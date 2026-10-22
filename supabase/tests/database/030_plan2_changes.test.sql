-- PLAN2 changes requested by the PO (review 2026-10-22 14:30). Migration 0030.
-- Case …208 (Testteam Nord …101): primary nurse coach …901 (joins as care assistant), deputy nurse …902 (registered nurse).
-- Operations …904 joins Testteam Mitte …102 here (another team of the same organisation).
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.generated_planned() returns integer language sql as $$
  select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
    and status = 'planned' and visit_date > (now() at time zone 'Europe/Zurich')::date
$$;

insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant'),
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000904', 'registered_nurse');
update public.cases
  set primary_nurse_id = '00000000-0000-4000-a000-000000000901', deputy_nurse_id = '00000000-0000-4000-a000-000000000902',
      medical_order_status = 'present', medical_order_valid_until = pg_temp.today() + 10
  where id = '00000000-0000-4000-a000-000000000208';

-- A visit planned by hand in the 08:00 window two days ahead.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status, planned_minutes_a)
values ('00000000-0000-4000-b000-000000000011', 'af000000-0000-4000-8000-000000000001', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today() + 2, '08:15', '08:45', array['Grundpflege'], false, 'planned', 30);

insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by,
                                    freq_times, freq_period, freq_weekdays, window_start, window_end) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   'Körperpflege', 'A', 30, 'täglich', current_date + 30, '00000000-0000-4000-a000-000000000902', 1, 'day', null, '08:00', '09:00'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   'Wundversorgung', 'B', 20, '2x wöchentlich', current_date + 30, '00000000-0000-4000-a000-000000000902', 2, 'week', '{1,4}', '08:00', '09:00');

-- No double planning ------------------------------------------------------------------------------------------------
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
           and visit_date = pg_temp.today() + 2 and status <> 'cancelled' and time_start < '09:00' and coalesce(time_end, time_start) > '08:00'),
  1, 'a hand-planned visit in the window means no generated visit next to it');
select is(pg_temp.generated_planned(), 27, 'the other 27 days are planned');
select ok(exists (select 1 from public.visit_plan_changes where visit_id = 'af000000-0000-4000-8000-000000000001'
                  and change = 'skipped' and reason = 'care plan: already planned'), 'the skipped slot is logged as "already planned"');

-- Daily run ---------------------------------------------------------------------------------------------------------
select lives_ok($$ select private.generate_all_plans(); select private.generate_all_plans() $$, 'the daily job runs twice');
select is(pg_temp.generated_planned(), 27, 'and creates no duplicates');
select is((select count(*)::int from public.visit_plan_changes where visit_id = 'af000000-0000-4000-8000-000000000001' and change = 'skipped'),
  1, 'the skip is logged once');

-- Another team of the same organisation -------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.set_care_plan_schedule((select id from public.care_plan_items where service = 'Körperpflege'
          and case_id = '00000000-0000-4000-a000-000000000208'), 1, 'day', null, '07:00', '08:00', 'af000000-0000-4000-8000-000000000010') ->> 'result',
  'rejected', 'a member of another team cannot set the rhythm');
select is(public.plan_from_care_plan('00000000-0000-4000-a000-000000000208', 'af000000-0000-4000-8000-000000000011') ->> 'result',
  'rejected', 'nor run planning for the case');
reset role;

-- A moved B visit after the order end carries the J3 flag and shows in the plan status ------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.reschedule_visit((select id from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
            and plan_generated and planned_minutes_b > 0 order by visit_date limit 1),
          (select visit_date from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
            and plan_generated and planned_minutes_b > 0 order by visit_date limit 1), '10:00', '11:00', 'Wunsch der Klientin',
          'af000000-0000-4000-8000-000000000020') ->> 'result', 'ok', 'the team moves a generated B visit');
reset role;
update public.cases set medical_order_valid_until = pg_temp.today() where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok((select order_flagged >= 1 from public.team_plan_status() where case_id = '00000000-0000-4000-a000-000000000208'),
  'the moved B visit after the order end is flagged in the plan status');
reset role;

-- Uncovered path ------------------------------------------------------------------------------------------------------
update public.cases set primary_nurse_id = null, deputy_nurse_id = null where id = '00000000-0000-4000-a000-000000000208';
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
           and status = 'planned' and visit_date > pg_temp.today() and responsible_user_id is not null
           and not exists (select 1 from public.visit_plan_changes pc where pc.visit_id = care_visits.id and pc.change = 'moved')), 0,
  'without an eligible primary nurse or deputy the generated visits stay uncovered (J3/OPS1 flag)');

-- Withdrawn preconditions -------------------------------------------------------------------------------------------
update public.cases set needs_assessment_done_at = null where id = '00000000-0000-4000-a000-000000000208';
select is(pg_temp.generated_planned(), 1, 'needs assessment no longer done: untouched generated visits are dropped, the moved one stays');
select ok(exists (select 1 from public.visit_plan_changes where case_id = '00000000-0000-4000-a000-000000000208'
                  and change = 'removed' and reason = 'care plan: needs assessment first'), 'with the reason logged');
update public.cases set needs_assessment_done_at = now() - interval '30 days' where id = '00000000-0000-4000-a000-000000000208';

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.close_case('00000000-0000-4000-a000-000000000208', 'goal_reached', null, 'af000000-0000-4000-8000-000000000030'), 'ok', 'close');
reset role;
select is(pg_temp.generated_planned(), 0, 'a closed case has no planned generated visits left');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.reopen_case('00000000-0000-4000-a000-000000000208', 'Rückkehr nach Hause', 'af000000-0000-4000-8000-000000000031'), 'ok', 'reopen');
select ok((select r -> 'reasons' ? 'reopened_not_ready'
           from public.plan_from_care_plan('00000000-0000-4000-a000-000000000208', 'af000000-0000-4000-8000-000000000032') r)
          and (select count(*) from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated
               and status = 'planned' and visit_date > pg_temp.today()) = 0,
  'a reopened case that is not ready gets no generated visits');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok((select value is not null and value > 0 from public.pilot_kpis(current_date)
           where team_id is null and kpi = 'planning_actions_per_client_week' and organization_id = '00000000-0000-4000-b000-000000000011'),
  'AN1 counts the team''s own planning actions per client and week (the move above), not the generated ones');
reset role;

select * from finish();
rollback;
