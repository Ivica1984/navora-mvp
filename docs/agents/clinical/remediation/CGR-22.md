# Remediation plan: CGR-22 (an uncovered visit silenced a day ahead)

**Written by:** Engineering (`eng`) · 2026-10-23 11:40 (Europe/Zurich) · **Item:** OPS1 (also C1) · **Remedy item:** CSR1 (seventh PR), delivered under issue #149
**Finding:** [Clinical Governance Report, section 2026-10-23 06:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-22, advisory (S2) for OPS1; unchanged in 10:29 (condition for OPS1's acceptance). CSR1 criterion CGR-22 (PO 2026-10-23 07:10, strict provisional default). Decision D-28 (`clinical`).

## Risk

`visit_uncovered` (P2, not escalating) could be closed by hand in OPS1. Since 0038 it persists after the planned start, but a close made a day ahead ("Team kümmert sich") silenced it for that visit for good. If nobody was assigned, the next signal was `visit_overdue` at the planned start, when the visit was already late.

## Affected code and data

- Migration 0044 §2-4: new internal `private.exception_closes_with_cause(org, type)` (safety exceptions as in 0039, plus `visit_uncovered`); `private.open_exception_org` and `public.handle_exception` use it; `public.operations_exceptions()` returns `closable = false` for `visit_uncovered` and shows it even after an earlier close.
- Unchanged: priority P2 and the 24 h window (exception rules), `private.exception_is_safety`, `team_visit_alerts` (lists only overdue and stuck), the AN1 count of safety exceptions, `visit_uncovered_hospital` (P1, already a safety exception).
- App: `/operations` hides "Schliessen" through `closable` (no change needed); the note text `CLOSES_WITH_CAUSE` and the `cause_persists` message now name the uncovered case and no longer call every such exception a safety exception.
- No data migration. Earlier closes stay in `exception_events` (history), they simply no longer hide the exception.

## Steps

1. IMPLEMENTED: the hand close returns `cause_persists`, nothing written; take over and notes stay.
2. IMPLEMENTED: `closable = false`; a close written before 0044 does not hide it.
3. IMPLEMENTED: it ends with its cause: a start, a responsible member, a cancellation (also removal, suspension, cover, which already ended it).
4. IMPLEMENTED: rule register CR-049 (PROVISIONAL, D-28); ADR-055.

## Tests

- pgTAP 044: listed with P2 and `closable = false`; close → `cause_persists`, no close row; take over and a note → `ok`; a legacy close no longer hides it, still not closable, can be taken over; after a team member starts it, cancels it, or a responsible member is set (plan regeneration simulated as the table owner) it is gone; no listed uncovered visit is closable. pgTAP 039 updated: `closable` equals "does not close only with its cause" for every listed exception; overdue offers, missing reports and cases not ready stay closable (the hand close itself stays in 019).
- Unit: `tests/unit/operations-exceptions.test.ts` (note text). e2e `tests/e2e/operations.spec.ts`: every listed "Einsatz ohne Verantwortliche" card has no "Schliessen" and shows the note (the seed's uncovered visits depend on the time of day).
- CI runs them. Locally only pgTAP ran, on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim.

## Needs a decision (not built here)

- **D-28** (`clinical`): whether an uncovered visit is a safety signal, at which priority, and whether a hand close may silence it. The strict default is removed or widened by migration once answered.
- OPEN: no command assigns a responsible member to an existing hand-planned visit (visit assignment is D-6). Until a team can say "ich übernehme" for such a visit, its uncovered exception ends by a start, a cancellation or removal, or by planning it again with a responsible member.
