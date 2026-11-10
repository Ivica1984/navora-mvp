#!/usr/bin/env bash
# B0 runner ports (ADR-174): starts the local Supabase stack in CI.
#  1. Reserves the Supabase ports (54320-54329) from the kernel's ephemeral range, so no outbound connection opened
#     during the image pulls or the migrations takes one of them as its source port before Docker binds it.
#  2. Runs `supabase start` once (no retry) and keeps its exit status.
#  3. On failure, names an infrastructure failure as such in an annotation and prints the socket that holds the port,
#     so a red job that never ran a test is not read as a test result.
# Usage: scripts/ci-supabase-start.sh [extra args for supabase start]
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
node "$here/ci-supabase-start.mjs" --check-config "$here/../supabase/config.toml" || exit 1
range="$(node "$here/ci-supabase-start.mjs" --range)"
ports_filter="( sport >= :${range%-*} and sport <= :${range#*-} )"

if sudo -n sysctl -q -w "net.ipv4.ip_local_reserved_ports=${range}"; then
  echo "::notice title=supabase ports reserved::net.ipv4.ip_local_reserved_ports=$(cat /proc/sys/net/ipv4/ip_local_reserved_ports); ephemeral range $(tr '\t' '-' < /proc/sys/net/ipv4/ip_local_port_range)"
else
  echo "::warning title=supabase ports not reserved::sysctl net.ipv4.ip_local_reserved_ports=${range} failed; starting without the reservation (ADR-174)"
fi
held="$(ss -Htan "$ports_filter" 2>/dev/null || true)"
if [ -n "$held" ]; then
  echo "::warning title=supabase ports already in use before start::$(echo "$held" | sed -e 's/%/%25/g' | awk '{printf "%s%%0A", $0}')"
fi

out="$(mktemp)"
supabase start "$@" 2>&1 | tee "$out"
status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
  node "$here/ci-supabase-start.mjs" --classify "$out"
  echo "--- sockets on ${range} at failure (ADR-174 diagnosis) ---"
  sudo -n ss -tanpe "$ports_filter" 2>/dev/null || ss -tan "$ports_filter" 2>/dev/null
  echo "--- end ---"
fi
exit "$status"
