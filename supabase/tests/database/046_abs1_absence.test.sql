-- ABS1, first PR (migration 0046, ADR-057): absence without the phone chain, "Offen im Team", one-tap take,
-- withdraw and shorten, PLAN2 respects the absence, CGR-11 (qualification change releases), CGR-15 (an untaken
-- released visit stays alerted), CGR-18 (absence never refused; visits in progress and draft reports stay hers),
-- CGR-22 (every uncovered visit can be taken; visit_uncovered ends with its cause), HAND1 shows the release as fact.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · coach …901 joins
-- Testteam Mitte …102 here (another team, same organisation) · ops …904 · admin …905 · admin …903 (organisation B).
-- Case …208 (Nord): primary nurse …906, deputy …902 (set here). All data synthetic. Fixtures are written as the
-- table owner; every step under test goes through the real commands as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(93);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;

-- Privileges --------------------------------------------------------------------------------------------------------
select ok(has_function_privilege('authenticated', 'public.record_absence(uuid, uuid, date, date, time, time, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.record_absence(uuid, uuid, date, date, time, time, uuid)', 'execute'),
  'record_absence: members yes, anon no');
select ok(has_function_privilege('authenticated', 'public.take_open_visit(uuid, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.change_absence(uuid, boolean, date, time, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.team_open_visits(date)', 'execute')
          and has_function_privilege('authenticated', 'public.team_absences()', 'execute'),
  'take, change, open list and absences are callable by members');
select ok(not has_function_privilege('authenticated', 'private.release_visits_between(uuid, uuid, timestamptz, timestamptz, text, uuid, boolean)', 'execute')
          and not has_function_privilege('authenticated', 'private.member_absent_during(uuid, uuid, timestamptz, timestamptz)', 'execute'),
  'the release rule and the absence helper are internal');
select ok(not has_table_privilege('authenticated', 'public.member_absences', 'insert')
          and not has_table_privilege('authenticated', 'public.member_absences', 'update')
          and not has_table_privilege('authenticated', 'public.absence_releases', 'select'),
  'absences change only through the commands; the release links are not readable');
select ok(pg_get_function_arguments('public.record_absence(uuid, uuid, date, date, time, time, uuid)'::regprocedure) !~ '(reason|note|text)',
  'no reason or free text can be passed with an absence');
select ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'member_absences'
                      and (column_name ~ '(reason|note|comment)' or data_type = 'text')),
  'and the absence table has no text column at all');

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name, updated_by) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'Test Pflege RN', '00000000-0000-4000-a000-000000000905'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000906', 'Test Pflege FaGe', '00000000-0000-4000-a000-000000000905')
on conflict (organization_id, user_id) do update set display_name = excluded.display_name;
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-000000000906', deputy_nurse_id = '00000000-0000-4000-a000-000000000902',
                        medical_order_status = 'present'
  where id = '00000000-0000-4000-a000-000000000208';

create temp table fx (name text primary key, id uuid not null, at timestamptz not null, resp uuid, b int, st text);
grant select on fx to authenticated;
insert into fx values
  -- 906's visits (care assistant, category A)
  ('t1',      'a0460000-0000-4000-8000-000000000001', (pg_temp.today() + 1 + time '09:00') at time zone 'Europe/Zurich', '00000000-0000-4000-a000-000000000906', 0, 'planned'),
  ('t2',      'a0460000-0000-4000-8000-000000000002', (pg_temp.today() + 1 + time '15:00') at time zone 'Europe/Zurich', '00000000-0000-4000-a000-000000000906', 0, 'planned'),
  ('t3',      'a0460000-0000-4000-8000-000000000003', (pg_temp.today() + 3 + time '09:00') at time zone 'Europe/Zurich', '00000000-0000-4000-a000-000000000906', 0, 'planned'),
  -- open visits nobody is responsible for
  ('open_b',  'a0460000-0000-4000-8000-000000000004', (pg_temp.today() + 1 + time '18:00') at time zone 'Europe/Zurich', null, 20, 'planned'),
  -- 'hand' and 'later' stay today whatever the time of day (least: before 23:00 Zurich); 'overdue' stays today too.
  ('hand',    'a0460000-0000-4000-8000-000000000005', least(now() + interval '3 hours', (pg_temp.today() + time '23:00') at time zone 'Europe/Zurich'), null, 0, 'planned'),
  -- 902's visits (registered nurse) for her absence today
  ('paused',  'a0460000-0000-4000-8000-000000000006', now() - interval '3 hours', '00000000-0000-4000-a000-000000000902', 0, 'paused'),
  ('overdue', 'a0460000-0000-4000-8000-000000000007', greatest(now() - interval '20 minutes', (pg_temp.today() + time '00:00') at time zone 'Europe/Zurich'), '00000000-0000-4000-a000-000000000902', 0, 'planned'),
  ('later',   'a0460000-0000-4000-8000-000000000008', least(now() + interval '4 hours', (pg_temp.today() + time '23:00') at time zone 'Europe/Zurich'), '00000000-0000-4000-a000-000000000902', 0, 'planned'),
  ('done',    'a0460000-0000-4000-8000-000000000009', now() - interval '6 hours', '00000000-0000-4000-a000-000000000902', 0, 'completed'),
  -- 902's visits for the qualification change (CGR-11)
  ('rn_b',    'a0460000-0000-4000-8000-000000000010', (pg_temp.today() + 5 + time '10:00') at time zone 'Europe/Zurich', '00000000-0000-4000-a000-000000000902', 20, 'planned'),
  ('rn_a',    'a0460000-0000-4000-8000-000000000011', (pg_temp.today() + 5 + time '12:00') at time zone 'Europe/Zurich', '00000000-0000-4000-a000-000000000902', 0, 'planned');

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (f.at at time zone 'Europe/Zurich')::date, (f.at at time zone 'Europe/Zurich')::time,
       ((f.at + interval '30 minutes') at time zone 'Europe/Zurich')::time, array['Grundpflege'], false, f.st,
       case when f.b > 0 then 10 else 30 end, f.b, f.resp
from fx f;
-- 902 performed the completed visit and has only a draft report (CGR-18); she started the paused one.
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000101', 'started', 'planned', 'started',
       '00000000-0000-4000-a000-000000000902', f.at from fx f where f.name in ('paused', 'done');
insert into public.visit_reports (organization_id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       1, 'draft', '{}'::jsonb, '00000000-0000-4000-a000-000000000902', false, '00000000-0000-4000-a000-000000000902'
from fx f where f.name = 'done';

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.resp(n text) returns uuid language sql as $$ select responsible_user_id from public.care_visits where id = pg_temp.vid(n) $$;
create function pg_temp.open_ids(p date) returns uuid[] language sql as $$
  select coalesce(array_agg(o.visit_id), '{}') from public.team_open_visits(p) o where o.visit_id in (select id from fx) $$;
create function pg_temp.ops(n text, t text) returns integer language sql as $$
  select count(*)::int from public.operations_exceptions() x where x.exception_type = t and x.entity_id = pg_temp.vid(n) $$;

-- 1. 906 records her own absence for tomorrow ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 1, null, null, null,
          'a4600000-0000-4000-8000-000000000001') ->> 'result', 'ok', 'a member records her own absence for tomorrow (two taps: no reason, no approval)');
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 1, null, null, null,
          'a4600000-0000-4000-8000-000000000001') ->> 'result', 'duplicate', 'the same key is idempotent');
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 1, null, '12:00', null,
          'a4600000-0000-4000-8000-000000000002') ->> 'result', 'overlaps', 'an overlapping second absence is refused');
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() - 2, pg_temp.today() - 1, null, null,
          'a4600000-0000-4000-8000-000000000003') ->> 'result', 'in_past', 'an absence entirely in the past is refused');
select throws_ok($$ select public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 2, pg_temp.today() + 1,
          null, null, 'a4600000-0000-4000-8000-000000000004') $$, '22023', null, 'an absence must end after it starts');
reset role;

select is(pg_temp.resp('t1'), null, 'her visit tomorrow morning is released');
select is(pg_temp.resp('t2'), null, 'and her visit tomorrow afternoon');
select is(pg_temp.resp('t3'), '00000000-0000-4000-a000-000000000906'::uuid, 'a visit after the absence stays hers');
select is((select count(*)::int from public.visit_plan_changes where visit_id in (pg_temp.vid('t1'), pg_temp.vid('t2'))
           and change = 'released' and reason = 'Abwesenheit'), 2, 'each release is in the J3 change log with the fixed text "Abwesenheit"');
select is((select count(*)::int from public.audit_events where command = 'record_absence' and table_name = 'member_absences'), 1,
  'the absence is audited once');
select is((select count(*)::int from public.audit_events where command = 'record_absence' and table_name = 'care_visits'), 2,
  'the releases are audited under the same command');

-- 2. The team sees the absence and the open visits -----------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select member from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000101'), 'Test Pflege FaGe',
  'her team sees who is absent');
select is((select may_change from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000101'), false,
  'a colleague who did not record it cannot change it');
select ok(pg_temp.vid('t1') = any (pg_temp.open_ids(pg_temp.today() + 1)) and pg_temp.vid('t2') = any (pg_temp.open_ids(pg_temp.today() + 1)),
  '"Offen im Team" lists the released visits');
select ok(pg_temp.vid('hand') = any (pg_temp.open_ids(pg_temp.today())) and pg_temp.vid('open_b') = any (pg_temp.open_ids(pg_temp.today())),
  'and every other uncovered visit of the team (hand-planned without anyone, a B visit)');
select is((select known_by from public.team_open_visits(pg_temp.today()) where visit_id = pg_temp.vid('t1')), 'me',
  'the deputy is marked "kennt die Klientin" (the absent primary nurse is skipped)');
select is((select known_by_me from public.team_open_visits(pg_temp.today()) where visit_id = pg_temp.vid('t1')), true,
  'known_by_me is set for her');
select is((select may_take from public.team_open_visits(pg_temp.today()) where visit_id = pg_temp.vid('open_b')), true,
  'a registered nurse may take a B visit');
-- created in this transaction only (the seed holds no absence since ABS1-C6; the filter stays as a guard)
select is((select count(*)::int from public.member_absences where created_at >= now()), 1, 'a team member reads the absence row of her team');
select ok((select array_agg(visit_id order by visit_date, time_start) = array[pg_temp.vid('t1'), pg_temp.vid('t2'), pg_temp.vid('open_b')]
           from public.team_open_visits(pg_temp.today() + 1) where visit_id in (select id from fx)),
  'in time order');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is((select is_me from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000101'), true,
  'the absent member sees her absence on her own /field');
select is((select may_take from public.team_open_visits(pg_temp.today()) where visit_id = pg_temp.vid('t1')), false,
  'she is not offered a visit during her absence');
select is(public.take_open_visit(pg_temp.vid('t1'), 'a4600000-0000-4000-8000-000000000010') ->> 'result', 'absent',
  'and cannot take it');
select is((select may_take from public.team_open_visits(pg_temp.today()) where visit_id = pg_temp.vid('open_b')), false,
  'a care assistant is not offered a B visit');
select is(public.take_open_visit(pg_temp.vid('open_b'), 'a4600000-0000-4000-8000-000000000011') ->> 'result', 'not_qualified',
  'and cannot take it (J3 rule)');
reset role;

-- 3. One tap, first wins ---------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.take_open_visit(pg_temp.vid('t1'), 'a4600000-0000-4000-8000-000000000020') ->> 'result', 'ok', 'a colleague takes a released visit');
select is(public.take_open_visit(pg_temp.vid('t1'), 'a4600000-0000-4000-8000-000000000020') ->> 'result', 'duplicate', 'the same tap twice is idempotent');
select is(public.take_open_visit(pg_temp.vid('t1'), 'a4600000-0000-4000-8000-000000000021') ->> 'result', 'already_taken',
  'a second take sees "bereits übernommen"');
select ok(not (pg_temp.vid('t1') = any (pg_temp.open_ids(pg_temp.today()))), 'the taken visit leaves "Offen im Team"');
select is(public.take_open_visit(pg_temp.vid('t3'), 'a4600000-0000-4000-8000-000000000022') ->> 'result', 'already_taken',
  'a visit with someone responsible cannot be taken');
reset role;
select is(pg_temp.resp('t1'), '00000000-0000-4000-a000-000000000902'::uuid, 'the taker is responsible; exactly one responsible member');
select is((select time_start from public.care_visits where id = pg_temp.vid('t1')), '09:00'::time, 'the planned time stays');
select is((select reason from public.visit_plan_changes where visit_id = pg_temp.vid('t1') and change = 'taken'),
  'Übernommen aus «Offen im Team»', 'the take is in the J3 change log');

-- 4. Shorten: untaken visits return, taken visits stay ---------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.change_absence((select id from public.member_absences limit 1), true, null, null,
          'a4600000-0000-4000-8000-000000000030') ->> 'result', 'rejected', 'a colleague who did not record it cannot withdraw it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.change_absence((select absence_id from public.team_absences() where is_me), false, pg_temp.today() + 2, null,
          'a4600000-0000-4000-8000-000000000031') ->> 'result', 'not_shorter', 'a longer end is not a shortening');
select is((public.change_absence((select absence_id from public.team_absences() where is_me), false, pg_temp.today() + 1, '12:00',
          'a4600000-0000-4000-8000-000000000032') ->> 'returned')::int, 1, 'she shortens it to tomorrow 12:00: one untaken visit returns');
reset role;
select is(pg_temp.resp('t2'), '00000000-0000-4000-a000-000000000906'::uuid, 'the afternoon visit is hers again');
select is(pg_temp.resp('t1'), '00000000-0000-4000-a000-000000000902'::uuid, 'the taken visit stays with the colleague');
select is((select reason from public.visit_plan_changes where visit_id = pg_temp.vid('t2') and change = 'returned'),
  'Abwesenheit beendet', 'the return is logged with a fixed text');

-- 5. For a colleague; withdraw by the absent member ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906',
          pg_temp.today() + 3, null, null, null, 'a4600000-0000-4000-8000-000000000040') ->> 'released')::int, 1,
  'a colleague records the absence for her (she phoned one colleague, not a dispatcher)');
reset role;
select is((select recorded_by from public.member_absences where starts_at = (pg_temp.today() + 3 + time '00:00') at time zone 'Europe/Zurich'),
  '00000000-0000-4000-a000-000000000902'::uuid, 'it is recorded with who recorded it');
select is(pg_temp.resp('t3'), null, 'her visit that day is released');
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is((select recorded_by_me from public.team_absences() where is_me and starts_at > now() + interval '2 days'), false,
  'she sees it on her /field, recorded by a colleague');
select is((public.change_absence((select absence_id from public.team_absences() where is_me and starts_at > now() + interval '2 days'),
          true, null, null, 'a4600000-0000-4000-8000-000000000041') ->> 'returned')::int, 1, 'she withdraws it; the untaken visit returns');
reset role;
select is(pg_temp.resp('t3'), '00000000-0000-4000-a000-000000000906'::uuid, 'and is hers again');
select ok((select withdrawn_at is not null from public.member_absences where starts_at = (pg_temp.today() + 3 + time '00:00') at time zone 'Europe/Zurich'),
  'the withdrawn absence keeps its row');

-- 6. Other team, other organisation ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', pg_temp.today() + 4,
          null, null, null, 'a4600000-0000-4000-8000-000000000050') ->> 'result', 'rejected', 'a member of another team cannot record an absence there');
select is(public.record_absence('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000906', pg_temp.today() + 4,
          null, null, null, 'a4600000-0000-4000-8000-000000000051') ->> 'result', 'rejected', 'nor for someone outside her team');
select is(cardinality(pg_temp.open_ids(pg_temp.today())), 0, 'another team does not see the open visits');
select is(public.take_open_visit(pg_temp.vid('open_b'), 'a4600000-0000-4000-8000-000000000052') ->> 'result', 'rejected', 'nor take one');
select is((select count(*)::int from public.team_absences()), 0, 'nor sees who is absent');
select is((select count(*)::int from public.member_absences), 0, 'nor reads the absence rows');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.member_absences), 0, 'Operations does not read who is absent');
select is((select count(*)::int from public.team_absences()), 0, 'not through the reader either');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(cardinality(pg_temp.open_ids(pg_temp.today())), 0, 'another organisation sees nothing');
select is(public.take_open_visit(pg_temp.vid('hand'), 'a4600000-0000-4000-8000-000000000053') ->> 'result', 'rejected', 'and takes nothing');
reset role;

-- 7. CGR-22: a hand-planned visit with nobody responsible is taken; the exception ends with its cause -------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ops('hand', 'visit_uncovered'), 1, 'the hand-planned visit without anyone raises visit_uncovered');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select ok(pg_temp.vid('hand') = any (pg_temp.open_ids(pg_temp.today())), 'it is listed for every team member');
select is(public.take_open_visit(pg_temp.vid('hand'), 'a4600000-0000-4000-8000-000000000060') ->> 'result', 'ok', 'a member takes it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ops('hand', 'visit_uncovered'), 0, 'visit_uncovered ends with its cause');
reset role;

-- 8. CGR-18 / CGR-15: 902 is absent today with a paused visit and a draft report -----------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902', null, null, null, null,
          'a4600000-0000-4000-8000-000000000070') ->> 'result', 'ok', 'an absence for today is accepted while she has a paused visit and a draft report');
reset role;
select is(pg_temp.resp('paused'), '00000000-0000-4000-a000-000000000902'::uuid, 'the paused visit keeps her as responsible');
select is(private.visit_performer(pg_temp.vid('paused')), '00000000-0000-4000-a000-000000000902'::uuid, 'and as performer');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ops('paused', 'visit_stuck'), 1, 'and it carries the stuck-visit exception');
select is(pg_temp.ops('overdue', 'visit_overdue'), 1, 'CGR-15: the released overdue visit nobody took stays alerted after its start');
select ok((select detail from public.operations_exceptions() where exception_type = 'visit_overdue' and entity_id = pg_temp.vid('overdue')) like '%niemand zuständig%',
  'with "niemand zuständig", never who is absent');
reset role;
select is(pg_temp.resp('overdue'), null, 'the overdue planned visit was released');
select is(pg_temp.resp('later'), null, 'and the later one today');
select is((select status from public.visit_reports where visit_id = pg_temp.vid('done')), 'draft', 'her draft report stays');
select ok(private.user_in_team('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902')
          and (select performer_id from public.visit_reports where visit_id = pg_temp.vid('done')) = '00000000-0000-4000-a000-000000000902',
  'she stays a member and the performer, so she can sign it on return');

-- 9. HAND1: a release shows as the fact only ---------------------------------------------------------------------------
select ok(exists (select 1 from private.handover_entries(pg_temp.vid('t3'), '00000000-0000-4000-a000-000000000906') h
                  where h.kind = 'visit_released' and h.detail ->> 'reason' is null
                    and not (h.detail -> 'before' ? 'responsible_id') and not (h.detail -> 'after' ? 'responsible_id')),
  'HAND1 lists "wieder offen im Team" without a reason or a member id');

-- 10. PLAN2 respects the absence ---------------------------------------------------------------------------------------
-- 906 (primary) absent on day +6; 902 (deputy) absent on day +7. A daily A item 08:00-09:00.
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 6, null, null, null,
          'a4600000-0000-4000-8000-000000000080') ->> 'result', 'ok', 'the primary nurse records a future absence');
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902', pg_temp.today() + 7, null,
          null, null, 'a4600000-0000-4000-8000-000000000081') ->> 'result', 'ok', 'and one for the deputy');
reset role;
-- Both absences on day +7 to test "else uncovered".
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906',
        (pg_temp.today() + 7 + time '00:00') at time zone 'Europe/Zurich', (pg_temp.today() + 8 + time '00:00') at time zone 'Europe/Zurich',
        '00000000-0000-4000-a000-000000000906');
insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by,
                                    freq_times, freq_period, freq_weekdays, window_start, window_end) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   'Körperpflege', 'A', 30, 'täglich', current_date + 30, '00000000-0000-4000-a000-000000000902', 1, 'day', null, '06:00', '07:00');
select lives_ok($$ select private.generate_case_plan('00000000-0000-4000-a000-000000000208', private.plan_system_actor()) $$, 'the plan is generated');
create function pg_temp.gen(d integer) returns uuid language sql as $$
  select responsible_user_id from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
    and visit_date = pg_temp.today() + d and plan_slot_start = '06:00' $$;
select is(pg_temp.gen(8), '00000000-0000-4000-a000-000000000906'::uuid, 'a normal day goes to the primary nurse');
select is(pg_temp.gen(6), '00000000-0000-4000-a000-000000000902'::uuid, 'PLAN2: during her absence the visit goes to the deputy');
select is(pg_temp.gen(7), null, 'with both absent it stays uncovered, never the absent member');
select lives_ok($$ select private.generate_case_plan('00000000-0000-4000-a000-000000000208', private.plan_system_actor()) $$, 'regeneration runs');
select ok(pg_temp.gen(6) = '00000000-0000-4000-a000-000000000902' and pg_temp.gen(7) is null,
  're-generation never assigns the absent member');
-- A visit taken from "Offen im Team" is not reassigned by regeneration.
update public.member_absences set withdrawn_at = now(), withdrawn_by = '00000000-0000-4000-a000-000000000902'
  where user_id = '00000000-0000-4000-a000-000000000902' and starts_at = (pg_temp.today() + 7 + time '00:00') at time zone 'Europe/Zurich';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.take_open_visit((select id from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
          and plan_generated and visit_date = pg_temp.today() + 7 and plan_slot_start = '06:00'), 'a4600000-0000-4000-8000-000000000082') ->> 'result',
  'ok', 'the deputy, back, takes the generated uncovered visit');
reset role;
update public.member_absences set withdrawn_at = now(), withdrawn_by = '00000000-0000-4000-a000-000000000906'
  where user_id = '00000000-0000-4000-a000-000000000906' and starts_at = (pg_temp.today() + 7 + time '00:00') at time zone 'Europe/Zurich';
select lives_ok($$ select private.generate_case_plan('00000000-0000-4000-a000-000000000208', private.plan_system_actor()) $$, 'regeneration after both return');
select is(pg_temp.gen(7), '00000000-0000-4000-a000-000000000902'::uuid, 'the taken visit stays with the taker (not reassigned to the primary nurse)');

-- 11. CGR-11: registered nurse → care assistant releases what she may no longer perform -------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_member_qualification('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902', 'care_assistant',
          'Synthetisch: Testfall Qualifikation', 'a4600000-0000-4000-8000-000000000090'), 'ok', 'the administrator changes her qualification');
reset role;
select is(pg_temp.resp('rn_b'), null, 'CGR-11: her B visit is released');
select is(pg_temp.resp('rn_a'), '00000000-0000-4000-a000-000000000902'::uuid, 'her A visit stays');
select is((select reason from public.visit_plan_changes where visit_id = pg_temp.vid('rn_b') and change = 'released'),
  'Qualifikation geändert', 'with a fixed reason text');
select is(pg_temp.resp('paused'), '00000000-0000-4000-a000-000000000902'::uuid, 'a visit in progress is not released (CGR-10)');

select * from finish();
rollback;
