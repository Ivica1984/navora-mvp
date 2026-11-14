# Remediation plan: CGR-72 (an automatic access end must not let a leaver's care responsibility lapse silently)

**Finding:** `cra` CGR-72, Clinical Governance Report 2026-10-27 05:30 (confirmed 09:30), **blocking for ADM2 acceptance (S2)**. Remedy decided by the PO as **ADM2-15** (`briefs/ADM2.md`, 2026-10-27 06:10). Engineering: ADR-114 (part (a)); part (b) ADR-115, migration 0092, IMPLEMENTED in PR #647 (CI decides).

**Risk:** the manual `end_member_access` refuses while she is primary or deputy nurse of an open case or holds a planned or covered visit from today (LEAVE1-2, 0074:345-356). ADM2-13 ends access at the recorded contract end without a command, so that refusal cannot fire: an open case could keep naming as primary or deputy nurse a person who can no longer read or act, and nobody is told (Hazard Log H-21, PS-61).

**Affected code and data (part (b), written in 0092):** `private.access_ended` (contract end evaluated at read time, ADR-114 engineering question 1), the LEAVE1-12 open-work list (0075), `team_case_lifecycle` / `/team` open items, OPS1 `operations_exceptions` (0019 and later), `set_primary_nurse` (0021, 0078 guard unchanged), `restore_member_access` (0074). No data migration.

**Steps (IMPLEMENTED in 0092, part (b) of the ADM2 PR #647, CI decides; part (a) does not end anyone's access and changes no responsibility):**
1. ADM2-15 (a): from 14 Zurich days before the recorded end date, the ADM2-12 list for the team's registered nurses and the organisation's administrators also shows her open cases as primary or deputy nurse and her responsible or covered visits up to the end date (case reference, role, visit date only; no client name, address or health content).
2. ADM2-15 (b): from the access end, every open case still naming her is shown to its team on `/team` ("Bezugspflege neu bestimmen" / "Stellvertretung neu bestimmen") and as one OPS1 exception per case with the existing take, comment and close lifecycle; both disappear when `set_primary_nurse` names someone else or `restore_member_access` restores her.
3. ADM2-15 (c): nothing above delays the access end (ADM2-13). No threshold, priority, ordering, escalation clock or successor choice is added; the deputy is not promoted.

**Tests (IMPLEMENTED: pgTAP 092, Playwright `contract-end.spec.ts`; CI decides):** pgTAP across the boundary with the test clock: end date recorded; she is primary nurse of case X, deputy of case Y and responsible for a visit on the end date; day 15 none listed; day 14 all three listed to the team's RN and an administrator, not to a nurse of another team, a coach or Operations; the day after, access ended, X and Y shown to their team and one OPS1 exception each; `set_primary_nurse` for X clears X's item and closes its exception; `restore_member_access` clears Y's; the manual `end_member_access` still refuses with `has_cases` (LEAVE1 suite unmodified). e2e at 390 px: the `/team` item on the day after.

**Needs a decision (not coded):** who holds the care-process responsibility after a primary nurse leaves is UNKNOWN (D-12, D-25; `owner`/`clinical`); NAVORA names no successor. No new rule is invented here.

**Built as (ADR-115):** `contract_end_handover()` (step 1, case reference = last six hex digits of the case id), `team_successor_items()` and the OPS1 exception `successor_needed` (step 2, P2 without threshold or clock), read-time access end in `private.access_ended` (step 3). Deviation for `po`: the contract end writes no row to `member_access_events` (ADR-115 deviation 1).
