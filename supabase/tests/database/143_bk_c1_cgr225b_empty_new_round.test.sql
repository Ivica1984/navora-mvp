-- BK-c1 (ADR-199 (6), (9); CGR-225 (b); PO 2026-11-17 05:39 (2), «also in #1342»): the third CGR-225 case. pgTAP 141
-- §11 covers «no team eligible at confirmation» and «every team declined»; no case reached an EMPTY NEW ROUND after a
-- release (`cra` CLINICAL_GOVERNANCE, PS-194). Here a take is released because the named member stops passing, the new
-- round screens every team, and none passes: the order must read `not_covered / no_team_eligible` at once and raise the
-- `order_not_covered` exception at once, long before the latest coverage time (positive). Negative: a release whose
-- new round still offers a team reads `no_longer_covered` and raises no exception before the latest coverage time.
-- No clinical value is set here; the 240 min lead stays PROPOSED (K-8).
--
-- Users: kundebs …9e8 (client). Fixture: teams …b143-…01 (M1) and …b143-…02 (M2), postcode 4102, 10 km; no seed team
-- of Testorganisation S serves 4102 with a FaGe member (pgTAP 141 §11 `all_declined` relies on the same fact; checked
-- here as a precondition). Pinned clock Mon 2026-11-16 12:00 Europe/Zurich. Synthetic data only; rolled back.
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
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b143-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a143-0000000000' || n)::uuid $$;

-- Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003c8', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-c1 Leerrunde-Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003c8', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b143-000000000001', 'BK-c1 Leerrunde T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b143-000000000002', 'BK-c1 Leerrunde T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b143-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a143-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-c1-e' || n || '.fixture@navora.test'
  from unnest(array['01', '02']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a143-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b143-000000000001', '00000000-0000-4000-a143-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b143-000000000002', '00000000-0000-4000-a143-000000000002', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a143-0000000000' || n)::uuid, 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02']) n;

-- One FaGe day order, Thu 2026-11-19 08:00 – 12:00, confirmed by the client (latest coverage time 04:00, PROPOSED lead).
create temp table made (r jsonb);
grant all on made to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
insert into made select public.confirm_client_order('00000000-0000-4000-a000-0000000003c8', date '2026-11-19', time '08:00',
  time '12:00', '4102', 'fage_efz', array['C1'], array['C1'], null, 'dddd0000-0000-4000-8143-000000000001');
reset role;
create function pg_temp.o() returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made $$;
select is((select r ->> 'result' from made), 'ok', 'the fixture order is confirmed');

create function pg_temp.take(actor text, team text, member text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(actor);
  set local role authenticated;
  res := public.take_order(pg_temp.o(), pg_temp.t(team), pg_temp.m(member), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.cs() returns text language plpgsql as $$
declare res text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  select x.cover_state || coalesce('/' || x.cover_detail, '') into res from public.client_orders() x where x.id = pg_temp.o();
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.exc() returns boolean language sql as $$
  select exists (select 1 from private.derived_exceptions('00000000-0000-4000-b000-000000000019') x
                 where x.exception_type = 'order_not_covered' and x.entity_id = pg_temp.o())
$$;
create function pg_temp.offers(rnd int) returns int language sql as $$
  select count(*)::int from public.order_offers f where f.order_id = pg_temp.o() and f.round = rnd
$$;
create function pg_temp.absent(member text) returns void language sql as $$
  insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
  select '00000000-0000-4000-b000-000000000019', tm.team_id, tm.user_id,
         timestamptz '2026-11-19 07:00:00+01', timestamptz '2026-11-19 13:00:00+01', tm.user_id
  from public.team_memberships tm where tm.user_id = pg_temp.m(member) and tm.team_id::text like '00000000-0000-4000-b143-%';
$$;

-- Precondition: round 1 offers exactly the two fixture teams (no other team of the organisation serves 4102).
select is(pg_temp.offers(1), 2, 'precondition: round 1 offers exactly the two fixture teams');

-- 1. Negative: a release whose new round still offers a team ------------------------------------------------------------
select is(pg_temp.take(pg_temp.m('01')::text, '01', '01', 'ffff0000-0000-4000-8143-000000000001') ->> 'result', 'ok',
          'T1 takes the order with M1');
select is(pg_temp.cs(), 'covered', 'the take covers the order');
select pg_temp.absent('01');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.o() and released_at is null), 0,
          'an absence of M1 overlapping the slot releases the take');
select is(pg_temp.offers(2), 1, 'round 2 still offers one team (T2 with M2)');
select is(pg_temp.cs(), 'no_longer_covered', 'negative: a new round with a team left reads «nicht mehr gedeckt»');
select ok(not pg_temp.exc(), 'negative: and raises no exception before the latest coverage time');

-- 2. Positive (CGR-225 (b)): a release whose new round has no eligible team -------------------------------------------
select is(pg_temp.take(pg_temp.m('02')::text, '02', '02', 'ffff0000-0000-4000-8143-000000000002') ->> 'result', 'ok',
          'round 2: T2 takes the order with M2');
select pg_temp.absent('02');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.o() and released_at is null), 0,
          'an absence of M2 overlapping the slot releases the second take');
select is(pg_temp.offers(3), 0, 'round 3 screens every team again and none passes (both members absent)');
select is((select c.cover_state || '/' || c.cover_detail from private.order_cover(pg_temp.o(), private.now()) c),
          'not_covered/no_team_eligible',
          'CGR-225 (b): an empty new round after a release reads «nicht gedeckt» / no_team_eligible at once (Operations)');
select is(pg_temp.cs(), 'not_covered/no_team_free', 'F-1 (BK-c2): the client reads the one neutral zero state');
select ok(pg_temp.exc(), 'CGR-225 (b): and raises the order_not_covered exception at once (Mon 12:00, cover time Thu 04:00)');
select is((select count(*)::int from public.order_exclusions where order_id = pg_temp.o() and round = 3
           and team_id::text like '00000000-0000-4000-b143-%'), 2,
          'AUT-117: round 3 records an exclusion row for each fixture team');

select * from finish();
rollback;
