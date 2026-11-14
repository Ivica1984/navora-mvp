-- BK-a (brief `docs/agents/briefs/BK.md`, slice BK-a; ADR-191, ADR-192, ADR-194): the client's shift order.
--
-- Written BEFORE the migration (red first, task rule 3): on `recovery/main` `cdf79fc` this file fails at its first
-- statement that reads `public.client_accounts` (the table does not exist yet). Migration 0129 turns it green.
--
-- What it guards:
--   * the client is a separate account, never an organisation member (ADR-192 (1), (2)); a client-only user reads no
--     row of any table in `public` except the reference lists (postcodes, activity list, matrix), and no
--     `partner_requests` row (ADR-192 (3));
--   * nothing exists before «Bestätigen & Absenden» (BK-1d): the preview writes no row;
--   * BK-1b: no default fills a required field; every missing field is named; a tag outside the list, a required tag
--     not among the tags, a postcode outside the list, an unknown grade, a start in the past, a zero duration and a
--     radius <= 0 are refused by code;
--   * BK-1c / CGR-206 (a): 22:00–07:00 is ONE row of 540 minutes, start date + end next day;
--   * PO 18:40 (2): the shift label comes only from the client's own plan and steers nothing; no label when no plan
--     entry matches, and the order is still valid; changing the plan changes no stored order fact;
--   * UXR-196: the built sentence uses the form's labels, no code, no ISO date, no `_`;
--   * ADR-191 (3), `lca` P-7: no caller-supplied text is stored (no text parameter in the command signature);
--   * AUT-119 (a): no price column on the order;
--   * BK-1n: a nurse, Operations and an admin of the same organisation cannot confirm; client A never sees B's order;
--   * idempotency: the same key twice writes one row; the confirmed order creates no case and no team search, and the
--     Operations intake list (status open / ready_to_convert) and «Fall eröffnen» do not take it;
--   * every confirmed order writes one audit row;
--   * CGR-206 (d) (BK amendment 2026-11-13 21:39 (2)): the stored duration follows the clock change. Night Sat
--     30.10.2027 22:00 – Sun 31.10.2027 07:00 = 600 min «(10 Std.)»; night Sat 27.03.2027 22:00 – Sun 28.03.2027 07:00
--     = 480 min «(8 Std.)»; a start of 02:30 on 28.03.2027 (a wall-clock time that does not exist) is shown as 03:30 in
--     the preview before confirmation (DST1 / ADR-081 reading), never shifted silently after it. Dates are calendar
--     facts, not rules. Added after the migration: the code already computed this, so these assertions were green on
--     first run (they guard against a regression; they were not red first).
-- Users (seed): kundebs …9e8 (client of «Testheim Rhein (synthetisch)», org S) · opsbs …9e5 (operations, org S) ·
-- pflegebs …9e6 (nurse, org S). Fixture in this file: client account B with user …9e9, admin of org S …9ea.
-- Pinned clock (private.test_clock): Friday 2026-11-13 12:00 Europe/Zurich. Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(56);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Pinned clock (the seed enables private.test_clock; migration 0067).
select set_config('navora.test_now', '2026-11-13 12:00:00+01', true);

-- Fixture: a second client account in org S with its own user, and an admin of org S.
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-4000-a000-0000000009e9', 'authenticated', 'authenticated', 'kundeb.fixture@navora.test'),
  ('00000000-0000-4000-a000-0000000009ea', 'authenticated', 'authenticated', 'adminbs.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000009ea', 'admin');
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003c2', '00000000-0000-4000-b000-000000000019', 'Testspital Birs (synthetisch)', 'hospital_ward');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003c2', '00000000-0000-4000-a000-0000000009e9');

-- 1. Schema facts ---------------------------------------------------------------------------------------------------
select has_table('public', 'client_accounts', 'client_accounts exists');
select has_table('public', 'client_account_members', 'client_account_members exists');
select has_table('public', 'client_shift_plans', 'client_shift_plans exists');
select has_table('public', 'postcodes', 'postcodes exists');
select hasnt_column('public', 'partner_requests', 'price_per_hour', 'AUT-119 (a): BK-a builds no price column');
select is((select count(*)::int from public.postcodes where source = 'synthetic'),
          (select count(*)::int from public.postcodes), 'every seeded postcode is marked synthetic');
select is((select count(*)::int from public.postcodes p
           where p.region_name not in ('Basel-Stadt', 'Basel-Landschaft')), 0, 'postcodes only in BS/BL (FE-019)');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name in ('postcodes', 'client_shift_plans', 'client_accounts')
             and column_name ~ '(street|strasse|address|lat|lon|coord)'), 0, 'no street or coordinate column (P-8)');
select is((select count(*)::int from pg_proc p, unnest(p.proargtypes) with ordinality t(oid, i)
           where p.proname = 'confirm_client_order' and p.pronamespace = 'public'::regnamespace
             and format_type(t.oid, null) in ('text', 'character varying', 'jsonb', 'json')
             and p.proargnames[t.i] not in ('p_postcode', 'p_grade')), 0,
          'ADR-191 (3): confirm_client_order has no free-text parameter (only the postcode and grade codes are text)');

-- 2. A client is never an organisation member (ADR-192 (2)) -------------------------------------------------------
select throws_ok($$ insert into public.organization_memberships (organization_id, user_id, role)
                    values ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000009e8', 'nurse') $$,
                 '23514', 'client_is_not_member', 'a client cannot become a member of the same organisation');
select throws_ok($$ insert into public.client_account_members (client_account_id, user_id)
                    values ('00000000-0000-4000-a000-0000000003c1', '00000000-0000-4000-a000-0000000009e6') $$,
                 '23514', 'client_is_not_member', 'an organisation member cannot become a client of the same organisation');

-- 3. A client-only user reads nothing of the network (ADR-192 (3)) ------------------------------------------------
create temp table visible_rows (t text, n integer);
grant all on visible_rows to authenticated;
do $$
declare r record;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'p')
             and has_table_privilege('authenticated', c.oid, 'select') loop
    -- A row of an organisation (organization_id set) is network data; a global row (organization_id null, or a table
    -- without the column) is a reference or default value that every signed-in user reads by design.
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = r.relname and column_name = 'organization_id') then
      execute format('insert into visible_rows select %L, count(*)::int from public.%I where organization_id is not null',
                     r.relname, r.relname);
    else
      execute format('insert into visible_rows select %L, count(*)::int from public.%I', r.relname, r.relname);
    end if;
  end loop;
  reset role;
end;
$$;
select is((select coalesce(string_agg(t || ':' || n, ', ' order by t), '') from visible_rows
           where n > 0 and t not in ('postcodes', 'qual_activities', 'qual_matrix_cells', 'qual_matrix_versions',
                                     'billing_rules', 'exception_rules', 'safety_alert_categories', 'tariff_rates',
                                     'working_time')), '',
          'a client-only user reads no organisation row of any public table (only global reference rows)');

-- 4. Preview writes nothing; required fields are never defaulted (BK-1b, BK-1d) --------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select is((select (r ->> 'problems') from public.preview_client_order(
             '00000000-0000-4000-a000-0000000003c1', null, null, null, null, null, null, null, null) r),
          '["missing_start_date", "missing_start_time", "missing_end_time", "missing_postcode", "missing_grade", "missing_activity_tags"]',
          'BK-1b: every missing required field is named; none is defaulted');
reset role;
select is((select count(*)::int from public.partner_requests where order_kind is not null), 0,
          'BK-1d: the preview wrote no row');

select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
create temp table pv as select public.preview_client_order(
  '00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00', time '07:00', '4102', 'fage_efz',
  array['B1'], array[]::text[], null) as r;
select is((select r -> 'problems' from pv), '[]'::jsonb, 'a complete night order has no problem');
select is((select (r ->> 'duration_minutes')::int from pv), 540, 'BK-1c: 22:00–07:00 is 540 minutes');
select is((select (r ->> 'ends_at')::timestamptz from pv), timestamptz '2026-11-23 07:00:00+01', 'BK-1c: ends the next day 07:00');
select is((select r ->> 'sentence' from pv),
          'Schichtauftrag · FaGe · So 22.11.2026 22:00 – Mo 23.11.2026 07:00 (9 Std.) · 4102 Binningen',
          'UXR-196: the built sentence uses the form labels');
select ok((select position('_' in r ->> 'sentence') = 0 from pv), 'UXR-196: no `_` in the sentence');
select is((select r ->> 'shift_label' from pv), 'Nacht', 'PO 18:40 (2)(b): label from the client''s own plan');
select is((select (r ->> 'weekend')::boolean from pv), true, 'PO 18:40 (2)(c): a Sunday start is weekend (calendar fact)');

select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-18', time '09:10',
           time '13:20', '4051', 'ags_eba', array['B1'], null, null) ->> 'shift_label'), null,
          'PO 18:40 (2)(c): no plan entry matches → no label');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-18', time '09:10',
           time '13:20', '4051', 'ags_eba', array['B1'], null, null) -> 'problems'), '[]'::jsonb,
          'PO 18:40 (2)(c): an order without label is still valid');

select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '22:00', '4102', 'fage_efz', array['B1'], null, null) -> 'problems'), '["end_equals_start"]'::jsonb,
          'a zero duration is refused, never read as 24 h');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-12', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], null, null) -> 'problems'), '["starts_in_past"]'::jsonb,
          'a start before now is refused');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '3000', 'fage_efz', array['B1'], null, null) -> 'problems'), '["postcode_not_in_list"]'::jsonb,
          'a postcode outside the BS/BL list is refused');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'pflegehelfer_srk', array['B1'], null, null) -> 'problems'), '["grade_unknown"]'::jsonb,
          'only AGS, FaGe, HF can be ordered');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1', 'ZZ9'], null, null) -> 'problems'), '["tag_unknown"]'::jsonb,
          'a tag outside the activity list is refused (P-6)');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], array['B3'], null) -> 'problems'), '["required_tag_not_in_tags"]'::jsonb,
          'a required tag must be one of the tags');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], null, 0) -> 'problems'), '["radius_not_positive"]'::jsonb,
          'a radius must be > 0 when given');
select is((select public.preview_client_order('00000000-0000-4000-a000-0000000003c2', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], null, null) -> 'problems'), '["not_client"]'::jsonb,
          'client A cannot preview for client account B');

-- 4b. Clock change (CGR-206 (d)) ------------------------------------------------------------------------------------
create temp table dst as select
  public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2027-10-30', time '22:00', time '07:00',
    '4102', 'fage_efz', array['B1'], null, null) as autumn,
  public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2027-03-27', time '22:00', time '07:00',
    '4102', 'fage_efz', array['B1'], null, null) as spring,
  public.preview_client_order('00000000-0000-4000-a000-0000000003c1', date '2027-03-28', time '02:30', time '07:00',
    '4102', 'fage_efz', array['B1'], null, null) as gap;
select is((select (autumn ->> 'duration_minutes')::int from dst), 600,
          'CGR-206 (d): night 30./31.10.2027 (clocks back) is 600 minutes');
select is((select autumn ->> 'sentence' from dst),
          'Schichtauftrag · FaGe · Sa 30.10.2027 22:00 – So 31.10.2027 07:00 (10 Std.) · 4102 Binningen',
          'CGR-206 (d): the autumn sentence says (10 Std.)');
select is((select (spring ->> 'duration_minutes')::int from dst), 480,
          'CGR-206 (d): night 27./28.03.2027 (clocks forward) is 480 minutes');
select is((select spring ->> 'sentence' from dst),
          'Schichtauftrag · FaGe · Sa 27.03.2027 22:00 – So 28.03.2027 07:00 (8 Std.) · 4102 Binningen',
          'CGR-206 (d): the spring sentence says (8 Std.)');
select is((select (gap ->> 'starts_at')::timestamptz from dst), timestamptz '2027-03-28 03:30:00+02',
          'CGR-206 (d): a 02:30 start on 28.03.2027 is read as 03:30 (DST1 / ADR-081)');
select is((select gap ->> 'sentence' from dst),
          'Schichtauftrag · FaGe · So 28.03.2027 03:30 – So 28.03.2027 07:00 (3 Std. 30 Min.) · 4102 Binningen',
          'CGR-206 (d): the preview shows 03:30 before confirmation, not the typed 02:30');

-- 5. Confirm (BK-1d) ------------------------------------------------------------------------------------------------
select is((select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], array[]::text[], null,
           'bbbb0000-0000-4000-8000-000000000001') ->> 'result'), 'ok', 'client A confirms the night order');
select is((select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], array[]::text[], null,
           'bbbb0000-0000-4000-8000-000000000001') ->> 'result'), 'duplicate', 'the same key twice is a duplicate');
select is((select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '22:00', '4102', 'fage_efz', array['B1'], null, null,
           'bbbb0000-0000-4000-8000-000000000002') ->> 'result'), 'invalid', 'confirm re-runs the checks');
select is((select count(*)::int from public.client_orders()), 1, 'client A sees its one order');
select is((select o.duration_minutes from public.client_orders() o), 540, 'client_orders: 540 minutes');
select is((select o.cover_state from public.client_orders() o), 'not_covered', 'BK-6: not covered is stated');
reset role;

select is((select count(*)::int from public.partner_requests where order_kind = 'shift'), 1, 'one row, not two days');
select is((select status from public.partner_requests where order_kind = 'shift'), 'client_confirmed',
          'status keeps it off the Operations intake list (open / ready_to_convert)');
select is((select count(*)::int from public.partner_requests where order_kind = 'shift' and notes is null
             and urgency is null and need_summary = request_title), 1,
          'no caller text, no preset urgency (IPA1-7); the stored text is the built sentence');
select is((select count(*)::int from public.audit_events a join public.partner_requests p on p.id = a.entity_id
           where p.order_kind = 'shift' and a.table_name = 'partner_requests' and a.command = 'confirm_client_order'), 1,
          'one audit row for the confirmed order');
select is((select count(*)::int from public.cases c join public.partner_requests p on p.converted_case_id = c.id
           where p.order_kind = 'shift'), 0, 'no case is created');

-- Changing the plan changes no stored fact of the order (PO 18:40 (2)(d)).
update public.client_shift_plans set starts_at = time '21:00' where client_account_id = '00000000-0000-4000-a000-0000000003c1' and label = 'Nacht';
select ok((select starts_at = timestamptz '2026-11-22 22:00:00+01' and ends_at = timestamptz '2026-11-23 07:00:00+01'
                   and shift_label = 'Nacht' from public.partner_requests where order_kind = 'shift'),
          'a plan change leaves the order unchanged');

-- 6. Nobody confirms for a client (BK-1n) ---------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e9');
set local role authenticated;
select is((select count(*)::int from public.client_orders()), 0, 'client B never sees client A''s order');
select is((select count(*)::int from public.partner_requests), 0, 'client B reads no partner_requests row');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e5');
set local role authenticated;
select is((select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], null, null, 'bbbb0000-0000-4000-8000-000000000003') ->> 'result'),
          'rejected', 'Operations cannot confirm for a client');
select is((select public.convert_partner_request(p.id, 'Test', 'Person', true, '{}'::jsonb, 'bbbb0000-0000-4000-8000-000000000004') ->> 'result'
           from public.partner_requests p where p.order_kind = 'shift'), 'rejected',
          '«Fall eröffnen» does not take a client order');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
set local role authenticated;
select is((select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], null, null, 'bbbb0000-0000-4000-8000-000000000005') ->> 'result'),
          'rejected', 'a nurse cannot confirm for a client');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009ea');
set local role authenticated;
select is((select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-22', time '22:00',
           time '07:00', '4102', 'fage_efz', array['B1'], null, null, 'bbbb0000-0000-4000-8000-000000000006') ->> 'result'),
          'rejected', 'an admin of the organisation cannot confirm for a client');
reset role;

-- 7. No direct table writes for authenticated ----------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.partner_requests', 'insert')
          and not has_table_privilege('authenticated', 'public.partner_requests', 'update')
          and not has_table_privilege('authenticated', 'public.client_accounts', 'insert')
          and not has_table_privilege('authenticated', 'public.client_account_members', 'insert')
          and not has_table_privilege('authenticated', 'public.client_shift_plans', 'update')
          and not has_table_privilege('authenticated', 'public.postcodes', 'insert'),
          'authenticated writes no order, account, plan or postcode table directly');

select * from finish();
rollback;
