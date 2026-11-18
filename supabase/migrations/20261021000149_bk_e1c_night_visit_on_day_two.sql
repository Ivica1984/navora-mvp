-- BK-e1c (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1–C3; R3b, `cra` CGR-257, `uxa` UXR-248;
-- ADR-203 amendment BK-e1c in docs/engineering/DECISIONS.md). A night visit crossing midnight (the repository's existing
-- rule: `time_end < time_start`, 0038/0048/0069/0071) that is still running on the next calendar day stays on that day's
-- /field («Heute» after midnight), and so do the client's safety alerts of that visit.
--
--   1. `private.field_day_carried(...)`: one private predicate, true when the visit is dated the day before `p_date`,
--      crosses midnight, and is `started` or `paused` (running), or was completed on `p_date` (Europe/Zurich, recorded
--      time of its `completed` event). PROPOSED for `cra`/`uxa` (review question 5): a night visit completed on day 2
--      stays on day 2, so the card, «Bericht prüfen und unterschreiben» and «Ereignis melden» do not vanish from her day
--      at the refresh right after «Einsatz abschliessen». Not carried (C3): a day-1 visit that is `planned`,
--      `on_the_way` (PROPOSED, review question 3 for `cra`), `cancelled`, completed on day 1, a day visit, or a visit
--      dated two or more days back. The predicate reads no clock: the date is its only input.
--   2. `public.field_visits(date)` uses it next to `v.visit_date = p_date`, returns `carried_from_previous_day boolean`,
--      and lists carried visits first (UXR-248: first card below any P1 signal; the screen keeps that order).
--   3. `public.field_safety_alerts(date)` uses the same predicate (CGR-257: visit and its alerts never drift apart).
--
-- Display only: no command, no state transition, no refusal and no clinical rule changes; RLS, grants and the audit
-- triggers are untouched (field_visits stays SECURITY INVOKER, field_safety_alerts keeps `private.reads_visit`).
-- Idempotent: the field_visits patch carries the marker BK-E1C and is skipped when present; every fragment must match
-- exactly once, otherwise the migration stops. Synthetic data only.

-- 1. The predicate --------------------------------------------------------------------------------------------------
create or replace function private.field_day_carried(p_visit_id uuid, p_visit_date date, p_time_start time,
                                                     p_time_end time, p_status text, p_date date)
returns boolean
language sql stable security invoker set search_path = ''
as $$
  select coalesce(
    p_date is not null
    and p_visit_date = p_date - 1
    and p_time_start is not null and p_time_end is not null
    and p_time_end < p_time_start
    and (p_status in ('started', 'paused')
         or (p_status = 'completed'
             and exists (select 1 from public.visit_events e
                         where e.visit_id = p_visit_id and e.to_status = 'completed'
                           and (e.occurred_at at time zone 'Europe/Zurich')::date = p_date))),
    false)
$$;
revoke all on function private.field_day_carried(uuid, date, time, time, text, date) from public, anon;
grant execute on function private.field_day_carried(uuid, date, time, time, text, date) to authenticated;
comment on function private.field_day_carried(uuid, date, time, time, text, date) is
  'BK-e1c (0149, ADR-203 amendment): true when a midnight-crossing visit of the day before p_date is still running '
  '(started, paused) or was completed on p_date (Europe/Zurich). Used by field_visits and field_safety_alerts. Display only.';

-- 2. field_visits: the predicate, the flag, carried first --------------------------------------------------------------
do $$
declare
  def text := pg_get_functiondef('public.field_visits(date)'::regprocedure);
  w0  text := E'    and v.visit_date = p_date\n';
  w1  text := E'    and (v.visit_date = p_date\n'
           || E'         or private.field_day_carried(v.id, v.visit_date, v.time_start, v.time_end, v.status, p_date))  -- BK-E1C\n';
  s0  text := E'v.order_take_id is not null  -- BK-E1B-F (UXR-237, UXR-239)\n  from public.care_visits v';
  s1  text := E'v.order_take_id is not null,  -- BK-E1B-F (UXR-237, UXR-239)\n'
           || E'         private.field_day_carried(v.id, v.visit_date, v.time_start, v.time_end, v.status, p_date)  -- BK-E1C\n'
           || E'  from public.care_visits v';
  r0  text := E', from_take boolean)\n LANGUAGE sql';
  r1  text := E', from_take boolean, carried_from_previous_day boolean)\n LANGUAGE sql';
  o0  text := 'order by v.time_start nulls last, v.id';
  o1  text := 'order by (v.visit_date <> p_date) desc, v.time_start nulls last, v.id';
  frag text;
begin
  if position('BK-E1C' in def) > 0 then
    return;
  end if;
  foreach frag in array array[w0, s0, r0, o0] loop
    if (length(def) - length(replace(def, frag, ''))) / length(frag) <> 1 then
      raise exception '0149: field_visits patch did not match exactly once: %', frag;
    end if;
  end loop;
  def := replace(def, w0, w1);
  def := replace(def, s0, s1);
  def := replace(def, r0, r1);
  def := replace(def, o0, o1);
  execute 'drop function public.field_visits(date)';
  execute def;
end;
$$;
revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;

-- 3. field_safety_alerts: the same predicate (0073 otherwise unchanged; same return type) ------------------------------
create or replace function public.field_safety_alerts(p_date date)
returns table (visit_id uuid, case_id uuid, category_code text, category_label text, category_class text, help_text text,
               refuses_codes boolean, value text, note text, source text, recorded_at timestamptz, actor_kind text,
               actor_name text)
language sql stable security definer set search_path = ''
as $$
  select v.id, v.case_id, cat.code, cat.label, cat.class, cat.help_text, cat.refuses_codes,
         l.value, l.note, l.source, l.created_at, a.kind,
         case when a.kind in ('team', 'coordination') then
           (select p.display_name from public.member_profiles p
            where p.organization_id = v.organization_id and p.user_id = l.actor_id)
         end
  from public.care_visits v
  cross join lateral private.active_alert_categories(v.visit_date) cat
  left join lateral (
    select x.id, x.value, x.note, x.source, x.created_at, x.actor_id
    from public.case_safety_alert_values x
    join public.safety_alert_categories xc on xc.id = x.category_id
    where x.case_id = v.case_id and x.organization_id = v.organization_id and xc.code = cat.code
    order by x.seq desc
    limit 1
  ) l on true
  cross join lateral (select case
      when l.id is null then null
      when l.actor_id = (select auth.uid()) then 'me'
      when exists (select 1 from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = l.actor_id) then 'team'
      when exists (select 1 from public.organization_memberships om
                   where om.organization_id = v.organization_id and om.user_id = l.actor_id
                     and om.role in ('admin', 'coach', 'operations')) then 'coordination'
      else 'former'
    end as kind) a
  where p_date is not null
    and (v.visit_date = p_date
         or private.field_day_carried(v.id, v.visit_date, v.time_start, v.time_end, v.status, p_date))  -- BK-E1C (CGR-257)
    and v.case_id is not null
    and (select auth.uid()) is not null
    and private.reads_visit(v.id)
  order by (v.visit_date <> p_date) desc, v.time_start nulls last, v.id, cat.class desc, cat.code
$$;
revoke all on function public.field_safety_alerts(date) from public, anon;
grant execute on function public.field_safety_alerts(date) to authenticated;
comment on function public.field_safety_alerts(date) is
  'DOOR1-3/-4 (0073), BK-e1c (0149): per visit on p_date, or carried onto p_date (private.field_day_carried, the '
  'predicate of field_visits), that the caller reads (private.reads_visit: the team, or the covering member while her '
  'cover runs) and per active category, the latest value with who, when and source; nulls when none ("nicht '
  'erfasst"). Display only.';
