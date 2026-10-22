---
id: PLAN2
title: Self-planning — visits follow the care plan
author: po
status: approved
updated: 2026-10-22
---

# PLAN2 — Self-planning: visits follow the care plan

## Problem
**Challenge finding (PO, 2026-10-22).** The care plan (J3) already records, per service, the KLV category, the minutes and the frequency. The team then re-enters the same information visit by visit, by hand, for every client and every week. This is the classic Spitex dispatch task, inherited, not designed:
- the frequency is free text ("3x weekly") that nothing reads;
- the primary nurse (J6) is not used when visits are created;
- every care-plan change means replanning by hand.

If NAVORA were designed from scratch, nobody would plan a recurring visit more than once.

## Users and journey step
The assigned team. Journey: Planning. Feeds Visit, Billing (J5) and Continuity (J6).

## Outcome
The team agrees the care plan once. The visits for the coming four weeks then exist, with the right minutes, category and nurse, and the team only handles exceptions.

## Acceptance criteria
- [ ] **Structured frequency** per care-plan item: times per day or per week, optional preferred weekdays and time window. The existing free text is kept as a note. Items without structured frequency are not planned automatically, and the team sees which ones they are.
- [ ] One team action, and afterwards a daily automatic run, keep a **rolling four-week series** of planned visits for every active case.
- [ ] Each generated visit carries:
    - planned minutes per category from the care plan;
    - responsibility assigned to the **primary nurse**, or to the deputy when the primary nurse cannot do the work;
    - otherwise no one, which raises the existing "uncovered" flag.
- [ ] **Safety and billing rules from J3 apply unchanged:**
    - the needs assessment still comes first;
    - category B services are assigned only to a `registered_nurse`;
    - no B visit is generated beyond the validity end of the medical order (the case shows why);
    - an A/C visit without an order keeps the inform-GP task.
- [ ] **The team stays in charge.** Visits the team moved, removed or started are never overwritten. A care-plan change regenerates only future untouched visits. Every generated, regenerated or dropped visit is in the plan change log with the reason "care plan".
- [ ] **C1 interruptions are respected:** no visits are generated inside a pause, after a case is closed, or for a cancelled series.
- [ ] Measured in AN1: share of visits created automatically, and team planning actions per client per week (before and after).
- [ ] Negative tests: no visits for another team's cases; nothing is generated for a case that is not active.

## Out of scope
Route optimisation and travel time; balancing workload across nurses; AI scheduling; client self-booking.

## Constraints and references
`DOMAIN_RULES.md` Teamautonomie (the team plans; NAVORA does not dispatch). J3 rules (ADR-028, ADR-030), J6 primary nurse (ADR-037), C1 lifecycle. The structured frequency is a planning field, not a clinical one. `clinical` sees it with D-15 but it does not wait for D-15.

## Open questions for engineering
- Daily generation as a scheduled database job, or on read? Choose what keeps the four-week window reliable.
