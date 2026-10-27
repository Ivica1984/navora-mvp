---
id: PLAN3
title: Day-plan and continuity proposal — the team confirms who visits whom tomorrow instead of assembling it by hand
author: po
status: approved
updated: 2026-10-27
---

# PLAN3 — Day-plan and continuity proposal

## Problem
PLAN2 generates the visits from the care plan, but nobody proposes who takes them. A team member still sets `responsible_user_id` visit by visit (J3, 0014), balancing who knows the client, who is qualified, who is absent (ABS1) and who already has a full day. In a traditional provider this is the scheduling administrator's work; in a self-organised team it is a daily coordination task of a nurse, done in the evening or by phone. It is the largest remaining manual coordination task after PLAN2 (Strategic Alignment Review dimension 3, *partial*: "no planning proposal"; AI Operating Model Review A3 "Roster and day plan", level L). Continuity (value 2) depends on it: an unassigned or randomly assigned visit is where the client meets a stranger.

## Users and journey step
The team (every member may ask for and confirm a proposal; the team decides, not a planner). Journey: Planning → Visit.

## Outcome
For a chosen day, the team sees a proposal of who takes each open visit, built from rules it can read (the client's primary nurse first, then her deputy, then a member who has visited the client before, within qualification and presence). The team confirms it, or changes single assignments, in one screen. Every proposal and every change is recorded through AIG1, so the team and Operations can see how often the proposal is right.

## Acceptance criteria
- [ ] **PLAN3-1 Proposal for one team and one day.** A team member asks for a proposal for a date from today to 14 days ahead. It covers the team's planned visits of that day without a responsible member and, if she ticks "auch zugewiesene neu vorschlagen", those with one. It proposes one responsible member per visit or "kein Vorschlag" with the reason. It writes nothing to `care_visits` (pgTAP: the visit rows are unchanged after a proposal).
- [ ] **PLAN3-2 Hard limits, never broken.** A member is proposed only if: she is an active member of the case's team on that date (ADM1, LEAVE1: access not ended, contract end not passed); she has no recorded absence covering the visit (ABS1); she meets the existing qualification rule of the visit (J3: a registered nurse for category B minutes and for a needs assessment, 0014:244); and the visit does not overlap another visit already assigned or proposed to her that day by its planned times. pgTAP one case each: absent, removed, not RN for a B visit, overlapping → not proposed.
- [ ] **PLAN3-3 Continuity order, stated.** Among members who pass PLAN3-2 the proposal prefers, in this order: the case's primary nurse (J6), her deputy, a member with the most completed visits to the client in the last 90 days, then the member with the fewest planned minutes that day; ties broken by a stable key stated in the ADR (not random; pgTAP proves the same input gives the same proposal). Each proposed line shows its reason ("Bezugspflegende", "Stellvertretung", "kennt die Klientin (n Besuche)", "freie Kapazität").
- [ ] **PLAN3-4 Load is visible, not judged.** The proposal shows each member's planned minutes for that day before and after the proposal. NAVORA sets no maximum; the team sees and decides (no labour-law rule is built; D-23 and the working-time record stay with the employer).
- [ ] **PLAN3-5 Confirm in the team.** The team member confirms the whole proposal or changes single lines; confirming sets `responsible_user_id` through the existing J3 command path (every existing J3 check applies again at confirm time; a line that fails is reported and not set). Each confirmed or changed line is an AIG1 confirmation (AIG1-3): proposal kept in the ledger, `corrected` where she chose another member. Under AIG1-5's default every line is confirmed one by one or by an explicit list of lines she ticked; there is no "alle übernehmen" without the list.
- [ ] **PLAN3-6 Registered as an AIG1 agent.** PLAN3 is agent `plan3_day_proposal`, kind `rule`, level `L`, with its synthetic evaluation fixture (AIG1-9) and a stop threshold written by the administrator who switches it on (AIG1-8). Off by default. When stopped, the team sees "Vorschlag zurzeit nicht verfügbar" and plans by hand as today.
- [ ] **PLAN3-7 Measures, at team level only.** Through AIG1-7: per team and month, the share of lines confirmed unchanged and corrected. AN2 adds, per team and month, the share of visits performed by the client's primary nurse or deputy, before and after PLAN3 is switched on for that team. No per-person figure (pgTAP: no person column; small-team suppression).
- [ ] **PLAN3-8 Scope.** A proposal reads only the asking member's team's cases, visits and members (scope inheritance, AIG1-6); a member of another team, Operations and a coach can neither ask for nor read a proposal for this team (pgTAP).
- [ ] **PLAN3-9 Screen.** On `/team`, "Tag vorschlagen" for a date; a list per member with her visits, reasons and minutes; confirm per line or by ticked list; e2e at 390 px: ask, change one line, confirm, see the responsible members set and the ledger showing one `corrected` line.
- [ ] **Negative.** No route or travel time, no geodata and no client address is read (location features stay Gate 5, Q7). No visit is moved, added, cancelled or re-timed. Cover across teams stays COVER1. No proposal reaches a person outside the team. No AI service.

## Rules and their input class
- PLAN3-2 limits are existing rules (J3 qualification, ABS1, ADM1/LEAVE1 membership); input class *visit/schedule fact*. No new rule.
- PLAN3-3 order is a planning preference, input class *visit/schedule fact* (who is primary nurse, who visited before, planned minutes). It ranks members, never clients; it routes no client and escalates nothing. Not for the adviser.
- No labour-law limit (rest time, maximum daily hours) is built; that stays with the employer and `legal` (D-23). If the pilot shows teams need one, it comes through a decision package, not a default.

## Out of scope
- Day order and travel optimisation (needs client location, Q7, and a privacy review; later increment).
- Proposals across teams (COVER1) and for more than one day at a time.
- Any AI model; PLAN3 is a deterministic rule agent.

## Constraints and references
AIG1 (must be accepted first; PLAN3 is its first consumer); J3 (0014), J6, ABS1, ADM1, LEAVE1, PLAN2, COVER1; AN2; `docs/product/AI_OPERATING_MODEL_REVIEW.md` A3; `docs/product/STRATEGIC_ALIGNMENT_REVIEW.md` §4; D-23 (working time, employer); Q7 (location features, Gate 5); hypothesis P-18 style before/after measure.

## Open questions for engineering
- Do visits carry planned start and end times today, or only a date and minutes? If only minutes, PLAN3-2's overlap check uses what exists; state it in the ADR and do not invent times.
- Is "completed visits to the client in the last 90 days" readable for the team under RLS2 without a new read? If not, propose the narrowest read.

**Clinical review gate:** applies in part (assignment touches who performs care; the qualification rule is J3's). `cra` reviews the merged build.
