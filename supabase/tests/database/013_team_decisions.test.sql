-- J2: team decision (team pull) on open matching requests.
-- Users: coach …901 · nurse …902 (Testteam Nord, Bern West) · foreign admin …903 · operations …904
-- Bern West, org A: Testteam Nord …101 (active), Testteam Mitte …102 (active, no members in the seed)
begin;
create extension if not exists pgtap with schema extensions;

select plan(21);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select function_privs_are('public', 'decide_matching_request', array['uuid','uuid','text','text','uuid','text'],
  'anon', array[]::text[], 'anon cannot decide');
select function_privs_are('public', 'team_offers', array[]::text[], 'anon', array[]::text[], 'anon cannot read offers');
select is(
  (select array_agg(a) from unnest((select proargnames from pg_proc where oid = 'public.team_offers()'::regprocedure)) a
   where a in ('first_name', 'last_name', 'client_name', 'name', 'address', 'phone')),
  null, 'offers carry no client identity (data minimisation before acceptance)');

-- Two referrals in Bern West, converted by operations (J1)
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$
begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital J2', 'Spital', 'Bern West', null,
    'hoch', null, 'J2 Anfrage A', 'Bedarf A', array['Grundpflege'], 'a2000000-0000-4000-8000-000000000001', 'referrer_stated');
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital J2', 'Spital', 'Bern West', null,
    'mittel', null, 'J2 Anfrage B', 'Bedarf B', array['Begleitung'], 'a2000000-0000-4000-8000-000000000002', 'referrer_stated');
  -- J1 (PO brief): complete facts so the cases are ready and the matching requests exist.
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'J2 Anfrage A'),
    'Klient', 'J2A', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 1),
    'a2000000-0000-4000-8000-000000000003');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'J2 Anfrage B'),
    'Klient', 'J2B', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 1),
    'a2000000-0000-4000-8000-000000000004');
end
$$;
reset role;

create temp table req as
  select m.id, c.last_name from public.matching_requests m join public.cases c on c.id = m.case_id
  where c.last_name in ('J2A', 'J2B');
grant select on req to authenticated;

-- Nurse (Testteam Nord)
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is(
  (select count(*)::int from public.team_offers() o join req r on r.id = o.matching_request_id
   where o.team_id = '00000000-0000-4000-a000-000000000101'),
  2, 'both Bern West requests are offered to the nurse''s active team');
select is(
  (select team_name from public.team_offers() where matching_request_id = (select id from req where last_name = 'J2A')),
  'Testteam Nord', 'the offer names the team it is for');
select is(
  (select count(*)::int from public.team_offers() where matching_request_id = '00000000-0000-4000-a000-000000000401'),
  0, 'a request of another region (Zürich Pilot) is not offered');

select is(public.decide_matching_request((select id from req where last_name = 'J2A'),
          '00000000-0000-4000-a000-000000000102', 'accept', null, 'a2000000-0000-4000-8000-000000000010'),
  'rejected', 'a nurse cannot decide for a team she is not in');
select is(public.decide_matching_request((select id from req where last_name = 'J2B'),
          '00000000-0000-4000-a000-000000000101', 'decline', 'Keine Kapazität diese Woche', 'a2000000-0000-4000-8000-000000000011', 'capacity'),
  'ok', 'the team declines request B with a reason');
select is(
  (select my_team_declined from public.team_offers() where matching_request_id = (select id from req where last_name = 'J2B')),
  true, 'the declined offer stays visible as declined');
select is(public.decide_matching_request((select id from req where last_name = 'J2B'),
          '00000000-0000-4000-a000-000000000101', 'accept', null, 'a2000000-0000-4000-8000-000000000012'),
  'rejected', 'a team cannot silently flip its decision');

select is(public.decide_matching_request((select id from req where last_name = 'J2A'),
          '00000000-0000-4000-a000-000000000101', 'accept', null, 'a2000000-0000-4000-8000-000000000013'),
  'ok', 'the team accepts request A');
select is(public.decide_matching_request((select id from req where last_name = 'J2A'),
          '00000000-0000-4000-a000-000000000101', 'accept', null, 'a2000000-0000-4000-8000-000000000013'),
  'duplicate', 'the same key again is a duplicate');
reset role;

select is(
  (select assigned_team_id::text || '/' || status from public.cases where last_name = 'J2A'),
  '00000000-0000-4000-a000-000000000101/laufend', 'the case is assigned to the accepting team');
select is(
  (select status from public.matching_requests where id = (select id from req where last_name = 'J2A')),
  'accepted', 'the request is closed as accepted');
select ok(
  exists (select 1 from public.audit_events where command = 'decide_matching_request' and table_name = 'cases'),
  'the assignment is audited with the command');

-- Another team tries the taken request
-- J2 changes: a new case requires a registered nurse (needs assessment), so the coach joins as one.
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'registered_nurse');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(
  (select count(*)::int from public.team_offers() where matching_request_id = (select id from req where last_name = 'J2A')),
  0, 'an accepted request is no longer offered to other teams');
select is(public.decide_matching_request((select id from req where last_name = 'J2A'),
          '00000000-0000-4000-a000-000000000102', 'accept', null, 'a2000000-0000-4000-8000-000000000020'),
  'taken', 'a later acceptance by another team is refused as taken');
select is(public.decide_matching_request((select id from req where last_name = 'J2B'),
          '00000000-0000-4000-a000-000000000102', 'accept', null, 'a2000000-0000-4000-8000-000000000021'),
  'ok', 'a decline by one team does not block another team');
select throws_ok(
  $$ insert into public.team_decisions (organization_id, matching_request_id, team_id, decision, actor_id, idempotency_key)
     values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000401',
             '00000000-0000-4000-a000-000000000102', 'accept', auth.uid(), gen_random_uuid()) $$,
  '42501', null, 'a direct insert is refused');
reset role;

select throws_ok($$ update public.team_decisions set decision = 'accept' $$, '42501', null, 'decisions are append-only');

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.decide_matching_request('00000000-0000-4000-a000-000000000401',
          '00000000-0000-4000-a000-000000000151', 'accept', null, 'a2000000-0000-4000-8000-000000000030'),
  'rejected', 'another organisation cannot decide on org-A requests');
reset role;

select * from finish();
rollback;
