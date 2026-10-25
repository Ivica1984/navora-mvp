-- ABS1 part 2, AN1 (migration 0048, ADR-059): the three absence measures in pilot_kpis, organisation level for
-- coordination roles, team level under the small-team rule. Aggregates only: no row names who was absent.
-- Fixtures (synthetic) are written as the table owner with fixed offsets from private.now(), so the figures do not depend on
-- the time of day (only a run in the first three hours of a month would put the fixtures in the previous month).
-- COVER1 lead time: the seed default (24 h).
begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;

update public.cases set primary_nurse_id = '00000000-0000-4000-a000-000000000906', deputy_nurse_id = '00000000-0000-4000-a000-000000000902'
  where id = '00000000-0000-4000-a000-000000000208';

-- Absence 1 (906, recorded 2 h ago by 902): v1 taken by the deputy, v2 taken by someone else, v3 not taken, v4 returned
-- to her untaken (left out). Absence 2 (902, recorded 3 h ago): v5 taken by the primary nurse 30 min later.
insert into public.member_absences (id, organization_id, team_id, user_id, starts_at, ends_at, recorded_by, created_at) values
  ('a0480000-0000-4000-9000-000000000001', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101',
   '00000000-0000-4000-a000-000000000906', private.now() - interval '1 hour', private.now() + interval '5 days', '00000000-0000-4000-a000-000000000902',
   private.now() - interval '2 hours'),
  ('a0480000-0000-4000-9000-000000000002', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101',
   '00000000-0000-4000-a000-000000000902', private.now() - interval '1 hour', private.now() + interval '2 hours', '00000000-0000-4000-a000-000000000902',
   private.now() - interval '3 hours');

create temp table fx (name text primary key, id uuid not null, absence uuid not null, at timestamptz not null);
insert into fx values
  ('v1', 'a0480000-0000-4000-8000-000000000101', 'a0480000-0000-4000-9000-000000000001', ((pg_temp.today() + 3) + time '09:00') at time zone 'Europe/Zurich'),
  ('v2', 'a0480000-0000-4000-8000-000000000102', 'a0480000-0000-4000-9000-000000000001', ((pg_temp.today() + 3) + time '11:00') at time zone 'Europe/Zurich'),
  ('v3', 'a0480000-0000-4000-8000-000000000103', 'a0480000-0000-4000-9000-000000000001', ((pg_temp.today() + 3) + time '13:00') at time zone 'Europe/Zurich'),
  ('v4', 'a0480000-0000-4000-8000-000000000104', 'a0480000-0000-4000-9000-000000000001', ((pg_temp.today() + 3) + time '15:00') at time zone 'Europe/Zurich'),
  ('v5', 'a0480000-0000-4000-8000-000000000105', 'a0480000-0000-4000-9000-000000000002', private.now() + interval '1 hour');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (f.at at time zone 'Europe/Zurich')::date, (f.at at time zone 'Europe/Zurich')::time,
       ((f.at + interval '30 minutes') at time zone 'Europe/Zurich')::time, array['Grundpflege'], false, 'planned', 30, 0,
       case f.name when 'v1' then '00000000-0000-4000-a000-000000000902'::uuid when 'v2' then '00000000-0000-4000-a000-000000000901'::uuid
                   when 'v4' then '00000000-0000-4000-a000-000000000906'::uuid when 'v5' then '00000000-0000-4000-a000-000000000906'::uuid end
from fx f;
insert into public.absence_releases (absence_id, visit_id) select f.absence, f.id from fx f;
insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id, changed_at)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       x.change, '{}'::jsonb, '{}'::jsonb, x.reason, x.actor, x.at
from fx f join (values
  ('v1', 'taken',    'Übernommen aus «Offen im Team»', '00000000-0000-4000-a000-000000000902'::uuid, private.now() - interval '90 minutes'),
  ('v2', 'taken',    'Übernommen aus «Offen im Team»', '00000000-0000-4000-a000-000000000901'::uuid, private.now() - interval '60 minutes'),
  ('v4', 'returned', 'Abwesenheit beendet',            '00000000-0000-4000-a000-000000000902'::uuid, private.now() - interval '30 minutes'),
  ('v5', 'taken',    'Übernommen aus «Offen im Team»', '00000000-0000-4000-a000-000000000906'::uuid, private.now() - interval '150 minutes')
) as x(name, change, reason, actor, at) on x.name = f.name;

-- AN1 condition (0057, ADR-070): the seed's small teams would hide the organisation row of org A. Three more synthetic
-- persons with one completed visit each this month, in two small teams of their own (no case, no client, no
-- departure), make the hidden teams' persons number 3 or more, so the organisation figures under test may show.
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000011', 'ad570000-0000-4000-8000-0000000000b1', 'AN1 Fixture 1', 'Test', 'active'),
  ('00000000-0000-4000-b000-000000000011', 'ad570000-0000-4000-8000-0000000000b2', 'AN1 Fixture 2', 'Test', 'active');
insert into public.care_visits (organization_id, id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000011', ('ad570000-0000-4000-8000-00000000000' || g)::uuid,
       case when g < 3 then 'ad570000-0000-4000-8000-0000000000b1' else 'ad570000-0000-4000-8000-0000000000b2' end::uuid,
       date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date)::date, '06:00', '06:30', false, 'completed'
from generate_series(1, 3) g;
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
select v.organization_id, v.id, v.team_id, 'started', 'on_the_way', 'started',
       ('ad570000-0000-4000-8000-0000000000f' || right(v.id::text, 1))::uuid, (v.visit_date + time '06:00') at time zone 'Europe/Zurich'
from public.care_visits v where v.team_id in ('ad570000-0000-4000-8000-0000000000b1', 'ad570000-0000-4000-8000-0000000000b2');
-- Organisation level (coordination role) --------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is((select value from public.pilot_kpis(pg_temp.today()) where team_id is null and kpi = 'absence_taken_before_cover_lead'),
  50.0::numeric, 'taken by the own team before the COVER1 lead time: v1 and v2 of v1, v2, v3, v5 (v4 returned, left out)');
select is((select base from public.pilot_kpis(pg_temp.today()) where team_id is null and kpi = 'absence_taken_before_cover_lead'),
  4, 'with its base count');
select is((select value from public.pilot_kpis(pg_temp.today()) where team_id is null and kpi = 'absence_last_take_minutes'),
  30::numeric, 'median minutes to the last take: only absence 2 has all its released visits taken (30 min)');
select is((select base from public.pilot_kpis(pg_temp.today()) where team_id is null and kpi = 'absence_last_take_minutes'),
  1, 'base: absences whose released visits are all taken');
select is((select value from public.pilot_kpis(pg_temp.today()) where team_id is null and kpi = 'absence_taken_by_known_share'),
  66.7::numeric, 'taken by the deputy or primary nurse: v1 (deputy) and v5 (primary) of three taken');
select ok((select bool_and(too_few) from public.pilot_kpis(pg_temp.today()) where team_id is null and kpi like 'absence_%'),
  'small bases are flagged as too few');
select ok((select bool_and(note is not null) from public.pilot_kpis(pg_temp.today()) where kpi like 'absence_%'),
  'each measure carries its note');
select is((select count(*)::int from public.pilot_kpis(pg_temp.today())
           where kpi like 'absence_%' and team_id is not null and value is not null), 0,
  'team level: no figure while the team has fewer than three nurses with visits (small-team rule)');
reset role;

-- Another organisation sees none of it ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.pilot_kpis(pg_temp.today()) where kpi like 'absence_%'
             and organization_id = '00000000-0000-4000-b000-000000000011'), 0, 'another organisation sees no absence measure');
reset role;

-- Nothing about who was absent: the function's result has no member column.
select is(pg_get_function_result('public.pilot_kpis(date)'::regprocedure),
  'TABLE(organization_id uuid, team_id uuid, team_name text, kpi text, value numeric, base integer, too_few boolean, note text)',
  'AN1 returns aggregates only (no member column)');

select * from finish();
rollback;
