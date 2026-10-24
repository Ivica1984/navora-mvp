# Remediation plan: CGR-24 and CGR-30 (a report correction could stay open for good)

**Written by:** Engineering (`eng`) · 2026-10-23 14:40 (Europe/Zurich) · **Item:** F1-F4, F6 · **Remedy item:** CSR1 part 8, delivered under issue #149
**Finding:** [Clinical Governance Report, section 2026-10-23 10:29](../../reports/CLINICAL_GOVERNANCE.md), CGR-24, advisory (S2), a condition of F1-F4's acceptance (PO 2026-10-23 11:25). CSR1 criterion CGR-24 (strict provisional default). CGR-30 (advisory S3, `cra` section 2026-10-23 14:30 on PR #200): the signal must not be closable by hand. Decision D-28 (`clinical`).

## Risk

A report correction draft (F6, `correct_report`) could stay unsigned without end. Meanwhile the old final version stays in force (0044) and the draft unlocks the visit's times and observations (0040). Nothing told the team or Operations that a correction was left half done.

## Affected code and data

- Migration 0047 §1 exception rule `report_correction_open` (P3, no own threshold, not escalating); §1b `private.exception_closes_with_cause` lists it (CGR-30); §2a `private.derived_exceptions` derives it; §2b `public.team_visit_alerts` returns it, an earlier close does not hide it; §2c `public.operations_exceptions`: `closable = false`, an earlier close does not hide it.
- App: `/team` "Einsätze mit Handlungsbedarf" (footer text), `/operations` exception centre (generic card).
- Unchanged: `correct_report`, `sign_report`, `countersign_report`, billing (reads only final versions, 0043). No data migration; open corrections older than the threshold appear once 0047 runs (intended).

## Steps

1. IMPLEMENTED: a correction version not `final` after the organisation's `report_not_final` threshold raises `report_correction_open` (P3) for the team and Operations.
2. IMPLEMENTED: it ends when the correction is final; a correction signed but waiting for the countersignature keeps it (stricter than the criterion; ADR-058).
3. IMPLEMENTED (CGR-30): closes only with its cause: a hand close returns `cause_persists`, `closable = false`, an earlier close hides it neither for the team nor for Operations.
4. IMPLEMENTED: detail without clinical text (date, time, version, what is missing); key per correction version.
5. IMPLEMENTED: rule register CR-053 (PROVISIONAL, D-28); ADR-058.

## Tests

- pgTAP 047: rule shape; not a safety exception; fresh draft → nothing; 23 h → nothing; 25 h → P3 for Operations and the team, detail, key; not closable, hand close → `cause_persists`, an earlier close row hides it neither for the team nor for Operations (CGR-30); another organisation sees nothing; an organisation override of `report_not_final` (48 h) moves the threshold; signed final → gone for team and Operations; a care assistant's correction signed but not countersigned → stays ("Gegenzeichnung offen") → countersigned → gone. pgTAP 019 counts 17 exception types.
- CI runs them. Locally only pgTAP ran (plain PostgreSQL 16, stubbed Supabase roles, a minimal pgTAP shim).

## Needs a decision (not built here)

- **D-28** (`clinical`): the threshold (24 h now, shared with `report_not_final`) and the priority.
- UNKNOWN: whether a correction draft should be withdrawable (the criterion mentions it; no such command exists).
