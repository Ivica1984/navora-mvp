-- HD-3a slice 2d (brief docs/agents/briefs/HD.md §5b PO amendment 2026-11-24 19:39, FE-125; migration 0174):
--   * wishes per person: ISO weekday with a shift type of the home (`work`) or without work (`off`); no free text,
--     no reason; RLS on and no table grant, read only through `institution_plan`.
--   * `institution_set_staff_wishes`: lead and planner of the same home only, with one audit event (old and new set);
--     viewer and another home's lead refused; malformed entries, a foreign shift type, duplicates and a weekday wished
--     with and without work refused and change nothing; access end raises (LEAVE1-3); anon no execute.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(35);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a174-0000000000' || n)::uuid $$;

-- Fixture (as owner): home H2 with lead L2 (and L5, whose access ends) and its own shift type; viewer V and planner P
-- of home 1.
insert into auth.users (id, email) values (pg_temp.u('01'), 'l2.hd3a4@navora.test'), (pg_temp.u('02'), 'v.hd3a4@navora.test'),
                                          (pg_temp.u('03'), 'p.hd3a4@navora.test'), (pg_temp.u('05'), 'l5.hd3a4@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('11'), 'Testheim HD-3a d (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.u('11'), pg_temp.u('01'), 'lead'), (pg_temp.inst(), pg_temp.u('02'), 'viewer'),
  (pg_temp.inst(), pg_temp.u('03'), 'planner'), (pg_temp.u('11'), pg_temp.u('05'), 'lead');
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, ends_at, sort) values
  (pg_temp.u('31'), pg_temp.u('11'), 'Z', 'Zweitheim', '07:00', '15:00', 0);
insert into public.institution_staff (id, institution_id, display_name, grade) values
  (pg_temp.u('41'), pg_temp.u('11'), 'HD3a Zweitheim Person', 'fage_efz');

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Wunsch', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 't', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'WZ', 'HD3a Wunschdienst', '10:00', '18:00')) ->> 'shift_type_id')::uuid;
create function pg_temp.wishes(p_user text, staff uuid, w text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_set_staff_wishes(%L, %s)', staff,
    coalesce(quote_literal(w) || '::jsonb', 'null')))
$$;
create function pg_temp.stored(staff uuid) returns int language sql as $$
  select count(*)::int from public.institution_staff_wishes where staff_id = staff
$$;
create function pg_temp.work(wd int) returns text language sql as $$
  select format('{"weekday": %s, "kind": "work", "shift_type_id": "%s"}', wd, pg_temp.id('t'))
$$;

-- 1. Schema and access ---------------------------------------------------------------------------------------------------
select has_table('public', 'institution_staff_wishes', 'the wishes table exists');
select ok((select relrowsecurity from pg_class where oid = 'public.institution_staff_wishes'::regclass), 'RLS is on');
select ok(not has_table_privilege('authenticated', 'public.institution_staff_wishes', 'select')
          and not has_table_privilege('authenticated', 'public.institution_staff_wishes', 'insert')
          and not has_table_privilege('anon', 'public.institution_staff_wishes', 'select'),
          'no table privilege for authenticated or anon: read and write only through the functions');
select hasnt_column('public', 'institution_staff_wishes', 'reason', 'no reason column (no health data)');
select throws_ok(format($$insert into public.institution_staff_wishes (institution_id, staff_id, weekday, kind)
                          values (%L, %L, 1, 'work')$$, pg_temp.inst(), pg_temp.id('x')),
                 '23514', null, 'the database refuses a work wish without a shift type');
select throws_ok(format($$insert into public.institution_staff_wishes (institution_id, staff_id, weekday, kind)
                          values (%L, %L, 8, 'off')$$, pg_temp.inst(), pg_temp.id('x')),
                 '23514', null, 'the database refuses weekday 8');
select throws_ok(format($$insert into public.institution_staff_wishes (institution_id, staff_id, weekday, kind, shift_type_id)
                          values (%L, %L, 1, 'work', %L)$$, pg_temp.inst(), pg_temp.id('x'), pg_temp.u('31')),
                 '23503', null, 'the database refuses a shift type of another home');

-- 2. Accepted writes ------------------------------------------------------------------------------------------------------
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), format('[%s, %s, {"weekday": 2, "kind": "off"}]',
            pg_temp.work(1), pg_temp.work(3))) ->> 'result', 'ok', 'the lead sets Mon and Wed with the shift, Tue off');
select is(pg_temp.stored(pg_temp.id('x')), 3, 'three wishes are stored');
select is((select string_agg(weekday || kind, ' ' order by weekday) from public.institution_staff_wishes
           where staff_id = pg_temp.id('x')), '1work 2off 3work', 'weekday and kind as entered');
select is((select jsonb_array_length(changed -> 'wishes' -> 'new') from public.institution_audit_events
           where command = 'institution_set_staff_wishes' and entity_id = pg_temp.id('x')), 3,
          'one audit event, carrying the new set');
select is(pg_temp.wishes(pg_temp.u('03')::text, pg_temp.id('x'), format('[%s]', pg_temp.work(5))) ->> 'result', 'ok',
          'the planner replaces the set');
select is((select string_agg(weekday || kind, ' ') from public.institution_staff_wishes where staff_id = pg_temp.id('x')),
          '5work', 'the call replaces the whole set');
select is((select jsonb_array_length(changed -> 'wishes' -> 'old') from public.institution_audit_events
           where command = 'institution_set_staff_wishes' and entity_id = pg_temp.id('x')
           order by occurred_at desc, id desc limit 1), 3, 'the audit event carries the old set');

-- 3. Read through institution_plan (every member, like the other person data) -----------------------------------------
select is((select count(*)::int from jsonb_array_elements(pg_temp.cmd(pg_temp.u('02')::text,
             format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), current_date, current_date)) -> 'wishes') w
           where w ->> 'staff_id' = pg_temp.id('x')::text and w ->> 'weekday' = '5' and w ->> 'kind' = 'work'
             and w ->> 'shift_type_id' = pg_temp.id('t')::text), 1, 'a viewer reads the wish in the plan');
select is(pg_temp.cmd(pg_temp.u('01')::text, format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(),
            current_date, current_date)) ->> 'result', 'rejected', 'another home''s lead reads nothing');

-- 4. Refused writes change nothing -----------------------------------------------------------------------------------------
select is(pg_temp.wishes(pg_temp.u('02')::text, pg_temp.id('x'), '[]') ->> 'result', 'rejected', 'a viewer cannot set wishes');
select is(pg_temp.wishes(pg_temp.u('01')::text, pg_temp.id('x'), '[]') ->> 'result', 'rejected',
          'another home''s lead cannot set wishes');
select is(pg_temp.wishes(pg_temp.lead(), null, '[]') ->> 'result', 'rejected', 'no person: rejected');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), null) -> 'problems' ->> 0, 'wishes_not_valid', 'null is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '{"weekday": 1}') -> 'problems' ->> 0, 'wishes_not_valid',
          'an object instead of a list is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '[1]') -> 'problems' ->> 0, 'wishes_not_valid',
          'a scalar entry is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '[{"weekday": 8, "kind": "off"}]') -> 'problems' ->> 0,
          'wishes_not_valid', 'weekday 8 is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '[{"weekday": "1", "kind": "off"}]') -> 'problems' ->> 0,
          'wishes_not_valid', 'a weekday as text is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '[{"weekday": 1, "kind": "sick"}]') -> 'problems' ->> 0,
          'wishes_not_valid', 'another kind is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '[{"weekday": 1, "kind": "off", "reason": "x"}]') -> 'problems' ->> 0,
          'wishes_not_valid', 'an extra key (free text) is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), format('[{"weekday": 1, "kind": "off", "shift_type_id": "%s"}]',
            pg_temp.id('t'))) -> 'problems' ->> 0, 'wishes_not_valid', 'an off wish with a shift type is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '[{"weekday": 1, "kind": "work"}]') -> 'problems' ->> 0,
          'wishes_not_valid', 'a work wish without a shift type is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), format('[{"weekday": 1, "kind": "work", "shift_type_id": "%s"}]',
            pg_temp.u('31'))) -> 'problems' ->> 0, 'shift_type_not_found', 'a shift type of another home is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), format('[%s, %s]', pg_temp.work(1), pg_temp.work(1))) -> 'problems' ->> 0,
          'wish_duplicate', 'a duplicate is refused');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), format('[%s, {"weekday": 1, "kind": "off"}]', pg_temp.work(1)))
            -> 'problems' ->> 0, 'wish_conflict', 'a weekday wished with and without work is refused');
select is((select string_agg(weekday || kind, ' ') from public.institution_staff_wishes where staff_id = pg_temp.id('x'))
          || ' / ' || (select count(*) from public.institution_audit_events
                       where command = 'institution_set_staff_wishes' and entity_id = pg_temp.id('x')),
          '5work / 2', 'refused calls change nothing and write no audit event');
select is(pg_temp.wishes(pg_temp.lead(), pg_temp.id('x'), '[]') ->> 'wishes', '0', 'an empty list clears the set');

-- 5. Access end (LEAVE1-3) and grants ----------------------------------------------------------------------------------
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('05'), 'ended', 'employment_ended', pg_temp.u('01'));
select is(pg_temp.wishes(pg_temp.u('05')::text, pg_temp.u('41'), '[{"weekday": 1, "kind": "off"}]') ->> 'sqlstate', '42501',
          'after the access end set_staff_wishes raises access_ended');
select ok(not has_function_privilege('anon', 'public.institution_set_staff_wishes(uuid, jsonb)', 'execute'),
          'anon cannot execute the command');

select * from finish();
rollback;
