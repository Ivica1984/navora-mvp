-- Δ11 (spec B1, `docs/product/specs/B1.md`) / SAFE-D11 R1, R5, R6 (brief `docs/agents/briefs/SAFE-D11.md`): a case closed
-- BEFORE any team accepted it and then reopened is in a team search again. ADR-184; fix in migration 0125.
--
-- Written red first: on `recovery/main` `4a543c0` assertions 5, 8, 10 and 11 failed (probe PR #1133, `ci` 43237144854,
-- `db` job: «Failed 5, 8, 10-11»): `close_case` (0031) withdrew the search, `reopen_case` (0024) opened none and
-- `private.open_matching_if_ready` (0034) inserted only when no request of any status existed. With 0125 they hold.
-- The other assertions guard the fix (history kept as a new row, reopen audited, duplicate key, a case that has its
-- team gets no new search). R2, R3, R4 and the negative cases: pgTAP 130.
--
-- Users: nurse …902 (Testteam Nord …101, Bern West) · operations …904 (org A). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

-- B1.1-1 (ADR-186): a signed-in user can only enter a listed region. The regions this file enters are put on org A's
-- list for this test only (rolled back); the seed and its legacy values stay as they are (FE-066).
insert into public.regions (organization_id, name, sort_order) values
  ('00000000-0000-4000-b000-000000000011', 'Bern West', 90)
  on conflict (organization_id, name) do nothing;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- A referral in Bern West, converted by Operations with complete facts (J1), so the case is ready and searched (J2).
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$
begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital D11', 'Spital', 'Bern West', null,
    'mittel', null, 'D11 Anfrage', 'Bedarf D11', array['Grundpflege'], 'd1100000-0000-4000-8000-000000000001', 'referrer_stated');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'D11 Anfrage'),
    'Klient', 'D11A', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 1),
    'd1100000-0000-4000-8000-000000000002');
end
$$;
reset role;

create temp table d11 as
  select c.id as case_id, (select m.id from public.matching_requests m where m.case_id = c.id) as first_request_id
  from public.cases c where c.last_name = 'D11A';
grant select on d11 to authenticated;

create function pg_temp.open_requests() returns int language sql as $$
  select count(*)::int from public.matching_requests m join d11 on d11.case_id = m.case_id where m.status = 'open';
$$;

select is(pg_temp.open_requests(), 1, 'setup: the converted case is ready and has exactly one open team search');

-- Closed before any team accepted -------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.close_case((select case_id from d11), 'declined', null, 'd1100000-0000-4000-8000-000000000010'), 'ok',
  'Operations closes the case while it is still in the team search');
reset role;
select is((select status from public.matching_requests where id = (select first_request_id from d11)), 'withdrawn',
  'the open team search is withdrawn on close (0031, IMPLEMENTED)');

-- Reopened --------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.reopen_case((select case_id from d11), 'Rückkehr nach Hause', 'd1100000-0000-4000-8000-000000000011'), 'ok',
  'Operations reopens the case');
reset role;

select is(pg_temp.open_requests(), 1,
  'the reopened case is in exactly one open team search again (Δ11)');
select is((select status from public.matching_requests where id = (select first_request_id from d11)), 'withdrawn',
  'the withdrawn search stays withdrawn: history is kept, a new search is a new row (ADR-184 1)');
select ok(exists (select 1 from public.audit_events where command = 'reopen_case'
                  and idempotency_key = 'd1100000-0000-4000-8000-000000000011'), 'the reopen is audited');

create temp table d11_open as
  select m.id from public.matching_requests m join d11 on d11.case_id = m.case_id where m.status = 'open';
grant select on d11_open to authenticated;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.team_offers() o join d11_open on d11_open.id = o.matching_request_id
           where o.team_id = '00000000-0000-4000-a000-000000000101'), 1,
  'a team in the case''s region is offered the reopened case again');
reset role;

-- Idempotency: the same reopen key again changes nothing --------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.reopen_case((select case_id from d11), 'Rückkehr nach Hause', 'd1100000-0000-4000-8000-000000000011'), 'duplicate',
  'the same reopen key again is a duplicate');
reset role;
select is(pg_temp.open_requests(), 1, 'and still exactly one open team search, not two');

-- A second close and reopen cycle ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$
begin
  perform public.close_case((select case_id from d11), 'other', 'Zweiter Abschluss', 'd1100000-0000-4000-8000-000000000020');
  perform public.reopen_case((select case_id from d11), 'Zweite Rückkehr', 'd1100000-0000-4000-8000-000000000021');
end
$$;
reset role;
select is(pg_temp.open_requests(), 1, 'after a second close and reopen: exactly one open team search');
select is((select count(*)::int from public.matching_requests m join d11 on d11.case_id = m.case_id where m.status = 'open'
             and m.id = (select first_request_id from d11)), 0,
  'the first search is never reopened in place');

-- A case that has its team gets no new team search on reopen (guards the fix) -----------------------------------------
-- Case …208 belongs to Testteam Nord …101 (seed).
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(
  (select public.close_case('00000000-0000-4000-a000-000000000208', 'goal_reached', null, 'd1100000-0000-4000-8000-000000000030')
       || '/' || public.reopen_case('00000000-0000-4000-a000-000000000208', 'Rückkehr', 'd1100000-0000-4000-8000-000000000031')),
  'ok/ok', 'Operations closes and reopens a case that has its team');
reset role;
select is((select count(*)::int from public.matching_requests
           where case_id = '00000000-0000-4000-a000-000000000208' and status = 'open'), 0,
  'a reopened case with its team gets no new team search');

select * from finish();
rollback;
