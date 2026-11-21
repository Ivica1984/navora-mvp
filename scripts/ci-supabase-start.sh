#!/usr/bin/env bash
# B0 runner ports (ADR-174): starts the local Supabase stack in CI.
#  1. Reserves the Supabase ports (54320-54329) from the kernel's ephemeral range, so no outbound connection opened
#     during the image pulls or the migrations takes one of them as its source port before Docker binds it.
#  2. Runs `supabase start` and keeps its exit status. No retry (ADR-174), with one exception (ADR-204): a start the
#     image registry refused for its rate limit is retried ONCE from Docker Hub, logged in with the repository secrets
#     DOCKERHUB_USERNAME / DOCKERHUB_TOKEN. Without both secrets, or for any other failure, there is no retry.
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
start_stack() {
  supabase start "$@" 2>&1 | tee "$out"
  return "${PIPESTATUS[0]}"
}
start_stack "$@"
status=$?

# ADR-204: the one Docker Hub retry after a registry limit (decided by the classifier, never in a loop).
if [ "$status" -ne 0 ]; then
  fallback="$(node "$here/ci-supabase-start.mjs" --fallback "$out")"
  if [ -n "$fallback" ]; then
    echo "::warning title=registry limit: one retry from Docker Hub (ADR-204)::The default registry refused the pull; retrying once from ${fallback} with the repository's Docker Hub account."
    if printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin docker.io >/dev/null 2>&1; then
      supabase stop --no-backup >/dev/null 2>&1 || echo "::notice title=supabase stop::stop before the retry returned non-zero (nothing was running)"
      export SUPABASE_INTERNAL_IMAGE_REGISTRY="$fallback"
      start_stack "$@"
      status=$?
    else
      echo "::error title=Docker Hub login failed (ADR-204)::DOCKERHUB_USERNAME / DOCKERHUB_TOKEN were refused; no retry. Check the repository secrets."
    fi
  fi
fi

if [ "$status" -ne 0 ]; then
  node "$here/ci-supabase-start.mjs" --classify "$out"
  echo "--- sockets on ${range} at failure (ADR-174 diagnosis) ---"
  sudo -n ss -tanpe "$ports_filter" 2>/dev/null || ss -tan "$ports_filter" 2>/dev/null
  echo "--- end ---"
fi
exit "$status"
