-- C1: case and visit lifecycle (PO brief docs/agents/briefs/C1.md).
-- Users: nurse …902 (Testteam Nord) · ops …904 (operations) · coach …901 (coordinator, not in the team) · foreign …903
-- Case …208 (Testteam Nord, laufend). Visit …508 (tomorrow, planned). Visits X and Y inserted here (in 3 h).
begin;
create extension if not exists pgtap with schema extensions;

select plan(39);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000011', x.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       ((private.now() + interval '3 hours') at time zone 'Europe/Zurich')::date, ((private.now() + interval '3 hours') at time zone 'Europe/Zurich')::time, null, false, 'planned'
from (values ('ad000000-0000-4000-8000-0000000000aa'::uuid)) x(id);
-- VIS1-5: the no-show fixture is departed below, so it is dated today (a visit dated after today cannot be departed,
-- CGR-87); before VIS1 it was dated three hours ahead, i.e. tomorrow after 21:00 Zurich.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
values ('00000000-0000-4000-b000-000000000011', 'ad000000-0000-4000-8000-0000000000bb', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date, '23:59', null, false, 'planned');

select ok(not has_table_privilege('authenticated', 'public.visit_status_notes', 'insert'), 'status notes only through commands');
select ok(not has_table_privilege('authenticated', 'public.case_lifecycle_events', 'insert'), 'lifecycle only through commands');

-- Pause and resume --------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'hospital_stay', null, null, 'ad000000-0000-4000-8000-000000000001'),
  'rejected', 'another organisation cannot pause');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.pause_case('00000000-0000-4000-a000-000000000208', 'holiday', null, null, 'ad000000-0000-4000-8000-000000000002') $$,
  '22023', null, 'pause reason from the list');
select throws_ok($$ select public.pause_case('00000000-0000-4000-a000-000000000208', 'other', null, null, 'ad000000-0000-4000-8000-000000000003') $$,
  '22023', null, '"other" needs a note');
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'hospital_stay', 'Spitaleintritt', (private.now() at time zone 'Europe/Zurich')::date + 3,
          'ad000000-0000-4000-8000-000000000004'), 'ok', 'the team pauses the case (hospital stay, expected end)');
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'hospital_stay', null, null, 'ad000000-0000-4000-8000-000000000004'),
  'duplicate', 'resend is a duplicate');
select ok((select suspended_at is not null and status = 'planned' from public.care_visits where id = '00000000-0000-4000-a000-000000000508'),
  'planned visits inside the pause are suspended, not deleted');
-- VIS1-5: today's visit 501 (inside the pause) instead of tomorrow's 508, which VIS1 refuses before the suspension check.
select ok((select suspended_at is not null from public.care_visits where id = '00000000-0000-4000-a000-000000000501'),
  'today''s planned visit inside the pause is suspended too');
select throws_ok($$ select public.depart_visit('00000000-0000-4000-a000-000000000501', 'ad000000-0000-4000-8000-000000000005') $$,
  '23514', null, 'a suspended visit cannot start');
reset role;
select ok(not ('uncovered' = any (private.visit_flags('00000000-0000-4000-a000-000000000208', (private.now() at time zone 'Europe/Zurich')::date + 1, 0, null, 'planned', '09:00'))),
  'a paused case raises no uncovered flag');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.plan_visit('00000000-0000-4000-a000-000000000208', (private.now() at time zone 'Europe/Zurich')::date + 2, '10:00', '10:30', 30, 0, 0, false, null,
          'ad000000-0000-4000-8000-000000000006') $$, 'NV002', null, 'no new visits while the case is paused');
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'rehabilitation', null, null, 'ad000000-0000-4000-8000-000000000007'),
  'wrong_state', 'an already paused case cannot be paused again');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions()
           where exception_type in ('visit_uncovered', 'visit_uncovered_hospital') and entity_id in
             ('ad000000-0000-4000-8000-0000000000aa', 'ad000000-0000-4000-8000-0000000000bb')), 0,
  'suspended visits raise no uncovered-visit exception');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.resume_case('00000000-0000-4000-a000-000000000208', 'ad000000-0000-4000-8000-000000000008'), 'ok', 'the team resumes the case');
select ok((select suspended_at is null from public.care_visits where id = '00000000-0000-4000-a000-000000000508'),
  'resume reactivates the suspended visits that lie ahead');

-- Cancel a visit --------------------------------------------------------------------------------------------------
select is(public.cancel_visit('ad000000-0000-4000-8000-0000000000aa', 'team_cancelled', null, 'ad000000-0000-4000-8000-000000000010'),
  'ok', 'the team cancels a visit with a reason');
select is(public.cancel_visit('ad000000-0000-4000-8000-0000000000aa', 'team_cancelled', null, 'ad000000-0000-4000-8000-000000000011'),
  'wrong_state', 'a cancelled visit cannot be cancelled again');
select ok((select status = 'cancelled' from public.care_visits where id = 'ad000000-0000-4000-8000-0000000000aa')
          and exists (select 1 from public.visit_events where visit_id = 'ad000000-0000-4000-8000-0000000000aa' and event_type = 'cancelled'),
  'the cancellation is a visit event');
select is(public.create_report_draft('ad000000-0000-4000-8000-0000000000aa', null, 'ad000000-0000-4000-8000-000000000012') ->> 'reason',
  'visit_not_completed', 'a cancelled visit gets no report draft (and so no billing fact)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from public.operations_exceptions() where exception_type = 'team_cancellation_late'
           and entity_id = 'ad000000-0000-4000-8000-0000000000aa'), 'P2', 'a team cancellation within 24 h is a P2 continuity exception');
reset role;

-- No-show -------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_no_show('ad000000-0000-4000-8000-0000000000bb', 'Niemand öffnet', 'ad000000-0000-4000-8000-000000000020', true),
  'wrong_state', 'a no-show is recorded after arrival (on the way), not from the plan');
do $$ begin perform public.depart_visit('ad000000-0000-4000-8000-0000000000bb', 'ad000000-0000-4000-8000-000000000021'); end $$;
select throws_ok($$ select public.record_no_show('ad000000-0000-4000-8000-0000000000bb', null, 'ad000000-0000-4000-8000-000000000022', true) $$,
  '22023', null, 'a no-show needs a note');
select is(public.record_no_show('ad000000-0000-4000-8000-0000000000bb', 'Niemand öffnet, Telefon ohne Antwort',
          'ad000000-0000-4000-8000-000000000023', true), 'ok', 'the nurse records that the client was not reached');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from public.operations_exceptions() where exception_type = 'no_show_open'
           and entity_id = 'ad000000-0000-4000-8000-0000000000bb'), 'P1', 'a no-show is a P1 safety exception at once');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.record_no_show_outcome('ad000000-0000-4000-8000-0000000000bb', 'client_reached', 'erreicht',
          'ad000000-0000-4000-8000-000000000024'), 'rejected', 'nobody outside the team records the outcome');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.record_no_show_outcome('ad000000-0000-4000-8000-0000000000bb', 'client_reached', null,
          'ad000000-0000-4000-8000-000000000025') $$, '22023', null, 'the outcome needs a note');
select is(public.record_no_show_outcome('ad000000-0000-4000-8000-0000000000bb', 'emergency_contact_informed', 'Tochter informiert, besucht heute',
          'ad000000-0000-4000-8000-000000000026', 'emergency'), 'ok', 'the team records the outcome');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'no_show_open'
           and entity_id = 'ad000000-0000-4000-8000-0000000000bb'), 0, 'the outcome closes the safety exception');

-- Close and reopen ------------------------------------------------------------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.close_case('00000000-0000-4000-a000-000000000208', 'goal_reached', null, 'ad000000-0000-4000-8000-000000000030'),
  'rejected', 'a coach outside the team cannot close (team or Operations only)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.close_case('00000000-0000-4000-a000-000000000208', 'goal_reached', null, 'ad000000-0000-4000-8000-000000000031'),
  'ok', 'Operations closes the case with a reason');
reset role;
select ok((select lifecycle = 'closed' and status = 'abgeschlossen' and primary_nurse_id is null from public.cases
           where id = '00000000-0000-4000-a000-000000000208'), 'the case is closed and the primary-nurse assignment ends');
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
           and status = 'planned' and visit_date >= (private.now() at time zone 'Europe/Zurich')::date), 0,
  'all future planned visits are cancelled');
select ok(exists (select 1 from public.visit_status_notes where visit_id = '00000000-0000-4000-a000-000000000508' and reason_code = 'case_closed'),
  'with the close reason');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.team_cases() where case_id = '00000000-0000-4000-a000-000000000208'), 0,
  'the case leaves the team''s active list');
select throws_ok($$ select public.reopen_case('00000000-0000-4000-a000-000000000208', null, 'ad000000-0000-4000-8000-000000000032') $$,
  '22023', null, 'reopening needs a reason');
select is(public.reopen_case('00000000-0000-4000-a000-000000000208', 'Rückkehr nach Hause', 'ad000000-0000-4000-8000-000000000033'),
  'ok', 'the team reopens the case');
select throws_ok($$ select public.plan_visit('00000000-0000-4000-a000-000000000208', (private.now() at time zone 'Europe/Zurich')::date + 2, '10:00', '10:30', 30, 0, 0, false, null,
          'ad000000-0000-4000-8000-000000000034') $$, 'NV003', null, 'after a reopen, planning waits for the J1 readiness check');
reset role;

select is((select string_agg(kind, ',' order by created_at) from public.case_lifecycle_events where case_id = '00000000-0000-4000-a000-000000000208'),
  'pause,resume,close,reopen', 'every lifecycle step is logged');

select * from finish();
rollback;
