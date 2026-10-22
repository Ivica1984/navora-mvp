---
id: CSR1
title: Clinical safety remediation
author: po
status: approved
updated: 2026-10-22
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
- [ ] **CGR-12 (J3, C1): the qualification rule holds for the whole visit.** For category B or needs-assessment visits, the registered-nurse check applies to **every** transition into `started` (including resume from `paused`) and into `completed`. pgTAP: a care assistant cannot resume or complete such a visit (`NV001`), and a registered nurse can.
- [ ] **CGR-04 (OPS1, C1): a visit that did not happen stays visible.** Two new exception types:
  - a planned visit whose start time has passed without a start;
  - a visit left `on_the_way`, `started` or `paused`.

  Both stay open until a person resolves them, even after the planned start has passed. Thresholds are a `clinical` decision (D-28). Until it is answered, engineering uses a strict provisional default, listed as `PROVISIONAL` in `clinical/CLINICAL_RULE_REGISTER.md`. The provisional default is safer to raise early than late. pgTAP for both types, including that the existing "uncovered" exception no longer simply disappears at start time.
  - **Added 2026-10-23 00:10 (ADM1 pre-review):** the overdue exception does not depend on who is responsible. A missed planned visit whose responsible person is no longer a member of the visit's team (removed under ADM1, or with no responsible person) is raised the same way, is visible to every member of the team, and says "zuständige Person nicht mehr im Team" or "niemand zuständig". pgTAP: remove a member who has a planned visit dated yesterday → an overdue exception for that visit is returned to another member of the team.
- [ ] **CGR-05 (OPS1, QG1): a serious quality event stays escalated until closed.** The exception stays while the event is `in_review`, and escalation continues. pgTAP.
- [ ] **CGR-06 (OPS1): P1 safety exceptions cannot be silenced while their cause persists.** A P1 exception either re-opens while the cause persists or cannot be closed until the cause is resolved (engineering chooses; ADR). That includes `no_show_open` without a recorded outcome. pgTAP.
- [ ] **CGR-01 (F1-F4): only the author supersedes her observation.** A colleague's supersede is `rejected`. A colleague adds her own observation instead. pgTAP.
- [ ] **CGR-02 (F6, F7): she signs what she saw.** The sign command carries the version or hash of the snapshot shown. It is rejected (`facts_changed`, and the screen reloads the snapshot) when observations or times changed since. pgTAP + e2e.
- [ ] **CGR-03 (F3, F6, J5): signed means fixed.** After a report is `final`, time corrections and observations are refused, or go only through the F6 correction-version path. J5 billing facts take minutes from the signed snapshot, never from live times. pgTAP for both.
- [ ] **CGR-07 (J5): no bill on a missing, expired or unmodelled basis.** Three new not-billable reasons:
  - `order_validity_missing`: an order without an end date;
  - `order_expired`: this also applies to A and C minutes;
  - `payer_not_modelled`: any case that is not KVG.

  pgTAP. This adds no tariff rule: it refuses to estimate where the rule is not modelled.
- [ ] **CGR-08 (J5, advisory, accepted as a condition):** canton-sourced rates and minimums are marked as unvalidated in the data, and the J5 preview shows "nicht validiert". Re-seeding waits for D-11 and D-18.
- [ ] **CGR-13 (QG1, advisory, accepted as a condition):** until `clinical` answers D-16, the UI labels a hold "Abrechnungssperre" (billing hold), so nobody reads it as a care stop.
- [ ] **No regression:** all existing pgTAP, unit and e2e tests stay green. The Clinical Rule Register lists every provisional default CSR1 introduces.
- [ ] **Clinical gate trail:** each PR names the report section it addresses and the CGR IDs it closes (README *Clinical review gate*).

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

The report found no blocking finding for HAND1, RET1, AN1, PLAN2, J6, J1, J2 or COVER1 (switched off). Their acceptances stand; its advisory risks are tracked in `clinical/SAFETY_RISK_REGISTER.md`.
