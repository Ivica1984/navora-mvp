-- CSR1 part 11 / CGR-32 (migration 0053, ADR-065; PO 2026-10-23 19:12 in docs/agents/briefs/ABS1.md): an absence
-- recorded today that starts yesterday keeps her past planned visits with her, counts them in `past_planned` (caller's
-- teams only, ABS1-N1), and flags their overdue alert `responsible_absent` on /team and in OPS1. The flag is computed
-- from the absence: shortening or withdrawing it clears the flag. Today's and later visits are released as in 048.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) is absent · care assistant …906 (Nord) records the absence
-- and reads /team · operations …904 reads OPS1. All data synthetic. Fixtures are written as the table owner; every step
-- under test goes through the real commands and readers as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;

-- 902 also belongs to Testteam Mitte (…102), so the absence applies there too (ABS1-C3); 906 is in Nord only.
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000902', 'registered_nurse');

create temp table fx (name text primary key, id uuid not null, case_id uuid not null, team_id uuid not null,
                      d int not null, t0 time not null, resp uuid not null);
grant select on fx to authenticated;
insert into fx values
  -- yesterday 07:00, hers, inside the absence: kept, counted, flagged
  ('past',      'a0540000-0000-4000-8000-000000000001', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', -1, '07:00', '00000000-0000-4000-a000-000000000902'),
  -- yesterday 09:00, hers, inside the absence, its overdue alert closed by hand earlier (cra 19:46): still counted
  ('closed',    'a0540000-0000-4000-8000-000000000007', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', -1, '09:00', '00000000-0000-4000-a000-000000000902'),
  -- yesterday 05:00, hers, before the absence starts: not counted, not flagged
  ('early',     'a0540000-0000-4000-8000-000000000002', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', -1, '05:00', '00000000-0000-4000-a000-000000000902'),
  -- two days ago 07:00, the colleague's (not absent then; the seed's ended absence of 906 covers only yesterday): no flag
  ('other',     'a0540000-0000-4000-8000-000000000003', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', -2, '07:00', '00000000-0000-4000-a000-000000000906'),
  -- yesterday 08:00, hers, in Testteam Mitte: kept and flagged, but not counted for a Nord-only caller (ABS1-N1)
  ('past_mitte','a0540000-0000-4000-8000-000000000004', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', -1, '08:00', '00000000-0000-4000-a000-000000000902'),
  -- today 12:00 and tomorrow 09:00, hers: released as in 048
  ('today',     'a0540000-0000-4000-8000-000000000005', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',  0, '12:00', '00000000-0000-4000-a000-000000000902'),
  ('tomorrow',  'a0540000-0000-4000-8000-000000000006', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',  1, '09:00', '00000000-0000-4000-a000-000000000902');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, f.case_id, f.team_id, pg_temp.today() + f.d, f.t0, f.t0 + interval '30 minutes',
       array['Grundpflege'], false, 'planned', 30, 0, f.resp
from fx f;

-- A coordinator closed the 09:00 visit's overdue alert while it was still P2 (synthetic text).
insert into public.exception_events (organization_id, exception_key, kind, text, actor_id)
values ('00000000-0000-4000-b000-000000000011', 'visit_overdue:a0540000-0000-4000-8000-000000000007', 'close',
        'Synthetisch: Team informiert', '00000000-0000-4000-a000-000000000904');

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.resp(n text) returns uuid language sql as $$
  select responsible_user_id from public.care_visits where id = pg_temp.vid(n) $$;
-- /team as the caller: the overdue alert's flags, or null when there is no overdue alert
create function pg_temp.team_flags(n text) returns text[] language sql as $$
  select a.flags from public.team_visit_alerts() a where a.exception_type = 'visit_overdue' and a.visit_id = pg_temp.vid(n) $$;
-- OPS1 as the caller
create function pg_temp.ops_flags(n text) returns text[] language sql as $$
  select x.flags from public.operations_exceptions() x where x.exception_type = 'visit_overdue' and x.entity_id = pg_temp.vid(n) $$;

-- 0. Without an absence: the overdue alert is there, without the flag ------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team_flags('past'), array[]::text[], 'without an absence, yesterday''s planned visit has its overdue alert on /team, without the flag');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ops_flags('past'), array[]::text[], 'and in OPS1, without the flag');
reset role;

-- 1. A colleague records her absent from yesterday 06:00 (until tomorrow, whole day) ----------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
create temp table r1 as
  select public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
                               pg_temp.today() - 1, pg_temp.today() + 1, '06:00', null, 'a5400000-0000-4000-8000-000000000001') as r;
reset role;
select is((select r ->> 'result' from r1), 'ok', 'CGR-32 (1): an absence starting yesterday is recorded, never refused for her past visits');
select is((select (r ->> 'past_planned')::int from r1), 2,
  'past_planned = 2: yesterday''s 07:00 visit and the 09:00 one whose alert was closed by hand; not the 05:00 one before the absence, not the Mitte one (ABS1-N1)');
select is((select (r ->> 'released')::int from r1), 2, 'today''s and tomorrow''s visits are released as in 048');
select is((select (r ->> 'teams')::int from r1), 2, 'the absence applies to both of her teams (ABS1-C3)');

select is(pg_temp.resp('past'), '00000000-0000-4000-a000-000000000902'::uuid, 'CGR-32 (2): yesterday''s visit still names her');
select is(pg_temp.resp('past_mitte'), '00000000-0000-4000-a000-000000000902'::uuid, 'and so does the Mitte one');
select is((select count(*)::int from public.visit_plan_changes c where c.visit_id in (pg_temp.vid('past'), pg_temp.vid('past_mitte'))), 0,
  'no plan change is written for the past visits (not released)');
select is(pg_temp.resp('today'), null, 'today''s visit is released');
select is(pg_temp.resp('tomorrow'), null, 'tomorrow''s visit is released');

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team_flags('past'), array['responsible_absent'], 'CGR-32 (2): on /team the overdue alert carries responsible_absent');
select ok((select a.detail from public.team_visit_alerts() a where a.exception_type = 'visit_overdue' and a.visit_id = pg_temp.vid('past'))
          like '%zuständig:%', 'the detail still names who is responsible (no reason, no free text added)');
select is(pg_temp.team_flags('closed'), array['responsible_absent'],
  'the hand-closed overdue alert is still listed (it escalates, so it closes only with its cause) and flagged');
select is(pg_temp.team_flags('early'), array[]::text[], 'the 05:00 visit before the absence keeps its alert without the flag');
select is(pg_temp.team_flags('other'), array[]::text[], 'the colleague''s overdue visit has the alert without the flag');
select is(pg_temp.team_flags('past_mitte'), null, 'a Nord member does not see the Mitte alert');
select is((select count(*)::int from public.team_visit_alerts() a where a.visit_id = pg_temp.vid('past')), 1,
  'the visit has exactly one alert on /team');
select ok(not exists (select 1 from public.team_visit_alerts() a where a.exception_type <> 'visit_overdue' and a.flags <> array[]::text[]),
  'only overdue alerts carry the flag');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ops_flags('past'), array['responsible_absent'], 'CGR-32 (2): in OPS1 the overdue alert carries responsible_absent');
select is(pg_temp.ops_flags('past_mitte'), array['responsible_absent'], 'and the Mitte one, for the coordinator of the organisation');
select is(pg_temp.ops_flags('other'), array[]::text[], 'the colleague''s overdue visit has no flag in OPS1');
select ok(exists (select 1 from public.pilot_kpis(pg_temp.today()) k where k.kpi = 'open_p1_exceptions' and k.value >= 2),
  'pilot_kpis still reads operations_exceptions after the new column (P1 count includes the flagged visits)');
reset role;

-- 2. Shortening the absence to before the visit clears the flag (computed, not stored) ------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.change_absence((select (r ->> 'absence_id')::uuid from r1), false, pg_temp.today() - 1, '06:30',
          'a5400000-0000-4000-8000-000000000002') ->> 'result', 'ok', 'the recorder shortens the absence to yesterday 06:30');
select is(pg_temp.team_flags('past'), array[]::text[], 'CGR-32 (3): the visit is no longer inside the absence: alert without the flag');
reset role;
select is(pg_temp.resp('past'), '00000000-0000-4000-a000-000000000902'::uuid, 'and it still names her');
select is(pg_temp.resp('today'), '00000000-0000-4000-a000-000000000902'::uuid, 'today''s released visit returns to her (048, unchanged)');

-- 3. A new absence from yesterday 06:30 flags it again; withdrawing it clears the flag -------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
create temp table r2 as
  select public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
                               pg_temp.today() - 1, pg_temp.today() + 1, '06:30', null, 'a5400000-0000-4000-8000-000000000003') as r;
select is((select r ->> 'result' from r2) || ' ' || (select r ->> 'past_planned' from r2), 'ok 2',
  'a new absence from yesterday 06:30 is recorded and counts the 07:00 and 09:00 visits again');
select is(pg_temp.team_flags('past'), array['responsible_absent'], 'the flag is back');
select is(public.change_absence((select (r ->> 'absence_id')::uuid from r2), true, null, null,
          'a5400000-0000-4000-8000-000000000004') ->> 'result', 'ok', 'the recorder withdraws the absence');
select is(pg_temp.team_flags('past'), array[]::text[], 'CGR-32 (3): withdrawing clears the flag; the alert stays');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.ops_flags('past_mitte'), array[]::text[], 'and in OPS1 for the Mitte visit');
reset role;

-- 4. Privileges: the flag helper is not callable by the app ----------------------------------------------------------
select ok(not has_function_privilege('authenticated', 'private.visit_responsible_absent(uuid)', 'execute'),
  'authenticated cannot call private.visit_responsible_absent');
select ok(not has_function_privilege('anon', 'public.team_visit_alerts()', 'execute')
          and not has_function_privilege('anon', 'public.operations_exceptions()', 'execute'),
  'anon still cannot read /team alerts or OPS1 after the readers were recreated');

select * from finish();
rollback;
