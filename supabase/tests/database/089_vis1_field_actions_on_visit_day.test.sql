-- VIS1 (ADR-111, `cra` CGR-87): field actions happen on the visit's day.
-- VIS1-1: depart, start, no-show and "not completed" refuse a visit dated after today (Europe/Zurich) with not_today;
--         complete refuses a visit started before its date with started_before_date. Status unchanged, no visit event,
--         one audit row with the outcome.
-- VIS1-2: tomorrow refused; moved to today with reschedule_visit → ok; today and yesterday unchanged.
-- VIS1-6: past-dated visits keep today's behaviour; no tolerance before the date.
-- Users (supabase/seed.sql): nurse …902 (Testteam Nord …101, registered nurse) · coordinator …904 (org A, no team).
-- Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(41);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.v(n integer) returns uuid language sql as $$
  select ('00000000-0000-4000-a089-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql as $$
  select ('a8900000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.status(n integer) returns text language sql as $$
  select status from public.care_visits where id = pg_temp.v(n) $$;
create function pg_temp.events(n integer) returns integer language sql as $$
  select count(*)::int from public.visit_events where visit_id = pg_temp.v(n) $$;
create function pg_temp.refusals(n integer, p_command text) returns text language sql as $$
  select coalesce(string_agg(a.changed -> 'outcome' ->> 'new', ',' order by a.id), '')
  from public.audit_events a
  where a.table_name = 'care_visits' and a.entity_id = pg_temp.v(n) and a.command = p_command and a.changed ? 'outcome' $$;

-- Fixtures: Testteam Nord, case …208, responsible …902.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(x.n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.today() + x.d, x.t, x.t + interval '30 minutes', false, x.s,
       '00000000-0000-4000-a000-000000000902'
from (values (1,  1, time '09:00', 'planned'),      -- tomorrow
             (2,  0, time '11:00', 'planned'),      -- today
             (3, -1, time '09:00', 'planned'),      -- yesterday (VIS1-6)
             (4,  1, time '08:00', 'on_the_way'),   -- tomorrow, already on the way (before VIS1)
             (5,  1, time '07:00', 'started'),      -- tomorrow, already started (before VIS1)
             (6,  0, time '08:00', 'planned'),      -- today, started yesterday (before VIS1), below
             (7,  7, time '09:00', 'planned'))      -- next week (VIS1-3 example)
  as x(n, d, t, s);

-- 6: a visit dated today that was started yesterday (only possible before VIS1): written as the table owner at a
-- clock pinned to yesterday, so the started event carries yesterday's time.
select set_config('navora.test_now', (private.now() - interval '1 day')::text, true);
update public.care_visits set status = 'started' where id = pg_temp.v(6);
select set_config('navora.test_now', (private.now() + interval '1 day')::text, true);
select is((select (private.at_zurich(max(occurred_at)))::date from public.visit_events where visit_id = pg_temp.v(6) and event_type = 'started'),
  pg_temp.today() - 1, 'fixture: visit 6 was started yesterday');

-- Contract -------------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('authenticated', 'private.write_visit_refusal(public.care_visits, text, text)', 'execute'),
  'the refusal writer is not callable by the app');
select ok(not has_function_privilege('anon', 'private.visit_day_refusal(text, uuid)', 'execute'),
  'anon cannot call the day rule');
select is((select class from private.audit_value_classes where table_name = 'care_visits' and key = 'outcome'), 'code',
  'AUD1-1: the outcome key is catalogued as a code');

-- VIS1-2: a visit dated tomorrow ---------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.v(1), pg_temp.k(1)), 'not_today', 'start: a visit dated tomorrow is refused');
select is(public.depart_visit(pg_temp.v(1), pg_temp.k(2)), 'not_today', 'depart: a visit dated tomorrow is refused');
select is(pg_temp.status(1), 'planned', 'its status is still planned');
select is(pg_temp.events(1), 0, 'no visit event was written');
select is(public.start_visit(pg_temp.v(7), pg_temp.k(3)), 'not_today', 'next week: refused as well (no tolerance)');
select is(public.record_no_show(pg_temp.v(4), 'Synthetisch: niemand öffnet', pg_temp.k(4), true), 'not_today',
  'no-show: refused on a visit dated tomorrow, even when already on the way');
select is(pg_temp.status(4), 'on_the_way', 'and nothing changed');
select is((select count(*)::int from public.visit_status_notes where visit_id = pg_temp.v(4)), 0, 'no status note was written');
select is(public.end_visit_not_completed(pg_temp.v(5), 'client_declined', null, pg_temp.k(5)), 'not_today',
  'not completed: refused on a visit dated tomorrow');
select is(public.complete_visit(pg_temp.v(5), pg_temp.k(6)), 'started_before_date',
  'complete: a started visit dated tomorrow is refused (it was started before its date)');
select is(pg_temp.status(5), 'started', 'and it stays started');
reset role;

-- Audit: one row per refusal, the outcome only, no idempotency key ----------------------------------------------------
select is(pg_temp.refusals(1, 'start_visit'), 'not_today', 'one audit row for the refused start');
select is(pg_temp.refusals(1, 'depart_visit'), 'not_today', 'one audit row for the refused departure');
select is(pg_temp.refusals(4, 'record_no_show'), 'not_today', 'one audit row for the refused no-show');
select is(pg_temp.refusals(5, 'end_visit_not_completed'), 'not_today', 'one audit row for the refused "not completed"');
select is(pg_temp.refusals(5, 'complete_visit'), 'started_before_date', 'one audit row for the refused completion');
select ok((select bool_and(a.idempotency_key is null and a.actor_id = '00000000-0000-4000-a000-000000000902'
                           and array(select jsonb_object_keys(a.changed)) = array['outcome'])
           from public.audit_events a where a.table_name = 'care_visits' and a.changed ? 'outcome'),
  'refusal rows carry the actor and the outcome code only, no idempotency key');

-- Not visible to her: the command's own refusal, no day outcome, no audit row ----------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.start_visit(pg_temp.v(7), pg_temp.k(10)), 'rejected', 'a coordinator outside the team gets rejected, not the date');
reset role;
select is(pg_temp.refusals(7, 'start_visit'), 'not_today', 'and her call wrote no refusal row (only the nurse''s one)');

-- The audited route for a visit done early: move it to today, then start it ------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.v(1), pg_temp.today(), '09:00', '09:30', 'Heute statt morgen gemacht', pg_temp.k(11)) ->> 'result',
  'ok', 'she moves tomorrow''s visit to today (J3)');
select is(public.start_visit(pg_temp.v(1), pg_temp.k(1)), 'ok',
  'the same key as the refused start is evaluated again: started, not a duplicate');
select is(pg_temp.status(1), 'started', 'the moved visit is started');
select is(public.complete_visit(pg_temp.v(1), pg_temp.k(12)), 'ok', 'and completed on its (new) day');
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.v(1) and change = 'moved'), 1,
  'the move is on record');
reset role;

-- VIS1-2 / VIS1-6: today and yesterday unchanged ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.depart_visit(pg_temp.v(2), pg_temp.k(20)), 'ok', 'today: depart');
select is(public.start_visit(pg_temp.v(2), pg_temp.k(21)), 'ok', 'today: start');
select is(public.complete_visit(pg_temp.v(2), pg_temp.k(22)), 'ok', 'today: complete');
select is(public.start_visit(pg_temp.v(3), pg_temp.k(23)), 'ok', 'yesterday: a forgotten tap can still be recorded (start)');
select is(public.complete_visit(pg_temp.v(3), pg_temp.k(24)), 'ok', 'yesterday: complete');
select is(public.complete_visit(pg_temp.v(6), pg_temp.k(25)), 'started_before_date',
  'complete: a visit dated today that was started yesterday is refused');
select is(public.end_visit_not_completed(pg_temp.v(6), 'started_by_mistake', null, pg_temp.k(26)), 'ok',
  'it can be ended as not completed on its day (CSR1)');
reset role;
select is((select count(*)::int from public.audit_events a where a.table_name = 'care_visits' and a.changed ? 'outcome'
           and a.entity_id in (pg_temp.v(2), pg_temp.v(3))), 0, 'today and yesterday: no refusal row');

-- Duplicate keys still answer duplicate (begin_command runs first) -----------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.v(2), pg_temp.k(21)), 'duplicate', 'a repeated successful key is still a duplicate');
reset role;

-- The day changes at Zurich midnight (DAY-1), not at UTC midnight ------------------------------------------------------
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(8), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        pg_temp.today() + 1, '00:10', '00:40', false, 'planned', '00000000-0000-4000-a000-000000000902');
-- 23:50 Zurich today: tomorrow's 00:10 visit is still refused.
select set_config('navora.test_now', private.at_zurich((pg_temp.today() + time '23:50')::timestamp)::text, true);
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.v(8), pg_temp.k(30)), 'not_today', '23:50 Zurich: a visit at 00:10 the next day is refused');
reset role;
-- 00:05 Zurich the next day: it is today now.
select set_config('navora.test_now', (private.now() + interval '15 minutes')::text, true);
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.v(8), pg_temp.k(31)), 'ok', '00:05 Zurich: the same visit can be started');
reset role;

-- No tolerance and no other date rule coded (VIS1-6, CGR-87 (4)) ------------------------------------------------------
select ok((select prosrc !~ '(interval|tolerance|minutes)' from pg_proc where oid = 'private.visit_day_refusal(text, uuid)'::regprocedure),
  'the day rule holds no tolerance or interval');
select ok((select prosrc ~ 'VIS1' from pg_proc where oid = 'private.transition_visit(text, uuid, text[], text, uuid)'::regprocedure)
          and (select prosrc ~ 'VIS1' from pg_proc where oid = 'public.record_no_show(uuid, text, uuid, boolean)'::regprocedure)
          and (select prosrc ~ 'VIS1' from pg_proc where oid = 'public.end_visit_not_completed(uuid, text, text, uuid)'::regprocedure),
  'every field command carries the day rule');

select * from finish();
rollback;
