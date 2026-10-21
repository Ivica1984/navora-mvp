-- Baseline schema and the documented LEGACY exposure.
-- The "LEGACY SR-01" assertions describe the current insecure state on purpose.
-- T9 must flip them (anon sees 0 rows and cannot write) in the same PR that
-- replaces the policies — a passing legacy assertion after T9 is a failure.
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

select has_table('public', t, 'table ' || t || ' exists')
from unnest(array[
  'teams', 'cases', 'partner_requests', 'matching_requests',
  'match_candidates', 'care_visits', 'care_notes', 'quality_events'
]) as t;

select is(
  (select count(*)::int from pg_tables
   where schemaname = 'public'
     and tablename in ('teams','cases','partner_requests','matching_requests',
                       'match_candidates','care_visits','care_notes','quality_events')
     and rowsecurity),
  8,
  'RLS is enabled on all 8 care tables'
);

select fk_ok('public', 'cases', 'assigned_team_id', 'public', 'teams', 'id', 'cases.assigned_team_id → teams.id');
select fk_ok('public', 'care_visits', 'case_id', 'public', 'cases', 'id', 'care_visits.case_id → cases.id');

-- Seed sanity: synthetic only
select is(
  (select count(*)::int from public.cases where name not like 'Testfall %'),
  0,
  'every seeded case is an obvious test case'
);

-- LEGACY SR-01 — documents today's exposure; must become the opposite in T9.
set local role anon;
select ok(
  (select count(*) from public.cases) > 0,
  'LEGACY SR-01: anon can read cases (T9 must make this 0)'
);
select lives_ok(
  $$ update public.teams set coach_name = coach_name where id = '00000000-0000-4000-a000-000000000104' $$,
  'LEGACY SR-01: anon can update teams (T9 must deny this)'
);
reset role;

select * from finish();
rollback;
