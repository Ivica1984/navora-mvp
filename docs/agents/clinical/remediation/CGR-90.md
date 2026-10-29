# Remediation plan: CGR-90 (the day rule held only in the commands)

**Finding:** `cra` CGR-90, Clinical Governance Report 2026-10-28 22:00 (PR #628), **advisory S2**. Placed by the PO as **VIS1-9** (`briefs/VIS1.md`, 2026-10-28 22:15). Engineering: ADR-112, migration 0090.

**Risk:** 0089 refuses field actions on a visit dated after today inside the commands only. `authenticated` keeps the column grant `update (status) on care_visits` (0003:184, 0004:135) and `private.enforce_visit_transition` (0038) checks only the state pair, suspension and qualification. Any client holding a team member's session can start next week's visit with a direct `UPDATE`: the CGR-87 hazard (no overdue/missed signal on the real date, a record naming a day without care) on a second write path.

**Affected code and data:** `private.enforce_visit_transition` (0038), the column grant (unchanged, reason below). No data migration; existing rows are not touched.

**Steps (IMPLEMENTED in the VIS1 follow-up PR, CI decides):**
1. Migration 0090: `private.visit_status_day_refusal` returns the 0089 outcomes for a status written as `authenticated`; the trigger raises SQLSTATE 23514 with `not_today` or `started_before_date`, so the statement fails and no row changes. Pause and resume unchanged; past- and today-dated visits unchanged (VIS1-6).
2. The column grant stays: `private.transition_visit` (0007) is security invoker and writes status through it; withdrawing it would break depart, start, pause, resume and complete. The trigger is therefore the floor on every path.

**Tests:** pgTAP `090_vis1_follow_up_day_rule_every_path_and_move_fact.test.sql` (direct start, depart and complete of tomorrow's visits refused, status and events unchanged; today and yesterday as before; the command still answers `not_today` with its audit row).

**Needs a decision (not coded):** none new. The open items of CGR-87 (tolerance before the date, late documentation) stay with `clinical` and the Clinical Owner (UNKNOWN).
