-- AIG1-C1 (as amended 2026-10-30 21:25) and AIG1-C2 (CGR-105) (migration 0104, ADR-130). Brief `docs/agents/briefs/AIG1.md`.
-- All data synthetic; no AI service is called.
-- Seed users: pflege …902 "p" (RN, Nord …101) · assist …906 "ca" (CA, Nord) · ops …904 · admin …905 (org A …011).
-- Synthetic users added here: a1040000-…-010401 "r4", a registered nurse of Nord and the primary nurse of case …208, so the
-- synthetic test agent proposes her; a1040000-…-010402 "o", a nurse of team …102 only. Visits a1040000-…-8000-00000000010x.
begin;
create extension if not exists pgtap with schema extensions;

select plan(23);

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
                 when 'r4' then 'a1040000-0000-4000-a000-000000010401' when 'o' then 'a1040000-0000-4000-a000-000000010402' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1041000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1040000-0000-4000-8000-' || lpad((100 + n)::text, 12, '0'))::uuid $$;
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

select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(1))) ->> 'result', 'ok',
  'fixture: the synthetic test agent is switched on');
select ok(pg_temp.propose(1, 2) is not null and pg_temp.propose(2, 3) is not null and pg_temp.propose(3, 4) is not null
          and pg_temp.propose(4, 5) is not null, 'fixture: four proposals of r4');
select ok(pg_temp.decide(1, 'confirmed', null, 6) ->> 'result' = 'ok' and pg_temp.decide(2, 'confirmed', null, 7) ->> 'result' = 'ok'
          and pg_temp.decide(3, 'confirmed', null, 8) ->> 'result' = 'ok' and pg_temp.decide(4, 'confirmed', null, 9) ->> 'result' = 'ok',
  'fixture: the four confirmed unchanged while their visits are open');
update public.ai_agent_definitions set version = '2' where key = 'aig1_test_primary_nurse';
select is(pg_temp.cmd('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(5), pg_temp.k(10))) ->> 'result',
  'agent_stopped', 'fixture: the changed version stops the agent');
insert into stop1 select id from public.ai_agent_stops order by seq desc limit 1;

-- The next day: visits 1-3 are dated before today (no longer open); visit 4 is today (still open).
select pg_temp.at((pg_temp.t() + 2) + time '07:00');
create temp table c0 as select pg_temp.confs() as n;

-- AIG1-C1 (2): listed, labelled not_open, not counted as open ----------------------------------------------------------------
select is((select string_agg(((e ->> 'entity_id') = pg_temp.v(4)::text)::text || ':' || (e ->> 'not_open'), ','
                             order by e ->> 'entity_id') from jsonb_array_elements(pg_temp.lookback()) e),
  'false:true,false:true,false:true,true:false',
  'AIG1-C1 (2): all four lines stay listed; the three past visits are returned not_open, the open visit is not');
select is(pg_temp.detail(), '[{"detail": "Testassistent Bezugspflege · Werte: 1 offen · 3 nicht mehr offen"}]'::jsonb,
  'AIG1-C1 (2): the OPS1 detail shows both counts; the past visits are not counted as open');
select is((select count(*)::int from unnest((select proargnames from pg_proc where oid = 'public.agent_stop_lookback(uuid)'::regprocedure)
                                          || (select proargnames from pg_proc where oid = 'public.record_lookback_lines(text, uuid)'::regprocedure)) a
           where a ~ '(confirm|outcome|status|user|person|member|actor|by$|nurse)'), 0,
  'AIG1-C1 / AIG1-11 (4): neither the look-back list nor the record reader has a person or outcome column');

-- AIG1-C1 (1): re-confirmation and correction of a past visit's line are refused not_open; nothing is written -------------
select is(pg_temp.decide(1, 'confirmed', null, 11), '{"result": "refused", "reason": "not_open"}'::jsonb,
  'AIG1-C1 (1): re-confirming a listed value of a visit no longer open is refused not_open');
select is(pg_temp.decide(2, 'corrected', pg_temp.u('p'), 12), '{"result": "refused", "reason": "not_open"}'::jsonb,
  'AIG1-C1 (1): changing a listed value of a visit no longer open is refused not_open');
select ok(pg_temp.confs() = (select n from c0)
          and (select count(*) = 2 from public.care_visits where id in (pg_temp.v(1), pg_temp.v(2)) and responsible_user_id = pg_temp.u('r4')),
  'AIG1-C1 (1): no ai_confirmations row is written and the records are unchanged');
select ok(pg_temp.line(1) ->> 'not_open' = 'true' and pg_temp.line(2) ->> 'not_open' = 'true',
  'AIG1-C1 (3): both lines stay on the look-back list');

-- AIG1-C1 (3) guard: an applied value is never rejected off the list ---------------------------------------------------------
select is(pg_temp.err('p', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug(3), 'rejected', pg_temp.k(13))),
  '22023', 'AIG1-C1 (3): rejecting a value already applied is refused');
select ok(pg_temp.confs() = (select n from c0) and pg_temp.line(3) is not null,
  'AIG1-C1 (3): no row is written and the line stays listed');

-- AIG1-C2 (a)/(d): the record reader answers the record's team only ------------------------------------------------------------
select is(pg_temp.record_lines('p', 4),
  jsonb_build_array(jsonb_build_object('field', 'responsible_user_id', 'record_open', true, 'suggestion_id', pg_temp.sug(4))),
  'AIG1-C2 (a): a member of the record''s team gets the listed suggestion of an open visit');
select is(pg_temp.record_lines('p', 1),
  jsonb_build_array(jsonb_build_object('field', 'responsible_user_id', 'record_open', false, 'suggestion_id', pg_temp.sug(1))),
  'AIG1-C2 (b): for a visit no longer open the line says so (no action on screen)');
select is(jsonb_array_length(pg_temp.record_lines('ops', 4)), 0,
  'AIG1-C2 (d): a coordinator who is not a team member gets no line, so no control');
select is(jsonb_array_length(pg_temp.record_lines('o', 4)), 0,
  'AIG1-C2: a member of another team gets no line');
select is(jsonb_array_length(pg_temp.record_lines('p', 5)), 0,
  'AIG1-C2: a record without a listed value has no line');

-- AIG1-15 (iv) unchanged: the open visit's line is counted open and leaves on re-confirmation -----------------------------
select is(pg_temp.decide(4, 'confirmed', null, 14) ->> 'result', 'ok',
  'AIG1-15 (iv): re-confirming the listed value of a still open visit is ok');
select ok(pg_temp.confs() = (select n from c0) + 1 and pg_temp.line(4) is null
          and jsonb_array_length(pg_temp.record_lines('p', 4)) = 0,
  'AIG1-15 (iv): one ai_confirmations row; the line leaves the list and the record page');

-- AIG1-C1 (4): every open-visit line handled, the agent still stopped: "0 offen · 3 nicht mehr offen" ---------------------
select is(pg_temp.detail(), '[{"detail": "Testassistent Bezugspflege · Werte: 0 offen · 3 nicht mehr offen"}]'::jsonb,
  'AIG1-C1 (4): the exception stays open while the agent is stopped and reads "Werte: 0 offen · 3 nicht mehr offen"');
select is((select state from public.ai_agent_settings where organization_id = '00000000-0000-4000-b000-000000000011'
             and agent_key = 'aig1_test_primary_nurse'), 'stopped',
  'AIG1-C1 (4): the agent stays stopped (closes only on a new audited switch-on)');
select is(jsonb_array_length(pg_temp.lookback()), 3,
  'AIG1-C1 (3): the three past-visit lines are never removed');

select * from finish();
rollback;
