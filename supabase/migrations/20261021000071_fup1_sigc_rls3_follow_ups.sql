-- FUP1: follow-ups of SIGC and RLS3 (`docs/agents/briefs/FUP1.md`, PO 2026-10-25 14:13). ADR-084.
-- Source: `cra` 2026-10-25 13:26 (PR #374) CGR-57 (S2), CGR-58 (S3), CGR-59 (S2), all advisory.
-- Display and read-model changes only. No threshold, watched period, clinical, billing or tariff rule is set or changed
-- (D-28, D-32, D-18 stay open). Every rule below reads visit/schedule facts only.
--
-- Before (0068, 0070):
--   * CGR-57: `private.visit_wall_range(date, time, time)` gave a planned visit without an end time one minute, while
--     ABS1's `private.visit_interval` (0069) gives it start + planned minutes A+B+C, else the rest of its day. A visit at
--     19:50 without an end and 45 planned minutes (about 20:35) was not listed under watched hours 07:00-20:00.
--   * CGR-58: `my_signals.watched_now` is judged at the reader's instant, not at the instant the step to Operations is
--     made; a care assistant who takes a P1 no-show at 19:55 (watched until 20:00) read "Meldung an Operations folgt"
--     although the step, due after 20:00, stays in the app.
--   * CGR-59: the RLS3-4b billing view did not say whether a correction is contained in the billed version.
-- Now (IMPLEMENTED in this migration):
--   1. FUP1-1: `private.visit_wall_range(care_visits)` reads the length of a visit without an end (or with end = start)
--      from `private.visit_interval` itself: wall start + its elapsed length, and never earlier than the wall reading
--      of its end instant (the longer of the two readings on a clock-change night). Visits with an explicit end keep
--      the 0068 wall-clock reading. `visits_outside_watched_hours` reads it; the 3-argument helper is dropped.
--   2. FUP1-2: `private.signal_step_outside_app(signal, at)`: once the step to Operations is made (an Operations
--      delivery exists, or the signal is escalated), true only when an Operations delivery is handed to the sender or
--      sent outside the app (`pending`, `sent`); before it, whether a watched period runs at the instant the step is
--      due (the untaken threshold of the episode, never earlier than `at`). No untaken threshold → false.
--      `my_signals` gains `operations_outside_app` (= that function at `private.now()`); `watched_now` is unchanged.
--   3. FUP1-3 (= RLS3-4c): `visit_correction_history` gains `in_billed_version` per correction: correction time at or
--      before the countersignature time (or the signature time when no countersignature is required) of the version
--      the current billing fact rests on → true; after it → false; no billing fact → null. Both levels; level (b)
--      still returns no reason and no corrector; nothing groups or counts per person.
-- Unchanged: `private.visit_interval`, `private.watched_inside`, `outside_classify`, thresholds, recipients, the
--   SIG1/SIG2 steps, the two access levels of the correction trail, SIG1-8 as a go-live condition (Clinical Owner).
-- Idempotent: every object is created with create or replace / drop if exists; a second run changes nothing.

-- 1. FUP1-1 (CGR-57): one visit length everywhere -----------------------------------------------------------------------
-- The planned interval of a visit on the Zurich wall clock. No start: the whole date. No end, or end = start: the
-- length `private.visit_interval` gives it (planned minutes A+B+C, else to the end of its date), read both as wall
-- start + elapsed length and as the wall reading of its end instant, whichever is later (never shorter on a
-- clock-change night). End before start: across midnight. Otherwise: start .. end.
create or replace function private.visit_wall_range(v public.care_visits)
returns tsrange language sql stable set search_path = ''
as $$
  select case
    when v.time_start is null then tsrange(v.visit_date::timestamp, (v.visit_date + 1)::timestamp, '[)')
    when v.time_end is null or v.time_end = v.time_start then
      (select tsrange(v.visit_date + v.time_start,
                      greatest((v.visit_date + v.time_start) + (upper(i.r) - lower(i.r)), private.at_zurich(upper(i.r))),
                      '[)')
       from (select private.visit_interval(v) as r) i)
    when v.time_end < v.time_start then tsrange(v.visit_date + v.time_start, (v.visit_date + 1) + v.time_end, '[)')
    else tsrange(v.visit_date + v.time_start, v.visit_date + v.time_end, '[)') end
$$;
revoke all on function private.visit_wall_range(public.care_visits) from public, anon, authenticated;
comment on function private.visit_wall_range(public.care_visits) is
  'FUP1-1 (CGR-57, ADR-084): planned interval of a visit on the Zurich wall clock. Without an end (or end = start) its '
  'length is read from private.visit_interval (start + planned minutes A+B+C, else to the end of its date), never '
  'shorter than either wall reading. Used by visits_outside_watched_hours.';

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
    and not (private.visit_wall_range(v)   /* FUP1-1 (ADR-084) */
             <@ private.watched_wall_ranges(v.organization_id, v.visit_date, v.visit_date + 2))
  order by v.visit_date, v.time_start nulls first, t.name, v.id
$$;
revoke all on function public.visits_outside_watched_hours(boolean) from public, anon;
grant execute on function public.visits_outside_watched_hours(boolean) to authenticated;
comment on function public.visits_outside_watched_hours(boolean) is
  'SIG2-C1 (2) (CGR-48, ADR-082) with FUP1-1 (CGR-57, ADR-084): planned, not suspended visits of today and the next 6 '
  'Zurich days whose planned interval (private.visit_wall_range: the ABS1 length for a visit without an end) is not '
  'wholly inside the organisation''s watched periods (wall time; no watched hours → every planned visit). '
  'Administrators: their organisation (p_own_teams = false, /admin); /team and every other member: her own teams. Date, '
  'times and team only. The structured replacement for the manual SIG1-8 check; SIG1-8 stays a go-live condition.';

drop function if exists private.visit_wall_range(date, time, time);

-- 2. FUP1-2 (CGR-58): the banner follows the delivery --------------------------------------------------------------------
-- Does the step to Operations of this signal reach Operations outside the app?
--   * The step is made (an Operations delivery exists, or the signal is escalated): true only when an Operations
--     delivery is handed to the sender or sent (`pending`, `sent`); `outside_working_time`, `not_active`, `failed`, no
--     outside row (channel off), or no Operations member → false.
--   * Not made yet: a watched period runs at the instant the step is due (the episode's untaken threshold, as the SIG1-5
--     step computes it), never earlier than p_at. No untaken threshold → false (nothing is promised).
create or replace function private.signal_step_outside_app(p_signal_id uuid, p_at timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case
    when s.escalated_at is not null
         or exists (select 1 from public.signal_deliveries d
                    where d.signal_id = s.id and d.reason in ('operations_fallback', 'untaken'))
      then exists (select 1 from public.signal_deliveries d
                   join public.signal_outside_deliveries o on o.id = d.id
                   where d.signal_id = s.id and d.reason in ('operations_fallback', 'untaken')
                     and o.result in ('pending', 'sent'))
    else coalesce((select private.watched_inside(s.organization_id,
                                                 greatest(p_at, private.after_threshold(s.created_at, r.amount, r.unit)))
                   from private.effective_exception_rules(s.organization_id) r
                   where r.exception_type = 'signal_untaken'
                   limit 1), false)
  end
  from public.safety_signals s where s.id = p_signal_id
$$;
revoke all on function private.signal_step_outside_app(uuid, timestamptz) from public, anon, authenticated;
comment on function private.signal_step_outside_app(uuid, timestamptz) is
  'FUP1-2 (CGR-58, ADR-084): whether the step to Operations of a signal reaches Operations outside the app. Made: '
  'follows the Operations delivery (pending/sent → true; otherwise false). Not made: watched_inside at the instant the '
  'step is due (untaken threshold, never before p_at). No threshold → false.';

-- The 0068 body with one more column, `operations_outside_app`.
drop function if exists public.my_signals();
create function public.my_signals()
returns table (signal_id uuid, signal_kind text, visit_id uuid, visit_date date, time_start time, team_id uuid,
               team_name text, reason text, delivered_at timestamptz, p1_at timestamptz,
               taken_by_me boolean, taken_by_name text, taken_at timestamptz, outside_none boolean,
               taken_by_qualification text, taken_awaits_rn boolean, watched_now boolean,
               operations_outside_app boolean)
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
           private.watched_inside(s.organization_id, private.now()),   -- SIG2-C1 (1), ADR-082
           private.signal_step_outside_app(s.id, private.now())        -- FUP1-2, ADR-084
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
  'SIG1-3 reader with SIG1-C1 (0063), SIG2-C1 (1) (ADR-082) and FUP1-2 (ADR-084): the caller''s open P1 safety '
  'signals; watched_now = a watched period of the organisation runs now; operations_outside_app = the step to '
  'Operations reaches Operations outside the app (follows its delivery once made; before, judged at the instant it is '
  'due). The banner promises the message only on operations_outside_app.';

-- 3. FUP1-3 (CGR-59, RLS3-4c): billed or not, per correction ------------------------------------------------------------
-- The 0070 body with one more column, `in_billed_version`, and the signed instant of the billed version in `fact`.
drop function if exists public.visit_correction_history(uuid);
create function public.visit_correction_history(p_visit_id uuid)
returns table (
  correction_id bigint,
  event_id bigint,
  event_type text,
  recorded_at timestamptz,            -- the event as recorded
  old_at timestamptz,                 -- value before this correction (previous correction or the recorded time)
  new_at timestamptz,                 -- value after this correction
  corrected_on timestamptz,           -- when the correction was made
  full_trail boolean,                 -- (a) true, (b) false
  reason text,                        -- (a) only
  corrector_name text,                -- (a) only
  corrected_by_me boolean,            -- (a) only
  fact_report_version integer,        -- signed report version the current billing fact is based on (null: no fact yet)
  fact_countersigned_by_name text,    -- its countersigner (already on the report)
  in_billed_version boolean           -- FUP1-3: the correction is contained in that version (null: no fact yet)
)
language sql stable security definer set search_path = ''
as $$
  with v as (
    select cv.id, cv.organization_id,
           case
             when private.reads_visit(cv.id)
               or (exists (select 1 from public.visit_reports r
                           where r.visit_id = cv.id
                             and (r.performer_id = (select auth.uid()) or r.countersigned_by = (select auth.uid())))
                   and (private.is_team_member(cv.team_id)
                        or (cv.cover_team_id is not null and private.is_team_member(cv.cover_team_id))))
               then 'a'
             when private.is_coordinator(cv.organization_id) then 'b'
           end as lvl
    from public.care_visits cv
    where cv.id = p_visit_id
      and private.is_org_member(cv.organization_id)
  ), fact as (
    select r.version, private.member_name(r.organization_id, r.countersigned_by) as countersigner,
           -- FUP1-3: the instant the billed version became final (countersignature, or signature when none is required)
           case when r.countersign_required then r.countersigned_at else r.signed_at end as billed_at
    from v
    join public.billable_facts f on f.visit_id = v.id
    join public.visit_reports r on r.id = f.report_id
    where not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
    order by f.created_at desc, f.id desc
    limit 1
  )
  select x.id, e.id, e.event_type, e.occurred_at,
         coalesce((select y.corrected_at from public.visit_time_corrections y
                   where y.event_id = x.event_id and (y.created_at, y.id) < (x.created_at, x.id)
                   order by y.created_at desc, y.id desc limit 1), e.occurred_at),
         x.corrected_at,
         x.created_at,
         v.lvl = 'a',
         case when v.lvl = 'a' then x.reason end,
         case when v.lvl = 'a' then private.member_name(x.organization_id, x.actor_id) end,
         case when v.lvl = 'a' then x.actor_id = (select auth.uid()) end,
         (select fact.version from fact),
         (select fact.countersigner from fact),
         x.created_at <= (select fact.billed_at from fact)   -- FUP1-3 (ADR-084); null without a fact
  from v
  join public.visit_time_corrections x on x.visit_id = v.id
  join public.visit_events e on e.id = x.event_id
  where v.lvl is not null
  order by e.id, x.created_at, x.id;
$$;

revoke all on function public.visit_correction_history(uuid) from public, anon;
grant execute on function public.visit_correction_history(uuid) to authenticated;

comment on function public.visit_correction_history(uuid) is
  'RLS3-4b (ADR-083) with FUP1-3 / RLS3-4c (ADR-084): correction trail of one visit. (a) full trail with reason and '
  'corrector for the report''s author and countersigner, the visit''s team and its active covering member; (b) billing '
  'view (values and times, no reason, no corrector) for other coordination roles of the organisation. Both: '
  'in_billed_version = the correction was made at or before the countersignature (or signature, when none is '
  'required) of the version the current billing fact rests on; null without a fact. Never per person.';
