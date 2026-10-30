-- CGR-96 (`cra` 2026-10-29 21:30 and 23:10; issue #693; ADR-127): e2e `vis1.spec.ts` saw two /field cards named
-- "<slot>, Testfall 08" after one "Heute machen". This file reproduces the situation in the database, deterministically:
-- the client already has a visit today in the slot the move lands on (as `ux1.spec` 20:45–21:15 or `vis1-10.spec`
-- 22:40–23:10 leave one in an evening e2e run), and the nurse moves a future visit of the same client into that slot.
-- It names the rows behind the two cards and shows that one move never yields two visits:
--   * the move updates the moved visit in place (same id), adds no care_visits row, and leaves the other visit as it was;
--   * the slot then holds two different ids (the pre-existing visit and the moved one), each once in `field_visits`;
--   * the moved visit is gone from its old day; a repeated command with the same key is a `duplicate` and adds nothing;
--   * one `moved` plan-change row, for the moved visit only.
-- Negative: no migration; this file only reads and calls existing commands (VIS1 0093, VIS2 0098).
-- Users (supabase/seed.sql): nurse …902 (Testteam Nord …101). Case …208 (Testfall 08, Nord). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(13);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  private.at_zurich(((private.at_zurich(private.now()))::date + time '10:00')::timestamp)::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.v(n integer) returns uuid language sql as $$
  select ('00000000-0000-4000-a102-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql as $$
  select ('a1020000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;

-- Fixtures (as the table owner), case …208, team Nord, responsible …902:
--   v(1) today 20:45–21:15 (the visit an earlier spec planned at a fixed slot);
--   v(2) 45 days ahead 22:00–22:30 (the visit vis1.spec plans and then moves to today).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, responsible_user_id)
values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', pg_temp.today(), time '20:45', time '21:15', false, 'planned', 30, 0,
   '00000000-0000-4000-a000-000000000902'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', pg_temp.today() + 45, time '22:00', time '22:30', false, 'planned', 30, 0,
   '00000000-0000-4000-a000-000000000902');

create temp table cgr96_before on commit drop as
  select count(*)::int as visits from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208';

-- The move ("Heute machen") into the occupied slot, as the nurse -------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.move_visit_to_today(pg_temp.v(2), pg_temp.today(), time '20:45', time '21:15',
                                     'Synthetisch: Klientin bittet um heute', pg_temp.k(1), false) ->> 'result',
  'ok', 'CGR-96: the move into a slot the client already has today is saved (VIS2: an overlap is a fact, not a refusal)');
select is((select array_agg(visit_id order by visit_id) from public.field_visits(pg_temp.today())
           where visit_id in (pg_temp.v(1), pg_temp.v(2))),
  array[pg_temp.v(1), pg_temp.v(2)],
  'CGR-96: today''s /field read returns both visits of the slot, two different ids');
select is((select count(*)::int from public.field_visits(pg_temp.today()))
          - (select count(distinct visit_id)::int from public.field_visits(pg_temp.today())), 0,
  'CGR-96: no visit id is returned twice by today''s /field read');
select is((select count(*)::int from public.field_visits(pg_temp.today() + 45) where visit_id = pg_temp.v(2)), 0,
  'CGR-96: the moved visit is no longer on its old day');
-- A repeat of the same command (same idempotency key) adds nothing.
select is(public.move_visit_to_today(pg_temp.v(2), pg_temp.today(), time '20:45', time '21:15',
                                     'Synthetisch: Klientin bittet um heute', pg_temp.k(1), false) ->> 'result',
  'duplicate', 'CGR-96: the same move sent twice is a duplicate');
reset role;

-- The rows behind the two cards (as the table owner) ------------------------------------------------------------------
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'),
  (select visits from cgr96_before), 'CGR-96: the move adds no care_visits row (one move never yields two visits)');
select is((select array_agg(id order by id) from public.care_visits
           where case_id = '00000000-0000-4000-a000-000000000208' and visit_date = pg_temp.today()
             and time_start = time '20:45' and time_end = time '21:15'),
  array[pg_temp.v(1), pg_temp.v(2)],
  'CGR-96: the slot holds exactly two rows: the visit planned there before and the moved visit');
select is((select visit_date = pg_temp.today() and time_start = time '20:45' and status = 'planned'
           from public.care_visits where id = pg_temp.v(2)),
  true, 'CGR-96: the moved visit keeps its id and is stored today in the chosen slot, planned (not started)');
select is((select visit_date = pg_temp.today() and time_start = time '20:45' and time_end = time '21:15' and status = 'planned'
           from public.care_visits where id = pg_temp.v(1)),
  true, 'CGR-96: the visit already in the slot is unchanged');
select is((select count(*)::int from public.care_visits where id = pg_temp.v(2)), 1,
  'CGR-96: the moved id exists once');
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.v(2) and change = 'moved'), 1,
  'CGR-96: one `moved` row for the moved visit (the repeat wrote none)');
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.v(1)), 0,
  'CGR-96: no plan change is written for the visit already in the slot');
select is((select count(*)::int from public.care_visits
           where case_id = '00000000-0000-4000-a000-000000000208' and visit_date = pg_temp.today() + 45
             and time_start = time '22:00'), 0,
  'CGR-96: nothing is left behind on the old day');

select * from finish();
rollback;
