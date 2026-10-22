---
id: OPS1
title: Operations exception center
author: po
status: approved
updated: 2026-10-22
---

# OPS1 — Operations exception center

## Clinical review gate — 2026-10-22 23:00: reopened, changes-requested

The PO considered the Clinical Governance Report (`reports/CLINICAL_GOVERNANCE.md`, 2026-10-22 22:30) under the gate (README; D-27). The acceptance below is withdrawn for these findings; the remedy is [CSR1](CSR1.md). The PO did not run tests; evidence is the report's code references.

| Finding | Severity | PO decision |
|---|---|---|
| CGR-04 | blocking | considered; remedy CSR1, thresholds D-28 |
| CGR-05 | blocking | considered; escalation continues until `closed`; remedy CSR1 |
| CGR-06 | blocking | considered; a P1 cannot be silenced while its cause persists; remedy CSR1 |

## PO acceptance — 2026-10-22 12:00: accepted

| Criterion | Result | Evidence |
|---|---|---|
| Exceptions derived from state, all brief sources | met | #39 (ADR-035), 10 types incl. report not final (F6) and serious quality event (QG1) |
| Reason, age, case, team, link; Operations-scoped data | met | #39 |
| Take over, note, close with reason; auto-close with note | met | #39 |
| ≤ 6 KPIs, no matching start, no case editing | met | #39 |
| Thresholds as configuration with Q9 defaults | met | `exception_rules` |

Deviations accepted: a serious quality event shows at once as P2 and becomes P1 after 4 h (safer than the brief); rules change by migration until ADM1. Follow-up: the legacy heuristics below the list are labelled "unvalidated" — remove them when ADM1 ships unless a pilot user relies on one. PO did not run the tests; evidence is the merged test suite and green CI on the merge commit.

## Problem
Self-organisation works only with a safety net: no case waits silently, no visit stays uncovered. `ARCHITECTURE.md` defines Operations as an exception-based control tower, not dispatch. J1–J3 and QG1 create exceptions (blocked cases, overdue offers, uncovered visits, expired orders, serious quality events), but there is no single place that derives them from state. This is the scaling lever of the model: a small Operations group can support many teams.

## Users and journey step
NAVORA Operations. Cross-cutting over Fall → Matching → Teamentscheid → Teamplanung → Qualität.

## Outcome
Operations opens one list of open exceptions sorted by urgency, each with reason, age, case, team and next step; who took it is visible; resolved exceptions close with a trace.

## Acceptance criteria
- [ ] Exceptions are derived from state, never entered by hand: case not ready for matching after a threshold (J1); offer overdue or all candidates exhausted (J2); visit uncovered within 24 h, medical order expired, care-plan review overdue (J3); serious quality event open (QG1); report missing (F6).
- [ ] Each exception shows reason, creation time, case, team and a link to its origin; data limited to what Operations may see.
- [ ] Take over, comment and close are audited commands; closing needs a reason; a fixed cause closes the exception automatically with a note.
- [ ] At most six KPI cards; no matching start and no case editing from OPS1.
- [ ] Thresholds and urgency are configuration, not code. Pilot defaults (Q9):
    - **P1 safety:** serious quality event open longer than 4 hours; uncovered visit within 24 hours for a hospital-discharge case.
    - **P2 continuity:** any other uncovered visit within 24 hours (delivered in #32); all candidates exhausted; offer past its Q8 deadline.
    - **P3 administration:** case not ready for matching 1 working day after the referral; medical order expiring within 7 days or expired; care-plan review overdue; report not final 24 hours after the visit ended.

## Out of scope
Team performance ranking, workforce planning, reporting exports.

## Constraints and references
`PRODUCT_REQUIREMENTS.md` Operations (max. six KPIs, kein Matching-Start). Existing `/operations` attention list (T13 seed coverage, #15): extend it rather than build a second one. Thresholds: Q9.

## Open questions for engineering
- Which exception types the current attention list already derives, and which are new.
