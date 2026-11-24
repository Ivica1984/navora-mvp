-- HD-3a slice 2c (brief docs/agents/briefs/HD.md §5b PO amendment 2026-11-24 19:39, FE-123 Q3; migration 0173):
-- einteilen von Hand gegen eine Planungsregel = Warnung, Speichern nach Bestätigung, Warnung bleibt sichtbar, Audit.
--   * a rule breach returns `warning` with the rules and writes nothing (no row, no audit event);
--   * a confirmation that does not cover every current rule is a warning again (also when a rule appeared between the
--     two calls); a full confirmation saves the row with override_rules/by/at and one audit event naming the rules;
--   * absence and double booking stay blocked, also with a confirmation;
--   * institution_plan shows the rules broken now and the confirmed ones (one reading with the command);
--   * permission: viewer refused; access end raises (LEAVE1-3); anon has no execute; the 5-argument form is gone.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);


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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a173-0000000000' || n)::uuid $$;

create function pg_temp.d(n int) returns date language sql as $$ select (private.at_zurich(private.now()))::date + n $$;

insert into auth.users (id, email) values (pg_temp.u('01'), 'l2.hd3a3@navora.test'), (pg_temp.u('02'), 'v.hd3a3@navora.test'),
                                          (pg_temp.u('05'), 'l5.hd3a3@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('11'), 'Testheim HD-3a c (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.u('11'), pg_temp.u('01'), 'lead'), (pg_temp.inst(), pg_temp.u('02'), 'viewer'), (pg_temp.u('11'), pg_temp.u('05'), 'lead');

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Zett', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3a Station c')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'CF', 'HD3a Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids select 's', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'CS', 'HD3a Spät', '14:30', '23:00')) ->> 'shift_type_id')::uuid;
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('f'), 'early'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('s'), 'late'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 50, %L)', pg_temp.id('x'), 'early_only'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42)', pg_temp.inst()));

create function pg_temp.assign(p_user text, shift uuid, day date, confirm text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_assign_staff(%L, %L, %L, %L, %L, %s)', pg_temp.inst(),
    pg_temp.id('st'), shift, day, pg_temp.id('x'), coalesce(quote_literal(confirm) || '::text[]', 'null')))
$$;
create function pg_temp.rows(shift uuid, day date) returns int language sql as $$
  select count(*)::int from public.institution_assignments where staff_id = pg_temp.id('x') and shift_type_id = shift and work_date = day
$$;
create function pg_temp.audits() returns int language sql as $$
  select count(*)::int from public.institution_audit_events where command = 'institution_assign_staff' and changed ->> 'staff_id' = pg_temp.id('x')::text
$$;
create function pg_temp.plan_person(shift uuid, day date) returns jsonb language sql as $$
  select a from jsonb_array_elements(pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)',
           pg_temp.inst(), day, day)) -> 'cells') c, jsonb_array_elements(c -> 'assigned') a
  where c ->> 'shift_type_id' = shift::text and a ->> 'staff_id' = pg_temp.id('x')::text
$$;

-- 1. Shape ---------------------------------------------------------------------------------------------------------------
select hasnt_function('public', 'institution_assign_staff', array['uuid', 'uuid', 'uuid', 'date', 'uuid'],
                      'the 5-argument form is gone: one assignment path');
select has_function('public', 'institution_assign_staff', array['uuid', 'uuid', 'uuid', 'date', 'uuid', 'text[]'],
                    'assign takes the confirmed rules');
select has_column('public', 'institution_assignments', 'override_rules', 'an assignment keeps the confirmed rules');
select has_column('public', 'institution_assignments', 'override_by', 'an assignment keeps who confirmed');

-- 2. Warning, then confirmation ----------------------------------------------------------------------------------------
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('s'), pg_temp.d(10), null),
          '{"result": "warning", "rules": ["shift_model"]}'::jsonb, 'early_only on a late shift: a warning naming the rule');
select is(pg_temp.rows(pg_temp.id('s'), pg_temp.d(10)) || '/' || pg_temp.audits(), '0/0', 'the warning writes nothing');
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('s'), pg_temp.d(10), '{rest}') ->> 'result', 'warning',
          'a confirmation of another rule is a warning again');
select is(pg_temp.rows(pg_temp.id('s'), pg_temp.d(10)), 0, 'and still writes nothing');
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('s'), pg_temp.d(10), '{shift_model}') ->> 'result', 'ok',
          'the confirmed warning is saved');
select is((select override_rules::text || ' ' || (override_by = pg_temp.lead()::uuid)::text || ' ' || (override_at is not null)::text
           from public.institution_assignments where staff_id = pg_temp.id('x') and work_date = pg_temp.d(10)),
          '{shift_model} true true', 'the row keeps the rule, the confirming person and the time');
select is((select (changed -> 'override_rules')::text || ' ' || (actor_id = pg_temp.lead()::uuid)::text
           from public.institution_audit_events where command = 'institution_assign_staff'
             and changed ->> 'staff_id' = pg_temp.id('x')::text), '["shift_model"] true',
          'one audit event names the rule, its actor is the confirming person');
-- The early shift the next morning: 23:00 -> 07:00 is 8 h (< 11 h rest).
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('f'), pg_temp.d(11), null),
          '{"result": "warning", "rules": ["rest"]}'::jsonb, 'an early shift 8 h after the late one: rest warning');
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('f'), pg_temp.d(11), '{rest}') ->> 'result', 'ok', 'confirmed and saved');
-- No rule: saved at once, without override.
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('f'), pg_temp.d(30), null) ->> 'result', 'ok',
          'a shift without any rule breach is saved at once');
select is((select override_rules from public.institution_assignments where staff_id = pg_temp.id('x') and work_date = pg_temp.d(30)),
          null, 'and carries no override');

-- 3. Blocked stays blocked ---------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_record_absence(%L, %L, %L, %L, %L)', pg_temp.inst(),
            pg_temp.id('x'), pg_temp.d(40), pg_temp.d(40), 'vacation')) ->> 'result', 'ok', 'fixture: Ferien on day 40');
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('f'), pg_temp.d(40), '{shift_model,rest,consecutive,pensum_full}') -> 'problems' ->> 0,
          'staff_absent', 'an absence stays blocked, also with every rule confirmed');
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('f'), pg_temp.d(30), '{shift_model,rest,consecutive,pensum_full}') -> 'problems' ->> 0,
          'already_assigned', 'a double booking stays blocked, also with every rule confirmed');
select is(pg_temp.rows(pg_temp.id('f'), pg_temp.d(40)) + pg_temp.rows(pg_temp.id('f'), pg_temp.d(30)), 1, 'nothing more was written');

-- 4. One reading in the plan -------------------------------------------------------------------------------------------
select is(pg_temp.plan_person(pg_temp.id('s'), pg_temp.d(10)) -> 'override_rules', '["shift_model"]'::jsonb,
          'the plan shows the confirmed rule on the cell');
select is(pg_temp.plan_person(pg_temp.id('s'), pg_temp.d(10)) -> 'rules', '["shift_model", "rest"]'::jsonb,
          'and the rules the shift breaks now (shift model, and rest towards the next morning)');
select is(pg_temp.plan_person(pg_temp.id('f'), pg_temp.d(30)) -> 'rules', '[]'::jsonb, 'a shift without a breach shows none');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('s'), 'early'))
            ->> 'result', 'ok', 'the lead reclassifies the late type as early');
select is(pg_temp.plan_person(pg_temp.id('s'), pg_temp.d(10)) -> 'rules', '["rest"]'::jsonb,
          'the current reading follows the change; the stored row is unchanged');

-- 5. A rule that appears between the two calls is never saved unconfirmed -------------------------------------------------
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('s'), pg_temp.d(20), null) ->> 'result', 'ok',
          'fixture: the (now early) type on day 20, no breach');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 50, %L)', pg_temp.id('x'), 'late_only'))
            ->> 'result', 'ok', 'fixture: the person becomes late_only');
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('f'), pg_temp.d(50), null),
          '{"result": "warning", "rules": ["shift_model"]}'::jsonb, 'first call: shift model');
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 1)', pg_temp.inst()));
select is(pg_temp.assign(pg_temp.lead(), pg_temp.id('f'), pg_temp.d(50), '{shift_model}'),
          '{"result": "warning", "rules": ["shift_model", "pensum_full"]}'::jsonb,
          'after the target hours fell in between: a warning again, now with the Pensum');
select is(pg_temp.rows(pg_temp.id('f'), pg_temp.d(50)), 0, 'and nothing was saved');

-- 6. Permission ----------------------------------------------------------------------------------------------------------
select is(pg_temp.assign(pg_temp.u('02')::text, pg_temp.id('f'), pg_temp.d(60), '{shift_model,pensum_full}') ->> 'result', 'rejected',
          'a viewer cannot assign, also not with a confirmation');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'ended', 'employment_ended', pg_temp.u('01'));
select is(pg_temp.cmd(pg_temp.u('05')::text, format('select public.institution_assign_staff(%L, %L, %L, %L, %L, %L::text[])',
            pg_temp.u('11'), pg_temp.id('st'), pg_temp.id('f'), pg_temp.d(60), pg_temp.id('x'), '{shift_model}')) ->> 'sqlstate',
          '42501', 'after the access end assign raises access_ended');
select ok(not has_function_privilege('anon', 'public.institution_assign_staff(uuid, uuid, uuid, date, uuid, text[])', 'execute')
          and not has_function_privilege('authenticated', 'private.institution_rule_breaches(uuid, uuid, date, uuid)', 'execute'),
          'anon cannot assign; nobody but the owner calls the rule reading directly');

select * from finish();
rollback;
