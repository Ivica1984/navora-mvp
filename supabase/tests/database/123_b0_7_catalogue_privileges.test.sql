begin;
-- B0-7 (PRODUCT_BLOCKS.md §4, ADR-176): database privileges, checked in the catalogue after ALL migrations.
-- Objects that belong to an extension (pg_depend deptype 'e', e.g. pgTAP itself) are not NAVORA objects and are skipped.
-- Each check lists the offending objects by name, so a red run names what broke the rule (empty string = green).
-- No object list is kept by hand: a new table, function, sequence or view is checked the moment a migration adds it.
-- B0-7 covered schemas: public, private
-- (the schemas the NAVORA migrations own; `extensions`, `auth` and the other Supabase schemas are managed by Supabase.
--  tests/unit/b0-7-catalogue.test.ts fails when a migration creates a schema that is not in this list.)
-- "anon grant" means (ADR-176): an ACL entry naming `anon` on a relation, function or schema, a default privilege of
-- the migration role that would give `anon` a future object, or `anon` USAGE on `private`. A PUBLIC grant on an
-- ordinary (SECURITY INVOKER) function in `private` is not one, because `anon` cannot reach `private` (B0-7-4).
select plan(9);

-- Not vacuous: the catalogue holds the objects the rules are about.
select ok((select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = any (array['public', 'private']) and c.relkind in ('r', 'p')) > 50
          and (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = any (array['public', 'private']) and p.prosecdef) > 100,
  'B0-7-0: the covered schemas hold the migrated tables and SECURITY DEFINER functions');

-- 1. No table without RLS (public and private, partitioned tables included).
select is((select coalesce(string_agg(n.nspname || '.' || c.relname, ', ' order by n.nspname, c.relname), '')
           from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = any (array['public', 'private']) and c.relkind in ('r', 'p') and not c.relrowsecurity
             and not exists (select 1 from pg_depend dp where dp.classid = 'pg_class'::regclass and dp.objid = c.oid and dp.deptype = 'e')),
  '', 'B0-7-1: every table in public and private has row level security on');

-- 2. No anon grant on a relation (table, view, materialised view, sequence, foreign table).
select is((select coalesce(string_agg(distinct n.nspname || '.' || c.relname || ' (' || a.privilege_type || ')', ', '), '')
           from pg_class c join pg_namespace n on n.oid = c.relnamespace, aclexplode(c.relacl) a
           where n.nspname = any (array['public', 'private']) and c.relkind in ('r', 'p', 'v', 'm', 'S', 'f')
             and a.grantee = 'anon'::regrole
             and not exists (select 1 from pg_depend dp where dp.classid = 'pg_class'::regclass and dp.objid = c.oid and dp.deptype = 'e')),
  '', 'B0-7-2: anon holds no privilege on any table, view or sequence');

-- 3. No anon grant on a function.
select is((select coalesce(string_agg(distinct p.oid::regprocedure::text, ', '), '')
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace, aclexplode(p.proacl) a
           where n.nspname = any (array['public', 'private']) and a.grantee = 'anon'::regrole
             and not exists (select 1 from pg_depend dp where dp.classid = 'pg_proc'::regclass and dp.objid = p.oid and dp.deptype = 'e')),
  '', 'B0-7-3: no function grants EXECUTE to anon');
select is((select coalesce(string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text), '')
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')
             and not exists (select 1 from pg_depend dp where dp.classid = 'pg_proc'::regclass and dp.objid = p.oid and dp.deptype = 'e')),
  '', 'B0-7-3b: anon can execute no function in public (no PUBLIC grant either)');

-- 4. anon cannot reach private at all.
select ok(not has_schema_privilege('anon', 'private', 'usage') and not has_schema_privilege('anon', 'private', 'create')
          and not has_schema_privilege('anon', 'public', 'create'),
  'B0-7-4: anon has no USAGE on private and may create nothing');

-- 5. No default privilege of the migration role gives a future object to anon.
select is((select coalesce(string_agg(distinct coalesce(n.nspname, '(all)') || ':' || d.defaclobjtype::text || ' ' || a.privilege_type, ', '), '')
           from pg_default_acl d left join pg_namespace n on n.oid = d.defaclnamespace, aclexplode(d.defaclacl) a
           where d.defaclrole = current_user::regrole and (n.nspname is null or n.nspname = any (array['public', 'private']))
             and a.grantee = 'anon'::regrole),
  '', 'B0-7-5: no default privilege (pg_default_acl) of the migration role gives anon a future object');

-- 6. Every SECURITY DEFINER function pins search_path to the empty string (extension members excluded).
select is((select coalesce(string_agg(p.oid::regprocedure::text || ' ' || coalesce(array_to_string(p.proconfig, ' '), '(none)'), ', '
                                      order by p.oid::regprocedure::text), '')
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = any (array['public', 'private']) and p.prosecdef
             and not coalesce('search_path=""' = any (p.proconfig), false)
             and not exists (select 1 from pg_depend dp where dp.classid = 'pg_proc'::regclass and dp.objid = p.oid and dp.deptype = 'e')),
  '', 'B0-7-6: every SECURITY DEFINER function has search_path = ''''');

-- 7. No SECURITY DEFINER function is executable by PUBLIC (a NULL ACL means the default, which grants PUBLIC).
select is((select coalesce(string_agg(distinct p.oid::regprocedure::text, ', '), '')
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
                aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
           where n.nspname = any (array['public', 'private']) and p.prosecdef
             and a.privilege_type = 'EXECUTE' and a.grantee = 0
             and not exists (select 1 from pg_depend dp where dp.classid = 'pg_proc'::regclass and dp.objid = p.oid and dp.deptype = 'e')),
  '', 'B0-7-7: EXECUTE on every SECURITY DEFINER function is revoked from PUBLIC');

select * from finish();
rollback;
