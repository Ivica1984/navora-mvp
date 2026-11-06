-- PLAN3-14 (`cra` CGR-136, PO 2026-11-05 14:50): a member is busy with every visit she is responsible for, in any team,
-- and overlap is checked again at confirm (migration 0110, ADR-146). Brief `docs/agents/briefs/PLAN3.md`. All data
-- synthetic; no AI service is called.
-- Seed users (Testorganisation A …011): admin …905.
-- Synthetic here: team A "Synth Team PLAN3-14 A" a1110000-…-000000000001 and team B "… B" …000000000002, same
-- organisation. m1 (RN, team A only) accepted a team-B cover; m2 (RN, teams A and B) has a team-B visit; m3, m4 (RN,
-- team A only). Cases KA1 (team A, primary m1), KA2 (team A, primary m2), KA3 (team A, primary m2), KB (team B).
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T. Day D = T+2.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'm1' then 'a1110000-0000-4000-a000-0000000000b1' when 'm2' then 'a1110000-0000-4000-a000-0000000000b2'
                 when 'm3' then 'a1110000-0000-4000-a000-0000000000b3' when 'm4' then 'a1110000-0000-4000-a000-0000000000b4'
            end)::uuid
$$;
create function pg_temp.ta() returns uuid language sql immutable as $$ select 'a1110000-0000-4000-a000-000000000001'::uuid $$;
create function pg_temp.tb() returns uuid language sql immutable as $$ select 'a1110000-0000-4000-a000-000000000002'::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000011'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1111000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.c(n int) returns uuid language sql immutable as $$
  select ('a1110000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1110000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.sug(n int) returns uuid language sql stable as $$
  select s.id from public.ai_suggestions s where s.entity_id = pg_temp.v(n) and s.agent_key = 'plan3_day_proposal'
  order by s.seq desc limit 1 $$;
create function pg_temp.proposed(n int) returns uuid language sql stable as $$
  select (s.proposed_value #>> '{}')::uuid from public.ai_suggestions s where s.id = pg_temp.sug(n) $$;
create function pg_temp.resp(n int) returns uuid language sql stable as $$
  select responsible_user_id from public.care_visits where id = pg_temp.v(n) $$;

-- Fixtures (as the table owner) ----------------------------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), 'plan314-' || n || '@navora.test' from unnest(array['m1', 'm2', 'm3', 'm4']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['m1', 'm2', 'm3', 'm4']) n;
insert into public.member_profiles (organization_id, user_id, display_name)
select pg_temp.org(), pg_temp.u(n), 'Synth ' || upper(n) from unnest(array['m1', 'm2', 'm3', 'm4']) n;
insert into public.teams (organization_id, id, name, region, status)
values (pg_temp.org(), pg_temp.ta(), 'Synth Team PLAN3-14 A', 'Bern Nord', 'active'),
       (pg_temp.org(), pg_temp.tb(), 'Synth Team PLAN3-14 B', 'Bern Nord', 'active');
insert into public.team_memberships (team_id, user_id, qualification)
select pg_temp.ta(), pg_temp.u(n), 'registered_nurse' from unnest(array['m1', 'm2', 'm3', 'm4']) n
union all select pg_temp.tb(), pg_temp.u('m2'), 'registered_nurse';
-- Cases: copies of the seeded case 208, no automatic planning.
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.c(n), 'assigned_team_id',
          case when n = 9 then pg_temp.tb() else pg_temp.ta() end,
          'auto_planning', false, 'primary_nurse_id', case n when 1 then pg_temp.u('m1') when 2 then pg_temp.u('m2')
                                                              when 3 then pg_temp.u('m2') end,
          'deputy_nurse_id', null, 'proposed_primary_nurse_id', null))).*
from kc k, unnest(array[1, 2, 3, 9]) n;
create function pg_temp.mk(n int, k int, team uuid, s time, e time, resp text) returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                  billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
  values (pg_temp.org(), pg_temp.v(n), pg_temp.c(k), team, pg_temp.t() + 2, s, e, array['Grundpflege'], false, 'planned',
          30, 0, pg_temp.u(resp)) $$;
-- Team B on D: VB1 09:00-09:30 covered by m1 (COVER1: responsible member, covered_by, cover_team_id; team stays B);
-- VB2 09:00-09:30 of m2 (her second team); VB3 11:00-11:30 still unassigned.
select pg_temp.mk(101, 9, pg_temp.tb(), '09:00', '09:30', 'm1');
update public.care_visits set covered_by = pg_temp.u('m1'), cover_team_id = pg_temp.ta() where id = pg_temp.v(101);
select pg_temp.mk(102, 9, pg_temp.tb(), '09:00', '09:30', 'm2');
select pg_temp.mk(103, 9, pg_temp.tb(), '11:00', '11:30', null);
-- Team A on D: VA1 09:15-09:45 (KA1, primary m1), VA2 09:15-09:45 (KA2, primary m2), VA3 11:00-11:30 (KA3, primary m2).
select pg_temp.mk(1, 1, pg_temp.ta(), '09:15', '09:45', null);
select pg_temp.mk(2, 2, pg_temp.ta(), '09:15', '09:45', null);
select pg_temp.mk(3, 3, pg_temp.ta(), '11:00', '11:30', null);

-- The agent on, team A's switch on.
select is(pg_temp.res('admin', format('select public.set_agent_state(%L, %L, true, 50, 20, 7, %L)', pg_temp.org(),
            'plan3_day_proposal', pg_temp.k(1))), 'ok', 'setup: the administrator switches the agent on');
select is(pg_temp.res('m3', format('select public.set_team_day_proposal(%L, true, %L)', pg_temp.ta(), pg_temp.k(2))), 'ok',
  'setup: a member of team A switches the day proposal on');

-- PLAN3-14 (1): busy with every visit she is responsible for, in any team ---------------------------------------------------
select is(pg_temp.cmd('m3', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.ta(), pg_temp.t() + 2,
            pg_temp.k(3))) - 'proposal_id', '{"result":"ok","lines":3,"not_found":0}'::jsonb,
  'PLAN3-14: one line per open visit of team A');
select isnt(pg_temp.proposed(1), pg_temp.u('m1'),
  'PLAN3-14 (1): a member who accepted a team-B cover 09:00-09:30 is not proposed for a team-A visit 09:15-09:45');
select isnt(pg_temp.proposed(2), pg_temp.u('m2'),
  'PLAN3-14 (1): a member of teams A and B with a team-B visit at 09:00 is not proposed for a team-A visit 09:15');
select ok(pg_temp.proposed(1) in (pg_temp.u('m3'), pg_temp.u('m4')) and pg_temp.proposed(2) in (pg_temp.u('m3'), pg_temp.u('m4'))
          and pg_temp.proposed(1) <> pg_temp.proposed(2),
  'PLAN3-14 (1): the two overlapping visits go to the two free members');
select is(pg_temp.proposed(3), pg_temp.u('m2'),
  'PLAN3-14 (1): at 11:00 m2 is free in every team and is proposed as the primary nurse');

-- PLAN3-14 (1): the asking team reads nothing of the other team's visits --------------------------------------------------------
select ok((select bool_and(e ->> 'visit_id' in (pg_temp.v(1)::text, pg_temp.v(2)::text, pg_temp.v(3)::text))
           from jsonb_array_elements(pg_temp.rows('m3', format('select * from public.day_plan(%L, %L)', pg_temp.ta(),
                                                                pg_temp.t() + 2))) e),
  'PLAN3-14 (1): day_plan returns only team A''s visits');
select ok(pg_temp.rows('m3', format('select * from public.day_plan_load(%L, %L)', pg_temp.ta(), pg_temp.t() + 2))::text
          !~ (pg_temp.v(101)::text || '|' || pg_temp.v(102)::text || '|' || pg_temp.c(9)::text || '|09:00'),
  'PLAN3-14 (1): day_plan_load returns no id or time of the other team''s visit or case');
select is((select string_agg(a.nm, ',' order by a.nm) from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
                  unnest(p.proargnames, p.proargmodes) a(nm, md)
           where n.nspname = 'public' and p.proname = 'day_plan_load' and a.md = 't'),
  'member_id,member_name,minutes_now,minutes_with_proposal,other_team_visits',
  'PLAN3-14 (1): day_plan_load adds only a yes/no flag (no count, no client, no time)');
select is((select jsonb_object_agg(e ->> 'member_name', jsonb_build_array((e ->> 'minutes_now')::int,
                                                                          (e ->> 'other_team_visits')::boolean))
           from jsonb_array_elements(pg_temp.rows('m3', format('select * from public.day_plan_load(%L, %L)', pg_temp.ta(),
                                                                pg_temp.t() + 2))) e),
  '{"Synth M1": [0, true], "Synth M2": [0, true], "Synth M3": [0, false], "Synth M4": [0, false]}'::jsonb,
  'PLAN3-14 (1): the day load keeps its team scope and flags "weitere Einsätze in anderen Teams"');

-- PLAN3-14 (2): overlap is checked again at confirm ----------------------------------------------------------------------------
-- After the proposal, VB3 (team B, 11:00-11:30) is assigned to m2 by hand (as the J3 command would, here as table owner).
update public.care_visits set responsible_user_id = pg_temp.u('m2') where id = pg_temp.v(103);
select is(pg_temp.cmd('m1', format('select public.confirm_suggestions(%L::uuid[], %L)',
            array[pg_temp.sug(1), pg_temp.sug(3)], pg_temp.k(4))),
  jsonb_build_object('result', 'ok', 'confirmed', 1,
                     'refused', jsonb_build_array(jsonb_build_object('suggestion_id', pg_temp.sug(3), 'reason', 'overlap'))),
  'PLAN3-14 (2): a line proposed before a hand assignment of an overlapping visit is refused as overlap; the other is set');
select ok(pg_temp.resp(3) is null and pg_temp.resp(1) = pg_temp.proposed(1)
          and not exists (select 1 from public.ai_confirmations where suggestion_id = pg_temp.sug(3)),
  'PLAN3-14 (2): the refused visit stays unassigned and its line stays open; the other visit has its member');
select is(pg_temp.cmd('m1', format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', pg_temp.sug(2), 'corrected',
            to_jsonb(pg_temp.u('m1')::text)::text, pg_temp.k(5))),
  '{"result":"refused","reason":"overlap"}'::jsonb,
  'PLAN3-14 (2): a correction to a member busy in another team at that time is refused as overlap');

select * from finish();
rollback;
