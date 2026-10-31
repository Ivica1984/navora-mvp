# Remediation plan: CGR-11 (a qualification change left B visits looking covered)

**Written by:** Engineering (`eng`) · 2026-10-23 (Europe/Zurich) · **Item:** ABS1 (also F0) · delivered under issue #134, first ABS1 PR (migration 0046)
**Finding:** [Clinical Governance Report, section 2026-10-22 22:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-11, blocking for ABS1; listed again for ABS1 in the 2026-10-23 10:29 section.

## Risk

A registered nurse changed to care assistant stayed responsible for category B and needs-assessment visits she may no longer start (CR-007). They looked covered until the start failed at the door.

## Affected code and data

- Migration 0046 §4 `private.release_visits_between` (the one release rule, `rn_only`), §10c `public.set_member_qualification` (patched from its current definition).
- `visit_plan_changes`: a `released` row with the fixed text `Qualifikation geändert` (team-readable, no reason of the administrator; that stays in `change_log`).
- No data migration: visits of members changed before 0046 are not released retroactively (OPEN, see below).

## Steps

1. IMPLEMENTED: `registered_nurse` → `care_assistant` releases her planned (suspended included) B and needs-assessment visits of that team dated today or later, through the same rule as absence and removal.
2. IMPLEMENTED: visits on the way, started or paused are not released (CGR-10); the NV001 check still refuses her resume and completion of a B visit (CR-007).
3. IMPLEMENTED: the released visits are uncovered at once: J3 flag, OPS1 `visit_uncovered` (closes only with its cause, CGR-22), "Offen im Team" for registered nurses of the team.

## Tests

- pgTAP 046 §11: B visit released with `Qualifikation geändert`, A visit stays, a paused visit stays.
- CI runs them. Locally pgTAP ran on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim (all 44 files); vitest, typecheck, lint and e2e did not run here.

## Needs a decision (not built here)

- Whether visits already held by a member whose qualification changed before 0046 must be released by a one-off data fix: a production data question for `owner` when real data exists (no real data today).
- A started B visit of a member who just lost the qualification cannot be completed by her (NV001); a colleague ends it through CGR-20. Whether that is acceptable is for `clinical` (D-28 family); no rule is invented here.
