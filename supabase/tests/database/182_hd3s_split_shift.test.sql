-- HD-3s «Geteilter Dienst (zwei Blöcke) im Heimplan» (brief docs/agents/briefs/HD-3s.md, founder FE-127 (3); migration
-- 0182). Fixed, checkable rules; synthetic data only; rolled back.
--   * shape: V1-V5 as check constraints (tested in this order) and as the command's reason, the same code each time;
--   * write: only the lead of the same home (planner, viewer, another home's lead refused), audit, access end raises,
--     anon no execute; the one-block commands refuse a split type;
--   * rules on the database side: the pause is not working time (R-h), rest counts after block 2 and never between the
--     blocks (R-f, K1), one working day (R-g), a shift inside the pause is `busy` (K3), absence on the work date (R-d),
--     shift models `any` and `no_night` only (R-c); the draft take-over refuses a row against a rule;
--   * minimum staffing: a split shift fills only its own cell, never an early or late gap (fail closed);
--   * «Arbeitstage pro Woche»: default 5, 1-7, lead only, audit, in institution_plan;
--   * a split shift is not orderable (fail closed, HD-3s-F2).
begin;
create extension if not exists pgtap with schema extensions;

select plan(67);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a182-0000000000' || n)::uuid $$;
-- D = the Monday at least a week ahead (all rule tests in one ISO week, all in the future).
create function pg_temp.d(n int) returns date language sql as $$
  select (private.at_zurich(private.now()))::date + 7 + (8 - extract(isodow from (private.at_zurich(private.now()))::date)::int) % 7 + n
$$;

-- Fixture (as owner): planner P and viewer V of home 1; home H2 with lead L2 (and L5, whose access ends).
insert into auth.users (id, email) values (pg_temp.u('01'), 'l2.hd3s@navora.test'), (pg_temp.u('02'), 'v.hd3s@navora.test'),
                                          (pg_temp.u('03'), 'p.hd3s@navora.test'), (pg_temp.u('05'), 'l5.hd3s@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('11'), 'Testheim HD-3s (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.u('11'), pg_temp.u('01'), 'lead'), (pg_temp.inst(), pg_temp.u('02'), 'viewer'),
  (pg_temp.inst(), pg_temp.u('03'), 'planner'), (pg_temp.u('11'), pg_temp.u('05'), 'lead');

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
create function pg_temp.split(p_user text, p_inst uuid, code text, b1s text, b1e text, b2s text, b2e text) returns jsonb
language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_split_shift_type(%L, %L, %L, %L, %L, %L, %L)',
           p_inst, code, 'HD3s ' || code, b1s, b1e, b2s, b2e))
$$;
create function pg_temp.staff(name text, pensum int, model text) returns uuid language plpgsql as $$
declare s uuid;
begin
  s := (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)', pg_temp.inst(), name,
          'fage_efz')) ->> 'staff_id')::uuid;
  perform pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, %s, %L)', s, pensum, model));
  return s;
end $$;
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3s Station')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'SF', 'HD3s Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids select 'f0', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'SF0', 'HD3s Früh früh', '06:30', '14:00')) ->> 'shift_type_id')::uuid;
insert into ids select 'm', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'SM', 'HD3s Mittag', '12:00', '15:00')) ->> 'shift_type_id')::uuid;
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('f'), 'early'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('f0'), 'early'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42)', pg_temp.inst()));
insert into ids values ('x', pg_temp.staff('HD3s Xaver', 100, 'any')), ('y', pg_temp.staff('HD3s Yara', 25, 'any')),
                       ('w', pg_temp.staff('HD3s Wanda', 100, 'early_only')), ('n', pg_temp.staff('HD3s Nora', 100, 'no_night')),
                       ('z', pg_temp.staff('HD3s Zeno', 100, 'any'));

create function pg_temp.assign(shift uuid, day date, staff uuid) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L, null)', pg_temp.inst(),
    pg_temp.id('st'), shift, day, staff))
$$;
create function pg_temp.breaches(staff uuid, shift uuid, day date) returns text[] language sql as $$
  select private.institution_rule_breaches(staff, shift, day, null)
$$;
create function pg_temp.cell(shift uuid, day date) returns jsonb language sql as $$
  select c from jsonb_array_elements(pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)',
           pg_temp.inst(), day, day)) -> 'cells') c
  where c ->> 'shift_type_id' = shift::text and c ->> 'station_id' = pg_temp.id('st')::text
$$;

-- 1. Shape ---------------------------------------------------------------------------------------------------------------
select has_column('public', 'institution_shift_types', 'block1_ends_at', 'a shift type has the end of block 1');
select has_column('public', 'institution_shift_types', 'block2_starts_at', 'a shift type has the start of block 2');
select has_column('public', 'institutions', 'work_days_per_week', 'a home has «Arbeitstage pro Woche»');
select is((select count(*)::int from pg_constraint where conrelid = 'public.institution_shift_types'::regclass
           and conname like 'institution\_shift\_types\_split\_v_\_%'), 5, 'five shape constraints V1-V5');

-- 2. V1-V5: the command names the first failing check; the function and the constraint agree --------------------------
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T1', '07:00:30', '11:30', '16:00', '20:00') -> 'problems' ->> 0,
          'time_format', 'V1 seconds are refused as time_format');
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T1', '07:00', null, '16:00', '20:00') -> 'problems' ->> 0,
          'time_format', 'V1 a missing time is time_format');
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T2', '07:00', '07:00', '16:00', '20:00') -> 'problems' ->> 0,
          'zero_length', 'V2 a block of length 0 is zero_length');
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T3', '22:00', '02:00', '16:00', '20:00') -> 'problems' ->> 0,
          'block_crosses_midnight', 'V3 a block over midnight is block_crosses_midnight');
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T4', '07:00', '11:30', '10:00', '20:00') -> 'problems' ->> 0,
          'block_order', 'V4 block 2 starting inside block 1 is block_order');
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T4', '16:00', '20:00', '07:00', '11:30') -> 'problems' ->> 0,
          'block_order', 'V4 block 2 before block 1 is block_order');
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T5', '07:00', '11:30', '11:30', '20:00') -> 'problems' ->> 0,
          'no_pause', 'V5 block 2 starting when block 1 ends is no_pause');
select is(pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'T6', '07:00', '07:00', '07:00', '07:00') -> 'problems' ->> 0,
          'zero_length', 'order: zero_length before block_order and no_pause');
select is((select count(*)::int from public.institution_shift_types where institution_id = pg_temp.inst() and code like 'T_'),
          0, 'no refused shape was stored');
select throws_like($$insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, block1_ends_at,
                       block2_starts_at, shift_class) values ('00000000-0000-4000-a000-0000000004c1', 'C2', 'c', '07:00', '20:00',
                       '07:00', '16:00', 'split')$$, '%split_v2_zero_length%', 'the database refuses V2 itself');
select throws_like($$insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, block1_ends_at,
                       block2_starts_at, shift_class) values ('00000000-0000-4000-a000-0000000004c1', 'C3', 'c', '07:00', '20:00',
                       '06:00', '16:00', 'split')$$, '%split_v3_block_crosses_midnight%', 'the database refuses V3 itself');
select throws_like($$insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, block1_ends_at,
                       block2_starts_at, shift_class) values ('00000000-0000-4000-a000-0000000004c1', 'C4', 'c', '07:00', '20:00',
                       '11:30', '10:00', 'split')$$, '%split_v4_block_order%', 'the database refuses V4 itself');
select throws_like($$insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, block1_ends_at,
                       block2_starts_at, shift_class) values ('00000000-0000-4000-a000-0000000004c1', 'C5', 'c', '07:00', '20:00',
                       '11:30', '11:30', 'split')$$, '%split_v5_no_pause%', 'the database refuses V5 itself');
select throws_like($$insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, block1_ends_at,
                       block2_starts_at, shift_class) values ('00000000-0000-4000-a000-0000000004c1', 'C1', 'c', '07:00', '20:00',
                       '11:30:15', '16:00', 'split')$$, '%split_v1_time_format%', 'the database refuses V1 itself');
select throws_like($$insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, block1_ends_at,
                       block2_starts_at, shift_class) values ('00000000-0000-4000-a000-0000000004c1', 'C0', 'c', '07:00', '20:00',
                       '11:30', '16:00', 'early')$$, '%split_blocks%', 'two blocks always carry the class split');
select throws_like($$insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, shift_class)
                       values ('00000000-0000-4000-a000-0000000004c1', 'C9', 'c', '07:00', '20:00', 'split')$$,
                   '%split_blocks%', 'the class split always carries two blocks');

-- 3. Write: lead only, same home, audit, access end ----------------------------------------------------------------------
insert into ids select 'sp', (pg_temp.split(pg_temp.lead(), pg_temp.inst(), 'SG', '07:00', '11:30', '16:00', '20:00')
                              ->> 'shift_type_id')::uuid;
select isnt(pg_temp.id('sp'), null, 'the lead creates a split shift 07:00-11:30 and 16:00-20:00');
select is((select row(starts_at, block1_ends_at, block2_starts_at, ends_at, shift_class)::text
           from public.institution_shift_types where id = pg_temp.id('sp')),
          row('07:00'::time, '11:30'::time, '16:00'::time, '20:00'::time, 'split')::text, 'both blocks and the class are stored');
select is((select count(*)::int from public.institution_audit_events where command = 'institution_set_split_shift_type'
           and entity_id = pg_temp.id('sp')), 1, 'one audit event');
select is(pg_temp.split(pg_temp.u('03')::text, pg_temp.inst(), 'SP', '07:00', '11:30', '16:00', '20:00') ->> 'result',
          'rejected', 'a planner cannot create a shift type (master data: lead only)');
select is(pg_temp.split(pg_temp.u('02')::text, pg_temp.inst(), 'SV', '07:00', '11:30', '16:00', '20:00') ->> 'result',
          'rejected', 'a viewer cannot create one');
select is(pg_temp.split(pg_temp.u('01')::text, pg_temp.inst(), 'SX', '07:00', '11:30', '16:00', '20:00') ->> 'result',
          'rejected', 'the lead of another home cannot create one here');
select is((select count(*)::int from public.institution_shift_types where institution_id = pg_temp.inst()
           and code in ('SP', 'SV', 'SX')), 0, 'nothing refused was stored');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'ended', 'employment_ended', pg_temp.u('01'));
select is(pg_temp.split(pg_temp.u('05')::text, pg_temp.u('11'), 'SE', '07:00', '11:30', '16:00', '20:00') ->> 'sqlstate',
          '42501', 'after the access end the command raises access_ended');
select ok(not has_function_privilege('anon', 'public.institution_set_split_shift_type(uuid, text, text, time, time, time, time)', 'execute')
          and not has_function_privilege('anon', 'public.institution_set_work_days_per_week(uuid, integer)', 'execute')
          and not has_function_privilege('authenticated', 'private.institution_split_problem(time, time, time, time)', 'execute')
          and not has_function_privilege('authenticated', 'private.institution_shift_minutes(date, time, time, time, time)', 'execute'),
          'anon executes neither command; the helpers are private');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)', pg_temp.inst(),
            'SG', 'HD3s SG', '07:00', '15:00')) -> 'problems' ->> 0, 'shift_type_is_split',
          'the one-block command refuses a split type');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('sp'), 'early'))
            -> 'problems' ->> 0, 'shift_type_is_split', 'the class of a split type cannot be changed alone');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('f'), 'split'))
            -> 'problems' ->> 0, 'shift_class_not_valid', 'a one-block type never gets the class split');

-- 4. Rules on the database side ------------------------------------------------------------------------------------------
select is(private.institution_shift_minutes(pg_temp.d(0), '07:00', '20:00', '11:30', '16:00'), 510::numeric,
          'R-h: working minutes 4 h 30 + 4 h, the pause of 4 h 30 not counted');
select is(private.institution_shift_minutes(pg_temp.d(0), '07:00', '15:30', null, null), 510::numeric,
          'R-h: a one-block shift counts its whole span (HD-3a unchanged)');
select is(pg_temp.breaches(pg_temp.id('y'), pg_temp.id('sp'), pg_temp.d(0)), '{}'::text[],
          'R-h: 25 % of 42 h = 630 min takes the split shift (510 min); with the pause (780 min) it would not');
select is(pg_temp.assign(pg_temp.id('sp'), pg_temp.d(0), pg_temp.id('y')) ->> 'result', 'ok', 'and it is saved without a warning');
select is(pg_temp.assign(pg_temp.id('sp'), pg_temp.d(0), pg_temp.id('x')) ->> 'result', 'ok',
          'K1: a split shift alone breaks no rest rule (4 h 30 between its blocks)');
select is(pg_temp.assign(pg_temp.id('m'), pg_temp.d(0), pg_temp.id('x')) -> 'problems' ->> 0, 'staff_overlap',
          'K3: a shift inside the pause is refused as double booking');
select is(pg_temp.breaches(pg_temp.id('x'), pg_temp.id('f'), pg_temp.d(1)), '{}'::text[],
          'R-f: 11 h from the end of block 2 (20:00) to 07:00 the next day is enough');
select is(pg_temp.breaches(pg_temp.id('x'), pg_temp.id('f0'), pg_temp.d(1)), '{rest}'::text[],
          'R-f: 10 h 30 after block 2 (to 06:30) is a rest breach');
select is(pg_temp.breaches(pg_temp.id('x'), pg_temp.id('sp'), pg_temp.d(-1) ) , '{}'::text[],
          'R-f: from the end of block 2 on the day before (20:00) to block 1 (07:00) is 11 h');
select is(pg_temp.breaches(pg_temp.id('w'), pg_temp.id('sp'), pg_temp.d(2)), '{shift_model}'::text[],
          'R-c: «nur Früh» never fits a split shift');
select is(pg_temp.breaches(pg_temp.id('n'), pg_temp.id('sp'), pg_temp.d(2)), '{}'::text[], 'R-c: «keine Nacht» fits it');
update public.institution_staff set shift_model = 'late_only' where id = pg_temp.id('w');
select is(pg_temp.breaches(pg_temp.id('w'), pg_temp.id('sp'), pg_temp.d(2)), '{shift_model}'::text[], 'R-c: «nur Spät» never fits it');
update public.institution_staff set shift_model = 'night_only' where id = pg_temp.id('w');
select is(pg_temp.breaches(pg_temp.id('w'), pg_temp.id('sp'), pg_temp.d(2)), '{shift_model}'::text[], 'R-c: «nur Nacht» never fits it');
update public.institution_staff set shift_model = 'early_only' where id = pg_temp.id('w');
select is(pg_temp.assign(pg_temp.id('sp'), pg_temp.d(2), pg_temp.id('w')) ->> 'result', 'warning',
          'by hand: against the shift model a warning (FE-123 (7)), nothing saved yet');
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_record_absence(%L, %L, %L, %L, %L)', pg_temp.inst(),
  pg_temp.id('x'), pg_temp.d(4), pg_temp.d(4), 'vacation'));
select is(pg_temp.assign(pg_temp.id('sp'), pg_temp.d(4), pg_temp.id('x')) -> 'problems' ->> 0, 'staff_absent',
          'R-d: an absence on the work date refuses the split shift');

-- 5. Take-over of a draft: each row checked with both blocks; minimum staffing only in its own cell ------------------
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 2, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('sp')));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 1, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f')));
create temp table applied as
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)', pg_temp.inst(),
           pg_temp.u('91'), jsonb_build_array(
             jsonb_build_object('date', pg_temp.d(3), 'station_id', pg_temp.id('st'), 'shift_type_id', pg_temp.id('sp'),
                                'staff_id', pg_temp.id('w')),
             jsonb_build_object('date', pg_temp.d(3), 'station_id', pg_temp.id('st'), 'shift_type_id', pg_temp.id('sp'),
                                'staff_id', pg_temp.id('n'))))) as r;
select is((select (r ->> 'applied')::int from applied), 1, 'take-over: the row that keeps every rule is saved');
select is((select r -> 'refused' -> 0 ->> 'reason' from applied), 'planning_rule', 'the row against a rule is refused');
select is((select r -> 'refused' -> 0 -> 'rules' from applied), '["shift_model"]'::jsonb, 'with its rule: shift model');
select is((select count(*)::int from public.institution_assignments where staff_id = pg_temp.id('w')), 0,
          'the refused row is never saved as an override');
select is(pg_temp.cell(pg_temp.id('sp'), pg_temp.d(3)) ->> 'status', 'gap', 'the split cell has 1 of 2: still a gap');
select is(pg_temp.cell(pg_temp.id('f'), pg_temp.d(3)) ->> 'status', 'gap',
          'fail closed: the person in the split shift does not fill the early shift gap of that day');
select is((pg_temp.cell(pg_temp.id('f'), pg_temp.d(3)) ->> 'missing')::int, 1, 'the early shift still misses 1');

-- 6. One working day (R-g): with 2 days in a row allowed, two split shifts on two days are allowed, a third is not -----
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 2, 42)', pg_temp.inst()));
select is(pg_temp.assign(pg_temp.id('sp'), pg_temp.d(0), pg_temp.id('z')) ->> 'result', 'ok', 'R-g: day 1');
select is(pg_temp.breaches(pg_temp.id('z'), pg_temp.id('sp'), pg_temp.d(1)), '{}'::text[],
          'R-g: day 2 is allowed, so one split shift counted as one day');
select is(pg_temp.assign(pg_temp.id('sp'), pg_temp.d(1), pg_temp.id('z')) ->> 'result', 'ok', 'R-g: day 2 saved');
select is(pg_temp.breaches(pg_temp.id('z'), pg_temp.id('sp'), pg_temp.d(2)), '{consecutive}'::text[], 'R-g: day 3 is too many');

-- 7. «Arbeitstage pro Woche» (S5, hint only) -------------------------------------------------------------------------
select is((pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), pg_temp.d(0),
           pg_temp.d(0))) -> 'institution' ->> 'work_days_per_week')::int, 5, 'default 5, shown in the plan');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_work_days_per_week(%L, 4)', pg_temp.inst())) ->> 'result',
          'ok', 'the lead sets 4');
select is((select work_days_per_week from public.institutions where id = pg_temp.inst()), 4, 'stored');
select is((select count(*)::int from public.institution_audit_events where command = 'institution_set_work_days_per_week'
           and entity_id = pg_temp.inst()), 1, 'with one audit event');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_work_days_per_week(%L, 0)', pg_temp.inst())) -> 'problems' ->> 0,
          'work_days_per_week_not_valid', '0 is refused');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_work_days_per_week(%L, 8)', pg_temp.inst())) -> 'problems' ->> 0,
          'work_days_per_week_not_valid', '8 is refused');
select is(pg_temp.cmd(pg_temp.u('03')::text, format('select public.institution_set_work_days_per_week(%L, 3)', pg_temp.inst())) ->> 'result',
          'rejected', 'a planner cannot set it');
select throws_like($$update public.institutions set work_days_per_week = 9 where id = '00000000-0000-4000-a000-0000000004c1'$$,
                   '%work_days_per_week_check%', 'the database refuses 9 itself');

-- 8. Orders (fail closed) ------------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_prepare_gap_order(%L, %L, %L, %L)', pg_temp.inst(),
            pg_temp.id('st'), pg_temp.id('sp'), pg_temp.d(3))) -> 'problems' ->> 0, 'split_shift_not_orderable',
          'a gap in a split shift is not ordered as one time window');

select * from finish();
rollback;
