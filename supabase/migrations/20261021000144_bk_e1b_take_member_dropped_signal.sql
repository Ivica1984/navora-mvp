-- BK-e1b / CGR-246 (brief docs/agents/briefs/BK.md §PO amendments 2026-11-18 05:39 (2), 06:39 (4), 08:39 (1)(b) and
-- 09:39 (1); `cra` 05:26, 06:27, 09:27; `lca` 08:20, D-44 (2); ADR-203 (12), (16)). Red first: pgTAP 148 §10 and §13
-- (commit b2fe4d0) fail before this migration. Gate «Simulation, synthetic data» only.
--
-- Before: a live take whose named member no longer passes (`private.order_member_step < 4`) is kept when her visit is
--   under way (CGR-244) or when the start has passed (CGR-242, CGR-250 choice (b)). The client reads «nicht gedeckt»
--   (ADR-199 (5) safety net), but nobody is told: after the start the absent member is the only person who sees the
--   take visit, and the order is not offered again.
-- Now (IMPLEMENTED in this migration), through the existing SIG1 path (ADR-074), no new channel:
--   1. a derived exception `take_member_dropped` (P1, no threshold; no time rule is invented): one row per live take
--      whose named member does not pass while its visit is on the way, started or paused, or still planned at or after
--      the order's start. Entity: the take's visit; team: the take's team; detail: the step code only (`step_0` …
--      `step_3`), never the absence type or any person data (D-44 (2)). `since`: the start for a planned visit, else
--      the visit's last status event. It closes with its cause (the visit leaves those states, she passes again, or
--      the take ends), because a P1 type closes with its cause (`private.exception_is_safety`).
--   2. `private.signal_kind_of` maps it to the signal kind `take_member_dropped` (the kind check is widened).
--   3. recipients: the SIG1 rule unchanged (the non-absent members of the owning team, the responsible member when not
--      absent, Operations when nobody is on duty), plus the named member herself even when absent, as long as she is
--      still in the team and her access has not ended (CGR-246 «to her»). Never another team, never the client or a
--      partner account (no new read path; `my_signals` reads deliveries only).
--   4. take and visit are never changed by the signal (CGR-244).
-- Operations of the same organisation read the OPS1 row as for every P1 type (`lca` 08:20 accepted, codes-only detail).
-- Not here: the words to her and to the team with the display name (`uxa` 05:48, confirmed by `cra` 06:27) need a
-- recipient-specific line on the card; the banner shows the kind text (ADR-203 (16), deviation stated). Re-offer after
-- a drop-out and the one-tap «Ich übernehme» (H-BK-05:39) are later slices.
-- Unchanged: every other exception type, signal kind and recipient. Patches are checked to match exactly once and carry
-- the marker BK-E1B-S (idempotent: a patched body is skipped). No data change. No clinical, legal or tariff rule.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.bk_e1b_s_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0144 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0144 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_e1b_s_patch(text, text[], text) from public, anon, authenticated;

-- 1. Operating rule (P1, no threshold) -----------------------------------------------------------------------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step)
values ('take_member_dropped', 'P1', null, null, null,
        'Übernommene Schicht: Person fällt aus',
        'Im Team klären, wer übernimmt.')
on conflict (exception_type) do nothing;

-- 2. Signal kind -----------------------------------------------------------------------------------------------------------
alter table public.safety_signals drop constraint if exists safety_signals_signal_kind_check;
alter table public.safety_signals add constraint safety_signals_signal_kind_check
  check (signal_kind in ('visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_interrupted', 'no_show',
                         'take_member_dropped'));

create or replace function private.signal_kind_of(p_exception_type text)
returns text language sql immutable set search_path = ''
as $$
  select case p_exception_type
    when 'visit_overdue' then 'visit_overdue'
    when 'visit_stuck' then 'visit_stuck'
    when 'visit_uncovered' then 'visit_uncovered'
    when 'visit_uncovered_hospital' then 'visit_uncovered'
    when 'visit_interrupted' then 'visit_interrupted'
    when 'no_show_open' then 'no_show'
    when 'take_member_dropped' then 'take_member_dropped'  -- BK-E1B-S (CGR-246)
  end
$$;
revoke all on function private.signal_kind_of(text) from public, anon, authenticated;

-- 3. Derived exception ------------------------------------------------------------------------------------------------------
select private.bk_e1b_s_patch('private.derived_exceptions(uuid)', array[
  E'  union all\n  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)\n',
  E'  union all\n'
  || E'  -- BK-E1B-S (CGR-246, ADR-203 (12)): a live take whose named member no longer passes while its visit is under way\n'
  || E'  -- or still planned after the start; P1 to her own team and to her (SIG1), closes with its cause; code detail only\n'
  || E'  select ''take_member_dropped:'' || k.id, ''take_member_dropped'',\n'
  || E'         case when v.status = ''planned'' then o.starts_at else coalesce(last.at, o.starts_at) end,\n'
  || E'         v.case_id, k.team_id, ''visit'', v.id, ''step_'' || st.step\n'
  || E'  from public.order_takes k\n'
  || E'  join public.partner_requests o on o.id = k.order_id\n'
  || E'  join public.care_visits v on v.order_take_id = k.id\n'
  || E'  cross join lateral (select private.order_member_step(o.id, k.team_id, k.member_id) as step) st\n'
  || E'  left join lateral (select max(e.occurred_at) as at from public.visit_events e where e.visit_id = v.id) last on true\n'
  || E'  join rules r on r.exception_type = ''take_member_dropped''\n'
  || E'  where k.organization_id = p_org and k.released_at is null and st.step < 4\n'
  || E'    and (v.status in (''on_the_way'', ''started'', ''paused'')\n'
  || E'         or (v.status = ''planned'' and private.now() >= o.starts_at))\n'
  || E'  union all\n  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)\n',
  '1'], 'BK-E1B-S');
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- 4. Recipients: the SIG1 rule, plus the named member herself (even when absent) ------------------------------------------
select private.bk_e1b_s_patch('private.signal_recipients(uuid)', array[
  E'  select o, ''operations_fallback'' from s, private.signal_operations_users(s.organization_id) o\n'
  || E'  where not exists (select 1 from direct_one)\n',
  E'  select o, ''operations_fallback'' from s, private.signal_operations_users(s.organization_id) o\n'
  || E'  where not exists (select 1 from direct_one)\n'
  || E'  union all\n'
  || E'  -- BK-E1B-S (CGR-246): the take''s named member herself, even when absent, while still in the team with access.\n'
  || E'  -- The fallback above is decided without her, so an absent member alone never replaces Operations.\n'
  || E'  select k.member_id, ''responsible'' from s\n'
  || E'  join public.care_visits v on v.id = s.visit_id\n'
  || E'  join public.order_takes k on k.id = v.order_take_id\n'
  || E'  where s.signal_kind = ''take_member_dropped''\n'
  || E'    and private.user_in_team(s.team_id, k.member_id) and not private.access_ended(k.member_id)\n'
  || E'    and not exists (select 1 from direct_one d where d.user_id = k.member_id)\n',
  '1'], 'BK-E1B-S');
revoke all on function private.signal_recipients(uuid) from public, anon, authenticated;

drop function private.bk_e1b_s_patch(text, text[], text);
