# Safety Risk Register

**Maintained by:** Clinical & Regulatory Architect (review role) · **Last change:** 2026-10-22 22:30 · **Baseline:** `recovery/main` @ `b546299`

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
| G-1 | gov | No named clinical owner or legal adviser; clinical decisions open while features ship | `README.md` *Participants*; D-27 | S1 | owner | name a qualified person (D-27) | A | open |
| G-2 | gov | Acceptance on green CI without clinical sign-off | `NEXT_CAPABILITY.md` standing review rule | S1 | owner, po | clinical review gate (#136, #138) with a qualified approver | A | in-review (#136, #138) |
| G-3 | gov | AI agents write clinical and billing logic without a human merge | `README.md` *Participants* | S1 | owner | human approval for migrations touching clinical or billing logic | A | open |
| G-4 | gov | Operational rules with clinical effect decided by the PO alone (Q8, Q9, Q11, D-21) | `OPEN_DECISIONS.md` *Decided* | S2 | owner | clinical co-approval; entries in the Clinical Rule Register | A | open |
| G-5 | gov | No outcome indicators; patient outcomes ranked 6th of 10 | `NEXT_CAPABILITY.md` value order; AN1 | S2 | owner, clinical | define pilot outcome indicators | C | open |
| G-6 | gov | Documentation drift: `main`, handover docs and engineering roadmap disagree with `recovery/main` | `docs/engineering/ROADMAP.md`; D-8 | S3 | eng, owner | merge (D-8); keep status files authoritative | A | open |
| G-7 | gov | Source code provenance unverified (agent transcription) | SR-19; `RECOVERY_LOG.md` | S3 | owner | zip comparison (O-C) or formal acceptance of the rewritten code | C | open |
| C-1 | clin | KLV category chosen freely by the team | CR-001 | S1 | clinical | D-15 | B | open |
| C-2 | clin | Needs assessment labelled category A without sign-off | CR-002 | S2 | clinical | D-15 | B | open |
| C-3 | clin | Two qualification levels only, default `care_assistant` | CR-009 | S2 | clinical | D-15 | B | open |
| C-4 | clin | Qualification without registration evidence | CGR-16 | S1 | owner, eng | verification step before a qualification is active | C | open |
| C-5 | clin | Registered-nurse check only at first start | CGR-12 | S1 | eng | check at every transition | B | open |
| C-6 | clin | Care-assistant scope for category A undefined | CR-010 | S2 | clinical | D-15 | B | open |
| C-7 | clin | Pressure to reduce countersignature (D-10) | `OPEN_DECISIONS.md` D-10 | S2 | clinical | keep universal countersignature for the pilot | B | open |
| C-8 | clin | No reassessment on resume, reopen or return | 0024:236-258; 0025:158-165 | S1 | clinical | triggers and intervals; instrument D-13 | B | open |
| C-9 | clin | Review date passed only raises a P3 flag | 0014:150 | S2 | clinical | defined consequence of an overdue review | B | open |
| C-10 | clin | Free-text observations only; no deterioration signal | 0009:7-8 | S2 | clinical, po | structured items chosen by `clinical` | C | open |
| C-12 | clin | Severity scale hard-coded | CR-017 | S2 | clinical | D-16 | B | open |
| PS-1 | safety | Missed or overdue visit raises no alert | CGR-04 | S1 | eng, clinical | exception type + threshold | B | open |
| PS-2 | safety | Uncovered alert disappears at start time | CGR-04 | S1 | eng | alert persists until resolved | B | open |
| PS-3 | safety | Phantom coverage after removal, downgrade, role change, absence | CGR-09, CGR-10, CGR-11 | S1 | eng | one eligibility release rule | B | partly in review (#135) |
| PS-4 | safety | No-show only detectable after departure; no protocol | CR-014 | S1 | clinical | D-19 | B | open |
| PS-5 | safety | Hold does not stop care | CGR-13 | S1 | clinical, eng | D-16 hold semantics | B | open |
| PS-6 | safety | Serious event leaves OPS1 on `in_review` | CGR-05 | S1 | eng | exception until closed | B | open |
| PS-7 | safety | Closed P1 exception never returns | CGR-06 | S1 | eng | re-open while cause persists | B | open |
| PS-8 | safety | Case closable while visits in progress or holds open | 0031:8-50 | S2 | eng | refuse or require explicit handling | B | open |
| PS-9 | safety | Pause leaves later visits planned; no alert on resume | 0024:231, 236-258 | S2 | eng | suspend through the actual return; alert | B | open |
| PS-10 | safety | No capacity or overlap check | 0030:157-164 | S2 | eng, po | overlap check | C | open |
| PS-11 | safety | Report stuck if performer absent | CR-012 | S2 | clinical, eng | delegated takeover | C | open |
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
| BL-1 | billing | Rates from one canton's publication, citation inconsistent | CR-028 | S2 | legal | verify source and citation | C | open |
| BL-2 | billing | 10-minute minimum from Basel-Stadt, applied nationally, read differently from the brief | CR-029 | S1 | legal | D-18, D-11 | C | open |
| BL-3 | billing | Billed minutes can differ from the signed report | CGR-03 | S1 | eng | bill from the signed snapshot | B | open |
| BL-4 | billing | Order without an end date valid forever; expired orders ignored for A/C | CGR-07 | S1 | eng, legal | validity required; D-22 | B | open |
| BL-5 | billing | All cases priced at KVG rates whatever the insurance type | CGR-07 | S1 | eng | non-KVG not billable until modelled | B | open |
| BL-6 | billing | Billing ignores qualification, needs assessment and review date | 0023:82, 120-125 | S1 | eng, clinical | billing gates after D-15 | C | open |
| BL-7 | billing | Proportional minute split is a PO rule | CR-030 | S2 | legal | D-18 | C | open |
| BL-8 | billing | Fact stays billable after a later hold | 0023:198 | S2 | eng | supersede or flag the fact | B | open |
| BL-9 | billing | Working-time facts never pick up corrections | 0023:154 | S2 | eng | regenerate on correction | B | open |
| BL-10 | billing | Any team member can generate billing facts | `billing/commands.ts` | S3 | eng, po | restrict to a billing role | C | open |
| BL-11 | billing | Patient contribution and residual financing missing | 0022:358-359 | S2 | owner | D-11 | C | open |
| BL-12 | billing | Income model may reward volume over need | D-14 | S2 | owner, clinical | guardrails in J7 | C | open |
| LT-1 | LTCF/PAG | Nursing-home analysis uses an unvalidated partial source and treats assessment roles as overhead | `NURSING_HOME_TRANSFORMATION.md` | S1 (Horizon 3) | po, owner | licence D-24; show the replacement control for each role | – | open |
| LT-2 | PAG | Upcoding incentive if team income tracks classification | D-14 | S1 (Horizon 3) | owner | written guardrail; second review of upward changes | – | open |
| LT-3 | MQI | AN1 process KPIs could be presented as care quality | AN1 | S2 | po | label AN1 as process indicators | C | open |
