---
id: RLS3
title: Coordination roles and teammates read no more than their task needs
author: po
status: approved
updated: 2026-10-25
---

# RLS3 — Coordination roles and teammates read no more than their task needs

## Problem
RLS2 (accepted 2026-10-25 08:10 CET, #331, 0066) closed every **organisation-wide** client-linked read path and listed the remaining over-wide reads as findings F-1 to F-5 in `docs/engineering/READ_PATHS.md`. Three of them have no owner in any approved brief:
- **F-2:** coordination roles (admin, coach, Operations) read `visit_status_notes` (including the **whole free-text no-show and interruption note**), `cover_events` and `working_time_facts` row by row through the table API, for every team, because their policies copy the 0015 coordination clause. No screen does this (`READ_PATHS.md`: no `.from()` in `src/`). `lca` 2026-10-25 07:50: the larger free-text exposure of the open findings; with real data it is what D-3 gate (iv) forbids.
- **F-5:** `care_plan_items`, `case_lifecycle_events` and `cover_events` have no negative pgTAP case for a table-API read from another team; their scope is team "by reading" only. Gate (iv) asks for a pgTAP per path.
- **F-4:** inside the team, `visit_events.actor_id` and `visit_time_corrections.actor_id` are readable row by row, so a teammate can rebuild a colleague's working day through the table API (no function or screen does). Q13 tied this to the D-23 working-day proposal (C); `lca` 07:50 shows the exposure exists without C, because the events are written for care today. With real data it is **unresolved: needs the DSFA**; the protective route (revoke before the first real employee) is compliant under every plausible interpretation on the federal sources read.

F-1 is built by DOOR1-11; F-3 waits for D-4 or the DSFA (D-3 item 6 b). Neither is in this brief.

## Users and journey step
Every member (nurse, care assistant, coach, Operations, administrator) and every client. Steps: Visit, Documentation (`ARCHITECTURE.md` data flow). This completes D-3 real-data gate (iv) for F-2 and F-5 and adds F-4 as a real-data gate for employees (D-23 item 9).

## Outcome
No coordination role can read a nurse's visit status note, a cover event or a working-time fact of a team it does not belong to by querying the table, every client-linked table has a negative test, and no teammate can list which colleague recorded which visit event and when.

## Acceptance criteria
- [ ] **RLS3-1 F-2 narrowed.** The read policies of `visit_status_notes`, `cover_events` and `working_time_facts` return a row through the table API only to an active member of the row's team (directly or through its visit) and, for `visit_status_notes`, to the covering member while her cover runs (`private.reads_visit`, 0066); `cover_events` also to the nurse the event names (own row). No coordination role reads any row of a team it is not a member of. pgTAP per table: team A reads, team B of the same organisation reads 0, Operations, coach and administrator of the organisation read 0, another organisation 0, `anon` refused; covering member reads while the cover runs and 0 after it ends.
- [ ] **RLS3-2 Read models unchanged for their task.** `operations_exceptions()`, `uncovered_visits()`, `my_covers()`, `cover_offers()`, `team_visit_alerts()`, `field_visit_status_notes()` and the AN1/AN2 readers return the same rows and values on the seed as before (existing pgTAP 019, 042, 045, 057, 058, 059, 067 unchanged and green; OPS1 still raises a no-show and an interruption for Operations). If a read model loses a value it needs, it is fixed inside the read model, never by widening the table policy.
- [ ] **RLS3-3 F-5 tests.** pgTAP: a nurse of another team in the same organisation reads 0 rows of `care_plan_items`, `case_lifecycle_events` and `cover_events` of team A through the table API; a member of team A reads them. If a test finds a wider scope, the policy is narrowed in this PR.
- [ ] **RLS3-4 F-4 no per-person rows inside the team.** `actor_id` of `visit_events` and `visit_time_corrections` is not selectable by `authenticated` through the table API (column revoke). Every function that returns another member's identity together with a visit event or correction time is listed in `READ_PATHS.md` with the care task that needs it (for example the handover or the cover banner) and returns it per visit, never as a list or total per person (D-23 term b); a nurse still sees her own events. pgTAP: a teammate's table-API select of `actor_id` is refused; the function list is fixed in the test (a new reader fails CI). The PO accepts each named task at review or asks for a change.
- [ ] **RLS3-5 Inventory.** `READ_PATHS.md` updated: F-2, F-4, F-5 marked closed with their pgTAP; F-1 and F-3 still open with their route (DOOR1-11; D-4 or DSFA).
- [ ] **RLS3-6 No regression.** Every existing pgTAP, unit and e2e test green; no assertion removed or weakened (an assertion that encoded the removed scope is replaced by the narrower one and named in the status row); `/field`, `/team`, `/cases`, `/operations`, `/admin` show what they show today (existing e2e).

## Rules and their input class
One access rule: who may read a row or column, decided by team membership and cover (input class *visit/schedule fact*). No signal, threshold, priority or clinical content added or changed. Not "for the adviser".

## Out of scope
- F-1 (the note excerpt in `operations_exceptions()`): DOOR1-11.
- F-3 (`audit_events` free text for administrators): D-4 or the DSFA, D-3 item 6 (b).
- The read log, the DSFA, the cover-read field list (D-3 gates i, ii; D-3 b `clinical`).
- The D-23 working-day proposal (C) itself.
- Any change to what a screen shows; if one would be needed, it is a finding with a proposal, not a change.

## Constraints and references
D-3 (option B, gate iv; items 5-7), D-23 (C plus D, terms a-e; item 9), Q13 (decided by po 2026-10-25 08:10 CET), RLS2 / 0066 / ADR-080, `READ_PATHS.md`. `lca` 2026-10-25 07:50 (advisory, not legal advice): DSG Art. 6 Abs. 3, Art. 7 Abs. 3, ArGV 3 Art. 26 as cited. **Clinical gate:** no clinical rule; `cra` is informed and may say whether a coordination role has a clinical need for a note's text (D-27); if it does, the text goes through a named read model, not the table. Real data stays blocked by D-1, D-9, D-29 and the other gates regardless.

## Open questions for engineering
- Does any read model run as `security invoker` over these tables for a coordination role (then RLS3-1 would empty it)? Name it and move the read into a definer read model with its task.
- Which functions read `actor_id` today (`field_visits`, HAND1, the cover banner)? List them for RLS3-4.
- Estimate: one additive migration, about 30-40 pgTAP assertions, an inventory update.
