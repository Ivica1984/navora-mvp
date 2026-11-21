-- AIG1-C4 (CGR-107, with CGR-106) and AIG1-C5 (AUT-30) (ADR-139). PO brief docs/agents/briefs/AIG1.md, 2026-10-31
-- 02:25 and 02:55 CET. Synthetic data only. Both conditions must hold before the first agent other than the synthetic
-- test agent is switched on and before any real data.
--
-- No clinical rule is made here: whether late proposals are a fault of the assistant, whether expired proposals count
-- toward a stop, and whether, by whom and by when a listed value must be re-checked stay the Clinical Owner's (D-17,
-- UNKNOWN). NAVORA only stops asking for a decision without content and stops tying a stop's follow-up to the agent's
-- state.
--
-- Before (IMPLEMENTED, 0097 / 0103 / 0104):
--   * `open_suggestions` listed every undecided proposal, also one whose visit is no longer open; the only way to clear
--     it was "Ablehnen", which writes a `rejected` confirmation and so counts as a correction in `aig1_window_stats`.
--   * `agent_health` showed no count of proposals that passed undecided.
--   * The OPS1 `agent_stopped` exception existed only for `last_stop_id` while `state = 'stopped'`: switching the agent
--     off (or on) removed it with open lines left, and a worked-down stop kept "0 offen" alive until a restart.
--   * `agent_health` returned the stop only while `state = 'stopped'`, so the look-back link vanished with the state.
-- After:
--   1. AIG1-C4 (1): `open_suggestions` returns only proposals whose record is still open (`private.aig1_record_open`,
--      Europe/Zurich, unchanged condition). Filtered on read; the ledger row stays as it is (append-only, undecided).
--   2. AIG1-C4 (1)/(2) guard: `confirm_suggestion` refuses `not_open` for an undecided proposal whose record is no longer
--      open, whatever the outcome (confirmed, corrected, rejected, not_found). No confirmation row is written, so such a
--      proposal is never decided and never a correction; it has expired. Confirm and correct were already refused
--      `not_open` by the consuming command; reject and not_found are new refusals (a decision without content).
--   3. AIG1-C4 (2): `aig1_window_stats` is unchanged: it already counts only proposals someone decided.
--   4. AIG1-C4 (3): `private.aig1_window_expired` counts, per agent and window, the undecided proposals whose record is no
--      longer open; `agent_health` returns it for the last closed window as `last_window_expired` (null before the first
--      closed window). Per agent and organisation, never per person (AIG1-11).
--   5. AIG1-C5 (a): the OPS1 `agent_stopped` exception is derived per stop of the organisation that has at least one open
--      line (not superseded, record still open), whatever the agent's state now; it closes by itself at "0 offen".
--   6. AIG1-C5 (b)/(c): `agent_health` returns `stops`, every stop of the agent newest first with its id, reason, date
--      and counts (`open`, `not_open`), so a stop with open lines keeps its link and a stop at 0 offen stays readable as
--      history whatever the state. The existing stop columns keep their meaning (filled while `stopped`) for the status.
--   7. AIG1-C5 (e): no new reader, role or person column; the look-back reader `agent_stop_lookback` is unchanged.
-- Idempotent: `create or replace`; `drop function if exists` before `agent_health`'s changed return type; patches carry a
-- marker and are skipped when present.

-- 0. Patch helper (removed at the end) ------------------------------------------------------------------------------------
create or replace function private.aig1d_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0105 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0105 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.aig1d_patch(text, text[], text) from public, anon, authenticated;

-- 1. AIG1-C4 (1): the confirm screen lists only proposals that can still be decided --------------------------------------
create or replace function public.open_suggestions(p_team_id uuid)
returns table (suggestion_id uuid, agent_key text, agent_name text, field text, entity_type text, entity_id uuid,
               visit_date date, time_start time, not_found boolean, proposed_value jsonb, proposed_name text,
               bulk_allowed boolean, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select s.id, s.agent_key, d.name, s.field, s.entity_type, s.entity_id, v.visit_date, v.time_start, s.not_found,
         s.proposed_value,
         case when s.field = 'responsible_user_id' and not s.not_found
              then private.member_name(s.organization_id, (s.proposed_value #>> '{}')::uuid) end,
         f.class = 'schedule' and d.kind = 'rule' and d.level = 'L' and not s.not_found
           and not exists (select 1 from public.ai_one_by_one_fields o where o.organization_id = s.organization_id
                           and o.agent_key = s.agent_key and o.field = s.field),
         s.created_at
  from public.ai_suggestions s
  join public.ai_agent_definitions d on d.key = s.agent_key
  join public.ai_agent_fields f on f.agent_key = s.agent_key and f.field = s.field
  left join public.care_visits v on s.entity_type = 'care_visits' and v.id = s.entity_id
  where s.team_id = p_team_id
    and not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(s.organization_id) and private.is_team_member(s.team_id)
    and not exists (select 1 from public.ai_confirmations c where c.suggestion_id = s.id)
    and private.aig1_record_open(s.entity_type, s.entity_id)                                   -- AIG1-C4 (1)
  order by v.visit_date nulls last, v.time_start nulls last, s.seq
$$;
revoke all on function public.open_suggestions(uuid) from public, anon;
grant execute on function public.open_suggestions(uuid) to authenticated;
comment on function public.open_suggestions(uuid) is
  'AIG1-3/-5/AIG1-C4: undecided proposals of one team for its active members (confirm screen), only while the record is '
  'still open; a proposal whose visit passed undecided has expired and is not listed (the ledger row stays). No '
  'confirmer, no outcome.';

-- 2. AIG1-C4 (1)/(2): an expired proposal is not decided (no confirmation row, never a correction) ----------------------
select private.aig1d_patch('public.confirm_suggestion(uuid, text, jsonb, uuid)', array[
  E'  if not found or not private.is_org_member(s.organization_id) or not private.is_team_member(s.team_id) then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''rejected''));\n'
  || E'  end if;\n',
  E'  if not found or not private.is_org_member(s.organization_id) or not private.is_team_member(s.team_id) then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''rejected''));\n'
  || E'  end if;\n'
  || E'  -- AIG1-C4 (1)/(2): an undecided proposal whose record is no longer open has expired; nobody decides it.\n'
  || E'  if not exists (select 1 from public.ai_confirmations c where c.suggestion_id = s.id)\n'
  || E'     and not private.aig1_record_open(s.entity_type, s.entity_id) then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''refused''), ''reason'', ''not_open'');\n'
  || E'  end if;\n',
  '1'], 'AIG1-C4');

-- 3. AIG1-C4 (3): expired proposals per agent and window ---------------------------------------------------------------
create or replace function private.aig1_window_expired(p_org uuid, p_key text, p_from timestamptz, p_to timestamptz)
returns integer language sql stable security definer set search_path = ''
as $$
  select count(*)::int
  from public.ai_suggestions s
  where s.organization_id = p_org and s.agent_key = p_key and s.created_at >= p_from and s.created_at < p_to
    and not exists (select 1 from public.ai_confirmations c where c.suggestion_id = s.id)
    and not private.aig1_record_open(s.entity_type, s.entity_id)
$$;
revoke all on function private.aig1_window_expired(uuid, text, timestamptz, timestamptz) from public, anon, authenticated;
comment on function private.aig1_window_expired(uuid, text, timestamptz, timestamptz) is
  'AIG1-C4 (3): proposals of one agent in one organisation created in [p_from, p_to) that nobody decided and whose '
  'record is no longer open ("Abgelaufen ohne Entscheid"). Never counted as decided or as a correction.';

-- 4. AIG1-C5: the counts of one stop's look-back lines (the same split as `agent_stop_lookback` and the OPS1 detail) ----
create or replace function private.aig1_stop_counts(p_stop_id uuid)
returns table (open_lines integer, not_open_lines integer)
language sql stable security definer set search_path = ''
as $$
  select count(*) filter (where not l.superseded and private.aig1_record_open(l.entity_type, l.entity_id))::int,
         count(*) filter (where not l.superseded and not private.aig1_record_open(l.entity_type, l.entity_id))::int
  from private.aig1_lookback(p_stop_id) l
$$;
revoke all on function private.aig1_stop_counts(uuid) from public, anon, authenticated;

-- 5. AIG1-C4 (3) / AIG1-C5 (b)/(c): the health list carries the expired count and every stop with its counts ----------
drop function if exists public.agent_health(uuid);
create or replace function public.agent_health(p_organization_id uuid)
returns table (agent_key text, agent_name text, level text, kind text, version text, state text,
               last_proposal_at timestamptz, last_window_share numeric, last_window_decided integer,
               stop_reason text, stopped_at timestamptz, stop_id uuid,
               stop_share numeric, stop_min_proposals integer, stop_window_days integer,
               last_window_min_reached boolean, last_window_expired integer, stops jsonb)
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
         case when lw.decided is null then null else lw.decided >= s.stop_min_proposals end,  -- AIG1-16 (2)
         lw.expired,                                                                           -- AIG1-C4 (3)
         (select coalesce(jsonb_agg(jsonb_build_object('stop_id', x.id, 'reason', x.reason, 'stopped_at', x.created_at,
                                                       'open', c.open_lines, 'not_open', c.not_open_lines)
                                    order by x.seq desc), '[]'::jsonb)                         -- AIG1-C5 (b)
          from public.ai_agent_stops x
          cross join lateral private.aig1_stop_counts(x.id) c
          where x.organization_id = p_organization_id and x.agent_key = d.key)
  from public.ai_agent_definitions d
  left join public.ai_agent_settings s on s.organization_id = p_organization_id and s.agent_key = d.key
  left join public.ai_agent_stops st on st.id = s.last_stop_id and s.state = 'stopped'
  left join lateral (
    select w.share, w.decided, private.aig1_window_expired(p_organization_id, d.key, b.w_from, b.w_to) as expired
    from (select s.switched_on_at + (z.nwin - 1) * z.iv as w_from, s.switched_on_at + z.nwin * z.iv as w_to
          from (select make_interval(days => s.stop_window_days) as iv,
                       floor(extract(epoch from (private.now() - s.switched_on_at))
                             / extract(epoch from make_interval(days => s.stop_window_days))) as nwin) z) b
    cross join lateral private.aig1_window_stats(p_organization_id, d.key, b.w_from, b.w_to) w
    where s.switched_on_at is not null
      and private.now() >= s.switched_on_at + make_interval(days => s.stop_window_days)
  ) lw on true
  order by d.name;
end;
$$;
revoke all on function public.agent_health(uuid) from public, anon;
grant execute on function public.agent_health(uuid) to authenticated;
comment on function public.agent_health(uuid) is
  'AIG1-10/-16/AIG1-C4/AIG1-C5: one line per agent for coordinators of the organisation: state, last proposal, last '
  'closed window''s correction share, decided count and expired count (proposals that passed undecided), why it is '
  'stopped (while stopped), the written threshold, whether the last closed window reached the minimum, and every stop '
  'of the agent newest first with its look-back counts (open, not_open), whatever the state. No person column.';

-- 6. AIG1-C5 (a): one OPS1 exception per stop with an open line, whatever the agent's state ------------------------------
select private.aig1d_patch('private.derived_exceptions(uuid)', array[
  E'(closes when it is switched on again)',
  E'(AIG1-C5: listed per stop while it has an open line)',
  '1',
  E'  from public.ai_agent_settings g\n'
  || E'  join public.ai_agent_stops st on st.id = g.last_stop_id\n'
  || E'  join public.ai_agent_definitions d on d.key = g.agent_key\n',
  E'  from public.ai_agent_stops st\n'
  || E'  join public.ai_agent_definitions d on d.key = st.agent_key\n',
  '1',
  E'  where g.organization_id = p_org and g.state = ''stopped''\n',
  E'  where st.organization_id = p_org\n'
  || E'    and exists (select 1 from private.aig1_lookback(st.id) l where not l.superseded\n'
  || E'                and private.aig1_record_open(l.entity_type, l.entity_id))\n',
  '1'], 'AIG1-C5');

drop function private.aig1d_patch(text, text[], text);
