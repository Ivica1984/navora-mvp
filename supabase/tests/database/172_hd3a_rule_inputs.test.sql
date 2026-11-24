-- HD-3a slice 2b (brief docs/agents/briefs/HD.md §5b PO amendment 2026-11-24 19:39, FE-123; migration 0172):
--   * `early_only` replaces `day_only`: the value is gone after the migration and the database refuses it.
--   * Q1: the home's «Sollstunden pro Woche» (`weekly_target_hours`), set by the lead only, 1-80 h input check, NULL
--     = not entered; the 3-argument limits command is gone (one path).
--   * Q2: the class of a shift type (`early`, `late`, `night` or none), set by the lead only; no day class; a class
--     change keeps every assignment and names those that no longer fit the person's model.
--   * the synthetic example: classes, 42 h, Pensum and models, no example shift against a model.
--   * permission: planner, viewer and another home's lead are refused; access end raises (LEAVE1-3); anon no execute;
--     every accepted change writes one audit event.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(41);


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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a172-0000000000' || n)::uuid $$;

create function pg_temp.zurich_today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;

-- Fixture (as owner): home H2 with lead L2 (and L5, whose access ends); viewer V and planner P of home 1; H3 an empty
-- simulation home with lead L6 for the example.
insert into auth.users (id, email) values (pg_temp.u('01'), 'l2.hd3a2@navora.test'), (pg_temp.u('02'), 'v.hd3a2@navora.test'),
                                          (pg_temp.u('03'), 'p.hd3a2@navora.test'), (pg_temp.u('05'), 'l5.hd3a2@navora.test'),
                                          (pg_temp.u('06'), 'l6.hd3a2@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('11'), 'Testheim HD-3a b (synthetisch)', 'home', true),
  (pg_temp.u('13'), 'Testheim HD-3a Beispiel (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.u('11'), pg_temp.u('01'), 'lead'), (pg_temp.inst(), pg_temp.u('02'), 'viewer'),
  (pg_temp.inst(), pg_temp.u('03'), 'planner'), (pg_temp.u('11'), pg_temp.u('05'), 'lead'),
  (pg_temp.u('13'), pg_temp.u('06'), 'lead');
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, ends_at, sort) values
  (pg_temp.u('31'), pg_temp.u('11'), 'Z', 'Zweitheim', '07:00', '15:00', 0);

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Ypsilon', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3a Station')) ->> 'station_id')::uuid;
insert into ids select 't', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'HZ', 'HD3a Zwischen', '10:00', '18:00')) ->> 'shift_type_id')::uuid;
create function pg_temp.planning(p_user text, staff uuid, pensum integer, model text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_staff_planning(%L, %s, %L)',
    staff, coalesce(pensum::text, 'null'), model))
$$;
create function pg_temp.limits(p_user text, inst uuid, hours text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_planning_limits(%L, 11, 6, %s)', inst, hours))
$$;
create function pg_temp.cls(p_user text, t uuid, c text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_shift_class(%L, %s)', t,
    coalesce(quote_literal(c), 'null')))
$$;

-- 1. Schema and the forward migration of day_only -------------------------------------------------------------------
select has_column('public', 'institutions', 'weekly_target_hours', 'a home has its weekly target hours');
select has_column('public', 'institution_shift_types', 'shift_class', 'a shift type has a class');
select is((select count(*)::int from public.institution_staff where shift_model = 'day_only'), 0,
          'no person has day_only after the migration');
select throws_ok(format($$update public.institution_staff set shift_model = 'day_only' where id = %L$$, pg_temp.id('x')),
                 '23514', null, 'the database refuses day_only');
select throws_ok(format($$update public.institution_shift_types set shift_class = 'day' where id = %L$$, pg_temp.id('t')),
                 '23514', null, 'the database refuses a day class');
select throws_ok(format($$update public.institutions set weekly_target_hours = 0 where id = %L$$, pg_temp.inst()),
                 '23514', null, 'the database refuses 0 weekly target hours');
select is(pg_temp.planning(pg_temp.lead(), pg_temp.id('x'), 80, 'day_only') -> 'problems' ->> 0, 'shift_model_not_valid',
          'the command refuses day_only');
select is(pg_temp.planning(pg_temp.lead(), pg_temp.id('x'), 80, 'early_only') ->> 'result', 'ok', 'the command accepts early_only');
select is((select shift_model from public.institution_staff where id = pg_temp.id('x')), 'early_only', 'early_only is stored');

-- 2. Weekly target hours (Q1) -----------------------------------------------------------------------------------------
select hasnt_function('public', 'institution_set_planning_limits', array['uuid', 'integer', 'integer'],
                      'the 3-argument limits command is gone: one path');
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), null,
          'a home without an entry has no weekly target hours (the draft then refuses, fail closed)');
select is(pg_temp.limits(pg_temp.lead(), pg_temp.inst(), '42') ->> 'result', 'ok', 'the lead enters 42 h');
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), 42::numeric, '42 h is stored');
select is(pg_temp.limits(pg_temp.lead(), pg_temp.inst(), '0.5') -> 'problems' ->> 0, 'weekly_target_hours_not_valid',
          '0.5 h is refused');
select is(pg_temp.limits(pg_temp.lead(), pg_temp.inst(), '81') -> 'problems' ->> 0, 'weekly_target_hours_not_valid',
          '81 h is refused');
select is(pg_temp.limits(pg_temp.u('03')::text, pg_temp.inst(), '40') ->> 'result', 'rejected', 'a planner cannot set it');
select is(pg_temp.limits(pg_temp.u('01')::text, pg_temp.inst(), '40') ->> 'result', 'rejected', 'another home''s lead cannot set it');
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), 42::numeric,
          'refused calls change nothing');
select is((select changed -> 'weekly_target_hours' ->> 'new' from public.institution_audit_events
           where command = 'institution_set_planning_limits' and institution_id = pg_temp.inst()), '42',
          'one audit event, carrying the new weekly target hours');
select is(pg_temp.limits(pg_temp.lead(), pg_temp.inst(), 'null') ->> 'result', 'ok', 'the lead can clear it again');
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), null, 'cleared = not entered');

-- 3. Shift class (Q2) -------------------------------------------------------------------------------------------------
select is((select shift_class from public.institution_shift_types where id = pg_temp.id('t')), null,
          'a new shift type has no class (only persons with any)');
select is(pg_temp.cls(pg_temp.lead(), pg_temp.id('t'), 'day') -> 'problems' ->> 0, 'shift_class_not_valid',
          'the command refuses a day class');
select is(pg_temp.cls(pg_temp.u('03')::text, pg_temp.id('t'), 'early') ->> 'result', 'rejected', 'a planner cannot set a class');
select is(pg_temp.cls(pg_temp.u('02')::text, pg_temp.id('t'), 'early') ->> 'result', 'rejected', 'a viewer cannot set a class');
select is(pg_temp.cls(pg_temp.u('01')::text, pg_temp.id('t'), 'early') ->> 'result', 'rejected',
          'another home''s lead cannot set a class');
-- An early_only person tomorrow and on a past day on the unclassified type (by hand; the cell warning follows).
-- Since 0173 the hand assignment names the breach first (Q3); the fixture confirms it.
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L, %L::text[])', pg_temp.inst(),
            pg_temp.id('st'), pg_temp.id('t'), pg_temp.zurich_today() + 1, pg_temp.id('x'), '{shift_model}')) ->> 'result', 'ok',
          'fixture: the early_only person is assigned tomorrow (warning confirmed)');
insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id)
  values (pg_temp.inst(), pg_temp.id('st'), pg_temp.id('t'), pg_temp.zurich_today() - 3, pg_temp.id('x'));
select is(pg_temp.cls(pg_temp.lead(), pg_temp.id('t'), 'late') ->> 'affected_assignments', '1',
          'class late: the one assignment from today on that no longer fits early_only is named (the past one not)');
select is((select count(*)::int from public.institution_assignments where shift_type_id = pg_temp.id('t')), 2,
          'a class change removes no assignment');
select is((select shift_class from public.institution_shift_types where id = pg_temp.id('t')), 'late', 'the class is stored');
select is(pg_temp.cls(pg_temp.lead(), pg_temp.id('t'), 'early') ->> 'affected_assignments', '0',
          'class early: early_only fits again');
select is(pg_temp.cls(pg_temp.lead(), pg_temp.id('t'), null) ->> 'affected_assignments', '1',
          'no class: a restricted model never fits an unclassified type');
select is((select count(*)::int from public.institution_audit_events
           where command = 'institution_set_shift_class' and entity_id = pg_temp.id('t')), 3,
          'each accepted change writes one audit event, a refused one none');
select is((select changed -> 'shift_class' ->> 'old' from public.institution_audit_events
           where command = 'institution_set_shift_class' and entity_id = pg_temp.id('t')
           order by occurred_at desc, id desc limit 1), 'early', 'the audit event carries the old class');

-- 4. The synthetic example (FE-123, «Beispielwert des Heims») ---------------------------------------------------------
select is(pg_temp.cmd(pg_temp.u('06')::text, format('select public.institution_load_example(%L, %L)', pg_temp.u('13'),
            date_trunc('week', pg_temp.zurich_today())::date)) ->> 'result', 'ok', 'fixture: the example is loaded');
select is((select weekly_target_hours from public.institutions where id = pg_temp.u('13')), 42::numeric,
          'the example home has 42 h');
select is((select string_agg(code || '=' || shift_class, ' ' order by sort) from public.institution_shift_types
           where institution_id = pg_temp.u('13')), 'F=early S=late N=night', 'the example shift types carry their class');
select is((select count(*)::int from public.institution_staff where institution_id = pg_temp.u('13') and pensum_pct is null), 0,
          'every example person has a Pensum');
select is((select count(*)::int from public.institution_assignments a
           join public.institution_staff s on s.id = a.staff_id
           join public.institution_shift_types t on t.id = a.shift_type_id
           where a.institution_id = pg_temp.u('13') and not (s.shift_model = 'any'
             or (s.shift_model = 'early_only' and t.shift_class = 'early')
             or (s.shift_model = 'late_only' and t.shift_class = 'late')
             or (s.shift_model = 'night_only' and t.shift_class = 'night')
             or (s.shift_model = 'no_night' and t.shift_class in ('early', 'late')))), 0,
          'no example shift is against the person''s shift model');

-- 5. Access end (LEAVE1-3) and grants ----------------------------------------------------------------------------------
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'ended', 'employment_ended', pg_temp.u('01'));
select is(pg_temp.cls(pg_temp.u('05')::text, pg_temp.u('31'), 'early') ->> 'sqlstate', '42501',
          'after the access end set_shift_class raises access_ended');
select ok(not has_function_privilege('anon', 'public.institution_set_shift_class(uuid, text)', 'execute')
          and not has_function_privilege('anon', 'public.institution_set_planning_limits(uuid, integer, integer, numeric)', 'execute'),
          'anon executes neither command');

select * from finish();
rollback;
