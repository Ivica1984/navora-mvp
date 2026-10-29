-- VIS1-10 (ADR-116; PO brief docs/agents/briefs/VIS1.md, po 2026-10-29 02:15, 03:10, 04:10; `cra` CGR-91).
-- "Heute machen" (move_visit_to_today) lands on the database's today (Europe/Zurich) or is refused with day_changed:
-- nothing changes, no `moved` row, one audit row. The /team move to a past date (reschedule_visit, Nachtrag) is unchanged.
-- Clock pinned at 00:05 Zurich: the page was rendered yesterday evening and is confirmed five minutes after midnight.
-- Users (supabase/seed.sql): nurse …902 (Testteam Nord …101) · coordinator …904 (org A, no team). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(29);

select set_config('navora.test_now',
  private.at_zurich(((private.at_zurich(private.now()))::date + time '00:05')::timestamp)::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.v(n integer) returns uuid language sql as $$
  select ('00000000-0000-4000-a093-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql as $$
  select ('a9300000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.slot(n integer) returns text language sql as $$
  select visit_date::text || ' ' || time_start::text || '-' || time_end::text || ' ' || coalesce(responsible_user_id::text, '-')
  from public.care_visits where id = pg_temp.v(n) $$;
create function pg_temp.moved(n integer) returns integer language sql as $$
  select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.v(n) and change = 'moved' $$;
create function pg_temp.refusals(n integer) returns integer language sql as $$
  select count(*)::int from public.audit_events
  where entity_id = pg_temp.v(n) and command = 'move_visit_to_today' and changed -> 'outcome' ->> 'new' = 'day_changed' $$;

-- Fixtures (as the table owner): case …208, team Nord, responsible …902, planned 30 minutes in a 30-minute window.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(x.n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.today() + x.d, time '15:00', time '15:30', false, 'planned', 30, 0,
       '00000000-0000-4000-a000-000000000902'
from (values (1, 3), (2, 4), (3, 5), (4, 6)) as x(n, d);

-- Contract -------------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.move_visit_to_today(uuid, date, time, time, text, uuid)', 'execute'),
  'anon cannot call move_visit_to_today');
select ok(has_function_privilege('authenticated', 'public.move_visit_to_today(uuid, date, time, time, text, uuid)', 'execute'),
  'the app (authenticated) can call move_visit_to_today');
select ok((select prosecdef from pg_proc where oid = 'public.move_visit_to_today(uuid, date, time, time, text, uuid)'::regprocedure),
  'move_visit_to_today is SECURITY DEFINER (search_path pinned)');
select ok((select prosrc !~ '(interval|tolerance|minutes)' from pg_proc where oid = 'public.move_visit_to_today(uuid, date, time, time, text, uuid)'::regprocedure),
  'VIS1-10: the day rule holds no tolerance or interval');
select ok(has_function_privilege('authenticated', 'public.reschedule_visit(uuid, date, time, time, text, uuid)', 'execute'),
  'reschedule_visit (the /team move) keeps its signature and grant');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

-- Page rendered yesterday, confirmed at 00:05 today: refused ---------------------------------------------------------
select is((select public.move_visit_to_today(pg_temp.v(1), pg_temp.today() - 1, time '00:10', time '00:40', 'An der Tür', pg_temp.k(1)) ->> 'result'),
  'day_changed', 'VIS1-10: "Heute machen" with yesterday''s date at 00:05 is refused with day_changed');
reset role;
select is(pg_temp.slot(1), (pg_temp.today() + 3)::text || ' 15:00:00-15:30:00 00000000-0000-4000-a000-000000000902',
  'VIS1-10: date, times and responsible member unchanged');
select is(pg_temp.moved(1), 0, 'VIS1-10: no moved row');
select is(pg_temp.refusals(1), 1, 'VIS1-10: one audit row with the outcome day_changed');
select is((select count(*)::int from public.audit_events where entity_id = pg_temp.v(1) and idempotency_key is not null), 0,
  'VIS1-10: the refusal row carries no idempotency key (ADR-111 (2)), so the same key is evaluated again');
select is((select count(*)::int from public.audit_events where entity_id = pg_temp.v(1) and command is not null), 1,
  'VIS1-10: no other command row is written for the visit');
set local role authenticated;
select is((select public.move_visit_to_today(pg_temp.v(1), pg_temp.today() - 1, time '00:10', time '00:40', 'An der Tür', pg_temp.k(1)) ->> 'today'),
  pg_temp.today()::text, 'VIS1-10: the refusal names the database''s today (for the confirmation shown again)');
select is((select public.move_visit_to_today(pg_temp.v(1), pg_temp.today() - 1, time '00:10', time '00:40', 'An der Tür', pg_temp.k(1)) ->> 'visit_date'),
  (pg_temp.today() + 3)::text, 'VIS1-10: the refusal names the visit''s unchanged date');

-- Confirmed again with the shown (database's) date: moved to today ---------------------------------------------------
select is((select public.move_visit_to_today(pg_temp.v(1), pg_temp.today(), time '00:10', time '00:40', 'An der Tür', pg_temp.k(1)) ->> 'result'),
  'ok', 'VIS1-10: the second confirm with today''s date (same key) returns ok');
reset role;
select is(pg_temp.slot(1), pg_temp.today()::text || ' 00:10:00-00:40:00 00000000-0000-4000-a000-000000000902',
  'VIS1-10: the stored date is the database''s today with the confirmed times');
select is(pg_temp.moved(1), 1, 'VIS1-10: one moved row');
select is((select after ->> 'date' from public.visit_plan_changes where visit_id = pg_temp.v(1) and change = 'moved'),
  pg_temp.today()::text, 'VIS1-10: the moved fact names today');
set local role authenticated;
select is((select public.move_visit_to_today(pg_temp.v(1), pg_temp.today(), time '00:10', time '00:40', 'An der Tür', pg_temp.k(1)) ->> 'result'),
  'duplicate', 'a retry of the applied move is a duplicate');
reset role;
select is(pg_temp.moved(1), 1, 'the duplicate writes no second moved row');

-- Device clock ahead (shown tomorrow): refused as well ---------------------------------------------------------------
set local role authenticated;
select is((select public.move_visit_to_today(pg_temp.v(2), pg_temp.today() + 1, time '00:10', time '00:40', 'An der Tür', pg_temp.k(2)) ->> 'result'),
  'day_changed', 'VIS1-10: a shown date after the database''s today is refused too');
reset role;
select is(pg_temp.slot(2), (pg_temp.today() + 4)::text || ' 15:00:00-15:30:00 00000000-0000-4000-a000-000000000902',
  'VIS1-10: that visit is unchanged');

-- Outside the team: reschedule_visit's own refusal, no day learned, no refusal row -----------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select public.move_visit_to_today(pg_temp.v(3), pg_temp.today() - 1, time '00:10', time '00:40', 'An der Tür', pg_temp.k(3))),
  '{"result": "rejected", "reason": "not_team_member"}'::jsonb, 'a coordinator outside the team gets rejected (no date in the answer)');
reset role;
select is(pg_temp.refusals(3), 0, 'no day_changed row for someone outside the team');
select is(pg_temp.moved(3), 0, 'and no move');

-- Not signed in -------------------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);
select is((select public.move_visit_to_today(pg_temp.v(3), pg_temp.today(), time '00:10', time '00:40', 'An der Tür', pg_temp.k(4)) ->> 'result'),
  'rejected', 'without a user the command is rejected');

-- /team: the move to a past date (Nachtrag, ADR-063 / ABS1-C5) is unchanged ------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select public.reschedule_visit(pg_temp.v(4), pg_temp.today() - 1, time '15:00', time '15:30', 'Nachtrag', pg_temp.k(5)) ->> 'result'),
  'ok', 'the /team move to a past date still returns ok');
reset role;
select is((select visit_date from public.care_visits where id = pg_temp.v(4)), pg_temp.today() - 1,
  'the /team move stored the past date');
select is(pg_temp.refusals(4), 0, 'the /team move writes no day_changed row');

-- Key required (begin_command) ----------------------------------------------------------------------------------------
set local role authenticated;
select throws_ok($$ select public.move_visit_to_today(pg_temp.v(2), pg_temp.today(), time '00:10', time '00:40', 'An der Tür', null) $$,
  '22023', 'idempotency key is required', 'an idempotency key is required');
reset role;

select * from finish();
rollback;
