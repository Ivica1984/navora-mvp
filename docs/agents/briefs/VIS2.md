---
id: VIS2
title: A second visit of the same client at the same time is visible before it is saved, and two such cards can be told apart
author: po
status: approved
updated: 2026-10-29
---

# VIS2 — Same-client overlap is visible before saving; same-slot cards are distinguishable

## Problem
`cra` CGR-97 (advisory S3, review 2026-10-29 23:10, PR #696; H-25, PS-86): neither planning (J3, PLAN2) nor VIS1 "Heute machen" (`move_visit_to_today`) checks whether the client already has a visit at an overlapping time on the target day. IMPLEMENTED fact (`cra`: no same-client overlap check in `supabase/migrations`). Two visits of one client at the same time then render as two `/field` cards with the **same accessible name** ("22:40 – 23:10, Testfall 08"); CGR-96 showed this happen in CI (two different synthetic visits, `e2e` red on `recovery/main` `1500cb3`). An intended double visit exists (two people for one transfer), so refusing it would be an invented rule. An unintended duplicate (planned twice, or moved onto an existing visit) gives a nurse two cards she cannot tell apart: one can be documented on the wrong visit, or both performed and recorded, a second billable fact for one service (H-14, H-25).

## Users and journey step
The nurse who moves a visit to today (VIS1) and the team member who plans or reschedules a visit (J3, PLAN2); the nurse reading `/field` on her phone. Journey: Planning → Visit (`ARCHITECTURE.md` data flow).

## Outcome
Whoever is about to put a second visit of the same client into an overlapping time on a day reads one factual sentence before she saves, and decides; nothing is refused. Two cards of the same client and time on `/field` can be told apart by sight and by a screen reader.

## Acceptance criteria
- [ ] **VIS2-1 Overlap fact before saving (planning and "Heute machen").** When a visit is created or rescheduled (J3 planning form, reschedule, VIS1-3b "Heute machen") and the client already has another non-cancelled visit on the target date whose time overlaps the chosen time, the confirmation shows one sentence in style `info` before saving, for example "Bei dieser Person ist am <Datum> um <Zeit> bereits ein Einsatz geplant." (wording `uxa`'s). No refusal, no extra tap, no warning colour above `info`, no reason field. The save goes through unchanged when she confirms.
- [ ] **VIS2-2 Team boundary (as VIS1-8 (2)).** If the overlapping visit belongs to a team the person cannot read, the sentence states only that a visit exists at an overlapping time on that date, with no team, member, service or time of the other visit; it never says "no visit" while one exists that she cannot read. The fact is computed by a SECURITY DEFINER function that returns yes/no (and, for a readable visit, its time) only for a client whose case the caller may already read (RLS2); no new read of another team's visit. Named in `READ_PATHS.md`.
- [ ] **VIS2-3 Distinguishable cards.** On `/field`, two cards of the same client whose times overlap carry different accessible names and a visible distinguishing line (for example the responsible member's display name or the planned service; choice and wording `uxa`'s). One card per visit row, as today.
- [ ] **VIS2-4 Audit.** The command's existing audit row records `overlap_shown: true|false` as a code value (AUD1 classes it `code`); no new audit table.
- [ ] **Tests (synthetic seed only).** pgTAP: the overlap function returns true for an overlapping same-client visit of the caller's team (with its time), true without detail for an overlapping visit of another team, false for a non-overlapping or cancelled visit and for a different client; a caller who cannot read the case gets nothing; the save of an overlapping visit is not refused (planning and `move_visit_to_today`). Unit: the sentence for the readable and the unreadable case. e2e at 390 px: "Heute machen" onto a slot where the client already has a visit shows the sentence and the move completes; two same-slot cards of one client have different accessible names (this test owns its own client or slot, so it does not depend on another spec's fixtures; see CGR-96).
- [ ] **Negative.** No visit is refused or delayed for an overlap; no reason is required; no colour above `info`; no person or team of a visit she cannot read is shown; nothing is counted per person.

## Rules and their input class
- VIS2-1/-2 overlap fact: *visit/schedule fact* (two recorded visit times of one client); display only, it does not rank, route or escalate. **No rule is set** on whether a same-client overlap is allowed, needs a reason or a second confirmation, or how it is billed: Clinical Owner and billing owner (`cra` CGR-97 asks them; UNKNOWN). If one is ever set, it is a register row with owner `clinical`, PROVISIONAL, raised before build.

## Out of scope
- Any refusal, reason code or second-person confirmation of an overlap.
- Overlap across different clients for one nurse (her own double booking: PLAN3 "within … overlap" covers proposals; a manual check is a later item).
- Billing de-duplication: J5 facts rest on signed reports; whether two overlapping visits of one client are both billable is D-18 / the billing owner's.

## Constraints and references
- `cra` CGR-97 (PR #696), CGR-96 (#693), VIS1-8 pattern (fact sentence, team boundary), RLS2, READ_PATHS, AUD1 code classes. `ARCHITECTURE.md`: the record shows facts, the team decides.
- Synthetic data only (owner rule 2026-10-29, D-1). Before G-23 (first real organisation) and before PLAN3 proposals reach a team.

## Open questions for engineering
- Whether one function can serve the J3 form, reschedule and `move_visit_to_today` (preferred: one read path).
- Overlap definition: half-open time intervals on the same date, the same as PLAN3's member-overlap test, named in the ADR.

## PO notes
- **2026-10-29 23:15 CET, approved** from `cra` CGR-97. **Why:** *Why can the same client get two visits at the same time without anyone seeing it?* Because planning and the move were built per visit and never look at the client's day. From scratch, the record that already holds both visits tells the person deciding, at the moment she decides; that costs no tap and needs no dispatcher to spot duplicates later (value 5, value 2 continuity, safety precondition: one documentation per service). Refusing would invent a clinical rule; showing the fact does not.
- Placed after AIG1 and before PLAN3: PLAN3 proposes assignments for existing visits and must not compound duplicates; small (one function, one sentence, one name change).
