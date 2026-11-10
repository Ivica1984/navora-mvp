---
id: POOL1
title: Demand pooling: idle team capacity matched to freely released demand, always as a separate GM-1 order (synthetic)
author: po
status: approved
updated: 2026-11-11
---

# POOL1 — Demand pooling (Phase A, synthetic)

**Approved 2026-11-11 00:05 CET for synthetic data only** under founder decision **FE-055** (4). Built after B0, BD and GMSEP. **Stop before any real use:** `lca` must answer L-7 (staff leasing under AVG vs. mandate) for pooled engagements first.

## Problem
A self-organised team earns more than an employed nurse only while its booked share stays high: at 70 CHF/h, 85 % utilisation leaves about +6 %, 70 % leaves −13 % (`ECONOMICS_COMPARISON.md` §2.3). Idle hours are the main income risk of GM-1. Institutions meanwhile pay 1.1-1.7× for temporary staff.

## Users and journey step
GM-1 teams with idle capacity; institutions (GM-1 clients and GM-2 software customers) that release short-term demand. Steps: Referral/order → Matching → Team decision → Planning.

## Outcome
When a team has idle capacity, it sees released short-term demand it is qualified for and may accept it; every accepted engagement becomes its own GM-1 order (KON-1).

## Acceptance criteria
- [ ] POOL1-1: an institution releases demand explicitly (date, shift, activities required, number of people); nothing is derived from its staff data. A GM-2 institution that never releases demand never appears.
- [ ] POOL1-2: a team's idle capacity comes from its own plan (unplanned confirmed availability), never from another team's data.
- [ ] POOL1-3: the AI proposes matches only where QUAL1 (activity rule E/D, never `?`) is met for the members it names; a match where the rule is open is not shown.
- [ ] POOL1-4: the team decides (accept/decline); the AI never accepts, books or commits a team (team autonomy, value 4). Declines need no reason.
- [ ] POOL1-5: acceptance creates a new order with `business_model = gm1_team`, constellation KON-1, its own contract reference and its own billing preparation (GMSEP-1, -5); no record links it to the institution's GM-2 licence.
- [ ] POOL1-6: the team sees only the released demand and, after acceptance, what the order requires; never the institution's own staff, rosters or residents beyond the order (GMSEP-4).
- [ ] POOL1-7: a team metric shows booked share per month before and after pooling (team level only, never per person; AN3 style).
- [ ] POOL1-8: in the BD flow test, an idle synthetic team receives, accepts and plans one pooled engagement end to end.
- [ ] Negative cases: an institution cannot pick a named nurse; a member without the qualification is never proposed; an engagement without a GM-1 order cannot be planned.

## Rules and their input class
Idle capacity and released demand: *visit/schedule fact*. Qualification: existing QUAL1 rule (PROPOSED matrix, synthetic only). No new clinical rule.

## AI leverage
1. Remove: phone and mail chains for short-term cover, agency mediation. 2. Rules: qualification (QUAL1), separation (GMSEP). 3. Monitor: idle capacity and open released demand, continuously. 4. AI prepares: a ranked list of released demand per team (input: team's idle slots, qualification states, released demand; output: suggestion with reasons; level L; stop: no suggestion if any rule is `?`). 5-6. The team reviews and decides. 7. The order confirmation stays a human act. D-35 rule A: no client or staff data to an external AI service; ranking runs in NAVORA.

## Out of scope
Pricing of pooled engagements, the contract form (D-44, L-7), payment (L-10).

## Constraints and references
FE-040, FE-055 (4); KON-1; L-7, L-11; QUAL1, PLAN3, ABS1, COVER1, GMSEP; `ECONOMICS_COMPARISON.md` §2.3.

## Open questions for engineering
1. Can the COVER1 cover search be reused as the matching engine with a new demand source?
