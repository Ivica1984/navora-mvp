---
id: DOOR1
title: What the nurse needs at the door
author: po
status: approved
updated: 2026-10-24
---

# DOOR1 — What the nurse needs at the door

**Approved by the PO 2026-10-24 23:10** (product authority). Source decisions: D-17 parts 1-2 and D-19 part 2, both decided by po on complete packages (`cra` 22:26, `lca` 17:57, 22:50; Engineering drafted by po, not confirmed by eng). No clinical rule: the clinical categories (D-17 part 3) and the no-show protocol (D-19 part 1) stay with the Clinical Owner.

## Problem
- Before a first visit, or a cover, someone phones the nurse to brief her: how to get in, who holds the key, which language. In a self-organised team nobody is paid to make that call, and the briefing is lost after it (challenge row, D-17).
- NAVORA already records the access and language notes at intake (`cases.access_notes`, `cases.language_notes`, 0013, 0017), but **no reader in `src/features/field` or the field page shows them**: the nurse at the door sees none of it (D-17 Engineering, drafted by po, read on 515d494, not tested). H-03 (S1, open): the nurse is unaware of the access arrangement or other safety context.
- A no-show record reads like "did not open at the door" even when only a phone attempt was made (`cra` 22:26, D-19 (2)), and "Notfallkontakt informiert" is recorded without the basis of that disclosure (recorded consent or emergency), which the provider may later have to show (`lca` 22:50, D-19 note 1).

## Users and journey step
Nurse and care assistant on `/field` (Visit), the covering member while a cover is active (COVER1, still off), the team in HAND1 (Documentation). Intake (Referral → Case) records the access arrangement once.

## Outcome
The nurse opens her visit card and sees how to get in, which language, and what is not known yet, without a phone call. A no-show record says whether she was at the door, and a disclosure to an emergency contact says on which basis it was made.

## Acceptance criteria
- [ ] **DOOR1-1 Notes on the card.** Given a visit of team A whose case has `access_notes` and `language_notes`, when a member of team A opens `/field`, then the card shows both; when a note is empty, the card shows "nicht erfasst" (never blank). The covering member sees them only while her cover is active (`private.cover_team_for`). pgTAP on the read model: a member of team B, a member of another organisation, a client or partner account and `anon` read nothing; a covering member after the cover ended reads nothing.
- [ ] **DOOR1-2 Category reference list.** A versioned reference table of safety-alert categories (code, label, class `organisational` or `clinical`, version, active from, source). It ships with **one organisational category, the access arrangement**, and **no clinical category**. pgTAP: the catalogue holds no active `clinical` row; a `clinical` row cannot be inserted without an approval reference (D-17 part 3, the Clinical Owner).
- [ ] **DOOR1-3 Values, append-only.** A value per case and category is `ja`, `nein` or `unbekannt`, with a note (at most 300 characters), a source (`referral`, `client`, `relative`, `doctor`, `team`), who recorded it and when. "ja" requires the note. No update, delete or truncate for any role (trigger), audited without the note. The read model returns the latest value per category; a change never overwrites the earlier value. pgTAP for each refusal and for "latest wins".
- [ ] **DOOR1-4 Display form.** On the card and at intake: "unbekannt" is shown first and visually distinct from "nein"; each value shows who, when and source; a category with no value shows "nicht erfasst". The access-arrangement field says where and who holds the key and its help text reads "Ort und wer den Schlüssel hat, nie den Code". A note containing a run of four or more digits is refused for this category with "Bitte keinen Code erfassen" (engineering may propose a better guard; no code is ever stored). Unit test on the guard; e2e at 390 px.
- [ ] **DOOR1-5 "An der Tür".** `record_no_show` takes a required fact "an der Tür: ja/nein"; the note stays required. Rows recorded before this change read "nicht erfasst". The fact is shown with the no-show in HAND1 and in the Operations exception detail. pgTAP: both values stored and shown; refused without the fact.
- [ ] **DOOR1-6 Basis of "Notfallkontakt informiert".** `record_no_show_outcome` with `emergency_contact_informed` requires a basis: `recorded_consent`, `emergency` or `other` (with `other` the note must say which); every other outcome refuses a basis. Shown with the outcome ("Grundlage: erfasste Einwilligung / Notfall / andere"). pgTAP: refused without a basis; refused with a basis on another outcome; stored and shown.
- [ ] **DOOR1-7 Changes in HAND1.** A new value row, and the two no-show facts, appear in "since you were last here" (0033) as a changed fact with who and when.
- [ ] **DOOR1-8 Display only.** No alert value and no door fact raises a signal, changes the J1 readiness result, blocks planning or ranks anything. pgTAP: with the access arrangement `unbekannt`, J1 readiness and planning of a hospital-discharge first visit are unchanged; `access_unknown` stays the only task from an empty access note (0013), opened as today.
- [ ] **DOOR1-9 Read scope.** Values, notes and the two no-show facts are read only by the case's or visit's team and the covering member while the cover is active; Operations sees a no-show through the existing signal and exception readers, without the free-text notes. No AN1, AN2, billing, export or push function reads the notes (pgTAP catalogue check, as F6R-7). Consistent with RLS2: nothing widened.
- [ ] **DOOR1-11 Operations sees what was done, not the note (CGR-51, Q13 F-1, PO 2026-10-25 02:10 CET).** In `operations_exceptions()` (and any Operations read model of a no-show or interruption), the row shows "an der Tür: ja/nein" (DOOR1-5), the recorded outcome code and its basis (DOOR1-6) and the time, with **no free-text note**; without an outcome it shows "Ergebnis offen"; the team keeps the note. The free-text excerpt (120/200 characters, `READ_PATHS.md` F-1) is removed **in the same PR**, not before. pgTAP: a no-show with "an der Tür: ja" and outcome "Notfallkontakt informiert" → Operations' row carries both codes and the basis and no note text; without an outcome → "Ergebnis offen"; an interruption → its reason code and no note text.
- [ ] **DOOR1-10 No regression.** pgTAP, unit and e2e green; C1 no-show path, SIG1 P1 signal and SIG1-C1 unchanged (a no-show without an outcome stays P1).

## Rules and their input class
- DOOR1-3/-4 alert values: *care-context fact recorded by a nurse*, **display only**, so not "for the adviser" (`cra` 22:26 D-34 note).
- DOOR1-5 "an der Tür" and DOOR1-6 basis: *care-context fact recorded by a nurse*, display and record only.
- DOOR1-8 adds no rule that ranks, routes, escalates or blocks. The P1 no-show signal is unchanged (*visit/schedule fact*).
- No *clinical content*: no clinical category, no step, no waiting time.

## Out of scope
- **Clinical categories** (allergies, fall risk, infection precautions or others): only from the Clinical Owner (D-17 part 3).
- **The no-show protocol** (steps, order, waiting times, emergency trigger, who may act): the Clinical Owner (D-19 part 1). No step text, and the PO's 15-minute hypothesis bound is never shown as a waiting time.
- **The emergency contact on the card:** later, only through a team read model with the D-9 g4 consent flag, never by re-granting the revoked `cases` columns (`lca` 22:50); waits for D-9 and `lca` question 6.
- Key-safe or door codes: never stored.
- Any block on readiness (option C rejected as product default).

## Constraints and references
D-17, D-19 (packages), D-9 (intake legal basis; no real data before its gates), D-3 and RLS2 (read scope), D-34 (no interpretation), H-03, PS-4, CR-014, `cra` 22:26 (D-17 (3) form conditions, D-19 (2)), `lca` 17:57 (minimisation: a precaution, never a diagnosis; no code) and 22:50 (basis fact; team read model). Real data stays blocked by D-1, D-9, D-29 and the D-3 gates.

## Open questions for engineering
1. Whether the language notes belong in the category table or stay as the existing note (the PO's view: keep the note, show it; no second record, D-15).
2. Whether "an der Tür" and the basis fit as columns on `visit_status_notes` or need their own append-only rows.
3. Size estimate; DOOR1 may be split into (a) DOOR1-1, -5, -6, -7 and (b) the category table, in that order.
