-- BK-c (brief `docs/agents/briefs/BK.md`, PO amendment 2026-11-17 13:39 (2): CGR-235 (b) is a BK-c acceptance
-- criterion; `cra` CLINICAL_GOVERNANCE 13:28, CGR-235 (b); answers PO 10:39 (3)(b)). pgTAP 141 §10 and 143 pin the
-- immediate `order_not_covered` path for SELF-named takes; pgTAP 144 §6, §7 pin it for an UNACKNOWLEDGED colleague take
-- and for «Ich kann nicht». No test pinned it for an ACKNOWLEDGED take of a colleague that falls away through the
-- ADR-199 path (an absence record, CGR-235 (a)). `cra` names the two cases tested here:
--   1. M1 names M2, M2 acknowledges; an absence of M2 is recorded after `latest_cover_at` and before `starts_at`
--      → no live take, `not_covered`, `order_not_covered` at once (both teams are offered again, so the exception
--      comes from the coverage time, not from an empty round).
--   2. The same at `latest_cover_at` − 1 min with no team eligible → `not_covered / no_team_eligible`, exception at once.
-- Negative control in each case: before the absence the acknowledged take covers and raises no exception.
-- This pins behaviour the code already has (ADR-199 (5), ADR-200 (2)); it changes no code. It asserts no screen words:
-- the client detail after «Gedeckt» is CGR-235 (c), words owned by `uxa` and `lca` (OPEN). No clinical value is set;
-- the 240 min lead stays PROPOSED (K-8).
--
-- Users: kundebs …9e8 (client). Fixture: T1 (M1, M2), T2 (M3), postcode 4102, 10 km, all FaGe; no seed team of
-- Testorganisation S serves 4102 with a FaGe member (pgTAP 143 precondition, re-checked below). Pinned clock, moved
-- forward only. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(21);

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
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b145-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a145-0000000000' || n)::uuid $$;

-- Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003cb', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-c CGR-235 Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003cb', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b145-000000000001', 'BK-c CGR-235 T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b145-000000000002', 'BK-c CGR-235 T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b145-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a145-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-c-cgr235-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a145-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b145-000000000001', '00000000-0000-4000-a145-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b145-000000000001', '00000000-0000-4000-a145-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b145-000000000002', '00000000-0000-4000-a145-000000000003', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a145-0000000000' || n)::uuid, 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02', '03']) n;
-- O2's day: M1 and M3 are away, so after M2's absence no team passes (case 2).
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b145-000000000001', '00000000-0000-4000-a145-000000000001',
   timestamptz '2026-11-20 07:00:00+01', timestamptz '2026-11-20 13:00:00+01', '00000000-0000-4000-a145-000000000001'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b145-000000000002', '00000000-0000-4000-a145-000000000003',
   timestamptz '2026-11-20 07:00:00+01', timestamptz '2026-11-20 13:00:00+01', '00000000-0000-4000-a145-000000000003');

-- Orders (FaGe, C1, 08:00 – 12:00; latest coverage time 04:00 with the PROPOSED 240 min lead) -------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(k text, d date, key text) returns void language sql as $$
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003cb', d, time '08:00', time '12:00',
                                                         '4102', 'fage_efz', array['C1'], array['C1'], null, key::uuid)
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select pg_temp.co('o1', date '2026-11-19', 'dddd0000-0000-4000-8145-000000000001');  -- case 1: after latest_cover_at
select pg_temp.co('o2', date '2026-11-20', 'dddd0000-0000-4000-8145-000000000002');  -- case 2: −1 min, no team left
reset role;
select pg_temp.as_owner();
select is((select count(*)::int from made where r ->> 'result' = 'ok'), 2, 'the two fixture orders are confirmed');

-- Helpers ---------------------------------------------------------------------------------------------------------------
create function pg_temp.offered(k text, rnd int) returns uuid[] language sql as $$
  select coalesce(array_agg(o.team_id order by o.team_id), '{}') from public.order_offers o
  where o.order_id = pg_temp.oid(k) and o.round = rnd
$$;
create function pg_temp.take(actor text, k text, team text, member text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.take_order(pg_temp.oid(k), pg_temp.t(team), pg_temp.m(member), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.ack(actor text, k text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.acknowledge_take(pg_temp.oid(k), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.cs(k text) returns text language plpgsql as $$
declare res text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  select x.cover_state into res from public.client_orders() x where x.id = pg_temp.oid(k);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.ops(k text) returns text language sql as $$
  select c.cover_state || coalesce('/' || c.cover_detail, '') from private.order_cover(pg_temp.oid(k), private.now()) c
$$;
create function pg_temp.exc(k text) returns boolean language sql as $$
  select exists (select 1 from private.derived_exceptions('00000000-0000-4000-b000-000000000019') x
                 where x.exception_type = 'order_not_covered' and x.entity_id = pg_temp.oid(k))
$$;
create function pg_temp.live(k text) returns int language sql as $$
  select count(*)::int from public.order_takes t where t.order_id = pg_temp.oid(k) and t.released_at is null
$$;
-- M2 records her own absence (her path after «Bestätigen», CGR-235 (a)); the ADR-199 trigger releases the take.
create function pg_temp.absent_m2(d date) returns void language sql as $$
  insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
  values ('00000000-0000-4000-b000-000000000019', pg_temp.t('01'), pg_temp.m('02'),
          (d + time '07:00') at time zone 'Europe/Zurich', (d + time '13:00') at time zone 'Europe/Zurich', pg_temp.m('02'))
$$;

-- Precondition: round 1 offers only fixture teams (no seed team serves 4102 with a FaGe member) -----------------------
select is(pg_temp.offered('o1', 1), array[pg_temp.t('01'), pg_temp.t('02')], 'precondition: O1 round 1 offers exactly T1 and T2');
select is(pg_temp.offered('o2', 1), array[pg_temp.t('01')], 'precondition: O2 round 1 offers only T1 (through M2)');

-- 1. Acknowledged colleague take falls away AFTER latest_cover_at, before starts_at -----------------------------------
select is(pg_temp.take('01', 'o1', '01', '02', 'ffff0000-0000-4000-8145-000000000010') ->> 'result', 'ok', 'M1 takes O1 naming M2');
select is(pg_temp.ack('02', 'o1', 'ffff0000-0000-4000-8145-000000000011') ->> 'result', 'ok', 'M2 acknowledges O1');
select pg_temp.clock('2026-11-19 05:00:00+01');
select is(pg_temp.ops('o1'), 'covered', 'negative control: after the latest coverage time the acknowledged take still covers');
select ok(not pg_temp.exc('o1'), 'negative control: and raises no exception');
select pg_temp.absent_m2(date '2026-11-19');
select is(pg_temp.live('o1'), 0, 'CGR-235 (b): her absence after the latest coverage time releases the acknowledged take at once');
select is(pg_temp.offered('o1', 2), array[pg_temp.t('01'), pg_temp.t('02')],
          'the release path screens a new round (T1 through M1, T2 through M3), so the round is not empty');
select is(pg_temp.ops('o1'), 'not_covered/cover_time_reached',
          'CGR-235 (b): Operations reads «nicht gedeckt» because the latest coverage time has passed, not «nicht mehr gedeckt»');
select is(pg_temp.cs('o1'), 'not_covered', 'the client reads «nicht gedeckt» (state only; the detail words are CGR-235 (c), OPEN)');
select ok(pg_temp.exc('o1'), 'CGR-235 (b): order_not_covered is raised at once, before the start');
select is((select release_reason from public.order_takes t where t.order_id = pg_temp.oid('o1') order by t.taken_at desc, t.id desc limit 1),
          'step_3', 'the release goes the ADR-199 step path (absence = not available), not a person''s «Ich kann nicht»');

-- 2. The same at latest_cover_at − 1 min with no team eligible ----------------------------------------------------------
select pg_temp.clock('2026-11-16 12:00:00+01');
select is(pg_temp.take('01', 'o2', '01', '02', 'ffff0000-0000-4000-8145-000000000020') ->> 'result', 'ok', 'M1 (away that day) takes O2 naming M2');
select is(pg_temp.ack('02', 'o2', 'ffff0000-0000-4000-8145-000000000021') ->> 'result', 'ok', 'M2 acknowledges O2');
select pg_temp.clock('2026-11-20 03:59:00+01');
select is(pg_temp.ops('o2'), 'covered', 'negative control: one minute before the latest coverage time the acknowledged take covers');
select ok(not pg_temp.exc('o2'), 'negative control: and raises no exception');
select pg_temp.absent_m2(date '2026-11-20');
select is(pg_temp.live('o2'), 0, 'CGR-235 (b): her absence at 03:59 releases the acknowledged take at once');
select is(pg_temp.offered('o2', 2), '{}'::uuid[], 'the new round offers no team (M1 and M3 away)');
select is(pg_temp.ops('o2'), 'not_covered/no_team_eligible', 'CGR-235 (b): Operations reads «nicht gedeckt» / no_team_eligible at once');
select ok(pg_temp.exc('o2'), 'CGR-235 (b): order_not_covered is raised at once, one minute before the coverage time');

select * from finish();
rollback;
