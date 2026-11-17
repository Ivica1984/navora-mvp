#!/usr/bin/env bash
# BK-c1 (migration 0135, ADR-199 (3), BK-5a / CGR-211): two teams take the same confirmed shift order in two real,
# parallel database sessions. Exactly one take may become live; the other gets `already_taken` and writes nothing.
# pgTAP runs inside one transaction and cannot open a second session, so this check uses two psql processes (as
# open-visit-take.sh). The serialisation under test is the `for update` lock on the order row in `public.take_order`;
# the partial unique index `order_takes (order_id) where released_at is null` is the backstop.
# A second case: two members of the SAME team take at once (every active member may take for her team, PO 03:39 (2)).
# A third case (CGR-229, PO 2026-11-17 05:39 (2) (b)): one person (M1) is a member of two teams; two OVERLAPPING orders
# are taken naming her, one per team, in two sessions at once. The order lock alone does not serialise them (two
# different order rows), so `take_order` must serialise per named person before the CGR-204 (b) re-check: exactly one
# `ok`, the other `member_not_eligible` with step 3 (her live take of the other order), exactly one live take.
# Commits its own synthetic fixture rows (fixed ids, Testorganisation S) and removes them again. Synthetic data only.
# Usage: DB_URL=... order-take.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
ORG=00000000-0000-4000-b000-000000000019
ACC=00000000-0000-4000-a000-0000000003c7
CLIENT=00000000-0000-4000-a000-0000000009e8   # seed: kundebs
T1=00000000-0000-4000-b0c1-000000000001
T2=00000000-0000-4000-b0c1-000000000002
M1=00000000-0000-4000-a0c1-000000000001       # T1
M2=00000000-0000-4000-a0c1-000000000002       # T2
M3=00000000-0000-4000-a0c1-000000000003       # T1
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }
START=$(psql "$DB_URL" -X -At -c "select clock_timestamp()")

cleanup() {
  psql_q <<SQL
set session_replication_role = replica;
delete from public.order_takes where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.order_declines where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.order_offers where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.order_exclusions where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.partner_requests where client_account_id = '$ACC';
delete from public.member_qualification_evidence where user_id in ('$M1', '$M2', '$M3');
delete from public.team_memberships where team_id in ('$T1', '$T2');
delete from public.team_service_postcodes where team_id in ('$T1', '$T2');
delete from public.teams where id in ('$T1', '$T2');
delete from public.organization_memberships where user_id in ('$M1', '$M2', '$M3');
delete from public.client_account_members where client_account_id = '$ACC';
delete from public.client_accounts where id = '$ACC';
delete from auth.users where id in ('$M1', '$M2', '$M3');
delete from public.audit_events where occurred_at >= timestamptz '$START'
  and (organization_id = '$ORG' or actor_id in ('$CLIENT', '$M1', '$M2', '$M3'));
SQL
}
trap cleanup EXIT
cleanup

# Fixture: T1 (M1, M3) and T2 (M2, M1), service postcode 4102, 10 km; FaGe evidence verified for all three.
psql_q <<SQL
insert into public.client_accounts (id, organization_id, display_name, client_kind)
  values ('$ACC', '$ORG', 'Haushalt BK-c1 Race-Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values ('$ACC', '$CLIENT');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('$ORG', '$T1', 'BK-c1 Race T1', 'Basel-Landschaft', 'active', 10),
  ('$ORG', '$T2', 'BK-c1 Race T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values ('$T1', '4102'), ('$T2', '4102');
insert into auth.users (id, aud, role, email) values
  ('$M1', 'authenticated', 'authenticated', 'bk-c1-race-1.fixture@navora.test'),
  ('$M2', 'authenticated', 'authenticated', 'bk-c1-race-2.fixture@navora.test'),
  ('$M3', 'authenticated', 'authenticated', 'bk-c1-race-3.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('$ORG', '$M1', 'nurse'), ('$ORG', '$M2', 'nurse'), ('$ORG', '$M3', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('$T1', '$M1', 'care_assistant'), ('$T2', '$M2', 'care_assistant'), ('$T1', '$M3', 'care_assistant'),
  ('$T2', '$M1', 'care_assistant');  -- M1 in both teams (case 3, CGR-229)
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '$ORG', u, 'grade', 'fage_efz', 'verified', true, null from unnest(array['$M1', '$M2', '$M3']::uuid[]) u;
SQL

confirm() {  # $1 days ahead, optional $2 start and $3 end (default 08:00–12:00) → prints the order id
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
set local request.jwt.claims to '{"sub":"$CLIENT","role":"authenticated"}';  -- SET prints nothing (psql -At)
set local role authenticated;
select public.confirm_client_order('$ACC', ((now() + interval '$1 days') at time zone 'Europe/Zurich')::date, time '${2:-08:00}',
  time '${3:-12:00}', '4102', 'fage_efz', array['C1'], array['C1'], null, gen_random_uuid()) ->> 'order_id';
commit;
SQL
}

take() {  # $1 caller, $2 order, $3 team, optional $4 named member (default: the caller) → prints result or reason[:step]
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
set local request.jwt.claims to '{"sub":"$1","role":"authenticated"}';
set local role authenticated;
select coalesce((r ->> 'reason') || coalesce(':' || (r ->> 'step'), ''), r ->> 'result')
  from public.take_order('$2', '$3', '${4:-$1}', gen_random_uuid()) r;
-- hold the transaction a moment so the two takes overlap
select pg_sleep(0.3);
commit;
SQL
}

check() {  # $1 label, $2 order, $3 file a, $4 file b
  local results live rows
  results=$(cat "$3" "$4" | grep -E '^[a-z_]+(:[0-9])?$' | sort | tr '\n' ' ')
  live=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_takes where order_id = '$2' and released_at is null")
  rows=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_takes where order_id = '$2'")
  echo "$1: results: $results; live takes: $live; take rows: $rows"
  if [ "$results" = "already_taken ok " ] && [ "$live" = "1" ] && [ "$rows" = "1" ]; then
    echo "ok - $1: one take wins, the other gets \"already_taken\" and writes nothing"
  else
    echo "not ok - $1: expected one ok and one already_taken with exactly one take row"; exit 1
  fi
}

tmp=$(mktemp -d)
O1=$(confirm 3)
O2=$(confirm 4)
[ -n "$O1" ] && [ -n "$O2" ] || { echo "not ok - fixture orders not confirmed"; exit 1; }
O3=$(confirm 5 08:00 12:00)
O4=$(confirm 5 10:00 14:00)   # overlaps O3 from 10:00 to 12:00
[ -n "$O3" ] && [ -n "$O4" ] || { echo "not ok - fixture orders O3/O4 not confirmed"; exit 1; }
offers=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_offers where order_id in ('$O1', '$O2', '$O3', '$O4') and team_id in ('$T1', '$T2')")
[ "$offers" = "8" ] || { echo "not ok - expected both race teams offered on all four orders (got $offers)"; exit 1; }

# Case 1: two teams, one order (BK-5a, CGR-211)
take "$M1" "$O1" "$T1" > "$tmp/a" &
take "$M2" "$O1" "$T2" > "$tmp/b" &
wait
check "two teams" "$O1" "$tmp/a" "$tmp/b"

# Case 2: two members of the same team, one order (PO 03:39 (2): every active member may take for her team)
take "$M1" "$O2" "$T1" > "$tmp/c" &
take "$M3" "$O2" "$T1" > "$tmp/d" &
wait
check "one team, two members" "$O2" "$tmp/c" "$tmp/d"

# Case 3: one person in two teams, two overlapping orders, two sessions at once (CGR-229, PO 05:39 (2) (b)).
# Session a: M1 takes O3 for T1 naming herself. Session b: M2 takes O4 for T2 naming M1 (her colleague in T2).
take "$M1" "$O3" "$T1" "$M1" > "$tmp/e" &
take "$M2" "$O4" "$T2" "$M1" > "$tmp/f" &
wait
results=$(cat "$tmp/e" "$tmp/f" | grep -E '^[a-z_]+(:[0-9])?$' | sort | tr '\n' ' ')
live=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_takes where order_id in ('$O3', '$O4') and member_id = '$M1' and released_at is null")
rows=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_takes where order_id in ('$O3', '$O4')")
echo "one person, two teams, overlapping orders: results: $results; live takes of M1: $live; take rows: $rows"
if [ "$results" = "member_not_eligible:3 ok " ] && [ "$live" = "1" ] && [ "$rows" = "1" ]; then
  echo "ok - one person, two overlapping orders: one take wins, the other gets \"member_not_eligible\" step 3 and writes nothing"
else
  echo "not ok - one person, two overlapping orders: expected one ok and one member_not_eligible:3 with exactly one take row (CGR-229)"; exit 1
fi
