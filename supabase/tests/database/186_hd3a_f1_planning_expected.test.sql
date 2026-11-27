-- HD-3a-F1 R-6-2 (b) (brief docs/agents/briefs/HD-3a-F1.md, migration 0188): the three planning-input commands take
-- the values the form showed (`p_expected`) and compare them under their row lock.
--   1. signatures: the old forms are gone (one path, no way round the compare), the new ones exist;
--   2. per command: shown = current -> ok, written, one audit event; shown != current -> `conflict` /
--      `changed_meanwhile`, nothing written, no audit event; typed compare (42 = 42.0); «nicht eingetragen» (JSON null)
--      is a value: shown null while a value is stored is a conflict;
--   3. shape: p_expected NULL, not an object, a missing key, a wrong type -> `invalid` / `expected_not_valid`, nothing
--      written (a missing key is not «nicht eingetragen»);
--   4. kept order and guards: membership before the compare (viewer, non-member, another home: rejected even with a
--      matching shown value), range checks keep their codes, planner may set Pensum but not the limits, LEAVE1-3 raises,
--      the split class guard stays (pgTAP 182), anon has no execute; security definer and empty search_path (pgTAP 157).
-- The two-session case (two saves from the same shown value at once) is scripts/db-concurrency/home-plan-assign.sh J.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(36);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a186-0000000000' || n)::uuid $$;

insert into auth.users (id, email) values (pg_temp.u('01'), 'v.hd3af1b@navora.test'), (pg_temp.u('02'), 'p.hd3af1b@navora.test'),
  (pg_temp.u('03'), 'e.hd3af1b@navora.test'), (pg_temp.u('04'), 'n.hd3af1b@navora.test'), (pg_temp.u('05'), 'o.hd3af1b@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('c1'), 'Testheim HD-3a-F1 b (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.inst(), pg_temp.u('01'), 'viewer'), (pg_temp.inst(), pg_temp.u('02'), 'planner'),
  (pg_temp.inst(), pg_temp.u('03'), 'lead'), (pg_temp.u('c1'), pg_temp.u('05'), 'lead');

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3aF1b Iks', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 't', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'XE', 'HD3aF1b Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;

create function pg_temp.audits(cmd text, entity uuid) returns bigint language sql as $$
  select count(*) from public.institution_audit_events where command = cmd and entity_id = entity
$$;
create function pg_temp.limits(p_user text, rest int, days int, weekly text, shown jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_planning_limits(%L, %s, %s, %s, %L::jsonb)',
    pg_temp.inst(), rest, days, weekly, shown))
$$;
create function pg_temp.staff(p_user text, pensum text, model text, shown jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_staff_planning(%L, %s, %L, %L::jsonb)',
    pg_temp.id('x'), pensum, model, shown))
$$;
create function pg_temp.cls(p_user text, c text, shown jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_shift_class(%L, %s, %L::jsonb)',
    pg_temp.id('t'), coalesce(quote_literal(c), 'null'), shown))
$$;
create function pg_temp.code(r jsonb) returns text language sql as $$ select coalesce(r -> 'problems' ->> 0, r ->> 'result', r ->> 'sqlstate') $$;

-- Start values (owner, synthetic): the home 11 h / 6 days / 42 h, the person 100 % any, the type without class.
set local session_replication_role = replica;
update public.institutions set min_rest_hours = 11, max_consecutive_days = 6, weekly_target_hours = 42 where id = pg_temp.inst();
update public.institution_staff set pensum_pct = 100, shift_model = 'any' where id = pg_temp.id('x');
set local session_replication_role = origin;

-- 1. Signatures -------------------------------------------------------------------------------------------------------
select hasnt_function('public', 'institution_set_planning_limits', array['uuid', 'integer', 'integer', 'numeric'],
                      'the limits command without the shown values is gone');
select hasnt_function('public', 'institution_set_staff_planning', array['uuid', 'integer', 'text'],
                      'the staff planning command without the shown values is gone');
select hasnt_function('public', 'institution_set_shift_class', array['uuid', 'text'],
                      'the shift class command without the shown value is gone');
select ok(to_regprocedure('public.institution_set_planning_limits(uuid, integer, integer, numeric, jsonb)') is not null
          and to_regprocedure('public.institution_set_staff_planning(uuid, integer, text, jsonb)') is not null
          and to_regprocedure('public.institution_set_shift_class(uuid, text, jsonb)') is not null,
          'the three commands take p_expected');

-- 2a. Limits ------------------------------------------------------------------------------------------------------------
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, '40',
          '{"min_rest_hours": 11, "max_consecutive_days": 6, "weekly_target_hours": 41}')), 'changed_meanwhile',
          'limits: a shown Wochensoll that is no longer current is refused changed_meanwhile');
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), 42::numeric,
          'limits: nothing written on a conflict');
select is(pg_temp.audits('institution_set_planning_limits', pg_temp.inst()), 0::bigint, 'limits: no audit event on a conflict');
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, '40',
          '{"min_rest_hours": 11, "max_consecutive_days": 6, "weekly_target_hours": null}')), 'changed_meanwhile',
          'limits: «nicht eingetragen» shown while 42 is stored is a conflict, not «no value to compare»');
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, '40',
          '{"min_rest_hours": 12, "max_consecutive_days": 6, "weekly_target_hours": 42}')), 'changed_meanwhile',
          'limits: a changed rest time is a conflict too');
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, '40',
          '{"min_rest_hours": 11, "max_consecutive_days": 6, "weekly_target_hours": 42.0}')), 'ok',
          'limits: shown = current (typed: 42.0 = 42) -> ok');
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), 40::numeric, 'limits: the new value is stored');
select is(pg_temp.audits('institution_set_planning_limits', pg_temp.inst()), 1::bigint, 'limits: one audit event');
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, 'null',
          '{"min_rest_hours": 11, "max_consecutive_days": 6, "weekly_target_hours": 42}')), 'changed_meanwhile',
          'limits: a second save from the old screen (still showing 42) is refused: no silent overwrite');

-- 2b. Staff planning --------------------------------------------------------------------------------------------------
select is(pg_temp.code(pg_temp.staff(pg_temp.lead(), '50', 'any', '{"pensum_pct": 80, "shift_model": "any"}')), 'changed_meanwhile',
          'staff: a shown Pensum that is no longer current is refused');
select is(pg_temp.code(pg_temp.staff(pg_temp.lead(), '50', 'any', '{"pensum_pct": 100, "shift_model": "no_night"}')), 'changed_meanwhile',
          'staff: a shown shift model that is no longer current is refused');
select is((select pensum_pct from public.institution_staff where id = pg_temp.id('x')), 100, 'staff: nothing written on a conflict');
select is(pg_temp.code(pg_temp.staff(pg_temp.u('02')::text, 'null', 'any', '{"pensum_pct": 100, "shift_model": "any"}')), 'ok',
          'staff: a planner saves «nicht eingetragen» from the current shown values');
select is(pg_temp.code(pg_temp.staff(pg_temp.lead(), '60', 'any', '{"pensum_pct": 100, "shift_model": "any"}')), 'changed_meanwhile',
          'staff: the lead''s save from the screen that still showed 100 % is refused (the planner''s change stays)');
select is((select pensum_pct from public.institution_staff where id = pg_temp.id('x')), null::int, 'staff: the planner''s value stands');
select is(pg_temp.code(pg_temp.staff(pg_temp.lead(), '60', 'any', '{"pensum_pct": null, "shift_model": "any"}')), 'ok',
          'staff: shown «nicht eingetragen» = stored NULL -> ok');
select is(pg_temp.audits('institution_set_staff_planning', pg_temp.id('x')), 2::bigint, 'staff: one audit event per saved change only');

-- 2c. Shift class -----------------------------------------------------------------------------------------------------
select is(pg_temp.code(pg_temp.cls(pg_temp.lead(), 'early', '{"shift_class": "late"}')), 'changed_meanwhile',
          'class: a shown class that is no longer current is refused');
select is(pg_temp.code(pg_temp.cls(pg_temp.lead(), 'early', '{"shift_class": null}')), 'ok',
          'class: shown «keine Klasse» = stored NULL -> ok');
select is((select shift_class from public.institution_shift_types where id = pg_temp.id('t')), 'early', 'class: the class is stored');

-- 3. Shape ------------------------------------------------------------------------------------------------------------
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, '30', null)), 'expected_not_valid',
          'shape: no shown values -> expected_not_valid');
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, '30', '{"min_rest_hours": 11, "max_consecutive_days": 6}')),
          'expected_not_valid', 'shape: a missing key is not «nicht eingetragen» -> expected_not_valid');
select is(pg_temp.code(pg_temp.limits(pg_temp.lead(), 11, 6, '30',
          '{"min_rest_hours": "11", "max_consecutive_days": 6, "weekly_target_hours": 40}')), 'expected_not_valid',
          'shape: a number sent as text -> expected_not_valid');
select is(pg_temp.code(pg_temp.staff(pg_temp.lead(), '50', 'any', '[60, "any"]')), 'expected_not_valid',
          'shape: an array instead of an object -> expected_not_valid');
select is(pg_temp.code(pg_temp.cls(pg_temp.lead(), 'late', '{}')), 'expected_not_valid', 'shape: the class key is required');
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst())::text || '/'
          || (select pensum_pct from public.institution_staff where id = pg_temp.id('x'))::text || '/'
          || (select shift_class from public.institution_shift_types where id = pg_temp.id('t')), '40/60/early',
          'shape: none of the refused calls wrote anything');

-- 4. Order and guards ---------------------------------------------------------------------------------------------------
select is(pg_temp.code(pg_temp.staff(pg_temp.u('01')::text, '50', 'any', '{"pensum_pct": 60, "shift_model": "any"}')), 'rejected',
          'guard: a viewer is rejected even with matching shown values');
select is(pg_temp.code(pg_temp.limits(pg_temp.u('02')::text, 11, 6, '30',
          '{"min_rest_hours": 11, "max_consecutive_days": 6, "weekly_target_hours": 40}')), 'rejected',
          'guard: a planner still cannot set the limits');
select is(pg_temp.code(pg_temp.cls(pg_temp.u('05')::text, 'late', '{"shift_class": "early"}')), 'rejected',
          'guard: the lead of another home is rejected');
select is(pg_temp.code(pg_temp.staff(pg_temp.lead(), '5', 'any', '{"pensum_pct": 60, "shift_model": "any"}')), 'pensum_not_valid',
          'guard: the range check keeps its code before the compare');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('03'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('03'), 'ended', 'employment_ended', pg_temp.u('05'));
select is(pg_temp.code(pg_temp.staff(pg_temp.u('03')::text, '50', 'any', '{"pensum_pct": 60, "shift_model": "any"}')), '42501',
          'guard: after the access end the command raises access_ended (LEAVE1-3)');
select ok(not has_function_privilege('anon', 'public.institution_set_planning_limits(uuid, integer, integer, numeric, jsonb)', 'execute')
          and not has_function_privilege('anon', 'public.institution_set_staff_planning(uuid, integer, text, jsonb)', 'execute')
          and not has_function_privilege('anon', 'public.institution_set_shift_class(uuid, text, jsonb)', 'execute'),
          'guard: anon has no execute on the three commands');

select * from finish();
rollback;
