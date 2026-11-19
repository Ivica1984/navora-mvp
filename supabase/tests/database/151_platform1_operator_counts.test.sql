-- PLATFORM1 (ADR-213; founder live session 2026-11-19): the NAVORA operator cockpit reads counts only.
-- Source: Blueprint V3.2 §2.4 row «NAVORA-Betrieb» (counts and exceptions, never care content or addresses), §3.3 (no
-- care revenue of a team), FE-078 (no money column). Red first: on `recovery/main` `e34eeb3` neither
-- public.platform_overview() nor private.platform_operators exists.
-- Users: navora.test …a01 (NAVORA operations, seed), pflegebs …9e6 (nurse), kundebs …9e8 (client), admin.test …905
-- (org admin). Pinned clock. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
select set_config('navora.test_now', '2026-11-19 12:00:00+01', true);
create function pg_temp.out_cols(fn text) returns setof text language sql as $$
  select n from pg_proc p, unnest(p.proargnames, p.proargmodes) as a(n, m)
  where p.oid = fn::regprocedure and a.m = 't'
$$;

-- 0. Surface ---------------------------------------------------------------------------------------------------------
select has_function('public', 'platform_overview', array[]::text[], 'platform_overview() exists');
select has_function('public', 'am_platform_operator', array[]::text[], 'am_platform_operator() exists');
select is((select count(*)::int from pg_temp.out_cols('public.platform_overview()') c
           where c ~* '(amount|chf|price|fee|revenue|address|street|display_name|email|note|content)'), 0,
          'Blueprint §2.4 / FE-078: no money, address, person or content column');
select ok(not has_table_privilege('authenticated', 'private.platform_operators', 'select'),
          'authenticated cannot read the operator table');
select ok(not has_function_privilege('anon', 'public.platform_overview()', 'execute'), 'anon cannot run platform_overview()');
select ok(not has_function_privilege('anon', 'public.am_platform_operator()', 'execute'), 'anon cannot run am_platform_operator()');

-- 1. One upcoming order of Testheim Rhein, confirmed by the client (synthetic) -------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select lives_ok($$ select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1', date '2026-11-25', time '08:00',
                    time '12:00', '4051', 'fage_efz', array['C1'], array['C1'], null, 'dddd0000-0000-4000-8151-000000000001') $$,
                'fixture: the client confirms one order for next week');
select is((select count(*)::int from public.platform_overview()), 0, 'the client reads no platform row');
select is(public.am_platform_operator(), false, 'the client is not NAVORA operations');
reset role;

-- 2. Other roles read nothing ------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
set local role authenticated;
select is((select count(*)::int from public.platform_overview()), 0, 'a nurse reads no platform row');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is((select count(*)::int from public.platform_overview()), 0, 'an organisation admin reads no platform row');
reset role;

-- 3. NAVORA operations reads one row per organisation with the counts ----------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000a01');
set local role authenticated;
select is(public.am_platform_operator(), true, 'navora.test is NAVORA operations');
create temp table seen as select * from public.platform_overview();
reset role;
select pg_temp.as_owner();
select is((select count(*)::int from seen), (select count(*)::int from public.organizations), 'one row per organisation');
select is((select teams from seen where organization_id = '00000000-0000-4000-b000-000000000019'),
          (select count(*)::int from public.teams where organization_id = '00000000-0000-4000-b000-000000000019'),
          'the team count of Testorganisation S equals its teams');
select is((select orders_upcoming from seen where organization_id = '00000000-0000-4000-b000-000000000019'),
          (select count(*)::int from public.partner_requests
            where organization_id = '00000000-0000-4000-b000-000000000019' and order_kind is not null
              and ends_at > private.now()),
          'upcoming orders of Testorganisation S equal its orders that have not ended');
select is((select orders_covered + orders_waiting + orders_not_covered from seen
            where organization_id = '00000000-0000-4000-b000-000000000019'),
          (select orders_upcoming from seen where organization_id = '00000000-0000-4000-b000-000000000019'),
          'every upcoming order is counted once: covered, waiting or not covered');

select * from finish();
rollback;
