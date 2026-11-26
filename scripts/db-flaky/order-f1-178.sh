#!/usr/bin/env bash
# ORDER-F1-178 probe (unmerged probe branch, not a fix): pgTAP 178 (ORDER-F1) hung until the 30-min `db` job timeout in
# three CI runs since 0178 merged (jobs 139560106196, 139586627305, 139587468106: 177 printed «ok», 178 never finished),
# while it takes about 41 s when it passes (job 139594153646). This script names WHERE it hangs and WHY:
#  1. pgTAP 178 runs REPEATS times through psql with `\timing on` and echo of every statement, so the last echoed statement
#     of a hanging run is the statement that does not end; every run is bounded by RUN_SECONDS (then cancelled from outside).
#  2. While a run lasts, a watcher prints every RUN_WATCH seconds the probe backend's state, wait event (Lock = waiting
#     for another session, empty = computing), blocking pids and the blocking sessions' queries (pg_cron jobs show here).
# Needs the seeded local stack with the pinned database clock (run after "Seed"). Writes nothing: 178 rolls back.
# Usage: DB_URL=... REPEATS=12 RUN_SECONDS=300 order-f1-178.sh
set -uo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
REPEATS="${REPEATS:-12}"
RUN_SECONDS="${RUN_SECONDS:-300}"
RUN_WATCH="${RUN_WATCH:-20}"
FILE="supabase/tests/database/178_order_f1_member_step_visit_window.test.sql"
PLAN=$(grep -oE 'select plan\([0-9]+\)' "$FILE" | grep -oE '[0-9]+')
work="$(mktemp -d)"
status=0
green=0
hung=0

watch_sql() {
  cat <<SQL
select now()::time(0) || ' probe pid ' || a.pid || ' state ' || a.state || ' wait ' || coalesce(a.wait_event_type || ':' || a.wait_event, '-')
       || ' for ' || (now() - a.query_start)::interval(0) || ' blocked by ' || coalesce(nullif(pg_blocking_pids(a.pid)::text, '{}'), '-')
       || ' | ' || left(regexp_replace(a.query, '\s+', ' ', 'g'), 160)
from pg_stat_activity a where a.application_name = 'order-f1-178-probe';
select now()::time(0) || '   blocker pid ' || b.pid || ' ' || coalesce(b.application_name, '') || ' ' || coalesce(b.backend_type, '')
       || ' state ' || coalesce(b.state, '-') || ' wait ' || coalesce(b.wait_event_type || ':' || b.wait_event, '-')
       || ' | ' || left(regexp_replace(coalesce(b.query, ''), '\s+', ' ', 'g'), 160)
from pg_stat_activity a, unnest(pg_blocking_pids(a.pid)) bp join pg_stat_activity b on b.pid = bp
where a.application_name = 'order-f1-178-probe';
select now()::time(0) || '   other active: pid ' || pid || ' ' || coalesce(application_name, '') || ' ' || backend_type || ' wait '
       || coalesce(wait_event_type || ':' || wait_event, '-') || ' | ' || left(regexp_replace(query, '\s+', ' ', 'g'), 120)
from pg_stat_activity where state = 'active' and pid <> pg_backend_pid() and application_name <> 'order-f1-178-probe'
  and backend_type in ('client backend', 'pg_cron', 'background worker', 'autovacuum worker');
SQL
}

echo "ORDER-F1-178 probe: pgTAP 178 (${PLAN} tests), ${REPEATS} runs, each bounded by ${RUN_SECONDS} s, watcher every ${RUN_WATCH} s"
for i in $(seq 1 "$REPEATS"); do
  start=$(date +%s)
  { echo '\timing on'; cat "$FILE"; } | PGAPPNAME=order-f1-178-probe timeout --signal=INT "$RUN_SECONDS" \
    psql "$DB_URL" -X -q -At -a -v ON_ERROR_STOP=1 > "$work/run.out" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$RUN_WATCH"
    kill -0 "$pid" 2>/dev/null || break
    watch_sql | psql "$DB_URL" -X -q -At >> "$work/watch.out" 2>&1
  done
  wait "$pid"; rs=$?
  secs=$(( $(date +%s) - start ))
  oks=$(grep -c '^ok ' "$work/run.out")
  bad=$(grep -c '^not ok ' "$work/run.out")
  if [ "$rs" -eq 0 ] && [ "$oks" -eq "$PLAN" ] && [ "$bad" -eq 0 ]; then
    green=$((green + 1))
    echo "run $i: green in ${secs} s; $(grep -m1 'ORDER-F1 budget: ' "$work/run.out" | sed 's/^# //')"
  else
    status=1
    [ "$secs" -ge "$RUN_SECONDS" ] && hung=$((hung + 1))
    echo "run $i: exit $rs after ${secs} s, ok $oks, not ok $bad"
    echo "--- run $i: the last 40 lines (the last echoed statement is the one that did not end)"
    tail -40 "$work/run.out"
    echo "--- run $i: watcher"
    cat "$work/watch.out"
    grep -A4 '^not ok ' "$work/run.out" | head -20
  fi
  # Slowest statements of the run (psql \timing lines), also for green runs: where the 41 s go.
  echo "run $i slowest: $(grep -oE '^Time: [0-9.]+ ms' "$work/run.out" | awk '{print $2}' | sort -rn | head -5 | tr '\n' ' ')"
  : > "$work/watch.out"
done
echo "ORDER-F1-178 probe: ${green}/${REPEATS} green, ${hung} hung (bounded at ${RUN_SECONDS} s) at $(date -u +%H:%M) UTC"
rm -rf "$work"
exit "$status"
