#!/usr/bin/env bash
# HD-1 (PO residual list 2026-11-20 20:05, item 4; migrations 0159/0160): two planners of the same home act at the same
# time in two real, parallel database sessions. pgTAP runs inside one transaction and cannot open a second session, so
# this check uses two psql processes (as cover-accept.sh).
#   A: both assign the same person to two overlapping shifts of the same day: exactly one wins, the other gets
#      «staff_overlap» (the person row lock serialises them; never a unique violation, never both).
#   B: both assign the same person to the same shift: exactly one wins, the other gets «already_assigned».
#   C: the lead moves the times of an unused shift type onto an overlap while a planner assigns it: never both (a silent
#      overlap); the shift type row lock (R2) serialises them.
# Commits its own synthetic fixture rows (fixed ids, home «Testheim Rhein» of the seed) and removes them again.
# Usage: DB_URL=... home-plan-assign.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
INST=00000000-0000-4000-a000-0000000004c1
LEAD=00000000-0000-4000-a000-0000000009e8
PLANNER=a1600000-0000-4000-8000-0000000000e1
ST=a1600000-0000-4000-8000-0000000000a1
TF=a1600000-0000-4000-8000-0000000000b1
TS=a1600000-0000-4000-8000-0000000000b2
TU=a1600000-0000-4000-8000-0000000000b3
PX=a1600000-0000-4000-8000-0000000000c1
DAY=2030-04-08
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }

cleanup() {
  psql_q <<SQL
set session_replication_role = replica;
delete from public.institution_audit_events where institution_id = '$INST' and (entity_id in ('$ST', '$TF', '$TS', '$TU', '$PX')
  or changed ->> 'staff_id' = '$PX' or entity_id in (select id from public.institution_assignments where staff_id = '$PX'));
delete from public.institution_assignments where staff_id = '$PX';
delete from public.institution_staff where id = '$PX';
delete from public.institution_shift_types where id in ('$TF', '$TS', '$TU');
delete from public.institution_stations where id = '$ST';
delete from public.institution_members where user_id = '$PLANNER';
delete from auth.users where id = '$PLANNER';
SQL
}
trap cleanup EXIT
cleanup

psql_q <<SQL
insert into auth.users (id, email) values ('$PLANNER', 'planer.hd1-race@navora.test');
insert into public.institution_members (institution_id, user_id, role) values ('$INST', '$PLANNER', 'planner');
insert into public.institution_stations (id, institution_id, name, sort) values ('$ST', '$INST', 'Station Race (synthetisch)', 99);
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, ends_at, sort) values
  ('$TF', '$INST', 'XF', 'Race Früh', '07:00', '15:30', 97),
  ('$TS', '$INST', 'XS', 'Race Spät', '14:30', '23:00', 98),
  ('$TU', '$INST', 'XU', 'Race Ungenutzt', '08:00', '12:00', 99);
insert into public.institution_staff (id, institution_id, display_name, grade) values ('$PX', '$INST', 'Race Person (synthetisch)', 'nurse_hf_fh');
SQL

run_as() {  # $1 user, $2 sql returning one text value
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$1","role":"authenticated"}', true);
set local role authenticated;
$2
-- hold the transaction a moment so the two sessions overlap
select pg_sleep(0.3);
commit;
SQL
}
assign() {  # $1 user, $2 shift type
  run_as "$1" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_assign_staff('$INST', '$ST', '$2', '$DAY', '$PX') r;"
}
norm() { grep -hE '^[a-z_]+$' "$@" | sort | tr '\n' ' '; }
tmp=$(mktemp -d)
fail=0

# A: overlapping shifts
assign "$LEAD" "$TF" > "$tmp/a1" & assign "$PLANNER" "$TS" > "$tmp/a2" & wait
ra=$(norm "$tmp/a1" "$tmp/a2")
na=$(psql "$DB_URL" -X -At -c "select count(*) from public.institution_assignments where staff_id = '$PX'")
echo "A results: $ra; assignments: $na"
if [ "$ra" = "ok staff_overlap " ] && [ "$na" = "1" ]; then echo "ok - A: overlapping shifts in parallel: one wins, the other «staff_overlap»";
else echo "not ok - A: expected one ok and one staff_overlap with one assignment"; fail=1; fi
psql_q -c "set session_replication_role = replica; delete from public.institution_assignments where staff_id = '$PX'"

# B: the same shift
assign "$LEAD" "$TF" > "$tmp/b1" & assign "$PLANNER" "$TF" > "$tmp/b2" & wait
rb=$(norm "$tmp/b1" "$tmp/b2")
nb=$(psql "$DB_URL" -X -At -c "select count(*) from public.institution_assignments where staff_id = '$PX'")
echo "B results: $rb; assignments: $nb"
if [ "$rb" = "already_assigned ok " ] && [ "$nb" = "1" ]; then echo "ok - B: the same shift in parallel: one wins, the other «already_assigned»";
else echo "not ok - B: expected one ok and one already_assigned with one assignment"; fail=1; fi
psql_q -c "set session_replication_role = replica; delete from public.institution_assignments where staff_id = '$PX'"

# C: the person already works XS 14:30–23:00. The lead moves the unused type XU (08:00–12:00) to 13:00–17:00, which
# would overlap XS, while a planner assigns XU. Valid: change first -> the assignment sees the new times and gets
# «staff_overlap»; or assignment first -> the change gets «shift_type_in_use». Without the shift type row lock both would
# succeed and leave a silent overlap.
psql_q -c "insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id) values ('$INST', '$ST', '$TS', '$DAY', '$PX')"
run_as "$LEAD" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_set_shift_type('$INST', 'XU', 'Race Ungenutzt', '13:00', '17:00') r;" > "$tmp/c1" &
assign "$PLANNER" "$TU" > "$tmp/c2" & wait
rc=$(norm "$tmp/c1" "$tmp/c2")
state=$(psql "$DB_URL" -X -At -c "select (select count(*) from public.institution_assignments where staff_id = '$PX' and shift_type_id = '$TU')
  || '/' || (select to_char(starts_at, 'HH24:MI') from public.institution_shift_types where id = '$TU')")
echo "C results: $rc; XU assignments/start: $state"
case "$rc|$state" in
  "ok staff_overlap |0/13:00"|"ok shift_type_in_use |1/08:00") echo "ok - C: time change and assignment serialise (no silent overlap)";;
  *) echo "not ok - C: unexpected interleaving (silent overlap?)"; fail=1;;
esac
exit $fail
