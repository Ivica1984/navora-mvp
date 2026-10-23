-- CSR1, first PR (migration 0038; Clinical Governance Report 2026-10-22 22:30): C1's findings CGR-12 and CGR-04.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · coach …901
--        (coordinator of org A, not in a team) · admin …905 (org A) · fremd …903 (admin of org B).
-- CGR-12: a care assistant cannot resume or complete a category B or needs-assessment visit (NV001); a registered
--         nurse can; category A stays open to every member. All steps through the real commands.
-- CGR-04: `visit_overdue` and `visit_stuck` (PROVISIONAL thresholds, D-28); the uncovered exception stays after the
--         planned start; a removed member's visit dated yesterday is raised and shown to another team member.
-- Within one transaction now() is constant, so visit times are placed relative to now() and stuck visits get a
-- synthetic earlier status event (inserted as the table owner, as a fixture).
begin;
create extension if not exists pgtap with schema extensions;

select plan(38);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
create temp table fx (name text primary key, id uuid not null, at timestamptz not null, status text not null,
                      resp uuid, min_a int not null default 0, min_b int not null default 0, na boolean not null default false);
grant select on fx to authenticated;
insert into fx values
  -- CGR-12
  ('b_visit',   '00000000-0000-4000-a038-000000000001', now() - interval '20 minutes', 'planned', '00000000-0000-4000-a000-000000000902', 0, 30, false),
  ('na_visit',  '00000000-0000-4000-a038-000000000002', now() - interval '20 minutes', 'planned', '00000000-0000-4000-a000-000000000902', 30, 0, true),
  ('a_visit',   '00000000-0000-4000-a038-000000000003', now() - interval '20 minutes', 'planned', '00000000-0000-4000-a000-000000000906', 30, 0, false),
  -- CGR-04 overdue
  ('late2h',    '00000000-0000-4000-a038-000000000011', now() - interval '2 hours',    'planned', '00000000-0000-4000-a000-000000000902', 30, 0, false),
  ('late10',    '00000000-0000-4000-a038-000000000012', now() - interval '10 minutes', 'planned', '00000000-0000-4000-a000-000000000902', 30, 0, false),
  ('ahead',     '00000000-0000-4000-a038-000000000013', now() + interval '2 hours',    'planned', '00000000-0000-4000-a000-000000000902', 30, 0, false),
  ('nobody',    '00000000-0000-4000-a038-000000000014', now() - interval '10 minutes', 'planned', null,                                    30, 0, false),
  ('yesterday', '00000000-0000-4000-a038-000000000015', now() - interval '1 day',      'planned', '00000000-0000-4000-a000-000000000906', 30, 0, false),
  ('suspended', '00000000-0000-4000-a038-000000000016', now() - interval '2 hours',    'planned', '00000000-0000-4000-a000-000000000902', 30, 0, false),
  -- CGR-04 stuck
  ('paused2h',  '00000000-0000-4000-a038-000000000021', now() - interval '3 hours',    'paused',  '00000000-0000-4000-a000-000000000902', 30, 0, false),
  ('way4h',     '00000000-0000-4000-a038-000000000022', now() - interval '5 hours',    'on_the_way', '00000000-0000-4000-a000-000000000902', 30, 0, false),
  ('long',      '00000000-0000-4000-a038-000000000023', now() - interval '10 minutes', 'started', '00000000-0000-4000-a000-000000000902', 30, 0, false);

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, is_needs_assessment, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (f.at at time zone 'Europe/Zurich')::date, (f.at at time zone 'Europe/Zurich')::time,
       case when f.name = 'long' then ((f.at + interval '2 hours') at time zone 'Europe/Zurich')::time
            else ((f.at + interval '30 minutes') at time zone 'Europe/Zurich')::time end,
       array['Grundpflege'], false, f.status, f.min_a, f.min_b, f.na, f.resp
from fx f;
-- 'long' may end after midnight; the stuck rule then counts its end on the next day (0038).
update public.care_visits set suspended_at = now() where id = '00000000-0000-4000-a038-000000000016';

-- Synthetic last status events for the stuck fixtures: paused 2 h ago, on the way 4 h ago, started 1 h 30 ago.
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, occurred_at, actor_id)
values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a038-000000000021', '00000000-0000-4000-a000-000000000101',
   'paused', 'started', 'paused', now() - interval '2 hours', '00000000-0000-4000-a000-000000000902'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a038-000000000022', '00000000-0000-4000-a000-000000000101',
   'departed', 'planned', 'on_the_way', now() - interval '4 hours', '00000000-0000-4000-a000-000000000902'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a038-000000000023', '00000000-0000-4000-a000-000000000101',
   'started', 'planned', 'started', now() - interval '90 minutes', '00000000-0000-4000-a000-000000000902');

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.status(n text) returns text language sql as $$
  select v.status from public.care_visits v where v.id = pg_temp.vid(n) $$;
-- Exceptions as the coordinator sees them (OPS1) and as a team member sees them (team view).
create function pg_temp.ops(t text, n text) returns table (exception_key text, priority text, detail text) language sql as $$
  select x.exception_key, x.priority, x.detail from public.operations_exceptions() x
  where x.exception_type = t and x.entity_id = pg_temp.vid(n) $$;
create function pg_temp.team(t text, n text) returns table (exception_key text, priority text, detail text) language sql as $$
  select x.exception_key, x.priority, x.detail from public.team_visit_alerts() x
  where x.exception_type = t and x.visit_id = pg_temp.vid(n) $$;

-- CGR-12: the qualification rule holds for the whole visit ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select throws_ok($$ select public.start_visit(pg_temp.vid('b_visit'), 'a3800000-0000-4000-8000-000000000001') $$, 'NV001', null,
  'CGR-12: a care assistant cannot start a category B visit (unchanged)');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.vid('b_visit'), 'a3800000-0000-4000-8000-000000000002'), 'ok', 'the registered nurse starts the B visit');
select is(public.pause_visit(pg_temp.vid('b_visit'), 'a3800000-0000-4000-8000-000000000003'), 'ok', 'and pauses it');
select is(public.start_visit(pg_temp.vid('na_visit'), 'a3800000-0000-4000-8000-000000000004'), 'ok', 'she starts the needs assessment');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select throws_ok($$ select public.resume_visit(pg_temp.vid('b_visit'), 'a3800000-0000-4000-8000-000000000005') $$, 'NV001', null,
  'CGR-12: a care assistant cannot resume a paused category B visit');
select throws_ok($$ select public.complete_visit(pg_temp.vid('na_visit'), 'a3800000-0000-4000-8000-000000000006') $$, 'NV001', null,
  'CGR-12: a care assistant cannot complete a needs-assessment visit');
reset role;
select is(pg_temp.status('b_visit'), 'paused', 'CGR-12: the B visit stays paused');
select is(pg_temp.status('na_visit'), 'started', 'CGR-12: the needs assessment stays started');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.resume_visit(pg_temp.vid('b_visit'), 'a3800000-0000-4000-8000-000000000007'), 'ok', 'CGR-12: the registered nurse resumes it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select throws_ok($$ select public.complete_visit(pg_temp.vid('b_visit'), 'a3800000-0000-4000-8000-000000000008') $$, 'NV001', null,
  'CGR-12: a care assistant cannot complete a category B visit');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.complete_visit(pg_temp.vid('b_visit'), 'a3800000-0000-4000-8000-000000000009'), 'ok', 'CGR-12: the registered nurse completes it');
select is(public.complete_visit(pg_temp.vid('na_visit'), 'a3800000-0000-4000-8000-000000000010'), 'ok', 'and completes the needs assessment');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('a_visit'), 'a3800000-0000-4000-8000-000000000011');
  perform public.pause_visit(pg_temp.vid('a_visit'), 'a3800000-0000-4000-8000-000000000012');
end $$;
select is(public.resume_visit(pg_temp.vid('a_visit'), 'a3800000-0000-4000-8000-000000000013'), 'ok',
  'a care assistant still resumes a category A visit');
select is(public.complete_visit(pg_temp.vid('a_visit'), 'a3800000-0000-4000-8000-000000000014'), 'ok',
  'and completes it');
reset role;

-- CGR-04: overdue (as Operations) -----------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select priority from pg_temp.ops('visit_overdue', 'late2h')), 'P1',
  'CGR-04: a planned visit not started 2 h after its planned start is overdue, P1 after 1 h (PROVISIONAL)');
select is((select priority from pg_temp.ops('visit_overdue', 'late10')), 'P2',
  'CGR-04: 10 minutes after the planned start it is already raised, as P2');
select ok((select detail like '%zuständig: %' from pg_temp.ops('visit_overdue', 'late10')), 'the detail names who is responsible');
select is((select count(*)::int from pg_temp.ops('visit_overdue', 'ahead')), 0, 'a visit still ahead is not overdue');
select is((select count(*)::int from pg_temp.ops('visit_overdue', 'suspended')), 0, 'a suspended visit (case paused) is not overdue');
select ok((select detail like '%niemand zuständig%' from pg_temp.ops('visit_overdue', 'nobody')),
  'CGR-04: overdue does not depend on a responsible person ("niemand zuständig")');
select is((select count(*)::int from pg_temp.ops('visit_uncovered', 'nobody')), 1,
  'PS-2: the uncovered exception no longer disappears at the planned start');
reset role;

-- The team sees its overdue visits too; other people see nothing.
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select priority from pg_temp.team('visit_overdue', 'late2h')), 'P1', 'CSR1: every team member sees the overdue visit, same priority');
select is((select count(*)::int from public.operations_exceptions()), 0, 'a nurse still sees no OPS1 list');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.team_visit_alerts()), 0, 'a coordinator outside the team gets no team alerts (OPS1 is her list)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.team_visit_alerts()), 0, 'another organisation sees nothing');
reset role;

-- Started → the overdue exception ends; the visit is not stuck yet.
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.vid('late2h'), 'a3800000-0000-4000-8000-000000000020'), 'ok', 'the nurse starts the late visit');
select is((select count(*)::int from pg_temp.team('visit_overdue', 'late2h')), 0, 'once started it is no longer overdue');
select is((select count(*)::int from pg_temp.team('visit_stuck', 'late2h')), 0, 'and not stuck: it just started');

-- CGR-04: stuck visits.
select is((select priority from pg_temp.team('visit_stuck', 'paused2h')), 'P2', 'CGR-04: paused for 2 h is stuck, P2 (PROVISIONAL 1 h)');
select is((select priority from pg_temp.team('visit_stuck', 'way4h')), 'P1', 'CGR-04: on the way for 4 h is stuck, P1 after 3 h');
select is((select count(*)::int from pg_temp.team('visit_stuck', 'long')), 0,
  'a started visit is not stuck before its planned end');
select is(public.resume_visit(pg_temp.vid('paused2h'), 'a3800000-0000-4000-8000-000000000021'), 'ok', 'the nurse resumes the paused visit');
select is((select count(*)::int from pg_temp.team('visit_stuck', 'paused2h')), 0, 'the stuck exception of the old state ends with the new status change');
reset role;

-- Closed by a person in OPS1 with a reason: closed for the team as well.
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.handle_exception((select exception_key from pg_temp.ops('visit_stuck', 'way4h')), 'close',
          'Pflegeperson erreicht, Einsatz läuft', 'a3800000-0000-4000-8000-000000000030'), 'ok',
  'a coordinator closes the stuck exception with a reason');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from pg_temp.team('visit_stuck', 'way4h')), 0, 'a closed exception is closed for the team too');
reset role;

-- CSR1 addition (ADM1 pre-review): a removed member's missed visit dated yesterday.
-- She first signs the report of the A visit she completed above (CGR-18 would refuse the removal otherwise).
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
do $$ begin
  perform public.create_report_draft(pg_temp.vid('a_visit'), 'Synthetischer Bericht', 'a3800000-0000-4000-8000-000000000041');
  perform public.sign_report((select id from public.visit_reports where visit_id = pg_temp.vid('a_visit')),
                             'a3800000-0000-4000-8000-000000000042');
end $$;
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906',
          'Wechsel nach Mitte', 'a3800000-0000-4000-8000-000000000040') ->> 'result', 'ok',
  'the administrator removes the care assistant');
reset role;
select is((select responsible_user_id from public.care_visits where id = pg_temp.vid('yesterday')),
  '00000000-0000-4000-a000-000000000906'::uuid, 'her visit dated yesterday is not released (removal releases from today)');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok((select detail like '%zuständige Person nicht mehr im Team%' from pg_temp.team('visit_overdue', 'yesterday')),
  'CSR1: the missed visit of the removed member is overdue and shown to another member of the team');
reset role;

select * from finish();
rollback;
