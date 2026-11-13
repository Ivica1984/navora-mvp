-- B1.1-1c (founder decision FE-073; brief `docs/agents/briefs/B1.1.md` §PO 11:25 point 2; ADR-189).
--
-- Written BEFORE the seed change (red first, own commit): against the seed of the #1184 head `f27d6e2` tests 1-4 are
-- expected to fail (that seed writes «Bern West», «Bern Ost», «Zürich Pilot», «Basel Pilot») and 5-6 too (no postcode).
--
-- What it guards, on the database after `supabase db reset` (migrations + supabase/seed.sql), before any other file:
--   * every region on teams, cases, referrals and team searches is a listed region of its own organisation;
--   * the seed registers no legacy region value (pgTAP 132/133, the race scripts and the e2e specs write their own);
--   * every seeded case carries the postcode of its region (4052 Basel for Basel-Stadt, 4410 Liestal for
--     Basel-Landschaft) and no street address;
--   * organisation isolation keeps its shape: org B is on the same list region as org A on purpose (seed T9).
-- Synthetic data only. Other pgTAP files roll back, so the order of files does not change these counts.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

create temp table region_rows as
  select 'teams' as t, organization_id, region from public.teams
  union all select 'cases', organization_id, region from public.cases
  union all select 'partner_requests', organization_id, region from public.partner_requests
  union all select 'matching_requests', organization_id, region from public.matching_requests;

-- 1-4 Only list regions, no legacy value -----------------------------------------------------------------------------
select is((select count(*)::int from region_rows where region is null), 0, 'every seeded row names a region');
select is((select count(*)::int from region_rows x
           where not exists (select 1 from public.regions r
                             where r.organization_id = x.organization_id and r.name = x.region and r.active)), 0,
          'every seeded region is a listed region of its own organisation (Basel-Stadt or Basel-Landschaft, FE-019)');
select is((select count(*)::int from public.region_legacy_values), 0, 'the seed registers no legacy region value');
select is((select count(*)::int from region_rows
           where region in ('Bern West', 'Bern Ost', 'Zürich Pilot', 'Basel Pilot')), 0,
          'none of the pre-B1.1-1c seed names is left');

-- 5-7 Postcodes of the places of care --------------------------------------------------------------------------------
select is((select count(*)::int from public.cases where plz is null), 0, 'every seeded case carries a postcode');
select is((select count(*)::int from public.cases
           where not ((region = 'Basel-Stadt' and plz = '4052') or (region = 'Basel-Landschaft' and plz = '4410'))), 0,
          'the postcode is the one of the case region (4052 Basel-Stadt, 4410 Basel-Landschaft)');
select is((select count(*)::int from public.cases where address is not null or ort is not null), 0,
          'no street address or place name is seeded (data minimisation; the postcode is the only location field)');

-- 8 Isolation shape (seed T9) ----------------------------------------------------------------------------------------
select ok(exists (select 1 from public.teams a join public.teams b on a.region = b.region
                  where a.organization_id = '00000000-0000-4000-b000-000000000011'
                    and b.organization_id = '00000000-0000-4000-b000-000000000012'),
          'org B shares a list region with org A on purpose: isolation comes from the organisation, not the region');

select * from finish();
rollback;
