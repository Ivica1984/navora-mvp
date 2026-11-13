-- B1.1-1b (CGR-201; brief `docs/agents/briefs/B1.1.md` §PO 06:39 point 2 and §PO 08:39 point 1; ADR-187).
--
-- Written BEFORE the migration (red first, task rule 3 and PO 06:39 point 3): on `recovery/main` `5518c1d` this file
-- fails at tests 1-2 (no share lock in the trigger) and then at its first read of `mapped_region_name` (the column
-- does not exist yet). Migration 20261021000128 turns it green.
--
-- What it guards (single session, deterministic; the two-session race itself is scripts/db-concurrency/region-map-race.sh):
--   * the insert path of the trigger and the owner path take a share lock on the legacy row before reading the mapping;
--   * a row that carries a mapped legacy text (fixture: written with triggers off, as a lost race would leave it) is
--     listed under «Region nicht zugeordnet» with its counts and the region it is mapped to;
--   * «Zuordnen» on it accepts only that region, rewrites the remaining rows and writes one more audit row (from, to);
--   * a non-listed text in use without any legacy row is listed and can be mapped;
--   * role checks unchanged (a coach sees nothing).
-- Users: Operations …904, coach …901 (org A …011). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.k(n integer) returns uuid language sql as $$
  select ('b1130000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
grant execute on function pg_temp.k(integer) to authenticated, anon;

create temp table ids as
  select (select id from public.regions where organization_id = '00000000-0000-4000-b000-000000000011' and name = 'Basel-Stadt') as bs,
         (select id from public.regions where organization_id = '00000000-0000-4000-b000-000000000011' and name = 'Basel-Landschaft') as bl,
         (select id from public.cases where organization_id = '00000000-0000-4000-b000-000000000011' order by id limit 1) as case1,
         (select id from public.cases where organization_id = '00000000-0000-4000-b000-000000000011' order by id offset 1 limit 1) as case2;
grant select on ids to authenticated, anon;

-- 1-2 The lock (structure; the behaviour is proven by the two-session script in the `db` job) ---------------------
select ok((select prosrc from pg_proc where oid = 'private.region_from_list()'::regprocedure) ~* 'for share',
          'the insert path of region_from_list takes a share lock on the legacy row (CGR-201)');
select ok((select prosrc from pg_proc where oid = 'private.register_legacy_region(uuid, text)'::regprocedure) ~* 'for share',
          'register_legacy_region takes the same share lock before reading the mapping');

-- 3 Fixture: map «Bern West» as Operations, then leave one team and one case on the old text (a lost race), and one case
-- on a text that has no legacy row at all. Triggers are off only for these three fixture writes.
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select bs from ids), pg_temp.k(1)),
  'ok', 'fixture: Operations maps «Bern West» to Basel-Stadt');
reset role;
set local session_replication_role = replica;
update public.teams set region = 'Bern West' where id = '00000000-0000-4000-a000-000000000101';
update public.cases set region = 'Bern West' where id = (select case1 from ids);
update public.cases set region = 'Ohne Eintrag B133' where id = (select case2 from ids);
set local session_replication_role = origin;

-- 4-6 Listed with counts and the mapped region ---------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok(exists (select 1 from public.unmapped_regions('00000000-0000-4000-b000-000000000011') u
                  where u.legacy_value = 'Bern West' and u.teams >= 1 and u.cases >= 1
                    and u.mapped_region_id = (select bs from ids) and u.mapped_region_name = 'Basel-Stadt'),
          'a mapped value with rows still on its text is listed with its counts and the region it is mapped to');
select ok(exists (select 1 from public.unmapped_regions('00000000-0000-4000-b000-000000000011') u
                  where u.legacy_value = 'Ohne Eintrag B133' and u.cases = 1 and u.mapped_region_id is null),
          'a non-listed text in use without a legacy row is listed with its count, as unmapped');
select ok(not exists (select 1 from public.unmapped_regions('00000000-0000-4000-b000-000000000011') u
                      where u.legacy_value in ('Basel-Stadt', 'Basel-Landschaft')),
          'list names are never listed');

-- 7-12 «Zuordnen» on the stray rows ----------------------------------------------------------------------------------
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select bl from ids), pg_temp.k(2)),
  'already_mapped', 'another region than the one already chosen is refused (a re-map is CGR-202 (a))');
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select bs from ids), pg_temp.k(3)),
  'ok', 'the region already chosen rewrites the remaining rows');
select ok(not exists (select 1 from public.unmapped_regions('00000000-0000-4000-b000-000000000011') u
                      where u.legacy_value = 'Bern West'),
          'afterwards «Bern West» is no longer listed');
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Bern West', (select bs from ids), pg_temp.k(4)),
  'already_mapped', 'with nothing left on the text there is nothing to rewrite');
reset role;
select is((select region from public.teams where id = '00000000-0000-4000-a000-000000000101')
          || ' / ' || (select region from public.cases where id = (select case1 from ids)),
          'Basel-Stadt / Basel-Stadt', 'the stray team and case now carry Basel-Stadt');
select is((select count(*)::int from public.audit_events a
           where a.organization_id = '00000000-0000-4000-b000-000000000011' and a.table_name = 'region_legacy_values'
             and a.changed ->> 'from' = 'Bern West' and a.changed ->> 'to' = 'Basel-Stadt'
             and a.actor_id = '00000000-0000-4000-a000-000000000904' and a.occurred_at is not null
             and (select array_agg(k order by k) from jsonb_object_keys(a.changed) k) = array['from', 'to']),
          2, 'the first mapping and the rewrite of the stray rows each wrote one audit row with from and to only');

-- 13-15 A text without a legacy row --------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Ohne Eintrag B133', (select bl from ids), pg_temp.k(5)),
  'ok', 'a text in use without a legacy row is registered and mapped');
select is(public.map_legacy_region('00000000-0000-4000-b000-000000000011', 'Nirgends B133', (select bl from ids), pg_temp.k(6)),
  'not_found', 'a text that is neither a legacy value nor in use is not found');
reset role;
select is((select c.region || ' / ' || l.mapping_kind from public.cases c
           join public.region_legacy_values l on l.organization_id = c.organization_id and l.legacy_value = 'Ohne Eintrag B133'
           where c.id = (select case2 from ids)),
          'Basel-Landschaft / manual', 'the case carries Basel-Landschaft and the legacy row is mapped by hand');

-- 16 Roles unchanged -----------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.unmapped_regions('00000000-0000-4000-b000-000000000011')), 0,
          'a coach still sees nothing');
reset role;

select * from finish();
rollback;
