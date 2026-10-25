-- DST1: safety alerts are on time on the nights the clock changes. ADR-081. Engineering fix; no threshold, priority,
-- receiver or step changes (thresholds stay PROVISIONAL, D-28; routes stay SIG1/SIG2).
--
-- Root cause (IMPLEMENTED in the code before this migration, verified on PostgreSQL 16 and documented behaviour of 17):
--   every function turns a Zurich local date and time into an instant with `<timestamp> at time zone 'Europe/Zurich'`.
--   PostgreSQL resolves an ambiguous local time (the repeated hour 02:00-02:59 on the autumn night) to the LATER
--   instant (CET): 2026-10-25 02:30 → 01:30 UTC, not 00:30 UTC. A visit planned at 02:30 that nobody starts was
--   therefore raised overdue (CSR1, CR-038) and escalated to P1 (SIG1) one hour late. A local time that does not exist
--   (spring night 2027-03-28 02:00-02:59) is read in standard time: 02:30 → 01:30 UTC (= 03:30 CEST).
--
-- Now (IMPLEMENTED):
--   1. `private.at_zurich(timestamp) → timestamptz`: one conversion rule for local → instant.
--      * ambiguous local time → the EARLIER instant (CEST);                                         DST1-2
--      * non-existent local time → standard-time reading (CET), i.e. what PostgreSQL does; never later than CET. DST1-3
--      * every other local time → unchanged.
--      `private.at_zurich(timestamptz) → timestamp` is the plain reverse (instant → Zurich wall clock), unchanged.
--   2. Every function in `public` and `private` (extension functions excluded) is re-created from its own current
--      definition with each `<operand> at time zone 'Europe/Zurich'` replaced by `private.at_zurich(<operand>)`
--      (the overload keeps the direction), and each `now()` replaced by `private.now()`. Signatures, owners, grants,
--      security and search_path are unchanged (CREATE OR REPLACE of pg_get_functiondef), as in ADR-068 / 0055.
--      Column defaults `now()` in public/private tables become `private.now()`.
--   3. `private.now()`: the database clock. It returns now() unless BOTH the session setting `navora.test_now` is set
--      AND the private table `private.test_clock` holds an enabled row. That row is written only by `supabase/seed.sql`
--      (local and CI; `supabase db push` never runs the seed), so on staging and production `private.now()` is now().
--      The table has RLS on and no grants: no API role can read or write it. Purpose: pgTAP runs at a pinned clock
--      (DST1-1, DST1-4).
--   The migration fails if any function body still holds a bare now() or a native Zurich conversion.
--   Idempotent: a second run finds nothing to replace.
-- Guard: pgTAP 068 fails when a later migration brings `now()` or `at time zone 'Europe/Zurich'` back into a body.

-- 1. Conversion rule ---------------------------------------------------------------------------------------------------
create or replace function private.at_zurich(p_local timestamp)
returns timestamptz
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
           when ((p_local at time zone 'Europe/Zurich') - interval '1 hour') at time zone 'Europe/Zurich' = p_local
             then (p_local at time zone 'Europe/Zurich') - interval '1 hour'
           else p_local at time zone 'Europe/Zurich'
         end
$$;
comment on function private.at_zurich(timestamp) is
  'DST1 / ADR-081: Zurich local date and time → instant. Ambiguous (autumn repeated hour) → the earlier instant (CEST); '
  'non-existent (spring gap) → read in standard time (CET); otherwise unchanged.';

create or replace function private.at_zurich(p_instant timestamptz)
returns timestamp
language sql
immutable
parallel safe
set search_path = ''
as $$ select p_instant at time zone 'Europe/Zurich' $$;
comment on function private.at_zurich(timestamptz) is
  'DST1 / ADR-081: instant → Zurich wall clock (unchanged reverse of at_zurich(timestamp)).';

-- 2. Test clock ----------------------------------------------------------------------------------------------------------
create table if not exists private.test_clock (
  enabled boolean primary key default true check (enabled)
);
alter table private.test_clock enable row level security;
revoke all on private.test_clock from public, anon, authenticated, service_role;
comment on table private.test_clock is
  'DST1 / ADR-081: one row only in local and CI databases (written by supabase/seed.sql). Without it, '
  'private.now() ignores navora.test_now. Never seeded on staging or production.';

create or replace function private.now()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when nullif(pg_catalog.current_setting('navora.test_now', true), '') is not null
                and exists (select 1 from private.test_clock t where t.enabled)
             then pg_catalog.current_setting('navora.test_now', true)::timestamptz
           else pg_catalog.now()
         end
$$;
comment on function private.now() is
  'DST1 / ADR-081: the database clock. now(), unless navora.test_now is set in a database that holds the test-clock row '
  '(local and CI only).';
revoke all on function private.now() from public;
grant execute on function private.now() to anon, authenticated, service_role;
grant execute on function private.at_zurich(timestamp) to anon, authenticated, service_role;
grant execute on function private.at_zurich(timestamptz) to anon, authenticated, service_role;

-- 3. Re-create every affected function ----------------------------------------------------------------------------------
-- Wraps the operand of each `<operand> at time zone 'Europe/Zurich'` (also inside dynamic SQL strings, where the quotes
-- are doubled or backslash-escaped). The operand is what AT TIME ZONE binds: an identifier chain with casts, or a
-- parenthesised group with an optional function name before it. Anything else (a string literal) aborts the migration.
create function pg_temp.dst1_wrap(src text) returns text language plpgsql as $f$
declare
  re    constant text := '\s+at\s+time\s+zone\s+(\\?''{1,2})Europe/Zurich\1';
  done  text := '';
  rest  text := src;
  pos   int;
  mt    text;
  head  text;
  i     int;
  depth int;
  c     text;
begin
  loop
    pos := regexp_instr(rest, re, 1, 1, 0, 'i');
    exit when pos = 0;
    mt   := regexp_substr(rest, re, 1, 1, 'i');
    head := done || substr(rest, 1, pos - 1);   -- earlier, already wrapped text included (nested conversions)
    i    := length(head);
    loop
      while i >= 1 and substr(head, i, 1) ~ '[A-Za-z0-9_.:"]' loop
        i := i - 1;
      end loop;
      exit when i < 1 or substr(head, i, 1) <> ')';
      depth := 0;
      loop
        c := substr(head, i, 1);
        if c = ')' then depth := depth + 1; elsif c = '(' then depth := depth - 1; end if;
        i := i - 1;
        exit when depth = 0;
        if i < 1 then
          raise exception 'DST1: unbalanced parentheses before AT TIME ZONE: %', right(head, 120);
        end if;
      end loop;
    end loop;
    if i + 1 > length(head) or (i >= 1 and substr(head, i, 1) in ('''', '\')) then
      raise exception 'DST1: unsupported operand before AT TIME ZONE: %', right(head, 120);
    end if;
    done := substr(head, 1, i) || 'private.at_zurich(' || substr(head, i + 1) || ')';
    rest := substr(rest, pos + length(mt));
  end loop;
  return done || rest;
end;
$f$;

do $$
declare
  r   record;
  def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prokind = 'f'
      and p.oid not in ('private.at_zurich(timestamp)'::regprocedure, 'private.at_zurich(timestamptz)'::regprocedure,
                        'private.now()'::regprocedure)
      and (p.prosrc ~* 'at\s+time\s+zone\s+\\?''{1,2}Europe/Zurich' or p.prosrc ~ '(^|[^.\w])now\(\)')
      and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    def := pg_get_functiondef(r.oid);
    def := pg_temp.dst1_wrap(def);
    def := regexp_replace(def, '(^|[^.\w])now\(\)', '\1private.now()', 'g');
    execute def;
  end loop;

  for r in
    select n.nspname, c.relname, a.attname, pg_get_expr(d.adbin, d.adrelid) as expr
    from pg_attrdef d
    join pg_class c on c.oid = d.adrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
    where n.nspname in ('public', 'private')
      and pg_get_expr(d.adbin, d.adrelid) ~ '(^|[^.\w])now\(\)'
  loop
    execute format('alter table %I.%I alter column %I set default %s', r.nspname, r.relname, r.attname,
                   regexp_replace(r.expr, '(^|[^.\w])now\(\)', '\1private.now()', 'g'));
  end loop;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.oid not in ('private.at_zurich(timestamp)'::regprocedure, 'private.at_zurich(timestamptz)'::regprocedure,
                        'private.now()'::regprocedure)
      and (p.prosrc ~* 'at\s+time\s+zone\s+\\?''{1,2}Europe/Zurich' or p.prosrc ~ '(^|[^.\w])now\(\)')
      and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  ) then
    raise exception 'ADR-081: a function body in public/private still uses now() or a native Zurich conversion';
  end if;
  if exists (
    select 1 from pg_attrdef d join pg_class c on c.oid = d.adrelid join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private') and pg_get_expr(d.adbin, d.adrelid) ~ '(^|[^.\w])now\(\)'
  ) then
    raise exception 'ADR-081: a column default in public/private still uses now()';
  end if;
end;
$$;

drop function pg_temp.dst1_wrap(text);
