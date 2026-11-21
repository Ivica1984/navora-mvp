# Remediation plan: CGR-35 (a moved flagged past visit loses the absence fact)

**Written by:** Engineering (`eng`) · 2026-10-24 02:45 (Europe/Zurich) · **Item:** ABS1 (accepted) · **Remedy item:** AN2 first change, issue #205
**Finding:** [Clinical Governance Report, section 2026-10-23 22:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-35, advisory (S3); Safety Risk Register PS-28. PO decision 2026-10-23 23:15 in [`briefs/ABS1.md`](../../briefs/ABS1.md), criteria (1)–(5).

## Risk

A past planned visit flagged "Zuständige Person abwesend gemeldet" (CGR-32) that the team moves forward with `reschedule_visit` ("Folgeeinsatz") ends its overdue alert. The flag is computed, so the record then shows an ordinary planning move: that the care due on the original date was not given because the responsible member was reported absent is lost once the absence is shortened or withdrawn. Documentation integrity; AN2 measure 8 would undercount missed care.

## Affected code and data

- Migration 0056: `visit_plan_changes.responsible_absent` (new column, check: only `moved`), `reschedule_visit` (patched on its current definition), new audit trigger `audit_visit_plan_moves`, readers `private.handover_entries` and `public.team_cases`.
- App: `src/features/handover/rules.ts` (HAND1 line), `src/app/(protected)/team/team-client.tsx` (`/team` last change).
- Unchanged: ABS1-C4 release, ABS1-C5 refusal, CGR-32 flag (computed), the reason rule of moves, who may move. No data migration: rows written before 0056 stay false (nothing was recorded then).

## Steps

1. IMPLEMENTED: before the move, `reschedule_visit` reads the CGR-34 condition (planned, dated before today Europe/Zurich, `private.visit_responsible_absent`) and stores it on the `moved` row; no parameter, no write privilege.
2. IMPLEMENTED: the row is append-only (0014), so a later withdrawal or shortening keeps the value.
3. IMPLEMENTED: one audit row per `moved` row carries `responsible_absent`.
4. IMPLEMENTED: HAND1 "Einsatz verschoben" and `/team` show the fixed text "nicht durchgeführt: zuständige Person abwesend gemeldet".

## Tests

- pgTAP 057 (the `cra` case set): absence from yesterday recorded today → yesterday's flagged visit moved to tomorrow → `true`; absence withdrawn → still `true`; the same move without an absence → `false`; a future visit moved → `false`; no app write privilege, no parameter, update refused, a non-`moved` row with `true` refused; the audit row carries it; `/team` returns it.
- Unit: `handover-rules.test.ts` (HAND1 line once after the reason; not on false or missing; not on a removal).
- CI runs them. Locally only pgTAP-style checks ran (plain PostgreSQL 16 with all migrations and the seed, stubbed Supabase roles, a minimal stand-in for the pgTAP functions used); unit and e2e did not run locally (npm registry not reachable from this session).

## Needs a decision (not built here)

- Whether missed care must be made up, and whether a move counts as making it up: `clinical` (D-28, D-31). Unchanged.
