-- B1.1-1 (a, Δ1) region list and legacy values (brief `docs/agents/briefs/B1.1.md`; ADR-186).
--
-- Written BEFORE the migration (red first, task rule 3): on `recovery/main` `0ea663a` this file fails at its first
-- statement that reads `public.regions` (the table does not exist yet). The migration that turns it green is PLANNED
-- (ADR-186), not part of the commit that adds this file.
--
-- What it guards:
--   * the list (Basel-Stadt, Basel-Landschaft; FE-019) exists for every organisation and nothing else is listed;
--   * the write path: a region outside the list cannot be entered by a signed-in user (referral, new team, changed
--     team region); an unchanged legacy region of a team stays (renaming a team does not force a mapping);
--   * no loss: every region value on teams, cases, referrals and team searches is either listed or a legacy value of
--     the same organisation; mapping by hand keeps the number of cases and open searches and keeps every
--     (open search, team) pair that matched before;
--   * «Region nicht zugeordnet»: Operations of the organisation sees its own unmapped values only; another
--     organisation, a coach and `anon` neither see nor map them; the mapping writes one audit row (who, when, from, to).
-- No new eligibility rule: region stays the only geographic criterion and the comparison stays a text comparison.
--
-- Users: Operations …904, admin …905, coach …901, nurse …902 (org A …011) · admin …903 (org B …012, also «Bern West»
-- on purpose, seed T9). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(35);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.k(n integer) returns uuid language sql as $$
  select ('b1110000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
grant execute on function pg_temp.k(integer) to authenticated, anon;

-- Snapshot of the region-bearing rows (as postgres, before any change) -------------------------------------------
create temp table region_rows as
  select 'teams' as t, organization_id, id, region from public.teams
  union all select 'cases', organization_id, id, region from public.cases
  union all select 'partner_requests', organization_id, id, region from public.partner_requests
  union all select 'matching_requests', organization_id, id, region from public.matching_requests;

-- (open search, active team) pairs that match today, by the unchanged text comparison.
create temp table pairs_before as
  select m.id as matching_request_id, t.id as team_id
  from public.matching_requests m
  join public.teams t on t.organization_id = m.organization_id and t.region = m.region and t.status = 'active'
  where m.status = 'open';

-- 1-4 The list ---------------------------------------------------------------------------------------------------
select has_table('public', 'regions', 'the region list is a table');
select has_table('public', 'region_legacy_values', 'legacy region values are kept in their own table');
select is((select array_agg(r.name order by r.sort_order) from public.regions r
           where r.organization_id = '00000000-0000-4000-b000-000000000011' and r.active),
          array['Basel-Stadt', 'Basel-Landschaft'], 'org A lists exactly Basel-Stadt and Basel-Landschaft (FE-019)');
select is((select count(*)::int from public.organizations o
           where (select count(*) from public.regions r where r.organization_id = o.id and r.active) <> 2), 0,
          'every organisation has the two list entries');

-- 5-7 No loss: every value is accounted for ------------------------------------------------------------------------
select is((select count(*)::int from (select distinct organization_id, region from region_rows where region is not null) v
           where not exists (select 1 from public.regions r where r.organization_id = v.organization_id and r.name = v.region)
             and not exists (select 1 from public.region_legacy_values l
                             where l.organization_id = v.organization_id and l.legacy_value = v.region)), 0,
          'every region value is either listed or a legacy value of the same organisation');
select ok(exists (select 1 from public.region_legacy_values l
                  where l.organization_id = '00000000-0000-4000-b000-000000000011' and l.legacy_value = 'Bern West'
                    and l.region_id is null),
          '«Bern West» (seed, FE-066 unchanged) is an unmapped legacy value of org A');
select ok(not exists (select 1 from public.region_legacy_values l where l.legacy_value in ('Basel-Stadt', 'Basel-Landschaft')),
          'a listed name is never a legacy value');

-- 8-13 Write path (signed-in users) -------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select throws_ok($$ select public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital B111', 'Spital',
       'Bern West', null, 'mittel', null, 'B1.1-1 Freitext', 'Synthetisch', array['Grundpflege'], pg_temp.k(1),
       'referrer_stated', null) $$,
  '22023', 'region_not_in_list', 'a referral with a legacy region (free text) is refused');
select throws_ok($$ select public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital B111', 'Spital',
       'Basel Stadt', null, 'mittel', null, 'B1.1-1 Tippfehler', 'Synthetisch', array['Grundpflege'], pg_temp.k(2),
       'referrer_stated', null) $$,
  '22023', 'region_not_in_list', 'a near miss of a list entry is refused, not silently corrected');
select is(public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital B111', 'Spital',
       'Basel-Stadt', null, 'mittel', null, 'B1.1-1 Liste', 'Synthetisch', array['Grundpflege'], pg_temp.k(3),
       'referrer_stated', null),
  'ok', 'a referral with a list region is recorded');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select throws_ok($$ select public.create_team('00000000-0000-4000-b000-000000000011', 'Testteam B111', 'Zürich Süd', pg_temp.k(4)) $$,
  '22023', 'region_not_in_list', 'a new team with a region outside the list is refused');
select is(public.create_team('00000000-0000-4000-b000-000000000011', 'Testteam B111', 'Basel-Landschaft', pg_temp.k(5)),
  'ok', 'a new team with a list region is created');
select is(public.update_team('00000000-0000-4000-a000-000000000101', 'Testteam Nord B111', 'Bern West', pg_temp.k(6)),
  'ok', 'renaming a team that keeps its unchanged legacy region works');
select throws_ok($$ select public.update_team('00000000-0000-4000-a000-000000000101', 'Testteam Nord B111', 'Bern Mitte', pg_temp.k(7)) $$,
  '22023', 'region_not_in_list', 'changing a team region to a value outside the list is refused');
reset role;

-- 13a-13d Write path (service key; PO 03:39 merge condition 7, ADR-186 amendment 04:30): `service_role` is an
-- application role (src/features/push/dispatch.ts signs in with it), not a migration or seed, so it is refused a
-- non-listed region in each of the four tables like a signed-in user (BYPASSRLS does not skip a trigger).
set local role service_role;
select throws_ok($$ update public.teams set region = 'Zürich Süd' where id = '00000000-0000-4000-a000-000000000101' $$,
  '22023', 'region_not_in_list', 'service_role cannot write a non-listed team region');
select throws_ok($$ update public.cases set region = 'Zürich Süd'
       where id = (select id from public.cases where organization_id = '00000000-0000-4000-b000-000000000011' order by id limit 1) $$,
  '22023', 'region_not_in_list', 'service_role cannot write a non-listed case region');
select throws_ok($$ update public.partner_requests set region = 'Zürich Süd'
       where id = (select id from public.partner_requests where organization_id = '00000000-0000-4000-b000-000000000011' order by id limit 1) $$,
  '22023', 'region_not_in_list', 'service_role cannot write a non-listed referral region');
select throws_ok($$ update public.matching_requests set region = 'Zürich Süd'
       where id = (select id from public.matching_requests where organization_id = '00000000-0000-4000-b000-000000000011' order by id limit 1) $$,
  '22023', 'region_not_in_list', 'service_role cannot write a non-listed team-search region');
reset role;

-- 14-18 «Region nicht zugeordnet» --------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok(exists (select 1 from public.unmapped_regions('00000000-0000-4000-b000-000000000011') u
                  where u.legacy_value = 'Bern West' and u.teams >= 1 and u.cases >= 1),
          'Operations sees «Bern West» with its teams and cases');
select ok(not exists (select 1 from public.unmapped_regions('00000000-0000-4000-b000-000000000011') u
                      where u.legacy_value in ('Basel-Stadt', 'Basel-Landschaft')),
          'listed regions are not in «Region nicht zugeordnet»');
select is((select count(*)::int from public.unmapped_regions('00000000-0000-4000-b000-000000000012')), 0,
          'Operations of org A does not see org B''s legacy values');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.unmapped_regions('00000000-0000-4000-b000-000000000011')), 0,
          'a coach does not see the list');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.unmapped_regions('00000000-0000-4000-b000-000000000011')), 0,
          'a team nurse does not see the list');
reset role;

-- 19-21 Mapping refused ----------------------------------------------------------------------------------------------
create temp table target as
  select r.id from public.regions r where r.organization_id = '00000000-0000-4000-b000-000000000011' and r.name = 'Basel-Stadt';
grant select on target to authenticated, anon;

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select id from target), pg_temp.k(10)),
  'rejected', 'a coach cannot map');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select id from target), pg_temp.k(11)),
  'rejected', 'the admin of another organisation cannot map');
reset role;
set local role anon;
select throws_ok($$ select public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West',
       (select id from target), pg_temp.k(12)) $$,
  '42501', null, 'anon cannot call the mapping');
reset role;

-- 22-31 Mapping by hand: no loss, audit, idempotent --------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select id from target), pg_temp.k(13)),
  'ok', 'Operations maps «Bern West» to Basel-Stadt');
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select id from target), pg_temp.k(13)),
  'duplicate', 'the same key is a duplicate');
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select id from target), pg_temp.k(14)),
  'already_mapped', 'a mapped value is not mapped twice');
select ok(not exists (select 1 from public.unmapped_regions('00000000-0000-4000-b000-000000000011') u where u.legacy_value = 'Bern West'),
  'after the mapping «Bern West» is no longer listed');
reset role;

select is((select count(*)::int from public.cases where organization_id = '00000000-0000-4000-b000-000000000011')
          + (select count(*)::int from public.matching_requests where organization_id = '00000000-0000-4000-b000-000000000011' and status = 'open'),
          (select count(*)::int from region_rows where t = 'cases' and organization_id = '00000000-0000-4000-b000-000000000011')
          + (select count(*)::int from public.matching_requests m join region_rows r on r.id = m.id
             where r.organization_id = '00000000-0000-4000-b000-000000000011' and m.status = 'open'),
          'the number of cases and open team searches of org A is unchanged by the mapping');
select is((select count(*)::int from pairs_before p
           where not exists (select 1 from public.matching_requests m
                             join public.teams t on t.organization_id = m.organization_id and t.region = m.region and t.status = 'active'
                             where m.id = p.matching_request_id and t.id = p.team_id and m.status = 'open')), 0,
          'every (open search, team) pair that matched before still matches');
select is((select count(*)::int from public.teams t join region_rows r on r.id = t.id
           where t.organization_id = '00000000-0000-4000-b000-000000000011' and r.region = 'Bern West' and t.region <> 'Basel-Stadt'), 0,
          'every org A team that said «Bern West» now says Basel-Stadt');
select is((select count(*)::int from (
             select organization_id, region from public.teams
             union all select organization_id, region from public.cases
             union all select organization_id, region from public.partner_requests
             union all select organization_id, region from public.matching_requests) n
           where n.organization_id = '00000000-0000-4000-b000-000000000012' and n.region = 'Bern West'),
          (select count(*)::int from region_rows r where r.organization_id = '00000000-0000-4000-b000-000000000012' and r.region = 'Bern West'),
          'org B''s «Bern West» rows are untouched');
select ok(exists (select 1 from public.audit_events a
                  where a.organization_id = '00000000-0000-4000-b000-000000000011' and a.table_name = 'region_legacy_values'
                    and a.actor_id = '00000000-0000-4000-a000-000000000904'
                    and a.changed ->> 'from' = 'Bern West' and a.changed ->> 'to' = 'Basel-Stadt' and a.occurred_at is not null),
          'the mapping wrote one audit row with who, when, from and to');

select * from finish();
rollback;
