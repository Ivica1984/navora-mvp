-- PLAN3-13: the look-back measure per stop and team, never per person (ADR-150). PO brief docs/agents/briefs/PLAN3.md,
-- note 2026-10-31 02:25 (ADR-130 deviation 5, the AIG1-C1 P-6 measure extension) and note 02:55 (AUT-31). Stage 0 of
-- D-35: synthetic data only, no AI service. No clinical rule, no threshold, no stop criterion, no new read.
--
-- Before (IMPLEMENTED in 0097/0104/0111): `agent_stop_lookback(stop)` lists the lines still on the list now and says
-- whether each is superseded or no longer open; `team_lookback_stops()` counts open and no-longer-open lines per team.
-- Nothing said how many lines the stop listed at first, how many left by a re-check, how many were no longer open
-- already at the stop and how long the team took to "0 offen" — the data P-39 and P-40 are decided on.
-- Now (IMPLEMENTED in this migration):
--   1. `private.plan3_visit_open_at(visit, instant)`: the AIG1-C1 open-visit condition (0104 `aig1_record_open`) at a
--      past instant. status and visit_date are read back from `audit_events` (every UPDATE of care_visits writes the old
--      value, 0014); suspension and cover from their own timestamps (`suspended_at`, `covered_at`). Known limit
--      (ADR-150 deviation 1): a suspension or cover that was lifted again leaves no timestamp, so the visit counts as
--      open for that span.
--   2. `private.plan3_stop_lines(stop)`: every line the stop listed at the stop (`aig1_lookback` without the "not re-checked
--      since" condition), with the time of the first re-check after the stop and the instant the visit became no
--      longer open after the stop (first candidate instant at which (1) is false). No person column.
--   3. `public.agent_stop_measures(stop)`: per team of the stop, the six counts of the brief — lines at stop; lines left
--      by correction or re-confirmation; lines "überholt"; lines "nicht mehr offen" at the stop; lines that became "nicht
--      mehr offen" while still listed; days until "0 offen" (Zurich calendar days from the stop to the moment the last
--      line left; null while a line is open) — plus `open_now` and, AUT-31, the agent's proposals of that team in the
--      stop window and their median lead time from proposal to visit start (hours). The access is that of
--      `agent_stop_lookback` (coordinators every team, a member her own teams; LEAVE1-3). Writes nothing.
--   The AUT-31 expired share (AIG1-C4) is PLANNED: AIG1-C4 is in #814 (migration 0105), not on this stack (ADR-150
--   deviation 2).
-- No table, so no RLS policy, column grant or audit trigger is added; functions only. Idempotent: `create or replace`.

-- 1. The open-visit condition at a past instant ---------------------------------------------------------------------------
create or replace function private.plan3_visit_open_at(p_visit_id uuid, p_at timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select coalesce((select a.changed -> 'status' ->> 'old' from public.audit_events a
                     where a.table_name = 'care_visits' and a.entity_id = v.id and a.changed ? 'status'
                       and a.occurred_at > p_at order by a.occurred_at, a.id limit 1), v.status) = 'planned'
       and not coalesce(v.suspended_at <= p_at, false)
       and not coalesce(v.covered_at <= p_at, false)
       and coalesce((select (a.changed -> 'visit_date' ->> 'old')::date from public.audit_events a
                     where a.table_name = 'care_visits' and a.entity_id = v.id and a.changed ? 'visit_date'
                       and a.occurred_at > p_at order by a.occurred_at, a.id limit 1), v.visit_date)
           >= (private.at_zurich(p_at))::date
    from public.care_visits v where v.id = p_visit_id), false)
$$;
revoke all on function private.plan3_visit_open_at(uuid, timestamptz) from public, anon, authenticated;
comment on function private.plan3_visit_open_at(uuid, timestamptz) is
  'PLAN3-13: the AIG1-C1 open-visit condition (planned, not suspended or covered, not dated before that day, Europe/'
  'Zurich) at a past instant; status and visit_date from audit_events, suspension and cover from their timestamps. A '
  'lifted suspension or cover leaves no trace (ADR-150 deviation 1).';

-- 2. Every line of the stop as listed at the stop ------------------------------------------------------------------------
create or replace function private.plan3_stop_lines(p_stop_id uuid)
returns table (suggestion_id uuid, organization_id uuid, team_id uuid, entity_type text, entity_id uuid,
               stopped_at timestamptz, open_at_stop boolean, rechecked_at timestamptz,
               superseded boolean, superseded_at timestamptz, open_now boolean, not_open_since timestamptz)
language sql stable security definer set search_path = ''
as $$
  select s.id, s.organization_id, s.team_id, s.entity_type, s.entity_id, st.created_at,
         case when s.entity_type = 'care_visits' then private.plan3_visit_open_at(s.entity_id, st.created_at) else true end,
         z.confirmed_at,
         cur.value is distinct from c.final_value,
         case when cur.value is distinct from c.final_value
              then private.aig1_superseded_at(s.entity_type, s.entity_id, s.field, c.final_value) end,
         private.aig1_record_open(s.entity_type, s.entity_id),
         case when s.entity_type = 'care_visits' and not private.aig1_record_open(s.entity_type, s.entity_id) then
           (select min(t.at) from (
              select a.occurred_at as at from public.audit_events a
              where a.table_name = 'care_visits' and a.entity_id = s.entity_id
                and (a.changed ? 'status' or a.changed ? 'visit_date')
              union all select v.suspended_at from public.care_visits v where v.id = s.entity_id
              union all select v.covered_at from public.care_visits v where v.id = s.entity_id
              union all select private.at_zurich((v.visit_date + 1)::timestamp) from public.care_visits v
              where v.id = s.entity_id) t
            where t.at is not null and t.at > st.created_at and t.at <= private.now()
              and not private.plan3_visit_open_at(s.entity_id, t.at)) end
  from public.ai_agent_stops st
  join public.ai_suggestions s
    on s.organization_id = st.organization_id and s.agent_key = st.agent_key
   and s.created_at >= st.window_from
   and (s.created_at < st.window_to or (st.reason = 'version_changed' and s.seq <= st.suggestion_seq))
  cross join lateral (select y.outcome, y.final_value from public.ai_confirmations y
                      where y.suggestion_id = s.id and y.seq <= st.confirmation_seq order by y.seq desc limit 1) c
  cross join lateral (select private.aig1_current_value(s.entity_type, s.entity_id, s.field) as value) cur
  left join lateral (select y.confirmed_at from public.ai_confirmations y
                     where y.suggestion_id = s.id and y.seq > st.confirmation_seq order by y.seq limit 1) z on true
  where st.id = p_stop_id
    and c.outcome = 'confirmed'                                            -- unchanged at the stop (as aig1_lookback)
$$;
revoke all on function private.plan3_stop_lines(uuid) from public, anon, authenticated;
comment on function private.plan3_stop_lines(uuid) is
  'PLAN3-13: every line a stop listed at the stop (aig1_lookback without "not re-checked since"), with the first '
  're-check after the stop, superseded, open now, and when the visit became no longer open. No person column; callers '
  'filter access.';

-- 3. The measure per stop and team ---------------------------------------------------------------------------------------
create or replace function public.agent_stop_measures(p_stop_id uuid)
returns table (team_id uuid, team_name text, lines_at_stop integer, left_by_recheck integer, superseded integer,
               not_open_at_stop integer, became_not_open integer, open_now integer, days_to_zero_open integer,
               proposals_in_window integer, lead_time_median_hours numeric)
language sql stable security definer set search_path = ''
as $$
  with st as (select * from public.ai_agent_stops where id = p_stop_id),
  lines as (
    select l.*,
           l.rechecked_at is not null                                                 as left_recheck,
           l.rechecked_at is null and l.superseded                                    as is_superseded,
           l.rechecked_at is null and not l.superseded and l.open_at_stop and not l.open_now as became,
           l.rechecked_at is null and not l.superseded and l.open_now                 as still_open,
           -- when the line stopped counting as open: at the stop if its visit was no longer open then; otherwise the
           -- first of re-check, supersession and the visit closing (never before the stop); null while it counts as open
           case when not l.open_at_stop then l.stopped_at
                when coalesce(l.rechecked_at, l.superseded_at, l.not_open_since) is null then null
                else greatest(l.stopped_at, least(l.rechecked_at, l.superseded_at, l.not_open_since)) end as left_at
    from private.plan3_stop_lines(p_stop_id) l
  ),
  scoped as (                                                         -- the scope of agent_stop_lookback (0104)
    select l.* from lines l, st
    where not private.access_ended((select auth.uid()))                                        -- LEAVE1-3
      and private.is_org_member(st.organization_id)
      and (private.is_coordinator(st.organization_id) or private.is_team_member(l.team_id))
  ),
  props as (                                                          -- AUT-31: the agent's proposals in the window
    select s.team_id, count(*)::int as n,
           round((percentile_cont(0.5) within group (order by
             extract(epoch from (private.visit_start_at(v.visit_date, v.time_start) - s.created_at)) / 3600.0))::numeric, 1)
             as median_hours
    from st
    join public.ai_suggestions s
      on s.organization_id = st.organization_id and s.agent_key = st.agent_key
     and s.created_at >= st.window_from
     and (s.created_at < st.window_to or (st.reason = 'version_changed' and s.seq <= st.suggestion_seq))
    join public.care_visits v on s.entity_type = 'care_visits' and v.id = s.entity_id
    group by s.team_id
  )
  select g.team_id, t.name, g.lines_at_stop, g.left_by_recheck, g.superseded, g.not_open_at_stop, g.became_not_open,
         g.open_now,
         case when g.open_now = 0 and g.unknown_left = 0 and g.last_left is not null
              then ((private.at_zurich(g.last_left))::date - (private.at_zurich(g.stopped_at))::date) end,
         coalesce(p.n, 0), p.median_hours
  from (
    select l.team_id, min(l.stopped_at) as stopped_at,
           count(*)::int as lines_at_stop,
           (count(*) filter (where l.left_recheck))::int as left_by_recheck,
           (count(*) filter (where l.is_superseded))::int as superseded,
           (count(*) filter (where not l.open_at_stop))::int as not_open_at_stop,
           (count(*) filter (where l.became))::int as became_not_open,
           (count(*) filter (where l.still_open))::int as open_now,               -- as team_lookback_stops (0111)
           (count(*) filter (where l.left_at is null))::int as unknown_left,
           max(l.left_at) as last_left
    from scoped l group by l.team_id
  ) g
  join public.teams t on t.id = g.team_id
  left join props p on p.team_id = g.team_id
  order by t.name
$$;
revoke all on function public.agent_stop_measures(uuid) from public, anon;
grant execute on function public.agent_stop_measures(uuid) to authenticated;
comment on function public.agent_stop_measures(uuid) is
  'PLAN3-13: per team of a stop, never per person: lines at the stop, left by re-confirmation or correction, superseded, '
  'no longer open at the stop, no longer open since while still listed, open now, Zurich days until "0 offen" (null '
  'while open); AUT-31: proposals of that team in the stop window and their median lead time to the visit (hours). '
  'Scope as agent_stop_lookback (coordinators every team, a member her own teams). A usefulness measure, never a stop '
  'criterion. Writes nothing.';
