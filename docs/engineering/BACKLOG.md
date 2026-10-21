# NAVORA — Engineering Backlog

**Maintained by:** Lead Engineer (Claude) · **Last updated:** 2026-10-21 (J1–J3 done; priorities via docs/agents)
**Plan:** `claude/NAVORA_RECOVERY_EXECUTION_PLAN.md` (Project) · **Roadmap:** `docs/engineering/ROADMAP.md`
**Status values:** BLOCKED · READY · IN PROGRESS · IN REVIEW · DONE · PROPOSED
Ordered by priority. Work continues on the top item that is not blocked.

---

## Owner actions (blocking or gating)

Decision brief with options and recommendations: [`DECISIONS_NEEDED.md`](DECISIONS_NEEDED.md) (D-1 … D-8).


| ID | Action | Gates | Why the agent cannot do it |
|---|---|---|---|
| O-A | **Branch rulesets:** `main` and `recovery/main` PR-only, required check `ci / app` + `ci / db`, no force-push/deletion; `preserve/**` and tags `preserve-*`, `v*` immutable | T2, T7 acceptance, M2 | GitHub settings writes are blocked for the agent (HTTP 403) |
| O-B | **Secret scanning + push protection + Dependabot alerts** (Settings → Code security) | T2 | same |
| O-C | **Verify the transcribed import:** `git switch import/project-src-2026-10-21 && bash scripts/verify-against-zip.sh /path/to/src.zip` → must print `IDENTICAL` | M2 merge | zip only on the owner's machine |
| O-D | **Codespace check:** `gh codespace list`; if one exists, preserve it (runbook T1) | ADR-001 timebox | agent token cannot list Codespaces (HTTP 403) |
| O-E | **Live DB:** containment C-1 DONE 2026-10-21 (anon access revoked, verified — `docs/ops/live/CONTAINMENT_REPORT_C1_2026-10-21.md`). **Still open:** are the 6 cases / 3 care notes real people (legal: possible FADP incident)? rotate the anon/JWT key (SR-12); enable leaked-password protection | SR-01 (contained), SR-12 | key rotation and the legal question are owner-only |
| O-F | ~~Schema-only pull of live~~ — **DONE by agent** 2026-10-21 via read-only catalog queries (`docs/ops/live/SCHEMA_DRIFT_2026-10-21.md`); ADR-022: repo schema stays the target | — | — |
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
| T13 | DB-level seed coverage test: one pgTAP/SQL check per attention category | DONE | PR #15 merged; `006_seed_attention_coverage.test.sql`, 22 assertions, CI db green. Gap: `submitted` note branch unit-tested only |
| T14 | Generated `database.types.ts`, typed client, drift check in CI, compile-time proof | DONE | PR #11 merged |
| T15 | Inline command errors; all regions on Teams; memoised auth check; bots off `recovery/main` | DONE | PR #12 merged |
| TD-17 | Structured logging without personal/health data (closes SR-25) | DONE | PR #17 merged, CI green |
| TD-19 | Live schema verified, drift documented, ADR-022, stricter live rules adopted | IN REVIEW | branch `docs/td19-schema-drift` |

## Care journey — front half

> **Priorities now come from the Product Owner** via the official collaboration layer `docs/agents/` (owner approval 2026-10-21): queue in `NEXT_CAPABILITY.md`, status in `IMPLEMENTATION_STATUS.md`, decisions in `OPEN_DECISIONS.md`. This backlog holds engineering detail only.

| ID | Task | Status |
|---|---|---|
| J1 | Referral intake (admin/operations) → review → case + open matching request; provisional consent gate; audited | **DONE** — PR #23 (ADR-026) |
| J2 | Team decision: active teams of the case's region see open requests (hard filters available today: active team, service area = region; others shown as "not checked"); no client identity before acceptance; first acceptance assigns the case atomically; decline recorded in append-only `team_decisions` | **DONE** — PR #24 (ADR-027) |
| J3 | Team planning: team members plan, move and remove planned visits of their team's cases (no coach/operations override); visible in `/field`; audited incl. insert/delete | **DONE** — PR #25 (ADR-028) |
| J4 | Team availability and capacity windows → derived capacity replaces hand-entered `utilization`/`open_slots` (Operations, matching hard filter) | PROPOSED — PLATFORM_MAP D5 slice 3 |

## Product (M4 — Roadmap Gate 2)

| ID | Task | Status |
|---|---|---|
| F1 | `/field` own-visits day view (mobile-first); scope = caller's teams via `field_visits()`; nurses land on `/field` | **DONE** — PR #19, CI green. Assignment = team until D-6 |
| F2 | Field state machine `planned → on_the_way → started ↔ paused → completed` as audited idempotent commands; append-only `visit_events` by trigger; travel/care/pause derived | **DONE** — PR #20, CI green (ADR-023). `assigned/accepted/cancelled/no_show` wait for D-6 |
| F3 | Time corrections as reasoned, append-only records (no silent edits); effective time + original + reason shown; future times and out-of-order timelines refused | **DONE** — PR #21, CI green (ADR-024). Who reviews corrections: open (Q4/D-6) |
| F4 | Observations (free text, author/time/source), immutable with versions; **team-only** visibility; handover to the client's next visits of the team (14-day display default) | **DONE** — PR #22, CI green (ADR-025) |
| F5 | E2E + RLS-negative suite for the field workflow | PROPOSED |
| F6 | Visit report: draft → submitted from the observations; Operations attention closes when the report is approved | NEXT (Gate 2/3 boundary). Who approves = Q4 |
| F7 | Offline-sync concept (idempotent queued commands, device data limits) | PROPOSED (Gate 2 item 3, concept only) |

## Open questions (product)

| ID | Question |
|---|---|
| Q1 | ~~Purpose of the live `orders` table~~ — **answered (inferred):** Stripe test-mode checkouts from another app (likely Lumena-Health). Owner: move or delete (SR-26) |
| Q2 | TD-09: should a case without team in `teampruefung` raise one or two attention items? |
| Q3 | Operations recommends "Matching starten" though Operations must not trigger matching (DOMAIN_RULES) — reword? |
| Q4 | Real role set and permission matrix. T9 uses placeholders: read = any org member (incl. health fields), team settings = admin/coach, visits = own team. Needs product + data-protection decision before real users |
| Q5 | Who creates organisations and memberships, and how (no UI/API yet — SQL only) |
| Q6 | **Legal:** retention period and access rules for `audit_events` (who may read, how long kept, export for audits) — needed before real data |
| Q7 | Do location features belong in NAVORA's matching (team bases, service radius, geocoded case addresses with PostGIS, team capacity limits)? Live has an unused prototype; geocoding sends addresses to a provider → also a data-protection question |
