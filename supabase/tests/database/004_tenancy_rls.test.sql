-- T9: tenant isolation and role rules (ADR-005, ADR-018).
-- Users (supabase/seed.sql):
--   coach.test  …901  org A, role coach, no team
--   pflege.test …902  org A, role nurse, member of Testteam Nord (…101)
--   fremd.test  …903  org B, role admin
--   (none)      …999  signed in, but member of nothing
begin;
create extension if not exists pgtap with schema extensions;

select plan(38);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- ---------------------------------------------------------------------------
-- anon: no access to any table (closes SR-01 locally)
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok(format('select 1 from public.%I limit 1', t), '42501', null, 'anon cannot read ' || t)
from unnest(array['teams','cases','partner_requests','matching_requests','match_candidates',
                  'care_visits','care_notes','quality_events','organizations',
                  'organization_memberships','team_memberships']) as t;
select throws_ok(
  $$ update public.teams set priority = true $$, '42501', null, 'anon cannot update teams');
select throws_ok(
  $$ update public.care_visits set status = 'started' $$, '42501', null, 'anon cannot update visits');
reset role;

-- ---------------------------------------------------------------------------
-- No legacy policy survives
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from pg_policies where policyname = 'legacy_public_all'),
  0, 'all legacy_public_all policies are dropped');
select is(
  (select count(*)::int from pg_policies where schemaname = 'public' and 'public' = any (roles)),
  0, 'no policy in public targets the PUBLIC role');

-- ---------------------------------------------------------------------------
-- coach.test (org A, coach)
-- ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.cases), 10, 'coach A sees the 10 org-A cases');
select is((select count(*)::int from public.cases where organization_id = '00000000-0000-4000-b000-000000000012'),
  0, 'coach A sees no org-B case');
select is((select count(*)::int from public.teams where name = 'Fremdteam B'), 0, 'coach A does not see Fremdteam B');
select is((select count(*)::int from public.care_visits), 7, 'coach A sees the 7 org-A visits');
select is((select count(*)::int from public.organizations), 1, 'coach A sees only own organisation');
select is((select count(*)::int from public.organization_memberships), 1, 'coach A sees only own membership');

with u as (update public.teams set priority = true
           where id = '00000000-0000-4000-a000-000000000104' returning 1)
select is((select count(*)::int from u), 1, 'coach A can set Coach-Fokus on an org-A team');

with u as (update public.teams set priority = true
           where id = '00000000-0000-4000-a000-000000000151' returning 1)
select is((select count(*)::int from u), 0, 'coach A cannot change an org-B team');

with u as (update public.care_visits set status = 'started'
           where id = '00000000-0000-4000-a000-000000000501' returning 1)
select is((select count(*)::int from u), 0, 'coach A (no team) cannot move a team visit');

select throws_ok(
  $$ update public.teams set organization_id = '00000000-0000-4000-b000-000000000012'
     where id = '00000000-0000-4000-a000-000000000104' $$,
  '42501', null, 'coach A cannot move a team to another organisation');
select throws_ok(
  $$ insert into public.cases (organization_id, name) values ('00000000-0000-4000-b000-000000000011', 'x') $$,
  '42501', null, 'coach A cannot insert cases');
select throws_ok(
  $$ delete from public.care_visits $$, '42501', null, 'coach A cannot delete visits');
select throws_ok(
  $$ update public.cases set notes = 'x' $$, '42501', null, 'coach A cannot update cases');
reset role;

-- ---------------------------------------------------------------------------
-- pflege.test (org A, nurse, member of Testteam Nord)
-- ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
with u as (update public.care_visits set status = 'started'
           where id = '00000000-0000-4000-a000-000000000501' returning 1)
select is((select count(*)::int from u), 1, 'nurse can start a visit of her own team');

with u as (update public.care_visits set status = 'completed'
           where id = '00000000-0000-4000-a000-000000000505' returning 1)
select is((select count(*)::int from u), 0, 'nurse cannot move a visit of another team (Testteam Mitte)');

with u as (update public.care_visits set status = 'started'
           where id = '00000000-0000-4000-a000-000000000551' returning 1)
select is((select count(*)::int from u), 0, 'nurse cannot move an org-B visit');

with u as (update public.teams set priority = true
           where id = '00000000-0000-4000-a000-000000000101' returning 1)
select is((select count(*)::int from u), 0, 'nurse cannot change team settings, not even of her own team');

select throws_ok(
  $$ update public.care_visits set team_id = '00000000-0000-4000-a000-000000000102'
     where id = '00000000-0000-4000-a000-000000000501' $$,
  '42501', null, 'nurse cannot reassign a visit to another team');
select is((select count(*)::int from public.team_memberships), 1, 'nurse sees only her own team membership');
reset role;

-- ---------------------------------------------------------------------------
-- fremd.test (org B, admin) and a member of nothing
-- ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select string_agg(name, ',') from public.cases), 'Testfall B1', 'org-B admin sees only org-B cases');
with u as (update public.teams set priority = true
           where id = '00000000-0000-4000-a000-000000000101' returning 1)
select is((select count(*)::int from u), 0, 'org-B admin cannot change an org-A team');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000999');
set local role authenticated;
select is((select count(*)::int from public.cases) + (select count(*)::int from public.teams)
          + (select count(*)::int from public.care_visits), 0,
  'a signed-in user without membership sees nothing');
reset role;

-- ---------------------------------------------------------------------------
-- Cross-tenant references are impossible at the database level
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.care_visits (organization_id, case_id, team_id)
     values ('00000000-0000-4000-b000-000000000012',
             '00000000-0000-4000-a000-000000000208',
             '00000000-0000-4000-a000-000000000151') $$,
  '23503', null, 'a visit cannot reference a case of another organisation');

select * from finish();
rollback;
