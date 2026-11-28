-- PLAN3-9 (2) (`uxa` UXR-103, adopted by the PO note 2026-11-06 06:30; not a PLAN3 acceptance condition): one place
-- decides a day-plan line. ADR-160.
--
-- Before (IMPLEMENTED in 0097/0109/0116): `/team/vorschlaege` listed every open proposal of the team one by one with
-- its own "Bestätigen", the open lines of a PLAN3 day plan included, so one line had two places to be decided.
-- Now (IMPLEMENTED in this migration): one reader
--   * open_day_plan_lines(team) → (suggestion_id, plan_date): for every proposal `open_suggestions` returns to the
--     caller that is a PLAN3 day-plan line, the day of its day plan (`day_plan_lines.plan_date`). The app groups the
--     lines by that day into one row per day plan and links the row to `/team/tagesplan`.
-- The reader is built on `open_suggestions` itself, so it returns exactly the open lines the caller already reads
-- there (active members of that team only: LEAVE1-3, `is_org_member`, `is_team_member`; no confirmer; nothing
-- decided; no line closed by a fresh request, PLAN3-15) and adds one date per line. No name, no member, no client,
-- no visit column: the date is the one the team itself asked for. No new read is granted to any role beyond what
-- `open_suggestions` and `day_plan` already give the same caller.
-- The LEAVE1-3 guard is repeated in this reader's own body (as every definer read model carries it; pgTAP 074 checks
-- the catalogue), although `open_suggestions` already applies it.
-- `confirm_suggestion` and `confirm_suggestions` are not changed: `/team/tagesplan` decides its lines through them.
-- No table, so no RLS policy, column grant or audit trigger is added; the reader writes nothing.
-- Idempotent: `create or replace`, grants repeated.

create or replace function public.open_day_plan_lines(p_team_id uuid)
returns table (suggestion_id uuid, plan_date date)
language sql stable security definer set search_path = ''
as $$
  select o.suggestion_id, dl.plan_date
  from public.open_suggestions(p_team_id) o
  join public.day_plan_lines dl on dl.suggestion_id = o.suggestion_id
  where o.agent_key = 'plan3_day_proposal'
    and not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
  order by dl.plan_date, o.suggestion_id
$$;
revoke all on function public.open_day_plan_lines(uuid) from public, anon;
grant execute on function public.open_day_plan_lines(uuid) to authenticated;
comment on function public.open_day_plan_lines(uuid) is
  'PLAN3-9 (2): the day (plan_date) of each open PLAN3 day-plan line that open_suggestions returns to the caller for '
  'one team, so the confirm screen shows one row per day plan instead of deciding its lines. No name, no other column.';
