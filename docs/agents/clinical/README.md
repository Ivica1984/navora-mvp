# Clinical governance

Owned by the **NAVORA Clinical & Regulatory Architect** (`cra`). Gate and workflow: [`../COORDINATION.md`](../COORDINATION.md#clinical-governance-gate).

- `CGR-YYYY-MM-DD.md`: Clinical Governance Report. The newest date is the **latest** report, and Engineering reviews it before any capability that affects patient care, documentation, billing, quality, assessment, LTCF, PAG or MQI. Every finding has a stable ID (for example `CGR-2026-10-22-F1`), a severity and an affected area. Each finding is marked IMPLEMENTED, PLANNED, OPEN or UNKNOWN, with the source for every rule it cites.
- `remediation/<finding ID>.md`: remediation plan, written by Engineering **before** proceeding when a finding creates a safety, billing or regulatory risk.

Status (2026-10-22): **no Clinical Governance Report has been published yet** (OPEN).

No personal or health data in this folder; synthetic examples only. Findings never invent clinical or regulatory rules: open questions go to `clinical`, `legal` or `owner` in `OPEN_DECISIONS.md`.
