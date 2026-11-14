#!/usr/bin/env bash
# WORK1-C5 (ADR-126, `cra` CGR-86, issue #603): evidence for the pgTAP 079 test 44 fix.
#  1. Probe (names the cause): two parallel transactions take the WORK1-5 catalogue of the five seed roles, wait 65 s
#     without doing anything themselves, and take it again. One runs at READ COMMITTED (as 079 did before the fix), one
#     at REPEATABLE READ (as 079 does now). Every role:object that differs is printed. A difference at READ COMMITTED
#     is a concurrent writer (the local stack's pg_cron jobs); a difference at REPEATABLE READ fails this script,
#     because then the fix does not hold.
#  2. Repeat: pgTAP 079 runs REPEATS times (default 50) through psql; every run must print 68 `ok` and no `not ok`.
# Needs the seeded local stack with the pinned database clock (run between "Database tests" and "Unpin").
# Writes nothing: every transaction rolls back. Usage: DB_URL=... REPEATS=50 work1-c5.sh
set -uo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
REPEATS="${REPEATS:-50}"
WAIT_SECONDS="${WAIT_SECONDS:-65}"
FILE="supabase/tests/database/079_work1_working_day.test.sql"
work="$(mktemp -d)"

probe_sql() { # $1 = isolation level
  cat <<SQL
begin isolation level $1;
create function pg_temp.act_as(uid text) returns void language sql as \$\$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
\$\$;
create function pg_temp.u(n text) returns text language sql immutable as \$\$
  select case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                else '00000000-0000-4000-a000-000000000905' end
\$\$;
SQL
  # The catalogue function exactly as pgTAP 079 defines it (one source of truth).
  awk '/^create function pg_temp.pin\(/{print} /^create function pg_temp.fingerprint\(/{f=1} f{print} f&&/^end \$\$;/{f=0}' "$FILE"
  cat <<SQL
create temp table b as select r.p, f.obj, f.hash from unnest(array['rn', 'ca', 'coach', 'ops', 'admin']) r(p), pg_temp.fingerprint(r.p) f;
select pg_sleep($WAIT_SECONDS);
create temp table a as select r.p, f.obj, f.hash from unnest(array['rn', 'ca', 'coach', 'ops', 'admin']) r(p), pg_temp.fingerprint(r.p) f;
select 'differs ' || coalesce(b.p, a.p) || ':' || coalesce(b.obj, a.obj)
from b full join a on a.p = b.p and a.obj = b.obj where b.hash is distinct from a.hash order by 1;
select 'objects ' || count(*) from a;
rollback;
SQL
}

echo "WORK1-C5 probe: catalogue at READ COMMITTED and REPEATABLE READ, ${WAIT_SECONDS} s apart, no own action"
probe_sql "read committed" | psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 > "$work/rc.out" 2>&1 &
p1=$!
probe_sql "repeatable read" | psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 > "$work/rr.out" 2>&1 &
p2=$!
wait $p1; s1=$?
wait $p2; s2=$?
status=0
echo "--- READ COMMITTED (exit $s1)"; grep -v '^$' "$work/rc.out"
echo "--- REPEATABLE READ (exit $s2)"; grep -v '^$' "$work/rr.out"
if [ "$s1" -ne 0 ] || [ "$s2" -ne 0 ]; then echo "probe: psql failed"; status=1; fi
if grep -q '^differs ' "$work/rr.out"; then echo "probe: REPEATABLE READ still differs: the fix does not hold"; status=1; fi
if ! grep -q '^differs ' "$work/rc.out"; then
  echo "probe: no concurrent write seen at READ COMMITTED in ${WAIT_SECONDS} s (cause not reproduced in this run; UNKNOWN, not a failure)"
fi

echo "WORK1-C5 repeat: pgTAP 079, ${REPEATS} runs"
green=0
for i in $(seq 1 "$REPEATS"); do
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -f "$FILE" > "$work/run.out" 2>&1
  rs=$?
  oks=$(grep -c '^ok ' "$work/run.out")
  bad=$(grep -c '^not ok ' "$work/run.out")
  if [ "$rs" -eq 0 ] && [ "$oks" -eq 68 ] && [ "$bad" -eq 0 ]; then
    green=$((green + 1))
  else
    echo "run $i: exit $rs, ok $oks, not ok $bad"
    grep -A4 '^not ok ' "$work/run.out" | head -20
    grep -i 'error' "$work/run.out" | head -5
    status=1
  fi
done
echo "WORK1-C5 repeat: ${green}/${REPEATS} runs green (68/68 each) at $(date -u +%H:%M) UTC"
rm -rf "$work"
exit "$status"
