-- HD-2 gap → external order → status back (brief docs/agents/briefs/HD.md §3, §3a, §4 row HD-2; migration 0162).
-- Positive: a gap cell becomes a draft (E), is sent through confirm_client_order (no second order path), the plan cell
--   reads the order's cover exactly as /order reads it (one source, private.order_client_state); a confirmed and
--   checked person (G) fills the slot; when she drops out (N) the cell is a gap again and never «ok».
-- Negative: not a gap, already ordered (lock and unique index), wrong grade for a missing grade, missing activities,
--   the gap closed meanwhile, a second send, a discard after sending, a past shift.
-- Permission: viewer and stranger are rejected; the table is not readable or writable by `authenticated`.
-- Synthetic data only; rolled back. Pinned clock Mon 2026-11-16 12:00 Europe/Zurich; shift Thu 2026-11-19 07:00–15:30.
-- Users: kundebs …9e8 (lead of «Testheim Rhein» …4c1 and member of its client account …3c1), viewer …a161-…02,
-- stranger …a161-…03; nurses …a161-…11, …12 in team …b161-…01 of Testorganisation S (…b000-…019), admin …a161-…09.
begin;
create extension if not exists pgtap with schema extensions;

select plan(45);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r;
end $$;
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
create function pg_temp.lead() returns text language sql as $$ select '00000000-0000-4000-a000-0000000009e8' $$;
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a161-0000000000' || n)::uuid $$;
create function pg_temp.inst() returns uuid language sql as $$ select '00000000-0000-4000-a000-0000000004c1'::uuid $$;
create function pg_temp.st() returns uuid language sql as $$ select '00000000-0000-4000-c161-000000000001'::uuid $$;
create function pg_temp.fr() returns uuid language sql as $$ select '00000000-0000-4000-c161-000000000002'::uuid $$;
create function pg_temp.sp() returns uuid language sql as $$ select '00000000-0000-4000-c161-000000000003'::uuid $$;
create function pg_temp.mara() returns uuid language sql as $$ select '00000000-0000-4000-c161-000000000011'::uuid $$;
create function pg_temp.lena() returns uuid language sql as $$ select '00000000-0000-4000-c161-000000000012'::uuid $$;

-- Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into auth.users (id, aud, role, email)
  select pg_temp.u(n), 'authenticated', 'authenticated', 'hd2-' || n || '.fixture@navora.test'
  from unnest(array['02', '03', '09', '11', '12']) n;
insert into public.institution_members (institution_id, user_id, role) values (pg_temp.inst(), pg_temp.u('02'), 'viewer');
insert into public.institution_stations (id, institution_id, name, sort) values (pg_temp.st(), pg_temp.inst(), 'Station HD-2', 1);
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, ends_at, sort) values
  (pg_temp.fr(), pg_temp.inst(), 'F2', 'Früh HD-2', '07:00', '15:30', 1),
  (pg_temp.sp(), pg_temp.inst(), 'S2', 'Spät HD-2', '15:00', '23:00', 2);
insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total, required_grade,
                                               required_grade_count, example) values
  (pg_temp.inst(), pg_temp.st(), pg_temp.fr(), 1, 'nurse_hf_fh', 1, true),
  (pg_temp.inst(), pg_temp.st(), pg_temp.sp(), 1, null, 0, true);
insert into public.institution_staff (id, institution_id, display_name, grade, home_station_id) values
  (pg_temp.mara(), pg_temp.inst(), 'Mara Test HD-2', 'nurse_hf_fh', pg_temp.st()),
  (pg_temp.lena(), pg_temp.inst(), 'Lena Test HD-2', 'nurse_hf_fh', pg_temp.st());
insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id) values
  (pg_temp.inst(), pg_temp.st(), pg_temp.fr(), date '2026-11-19', pg_temp.mara());
insert into public.institution_absences (institution_id, staff_id, starts_on, ends_on) values
  (pg_temp.inst(), pg_temp.mara(), date '2026-11-19', date '2026-11-19');
-- One HF team in Basel-Landschaft serving 4102.
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b161-000000000001', 'HD-2 Team HF', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values ('00000000-0000-4000-b161-000000000001', '4102');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('11'), 'nurse'),
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('12'), 'nurse'),
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('09'), 'admin');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b161-000000000001', pg_temp.u('11'), 'registered_nurse'),
  ('00000000-0000-4000-b161-000000000001', pg_temp.u('12'), 'registered_nurse');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019'::uuid, pg_temp.u(n), 'grade', 'nurse_hf_fh', 'verified', true, null::date
  from unnest(array['11', '12']) n
  union all  -- the matrix cell A1 × HF requires `practice_licence` (PROPOSED matrix, synthetic evidence only)
  select '00000000-0000-4000-b000-000000000019', pg_temp.u(n), 'practice_licence', null, 'verified', true, null
  from unnest(array['11', '12']) n;

create function pg_temp.cell(p_shift uuid) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-19', '2026-11-19'));
  return (select c from jsonb_array_elements(r -> 'cells') c
          where c ->> 'station_id' = pg_temp.st()::text and c ->> 'shift_type_id' = p_shift::text);
end $$;
create function pg_temp.prep(p_user text, p_shift uuid) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_prepare_gap_order(%L, %L, %L, %L)',
                                    pg_temp.inst(), pg_temp.st(), p_shift, '2026-11-19'))
$$;
create function pg_temp.send(p_user text, p_gap uuid, p_grade text, p_tags text, p_key text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_send_gap_order(%L, %L, %L, %L::text[], %L::text[], null, %L)',
                                    p_gap, '4102', p_grade, p_tags, '{}', p_key))
$$;
create temp table ids (k text primary key, id uuid);
grant all on ids to authenticated;

-- 1. Permission ------------------------------------------------------------------------------------------------------
select is(pg_temp.prep(pg_temp.u('02')::text, pg_temp.fr()) ->> 'result', 'rejected', 'a viewer cannot prepare an order');
select is(pg_temp.prep(pg_temp.u('03')::text, pg_temp.fr()) ->> 'result', 'rejected', 'a stranger cannot prepare an order');
select is((pg_temp.cell(pg_temp.fr()) ->> 'status'), 'gap', 'precondition: Mara is absent, the HF early shift is a gap');
select is(pg_temp.cell(pg_temp.fr()) -> 'order', 'null'::jsonb, 'precondition: the gap cell has no order');

-- 2. Prepare (E) -----------------------------------------------------------------------------------------------------
create temp table r1 as select pg_temp.prep(pg_temp.lead(), pg_temp.fr()) as r;
select is((select r ->> 'result' from r1), 'ok', 'the lead prepares an order from the gap');
insert into ids select 'g1', (r ->> 'gap_order_id')::uuid from r1;
select is((select r -> 'prefill' ->> 'grade' from r1), 'nurse_hf_fh', 'a missing HF fixes the ordered grade');
select is((select r -> 'prefill' ->> 'start_time' from r1) || '-' || (select r -> 'prefill' ->> 'end_time' from r1),
          '07:00-15:30', 'date and times come from the cell''s shift type');
select is((select r -> 'prefill' -> 'postcode' from r1), 'null'::jsonb, 'no postcode is invented for the home');
select is((select r -> 'prefill' -> 'activity_tags' from r1), '[]'::jsonb, 'no activities are invented on the first order');
select is(pg_temp.cell(pg_temp.fr()) -> 'order' ->> 'state', 'prepared', 'week/month read «Auftrag vorbereitet» (E)');
select is(pg_temp.cell(pg_temp.fr()) ->> 'status', 'gap', 'a draft never fills the gap');
select is(pg_temp.prep(pg_temp.lead(), pg_temp.fr()) -> 'problems', '["already_ordered"]'::jsonb,
          'a second order for the same gap is refused (double-order lock)');
select throws_ok(format($q$insert into public.institution_gap_orders (institution_id, station_id, shift_type_id, work_date,
                    client_account_id, prepared_by) values (%L, %L, %L, '2026-11-19', '00000000-0000-4000-a000-0000000003c1', %L)$q$,
                 pg_temp.inst(), pg_temp.st(), pg_temp.fr(), pg_temp.lead()),
                 '23505', null, 'the partial unique index is the backstop for one active order per cell');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_prepare_gap_order(%L, %L, %L, %L)', pg_temp.inst(),
            pg_temp.st(), pg_temp.fr(), '2026-11-12')) -> 'problems', '["starts_in_past"]'::jsonb,
          'a shift in the past cannot be ordered');

-- 3. Preview and send -----------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.lead(), format($q$select public.institution_preview_gap_order(%L, '4102', 'fage_efz',
            '{A1}', '{}', null)$q$, (select id from ids where k = 'g1'))) -> 'problems', '["grade_not_missing"]'::jsonb,
          'a lower grade for a missing HF is refused (it would leave the gap open)');
select is(pg_temp.cmd(pg_temp.lead(), format($q$select public.institution_preview_gap_order(%L, '4102', 'nurse_hf_fh',
            '{A1}', '{}', null)$q$, (select id from ids where k = 'g1'))) -> 'preview' -> 'problems', '[]'::jsonb,
          'the preview goes through preview_client_order and finds no problem');
select is(pg_temp.send(pg_temp.u('02')::text, (select id from ids where k = 'g1'), 'nurse_hf_fh', '{A1}',
                       'eeee0000-0000-4000-8161-000000000001') ->> 'result', 'rejected', 'a viewer cannot send');
select ok(pg_temp.send(pg_temp.lead(), (select id from ids where k = 'g1'), 'nurse_hf_fh', '{}',
                       'eeee0000-0000-4000-8161-000000000002') -> 'problems' ? 'missing_activity_tags',
          'without activities the order path refuses (problems of client_order_check)');
select is(pg_temp.cell(pg_temp.fr()) -> 'order' ->> 'state', 'prepared', 'a refused send leaves the draft unchanged');
create temp table r2 as select pg_temp.send(pg_temp.lead(), (select id from ids where k = 'g1'), 'nurse_hf_fh', '{A1}',
                                            'eeee0000-0000-4000-8161-000000000003') as r;
select is((select r ->> 'result' from r2), 'ok', 'the lead sends the order');
insert into ids select 'o1', (r ->> 'order_id')::uuid from r2;
select is((select count(*)::int from public.partner_requests where id = (select id from ids where k = 'o1')
             and client_account_id = '00000000-0000-4000-a000-0000000003c1' and status = 'client_confirmed'
             and grade = 'nurse_hf_fh'), 1, 'the order is an ordinary client order of the home''s client account');
select is((select order_postcode from public.institutions where id = pg_temp.inst()), '4102',
          'the home''s postcode is kept from its first sent order');
select is(pg_temp.send(pg_temp.lead(), (select id from ids where k = 'g1'), 'nurse_hf_fh', '{A1}',
                       'eeee0000-0000-4000-8161-000000000004') ->> 'result', 'already_sent', 'a second send changes nothing');
select is((select count(*)::int from public.institution_gap_orders g join public.partner_requests p on p.id = g.order_id
             where g.station_id = pg_temp.st()), 1, 'exactly one order exists for the gap');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_discard_gap_order(%L)',
            (select id from ids where k = 'g1'))) -> 'problems', '["not_prepared"]'::jsonb, 'a sent order is not discarded');

-- 4. Status back: one source with /order (A → G → N) ----------------------------------------------------------------
create function pg_temp.client_state() returns text language sql as $$
  select (pg_temp.cmd(pg_temp.lead(), format('select x.cover_state || coalesce(''/'' || x.cover_detail, '''') from public.client_orders() x where x.id = %L',
                                             (select id from ids where k = 'o1')))) #>> '{}'
$$;
create function pg_temp.cell_state() returns text language sql as $$
  select (pg_temp.cell(pg_temp.fr()) -> 'order' ->> 'cover_state') || coalesce('/' || (pg_temp.cell(pg_temp.fr()) -> 'order' ->> 'cover_detail'), '')
$$;
select is(pg_temp.cell_state(), 'open', 'A: «Angebot versandt · noch nicht gedeckt»');
select is(pg_temp.cell_state(), pg_temp.client_state(), 'the plan cell and /order read the same state (A)');
select is(pg_temp.cell(pg_temp.fr()) ->> 'status', 'gap', 'A never fills the gap');
select pg_temp.act_as(pg_temp.u('11')::text);
set local role authenticated;
select is(public.take_order((select id from ids where k = 'o1'), '00000000-0000-4000-b161-000000000001', pg_temp.u('11'),
                            'ffff0000-0000-4000-8161-000000000001') ->> 'result', 'ok', 'the HF nurse takes the order for herself');
reset role;
select pg_temp.as_owner();
select is(pg_temp.cell_state(), 'covered', 'G: the person confirmed and was checked');
select is(pg_temp.cell_state(), pg_temp.client_state(), 'the plan cell and /order read the same state (G)');
select is(pg_temp.cell(pg_temp.fr()) ->> 'status', 'ok', 'G fills the HF slot: the cell is no longer a gap');
select is((pg_temp.cell(pg_temp.fr()) ->> 'external_covered')::int, 1, 'one slot is covered externally');
-- Her contract end passes before the shift, no command runs (FE-110 (b) path, pgTAP 160 §4).
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('11'), null, date '2026-11-17', pg_temp.u('09'));
select set_config('navora.test_now', '2026-11-18 10:00:00+01', true);
select is(pg_temp.cell_state(), 'no_longer_covered/no_offer_open', 'N: «Nicht mehr gedeckt · kein Angebot offen»');
select is(pg_temp.cell_state(), pg_temp.client_state(), 'the plan cell and /order read the same state (N)');
select is(pg_temp.cell(pg_temp.fr()) ->> 'status', 'gap', 'N: the cell is a gap again, never «ok» / «gedeckt»');
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);

-- 5. Discard, prefill from the last order, and a gap that closed meanwhile ----------------------------------------
create temp table r3 as select pg_temp.prep(pg_temp.lead(), pg_temp.sp()) as r;
select is((select r ->> 'result' from r3) || '/' || coalesce((select r -> 'prefill' ->> 'grade' from r3), 'none'), 'ok/none',
          'a gap of the total only: the order is prepared and the lead chooses the grade');
select is((select r -> 'prefill' -> 'activity_tags' from r3), '["A1"]'::jsonb,
          'activities are prefilled from the last order of this station (labelled as such)');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_discard_gap_order(%L)',
            (select r ->> 'gap_order_id' from r3))) ->> 'result', 'ok', 'the lead discards the draft');
select is(pg_temp.cell(pg_temp.sp()) -> 'order', 'null'::jsonb, 'after the discard the cell has no order');
create temp table r4 as select pg_temp.prep(pg_temp.lead(), pg_temp.sp()) as r;
select is((select r ->> 'result' from r4), 'ok', 'after a discard the gap can be prepared again');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L)', pg_temp.inst(),
            pg_temp.st(), pg_temp.sp(), '2026-11-19', pg_temp.lena())) ->> 'result', 'ok', 'Lena is assigned internally');
select is(pg_temp.send(pg_temp.lead(), (select (r ->> 'gap_order_id')::uuid from r4), 'nurse_hf_fh', '{A1}',
                       'eeee0000-0000-4000-8161-000000000005') -> 'problems', '["not_a_gap"]'::jsonb,
          'the gap closed meanwhile: nothing is ordered');

-- 6. Direct table access ---------------------------------------------------------------------------------------------
select pg_temp.act_as(pg_temp.lead());
set local role authenticated;
select throws_ok('select * from public.institution_gap_orders', '42501', null, 'authenticated cannot read the table');
select throws_ok($q$update public.institution_gap_orders set state = 'discarded'$q$, '42501', null,
                 'authenticated cannot write the table');
reset role;
select pg_temp.as_owner();

select * from finish();
rollback;
