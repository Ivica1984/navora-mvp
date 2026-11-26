-- ORDER-F1-F5 «the offer reasons read the clock once, whatever the plan» (PO Active now 2026-11-26 06:39 point 3).
-- Written BEFORE the fix (red first): the deployed private.order_offer_reasons is still the BK-c3 definition of
-- migration 0137 (no later migration re-creates it).
-- Cause (eng on #1774, 7183569299; ci-repeat 45759933656, db repeat 3, job 139707344810, pgTAP 180 test 9:
-- private.now() 2 003 007 calls instead of 1 007): `knows_client` compares `q.ends_at <= private.now()` on every row of
-- the client's orders `q` when the planner drives the join from partner_requests (client index) instead of from the
-- team's takes. The call count then follows the client's order history, not the call: a plan-dependent scaling defect.
--
-- Deterministic: call counts from pg_stat_xact_user_functions (track_functions = all, set by the db job and asserted
-- first); the planner is pinned per case with transaction-local settings (they reach the security definer function,
-- whose only own setting is search_path). Wall time is printed with diag() only.
-- The clock reads of the function's own body are the reads of one statement minus a baseline: the same statement
-- with only the member_free branch (pg_temp.reasons_base), because the nested private.order_member_step may read the
-- clock itself (first red run on 28a16255, ci 45767019483, db job 139730245834: 47 reads for 46 calls in every plan,
-- old and new alike; that one read is the helper's, not this function's, and is now subtracted).
--
-- What it proves:
-- (1) Positive control: the frozen BK-c3 definition (pg_temp copy of 0137) reads the clock more than once per call
--     under at least one pinned plan, so this fixture reproduces the defect (stays true after the fix).
-- (2) For each pinned plan (default; index scans only, so partner_requests is entered by the client index; sequential
--     scans with hash joins; the join order as written, nested loops only) the deployed function calls private.now()
--     at most once per call.
-- (3) Same clause codes: under every pinned plan the deployed function returns, for every (order, team) pair of the
--     fixture, exactly the codes of the frozen definition under the default plan. No rule changes.
-- (4) The rule itself, unchanged: T1 (an ended, acknowledged, never released take for the client) gets knows_client on
--     the client's other orders; not on the order of that take itself (q <> o); T2, whose take is of a slot not yet
--     ended, gets none.
-- (5) Guards kept: security definer, search_path '', no execute for PUBLIC, anon or authenticated; the clock CTE.
-- Users: kundebs …9e8 (client). Synthetic: M1 (nurse, T1), M2 (nurse, T2), org 019, verified FaGe.
-- Pinned clock, moved forward only. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.clock(ts text) returns void language sql as $$ select set_config('navora.test_now', ts, true) $$;
create function pg_temp.m1() returns uuid language sql immutable as $$ select '00000000-0000-4000-a181-000000000001'::uuid $$;
create function pg_temp.m2() returns uuid language sql immutable as $$ select '00000000-0000-4000-a181-000000000002'::uuid $$;
create function pg_temp.t1() returns uuid language sql immutable as $$ select '00000000-0000-4000-b181-000000000001'::uuid $$;
create function pg_temp.t2() returns uuid language sql immutable as $$ select '00000000-0000-4000-b181-000000000002'::uuid $$;
create function pg_temp.fo(i int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-e181-' || lpad(i::text, 12, '0'))::uuid $$;
create function pg_temp.po(i int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-f181-' || lpad(i::text, 12, '0'))::uuid $$;

select is(current_setting('track_functions'), 'all', 'the db job sets track_functions = all, so the call counts below measure');

-- The frozen BK-c3 definition (migration 0137, unchanged since), for the positive control and the equivalence.
create function pg_temp.reasons_old(p_order_id uuid, p_team_id uuid)
returns text[] language sql stable security definer set search_path = ''
as $old$
  select array_remove(array[
    case when exists (select 1 from public.team_memberships m
                      where m.team_id = p_team_id
                        and private.order_member_step(p_order_id, p_team_id, m.user_id) = 4)
         then 'member_free' end,
    case when exists (select 1 from public.order_takes t
                      join public.partner_requests q on q.id = t.order_id
                      join public.partner_requests o on o.id = p_order_id
                      where t.team_id = p_team_id
                        and q.id <> o.id
                        and q.client_account_id = o.client_account_id
                        and q.ends_at <= private.now()
                        and t.acknowledged_at is not null
                        and t.released_at is null)
         then 'knows_client' end
  ], null)
$old$;

-- Baseline: the member_free branch alone (identical in both definitions), to subtract the nested helper's clock reads.
create function pg_temp.reasons_base(p_order_id uuid, p_team_id uuid)
returns text[] language sql stable security definer set search_path = ''
as $base$
  select array_remove(array[
    case when exists (select 1 from public.team_memberships m
                      where m.team_id = p_team_id
                        and private.order_member_step(p_order_id, p_team_id, m.user_id) = 4)
         then 'member_free' end
  ], null)
$base$;

-- Fixture (synthetic), as the table owner ------------------------------------------------------------------------------------
select pg_temp.clock('2026-11-24 10:00:00+01');
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003f5', '00000000-0000-4000-b000-000000000019', 'Haushalt ORDER-F1-F5 (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003f5', '00000000-0000-4000-a000-0000000009e8');
insert into auth.users (id, aud, role, email) values
  (pg_temp.m1(), 'authenticated', 'authenticated', 'order-f1-f5-m1.fixture@navora.test'),
  (pg_temp.m2(), 'authenticated', 'authenticated', 'order-f1-f5-m2.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'nurse'), ('00000000-0000-4000-b000-000000000019', pg_temp.m2(), 'nurse');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.t1(), 'ORDER-F1-F5 Fixture T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', pg_temp.t2(), 'ORDER-F1-F5 Fixture T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values (pg_temp.t1(), '4102'), (pg_temp.t2(), '4102');
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.t1(), pg_temp.m1(), 'care_assistant'), (pg_temp.t2(), pg_temp.m2(), 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  values ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'grade', 'fage_efz', 'verified', true, null),
         ('00000000-0000-4000-b000-000000000019', pg_temp.m2(), 'grade', 'fage_efz', 'verified', true, null);

create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.confirm(k text, d date, key text) returns void language plpgsql as $$
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003f5'::uuid, d, time '08:00',
                                                         time '12:00', '4102', 'fage_efz', array['C1'], array['C1'], null,
                                                         key::uuid);
  reset role;
  perform pg_temp.as_owner();
end $$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
create function pg_temp.take(k text, team uuid, member uuid, key text) returns text language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(member::text);
  set local role authenticated;
  res := public.take_order(pg_temp.oid(k), team, member, key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return coalesce(res ->> 'result', 'null') || coalesce('/' || (res ->> 'reason'), '');
end $$;

-- p: T1's own take (self-named, so acknowledged), ended at the read; n: T2's own take of a slot not ended at the read;
-- f: the open order whose copies are read.
select pg_temp.confirm('p', date '2026-11-26', 'dddd0000-0000-4000-8181-000000000001');
select pg_temp.confirm('n', date '2026-12-10', 'dddd0000-0000-4000-8181-000000000002');
select pg_temp.confirm('f', date '2026-12-01', 'dddd0000-0000-4000-8181-000000000003');
select is(array[pg_temp.take('p', pg_temp.t1(), pg_temp.m1(), 'ffff0000-0000-4000-8181-000000000001'),
                pg_temp.take('n', pg_temp.t2(), pg_temp.m2(), 'ffff0000-0000-4000-8181-000000000002')],
          array['ok', 'ok'], 'precondition: M1 (T1) takes p, M2 (T2) takes n, both self-named');
select ok((select bool_and(t.acknowledged_at is not null and t.released_at is null) from public.order_takes t
           where t.order_id in (pg_temp.oid('p'), pg_temp.oid('n'))),
          'precondition: both takes are acknowledged and never released');

-- The client's order history: 300 ended copies of f (the side the bad plan scans per call) and 20 future copies.
create temp table ft as select * from public.partner_requests where id = pg_temp.oid('f');
insert into public.partner_requests
select (jsonb_populate_record(b, jsonb_build_object('id', pg_temp.po(i),
          'starts_at', b.starts_at - make_interval(days => 10, hours => i), 'ends_at', b.ends_at - make_interval(days => 10, hours => i)))).*
from ft b, generate_series(1, 300) i;
insert into public.partner_requests
select (jsonb_populate_record(b, jsonb_build_object('id', pg_temp.fo(i),
          'starts_at', b.starts_at + make_interval(hours => i), 'ends_at', b.ends_at + make_interval(hours => i)))).*
from ft b, generate_series(1, 20) i;
analyze public.partner_requests;
analyze public.order_takes;

select pg_temp.clock('2026-11-28 10:00:00+01');  -- p has ended, n and f have not

-- The (order, team) pairs read: every future copy for both teams, f, p and n for both teams.
create temp table pairs (order_id uuid, team_id uuid, primary key (order_id, team_id));
insert into pairs
select o.id, t.id
from (select pg_temp.fo(i) from generate_series(1, 20) i
      union all select pg_temp.oid('f') union all select pg_temp.oid('p') union all select pg_temp.oid('n')) o(id),
     (values (pg_temp.t1()), (pg_temp.t2())) t(id);
select is((select count(*)::int from pairs), 46, 'precondition: 46 (order, team) pairs');
select cmp_ok((select count(*)::int from public.partner_requests q
               where q.client_account_id = '00000000-0000-4000-a000-0000000003f5'), '>=', 323,
              'precondition: the client holds at least 323 orders (300 ended copies, 20 future copies, p, n, f)');

-- Pinned plans (transaction-local planner settings; each case resets the others) -------------------------------------------
create temp table plan_case (k text primary key, ord int, settings jsonb);
insert into plan_case values
  ('plan_default', 1, '{}'),
  ('plan_index_only', 2, '{"enable_seqscan": "off"}'),
  ('plan_seq_hash', 3, '{"enable_indexscan": "off", "enable_bitmapscan": "off", "enable_indexonlyscan": "off", "enable_nestloop": "off"}'),
  ('plan_written_order', 4, '{"join_collapse_limit": "1", "from_collapse_limit": "1", "enable_hashjoin": "off", "enable_mergejoin": "off"}');
create temp table planner_default as
select s.name, current_setting(s.name) as setting
from unnest(array['enable_seqscan', 'enable_indexscan', 'enable_bitmapscan', 'enable_indexonlyscan', 'enable_nestloop',
                  'enable_hashjoin', 'enable_mergejoin', 'join_collapse_limit', 'from_collapse_limit']) s(name);
create function pg_temp.pin(p_k text) returns void language plpgsql as $$
declare r record;
begin
  for r in select d.name, coalesce(c.settings ->> d.name, d.setting) as v
           from planner_default d left join plan_case c on c.k = p_k loop
    perform set_config(r.name, r.v, true);
  end loop;
end $$;
create function pg_temp.now_calls() returns bigint language sql as $$
  select coalesce(sum(s.calls), 0)::bigint from pg_stat_xact_user_functions s where s.schemaname = 'private' and s.funcname = 'now'
$$;

-- Clock reads of a definition's own body under one plan: its statement minus the baseline statement.
create function pg_temp.own_reads(p_k text, p_def text) returns bigint language sql as $$
  select d.now_calls - b.now_calls from cost d join cost b on b.k = d.k and b.def = 'base' where d.k = p_k and d.def = p_def
$$;
create temp table got (k text, def text, order_id uuid, team_id uuid, codes text[], primary key (k, def, order_id, team_id));
create temp table cost (k text, def text, calls bigint, now_calls bigint, primary key (k, def));
-- One statement per (plan, definition): the function body is planned at its first call under the pinned settings.
create function pg_temp.run(p_k text, p_def text) returns void language plpgsql as $$
declare n0 bigint; n bigint; t0 timestamptz;
begin
  perform pg_temp.pin(p_k);
  n0 := pg_temp.now_calls();
  t0 := clock_timestamp();
  execute format('insert into got select %L, %L, x.order_id, x.team_id, %s(x.order_id, x.team_id) from pairs x',
                 p_k, p_def, case p_def when 'old' then 'pg_temp.reasons_old' when 'base' then 'pg_temp.reasons_base'
                                 else 'private.order_offer_reasons' end);
  get diagnostics n = row_count;
  insert into cost values (p_k, p_def, n, pg_temp.now_calls() - n0);
  perform pg_temp.pin('plan_default');
  raise notice 'ORDER-F1-F5 % % : % calls, % private.now() calls, % ms wall', p_def, p_k, n,
    (select c.now_calls from cost c where c.k = p_k and c.def = p_def),
    round(extract(epoch from clock_timestamp() - t0) * 1000);
end $$;
select pg_temp.run(c.k, d.def) from plan_case c, (values ('base'), ('old'), ('new')) d(def) order by c.ord, d.def;
select diag(format('ORDER-F1-F5 %s %s: %s calls, %s private.now() calls in the statement', c.def, c.k, c.calls, c.now_calls))
from cost c join plan_case p on p.k = c.k order by p.ord, c.def;

-- (1) Positive control ------------------------------------------------------------------------------------------------------
select is((select count(*)::int from cost where calls <> 46), 0, 'every case made 46 calls');
select ok((select bool_or(pg_temp.own_reads(c.k, 'old') > c.calls) from cost c where c.def = 'old'),
          'positive control: the frozen BK-c3 definition reads the clock more than once per call under a pinned plan');

-- (2) At most one clock read per call, under every pinned plan ---------------------------------------------------------------
select cmp_ok(pg_temp.own_reads('plan_default', 'new'), '<=', 46::bigint,
              'ORDER-F1-F5: default plan: at most one private.now() call per order_offer_reasons call');
select cmp_ok(pg_temp.own_reads('plan_index_only', 'new'), '<=', 46::bigint,
              'ORDER-F1-F5: index scans only (client index first): at most one private.now() call per call');
select cmp_ok(pg_temp.own_reads('plan_seq_hash', 'new'), '<=', 46::bigint,
              'ORDER-F1-F5: sequential scans, hash joins: at most one private.now() call per call');
select cmp_ok(pg_temp.own_reads('plan_written_order', 'new'), '<=', 46::bigint,
              'ORDER-F1-F5: join order as written, nested loops: at most one private.now() call per call');

-- (3) Same clause codes for every pair, under every plan ----------------------------------------------------------------------
create function pg_temp.differ(p_k text, p_def text) returns int language sql as $$
  select count(*)::int from got a join got b on b.order_id = a.order_id and b.team_id = a.team_id
  where a.k = 'plan_default' and a.def = 'old' and b.k = p_k and b.def = p_def and a.codes is distinct from b.codes
$$;
select is((select count(*)::int from got), 46 * 12, 'every (plan, definition) case read every pair once');
select is(pg_temp.differ('plan_default', 'new'), 0, 'ORDER-F1-F5: default plan: the same codes as BK-c3 for every pair');
select is(pg_temp.differ('plan_index_only', 'new'), 0, 'ORDER-F1-F5: index scans only: the same codes for every pair');
select is(pg_temp.differ('plan_seq_hash', 'new'), 0, 'ORDER-F1-F5: sequential scans, hash joins: the same codes for every pair');
select is(pg_temp.differ('plan_written_order', 'new'), 0, 'ORDER-F1-F5: join order as written: the same codes for every pair');

-- (4) The rule, unchanged -------------------------------------------------------------------------------------------------------
select ok((select bool_and('knows_client' = any(g.codes)) from got g
           where g.k = 'plan_default' and g.def = 'new' and g.team_id = pg_temp.t1() and g.order_id <> pg_temp.oid('p')),
          'knows_client: T1 (ended, acknowledged, never released take p) on every other order of the client');
select ok((select not ('knows_client' = any(g.codes)) from got g
           where g.k = 'plan_default' and g.def = 'new' and g.team_id = pg_temp.t1() and g.order_id = pg_temp.oid('p')),
          'knows_client needs an EARLIER order: not on p itself (q <> o)');
select is((select count(*)::int from got g
           where g.def = 'new' and g.team_id = pg_temp.t2() and 'knows_client' = any(g.codes)), 0,
          'knows_client needs an ended slot: T2 (take n not ended) gets it under no plan');

-- (5) Guards kept ----------------------------------------------------------------------------------------------------------------
select ok((select p.prosecdef and 'search_path=""' = any(p.proconfig)
           from pg_proc p where p.oid = 'private.order_offer_reasons(uuid, uuid)'::regprocedure),
          'private.order_offer_reasons: security definer and empty search_path kept');
select ok(not has_function_privilege('authenticated', 'private.order_offer_reasons(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'private.order_offer_reasons(uuid, uuid)', 'execute')
          and not exists (select 1 from pg_proc p, aclexplode(p.proacl) a
                          where p.oid = 'private.order_offer_reasons(uuid, uuid)'::regprocedure and a.grantee = 0),
          'private.order_offer_reasons: no execute for PUBLIC, anon or authenticated');
select ok(strpos(pg_get_functiondef('private.order_offer_reasons(uuid, uuid)'::regprocedure),
                 'with clock as materialized (select private.now() as now_)') > 0
          and strpos(pg_get_functiondef('private.order_offer_reasons(uuid, uuid)'::regprocedure), 'from clock c') > 0,
          'the deployed function reads the clock in one materialised CTE of the outer select');

select * from finish();
rollback;
