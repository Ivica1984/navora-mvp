---
id: OPS1
title: Operations exception center
author: po
status: draft
updated: 2026-10-21
---

# OPS1 — Operations exception center

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
- [ ] Thresholds and urgency are configuration, not code.

## Out of scope
Team performance ranking, workforce planning, reporting exports.

## Constraints and references
`PRODUCT_REQUIREMENTS.md` Operations (max. six KPIs, kein Matching-Start). Existing `/operations` attention list (T13 seed coverage, #15): extend it rather than build a second one. Thresholds: Q9.

## Open questions for engineering
- Which exception types the current attention list already derives, and which are new.
