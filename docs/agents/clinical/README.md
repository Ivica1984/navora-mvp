# Clinical governance registers

The **Clinical Governance Report** has a single path: [`../reports/CLINICAL_GOVERNANCE.md`](../reports/CLINICAL_GOVERNANCE.md). Its newest dated section is the latest report. The gate is described in [`../README.md`](../README.md) under *Clinical review gate*.

This folder holds:
- [`HAZARD_LOG.md`](HAZARD_LOG.md), [`SAFETY_RISK_REGISTER.md`](SAFETY_RISK_REGISTER.md), [`CLINICAL_RULE_REGISTER.md`](CLINICAL_RULE_REGISTER.md): maintained by the Clinical & Regulatory Architect (`cra`).
- `approvals/CR-nnn.md` (none yet): the approval record of a register row with status `APPROVED`. The row names this file; the file states `Approver role: …`, `G-1 reference: …` (naming G-1) and `Date: YYYY-MM-DD`. `npm run agents:check` fails without it (DOOR1-16, CGR-68, ADR-097). Written only after G-1, for the named Clinical Owner's decision.
- `remediation/<finding ID>.md`: remediation plans. Engineering writes one **before** proceeding with an item, whenever a finding creates a safety, billing or regulatory risk for that item.

No personal or health data here; synthetic examples only.
