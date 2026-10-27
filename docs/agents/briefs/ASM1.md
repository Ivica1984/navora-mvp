---
id: ASM1
title: Assessment record — the needs assessment is recorded once, as a signed fact, and the care plan shows which assessment it rests on
author: po
status: approved
updated: 2026-10-27
---

# ASM1 — Assessment record (D-13 B)

## Problem
The needs assessment is the billing basis and the start of continuity (D-13 *Context*), yet NAVORA records it only as a visit flag and a first-completion date (J3, 0014: `care_visits.is_needs_assessment`, `cases.needs_assessment_done_at`, set once by `coalesce`). A reassessment leaves no trace; the planned minutes per category on the care plan carry no link to the assessment they came from; a team cannot see that its care plan rests on an outdated assessment. Re-typing minutes from the provider's assessment tool is duplicate documentation with a transcription hazard (D-13 point 3). The Strategic Alignment Review rates interRAI-supported care planning *weak* (dimension 6), and every option of D-37 needs this record first. D-13 option B was decided by the PO on 2026-10-25 with five acceptance criteria (`lca` 01:41, `cra` 02:26); this brief builds it.

## Users and journey step
The registered nurse who performs the assessment; the team that writes and follows the care plan; billing (J5 reads the basis); later the GP information (ORD0 question 6). Journey: Case → Planning (care plan) → Billing.

## Outcome
Each assessment of a case is one record: when, with which instrument and version, by which registered nurse, where the full assessment lives, and the resulting minutes per category. The care plan shows which assessment it was written against, and the team sees when a newer one exists. Nothing is computed from it.

## Acceptance criteria
- [ ] **ASM1-1 The record.** An append-only table of assessment records per case: assessment date; instrument and version from the organisation's reference list (ASM1-6); the assessing registered nurse (a team member with a verified qualification, ADM1/D-29 link, or her GLN where recorded); the document reference (ASM1-3); planned minutes per category A, B, C as entered; author and time. Several records per case. No item, score, scale, CAP, output or free-text finding column exists (pgTAP checks the column list).
- [ ] **ASM1-2 Supersede, never overwrite** (D-13 criterion 1). A wrong record is corrected by a new record naming the record it supersedes, a reason of 10-500 characters and its author; the superseded record is kept, never shown or used as current. pgTAP: update or delete refused for every role; after a supersede the planning and billing reads return the new minutes only.
- [ ] **ASM1-3 The reference is an identifier** (D-13 criterion 2). The link to the full assessment in the provider's tool is an opaque identifier: pattern-checked, no spaces, bounded length (Engineering states the bound in the ADR), never a file name, title or free text; NAVORA stores no document. pgTAP: a reference with a space or above the bound is refused.
- [ ] **ASM1-4 Minutes only with their reference** (D-13 criterion 4). A record with minutes per category is refused without the reference of ASM1-3.
- [ ] **ASM1-5 The named assessor confirms** (D-13 criterion 5). A record entered by someone other than the registered nurse it names stays `unconfirmed` ("nicht bestätigt") until that nurse confirms it (audited, who and when); planning may use it and the team sees the state. pgTAP: entered by another member → `unconfirmed`; the named RN confirms → `confirmed`; nobody else can confirm.
- [ ] **ASM1-6 Instrument reference list.** Per organisation: instrument name, version, valid from, valid to. A record can name only an entry valid on its assessment date (pgTAP). Names only: no logo, no item text, no claim that NAVORA is licensed or endorsed; where an instrument name is a third party's mark, the list shows it as such (D-36 option A, `lca` terms (a)-(c)). The seed holds synthetic instrument names only. **No entry is marked "designated"** until D-37 is decided by the owner.
- [ ] **ASM1-7 Care plan against its assessment** (D-13 criterion 3). The care plan stores and shows the date of the assessment it was written against. When a newer non-superseded assessment exists for the case, the team sees "Neuere Bedarfsabklärung vom <Datum>" on the care plan (no block, no signal, no exception). pgTAP: plan written against record 1, record 2 recorded → the marker is returned to the team; a member of another team reads nothing.
- [ ] **ASM1-8 Existing reads keep working.** `cases.needs_assessment_done_at` and the J1 readiness item that reads it are unchanged in meaning (the first completed assessment visit); J3 planning and J5 billing facts are unchanged unless they now read the current record's minutes, which Engineering states in the ADR with a pgTAP proof that the billing totals of the seed are identical before and after.
- [ ] **ASM1-9 Reads.** The case's team (RN and care assistant) reads the records of its cases; the assessing RN confirms; Operations and administrators read no minutes or references of a case outside a stated purpose they already have (`READ_PATHS.md`; no read widened; pgTAP for another team, Operations, coach).
- [ ] **ASM1-10 Screens.** On the case (team view): the current assessment (date, instrument and version, assessor, state, minutes per category) and its history with superseded records marked; a form for a new record and for a supersede with reason. e2e at 390 px: record, see "nicht bestätigt", confirm as the named RN, supersede with a reason, see the marker on the care plan.
- [ ] **Negative.** No reassessment due date, interval, reminder, signal or exception is shown or computed. No category is derived from anything (the KLV mapping stays D-15, `clinical`). Nothing is imported from a tool (that is D-13 A, a later `owner` decision).

## Rules and their input class
- No rule that ranks, routes or escalates. The marker in ASM1-7 is a display of a *care-context fact recorded by a person* (the assessment date), comparing two dates; it blocks nothing.
- The reassessment interval and triggers are clinical rules (C-8, H-08, CR-002 `UNVALIDATED`) set only by the Clinical Owner (D-27, G-1). ASM1 builds none of them; a later increment shows "Neubeurteilung fällig" only once the Clinical Owner has set the interval.
- Which instrument a provider uses is the provider's choice and licence (D-13 point 1); NAVORA records the name.

## Out of scope
- The reassessment due display (waits for the Clinical Owner).
- Integration with the provider's tool (D-13 A, D-37 B: a later `owner` decision after D-12 names the provider and tool).
- Any interRAI item, scale, CAP or output; any computation (D-34, D-36 A).
- Designating an instrument (D-37).

## Constraints and references
D-13 (po-decided, option B; criteria 1-5 from `lca` 01:41 and `cra` 02:26); D-36 option A and `lca` terms (a)-(c) (2026-10-27 12:42); D-37 (open, owner); D-15 (KLV mapping, `clinical`); D-29 (qualification verification, real-data gate); D-4 (retention); J3 (0014), J5, ORD0; `READ_PATHS.md`; hypothesis P-9 (care graph gaps).

**Real-data gate:** D-29 answered (the assessor's qualification is verified) and D-11/D-12 name the provider whose assessment instrument and licence apply. Synthetic data until then.

## Open questions for engineering
- Does J5 read planned minutes from the care plan today? If ASM1 makes the current assessment the source, state the migration path so no billing fact changes for existing seed data (ASM1-8).
- Is the GLN already stored for members (ADM1)? If not, link the verified qualification and leave GLN as UNKNOWN in the ADR; do not add a GLN field without saying who verifies it (D-29).

**Clinical review gate:** applies (assessment, care plan, billing basis). `cra` reviews the merged build before acceptance.
