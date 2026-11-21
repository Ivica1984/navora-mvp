# NAVORA — Verified State Report

**Verified:** 2026-10-21 ~12:58 CEST · **Method:** GitHub REST API only (`gh api repos/Ivica1984/navora-mvp/...`), not the agent's local clone.
**Labels:** VERIFIED = returned by the API in this check · NOT PRESENT = API returned 404/empty · UNKNOWN.

## 1. Branches — VERIFIED

| Branch | Head | Protected | Role |
|---|---|---|---|
| `main` | `5a7f0b0` | **no** | default; still the docs + static mock |
| `recovery/main` | `332c607` | **no** | integration trunk, 21 commits ahead of `main`, 0 behind |
| `import/project-src-2026-10-21` | `f274ee7` | **no** | transcribed import; ancestor of `recovery/main` (20 behind it, 0 ahead) |
| `feat/rec-ci` | `3ac24ff` | no | merged (#1), not deleted |
| `docs/m2-readiness` | `ed0524a` | no | merged (#4), not deleted |
| `docs/owner-runbook` | `a9d4124` | no | merged (#5), not deleted |

Rulesets: `[]` (none). Classic protection on `main`: "Branch not protected" (404).
Secret scanning, push protection, Dependabot security updates: all `disabled`. Visibility: **public**.

## 2. Pull requests — VERIFIED

| # | State | Head → Base | Notes |
|---|---|---|---|
| 1 | merged 10:23 UTC | `feat/rec-ci` → `recovery/main` | M1 (T3–T7) |
| 2 | closed, not merged | `import/…` → `main` | auto-opened on push; closed on purpose |
| 3 | **open**, `mergeable=true`, `state=clean`, 21 commits, 51 files | `recovery/main` → `main` | M2; "clean" only because no checks are required yet |
| 4 | merged 10:28 UTC | `docs/m2-readiness` → `recovery/main` | registers + README |
| 5 | merged 10:32 UTC | `docs/owner-runbook` → `recovery/main` | owner runbook |

All merges into `recovery/main` are merge commits (2 parents) — VERIFIED.

## 3. Workflows — VERIFIED

| Workflow | Path | State | Latest result |
|---|---|---|---|
| `ci` | `.github/workflows/ci.yml` | active | success on `recovery/main@332c607` (push and PR): `app` + `db` |
| `lockfile-sync` | `.github/workflows/lockfile-sync.yml` | active | success (last on `recovery/main@b50e479`; no bot commit was needed) |

Last failing CI run: `feat/rec-ci@46ba3fa` (typecheck on `getCasesWithVisits`), fixed in `3ac24ff`.
`main` has **0** check runs: no workflow file exists on `main` yet.

## 4. ADR documents — VERIFIED, with one deviation

- `docs/engineering/DECISIONS.md` on `recovery/main` contains **ADR-001 … ADR-016** (16 entries).
  Status as written: ACCEPTED 1 (ADR-012), "ACCEPTED in practice, owner confirmation pending" 5 (004, 006, 008, 009, 010), PROPOSED 10.
- **Deviation:** `docs/adr/` does **NOT EXIST** (API 404). The execution plan said "ADRs for D1–D11" and the old decision log said entries "graduate to `docs/adr/`"; no entry has. The ADRs exist only as sections of one file. This is acceptable for the current size; no owner has accepted any ADR yet.

## 5. docs/engineering — VERIFIED (on `recovery/main` only)

`BACKLOG.md`, `DECISIONS.md`, `OWNER_RUNBOOK.md`, `ROADMAP.md`, `SECURITY_RISKS.md`, `TECH_DEBT.md`.
Also present: `docs/recovery/RECOVERY_LOG.md`, `docs/recovery/PROJECT_SRC_MANIFEST.sha256`, `docs/proposals/CURRENT_IMPLEMENTATION_STATUS.update.md`.
On `main`: **none** of these exist. `RECOVERY_RUNBOOK.md` exists only in the claude.ai Project, not in the repo.

## 6. Other checks

| Check | Result |
|---|---|
| Manifest vs files on the import branch (3 sampled: `operations/types.ts`, `lib/supabase.ts`, `visits-client.tsx`) | SHA-256 match — VERIFIED for those 3 only |
| Manifest vs `src.zip` | NOT VERIFIED (owner step O-C) |
| Codespace | UNKNOWN (agent token cannot list Codespaces) |
| Live database exposure | UNKNOWN (owner step O-E) |

## 7. Corrections to the previous status message

1. "Registers are in the repo" — true for `recovery/main` only; `main` gets them with M2.
2. "Decision log ADR-001–016" — true, as one file, not as `docs/adr/` documents.
3. PR #3 shows "clean" — this reflects missing required checks, not a review.
4. Three merged feature branches were left in place (not deleted).

## Verdict

Everything previously reported as existing exists on GitHub. The deviations are about precision,
not missing work. **Verification succeeded → T8 proceeds**, on a branch from `recovery/main`.
Owner-side gaps (protection, scanning, visibility, zip, Codespace, live DB) are unchanged and do not block T8.
