# Remediation plan: CGR-29 (after a hold, an older signed version was billed again)

**Written by:** Engineering (`eng`) · 2026-10-23 16:45 (Europe/Zurich) · **Item:** J5 · **Remedy item:** CSR1 part 9, delivered under issue #149
**Finding:** [Clinical Governance Report, section 2026-10-23 14:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-29, advisory (S3); a condition of J5's acceptance (PO 2026-10-23 15:25). CSR1 criterion CGR-29.

## Risk

When a quality hold was lifted, the hold trigger (0043) appended the fact in force **before** the hold again. If a report correction had become final **during** the hold, no fact had been built for it (`build_billable_fact` returns null while a hold is open). After the lift, the preview and AN1 counted the **older** signed snapshot until someone ran the generation again. Billing then did not follow what the nurse last signed (billing integrity). Nothing is invoiced today.

## Affected code and data

- Migration 0049 §5: `private.billable_fact_follow_hold()` (trigger on `quality_holds`), lift branch.
- Unchanged: `build_billable_fact` (0043), the hold branch, immutability of facts, `billing_preview`.
- No data migration: a visit already in this state is corrected by the next `generate_billable_facts` (it builds the missing fact), as before.

## Steps

1. IMPLEMENTED: on the last lift, the visit's latest final report version is looked up; if it has no J5-v3 `report` fact, it is built from that version with `build_billable_fact` (the same function, the signed snapshot), superseding the hold fact. The lifter is `created_by`.
2. IMPLEMENTED: otherwise the pre-hold fact is restored as before (BL-8).
3. IMPLEMENTED (wider than the finding): the same build also happens when the fact before the hold was not billable (no hold fact was appended then, so the old branch did nothing).
4. IMPLEMENTED (J5-C1, same place): after a restore, a payer corrected during the hold is re-derived.

## Tests

- pgTAP 049: version 1 final → fact → hold → correction version 2 (start 45 minutes earlier) signed and final during the hold → no fact while held → lift → the head fact carries version 2's `report_id` and snapshot hash, cause `report`, more measured minutes than version 1, created by the lifter, superseding the hold fact; no `hold_lifted` fact. pgTAP 043 (BL-8 restore without a correction in between) unchanged and still asserting.
- CI runs them. Locally only pgTAP ran (plain PostgreSQL 16, stubbed Supabase roles, a minimal pgTAP shim).

## Needs a decision (not built here)

- Nothing new. Note for D-22 (`legal`): a fact built for a new report version (here, or by a correction anywhere) reads the case's order as it is at build time (0043, unchanged). Whether an order end date recorded later may then cover the earlier visit is the D-22 question; J5-C1's strict default covers only re-derivation.
