---
id: COND1
title: Pre-pilot conditions, one hand-off
author: po
status: approved
updated: 2026-10-26
---

# COND1 — Pre-pilot conditions, one hand-off

## Problem
Thirteen conditions the PO set on accepted or reviewed items (DOOR1, LEAVE1, WORK1, FUP1, AUD1) are approved but have no hand-off of their own. They live as prose in the parent briefs, so the watcher creates no `eng:<ID>` issue for them, and Engineering has no active item to claim. Evidence: hand-off #437 was created from the empty *Next up* placeholder (ID `–`); `eng` 2026-10-26 09:12 CET reported that none of these conditions has an `active` hand-off. Without one, conditions that gate the first real client (G-13, G-19, D-3) and the first reading of the North Star (WORK1-C1) are not scheduled.

## Users and journey step
Nurses and teams (Visit, Documentation, Quality), administrators (access end, audit read), Operations (outside-app signals). Cross-cutting: Visit → Documentation → Quality, plus the North Star measure in Analytics.

## Outcome
Each condition is built and tested exactly as specified in its parent brief, tracked under one item, so nothing that gates real data or the first pilot measure is left without an owner.

## Acceptance criteria
Each criterion is met when its parent brief's text is met in code and CI; the parent brief stays the specification. Build order (PO, unchanged from 07:15; patient safety is a precondition, then the value order):

- [ ] **COND1-1 = LEAVE1-C2, -C3, -C4** ([LEAVE1](LEAVE1.md), *Conditions*): a delivery to a person without access is not "reached" (CGR-64); a take counts only if recorded after the taker's latest access end (CGR-63, option (a)); no leaver's name on an OPS1 take or a quality event owner (display only). Tests as listed there. *Why first:* patient safety precondition; the PO's 07:15 build order, rides with COND1-2.
- [ ] **COND1-2 = DOOR1-12, -13, -14** ([DOOR1](DOOR1.md)): no code in the intake note either; one "Zugang" line; a `clinical` category only with an `APPROVED` register row (CGR-61). Tests and the `READ_PATHS.md` alignment as listed there.
- [ ] **COND1-3 = WORK1-C1 + WORK1-C4** ([WORK1](WORK1.md), *PO review 07:15* and *PO review 10:15*): `care_minutes` is the union of confirmed care segments minus their overlap with declared breaks; `care ≤ paid` for every version; pgTAP (a)-(c) as listed there. *Added 2026-10-26 10:15 (po, CGR-65):* WORK1-C4, the proposal uses the effective (F3-corrected) event time, marks corrected segments, and `/work` points to the visit's time correction when a visit segment is edited; no write-back; tests as listed there. *Why next:* value 1 (small, one expression), the North Star must not exceed 100 % before it is read as pilot evidence.
- [ ] **COND1-4 = FUP1-C1, FUP1-C2** ([FUP1](FUP1.md), *PO decision 18:12*): no outside-app promise in the last evaluator interval (Q16); none without a reachable Operations recipient (CGR-60).
- [ ] **COND1-5 = WORK1-C2, WORK1-C3** ([WORK1](WORK1.md), *PO 08:15*): information text `work1-notice-v2` (v1 acknowledgement does not carry over); a leaver's unexported confirmed days as one count for administrators only, her own count on `/work`. Tests as listed there.
- [ ] **COND1-6 = AUD1-M1, AUD1-M2** ([AUD1](AUD1.md)): purpose `billing` returns `code` values only, also to a team member; the stale F-3 line in `READ_PATHS.md` corrected.
- [ ] **COND1-7 Tracking.** Every PR names the conditions it closes in its title or body; the parent brief's condition line is marked done by the PO at review, not by Engineering. Several PRs are fine (COND1-1 and COND1-2 ride together, as asked by `cra` 05:26). COND1 is `delivered` when COND1-1 to COND1-6 are merged with green CI.
- [ ] **Negative cases** are the ones in each parent brief; COND1 adds none and removes none.

## Rules and their input class
COND1 adds no rule. Each condition keeps the input class stated in its parent brief: all are *visit/schedule facts* or display narrowing; DOOR1-14 refuses a *clinical content* category without an approved register row (it adds none). No threshold, no clinical value.

## Out of scope
LEAVE1-C1 (per-organisation access end): its trigger is a second organisation or a person in two, not the first real client; it stays in [LEAVE1](LEAVE1.md) until then. Any new capability; G-19 adoption by the employer (D-12); the final information text by the employer; D-4 retention; a change to any parent criterion (a change goes back to its parent brief through the PO).

## Constraints and references
Parent briefs DOOR1, LEAVE1, WORK1, FUP1, AUD1; G-13, G-19 and D-3 gates in `docs/product/CARE_OPERATING_MODEL.md`; D-23 item 15 (`lca` 07:45, advisory); CGR-60, -61, -63, -64, -65. WORK1 accepted 2026-10-26 10:15 CET (`cra` 09:26 without a blocking finding).

## Open questions for engineering
- If a condition turns out to need a clinical value or a legal reading not given in its parent brief, stop that condition and say so on the hand-off; do not choose one.
- The watcher fix for placeholder rows without an ID (`eng` 09:12, PLANNED) is Engineering's own; it is not part of COND1.
