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

### Amendment 2026-11-11 02:39 CET (po, after `cra` CGR-173 and `aia` AUT-83, AUT-84)
Product decisions within FE-055 (4); no founder decision changed. FE-055 (4) "das Team entscheidet" is met by the team's standing mandate; "die KI schlägt vor" is, under D-35 stage 0, a deterministic rule inside NAVORA.
- **POOL1-2 (replaced, AUT-83 (1)):** ~~idle capacity from "unplanned confirmed availability"~~. Idle capacity = an interval with no planned visit or shift of the member and no ABS1 absence, derived from existing facts only. **No availability entry.** A member who does not want pooled work says so once, as a standing personal setting. Test: a member receives her first match with 0 entries made beforehand.
- **POOL1-4 (sharpened, AUT-83 (2), (3)):** the team sets **once** a standing pooling mandate: pooling on/off (off by default, PLAN3-10 pattern), any limits it chooses, and whether a pooled engagement is accepted by the named member herself within the mandate (COVER1 `accept_cover` pattern) or needs a team confirmation per offer. The AI/rule never accepts. Every accepted engagement is visible to the whole team at once. Test: with the mandate off no match is shown; with it on, the named member's acceptance creates the engagement and the team view shows it.
- **POOL1-3a (new, CGR-173 (1)):** the qualification check runs in the order's context **NH-EXT**; a cell that is E/D in home care and `?` in NH-EXT is never proposed (pgTAP).
- **POOL1-3b (new, CGR-173 (2)):** released demand without a named delegation source and escalation addressee per activity (CR-182 fields) is never shown to a team (pgTAP).
- **POOL1-3c (new, CGR-173 (3)):** acceptance is refused when the shift overlaps any visit or shift the member holds; an ABS1 absence recorded afterwards releases the engagement as uncovered with a visible fact (pgTAP).
- **POOL1-6 (sharpened, CGR-173 (4)):** the order's read set includes the safety-alert set of the residents in the order once D-17 exists; until then the brief records the gap and real use waits.
- **POOL1-3d (new, CGR-173 (5)):** no rest or maximum check exists (WORK1 *Not built*); the Phase A test records the gap; before real use a rest/maximum rule from `lca` (ArG) and the Clinical Owner.
- **POOL1-9 (new, AUT-84):** the matcher is registered in AIG1 as agent kind `rule`, level L, off by default, with a synthetic evaluation fixture (AIG1-9), stop threshold, every shown match in the suggestion ledger with its inputs, field allow-list (no residents' or institution staff data); ordering by fixed published keys: (1) qualification met in NH-EXT, (2) no travel conflict with the member's same-day plan, (3) earliest release time. UI wording "NAVORA schlägt vor (Regel)", not "KI". A learned ranking is a later stage and a new decision.
- **Real-use conditions:** CGR-173 (1)-(5) and `lca` L-7, all before any real pooled engagement.

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
