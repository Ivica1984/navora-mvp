-- AN2 part 3 (`docs/agents/briefs/AN2.md`, measures 1, 2, 4, 8 with AN2-M8a, 10; ADR-071). Completes the section
-- "Pilot-Hypothesen" of 0057 (ADR-070). Read-only for product data: no command, visit, alert or record changes. The one
-- new object is an internal marker table for AN2-M8a.
--
-- `public.pilot_hypotheses(p_month)` is re-created with the same signature, access rule (AN1), suppression rule
-- (`private.pilot_team_people`, `private.pilot_org_suppressed`), period (visits dated in the month) and every measure of
-- 0057 unchanged. Added measures and their event sources:
--   1  uncovered_taken_by_team_share     The responsible member over time from `visit_plan_changes` (`released`,
--      uncovered_hours_to_take           `taken`, `returned`; before the first change: its `before`, else today's value).
--                                        A `visit_uncovered` / `visit_uncovered_hospital` exception (0019, kept after the
--                                        start by 0038 PS-2) starts at the first moment inside its window (planned start
--                                        minus the effective threshold) at which the planned visit has nobody responsible;
--                                        it ends with the next change of the responsible member. Counted as "taken by the
--                                        team" when that change is a `taken` ("Offen im Team", ABS1) and no `take` or
--                                        `close` in `exception_events` on the exception's key came before it (the same
--                                        definition as AN1 `cover_without_operations`). Median hours start → take.
--   2  followup_without_visit_share      `visit_status_notes` kind `interruption_followup` (0045), code
--      followup_decision_minutes         `follow_up_planned`: share with no visit of the same case created within 48 h
--                                        after the decision (`visit_plan_changes` `planned`, or a new `care_visits` row);
--                                        decisions younger than 48 h without such a visit are not judged yet. Median
--                                        minutes from the `interrupted` event to the decision (every decision code).
--   4  late_moves_per_100                `visit_plan_changes` `moved`, and `released`/`taken`/`returned` that change the
--      late_responsible_changes_per_100  responsible member, made less than 24 h before the planned start as it stood at
--                                        the change (the row's `before` slot), per 100 visits of the month.
--   8  absences_per_100                  `member_absences` starting in the month (Europe/Zurich date) per 100 visits;
--      absences_by_colleague_share       recorded by a colleague; of those, withdrawn by the member herself; shortened
--      absences_withdrawn_by_member_share (audit of `ends_at`) or withdrawn within 48 h of recording, or followed within
--      absences_revised_share            48 h by a new absence of the same member adjacent to or overlapping the first
--      absences_start_yesterday_share    recorded period; start = the day before recording (ABS1-C6); start earlier than
--      absences_start_before_yesterday   that (command path only). Team rows count the team's rows; the organisation
--      absence_past_visits_per_100       row counts an absence once (`absence_group`, ABS1-C3).
--      absence_past_visit_end (detail)   Past planned visits flagged by CGR-32 when the absence was recorded (planned
--                                        then, dated before the recording day, naming her, interval inside the absence as
--                                        first recorded; a later move's `before` slot is the slot of that time) per 100
--                                        absences, and how each ended first: `started_late`, `cancelled` (stored CGR-34
--                                        mark), `cancelled_without_mark`, `moved` (stored CGR-35 mark), `moved_before_capture`
--                                        (AN2-M8a: "vor Erfassung (nicht gezählt)", never "nicht abwesend"), `still_open`,
--                                        `other`.
--  10  overdue_ended_by_command_share    `visit_overdue` (0038: planned start + effective threshold, while planned) and
--      overdue_closed_by_hand_share      `visit_stuck` (one per status change into on the way, started or paused; key
--      stuck_ended_by_command_share      `visit_stuck:<visit>:<event>`): ended by the next visit event (a command) or
--      stuck_closed_by_hand_share        closed by hand first (`exception_events` `close` on the key). Base = every such
--                                        exception in the period, also those still open.
-- Thresholds are read as they are now (`private.effective_exception_rules`), as in 0057; none is invented (D-28).
-- Known limits (ADR-071): historical suspension and cover state are not replayed for measure 1; a visit removed from the
-- plan is gone from every measure (its history row stays); measure 8's flag uses today's responsible member.

-- AN2-M8a: when the CGR-35 column began to be filled. 0056 recorded no time; the earliest of "now" (this migration) and
-- the first stored `true` is a safe lower bound: a move before it is shown as "vor Erfassung (nicht gezählt)".
create table if not exists private.an2_capture_starts (
  capture    text primary key,
  started_at timestamptz not null
);
alter table private.an2_capture_starts enable row level security;
revoke all on private.an2_capture_starts from public, anon, authenticated;
comment on table private.an2_capture_starts is
  'AN2-M8a (ADR-071): from when a stored fact is captured; earlier events are shown as "vor Erfassung (nicht gezählt)".';
insert into private.an2_capture_starts (capture, started_at)
select 'visit_plan_changes.responsible_absent',
       least(now(), coalesce((select min(pc.changed_at) from public.visit_plan_changes pc where pc.responsible_absent), now()))
on conflict (capture) do nothing;

create or replace function public.pilot_hypotheses(p_month date)
returns table (organization_id uuid, team_id uuid, team_name text, measure text, detail text,
               value numeric, base integer, too_few boolean, suppressed boolean, note text)
language sql stable security definer set search_path = ''
as $$
  with params as (
    select date_trunc('month', p_month)::date as m0, (date_trunc('month', p_month) + interval '1 month')::date as m1
  ), my_orgs as (
    select o.organization_id, private.is_coordinator(o.organization_id) as coordinator
    from public.organization_memberships o where o.user_id = (select auth.uid())
  ), my_teams as (
    select t.id, t.organization_id, t.name from public.teams t join my_orgs o on o.organization_id = t.organization_id
    where o.coordinator or private.is_team_member(t.id)
  ), people as (
    select tp.team_id, tp.people
    from my_orgs o, params p, lateral private.pilot_team_people(o.organization_id, p.m0, p.m1) tp
  ), org_hidden as (
    select o.organization_id, private.pilot_org_suppressed(o.organization_id, p.m0, p.m1) as hidden
    from my_orgs o, params p where o.coordinator
  ),
  -- The month's visits of the teams the caller may see -------------------------------------------------------------
  visits as (
    select v.id, v.organization_id, v.team_id, v.case_id, v.status, v.visit_date, v.time_start, v.time_end, v.created_at,
           v.responsible_user_id
    from public.care_visits v, params p
    where v.visit_date >= p.m0 and v.visit_date < p.m1 and v.team_id in (select id from my_teams)
  ),
  -- 3. Coordinator ends (CGR-26 'coordination': admin/coach/operations of the organisation, not in the visit's team) -
  ends as (
    select v.organization_id, v.team_id,
           exists (select 1 from public.organization_memberships om
                   where om.organization_id = v.organization_id and om.user_id = e.actor_id
                     and om.role in ('admin', 'coach', 'operations'))
           and not exists (select 1 from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = e.actor_id)
             as by_coordination
    from visits v
    join public.visit_events e on e.visit_id = v.id and e.event_type = 'interrupted' and e.from_status in ('started', 'paused')
  ), m3 as (
    select x.organization_id, x.team_id, 'coordinator_ends'::text as measure, null::text as detail,
           (count(*) filter (where x.by_coordination))::numeric as value, count(*)::int as base
    from ends x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
  ),
  -- 5. Correction rounds -----------------------------------------------------------------------------------------------
  first_signed as (
    select r.id, r.visit_id, v.organization_id, v.team_id,
           (select count(*) from public.visit_reports c where c.visit_id = r.visit_id and c.supersedes_id is not null) as corrections
    from public.visit_reports r join visits v on v.id = r.visit_id
    where r.supersedes_id is null and r.signed_at is not null
  ), corrections as (
    select c.id, c.status, c.signed_at, c.created_at, c.withdrawn_at, c.countersigned_at, c.visit_id,
           v.organization_id, v.team_id, s.signed_at as previous_signed_at,
           private.report_snapshot_hash(c.snapshot) = private.report_snapshot_hash(s.snapshot)
             and c.summary is not distinct from s.summary as unchanged
    from public.visit_reports c
    join public.visit_reports s on s.id = c.supersedes_id
    join visits v on v.id = c.visit_id
  ), m5 as (
    select f.organization_id, f.team_id, 'correction_versions_per_100'::text as measure, null::text as detail,
           round(100.0 * sum(f.corrections) / count(*), 1) as value, count(*)::int as base
    from first_signed f group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
    union all
    select c.organization_id, c.team_id, 'correction_minutes_after_signature', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (c.created_at - c.previous_signed_at)) / 60))::numeric, 0),
           count(*)::int
    from corrections c where c.previous_signed_at is not null
    group by grouping sets ((c.organization_id, c.team_id), (c.organization_id))
    union all
    select c.organization_id, c.team_id, 'correction_unchanged_share', null,
           round(100.0 * count(*) filter (where c.unchanged) / count(*), 1), count(*)::int
    from corrections c where c.signed_at is not null
    group by grouping sets ((c.organization_id, c.team_id), (c.organization_id))
  ),
  -- 6. Open corrections (report_correction_open, 0047: report_not_final threshold, ends with final or withdrawal) ------
  signals as (
    select c.organization_id, c.team_id, s.started_at,
           case when c.status = 'final' then coalesce(c.countersigned_at, c.signed_at)
                when c.status = 'withdrawn' then c.withdrawn_at end as ended_at,
           c.status
    from corrections c
    cross join lateral (
      select private.after_threshold(c.created_at, r.amount, r.unit) as started_at
      from private.effective_exception_rules(c.organization_id) r where r.exception_type = 'report_not_final') s
  ), raised as (
    select * from signals g
    where g.started_at <= now() and (g.ended_at is null or g.ended_at > g.started_at)
  ), m6 as (
    -- value: corrections that raised the signal; base: all correction versions of the month's visits
    select g.organization_id, g.team_id, 'correction_open_signals'::text as measure, null::text as detail,
           (count(*) filter (where g.started_at <= now() and (g.ended_at is null or g.ended_at > g.started_at)))::numeric as value,
           count(*)::int as base
    from signals g group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
    union all
    select g.organization_id, g.team_id, 'correction_open_hours', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (g.ended_at - g.started_at)) / 3600))::numeric, 1),
           count(*)::int
    from raised g where g.ended_at is not null
    group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
    union all
    select g.organization_id, g.team_id, 'correction_open_withdrawn_share', null,
           round(100.0 * count(*) filter (where g.status = 'withdrawn') / count(*), 1), count(*)::int
    from raised g where g.ended_at is not null
    group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
    union all
    select g.organization_id, g.team_id, 'correction_open_signed_share', null,
           round(100.0 * count(*) filter (where g.status = 'final') / count(*), 1), count(*)::int
    from raised g where g.ended_at is not null
    group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
  ),
  -- 7. Not-billable facts (AN2-M7: below_minimum on its own row, never in the total) -----------------------------------
  facts as (
    select f.id, f.visit_id, f.organization_id, f.team_id, f.billable, f.reasons, f.created_at, f.cause
    from public.billable_facts f join visits v on v.id = f.visit_id
  ), not_billable as (
    select f.*, f.reasons <@ array['below_minimum']::text[] and cardinality(f.reasons) > 0 as only_below_minimum,
           (select min(l.created_at) from public.billable_facts l
            where l.visit_id = f.visit_id and l.billable and l.created_at > f.created_at) as billable_at
    from facts f where not f.billable
  ), nb_totals as (
    select nb.organization_id, nb.team_id, count(*) as n
    from not_billable nb group by grouping sets ((nb.organization_id, nb.team_id), (nb.organization_id))
  ), nb_reasons as (
    select nb.organization_id, nb.team_id, coalesce(r.code, 'none') as code, count(*) as n
    from not_billable nb
    left join lateral unnest(nullif(nb.reasons, '{}'::text[])) r(code) on true
    group by grouping sets ((nb.organization_id, nb.team_id, coalesce(r.code, 'none')), (nb.organization_id, coalesce(r.code, 'none')))
  ), m7 as (
    select f.organization_id, f.team_id, 'not_billable_facts'::text as measure, null::text as detail,
           (count(*) filter (where not f.billable and not coalesce(nb.only_below_minimum, false)))::numeric as value,
           count(*)::int as base
    from facts f left join not_billable nb on nb.id = f.id
    group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
    union all
    select r.organization_id, r.team_id, 'not_billable_reason', r.code, r.n::numeric, coalesce(t.n, 0)::int
    from nb_reasons r
    left join nb_totals t on t.organization_id = r.organization_id and t.team_id is not distinct from r.team_id
    union all
    select nb.organization_id, nb.team_id, 'not_billable_days_to_billable', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (nb.billable_at - nb.created_at)) / 86400))::numeric, 1),
           count(*)::int
    from not_billable nb where nb.billable_at is not null and not nb.only_below_minimum
    group by grouping sets ((nb.organization_id, nb.team_id), (nb.organization_id))
  ),
  -- 9. Long or fragmented visits (CGR-23) ------------------------------------------------------------------------------
  started_visits as (
    select v.organization_id, v.team_id,
           (select count(*) from public.visit_events e where e.visit_id = v.id and e.event_type = 'paused') as pauses,
           (select min(e.occurred_at) from public.visit_events e where e.visit_id = v.id and e.event_type = 'started') as started_at,
           (select max(e.occurred_at) from public.visit_events e
            where e.visit_id = v.id and e.event_type in ('completed', 'interrupted')) as ended_at,
           case when v.time_end is not null then
             (v.visit_date + v.time_end + case when v.time_end < v.time_start then interval '1 day' else interval '0' end)
               at time zone 'Europe/Zurich' end as planned_end,
           (select private.after_threshold(private.after_threshold(
                     (v.visit_date + v.time_end + case when v.time_end < v.time_start then interval '1 day' else interval '0' end)
                       at time zone 'Europe/Zurich', r.amount, r.unit), r.escalate_to_p1_after_hours, 'hours')
            from private.effective_exception_rules(v.organization_id) r where r.exception_type = 'visit_stuck') as p1_at
    from visits v
    where exists (select 1 from public.visit_events e where e.visit_id = v.id and e.event_type = 'started')
  ), m9 as (
    select s.organization_id, s.team_id, 'visits_many_pauses'::text as measure, null::text as detail,
           (count(*) filter (where s.pauses > 2))::numeric as value, count(*)::int as base
    from started_visits s group by grouping sets ((s.organization_id, s.team_id), (s.organization_id))
    union all
    select s.organization_id, s.team_id, 'visits_open_past_p1', null,
           (count(*) filter (where coalesce(s.ended_at, now()) > s.p1_at))::numeric, count(*)::int
    from started_visits s where s.p1_at is not null
    group by grouping sets ((s.organization_id, s.team_id), (s.organization_id))
  ),
  -- 11. Quality holds ------------------------------------------------------------------------------------------------
  holds as (
    select h.set_at, h.lifted_at, v.organization_id, v.team_id
    from public.quality_holds h join visits v on v.id = h.visit_id
  ), m11 as (
    select h.organization_id, h.team_id, 'hold_lift_hours'::text as measure, null::text as detail,
           round((percentile_cont(0.5) within group (order by extract(epoch from (h.lifted_at - h.set_at)) / 3600))::numeric, 1),
           count(*)::int
    from holds h where h.lifted_at is not null
    group by grouping sets ((h.organization_id, h.team_id), (h.organization_id))
    union all
    select h.organization_id, h.team_id, 'holds_still_open', null,
           (count(*) filter (where h.lifted_at is null))::numeric, count(*)::int
    from holds h group by grouping sets ((h.organization_id, h.team_id), (h.organization_id))
  ),
  -- 12. Late billing facts -------------------------------------------------------------------------------------------
  report_facts as (
    select f.organization_id, f.team_id, f.created_at,
           (select max(coalesce(lc.corrected_at, e.occurred_at)) from public.visit_events e
              left join lateral (select x.corrected_at from public.visit_time_corrections x where x.event_id = e.id
                                 order by x.created_at desc, x.id desc limit 1) lc on true
            where e.visit_id = f.visit_id and e.event_type = 'completed') as ended_at
    from facts f where f.cause = 'report'
  ), m12 as (
    select r.organization_id, r.team_id, 'late_report_facts_share'::text as measure, null::text as detail,
           round(100.0 * count(*) filter (where r.created_at > r.ended_at + interval '24 hours') / count(*), 1),
           count(*)::int
    from report_facts r where r.ended_at is not null
    group by grouping sets ((r.organization_id, r.team_id), (r.organization_id))
    union all
    select f.organization_id, f.team_id, 'basis_changed_per_100', null,
           round(100.0 * count(*) filter (where f.cause = 'basis_changed') / count(*), 1), count(*)::int
    from facts f group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
  ),
  -- 1. Uncovered visits taken by the team (ABS1 "Offen im Team") --------------------------------------------------------
  -- The responsible member over time: at creation (the `before` of the first change, or today's value when nothing
  -- changed it), then after every logged change of it (released, taken, returned).
  resp_changes as (
    select pc.id, pc.visit_id, pc.change, pc.changed_at,
           (pc.before ->> 'responsible_id')::uuid as before_resp, (pc.after ->> 'responsible_id')::uuid as after_resp
    from public.visit_plan_changes pc join visits v on v.id = pc.visit_id
    where pc.change in ('released', 'taken', 'returned')
  ), resp_points as (
    select v.id as visit_id, v.created_at as at, 0::bigint as seq, null::text as change,
           case when exists (select 1 from resp_changes r where r.visit_id = v.id)
                then (select r.before_resp from resp_changes r where r.visit_id = v.id order by r.changed_at, r.id limit 1)
                else v.responsible_user_id end as resp
    from visits v
    union all
    select r.visit_id, r.changed_at, r.id, r.change, r.after_resp from resp_changes r
  ), resp_segments as (
    select p.visit_id, p.at as seg_from, p.resp,
           lead(p.at) over w as seg_until, lead(p.change) over w as next_change
    from resp_points p
    window w as (partition by p.visit_id order by p.at, p.seq)
  ), uncovered_base as (
    -- The exception's window opens at the planned start minus the effective threshold (0019, PS-2 in 0038: it stays
    -- after the start while the visit is planned and nobody is responsible).
    select v.id, v.organization_id, v.team_id, w.start_at,
           w.start_at - (private.after_threshold(w.start_at, r.amount, r.unit) - w.start_at) as window_from,
           (select min(e.occurred_at) from public.visit_events e where e.visit_id = v.id) as exit_at
    from visits v
    cross join lateral (select private.visit_start_at(v.visit_date, v.time_start) as start_at) w
    left join lateral (select x.referral_type from public.matching_requests x where x.case_id = v.case_id
                       order by x.created_at desc limit 1) mr on true
    join lateral (select er.amount, er.unit from private.effective_exception_rules(v.organization_id) er
                  where er.exception_type = case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital'
                                                 else 'visit_uncovered' end) r on true
  ), uncovered as (
    -- One exception per visit: the first moment inside the window at which the visit was planned with nobody
    -- responsible. It ended with the next change of the responsible member.
    select b.organization_id, b.team_id, b.id, s.since, s.seg_until as ended_at,
           s.next_change = 'taken'
           and not exists (select 1 from public.exception_events ev
                           where ev.organization_id = b.organization_id and ev.kind in ('take', 'close')
                             and ev.exception_key in ('visit_uncovered:' || b.id, 'visit_uncovered_hospital:' || b.id)
                             and ev.created_at < s.seg_until) as by_team
    from uncovered_base b
    cross join lateral (
      select greatest(g.seg_from, b.window_from) as since, g.seg_until, g.next_change
      from resp_segments g
      where g.visit_id = b.id and g.resp is null
        and coalesce(g.seg_until, 'infinity'::timestamptz) > b.window_from
        and greatest(g.seg_from, b.window_from) < least(coalesce(b.exit_at, 'infinity'::timestamptz), now())
      order by g.seg_from limit 1) s
  ), m1 as (
    select u.organization_id, u.team_id, 'uncovered_taken_by_team_share'::text as measure, null::text as detail,
           round(100.0 * count(*) filter (where u.by_team) / count(*), 1) as value, count(*)::int as base
    from uncovered u group by grouping sets ((u.organization_id, u.team_id), (u.organization_id))
    union all
    select u.organization_id, u.team_id, 'uncovered_hours_to_take', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (u.ended_at - u.since)) / 3600))::numeric, 1),
           count(*)::int
    from uncovered u where u.by_team
    group by grouping sets ((u.organization_id, u.team_id), (u.organization_id))
  ),
  -- 2. Follow-up after an interrupted visit (0045 decision) ------------------------------------------------------------
  followups as (
    select v.organization_id, v.team_id, v.case_id, n.reason_code, n.created_at as decided_at,
           (select max(e.occurred_at) from public.visit_events e where e.visit_id = v.id and e.event_type = 'interrupted') as ended_at,
           exists (select 1 from public.visit_plan_changes pc
                   where pc.case_id = v.case_id and pc.change = 'planned'
                     and pc.changed_at >= n.created_at and pc.changed_at <= n.created_at + interval '48 hours')
           or exists (select 1 from public.care_visits x
                      where x.case_id = v.case_id and x.id <> v.id
                        and x.created_at >= n.created_at and x.created_at <= n.created_at + interval '48 hours') as visit_planned
    from visits v
    join public.visit_status_notes n on n.visit_id = v.id and n.kind = 'interruption_followup'
  ), m2 as (
    -- Only decisions whose 48 h have passed, or that already have a planned visit, can be judged.
    select f.organization_id, f.team_id, 'followup_without_visit_share'::text as measure, null::text as detail,
           round(100.0 * count(*) filter (where not f.visit_planned) / count(*), 1) as value, count(*)::int as base
    from followups f
    where f.reason_code = 'follow_up_planned' and (f.visit_planned or f.decided_at + interval '48 hours' <= now())
    group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
    union all
    select f.organization_id, f.team_id, 'followup_decision_minutes', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (f.decided_at - f.ended_at)) / 60))::numeric, 0),
           count(*)::int
    from followups f where f.ended_at is not null
    group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
  ),
  -- 4. Single visits given away by hand: moves and changes of the responsible member less than 24 h before the start
  -- as planned at the moment of the change (the change's `before` slot) --------------------------------------------
  late_changes as (
    select pc.visit_id, pc.change,
           pc.changed_at >= private.visit_start_at((pc.before ->> 'date')::date, (pc.before ->> 'start')::time) - interval '24 hours'
           and pc.changed_at < private.visit_start_at((pc.before ->> 'date')::date, (pc.before ->> 'start')::time) as late,
           (pc.before ->> 'responsible_id') is distinct from (pc.after ->> 'responsible_id') as resp_changed
    from public.visit_plan_changes pc join visits v on v.id = pc.visit_id
    where pc.change in ('moved', 'released', 'taken', 'returned') and pc.before ? 'date'
  ), visit_late as (
    select v.organization_id, v.team_id,
           (select count(*) from late_changes l where l.visit_id = v.id and l.late and l.change = 'moved') as moves,
           (select count(*) from late_changes l where l.visit_id = v.id and l.late and l.change <> 'moved' and l.resp_changed) as handovers
    from visits v
  ), m4 as (
    select x.organization_id, x.team_id, 'late_moves_per_100'::text as measure, null::text as detail,
           round(100.0 * sum(x.moves) / count(*), 1) as value, count(*)::int as base
    from visit_late x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
    union all
    select x.organization_id, x.team_id, 'late_responsible_changes_per_100', null,
           round(100.0 * sum(x.handovers) / count(*), 1), count(*)::int
    from visit_late x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
  ),
  -- 8. Absences (ABS1): absences starting in the month (Europe/Zurich date). A team row counts the team's absence rows;
  -- the organisation row counts each absence once (ABS1-C3 `absence_group`). No person, reason or date is returned.
  absences as (
    select a.id, a.absence_group, a.organization_id, a.team_id, a.user_id, a.starts_at, a.created_at,
           a.recorded_by <> a.user_id as by_colleague,
           a.withdrawn_at is not null and a.withdrawn_by = a.user_id as withdrawn_by_member,
           (a.starts_at at time zone 'Europe/Zurich')::date as start_day,
           (a.created_at at time zone 'Europe/Zurich')::date as recorded_day,
           -- the end as first recorded (a shortening is audited with old and new end)
           coalesce((select (ae.changed -> 'ends_at' ->> 'old')::timestamptz from public.audit_events ae
                     where ae.table_name = 'member_absences' and ae.entity_id = a.id
                       and ae.changed -> 'ends_at' ->> 'old' is not null
                     order by ae.occurred_at, ae.id limit 1), a.ends_at) as first_ends_at,
           (a.withdrawn_at is not null and a.withdrawn_at <= a.created_at + interval '48 hours')
           or exists (select 1 from public.audit_events ae
                      where ae.table_name = 'member_absences' and ae.entity_id = a.id
                        and ae.changed -> 'ends_at' ->> 'old' is not null
                        and ae.occurred_at <= a.created_at + interval '48 hours') as changed_48h
    from public.member_absences a, params p
    where a.team_id in (select id from my_teams)
      and (a.starts_at at time zone 'Europe/Zurich')::date >= p.m0 and (a.starts_at at time zone 'Europe/Zurich')::date < p.m1
  ), absences_x as (
    select a.*,
           a.changed_48h
           or exists (select 1 from public.member_absences n
                      where n.organization_id = a.organization_id and n.user_id = a.user_id and n.absence_group <> a.absence_group
                        and n.created_at > a.created_at and n.created_at <= a.created_at + interval '48 hours'
                        and n.starts_at <= a.first_ends_at and n.ends_at >= a.starts_at) as revised
    from absences a
  ), absence_scope as (
    select a.organization_id, a.team_id, a.by_colleague, a.withdrawn_by_member, a.revised, a.start_day, a.recorded_day
    from absences_x a
    union all
    (select distinct on (a.absence_group) a.organization_id, null::uuid, a.by_colleague, a.withdrawn_by_member, a.revised,
            a.start_day, a.recorded_day
     from absences_x a order by a.absence_group, a.id)
  ), absence_counts as (
    select s.organization_id, s.team_id, count(*) as n,
           count(*) filter (where s.by_colleague) as by_colleague,
           count(*) filter (where s.by_colleague and s.withdrawn_by_member) as colleague_withdrawn,
           count(*) filter (where s.revised) as revised,
           count(*) filter (where s.start_day = s.recorded_day - 1) as start_yesterday,
           count(*) filter (where s.start_day < s.recorded_day - 1) as start_before_yesterday
    from absence_scope s group by s.organization_id, s.team_id
  ), visit_counts as (
    select v.organization_id, v.team_id, count(*) as n
    from visits v group by grouping sets ((v.organization_id, v.team_id), (v.organization_id))
  ),
  -- Past planned visits flagged by CGR-32 at the time the absence was recorded: planned, not left `planned` before
  -- the recording, dated before the recording day, naming the absent member, their interval (as planned then: the
  -- `before` slot of a later move) inside the absence as first recorded.
  flagged as (
    select a.organization_id, a.team_id, v.id as visit_id, v.status, a.created_at as recorded_at
    from absences a
    join public.care_visits v on v.organization_id = a.organization_id and v.team_id = a.team_id and v.responsible_user_id = a.user_id
    cross join lateral (
      select (s.slot ->> 'date')::date as slot_date,
             jsonb_populate_record(null::public.care_visits, to_jsonb(v) || jsonb_build_object(
               'visit_date', s.slot -> 'date', 'time_start', s.slot -> 'start', 'time_end', s.slot -> 'end')) as at_recording
      from (select coalesce((select pc.before from public.visit_plan_changes pc
                             where pc.visit_id = v.id and pc.change = 'moved' and pc.changed_at >= a.created_at
                             order by pc.changed_at, pc.id limit 1), private.visit_slot_json(v)) as slot) s) r
    where r.slot_date < a.recorded_day
      and private.visit_interval(r.at_recording) && tstzrange(a.starts_at, a.first_ends_at, '[)')
      and not exists (select 1 from public.visit_events e where e.visit_id = v.id and e.occurred_at < a.created_at)
  ), capture as (
    -- AN2-M8a: `visit_plan_changes.responsible_absent` exists since 0056; moves before it are not counted.
    -- The stored start only (set once by this migration); the reader never moves it.
    select coalesce((select c.started_at from private.an2_capture_starts c
                     where c.capture = 'visit_plan_changes.responsible_absent'), now()) as started_at
  ), flagged_end as (
    select f.organization_id, f.team_id,
           case
             when m.changed_at is not null and (x.occurred_at is null or m.changed_at <= x.occurred_at) then
               case when m.responsible_absent then 'moved'
                    when m.changed_at < (select c.started_at from capture c) then 'moved_before_capture'
                    else 'other' end
             when x.event_type in ('departed', 'started') then 'started_late'
             when x.event_type = 'cancelled' then
               case when exists (select 1 from public.visit_status_notes n
                                 where n.visit_id = f.visit_id and n.kind = 'cancelled' and n.responsible_absent)
                    then 'cancelled' else 'cancelled_without_mark' end
             when x.occurred_at is null and f.status = 'planned' then 'still_open'
             else 'other'
           end as ending
    from flagged f
    left join lateral (select pc.changed_at, pc.responsible_absent from public.visit_plan_changes pc
                       where pc.visit_id = f.visit_id and pc.change = 'moved' and pc.changed_at >= f.recorded_at
                       order by pc.changed_at, pc.id limit 1) m on true
    left join lateral (select e.occurred_at, e.event_type from public.visit_events e
                       where e.visit_id = f.visit_id and e.occurred_at >= f.recorded_at
                       order by e.occurred_at, e.id limit 1) x on true
  ), flagged_scope as (
    select f.organization_id, f.team_id, f.ending from flagged_end f
    union all
    select f.organization_id, null::uuid, f.ending from flagged_end f
  ), flagged_counts as (
    select s.organization_id, s.team_id, count(*) as n from flagged_scope s group by s.organization_id, s.team_id
  ), endings(code) as (
    values ('started_late'), ('cancelled'), ('cancelled_without_mark'), ('moved'), ('moved_before_capture'), ('still_open'), ('other')
  ), m8 as (
    select vc.organization_id, vc.team_id, 'absences_per_100'::text as measure, null::text as detail,
           round(100.0 * coalesce(ac.n, 0) / vc.n, 1) as value, vc.n::int as base
    from visit_counts vc
    left join absence_counts ac on ac.organization_id = vc.organization_id and ac.team_id is not distinct from vc.team_id
    union all
    select ac.organization_id, ac.team_id, 'absences_by_colleague_share', null, round(100.0 * ac.by_colleague / ac.n, 1), ac.n::int
    from absence_counts ac
    union all
    select ac.organization_id, ac.team_id, 'absences_withdrawn_by_member_share', null,
           round(100.0 * ac.colleague_withdrawn / nullif(ac.by_colleague, 0), 1), ac.by_colleague::int
    from absence_counts ac
    union all
    select ac.organization_id, ac.team_id, 'absences_revised_share', null, round(100.0 * ac.revised / ac.n, 1), ac.n::int
    from absence_counts ac
    union all
    select ac.organization_id, ac.team_id, 'absences_start_yesterday_share', null, round(100.0 * ac.start_yesterday / ac.n, 1), ac.n::int
    from absence_counts ac
    union all
    select ac.organization_id, ac.team_id, 'absences_start_before_yesterday', null, ac.start_before_yesterday::numeric, ac.n::int
    from absence_counts ac
    union all
    select ac.organization_id, ac.team_id, 'absence_past_visits_per_100', null,
           round(100.0 * coalesce(fc.n, 0) / ac.n, 1), ac.n::int
    from absence_counts ac
    left join flagged_counts fc on fc.organization_id = ac.organization_id and fc.team_id is not distinct from ac.team_id
    union all
    select fc.organization_id, fc.team_id, 'absence_past_visit_end', k.code,
           (select count(*) from flagged_scope s
            where s.organization_id = fc.organization_id and s.team_id is not distinct from fc.team_id and s.ending = k.code)::numeric,
           fc.n::int
    from flagged_counts fc cross join endings k
  ),
  -- 10. How exceptions end: overdue and stuck visits (0038), by a visit command or closed by hand -----------------------
  overdue as (
    select v.organization_id, v.team_id, o.since,
           (select min(e.occurred_at) from public.visit_events e where e.visit_id = v.id) as exit_at,
           (select min(ev.created_at) from public.exception_events ev
            where ev.organization_id = v.organization_id and ev.kind = 'close' and ev.exception_key = 'visit_overdue:' || v.id) as closed_at
    from visits v
    cross join lateral (select private.after_threshold(private.visit_start_at(v.visit_date, v.time_start), er.amount, er.unit) as since
                        from private.effective_exception_rules(v.organization_id) er where er.exception_type = 'visit_overdue') o
  ), stuck as (
    -- one exception per status change into on the way, started or paused (key `visit_stuck:<visit>:<event>`)
    select v.organization_id, v.team_id, s.since,
           (select min(n.occurred_at) from public.visit_events n
            where n.visit_id = e.visit_id and (n.occurred_at, n.id) > (e.occurred_at, e.id)) as exit_at,
           (select min(ev.created_at) from public.exception_events ev
            where ev.organization_id = v.organization_id and ev.kind = 'close'
              and ev.exception_key = 'visit_stuck:' || v.id || ':' || e.id) as closed_at
    from visits v
    join public.visit_events e on e.visit_id = v.id and e.to_status in ('on_the_way', 'started', 'paused')
    cross join lateral (
      select private.after_threshold(case
               when e.to_status = 'started' and coalesce(v.time_end, v.time_start) is not null
                 then greatest(e.occurred_at, (v.visit_date + coalesce(v.time_end, v.time_start)
                        + case when v.time_end < v.time_start then interval '1 day' else interval '0' end) at time zone 'Europe/Zurich')
               else e.occurred_at end, er.amount, er.unit) as since
      from private.effective_exception_rules(v.organization_id) er where er.exception_type = 'visit_stuck') s
  ), episodes as (
    select 'overdue'::text as kind, o.organization_id, o.team_id, o.exit_at, o.closed_at from overdue o
    where o.since <= now() and o.since < coalesce(o.exit_at, 'infinity'::timestamptz)
    union all
    select 'stuck', s.organization_id, s.team_id, s.exit_at, s.closed_at from stuck s
    where s.since <= now() and s.since < coalesce(s.exit_at, 'infinity'::timestamptz)
  ), m10 as (
    select x.organization_id, x.team_id, x.kind || '_ended_by_command_share' as measure, null::text as detail,
           round(100.0 * count(*) filter (where x.exit_at is not null and (x.closed_at is null or x.exit_at <= x.closed_at)) / count(*), 1)
             as value,
           count(*)::int as base
    from episodes x group by grouping sets ((x.kind, x.organization_id, x.team_id), (x.kind, x.organization_id))
    union all
    select x.organization_id, x.team_id, x.kind || '_closed_by_hand_share', null,
           round(100.0 * count(*) filter (where x.closed_at is not null and (x.exit_at is null or x.closed_at < x.exit_at)) / count(*), 1),
           count(*)::int
    from episodes x group by grouping sets ((x.kind, x.organization_id, x.team_id), (x.kind, x.organization_id))
  ),
  computed as (
    select * from m3 union all select * from m5 union all select * from m6 union all select * from m7
    union all select * from m9 union all select * from m11 union all select * from m12
    union all select * from m1 union all select * from m2 union all select * from m4 union all select * from m8
    union all select * from m10
  ),
  -- Every measure appears in every scope, also without events (base 0) ------------------------------------------------
  scopes as (
    select o.organization_id, null::uuid as team_id from my_orgs o where o.coordinator
    union all
    select t.organization_id, t.id from my_teams t
  ), catalogue(measure, detail) as (
    values ('coordinator_ends', null::text), ('correction_versions_per_100', null), ('correction_minutes_after_signature', null),
           ('correction_unchanged_share', null), ('correction_open_signals', null), ('correction_open_hours', null),
           ('correction_open_withdrawn_share', null), ('correction_open_signed_share', null), ('not_billable_facts', null),
           ('not_billable_reason', 'below_minimum'), ('not_billable_days_to_billable', null), ('visits_many_pauses', null),
           ('visits_open_past_p1', null), ('hold_lift_hours', null), ('holds_still_open', null),
           ('late_report_facts_share', null), ('basis_changed_per_100', null),
           -- part 3
           ('uncovered_taken_by_team_share', null), ('uncovered_hours_to_take', null),
           ('followup_without_visit_share', null), ('followup_decision_minutes', null),
           ('late_moves_per_100', null), ('late_responsible_changes_per_100', null),
           ('absences_per_100', null), ('absences_by_colleague_share', null), ('absences_withdrawn_by_member_share', null),
           ('absences_revised_share', null), ('absences_start_yesterday_share', null), ('absences_start_before_yesterday', null),
           ('absence_past_visits_per_100', null),
           ('absence_past_visit_end', 'started_late'), ('absence_past_visit_end', 'cancelled'),
           ('absence_past_visit_end', 'cancelled_without_mark'), ('absence_past_visit_end', 'moved'),
           ('absence_past_visit_end', 'moved_before_capture'), ('absence_past_visit_end', 'still_open'),
           ('absence_past_visit_end', 'other'),
           ('overdue_ended_by_command_share', null), ('overdue_closed_by_hand_share', null),
           ('stuck_ended_by_command_share', null), ('stuck_closed_by_hand_share', null)
  ), rows_all as (
    select s.organization_id, s.team_id, k.measure, k.detail, c.value, coalesce(c.base, 0) as base
    from scopes s cross join catalogue k
    left join computed c on c.organization_id = s.organization_id and c.team_id is not distinct from s.team_id
                        and c.measure = k.measure and c.detail is not distinct from k.detail
    union all
    -- per-reason rows beyond the catalogue (codes only)
    select c.organization_id, c.team_id, c.measure, c.detail, c.value, c.base
    from computed c join scopes s on s.organization_id = c.organization_id and s.team_id is not distinct from c.team_id
    where c.measure = 'not_billable_reason' and c.detail is distinct from 'below_minimum'
  )
  select r.organization_id, r.team_id, t.name, r.measure, r.detail,
         case when h.hide then null else r.value end,
         case when h.hide then null else r.base end,
         not h.hide and r.base < 5,
         h.hide,
         case when h.hide and r.team_id is null
                then 'Zu wenig Personen: die Organisationszahl wird verborgen, solange sie auf weniger als 3 Pflegende zurückgeführt werden könnte.'
              when h.hide
                then 'Zu wenig Personen: Teamzahlen erst ab 3 Pflegenden mit Einsätzen im Zeitraum.'
              when r.measure = 'not_billable_reason' and r.detail = 'below_minimum'
                then 'Regel in rechtlicher Prüfung (D-18), nicht als Verlust werten. Nicht in der Summe der nicht abrechenbaren Fakten.'
              when r.measure = 'absence_past_visit_end' and r.detail = 'moved_before_capture'
                then 'vor Erfassung (nicht gezählt): Verschiebungen vor der Erfassung der Abwesenheitsmarke (0056); ob die zuständige Person abwesend war, ist nicht gespeichert.'
              when r.measure = 'followup_without_visit_share'
                then 'Gezählt werden neu geplante Einsätze desselben Falls; ein verschobener bestehender Einsatz zählt nicht. «Folgeeinsatz geplant» ist eine Aussage, keine Prüfung (D-31).'
              when r.measure in ('correction_open_signals', 'visits_open_past_p1', 'uncovered_taken_by_team_share', 'uncovered_hours_to_take',
                                 'overdue_ended_by_command_share', 'overdue_closed_by_hand_share',
                                 'stuck_ended_by_command_share', 'stuck_closed_by_hand_share')
                then 'Schwelle wie heute eingestellt (provisorisch, D-28).'
         end
  from rows_all r
  left join my_teams t on t.id = r.team_id
  cross join lateral (select case when r.team_id is null then coalesce((select oh.hidden from org_hidden oh
                                                                         where oh.organization_id = r.organization_id), true)
                                  else coalesce((select p.people from people p where p.team_id = r.team_id), 0) < 3 end as hide) h
  order by 1, 2 nulls first, 4, 5 nulls first;
$$;
revoke all on function public.pilot_hypotheses(date) from public, anon;
grant execute on function public.pilot_hypotheses(date) to authenticated;
comment on function public.pilot_hypotheses(date) is
  'AN2: pilot hypotheses measured from events, per team and organisation (never per nurse), for the visits dated in '
  'the month. AN1 access and suppression (ADR-044, ADR-070): a team below 3 persons and a hidden organisation row show '
  'neither value nor base. Measures 1-12 (parts 2 and 3; ADR-070, ADR-071).';
