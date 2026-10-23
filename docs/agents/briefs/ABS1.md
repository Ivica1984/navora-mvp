---
id: ABS1
title: Absence without the phone chain
author: po
status: approved
updated: 2026-10-23
---

# ABS1 — Absence without the phone chain: "I can't work" hands the day to the team

## PO review — 2026-10-23 14:16: part 1 met; changes-requested for part 2 (three conditions) and the clinical gate

Reviewed ABS1 part 1: #195 (head 16cdc0a, CI run 39948275720 green: app, db incl. pgTAP 046 and the two-session take check, e2e; merged as a626c30, CI run 39948793722 green on the merge commit and on c8dab8d, checked through the API). The PO read migration 0046 in full, pgTAP 046 (93 assertions), `scripts/db-concurrency/open-visit-take.sh`, the e2e test in `tests/e2e/field.spec.ts`, `absence-section.tsx`, `src/features/absence/*`, the unit test, ADR-057, CR-051 and CR-052. **The PO did not run the tests.** Evidence is merged code and tests plus green CI.

| Criterion | Result | Evidence |
|---|---|---|
| Record unavailability (own; default today; no reason, no free text; audited, idempotent) | met | `record_absence` has no reason parameter (pgTAP asserts the signature and the absence of a text column); audit trigger on `member_absences`; `duplicate` on the same key; overlaps refused |
| For a colleague (same team; she sees it; other team cannot) | met | pgTAP §5 (`recorded_by` is the colleague, `team_absences().is_me` for her), §6 (another team `rejected`) |
| No approval step | met | no approval state or command exists |
| Her visits released at once; started untouched; J3 log "Abwesenheit" | **met for timed visits; gap for untimed visits** | `private.release_visits_between`; pgTAP §1, §8. **Gap (ABS1-C1):** a visit without a start time has the interval 00:00–00:01, so an absence starting later that day (e.g. 10:00) does not release it: it stays with the absent nurse and looks covered, the exact gap ABS1 exists to close |
| The team takes them; "kennt die Klientin" (deputy, then primary; label only) | met | `team_open_visits`; pgTAP §2 (`known_by`, order by time); UI label in `absence-section.tsx` |
| One tap, first wins; J3 qualification; button not offered to a care assistant for B | met | `take_open_visit` row lock; two-session CI check (one `ok`, one `already_taken`, one log row); pgTAP §2/§3 (`not_qualified`, `may_take = false`); UI shows no button when `may_take` is false; message "Bereits übernommen" |
| Every uncovered visit, not only absences (12:15 amendment); `visit_uncovered` ends with its cause | met | pgTAP §7: hand-planned visit with nobody responsible → listed → taken → no `visit_uncovered`; another team `rejected`, another organisation sees nothing |
| Overlap is shown | **implemented, not tested** | `overlaps_my_visit` and the label exist; no pgTAP or e2e assertion (ABS1-C2) |
| PLAN2 respects the absence; regeneration never re-assigns | met | 0046 §10a/§10b; pgTAP §10 (deputy on her absent day, uncovered when both absent, a taken visit stays with the taker) |
| Withdraw or shorten | met | `change_absence`; pgTAP §4 (shorten: untaken returns with "Abwesenheit beendet", taken stays), §5 (withdraw by the absent member of an absence a colleague recorded) |
| Privacy (own team only; coordination, other teams, AN1 never) | met for part 1 | RLS `team_members_read`; pgTAP §6 (other team, Operations, other organisation read 0 rows). AN1 not yet touched (part 2) |
| Measured in AN1 (three measures) | **open (part 2, PLANNED)** | not in this PR |
| Phone width; absence at most two taps from the top of `/field` | met | e2e at 390 px: the button is in the viewport, open → form with save, no reason field, no horizontal overflow. Saving is not exercised in e2e (it would release seed visits); pgTAP covers the command. Accepted |
| Negative tests (7) | met | pgTAP §2, §6, §8, signature check; two-session check |
| Clinical gate: one release rule (CGR-15), suspended included (CGR-09), in progress excluded (CGR-10), qualification at take (CGR-12) | met in code | one function used by absence, ADM1 removal and the qualification change; pgTAP §8, §11. **Awaits a `cra` section on 0046** |
| CGR-11 | met in code | 0046 §10c; pgTAP §11 (B released with "Qualifikation geändert", A stays, paused stays) |
| CGR-15 | met in code | pgTAP §8: the released overdue visit keeps `visit_overdue` ("niemand zuständig") |
| Performed visits and open reports (absence never refused; paused keeps her with `visit_stuck`; draft stays hers) | met | pgTAP §8 |
| PR names the latest report section and CGR IDs | met | #195 names the 10:29 section, CGR-11, CGR-15 |

**PO status: `changes-requested`.** Part 1 is a sound delivery and stays merged. ABS1 is accepted without another full review once part 2 is merged with green CI, meets the three conditions below and the AN1 criterion, and a `cra` section on 0046 (and part 2) holds no blocking finding.

**Conditions for part 2 (concrete, testable):**
- **ABS1-C1 (patient safety):** a visit without a start time is released when the absence covers any part of its date (it can happen at any time that day). The same whole-day interval applies when `take_open_visit` and `team_open_visits` check whether the taker or the known nurse is absent, and when PLAN2 checks a slot. pgTAP: an absence today from 10:00 releases her untimed visit of today; an untimed visit tomorrow is not offered as `may_take` to a member absent tomorrow from 15:00.
- **ABS1-C2:** pgTAP asserts `overlaps_my_visit` for a released visit overlapping the caller's own planned visit, and null for one that does not.
- **ABS1-C3 (PO decision, answers engineering's OPEN "absence across several teams"):** availability belongs to the person, not to one team. Recording an absence applies to every team of that member in the same organisation (one row per team, or one row with the release in each team; engineering decides how); withdraw and shorten change all of them together. Each team sees only its own released visits and the from–to, as today. Whoever may record it for her (a colleague in any of her teams) may record it for all. pgTAP: a member of two teams, absence recorded by a colleague of team A, releases her visit in team B, and team B sees her absent.

**Decided, deviation accepted:** the e2e does not save an absence (seed isolation); the command is covered by pgTAP 046.
**Not decided here (stays OPEN, owner once real data exists):** visits held before 0046 by a member whose qualification changed (CR-052). No real client data exists in the pilot database yet (D-1), so nothing is unsafe today.

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
- [x] **Record unavailability.** A team member records her own unavailability on `/field`: start and end (date, optional time; default the whole of today). **No reason field and no free text**: NAVORA stores no reason for an absence. The command is audited and idempotent.
- [x] **For a colleague.** Any member of the same team can record it for a colleague (the sick nurse phones one colleague, not a dispatcher). It is audited with who recorded it, and the absent member sees it on her own `/field`. A member of another team or organisation cannot.
- [x] **No approval step.** Recording unavailability needs nobody's approval in NAVORA. It is an availability fact for planning, not a leave request: whether holidays need the employer's agreement stays outside NAVORA's rules and is not modelled here.
- [ ] **Her visits are released at once.** Every visit in the period where she is the responsible member and that has not started loses her as responsible member and becomes uncovered: the J3 uncovered flag, the OPS1 exception at its existing thresholds, and COVER1 at its lead time (once D-3 switches it on). Visits already started are untouched. The release is recorded in the J3 change log with the reason "Abwesenheit" (no further detail).
- [x] **The team takes them.** The `/field` view of every member of the team shows the released visits under "Offen im Team", in time order, with what the team view already shows for its own visits (F0 team-scoped read; nothing more). For each visit, the case's **deputy nurse, then the primary nurse** (J6), if present in the team and not the absent person, is marked "kennt die Klientin". This is a label, not an assignment.
- [x] **One tap, first wins.** A member takes a visit with one tap. It is atomic: if two take it at once, one gets it and the other sees "bereits übernommen". The taker becomes the responsible member; the planned time stays; she can move it with the existing J3 move-with-reason. J3 rules hold: a care assistant cannot take category B or needs-assessment visits, and the take button is not offered to her for them.
- [x] **Every uncovered visit, not only absences (PO 2026-10-23 12:15, from the OPS1 CGR-22 review).** "Offen im Team" lists every planned, not suspended, not covered visit of the team with nobody responsible, whatever made it uncovered: an absence, a removal (ADM1), a qualification change (CGR-11), PLAN2 without a deputy or primary nurse, or a hand-planned visit without a responsible member. The same one-tap take, with the same qualification and first-wins rules, makes the taker responsible, and the OPS1 `visit_uncovered` exception then ends with its cause (CGR-22: Operations cannot close it by hand). pgTAP: a hand-planned visit with nobody responsible → listed for every team member → taken → no `visit_uncovered`; a care assistant is not offered a B visit; another team cannot take it. This uses the accepted J3 model (team plus optional responsible member) and does not answer D-6.
- [ ] **Overlap is shown.** A released visit that overlaps one of the member's own planned visits is marked "überschneidet sich mit deinem Einsatz <time>". She can still take it (she may move one of them), but she sees it before the tap.
- [x] **PLAN2 respects the absence.** Visits PLAN2 generates inside a recorded absence are assigned to the deputy if she may perform them, else left uncovered, never to the absent member. Re-generation never re-assigns a released visit to the absent member.
- [x] **Withdraw or shorten.** The absent member (or the colleague who recorded it) can withdraw or shorten an absence before or during it. Visits nobody has taken yet return to her; visits a colleague took stay with that colleague.
- [ ] **Privacy.** Her own team sees that a member is unavailable from–to. Other teams, coordination roles and AN1 see only uncovered visits, never who is absent. Nothing about absences is shown or computed per nurse anywhere else.
- [ ] **Measured in AN1** (team and organisation level, small-team rule as in AN1):
    - share of released visits taken by the own team before the COVER1 lead time;
    - median time from absence recorded to the last released visit taken;
    - share of released visits taken by the deputy or primary nurse.
- [x] Works at phone width; recording an absence for today is reachable from the top of `/field` in at most two taps.
- [x] Negative tests:
    - another team's member neither sees the released visits nor can take them;
    - another organisation sees nothing;
    - a care assistant cannot take a category B or needs-assessment visit;
    - a member cannot record an absence for someone outside her team;
    - two concurrent takes give exactly one responsible member;
    - a started visit is not released;
    - no reason text can be stored with an absence (the command has no such parameter).

- [x] **Clinical gate (2026-10-22 23:00, CGR-15, CGR-11):** one eligibility and release rule for every path that takes a person off a visit (absence, removal, qualification change). It covers suspended visits (CGR-09), refuses or excludes in-progress visits (CGR-10), and respects qualification for B and needs-assessment visits at take, resume and complete (CGR-12, from CSR1).
- [x] **CGR-11:** `set_member_qualification` from `registered_nurse` to `care_assistant` releases the B and needs-assessment visits she may no longer perform, through the same release rule, logged with a fixed reason text. pgTAP.
- [x] **CGR-15:** a released visit that nobody takes stays alerted after its planned start, through CSR1's overdue-visit exception; it does not vanish at start time. pgTAP.
- [x] **Performed visits and open reports (PO 2026-10-23 03:10, from CGR-18):** recording an absence is **never refused**. A visit she is performing (`on_the_way`, `started`, `paused`) is not released and stays visible to the team through CSR1's stuck-visit exception (CGR-04); her missing or `draft` reports stay hers and appear as `report_not_final`. She stays a team member, so she can document on return. pgTAP: an absence recorded while she has a `paused` visit is accepted, that visit keeps her as responsible and performer, and it carries the stuck-visit exception; an absence recorded while she has a `draft` report is accepted and the report stays signable by her.
- [x] The PR names the latest Clinical Governance Report section and the CGR IDs it addresses.
- [ ] **ABS1-C1 (PO 2026-10-23 14:16):** an untimed visit is released when the absence covers any part of its date; the same whole-day interval for the absent checks at take, in "Offen im Team" and in PLAN2. pgTAP.
- [ ] **ABS1-C2 (PO 2026-10-23 14:16):** pgTAP asserts "überschneidet sich" (`overlaps_my_visit`) set and not set.
- [ ] **ABS1-C3 (PO 2026-10-23 14:16):** an absence applies to every team of the member in the organisation; withdraw and shorten change all; pgTAP with a member of two teams.

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
J3 (responsible member, uncovered flag, change log, qualification rule), J6 (primary and deputy), PLAN2 (generation), OPS1 (exceptions), COVER1 (lead time; switched off until D-3), AN1. All accepted, but J3, C1 and OPS1 were reopened on 2026-10-22 23:00: ABS1 starts after CSR1 delivers the qualification and overdue-visit rules (CGR-12, CGR-04). No open decision blocks it: no reason is stored, so no health data is processed; no approval rule is modelled, so no labour-law rule is assumed.

## Constraints and references
`DOMAIN_RULES.md` data minimisation and team-scoped access (F0, ADR-031). J3 (ADR-030), J6 (ADR-037), PLAN2 (ADR-042), OPS1 (ADR-035), COVER1 (ADR-045), HAND1 (ADR-047). Working time and leave law are outside NAVORA here (D-23 covers recorded working time only).

- **PO 2026-10-22 20:15:** ADM1 change 1 (a removed member's future visits are released) needs the same release as ABS1. Build one private release function (team, member, from, until, reason) and use it in both; whichever ships first creates it.

- **PO 2026-10-22 22:15:** the release function exists (ADM1 changes, #135, migration 0036); reuse it. Two additions for ABS1: (1) HAND1 "since your last visit" shows a `released` entry as the fact only, "Einsatz <Datum Zeit> wieder offen im Team", never a reason; e2e or pgTAP asserts it. (2) Every row a team can read carries a fixed reason text ("Abwesenheit"), never free text, as in the ADM1 pre-review.

## Open questions for engineering
- Is an absence a row per member with a time range and an exclusion on overlap, with release done by the same command (no job), cheaper than a job?
- Can "Offen im Team" reuse the J3 uncovered list with a team filter instead of a new read model?
