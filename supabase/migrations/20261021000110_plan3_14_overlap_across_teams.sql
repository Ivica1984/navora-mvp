-- PLAN3-14: a member is busy with every visit she is responsible for, in any team; overlap is checked again at confirm
-- (ADR-146). PO brief docs/agents/briefs/PLAN3.md PLAN3-14 (added 2026-11-05 14:50, `cra` CGR-136, advisory S2; PO
-- decision, product authority, no clinical rule, no threshold). Stage 0 of D-35: synthetic data only, no AI service.
--
-- Before (IMPLEMENTED in 0109): `private.plan3_lines` counted as busy only the visits of the asking team, so a member who
-- accepted a COVER1 visit of another team (0028: the visit keeps its team, the covering nurse becomes its responsible
-- member) or who belongs to two teams (0003) could be proposed for two clients at the same time. Confirming a line
-- re-ran the J3 checks (membership, qualification, contract, absence) but not the overlap.
-- Now (IMPLEMENTED in this migration):
--   1. `private.plan3_other_team_busy(org, member, date, team)`: the planned intervals of every non-cancelled visit of
--      the organisation that day whose responsible member is she, outside the given team. Definer, granted to nobody:
--      it returns only time ranges to the two functions below, never to a caller.
--   2. `private.plan3_lines` adds that busy time to each member's team-scoped busy time before the run. The asking
--      team still gets only the reason `overlap` (or the next member); no other team's client, case, visit or time is
--      written to a line or returned (PLAN3-8). The planned load (`lod`) keeps its team scope (PLAN3-4).
--   3. `private.aig1_apply`: for a day-plan line (a `day_plan_lines` row exists for the suggestion), confirming or
--      correcting it first refuses `overlap` when the chosen member has, by now, another non-cancelled visit of the
--      organisation that day whose planned interval overlaps this one (any team, hand assignment included). The value
--      stays open, the visit unassigned (as for `absent`); in a ticked list the other lines are set (AIG1-5 unchanged).
--      A transaction-scoped advisory lock per member and day serialises two concurrent PLAN3 confirms for one member.
--      Other AIG1 agents' values are unchanged (no day-plan line, no extra check).
--   4. `public.day_plan_load` gains `other_team_visits boolean` ("weitere Einsätze in anderen Teams", wording `uxa`):
--      only whether such a visit exists; no count, client or time. Minutes keep the team scope. The return type
--      changes, so the function is dropped and created again with the same grants.
-- Not in this migration (PLANNED, ADR-145/146): the `/team` screen (part (b)), the hand-assignment (J3) path taking the
-- same advisory lock (OPEN, see ADR-146 deviation 2).
-- Idempotent: `create or replace`, `drop function if exists`.

-- 1. Busy time outside the asking team (PLAN3-14 (1)) ------------------------------------------------------------------------
create or replace function private.plan3_other_team_busy(p_org uuid, p_user uuid, p_date date, p_team uuid)
returns tstzmultirange
language sql stable security definer set search_path = ''
as $$
  select coalesce(range_agg(private.visit_interval(x)), '{}'::tstzmultirange)
  from public.care_visits x
  where x.organization_id = p_org and x.visit_date = p_date and x.status <> 'cancelled'
    and x.responsible_user_id = p_user and x.team_id is distinct from p_team
$$;
revoke all on function private.plan3_other_team_busy(uuid, uuid, date, uuid) from public, anon, authenticated;
comment on function private.plan3_other_team_busy(uuid, uuid, date, uuid) is
  'PLAN3-14 (1): planned intervals of a member''s non-cancelled visits of that day in every other team of the '
  'organisation (COVER1 cover, a second membership). Internal: only plan3_lines reads it; nothing reaches a caller.';

-- 2. The lines of one team and day, now with the busy time of every team (PLAN3-1, PLAN3-2, PLAN3-8, PLAN3-14) -----------------
create or replace function private.plan3_lines(p_team uuid, p_date date, p_include_assigned boolean)
returns table (visit_id uuid, case_id uuid, member_id uuid, reason text, known_visits integer,
               not_found_reason text, assigned_before uuid)
language plpgsql stable security definer set search_path = ''
as $$
declare
  org   uuid := private.team_organization(p_team);
  today date := (private.at_zurich(private.now()))::date;
  mem   uuid[];
  lod   integer[] := '{}';
  bus   tstzmultirange[] := '{}';
  v     public.care_visits%rowtype;
  pn    uuid;
  dp    uuid;
  rng   tstzrange;
  cands jsonb;
  pick  jsonb;
  f     text;
  k     integer;
  i     integer;
  m     uuid;
begin
  select coalesce(array_agg(tm.user_id order by tm.user_id::text), '{}') into mem
  from public.team_memberships tm where tm.team_id = p_team;
  -- Each member's day before the run: the team's visits of that day assigned to her that are not re-proposed now
  -- (load and busy time), plus, for the busy time only, her visits of that day in every other team (PLAN3-14 (1)).
  for i in 1 .. cardinality(mem) loop
    lod[i] := (select coalesce(sum(private.plan3_visit_minutes(x)), 0)::int
               from public.care_visits x
               where x.team_id = p_team and x.visit_date = p_date and x.status <> 'cancelled'
                 and x.responsible_user_id = mem[i] and not private.plan3_visit_open(x, p_include_assigned));
    bus[i] := (select coalesce(range_agg(private.visit_interval(x)), '{}'::tstzmultirange)
               from public.care_visits x
               where x.team_id = p_team and x.visit_date = p_date and x.status <> 'cancelled'
                 and x.responsible_user_id = mem[i] and not private.plan3_visit_open(x, p_include_assigned))
              + private.plan3_other_team_busy(org, mem[i], p_date, p_team);
  end loop;

  for v in
    select x.* from public.care_visits x
    where x.team_id = p_team and x.visit_date = p_date and private.plan3_visit_open(x, p_include_assigned)
    order by x.time_start nulls last, x.time_end nulls last, x.id::text
  loop
    select c.primary_nurse_id, c.deputy_nurse_id into pn, dp from public.cases c where c.id = v.case_id;
    rng := private.visit_interval(v);
    cands := '[]'::jsonb;
    for i in 1 .. cardinality(mem) loop
      f := case
        when not private.may_perform_visit(p_team, mem[i], 0, false)
             or not private.adm2_in_contract(org, mem[i], v.visit_date) then 'not_active'
        when not private.may_perform_visit(p_team, mem[i], v.planned_minutes_b, v.is_needs_assessment) then 'needs_rn'
        when private.member_absent_during(p_team, mem[i], lower(rng), upper(rng)) then 'absent'
        when bus[i] && rng then 'overlap'
      end;
      k := 0;
      if f is null then
        -- Completed visits to this client in the last 90 days whose performer (first start event, F6) is she.
        select count(*)::int into k from public.care_visits h
        where h.case_id = v.case_id and h.team_id = p_team and h.status = 'completed'
          and h.visit_date between today - 90 and today and private.visit_performer(h.id) = mem[i];
      end if;
      cands := cands || jsonb_build_array(jsonb_build_object('id', mem[i], 'fail', f, 'known', k, 'load', lod[i]));
    end loop;
    pick := private.plan3_choose(cands, pn, dp);
    m := (pick ->> 'member')::uuid;
    if m is not null then
      i := array_position(mem, m);
      lod[i] := lod[i] + private.plan3_visit_minutes(v);
      bus[i] := bus[i] + tstzmultirange(rng);
    end if;
    visit_id := v.id;
    case_id := v.case_id;
    member_id := m;
    reason := pick ->> 'reason';
    known_visits := case when m is null then null else (pick ->> 'known')::int end;
    not_found_reason := pick ->> 'not_found_reason';
    assigned_before := v.responsible_user_id;
    return next;
  end loop;
end;
$$;
revoke all on function private.plan3_lines(uuid, date, boolean) from public, anon, authenticated;
comment on function private.plan3_lines(uuid, date, boolean) is
  'PLAN3-1/-2/-3/-14: the proposal for one team and day, computed (writes nothing). Every PLAN3-2 limit is an existing '
  'check (ADM2-6/LEAVE1 membership and access, ADM2 contract, J3 RN rule, ABS1 absence) plus the overlap with her '
  'visits of that day in any team of the organisation (PLAN3-14). Returns only that team''s visits and cases.';

-- 3. Confirm: overlap again, for day-plan lines only (PLAN3-14 (2)) -------------------------------------------------------------
-- Returns 'overlap' when the member has another non-cancelled visit of the organisation that day overlapping this one.
create or replace function private.plan3_confirm_overlaps(p_visit_id uuid, p_user uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v public.care_visits%rowtype;
begin
  select * into v from public.care_visits x where x.id = p_visit_id;
  if not found or p_user is null then
    return false;                                    -- the consuming command reports a missing visit (not_open)
  end if;
  -- Serialise two PLAN3 confirms for the same member and day (two ticked lists at once).
  perform pg_advisory_xact_lock(hashtextextended('plan3_busy:' || p_user::text || ':' || v.visit_date::text, 0));
  return exists (
    select 1 from public.care_visits x
    where x.organization_id = v.organization_id and x.visit_date = v.visit_date and x.status <> 'cancelled'
      and x.responsible_user_id = p_user and x.id <> v.id
      and private.visit_interval(x) && private.visit_interval(v));
end;
$$;
revoke all on function private.plan3_confirm_overlaps(uuid, uuid) from public, anon, authenticated;
comment on function private.plan3_confirm_overlaps(uuid, uuid) is
  'PLAN3-14 (2): whether the member has, by now, another non-cancelled visit that day (any team) whose planned interval '
  'overlaps the visit. Internal; used by aig1_apply for day-plan lines only.';

create or replace function private.aig1_apply(p_s public.ai_suggestions, p_value jsonb, p_actor uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  f    public.ai_agent_fields%rowtype;
  prev jsonb;
  u    uuid;
  dpl  boolean;
begin
  select * into f from public.ai_agent_fields x where x.agent_key = p_s.agent_key and x.field = p_s.field;
  -- The value the record holds from this suggestion's last applied confirmation (a re-check may replace only that).
  select c.final_value into prev from public.ai_confirmations c
  where c.suggestion_id = p_s.id and c.outcome in ('confirmed', 'corrected') order by c.seq desc limit 1;
  dpl := exists (select 1 from public.day_plan_lines dl where dl.suggestion_id = p_s.id);
  -- PLAN3-5 (0109): before its first applied confirmation, a day-plan line expects the member the visit had when it
  -- was proposed (null for an unassigned visit), so "auch zugewiesene neu vorschlagen" lines can be decided.
  if prev is null and dpl then
    select to_jsonb(dl.assigned_before::text) into prev from public.day_plan_lines dl where dl.suggestion_id = p_s.id;
  end if;
  if f.target_table = 'care_visits' and f.target_column = 'responsible_user_id' and p_s.entity_type = 'care_visits' then
    begin
      u := (p_value #>> '{}')::uuid;
    exception when invalid_text_representation then
      raise exception 'the value must be a member id' using errcode = '22023';
    end;
    -- PLAN3-14 (2, 0110): a day-plan line is refused when the member is busy at that time by now, in any team.
    if dpl and private.plan3_confirm_overlaps(p_s.entity_id, u) then
      return 'overlap';
    end if;
    return private.aig1_apply_visit_responsible(p_s.entity_id, u, (prev #>> '{}')::uuid, p_actor);
  end if;
  raise exception 'no consuming command for %.% (AIG1-3)', f.target_table, f.target_column using errcode = '0A000';
end;
$$;
revoke all on function private.aig1_apply(public.ai_suggestions, jsonb, uuid) from public, anon, authenticated;

-- 4. The day load with "weitere Einsätze in anderen Teams" (PLAN3-4, PLAN3-14 (1)) ---------------------------------------------
drop function if exists public.day_plan_load(uuid, date);
create function public.day_plan_load(p_team_id uuid, p_date date)
returns table (member_id uuid, member_name text, minutes_now integer, minutes_with_proposal integer,
               other_team_visits boolean)
language sql stable security definer set search_path = ''
as $$
  with newest as (
    select dl.proposal_id from public.day_plan_lines dl
    where dl.team_id = p_team_id and dl.plan_date = p_date
    order by dl.created_at desc, dl.suggestion_id limit 1
  ), open_lines as (
    select v.responsible_user_id, private.plan3_visit_minutes(v) as minutes, (s.proposed_value #>> '{}')::uuid as proposed
    from newest nw
    join public.day_plan_lines dl on dl.proposal_id = nw.proposal_id
    join public.ai_suggestions s on s.id = dl.suggestion_id and not s.not_found
    join public.care_visits v on v.id = dl.visit_id
    where not exists (select 1 from public.ai_confirmations k where k.suggestion_id = s.id)
      and v.status = 'planned' and v.suspended_at is null and v.covered_by is null
  )
  select tm.user_id, private.member_name(t.organization_id, tm.user_id), now_m.m,
         now_m.m
         - coalesce((select sum(o.minutes) from open_lines o
                     where o.responsible_user_id = tm.user_id and o.proposed <> tm.user_id), 0)::int
         + coalesce((select sum(o.minutes) from open_lines o
                     where o.proposed = tm.user_id and o.responsible_user_id is distinct from tm.user_id), 0)::int,
         exists (select 1 from public.care_visits x
                 where x.organization_id = t.organization_id and x.visit_date = p_date and x.status <> 'cancelled'
                   and x.responsible_user_id = tm.user_id and x.team_id <> t.id)
  from public.teams t
  join public.team_memberships tm on tm.team_id = t.id
  cross join lateral (
    select coalesce(sum(private.plan3_visit_minutes(x)), 0)::int as m from public.care_visits x
    where x.team_id = t.id and x.visit_date = p_date and x.status <> 'cancelled' and x.responsible_user_id = tm.user_id
  ) now_m
  where t.id = p_team_id and exists (select 1 from newest)
    and not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(t.organization_id) and private.is_team_member(t.id)
    and not private.access_ended(tm.user_id)
  order by private.member_name(t.organization_id, tm.user_id) nulls last, tm.user_id::text
$$;
revoke all on function public.day_plan_load(uuid, date) from public, anon;
grant execute on function public.day_plan_load(uuid, date) to authenticated;
comment on function public.day_plan_load(uuid, date) is
  'PLAN3-4/-14: per member of the team, planned minutes of that team and day now and with the newest proposal''s '
  'undecided lines, and whether she has visits that day in another team ("weitere Einsätze in anderen Teams"; no '
  'count, client or time). Shown to the team; NAVORA sets no maximum (D-23).';
