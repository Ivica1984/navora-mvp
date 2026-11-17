-- BK-c1 (brief `docs/agents/briefs/BK.md`, slice BK-c, PO acceptance 2026-11-17 02:39 «Consequence»; ADR-199): the
-- broadcast take, the decline, the team's offer list, the client's cover state, the Operations exception and the
-- re-coverage when the named member stops passing. Database part only; ranking (BK-3), the offer card words (BK-4) and
-- the screens are BK-c2 / BK-c3 (ADR-199 (8)).
--
-- Red first (FE-071 (2), task rule 3): pushed alone as the first commit of the BK-c1 PR, on `recovery/main` `14f0f91`.
-- There it fails: `public.take_order`, `public.decline_order`, `public.team_order_offers`, `public.order_takes`,
-- `public.order_declines`, the `round` column and `private.screen_unscreened_orders` do not exist, and
-- `public.client_orders()` returns the constant `not_covered`. The BK-c1 migration turns it green.
--
-- What it guards (each line names its source in the brief):
--   * FE-078 part 2 / PO 15:00 (1): every team that passes every hard check sees the order at the same time; a decline
--     drops only that team; the others keep seeing it.
--   * `eng` V-8 / `aia` AUT-128 (PO 20:40 (2)): the teams that see an order in the team view are exactly its
--     `order_offers` rows of the current round; a team without a row never sees it.
--   * BK-5a / PO 15:00 (2) / CGR-211: the first take that passes the fresh hard re-check wins; a second take is refused
--     with `already_taken` and writes nothing; an idempotent repeat returns `duplicate`.
--   * BK-5n / FE-039: only an active member of the team takes for it, naming a member of that team; Operations cannot.
--   * CGR-204 (b) / AUT-130 / CGR-224: the re-check at the take runs through `private.order_member_step`; a live take of
--     the same person on an overlapping order is one more availability source (step 3); the own order does not count;
--     a take that ends exactly at the start does not overlap.
--   * H-BK-15:39 (i), (ii): a taken order leaves the other teams' lists only once the take is committed; after a
--     release it returns to every team that passes the fresh screening.
--   * CGR-223 (a)-(c): the named member stops passing before the start (absence overlapping the slot; grade evidence
--     no longer valid at the slot end) → the take is released, the client sees `no_longer_covered`, a new round
--     screens every team again; the team may take again with another member who passes.
--   * BK-6 / CGR-222 (c) / CGR-225: pinned clock; one minute before the latest coverage time `open` without an
--     exception; at it `not_covered` with the exception, and that time is before `starts_at`; a short-notice order and
--     an order no team passes raise both at once; every team declined → `not_covered` with the exception.
--   * CGR-215 (b): an order confirmed without screening rows is screened by the backfill (idempotent).
--   * CGR-215 (c): order exceptions are listed by time to start.
--   * `lca` D-44 (2) (a) (PO 20:40 (3)): the client read model has no team count; the team view has no other team.
-- Not here (PLANNED in ADR-199): the two-session race script (`scripts/db-concurrency/order-take.sh`, BK-c1 second
-- commit); ranking and reasons (BK-c3); words (`uxa`). The coverage-lead value (4 h) is a simulation default, PROPOSED,
-- with the Clinical Owner before real data (K-8); passing this file is no clinical release.
--
-- Users: kundebs …9e8 (here member of the fixture household …3c4 of org S), opsbs …9e5 (operations of org S).
-- Fixture: teams …b141-…01 to …04 of Testorganisation S, service postcode 4102, maximum 10 km; members …a141-…01 to
-- …05. Seed team «Testteam Basel» has no FaGe and is excluded from every FaGe order here. Pinned clock: Mon 2026-11-16
-- 12:00 Europe/Zurich. Synthetic data only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(74);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);

-- 0. The new surface (non-aborting checks first) --------------------------------------------------------------------
select has_function('public', 'take_order', array['uuid', 'uuid', 'uuid', 'uuid'], 'BK-5a: public.take_order exists');
select has_function('public', 'decline_order', array['uuid', 'uuid', 'uuid'], 'FE-078 (1): public.decline_order exists');
select has_function('public', 'team_order_offers', array[]::text[], 'V-8: public.team_order_offers exists');
select has_table('public', 'order_takes', 'BK-5a: public.order_takes exists');
select has_table('public', 'order_declines', 'FE-078 (1): public.order_declines exists');
select has_column('public', 'order_offers', 'round', 'CGR-223: offer rows carry the screening round');
select has_column('public', 'order_exclusions', 'round', 'CGR-223: exclusion rows carry the screening round');
create function pg_temp.out_cols(fn text) returns setof text language sql as $$
  select n from pg_proc p, unnest(p.proargnames, p.proargmodes) as a(n, m)
  where p.oid = fn::regprocedure and a.m = 't'
$$;
select is((select count(*)::int from pg_temp.out_cols('public.client_orders()') c
           where c ~* '(^|_)(count|counts|anzahl|teams|n_teams|ranks?)(_|$)'), 0,
          'D-44 (2) (a): the client read model returns no team count');
select ok(pg_get_function_result('public.client_orders()'::regprocedure) ~ 'cover_detail',
          'BK-6: the client read model says why an order is not covered (cover_detail)');

-- 1. Fixture (synthetic), written as the table owner (0120 evidence guard) --------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003c4', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-c Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003c4', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b141-000000000001', 'BK-c Fixture T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b141-000000000002', 'BK-c Fixture T2', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b141-000000000003', 'BK-c Fixture T3', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b141-000000000004', 'BK-c Fixture T4 nur AGS', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b141-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a141-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-c1-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03', '04', '05']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a141-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03', '04', '05']) n;
-- M1, M4 → T1 · M2 → T2 · M3 → T3 · M5 → T4
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b141-000000000001', '00000000-0000-4000-a141-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b141-000000000001', '00000000-0000-4000-a141-000000000004', 'care_assistant'),
  ('00000000-0000-4000-b141-000000000002', '00000000-0000-4000-a141-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b141-000000000003', '00000000-0000-4000-a141-000000000003', 'care_assistant'),
  ('00000000-0000-4000-b141-000000000004', '00000000-0000-4000-a141-000000000005', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a141-000000000001', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a141-000000000002', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a141-000000000003', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a141-000000000004', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a141-000000000005', 'grade', 'ags_eba', 'verified', true, null);

-- 2. Orders (FaGe, C1 «E», required) ----------------------------------------------------------------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(k text, d date, s time, e time, pc text, key text) returns void language sql as $$
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003c4', d, s, e, pc, 'fage_efz',
                                                         array['C1'], array['C1'], null, key::uuid)
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b141-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a141-0000000000' || n)::uuid $$;

select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
-- O1 night Sun 22.11. 22:00 – Mon 07:00 · O2 overlaps O1 (Mon 01:00–05:00) · O3 starts exactly at O1's end
-- O4 Liestal 4410 (no team within reach) · O5 short notice (today 14:00, inside the 4 h lead) · O6 Fri 20.11. 10:00
-- O7 Wed 25.11. 08:00 (every team declines)
select pg_temp.co('o1', date '2026-11-22', time '22:00', time '07:00', '4102', 'dddd0000-0000-4000-8141-000000000001');
select pg_temp.co('o2', date '2026-11-23', time '01:00', time '05:00', '4102', 'dddd0000-0000-4000-8141-000000000002');
select pg_temp.co('o3', date '2026-11-23', time '07:00', time '12:00', '4102', 'dddd0000-0000-4000-8141-000000000003');
select pg_temp.co('o4', date '2026-11-18', time '08:00', time '12:00', '4410', 'dddd0000-0000-4000-8141-000000000004');
select pg_temp.co('o5', date '2026-11-16', time '14:00', time '18:00', '4102', 'dddd0000-0000-4000-8141-000000000005');
select pg_temp.co('o6', date '2026-11-20', time '10:00', time '14:00', '4102', 'dddd0000-0000-4000-8141-000000000006');
select pg_temp.co('o7', date '2026-11-25', time '08:00', time '12:00', '4102', 'dddd0000-0000-4000-8141-000000000007');
reset role;
select is((select count(*)::int from made where r ->> 'result' = 'ok'), 7, 'the seven fixture orders are confirmed');

create function pg_temp.offered(k text, rnd int) returns uuid[] language sql as $$
  select coalesce(array_agg(o.team_id order by o.team_id), '{}') from public.order_offers o
  where o.order_id = pg_temp.oid(k) and o.round = rnd and o.team_id::text like '00000000-0000-4000-b141-%'
$$;
select is(pg_temp.offered('o1', 1), array[pg_temp.t('01'), pg_temp.t('02'), pg_temp.t('03')],
          'FE-078 (1): the three passing teams get an offer row in round 1; T4 (AGS only) does not');
select is((select count(*)::int from public.order_offers where order_id = pg_temp.oid('o4')), 0,
          'zero state: no team reaches 4410');

-- 3. Team view equals offer rows (V-8, AUT-128) -----------------------------------------------------------------------
create function pg_temp.sees(member text, k text) returns uuid[] language plpgsql as $$
declare res uuid[];
begin
  perform pg_temp.act_as(pg_temp.m(member)::text);
  set local role authenticated;
  select coalesce(array_agg(x.team_id order by x.team_id), '{}') into res
  from public.team_order_offers() x where x.order_id = pg_temp.oid(k);
  reset role;
  return res;
end;
$$;
select is(pg_temp.sees('01', 'o1'), array[pg_temp.t('01')], 'V-8: a member of T1 sees O1 for her own team');
select is(pg_temp.sees('02', 'o1'), array[pg_temp.t('02')], 'V-8: a member of T2 sees O1 for her own team');
select is(pg_temp.sees('03', 'o1'), array[pg_temp.t('03')], 'V-8: a member of T3 sees O1 for her own team');
select is(pg_temp.sees('05', 'o1'), '{}'::uuid[], 'V-8 negative: a member of T4 (no offer row) never sees O1');
select is((select count(*)::int from pg_temp.out_cols('public.team_order_offers()') c
           where c ~* '(^|_)(count|counts|anzahl|teams|other|ranks?|position)(_|$)'), 0,
          'template §2: the team view carries no count, no other team and no ranking position');

-- 4. Client before any take ------------------------------------------------------------------------------------------
create function pg_temp.cs(k text) returns text language plpgsql as $$
declare res text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  select x.cover_state || coalesce('/' || x.cover_detail, '') into res from public.client_orders() x where x.id = pg_temp.oid(k);
  reset role;
  return res;
end;
$$;
create function pg_temp.exc(k text) returns boolean language sql as $$
  select exists (select 1 from private.derived_exceptions('00000000-0000-4000-b000-000000000019') x
                 where x.exception_type = 'order_not_covered' and x.entity_id = pg_temp.oid(k))
$$;
select is(pg_temp.cs('o1'), 'open', 'BK-6: O1 before any take and before the coverage time is «open» (noch nicht gedeckt)');
select ok(not pg_temp.exc('o1'), 'BK-6: no exception for O1 six days before the start');

-- 5. Decline (FE-078 (1)) --------------------------------------------------------------------------------------------
select pg_temp.act_as(pg_temp.m('03')::text);
set local role authenticated;
select is(public.decline_order(pg_temp.oid('o1'), pg_temp.t('03'), 'eeee0000-0000-4000-8141-000000000001') ->> 'result', 'ok',
          'FE-078 (1): a member of T3 declines O1 for her team');
reset role;
select is(pg_temp.sees('03', 'o1'), '{}'::uuid[], 'a declined offer leaves the declining team''s list');
select is(pg_temp.sees('02', 'o1'), array[pg_temp.t('02')], 'FE-078 (1): the other teams keep seeing it');
select is(pg_temp.cs('o1'), 'open', 'one decline leaves the order open');

-- 6. Refused takes write nothing (BK-5n, CGR-204 (b)) ------------------------------------------------------------------
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b141-000000000001', '00000000-0000-4000-a141-000000000004',
   timestamptz '2026-11-22 20:00:00+01', timestamptz '2026-11-23 09:00:00+01', '00000000-0000-4000-a141-000000000004');
create function pg_temp.take(actor text, k text, team text, member text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(actor);
  set local role authenticated;
  res := public.take_order(pg_temp.oid(k), pg_temp.t(team), pg_temp.m(member), key::uuid);
  reset role;
  return res;
end;
$$;
select is(pg_temp.take(pg_temp.m('05')::text, 'o1', '04', '05', 'ffff0000-0000-4000-8141-000000000001') ->> 'reason', 'not_offered',
          'BK-2n: a team without an offer row cannot take');
select is(pg_temp.take(pg_temp.m('02')::text, 'o1', '01', '02', 'ffff0000-0000-4000-8141-000000000002') ->> 'reason', 'not_team_member',
          'BK-5n / FE-039: nobody takes for another team');
select is(pg_temp.take(pg_temp.m('01')::text, 'o1', '01', '02', 'ffff0000-0000-4000-8141-000000000003') ->> 'reason', 'member_not_in_team',
          'BK-5n: the named person must be a member of the taking team');
select is(pg_temp.take('00000000-0000-4000-a000-0000000009e5', 'o1', '01', '01', 'ffff0000-0000-4000-8141-000000000004') ->> 'reason', 'not_team_member',
          'FE-039: Operations cannot take for a team');
select is(pg_temp.take(pg_temp.m('03')::text, 'o1', '03', '03', 'ffff0000-0000-4000-8141-000000000005') ->> 'reason', 'not_offered',
          'a team that declined cannot take in the same round');
select is(pg_temp.take(pg_temp.m('01')::text, 'o1', '01', '04', 'ffff0000-0000-4000-8141-000000000006'),
          '{"result": "refused", "reason": "member_not_eligible", "step": 3}'::jsonb,
          'CGR-204 (b): the re-check at the take refuses a member who is away for part of the slot, with the step');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.oid('o1')), 0, 'refused takes write nothing');

-- 7. The first valid take wins (BK-5a, CGR-211) ------------------------------------------------------------------------
create temp table took (k text primary key, r jsonb);
grant all on took to authenticated;
insert into took select 'o1', pg_temp.take(pg_temp.m('01')::text, 'o1', '01', '01', 'ffff0000-0000-4000-8141-000000000010');
select is((select r ->> 'result' from took where k = 'o1'), 'ok', 'BK-5a: T1 takes O1 with M1');
select is(pg_temp.take(pg_temp.m('01')::text, 'o1', '01', '01', 'ffff0000-0000-4000-8141-000000000010') ->> 'result', 'duplicate',
          'an idempotent repeat returns duplicate');
select is(pg_temp.take(pg_temp.m('02')::text, 'o1', '02', '02', 'ffff0000-0000-4000-8141-000000000011') ->> 'reason', 'already_taken',
          'BK-5a: a later take by another team is refused with already_taken');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.oid('o1')), 1, 'CGR-211: exactly one take row');
select ok(exists (select 1 from public.audit_events a where a.table_name = 'order_takes'
                  and a.entity_id = (select (r ->> 'take_id')::uuid from took where k = 'o1')),
          'AUD1: the take has its audit row');

-- 8. After the take (H-BK-15:39 (i), lca G-3) ------------------------------------------------------------------------
select is(pg_temp.cs('o1'), 'covered', 'BK-5a: the client sees «gedeckt»');
create function pg_temp.cover_team(k text) returns text language plpgsql as $$
declare res text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  select x.covered_team_name into res from public.client_orders() x where x.id = pg_temp.oid(k);
  reset role;
  return res;
end;
$$;
create function pg_temp.offer_state(member text, k text) returns text language plpgsql as $$
declare res text;
begin
  perform pg_temp.act_as(pg_temp.m(member)::text);
  set local role authenticated;
  select x.offer_state into res from public.team_order_offers() x where x.order_id = pg_temp.oid(k);
  reset role;
  return res;
end;
$$;
select is(pg_temp.cover_team('o1'), 'BK-c Fixture T1', 'lca G-3: after the take the client sees the taking team''s name');
select is(pg_temp.sees('02', 'o1'), '{}'::uuid[], 'H-BK-15:39 (i): the committed take removes O1 from the other teams'' lists');
select is(pg_temp.offer_state('01', 'o1'), 'taken_by_us', 'the taking team sees the order as its own take');
select is(pg_temp.offer_state('02', 'o5'), 'open', 'an untaken offer reads open for a team that sees it');

-- 9. One person, two overlapping orders (CGR-224, AUT-130) --------------------------------------------------------------
select is(private.order_member_step(pg_temp.oid('o2'), pg_temp.t('01'), pg_temp.m('01')), 3,
          'AUT-130: a live take on an overlapping order is an availability source of order_member_step (step 3)');
select is(private.order_member_step(pg_temp.oid('o1'), pg_temp.t('01'), pg_temp.m('01')), 4,
          'AUT-130: the own take does not make its member unavailable for the same order');
select is(private.order_member_step(pg_temp.oid('o3'), pg_temp.t('01'), pg_temp.m('01')), 4,
          'CGR-224: a take ending exactly at the start does not overlap ([start, end))');
select is(pg_temp.take(pg_temp.m('01')::text, 'o2', '01', '01', 'ffff0000-0000-4000-8141-000000000020'),
          '{"result": "refused", "reason": "member_not_eligible", "step": 3}'::jsonb,
          'CGR-224: an overlapping second take of the same person is refused with the availability step');
select is(pg_temp.take(pg_temp.m('01')::text, 'o3', '01', '01', 'ffff0000-0000-4000-8141-000000000021') ->> 'result', 'ok',
          'CGR-224 positive: a non-overlapping second take of the same person passes');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.oid('o2')), 0, 'CGR-224: nothing stored for O2');

-- 10. The named member stops passing (CGR-223) --------------------------------------------------------------------------
select pg_temp.as_owner();
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b141-000000000001', '00000000-0000-4000-a141-000000000001',
   timestamptz '2026-11-23 03:00:00+01', timestamptz '2026-11-23 05:00:00+01', '00000000-0000-4000-a141-000000000001');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.oid('o1') and released_at is null), 0,
          'CGR-223 (a): an absence overlapping the slot releases the take');
select ok((select release_reason from public.order_takes where order_id = pg_temp.oid('o1')) is not null,
          'CGR-223: the release names a step code');
select is(pg_temp.cs('o1'), 'no_longer_covered', 'CGR-223 (b): the client sees «nicht mehr gedeckt» at once');
select is(pg_temp.offered('o1', 2), array[pg_temp.t('02'), pg_temp.t('03')],
          'CGR-223 (c): round 2 screens every team again; T3''s earlier decline does not carry over; T1 has nobody free');
select is((select reason from public.order_exclusions where order_id = pg_temp.oid('o1') and round = 2 and team_id = pg_temp.t('01')),
          'no_member_available', 'CGR-223 (c): T1 is excluded in round 2 with its step');
select is(pg_temp.offered('o1', 1), array[pg_temp.t('01'), pg_temp.t('02'), pg_temp.t('03')],
          'AUT-117 (b): round 1 rows are unchanged');
select is(pg_temp.sees('02', 'o1'), array[pg_temp.t('02')], 'H-BK-15:39 (ii): O1 is back in T2''s list');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.oid('o3') and released_at is null), 1,
          'the take of O3 (no overlap with the absence) stays');
-- grade evidence no longer verified for the slot (CGR-223 (a), second path). Evidence is append-only (QUAL1-2), so a
-- record cannot be shortened after the take (validity at the slot end is checked at the take); the reachable path is a
-- new record that makes the grade contradictory (`private.qual_evidence_state`, 0120).
select is(pg_temp.take(pg_temp.m('03')::text, 'o1', '03', '03', 'ffff0000-0000-4000-8141-000000000030') ->> 'result', 'ok',
          'round 2: T3 takes O1 with M3');
select pg_temp.as_owner();
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a141-000000000003', 'grade', 'ags_eba', 'verified', true, null);
select is(pg_temp.cs('o1'), 'no_longer_covered', 'CGR-223 (a): a grade that is no longer verified releases the take');
select is(pg_temp.offered('o1', 3), array[pg_temp.t('02')], 'CGR-223 (c): round 3 offers only the team that still passes');

-- 11. Short notice, zero state, every team declined (CGR-222 (c), CGR-225, BK-6) --------------------------------------
select is(pg_temp.cs('o5'), 'not_covered/cover_time_reached',
          'CGR-222 (c): an order confirmed inside the coverage lead is «nicht gedeckt» at once');
select ok(pg_temp.exc('o5'), 'CGR-222 (c): and raises the exception at once');
select ok(cardinality(pg_temp.offered('o5', 1)) > 0, 'CGR-222 (c): the offers still go out');
select is(pg_temp.cs('o4'), 'not_covered/no_team_eligible', 'CGR-225: no team passes at confirmation → «nicht gedeckt»');
select ok(pg_temp.exc('o4'), 'CGR-225: the exception is raised at once, not only at the coverage time');
select pg_temp.act_as(pg_temp.m('01')::text);
set local role authenticated;
select public.decline_order(pg_temp.oid('o7'), pg_temp.t('01'), 'eeee0000-0000-4000-8141-000000000071');
reset role;
select pg_temp.act_as(pg_temp.m('02')::text);
set local role authenticated;
select public.decline_order(pg_temp.oid('o7'), pg_temp.t('02'), 'eeee0000-0000-4000-8141-000000000072');
reset role;
select is(pg_temp.cs('o7'), 'open', 'two of three teams declined: still open');
select pg_temp.act_as(pg_temp.m('03')::text);
set local role authenticated;
select public.decline_order(pg_temp.oid('o7'), pg_temp.t('03'), 'eeee0000-0000-4000-8141-000000000073');
reset role;
select is(pg_temp.cs('o7'), 'not_covered/all_declined', 'BK-6: every eligible team declined → «nicht gedeckt»');
select ok(pg_temp.exc('o7'), 'BK-6: and the exception');

-- 12. Exceptions by time to start (CGR-215 (c)) -------------------------------------------------------------------------
create temp table ex_order (n bigint, entity_id uuid);
grant all on ex_order to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e5');
set local role authenticated;
insert into ex_order
  select x.ordinality, x.entity_id from public.operations_exceptions() with ordinality x
  where x.exception_type = 'order_not_covered';
reset role;
select is((select array_agg(e.entity_id order by e.n) from ex_order e where e.entity_id in (pg_temp.oid('o4'), pg_temp.oid('o5'), pg_temp.oid('o7'))),
          array[pg_temp.oid('o5'), pg_temp.oid('o4'), pg_temp.oid('o7')],
          'CGR-215 (c): Operations sees order exceptions ordered by time to start (O5 today, O4 Wed, O7 next Wed)');

-- 13. Client never reads takes or declines; no count (D-44 (2) (a)) -----------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select is((select count(*)::int from public.order_takes) + (select count(*)::int from public.order_declines), 0,
          'the client reads no take or decline row');
reset role;
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name = 'order_declines' and column_name ~ '(reason|why)'), 0,
          'template: a decline carries no reason (none is asked in BK)');

-- 14. Latest coverage time on a pinned clock (CGR-222 (c)) -------------------------------------------------------------
select set_config('navora.test_now', '2026-11-20 05:59:00+01', true);
select is(pg_temp.cs('o6'), 'open', 'CGR-222 (c): one minute before the latest coverage time: open');
select ok(not pg_temp.exc('o6'), 'CGR-222 (c): and no exception');
select set_config('navora.test_now', '2026-11-20 06:00:00+01', true);
select is(pg_temp.cs('o6'), 'not_covered/cover_time_reached', 'CGR-222 (c): at the latest coverage time: not covered');
select ok(pg_temp.exc('o6'), 'CGR-222 (c): with the exception');
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);

-- 15. Orders confirmed without screening rows (CGR-215 (b)) ------------------------------------------------------------
select pg_temp.as_owner();
insert into public.partner_requests
  (id, organization_id, partner_name, partner_type, region, city, urgency, urgency_source, request_title, need_summary,
   status, order_kind, client_account_id, starts_at, ends_at, postcode, grade, activity_tags, required_tags, shift_label,
   confirmed_at, confirmed_by)
values ('00000000-0000-4000-c141-000000000001', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-c Fixture (synthetisch)',
        'household', 'Basel-Landschaft', 'Binningen', null, 'unknown', 'Fixture vor BK-c', 'Fixture vor BK-c',
        'client_confirmed', 'shift', '00000000-0000-4000-a000-0000000003c4', timestamptz '2026-11-26 08:00:00+01',
        timestamptz '2026-11-26 12:00:00+01', '4102', 'fage_efz', array['C1'], array['C1'], null,
        timestamptz '2026-11-12 09:00:00+01', '00000000-0000-4000-a000-0000000009e8');
select private.screen_unscreened_orders();
select is((select array_agg(team_id order by team_id) from public.order_offers
           where order_id = '00000000-0000-4000-c141-000000000001' and team_id::text like '00000000-0000-4000-b141-%'),
          array[pg_temp.t('01'), pg_temp.t('02')],
          'CGR-215 (b): an order confirmed before BK-c is screened by the backfill (T3: M3''s grade is contradictory since §10)');
select private.screen_unscreened_orders();
select is((select count(*)::int from public.order_offers where order_id = '00000000-0000-4000-c141-000000000001'),
          (select count(*)::int from public.order_offers where order_id = '00000000-0000-4000-c141-000000000001' and round = 1),
          'CGR-215 (b): the backfill is idempotent (round 1 only, written once)');

select * from finish();
rollback;
