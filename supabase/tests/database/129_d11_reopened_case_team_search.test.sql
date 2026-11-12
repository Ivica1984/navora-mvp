-- Δ11 (spec B1, `docs/product/specs/B1.md`; FE-070 Lieferung 1 §3 item 0): a case closed BEFORE any team accepted it
-- and then reopened must be in a team search again. ADR-184 (PROPOSED).
--
-- REPRODUCTION, EXPECTED RED on `recovery/main` today (prepared on a branch, not merged; PO 2026-11-12 14:39):
-- `close_case` (0031) withdraws the open matching request; `reopen_case` (0024) sets the case `active` and keeps
-- `ready_for_matching_at`; `private.open_matching_if_ready` (0034) only inserts when NO matching request exists for
-- the case, whatever its status, and nothing calls it on reopen. So the reopened case has no open team search, no
-- team is offered it, and no exception names it. Assertions marked [RED today] fail until the fix; the others
-- hold today and guard the fix (history kept, a case that has its team gets no new search, idempotency).
--
-- Users: nurse …902 (Testteam Nord …101, Bern West) · operations …904 (org A). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

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
  '[RED today] the reopened case is in exactly one open team search again (Δ11)');
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
  '[RED today] a team in the case''s region is offered the reopened case again');
reset role;

-- Idempotency: the same reopen key again changes nothing --------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.reopen_case((select case_id from d11), 'Rückkehr nach Hause', 'd1100000-0000-4000-8000-000000000011'), 'duplicate',
  'the same reopen key again is a duplicate');
reset role;
select is(pg_temp.open_requests(), 1, '[RED today] and still exactly one open team search, not two');

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
select is(pg_temp.open_requests(), 1, '[RED today] after a second close and reopen: exactly one open team search');
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
