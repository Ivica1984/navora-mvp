#!/usr/bin/env bash
# HD-1 (PO residual list 2026-11-20 20:05, item 4; migrations 0159/0160): two planners of the same home act at the same
# time in two real, parallel database sessions. pgTAP runs inside one transaction and cannot open a second session, so
# this check uses two psql processes (as cover-accept.sh).
#   A: both assign the same person to two overlapping shifts of the same day: exactly one wins, the other gets
#      «staff_overlap» (the person row lock serialises them; never a unique violation, never both).
#   B: both assign the same person to the same shift: exactly one wins, the other gets «already_assigned».
#   C: the lead moves the times of an unused shift type onto an overlap while a planner assigns it: never both (a silent
#      overlap); the shift type row lock (R2) serialises them.
#   D (HD-3a, ADR-224 rev. 2): the lead takes over a draft with the late shift of the person while a planner assigns her
#      by hand to the early shift the next morning (8 h rest < 11 h): exactly one survives, the other gets the rest rule
#      (the apply refuses its row as «planning_rule», the hand assignment answers «warning»); never both.
#   E: two drafts with overlapping shifts of the same person are taken over at once: one saves, the other refuses
#      «staff_overlap»; never both, never a unique violation, no deadlock (both lock persons in id order).
#   F: the same draft (same apply id) is sent twice at once (double click): one «ok», one «already_applied», one row.
#   G (0176, review finding 1): a draft row and an external gap order for the same empty cell, in both orders: exactly
#      one of «row saved» / «order prepared», never both (both take private.institution_cell_lock). G1 apply first ->
#      prepare «not_a_gap»; G2 prepare first -> apply «cell_has_order».
#   H (0176, review finding 4): the planner's role is removed while her apply waits for a person lock: «rejected», no
#      run record, no assignment.
#   I (HD-3a-F1, 0186): the lead empties the Wochensoll while an apply waits on a cell lock: serial outcome, the row is
#      never saved with R-h skipped.
#   J (HD-3a-F1 R-6-2 (b), 0188): two planners save a different Pensum for the same person from the same shown value at
#      once: exactly one «ok», the other «changed_meanwhile» (compared under the person row lock), the stored Pensum is
#      the winner's; the later save never overwrites the earlier one silently (the serial outcome).
#   K (HD-3a-F3, 0189): the lead lowers the monthly target of a person while a planner assigns her a shift that fits only
#      the old target: the target writer and the assignment take the same first lock (person row), so the outcome is
#      serial: either the target change waits and the assignment was judged on the old target (assignment event before
#      the target event), or the assignment waits and answers «warning» (month_target_full) and nothing is saved.
#   L (HD-PEN-HAND, 0190): the lead removes the Pensum of a person while a planner assigns her by hand without a
#      confirmation: both take the person row first, so the outcome is serial: either the Pensum change waits and the
#      shift was saved while the Pensum still held (assignment event before the planning event), or the assignment
#      waits and answers «warning» (hours_unknown) and nothing is saved. Never saved unconfirmed without hours check.
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
DAY2=2030-04-09
A1=a1600000-0000-4000-8000-0000000000d1
A2=a1600000-0000-4000-8000-0000000000d2
A3=a1600000-0000-4000-8000-0000000000d3
A4=a1600000-0000-4000-8000-0000000000d4
A5=a1600000-0000-4000-8000-0000000000d5
A6=a1600000-0000-4000-8000-0000000000d6
A7=a1600000-0000-4000-8000-0000000000d7
A8=a1600000-0000-4000-8000-0000000000d8
DAY3=2030-04-15
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }
# HD-3a-F1 (migration 0186): «übernehmen» refuses the whole call without the home's Wochensoll and a row of a person
# without Pensum (fail closed). The D-G applies are valid drafts, so the fixture gives the race home a Wochensoll and the
# race person a Pensum, as the planner requires; the home's own value is read first and restored in cleanup.
ORIG_WT=$(psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -c "select coalesce(weekly_target_hours::text, 'null') from public.institutions where id = '$INST'")

cleanup() {
  psql_q <<SQL
set session_replication_role = replica;
update public.institutions set weekly_target_hours = $ORIG_WT where id = '$INST';
delete from public.institution_audit_events where institution_id = '$INST' and (entity_id in ('$ST', '$TF', '$TS', '$TU', '$PX')
  or changed ->> 'staff_id' = '$PX' or entity_id in (select id from public.institution_assignments where staff_id = '$PX'));
delete from public.institution_audit_events where institution_id = '$INST' and entity_id in ('$A1', '$A2', '$A3', '$A4', '$A5', '$A6', '$A7', '$A8');
delete from public.institution_audit_events where institution_id = '$INST'
  and entity_id in (select id from public.institution_gap_orders where station_id = '$ST');
delete from public.institution_draft_runs where id in ('$A1', '$A2', '$A3', '$A4', '$A5', '$A6', '$A7', '$A8');
delete from public.institution_gap_orders where station_id = '$ST';
delete from public.institution_assignments where staff_id = '$PX';
delete from public.institution_monthly_targets where staff_id = '$PX';
delete from public.institution_staffing_rules where station_id = '$ST';
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
  ('$TU', '$INST', 'XU', 'Race Ungenutzt', '00:00', '03:00', 99);
insert into public.institution_staff (id, institution_id, display_name, grade, pensum_pct) values ('$PX', '$INST', 'Race Person (synthetisch)', 'nurse_hf_fh', 100);
set session_replication_role = replica;
update public.institutions set weekly_target_hours = 42 where id = '$INST';
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

# C: the person already works XS 14:30–23:00. The lead moves the unused type XU (00:00–03:00, 11.5 h before XS, so no rest warning since HD-3a 0173) to 13:00–17:00, which
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
  "ok staff_overlap |0/13:00"|"ok shift_type_in_use |1/00:00") echo "ok - C: time change and assignment serialise (no silent overlap)";;
  *) echo "not ok - C: unexpected interleaving (silent overlap?)"; fail=1;;
esac
psql_q -c "set session_replication_role = replica; delete from public.institution_assignments where staff_id = '$PX'"

# D-F (HD-3a «Entwurf übernehmen»): each cell has a staffing rule, so the apply reaches institution_assign_staff.
psql_q <<SQL
insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total) values
  ('$INST', '$ST', '$TF', 1), ('$INST', '$ST', '$TS', 1);
SQL
apply() {  # $1 user, $2 apply id, $3 shift type, $4 day
  run_as "$1" "select case when r ->> 'result' = 'already_applied' then 'already_applied' when (r ->> 'applied')::int = 1 then 'ok'
    else coalesce(r -> 'refused' -> 0 ->> 'reason', r -> 'problems' ->> 0, r ->> 'result') end
    from public.institution_apply_draft('$INST', '$2', jsonb_build_array(jsonb_build_object('date', '$4', 'station_id', '$ST',
      'shift_type_id', '$3', 'staff_id', '$PX'))) r;"
}
count_px() { psql "$DB_URL" -X -At -c "select count(*) from public.institution_assignments where staff_id = '$PX'"; }

# D: draft late shift on DAY vs. hand early shift on DAY2 (14:30-23:00 then 07:00: 8 h rest)
apply "$LEAD" "$A1" "$TS" "$DAY" > "$tmp/d1" &
run_as "$PLANNER" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_assign_staff('$INST', '$ST', '$TF', '$DAY2', '$PX') r;" > "$tmp/d2" & wait
rd=$(norm "$tmp/d1" "$tmp/d2")
nd=$(count_px)
echo "D results: $rd; assignments: $nd"
case "$rd|$nd" in
  "ok warning |1"|"ok planning_rule |1") echo "ok - D: draft and hand assignment against the rest rule: exactly one survives";;
  *) echo "not ok - D: expected exactly one of draft and hand assignment (rest rule)"; fail=1;;
esac
psql_q -c "set session_replication_role = replica; delete from public.institution_assignments where staff_id = '$PX'"

# E: two drafts with overlapping shifts of the same day
apply "$LEAD" "$A2" "$TF" "$DAY" > "$tmp/e1" & apply "$PLANNER" "$A3" "$TS" "$DAY" > "$tmp/e2" & wait
re=$(norm "$tmp/e1" "$tmp/e2")
ne=$(count_px)
echo "E results: $re; assignments: $ne"
if [ "$re" = "ok staff_overlap " ] && [ "$ne" = "1" ]; then echo "ok - E: two overlapping drafts at once: one saves, the other «staff_overlap»";
else echo "not ok - E: expected one ok and one staff_overlap with one assignment"; fail=1; fi
psql_q -c "set session_replication_role = replica; delete from public.institution_assignments where staff_id = '$PX'"

# F: the same draft twice at once
apply "$LEAD" "$A4" "$TF" "$DAY" > "$tmp/f1" & apply "$LEAD" "$A4" "$TF" "$DAY" > "$tmp/f2" & wait
rf=$(norm "$tmp/f1" "$tmp/f2")
nf=$(count_px)
echo "F results: $rf; assignments: $nf"
if [ "$rf" = "already_applied ok " ] && [ "$nf" = "1" ]; then echo "ok - F: the same apply id twice: one «ok», one «already_applied», one row";
else echo "not ok - F: expected ok and already_applied with one assignment"; fail=1; fi
psql_q -c "set session_replication_role = replica; delete from public.institution_assignments where staff_id = '$PX'"

# G: draft row vs. external order for the same empty cell (XF on DAY3, staffing rule 1). The second command starts
# 0.15 s after the first, while the first still holds its locks (run_as keeps the transaction open 0.3 s), so each order
# of the two is forced once. Before 0176 the apply did not take the cell lock and both committed.
prepare() {  # $1 user
  run_as "$1" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_prepare_gap_order('$INST', '$ST', '$TF', '$DAY3') r;"
}
count_orders() { psql "$DB_URL" -X -At -c "select count(*) from public.institution_gap_orders where station_id = '$ST' and state in ('prepared', 'sent')"; }
clear_g() {
  psql_q <<SQL
set session_replication_role = replica;
delete from public.institution_audit_events where institution_id = '$INST'
  and entity_id in (select id from public.institution_gap_orders where station_id = '$ST');
delete from public.institution_gap_orders where station_id = '$ST';
delete from public.institution_assignments where staff_id = '$PX';
delete from public.institution_monthly_targets where staff_id = '$PX';
SQL
}
apply "$LEAD" "$A5" "$TF" "$DAY3" > "$tmp/g1a" & (sleep 0.15; prepare "$PLANNER" > "$tmp/g1b") & wait
g1="$(norm "$tmp/g1a")|$(norm "$tmp/g1b")|$(count_px)/$(count_orders)"
echo "G1 (apply first) apply|prepare|assignments/orders: $g1"
if [ "$g1" = "ok |not_a_gap |1/0" ]; then echo "ok - G1: apply first: the row is saved, prepare finds no gap";
else echo "not ok - G1: expected the row saved and no order (both would mean an external team for a filled cell)"; fail=1; fi
clear_g
prepare "$PLANNER" > "$tmp/g2b" & (sleep 0.15; apply "$LEAD" "$A6" "$TF" "$DAY3" > "$tmp/g2a") & wait
g2="$(norm "$tmp/g2a")|$(norm "$tmp/g2b")|$(count_px)/$(count_orders)"
echo "G2 (prepare first) apply|prepare|assignments/orders: $g2"
if [ "$g2" = "cell_has_order |ok |0/1" ]; then echo "ok - G2: prepare first: the order stands, the draft row is refused «cell_has_order»";
else echo "not ok - G2: expected the order and the row refused"; fail=1; fi
clear_g

# H: the lead's session holds the person row and removes the planner's role; the planner's apply waits for the person
# lock and must then be refused before anything is recorded.
psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 > /dev/null <<SQL &
begin;
set local session_replication_role = replica;
select 1 from public.institution_staff where id = '$PX' for update;
delete from public.institution_members where institution_id = '$INST' and user_id = '$PLANNER';
select pg_sleep(1.0);
commit;
SQL
(sleep 0.4; apply "$PLANNER" "$A7" "$TF" "$DAY3" > "$tmp/h1") & wait
h="$(norm "$tmp/h1")|$(count_px)|$(psql "$DB_URL" -X -At -c "select count(*) from public.institution_draft_runs where id = '$A7'")"
echo "H apply|assignments|run records: $h"
if [ "$h" = "rejected |0|0" ]; then echo "ok - H: role removed while waiting: «rejected», no run record, no assignment";
else echo "not ok - H: expected rejected with no run record"; fail=1; fi
psql_q -c "insert into public.institution_members (institution_id, user_id, role) values ('$INST', '$PLANNER', 'planner') on conflict do nothing"

# I (HD-3a-F1, migration 0186; contract eng 7225259824 point 1): the lead empties the Wochensoll while an apply waits on
# a cell lock. Regression guard: a setter committing NULL in between would let R-h be skipped and save the row of a
# person whose Pensum (10 % of 42 h = 4.2 h) cannot hold an 8.5 h shift. Checked on the pre-0186 definition: also
# serial (the run-record insert's foreign key already took the home `for key share` before the cell locks; the race
# named in the contract was not real). 0186 takes the home `for share` explicitly, because its new check runs before
# that insert. Serial outcomes only: apply first -> «planning_rule» (R-h on 42 h), setter ok, no row; setter
# first -> «weekly_target_missing», no row. Never a saved row. A superuser session holds the cell lock for 1.5 s (the setter, held 0.3 s by run_as, commits well before it ends).
DAY4=2030-04-22
psql_q -c "set session_replication_role = replica; update public.institution_staff set pensum_pct = 10 where id = '$PX'"
AUD0=$(psql "$DB_URL" -X -At -c "select coalesce(max(id), 0) from public.institution_audit_events")
LIM=$(psql "$DB_URL" -X -At -c "select min_rest_hours || ', ' || max_consecutive_days from public.institutions where id = '$INST'")
# 0188: the setter states the values its form showed (`p_expected`): the current ones, so the setter itself succeeds.
EXP=$(psql "$DB_URL" -X -At -c "select jsonb_build_object('min_rest_hours', min_rest_hours, 'max_consecutive_days', max_consecutive_days, 'weekly_target_hours', weekly_target_hours) from public.institutions where id = '$INST'")
psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 > /dev/null <<SQL &
begin;
select private.institution_cell_lock('$ST', '$TF', '$DAY4');
select pg_sleep(1.5);
commit;
SQL
(sleep 0.2; apply "$LEAD" "$A8" "$TF" "$DAY4" > "$tmp/i1") &
(sleep 0.4; run_as "$LEAD" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_set_planning_limits('$INST', $LIM, null, '$EXP'::jsonb) r;" > "$tmp/i2") &
wait
i="$(norm "$tmp/i1")|$(norm "$tmp/i2")|$(count_px)"
echo "I apply|set_planning_limits|assignments: $i"
case "$i" in
  "planning_rule |ok |0"|"weekly_target_missing |ok |0") echo "ok - I: Wochensoll emptied during an apply: the setter and the apply serialise, R-h is never skipped";;
  *) echo "not ok - I: expected a serial outcome with no saved row (a saved row means R-h was skipped)"; fail=1;;
esac
psql_q <<SQL
set session_replication_role = replica;
delete from public.institution_audit_events where institution_id = '$INST' and command = 'institution_set_planning_limits' and id > $AUD0;
update public.institutions set weekly_target_hours = 42 where id = '$INST';
SQL

# J (HD-3a-F1 R-6-2 (b), migration 0188): lead and planner both saw Pensum 10 % / «alle Dienste» and save 50 % and 60 % at
# the same time. A superuser session holds the person row for 1 s so both calls wait on the same lock; run_as keeps each
# transaction open 0.3 s after its write, so the second compares against the first's committed row (READ COMMITTED
# re-reads the locked row). Serial outcome only: one «ok», one «changed_meanwhile», the stored Pensum is the winner's.
AUDJ=$(psql "$DB_URL" -X -At -c "select coalesce(max(id), 0) from public.institution_audit_events")
SHOWN='{"pensum_pct": 10, "shift_model": "any"}'
psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 > /dev/null <<SQL &
begin;
select 1 from public.institution_staff where id = '$PX' for update;
select pg_sleep(1);
commit;
SQL
(sleep 0.2; run_as "$LEAD" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_set_staff_planning('$PX', 50, 'any', '$SHOWN'::jsonb) r;" > "$tmp/j1") &
(sleep 0.3; run_as "$PLANNER" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_set_staff_planning('$PX', 60, 'any', '$SHOWN'::jsonb) r;" > "$tmp/j2") &
wait
jr="$(norm "$tmp/j1")|$(norm "$tmp/j2")"
jp=$(psql "$DB_URL" -X -At -c "select pensum_pct from public.institution_staff where id = '$PX'")
ja=$(psql "$DB_URL" -X -At -c "select count(*) from public.institution_audit_events where command = 'institution_set_staff_planning' and entity_id = '$PX' and id > $AUDJ")
echo "J lead|planner|stored Pensum|audit events: $jr|$jp|$ja"
case "$jr|$jp|$ja" in
  "ok |changed_meanwhile |50|1"|"changed_meanwhile |ok |60|1") echo "ok - J: two saves from the same shown Pensum: one wins, the other «changed_meanwhile», nothing overwritten silently";;
  *) echo "not ok - J: expected one ok and one changed_meanwhile with the winner's Pensum and one audit event"; fail=1;;
esac
psql_q -c "set session_replication_role = replica; delete from public.institution_audit_events where command = 'institution_set_staff_planning' and entity_id = '$PX' and id > $AUDJ"

# K (HD-3a-F3, migration 0189): PX has a target of exactly one early shift (510 min) for May 2030 and no shift there.
# The lead lowers it to 300 min (shown value 510) while the planner assigns PX the early shift on 2030-05-06. A superuser
# session holds the person row for 1 s so both calls queue on the same lock.
DAY5=2030-05-06
AUDK=$(psql "$DB_URL" -X -At -c "select coalesce(max(id), 0) from public.institution_audit_events")
psql_q -c "insert into public.institution_monthly_targets (institution_id, staff_id, period_month, target_minutes) values ('$INST', '$PX', '2030-05-01', 510)"
psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 > /dev/null <<SQL &
begin;
select 1 from public.institution_staff where id = '$PX' for update;
select pg_sleep(1);
commit;
SQL
(sleep 0.2; run_as "$LEAD" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_set_monthly_target('$PX', '2030-05-01', 300, '{\"target_minutes\": 510}'::jsonb) r;" > "$tmp/k1") &
(sleep 0.3; run_as "$PLANNER" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_assign_staff('$INST', '$ST', '$TF', '$DAY5', '$PX') r;" > "$tmp/k2") &
wait
kr="$(norm "$tmp/k1")|$(norm "$tmp/k2")"
kn=$(psql "$DB_URL" -X -At -c "select count(*) from public.institution_assignments where staff_id = '$PX' and work_date = '$DAY5'")
kt=$(psql "$DB_URL" -X -At -c "select target_minutes from public.institution_monthly_targets where staff_id = '$PX' and period_month = '2030-05-01'")
# Order of the two committed writes (audit ids): «a<t» = the assignment was saved before the target changed.
ko=$(psql "$DB_URL" -X -At -c "select case when (select min(id) from public.institution_audit_events where command = 'institution_assign_staff' and changed ->> 'staff_id' = '$PX' and id > $AUDK)
  < (select min(id) from public.institution_audit_events where command = 'institution_set_monthly_target' and changed ->> 'staff_id' = '$PX' and id > $AUDK) then 'a<t' else 't<a' end")
echo "K target|assign|saved|target|order: $kr|$kn|$kt|$ko"
case "$kr|$kn|$kt|$ko" in
  "ok |warning |0|300|t<a"|"ok |ok |1|300|a<t") echo "ok - K: a target lowered during an assignment: serial on the person lock, the shift is never saved against a target it breaks";;
  *) echo "not ok - K: expected the serial outcome (target first -> warning, nothing saved; or assignment first, then the target)"; fail=1;;
esac
psql_q <<SQL
set session_replication_role = replica;
delete from public.institution_audit_events where id > $AUDK and (changed ->> 'staff_id' = '$PX' or entity_id in (select id from public.institution_assignments where staff_id = '$PX'));
delete from public.institution_assignments where staff_id = '$PX' and work_date = '$DAY5';
delete from public.institution_monthly_targets where staff_id = '$PX';
SQL

# L (HD-PEN-HAND, migration 0190): PX has a Pensum (J left 50 or 60 %) and no shift in the week of 2030-06-03; the home
# has Wochensoll 42 and PX no monthly target for June 2030. The lead removes the Pensum (shown value = the stored one)
# while the planner assigns PX the early shift on 2030-06-03 without a confirmation. A superuser session holds the person
# row for 1 s so both calls queue on the same lock.
DAY6=2030-06-03
AUDL=$(psql "$DB_URL" -X -At -c "select coalesce(max(id), 0) from public.institution_audit_events")
SHOWNL=$(psql "$DB_URL" -X -At -c "select jsonb_build_object('pensum_pct', pensum_pct, 'shift_model', shift_model) from public.institution_staff where id = '$PX'")
psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 > /dev/null <<SQL &
begin;
select 1 from public.institution_staff where id = '$PX' for update;
select pg_sleep(1);
commit;
SQL
(sleep 0.2; run_as "$LEAD" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_set_staff_planning('$PX', null, 'any', '$SHOWNL'::jsonb) r;" > "$tmp/l1") &
(sleep 0.3; run_as "$PLANNER" "select coalesce(r -> 'problems' ->> 0, r ->> 'result') from public.institution_assign_staff('$INST', '$ST', '$TF', '$DAY6', '$PX') r;" > "$tmp/l2") &
wait
lr="$(norm "$tmp/l1")|$(norm "$tmp/l2")"
ln=$(psql "$DB_URL" -X -At -c "select count(*) from public.institution_assignments where staff_id = '$PX' and work_date = '$DAY6'")
lp=$(psql "$DB_URL" -X -At -c "select coalesce(pensum_pct::text, 'null') from public.institution_staff where id = '$PX'")
# Order of the two committed writes (audit ids): «a<p» = the assignment was saved before the Pensum was removed.
lo=$(psql "$DB_URL" -X -At -c "select case when (select min(id) from public.institution_audit_events where command = 'institution_assign_staff' and changed ->> 'staff_id' = '$PX' and id > $AUDL)
  < (select min(id) from public.institution_audit_events where command = 'institution_set_staff_planning' and entity_id = '$PX' and id > $AUDL) then 'a<p' else 'p<a' end")
echo "L pensum|assign|saved|pensum|order: $lr|$ln|$lp|$lo"
case "$lr|$ln|$lp|$lo" in
  "ok |warning |0|null|p<a"|"ok |ok |1|null|a<p") echo "ok - L: Pensum removed during a hand assignment: serial on the person lock, never saved unconfirmed without hours check";;
  *) echo "not ok - L: expected the serial outcome (Pensum removed first -> warning hours_unknown, nothing saved; or assignment first, then the removal)"; fail=1;;
esac
psql_q <<SQL
set session_replication_role = replica;
delete from public.institution_audit_events where id > $AUDL and (entity_id = '$PX' or changed ->> 'staff_id' = '$PX' or entity_id in (select id from public.institution_assignments where staff_id = '$PX'));
delete from public.institution_assignments where staff_id = '$PX' and work_date = '$DAY6';
SQL
exit $fail
