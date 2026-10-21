-- J3: team planning — plan, move and remove planned visits of the team's own cases.
-- Users: coach …901 (org A, no team) · nurse …902 (Testteam Nord) · foreign …903 · operations …904
-- Case …208 (Testfall 08) is assigned to Testteam Nord (laufend). Case …210 belongs to Testteam Mitte.
begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select function_privs_are('public', 'plan_visit', array['uuid','date','time without time zone','time without time zone','text[]','uuid'],
  'anon', array[]::text[], 'anon cannot plan visits');
select ok(not has_table_privilege('authenticated', 'public.care_visits', 'insert'), 'no direct visit inserts');
select ok(not has_table_privilege('authenticated', 'public.care_visits', 'delete'), 'no direct visit deletes');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is(
  (select client_name || ' / ' || team_name from public.team_cases() where case_id = '00000000-0000-4000-a000-000000000208'),
  'Testfall 08 / Testteam Nord', 'the nurse sees her team''s running case');
select is(
  (select count(*)::int from public.team_cases() where case_id = '00000000-0000-4000-a000-000000000210'),
  0, 'she does not see another team''s case');

select is(public.plan_visit('00000000-0000-4000-a000-000000000208', current_date + 3, '07:30', '08:15',
          array['Grundpflege'], 'a3000000-0000-4000-8000-000000000001'),
  'ok', 'the team plans a visit for its case');
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', current_date + 3, '07:30', '08:15',
          array['Grundpflege'], 'a3000000-0000-4000-8000-000000000001'),
  'duplicate', 'the same key again is a duplicate');
select is(
  (select count(*)::int from public.care_visits
   where case_id = '00000000-0000-4000-a000-000000000208' and visit_date = current_date + 3
     and team_id = '00000000-0000-4000-a000-000000000101' and status = 'planned' and billable = false),
  1, 'exactly one planned, non-billable visit of the team exists');
select is(
  (select count(*)::int from public.field_visits(current_date + 3)), 1,
  'the planned visit appears in the nurse''s field day');

select throws_ok(
  $$ select public.plan_visit('00000000-0000-4000-a000-000000000208', current_date + 3, '09:00', '08:00', null,
       'a3000000-0000-4000-8000-000000000002') $$,
  '22023', null, 'end before start is refused');
select throws_ok(
  $$ select public.plan_visit('00000000-0000-4000-a000-000000000208', current_date - 10, '09:00', '10:00', null,
       'a3000000-0000-4000-8000-000000000003') $$,
  '22023', null, 'a date far in the past is refused');
select is(public.plan_visit('00000000-0000-4000-a000-000000000210', current_date + 3, '09:00', '10:00', null,
          'a3000000-0000-4000-8000-000000000004'),
  'rejected', 'she cannot plan for another team''s case');

select is(public.reschedule_visit(
          (select id from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and visit_date = current_date + 3),
          current_date + 4, '08:00', '08:45', 'a3000000-0000-4000-8000-000000000005'),
  'ok', 'the team moves its planned visit');
select is(public.reschedule_visit('00000000-0000-4000-a000-000000000502', current_date + 4, '08:00', '08:45',
          'a3000000-0000-4000-8000-000000000006'),
  'rejected', 'a started visit cannot be moved (it is a fact, not a plan)');
select is(public.remove_planned_visit(
          (select id from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and visit_date = current_date + 4),
          'a3000000-0000-4000-8000-000000000007'),
  'ok', 'the team removes its planned visit');
reset role;

select is(
  (select count(*)::int from public.audit_events
   where command in ('plan_visit', 'reschedule_visit', 'remove_planned_visit')
     and actor_id = '00000000-0000-4000-a000-000000000902'),
  3, 'plan, move and removal are each audited');

-- No dispatcher: coach and operations cannot plan for the team
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', current_date + 5, '09:00', '10:00', null,
          'a3000000-0000-4000-8000-000000000010'),
  'rejected', 'a coach cannot plan the team''s visits');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', current_date + 5, '09:00', '10:00', null,
          'a3000000-0000-4000-8000-000000000011'),
  'rejected', 'operations cannot plan the team''s visits (no dispatcher)');
select is((select count(*)::int from public.team_cases()), 0, 'operations has no team cases');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.remove_planned_visit('00000000-0000-4000-a000-000000000508', 'a3000000-0000-4000-8000-000000000020'),
  'rejected', 'another organisation cannot remove visits');
reset role;

select * from finish();
rollback;
