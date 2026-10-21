-- F0 step 1: team-scoped clinical read (criteria 3c/3d), closes SR-22 for the legacy tables.
-- Users: coach …901 (org A, coordinator, no team) · nurse …902 (Testteam Nord …101)
--        foreign admin …903 (org B) · operations …904 (org A, coordinator)
-- Seed: case 208 → Testteam Nord · case 210 → Testteam Mitte · case 209 → Testteam West
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Nurse: own teams only -------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is((select count(*)::int from public.cases where id = '00000000-0000-4000-a000-000000000208'), 1,
  'nurse reads the case of her own team');
select is((select count(*)::int from public.cases where id = '00000000-0000-4000-a000-000000000210'), 0,
  'nurse does not read a case of another team (Testteam Mitte)');
select is((select count(*)::int from public.cases where assigned_team_id is distinct from '00000000-0000-4000-a000-000000000101'), 0,
  'nurse reads no case outside her teams, including cases without a team');
select is((select count(*)::int from public.care_visits where team_id <> '00000000-0000-4000-a000-000000000101'), 0,
  'nurse reads visits of her own teams only');
select is((select count(*)::int from public.care_notes where team_id <> '00000000-0000-4000-a000-000000000101'), 0,
  'nurse reads visit reports of her own teams only');
select is((select count(*)::int from public.quality_events where team_id <> '00000000-0000-4000-a000-000000000101'), 0,
  'nurse reads quality events of her own teams only');
select is((select count(*)::int from public.partner_requests), 0, 'nurse reads no referrals');
select is((select count(*)::int from public.matching_requests), 0, 'nurse reads no matching requests (offers come via team_offers)');
select throws_ok($$ select diagnosis_tags from public.cases limit 1 $$, '42501', null,
  'not even the own team reads diagnosis tags through the table API');
select throws_ok($$ select content from public.care_notes limit 1 $$, '42501', null,
  'visit-report content is not readable through the table API');
select is((select count(*)::int from public.field_visits(current_date)), 2,
  'the field read model still works for the nurse (F1)');
reset role;

-- Coordinators: organisation-wide rows, no health fields ----------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.cases where organization_id = '00000000-0000-4000-b000-000000000011'), 10,
  'a coach reads all org-A cases (Operations)');
select throws_ok($$ select cognitive_status from public.cases limit 1 $$, '42501', null,
  'a coach cannot read cognitive status');
select throws_ok($$ select date_of_birth from public.cases limit 1 $$, '42501', null,
  'a coach cannot read the date of birth');
select is((select count(*)::int from public.care_notes), 2, 'a coach reads the status of all org-A visit reports');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok((select count(*) from public.partner_requests) > 0, 'operations reads referrals (intake)');
select throws_ok($$ select phone from public.cases limit 1 $$, '42501', null, 'operations cannot read phone numbers');
select lives_ok($$ select id, first_name, last_name, region, status, urgency, care_needs, assigned_team_id from public.cases limit 1 $$,
  'operations reads the case summary columns the Operations view uses');
reset role;

-- Other organisation -----------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.cases where organization_id = '00000000-0000-4000-b000-000000000011'), 0,
  'org-B admin reads no org-A case');
select is((select count(*)::int from public.partner_requests where organization_id = '00000000-0000-4000-b000-000000000011'), 0,
  'org-B admin reads no org-A referral');
reset role;

-- Policy hygiene -----------------------------------------------------------------------
select is(
  (select count(*)::int from pg_policies where schemaname = 'public' and policyname = 'org_members_read'
     and tablename in ('cases', 'care_visits', 'care_notes', 'quality_events', 'partner_requests', 'matching_requests', 'match_candidates')),
  0, 'no organisation-wide read policy is left on the legacy clinical tables');
select ok(not has_column_privilege('authenticated', 'public.cases', 'diagnosis_tags', 'select'),
  'authenticated holds no SELECT on diagnosis tags');

select * from finish();
rollback;
