---
id: PLAN2
title: Self-planning — visits follow the care plan
author: po
status: approved
updated: 2026-10-22
---

# PLAN2 — Self-planning: visits follow the care plan

## PO acceptance — 2026-10-22 16:15: accepted

Reviewed on merged evidence: #118 (merge efa5c7f, CI green on the merge commit), migration 0030, pgTAP 030 (18 assertions), `auto-plan.tsx`, unit `planning-rules.test.ts`. **The PO did not run the tests**; results come from reading the migration and the tests.

| Criterion (14:30 list and 14:45 addendum) | Result | Evidence |
|---|---|---|
| No double planning, skipped slot logged | met | `generate_case_plan` skips a slot with any non-cancelled visit of the case overlapping the window and drops an untouched generated double; pgTAP 030 "a hand-planned visit in the window means no generated visit next to it", "the other 27 days are planned", "logged as already planned" |
| Withdrawn preconditions drop future visits with a reason | met | `drop_generated_visits`; pgTAP 030: needs assessment withdrawn (dropped, the moved visit stays, reason logged), close (no planned generated visits left), reopen not ready (none generated, reason `reopened_not_ready`) |
| A touched B visit after the order end is flagged and shows in the plan status | met | `team_plan_status.order_flagged`; pgTAP 030 "the moved B visit after the order end is flagged"; rendered in `auto-plan.tsx` |
| Uncovered path | met | pgTAP 030: without an eligible primary nurse or deputy, generated visits have no responsible member; the uncovered flag derives from that in `visit_flags` (tested in J3 and pgTAP 029) |
| Daily run tested | met | pgTAP 030 `generate_all_plans` twice, no duplicates, skip logged once |
| Negative test: another team of the same organisation | met | pgTAP 030 rhythm and planning both `rejected` |
| AN1 KPI planning actions per client per week | met | `planning_actions_per_client_week` excludes care-plan and cover changes; pgTAP 030; definition on `/analytics`. Redefined unchanged in AN1 #124 |
| Addendum: the case says why B work stops | met | `orderNotice` renders "B-Leistungen geplant bis <Datum>: Verordnung erneuern"; unit test |
| Addendum: hosted daily job confirmed | met as asked | status row: checked 2026-10-22, no hosted project runs these migrations (staging waits for D-2); owner task recorded |

**Why accepted.** The safety and billing risk (two visits in one slot) is closed, lifecycle changes now withdraw generated visits, and the KPI lets the pilot show whether hand planning really falls. This removes the scheduling administrator's weekly re-entry work: value 1 (direct care time) and 5 (less administration), with continuity kept because generated visits go to the primary nurse.

**Deviations, decided:** a hand-planned visit without a start time would not block a generated slot: **accepted**, because every planning command requires start and end (`check_visit_slot`). The hosted daily job is an owner task tied to D-2: **accepted**; until then the window is kept by triggers and page load.

## PO addendum — 2026-10-22 14:45 (adds to the 14:30 review, same verdict)

- [ ] **The case says why B work stops.** When B items have a rhythm and the order ends inside the four weeks, the case card shows "B-Leistungen geplant bis <Datum>: Verordnung erneuern" (`team_plan_status.b_until` is computed but not rendered in `auto-plan.tsx`). Unit or e2e test asserts the text.
- [ ] **Hosted daily job confirmed.** The status row states whether `cron.job` contains `navora-plan2-daily` on the hosted project, with the date checked. If it does not, there is an owner task to enable pg_cron. Page-load refresh alone does not keep the four-week window for teams that do not open `/team`.

## PO review — 2026-10-22 14:30: changes-requested

Reviewed on merged evidence: #92 (merge e43a8b5, CI green on the merge commit), migration 0025, ADR-042, pgTAP 025 (34 assertions), e2e `tests/e2e/planning.spec.ts`. **The PO did not run the tests**; results come from reading the migration and the tests.

| Criterion | Result | Evidence |
|---|---|---|
| Structured frequency; free text kept; team sees unscheduled items | met | `set_care_plan_schedule`; pgTAP 025 "once a day per item", "the team sees which items are not planned automatically"; e2e "nicht automatisch geplant" |
| Rolling four-week series, team action plus daily run | partial | team action tested (pgTAP 025 "one visit per day for the next four weeks"; e2e 28 visits). The daily job runs only where pg_cron exists, otherwise on page load and triggers; `generate_all_plans` has no test |
| Minutes per category; primary nurse → deputy → uncovered | met | pgTAP 025 "B work goes to the deputy because the primary nurse is a care assistant". The uncovered branch has no test |
| J3: needs assessment first; B only by a registered nurse | met | pgTAP 025 |
| J3: no B after order validity; inform-GP task for A/C without order | partial | B minutes cut after the order end (pgTAP 025 "no B work after the order ends"). The reason appears only in the command result, not in the team's plan status |
| Team stays in charge: moved, removed, started never overwritten | met | pgTAP 025 "a removed slot is not recreated", "the moved visit is never overwritten" |
| Every generated, regenerated or dropped visit logged | partial | generated and regenerated tested; dropped visits logged in code, no test |
| C1: nothing for paused, closed or not-ready cases | partial | pause and series-off tested. **Closed case: no test** |
| AN1: share of generated visits; planning actions per client per week | partial | share in AN1 (0027). Planning actions per client per week is not built |
| Negative tests | partial | Operations, other organisation rejected. Missing: another team in the same organisation |

**Why changes-requested.** PLAN2 is the right product and removes the scheduling administrator's daily work. One behaviour is a patient-safety and billing risk, and two lifecycle paths are untested:

- [ ] **No double planning.** Generation never creates a visit for a case on a day and time window where the case already has a non-cancelled visit, whether planned by hand or generated. pgTAP: a case with a hand-planned visit at 08:00–09:00 gets a rhythm "once a day 08:00–09:00" and has exactly one visit that day; the skipped slot is logged as "already planned".
- [ ] **Withdrawn preconditions drop future visits.** When a case is closed, or reopened and not yet ready, or its needs assessment is no longer done, untouched generated future visits are removed with a logged reason. pgTAP for close and for reopen-not-ready.
- [ ] **A touched visit with B minutes after the order end is flagged** with the J3 order flag and shows in the team's plan status. pgTAP: move a generated B visit, shorten the order validity, the visit carries the flag.
- [ ] **Uncovered path:** a case with no eligible primary nurse or deputy produces uncovered visits that raise the existing J3/OPS1 uncovered flag. pgTAP.
- [ ] **Daily run is tested:** `generate_all_plans` (the function the daily job calls) is run twice in pgTAP and creates no duplicates.
- [ ] **Negative test:** a member of another team in the same organisation cannot set a rhythm or run planning for the case.
- [ ] **AN1 KPI "team planning actions per client per week"** from `visit_plan_changes` (manual plan, move and remove, excluding the reason "care plan"), so the pilot can show that planning work fell. Per team and organisation, with the AN1 rules.

**Deviations, decided:** default weekday spread and four weeks ahead are accepted (D-21). Absences are not modelled: accepted, absences go to COVER1. Regeneration on every care-plan item change: accepted.

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
