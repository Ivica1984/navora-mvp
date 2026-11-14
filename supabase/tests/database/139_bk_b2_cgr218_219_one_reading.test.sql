-- BK-b2, merge conditions of PR #1273 (brief `docs/agents/briefs/BK.md` §PO amendment 2026-11-14 13:39 (2), (3);
-- `cra` 13:30 CGR-218, CGR-219; ADR-196 amendment 14:10).
--
-- Red first (task rule 3): committed before the code on the #1273 branch. On head `4b8a158` it fails: the matrix cell is
-- read without the client kind (a FaGe with B1 on a `home` order is confirmed), a required «D» is accepted at confirm,
-- there is no `conflict_reading` key and no `private.member_activity_ok`.
--
-- What it guards:
--   * CGR-218 (A) (PO 13:39 (2)): until the Clinical Owner decides CR-180 (PROPOSED), the cell is read in the
--     strictest context that fits the client kind: `household` the plain QAM-0.2 table; `home` (NH-EXT) every «D» and
--     every «E» in a row B* as «?» (QUALIFICATION_MATRIX.md §4.2 «Context modifiers»); `hospital_ward` (HOSP-IN) every
--     row «?». A «?» counts as «-» in every phase (CR-179). Tests from `cra`: FaGe B1 on `home` refused at confirm, B1
--     named, no order row; HF B7 on `home` refused; any `hospital_ward` order with an activity refused; FaGe B1 on
--     `household` read by the plain table; `home` AGS C1 confirmed and offered.
--   * CGR-219 (PO 13:39 (3)): confirm check and member step use ONE reading. A required activity whose cell is «D» can
--     be passed by no member, so confirm refuses it naming the activity; not required it is confirmed (plain table).
--     Consistency over every client kind × grade × activity of QAM-0.2 × required/not: «confirm accepts» holds exactly
--     when a member of that grade with every evidence verified passes the activity step.
-- No clinical rule is set or confirmed here: the cells and CR-180 stay PROPOSED; the PO chose the stricter of two
-- `cra` review positions (D-27). Passing this file is no clinical release.
-- Users: kundebs …9e8 (seed client of «Testheim Rhein», kind `home`, …3c1). Fixture (synthetic, Testorganisation S,
-- simulation): client accounts …3c2 (`household`) and …3c3 (`hospital_ward`) with kundebs as member; team …b139-01 with
-- reach 4102 / 10 km and three members …a139-01 (AGS), -02 (FaGe), -03 (HF), each with every evidence verified.
-- Pinned clock: Fri 2026-11-13 12:00 Europe/Zurich. Everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(21);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
select set_config('navora.test_now', '2026-11-13 12:00:00+01', true);

-- Fixture as the table owner, no request user (0120 evidence guard) ------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003c2', '00000000-0000-4000-b000-000000000019', 'Haushalt Fixture (synthetisch)', 'household'),
  ('00000000-0000-4000-a000-0000000003c3', '00000000-0000-4000-b000-000000000019', 'Spitalstation Fixture (synthetisch)', 'hospital_ward');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003c2', '00000000-0000-4000-a000-0000000009e8'),
  ('00000000-0000-4000-a000-0000000003c3', '00000000-0000-4000-a000-0000000009e8');

insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b139-000000000001', 'CGR-218 Fixture alle Nachweise', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values ('00000000-0000-4000-b139-000000000001', '4102');
insert into auth.users (id, aud, role, email)
  select ('00000000-0000-4000-a139-0000000000' || n)::uuid, 'authenticated', 'authenticated', 'cgr218-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', ('00000000-0000-4000-a139-0000000000' || n)::uuid, 'nurse'
  from unnest(array['01', '02', '03']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b139-000000000001', '00000000-0000-4000-a139-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b139-000000000001', '00000000-0000-4000-a139-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b139-000000000001', '00000000-0000-4000-a139-000000000003', 'registered_nurse');
create temp table member_grade (user_id uuid primary key, grade text not null);
insert into member_grade values
  ('00000000-0000-4000-a139-000000000001', 'ags_eba'),
  ('00000000-0000-4000-a139-000000000002', 'fage_efz'),
  ('00000000-0000-4000-a139-000000000003', 'nurse_hf_fh');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019'::uuid, m.user_id, 'grade', m.grade, 'verified', true, null::timestamptz
  from member_grade m
  union all
  select '00000000-0000-4000-b000-000000000019'::uuid, m.user_id, r, null, 'verified', true, null
  from member_grade m
  cross join unnest(array['practice_licence', 'experience_2y', 'experience_psych_2y', 'instruction_record']) r;

create function pg_temp.pv(acct text, grade text, tags text[], req text[]) returns jsonb language sql as $$
  select public.preview_client_order(('00000000-0000-4000-a000-0000000003' || acct)::uuid, date '2026-11-22',
                                     time '22:00', time '07:00', '4102', grade, tags, req, null)
$$;
create function pg_temp.cf(acct text, grade text, tags text[], req text[], k text) returns jsonb language sql as $$
  select public.confirm_client_order(('00000000-0000-4000-a000-0000000003' || acct)::uuid, date '2026-11-22',
                                     time '22:00', time '07:00', '4102', grade, tags, req, null,
                                     ('dddd0000-0000-4000-8139-0000000000' || k)::uuid)
$$;
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;

select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;

-- 1. CGR-218 (A): `home` read as NH-EXT ------------------------------------------------------------------------------
insert into made select 'home_fage_b1', pg_temp.cf('c1', 'fage_efz', array['B1'], '{}', '01');
select is((select r ->> 'result' from made where k = 'home_fage_b1'), 'invalid',
          'CGR-218 (A): FaGe with B1 («D») on a home order is refused at confirm');
select is((select r -> 'conflict_activities' from made where k = 'home_fage_b1'), '["B1"]'::jsonb,
          'CGR-218 (A): the refusal names B1');
insert into made select 'home_hf_b7', pg_temp.cf('c1', 'nurse_hf_fh', array['B7'], '{}', '02');
select is((select r -> 'conflict_activities' from made where k = 'home_hf_b7'), '["B7"]'::jsonb,
          'CGR-218 (A): HF with B7 («E» in a row B*) on a home order is refused, B7 named');
select is((pg_temp.pv('c1', 'nurse_hf_fh', array['A3'], '{}') -> 'conflict_activities'), '[]'::jsonb,
          'CGR-218 (A): an «E» outside the rows B* (HF A3) stays own scope on a home order');
select is((pg_temp.pv('c1', 'fage_efz', array['B1'], '{}') ->> 'conflict_reading'), 'nh_ext_strict',
          'the preview names the reading it used for a home order');
insert into made select 'home_ags_c1', pg_temp.cf('c1', 'ags_eba', array['C1'], '{}', '03');
select is((select r ->> 'result' from made where k = 'home_ags_c1'), 'ok',
          'CGR-218 (A): AGS with C1 («E», not a row B*) on a home order is confirmed');

-- 2. CGR-218 (A): `hospital_ward` read as HOSP-IN ----------------------------------------------------------------------
insert into made select 'hosp_ags_c1', pg_temp.cf('c3', 'ags_eba', array['C1'], '{}', '04');
select is((select r ->> 'result' from made where k = 'hosp_ags_c1'), 'invalid',
          'CGR-218 (A): a hospital ward order with C1 is refused (every row «?»)');
select is((select r -> 'conflict_activities' from made where k = 'hosp_ags_c1'), '["C1"]'::jsonb,
          'CGR-218 (A): the hospital ward refusal names the activity');
select is((select count(*)::int from unnest(array['ags_eba', 'fage_efz', 'nurse_hf_fh']) g
           cross join public.qual_activities q
           where not ((pg_temp.pv('c3', g, array[q.code], '{}') -> 'problems') ? 'level_activity_conflict')), 0,
          'CGR-218 (A): no grade with any activity is orderable for a hospital ward');
select is((pg_temp.pv('c3', 'ags_eba', array['C1'], '{}') ->> 'conflict_reading'), 'hosp_in_strict',
          'the preview names the hospital ward reading');

-- 3. `household`: the plain table, with CGR-219 ------------------------------------------------------------------------
insert into made select 'hh_fage_b1', pg_temp.cf('c2', 'fage_efz', array['B1'], '{}', '05');
select is((select r ->> 'result' from made where k = 'hh_fage_b1'), 'ok',
          'household: FaGe with B1 not required («D») is confirmed by the plain table');
select is((pg_temp.pv('c2', 'fage_efz', array['B1'], '{}') ->> 'conflict_reading'), 'plain',
          'the preview names the plain reading for a household');
insert into made select 'hh_fage_b1_req', pg_temp.cf('c2', 'fage_efz', array['B1'], array['B1'], '06');
select is((select r ->> 'result' from made where k = 'hh_fage_b1_req'), 'invalid',
          'CGR-219: FaGe with B1 marked required («D», no own scope) is refused at confirm');
select is((select r -> 'conflict_activities' from made where k = 'hh_fage_b1_req'), '["B1"]'::jsonb,
          'CGR-219: the refusal names B1');
reset role;
select is((select count(*)::int from public.partner_requests
           where client_account_id in ('00000000-0000-4000-a000-0000000003c1', '00000000-0000-4000-a000-0000000003c2',
                                       '00000000-0000-4000-a000-0000000003c3')), 2,
          'only the two accepted orders (home AGS C1, household FaGe B1) wrote an order row');
select is((select count(*)::int from made where r ->> 'result' = 'invalid' and r ? 'order_id'), 0,
          'no refused order returns an order id');

-- 4. Accepted orders reach the fully evidenced member ----------------------------------------------------------------
select is((select count(*)::int from public.order_offers
           where order_id = (select (r ->> 'order_id')::uuid from made where k = 'home_ags_c1')
             and team_id = '00000000-0000-4000-b139-000000000001'), 1,
          'home AGS C1: the team with a fully evidenced AGS is offered');
select is((select count(*)::int from public.order_offers
           where order_id = (select (r ->> 'order_id')::uuid from made where k = 'hh_fage_b1')
             and team_id = '00000000-0000-4000-b139-000000000001'), 1,
          'household FaGe B1 not required: the team with a fully evidenced FaGe is offered');

-- 5. CGR-219 consistency: one reading for confirm and member step -----------------------------------------------------
create temp table grid as
  select k.kind, g.grade, q.code, rq.req,
         case k.kind when 'home' then 'c1' when 'household' then 'c2' else 'c3' end as acct,
         (select m.user_id from member_grade m where m.grade = g.grade) as member
  from (values ('home'), ('household'), ('hospital_ward')) k (kind)
  cross join (values ('ags_eba'), ('fage_efz'), ('nurse_hf_fh')) g (grade)
  cross join public.qual_activities q
  cross join (values (false), (true)) rq (req);
grant all on grid to authenticated;
alter table grid add column accepts boolean, add column passes boolean;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
update grid set accepts = not ((pg_temp.pv(acct, grade, array[code], case when req then array[code] else '{}' end)
                                -> 'problems') ? 'level_activity_conflict');
reset role;
update grid set passes = private.member_activity_ok('00000000-0000-4000-b000-000000000019', member, kind, grade,
                                                    array[code], case when req then array[code] else '{}' end,
                                                    timestamptz '2026-11-23 07:00:00+01');
select is((select count(*)::int from grid), 3 * 3 * (select count(*)::int from public.qual_activities) * 2,
          'the grid covers every client kind × grade × activity × required');
select is((select count(*)::int from grid where accepts and not passes), 0,
          'CGR-219: whatever confirm accepts, a member of that grade with every evidence verified can pass');
select is((select count(*)::int from grid where passes and not accepts), 0,
          'one reading: whatever such a member passes, confirm accepts (no hidden second rule)');

select * from finish();
rollback;
