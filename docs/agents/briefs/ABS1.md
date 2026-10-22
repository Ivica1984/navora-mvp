---
id: ABS1
title: Absence without the phone chain
author: po
status: approved
updated: 2026-10-22
---

# ABS1 — Absence without the phone chain: "I can't work" hands the day to the team

## Problem
**Challenge finding (PO, 2026-10-22 18:20).** When a nurse falls ill at 06:30, the traditional organisation runs a phone chain: she calls the shift lead or the dispatcher, who phones colleagues one by one and re-assigns her visits by hand. Buurtzorg moves this into the team, but it is still a morning of phone calls, often carried by the coach when the team cannot agree. Why does the workflow exist? Because nobody else knows which visits are now without a nurse, and who could take them.

In NAVORA today:
- a visit has a responsible member (J3), and PLAN2 assigns generated visits to the primary nurse;
- NAVORA has **no notion of a member being unavailable**. A sick nurse's visits stay assigned to her. They do not count as uncovered, so neither the J3 team flag, nor OPS1, nor COVER1 sees them;
- the only fix is that someone notices and re-assigns each visit by hand.

This is a **patient-safety gap** (a visit can silently not happen while it looks assigned) and the last coordination task that still needs a phone chain. COVER1 solves cover *between* teams, but only for visits that are already uncovered.

If NAVORA were designed from scratch, the absent nurse would say once that she cannot work, and her visits would go to the colleagues who know the clients, in one tap each, with nobody coordinating.

## Users and journey step
The absent nurse; her team members; Operations only through the existing exceptions. Journey: **Planning → Visit**. Feeds Continuity (J6), COVER1 and AN1.

## Outcome
A nurse records in a few seconds that she is not available. Her visits in that period are at once open to her team, the colleague who knows the client is shown first, and a colleague takes a visit with one tap. No visit stays with a nurse who is not working, and nobody has to phone anyone.

## Acceptance criteria
- [ ] **Record unavailability.** A team member records her own unavailability on `/field`: start and end (date, optional time; default the whole of today). **No reason field and no free text**: NAVORA stores no reason for an absence. The command is audited and idempotent.
- [ ] **For a colleague.** Any member of the same team can record it for a colleague (the sick nurse phones one colleague, not a dispatcher). It is audited with who recorded it, and the absent member sees it on her own `/field`. A member of another team or organisation cannot.
- [ ] **No approval step.** Recording unavailability needs nobody's approval in NAVORA. It is an availability fact for planning, not a leave request: whether holidays need the employer's agreement stays outside NAVORA's rules and is not modelled here.
- [ ] **Her visits are released at once.** Every visit in the period where she is the responsible member and that has not started loses her as responsible member and becomes uncovered: the J3 uncovered flag, the OPS1 exception at its existing thresholds, and COVER1 at its lead time (once D-3 switches it on). Visits already started are untouched. The release is recorded in the J3 change log with the reason "Abwesenheit" (no further detail).
- [ ] **The team takes them.** The `/field` view of every member of the team shows the released visits under "Offen im Team", in time order, with what the team view already shows for its own visits (F0 team-scoped read; nothing more). For each visit, the case's **deputy nurse, then the primary nurse** (J6), if present in the team and not the absent person, is marked "kennt die Klientin". This is a label, not an assignment.
- [ ] **One tap, first wins.** A member takes a visit with one tap. It is atomic: if two take it at once, one gets it and the other sees "bereits übernommen". The taker becomes the responsible member; the planned time stays; she can move it with the existing J3 move-with-reason. J3 rules hold: a care assistant cannot take category B or needs-assessment visits, and the take button is not offered to her for them.
- [ ] **Overlap is shown.** A released visit that overlaps one of the member's own planned visits is marked "überschneidet sich mit deinem Einsatz <time>". She can still take it (she may move one of them), but she sees it before the tap.
- [ ] **PLAN2 respects the absence.** Visits PLAN2 generates inside a recorded absence are assigned to the deputy if she may perform them, else left uncovered, never to the absent member. Re-generation never re-assigns a released visit to the absent member.
- [ ] **Withdraw or shorten.** The absent member (or the colleague who recorded it) can withdraw or shorten an absence before or during it. Visits nobody has taken yet return to her; visits a colleague took stay with that colleague.
- [ ] **Privacy.** Her own team sees that a member is unavailable from–to. Other teams, coordination roles and AN1 see only uncovered visits, never who is absent. Nothing about absences is shown or computed per nurse anywhere else.
- [ ] **Measured in AN1** (team and organisation level, small-team rule as in AN1):
    - share of released visits taken by the own team before the COVER1 lead time;
    - median time from absence recorded to the last released visit taken;
    - share of released visits taken by the deputy or primary nurse.
- [ ] Works at phone width; recording an absence for today is reachable from the top of `/field` in at most two taps.
- [ ] Negative tests:
    - another team's member neither sees the released visits nor can take them;
    - another organisation sees nothing;
    - a care assistant cannot take a category B or needs-assessment visit;
    - a member cannot record an absence for someone outside her team;
    - two concurrent takes give exactly one responsible member;
    - a started visit is not released;
    - no reason text can be stored with an absence (the command has no such parameter).

## Out of scope
- Reasons, sick notes, medical certificates, leave balances, payroll and HR records: not stored, not computed.
- Holiday planning with approval (no approval step is modelled; see the third criterion).
- Automatic re-planning or route optimisation of the taker's day.
- Cross-team cover: that is COVER1, which picks up whatever the team has not taken at its lead time.
- Team capacity planning (J4, Gate 5).

## Operating-model impact
| Question | Answer |
|---|---|
| Layer of administration replaced | Dispatch and shift lead for absences; the coach as absence handler (Buurtzorg's hidden scaling limit, `CARE_OPERATING_MODEL.md`) |
| Manual activity removed | The morning phone chain, re-assigning visits one by one, checking who may do which visit, telling Operations |
| Role less necessary | Dispatcher, shift lead or "Tagesverantwortliche", coach as first line for absences |
| Continuity of care | The deputy or primary nurse is shown first, so the client sees a known nurse; HAND1 tells the taker what changed |
| Direct care time | Phone time on the morning of an absence goes back to visits; measured by AN1 time-to-taken |
| Caregiver income potential | Released visits are taken in the team rather than lost or handed to another team, so the team keeps its billable volume |
| Long-term operating model | Availability is a fact the network acts on; together with COVER1 it makes absence handling self-running at any number of teams |

## Patient safety
Today an absent nurse's visit can look assigned and silently not happen. After ABS1 it becomes uncovered at once and enters the existing safety net (J3 flag, OPS1 P1/P2 thresholds, COVER1 after D-3). ABS1 adds no clinical rule: who may perform which visit stays the J3 qualification rule.

## Dependencies
J3 (responsible member, uncovered flag, change log, qualification rule), J6 (primary and deputy), PLAN2 (generation), OPS1 (exceptions), COVER1 (lead time; switched off until D-3), AN1. All accepted. No open decision blocks it: no reason is stored, so no health data is processed; no approval rule is modelled, so no labour-law rule is assumed.

## Constraints and references
`DOMAIN_RULES.md` data minimisation and team-scoped access (F0, ADR-031). J3 (ADR-030), J6 (ADR-037), PLAN2 (ADR-042), OPS1 (ADR-035), COVER1 (ADR-045), HAND1 (ADR-047). Working time and leave law are outside NAVORA here (D-23 covers recorded working time only).

- **PO 2026-10-22 20:15:** ADM1 change 1 (a removed member's future visits are released) needs the same release as ABS1. Build one private release function (team, member, from, until, reason) and use it in both; whichever ships first creates it.

## Open questions for engineering
- Is an absence a row per member with a time range and an exclusion on overlap, with release done by the same command (no job), cheaper than a job?
- Can "Offen im Team" reuse the J3 uncovered list with a team filter instead of a new read model?
