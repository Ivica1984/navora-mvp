---
id: FUP1
title: Follow-ups of SIGC and RLS3 - the outside-hours list counts the planned length, the banner promises what delivery does, billing sees whether a correction is billed
author: po
status: approved
updated: 2026-10-25
---

# FUP1 — Follow-ups of SIGC and RLS3 (one PR)

**Approved by the PO 2026-10-25 14:13 CET** (product authority; display and read-model changes only; no threshold, no clinical rule, no billing or tariff rule is set). Source: `cra` 2026-10-25 13:26 CET (PR #374) CGR-57 (S2), CGR-58 (S3), CGR-59 (S2), all advisory. Conditions of SIGC (accepted 14:13 with CGR-57 and CGR-58 as conditions) and of RLS3 (RLS3-4c, from CGR-59).

## Problem
- **CGR-57 (S2, before the list counts as SIG1-8 evidence, i.e. before go-live):** `visits_outside_watched_hours` (0068) treats a planned visit without an end time as one minute long (`private.visit_wall_range`, 0068:153-163), while ABS1's `private.visit_interval` (0069:42-48) gives it start + planned minutes A+B+C, else the rest of its day. A visit at 19:50 without an end and with 45 planned minutes runs to about 20:35 but is not listed under watched hours 07:00-20:00; a P1 there after 20:00 reaches Operations only in the app (SIG2-12). The list then tells the Clinical Owner that the plan is covered when it is not.
- **CGR-58 (S3):** `my_signals.watched_now` is judged when the banner is read, not when the step to Operations is made. A care assistant who takes a P1 no-show at 19:55 (watched until 20:00) reads "Meldung an Operations folgt", although the step, due after 20:00, stays in the app.
- **CGR-59 (S2, before invoicing, gate C):** the RLS3-4b billing view shows old and new value, the time of each correction and the version the billing fact rests on, but not whether the correction is contained in that version. A correction made after the countersignature is not in the billed snapshot (0043), and the billing reader cannot tell it from one that is.

## Users and journey step
Planning team and administrator (Planning → Visit: SIG1-8 control), care assistant and registered nurse taking a signal (Visit → safety signal), billing reader outside the visit's team (Documentation → Billing).

## Outcome
The list that replaces the manual SIG1-8 check uses the same visit length as every other safety check, the banner never promises a push that will not happen, and the billing view says per correction whether the billed version contains it.

## Acceptance criteria
- [ ] **FUP1-1 (CGR-57) One visit length everywhere.** `visits_outside_watched_hours` computes the interval of a planned visit without an end exactly as `private.visit_interval` does (start + planned minutes A+B+C, else to the end of its Zurich day); preferably by calling or sharing that function, so the two cannot drift. pgTAP with watched hours 07:00-20:00: a visit at 19:50 without an end and 45 planned minutes → listed; at 19:50 without an end and no planned minutes → listed; at 08:00 without an end and 20 planned minutes → not listed. Every existing 069 assertion keeps its result (the 06:50 case stays listed).
- [ ] **FUP1-2 (CGR-58) The banner follows the delivery.** For a taken P1 whose step to Operations is not stopped: if an Operations delivery of the signal already exists, the text follows its classification (pushed → "Meldung an Operations folgt" / sent wording as today; `outside_working_time` → `OPERATIONS_APP_ONLY`); if none exists yet, `watched_now` (or a new reader flag) is evaluated at the instant the step is due (the untaken threshold of the episode), not at `now()`. pgTAP: watched until 20:00, a care assistant takes at 19:55, the step is due after 20:00 → the reader flag says app only; an Operations delivery already sent outside the app → the flag follows it. Unit test on `takenText` for both. A missing flag still never promises the message (SIGC, `rules.ts`).
- [ ] **FUP1-3 (CGR-59, = RLS3-4c) Billed or not, per correction.** The billing view (level (b) of `visit_correction_history`, RLS3-4b) and the full trail (level (a)) return per correction `in_billed_version`: true when the correction time is at or before the countersignature time of the version the current billing fact rests on, or its signature time when no countersignature is required; false otherwise; null when no billing fact exists. pgTAP: a correction before the countersignature → true; a correction after it → false; a visit without a billing fact → null; level (b) still returns no reason and no corrector; no reader groups or counts corrections per person (D-23 term b). If #373 already carries this, FUP1-3 is met by #373 and the PR says so.
- [ ] **FUP1-4 No regression.** pgTAP, unit and e2e green; no assertion of 069, 070 or 071 removed or weakened; SIG1-8 stays a go-live condition (only the Clinical Owner lifts it).
- [ ] **FUP1-5 Inventory header current** (added by the PO 2026-10-25 16:11 CET at the RLS3 review; docs only). The header of `docs/engineering/READ_PATHS.md` states the merged state (0070 merged as 3d6e125, F-2, F-4, F-5 closed; F-1, F-3 open with their routes) instead of "RLS3 PR open; CI decides". If FUP1-3 adds `in_billed_version`, the `visit_correction_history` row names it. Optional for a PR already in review; then it rides in the next Engineering PR that touches `READ_PATHS.md`.
- [ ] One PR; the status row uses the ID `FUP1`.

## Rules and their input class
- FUP1-1: visit length for a safety check, *visit/schedule fact* (planned start, planned minutes); the rule already exists in `visit_interval`, it is reused, not invented.
- FUP1-2: display of a delivery classification, *visit/schedule fact* (watched period, threshold instant); no threshold changes (D-28).
- FUP1-3: an ordering of two recorded instants, *visit/schedule fact*. It states a fact; it decides no billing rule (what happens to a correction that is not billed is D-18 and the invoice brief, not this item).

## Out of scope
Any threshold or watched-hours change (D-28, D-32), a planning-time notice (challenge row 2026-10-25 13:16), what invoicing does with `in_billed_version = false` (D-18; challenge row 2026-10-25 14:13), the corrector or reason for any reader outside the team (D-23 item 10).

## Constraints and references
[`SIGC.md`](SIGC.md), [`RLS3.md`](RLS3.md) (RLS3-4b, RLS3-4c), [`DST1.md`](DST1.md); 0064, 0068, 0069, 0070 (#373); `cra` 13:26 (PR #374); D-23 item 11. Clinical review gate: in scope (safety signals, billing); `cra` reviews the merge commit before acceptance.

## Open questions for engineering
- Can `visits_outside_watched_hours` reuse `private.visit_interval` directly (it returns instants, the list compares wall-clock periods)? If not, name the shared helper in the ADR.
- Estimate: one additive migration, about 12-18 pgTAP assertions, one unit test.
