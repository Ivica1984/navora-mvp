---
id: ADM1
title: Pilot administration — members, qualifications and operating rules
author: po
status: approved
updated: 2026-10-22
---

# ADM1 — Pilot administration: members, qualifications and operating rules

## PO review — 2026-10-22 20:15: changes-requested (patient safety)

Reviewed on merged evidence: #101 (head c736429, CI green: app, db, e2e; merge commit bdb0d1d on `recovery/main`: app and db green, e2e red on one run only in `lifecycle.spec.ts` "a visit suspended by a pause …", the known C1 flake, see below; `admin.spec.ts` passed), ADR-046, migration 0035, pgTAP 035 (67 assertions), unit `admin-rules.test.ts`, e2e `admin.spec.ts`. **The PO did not run the tests**; results are taken from CI and from reading the code.

| Criterion | Result | Evidence |
|---|---|---|
| Member profile with display name, shown in the team week, primary nurse and deputy | met | `member_profiles` (name only, commands only); pgTAP 035 "Anna M." in `team_cases()` members, primary nurse id; e2e "Carla Coach" in `/admin` |
| … shown at report signature and countersignature, quality-event author, exception owner | met in code; **not asserted** for report and quality | `signed_by_name`, `countersigned_by_name`, author name in `field_quality`; pgTAP 035 only `lives_ok` for `field_reports` and `field_quality`; unit `handlerLabel` asserts the exception owner name |
| Invite with role, optional team and qualification; accepted on sign-in with the confirmed email | met | `invite_member`, `accept_my_invitations` (`auth/actions.ts`); pgTAP 035 invalid email, team without qualification refused, duplicate member, revoke, accept once, idempotent, unconfirmed email accepts nothing; e2e invite |
| Add and remove team memberships; qualification change with a reason, audited | met for the commands; **unsafe side effect on removal** (change 1) | `add_team_member`, `remove_team_member` (reason, refused while primary nurse or deputy of an open case), qualification through the F0 command `set_member_qualification` (reason, change log); pgTAP 035 add once, removal guard, removal logged |
| Create, rename, deactivate teams, set the region; deactivation refused while cases are open | met | `create_team`, `update_team`, `deactivate_team` (`status = 'closed'`, J2 excludes it); pgTAP 035 unique name, refused with open cases, closed team takes no member, audited; e2e create and refused deactivation with the reason shown |
| Response deadlines and exception thresholds and priorities within safe ranges, audited, no migration, who and when | met | `set_response_deadline`, `set_exception_rule`, `reset_exception_rule`, `private.effective_exception_rules`; pgTAP 035 P1 never lowered or later, others ≤ 2× default, escalation never later, override per organisation only, who and when; e2e out-of-range refused, reset to default |
| Tariff and reference data not editable | met | pgTAP 035 no insert/update privilege on `tariff_rates`; no `tariff`/`billing_rule` command exists |
| Negative tests: nurse, coach, operations, other organisation | met | pgTAP 035 nurse, coach, operations and foreign administrator each refused and see nothing; e2e nurse sees `admin-denied` |

**Why changes-requested.** The administration does what the brief asks, and the safe ranges for operating rules are exactly right: an organisation may make safety alerts earlier, never later. But `remove_team_member` deletes the membership and leaves every future visit with `responsible_user_id` = that person. `private.visit_flags` raises `uncovered` only when the responsible member is null, so these visits **look covered, raise no J3 flag, no OPS1 exception and no COVER1 offer, and the person they are assigned to can no longer see them**. This is the same silent-miss failure that ABS1 was approved to close, created here by an administrator's routine action. Patient safety is a precondition, so it cannot be accepted with a condition.

**Changes (testable, one PR):**
1. **Removal releases her visits.** `remove_team_member` sets the responsible member to null on every visit of that team's cases that is `planned` (not started, not cancelled, not suspended) and dated today or later, in the same command. Each release is written to the plan change log with the reason "Mitglied aus dem Team entfernt: <reason>"; the result returns the number released, and `/admin` shows it ("3 Einsätze sind jetzt offen im Team"). pgTAP:
   - a removed member's future planned visit has no responsible member, carries the flag `uncovered` and appears in OPS1 `derived_exceptions` as an uncovered visit;
   - her started, completed and past visits are unchanged;
   - the release is in the change log with the reason;
   - another team's visits are untouched.
   Build it as one private release function that ABS1 reuses (ABS1 releases the same set for a time range), so there is one release rule, not two.
2. **Role change is explicit about visits.** pgTAP for `set_member_role` from nurse to coach or operations while she is responsible for a future visit: either she can still start it (team membership and qualification unchanged, asserted), or the visit is released as in change 1. ADR-046 states which.
3. **Names asserted where people appear.** pgTAP: `field_reports` returns the signer's and countersigner's display name; `field_quality` returns the author's display name; a profile of another organisation never appears; without a profile the name is null and the neutral label stays.
4. **Remove the unvalidated legacy hints** ("Weitere Hinweise" on `/operations`, `src/features/operations/rules.ts`), as the brief's constraint asks once ADM1 ships. There are no pilot users yet who rely on them; the OPS1 exception list is the validated source.

**Deviations, decided:**
- Account creation and the invitation e-mail outside the app until D-26: **accepted** for the pilot (a few accounts, created by NAVORA operations). D-26 stays with the owner; the PO recommendation is added there.
- Built under D-5 while D-20 is open: **accepted**. D-5 is the decided rule. The PO's 18:20 line "ADM1 waits for D-20" is withdrawn: D-20 may later move admission to the teams as a follow-up, and the commands are already scoped so that a team-level permission can be added without a data change.
- Deactivation refused while cases are open (active or paused), not only active: **accepted**, it is the stricter and safer reading (a paused case returns to its team, RET1).
- Qualification changed through the existing F0 command: **accepted**, one rule for J2, J3 and ADM1.

**C1 condition (open since 16:15):** the e2e "a visit suspended by a pause is marked on /field …" failed again on the merge commit bdb0d1d while it passed on the PR head. It is not ADM1's failure. It must be fixed in engineering's next PR (the ADM1 changes or ABS1), not re-run.

## Problem
Several things NAVORA administrators must manage can today be changed only by a command or by a migration:
- member qualifications (D-5, F0);
- response deadlines (J2);
- exception thresholds (OPS1).

Members also have no display names, so a nurse cannot see who her case's primary nurse is (J6). Running a pilot this way means every invitation, every new team and every threshold change becomes an engineering task, and teams work with unnamed colleagues.

## Users and journey step
NAVORA administrators. Every user benefits from names. Cross-cutting: Team Decision, Planning, Visit, Operations.

## Outcome
A NAVORA administrator manages members, teams and operating rules in one admin area without engineering help. Every person shows by name wherever the product lists people.

## Acceptance criteria
- [ ] **Member profile** with a display name. It is shown wherever members appear: team week, primary nurse and deputy, report signature and countersignature, exception owner, quality-event author.
- [ ] An administrator **invites** a person to the organisation with a role, adds and removes team memberships, and sets the qualification (`registered_nurse`, `care_assistant`). A qualification change needs a reason (F0 rule) and is audited.
- [ ] An administrator **creates, renames and deactivates teams** and sets their region. Deactivating a team with active cases is refused until the cases are handed over.
- [ ] An administrator changes **response deadlines** per referral type (J2) and **exception thresholds and priorities** (OPS1) within safe ranges. Changes are audited, take effect without a migration and show who changed what and when.
- [ ] **Tariff and reference data (J5) are not editable here.** They change only through a reviewed migration with a cited source, because they are regulated data.
- [ ] Negative tests: nurses, coaches and operations can open none of these functions; another organisation's administrator sees nothing.

## Out of scope
Self-administration by partners or teams (D-5), single sign-on, MFA rollout, payroll data.

## Constraints and references
D-5 (decided: NAVORA administrators manage members and qualifications). D-3 (role matrix). J6 gap "members without names". OPS1 follow-up: remove the unvalidated legacy hints once this ships, unless pilot users rely on one.

## Open questions for engineering
- Do profiles belong in `organization_memberships` or in a separate table that does not hold health data?
