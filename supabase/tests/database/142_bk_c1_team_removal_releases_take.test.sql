-- BK-c1 (ADR-199 (5), PO 2026-11-17 03:39 point 4: «the list of every writer of the four availability sources»): the
-- writer list found one path that turns a passing member into a failing one WITHOUT touching the four trigger tables of
-- 0135: `public.remove_team_member` deletes the `team_memberships` row (0035 → 0036 → 0037 → 0065 patch) and writes no
-- `member_access_events` row, so `private.order_member_step` returns 0 for her take while the take stays live.
-- Consequences on the branch head `b6f4cb7` (reproduced here, red first):
--   (a) the take is not released, no new round is screened, and every other team gets `already_taken` until the start;
--   (b) the client sees `no_longer_covered` (the read-time safety net works), but that state never becomes
--       `not_covered`, so the `order_not_covered` exception is never raised for Operations, not even after the latest
--       coverage time (ADR-199 (9) says: raised for `no_longer_covered` at or after `latest_cover_at`).
-- The fix (same PR): a recheck trigger on `team_memberships` (delete, and update of team or user), and `order_cover`
-- treats a live take whose member no longer passes like a released one for the time-based states (cover time reached,
-- started), so any path the triggers miss (configuration tables written only by migrations: `qual_matrix_cells`,
-- `qual_activities`) still raises the exception. No clinical rule is set here; the 240 min lead stays PROPOSED (K-8).
--
-- Users: kundebs …9e8 (client), fixture admin …a142-…09 of Testorganisation S. Fixture: teams …b142-…01 (M1, M2) and
-- …b142-…02 (M3), postcode 4102, 10 km. Pinned clock Mon 2026-11-16 12:00 Europe/Zurich. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b142-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a142-0000000000' || n)::uuid $$;

-- Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003c6', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-c1 Writer-Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003c6', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b142-000000000001', 'BK-c1 Writer T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b142-000000000002', 'BK-c1 Writer T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b142-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a142-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-c1-w' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03', '09']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a142-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03']) n;
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a142-000000000009', 'admin');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b142-000000000001', '00000000-0000-4000-a142-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b142-000000000001', '00000000-0000-4000-a142-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b142-000000000002', '00000000-0000-4000-a142-000000000003', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a142-0000000000' || n)::uuid, 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02', '03']) n;

-- One FaGe night order, Thu 2026-11-19 22:00 – Fri 07:00, confirmed by the client.
create temp table made (r jsonb);
grant all on made to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
insert into made select public.confirm_client_order('00000000-0000-4000-a000-0000000003c6', date '2026-11-19', time '22:00',
  time '07:00', '4102', 'fage_efz', array['C1'], array['C1'], null, 'dddd0000-0000-4000-8142-000000000001');
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
create function pg_temp.live() returns int language sql as $$
  select count(*)::int from public.order_takes where order_id = pg_temp.o() and released_at is null
$$;
create function pg_temp.offered(rnd int) returns uuid[] language sql as $$
  select coalesce(array_agg(f.team_id order by f.team_id), '{}') from public.order_offers f
  where f.order_id = pg_temp.o() and f.round = rnd and f.team_id::text like '00000000-0000-4000-b142-%'
$$;

-- 1. Team removal of the named member releases her take (writer `remove_team_member`) --------------------------------
select is(pg_temp.take(pg_temp.m('01')::text, '01', '01', 'ffff0000-0000-4000-8142-000000000001') ->> 'result', 'ok',
          'T1 takes the order with M1');
select pg_temp.act_as('00000000-0000-4000-a142-000000000009');
set local role authenticated;
select is(public.remove_team_member(pg_temp.t('01'), pg_temp.m('01'), 'Teamwechsel (synthetisch)',
                                    'ffff0000-0000-4000-8142-000000000002') ->> 'result', 'ok',
          'the admin removes M1 from T1 (no access end, so no member_access_events row)');
reset role;
select pg_temp.as_owner();
select is(private.order_member_step(pg_temp.o(), pg_temp.t('01'), pg_temp.m('01')), 0,
          'after the removal M1 no longer passes for T1 (step 0)');
select is(pg_temp.live(), 0, 'ADR-199 (5): the team removal releases the take (writer list: remove_team_member)');
select is((select release_reason from public.order_takes where order_id = pg_temp.o()), 'step_0',
          'the release names the step code step_0, never a person''s data (P-5)');
select is(pg_temp.cs(), 'no_longer_covered', 'CGR-223 (b): the client sees «nicht mehr gedeckt»');
select is(pg_temp.offered(2), array[pg_temp.t('01'), pg_temp.t('02')],
          'CGR-223 (c): round 2 screens every team again; T1 still has M2 who passes');
select is(pg_temp.take(pg_temp.m('03')::text, '02', '03', 'ffff0000-0000-4000-8142-000000000003') ->> 'result', 'ok',
          'CGR-223 (c): another team can take the order again (no stuck already_taken)');
select is(pg_temp.cs(), 'covered', 'the new take covers the order');

-- 2. Safety net for a path no trigger sees (ADR-199 (5) and (9)) ------------------------------------------------------
-- A membership row removed with triggers off stands for any future or configuration-only path the triggers miss.
set local session_replication_role = replica;
delete from public.team_memberships where team_id = pg_temp.t('02') and user_id = pg_temp.m('03');
set local session_replication_role = origin;
select is(pg_temp.live(), 1, 'precondition: with triggers off the take of M3 stays live although M3 no longer passes');
select is(pg_temp.cs(), 'no_longer_covered', 'safety net: a live take whose member no longer passes is never «gedeckt»');
select ok(not pg_temp.exc(), 'before the latest coverage time: no exception yet (same rule as a released take)');
select set_config('navora.test_now', '2026-11-19 18:00:00+01', true);  -- starts_at − 240 min (PROPOSED lead)
select is(pg_temp.cs(), 'not_covered/cover_time_reached',
          'ADR-199 (9): at the latest coverage time a live take whose member no longer passes reads not_covered');
select ok(pg_temp.exc(), 'ADR-199 (9): and Operations gets the order_not_covered exception');
select set_config('navora.test_now', '2026-11-19 22:00:00+01', true);
select is(pg_temp.cs(), 'not_covered/started', 'at the start it reads not_covered / started');

select * from finish();
rollback;
