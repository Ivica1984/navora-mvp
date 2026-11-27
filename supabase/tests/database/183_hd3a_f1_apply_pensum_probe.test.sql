-- PROBE, do not merge (HD-3a-F1, issue #1745, FE-129): red reproduction of the known limit of HD-3a «übernehmen».
-- Facts from the code on recovery/main 9933e26e:
--   * public.institution_apply_draft never reads institution_staff.pensum_pct or institutions.weekly_target_hours;
--   * every row goes through institution_assign_staff -> private.institution_rule_breaches, which skips R-h
--     (minutes per ISO week <= Pensum x Wochensoll) when either value is NULL.
-- So when Pensum or Wochensoll is set to «nicht eingetragen» between «Plan vorschlagen» and «übernehmen», the draft
-- rows are saved without the weekly hours check. The solver would not have planned such a person at all.
--
-- What this probe asserts (behaviour only; the refusal codes are for the HD-3a-F1 contract, not fixed here):
--   section 1 (control, green today): Pensum 100 and Wochensoll 42 entered -> the row is saved. Shows the fixture is
--     valid, so a red section 2 or 3 is the defect and not a broken setup.
--   section 2 (red today): Pensum set to «nicht eingetragen» -> that person's row is not saved and is reported refused;
--     another person's row in the same call is still saved (partial take-over stays).
--   section 3 (red today): Wochensoll set to «nicht eingetragen» -> the call saves no row at all.
-- Not covered: R-6-2 (b) (planning-input forms re-check the shown values under a row lock). That race needs two
-- concurrent sessions and cannot be shown red deterministically inside one pgTAP transaction.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a183-0000000000' || n)::uuid $$;
create function pg_temp.d(n int) returns date language sql as $$ select (private.at_zurich(private.now()))::date + 200 + n $$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select k, (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3aF1 ' || k, 'fage_efz')) ->> 'staff_id')::uuid
  from (values ('p'), ('q'), ('r'), ('s')) v(k);
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3aF1 Station')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'FF', 'HD3aF1 Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids values ('a1', pg_temp.u('a1')), ('a2', pg_temp.u('a2')), ('a3', pg_temp.u('a3'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('f'), 'early'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L)', pg_temp.id(k), 'any'))
  from (values ('p'), ('q'), ('r'), ('s')) v(k);
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42)', pg_temp.inst()));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 4, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f')));

create function pg_temp.dr(person text, n int) returns jsonb language sql as $$
  select jsonb_build_object('date', pg_temp.d(n)::text, 'station_id', pg_temp.id('st'),
                            'shift_type_id', pg_temp.id('f'), 'staff_id', pg_temp.id(person))
$$;
create function pg_temp.apply(k text, p_rows jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)',
    pg_temp.inst(), pg_temp.id(k), p_rows))
$$;
create function pg_temp.has(person text, n int) returns boolean language sql as $$
  select exists (select 1 from public.institution_assignments where staff_id = pg_temp.id(person)
                 and shift_type_id = pg_temp.id('f') and work_date = pg_temp.d(n))
$$;
create temp table res (k text primary key, v jsonb);

-- 1. Control: both values entered -> the row is saved (green today and after the fix) ---------------------------------
insert into res values ('a1', pg_temp.apply('a1', jsonb_build_array(pg_temp.dr('p', 1))));
select is(pg_temp.id('p') is not null and pg_temp.id('st') is not null and pg_temp.id('f') is not null, true,
          'fixture: persons, station and shift type were created by the commands');
select is((select v ->> 'applied' from res where k = 'a1') || '/' || pg_temp.has('p', 1)::text, '1/true',
          'control: with Pensum 100 and Wochensoll 42 the draft row is saved');

-- 2. Pensum set to «nicht eingetragen» after the draft was shown ------------------------------------------------------
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, null, %L)', pg_temp.id('q'), 'any'));
select is((select pensum_pct from public.institution_staff where id = pg_temp.id('q')), null::int,
          'fixture: Q has no Pensum now (set by the command)');
insert into res values ('a2', pg_temp.apply('a2', jsonb_build_array(pg_temp.dr('q', 3), pg_temp.dr('r', 3))));
select ok(not pg_temp.has('q', 3),
          'RED until HD-3a-F1: a row of a person without Pensum is not saved by «übernehmen» (R-6-1, fail closed)');
select ok(pg_temp.has('r', 3) and exists (select 1 from res, jsonb_array_elements(v -> 'refused') x
                                          where k = 'a2' and x ->> 'staff_id' = pg_temp.id('q')::text),
          'RED until HD-3a-F1: the row is reported refused, the other person''s row is still saved');

-- 3. Wochensoll set to «nicht eingetragen» -> the whole call saves nothing -------------------------------------------
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, null)', pg_temp.inst()));
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), null::numeric,
          'fixture: the home has no Wochensoll now (set by the command)');
insert into res values ('a3', pg_temp.apply('a3', jsonb_build_array(pg_temp.dr('r', 5), pg_temp.dr('s', 5))));
select ok(not pg_temp.has('r', 5) and not pg_temp.has('s', 5),
          'RED until HD-3a-F1: without Wochensoll «übernehmen» saves no row at all (R-6-1, fail closed)');

select * from finish();
rollback;
