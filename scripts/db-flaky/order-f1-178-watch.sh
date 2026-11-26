#!/usr/bin/env bash
# ORDER-F1-178 watcher (unmerged probe): pgTAP 178 hangs only inside the full suite (3 of ~13 CI db runs), never alone
# (12/12 green in 40 s each after the seed, probe job 139603225718). This runs beside the real "Database tests" step.
#   start  : prints which seeded public tables autovacuum has not analyzed yet, then starts a background loop that every
#            WATCH_SECONDS writes each client backend active longer than LONG_SECONDS (state, wait event: Lock = waits for
#            another session, empty = computing; blocking pids and their queries; tables still never analyzed).
#   report : prints what the loop wrote (run with `if: always()`, so it also runs when the job hits its timeout).
# Read-only: only pg_stat_activity, pg_stat_user_tables and pg_locks are read.
set -uo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
WATCH_SECONDS="${WATCH_SECONDS:-30}"
LONG_SECONDS="${LONG_SECONDS:-60}"
OUT="${RUNNER_TEMP:-/tmp}/order-f1-178-watch.log"

never_analyzed_sql="select now()::time(0) || ' never analyzed: ' || coalesce(string_agg(relname || ' (' || n_live_tup || ')', ', ' order by relname), 'none')
from pg_stat_user_tables where schemaname = 'public' and n_live_tup > 0 and last_analyze is null and last_autoanalyze is null;"

long_sql="select now()::time(0) || ' long pid ' || a.pid || ' ' || coalesce(a.application_name, '') || ' state ' || a.state
       || ' wait ' || coalesce(a.wait_event_type || ':' || a.wait_event, '-') || ' for ' || (now() - a.query_start)::interval(0)
       || ' blocked by ' || coalesce(nullif(pg_blocking_pids(a.pid)::text, '{}'), '-')
       || ' | ' || left(regexp_replace(a.query, '\s+', ' ', 'g'), 200)
from pg_stat_activity a
where a.state = 'active' and a.backend_type = 'client backend' and a.pid <> pg_backend_pid()
  and now() - a.query_start > make_interval(secs => $LONG_SECONDS)
union all
select now()::time(0) || '   blocker pid ' || b.pid || ' ' || coalesce(b.application_name, '') || ' ' || b.backend_type
       || ' state ' || coalesce(b.state, '-') || ' wait ' || coalesce(b.wait_event_type || ':' || b.wait_event, '-')
       || ' | ' || left(regexp_replace(coalesce(b.query, ''), '\s+', ' ', 'g'), 200)
from pg_stat_activity a, unnest(pg_blocking_pids(a.pid)) bp join pg_stat_activity b on b.pid = bp
where a.state = 'active' and a.backend_type = 'client backend' and now() - a.query_start > make_interval(secs => $LONG_SECONDS);"

case "${1:-}" in
  start)
    psql "$DB_URL" -X -q -At -c "$never_analyzed_sql" | tee "$OUT"
    (
      while true; do
        sleep "$WATCH_SECONDS"
        lines=$(psql "$DB_URL" -X -q -At -c "$long_sql" 2>&1)
        if [ -n "$lines" ]; then
          echo "$lines" >> "$OUT"
          psql "$DB_URL" -X -q -At -c "$never_analyzed_sql" >> "$OUT" 2>&1
        fi
      done
    ) > /dev/null 2>&1 &
    disown
    echo "ORDER-F1-178 watcher started (every ${WATCH_SECONDS} s, statements longer than ${LONG_SECONDS} s) -> $OUT"
    ;;
  report)
    echo "ORDER-F1-178 watcher report ($OUT):"
    cat "$OUT" 2>/dev/null || echo "(no file)"
    grep -q ' long pid ' "$OUT" 2>/dev/null || echo "no statement ran longer than ${LONG_SECONDS} s"
    ;;
  *) echo "usage: $0 start|report"; exit 2 ;;
esac
