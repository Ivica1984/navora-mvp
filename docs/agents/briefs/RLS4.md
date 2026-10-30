---
id: RLS4
title: Who did what is read per record, never listed per person; who is responsible stays visible to the team
author: po
status: approved
updated: 2026-10-29
---

# RLS4 — Acts per record, assignments to the team (OBS1-7 (c) inventory decided)

## Problem
OBS1-C1 (#688, 0096) closed five authorship and signer columns. Its inventory (`docs/engineering/READ_PATHS.md`, *Remaining person-linked column grants*, OBS1-7 (c)) lists 19 care-record tables where a team member can still select, row by row through the table API, a column naming a person, and filter or count it per person: who decided a team decision, who did a case task, who changed a plan, who wrote a quality event, whose working time a fact is, who created a billable fact. That is the same gap RLS3-4 and OBS1-7 closed for visit events and observations (D-23 term b: never a list or total per person). The PO decides on that list (OBS1-7 (c)); this brief is that decision.

## Users and journey step
Every team member and coordination role reading care records; no new screen. Cross-cutting (Visit, Documentation, Quality, Billing).

## Outcome
A column that records **who did an act** (decided, wrote, changed, completed, set, lifted, returned, countersigned, withdrew, created, recorded, confirmed, took) is read only per record through the record's existing reader, as RLS3-4. A column that records **who is responsible now** (an assignment the team must see to coordinate care) stays readable by the team. Nobody can list a colleague's acts through the Data API.

## Acceptance criteria
- [ ] **RLS4-1 Acts closed (RLS3-4 pattern).** `authenticated` has no direct select on these columns; each is read only through an existing SECURITY DEFINER reader or a per-record function, which the PR names: `visit_reports.created_by`, `countersigned_by`, `withdrawn_by`; `visit_report_returns.returned_by`; `care_visits.suspended_by`; `visit_plan_changes.actor_id`; `visit_status_notes.actor_id`; `working_time_facts.performer_id` (her own rows stay readable to her through her own reader, WORK1); `care_plan_items.created_by`, `retired_by`; `case_tasks.done_by`; `case_lifecycle_events.actor_id`; `case_gp_notices.recorded_by`; `cases.intake_consent_confirmed_by`; `team_decisions.actor_id`; `quality_events.author_id`; `quality_event_log.actor_id`; `quality_holds.set_by`, `lifted_by`; `billable_facts.created_by`; `safety_signals.taken_by`; `referral_links.actor_id`. Engineering chooses the mechanism (column grants as 0070, 0096) and states it in the ADR.
- [ ] **RLS4-2 Assignments stay readable to those who coordinate** (no change): `cases.primary_nurse_id`, `deputy_nurse_id` (J6); `care_visits.responsible_user_id`, `covered_by` (J3, COVER1); `cover_events.nurse_id` (COVER1); `visit_reports.performer_id` and `visit_report_returns.performer_id` (who must act on the report; F6R); `quality_events.owner_id` (who handles the event now). Each is listed in `READ_PATHS.md` with the task that needs it. If Engineering finds a column in RLS4-1 that a current screen reads as an assignment, or one in RLS4-2 that records an act, it names it in the ADR as a deviation for the PO instead of choosing.
- [ ] **RLS4-3 Every screen keeps working.** Each current reader of an RLS4-1 column (functions, views, app queries) is named in the PR and keeps its output; where the app reads one of these tables directly, it moves to a function returning the person per record. The record still shows "von <Name>" where it does today, per record.
- [ ] **RLS4-4 `READ_PATHS.md`.** The RLS4-1 columns move from the inventory to the closed list; the RLS4-2 columns are listed as accepted assignment reads with their task; the *Not care records* line is unchanged (administration and own rows, out of scope here).
- [ ] **Tests (synthetic seed only).** pgTAP: an active member of the record's team gets 42501 on a direct select of each RLS4-1 column; a `group by` on any of them is refused; each named reader still returns the person per record for her team; the RLS4-2 columns stay selectable by the team; the RLS3-4 catalogue test (071) is updated by these columns only; `anon` holds nothing on these tables. Existing pgTAP that selects an RLS4-1 column as `authenticated` moves to the reader with the same content asserted (OBS1-C1 pattern). CI e2e unchanged and green.
- [ ] **Negative.** No row read is widened or narrowed (RLS unchanged); no new per-person list, count or export for any role; no change to the live project (D-1).

## Rules and their input class
None. Access narrowing only; no clinical, legal or tariff rule.

## Out of scope
- The *Not care records* line of the inventory (audit, change log, exception and administration tables, own rows): coordination roles and administrators read those for their task; a later inventory decision if `lca` or `aia` finds a per-person use.
- Time columns next to these (`created_at`, `occurred_at`): they stay with the row; without the person column they do not identify an act's author.
- AIG1 confirmation columns (AIG1-11 closes them at build).

## Constraints and references
- OBS1-7 (c) inventory (`READ_PATHS.md`, 2026-10-29, #688), RLS3-4, ADR-083, ADR-119, D-23 term b (`lca` 2026-10-24, re-checked 16:05 for OBS1-7: most protective option), D-3, OR Art. 328b and ArGV 3 Art. 26 as cited by `lca` in D-23 (the PO does not interpret them).
- **Before G-18** (first real employee). Synthetic data only.
- `lca` reads the RLS4-2 keep-list in the PR before merge (does any listed assignment column enable a per-person evaluation the D-23 reading excludes?); advisory, as OBS1-6.

## Open questions for engineering
- Whether one migration can close all RLS4-1 columns with a generated column-grant list (as 0096), and which pgTAP files move.
- Whether `quality_events.author_id` must stay readable to the event's reader as a per-record "gemeldet von" (then through the QG1 reader, per record).

## PO notes
- **2026-10-29 23:15 CET, approved** (OBS1-7 (c): "the PO decides on that list"). **Why:** *Why can a teammate list who did what?* Because the tables were granted table-wide when the record was built, before RLS3-4 set the rule; nobody decided that a per-person list should exist. From scratch, accountability is per record (who stands behind this entry) and coordination needs only who is responsible now; a listable act history per colleague serves no care task and turns the shared record into mutual monitoring (value 4 team autonomy; employee privacy). The split *act vs. assignment* is the product rule; it keeps continuity (value 2: the team sees the primary nurse and the responsible member) and closes everything else.
- Not escalated: it narrows reads only, is reversible, and takes the protective option `lca` already found compliant for the same pattern (RLS3-4, OBS1-7). The `lca` read of the keep-list is the remaining check.
