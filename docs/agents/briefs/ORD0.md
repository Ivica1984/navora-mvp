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

## PO review — 2026-10-24 13:15: reviewed, **awaiting clinical review** (not accepted)

#284 (head 4f938f6, merged as 2561463; migration 0061, ADR-075). CI green on the head (app, db incl. pgTAP 063, e2e) and on `recovery/main` f35d60e, which contains the merge (read through the GitHub API; on the merge commit itself `e2e` shows *cancelled*, superseded by the next push, not failed). **The PO did not run the tests.** The status row still says `in-review`; #289 (eng, open) sets `delivered`. The review starts on the merge with green CI (PO instruction C).

**Clinical review gate (README).** ORD0 is in scope (doctor information, medical order, B care). Findings considered: CGR-36 and CGR-38 (the brief's source; remedies built as decided, remediation plans `clinical/remediation/CGR-36.md`, `CGR-38.md`), CGR-40 (date lower bound = case creation: met). The newest `cra` sections (#259 06:30, #278 10:26, both still open) were written before 0061; **no section covers 0061**. So the PO completes its own review and **does not set `accepted`**; `cra` is asked to review 0061 (and CR-069, CR-070).

| Criterion | Result | Evidence |
|---|---|---|
| ORD0-1 record "doctor informed": team member, date (not future, not before the case), one of four channel codes; actor and time by the server; no free text; audited; idempotent | met | 0061 `public.record_gp_informed` (channel list, `future`, `before_case`, `not_team`, `begin_command` → `duplicate`); table `case_gp_notices` append-only (guard trigger, no insert grant), audit trigger; pgTAP 063: channel "fax" and null date refused, coach and non-member `rejected`, other organisation `rejected`, future `rejected`, before case `rejected` (no record, no audit row), between case and task creation `ok`, replay `duplicate`, columns without free text |
| ORD0-2 closes the task (`done`, `done_by`, date); nothing else but a case close; `complete_case_task('inform_gp')` stays refused | met, with deviation 1 (Q12) | same function updates `case_tasks`; pgTAP 063 "the task is done, with done_by", "stays refused", "planning and PLAN2 do not reopen the task" |
| ORD0-3 shown on the team's case view ("informiert am <Datum> (<Kanal>)"), one-tap action while open; HAND1 entry | met; HAND1 SQL entry untested (condition ORD0-C1) | `team-client.tsx`; e2e `doctor.spec.ts` (A visit without order → task → one step → "Hausärztin/Hausarzt informiert am … (Telefon)", task gone, no overflow at phone width); HAND1: 0061 patches `private.handover_entries` (`gp_informed`), `handover/rules.ts` entry title and line; unit `gp-rules.test.ts` renders it. No pgTAP asserts that `handover_entries` returns the row |
| ORD0-4 P3 "Verordnung ohne Enddatum" on `/team` and OPS1; not closable by hand; ends with an end date, order no longer `present`, or no active B item; intake still accepts | met; the "order no longer `present`" ending untested (condition ORD0-C1) | `private.order_without_end_date_holds` (lifecycle `active`, team, `present`, `valid_until` null, active B item); rule row P3, no threshold; pgTAP 063: A/C only none, C item none, B + present → exception, `/team` and OPS1 show it, hand close refused, other organisation none, end date → gone, no active B item → gone |
| ORD0-5 pgTAP (the `cra` case set) | met | pgTAP 063, 53 assertions, every case of the brief's list present |
| ORD0-6 AN2 measure 10 with `order_without_end_date`; 7-day `inform_gp` share per team as evidence | met | 0061 patch of `pilot_hypotheses` (`order_open_end_ending`, `inform_gp_done_within_7d_share`); pgTAP 063 "two episodes, ended by the end date and by the retired B item", "measure 10 has five ending rows and the 7-day share"; `analytics/hypotheses.ts` + unit test |
| Test-expectation changes (019, 059, 061) | checked, no assertion weakened | rule counts 18 → 19, measure count 37 → 39; same assertions |

**Deviations (decided by the PO):**
1. *Planning and PLAN2 no longer reopen `inform_gp` once a record exists (CR-069)* — **accepted; Q12 decided (a)** (`OPEN_DECISIONS.md`): never again within the same case for the pilot. Without it every `/team` load reopened the task, which is exactly the "task teams learn to ignore" that CGR-36 named. Whether a reassessment result must also be sent (deadline, content) stays D-22; the PO added it to the D-22 package as question 6, and (b) is revisited with that answer.
2. *A record is refused for a closed case (`case_closed`)* — **accepted**: a case close already closes the task; a record after closing would document nothing the team can act on.
3. *No open task → `unchanged`, nothing written* — **accepted with deviation 1**: the record exists to close the task; a second "informed" record without a task is ORD1's job (sending, not recording).
4. *"Running" = lifecycle `active`* — **accepted**: a paused case plans no B visit.

**Condition ORD0-C1 (before acceptance, small, in the next PR that touches pgTAP 063):** two assertions in pgTAP 063: (a) `private.handover_entries` returns one `gp_informed` entry (date, channel, member code, no free text) for the team after a record; (b) setting the order to a status other than `present` ends the exception (the third ending in ORD0-4). Both are met in code; they are tested so the next migration that patches these readers cannot drop them unnoticed.

**Business and care value.** The doctor link is now a fact the team sees and records in one step, without a coordinator; an open-ended order on B care is visible to the team instead of silently generating visits. Measured by ORD0-6 (7-day share; how the exception ends). Architecture: commands and derived exceptions in the existing readers, no new subsystem (Handbook: one exception surface, audited commands).

## PO review — 2026-10-24 15:10: clinical gate passed, **`changes-requested`** (ORD0-C1 open; ORD0-C2 added for CGR-44)

**Clinical review gate passed.** The `cra` section 2026-10-24 14:27 (open PR #294, read on its branch, afef2cc) reviews 0061 and pgTAP 063: **no blocking finding**; CGR-36, CGR-38 and CGR-40 closed; BL-16 mitigated; one new advisory finding, CGR-44 (S2), on Q12 (a). `cra` supports ORD0-C1 and adds nothing to it. **The PO did not run the tests.** CI unchanged since 13:15 (green on head 4f938f6 and `recovery/main` f35d60e).

| Criterion | Result | Evidence |
|---|---|---|
| ORD0-1 to ORD0-6 | met (13:15 table above, unchanged) | 0061, pgTAP 063, e2e `doctor.spec.ts`; `cra` 14:27 CGR-36 evidence row (pgTAP 063 lines 63-158) |
| Clinical review gate | passed | `cra` 14:27: "the PO may accept with ORD0-C1 and a decision on CGR-44" |
| ORD0-C1 (two pgTAP assertions: HAND1 `gp_informed` entry; exception ends when the order is no longer `present`) | **not met** | no PR has touched pgTAP 063 since #284 (`git log` on `supabase/tests/database/063_*`; #295 does not touch it) |
| CGR-44 (Q12 (a): a case never asks again after a later A/C change) | decided: Q12 changes to (c) → ORD0-C2 | 0061:183, 190 (`not exists … case_gp_notices` per case), 0061:159 (`no_open_task` → `unchanged`) |

**Why `changes-requested`, not `accepted`.** ORD0-C1 was set at 13:15 as a condition *before* acceptance and is still open. CGR-44 makes deviation 1 (Q12 (a)) a continuity gap: a client whose A/C care grows months later is never prompted again. `lca` 15:05 (D-22) finds Q12 (a) not shown to be compliant and option (c) a better fit with the tarifsuisse contract (Art. 9 Abs. 1: a lasting change of needs requires a new needs assessment). The PO's 13:15 reason against reopening (a task reopened on every `/team` load is ignored) does not apply to (c), which reopens on an event, once.

**Q12 changed to (c) (PO, product authority; no deadline or content invented; D-22 question 6 stays open).** Deviation 1 is replaced by:

**ORD0-C2 (with ORD0-C1, in one PR, next after SIG2 #295):**
- (a) When a care-plan item of category A or C becomes active in a case whose medical order is not `present`, and no "Hausärztin/Hausarzt informiert" record exists with a date on or after the day that item became active, **one** `inform_gp` task opens for the case. A plan refresh, PLAN2 run or `/team` load never opens a second one while one is open, and never reopens it for an item already covered by a record.
- (b) `record_gp_informed` then closes that task (ORD0-1/ORD0-2 unchanged); with no open task it still returns `unchanged`.
- (c) A new B item with an order `present` opens no task; a case close closes the task (unchanged).
- (d) pgTAP: record, then a new active C item → one new task; a second refresh → still one; a record → `done`; a new B item with order `present` → no task; a new A item with an earlier record dated after its activation → no task.
- (e) HAND1 shows the reopened task like the first one; AN2 measure 10's 7-day share counts each task episode.
- The deadline, the content of the information and whether a reassessment result must be sent remain D-22 question 6 (legal adviser, Clinical Owner).

**Deviations 2-4** (13:15) stay accepted. **Result: `changes-requested`** (ORD0-C1, ORD0-C2). Acceptance follows when both are merged with green CI; no further `cra` gate is needed for these two unless `cra` finds a new hazard in them. Issue #292 stays open for that review.
