-- F1: field_visits() returns only the caller's team visits, with minimal client context.
-- Users (supabase/seed.sql): coach …901 (org A, no team) · nurse …902 (Testteam Nord …101) · foreign …903 (org B)
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Contract -------------------------------------------------------------------------
select function_privs_are('public', 'field_visits', array['date'], 'anon', array[]::text[],
  'anon cannot execute field_visits');
select function_privs_are('public', 'field_visits', array['date'], 'authenticated', array['EXECUTE'],
  'authenticated can execute field_visits');
select is(
  (select prosecdef from pg_proc where oid = 'public.field_visits(date)'::regprocedure), false,
  'field_visits is SECURITY INVOKER (RLS of the caller applies)');
select is(
  (select array_agg(a order by a) from unnest(
     (select proargnames from pg_proc where oid = 'public.field_visits(date)'::regprocedure)) a
   where a in ('diagnosis_tags','cognitive_status','mobility_status','date_of_birth',
               'insurance_provider','phone','notes','billable','emergency_contact_phone')),
  null,
  'field_visits returns no health, identity or billing fields beyond name, care needs and address');

-- Nurse (Testteam Nord) ------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select results_eq(
  $$ select visit_id from public.field_visits(current_date) $$,
  $$ values ('00000000-0000-4000-a000-000000000501'::uuid), ('00000000-0000-4000-a000-000000000502'::uuid) $$,
  'nurse sees exactly her team''s two visits today, ordered by start time');
select is(
  (select count(*)::int from public.field_visits(current_date)
   where visit_id = '00000000-0000-4000-a000-000000000503'), 0,
  'nurse does not see a visit of another team on the same day (Testteam West)');
select is(
  (select count(*)::int from public.field_visits(current_date)
   where visit_id = '00000000-0000-4000-a000-000000000551'), 0,
  'nurse does not see an org-B visit on the same day');
select is(
  (select client_name || ' / ' || team_name from public.field_visits(current_date)
   where visit_id = '00000000-0000-4000-a000-000000000501'),
  'Testfall 08 / Testteam Nord',
  'client name and team name are resolved');
select is(
  (select count(*)::int from public.field_visits(current_date - 2)), 1,
  'another day returns that day''s visits (the cancelled one two days ago)');
select is((select count(*)::int from public.field_visits(null)), 0, 'no date → no rows');
reset role;

-- Coach without team, foreign organisation -----------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.field_visits(current_date)), 0,
  'a coach who is in no team gets an empty field list');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.field_visits(current_date)), 0,
  'org-B admin (no team in org A) sees no org-A visits');
reset role;

select * from finish();
rollback;
