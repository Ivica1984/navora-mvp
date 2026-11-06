-- PLAN3-16: a hand assignment says when the member already has a visit at that time (migration 0118, ADR-161). Brief
-- `docs/agents/briefs/PLAN3.md` PLAN3-16 (po 2026-11-06 06:30; `cra` CGR-137, advisory S3; `aia` 20:20 condition).
-- Information only: nothing here is refused for an overlap. All data synthetic.
-- Seed users (Testorganisation A …011): pflege …902 (RN, Nord, not in the synthetic teams) · admin …905.
-- Synthetic here: team A "Synth Team PLAN3-16 A" a1600000-…-000000000001 (members m1, m2), team B "… B" …0002
-- (member m1 only, so m1 belongs to two teams, as COVER1 cover or a second membership); cases KA (team A), KB (team B).
-- Day D = T+2. VB: a team-B visit of m1 at 09:00-09:30 (the other team's visit the asking team must learn nothing of).
begin;
create extension if not exists pgtap with schema extensions;

select plan(40);

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
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'm1' then 'a1600000-0000-4000-a000-0000000000a1' when 'm2' then 'a1600000-0000-4000-a000-0000000000a2'
                 when 'm3' then 'a1600000-0000-4000-a000-0000000000a3' end)::uuid
$$;
create function pg_temp.team(n text) returns uuid language sql immutable as $$
  select ('a1600000-0000-4000-a000-00000000000' || case n when 'A' then '1' else '2' end)::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000011'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1601000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.c(n text) returns uuid language sql immutable as $$
  select ('a1600000-0000-4000-c000-00000000000' || case n when 'A' then '1' else '2' end)::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1600000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
-- plan_visit of 30 min category A for case KA on D, as m2, with the member and what the form showed.
create function pg_temp.plan(s time, e time, resp text, shown boolean, key int) returns jsonb language sql as $$
  select pg_temp.cmd('m2', format(
    'select public.plan_visit(%L, %L, %L, %L, 30, 0, 0, false, %L, %L, null, %L)',
    pg_temp.c('A'), pg_temp.t() + 2, s, e, pg_temp.u(resp), pg_temp.k(key), shown)) $$;
-- The form's read: the case KA when no visit is given (the planning form), else the visit (the move form).
create function pg_temp.slot(p_user text, p_member text, p_visit uuid, s time, e time) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.member_slot_overlap(%L, %L, %L, %L, %L, %L)',
    case when p_visit is null then pg_temp.c('A') end, p_visit, pg_temp.u(p_member), pg_temp.t() + 2, s, e)) $$;
-- The audit row of the command that wrote visit n (care_visits insert/update, or its moved row).
create function pg_temp.shown_on(p_table text, p_entity uuid, p_command text) returns text language sql stable as $$
  select a.changed -> 'member_overlap_shown' ->> 'new' from public.audit_events a
  where a.table_name = p_table and a.entity_id = p_entity and a.command = p_command
  order by a.occurred_at desc, a.id desc limit 1 $$;

-- Fixtures (as the table owner) ----------------------------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), 'plan3-16-' || n || '@navora.test' from unnest(array['m1', 'm2', 'm3']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['m1', 'm2', 'm3']) n;
insert into public.member_profiles (organization_id, user_id, display_name)
select pg_temp.org(), pg_temp.u(n), 'Synth ' || upper(n) from unnest(array['m1', 'm2', 'm3']) n;
insert into public.teams (organization_id, id, name, region, status)
values (pg_temp.org(), pg_temp.team('A'), 'Synth Team PLAN3-16 A', 'Bern Nord', 'active'),
       (pg_temp.org(), pg_temp.team('B'), 'Synth Team PLAN3-16 B', 'Bern Nord', 'active');
insert into public.team_memberships (team_id, user_id, qualification)
values (pg_temp.team('A'), pg_temp.u('m1'), 'registered_nurse'), (pg_temp.team('A'), pg_temp.u('m2'), 'registered_nurse'),
       (pg_temp.team('B'), pg_temp.u('m1'), 'registered_nurse'), (pg_temp.team('B'), pg_temp.u('m3'), 'registered_nurse');
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.c(n), 'assigned_team_id', pg_temp.team(n),
          'auto_planning', false, 'primary_nurse_id', null, 'deputy_nurse_id', null, 'proposed_primary_nurse_id', null))).*
from kc k, unnest(array['A', 'B']) n;
create function pg_temp.mk(n int, k text, s time, e time, resp text) returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                  billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
  values (pg_temp.org(), pg_temp.v(n), pg_temp.c(k), pg_temp.team(k), pg_temp.t() + 2, s, e, array['Grundpflege'], false,
          'planned', 30, 0, pg_temp.u(resp)) $$;
select pg_temp.mk(1, 'B', '09:00', '09:30', 'm1');    -- VB: the other team's visit
select pg_temp.mk(2, 'A', '09:10', '09:40', null);    -- open in team A, overlaps VB
select pg_temp.mk(3, 'A', '11:00', '11:30', null);    -- open in team A, no overlap
select pg_temp.mk(4, 'A', '13:00', '13:30', 'm1');    -- team A, m1, to be moved
create temp table vb as select to_jsonb(v) as row from public.care_visits v where v.id = pg_temp.v(1);

-- Contract -------------------------------------------------------------------------------------------------------------------
select is((select count(*)::int from pg_proc where pronamespace = 'public'::regnamespace
           and proname in ('plan_visit', 'reschedule_visit', 'move_visit_to_today', 'take_open_visit')), 4,
  'one signature each for the four hand-assignment commands');
select ok(has_function_privilege('authenticated',
            'public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean)', 'execute')
          and has_function_privilege('authenticated', 'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)', 'execute')
          and has_function_privilege('authenticated', 'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)', 'execute')
          and has_function_privilege('authenticated', 'public.take_open_visit(uuid, uuid, boolean)', 'execute'),
  'PLAN3-16: each command takes p_member_overlap_shown and stays callable by the app');
select ok(not has_function_privilege('anon', 'public.take_open_visit(uuid, uuid, boolean)', 'execute')
          and not has_function_privilege('anon', 'public.member_slot_overlap(uuid, uuid, uuid, date, time, time)', 'execute'),
  'anon calls neither take_open_visit nor member_slot_overlap');
select ok(has_function_privilege('authenticated', 'public.member_slot_overlap(uuid, uuid, uuid, date, time, time)', 'execute')
          and (select prosecdef and provolatile = 's' from pg_proc
               where oid = 'public.member_slot_overlap(uuid, uuid, uuid, date, time, time)'::regprocedure),
  'member_slot_overlap: the form''s read, SECURITY DEFINER and stable (writes nothing)');
select ok(not has_function_privilege('authenticated', 'private.member_visit_overlap(uuid, uuid)', 'execute'),
  'private.member_visit_overlap is internal (granted to nobody)');
select ok((select prosrc ~ 'pg_advisory_xact_lock' and prosrc ~ 'plan3_busy:' from pg_proc
           where oid = 'private.member_visit_overlap(uuid, uuid)'::regprocedure),
  'PLAN3-16: the hand path takes the PLAN3-14 lock on member and day (same key)');
select ok((select prosrc ~ 'private\.member_visit_overlap\(' from pg_proc
           where oid = 'private.plan3_confirm_overlaps(uuid, uuid)'::regprocedure),
  'PLAN3-16: the PLAN3-14 confirm uses the same member-overlap definition');
select ok((select bool_and(prosrc ~ 'private\.member_visit_overlap\(' and prosrc ~ 'navora\.member_overlap_shown')
           from pg_proc where oid in ('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean)'::regprocedure,
                                      'public.reschedule_visit(uuid, date, time, time, text, uuid, boolean, boolean)'::regprocedure,
                                      'public.take_open_visit(uuid, uuid, boolean)'::regprocedure)),
  'PLAN3-16: each hand path computes the fact and records what the form showed');
select ok((select count(*) = 2 from private.audit_value_classes where key = 'member_overlap_shown' and class = 'code'
           and table_name in ('care_visits', 'visit_plan_changes')),
  'AUD1: member_overlap_shown is classed as a code value on both audited tables');

-- The form's read (member_slot_overlap) --------------------------------------------------------------------------------------
select is(pg_temp.slot('m2', 'm1', null, '09:15', '09:45'), 'true'::jsonb,
  'read: a 09:15 slot for m1, who has a team-B visit at 09:00, is busy (any team)');
select is(pg_temp.slot('m2', 'm1', null, '11:30', '12:00'), 'false'::jsonb, 'read: without overlap false');
select is(pg_temp.slot('m2', 'm1', null, '09:30', '10:00'), 'false'::jsonb, 'read: touching ends do not overlap');
select is(pg_temp.slot('m2', 'm1', pg_temp.v(4), '13:00', '13:30'), 'false'::jsonb,
  'read: the visit being moved does not overlap itself');
select is(pg_temp.slot('m2', 'm1', pg_temp.v(1), '09:15', '09:45'), null::jsonb,
  'read: a visit of another team (not hers to read) gets no answer');
select is(pg_temp.slot('p', 'm1', null, '09:15', '09:45'), null::jsonb,
  'read: a person outside the team gets no answer');
select is(pg_temp.slot('m2', 'm3', null, '09:15', '09:45'), null::jsonb,
  'read: a member who is not in the asking team gets no answer');
select is(pg_temp.slot('m2', 'm1', null, '10:00', '09:00'), null::jsonb, 'read: an incomplete slot gets no answer');

-- plan_visit -----------------------------------------------------------------------------------------------------------------
create temp table r1 as select pg_temp.plan('09:15', '09:45', 'm1', true, 1) as r;
select is((select r ->> 'result' from r1), 'ok',
  'PLAN3-16: planning a 09:15 visit for m1 (team-B visit at 09:00) is saved, never refused');
select is((select r -> 'member_overlap' from r1), 'true'::jsonb, 'plan_visit: the result carries member_overlap true');
select is(pg_temp.shown_on('care_visits', (select (r ->> 'visit_id')::uuid from r1), 'plan_visit'), 'true',
  'plan_visit: what the form showed is recorded on the insert audit row (VIS2-4 pattern)');
select is((select string_agg(k, ',' order by k) from r1, jsonb_object_keys(r) k), 'flags,member_overlap,overlap,result,visit_id',
  'plan_visit: the result has no other key');
select ok((select r::text !~ (pg_temp.v(1)::text || '|' || pg_temp.c('B')::text || '|' || pg_temp.team('B')::text
                             || '|09:00|09:30|Team PLAN3-16 B') from r1),
  'plan_visit: nothing of the team-B visit (id, case, team, time) reaches the asking team');
create temp table r2 as select pg_temp.plan('11:30', '12:00', 'm1', false, 2) as r;
select is((select r -> 'member_overlap' from r2), 'false'::jsonb, 'plan_visit: without overlap false');
select is(pg_temp.shown_on('care_visits', (select (r ->> 'visit_id')::uuid from r2), 'plan_visit'), 'false',
  'plan_visit: "not shown" is recorded as false');
create temp table r3 as select pg_temp.plan('15:00', '15:30', null, null, 3) as r;
select is((select r ->> 'result' || ':' || coalesce(r ->> 'member_overlap', 'null') from r3), 'ok:null',
  'plan_visit: without a member there is no fact (null)');
select is(pg_temp.shown_on('care_visits', (select (r ->> 'visit_id')::uuid from r3), 'plan_visit'), null,
  'plan_visit: an older caller (null) records nothing');

-- take_open_visit -------------------------------------------------------------------------------------------------------------
create temp table t1 as select pg_temp.cmd('m1', format('select public.take_open_visit(%L, %L, false)', pg_temp.v(2), pg_temp.k(10))) as r;
select is((select r ->> 'result' from t1), 'ok', 'take_open_visit: taking a 09:10 visit while busy in team B is not refused');
select is((select r -> 'member_overlap' from t1), 'true'::jsonb, 'take_open_visit: the result carries member_overlap true');
select is((select string_agg(k, ',' order by k) from t1, jsonb_object_keys(r) k), 'member_overlap,result',
  'take_open_visit: yes/no only, no other key');
select is(pg_temp.shown_on('care_visits', pg_temp.v(2), 'take_open_visit'), 'false',
  'take_open_visit: what was shown is recorded on its care_visits audit row');
select is(pg_temp.cmd('m1', format('select public.take_open_visit(%L, %L, null)', pg_temp.v(3), pg_temp.k(11))) -> 'member_overlap',
  'false'::jsonb, 'take_open_visit: without overlap false');
select is(pg_temp.cmd('m1', format('select public.take_open_visit(%L, %L, null)', pg_temp.v(3), pg_temp.k(11))) ->> 'result',
  'duplicate', 'take_open_visit: a repeated key stays a duplicate');

-- reschedule_visit / move_visit_to_today ------------------------------------------------------------------------------------------
create temp table s1 as select pg_temp.cmd('m2', format('select public.reschedule_visit(%L, %L, %L, %L, %L, %L, null, true)',
  pg_temp.v(4), pg_temp.t() + 2, '09:20', '09:50', 'Synthetischer Grund', pg_temp.k(20))) as r;
select is((select r ->> 'result' from s1), 'ok', 'reschedule_visit: moving m1''s visit onto her team-B time is not refused');
select is((select r -> 'member_overlap' from s1), 'true'::jsonb, 'reschedule_visit: the result carries member_overlap true');
select is(pg_temp.shown_on('visit_plan_changes', pg_temp.v(4), 'reschedule_visit'), 'true',
  'reschedule_visit: what the form showed is recorded on the moved audit row');
select ok((select r::text !~ (pg_temp.v(1)::text || '|' || pg_temp.c('B')::text || '|09:00|09:30') from s1),
  'reschedule_visit: nothing of the team-B visit reaches the asking team');
select is(pg_temp.cmd('m2', format('select public.reschedule_visit(%L, %L, %L, %L, %L, %L, null, false)',
  pg_temp.v(4), pg_temp.t() + 2, '16:00', '16:30', 'Synthetischer Grund', pg_temp.k(21))) -> 'member_overlap', 'false'::jsonb,
  'reschedule_visit: without overlap false');
select ok((select prosrc ~ 'p_member_overlap_shown\)' from pg_proc
           where oid = 'public.move_visit_to_today(uuid, date, time, time, text, uuid, boolean, boolean)'::regprocedure),
  'move_visit_to_today passes p_member_overlap_shown to reschedule_visit');

-- Unchanged ----------------------------------------------------------------------------------------------------------------------
select is((select to_jsonb(v) from public.care_visits v where v.id = pg_temp.v(1)), (select row from vb),
  'the team-B visit is untouched by every hand path');
select is((select count(*)::int from public.care_visits where team_id = pg_temp.team('A') and responsible_user_id = pg_temp.u('m1')
           and visit_date = pg_temp.t() + 2), 5,
  'every hand assignment above was saved (information only: 2 planned, 2 taken, 1 moved)');

select * from finish();
rollback;
