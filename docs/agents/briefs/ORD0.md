---
id: ORD0
title: The doctor link that must not get lost (GP informed, order without end date)
author: po
status: approved
updated: 2026-10-24
---

# ORD0 — The doctor link that must not get lost

## Problem
Two gaps between home care and the client's doctor, found by `cra` on 2026-10-24 02:26:
- **CGR-36:** when A/C care is planned without a medical order, J1 opens the task "Hausärztin/Hausarzt informieren (A/C ohne Verordnung)", but no command can complete it; it closes only when the case closes. NAVORA cannot record whether, when and how the doctor was informed, and the permanent open task teaches teams to ignore tasks. `lca` reads KLV Art. 8a Abs. 1bis as: the needs-assessment result **is** sent promptly to the treating doctor (advisory, D-22).
- **CGR-38:** an order recorded `present` without an end date never raises a signal, and PLAN2 keeps generating B visits for it without end. Billing already refuses such an order (CR-046), so the money is protected but the care is not: nobody is prompted to renew.

**Why does this workflow exist?** Chasing the doctor by phone and fax exists because nobody can see what was sent and what is missing. ORD0 makes both facts visible to the team that owns the case, without a coordinator; ORD1 (draft, D-22) later removes the chasing itself.

## Users and journey step
The team of the case (registered nurses and care assistants), Operations; step Case → Planning (J1, J3, PLAN2).

## Outcome
The team records in one step that the doctor was informed, and the task closes. An open-ended order on B care is a visible exception until an end date is entered.

## Acceptance criteria
Product decisions on CGR-36 and CGR-38 (PO, 2026-10-24 03:10, product authority). No deadline, no content of the information, no order duration and no billing effect is decided here: those stay D-22 (`legal`, `clinical`).

- [ ] **ORD0-1 Record "doctor informed" (CGR-36).** A member of the case's team records "Hausärztin/Hausarzt informiert" with the date it happened (not in the future, not before the case was created; PO 2026-10-24 07:10 on CGR-40: the doctor is often informed at the needs assessment, before the task exists, and the true date must be recordable) and one channel code from a fixed list: `elektronisch`, `brief`, `telefon`, `persoenlich`. Actor and recording time are set by the server; no free text, no health data. The command is audited and idempotent (a replay returns `duplicate`).
  - pgTAP (CGR-40): a date between case creation and task creation → `ok`; a date before case creation → `rejected`; a future date (Zurich day) → `rejected`.
- [ ] **ORD0-2 It closes the task.** The record sets the `inform_gp` task to `done` with `done_by` and the date. Nothing else closes it except a case close (today's behaviour). `complete_case_task('inform_gp')` stays refused.
- [ ] **ORD0-3 Shown.** The case view of the team shows "Hausärztin/Hausarzt informiert am <Datum> (<Kanal>)"; while open, the task shows the one-tap action. HAND1 lists the record as an entry.
- [ ] **ORD0-4 Order without end date (CGR-38).** A running case with an active B care-plan item and a medical order `present` without an end date raises a P3 exception "Verordnung ohne Enddatum" for the team (`/team`) and OPS1. It is not closable by hand while it holds; it ends when an end date is entered, the order is no longer `present`, or no active B item remains. Intake keeps accepting an order without an end date (`lca` reads KLV Art. 8 Abs. 2-4 as allowing open-ended B orders in some cases; advisory), so the exception prompts, it does not block.
- [ ] **ORD0-5 pgTAP (the `cra` case set).** A/C visit planned without an order → task open; a team member records it → `done`, `done_by`, an audit row; a non-member → `rejected`; another organisation → `rejected`; replay → `duplicate`; date in the future → `rejected`. B item + `present` without end date → exception; end date entered → gone; A/C only → none; another organisation → none; hand close → refused.
- [ ] **ORD0-6 Evidence.** AN2 measure 10 includes `order_without_end_date` in "how exceptions end"; the share of `inform_gp` tasks done within 7 days per team is shown as evidence for D-22 (not as a deadline).

## Out of scope
- The deadline and content of the doctor's information, and whether it is a billing condition (D-22, `legal`/`clinical`).
- The doctor's issue date and GLN/ZSR of an order (`lca` note 2 on D-22): asked of `eng` in the D-22 package; built with D-22's answer or ORD1.
- Sending anything to the doctor from NAVORA (ORD1, draft).

## Constraints and references
CGR-36, CGR-38 (`reports/CLINICAL_GOVERNANCE.md` 2026-10-24 02:26); CR-003, CR-004, CR-005, CR-046; D-22 package (`decisions/D-22.md`); J1, J3, PLAN2, OPS1, HAND1. No personal or health data in the record.

## Open questions for engineering
- Whether ORD0-1 is a new command or an extension of `complete_case_task` with a typed payload; the `cra` test case "complete_case_task('inform_gp') still refused" applies only if it is separate.
- Whether the P3 exception fits the existing `derived_exceptions` reader without a new table.
