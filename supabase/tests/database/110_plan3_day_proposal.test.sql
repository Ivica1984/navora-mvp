-- PLAN3 part (a): day-plan and continuity proposal (migration 0109, ADR-145). Brief `docs/agents/briefs/PLAN3.md`
-- (PLAN3-1 to -6, -8, -10). All data synthetic; no AI service is called.
-- Seed users (Testorganisation A …011): pflege …902 (RN, Nord) · ops …904 · admin …905 · coach …901.
-- Synthetic here: team "Synth Team PLAN3" a1100000-…-000000000001; members r1-r4 registered nurses, ca a care assistant,
-- r6 a registered nurse whose contract ends before day D, r7 a registered nurse whose access ended. Cases K1 (primary
-- r1, deputy r2), K2 (none; r3 performed two of its visits in the last 90 days), K3 (none).
begin;
create extension if not exists pgtap with schema extensions;

select plan(72);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ops' then '00000000-0000-4000-a000-000000000904'
                 when 'admin' then '00000000-0000-4000-a000-000000000905' when 'coach' then '00000000-0000-4000-a000-000000000901'
                 when 'r1' then 'a1100000-0000-4000-a000-0000000000a1' when 'r2' then 'a1100000-0000-4000-a000-0000000000a2'
                 when 'r3' then 'a1100000-0000-4000-a000-0000000000a3' when 'r4' then 'a1100000-0000-4000-a000-0000000000a4'
                 when 'ca' then 'a1100000-0000-4000-a000-0000000000a5' when 'r6' then 'a1100000-0000-4000-a000-0000000000a6'
                 when 'r7' then 'a1100000-0000-4000-a000-0000000000a7' end)::uuid
$$;
create function pg_temp.team() returns uuid language sql immutable as $$ select 'a1100000-0000-4000-a000-000000000001'::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000011'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1101000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.c(n int) returns uuid language sql immutable as $$
  select ('a1100000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1100000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.res(p_user text, p_sql text) returns text language sql as $$
  select coalesce(r ->> 'result', r #>> '{}') from (select pg_temp.cmd(p_user, p_sql) as r) s $$;
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
  perform pg_temp.rows(p_user, p_sql);
  return 'none';
exception when others then
  execute 'reset role';
  return sqlstate;
end $$;
create function pg_temp.ask(p_user text, p_day int, p_include boolean, key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.propose_day_plan(%L, %L, %L, %L)', pg_temp.team(), pg_temp.t() + p_day,
                                    p_include, pg_temp.k(key))) $$;
create function pg_temp.switch(p_user text, p_on boolean, key int) returns text language sql as $$
  select pg_temp.res(p_user, format('select public.set_team_day_proposal(%L, %L, %L)', pg_temp.team(), p_on, pg_temp.k(key))) $$;
-- The newest PLAN3 ledger row of visit n, and the line the reader returns for it.
create function pg_temp.sug(n int) returns uuid language sql stable as $$
  select s.id from public.ai_suggestions s where s.entity_id = pg_temp.v(n) and s.agent_key = 'plan3_day_proposal'
  order by s.seq desc limit 1 $$;
create function pg_temp.line(n int) returns public.day_plan_lines language sql stable as $$
  select l from public.day_plan_lines l where l.suggestion_id = pg_temp.sug(n) $$;
create function pg_temp.proposed(n int) returns uuid language sql stable as $$
  select (s.proposed_value #>> '{}')::uuid from public.ai_suggestions s where s.id = pg_temp.sug(n) $$;
create function pg_temp.resp(n int) returns uuid language sql stable as $$
  select responsible_user_id from public.care_visits where id = pg_temp.v(n) $$;
create function pg_temp.reader(p_user text, p_day int) returns jsonb language sql as $$
  select pg_temp.rows(p_user, format('select * from public.day_plan(%L, %L)', pg_temp.team(), pg_temp.t() + p_day)) $$;
create function pg_temp.ledger() returns int language sql stable as $$
  select count(*)::int from public.ai_suggestions where agent_key = 'plan3_day_proposal' $$;
create function pg_temp.visits_hash() returns text language sql stable as $$
  select md5(string_agg(to_jsonb(v)::text, '|' order by v.id)) from public.care_visits v where v.team_id = pg_temp.team() $$;

-- Fixtures (as the table owner) ----------------------------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), 'plan3-' || n || '@navora.test' from unnest(array['r1', 'r2', 'r3', 'r4', 'ca', 'r6', 'r7']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['r1', 'r2', 'r3', 'r4', 'ca', 'r6', 'r7']) n;
insert into public.member_profiles (organization_id, user_id, display_name)
select pg_temp.org(), pg_temp.u(n), 'Synth ' || upper(n) from unnest(array['r1', 'r2', 'r3', 'r4', 'ca', 'r6', 'r7']) n;
insert into public.teams (organization_id, id, name, region, status)
values (pg_temp.org(), pg_temp.team(), 'Synth Team PLAN3', 'Bern Nord', 'active');
insert into public.team_memberships (team_id, user_id, qualification)
select pg_temp.team(), pg_temp.u(n), case n when 'ca' then 'care_assistant' else 'registered_nurse' end
from unnest(array['r1', 'r2', 'r3', 'r4', 'ca', 'r6', 'r7']) n;
-- r6: contract ends the day before D (access still open today). r7: access ended.
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id)
values (pg_temp.org(), pg_temp.u('r6'), pg_temp.t() - 100, pg_temp.t() + 1, pg_temp.u('admin'));
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
values (pg_temp.org(), pg_temp.u('r7'), 'ended', 'access_withdrawn', pg_temp.u('admin'));
-- Cases: copies of the seeded case 208 in the synthetic team, no automatic planning.
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.c(n), 'assigned_team_id', pg_temp.team(),
          'auto_planning', false, 'primary_nurse_id', case when n = 1 then pg_temp.u('r1') end,
          'deputy_nurse_id', case when n = 1 then pg_temp.u('r2') end, 'proposed_primary_nurse_id', null))).*
from kc k, generate_series(1, 3) n;
-- Visits. Day D = T+2: V1-V6, V7 and V10 assigned to r3, V11. D3 = T+4: V12 (assigned r4), V13. D2 = T+5: V14.
create function pg_temp.mk(n int, k int, d int, s time, e time, a int, b int, resp text, st text default 'planned')
returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                  billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
  values (pg_temp.org(), pg_temp.v(n), pg_temp.c(k), pg_temp.team(), pg_temp.t() + d, s, e, array['Grundpflege'], false, st,
          a, b, pg_temp.u(resp)) $$;
select pg_temp.mk(1, 1, 2, '08:00', '08:30', 30, 0, null);
select pg_temp.mk(2, 1, 2, '08:15', '08:45', 30, 0, null);
select pg_temp.mk(3, 2, 2, '09:00', '09:30', 30, 0, null);
select pg_temp.mk(4, 3, 2, '10:00', '10:30', 0, 30, null);
select pg_temp.mk(5, 3, 2, '10:00', '10:30', 30, 0, null);
select pg_temp.mk(6, 1, 2, '12:00', '12:20', 20, 0, null);
select pg_temp.mk(7, 2, 2, '14:00', '14:30', 30, 0, 'r3');
select pg_temp.mk(10, 3, 2, '16:00', '16:30', 30, 0, 'r3');
select pg_temp.mk(11, 2, 2, '16:15', '16:45', 30, 0, null);
select pg_temp.mk(12, 2, 4, '09:00', '09:30', 30, 0, 'r4');
select pg_temp.mk(13, 1, 4, '10:00', '10:30', 30, 0, null);
select pg_temp.mk(14, 3, 5, '08:00', '08:30', 0, 30, null);
-- History of K2: r3 performed two completed visits in the last 90 days, r4 one 100 days ago (outside the window).
select pg_temp.mk(20, 2, -10, '09:00', '09:30', 30, 0, 'r3', 'completed');
select pg_temp.mk(21, 2, -20, '09:00', '09:30', 30, 0, 'r3', 'completed');
select pg_temp.mk(22, 2, -100, '09:00', '09:30', 30, 0, 'r4', 'completed');
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, occurred_at, actor_id)
select pg_temp.org(), pg_temp.v(n), pg_temp.team(), 'started', 'on_the_way', 'started',
       private.at_zurich(pg_temp.t() + d + time '09:00'), pg_temp.u(who)
from (values (20, -10, 'r3'), (21, -20, 'r3'), (22, -100, 'r4')) x(n, d, who);
-- r1 absent around V6 on D; r1-r4 absent all of D2.
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
values (pg_temp.org(), pg_temp.team(), pg_temp.u('r1'), private.at_zurich(pg_temp.t() + 2 + time '11:00'),
        private.at_zurich(pg_temp.t() + 2 + time '13:00'), pg_temp.u('r1'));
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
select pg_temp.org(), pg_temp.team(), pg_temp.u(n), private.at_zurich(pg_temp.t() + 5 + time '00:00'),
       private.at_zurich(pg_temp.t() + 6 + time '00:00'), pg_temp.u(n)
from unnest(array['r1', 'r2', 'r3', 'r4']) n;

-- PLAN3-6: the agent in the register, off by default --------------------------------------------------------------------------
select ok((select level = 'L' and kind = 'rule' and provider is null and fixture = 'aig1_eval_plan3_day_proposal'
           and eval_bar = 100 and brief = 'PLAN3' from public.ai_agent_definitions where key = 'plan3_day_proposal'),
  'PLAN3-6: plan3_day_proposal is registered as a level-L rule agent with its fixture');
select is((select class from public.ai_agent_fields where agent_key = 'plan3_day_proposal' and field = 'responsible_user_id'),
  'schedule', 'PLAN3-5: its field is the visit''s responsible member, class schedule (CGR-78)');
select is((select count(*)::int from private.aig1_eval_plan3_day_proposal() where expected is distinct from actual), 0,
  'PLAN3-3 / AIG1-9: every synthetic fixture case gives the expected member, reason or limit');
-- Scoped to the test organisation: the seed switches the agent on for Testorganisation H (PLAN3 part (b) e2e, ADR-147).
select is((select count(*)::int from public.ai_agent_settings where agent_key = 'plan3_day_proposal'
           and organization_id = pg_temp.org()), 0,
  'PLAN3-6: off by default (no settings row for an organisation that has not switched it on)');
select is(pg_temp.ask('r1', 2, false, 1) ->> 'reason', 'agent_off',
  'PLAN3-6: with the agent off a team member''s request is refused');
select is(pg_temp.rows('r1', format('select agent_state from public.team_day_proposal_state(%L)', pg_temp.team())) -> 0 ->> 'agent_state',
  'off', 'PLAN3-6: the team reads the agent state ("Vorschlag zurzeit nicht verfügbar")');
select is(pg_temp.res('admin', format('select public.set_agent_state(%L, %L, true, 50, 20, 7, %L)', pg_temp.org(),
            'plan3_day_proposal', pg_temp.k(2))), 'ok', 'PLAN3-6: the administrator switches the agent on with its threshold');

-- PLAN3-10: the team switch ------------------------------------------------------------------------------------------------
select is(pg_temp.ask('r1', 2, false, 3) ->> 'reason', 'team_off', 'PLAN3-10: with the team switch off the request is refused');
select is(pg_temp.ledger(), 0, 'PLAN3-10: a refused request writes no ledger row');
select is(pg_temp.rows('r2', format('select * from public.team_day_proposal_state(%L)', pg_temp.team())) -> 0 ->> 'team_enabled',
  'false', 'PLAN3-10: default off per team');
select is(pg_temp.switch('p', true, 4), 'rejected', 'PLAN3-10: a member of another team is refused');
select is(pg_temp.switch('ops', true, 5), 'rejected', 'PLAN3-10: Operations is refused');
select is(pg_temp.switch('coach', true, 6), 'rejected', 'PLAN3-10: a coach is refused');
select is(pg_temp.switch('admin', true, 7), 'rejected', 'PLAN3-10: the administrator is refused');
select is(pg_temp.err('r7', format('select public.set_team_day_proposal(%L, true, %L)', pg_temp.team(), pg_temp.k(8))),
  '42501', 'PLAN3-10: a member whose access ended is refused (LEAVE1-3)');
select is((select count(*)::int from public.team_day_proposal_settings where team_id = pg_temp.team()), 0,
  'PLAN3-10: no refused switch wrote a setting');
select is(pg_temp.switch('r1', true, 9), 'ok', 'PLAN3-10: a member of the team switches it on');
select is(pg_temp.switch('r2', true, 10), 'unchanged', 'PLAN3-10: switching on again changes nothing');
select ok((select count(*) = 1 and bool_and(a.actor_id = pg_temp.u('r1') and a.command = 'set_team_day_proposal'
                                            and a.changed -> 'team_id' ->> 'new' = pg_temp.team()::text
                                            and a.changed -> 'enabled' ->> 'new' = 'true')
           from public.audit_events a where a.table_name = 'team_day_proposal_settings'),
  'PLAN3-10: the switch is audited with its actor and names the team');
select is(pg_temp.rows('r2', format('select team_enabled, enabled_since, agent_state from public.team_day_proposal_state(%L)',
            pg_temp.team())) -> 0, jsonb_build_object('team_enabled', true, 'enabled_since', pg_temp.t(), 'agent_state', 'on'),
  'PLAN3-10: the team sees "eingeschaltet am <Datum>" and the agent on, with no name');
select is((select count(*)::int from information_schema.columns where table_schema = 'public'
           and table_name = 'team_day_proposal_settings' and column_name ~ '(actor|_by$|user)'), 0,
  'PLAN3-10: the setting has no actor column');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
             and (p.prosrc ~ 'team_day_proposal_settings'
                  or exists (select 1 from unnest(p.proargnames, p.proargmodes) a(nm, md)
                             where md in ('t', 'o') and nm ~ '(switched_by|switch_actor)'))
             and (p.prosrc ~ 'audit_events'
                  or exists (select 1 from unnest(p.proargnames, p.proargmodes) a(nm, md)
                             where md in ('t', 'o') and nm ~ '(actor|_by$|user)'))), null,
  'PLAN3-10: no reader granted to authenticated returns the switch actor');
select is((select count(*)::int from jsonb_array_elements(pg_temp.rows('admin', format(
            'select * from public.read_audit_record(%L, %L, %L)', 'team_day_proposal_settings',
            (select id from public.team_day_proposal_settings where team_id = pg_temp.team()), 'compliance'))) e
           where e ->> 'actor_id' = pg_temp.u('r1')::text), 1,
  'PLAN3-10: read_audit_record returns the switch actor for that one record');

-- PLAN3-8: scope ------------------------------------------------------------------------------------------------------------
select is(pg_temp.err('p', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.t() + 2,
            pg_temp.k(11))), '42501', 'PLAN3-8: a member of another team cannot ask');
select is(pg_temp.err('ops', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.t() + 2,
            pg_temp.k(12))), '42501', 'PLAN3-8: Operations cannot ask');
select is(pg_temp.err('coach', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.t() + 2,
            pg_temp.k(13))), '42501', 'PLAN3-8: a coach cannot ask');

-- PLAN3-1: the proposal for one team and one day ------------------------------------------------------------------------------
select is(pg_temp.ask('r2', 15, false, 14) ->> 'reason', 'date_out_of_range', 'PLAN3-1: more than 14 days ahead is refused');
select is(pg_temp.ask('r2', -1, false, 15) ->> 'reason', 'date_out_of_range', 'PLAN3-1: a past day is refused');
create temp table h0 as select pg_temp.visits_hash() as h;
select is(pg_temp.ask('r2', 2, false, 16) - 'proposal_id', '{"result":"ok","lines":7,"not_found":0}'::jsonb,
  'PLAN3-1: one line per unassigned open visit of the day (V1-V6, V11)');
select is(pg_temp.visits_hash(), (select h from h0), 'PLAN3-1: the visit rows are unchanged after a proposal');
select is(pg_temp.sug(7), null, 'PLAN3-1: an assigned visit is not proposed without "auch zugewiesene neu vorschlagen"');
select is((select count(distinct proposal_id)::int from public.ai_suggestions where agent_key = 'plan3_day_proposal'), 1,
  'AIG1-2: the lines of one proposal share one proposal id in the ledger');

-- PLAN3-3: continuity order, stated --------------------------------------------------------------------------------------------
select is(array[pg_temp.proposed(1)::text, (pg_temp.line(1)).reason], array[pg_temp.u('r1')::text, 'primary_nurse'],
  'PLAN3-3: the primary nurse first ("Bezugspflegende")');
select is(array[pg_temp.proposed(2)::text, (pg_temp.line(2)).reason], array[pg_temp.u('r2')::text, 'deputy'],
  'PLAN3-3: the deputy when the primary nurse overlaps ("Stellvertretung")');
select is(array[pg_temp.proposed(3)::text, (pg_temp.line(3)).reason, (pg_temp.line(3)).known_visits::text],
  array[pg_temp.u('r3')::text, 'knows_client', '2'], 'PLAN3-3: then the member who knows the client (2 visits in 90 days)');
select is(array[pg_temp.proposed(4)::text, (pg_temp.line(4)).reason], array[pg_temp.u('r4')::text, 'free_capacity'],
  'PLAN3-3: then the fewest planned minutes ("freie Kapazität")');
select is(pg_temp.proposed(5), pg_temp.u('ca'), 'PLAN3-3: a care assistant with free capacity takes an A-only visit');
select is(array[pg_temp.proposed(6)::text, (pg_temp.line(6)).reason], array[pg_temp.u('r2')::text, 'deputy'],
  'PLAN3-3: the deputy when the primary nurse is absent');
select is(array[pg_temp.proposed(11)::text, (pg_temp.line(11)).reason], array[pg_temp.u('r1')::text, 'free_capacity'],
  'PLAN3-3: ties on minutes are broken by the member id (stable key)');
select is((select jsonb_agg(jsonb_build_array(l.visit_id, l.member_id, l.reason, l.known_visits, l.not_found_reason)
                            order by l.visit_id)
           from private.plan3_lines(pg_temp.team(), pg_temp.t() + 2, false) l),
          (select jsonb_agg(jsonb_build_array(l.visit_id, (s.proposed_value #>> '{}')::uuid, l.reason, l.known_visits,
                                              l.not_found_reason) order by l.visit_id)
           from public.day_plan_lines l join public.ai_suggestions s on s.id = l.suggestion_id),
  'PLAN3-3: the same input gives the same proposal');

-- PLAN3-2: hard limits, never broken ----------------------------------------------------------------------------------------
select is((select count(*)::int from public.ai_suggestions where agent_key = 'plan3_day_proposal'
           and proposed_value #>> '{}' = pg_temp.u('r6')::text), 0, 'PLAN3-2: a member whose contract ends before the day is not proposed');
select is((select count(*)::int from public.ai_suggestions where agent_key = 'plan3_day_proposal'
           and proposed_value #>> '{}' = pg_temp.u('r7')::text), 0, 'PLAN3-2: a member whose access ended is not proposed');
select isnt(pg_temp.proposed(4), pg_temp.u('ca'), 'PLAN3-2: a care assistant is not proposed for a visit with B minutes');
select isnt(pg_temp.proposed(6), pg_temp.u('r1'), 'PLAN3-2: an absent member is not proposed');
select ok(pg_temp.proposed(2) <> pg_temp.u('r1') and pg_temp.proposed(11) <> pg_temp.u('r3'),
  'PLAN3-2: an overlap with a proposed (V1) or an assigned visit (V10) excludes the member');

-- PLAN3-9 / PLAN3-4: the readers -----------------------------------------------------------------------------------------------
select is((select jsonb_agg(jsonb_build_array(e ->> 'member_name', e ->> 'reason', e ->> 'not_continuity', e ->> 'decision')
                            order by e ->> 'time_start', e ->> 'visit_id')
           from jsonb_array_elements(pg_temp.reader('r3', 2)) e) -> 0,
  '["Synth R1", "primary_nurse", "false", "open"]'::jsonb, 'PLAN3-9: the reader returns member, reason and state per line');
select is((select (e ->> 'not_continuity')::boolean from jsonb_array_elements(pg_temp.reader('r3', 2)) e
           where e ->> 'visit_id' = pg_temp.v(11)::text), true, 'PLAN3-9: "nicht Bezugspflege/Stellvertretung" is flagged');
select is(jsonb_array_length(pg_temp.reader('p', 2)), 0, 'PLAN3-8: a member of another team reads no line');
select is(jsonb_array_length(pg_temp.reader('ops', 2)), 0, 'PLAN3-8: Operations reads no line');
select is((select jsonb_object_agg(e ->> 'member_name', jsonb_build_array((e ->> 'minutes_now')::int,
                                                                          (e ->> 'minutes_with_proposal')::int))
           from jsonb_array_elements(pg_temp.rows('r1', format('select * from public.day_plan_load(%L, %L)', pg_temp.team(),
                                                                pg_temp.t() + 2))) e
           where e ->> 'member_name' in ('Synth R2', 'Synth R3', 'Synth R4')),
  '{"Synth R2": [0, 50], "Synth R3": [60, 90], "Synth R4": [0, 30]}'::jsonb,
  'PLAN3-4: planned minutes per member now and with the proposal (no maximum)');
-- PLAN3-15 (0116, ADR-157): a second request is no longer refused `open_proposal`; it closes the seven undecided
-- lines and writes the same seven again (the rest of this file decides the new lines). Details in pgTAP 116.
select is(pg_temp.ask('r3', 2, false, 17) - 'proposal_id', '{"result":"ok","lines":7,"not_found":0,"closed":7}'::jsonb,
  'PLAN3-1/-15: a second request for the same day replaces the undecided lines');

-- PLAN3-5: confirm in the team ------------------------------------------------------------------------------------------------
select is(pg_temp.cmd('r2', format('select public.confirm_suggestions(%L::uuid[], %L)',
            array[pg_temp.sug(1), pg_temp.sug(2), pg_temp.sug(4)], pg_temp.k(18))) - 'refused',
  '{"result":"ok","confirmed":3}'::jsonb, 'PLAN3-5: a ticked list of three lines is confirmed');
select is((select count(*)::int from public.ai_confirmations c where c.suggestion_id in (pg_temp.sug(1), pg_temp.sug(2), pg_temp.sug(4))
           and c.bulk and c.outcome = 'confirmed' and c.confirmed_by = pg_temp.u('r2')), 3,
  'PLAN3-5: three AIG1 confirmation rows');
select ok(pg_temp.resp(1) = pg_temp.u('r1') and pg_temp.resp(2) = pg_temp.u('r2') and pg_temp.resp(4) = pg_temp.u('r4'),
  'PLAN3-5: the responsible members are set through the J3 path');
select is(pg_temp.res('r2', format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', pg_temp.sug(3), 'corrected',
            to_jsonb(pg_temp.u('r4')::text)::text, pg_temp.k(19))), 'ok', 'PLAN3-5: a changed line is a correction');
select ok(pg_temp.resp(3) = pg_temp.u('r4') and (select outcome from public.ai_confirmations where suggestion_id = pg_temp.sug(3)) = 'corrected',
  'PLAN3-5: the corrected member is set and the ledger shows corrected');
-- The care assistant is recorded absent after the proposal: her line fails the J3 check at confirm time.
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
values (pg_temp.org(), pg_temp.team(), pg_temp.u('ca'), private.at_zurich(pg_temp.t() + 2 + time '09:45'),
        private.at_zurich(pg_temp.t() + 2 + time '11:00'), pg_temp.u('ca'));
select is(pg_temp.cmd('r1', format('select public.confirm_suggestions(%L::uuid[], %L)', array[pg_temp.sug(5), pg_temp.sug(6)],
            pg_temp.k(20))), jsonb_build_object('result', 'ok', 'confirmed', 1,
            'refused', jsonb_build_array(jsonb_build_object('suggestion_id', pg_temp.sug(5), 'reason', 'absent'))),
  'PLAN3-5: a line that fails a J3 check at confirm time is reported, the other is set');
select ok(pg_temp.resp(5) is null and pg_temp.resp(6) = pg_temp.u('r2'), 'PLAN3-5: the refused visit stays unassigned');
select is((select jsonb_object_agg(e ->> 'visit_id', e ->> 'decision') from jsonb_array_elements(pg_temp.reader('r1', 2)) e
           where e ->> 'visit_id' in (pg_temp.v(1)::text, pg_temp.v(3)::text, pg_temp.v(5)::text)),
  jsonb_build_object(pg_temp.v(1)::text, 'confirmed', pg_temp.v(3)::text, 'corrected', pg_temp.v(5)::text, 'open'),
  'PLAN3-9: the reader shows each line''s decision, no confirmer');

-- "auch zugewiesene neu vorschlagen" -------------------------------------------------------------------------------------------
select is(pg_temp.ask('r1', 4, true, 21) - 'proposal_id', '{"result":"ok","lines":2,"not_found":0}'::jsonb,
  'PLAN3-1: with "auch zugewiesene" the assigned visit is proposed too');
select is((select (e ->> 'changes_assignment')::boolean from jsonb_array_elements(pg_temp.reader('r1', 4)) e
           where e ->> 'visit_id' = pg_temp.v(12)::text), true, 'PLAN3-9: "ändert bisherige Zuteilung" is flagged');
select is(pg_temp.res('r1', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug(12), 'confirmed',
            pg_temp.k(22))), 'ok', 'PLAN3-5: a re-proposed assigned visit is confirmed against the member it had');
select is(pg_temp.resp(12), pg_temp.u('r3'), 'PLAN3-5: the visit now has the proposed member');

-- "kein Vorschlag" with its reason ---------------------------------------------------------------------------------------------
select is(pg_temp.ask('r1', 5, false, 23) - 'proposal_id', '{"result":"ok","lines":1,"not_found":1}'::jsonb,
  'PLAN3-1: a visit nobody may take gets "kein Vorschlag"');
select is(pg_temp.reader('r1', 5) -> 0 ->> 'not_found_reason', 'absent',
  'PLAN3-1: "kein Vorschlag" names the closest limit (every registered nurse absent)');

-- PLAN3-10: the team switches it off again ------------------------------------------------------------------------------------
select is(pg_temp.switch('r2', false, 25), 'ok', 'PLAN3-10: any member of the team switches it off');
select is(pg_temp.ask('r1', 3, false, 26) ->> 'reason', 'team_off', 'PLAN3-10: switched off, no proposal');
select is(pg_temp.switch('r3', true, 27), 'ok', 'PLAN3-10: and on again');

-- PLAN3-6: stopped ---------------------------------------------------------------------------------------------------------------
select ok(private.aig1_stop(pg_temp.org(), 'plan3_day_proposal', 'threshold', private.now() - interval '7 days', private.now(), 20, 80)
          is not null, 'setup: the agent stops on its threshold');
create temp table l0 as select pg_temp.ledger() as n;
select is(pg_temp.ask('r1', 3, false, 24) ->> 'reason', 'agent_stopped',
  'PLAN3-10: with the agent stopped and the team on, the request is refused as stopped');
select is(pg_temp.ledger(), (select n from l0), 'PLAN3-6: a stopped agent writes no ledger row');
select is(pg_temp.rows('r1', format('select agent_state from public.team_day_proposal_state(%L)', pg_temp.team())) -> 0 ->> 'agent_state',
  'stopped', 'PLAN3-6: the team reads "stopped" and plans by hand');

select * from finish();
rollback;
