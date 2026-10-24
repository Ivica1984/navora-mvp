# Remediation plan: CGR-19 (a correction nobody can sign)

**Written by:** Engineering (`eng`) · 2026-10-23 11:40 (Europe/Zurich) · **Item:** F6 (review issue #146) · **Remedy item:** CSR1 (seventh PR), delivered under issue #149
**Finding:** [Clinical Governance Report, section 2026-10-23 02:28](../../reports/CLINICAL_GOVERNANCE.md), CGR-19, advisory (S2) for F6; unchanged in 06:30 and 10:29. CSR1 criterion CGR-19 (PO 2026-10-23 03:10). Decision D-30 (`clinical`, with `legal`).

## Risk

`correct_report` (0016) copies the original performer into the correction draft, and only the performer may sign (`sign_report`, 0016, 0041). Once she has left the team, a correction of her final report can never become final. Since 0040 an open correction draft also unlocks the visit's times and observations, with no time limit (CGR-24). The final version stays in force, so nothing is lost, but the record shows an open correction forever.

## Affected code and data

- New migration `20261021000044_csr1_correction_and_uncovered.sql` §1: `public.correct_report` gains one check after `not_latest`: `private.user_in_team(r.team_id, r.performer_id)`, else `rejected` / `performer_not_in_team`. Same signature, grants and return shape.
- App: `src/features/field/report.ts` message for `performer_not_in_team` (shown by the existing correction form).
- No data migration. Correction drafts already open stay as they are (none exist outside synthetic data).

## Steps

1. IMPLEMENTED: refuse the correction while the performer is not a team member; nothing is written (no draft row, no audit row, facts stay locked).
2. IMPLEMENTED: a correction is allowed as before while she is a member, and again if she rejoins.
3. IMPLEMENTED: German message on `/field`: correction not possible, the final report stays valid, the case is not yet regulated.
4. IMPLEMENTED: rule register CR-048 (PROVISIONAL, D-30); ADR-055.

## Tests

- pgTAP 044: a final report by a registered nurse and a countersigned one by a care assistant; the registered nurse leaves the team (simulated as the table owner); a team member's correction of her report → `performer_not_in_team`, no draft row, the final version stays latest and readable on `/field`, the facts stay locked; the same request again is refused the same way; a correction of the care assistant's report (still a member) → `ok`, a draft carrying her as performer; the performer herself outside the team → `not_team_member` (unchanged); after she rejoins → `ok`.
- Unit: `tests/unit/field-report.test.ts` (message present, says the final report stays valid).
- CI runs them. Locally only pgTAP ran, on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim; nothing is claimed as passed until CI ran it.

## Needs a decision (not built here)

- **D-30** (`clinical`, with `legal`): who may correct and sign a correction when the performer has left the team, and what the corrected record shows about authorship. This refusal is replaced when D-30 is answered.
- OPEN: a correction draft opened while she was still a member stays open if she leaves afterwards. Refusing her removal for an open correction draft (0037) or closing such drafts is part of the D-30 answer, not invented here.
