-- VIS2 (ADR-121; PO brief docs/agents/briefs/VIS2.md; `cra` CGR-97): a second visit of the same client at an overlapping
-- time is a fact before saving, never a refusal.
-- VIS2-1 `client_visit_overlap(case, visit, date, start, end)`: half-open wall-clock intervals on the same date, other
--        visits of the case of any team, not cancelled; the visit given is excluded.
-- VIS2-2 team boundary: another team's visit counts without its time; a caller who cannot read the client gets null.
-- VIS2-4 `overlap_shown` (what the form showed, code value) on the command's existing audit row: plan_visit's
--        care_visits insert row, reschedule_visit's (and move_visit_to_today's) `moved` plan-change row.
-- VIS2-5 the command's result carries the server's own check at the save, whatever the form showed.
-- Negative: plan_visit, reschedule_visit and move_visit_to_today save an overlapping visit unchanged.
-- Users (supabase/seed.sql): nurse …902 (Testteam Nord …101) · coordinator …904 (org A, no team) · nurse …961 (org C).
-- Teams: Nord …101, Mitte …104 (org A, no member of …902). Cases …208 (Nord), …209 (Mitte). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(40);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  private.at_zurich(((private.at_zurich(private.now()))::date + time '10:00')::timestamp)::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.v(n integer) returns uuid language sql as $$
  select ('00000000-0000-4000-a098-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql as $$
  select ('a9800000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.ov(c text, v uuid, d integer, s text, e text) returns jsonb language sql as $$
  select public.client_visit_overlap(c::uuid, v, pg_temp.today() + d, s::time, e::time) $$;
-- The overlap_shown value(s) on the audit rows of a visit's plan changes.
create function pg_temp.shown(v uuid) returns text language sql as $$
  select string_agg(coalesce(a.changed -> 'overlap_shown' ->> 'new', '-'), ',' order by a.id)
  from public.audit_events a where a.table_name = 'visit_plan_changes' and a.entity_id = v $$;

-- Fixtures (as the table owner). Case …208 unless named; Nord visits name …902 as responsible.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(x.n), x.c::uuid, x.team::uuid,
       pg_temp.today() + x.d, x.t, x.e, false, x.s, 30, 0,
       case when x.team = '00000000-0000-4000-a000-000000000101' then '00000000-0000-4000-a000-000000000902'::uuid end
from (values
  (1, 20, time '09:00', time '09:30', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (2, 21, time '09:00', time '09:30', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000104'),
  (3, 22, time '09:00', time '09:30', 'cancelled', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (4, 23, time '09:00', time '09:30', 'planned',   '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104'),
  (5, 24, time '09:00', null,         'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (6, 25, time '09:00', time '09:30', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (7, 26, time '10:00', time '10:30', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (8, 27, time '09:10', time '09:40', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (9, 27, time '09:00', time '09:30', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000104'),
  (10, 0, time '15:00', time '15:30', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (11, 1, time '16:00', time '16:30', 'planned',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101'),
  (12, 28, time '11:00', time '11:30', 'planned',  '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101')
) as x(n, d, t, e, s, c, team);

-- Contract -------------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.client_visit_overlap(uuid, uuid, date, time, time)', 'execute'),
  'anon cannot call client_visit_overlap');
select ok(has_function_privilege('authenticated', 'public.client_visit_overlap(uuid, uuid, date, time, time)', 'execute'),
  'the app (authenticated) can call client_visit_overlap');
select ok((select prosecdef and array_to_string(proconfig, ',') like 'search_path=%' from pg_proc
           where oid = 'public.client_visit_overlap(uuid, uuid, date, time, time)'::regprocedure),
  'client_visit_overlap is SECURITY DEFINER with a pinned search_path');
select ok(not has_function_privilege('authenticated', 'private.client_overlap_visits(uuid, date, time, time, uuid)', 'execute'),
  'the overlap rows are not callable by the app (no new read path to visits)');
select is((select provolatile::text from pg_proc where oid = 'public.client_visit_overlap(uuid, uuid, date, time, time)'::regprocedure),
  's', 'client_visit_overlap is stable (it writes nothing)');
select is((select string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', ' | ' order by p.proname)
           from pg_proc p where p.proname in ('plan_visit', 'reschedule_visit', 'move_visit_to_today')
             and p.pronamespace = 'public'::regnamespace),
  'move_visit_to_today(p_visit_id uuid, p_shown_date date, p_time_start time without time zone, p_time_end time without time zone, p_reason text, p_idempotency_key uuid, p_overlap_shown boolean)'
  || ' | plan_visit(p_case_id uuid, p_visit_date date, p_time_start time without time zone, p_time_end time without time zone, p_minutes_a integer, p_minutes_b integer, p_minutes_c integer, p_needs_assessment boolean, p_responsible_user_id uuid, p_idempotency_key uuid, p_overlap_shown boolean)'
  || ' | reschedule_visit(p_visit_id uuid, p_visit_date date, p_time_start time without time zone, p_time_end time without time zone, p_reason text, p_idempotency_key uuid, p_overlap_shown boolean)',
  'VIS2-4: one signature each, with p_overlap_shown last (no ambiguous overload)');
select is((select class from private.audit_value_classes where table_name = 'visit_plan_changes' and key = 'overlap_shown'),
  'code', 'VIS2-4 / AUD1-1: overlap_shown is catalogued as a code');

-- VIS2-1 / VIS2-2 as a member of the case's team (case given: the planning form) -------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '09:15', '09:45'),
  '{"overlap": true, "time_start": "09:00", "time_end": "09:30"}'::jsonb, 'VIS2-1: an overlapping visit of her team is a fact with its times');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '08:30', '10:00'),
  '{"overlap": true, "time_start": "09:00", "time_end": "09:30"}'::jsonb, 'VIS2-1: a slot that contains the other visit overlaps');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '09:30', '10:00') ->> 'overlap', 'false',
  'VIS2-1: half-open: a slot starting when the other ends does not overlap');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '08:30', '09:00') ->> 'overlap', 'false',
  'VIS2-1: half-open: a slot ending when the other starts does not overlap');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 19, '09:00', '09:30') ->> 'overlap', 'false',
  'VIS2-1: the same time on another date does not overlap');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 21, '09:00', '09:30'),
  '{"overlap": true, "time_start": null, "time_end": null}'::jsonb,
  'VIS2-2: another team''s overlapping visit counts, without its times');
select is((select string_agg(k, ',' order by k)
           from jsonb_object_keys(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 21, '09:00', '09:30')) k),
  'overlap,time_end,time_start', 'VIS2-2: the answer carries no team, member, service or count');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 22, '09:00', '09:30') ->> 'overlap', 'false',
  'VIS2-1: a cancelled visit does not count');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 23, '09:00', '09:30') ->> 'overlap', 'false',
  'VIS2-1: another client''s visit at that time does not count');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 24, '09:20', '09:40'),
  '{"overlap": true, "time_start": "09:00", "time_end": "09:30"}'::jsonb,
  'VIS2-1: a visit without an end occupies start + planned minutes (09:00-09:30)');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 24, '09:30', '09:50') ->> 'overlap', 'false',
  'VIS2-1: ... and not beyond it');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 27, '09:00', '09:15'),
  '{"overlap": true, "time_start": "09:10", "time_end": "09:40"}'::jsonb,
  'VIS2-2: with her team''s and another team''s visit overlapping, only her team''s time is named');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '09:45', '09:15'), null,
  'an incomplete slot (end before start) gets no answer');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, null, '09:15'), null,
  'a slot without a start gets no answer');

-- Visit given (the /team move and "Heute machen"): the visit itself is excluded -------------------------------------
select is(pg_temp.ov(null, pg_temp.v(1), 20, '09:00', '09:30') ->> 'overlap', 'false',
  'VIS2-1: the visit being moved never overlaps itself');
select is(pg_temp.ov(null, pg_temp.v(7), 25, '09:15', '09:45'),
  '{"overlap": true, "time_start": "09:00", "time_end": "09:30"}'::jsonb, 'VIS2-1: moving a visit onto the client''s other visit is a fact');
select is(pg_temp.ov('00000000-0000-4000-a000-000000000209', pg_temp.v(7), 25, '09:15', '09:45'), null,
  'a visit given with another case gets no answer');
reset role;

-- VIS2-2: a caller who cannot read the client gets nothing -----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '09:15', '09:45'), null,
  'VIS2-2: the coordinator (no team of the case) gets no answer for the case');
select is(pg_temp.ov(null, pg_temp.v(1), 20, '09:15', '09:45'), null,
  'VIS2-2: ... nor for one of its visits');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000961');
set local role authenticated;
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '09:15', '09:45'), null,
  'VIS2-2: a nurse of another organisation gets no answer');
reset role;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);
select is(pg_temp.ov('00000000-0000-4000-a000-000000000208', null, 20, '09:15', '09:45'), null,
  'without a signed-in user: no answer');

-- Negative + VIS2-4: the saves go through unchanged and record the fact ----------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
-- The form showed nothing (the answer had not loaded): saved anyway; the result carries the server's check.
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 20, time '09:15', time '09:45',
                            30, 0, 0, false, '00000000-0000-4000-a000-000000000902', pg_temp.k(1), false) - 'visit_id',
  jsonb_build_object('result', 'ok',
                     'overlap', '{"overlap": true, "time_start": "09:00", "time_end": "09:30"}'::jsonb, 'flags', '[]'::jsonb),
  'VIS2 negative / VIS2-5: plan_visit saves an overlapping visit; its result states the overlap the form did not show');
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 29, time '09:15', time '09:45',
                            30, 0, 0, false, '00000000-0000-4000-a000-000000000902', pg_temp.k(2), false) -> 'overlap' ->> 'overlap',
  'false', 'plan_visit saves a visit without an overlap; its result says so');
select is(public.reschedule_visit(pg_temp.v(7), pg_temp.today() + 25, time '09:15', time '09:45', 'Testgrund', pg_temp.k(3), true)
          -> 'overlap', '{"overlap": true, "time_start": "09:00", "time_end": "09:30"}'::jsonb,
  'VIS2 negative: reschedule_visit moves a visit onto the client''s other visit (ok, with the overlap)');
select is(public.reschedule_visit(pg_temp.v(12), pg_temp.today() + 28, time '13:00', time '13:30', 'Testgrund', pg_temp.k(4))
          ->> 'result', 'ok', 'reschedule_visit with the old arguments still moves (no overlap_shown recorded)');
select is(public.move_visit_to_today(pg_temp.v(11), pg_temp.today(), time '15:10', time '15:40', 'Testgrund', pg_temp.k(5), true)
          -> 'overlap' ->> 'overlap', 'true', 'VIS2 negative: "Heute machen" onto the client''s visit of today completes');
reset role;

select is((select visit_date - pg_temp.today() || ' ' || time_start::text from public.care_visits where id = pg_temp.v(7)),
  '25 09:15:00', 'the overlapping move is stored as chosen');
select is((select visit_date = pg_temp.today() and time_start = time '15:10' from public.care_visits where id = pg_temp.v(11)),
  true, 'the "Heute machen" move is stored as chosen');
-- The audit row of plan_visit: the care_visits insert row of the new visit.
create function pg_temp.plan_shown(d integer) returns text language sql as $$
  select string_agg(coalesce(a.changed -> 'overlap_shown' ->> 'new', '-'), ',' order by a.id)
  from public.audit_events a join public.care_visits v on v.id = a.entity_id
  where a.table_name = 'care_visits' and a.command = 'plan_visit' and a.changed ? 'status'
    and v.case_id = '00000000-0000-4000-a000-000000000208' and v.visit_date = pg_temp.today() + d $$;
select is(pg_temp.plan_shown(20), 'false', 'VIS2-4: the insert row records what the form showed (false), not the server''s check');
select is(pg_temp.plan_shown(29), 'false', 'VIS2-4: the insert row of the free plan records overlap_shown = false');
select is(pg_temp.shown(pg_temp.v(7)) || '|' || pg_temp.shown(pg_temp.v(12)) || '|' || pg_temp.shown(pg_temp.v(11)),
  'true|-|true', 'VIS2-4: each move''s row records what the form showed; an old caller records nothing');
select is((select count(*)::int from public.audit_events
           where changed ? 'overlap_shown'
             and not (table_name = 'visit_plan_changes' and command in ('reschedule_visit', 'move_visit_to_today'))
             and not (table_name = 'care_visits' and command = 'plan_visit' and changed ? 'status')), 0,
  'VIS2-4: only the command''s own audit row carries it (no update, release or other row)');
select is(current_setting('navora.overlap_shown', true), '', 'the transaction-local marker is reset after each save');

select * from finish();
rollback;
