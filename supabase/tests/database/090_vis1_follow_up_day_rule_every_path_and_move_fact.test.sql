-- VIS1 follow-up (ADR-112; PO brief docs/agents/briefs/VIS1.md).
-- VIS1-9 (`cra` CGR-90): the 0089 day rule also holds for a direct UPDATE of care_visits.status as `authenticated`.
-- VIS1-8 (`cra` CGR-89): one server-side yes/no: is another visit of the client still on the date the visit leaves
--         (own team or another team's, never shown in detail)?
-- VIS1-3c (`uxa` UXR-30): a visit moved to today with the prefilled start (next full 5 minutes after now) raises no
--         visit_overdue at the pinned now; the same move with the card's earlier time does (the hazard it removes).
-- Users (supabase/seed.sql): nurse …902 (Testteam Nord …101) · coordinator …904 (org A, no team).
-- Teams: Nord …101, Mitte …104 (org A). Case …208 (Nord). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

-- Pinned clock (DST1 pattern): 14:02 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  private.at_zurich(((private.at_zurich(private.now()))::date + time '14:02')::timestamp)::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.v(n integer) returns uuid language sql as $$
  select ('00000000-0000-4000-a090-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql as $$
  select ('a9000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.status(n integer) returns text language sql as $$
  select status from public.care_visits where id = pg_temp.v(n) $$;

-- Fixtures (as the table owner). Case …208; team Nord unless named; responsible …902 on Nord visits.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(x.n), '00000000-0000-4000-a000-000000000208', x.team::uuid,
       pg_temp.today() + x.d, x.t, x.t + interval '30 minutes', false, x.s, 30, 0,
       case when x.team = '00000000-0000-4000-a000-000000000101' then '00000000-0000-4000-a000-000000000902'::uuid end
from (values
  -- VIS1-9
  (1,   1, time '09:00', 'planned',    '00000000-0000-4000-a000-000000000101'),   -- tomorrow
  (2,   0, time '15:00', 'planned',    '00000000-0000-4000-a000-000000000101'),   -- today
  (3,  -1, time '09:00', 'planned',    '00000000-0000-4000-a000-000000000101'),   -- yesterday (VIS1-6)
  (4,   1, time '08:00', 'on_the_way', '00000000-0000-4000-a000-000000000101'),   -- tomorrow, on the way (before VIS1)
  (5,   1, time '07:00', 'started',    '00000000-0000-4000-a000-000000000101'),   -- tomorrow, started (before VIS1)
  -- VIS1-8: day +11 one visit only; +12 two Nord visits; +13 one Nord and one Mitte visit; +14 one Nord and one cancelled
  (11, 11, time '09:00', 'planned',    '00000000-0000-4000-a000-000000000101'),
  (12, 12, time '09:00', 'planned',    '00000000-0000-4000-a000-000000000101'),
  (13, 12, time '17:00', 'planned',    '00000000-0000-4000-a000-000000000101'),
  (14, 13, time '09:00', 'planned',    '00000000-0000-4000-a000-000000000101'),
  (15, 13, time '17:00', 'planned',    '00000000-0000-4000-a000-000000000104'),   -- another team's visit, same client
  (16, 14, time '09:00', 'planned',    '00000000-0000-4000-a000-000000000101'),
  (17, 14, time '17:00', 'cancelled',  '00000000-0000-4000-a000-000000000101'),
  -- VIS1-3c: tomorrow 06:00 and 06:30 (both earlier than the pinned now on today)
  (21,  1, time '06:00', 'planned',    '00000000-0000-4000-a000-000000000101'),
  (22,  1, time '06:30', 'planned',    '00000000-0000-4000-a000-000000000101'))
  as x(n, d, t, s, team);

-- Contract -------------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'private.visit_status_day_refusal(uuid, date, text, text)', 'execute'),
  'anon cannot call the day rule of the trigger');
select ok(not has_function_privilege('anon', 'public.visit_move_leaves_other_visit(uuid)', 'execute'),
  'anon cannot call the move fact');
select ok(has_function_privilege('authenticated', 'public.visit_move_leaves_other_visit(uuid)', 'execute'),
  'the app (authenticated) can call the move fact');
select is((select prorettype::regtype::text || ':' || proretset::text from pg_proc where oid = 'public.visit_move_leaves_other_visit(uuid)'::regprocedure),
  'boolean:false', 'VIS1-8 (2): the move fact is one yes/no, never rows');
select ok((select prosrc ~ 'visit_status_day_refusal' from pg_proc where oid = 'private.enforce_visit_transition()'::regprocedure),
  'VIS1-9: the transition trigger carries the day rule');
select ok((select prosrc !~ '(interval|tolerance|minutes)' from pg_proc where oid = 'private.visit_status_day_refusal(uuid, date, text, text)'::regprocedure),
  'VIS1-9: the trigger''s day rule holds no tolerance or interval');

-- VIS1-9: direct UPDATE as an authenticated team member -------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ update public.care_visits set status = 'started' where id = pg_temp.v(1) $$,
  '23514', 'not_today', 'VIS1-9: a direct start of tomorrow''s visit is refused');
select throws_ok($$ update public.care_visits set status = 'on_the_way' where id = pg_temp.v(1) $$,
  '23514', 'not_today', 'VIS1-9: a direct depart of tomorrow''s visit is refused');
select throws_ok($$ update public.care_visits set status = 'started' where id = pg_temp.v(4) $$,
  '23514', 'not_today', 'VIS1-9: a direct start of tomorrow''s visit that is already on the way is refused');
select throws_ok($$ update public.care_visits set status = 'completed' where id = pg_temp.v(5) $$,
  '23514', 'started_before_date', 'VIS1-9: completing tomorrow''s started visit directly follows the VIS1-1 rule');
reset role;
select is(pg_temp.status(1), 'planned', 'tomorrow''s visit is still planned');
select is(pg_temp.status(4), 'on_the_way', 'tomorrow''s on-the-way visit is unchanged');
select is(pg_temp.status(5), 'started', 'tomorrow''s started visit is unchanged');
select is((select count(*)::int from public.visit_events where visit_id in (pg_temp.v(1), pg_temp.v(4))), 0,
  'no visit event row was written by the refused updates');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
with u as (update public.care_visits set status = 'paused' where id = pg_temp.v(5) returning 1)
select is((select count(*)::int from u), 1, 'pause is unchanged (as in 0089)');
with u as (update public.care_visits set status = 'started' where id = pg_temp.v(2) returning 1)
select is((select count(*)::int from u), 1, 'VIS1-6: a direct start of today''s visit behaves as before');
with u as (update public.care_visits set status = 'on_the_way' where id = pg_temp.v(3) returning 1)
select is((select count(*)::int from u), 1, 'VIS1-6: yesterday''s visit can still be recorded (depart)');
-- The command still answers with its outcome code and audit row (its own check runs before the trigger).
select is(public.start_visit(pg_temp.v(1), pg_temp.k(1)), 'not_today', 'the command still returns not_today');
reset role;
select is((select count(*)::int from public.audit_events a where a.table_name = 'care_visits' and a.entity_id = pg_temp.v(1)
           and a.command = 'start_visit' and a.changed -> 'outcome' ->> 'new' = 'not_today'), 1,
  'and still writes its one refusal row');

-- VIS1-8: what the move leaves behind ----------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.visit_move_leaves_other_visit(pg_temp.v(11)), false, 'VIS1-8: the client''s only visit that day: false (kein Einsatz)');
select is(public.visit_move_leaves_other_visit(pg_temp.v(12)), true, 'VIS1-8: another visit of her team that day: true');
select is(public.visit_move_leaves_other_visit(pg_temp.v(14)), true,
  'VIS1-8 (2): another team''s visit for the client that day: true, never "kein Einsatz"');
select is((select count(*)::int from public.care_visits where id = pg_temp.v(15)), 0,
  'VIS1-8 (2): she cannot read that other team''s visit (no new read permission)');
select is(public.visit_move_leaves_other_visit(pg_temp.v(16)), false, 'VIS1-8: a cancelled visit that day does not count');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.visit_move_leaves_other_visit(pg_temp.v(12)), null::boolean, 'VIS1-8: outside the visit''s team: no answer');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.v(11), pg_temp.today(), '14:05', '14:35', 'Synthetisch: heute gemacht', pg_temp.k(11)) ->> 'result',
  'ok', 'VIS1-8 (3): the move itself is unchanged (J3)');
reset role;
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.v(11) and change = 'moved'), 1,
  'VIS1-8 (3): the move stays on record for the team (moved row)');

-- VIS1-3c: the prefilled start is never in the past --------------------------------------------------------------------
-- 14:02 Zurich: the prefill is 14:05 (next full 5 minutes after now) to 14:35 (the card's 30 minutes).
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.v(21), pg_temp.today(), '14:05', '14:35', 'Synthetisch: Klientin bittet um heute', pg_temp.k(21)) ->> 'result',
  'ok', 'VIS1-3c: tomorrow''s 06:00 visit moved to today with the prefilled 14:05');
select is(public.reschedule_visit(pg_temp.v(22), pg_temp.today(), '06:30', '07:00', 'Synthetisch: Kartenzeit behalten', pg_temp.k(22)) ->> 'result',
  'ok', 'control: tomorrow''s 06:30 visit moved to today with the card''s time (what VIS1-3c replaces)');
select ok(not exists (select 1 from public.team_visit_alerts() a where a.exception_type = 'visit_overdue' and a.visit_id = pg_temp.v(21)),
  'VIS1-3c: at the pinned now the moved visit is not overdue on /team');
select ok(exists (select 1 from public.team_visit_alerts() a where a.exception_type = 'visit_overdue' and a.visit_id = pg_temp.v(22)),
  'control: with the card''s earlier time it is overdue at once (the hazard)');
reset role;
select ok(private.evaluate_signals('00000000-0000-4000-b000-000000000011', true) >= 0, 'the signal evaluation runs at the pinned now');
select is((select count(*)::int from public.safety_signals where visit_id = pg_temp.v(21) and signal_kind = 'visit_overdue'), 0,
  'VIS1-3c: no visit_overdue signal for the visit moved with the prefill');
select is((select count(*)::int from public.safety_signals where visit_id = pg_temp.v(22) and signal_kind = 'visit_overdue'), 1,
  'control: one visit_overdue signal for the visit moved with the card''s time');

select * from finish();
rollback;
