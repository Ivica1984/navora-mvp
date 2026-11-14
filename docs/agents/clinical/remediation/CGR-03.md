# Remediation plan: CGR-03, J5 part (billing reads live times instead of the signed snapshot), with BL-9

**Written by:** Engineering (`eng`) · 2026-10-23 10:40 (Europe/Zurich) · **Item:** J5 (review issue #148) · **Remedy item:** CSR1 (sixth PR)
**Finding:** [Clinical Governance Report, section 2026-10-22 22:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-03, blocking (the F3/F4 part was closed by 0040; this plan covers the J5 part). BL-3 and BL-9 in the [Safety Risk Register](../SAFETY_RISK_REGISTER.md) (BL-9 recommended in the 23:05 section, CSR1 condition 2026-10-23 01:10). Hazard H-05.

## Risk

`private.build_billable_fact` (0023:28-50, 89) took measured care minutes from the live events and time corrections and the planned minutes from the live visit row. A bill could therefore differ from the report the nurse signed. `working_time_facts` were written once per visit (`on conflict (visit_id) do nothing`, 0023:154), so a corrected report never reached working time, the base of the North Star and fair pay (D-23, J7).

## Affected code and data

- Migration `20261021000043_csr1_j5_signed_billing.sql` §2-4: `private.snapshot_times(jsonb)`; `build_billable_fact` (rule J5-v3) reads `visit_reports.snapshot` of the final version; `billable_facts.snapshot_hash`; `working_time_facts.report_id`, `supersedes_id`, `source`, one fact per final report version; AN1 patch (§7).
- No existing fact or working-time row changes (immutable). J5-v2 facts are superseded by J5-v3 facts on the next generation.

## Steps

1. IMPLEMENTED: times (travel, care, pause; exact care minutes) from the snapshot, same arithmetic as before.
2. IMPLEMENTED: planned minutes per category from the snapshot.
3. IMPLEMENTED: the fact records the hash of the snapshot it was built from.
4. IMPLEMENTED (BL-9): a working-time fact per final report version from the same snapshot; a correction appends a new one that references the earlier one; nothing is updated.
5. IMPLEMENTED: AN1 reads J5-v3 facts.

## Tests

- pgTAP 043: after signature the live start and the live plan drift (written as the table owner); the fact still has 30 measured minutes and A 20 / C 10 from the snapshot, and its hash equals the signed snapshot's; a correction version with an earlier start yields a fact with 45 minutes superseding the old fact, and a working-time fact with 45 minutes referencing the earlier one, which keeps 30.
- pgTAP 022 updated to the rule name J5-v3 (no other expectation changed).
- CI runs them. Locally: migrations and seed on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim (043: 49/49; 022: 30/30; every other file the shim can run: green).

## Needs a decision (not built here)

None for this finding. Which minutes are billed (planned, scaled to measured) stays D-18 (CR-030).
