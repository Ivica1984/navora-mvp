-- BK-e1b / CGR-252 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 09:39 (2); `cra` 09:27 advisory S3;
-- ADR-203 (17)).
-- Before: `cancel_visit` (0141, CGR-248) and the five commands of 0142 (CGR-249) refused a visit written from a take
--   with the stated result `take_visit`, but left no trace: the attempt was invisible in the audit record.
-- Now (IMPLEMENTED in this migration): each of the six refusals writes exactly ONE `audit_events` row through the
--   existing `private.write_visit_refusal` (VIS1 / ADR-111 (2) form: table `care_visits`, the visit, the command name,
--   `changed = {"outcome": {"old": null, "new": "take_visit"}}`, no idempotency key, actor = the caller), and nothing
--   else: visit, plan changes, take, client cover and status notes stay unchanged. The row is written only where the
--   refusal is returned, i.e. after the caller's own access check, so a caller outside the team still gets the
--   unchanged `rejected` without any row (no fact about another team's visit).
--   PO 09:39: a refused attempt raises no CGR-246 signal (a refusal is not an absence); nothing here touches SIG1.
-- Unchanged: signatures, grants, results, every visit not from a take, the writer list of `public.care_visits`
--   (ADR-203 (15): this writes `audit_events` only).
-- Body patches carry the marker BK-E1B-R and must match exactly once (idempotent: a patched body is skipped).
-- No data change. No clinical, legal or tariff rule is set here.

create or replace function private.bk_e1b_r_patch(p_fn text, p_find text, p_replace text, p_marker text)
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
    raise exception '0145 patch for % must match once, matched %: %', p_fn, n, p_find;
  end if;
  def := replace(def, p_find, p_replace);
  if position(p_marker in def) = 0 then
    raise exception '0145 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_e1b_r_patch(text, text, text, text) from public, anon, authenticated;

-- 1. cancel_visit (0141) ---------------------------------------------------------------------------------------------
select private.bk_e1b_r_patch(
  'public.cancel_visit(uuid, text, text, uuid)',
  E'  if v.order_take_id is not null then return private.end_command(''take_visit''); end if;\n',
  E'  if v.order_take_id is not null then\n'
  || E'    perform private.write_visit_refusal(v, ''cancel_visit'', ''take_visit'');  -- BK-E1B-R (CGR-252): one row\n'
  || E'    return private.end_command(''take_visit'');\n'
  || E'  end if;\n',
  'BK-E1B-R');

-- 2. reschedule_visit (0142 §1) ----------------------------------------------------------------------------------------
select private.bk_e1b_r_patch(
  'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)',
  E'    perform private.end_command(''take_visit'');\n    return jsonb_build_object(''result'', ''take_visit'');\n',
  E'    perform private.write_visit_refusal(v, ''reschedule_visit'', ''take_visit'');  -- BK-E1B-R (CGR-252): one row\n'
  || E'    perform private.end_command(''take_visit'');\n    return jsonb_build_object(''result'', ''take_visit'');\n',
  'BK-E1B-R');

-- 3. move_visit_to_today (0142 §2): refused before reschedule_visit is reached, so one row only ------------------------
select private.bk_e1b_r_patch(
  'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)',
  E'  if v.id is not null and v.order_take_id is not null then\n    return jsonb_build_object(''result'', ''take_visit'');\n',
  E'  if v.id is not null and v.order_take_id is not null then\n'
  || E'    perform private.write_visit_refusal(v, ''move_visit_to_today'', ''take_visit'');  -- BK-E1B-R (CGR-252): one row\n'
  || E'    return jsonb_build_object(''result'', ''take_visit'');\n',
  'BK-E1B-R');

-- 4. remove_planned_visit (0142 §3) ------------------------------------------------------------------------------------
select private.bk_e1b_r_patch(
  'public.remove_planned_visit(uuid, text, uuid)',
  E'    perform private.end_command(''take_visit'');\n    return jsonb_build_object(''result'', ''take_visit'');\n',
  E'    perform private.write_visit_refusal(v, ''remove_planned_visit'', ''take_visit'');  -- BK-E1B-R (CGR-252): one row\n'
  || E'    perform private.end_command(''take_visit'');\n    return jsonb_build_object(''result'', ''take_visit'');\n',
  'BK-E1B-R');

-- 5. take_open_visit (0142 §4) -----------------------------------------------------------------------------------------
select private.bk_e1b_r_patch(
  'public.take_open_visit(uuid, uuid, boolean)',
  E'  if v.order_take_id is not null then\n    return jsonb_build_object(''result'', private.end_command(''take_visit''));\n',
  E'  if v.order_take_id is not null then\n'
  || E'    perform private.write_visit_refusal(v, ''take_open_visit'', ''take_visit'');  -- BK-E1B-R (CGR-252): one row\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''take_visit''));\n',
  'BK-E1B-R');

-- 6. propose_visit_responsible (0142 §5) -------------------------------------------------------------------------------
select private.bk_e1b_r_patch(
  'public.propose_visit_responsible(uuid, uuid)',
  E'  if v.order_take_id is not null then\n    return jsonb_build_object(''result'', private.end_command(''take_visit''));\n',
  E'  if v.order_take_id is not null then\n'
  || E'    perform private.write_visit_refusal(v, ''propose_visit_responsible'', ''take_visit'');  -- BK-E1B-R (CGR-252)\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''take_visit''));\n',
  'BK-E1B-R');

drop function private.bk_e1b_r_patch(text, text, text, text);

-- Comments: the existing text plus the CGR-252 sentence (once).
do $$
declare
  f text;
  note text;
begin
  foreach f in array array[
    'public.cancel_visit(uuid, text, text, uuid)',
    'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.remove_planned_visit(uuid, text, uuid)',
    'public.take_open_visit(uuid, uuid, boolean)',
    'public.propose_visit_responsible(uuid, uuid)'] loop
    note := coalesce(obj_description(f::regprocedure, 'pg_proc'), '');
    if position('CGR-252' in note) = 0 then
      execute format('comment on function %s is %L', f,
        btrim(note || ' BK-e1b / CGR-252: a take_visit refusal writes one audit row (outcome take_visit, no key).'));
    end if;
  end loop;
end;
$$;

-- Guards: each of the six carries the marker once, still calls the refusal writer, and keeps its security definer and
-- empty search path.
do $$
declare
  f text;
  d text;
begin
  foreach f in array array[
    'public.cancel_visit(uuid, text, text, uuid)',
    'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)',
    'public.remove_planned_visit(uuid, text, uuid)',
    'public.take_open_visit(uuid, uuid, boolean)',
    'public.propose_visit_responsible(uuid, uuid)'] loop
    d := pg_get_functiondef(f::regprocedure);
    if (length(d) - length(replace(d, 'BK-E1B-R', ''))) / length('BK-E1B-R') <> 1
       or position('private.write_visit_refusal(v, ' in d) = 0
       or position('SECURITY DEFINER' in d) = 0 or position('SET search_path TO ''''' in d) = 0 then
      raise exception '0145: % is not patched as expected', f;
    end if;
  end loop;
end;
$$;
