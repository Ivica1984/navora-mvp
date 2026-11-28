# NAVORA — Recovery Log

Chronological record of how the recovered application code entered Git.
Every entry states its source, what was verified and what was not.

## 2026-10-21 — Import of the Project copies (branch `import/project-src-2026-10-21`)

**Source:** the 24 `src/…` files uploaded to the claude.ai Project "NAVORA" on
2026-10-20 15:55 UTC. These are copies of `src.zip` made by the owner; the zip itself
was not available to the agent.

**Method:** the Lead Engineer (Claude) read each file from the Project and wrote it to
disk unchanged, including known defects (stray line numbers in `src/app/page.tsx`,
`as any` casts, missing trailing newlines). No file was cleaned up in this commit.

**Fidelity:** NOT byte-verified. The agent caught and corrected one of its own
transcription slips during the import (a dropped `fontWeight: 700` in
`operations-client.tsx`). Other slips cannot be ruled out until the owner runs
`scripts/verify-against-zip.sh /path/to/src.zip` and it prints `IDENTICAL`.

**Not imported (deliberately):**

| File | Reason |
|---|---|
| `src/app/operations/operations-client.backup.tsx` | historic UI, not routed; large; transcription risk without build value |
| `src/app/operations/operations-client.before-control-tower.tsx` | same |

Both remain in the Project and in the zip, and arrive with the owner's byte-exact
import (`preserve/src-zip-2026-10-20`, runbook T2) or are added to
`docs/legacy-ui/` from there.

**Unchanged from `main`:** `src/app/layout.tsx`, `src/app/globals.css` and
`src/app/favicon.ico` are byte-identical between `main` and the Project copies
(verified with `md5sum`/`cmp`).

**Checksums:** `docs/recovery/PROJECT_SRC_MANIFEST.sha256` (SHA-256 of every file under
`src/` on this branch).

**Codespace:** NOT checked. The agent's GitHub access is scoped to this repository and
cannot list Codespaces (HTTP 403). The 48-h timebox (ADR-001) runs from the owner's
check.

## Known legacy risks carried by this import (unchanged on purpose)

See `docs/engineering/SECURITY_RISKS.md`: SR-02 (anon server queries), SR-06
(health-data over-fetch), SR-07 (no route protection, login bypass link), SR-08
(browser writes), SR-09 (client sets `billable`). These are fixed in T8–T10, not here.
