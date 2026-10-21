# NAVORA — Engineering Roadmap

**Last updated:** 2026-10-21 · Product gates: `ROADMAP.md` (handover). This file tracks the engineering milestones that lead through those gates.
Durations assume one engineer; dates are targets, not commitments.

| Milestone | Content | Exit criterion | Target | Status |
|---|---|---|---|---|
| **M0 Secure** | sources in Git with checksums; `main` protected | protected refs + verified import | Day 2 | PARTLY DONE — code in Git with checksums; protection + zip verification are owner steps (O-A…O-D) |
| **M1 Buildable** | T3–T7 | lint, typecheck, unit, audit, build, migrations, pgTAP green in CI on synthetic data | Day 6 | **DONE 2026-10-21** (PR #1, merged into `recovery/main`) |
| **M2 Recovered main** | `recovery/main → main` by merge commit, tag `v0.1.0-recovered` | real code on `main`, honest README, risks listed | Day 7 | IN REVIEW — gated on O-A, O-C, owner approval |
| **M3 Secure staging** | T8 auth · T9 tenancy/RLS · T10 commands/audit · T11 headers · T12 staging | anon and foreign-org access fail in pgTAP; all writes audited; protected staging URL | Day 20 | **Code complete except T12** — T8–T11, T14, T15 done on `recovery/main`; T12 staging blocked on owner hosting decision (D-2); permission matrix D-3 open |
| **M4 Field MVP** | `/field` F1–F5 (ROADMAP Gate 2 order: own visits → state machine + time → observations/handover → offline concept) | Gate 2 criteria on staging | Day 40 | **IN PROGRESS** — F1 done (PR #19); F2 in review; F3 next. Staging still blocked by D-2 |
| **M5 Pilot readiness** | restore test, incident runbook, DPIA sign-off, live-DB migration or retirement | go/no-go for real data | owner-driven | NOT STARTED |

Mapping to product gates: M0–M2 = Gate 0 (engineering part) · M3 = Gate 1 · M4 = Gate 2 · M5 = Gate 0/1 owner and legal parts. Gates 3–7 start after M4.

## Changes to the plan made today
- M1 reached before M0 completes: ADR-013 (transcribed import, verified later) and ADR-012/014 (CI as runner and lockfile resolver) removed the dependency on owner availability.
- T4/T5 landed together with T3/T6/T7 in one PR instead of separate branches; recorded in PR #1.

## Execution order (from 2026-10-21, owner instruction)
Business capabilities first, following `ROADMAP.md` (handover) gate order; platform work only when it blocks a capability.
The owner referenced an *Architecture Handbook section 16 "Nächste Coding-Reihenfolge"*. That document is **not in the repository or the Project** (searched 2026-10-21). Until it is provided, Gate 2 of `ROADMAP.md` is the execution order:
1. `/field` own visits, minimal context, mobile → F1 ✅
2. state machine + idempotent commands; depart/start/pause/resume/complete; time segments with correction events → F2 (review), F3
3. observations, team visibility, handover, offline-sync concept → F4, F6, F7
4. Gate 2 exit: full workflow E2E, RLS-negative and positively tested → F5
