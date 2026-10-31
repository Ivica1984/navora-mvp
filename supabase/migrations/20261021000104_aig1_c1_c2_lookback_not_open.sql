-- AIG1-C1 (as amended 2026-10-30 21:25, AUT-29) and AIG1-C2 (CGR-105, 2026-10-30 22:15) (ADR-130). PO brief
-- docs/agents/briefs/AIG1.md. A look-back line of a visit no longer open is neither re-confirmed nor changed, is labelled
-- and counted apart, and is never removed; a line of a visit still open can be re-confirmed or changed one by one by the
-- record's team on the record page. Synthetic data only.
--
-- No clinical rule is made here: whether, by whom and by when a listed value must be re-checked stays the Clinical
-- Owner's (D-17, UNKNOWN). NAVORA only declines to record an attestation without content (a "bestätigt" on a visit that
-- can no longer be performed) and makes the existing, tested command reachable for an open visit.
--
-- Before (IMPLEMENTED, 0097 / 0103):
--   * `private.aig1_apply_visit_responsible` returned `ok` for a re-confirmation of a value the record already holds on a
--     visit no longer open, so `confirm_suggestion` wrote an `ai_confirmations` row ("bestätigt") and the line left the
--     look-back list (0103: "re-confirmed as built"). A correction of such a value was already refused `not_open`.
--   * `confirm_suggestion` accepted `rejected` for a value already applied; that writes a confirmation row, so the line
--     left the look-back list although the record kept the value.
--   * `agent_stop_lookback` and the OPS1 detail of `agent_stopped` counted every line not superseded as "offen".
--   * No reader told the record page which of its values is on a look-back list.
-- After:
--   1. `private.aig1_record_open(entity_type, entity_id)`: the open-visit condition of 0097/0103 in one place
--      (`planned`, not suspended, not covered, not dated before today, Europe/Zurich). Unchanged condition.
--   2. AIG1-C1 (1): a re-confirmation of a value the record already holds on a visit no longer open returns `not_open`;
--      the caller writes no `ai_confirmations` row and no ledger change, so the line stays listed. A correction keeps its
--      existing `not_open` (0097, unchanged).
--   3. AIG1-C1 (3) guard: `rejected` is refused (22023) for a value already applied (its newest confirmation is
--      `confirmed` or `corrected`). A line leaves the list only by re-confirmation or change of an open visit.
--   4. AIG1-C1 (2): `agent_stop_lookback` also returns `not_open` (the line is not superseded and its visit is no longer
--      open). The return type changes, so the function is dropped and re-created with its grants (callers: the look-back
--      page and pgTAP). No person column (AIG1-11 (4), pgTAP 071 unchanged).
--   5. AIG1-C1 (2)/(4): the OPS1 detail reads "<Agent> · Werte: <n> offen · <m> nicht mehr offen" (wording adopted by the
--      PO 2026-10-31 00:10 from `uxa`); the exception stays open while the agent is `stopped` (unchanged), so with every
--      open-visit line handled it reads "Werte: 0 offen · <m> nicht mehr offen".
--   6. AIG1-C2 (a)/(d): `record_lookback_lines(entity_type, entity_id)` returns, to active members of the record's team
--      only (exactly those who may call `confirm_suggestion` for it), the listed suggestion of that record per field:
--      suggestion id, field, agent name, stop and whether the visit is still open. No person, no outcome, no confirmer;
--      a coordinator who is not a team member gets no row, so the record page shows her no control.
-- Idempotent: `create or replace`; `drop function if exists` before the changed return type; the OPS1 patch carries a
-- marker and is skipped when present.

-- 0. Patch helper (removed at the end) ------------------------------------------------------------------------------------
create or replace function private.aig1c_patch(p_fn text, p_pairs text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]);
    if n <> p_pairs[i + 2]::integer then
      raise exception '0104 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0104 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.aig1c_patch(text, text[], text) from public, anon, authenticated;

-- 1. The open-visit condition in one place --------------------------------------------------------------------------------
create or replace function private.aig1_record_open(p_entity_type text, p_entity_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case
    when p_entity_type = 'care_visits' then coalesce(
      (select v.status = 'planned' and v.suspended_at is null and v.covered_by is null
              and v.visit_date >= (private.at_zurich(private.now()))::date
       from public.care_visits v where v.id = p_entity_id), false)
    else true                                               -- no other field has a consuming command (ADR-120)
  end
$$;
revoke all on function private.aig1_record_open(text, uuid) from public, anon, authenticated;
comment on function private.aig1_record_open(text, uuid) is
  'AIG1-C1: whether the record of a proposed value is still open (a visit: planned, not suspended or covered, not dated '
  'before today, Europe/Zurich). The same condition as the first confirmation (0097) and AIG1-15 (0103).';

-- 2. AIG1-C1 (1): no attestation on a visit no longer open ---------------------------------------------------------------
create or replace function private.aig1_apply_visit_responsible(p_visit_id uuid, p_user uuid, p_expected uuid, p_actor uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare v public.care_visits%rowtype;
begin
  select * into v from public.care_visits x where x.id = p_visit_id for update;
  if not found then
    return 'not_open';
  end if;
  if v.responsible_user_id is not distinct from p_user then
    -- The record already holds this value (a re-confirmation, AIG1-12 (iv)).
    -- AIG1-C1 (1): a visit no longer open is not re-confirmed; the caller writes no confirmation and the line stays.
    if not private.aig1_record_open('care_visits', v.id) then
      return 'not_open';
    end if;
    -- AIG1-15: the checks of a first confirmation, in the same order.
    if not private.may_perform_visit(v.team_id, p_user, v.planned_minutes_b, v.is_needs_assessment) then
      return 'not_qualified';
    end if;
    if not private.adm2_in_contract(v.organization_id, p_user, v.visit_date) then
      return 'outside_contract';
    end if;
    if private.member_absent_during(v.team_id, p_user, lower(private.visit_interval(v)), upper(private.visit_interval(v))) then
      return 'absent';
    end if;
    return 'ok';
  end if;
  if v.responsible_user_id is distinct from p_expected then
    return 'already_taken';                               -- stale proposal: someone assigned the visit meanwhile
  end if;
  if not private.aig1_record_open('care_visits', v.id) then
    return 'not_open';                                    -- also a correction of a listed value (AIG1-C1 (1))
  end if;
  if not private.may_perform_visit(v.team_id, p_user, v.planned_minutes_b, v.is_needs_assessment) then
    return 'not_qualified';                              -- membership, access, qualification, RN for B / assessment
  end if;
  if not private.adm2_in_contract(v.organization_id, p_user, v.visit_date) then
    return 'outside_contract';
  end if;
  if private.member_absent_during(v.team_id, p_user, lower(private.visit_interval(v)), upper(private.visit_interval(v))) then
    return 'absent';
  end if;
  update public.care_visits set responsible_user_id = p_user where id = v.id;
  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  values (v.organization_id, v.id, v.case_id, v.team_id, 'taken',
          private.visit_slot_json(v) || jsonb_build_object('responsible_id', v.responsible_user_id),
          private.visit_slot_json(v) || jsonb_build_object('responsible_id', p_user),
          'Bestätigter Vorschlag (AIG1)', p_actor);
  return 'ok';
end;
$$;
revoke all on function private.aig1_apply_visit_responsible(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- 3. AIG1-C1 (3): a value already applied is not rejected (the line would leave the list with the value unchanged) ------
select private.aig1c_patch('public.confirm_suggestion(uuid, text, jsonb, uuid)', array[
  E'  if p_outcome = ''rejected'' then\n'
  || E'    if p_value is not null then\n',
  E'  if p_outcome = ''rejected'' then\n'
  || E'    -- AIG1-C1 (3): a value already applied stays on its look-back list until it is re-confirmed or changed.\n'
  || E'    if (select c.outcome from public.ai_confirmations c where c.suggestion_id = s.id order by c.seq desc limit 1)\n'
  || E'       in (''confirmed'', ''corrected'') then\n'
  || E'      raise exception ''a value already applied is confirmed again or changed, not rejected (AIG1-C1)'' using errcode = ''22023'';\n'
  || E'    end if;\n'
  || E'    if p_value is not null then\n',
  '1'], 'AIG1-C1 (3)');

-- 4. AIG1-C1 (2): the look-back list says which lines belong to a visit no longer open ----------------------------------
drop function if exists public.agent_stop_lookback(uuid);
create or replace function public.agent_stop_lookback(p_stop_id uuid)
returns table (entity_type text, entity_id uuid, field text, team_id uuid, team_name text, case_ref text,
               visit_date date, proposed_at timestamptz, superseded boolean, superseded_at timestamptz,
               not_open boolean)
language sql stable security definer set search_path = ''
as $$
  select l.entity_type, l.entity_id, l.field, l.team_id, t.name, private.case_reference(l.case_id), v.visit_date,
         l.proposed_at, l.superseded, l.superseded_at,
         (not l.superseded and not private.aig1_record_open(l.entity_type, l.entity_id))      -- AIG1-C1 (2)
  from private.aig1_lookback(p_stop_id) l
  join public.teams t on t.id = l.team_id
  left join public.care_visits v on l.entity_type = 'care_visits' and v.id = l.entity_id
  where not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(l.organization_id)
    and (private.is_coordinator(l.organization_id) or private.is_team_member(l.team_id))
  order by l.superseded, (not l.superseded and not private.aig1_record_open(l.entity_type, l.entity_id)),
           v.visit_date nulls last, t.name, l.proposed_at
$$;
revoke all on function public.agent_stop_lookback(uuid) from public, anon;
grant execute on function public.agent_stop_lookback(uuid) to authenticated;
comment on function public.agent_stop_lookback(uuid) is
  'AIG1-12/-13/AIG1-C1: records holding a value of the stopped agent confirmed unchanged in the stop window (threshold) '
  'or since the switch-on (version change), not confirmed again or corrected since; a line whose record no longer holds '
  'the value stays, marked superseded ("überholt am <Datum>"); a line whose visit is no longer open stays, marked '
  'not_open ("Einsatz nicht mehr offen"), and is not counted as open. No person, no outcome column. Coordinators see '
  'every line; a member only the lines of her own teams'' records. Writes nothing.';

-- 5. AIG1-C1 (2)/(4): the OPS1 detail shows both counts --------------------------------------------------------------------
select private.aig1c_patch('private.derived_exceptions(uuid)', array[
  E'(select count(*) from private.aig1_lookback(st.id) l where not l.superseded) || '' offen''',
  E'''Werte: '' || (select count(*) from private.aig1_lookback(st.id) l where not l.superseded\n'
  || E'           and private.aig1_record_open(l.entity_type, l.entity_id)) || '' offen · ''\n'
  || E'         || (select count(*) from private.aig1_lookback(st.id) l where not l.superseded\n'
  || E'           and not private.aig1_record_open(l.entity_type, l.entity_id)) || '' nicht mehr offen'' /* AIG1-C1 */',
  '1'], 'AIG1-C1');

-- 6. AIG1-C2 (a)/(d): the record page learns which of its values is listed, for the record's team only ----------------
create or replace function public.record_lookback_lines(p_entity_type text, p_entity_id uuid)
returns table (suggestion_id uuid, field text, agent_name text, stop_id uuid, record_open boolean)
language sql stable security definer set search_path = ''
as $$
  select distinct on (l.field) l.suggestion_id, l.field, d.name, st.id,
         private.aig1_record_open(l.entity_type, l.entity_id)
  from public.ai_agent_stops st
  cross join lateral private.aig1_lookback(st.id) l
  join public.ai_agent_definitions d on d.key = st.agent_key
  where p_entity_type = 'care_visits'
    and st.organization_id = (select v.organization_id from public.care_visits v where v.id = p_entity_id)
    and l.entity_type = p_entity_type and l.entity_id = p_entity_id
    and not l.superseded
    and not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(l.organization_id)
    and private.is_team_member(l.team_id)                       -- AIG1-C2 (a)/(d): the record's team, never a role
  order by l.field, st.seq desc
$$;
revoke all on function public.record_lookback_lines(text, uuid) from public, anon;
grant execute on function public.record_lookback_lines(text, uuid) to authenticated;
comment on function public.record_lookback_lines(text, uuid) is
  'AIG1-C2: for active members of the record''s team only (those who may call confirm_suggestion for it), the look-back '
  'line of each field of this record that is still listed and not superseded: suggestion, field, agent, newest stop and '
  'whether the visit is still open. No person, outcome or confirmer. Coordinators who are not team members get no row.';

drop function private.aig1c_patch(text, text[], text);
