-- ABS1 part 2 (migration 0048, ADR-057, ADR-059): ABS1-C1 / CGR-27 (one visit interval: no start = whole date; start
-- without end = start + planned minutes, else to the end of the date), ABS1-C2 ("überschneidet sich"), ABS1-C3 (an
-- absence applies to every team of the member in the organisation).
-- Users: nurse …902 (registered nurse, Testteam Nord …101; joins Testteam Mitte …102 in §4) · nurse …906 (care
-- assistant, Nord) · coach …901 joins Mitte here · admin …903 (organisation B). Case …208 (Nord): primary …906,
-- deputy …902. Case …210 (Mitte). All data synthetic. Fixtures are written as the table owner; every step under test
-- goes through the real commands as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(45);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
insert into public.member_profiles (organization_id, user_id, display_name, updated_by) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'Test Pflege RN', '00000000-0000-4000-a000-000000000905'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000906', 'Test Pflege FaGe', '00000000-0000-4000-a000-000000000905')
on conflict (organization_id, user_id) do update set display_name = excluded.display_name;
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-000000000906', deputy_nurse_id = '00000000-0000-4000-a000-000000000902'
  where id = '00000000-0000-4000-a000-000000000208';

-- name, id, team, case, day offset, start, end, minutes A, responsible
create temp table fx (name text primary key, id uuid not null, team uuid not null, case_id uuid not null, d int not null,
                      t0 time, t1 time, a int, resp uuid);
grant select on fx to authenticated;
insert into fx values
  -- §1 CGR-27 (brief criterion, PO 15:25): 902's visits without a start or without an end
  ('untimed_today', 'a0480000-0000-4000-8000-000000000001', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 0, null, null, 30, '00000000-0000-4000-a000-000000000902'),
  ('untimed_tmr',   'a0480000-0000-4000-8000-000000000002', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 1, null, null, 30, '00000000-0000-4000-a000-000000000902'),
  ('noend_60',      'a0480000-0000-4000-8000-000000000003', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 1, '08:00', null, 60, '00000000-0000-4000-a000-000000000902'),
  ('noend_nomin',   'a0480000-0000-4000-8000-000000000004', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 1, '06:00', null, null, '00000000-0000-4000-a000-000000000902'),
  ('noend_short',   'a0480000-0000-4000-8000-000000000005', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 1, '07:00', null, 30, '00000000-0000-4000-a000-000000000902'),
  ('at_0800',       'a0480000-0000-4000-8000-000000000006', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 2, '08:00', null, 60, '00000000-0000-4000-a000-000000000902'),
  -- §3 overlap: her own visit and three open ones
  ('mine',          'a0480000-0000-4000-8000-000000000010', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 4, '10:00', '10:30', 30, '00000000-0000-4000-a000-000000000902'),
  ('ov_yes',        'a0480000-0000-4000-8000-000000000011', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 4, '10:15', '10:45', 30, null),
  ('ov_no',         'a0480000-0000-4000-8000-000000000012', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 4, '12:00', '12:30', 30, null),
  ('ov_untimed',    'a0480000-0000-4000-8000-000000000013', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 4, null, null, 30, null),
  -- §4 ABS1-C3: 902 in two teams
  ('nord_v',        'a0480000-0000-4000-8000-000000000020', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 6, '14:00', '14:30', 30, '00000000-0000-4000-a000-000000000902'),
  ('mitte_v',       'a0480000-0000-4000-8000-000000000021', '00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000210', 6, '09:00', '09:30', 30, '00000000-0000-4000-a000-000000000902'),
  ('mitte_open',    'a0480000-0000-4000-8000-000000000022', '00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000210', 7, null, null, 30, null);

-- 902 joins Mitte in §4; the visit there is inserted now (as the owner) and given to her in §4.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, f.case_id, f.team, pg_temp.today() + f.d, f.t0, f.t1, array['Grundpflege'],
       false, 'planned', f.a, 0, case when f.team = '00000000-0000-4000-a000-000000000101' then f.resp end
from fx f;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.resp(n text) returns uuid language sql as $$ select responsible_user_id from public.care_visits where id = pg_temp.vid(n) $$;
create function pg_temp.may_take(n text, d int) returns boolean language sql as $$
  select o.may_take from public.team_open_visits(pg_temp.today() + d) o where o.visit_id = pg_temp.vid(n) $$;
create function pg_temp.known(n text, d int) returns text language sql as $$
  select o.known_by from public.team_open_visits(pg_temp.today() + d) o where o.visit_id = pg_temp.vid(n) $$;
create function pg_temp.overlap(n text, d int) returns time language sql as $$
  select o.overlaps_my_visit from public.team_open_visits(pg_temp.today() + d) o where o.visit_id = pg_temp.vid(n) $$;

-- 0. The interval itself (arithmetic, Europe/Zurich) ------------------------------------------------------------------
select is((select upper(private.visit_interval(v)) - lower(private.visit_interval(v)) from public.care_visits v where v.id = pg_temp.vid('noend_60')),
  interval '60 minutes', 'CGR-27: a visit with a start and no end occupies start + its planned minutes');
select is((select upper(private.visit_interval(v)) from public.care_visits v where v.id = pg_temp.vid('noend_nomin')),
  ((pg_temp.today() + 2) + time '00:00') at time zone 'Europe/Zurich', 'without planned minutes it runs to the end of its date');
select is((select private.visit_interval(v) from public.care_visits v where v.id = pg_temp.vid('untimed_tmr')),
  tstzrange(((pg_temp.today() + 1) + time '00:00') at time zone 'Europe/Zurich', ((pg_temp.today() + 2) + time '00:00') at time zone 'Europe/Zurich', '[)'),
  'a visit without a start occupies its whole date');

-- 1. ABS1-C1 / CGR-27: release --------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today(), null, '12:00', null,
          'a4800000-0000-4000-8000-000000000001') ->> 'result', 'ok', 'an absence today from 12:00');
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 1, null, '08:30', null,
          'a4800000-0000-4000-8000-000000000002') ->> 'result', 'ok', 'an absence tomorrow from 08:30');
reset role;
select is(pg_temp.resp('untimed_today'), null, 'ABS1-C1: the absence from 12:00 releases her untimed visit of today');
select is(pg_temp.resp('untimed_tmr'), null, 'and the one from 08:30 her untimed visit of tomorrow');
select is(pg_temp.resp('noend_60'), null, 'CGR-27: a visit 08:00 without an end and with 60 planned minutes is released by an absence from 08:30');
select is(pg_temp.resp('noend_nomin'), null, 'a visit 06:00 without an end and without planned minutes too (to the end of its date)');
select is(pg_temp.resp('noend_short'), '00000000-0000-4000-a000-000000000902'::uuid, 'a visit 07:00-07:30 (no end, 30 minutes) stays hers');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 2, null, null, '07:59',
          'a4800000-0000-4000-8000-000000000003') ->> 'released', '0', 'an absence ending 07:59 releases nothing at 08:00');
reset role;
select is(pg_temp.resp('at_0800'), '00000000-0000-4000-a000-000000000902'::uuid, 'the visit 08:00 without an end stays hers');
select is((select count(*)::int from public.visit_plan_changes where visit_id in (pg_temp.vid('untimed_today'), pg_temp.vid('untimed_tmr'),
             pg_temp.vid('noend_60'), pg_temp.vid('noend_nomin')) and change = 'released' and reason = 'Abwesenheit'), 4,
  'each release is logged with the fixed text');

-- 2. ABS1-C1: take and "Offen im Team" use the same interval ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(pg_temp.may_take('untimed_tmr', 1), false, 'CGR-27: the absent nurse is not offered her untimed visit');
select is(public.take_open_visit(pg_temp.vid('noend_60'), 'a4800000-0000-4000-8000-000000000010') ->> 'result', 'absent',
  'and cannot take the visit without an end');
select is(public.take_open_visit(pg_temp.vid('untimed_tmr'), 'a4800000-0000-4000-8000-000000000014') ->> 'result', 'absent',
  'nor the untimed one');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.may_take('untimed_tmr', 1), true, 'a colleague who is available may take the untimed visit');
select is(pg_temp.known('untimed_tmr', 1), 'me', 'the absent deputy is skipped; the primary nurse is "kennt die Klientin"');
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null, pg_temp.today() + 1, null, '15:00', null,
          'a4800000-0000-4000-8000-000000000011') ->> 'result', 'ok', 'the primary nurse is absent tomorrow from 15:00');
select is(pg_temp.may_take('untimed_tmr', 1), false,
  'ABS1-C1: an untimed visit tomorrow is not offered as may_take to a member absent tomorrow from 15:00');
select is(public.take_open_visit(pg_temp.vid('untimed_tmr'), 'a4800000-0000-4000-8000-000000000012') ->> 'result', 'absent',
  'and she cannot take it');
select is(pg_temp.known('untimed_tmr', 1), null, 'with both absent that day, nobody is marked "kennt die Klientin"');
reset role;

-- change_absence uses the same interval: shortened to 08:45, she is still absent part of that date.
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.change_absence((select absence_id from public.team_absences() where is_me and starts_at = ((pg_temp.today() + 1) + time '08:30') at time zone 'Europe/Zurich'), false,
          pg_temp.today() + 1, '08:45', 'a4800000-0000-4000-8000-000000000013') ->> 'returned', '0',
  'shortened to 08:45: nothing returns (the untimed and the 08:00 visits still fall in the absence)');
reset role;
select is(pg_temp.resp('untimed_tmr'), null, 'the untimed visit stays open in the team');

-- 3. ABS1-C2: "überschneidet sich" ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(pg_temp.overlap('ov_yes', 4), '10:00'::time,
  'ABS1-C2: an open visit 10:15 overlapping her own visit 10:00-10:30 is marked with its start');
select is(pg_temp.overlap('ov_no', 4), null, 'an open visit 12:00 is not marked');
select is(pg_temp.overlap('ov_untimed', 4), null, 'an open visit without a time is not marked (no time to clash)');
select is(pg_temp.may_take('ov_yes', 4), true, 'she may still take the overlapping visit');
reset role;

-- 4. ABS1-C3: an absence applies to every team of the member ------------------------------------------------------
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000902', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'registered_nurse');
update public.care_visits set responsible_user_id = '00000000-0000-4000-a000-000000000902' where id = pg_temp.vid('mitte_v');

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
          pg_temp.today() + 6, null, null, null, 'a4800000-0000-4000-8000-000000000020')
          - 'absence_id', '{"result": "ok", "released": 2, "teams": 2}'::jsonb,
  'ABS1-C3: a colleague of team Nord records it once; it applies to both of her teams and releases both visits');
reset role;
select is(pg_temp.resp('mitte_v'), null, 'her visit in team Mitte is released');
select is(pg_temp.resp('nord_v'), null, 'and her visit in team Nord');
select is((select count(*)::int from public.member_absences where user_id = '00000000-0000-4000-a000-000000000902'
             and starts_at = ((pg_temp.today() + 6) + time '00:00') at time zone 'Europe/Zurich'), 2, 'one row per team, one group');

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select member from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000102'
             and starts_at = ((pg_temp.today() + 6) + time '00:00') at time zone 'Europe/Zurich'), 'Test Pflege RN',
  'team Mitte sees her absent');
select is((select count(*)::int from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000101'), 0,
  'but not team Nord''s row');
select is((select count(*)::int from public.member_absences where team_id = '00000000-0000-4000-a000-000000000101'), 0,
  'and cannot read it directly (RLS)');
select ok(pg_temp.vid('mitte_v') = any (select visit_id from public.team_open_visits(pg_temp.today() + 6))
          and not (pg_temp.vid('nord_v') = any (select visit_id from public.team_open_visits(pg_temp.today() + 6))),
  'team Mitte sees only its own released visit');
select is(public.record_absence('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000902',
          pg_temp.today() + 7, null, null, null, 'a4800000-0000-4000-8000-000000000021') ->> 'teams', '2',
  'a colleague of team Mitte may record it for her too, for all her teams');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.team_absences() where is_me
             and starts_at = ((pg_temp.today() + 6) + time '00:00') at time zone 'Europe/Zurich'), 1,
  'she sees her absence once, not once per team');
select is(public.record_absence('00000000-0000-4000-a000-000000000102', null, pg_temp.today() + 6, null, '12:00', null,
          'a4800000-0000-4000-8000-000000000022') ->> 'result', 'overlaps', 'overlaps are checked across her teams');
select is(pg_temp.may_take('mitte_open', 7), false, 'while absent she is offered no visit in either team');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is((select count(*)::int from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000101'
             and starts_at = ((pg_temp.today() + 7) + time '00:00') at time zone 'Europe/Zurich'), 1,
  'team Nord sees the absence a colleague of team Mitte recorded');
select is(public.change_absence((select absence_id from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000101'
             and starts_at = ((pg_temp.today() + 6) + time '00:00') at time zone 'Europe/Zurich'), true, null, null,
          'a4800000-0000-4000-8000-000000000023') ->> 'returned', '2',
  'the recorder (team Nord only) withdraws it: both visits return');
reset role;
select is((select count(*)::int from public.member_absences where user_id = '00000000-0000-4000-a000-000000000902'
             and starts_at = ((pg_temp.today() + 6) + time '00:00') at time zone 'Europe/Zurich' and withdrawn_at is not null), 2,
  'withdraw changes the rows of both teams together');
select is(pg_temp.resp('mitte_v'), '00000000-0000-4000-a000-000000000902'::uuid, 'her Mitte visit is hers again');

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
          pg_temp.today() + 9, null, null, null, 'a4800000-0000-4000-8000-000000000030') ->> 'result', 'rejected',
  'another organisation cannot record it');
reset role;

select * from finish();
rollback;
