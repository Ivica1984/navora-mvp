# Remediation plan: CGR-13 (a quality hold could read as a stop of care)

**Written by:** Engineering (`eng`) · 2026-10-23 14:40 (Europe/Zurich) · **Item:** QG1 · **Remedy item:** CSR1 part 8, delivered under issue #149
**Finding:** Clinical Governance Report, CGR-13, advisory, a condition of QG1 (see `briefs/CSR1.md`). Decision D-16 (`clinical`).

## Risk

The UI called a quality hold "Qualitäts-Stopp". A nurse could read it as "stop caring for this client", while it only blocks billing of the visit.

## Affected code

- `src/features/quality/rules.ts` (`HOLD_MEANING`, notice text), `src/app/(protected)/field/quality-section.tsx`, `src/app/(protected)/operations/holds-panel.tsx`, `src/components/billing/billing-preview.tsx`, `src/features/billing/rules.ts`, `src/features/quality/commands.ts`, `queries.ts`. No database change.

## Steps

1. IMPLEMENTED: "Abrechnungssperre" everywhere a hold is named in the UI, with "Gesperrt ist nur die Abrechnung; ob und wie gepflegt wird, regelt die Sperre nicht."
2. IMPLEMENTED: rule register CR-055 (UNVALIDATED, D-16).

## Tests

- Unit `tests/unit/quality-rules.test.ts`; e2e `tests/e2e/quality.spec.ts` (badge text, meaning, no "Stopp" in the section). CI runs them.
