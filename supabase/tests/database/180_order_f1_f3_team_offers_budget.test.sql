-- ORDER-F1-F3 «the team offer list stays fast as orders grow» (PO Active now 2026-11-26 02:39 point 2, scope (a)).
-- Budget at target size BEFORE the fix: red first on recovery/main 5808e9bd (canonical source
-- supabase/schema/functions/public.team_order_offers.sql, unchanged since BK-c3 / HD-2 slice 5).
-- Cause on staging (eng 7179833552): /team re-render waited on team_order_offers() for 6 934 ms (normally 1.2-1.5 s,
-- statement timeout 8 s); per-function root cause UNKNOWN until this file measures it.
--
-- Deterministic (call counts from pg_stat_xact_user_functions, no wall clock asserted; track_functions = all is set by
-- the db job and asserted first). Wall time and per-function self time are printed with diag() only, as the diagnostic.
--
-- What it proves:
-- (1) Size: carer M1 (team T1) sees 1 000 future open offers plus F and her own taken order H.
-- (2) Cost follows the caller, not the platform: adding, for ANOTHER team T2, 1 001 current-round offers on the same
--     orders, 1 000 ended orders offered to T1 and T2, and 1 000 released takes of T2, changes neither M1's rows nor
--     the number of calls of any helper function one team_order_offers() call makes for her (one test per helper).
--     Hypotheses from the source (UNKNOWN until this runs): `is_team_member` and `order_round` run per order_offers
--     row of every team before the membership filter removes it; `private.now()` runs per row; `last_release` reads
--     every released take of the platform.
-- (3) Guards kept (must stay green through the fix): M2 (T2) reads T2 rows only; after M1's access ended (LEAVE1-3)
--     she reads no row.
-- Not here: equivalence old/new and the deployed-text check (added with the fix, same PR).
-- Users: kundebs …9e8 (client). Synthetic: M1 (nurse, T1, org 019, verified FaGe), M2 (nurse, T2, org 019).
-- Pinned clock, moved forward only. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(15);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.clock(ts text) returns void language sql as $$ select set_config('navora.test_now', ts, true) $$;
create function pg_temp.m1() returns uuid language sql immutable as $$ select '00000000-0000-4000-a180-000000000001'::uuid $$;
create function pg_temp.m2() returns uuid language sql immutable as $$ select '00000000-0000-4000-a180-000000000002'::uuid $$;
create function pg_temp.t1() returns uuid language sql immutable as $$ select '00000000-0000-4000-b180-000000000001'::uuid $$;
create function pg_temp.t2() returns uuid language sql immutable as $$ select '00000000-0000-4000-b180-000000000002'::uuid $$;
create function pg_temp.fo(i int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-e180-' || lpad(i::text, 12, '0'))::uuid $$;
create function pg_temp.po(i int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-f180-' || lpad(i::text, 12, '0'))::uuid $$;

-- The helpers one team_order_offers() call may reach (private schema).
create temp table helper (f text primary key);
insert into helper values ('is_team_member'), ('access_ended'), ('order_round'), ('now'), ('order_latest_cover_at'),
                          ('order_member_step'), ('order_offer_reasons');
create temp table stat (k text, f text, calls bigint, self_ms double precision, primary key (k, f));
create function pg_temp.snap(p_k text) returns void language sql as $$
  insert into stat select p_k, h.f, coalesce(sum(s.calls), 0), coalesce(sum(s.self_time), 0)
  from helper h left join pg_stat_xact_user_functions s on s.schemaname = 'private' and s.funcname = h.f
  group by h.f
$$;
create temp table seen (k text, ord int, order_id uuid, team_id uuid, offer_state text, primary key (k, ord));
grant all on seen to authenticated;
-- One call of team_order_offers() as `uid`; rows kept under `k`; calls of each helper before (k||'0') and after (k||'1').
create function pg_temp.offers(p_k text, uid uuid) returns int language plpgsql as $$
declare t0 timestamptz; n int;
begin
  perform pg_temp.snap(p_k || '0');
  perform pg_temp.act_as(uid::text);
  set local role authenticated;
  t0 := clock_timestamp();
  insert into seen select p_k, (row_number() over ())::int, o.order_id, o.team_id, o.offer_state from public.team_order_offers() o;
  get diagnostics n = row_count;
  reset role;
  perform pg_temp.as_owner();
  perform pg_temp.snap(p_k || '1');
  raise notice 'ORDER-F1-F3 % : % rows, % ms wall', p_k, n, round(extract(epoch from clock_timestamp() - t0) * 1000);
  return n;
end $$;
create function pg_temp.used(p_k text, p_f text) returns bigint language sql as $$
  select b.calls - a.calls from stat a join stat b on b.f = a.f and b.k = p_k || '1' where a.k = p_k || '0' and a.f = p_f
$$;

select is(current_setting('track_functions'), 'all', 'the db job sets track_functions = all, so the call counts below measure');

-- Fixture (synthetic), as the table owner ------------------------------------------------------------------------------------
select pg_temp.clock('2026-11-25 10:00:00+01');
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003e1', '00000000-0000-4000-b000-000000000019', 'Haushalt ORDER-F1-F3 (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003e1', '00000000-0000-4000-a000-0000000009e8');
insert into auth.users (id, aud, role, email) values
  (pg_temp.m1(), 'authenticated', 'authenticated', 'order-f1-f3-m1.fixture@navora.test'),
  (pg_temp.m2(), 'authenticated', 'authenticated', 'order-f1-f3-m2.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'nurse'), ('00000000-0000-4000-b000-000000000019', pg_temp.m2(), 'nurse');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.t1(), 'ORDER-F1-F3 Fixture T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', pg_temp.t2(), 'ORDER-F1-F3 Fixture T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values (pg_temp.t1(), '4102');
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
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003e1'::uuid, d, time '08:00',
                                                         time '12:00', '4102', 'fage_efz', array['C1'], array['C1'], null,
                                                         key::uuid);
  reset role;
  perform pg_temp.as_owner();
end $$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;

-- F: the open order offered to T1 (template of the 1 000 copies); H: an order M1 takes (template of the released takes).
select pg_temp.confirm('f', date '2026-12-01', 'dddd0000-0000-4000-8180-000000000001');
select pg_temp.confirm('h', date '2026-12-02', 'dddd0000-0000-4000-8180-000000000002');
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
select is(pg_temp.take('h', 'ffff0000-0000-4000-8180-000000000001') ->> 'result', 'ok', 'M1 takes order H before its start');

-- Config A: 1 000 future copies of F, each offered to T1 in F's round (as a team collects offers over weeks).
create temp table ft as select * from public.partner_requests where id = pg_temp.oid('f');
insert into public.partner_requests
select (jsonb_populate_record(b, jsonb_build_object('id', pg_temp.fo(i),
          'starts_at', b.starts_at + make_interval(hours => i), 'ends_at', b.ends_at + make_interval(hours => i)))).*
from ft b, generate_series(1, 1000) i;
create temp table ot as select * from public.order_offers where order_id = pg_temp.oid('f') and team_id = pg_temp.t1();
insert into public.order_offers
select (jsonb_populate_record(o, jsonb_build_object('id', gen_random_uuid(), 'order_id', pg_temp.fo(i)))).*
from ot o, generate_series(1, 1000) i;

select pg_temp.clock('2026-11-30 10:00:00+01');
select cmp_ok(pg_temp.offers('a', pg_temp.m1()), '>=', 1002,
              'size: M1 reads at least 1 002 rows (F, its 1 000 copies, her taken order H)');

-- Config B: the platform grows around T1 without touching T1's offers --------------------------------------------------------
-- (i) T2 is offered the same 1 001 orders in the same round (another team's rows).
insert into public.order_offers
select (jsonb_populate_record(o, jsonb_build_object('id', gen_random_uuid(), 'team_id', pg_temp.t2()))).*
from public.order_offers o where o.team_id = pg_temp.t1() and (o.order_id = pg_temp.oid('f') or o.order_id in
      (select pg_temp.fo(i) from generate_series(1, 1000) i));
-- (ii) 1 000 ended orders (copies of F weeks back), offered to T1 and T2.
insert into public.partner_requests
select (jsonb_populate_record(b, jsonb_build_object('id', pg_temp.po(i),
          'starts_at', b.starts_at - make_interval(days => 30, hours => i), 'ends_at', b.ends_at - make_interval(days => 30, hours => i)))).*
from ft b, generate_series(1, 1000) i;
insert into public.order_offers
select (jsonb_populate_record(o, jsonb_build_object('id', gen_random_uuid(), 'order_id', pg_temp.po(i), 'team_id', t.id))).*
from ot o, generate_series(1, 1000) i, (values (pg_temp.t1()), (pg_temp.t2())) t(id);
-- (iii) 1 000 released takes of T2 (M2) on the ended orders: the platform's release history.
create temp table kt as select * from public.order_takes where order_id = pg_temp.oid('h') and released_at is null;
insert into public.order_takes
select (jsonb_populate_record(k, jsonb_build_object('id', gen_random_uuid(), 'order_id', pg_temp.po(i), 'team_id', pg_temp.t2(),
          'member_id', pg_temp.m2(), 'taken_by', pg_temp.m2(), 'released_at', '2026-10-20 10:00:00+02',
          'release_reason', 'step_1'))).*
from kt k, generate_series(1, 1000) i;

select is(pg_temp.offers('b', pg_temp.m1()), (select count(*)::int from seen where k = 'a'),
          'the grown platform adds no row for M1');
select is((select array_agg(order_id || '/' || team_id || '/' || offer_state order by ord) from seen where k = 'b'),
          (select array_agg(order_id || '/' || team_id || '/' || offer_state order by ord) from seen where k = 'a'),
          'M1 reads the same rows in the same order (order A)');

-- Diagnostic per helper: calls and self time in A and B (not asserted; the numbers for the fix).
select diag(format('ORDER-F1-F3 %s: A %s calls %s ms self | B %s calls %s ms self', h.f,
                   pg_temp.used('a', h.f), round((select b.self_ms - a.self_ms from stat a, stat b
                                                 where a.k = 'a0' and b.k = 'a1' and a.f = h.f and b.f = h.f)::numeric, 1),
                   pg_temp.used('b', h.f), round((select b.self_ms - a.self_ms from stat a, stat b
                                                 where a.k = 'b0' and b.k = 'b1' and a.f = h.f and b.f = h.f)::numeric, 1)))
from helper h order by h.f;

-- (2) Budget: one call for M1 costs the same number of helper calls on the grown platform. ----------------------------------
select is(pg_temp.used('b', 'is_team_member'), pg_temp.used('a', 'is_team_member'),
          'ORDER-F1-F3: is_team_member calls do not grow with other teams'' offers, ended orders or released takes');
select is(pg_temp.used('b', 'access_ended'), pg_temp.used('a', 'access_ended'),
          'ORDER-F1-F3: access_ended (LEAVE1-3) calls do not grow with the platform');
select is(pg_temp.used('b', 'order_round'), pg_temp.used('a', 'order_round'),
          'ORDER-F1-F3: order_round calls do not grow with the platform');
select is(pg_temp.used('b', 'now'), pg_temp.used('a', 'now'),
          'ORDER-F1-F3: private.now() calls do not grow with the platform');
select is(pg_temp.used('b', 'order_latest_cover_at'), pg_temp.used('a', 'order_latest_cover_at'),
          'ORDER-F1-F3: order_latest_cover_at calls do not grow with the platform');
select is(pg_temp.used('b', 'order_member_step'), pg_temp.used('a', 'order_member_step'),
          'ORDER-F1-F3: order_member_step calls do not grow with the platform');
select is(pg_temp.used('b', 'order_offer_reasons'), pg_temp.used('a', 'order_offer_reasons'),
          'ORDER-F1-F3: order_offer_reasons calls do not grow with the platform');
select cmp_ok(pg_temp.used('a', 'order_member_step'), '>', 0::bigint,
              'positive control: the call counts measure (order_member_step ran for M1''s rows)');

-- (3) Guards kept --------------------------------------------------------------------------------------------------------------
select pg_temp.offers('m2', pg_temp.m2());
select is((select count(*)::int from seen where k = 'm2' and team_id is distinct from pg_temp.t2()), 0,
          'permission: M2 reads rows of her own team T2 only');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'ended', 'employment_ended', '00000000-0000-4000-a000-0000000009e8');
select is(pg_temp.offers('ended', pg_temp.m1()), 0, 'LEAVE1-3: after her access ended, M1 reads no offer row');

select * from finish();
rollback;
