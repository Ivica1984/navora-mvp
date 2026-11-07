-- ADR-068 (migration 0055): the database has one calendar "today", Europe/Zurich. `current_date` follows the session
-- time zone (UTC), so it differs from the Zurich date between 00:00 and 02:00 Zurich time (summer). No function in
-- `public` or `private` may use it. Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(3);

select is(
  (select count(*)::int
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'private')
     and p.prosrc ~* '\mcurrent_date\M'
     and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')),
  0,
  'no function in public or private uses current_date (session time zone); today is the Europe/Zurich date');

select ok(
  -- ADR-081 (0067): the Zurich conversion is written private.at_zurich(...) since DST1.
  (select p.prosrc like '%private.at_zurich(private.now())%' from pg_proc p where p.oid = 'private.derived_exceptions(uuid)'::regprocedure),
  'OPS1 derived exceptions judge order expiry and review dates against the Zurich date');

-- A session in UTC just after midnight Zurich time: pause_case must refuse an expected end of the Zurich yesterday.
select ok(
  (select p.prosrc like '%p_expected_end < (private.at_zurich(private.now()))::date%'
   from pg_proc p where p.proname = 'pause_case' and p.pronamespace = 'public'::regnamespace),
  'pause_case compares the expected end with the Zurich date');

select * from finish();
rollback;
