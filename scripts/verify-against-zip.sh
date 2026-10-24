#!/usr/bin/env bash
# Compare the agent-transcribed import (branch import/project-src-2026-10-21)
# with the original src.zip. Run on the owner's machine from the repo root:
#
#   git fetch origin && git switch import/project-src-2026-10-21
#   bash scripts/verify-against-zip.sh /path/to/src.zip
#
# Output "IDENTICAL" means every transcribed file matches the zip byte for byte.
# Any diff printed is a transcription error or a Project-upload artefact and
# must be reported to the Lead Engineer before recovery/main is merged to main.
set -euo pipefail

ZIP="${1:?usage: verify-against-zip.sh /path/to/src.zip}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "# src.zip sha256"
if command -v sha256sum >/dev/null; then sha256sum "$ZIP"; else shasum -a 256 "$ZIP"; fi

unzip -q "$ZIP" -d "$WORK"
ROOT="$WORK"
[ -d "$WORK/src" ] && ROOT="$WORK/src"

# Not transcribed on purpose (historic UI, not part of the build); listed so the
# diff stays readable. They arrive with the owner's byte-exact zip import.
EXCLUDES=(
  --exclude=operations-client.backup.tsx
  --exclude=operations-client.before-control-tower.tsx
  --exclude=favicon.ico
)

if diff -r "${EXCLUDES[@]}" "$ROOT" src; then
  echo "IDENTICAL (excluding the two backup UI files and favicon.ico)"
else
  echo "DIFFERENCES FOUND — see above"
  exit 1
fi
