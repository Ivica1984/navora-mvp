-- PLAN3-9 (2) (migration 0117, ADR-160; `uxa` UXR-103; PO note 2026-11-06 06:30): `open_day_plan_lines` returns, for
-- the open PLAN3 lines the caller reads in `open_suggestions`, the day of their day plan and nothing else. All data
-- synthetic (seed.sql Testorganisation G: teamg …9e1, registered nurse of Testteam G …1a1; tomorrow's open visits
-- …5c1-…5c5); pflege …902 of Testorganisation A. No AI service is called.
begin;
create extension if not exists pgtap with schema extensions;

select plan(11);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'teamg' then '00000000-0000-4000-a000-0000000009e1' when 'pa' then '00000000-0000-4000-a000-000000000902' end)::uuid
$$;
create function pg_temp.team() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001a1'::uuid $$;
create function pg_temp.vis(s text) returns uuid language sql immutable as $$ select ('00000000-0000-4000-a000-0000000005' || s)::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1180000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create temp table d0 as select visit_date as d from public.care_visits where id = '00000000-0000-4000-a000-0000000005c1';
create function pg_temp.d() returns date language sql stable as $$ select d from d0 $$;
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
create function pg_temp.days(p_user text) returns jsonb language sql as $$
  select pg_temp.rows(p_user, format('select * from public.open_day_plan_lines(%L)', pg_temp.team())) $$;
-- The open PLAN3 lines of the team as teamg reads them on the confirm list.
create function pg_temp.open_plan3(p_user text) returns jsonb language sql as $$
  select pg_temp.rows(p_user, format('select suggestion_id from public.open_suggestions(%L) where agent_key = %L',
                                     pg_temp.team(), 'plan3_day_proposal')) $$;
create function pg_temp.sug(s text) returns uuid language sql stable as $$
  select x.id from public.ai_suggestions x where x.entity_id = pg_temp.vis(s) and x.agent_key = 'plan3_day_proposal'
  order by x.seq desc limit 1 $$;

-- Shape and grants ----------------------------------------------------------------------------------------------------------
select is(pg_get_function_result('public.open_day_plan_lines(uuid)'::regprocedure),
  'TABLE(suggestion_id uuid, plan_date date)',
  'PLAN3-9 (2): the reader returns the line and the day of its day plan, no other column');
select ok((select p.prosecdef and p.provolatile = 's' and has_function_privilege('authenticated', p.oid, 'execute')
                  and not has_function_privilege('anon', p.oid, 'execute')
           from pg_proc p where p.oid = 'public.open_day_plan_lines(uuid)'::regprocedure),
  'PLAN3-9 (2): a stable definer reader for signed-in users only');

-- Fixture: the team switches the day proposal on and asks for tomorrow ------------------------------------------------------
select is(pg_temp.res('teamg', format('select public.set_team_day_proposal(%L, true, %L)', pg_temp.team(), pg_temp.k(1))), 'ok',
  'fixture: a member of Testteam G switches the day proposal on (PLAN3-10)');
select is(pg_temp.cmd('teamg', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.d(),
            pg_temp.k(2))) ->> 'result', 'ok', 'fixture: a day plan for tomorrow is proposed');

select ok(jsonb_array_length(pg_temp.days('teamg')) > 0
          and jsonb_array_length(pg_temp.days('teamg')) = jsonb_array_length(pg_temp.open_plan3('teamg')),
  'PLAN3-9 (2): one row per open PLAN3 line of the confirm list, none missing and none added');
select is((select count(*)::int from jsonb_array_elements(pg_temp.days('teamg')) e where (e ->> 'plan_date')::date <> pg_temp.d()), 0,
  'PLAN3-9 (2): every line of the day plan asked for tomorrow carries tomorrow as its day');
select is((select count(*)::int from jsonb_array_elements(pg_temp.days('teamg')) e
           where not exists (select 1 from jsonb_array_elements(pg_temp.open_plan3('teamg')) o
                             where o ->> 'suggestion_id' = e ->> 'suggestion_id')), 0,
  'PLAN3-9 (2): the reader returns only lines the caller reads as open in open_suggestions');

-- A decided line leaves; a fresh request leaves no closed line --------------------------------------------------------------
create temp table n0 as select jsonb_array_length(pg_temp.days('teamg')) as n;
select is(pg_temp.res('teamg', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug('c2'), 'rejected',
            pg_temp.k(3))), 'ok', 'fixture: one line is rejected');
select is(jsonb_array_length(pg_temp.days('teamg')), (select n - 1 from n0),
  'PLAN3-9 (2): a decided line is no longer returned (its day row counts one fewer)');
select is(pg_temp.cmd('teamg', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.d(),
            pg_temp.k(4))) ->> 'result' in ('ok', 'nothing_open') and
          jsonb_array_length(pg_temp.days('teamg')) = jsonb_array_length(pg_temp.open_plan3('teamg')), true,
  'PLAN3-15: after a fresh request the reader still matches the open list (closed lines are not returned)');

-- Scope: a member of another organisation reads no line --------------------------------------------------------------------
select is(pg_temp.days('pa'), '[]'::jsonb,
  'PLAN3-8: a nurse of Testorganisation A reads no day of Testteam G');

select * from finish();
rollback;
