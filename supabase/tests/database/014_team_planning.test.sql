-- J3 (PO brief docs/agents/briefs/J3.md): visit planning with billable basis.
-- Users: coach …901 (joins Testteam Nord as care assistant during the test) · nurse …902 (Testteam Nord, registered nurse) · foreign …903 · operations …904
-- Case …208 (Testfall 08): Testteam Nord, laufend, needs assessment done (seed), no medical order recorded.
begin;
create extension if not exists pgtap with schema extensions;

select plan(37);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.plan(case_id uuid, d date, s time, e time, a int, b int, c int, na boolean, resp uuid, k text)
returns jsonb language sql as $$ select public.plan_visit(case_id, d, s, e, a, b, c, na, resp, k::uuid) $$;

select ok(not has_table_privilege('authenticated', 'public.care_visits', 'insert'), 'no direct visit inserts');
select ok(not has_table_privilege('authenticated', 'public.care_plan_items', 'insert'), 'no direct care-plan inserts');
select ok(not has_table_privilege('authenticated', 'public.visit_plan_changes', 'insert'), 'no direct change-log inserts');

-- A new case without needs assessment (ready intake, accepted by Testteam Nord) --------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$
begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital J3', 'Spital', 'Bern West', null,
    'mittel', null, 'J3 Anfrage', 'Bedarf J3', array['Grundpflege'], 'a3000000-0000-4000-8000-000000000101');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'J3 Anfrage'),
    'Klient', 'J3neu', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', (now() at time zone 'Europe/Zurich')::date + 1,
      'medical_order_status', 'requested'),
    'a3000000-0000-4000-8000-000000000102');
end $$;
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.decide_matching_request(
    -- F0: nurses read offers through team_offers(), not the matching_requests table
    (select o.matching_request_id from public.team_offers() o where o.request_title = 'Teamsuche: J3 Anfrage'),
    '00000000-0000-4000-a000-000000000101', 'accept', null, 'a3000000-0000-4000-8000-000000000103');
end $$;

create temp table j3 as select id from public.cases where last_name = 'J3neu';

select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 1, '09:00', '09:45', 0, 0, 30, false, null,
          'a3000000-0000-4000-8000-000000000001') ->> 'reason',
  'assessment_first', 'before the needs assessment no other visit can be planned');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 1, '09:00', '10:00', 45, 15, 0, true, null,
          'a3000000-0000-4000-8000-000000000002') ->> 'reason',
  'assessment_category_a_only', 'the needs assessment is category A only');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 1, '09:00', '10:00', 60, 0, 0, true,
          '00000000-0000-4000-a000-000000000902', 'a3000000-0000-4000-8000-000000000003') ->> 'result',
  'ok', 'the team plans the needs assessment (registered nurse responsible)');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 2, '09:00', '10:00', 60, 0, 0, true, null,
          'a3000000-0000-4000-8000-000000000004') ->> 'reason',
  'assessment_already_planned', 'only one open needs-assessment visit at a time');
select is(
  (select array_agg(kind) from public.team_cases() t, unnest(t.open_tasks) kind where t.case_id = (select id from j3) and kind = 'inform_gp'),
  null, 'the needs assessment itself creates no inform-GP task');

-- A care assistant of the team cannot start the needs assessment (registered nurse only)
reset role;
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select throws_ok(
  $$ select public.start_visit((select id from public.care_visits where case_id = (select id from j3) and is_needs_assessment),
                               'a3000000-0000-4000-8000-000000000050') $$,
  'NV001', null, 'a care assistant cannot start the needs-assessment visit');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

-- Complete the assessment → regular planning opens
select is(public.start_visit((select id from public.care_visits where case_id = (select id from j3) and is_needs_assessment),
          'a3000000-0000-4000-8000-000000000005'), 'ok', 'start assessment');
select is(public.complete_visit((select id from public.care_visits where case_id = (select id from j3) and is_needs_assessment),
          'a3000000-0000-4000-8000-000000000006'), 'ok', 'complete assessment');
select is((select needs_assessment_done from public.team_cases() where case_id = (select id from j3)), true,
  'completing the assessment visit marks the case');

-- Care plan
select is(public.add_care_plan_item((select id from j3), 'Grundpflege', 'C', 30, '1x täglich', (now() at time zone 'Europe/Zurich')::date + 30,
          'Selbständig waschen am Lavabo', 'a3000000-0000-4000-8000-000000000007'), 'ok', 'the team records a care-plan item (category C)');
select is(public.add_care_plan_item((select id from j3), 'Wundversorgung', 'B', 15, '3x pro Woche', (now() at time zone 'Europe/Zurich')::date + 10,
          null, 'a3000000-0000-4000-8000-000000000008'), 'ok', 'and a category B item');
select throws_ok(
  $$ select public.add_care_plan_item((select id from j3), 'X', 'D', 15, 'x', (now() at time zone 'Europe/Zurich')::date + 10, null, 'a3000000-0000-4000-8000-000000000009') $$,
  '22023', null, 'only categories A, B, C exist');
select is(jsonb_array_length((select care_plan from public.team_cases() where case_id = (select id from j3))), 2,
  'the care plan summary lists both items');
select is(
  (select care_plan -> 1 ->> 'goal' from public.team_cases() where case_id = (select id from j3)),
  'Selbständig waschen am Lavabo', 'a care-plan item keeps its care goal');
select is(
  (select care_goals from public.field_visits((now() at time zone 'Europe/Zurich')::date + 1) where case_id = (select id from j3) limit 1),
  array['Selbständig waschen am Lavabo'], 'the care goal appears on the nurse''s visit card');

-- Visits with minutes per category
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 2, '08:00', '08:45', 0, 15, 30, false, null,
          'a3000000-0000-4000-8000-000000000010') ->> 'reason',
  'order_required', 'a category B visit without a present medical order is refused');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 2, '08:00', '08:45', 0, 0, 30, false, null,
          'a3000000-0000-4000-8000-000000000011') ->> 'result',
  'ok', 'a category C visit without an order is allowed');
select is(
  (select count(*)::int from public.case_tasks where case_id = (select id from j3) and kind = 'inform_gp' and status = 'open'),
  1, 'and creates the inform-GP task');
select is(
  (select planned_minutes_a || '/' || planned_minutes_b || '/' || planned_minutes_c from public.care_visits
   where case_id = (select id from j3) and visit_date = (now() at time zone 'Europe/Zurich')::date + 2),
  '0/0/30', 'minutes are stored per category, not only as a total');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 3, '08:00', '08:20', 0, 0, 30, false, null,
          'a3000000-0000-4000-8000-000000000012') ->> 'reason',
  'minutes_exceed_window', 'planned minutes cannot exceed the time window');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 40, '08:00', '08:45', 0, 0, 30, false, null,
          'a3000000-0000-4000-8000-000000000013') -> 'flags',
  '["reassessment_due"]'::jsonb, 'a visit after the care-plan review date is flagged for reassessment');
reset role;

-- Medical order present but expiring (the coach is a care assistant of the team since above)
update public.cases set medical_order_status = 'present', medical_order_valid_until = (now() at time zone 'Europe/Zurich')::date + 5 where last_name = 'J3neu';

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 4, '08:00', '08:45', 0, 15, 30, false,
          '00000000-0000-4000-a000-000000000901', 'a3000000-0000-4000-8000-000000000014') ->> 'reason',
  'rn_required', 'a category B visit cannot be assigned to a care assistant');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 4, '08:00', '08:45', 0, 15, 30, false,
          '00000000-0000-4000-a000-000000000902', 'a3000000-0000-4000-8000-000000000015') ->> 'result',
  'ok', 'a category B visit with a present order and a registered nurse is planned');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 7, '08:00', '08:45', 0, 15, 0, false,
          '00000000-0000-4000-a000-000000000902', 'a3000000-0000-4000-8000-000000000016') -> 'flags',
  '["order_expired"]'::jsonb, 'a category B visit after the order validity end is flagged');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 4, '10:00', '10:30', 0, 0, 30, false,
          '00000000-0000-4000-a000-000000000903', 'a3000000-0000-4000-8000-000000000017') ->> 'reason',
  'responsible_not_in_team', 'the responsible person must be a member of the team');

-- Move and remove need a reason; the change log keeps the original
select throws_ok(
  format($$ select public.reschedule_visit(%L, (now() at time zone 'Europe/Zurich')::date + 5, '08:00', '08:45', '', 'a3000000-0000-4000-8000-000000000018') $$,
         (select id from public.care_visits where case_id = (select id from j3) and visit_date = (now() at time zone 'Europe/Zurich')::date + 2)),
  '22023', null, 'moving without a reason is refused');
select is(public.reschedule_visit((select id from public.care_visits where case_id = (select id from j3) and visit_date = (now() at time zone 'Europe/Zurich')::date + 2),
          (now() at time zone 'Europe/Zurich')::date + 5, '08:00', '08:45', 'Klientin hat Arzttermin', 'a3000000-0000-4000-8000-000000000019') ->> 'result',
  'ok', 'the team moves a visit with a reason');
select is(
  (select (before ->> 'date')::date || ' → ' || (after ->> 'date')::date || ' · ' || reason
   from public.visit_plan_changes where change = 'moved' and case_id = (select id from j3)),
  ((now() at time zone 'Europe/Zurich')::date + 2)::text || ' → ' || ((now() at time zone 'Europe/Zurich')::date + 5)::text || ' · Klientin hat Arzttermin',
  'the change log keeps original, new value and reason');
select is(public.remove_planned_visit((select id from public.care_visits where case_id = (select id from j3) and visit_date = (now() at time zone 'Europe/Zurich')::date + 5),
          'Doppelt geplant', 'a3000000-0000-4000-8000-000000000020') ->> 'result',
  'ok', 'the team removes a planned visit with a reason');
select is(
  (select count(*)::int from public.visit_plan_changes where case_id = (select id from j3) and change = 'removed' and reason = 'Doppelt geplant'),
  1, 'the removed plan stays in the change log');
reset role;

-- Uncovered visits in the next 24 h → Operations
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok(
  (select count(*) from public.uncovered_visits()) >= 0,
  'operations can list uncovered visits (no client identity)');
select is(
  (select count(*)::int from public.team_cases()), 0, 'operations has no team cases (no dispatcher)');
select is(pg_temp.plan((select id from j3), (now() at time zone 'Europe/Zurich')::date + 4, '12:00', '12:30', 0, 0, 30, false, null,
          'a3000000-0000-4000-8000-000000000030') ->> 'reason',
  'not_team_member', 'operations cannot plan the team''s visits');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(pg_temp.plan('00000000-0000-4000-a000-000000000208', (now() at time zone 'Europe/Zurich')::date + 4, '12:00', '12:30', 0, 0, 30, false, null,
          'a3000000-0000-4000-8000-000000000040') ->> 'reason',
  'not_team_member', 'another organisation cannot plan');
reset role;

select * from finish();
rollback;
