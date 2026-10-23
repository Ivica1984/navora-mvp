---
id: ABS1
title: Absence without the phone chain
author: po
status: approved
updated: 2026-10-23
---

# ABS1 — Absence without the phone chain: "I can't work" hands the day to the team

## PO review — 2026-10-23 18:15: part 3 met in code for every visit from today; one residual (ABS1-C5); awaiting clinical review

Reviewed ABS1 part 3: #212 (head 93a66f8, CI run 39978598901 green: app, db incl. pgTAP `050_abs1_part3` and the adjusted `048_abs1_part2`, e2e; merged as 1f64128, CI runs 39979449276 and 39979442607 green on the merge commit; runs 39981426191 and 39981419043 green on cfb4808; checked through the API). The PO read migration 0050 in full, the pgTAP 050 assertions, and searched every migration for commands that set `responsible_user_id` or insert visits. **The PO did not run the tests.** Evidence is merged code and tests plus green CI.

| Criterion | Result | Evidence |
|---|---|---|
| ABS1-C4 (a): `plan_visit` with an absent responsible member returns `rejected`/`responsible_absent` and writes nothing | met in code | 0050 §1: check after the qualification check, on the one interval (`private.visit_interval`, 0048) and the person-level `member_absent_during`; pgTAP 050 §1: refused on day +3 at 08:00 and 10:00, allowed on day +4, no row written |
| ABS1-C4 (b): the same visit planned uncovered is ok and listed in "Offen im Team" | met in code | pgTAP 050 §2 |
| ABS1-C4 (c): a move into her absence releases the visit (not refused), log "Abwesenheit", linked to the absence | met in code | 0050 §2: after the `moved` log, `private.release_visits_between` (the one release rule) over the part of the interval inside the absence; `absence_releases` row when her team has a row for the absence; result carries `released`. pgTAP 050 §3: responsible empty, date kept, log `moved` + `released:Abwesenheit`, listed in "Offen im Team", one `absence_releases` row; §6: withdrawing the absence returns it to her |
| ABS1-C4 (d): the same move outside her absence keeps her | met in code | pgTAP 050 §4: responsible unchanged, no `released` row |
| ABS1-C4 (e): absent via team A, not responsible in team B by hand | met in code | pgTAP 050 §5: she joins Mitte after the Nord absence; `plan_visit` in Mitte refused; a Mitte move into the absence releases the visit (unlinked: no Mitte row) |
| ABS1-N1: `released` counts only the caller's teams | met in code | 0050 §3 (`is_team_member(t.team_id)` guards the sum; the release itself is unchanged); pgTAP 050 §5: both visits released, the Nord colleague's count excludes the Mitte visit |
| No other hand path to an absent member | met, one residual | commands that set a responsible member: `plan_visit`, `reschedule_visit` (0014, patched), `take_open_visit` and the withdraw return (0046, 0048: absence-checked), PLAN2 (0025, 0030: absence-checked), `accept_cover` (0028: COVER1 condition before D-3). **Residual:** the release rule acts on visits from today on (0046:131), so `reschedule_visit` to a date **before today** inside her absence leaves the visit with her and returns `released: false` (engineering's UNKNOWN, ADR-061) |
| **Clinical gate** | **awaiting clinical review** | no `cra` section covers 0048 or 0050 (the newest sections, 14:30 and 15:00 on PR #203 head 31a6a16, predate both) |

**Deviations, decided:**
- Release without an absence row for that team (she joined the team after the absence was recorded): the visit is released but not linked, so a withdrawn absence leaves it in "Offen im Team": **accepted**. The error is in the safe direction (open and visible, never falsely covered); the team takes it in one tap.
- Move into the absence is released, not refused: as ordered at 16:18.
- **Move to a date before today inside her absence (engineering's question): refuse it.** Decision within product authority, the strict default; not a clinical rule. A visit in the past that names an absent member as responsible is either never done or recorded under the wrong person; neither may look settled. New condition **ABS1-C5** below. Whether a planned visit should be movable into the past at all is not decided here.

**PO status: stays `changes-requested`** (one small residual). ABS1 is accepted without another full review once ABS1-C5 is merged with green CI and a `cra` section covering 0048, 0050 and ABS1-C5 holds no blocking finding.

**Condition (concrete, testable):**
- **ABS1-C5 (patient safety, rides along with CSR1 part 10):** `reschedule_visit` returns `rejected` with reason `responsible_absent` and writes nothing (no `moved` log, date and time unchanged) when, after the move, the visit would still name a responsible member absent at its interval (in practice: the new date is before today). pgTAP: (a) move her visit to yesterday inside her absence → `responsible_absent`, visit and log unchanged; (b) the same move to yesterday outside any absence → ok, still hers; (c) the 050 case (c) for a future date still releases.

## PO review — 2026-10-23 16:18: part 2 met in code; awaiting clinical review; one new safety condition (ABS1-C4)

Reviewed ABS1 part 2: #206 (head 9bcd151, CI run 39962574922 green: app, db incl. pgTAP `048_abs1_part2` and `048_abs1_an1_measures`, e2e; merged as 2401a11, CI run 39963139033 green on the merge commit; the push run 39963129700 on 2401a11 was cancelled by the next push; run 39963865259 green on d264ea9; checked through the API). The PO read migration 0048 in full, both pgTAP 048 files, the diff of `absence-section.tsx` and `src/features/analytics/rules.ts`, and searched every migration for the absence checks. **The PO did not run the tests.** Evidence is merged code and tests plus green CI.

| Criterion | Result | Evidence |
|---|---|---|
| CGR-27 / ABS1-C1: one interval; untimed = whole date; start without end = start + A+B+C, else to the end of the date | met in code | `private.visit_interval` replaced in 0048 §1; every absence check calls it: release (0046:145), take (0046:351), "Offen im Team" and `known_by` (0046:384-410), `change_absence` (0048 §4). pgTAP 048 §0 (interval arithmetic), §1: absence from 12:00 releases the untimed visit; from 08:30 releases 08:00 without end with 60 min; 06:00 without end and without minutes released; 07:00 without end and 30 min stays; absence ending 07:59 keeps the 08:00 visit |
| CGR-27: the absent nurse cannot take either one | met in code | pgTAP 048 §2: `take_open_visit` → `absent` for the 08:00 no-end and the untimed visit; `may_take = false`; the absent deputy is skipped for "kennt die Klientin" |
| CGR-27: PLAN2's absent check | met (no change needed) | PLAN2 slots always carry a start and an end (0025 check), so the slot window equals the interval; `cra` 14:30 states the same |
| ABS1-C2: "überschneidet sich" set and not set | met in code | pgTAP 048 §3: overlapping 10:00 marked; 12:00 not marked; untimed not marked (no time to clash: accepted); she may still take it |
| ABS1-C3: applies to every team; withdraw and shorten change all; each team reads only its row | met in code | 0048 §2-§4 (`absence_group`, one row per team, overlap across her teams, person-level `member_absent_during`); pgTAP 048 §4: recorded by a colleague of Nord releases her Mitte and Nord visits; Mitte sees her absent, Nord's row not readable from Mitte; withdraw returns both |
| Measured in AN1 (three measures, small-team rule, aggregates only) | met in code | `pilot_kpis` patch 0048 §6; pgTAP `048_abs1_an1_measures`: values and bases at organisation level, `too_few` below 5, no team figure under three nurses, notes present, another organisation sees nothing, no member column. Labels in `analytics/rules.ts` |
| Her visits released at once (criterion left open at 14:16 for untimed visits) | met in code | as CGR-27 above |
| Privacy | met, one note | `team_absences` once per absence; the overlap result returns the row id only for the caller's own team. **Note (ABS1-N1):** `record_absence` returns `released` summed over all her teams, so a colleague of team A learns how many of her visits team B had in the period. Not shown in the UI and no health data; fixed with ABS1-C4 (count only the caller's teams) |
| **Clinical gate** | **awaiting clinical review** | no `cra` section covers 0048: the newest sections (14:30, 15:00, PR #203 head 31a6a16) predate #206. CGR-27 stays open in the report until `cra` reviews 2401a11 |
| **New: hand planning onto an absent member** | **gap (ABS1-C4, patient safety)** | the absence is checked when it is recorded, at take, in "Offen im Team" and in PLAN2, but **not** when a visit is given to her afterwards by hand: `plan_visit` (0014:171, `p_responsible_user_id` checks team and qualification only) and `reschedule_visit` (0014:279, keeps the responsible member when the visit moves into her absence) never call `member_absent_during` (search of all migrations: only 0046 and 0048 do). A visit planned or moved into her absence stays with her and looks covered: the gap ABS1 exists to close. The same path covers the deviation "a team she joins after the absence": its visits can only reach her by hand planning |

**Deviations, decided:**
- (3) "Offen im Team" covers 14 days from the shown day: accepted (beyond that, PLAN2 and the release still apply).
- (4) an absent member cannot take a visit (`absent`): accepted; it follows from the outcome.
- (5) e2e does not save an absence: accepted at 14:16.
- CGR-28 PLANNED as a D-3 condition: agreed (`briefs/COVER1.md`). `accept_cover` by a member absent at the visit's time is the same class; added to the COVER1 conditions.
- A team she joins later respects the absence but its visits are not released: accepted **with ABS1-C4**, which closes the only way such a visit reaches her.
- `absence_taken_by_known_share` uses the case nurses as recorded now; the last-take median counts a two-team absence per team: accepted, both labelled on `/analytics`.

**PO status: `changes-requested`** (small part 3). Part 2 is a sound delivery and stays merged. ABS1 is accepted without another full review once ABS1-C4 is merged with green CI and a `cra` section covering 0048 and part 3 holds no blocking finding.

**Condition for part 3 (concrete, testable):**
- **ABS1-C4 (patient safety):** no command gives a planned visit to a member who is absent at its interval (`private.visit_interval`). `plan_visit` with a responsible member absent at that time returns `rejected` with reason `responsible_absent` and writes nothing. `reschedule_visit` that moves a visit into its responsible member's absence releases it through the one release rule (fixed text "Abwesenheit", J3 log), so it appears in "Offen im Team" and as uncovered; it is not refused (the move itself is legitimate). pgTAP: (a) plan with an absent responsible → `responsible_absent`, no row; (b) plan the same visit uncovered → ok, listed in "Offen im Team"; (c) move her 08:00 visit to the next day inside her absence → responsible empty, log "Abwesenheit"; (d) the same move outside her absence keeps her; (e) a member of two teams absent via team A cannot be made responsible in team B by hand.
- **ABS1-N1 (rides along):** `record_absence` returns `released` counted over the caller's own teams only; pgTAP with the two-team case.

## PO note — 2026-10-23 15:25: clinical gate on part 1 is blocking (CGR-27); part 2 widened

The Clinical Governance Report section 14:30 (PR #203, head 31a6a16) reviewed 0046 and found **CGR-27 (blocking, S1)**; the 15:00 section keeps it open. The PO confirmed it in 0046:90-98: `private.visit_interval` makes a visit **without a start time** 00:00-00:01 (the PO's ABS1-C1) and a visit **with a start but no end time** one minute long. An absence from 08:30 therefore does not release a visit planned 08:00 without an end: it stays with the absent nurse, is missing from "Offen im Team", raises no `visit_uncovered`, and looks covered. **The PO did not run the tests.**

**PO status stays `changes-requested`.** Part 2 now has four conditions; CGR-27 is done **first** in part 2 and replaces the narrower ABS1-C1 (its pgTAP cases stay). The rest is unchanged: ABS1-C2, ABS1-C3 (endorsed by `cra` 14:30), AN1 measures. Accepted without another full review once part 2 is merged with green CI and a `cra` section on it holds no blocking finding.

- **CGR-28 (advisory, S2 once cover is on):** an absence does not end covers she accepted for another team. Cover is switched off (D-3), so this is **not** a part-2 criterion; it is a condition on enabling cover, recorded in `briefs/COVER1.md` and D-3.
- **AN2:** "absences recorded by a colleague and later withdrawn by the member" (the `cra` 14:30 suggestion) is an AN2 measure.

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
- [x] **Her visits are released at once.** (untimed and no-end visits met 16:18, #206; hand planning afterwards: ABS1-C4) Every visit in the period where she is the responsible member and that has not started loses her as responsible member and becomes uncovered: the J3 uncovered flag, the OPS1 exception at its existing thresholds, and COVER1 at its lead time (once D-3 switches it on). Visits already started are untouched. The release is recorded in the J3 change log with the reason "Abwesenheit" (no further detail).
- [x] **The team takes them.** The `/field` view of every member of the team shows the released visits under "Offen im Team", in time order, with what the team view already shows for its own visits (F0 team-scoped read; nothing more). For each visit, the case's **deputy nurse, then the primary nurse** (J6), if present in the team and not the absent person, is marked "kennt die Klientin". This is a label, not an assignment.
- [x] **One tap, first wins.** A member takes a visit with one tap. It is atomic: if two take it at once, one gets it and the other sees "bereits übernommen". The taker becomes the responsible member; the planned time stays; she can move it with the existing J3 move-with-reason. J3 rules hold: a care assistant cannot take category B or needs-assessment visits, and the take button is not offered to her for them.
- [x] **Every uncovered visit, not only absences (PO 2026-10-23 12:15, from the OPS1 CGR-22 review).** "Offen im Team" lists every planned, not suspended, not covered visit of the team with nobody responsible, whatever made it uncovered: an absence, a removal (ADM1), a qualification change (CGR-11), PLAN2 without a deputy or primary nurse, or a hand-planned visit without a responsible member. The same one-tap take, with the same qualification and first-wins rules, makes the taker responsible, and the OPS1 `visit_uncovered` exception then ends with its cause (CGR-22: Operations cannot close it by hand). pgTAP: a hand-planned visit with nobody responsible → listed for every team member → taken → no `visit_uncovered`; a care assistant is not offered a B visit; another team cannot take it. This uses the accepted J3 model (team plus optional responsible member) and does not answer D-6.
- [x] **Overlap is shown.** (pgTAP 048 §3, 16:18) A released visit that overlaps one of the member's own planned visits is marked "überschneidet sich mit deinem Einsatz <time>". She can still take it (she may move one of them), but she sees it before the tap.
- [x] **PLAN2 respects the absence.** Visits PLAN2 generates inside a recorded absence are assigned to the deputy if she may perform them, else left uncovered, never to the absent member. Re-generation never re-assigns a released visit to the absent member.
- [x] **Withdraw or shorten.** The absent member (or the colleague who recorded it) can withdraw or shorten an absence before or during it. Visits nobody has taken yet return to her; visits a colleague took stay with that colleague.
- [ ] **Privacy.** Her own team sees that a member is unavailable from–to. Other teams, coordination roles and AN1 see only uncovered visits, never who is absent. Nothing about absences is shown or computed per nurse anywhere else.
- [x] **Measured in AN1** (met 16:18, #206, 0048) (team and organisation level, small-team rule as in AN1):
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
- [x] **ABS1-C4 (PO 2026-10-23 16:18, patient safety; met in code 18:15, #212, except ABS1-C5):** no command gives a planned visit to a member absent at its interval: `plan_visit` refuses with `responsible_absent`; `reschedule_visit` into her absence releases the visit ("Abwesenheit"). pgTAP (a)-(e) in the 16:18 review. **ABS1-N1:** `released` counts only the caller's teams.
- [ ] **ABS1-C5 (PO 2026-10-23 18:15, patient safety):** `reschedule_visit` refuses with `responsible_absent` a move that would leave the visit with a member absent at its interval (a date before today); pgTAP (a)-(c) in the 18:15 review.
- [x] **ABS1-C1 (PO 2026-10-23 14:16; met in code 16:18, #206):** an untimed visit is released when the absence covers any part of its date; the same whole-day interval for the absent checks at take, in "Offen im Team" and in PLAN2. pgTAP.
- [x] **CGR-27 (met in code 16:18, #206; awaits `cra`) (blocking S1, `cra` 14:30; PO 2026-10-23 15:25; includes ABS1-C1):** one interval function for the release, the take, "Offen im Team", `known_by`, PLAN2's absent check and `change_absence`: a visit **without a start time** occupies its whole date (Europe/Zurich, 00:00 to 24:00); a visit **with a start and no end** occupies at least start + its planned minutes (A+B+C), and with no planned minutes to the end of its date. Arithmetic over planned data, no clinical rule. pgTAP: an absence from 12:00 releases that day's untimed visit; an absence from 08:30 releases a visit at 08:00 without an end and with 60 planned minutes; the absent nurse cannot take either one; an absence ending 07:59 does not release the 08:00 visit.
- [x] **ABS1-C2 (PO 2026-10-23 14:16; met 16:18, #206):** pgTAP asserts "überschneidet sich" (`overlaps_my_visit`) set and not set.
- [x] **ABS1-C3 (PO 2026-10-23 14:16; met 16:18, #206):** an absence applies to every team of the member in the organisation; withdraw and shorten change all; pgTAP with a member of two teams.

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
