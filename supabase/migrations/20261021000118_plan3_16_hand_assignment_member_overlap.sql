-- PLAN3-16: a hand assignment says when the member already has a visit at that time (ADR-161). PO brief
-- docs/agents/briefs/PLAN3.md PLAN3-16 (added by po 2026-11-06 06:30; `cra` CGR-137, advisory S3; `aia` 20:20 condition:
-- a line of information on the existing act, no confirmation tap, no reason field). Not a PLAN3 acceptance condition;
-- before M9. No clinical rule and no threshold: NAVORA does not decide whether two visits of one person at one time are
-- allowed (one household, a joint visit can be intended); it only states the fact.
--
-- Before (IMPLEMENTED fact, `cra` CGR-137): after 0110 a PLAN3 line is refused for a member who already has an
-- overlapping visit in any team, but every hand path that gives a visit a member (`plan_visit` with a member,
-- `take_open_visit`, `reschedule_visit` / `move_visit_to_today` of a visit with a member) saved a second visit of the same
-- person at the same time without any notice, and none took the 0110 advisory lock.
-- Now (IMPLEMENTED in this migration):
--   1. `private.member_visit_overlap(visit, member)`: the one member-overlap definition of PLAN3-14 (2), moved out of
--      `private.plan3_confirm_overlaps` unchanged: every other non-cancelled visit of the organisation that day, any team,
--      whose responsible member is she and whose planned interval (`private.visit_interval`) meets the visit's. It takes
--      the 0110 transaction-scoped advisory lock on member and day (same key), so a hand path and a PLAN3 confirm for
--      one person and day are serialised. `plan3_confirm_overlaps` now returns it (one place decides).
--   2. `public.member_slot_overlap(case, visit, member, date, start, end)` (SECURITY DEFINER, stable): the form's read
--      before saving. yes/no only (no other team's client, case, visit, team or time). The team as in VIS2
--      (`client_visit_overlap`): the visit's team for its members (the visit excluded), else the case's assigned team
--      for its members; only about a member of that team. Anyone else, or an incomplete slot: null. LEAVE1-3 guarded.
--      No new read permission on any table.
--   3. The four commands take `p_member_overlap_shown boolean default null` (what the form showed) and record it as
--      `member_overlap_shown: true|false` (code value) on their existing audit row, as VIS2-4: `plan_visit` and
--      `take_open_visit` on their care_visits insert / update row (`private.write_audit_event`), `reschedule_visit` on
--      its `moved` row (`private.audit_visit_plan_move`); `move_visit_to_today` passes it on. Null records nothing.
--      An `ok` result carries `member_overlap` (true|false; null when the visit has no member): the server's own check
--      after the write, whatever the form showed. Never a refusal; every other refusal, check and grant unchanged.
--      Old signatures are dropped and recreated with the extra defaulted argument (no ambiguous overload).
-- Not in this migration: COVER1 `accept_cover` (cover across teams; not named by the brief, OPEN in ADR-161) and the
-- automatic PLAN2 series (`generate_case_plan`, the primary nurse by rule, not by hand).
-- Idempotent: create or replace; each command rewrite is skipped when the new signature exists; catalogue on conflict.

-- 1. The one member-overlap definition (PLAN3-14 (2), now shared) ---------------------------------------------------------------
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
  -- PLAN3-14 / PLAN3-16: serialise every assignment of one member and day (PLAN3 confirm and the hand paths).
  perform pg_advisory_xact_lock(hashtextextended('plan3_busy:' || p_user::text || ':' || v.visit_date::text, 0));
  return exists (
    select 1 from public.care_visits x
    where x.organization_id = v.organization_id and x.visit_date = v.visit_date and x.status <> 'cancelled'
      and x.responsible_user_id = p_user and x.id <> v.id
      and private.visit_interval(x) && private.visit_interval(v));
end;
$$;
revoke all on function private.member_visit_overlap(uuid, uuid) from public, anon, authenticated;
comment on function private.member_visit_overlap(uuid, uuid) is
  'PLAN3-14 (2) / PLAN3-16 (ADR-146, ADR-161): whether the member has another non-cancelled visit that day (any team of '
  'the organisation) whose planned interval overlaps the visit. Takes the plan3_busy advisory lock on member and day. '
  'Internal: no permission check; nothing but the yes/no reaches a caller.';

create or replace function private.plan3_confirm_overlaps(p_visit_id uuid, p_user uuid)
returns boolean
language sql security definer set search_path = ''
as $$
  select private.member_visit_overlap(p_visit_id, p_user)
$$;
revoke all on function private.plan3_confirm_overlaps(uuid, uuid) from public, anon, authenticated;
comment on function private.plan3_confirm_overlaps(uuid, uuid) is
  'PLAN3-14 (2): whether the member has, by now, another non-cancelled visit that day (any team) whose planned interval '
  'overlaps the visit (private.member_visit_overlap, PLAN3-16). Internal; used by aig1_apply for day-plan lines only.';

-- 2. The form's read before saving ------------------------------------------------------------------------------------------
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
  return exists (
    select 1 from public.care_visits x
    where x.organization_id = org and x.visit_date = p_visit_date and x.status <> 'cancelled'
      and x.responsible_user_id = p_member_id and (ex is null or x.id <> ex)
      and private.visit_interval(x) && rng);
end;
$$;
revoke all on function public.member_slot_overlap(uuid, uuid, uuid, date, time, time) from public, anon;
grant execute on function public.member_slot_overlap(uuid, uuid, uuid, date, time, time) to authenticated;
comment on function public.member_slot_overlap(uuid, uuid, uuid, date, time, time) is
  'PLAN3-16 (ADR-161, `cra` CGR-137): whether a member of the team already has a visit (any team, not cancelled) at a '
  'time overlapping [date + start, date + end). The team: the given visit''s (for its team members; it is excluded), '
  'else the case''s assigned team (for its members). yes/no only: no other team''s client, case, visit, team or time. '
  'LEAVE1-3 guarded; null for anyone else, a member outside that team or an incomplete slot. Never a refusal.';

-- 3. The audit rows record what the form showed (VIS2-4 pattern) -------------------------------------------------------------
create or replace function pg_temp.p316_patch(def text, old text, new text) returns text language plpgsql as $$
begin
  if (length(def) - length(replace(def, old, ''))) / length(old) <> 1 then
    raise exception 'PLAN3-16: anchor not found exactly once: %', left(old, 100);
  end if;
  return replace(def, old, new);
end;
$$;

do $$
declare
  def text;
begin
  def := pg_get_functiondef('private.write_audit_event()'::regprocedure);
  if def not like '%navora.member_overlap_shown%' then
    def := pg_temp.p316_patch(def,
      E'  shown   text  := nullif(current_setting(''navora.overlap_shown'', true), '''');\n',
      E'  shown   text  := nullif(current_setting(''navora.overlap_shown'', true), '''');\n'
      || E'  mshown  text  := nullif(current_setting(''navora.member_overlap_shown'', true), '''');\n');
    def := pg_temp.p316_patch(def,
      E'    diff := diff || jsonb_build_object(''overlap_shown'', jsonb_build_object(''old'', null, ''new'', shown::boolean));\n  end if;\n',
      E'    diff := diff || jsonb_build_object(''overlap_shown'', jsonb_build_object(''old'', null, ''new'', shown::boolean));\n  end if;\n'
      || E'  -- PLAN3-16 (ADR-161): set by plan_visit (insert) and take_open_visit (update) for their one write.\n'
      || E'  if tg_table_name = ''care_visits'' and mshown in (''true'', ''false'') then\n'
      || E'    diff := diff || jsonb_build_object(''member_overlap_shown'', jsonb_build_object(''old'', null, ''new'', mshown::boolean));\n'
      || E'  end if;\n');
    execute def;
  end if;

  def := pg_get_functiondef('private.audit_visit_plan_move()'::regprocedure);
  if def not like '%navora.member_overlap_shown%' then
    def := pg_temp.p316_patch(def,
      E'  shown text := nullif(current_setting(''navora.overlap_shown'', true), '''');\n',
      E'  shown text := nullif(current_setting(''navora.overlap_shown'', true), '''');\n'
      || E'  mshown text := nullif(current_setting(''navora.member_overlap_shown'', true), '''');\n');
    def := pg_temp.p316_patch(def,
      E'             else ''{}''::jsonb end);\n',
      E'             else ''{}''::jsonb end\n'
      -- PLAN3-16 (ADR-161): set by reschedule_visit for this one insert, from its p_member_overlap_shown.
      || E'     || case when mshown in (''true'', ''false'')\n'
      || E'             then jsonb_build_object(''member_overlap_shown'', jsonb_build_object(''old'', null, ''new'', mshown::boolean))\n'
      || E'             else ''{}''::jsonb end);\n');
    execute def;
  end if;
end;
$$;

insert into private.audit_value_classes (table_name, key, class)
values ('visit_plan_changes', 'member_overlap_shown', 'code'), ('care_visits', 'member_overlap_shown', 'code')
on conflict (table_name, key) do nothing;

-- 4. The four commands -----------------------------------------------------------------------------------------------------
do $$
declare
  def  text;
  note text;
  arg  constant text := ', p_member_overlap_shown boolean DEFAULT NULL::boolean)';
  mark_set constant text := E'  -- PLAN3-16 (ADR-161): what the form showed about the member, on this command''s audit row only.\n'
                            || E'  perform set_config(''navora.member_overlap_shown'', coalesce(p_member_overlap_shown::text, ''''), true);\n';
  mark_reset constant text := E'  perform set_config(''navora.member_overlap_shown'', '''', true);\n';
begin
  -- plan_visit --------------------------------------------------------------------------------------------------------------
  if to_regprocedure('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean)') is null then
    def  := pg_get_functiondef('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean)'::regprocedure);
    note := obj_description('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean)'::regprocedure, 'pg_proc');
    def := pg_temp.p316_patch(def, 'p_overlap_shown boolean DEFAULT NULL::boolean)', 'p_overlap_shown boolean DEFAULT NULL::boolean' || arg);
    def := pg_temp.p316_patch(def, E'  services text[];\n', E'  services text[];\n  mo   boolean;\n');
    def := pg_temp.p316_patch(def, E'  insert into public.care_visits\n', mark_set || E'  insert into public.care_visits\n');
    def := pg_temp.p316_patch(def,
      E'  returning id into vid;\n  perform set_config(''navora.overlap_shown'', '''', true);\n',
      E'  returning id into vid;\n  perform set_config(''navora.overlap_shown'', '''', true);\n' || mark_reset
      || E'  -- PLAN3-16: the member-overlap fact after the write (any team; the PLAN3-14 lock on member and day).\n'
      || E'  if p_responsible_user_id is not null then\n'
      || E'    mo := private.member_visit_overlap(vid, p_responsible_user_id);\n'
      || E'  end if;\n');
    def := pg_temp.p316_patch(def,
      E'    ''overlap'', private.client_overlap_fact(c.id, p_visit_date, p_time_start, p_time_end, vid),\n',
      E'    ''overlap'', private.client_overlap_fact(c.id, p_visit_date, p_time_start, p_time_end, vid),\n'
      || E'    ''member_overlap'', mo,\n');
    drop function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean);
    execute def;
    execute format('comment on function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean) is %L',
                   note || ' PLAN3-16 (ADR-161): p_member_overlap_shown is recorded as member_overlap_shown on the audit '
                   || 'row; an ok result carries member_overlap (yes/no, any team; null without a member). Never refused for it.');
  end if;

  -- reschedule_visit --------------------------------------------------------------------------------------------------------
  if to_regprocedure('public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)') is null then
    def  := pg_get_functiondef('public.reschedule_visit(uuid, date, time, time, text, uuid, boolean)'::regprocedure);
    note := obj_description('public.reschedule_visit(uuid, date, time, time, text, uuid, boolean)'::regprocedure, 'pg_proc');
    def := pg_temp.p316_patch(def, 'p_overlap_shown boolean DEFAULT NULL::boolean)', 'p_overlap_shown boolean DEFAULT NULL::boolean' || arg);
    def := pg_temp.p316_patch(def, E'  absent boolean := false;\n', E'  absent boolean := false;\n  mo     boolean;\n');
    def := pg_temp.p316_patch(def,
      E'  perform set_config(''navora.overlap_shown'', coalesce(p_overlap_shown::text, ''''), true);\n',
      E'  perform set_config(''navora.overlap_shown'', coalesce(p_overlap_shown::text, ''''), true);\n' || mark_set);
    def := pg_temp.p316_patch(def,
      E'  values (v.organization_id, v.id, v.case_id, v.team_id, ''moved'', before, private.visit_slot_json(v), why, uid, absent);\n  perform set_config(''navora.overlap_shown'', '''', true);\n',
      E'  values (v.organization_id, v.id, v.case_id, v.team_id, ''moved'', before, private.visit_slot_json(v), why, uid, absent);\n  perform set_config(''navora.overlap_shown'', '''', true);\n'
      || mark_reset);
    def := pg_temp.p316_patch(def,
      E'  perform private.end_command(''ok'');\n',
      E'  -- PLAN3-16: the member-overlap fact after the move (null when the visit has, or was released to, no member).\n'
      || E'  if v.responsible_user_id is not null then\n'
      || E'    mo := private.member_visit_overlap(v.id, v.responsible_user_id);\n'
      || E'  end if;\n'
      || E'  perform private.end_command(''ok'');\n');
    def := pg_temp.p316_patch(def,
      E'    ''overlap'', private.client_overlap_fact(v.case_id, v.visit_date, v.time_start, v.time_end, v.id),\n',
      E'    ''overlap'', private.client_overlap_fact(v.case_id, v.visit_date, v.time_start, v.time_end, v.id),\n'
      || E'    ''member_overlap'', mo,\n');
    drop function public.reschedule_visit(uuid, date, time, time, text, uuid, boolean);
    execute def;
    execute format('comment on function public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean) is %L',
                   note || ' PLAN3-16 (ADR-161): p_member_overlap_shown is recorded as member_overlap_shown on the moved '
                   || 'audit row; an ok result carries member_overlap (yes/no, any team). Never refused for it.');
  end if;

  -- move_visit_to_today ------------------------------------------------------------------------------------------------------
  if to_regprocedure('public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)') is null then
    def  := pg_get_functiondef('public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean)'::regprocedure);
    note := obj_description('public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean)'::regprocedure, 'pg_proc');
    def := pg_temp.p316_patch(def, 'p_overlap_shown boolean DEFAULT NULL::boolean)', 'p_overlap_shown boolean DEFAULT NULL::boolean' || arg);
    def := pg_temp.p316_patch(def,
      'p_reason, p_idempotency_key, p_overlap_shown);',
      'p_reason, p_idempotency_key, p_overlap_shown, p_member_overlap_shown);');
    drop function public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean);
    execute def;
    execute format('comment on function public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean) is %L',
                   note || ' PLAN3-16 (ADR-161): passes p_member_overlap_shown to reschedule_visit.');
  end if;

  -- take_open_visit ----------------------------------------------------------------------------------------------------------
  if to_regprocedure('public.take_open_visit(uuid, uuid, boolean)') is null then
    def  := pg_get_functiondef('public.take_open_visit(uuid, uuid)'::regprocedure);
    note := obj_description('public.take_open_visit(uuid, uuid)'::regprocedure, 'pg_proc');
    def := pg_temp.p316_patch(def, 'p_idempotency_key uuid)', 'p_idempotency_key uuid' || arg);
    def := pg_temp.p316_patch(def, E'  v   public.care_visits%rowtype;\n', E'  v   public.care_visits%rowtype;\n  mo  boolean;\n');
    def := pg_temp.p316_patch(def,
      E'  update public.care_visits set responsible_user_id = uid where id = v.id;\n',
      mark_set
      || E'  update public.care_visits set responsible_user_id = uid where id = v.id;\n'
      || mark_reset
      || E'  -- PLAN3-16: the member-overlap fact after the take (any team; the PLAN3-14 lock on member and day).\n'
      || E'  mo := private.member_visit_overlap(v.id, uid);\n');
    def := pg_temp.p316_patch(def,
      E'  return jsonb_build_object(''result'', private.end_command(''ok''));\n',
      E'  return jsonb_build_object(''result'', private.end_command(''ok''), ''member_overlap'', mo);\n');
    drop function public.take_open_visit(uuid, uuid);
    execute def;
    execute format('comment on function public.take_open_visit(uuid, uuid, boolean) is %L',
                   note || ' PLAN3-16 (ADR-161): p_member_overlap_shown is recorded as member_overlap_shown on the '
                   || 'care_visits audit row; an ok result carries member_overlap (yes/no, any team). Never refused for it.');
  end if;
end;
$$;

revoke all on function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean) from public, anon;
grant execute on function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean) to authenticated, service_role;
revoke all on function public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean) from public, anon;
grant execute on function public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean) to authenticated, service_role;
revoke all on function public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean) from public, anon;
grant execute on function public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean) to authenticated, service_role;
revoke all on function public.take_open_visit(uuid, uuid, boolean) from public, anon;
grant execute on function public.take_open_visit(uuid, uuid, boolean) to authenticated;

drop function pg_temp.p316_patch(text, text, text);

-- Guards: one signature each; each hand path carries the marker (set and reset) and the fact.
do $$
declare
  f   text;
  def text;
begin
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
        and proname in ('plan_visit', 'reschedule_visit', 'move_visit_to_today', 'take_open_visit')) <> 4 then
    raise exception 'PLAN3-16: plan_visit, reschedule_visit, move_visit_to_today and take_open_visit must have one signature each';
  end if;
  foreach f in array array[
    'public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean)',
    'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.take_open_visit(uuid, uuid, boolean)'] loop
    def := pg_get_functiondef(f::regprocedure);
    if (length(def) - length(replace(def, 'navora.member_overlap_shown', ''))) / length('navora.member_overlap_shown') <> 2
       or def not like '%private.member_visit_overlap(%' then
      raise exception 'PLAN3-16: % does not carry the member-overlap marker and fact', f;
    end if;
  end loop;
end;
$$;
