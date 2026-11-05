-- PLAN3-11 (migration 0111, ADR-149): after a stop, the team finds the look-back lines of its own records on `/team`.
-- Brief `docs/agents/briefs/PLAN3.md` PLAN3-11 as amended by AIG1-C5 (d). All data synthetic; no AI service is called.
-- Fixture as pgTAP 104 (synthetic test agent `aig1_test_primary_nurse`, org A …011): seed users pflege …902 "p" (Nord
-- …101), ops …904 (coordinator, no team), admin …905; synthetic "r4" (Nord, primary nurse of case …208) and "o" (team
-- …102 only). Ids a1120000-… so they never collide with 104.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;
create function pg_temp.at(p_local timestamp) returns void language sql as $$
  select set_config('navora.test_now', private.at_zurich(p_local)::text, true) $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'ops' then '00000000-0000-4000-a000-000000000904' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'r4' then 'a1120000-0000-4000-a000-000000011201' when 'o' then 'a1120000-0000-4000-a000-000000011202' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1121000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1120000-0000-4000-8000-' || lpad((100 + n)::text, 12, '0'))::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.rows(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]'') from (%s) x', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.err(p_user text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  begin
    execute p_sql;
  exception when others then
    execute 'reset role';
    return sqlstate;
  end;
  execute 'reset role';
  return 'no error';
end $$;
create function pg_temp.propose(n int, key int) returns uuid language sql as $$
  select (pg_temp.cmd('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(n), pg_temp.k(key)))
          ->> 'suggestion_id')::uuid $$;
create function pg_temp.sug(n int) returns uuid language sql stable as $$
  select s.id from public.ai_suggestions s where s.entity_id = pg_temp.v(n) order by s.seq desc limit 1 $$;
-- "p" decides the proposal for visit n (outcome, value); returns {result, reason}.
create function pg_temp.decide(n int, p_outcome text, p_value uuid, key int) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.confirm_suggestion(%L, %L, %s, %L)', pg_temp.sug(n), p_outcome,
                                 case when p_value is null then 'null' else quote_literal(to_jsonb(p_value::text)::text) || '::jsonb' end,
                                 pg_temp.k(key))) $$;
create function pg_temp.confs() returns int language sql stable as $$
  select count(*)::int from public.ai_confirmations c join public.ai_suggestions s on s.id = c.suggestion_id
  where s.entity_id in (select pg_temp.v(n) from generate_series(1, 5) n) $$;
create temp table stop1 (id uuid);
create function pg_temp.lookback() returns jsonb language sql as $$
  select pg_temp.rows('ops', format('select entity_id, superseded, not_open from public.agent_stop_lookback(%L)',
                                    (select id from stop1))) $$;
create function pg_temp.line(n int) returns jsonb language sql as $$
  select (select e from jsonb_array_elements(pg_temp.lookback()) e where e ->> 'entity_id' = pg_temp.v(n)::text) $$;
create function pg_temp.detail() returns jsonb language sql as $$
  select pg_temp.rows('ops', format('select detail from public.operations_exceptions() where exception_key = %L',
                                    'agent_stopped:' || (select id from stop1))) $$;
create function pg_temp.record_lines(p_user text, n int) returns jsonb language sql as $$
  select pg_temp.rows(p_user, format('select suggestion_id, field, record_open from public.record_lookback_lines(%L, %L)',
                                     'care_visits', pg_temp.v(n))) $$;

-- Fixtures (as the table owner): r4, the primary nurse of case 208; o, a nurse of team 102 only; unassigned Nord visits
-- of case 208: 1-3 on T+1 (past once the clock moves to T+2), 4 on T+2 (still open then), 5 on T+2 (proposed after the stop).
insert into auth.users (id, email) values (pg_temp.u('r4'), 'aig1-c1-r4@navora.test'), (pg_temp.u('o'), 'aig1-c1-o@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('r4'), 'nurse'),
       ('00000000-0000-4000-b000-000000000011', pg_temp.u('o'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u('r4'), 'registered_nurse'),
       ('00000000-0000-4000-a000-000000000102', pg_temp.u('o'), 'registered_nurse');
update public.cases set primary_nurse_id = pg_temp.u('r4') where id = '00000000-0000-4000-a000-000000000208';
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.t() + d, s, s + interval '15 minutes', array['Grundpflege'], false,
       'planned', 15
from (values (1, 1, time '08:00'), (2, 1, time '09:00'), (3, 1, time '10:00'), (4, 2, time '08:00'),
             (5, 2, time '09:00')) f(n, d, s);

create function pg_temp.stops(p_user text) returns jsonb language sql as $$
  select pg_temp.rows(p_user, 'select stop_id, team_id, open_count, not_open_count from public.team_lookback_stops()') $$;
create function pg_temp.mine(p_user text) returns jsonb language sql as $$
  select (select e from jsonb_array_elements(pg_temp.stops(p_user)) e where (e ->> 'stop_id')::uuid = (select id from stop1)) $$;

-- Fixtures (as the table owner, as in 104): four Nord visits of case 208 (1-3 on T+1, 4 on T+2), all confirmed unchanged
-- while open, then the version change stops the agent; the clock moves to T+2, so 1-3 are no longer open.
insert into auth.users (id, email) values (pg_temp.u('r4'), 'plan3-11-r4@navora.test'), (pg_temp.u('o'), 'plan3-11-o@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('r4'), 'nurse'),
       ('00000000-0000-4000-b000-000000000011', pg_temp.u('o'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u('r4'), 'registered_nurse'),
       ('00000000-0000-4000-a000-000000000102', pg_temp.u('o'), 'registered_nurse');
update public.cases set primary_nurse_id = pg_temp.u('r4') where id = '00000000-0000-4000-a000-000000000208';
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.t() + d, s, s + interval '15 minutes', array['Grundpflege'], false,
       'planned', 15
from (values (1, 1, time '08:00'), (2, 1, time '09:00'), (3, 1, time '10:00'), (4, 2, time '08:00'),
             (5, 2, time '09:00')) f(n, d, s);

select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(1))) ->> 'result', 'ok',
  'fixture: the synthetic test agent is switched on');
select ok(pg_temp.propose(1, 2) is not null and pg_temp.propose(2, 3) is not null and pg_temp.propose(3, 4) is not null
          and pg_temp.propose(4, 5) is not null
          and pg_temp.decide(1, 'confirmed', null, 6) ->> 'result' = 'ok' and pg_temp.decide(2, 'confirmed', null, 7) ->> 'result' = 'ok'
          and pg_temp.decide(3, 'confirmed', null, 8) ->> 'result' = 'ok' and pg_temp.decide(4, 'confirmed', null, 9) ->> 'result' = 'ok',
  'fixture: four proposals of r4, confirmed unchanged while their visits are open');
update public.ai_agent_definitions set version = '2' where key = 'aig1_test_primary_nurse';
select is(pg_temp.cmd('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(5), pg_temp.k(10))) ->> 'result',
  'agent_stopped', 'fixture: the changed version stops the agent');
insert into stop1 select id from public.ai_agent_stops order by seq desc limit 1;
select pg_temp.at((pg_temp.t() + 2) + time '07:00');

-- PLAN3-11: the team's own count, from the same lines as the look-back list ---------------------------------------------
select is(pg_temp.mine('p'),
  jsonb_build_object('stop_id', (select id from stop1), 'team_id', '00000000-0000-4000-a000-000000000101',
                     'open_count', 1, 'not_open_count', 3),
  'PLAN3-11: a member of team Nord gets the stop with "1 offen · 3 nicht mehr offen" for her team');
select is(pg_temp.mine('o'), null,
  'PLAN3-11: a member of another team gets no row for the stop (never widened)');
select is(pg_temp.mine('ops'), null,
  'PLAN3-11: a coordinator who is not a team member gets no row on the team view (Operations keeps the full list)');
select is((select count(*)::int from jsonb_array_elements(pg_temp.rows('o',
             format('select entity_id from public.agent_stop_lookback(%L)', (select id from stop1))))), 0,
  'PLAN3-11 / AIG1-12 (iii): the list the link opens returns no line to a member of team B');
select is((select count(*)::int from unnest((select proargnames from pg_proc
             where oid = 'public.team_lookback_stops()'::regprocedure)) a
           where a ~ '(confirm|outcome|status|user|person|member|actor|by$|nurse)'), 0,
  'PLAN3-11 / AIG1-11 (4): the stop reader has no person, outcome or confirmer column');

-- AIG1-C5 (d): the entry hangs on the open lines, not on the agent's state ----------------------------------------------
select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, false, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(11))) ->> 'result', 'ok',
  'fixture: the stopped test agent is switched off');
select is((pg_temp.mine('p') ->> 'open_count')::int, 1,
  'PLAN3-11 (AIG1-C5 (d)): after the switch-off the member still gets the stop with its open line');

-- No entry at "0 offen" ------------------------------------------------------------------------------------------------------
select is(pg_temp.decide(4, 'confirmed', null, 12) ->> 'result', 'ok',
  'AIG1-15 (iv): the member re-confirms the open line');
select is(pg_temp.mine('p'), null,
  'PLAN3-11 (AIG1-C5 (d)): at "0 offen" the stop has no entry on /team');

select * from finish();
rollback;
