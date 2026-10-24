---
id: RLS2
title: Visit and case records are read only by the people who care for the client
author: po
status: approved
updated: 2026-10-24
---

# RLS2 — Visit and case records are read only by the people who care for the client

## Problem
0015 (ADR-031) narrowed clinical reads to the client's own team (D-3 option B). Four tables were left outside it and are readable by **every member of the organisation** through the table API (`lca` 2026-10-24 21:55, read, not tested; PO 21:10 for the first one):
- `visit_events` (0007:22-47): visit, team, event type, time, `actor_id`;
- `visit_time_corrections` (0008:19-44): corrected time, **free-text `reason`**, `actor_id`;
- `team_decisions` (0011:23-50): case, team, accept/decline, **free-text `reason`**, `actor_id`;
- `case_tasks` (0013:85-102): case, task kind (`gp_missing`, `inform_gp`, `access_unknown`, …), status, who closed it.

Consequences: (1) a free-text reason can carry health data and names ("Klientin gestürzt …"), and a nurse of another team can read it: more than the minimum by default (DSG Art. 7 Abs. 3) and a possible disclosure of a professional secret outside the treating team (`lca` D-3 21:55); (2) any member can reconstruct a colleague's working day from `actor_id` and times, which D-23 excludes (`lca` D-23 21:55; ArGV 3 Art. 26 as cited). `lca` finds D-3 option B with real data **not compliant under every plausible interpretation** until this is fixed; D-23 C plus D is compliant only with it. No screen reads these tables directly (`grep` over `src/`: no `from("…")` on any of the four); readers are `security definer` functions, so narrowing the table policies should change no screen. Nobody has listed every read path; the four were found one by one.

## Users and journey step
Every member (nurse, care assistant, coach, Operations, administrator) and every client. Steps: Team Decision, Planning, Visit, Documentation (`ARCHITECTURE.md` data flow). This is D-3 real-data gate (iv) and D-23 precondition 3 (a).

## Outcome
A member reads visit, correction, decision and task rows only for clients her team cares for (or the one visit she covers), and the organisation has one list that shows, for every path that returns client- or visit-linked rows, who can read it and which test proves it.

## Acceptance criteria
- [ ] **RLS2-1 Read-path inventory.** `docs/engineering/READ_PATHS.md` lists every table, view and function in `public` that `authenticated` can select or execute and that returns rows linked to a client, case or visit. Per path: the scope (row's team; covering member; coordination role and the named task that needs it; organisation-wide), whether free text is returned, and the pgTAP file and assertion that proves the scope. Paths that are organisation-wide are marked. A pgTAP assertion compares the inventory's table list with the catalogue (every `public` table with a `case_id`, `visit_id` or `client_id` column and a select grant to `authenticated` appears in a fixed list in the test), so a new table without a scope decision fails CI.
- [ ] **RLS2-2 The four tables are team-scoped (0015 pattern).** For `visit_events`, `visit_time_corrections`, `team_decisions` and `case_tasks`, a table-API read returns a row only to (a) an active member of the row's team (directly, or through the row's visit or case), (b) the covering member for a covered visit while her cover is active (the existing cover predicate), (c) Operations, coach or administrator of the organisation **only** where RLS2-1 names the task that needs it; otherwise none. pgTAP per table: a nurse of team A reads team A's row; a nurse of team B in the same organisation reads 0 rows of team A; a member of another organisation reads 0; `anon` reads 0; a covering member reads the covered visit's rows while the cover is active and 0 after it ends.
- [ ] **RLS2-3 Free-text reasons stay in the team.** `visit_time_corrections.reason` and `team_decisions.reason` are never returned outside (a) and (b) above, coordination roles included, through the table API (column revoke as in 0015:68) or through any function in RLS2-1, unless RLS2-1 names a task that needs the text; pgTAP for each.
- [ ] **RLS2-4 No per-person day for others.** No path in RLS2-1 returns another member's visit events or corrections aggregated per person (D-23 term b); a nurse can read her own. pgTAP: a member of the same team sees the visit's status times (care coordination) but no function returns a per-person total for a colleague.
- [ ] **RLS2-5 Other gaps.** Every further organisation-wide path RLS2-1 finds is narrowed in this PR with pgTAP, or, if narrowing would change a screen, listed in the inventory as a finding with a proposed change and an `eng-proposal` row; nothing is widened.
- [ ] **RLS2-6 No regression.** Every existing pgTAP, unit and e2e test stays green; no assertion removed or weakened; `/field`, `/team`, `/cases`, `/operations` and `/admin` show what they show today (existing e2e). AN1 and AN2 measures keep their values on the seed (pgTAP 057/058/059 unchanged).
- [ ] **RLS2-7 Negative cases.** A nurse cannot widen her scope by passing another team's `visit_id` or `case_id` to any function in RLS2-1 (pgTAP for each function that takes such an argument); a removed member reads nothing of her former team immediately after removal.

## Rules and their input class
One access rule: who may read a row, decided by team membership and cover (input class *visit/schedule fact*). No signal, threshold, priority or clinical content is added or changed. Not "for the adviser".

## Out of scope
- The read log (D-3 gate i), the DSFA (gate ii) and the cover-read field list (`clinical`, D-3 b).
- `member_profiles` display names (organisation-wide by design; staff names inside the employer, `lca` 21:55).
- The working-day proposal itself (D-23 C) and its information text (D-23 item 7 c).
- Any change to what coordination roles see on a screen; if one is needed, it is an RLS2-5 finding, not a change in this PR.

## Constraints and references
D-3 (option B, gates i-iv; `lca` 02:52, 06:55, 16:45, 21:55), D-23 (C plus D, terms a-e; `lca` 17:57, 21:55), ADR-031 / 0015, COVER1 (cover predicate), AN1 small-group suppression. DSG Art. 7 Abs. 3, StGB Art. 321 as cited by `lca` (advisory, not legal advice). **Clinical gate:** no clinical rule; `cra` is informed and may comment on whether any coordination-role task in RLS2-1 is a clinical need (D-27). Real data stays blocked by D-1, D-9, D-29 and the other gates regardless.

## Open questions for engineering
- Which coordination-role reads of these four tables are needed today (OPS1 exceptions, AN1/AN2, HAND1, ORD0 tasks)? Name them in RLS2-1; the PO accepts each named task or asks for a change.
- Whether the catalogue check in RLS2-1 is better keyed on column names or on an explicit list; either is acceptable if a new client-linked table without a scope decision fails CI.
- Estimate: one additive migration, about 30-40 pgTAP assertions, one inventory document.
