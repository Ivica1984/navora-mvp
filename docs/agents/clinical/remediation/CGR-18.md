# Remediation plan: CGR-18 (removal leaves care undocumentable)

**Written by:** Engineering (`eng`) · 2026-10-23 03:20 (Europe/Zurich) · **Item:** ADM1 (follow-up to #135) · **PR:** #153
**Finding:** [Clinical Governance Report, section 2026-10-23 02:28](../../reports/CLINICAL_GOVERNANCE.md), CGR-18, blocking (S1). Hazard H-12, risk PS-14, rule CR-012 and CR-036.

## Risk

Only the performer of a visit (first `started` actor) may draft and sign its report, and only as a team member. `remove_team_member` (0036) checked the responsible member only. Removing a member who performs a colleague's visit, or whose completed visit has no report or a `draft`, made that documentation impossible: care delivered with no signed record. Billing stayed blocked (fails safe).

## Affected code and data

- `public.remove_team_member` (0036:79-130), replaced in migration 0037 with the same signature and return shape.
- Read only: `public.visit_events`, `public.care_visits`, `public.visit_reports`, `private.visit_performer` (0016:98-105).
- `/admin` message (`src/features/admin/rules.ts`).
- No data migration. Existing memberships are unchanged; the rule applies to the next removal.

## Steps

1. IMPLEMENTED: refuse `has_visit_in_progress` while she is the performer of a visit of the team that is `on_the_way`, `started` or `paused`.
2. IMPLEMENTED: refuse `has_unsigned_reports` while she is the performer of a `completed` visit of the team with no report in `signed` or `final`.
3. IMPLEMENTED: `/admin` explains the new refusal.
4. IMPLEMENTED: ADR-046 amendment (CGR-18) in `docs/engineering/DECISIONS.md`. The CR-036 row (added by the CRA in #155) needs the performer check once both are merged; left to the CRA, who owns the register.

## Tests

- pgTAP 037 (24 assertions), through the real commands: (1) a care assistant starts a colleague's visit → refused while started and paused, nothing released, she stays a member; (2) completed, no report → refused; (3) `draft` → refused; (4) `signed` awaiting countersignature → allowed (her planned visit is released); `final` → allowed.
- Unit `tests/unit/admin-rules.test.ts`: result code and message.
- CI runs them; nothing was run locally (no database or npm registry in this run).

## Needs a decision (not built here)

- **CGR-19** (advisory): who may correct and sign a correction of a report whose author has left the team. Owner `clinical` with `legal`; the CRA asked the PO to open it. Engineering does not invent a takeover rule.
- **Delegated takeover of an unsigned report** when the performer is unavailable (PS-11, H-12): a clinical rule, OPEN. Until then refusal is the safe default.
- **ABS1:** the same performer check should apply to an absence (CRA recommendation). PLANNED with ABS1, per its brief.
