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
- [ ] **RLS3-4b The correction trail stays visible to the people who sign and bill the visit** (added by the PO 2026-10-25 10:12 CET from `cra` 09:31, CGR-55, S2; **sharpened 2026-10-25 12:12 CET** from `lca` 11:50 in D-23 and D-3; product authority, narrows only, no clinical rule). After the revoke of RLS3-4, one listed per-visit reader returns the correction history of a visit. **Two levels, by who reads:** (a) **full trail** (corrector, time of the correction, old and new value, reason) to the report's author, its countersigning registered nurse (J5, CR-086), active members of the visit's team and the covering member while her cover runs (`private.reads_visit`, 0066); (b) **billing view** to everyone else who may read the visit's billable facts today (every coordination role through `teams_in_scope`, as `billing_preview` does, 0043/0015): that the visit has a correction, the old and new value, the time of the correction, and the signed version the fact is based on with its countersigner (already on the report), **but never the free-text reason and never the corrector's identity**. "The billing review" is not a named person yet (the billing role belongs to the licence holder's organisational policy, D-12); until it is, every reader outside the visit's team gets (b). Listed in `READ_PATHS.md` with both tasks. pgTAP: after the revoke, the countersigning RN of a visit still sees who corrected an event of that visit and why; an administrator, a coach and an Operations member of the organisation who are not in the visit's team receive the correction's old and new value and time from the reader but `reason` and the corrector are null or absent; no function in the fixed list of RLS3-4 returns `visit_time_corrections.reason` to anyone outside the visit's team and the covering member; a teammate's table-API select of `visit_time_corrections.actor_id` is refused; no reader returns corrections grouped or counted per person (D-23 term b).
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

**PO 2026-10-25 12:12 CET (RLS3-4b sharpened):** `lca` 11:50 (D-23 re-check points 3-4, D-3 re-check point 2; advisory, not legal advice) found RLS3-4b compliant for the author and the countersigner, but **unresolved** if "the billing review" means every coordination role with the reason and the corrector, because that reopens through a function the read 0066 removed (D-3 gate iv: "correction reasons: met"). It found the protective variant compliant under every plausible interpretation on the federal sources read: billing evidence under KVV Art. 59 Abs. 1 needs the corrected values, that and when a correction happened, and the signed version, not the reason or the corrector. The PO takes the protective variant as (b). **`cra` asked** in its next section whether (b) serves CGR-55's billing purpose; if it does not, CGR-55 names what billing needs beyond (b) and the PO decides again. Engineering builds (a) and (b) as written.

`cra` 2026-10-25 09:31 CET (open PR #358): no coordination role has a standing clinical need for the free text of a no-show or interruption note; a task-bound read (the clinically responsible person reviewing a quality event or a P1 that followed a no-show) belongs in a named, logged read model tied to that open event, never the table API; who holds it is UNKNOWN until G-1. RLS3-1 as written is clinically safe. CGR-55 → RLS3-4b.

## Open questions for engineering
- Does any read model run as `security invoker` over these tables for a coordination role (then RLS3-1 would empty it)? Name it and move the read into a definer read model with its task.
- Which functions read `actor_id` today (`field_visits`, HAND1, the cover banner)? List them for RLS3-4.
- Estimate: one additive migration, about 30-40 pgTAP assertions, an inventory update.
