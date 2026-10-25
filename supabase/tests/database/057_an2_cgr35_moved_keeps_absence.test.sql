-- AN2 first change / CGR-35 (migration 0056, ADR-069; PO 2026-10-23 23:15 in docs/agents/briefs/ABS1.md, `cra` 22:30
-- case set): a past planned visit flagged by CGR-32 (its responsible member recorded absent at its interval) that is
-- moved forward with `reschedule_visit` stores, server side and immutably, `responsible_absent = true` on its `moved`
-- row in `visit_plan_changes`. Any other move stores false. The caller cannot set it; withdrawing the absence later
-- does not erase it; the audit row carries it. No new reason code, no new parameter.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) is absent · care assistant …906 (Nord) records the absence
-- and moves. All data synthetic. Fixtures are written as the table owner; every step under test goes through the
-- real commands and readers as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(24);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;

create temp table fx (name text primary key, id uuid not null, d int not null, t0 time not null, resp uuid not null);
grant select on fx to authenticated;
insert into fx values
  -- yesterday 07:00, hers, inside the absence recorded below: flagged by CGR-32
  ('flagged', 'a0570000-0000-4000-8000-000000000001', -1, '07:00', '00000000-0000-4000-a000-000000000902'),
  -- two days ago 07:00, the colleague's; nobody absent then (the seed holds no absence)
  ('plain',   'a0570000-0000-4000-8000-000000000002', -2, '07:00', '00000000-0000-4000-a000-000000000906'),
  -- in three days 09:00, hers, after the absence: a move of a future visit
  ('future',  'a0570000-0000-4000-8000-000000000003',  3, '09:00', '00000000-0000-4000-a000-000000000902');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       pg_temp.today() + f.d, f.t0, f.t0 + interval '30 minutes', array['Grundpflege'], false, 'planned', 30, 0, f.resp
from fx f;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.flag(n text) returns boolean language sql as $$
  select pc.responsible_absent from public.visit_plan_changes pc where pc.visit_id = pg_temp.vid(n) and pc.change = 'moved' $$;

-- 1. A colleague records her absent from yesterday 06:00 through today (whole day) -----------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
create temp table r1 as
  select public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
                               pg_temp.today() - 1, pg_temp.today(), '06:00', null, 'a5700000-0000-4000-8000-000000000001') as r;
select is((select r ->> 'result' from r1), 'ok', 'the absence from yesterday 06:00 is recorded');
select ok(exists (select 1 from public.team_visit_alerts() a where a.exception_type = 'visit_overdue'
                  and a.visit_id = pg_temp.vid('flagged') and a.flags = array['responsible_absent']),
  'precondition (CGR-32): yesterday''s visit has its overdue alert, flagged responsible_absent');

-- 2. The team moves the flagged visit to tomorrow with a typed reason ("Folgeeinsatz") ------------------------------
select is(public.reschedule_visit(pg_temp.vid('flagged'), pg_temp.today() + 1, '07:00', '07:30', 'Folgeeinsatz',
          'a5700000-0000-4000-8000-000000000002') ->> 'result', 'ok',
  'CGR-35: the flagged past visit is moved to tomorrow (typed reason, no new parameter)');
select is(public.reschedule_visit(pg_temp.vid('flagged'), pg_temp.today() + 1, '07:00', '07:30', 'Folgeeinsatz',
          'a5700000-0000-4000-8000-000000000002') ->> 'result', 'duplicate',
  'the same command again is a duplicate');
reset role;
select is(pg_temp.flag('flagged'), true, 'CGR-35 (1): its moved row stores responsible_absent = true');
select is((select reason from public.visit_plan_changes where visit_id = pg_temp.vid('flagged') and change = 'moved'),
  'Folgeeinsatz', 'the typed reason is kept as given');
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.vid('flagged') and change = 'moved'), 1,
  'exactly one moved row for the visit');
select is((select visit_date from public.care_visits where id = pg_temp.vid('flagged')), pg_temp.today() + 1,
  'the visit is now planned for tomorrow');
select is((select (a.changed -> 'responsible_absent' ->> 'new')::boolean from public.audit_events a
           where a.table_name = 'visit_plan_changes' and a.entity_id = pg_temp.vid('flagged')), true,
  'CGR-35 (4): the audit row of the move records responsible_absent = true');
select is((select a.command from public.audit_events a
           where a.table_name = 'visit_plan_changes' and a.entity_id = pg_temp.vid('flagged')), 'reschedule_visit',
  'the audit row names the command');

-- 3. Readers: HAND1 detail and /team last change -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is((select (x -> 'last_change' ->> 'responsible_absent')::boolean
           from public.team_cases() tc, jsonb_array_elements(tc.upcoming) x
           where (x ->> 'visit_id')::uuid = pg_temp.vid('flagged')), true,
  'CGR-35 (3): /team (team_cases last_change) returns responsible_absent = true for the move');
reset role;
select ok(pg_get_functiondef('private.handover_entries(uuid, uuid)'::regprocedure)
          like '%''responsible_absent'', pc.responsible_absent%',
  'CGR-35 (3): HAND1 (handover_entries) adds responsible_absent to the detail of plan-change entries');

-- 4. Withdrawing the absence does not erase the stored fact -------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.change_absence((select (r ->> 'absence_id')::uuid from r1), true, null, null,
          'a5700000-0000-4000-8000-000000000003') ->> 'result', 'ok', 'the recorder withdraws the absence');
reset role;
select is(pg_temp.flag('flagged'), true, 'CGR-35 (2): after the withdrawal the moved row still has responsible_absent = true');

-- 5. A past visit without an absence, and a future visit: false -------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.vid('plain'), pg_temp.today() + 1, '10:00', '10:30', 'Folgeeinsatz',
          'a5700000-0000-4000-8000-000000000004') ->> 'result', 'ok',
  'a past visit whose responsible member was not absent is moved');
select is(public.reschedule_visit(pg_temp.vid('future'), pg_temp.today() + 4, '09:00', '09:30', 'Klientin wünscht später',
          'a5700000-0000-4000-8000-000000000005') ->> 'result', 'ok',
  'a future visit is moved');
reset role;
select is(pg_temp.flag('plain'), false, 'CGR-35 (4): the same move without an absence stores false');
select is(pg_temp.flag('future'), false, 'CGR-35 (4): a move of a future visit stores false');
select is((select (a.changed -> 'responsible_absent' ->> 'new')::boolean from public.audit_events a
           where a.table_name = 'visit_plan_changes' and a.entity_id = pg_temp.vid('plain')), false,
  'the audit row of an ordinary move records responsible_absent = false');

-- 6. The caller cannot set or change it; only a moved row can carry it ---------------------------------------------
select ok(has_table_privilege('authenticated', 'public.visit_plan_changes', 'select')
          and not has_table_privilege('authenticated', 'public.visit_plan_changes', 'insert')
          and not has_table_privilege('authenticated', 'public.visit_plan_changes', 'update')
          and not has_table_privilege('authenticated', 'public.visit_plan_changes', 'delete'),
  'CGR-35 (1): authenticated reads plan changes but cannot insert, update or delete them');
select ok(not exists (select 1 from information_schema.parameters p
                      where p.specific_schema = 'public' and p.specific_name like 'reschedule_visit\_%'
                        and p.parameter_name ilike '%absent%'),
  'reschedule_visit has no parameter for it');
select throws_ok($$ update public.visit_plan_changes set responsible_absent = false where visit_id = pg_temp.vid('flagged') $$,
  '42501', null, 'the stored fact is immutable: plan changes stay append-only, even for the table owner');
select throws_ok($$ insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, reason, actor_id,
                                                           responsible_absent)
                    values ('00000000-0000-4000-b000-000000000011', pg_temp.vid('plain'), '00000000-0000-4000-a000-000000000208',
                            '00000000-0000-4000-a000-000000000101', 'removed', 'Synthetisch',
                            '00000000-0000-4000-a000-000000000906', true) $$,
  '23514', null, 'only a moved row can carry responsible_absent = true (check constraint)');
select ok(not has_function_privilege('authenticated', 'private.audit_visit_plan_move()', 'execute')
          and not has_function_privilege('anon', 'private.audit_visit_plan_move()', 'execute'),
  'the audit trigger function is not callable by app roles');

select * from finish();
rollback;
