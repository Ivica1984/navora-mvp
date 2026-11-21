-- BK-b1s (brief `docs/agents/briefs/BK.md`, PO amendment 2026-11-14 10:39 (3); AUT-117 (c); ADR-195 addendum 11:10):
-- the reader of the team's own reach screen and the screen's permission facts at the database.
--
-- Red first: on the BK-b1 head (`f3b2a5c`) this file fails at its first statement (`public.my_team_reach()` does not
-- exist). Migration 0131 turns it green.
--
-- What it guards:
--   * (a) an active member reads her own team's reach (postcodes, maximum, date of the last change) and no other team;
--     a change through set_team_reach is what the reader shows next;
--   * (c) a member of another team reads nothing of this team and cannot change it; a former member (LEAVE1, access
--     ended) reads nothing and cannot change it; a person in no team and a client read nothing;
--   * the function: security definer with an empty search_path, no anon execute, returns no person column.
-- Users (seed): pflegebs …9e6 and assistbs …9e7 (members of Testteam Basel …1b9, org S), opsbs …9e5 (org S, in no
-- team), pflege.test …902 (Testteam Nord …101, org A), kundebs …9e8 (client). Synthetic data only; everything is rolled
-- back at the end.
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
select set_config('navora.test_now', '2026-11-14 11:00:00+01', true);

-- 1. Function facts -------------------------------------------------------------------------------------------------
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'my_team_reach' and p.prosecdef
             and p.proconfig @> array['search_path=""']), 1,
          'BK-b1s: my_team_reach is security definer with an empty search_path');
select ok(not has_function_privilege('anon', 'public.my_team_reach()', 'execute'), 'BK-b1s: anon cannot call my_team_reach');
select ok(has_function_privilege('authenticated', 'public.my_team_reach()', 'execute'), 'BK-b1s: authenticated may call my_team_reach');
select is((select count(*)::int from information_schema.parameters
           where specific_schema = 'public' and specific_name like 'my_team_reach%' and parameter_mode = 'OUT'
             and parameter_name ~ '(user|member|person|name_of|email|address|street)'), 0,
          'P-5: the reader returns no person or address column');

-- 2. (a) An active member reads her own team only ---------------------------------------------------------------------
set local role authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
select is((select array_agg(team_name::text) from public.my_team_reach()), array['Testteam Basel'],
          '(a) a member of Testteam Basel reads exactly her own team');
select is((select postcodes from public.my_team_reach()), array['4051'], '(a) she reads the seeded service postcode');
select is((select max_distance_km from public.my_team_reach()), 10::numeric, '(a) she reads the seeded maximum');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001b9', array['4057', '4051'], 7.5,
                                 '00000000-0000-4000-c137-000000000001'))->>'result', 'ok',
          '(a) she changes her team''s reach through set_team_reach');
select is((select postcodes from public.my_team_reach()), array['4051', '4057'], '(a) the reader shows the new postcodes');
select is((select max_distance_km from public.my_team_reach()), 7.5::numeric, '(a) the reader shows the new maximum');
select is((select reach_changed_at from public.my_team_reach()), '2026-11-14 11:00:00+01'::timestamptz,
          'AUT-117 (c): the reader shows when the reach was last changed');

-- 3. (c) Another team's member, a person in no team, a client ---------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
select is((select count(*)::int from public.my_team_reach() where team_id = '00000000-0000-4000-a000-0000000001b9'), 0,
          '(c) a member of another team reads nothing of Testteam Basel');
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001b9', array['4410'], 50,
                                 '00000000-0000-4000-c137-000000000002'))->>'result', 'rejected',
          '(c) a member of another team cannot change Testteam Basel''s reach');
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e5');
select is((select count(*)::int from public.my_team_reach()), 0, '(c) a person of the organisation in no team reads nothing');
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
select is((select count(*)::int from public.my_team_reach()), 0, 'ADR-192 (3): a client reads no team reach');

-- 4. (c) A former member (LEAVE1: access ended) -----------------------------------------------------------------------
reset role;
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
values ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000009e7', 'ended', 'employment_ended',
        '00000000-0000-4000-a000-0000000009e6');
set local role authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e7');
select is((select count(*)::int from public.my_team_reach()), 0, '(c) LEAVE1-3: a former member reads nothing');
select throws_ok($$select public.set_team_reach('00000000-0000-4000-a000-0000000001b9', array['4410'], 50,
                                                '00000000-0000-4000-c137-000000000003')$$,
                 '42501', 'access_ended', '(c) LEAVE1-3: a former member cannot change the reach (access_ended)');
reset role;
select is((select max_distance_km from public.teams where id = '00000000-0000-4000-a000-0000000001b9'), 7.5::numeric,
          '(c) the reach is unchanged after the former member''s attempt');

select * from finish();
rollback;
