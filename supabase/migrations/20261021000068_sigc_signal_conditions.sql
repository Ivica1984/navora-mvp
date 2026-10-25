-- SIGC: the PO conditions SIG1-C2 (CGR-47), SIG1-C3 (CGR-46) and SIG2-C1 (CGR-48) of 2026-10-24 23:10
-- (`docs/agents/briefs/SIGC.md`, `SIG1.md` "PO conditions — 2026-10-24 23:10", `SIG2.md` "PO condition — 2026-10-24
-- 23:10"). ADR-082. Remediation plans `docs/agents/clinical/remediation/CGR-47.md`, `CGR-48.md`.
-- No clinical rule, threshold, priority, receiver, response duty or response time is decided here (D-28 stays open).
-- Every rule below reads visit/schedule facts only (take, role, watched hours, planned interval).
--
-- Before (0060, 0062, 0063, 0064):
--   * CGR-47: AN2 measure 10 (`signal_taken_share`, `signal_minutes_to_take`) and SIG2-10
--     (`signal_taken_within_threshold_share`) read `safety_signals.taken_at`, the FIRST take. For a no-show or a
--     broken-off visit that may be a care assistant's take, which SIG1-C1 does not count as one that stops the step.
--   * CGR-48 (1): `my_signals` gives the banner no watched-hours input, so a care assistant's take of a P1 no-show at
--     21:30 shows "Meldung an Operations folgt" although the Operations push stays in the app at that hour (SIG2-12).
--   * CGR-48 (2): SIG1-8 ("visits outside the watched hours are not planned") is a manual check; nothing lists them.
-- Now (IMPLEMENTED in this migration):
--   1. SIG1-C2: `private.signal_qualified_taken_at(signal)`: for `no_show` and `visit_interrupted` the first take with
--      `stops_escalation`; for every other kind the first take, as built. The three response measures count it; a take
--      that does not stop the step counts as not taken. The first take of any member stays as its own measure
--      `first_take_any_minutes`, with a note saying it is not the qualified response. AN1 suppression unchanged.
--   2. SIG2-C1 (1): `my_signals` gains `watched_now`: whether a watched period of the signal's organisation runs at the
--      reader's instant (`private.watched_inside(org, private.now())`, the SIG2-12 predicate: no watched hours → false).
--   3. SIG2-C1 (2): `public.visits_outside_watched_hours(p_team_id)`: the planned visits of the next 7 Zurich days
--      (today and the 6 following days) whose planned interval is not wholly inside the organisation's watched periods
--      (Europe/Zurich wall time, the same reading as `watched_inside`; adjacent periods count as one). Administrators read
--      their organisation (/admin); `p_own_teams => true` (/team) and every other member: her own teams only. Date,
--      times and team only, no client data.
-- Unchanged: `take_signal`, `signal_take_stops`, recipients, thresholds, `safety_signals.taken_by` (first taker), the
--   SIG1-5 and SIG2 steps, SIG1-8 as a go-live condition (Clinical Owner).

-- 0. Patch helper (each pattern must match the stated number of times; idempotent through a marker) -------------------
create function private.c68_patch(p_fn text, p_triples text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  for i in 1 .. coalesce(array_length(p_triples, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_triples[i], ''))) / length(p_triples[i]);
    if n <> p_triples[i + 2]::integer then
      raise exception '0068 patch for % must match % time(s), matched %: %', p_fn, p_triples[i + 2], n, p_triples[i];
    end if;
    def := replace(def, p_triples[i], p_triples[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0068 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.c68_patch(text, text[], text) from public, anon, authenticated;

-- 1. SIG1-C2 (CGR-47): the take AN2 counts ------------------------------------------------------------------------------
create or replace function private.signal_qualified_taken_at(p_signal_id uuid)
returns timestamptz language sql stable security definer set search_path = ''
as $$
  select case
    when s.signal_kind in ('no_show', 'visit_interrupted')
      then (select min(t.taken_at) from public.signal_takes t where t.signal_id = s.id and t.stops_escalation)
    else s.taken_at end
  from public.safety_signals s where s.id = p_signal_id
$$;
revoke all on function private.signal_qualified_taken_at(uuid) from public, anon, authenticated;
comment on function private.signal_qualified_taken_at(uuid) is
  'SIG1-C2 (CGR-47, ADR-082): the take AN2 counts as the response. no_show and visit_interrupted: the first take that '
  'stops the step to Operations (signal_takes.stops_escalation); every other kind: the first take (as built). Null = '
  'not taken in that sense.';

select private.c68_patch('public.pilot_hypotheses(date)', array[
    -- measure 10 (SIG1-6): the qualified take; the first take of anyone kept beside it
    E'    select s.organization_id, s.team_id, s.taken_at, s.p1_at\n',
    E'    select s.organization_id, s.team_id, private.signal_qualified_taken_at(s.id) as taken_at, s.p1_at,\n'
    || E'           s.taken_at as first_taken_at /* SIG1-C2 (ADR-082) */\n',
    '1',
    E'    from sig1_episodes x where x.taken_at is not null group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n',
    E'    from sig1_episodes x where x.taken_at is not null group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n'
    || E'    union all\n'
    || E'    -- SIG1-C2: the first take of any member, its own value, never read as the qualified response\n'
    || E'    select x.organization_id, x.team_id, ''first_take_any_minutes'', null,\n'
    || E'           round((percentile_cont(0.5) within group (order by greatest(0, extract(epoch from (x.first_taken_at - x.p1_at)) / 60)))::numeric, 1),\n'
    || E'           count(*)::int\n'
    || E'    from sig1_episodes x where x.first_taken_at is not null group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n',
    '1',
    -- SIG2-10: taken within the untaken threshold, by the qualified take
    E'           s.taken_at is not null and s.taken_at <= (select private.after_threshold(s.created_at, er.amount, er.unit)\n',
    E'           private.signal_qualified_taken_at(s.id) is not null /* SIG1-C2 */\n'
    || E'           and private.signal_qualified_taken_at(s.id) <= (select private.after_threshold(s.created_at, er.amount, er.unit)\n',
    '1',
    -- catalogue
    E'           (''signal_taken_share'', null), (''signal_minutes_to_take'', null),\n',
    E'           (''signal_taken_share'', null), (''signal_minutes_to_take'', null), (''first_take_any_minutes'', null),\n',
    '1',
    -- notes: before the generic "threshold as set today" branch, which then no longer reaches the three measures
    E'              when r.measure in (''correction_open_signals'',',
    E'              when r.measure in (''signal_taken_share'', ''signal_minutes_to_take'', ''signal_taken_within_threshold_share'')\n'
    || E'                then ''Schwelle wie heute eingestellt (provisorisch, D-28). Bei «Klientin öffnet nicht» und «Einsatz abgebrochen» '
    || E'zählt die Übernahme, die die Meldung an Operations stoppt (SIG1-C2).''\n'
    || E'              when r.measure = ''first_take_any_minutes''\n'
    || E'                then ''Erste Übernahme durch irgendein Mitglied, auch wenn sie die Meldung an Operations nicht stoppt. '
    || E'Nicht die qualifizierte Antwort (SIG1-C2).''\n'
    || E'              when r.measure in (''correction_open_signals'',',
    '1'
  ], 'SIG1-C2 (ADR-082)');

-- 2. SIG2-C1 (1) (CGR-48): the reader says whether a watched period runs -----------------------------------------------
-- The 0063 body with one more column, `watched_now`.
drop function if exists public.my_signals();
create function public.my_signals()
returns table (signal_id uuid, signal_kind text, visit_id uuid, visit_date date, time_start time, team_id uuid,
               team_name text, reason text, delivered_at timestamptz, p1_at timestamptz,
               taken_by_me boolean, taken_by_name text, taken_at timestamptz, outside_none boolean,
               taken_by_qualification text, taken_awaits_rn boolean, watched_now boolean)
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null then return; end if;
  for org in select distinct om.organization_id from public.organization_memberships om where om.user_id = uid loop
    perform private.evaluate_signals(org, false);
  end loop;
  return query
    select s.id, s.signal_kind, s.visit_id, v.visit_date, v.time_start, s.team_id, t.name, d.reason, d.created_at, s.p1_at,
           coalesce(tk.taker_id = uid, false),
           case when tk.taker_id is not null
                then coalesce(private.member_name(s.organization_id, tk.taker_id), 'Teammitglied') end,
           tk.taken_at, s.outside_none_at is not null,
           tk.qualification,
           (tk.taker_id is not null and not tk.stops_escalation),
           private.watched_inside(s.organization_id, private.now())   -- SIG2-C1 (1), ADR-082
    from public.signal_deliveries d
    join public.safety_signals s on s.id = d.signal_id
    join public.care_visits v on v.id = s.visit_id
    join public.teams t on t.id = s.team_id
    left join lateral (select x.taker_id, x.taken_at, x.qualification, x.stops_escalation from public.signal_takes x
                       where x.signal_id = s.id order by x.stops_escalation desc, x.taken_at, x.id limit 1) tk on true
    where d.recipient_id = uid and s.ended_at is null and private.is_org_member(d.organization_id)
    order by (tk.taker_id is null or not tk.stops_escalation) desc, d.created_at desc, s.id;
end;
$$;
revoke all on function public.my_signals() from public, anon;
grant execute on function public.my_signals() to authenticated;
comment on function public.my_signals() is
  'SIG1-3 reader with SIG1-C1 (0063) and SIG2-C1 (1) (ADR-082): the caller''s open P1 safety signals; watched_now = a '
  'watched period of the organisation runs now (no watched hours recorded → false), so the banner says when the step to '
  'Operations stays in the app.';

-- 3. SIG2-C1 (2) (CGR-48): planned visits outside the watched hours ----------------------------------------------------
-- A visit's planned interval on the wall clock: start .. end; no end → one minute (as ABS1); an end at or before the
-- start → the next day; no start → the whole day (cannot be shown to be inside).
create or replace function private.visit_wall_range(p_date date, p_start time, p_end time)
returns tsrange language sql immutable set search_path = ''
as $$
  select case
    when p_start is null then tsrange(p_date::timestamp, (p_date + 1)::timestamp, '[)')
    when p_end is null then tsrange(p_date + p_start, p_date + p_start + interval '1 minute', '[)')
    when p_end <= p_start then tsrange(p_date + p_start, (p_date + 1) + p_end, '[)')
    else tsrange(p_date + p_start, p_date + p_end, '[)') end
$$;
revoke all on function private.visit_wall_range(date, time, time) from public, anon, authenticated;

-- The organisation's watched periods on the wall clock of the given days (start inclusive, end exclusive, '24:00' =
-- midnight at the end of the day), merged: adjacent periods are one.
create or replace function private.watched_wall_ranges(p_org uuid, p_from date, p_to date)
returns tsmultirange language sql stable security definer set search_path = ''
as $$
  select coalesce(range_agg(tsrange(d::date + h.starts, d::date + h.ends, '[)')), '{}'::tsmultirange)
  from generate_series(p_from, p_to, interval '1 day') d
  join public.organization_watched_hours h
    on h.organization_id = p_org and h.weekday = extract(isodow from d)::int and h.ends > h.starts
$$;
revoke all on function private.watched_wall_ranges(uuid, date, date) from public, anon, authenticated;

create or replace function public.visits_outside_watched_hours(p_own_teams boolean default false)
returns table (visit_id uuid, organization_id uuid, team_id uuid, team_name text, visit_date date,
               time_start time, time_end time)
language sql stable security definer set search_path = ''
as $$
  with today as (select (private.at_zurich(private.now()))::date as d)
  select v.id, v.organization_id, t.id, t.name, v.visit_date, v.time_start, v.time_end
  from public.care_visits v
  join public.teams t on t.id = v.team_id
  cross join today
  where v.status = 'planned' and v.suspended_at is null
    and v.visit_date >= today.d and v.visit_date <= today.d + 6
    and private.is_org_member(v.organization_id)
    and ((not coalesce(p_own_teams, false) and private.is_org_admin(v.organization_id)) or private.is_team_member(v.team_id))
    and not (private.visit_wall_range(v.visit_date, v.time_start, v.time_end)
             <@ private.watched_wall_ranges(v.organization_id, v.visit_date, v.visit_date + 1))
  order by v.visit_date, v.time_start nulls first, t.name, v.id
$$;
revoke all on function public.visits_outside_watched_hours(boolean) from public, anon;
grant execute on function public.visits_outside_watched_hours(boolean) to authenticated;
comment on function public.visits_outside_watched_hours(boolean) is
  'SIG2-C1 (2) (CGR-48, ADR-082): planned, not suspended visits of today and the next 6 Zurich days whose planned '
  'interval is not wholly inside the organisation''s watched periods (wall time; no watched hours → every planned visit). '
  'Administrators: their organisation (p_own_teams = false, /admin); /team and every other member: her own teams. Date, times and team only. The structured '
  'replacement for the manual SIG1-8 check; SIG1-8 stays a go-live condition.';

drop function private.c68_patch(text, text[], text);
