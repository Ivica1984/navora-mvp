# Remediation plan: CGR-39 (the override range is inverted for look-ahead rules)

**Written by:** Engineering (`eng`) · 2026-10-24 08:35 (Europe/Zurich) · **Item:** ADM1 (changes-requested 2026-10-24 07:10) · **Issue:** #262
**Finding:** [Clinical Governance Report, section 2026-10-24 06:30](../../reports/CLINICAL_GOVERNANCE.md) (open PR #259), CGR-39, **blocking (S1)**. PO decision: `briefs/ADM1.md`, ADM1-R1 to ADM1-R6.

## Risk

An organisation administrator could set the P1 rule `visit_uncovered_hospital` to 0 h. Its window `between now() and now()` is then empty, and the P1 signal for an unassigned visit after a hospital discharge never fires. The same inversion let `visit_uncovered` and `team_cancellation_late` be set to 0 and `order_expiring` to fire only on the end date, while a stricter value was refused. The `/admin` text promised the opposite. Engineering also found `cover_without_access` (0029:259-261) with the same look-ahead window; the report did not name it.

## Affected code and data

- Migration 0035: `private.exception_rule_range` (526-536), `public.set_exception_rule` (577-583), `public.admin_exception_rules`. Readers that use the amount: `private.derived_exceptions` (0019, 0024, 0029, 0038, 0045, 0047).
- Data: `public.exception_rule_overrides` (organisation overrides). On synthetic data none exist after `db reset`. The live project is not touched.
- App: `src/features/admin/rules.ts`, `src/app/(protected)/admin/admin-client.tsx`.

## Steps

1. IMPLEMENTED (0059): a direction per amount-bearing rule (`look_ahead`, `delay`), required by a check constraint.
2. IMPLEMENTED (0059): one range check: look-ahead from the default up to 4×; delay from the floor (0; `visit_stuck` 1 h) up to the default; priority never lower, escalation never later.
3. IMPLEMENTED (0059): existing overrides outside the range are reset to the default, one audit row each with the old values; the count is raised as a NOTICE.
4. IMPLEMENTED: `/admin` names the range and which way is stricter per rule; the client check mirrors the database.
5. Unchanged: every default, every reader, the effective rules for organisations without overrides.

## Tests

- pgTAP 061 (49): direction of every rule, the constraint, the brief's value matrix (`visit_uncovered_hospital` 12/0 → `out_of_range`, 48 → `ok`; `visit_uncovered` 0 → `out_of_range`, 36 → `ok`; `order_expiring` 0/3 → `out_of_range`, 14 → `ok`; `team_cancellation_late` 0 → `out_of_range`, 48 → `ok`; `visit_stuck` 2 → `out_of_range`, 1 → `ok`; `report_not_final` 48 → `out_of_range`, 12 → `ok`; priority P1 → P2 refused), `cover_without_access`, `visit_overdue`, `case_not_ready`, escalation; the behavioural test (hospital discharge, unassigned visit in 36 h: no P1 exception with the default, P1 with an accepted 48 h override); the reset with audit rows, idempotent, not callable by users.
- pgTAP 035: the inverted assertions (191-196) replaced, as the brief asks; count unchanged (67).
- Unit `admin-rules` and e2e `admin.spec.ts` (a look-ahead rule refuses a lower value with the text).
- CI runs them. Locally only a stand-in ran (plain PostgreSQL 16, stubbed Supabase roles, a minimal pgTAP stand-in): 061 49/49, 035 67/67, and 019, 023, 029, 039, 044, 047, 057-060 green; with the old range put back, 24 assertions of 061 and 4 of 035 turn red. The unit file ran under `bun test` (11 pass) as a smoke check.

## Needs a decision (not built here)

- The clinical band per rule, and whether any rule may ever be made later than today's default: `clinical` (D-28). Until then nothing can be made later.
- The 4× upper bound and the `visit_stuck` floor are engineering bounds; if the PO or the Clinical Owner wants others, a new migration changes one function.
