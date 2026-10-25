---
id: WORK1
title: The working day is proposed from the visits; the nurse confirms it instead of filling a timesheet
author: po
status: approved
updated: 2026-10-26
---

# WORK1 — The working day is proposed from the visits; the nurse confirms it instead of filling a timesheet

**Approved by the PO 2026-10-26 00:20 CET** (product authority; builds decision [D-23](../decisions/D-23.md) C plus D, `po-decided` 2026-10-24 21:10, which `lca` found compliant under every plausible interpretation on the federal sources read, on terms (a)-(e) and the 2026-10-25 04:10 additions). Its preconditions are met: RLS2 accepted (event reads narrowed to the team, D-23 item 9), RLS3 accepted (no teammate reads `actor_id` row by row, F-4, item 12). Built and tested on synthetic data only; real employees only after go-live gate **G-19**. No labour-law rule is assumed: NAVORA checks no break, rest or plan limit (D-23 item 8).

## Problem
- **A nurse records her working time twice.** The visits already carry depart, start, pause, resume and complete times (F1-F4, F7; `visit_events` 0007), yet the employer's working-time record (ArGV 1 Art. 73 content as read by `lca`, D-23 [W1]-[W3]) is a separate timesheet typed by hand at the end of the day or week. That is administration (value 5) taken from care or rest time.
- **The North Star is not measurable** (`docs/product/CARE_OPERATING_MODEL.md`): its denominator, paid working time, is not in NAVORA. AN1 shows only the share of care inside a visit, labelled as such, and never compares it with the Buurtzorg benchmark. Without confirmed paid time no pilot can show whether NAVORA raises the direct care share (value 1).
- **Unpaid work stays invisible.** Calls to a doctor, on-call advice by phone and the travel of a call-out happen outside visits; on a hand-written sheet they are forgotten or rounded away. Whether a nurse is paid for them depends on her employer, but she cannot claim what nobody recorded (value 3, hypothesis).

## Users and journey step
The nurse (any qualification) and her team. Journey: **Visit → Documentation**, then **Analytics** (team-level North Star). The employer receives only what the nurse exports.

## Outcome
At the end of her day the nurse sees her working day already laid out from her visits, answers two questions (breaks of 30 minutes or more; work outside visits), confirms with one action, and exports the confirmed month to her employer. Her team sees, for the month, how much of its confirmed paid time was direct care, never per person.

## Acceptance criteria
- [ ] **WORK1-1 Proposal from her own events.** A read model `my_working_day(date)` returns, **only to the signed-in nurse and only for herself**, segments derived from her own visit events of that Zurich calendar day: per visit the travel segment (`departed` → `started`), the care segment (`started` → `completed`, pauses as their own segments) and the report segment where a sign time exists (F7), each with **start and end as stored instants** (D-23 item 8a). Gaps are shown as gaps, never filled: before her first `departed` and after her last `completed` the proposal shows "Beginn des Arbeitstags?" and "Ende des Arbeitstags?" for her to enter. Cancelled and no-show visits contribute only the segments that have events. **No location data** is read or shown (item 1). pgTAP: a nurse with three visits gets exactly their segments with the stored instants; a colleague of the same team, the team's RN, a coach, Operations and an administrator get zero rows for her date (as themselves, the function returns only their own day).
- [ ] **WORK1-2 The day is never complete by default.** The proposal carries two questions that must be answered before it can be confirmed: (1) breaks of 30 minutes or more (none, or each with start and end); (2) work outside visits from a fixed list (team meeting, training, administration, on-call intervention without a visit, travel of a call-out, other), each with start and end, or "keine" (item 8b). Nothing is pre-confirmed and nothing is pre-ticked. pgTAP and unit: a proposal with an unanswered question is refused by the confirm command (`questions_open`); "keine" is an explicit answer, stored as such.
- [ ] **WORK1-3 Confirm and correct, audited.** `confirm_working_day(date, payload, idempotency_key)`, the nurse for herself only, stores the confirmed day append-only (version 1); a later change is a new version with a reason code (`segment_missing`, `time_wrong`, `break_missing`, `other`) and an optional note of at most 200 characters that **only she** reads; the earlier version stays readable to her. Audited (actor, date, version, time; never the note in a team-readable row). Refused for: another person's day, a day in the future, a member whose access has ended (LEAVE1, `access_ended`). Segment durations are elapsed time from stored instants. pgTAP: confirm, correct, both versions kept; refusals for each case; a segment across the repeated hour of 2026-10-25 counts its real length (DST1 test clock, item 8c).
- [ ] **WORK1-4 Export on her action.** The nurse exports her confirmed days of a month as CSV: date, segment kind, start, end (local time with UTC offset), elapsed minutes, version, confirmed at. **No client, case, address, visit identifier or note** in the file (the employer needs her time, not the clients'). The export is audited (who, month, when, number of days), its content is not stored again. Unconfirmed days are listed by date as "nicht bestätigt" in the file header, never filled. Unit test for the file; e2e at 390 px: proposal → answer both questions → confirm → correct → export.
- [ ] **WORK1-5 Nobody else reads her working day** (D-23 item 1, term (b)). No other person, coordination roles included, reads her proposal, confirmed days, versions or notes through any table, view or function. pgTAP **catalogue check** (pattern of LEAVE1-3): every table and read model `authenticated` can read returns, as a teammate, an RN of her team, a coach, Operations and an administrator, zero rows of her working-day data; a new table or function cannot slip through. No screen, export or report aggregates visit events **per person** for anyone but that person (catalogue: the working-day helpers are read only by `my_working_day`, the confirm and export commands and the WORK1-6 team aggregate).
- [ ] **WORK1-6 Team North Star (D-23 option D).** AN1 gains, per team and month, "Anteil direkte Pflegezeit an bestätigter Arbeitszeit": the care minutes of confirmed days (care segments) over the confirmed paid minutes of the same days (all segments minus breaks), counting **only confirmed days** in both numerator and denominator, with the number of confirmed days shown next to it. Shown only when the team passes the existing AN1 small-group suppression (0032: fewer than 3 people or a base below 5 → hidden); never per person, never ordered by value. The existing within-visit share stays, labelled as before. pgTAP: a team of 2 is suppressed; a team of 3 with 6 confirmed days shows the expected ratio; unconfirmed days change neither number; no per-person row exists in the result.
- [ ] **WORK1-7 Working time never feeds billing** (D-23 item 6). Catalogue check: no J5, billing-preview, billable-fact or export-to-payer function reads the working-day tables. `generate_billable_facts` output unchanged for the pgTAP fixture.
- [ ] **WORK1-8 Information before first use** (D-23 item 3b, 7c). Before her first proposal is shown, the nurse sees a fixed information text that names both uses (team colleagues see visit status times for care coordination; her own working-day proposal, which only she sees and exports) and acknowledges it once; the acknowledgement (who, text version, when) is recorded. The text is a draft for the employer: whether it meets DSG Art. 19 for a given employer is part of gate G-19, not of this brief. e2e: first visit to the page shows the text; after acknowledging, the proposal.
- [ ] **WORK1-9 Leaver.** After LEAVE1 `end_member_access` she reads and confirms nothing (LEAVE1-3 holds for the new tables: the LEAVE1 catalogue tests stay green with them); her confirmed days and versions are kept unchanged (LEAVE1-4; D-4 provisional rule: no deletion before the final rule). pgTAP.
- [ ] **WORK1-10 No regression.** pgTAP, unit and e2e green; RLS2, RLS3 and LEAVE1 catalogue assertions unchanged except for adding the new objects; `visit_events` and `visit_time_corrections` readers unchanged.

## Rules and their input class
- WORK1-1 segment derivation: *visit/schedule fact* (stored event instants). It displays only; it ranks, routes or escalates nothing.
- WORK1-2 the two questions and the "never complete by default" gate: *a fact recorded by the nurse about her own work*, not about a client; it gates her own confirmation only. Not *clinical content*, not "for the adviser".
- WORK1-6 team ratio: *visit/schedule fact* over confirmed working time; display only, suppression rule reused from AN1.
- **Not built:** any check or warning on breaks, rest periods, daily or weekly maxima, night or Sunday limits (`lca` finds those unresolved and read only from secondary sources; D-23 item 8). The 30-minute break threshold in WORK1-2 is the content of the record as `lca` read ArGV 1 Art. 73 ([W1]); it asks a question and never refuses or warns on a value.

## Out of scope
- NAVORA as the employer's working-time record (option B, D-23 item 5) and any payroll function.
- Plans, rosters and any limit check (D-23 item 8).
- An administrator's or employer's view inside NAVORA of a person's days; the employer receives only the nurse's export.
- Location data of any kind.
- Self-employed nurses and partnership models (D-12): the proposal works the same; whether a record duty applies is the employer's question under G-19.
- Automatic export to an employer system (a later brief once D-12 names the employer and its system).

## Constraints and references
- [D-23](../decisions/D-23.md) items 1-12 (`po-decided`; `lca` 17:57, 21:55, 2026-10-25 03:43, 07:50, 15:41; advisory, not legal advice). [D-4](../decisions/D-4.md) provisional rule (no deletion before the final rule).
- RLS2 (`visit_events`, `visit_time_corrections` team-scoped, 0066), RLS3-4 (F-4, 0070), LEAVE1-3 catalogue pattern (0074), DST1 test clock (0067, 0069), AN1 suppression (0032), AN2 org suppression (0057).
- North Star definition: `docs/product/CARE_OPERATING_MODEL.md` (direct care share; Buurtzorg 60 % as a benchmark, hypothesis 75 %).
- **Go-live gate G-19** (go-live gate index): no real employee confirms a day before (1) the licence holder adopts the nurse-confirmed export as its way of keeping the record and states whether ArGV 1 Art. 73b applies under its agreements (D-23 item 4; needs D-12), (2) the employer adopts the information text (WORK1-8) after an `lca` look at the final wording, and (3) D-4 carries a retention criterion for confirmed working days (D-23 item 7e).

## Open questions for engineering
1. Whether the report segment (WORK1-1) can be derived reliably from the F7 sign time alone, or whether report time written after the visit is better left to the nurse as a non-visit entry ("Administration"). Either is acceptable if WORK1-1's "never filled" rule holds.
2. Storage: one append-only table of confirmed day versions with the segments as rows or as a JSON payload; whichever keeps WORK1-5's catalogue check simple.
3. Whether the leaver's unexported confirmed days should appear as a **count** in the LEAVE1-12 result for the administrator (never times or content). The PO will ask `lca` before this is built; until then: not shown.
