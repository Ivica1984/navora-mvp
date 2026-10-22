# Clinical Governance Report

**Author:** Clinical & Regulatory Architect (review role; an AI agent, not a licensed clinician) · **Approves clinical rules:** a named, qualified person (D-27) · **Protocol:** `README.md` *Clinical review gate*
**Registers:**
- [Hazard Log](../clinical/HAZARD_LOG.md)
- [Clinical Rule Register](../clinical/CLINICAL_RULE_REGISTER.md)
- [Safety Risk Register](../clinical/SAFETY_RISK_REGISTER.md)

**Editable copy:** NAVORA Clinical Governance Baseline Report (Claude Docs). That copy holds the full narrative; this file holds the binding gate findings.

The newest dated section is the latest report. Earlier sections are never edited; a finding changes status only through a later section.

**Severity:**
- `blocking`: the item is not accepted. The PO sets `changes-requested`, or opens a decision for the owner named in the finding.
- `advisory`: may be accepted as a condition, with the reason recorded.

---

## 2026-10-22 22:30: baseline review and first gate

**Scope:** `recovery/main` @ `b546299`, plus open PRs #135 (ADM1 changes), #136 and #138 (role and gate), and #137 (PO cycle). I read migrations 0001–0036, `src/features`, pgTAP and e2e tests, all briefs, `OPEN_DECISIONS.md`, `NEXT_CAPABILITY.md`, `JOURNAL.md`, the engineering registers, the ops reports and the product documents.

**Not done:**
- I did not run the tests. CI results are taken as reported in the PRs.
- The live database and hosting were not accessed.
- The *Architecture Handbook* is not in the repository: **UNKNOWN**.

**Overall: not ready for real clients, real health data or invoicing.**
- The engineering foundation is strong: append-only events, immutable signed reports, audited commands, scoped access rules.
- No clinical rule has qualified approval (Clinical Rule Register: 0 of 34 approved).
- No clinical or legal person is named (G-1).
- Ten S1 safety gaps are in shipped code.

No LTCF, PAG or MQI logic exists in the code, which is correct.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-01 | F1-F4 | blocking | Any team member can supersede a colleague's observation. The new version carries the editor as author, and read models show only the latest version. | `record_observation` 0009:104-111 (no `prev.author_id = uid`) | Reject superseding unless the caller wrote the previous version. pgTAP: a colleague's supersede is `rejected`. |
| CGR-02 | F6, F7 | blocking | Signing rebuilds the snapshot at the moment of signing, so a colleague's later observation or time correction is signed unseen. | `sign_report` 0016:269; `report-section.tsx:183` | The sign command carries the version or hash of the snapshot shown, and is rejected when the facts have changed since. pgTAP + e2e. |
| CGR-03 | F3, F6, J5 | blocking | Time corrections and observations are accepted after the report is `final`. Billing reads the live, corrected times instead of the signed snapshot. | `correct_visit_time` 0008:73-130 (no report check); 0009:100; 0023:28-50, 89 | After `final`, changes go only through a correction version of the report (F6 path) or are refused. Billing facts take minutes from the signed snapshot. pgTAP for both. |
| CGR-04 | OPS1, C1 | blocking | A planned visit whose start passes without a start, or a visit left `started` or `paused`, raises no exception. The "uncovered" exception looks only ahead of `now()` and disappears at start time. | exception lists 0019:34-47 and 0024:443-447; 0024:491-492 | New exception types that persist until a person resolves them. Thresholds are set by `clinical`; until then, a strict provisional default listed as `PROVISIONAL` in the rule register. pgTAP. |
| CGR-05 | OPS1, QG1 | blocking | A serious quality event leaves OPS1 as soon as it is set to `in_review`. The escalation clock starts at `created_at`. | 0019:199-202, 252-253; 0024:513-516 | The exception stays until the event is `closed`; escalation continues in `in_review`. pgTAP. |
| CGR-06 | OPS1 | blocking | Closing an exception with any reason closes it permanently for that cause, including P1 `no_show_open` with no recorded outcome. | 0019:270 (`closed exceptions stay closed for this cause`) | A P1 safety exception re-opens while its cause persists, or cannot be closed until the cause is resolved. pgTAP. |
| CGR-07 | J5 | blocking | Billing has three gaps:<br>• An order `present` with no end date is valid forever.<br>• An expired order does not affect A/C minutes.<br>• Every case is priced at KVG insurer rates whatever its insurance type. | 0023:114, 117; 0023:221-224 | Add three not-billable reasons: `order_validity_missing`, `order_expired`, and `payer_not_modelled` for non-KVG cases. pgTAP. |
| CGR-08 | J5 | advisory | Canton-sourced values are seeded as federal (`CH`): rates from a Graubünden publication, the minimum from a Basel-Stadt leaflet. The KLV citation differs from the brief, and the code reads the minimum differently from the brief. | 0022:52-60; 0023:124; `briefs/J5.md:63` | Mark these rows unvalidated in the data itself, so the preview shows it. Re-seed for the pilot canton once D-11 and D-18 are answered. |
| CGR-09 | ADM1 (#135) | blocking | Removal does not release her **suspended** visits. `resume_case` later reactivates them with a person who is no longer a team member as responsible, so they look covered. | `release_member_visits` 0036 (`x.suspended_at is null`); `resume_case` 0024:253 keeps `responsible_user_id` | Release suspended visits too, or have resume clear a responsible member who is not an eligible team member. pgTAP: remove → resume → the visit is uncovered. |
| CGR-10 | ADM1 (#135) | blocking | Removal while she has a visit `on_the_way`, `started` or `paused` deletes her membership. She can then no longer complete or document it, and no exception covers the stuck visit. | 0036 releases `planned` only; membership deleted unconditionally | Refuse removal while she has a visit in progress (new result `has_visit_in_progress`). pgTAP. |
| CGR-11 | F0 (#38), ABS1 | blocking for ABS1 | A qualification change from `registered_nurse` to `care_assistant` leaves her responsible for category B and needs-assessment visits she may no longer start. They look covered until the start fails. | `set_member_qualification` 0018:133-174 | `set_member_qualification` uses the same release rule for visits she is no longer eligible for. Test in ABS1's delivery at the latest. |
| CGR-12 | J3, C1 | blocking | The registered-nurse check applies only at the first start, so a care assistant can resume and complete a B or needs-assessment visit. | 0024:125 (`old.status in ('planned','on_the_way')`) | Apply the check to every transition into `started` and `completed` for those visits. pgTAP. |
| CGR-13 | QG1 | advisory now, blocking before real data | A hold blocks only billing. The visit can still be started, and planning, cover and matching ignore holds. | `visit_has_open_hold` used only in 0020, 0022, 0023 | `clinical` defines what a hold stops (D-16); engineering enforces it. Until then, label holds in the UI as "billing hold" so nobody reads them as a care stop. |
| CGR-14 | protocol (#136, #138) | blocking for #136 | #136 makes the Architect the owner of the `clinical` decisions. An AI reviewer must not be the deciding owner of clinical rules; D-27 itself recommends a named, qualified person. #136 and #138 also define different role names and report paths. | #136 README *Roles*; #138 `cra` role | Adopt #136's gate wording, which is the stronger one. Keep `clinical` as the named qualified person, and record the Architect as a reviewer (#138's `cra`, or `clinical (review)` without decision rights). One report path: this file. Answer D-27 with a named person. |
| CGR-15 | ABS1 (brief) | advisory on the brief, blocking at delivery | ABS1 claims "needs no open decision", but it decides who takes an absent nurse's visits. It must reuse one eligibility rule covering suspended, in-progress and qualification-restricted visits (CGR-09 to CGR-12), and released visits must stay alerted after their start time (CGR-04). | `briefs/ABS1.md`; `NEXT_CAPABILITY.md` | Add these acceptance criteria to the brief before engineering starts. |
| CGR-16 | F0, ADM1 | advisory now, blocking before real data | A qualification is a label set by an administrator, with no evidence of registration and no expiry. | grep: no GLN, NAREG or MedReg fields | Owner and `clinical` define the verification step. A qualification is active only after evidence is recorded. |

### Gate status per item

**Earlier acceptances.** Accepted items stand under the protocol; the findings above apply to them as blocking. The PO sets `changes-requested` on F1-F4, F6, F7, J3, J5, OPS1 and C1. These are bundled for engineering as one item, the **Clinical safety remediation (CSR1)**, ranked above ABS1.

| Item | Result | Findings |
|---|---|---|
| ADM1 changes (#135) | **not acceptable yet** | CGR-09 and CGR-10 blocking. Changes 1–4 and the removal of legacy unvalidated heuristics (CR-034) are endorsed. The PO's privacy fix (#137) is endorsed. |
| ABS1 | brief to amend before start | CGR-15 and CGR-11 |
| F1-F4 | changes-requested | CGR-01, CGR-03 |
| F6, F7 | changes-requested | CGR-02, CGR-03 |
| J5 | changes-requested | CGR-03, CGR-07; CGR-08 advisory |
| OPS1, C1 | changes-requested | CGR-04, CGR-05, CGR-06, CGR-12 |
| J3 | changes-requested | CGR-12 |
| QG1 | condition | CGR-13 |
| #136, #138 | reconcile | CGR-14 |
| HAND1, RET1, AN1, PLAN2, J6, J1, J2, COVER1 (off) | no blocking finding | advisory risks are in the Safety Risk Register (C-8, PS-9, PS-10, LT-3) |

### Decisions requested (no answer is assumed)

- **owner:**
  - D-27: name the qualified person who confirms clinical rules;
  - D-1: is the live data real?
  - D-11 and D-12.
- **clinical** (once named):
  - D-16 and D-17 first (escalation and safety alerts);
  - then D-19, D-15, D-10 and D-6;
  - plus the thresholds for CGR-04, and reassessment triggers.
- **legal:** D-18, D-22, D-9 and D-4.

**Next review:** the next scheduled governance cycle, or earlier when a PR in scope is opened.
