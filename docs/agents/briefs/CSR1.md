---
id: CSR1
title: Clinical safety remediation
author: po
status: approved
updated: 2026-10-23
---

# CSR1: Clinical safety remediation (Clinical Governance Report, 2026-10-22 22:30)

## Problem
The first Clinical Governance Report (`reports/CLINICAL_GOVERNANCE.md`, 22:30) found blocking safety gaps in capabilities the PO had already accepted. The PO spot-checked two of them against the code and confirmed them:
- CGR-01: `record_observation` in migration 0009 does not check the author of the superseded version.
- CGR-12: the registered-nurse check in migration 0024 applies only to `planned`/`on_the_way` → `started`.

Each of these gaps lets a visit look safe when it is not, or lets a signed record change after signature:
- a visit that never started;
- a care assistant completing a registered-nurse visit;
- a colleague rewriting another nurse's observation;
- a report signed over facts the nurse never saw;
- a bill computed from times changed after signature.

Under the clinical review gate (README; D-27), these items are no longer accepted. The PO set them to `changes-requested`: F1-F4, F6, F7, J3, J5, OPS1 and C1. CSR1 is the one item that carries their remedies.

## Users and journey step
Nurses and teams (Visit, Documentation), operations (exceptions), and billing preparation (J5). Journey steps: Visit → Documentation → Quality → Billing.

## Outcome
No visit looks covered, started or documented when it is not. A signed report is exactly what the nurse saw, and billing reads only what was signed.

## Acceptance criteria
Order of work: patient safety first.
- [x] **CGR-12 (J3, C1): the qualification rule holds for the whole visit.** For category B or needs-assessment visits, the registered-nurse check applies to **every** transition into `started` (including resume from `paused`) and into `completed`. pgTAP: a care assistant cannot resume or complete such a visit (`NV001`), and a registered nurse can.
- [x] **CGR-04 (OPS1, C1): a visit that did not happen stays visible.** Two new exception types:
  - a planned visit whose start time has passed without a start;
  - a visit left `on_the_way`, `started` or `paused`.

  Both stay open until a person resolves them, even after the planned start has passed. Thresholds are a `clinical` decision (D-28). Until it is answered, engineering uses a strict provisional default, listed as `PROVISIONAL` in `clinical/CLINICAL_RULE_REGISTER.md`. The provisional default is safer to raise early than late. pgTAP for both types, including that the existing "uncovered" exception no longer simply disappears at start time.
  - **Added 2026-10-23 00:10 (ADM1 pre-review):** the overdue exception does not depend on who is responsible. A missed planned visit whose responsible person is no longer a member of the visit's team (removed under ADM1, or with no responsible person) is raised the same way, is visible to every member of the team, and says "zuständige Person nicht mehr im Team" or "niemand zuständig". pgTAP: remove a member who has a planned visit dated yesterday → an overdue exception for that visit is returned to another member of the team.
- [x] **CGR-05 (OPS1, QG1): a serious quality event stays escalated until closed.** The exception stays while the event is `in_review`, and escalation continues. pgTAP.
- [x] **CGR-06 (OPS1): P1 safety exceptions cannot be silenced while their cause persists.** A P1 exception either re-opens while the cause persists or cannot be closed until the cause is resolved (engineering chooses; ADR). That includes `no_show_open` without a recorded outcome. pgTAP.
- [ ] **CGR-20 (OPS1, C1; blocking S1, added 2026-10-23 07:10): a broken-off visit has an honest end.** Today a `started` or `paused` visit can only become `completed`, and since 0039 its `visit_stuck` alert cannot be closed, so a visit that really stopped (client taken to hospital, nurse called away, started by mistake) ends either as a permanent P1 or as a false completion. Change:
  - a new audited, idempotent command ends a `started` or `paused` visit as **not completed** (status name engineering's choice, e.g. `interrupted`; ADR), with a mandatory reason from a list (client transferred or taken to hospital, client declined to continue, nurse called away or unwell, started by mistake, other with a note) and the actor;
  - allowed for the performer, any member of the visit's team (an absent or removed performer must not leave it stuck, ABS1), or a coordination role; whatever her qualification, because it records that care stopped, not care given. Who may finally record it is part of D-31;
  - it ends `visit_stuck` through its cause (no hand close); it produces **no billable fact** (J5), no F6 report obligation, no `report_not_final`, and does not count as a completed visit in AN1 or J6, until D-31 is answered;
  - the visit stays visible to its team as "nicht abgeschlossen · <Grund>" on `/field` and in HAND1's "Seit deinem letzten Einsatz"; already recorded observations stay unchanged;
  - `/field` offers it next to "Abschliessen" on a started or paused visit, so the only button on a stuck visit is never "complete".

  pgTAP: started → not completed with reason → no `visit_stuck`, no billable fact, audit row present; paused → not completed, same; a care assistant who performs a B visit can record it; another team member can record it; someone outside the team or organisation cannot; without a reason → refused; a not-completed visit cannot be completed or restarted. e2e at phone width: the action on a started visit. Rule register: one `PROVISIONAL` row referring to D-31.
- [ ] **CGR-22 (OPS1, advisory, strict provisional default 2026-10-23 07:10):** the hand close of `visit_uncovered` is refused (`cause_persists`) while the visit is planned and nobody is responsible; it ends by assigning someone or cancelling the visit. pgTAP for both endings and the refused close. The priority of uncovered visits stays with D-28 (`clinical`). May ride a later CSR1 PR; OPS1 does not wait for it.
- [x] **CGR-01 (F1-F4): only the author supersedes her observation.** A colleague's supersede is `rejected`. A colleague adds her own observation instead. pgTAP.
- [x] **CGR-02 (F6, F7): she signs what she saw.** The sign command carries the version or hash of the snapshot shown. It is rejected (`facts_changed`, and the screen reloads the snapshot) when observations or times changed since. pgTAP + e2e. *(Met by part 4, #175, migration 0041, PO 2026-10-23 09:10; evidence in `F7.md`.)*
- [ ] **CGR-03 (F3, F6, J5): signed means fixed.** After a report is `final`, time corrections and observations are refused, or go only through the F6 correction-version path. J5 billing facts take minutes from the signed snapshot, never from live times. pgTAP for both. *(F3/F4 part met by part 3, #171, migration 0040, PO 2026-10-23 08:20; the J5 part is open.)*
- [ ] **CGR-07 (J5): no bill on a missing, expired or unmodelled basis.** Three new not-billable reasons:
  - `order_validity_missing`: an order without an end date;
  - `order_expired`: this also applies to A and C minutes;
  - `payer_not_modelled`: any case that is not KVG.

  pgTAP. This adds no tariff rule: it refuses to estimate where the rule is not modelled.
- [ ] **CGR-08 (J5, advisory, accepted as a condition):** canton-sourced rates and minimums are marked as unvalidated in the data, and the J5 preview shows "nicht validiert". Re-seeding waits for D-11 and D-18.
- [ ] **CGR-13 (QG1, advisory, accepted as a condition):** until `clinical` answers D-16, the UI labels a hold "Abrechnungssperre" (billing hold), so nobody reads it as a care stop.
- [ ] **BL-8 (J5, advisory, accepted as a condition 2026-10-23 01:10):** a billing fact never stays billable under a later hold. When a quality hold opens on a visit that already has a billable fact, the fact is superseded by a not-billable fact with reason `quality_hold` (or an equivalent derived flag; engineering chooses, ADR); lifting the hold produces a new billable fact. The J5 preview and AN1 "billable minutes per care minute" read the same rule. pgTAP: fact → hold → not billable; lift → billable again; history kept.
- [ ] **BL-9 (J5, AN1, advisory, accepted as a condition 2026-10-23 01:10):** working-time facts follow the signed truth. When a report correction version (F6 path, CGR-03) supersedes a billing fact, the working-time fact of that visit is replaced from the same corrected snapshot, with a link to the old values; never updated silently. pgTAP: correction version with changed times → working-time fact shows the corrected minutes and references the earlier ones.
- [ ] **CGR-19 (F6, advisory, interim safe default 2026-10-23 03:10):** `correct_report` is refused with a clear reason (for example `performer_not_in_team`) while the report's performer is not a member of the visit's team, instead of creating a correction draft that nobody can ever sign. The current final version stays in force and readable. The rule for who may correct and sign in that case is D-30 (`clinical`, with `legal`); this criterion is replaced when D-30 is answered. pgTAP: performer removed → correction refused, no draft row; performer still a member → correction allowed as today.
- [ ] **No regression:** all existing pgTAP, unit and e2e tests stay green. The Clinical Rule Register lists every provisional default CSR1 introduces.
- [ ] **Clinical gate trail:** each PR names the report section it addresses and the CGR IDs it closes (README *Clinical review gate*).

Build order: the two BL conditions come after every blocking criterion above; they may ship in a later CSR1 PR. J5 is re-accepted only with them; the other reopened items do not wait for them.

Progress (PO, 2026-10-23 06:10): CGR-12 and CGR-04 met by part 1 (#161, migration 0038); evidence tables in `C1.md` and `J3.md`.
Progress (PO, 2026-10-23 07:10): CGR-05 and CGR-06 met by part 2 (#165, migration 0039); evidence in `OPS1.md`. C1, J3 and ADM1 accepted after the `cra` section 06:30. **Next part: CGR-20** (blocking for OPS1), after the part engineering already has in progress (F1-F4, CGR-01, if started); then F6/F7, J5.
Progress (PO, 2026-10-23 08:20): CGR-01 and the F3/F4 part of CGR-03 met by part 3 (#171, migration 0040); evidence in `F1-F4.md`. F1-F4 is accepted after a `cra` section on 0040 without a blocking finding. Condition for the CGR-02 PR: pgTAP that a time corrected in a correction draft reaches the signed correction version. **Next part: CGR-20** (blocks OPS1), then F6/F7 (CGR-02, CGR-19), J5.

Progress (PO, 2026-10-23 09:10): CGR-02 met by part 4 (#175, migration 0041), including the 08:20 condition; evidence in `F7.md`. F7 is accepted after a `cra` section on 0041 without a blocking finding. **Order of the remaining parts (PO decision):** 1. **CGR-20** (an honest *not completed* end; blocks OPS1 and is needed by ABS1), 2. J5 (CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9), 3. CGR-19 (F6), with CGR-22 in any part. CGR-20 goes before J5 because it keeps the care record truthful today, while J5's billing gaps cannot cause a real invoice before D-12 and D-18. The watcher currently labels J5 (#148) `active` (see the 09:10 journal entry); engineering builds CGR-20 first and may deliver it under #149 or #148.

## Out of scope
- Defining clinical thresholds, escalation chains or what a quality hold stops. Those are `clinical` decisions (D-28, D-16).
- Tariff rules (D-18), order forms (D-22), and qualification verification (CGR-16, D-29).
- ADM1 findings CGR-09 and CGR-10 (they stay in #135) and ABS1 findings CGR-11 and CGR-15 (they are in the ABS1 brief).

## Constraints and references
- `reports/CLINICAL_GOVERNANCE.md` (2026-10-22 22:30), `clinical/HAZARD_LOG.md`, `clinical/CLINICAL_RULE_REGISTER.md`, `clinical/SAFETY_RISK_REGISTER.md`.
- Decisions: D-27 (the Architect recommends; a named human clinical owner approves), D-28 (exception thresholds), D-16.
- No new clinical rule is invented: where a threshold is needed, CSR1 ships a strict, labelled provisional default.

## Delivery
Engineering may deliver CSR1 in one PR or in several, and decides how. Each reopened item goes back to `delivered` when its CGR findings are merged with green CI. The PO then re-accepts it against this brief and the latest Clinical Governance Report.

## Open questions for engineering
- Is a persistent "visit overdue" exception cheaper as a derived view over `visits` and `now()` (no job), like the existing uncovered exception?
- Can the snapshot hash for CGR-02 reuse the F6 snapshot builder, so sign and display share one function?

## Findings considered (PO, 2026-10-22 23:00)

The PO did not run tests. "Confirmed" means the PO read the cited code and found the gap as described.

| Finding | Item | Severity | PO decision |
|---|---|---|---|
| CGR-01 | F1-F4 | blocking | confirmed (0009: supersede has no author check); CSR1 |
| CGR-02 | F6, F7 | blocking | considered; CSR1 |
| CGR-03 | F3, F6, J5 | blocking | considered; CSR1 |
| CGR-04 | OPS1, C1 | blocking | considered; CSR1, thresholds D-28 (`clinical`) |
| CGR-05 | OPS1, QG1 | blocking | considered; CSR1 |
| CGR-06 | OPS1 | blocking | considered; CSR1 |
| CGR-07 | J5 | blocking | considered; CSR1 |
| CGR-08 | J5 | advisory | accepted as a condition; CSR1 |
| CGR-09, CGR-10 | ADM1 (#135) | blocking | changes on #135 (`briefs/ADM1.md`) |
| CGR-11, CGR-15 | F0, ABS1 | blocking for ABS1 | ABS1 brief amended |
| CGR-12 | J3, C1 | blocking | confirmed (0024: check only on the first start); CSR1 |
| CGR-13 | QG1 | advisory now | condition on QG1; UI label in CSR1; D-16 |
| CGR-14 | protocol | blocking for #136 | resolved in #136 (merged): `cra` is a reviewer without decision rights; `clinical` is the named human; one report path |
| CGR-16 | F0, ADM1 | advisory now, blocking before real data | D-29 (`owner`) |
| BL-8 | J5 | advisory (S2), recommended as a condition in the 23:05 section | **added 2026-10-23 01:10** as a CSR1 condition; confirmed by PO reading 0023: the preview filters `visit_has_open_hold`, but the fact itself stays `billable`, so any later reader of `billable_facts` (insurer invoices after D-12/D-18) would bill a held visit |
| BL-9 | J5, AN1 | advisory (S2), recommended as a condition in the 23:05 section | **added 2026-10-23 01:10** as a CSR1 condition; confirmed by PO reading 0023: `working_time_facts` insert `on conflict (visit_id) do nothing`, so a corrected visit keeps its first times. Working-time facts are the base for the North Star and fair pay (D-23, J7) |
| CGR-18 | ADM1 (merged) | blocking (S1), section 02:28 | confirmed (0036 checks the responsible person only; 0016 lets only the performer draft and sign); **ADM1 changes-requested 2026-10-23 03:10**, one small PR (`briefs/ADM1.md`); not part of CSR1, but may ride as the first commit of CSR1's first PR. ABS1: absence never refused, see `briefs/ABS1.md` |
| CGR-20 | OPS1, C1 | blocking (S1) for OPS1, section 06:30 | confirmed (0038:38-45 allows `started`/`paused` → `completed` only; 0024:353 `cancel_visit` only before start); criterion added 2026-10-23 07:10; documentation and billing rule to **D-31** (`clinical`, with `legal`) |
| CGR-21 | C1, COVER1 | advisory (S2), dormant while cover is off | condition of the COVER1 delta review after D-3: overdue and stuck alerts of a covered visit reach the covering nurse and her team, and the detail does not imply that someone is on the way |
| CGR-22 | OPS1 | advisory (S2) | strict provisional default added as a CSR1 criterion 2026-10-23 07:10; question added to D-28 |
| CGR-23 | C1 | advisory (S3) | pilot measure (AN1): visits with more than two pause/resume cycles or open longer than planned plus the P1 threshold, reviewed by the team; threshold change waits for D-28 |
| CGR-19 | F6 | advisory (S2), section 02:28 | confirmed (0016 `correct_report` copies `r.performer_id`; `sign_report` requires the performer); interim refusal added to CSR1 2026-10-23 03:10; rule to D-30 (`clinical`, with `legal`) |

The report found no blocking finding for HAND1, RET1, AN1, PLAN2, J6, J1, J2 or COVER1 (switched off). Their acceptances stand; its advisory risks are tracked in `clinical/SAFETY_RISK_REGISTER.md`.
