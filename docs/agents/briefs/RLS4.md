---
id: RLS4
title: Who did what is read per record, never pulled as a list per colleague
author: po
status: approved
updated: 2026-10-29
---

# RLS4 — Who did what is read per record, never pulled as a list per colleague

## Problem
OBS1-C1 (#688, migration 0096, accepted as met 2026-10-29 23:20 CET) closed five authorship and signer columns to direct table selects. Its inventory (`docs/engineering/READ_PATHS.md`, *Remaining person-linked column grants*, OBS1-7 (c)) shows **19 care-record tables** whose person columns a team member can still select through the Data API and filter per colleague: who changed a plan, closed a task, set or lifted a billing hold, returned or withdrew a report, recorded a quality event, confirmed intake consent, and so on. Each row is legitimate where it is used (one visit, one case, one event); a filter "every act of colleague X" is not, and it is exactly what D-23 term (b) and G-18 exclude for a real employee (`lca` 16:05 reading for the analogous OBS1 columns: closing them like RLS3-4 is compliant under every plausible interpretation; leaving them open is unresolved). Until now such paths were found one brief at a time (RLS3-4, OBS1-7, AIG1-11). D-23 item 20 (4) says the PO decides on the inventory; this brief is that decision.

How we know: `READ_PATHS.md` inventory read from a database built from 0001-0096 (`eng`, ADR-119). The app reads none of the closed columns directly (`grep` of `src/` on `recovery/main` 1500cb3 by the PO, not tested): its table queries on `quality_holds`, `case_gp_notices`, `cases` and `care_visits` name their columns and do not include them.

## Users and journey step
Every team member and coordination role, across Case → Planning → Visit → Documentation → Quality → Billing (`ARCHITECTURE.md` data flow). No screen changes.

## Outcome
A nurse still sees, on the record she is working with, who did what (the handover, the report, the hold, the task); nobody can pull a list, count or filter of a colleague's acts from the database. The team keeps its shared record without it becoming a means of watching each other.

## Acceptance criteria
- [ ] **RLS4-1 Act-trail columns closed (RLS3-4 pattern, column grants; Engineering names the mechanism in the ADR).** `authenticated` gets `permission denied` (42501) on a direct select of each of these columns, and no table-wide select grant remains on their tables:
  `visit_reports.created_by`, `countersigned_by`, `withdrawn_by`; `visit_report_returns.returned_by`; `care_visits.suspended_by`; `cover_events.nurse_id`; `visit_plan_changes.actor_id`; `visit_status_notes.actor_id`; `working_time_facts.performer_id`; `care_plan_items.created_by`, `retired_by`; `case_tasks.done_by`; `case_lifecycle_events.actor_id`; `case_gp_notices.recorded_by`; `cases.intake_consent_confirmed_by`; `team_decisions.actor_id`; `quality_events.author_id`; `quality_event_log.actor_id`; `quality_holds.set_by`, `lifted_by`; `billable_facts.created_by`; `referral_links.actor_id`.
- [ ] **RLS4-2 Assignment columns stay selectable** (the team needs them to coordinate today's work, and they are already on every card): `care_visits.responsible_user_id`, `care_visits.covered_by`, `cases.primary_nurse_id`, `cases.deputy_nurse_id`, `quality_events.owner_id`, `visit_reports.performer_id`, `visit_report_returns.performer_id`, `safety_signals.taken_by` (recipient-scoped). pgTAP asserts they remain selectable for the row's team, so the boundary is explicit.
- [ ] **RLS4-3 Every current reader keeps working, each named.** Every function, policy, view and app query that reads an RLS4-1 column is listed in the ADR with its result (unaffected SECURITY DEFINER, or changed); an INVOKER reader moves to a private SECURITY DEFINER helper that answers per record and only for a person the table policy already admits (the `private.observation_authorship` pattern of 0096). Where a screen shows the person today, it still does, per record. pgTAP proves one positive per changed reader.
- [ ] **RLS4-4 No per-person read anywhere.** No function added or changed takes a person argument and returns acts of that person, and no reader returns rows of these tables grouped, counted or filtered by one of the RLS4-1 columns, for any role (own rows through existing `own` scopes stay as they are). pgTAP: a teammate cannot count a colleague's acts through the table API on any RLS4-1 table.
- [ ] **RLS4-5 `READ_PATHS.md`:** the RLS4-1 columns move from the inventory to *closed under RLS3-4*; the RLS4-2 columns are recorded as kept, with this brief as the reason; the *not care records* list stays an inventory. pgTAP 067 and 071 lists are updated by these columns only.
- [ ] **RLS4-6 Tests:** pgTAP 42501 for each RLS4-1 column as an active member of the row's team and as a coordination role; existing suites that read a closed column as `authenticated` move to the reader or to the table owner where they assert the stored value, with unchanged content assertions; app, db, e2e and ui-screenshots green on the PR head without any test skipped, retried or loosened.
- [ ] **RLS4-7 `lca` reads the PR before merge** (D-23 term (b), item 21) and states whether keeping the RLS4-2 columns selectable is compliant; if `lca` finds a kept column unresolved, Engineering closes it in the same PR the same way. No `cra` gate: no clinical content, no change to who may read a record.
- [ ] **Negative:** no RLS policy widened or narrowed by rows, no column added or dropped, no data changed, no screen text changed, no live project touched (D-1).

## Rules and their input class
No rule is added or changed. This narrows read grants only; no signal, threshold, gate or priority. No *clinical content*.

## Out of scope
- The *not care records* list (`audit_events`, `change_log`, `exception_events`, `exception_rule_overrides`, `response_deadlines`, `member_access_events`, …): coordination-role and administrative tables; a later decision once `lca` has read them.
- Hiding assignment (RLS4-2): a plan has to say who goes where. A colleague's visit list for a day remains visible to her team, as it is today.
- Any change to who may read a record, to AN1/AN2 measures, or to AIG1 (its confirmer columns are AIG1-11).

## Constraints and references
D-23 (`po-decided`, items 20 and 21), G-18 (before the first real employee), RLS3-4 (0070), OBS1-7 (0096, ADR-119), AIG1-11 (same principle for AI confirmations), `READ_PATHS.md`. Synthetic data only (owner rule 2026-10-29, D-1).

## Open questions for engineering
1. Is any RLS4-1 column read by an RLS policy or a view through the caller's grants (would a column revoke break a policy)? Name it in the ADR.
2. Do any of the 19 tables still carry an `authenticated` table-wide grant that a later migration relies on for `insert … returning *`? If so, how is `returning` kept working?

## PO notes
**2026-10-29 23:20 CET, approved (po, product authority under D-23).** Value 4 (team autonomy without mutual monitoring), precondition for value 3 and 7 (real employees in a scalable pilot). From scratch, a shared care record shows who did what on the entry and never offers a per-colleague query; the grant model should say so once, not table by table. Cost is low: the app reads none of these columns directly (UNKNOWN until RLS4-3 confirms). Placed in *Next up* after AIG1; gate **G-18**.
