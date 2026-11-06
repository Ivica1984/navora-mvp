-- PLAN3-9 (1) (migration 0115, ADR-156; `cra` CGR-138; PO note 2026-11-06 06:30): `day_plan` returns per line one
-- yes/no, whether the visit has a responsible member now, and no other new column. Brief `docs/agents/briefs/PLAN3.md`
-- PLAN3-9 (1): "pgTAP: the yes/no is false after a rejection and true after a confirm". All data synthetic (seed.sql
-- Testorganisation G: teamg …9e1 and bezugg …9e2, registered nurses of Testteam G …1a1; tomorrow's open visits
-- …5c1-…5c5); pflege …902 of Testorganisation A. No AI service is called.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'teamg' then '00000000-0000-4000-a000-0000000009e1' when 'bezugg' then '00000000-0000-4000-a000-0000000009e2'
                 when 'pa' then '00000000-0000-4000-a000-000000000902' end)::uuid
$$;
create function pg_temp.team() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001a1'::uuid $$;
create function pg_temp.vis(s text) returns uuid language sql immutable as $$ select ('00000000-0000-4000-a000-0000000005' || s)::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1150000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.reader(p_user text) returns jsonb language sql as $$
  select pg_temp.rows(p_user, format('select * from public.day_plan(%L, %L)', pg_temp.team(), pg_temp.d())) $$;
-- The reader's line of visit s, as teamg reads it.
create function pg_temp.lineof(s text) returns jsonb language sql as $$
  select e from jsonb_array_elements(pg_temp.reader('teamg')) e where e ->> 'visit_id' = pg_temp.vis(s)::text $$;
create function pg_temp.sug(s text) returns uuid language sql stable as $$
  select x.id from public.ai_suggestions x where x.entity_id = pg_temp.vis(s) and x.agent_key = 'plan3_day_proposal'
  order by x.seq desc limit 1 $$;

-- The reader's shape: the 0109 columns in their order, then one boolean, nothing else -----------------------------------
select is(pg_get_function_result('public.day_plan(uuid, date)'::regprocedure),
  'TABLE(suggestion_id uuid, proposal_id uuid, proposed_at timestamp with time zone, visit_id uuid, case_id uuid, '
  'time_start time without time zone, time_end time without time zone, minutes_a integer, minutes_b integer, '
  'minutes_c integer, is_needs_assessment boolean, member_id uuid, member_name text, reason text, known_visits integer, '
  'not_found_reason text, changes_assignment boolean, not_continuity boolean, decision text, bulk_allowed boolean, '
  'visit_has_responsible boolean)',
  'PLAN3-9 (1): day_plan adds exactly one column, visit_has_responsible (boolean), after the 0109 columns');
select ok((select p.prosecdef and p.provolatile = 's' and has_function_privilege('authenticated', p.oid, 'execute')
                  and not has_function_privilege('anon', p.oid, 'execute')
           from pg_proc p where p.oid = 'public.day_plan(uuid, date)'::regprocedure),
  'PLAN3-9 (1): still a stable definer reader for signed-in users only (grants as 0109)');

-- Fixture: the team switches the day proposal on and asks for tomorrow ------------------------------------------------------
select is(pg_temp.res('teamg', format('select public.set_team_day_proposal(%L, true, %L)', pg_temp.team(), pg_temp.k(1))), 'ok',
  'fixture: a member of Testteam G switches the day proposal on (PLAN3-10)');
select is(pg_temp.cmd('teamg', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.d(),
            pg_temp.k(2))) ->> 'result', 'ok', 'fixture: a day plan for tomorrow is proposed');

select is((select count(*)::int from jsonb_array_elements(pg_temp.reader('teamg')) e
           where (e ->> 'visit_has_responsible')::boolean is distinct from false), 0,
  'PLAN3-9 (1): before any decision every line of a day asked without "auch zugewiesene" reads false (nobody yet)');

-- Reject one line, confirm another ----------------------------------------------------------------------------------------
select is(pg_temp.res('teamg', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug('c2'), 'rejected',
            pg_temp.k(3))), 'ok', 'fixture: the 09:00 line is rejected');
select is(pg_temp.lineof('c2') ->> 'decision', 'rejected', 'PLAN3-9 (1): the rejected line reads rejected');
select is((pg_temp.lineof('c2') ->> 'visit_has_responsible')::boolean, false,
  'PLAN3-9 (1): after a rejection the visit still has nobody: the yes/no is false');
select is(pg_temp.res('teamg', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug('c1'), 'confirmed',
            pg_temp.k(4))), 'ok', 'fixture: the 08:00 line is confirmed');
select is((pg_temp.lineof('c1') ->> 'visit_has_responsible')::boolean, true,
  'PLAN3-9 (1): after a confirm the visit has a responsible member: the yes/no is true');
select ok((select responsible_user_id is not null from public.care_visits where id = pg_temp.vis('c1'))
          and (select responsible_user_id is null from public.care_visits where id = pg_temp.vis('c2')),
  'PLAN3-9 (1): the yes/no matches care_visits (confirm set the member, the rejection wrote nothing)');

-- Scope unchanged: a member of another organisation reads no line -----------------------------------------------------------
select is(pg_temp.reader('pa'), '[]'::jsonb,
  'PLAN3-8: a nurse of Testorganisation A reads no line of Testteam G (scope as 0109)');

select * from finish();
rollback;
