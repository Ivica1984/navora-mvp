# NAVORA — Engineering Roadmap

**Last updated:** 2026-10-21 · Product gates: `ROADMAP.md` (handover). This file tracks the engineering milestones that lead through those gates.
Durations assume one engineer; dates are targets, not commitments.

| Milestone | Content | Exit criterion | Target | Status |
|---|---|---|---|---|
| **M0 Secure** | sources in Git with checksums; `main` protected | protected refs + verified import | Day 2 | PARTLY DONE — code in Git with checksums; protection + zip verification are owner steps (O-A…O-D) |
| **M1 Buildable** | T3–T7 | lint, typecheck, unit, audit, build, migrations, pgTAP green in CI on synthetic data | Day 6 | **DONE 2026-10-21** (PR #1, merged into `recovery/main`) |
| **M2 Recovered main** | `recovery/main → main` by merge commit, tag `v0.1.0-recovered` | real code on `main`, honest README, risks listed | Day 7 | IN REVIEW — gated on O-A, O-C, owner approval |
| **M3 Secure staging** | T8 auth · T9 tenancy/RLS · T10 commands/audit · T11 headers · T12 staging | anon and foreign-org access fail in pgTAP; all writes audited; protected staging URL | Day 20 | **Code complete except T12** — T8–T11, T14, T15 done on `recovery/main`; T12 staging blocked on owner hosting decision (D-2); permission matrix D-3 open |
| **M4 Field MVP** | `/field` F1–F5 (ROADMAP Gate 2 order: own visits → state machine + time → observations/handover → offline concept) | Gate 2 criteria on staging | Day 40 | **IN PROGRESS** — F1–F3 done (PRs #19–#21); F4 observations/handover in review; next F6 report, F7 offline concept, F5 Gate-2 exit suite. Staging still blocked by D-2 |
| **M5 Pilot readiness** | restore test, incident runbook, DPIA sign-off, live-DB migration or retirement | go/no-go for real data | owner-driven | NOT STARTED |

Mapping to product gates: M0–M2 = Gate 0 (engineering part) · M3 = Gate 1 · M4 = Gate 2 · M5 = Gate 0/1 owner and legal parts. Gates 3–7 start after M4.

## Changes to the plan made today
- M1 reached before M0 completes: ADR-013 (transcribed import, verified later) and ADR-012/014 (CI as runner and lockfile resolver) removed the dependency on owner availability.
- T4/T5 landed together with T3/T6/T7 in one PR instead of separate branches; recorded in PR #1.

See also `PLATFORM_MAP.md`: domain view. The **largest platform value is D5 Team Self-Organisation & Planning** (J2–J4).

## Care-journey view (owner direction 2026-10-21: complete the journey, biggest gap first)
Source of truth for the target: `ARCHITECTURE.md` data flow and workflow (*Partneranfrage → Fall → Matching → Teamentscheid → Teamplanung → Einsatz → Dokumentationsfreigabe → Qualität → Billing-Fakten*), `MASTER_CONTEXT.md`, `PRODUCT_REQUIREMENTS.md`, `DOMAIN_RULES.md`. The owner refers to an *Architecture Handbook* (incl. section 16 "Nächste Coding-Reihenfolge"). It is **not in the repository or the Project**; when it is provided, this view is re-derived from it.

| # | Journey step (ARCHITECTURE.md) | State 2026-10-21 | Work item |
|---|---|---|---|
| 1 | Referral (`partner_requests`) | **done** (J1, PR #23) | J1 |
| 2 | Case (`cases`) | **done** (J1): conversion after review, provisional consent gate | J1 |
| 3 | Matching (`matching_requests`, candidates) | J1 opens a request; engine = Gate 4 (needs competence/capacity data, validated weights) | J2 (team-pull, no ranking) |
| 4 | Team decision | **done** (J2, PR #24): team pull, atomic accept | J2 |
| 5 | Team planning → `care_visits` | **done** (J3, PR #25) | J4 capacity proposed to the PO (COORD-2) |
| 6 | Care delivery (`/field`) | **done**: F1–F3 | — |
| 7 | Documentation: observations, handover | **done**: F4 | — |
| 8 | Report → human approval | signed report in review (#35): performer signs, countersignature provisional until D-10 | F6 |
| 9 | Quality gate (`quality_events`) | read-only attention list | Q1 (raise from field), review flow |
| 10 | Billing facts | blocked: legal/tariff decisions (Gate 6) | owner |

**Source of priorities (from 2026-10-21 18:31):** the Product Owner queue in `docs/agents/NEXT_CAPABILITY.md`. Engineering proposals go through `docs/agents/OPEN_DECISIONS.md`.

**Priority rule (engineering view, input to the PO):** close the earliest broken link first, so real (synthetic-staging) data can flow through every implemented step. Steps 1–5 come before 8–10, because without them no visit exists except seed data.
