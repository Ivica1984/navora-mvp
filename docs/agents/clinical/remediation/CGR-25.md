# Remediation plan: CGR-25 (an interrupted visit went silent)

**Written by:** Engineering (`eng`) · 2026-10-23 12:30 (Europe/Zurich) · **Item:** OPS1 (also C1, ABS1) · **Remedy item:** CSR1 (eighth PR, completes part 7), delivered under issue #149
**Finding:** [Clinical Governance Report, section 2026-10-23 10:29](../../reports/CLINICAL_GOVERNANCE.md), CGR-25, advisory (S2), a condition of OPS1's acceptance (PO 2026-10-23 11:25). CSR1 criterion CGR-25 (strict provisional default). Decision D-31 (`clinical`, with `legal`).

## Risk

Since 0042 a visit ended as *not completed* (`interrupted`) drops every signal: `visit_stuck` ends with its cause and there is no report obligation. Care that was still due (medication, wound care) was then seen only at the next visit, and nobody had to decide about it. A client taken to hospital or left mid-visit could get no deliberate follow-up.

## Affected code and data

- Migration 0045:
  - §1 `visit_status_notes`: new kind `interruption_followup`, reason codes `follow_up_planned`, `no_longer_needed` (`other` exists); a check (code from the list, `other` needs a note); one decision per visit (partial unique index).
  - §2 exception rule `visit_interrupted` (P2, no threshold, not escalating).
  - §3 `private.exception_closes_with_cause` lists it.
  - §4 `private.derived_exceptions` derives it; `public.operations_exceptions` (`closable = false`, an earlier close does not hide it); `public.team_visit_alerts` returns it (same rule for earlier closes).
  - §5 new command `public.record_interruption_followup`.
- App: `/field` (queue "Nicht abgeschlossen: Entscheid offen" and the visit card), `/team` (visit alerts), `/operations` (exception card): one shared decision form (`src/components/lifecycle/InterruptionFollowupForm.tsx`). HAND1 shows the decision as "Nicht abgeschlossen: Entscheid".
- Unchanged: `end_visit_not_completed` (0042), billing, reports, AN1, J6 (none reads the decision).
- No data migration. Visits already `interrupted` raise the exception once 0045 runs (intended).

## Steps

1. IMPLEMENTED: an interrupted visit raises `visit_interrupted` at once, for the team (`team_visit_alerts`) and Operations (`operations_exceptions`), with reason, note and, for `client_transferred`, the case's next planned visit.
2. IMPLEMENTED: closed only by a follow-up decision from the list, by a team member or a coordination role; a hand close returns `cause_persists`; a decision without a reason, with a code outside the list, or `other` without a note is refused (22023); a second decision returns `already_decided`.
3. IMPLEMENTED: audited (audit_visit_status_notes), idempotent, actor recorded.
4. IMPLEMENTED: rule register CR-050 (PROVISIONAL, D-31); ADR-056.

## Tests

- pgTAP 045 (46 assertions): surface and rule; interrupted → visible to the team (both qualifications), not to another team, P2 for Operations, `closable = false`; hand close → `cause_persists`, nothing written; take over allowed; an earlier close row hides it neither for Operations nor for the team; refusals (outsider, other organisation, no reason, code outside the list, `other` without note, a visit not interrupted); team member decides → gone for team and Operations, duplicate, `already_decided`, `/field` reads it, audit row, actor; a coordinator decides the other → gone; visits unchanged. pgTAP 019 counts 16 exception types.
- Unit: `tests/unit/lifecycle-rules.test.ts`, `handover-rules.test.ts`, `operations-exceptions.test.ts`.
- e2e `tests/e2e/lifecycle.spec.ts` at phone width: end a started visit as not completed → card, `/field` queue and `/team` show "Entscheid offen" → a decision from the list → gone.
- CI runs them. Locally only pgTAP ran (every file the shim can run, 001 and 007 not), on plain PostgreSQL 16 with stubbed Supabase roles and a minimal pgTAP shim; vitest, typecheck, lint and e2e did not run (npm registry unreachable here).

## Needs a decision (not built here)

- **D-31** (`clinical`, with `legal`): what a follow-up decision must contain, who may decide, whether it can be corrected, and whether "Folgeeinsatz geplant" must be linked to an actual planned visit. Today it is a person's statement; nothing checks the plan.
- **D-28** (`clinical`): the priority (P2 now, organisations may only raise it).
- CGR-26 (the performer sees who ended her visit) is CSR1 part 8.
