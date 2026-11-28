-- BD seed completion for Testorganisation S (PO 2026-11-11 10:39, BD brief amendment 10:39, comment on PR #1069;
-- ADR-183). Fixture only: no grant, policy, rule or command changes.
--   (G-a) org S has exactly the synthetic ASM1 instrument list of Testorganisation A (same names, versions, validity,
--         third-party-mark flag), so the BD run can record an ASM1 assessment. No assessment record is seeded.
--   (G-b) `plan3_day_proposal` is seeded `on` for org S (as for Testorganisation H; no administrator in the run, so the
--         AUT-88 act baseline holds no management act). Only org H and org S have it on. The team's own switch
--         (PLAN3-10) stays off, as by default: a member of Testteam Basel switches it on in the run (a team act).
-- Synthetische Daten. Seed: org S …019, Testteam Basel …1b9, opsbs …9e5 (operations), pflegebs …9e6 (registered nurse),
-- assistbs …9e7 (care assistant); Testorganisation A …011, assist.test …906; Testorganisation H …018.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create function pg_temp.org_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;
create function pg_temp.org_a() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000011'::uuid $$;
create function pg_temp.org_h() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000018'::uuid $$;
create function pg_temp.team_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001b9'::uuid $$;
create function pg_temp.ops() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e5'::uuid $$;
create function pg_temp.nurse() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e6'::uuid $$;
create function pg_temp.assist_a() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-000000000906'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1250000-0000-4000-e000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
-- A query run as `authenticated` for uid (RLS and column grants apply); returns its rows as a jsonb array.
create function pg_temp.rows_as(uid uuid, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(uid);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(q)), ''[]''::jsonb) from (%s) q', p_sql) into r;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r;
exception when others then
  execute 'reset role';
  perform pg_temp.as_owner();
  raise;
end $$;
-- A command run as `authenticated` for uid; returns its text result.
create function pg_temp.res_as(uid uuid, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform pg_temp.act_as(uid);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r;
exception when others then
  execute 'reset role';
  perform pg_temp.as_owner();
  raise;
end $$;

-- 1. (G-a) org S has exactly the instrument list of org A ----------------------------------------------------------------------
select set_eq(
  format('select name, version, valid_from, valid_to, third_party_mark from public.assessment_instruments where organization_id = %L', pg_temp.org_s()),
  format('select name, version, valid_from, valid_to, third_party_mark from public.assessment_instruments where organization_id = %L', pg_temp.org_a()),
  '(G-a): Testorganisation S has exactly the instrument entries of Testorganisation A (name, version, validity, mark)');
select is((select count(*)::int from public.assessment_instruments where organization_id = pg_temp.org_s()),
          (select count(*)::int from public.assessment_instruments where organization_id = pg_temp.org_a()),
  '(G-a): the same number of entries (no duplicate)');
select ok((select count(*) = 1 from public.assessment_instruments
           where organization_id = pg_temp.org_s() and valid_to is null and not third_party_mark
             and valid_from <= (private.now() at time zone 'Europe/Zurich')::date),
  '(G-a): one entry is valid today and not a third party''s mark (the run can record ASM1 with it)');
select is((select count(*)::int from public.assessment_instruments i
           where i.organization_id = pg_temp.org_s()
             and not exists (select 1 from public.organization_memberships m
                             where m.organization_id = pg_temp.org_s() and m.user_id = i.created_by)), 0,
  '(G-a): every org S entry names a member of org S as author (fixture attribution, no foreign actor)');
select is((select count(*)::int from public.assessment_records where organization_id = pg_temp.org_s()), 0,
  '(G-a): no assessment record is seeded for org S (the BD run writes it through the command)');
select is(jsonb_array_length(pg_temp.rows_as(pg_temp.nurse(),
            'select id, name, version from public.assessment_instruments')),
          (select count(*)::int from public.assessment_instruments where organization_id = pg_temp.org_s()),
  '(G-a): the org S registered nurse reads the org S list under RLS (granted columns only)');
select is((pg_temp.rows_as(pg_temp.assist_a(),
            format('select id from public.assessment_instruments where organization_id = %L', pg_temp.org_s())))::text,
          '[]',
  '(G-a): a member of Testorganisation A reads no org S entry (RLS)');

-- 2. (G-b) the day proposal is on for org H and org S only ---------------------------------------------------------------------
select set_eq(
  $$ select organization_id from public.ai_agent_settings where agent_key = 'plan3_day_proposal' and state = 'on' $$,
  format('values (%L::uuid), (%L::uuid)', pg_temp.org_h(), pg_temp.org_s()),
  '(G-b): only Testorganisation H and Testorganisation S have plan3_day_proposal on');
select ok((select a.on_version = d.version and a.on_provider is not distinct from d.provider
                  and a.on_region is not distinct from d.region
                  and a.stop_share is not null and a.stop_min_proposals is not null and a.stop_window_days is not null
           from public.ai_agent_settings a join public.ai_agent_definitions d on d.key = a.agent_key
           where a.organization_id = pg_temp.org_s() and a.agent_key = 'plan3_day_proposal'),
  '(G-b): the org S row is as set_agent_state writes it (definition version, provider, region; threshold set)');
select ok((select exists (select 1 from public.organization_memberships m
                          where m.organization_id = pg_temp.org_s() and m.user_id = a.switched_on_by)
           from public.ai_agent_settings a
           where a.organization_id = pg_temp.org_s() and a.agent_key = 'plan3_day_proposal'),
  '(G-b): switched_on_by is a member of org S (fixture attribution, as for org H)');
select is((select count(*)::int from public.organization_memberships
           where organization_id = pg_temp.org_s() and role = 'admin'), 0,
  '(G-b): org S has no administrator (no management act in the AUT-88 baseline)');
select is((select count(*)::int from public.team_day_proposal_settings where team_id = pg_temp.team_s()), 0,
  '(G-b): the team''s own switch is not seeded (off by default; the team switches it, PLAN3-10)');
select is(pg_temp.rows_as(pg_temp.nurse(),
            format('select team_enabled, agent_state from public.team_day_proposal_state(%L)', pg_temp.team_s())) -> 0,
          '{"team_enabled": false, "agent_state": "on"}'::jsonb,
  '(G-b): the org S nurse reads agent state on and her team''s switch off');
select is(pg_temp.res_as(pg_temp.nurse(),
            format('select public.set_team_day_proposal(%L, true, %L)', pg_temp.team_s(), pg_temp.k(1))), 'ok',
  '(G-b): a member of Testteam Basel switches the day proposal on for her team (team act, no administrator)');
select is(pg_temp.rows_as(pg_temp.nurse(),
            format('select team_enabled, agent_state from public.team_day_proposal_state(%L)', pg_temp.team_s())) -> 0,
          '{"team_enabled": true, "agent_state": "on"}'::jsonb,
  '(G-b): after the team act the team may ask for a proposal');
select is(pg_temp.res_as(pg_temp.ops(),
            format('select public.set_team_day_proposal(%L, false, %L)', pg_temp.team_s(), pg_temp.k(2))), 'rejected',
  '(G-b): Operations (not a team member) may not switch the team''s proposal (PLAN3-10)');

select * from finish();
rollback;
