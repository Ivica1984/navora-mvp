-- SAFE-D11 (brief docs/agents/briefs/SAFE-D11.md, PO 2026-11-12 15:45 CET, founder FE-071; spec B1 Δ11; ADR-184).
-- Documented safety exception, gate «Simulation, synthetic data». No new care rule, no new grant, policy or column.
--
-- Before (IMPLEMENTED, 0024 / 0031 / 0034):
--   * `close_case` withdraws the open team search (0031:43);
--   * `reopen_case` sets the case `active` and keeps `ready_for_matching_at` (0024:300-323), and calls nothing else;
--   * `private.open_matching_if_ready` inserts a search only when NO `matching_requests` row of any status exists for
--     the case (0034:187).
--   So a case closed before any team accepted and then reopened is never searched again, and no exception names it
--   (escalations read `status = 'open'`, 0019:105; `case_not_ready` needs `ready_for_matching_at is null`, 0024:468).
--
-- After (this migration):
--   1. R1: `open_matching_if_ready` also opens a search for an ACTIVE case WITHOUT a team whose every earlier request is
--      `withdrawn` (only `close_case` withdraws; so this is exactly a reopened case). Same insert as a first search:
--      region, urgency, required services, required qualification, referral type, a new response deadline from now
--      (`private.response_due`, PO answer to ADR-184, 15:39) and RET1 first refusal (`private.set_first_refusal`); the
--      BEFORE INSERT trigger of 0086 copies urgency source and requested start as for every search. The withdrawn rows
--      are never touched (history). A case with no request at all behaves exactly as before.
--   2. R1/R6: `reopen_case` calls it once, after the reopen, for a case without a team. A duplicate key returns before
--      (no second call); a second close withdraws the new search, so a second reopen again yields one open search.
--   3. R2: OPS1 exception `case_reopened_no_team` (P2, as `candidates_exhausted`): an active case without a team that was
--      reopened, had been ready, and has no open search. Detail = the missing readiness items (as `case_not_ready`).
--      Key carries the reopen time, so a later reopen is a new exception. It closes with its cause only (a search opens,
--      a team is assigned, the case is closed): `exception_closes_with_cause`, `closable` and the visibility filter of
--      `operations_exceptions` list it, as ORD0-4 did (0061).
--   4. R4: a team can be inactive while its case is reopened (`deactivate_team` refuses only for cases not closed,
--      0035:469; the case can be reopened afterwards). OPS1 exception `case_reopened_team_inactive` (P2, same pattern):
--      a reopened case not closed whose assigned team is not `active`. It never reassigns.
--   5. R5: nothing here sets `assigned_team_id`.
-- Visibility (unchanged readers): `operations_exceptions` lists only for coordinators of the case's organisation;
-- `team_visit_alerts` filters by type and does not include the two new types.
-- Who decides the readiness tiers, P1 for urgent or hospital-discharge cases (`cra`), and the case hand-over to another
-- team (not in the app): OPEN, out of scope.
-- Idempotent: `create or replace`; rule rows `on conflict do nothing`; patches carry the marker SAFE-D11 and are skipped
-- when present.

-- 0. Patch helper (removed at the end) ------------------------------------------------------------------------------------
create or replace function private.safe_d11_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0125 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0125 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.safe_d11_patch(text, text[], text) from public, anon, authenticated;

-- 1. R1: a reopened case without a team is searched again (0034:171-202 with one more condition) -----------------------
create or replace function private.open_matching_if_ready(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
  missing jsonb := private.case_readiness(p_case_id);
  rtype text;
  rid uuid;
begin
  if jsonb_array_length(missing) > 0 then
    return missing;
  end if;
  select * into c from public.cases where id = p_case_id;
  if c.ready_for_matching_at is null then
    update public.cases set ready_for_matching_at = now(), next_step = 'Teamentscheid ausstehend' where id = c.id;
  end if;
  if not exists (select 1 from public.matching_requests m where m.case_id = c.id)
     -- SAFE-D11 (ADR-184): an active case without a team whose every earlier search was withdrawn on close
     or (c.lifecycle = 'active' and c.assigned_team_id is null
         and not exists (select 1 from public.matching_requests m where m.case_id = c.id and m.status <> 'withdrawn')) then
    rtype := private.referral_type_of((select p.partner_type from public.partner_requests p where p.id = c.source_partner_request_id));
    insert into public.matching_requests
      (organization_id, case_id, request_title, region, urgency, required_services, status,
       referral_type, response_due_at, required_qualification)
    values
      (c.organization_id, c.id, 'Teamsuche: ' || coalesce(c.bedarf, 'Klientenfall'), c.region, c.urgency,
       coalesce(c.care_needs, '{}'), 'open',
       rtype, private.response_due(c.organization_id, rtype, now()),
       private.required_qualification(c.id))
    returning id into rid;
    perform private.set_first_refusal(rid);   -- RET1: returning client
  end if;
  return '[]'::jsonb;
end;
$$;
revoke all on function private.open_matching_if_ready(uuid) from public, anon, authenticated;

-- 2. R1/R6: reopen opens the search again for a case without a team (0024:300-323 plus one call) ------------------------
create or replace function public.reopen_case(p_case_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  why text := private.check_text(p_reason, 3, 500, 'reason');
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('reopen_case', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from private.case_for_team_or_ops(p_case_id, true);
  if c.id is null then return private.end_command('rejected'); end if;
  if c.lifecycle <> 'closed' then return private.end_command('wrong_state'); end if;
  insert into public.case_lifecycle_events (organization_id, case_id, kind, note, actor_id, idempotency_key)
  values (c.organization_id, c.id, 'reopen', why, uid, p_idempotency_key);
  update public.cases
    set lifecycle = 'active', reopened_at = now(),
        status = case when c.assigned_team_id is not null then 'laufend' else 'neu' end,
        next_step = 'Wiedereröffnet: Angaben prüfen'
    where id = c.id;
  -- SAFE-D11 (ADR-184): a case without a team is in a team search again when it is ready; otherwise OPS1 shows
  -- `case_reopened_no_team` with the missing items. Never assigns a team.
  if c.assigned_team_id is null then
    perform private.open_matching_if_ready(c.id);
  end if;
  return private.end_command('ok');
end;
$$;
revoke all on function public.reopen_case(uuid, text, uuid) from public, anon;
grant execute on function public.reopen_case(uuid, text, uuid) to authenticated;

-- 3. R2 / R4: two OPS1 exception types -------------------------------------------------------------------------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  ('case_reopened_no_team', 'P2', null, null, null, 'Wiedereröffneter Fall ohne Team',
   'Fehlende Angaben ergänzen; die Teamsuche öffnet sich dann selbst. Nie automatisch zuweisen.'),
  ('case_reopened_team_inactive', 'P2', null, null, null, 'Wiedereröffneter Fall: Team nicht mehr aktiv',
   'Das zugewiesene Team ist nicht mehr aktiv. Klären, welches Team den Fall übernimmt; eine Übergabe ist in der App noch nicht möglich. Nie automatisch zuweisen.')
on conflict (exception_type) do nothing;

select private.safe_d11_patch('private.derived_exceptions(uuid)', array[
  E'  union all\n  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)\n',
  E'  union all\n'
  || E'  -- SAFE-D11 R2 (ADR-184): a reopened case without a team and without an open team search (closes with its cause)\n'
  || E'  select ''case_reopened_no_team:'' || c.id || '':'' || extract(epoch from c.reopened_at)::bigint, ''case_reopened_no_team'',\n'
  || E'         c.reopened_at, c.id, null::uuid, ''case'', c.id,\n'
  || E'         (select string_agg(m ->> ''item'', '', '') from jsonb_array_elements(private.case_readiness(c.id)) m)\n'
  || E'  from public.cases c\n'
  || E'  join rules r on r.exception_type = ''case_reopened_no_team''\n'
  || E'  where c.organization_id = p_org and c.lifecycle = ''active'' and c.assigned_team_id is null\n'
  || E'    and c.reopened_at is not null and c.ready_for_matching_at is not null\n'
  || E'    and not exists (select 1 from public.matching_requests m where m.case_id = c.id and m.status = ''open'')\n'
  || E'  union all\n'
  || E'  -- SAFE-D11 R4: a reopened case whose team is no longer active (closes with its cause; never reassigns)\n'
  || E'  select ''case_reopened_team_inactive:'' || c.id || '':'' || extract(epoch from c.reopened_at)::bigint, ''case_reopened_team_inactive'',\n'
  || E'         c.reopened_at, c.id, c.assigned_team_id, ''case'', c.id, null::text\n'
  || E'  from public.cases c\n'
  || E'  join public.teams t on t.id = c.assigned_team_id\n'
  || E'  join rules r on r.exception_type = ''case_reopened_team_inactive''\n'
  || E'  where c.organization_id = p_org and c.lifecycle <> ''closed'' and c.reopened_at is not null\n'
  || E'    and t.status is distinct from ''active''\n'
  || E'  union all\n  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)\n',
  '1'], 'SAFE-D11');
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- Both close only with their cause: in the close command (0047, 0061) and in OPS1 (`closable`, the visibility filter).
select private.safe_d11_patch('private.exception_closes_with_cause(uuid, text)', array[
  E'''order_without_end_date'' /* ORD0-4 */)',
  E'''order_without_end_date'' /* ORD0-4 */, ''case_reopened_no_team'', ''case_reopened_team_inactive'' /* SAFE-D11 */)',
  '1'], 'SAFE-D11');
revoke all on function private.exception_closes_with_cause(uuid, text) from public, anon, authenticated;

select private.safe_d11_patch('public.operations_exceptions()', array[
  E'''order_without_end_date'' /* ORD0-4 */)',
  E'''order_without_end_date'' /* ORD0-4 */, ''case_reopened_no_team'', ''case_reopened_team_inactive'' /* SAFE-D11 */)',
  '2'], 'SAFE-D11');

drop function private.safe_d11_patch(text, text[], text);
