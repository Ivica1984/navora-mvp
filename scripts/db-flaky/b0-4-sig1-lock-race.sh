#!/usr/bin/env bash
# B0-4 (PRODUCT_BLOCKS.md §4, issue #919, ADR-175): the pgTAP 080 SIG1 lock race, reproduced in real sessions.
# pgTAP runs inside one transaction and cannot open a second session, so this uses psql processes (as
# scripts/db-concurrency/sig1-evaluation-lock.sh and scripts/db-flaky/b0-3-079-snapshot.sh).
#
# private.evaluate_signals skips (returns 0, writes nothing) when another session holds the organisation's SIG1
# evaluation lock (0060: pg_try_advisory_xact_lock), as the pg_cron job `navora-sig1-signals` does during its run.
# On `f5f5e09` one of two runs of 080 failed 17/58, tests 6-9 "have" empty (#919). #922 (ADR-162) gave 080 a waiting
# lock of org A at its start.
#
#   (1) Before #922: today's 080 with exactly the #922 block removed (b0-4-strip-sig1-lock.mjs; plan 58), run while a
#       second session holds org A's lock. Must be red with tests 6 to 9 among the failures (the #919 signature).
#       Green = the race is not reproduced, and this script fails, because then it proves nothing.
#   (2) Today: 080 as it is, started while the second session holds the lock. It must wait for the lock (seen in
#       pg_locks as not granted), and once the holder ends, pass in full (59/59).
#   (3) Forced scheduler run: 062, 078 and 080 as they are, each while a second session runs the pg_cron job's own
#       command (`select private.evaluate_all_signals();`) again and again, each run committed. Each must pass in full.
#
# Side effects, by design: (3) commits evaluator runs, as pg_cron does every minute on the stack. Every pgTAP file
# rolls back. Runs after "Unpin the database clock": every file pins its own clock (navora.test_now, seed test-clock row).
# Usage: DB_URL=... b0-4-sig1-lock-race.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
ORG_A=00000000-0000-4000-b000-000000000011
F062="supabase/tests/database/062_sig1_safety_signal_delivery.test.sql"
F078="supabase/tests/database/078_leave1_14_claims_lapse.test.sql"
F080="supabase/tests/database/080_cond1_leave1_door1_conditions.test.sql"
HOLD_SECONDS=90
work="$(mktemp -d)"
holder=""
cleanup() {
  [ -n "$holder" ] && kill "$holder" 2>/dev/null || true
  psql "$DB_URL" -X -q -At -c "select count(pg_terminate_backend(pid)) from pg_stat_activity
    where application_name = 'b0-4-holder'" > /dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
status=0

LOCK_KEYS="classid::text::bigint = (hashtext('navora.sig1')::bigint & 4294967295)
  and objid::text::bigint = (hashtext('$ORG_A')::bigint & 4294967295)"

lock_rows() { # $1 = "true" (granted) or "false" (waiting); count of such rows on org A's SIG1 lock
  psql "$DB_URL" -X -At -c "select count(*) from pg_locks where locktype = 'advisory' and objsubid = 2
    and granted = $1 and $LOCK_KEYS"
}

hold_start() { # a second session takes org A's SIG1 lock and keeps it until hold_stop (at most HOLD_SECONDS)
  PGAPPNAME=b0-4-holder psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 > "$work/holder.out" 2>&1 <<SQL &
select pg_advisory_lock(hashtext('navora.sig1'), hashtext('$ORG_A'));
select pg_sleep($HOLD_SECONDS);
SQL
  holder=$!
  for _ in $(seq 1 50); do
    [ "$(lock_rows true)" = "1" ] && return 0
    sleep 0.2
  done
  echo "not ok - the holder session never took org A's SIG1 lock"; cat "$work/holder.out"; exit 1
}

hold_stop() { # ends the holder session; its session lock goes with it
  psql "$DB_URL" -X -q -At -c "select count(pg_terminate_backend(pid)) from pg_stat_activity
    where application_name = 'b0-4-holder'" > /dev/null
  wait "$holder" 2>/dev/null || true
  holder=""
  for _ in $(seq 1 50); do
    [ "$(lock_rows true)" = "0" ] && return 0
    sleep 0.2
  done
  echo "not ok - org A's SIG1 lock is still held after the holder ended"; exit 1
}

run_file() { # $1 = SQL file, $2 = output file; prints nothing, returns psql's exit code
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -f "$1" > "$2" 2>&1
}

planned() { grep -oE '^select plan\([0-9]+\);' "$1" | grep -oE '[0-9]+'; }
oks() { grep -cE '^ok [0-9]+' "$1" || true; }
fails() { grep -oE '^not ok [0-9]+' "$1" | grep -oE '[0-9]+' | tr '\n' ' ' | sed 's/ $//' || true; }

show_failures() { # first failures with their diagnostics, and any SQL error
  grep -A4 -E '^not ok [0-9]+' "$1" | head -24 | sed 's/^/    /' || true
  grep -iE '^(psql:|ERROR)' "$1" | head -5 | sed 's/^/    /' || true
}

echo "B0-4: pgTAP 080 SIG1 lock race (#919), in real sessions"

echo "(1) before #922: 080 without the CGR-110 block, while another session holds org A's SIG1 lock"
node scripts/db-flaky/b0-4-strip-sig1-lock.mjs "$F080" > "$work/080_before.sql"
hold_start
set +e; run_file "$work/080_before.sql" "$work/before.out"; rc=$?; set -e
hold_stop
red="$(fails "$work/before.out")"
echo "  exit $rc, plan $(planned "$work/080_before.sql"), ok $(oks "$work/before.out"), not ok: ${red:-none}"
missing=""
for t in 6 7 8 9; do
  grep -qE "^not ok $t( |$)" "$work/before.out" || missing="$missing $t"
done
if [ "$rc" -eq 0 ] && [ -z "$red" ]; then
  echo "not ok - before #922: 080 stayed green while another session held the lock (race not reproduced)"; status=1
elif [ -n "$missing" ]; then
  echo "not ok - before #922: red, but test(s)$missing not among the failures (shape differs from #919: 6-9 first)"
  show_failures "$work/before.out"; status=1
else
  # Every evaluation skips while the lock is held for the whole file, so later steps may also end in a SQL error
  # (rc != 0); the #919 signature is tests 6-9 failing with no delivery, which is what is required here.
  echo "ok - before #922: red as on f5f5e09 (#919): tests 6-9 fail; $(echo "$red" | wc -w) failed of $(planned "$work/080_before.sql"), psql exit $rc"
  show_failures "$work/before.out"
fi

echo "(2) today: 080 as it is, started while another session holds org A's SIG1 lock"
hold_start
set +e; run_file "$F080" "$work/today.out" & file=$!; set -e
waited=no
for _ in $(seq 1 100); do
  if [ "$(lock_rows false)" = "1" ]; then waited=yes; break; fi
  kill -0 "$file" 2>/dev/null || break
  sleep 0.2
done
hold_stop
set +e; wait "$file"; rc=$?; set -e
want="$(planned "$F080")"
echo "  waited for the lock: $waited; exit $rc, plan $want, ok $(oks "$work/today.out"), not ok: $(fails "$work/today.out")"
if [ "$waited" != "yes" ]; then
  echo "not ok - today: 080 did not wait for the lock (it finished or never queued while the holder had it)"; status=1
fi
if [ "$rc" -eq 0 ] && [ "$(oks "$work/today.out")" = "$want" ] && [ -z "$(fails "$work/today.out")" ]; then
  echo "ok - today: 080 waited for the lock, then passed $want/$want"
else
  echo "not ok - today: 080 is not green after the lock was released"; show_failures "$work/today.out"; status=1
fi

echo "(3) forced scheduler run: the pg_cron job's command, committed again and again, during each file"
for f in "$F062" "$F078" "$F080"; do
  name="$(basename "$f" .test.sql)"
  rm -f "$work/stop"; : > "$work/cron.log"
  (
    while [ ! -f "$work/stop" ]; do
      echo "start" >> "$work/cron.log"
      if psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -c "select private.evaluate_all_signals();" > "$work/cron.one" 2>&1; then
        echo "done $(cat "$work/cron.one")" >> "$work/cron.log"
      else
        echo "error $(tr '\n' ' ' < "$work/cron.one")" >> "$work/cron.log"
      fi
      sleep 0.3
    done
  ) & cron=$!
  for _ in $(seq 1 50); do grep -q '^done' "$work/cron.log" && break; sleep 0.2; done
  before_starts=$(grep -c '^start' "$work/cron.log" || true)
  set +e; run_file "$f" "$work/forced.out"; rc=$?; set -e
  after_starts=$(grep -c '^start' "$work/cron.log" || true)
  touch "$work/stop"; wait "$cron" || true
  want="$(planned "$f")"
  during=$((after_starts - before_starts))
  errors=$(grep -c '^error' "$work/cron.log" || true)
  echo "  $name: scheduler runs started during the file $during, committed in total $(grep -c '^done' "$work/cron.log" || true), errors $errors; exit $rc, ok $(oks "$work/forced.out")/$want, not ok: $(fails "$work/forced.out")"
  if [ "$errors" -ne 0 ]; then
    echo "not ok - forced scheduler run: the scheduler command failed during $name"; grep '^error' "$work/cron.log" | head -3; status=1
  elif [ "$during" -lt 1 ]; then
    echo "not ok - forced scheduler run: no scheduler run started while $name ran (proves nothing)"; status=1
  elif [ "$rc" -eq 0 ] && [ "$(oks "$work/forced.out")" = "$want" ] && [ -z "$(fails "$work/forced.out")" ]; then
    echo "ok - forced scheduler run: $name passed $want/$want"
  else
    echo "not ok - forced scheduler run: $name is not green"; show_failures "$work/forced.out"; status=1
  fi
done

exit "$status"
