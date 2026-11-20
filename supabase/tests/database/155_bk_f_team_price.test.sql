-- BK-f, contract 2026-11-20 06:39 point 2 (a) (AUT-119 (b) first half; migration 0155): the team's own standing price.
-- Guards:
--   * a member of the team sets the price; another team's member, a client-only user and anon cannot (AUT-117 (a));
--   * invalid values are refused with a reason; the same value twice writes no second row; append-only (no update,
--     no delete); every change writes one audit row;
--   * «Übernehmen» copies the current price onto the take (snapshot); a later price change never changes the take;
--     the snapshot columns cannot be updated; a team without a price takes with an empty snapshot (no NAVORA default);
--   * a client-only user reads no team price row (G-6);
--   * no commission, percent or fee column (FE-078).
-- Fixture: organisation 019, T1 (M1), T2 (M2), client kundebs …9e8, postcode 4102. Synthetic data only; rolled back.
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
select pg_temp.clock('2026-11-16 12:00:00+01');
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b155-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a155-0000000000' || n)::uuid $$;

-- 0. Surface ---------------------------------------------------------------------------------------------------------
select has_table('public', 'team_prices', 'AUT-119 (b): the team price table exists');
select has_column('public', 'order_takes', 'price_per_hour_snapshot', 'the take carries a price snapshot');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name in ('team_prices')
             and column_name ~* '(commission|percent|fee|navora_|iban|payment|paid)'), 0,
  'FE-078: no commission, percent, fee or payment column on team_prices');

-- 1. Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a155-0000000003cb', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-f Preis Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a155-0000000003cb', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b155-000000000001', 'BK-f Preis T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b155-000000000002', 'BK-f Preis T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b155-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a155-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-f-price-' || n || '.fixture@navora.test'
  from unnest(array['01', '02']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a155-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b155-000000000001', '00000000-0000-4000-a155-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b155-000000000002', '00000000-0000-4000-a155-000000000002', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a155-0000000000' || n)::uuid, 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02']) n;

create function pg_temp.price(actor text, team text, p numeric, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(actor);
  set local role authenticated;
  res := public.set_team_price(pg_temp.t(team), p, key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;

-- 2. Who may set the price ---------------------------------------------------------------------------------------------
select is(pg_temp.price(pg_temp.m('01')::text, '01', 72.50, 'eeee0000-0000-4000-8155-000000000001') ->> 'result', 'ok',
  'AUT-117 (a): a member of T1 sets T1''s price');
select is(pg_temp.price(pg_temp.m('02')::text, '01', 10.00, 'eeee0000-0000-4000-8155-000000000002') ->> 'result', 'rejected',
  'a member of another team cannot set T1''s price');
select is(pg_temp.price('00000000-0000-4000-a000-0000000009e8', '01', 10.00, 'eeee0000-0000-4000-8155-000000000003') ->> 'result', 'rejected',
  'a client-only user cannot set a team price');
select throws_ok($$ set local role anon; select public.set_team_price('00000000-0000-4000-b155-000000000001', 1, gen_random_uuid()) $$,
  '42501', null, 'anon cannot call set_team_price');
reset role;
select is(pg_temp.price(pg_temp.m('01')::text, '01', 0, 'eeee0000-0000-4000-8155-000000000004') -> 'problems', '["price_not_valid"]'::jsonb,
  'a price of 0 is refused with a reason');
select is(pg_temp.price(pg_temp.m('01')::text, '01', 72.505, 'eeee0000-0000-4000-8155-000000000005') -> 'problems', '["price_not_valid"]'::jsonb,
  'a price with more than 2 decimals is refused');
select is(pg_temp.price(pg_temp.m('01')::text, '01', 72.50, 'eeee0000-0000-4000-8155-000000000006') ->> 'changed', 'false',
  'the same price again writes no second row');
select is((select count(*)::int from public.team_prices where team_id = pg_temp.t('01')), 1, 'one price row for T1');
select is((select count(*)::int from public.audit_events where entity_id = pg_temp.t('01') and changed ? 'price_per_hour'), 1,
  'the price change wrote one audit row');
select throws_ok($$ update public.team_prices set price_per_hour = 1 where team_id = '00000000-0000-4000-b155-000000000001' $$,
  '42501', 'team_prices is append-only', 'team_prices rows are never updated');
select throws_ok($$ delete from public.team_prices where team_id = '00000000-0000-4000-b155-000000000001' $$,
  '42501', 'team_prices is append-only', 'team_prices rows are never deleted');

-- 3. Snapshot at «Übernehmen» -------------------------------------------------------------------------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
insert into made select 'o1', public.confirm_client_order('00000000-0000-4000-a155-0000000003cb', date '2026-11-19', time '08:00',
  time '12:00', '4102', 'fage_efz', array['C1'], array['C1'], null, 'dddd0000-0000-4000-8155-000000000001'::uuid);
insert into made select 'o2', public.confirm_client_order('00000000-0000-4000-a155-0000000003cb', date '2026-11-20', time '08:00',
  time '12:00', '4102', 'fage_efz', array['C1'], array['C1'], null, 'dddd0000-0000-4000-8155-000000000002'::uuid);
reset role;
select pg_temp.as_owner();
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
create function pg_temp.take(actor text, k text, team text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.take_order(pg_temp.oid(k), pg_temp.t(team), pg_temp.m(actor), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;

select is(pg_temp.take('01', 'o1', '01', 'eeee0000-0000-4000-8155-000000000011') ->> 'result', 'ok', 'T1 takes o1');
select is((select price_per_hour_snapshot from public.order_takes where order_id = pg_temp.oid('o1') and released_at is null),
  72.50::numeric(8,2), 'the take carries T1''s price at the moment of the take');
select is(pg_temp.price(pg_temp.m('01')::text, '01', 80.00, 'eeee0000-0000-4000-8155-000000000007') ->> 'changed', 'true',
  'T1 changes its price later');
select is((select price_per_hour_snapshot from public.order_takes where order_id = pg_temp.oid('o1') and released_at is null),
  72.50::numeric(8,2), 'a later price change never changes the taken shift');
select throws_ok(format($$ update public.order_takes set price_per_hour_snapshot = 1 where order_id = %L $$, pg_temp.oid('o1')),
  '42501', 'the take price snapshot is never updated', 'the snapshot cannot be updated');
select is(pg_temp.take('02', 'o2', '02', 'eeee0000-0000-4000-8155-000000000012') ->> 'result', 'ok', 'T2 (no price) takes o2');
select ok((select price_per_hour_snapshot is null and price_id is null from public.order_takes
           where order_id = pg_temp.oid('o2') and released_at is null),
  'no NAVORA default: a team without a price takes with an empty snapshot');

-- 4. G-6: a client-only user reads no team price ------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select is((select count(*)::int from public.team_prices), 0, 'G-6: a client-only user reads no team price row');
reset role;
select pg_temp.as_owner();

select * from finish();
rollback;
