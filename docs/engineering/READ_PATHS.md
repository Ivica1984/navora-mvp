# Read-path inventory: client-, case- and visit-linked reads (RLS2-1)

**Owner:** Engineering (`eng`) · **Brief:** [`RLS2`](../agents/briefs/RLS2.md) · **ADR:** ADR-080 · **Migration:** 0066 · **Proof:** pgTAP `067_rls2_team_scoped_records` (127 assertions) · **State:** IMPLEMENTED on synthetic data (PR open; CI decides) · **Last change:** 2026-10-25 00:35 Europe/Zurich

Every table, view and function in schema `public` that the role `authenticated` can select or execute and that returns rows linked to a client, a case or a visit. In NAVORA the client is the case (`cases`); there is no `client_id` column.

## How the list is kept complete

pgTAP 067 compares this list with the database catalogue, so a new path without a scope decision fails CI:
- **Tables:** every `public` table or view with a `case_id`, `visit_id` or `client_id` column and any column `select` grant to `authenticated` must be in a fixed list in the test (22 tables today). `cases` and `care_visits` are the client and the visit themselves and are listed below as well.
- **Functions:** every `public` function that `authenticated` can execute and whose result has a `case_id`, `visit_id` or `client_id` column must be in a fixed list (24 functions today).
- **Views:** none is readable by `authenticated` (asserted). **RLS:** on for every readable table (asserted).
- **Readers of the four RLS2 tables:** the functions that read `visit_events` or `visit_time_corrections` and return a set are a fixed list (`field_visits`, `pilot_kpis`, `pilot_hypotheses`); the functions that read a `reason` together with those tables are a fixed list; no function reads `team_decisions.reason` (asserted).
- **Cross-team sweep:** every reader below is called by a registered nurse of another team in the same organisation and region (Mitte) and must return **no** row whose case, team or visit belongs to Nord (37 calls, 067). Positive controls show that Nord and Operations still see their rows.

A change that adds a path updates this file and the lists in 067 in the same PR.

## Scope vocabulary

| Scope | Meaning |
|---|---|
| **team** | an active member of the row's team, directly or through the row's visit (its team) or case (its assigned team). Membership is a row in `team_memberships`, deleted on removal, so a removed member reads nothing at once |
| **cover** | the covering member of a covered visit while the cover is active: `care_visits.covered_by` = her, still a member of the cover team and the organisation, and no `final` report yet (0066 `private.reads_visit`) |
| **coordination: \<task\>** | admin, coach or operations of the organisation, for the named task only |
| **own** | the caller's own rows (recipient, performer) |
| **organisation-wide** | every member of the organisation. Marked ⚠ |

"Proof" names the pgTAP file that shows the scope with a negative case. `067` is this PR. A file in *italics* was found by search and not re-read in this PR (UNKNOWN whether every role is covered there); the 067 sweep covers every function for the cross-team case.

## Tables (table API)

| Table | Scope (policy) | Free text returned | Proof |
|---|---|---|---|
| `visit_events` | team, cover (**was ⚠ organisation-wide, 0007**) | no | 067 |
| `visit_time_corrections` | team, cover (**was ⚠ organisation-wide, 0008**) | `reason` (team, cover only) | 067 |
| `team_decisions` | team (**was team + every coordination role, 0017**) | `reason` (deciding team only) | 067, 017 |
| `case_tasks` | team of the case (**was ⚠ organisation-wide, 0013**) | no | 067, 012 |
| `cases` | team; coordination: Operations case list and intake (`/operations`, `src/features/operations/queries.ts:36`). Health columns revoked for everyone (0015) | `notes` revoked | 015, *004* |
| `care_visits` | team; coordination: Operations visit list (`queries.ts:38`, `/visits`) | no | 015, *004* |
| `care_notes` | team; coordination: report status only (`content` revoked, 0015) | `content` revoked | 015 |
| `visit_reports` | team | `summary`, `snapshot` (team) | *016* |
| `visit_report_returns` | team: performer and the team's registered nurses | `reason` (same) | 066 |
| `visit_observations` | team | observation text (team) | *011*, *042* |
| `visit_plan_changes` | team | `reason` (team) | *030*, *050* |
| `care_plan_items` | team | `goal` (team) | UNKNOWN (no negative case found) → finding F-5 |
| `billable_facts` | team; coordination: intake role (billing preparation, J5) | no | *022* |
| `working_time_facts` | team; coordination: none on a screen | no | *042*, *043* → F-2 |
| `quality_events` | team; serious events: admin and coach (quality review, QG1) | `description`, `closing_note` (team; admin and coach for serious events) | 015, *020* |
| `quality_holds` | team; coordination: quality hold handling (`src/features/quality/queries.ts:37`) | `reason`, `lift_reason` | *020* |
| `case_gp_notices` | team of the notice or of the case; coordination: ORD0 doctor informed (`src/features/gp/queries.ts:13`) | no (date, channel, who recorded) | *063* |
| `case_lifecycle_events` | inherits `cases` (team; coordination) | `reason_code` only | UNKNOWN → F-5 |
| `visit_status_notes` | inherits `care_visits` (team; coordination) | `note` (no-show, interruption) | *042*, *045* → F-1, F-2 |
| `cover_events` | team of the visit; the nurse herself; coordination: none on a screen | no | UNKNOWN → F-2, F-5 |
| `safety_signals` | own: recipients of a delivery | `reason` code | 062 |
| `signal_deliveries` | own: recipient | no | 062 |
| `matching_requests` | coordination: intake and matching (J2) | `notes` | 015 |
| `partner_requests` (referral, no case column) | coordination: intake (`src/features/intake/queries.ts:49`) | referral fields | 015 |
| `match_candidates` (no case column) | coordination: matching | no | *015* |
| `audit_events` (entity-linked, no case column) | coordination: admin only, audit review | `changed` holds audited columns, incl. `quality_holds.reason` and signal reason codes | *005*, *063* → F-3 |

## Functions

| Function | Scope | Free text returned | Proof |
|---|---|---|---|
| `field_visits(date)` | team (INVOKER: joins the caller's `team_memberships`; reads the four tables under RLS) | correction `reason` (team) | 067, 008 |
| `field_notes(date)` | team (INVOKER) | note content (team) | 067 sweep |
| `field_quality(date)`, `field_since_last(date)`, `field_visit_status_notes(date)` | team | entries of the team's visits | 067 sweep, *033*, *042* |
| `field_reports(date)`, `field_countersign_queue()`, `field_returned_reports()`, `report_returns(visit)` | team; return reason only for performer and the team's RNs (F6R) | report text, return reason | 066, 067 |
| `team_cases()`, `team_case_lifecycle()`, `team_plan_status()`, `team_visit_alerts()`, `team_open_visits(date)` | team | open task **kinds** (no text) | 067 sweep, *014*, *038* |
| `my_covers()`, `cover_offers()` | own cover; offers without identity (COVER1) | no | 067 sweep, *028* |
| `my_signals()` | own deliveries | no | 067, 062 |
| `case_funding_facts(case)` | team of the case; coordination: intake (open task kinds) | no | 067 |
| `intake_cases()`, `linkable_cases(request)` | coordination: intake | no | 067, *034* |
| `operations_exceptions()` | coordination: OPS1 exception list | `detail`: generated text, **plus the first 120/200 characters of a no-show or interruption note** | 067 (OPS1 still raises after RLS2), *019* → F-1 |
| `ops_case_lifecycle()` | coordination: case lifecycle on `/operations` | `last_reason` code | *031* |
| `matching_escalations()` | coordination: J2 escalation | decline **code, team, time; the free-text reason was removed by 0066** | 067, 017 |
| `team_offers()` | team (offers without client identity) | no | *031*, *034* |
| `uncovered_visits()` | coordination: Operations; team of the visit (**was ⚠ organisation-wide, 0014**) | no | 067, 014 |
| `final_report_visits()`, `continuity_by_case(month)` | team; coordination | no | 067 sweep, *016*, *021* |
| `pilot_kpis(month)`, `pilot_hypotheses(month)` | team rows for members; organisation rows under AN1 suppression; coordination: pilot review | no; **no per-person column** (asserted, RLS2-4) | 067, 059 |
| `billing_preview(month)` | team; coordination | no | 067 sweep, *022* |

Commands (`correct_visit_time`, `complete_case_task`, `decide_matching_request`, …) return a result code, not rows. 067 checks that a nurse of another team cannot act on Nord's event or case task (RLS2-7).

## Findings (RLS2-5)

No further **organisation-wide** client-linked path remains (catalogue and sweep). The findings below are coordination-role paths; narrowing them would change a screen or needs a product answer, so they are proposals, not changes (eng-proposal **RLS3**, decision **Q13** for `po`):

| ID | Finding | Proposed change | Screen affected |
|---|---|---|---|
| F-1 | `operations_exceptions()` shows Operations the first 120 (no-show) or 200 (interruption) characters of the nurse's free-text note. The note can carry health data. `cra` 22:26: Operations must know *that* and *when*; it did not name the note | show the reason code and "Notiz im Team" instead of the text; the team keeps the note | `/operations` exception detail |
| F-2 | Coordination roles read `visit_status_notes` (note), `cover_events` and `working_time_facts` row by row through the table API, because their policies inherit or copy the 0015 coordination clause. No screen reads them directly; Operations uses the read models | narrow the three policies to team (+ cover for `visit_status_notes`), like 0066 | none known (no `.from()` in `src/`) |
| F-3 | `audit_events` is readable by the organisation's administrators for every team, including the audited `quality_holds.reason` text | part of the D-3 read log and D-4 access rules; keep until D-4 decides, then restrict the free-text columns | `/admin` audit view (if any) |
| F-4 | Inside the team, `visit_events.actor_id` and times are readable row by row; a teammate could rebuild a colleague's day from the table API (no function does, RLS2-4). D-23 term (b) | revoke `actor_id` on `visit_events` and `visit_time_corrections` from `authenticated` together with the D-23 working-day proposal (her own events through a read model) | none today |
| F-5 | No negative pgTAP case was found for `care_plan_items`, `case_lifecycle_events` and `cover_events` table reads (the policies are team-scoped by reading) | add the cross-team table-API case for them to the next PR that touches them | none |

## What this inventory does not cover

- The read log (D-3 gate i), the DSFA (gate ii), the cover-read field list (D-3 b, `clinical`).
- `member_profiles` and `teams` (organisation-wide by design; no client link).
- Schema `private` (not exposed by the Data API) and the service role.
- The live project `jwmfxrmougneeceldhsa` (contained, C-1). Nothing here was checked against it.
