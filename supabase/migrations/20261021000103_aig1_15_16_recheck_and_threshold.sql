-- AIG1-15 and AIG1-16 (ADR-128): a look-back re-confirmation runs the checks of a first confirmation, and a stop
-- threshold that cannot fire is refused while the health list shows the written threshold. PO brief
-- docs/agents/briefs/AIG1.md (AIG1-15, AIG1-16, added by po 2026-10-30 02:10 from `cra` CGR-98 and CGR-100 (1)-(2),
-- `lca` D-35 01:50). Part (b) of AIG1, database half; the screens follow in the part (b) UI PR. Synthetic data only.
--
-- No clinical, legal or tariff rule is made here, and no threshold value is set: the stop share, minimum and window stay
-- the switching administrator's. Whether a performed visit with a no-longer-valid member needs action is the Clinical
-- Owner's (D-17, UNKNOWN); a visit no longer open is re-confirmed as built.
--
-- Before (IMPLEMENTED, 0097 / #701):
--   * `private.aig1_apply_visit_responsible` returned `ok` at once when the visit already held the confirmed member,
--     so a look-back re-confirmation (AIG1-12 (iv)) wrote "bestätigt" without the open-visit, qualification, contract
--     and absence checks (CGR-98).
--   * `public.set_agent_state` accepted `stop_share = 100`; the stop fires on a share above the threshold, so it never
--     fired (CGR-100 (1)).
--   * `public.agent_health` returned no threshold and no "minimum reached" flag (CGR-100 (2)).
-- After:
--   1. AIG1-15: when the visit already holds the value and is still open (`planned`, not suspended or covered, not dated
--      before today, Europe/Zurich), `may_perform_visit` (-> not_qualified), `adm2_in_contract` (-> outside_contract)
--      and `member_absent_during` (-> absent) run in the order of a first confirmation. `confirm_suggestion` and
--      `confirm_suggestions` already write no `ai_confirmations` row when the applier refuses, so the line stays on the
--      look-back list. No table, grant or read path changes.
--   2. AIG1-16 (1): `set_agent_state` refuses a share of 100 or more with the existing `threshold_missing`.
--   3. AIG1-16 (2): `agent_health` also returns `stop_share`, `stop_min_proposals`, `stop_window_days` and
--      `last_window_min_reached` (the last closed window's decided count >= the minimum; null before the first closed
--      window). Per agent and organisation; no person column. The return type changes, so the function is dropped and
--      re-created with its grants (only pgTAP 097 and the generated types read it; no app caller yet).
-- Idempotent: `create or replace`; `drop function if exists` before the changed return type.

-- 1. AIG1-15: the re-confirmation runs the first confirmation's checks -----------------------------------------------------
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
    -- The record already holds this value (a re-confirmation, AIG1-12 (iv)). AIG1-15: while the visit is still open
    -- (the open-visit condition below), the checks of a first confirmation run in the same order; a refusal returns
    -- its reason and the caller writes no confirmation. A visit no longer open stays as built (Clinical Owner, UNKNOWN).
    if v.status = 'planned' and v.suspended_at is null and v.covered_by is null
       and v.visit_date >= (private.at_zurich(private.now()))::date then
      if not private.may_perform_visit(v.team_id, p_user, v.planned_minutes_b, v.is_needs_assessment) then
        return 'not_qualified';
      end if;
      if not private.adm2_in_contract(v.organization_id, p_user, v.visit_date) then
        return 'outside_contract';
      end if;
      if private.member_absent_during(v.team_id, p_user, lower(private.visit_interval(v)), upper(private.visit_interval(v))) then
        return 'absent';
      end if;
    end if;
    return 'ok';
  end if;
  if v.responsible_user_id is distinct from p_expected then
    return 'already_taken';                               -- stale proposal: someone assigned the visit meanwhile
  end if;
  if v.status <> 'planned' or v.suspended_at is not null or v.covered_by is not null
     or v.visit_date < (private.at_zurich(private.now()))::date then
    return 'not_open';
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

-- 2. AIG1-16 (1): a share that can never be exceeded is no threshold ------------------------------------------------------
create or replace function public.set_agent_state(p_organization_id uuid, p_agent_key text, p_on boolean,
                                                  p_stop_share numeric, p_stop_min_proposals integer,
                                                  p_stop_window_days integer, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  d   public.ai_agent_definitions%rowtype;
  s   public.ai_agent_settings%rowtype;
  had boolean;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_on is null then
    raise exception 'on is required' using errcode = '22023';
  end if;
  if private.begin_command('set_agent_state', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if not private.is_org_admin(p_organization_id) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  select * into d from public.ai_agent_definitions x where x.key = p_agent_key;
  if not found then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'unknown_agent');
  end if;
  select * into s from public.ai_agent_settings x
  where x.organization_id = p_organization_id and x.agent_key = p_agent_key for update;
  had := found;

  if not p_on then
    if not had or s.state = 'off' then
      return jsonb_build_object('result', private.end_command('unchanged'));
    end if;
    update public.ai_agent_settings set state = 'off', updated_at = private.now() where id = s.id;
    return jsonb_build_object('result', private.end_command('ok'));
  end if;

  -- Switch-on refusals, each with its stated reason.
  if d.kind = 'ai' then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'ai_not_allowed',
      'detail', 'D-35 Regel A: Kein KI-Dienst in irgendeiner Umgebung, bis der Inhaber Stufe 1 freigibt.');
  end if;
  if d.level in ('G', 'H') then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'level_not_allowed',
      'detail', 'D-34: Assistenten der Stufe G oder H gehören zum klinischen Modul und sind hier nicht einschaltbar.');
  end if;
  -- AIG1-16 (1): a share of 100 can never be exceeded (the stop fires on a share above it), so it is no threshold.
  if p_stop_share is null or p_stop_share < 0 or p_stop_share >= 100
     or p_stop_min_proposals is null or p_stop_min_proposals not between 1 and 100000
     or p_stop_window_days is null or p_stop_window_days not between 1 and 366 then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'threshold_missing',
      'detail', 'AIG1-8: Ohne schriftliche Stoppschwelle (Anteil, Mindestzahl, Zeitfenster) wird nicht eingeschaltet.');
  end if;
  if d.fixture is null or to_regprocedure('private.' || d.fixture || '()') is null then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'no_fixture',
      'detail', 'AIG1-9: Ohne Testfälle wird nicht eingeschaltet.');
  end if;
  if had and s.state = 'on' and s.stop_share = p_stop_share and s.stop_min_proposals = p_stop_min_proposals
     and s.stop_window_days = p_stop_window_days and s.on_version = d.version then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;

  insert into public.ai_agent_settings (organization_id, agent_key, state, stop_share, stop_min_proposals,
                                        stop_window_days, switched_on_by, switched_on_at, on_version, on_provider,
                                        on_region, last_stop_id, updated_at)
  values (p_organization_id, p_agent_key, 'on', p_stop_share, p_stop_min_proposals, p_stop_window_days, uid,
          private.now(), d.version, d.provider, d.region, null, private.now())
  on conflict (organization_id, agent_key) do update
    set state = 'on', stop_share = excluded.stop_share, stop_min_proposals = excluded.stop_min_proposals,
        stop_window_days = excluded.stop_window_days, switched_on_by = excluded.switched_on_by,
        switched_on_at = excluded.switched_on_at, on_version = excluded.on_version, on_provider = excluded.on_provider,
        on_region = excluded.on_region, last_stop_id = null, updated_at = excluded.updated_at;
  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.set_agent_state(uuid, text, boolean, numeric, integer, integer, uuid) from public, anon;
grant execute on function public.set_agent_state(uuid, text, boolean, numeric, integer, integer, uuid) to authenticated;
comment on function public.set_agent_state(uuid, text, boolean, numeric, integer, integer, uuid) is
  'AIG1-1/-8/-16: an organisation administrator switches an agent on (with its written stop threshold) or off. Audited, '
  'idempotent. Refused with a stated reason: kind ai (D-35 rule A), level G/H (D-34), no threshold or a share of 100 or '
  'more that can never be exceeded (threshold_missing), no fixture. A '
  'restart after a stop is a new switch-on.';

-- 3. AIG1-16 (2): the health list carries the written threshold and whether the last window reached the minimum ----------
drop function if exists public.agent_health(uuid);
create or replace function public.agent_health(p_organization_id uuid)
returns table (agent_key text, agent_name text, level text, kind text, version text, state text,
               last_proposal_at timestamptz, last_window_share numeric, last_window_decided integer,
               stop_reason text, stopped_at timestamptz, stop_id uuid,
               stop_share numeric, stop_min_proposals integer, stop_window_days integer,
               last_window_min_reached boolean)
language plpgsql volatile security definer set search_path = ''
as $$
#variable_conflict use_column
declare k text;
begin
  if (select auth.uid()) is null or private.access_ended((select auth.uid()))              -- LEAVE1-3
     or not private.is_coordinator(p_organization_id) then
    return;
  end if;
  for k in select s.agent_key from public.ai_agent_settings s where s.organization_id = p_organization_id loop
    perform private.aig1_check(p_organization_id, k);
  end loop;
  return query
  select d.key, d.name, d.level, d.kind, d.version, coalesce(s.state, 'off'),
         (select max(x.created_at) from public.ai_suggestions x where x.organization_id = p_organization_id and x.agent_key = d.key),
         lw.share, lw.decided,
         st.reason, st.created_at, st.id,
         s.stop_share, s.stop_min_proposals, s.stop_window_days,
         case when lw.decided is null then null else lw.decided >= s.stop_min_proposals end   -- AIG1-16 (2)
  from public.ai_agent_definitions d
  left join public.ai_agent_settings s on s.organization_id = p_organization_id and s.agent_key = d.key
  left join public.ai_agent_stops st on st.id = s.last_stop_id and s.state = 'stopped'
  left join lateral (
    select w.share, w.decided
    from private.aig1_window_stats(p_organization_id, d.key,
           s.switched_on_at + (floor(extract(epoch from (private.now() - s.switched_on_at))
                                     / extract(epoch from make_interval(days => s.stop_window_days))) - 1)
                              * make_interval(days => s.stop_window_days),
           s.switched_on_at + floor(extract(epoch from (private.now() - s.switched_on_at))
                                    / extract(epoch from make_interval(days => s.stop_window_days)))
                              * make_interval(days => s.stop_window_days)) w
    where s.switched_on_at is not null
      and private.now() >= s.switched_on_at + make_interval(days => s.stop_window_days)
  ) lw on true
  order by d.name;
end;
$$;
revoke all on function public.agent_health(uuid) from public, anon;
grant execute on function public.agent_health(uuid) to authenticated;
comment on function public.agent_health(uuid) is
  'AIG1-10/-16: one line per agent for coordinators of the organisation: state, last proposal, last closed window''s '
  'correction share and decided count, why it stopped, the written threshold (share, minimum decided count, window '
  'days) and whether the last closed window reached the minimum (null before the first closed window). No person column.';
