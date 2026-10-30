-- AIG1-15 and AIG1-16 (migration 0103, ADR-128). Brief `docs/agents/briefs/AIG1.md`. All data synthetic; no AI
-- service is called.
-- Seed users: pflege …902 "p" (RN, Nord …101) · assist …906 "ca" (CA, Nord) · ops …904 · admin …905 (org A …011).
-- Synthetic user added here: a1030000-…-010301 "r1", a registered nurse of Nord and the primary nurse of case …208, so
-- the synthetic test agent proposes her. Visits a1030000-…-8000-0000000001xx are created here.
begin;
create extension if not exists pgtap with schema extensions;

select plan(25);

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
                 when 'r1' then 'a1030000-0000-4000-a000-000000010301' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1031000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1030000-0000-4000-8000-' || lpad((100 + n)::text, 12, '0'))::uuid $$;
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
create function pg_temp.switch(p_share numeric, key int) returns jsonb language sql as $$
  select pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, %s, 2, 7, %L)',
                     '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', p_share, pg_temp.k(key))) $$;
create function pg_temp.propose(n int, key int) returns uuid language sql as $$
  select (pg_temp.cmd('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(n), pg_temp.k(key)))
          ->> 'suggestion_id')::uuid $$;
create function pg_temp.sug(n int) returns uuid language sql stable as $$
  select s.id from public.ai_suggestions s where s.entity_id = pg_temp.v(n) order by s.seq desc limit 1 $$;
-- "p" confirms the proposal for visit n unchanged; returns {result, reason}.
create function pg_temp.confirm(n int, key int) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug(n), 'confirmed',
                                 pg_temp.k(key))) $$;
create function pg_temp.confs() returns int language sql stable as $$
  select count(*)::int from public.ai_confirmations c join public.ai_suggestions s on s.id = c.suggestion_id
  where s.entity_id in (select pg_temp.v(n) from generate_series(1, 10) n) $$;
create temp table stop1 (id uuid);
create function pg_temp.listed(n int) returns boolean language sql as $$
  select exists (select 1 from jsonb_array_elements(pg_temp.rows('ops', format(
                   'select entity_id from public.agent_stop_lookback(%L)', (select id from stop1)))) e
                 where e ->> 'entity_id' = pg_temp.v(n)::text) $$;
create function pg_temp.health() returns jsonb language sql as $$
  select pg_temp.rows('ops', format('select stop_share, stop_min_proposals, stop_window_days, last_window_decided, '
                                    'last_window_min_reached from public.agent_health(%L) where agent_key = %L',
                                    '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse')) -> 0 $$;

-- Fixtures (as the table owner): r1, the primary nurse of case 208; unassigned Nord visits of case 208:
-- 1 on T+2 08:00 with B minutes (needs a registered nurse), 2 on T+2 09:00, 3 on T+3 08:00, 4 on T+2 10:00,
-- 5 on T+2 11:00 (proposed after the stop), 6-8 on T+30 to T+32 (the threshold windows).
insert into auth.users (id, email) values (pg_temp.u('r1'), 'aig1-15-r1@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('r1'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u('r1'), 'registered_nurse');
update public.cases set primary_nurse_id = pg_temp.u('r1') where id = '00000000-0000-4000-a000-000000000208';
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.t() + d, s, s + interval '15 minutes', array['Grundpflege'], false,
       'planned', case when n = 1 then 0 else 15 end, case when n = 1 then 15 else 0 end
from (values (1, 2, time '08:00'), (2, 2, time '09:00'), (3, 3, time '08:00'), (4, 2, time '10:00'), (5, 2, time '11:00'),
             (6, 30, time '08:00'), (7, 31, time '08:00'), (8, 32, time '08:00')) f(n, d, s);

-- AIG1-15: four values confirmed unchanged, then the agent stops (version change) ------------------------------------------
select is(pg_temp.switch(50, 1) ->> 'result', 'ok', 'fixture: the synthetic test agent is switched on');
select ok(pg_temp.propose(1, 2) is not null and pg_temp.propose(2, 3) is not null and pg_temp.propose(3, 4) is not null
          and pg_temp.propose(4, 5) is not null, 'fixture: four proposals of r1');
select ok(pg_temp.confirm(1, 6) ->> 'result' = 'ok' and pg_temp.confirm(2, 7) ->> 'result' = 'ok'
          and pg_temp.confirm(3, 8) ->> 'result' = 'ok' and pg_temp.confirm(4, 9) ->> 'result' = 'ok',
  'fixture: the four confirmed unchanged');
select ok((select count(*) = 4 from public.care_visits where id in (pg_temp.v(1), pg_temp.v(2), pg_temp.v(3), pg_temp.v(4))
                                                             and responsible_user_id = pg_temp.u('r1')),
  'fixture: the four visits hold her');
update public.ai_agent_definitions set version = '2' where key = 'aig1_test_primary_nurse';
select is(pg_temp.cmd('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(5), pg_temp.k(10))) ->> 'result',
  'agent_stopped', 'fixture: the changed version stops the agent');
insert into stop1 select id from public.ai_agent_stops order by seq desc limit 1;
select ok(pg_temp.listed(1) and pg_temp.listed(2) and pg_temp.listed(3) and pg_temp.listed(4),
  'fixture: the look-back lists the four visits');
create temp table c0 as select pg_temp.confs() as n;

-- (i) qualification removed, visit needs a registered nurse (B minutes) → not_qualified
update public.team_memberships set qualification = 'care_assistant'
where team_id = '00000000-0000-4000-a000-000000000101' and user_id = pg_temp.u('r1');
select is(pg_temp.confirm(1, 11), '{"result": "refused", "reason": "not_qualified"}'::jsonb,
  'AIG1-15 (i): re-confirming a member no longer qualified for the visit is refused not_qualified');
select ok(pg_temp.confs() = (select n from c0) and pg_temp.listed(1),
  'AIG1-15 (i): no ai_confirmations row is written and the line stays on the look-back list');
update public.team_memberships set qualification = 'registered_nurse'
where team_id = '00000000-0000-4000-a000-000000000101' and user_id = pg_temp.u('r1');

-- (ii) an absence recorded over the visit → absent
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101', pg_temp.u('r1'),
        private.at_zurich((pg_temp.t() + 2) + time '09:00'), private.at_zurich((pg_temp.t() + 2) + time '09:30'),
        pg_temp.u('admin'));
select is(pg_temp.confirm(2, 12), '{"result": "refused", "reason": "absent"}'::jsonb,
  'AIG1-15 (ii): re-confirming a member absent on the visit is refused absent');
select ok(pg_temp.confs() = (select n from c0) and pg_temp.listed(2),
  'AIG1-15 (ii): no ai_confirmations row is written and the line stays on the look-back list');

-- (iii) her contract ends before the visit → outside_contract
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('r1'), null, pg_temp.t() + 2, pg_temp.u('admin'));
select is(pg_temp.confirm(3, 13), '{"result": "refused", "reason": "outside_contract"}'::jsonb,
  'AIG1-15 (iii): re-confirming a member whose contract ends before the visit is refused outside_contract');
select ok(pg_temp.confs() = (select n from c0) and pg_temp.listed(3),
  'AIG1-15 (iii): no ai_confirmations row is written and the line stays on the look-back list');

-- (iv) the member still valid → ok, the line leaves
select is(pg_temp.confirm(4, 14) ->> 'result', 'ok', 'AIG1-15 (iv): re-confirming a still valid member is ok');
select ok(pg_temp.confs() = (select n from c0) + 1 and not pg_temp.listed(4),
  'AIG1-15 (iv): one ai_confirmations row is written and the line leaves the look-back list');

-- A visit no longer open (dated before today) is re-confirmed as built (Clinical Owner, D-17: UNKNOWN)
select pg_temp.at((pg_temp.t() + 4) + time '10:00');
select is(pg_temp.confirm(3, 15) ->> 'result', 'ok',
  'AIG1-15: a visit no longer open is re-confirmed as built, without the open-visit checks');
-- Her contract continues (newest row is current), so the threshold windows below can be confirmed.
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('r1'), null, null, pg_temp.u('admin'));

-- AIG1-16 (1): a share that can never be exceeded is refused ------------------------------------------------------------------
select is(pg_temp.switch(100, 20) - 'detail', '{"result": "refused", "reason": "threshold_missing"}'::jsonb,
  'AIG1-16 (1): a switch-on with stop share 100 is refused threshold_missing');
select is(pg_temp.switch(99, 21) ->> 'result', 'ok', 'AIG1-16 (1): a switch-on with stop share 99 is accepted');

-- AIG1-16 (2): the health row carries the written threshold and whether the last closed window reached the minimum -----
select is(pg_temp.health(),
  '{"stop_share": 99.00, "stop_min_proposals": 2, "stop_window_days": 7, "last_window_decided": null, "last_window_min_reached": null}'::jsonb,
  'AIG1-16 (2): share, minimum and window are shown; no closed window yet, so no reached flag');
select ok(pg_temp.propose(6, 22) is not null, 'fixture: one proposal in the first window');
select is(pg_temp.confirm(6, 23) ->> 'result', 'ok', 'fixture: decided in the first window');
select pg_temp.at((pg_temp.t() + 12) + time '10:00');
select is(pg_temp.health() - 'stop_share' - 'stop_window_days',
  '{"stop_min_proposals": 2, "last_window_decided": 1, "last_window_min_reached": false}'::jsonb,
  'AIG1-16 (2): one decided proposal below the minimum of two: reached false');
select ok(pg_temp.propose(7, 24) is not null and pg_temp.propose(8, 25) is not null,
  'fixture: two proposals in the second window');
select ok(pg_temp.confirm(7, 26) ->> 'result' = 'ok' and pg_temp.confirm(8, 27) ->> 'result' = 'ok',
  'fixture: both decided in the second window');
select pg_temp.at((pg_temp.t() + 19) + time '10:00');
select is(pg_temp.health() - 'stop_share' - 'stop_window_days',
  '{"stop_min_proposals": 2, "last_window_decided": 2, "last_window_min_reached": true}'::jsonb,
  'AIG1-16 (2): two decided proposals at the minimum of two: reached true');
select is((select string_agg(a, ',') from unnest((select proargnames from pg_proc where oid = 'public.agent_health(uuid)'::regprocedure)) a
           where a ~ '(confirm|outcome|status|user|person|member|actor|by$|nurse)'), null,
  'AIG1-16 (2): the health list has no person column');

select * from finish();
rollback;
