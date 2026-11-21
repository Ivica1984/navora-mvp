-- BK-e1c / R3b, CGR-257, UXR-248 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1–C3; ADR-203 (22)).
-- Between 00:00 and the end of a night shift the carer's «Heute» on /field must show the running night visit itself,
-- with the client's safety alerts. Until now `public.field_visits(p_date)` and `public.field_safety_alerts(p_date)`
-- listed a visit only on its `visit_date`, so the running visit sat on the previous day's page.
--
-- 1. `private.field_day_includes(...)`: the one predicate of a /field day. A visit belongs to day `p_date` when it is
--    dated `p_date`, or when it is dated `p_date - 1`, crosses midnight (`time_end < time_start`, the repository's
--    existing rule, 0038/0048/0069/0071) and is running (`started` or `paused`). Not pulled forward: completed, planned,
--    cancelled, `on_the_way` (PROPOSED, `cra` decides), a day visit, anything older than the previous day.
-- 2. `field_visits` uses it, returns `carried_from_previous_day boolean` and lists the carried visit first.
-- 3. `field_safety_alerts` uses the same predicate, so a carried visit never shows without its alerts (CGR-257).
--
-- Display only: no rule about starting, completing, covering, releasing or billing changes; every command keeps its own
-- checks (e.g. the VIS1 day rule, 0089). Scope unchanged: the same joins, RLS and `private.reads_visit` as before.
-- Idempotent: each patch carries the marker BK-E1C and is skipped when present; it must match exactly once, otherwise
-- the migration stops.

create or replace function private.field_day_includes(p_visit_date date, p_time_start time, p_time_end time,
                                                      p_status text, p_date date)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_date is not null and p_visit_date is not null
     and (p_visit_date = p_date
          or (p_visit_date = p_date - 1
              and p_time_start is not null and p_time_end is not null and p_time_end < p_time_start
              and p_status in ('started', 'paused')))
$$;
comment on function private.field_day_includes(date, time, time, text, date) is
  'BK-e1c (0149, CGR-257): the visits a /field day lists: its own, plus a running (started/paused) night visit of the '
  'previous day that crosses midnight. Used by field_visits and field_safety_alerts. Display only.';
revoke all on function private.field_day_includes(date, time, time, text, date) from public, anon;
grant execute on function private.field_day_includes(date, time, time, text, date) to authenticated;

do $$
declare
  def text := pg_get_functiondef('public.field_visits(date)'::regprocedure);
  f1  text := E'         v.order_take_id is not null  -- BK-E1B-F (UXR-237, UXR-239)\n  from public.care_visits v';
  f2  text := E', from_take boolean)\n LANGUAGE sql';
  f3  text := E'    and v.visit_date = p_date\n';
  f4  text := E'  order by v.time_start nulls last, v.id;';
begin
  if position('BK-E1C' in def) > 0 then
    return;
  end if;
  if (length(def) - length(replace(def, f1, ''))) / length(f1) <> 1
     or (length(def) - length(replace(def, f2, ''))) / length(f2) <> 1
     or (length(def) - length(replace(def, f3, ''))) / length(f3) <> 1
     or (length(def) - length(replace(def, f4, ''))) / length(f4) <> 1 then
    raise exception '0149: field_visits patch did not match exactly once';
  end if;
  def := replace(def, f1, E'         v.order_take_id is not null,  -- BK-E1B-F (UXR-237, UXR-239)\n'
                       || E'         v.visit_date < p_date  -- BK-E1C (CGR-257, UXR-248): carried from the previous day\n'
                       || E'  from public.care_visits v');
  def := replace(def, f2, E', from_take boolean, carried_from_previous_day boolean)\n LANGUAGE sql');
  def := replace(def, f3, E'    and v.visit_date between p_date - 1 and p_date\n'
                       || E'    and private.field_day_includes(v.visit_date, v.time_start, v.time_end, v.status, p_date)  -- BK-E1C\n');
  def := replace(def, f4, E'  order by v.visit_date, v.time_start nulls last, v.id;');
  execute 'drop function public.field_visits(date)';
  execute def;
end;
$$;
revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;

do $$
declare
  def text := pg_get_functiondef('public.field_safety_alerts(date)'::regprocedure);
  f1  text := E'  where p_date is not null and v.visit_date = p_date and v.case_id is not null\n';
begin
  if position('BK-E1C' in def) > 0 then
    return;
  end if;
  if (length(def) - length(replace(def, f1, ''))) / length(f1) <> 1 then
    raise exception '0149: field_safety_alerts patch did not match exactly once';
  end if;
  def := replace(def, f1, E'  where p_date is not null and v.visit_date between p_date - 1 and p_date\n'
                       || E'    and private.field_day_includes(v.visit_date, v.time_start, v.time_end, v.status, p_date)  -- BK-E1C (CGR-257)\n'
                       || E'    and v.case_id is not null\n');
  execute def;
end;
$$;
revoke all on function public.field_safety_alerts(date) from public, anon;
grant execute on function public.field_safety_alerts(date) to authenticated;
