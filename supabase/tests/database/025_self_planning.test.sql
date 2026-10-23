-- PLAN2: visits follow the care plan (PO brief docs/agents/briefs/PLAN2.md).
-- Case …208 (Testteam Nord …101). Nurse …902 (registered nurse) is the deputy; coach …901 joins the team
-- here as care assistant and is the primary nurse, so category B work must go to the deputy.
-- Users outside the team: operations …904 (org A), foreign admin …903 (org B).
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.generated() returns integer language sql as $$
  select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
$$;

insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant');
update public.cases
  set primary_nurse_id = '00000000-0000-4000-a000-000000000901', deputy_nurse_id = '00000000-0000-4000-a000-000000000902',
      medical_order_status = 'present', medical_order_valid_until = pg_temp.today() + 10
  where id = '00000000-0000-4000-a000-000000000208';

-- Structure ------------------------------------------------------------------------------------------------------
select has_column('public', 'care_plan_items', 'freq_period', 'care-plan items have a structured frequency');
select ok(not has_table_privilege('authenticated', 'public.plan_slot_skips', 'insert'), 'removed slots are recorded by the database only');
select throws_ok($$ insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency,
                      review_date, created_by, freq_times, freq_period, window_start, window_end)
                    values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                      'Test', 'A', 10, '2x täglich', (now() at time zone 'Europe/Zurich')::date + 30, '00000000-0000-4000-a000-000000000902', 2, 'day', '08:00', '09:00') $$,
  '23514', null, 'once a day per item (a second daily visit is a second item with its own window)');

-- The care plan generates four weeks ---------------------------------------------------------------------------
insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by,
                                    freq_times, freq_period, freq_weekdays, window_start, window_end) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   'Körperpflege', 'A', 30, 'täglich', (now() at time zone 'Europe/Zurich')::date + 30, '00000000-0000-4000-a000-000000000902', 1, 'day', null, '08:00', '09:00'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   'Wundversorgung', 'B', 20, '2x wöchentlich', (now() at time zone 'Europe/Zurich')::date + 30, '00000000-0000-4000-a000-000000000902', 2, 'week', '{1,4}', '08:00', '09:00');

select is(pg_temp.generated(), 28, 'one visit per day for the next four weeks');
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated and planned_minutes_b = 20),
          (select count(*)::int from generate_series(pg_temp.today() + 1, pg_temp.today() + 10, interval '1 day') g where extract(isodow from g) in (1, 4)),
  'B minutes on Mondays and Thursdays, merged into the same visit, only while the order is valid');
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
           and planned_minutes_b > 0 and visit_date > pg_temp.today() + 10), 0, 'no B work after the order ends');
select ok(not exists (select 1 from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
                      and planned_minutes_b > 0 and responsible_user_id is distinct from '00000000-0000-4000-a000-000000000902'),
  'B work goes to the deputy because the primary nurse is a care assistant');
select ok(not exists (select 1 from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
                      and planned_minutes_b = 0 and responsible_user_id is distinct from '00000000-0000-4000-a000-000000000901'),
  'other visits go to the primary nurse');
select is((select count(*)::int from public.visit_plan_changes pc join public.care_visits v on v.id = pc.visit_id
           where v.case_id = '00000000-0000-4000-a000-000000000208' and v.plan_generated and pc.change = 'planned' and pc.reason = 'care plan'),
  28, 'every generated visit is in the plan change log with the reason "care plan"');

insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        'Hauswirtschaft', 'A', 15, 'wöchentlich', (now() at time zone 'Europe/Zurich')::date + 30, '00000000-0000-4000-a000-000000000902');

-- The team stays in charge -------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select jsonb_array_length(unscheduled) from public.team_plan_status() where case_id = '00000000-0000-4000-a000-000000000208'), 1,
  'the team sees which items are not planned automatically');
select ok((select r -> 'reasons' ? 'order_missing_or_expired' and r -> 'reasons' ? 'items_without_schedule' and r ->> 'result' = 'ok'
           from public.plan_from_care_plan('00000000-0000-4000-a000-000000000208', 'a2600000-0000-4000-8000-000000000001') r),
  'the team action plans and says what was left out and why');
select is(public.remove_planned_visit((select id from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
            and plan_generated and visit_date = pg_temp.today() + 3), 'Klient verreist', 'a2600000-0000-4000-8000-000000000002') ->> 'result',
  'ok', 'the team removes a generated visit');
select is(public.reschedule_visit((select id from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
            and plan_generated and visit_date = pg_temp.today() + 5), pg_temp.today() + 5, '10:00', '11:00', 'Wunsch der Klientin',
            'a2600000-0000-4000-8000-000000000003') ->> 'result', 'ok', 'and moves another one');
select is(public.plan_from_care_plan('00000000-0000-4000-a000-000000000208', 'a2600000-0000-4000-8000-000000000004') ->> 'result', 'ok', 'plans again');
reset role;
select is(pg_temp.generated(), 27, 'a removed slot is not recreated');

update public.care_plan_items set planned_minutes = 40
  where case_id = '00000000-0000-4000-a000-000000000208' and service = 'Körperpflege';
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
           and planned_minutes_a = 40), 26, 'a care-plan change regenerates the future untouched visits');
select is((select planned_minutes_a from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
           and visit_date = pg_temp.today() + 5), 30, 'the moved visit is never overwritten');
select is((select count(*)::int from public.visit_plan_changes pc join public.care_visits v on v.id = pc.visit_id
           where v.case_id = '00000000-0000-4000-a000-000000000208' and pc.change = 'regenerated' and pc.reason = 'care plan'),
  26, 'each regenerated visit is logged with the reason "care plan"');

-- Other teams and roles --------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.plan_from_care_plan('00000000-0000-4000-a000-000000000208', 'a2600000-0000-4000-8000-000000000010') ->> 'result',
  'rejected', 'Operations does not plan for the team');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.plan_from_care_plan('00000000-0000-4000-a000-000000000208', 'a2600000-0000-4000-8000-000000000011') ->> 'result',
  'rejected', 'another organisation cannot plan this case');
select is((select count(*)::int from public.team_plan_status()), 0, 'and sees no plan status');
reset role;

-- Structured frequency through the command -------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.set_care_plan_schedule((select id from public.care_plan_items where service = 'Hauswirtschaft'
          and case_id = '00000000-0000-4000-a000-000000000208'), 2, 'week', array[1,3,5], '14:00', '14:30', 'a2600000-0000-4000-8000-000000000020') $$,
  '22023', null, 'weekdays must match the number of visits');
select is(public.set_care_plan_schedule((select id from public.care_plan_items where service = 'Hauswirtschaft'
          and case_id = '00000000-0000-4000-a000-000000000208'), 1, 'week', array[3], '14:00', '14:30', 'a2600000-0000-4000-8000-000000000021') ->> 'result',
  'ok', 'the team sets a weekly frequency with a weekday and a window');
reset role;
select is(pg_temp.generated(), 31, 'the new item adds a Wednesday afternoon visit each week');

-- Switching the series off and on ----------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.set_auto_planning('00000000-0000-4000-a000-000000000208', false, null, 'a2600000-0000-4000-8000-000000000030') $$,
  '22023', null, 'switching the series off needs a reason');
select is(public.set_auto_planning('00000000-0000-4000-a000-000000000208', false, 'Pflegeplan wird überarbeitet', 'a2600000-0000-4000-8000-000000000031'),
  'ok', 'the team switches the series off');
reset role;
select is(pg_temp.generated(), 1, 'future untouched visits are dropped; the moved one stays');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_auto_planning('00000000-0000-4000-a000-000000000208', true, 'Plan bestätigt', 'a2600000-0000-4000-8000-000000000032'),
  'ok', 'and on again');
reset role;
select is(pg_temp.generated(), 31, 'the series is back, still without the removed slot');

-- C1 and J3 rules ------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'hospital_stay', null, null, 'a2600000-0000-4000-8000-000000000040'), 'ok', 'pause');
select ok((select r ->> 'result' = 'skipped' and r -> 'reasons' ? 'case_paused'
           from public.plan_from_care_plan('00000000-0000-4000-a000-000000000208', 'a2600000-0000-4000-8000-000000000041') r),
  'nothing is generated while the case is paused');
select is(public.resume_case('00000000-0000-4000-a000-000000000208', 'a2600000-0000-4000-8000-000000000042'), 'ok', 'resume');
reset role;

update public.cases set medical_order_status = 'requested' where id = '00000000-0000-4000-a000-000000000208';
select ok(exists (select 1 from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000208' and kind = 'inform_gp' and status = 'open'),
  'A/C visits without an order keep the inform-GP task');
update public.cases set needs_assessment_done_at = null where id = '00000000-0000-4000-a000-000000000208';
select ok((private.generate_case_plan('00000000-0000-4000-a000-000000000208', private.plan_system_actor())) -> 'reasons' ? 'assessment_first',
  'the needs assessment still comes first');

select * from finish();
rollback;
