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
-- Idempotent: every change is a patch of the current definition (pg_get_functiondef; each find must match exactly as
-- often as stated) carrying the marker SAFE-D11, skipped when present; rule rows `on conflict do nothing`.

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

-- 1. R1: a reopened case without a team is searched again ---------------------------------------------------------------
-- Patched from the current definition (0034:171-202 as rewritten by 0067 to private.now()), so every later change to the
-- first-search insert stays: only the guard gets one more condition.
select private.safe_d11_patch('private.open_matching_if_ready(uuid)', array[
  E'  if not exists (select 1 from public.matching_requests m where m.case_id = c.id) then\n',
  E'  if not exists (select 1 from public.matching_requests m where m.case_id = c.id)\n'
  || E'     -- SAFE-D11 (ADR-184): an active case without a team whose every earlier search was withdrawn on close\n'
  || E'     or (c.lifecycle = ''active'' and c.assigned_team_id is null\n'
  || E'         and not exists (select 1 from public.matching_requests m where m.case_id = c.id and m.status <> ''withdrawn'')) then\n',
  '1'], 'SAFE-D11');
revoke all on function private.open_matching_if_ready(uuid) from public, anon, authenticated;

-- 2. R1/R6: reopen opens the search again for a case without a team (0024:300-323, current definition, plus one call) --
select private.safe_d11_patch('public.reopen_case(uuid, text, uuid)', array[
  E'        next_step = ''Wiedereröffnet: Angaben prüfen''\n    where id = c.id;\n',
  E'        next_step = ''Wiedereröffnet: Angaben prüfen''\n    where id = c.id;\n'
  || E'  -- SAFE-D11 (ADR-184): a case without a team is in a team search again when it is ready; otherwise OPS1 shows\n'
  || E'  -- case_reopened_no_team with the missing items. Never assigns a team.\n'
  || E'  if c.assigned_team_id is null then\n'
  || E'    perform private.open_matching_if_ready(c.id);\n'
  || E'  end if;\n',
  '1'], 'SAFE-D11');

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
