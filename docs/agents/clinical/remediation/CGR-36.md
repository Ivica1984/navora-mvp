# Remediation plan: CGR-36 (the "inform the doctor" task can never be completed), with CGR-40

**Written by:** Engineering (`eng`) · 2026-10-24 11:35 (Europe/Zurich) · **Item:** ORD0 (issue #247) · **Brief:** `briefs/ORD0.md`
**Findings:** [Clinical Governance Report, section 2026-10-24 02:26](../../reports/CLINICAL_GOVERNANCE.md), CGR-36, **advisory (S2)**; section 2026-10-24 06:30, CGR-40, **advisory (S3)**. Hazard H-18, billing risk BL-16. Product decisions: PO 2026-10-24 03:10 (ORD0-1 to ORD0-6) and 07:10 (CGR-40: lower bound = case creation).

## Risk

When A/C care is given without a medical order, NAVORA cannot record whether, when and how the treating doctor was informed. The permanent open task teaches teams to ignore tasks. `lca` reads KLV Art. 8a Abs. 1bis as requiring the information (advisory, D-22); whether it is a billing condition and its deadline are UNKNOWN (`legal`, `clinical`).

## Affected code and data

- Task creation: `public.plan_visit` (0014 … 0050), `private.generate_case_plan` (0025, 0030, 0046); closing: case close (0024, 0031). `public.complete_case_task` (0034) refuses `inform_gp` and stays so.
- New data: `public.case_gp_notices` (date, channel code, task, actor, time; no free text, no health data). The live project is not touched.
- App: `/team` case card; HAND1 (`/field`).

## Steps

1. IMPLEMENTED (0061): `public.record_gp_informed` — a member of the case's team records the date (not in the future, not before the case was created; CGR-40) and one channel code; audited, idempotent (`duplicate`); closes the open `inform_gp` task (`done_by`, `done_at`) in the same transaction.
2. IMPLEMENTED (0061): once a case has a record, planning and PLAN2 do not reopen `inform_gp` for it (otherwise the next plan refresh reopens it). **Q12 (`po`)** decides when the team must be asked again; until then the strict reading of the brief's outcome ("the task closes") applies.
3. IMPLEMENTED (app): the case card shows "Hausärztin/Hausarzt informiert am <Datum> (<Kanal>)"; while the task is open, one step records it. HAND1 lists the record.
4. IMPLEMENTED (0061): AN2 measure 10 `inform_gp_done_within_7d_share` per team (evidence for D-22, not a deadline).

## Tests

pgTAP 063: A/C visit without an order → task open; team member → `done`, `done_by`, audit rows; non-member (Operations, coach) → `rejected`; other organisation → `rejected`; replay → `duplicate`; future date → `rejected`; date before case creation → `rejected`; date between case and task creation → `ok` (CGR-40); `complete_case_task('inform_gp')` still refused; no reopening by planning or PLAN2; immutable record; RLS. Unit `gp-rules`; e2e `doctor.spec.ts`. CI is the runner.

## Needs a decision

- **legal / clinical (D-22):** deadline and content of the information; whether it is a billing condition. Nothing of this is built.
- **po (Q12):** when `inform_gp` opens again after a record (built: never within the same case).
