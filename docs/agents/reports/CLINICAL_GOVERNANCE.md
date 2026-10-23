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

## 2026-10-23 14:30: J5 signed billing, CSR1 part 7, ABS1 part 1 (0043-0046); open PR #200 (0047)

**Scope:** `recovery/main` @ `980cdd9`. Changes since the 10:29 section (merged with #184 as `845ae96`):
- **Code merged:** #183 (CSR1 part 6, J5: CGR-03 J5 part, CGR-07, CGR-08, BL-8, BL-9; migration 0043, pgTAP 043) as `896e943`; #188 (CSR1 part 7: CGR-19, CGR-22; migration 0044, pgTAP 044) as `e215924`; #192 (CSR1 part 7 completion: CGR-25; migration 0045, pgTAP 045) as `7e5013b`; #195 (ABS1 part 1: CGR-11, CGR-15; migration 0046, pgTAP 046, two-session take check) as `a626c30`.
- **Docs:** #185, #187, #189, #191, #193, #194, #196, #198 (PO and engineering cycles). J5, F6 and ABS1 part 1 wait for this section. PO conditions J5-C1 and ABS1-C1 to C3 opened; D-10, D-22, D-28 and D-31 sharpened; none answered.
- **Open PR in scope:** #200 (CSR1 part 8: CGR-24, CGR-26, CGR-13; migration 0047, pgTAP 047), head `023cc1e`. CI on its head: **UNKNOWN** (one run in progress on `61c7d76`, none on `023cc1e`); GitHub reports a merge conflict with `recovery/main`.

I read migrations 0043 to 0047 in full, pgTAP 043 to 047, the cover commands they interact with (0028, 0029), `generate_billable_facts` (0022) and the decision rows. **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `896e943`, `e215924` (one e2e run cancelled, a second passed), `7e5013b`, `a626c30` and `980cdd9`.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-27 | ABS1 (0046) | **blocking (S1)** | The release rule and every absence check compare the absence with the visit's **planned interval**, and that interval is wrong for two kinds of visit. A visit **without a start time** is 00:00-00:01; a visit **with a start time but no end time** is one minute long. So an absence starting at 12:00 does not release that day's untimed visit, and an absence starting at 08:30 does not release a visit planned 08:00 without an end. The visit stays with the absent nurse, does not appear in "Offen im Team", raises no `visit_uncovered`, and looks covered. Only `visit_overdue` catches it, after the start and with a PROVISIONAL threshold. The same interval decides whether the absent nurse may take a visit and whether a deputy is shown as "kennt die Klientin". This confirms the PO's ABS1-C1 and widens it to visits without an end time. IMPLEMENTED gap. | `private.visit_interval` 0046:90-98; release filter 0046:145; `member_absent_during` 0046:101-108, used in take 0046:351, "Offen im Team" 0046:397-398 and `known_by` 0046:407-411; pgTAP 046 uses timed visits only | A visit without a start time occupies its whole date (Europe/Zurich, 00:00 to 24:00). A visit with a start and no end occupies at least start + its planned minutes (A+B+C); with no planned minutes, to the end of its date. This is arithmetic, not a clinical rule. One interval function for release, take, "Offen im Team", `known_by` and `change_absence`. pgTAP: an absence from 12:00 releases that day's untimed visit; an absence from 08:30 releases a visit 08:00 without an end and with 60 planned minutes; the absent nurse cannot take either one. |
| CGR-28 | ABS1 with COVER1 (0046, 0029) | advisory (S2 if cover is enabled) | An absence releases only visits of **the absence's team** where she is the **responsible member**. A visit she accepted as a **cover** for another team has `covered_by` = her and no responsible member, so the absence does not touch it. It stays "covered": it is excluded from `visit_uncovered`, from new cover offers and from "Offen im Team". From 4 h before the start she cannot hand the cover back either (`too_late`). Only `visit_overdue` catches it. Cover is switched off by default (PS-12, D-3), so this is not blocking today. IMPLEMENTED gap. | release filter 0046:142 (`team_id` and `responsible_user_id`); `accept_cover` sets only `covered_by` 0029:186; `withdraw_cover` refuses within the fallback lead 0029:215-218; "Offen im Team" and take exclude covered visits 0046:388, 344 | Before D-3 enables cover: an absence also ends her covers in the period (as `withdraw_cover`, without the lead-time limit, with the fixed text "Abwesenheit"). The visit is then uncovered again for its own team and Operations. pgTAP: she accepts a cover → records an absence → `covered_by` is empty → `visit_uncovered` for the original team. |
| CGR-29 | J5 (0043) | advisory (S3) | When a quality hold is lifted, the trigger appends the fact that was in force **before** the hold again. If a report correction was signed and became final **during** the hold, no fact was built for it (`build_billable_fact` returns null while a hold is open). After the lift, the preview and AN1 therefore count the **older** signed snapshot as billable until someone runs the generation again. Nothing is invoiced today, so this is not blocking. IMPLEMENTED gap. | `build_billable_fact` returns null under an open hold 0043:166-169; lift appends the pre-hold fact 0043:295-308; `correct_report` has no hold check (0044:28-75); generation runs only on demand (0022:264-289); pgTAP 043:171-212 covers hold and lift without a correction in between | On the last lift, if the visit's latest final report version has no J5-v3 `report` fact, build it from that version (the same function) instead of restoring the old fact. pgTAP: v1 final → fact → hold → correction v2 final → lift → the head fact carries v2's `report_id` and snapshot hash. |
| CGR-30 | CSR1 part 8 (#200, 0047) | advisory (S3) | `report_correction_open` can be closed by hand in OPS1, like `report_not_final`. Its key is the correction's id, so one hand close hides it for good, from Operations and from the team (`team_visit_alerts` does not ignore a close for this type). The correction stays open, the visit's times and observations stay unlocked, and nothing signals it again. That is the CGR-24 hazard, now silenced by a person instead of by a missing signal. The close is attributable and audited. OPEN in the PR (ADR-058). | #200: 0047:17-18 (closable as `report_not_final`), pgTAP 047:24 (`exception_closes_with_cause` false); `team_visit_alerts` patch 0047:77-80 adds the type without the "an earlier close never hides it" clause used for `visit_interrupted` (0045:138-139) | Add `report_correction_open` to `private.exception_closes_with_cause` (as CGR-22 and CGR-25): it ends only when the correction is final. A correction that can never be signed (performer gone, D-30) then stays visible, which is correct. pgTAP: close → `cause_persists`; `closable` false; final → gone. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-03 | **closed** (J5 part now too) | `private.snapshot_times` reads the events of the signed snapshot (0043:66-92); `build_billable_fact` takes times and planned minutes per category only from the final version's snapshot and stores its hash (0043:172-178, 245); a correction version yields a new superseding fact (0043:228-231). pgTAP 043:86-110 (live times and live plan drift after signature; the fact keeps the signed 30 minutes and the snapshot hash), 043:224-247 (correction version → new fact with 45 minutes, superseding). Residual: CGR-24 (open correction, #200), CGR-29 |
| CGR-07 | **closed** (strict default, CR-046 PROVISIONAL; D-18, D-22) | `order_validity_missing`, `order_expired` (A and C too), `payer_not_modelled` for any insurance type other than KVG (0043:198-213). pgTAP 043:113-162. Whether A and C without an order are billable at all stays R-8 / D-22 (pgTAP 043:107 asserts they are; that is the existing PO rule, not a new one) |
| CGR-08 | **closed** | `validated` and `validation_note` on reference rows, seeded rows unvalidated (0043:33-49); fact warning `reference_not_validated` (0043:181, 220-226); preview `reference_validated` (0043:418-426). pgTAP 043:71-75, 108, 164-168, 249-256. Re-seeding waits for D-11 and D-18 (BL-1, BL-2) |
| BL-8, BL-9 | **mitigated-in-code** | BL-8: hold → not-billable fact, last lift → earlier fact again (0043:267-339; pgTAP 043:171-222); residual CGR-29. BL-9: one working-time fact per final version from its snapshot, superseding (0043:248-259; pgTAP 043:110, 242-247) |
| CGR-19 | **closed** (interim, D-30) | `correct_report` refuses `performer_not_in_team` and writes nothing (0044:59-64). pgTAP 044:143. Residual (OPEN, CR-048): a correction draft opened before she left stays open; #200's signal (CGR-24) makes it visible, subject to CGR-30 |
| CGR-22 | **closed** (interim, D-28) | hand close returns `cause_persists` (0044:85-90, 136-138); not closable and an earlier close no longer hides it (0044:165-170). pgTAP 044:71-80, 104-105 |
| CGR-25 | **closed** (interim, D-31) | `visit_interrupted` from the end until one follow-up decision (0045:93-123), not closable by hand (0045:62-67, 127-132), visible to the team and Operations (0045:135-140), audited, idempotent, one decision per visit (0045:49, 161-197); `client_transferred` names the next planned visit (0045:108-117). pgTAP 045:71-87, 105-107, 169. Residual (OPEN, D-31 (c)-(e)): "Folgeeinsatz geplant" is an unchecked statement |
| CGR-11 | **closed** | qualification change from registered nurse to care assistant releases her B and needs-assessment visits from today, not those in progress (0046:478-487, through 0046:125-158). pgTAP 046:321-331 |
| CGR-15 | **closed** | a released visit nobody takes keeps its overdue alert after its start (derivation unchanged). pgTAP 046:251-262 |
| CGR-24 | open (advisory); **remedy in #200** | 0047:58-73 (P3 after the `report_not_final` threshold, until final; signed-awaiting-countersignature counts as open), pgTAP 047:76-179. Closes when #200 is merged with green CI. The billing side was closed by 0043 (CGR-03). Residual CGR-30 |
| CGR-26 | open (advisory); **remedy in #200** | `field_visit_status_notes` returns who ended the visit as a label, no user id (0047:93-127); `/field` shows "Beendet von …". The weekly pilot measure is PLANNED (AN2). Correction of an erroneous end stays D-31 |
| CGR-13 | open (advisory); **wording remedy in #200** | UI label "Abrechnungssperre" with the sentence that the hold blocks billing only. What a hold stops clinically stays D-16 (PS-5) |
| CGR-16, CGR-21, CGR-23 | open, unchanged | no change in their code |

### Other changes reviewed (no finding)

- **ABS1 privacy:** `member_absences` has no reason and no free-text column; only the own team reads it; HAND1 shows a release as a fact without reason or member id (0046:48-72, 491-497). Endorsed (data minimisation).
- **Absence recorded by a colleague** (0046:184-240): allowed without the absent member's confirmation; she can withdraw it (0046:271-273) and her visits return if nobody took them. Acceptable. The PO may add to AN2 how many absences are recorded by a colleague and withdrawn by the member.
- **ABS1-C3** (an absence applies to every team of the member; PO decision 14:16): endorsed. A member of two teams who is absent in one still looks available in the other. Same class as CGR-27; part of the same part-2 test set.
- **PLAN2 with absence** uses the slot window, not `visit_interval`, so CGR-27 does not apply there (0046:462-471).
- **0043 A/C without an order billable** (`without_order_ac`): existing PO rule, unchanged; tracked as R-8 / D-22, `legal`.
- **J5-C1** (PO condition: re-derive the fact when the payer is corrected): endorsed as a billing-integrity condition; the strict default for order changes until D-22 is correct.
- **#200 stricter than asked:** a correction that is signed but awaits the countersignature keeps the signal (0047:12-15). Endorsed.
- **Rule register:** CR-045 to CR-052 (engineering) checked against the code; architect notes added. CR-053 to CR-055 come with #200 and are checked when it merges.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| J5 (#183 merged, `delivered`) | **no blocking finding**; the PO may accept, with CGR-29 and J5-C1 as conditions | CGR-03 (J5 part), CGR-07, CGR-08 closed; BL-8, BL-9 mitigated-in-code; CGR-29 advisory |
| F6 (#188 merged, `delivered`) | **no blocking finding**; the PO may accept, with CGR-24 as condition (remedy in #200) | CGR-19 closed (interim, D-30) |
| OPS1 (accepted) | conditions CGR-22 and CGR-25 **confirmed closed**; CGR-26 remaining (remedy in #200) | – |
| ABS1 part 1 (#195 merged, `delivered`) | **blocking: CGR-27.** Not accepted; the PO's `changes-requested` for part 2 stands and must include CGR-27 | CGR-11, CGR-15 closed; CGR-27 blocking; CGR-28 advisory (before cover is enabled) |
| CSR1 part 8 (#200, open) | **no blocking finding**; CI and the merge conflict are open | CGR-24, CGR-26, CGR-13 remedies present; CGR-30 advisory |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** add CGR-27 to ABS1 part 2 (with ABS1-C1); record CGR-28 as a condition on enabling cover (D-3); record CGR-29 as a J5 condition; decide CGR-30 on #200.
- **clinical** (once named): D-31 (including (c)-(e)), D-28, D-10, D-30, D-16, D-17.
- **legal:** D-18, D-22 (including J5-C1's order question); D-31 with `clinical`.

---

## 2026-10-23 10:29: CSR1 parts 3, 4 and 5 (0040, 0041, 0042)

**Scope:** `recovery/main` @ `50681da`. Changes since the 06:30 section (merged with #167 as `6fc517a`):
- **Code merged:** #171 (CSR1 part 3, F1-F4: CGR-01, CGR-03 F3/F4 part; migration 0040, pgTAP 040) as `bf37957`; #175 (CSR1 part 4, F7/F6: CGR-02; migration 0041, pgTAP 041; pgTAP 016, 019, 022, 026, 037, 038 adapted to the hashed sign) as `479701c`; #179 (CSR1 part 5, OPS1: CGR-20; migration 0042, pgTAP 042, `/field`, HAND1 label, CR-042) as `a78fa7e`.
- **Docs:** #169, #172, #174, #176, #178, #180, #182 (PO and engineering cycles): D-31 opened (CGR-20), CGR-22 added to D-28, countersigner return question added to D-10, CSR1 order (CGR-20, then J5, then CGR-19), WATCH-1, remediation plans CGR-02 and CGR-20.
- **Open PRs:** only #3 (`recovery/main` → `main`), out of scope for this review. No open PR in scope, so no PR comments this run.

I read migrations 0040, 0041 and 0042 in full, pgTAP 040, 041 and 042, the remediation plans, `report-commands.ts`, `report-section.tsx`, and the functions they interact with (0008, 0009, 0016, 0024, 0038, 0039). **I did not run the tests.** CI (checked through the API) is green for app, db (migrations, seed, pgTAP) and e2e on `bf37957`, `479701c` and `a78fa7e` (one e2e run on `a78fa7e` was cancelled and a second one passed). On `50681da` (docs only) app and db are green and e2e was still running.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-24 | F1-F4, F6 (0040) | advisory (S2) | Since 0040 a `signed` or `final` report locks the visit's times and observations, which is correct (CGR-03). The lock is lifted by `correct_report`, which **any team member** may call with a reason, and the correction draft then stays open **with no time limit and no signal**: `report_not_final` looks only for the absence of any `final` version, and the earlier final version still exists. While the draft is open, team members can change times and add observations, handover reads the changed live observations, and J5 still bills from the live times (CGR-03 J5 part, BL-3). A correction that is never signed (performer absent, or gone: CGR-19) therefore reopens the record silently and indefinitely. The changes stay attributable and audited, and nothing becomes signed unseen (0041), so this is not blocking. IMPLEMENTED gap. | `correct_report` 0016:343-349 (team member, no performer check); `private.visit_facts_locked` 0040:24-33 (latest version only); `report_not_final` 0024:519-527 (`not exists ... status = 'final'`); billable facts 0022:278 (any `final` version) | A correction draft older than the `report_not_final` threshold raises a P3 exception (type engineering's choice, e.g. `report_correction_open`) for the team and Operations until it is signed. Its threshold is a provisional default (`PROVISIONAL`, D-28). J5 takes minutes from the latest **final** snapshot, not the live facts, while a correction is open (the J5 part of CGR-03). pgTAP: final → correction draft opened → after the threshold the exception exists → signed → it ends. |
| CGR-25 | OPS1 (0042) | advisory (S2) | Ending a visit as *not completed* removes **every** signal about it: `visit_stuck` ends (correct), and nothing replaces it. Care that was due and not given (medication, wound care, a meal) is visible only passively, on `/field` and in HAND1 at the case's **next** visit. For `nurse_unavailable` (the nurse called away or unwell) the person who knows least about the follow-up may be the one recording it, and nobody else is told. For `client_transferred` the case's later visits stay planned (PO challenge 10:15). Before 0042 the P1 stuck alert at least forced a person to look. Whether a follow-up is required, by whom and at which priority is a clinical rule; it cannot be set here. UNKNOWN; owner `clinical` (D-31). | 0042:129-133 (status `interrupted`, no exception written); derived exceptions read only `on_the_way`, `started`, `paused` for `visit_stuck` (0038 §2); pgTAP 042 checks "no stuck or overdue exception" afterwards; remediation plan CGR-20 step 5 (visibility through `/field` and HAND1 only) | Strict provisional default until D-31: an `interrupted` visit raises an exception for the visit's team and Operations (type and priority engineering's choice, `PROVISIONAL`, e.g. P2 `visit_interrupted`, not escalating), closable by a person with a reason ("Folgeeinsatz geplant", "nicht mehr nötig"), with the reason code and note in its detail; for `client_transferred` the detail names the case's next planned visit. The PO adds the follow-up question to D-31. pgTAP: interrupted → exception visible to team and Operations → closed with a reason → gone. |
| CGR-26 | OPS1 (0042) | advisory (S3) | A coordinator outside the team can end any started or paused visit of the organisation as *not completed*, and the status is terminal. If that is done in error while the nurse is still on site, she can no longer complete the visit or add an observation, and care actually given is recorded as not given. The actor is recorded and audited, so the error is traceable, but it cannot be corrected. Who may record the end is already a D-31 question. | 0042:124-129 (`is_team_member` or `is_coordinator`), 0042:17-19 (no way out of `interrupted`); `record_observation` 0040:144 (no `interrupted`) | Until D-31: show the performer, on `/field`, who ended her visit and why; count coordinator-recorded interruptions of a visit in progress as a weekly pilot measure. If D-31 keeps the coordinator, it also says how an interruption recorded in error is corrected. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-01 | **closed** | `record_observation` refuses a supersede unless `prev.author_id = auth.uid()` (0040:154-163). pgTAP 040:83 (a colleague's supersede is `rejected`); 040:71-73 (the colleague adds her own observation); 040:63-67 (the author still supersedes her own). Only this command writes `visit_observations` (0009:50-61: select-only grants, update and delete refused) |
| CGR-02 | **closed** | `field_reports` shows a draft's live snapshot and its `snapshot_hash` (0041:60-77); `sign_report(report, hash, key)` refuses `facts_changed` and writes nothing when the current facts have another hash, and stores exactly the snapshot whose hash was sent (0041:114-124); the two-argument version is dropped (0041:84); the builder runs in UTC (0041:25). `/field` sends the hash and reloads after a refusal (`report-section.tsx`, `report-commands.ts:73-85, 120-135`). pgTAP 041:75-94 (a colleague's observation after display → `facts_changed`, still a draft), 041:99-115 (sign after reload), 041:119-130 (a corrected time reaches the signed correction version), 041:136 (time-zone independent), 041:148-154 (countersignature of the frozen version). The summary is not hashed; only the performer edits it (0016 `update_report_draft`), so no colleague's text is signed unseen |
| CGR-03 | **closed for F3, F4 and F6**; **open for J5** (billing from the signed snapshot) | `private.visit_facts_locked` true while the latest version is `signed` or `final` (0040:24-33); `correct_visit_time` and `record_observation` return `rejected` under the lock, serialised with the report row lock (0040:80-85, 148-152); `correct_report` reopens through a correction draft (0016:343-349). pgTAP 040:104-124 (after final: time correction, new and superseding observation refused, nothing written), 040:130-147 (correction draft reopens; the signed correction version carries the changes; version 1 unchanged; locked again), 040:158-162 (`signed` awaiting countersignature locks too). J5 still reads live times (0023:28-50); residual CGR-24 |
| CGR-20 | **closed** (interim rule PROVISIONAL, D-31) | terminal status `interrupted` only through `end_visit_not_completed` with a reason from a list, `other` with a note, actor and timeline event, audited, idempotent, row-locked (0042:99-135); a direct update to `interrupted` is refused (pgTAP 042:112-113); a care assistant ends a started B visit (042:130); `visit_stuck` ends without a hand close; no report draft, no billable or working-time fact, no `report_not_final`, no assessment marker (pgTAP 042, remediation plan *Tests*); `/field` and HAND1 show the reason (042:199-204). Residual CGR-25, CGR-26 |
| CGR-19 | open (advisory) | unchanged; next CSR1 part after J5 (PO 09:10) |
| CGR-22 | open (advisory) | not built yet; strict default is a CSR1 criterion (PO 07:10), question in D-28 |
| CGR-07, CGR-08 | open, unchanged | no change in 0022, 0023; J5's CSR1 part (#148) is next |
| CGR-11, CGR-13, CGR-15, CGR-16, CGR-21, CGR-23 | open, unchanged | no change in 0018, 0020, 0029, 0038 |

### Other changes reviewed (no finding)

- **`signed` locks too (0040, ADR-051):** stricter than the report asked. A countersigner who sees an error must countersign and then open a correction. The PO asked `clinical` in D-10 whether she may return the report instead. Endorsed as the strict default; nothing changes silently.
- **0042 is `security definer`** (ADR-053), not invoker as the brief recommended, so the state machine keeps refusing a direct update to `interrupted` and the reason cannot be skipped. Endorsed.
- **Observations after the end refused (0042):** the reason note (up to 1000 characters) carries what happened, and observations recorded during the visit stay. Acceptable until D-31. These observations are never signed, because no report exists for an interrupted visit; whether a report of the care already given is required is already a D-31 question.
- **Time corrections on an interrupted visit** stay possible (remediation plan, UNKNOWN): reasoned, audited, and no fact derives from them today. No finding; it must be re-checked if D-31 makes interrupted minutes billable.
- **Rule register:** CR-042 (engineering, 0042) checked against the code. CR-043 (0040) and CR-044 (0041) added by this review; CR-012 and CR-013 updated.
- **PO challenge (10:15):** after a hospital-transfer interruption, offer "Fall pausieren" in the same step. No safety objection: it only offers an existing, audited command, and the team chooses. It reduces the CGR-25 risk for that reason but does not replace the follow-up signal for the other reasons.
- **WATCH-1 (PO 09:10):** a coordination gap, not clinical. No finding.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| F1-F4 (#171 merged, `delivered`) | **no blocking finding**; the PO may accept | CGR-01 closed; CGR-03 closed for F3 and F4; CGR-24 advisory |
| F7 (#175 merged, `delivered`) | **no blocking finding**; the PO may accept | CGR-02 closed; CGR-03 closed for F6 sign and correction (0040) |
| F6 | **no blocking finding from this review**; D-10 (`clinical`) still blocks it in `OPEN_DECISIONS.md` | CGR-02 and CGR-03 closed for F6; CGR-19 and CGR-24 advisory |
| OPS1 (#179 merged, `delivered`) | **no blocking finding**; the PO may accept, recording CGR-22 and CGR-25 as conditions | CGR-20 closed (interim rule, D-31); CGR-22, CGR-25 advisory (S2); CGR-26 advisory (S3) |
| J5 | changes-requested (unchanged) | CGR-03 (J5 part), CGR-07 blocking; CGR-08, BL-8, BL-9 |
| ABS1 | approved, unstarted | CGR-11, CGR-15; the CGR-20 dependency is met |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** add to D-31: (a) after a visit is ended as not completed, must a follow-up be decided, by whom, by when and at which priority (CGR-25); (b) how an interruption recorded in error is corrected (CGR-26). Add to D-28: how long a report correction may stay unsigned before it is a signal (CGR-24).
- **clinical** (once named): D-31, D-28, D-10, D-30, D-16, D-17.
- **legal:** D-18, D-22; D-31 with `clinical`.

---

## 2026-10-23 06:30: ADM1 CGR-18 fix, CSR1 parts 1 and 2

**Scope:** `recovery/main` @ `8ec3351`, plus #165 at head `74f3acf`. #165 was merged during this run as `c987e83` (tree identical to `74f3acf`), and OPS1 was set `delivered` (#166). Changes since the 02:28 section (`0e90932`):
- **Code merged:** #153 (ADM1 CGR-18 fix, migration 0037, pgTAP 037) as `95ed737`; #161 (CSR1 part 1: CGR-12, CGR-04; migration 0038, pgTAP 038, `/team` alerts) as `74940fb`.
- **Code merged during this run:** #165 (CSR1 part 2, OPS1: CGR-05, CGR-06; migration 0039, pgTAP 039, `/operations`) as `c987e83`.
- **Docs:** #156, #158, #159, #162, #164 (PO and engineering cycles): D-30 opened (CGR-19); CSR1 criterion for CGR-19; ABS1 amended; C1 and J3 met by the PO, waiting for this review; ADM1 waiting for this review.
- #155 (this role's 02:28 section) was green but not merged. This PR carries it (merge commit) so the registers stay in one line of history.

I read migrations 0037, 0038 and 0039 in full, pgTAP 037, 038 and 039, and the functions they interact with (0003, 0007, 0016, 0024, 0028, 0029, 0035). **I did not run the tests.** CI shows app, db (migrations, seed, pgTAP) and e2e green on `95ed737`, `74940fb`, `8ec3351` (as reported in the journal) and on #165 head `74f3acf` (run 39900134825, checked).

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-20 | OPS1 (0039) with C1 (0038) | blocking (S1) for OPS1 acceptance | Since 0039 a `visit_stuck` exception can no longer be closed by hand, which is correct (CGR-06). But a visit that is `started` or `paused` has **no honest way to end except `completed`**. It cannot be cancelled or recorded as a no-show from those states. Pause and resume only restart the clock. So when a visit is really broken off (client taken to hospital during the visit, nurse called away, visit started by mistake), the team must either live with a permanent P1 on `/operations` and `/team`, or record the visit as `completed`. A false completion creates a report obligation for care not given, and its live start and end times feed measured minutes (BL-3, CGR-03). Before 0039 the coordinator closed the exception with a reason, so this pressure did not exist. How an interrupted visit is documented and billed is UNKNOWN; owner `clinical`, with `legal`. IMPLEMENTED gap in the state machine, made acute by 0039. | transitions for app users 0038:38-45 (from `started`/`paused` only to `paused`, `started`, `completed`); `cancel_visit` 0024:353 (`planned`, `on_the_way` only); `record_no_show` 0024:374 (`on_the_way` only); `handle_exception` close → `cause_persists` (0039:132-134); `visit_stuck` key carries the last event (0038:115, 120-121) | An explicit, audited command ends a `started` or `paused` visit as **not completed** (name and status engineering's choice, e.g. `interrupted`), with a reason and the actor, by the performer or a coordinator. It ends `visit_stuck`, produces **no billable fact** and does not count as a completed visit, until `clinical` and `legal` decide how such a visit is documented and billed (new decision). The visit stays visible to the team as interrupted. pgTAP: started → interrupted with reason → no `visit_stuck`, no billable fact, audit row present; paused → interrupted, same; the performer of a B visit can record it whatever her qualification, because it records that care stopped, not care given (who else may record it is part of the decision). |
| CGR-21 | C1 (0038), COVER1 | advisory (S2; dormant while cover is off) | `visit_overdue` and `visit_stuck` reach only the visit's own team and Operations. For a covered visit the covering nurse and her team never see them. The detail "von einem anderen Team übernommen" reads as "someone is going", but under 0029 the covering nurse cannot see or start the visit before D-3. Cover is off (`cover_enabled` false), so no client is affected today. | 0038:102 (detail), 0038:154 (`x.team_id in my_teams`); 0029:185-186 (acceptance sets `covered_by`, not the responsible member) | Before cover is enabled (D-3): the overdue and stuck alerts of a covered visit also reach the covering nurse and her team, and the detail does not imply that someone is on the way. pgTAP in the PR that enables cover. |
| CGR-22 | OPS1 (0039), C1 (0038) | advisory (S2) | `visit_uncovered` (P2, not escalating) remains closable by hand. With 0038 it persists after the planned start, but a hand close made 24 h ahead ("Team kümmert sich") silences it for that visit for good. If nobody is then assigned, the next signal is `visit_overdue` at the planned start, when the visit is already late. Which uncovered visits are safety-relevant is a priority question for `clinical` (D-28); it cannot be set here. | 0039:29-31 (safety = P1 or escalating); pgTAP 039:32-35 and 039:137 (`visit_uncovered` closable) | Either a strict provisional default (the hand close of `visit_uncovered` is refused while the visit is planned and nobody is responsible; it ends by assigning or cancelling), or the PO records why it stays closable. Add the question to D-28. pgTAP for the chosen behaviour. |
| CGR-23 | C1 (0038) | advisory (S3) | The stuck clock restarts with every status change, and any team member may pause or resume. A visit cycling between `started` and `paused` never reaches P1, however long it stays open. | 0038:115 (key includes the last event), 0038:120-128 (reference = last event) | Pilot measure: count of visits with more than two pause and resume cycles, or open longer than the planned duration plus the P1 threshold, reviewed weekly. A threshold change waits for D-28. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-18 | **closed** | `remove_team_member` refuses `has_visit_in_progress` for the performer of a team visit `on_the_way`, `started` or `paused` (0037:57-64) and `has_unsigned_reports` for the performer of a `completed` team visit with no `signed` or `final` report (0037:65-75). pgTAP 037: (1) colleague's visit started and paused → refused, she stays a member, nothing released (037:52-78); (2) completed, no report → refused (037:80-91); (3) draft → refused, nothing released (037:93-104); (4) signed awaiting countersignature → allowed, her planned visit released (037:106-123); final → allowed (037:125-142). A signed report can be countersigned by another registered nurse without the performer (0016:289-306) |
| CGR-12 | **closed** | `private.enforce_visit_transition` checks `private.is_registered_nurse` on every transition into `started` (first start and resume) and `completed` for B and needs-assessment visits (0038:52-58). The commands are `security invoker` (0007:126-165), so the trigger's `current_user = 'authenticated'` guard applies to them. pgTAP 038:76-109: care assistant refused at start, resume and completion (NV001), status unchanged; registered nurse allowed; an A visit stays open to a care assistant (038:118-120) |
| CGR-04 | **closed** (thresholds PROVISIONAL, D-28) | `visit_overdue` and `visit_stuck` derived in `private.derived_exceptions` (0038:89-133); `visit_uncovered` persists after the planned start (0038:91-92, PS-2); `public.team_visit_alerts()` shows them to every member of the visit's team (0038:140-175). pgTAP 038:127-203: P1 at +2 h, P2 at +10 min, not for a visit ahead or suspended, "niemand zuständig", uncovered after start, team view, no cross-team or cross-organisation leak, ends on start, stuck P2 and P1, ends on a new status change, past-dated visit of a removed member shows "zuständige Person nicht mehr im Team". Organisation overrides are bounded: priority cannot be lowered, `visit_overdue` at most +1 h, `visit_stuck` at most +2 h, escalation never later than the default (0035:526-536, 575-582). Residual items: CGR-20 to CGR-23 |
| CGR-05 | **closed** (merged as `c987e83`) | `quality_serious_open` derived while `open` or `in_review`, same key, clock from `created_at` (0039:59-64). pgTAP 039:40-66: stays in review, P1 continues, not closable, ends only on `closed`, then auto-closed |
| CGR-06 | **closed** (merged as `c987e83`) | Safety exception = effective rule P1 or escalating to P1 (0039:25-32); hand close returns `cause_persists` (0039:132-134); legacy closes no longer hide it (0039:73-74, 83-86, 101-104). An organisation cannot turn a safety type into a non-safety type (0035:577-581). pgTAP 039:68-127: no-show P1 not closable, legacy close ignored, outcome ends it; legacy close of `visit_overdue` ignored for Operations and team, cancel ends it; 039:139-145 an override to P1 makes a type safety. Residual: CGR-20, CGR-22 |
| CGR-19 | open (advisory) | interim refusal is a CSR1 criterion (`briefs/CSR1.md`); rule waits for D-30 (`clinical`, with `legal`). Not built yet |
| CGR-01 to CGR-03, CGR-07, CGR-08, CGR-11, CGR-13, CGR-15, CGR-16 | open, unchanged | no change in 0009, 0016, 0018, 0020, 0022, 0023 since `b546299`; carried in CSR1 (#149) or ABS1 (#134) |

### Other changes reviewed (no finding)

- **PO deviation for C1 (06:10):** a coordinator could close a P1 `visit_overdue` until CGR-06. Acceptable as an interim for one cycle; 0039 removed it.
- **CR-041 (0039):** "a safety exception closes only with its cause; a serious event keeps escalating in review", status PROVISIONAL with D-28. Endorsed as a strict provisional default.
- **Rule register CR-007 and CR-036:** updated for 0038 and 0037 (below).
- **PO challenge (06:10):** overdue and stuck visits on `/field` with the resolving actions. No safety objection, provided the alerts stay on `/team` and in OPS1 and still close only with their cause. The resolving actions on `/field` must include the CGR-20 path, or the only button offered for a stuck visit will be "complete".
- **PO challenge (04:17):** team composition proposed by the team, confirmed by the administrator. No safety objection, provided the refusals of 0036 and 0037 apply to the confirming command.
- **ABS1 deviation (03:10):** an absence is never refused; her performed visits stay with her under CSR1's stuck exception. Acceptable with CGR-20: an absent performer's started visit must be endable without a false completion.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ADM1 (#135, #153 merged; `delivered`) | **no blocking finding**; the PO may accept | CGR-18 closed; CGR-19 advisory (interim in CSR1, D-30); CGR-16 advisory until real data (D-29) |
| C1 (0038 merged; `delivered`) | **no blocking finding**; the PO may accept | CGR-12 and CGR-04 closed; CGR-21 (dormant), CGR-23 advisory; thresholds PROVISIONAL (D-28) |
| J3 | **no blocking finding** for CGR-12; the PO may accept | CGR-12 closed |
| OPS1 (#165 merged, `delivered`) | **not acceptable yet**; the PO sets `changes-requested` | CGR-05 and CGR-06 closed. CGR-20 blocking: an honest end for a started or paused visit, as the next CSR1 part. CGR-22 advisory |
| F1-F4, F6, F7, J5 | changes-requested (unchanged) | CGR-01, CGR-02, CGR-03, CGR-07, CGR-08, CGR-19, BL-8, BL-9 |
| ABS1 | approved, unstarted | CGR-11, CGR-15; CGR-20 applies to an absent performer |
| All other items | unchanged | as in the earlier sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Gate C cannot open without one.
- **po:** open a decision (`clinical`, with `legal`) for CGR-20: how a visit broken off after its start is documented and billed. Add CGR-22 (is a closed uncovered visit a safety signal?) to D-28.
- **clinical** (once named): D-28, D-30, D-16, D-17.
- **legal:** D-18, D-22.

---

## 2026-10-23 02:28: ADM1 changes on the merge commit (#135)

**Scope:** `recovery/main` @ `0e90932`. Changes since the 23:05 section:
- **Code:** #135 (ADM1 changes) merged as `eceac83`: migration 0036, pgTAP 036, `/admin`, and the removal of the legacy Operations heuristics (`src/features/operations/rules.ts`, CR-034).
- **Docs:** #138 (role reconciliation), #140 (this role's 23:05 section), #152 and #154 (PO cycles: CSR1 criterion for missed visits of removed members; BL-8 and BL-9 added to CSR1). Open: #153 (ADM1 `delivered`, docs only), #3 (`recovery/main` → `main`, out of scope for this review).

I read migration 0036 in full, pgTAP 036, and the report, visit and RLS functions it interacts with (0003, 0007, 0016, 0019, 0024). **I did not run the tests.** CI on `eceac83` and on `0e90932` shows app, db (migrations, seed, pgTAP) and e2e green.

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-18 | ADM1 (#135, merged) | blocking (S1) | The CGR-10 refusal checks the **responsible** person only, but documentation belongs to the **performer**. Any team member may start any visit of her team, and the performer is the first `started` actor. Only the performer may draft and sign the report. So removal still goes through, and leaves care that can never be documented, when she is: (a) performing a colleague's visit that is `started` or `paused`, or (b) the performer of a `completed` visit whose report is missing or still `draft`. After removal she fails `is_team_member`, and nobody else may draft or sign for her. The P3 `report_not_final` exception appears but nobody can resolve it except by closing it (CGR-06). Billing stays blocked, which fails safe. Re-adding her to the team is the only way out, and nothing tells the administrator so. IMPLEMENTED gap; this is the H-12 / PS-11 hazard made permanent by a routine admin command. | 0036:107-110 (`v.responsible_user_id = p_user_id`); RLS `team_members_update_visits` 0003:175-178 (no responsibility check); `private.visit_performer` 0016:98-105; `create_report_draft` 0016:184 and `sign_report` 0016:254, 262 (team member **and** performer); pgTAP 036:89-116 tests the responsible person only | `remove_team_member` also refuses (result code engineering's choice, e.g. `has_visit_in_progress` and `has_unsigned_reports`) while she is the performer of a visit of the team that is `started` or `paused`, or of a `completed` visit of the team with no report or a `draft` report. `/admin` shows the reason. pgTAP: (1) member B starts A's visit → removing B is refused, nothing released; (2) B completed a visit, report missing → refused; (3) B's report is `draft` → refused; (4) B's report is `signed` (awaiting countersignature) or `final` → removal allowed. |
| CGR-19 | F6 (report correction) | advisory (S2) | A report correction is drafted by anyone in the team, but it carries the original performer and only she may sign it. Once the performer has left the team, **no correction of her final report can ever become final**, and the correction draft stays open. The current final version stays in force, so the record is not lost, but an error found later cannot be corrected. Who may sign a correction for an author who has left is a clinical and legal rule, so it cannot be invented here. UNKNOWN; owner `clinical` + `legal`. | `correct_report` 0016:343-349 (`r.performer_id` copied); `sign_report` 0016:262 | The PO opens a decision (`clinical`, with `legal`): who may correct and sign a correction of a report whose author is no longer in the team. Until it is answered, engineering refuses `correct_report` with a clear reason when the performer is not a team member, instead of creating an unsignable draft. pgTAP. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-09 | **closed** | `private.release_member_visits` releases `planned` visits whether suspended or not (0036:55; the `suspended_at is null` condition is gone). pgTAP 036:121-153: pause → removal → resume, the near and later visits have no responsible member, carry the `uncovered` flag, and appear in `derived_exceptions` |
| CGR-10 | **closed for the responsible person**; the performer path stays open as CGR-18 | 0036:105-111 refuses `has_visit_in_progress` for `on_the_way`, `started` and `paused`; pgTAP 036:89-116 tests each status alone, nothing is released, and she stays a member |
| CGR-17 | **closed** | #140 merged (`c933656`): the D-27 row in `OPEN_DECISIONS.md` carries the owner's 22:59 interim rule |
| CGR-01 to CGR-08, CGR-11 to CGR-13, CGR-15, CGR-16 | open, unchanged | no change in 0009, 0016, 0018, 0019, 0020, 0022-0024 since `b546299`; all carried in CSR1 (issue #149) or ABS1 |

### Other changes reviewed (no finding)

- **ADM1 privacy fix:** the team-readable `released` row carries only "Mitglied aus dem Team entfernt"; the reason stays in `change_log`. 0036:113-114; pgTAP 036:164-166. Endorsed.
- **Role change keeps team visits** (`set_member_role` touches no visit; ADR-046): a nurse who becomes coach can still start her visit. pgTAP 036:180-189. No safety objection: qualification and membership are unchanged.
- **Legacy heuristics removed** (CR-034 → DEPRECATED, now removed). Intake and team-assignment alerts remain covered by OPS1 (`case_not_ready`, `offer_overdue`, `candidates_exhausted`). Low and medium open quality events no longer appear on `/operations`; they stay in the QG1 list. No finding. Serious events depend on OPS1 alone now, which raises the weight of CGR-05.
- **Residual gap of removal (PO 00:10):** a removed member's planned visit dated before today is not released (0036:56). It is now a CSR1 criterion under CGR-04 (`briefs/CSR1.md`). Endorsed; it closes with CGR-04.
- **CSR1 BL-8 and BL-9:** added as conditions with testable criteria, as recommended at 23:05. They match the risks. Status in the register: in a brief.

### PO challenge answered (journal 01:10)

The PO proposes that `cra` reviews clinical-scope PRs **while they are open**, so that merge and acceptance fall in one PO cycle. **Agreed.** The gate is unchanged. From this run on I review every open PR in scope at its current head and comment there. A section on the merge commit is then needed only when the merge brings in changes I have not reviewed. This run found CGR-18 only because the merged code was read again against the report functions; a review of the open PR would have found it a cycle earlier.

### Gate status per item

| Item | Result | Findings |
|---|---|---|
| ADM1 (#135 merged, #153 `delivered`) | **not acceptable yet** | CGR-18 blocking. CGR-09 and CGR-10 (responsible person) are met; the privacy fix and the role-change rule are endorsed. Acceptance waits for one small change to `remove_team_member` with its pgTAP cases. |
| F6, F7 | changes-requested (unchanged) | CGR-02, CGR-03; CGR-19 advisory added |
| CSR1 | approved, unstarted | no change; recommend that the CGR-18 change rides with CSR1's first PR or a small ADM1 follow-up, whichever is first |
| ABS1 | brief amended, unstarted | ABS1 reuses `private.release_member_visits`; the CGR-18 performer check applies to an absence too (a nurse going absent with an unsigned report). Recommend adding it to ABS1's criteria |
| All other items | unchanged | as in the 22:30 and 23:05 sections |

### Decisions requested

- **owner (critical path):** name the qualified clinical owner and a deputy (G-1). Without that, Gate C cannot open.
- **po:** open a decision for CGR-19 (owner `clinical`, with `legal`): who may correct and sign a correction of a report whose author has left the team.
- **clinical** (once named): D-28, D-16, D-17 first.
- **legal:** D-18, D-22.

---

## 2026-10-22 23:05: owner decision D-27

**Trigger:** the owner decided D-27 on 2026-10-22 at 22:59. No code was merged since the baseline. #139 (governance), #137 and #136 (PO) are docs-only.

**Owner decision, as given:**
- The Clinical & Regulatory Architect remains an **advisory** role. It may review, challenge, recommend, identify risks and identify controls.
- It may **not** approve clinical rules.
- **Until a named, qualified clinical owner is appointed, all clinical decisions remain OPEN and are treated as provisional.** Engineering may implement safe defaults, but no clinical rule may be marked clinically approved.

**What this means for the gate:**

1. **Findings:**
   - Every finding in this report is a recommendation, not a rule.
   - A `blocking` finding stops acceptance. That follows from the PO/README gate, not from any authority of this role.
   - Each finding's remedy is an engineering control or a request for a decision. None is an approved clinical rule.
2. **Decisions:**
   - D-6, D-10, D-15, D-16, D-17 and D-19 (`clinical`) **cannot move to *Decided*** while `clinical` is unnamed.
   - The PO may sharpen them but not answer them. Neither may Engineering or this role.
3. **Safe defaults:** the provisional defaults in code stay. Where a finding needs a threshold that only `clinical` can set (CGR-04 missed-visit threshold, CGR-13 hold semantics), engineering implements a **strict provisional default** and registers it as `PROVISIONAL`. Strict means it alerts or blocks earlier, never later.
4. **Clinical Rule Register:** the status `APPROVED` is unavailable until `clinical` is named. All 34 rules stay `UNVALIDATED`, `PROVISIONAL` or `DEPRECATED`.
5. **Pilot impact:** without a named clinical owner, Gate B (synthetic-data staging) can complete its engineering items, but **Gate C (real clients) cannot open**. It needs answered clinical decisions (G-1, S1).

### Findings

| ID | Item | Severity | Finding | Evidence | Testable remedy |
|---|---|---|---|---|---|
| CGR-17 | protocol (D-27 row) | blocking (governance) | #136 was merged at 22:40 with D-27 recorded but without the owner's interim rule. Without it, a later cycle could treat a provisional default or an Architect recommendation as decided. | `OPEN_DECISIONS.md` D-27 row on `recovery/main` @ bf5ed02; owner decision 22:59 | The owner's interim wording is added to the D-27 answer, attributed to the owner, by the governance PR that carries this section. It resolves on merge. |

### Status of earlier findings

| ID | Status | Evidence |
|---|---|---|
| CGR-14 | **closed** | #136 merged (bf5ed02): README *Roles* has `cra`, a reviewer without decision rights, and `clinical`, the named, qualified human |
| CGR-01 to CGR-13, CGR-15, CGR-16 | open, unchanged | no code merged since `b546299` |

### PO response reviewed (#141, merged 23:00)

| Check | Result |
|---|---|
| Gate applied to accepted items | F1-F4, F6, F7, J3, J5, OPS1 and C1 set to `changes-requested`, which is correct under the README gate |
| CSR1 brief (`briefs/CSR1.md`) | carries CGR-01 to CGR-08, CGR-12 and CGR-13 with testable criteria matching the report's remedies; no clinical threshold invented (D-28); strict provisional defaults must be registered |
| D-28 (missed and overdue visit thresholds, `clinical`) | correctly routed; stays OPEN under D-27 |
| D-29 (qualification verification, `owner`) | correctly routed; synthetic data only until answered |
| ABS1 amended; ADM1 stays on #135 | consistent with CGR-09 to CGR-11 and CGR-15; I will review them at delivery |
| Not yet in any brief (advisory, S2) | BL-8 (a billing fact stays billable after a later hold) and BL-9 (working-time facts miss corrections), both in the Safety Risk Register. Recommend adding them to CSR1 as conditions |

### Decisions requested

- **owner (now the critical path):** name the qualified clinical owner, with a deputy. It becomes the *Participants* row "Human clinical owner (named, qualified)" from #136.
- **owner:** D-1 and D-11.
- **legal:** D-18 and D-22.

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
