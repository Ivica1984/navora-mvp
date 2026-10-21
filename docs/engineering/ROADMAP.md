# NAVORA — Engineering Roadmap

**Last updated:** 2026-10-21 · Product gates: `ROADMAP.md` (handover). This file tracks the engineering milestones that lead through those gates.
Durations assume one engineer; dates are targets, not commitments.

| Milestone | Content | Exit criterion | Target | Status |
|---|---|---|---|---|
| **M0 Secure** | sources in Git with checksums; `main` protected | protected refs + verified import | Day 2 | PARTLY DONE — code in Git with checksums; protection + zip verification are owner steps (O-A…O-D) |
| **M1 Buildable** | T3–T7 | lint, typecheck, unit, audit, build, migrations, pgTAP green in CI on synthetic data | Day 6 | **DONE 2026-10-21** (PR #1, merged into `recovery/main`) |
| **M2 Recovered main** | `recovery/main → main` by merge commit, tag `v0.1.0-recovered` | real code on `main`, honest README, risks listed | Day 7 | IN REVIEW — gated on O-A, O-C, owner approval |
| **M3 Secure staging** | T8 auth · T9 tenancy/RLS · T10 commands/audit · T11 headers · T12 staging | anon and foreign-org access fail in pgTAP; all writes audited; protected staging URL | Day 20 | IN PROGRESS — T8–T11 done (T14 type safety in review); **T12 blocked on owner hosting decision** |
| **M4 Field MVP** | `/field` F1–F5 | Gate 2 criteria on staging | Day 40 | PROPOSED |
| **M5 Pilot readiness** | restore test, incident runbook, DPIA sign-off, live-DB migration or retirement | go/no-go for real data | owner-driven | NOT STARTED |

Mapping to product gates: M0–M2 = Gate 0 (engineering part) · M3 = Gate 1 · M4 = Gate 2 · M5 = Gate 0/1 owner and legal parts. Gates 3–7 start after M4.

## Changes to the plan made today
- M1 reached before M0 completes: ADR-013 (transcribed import, verified later) and ADR-012/014 (CI as runner and lockfile resolver) removed the dependency on owner availability.
- T4/T5 landed together with T3/T6/T7 in one PR instead of separate branches; recorded in PR #1.
