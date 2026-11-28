-- HD-3a-F3 (brief docs/agents/briefs/HD-3a-F3.md, founder FE-135 option A; ADR-231; migration 0189): the monthly target
-- per person and calendar month, entered by the home lead.
--   1. writer public.institution_set_monthly_target: enter, change, delete with audit old/new; refusal shapes (negative,
--      zero, over the bound, not a first day, missing or stale shown value -> nothing written, no audit event);
--   2. permissions: planner, viewer, non-member, lead of another home, lead whose access ended (LEAVE1-3) and anon
--      cannot write; authenticated has no table privilege (RLS on, no grant);
--   3. rule R-m in private.institution_rule_breaches: with a target the month is the condition (equal passes, one more
--      shift refuses with month_target_full) and R-h is not applied; without a target R-h is unchanged (pensum_full);
--      a night across the month end counts to its work date's month; the pause of a split shift is not counted;
--   4. hard rules unchanged with a target: rest, days in a row, shift model (warnings), absence and double booking
--      (blocks);
--   5. «übernehmen»: weder Monatssoll noch Pensum -> pensum_missing (fail closed); with a target and no Pensum the row
--      is saved and checked by R-m;
--   6. institution_plan month_targets (T-1): target, planned, remaining, comparison (weekly budget x days / 7) and
--      deviates (every deviation while the threshold is empty, none above a set threshold, NULL without comparison);
--   7. threshold writer public.institution_set_monthly_target_threshold: lead only, input check, stale value, audit.
-- The serialisation of a target change with an assignment of the same person (two sessions) is case K in
-- scripts/db-concurrency/home-plan-assign.sh; here the catalogue proves the shared first lock. Synthetic data only;
-- rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(55);

create function pg_temp.exp_limits(i uuid) returns jsonb language sql as $exp$
  select jsonb_build_object('min_rest_hours', h.min_rest_hours, 'max_consecutive_days', h.max_consecutive_days,
                            'weekly_target_hours', h.weekly_target_hours) from public.institutions h where h.id = i $exp$;
create function pg_temp.exp_staff(s uuid) returns jsonb language sql as $exp$
  select jsonb_build_object('pensum_pct', p.pensum_pct, 'shift_model', p.shift_model)
  from public.institution_staff p where p.id = s $exp$;
create function pg_temp.exp_class(t uuid) returns jsonb language sql as $exp$
  select jsonb_build_object('shift_class', x.shift_class) from public.institution_shift_types x where x.id = t $exp$;

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a187-0000000000' || n)::uuid $$;
-- M: a calendar month far from the seed and the other tests (the first month starting after today + 200 days).
create function pg_temp.m() returns date language sql as $$
  select (date_trunc('month', ((private.at_zurich(private.now()))::date + 200)::timestamp) + interval '1 month')::date $$;
create function pg_temp.md(n int) returns date language sql as $$ select pg_temp.m() + n $$;  -- day n+1 of M
create function pg_temp.mlast() returns date language sql as $$ select (pg_temp.m() + interval '1 month')::date - 1 $$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select k, (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3aF3t ' || k, 'fage_efz')) ->> 'staff_id')::uuid
  from (values ('p'), ('q'), ('r'), ('s'), ('t'), ('w')) v(k);
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3aF3t Station')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'F3F', 'HD3aF3t Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids select 'n', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'F3N', 'HD3aF3t Nacht', '21:00', '07:00')) ->> 'shift_type_id')::uuid;
insert into ids values ('a1', pg_temp.u('a1')), ('a2', pg_temp.u('a2'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L, %L::jsonb)', pg_temp.id('f'), 'early', pg_temp.exp_class(pg_temp.id('f'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L, %L::jsonb)', pg_temp.id('n'), 'night', pg_temp.exp_class(pg_temp.id('n'))));
-- P, Q, S, T: Pensum 10 % (R-h = floor(10 x 2520 / 100) = 252 minutes per week: one early shift of 510 breaks it).
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 10, %L, %L::jsonb)', pg_temp.id(k), 'any', pg_temp.exp_staff(pg_temp.id(k))))
  from (values ('p'), ('q'), ('s'), ('t')) v(k);
-- W: Pensum 100 % (comparison value test). R: no Pensum.
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L, %L::jsonb)', pg_temp.id('w'), 'any', pg_temp.exp_staff(pg_temp.id('w'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 6, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f')));

create function pg_temp.fmin() returns int language sql as $$
  select private.institution_shift_minutes(pg_temp.m(), '07:00', '15:30', null, null)::int $$;
create function pg_temp.target_of(person text) returns int language sql as $$
  select target_minutes from public.institution_monthly_targets where staff_id = pg_temp.id(person) and period_month = pg_temp.m() $$;
create function pg_temp.set_target(p_user text, person text, p_month date, p_minutes int, p_expected jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_monthly_target(%L, %L, %s, %L::jsonb)',
    pg_temp.id(person), p_month, coalesce(p_minutes::text, 'null'), p_expected))
$$;
-- «what the screen showed» = the current target (as the test owner; authenticated cannot read the table).
create function pg_temp.exp_target(person text, p_month date) returns jsonb language sql as $$
  select jsonb_build_object('target_minutes', (select target_minutes from public.institution_monthly_targets
                                               where staff_id = pg_temp.id(person) and period_month = p_month))
$$;
create function pg_temp.lead_target(person text, p_minutes int) returns jsonb language sql as $$
  select pg_temp.set_target(pg_temp.lead(), person, pg_temp.m(), p_minutes, pg_temp.exp_target(person, pg_temp.m()))
$$;
create function pg_temp.audits(person text) returns bigint language sql as $$
  select count(*) from public.institution_audit_events
  where command = 'institution_set_monthly_target' and changed ->> 'staff_id' = pg_temp.id(person)::text
$$;
create function pg_temp.assign(person text, typ text, p_date date) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L, null)',
    pg_temp.inst(), pg_temp.id('st'), pg_temp.id(typ), p_date, pg_temp.id(person)))
$$;
create function pg_temp.store(person text, typ text, p_date date) returns void language sql as $$
  insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id)
  values (pg_temp.inst(), pg_temp.id('st'), pg_temp.id(typ), p_date, pg_temp.id(person))
$$;
create function pg_temp.breaches(person text, typ text, p_date date) returns text[] language sql as $$
  select private.institution_rule_breaches(pg_temp.id(person), pg_temp.id(typ), p_date, null)
$$;

-- 1. Writer -----------------------------------------------------------------------------------------------------------
select is(pg_temp.id('p') is not null and pg_temp.id('st') is not null and pg_temp.id('n') is not null, true,
          'fixture: persons, station and shift types were created by the commands');
select is(pg_temp.lead_target('p', 2 * pg_temp.fmin()), '{"result": "ok"}'::jsonb,
          'the lead enters a monthly target for P and month M');
select is(pg_temp.target_of('p'), 2 * pg_temp.fmin(), 'the target is stored in working minutes');
select is((select changed from public.institution_audit_events where command = 'institution_set_monthly_target'
           and changed ->> 'staff_id' = pg_temp.id('p')::text),
          jsonb_build_object('staff_id', pg_temp.id('p'), 'month', pg_temp.m(),
                             'target_minutes', jsonb_build_object('old', null, 'new', 2 * pg_temp.fmin())),
          'one audit event names person, month and old/new value');
select is(pg_temp.lead_target('p', 2 * pg_temp.fmin()), '{"result": "ok"}'::jsonb, 'the same value again answers ok');
select is(pg_temp.audits('p'), 1::bigint, 'and writes no second audit event (nothing changed)');
select is(pg_temp.lead_target('p', -60) || pg_temp.lead_target('p', 0) || jsonb_build_object('x', pg_temp.lead_target('p', 44641)),
          '{"result": "invalid", "problems": ["target_not_valid"], "x": {"result": "invalid", "problems": ["target_not_valid"]}}'::jsonb,
          'negative, zero and more than 31 days of minutes are refused with target_not_valid (T-2)');
select is(pg_temp.set_target(pg_temp.lead(), 'p', pg_temp.md(1), 600, '{"target_minutes": null}'),
          '{"result": "invalid", "problems": ["month_not_valid"]}'::jsonb, 'a month not named by its first day is refused');
select is(pg_temp.set_target(pg_temp.lead(), 'p', pg_temp.m(), 600, '{}') || jsonb_build_object('y',
            pg_temp.set_target(pg_temp.lead(), 'p', pg_temp.m(), 600, '{"target_minutes": "1020"}')),
          '{"result": "invalid", "problems": ["expected_not_valid"], "y": {"result": "invalid", "problems": ["expected_not_valid"]}}'::jsonb,
          'a missing or non-number shown value is refused with expected_not_valid');
select is(pg_temp.set_target(pg_temp.lead(), 'p', pg_temp.m(), 600, '{"target_minutes": 999}'),
          '{"result": "conflict", "problems": ["changed_meanwhile"]}'::jsonb,
          'a target changed since the form was shown is never overwritten: changed_meanwhile');
select is(pg_temp.target_of('p') || '/' || pg_temp.audits('p'), (2 * pg_temp.fmin()) || '/1',
          'every refusal wrote nothing and no audit event');
-- Change and delete on Q (then Q has no target again for the R-h regression below).
select is(pg_temp.lead_target('q', 900), '{"result": "ok"}'::jsonb, 'enter a target for Q');
select is(pg_temp.lead_target('q', 1200), '{"result": "ok"}'::jsonb, 'then change it');
select is(pg_temp.target_of('q'), 1200, 'the change is stored');
select is(pg_temp.lead_target('q', null), '{"result": "ok"}'::jsonb, 'NULL deletes the target');
select is(pg_temp.target_of('q') is null and pg_temp.audits('q') = 3, true,
          'the target is gone; enter, change and delete are three audit events');
select is((select changed -> 'target_minutes' from public.institution_audit_events
           where command = 'institution_set_monthly_target' and changed ->> 'staff_id' = pg_temp.id('q')::text
           order by id desc limit 1), '{"old": 1200, "new": null}'::jsonb, 'the delete is audited with old/new');

-- 2. Permissions --------------------------------------------------------------------------------------------------------
insert into auth.users (id, email) values (pg_temp.u('b1'), 'v.hd3af3@navora.test'), (pg_temp.u('b2'), 'l.hd3af3@navora.test'),
  (pg_temp.u('b3'), 'p.hd3af3@navora.test'), (pg_temp.u('b4'), 'e.hd3af3@navora.test'), (pg_temp.u('b5'), 'n.hd3af3@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('c1'), 'Testheim HD-3a-F3 (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.inst(), pg_temp.u('b1'), 'viewer'), (pg_temp.u('c1'), pg_temp.u('b2'), 'lead'),
  (pg_temp.inst(), pg_temp.u('b3'), 'planner'), (pg_temp.inst(), pg_temp.u('b4'), 'lead');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('b4'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('b4'), 'ended', 'employment_ended', pg_temp.u('b2'));
select is(pg_temp.set_target(pg_temp.u('b3')::text, 'p', pg_temp.m(), 600, pg_temp.exp_target('p', pg_temp.m())),
          '{"result": "rejected"}'::jsonb, 'a planner of the home cannot set a monthly target (lead only, brief)');
select is(pg_temp.set_target(pg_temp.u('b1')::text, 'p', pg_temp.m(), 600, pg_temp.exp_target('p', pg_temp.m())),
          '{"result": "rejected"}'::jsonb, 'a viewer cannot');
select is(pg_temp.set_target(pg_temp.u('b5')::text, 'p', pg_temp.m(), 600, pg_temp.exp_target('p', pg_temp.m())),
          '{"result": "rejected"}'::jsonb, 'a signed-in user without membership cannot');
select is(pg_temp.set_target(pg_temp.u('b2')::text, 'p', pg_temp.m(), 600, pg_temp.exp_target('p', pg_temp.m())),
          '{"result": "rejected"}'::jsonb, 'the lead of another home cannot');
select ok(coalesce(pg_temp.set_target(pg_temp.u('b4')::text, 'p', pg_temp.m(), 600, pg_temp.exp_target('p', pg_temp.m())) ->> 'result', 'x')
          <> 'ok', 'a lead of this home whose access ended cannot (LEAVE1-3)');
select is(pg_temp.target_of('p') || '/' || pg_temp.audits('p'), (2 * pg_temp.fmin()) || '/1',
          'no refused caller changed the target or wrote an audit event');
select ok(not has_function_privilege('anon', 'public.institution_set_monthly_target(uuid, date, integer, jsonb)', 'execute')
          and not has_function_privilege('anon', 'public.institution_set_monthly_target_threshold(uuid, numeric, jsonb)', 'execute'),
          'anon has no execute on the two new commands');
select ok(not has_table_privilege('authenticated', 'public.institution_monthly_targets', 'select')
          and not has_table_privilege('authenticated', 'public.institution_monthly_targets', 'insert')
          and not has_table_privilege('authenticated', 'public.institution_monthly_targets', 'update')
          and not has_table_privilege('authenticated', 'public.institution_monthly_targets', 'delete')
          and (select relrowsecurity from pg_class where oid = 'public.institution_monthly_targets'::regclass),
          'authenticated has no table privilege; RLS is on');
select ok((select bool_and(prosecdef and proconfig @> array['search_path=""']) from pg_proc
           where oid in ('public.institution_set_monthly_target(uuid, date, integer, jsonb)'::regprocedure,
                         'public.institution_set_monthly_target_threshold(uuid, numeric, jsonb)'::regprocedure)),
          'both commands are security definer with an empty search_path');

-- 3. Rule R-m --------------------------------------------------------------------------------------------------------------
-- P: Pensum 10 % (R-h 252 min/week) but target 2 early shifts in M. Two shifts in one ISO week pass (R-h not applied).
select is(pg_temp.assign('p', 'f', pg_temp.md(7)) ->> 'result', 'ok', 'with a target the first shift is saved (R-h not applied)');
select is(pg_temp.assign('p', 'f', pg_temp.md(8)) ->> 'result', 'ok', 'the second shift reaches the target exactly and is saved');
select is(pg_temp.assign('p', 'f', pg_temp.md(10)), '{"result": "warning", "rules": ["month_target_full"]}'::jsonb,
          'one more shift goes over the target: month_target_full, nothing saved without confirmation');
select is(pg_temp.breaches('p', 'f', (pg_temp.m() + interval '1 month')::date + 7), '{pensum_full}'::text[],
          'in the next month (no target there) R-h holds again for P');
-- Q: Pensum 10 %, no target -> R-h unchanged.
select is(pg_temp.breaches('q', 'f', pg_temp.md(7)), '{pensum_full}'::text[], 'without a target R-h is unchanged (pensum_full)');
-- One minute boundary: target = one shift + 0 -> a second shift refuses; target raised by the shift length passes.
select pg_temp.lead_target('t', pg_temp.fmin());
select pg_temp.store('t', 'f', pg_temp.md(14));
select is(pg_temp.breaches('t', 'f', pg_temp.md(15)), '{month_target_full}'::text[], 'target = planned: one more shift refuses');
select pg_temp.lead_target('t', 2 * pg_temp.fmin() - 1);
select is(pg_temp.breaches('t', 'f', pg_temp.md(15)), '{month_target_full}'::text[], 'one minute short still refuses');
select pg_temp.lead_target('t', 2 * pg_temp.fmin());
select is(pg_temp.breaches('t', 'f', pg_temp.md(15)), '{}'::text[], 'equal to the target passes');
-- S: a night on the last day of M counts to M (its work date), not to the next month.
select pg_temp.lead_target('s', private.institution_shift_minutes(pg_temp.mlast(), '21:00', '07:00', null, null)::int);
select is(pg_temp.breaches('s', 'n', pg_temp.mlast()), '{}'::text[], 'a night on the last day of M fits a target of exactly one night');
select pg_temp.store('s', 'n', pg_temp.mlast());
select is(pg_temp.breaches('s', 'f', pg_temp.md(2)), '{month_target_full}'::text[],
          'that night counts to M: another shift in M goes over the target');
-- Split shift: the pause is not working time (07:00-11:00 + 16:00-20:00 = 8 h).
insert into ids select 'sp', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_split_shift_type(%L, %L, %L, %L, %L, %L, %L)',
  pg_temp.inst(), 'F3G', 'HD3aF3t Geteilt', '07:00', '11:00', '16:00', '20:00')) ->> 'shift_type_id')::uuid;
select pg_temp.lead_target('w', 480);
select is(pg_temp.breaches('w', 'sp', pg_temp.md(20)), '{}'::text[],
          'a split shift of 2 x 4 h fits a target of 480 minutes (the 5 h pause is not counted)');

-- 4. Hard rules unchanged with a target ------------------------------------------------------------------------------------
select pg_temp.lead_target('w', 44640);  -- a target that never binds
select pg_temp.store('w', 'n', pg_temp.md(3));
select is(pg_temp.breaches('w', 'f', pg_temp.md(4)), '{rest}'::text[], 'rest time (11 h) still breaks with a target');
select pg_temp.store('w', 'f', pg_temp.md(21 + k)) from generate_series(0, 5) k;
select is(pg_temp.breaches('w', 'f', pg_temp.md(27)), '{consecutive}'::text[], 'more than 6 days in a row still breaks with a target');
select is(pg_temp.assign('w', 'f', pg_temp.md(21)) -> 'problems', '["already_assigned"]'::jsonb, 'double booking is still blocked');
insert into public.institution_absences (institution_id, staff_id, starts_on, ends_on)
  values (pg_temp.inst(), pg_temp.id('w'), pg_temp.md(12), pg_temp.md(12));
select is(pg_temp.assign('w', 'f', pg_temp.md(12)) -> 'problems', '["staff_absent"]'::jsonb, 'an absence still blocks');
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L, %L::jsonb)', pg_temp.id('w'), 'night_only', pg_temp.exp_staff(pg_temp.id('w'))));
select is(pg_temp.breaches('w', 'f', pg_temp.md(16)), '{shift_model}'::text[], 'the shift model still breaks with a target');
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L, %L::jsonb)', pg_temp.id('w'), 'any', pg_temp.exp_staff(pg_temp.id('w'))));

-- 5. «übernehmen»: weder Monatssoll noch Pensum ---------------------------------------------------------------------------
create function pg_temp.dr(person text, p_date date) returns jsonb language sql as $$
  select jsonb_build_object('date', p_date::text, 'station_id', pg_temp.id('st'), 'shift_type_id', pg_temp.id('f'),
                            'staff_id', pg_temp.id(person))
$$;
create function pg_temp.apply(k text, p_rows jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)',
    pg_temp.inst(), pg_temp.id(k), p_rows))
$$;
select is((select x ->> 'reason' from jsonb_array_elements(pg_temp.apply('a1', jsonb_build_array(pg_temp.dr('r', pg_temp.md(5)))) -> 'refused') x),
          'pensum_missing', 'R without Pensum and without target: the row is refused with pensum_missing (fail closed)');
select pg_temp.lead_target('r', pg_temp.fmin());
select is(pg_temp.apply('a2', jsonb_build_array(pg_temp.dr('r', pg_temp.md(5)), pg_temp.dr('r', pg_temp.md(6)))) -> 'refused',
          jsonb_build_array(jsonb_build_object('staff_id', pg_temp.id('r')::text, 'date', pg_temp.md(6)::text,
            'station_id', pg_temp.id('st')::text, 'shift_type_id', pg_temp.id('f')::text, 'reason', 'planning_rule',
            'rules', '["month_target_full"]'::jsonb)),
          'with a target and no Pensum the first row is saved and the second refused by R-m (month_target_full)');

-- 6. institution_plan month_targets ---------------------------------------------------------------------------------------
create function pg_temp.mt(person text) returns jsonb language sql as $$
  select x from jsonb_array_elements(
    (pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), pg_temp.m(), pg_temp.mlast())))
    -> 'month_targets') x
  where x ->> 'staff_id' = pg_temp.id(person)::text and x ->> 'month' = pg_temp.m()::text
$$;
create function pg_temp.cmp(pct int) returns int language sql as $$
  select round(floor(pct * 2520 / 100.0) * extract(day from pg_temp.mlast()) / 7)::int $$;
select is(pg_temp.mt('p') - 'deviates', jsonb_build_object('staff_id', pg_temp.id('p'), 'month', pg_temp.m(),
            'target_minutes', 2 * pg_temp.fmin(), 'planned_minutes', 2 * pg_temp.fmin(), 'remaining_minutes', 0,
            'comparison_minutes', pg_temp.cmp(10)),
          'plan: target, planned (both saved shifts), remaining 0 and the comparison value of P');
select is((pg_temp.mt('p') ->> 'deviates')::boolean, true, 'with an empty threshold every deviation is shown');
select is(pg_temp.mt('q') ->> 'target_minutes', null, 'Q has no target: target and remaining NULL');
select is((pg_temp.mt('r') -> 'comparison_minutes') || (pg_temp.mt('r') -> 'deviates'), '[null, null]'::jsonb,
          'R has no Pensum: no comparison and no deviation flag (never a guessed value)');
select pg_temp.lead_target('q', pg_temp.cmp(10));
select is((pg_temp.mt('q') ->> 'deviates')::boolean, false, 'negative: a target equal to the comparison value shows no warning');

-- 7. Threshold writer ------------------------------------------------------------------------------------------------------
create function pg_temp.thr(p_user text, p_hours text, p_expected jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_monthly_target_threshold(%L, %s, %L::jsonb)',
    pg_temp.inst(), p_hours, p_expected))
$$;
select is(pg_temp.thr(pg_temp.u('b3')::text, '100', '{"monthly_target_deviation_hours": null}'), '{"result": "rejected"}'::jsonb,
          'a planner cannot set the threshold');
select is(pg_temp.thr(pg_temp.lead(), '-1', '{"monthly_target_deviation_hours": null}') || jsonb_build_object('z',
            pg_temp.thr(pg_temp.lead(), '1.005', '{"monthly_target_deviation_hours": null}')),
          '{"result": "invalid", "problems": ["threshold_not_valid"], "z": {"result": "invalid", "problems": ["threshold_not_valid"]}}'::jsonb,
          'a negative threshold or one with three decimals is refused');
select is(pg_temp.thr(pg_temp.lead(), '100', '{"monthly_target_deviation_hours": 5}'),
          '{"result": "conflict", "problems": ["changed_meanwhile"]}'::jsonb, 'a stale shown threshold is refused');
select is(pg_temp.thr(pg_temp.lead(), '100', '{"monthly_target_deviation_hours": null}'), '{"result": "ok"}'::jsonb,
          'the lead sets a threshold of 100 h');
select is((pg_temp.mt('p') ->> 'deviates')::boolean, false, 'a deviation below the threshold shows no warning');
select is((select count(*) from public.institution_audit_events where command = 'institution_set_monthly_target_threshold'
           and entity_id = pg_temp.inst()), 1::bigint, 'the threshold change is audited once');

select * from finish();
rollback;
