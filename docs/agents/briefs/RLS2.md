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

## PO review 2026-10-25 08:10 CET: accepted

**Delivered in:** PR #331 (migration 0066, ADR-080, pgTAP 067 with 127 assertions, `docs/engineering/READ_PATHS.md`), merged 2026-10-25 07:11 CET as c1703a0. **CI:** `app`, `db`, `e2e` green on the PR head bb3ed48, on the merge commit c1703a0 and on `recovery/main` 8b099fa. **The PO did not run the tests;** the evidence below is the merged code and tests read by the PO plus the CI results. **Clinical gate:** no clinical rule; `cra` 05:30 CET (on bb3ed48): no blocking finding on RLS2. `lca` 07:50 CET re-checked D-3 gate (iv) and D-23 against the merged code (advisory).

| Criterion | Result | Evidence |
|---|---|---|
| RLS2-1 Read-path inventory with catalogue check | met | `READ_PATHS.md`: 22 tables, 24 functions, scope, free text and proof per path; organisation-wide paths marked (none left). pgTAP 067 compares the catalogue with fixed lists (tables with `case_id`/`visit_id`/`client_id` and a select grant; functions with such a result column), asserts no view is readable by `authenticated` and RLS is on everywhere; a new path without a scope decision fails CI |
| RLS2-2 Four tables team-scoped | met | 0066 policies via `private.reads_visit` / `private.reads_case`; 067: team A reads, team B of the same organisation 0, other organisation 0 (`admin_b`), `anon` refused (42501) on all four, covering member reads while the cover runs and 0 after withdrawal, after leaving the cover team and once the report is final |
| RLS2-3 Free-text reasons stay in the team | met | no coordination role reads the four tables through the table API (067; 017 test 42 now asserts 0); `matching_escalations()` returns code, team and time without `reason` (067, also through `private.matching_escalations_for`); fixed list of functions that read a `reason` with these tables; no function reads `team_decisions.reason` (asserted) |
| RLS2-4 No per-person day for others | met | the functions reading `visit_events`/`visit_time_corrections` and returning a set are a fixed list (`field_visits`, `pilot_kpis`, `pilot_hypotheses`); no per-person column in the pilot readers (asserted); a care assistant of the team sees the visit's status times in `field_visits` (067) |
| RLS2-5 Other gaps | met | `uncovered_visits()` narrowed from organisation-wide to coordination roles and the visit's team (067: Operations 1, team 1, other team 0); remaining coordination-role and in-team reads listed as findings F-1 to F-5 with an `eng-proposal` row (RLS3, Q13); nothing widened |
| RLS2-6 No regression | met | CI green (all pgTAP, unit, e2e); OPS1 and `my_signals` still raise a no-show and an overdue visit after the narrowing (067, `cra` 22:26 request); pgTAP 057/058/059 not changed by the PR (`git diff c1703a0^1 c1703a0`). Two existing files changed, see deviation 2 |
| RLS2-7 Negative cases | met | 067: a nurse of Mitte passing Nord's `visit_id`/`case_id` gets 0 rows or a refusal from `case_funding_facts`, `report_returns`, `linkable_cases`, `correct_visit_time`, `complete_case_task`; sweep of 37 reader calls returns no Nord row to Mitte, with positive controls; a removed member reads 0 rows of all four tables immediately after removal |

**Deviations (decided):**
1. `team_decisions` was team plus coordination roles since 0017, not organisation-wide as the brief said: **accepted**; the brief's problem statement was wrong in that detail, the outcome is the same (deciding team only).
2. pgTAP 017 test 42 (coordination roles read every decision) now asserts 0 rows; 012 tests 16 and 23 read `case_tasks` as the table owner, Operations' view is checked through `case_funding_facts` (067): **accepted**. The old assertions encoded the scope this brief removes; the intake behaviour they check is still asserted, and no assertion was dropped.
3. The covering read also ends when the visit's report is final (D-3, PO 2026-10-22 14:30): **accepted**, narrower than the brief.
4. No column grant changed; the row scope keeps the reasons in the team and `field_visits` (invoker) reads them for the own team: **accepted**, RLS2-3 is met by the row scope (the brief named the column revoke as one way, not the required one).

**Why accepted:** the four organisation-wide tables, the one organisation-wide function and the free-text decline reason no longer leave the team, and the catalogue check stops the next gap from being found one by one. That is D-3 real-data gate (iv) for these paths and D-23 precondition 3 (a). It changes no screen, so it costs the nurse nothing.

**Not part of this acceptance (follow-up, approved as brief RLS3, *Next up* 3):** F-2 (three tables row-readable by coordination roles, including the whole no-show and interruption note), F-5 (missing negative pgTAP for three tables) and F-4 (`actor_id` row reads inside the team, moved before the first real employee). F-1 rides with DOOR1-11, F-3 with D-4 or the DSFA. Gate (iv) is therefore **not yet met** for real data (`lca` 07:50).
