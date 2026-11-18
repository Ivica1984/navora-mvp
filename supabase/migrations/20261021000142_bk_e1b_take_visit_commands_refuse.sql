-- BK-e1b / CGR-249 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 07:39 (1); `cra` 07:27; ADR-203 (14)).
-- Before: `cancel_visit` refused a visit written from a take (0141, CGR-248), but `move_visit_to_today`,
--   `reschedule_visit` and `remove_planned_visit` still moved, re-dated or deleted it while the take stayed live, so the
--   order kept reading «gedeckt» for a slot nobody was coming to. `take_open_visit` and `propose_visit_responsible`
--   act only on a visit without a member; they did not check the take either.
-- Now (IMPLEMENTED in this migration): each of the five refuses a visit with `order_take_id` with the stated result
--   `take_visit` (as `cancel_visit`), for every member of the visit's team, before anything is written: visit row,
--   plan changes, take and client cover stay unchanged. The refusal is read only after the caller's own access check,
--   so a caller outside the team still gets the unchanged `rejected` (no fact about another team's visit).
--   The member's way out before «unterwegs» stays the release with a reason (CGR-242, `release_named_take`).
-- Unchanged: signatures, grants, comments (extended), every visit not from a take, every other result.
-- Body patches carry the marker BK-E1B-M and are checked to match exactly once (idempotent: a patched body is skipped).
-- No data change. No clinical, legal or tariff rule is set here.

create or replace function private.bk_e1b_m_patch(p_fn text, p_find text, p_replace text, p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  n := (length(def) - length(replace(def, p_find, ''))) / length(p_find);
  if n <> 1 then
    raise exception '0142 patch for % must match once, matched %: %', p_fn, n, p_find;
  end if;
  def := replace(def, p_find, p_replace);
  if position(p_marker in def) = 0 then
    raise exception '0142 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_e1b_m_patch(text, text, text, text) from public, anon, authenticated;

-- 1. reschedule_visit: after the row lock, for a member of the visit's team (also a take visit on the way) ------------
select private.bk_e1b_m_patch(
  'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)',
  E'  select * into v from public.care_visits where id = p_visit_id for update;\n',
  E'  select * into v from public.care_visits where id = p_visit_id for update;\n'
  || E'  -- BK-E1B-M (CGR-249): a visit written from a take is never moved or re-dated by a person command.\n'
  || E'  if found and v.order_take_id is not null\n'
  || E'     and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id) then\n'
  || E'    perform private.end_command(''take_visit'');\n'
  || E'    return jsonb_build_object(''result'', ''take_visit'');\n'
  || E'  end if;\n',
  'BK-E1B-M');

-- 2. move_visit_to_today: before the VIS1-10 day check (a take visit is refused whatever day was shown) -------------
select private.bk_e1b_m_patch(
  'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)',
  E'  select * into v from private.visit_for_team(p_visit_id);\n',
  E'  select * into v from private.visit_for_team(p_visit_id);\n'
  || E'  -- BK-E1B-M (CGR-249): «Heute machen» never moves a visit written from a take.\n'
  || E'  if v.id is not null and v.order_take_id is not null then\n'
  || E'    return jsonb_build_object(''result'', ''take_visit'');\n'
  || E'  end if;\n',
  'BK-E1B-M');

-- 3. remove_planned_visit: after the row lock, for a member of the visit's team -----------------------------------------
select private.bk_e1b_m_patch(
  'public.remove_planned_visit(uuid, text, uuid)',
  E'  select * into v from public.care_visits where id = p_visit_id for update;\n',
  E'  select * into v from public.care_visits where id = p_visit_id for update;\n'
  || E'  -- BK-E1B-M (CGR-249): a visit written from a take is never deleted by a person command.\n'
  || E'  if found and v.order_take_id is not null\n'
  || E'     and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id) then\n'
  || E'    perform private.end_command(''take_visit'');\n'
  || E'    return jsonb_build_object(''result'', ''take_visit'');\n'
  || E'  end if;\n',
  'BK-E1B-M');

-- 4. take_open_visit: after the access check, before «already taken» (defence in depth; see ADR-203 (14)) -------------
select private.bk_e1b_m_patch(
  'public.take_open_visit(uuid, uuid, boolean)',
  E'  if v.responsible_user_id is not null then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''already_taken''));\n',
  E'  -- BK-E1B-M (CGR-249): a visit written from a take is never re-assigned from «Offen im Team».\n'
  || E'  if v.order_take_id is not null then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''take_visit''));\n'
  || E'  end if;\n'
  || E'  if v.responsible_user_id is not null then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''already_taken''));\n',
  'BK-E1B-M');

-- 5. propose_visit_responsible: after the AIG1-6 access check, before the agent state (no suggestion is written) ------
select private.bk_e1b_m_patch(
  'public.propose_visit_responsible(uuid, uuid)',
  E'  st := private.aig1_check(v.organization_id, agent);\n',
  E'  -- BK-E1B-M (CGR-249): no member is proposed for a visit written from a take.\n'
  || E'  if v.order_take_id is not null then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''take_visit''));\n'
  || E'  end if;\n'
  || E'  st := private.aig1_check(v.organization_id, agent);\n',
  'BK-E1B-M');

drop function private.bk_e1b_m_patch(text, text, text, text);

-- Comments: the existing text plus the CGR-249 sentence (once).
do $$
declare
  f text;
  note text;
begin
  foreach f in array array[
    'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.remove_planned_visit(uuid, text, uuid)',
    'public.take_open_visit(uuid, uuid, boolean)',
    'public.propose_visit_responsible(uuid, uuid)'] loop
    note := coalesce(obj_description(f::regprocedure, 'pg_proc'), '');
    if position('CGR-249' in note) = 0 then
      execute format('comment on function %s is %L', f,
        btrim(note || ' BK-e1b / CGR-249: a visit written from a take (order_take_id) is refused with take_visit; '
              || 'the way out is the release (CGR-242).'));
    end if;
  end loop;
end;
$$;

-- Guards: each of the five carries the marker once and keeps its security definer and empty search path.
do $$
declare
  f text;
  d text;
begin
  foreach f in array array[
    'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.remove_planned_visit(uuid, text, uuid)',
    'public.take_open_visit(uuid, uuid, boolean)',
    'public.propose_visit_responsible(uuid, uuid)'] loop
    d := pg_get_functiondef(f::regprocedure);
    if position('BK-E1B-M' in d) = 0 or position('SECURITY DEFINER' in d) = 0 or position('SET search_path TO ''''' in d) = 0 then
      raise exception '0142: % is not patched as expected', f;
    end if;
  end loop;
end;
$$;
