# Remediation plan: CGR-07 (no bill on a missing, expired or unmodelled basis), with CGR-08 and BL-8

**Written by:** Engineering (`eng`) · 2026-10-23 10:40 (Europe/Zurich) · **Item:** J5 (review issue #148) · **Remedy item:** CSR1 (sixth PR)
**Finding:** [Clinical Governance Report, section 2026-10-22 22:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-07 (blocking) and CGR-08 (advisory, accepted as a condition); BL-8 (section 23:05, CSR1 condition 2026-10-23 01:10). Safety risks BL-1, BL-2, BL-4, BL-5, BL-8.

## Risk

- An order `present` without an end date counted as valid forever (0023:114, CR-006); an expired order did not affect A and C minutes (0023:117).
- Every case was priced at KVG insurer rates whatever its insurance type (0023:221-224).
- Canton-sourced rates and the minimum were seeded as federal (`CH`) without any marker in the data (0022:52-60).
- A fact stayed `billable` when a quality hold opened later; only the preview filtered it (0023:198), so any other reader (a future invoice) would bill a held visit.

## Affected code and data

- Migration 0043 §1 (reference data: `validated`, `validation_note`), §4 (three reasons, warning `reference_not_validated`), §5 (hold trigger and backfill), §6 (`billing_preview.reference_validated`).
- App: `features/billing/rules.ts` (labels), `components/billing/billing-preview.tsx` ("nicht validiert"), `database.types.ts`.

## Steps

1. IMPLEMENTED: `order_validity_missing`, `order_expired`, `payer_not_modelled` as not-billable reasons; no tariff rule added (the visit is not estimated).
2. IMPLEMENTED (CGR-08): seeded reference rows `validated = false` with a note; facts warn; the preview shows it. Re-seeding: PLANNED after D-11 and D-18 (owner, legal), not done here.
3. IMPLEMENTED (BL-8): a hold appends a not-billable fact (`cause = quality_hold`); lifting the last hold appends the earlier fact again (`cause = hold_lifted`); history kept; generation and hold serialised on the visit row; open holds back-filled by the migration.

## Tests

- pgTAP 043: order without end date (A/C visit) → `order_validity_missing`; expired order → `order_expired` only; `private` and missing insurance type → `payer_not_modelled`; B with a dated valid order and KVG → billable (control); the preview lists the three reasons; reference rows unvalidated with a note, the fact warns, the preview says `reference_validated = false`, and `true` once the rows are validated; hold → not-billable hold fact superseding the billable one, the old fact unchanged, the preview stops counting and lists `quality_hold`, no new fact while held; lift by a coach → billable again (`hold_lifted`), three facts, the preview counts it again, generation stays idempotent; a hold before any fact creates none.
- Unit `billing-rules.test.ts` (labels, notice); e2e `billing.spec.ts` (the notice on `/team`).
- CI runs them; locally only pgTAP (see CGR-03.md).

## Needs a decision (not built here)

- D-22 (`legal`): valid order forms and renewal; D-18 (`legal`): tariff-contract time rules; D-11 (`owner`): pilot canton (its rates and residual financing); D-12 (`owner`): admission for real invoicing. Non-KVG payers (IV, UV, MV, private) stay not billable until modelled; that is a product and legal question, not engineering's.
