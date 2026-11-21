# Remediation plan: CGR-26 (the performer did not see who ended her visit)

**Written by:** Engineering (`eng`) · 2026-10-23 14:40 (Europe/Zurich) · **Item:** OPS1 · **Remedy item:** CSR1 part 8, delivered under issue #149
**Finding:** [Clinical Governance Report, section 2026-10-23 10:29](../../reports/CLINICAL_GOVERNANCE.md), CGR-26, advisory (S3), a condition of OPS1's acceptance (PO 2026-10-23 11:25). Decision D-31 (`clinical`, with `legal`) for corrections.

## Risk

Since 0042 a team member or a coordination role can end a started visit as not completed. The performer saw the reason but not that someone else had ended it, so an end recorded by Operations or a colleague could go unnoticed by the person at the client.

## Affected code and data

- Migration 0047 §3: `public.field_visit_status_notes(date)` returns who recorded each note as a label (`actor_kind`, `actor_name`, `actor_qualification`, `actor_role`; no user id).
- App: `src/features/lifecycle/rules.ts` (`recordedByLabel`, `recordedBySomeoneElse`), `/field` card (`visit-lifecycle.tsx`, "Beendet von … · time"), `database.types.ts` (by hand; the types bot regenerates it).
- Unchanged: `end_visit_not_completed`, `visit_status_notes`. No data migration.

## Steps

1. IMPLEMENTED: the card of an interrupted visit shows who ended it and why; emphasised when it was not the reader.
2. IMPLEMENTED: a member who has left is "nicht mehr im Team", without name.
3. PLANNED (AN2): the count of ends recorded by a coordination role while the visit was in progress.
4. OPEN (D-31): correcting an end recorded in error; nothing built.

## Tests

- pgTAP 047: reader columns (no id); a colleague's end → team, name, qualification; Operations' end → coordination, role; her own → me; seen by the colleague as team; after the colleague leaves → former, no name; another organisation reads nothing.
- Unit `tests/unit/lifecycle-rules.test.ts` (labels). e2e `tests/e2e/lifecycle.spec.ts` at phone width: the nurse starts a visit, the care assistant ends it on her own session, the nurse's card shows "Beendet von … Pflegeassistenz" and the reason.
- CI runs them; locally only pgTAP ran.
