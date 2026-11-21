-- VIS1 follow-up (PO brief docs/agents/briefs/VIS1.md: VIS1-9 from `cra` CGR-90, VIS1-8 from `cra` CGR-89; ADR-112).
-- Visit/schedule facts only (the visit date, the Zurich calendar day, DAY-1; whether another visit exists on a date).
-- No clinical rule, no tolerance, no threshold, no count rule, no "replacement needed" logic.
--
-- Before (IMPLEMENTED defect, CGR-90): 0089 put the day rule into the commands only. `authenticated` keeps the column
--   grant `update (status) on care_visits` (0003:184, 0004:135), and `private.enforce_visit_transition` (0038) checks
--   only the state pair, suspension and qualification. A direct `update care_visits set status = 'started'` on next
--   week's visit by a team member therefore still passed: the CGR-87 hazard on a second write path.
-- Now (IMPLEMENTED in this migration):
--   1. VIS1-9: `private.visit_status_day_refusal(visit, old status, new status)` (SECURITY DEFINER, no table read
--      beyond the visit's own `started` events) returns the same outcomes as 0089 for a status change written as
--      `authenticated`: `not_today` for a change out of `planned` or `on_the_way` into `on_the_way`, `started`,
--      `no_show` or `interrupted` on a visit dated after today (Europe/Zurich); `started_before_date` for a change
--      into `completed` of a visit dated after today or started on a Zurich day before its date. Pause and resume
--      (started <-> paused) stay as they are (0089). `private.enforce_visit_transition` calls it in its
--      `authenticated` branch and raises SQLSTATE 23514 with the outcome as message, so the statement fails and no
--      row changes. The column grant stays: the security-invoker commands (`private.transition_visit`, 0007) write
--      status through it, so withdrawing it would break depart, start, pause, resume and complete.
--      Past- and today-dated visits are unchanged (VIS1-6). The commands keep their own earlier check (0089), so a
--      refusal through a command still returns its outcome code and writes its audit row; the trigger is the floor.
--   2. VIS1-8: `public.visit_move_leaves_other_visit(visit)` (SECURITY DEFINER, stable) answers one yes/no for the
--      "Heute machen" confirmation: is another visit of the same client (in NAVORA the client is the case, there is
--      no cross-case identity, D-9) still on the date this visit would leave (its current `visit_date`), whichever
--      team holds it? Counted: every other visit of the case on that date that is not `cancelled` (a removed visit
--      is deleted, 0014). Only a team member of the visit (`private.visit_for_team`) gets an answer; anyone else gets
--      null. The answer carries no time, no team, no name and no count, so another team's visit is never shown and
--      never makes the sentence say "kein Einsatz" (VIS1-8 (2)). No new read permission on any table.
-- Unchanged: `reschedule_visit`, `visit_overdue`, its threshold (D-28, PROVISIONAL), the signal job, every permission.
-- Idempotent: create or replace only; re-running this file changes nothing.

-- 1. VIS1-9: the day rule for a status written as `authenticated` ------------------------------------------------------
create or replace function private.visit_status_day_refusal(p_visit_id uuid, p_visit_date date, p_old text, p_new text)
returns text
language plpgsql stable security definer set search_path = ''
as $$
declare
  today      date := (private.at_zurich(private.now()))::date;
  started_on date;
begin
  if p_visit_date is null or p_old is not distinct from p_new then
    return null;
  end if;
  if p_new in ('on_the_way', 'started', 'no_show', 'interrupted') and p_old in ('planned', 'on_the_way') then
    if p_visit_date > today then
      return 'not_today';
    end if;
  elsif p_new = 'completed' then
    select (private.at_zurich(max(e.occurred_at)))::date into started_on
    from public.visit_events e
    where e.visit_id = p_visit_id and e.event_type = 'started';
    if p_visit_date > today or (started_on is not null and started_on < p_visit_date) then
      return 'started_before_date';
    end if;
  end if;
  return null;
end;
$$;
revoke all on function private.visit_status_day_refusal(uuid, date, text, text) from public, anon;
-- The trigger runs as the writing role; it needs execute. The function reads only the visit's own `started` events
-- and returns an outcome code, nothing else.
grant execute on function private.visit_status_day_refusal(uuid, date, text, text) to authenticated;
comment on function private.visit_status_day_refusal(uuid, date, text, text) is
  'VIS1-9 / ADR-112 / CGR-90: the 0089 day rule for a status change written as authenticated (direct UPDATE or a '
  'security-invoker command): not_today, started_before_date or null. Called by private.enforce_visit_transition.';

create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  vis1_out text;
begin
  if current_user = 'authenticated' and new.status is distinct from old.status then
    if not ((old.status, new.status) in (
      ('planned',    'on_the_way'),
      ('planned',    'started'),
      ('on_the_way', 'started'),
      ('started',    'paused'),
      ('paused',     'started'),
      ('started',    'completed')
    )) then
      raise exception 'visit transition % -> % is not allowed', old.status, new.status
        using errcode = '23514';
    end if;
    if old.suspended_at is not null then
      raise exception 'the visit is suspended because the case is paused' using errcode = '23514';
    end if;
    -- VIS1-9 / CGR-90: the visit's day on every write path (the later of the old and new date, so a combined write
    -- cannot move the date and start in one statement).
    vis1_out := private.visit_status_day_refusal(old.id, greatest(old.visit_date, new.visit_date), old.status, new.status);
    if vis1_out is not null then
      raise exception '%', vis1_out using errcode = '23514', hint = 'VIS1: the visit is worked on its day (Europe/Zurich)';
    end if;
    -- CGR-12: every transition into `started` (first start and resume) and into `completed`.
    if new.status in ('started', 'completed')
       and (coalesce(new.planned_minutes_b, 0) > 0 or new.is_needs_assessment)
       and not private.is_registered_nurse(new.team_id, (select auth.uid())) then
      raise exception 'category B and needs-assessment visits are started, resumed and completed by a registered nurse'
        using errcode = 'NV001';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_visit_transition() from public, anon, authenticated;

-- 2. VIS1-8: what the move leaves behind (one yes/no) ------------------------------------------------------------------
create or replace function public.visit_move_leaves_other_visit(p_visit_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.care_visits x
    where x.case_id = v.case_id and x.id <> v.id and x.visit_date = v.visit_date
      and x.status is distinct from 'cancelled')
  from private.visit_for_team(p_visit_id) v
  where v.id is not null
$$;
revoke all on function public.visit_move_leaves_other_visit(uuid) from public, anon;
grant execute on function public.visit_move_leaves_other_visit(uuid) to authenticated;
comment on function public.visit_move_leaves_other_visit(uuid) is
  'VIS1-8 / ADR-112 / CGR-89: for a team member of the visit, whether another visit of the same case (any team, not '
  'cancelled) is on the visit''s current date; null for anyone else. Yes/no only: no time, team, name or count.';
