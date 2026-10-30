-- ABS1-C5 (migration 0052, ADR-063): `reschedule_visit` refuses with responsible_absent a move that would leave the
-- visit with a member absent at its interval (a date before today, which the release rule does not cover), and writes
-- nothing. Cases (a)-(c) of the PO review 2026-10-23 18:15 in docs/agents/briefs/ABS1.md.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) is responsible · care assistant …906 (Nord) records the
-- absence and moves. Case …208. All data synthetic. Fixtures are written as the table owner; every step under test goes
-- through the real commands as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;

create temp table fx (name text primary key, id uuid not null, d int not null, t0 time not null, t1 time not null);
grant select on fx to authenticated;
insert into fx values
  ('past_in',   'a0520000-0000-4000-8000-000000000001', 2, '07:00', '07:30'),   -- (a) moved to yesterday, inside
  ('past_out',  'a0520000-0000-4000-8000-000000000002', 2, '09:00', '09:30'),   -- (b) moved to yesterday, outside
  ('future_in', 'a0520000-0000-4000-8000-000000000003', 5, '07:00', '07:30');   -- (c) moved into the absence ahead
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.today() + f.d, f.t0, f.t1, array['Grundpflege'],
       false, 'planned', 30, 0, '00000000-0000-4000-a000-000000000902'
from fx f;
create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.slot(n text) returns text language sql as $$
  select v.visit_date || ' ' || v.time_start || ' ' || coalesce(v.responsible_user_id::text, '-')
  from public.care_visits v where v.id = pg_temp.vid(n) $$;
create function pg_temp.moves(n text) returns integer language sql as $$
  select count(*)::int from public.visit_plan_changes c where c.visit_id = pg_temp.vid(n) and c.change = 'moved' $$;
create temp table before_slot as select f.name, pg_temp.slot(f.name) as s from fx f;

-- A colleague records 902 absent from yesterday 06:00 to tomorrow 08:00 (an absence must end in the future), and on
-- day +3 (whole day).
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
          pg_temp.today() - 1, pg_temp.today() + 1, '06:00', '08:00', 'a5200000-0000-4000-8000-000000000001') ->> 'result', 'ok',
  'a colleague records her absent from yesterday 06:00 to tomorrow 08:00');
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
          pg_temp.today() + 3, null, null, null, 'a5200000-0000-4000-8000-000000000002') ->> 'result', 'ok',
  'and absent on day +3');

-- (a) move to yesterday inside her absence: refused, nothing written ---------------------------------------------------
select is(public.reschedule_visit(pg_temp.vid('past_in'), pg_temp.today() - 1, '07:00', '07:30', 'Synthetisch: Nachtrag',
          'a5200000-0000-4000-8000-000000000010'),
  '{"result": "rejected", "reason": "responsible_absent"}'::jsonb,
  'ABS1-C5 (a): a move to yesterday inside her absence is refused with responsible_absent');
select is(public.reschedule_visit(pg_temp.vid('past_in'), pg_temp.today() - 1, '07:00', '07:30', 'Synthetisch: Nachtrag',
          'a5200000-0000-4000-8000-000000000010'), '{"result": "rejected", "reason": "responsible_absent"}'::jsonb,
  'a replay with the same key is refused again (a refusal writes no audit row, as every rejection)');
reset role;
select is(pg_temp.slot('past_in'), (select s from before_slot where name = 'past_in'), '(a) date, time and responsible unchanged');
select is(pg_temp.moves('past_in'), 0, '(a) no moved log row');
select is((select count(*)::int from public.visit_plan_changes c where c.visit_id = pg_temp.vid('past_in')), 0,
  '(a) no plan change of any kind (no release either)');

-- (b) the same move to yesterday outside any absence: ok, still hers --------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.vid('past_out'), pg_temp.today() - 1, '05:00', '05:30', 'Synthetisch: Nachtrag',
          'a5200000-0000-4000-8000-000000000011') - 'visit_id' - 'flags' - 'overlap' /* VIS2-5 (0098) */, '{"result": "ok", "released": false}'::jsonb,
  'ABS1-C5 (b): a move to yesterday outside her absence is accepted');
reset role;
select is(pg_temp.slot('past_out'), (pg_temp.today() - 1) || ' 05:00:00 00000000-0000-4000-a000-000000000902',
  '(b) moved, still hers');
select is(pg_temp.moves('past_out'), 1, '(b) one moved log row');

-- (c) a move into her absence ahead still releases (ABS1-C4 (c), unchanged) --------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.vid('future_in'), pg_temp.today() + 3, '07:00', '07:30', 'Wunsch der Klientin',
          'a5200000-0000-4000-8000-000000000012') - 'visit_id' - 'flags' - 'overlap' /* VIS2-5 (0098) */, '{"result": "ok", "released": true}'::jsonb,
  'ABS1-C5 (c): a move into her absence on day +3 is accepted and releases the visit');
reset role;
select is(pg_temp.slot('future_in'), (pg_temp.today() + 3) || ' 07:00:00 -', '(c) moved and open in the team');

select * from finish();
rollback;
