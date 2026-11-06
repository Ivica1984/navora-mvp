-- PLAN3-7 (migration 0113, ADR-151): the day-plan assistant's measures per team and Zurich month, never per person.
-- Brief `docs/agents/briefs/PLAN3.md` PLAN3-7 (amended 2026-10-30 03:10, AUT-25): "No per-person figure (pgTAP: no
-- person column; small-team suppression)". All data synthetic (seed.sql Testorganisation H, plus ledger rows written
-- here); no AI service is called.
-- Users: teamh …9d7, bezugh …9d8, assisth …9d9 (seed names teamg/bezugg/assistg kept as test aliases) (members of Testteam H …1a8); pflege …902 of Testorganisation A.
-- Fixture (day 11 of the current Zurich month, so the month never splits): plan P1 at 10:00 with three lines (…5d1 and
-- …5d2 proposed to Bezug H, …5d4 "kein Vorschlag: overlap"), plan P2 at 11:00 with two lines (…5d3 proposed to Team H,
-- …5d5 "kein Vorschlag: needs_rn"). P1's two proposed lines confirmed by teamg in one ticked list at 10:30; P2's line
-- corrected by bezugg at 11:10. Later assistg confirms the "kein Vorschlag" of …5d4 (the third confirmer).
-- CGR-140 (migration 0114, ADR-153): after the 0113 values, plan P3 at 12:00 proposes …5d1 again to Team H and bezugg
-- rejects it at 12:05, so the rejected line is decided and in its own share.
begin;
create extension if not exists pgtap with schema extensions;

select plan(15);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'teamg' then '00000000-0000-4000-a000-0000000009d7' when 'bezugg' then '00000000-0000-4000-a000-0000000009d8'
                 when 'assistg' then '00000000-0000-4000-a000-0000000009d9' when 'pa' then '00000000-0000-4000-a000-000000000902' end)::uuid
$$;
create function pg_temp.team() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001a8'::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000018'::uuid $$;
create function pg_temp.vis(s text) returns uuid language sql immutable as $$ select ('00000000-0000-4000-a000-0000000005' || replace(s, 'c', 'd'))::uuid $$;
create function pg_temp.pid(n int) returns uuid language sql immutable as $$
  select ('a1140000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create temp table d0 as
  select date_trunc('month', (private.now() at time zone 'Europe/Zurich'))::date as m0;
-- An instant on day 11 of the current Zurich month at hh:mm Zurich.
create function pg_temp.at(hhmm text) returns timestamptz language sql stable as $$
  select ((select m0 from d0) + 10 + hhmm::time) at time zone 'Europe/Zurich' $$;
create function pg_temp.rows(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]'') from (%s) x', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.g(p_user text) returns jsonb language sql as $$
  select pg_temp.rows(p_user, format('select * from public.plan3_team_measures(%L) where team_id = %L',
                                     (select m0 from d0), pg_temp.team())) -> 0 $$;
-- One ledger line (as propose_day_plan writes it: ai_suggestions + day_plan_lines).
create function pg_temp.line(p_plan int, s text, p_member text, p_reason text, p_not_found text, hhmm text) returns uuid
language plpgsql as $$
declare sid uuid;
begin
  insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field,
                                     entity_type, entity_id, input_refs, not_found, proposed_value, created_at)
  select pg_temp.pid(p_plan), pg_temp.org(), pg_temp.team(), v.case_id, 'plan3_day_proposal', '1', 'responsible_user_id',
         'care_visits', v.id, jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', v.id::text)),
         p_member is null, case when p_member is not null then to_jsonb(pg_temp.u(p_member)::text) end, pg_temp.at(hhmm)
  from public.care_visits v where v.id = pg_temp.vis(s)
  returning ai_suggestions.id into sid;
  insert into public.day_plan_lines (suggestion_id, proposal_id, organization_id, team_id, visit_id, plan_date,
                                     include_assigned, reason, known_visits, not_found_reason, created_at)
  values (sid, pg_temp.pid(p_plan), pg_temp.org(), pg_temp.team(), pg_temp.vis(s), (select m0 from d0) + 11, false,
          p_reason, case when p_reason is not null then 0 end, p_not_found, pg_temp.at(hhmm));
  return sid;
end $$;
create function pg_temp.decide(s text, p_outcome text, p_value text, p_bulk boolean, p_by text, hhmm text) returns void
language sql as $$
  insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, bulk, confirmed_by,
                                       confirmed_at)
  select x.id, x.organization_id, x.team_id, p_outcome,
         case when p_value is not null then to_jsonb(pg_temp.u(p_value)::text) end, p_bulk, pg_temp.u(p_by), pg_temp.at(hhmm)
  from public.ai_suggestions x where x.entity_id = pg_temp.vis(s) and x.agent_key = 'plan3_day_proposal'
  order by x.seq desc limit 1 $$;

-- Before any proposal ---------------------------------------------------------------------------------------------------
select is(pg_temp.g('teamg'), null::jsonb,
  'PLAN3-7: a team without a day plan and without a completed visit in the month has no row');

-- Fixture -------------------------------------------------------------------------------------------------------------
do $$
begin
  perform pg_temp.line(1, 'c1', 'bezugg', 'primary_nurse', null, '10:00');
  perform pg_temp.line(1, 'c2', 'bezugg', 'primary_nurse', null, '10:00');
  perform pg_temp.line(1, 'c4', null, null, 'overlap', '10:00');
  perform pg_temp.line(2, 'c3', 'teamg', 'free_capacity', null, '11:00');
  perform pg_temp.line(2, 'c5', null, null, 'needs_rn', '11:00');
  perform pg_temp.decide('c1', 'confirmed', 'bezugg', true, 'teamg', '10:30');
  perform pg_temp.decide('c2', 'confirmed', 'bezugg', true, 'teamg', '10:30');
  perform pg_temp.decide('c3', 'corrected', 'bezugg', false, 'bezugg', '11:10');
end $$;

-- Two confirmers: counts only (AIG1-7) ----------------------------------------------------------------------------------
select is(pg_temp.g('teamg') - 'team_id' - 'month' - 'enabled_since' - 'continuity_before_base' - 'continuity_after_base'
          - 'continuity_before_share' - 'continuity_after_share' - 'continuity_suppressed',
  jsonb_build_object('team_name', 'Testteam H', 'day_plans', 2, 'lines', 5, 'decided_lines', null,
                     'confirmed_unchanged_share', null, 'corrected_share', null, 'rejected_share', null,
                     'confirm_actions_per_plan', null,
                     'minutes_to_last_decision_median', null, 'no_proposal', null, 'no_proposal_share', null,
                     'no_proposal_not_active', null, 'no_proposal_needs_rn', null, 'no_proposal_absent', null,
                     'no_proposal_overlap', null, 'proposal_suppressed', true),
  'PLAN3-7: with two confirmers in the month the team sees its 2 day plans and 5 lines, every share suppressed');

-- The third confirmer -------------------------------------------------------------------------------------------------
do $$ begin perform pg_temp.decide('c4', 'not_found', null, false, 'assistg', '10:40'); end $$;
select is(pg_temp.g('teamg') ->> 'proposal_suppressed', 'false',
  'PLAN3-7: three distinct confirmers in the month lift the suppression');
select is((pg_temp.g('teamg') ->> 'decided_lines')::int, 3,
  'PLAN3-7: decided lines are the proposed lines with an outcome (two confirmed, one corrected); "kein Vorschlag" excluded');
select is(jsonb_build_array((pg_temp.g('teamg') ->> 'confirmed_unchanged_share')::numeric,
                            (pg_temp.g('teamg') ->> 'corrected_share')::numeric),
  jsonb_build_array(66.7, 33.3),
  'PLAN3-7 (AIG1-7, AUT-1 balancing measure): 66.7 % confirmed unchanged, 33.3 % corrected');
select is((pg_temp.g('teamg') ->> 'confirm_actions_per_plan')::numeric, 1.5,
  'PLAN3-7 (AUT-1): the ticked list counts once: P1 two actions (list + "kein Vorschlag"), P2 one: 1.5 per plan');
select is((pg_temp.g('teamg') ->> 'minutes_to_last_decision_median')::numeric, 20.0,
  'PLAN3-7 (AUT-1): median minutes from proposal to the last decided line: P1 30, P2 10, median 20');
select is(jsonb_build_object('n', (pg_temp.g('teamg') ->> 'no_proposal')::int,
                             'share', (pg_temp.g('teamg') ->> 'no_proposal_share')::numeric,
                             'overlap', (pg_temp.g('teamg') ->> 'no_proposal_overlap')::int,
                             'needs_rn', (pg_temp.g('teamg') ->> 'no_proposal_needs_rn')::int,
                             'absent', (pg_temp.g('teamg') ->> 'no_proposal_absent')::int,
                             'not_active', (pg_temp.g('teamg') ->> 'no_proposal_not_active')::int),
  jsonb_build_object('n', 2, 'share', 40.0, 'overlap', 1, 'needs_rn', 1, 'absent', 0, 'not_active', 0),
  'PLAN3-7 (AUT-25): 2 of 5 lines "kein Vorschlag" (40 %), one for overlap, one for needs_rn');

-- CGR-140 (0114, ADR-153): a rejected line is decided and in its own share ------------------------------------------
do $$
begin
  perform pg_temp.line(3, 'c1', 'teamg', 'free_capacity', null, '12:00');
  perform pg_temp.decide('c1', 'rejected', null, false, 'bezugg', '12:05');
end $$;
select is((pg_temp.g('teamg') ->> 'decided_lines')::int, 4,
  'CGR-140: a rejected line counts as decided (two confirmed, one corrected, one rejected)');
select is(jsonb_build_array((pg_temp.g('teamg') ->> 'confirmed_unchanged_share')::numeric,
                            (pg_temp.g('teamg') ->> 'corrected_share')::numeric,
                            (pg_temp.g('teamg') ->> 'rejected_share')::numeric),
  jsonb_build_array(50.0, 25.0, 25.0),
  'CGR-140 option (a): 50 % confirmed unchanged, 25 % corrected, 25 % rejected ("Abgelehnt")');
select ok(abs((pg_temp.g('teamg') ->> 'confirmed_unchanged_share')::numeric
              + (pg_temp.g('teamg') ->> 'corrected_share')::numeric
              + (pg_temp.g('teamg') ->> 'rejected_share')::numeric - 100) <= 0.1,
  'CGR-140: the three shares add up to 100 % of the decided lines (±0.1)');

-- Continuity: Testteam H has no completed visit with a performer this month (AN1: fewer than three performers) --------
select is(pg_temp.g('teamg') -> 'continuity_suppressed', 'true'::jsonb,
  'PLAN3-7 (AN1): fewer than three performers in the month: the continuity shares are suppressed');
select ok(pg_temp.g('teamg') -> 'continuity_before_share' = 'null'::jsonb
          and pg_temp.g('teamg') -> 'continuity_after_share' = 'null'::jsonb,
  'PLAN3-7 (AN1): a suppressed continuity share is null, never 0');

-- Scope ---------------------------------------------------------------------------------------------------------------
select is(pg_temp.rows('pa', format('select team_id from public.plan3_team_measures(%L) where team_id = %L',
                                    (select m0 from d0), pg_temp.team())), '[]'::jsonb,
  'PLAN3-7: a member of another organisation reads no row of Testteam H');

-- AIG1-11 (4) / brief: no person column ---------------------------------------------------------------------------------
select is((select count(*)::int from unnest((select proargnames from pg_proc
             where oid = 'public.plan3_team_measures(date)'::regprocedure)) a
           where a ~ '(confirmer|confirmed_by|outcome|user|person|member|actor|_by$|nurse_id)'), 0,
  'PLAN3-7 / AIG1-11 (4): the measure has no person, outcome or confirmer column');

select * from finish();
rollback;
