#!/usr/bin/env bash
# CGR-110 (#399, ADR-137): evidence for the cause of the pgTAP 062 tests 47/50 failures, in two real sessions.
# pgTAP runs inside one transaction and cannot open a second session, so this check uses two psql processes
# (as cover-accept.sh). Nothing is committed: every fixture lives in a transaction that is rolled back.
#
#   (i)   Scheduler state: is the pg_cron job `navora-sig1-signals` scheduled, and how long do its runs take?
#         Printed for the record only (the stack may lack pg_cron; then nothing is printed and nothing fails).
#   (ii)  Mechanism: while another session holds org B's SIG1 evaluation lock (as a scheduler run does),
#         `private.evaluate_signals(org B, true)` in this session returns 0 and writes no delivery for the 062
#         visit-5 fixture: exactly the 062 failure (have empty, have 0). Fails if the call does not skip.
#   (iii) Remedy: the same session first waits for the lock (as 062 now does), then the evaluation writes the
#         fallback delivery `903=operations_fallback`. Fails otherwise.
# Pinned clock in the evaluating session: 12:00 Zurich today, as 062 (needs the seed's test-clock row).
# Usage: DB_URL=... sig1-evaluation-lock.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
ORG_B=00000000-0000-4000-b000-000000000012
TEAM_B=00000000-0000-4000-a000-000000000151
CASE_B=00000000-0000-4000-a000-000000000251
VISIT=a1100000-0000-4000-8000-000000000005
HOLD_SECONDS=6

echo "(i) scheduler state"
psql "$DB_URL" -X -At -v ON_ERROR_STOP=0 <<SQL || true
select 'cron job: ' || jobname || ' schedule ' || schedule || ' active ' || active
from cron.job where command like '%private.evaluate_all_signals()%';
select 'last runs: ' || coalesce(string_agg(status || ' ' || round(extract(epoch from (end_time - start_time))::numeric, 3) || ' s',
                                            ', ' order by start_time desc), 'none')
from (select d.status, d.start_time, d.end_time from cron.job_run_details d join cron.job j on j.jobid = d.jobid
      where j.command like '%private.evaluate_all_signals()%' order by d.start_time desc limit 5) r;
SQL

hold_lock() {  # holds org B's SIG1 evaluation lock for HOLD_SECONDS, like a scheduler run
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select pg_advisory_xact_lock(hashtext('navora.sig1'), hashtext('$ORG_B'));
select pg_sleep($HOLD_SECONDS);
commit;
SQL
}

wait_for_holder() {  # until another backend holds the lock (at most 10 s)
  for _ in $(seq 1 50); do
    held=$(psql "$DB_URL" -X -At -c "select count(*) from pg_locks where locktype = 'advisory' and granted and objsubid = 2
      and classid::text::bigint = (hashtext('navora.sig1')::bigint & 4294967295)
      and objid::text::bigint = (hashtext('$ORG_B')::bigint & 4294967295) and pid <> pg_backend_pid()")
    [ "$held" = "1" ] && return 0
    sleep 0.2
  done
  echo "not ok - the holder session never took the lock"; exit 1
}

evaluate() {  # $1 = "wait" to take the lock first (the 062 remedy), "" to call as 062 did before
  local first=""
  [ "$1" = "wait" ] && first="select pg_advisory_xact_lock(hashtext('navora.sig1'), hashtext('$ORG_B'));"
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '12:00') at time zone 'Europe/Zurich')::text, true);
$first
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
values ('$ORG_B', '$VISIT', '$CASE_B', '$TEAM_B',
        ((private.now() - interval '2 hours') at time zone 'Europe/Zurich')::date,
        ((private.now() - interval '2 hours') at time zone 'Europe/Zurich')::time(0), null, false, 'planned', null);
select 'returned=' || private.evaluate_signals('$ORG_B', true);
select 'recipients=' || coalesce(string_agg(right(d.recipient_id::text, 3) || '=' || d.reason, ',' order by d.recipient_id), '')
from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
where s.visit_id = '$VISIT' and s.ended_at is null;
rollback;
SQL
}

echo "(ii) evaluation while another session holds the lock"
hold_lock > /dev/null &
holder=$!
wait_for_holder
out=$(evaluate "")
wait "$holder"
echo "$out"
if echo "$out" | grep -qx 'returned=0' && echo "$out" | grep -qx 'recipients='; then
  echo "ok - a concurrent lock holder makes evaluate_signals skip: no delivery (the 062 tests 47/50 signature)"
else
  echo "not ok - expected returned=0 and no recipient while the lock is held elsewhere"; exit 1
fi

echo "(iii) evaluation that waits for the lock first (062 remedy)"
hold_lock > /dev/null &
holder=$!
wait_for_holder
out=$(evaluate "wait")
wait "$holder"
echo "$out"
if echo "$out" | grep -qx 'recipients=903=operations_fallback'; then
  echo "ok - after waiting for the lock the evaluation delivers to org B's admin (903=operations_fallback)"
else
  echo "not ok - expected recipients=903=operations_fallback after waiting for the lock"; exit 1
fi
