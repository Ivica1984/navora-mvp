-- HD-1 fixed residual list (PO 2026-11-20 20:05, briefs/HD.md Fassung 3 §4a), migration 0160.
--   R1 (patient safety): an inactive person never counts as present. The cell turns into a gap, the person stays listed
--      in the cell marked `inactive`; reactivating closes the gap again (week and month read the same cells).
--   R2: a time change of a shift type that is used in the plan is refused (`shift_type_in_use`); the stored times stay;
--      a label-only change and a change of an unused type stay possible. «In use» means any assignment, past or future,
--      because the times live on the type: changing them would rewrite past plans as well (named for `po`).
--   R3: an absence covers the whole calendar day. A shift whose span touches an absence day (the night D-1 → D) counts
--      as absent (gap) and cannot be newly assigned; a shift that ends exactly at 00:00 of D does not touch D.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(27);

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

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
create function pg_temp.shift(code text, starts text, ends text) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
    pg_temp.inst(), code, 'Dienst ' || code, starts, ends))
$$;
-- HD-PEN-HAND (0190): a hand assignment of a person without Pensum (or in a home without Wochensoll) names
-- hours_unknown first (warning, confirm or cancel); this fixture is about another rule and confirms it.
create function pg_temp.assign(p text, sh text, d date) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L, %L::text[])',
    pg_temp.inst(), pg_temp.id('st'), pg_temp.id(sh), d, pg_temp.id(p), '{hours_unknown}'))
$$;
create function pg_temp.cell(d date, sh text) returns jsonb language sql as $$
  select c from jsonb_array_elements(pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)',
    pg_temp.inst(), d, d)) -> 'cells') c
  where c ->> 'station_id' = pg_temp.id('st')::text and c ->> 'shift_type_id' = pg_temp.id(sh)::text
$$;
create function pg_temp.person_in(c jsonb, p text) returns jsonb language sql as $$
  select a from jsonb_array_elements(c -> 'assigned') a where a ->> 'staff_id' = pg_temp.id(p)::text
$$;

-- Fixture through the lead's own commands: one station, a day shift F, a night N, an evening E ending at midnight,
-- an unused shift U; requirement F and N: 1 person, 1 HF. Staff: HF X, HF Y.
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'Station R159')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.shift('RF', '07:00', '15:30') ->> 'shift_type_id')::uuid;
insert into ids select 'n', (pg_temp.shift('RN', '22:30', '07:15') ->> 'shift_type_id')::uuid;
insert into ids select 'e', (pg_temp.shift('RE', '16:00', '00:00') ->> 'shift_type_id')::uuid;
insert into ids select 'u', (pg_temp.shift('RU', '08:00', '12:00') ->> 'shift_type_id')::uuid;
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 1, %L, 1)',
  pg_temp.inst(), pg_temp.id('st'), pg_temp.id(sh), 'nurse_hf_fh')) from unnest(array['f', 'n']) sh;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'R159 Iks', 'nurse_hf_fh')) ->> 'staff_id')::uuid;
insert into ids select 'y', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'R159 Ypsilon', 'nurse_hf_fh')) ->> 'staff_id')::uuid;
select is((select count(*)::int from ids where v is not null), 7, 'fixture: station, four shift types, two HF persons');

-- R1 ------------------------------------------------------------------------------------------------------------------
select is(pg_temp.assign('x', 'f', '2030-03-04') ->> 'result', 'ok', 'R1: X (HF) is assigned to Monday F');
select is(pg_temp.cell('2030-03-04', 'f') ->> 'status', 'ok', 'R1: 1 of 1 with HF: ok');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_active(%L, false)', pg_temp.id('x'))) ->> 'result',
          'ok', 'R1: the lead sets X inactive');
select is(pg_temp.cell('2030-03-04', 'f') ->> 'status', 'gap', 'R1: an inactive person never counts as present: the cell is a gap');
select is((pg_temp.cell('2030-03-04', 'f') ->> 'present')::int, 0, 'R1: present = 0');
select is((pg_temp.cell('2030-03-04', 'f') ->> 'grade_present')::int, 0, 'R1: grade_present = 0 (the HF is not counted)');
select is(pg_temp.person_in(pg_temp.cell('2030-03-04', 'f'), 'x') ->> 'inactive', 'true',
          'R1: the person stays listed in the cell, marked inactive');
select is((select count(*)::int from jsonb_array_elements(pg_temp.cmd(pg_temp.lead(), format(
            'select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2030-03-01', '2030-03-31')) -> 'cells') c
           where c ->> 'status' = 'gap' and c ->> 'date' = '2030-03-04' and c ->> 'shift_type_id' = pg_temp.id('f')::text),
          1, 'R1: the month read (same function) shows the same gap');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_active(%L, true)', pg_temp.id('x'))) ->> 'result',
          'ok', 'R1: the lead sets X active again');
select is(pg_temp.cell('2030-03-04', 'f') ->> 'status', 'ok', 'R1: reactivated, the cell is ok again');
select is(pg_temp.person_in(pg_temp.cell('2030-03-04', 'f'), 'x') ->> 'inactive', 'false', 'R1: no longer marked inactive');

-- R2 ------------------------------------------------------------------------------------------------------------------
select is(pg_temp.shift('RF', '06:30', '15:00') -> 'problems' ->> 0, 'shift_type_in_use',
          'R2: a time change of a shift type in use is refused');
select is((select to_char(starts_at, 'HH24:MI') || '-' || to_char(ends_at, 'HH24:MI') from public.institution_shift_types
           where id = pg_temp.id('f')), '07:00-15:30', 'R2: the stored times stay unchanged');
select is(pg_temp.shift('RF', '07:00', '15:30') ->> 'result', 'ok', 'R2: the same times with a new label are accepted');
select is(pg_temp.shift('RU', '08:30', '12:30') ->> 'result', 'ok', 'R2: an unused shift type may change its times');
select is(pg_temp.assign('y', 'u', '2020-01-06') ->> 'result', 'ok', 'R2: Y is assigned to U on a past day');
select is(pg_temp.shift('RU', '09:00', '13:00') -> 'problems' ->> 0, 'shift_type_in_use',
          'R2: a type used only in the past is refused too (its times are part of the past plan)');

-- R3 ------------------------------------------------------------------------------------------------------------------
select is(pg_temp.assign('y', 'n', '2030-03-10') ->> 'result', 'ok', 'R3: Y is assigned to the night Sunday 10 → Monday 11');
select is(pg_temp.assign('y', 'e', '2030-03-09') ->> 'result', 'ok', 'R3: Y is assigned to E Saturday 9, 16:00–00:00');
select is((pg_temp.cmd(pg_temp.lead(), format('select public.institution_record_absence(%L, %L, %L, %L)',
          pg_temp.inst(), pg_temp.id('y'), '2030-03-11', '2030-03-12')) ->> 'affected_assignments')::int, 1,
          'R3: an absence from Monday 11 reports the night into it as affected');
select is(pg_temp.cell('2030-03-10', 'n') ->> 'status', 'gap', 'R3: the night D-1 → D counts as absent: gap');
select is(pg_temp.person_in(pg_temp.cell('2030-03-10', 'n'), 'y') ->> 'absent', 'true', 'R3: Y is marked absent in that night');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_unassign_staff(%L)',
          pg_temp.person_in(pg_temp.cell('2030-03-10', 'n'), 'y') ->> 'assignment_id')) ->> 'result', 'ok',
          'R3: the planner removes Y from that night');
select is(pg_temp.assign('y', 'n', '2030-03-10') -> 'problems' ->> 0, 'staff_absent',
          'R3: a night into an absence day cannot be newly assigned');
select is(pg_temp.person_in(pg_temp.cell('2030-03-09', 'e'), 'y') ->> 'absent', 'false',
          'R3: a shift ending exactly at 00:00 of the absence day does not touch it');
select is(pg_temp.assign('x', 'n', '2030-03-10') ->> 'result', 'ok', 'R3: another person (not absent) takes that night');

select * from finish();
rollback;
