-- SAFE-D11 (brief `docs/agents/briefs/SAFE-D11.md`, ADR-184): after a reopen, a case without a team has exactly one of
-- two results: (A) an open, admissible team search (pgTAP 129, R1/R5/R6), or (B) a visible Operations exception that
-- names why no search is open (R2). Never neither. This file: R2, R3, R4 and the negative cases.
--
-- Written before the fix (red-first rule) and pushed without the migration to the probe branch (PR #1133, head
-- `7e82331` = `recovery/main` `7442889` + tests): `ci` 43246886503, `db` job 131281827420: «Failed 6-10, 18, 22, 26-27,
-- 34», exactly the R2, R3 and R4 assertions (no such exception type; no new search after reopen, Δ11). Migration 0125.
--
-- Users: operations …904, coach …901, nurse …902 (org A) · admin …905 (org A) · admin …903 (org B). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(37);

-- B1.1-1 (ADR-186): a signed-in user can only enter a listed region. The extra regions this file enters are put on
-- org A's list for this test only (rolled back). B1.1-1c (FE-073): the seed's legacy value is no longer
-- among them, the seed uses Basel-Stadt.
insert into public.regions (organization_id, name, sort_order) values
  ('00000000-0000-4000-b000-000000000011', 'Region ohne Team D11', 91),
  ('00000000-0000-4000-b000-000000000011', 'Region D11 Team', 92)
  on conflict (organization_id, name) do nothing;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Fixtures: four referrals converted by Operations with complete synthetic facts (J1) --------------------------------
--   D11N, D11M: Basel-Stadt (R2, a fact is missing at reopen) · D11R: a region without a team (R3) · D11T: R4 team case
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$
declare
  r record;
begin
  for r in select * from (values
      ('D11N', 'Basel-Stadt', 'd1300000-0000-4000-8000-000000000001'::uuid, 'd1300000-0000-4000-8000-000000000002'::uuid),
      ('D11M', 'Basel-Stadt', 'd1300000-0000-4000-8000-000000000003'::uuid, 'd1300000-0000-4000-8000-000000000004'::uuid),
      ('D11R', 'Region ohne Team D11', 'd1300000-0000-4000-8000-000000000005'::uuid, 'd1300000-0000-4000-8000-000000000006'::uuid),
      ('D11T', 'Region D11 Team', 'd1300000-0000-4000-8000-000000000007'::uuid, 'd1300000-0000-4000-8000-000000000008'::uuid)
    ) as v(last_name, region, k1, k2)
  loop
    perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital ' || r.last_name, 'Spital', r.region, null,
      'mittel', null, 'Anfrage ' || r.last_name, 'Bedarf ' || r.last_name, array['Grundpflege'], r.k1, 'referrer_stated');
    perform public.convert_partner_request((select id from public.partner_requests where request_title = 'Anfrage ' || r.last_name),
      'Klient', r.last_name, true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
        'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 1),
      r.k2);
  end loop;
end
$$;
reset role;

create temp table d11c as select c.last_name, c.id from public.cases c where c.last_name in ('D11N', 'D11M', 'D11R', 'D11T');
grant select on d11c to authenticated;
create function pg_temp.cid(p text) returns uuid language sql as $$ select id from d11c where last_name = p $$;
create function pg_temp.open_requests(p text) returns int language sql as $$
  select count(*)::int from public.matching_requests m where m.case_id = pg_temp.cid(p) and m.status = 'open';
$$;
create function pg_temp.ex(p_type text, p text) returns int language sql as $$
  select count(*)::int from public.operations_exceptions() x where x.exception_type = p_type and x.case_id = pg_temp.cid(p);
$$;

select is((select count(*)::int from d11c), 4, 'setup: four synthetic cases converted');
select is(pg_temp.open_requests('D11N') + pg_temp.open_requests('D11M') + pg_temp.open_requests('D11R'), 3,
  'setup: each of the three unassigned cases has one open team search');

-- R2: reopened while a fact is missing -> no search, a visible Operations exception ---------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.close_case(pg_temp.cid('D11N'), 'declined', null, 'd1300000-0000-4000-8000-000000000010'), 'ok',
  'R2: Operations closes D11N while it is still in the team search');
reset role;
-- Fixture: the insurer is no longer known when the client returns (a fact removed while the case was closed).
update public.cases set insurer_name = null where id = pg_temp.cid('D11N');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.reopen_case(pg_temp.cid('D11N'), 'Rückkehr nach Hause', 'd1300000-0000-4000-8000-000000000011'), 'ok',
  'R2: Operations reopens D11N');
reset role;
select is(pg_temp.open_requests('D11N'), 0, 'R2: no team search opens while a readiness item is missing');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ex('case_reopened_no_team', 'D11N'), 1,
  'R2: Operations sees exactly one exception «Wiedereröffneter Fall ohne Team» for the case');
select is((select x.priority || ' | ' || x.label || ' | ' || x.next_step from public.operations_exceptions() x
           where x.exception_type = 'case_reopened_no_team' and x.case_id = pg_temp.cid('D11N')),
  'P2 | Wiedereröffneter Fall ohne Team | Fehlende Angaben ergänzen; die Teamsuche öffnet sich dann selbst. Nie automatisch zuweisen.',
  'R2: priority P2, label and next step as in the brief');
select ok((select x.region = 'Basel-Stadt' and x.case_label like '%D11N%'
           from public.operations_exceptions() x where x.exception_type = 'case_reopened_no_team' and x.case_id = pg_temp.cid('D11N')),
  'R2: the exception names case and region');
-- UXR-181: the detail is the stored reason of each missing readiness item (private.case_readiness), never the item code.
select is((select x.detail from public.operations_exceptions() x
           where x.exception_type = 'case_reopened_no_team' and x.case_id = pg_temp.cid('D11N')),
  'Krankenversicherer fehlt', 'R2 / UXR-181: the detail is the stored reason text of the missing item, not «insurer»');
select is((select x.closable from public.operations_exceptions() x
           where x.exception_type = 'case_reopened_no_team' and x.case_id = pg_temp.cid('D11N')), false,
  'R2: it is not closed by hand, it closes with its cause');
select is(public.handle_exception((select x.exception_key from public.operations_exceptions() x
           where x.exception_type = 'case_reopened_no_team' and x.case_id = pg_temp.cid('D11N')), 'close', 'Erledigt',
          'd1300000-0000-4000-8000-000000000012'), 'cause_persists', 'R2: closing it by hand is refused');
reset role;

-- Negative: who does not see it ----------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() x where x.case_id in (select id from d11c)), 0,
  'negative: a team nurse of the region sees no Operations exception for the case');
select is((select count(*)::int from public.team_visit_alerts() x where x.case_id in (select id from d11c)), 0,
  'negative: and no team alert for it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() x where x.case_id in (select id from d11c)), 0,
  'negative: the administrator of another organisation sees none');
reset role;
select is(has_function_privilege('anon', 'public.operations_exceptions()', 'execute'), false,
  'negative: anon cannot read Operations exceptions');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select isnt(public.handle_exception((select x.exception_key from public.operations_exceptions() x
           where x.exception_type = 'case_reopened_no_team' and x.case_id = pg_temp.cid('D11N')), 'close', 'Erledigt',
          'd1300000-0000-4000-8000-000000000013'), 'ok', 'negative: the coach gets no right to close it either');
reset role;

-- R2 closes automatically when the search opens; R5 no team is assigned -----------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.update_case_intake(pg_temp.cid('D11N'), jsonb_build_object('insurer_name', 'Testkasse'),
          'd1300000-0000-4000-8000-000000000014', 'Versicherer bei Rückkehr bestätigt') ->> 'result', 'ok',
  'R2: Operations completes the missing fact');
select is(pg_temp.ex('case_reopened_no_team', 'D11N'), 0, 'R2: and the exception is gone');
reset role;
select is(pg_temp.open_requests('D11N'), 1, 'R2: the team search then opens by itself');
select is((select assigned_team_id from public.cases where id = pg_temp.cid('D11N')), null,
  'R5: no path assigns a team; the case waits for a team decision');

-- R2 closes automatically when the case is closed again ----------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.close_case(pg_temp.cid('D11M'), 'declined', null, 'd1300000-0000-4000-8000-000000000020'), 'ok', 'R2: D11M closed');
reset role;
update public.cases set requested_start = null, insurer_name = null where id = pg_temp.cid('D11M');   -- fixture: start and insurer no longer known
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.reopen_case(pg_temp.cid('D11M'), 'Rückkehr', 'd1300000-0000-4000-8000-000000000021'), 'ok', 'R2: D11M reopened');
select is(pg_temp.ex('case_reopened_no_team', 'D11M'), 1, 'R2: D11M shows the exception');
select is((select x.detail from public.operations_exceptions() x
           where x.exception_type = 'case_reopened_no_team' and x.case_id = pg_temp.cid('D11M')),
  'Krankenversicherer fehlt; Gewünschter Beginn fehlt',
  'UXR-181: two missing items give their stored reasons in readiness order, joined by «; »');
select is((select x.detail from public.operations_exceptions() x
           where x.exception_type = 'case_not_ready' and x.case_id = pg_temp.cid('D11M')), null,
  'UXR-181: a reopened case that had been ready is not also case_not_ready (one fact, one exception)');
select is(public.close_case(pg_temp.cid('D11M'), 'other', 'Doch nicht', 'd1300000-0000-4000-8000-000000000022'), 'ok', 'R2: D11M closed again');
select is(pg_temp.ex('case_reopened_no_team', 'D11M'), 0, 'R2: closing the case again ends the exception');
reset role;

-- R3: the normal exceptions still apply to the new search --------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.close_case(pg_temp.cid('D11R'), 'declined', null, 'd1300000-0000-4000-8000-000000000030')
          || '/' || public.reopen_case(pg_temp.cid('D11R'), 'Rückkehr', 'd1300000-0000-4000-8000-000000000031'), 'ok/ok',
  'R3: D11R (region without a team) closed and reopened');
reset role;
select is(pg_temp.open_requests('D11R'), 1, 'R3: a new team search is open');
create temp table d11r_open as
  select m.id from public.matching_requests m where m.case_id = pg_temp.cid('D11R') and m.status = 'open';
grant select on d11r_open to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() x
           where x.exception_type = 'candidates_exhausted' and x.entity_id in (select id from d11r_open)), 1,
  'R3: the new search without an eligible team shows candidates_exhausted, as a first search does');
select is(pg_temp.ex('case_reopened_no_team', 'D11R'), 0, 'R3: and no reopen exception, because a search is open');
reset role;

-- R4: a case with its team keeps it; a team that is no longer active is an exception ---------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.create_team('00000000-0000-4000-b000-000000000011', 'Testteam D11', 'Region D11 Team',
          'd1300000-0000-4000-8000-000000000040'), 'ok', 'R4: the administrator creates a team');
reset role;
-- Fixture: the team took D11T (decision path not under test here; its request is decided).
update public.matching_requests set status = 'accepted', selected_team_id = (select id from public.teams where name = 'Testteam D11')
  where case_id = pg_temp.cid('D11T') and status = 'open';
update public.cases set assigned_team_id = (select id from public.teams where name = 'Testteam D11'), status = 'laufend'
  where id = pg_temp.cid('D11T');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.close_case(pg_temp.cid('D11T'), 'goal_reached', null, 'd1300000-0000-4000-8000-000000000041'), 'ok', 'R4: D11T closed');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.deactivate_team((select id from public.teams where name = 'Testteam D11'), 'Pilot beendet',
          'd1300000-0000-4000-8000-000000000042'), 'ok',
  'R4: a team whose only case is closed can be deactivated (0035): so a team can be inactive when its case is reopened');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.reopen_case(pg_temp.cid('D11T'), 'Rückkehr', 'd1300000-0000-4000-8000-000000000043'), 'ok', 'R4: D11T reopened');
reset role;
select is(pg_temp.open_requests('D11T'), 0, 'R4: a case with its team gets no new team search');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ex('case_reopened_team_inactive', 'D11T'), 1,
  'R4: the reopened case of a team that is no longer active is an Operations exception');
reset role;

select * from finish();
rollback;
