-- BK-b2 (brief `docs/agents/briefs/BK.md`, slice BK-b2, PO amendment 2026-11-14 09:39 (2); draft ADR-196): the
-- qualification part of the hard filter, read per member, and the level-against-activity check at confirmation.
--
-- Red first (task rule 3): pushed alone as the first commit of the BK-b2 PR, stacked on PR #1268 (BK-b1). On the
-- BK-b1 head `f3b2a5c` it fails: the preview has no `level_activity_conflict` and no `conflict_activities` key (§1), and
-- the screening knows only the distance reasons, so every fixture team below is offered (§2-§4). The BK-b2 migration
-- turns it green.
--
-- What it guards:
--   * CGR-216 (a) (PO amendment 2026-11-13 21:39 (4)): the preview returns `level_activity_conflict` naming the
--     activity when the matrix cell (QAM-0.2, PROPOSED) for the chosen level is «-» or «?»; confirm refuses it and
--     writes no order. A «D» cell or an «E» cell is no conflict. CGR-216 (b) / CGR-205 (d): no mapping from a higher to
--     a lower level (a HF order with an activity whose HF cell is «E» passes; nothing maps AGS to FaGe or HF).
--   * CGR-204 (a) (PO amendment 2026-11-13 13:40 (1)): a team is offered only if ONE AND THE SAME active member passes
--     (1) the level: verified grade equal to the order's grade for the whole slot (self_confirmed never counts, QUAL1-3;
--     expiry inside the slot fails; a higher grade is not the ordered grade, CGR-205 (d)); (2) every activity: own
--     scope («E» with every required evidence verified), or «D» for an activity the client did not mark required;
--     a required activity needs own scope («confirmed attribute», draft ADR-196 (3), PROPOSED for `cra`); (3)
--     availability for the whole slot [start, end): no absence (ABS1) and no open visit overlapping it.
--     The negative of CGR-204: a team whose qualified member is unavailable and whose available member lacks the level
--     is never offered; a team that passes only by combining two members is never offered.
--   * Each excluded team carries one reason (the furthest step any member reached); BK-2n: every team exactly once.
--   * LEAVE1: a former member (access ended) is not an active member.
--   * AUT-117 (b) analogue: an absence recorded after confirmation leaves the existing offer and exclusion rows unchanged.
--   * P-5: the reason names a step, never a person.
-- Not here (PLANNED): the re-check at the take and at shift start and naming the member (BK-c / BK-5a, CGR-204 (b));
-- overlap with another taken order (BK-c); ranking (BK-3). The matrix cells stay PROPOSED (D-43); passing this file is
-- no clinical release.
-- Users: kundebs …9e8 (seed client of …3c1; here member of the fixture household …3c2, org S). Fixture: teams …b138-…01 to …0d and members …a138-…01 to
-- …0f of Testorganisation S (simulation), each team with service postcode 4102 and maximum 10 km (distance 0), so the
-- distance part passes and only the qualification part decides. Pinned clock: Fri 2026-11-13 12:00 Europe/Zurich.
-- Order slot: Sun 2026-11-22 22:00 – Mon 2026-11-23 07:00. Synthetic data only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
select set_config('navora.test_now', '2026-11-13 12:00:00+01', true);

-- Named fixture change (CGR-218 (A), PO 13:39 (2)): the plain QAM-0.2 table applies only to a `household` order, so this
-- file orders for a synthetic household account …3c2 (kundebs as member) instead of the seed home …3c1. The home and
-- hospital ward readings are pgTAP 139.
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003c2', '00000000-0000-4000-b000-000000000019', 'Haushalt Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003c2', '00000000-0000-4000-a000-0000000009e8');

-- 1. CGR-216: level against activity at preview and confirm ---------------------------------------------------------
create function pg_temp.pv(grade text, tags text[], req text[]) returns jsonb language sql as $$
  select public.preview_client_order('00000000-0000-4000-a000-0000000003c2', date '2026-11-22', time '22:00',
                                     time '07:00', '4102', grade, tags, req, null)
$$;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select ok((pg_temp.pv('ags_eba', array['B2'], '{}') -> 'problems') ? 'level_activity_conflict',
          'CGR-216 (a): AGS with B2 (cell «-») is a level_activity_conflict');
select is((pg_temp.pv('ags_eba', array['B2'], '{}') -> 'conflict_activities'), '["B2"]'::jsonb,
          'CGR-216 (a): the conflict names the activity');
select is((pg_temp.pv('fage_efz', array['B3H'], '{}') -> 'conflict_activities'), '["B3H"]'::jsonb,
          'CGR-216 (a): FaGe with B3H (cell «?», K-2) is a conflict');
select is((pg_temp.pv('ags_eba', array['C1', 'B3', 'B2'], '{}') -> 'conflict_activities'), '["B2", "B3"]'::jsonb,
          'CGR-216 (a): every conflicting activity is named, in matrix order; C1 («E») is not');
select ok(not ((pg_temp.pv('fage_efz', array['B1', 'C1'], '{}') -> 'problems') ? 'level_activity_conflict'),
          'a «D» cell (FaGe B1) and an «E» cell (FaGe C1) are no conflict');
select is((pg_temp.pv('fage_efz', array['B1', 'C1'], '{}') -> 'conflict_activities'), '[]'::jsonb,
          'no conflict → an empty list, never a missing key');
select ok(not ((pg_temp.pv('nurse_hf_fh', array['B2'], '{}') -> 'problems') ? 'level_activity_conflict'),
          'CGR-216 (b): HF with B2 (cell «E») passes; the level is read as ordered');
select is((public.confirm_client_order('00000000-0000-4000-a000-0000000003c2', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'ags_eba', array['B2'], array[]::text[], null,
           'dddd0000-0000-4000-8138-000000000001') ->> 'result'), 'invalid',
          'CGR-216 (a): confirm refuses an order with a level_activity_conflict');
reset role;
select is((select count(*)::int from public.partner_requests where client_account_id = '00000000-0000-4000-a000-0000000003c2'
             and grade = 'ags_eba' and activity_tags = array['B2']), 0, 'CGR-216 (a): no order row is written');

-- The fixture is written as the table owner with no request user (the 0120 evidence guard refuses any app user).
select set_config('request.jwt.claims', '', true), set_config('request.jwt.claim.sub', '', true);

-- Fixture (synthetic): teams of org S with reach 4102 / 10 km, members and their evidence --------------------------
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000001', 'B2 Fixture V1 geeignet', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000002', 'B2 Fixture V2 geteilt', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000003', 'B2 Fixture V3 selbst bestätigt', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000004', 'B2 Fixture V4 nur HF', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000005', 'B2 Fixture V5 ohne Mitglied', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000006', 'B2 Fixture V6 ehemalig', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000007', 'B2 Fixture V7 Abwesenheit danach', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000008', 'B2 Fixture V8 Abwesenheit zurückgezogen', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000009', 'B2 Fixture V9 HF mit Erfahrung', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-00000000000a', 'B2 Fixture V10 läuft ab', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-00000000000b', 'B2 Fixture V11 Einsatz', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-00000000000c', 'B2 Fixture V12 kombiniert', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-00000000000d', 'B2 Fixture V13 widersprüchlich', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b138-%';

insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a138-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'bk-b2-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03', '04', '05', '06', '07', '08', '09', '0a', '0b', '0c', '0d', '0e', '0f']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a138-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03', '04', '05', '06', '07', '08', '09', '0a', '0b', '0c', '0d', '0e', '0f']) n;
-- member → team: 01 V1 · 02, 03 V2 · 04 V3 · 05 V4 · (V5 none) · 06 V6 · 07 V7 · 08 V8 · 09 V9 · 0a V10 · 0b V11 ·
-- 0c, 0d V12 · 0e V13 · 0f V1 (a second, unavailable member of the eligible team; V1 stays offered through 01)
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b138-000000000001', '00000000-0000-4000-a138-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000001', '00000000-0000-4000-a138-00000000000f', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000002', '00000000-0000-4000-a138-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000002', '00000000-0000-4000-a138-000000000003', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000003', '00000000-0000-4000-a138-000000000004', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000004', '00000000-0000-4000-a138-000000000005', 'registered_nurse'),
  ('00000000-0000-4000-b138-000000000006', '00000000-0000-4000-a138-000000000006', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000007', '00000000-0000-4000-a138-000000000007', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000008', '00000000-0000-4000-a138-000000000008', 'care_assistant'),
  ('00000000-0000-4000-b138-000000000009', '00000000-0000-4000-a138-000000000009', 'registered_nurse'),
  ('00000000-0000-4000-b138-00000000000a', '00000000-0000-4000-a138-00000000000a', 'care_assistant'),
  ('00000000-0000-4000-b138-00000000000b', '00000000-0000-4000-a138-00000000000b', 'care_assistant'),
  ('00000000-0000-4000-b138-00000000000c', '00000000-0000-4000-a138-00000000000c', 'care_assistant'),
  ('00000000-0000-4000-b138-00000000000c', '00000000-0000-4000-a138-00000000000d', 'care_assistant'),
  ('00000000-0000-4000-b138-00000000000d', '00000000-0000-4000-a138-00000000000e', 'care_assistant');

-- Evidence as the synthetic fixture path writes it (table owner, no request user, no command; 0120 guard).
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000001', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-00000000000f', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000002', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000003', 'grade', 'ags_eba', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000004', 'grade', 'fage_efz', 'self_confirmed', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000005', 'grade', 'nurse_hf_fh', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000005', 'practice_licence', null, 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000006', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000007', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000008', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000009', 'grade', 'nurse_hf_fh', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000009', 'practice_licence', null, 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000009', 'experience_2y', null, 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-00000000000a', 'grade', 'fage_efz', 'verified', true,
   timestamptz '2026-11-23 03:00:00+01'),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-00000000000b', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-00000000000c', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-00000000000d', 'grade', 'ags_eba', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-00000000000e', 'grade', 'fage_efz', 'verified', true, null),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-00000000000e', 'grade', 'ags_eba', 'verified', true, null);

-- Availability facts (ABS1 rows carry no reason; UXR-192).
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by, withdrawn_at, withdrawn_by) values
  -- V2: the qualified member is away for the last two hours of the slot (whole slot, CGR-204 (a)).
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000002', '00000000-0000-4000-a138-000000000002',
   timestamptz '2026-11-23 05:00:00+01', timestamptz '2026-11-23 08:00:00+01', '00000000-0000-4000-a138-000000000002', null, null),
  -- V1: the second member is away for the whole night; the first one carries the team.
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000001', '00000000-0000-4000-a138-00000000000f',
   timestamptz '2026-11-22 20:00:00+01', timestamptz '2026-11-23 09:00:00+01', '00000000-0000-4000-a138-00000000000f', null, null),
  -- V7: an absence that starts exactly at the end of the slot ([start, end) is half open).
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000007', '00000000-0000-4000-a138-000000000007',
   timestamptz '2026-11-23 07:00:00+01', timestamptz '2026-11-23 12:00:00+01', '00000000-0000-4000-a138-000000000007', null, null),
  -- V8: an overlapping absence that was withdrawn.
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000008', '00000000-0000-4000-a138-000000000008',
   timestamptz '2026-11-22 21:00:00+01', timestamptz '2026-11-23 02:00:00+01', '00000000-0000-4000-a138-000000000008',
   timestamptz '2026-11-12 09:00:00+01', '00000000-0000-4000-a138-000000000008'),
  -- V12: the FaGe is away; the AGS is free (CGR-204: two members never combine).
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-00000000000c', '00000000-0000-4000-a138-00000000000c',
   timestamptz '2026-11-22 18:00:00+01', timestamptz '2026-11-23 10:00:00+01', '00000000-0000-4000-a138-00000000000c', null, null);
-- V11: an open visit of the member inside the slot (Mon 06:00–06:30).
insert into public.care_visits (organization_id, team_id, visit_date, time_start, time_end, status, responsible_user_id) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-00000000000b', date '2026-11-23', time '06:00',
   time '06:30', 'planned', '00000000-0000-4000-a138-00000000000b');
-- V6: LEAVE1, the member's access has ended.
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a138-000000000006', 'ended', 'employment_ended',
   '00000000-0000-4000-a138-000000000001');

-- 2. Orders ----------------------------------------------------------------------------------------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
-- F: FaGe, B1 («D») and C1 («E»), C1 required.
insert into made select 'f', public.confirm_client_order('00000000-0000-4000-a000-0000000003c2', date '2026-11-22',
  time '22:00', time '07:00', '4102', 'fage_efz', array['B1', 'C1'], array['C1'], null, 'dddd0000-0000-4000-8138-000000000010');
-- F2: FaGe, B1 required («D» is not own scope): refused at confirm since CGR-219 (one reading, PO 13:39 (3)).
insert into made select 'f2', public.confirm_client_order('00000000-0000-4000-a000-0000000003c2', date '2026-11-24',
  time '22:00', time '07:00', '4102', 'fage_efz', array['B1'], array['B1'], null, 'dddd0000-0000-4000-8138-000000000011');
-- H: HF, A3 («E», requires practice licence and two years' experience), required.
insert into made select 'h', public.confirm_client_order('00000000-0000-4000-a000-0000000003c2', date '2026-11-22',
  time '22:00', time '07:00', '4102', 'nurse_hf_fh', array['A3'], array['A3'], null, 'dddd0000-0000-4000-8138-000000000012');
reset role;
select is((select count(*)::int from made where r ->> 'result' = 'ok'), 2, 'the fixture orders F and H are confirmed');

create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
create function pg_temp.why(k text, team text) returns text language sql as $$
  select coalesce((select reason from public.order_exclusions where order_id = pg_temp.oid(k)
                     and team_id = ('00000000-0000-4000-b138-0000000000' || team)::uuid),
                  case when exists (select 1 from public.order_offers where order_id = pg_temp.oid(k)
                                      and team_id = ('00000000-0000-4000-b138-0000000000' || team)::uuid)
                       then 'offered' end)
$$;

-- 3. Order F: per-member level, activities, availability (CGR-204 (a)) ---------------------------------------------
select is(pg_temp.why('f', '01'), 'offered', 'V1: one verified FaGe, free for the whole slot → offered');
select is(pg_temp.why('f', '02'), 'no_member_available',
          'CGR-204: qualified member away for part of the slot, available member AGS → not offered');
select is(pg_temp.why('f', '0c'), 'no_member_available',
          'CGR-204: a team that passes only by combining two members is not offered');
select is(pg_temp.why('f', '03'), 'no_member_with_grade', 'QUAL1-3: a self-confirmed grade never counts');
select is(pg_temp.why('f', '04'), 'no_member_with_grade', 'CGR-205 (d): a HF is not the ordered FaGe (no mapping)');
select is(pg_temp.why('f', '05'), 'no_active_member', 'a team without members is not offered');
select is(pg_temp.why('f', '06'), 'no_active_member', 'LEAVE1: a former member is not an active member');
select is(pg_temp.why('f', '07'), 'offered', 'an absence starting exactly at the end of the slot leaves her available');
select is(pg_temp.why('f', '08'), 'offered', 'a withdrawn absence does not count');
select is(pg_temp.why('f', '0a'), 'no_member_with_grade', 'evidence that expires inside the slot does not cover it');
select is(pg_temp.why('f', '0b'), 'no_member_available', 'an open visit of the member inside the slot makes her unavailable');
select is(pg_temp.why('f', '0d'), 'no_member_with_grade', 'two grade records that disagree (contradictory) never count');
select is((select count(*)::int from public.teams t
           where t.organization_id = '00000000-0000-4000-b000-000000000019'
             and (select count(*) from public.order_offers o where o.order_id = pg_temp.oid('f') and o.team_id = t.id)
               + (select count(*) from public.order_exclusions x where x.order_id = pg_temp.oid('f') and x.team_id = t.id)
               <> 1), 0, 'BK-2n: every team of the organisation is offered or excluded exactly once');
select is((select count(*)::int from public.order_offers o
           join public.order_exclusions x on x.order_id = o.order_id and x.team_id = o.team_id), 0,
          'BK-2n: no team is both offered and excluded');

-- 4. Required activities need own scope; evidence the cell requires (draft ADR-196 (3)) ----------------------------
select is((select r -> 'conflict_activities' from made where k = 'f2'), '["B1"]'::jsonb,
          'CGR-219: a required activity whose cell is «D» (FaGe B1) is refused at confirm, B1 named (was: confirmed, then no team)');
select is(pg_temp.why('h', '04'), 'no_member_activity_evidence',
          'HF A3 needs two years'' experience verified; licence alone → not offered');
select is(pg_temp.why('h', '09'), 'offered', 'HF with licence and experience verified, free → offered');
select is(pg_temp.why('h', '01'), 'no_member_with_grade', 'a FaGe team is not offered a HF order');

-- 5. Rows are written once (AUT-117 (b) analogue) -------------------------------------------------------------------
create temp table before_change as
  select 'o' as k, order_id, team_id, '' as v from public.order_offers
  union all select 'x', order_id, team_id, reason from public.order_exclusions;
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b138-000000000001', '00000000-0000-4000-a138-000000000001',
   timestamptz '2026-11-22 21:00:00+01', timestamptz '2026-11-23 08:00:00+01', '00000000-0000-4000-a138-000000000001');
select is((select count(*)::int from (
             (select 'o', order_id, team_id, '' from public.order_offers
              union all select 'x', order_id, team_id, reason from public.order_exclusions)
             except select * from before_change) d), 0,
          'an absence recorded after confirmation changes no offer or exclusion row (re-check at the take: BK-c)');

-- 6. Schema facts ---------------------------------------------------------------------------------------------------
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name in ('order_offers', 'order_exclusions')
             and column_name ~ '(user|member|person|actor)'), 0, 'P-5: still no person column on offer or exclusion rows');
select ok((select pg_get_constraintdef(c.oid) from pg_constraint c
           where c.conrelid = 'public.order_exclusions'::regclass and c.contype = 'c'
             and pg_get_constraintdef(c.oid) like '%reason%') like '%no_member_available%',
          'the reason check lists the BK-b2 reasons');
select ok(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and p.proname ~ 'member_eligib'),
          'the per-member check is private: no public function exposes who is eligible');

-- 7. Client view unchanged ------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select is((select count(*)::int from public.order_exclusions), 0, 'ADR-192 (3): the client reads no exclusion row');
reset role;
select pg_temp.act_as('00000000-0000-4000-a138-000000000003');
set local role authenticated;
select is((select count(*)::int from public.order_offers where order_id = pg_temp.oid('f')), 0,
          'a member of an excluded team (V2) reads no offer row of another team');
reset role;

select * from finish();
rollback;
