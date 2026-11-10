#!/usr/bin/env bash
# B0-3 part 2 (PRODUCT_BLOCKS.md §4, issue #603, ADR-170): deterministic reproduction of the pgTAP 079 test 44 race,
# in two real sessions. pgTAP runs inside one transaction and cannot open a second session, so this uses psql
# processes (as scripts/db-concurrency/*.sh).
#
#   Session A takes the WORK1-5 catalogue of the five seed roles (the function exactly as 079 defines it), then waits
#   on an advisory gate, then takes it again and prints every role:object that differs. It writes nothing and rolls
#   back. Session B holds the gate, waits until A is blocked on it, runs the local stack's scheduled evaluator command
#   (`select private.evaluate_all_signals();`, the pg_cron job `navora-sig1-signals`) as its own committed
#   transaction, and opens the gate. So exactly one scheduler run commits between A's two catalogues, every time.
#
#   (1) READ COMMITTED (079 before #761): the second catalogue must differ (at least admin and ops:
#       signal_evaluator_health(), whose last_run_at the run updates). No difference = the race is not reproduced,
#       and the script fails, because then it proves nothing.
#   (2) REPEATABLE READ (079 since #761, ADR-126): the second catalogue must be identical. A difference fails the
#       script, because then the fix does not hold.
#
# Side effect, by design: session B commits one evaluator run, as the pg_cron job does every minute on the stack.
# Usage: DB_URL=... b0-3-079-snapshot.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
FILE="supabase/tests/database/079_work1_working_day.test.sql"
GATE=7903603 # advisory key of this script only (classid 0, objid 7903603)
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Helpers and the catalogue function from 079 itself: from pg_temp.act_as to the end of pg_temp.fingerprint.
helpers="$(awk '/^create function pg_temp\.act_as\(/{f=1} f{print} /^create function pg_temp\.fingerprint\(/{g=1} g&&/^end \$\$;/{exit}' "$FILE")"
grep -q 'create function pg_temp.fingerprint(' <<<"$helpers" || { echo "not ok - catalogue function not found in $FILE"; exit 1; }

waiting_on_gate() { # number of sessions blocked on the gate
  psql "$DB_URL" -X -At -c "select count(*) from pg_locks where locktype = 'advisory' and not granted
    and classid = 0 and objid = $GATE and objsubid = 1"
}

race() { # $1 = isolation level; prints session A's output
  local level="$1"
  # Session B: hold the gate, wait for A, commit one scheduler run, open the gate.
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 > "$work/b.out" 2>&1 <<SQL &
select pg_advisory_lock($GATE);
do \$\$ begin
  for i in 1..1200 loop
    exit when exists (select 1 from pg_locks where locktype = 'advisory' and not granted
                      and classid = 0 and objid = $GATE and objsubid = 1);
    perform pg_sleep(0.1);
  end loop;
  if not exists (select 1 from pg_locks where locktype = 'advisory' and not granted
                 and classid = 0 and objid = $GATE and objsubid = 1) then
    raise exception 'session A never reached the gate';
  end if;
end \$\$;
select 'scheduler run committed, evaluated=' || private.evaluate_all_signals();
select pg_advisory_unlock($GATE);
SQL
  local b=$!
  for _ in $(seq 1 50); do # until B holds the gate (at most 10 s)
    held=$(psql "$DB_URL" -X -At -c "select count(*) from pg_locks where locktype = 'advisory' and granted
      and classid = 0 and objid = $GATE and objsubid = 1")
    [ "$held" = "1" ] && break
    sleep 0.2
  done
  [ "$held" = "1" ] || { echo "not ok - session B never took the gate"; cat "$work/b.out"; exit 1; }
  # Session A: catalogue, gate, catalogue, differences.
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 > "$work/a.out" 2>&1 <<SQL || { echo "not ok - session A failed"; cat "$work/a.out"; exit 1; }
begin isolation level $level;
$helpers
create temp table b as select r.p, f.obj, f.hash from unnest(array['rn', 'ca', 'coach', 'ops', 'admin']) r(p), pg_temp.fingerprint(r.p) f;
select pg_advisory_xact_lock($GATE);
create temp table a as select r.p, f.obj, f.hash from unnest(array['rn', 'ca', 'coach', 'ops', 'admin']) r(p), pg_temp.fingerprint(r.p) f;
select 'differs ' || coalesce(b.p, a.p) || ':' || coalesce(b.obj, a.obj)
from b full join a on a.p = b.p and a.obj = b.obj where b.hash is distinct from a.hash order by 1;
select 'objects ' || count(*) from a;
rollback;
SQL
  wait "$b" || { echo "not ok - session B failed"; cat "$work/b.out"; exit 1; }
  grep -v '^$' "$work/b.out" | sed 's/^/  B: /'
  grep -v '^$' "$work/a.out" | sed 's/^/  A: /'
  [ "$(waiting_on_gate)" = "0" ] || { echo "not ok - a session is still blocked on the gate"; exit 1; }
}

status=0
echo "B0-3 079 snapshot race: one committed scheduler run between the two WORK1-5 catalogues"
echo "(1) READ COMMITTED (079 before #761)"
race "read committed"
if grep -q '^differs ' "$work/a.out"; then
  echo "ok - READ COMMITTED: the catalogue changed ($(grep -c '^differs ' "$work/a.out") role:object), as 079 test 44 failed"
else
  echo "not ok - READ COMMITTED: no difference after a committed evaluator run (race not reproduced)"; status=1
fi
echo "(2) REPEATABLE READ (079 since #761, ADR-126)"
race "repeatable read"
if grep -q '^differs ' "$work/a.out"; then
  echo "not ok - REPEATABLE READ: the catalogue changed, so the fix does not hold"; status=1
elif grep -q '^objects ' "$work/a.out"; then
  echo "ok - REPEATABLE READ: identical catalogue ($(grep '^objects ' "$work/a.out" | cut -d' ' -f2) role:object rows)"
else
  echo "not ok - REPEATABLE READ: session A printed no catalogue"; status=1
fi
exit "$status"
