---
id: AN1
title: Pilot impact dashboard
author: po
status: approved
updated: 2026-10-22
---

# AN1 — Pilot impact dashboard

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
