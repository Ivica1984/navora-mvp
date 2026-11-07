-- J1: referral intake → case (+ facts) → matching request only when ready. Audited, consent gate,
-- insurer/order data protected. Brief: docs/agents/briefs/J1.md
-- Users: coach …901 · nurse …902 (Testteam Nord) · foreign admin …903 (org B) · operations …904 (org A)
begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select function_privs_are('public', 'convert_partner_request', array['uuid','text','text','boolean','jsonb','uuid'],
  'anon', array[]::text[], 'anon cannot convert requests');
select ok(not has_table_privilege('authenticated', 'public.cases', 'insert'), 'authenticated cannot insert cases directly');
select ok(not has_column_privilege('authenticated', 'public.cases', 'insurer_name', 'select'),
  'insurer is not readable through the table API');
select ok(not has_column_privilege('authenticated', 'public.cases', 'medical_order_status', 'select'),
  'medical order status is not readable through the table API');
select ok(has_column_privilege('authenticated', 'public.cases', 'residence_canton', 'select'),
  'residence canton stays readable (matching region context)');

-- Recording ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;

select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Testspital J1', 'Spital', 'Bern West',
          'Teststadt', 'hoch', 'ab morgen', 'Austritt J1', 'Synthetischer Bedarf J1', array['Grundpflege', ' Wundversorgung '],
          'a1000000-0000-4000-8000-000000000001', 'referrer_stated'),
  'ok', 'operations records a partner request');
select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Testspital J1', 'Spital', 'Bern West',
          'Teststadt', 'hoch', 'ab morgen', 'Austritt J1', 'Synthetischer Bedarf J1', array['Grundpflege'],
          'a1000000-0000-4000-8000-000000000001', 'referrer_stated'),
  'duplicate', 'the same key again is a duplicate');
select throws_ok(
  $$ select public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Testspital', null, 'Bern West',
       null, 'sehr hoch', null, 'Titel', 'Bedarf', null, 'a1000000-0000-4000-8000-000000000002', 'referrer_stated') $$,
  '22023', null, 'an urgency outside niedrig/mittel/hoch is refused');

-- Converting with incomplete facts -----------------------------------------------------------
select throws_ok(
  format($$ select public.convert_partner_request(%L, 'Test', 'Person J1', false, '{}'::jsonb, 'a1000000-0000-4000-8000-000000000010') $$,
         (select id from public.partner_requests where request_title = 'Austritt J1')),
  '22023', null, 'conversion without consent confirmation is refused');
select throws_ok(
  format($$ select public.convert_partner_request(%L, 'Test', 'Person J1', true, '{"residence_canton": "XX"}'::jsonb, 'a1000000-0000-4000-8000-000000000013') $$,
         (select id from public.partner_requests where request_title = 'Austritt J1')),
  '22023', null, 'an unknown canton code is refused');
select throws_ok(
  format($$ select public.convert_partner_request(%L, 'Test', 'Person J1', true, '{"blood_group": "A"}'::jsonb, 'a1000000-0000-4000-8000-000000000014') $$,
         (select id from public.partner_requests where request_title = 'Austritt J1')),
  '22023', null, 'fields outside the intake list are refused (data minimisation)');

create temp table r1 as
  select public.convert_partner_request((select id from public.partner_requests where request_title = 'Austritt J1'),
           'Test', 'Person J1', true,
           '{"residence_municipality": "Teststadt", "residence_canton": "BE", "insurance_type": "unknown"}'::jsonb,
           'a1000000-0000-4000-8000-000000000011') as res;

select is((select res ->> 'result' from r1), 'ok', 'operations converts the request');
select is((select (res ->> 'ready')::boolean from r1), false, 'the case is not ready yet');
select is(
  (select array_agg(e ->> 'item' order by e ->> 'item') from r1, jsonb_array_elements(res -> 'missing') e),
  array['insurance_type', 'insurer', 'requested_start'],
  'readiness names exactly the missing items (insurance type "unknown" counts as missing)');
select is(
  (select count(*)::int from public.matching_requests m join public.cases c on c.id = m.case_id where c.last_name = 'Person J1'),
  0, 'no matching request for a case that is not ready');
-- RLS2 (0066): Operations no longer reads `case_tasks` row by row; the task rows are checked as the table owner and
-- through the intake read model Operations uses (`case_funding_facts.open_tasks`, 067).
reset role;
select is(
  (select array_agg(kind order by kind) from public.case_tasks t join public.cases c on c.id = t.case_id where c.last_name = 'Person J1' and t.status = 'open'),
  array['access_unknown', 'gp_missing', 'language_unknown', 'other_providers_unknown'],
  'missing non-blocking items are open tasks on the case');
set local role authenticated;
select is(
  (select source_partner_request_id from public.cases where last_name = 'Person J1'),
  (select id from public.partner_requests where request_title = 'Austritt J1'), 'the case links to its referral');
select is(
  (select res ->> 'result' from (select public.convert_partner_request((select id from public.partner_requests where request_title = 'Austritt J1'),
     'Test', 'Person J1', true, '{}'::jsonb, 'a1000000-0000-4000-8000-000000000011') as res) x),
  'duplicate', 'converting again with the same key creates no second case');
select is((select count(*)::int from public.cases where last_name = 'Person J1'), 1, 'exactly one case per referral');

-- Completing the intake ------------------------------------------------------------------------
create temp table r2 as
  select public.update_case_intake((select id from public.cases where last_name = 'Person J1'),
           jsonb_build_object('insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 2,
                              'medical_order_status', 'requested', 'gp_named', true),
           'a1000000-0000-4000-8000-000000000020') as res;
select is((select (res ->> 'ready')::boolean from r2), true, 'with all blocking facts the case is ready');
select is(
  (select m.status || '/' || m.region from public.matching_requests m
   join public.cases c on c.id = m.case_id where c.last_name = 'Person J1'),
  'open/Bern West', 'the server opens the matching request once the case is ready');
select ok((select ready_for_matching_at is not null from public.cases where last_name = 'Person J1'), 'readiness time recorded');
reset role; -- RLS2 (0066): as the table owner (see above)
select is(
  (select count(*)::int from public.case_tasks t join public.cases c on c.id = t.case_id
   where c.last_name = 'Person J1' and t.kind = 'gp_missing' and t.status = 'done'),
  1, 'the GP task closes once a GP is named');
set local role authenticated;
select is(
  (select insurer_name || '/' || medical_order_status from public.case_funding_facts((select id from public.cases where last_name = 'Person J1'))),
  'Testkasse/requested', 'intake reads the funding facts through the protected function');
reset role;

select is(
  (select count(distinct table_name)::int from public.audit_events
   where command in ('convert_partner_request', 'update_case_intake') and actor_id = '00000000-0000-4000-a000-000000000904'),
  4, 'intake is audited on partner_requests, cases, case_tasks and matching_requests');
select ok(
  not exists (select 1 from public.audit_events where changed::text like '%Person J1%' or changed::text like '%Testkasse%'),
  'no names or insurer names enter the audit log');

-- Other roles ----------------------------------------------------------------------------
-- The case id is captured as the database owner: since F0 a nurse cannot even see the row.
create temp table j1case as select id from public.cases where last_name = 'Person J1';
grant select on j1case to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(
  (select count(*)::int from public.case_funding_facts((select id from j1case))),
  0, 'a nurse of a team not assigned to the case cannot read its insurer or order data');
select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital N', null, 'Bern West',
          null, 'mittel', null, 'Titel N', 'Bedarf N', null, 'a1000000-0000-4000-8000-000000000021', 'referrer_stated'),
  'rejected', 'a nurse cannot record partner requests');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.convert_partner_request('00000000-0000-4000-a000-000000000301', 'A', 'B', true, '{}'::jsonb,
          'a1000000-0000-4000-8000-000000000030') ->> 'result',
  'rejected', 'a coach cannot convert requests (coaches do not dispatch)');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.update_case_intake((select id from public.cases where last_name = 'Person J1'), '{}'::jsonb,
          'a1000000-0000-4000-8000-000000000041') ->> 'result',
  'rejected', 'an admin of another organisation cannot change org-A intake');
reset role;

select * from finish();
rollback;
