-- HD-3a slice 1 (brief docs/agents/briefs/HD.md §5b, FE-119, FE-120; migration 0171): master data and commands.
--   * absence kind: only `vacation`, `training`, `compensation`, `absent`; any other value is refused by the database
--     (check constraint and command); no reason column; the old 4-argument call records `absent`.
--   * Pensum 10-100 % or not entered, shift model from the fixed list: `institution_set_staff_planning` (lead, planner).
--   * Rest time and consecutive days per home (default 11 h / 6 days, founder parameters, «Arbeitszeitgesetz nicht
--     abschliessend geprüft»): `institution_set_planning_limits` (lead only).
--   * permission: viewer and another home's lead are refused; after the access end every command raises (LEAVE1-3);
--     anon has no execute; every change writes an audit event.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(43);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a171-0000000000' || n)::uuid $$;

-- Fixture (as owner): home H2 with lead L2; a viewer V and a planner P of home 1; L5 lead of H2 whose access ends.
insert into auth.users (id, email) values (pg_temp.u('01'), 'l2.hd3a@navora.test'), (pg_temp.u('02'), 'v.hd3a@navora.test'),
                                          (pg_temp.u('03'), 'p.hd3a@navora.test'), (pg_temp.u('05'), 'l5.hd3a@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('11'), 'Testheim HD-3a (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.u('11'), pg_temp.u('01'), 'lead'), (pg_temp.inst(), pg_temp.u('02'), 'viewer'),
  (pg_temp.inst(), pg_temp.u('03'), 'planner'), (pg_temp.u('11'), pg_temp.u('05'), 'lead');
insert into public.institution_staff (id, institution_id, display_name, grade) values
  (pg_temp.u('21'), pg_temp.u('11'), 'HD3a Zweitheim', 'fage_efz');

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Iks', 'nurse_hf_fh')) ->> 'staff_id')::uuid;
create function pg_temp.absence(p_user text, d1 date, d2 date, kind text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_record_absence(%L, %L, %L, %L, %L)',
    pg_temp.inst(), pg_temp.id('x'), d1, d2, kind))
$$;
create function pg_temp.planning(p_user text, staff uuid, pensum integer, model text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_staff_planning(%L, %s, %L)',
    staff, coalesce(pensum::text, 'null'), model))
$$;
create function pg_temp.limits(p_user text, inst uuid, rest integer, days integer) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_planning_limits(%L, %s, %s)', inst, rest, days))
$$;

-- 1. Schema ------------------------------------------------------------------------------------------------------------
select has_column('public', 'institution_staff', 'pensum_pct', 'staff has a Pensum column');
select has_column('public', 'institution_staff', 'shift_model', 'staff has a shift model column');
select has_column('public', 'institution_absences', 'kind', 'an absence has a kind');
select has_column('public', 'institutions', 'min_rest_hours', 'a home has a minimum rest time');
select has_column('public', 'institutions', 'max_consecutive_days', 'a home has a maximum of consecutive days');
select hasnt_column('public', 'institution_absences', 'reason', 'an absence still has no reason column');
select has_function('public', 'institution_record_absence', array['uuid', 'uuid', 'date', 'date', 'text'],
                    'record_absence takes the kind');
select hasnt_function('public', 'institution_record_absence', array['uuid', 'uuid', 'date', 'date'],
                      'the 4-argument form is gone: one absence path');
select isnt(pg_temp.id('x'), null, 'fixture: the lead adds a HF person');
select is((select shift_model from public.institution_staff where id = pg_temp.id('x')), 'any', 'a new person has shift model any');
select is((select pensum_pct from public.institution_staff where id = pg_temp.id('x')), null, 'a new person has no Pensum entered');
select is((select min_rest_hours from public.institutions where id = pg_temp.inst()), 11, 'default rest time 11 h');
select is((select max_consecutive_days from public.institutions where id = pg_temp.inst()), 6, 'default 6 consecutive days');

-- 2. Absence kind ------------------------------------------------------------------------------------------------------
select throws_ok(format($$insert into public.institution_absences (institution_id, staff_id, starts_on, ends_on, kind)
                         values (%L, %L, '2030-05-01', '2030-05-01', 'sickness')$$, pg_temp.inst(), pg_temp.id('x')),
                 '23514', null, 'the database refuses a kind outside the four (no sickness type)');
select is(pg_temp.absence(pg_temp.lead(), '2030-05-06', '2030-05-06', 'Krankheit') -> 'problems' ->> 0, 'kind_not_valid',
          'the command refuses «Krankheit»');
select is(pg_temp.absence(pg_temp.lead(), '2030-05-06', '2030-05-06', null) -> 'problems' ->> 0, 'kind_not_valid',
          'the command refuses an empty kind');
select is(pg_temp.absence(pg_temp.lead(), '2030-05-06', '2030-05-10', 'vacation') ->> 'result', 'ok', 'the lead records Ferien');
select is((select kind from public.institution_absences where staff_id = pg_temp.id('x') and starts_on = '2030-05-06'), 'vacation',
          'the absence is stored as vacation');
select is(pg_temp.absence(pg_temp.u('03')::text, '2030-06-03', '2030-06-03', 'compensation') ->> 'result', 'ok',
          'the planner records Kompensation');
select is(pg_temp.absence(pg_temp.lead(), '2030-06-10', '2030-06-11', 'training') ->> 'result', 'ok', 'the lead records Weiterbildung');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_record_absence(%L, %L, %L, %L)',
            pg_temp.inst(), pg_temp.id('x'), '2030-07-01', '2030-07-01')) ->> 'result', 'ok',
          'a call without the kind still works');
select is((select kind from public.institution_absences where staff_id = pg_temp.id('x') and starts_on = '2030-07-01'), 'absent',
          'and records the neutral kind absent');
select is(pg_temp.absence(pg_temp.u('02')::text, '2030-08-01', '2030-08-01', 'vacation') ->> 'result', 'rejected',
          'a viewer cannot record an absence');
select is((select changed ->> 'kind' from public.institution_audit_events
           where command = 'institution_record_absence' and changed ->> 'starts_on' = '2030-05-06'), 'vacation',
          'the audit event carries the kind');

-- 3. Pensum and shift model --------------------------------------------------------------------------------------------
select is(pg_temp.planning(pg_temp.lead(), pg_temp.id('x'), 80, 'no_night') ->> 'result', 'ok', 'the lead sets 80 % and no_night');
select is((select pensum_pct || ' ' || shift_model from public.institution_staff where id = pg_temp.id('x')), '80 no_night',
          'Pensum and shift model are stored');
select is(pg_temp.planning(pg_temp.lead(), pg_temp.id('x'), 5, 'any') -> 'problems' ->> 0, 'pensum_not_valid', 'Pensum 5 % is refused');
select is(pg_temp.planning(pg_temp.lead(), pg_temp.id('x'), 101, 'any') -> 'problems' ->> 0, 'pensum_not_valid', 'Pensum 101 % is refused');
select is(pg_temp.planning(pg_temp.lead(), pg_temp.id('x'), 50, 'nights') -> 'problems' ->> 0, 'shift_model_not_valid',
          'an unknown shift model is refused');
select is(pg_temp.planning(pg_temp.u('03')::text, pg_temp.id('x'), null, 'day_only') ->> 'result', 'ok',
          'the planner clears the Pensum and sets day_only');
select is((select coalesce(pensum_pct::text, 'none') || ' ' || shift_model from public.institution_staff where id = pg_temp.id('x')),
          'none day_only', 'a cleared Pensum is stored as not entered');
select is(pg_temp.planning(pg_temp.u('02')::text, pg_temp.id('x'), 60, 'any') ->> 'result', 'rejected', 'a viewer cannot change it');
select is(pg_temp.planning(pg_temp.u('01')::text, pg_temp.id('x'), 60, 'any') ->> 'result', 'rejected',
          'another home''s lead cannot change it');
select is((select count(*)::int from public.institution_audit_events
           where command = 'institution_set_staff_planning' and entity_id = pg_temp.id('x')), 2,
          'each accepted change writes one audit event, a refused one none');

-- 4. Planning limits ---------------------------------------------------------------------------------------------------
select is(pg_temp.limits(pg_temp.lead(), pg_temp.inst(), 12, 5) ->> 'result', 'ok', 'the lead sets 12 h and 5 days');
select is((select min_rest_hours || '/' || max_consecutive_days from public.institutions where id = pg_temp.inst()), '12/5',
          'the limits are stored');
select is(pg_temp.limits(pg_temp.lead(), pg_temp.inst(), 0, 5) -> 'problems' ->> 0, 'limits_not_valid', '0 h rest is refused');
select is(pg_temp.limits(pg_temp.u('03')::text, pg_temp.inst(), 11, 6) ->> 'result', 'rejected', 'a planner cannot set the limits');
select is(pg_temp.limits(pg_temp.u('01')::text, pg_temp.inst(), 11, 6) ->> 'result', 'rejected', 'another home''s lead cannot set them');
select is((select count(*)::int from public.institution_audit_events
           where command = 'institution_set_planning_limits' and institution_id = pg_temp.inst()), 1,
          'one audit event for the accepted change');

-- 5. Access end (LEAVE1-3) and grants ----------------------------------------------------------------------------------
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'ended', 'employment_ended', pg_temp.u('01'));
select is(pg_temp.limits(pg_temp.u('05')::text, pg_temp.u('11'), 11, 6) ->> 'sqlstate', '42501',
          'after the access end set_planning_limits raises access_ended');
select is(pg_temp.planning(pg_temp.u('05')::text, pg_temp.u('21'), 50, 'any') ->> 'sqlstate', '42501',
          'after the access end set_staff_planning raises access_ended');
select ok(not has_function_privilege('anon', 'public.institution_set_staff_planning(uuid, integer, text)', 'execute')
          and not has_function_privilege('anon', 'public.institution_set_planning_limits(uuid, integer, integer)', 'execute')
          and not has_function_privilege('anon', 'public.institution_record_absence(uuid, uuid, date, date, text)', 'execute'),
          'anon executes none of the three commands');

select * from finish();
rollback;
