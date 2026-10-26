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
- [ ] **COND1-4a** (*PO 15:16*, ADR-095 deviation 1): one pgTAP assertion in 082 or later: no Operations member with open access, one administrator `push_active` in the `signal_operations_users` fallback, inside the watched period → the not-made branch returns true. Skip if 082 already asserts it (say which test). Rides in any later COND1 PR.
- [ ] **COND1-5 = WORK1-C2, WORK1-C3** ([WORK1](WORK1.md), *PO 08:15*): information text `work1-notice-v2` (v1 acknowledgement does not carry over); a leaver's unexported confirmed days as one count for administrators only, her own count on `/work`. Tests as listed there.
- [ ] **COND1-6 = AUD1-M1, AUD1-M2** ([AUD1](AUD1.md)): purpose `billing` returns `code` values only, also to a team member; the stale F-3 line in `READ_PATHS.md` corrected.
- [ ] **COND1-8 = LEAVE1-C5** ([LEAVE1](LEAVE1.md), *PO decision 14:30*; CGR-67): an OPS1 exception take and an `in_review` quality claim count only if recorded after the person's latest access end (the LEAVE1-C3 rule, by the access-event sequence as in 0080:73-101); a restore does not bring her name back. pgTAP: take an OPS1 exception and claim a quality event, end the access, restore it → both read as untaken (`take_access_ended`, `claim_ended`), no name; a take or claim recorded after the restore counts. *Added 2026-10-26 14:30 (po).* Build after COND1-4.
- [ ] **COND1-9 = DOOR1-15** ([DOOR1](DOOR1.md), *PO decision 14:30*; CGR-66): the code guard stays as built; a phone number and a postal code stay refused in `cases.access_notes`. The help text under "Zugang zur Wohnung" reads exactly "Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code" (intake and the DOOR1-4 note). Unit and pgTAP pin "079 123 45 67" refused (22023), "8004 Zürich" refused, "Schlüssel bei der Tochter, Hintereingang" accepted. *Added 2026-10-26 14:30 (po).* Rides in any later COND1 PR.
- [ ] **COND1-10 = DOOR1-16** ([DOOR1](DOOR1.md), *PO decision 14:30*; CGR-68, interim part): `node scripts/agents-check.mjs` fails when a row of `docs/agents/clinical/CLINICAL_RULE_REGISTER.md` has status `APPROVED` and names no approval record (a file under `docs/agents/clinical/approvals/CR-nnn.md` with the approver's role, the G-1 reference and the date). Unit test: an `APPROVED` row without a record fails; with one it passes; today's register (no `APPROVED` row) passes. The required review by the named Clinical Owner (e.g. CODEOWNERS) is the owner's, after G-1, and not part of COND1. *Added 2026-10-26 14:30 (po).* Rides in any later COND1 PR.
- [ ] **COND1-7 Tracking.** Every PR names the conditions it closes in its title or body; the parent brief's condition line is marked done by the PO at review, not by Engineering. Several PRs are fine (COND1-1 and COND1-2 ride together, as asked by `cra` 05:26). COND1 is `delivered` when COND1-1 to COND1-6, COND1-4a and COND1-8 to COND1-10 are merged with green CI (*amended 2026-10-26 14:30 and 15:16, po*).
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

## PO decisions 2026-10-26 14:30 CET (product authority; no clinical value, no threshold, no legal reading)

Inputs: `cra` 13:39 (CGR-66, CGR-67, CGR-68, all advisory; `reports/CLINICAL_GOVERNANCE.md`), `eng` 13:50 (#451, COND1-3 deviation). The PO read 0080:62-216, 276-410, 421-436, 0073:177 and the intake help text (`src/app/(protected)/intake/intake-client.tsx:391-396`); the PO ran no test. COND1 is not reviewed yet (COND1-7).

1. **CGR-66 → COND1-9 (DOOR1-15): keep the guard; no phone number or postal code in the access note.** Why: the team's read of the emergency-contact phone is revoked on purpose (0015:68); a free-text note on every team member's phone must not become a side channel for a third person's number. The D-17 working view (`lca` 17:57, 22:50) already says the contact is the one captured for D-15, reused, shown only with the D-19 consent flag, read through a team read model. The postal code belongs in the address. Whether the nurse at the door needs the key holder's reachability on the card is added to the **D-17 part 3** ask (Clinical Owner); if yes, it is a structured contact, never a weaker guard. Data protection: the decision keeps the stricter default and adds no processing, so no `lca` re-check is requested.
2. **CGR-67 → COND1-8 (LEAVE1-C5): the C3 rule for OPS1 takes and quality claims too.** Why: the reason for option (a) holds here (she has no push subscription after the end and may not know she holds the claim); one rule for every claim is simpler to read and to test than two (value 5). Display and counting only; the P2 → P1 clock and QG1 rules are unchanged. If a quality claim has no recorded time to compare with the access sequence, Engineering says so on the hand-off and proposes; no stored row is rewritten.
3. **CGR-68 → COND1-10 (DOOR1-16), interim part only.** Why: the gate for the first clinical category must not rest on a cell any agent PR can change. The interim check only tightens `agents-check`; the required review by the named Clinical Owner stays with the owner (G-1).
4. **`eng` 13:50 deviation on COND1-3 (WORK1-C4 links by event instant, not by visit id): accepted provisionally, final at the COND1 review.** Why: WORK1-1 and pgTAP 079 keep `my_working_day` free of identifiers; the hint still points to the correction on the visit, and a segment she already edited links to her day (no wrong link, only a less exact one). Adding `visit_id` to her read model is not asked for now; the PO reopens it if the pilot shows corrections made in `/work` that never reach the visit (WORK1-C4 hypothesis, AN2).

## PO decisions 2026-10-26 15:16 CET (product authority; display narrowing only; no clinical value, no threshold, no legal reading)

Inputs: `eng` 14:59 (#457 merged a6757d0, CI `app`, `db`, `e2e` green on 4e0cd29), ADR-095 deviations (1) and (2) (listed as (9) and (10) in the COND1 status row). The PO read ADR-095, 0062:70-119 (`push_vendors_counted`, channel switch), the D-32 and D-33 rows. **The PO ran no test.** COND1 is not reviewed yet (COND1-7); the FUP1-C1/-C2 lines are marked done at the COND1 review. `cra` review of 0082 OPEN.

5. **ADR-095 (1): "Operations member" = the step's recipient set `signal_operations_users` (admins in its no-Operations fallback): accepted.** Why: the FUP1 outcome is that the banner never promises a push that will not happen, and the made-step branch already "follows the real delivery". Counting exactly the people the step will reach keeps prediction and delivery one rule (value 5, and a care assistant is not told "app only" while an admin does get the push). A role-only reading would add a second recipient definition to keep in step. Test asked for at review: the existing pgTAP 082 cases stay; if 082 has no case for the fallback (no Operations member with open access, one admin `push_active` → true), Engineering adds it in the next COND1 PR (COND1-4a, one assertion).
6. **ADR-095 (2): the channel check reads `enabled` and `enabled_since` only, without repeating `push_vendors_counted`: accepted.** Why: the channel cannot be switched on without `push_vendors_counted` (0062:119), and only Google and Microsoft endpoints are stored at all (D-32, D-33 owner 2026-10-26), so a Safari or Firefox subscription can never make the banner promise a push. Repeating the check would duplicate a precondition, not narrow the promise. If the vendor allow-list ever changes after the channel is on (D-33 reassessment, G-20), that change must re-check `push_vendors_counted` at the switch, not here.
