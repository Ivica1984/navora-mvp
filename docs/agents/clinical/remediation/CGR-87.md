# Remediation plan: CGR-87 (field actions not tied to the visit date)

**Finding:** `cra` CGR-87, Clinical Governance Report 2026-10-28 17:30 (PR #614), advisory for every current item, **S1 before a pilot with real clients**. Item: VIS1 (`briefs/VIS1.md`, issue #617). Engineering: ADR-111.

**Risk:** a visit dated in the future can be departed, started, completed, ended as not completed or marked not met today. On its real date it is no longer `planned`, so the overdue/missed signal (CSR1, SIG1, H-01) never fires; the record states care on a date it was not given (H-05); billable facts and measured minutes follow `visit_date` (0022, 0023).

**Affected code and data:** `private.transition_visit` (0007; `depart_visit`, `start_visit`, `complete_visit`), `public.record_no_show` (0072), `public.end_visit_not_completed` (0042); `/field` (`features/field/rules.ts`, `field-client.tsx`, `visit-lifecycle.tsx`); pgTAP and Playwright tests that worked future visits. Data: no migration of existing rows; a visit already started before its date (only possible before 0089) can no longer be completed and can be ended as not completed from its date on.

**Steps (IMPLEMENTED in the VIS1 PR, CI decides):**
1. Migration 0089: the four field commands refuse a visit dated after today (Europe/Zurich) with `not_today`; `complete_visit` refuses a visit started before its date with `started_before_date`; one audit row per refusal; status, events and notes unchanged.
2. `/field`: no field action after today, one `info` sentence with the way forward, "Heute machen" through the existing `reschedule_visit` (audited `moved` row), never starting the visit.
3. Tests: pgTAP 089; existing tests use visits dated today or move them first; no guard weakened, skipped or bypassed (CGR-87 test note). The UX1-27 e2e now starts a visit dated today (UX1-C1).

**Tests:** pgTAP `089_vis1_field_actions_on_visit_day.test.sql`; vitest `vis1-rules.test.ts`; Playwright `vis1.spec.ts` and the updated `field`, `lifecycle`, `signals`, `ux1` specs.

**Needs a decision (not coded):**
- Any tolerance before the visit date (for example a visit just after midnight): a level, set by a named person and entered in the Clinical Rule Register first (CGR-87 (4)). Owner: `clinical`. UNKNOWN.
- Late documentation of a past visit, including what should happen to a visit started before its date before 0089: Clinical Owner and PO (CGR-87 (3)). UNKNOWN. Past-dated visits keep today's behaviour (VIS1-6).
- Whether a prefilled move reason meets the J3 reason duty (VIS1-3b): `cra` in the VIS1-7 gate. Until then the reason is empty and required.
