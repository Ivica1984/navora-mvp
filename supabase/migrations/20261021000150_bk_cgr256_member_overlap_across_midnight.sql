-- CGR-256 (`cra` 2026-11-18 13:29, advisory S1 before real clients; brief docs/agents/briefs/BK.md §PO amendments 13:39
-- (2), 14:39 (2), 20:39, 21:39: first follow-up of slice BK-e; ADR-203 (23)). The PLAN3-16 member-overlap fact compared
-- only visits of the same `visit_date`, so a 22:00–07:00 visit of a member dated D (e.g. the visit a night take writes,
-- BK-7) was never seen beside her 06:00 visit dated D + 1, in either direction: the hand path's `member_overlap` and the
-- form's read said «free» although she is still on her night.
--
-- Change (display fact only, the definition of «overlap» is unchanged: `private.visit_interval(x) && ...`):
--   1. `private.member_visit_overlap`: candidates are her non-cancelled visits dated D - 1, D or D + 1 instead of D only.
--      The interval test decides; `visit_interval` already ends a visit with `time_end < time_start` on the next day
--      (0038/0048/0069). Locks unchanged: the person lock `order_take_member:<member>` first (BK-E1B-L, CGR-233), then
--      `plan3_busy:<member>:<day>`. The person lock alone serialises every reader of this function for one member, on
--      any day, so two writers on adjacent days are still serialised (the day lock was never the cross-day guard).
--   2. `public.member_slot_overlap` (the form's read): the same three days. Its own null for `end <= start` (an
--      incomplete slot, PLAN3-16) is unchanged; the form still cannot ask about a night slot itself.
-- Readers: every hand path (plan_visit, take_open_visit, reschedule_visit, move_visit_to_today) and the PLAN3-14 confirm
-- (`private.plan3_confirm_overlaps`, used by `aig1_apply` for day-plan lines), which therefore now also refuses a day-plan
-- line that meets a member's night of the previous day (the existing `overlap` refusal, same rule, one more case it sees).
-- Named limit: a visit whose interval reaches beyond the day after its date (start without end and more than about 24 h
-- of planned minutes) is still only seen on D - 1 .. D + 1 (UNKNOWN whether such a visit exists; no rule invented).
-- No rest-time rule (UNKNOWN, Clinical Owner, H-10). Result shapes, signatures, grants and locks are unchanged.
-- Idempotent: create or replace with the full body (marker BK-CGR256).

create or replace function private.member_visit_overlap(p_visit_id uuid, p_user uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v public.care_visits%rowtype;
begin
  select * into v from public.care_visits x where x.id = p_visit_id;
  if not found or p_user is null then
    return false;
  end if;
  -- BK-E1B-L (CGR-233): the take's person lock first, so a take of this member and this reading serialise.
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || p_user::text, 0));
  -- PLAN3-14 / PLAN3-16: serialise every assignment of one member and day (PLAN3 confirm and the hand paths).
  perform pg_advisory_xact_lock(hashtextextended('plan3_busy:' || p_user::text || ':' || v.visit_date::text, 0));
  -- BK-CGR256: the previous and the next day too, so a visit across midnight meets the other day's visits.
  return exists (
    select 1 from public.care_visits x
    where x.organization_id = v.organization_id
      and x.visit_date between v.visit_date - 1 and v.visit_date + 1
      and x.status <> 'cancelled'
      and x.responsible_user_id = p_user and x.id <> v.id
      and private.visit_interval(x) && private.visit_interval(v));
end;
$$;
revoke all on function private.member_visit_overlap(uuid, uuid) from public, anon, authenticated;
comment on function private.member_visit_overlap(uuid, uuid) is
  'PLAN3-14 (2) / PLAN3-16 (ADR-146, ADR-161): whether the member has another non-cancelled visit (any team of the '
  'organisation, dated the day before, the same day or the day after, BK-CGR256 / CGR-256) whose planned interval '
  'overlaps the visit. Takes the order_take_member person lock (BK-e1b CGR-233, ADR-203 (19), marker BK-E1B-L) and '
  'then the plan3_busy advisory lock on member and day. Internal: no permission check; nothing but the yes/no reaches '
  'a caller.';

create or replace function public.member_slot_overlap(
  p_case_id uuid, p_visit_id uuid, p_member_id uuid, p_visit_date date, p_time_start time, p_time_end time)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  tm  uuid;
  org uuid;
  ex  uuid;
  rng tstzrange;
begin
  -- LEAVE1-3: nothing for a person whose access ended.
  if (select auth.uid()) is null or private.access_ended((select auth.uid())) or p_member_id is null then
    return null;
  end if;
  -- The team as in VIS2 (client_visit_overlap): the visit's team for a team member of it (the visit is excluded),
  -- else the case's assigned team for a member of it.
  if p_visit_id is not null then
    select v.team_id, v.organization_id, v.id into tm, org, ex from private.visit_for_team(p_visit_id) v where v.id is not null;
    if tm is null or (p_case_id is not null
                      and not exists (select 1 from public.care_visits x where x.id = ex and x.case_id = p_case_id)) then
      return null;
    end if;
  elsif p_case_id is not null then
    select c.assigned_team_id, c.organization_id into tm, org from public.cases c where c.id = p_case_id;
    if tm is null or not private.is_org_member(org) or not private.is_team_member(tm) then
      return null;
    end if;
  else
    return null;
  end if;
  -- Only about a member of that team.
  if not exists (select 1 from public.team_memberships m where m.team_id = tm and m.user_id = p_member_id) then
    return null;
  end if;
  if p_visit_date is null or p_time_start is null or p_time_end is null or p_time_end <= p_time_start then
    return null;
  end if;
  rng := private.visit_interval(jsonb_populate_record(null::public.care_visits, jsonb_build_object(
           'visit_date', p_visit_date, 'time_start', p_time_start, 'time_end', p_time_end)));
  -- BK-CGR256: the previous and the next day too (a night of the day before still runs in the morning).
  return exists (
    select 1 from public.care_visits x
    where x.organization_id = org
      and x.visit_date between p_visit_date - 1 and p_visit_date + 1
      and x.status <> 'cancelled'
      and x.responsible_user_id = p_member_id and (ex is null or x.id <> ex)
      and private.visit_interval(x) && rng);
end;
$$;
revoke all on function public.member_slot_overlap(uuid, uuid, uuid, date, time, time) from public, anon;
grant execute on function public.member_slot_overlap(uuid, uuid, uuid, date, time, time) to authenticated;
comment on function public.member_slot_overlap(uuid, uuid, uuid, date, time, time) is
  'PLAN3-16 (ADR-161, `cra` CGR-137): whether a member of the team already has a visit (any team, not cancelled, dated '
  'the day before, the same day or the day after: BK-CGR256 / CGR-256) at a time overlapping [date + start, date + end). '
  'The team: the given visit''s (for its team members; it is excluded), else the case''s assigned team (for its '
  'members). yes/no only: no other team''s client, case, visit, team or time. LEAVE1-3 guarded; null for anyone else, a '
  'member outside that team or an incomplete slot. Never a refusal.';
