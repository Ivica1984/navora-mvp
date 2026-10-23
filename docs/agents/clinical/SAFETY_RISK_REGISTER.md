# Safety Risk Register

**Maintained by:** Clinical & Regulatory Architect (review role) · **Last change:** 2026-10-23 19:57 (PS-27 added for CGR-34). 2026-10-23 19:46 (#222 merged: BL-15 closed; PS-26 decided by the PO, build pending) · **Baseline:** `recovery/main` @ `50ee5f5`

This register holds every open risk from the clinical governance reviews: clinical (`C`), patient safety (`PS`), regulatory (`R`), billing (`BL`) and governance (`G`). Hazards to clients are in [`HAZARD_LOG.md`](HAZARD_LOG.md). Gate findings with remedies are in [`../reports/CLINICAL_GOVERNANCE.md`](../reports/CLINICAL_GOVERNANCE.md). Engineering items are in `docs/engineering/SECURITY_RISKS.md`; this register does not duplicate them.

**Severity:** S1 blocks a pilot with real clients · S2 before go-live · S3 during the pilot.

**Gates:**
- **A:** governance in place.
- **B:** synthetic-data staging.
- **C:** real clients and invoicing.

Gate details are in the report.

## Risks

| ID | Cat. | Risk | Evidence | Sev. | Owner | Required action | Gate | Status |
|---|---|---|---|---|---|---|---|---|
| G-1 | gov | No named clinical owner or legal adviser. Per D-27 (decided 2026-10-22) all clinical decisions stay OPEN and provisional until one is named, so real-client use cannot start | `README.md` *Participants*; D-27 | S1 | owner | appoint the qualified clinical owner and a deputy; name a legal adviser | C | open (role decided; person not named) |
| G-2 | gov | Acceptance on green CI without clinical review | `NEXT_CAPABILITY.md` standing review rule | S1 | owner, po | clinical review gate (#136) including the D-27 interim rule (CGR-17) | A | mitigated (gate in README via #136; interim rule in D-27 via #140; reviews of open PRs agreed 2026-10-23) |
| G-3 | gov | AI agents write clinical and billing logic without a human merge | `README.md` *Participants* | S1 | owner | human approval for migrations touching clinical or billing logic | A | open |
| G-4 | gov | Operational rules with clinical effect decided by the PO alone (Q8, Q9, Q11, D-21) | `OPEN_DECISIONS.md` *Decided* | S2 | owner | clinical co-approval; entries in the Clinical Rule Register | A | open |
| G-5 | gov | No outcome indicators; patient outcomes ranked 6th of 10 | `NEXT_CAPABILITY.md` value order; AN1 | S2 | owner, clinical | define pilot outcome indicators | C | open |
| G-6 | gov | Documentation drift: `main`, handover docs and engineering roadmap disagree with `recovery/main` | `docs/engineering/ROADMAP.md`; D-8 | S3 | eng, owner | merge (D-8); keep status files authoritative | A | open |
| G-7 | gov | Source code provenance unverified (agent transcription) | SR-19; `RECOVERY_LOG.md` | S3 | owner | zip comparison (O-C) or formal acceptance of the rewritten code | C | open |
| C-1 | clin | KLV category chosen freely by the team | CR-001 | S1 | clinical | D-15 | B | open |
| C-2 | clin | Needs assessment labelled category A without sign-off | CR-002 | S2 | clinical | D-15 | B | open |
| C-3 | clin | Two qualification levels only, default `care_assistant` | CR-009 | S2 | clinical | D-15 | B | open |
| C-4 | clin | Qualification without registration evidence | CGR-16 | S1 | owner, eng | verification step before a qualification is active | C | open |
| C-5 | clin | Registered-nurse check only at first start | CGR-12 closed: 0038:52-58, pgTAP 038:76-109 | S1 | eng | check at every transition | B | mitigated-in-code (rule needs D-15) |
| C-6 | clin | Care-assistant scope for category A undefined | CR-010 | S2 | clinical | D-15 | B | open |
| C-7 | clin | Pressure to reduce countersignature (D-10); since 0040 a countersigner who sees an error must countersign and then correct (return path asked in D-10) | `OPEN_DECISIONS.md` D-10; 0040 | S2 | clinical | keep universal countersignature for the pilot | B | open |
| C-8 | clin | No reassessment on resume, reopen or return | 0024:236-258; 0025:158-165 | S1 | clinical | triggers and intervals; instrument D-13 | B | open |
| C-9 | clin | Review date passed only raises a P3 flag | 0014:150 | S2 | clinical | defined consequence of an overdue review | B | open |
| C-10 | clin | Free-text observations only; no deterioration signal | 0009:7-8 | S2 | clinical, po | structured items chosen by `clinical` | C | open |
| C-12 | clin | Severity scale hard-coded | CR-017 | S2 | clinical | D-16 | B | open |
| PS-1 | safety | Missed or overdue visit raises no alert | CGR-04 closed: 0038, pgTAP 038 | S1 | eng, clinical | exception type + threshold | B | mitigated-in-code (thresholds PROVISIONAL, D-28) |
| PS-2 | safety | Uncovered alert disappears at start time | CGR-04 closed: 0038:91-92, pgTAP 038:136; hand close still possible (CGR-22) | S1 | eng | alert persists until resolved | B | mitigated-in-code |
| PS-3 | safety | Phantom coverage after removal, downgrade, role change, absence | CGR-09, CGR-10 closed (0036); CGR-11, CGR-15 closed (0046); CGR-27, ABS1-C3, ABS1-C4 closed (0048, 0050; pgTAP 048:65-200, 050); residual CGR-28 and `accept_cover` (cover off); past-dated visits of a removed member (CSR1) | S1 | eng | one eligibility release rule | B | mitigated-in-code (cover residual before D-3) |
| PS-4 | safety | No-show only detectable after departure; no protocol | CR-014 | S1 | clinical | D-19 | B | open |
| PS-5 | safety | Hold does not stop care | CGR-13 (wording closed in 0047 / #200: "Abrechnungssperre", `HOLD_MEANING`); what a hold stops stays D-16 | S1 | clinical, eng | D-16 hold semantics | B | open |
| PS-6 | safety | Serious event leaves OPS1 on `in_review` | CGR-05 closed: 0039:59-64, pgTAP 039:40-66 | S1 | eng | exception until closed | B | mitigated-in-code |
| PS-7 | safety | Closed P1 exception never returns | CGR-06 closed: 0039, pgTAP 039:68-127; residual CGR-20, CGR-22 | S1 | eng | re-open while cause persists | B | mitigated-in-code |
| PS-8 | safety | Case closable while visits in progress or holds open | 0031:8-50 | S2 | eng | refuse or require explicit handling | B | open |
| PS-9 | safety | Pause leaves later visits planned; no alert on resume | 0024:231, 236-258 | S2 | eng | suspend through the actual return; alert | B | open |
| PS-10 | safety | No capacity or overlap check | 0030:157-164 | S2 | eng, po | overlap check | C | open |
| PS-11 | safety | Report stuck if performer absent | CR-012 | S2 | clinical, eng | delegated takeover | C | open |
| PS-14 | safety | Removing a member leaves her own in-progress or undocumented visits permanently undocumentable | CGR-18 closed: 0037:57-75, pgTAP 037 | S1 | eng | refuse removal while she is the performer (CGR-18) | B | mitigated-in-code |
| PS-15 | safety | A correction of a departed author's report can never be signed | CGR-19 closed: 0044:59-64, pgTAP 044:143; a draft opened before she left stays open | S2 | clinical, legal, eng | D-30 | C | mitigated-in-code (interim, D-30) |
| PS-16 | safety | A started or paused visit can only end as `completed`; since 0039 its stuck alert cannot be closed, so a broken-off visit is either a permanent P1 or a false completion | CGR-20 closed: 0042:99-135, pgTAP 042 | S1 | eng, clinical, legal | audited "not completed" end, not billable until decided (D-31) | B | mitigated-in-code (interim rule, D-31) |
| PS-20 | safety | After a visit is ended as not completed, no signal asks anyone to decide the follow-up for care that was due | CGR-25 closed: 0045, pgTAP 045:71-107, 169 | S2 | eng, clinical | D-31 (c)-(e) | B | mitigated-in-code (PROVISIONAL) |
| PS-21 | safety | A report correction draft reopens the visit's facts with no time limit and no exception | CGR-24 closed: 0047, pgTAP 047:101-155, 174-195; CGR-30 closed; withdraw of an untouched draft (CGR-24-W) closed: 0049:206-262, pgTAP 049:101-237 | S2 | eng, clinical | P3 exception for an open correction; D-28 threshold | B | mitigated-in-code (threshold PROVISIONAL, D-28) |
| PS-22 | safety | A coordinator's "not completed" end of a visit in progress is irreversible | CGR-26 closed for the label: 0047 §3, `visit-lifecycle.tsx:81`, pgTAP 047 (who ended it); pilot measure PLANNED (AN2) | S3 | po, clinical | show the actor to the performer; pilot measure; D-31 | C | mitigated-in-code (correction of an erroneous end: D-31) |
| PS-23 | safety | An absence does not release untimed or open-ended visits; they stay with the absent nurse and look covered | CGR-27 closed: 0048:29-54, pgTAP 048:65-126 | S1 | eng | correct interval in release, take, "Offen im Team", `known_by` | B | closed |
| PS-24 | safety | An absent nurse keeps the covers she accepted for another team | CGR-28; 0046:142; 0029:186, 215-218 | S2 if cover enabled | eng | absence ends her covers before D-3 enables cover | C | open (cover off) |
| PS-25 | safety | The open-correction signal can be closed by hand and never returns | CGR-30 closed: 0047 §1b, 2b, 2c; pgTAP 047:26-27, 108-111, 119-129 | S3 | eng | close only with its cause | C | closed |
| PS-26 | safety | An absence recorded with a start in the past leaves past planned visits inside it naming the absent member (the release rule skips dates before today); `visit_overdue` still alerts | CGR-32; 0048:111-129; 0046:139. PO decided 2026-10-23 19:12 (product authority): flagged in the overdue alert ("Zuständige Person abwesend gemeldet"), not released; `past_planned` count; CSR1 part 11, PLANNED | S3 | po, eng | show or release those visits; never refuse recording the absence | B | open |
| PS-27 | safety | A past planned visit flagged "Zuständige Person abwesend gemeldet" (CGR-32) can be closed by hand only with `cancel_visit` reasons `client_cancelled`, `client_in_hospital`, `team_cancelled` or `other`; the flag is computed, not stored, so after the cancellation the record reads as a planned cancellation, not as care that was due and not given because the responsible member was absent | CGR-34; `cancel_visit` 0024; PO condition CGR-32 (3), `briefs/ABS1.md` 19:12 | S3 | po, eng | the closing record keeps that the visit was not done while its responsible member was absent; whether missed care must be made up or reported is `clinical` (D-28, D-31), UNKNOWN | B | open |
| PS-17 | safety | Overdue and stuck alerts of a covered visit do not reach the covering team; the detail suggests someone is going | CGR-21; 0038:102, 154 | S2 if cover enabled | eng | include the covering team before D-3 enables cover | C | open (cover off) |
| PS-18 | safety | A hand-closed uncovered visit stays silent until it is overdue | CGR-22 closed: 0044:85-90, 136-138, 165-170, pgTAP 044:71-80 | S2 | eng, clinical | D-28 | B | mitigated-in-code (PROVISIONAL) |
| PS-19 | safety | The stuck clock restarts with every pause or resume | CGR-23; 0038:115-128 | S3 | po, clinical | pilot measure; D-28 | C | open |
| PS-12 | safety | Covering nurse without context | 0028:118-151 | S1 if enabled | owner, clinical | D-3 and D-17 before enabling | C | mitigated (off) |
| PS-13 | safety | No offline capability | grep | S2 | eng, po | offline concept (Gate 2) | C | open |
| R-1 | reg | No legal entity, licence or OKP admission | D-12 | S1 | owner | decide entity, apply | C | open |
| R-2 | reg | Canton-specific rules seeded as federal | CR-028, CR-029 | S1 | owner, legal | D-11; re-seed per canton | C | open |
| R-3 | reg | Possible data-protection incident on live | `CONTAINMENT_REPORT_C1` | S1 | owner, legal | D-1; FDPIC assessment; key rotation | A | open |
| R-4 | reg | No DPIA, processor contracts, legal basis, retention | D-4, D-9 | S1 | legal | complete before real data | C | open |
| R-5 | reg | Public repository, no branch protection | D-7 | S2 | owner | make private; protect branches | A | open |
| R-6 | reg | Foreign `orders` table with e-mail addresses in the health database | SR-26 | S2 | owner | move or delete | A | open |
| R-7 | reg | Live schema drift (`billable` default true, cascade delete of care notes) | `SCHEMA_DRIFT_2026-10-21.md` | S2 | owner, eng | retire or migrate live | C | open |
| R-8 | reg | Medical-order form and A/C without order unconfirmed | CR-004; D-22 | S1 | legal | D-22 | C | open |
| R-9 | reg | Working-time record undecided | D-23 | S2 | legal | D-23 | C | open |
| R-10 | reg | Nursing-home leadership rules vs self-organised ward | D-25 | S1 (Horizon 3) | legal | D-25 | – | open |
| R-11 | reg | Professional accountability without line management unassigned | `MASTER_CONTEXT.md`; D-20 | S1 | owner, legal | name the accountable clinical lead per licence | C | open |
| BL-1 | billing | Rates from one canton's publication, citation inconsistent | CR-028 | S2 | legal | verify source and citation | C | open; rows marked unvalidated in the data since 0043 (CGR-08) |
| BL-2 | billing | 10-minute minimum from Basel-Stadt, applied nationally, read differently from the brief | CR-029 | S1 | legal | D-18, D-11 | C | open |
| BL-3 | billing | Billed minutes can differ from the signed report | CGR-03 closed: 0043:66-92, 172-178, pgTAP 043:86-110, 224-247 | S1 | eng | bill from the latest final snapshot | B | mitigated-in-code |
| BL-4 | billing | Order without an end date valid forever; expired orders ignored for A/C | CGR-07 closed: 0043:198-212, pgTAP 043:113-131, 150-162 | S1 | eng, legal | D-22 (form, later-recorded orders, J5-C1) | B | mitigated-in-code (strict default) |
| BL-5 | billing | All cases priced at KVG rates whatever the insurance type | CGR-07 closed: 0043:213, pgTAP 043:132-148 | S1 | eng | non-KVG not billable until modelled | B | mitigated-in-code |
| BL-6 | billing | Billing ignores qualification, needs assessment and review date | 0023:82, 120-125 | S1 | eng, clinical | billing gates after D-15 | C | open |
| BL-7 | billing | Proportional minute split is a PO rule | CR-030 | S2 | legal | D-18 | C | open |
| BL-8 | billing | Fact stays billable after a later hold | 0043:267-339, pgTAP 043:171-222; residual CGR-29 (BL-13) | S2 | eng | supersede or flag the fact | B | mitigated-in-code |
| BL-9 | billing | Working-time facts never pick up corrections | 0043:248-259, pgTAP 043:110, 242-247 | S2 | eng | regenerate on correction | B | mitigated-in-code |
| BL-10 | billing | Any team member can generate billing facts | `billing/commands.ts` | S3 | eng, po | restrict to a billing role | C | open |
| BL-11 | billing | Patient contribution and residual financing missing | 0022:358-359 | S2 | owner | D-11 | C | open |
| BL-12 | billing | Income model may reward volume over need | D-14 | S2 | owner, clinical | guardrails in J7 | C | open |
| BL-13 | billing | After a hold is lifted, an older signed snapshot counts as billable when a correction became final during the hold, until generation runs again | CGR-29 closed: 0049:383-388, pgTAP 049:243-271 | S3 | eng | build from the latest final version on lift | C | closed |
| BL-14 | billing | A residence correction never re-derives a fact; the fact's minimum rule and tariff versions come from the old canton while the preview prices with the live one | CGR-31; 0043:179, 221, 244, 373-378; 0049:342-346 | S3 (S1 before invoicing) | eng, legal | one time rule for the residence (D-18), re-derive or flag; preview prices with the fact's canton | C | open |
| BL-15 | billing | The order-as-of-visit-date rule (J5-C2) depends on `audit_cases` auditing both order columns; no test guards it, so a later migration could silently make earlier visits read today's order | CGR-33 closed 2026-10-23 19:46: pgTAP `053_cgr33_order_audit_guard` (#222, d67055b; CI green). Residual UNKNOWN: a write with `session_replication_role = replica` skips the trigger (superuser only; ADR-064) | S2 | eng | pgTAP on the trigger's argument list and on `audit_events` being append-only | C | closed |
| LT-1 | LTCF/PAG | Nursing-home analysis uses an unvalidated partial source and treats assessment roles as overhead | `NURSING_HOME_TRANSFORMATION.md` | S1 (Horizon 3) | po, owner | licence D-24; show the replacement control for each role | – | open |
| LT-2 | PAG | Upcoding incentive if team income tracks classification | D-14 | S1 (Horizon 3) | owner | written guardrail; second review of upward changes | – | open |
| LT-3 | MQI | AN1 process KPIs could be presented as care quality | AN1 | S2 | po | label AN1 as process indicators | C | open |
