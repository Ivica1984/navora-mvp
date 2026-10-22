-- COVER1 changes requested by the PO (2026-10-22 14:30, patient safety). Migration 0029.
-- Teams Nord (…101) and Mitte (…102), region "Bern West". Coach …901 joins Mitte (care assistant).
-- Visits of Nord, case …208: X (A, in 10 h), V (A, in 5 h), Z (A, in 30 h). Ops …904 coordinator, foreign admin …903.
begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'care_assistant');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c)
select '00000000-0000-4000-b000-000000000011', x.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (now() at time zone 'Europe/Zurich' + x.lead)::date, date_trunc('minute', (now() at time zone 'Europe/Zurich' + x.lead))::time,
       null, array['Grundpflege'], false, 'planned', 30, 0, 0
from (values ('ad900000-0000-4000-8000-00000000000a'::uuid, interval '10 hours'),
             ('ad900000-0000-4000-8000-00000000000b'::uuid, interval '5 hours'),
             ('ad900000-0000-4000-8000-00000000000c'::uuid, interval '30 hours')) x(id, lead);

-- Cover is off until D-3 ------------------------------------------------------------------------------------------
select is((select cover_enabled from public.cover_settings where organization_id is null), false, 'cover is off by default (platform)');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.cover_offers()), 0, 'while off, nobody is offered a visit');
select is(public.accept_cover('ad900000-0000-4000-8000-00000000000a', 'ad900000-0000-4000-8000-000000000001'), 'disabled',
  'and acceptance is refused');
select is(public.sync_cover_offers(), 0, 'and no offer is recorded');
reset role;

insert into public.cover_settings (organization_id, offer_lead_hours, fallback_lead_hours, cover_enabled)
values ('00000000-0000-4000-b000-000000000011', 24, 4, true);

-- A covered visit stays flagged and visible to Operations ---------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.accept_cover('ad900000-0000-4000-8000-00000000000a', 'ad900000-0000-4000-8000-000000000002'), 'rejected',
  'a nurse of another organisation cannot accept');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.accept_cover('ad900000-0000-4000-8000-00000000000c', 'ad900000-0000-4000-8000-000000000003'), 'taken',
  'outside the window nobody can accept');
select is(public.accept_cover('ad900000-0000-4000-8000-00000000000a', 'ad900000-0000-4000-8000-000000000004'), 'ok', 'accepted with cover on');
select is(public.accept_cover('ad900000-0000-4000-8000-00000000000b', 'ad900000-0000-4000-8000-000000000005'), 'ok', 'and a second, 5 h ahead');
reset role;
select ok((select responsible_user_id is null and covered_by = '00000000-0000-4000-a000-000000000901'
           from public.care_visits where id = 'ad900000-0000-4000-8000-00000000000a'),
  'no responsible member until she can perform the visit (D-3)');
select ok('uncovered' = any (private.visit_flags('00000000-0000-4000-a000-000000000208',
            (select visit_date from public.care_visits where id = 'ad900000-0000-4000-8000-00000000000a'), 0, null, 'planned',
            (select time_start from public.care_visits where id = 'ad900000-0000-4000-8000-00000000000a'))),
  'the case team keeps its uncovered flag');

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from public.operations_exceptions() where exception_type = 'cover_without_access'
           and entity_id = 'ad900000-0000-4000-8000-00000000000a'), 'P2', 'OPS1 shows "Übernahme ohne Zugriff" (P2 more than 4 h ahead)');
select is((select count(*)::int from public.operations_exceptions() where exception_type in ('visit_uncovered', 'visit_uncovered_hospital')
           and entity_id = 'ad900000-0000-4000-8000-00000000000a'), 0, 'instead of the plain uncovered exception');
reset role;
-- Move V to 3 h ahead (inside the fallback lead) to see the escalation.
update public.care_visits set visit_date = (now() at time zone 'Europe/Zurich' + interval '3 hours')::date,
                              time_start = date_trunc('minute', (now() at time zone 'Europe/Zurich' + interval '3 hours'))::time
  where id = 'ad900000-0000-4000-8000-00000000000b';
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from public.operations_exceptions() where exception_type = 'cover_without_access'
           and entity_id = 'ad900000-0000-4000-8000-00000000000b'), 'P1', 'and P1 from 4 h before the start');
reset role;

-- Withdraw ---------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.withdraw_cover('ad900000-0000-4000-8000-00000000000a', 'nicht meine', 'ad900000-0000-4000-8000-000000000010'), 'rejected',
  'only the covering nurse hands a cover back');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select throws_ok($$ select public.withdraw_cover('ad900000-0000-4000-8000-00000000000a', null, 'ad900000-0000-4000-8000-000000000011') $$,
  '22023', null, 'handing back needs a reason');
select is(public.withdraw_cover('ad900000-0000-4000-8000-00000000000b', 'Kind krank', 'ad900000-0000-4000-8000-000000000012'), 'too_late',
  'not inside the last 4 h');
select is(public.withdraw_cover('ad900000-0000-4000-8000-00000000000a', 'Kind krank', 'ad900000-0000-4000-8000-000000000013'), 'ok',
  'she hands it back with a reason');
reset role;
select ok((select covered_by is null from public.care_visits where id = 'ad900000-0000-4000-8000-00000000000a')
          and (select max(seq) filter (where kind = 'offered') > max(seq) filter (where kind = 'withdrawn')
               from public.cover_events where visit_id = 'ad900000-0000-4000-8000-00000000000a'),
  'the visit is offered again');
select ok(exists (select 1 from public.visit_plan_changes where visit_id = 'ad900000-0000-4000-8000-00000000000a'
                  and reason like 'cover withdrawn: Kind krank%'), 'the case team sees it in its plan log');

-- Two empty regions never match ------------------------------------------------------------------------------------
update public.teams set region = '' where id in ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000102');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.cover_offers()), 0, 'teams without a region are not neighbours');
reset role;

select * from finish();
rollback;
