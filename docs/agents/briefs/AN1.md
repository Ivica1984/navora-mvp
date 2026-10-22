---
id: AN1
title: Pilot impact dashboard
author: po
status: approved
updated: 2026-10-22
---

# AN1 — Pilot impact dashboard

## PO review — 2026-10-22 14:30: changes-requested

Reviewed on merged evidence: #97 (merge 7d00ce5, CI green on the merge commit) and the COVER1 extension in #99 (0028), migration 0027, ADR-044, pgTAP 027, e2e `tests/e2e/analytics.spec.ts`. **The PO did not run the tests**; results come from reading the migrations, the page and the tests.

| Criterion | Result | Evidence |
|---|---|---|
| North Star first: care minutes ÷ paid working minutes, per team and month, with 60 % / 75 % reference | **not met as defined** | shown first (`rules.ts` KPI order) with the reference, but implemented as care ÷ (travel + care + pause) **inside visits**. Documentation after the visit, the return trip, meetings and all other paid time are missing, and a missing departure counts as 0 travel. The figure is an upper bound and cannot be compared with Buurtzorg's 60 %. The pgTAP fixture yields exactly 75 % |
| Referral to first visit; visit end to final report; time corrections; nurses per client and primary share; billable per care minute | met | 0027; pgTAP 027 (corrections 20 %) |
| First-offer acceptance | met with deviation | measured as acceptance within the response deadline (accepted, see D-21) |
| Open P1 exceptions and median time to close | partial | open count is "now", not the month, without base count; time to close says "Noch nicht messbar" |
| PLAN2 share, F7 within 10 min, COVER1 without Operations | partial | PLAN2 and F7 in 0027. COVER1 figures added by text-patching `pilot_kpis` in 0028; **no test** of their values; "without Operations" is accepted ÷ offered and does not check Operations involvement |
| Per team and organisation, never per nurse; aggregates only | met with a gap | grouping and argument-name guard (pgTAP 027). A team with one or two nurses still reveals one nurse's figures |
| Access: own team; coordination roles all; other organisations nothing | met | pgTAP 027; e2e `analytics.spec.ts` |
| Period and source on every figure; < 5 marked "too few data" | partial | source per row, period only in the heading; open P1 has no base |

**Why changes-requested.** AN1 is the evidence base for the operating model and for D-14 (nurse income). A North Star that overstates the result is worse than none, because it would tell the owner the 75 % hypothesis is met when nothing is known. Concrete, testable changes:

- [ ] **Name the measured figure honestly.** Until paid working time is recorded, the first figure is labelled "Pflegeanteil im Einsatz" (care share within visits), with the definition care ÷ (travel + care + pause) of visits, and it shows **no** 60 % / 75 % reference line. The definition text says that documentation, the return trip and non-visit time are not included. e2e checks the label and the absence of the reference.
- [ ] **Incomplete visits do not inflate the share.** A visit without a departure or completion time is excluded from numerator and denominator and counted as "incomplete" next to the figure. pgTAP: one visit without departure changes the base count, not the share.
- [ ] **North Star placeholder.** A second row "Direkter Pflegeanteil (North Star)" shows "noch nicht messbar: bezahlte Arbeitszeit wird noch nicht erfasst", the same way P1 time to close does. It becomes real when working time exists (see the challenge row "separate timesheets").
- [ ] **No per-nurse inference.** Team figures are shown only for teams with at least 3 members who had visits in the period; otherwise "zu wenig Personen" and only the organisation figure. pgTAP with a two-nurse team.
- [ ] **COVER1 figures tested and correct.** "Cover without Operations" counts accepted covers where no one in a coordination role took over or closed the uncovered-visit exception before acceptance. Time to cover uses the first moment the visit entered the offer window, not the moment someone loaded `/field`. pgTAP for both values.
- [ ] **Period on every figure.** Each row shows its period; the open P1 count says "Stand jetzt" and shows a base.

**Deviations, decided:** first-offer acceptance as acceptance within the response deadline: **accepted** (J2 offers all eligible teams at once, so "first offer" has no other meaning). Live computation instead of a nightly aggregate: accepted for pilot volume.

## Problem
NAVORA's claims to partners, investors and nurses are measurable:
- less administrative time;
- faster start of care;
- more continuity;
- billable time that funds fair pay.

The data for all of these now exists in J1–J6, F1–F6 and OPS1, but nobody can see it. Without it the pilot cannot prove anything, and the founders cannot set the platform fee (D-14) from evidence.

## Users and journey step
NAVORA founders and Operations; each team for its own figures. Journey: Analytics, the last step after Billing.

## Outcome
One page shows the pilot KPIs per month, for the organisation and per team, each with its definition and its data source.

## Acceptance criteria
- [ ] **North Star first:** direct care share = measured care minutes ÷ paid working minutes (from F1–F4 events and confirmed working time), per team and month. Buurtzorg's reference point is 60 %; NAVORA's hypothesis is 75 % (`docs/product/CARE_OPERATING_MODEL.md`).
- [ ] KPIs, each with a definition shown on the page:
    - referral to first visit (median days);
    - first-offer acceptance rate;
    - time from visit end to final report (median), as the administrative-burden proxy;
    - share of visits with a time correction;
    - distinct nurses per client and primary-nurse share (from J6);
    - billable minutes per measured care minute (from J5);
    - open P1 exceptions and median time to close (from OPS1);
    - share of visits created from the care plan (PLAN2), reports final within 10 minutes (F7), uncovered visits resolved without Operations (COVER1).
- [ ] Per team and for the whole organisation; never per individual nurse.
- [ ] Only aggregates; no client identity or health data on the page.
- [ ] Teams see only their own team's figures; founders and Operations see all teams.
- [ ] Every figure shows its period and data source. Figures built from fewer than 5 visits are marked "too few data".

## Out of scope
Benchmarking against other providers, cantonal quality reporting, investor reports, payroll figures (J7).

## Constraints and references
KPI list: `ROADMAP.md` Gate 8. Continuity measure J6; billable facts J5; exceptions OPS1. Never an individual performance ranking (J6 rule).

## Open questions for engineering
- Which KPIs can be computed live, and which need a nightly aggregate?
