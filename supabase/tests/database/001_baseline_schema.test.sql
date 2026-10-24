-- Baseline schema. The two SR-01 assertions were inverted by T9 in the same
-- change that replaced the legacy policies.
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

-- SR-01 (inverted in T9): anon has no access. Was "LEGACY: anon can read/update".
set local role anon;
select throws_ok(
  $$ select count(*) from public.cases $$, '42501', null,
  'SR-01 closed: anon cannot read cases'
);
select throws_ok(
  $$ update public.teams set coach_name = coach_name where id = '00000000-0000-4000-a000-000000000104' $$,
  '42501', null,
  'SR-01 closed: anon cannot update teams'
);
reset role;

select * from finish();
rollback;
