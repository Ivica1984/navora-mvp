#!/usr/bin/env bash
# e2e run-day guard (issue #635, ADR-113).
#
# The e2e job keeps the real clock (ADR-081): the seed dates its rows by the Zurich day of `supabase start`, and the
# app and the specs read "today" (Europe/Zurich) whenever they run. A run that crosses midnight Europe/Zurich therefore
# looks for visits on a day the seed did not fill and fails for reasons that are not the PR's.
#
#   wait   — before the seed: if fewer than E2E_DAY_MARGIN_MIN minutes (default 20; a green e2e job runs about
#            4 min from seed to end) are left until midnight Europe/Zurich, wait until 30 s after midnight, so
#            seed, app and specs share one day. Records the day.
#   check  — after Playwright: if the Zurich day changed during the run, says so in an annotation (diagnosis only;
#            the tests decide the job).
#
# E2E_GUARD_NOW (epoch seconds) replaces the clock and E2E_GUARD_DRY_RUN=1 prints the wait instead of sleeping; both
# exist for tests/unit/ci-e2e-day-guard.test.ts only.
set -euo pipefail

mode="${1:-}"
margin="${E2E_DAY_MARGIN_MIN:-20}"
state="${E2E_DAY_FILE:-${RUNNER_TEMP:-/tmp}/e2e-run-day}"
now="${E2E_GUARD_NOW:-$(date +%s)}"

zurich() { TZ=Europe/Zurich date -d "@$1" "$2"; }

case "$mode" in
  wait)
    hm="$(zurich "$now" +%H:%M)"
    secs_of_day=$((10#$(zurich "$now" +%H) * 3600 + 10#$(zurich "$now" +%M) * 60 + 10#$(zurich "$now" +%S)))
    # Midnight Europe/Zurich is never inside a DST change (those happen at 02:00 and 03:00), so a day has 86400 s here.
    left=$((86400 - secs_of_day))
    if [ "$left" -lt $((margin * 60)) ]; then
      wait_s=$((left + 30))
      echo "::notice title=e2e run-day guard::Zurich time ${hm}: ${left}s to midnight (< ${margin} min). Waiting ${wait_s}s so seed, app and specs use one day (#635)."
      if [ "${E2E_GUARD_DRY_RUN:-0}" = "1" ]; then
        echo "WAIT ${wait_s}"
      else
        sleep "$wait_s"
      fi
      now=$((now + wait_s))
    else
      echo "e2e run-day guard: Zurich time ${hm}, ${left}s to midnight, no wait."
      if [ "${E2E_GUARD_DRY_RUN:-0}" = "1" ]; then echo "WAIT 0"; fi
    fi
    day="$(zurich "$now" +%F)"
    echo "$day" > "$state"
    echo "e2e run day (Europe/Zurich): $day"
    ;;
  check)
    if [ ! -f "$state" ]; then
      echo "e2e run-day guard: no run day recorded (the job stopped before the guard), nothing to compare."
      exit 0
    fi
    start_day="$(cat "$state")"
    end_day="$(zurich "$now" +%F)"
    if [ "$start_day" != "$end_day" ]; then
      echo "::warning title=e2e run-day guard::The Zurich day changed during the run (${start_day} -> ${end_day}). Date-dependent failures in this run may come from the clock, not the change (#635); raise E2E_DAY_MARGIN_MIN."
      echo "CHANGED"
    else
      echo "e2e run day unchanged: $end_day"
    fi
    ;;
  *)
    echo "usage: $0 wait|check" >&2
    exit 2
    ;;
esac
