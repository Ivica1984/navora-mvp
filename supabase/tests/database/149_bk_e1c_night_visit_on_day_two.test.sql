-- BK-e1c (migration 0149; brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 17:39, C1–C3; R3b, CGR-257, UXR-248;
-- ADR-203 amendment BK-e1c). Written red first: on `recovery/main` before 0149, C1 and C2 fail (no carried visit, no
-- flag, no alerts on day 2); the C3 controls pass before and after.
-- Users (supabase/seed.sql): nurse …902 (registered nurse, Testteam Nord …101) · admin …903 (org B). Case …208 (Nord).
-- «Day 2» is today (Europe/Zurich, private.now()); «day 1» is yesterday. Fixtures are written as the table owner; every
-- read goes through `authenticated`. All data synthetic.
begin;
create extension if not exists pgtap with schema extensions;

select plan(24);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'rn' then '00000000-0000-4000-a000-000000000902'
                 when 'admin_b' then '00000000-0000-4000-a000-000000000903' end)::uuid
$$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1490000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.as_user(p_user text, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.u(p_user)::text, true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
-- What `p_user` reads from field_visits(p_day) for visit n: 'carried flag' ('t'/'f'), or null when the row is absent.
create function pg_temp.fv(p_user text, p_day date, n int) returns text language sql as $$
  select pg_temp.as_user(p_user, format(
    $q$ select coalesce(carried_from_previous_day::text, '∅') from public.field_visits(%L) where visit_id = %L $q$, p_day, pg_temp.v(n)))
$$;
-- How many field_safety_alerts rows `p_user` reads on p_day for visit n.
create function pg_temp.fa(p_user text, p_day date, n int) returns int language sql as $$
  select pg_temp.as_user(p_user, format(
    $q$ select count(*) from public.field_safety_alerts(%L) where visit_id = %L $q$, p_day, pg_temp.v(n)))::int
$$;

-- Fixtures: Testteam Nord, case …208. All midnight-crossing visits run 22:00–07:00 unless named.
--  1 day 1, started             → carried (C1)
--  2 day 1, paused              → carried (C1)
--  3 day 1, completed on day 1  → not carried (C3)
--  4 day 1, planned             → not carried (C3)
--  5 day 1, cancelled           → not carried (C3)
--  6 day 1, started day visit 08:00–12:00 → not carried (C3)
--  7 day 1, on_the_way          → not carried (C3; PROPOSED, `cra` review question 3)
--  8 day 0 (two days back), started → not carried (only the day before)
--  9 day 1, completed on day 2  → carried (PROPOSED, review question 5: the card and its report stay on day 2)
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '22:00', '07:00', false, 'started'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '22:30', '06:30', false, 'paused'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '22:00', '07:00', false, 'completed'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(4), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '22:00', '07:00', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(5), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '22:00', '07:00', false, 'cancelled'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(6), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '08:00', '12:00', false, 'started'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(7), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '22:00', '07:00', false, 'on_the_way'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(8), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 2, '22:00', '07:00', false, 'started'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(9), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '22:00', '07:00', false, 'completed');
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, occurred_at, actor_id, command) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000101', 'completed', 'started', 'completed',
   ((pg_temp.today() - 1) + time '23:50') at time zone 'Europe/Zurich', pg_temp.u('rn'), 'complete_visit'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(9), '00000000-0000-4000-a000-000000000101', 'completed', 'started', 'completed',
   private.now(), pg_temp.u('rn'), 'complete_visit');

-- Contract ---------------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'private.field_day_carried(uuid, date, time, time, text, date)', 'execute'),
  'BK-e1c: anon cannot execute the predicate');
select is((select provolatile from pg_proc where oid = 'private.field_day_carried(uuid, date, time, time, text, date)'::regprocedure),
  's', 'BK-e1c: the predicate is stable and reads no clock (the date is its input)');
select is((select prosecdef from pg_proc where oid = 'public.field_visits(date)'::regprocedure), false,
  'BK-e1c: field_visits stays SECURITY INVOKER (RLS of the caller applies)');
select ok('carried_from_previous_day' = any((select proargnames from pg_proc where oid = 'public.field_visits(date)'::regprocedure)),
  'BK-e1c: field_visits returns carried_from_previous_day');

-- C1: the running night visit of day 1 is on day 2, flagged, first ----------------------------------------------------
select is(pg_temp.fv('rn', pg_temp.today(), 1), 'true', 'C1: a started 22:00–07:00 visit of day 1 is on day 2, carried');
select is(pg_temp.fv('rn', pg_temp.today(), 2), 'true', 'C1: a paused night visit of day 1 is on day 2, carried');
select is(pg_temp.fv('rn', pg_temp.today() - 1, 1), 'false', 'C1: on day 1 the same visit is there, not carried');
select is(pg_temp.fv('rn', pg_temp.today(), 501), null, 'fixture check: helper returns null for an absent visit');
select is(pg_temp.as_user('rn', format($q$ select string_agg(visit_id::text, ',') from (select visit_id from public.field_visits(%L) limit 2) x $q$, pg_temp.today())),
  pg_temp.v(1)::text || ',' || pg_temp.v(2)::text, 'C1 / UXR-248: carried visits come first in the list');
select is(pg_temp.as_user('rn', format($q$ select count(*) from public.field_visits(%L) where not carried_from_previous_day $q$, pg_temp.today()))::int,
  pg_temp.as_user('rn', format($q$ select count(*) from public.field_visits(%L) where visit_date = %L $q$, pg_temp.today(), pg_temp.today()))::int,
  'C1: every visit dated day 2 is still there, none flagged carried');
select is(pg_temp.fv('admin_b', pg_temp.today(), 1), null, 'C1: a user of another organisation does not see the carried visit');

-- C2: the client's safety alerts of that visit on day 2 ----------------------------------------------------------------
select ok(pg_temp.fa('rn', pg_temp.today(), 1) > 0, 'C2: field_safety_alerts(day 2) returns the alerts of the carried started visit');
select ok(pg_temp.fa('rn', pg_temp.today(), 2) > 0, 'C2: … and of the carried paused visit');
select is(pg_temp.fa('rn', pg_temp.today(), 1), pg_temp.fa('rn', pg_temp.today() - 1, 1),
  'C2: the same alert rows on day 2 as on day 1');
select is(pg_temp.fa('admin_b', pg_temp.today(), 1), 0, 'C2: another organisation reads no alerts of it');

-- C3: not pulled forward ------------------------------------------------------------------------------------------------
select is(pg_temp.fv('rn', pg_temp.today(), 3), null, 'C3: a night visit completed on day 1 is not on day 2');
select is(pg_temp.fv('rn', pg_temp.today(), 4), null, 'C3: a planned night visit of day 1 is not on day 2');
select is(pg_temp.fv('rn', pg_temp.today(), 5), null, 'C3: a cancelled night visit of day 1 is not on day 2');
select is(pg_temp.fv('rn', pg_temp.today(), 6), null, 'C3: a started day visit (08:00–12:00) of day 1 is not on day 2');
select is(pg_temp.fv('rn', pg_temp.today(), 7), null, 'C3 (PROPOSED, cra question 3): an on_the_way night visit of day 1 is not on day 2');
select is(pg_temp.fv('rn', pg_temp.today(), 8), null, 'C3: a started night visit of two days back is not on day 2');
select is(pg_temp.fa('rn', pg_temp.today(), 3) + pg_temp.fa('rn', pg_temp.today(), 4) + pg_temp.fa('rn', pg_temp.today(), 6), 0,
  'C2/C3: no alerts on day 2 for visits that are not carried (same predicate)');

-- PROPOSED (review question 5): completed on day 2 stays on day 2 ---------------------------------------------------------
select is(pg_temp.fv('rn', pg_temp.today(), 9), 'true',
  'PROPOSED: a night visit of day 1 completed on day 2 stays on day 2 (card and report do not vanish after «Abschliessen»)');
select is(pg_temp.fv('rn', pg_temp.today() + 1, 9), null, 'PROPOSED: … but not on day 3');

select * from finish();
rollback;
