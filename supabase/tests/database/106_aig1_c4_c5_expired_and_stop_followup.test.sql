-- AIG1-C4 (CGR-107, with the CGR-106 tests) and AIG1-C5 (AUT-30) (migration 0105, ADR-139). Brief
-- `docs/agents/briefs/AIG1.md` 2026-10-31 02:25 and 02:55 CET. All data synthetic; no AI service is called.
-- Seed users: pflege …902 "p" (RN, Nord …101) · assist …906 "ca" (CA, Nord) · ops …904 · admin …905 (org A …011).
-- Synthetic users added here: a1060000-…-010601 "r6", a registered nurse of Nord and the primary nurse of case …208, so the
-- synthetic test agent proposes her; a1060000-…-010602 "q6", another registered nurse of Nord (the corrected value).
-- Visits a1060000-0000-4000-8000-00000000010x.
begin;
create extension if not exists pgtap with schema extensions;

select plan(28);

-- Pinned clock (DST1 pattern): day T is today in Zurich; the run starts at T-2 10:00.
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;
create function pg_temp.at(p_local timestamp) returns void language sql as $$
  select set_config('navora.test_now', private.at_zurich(p_local)::text, true) $$;
select pg_temp.at((pg_temp.t() - 2) + time '10:00');

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'ops' then '00000000-0000-4000-a000-000000000904' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'r6' then 'a1060000-0000-4000-a000-000000010601' when 'q6' then 'a1060000-0000-4000-a000-000000010602' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1061000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1060000-0000-4000-8000-' || lpad((100 + n)::text, 12, '0'))::uuid $$;
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
create function pg_temp.propose(n int, key int) returns jsonb language sql as $$
  select pg_temp.cmd('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(n), pg_temp.k(key))) $$;
create function pg_temp.sug(n int) returns uuid language sql stable as $$
  select s.id from public.ai_suggestions s where s.entity_id = pg_temp.v(n) order by s.seq desc limit 1 $$;
-- "p" decides the proposal for visit n (outcome, value); returns {result, reason}.
create function pg_temp.decide(n int, p_outcome text, p_value uuid, key int) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.confirm_suggestion(%L, %L, %s, %L)', pg_temp.sug(n), p_outcome,
                                 case when p_value is null then 'null' else quote_literal(to_jsonb(p_value::text)::text) || '::jsonb' end,
                                 pg_temp.k(key))) $$;
create function pg_temp.switch(p_on boolean, key int) returns text language sql as $$
  select pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, %L::boolean, 50, 100, 1, %L)',
                                     '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', p_on, pg_temp.k(key))) ->> 'result' $$;
create function pg_temp.confs(n int) returns int language sql stable as $$
  select count(*)::int from public.ai_confirmations c where c.suggestion_id = pg_temp.sug(n) $$;
create temp table stops (n int primary key, id uuid);
create function pg_temp.stop(n int) returns uuid language sql stable as $$ select id from stops where stops.n = $1 $$;
-- The OPS1 exception of one stop, as Operations reads it (empty when not listed).
create function pg_temp.detail(n int) returns jsonb language sql as $$
  select pg_temp.rows('ops', format('select detail from public.operations_exceptions() where exception_key = %L',
                                    'agent_stopped:' || pg_temp.stop(n))) $$;
create function pg_temp.lookback(n int) returns jsonb language sql as $$
  select pg_temp.rows('ops', format('select entity_id, superseded, not_open from public.agent_stop_lookback(%L)', pg_temp.stop(n))) $$;
create function pg_temp.line(s int, n int) returns jsonb language sql as $$
  select (select e from jsonb_array_elements(pg_temp.lookback(s)) e where e ->> 'entity_id' = pg_temp.v(n)::text) $$;
create function pg_temp.health() returns jsonb language sql as $$
  select (pg_temp.rows('ops', format('select state, stop_id, last_window_decided, last_window_expired, stops '
                                     'from public.agent_health(%L) where agent_key = %L',
                                     '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse'))) -> 0 $$;
-- The health list's entry for one stop: {open, not_open}, or null when absent.
create function pg_temp.health_stop(n int) returns jsonb language sql as $$
  select (select jsonb_build_object('open', e -> 'open', 'not_open', e -> 'not_open')
          from jsonb_array_elements(pg_temp.health() -> 'stops') e where e ->> 'stop_id' = pg_temp.stop(n)::text) $$;

-- Fixtures (as the table owner): r6, the primary nurse of case 208; q6, another Nord nurse. Unassigned Nord visits of
-- case 208: 1-3, 5-8 on T+1 (2 with category B minutes); 4 on T-2 (today at the start; past once the clock moves on).
insert into auth.users (id, email) values (pg_temp.u('r6'), 'aig1-c4-r6@navora.test'), (pg_temp.u('q6'), 'aig1-c4-q6@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('r6'), 'nurse'),
       ('00000000-0000-4000-b000-000000000011', pg_temp.u('q6'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u('r6'), 'registered_nurse'),
       ('00000000-0000-4000-a000-000000000101', pg_temp.u('q6'), 'registered_nurse');
update public.cases set primary_nurse_id = pg_temp.u('r6') where id = '00000000-0000-4000-a000-000000000208';
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.t() + d, s, s + interval '15 minutes', array['Grundpflege'], false,
       'planned', case when n = 2 then 0 else 15 end, case when n = 2 then 15 else 0 end
from (values (1, 1, time '06:00'), (2, 1, time '06:30'), (3, 1, time '07:00'), (4, -2, time '18:00'),
             (5, 1, time '07:30'), (6, 1, time '08:00'), (7, 1, time '08:30'), (8, 1, time '09:00')) f(n, d, s);

select is(pg_temp.switch(true, 1), 'ok', 'fixture: the synthetic test agent is switched on (1-day window, minimum 100)');
select ok(pg_temp.propose(1, 2) ->> 'result' = 'ok' and pg_temp.propose(2, 3) ->> 'result' = 'ok'
          and pg_temp.propose(3, 4) ->> 'result' = 'ok' and pg_temp.propose(4, 5) ->> 'result' = 'ok'
          and pg_temp.propose(5, 6) ->> 'result' = 'ok', 'fixture: five proposals of r6 while every visit is open');
select ok(pg_temp.decide(1, 'confirmed', null, 7) ->> 'result' = 'ok' and pg_temp.decide(2, 'confirmed', null, 8) ->> 'result' = 'ok'
          and pg_temp.decide(3, 'confirmed', null, 9) ->> 'result' = 'ok',
  'fixture: three confirmed unchanged; 4 and 5 stay undecided');

-- The next day, after the first 1-day window closed: visit 4 passed undecided ------------------------------------------
select pg_temp.at((pg_temp.t() - 1) + time '11:00');

-- AIG1-C4 (1): the confirm screen no longer lists the expired proposal; an open one is listed as before -----------------
select is((select string_agg(e ->> 'entity_id', ',' order by e ->> 'entity_id')
           from jsonb_array_elements(pg_temp.rows('p', format('select entity_id from public.open_suggestions(%L)',
                                                              '00000000-0000-4000-a000-000000000101'))) e
           where e ->> 'entity_id' in (pg_temp.v(4)::text, pg_temp.v(5)::text)),
  pg_temp.v(5)::text,
  'AIG1-C4 (1): an undecided proposal whose visit is no longer open is not listed; one of an open visit is');
select is(pg_temp.decide(4, 'rejected', null, 10), '{"result": "refused", "reason": "not_open"}'::jsonb,
  'AIG1-C4 (1): rejecting an expired proposal is refused not_open (no decision without content)');
select is(pg_temp.decide(4, 'confirmed', null, 11), '{"result": "refused", "reason": "not_open"}'::jsonb,
  'AIG1-C4 (1): confirming an expired proposal is refused not_open');
select ok(pg_temp.confs(4) = 0 and (select count(*) = 1 from public.ai_suggestions where entity_id = pg_temp.v(4)),
  'AIG1-C4 (1): no confirmation row; the ledger row stays as it is (undecided)');

-- AIG1-C4 (2)/(3): never decided, never a correction; counted apart as expired ------------------------------------------
select is((select to_jsonb(w) from private.aig1_window_stats('00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse',
             private.at_zurich((pg_temp.t() - 2) + time '10:00'), private.at_zurich((pg_temp.t() - 1) + time '10:00')) w),
  '{"share": 0.00, "decided": 3, "corrections": 0}'::jsonb,
  'AIG1-C4 (2): the expired proposal is neither decided nor a correction in the window''s share');
select is(private.aig1_window_expired('00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse',
            private.at_zurich((pg_temp.t() - 2) + time '10:00'), private.at_zurich((pg_temp.t() - 1) + time '10:00')), 1,
  'AIG1-C4 (3): the window counts one expired proposal (the open undecided one is not expired)');
select is(pg_temp.health() - 'stop_id' - 'stops',
  '{"state": "on", "last_window_decided": 3, "last_window_expired": 1}'::jsonb,
  'AIG1-C4 (3): the health list shows the expired count next to the decided count');

-- AIG1-C5 (a)/(b): a stop with open lines stays followed up when the agent is switched off -------------------------------
update public.ai_agent_definitions set version = '2' where key = 'aig1_test_primary_nurse';
select is(pg_temp.propose(6, 12) ->> 'result', 'agent_stopped', 'fixture: the changed version stops the agent');
insert into stops select 1, id from public.ai_agent_stops order by seq desc limit 1;
select is(pg_temp.detail(1), '[{"detail": "Testassistent Bezugspflege · Werte: 3 offen · 0 nicht mehr offen"}]'::jsonb,
  'fixture: one exception for the stop with its three open lines');
select is(pg_temp.switch(false, 13), 'ok', 'fixture: the administrator switches the stopped agent off');
select is(pg_temp.detail(1), '[{"detail": "Testassistent Bezugspflege · Werte: 3 offen · 0 nicht mehr offen"}]'::jsonb,
  'AIG1-C5 (a): after the switch-off the exception is still listed with "3 offen"');
select ok(pg_temp.health() ->> 'state' = 'off' and pg_temp.health() -> 'stop_id' = 'null'::jsonb
          and pg_temp.health_stop(1) = '{"open": 3, "not_open": 0}'::jsonb,
  'AIG1-C5 (b)/(c): the health list shows "off" as a status and still returns the stop with its open lines');
select is(pg_temp.switch(true, 14), 'ok', 'fixture: the administrator switches the agent on again');
select is(pg_temp.detail(1), '[{"detail": "Testassistent Bezugspflege · Werte: 3 offen · 0 nicht mehr offen"}]'::jsonb,
  'AIG1-C5 (a): after a new switch-on the exception is still listed with "3 offen"');

-- AIG1-C5: two stops of one agent, each with open lines, give two exceptions with their own counts ---------------------
select ok(pg_temp.propose(7, 15) ->> 'result' = 'ok' and pg_temp.decide(7, 'confirmed', null, 16) ->> 'result' = 'ok',
  'fixture: one proposal confirmed unchanged after the new switch-on');
update public.ai_agent_definitions set version = '3' where key = 'aig1_test_primary_nurse';
select is(pg_temp.propose(8, 17) ->> 'result', 'agent_stopped', 'fixture: a second version change stops the agent again');
insert into stops select 2, id from public.ai_agent_stops order by seq desc limit 1;
select ok(pg_temp.detail(1) = '[{"detail": "Testassistent Bezugspflege · Werte: 3 offen · 0 nicht mehr offen"}]'::jsonb
          and pg_temp.detail(2) = '[{"detail": "Testassistent Bezugspflege · Werte: 1 offen · 0 nicht mehr offen"}]'::jsonb,
  'AIG1-C5: two stops with open lines are two exceptions, each with its own counts');

-- CGR-106: "Ändern" on a listed value of an open visit -----------------------------------------------------------------
select is(pg_temp.decide(1, 'corrected', pg_temp.u('q6'), 18) ->> 'result', 'ok',
  'CGR-106: changing a listed value to a qualified member is ok');
select ok((select responsible_user_id = pg_temp.u('q6') from public.care_visits where id = pg_temp.v(1))
          and (select count(*) = 1 from public.visit_plan_changes where visit_id = pg_temp.v(1)
               and reason = 'Bestätigter Vorschlag (AIG1)' and after ->> 'responsible_id' = pg_temp.u('q6')::text)
          and (select count(*) = 1 from public.ai_confirmations where suggestion_id = pg_temp.sug(1) and outcome = 'corrected')
          and pg_temp.line(1, 1) is null
          and jsonb_array_length(pg_temp.rows('p', format('select * from public.record_lookback_lines(%L, %L)',
                                                          'care_visits', pg_temp.v(1)))) = 0,
  'CGR-106: the visit holds the new member, one plan change and one corrected row; the line leaves both lists');
select ok(pg_temp.decide(2, 'corrected', pg_temp.u('ca'), 19) = '{"result": "refused", "reason": "not_qualified"}'::jsonb
          and pg_temp.confs(2) = 1 and pg_temp.line(1, 2) is not null
          and (select responsible_user_id = pg_temp.u('r6') from public.care_visits where id = pg_temp.v(2)),
  'CGR-106: a change to a member not qualified for the B minutes is refused not_qualified; no row, the line stays');
update public.care_visits set responsible_user_id = pg_temp.u('q6') where id = pg_temp.v(3);
select ok(pg_temp.decide(3, 'corrected', pg_temp.u('p'), 20) = '{"result": "refused", "reason": "already_taken"}'::jsonb
          and pg_temp.line(1, 3) ->> 'superseded' = 'true',
  'CGR-106: after a hand reassignment a change is refused already_taken and the line reads superseded');

-- AIG1-C5 (a)/(b): at "0 offen" the exception closes by itself; the stop stays readable as history ---------------------
select ok(pg_temp.decide(2, 'confirmed', null, 21) ->> 'result' = 'ok'
          and pg_temp.detail(1) = '[]'::jsonb
          and pg_temp.detail(2) = '[{"detail": "Testassistent Bezugspflege · Werte: 1 offen · 0 nicht mehr offen"}]'::jsonb,
  'AIG1-C5 (a): with its last open line handled the first stop''s exception is gone; the second stays');
select ok(pg_temp.decide(7, 'confirmed', null, 22) ->> 'result' = 'ok'
          and (select count(*) = 0 from private.derived_exceptions('00000000-0000-4000-b000-000000000011')
               where exception_type = 'agent_stopped')
          and (select state = 'stopped' from public.ai_agent_settings
               where organization_id = '00000000-0000-4000-b000-000000000011' and agent_key = 'aig1_test_primary_nurse'),
  'AIG1-C5 (a): every line handled: no exception while the agent stays stopped ("0 offen" is never an exception)');
select ok(pg_temp.health_stop(1) = '{"open": 0, "not_open": 0}'::jsonb and pg_temp.health_stop(2) = '{"open": 0, "not_open": 0}'::jsonb
          and pg_temp.health() ->> 'stop_id' = pg_temp.stop(2)::text
          and (pg_temp.health() -> 'stops' -> 0 ->> 'stop_id') = pg_temp.stop(2)::text,
  'AIG1-C5 (b)/(c): both stops stay readable as history with their counts, newest first; the status names the current stop');
select is((select string_agg(a, ',') from unnest((select proargnames from pg_proc where oid = 'public.agent_health(uuid)'::regprocedure)) a
           where a ~ '(confirm|outcome|status|user|person|member|actor|by$|nurse)'), null,
  'AIG1-C5 (e) / AIG1-11 (4): the health list has no person column');

select * from finish();
rollback;
