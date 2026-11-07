-- VIS2: a second visit of the same client at an overlapping time is visible before it is saved (PO brief
-- docs/agents/briefs/VIS2.md, approved 2026-10-29 23:15 from `cra` CGR-97, VIS2-5 added 2026-10-30 00:15 from `uxa`
-- UXR-50; issue #699; ADR-121).
-- Visit/schedule fact (two recorded visit times of one client). Display only: nothing is refused, ranked, routed or
-- escalated. No rule is set on whether a same-client overlap is allowed or billed (Clinical Owner, billing owner: OPEN).
--
-- Before (IMPLEMENTED fact, `cra` CGR-97): `plan_visit`, `reschedule_visit` and `move_visit_to_today` never looked at
--   the client's day. A second visit of the same client at the same time was saved without anyone seeing it.
-- Now (IMPLEMENTED in this migration):
--   1. `private.client_overlap_visits(case, date, start, end, exclude)`: the one overlap definition. Every other visit
--      of the case on that date that is not `cancelled` (a removed visit is deleted, 0014) whose planned wall-clock
--      interval (`private.visit_wall_range`, FUP1-1: without an end, start + planned minutes, else to the end of its
--      date) meets the half-open interval [date + start, date + end). Touching ends do not overlap.
--   2. `private.client_overlap_fact(...)`: {overlap, time_start, time_end}; the times only of the earliest overlapping
--      visit the caller can read (`private.reads_visit`), so another team's visit counts without any team, member,
--      service or time (VIS2-2). No permission check (internal).
--   3. `public.client_visit_overlap(case, visit, date, start, end)` (SECURITY DEFINER, stable): the fact for the
--      planning form (case given), the /team move and "Heute machen" (visit given, excluded). Answers only a caller who
--      may already read that client: a team member of the visit (`private.visit_for_team`, as VIS1-8) when a visit is
--      given, else a member of the case's assigned team (`private.reads_case`, RLS2). Anyone else, or an incomplete
--      slot, gets null. No new read permission on any table.
--   4. VIS2-4 / VIS2-5: `plan_visit`, `reschedule_visit` and `move_visit_to_today` take one more argument,
--      `p_overlap_shown boolean default null`: what the form showed. It is recorded as `overlap_shown: true|false` (code
--      value) on the command's existing audit row: `plan_visit`'s care_visits insert row (`private.write_audit_event`;
--      a `planned` plan change writes no audit row), `reschedule_visit`'s `moved` row (`private.audit_visit_plan_move`).
--      Null (an older caller) records nothing. The server re-checks at the save: an `ok` result carries `overlap` (2),
--      whatever the form showed, so the app can state an overlap the form did not show. Never a refusal.
--      The old signatures are dropped and recreated with the extra defaulted argument (no ambiguous overload); a call
--      with the old arguments resolves to the new function unchanged. Grants and comments re-applied.
-- Unchanged: every refusal, check and grant of the three commands; nothing is refused for an overlap.
-- Idempotent: create or replace; the command rewrite is skipped when the new signature exists; catalogue on conflict.

-- 1. The overlap definition --------------------------------------------------------------------------------------------
create or replace function private.client_overlap_visits(
  p_case_id uuid, p_visit_date date, p_time_start time, p_time_end time, p_exclude_visit_id uuid)
returns setof public.care_visits
language sql stable set search_path = ''
as $$
  select x.* from public.care_visits x
  where p_case_id is not null and p_visit_date is not null
    and p_time_start is not null and p_time_end is not null and p_time_end > p_time_start
    and x.case_id = p_case_id and x.visit_date = p_visit_date
    and x.status is distinct from 'cancelled'
    and (p_exclude_visit_id is null or x.id <> p_exclude_visit_id)
    and private.visit_wall_range(x) && tsrange(p_visit_date + p_time_start, p_visit_date + p_time_end, '[)')
$$;
revoke all on function private.client_overlap_visits(uuid, date, time, time, uuid) from public, anon, authenticated;
comment on function private.client_overlap_visits(uuid, date, time, time, uuid) is
  'VIS2 / ADR-121 / CGR-97: other visits of the case on the date, not cancelled, whose planned wall-clock interval '
  '(private.visit_wall_range) overlaps [date + start, date + end) half-open. Internal: no permission check.';

-- 2. The fact ----------------------------------------------------------------------------------------------------------
create or replace function private.client_overlap_fact(
  p_case_id uuid, p_visit_date date, p_time_start time, p_time_end time, p_exclude_visit_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  hit boolean;
  t   time;
  e   timestamp;
begin
  select exists (select 1 from private.client_overlap_visits(p_case_id, p_visit_date, p_time_start, p_time_end,
                                                             p_exclude_visit_id)) into hit;
  if hit then
    select o.time_start, upper(private.visit_wall_range(o)) into t, e
    from private.client_overlap_visits(p_case_id, p_visit_date, p_time_start, p_time_end, p_exclude_visit_id) o
    where o.time_start is not null and private.reads_visit(o.id)
    order by o.time_start, o.id
    limit 1;
  end if;
  return jsonb_build_object('overlap', hit,
                            'time_start', case when t is null then null else to_char(t, 'HH24:MI') end,
                            'time_end', case when t is null then null else to_char(e, 'HH24:MI') end);
end;
$$;
revoke all on function private.client_overlap_fact(uuid, date, time, time, uuid) from public, anon, authenticated;
comment on function private.client_overlap_fact(uuid, date, time, time, uuid) is
  'VIS2-1 / VIS2-2 / ADR-121: {overlap, time_start, time_end} for a slot of a case: overlap by private.client_overlap_visits; '
  'the times only of the earliest overlapping visit the caller can read (reads_visit). Internal: no permission check.';

-- 3. The read path for the confirmation --------------------------------------------------------------------------------
create or replace function public.client_visit_overlap(
  p_case_id uuid, p_visit_id uuid, p_visit_date date, p_time_start time, p_time_end time)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  k  uuid;
  ex uuid;
begin
  if (select auth.uid()) is null then
    return null;
  end if;
  if p_visit_id is not null then
    select v.case_id, v.id into k, ex from private.visit_for_team(p_visit_id) v where v.id is not null;
    if k is null or (p_case_id is not null and p_case_id <> k) then
      return null;
    end if;
  elsif p_case_id is not null and private.reads_case(p_case_id) then
    k := p_case_id;
  else
    return null;
  end if;
  if p_visit_date is null or p_time_start is null or p_time_end is null or p_time_end <= p_time_start then
    return null;
  end if;
  return private.client_overlap_fact(k, p_visit_date, p_time_start, p_time_end, ex);
end;
$$;
revoke all on function public.client_visit_overlap(uuid, uuid, date, time, time) from public, anon;
grant execute on function public.client_visit_overlap(uuid, uuid, date, time, time) to authenticated;
comment on function public.client_visit_overlap(uuid, uuid, date, time, time) is
  'VIS2-1 / VIS2-2 / ADR-121 / CGR-97: whether the client already has another visit (any team, not cancelled) at a '
  'time overlapping [date + start, date + end) on that date. Visit given: team members of that visit (it is excluded); '
  'else members of the case''s assigned team; null for anyone else or an incomplete slot. {overlap, time_start, '
  'time_end}: the times only of the earliest overlapping visit the caller can read; another team''s visit counts '
  'without any detail.';

-- 4. VIS2-4: the existing audit rows record what the form showed --------------------------------------------------------
create or replace function private.audit_visit_plan_move()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  shown text := nullif(current_setting('navora.overlap_shown', true), '');
begin
  insert into public.audit_events
    (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values
    (new.organization_id, (select auth.uid()),
     coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', session_user::text),
     tg_table_name, new.visit_id,
     nullif(current_setting('navora.command', true), ''),
     nullif(current_setting('navora.idempotency_key', true), '')::uuid,
     jsonb_build_object('change', jsonb_build_object('old', null, 'new', new.change),
                        'responsible_absent', jsonb_build_object('old', null, 'new', new.responsible_absent))
     -- VIS2-4 (ADR-121): set by reschedule_visit for this one insert, from its p_overlap_shown.
     || case when shown in ('true', 'false')
             then jsonb_build_object('overlap_shown', jsonb_build_object('old', null, 'new', shown::boolean))
             else '{}'::jsonb end);
  return new;
end;
$$;

-- plan_visit's audit row is its care_visits insert row. Unchanged otherwise (0001 baseline body); the marker is read
-- only for a care_visits insert.
create or replace function private.write_audit_event()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  col     text;
  diff    jsonb := '{}'::jsonb;
  old_row jsonb := to_jsonb(old);
  new_row jsonb := to_jsonb(new);
  key_txt text  := nullif(current_setting('navora.idempotency_key', true), '');
  shown   text  := nullif(current_setting('navora.overlap_shown', true), '');
begin
  foreach col in array tg_argv loop
    if old_row -> col is distinct from new_row -> col then
      diff := diff || jsonb_build_object(col, jsonb_build_object('old', old_row -> col, 'new', new_row -> col));
    end if;
  end loop;
  -- VIS2-4 (ADR-121): set by plan_visit for its one insert, from its p_overlap_shown.
  if tg_op = 'INSERT' and tg_table_name = 'care_visits' and shown in ('true', 'false') then
    diff := diff || jsonb_build_object('overlap_shown', jsonb_build_object('old', null, 'new', shown::boolean));
  end if;

  insert into public.audit_events
    (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values
    -- current_user is the function owner here (SECURITY DEFINER), so the
    -- caller's role comes from the request's JWT claims.
    (new.organization_id, (select auth.uid()),
     coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', session_user::text),
     tg_table_name, new.id,
     nullif(current_setting('navora.command', true), ''), key_txt::uuid, diff);

  return new;
end;
$$;

insert into private.audit_value_classes (table_name, key, class)
values ('visit_plan_changes', 'overlap_shown', 'code'), ('care_visits', 'overlap_shown', 'code')
on conflict (table_name, key) do nothing;

-- The three commands: one more defaulted argument, the marker around the one audited insert, `overlap` on `ok`.
create or replace function pg_temp.vis2_patch(def text, old text, new text) returns text language plpgsql as $$
begin
  if (length(def) - length(replace(def, old, ''))) / length(old) <> 1 then
    raise exception 'VIS2: anchor not found exactly once: %', left(old, 80);
  end if;
  return replace(def, old, new);
end;
$$;

do $$
declare
  def  text;
  note text;
  mark_set constant text := E'  -- VIS2-4 (ADR-121): what the form showed, on this command''s audit row only.\n'
                            || E'  perform set_config(''navora.overlap_shown'', coalesce(p_overlap_shown::text, ''''), true);\n';
  mark_reset constant text := E'  perform set_config(''navora.overlap_shown'', '''', true);\n';
begin
  -- plan_visit ------------------------------------------------------------------------------------------------------
  if to_regprocedure('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean)') is null then
    def  := pg_get_functiondef('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid)'::regprocedure);
    note := obj_description('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid)'::regprocedure, 'pg_proc');
    def := pg_temp.vis2_patch(def, 'p_responsible_user_id uuid, p_idempotency_key uuid)',
                              'p_responsible_user_id uuid, p_idempotency_key uuid, p_overlap_shown boolean DEFAULT NULL::boolean)');
    def := pg_temp.vis2_patch(def, E'  insert into public.care_visits\n', mark_set || E'  insert into public.care_visits\n');
    def := pg_temp.vis2_patch(def, E'  returning id into vid;\n', E'  returning id into vid;\n' || mark_reset);
    def := pg_temp.vis2_patch(def,
      E'  return jsonb_build_object(''result'', ''ok'', ''visit_id'', vid,\n',
      E'  -- VIS2-5 (ADR-121): the server''s own check at the save, whatever the form showed.\n'
      || E'  return jsonb_build_object(''result'', ''ok'', ''visit_id'', vid,\n'
      || E'    ''overlap'', private.client_overlap_fact(c.id, p_visit_date, p_time_start, p_time_end, vid),\n');
    drop function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid);
    execute def;
    execute format('comment on function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean) is %L',
                   note || ' VIS2 (ADR-121): p_overlap_shown (what the form showed) is recorded as overlap_shown on the '
                   || 'audit row; an ok result carries overlap (the server''s check). Never refused for an overlap.');
  end if;

  -- reschedule_visit ------------------------------------------------------------------------------------------------
  if to_regprocedure('public.reschedule_visit(uuid, date, time, time, text, uuid, boolean)') is null then
    def  := pg_get_functiondef('public.reschedule_visit(uuid, date, time, time, text, uuid)'::regprocedure);
    note := obj_description('public.reschedule_visit(uuid, date, time, time, text, uuid)'::regprocedure, 'pg_proc');
    def := pg_temp.vis2_patch(def, 'p_reason text, p_idempotency_key uuid)',
                              'p_reason text, p_idempotency_key uuid, p_overlap_shown boolean DEFAULT NULL::boolean)');
    def := pg_temp.vis2_patch(def,
      E'  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id,\n',
      mark_set
      || E'  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id,\n');
    def := pg_temp.vis2_patch(def,
      E'  values (v.organization_id, v.id, v.case_id, v.team_id, ''moved'', before, private.visit_slot_json(v), why, uid, absent);\n',
      E'  values (v.organization_id, v.id, v.case_id, v.team_id, ''moved'', before, private.visit_slot_json(v), why, uid, absent);\n'
      || mark_reset);
    def := pg_temp.vis2_patch(def,
      E'  return jsonb_build_object(''result'', ''ok'', ''visit_id'', v.id, ''released'', n_rel = 1,\n',
      E'  -- VIS2-5 (ADR-121): the server''s own check at the save, whatever the form showed.\n'
      || E'  return jsonb_build_object(''result'', ''ok'', ''visit_id'', v.id, ''released'', n_rel = 1,\n'
      || E'    ''overlap'', private.client_overlap_fact(v.case_id, v.visit_date, v.time_start, v.time_end, v.id),\n');
    drop function public.reschedule_visit(uuid, date, time, time, text, uuid);
    execute def;
    execute format('comment on function public.reschedule_visit(uuid, date, time, time, text, uuid, boolean) is %L',
                   note || ' VIS2 (ADR-121): p_overlap_shown (what the form showed) is recorded as overlap_shown on the '
                   || 'moved audit row; an ok result carries overlap (the server''s check). Never refused for an overlap.');
  end if;

  -- move_visit_to_today -----------------------------------------------------------------------------------------------
  if to_regprocedure('public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean)') is null then
    def  := pg_get_functiondef('public.move_visit_to_today(uuid, date, time, time, text, uuid)'::regprocedure);
    note := obj_description('public.move_visit_to_today(uuid, date, time, time, text, uuid)'::regprocedure, 'pg_proc');
    def := pg_temp.vis2_patch(def, 'p_reason text, p_idempotency_key uuid)',
                              'p_reason text, p_idempotency_key uuid, p_overlap_shown boolean DEFAULT NULL::boolean)');
    def := pg_temp.vis2_patch(def,
      'return public.reschedule_visit(p_visit_id, today, p_time_start, p_time_end, p_reason, p_idempotency_key);',
      'return public.reschedule_visit(p_visit_id, today, p_time_start, p_time_end, p_reason, p_idempotency_key, p_overlap_shown);');
    drop function public.move_visit_to_today(uuid, date, time, time, text, uuid);
    execute def;
    execute format('comment on function public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean) is %L',
                   note || ' VIS2 (ADR-121): passes p_overlap_shown to reschedule_visit.');
  end if;
end;
$$;

revoke all on function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean) from public, anon;
grant execute on function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean) to authenticated, service_role;
revoke all on function public.reschedule_visit(uuid, date, time, time, text, uuid, boolean) from public, anon;
grant execute on function public.reschedule_visit(uuid, date, time, time, text, uuid, boolean) to authenticated, service_role;
revoke all on function public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean) from public, anon;
grant execute on function public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean) to authenticated, service_role;

drop function pg_temp.vis2_patch(text, text, text);

-- Guards: one signature each; the marker set and reset exactly once in plan_visit and reschedule_visit.
do $$
declare
  f text;
  def text;
begin
  if (select count(*) from pg_proc where pronamespace = 'public'::regnamespace
        and proname in ('plan_visit', 'reschedule_visit', 'move_visit_to_today')) <> 3 then
    raise exception 'VIS2: plan_visit, reschedule_visit and move_visit_to_today must have one signature each';
  end if;
  foreach f in array array[
    'public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean)',
    'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean)'] loop
    def := pg_get_functiondef(f::regprocedure);
    if (length(def) - length(replace(def, 'navora.overlap_shown', ''))) / length('navora.overlap_shown') <> 2
       or def not like '%private.client_overlap_fact(%' then
      raise exception 'VIS2: % does not carry the overlap marker and result', f;
    end if;
  end loop;
end;
$$;
