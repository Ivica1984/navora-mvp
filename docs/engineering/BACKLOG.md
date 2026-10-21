# NAVORA — Engineering Backlog

**Maintained by:** Lead Engineer (Claude) · **Last updated:** 2026-10-21 (after T14)
**Plan:** `claude/NAVORA_RECOVERY_EXECUTION_PLAN.md` (Project) · **Roadmap:** `docs/engineering/ROADMAP.md`
**Status values:** BLOCKED · READY · IN PROGRESS · IN REVIEW · DONE · PROPOSED
Ordered by priority. Work continues on the top item that is not blocked.

---

## Owner actions (blocking or gating)

| ID | Action | Gates | Why the agent cannot do it |
|---|---|---|---|
| O-A | **Branch rulesets:** `main` and `recovery/main` PR-only, required check `ci / app` + `ci / db`, no force-push/deletion; `preserve/**` and tags `preserve-*`, `v*` immutable | T2, T7 acceptance, M2 | GitHub settings writes are blocked for the agent (HTTP 403) |
| O-B | **Secret scanning + push protection + Dependabot alerts** (Settings → Code security) | T2 | same |
| O-C | **Verify the transcribed import:** `git switch import/project-src-2026-10-21 && bash scripts/verify-against-zip.sh /path/to/src.zip` → must print `IDENTICAL` | M2 merge | zip only on the owner's machine |
| O-D | **Codespace check:** `gh codespace list`; if one exists, preserve it (runbook T1) | ADR-001 timebox | agent token cannot list Codespaces (HTTP 403) |
| O-E | **Live DB containment check:** real patient data in the live Supabase project? anon access? anything deployed with its anon key? | SR-01, SR-12 | no access to the live project — correctly so |
| O-F | **Schema-only pull of live** (`supabase db pull --schema public`) | replaces reconstructed baseline | same |
| O-G | Approve or reject ADR-001…ADR-017 | — | owner decision |

## Recovery (M0–M2)

| ID | Task | Status | Evidence |
|---|---|---|---|
| T1 | Secure sources (Codespace, zip + checksum) | BLOCKED (O-C, O-D) | — |
| T2 | Protect `main`; preservation branch; `recovery/main` | PARTLY DONE | `import/project-src-2026-10-21` + `recovery/main` pushed; protection is O-A/O-B |
| T3 | Deps + Next 16.4.1 security upgrade, scripts, `.env.example` | DONE | PR #1, CI: audit 0 vulnerabilities, next 16.4.1, sharp 0.35.5 |
| T4 | Local Supabase + reconstructed baseline + legacy policies migration | DONE | PR #1, CI: `db reset` pass |
| T5 | Synthetic seed covering every attention rule | DONE | PR #1, seed applies in CI; per-rule coverage asserted by Vitest, not yet by a DB-level test |
| T6 | Green build (one commit per fix) | DONE | PR #1, CI: lint/typecheck/build pass |
| T7 | CI pipeline | DONE (acceptance pending O-A) | PR #1; "PR blocked by failing test" needs required checks |
| M2 | `recovery/main → main` by merge commit, tag `v0.1.0-recovered` | IN REVIEW | PR opened; merge gated on O-A, O-C and owner approval |

## Security foundation (M3 — Roadmap Gate 1)

| ID | Task | Status | Depends on |
|---|---|---|---|
| T8 | SSR auth, proxy guard, `(protected)` group, server sign-in/out, browser writes → Server Actions | DONE | PR #7 merged into `recovery/main` |
| T9 | Tenancy, scoped RLS, legacy policies dropped, anon privileges revoked, cross-tenant FKs | DONE | PR #8 merged into `recovery/main` |
| T10 | Audit trigger + append-only log; idempotent DB commands; visit state machine; `billable` locked; minimal Operations payload | DONE | PR #9 merged into `recovery/main` |
| T11 | Nonce-based CSP + security headers, no `X-Powered-By` | DONE | PR #10 merged into `recovery/main` |
| T12 | Staging: Supabase project (EU/CH region) + protected Next host, migrations from CI, synthetic seed + staging-only users | **BLOCKED — owner decision** | O-G / ADR-011: hosting provider and region (cost + data residency = financial/legal decision); then a deploy token as a GitHub secret |
| T13 | DB-level seed coverage test: one pgTAP/SQL check per attention category | PROPOSED | — |
| T14 | Generated `database.types.ts`, typed client, drift check in CI, compile-time proof | IN REVIEW | PR #11 — CI on `1a41e83` green; drift check "in sync" |
| T15 | Replace `alert()` with an inline error/status model in Teams/Visits (TD-12) | PROPOSED | — |

## Product (M4 — Roadmap Gate 2)

| ID | Task | Status |
|---|---|---|
| F1 | `/field` own-visits list (mobile-first), RLS: only assigned visits | PROPOSED |
| F2 | Visit state machine as DB functions + `visit_events` + idempotency | PROPOSED — transitions need product/clinical confirmation |
| F3 | Time segments (travel/care/pause) with correction events | PROPOSED |
| F4 | Structured observation note (author/time/source), no AI | PROPOSED |
| F5 | E2E + RLS-negative suite for the field workflow | PROPOSED |

## Open questions (product)

| ID | Question |
|---|---|
| Q1 | Purpose of the live `orders` table (not reconstructed) |
| Q2 | TD-09: should a case without team in `teampruefung` raise one or two attention items? |
| Q3 | Operations recommends "Matching starten" though Operations must not trigger matching (DOMAIN_RULES) — reword? |
| Q4 | Real role set and permission matrix. T9 uses placeholders: read = any org member (incl. health fields), team settings = admin/coach, visits = own team. Needs product + data-protection decision before real users |
| Q5 | Who creates organisations and memberships, and how (no UI/API yet — SQL only) |
| Q6 | **Legal:** retention period and access rules for `audit_events` (who may read, how long kept, export for audits) — needed before real data |
