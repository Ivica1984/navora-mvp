-- PLAN3-13 (migration 0112, ADR-150): the look-back measure per stop and team, never per person. Brief
-- `docs/agents/briefs/PLAN3.md` note 2026-10-31 02:25 ("pgTAP on the seeded stop of Testorganisation F returns the six
-- counts as seeded; catalogue check finds no person column") and AUT-31 (02:55). All data synthetic (seed.sql
-- Testorganisation F); no AI service is called.
-- Seeded stop …6f1 (threshold, stopped 3 days ago + 1 h): four lines confirmed unchanged at the stop (…5b1 dated
-- yesterday, …5b2, …5b3, …5b4); …5b4 replaced after the stop ("überholt"); …5b5/…5b6 corrected in the window, so never
-- listed. Users: opsf …9c1 (Operations, coordinator, no team), teamf …9c5 (registered nurse of Testteam F), pflege …902
-- of Testorganisation A (another organisation).
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'opsf' then '00000000-0000-4000-a000-0000000009c1' when 'teamf' then '00000000-0000-4000-a000-0000000009c5'
                 when 'pa' then '00000000-0000-4000-a000-000000000902' end)::uuid
$$;
create function pg_temp.stop() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000006f1'::uuid $$;
create function pg_temp.vis(s text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-0000000005' || s)::uuid $$;
create function pg_temp.rows(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]'') from (%s) x', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
-- The six counts (and open_now) for Testteam F, as the given user reads them.
create function pg_temp.counts(p_user text) returns jsonb language sql as $$
  select pg_temp.rows(p_user, format(
    'select team_name, lines_at_stop, left_by_recheck, superseded, not_open_at_stop, became_not_open, open_now, '
    || 'days_to_zero_open from public.agent_stop_measures(%L)', pg_temp.stop())) -> 0 $$;
create function pg_temp.sug(s text) returns uuid language sql stable as $$
  select x.id from public.ai_suggestions x where x.entity_id = pg_temp.vis(s) order by x.seq desc limit 1 $$;
create function pg_temp.decide(s text, p_outcome text, p_value uuid, key text) returns jsonb language sql as $$
  select pg_temp.cmd('teamf', format('select public.confirm_suggestion(%L, %L, %s, %L)', pg_temp.sug(s), p_outcome,
                                     case when p_value is null then 'null'
                                          else quote_literal(to_jsonb(p_value::text)::text) || '::jsonb' end,
                                     ('a1130000-0000-4000-8000-' || lpad(key, 12, '0'))::uuid)) $$;

-- The open-visit condition at a past instant ----------------------------------------------------------------------------
select ok(private.plan3_visit_open_at(pg_temp.vis('b1'), (select created_at from public.ai_agent_stops where id = pg_temp.stop())),
  'PLAN3-13: visit …5b1 (dated yesterday) was open at the stop three days ago');
select ok(not private.plan3_visit_open_at(pg_temp.vis('b1'), private.now()),
  'PLAN3-13: visit …5b1 is no longer open now (the same condition as aig1_record_open)');

-- The six counts as seeded --------------------------------------------------------------------------------------------
select is(pg_temp.counts('opsf'),
  jsonb_build_object('team_name', 'Testteam F', 'lines_at_stop', 4, 'left_by_recheck', 0, 'superseded', 1,
                     'not_open_at_stop', 0, 'became_not_open', 1, 'open_now', 2, 'days_to_zero_open', null),
  'PLAN3-13: Operations reads the seeded stop: 4 lines at the stop, 0 re-checked, 1 überholt, 0 not open at the stop, '
  '1 no longer open since, 2 open, no "days until 0 offen" while lines are open');
select is(pg_temp.counts('teamf'), pg_temp.counts('opsf'),
  'PLAN3-13: a member of Testteam F reads the same counts for her own team (scope of agent_stop_lookback)');
select is(jsonb_array_length(pg_temp.rows('pa', format('select team_id from public.agent_stop_measures(%L)', pg_temp.stop()))), 0,
  'PLAN3-13: a member of another organisation reads no row of the stop');
select is(jsonb_array_length(pg_temp.rows('teamf', format('select team_id from public.agent_stop_lookback(%L)', pg_temp.stop()))),
  (pg_temp.counts('teamf') ->> 'lines_at_stop')::int,
  'PLAN3-13: before any re-check, the lines at the stop are the lines of the look-back list');

-- AUT-31: proposals of the window and their lead time -----------------------------------------------------------------
select is((pg_temp.rows('opsf', format('select proposals_in_window from public.agent_stop_measures(%L)', pg_temp.stop())) -> 0
           ->> 'proposals_in_window')::int, 6,
  'PLAN3-13 (AUT-31): the six proposals of the stop window are counted for Testteam F');
select ok((pg_temp.rows('opsf', format('select lead_time_median_hours from public.agent_stop_measures(%L)', pg_temp.stop())) -> 0
           ->> 'lead_time_median_hours')::numeric > 0,
  'PLAN3-13 (AUT-31): the median lead time from proposal to visit is given in hours');

-- A re-check moves a line from "open" to "left by re-check"; the stop's lines do not change ------------------------------
select is(pg_temp.decide('b2', 'confirmed', null, '1') ->> 'result', 'ok',
  'fixture: the member re-confirms the open line of visit …5b2');
select is(pg_temp.counts('opsf') - 'team_name',
  jsonb_build_object('lines_at_stop', 4, 'left_by_recheck', 1, 'superseded', 1, 'not_open_at_stop', 0,
                     'became_not_open', 1, 'open_now', 1, 'days_to_zero_open', null),
  'PLAN3-13: after one re-confirmation: still 4 lines at the stop, 1 left by re-check, 1 open');
select is(pg_temp.decide('b3', 'corrected', pg_temp.u('teamf'), '2') ->> 'result', 'ok',
  'fixture: the member changes the last open line (visit …5b3) to herself');
select is(pg_temp.counts('opsf') - 'team_name',
  jsonb_build_object('lines_at_stop', 4, 'left_by_recheck', 2, 'superseded', 1, 'not_open_at_stop', 0,
                     'became_not_open', 1, 'open_now', 0, 'days_to_zero_open', 3),
  'PLAN3-13: at "0 offen" the days from the stop (three days ago) to the last line leaving are 3');
select is(jsonb_array_length(pg_temp.rows('teamf', format('select team_id from public.team_lookback_stops() where stop_id = %L',
                                                          pg_temp.stop()))), 0,
  'PLAN3-13 / PLAN3-11: the measure stays while /team has no entry at "0 offen"');

-- AIG1-11 (4): no person column ------------------------------------------------------------------------------------------
select is((select count(*)::int from unnest((select proargnames from pg_proc
             where oid = 'public.agent_stop_measures(uuid)'::regprocedure)) a
           where a ~ '(confirm|outcome|status|user|person|member|actor|by$|nurse)'), 0,
  'PLAN3-13 / AIG1-11 (4): the measure has no person, outcome or confirmer column');

select * from finish();
rollback;
