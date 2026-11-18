-- BK-e1c (brief `docs/agents/briefs/BK.md` §PO amendment 2026-11-18 17:39, fixed list C1–C3; R3b, UXR-248, CGR-257;
-- `eng` design 2026-11-18 17:15). Red first (FE-071 (2)): pushed alone, before migration 0149, where `field_visits` and
-- `field_safety_alerts` filter `visit_date = p_date` only.
--
-- What it guards:
--   * C1: on day 2 the carer's `field_visits(day 2)` returns the running (started or paused) night visit of day 1
--     (`time_end < time_start`, the repository's «crosses midnight» rule, 0038/0048/0069/0071) with
--     `carried_from_previous_day = true`, before the visits of day 2. Day 1 still lists it (flag false).
--   * C2: `field_safety_alerts(day 2)` returns the client's alert rows for that visit too (same predicate).
--   * C3: not pulled forward: a day-1 night visit that is completed, planned or cancelled, a started day visit of day 1,
--     and a night visit two days back. PROPOSED (`cra` decides at the gate, `eng` 17:15 question 3): a night visit
--     `on_the_way` (travel recorded, not started) is not pulled forward.
--   * Scope unchanged: a user of another organisation reads none of it.
-- Display only: no rule about starting, completing, covering or billing changes. Synthetic data only; rolled back.
--
-- Users (supabase/seed.sql): nurse …902 (registered nurse, Testteam Nord …101, org A …011) · admin …903 (org B).
-- Case …208 (Nord). Days far ahead of the seed (today + 40 / + 41), so no seed visit interferes.
begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1490000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.d1() returns date language sql stable as $$
  select (private.now() at time zone 'Europe/Zurich')::date + 40 $$;
create function pg_temp.d2() returns date language sql stable as $$ select pg_temp.d1() + 1 $$;
-- Run `p_sql` as `p_user` through `authenticated` (RLS and grants apply) and return its single value as text.
create function pg_temp.as_user(p_user uuid, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.rn() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-000000000902'::uuid $$;
create function pg_temp.foreign_admin() returns uuid language sql immutable as $$
  select '00000000-0000-4000-a000-000000000903'::uuid $$;
-- The visit ids `p_user` reads from field_visits(p_day), in the function's order, as one text.
create function pg_temp.fv_ids(p_user uuid, p_day date) returns text language sql as $$
  select pg_temp.as_user(p_user, format(
    $q$ select coalesce(string_agg(x.visit_id::text, ',' order by x.ord), '') from public.field_visits(%L) with ordinality x $q$,
    p_day))
$$;
-- The carried flag of visit n in field_visits(p_day), read through jsonb so this file compiles before migration 0149.
create function pg_temp.carried(p_day date, n int) returns text language sql as $$
  select pg_temp.as_user(pg_temp.rn(), format(
    $q$ select coalesce(to_jsonb(x) ->> 'carried_from_previous_day', 'absent') from public.field_visits(%L) x
        where x.visit_id = %L $q$, p_day, pg_temp.v(n)))
$$;
-- How many alert rows `p_user` reads from field_safety_alerts(p_day) for the given visits.
create function pg_temp.alerts(p_user uuid, p_day date, p_visits int[]) returns int language sql as $$
  select pg_temp.as_user(p_user, format(
    $q$ select count(*) from public.field_safety_alerts(%L) where visit_id = any(%L::uuid[]) $q$,
    p_day, (select array_agg(pg_temp.v(n)) from unnest(p_visits) n)))::int
$$;

-- Fixtures (as the table owner) ------------------------------------------------------------------------------------
-- v1 night started · v2 night paused · v3 night completed · v4 night planned · v5 night cancelled · v6 day visit started
-- (all day 1) · v7 night on_the_way (day 1) · v8 night started two days back (day 0) · v9 day 2 visit 06:00.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(x.n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.d1() + x.day_offset, x.ts::time, x.te::time, false, x.st
from (values (1, 0, '22:00', '07:00', 'started'), (2, 0, '22:30', '06:30', 'paused'), (3, 0, '21:00', '05:00', 'completed'),
             (4, 0, '23:00', '06:00', 'planned'), (5, 0, '22:00', '07:00', 'cancelled'), (6, 0, '08:00', '12:00', 'started'),
             (7, 0, '23:30', '07:30', 'on_the_way'), (8, -1, '22:00', '07:00', 'started'), (9, 1, '06:00', '06:30', 'planned'))
     as x(n, day_offset, ts, te, st);

-- Contract ----------------------------------------------------------------------------------------------------------
select has_function('private', 'field_day_includes', array['date', 'time without time zone', 'time without time zone', 'text', 'date'],
  'BK-e1c: one private predicate decides which visits a /field day lists (shared by field_visits and field_safety_alerts)');
select is((select prosecdef from pg_proc where oid = 'public.field_visits(date)'::regprocedure), false,
  'field_visits stays SECURITY INVOKER (RLS of the caller applies)');

-- C1 -----------------------------------------------------------------------------------------------------------------
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()) like '%' || pg_temp.v(1) || '%',
  'C1: on day 2 field_visits lists the started 22:00–07:00 night visit of day 1');
select is(pg_temp.carried(pg_temp.d2(), 1), 'true', 'C1: it carries carried_from_previous_day = true on day 2');
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()) like '%' || pg_temp.v(2) || '%',
  'C1: on day 2 field_visits lists the paused night visit of day 1');
select is(split_part(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()), ',', 1), pg_temp.v(1)::text,
  'C1: the carried night visit comes before the visits of day 2 (here before a day-2 visit at 06:00)');
select is(pg_temp.carried(pg_temp.d2(), 9), 'false', 'C1: a visit of day 2 itself is not marked as carried');
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d1()) like '%' || pg_temp.v(1) || '%',
  'C1: day 1 still lists the night visit');
select is(pg_temp.carried(pg_temp.d1(), 1), 'false', 'C1: on its own day the night visit is not marked as carried');

-- C3 -----------------------------------------------------------------------------------------------------------------
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()) not like '%' || pg_temp.v(3) || '%',
  'C3: a completed night visit of day 1 is not pulled forward');
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()) not like '%' || pg_temp.v(4) || '%',
  'C3: a planned (never started) night visit of day 1 is not pulled forward');
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()) not like '%' || pg_temp.v(5) || '%',
  'C3: a cancelled night visit of day 1 is not pulled forward');
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()) not like '%' || pg_temp.v(6) || '%',
  'C3: a started day visit of day 1 (08:00–12:00) is not pulled forward');
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d2()) not like '%' || pg_temp.v(7) || '%',
  'C3 (PROPOSED, cra decides): a night visit of day 1 that is on_the_way, not started, is not pulled forward');
select ok(pg_temp.fv_ids(pg_temp.rn(), pg_temp.d1() + 1) not like '%' || pg_temp.v(8) || '%',
  'C3: a started night visit two days back is not pulled forward to day 2');

-- C2 -----------------------------------------------------------------------------------------------------------------
select ok(pg_temp.alerts(pg_temp.rn(), pg_temp.d2(), array[1]) > 0,
  'C2: on day 2 field_safety_alerts returns the client''s alert rows of the carried started night visit');
select ok(pg_temp.alerts(pg_temp.rn(), pg_temp.d2(), array[2]) > 0,
  'C2: on day 2 field_safety_alerts returns the alert rows of the carried paused night visit');
select is(pg_temp.alerts(pg_temp.rn(), pg_temp.d2(), array[3, 4, 5, 6, 7, 8]), 0,
  'C2/C3: no alert rows for the visits that are not pulled forward');

-- Scope --------------------------------------------------------------------------------------------------------------
select ok(pg_temp.fv_ids(pg_temp.foreign_admin(), pg_temp.d2()) not like '%' || pg_temp.v(1) || '%',
  'scope: a user of another organisation does not read the carried visit');
select is(pg_temp.alerts(pg_temp.foreign_admin(), pg_temp.d2(), array[1, 2]), 0,
  'scope: a user of another organisation reads no alert rows of the carried visits');

select * from finish();
rollback;
