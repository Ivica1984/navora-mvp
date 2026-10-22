---
id: ADM1
title: Pilot administration — members, qualifications and operating rules
author: po
status: approved
updated: 2026-10-22
---

# ADM1 — Pilot administration: members, qualifications and operating rules

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
