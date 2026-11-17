#!/usr/bin/env bash
# BK-c1 (migration 0135, ADR-199 (3), BK-5a / CGR-211): two teams take the same confirmed shift order in two real,
# parallel database sessions. Exactly one take may become live; the other gets `already_taken` and writes nothing.
# pgTAP runs inside one transaction and cannot open a second session, so this check uses two psql processes (as
# open-visit-take.sh). The serialisation under test is the `for update` lock on the order row in `public.take_order`;
# the partial unique index `order_takes (order_id) where released_at is null` is the backstop.
# A third case: two members of the SAME team take at once (every active member may take for her team, PO 03:39 (2)).
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

# Fixture: T1 (M1, M3) and T2 (M2), service postcode 4102, 10 km; FaGe evidence verified for all three.
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
  ('$T1', '$M1', 'care_assistant'), ('$T2', '$M2', 'care_assistant'), ('$T1', '$M3', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '$ORG', u, 'grade', 'fage_efz', 'verified', true, null from unnest(array['$M1', '$M2', '$M3']::uuid[]) u;
SQL

confirm() {  # $1 days ahead → prints the order id
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$CLIENT","role":"authenticated"}', true);
set local role authenticated;
select public.confirm_client_order('$ACC', ((now() + interval '$1 days') at time zone 'Europe/Zurich')::date, time '08:00',
  time '12:00', '4102', 'fage_efz', array['C1'], array['C1'], null, gen_random_uuid()) ->> 'order_id';
commit;
SQL
}

take() {  # $1 user, $2 order, $3 team → prints result or refusal reason
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$1","role":"authenticated"}', true);
set local role authenticated;
select coalesce(r ->> 'reason', r ->> 'result') from public.take_order('$2', '$3', '$1', gen_random_uuid()) r;
-- hold the transaction a moment so the two takes overlap
select pg_sleep(0.3);
commit;
SQL
}

check() {  # $1 label, $2 order, $3 file a, $4 file b
  local results live rows
  results=$(cat "$3" "$4" | grep -E '^[a-z_]+$' | sort | tr '\n' ' ')
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
offers=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_offers where order_id in ('$O1', '$O2') and team_id in ('$T1', '$T2')")
[ "$offers" = "4" ] || { echo "not ok - expected both race teams offered on both orders (got $offers)"; exit 1; }

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
