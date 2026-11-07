-- AN3 (migration 0108, ADR-144; brief docs/agents/briefs/AN3.md): `pilot_step_spans`, per team and month, never per
-- person, AN1 access and suppression, no WORK1 table, test clock for the month end.
-- Org B (…012, admin …903 = coordination role, member of no team). Fixtures in a fixed past month (June 2025), so the
-- seed and the time of day play no part. Teams created here:
--   T3 "AN3 Drei" (performers p1, p2, p3)   T2 "AN3 Zwei" (q1, q2)
-- Synthetic ids only; `pg_temp.id(name)` derives a fixed uuid from a fixture name. Fixtures are written as the table
-- owner; the read is called as `authenticated`. All data synthetic.
begin;
create extension if not exists pgtap with schema extensions;

select plan(29);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.id(n text) returns uuid language sql immutable as $$
  select ('a1090000-0000-4000-8000-' || left(md5(n), 12))::uuid $$;
create function pg_temp.at(d date, t time) returns timestamptz language sql immutable as $$
  select (d + t) at time zone 'Europe/Zurich' $$;

insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('t3'), 'AN3 Drei', 'Test', 'active'),
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('t2'), 'AN3 Zwei', 'Test', 'active');

-- A completed visit of org B's case …251: departed `travel` minutes before 08:00, started 08:00, completed 09:00.
-- `travel` null: no departure recorded (travel not measured, the visit is left out of the travel share).
create function pg_temp.visit(p_id text, p_team text, p_date date, p_actor text, p_travel int) returns void
language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
  values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), '00000000-0000-4000-a000-000000000251',
          pg_temp.id(p_team), p_date, '08:00', '09:00', false, 'completed');
  if p_travel is not null then
    insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
    values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), pg_temp.id(p_team), 'departed', 'planned', 'on_the_way',
            pg_temp.id(p_actor), pg_temp.at(p_date, '08:00') - make_interval(mins => p_travel));
  end if;
  insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
  values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), pg_temp.id(p_team), 'started', 'on_the_way', 'started',
          pg_temp.id(p_actor), pg_temp.at(p_date, '08:00')),
         ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), pg_temp.id(p_team), 'completed', 'started', 'completed',
          pg_temp.id(p_actor), pg_temp.at(p_date, '09:00'));
end $$;

create function pg_temp.s(p_measure text, p_team text default null) returns jsonb language sql as $$
  select to_jsonb(x) from public.pilot_step_spans('2025-06-01') x
  where x.measure = p_measure and x.team_id is not distinct from pg_temp.id(p_team) $$;
create function pg_temp.sv(p_measure text, p_team text default null) returns numeric language sql as $$
  select (pg_temp.s(p_measure, p_team) ->> 'value')::numeric $$;
create function pg_temp.sb(p_measure text, p_team text default null) returns int language sql as $$
  select (pg_temp.s(p_measure, p_team) ->> 'base')::int $$;

-- =====================================================================================================================
-- Fixtures, June 2025
-- =====================================================================================================================
-- AN3-2: T3 five visits with travel 10, 20, 30, 40, 50 min and 60 min care each; one visit without a departure.
--   travel share = 150 / (150 + 300) = 33.3 %, base 5. T2: two persons (hidden).
select pg_temp.visit('v1', 't3', '2025-06-10', 'p1', 10), pg_temp.visit('v2', 't3', '2025-06-10', 'p2', 20),
       pg_temp.visit('v3', 't3', '2025-06-11', 'p3', 30), pg_temp.visit('v4', 't3', '2025-06-11', 'p1', 40),
       pg_temp.visit('v5', 't3', '2025-06-12', 'p2', 50), pg_temp.visit('v6', 't3', '2025-06-12', 'p3', null);
select pg_temp.visit('w1', 't2', '2025-06-10', 'q1', 15), pg_temp.visit('w2', 't2', '2025-06-10', 'q2', 15);

-- AN3-1 (c): five partner requests received 2025-06-05 08:00; their cases (team T3) ready after 2, 4, 6, 8, 10 h
--   → median 6.0, base 5. A sixth case ready in July and a case without a partner request are not counted.
insert into public.partner_requests (organization_id, id, partner_name, partner_type, region, urgency, request_title,
                                     need_summary, requested_services, status, created_at)
select '00000000-0000-4000-b000-000000000012', pg_temp.id('r' || n), 'Synthetisches Spital', 'Spital', 'Bern West', 'mittel',
       'Synthetisch AN3 ' || n, 'Synthetisch', array['Grundpflege'], 'open', pg_temp.at('2025-06-05', '08:00')
from generate_series(1, 6) n;
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency,
                          assigned_team_id, source_partner_request_id, ready_for_matching_at)
select '00000000-0000-4000-b000-000000000012', pg_temp.id('c' || n), pg_temp.at('2025-06-05', '09:00'), 'AN3 Fall ' || n,
       'AN3', 'Fall ' || n, 'Bern West', 'laufend', 'mittel', pg_temp.id('t3'), pg_temp.id('r' || n),
       case when n = 6 then pg_temp.at('2025-07-02', '08:00') else pg_temp.at('2025-06-05', '08:00') + make_interval(hours => 2 * n) end
from generate_series(1, 6) n;
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency,
                          assigned_team_id, ready_for_matching_at)
values ('00000000-0000-4000-b000-000000000012', pg_temp.id('c7'), pg_temp.at('2025-06-05', '09:00'), 'AN3 Fall 7', 'AN3',
        'Fall 7', 'Bern West', 'laufend', 'mittel', pg_temp.id('t3'), pg_temp.at('2025-06-05', '09:30'));

-- AN3-1 (d): inform_gp tasks of T3's cases.
--   Five recorded done in June after 24, 48, 72, 96, 120 h (case c1) → median 72.0, base 5.
--   Open at the end of June: opened 06-20 and 06-25 (still open), opened 06-28 and recorded on 07-03 → 3 open,
--   ages 11, 6 and 3 days → median 6.0; base 3 → "zu wenig Daten". A task marked done by a case close without a
--   recorded close time (c5) counts nowhere.
insert into public.case_tasks (organization_id, case_id, kind, status, created_at, done_at, done_by)
select '00000000-0000-4000-b000-000000000012', pg_temp.id('c1'), 'inform_gp', 'done', pg_temp.at('2025-06-01', '08:00'),
       pg_temp.at('2025-06-01', '08:00') + make_interval(hours => 24 * n), '00000000-0000-4000-a000-000000000903'
from generate_series(1, 5) n;
insert into public.case_tasks (organization_id, case_id, kind, status, created_at, done_at, done_by) values
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('c2'), 'inform_gp', 'open', pg_temp.at('2025-06-20', '00:00'), null, null),
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('c3'), 'inform_gp', 'open', pg_temp.at('2025-06-25', '00:00'), null, null),
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('c4'), 'inform_gp', 'done', pg_temp.at('2025-06-28', '00:00'),
   pg_temp.at('2025-07-03', '08:00'), '00000000-0000-4000-a000-000000000903'),
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('c5'), 'inform_gp', 'done', pg_temp.at('2025-06-26', '00:00'), null, null);

-- AN3-1 (e): seven proposals of T3 on its June visits, created 2025-06-10 08:00. Five decided after 1 … 5 h
--   (confirmed, corrected, rejected, confirmed, rejected) → median 3.0, base 5. Two undecided, their visits past → expired 2
--   of 7 created.
insert into public.ai_suggestions (id, proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field,
                                   entity_type, entity_id, input_refs, proposed_value, created_at)
select pg_temp.id('s' || n), pg_temp.id('pr' || n), '00000000-0000-4000-b000-000000000012', pg_temp.id('t3'),
       '00000000-0000-4000-a000-000000000251', 'aig1_test_primary_nurse', '1', 'responsible_user_id', 'care_visits',
       pg_temp.id('v' || ((n % 5) + 1)), jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', pg_temp.id('v' || ((n % 5) + 1)))),
       to_jsonb(pg_temp.id('p1')::text), pg_temp.at('2025-06-10', '08:00')
from generate_series(1, 7) n;
insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, confirmed_by, confirmed_at)
select pg_temp.id('s' || n), '00000000-0000-4000-b000-000000000012', pg_temp.id('t3'), o.outcome,
       case when o.outcome in ('confirmed', 'corrected') then to_jsonb(pg_temp.id('p1')::text) end,
       '00000000-0000-4000-a000-000000000903', pg_temp.at('2025-06-10', '08:00') + make_interval(hours => n)
from generate_series(1, 5) n
join (values (1, 'confirmed'), (2, 'corrected'), (3, 'rejected'), (4, 'confirmed'), (5, 'rejected')) o(k, outcome) on o.k = n;

-- A team member (no coordination role) of T3 only.
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000906', 'nurse')
on conflict do nothing;
insert into public.team_memberships (team_id, user_id, qualification)
values (pg_temp.id('t3'), '00000000-0000-4000-a000-000000000906', 'care_assistant');

-- =====================================================================================================================
-- A. Catalogue: access, never per person (AN3-3), no WORK1 table (AN3-6)
-- =====================================================================================================================
select ok(has_function_privilege('authenticated', 'public.pilot_step_spans(date)', 'execute'), 'AN3: authenticated may call the read');
select ok(not has_function_privilege('anon', 'public.pilot_step_spans(date)', 'execute'), 'AN3: anon may not');
select is((select array_agg(a order by a) from unnest((select proargnames from pg_proc where oid = 'public.pilot_step_spans(date)'::regprocedure)) a
           where a <> 'p_month'),
          array['base', 'measure', 'note', 'organization_id', 'suppressed', 'team_id', 'team_name', 'too_few', 'value']::text[],
  'AN3-3: the result has team and organisation keys and figures only');
select ok(not exists (select 1 from unnest((select proargnames from pg_proc where oid = 'public.pilot_step_spans(date)'::regprocedure)) a
                      where a ~ '(user|member|person|nurse|performer|actor|confirm|done_by|created_by|signed_by)'),
  'AN3-3: no person column in the result');
select ok((select prosrc from pg_proc where oid = 'public.pilot_step_spans(date)'::regprocedure)
          !~ '(working_day|working_time|work1_)',
  'AN3-6: the read touches no WORK1 day or segment table');
select ok((select prosecdef and provolatile = 's' from pg_proc where oid = 'public.pilot_step_spans(date)'::regprocedure),
  'AN3: a stable read (no write path)');

-- =====================================================================================================================
-- B. Figures for team T3 (coordination role)
-- =====================================================================================================================
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(pg_temp.sv('travel_share_in_visits', 't3'), 33.3::numeric, 'AN3-2: travel within visits 150 / 450 = 33.3 %');
select is(pg_temp.sb('travel_share_in_visits', 't3'), 5, 'AN3-2: a visit without a departure is not in the base');
select is(pg_temp.sv('referral_to_case_ready_hours', 't3'), 6.0::numeric, 'AN3-1 (c): median 6.0 h from partner request to case ready');
select is(pg_temp.sb('referral_to_case_ready_hours', 't3'), 5, 'AN3-1 (c): July and request-less cases are not counted');
select is(pg_temp.sv('inform_gp_done_hours', 't3'), 72.0::numeric, 'AN3-1 (d): median 72.0 h from task opened to recorded done');
select is(pg_temp.sb('inform_gp_done_hours', 't3'), 5, 'AN3-1 (d): the task recorded in July and the case-close task are not in June');
select is(pg_temp.sv('inform_gp_open_at_month_end', 't3'), 3::numeric, 'AN3-1 (d): three tasks open at the end of June');
select is(pg_temp.sv('inform_gp_open_age_days', 't3'), 6.0::numeric, 'AN3-1 (d): their median age 6.0 days at the month end');
select ok((pg_temp.s('inform_gp_open_at_month_end', 't3') ->> 'too_few')::boolean,
  'AN3-4: a figure from fewer than 5 events is "zu wenig Daten"');
select is(pg_temp.sv('proposal_decided_hours', 't3'), 3.0::numeric, 'AN3-1 (e): median 3.0 h from proposal to decision');
select is(pg_temp.sb('proposal_decided_hours', 't3'), 5, 'AN3-1 (e): decided proposals only');
select is(pg_temp.sv('proposals_corrected', 't3'), 1::numeric, 'CGR-112: one of the five decisions changed the value');
select is(pg_temp.sv('proposals_rejected', 't3') || '/' || pg_temp.sb('proposals_rejected', 't3'), '2/5',
  'CGR-112: two of the five decisions rejected it, base = the decisions of the decision span');
select is(pg_temp.sv('proposals_expired_undecided', 't3'), 2::numeric, 'AN3-1 (e), AIG1-C4: two expired proposals counted apart');
select is(pg_temp.sb('proposals_expired_undecided', 't3'), 7, 'AN3-1 (e): base = proposals created in the month');

-- =====================================================================================================================
-- C. Suppression (AN3-4)
-- =====================================================================================================================
select ok((select count(*) = 9 and bool_and(value is null and base is null and suppressed)
           from public.pilot_step_spans('2025-06-01') where team_id = pg_temp.id('t2')),
  'AN3-4: a two-person team returns no value and no base for any figure');
select ok((select bool_and(value is null and base is null and suppressed and note like 'Zu wenig Personen%')
           from public.pilot_step_spans('2025-06-01') where team_id is null and organization_id = '00000000-0000-4000-b000-000000000012'),
  'AN3-4: the organisation row is hidden while it would point at the two hidden persons (AN1 condition)');
select is((select count(distinct measure)::int from public.pilot_step_spans('2025-06-01') where team_id = pg_temp.id('t3')), 9,
  'AN3: every figure appears for a team, also without events');
reset role;

-- =====================================================================================================================
-- D. A team member reads only her team's aggregates (AN3-3)
-- =====================================================================================================================
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select ok(not exists (select 1 from public.pilot_step_spans('2025-06-01') where team_id is null),
  'AN3-3: a team member gets no organisation row');
select ok(not exists (select 1 from public.pilot_step_spans('2025-06-01') where team_id = pg_temp.id('t2')),
  'AN3-3: and no row of a team she is not in');
select is(pg_temp.sv('travel_share_in_visits', 't3'), 33.3::numeric, 'AN3-3: her own team figure is the same aggregate');
reset role;

-- =====================================================================================================================
-- E. Test clock: in the current month the "month end" is now (AN3-7, DST1)
-- =====================================================================================================================
select set_config('navora.test_now', pg_temp.at('2025-06-26', '00:00')::text, true);
insert into private.test_clock (enabled) select true where not exists (select 1 from private.test_clock where enabled);
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(pg_temp.sv('inform_gp_open_at_month_end', 't3'), 2::numeric,
  'AN3-7: on 26 June two tasks are open now (the 28 June task does not exist yet)');
select is(pg_temp.sv('inform_gp_open_age_days', 't3'), 3.5::numeric, 'AN3-7: ages 6 and 1 day → median 3.5');
reset role;

select * from finish();
rollback;
