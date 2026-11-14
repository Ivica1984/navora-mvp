#!/usr/bin/env bash
# Runs one CI step, keeps its full output in the job log, and re-emits the tail
# as a GitHub annotation so results are readable from the checks API
# (the agent can read annotations but not raw job logs — ADR-014).
# Usage: scripts/ci-step.sh <label> <command...>
set -uo pipefail
label="$1"; shift
out="$(mktemp)"
"$@" 2>&1 | tee "$out"
status=${PIPESTATUS[0]}
tail_text="$(tail -n 40 "$out" | sed -e 's/%/%25/g' -e 's/\r//g' | awk '{printf "%s%%0A", $0}')"
if [ "$status" -eq 0 ]; then
  echo "::notice title=${label} passed::$(tail -n 8 "$out" | sed -e 's/%/%25/g' | awk '{printf "%s%%0A", $0}')"
else
  echo "::error title=${label} failed (exit ${status})::${tail_text}"
fi
exit "$status"
