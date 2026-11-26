-- ORDER-F1-F2 (PO Active now 2026-11-26 01:39 point 3; migration 0179). The automatic take re-check at every visit,
-- absence or qualification write (bk_c1_recheck_takes -> private.recheck_member_takes) costs work only for the member's
-- takes of orders not yet started. Before 0179 the loop query applied private.take_visit_under_way (sql, security
-- definer, not inlined, reads care_visits) to EVERY live take of hers, including takes of orders that already started,
-- and filtered those only afterwards, by `p.starts_at > private.now()`, which itself ran once per order row the plan
-- visited (sql security definer, never inlined). With unanalyzed tables pgTAP 178 hung computing in its 2 000-visit
-- insert (ci-repeat run 45730014560, db attempt 8, job 139609445952: 25 min, no wait event, no blocker; with a statement
-- bound the cancel lands inside private.now() under recheck_member_takes, ci-repeat run 45736138812 attempt 7). A third
-- cost: the loop query's plan was cached in the session while her takes were few (178 section 3 re-checks her 2 376
-- times with none) and reused for 1 000 (diag job 139639776198: 129 ms per write, every batch); it is now planned at
-- every call.
-- Deterministic (call counts, no wall clock; track_functions = all is set by the db job and asserted first). This file
-- proves:
-- (1) Cost: M1 holds 50 live takes of started orders and 1 of an order not yet started. One visit write for her calls
--     take_visit_under_way exactly once (before 0179: 51 times) and order_member_step once (positive control: the
--     re-check ran for her one take that can still be released); private.now() runs fewer times than she has takes
--     (the re-check reads the clock once).
-- (2) Behaviour kept: the take of the order not yet started stays live after a write that leaves her eligible; an absence
--     over its slot releases it (release_reason step_3, CGR-223 (c)); the 50 takes of started orders are never touched.
-- (3) Same rows, same order: for every member who holds a live take (seed and fixture), the previous loop query (frozen
--     copy, recovery/main ac3358b4) and the new one return the same take ids in the same order.
-- (4) Guards kept: person lock before the read (CGR-255) and the under-way refusal (CGR-244) are in pgTAP 148; security
--     definer, search_path, grants and the required substrings are in the generated pgTAP 157.
-- Users: kundebs …9e8 (client). Synthetic: M1 (nurse in team T1 of org 019, verified FaGe; in team TV of org 011 for her
-- visits). Pinned clock, moved forward only. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(13);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.clock(ts text) returns void language sql as $$ select set_config('navora.test_now', ts, true) $$;
create function pg_temp.m1() returns uuid language sql immutable as $$ select '00000000-0000-4000-a179-000000000001'::uuid $$;
create function pg_temp.t1() returns uuid language sql immutable as $$ select '00000000-0000-4000-b179-000000000001'::uuid $$;
create function pg_temp.tv() returns uuid language sql immutable as $$ select '00000000-0000-4000-b179-000000000002'::uuid $$;
create function pg_temp.cv() returns uuid language sql immutable as $$ select '00000000-0000-4000-c179-000000000001'::uuid $$;
create function pg_temp.po(i int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-e179-' || lpad(i::text, 12, '0'))::uuid $$;
create function pg_temp.calls(f text) returns bigint language sql volatile as $$
  select coalesce((select s.calls from pg_stat_xact_user_functions s where s.schemaname = 'private' and s.funcname = f), 0)
$$;
create temp table mark (k text primary key, under_way bigint, member_step bigint, clock bigint);
create function pg_temp.mark(k text) returns void language sql as $$
  insert into mark values (k, pg_temp.calls('take_visit_under_way'), pg_temp.calls('order_member_step'), pg_temp.calls('now'))
$$;

select is(current_setting('track_functions'), 'all', 'the db job sets track_functions = all, so the call counts below measure');

-- Fixture (synthetic), as the table owner ------------------------------------------------------------------------------------
select pg_temp.clock('2026-10-20 10:00:00+02');
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003e0', '00000000-0000-4000-b000-000000000019', 'Haushalt ORDER-F1-F2 (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003e0', '00000000-0000-4000-a000-0000000009e8');
insert into auth.users (id, aud, role, email) values (pg_temp.m1(), 'authenticated', 'authenticated', 'order-f1-f2-m1.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'nurse'), ('00000000-0000-4000-b000-000000000011', pg_temp.m1(), 'nurse');
insert into public.member_profiles (organization_id, user_id, display_name) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.m1(), 'Synth ORDER-F1-F2 M1');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.t1(), 'ORDER-F1-F2 Fixture T1', 'Basel-Landschaft', 'active', 10);
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.tv(), 'ORDER-F1-F2 Fixture TV', 'Bern Nord', 'active');
insert into public.team_service_postcodes (team_id, postcode) values (pg_temp.t1(), '4102');
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.t1(), pg_temp.m1(), 'care_assistant'), (pg_temp.tv(), pg_temp.m1(), 'registered_nurse');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  values ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'grade', 'fage_efz', 'verified', true, null);
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.cv(), 'assigned_team_id', pg_temp.tv(),
          'auto_planning', false, 'primary_nurse_id', null, 'deputy_nurse_id', null, 'proposed_primary_nurse_id', null))).*
from kc k;

create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(k text, d date, s time, e time, key text) returns void language sql as $$
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003e0'::uuid, d, s, e, '4102',
                                                         'fage_efz', array['C1'], array['C1'], null, key::uuid)
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
create function pg_temp.take(k text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m1()::text);
  set local role authenticated;
  res := public.take_order(pg_temp.oid(k), pg_temp.t1(), pg_temp.m1(), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end $$;
create function pg_temp.confirm(k text, d date, key text) returns void language plpgsql as $$
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  perform pg_temp.co(k, d, time '08:00', time '12:00', key);
  reset role;
  perform pg_temp.as_owner();
end $$;

-- P: the template of the started orders (taken before its start); F: the order not yet started at the measuring clock.
select pg_temp.confirm('p', date '2026-10-29', 'dddd0000-0000-4000-8179-000000000001');
select is(pg_temp.take('p', 'ffff0000-0000-4000-8179-000000000001') ->> 'result', 'ok', 'M1 takes order P before its start');
select pg_temp.clock('2026-11-25 10:00:00+01');
select pg_temp.confirm('f', date '2026-12-01', 'dddd0000-0000-4000-8179-000000000002');
select is(pg_temp.take('f', 'ffff0000-0000-4000-8179-000000000002') ->> 'result', 'ok', 'M1 takes order F before its start');
-- 49 more started orders with a live take of hers (copies of P a day apart), as a carer collects them over weeks.
create temp table pt as select * from public.partner_requests where id = pg_temp.oid('p');
insert into public.partner_requests
select (jsonb_populate_record(b, jsonb_build_object('id', pg_temp.po(i),
          'starts_at', b.starts_at - make_interval(days => i), 'ends_at', b.ends_at - make_interval(days => i)))).*
from pt b, generate_series(1, 49) i;
create temp table kt as select * from public.order_takes where order_id = pg_temp.oid('p') and released_at is null;
insert into public.order_takes
select (jsonb_populate_record(k, jsonb_build_object('id', gen_random_uuid(), 'order_id', pg_temp.po(i),
          'taken_at', k.taken_at - make_interval(days => i), 'acknowledged_at', k.acknowledged_at - make_interval(days => i)))).*
from kt k, generate_series(1, 49) i;
select pg_temp.clock('2026-11-30 10:00:00+01');
create function pg_temp.live(started boolean) returns int language sql as $$
  select count(*)::int from public.order_takes t join public.partner_requests p on p.id = t.order_id
  where t.member_id = pg_temp.m1() and t.released_at is null and (p.starts_at <= private.now()) = started
$$;
select ok(pg_temp.live(true) = 50 and pg_temp.live(false) = 1,
          'M1 holds 50 live takes of started orders and 1 of an order not yet started');

-- (3) Same rows, same order: the previous loop query (frozen copy of recovery/main ac3358b4) against the new one -------------
create function pg_temp.rows_old(p_user uuid) returns uuid[] language sql as $$
  select coalesce(array_agg(x.id order by x.ord), '{}') from (
    select t.id, row_number() over (order by p.starts_at, t.id) as ord
    from public.order_takes t join public.partner_requests p on p.id = t.order_id
    where t.member_id = p_user and t.released_at is null and p.starts_at > private.now()
      and not private.take_visit_under_way(t.id)) x
$$;
create function pg_temp.rows_new(p_user uuid, now_ timestamptz) returns uuid[] language sql as $$
  select coalesce(array_agg(x.id order by x.ord), '{}') from (
    with live as materialized (
      select t.id, t.order_id, t.team_id, t.member_id, p.starts_at
      from public.order_takes t join public.partner_requests p on p.id = t.order_id
      where t.member_id = p_user and t.released_at is null and p.starts_at > now_)
    select l.id, row_number() over (order by l.starts_at, l.id) as ord
    from live l
    where not private.take_visit_under_way(l.id)) x
$$;
select is((select count(*)::int from (select distinct member_id from public.order_takes where released_at is null) m
           where pg_temp.rows_old(m.member_id) is distinct from pg_temp.rows_new(m.member_id, private.now())), 0,
          'ORDER-F1-F2: for every member with a live take, the new loop query returns the previous takes in the same order');
select ok(strpos(pg_get_functiondef('private.recheck_member_takes(uuid)'::regprocedure), 'now_ := private.now();') > 0
          and strpos(pg_get_functiondef('private.recheck_member_takes(uuid)'::regprocedure), 'with live as materialized (') > 0
          and strpos(pg_get_functiondef('private.recheck_member_takes(uuid)'::regprocedure), 'p.starts_at > $2)') > 0
          and strpos(pg_get_functiondef('private.recheck_member_takes(uuid)'::regprocedure), 'using p_user, now_') > 0
          and strpos(pg_get_functiondef('private.recheck_member_takes(uuid)'::regprocedure),
                     'where not private.take_visit_under_way(l.id)') > 0,
          'the deployed function holds exactly the new loop query compared above');

-- (1) Cost of one visit write ------------------------------------------------------------------------------------------------
select pg_temp.mark('visit0');
insert into public.care_visits (organization_id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.cv(), pg_temp.tv(), date '2026-12-03', '14:00', '15:00',
        array['Grundpflege'], false, 'planned', 30, 0, pg_temp.m1());
select pg_temp.mark('visit1');
select is((select b.member_step - a.member_step from mark a, mark b where a.k = 'visit0' and b.k = 'visit1')::int, 1,
          'positive control: the visit write re-checked her one take of an order not yet started (order_member_step once)');
select is((select b.under_way - a.under_way from mark a, mark b where a.k = 'visit0' and b.k = 'visit1')::int, 1,
          'ORDER-F1-F2: one visit write reads take_visit_under_way once, not once per take of a started order (before: 51)');
select cmp_ok((select b.clock - a.clock from mark a, mark b where a.k = 'visit0' and b.k = 'visit1')::int, '<', 51,
          'ORDER-F1-F2: the visit write reads private.now() fewer times than she has live takes (the re-check reads it once)');
select ok(pg_temp.live(true) = 50 and pg_temp.live(false) = 1,
          'a write that leaves her eligible releases nothing: all 51 takes stay live');

-- (2) Release kept: an absence over F's slot releases F's take, and only it -------------------------------------------------
select pg_temp.mark('abs0');
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
select '00000000-0000-4000-b000-000000000019', pg_temp.t1(), pg_temp.m1(), o.starts_at - interval '1 hour',
       o.ends_at + interval '1 hour', pg_temp.m1()
from public.partner_requests o where o.id = pg_temp.oid('f');
select pg_temp.mark('abs1');
select is((select t.release_reason from public.order_takes t where t.order_id = pg_temp.oid('f') order by t.taken_at desc limit 1),
          'step_3', 'an absence over the slot still releases the take of the order not yet started (step 3, CGR-223 (c))');
select is((select b.under_way - a.under_way from mark a, mark b where a.k = 'abs0' and b.k = 'abs1')::int, 1,
          'the absence write reads take_visit_under_way once (her one take of an order not yet started)');
select is(pg_temp.live(true), 50, 'the 50 takes of started orders are never touched by the re-check');

select * from finish();
rollback;
