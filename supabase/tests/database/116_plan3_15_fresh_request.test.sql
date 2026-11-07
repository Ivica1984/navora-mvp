-- PLAN3-15 (migration 0116, ADR-157; po 2026-11-06 06:30 in PO PR #893; `aia` AUT-51; `cra` 2026-11-05 15:00
-- conditions): a fresh `propose_day_plan` request for the same team and day closes the earlier undecided lines with an
-- outcome of their own and writes the new lines; the `open_proposal` refusal is gone. Brief `docs/agents/briefs/PLAN3.md`
-- PLAN3-15: "a line refused `overlap` at confirm, then a fresh request for that day succeeds, the earlier undecided
-- lines carry the closing outcome, `open_suggestions` lists one line per visit, a confirmed line of the first proposal
-- is unchanged". All data synthetic (seed.sql Testorganisation H: teamg …9d7 and bezugg …9d8, registered nurses of
-- Testteam H …1a8; tomorrow's open visits …5d1 08:00, …5d2 09:00, …5d3 10:00 (Testfall H1, primary bezugg), …5d4
-- 08:15-08:45 and …5d5 12:00 (Testfall H2)); pflege …902 of Testorganisation A. No AI service is called.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'teamg' then '00000000-0000-4000-a000-0000000009d7' when 'bezugg' then '00000000-0000-4000-a000-0000000009d8'
                 when 'pa' then '00000000-0000-4000-a000-000000000902' end)::uuid
$$;
create function pg_temp.team() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001a8'::uuid $$;
create function pg_temp.vis(s text) returns uuid language sql immutable as $$ select ('00000000-0000-4000-a000-0000000005' || replace(s, 'c', 'd'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1160000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create temp table d0 as select visit_date as d from public.care_visits where id = '00000000-0000-4000-a000-0000000005d1';
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

create function pg_temp.err(p_user text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.rows(p_user, p_sql);
  return 'none';
exception when others then
  execute 'reset role';
  return sqlstate;
end $$;
create function pg_temp.err_update() returns text language plpgsql as $$
begin
  update public.day_plan_line_closures set plan_date = plan_date + 1;
  return 'none';
exception when others then
  return sqlstate;
end $$;
create function pg_temp.ask(p_include boolean, key int) returns jsonb language sql as $$
  select pg_temp.cmd('teamg', format('select public.propose_day_plan(%L, %L, %L, %L)', pg_temp.team(), pg_temp.d(),
                                     p_include, pg_temp.k(key))) $$;
create function pg_temp.decide(p_sug uuid, p_outcome text, p_value jsonb, key int) returns jsonb language sql as $$
  select pg_temp.cmd('teamg', format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', p_sug, p_outcome,
                                     p_value::text, pg_temp.k(key))) $$;
create function pg_temp.open_list() returns jsonb language sql as $$
  select pg_temp.rows('teamg', format('select * from public.open_suggestions(%L)', pg_temp.team())) $$;

-- Shape: the closing outcome is its own table, append-only, audited, closed to app roles --------------------------------------
select ok((select c.relrowsecurity from pg_class c where c.oid = 'public.day_plan_line_closures'::regclass),
  'PLAN3-15: day_plan_line_closures has row level security on');
select ok(not has_table_privilege('authenticated', 'public.day_plan_line_closures', 'select')
          and not has_table_privilege('authenticated', 'public.day_plan_line_closures', 'insert')
          and not has_table_privilege('anon', 'public.day_plan_line_closures', 'select'),
  'PLAN3-15: no app role reads or writes day_plan_line_closures');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name = 'day_plan_line_closures'
             and column_name ~ '(by|user|actor|member)$' and column_name <> 'closed_by_proposal_id'), 0,
  'PLAN3-15: no person column (who asked is in the audit row only)');
select is(position('open_proposal' in substring(pg_get_functiondef('public.propose_day_plan(uuid, date, boolean, uuid)'::regprocedure)
                                                 from '\$function\$(.*)\$function\$')), 0,
  'PLAN3-15: propose_day_plan no longer has an open_proposal refusal');

-- First request; one line confirmed; one line refused `overlap` at confirm ---------------------------------------------------
select is(pg_temp.res('teamg', format('select public.set_team_day_proposal(%L, true, %L)', pg_temp.team(), pg_temp.k(1))), 'ok',
  'fixture: a member of Testteam H switches the day proposal on (PLAN3-10)');
select is(pg_temp.ask(false, 2) - 'proposal_id', '{"result":"ok","lines":5,"not_found":0}'::jsonb,
  'PLAN3-15: a first request returns exactly the 0109 result (no "closed" key)');
create temp table p1 as
  select s.entity_id as visit_id, s.id as sug from public.ai_suggestions s where s.id in
    (select x.id from public.ai_suggestions x where x.agent_key = 'plan3_day_proposal' and x.team_id = pg_temp.team()
     and x.proposal_id = (select y.proposal_id from public.ai_suggestions y where y.id = pg_temp.sug('c1')));
create function pg_temp.old(s text) returns uuid language sql stable as $$
  select sug from p1 where visit_id = pg_temp.vis(s) $$;
select is((select count(*)::int from p1), 5, 'fixture: the first proposal has five lines');
select is(pg_temp.decide(pg_temp.old('c1'), 'confirmed', null, 3) ->> 'result', 'ok',
  'fixture: the 08:00 line (primary nurse) is confirmed');
select is(pg_temp.decide(pg_temp.old('c4'), 'corrected', to_jsonb(pg_temp.u('bezugg')::text), 4),
  '{"result":"refused","reason":"overlap"}'::jsonb,
  'PLAN3-14 (2): the 08:15 line changed to the member now busy at 08:00 is refused overlap; it stays open');

-- The fresh request succeeds and closes the earlier undecided lines ------------------------------------------------------------
select is(pg_temp.ask(false, 5) - 'proposal_id', '{"result":"ok","lines":4,"not_found":0,"closed":4}'::jsonb,
  'PLAN3-15: after the overlap refusal a fresh request for that day succeeds: 4 new lines, the 4 undecided closed');
select is((select count(*)::int from public.day_plan_line_closures x join p1 on p1.sug = x.suggestion_id
           where x.closed_by_proposal_id = (select y.proposal_id from public.ai_suggestions y where y.id = pg_temp.sug('c2'))),
  4, 'PLAN3-15: the earlier undecided lines carry the closing outcome, naming the request that closed them');
select is((select count(*)::int from public.ai_confirmations c join p1 on p1.sug = c.suggestion_id
           where p1.visit_id <> pg_temp.vis('c1')), 0,
  'PLAN3-15: closing is not a decision: no confirmation row for a closed line');
select is((select count(*)::int from public.ai_suggestions s join p1 on p1.sug = s.id), 5,
  'PLAN3-15: nothing is deleted from the ledger');
select ok((select bool_and(e ->> 'suggestion_id' not in (select sug::text from p1)) from jsonb_array_elements(pg_temp.open_list()) e)
          and jsonb_array_length(pg_temp.open_list()) = 4
          and (select count(distinct e ->> 'entity_id')::int from jsonb_array_elements(pg_temp.open_list()) e) = 4,
  'PLAN3-15: open_suggestions lists one line per visit, none of the closed ones');
select is((select responsible_user_id from public.care_visits where id = pg_temp.vis('c4')), null,
  'PLAN3-15: a closed line''s visit stays unassigned (care_visits not written)');

-- A confirmed line of the first proposal is unchanged and stays on the day plan --------------------------------------------
select ok(not private.plan3_line_closed(pg_temp.old('c1'))
          and (select count(*)::int from public.ai_confirmations c where c.suggestion_id = pg_temp.old('c1') and c.outcome = 'confirmed') = 1
          and (select responsible_user_id from public.care_visits where id = pg_temp.vis('c1')) = pg_temp.u('bezugg'),
  'PLAN3-15: the confirmed line of the first proposal is unchanged (not closed, still confirmed, the member kept)');
select is((select jsonb_agg(jsonb_build_array(e ->> 'time_start', e ->> 'decision', e ->> 'suggestion_id' in (select sug::text from p1))
                            order by e ->> 'time_start')
           from jsonb_array_elements(pg_temp.reader('teamg')) e),
  '[["08:00:00", "confirmed", true], ["08:15:00", "open", false], ["09:00:00", "open", false], ["10:00:00", "open", false], ["12:00:00", "open", false]]'::jsonb,
  'PLAN3-15: the day plan shows one line per visit: the confirmed one kept, the new ones open, no closed one');

-- A closed line is never decided --------------------------------------------------------------------------------------------
select is(pg_temp.decide(pg_temp.old('c2'), 'confirmed', null, 6), '{"result":"refused","reason":"replaced"}'::jsonb,
  'PLAN3-15: confirming a closed line from an old screen is refused replaced');
select is(pg_temp.decide(pg_temp.old('c2'), 'rejected', null, 7), '{"result":"refused","reason":"replaced"}'::jsonb,
  'PLAN3-15: rejecting a closed line is refused replaced too (a decision without content)');
select ok((select count(*)::int from public.ai_confirmations c where c.suggestion_id = pg_temp.old('c2')) = 0
          and (select responsible_user_id from public.care_visits where id = pg_temp.vis('c2')) is null,
  'PLAN3-15: no confirmation row and no visit change after the refusals');
select is(pg_temp.cmd('teamg', format('select public.confirm_suggestions(%L::uuid[], %L)',
            array[pg_temp.old('c3'), pg_temp.sug('c3')], pg_temp.k(8))),
  jsonb_build_object('result', 'ok', 'confirmed', 1,
                     'refused', jsonb_build_array(jsonb_build_object('suggestion_id', pg_temp.old('c3'), 'reason', 'replaced'))),
  'PLAN3-15: in a ticked list the closed line is returned replaced, the new line of the same visit is set');
select is((select responsible_user_id from public.care_visits where id = pg_temp.vis('c3')), pg_temp.u('bezugg'),
  'PLAN3-15: the 10:00 visit is set once, from the new line');

-- "auch zugewiesene": confirmed lines are not proposed again ----------------------------------------------------------------
select is(pg_temp.ask(true, 9) - 'proposal_id', '{"result":"ok","lines":3,"not_found":0,"closed":3}'::jsonb,
  'PLAN3-15: with "auch zugewiesene" a third request proposes the 3 visits without a confirmed line and closes their 3 lines');
select is((select count(*)::int from public.ai_suggestions s where s.entity_id in (pg_temp.vis('c1'), pg_temp.vis('c3'))
           and s.agent_key = 'plan3_day_proposal' and s.proposal_id = (select y.proposal_id from public.ai_suggestions y
                                                                       where y.id = pg_temp.sug('c2'))), 0,
  'PLAN3-15: the visits that hold a confirmed line''s member (08:00, 10:00) are not proposed again');
select is(jsonb_array_length(pg_temp.reader('teamg')), 5, 'PLAN3-15: still one line per visit on the day plan');
select is(jsonb_array_length(pg_temp.open_list()), 3, 'PLAN3-15: three open lines, one per open visit');

select is((select count(*)::int from public.day_plan_line_closures), 7, 'fixture: seven lines closed so far');

-- PLAN3-7: the closing counted per team and month, apart from the shares -----------------------------------------------------
select is((select jsonb_build_object('requests_closing', (e ->> 'requests_closing')::int, 'lines_closed', (e ->> 'lines_closed')::int)
           from jsonb_array_elements(pg_temp.rows('teamg', format('select * from public.plan3_team_measures(%L)',
                                                                   (private.at_zurich(private.now()))::date))) e
           where e ->> 'team_id' = pg_temp.team()::text),
  '{"requests_closing": 2, "lines_closed": 7}'::jsonb,
  'PLAN3-7 / PLAN3-15: two requests closed seven earlier lines this month (team level, no person)');

-- Audit and append-only ------------------------------------------------------------------------------------------------------
select is((select count(*)::int from public.audit_events a where a.table_name = 'day_plan_line_closures'
           and a.actor_id = pg_temp.u('teamg')), 7,
  'PLAN3-15: every closing is audited with the member who asked');
select is(pg_temp.err_update(), '42501', 'PLAN3-15: a closed line cannot be changed or reopened (append-only)');

-- Scope unchanged ---------------------------------------------------------------------------------------------------------
select is(pg_temp.err('pa', format('select public.propose_day_plan(%L, %L, false, %L)', pg_temp.team(), pg_temp.d(),
                                    pg_temp.k(10))), '42501',
  'PLAN3-8: a nurse of Testorganisation A cannot ask for Testteam H, so she closes nothing');
select is((select count(*)::int from public.day_plan_line_closures), 7, 'PLAN3-8: still seven closed lines');

select * from finish();
rollback;
