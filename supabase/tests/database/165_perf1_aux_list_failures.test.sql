-- PERF1 (brief docs/agents/briefs/PERF1.md scope (2), PO amendment 2026-11-21 20:39 (2), CGR-272; migration 0165).
-- Red on 0164: private.aux_list_failures and public.record_aux_list_failure do not exist. Green on 0165.
-- Positive: a nurse's failed load counts one per team of hers and Zurich day; a second failure increments (no second
--   row); another team is untouched.
-- Negative: an unknown list key is refused (22023) and counts nothing; a caller without a team counts nothing.
-- Permission: only authenticated may call it (anon, service_role refused); no API role reads or writes the table; the
--   table has no person column (team level, never per person); RLS on.
-- LEAVE1-3 (an ended access counts nothing) is held by the guard snapshot (pgTAP 157, required «access_ended»).
-- Users: pflegebs …9e6 (nurse, Testteam Basel …1b9, org S), pflege …902 (nurse, Testteam Nord, org A). Synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(13);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select has_table('private', 'aux_list_failures', 'CGR-272: private.aux_list_failures exists');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'private' and table_name = 'aux_list_failures'
             and column_name ~* '(user|member|person|actor|created_by|email|name)'), 0,
          'CGR-272: team level only, the table has no person column');
select ok((select relrowsecurity from pg_class where oid = 'private.aux_list_failures'::regclass), 'RLS is on');
select ok(not has_table_privilege('authenticated', 'private.aux_list_failures', 'select')
          and not has_table_privilege('authenticated', 'private.aux_list_failures', 'insert')
          and not has_table_privilege('anon', 'private.aux_list_failures', 'select')
          and not has_table_privilege('service_role', 'private.aux_list_failures', 'select'),
          'no API role reads or writes the counter table');
select ok(has_function_privilege('authenticated', 'public.record_aux_list_failure(text)', 'execute')
          and not has_function_privilege('anon', 'public.record_aux_list_failure(text)', 'execute')
          and not has_function_privilege('service_role', 'public.record_aux_list_failure(text)', 'execute'),
          'only authenticated may record a failed load');

-- Positive ------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
select is(public.record_aux_list_failure('team_visit_alerts'),
          (select count(distinct team_id)::int from public.team_memberships where user_id = '00000000-0000-4000-a000-0000000009e6'),
          'a failed load counts one row per team of the caller');
select is((select failures from private.aux_list_failures
           where team_id = '00000000-0000-4000-a000-0000000001b9' and list_key = 'team_visit_alerts'
             and day = (private.at_zurich(private.now()))::date), 1,
          'Testteam Basel: 1 failure today (Zurich day)');
select public.record_aux_list_failure('team_visit_alerts');
select is((select failures from private.aux_list_failures
           where team_id = '00000000-0000-4000-a000-0000000001b9' and list_key = 'team_visit_alerts'
             and day = (private.at_zurich(private.now()))::date), 2,
          'a second failure increments the same row');
select is((select count(*)::int from private.aux_list_failures where team_id = '00000000-0000-4000-a000-0000000001b9'), 1,
          'one row per team, day and list (no second row)');
select is((select count(*)::int from private.aux_list_failures f
           where not exists (select 1 from public.team_memberships tm
                             where tm.team_id = f.team_id and tm.user_id = '00000000-0000-4000-a000-0000000009e6')), 0,
          'no team of another person is counted');

-- Negative ------------------------------------------------------------------------------------------------------------
select throws_ok($$ select public.record_aux_list_failure('field_safety_alerts') $$, '22023', 'aux_list_unknown',
                 'CGR-273: an unknown list key (also the safety list) is refused');
select throws_ok($$ select public.record_aux_list_failure(null) $$, '22023', 'aux_list_unknown', 'a missing list key is refused');
select pg_temp.act_as('00000000-0000-4000-a000-00000000ffff');
select is(public.record_aux_list_failure('team_visit_alerts'), 0, 'a caller without a team counts nothing');

select * from finish();
rollback;
