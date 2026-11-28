-- VIS1 / ADR-111 (6), `cra` CGR-89 and open question C-2 (b): does PLAN2 re-create a generated visit that the team
-- moved off its planned date (for example with "Heute machen", VIS1-3b)?
-- Answer pinned here (behaviour of 0025/0030 as patched, unchanged by VIS1): NO. A moved generated visit keeps its
-- plan slot (`plan_slot_date`, `plan_slot_start`), counts as touched (`moved` row) and is kept, so generation creates
-- nothing for the date it left. The planned date then has no visit for that slot. This test records the fact; it sets
-- no clinical rule (whether a gap needs a replacement is the Clinical Owner's question, CGR-89 (3)).
-- Users (supabase/seed.sql): nurse …902 (Testteam Nord …101, registered nurse). Case …208. Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
-- PLAN2 generation reads now() (not the test clock), so the dates here do too.
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.in_slot(d date) returns integer language sql as $$
  select count(*)::int from public.care_visits
  where case_id = '00000000-0000-4000-a000-000000000208' and visit_date = d and status <> 'cancelled'
    and time_start < '14:00' and coalesce(time_end, time_start + interval '1 minute') > '13:00' $$;
create function pg_temp.slot_visit(d date) returns uuid language sql as $$
  select id from public.care_visits
  where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated and plan_slot_date = d and plan_slot_start = '13:00' $$;

-- A daily 13:00-14:00 care-plan item (no seed visit of case …208 lies in that window). The insert trigger plans it.
insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by,
                                    freq_times, freq_period, freq_weekdays, window_start, window_end) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   'Körperpflege', 'A', 30, 'täglich', pg_temp.today() + 30, '00000000-0000-4000-a000-000000000902', 1, 'day', null, '13:00', '14:00');
select lives_ok($$ select private.generate_case_plan('00000000-0000-4000-a000-000000000208', '00000000-0000-0000-0000-000000000000') $$,
  'fixture: PLAN2 generation runs for the case');

select is(pg_temp.in_slot(pg_temp.today() + 1), 1, 'fixture: tomorrow has one generated visit in the 13:00 slot');

-- The team moves tomorrow's generated visit to today (the "Heute machen" route: the existing reschedule_visit).
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.slot_visit(pg_temp.today() + 1), pg_temp.today(), '13:00', '13:30',
          'Wunsch der Klientin', 'a8920000-0000-4000-8000-000000000001') ->> 'result', 'ok',
  'a member of the team moves the generated visit to today');
reset role;

select ok((select visit_date = pg_temp.today() and plan_slot_date = pg_temp.today() + 1
           from public.care_visits where id = pg_temp.slot_visit(pg_temp.today() + 1)),
  'the moved visit keeps its plan slot (tomorrow) and carries today''s date');
select ok(exists (select 1 from public.visit_plan_changes
                  where visit_id = pg_temp.slot_visit(pg_temp.today() + 1) and change = 'moved'),
  'the move is in the plan log (touched)');

-- Generation again: per case, and the daily job.
select private.generate_case_plan('00000000-0000-4000-a000-000000000208', '00000000-0000-0000-0000-000000000000');
select lives_ok($$ select private.generate_all_plans() $$, 'the daily job runs after the move');

select is(pg_temp.in_slot(pg_temp.today() + 1), 0,
  'C-2 (b): PLAN2 does not re-create a visit on the date the moved visit left (the slot stays empty)');
select is(pg_temp.in_slot(pg_temp.today() + 2), 1, 'the next day keeps its generated visit (only the moved slot is affected)');

select * from finish();
rollback;
