-- BK-c2 database part (brief `docs/agents/briefs/BK.md`, PO amendments 2026-11-17 04:39 (3), 05:39 (3), 08:39 (2) to
-- (4), 09:39 (2); ADR-199 addendum 10:15). Red first (FE-071 (2)): pushed alone on `recovery/main` `dcce1ef`, where
-- `public.acknowledge_take`, `public.release_named_take`, `public.order_take_candidates` and the columns
-- `order_takes.acknowledged_at` / `released_by` do not exist, a take naming a colleague reads «gedeckt» at once, and
-- the client reads `no_team_eligible` / `all_declined` as separate values.
--
-- What it guards (each line names its source):
--   * CGR-230 (PO 05:39 (3)): a take naming a colleague other than the caller needs that colleague's acknowledgement;
--     positive: she acknowledges → the take stays live and covers; negative: no acknowledgement by `latest_cover_at` →
--     released (`not_acknowledged`) and re-offered; a member of another team cannot acknowledge; a self-named take
--     needs none.
--   * UXR-223 (PO 08:39 (3)): before the acknowledgement the client never reads «gedeckt»; it reads «noch nicht
--     gedeckt» with the detail `awaiting_acknowledgement` and no team name.
--   * UXR-222 (PO 08:39 (2)) with CGR-234 (PO 09:39 (2)): «Ich kann nicht» releases at once through the ADR-199
--     release path; (a) its own release code `member_cannot`, distinct from step codes, plus `released_by`, no reason
--     field; (b) a release one minute before `latest_cover_at` raises `order_not_covered` at once when no team is
--     eligible, and the lapse at `latest_cover_at` raises it too; (c) after `starts_at` the action is refused, never a
--     silent release; (d) the taker's team sees the release (the read model part; the screen is e2e).
--   * PO 08:39 (2) «her own team takes again if another member passes»: her «Ich kann nicht» is a non-availability for
--     THIS order in `private.order_member_step` (step 3); she is not re-offered as the going person.
--   * F-1 (PO 04:39 (3)): the client reads one neutral zero-state detail `no_team_free`; never `no_team_eligible` or
--     `all_declined`; Operations keeps the full detail.
--   * AUT-132 (PO 08:39 (4)): the colleague list holds only members at step 4; no step code reaches the caller.
-- Not here: the screens (Playwright, same PR), ranking (BK-c3). The 240 min lead stays PROPOSED (K-8).
--
-- Users: kundebs …9e8 (client). Fixture: T1 (M1, M2), T2 (M3), postcode 4102, 10 km, all FaGe; no seed team of
-- Testorganisation S serves 4102 with a FaGe member (pgTAP 143 precondition). Pinned clock, moved forward only.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(67);

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
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b144-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a144-0000000000' || n)::uuid $$;

-- 0. The new surface (non-aborting checks first) --------------------------------------------------------------------
select has_function('public', 'acknowledge_take', array['uuid', 'uuid'], 'CGR-230: public.acknowledge_take exists');
select has_function('public', 'release_named_take', array['uuid', 'uuid'], 'UXR-222: public.release_named_take exists');
select has_function('public', 'order_take_candidates', array['uuid', 'uuid'], 'AUT-132: public.order_take_candidates exists');
select has_column('public', 'order_takes', 'acknowledged_at', 'CGR-230: a take carries its acknowledgement time');
select has_column('public', 'order_takes', 'released_by', 'CGR-234 (a): a person''s release names who released');
select is((select coalesce(array_agg(c.column_name::text order by c.column_name), '{}') from information_schema.columns c
           where c.table_schema = 'public' and c.table_name = 'order_takes'
             and c.column_name not in ('id', 'organization_id', 'order_id', 'round', 'team_id', 'member_id', 'taken_by',
                                       'taken_at', 'released_at', 'release_reason', 'acknowledged_at', 'released_by')),
          '{}'::text[], 'lca (PO 08:39 (2)): no reason or free-text column on a take');

-- 1. Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003ca', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-c2 Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003ca', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b144-000000000001', 'BK-c2 Fixture T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b144-000000000002', 'BK-c2 Fixture T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b144-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a144-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-c2-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a144-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b144-000000000001', '00000000-0000-4000-a144-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b144-000000000001', '00000000-0000-4000-a144-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b144-000000000002', '00000000-0000-4000-a144-000000000003', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a144-0000000000' || n)::uuid, 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02', '03']) n;
-- O5's day: M1 and M3 are away, so after M2's «Ich kann nicht» no team passes (CGR-234 (b)).
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b144-000000000001', '00000000-0000-4000-a144-000000000001',
   timestamptz '2026-11-23 07:00:00+01', timestamptz '2026-11-23 13:00:00+01', '00000000-0000-4000-a144-000000000001'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b144-000000000002', '00000000-0000-4000-a144-000000000003',
   timestamptz '2026-11-23 07:00:00+01', timestamptz '2026-11-23 13:00:00+01', '00000000-0000-4000-a144-000000000003');

-- 2. Orders (FaGe, C1, 08:00 – 12:00; latest coverage time 04:00 with the PROPOSED 240 min lead) -------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(k text, d date, key text) returns void language sql as $$
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003ca', d, time '08:00', time '12:00',
                                                         '4102', 'fage_efz', array['C1'], array['C1'], null, key::uuid)
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select pg_temp.co('o1', date '2026-11-19', 'dddd0000-0000-4000-8144-000000000001');  -- self-named
select pg_temp.co('o2', date '2026-11-20', 'dddd0000-0000-4000-8144-000000000002');  -- colleague named, acknowledges
select pg_temp.co('o3', date '2026-11-21', 'dddd0000-0000-4000-8144-000000000003');  -- «Ich kann nicht» early
select pg_temp.co('o4', date '2026-11-22', 'dddd0000-0000-4000-8144-000000000004');  -- no acknowledgement: lapse
select pg_temp.co('o5', date '2026-11-23', 'dddd0000-0000-4000-8144-000000000005');  -- CGR-234 (b)
select pg_temp.co('o6', date '2026-11-25', 'dddd0000-0000-4000-8144-000000000006');  -- CGR-234 (c)
reset role;
select pg_temp.as_owner();
select is((select count(*)::int from made where r ->> 'result' = 'ok'), 6, 'the six fixture orders are confirmed');
create function pg_temp.offered(k text, rnd int) returns uuid[] language sql as $$
  select coalesce(array_agg(o.team_id order by o.team_id), '{}') from public.order_offers o
  where o.order_id = pg_temp.oid(k) and o.round = rnd and o.team_id::text like '00000000-0000-4000-b144-%'
$$;
select is(pg_temp.offered('o5', 1), array[pg_temp.t('01')], 'precondition: O5 round 1 offers only T1 (through M2)');

-- Helpers: commands as a user; client and Operations readings -----------------------------------------------------------
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
create function pg_temp.cannot(actor text, k text, key text) returns jsonb language plpgsql as $$
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
create function pg_temp.cs(k text) returns text language plpgsql as $$
declare res text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  select x.cover_state || coalesce('/' || x.cover_detail, '') into res from public.client_orders() x where x.id = pg_temp.oid(k);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.client_team(k text) returns text language plpgsql as $$
declare res text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  select x.covered_team_name into res from public.client_orders() x where x.id = pg_temp.oid(k);
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
create function pg_temp.live(k text) returns public.order_takes language sql as $$
  select * from public.order_takes t where t.order_id = pg_temp.oid(k) and t.released_at is null
$$;
create function pg_temp.last(k text) returns public.order_takes language sql as $$
  select * from public.order_takes t where t.order_id = pg_temp.oid(k) order by t.taken_at desc, t.id desc limit 1
$$;
create temp table seen (member text, k text, team_id uuid, offer_state text, taken_member_id uuid,
                        release_kind text, released_member_id uuid);
grant all on seen to authenticated;
create function pg_temp.look(member text, k text) returns void language plpgsql as $$
begin
  delete from seen where seen.member = $1 and seen.k = $2;
  perform pg_temp.act_as(pg_temp.m(member)::text);
  set local role authenticated;
  insert into seen select member, k, x.team_id, x.offer_state, x.taken_member_id, x.release_kind, x.released_member_id
    from public.team_order_offers() x where x.order_id = pg_temp.oid(k);
  reset role;
  perform pg_temp.as_owner();
end;
$$;
create function pg_temp.out_cols(fn text) returns setof text language sql as $$
  select n from pg_proc p, unnest(p.proargnames, p.proargmodes) as a(n, m)
  where p.oid = fn::regprocedure and a.m = 't'
$$;

-- 3. Self-named take: no acknowledgement (CGR-230, negative) -----------------------------------------------------------
select is(pg_temp.take('01', 'o1', '01', '01', 'ffff0000-0000-4000-8144-000000000001') ->> 'result', 'ok', 'M1 takes O1 naming herself');
select ok((pg_temp.live('o1')).acknowledged_at is not null, 'CGR-230: a take naming the caller herself counts as acknowledged');
select is(pg_temp.cs('o1'), 'covered', 'a self-named take covers at once');
select is(pg_temp.cannot('01', 'o1', 'ffff0000-0000-4000-8144-000000000002') ->> 'reason', 'self_named',
          'UXR-222: a self-named take has no «Ich kann nicht» (no un-take in BK-c)');
select is(pg_temp.ack('01', 'o1', 'ffff0000-0000-4000-8144-000000000003') ->> 'reason', 'already_acknowledged',
          'a self-named take has no «Bestätigen»');

-- 4. Colleague named, acknowledges (CGR-230 positive; UXR-221; UXR-223) -------------------------------------------------
select is(pg_temp.take('01', 'o2', '01', '02', 'ffff0000-0000-4000-8144-000000000010') ->> 'result', 'ok', 'M1 takes O2 naming M2');
select ok((pg_temp.live('o2')).acknowledged_at is null, 'CGR-230: a take naming a colleague waits for her acknowledgement');
select is(pg_temp.ops('o2'), 'pending_acknowledgement', 'Operations reads the take as pending acknowledgement');
select is(pg_temp.cs('o2'), 'open/awaiting_acknowledgement', 'UXR-223: before the acknowledgement the client reads «noch nicht gedeckt»');
select is(pg_temp.client_team('o2'), null, 'UXR-223: and no team name yet');
select is(pg_temp.ack('01', 'o2', 'ffff0000-0000-4000-8144-000000000011') ->> 'reason', 'not_named',
          'the taker cannot acknowledge for the named colleague');
select is(pg_temp.ack('03', 'o2', 'ffff0000-0000-4000-8144-000000000012') ->> 'reason', 'not_named',
          'CGR-230 negative: a member of another team cannot acknowledge');
select pg_temp.look('03', 'o2');
select is((select count(*)::int from seen where member = '03' and k = 'o2'), 0, 'BK-c2 (03:39 (3)): another team never sees the take');
select pg_temp.look('02', 'o2');
select is((select offer_state || '/' || taken_member_id::text from seen where member = '02' and k = 'o2'),
          'taken_by_us/' || pg_temp.m('02')::text, 'UXR-221: the named person sees the take of her team naming her');
select is(pg_temp.ack('02', 'o2', 'ffff0000-0000-4000-8144-000000000013') ->> 'result', 'ok', 'CGR-230: M2 acknowledges');
select is(pg_temp.cs('o2'), 'covered', 'CGR-230 positive: after the acknowledgement the take covers');
select is(pg_temp.cannot('02', 'o2', 'ffff0000-0000-4000-8144-000000000014') ->> 'reason', 'already_acknowledged',
          '«Ich kann nicht» only beside «Bestätigen», not after it');
select ok((select count(*) from public.audit_events a where a.table_name = 'order_takes'
           and a.entity_id = (pg_temp.live('o2')).id and a.changed ? 'acknowledged_at') >= 1,
          'AUD1: the acknowledgement has its audit row');

-- 5. «Ich kann nicht» (UXR-222, CGR-234 (a), (d)) ----------------------------------------------------------------------
select is(pg_temp.take('01', 'o3', '01', '02', 'ffff0000-0000-4000-8144-000000000020') ->> 'result', 'ok', 'M1 takes O3 naming M2');
select is(pg_temp.cannot('03', 'o3', 'ffff0000-0000-4000-8144-000000000021') ->> 'reason', 'not_named',
          'a member of another team cannot release');
select is(pg_temp.cannot('02', 'o3', 'ffff0000-0000-4000-8144-000000000022') ->> 'result', 'ok', 'UXR-222: M2 says «Ich kann nicht»');
select ok((pg_temp.live('o3')).id is null, 'UXR-222: the take is no longer live at once');
select is((pg_temp.last('o3')).release_reason || '/' || (pg_temp.last('o3')).released_by::text,
          'member_cannot/' || pg_temp.m('02')::text, 'CGR-234 (a): own release code, distinct from step codes, and released_by');
select is(private.order_member_step(pg_temp.oid('o3'), pg_temp.t('01'), pg_temp.m('02')), 3,
          'PO 08:39 (2): her «Ich kann nicht» is a non-availability for this order');
select is(pg_temp.offered('o3', 2), array[pg_temp.t('01'), pg_temp.t('02')],
          'UXR-222: the release path screens a new round; her team stays in through another member');
select is(pg_temp.cs('o3'), 'open/take_fell_away',
          'UXR-225 (a) (PO 12:39 (2)): the client never read «gedeckt», so it reads «noch nicht gedeckt», never «nicht mehr gedeckt»');
select pg_temp.look('01', 'o3');
select is((select offer_state || '/' || release_kind || '/' || released_member_id::text from seen where member = '01' and k = 'o3'),
          'open/member_cannot/' || pg_temp.m('02')::text, 'CGR-234 (d): the taker''s team sees the release and who released');
create temp table cand (user_id uuid, is_caller boolean);
grant all on cand to authenticated;
select pg_temp.act_as(pg_temp.m('01')::text);
set local role authenticated;
insert into cand select * from public.order_take_candidates(pg_temp.oid('o3'), pg_temp.t('01'));
reset role;
select pg_temp.as_owner();
select is((select array_agg(user_id::text || '/' || is_caller::text) from cand), array[pg_temp.m('01')::text || '/true'],
          'AUT-132: the colleague list holds only members at step 4 (M2 is not listed after «Ich kann nicht»)');
select is((select count(*)::int from (select pg_temp.out_cols('public.order_take_candidates(uuid, uuid)') c
                                      union all select pg_temp.out_cols('public.team_order_offers()')) x(c)
           where x.c ~* 'step'), 0, 'AUT-132: no step code of any member reaches the caller');

-- 6. No acknowledgement by the latest coverage time (CGR-230 negative, CGR-234 (b) +0) --------------------------------
select is(pg_temp.take('01', 'o4', '01', '02', 'ffff0000-0000-4000-8144-000000000030') ->> 'result', 'ok', 'M1 takes O4 naming M2');
select pg_temp.clock('2026-11-22 03:59:00+01');
select is(pg_temp.cs('o4'), 'open/awaiting_acknowledgement', 'one minute before the latest coverage time: still awaiting');
select ok(not pg_temp.exc('o4'), 'and no exception yet');
select pg_temp.clock('2026-11-22 04:00:00+01');
select is(pg_temp.ops('o4'), 'not_covered/not_acknowledged', 'CGR-230: at the latest coverage time an unacknowledged take counts as released');
select is(pg_temp.cs('o4'), 'not_covered/cover_time_reached', 'the client never read «gedeckt» and now reads «nicht gedeckt»');
select ok(pg_temp.exc('o4'), 'CGR-234 (b): order_not_covered is raised at the latest coverage time');
select is(pg_temp.ack('02', 'o4', 'ffff0000-0000-4000-8144-000000000031') ->> 'reason', 'no_live_take',
          'an acknowledgement after the latest coverage time is refused');
select is((pg_temp.last('o4')).release_reason || '/' || coalesce((pg_temp.last('o4')).released_by::text, '-'),
          'not_acknowledged/-', 'CGR-230: the lapse is recorded with its own code and no person');
select ok(pg_temp.t('02') = any (pg_temp.offered('o4', 2)), 'CGR-230: the order is re-offered (new round, T2 included)');
select pg_temp.look('03', 'o4');
select is((select offer_state from seen where member = '03' and k = 'o4'), 'open', 'CGR-230: the other team sees the re-offer');

-- 7. «Ich kann nicht» one minute before the coverage time, no team left (CGR-234 (b) −1) --------------------------------
select is(pg_temp.take('01', 'o5', '01', '02', 'ffff0000-0000-4000-8144-000000000040') ->> 'result', 'ok', 'M1 (away that day) takes O5 naming M2');
select pg_temp.clock('2026-11-23 03:59:00+01');
select is(pg_temp.cannot('02', 'o5', 'ffff0000-0000-4000-8144-000000000041') ->> 'result', 'ok', 'M2 says «Ich kann nicht» at 03:59');
select is(pg_temp.offered('o5', 2), '{}'::uuid[], 'the new round offers no team');
select is(pg_temp.ops('o5'), 'not_covered/no_team_eligible', 'Operations keeps the full detail');
select is(pg_temp.cs('o5'), 'not_covered/no_team_free', 'F-1: the client reads one neutral zero-state detail');
select ok(pg_temp.exc('o5'), 'CGR-234 (b): order_not_covered is raised at once, before the coverage time');

-- 8. After the start (CGR-234 (c)) -------------------------------------------------------------------------------------
select pg_temp.clock('2026-11-23 03:59:00+01');
select is(pg_temp.take('01', 'o6', '01', '02', 'ffff0000-0000-4000-8144-000000000050') ->> 'result', 'ok', 'M1 takes O6 naming M2');
select pg_temp.clock('2026-11-25 08:00:00+01');
select is(pg_temp.cannot('02', 'o6', 'ffff0000-0000-4000-8144-000000000051') ->> 'reason', 'order_started',
          'CGR-234 (c): after the start «Ich kann nicht» is refused');
select ok((pg_temp.live('o6')).id is not null, 'CGR-234 (c): never a silent release after the start');
select private.lapse_unacknowledged_takes();
select ok((pg_temp.live('o6')).id is not null, 'the lapse sweep does not touch a started order');
select is(pg_temp.ops('o6'), 'not_covered/started', 'an unacknowledged take never covers a started order');
select is(pg_temp.ack('02', 'o6', 'ffff0000-0000-4000-8144-000000000052') ->> 'reason', 'order_started',
          'an acknowledgement after the start is refused');

-- 10. An acknowledged take dropped by the ADR-199 safety net (UXR-225 (b), `lca` F-2; PO 12:39 (2)) ------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select pg_temp.co('o7', date '2026-11-28', 'dddd0000-0000-4000-8144-000000000007');
reset role;
select pg_temp.as_owner();
select is(made.r ->> 'result', 'ok', 'O7 is confirmed') from made where made.k = 'o7';
select is(pg_temp.take('01', 'o7', '01', '02', 'ffff0000-0000-4000-8144-000000000060') ->> 'result', 'ok', 'M1 takes O7 naming M2');
select is(pg_temp.ack('02', 'o7', 'ffff0000-0000-4000-8144-000000000061') ->> 'result', 'ok', 'M2 acknowledges O7');
select is(pg_temp.cs('o7'), 'covered', 'the client reads «gedeckt»');
-- A membership row removed with triggers off stands for any path the triggers miss (as pgTAP 142 section 2).
set local session_replication_role = replica;
delete from public.team_memberships where team_id = pg_temp.t('01') and user_id = pg_temp.m('02');
set local session_replication_role = origin;
select is(pg_temp.cs('o7'), 'no_longer_covered',
          'UXR-225 (b): after «gedeckt» was shown, the safety net reads «nicht mehr gedeckt» (the words carry no person, F-2)');

-- 9. Whole client read model (F-1, UXR-223 negative) -------------------------------------------------------------------
create temp table cl (id uuid, cover_state text, cover_detail text);
grant all on cl to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
insert into cl select x.id, x.cover_state, x.cover_detail from public.client_orders() x;
reset role;
select pg_temp.as_owner();
select is((select count(*)::int from cl where cover_detail in ('no_team_eligible', 'all_declined', 'not_acknowledged')), 0,
          'F-1: the client never reads no_team_eligible, all_declined or not_acknowledged');
select is((select count(*)::int from cl join public.order_takes t on t.order_id = cl.id and t.released_at is null
           where cl.cover_state = 'covered' and t.acknowledged_at is null), 0,
          'UXR-223: no client row reads «gedeckt» on an unacknowledged take');
select is((select count(*)::int from cl
           where cl.cover_state = 'no_longer_covered'
             and not exists (select 1 from public.order_takes t where t.order_id = cl.id and t.acknowledged_at is not null)), 0,
          'UXR-225 (a): no client row reads «nicht mehr gedeckt» on an order whose take was never acknowledged');

select * from finish();
rollback;
