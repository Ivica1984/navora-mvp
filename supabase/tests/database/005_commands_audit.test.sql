-- T10: audited, idempotent commands; DB-enforced visit transitions; billable locked.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.start_visit(uuid, uuid)', 'execute'), 'anon cannot execute start_visit');
select ok(not has_function_privilege('anon', 'public.set_team_priority(uuid, boolean, uuid)', 'execute'), 'anon cannot execute set_team_priority');
select ok(has_function_privilege('authenticated', 'public.complete_visit(uuid, uuid)', 'execute'), 'authenticated can execute complete_visit');
select ok(not has_function_privilege('authenticated', 'private.write_audit_event()', 'execute'), 'authenticated cannot call the audit writer');
select ok(not has_column_privilege('authenticated', 'public.care_visits', 'billable', 'update'), 'nobody in the app can update billable (SR-09)');
select ok(not has_table_privilege('authenticated', 'public.audit_events', 'insert'), 'authenticated cannot insert audit events');

-- ---------------------------------------------------------------------------
-- Nurse (team Testteam Nord): start, replay, complete
-- ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is(public.start_visit('00000000-0000-4000-a000-000000000501', 'aaaaaaaa-0000-4000-8000-000000000001'), 'ok',
  'nurse starts a planned visit of her team');
select is(public.start_visit('00000000-0000-4000-a000-000000000501', 'aaaaaaaa-0000-4000-8000-000000000001'), 'duplicate',
  'replaying the same idempotency key is a no-op');
select is(public.start_visit('00000000-0000-4000-a000-000000000501', 'aaaaaaaa-0000-4000-8000-000000000002'), 'rejected',
  'a new key on an already started visit is rejected (state guard)');
select is(public.complete_visit('00000000-0000-4000-a000-000000000501', 'aaaaaaaa-0000-4000-8000-000000000003'), 'ok',
  'nurse completes the visit');
select is((select billable from public.care_visits where id = '00000000-0000-4000-a000-000000000501'), false,
  'completing a visit does not make it billable (SR-09)');
select is(public.start_visit('00000000-0000-4000-a000-000000000505', 'aaaaaaaa-0000-4000-8000-000000000004'), 'rejected',
  'nurse cannot start a visit of another team');

select throws_ok(
  $$ update public.care_visits set status = 'planned' where id = '00000000-0000-4000-a000-000000000502' $$,
  '23514', null, 'direct update started -> planned is blocked by the state machine');
select throws_ok(
  $$ update public.care_visits set status = 'started' where id = '00000000-0000-4000-a000-000000000501' $$,
  '23514', null, 'direct update completed -> started is blocked by the state machine');
select throws_ok(
  $$ update public.care_visits set billable = true where id = '00000000-0000-4000-a000-000000000502' $$,
  '42501', null, 'direct update of billable is denied');
select throws_ok(
  $$ select public.start_visit('00000000-0000-4000-a000-000000000502', null) $$,
  '22023', null, 'a command without idempotency key is rejected');
reset role;

-- ---------------------------------------------------------------------------
-- Coach: team commands
-- ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.set_team_priority('00000000-0000-4000-a000-000000000104', true, 'bbbbbbbb-0000-4000-8000-000000000001'), 'ok',
  'coach sets Coach-Fokus');
select is(public.assign_team_coach('00000000-0000-4000-a000-000000000104', '  Coach Test 3 ', 'bbbbbbbb-0000-4000-8000-000000000002'), 'ok',
  'coach assigns a coach');
select is(public.set_team_priority('00000000-0000-4000-a000-000000000151', true, 'bbbbbbbb-0000-4000-8000-000000000003'), 'rejected',
  'coach cannot change an org-B team through a command');
select is(public.complete_visit('00000000-0000-4000-a000-000000000502', 'bbbbbbbb-0000-4000-8000-000000000004'), 'rejected',
  'coach outside the team cannot complete its started visit (RLS, not state)');
select throws_ok(
  $$ select public.assign_team_coach('00000000-0000-4000-a000-000000000104', '   ', 'bbbbbbbb-0000-4000-8000-000000000005') $$,
  '22023', null, 'blank coach name is rejected');
select is((select count(*)::int from public.audit_events), 0, 'a coach (not admin) cannot read the audit log');
reset role;

-- ---------------------------------------------------------------------------
-- Audit content (read as the table owner, not through the table API; unchanged by AUD1)
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.audit_events where command = 'start_visit'), 1,
  'exactly one audit row for the started visit (replay wrote nothing)');
select is(
  (select changed from public.audit_events where command = 'start_visit'),
  '{"status": {"new": "started", "old": "planned"}}'::jsonb,
  'audit records old and new status');
select is(
  (select actor_id::text || '|' || actor_role from public.audit_events where command = 'complete_visit'),
  '00000000-0000-4000-a000-000000000902|authenticated',
  'audit records the acting user and role');
select is(
  (select changed -> 'coach_name' ->> 'new' from public.audit_events where command = 'assign_team_coach'),
  'Coach Test 3', 'coach name is trimmed and audited');
select ok(
  not exists (select 1 from public.audit_events where changed ?| array['notes', 'services_provided', 'team_member_name']),
  'no free-text column is ever written to the audit log');

-- Direct (non-command) updates are audited too
update public.teams set open_slots = 9 where id = '00000000-0000-4000-a000-000000000103';
select is(
  (select count(*)::int from public.audit_events where command is null and entity_id = '00000000-0000-4000-a000-000000000103'), 1,
  'a direct update outside the commands is audited as well');

select throws_ok($$ delete from public.audit_events $$, '42501', null, 'audit log is append-only, even for the owner');

-- Invariant: every public table that app users can UPDATE has the audit trigger.
-- Fails as soon as a future migration grants UPDATE on an unaudited table.
select is(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and has_any_column_privilege('authenticated', c.oid, 'UPDATE')
     and not exists (
       select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
       where t.tgrelid = c.oid and p.proname = 'write_audit_event')),
  '',
  'every table updatable by app users is audited');

-- AUD1-2 (0077, ADR-090): no standing table read, also for an administrator; she reads one record's rows for a stated
-- purpose through the purpose reader (membership added inside this rolled-back test). Replaces the former positive check
-- of the placeholder policy org_admins_read_audit.
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000903', 'admin');
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.audit_events), 0, 'AUD1-2: an org-A admin reads 0 audit rows through the table');
select is((select count(*)::int from public.read_audit_record('teams', '00000000-0000-4000-a000-000000000104', 'compliance')), 2,
  'AUD1-3: the org-A admin reads the team record''s two audited commands through the purpose reader');
reset role;

select * from finish();
rollback;
