#!/usr/bin/env bash
# BK-e1b CGR-233 (ADR-202 (4), ADR-203 (4), (19)): a take that writes a visit for its named member (0138) racing a hand
# assignment of an overlapping visit to the same member, in two real, parallel database sessions. pgTAP runs inside
# one transaction and cannot open a second session, so this check uses two psql processes (as order-take.sh).
# The hand-assignment paths (plan_visit, reschedule_visit, move_visit_to_today, take_open_visit, AIG1 apply) never
# refuse for an overlap with another visit: they return the server's `member_overlap` fact (PLAN3-16, ADR-161). Since
# HD-3s-F2-F1 they refuse inside the window of her own live take (`member_take_window`, CGR-289 (c)). `take_order` refuses a
# member with an overlapping open visit (step 3, CGR-204 (a)). Both readings must be serialisable per member:
#   Case 1, take first: the take (and its visit) is uncommitted when the member takes an overlapping open visit.
#           The race must end in the serial outcome «take, then hand». HD-3s-F2-F1 (CGR-289 (c), PO decision 2026-11-27,
#           ADR-230, migration 0185) changed that serial outcome on purpose: the hand path no longer writes into the
#           window of her live take and lets the re-check release the take silently (the CGR-255 outcome of 0135 §10 /
#           0138 §3); it waits for the take under the same person lock, sees it committed and rejects with
#           `member_take_window`. So: the take stays live (no `step_3` release), the take visit stays `planned`, the open
#           visit stays open, nothing is written by the hand path.
#   Case 1s, serial control: the same two commands one after the other (take committed first, no sleep); same values.
#   Case 2, visit first: the member's take of an open visit is uncommitted when a take naming her for an overlapping
#           order runs. The take must wait and then refuse with step 3 (`member_not_eligible:3`) and write nothing.
#   Case 2s, serial control: the same two commands one after the other (hand path committed first); same values.
# Invariant after every case (CGR-255): no live take of M1 before its start beside another non-cancelled visit of M1
# whose interval overlaps the order slot (a race result must equal a serial result, PO 13:39 H-BK-13:39).
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
V3=00000000-0000-4000-c0e1-0000000000f3
V4=00000000-0000-4000-c0e1-0000000000f4
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
# (memberless) visits with activity C1, each inside the slot of one order (orders 6 to 9 days ahead, 08:00–12:00).
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
   array['Grundpflege'], false, 'planned', 30),
  ('$ORG', '$V3', '$CASE1', '$T1', ((now() + interval '8 days') at time zone 'Europe/Zurich')::date, '09:00', '09:30',
   array['Grundpflege'], false, 'planned', 30),
  ('$ORG', '$V4', '$CASE1', '$T1', ((now() + interval '9 days') at time zone 'Europe/Zurich')::date, '09:00', '09:30',
   array['Grundpflege'], false, 'planned', 30);
-- QUAL1-6: the matrix activity of both visits is the orders' tag C1 (as the take visit, 0138), and only C minutes (KLV-A
-- minutes would add A1 by CGR-149), so the FaGe M1 may perform them in the simulation organisation.
insert into public.visit_activities (organization_id, visit_id, activity_code) values ('$ORG', '$V1', 'C1'), ('$ORG', '$V2', 'C1'),
  ('$ORG', '$V3', 'C1'), ('$ORG', '$V4', 'C1');
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

take_open() {  # $1 visit, $2 seconds to hold → prints result:reason, else result:member_overlap (PLAN3-16 fact)
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
set local request.jwt.claims to '{"sub":"$M1","role":"authenticated"}';
set local role authenticated;
select (r ->> 'result') || ':' || coalesce(r ->> 'reason', r ->> 'member_overlap', 'null')
  from public.take_open_visit('$1', gen_random_uuid(), null) r;
select pg_sleep($2);
commit;
SQL
}

q() { psql "$DB_URL" -X -At -c "$1"; }

invariant() {  # → count of live takes of M1 before their start beside another non-cancelled overlapping visit of M1
  q "select count(*) from public.order_takes k join public.partner_requests p on p.id = k.order_id
     join public.care_visits x on x.responsible_user_id = k.member_id and x.status <> 'cancelled'
                              and x.order_take_id is distinct from k.id
    where k.member_id = '$M1' and k.released_at is null and p.starts_at > now()
      and private.visit_interval(x) && tstzrange(p.starts_at, p.ends_at, '[)')"
}

tmp=$(mktemp -d)
O1=$(confirm 6)
O2=$(confirm 7)
O3=$(confirm 8)
O4=$(confirm 9)
[ -n "$O1" ] && [ -n "$O2" ] && [ -n "$O3" ] && [ -n "$O4" ] || { echo "not ok - fixture orders not confirmed"; exit 1; }
offers=$(q "select count(*) from public.order_offers where order_id in ('$O1', '$O2', '$O3', '$O4') and team_id = '$T1'")
[ "$offers" = "4" ] || { echo "not ok - expected T1 offered on all four orders (got $offers)"; exit 1; }
fail=0

# «take, then hand» (case 1 and 1s): $1 label, $2 order, $3 visit, $4 take result, $5 hand result.
# HD-3s-F2-F1 (CGR-289 (c)): the hand path is rejected with member_take_window; the take stays live.
check_take_then_hand() {
  local rel live tvc r inv
  rel=$(q "select count(*) from public.order_takes where order_id = '$2' and member_id = '$M1'
           and released_at is not null")
  live=$(q "select count(*) from public.order_takes where order_id = '$2' and member_id = '$M1' and released_at is null")
  tvc=$(q "select string_agg(v.status, ',' order by v.status) from public.care_visits v
           join public.order_takes k on k.id = v.order_take_id where k.order_id = '$2'")
  r=$(q "select count(*) from public.care_visits where id = '$3' and responsible_user_id = '$M1' and status <> 'cancelled'")
  inv=$(invariant)
  echo "$1: take: $4; open visit: $5; take released: $rel; take live: $live; take visit: ${tvc:-none}; open visit assigned: $r; invariant violations: $inv"
  if [ "$4" = "ok" ] && [ "$5" = "rejected:member_take_window" ] && [ "$rel" = "0" ] && [ "$live" = "1" ] \
     && [ "$tvc" = "planned" ] && [ "$r" = "0" ] && [ "$inv" = "0" ]; then
    echo "ok - CGR-255/CGR-289 $1: serial outcome «take, then hand» (hand rejected member_take_window, take live, take visit planned, open visit open)"
  else
    echo "not ok - CGR-255/CGR-289 $1: expected take ok, open visit rejected:member_take_window, take live (not released), take visit planned, open visit open, invariant 0"
    fail=1
  fi
}

# «hand, then take» (case 2 and 2s): $1 label, $2 order, $3 visit, $4 hand result, $5 take result.
check_hand_then_take() {
  local rows r inv
  rows=$(q "select count(*) from public.order_takes where order_id = '$2'")
  r=$(q "select count(*) from public.care_visits where id = '$3' and responsible_user_id = '$M1' and status <> 'cancelled'")
  inv=$(invariant)
  echo "$1: open visit: $4; take: $5; take rows: $rows; open visit assigned: $r; invariant violations: $inv"
  if [ "$4" = "ok:false" ] && [ "$5" = "member_not_eligible:3" ] && [ "$rows" = "0" ] && [ "$r" = "1" ] && [ "$inv" = "0" ]; then
    echo "ok - CGR-233 $1: serial outcome «hand, then take» (take refused with step 3, no take row)"
  else
    echo "not ok - CGR-233 $1: expected open visit ok:false, take member_not_eligible:3, no take row, invariant 0"
    fail=1
  fi
}

pick_take() { grep -E '^[a-z_]+(:[0-9])?$' "$1" || true; }
pick_hand() { grep -E '^[a-z_]+:(true|false|null|[a-z_]+)$' "$1" || true; }

# Case 1: take first (held 2 s), the hand path 0.7 s later.
take "$O1" 2 > "$tmp/t1" &
sleep 0.7
take_open "$V1" 0 > "$tmp/p1" &
wait
check_take_then_hand "case 1 (take first, race)" "$O1" "$V1" "$(pick_take "$tmp/t1")" "$(pick_hand "$tmp/p1")"

# Case 1s: serial control, the take committed first, then the hand path (no sleep).
take "$O3" 0 > "$tmp/t3"
take_open "$V3" 0 > "$tmp/p3"
check_take_then_hand "case 1s (take, then hand, serial)" "$O3" "$V3" "$(pick_take "$tmp/t3")" "$(pick_hand "$tmp/p3")"

# Case 2: the hand path first (held 2 s), the take naming her 0.7 s later.
take_open "$V2" 2 > "$tmp/p2" &
sleep 0.7
take "$O2" 0 > "$tmp/t2" &
wait
check_hand_then_take "case 2 (visit first, race)" "$O2" "$V2" "$(pick_hand "$tmp/p2")" "$(pick_take "$tmp/t2")"

# Case 2s: serial control, the hand path committed first, then the take (no sleep).
take_open "$V4" 0 > "$tmp/p4"
take "$O4" 0 > "$tmp/t4"
check_hand_then_take "case 2s (hand, then take, serial)" "$O4" "$V4" "$(pick_hand "$tmp/p4")" "$(pick_take "$tmp/t4")"
exit $fail
