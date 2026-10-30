# Read-path inventory: client-, case- and visit-linked reads (RLS2-1)

**Owner:** Engineering (`eng`) · **Briefs:** [`RLS2`](../agents/briefs/RLS2.md), [`RLS3`](../agents/briefs/RLS3.md) · **ADRs:** ADR-080, ADR-083 · **Migrations:** 0066, 0070 · **Proof:** pgTAP `067_rls2_team_scoped_records` (128 assertions), `071_rls3_task_scoped_reads` (88) · **State:** IMPLEMENTED on synthetic data: 0066 and 0070 merged (RLS3 #373 merged as 3d6e125, CI green); F-2, F-4, F-5 closed; F-1 closed (DOOR1-11, 0072 merged), F-3 **closed** (AUD1, 0077 merged as 7f23a3b, pgTAP 077) · **Last change:** 2026-10-30 03:40 Europe/Zurich (**RLS4, 0099, ADR-122, amended by RLS4-5/-6:** 25 act columns on 19 care-record tables closed under RLS3-4 (the inventory's 22 plus `cover_events.nurse_id` and both `performer_id`), read per record only; `care_visits.team_member_name` closed (legacy, `/visits` reads `responsible_user_id`); five assignment columns stay readable with their task; pgTAP 099, 071 catalogue line); earlier 2026-10-29 23:55 Europe/Zurich (**AIG1 part (a), 0097, ADR-120:** seven AIG1 tables without any app grant; readers `open_suggestions`, `value_provenance` (the confirmer per value, RLS3-4 list), `agent_correction_rates`, `agent_health`, `agent_stop_lookback`); earlier 2026-10-29 20:50 Europe/Zurich (**OBS1-C1 / OBS1-7, 0096, ADR-119:** `visit_reports.snapshot`, `signed_by`, `signed_at` and `visit_observations.author_id`, `recorded_at` closed under RLS3-4; inventory of the remaining person-linked select grants, section *Remaining person-linked column grants*, for the PO to decide); earlier 2026-10-26 17:50 Europe/Zurich (COND1-6, 0084: AUD1-M1, purpose `billing` reads `code` values only, also inside the team; AUD1-M2, the stale F-3 "in PR" lines corrected); earlier 2026-10-26 11:50 (COND1-1/-2, 0080: `field_door_notes` intake date, `field_safety_alert_history` (DOOR1-13), `field_quality.claim_ended`, OPS1 `take_access_ended` (LEAVE1-C4); F-1 row aligned (DOOR1-10)); earlier 2026-10-26 00:40 (AUD1: audit-log section, F-3 closed in PR, 0077). Earlier 2026-10-25 16:40 Europe/Zurich (FUP1-5; FUP1-3 `in_billed_version`, 0071, PR #383)

Every table, view and function in schema `public` that the role `authenticated` can select or execute and that returns rows linked to a client, a case or a visit. In NAVORA the client is the case (`cases`); there is no `client_id` column.

**LEAVE1 (0074, ADR-087, pgTAP 074):** every readable table also carries the restrictive policy `leave1_access_open`, and every SECURITY DEFINER read model listed here returns nothing to a person whose access ended. pgTAP 074 checks both across the whole catalogue, independently of this list.

**LEAVE1 part (b) (0075, ADR-088, pgTAP 075):** `field_countersign_queue()` also lists the open reports of a team member whose access ended (kind and the date of the end, never a reason); HAND1 (`field_since_last`) shows every team member who reads a client's visit the entry `performer_access_ended` (open-report kind and date). `field_reports` gains `performer_unavailable`, `performer_access_ended`. Two new read models carry no case, visit or client column, so they are outside 067's function list: `member_open_reports(user)` (kind, visit date, team; the organisation's administrators and the registered nurses of the report's team) and `team_open_reports()` (a registered nurse's team members with open reports: counts by kind, access-end date). pgTAP 075 asserts their scope (another team's nurse and another organisation see nothing) and that only these, the queue, HAND1 and `end_member_access` read the open-work helpers.

**WORK1 (0079, ADR-092, pgTAP 079):** the working-day tables `working_day_versions` and `working_time_notice_acks` hold no client, case or visit column; scope **own** (one permissive policy `user_id = auth.uid()` plus `leave1_access_open`). Readers: `my_working_day(date)` (own visit events at their effective time: latest F3 `visit_time_corrections.corrected_at`, else recorded; no person argument, no identifier, no correction reason or corrector in the result, only a `corrected` mark; WORK1-C4, 0081), `my_working_day_versions(date)`, `my_working_time_notice()`, the commands `confirm_working_day` and `export_working_month`, and `pilot_kpis` through `private.team_confirmed_care_share` (team ratio under AN1 suppression, never per person). pgTAP 079 fixes this reader list and checks, for five other people, that every readable table and read model shows the same before and after her actions. **COND1-5 (0083, ADR-096):** `working_day_exports` (who, organisation, month, when) has no privilege for any app role; it is read only by `private.unexported_working_days`, which `my_unexported_working_days()` (her own count, no person argument, null after her access end), `member_unexported_working_days(person)` (one number, only for an administrator of an organisation of hers via `private.leave1_org_for`; null for the team's RNs and everybody else) and the `end_member_access` result call. No reader returns a row id of `working_day_versions` or `working_day_exports`, and the count does not read `audit_events` (AUD1-1 catalogue unchanged).

## How the list is kept complete

pgTAP 067 compares this list with the database catalogue, so a new path without a scope decision fails CI:
- **Tables:** every `public` table or view with a `case_id`, `visit_id` or `client_id` column and any column `select` grant to `authenticated` must be in a fixed list in the test (22 tables today). `cases` and `care_visits` are the client and the visit themselves and are listed below as well.
- **Functions:** every `public` function that `authenticated` can execute and whose result has a `case_id`, `visit_id` or `client_id` column must be in a fixed list (28 functions today, with `field_door_notes` (0072), `field_safety_alerts` (0073) and `field_safety_alert_history` (0080) from DOOR1; the earlier "24" was stale).
- **Views:** none is readable by `authenticated` (asserted). **RLS:** on for every readable table (asserted).
- **Readers of the four RLS2 tables:** the functions that read `visit_events` or `visit_time_corrections` and return a set are a fixed list (`field_visits`, `pilot_kpis`, `pilot_hypotheses`, `visit_correction_history`); the functions that read a `reason` together with those tables are a fixed list; no function reads `team_decisions.reason` (asserted).
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
| `visit_events` | team, cover (**was ⚠ organisation-wide, 0007**); `actor_id` not selectable by `authenticated` (RLS3-4, 0070) | no | 067, 071 |
| `visit_time_corrections` | team, cover (**was ⚠ organisation-wide, 0008**); `actor_id` not selectable by `authenticated` (RLS3-4, 0070) | `reason` (team, cover only) | 067, 071 |
| `team_decisions` | team (**was team + every coordination role, 0017**); `actor_id` not selectable (RLS4, 0099) | `reason` (deciding team only) | 067, 017 |
| `case_tasks` | team of the case (**was ⚠ organisation-wide, 0013**); `done_by` not selectable (RLS4, 0099) | no | 067, 012 |
| `cases` | team; coordination: Operations case list and intake (`/operations`, `src/features/operations/queries.ts:33`). Health columns revoked for everyone (0015); `intake_consent_confirmed_by` not selectable (RLS4, 0099); `primary_nurse_id`, `deputy_nurse_id` stay (RLS4-2) | `notes` revoked | 015, *004* |
| `care_visits` | team; coordination: `/visits` (**COND2-3, ADR-101:** `/operations` no longer reads it; its unused visit list with the nurse's name was removed, IPA1-C1); `suspended_by` and the legacy `team_member_name` not selectable (RLS4, RLS4-6, 0099: `/visits` names the responsible member from `responsible_user_id`); `responsible_user_id`, `covered_by` stay (RLS4-2) | no | 015, *004* |
| `care_notes` | team; coordination: report status only (`content` revoked, 0015) | `content` revoked | 015 |
| `visit_reports` | team; `snapshot`, `signed_by`, `signed_at` **not selectable by `authenticated`** (RLS3-4, OBS1-7, 0096: column grants on every other column); read per visit only through `field_reports`, `field_countersign_queue`, `field_returned_reports`, `report_returns` and the commands; **since 0099 (RLS4, RLS4-5) also** `created_by`, `countersigned_by`, `withdrawn_by`, `performer_id` | `summary` (team); `snapshot` through the functions only | *016* (reads through `field_reports` since 0096), 096 |
| `visit_report_returns` | team: performer and the team's registered nurses; `returned_by`, `performer_id` not selectable (RLS4, RLS4-5, 0099; the policy still reads `performer_id`) | `reason` (same) | 066 |
| `visit_observations` | team; `author_qualification_recorded` (OBS1-1 marker, 0095), `author_id` and `recorded_at` (OBS1-7, 0096) not selectable by `authenticated` (column grants on the other ten columns); read per observation only through `field_notes` (via `private.observation_authorship`), HAND1 and the report snapshot | observation text (team) | *011*, *042*, 095, 096 |
| `visit_plan_changes` | team; `actor_id` not selectable (RLS4, 0099) | `reason` (team) | *030*, *050* |
| `care_plan_items` | team; `created_by`, `retired_by` not selectable (RLS4, 0099); `assessment_id` (ASM1-7, 0100) selectable | `goal` (team) | 071 (F-5 closed) |
| `assessment_records` (ASM1, 0100, ADR-123) | team of the case (`private.reads_case`); no coordination role; `assessor_id`, `entered_by` not selectable (RLS4 pattern; read per record through `team_case_assessments`) | `supersede_reason`, `period_*` as entered (team) | 100, 067 |
| `assessment_confirmations` (ASM1-5, 0100; no case column) | team of the record's case; `confirmed_by` not selectable | no | 100 |
| `care_plan_assessment_reviews` (ASM1-C4, 0101, ADR-125) | **nobody through the table** (no grant, no policy); the case's latest act (record, state at the act, date, reviewer's name) is read per case through `team_case_assessments` (`plan_review`) by the case's assigned team only | no | 101 |
| `assessment_instruments` (ASM1-6, 0100; no case column, no personal data) | every member of the organisation; `created_by`, `ended_by` not selectable | instrument name and version | 100 |
| `billable_facts` | team; coordination: intake role (billing preparation, J5); `created_by` not selectable (RLS4, 0099) | no | *022* |
| `working_time_facts` | team (**was team + every coordination role, 0022**; RLS3-1, 0070); `performer_id` not selectable (RLS4, 0099) | no | 071 (F-2 closed), *042*, *043* |
| `quality_events` | team; serious events: admin and coach (quality review, QG1); `author_id` not selectable (RLS4, 0099), `owner_id` stays (RLS4-2) | `description`, `closing_note` (team; admin and coach for serious events) | 015, *020* |
| `quality_holds` | team; coordination: quality hold handling (`src/features/quality/queries.ts:37`); `set_by`, `lifted_by` not selectable (RLS4, 0099) | `reason`, `lift_reason` | *020* |
| `case_gp_notices` | team of the notice or of the case; coordination: ORD0 doctor informed (`src/features/gp/queries.ts:13`) | no (date, channel; who recorded not selectable since RLS4, 0099) | *063* |
| `case_lifecycle_events` | inherits `cases` (team; coordination: case lifecycle on `/operations`); `actor_id` not selectable (RLS4, 0099) | `reason_code` only | 071 (F-5 closed: another team reads 0) |
| `visit_status_notes` | team, cover (**was team + every coordination role through `care_visits`, 0024**; RLS3-1, 0070); `actor_id` not selectable (RLS4, 0099) | `note` (no-show, interruption; team, cover) | 071 (F-2 closed), *042*, *045* |
| `cover_events` | team of the visit; own: the nurse the event names (**was also every coordination role, 0028**; RLS3-1, 0070); `nurse_id` not selectable (RLS4-5, 0099) | no | 071 (F-2, F-5 closed) |
| `safety_signals` | own: recipients of a delivery; `taken_by` not selectable (RLS4, 0099) | `reason` code | 062 |
| `signal_deliveries` | own: recipient | no | 062 |
| `matching_requests` | coordination: intake and matching (J2) | `notes` | 015 |
| `partner_requests` (referral, no case column) | coordination: intake (`src/features/intake/queries.ts:49`) | referral fields | 015 |
| `match_candidates` (no case column) | coordination: matching | no | *015* |
| `audit_events` (entity-linked, no case column) | **none through the table API (AUD1-2, 0077)**: administrators of the record's organisation read one record's rows through `read_audit_record(entity_type, entity_id, purpose)` | `changed`: free-text keys withheld unless the administrator is an active member of the record's team (AUD1-4; list below), and always for `billing` (AUD1-M1, 0084) | 077, 084, *005* (F-3 closed) |

## Functions

| Function | Scope | Free text returned | Proof |
|---|---|---|---|
| `field_visits(date)` | team (INVOKER: joins the caller's `team_memberships`; reads the four tables under RLS) | correction `reason` (team) | 067, 008 |
| `field_notes(date)` | team (INVOKER) | note content (team); since 0095 (**OBS1-2, ADR-118**) per observation the author's display name and the OBS1-1 marker (`private.observation_qualification_missing`, team members only). **RLS3-4 entry:** identity with an observation time, care task *authorship of a clinical entry (ZH GesG § 13, `lca` 13:57)*; per observation, never a list, count or filter per person | 067 sweep, 071 (RLS3-4 list), 095 |
| `field_quality(date)`, `field_since_last(date)`, `field_visit_status_notes(date)` | team | entries of the team's visits (`field_visit_status_notes` and HAND1 also the DOOR1 codes `at_door`, `disclosure_basis`, 0072); `field_quality` names who recorded an event, never its owner, and since 0080 marks an `in_review` event whose owner's access ended (`claim_ended`, LEAVE1-C4) | 067 sweep, *033*, *042*, 072 |
| `field_door_notes(date)` (DOOR1-1, 0072) | team + covering member while the cover runs (`private.reads_visit`) | `cases.access_notes`, `cases.language_notes` of the visit's case; since 0080 (DOOR1-13) also the case's intake date (`intake_on`). The intake note never holds a code (DOOR1-12, write guard on every writer, 0080) | 072 (team A yes; team B, other organisation, no-membership account, Operations, administrator, cover after it ended: nothing; anon: no execute), 067 list |
| `field_safety_alerts(date)` (DOOR1-3/-4, 0073) | team + covering member while the cover runs (`private.reads_visit`); the table `case_safety_alert_values` has no grant to `anon` or `authenticated` | the latest safety-alert value per active category of the visit's case: value, note (<= 300, no code), source, who, when | 073 (team A yes; team B, other organisation, no-membership account, Operations, administrator, cover after it ended: nothing; anon: no execute; table: permission denied), 067 list |
| `field_safety_alert_history(date)` (DOOR1-13, 0080) | team + covering member while the cover runs (`private.reads_visit`), the same readers as the card; nothing to a person whose access ended (LEAVE1-3) | every recorded value of the access arrangement of the day's cases (value, note <= 300 without a code, source, who, when; newest first), then the intake note `cases.access_notes` as the earliest entry (`source` `referral`, `from_intake`); shown as the history of the one "Zugang" line once a value exists | 080 (team yes; Operations, leaver: nothing), 067 list, 072/073 catalogue |
| `field_reports(date)`, `field_countersign_queue()`, `field_returned_reports()`, `report_returns(visit)` | team; return reason only for performer and the team's RNs (F6R) | report text, return reason; since 0095 (**OBS1-3**) a new snapshot names per observation its author (id, display name at the time) and the OBS1-1 marker, task *authorship of a clinical entry (ZH GesG § 13, `lca` 13:57)*; signed snapshots unchanged. **Closed by OBS1-7 (0096, ADR-119; `lca` 16:05):** `visit_reports.snapshot`, `signed_by`, `signed_at` are no longer selectable through the table API, so author and marker in snapshots, and signer with signing time, are read only per visit through these functions (all SECURITY DEFINER) | 066, 067, 095, 096 |
| `team_cases()`, `team_case_lifecycle()`, `team_plan_status()`, `team_visit_alerts()`, `team_open_visits(date)` | team | open task **kinds** (no text); `team_cases` since 0088 (**COND2-4, ADR-102**) also the case's urgency source and, since COND2-4a, the requested start of **this return's** request (code, date; null when that request had none), only while the case's `review_after_pause` task is open | 067 sweep, *014*, *038*, 088 (team member and care assistant yes; nurse of another team, Operations: nothing) |
| `my_covers()`, `cover_offers()` | own cover; offers without identity (COVER1) | no | 067 sweep, *028* |
| `my_signals()` | own deliveries | no | 067, 062 |
| `case_funding_facts(case)` | team of the case; coordination: intake (open task kinds) | no | 067 |
| `intake_cases()`, `linkable_cases(request)` | coordination: intake | no | 067, *034* |
| `operations_exceptions()` | coordination: OPS1 exception list | `detail`: generated text only. **DOOR1-11 (0072, merged):** a no-show line is codes only (`private.no_show_ops_detail`: time, "an der Tür", "Ergebnis offen" or outcome with basis and time, "Notiz im Team"); an interruption line keeps its reason label and says "Notiz im Team"; no note text. **LEAVE1-C4 (0080):** a take whose taker's access has ended reads as untaken (no `owner_name`, no `taken_at`, flag `take_access_ended`); the same in `team_visit_alerts()` | 067 (OPS1 still raises after RLS2), *019*, 072 → F-1 |
| `ops_case_lifecycle()` | coordination: case lifecycle on `/operations` | `last_reason` code | *031* |
| `matching_escalations()` | coordination: J2 escalation | decline **code, team, time; the free-text reason was removed by 0066** | 067, 017 |
| `team_offers()` | team (offers without client identity) | no | *031*, *034* |
| `uncovered_visits()` | coordination: Operations; team of the visit (**was ⚠ organisation-wide, 0014**) | no | 067, 014 |
| `visits_outside_watched_hours(own_teams)` | administrators: their organisation (`/admin`); `/team` (own teams flag) and every other member: her own teams (SIGC, SIG2-C1 (2), 0068); date, times and team only | no | 067 sweep, 069 |
| `team_case_assessments()` (ASM1, 0100, ADR-123) | members of the case's assigned team (LEAVE1-3 guard); nobody else | per record: instrument, the assessor's display name and `assessor_is_me` (never who entered it), state, reference, minutes with period, supersede reason; per case: plan basis date, marker date, dated facts (kind, date). No list, count or filter per person | 100, 067 sweep |
| `final_report_visits()`, `continuity_by_case(month)` | team; coordination | no | 067 sweep, *016*, *021* |
| `pilot_kpis(month)`, `pilot_hypotheses(month)` | team rows for members; organisation rows under AN1 suppression; coordination: pilot review | no; **no per-person column** (asserted, RLS2-4) | 067, 059 |
| `billing_preview(month)` | team; coordination | no | 067 sweep, *022* |
| `visit_correction_history(visit)` | (a) full trail: team, cover, the report's author or countersigner while in the visit's team or cover team; (b) billing view: every other coordination role of the organisation (as `billing_preview`). Per visit, never per person (RLS3-4b, 0070) | `reason` and corrector: (a) only; (b) gets old and new value, time, signed version and countersigner; both levels get `in_billed_version` per correction (FUP1-3, 0071: made at or before the countersignature, or signature, of the billed version; null without a fact) | 071 |

Commands (`correct_visit_time`, `complete_case_task`, `decide_matching_request`, …) return a result code, not rows. 067 checks that a nurse of another team cannot act on Nord's event or case task (RLS2-7).

**AIG1 (0097, ADR-120; pgTAP 097, 071).** No AIG1 table (`ai_agent_definitions`, `ai_agent_settings`, `ai_agent_stops`, `ai_agent_fields`, `ai_one_by_one_fields`, `ai_suggestions`, `ai_confirmations`) has any grant for `authenticated` or `anon`; RLS is on without a policy. Readers, all SECURITY DEFINER with the LEAVE1-3 guard:

| Function | Scope | Person returned | Proof |
|---|---|---|---|
| `open_suggestions(team)` | active members of the team | the proposed member's name (the proposal itself), never a confirmer | 097 |
| `value_provenance(entity_type, entity_id, field)` | active members of the record's team | the confirmer of **one** value ("bestätigt von <Name> am <Datum>"), with that value's status; at most one row (AIG1-11 (2a)) | 097, 071 |
| `agent_correction_rates(month)` | team: own rows; coordinators: all teams of the organisation | none; per agent, field, team and month; a cell with fewer than three distinct confirmers is suppressed (AIG1-7) | 097 |
| `agent_health(org)` | coordinators of the organisation | none (AIG1-10; AIG1-16 adds the written threshold and a per-agent "minimum reached" flag, no person column) | 097, 103 |
| `agent_stop_lookback(stop)` | coordinators: every line; team members: lines of their teams' records | none; no outcome column (AIG1-12 (i)-(iv)); `superseded`, `superseded_at` per record (AIG1-13 (b)) | 097 |

Commands (`set_agent_state`, `propose_visit_responsible`, `confirm_suggestion`, `confirm_suggestions`) return result codes. The confirmer is otherwise read only per record through `read_audit_record('ai_confirmations', id, purpose)` (AUD1).

**VIS1-8 (0090, ADR-112):** `visit_move_leaves_other_visit(visit)` returns one boolean (no rows, no `case_id`/`visit_id` column), to a team member of the visit only (null otherwise): whether another visit of the same case, of any team and not cancelled, is on the visit's date. It shows no time, team, name or count of that visit; no new read permission. Care task: the "Heute machen" confirmation states what the move leaves behind (`cra` CGR-89).

**VIS2-1/-2 (0098, ADR-121):** `client_visit_overlap(case, visit, date, start, end)` returns `{overlap, time_start, time_end}` or null: to a team member of the visit (visit given, the visit excluded) or a member of the case's assigned team (case given, `reads_case`), null for anyone else. `overlap` counts every other visit of the case on that date, any team, not cancelled, whose planned interval meets the half-open slot; `time_start`/`time_end` are only those of the earliest overlapping visit the caller can read (`reads_visit`), so another team's visit shows no time, team, member, service or count. No new read permission; `private.client_overlap_visits` is not executable by app roles. The three commands' `ok` result carries the same object (VIS2-5). Care task: the planning, /team move and "Heute machen" confirmations (VIS2-1).

## Findings (RLS2-5)

No further **organisation-wide** client-linked path remains (catalogue and sweep). The findings below are coordination-role paths; narrowing them would change a screen or needs a product answer, so they were proposals (eng-proposal **RLS3**, decision **Q13** decided by `po` 2026-10-25 08:10). State after RLS3 (0070): F-2, F-4, F-5 closed. F-1 closed by DOOR1-11 (0072); F-3 closed by AUD1 (0077):

| ID | Finding | Proposed change | Screen affected |
|---|---|---|---|
| F-1 — **CLOSED (DOOR1-11, 0072 merged, pgTAP 072)**: route DOOR1-11 | `operations_exceptions()` shows Operations the first 120 (no-show) or 200 (interruption) characters of the nurse's free-text note. The note can carry health data. `cra` 22:26: Operations must know *that* and *when*; it did not name the note | show the reason code and "Notiz im Team" instead of the text; the team keeps the note | `/operations` exception detail |
| F-2 — **CLOSED** by RLS3-1 (0070, pgTAP 071) | Coordination roles read `visit_status_notes` (note), `cover_events` and `working_time_facts` row by row through the table API, because their policies inherit or copy the 0015 coordination clause. No screen reads them directly; Operations uses the read models | narrow the three policies to team (+ cover for `visit_status_notes`), like 0066 | none known (no `.from()` in `src/`) |
| F-3 — **CLOSED** (AUD1, 0077, pgTAP 077; merged as 7f23a3b, CI green): route AUD1 (D-3 item 6 b, D-4 gate r3) | `audit_events` was readable by the organisation's administrators for every team, including the audited `quality_holds.reason` text | policy dropped; one purpose reader per record (`compliance`, `billing`, `safety_review`), free text only inside the team and never for `billing` (AUD1-M1, 0084), every read recorded in `audit_read_log` | none (no screen read the log) |
| F-4 — **CLOSED** by RLS3-4 (0070, pgTAP 071; column revoke before the first real employee, Q13) | Inside the team, `visit_events.actor_id` and times are readable row by row; a teammate could rebuild a colleague's day from the table API (no function does, RLS2-4). D-23 term (b) | revoke `actor_id` on `visit_events` and `visit_time_corrections` from `authenticated` together with the D-23 working-day proposal (her own events through a read model) | none today |
| F-5 — **CLOSED** by RLS3-3 (pgTAP 071; no policy needed narrowing) | No negative pgTAP case was found for `care_plan_items`, `case_lifecycle_events` and `cover_events` table reads (the policies are team-scoped by reading) | add the cross-team table-API case for them to the next PR that touches them | none |

## Audit log: free text and readers (AUD1-1)

**State:** IMPLEMENTED (migration 0077 merged as 7f23a3b, ADR-090, pgTAP 077; AUD1-M1 by 0084, ADR-097, pgTAP 084). The value catalogue `private.audit_value_classes` classifies every key of `audit_events.changed` per audited table as `code` or `free_text`; pgTAP 077 fails when a column the audit trigger records is not in it, when the free-text list changes, or when a text column the app can write freely is classed `code`. A key that is not in the catalogue (a direct writer adding a new key) is withheld for every reader (fail closed).

**Audited free text** (withheld by `read_audit_record` unless the administrator is an active member of the record's team, and always for purpose `billing` (AUD1-M1, 0084); records without a team in `private.audit_record_team` are withheld for everyone):

| Table · key | Written by | Team of the record |
|---|---|---|
| `quality_holds.reason` | `set_quality_hold` (3–500 characters; may describe health) | `quality_holds.team_id` |
| `quality_holds.lift_reason` | `lift_quality_hold` (3–500 characters) | `quality_holds.team_id` |
| `teams.coach_name` | `assign_team_coach` | the team |
| `teams.name`, `teams.region` | `create_team`, `update_team` (`private.audit_command`) | the team |
| `cases.region` | intake (2–80 characters) | `cases.assigned_team_id` |
| `matching_requests.region` | copied from the case | `matching_requests.selected_team_id` |
| `partner_requests.region` | intake | none (withheld) |
| `member_profiles.display_name` | the member (2–80 characters) | none (withheld) |
| `member_invitations.email` | the administrator | none (withheld) |

Every other audited key is a code: a closed value set (CHECK or foreign key), a number, date, time, id or flag, or a status only commands set (no column grant to app roles; `care_visits.status` only through the 0004 state machine). Not free text in the log: notes, care notes, observation text, `visit_status_notes.note`, `case_safety_alert_values.note`, `change_log.reason`, `visit_plan_changes.reason` are not audited columns; their reasons stay in team-scoped tables.

**Functions that read `audit_events`** (all SECURITY DEFINER; pgTAP 077 fixes the list):

| Function | Task | Returns free text from `changed`? |
|---|---|---|
| `private.begin_command` | idempotency: did this user apply this key | no (boolean) |
| `private.handover_entries` (HAND1, `field_since_last`) | team handover: care-plan schedule change, primary-nurse change, medical-order status and validity | no (codes, dates, member codes; reasons from `change_log`) |
| `private.last_primary_nurse` (RET1) | the last primary nurse of a closed case | no (id) |
| `private.case_order_as_of` (CSR1, CGR-33) | the medical order as of the visit date | no (status code, date) |
| `public.pilot_hypotheses` (AN2) | absence end moved (CGR-35) | no (time) |
| `public.read_audit_record` (AUD1-3) | administrators: one record, for `compliance`, `billing` or `safety_review` | only inside the team (AUD1-4) |

Writers only (no read): `private.write_audit_event`, `private.write_audit_delete`, `private.audit_visit_plan_move`, `private.audit_command`, `set_member_qualification`, `plan_from_care_plan`, `set_auto_planning`, `private.adm1_reset_out_of_range_overrides`, `private.write_visit_refusal` (VIS1, ADR-111: one refusal row, outcome code only). The answer to the brief's question: no definer function returns free text from `changed` to a coordination role. `org_admins_read_audit` was used by no fixture or script outside pgTAP (`scripts/db-concurrency` deletes rows as the database owner).

**Read record (AUD1-5):** `public.audit_read_log` (append-only, no app grant): reader, time, organisation (null when nothing was returned), entity type and id, purpose code, rows returned. `org_audit_read_log(organisation)` returns an administrator her organisation's rows, never a count or rank per reader. Not the D-3 gate (i) read log and not the DSV Art. 4 log. D-4 gate (r3) met by this; r1 (client extract) and r2 (retention class per audited column) stay open.

## Identity with event or correction times (RLS3-4)

`actor_id` of `visit_events` and `visit_time_corrections` is not selectable through the table API (0070). **Since 0096 (OBS1-7, ADR-119; pgTAP 096) also closed:** `visit_reports.snapshot`, `visit_reports.signed_by`, `visit_reports.signed_at`, `visit_observations.author_id`, `visit_observations.recorded_at` (and since 0095 `visit_observations.author_qualification_recorded`). A member of the visit's team gets `permission denied` (42501) on a direct select of each; `select *` on either table is refused. The OBS1-5 "never as a list, count or filter per person" now holds for the snapshot, the signer and the observation author too, not only for the marker column. **Since 0099 (RLS4, ADR-122; pgTAP 099) also closed:** 25 act columns of 19 care-record tables, with their per-record readers in the section *Remaining person-linked column grants* below; 071 fails when a member can select any person column on those tables other than the five RLS4-2 assignments. These are the only functions that return another member's identity together with a visit event or correction time; each returns it **per visit**, never as a list or total per person (D-23 term b). pgTAP 071 derives the list from the catalogue and fails on a new one. The PO accepts each task at review.

| Function | Identity returned | Care task | Who |
|---|---|---|---|
| `field_reports(date)` | signer, countersigner, returner (names), with the report snapshot (event times, correction reason) | J5: sign and countersign the visit report; F6R return | team |
| `report_returns(visit)` | returner (name), with the returned snapshot | F6R: correct a returned report | performer and the team's registered nurses |
| `visit_correction_history(visit)` | corrector (name), (a) only | RLS3-4b: the people who sign the visit see who corrected it and why; billing (b) sees values and times only | (a) team, cover, author, countersigner; (b) coordination roles |
| `value_provenance(entity_type, entity_id, field)` | confirmer (name) of **one** proposed value, with its status (AIG1-11, 0097) | AIG1-3: "vorgeschlagen von <Agent> / bestätigt von <Name> am <Datum>" on the record line; never a list, count or filter per person. **Closed under RLS3-4 (0097):** `ai_confirmations.confirmed_by`, `outcome`, `confirmed_at` (no table grant at all); the only other reader is `read_audit_record` (one record, stated purpose). pgTAP 071 fails on a new function that returns a confirmer | active members of the record's team |

## Remaining person-linked column grants (OBS1-7 (c) inventory 2026-10-29; care records decided by RLS4, 0099)

The inventory of 2026-10-29 (0001-0096) listed every remaining **select** grant to `authenticated` on a column that names a person. The PO decided the care-record part as **RLS4** (brief `RLS4.md`, ADR-122): an **act** column (who decided, wrote, changed, completed, set, lifted, returned, countersigned, withdrew, created, recorded, confirmed, took) is closed; an **assignment** column (who is responsible now) stays readable to the people who coordinate. Time columns next to these (`created_at`, `occurred_at`, `…_at`) stay selectable wherever the row is.

**Closed by RLS4 (0099, pgTAP 099 and the 071 catalogue line).** `authenticated` has no select on these 25 columns (the brief's 22 and, by RLS4-5, the last three rows); a member of the record's team gets 42501 on a direct select, a filter, a `group by` or `select *`. Every reader is SECURITY DEFINER and reads as the table owner, unchanged. "Per record" names the readers that return the person to a member, one record at a time; "inside commands" means no reader returns the person (commands, guards, billing or the AN1/AN2 team aggregates read it as owner).

| Column | Returned per record by | Otherwise read (as owner) by |
|---|---|---|
| `visit_reports.created_by` | none | `create_report_draft`, `correct_report`, `return_report`, `private.build_billable_fact`, `private.billable_fact_follow_hold` |
| `visit_reports.countersigned_by` | `field_reports` (`countersigned_by_name`), `visit_correction_history` (`fact_countersigned_by_name`) | `countersign_report` |
| `visit_reports.withdrawn_by` | none | `withdraw_report_correction`, `pilot_hypotheses` (team aggregate) |
| `visit_report_returns.returned_by` | `field_reports`, `field_returned_reports`, `report_returns` (`returned_by_name`) | `return_report` |
| `care_visits.suspended_by` | none | `pause_case`, `resume_case`, `link_returning_referral` |
| `visit_plan_changes.actor_id` | `field_since_last` (HAND1 `author` code), `team_cases` (`own` flag only) | the planning and cover commands, `private.generate_case_plan`, `pilot_kpis`, `pilot_hypotheses` (team aggregates) |
| `visit_status_notes.actor_id` | `field_visit_status_notes` (`actor_name`), `field_since_last` | the no-show, interruption and end commands, `operations_exceptions`, `pilot_hypotheses` |
| `working_time_facts.performer_id` | none (no screen reads the table; her working day is read through WORK1 `my_working_day`) | `private.build_billable_fact` |
| `care_plan_items.created_by`, `retired_by` | `field_since_last` | `add_care_plan_item`, `retire_care_plan_item` |
| `case_tasks.done_by` | none | `complete_case_task`, `record_gp_informed`, `private.sync_case_tasks` |
| `case_lifecycle_events.actor_id` | `field_since_last` | `close_case`, `pause_case`, `resume_case`, `reopen_case`, `link_returning_referral` |
| `case_gp_notices.recorded_by` | `field_since_last` | `record_gp_informed`, `pilot_hypotheses` |
| `cases.intake_consent_confirmed_by` | none | `convert_partner_request`, `link_returning_referral` |
| `team_decisions.actor_id` | none | `decide_matching_request`, `pilot_kpis` |
| `quality_events.author_id` | `field_quality` (`person_name`, "gemeldet von", per event of the day), `field_since_last` | `record_quality_event` |
| `quality_event_log.actor_id` | none | `set_quality_event_status` |
| `quality_holds.set_by` | `field_quality` (`person_name`, per hold) | `set_quality_hold`, `record_quality_event` |
| `quality_holds.lifted_by` | none | `lift_quality_hold` |
| `billable_facts.created_by` | none | `private.build_billable_fact` and the rederive helpers |
| `safety_signals.taken_by` | none ("übernommen von" comes from `signal_takes` through `my_signals`, per signal, unchanged) | `take_signal` |
| `referral_links.actor_id` | none | `link_returning_referral`, `team_cases`, `pilot_kpis` |
| `cover_events.nurse_id` (RLS4-5) | none (who covers now: `care_visits.covered_by`; a hand-back shows per visit in `field_since_last` as the `moved` plan change with its reason) | `accept_cover`, `withdraw_cover` (`pilot_kpis` reads `cover_events` for `visit_id`, `kind` and `created_at` only, never `nurse_id`; RLS4-5 (c), pgTAP 099) |
| `visit_reports.performer_id` (RLS4-5) | `field_reports` (`i_am_performer`, `performer_unavailable`), `field_countersign_queue` (`performer_name`, to the team's registered nurses), `field_returned_reports` (her own) | the report commands, `private.open_reports_of`, `private.build_billable_fact`, `visit_correction_history` |
| `visit_report_returns.performer_id` (RLS4-5) | `report_returns` (rows for the performer and the team's RNs), `field_returned_reports` | `return_report`, `private.visit_open_return_performer`; the table's own policy |

**Legacy, closed (RLS4-6, 0099):** `care_visits.team_member_name` (free-text nurse name from before J3) is not selectable and not read or written by the app; `/visits` shows "Pflegekraft: <Name>" from `responsible_user_id` and `member_profiles` ("Noch offen" without, "Teammitglied" without a display name). Not dropped until the D-1 live reconciliation.

**Existing per-person paths (LEAVE1, unchanged, pinned by pgTAP 099):** `member_open_reports(user)` and the command `remove_team_member` take a person and read her open reports (kind, visit date, team) for the access-end handover. ADR-122 deviation 4 (OPEN, PO).

**Accepted assignment reads (RLS4-2, unchanged).** `lca` read the keep-list on #715 at 02:45 (D-23, advisory): these five are compliant under every plausible interpretation; the three it flagged moved to RLS4-1 (RLS4-5).

| Column | Task that needs it | Rows limited by |
|---|---|---|
| `cases.primary_nurse_id`, `deputy_nurse_id` | J6: the team sees who carries the case and who stands in | `scoped_read`: team or coordination role |
| `care_visits.responsible_user_id` | J3: who does the visit | `scoped_read`: team or coordination role |
| `care_visits.covered_by` | COVER1: who covers the visit now (also the `cover` scope of `private.reads_visit`) | as above |
| `quality_events.owner_id` | QG1: who handles the event now | `scoped_read`: team, or administrator and coach for serious events |

**Not care records (people, administration, own rows), for completeness:** `audit_events.actor_id` (✓, no permissive policy since AUD1: 0 rows), `change_log.actor_id` (✓, coordination roles), `exception_events.actor_id` (✓, coordination roles), `exception_rule_overrides.updated_by` (✓, coordination roles), `response_deadlines.updated_by` (✓, coordination roles), `member_access_events.actor_id, user_id` (✓, administrator or self), `member_contract_events.actor_id, user_id` (✓, administrator or self), `member_invitations.invited_by` (✓, administrators), `member_profiles.user_id, updated_by` (✓, organisation), `organization_memberships.user_id` (✓, own), `organization_push_settings.updated_by` (cols, organisation), `push_subscriptions.user_id` (cols, own), `team_memberships.user_id` (✓, team, coordination roles, own), `member_absences.user_id, recorded_by` (cols, team), `working_day_versions.user_id` (✓, own), `working_time_notice_acks.user_id` (✓, own).

## What this inventory does not cover

- The read log (D-3 gate i), the DSFA (gate ii), the cover-read field list (D-3 b, `clinical`).
- `member_profiles` and `teams` (organisation-wide by design; no client link).
- Schema `private` (not exposed by the Data API) and the service role.
- The live project `jwmfxrmougneeceldhsa` (contained, C-1). Nothing here was checked against it.
