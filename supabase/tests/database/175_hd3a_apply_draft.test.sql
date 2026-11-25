-- HD-3a slice 3 (brief docs/agents/briefs/HD.md §5b; ADR-224 rev. 2 «Apply and races»; migration 0175):
-- «Entwurf übernehmen». The database decides every row, not the solver:
--   * each row goes through institution_assign_staff without a confirmation: absence, double booking, overlap stay
--     blocked, and a planning rule (here: rest) refuses the row; nothing is saved as an override;
--   * a cell with an active external order, a cell already staffed and a cell without a staffing rule are refused;
--     a row of the missing grade is still accepted in a cell whose total is reached;
--   * partial take-over: refused rows are reported with their reason, accepted rows are saved; one run record and one
--     batch audit event, plus the event of every saved row;
--   * a repeat with the same apply id answers `already_applied` and writes nothing; an apply id of another home is
--     refused; malformed input and duplicates write nothing;
--   * permission: viewer and another home refused, planner allowed, access end raises (LEAVE1-3), anon no execute,
--     no table grant.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(42);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a175-0000000000' || n)::uuid $$;
create function pg_temp.d(n int) returns date language sql as $$ select (private.at_zurich(private.now()))::date + 100 + n $$;

insert into auth.users (id, email) values (pg_temp.u('01'), 'l2.hd3a5@navora.test'), (pg_temp.u('02'), 'v.hd3a5@navora.test'),
                                          (pg_temp.u('03'), 'p.hd3a5@navora.test'), (pg_temp.u('05'), 'l5.hd3a5@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('11'), 'Testheim HD-3a e (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.u('11'), pg_temp.u('01'), 'lead'), (pg_temp.inst(), pg_temp.u('02'), 'viewer'),
  (pg_temp.inst(), pg_temp.u('03'), 'planner'), (pg_temp.u('11'), pg_temp.u('05'), 'lead');

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Xaver', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 'y', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Yara', 'nurse_hf_fh')) ->> 'staff_id')::uuid;
insert into ids select 'z', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Zoe', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3a Station e')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'EF', 'HD3a Früh e', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids select 's', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'ES', 'HD3a Spät e', '14:30', '23:00')) ->> 'shift_type_id')::uuid;
insert into ids select 'n', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'EU', 'HD3a ohne Regel', '08:00', '12:00')) ->> 'shift_type_id')::uuid;
insert into ids values ('a1', pg_temp.u('a1')), ('a2', pg_temp.u('a2')), ('a3', pg_temp.u('a3')), ('a4', pg_temp.u('a4')),
                       ('a5', pg_temp.u('a5')), ('a6', pg_temp.u('a6')), ('a7', pg_temp.u('a7')), ('a8', pg_temp.u('a8'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('f'), 'early'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('s'), 'late'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L)', pg_temp.id(k), 'any'))
  from (values ('x'), ('y'), ('z')) v(k);
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42)', pg_temp.inst()));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 2, %L, 1)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f'), 'nurse_hf_fh'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 1, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('s')));

-- One draft row as the screen sends it.
create function pg_temp.dr(person text, shift text, n int, station uuid default null) returns jsonb language sql as $$
  select jsonb_build_object('date', pg_temp.d(n)::text, 'station_id', coalesce(station, pg_temp.id('st')),
                            'shift_type_id', pg_temp.id(shift), 'staff_id', pg_temp.id(person))
$$;
create function pg_temp.apply(p_user text, k text, p_rows jsonb, home uuid default null) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_apply_draft(%L, %L, %L::jsonb)',
    coalesce(home, pg_temp.inst()), pg_temp.id(k), p_rows))
$$;
create function pg_temp.has(person text, shift text, n int) returns boolean language sql as $$
  select exists (select 1 from public.institution_assignments where staff_id = pg_temp.id(person)
                 and shift_type_id = pg_temp.id(shift) and work_date = pg_temp.d(n))
$$;
create function pg_temp.n_assign() returns int language sql as $$
  select count(*)::int from public.institution_assignments where staff_id in (pg_temp.id('x'), pg_temp.id('y'), pg_temp.id('z'))
$$;
create function pg_temp.n_runs() returns int language sql as $$
  select count(*)::int from public.institution_draft_runs where institution_id in (pg_temp.inst(), pg_temp.u('11'))
$$;
create function pg_temp.batch_audits(apply text) returns int language sql as $$
  select count(*)::int from public.institution_audit_events where command = 'institution_apply_draft' and entity_id = pg_temp.id(apply)
$$;

-- 1. Shape ---------------------------------------------------------------------------------------------------------------
select has_function('public', 'institution_apply_draft', array['uuid', 'uuid', 'jsonb'], 'one command takes over a draft');
select has_table('public', 'institution_draft_runs', 'one run record per take-over');
select ok((select relrowsecurity from pg_class where oid = 'public.institution_draft_runs'::regclass), 'RLS is on');
select ok(not has_table_privilege('authenticated', 'public.institution_draft_runs', 'select')
          and not has_table_privilege('anon', 'public.institution_draft_runs', 'select'), 'no table grant to the app roles');
select throws_ok(format($q$insert into public.institution_draft_runs (id, institution_id, rows_offered, provenance)
                    values (gen_random_uuid(), %L, 1, 'model_proposal')$q$, pg_temp.inst()),
                 '23514', null, 'a run record carries only the provenance «Optimierung (feste Regeln)»');

-- 2. Malformed input writes nothing ------------------------------------------------------------------------------------
select is(pg_temp.apply(pg_temp.lead(), 'a1', '[]'::jsonb) -> 'problems', '["rows_not_valid"]'::jsonb, 'an empty draft is refused');
select is(pg_temp.apply(pg_temp.lead(), 'a1', '{"a": 1}'::jsonb) -> 'problems', '["rows_not_valid"]'::jsonb, 'not an array');
select is(pg_temp.apply(pg_temp.lead(), 'a1', jsonb_build_array(pg_temp.dr('x', 'f', 1) || '{"note": "x"}'::jsonb)) -> 'problems',
          '["rows_not_valid"]'::jsonb, 'an unknown key (no free text) is refused');
select is(pg_temp.apply(pg_temp.lead(), 'a1', jsonb_build_array(pg_temp.dr('x', 'f', 1) || '{"staff_id": "nope"}'::jsonb)) -> 'problems',
          '["rows_not_valid"]'::jsonb, 'a malformed id is refused');
select is(pg_temp.apply(pg_temp.lead(), 'a1', jsonb_build_array(pg_temp.dr('x', 'f', 1) || '{"date": "2030-02-30"}'::jsonb)) -> 'problems',
          '["rows_not_valid"]'::jsonb, 'an impossible date is refused');
select is(pg_temp.apply(pg_temp.lead(), 'a1', jsonb_build_array(pg_temp.dr('x', 'f', 1), pg_temp.dr('x', 'f', 1))) -> 'problems',
          '["duplicate_row"]'::jsonb, 'the same row twice is refused');
select is(pg_temp.n_runs() || '/' || pg_temp.n_assign(), '0/0', 'no refused call wrote a run or an assignment');

-- 3. A valid draft is saved whole --------------------------------------------------------------------------------------
select is(pg_temp.apply(pg_temp.lead(), 'a1', jsonb_build_array(pg_temp.dr('x', 'f', 10), pg_temp.dr('y', 'f', 10)))
            - 'assignment_ids',
          jsonb_build_object('result', 'ok', 'apply_id', pg_temp.id('a1'), 'applied', 2, 'refused', '[]'::jsonb),
          'two rows of a valid draft are saved');
select ok(pg_temp.has('x', 'f', 10) and pg_temp.has('y', 'f', 10), 'both assignments exist');
select is((select rows_offered || '/' || rows_applied || '/' || cardinality(assignment_ids) || '/' || provenance || '/'
                  || (applied_by = pg_temp.lead()::uuid)::text from public.institution_draft_runs where id = pg_temp.id('a1')),
          '2/2/2/optimizer_rules/true', 'the run record keeps counts, ids, provenance and who took it over');
select is(pg_temp.batch_audits('a1'), 1, 'one audit event for the batch');
select is((select count(*)::int from public.institution_audit_events where command = 'institution_assign_staff'
             and entity_id in (select unnest(assignment_ids) from public.institution_draft_runs where id = pg_temp.id('a1'))), 2,
          'and one assignment event per saved row');

-- 4. Safe repeat -------------------------------------------------------------------------------------------------------
select is(pg_temp.apply(pg_temp.lead(), 'a1', jsonb_build_array(pg_temp.dr('x', 'f', 10), pg_temp.dr('y', 'f', 10))),
          jsonb_build_object('result', 'already_applied', 'apply_id', pg_temp.id('a1'), 'applied', 2, 'refused', '[]'::jsonb),
          'the same apply id again: already_applied');
select is(pg_temp.n_assign() || '/' || pg_temp.batch_audits('a1'), '2/1', 'nothing written twice, no second audit event');
select is(pg_temp.apply(pg_temp.u('01')::text, 'a1', jsonb_build_array(pg_temp.dr('x', 'f', 10)), pg_temp.u('11')) -> 'problems',
          '["apply_id_used"]'::jsonb, 'an apply id of another home is refused and reveals nothing of it');

-- 5. Partial take-over: every refusal with its reason ------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_record_absence(%L, %L, %L, %L, %L)', pg_temp.inst(),
            pg_temp.id('z'), pg_temp.d(14), pg_temp.d(14), 'vacation')) ->> 'result', 'ok', 'fixture: Ferien of Zoe on day 14');
insert into public.institution_gap_orders (institution_id, station_id, shift_type_id, work_date, client_account_id, prepared_by)
  values (pg_temp.inst(), pg_temp.id('st'), pg_temp.id('s'), pg_temp.d(17), '00000000-0000-4000-a000-0000000003c1', pg_temp.lead()::uuid);
create temp table r2 as select pg_temp.apply(pg_temp.lead(), 'a2', jsonb_build_array(
  pg_temp.dr('x', 's', 10),                         -- overlaps the early shift of day 10
  pg_temp.dr('z', 'f', 10),                         -- the cell has 2 of 2, the HF included
  pg_temp.dr('y', 's', 12),                         -- valid
  pg_temp.dr('y', 'f', 13),                         -- 23:00 -> 07:00 is 8 h rest after the row before
  pg_temp.dr('z', 'f', 14),                         -- Ferien
  pg_temp.dr('x', 'n', 15),                         -- no staffing rule for this shift type
  pg_temp.dr('x', 'f', 16, gen_random_uuid()),      -- a station that is not of this home
  pg_temp.dr('z', 's', 17),                         -- an external order is prepared for this cell
  pg_temp.dr('x', 'f', 18))) as r;                  -- valid
select is((select r ->> 'result' || '/' || (r ->> 'applied') from r2), 'ok/2', 'two of nine rows are saved');
select is((select string_agg(e ->> 'reason', ',' order by e ->> 'reason') from r2, jsonb_array_elements(r -> 'refused') e),
          'cell_full,cell_has_order,no_staffing_rule,not_found,planning_rule,staff_absent,staff_overlap',
          'the seven others are refused, each with its reason');
select is((select e -> 'rules' from r2, jsonb_array_elements(r -> 'refused') e where e ->> 'reason' = 'planning_rule'),
          '["rest"]'::jsonb, 'the planning rule is named');
select is((select e ->> 'staff_id' || '/' || (e ->> 'date') from r2, jsonb_array_elements(r -> 'refused') e
           where e ->> 'reason' = 'planning_rule'), pg_temp.id('y') || '/' || pg_temp.d(13),
          'a refused row names the person and the date (the screen shows it as a gap)');
select ok(pg_temp.has('y', 's', 12) and pg_temp.has('x', 'f', 18), 'the valid rows are saved');
select ok(not (pg_temp.has('x', 's', 10) or pg_temp.has('z', 'f', 10) or pg_temp.has('y', 'f', 13) or pg_temp.has('z', 'f', 14)
               or pg_temp.has('x', 'n', 15) or pg_temp.has('x', 'f', 16) or pg_temp.has('z', 's', 17)), 'no refused row is saved');
select is((select count(*)::int from public.institution_assignments where override_rules is not null
             and staff_id in (pg_temp.id('x'), pg_temp.id('y'), pg_temp.id('z'))), 0, 'no row of a draft is saved as an override');
select is((select rows_offered || '/' || rows_applied || '/' || jsonb_array_length(refused) from public.institution_draft_runs
           where id = pg_temp.id('a2')), '9/2/7', 'the run record keeps the refused rows');
select is((select (changed ->> 'rows_applied') || '/' || (changed ->> 'rows_refused') || '/' || (changed ->> 'provenance')
           from public.institution_audit_events where command = 'institution_apply_draft' and entity_id = pg_temp.id('a2')),
          '2/7/optimizer_rules', 'the batch audit event counts saved and refused rows');

-- 6. The missing grade is still accepted in a cell whose total is reached -----------------------------------------------
select is(pg_temp.apply(pg_temp.lead(), 'a3', jsonb_build_array(pg_temp.dr('x', 'f', 20), pg_temp.dr('z', 'f', 20))) ->> 'applied',
          '2', 'two FaGe fill the total of the early cell of day 20, the HF is still missing');
select is(pg_temp.apply(pg_temp.lead(), 'a4', jsonb_build_array(pg_temp.dr('y', 'f', 20))) ->> 'applied', '1',
          'the HF row is accepted as the missing grade');
select is(pg_temp.apply(pg_temp.lead(), 'a5', jsonb_build_array(pg_temp.dr('z', 'f', 22), pg_temp.dr('y', 'f', 22))) ->> 'applied',
          '2', 'a FaGe and the HF for an empty early cell: both saved, in either order');

-- 7. Permission ----------------------------------------------------------------------------------------------------------
select is(pg_temp.apply(pg_temp.u('02')::text, 'a7', jsonb_build_array(pg_temp.dr('z', 's', 30))) ->> 'result', 'rejected',
          'a viewer cannot take over a draft');
select is(pg_temp.apply(pg_temp.u('01')::text, 'a7', jsonb_build_array(pg_temp.dr('z', 's', 30))) ->> 'result', 'rejected',
          'the lead of another home cannot');
select ok(not exists (select 1 from public.institution_draft_runs where id = pg_temp.id('a7')) and not pg_temp.has('z', 's', 30),
          'neither wrote anything');
select is(pg_temp.apply('a1750000-0000-4000-8000-000000000003', 'a7', jsonb_build_array(pg_temp.dr('z', 's', 30))) ->> 'result',
          'rejected', 'a user without membership cannot');
select is(pg_temp.apply(pg_temp.u('03')::text, 'a7', jsonb_build_array(pg_temp.dr('z', 's', 30))) ->> 'applied', '1',
          'a planner of the home can');
select is((select applied_by from public.institution_draft_runs where id = pg_temp.id('a7')), pg_temp.u('03'),
          'the run names the planner');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'ended', 'employment_ended', pg_temp.u('01'));
select is(pg_temp.apply(pg_temp.u('05')::text, 'a8', jsonb_build_array(pg_temp.dr('x', 'f', 40)), pg_temp.u('11')) ->> 'sqlstate',
          '42501', 'after the access end the command raises access_ended');
select ok(not has_function_privilege('anon', 'public.institution_apply_draft(uuid, uuid, jsonb)', 'execute'),
          'anon cannot take over a draft');
select ok(has_function_privilege('authenticated', 'public.institution_apply_draft(uuid, uuid, jsonb)', 'execute'),
          'authenticated may call it (the role is checked inside)');

select * from finish();
rollback;
