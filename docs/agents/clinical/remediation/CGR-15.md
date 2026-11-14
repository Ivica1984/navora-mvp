# Remediation plan: CGR-15 (ABS1 must reuse one eligibility and release rule; released visits stay alerted)

**Written by:** Engineering (`eng`) · 2026-10-23 (Europe/Zurich) · **Item:** ABS1 · delivered under issue #134, first ABS1 PR (migration 0046)
**Finding:** [Clinical Governance Report, section 2026-10-22 22:30](../../reports/CLINICAL_GOVERNANCE.md), CGR-15, advisory on the brief, blocking at delivery; listed for ABS1 in the 2026-10-23 10:29 section. Brief criteria "Clinical gate", "CGR-15", "Performed visits and open reports".

## Risk

ABS1 decides who takes an absent nurse's visits. Separate rules per path (absence, removal, qualification) could release in-progress visits, miss suspended ones or let a care assistant take a B visit; a released visit nobody takes could vanish at its start time.

## Affected code and data

- Migration 0046: §3 helpers (`visit_interval`, `member_absent_during`, `may_perform_visit`), §4 `release_visits_between` and `release_member_visits` (ADM1, now delegating), §5–§7 `record_absence`, `change_absence`, `take_open_visit`, §8–§9 readers, §10 patches (PLAN2, `plan_visit_untouched`, `set_member_qualification`, `handover_entries`).
- Tables `member_absences` (no reason, no text column), `absence_releases` (internal).
- App: `/field` (absence section at the top, "Offen im Team"), HAND1 label.

## Steps

1. IMPLEMENTED: one release rule for absence, removal and qualification change: planned visits incl. suspended (CGR-09); never on the way, started or paused (CGR-10, CGR-18).
2. IMPLEMENTED: one eligibility rule at take (`may_perform_visit` = CR-007 / `plan_visit`), and the existing NV001 trigger at start, resume and complete (CGR-12).
3. IMPLEMENTED: a released visit nobody takes keeps `visit_overdue` after its planned start ("niemand zuständig", CSR1 / CGR-04) and `visit_uncovered` until someone is responsible (CGR-22).
4. IMPLEMENTED: an absence is never refused; her paused visit keeps her as responsible and performer with `visit_stuck`; her draft report stays signable by her (she stays a member).
5. PLANNED (ABS1 part 2): AN1 measures.

## Tests

- pgTAP 046 (93 assertions), including: a paused visit not released and stuck; an overdue released visit alerted with "niemand zuständig"; a care assistant not offered and refused a B visit; first take wins; another team and organisation see and take nothing; Operations does not read absences.
- `scripts/db-concurrency/open-visit-take.sh`: two real parallel sessions, one `ok`, one `already_taken` (CI step).
- e2e `tests/e2e/field.spec.ts` (phone width): two taps to the absence form, no reason field, "Offen im Team" with "Übernehmen".
- CI runs them; nothing is claimed as passed before CI.

## Needs a decision (not built here)

- None new. Thresholds of `visit_overdue` and `visit_uncovered` stay D-28 (`clinical`); who may perform which visit stays the J3 rule (D-15).
