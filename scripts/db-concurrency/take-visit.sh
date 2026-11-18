#!/usr/bin/env bash
# BK-e1b CGR-233 (ADR-202 (4), ADR-203 (4), (19)): a take that writes a visit for its named member (0138) racing a hand
# assignment of an overlapping visit to the same member, in two real, parallel database sessions. pgTAP runs inside
# one transaction and cannot open a second session, so this check uses two psql processes (as order-take.sh).
# The hand-assignment paths (plan_visit, reschedule_visit, move_visit_to_today, take_open_visit, AIG1 apply) never
# refuse for an overlap: they return the server's `member_overlap` fact (PLAN3-16, ADR-161). `take_order` refuses a
# member with an overlapping open visit (step 3, CGR-204 (a)). Both readings must be serialisable per member:
#   Case 1, take first: the take (and its visit) is uncommitted when the member takes an overlapping open visit.
#           The hand path must wait for the take and then report `member_overlap: true` (it may not read «no overlap»
#           while a live take and its visit for her exist once both have committed).
#   Case 2, visit first: the member's take of an open visit is uncommitted when a take naming her for an overlapping
#           order runs. The take must wait and then refuse with step 3 (`member_not_eligible:3`) and write nothing.
# Without one shared person lock (`order_take_member:`) both cases end in an outcome no serial order produces.
# Commits its own synthetic fixture rows (fixed ids, Testorganisation S) and removes them again. Synthetic data only.
# Usage: DB_URL=... take-visit.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
ORG=00000000-0000-4000-b000-000000000019
ACC=00000000-0000-4000-b0e1-0000000000ac
CLIENT=00000000-0000-4000-a000-0000000009e8   # seed: kundebs
T1=00000000-0000-4000-b0e1-000000000001
M1=00000000-0000-4000-a0e1-000000000001
CASE1=00000000-0000-4000-c0e1-000000000001
V1=00000000-0000-4000-c0e1-0000000000f1
V2=00000000-0000-4000-c0e1-0000000000f2
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }
START=$(psql "$DB_URL" -X -At -c "select clock_timestamp()")

cleanup() {
  psql_q <<SQL
set session_replication_role = replica;
delete from public.visit_activities where visit_id in (select id from public.care_visits where team_id = '$T1');
delete from public.visit_plan_changes where team_id = '$T1';
delete from public.care_visits where team_id = '$T1';
delete from public.order_takes where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.order_declines where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.order_offers where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.order_exclusions where order_id in (select id from public.partner_requests where client_account_id = '$ACC');
delete from public.partner_requests where client_account_id = '$ACC';
delete from public.cases where id = '$CASE1';
delete from public.member_qualification_evidence where user_id = '$M1';
delete from public.team_memberships where team_id = '$T1';
delete from public.team_service_postcodes where team_id = '$T1';
delete from public.teams where id = '$T1';
delete from public.organization_memberships where user_id = '$M1';
delete from public.client_account_members where client_account_id = '$ACC';
delete from public.client_accounts where id = '$ACC';
delete from auth.users where id = '$M1';
delete from public.audit_events where occurred_at >= timestamptz '$START'
  and (organization_id = '$ORG' or actor_id in ('$CLIENT', '$M1'));
SQL
}
trap cleanup EXIT
cleanup

# Fixture: team T1 with M1 (FaGe evidence verified), service postcode 4102, 10 km; one running case of T1 with two open
# (memberless) visits with activity C1, each inside the slot of one order (orders 6 and 7 days ahead, 08:00–12:00).
psql_q <<SQL
insert into public.client_accounts (id, organization_id, display_name, client_kind)
  values ('$ACC', '$ORG', 'Haushalt BK-e1b Race-Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values ('$ACC', '$CLIENT');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('$ORG', '$T1', 'BK-e1b Race T1', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values ('$T1', '4102');
insert into auth.users (id, aud, role, email) values
  ('$M1', 'authenticated', 'authenticated', 'bk-e1b-race-1.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values ('$ORG', '$M1', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values ('$T1', '$M1', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  values ('$ORG', '$M1', 'grade', 'fage_efz', 'verified', true, null);
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, plz, status, urgency, bedarf,
                          care_needs, next_step, assigned_team, assigned_team_id)
  values ('$ORG', '$CASE1', now() - interval '3 days', 'Testfall Race BK-e1b', 'Testfall', 'Race', 'Basel-Landschaft',
          '4102', 'laufend', 'mittel', 'Grundpflege', array['Grundpflege'], 'Laufende Versorgung', 'BK-e1b Race T1', '$T1');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_c) values
  ('$ORG', '$V1', '$CASE1', '$T1', ((now() + interval '6 days') at time zone 'Europe/Zurich')::date, '09:00', '09:30',
   array['Grundpflege'], false, 'planned', 30),
  ('$ORG', '$V2', '$CASE1', '$T1', ((now() + interval '7 days') at time zone 'Europe/Zurich')::date, '09:00', '09:30',
   array['Grundpflege'], false, 'planned', 30);
-- QUAL1-6: the matrix activity of both visits is the orders' tag C1 (as the take visit, 0138), and only C minutes (KLV-A
-- minutes would add A1 by CGR-149), so the FaGe M1 may perform them in the simulation organisation.
insert into public.visit_activities (organization_id, visit_id, activity_code) values ('$ORG', '$V1', 'C1'), ('$ORG', '$V2', 'C1');
SQL

confirm() {  # $1 days ahead → prints the order id (08:00–12:00)
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
set local request.jwt.claims to '{"sub":"$CLIENT","role":"authenticated"}';
set local role authenticated;
select public.confirm_client_order('$ACC', ((now() + interval '$1 days') at time zone 'Europe/Zurich')::date, time '08:00',
  time '12:00', '4102', 'fage_efz', array['C1'], array['C1'], null, gen_random_uuid()) ->> 'order_id';
commit;
SQL
}

take() {  # $1 order, $2 seconds to hold the transaction → prints result or reason[:step] (M1 takes for T1, naming herself)
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
set local request.jwt.claims to '{"sub":"$M1","role":"authenticated"}';
set local role authenticated;
select coalesce((r ->> 'reason') || coalesce(':' || (r ->> 'step'), ''), r ->> 'result')
  from public.take_order('$1', '$T1', '$M1', gen_random_uuid()) r;
select pg_sleep($2);
commit;
SQL
}

take_open() {  # $1 visit, $2 seconds to hold → prints result:member_overlap (M1 takes the open visit, PLAN3-16 fact)
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
set local request.jwt.claims to '{"sub":"$M1","role":"authenticated"}';
set local role authenticated;
select (r ->> 'result') || ':' || coalesce(r ->> 'member_overlap', 'null')
  from public.take_open_visit('$1', gen_random_uuid(), null) r;
select pg_sleep($2);
commit;
SQL
}

tmp=$(mktemp -d)
O1=$(confirm 6)
O2=$(confirm 7)
[ -n "$O1" ] && [ -n "$O2" ] || { echo "not ok - fixture orders not confirmed"; exit 1; }
offers=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_offers where order_id in ('$O1', '$O2') and team_id = '$T1'")
[ "$offers" = "2" ] || { echo "not ok - expected T1 offered on both orders (got $offers)"; exit 1; }
fail=0

# Case 1: take first (held 2 s), the hand path 0.7 s later.
take "$O1" 2 > "$tmp/t1" &
sleep 0.7
take_open "$V1" 0 > "$tmp/p1" &
wait
t1=$(grep -E '^[a-z_]+(:[0-9])?$' "$tmp/t1" || true)
p1=$(grep -E '^[a-z_]+:(true|false|null)$' "$tmp/p1" || true)
tv=$(psql "$DB_URL" -X -At -c "select count(*) from public.care_visits v join public.order_takes k on k.id = v.order_take_id
  where k.order_id = '$O1' and k.released_at is null and v.responsible_user_id = '$M1' and v.status = 'planned'")
r1=$(psql "$DB_URL" -X -At -c "select count(*) from public.care_visits where id = '$V1' and responsible_user_id = '$M1'")
echo "case 1 (take first): take: $t1; open visit: $p1; live take visits of M1: $tv; open visit assigned: $r1"
if [ "$t1" = "ok" ] && [ "$p1" = "ok:true" ] && [ "$tv" = "1" ] && [ "$r1" = "1" ]; then
  echo "ok - CGR-233 case 1: the hand path waits for the take and reports member_overlap true"
else
  echo "not ok - CGR-233 case 1: expected take ok, open visit ok:true (the hand path read «no overlap» beside a live take visit)"
  fail=1
fi

# Case 2: the hand path first (held 2 s), the take naming her 0.7 s later.
take_open "$V2" 2 > "$tmp/p2" &
sleep 0.7
take "$O2" 0 > "$tmp/t2" &
wait
p2=$(grep -E '^[a-z_]+:(true|false|null)$' "$tmp/p2" || true)
t2=$(grep -E '^[a-z_]+(:[0-9])?$' "$tmp/t2" || true)
rows=$(psql "$DB_URL" -X -At -c "select count(*) from public.order_takes where order_id = '$O2'")
r2=$(psql "$DB_URL" -X -At -c "select count(*) from public.care_visits where id = '$V2' and responsible_user_id = '$M1'")
echo "case 2 (visit first): open visit: $p2; take: $t2; take rows: $rows; open visit assigned: $r2"
if [ "$p2" = "ok:false" ] && [ "$t2" = "member_not_eligible:3" ] && [ "$rows" = "0" ] && [ "$r2" = "1" ]; then
  echo "ok - CGR-233 case 2: the take waits for the hand path and refuses with step 3, writing nothing"
else
  echo "not ok - CGR-233 case 2: expected open visit ok:false, take member_not_eligible:3 and no take row"
  fail=1
fi
exit $fail
