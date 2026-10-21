-- J1: referral intake → case + open matching request (admin/operations only), audited, consent gate.
-- Users: coach …901 · nurse …902 · foreign admin …903 (org B) · operations …904 (org A)
begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select function_privs_are('public', 'convert_partner_request', array['uuid','text','text','boolean','uuid'],
  'anon', array[]::text[], 'anon cannot convert requests');
select ok(not has_table_privilege('authenticated', 'public.cases', 'insert'), 'authenticated cannot insert cases directly');

-- Recording ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;

select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Testspital J1', 'Spital', 'Bern West',
          'Teststadt', 'hoch', 'ab morgen', 'Austritt J1', 'Synthetischer Bedarf J1', array['Grundpflege', ' Wundversorgung '],
          'a1000000-0000-4000-8000-000000000001'),
  'ok', 'operations records a partner request');
select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Testspital J1', 'Spital', 'Bern West',
          'Teststadt', 'hoch', 'ab morgen', 'Austritt J1', 'Synthetischer Bedarf J1', array['Grundpflege'],
          'a1000000-0000-4000-8000-000000000001'),
  'duplicate', 'the same key again is a duplicate');
select throws_ok(
  $$ select public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Testspital', null, 'Bern West',
       null, 'sehr hoch', null, 'Titel', 'Bedarf', null, 'a1000000-0000-4000-8000-000000000002') $$,
  '22023', null, 'an urgency outside niedrig/mittel/hoch is refused');
select is(
  (select requested_services from public.partner_requests where request_title = 'Austritt J1'),
  array['Grundpflege', 'Wundversorgung'], 'services are trimmed');

-- Converting -----------------------------------------------------------------------------
select throws_ok(
  format($$ select public.convert_partner_request(%L, 'Test', 'Person J1', false, 'a1000000-0000-4000-8000-000000000010') $$,
         (select id from public.partner_requests where request_title = 'Austritt J1')),
  '22023', null, 'conversion without consent confirmation is refused');
select is(
  public.convert_partner_request((select id from public.partner_requests where request_title = 'Austritt J1'),
                                 'Test', 'Person J1', true, 'a1000000-0000-4000-8000-000000000011'),
  'ok', 'operations converts the request after review');

select is(
  (select status || '/' || urgency || '/' || region from public.cases where last_name = 'Person J1'),
  'neu/hoch/Bern West', 'the case starts as neu, with urgency and region from the request');
select is(
  (select assigned_team_id from public.cases where last_name = 'Person J1'), null,
  'no team is assigned at intake (teams decide, J2)');
select is(
  (select intake_consent_confirmed_by from public.cases where last_name = 'Person J1'),
  '00000000-0000-4000-a000-000000000904'::uuid, 'who confirmed consent is recorded');
select is(
  (select m.status || '/' || m.region from public.matching_requests m
   join public.cases c on c.id = m.case_id where c.last_name = 'Person J1'),
  'open/Bern West', 'an open matching request for the case''s region exists');
select is(
  (select status from public.partner_requests where request_title = 'Austritt J1'), 'converted',
  'the partner request is marked converted');
select is(
  public.convert_partner_request((select id from public.partner_requests where request_title = 'Austritt J1'),
                                 'Test', 'Person J1', true, 'a1000000-0000-4000-8000-000000000012'),
  'rejected', 'a converted request cannot be converted twice');
reset role;

select is(
  (select count(distinct table_name)::int from public.audit_events
   where command = 'convert_partner_request' and actor_id = '00000000-0000-4000-a000-000000000904'),
  3, 'conversion is audited on partner_requests, cases and matching_requests');
select ok(
  not exists (select 1 from public.audit_events where changed::text like '%Person J1%' or changed::text like '%Bedarf J1%'),
  'no names or need text enter the audit log');

-- Other roles ----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital N', null, 'Bern West',
          null, 'mittel', null, 'Titel N', 'Bedarf N', null, 'a1000000-0000-4000-8000-000000000020'),
  'rejected', 'a nurse cannot record partner requests');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.convert_partner_request('00000000-0000-4000-a000-000000000301', 'A', 'B', true,
          'a1000000-0000-4000-8000-000000000030'),
  'rejected', 'a coach cannot convert requests (coaches do not dispatch)');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Fremd', null, 'Bern West',
          null, 'mittel', null, 'Titel F', 'Bedarf F', null, 'a1000000-0000-4000-8000-000000000040'),
  'rejected', 'an admin of another organisation cannot record into org A');
select is(public.convert_partner_request('00000000-0000-4000-a000-000000000301', 'A', 'B', true,
          'a1000000-0000-4000-8000-000000000041'),
  'rejected', 'an admin of another organisation cannot convert org-A requests');
reset role;

select * from finish();
rollback;
