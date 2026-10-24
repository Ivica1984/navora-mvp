-- F4: observations with provenance, team-only visibility, versions, handover.
-- Users: coach …901 (org A, no team) · nurse …902 (Testteam Nord) · foreign …903 (org B)
-- Visits (Testteam Nord, client Testfall 08 / case …208): 501 today planned · 508 tomorrow planned
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select ok(not has_table_privilege('authenticated', 'public.visit_observations', 'insert'),
  'authenticated cannot insert observations directly');
select function_privs_are('public', 'record_observation', array['uuid','text','boolean','uuid','uuid'],
  'anon', array[]::text[], 'anon cannot record observations');
select function_privs_are('public', 'field_notes', array['date'], 'anon', array[]::text[],
  'anon cannot read field notes');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'vor dem Einsatz', false, null,
          'f4000000-0000-4000-8000-000000000001'),
  'rejected', 'no observation before the visit has begun');
select is(public.start_visit('00000000-0000-4000-a000-000000000501', 'f4000000-0000-4000-8000-000000000002'), 'ok', 'start 501');
select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'Klientin wach und orientiert, isst gut.', false, null,
          'f4000000-0000-4000-8000-000000000003'),
  'ok', 'nurse records an observation during the visit');
select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'Klientin wach und orientiert, isst gut.', false, null,
          'f4000000-0000-4000-8000-000000000003'),
  'duplicate', 'the same key again is a duplicate');
select throws_ok(
  $$ select public.record_observation('00000000-0000-4000-a000-000000000501', '   ', false, null, 'f4000000-0000-4000-8000-000000000004') $$,
  '22023', null, 'an empty observation is refused');
select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'Bitte Blutzucker morgen früh messen (Arztauftrag liegt bei).', true, null,
          'f4000000-0000-4000-8000-000000000005'),
  'ok', 'nurse marks an observation for handover');

select is(
  (select count(*)::int from public.visit_observations
   where visit_id = '00000000-0000-4000-a000-000000000501'
     and author_id = '00000000-0000-4000-a000-000000000902' and source = 'direct' and recorded_at = now()),
  2, 'provenance: author, source and server time are recorded');

-- Versions
select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'Klientin wach und orientiert, isst wenig.', false,
          (select id from public.visit_observations where content like '%isst gut.'),
          'f4000000-0000-4000-8000-000000000006'),
  'ok', 'a change is recorded as a new version');
select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'zweite Änderung am alten Stand', false,
          (select id from public.visit_observations where content like '%isst gut.'),
          'f4000000-0000-4000-8000-000000000007'),
  'rejected', 'an already superseded version cannot be superseded again');
select results_eq(
  $$ select content, edited from public.field_notes((now() at time zone 'Europe/Zurich')::date)
     where kind = 'observation' and visit_id = '00000000-0000-4000-a000-000000000501' order by recorded_at, content $$,
  $$ values ('Bitte Blutzucker morgen früh messen (Arztauftrag liegt bei).', false),
            ('Klientin wach und orientiert, isst wenig.', true) $$,
  'field_notes shows only current versions, with the edited flag');
select ok(
  (select bool_and(own) from public.field_notes((now() at time zone 'Europe/Zurich')::date)),
  'notes written by the caller are marked as own (no author ids are returned)');

-- Handover onto the next visit of the same client
select results_eq(
  $$ select content, source_date from public.field_notes((now() at time zone 'Europe/Zurich')::date + 1)
     where kind = 'handover' and visit_id = '00000000-0000-4000-a000-000000000508' $$,
  $$ values ('Bitte Blutzucker morgen früh messen (Arztauftrag liegt bei).', (now() at time zone 'Europe/Zurich')::date) $$,
  'the handover note appears on the client''s next visit of the team');
select is(
  (select count(*)::int from public.field_notes((now() at time zone 'Europe/Zurich')::date + 1) where kind = 'observation'),
  0, 'non-handover observations do not travel to other visits');

-- Direct writes
select throws_ok(
  $$ insert into public.visit_observations (organization_id, visit_id, team_id, author_id, content, idempotency_key)
     values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000501',
             '00000000-0000-4000-a000-000000000101', auth.uid(), 'direkt', gen_random_uuid()) $$,
  '42501', null, 'a direct insert is refused');
reset role;

select throws_ok($$ update public.visit_observations set content = 'geändert' $$, '42501', null,
  'observations are immutable, even for the database owner');

-- Visibility: team only
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.visit_observations), 0,
  'a coach of the same organisation who is not in the team cannot read the observations');
select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'Coach schreibt', false, null,
          'f4000000-0000-4000-8000-000000000020'),
  'rejected', 'a coach outside the team cannot record observations');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.visit_observations), 0, 'another organisation reads nothing');
select is(public.record_observation('00000000-0000-4000-a000-000000000501', 'fremd', false, null,
          'f4000000-0000-4000-8000-000000000030'),
  'rejected', 'another organisation cannot record observations');
reset role;

select * from finish();
rollback;
