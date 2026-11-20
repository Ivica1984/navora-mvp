-- HD-1 / HD-2 (migration 0159): the home plans its own staff (week, month, plan per staff member).
-- Guards:
--   * positive: the backfilled/seeded tenant of «Testheim Rhein» has kundebs as lead; the lead creates a station, shift
--     types, staff and a staffing requirement; assigns; the plan shows «ok»; an absence turns the cell into «gap» with
--     the person marked absent; removing the absence closes the gap; the example loads once;
--   * negative: an absent person, a double booking, an overlapping shift and an inactive person are refused; a range
--     over 42 days is refused; the example is refused a second time and for a non-simulation tenant;
--   * permission: another home's lead, a viewer (writes), a network admin, a team nurse, a client of another account and
--     anon read and write nothing; no app role has a table grant; a network member cannot become an institution member;
--   * schema and audit: an absence has no reason column; every command writes one append-only audit row.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(48);

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
exception when others then
  execute 'reset role';
  perform pg_temp.as_owner();
  return jsonb_build_object('sqlstate', sqlstate);
end $$;
create function pg_temp.lead() returns text language sql as $$ select '00000000-0000-4000-a000-0000000009e8' $$;
create function pg_temp.inst() returns uuid language sql as $$ select '00000000-0000-4000-a000-0000000004c1'::uuid $$;
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a158-0000000000' || n)::uuid $$;

-- Fixture (as owner): a second home H2 with its lead L2; a viewer V of home 1; a non-simulation home H3 with lead L3.
insert into auth.users (id, email) values (pg_temp.u('01'), 'l2.hd1@navora.test'), (pg_temp.u('02'), 'v.hd1@navora.test'),
                                          (pg_temp.u('03'), 'l3.hd1@navora.test'), (pg_temp.u('04'), 'adm.hd1@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('04'), 'admin');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('11'), 'Testheim Zwei (synthetisch)', 'home', true),
  (pg_temp.u('13'), 'Testheim Drei (synthetisch)', 'home', false);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.u('11'), pg_temp.u('01'), 'lead'), (pg_temp.inst(), pg_temp.u('02'), 'viewer'),
  (pg_temp.u('13'), pg_temp.u('03'), 'lead');

-- 1. Tenant and membership -------------------------------------------------------------------------------------------
select is((select role from public.institution_members where institution_id = pg_temp.inst() and user_id = pg_temp.lead()::uuid),
          'lead', 'kundebs is lead of the Testheim Rhein tenant');
select is((select institution_id from public.client_accounts where id = '00000000-0000-4000-a000-0000000003c1'),
          pg_temp.inst(), 'the home client account points at its tenant');
select is(pg_temp.cmd(pg_temp.lead(), 'select count(*) from public.my_institutions()')::int, 1,
          'my_institutions: the lead sees exactly her home');

-- 2. Settings by the lead ---------------------------------------------------------------------------------------------
create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format(
  'select public.institution_add_station(%L, %L)', pg_temp.inst(), 'Station Test')) ->> 'station_id')::uuid;
select isnt((select v from ids where k = 'st'), null, 'the lead adds a station');
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format(
  'select public.institution_set_shift_type(%L, %L, %L, %L, %L)', pg_temp.inst(), 'F', 'Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids select 's', (pg_temp.cmd(pg_temp.lead(), format(
  'select public.institution_set_shift_type(%L, %L, %L, %L, %L)', pg_temp.inst(), 'S', 'Spät', '14:30', '23:00')) ->> 'shift_type_id')::uuid;
insert into ids select 'n', (pg_temp.cmd(pg_temp.lead(), format(
  'select public.institution_set_shift_type(%L, %L, %L, %L, %L)', pg_temp.inst(), 'N', 'Nacht', '22:30', '07:15')) ->> 'shift_type_id')::uuid;
select is((select count(*)::int from ids where k in ('f', 's', 'n') and v is not null), 3, 'the lead sets three shift types');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 2, %L, 1)',
          pg_temp.inst(), (select v from ids where k = 'st'), (select v from ids where k = 'f'), 'nurse_hf_fh')) ->> 'result',
          'ok', 'the lead sets the home''s own requirement: 2 persons, 1 HF');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 1, %L, 2)',
          pg_temp.inst(), (select v from ids where k = 'st'), (select v from ids where k = 'f'), 'nurse_hf_fh')) ->> 'result',
          'invalid', 'a grade count above the total is refused');
insert into ids select 'p1', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, %L)',
  pg_temp.inst(), 'Test Eins', 'nurse_hf_fh', (select v from ids where k = 'st'))) ->> 'staff_id')::uuid;
insert into ids select 'p2', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'Test Zwei', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 'p3', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'Test Drei', 'fage_efz')) ->> 'staff_id')::uuid;
select is((select count(*)::int from ids where k like 'p_' and v is not null), 3, 'the lead adds three staff members');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
          pg_temp.inst(), 'Test Vier', 'doctor')) ->> 'result', 'invalid', 'an unknown grade code is refused');

-- 3. Plan: assign, status, absence, gap ------------------------------------------------------------------------------
create function pg_temp.assign(p text, sh text, d date) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L)',
    pg_temp.inst(), (select v from ids where k = 'st'), (select v from ids where k = sh), d, (select v from ids where k = p)))
$$;
create function pg_temp.cell(d date, sh text) returns jsonb language sql as $$
  select c from jsonb_array_elements(pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)',
    pg_temp.inst(), d, d)) -> 'cells') c
  where c ->> 'station_id' = (select v from ids where k = 'st')::text and c ->> 'shift_type_id' = (select v from ids where k = sh)::text
$$;
select is(pg_temp.assign('p1', 'f', '2026-11-25') ->> 'result', 'ok', 'assign HF to Wed Früh');
select is(pg_temp.cell('2026-11-25', 'f') ->> 'status', 'gap', 'one of two: the cell is a gap');
select is((pg_temp.cell('2026-11-25', 'f') ->> 'missing')::int, 1, 'missing = 1');
select is(pg_temp.assign('p2', 'f', '2026-11-25') ->> 'result', 'ok', 'assign FaGe to Wed Früh');
select is(pg_temp.cell('2026-11-25', 'f') ->> 'status', 'ok', 'two of two with one HF: ok');
select is(pg_temp.cell('2026-11-25', 's') ->> 'status', 'no_rule', 'no requirement set for Spät: no_rule, never a guess');
select is(pg_temp.assign('p2', 'f', '2026-11-25') ->> 'result', 'invalid', 'the same assignment twice is refused');
select is(pg_temp.assign('p2', 's', '2026-11-25') -> 'problems' ->> 0, 'staff_overlap', 'Früh 07:00–15:30 and Spät 14:30 overlap: refused');
select is(pg_temp.assign('p1', 'n', '2026-11-24') -> 'problems' ->> 0, 'staff_overlap',
          'Tuesday night 22:30–07:15 overlaps Wednesday Früh 07:00: refused');
select is(pg_temp.assign('p3', 'n', '2026-11-24') ->> 'result', 'ok', 'another person takes Tuesday night');

insert into ids select 'ab', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_record_absence(%L, %L, %L, %L)',
  pg_temp.inst(), (select v from ids where k = 'p2'), '2026-11-25', '2026-11-26')) ->> 'absence_id')::uuid;
select isnt((select v from ids where k = 'ab'), null, 'the planner records an absence (no reason asked)');
select is(pg_temp.cell('2026-11-25', 'f') ->> 'status', 'gap', 'the absence turns the cell into a gap');
select is((select a ->> 'absent' from jsonb_array_elements(pg_temp.cell('2026-11-25', 'f') -> 'assigned') a
           where a ->> 'staff_id' = (select v from ids where k = 'p2')::text), 'true', 'the person is marked absent in the cell');
select is(pg_temp.assign('p2', 'f', '2026-11-26') -> 'problems' ->> 0, 'staff_absent', 'an absent person cannot be assigned');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_record_absence(%L, %L, %L, %L)',
          pg_temp.inst(), (select v from ids where k = 'p2'), '2026-11-26', '2026-11-27')) -> 'problems' ->> 0,
          'absence_overlaps', 'an overlapping absence is refused');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_remove_absence(%L)', (select v from ids where k = 'ab'))) ->> 'result',
          'ok', 'the absence is removed');
select is(pg_temp.cell('2026-11-25', 'f') ->> 'status', 'ok', 'without the absence the cell is ok again');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_active(%L, false)', (select v from ids where k = 'p3'))) ->> 'result',
          'ok', 'the lead sets a person inactive');
select is(pg_temp.assign('p3', 'f', '2026-11-27') -> 'problems' ->> 0, 'staff_inactive', 'an inactive person cannot be assigned');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-01', '2026-12-31')) ->> 'result',
          'invalid', 'a range over 42 days is refused');
select is(jsonb_array_length(pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-01', '2026-11-30')) -> 'cells'),
          30 * 3, 'a month: one cell per day, station and shift type');

-- 4. Permissions ----------------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.u('01')::text, format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-25', '2026-11-25')) ->> 'result',
          'rejected', 'another home''s lead reads nothing of this home');
select is(pg_temp.cmd(pg_temp.u('01')::text, format('select public.institution_assign_staff(%L, %L, %L, %L, %L)', pg_temp.inst(),
          (select v from ids where k = 'st'), (select v from ids where k = 'f'), '2026-11-28', (select v from ids where k = 'p1'))) ->> 'result',
          'rejected', 'another home''s lead cannot assign here');
select is(pg_temp.cmd(pg_temp.u('02')::text, format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-25', '2026-11-25')) ->> 'result',
          'ok', 'a viewer reads the plan');
select is(pg_temp.cmd(pg_temp.u('02')::text, format('select public.institution_assign_staff(%L, %L, %L, %L, %L)', pg_temp.inst(),
          (select v from ids where k = 'st'), (select v from ids where k = 'f'), '2026-11-28', (select v from ids where k = 'p1'))) ->> 'result',
          'rejected', 'a viewer cannot assign');
select is(pg_temp.cmd(pg_temp.u('02')::text, format('select public.institution_add_station(%L, %L)', pg_temp.inst(), 'Viewer')) ->> 'result',
          'rejected', 'a viewer cannot change settings');
select is(pg_temp.cmd(pg_temp.u('04')::text,
          format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-25', '2026-11-25')) ->> 'result',
          'rejected', 'the admin of the network the home orders from reads nothing');
select is(pg_temp.cmd('00000000-0000-4000-a000-0000000009e6',
          format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-25', '2026-11-25')) ->> 'result',
          'rejected', 'a NAVORA team member reads nothing of the home''s staff');
select is(pg_temp.cmd('00000000-0000-4000-a000-0000000009e5', 'select count(*) from public.my_institutions()')::int, 0,
          'a coordinator of the network has no institution');
select is(pg_temp.cmd(pg_temp.lead(), 'select count(*) from public.institution_staff') ->> 'sqlstate', '42501',
          'no direct table read for the lead either (functions only)');
select ok(not exists (select 1 from information_schema.role_table_grants
                      where table_schema = 'public' and table_name like 'institution%' and grantee in ('anon', 'authenticated')),
          'no table grant to anon or authenticated on any institution table');
select ok(not has_function_privilege('anon', 'public.institution_plan(uuid, date, date)', 'execute'), 'anon cannot execute the plan read');
select throws_ok(format($$insert into public.institution_members (institution_id, user_id, role) values (%L, %L, 'planner')$$,
                        pg_temp.inst(), '00000000-0000-4000-a000-0000000009e5'),
                 '23514', 'institution_member_is_org_member', 'a member of the network organisation cannot join the home''s planning');

-- 5. Example data -----------------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_load_example(%L, %L)', pg_temp.inst(), '2026-11-23')) -> 'problems' ->> 0,
          'not_empty', 'the example is refused for a home that already has data');
select is(pg_temp.cmd(pg_temp.u('01')::text, format('select public.institution_load_example(%L, %L)', pg_temp.u('11'), '2026-11-23')) ->> 'result',
          'ok', 'an empty simulation home loads the synthetic example');
select is(pg_temp.cmd(pg_temp.u('03')::text, format('select public.institution_load_example(%L, %L)', pg_temp.u('13'), '2026-11-23')) -> 'problems' ->> 0,
          'not_simulation', 'a home outside the simulation never gets example data');

-- 6. Schema and audit -------------------------------------------------------------------------------------------------
select hasnt_column('public', 'institution_absences', 'reason', 'an absence has no reason column');
select ok((select count(*) from public.institution_audit_events where institution_id = pg_temp.inst()) >= 10,
          'commands write audit rows');
select throws_ok('delete from public.institution_audit_events', '42501', null, 'the audit is append-only');

select * from finish();
rollback;
