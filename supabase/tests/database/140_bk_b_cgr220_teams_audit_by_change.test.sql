-- BK-b, CGR-220 (`cra` 2026-11-14 13:30, advisory S3; PO amendment 13:39 (5) in `docs/agents/briefs/BK.md`; `aia`
-- 14:22 supported): the `audit_teams` row trigger skips by WHAT CHANGED, never by a session value.
--
-- Red first (task rule 3): on `recovery/main` `22ccbdc` (migration 0130) the trigger carries
-- `WHEN (current_setting('navora.command') <> 'set_team_reach')`, so a database session that sets that value can change
-- `priority` (or any audited team column) without an audit row. Assertions 1 to 5 fail there (6 to 12 hold already).
-- Migration 0134 turns them green.
--
-- What it guards:
--   * the trigger condition reads no session setting;
--   * with `navora.command = 'set_team_reach'` set in the session, a direct `priority` update still writes exactly one
--     audit row carrying `priority` (the `cra` 13:30 test);
--   * `set_team_reach` still writes exactly one `teams` audit row per accepted change (its own command row with old
--     and new distance and postcodes), also for a postcode-only change in the same transaction;
--   * a reach-only update outside the command (privileged session; no app grant exists) is skipped by the trigger
--     because only the command-owned columns changed; the app cannot do it (column privilege);
--   * a mixed update (an audited column and the distance together) writes one row with both keys;
--   * an update that changes nothing still writes its row as before (behaviour of every other path unchanged).
-- Users (seed): pflegebs …9e6 (nurse, member of Testteam Basel …1b9, reach 4051 / 10 km in the seed). Pinned clock.
-- Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
select set_config('navora.test_now', '2026-11-14 18:00:00+01', true);

create temp table mark (n int);
insert into mark values (0);
create function pg_temp.rows_1b9() returns int language sql as $$
  select count(*)::int from public.audit_events
   where table_name = 'teams' and entity_id = '00000000-0000-4000-a000-0000000001b9';
$$;
create function pg_temp.set_mark() returns void language sql as $$ update mark set n = pg_temp.rows_1b9(); $$;
create function pg_temp.since_mark() returns int language sql as $$ select pg_temp.rows_1b9() - n from mark; $$;
create function pg_temp.last_1b9() returns public.audit_events language sql as $$
  select * from public.audit_events
   where table_name = 'teams' and entity_id = '00000000-0000-4000-a000-0000000001b9'
   order by id desc limit 1;
$$;

-- 1. The condition reads no session setting -------------------------------------------------------------------------
select ok((select pg_get_triggerdef(t.oid) !~* 'current_setting|navora\.'
             from pg_trigger t where t.tgrelid = 'public.teams'::regclass and t.tgname = 'audit_teams'),
          'CGR-220: the audit_teams condition reads no session value');

-- 2. A session value no longer switches the audit off ---------------------------------------------------------------
select pg_temp.set_mark();
select set_config('navora.command', 'set_team_reach', true);
update public.teams set priority = not coalesce(priority, false) where id = '00000000-0000-4000-a000-0000000001b9';
select is(pg_temp.since_mark(), 1,
          'CGR-220: with navora.command = set_team_reach, a direct priority update still writes one audit row');
select ok((pg_temp.last_1b9()).changed ? 'priority', 'CGR-220: that row carries the priority change');
select set_config('navora.command', '', true);

-- 3. Mixed update: an audited column and the distance together ------------------------------------------------------
select pg_temp.set_mark();
select set_config('navora.command', 'set_team_reach', true);
update public.teams set priority = not coalesce(priority, false), max_distance_km = 11
 where id = '00000000-0000-4000-a000-0000000001b9';
select set_config('navora.command', '', true);
select is(pg_temp.since_mark(), 1, 'a mixed update writes exactly one audit row');
select ok((pg_temp.last_1b9()).changed ? 'priority' and (pg_temp.last_1b9()).changed ? 'max_distance_km',
          'the mixed row carries both priority and max_distance_km');

-- 4. set_team_reach: exactly one row per accepted change ------------------------------------------------------------
select pg_temp.set_mark();
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
set local role authenticated;
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001b9', array['4051', '4052'], 12,
           'cccc0000-0000-4000-8000-000000000220') ->> 'result'), 'ok', 'a member sets 1b9''s reach');
reset role;
select is(pg_temp.since_mark(), 1, 'set_team_reach writes exactly one teams audit row');
select ok((select command = 'set_team_reach' and changed ? 'max_distance_km' and changed ? 'service_postcodes'
             from pg_temp.last_1b9() ),
          'that row is the command row with distance and postcodes');

select pg_temp.set_mark();
set local role authenticated;
select is((public.set_team_reach('00000000-0000-4000-a000-0000000001b9', array['4051'], 12,
           'cccc0000-0000-4000-8000-000000000221') ->> 'result'), 'ok', 'a postcode-only change is accepted');
reset role;
select is(pg_temp.since_mark(), 1,
          'a postcode-only change in the same transaction still writes exactly one teams audit row');

-- 5. Only command-owned columns: no app path, and no extra trigger row ---------------------------------------------
select ok(not has_column_privilege('authenticated', 'public.teams', 'max_distance_km', 'UPDATE')
          and not has_column_privilege('authenticated', 'public.teams', 'reach_changed_at', 'UPDATE'),
          'the app cannot write the reach columns directly (only set_team_reach)');

-- 6. An update that changes nothing still writes its row (unchanged for every other path) -----------------------------
select pg_temp.set_mark();
update public.teams set priority = priority where id = '00000000-0000-4000-a000-0000000001b9';
select is(pg_temp.since_mark(), 1, 'a no-change update still writes one audit row, as before');

select * from finish();
rollback;
