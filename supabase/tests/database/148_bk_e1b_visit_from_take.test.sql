-- BK-e1b database part (brief `docs/agents/briefs/BK.md`, PO amendments 2026-11-18 02:39 criteria 2–4, 03:39 (3);
-- ADR-202 (2)–(4), ADR-203). Red first (FE-071 (2)): pushed alone, before the migration, where `care_visits` has no
-- `order_take_id`, no visit is written from a take, and `private.order_take_visit` does not exist.
--
-- What it guards (each line names its source):
--   * BK-7 / criterion 2: when a take becomes «gedeckt» (self-named: at the take; naming a colleague: at her
--     acknowledgement, ADR-200) one visit is written in the same transaction: named member responsible, the take's
--     team, date and times from `starts_at` / `ends_at` in Europe/Zurich, place from the order. A take awaiting the
--     acknowledgement writes none. Only the named member reads it on `/field`; a member of the same team who is not
--     named, and a member of another team, never do.
--   * CGR-232 / criterion 3: writing the visit does not release the take of the person who is coming (the visit of
--     the take is not an «open visit» of another order in `private.order_member_step` step 3).
--   * CGR-233 / criterion 3: the visit writer takes the `order_take_member:` lock before it writes (source check here;
--     the two-session race case is `scripts/concurrency-take-visit.mjs`).
--   * CGR-242 (PO 03:39 (3)): positive — a release after «gedeckt» and before the start ends the visit in the same
--     transaction as `cancelled`, never deleted, and the client no longer reads «gedeckt»; negative — after
--     `starts_at` no automatic step releases the take or changes the visit. No lead-time rule is built (UNKNOWN,
--     Clinical Owner).
--   * CGR-200 / CGR-206 (a) / criterion 4: a 22:00–07:00 take becomes one visit of 9 h (Europe/Zurich).
--   * CGR-242 (a), (c) (PO 04:39; migration 0139): the ended visit carries the stored system reason, writes no
--     «cancelled» timeline event and no status note (never counted as a cancellation), and /field returns the reason
--     to the named member only.
--   * CGR-242 (f): «Ich kann nicht» before the start on a take awaiting the acknowledgement writes and ends nothing.
--   * CGR-244 (PO 04:39): a take whose visit is under way before the start (F1 «unterwegs») is never released: her
--     absence keeps the take and the visit (the client view follows the unchanged ADR-199 (5) safety net: not
--     «gedeckt»); «Ich kann nicht» is refused with the visible reason `visit_under_way`.
-- Not here: the `/field` card (Playwright, same slice), the clock-change night (BK-g), the door address (ADR-202 (7),
-- OPEN). Synthetic data only; rolled back.
--
-- Users: kundebs …9e8 (client). Fixture: T1 (M1, M2), T2 (M3), postcode 4102, 10 km, all FaGe. Pinned clock, moved
-- forward only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(69);

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
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b148-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a148-0000000000' || n)::uuid $$;

-- 0. The new surface (non-aborting checks first) --------------------------------------------------------------------
select has_column('public', 'care_visits', 'order_take_id', 'ADR-202 (2): a visit can name the take it was written from');
select ok(exists (select 1 from pg_indexes i where i.schemaname = 'public' and i.tablename = 'care_visits'
                  and i.indexdef ilike '%unique%' and i.indexdef ilike '%(order_take_id)%'),
          'ADR-202 (2): at most one visit per take (unique index)');
select has_column('public', 'care_visits', 'system_end_reason', 'CGR-242 (a): a visit can carry a stored system end reason');
select has_function('private', 'order_take_visit', 'ADR-203: the one visit writer from a take exists');
select ok(coalesce(position('order_take_member:' in
            (select string_agg(p.prosrc, ' ') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'private' and p.proname = 'order_take_visit')), 0) > 0,
          'CGR-233: the visit writer takes the same order_take_member: lock as the take');

-- 1. Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003cb', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-e1b Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003cb', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b148-000000000001', 'BK-e1b Fixture T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b148-000000000002', 'BK-e1b Fixture T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b148-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a148-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-e1b-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a148-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b148-000000000001', '00000000-0000-4000-a148-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b148-000000000001', '00000000-0000-4000-a148-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b148-000000000002', '00000000-0000-4000-a148-000000000003', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a148-0000000000' || n)::uuid, 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02', '03']) n;

-- 2. Orders (FaGe, C1) ----------------------------------------------------------------------------------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(k text, d date, s time, e time, key text) returns void language sql as $$
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003cb', d, s, e,
                                                         '4102', 'fage_efz', array['C1'], array['C1'], null, key::uuid)
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select pg_temp.co('o1', date '2026-11-19', time '08:00', time '12:00', 'dddd0000-0000-4000-8148-000000000001');  -- self-named
select pg_temp.co('o2', date '2026-11-20', time '08:00', time '12:00', 'dddd0000-0000-4000-8148-000000000002');  -- colleague, ack
select pg_temp.co('o3', date '2026-11-21', time '22:00', time '07:00', 'dddd0000-0000-4000-8148-000000000003');  -- overnight
select pg_temp.co('o4', date '2026-11-23', time '08:00', time '12:00', 'dddd0000-0000-4000-8148-000000000004');  -- CGR-244
select pg_temp.co('o5', date '2026-11-24', time '08:00', time '12:00', 'dddd0000-0000-4000-8148-000000000005');  -- CGR-242 (f)
reset role;
select pg_temp.as_owner();
select is((select count(*)::int from made where r ->> 'result' = 'ok'), 5, 'the five fixture orders are confirmed');

-- Helpers ---------------------------------------------------------------------------------------------------------------
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
create function pg_temp.live(k text) returns public.order_takes language sql as $$
  select * from public.order_takes t where t.order_id = pg_temp.oid(k) and t.released_at is null
$$;
create function pg_temp.first_take(k text) returns uuid language sql as $$
  select t.id from public.order_takes t where t.order_id = pg_temp.oid(k) order by t.taken_at, t.id limit 1
$$;
-- The visit written from the first take of an order, read as the table owner (dynamic: the column is new).
create function pg_temp.visit(k text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  execute 'select to_jsonb(v) from public.care_visits v where v.order_take_id = $1' into res using pg_temp.first_take(k);
  return res;
end;
$$;
create function pg_temp.visits_of(k text) returns integer language plpgsql as $$
declare n integer;
begin
  execute 'select count(*)::int from public.care_visits v join public.order_takes t on t.id = v.order_take_id
           where t.order_id = $1' into n using pg_temp.oid(k);
  return n;
end;
$$;
create temp table fv (member text, visit_id uuid, plz text, ort text, status text, system_end_reason text, from_take boolean);
grant all on fv to authenticated;
create function pg_temp.field(member text, d date) returns void language plpgsql as $$
begin
  delete from fv where fv.member = $1;
  perform pg_temp.act_as(pg_temp.m(member)::text);
  set local role authenticated;
  insert into fv select member, x.visit_id, x.plz, x.ort, x.status, x.system_end_reason, x.from_take from public.field_visits(d) x;
  reset role;
  perform pg_temp.as_owner();
end;
$$;
create function pg_temp.sees(member text, k text, d date) returns boolean language plpgsql as $$
begin
  perform pg_temp.field(member, d);
  return exists (select 1 from fv where fv.member = $1 and fv.visit_id = (pg_temp.visit(k) ->> 'id')::uuid);
end;
$$;

create function pg_temp.release(actor text, k text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.release_named_take(pg_temp.oid(k), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.depart(actor text, k text, key text) returns text language plpgsql as $$
declare res text;
  vid uuid := (pg_temp.visit(k) ->> 'id')::uuid;  -- read as the table owner, before the role switch
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.depart_visit(vid, key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;

-- 3. Self-named take: the visit is written at the take (criterion 2; CGR-232) ------------------------------------------
select is(pg_temp.take('01', 'o1', '01', '01', 'ffff0000-0000-4000-8148-000000000001') ->> 'result', 'ok',
          'M1 takes O1 naming herself');
select is(pg_temp.visits_of('o1'), 1, 'BK-7: one visit is written from the self-named take');
select is(pg_temp.visit('o1') ->> 'responsible_user_id', pg_temp.m('01')::text, 'BK-7: the named member is responsible');
select is(pg_temp.visit('o1') ->> 'team_id', pg_temp.t('01')::text, 'BK-7: the take''s team owns the visit');
select is((pg_temp.visit('o1') ->> 'visit_date') || ' ' || (pg_temp.visit('o1') ->> 'time_start') || '-' ||
          (pg_temp.visit('o1') ->> 'time_end'), '2026-11-19 08:00:00-12:00:00',
          'BK-7: date and times from the order, Europe/Zurich wall clock');
select is(pg_temp.visit('o1') ->> 'status', 'planned', 'BK-7: the visit is planned');
select ok((pg_temp.live('o1')).id is not null, 'CGR-232: writing the visit does not release the take of the person who is coming');
select is(private.order_member_step(pg_temp.oid('o1'), pg_temp.t('01'), pg_temp.m('01')), 4,
          'CGR-232: step 3 does not count the visit written from the same take');
select is(pg_temp.cs('o1'), 'covered', 'the client still reads «gedeckt»');
select ok(exists (select 1 from public.audit_events a where a.table_name = 'care_visits'
                  and a.entity_id = (pg_temp.visit('o1') ->> 'id')::uuid),
          'AUD1: the written visit has its audit row');

-- 4. Only the named member reads it on /field (criterion 2, negative cases) ---------------------------------------------
select ok(pg_temp.sees('01', 'o1', date '2026-11-19'), 'BK-7: the named member reads the visit on /field');
-- UXR-237, UXR-239 (PO 05:39): /field carries a take flag, so the card names the kind and the simulation limit.
select is((select fv.from_take from fv where fv.member = '01' and fv.visit_id = (pg_temp.visit('o1') ->> 'id')::uuid), true,
          'UXR-237/239: field_visits.from_take is true for the visit written from a take');
select is((select count(*)::int from fv where fv.member = '01' and fv.from_take is distinct from
             exists (select 1 from public.care_visits v where v.id = fv.visit_id and v.order_take_id is not null)), 0,
          'UXR-237/239: from_take is never null and true only for a visit with order_take_id');
select is((select plz || ' ' || ort from fv where member = '01' and visit_id = (pg_temp.visit('o1') ->> 'id')::uuid),
          '4102 ' || (select p.city from public.partner_requests p where p.id = pg_temp.oid('o1')),
          'BK-7: the place comes from the order (postcode and place; no street, P-8)');
select ok(not pg_temp.sees('02', 'o1', date '2026-11-19'), 'BK-7 negative: a member of the same team who is not named does not');
select ok(not pg_temp.sees('03', 'o1', date '2026-11-19'), 'BK-7 negative: a member of another team does not');

-- 5. Take naming a colleague: no visit before her acknowledgement, one after it (ADR-200) ------------------------------
select is(pg_temp.take('01', 'o2', '01', '02', 'ffff0000-0000-4000-8148-000000000010') ->> 'result', 'ok', 'M1 takes O2 naming M2');
select is(pg_temp.visits_of('o2'), 0, 'BK-7: a take awaiting the acknowledgement writes no visit (not «gedeckt»)');
select is(pg_temp.ack('02', 'o2', 'ffff0000-0000-4000-8148-000000000011') ->> 'result', 'ok', 'M2 acknowledges');
select is(pg_temp.visits_of('o2'), 1, 'BK-7: the acknowledgement writes the visit');
select is(pg_temp.visit('o2') ->> 'responsible_user_id', pg_temp.m('02')::text, 'BK-7: the named colleague is responsible, not the taker');
select ok((pg_temp.live('o2')).id is not null, 'CGR-232: the acknowledged take stays live after its visit is written');
select ok(pg_temp.sees('02', 'o2', date '2026-11-20'), 'BK-7: the named colleague reads it on /field');
select ok(not pg_temp.sees('01', 'o2', date '2026-11-20'), 'BK-7 negative: the taker of the same team who is not named does not');

-- 6. Shift across midnight (criterion 4; CGR-200, CGR-206 (a)) -----------------------------------------------------------
select is(pg_temp.take('03', 'o3', '02', '03', 'ffff0000-0000-4000-8148-000000000020') ->> 'result', 'ok', 'M3 takes O3 (22:00–07:00)');
select is((pg_temp.visit('o3') ->> 'visit_date') || ' ' || (pg_temp.visit('o3') ->> 'time_start') || '-' ||
          (pg_temp.visit('o3') ->> 'time_end'), '2026-11-21 22:00:00-07:00:00', 'criterion 4: one visit from 22:00 to 07:00');
select is((select upper(private.visit_interval(v)) - lower(private.visit_interval(v)) from public.care_visits v
           where v.id = (pg_temp.visit('o3') ->> 'id')::uuid), interval '9 hours',
          'criterion 4: the visit covers 9 h, the same instants as the order');
select is((select tstzrange(p.starts_at, p.ends_at, '[)') from public.partner_requests p where p.id = pg_temp.oid('o3')),
          (select private.visit_interval(v) from public.care_visits v where v.id = (pg_temp.visit('o3') ->> 'id')::uuid),
          'criterion 4: visit interval equals the order slot');

-- 7. CGR-242 positive: release after «gedeckt», before the start → visit cancelled in the same transaction ------------
-- Recorded while a command name is set, as the absence command does: without the 0139 rule this would write a
-- «cancelled» timeline event for the visit.
select set_config('navora.command', 'bk_e1b_test_absence', true);
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b148-000000000001', '00000000-0000-4000-a148-000000000001',
   timestamptz '2026-11-19 07:00:00+01', timestamptz '2026-11-19 13:00:00+01', '00000000-0000-4000-a148-000000000001');
select ok((pg_temp.live('o1')).id is null,
          'precondition: her absence releases her take before the start (ADR-199 (5))');
select is(pg_temp.visit('o1') ->> 'status', 'cancelled', 'CGR-242: the visit of the released take is cancelled in the same transaction');
select is(pg_temp.visits_of('o1'), 1, 'CGR-242: and never deleted');
select isnt(pg_temp.cs('o1'), 'covered', 'CGR-242: the order leaves «gedeckt» for the client');
select set_config('navora.command', '', true);
select is(pg_temp.visit('o1') ->> 'system_end_reason', 'take_released_absence',
          'CGR-242 (a): the visit carries the stored system reason (her own absence released the take)');
select ok(not exists (select 1 from public.visit_events e where e.visit_id = (pg_temp.visit('o1') ->> 'id')::uuid
                      and e.event_type = 'cancelled'),
          'CGR-242 (a): no «cancelled» timeline event, so no count reads it as a cancellation');
select ok(not exists (select 1 from public.visit_status_notes n where n.visit_id = (pg_temp.visit('o1') ->> 'id')::uuid),
          'CGR-242 (a): no cancellation note with a client or team reason');
select ok(pg_temp.sees('01', 'o1', date '2026-11-19'), 'CGR-242 (c): /field still lists the ended visit to the released member');
select is((select f.status || ' ' || f.system_end_reason from fv f
           where f.member = '01' and f.visit_id = (pg_temp.visit('o1') ->> 'id')::uuid), 'cancelled take_released_absence',
          'CGR-242 (c): /field returns her the status and the reason code');
select ok(not pg_temp.sees('02', 'o1', date '2026-11-19'),
          'CGR-242 (c) / lca: a member of the same team who was not named never reads it or its reason');

-- 8. CGR-242 negative: after the start no automatic step releases or changes anything -----------------------------------
select pg_temp.clock('2026-11-20 09:00:00+01');
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b148-000000000001', '00000000-0000-4000-a148-000000000002',
   timestamptz '2026-11-20 10:00:00+01', timestamptz '2026-11-20 13:00:00+01', '00000000-0000-4000-a148-000000000002');
select ok((pg_temp.live('o2')).member_id = pg_temp.m('02'), 'CGR-242 negative: after starts_at the take is not released automatically');
select is(pg_temp.visit('o2') ->> 'status', 'planned', 'CGR-242 negative: after starts_at the visit is unchanged');

-- 9. CGR-242 (f): «Ich kann nicht» before the start on a take awaiting the acknowledgement -----------------------------
select is(pg_temp.take('01', 'o5', '01', '02', 'ffff0000-0000-4000-8148-000000000050') ->> 'result', 'ok', 'M1 takes O5 naming M2');
select is(pg_temp.release('02', 'o5', 'ffff0000-0000-4000-8148-000000000051') ->> 'result', 'ok',
          'M2 says «Ich kann nicht» before the start');
select ok((pg_temp.live('o5')).id is null, 'CGR-242 (f): the take is released');
select is(pg_temp.visits_of('o5'), 0, 'CGR-242 (f): no visit was written and none is left behind');

-- 10. CGR-244: a take whose visit is under way before the start is never released ----------------------------------------
select is(pg_temp.take('03', 'o4', '02', '03', 'ffff0000-0000-4000-8148-000000000040') ->> 'result', 'ok',
          'M3 takes O4 naming herself');
select is(pg_temp.visits_of('o4'), 1, 'the take writes its visit');
select pg_temp.clock('2026-11-23 07:30:00+01');
select is(pg_temp.depart('03', 'o4', 'ffff0000-0000-4000-8148-000000000041'), 'ok',
          'precondition: M3 sets «unterwegs» before the start (F1 has no time guard)');
select is(pg_temp.visit('o4') ->> 'status', 'on_the_way', 'precondition: the visit is on the way');
select is(pg_temp.cs('o4'), 'covered', 'precondition: on the way, the client reads «gedeckt»');
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b148-000000000002', '00000000-0000-4000-a148-000000000003',
   timestamptz '2026-11-23 07:00:00+01', timestamptz '2026-11-23 13:00:00+01', '00000000-0000-4000-a148-000000000003');
select ok((pg_temp.live('o4')).member_id = pg_temp.m('03'), 'CGR-244: her absence does not release the take while her visit is under way');
select is(pg_temp.visit('o4') ->> 'status', 'on_the_way', 'CGR-244: the visit is unchanged');
select ok(pg_temp.visit('o4') ->> 'system_end_reason' is null, 'CGR-244: no system end reason');
-- Deviation from the `cra` CGR-244 case («client still gedeckt»), recorded for `cra` (ADR-203 (10)): the ADR-199 (5)
-- safety net in private.order_cover is unchanged, so a live take whose member no longer passes is never shown as
-- covered. Here: not covered, the take is NOT re-broadcast (it stays live). Not changed by `eng` (safety rule).
select is(pg_temp.cs('o4'), 'not_covered',
          'CGR-244 with ADR-199 (5): the client is not shown «gedeckt» while the absence conflicts; the take is not re-broadcast');
select is(pg_temp.release('03', 'o4', 'ffff0000-0000-4000-8148-000000000042'),
          jsonb_build_object('result', 'refused', 'reason', 'visit_under_way'),
          'CGR-244: «Ich kann nicht» is refused with the visible reason visit_under_way');
select ok((pg_temp.live('o4')).member_id = pg_temp.m('03') and pg_temp.visit('o4') ->> 'status' = 'on_the_way',
          'CGR-244: after the refusal the take is live and the visit still on the way');

-- 11. CGR-248 / UXR-241 (PO 06:39 (2)): no person command ends a take visit while its take stays live ------------------
-- `cancel_visit` refuses a visit written from a take (order_take_id not null) with the stated reason `take_visit`;
-- visit, take and client cover stay unchanged. The cancellation of a visit not from a take is unchanged (pgTAP 023,
-- 031, 055 keep passing). Her way out before «unterwegs» stays the release with a reason (CGR-242, §7).
create function pg_temp.cancel(actor text, k text, key text) returns text language plpgsql as $$
declare res text;
  vid uuid := (pg_temp.visit(k) ->> 'id')::uuid;  -- read as the table owner, before the role switch
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.cancel_visit(vid, 'team_cancelled', null, key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create temp table cov as select pg_temp.cs('o1') as before;
select is(pg_temp.cancel('01', 'o1', 'ffff0000-0000-4000-8148-000000000060'), 'take_visit',
          'CGR-248: the named member cannot cancel her take visit; the stated reason is take_visit');
select is(pg_temp.visit('o1') ->> 'status', 'planned', 'CGR-248: the take visit stays planned');
select ok((pg_temp.live('o1')).member_id = pg_temp.m('01'), 'CGR-248: the take stays live with her');
select is(pg_temp.cs('o1'), (select before from cov), 'CGR-248: the client cover is unchanged by the refusal');
select is((select count(*)::int from public.visit_status_notes n where n.visit_id = (pg_temp.visit('o1') ->> 'id')::uuid
             and n.kind = 'cancelled'), 0, 'CGR-248: no cancellation note is written');
select is(pg_temp.cancel('02', 'o1', 'ffff0000-0000-4000-8148-000000000061'), 'take_visit',
          'CGR-248: a colleague of the same team cannot cancel it either');
select is(pg_temp.cancel('03', 'o4', 'ffff0000-0000-4000-8148-000000000062'), 'take_visit',
          'CGR-248: a take visit on the way is refused as well');
select is(pg_temp.visit('o4') ->> 'status', 'on_the_way', 'CGR-248: the visit on the way is unchanged');

select * from finish();
rollback;
