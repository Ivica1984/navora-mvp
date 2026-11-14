-- BK-b (brief `docs/agents/briefs/BK.md`, slice BK-b; ADR-193, draft ADR-195): postcode distances, the team's own
-- reach and the distance hard filter on offer rows.
--
-- PROBE, red first (task rule 3; FE-071: BK-b is not active until BK-a is accepted, so this file lives on the unmerged
-- probe branch `probe/bk-b-red-20261114` and is not part of any PR yet). On `recovery/main` `0f33ba3` it fails at its
-- first statement that reads `public.postcode_distances` (the table does not exist). The BK-b migration turns it green.
--
-- What it guards:
--   * ADR-193 (1), (2), `lca` P-8: the distance table holds only places and distances, is symmetric, 0 to itself,
--     references only listed postcodes; `authenticated` writes neither it nor the service-area table; no street or
--     coordinate column;
--   * AUT-117 (a): one audited command `set_team_reach` sets a team's service postcodes and maximum distance; an
--     active member of that team may call it; a member of another team may not; an organisation `admin` only for a
--     team without active members; postcodes only from the list; distance > 0;
--   * AUT-117 (d): every change writes one audit row with old and new values; after seed setup no team of org S is
--     without reach (scenario matrix count = 0);
--   * PO 18:40 (1)(c), (d) / BK-2, BK-2n: an order without radius reaches a team whose maximum covers the distance;
--     a team whose maximum is 1 km short is excluded `outside_radius`; a client radius smaller than the team's
--     maximum excludes the team; a team without service postcode → `no_service_area`, without maximum →
--     `no_max_distance`; distance = minimum over the team's service postcodes (ADR-193 (3)); an excluded team has no
--     offer row; every screened team appears exactly once (offer or exclusion);
--   * AUT-117 (b): a reach change after confirmation leaves the existing offer and exclusion rows unchanged;
--   * ADR-192 (3): the client reads no offer or exclusion row;
--   * CGR-217: the preview returns an information item (never a problem) when the same client account already has a
--     confirmed order with the same start, end, grade and postcode; a different postcode gives no item; the second
--     order stays confirmable.
-- Not here (PLANNED, second BK-b PR, own red tests): CGR-204 per-member level, confirmed required attributes and
-- availability for the whole slot; CGR-216 `level_activity_conflict`; AUT-122 / K-6 reach-change counts per team.
-- Distances: set by this file on fixture pairs (synthetic, inside the transaction); they state nothing about real
-- distances. Users (seed): kundebs …9e8 (client A, org S) · pflegebs …9e6 (nurse, member of Testteam Basel …1b9).
-- Fixture: nurse …9eb (member of fixture team T2 only), admin of org S …9ea. Pinned clock: Fri 2026-11-13 12:00
-- Europe/Zurich. Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(43);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
select set_config('navora.test_now', '2026-11-13 12:00:00+01', true);

-- 1. Schema facts ---------------------------------------------------------------------------------------------------
select has_table('public', 'postcode_distances', 'ADR-193 (1): postcode_distances exists');
select has_table('public', 'team_service_postcodes', 'ADR-193 (3): team_service_postcodes exists');
select has_column('public', 'teams', 'max_distance_km', 'ADR-193 (4): teams.max_distance_km exists');
select has_column('public', 'teams', 'reach_changed_at', 'AUT-117 (c): the date of the last reach change is stored');
select has_table('public', 'order_offers', 'BK-2n: offer rows exist');
select has_table('public', 'order_exclusions', 'BK-2: each excluded team carries its reason');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public'
             and table_name in ('postcode_distances', 'team_service_postcodes', 'order_offers', 'order_exclusions')
             and column_name ~ '(street|strasse|address|lat|lon|coord|gps)'), 0,
          'P-4, P-8: no street, coordinate or GPS column');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name in ('order_offers', 'order_exclusions')
             and column_name ~ '(user|member|person|actor)'), 0,
          'P-5: offer and exclusion rows name a team, never a person');

-- 2. The distance table (ADR-193 (1), (2)) --------------------------------------------------------------------------
select is((select count(*)::int from public.postcode_distances d
           where not exists (select 1 from public.postcode_distances r
                             where r.from_postcode = d.to_postcode and r.to_postcode = d.from_postcode
                               and r.distance_km = d.distance_km)), 0, 'the distance table is symmetric');
select is((select count(*)::int from public.postcode_distances
           where from_postcode = to_postcode and distance_km <> 0), 0, 'distance 0 from a postcode to itself');
select is((select count(*)::int from public.postcodes a cross join public.postcodes b
           where not exists (select 1 from public.postcode_distances d
                             where d.from_postcode = a.postcode and d.to_postcode = b.postcode)), 0,
          'every listed pair has a distance (no team is excluded for a missing pair)');
select is((select count(*)::int from public.postcode_distances d
           where not exists (select 1 from public.postcodes p where p.postcode = d.from_postcode)
              or not exists (select 1 from public.postcodes p where p.postcode = d.to_postcode)), 0,
          'no distance row for a postcode outside the list');

select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
set local role authenticated;
select throws_ok($$ insert into public.postcode_distances (from_postcode, to_postcode, distance_km)
                    values ('4051', '4051', 0) $$, '42501', null, 'authenticated cannot write postcode_distances');
select throws_ok($$ insert into public.team_service_postcodes (team_id, postcode)
                    values ('00000000-0000-4000-a000-0000000001b9', '4051') $$, '42501', null,
                 'authenticated cannot write team_service_postcodes directly (only through set_team_reach)');
reset role;

-- 3. Seed setup: every team of org S has a reach (AUT-117 (d) scenario count) ---------------------------------------
select is((select count(*)::int from public.teams t
           where t.organization_id = '00000000-0000-4000-b000-000000000019'
             and (t.max_distance_km is null
                  or not exists (select 1 from public.team_service_postcodes s where s.team_id = t.id))), 0,
          'AUT-117 (d): after seed setup no team of org S is excluded for no_service_area / no_max_distance');

-- Fixture: users, teams and distances (synthetic) ------------------------------------------------------------------
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-4000-a000-0000000009ea', 'authenticated', 'authenticated', 'adminbs.fixture@navora.test'),
  ('00000000-0000-4000-a000-0000000009eb', 'authenticated', 'authenticated', 'pflegebs2.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000009ea', 'admin'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000009eb', 'nurse');
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000001ba', 'Fixture T2 (synthetisch)', 'Basel-Stadt', 'active'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000001bb', 'Fixture T3 (synthetisch)', 'Basel-Stadt', 'active'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000001bc', 'Fixture T4 (synthetisch)', 'Basel-Stadt', 'active'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000001bd', 'Fixture T5 (synthetisch)', 'Basel-Stadt', 'active'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000001be', 'Fixture T6 (synthetisch)', 'Basel-Landschaft', 'active');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-0000000001ba', '00000000-0000-4000-a000-0000000009eb', 'registered_nurse');

create function pg_temp.set_dist(a text, b text, km numeric) returns void language sql as $$
  update public.postcode_distances set distance_km = km
   where (from_postcode, to_postcode) in ((a, b), (b, a));
$$;
select pg_temp.set_dist('4052', '4102', 3);
select pg_temp.set_dist('4051', '4102', 5);
select pg_temp.set_dist('4410', '4102', 15);
select pg_temp.set_dist('4123', '4102', 2);
select pg_temp.set_dist('4057', '4102', 9);

-- 4. set_team_reach: who may set it (AUT-117 (a)) -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
set local role authenticated;
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001b9', array['4052'], 10,
           'cccc0000-0000-4000-8000-000000000001') ->> 'result'), 'ok', 'a member of team 1b9 sets 1b9''s reach');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-0000000009eb');
set local role authenticated;
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001b9', array['4051'], 50,
           'cccc0000-0000-4000-8000-000000000002') ->> 'result'), 'rejected', 'a member of team T2 cannot set 1b9''s reach');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001ba', array['4051'], 6,
           'cccc0000-0000-4000-8000-000000000003') ->> 'result'), 'ok', 'the member of T2 sets T2''s reach');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001ba', array['9999'], 6,
           'cccc0000-0000-4000-8000-000000000004') -> 'problems'), '["postcode_not_in_list"]'::jsonb,
          'P-8: a postcode outside the list is refused');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001ba', array['4051'], 0,
           'cccc0000-0000-4000-8000-000000000005') -> 'problems'), '["max_distance_not_positive"]'::jsonb,
          'a maximum distance of 0 is refused');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001ba', array[]::text[], 6,
           'cccc0000-0000-4000-8000-000000000006') -> 'problems'), '["missing_service_postcode"]'::jsonb,
          'an empty service area is refused (no silent removal of the team from every order)');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-0000000009ea');
set local role authenticated;
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001ba', array['4051'], 60,
           'cccc0000-0000-4000-8000-000000000007') ->> 'result'), 'rejected',
          'AUT-117 (a): an admin cannot set the reach of a team with active members');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001bb', array['4051'], 4,
           'cccc0000-0000-4000-8000-000000000008') ->> 'result'), 'ok',
          'AUT-117 (a): an admin sets the reach of a team without active members');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001be', array['4410', '4123'], 3,
           'cccc0000-0000-4000-8000-000000000009') ->> 'result'), 'ok', 'a team may hold several service postcodes');
reset role;

-- Fixture teams with a missing part (written directly, as a broken seed would leave them).
update public.teams set max_distance_km = 10 where id = '00000000-0000-4000-a000-0000000001bc';
insert into public.team_service_postcodes (team_id, postcode) values ('00000000-0000-4000-a000-0000000001bd', '4051');

-- 5. Audit (AUT-117 (d)) --------------------------------------------------------------------------------------------
select is((select count(*)::int from public.audit_events
           where command = 'set_team_reach' and table_name = 'teams'), 4, 'one audit row per accepted change, none for a refusal');
select ok((select changed -> 'max_distance_km' = jsonb_build_object('old', null, 'new', 6)
             and changed -> 'service_postcodes' = jsonb_build_object('old', '[]'::jsonb, 'new', '["4051"]'::jsonb)
           from public.audit_events
           where command = 'set_team_reach' and entity_id = '00000000-0000-4000-a000-0000000001ba'),
          'the audit row carries old and new values of distance and postcodes');
select ok((select reach_changed_at = private.now() from public.teams where id = '00000000-0000-4000-a000-0000000001ba'),
          'AUT-117 (c): the date of the last change is stored');
select throws_ok($$ update public.teams set max_distance_km = 0 where id = '00000000-0000-4000-a000-0000000001ba' $$,
                 '23514', null, 'check: max_distance_km > 0');

-- 6. Hard filter on confirmation (BK-2, BK-2n, PO 18:40 (1)(c), (d)) -----------------------------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
insert into made select 'o1', public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22',
  time '22:00', time '07:00', '4102', 'fage_efz', array['B1'], array[]::text[], null,
  'cccc0000-0000-4000-8000-000000000010');
insert into made select 'o2', public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-23',
  time '22:00', time '07:00', '4102', 'fage_efz', array['B1'], array[]::text[], 4,
  'cccc0000-0000-4000-8000-000000000011');
select is((select count(*)::int from public.order_offers), 0, 'ADR-192 (3): the client reads no offer row');
select is((select count(*)::int from public.order_exclusions), 0, 'ADR-192 (3): the client reads no exclusion row');
reset role;

create temp view screen as
  select (select (r ->> 'order_id')::uuid from made where k = 'o1') as o1,
         (select (r ->> 'order_id')::uuid from made where k = 'o2') as o2;

select is((select array_agg(team_id::text order by team_id) from public.order_offers where order_id = (select o1 from screen)),
          array['00000000-0000-4000-a000-0000000001b9', '00000000-0000-4000-a000-0000000001ba',
                '00000000-0000-4000-a000-0000000001be'],
          'order without radius: offered are 1b9 (3 km of 10), T2 (5 of 6), T6 (min(15, 2) = 2 of 3)');
select is((select distance_km from public.order_offers
           where order_id = (select o1 from screen) and team_id = '00000000-0000-4000-a000-0000000001be'), 2::numeric,
          'ADR-193 (3): distance is the minimum over the team''s service postcodes');
select is((select reason from public.order_exclusions
           where order_id = (select o1 from screen) and team_id = '00000000-0000-4000-a000-0000000001bb'), 'outside_radius',
          'PO 18:40 (1)(d): a team whose maximum is 1 km short (4 of 5) is excluded');
select is((select reason from public.order_exclusions
           where order_id = (select o1 from screen) and team_id = '00000000-0000-4000-a000-0000000001bc'), 'no_service_area',
          'a team without service postcode is excluded with its reason');
select is((select reason from public.order_exclusions
           where order_id = (select o1 from screen) and team_id = '00000000-0000-4000-a000-0000000001bd'), 'no_max_distance',
          'a team without maximum distance gets no offer row and carries its reason');
select is((select count(*)::int from public.teams t
           where t.organization_id = '00000000-0000-4000-b000-000000000019'
             and (select count(*) from public.order_offers o where o.order_id = (select o1 from screen) and o.team_id = t.id)
               + (select count(*) from public.order_exclusions x where x.order_id = (select o1 from screen) and x.team_id = t.id)
               <> 1), 0, 'BK-2n: every team of the organisation is either offered or excluded, never both, never missing');
select is((select array_agg(team_id::text order by team_id) from public.order_offers where order_id = (select o2 from screen)),
          array['00000000-0000-4000-a000-0000000001b9', '00000000-0000-4000-a000-0000000001be'],
          'client radius 4: T2 (5 km, maximum 6) is excluded; 1b9 (3) and T6 (2) stay');
select is((select reason from public.order_exclusions
           where order_id = (select o2 from screen) and team_id = '00000000-0000-4000-a000-0000000001ba'), 'outside_radius',
          'PO 18:40 (1)(c): the smaller of team maximum and client radius applies');

-- 7. A reach change applies to new offers only (AUT-117 (b)) --------------------------------------------------------
create temp table before_change as
  select 'o' as k, order_id, team_id, distance_km::text as v from public.order_offers
  union all select 'x', order_id, team_id, reason from public.order_exclusions;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009eb');
set local role authenticated;
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001ba', array['4057'], 6,
           'cccc0000-0000-4000-8000-000000000012') ->> 'result'), 'ok', 'T2 moves its service area to 4057 (9 km)');
reset role;
select is((select count(*)::int from (
             select * from before_change
             except
             (select 'o', order_id, team_id, distance_km::text from public.order_offers
              union all select 'x', order_id, team_id, reason from public.order_exclusions)) d), 0,
          'AUT-117 (b): existing offer and exclusion rows are not altered or withdrawn');

-- 8. CGR-217: the same order twice is an information item, never a block -------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], array[]::text[], null) -> 'info'),
          '["same_order_already_confirmed"]'::jsonb, 'CGR-217: same start, end, grade and postcode → information item');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4051', 'fage_efz', array['B1'], array[]::text[], null) -> 'info'),
          '[]'::jsonb, 'CGR-217: a different postcode gives no item');
select is((select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], array[]::text[], null,
           'cccc0000-0000-4000-8000-000000000013') ->> 'result'), 'ok', 'CGR-217: the second order stays confirmable');
reset role;

select * from finish();
rollback;
