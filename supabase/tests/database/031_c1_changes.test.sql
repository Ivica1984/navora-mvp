-- C1 changes requested by the PO (review 2026-10-22 14:30). Migration 0031.
-- Case …208 (Testteam Nord …101, nurse …902). Case …206 (no team, open matching request …401, region "Zürich Pilot").
-- Here: coach …901 joins Testteam Mitte …102 (another team, same organisation) and Testteam West …104 (Zürich Pilot).
-- Operations …904 (coordinator), foreign admin …903 (org B).
begin;
create extension if not exists pgtap with schema extensions;

select plan(28);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000104', '00000000-0000-4000-a000-000000000901', 'registered_nurse');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, planned_minutes_a)
select '00000000-0000-4000-b000-000000000011', x.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       current_date + x.d, x.t, x.t + interval '30 minutes', false, 'planned', 30
from (values ('b1000000-0000-4000-8000-000000000001'::uuid, 3, time '14:00'),
             ('b1000000-0000-4000-8000-000000000002'::uuid, 0, time '23:30'),
             ('b1000000-0000-4000-8000-000000000003'::uuid, 4, time '15:00')) x(id, d, t);

-- Another team of the same organisation -------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'hospital_stay', null, null, 'b1000000-0000-4000-8000-000000000010'),
  'rejected', 'a member of another team cannot pause');
select is(public.resume_case('00000000-0000-4000-a000-000000000208', 'b1000000-0000-4000-8000-000000000011'), 'rejected', 'nor resume');
select is(public.cancel_visit('b1000000-0000-4000-8000-000000000001', 'team_cancelled', null, 'b1000000-0000-4000-8000-000000000012'),
  'rejected', 'nor cancel a visit');
select is(public.record_no_show('b1000000-0000-4000-8000-000000000001', 'Niemand öffnet', 'b1000000-0000-4000-8000-000000000013'),
  'rejected', 'nor record a no-show');
select is(public.reopen_case('00000000-0000-4000-a000-000000000208', 'Rückkehr', 'b1000000-0000-4000-8000-000000000014'), 'rejected',
  'nor reopen (neither the assigned team nor Operations)');
reset role;

-- Another organisation -------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.cancel_visit('b1000000-0000-4000-8000-000000000001', 'team_cancelled', null, 'b1000000-0000-4000-8000-000000000020'),
  'rejected', 'another organisation cannot cancel');
select is(public.close_case('00000000-0000-4000-a000-000000000208', 'goal_reached', null, 'b1000000-0000-4000-8000-000000000021'),
  'rejected', 'nor close');
select is(public.reopen_case('00000000-0000-4000-a000-000000000208', 'Rückkehr', 'b1000000-0000-4000-8000-000000000022'),
  'rejected', 'nor reopen');
reset role;

-- No-show: no report draft, no billing fact; audit with the reason --------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin perform public.depart_visit('b1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000030'); end $$;
select is(public.record_no_show('b1000000-0000-4000-8000-000000000002', 'Niemand öffnet', 'b1000000-0000-4000-8000-000000000031'), 'ok', 'no-show');
select is(public.create_report_draft('b1000000-0000-4000-8000-000000000002', null, 'b1000000-0000-4000-8000-000000000032') ->> 'reason',
  'visit_not_completed', 'a no-show visit gets no report draft');
reset role;
select is((select count(*)::int from public.billable_facts where visit_id = 'b1000000-0000-4000-8000-000000000002'), 0,
  'and so no billing fact');
select ok(exists (select 1 from public.audit_events where command = 'record_no_show'
                  and idempotency_key = 'b1000000-0000-4000-8000-000000000031'), 'the no-show is audited');

-- Late team cancellation stays visible until handled -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.cancel_visit('b1000000-0000-4000-8000-000000000003', 'team_cancelled', null, 'b1000000-0000-4000-8000-000000000040'), 'ok',
  'the team cancels a visit');
reset role;
-- Two days later, seen from the database: move the cancellation note and the visit into the past.
update public.care_visits set visit_date = current_date - 2 where id = 'b1000000-0000-4000-8000-000000000003';
alter table public.visit_status_notes disable trigger visit_status_notes_no_update_delete;
update public.visit_status_notes set created_at = ((current_date - 2) + time '15:00') at time zone 'Europe/Zurich' - interval '2 hours'
  where visit_id = 'b1000000-0000-4000-8000-000000000003';
alter table public.visit_status_notes enable trigger visit_status_notes_no_update_delete;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'team_cancellation_late'
           and entity_id = 'b1000000-0000-4000-8000-000000000003'), 1, 'the late cancellation is still open two days later');
select is(public.handle_exception('team_cancellation_late:b1000000-0000-4000-8000-000000000003', 'close', 'Mit Familie geklärt',
          'b1000000-0000-4000-8000-000000000041'), 'ok', 'until Operations closes it with a reason');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'team_cancellation_late'
           and entity_id = 'b1000000-0000-4000-8000-000000000003'), 0, 'then it is gone');
reset role;

-- Pause and close are audited with their reasons; close leaves records untouched ------------------------------------
create temp table before_close as
  select (select count(*) from public.visit_reports r join public.care_visits v on v.id = r.visit_id
          where v.case_id = '00000000-0000-4000-a000-000000000208' and r.status = 'final') as reports,
         (select count(*) from public.quality_events where case_id = '00000000-0000-4000-a000-000000000208') as quality,
         (select count(*) from public.billable_facts where case_id = '00000000-0000-4000-a000-000000000208') as facts;
insert into public.case_tasks (organization_id, case_id, kind) values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'inform_gp')
  on conflict do nothing;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'client_absence', null, null, 'b1000000-0000-4000-8000-000000000050'), 'ok', 'pause');
select is(public.resume_case('00000000-0000-4000-a000-000000000208', 'b1000000-0000-4000-8000-000000000051'), 'ok', 'resume');
select is(public.close_case('00000000-0000-4000-a000-000000000208', 'goal_reached', null, 'b1000000-0000-4000-8000-000000000052'), 'ok', 'close');
reset role;
select is((select count(distinct idempotency_key)::int from public.audit_events
           where idempotency_key in ('b1000000-0000-4000-8000-000000000050', 'b1000000-0000-4000-8000-000000000052')
             and table_name = 'case_lifecycle_events' and changed -> 'reason_code' ->> 'new' is not null), 2,
  'pause and close write audit rows with the reason');
select is((select count(*)::int from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000208' and status = 'open'), 0,
  'open case tasks are closed');
select ok((select (select count(*) from public.visit_reports r join public.care_visits v on v.id = r.visit_id
                   where v.case_id = '00000000-0000-4000-a000-000000000208' and r.status = 'final') = b.reports
                  and (select count(*) from public.quality_events where case_id = '00000000-0000-4000-a000-000000000208') = b.quality
                  and (select count(*) from public.billable_facts where case_id = '00000000-0000-4000-a000-000000000208') = b.facts
           from before_close b), 'final reports, quality events and billing facts are unchanged');

-- Close withdraws matching ---------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.close_case('00000000-0000-4000-a000-000000000206', 'declined', null, 'b1000000-0000-4000-8000-000000000060'), 'ok',
  'Operations closes a case that is still in the team search');
reset role;
select ok((select status = 'withdrawn' from public.matching_requests where id = '00000000-0000-4000-a000-000000000401')
          and not exists (select 1 from public.match_candidates where matching_request_id = '00000000-0000-4000-a000-000000000401'
                          and status <> 'withdrawn'), 'its matching request and candidates are withdrawn');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.team_offers() where matching_request_id = '00000000-0000-4000-a000-000000000401'), 0,
  'no team is offered it any more');
reset role;

-- PO addendum: Operations sees the organisation's cases for close and reopen; nobody else does.
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok(exists (select 1 from public.ops_case_lifecycle() where case_id = '00000000-0000-4000-a000-000000000209'),
  'Operations lists the organisation''s cases');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.ops_case_lifecycle()), 0, 'a nurse gets nothing from the Operations list');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.ops_case_lifecycle() where case_id = '00000000-0000-4000-a000-000000000209'), 0,
  'another organisation sees none of these cases');
reset role;

select * from finish();
rollback;
