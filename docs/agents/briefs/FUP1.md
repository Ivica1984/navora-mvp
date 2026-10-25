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

## PO review 2026-10-25 17:11 CET: criteria met, awaiting clinical review (not accepted)

**Reviewed:** PR #383 merged as `5fbda91` (merge commit; head `c93e82c`): migration 0071, ADR-084, pgTAP 069 (59 → 80) and 071 (81 → 88), unit `signals-rules.test.ts`, `rules.ts` (`operationsFollows`), remediation plans `clinical/remediation/CGR-57.md`, `CGR-58.md`, `CGR-59.md`, `READ_PATHS.md`. **CI** `app`, `db`, `e2e` green on head `c93e82c`, on the merge commit `5fbda91` and on `recovery/main` `9e97b03` (GitHub check runs read by the PO). **The PO did not run the tests**; Engineering ran them locally only with a pgTAP stand-in (vitest, typecheck, e2e not run locally); CI is the runner. `database.types.ts` was edited by hand.

| Criterion | Result | Evidence |
|---|---|---|
| FUP1-1 one visit length: shares `visit_interval` | met | `private.visit_wall_range(care_visits)` reads `private.visit_interval(v)` for a visit without an end or with end = start (0071 part 1); the 3-argument helper is dropped (069 catalogue assertion), so the two cannot drift |
| FUP1-1 pgTAP 19:50, 45 planned minutes → listed | met | 069 `f1950m45` listed; upper bound equals the wall reading of `visit_interval` |
| FUP1-1 pgTAP 19:50, no planned minutes → listed | met | 069 `f1950m0` listed (to the end of its day) |
| FUP1-1 pgTAP 08:00, 20 planned minutes → not listed | met | 069 `f0800m20` not listed; extra cases `f1930m20` not listed, `f1950eq` (end = start) listed |
| FUP1-1 existing 069 assertions keep their result (06:50 stays listed) | met | 069 `w0650` listed; plan 59 → 80, no assertion removed (diff shows only the plan line changed among removed lines) |
| FUP1-2 delivery exists → text follows its classification | met | `private.signal_step_outside_app`: made step → true only for an Operations delivery `pending` or `sent`; 069 `fsa` with an outside row `sent` → true, `outside_working_time` → false; `fsb`, `fsc` (no outside row, channel off) → false |
| FUP1-2 no delivery yet → judged at the instant the step is due | met | 069: watched until 20:00, P1 at 19:50 due 20:05, read at 19:55 → `watched_inside` true but `signal_step_outside_app` false |
| FUP1-2 reader flag and `takenText` | met | `my_signals.operations_outside_app` (0071); `operationsFollows` in `rules.ts`; unit test "follows operations_outside_app, not the reading instant" ; 069 `c3b`: `watched_now` and the new flag differ and the reader returns the new one |
| FUP1-2 a missing flag never promises | met | `operationsFollows`: only `true` promises; a row without the field falls back to `watched_now` (null → no promise) |
| FUP1-3 `in_billed_version` true / false / null | met | 071 v1: two corrections before the countersignature → true, one after → false; v4 without a billing fact → null; signature used when no countersignature is required (0071 `billed_at`) |
| FUP1-3 level (b) without reason and corrector; nothing per person | met | 071: Operations reads `reason`, `corrector_name`, `corrected_by_me` all null; argument-name catalogue check; no grouping in the reader |
| FUP1-4 no regression | met (CI) | `app`, `db`, `e2e` green on `c93e82c`, `5fbda91`, `9e97b03`; no 069, 070 or 071 assertion removed (plans only grew); SIG1-8 unchanged as a go-live condition (0071 header "Unchanged") |
| FUP1-5 inventory header current | met | `READ_PATHS.md` header and the `visit_correction_history` row (#383, 16:40) |
| One PR, status row ID `FUP1` | met | #383; `IMPLEMENTATION_STATUS.md` row `FUP1` |

**Business value and care model.** The list that replaces a person's manual SIG1-8 check now uses the same visit length as every other safety check, so a planning team can trust it without re-counting (less coordination, value 1 and 5; patient safety precondition). The banner no longer promises a push that will not happen, so a care assistant does not wait for Operations when she should call (safety). Billing reads whether a correction is in the billed version from two recorded instants, so no clerk compares logs (value 5, before invoicing gate C). **Architecture Handbook:** read models over recorded facts, definer readers with the RLS3 access levels, additive migration; aligned.

**Deviations (Engineering status row), decided:**
1. *End = start reads as no end in the list*: **accepted**; it matches `visit_interval`, which is the point of FUP1-1 (one length everywhere), and it lists more, never fewer.
2. *Watched periods read up to two days after the visit date*: **accepted**; covers a visit up to 30 planned hours, which no planned home-care visit reaches; protective.
3. *New flag instead of changing `watched_now`*: **accepted**; `watched_now` keeps its SIGC meaning (is a period running now), and the banner reads the new flag.
4. *Residual (UNKNOWN): a step due within the minute before a watched period ends may be classified one evaluator run later*: **decided as Q16** (po, product authority, display narrowing only): the banner promises the message only when a watched period runs **both** at the instant the step is due **and** one evaluator interval later (the scheduled job's cadence, one minute today per 0060; an operating fact, not a clinical value). Built as **FUP1-C1** below. Not a condition for acceptance: the window is at most one minute per watched-period end, and the wrong case is a promise the in-app delivery still covers (Operations receives the signal in the app either way).

**Condition (rides in the next Engineering PR that touches 0071's `signal_step_outside_app` or pgTAP 069; before go-live):**
- [ ] **FUP1-C1 (Q16) No promise in the last evaluator interval.** `private.signal_step_outside_app` (not-yet-made branch) returns true only when `watched_inside` is true at the due instant and at the due instant plus the evaluator interval (one minute; named once as a constant with a comment pointing to the cron schedule). pgTAP: watched until 20:00, step due 19:59:30 → false; due 19:58 → true; the made-step branch unchanged.

**Not accepted yet: clinical gate.** FUP1 is in the clinical review scope (safety signals, billing); `cra` reviews the merge commit `5fbda91` (0071) before acceptance, as for SIGC. The PO accepts on a `cra` section with no blocking finding on 0071. FUP1 moves from *Next up* 1 to the queue (rank 31).
