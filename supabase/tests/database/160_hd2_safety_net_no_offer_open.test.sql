-- HD-2 (brief docs/agents/briefs/HD.md §3, §3a): condition «Angebot läuft wieder» (HD-2 acceptance criterion, negative
-- test required): the client may read that the offer runs again only if (1) the take is released (`released_at` set),
-- (2) a new round has at least one open offer, and (3) the latest coverage time is not reached. FE-110 note (b).
-- History: written red on the unmerged probe branch `probe/hd-2-safety-net-red` (3588454b, test 8 `not ok` on
-- recovery/main 24ad2834), turned green by migration 0161 (safety net → detail `no_offer_open`).
--
-- How the client reads «the offer runs again» (`src/features/orders/offer-rules.ts` `clientCoverLines`):
--   `no_longer_covered` (no detail) and `open / take_fell_away` → «Das Angebot geht wieder an alle passenden Teams.»
--   `no_longer_covered / no_offer_open` and `open / take_fell_away_no_offer` → «kein Angebot offen» (0161).
-- Sections: 1 a real release (positive control); 2 the safety net on a path no trigger sees (triggers off);
-- 3 the time-based neighbours; 4 the safety net reached WITHOUT any command or trigger gap: a recorded contract end
-- passes while the take is live (`private.access_ended` is time-based; FE-110 (b) question «does this branch occur
-- outside a moment?» → yes).
-- No clinical rule is set here; the 240 min lead stays PROPOSED (K-8). Synthetic data only; rolled back.
--
-- Users: kundebs …9e8 (seed client), fixture admin …a160-…09 of Testorganisation S. Teams …b160-…01 (M1, M2),
-- …b160-…02 (M3), postcode 4102, 10 km. Pinned clock Mon 2026-11-16 12:00 Europe/Zurich.
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
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b160-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a160-0000000000' || n)::uuid $$;

-- Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-000000000460', '00000000-0000-4000-b000-000000000019', 'Haushalt HD-2 Probe (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-000000000460', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b160-000000000001', 'HD-2 Probe T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b160-000000000002', 'HD-2 Probe T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b160-%';
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a160-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'hd2-probe-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03', '09']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a160-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03']) n;
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a160-000000000009', 'admin');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b160-000000000001', '00000000-0000-4000-a160-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b160-000000000001', '00000000-0000-4000-a160-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b160-000000000002', '00000000-0000-4000-a160-000000000003', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a160-0000000000' || n)::uuid, 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02', '03']) n;

-- One FaGe night order, Thu 2026-11-19 22:00 – Fri 07:00, confirmed by the client.
create temp table made (r jsonb);
grant all on made to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
insert into made select public.confirm_client_order('00000000-0000-4000-a000-000000000460', date '2026-11-19', time '22:00',
  time '07:00', '4102', 'fage_efz', array['C1'], array['C1'], null, 'dddd0000-0000-4000-8160-000000000001');
reset role;
create function pg_temp.o() returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made $$;
select is((select r ->> 'result' from made), 'ok', 'the fixture order is confirmed');

create function pg_temp.take(team text, member text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(member)::text);
  set local role authenticated;
  res := public.take_order(pg_temp.o(), pg_temp.t(team), pg_temp.m(member), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
-- What the client's own read model says, as the client (RLS and LEAVE1-3 apply).
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
-- The two read-model values that `clientCoverLines` renders as «Das Angebot geht wieder an alle passenden Teams».
create function pg_temp.claims_again() returns boolean language sql as $$
  select pg_temp.cs() in ('no_longer_covered', 'open/take_fell_away')
$$;
-- Brief HD.md §3 conditions (1)–(3), read from the tables as the owner (no function of the code under test).
create function pg_temp.really_again() returns boolean language sql as $$
  select exists (select 1 from public.order_takes k where k.order_id = pg_temp.o() and k.released_at is not null)
     and not exists (select 1 from public.order_takes k where k.order_id = pg_temp.o() and k.released_at is null)
     and exists (select 1 from public.order_offers f
                 where f.order_id = pg_temp.o()
                   and f.round = (select max(f2.round) from public.order_offers f2 where f2.order_id = pg_temp.o())
                   and not exists (select 1 from public.order_declines d
                                   where d.order_id = f.order_id and d.round = f.round and d.team_id = f.team_id))
     and private.now() < private.order_latest_cover_at(pg_temp.o())
$$;

-- 1. Positive control: a real release (writer `remove_team_member`, ADR-199 (5)) ----------------------------------------
select is(pg_temp.take('01', '01', 'ffff0000-0000-4000-8160-000000000001') ->> 'result', 'ok', 'T1 takes the order with M1');
select pg_temp.act_as('00000000-0000-4000-a160-000000000009');
set local role authenticated;
select is(public.remove_team_member(pg_temp.t('01'), pg_temp.m('01'), 'Teamwechsel (synthetisch)',
                                    'ffff0000-0000-4000-8160-000000000002') ->> 'result', 'ok',
          'the admin removes M1 from T1; the take is released and round 2 is screened');
reset role;
select pg_temp.as_owner();
select ok(pg_temp.claims_again(), 'after a real release the client reads «Angebot geht wieder an alle passenden Teams»');
select ok(pg_temp.really_again(), 'positive control: and conditions (1)–(3) hold (released, open offer in round 2, before the deadline)');

-- 2. The safety net (ADR-199 (5)): a live take whose member no longer passes, on a path no trigger sees -----------------
select is(pg_temp.take('02', '03', 'ffff0000-0000-4000-8160-000000000003') ->> 'result', 'ok', 'T2 takes the order again with M3');
set local session_replication_role = replica;
delete from public.team_memberships where team_id = pg_temp.t('02') and user_id = pg_temp.m('03');
set local session_replication_role = origin;
select is((select count(*)::int from public.order_takes where order_id = pg_temp.o() and released_at is null), 1,
          'precondition: the take of M3 stays live (released_at null), so no new round is running');
-- Was RED on recovery/main 24ad2834: client_orders() read `no_longer_covered` → «Das Angebot geht wieder an alle
-- passenden Teams», although no release happened, every other team still gets `already_taken`, and no new round runs.
select is(pg_temp.cs(), 'no_longer_covered/no_offer_open', 'safety net (0161): «nicht mehr gedeckt», detail no_offer_open');
select ok(not pg_temp.claims_again() or pg_temp.really_again(),
          'HD.md §3: the client never reads «Angebot läuft wieder» while the take is live (safety net, FE-110 (b))');

-- 3. Unchanged neighbours: the time-based states of the safety net (pgTAP 142 §2) -------------------------------------
select set_config('navora.test_now', '2026-11-19 18:00:00+01', true);  -- starts_at − 240 min (PROPOSED lead)
select is(pg_temp.cs(), 'not_covered/cover_time_reached', 'at the latest coverage time the safety net reads not_covered');
select set_config('navora.test_now', '2026-11-19 22:00:00+01', true);
select is(pg_temp.cs(), 'not_covered/started', 'at the start it reads not_covered / started');

-- 4. The safety net without any command: a recorded contract end passes while the take is live -----------------------
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
delete from made;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
insert into made select public.confirm_client_order('00000000-0000-4000-a000-000000000460', date '2026-11-18', time '22:00',
  time '07:00', '4102', 'fage_efz', array['C1'], array['C1'], null, 'dddd0000-0000-4000-8160-000000000002');
reset role;
select pg_temp.as_owner();
select is(pg_temp.take('01', '02', 'ffff0000-0000-4000-8160-000000000004') ->> 'result', 'ok',
          'T1 takes a second order (Wed 22:00) with M2 while her access is still open');
select is(pg_temp.cs(), 'covered', 'the client reads «gedeckt»');
-- Her contract end is recorded after the take (Tue 17 Nov; access ends at the start of Wed 18 Nov, ADM2-13).
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.m('02'), null, date '2026-11-17', pg_temp.m('09'));
select set_config('navora.test_now', '2026-11-18 10:00:00+01', true);  -- the day after her contract end, before the deadline
select is(pg_temp.cs(), 'no_longer_covered/no_offer_open',
          'no command ran, the take is still live: «nicht mehr gedeckt · kein Angebot offen» (never «gedeckt», never «läuft wieder»)');
select ok(not pg_temp.claims_again() or pg_temp.really_again(),
          'HD.md §3 on the time-based path: no claim that the offer runs again while the take is live');

select * from finish();
rollback;
