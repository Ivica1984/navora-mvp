# Remediation plan: CGR-02 (a report is signed over facts the nurse never saw)

**Written by:** Engineering (`eng`) · 2026-10-23 08:25 (Europe/Zurich) · **Item:** F7 (issue #147), also F6 · **Remedy item:** CSR1 (fourth PR)
**Finding:** [Clinical Governance Report, section 2026-10-22 22:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-02, blocking. Hazard H-05. CSR1 criterion CGR-02.

## Risk

`sign_report` (0016) rebuilt the snapshot at the moment of signing, while `/field` showed the snapshot stored when the draft was created or last edited. An observation by a colleague or a time correction recorded in between became part of the signed report without the nurse seeing it. The signature, the record's basis for accountability, then covered facts she never confirmed (H-05).

## Affected code and data

- `public.sign_report(uuid, uuid)` (0016): dropped; replaced by `public.sign_report(uuid, text, uuid)` in migration 0041.
- `public.field_reports(date)` (0016, patched in 0035): replaced in 0041. A `draft` row now shows the live snapshot; every row carries `snapshot_hash`.
- `private.visit_report_snapshot(uuid)` (0016): pinned to `timezone = UTC` so its text, and the hash, do not depend on the session.
- New internal `private.report_snapshot_hash(jsonb)` (sha256, not callable by app users).
- App: `src/features/field/report-commands.ts` (`signReport`, `signAtCompletion` carry the hash), `report-section.tsx` (passes `report.snapshot_hash`, reloads after a refusal), `report.ts` (message for `facts_changed`), `database.types.ts`.
- No data migration. Stored snapshots of signed and final versions are unchanged. Draft rows keep their stored snapshot, which `sign_report` overwrites with the signed one.

## Steps

1. IMPLEMENTED: the draft shows the facts as they are now (the same builder `sign_report` uses), with the hash of exactly what is shown.
2. IMPLEMENTED: `sign_report` requires the hash, rebuilds the snapshot, and signs only when the hashes match. Otherwise it returns `rejected` / `facts_changed` and writes nothing.
3. IMPLEMENTED: the two-argument signature is dropped, so no caller can sign without naming what was shown.
4. IMPLEMENTED: `/field` reloads the card after a refusal and says what happened ("Zeiten oder Beobachtungen haben sich geändert … erneut unterschreiben").
5. IMPLEMENTED: ADR-052 in `docs/engineering/DECISIONS.md`.

## Tests

- pgTAP 041 (30 assertions), through the real commands: the shown hash is the hash of the current facts; a colleague's observation after she looked → `facts_changed`, nothing written; a null hash → `facts_changed`; after reloading she sees the observation and signs; the stored signed snapshot has exactly the hash she sent; saving the summary first does not refuse (F7); a time corrected in a correction draft after she looked → `facts_changed`, then signed after reloading; same hash under another session time zone; the countersignature path is unchanged.
- pgTAP 016, 019, 022, 026, 037, 038, 040: every `sign_report` call now passes the hash `/field` shows (`field_reports.snapshot_hash`).
- e2e `tests/e2e/field.spec.ts` (F6/F7 test, phone width): an observation saved in a second window after she opened the correction draft → the signature is refused, the card shows the observation, the second signature succeeds.
- Unit `tests/unit/field-report.test.ts`: the `facts_changed` message.
- CI runs them. Locally only the pgTAP files ran, on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim.

## Needs a decision (not built here)

- None for CGR-02: it applies the existing F6 rule (the performer signs the facts of the visit) to the facts she actually saw. No clinical rule is invented.
- UNKNOWN, not checked in this PR: whether any command changes the services or planned minutes of a `completed` visit after signature. Both are in the snapshot, so a change before signing is caught by the hash, and a change after signing does not touch the signed snapshot. Billing from the signed snapshot is CGR-03's J5 part (#148).
