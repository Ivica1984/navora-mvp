# Remediation plan: CGR-20 (a broken-off visit has no honest end)

**Written by:** Engineering (`eng`) · 2026-10-23 09:30 (Europe/Zurich) · **Item:** OPS1 (review issue #168), also C1 and ABS1 · **Remedy item:** CSR1 (fifth PR), delivered under issue #148 at the PO's request (comment 2026-10-23 09:10)
**Finding:** [Clinical Governance Report, section 2026-10-23 06:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-20, blocking (S1) for OPS1. Hazard H-15, safety risk PS-16. CSR1 criterion CGR-20. Decision D-31 (`clinical`, with `legal`, issue #170).

## Risk

A `started` or `paused` visit could only become `completed` (0007, 0038:38-45). `cancel_visit` works only before the start (0024:353) and `record_no_show` only on the way (0024:374). Since 0039 a `visit_stuck` exception cannot be closed by hand (`cause_persists`). A visit that really stopped therefore ended either as a permanent P1 on `/operations` and `/team`, or as a false completion: a report obligation for care not given and measured minutes that feed billing (H-15).

## Affected code and data

- New migration `20261021000042_csr1_visit_not_completed.sql`:
  - `visit_events.event_type` also allows `interrupted`; `private.write_visit_event()` writes it when the command records it (as for `cancelled` and `no_show`, 0024).
  - `visit_status_notes.kind` also allows `interrupted`; four new reason codes (`client_transferred`, `client_declined`, `nurse_unavailable`, `started_by_mistake`) plus `other`; a table check that an `interrupted` note has one of them and `other` has a note.
  - New command `public.end_visit_not_completed(p_visit_id, p_reason_code, p_reason, p_idempotency_key)`.
- No change to `private.enforce_visit_transition`: app users still cannot set a status directly to `interrupted`, so the reason cannot be skipped, and no transition leaves `interrupted`.
- Unchanged readers, because each counts only `status = 'completed'`: F6 `create_report_draft` (0016), `report_not_final` (0019, 0024), J6 (0021), J5 facts and preview (0022, 0023), AN1 (0027, 0032), HAND1's window (0033), the needs-assessment marker (0014). `visit_stuck` (0038) is derived from `on_the_way` / `started` / `paused` and ends by itself.
- App: `/field` card (`visit-lifecycle.tsx`: "Nicht abgeschlossen beenden" next to "Einsatz abschliessen" / "Fortsetzen", the reason form, "Nicht abgeschlossen · <Grund>"), `features/lifecycle/{rules,commands}.ts`, status label and colours, `features/field/{rules,time}.ts` (day summary, the clock stops), HAND1 entry title `visit_interrupted`, `database.types.ts`.
- No data migration. No existing row changes.

## Steps

1. IMPLEMENTED: terminal status `interrupted` ("nicht abgeschlossen"), reached only through the command.
2. IMPLEMENTED: the command requires a reason from the CSR1 list; `other` needs a note (3–1000 characters); records the actor in `visit_status_notes` and the timeline; audited through `audit_care_visits` and `audit_visit_status_notes`; idempotent (`begin_command`); locks the visit row so a parallel completion either wins or sees the new state.
3. IMPLEMENTED: allowed for any member of the visit's team (the performer is one: 0037 refuses her removal while the visit is in progress) and for a coordination role (`admin`, `coach`, `operations`), whatever the qualification. Refused (`rejected`) for anyone else; `wrong_state` unless `started` or `paused`.
4. IMPLEMENTED: no billable fact, no report obligation, no `report_not_final`, not counted as completed (readers unchanged, see above; pgTAP 042 checks the ones a test can reach).
5. IMPLEMENTED: visible to the team on `/field` (status and reason) and in HAND1 "Seit deinem letzten Einsatz" for the case's next visit (0033 already lists every `visit_status_notes` row of another visit of the case).
6. IMPLEMENTED: rule register CR-042 (PROVISIONAL, D-31); ADR-053.

## Tests

- pgTAP 042 (47 assertions), through the real commands: a care assistant ends a started B visit a registered nurse started; the performer ends her own visit with `other` and a note; a coordinator outside the team ends a paused, stuck visit and `visit_stuck` disappears for OPS1 and the team without a hand close; a member of another team and an admin of another organisation are refused; no reason, a reason outside the list, `other` without a note → 22023; a planned visit → `wrong_state`; a direct status update to `interrupted` or out of it → 23514; afterwards no complete, resume, restart or cancel; duplicate request → `duplicate`; reason, actor, timeline event and both audit rows present; report draft refused (`visit_not_completed`); no billable or working-time fact; a needs assessment ended this way does not mark the case's assessment as done; no `report_not_final`, stuck or overdue exception; `/field` shows status and reason; HAND1 shows the entry on the case's next visit.
- Unit: `lifecycle-rules` (reasons, labels, states, D-31 notice), `field-rules` (day summary), `field-time` (the clock stops, also from a pause), `field-report` (no report section), `handover-rules` (entry lines).
- e2e `tests/e2e/lifecycle.spec.ts` at phone width (390 px): start a visit, the action sits next to "Einsatz abschliessen", a reason is required, after saving the card shows "Nicht abgeschlossen · …", offers no complete, resume, start or report, and does not scroll sideways.
- CI runs them. Locally only the pgTAP files ran, on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim (042: 47/47; all other files that the shim can run: green). vitest, typecheck, lint and e2e did not run here (npm registry unreachable).

## Needs a decision (not built here)

- **D-31** (`clinical`, with `legal`): which reasons are allowed, whether a report with the care already given is required, whether the minutes already given may be billed, and who may finally record the end. Until then the interim rule above applies; CR-042 is PROVISIONAL.
- OPEN, part of D-31: whether a nurse may still add an observation to a visit ended this way. Today she cannot (record_observation accepts `on_the_way`, `started`, `paused`, `completed` only; unchanged); the reason note carries what happened.
- UNKNOWN, not changed here: `correct_visit_time` (0008, 0040) has no visit-status check, so a reasoned, audited time correction on an interrupted visit is possible, as on any visit without a signed report. No fact derives from those times today.
