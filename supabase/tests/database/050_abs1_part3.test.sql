-- ABS1 part 3 (migration 0050, ADR-061): ABS1-C4 (no command gives a planned visit to a member absent at its interval;
-- plan_visit refuses with responsible_absent, reschedule_visit into her absence releases the visit) and ABS1-N1
-- (record_absence counts `released` over the caller's own teams only). Cases (a)-(e) of the PO review 2026-10-23 16:18.
-- Users: nurse …902 (registered nurse, Testteam Nord …101; joins Testteam Mitte …102 in §5) · care assistant …906
-- (Nord) · coach …901 joins Mitte in §5. Case …208 (Nord), case …210 (Mitte). All data synthetic. Fixtures are written
-- as the table owner; every step under test goes through the real commands as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(31);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.resp(p uuid) returns uuid language sql as $$ select responsible_user_id from public.care_visits where id = p $$;
create function pg_temp.visit_at(p_case uuid, d int, t time) returns uuid language sql as $$
  select id from public.care_visits where case_id = p_case and visit_date = pg_temp.today() + d and time_start = t $$;

-- name, id, team, case, day offset, start, end, responsible (902 is responsible; Mitte rows get her in §5)
create temp table fx (name text primary key, id uuid not null, team uuid not null, case_id uuid not null, d int not null,
                      t0 time not null, t1 time not null);
grant select on fx to authenticated;
insert into fx values
  ('move_in',    'a0500000-0000-4000-8000-000000000001', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 2, '07:00', '07:30'),
  ('move_out',   'a0500000-0000-4000-8000-000000000002', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 2, '09:00', '09:30'),
  ('nord_v6',    'a0500000-0000-4000-8000-000000000003', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 6, '14:00', '14:30'),
  ('mitte_v6',   'a0500000-0000-4000-8000-000000000004', '00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000210', 6, '09:00', '09:30'),
  ('nord_v8',    'a0500000-0000-4000-8000-000000000005', '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000208', 8, '14:00', '14:30'),
  ('mitte_v8',   'a0500000-0000-4000-8000-000000000006', '00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000210', 8, '09:00', '09:30'),
  ('mitte_move', 'a0500000-0000-4000-8000-000000000007', '00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000210', 2, '11:00', '11:30');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, f.case_id, f.team, pg_temp.today() + f.d, f.t0, f.t1, array['Grundpflege'],
       false, 'planned', 30, 0, case when f.team = '00000000-0000-4000-a000-000000000101' then '00000000-0000-4000-a000-000000000902'::uuid end
from fx f;
create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;

-- 0. A colleague records 902 absent on day +3 (whole day). 902 is only in team Nord now.
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
          pg_temp.today() + 3, null, null, null, 'a5000000-0000-4000-8000-000000000001') ->> 'result', 'ok',
  'a colleague records her absent on day +3');

-- 1. (a) plan with an absent responsible member ------------------------------------------------------------------------
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 3, '08:00', '08:30', 30, 0, 0, false,
          '00000000-0000-4000-a000-000000000902', 'a5000000-0000-4000-8000-000000000010'),
  '{"result": "rejected", "reason": "responsible_absent"}'::jsonb,
  'ABS1-C4 (a): plan_visit with a responsible member absent at that time is refused with responsible_absent');
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 4, '08:00', '08:30', 30, 0, 0, false,
          '00000000-0000-4000-a000-000000000902', 'a5000000-0000-4000-8000-000000000011') ->> 'result', 'ok',
  'the day after her absence she can be made responsible');
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 3, '10:00', '10:30', 30, 0, 0, false,
          '00000000-0000-4000-a000-000000000906', 'a5000000-0000-4000-8000-000000000012') ->> 'result', 'ok',
  'a colleague who is available can be made responsible on day +3');
reset role;
select is(pg_temp.visit_at('00000000-0000-4000-a000-000000000208', 3, '08:00'), null, '(a) the refused plan wrote no visit');

-- 2. (b) the same visit planned uncovered -----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 3, '08:00', '08:30', 30, 0, 0, false,
          null, 'a5000000-0000-4000-8000-000000000013') ->> 'result', 'ok',
  'ABS1-C4 (b): the same visit planned without a responsible member is accepted');
select ok(pg_temp.visit_at('00000000-0000-4000-a000-000000000208', 3, '08:00')
          = any (select visit_id from public.team_open_visits(pg_temp.today() + 3)),
  '(b) and is listed in "Offen im Team"');
reset role;

-- 3. (c) a move into her absence releases the visit -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.vid('move_in'), pg_temp.today() + 3, '07:00', '07:30', 'Wunsch der Klientin',
          'a5000000-0000-4000-8000-000000000020') - 'visit_id' - 'flags', '{"result": "ok", "released": true}'::jsonb,
  'ABS1-C4 (c): moving her visit into her absence is not refused, and the visit is released');
select ok(pg_temp.vid('move_in') = any (select visit_id from public.team_open_visits(pg_temp.today() + 3)),
  '(c) the moved visit appears in "Offen im Team"');
reset role;
select is(pg_temp.resp(pg_temp.vid('move_in')), null, '(c) nobody is responsible for the moved visit');
select is((select (visit_date - pg_temp.today()) from public.care_visits where id = pg_temp.vid('move_in')), 3, '(c) the move itself is kept');
select is((select array_agg(change || ':' || coalesce(reason, '') order by change) from public.visit_plan_changes
           where visit_id = pg_temp.vid('move_in')),
  array['moved:Wunsch der Klientin', 'released:Abwesenheit'],
  '(c) the J3 log has the move with its reason, then the release with the fixed text "Abwesenheit"');
select is((select count(*)::int from public.absence_releases r join public.member_absences a on a.id = r.absence_id
           where r.visit_id = pg_temp.vid('move_in') and a.team_id = '00000000-0000-4000-a000-000000000101'), 1,
  '(c) the release is linked to the absence of the visit''s team');

-- 4. (d) the same kind of move outside her absence keeps her ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.reschedule_visit(pg_temp.vid('move_out'), pg_temp.today() + 5, '09:00', '09:30', 'Wunsch der Klientin',
          'a5000000-0000-4000-8000-000000000021') ->> 'released', 'false',
  'ABS1-C4 (d): moving her visit to a day she is not absent releases nothing');
reset role;
select is(pg_temp.resp(pg_temp.vid('move_out')), '00000000-0000-4000-a000-000000000902'::uuid, '(d) the visit stays hers');
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.vid('move_out') and change = 'released'), 0,
  '(d) no release is logged');

-- 5. (e) a member of two teams; ABS1-N1 -------------------------------------------------------------------------------
-- 902 joins team Mitte after the day +3 absence was recorded (no Mitte row for it); 901 joins Mitte too.
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000902', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'registered_nurse');
update public.care_visits set responsible_user_id = '00000000-0000-4000-a000-000000000902'
  where id in (pg_temp.vid('mitte_v6'), pg_temp.vid('mitte_v8'), pg_temp.vid('mitte_move'));

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.plan_visit('00000000-0000-4000-a000-000000000210', pg_temp.today() + 3, '10:00', '10:30', 30, 0, 0, false,
          '00000000-0000-4000-a000-000000000902', 'a5000000-0000-4000-8000-000000000030') ->> 'reason', 'responsible_absent',
  'ABS1-C4 (e): absent via team Nord, she cannot be made responsible in team Mitte by hand (joined after the absence)');
select is(public.reschedule_visit(pg_temp.vid('mitte_move'), pg_temp.today() + 3, '11:00', '11:30', 'Wunsch der Klientin',
          'a5000000-0000-4000-8000-000000000031') ->> 'released', 'true',
  '(e) a Mitte visit moved into that absence is released as well');
reset role;
select is(pg_temp.resp(pg_temp.vid('mitte_move')), null, '(e) nobody is responsible for it');
select is((select count(*)::int from public.absence_releases where visit_id = pg_temp.vid('mitte_move')), 0,
  '(e) without a Mitte row for that absence the release is not linked (withdrawing it will not return the visit)');

-- ABS1-N1: a colleague of Nord records her absent on day +6; she now has visits in both teams.
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
          pg_temp.today() + 6, null, null, null, 'a5000000-0000-4000-8000-000000000040') - 'absence_id',
  '{"result": "ok", "released": 1, "teams": 2, "past_planned": 0}'::jsonb,
  'ABS1-N1: a colleague of Nord only learns how many Nord visits were released');
reset role;
select is(pg_temp.resp(pg_temp.vid('nord_v6')), null, 'ABS1-N1: the Nord visit is released');
select is(pg_temp.resp(pg_temp.vid('mitte_v6')), null, 'and the Mitte visit too (the count is narrowed, not the release)');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_absence('00000000-0000-4000-a000-000000000101', null,
          pg_temp.today() + 8, null, null, null, 'a5000000-0000-4000-8000-000000000041') ->> 'released', '2',
  'ABS1-N1: recording her own absence, she sees the visits of both her teams');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.plan_visit('00000000-0000-4000-a000-000000000210', pg_temp.today() + 6, '10:00', '10:30', 30, 0, 0, false,
          '00000000-0000-4000-a000-000000000902', 'a5000000-0000-4000-8000-000000000032') ->> 'reason', 'responsible_absent',
  'ABS1-C4 (e): a member of two teams absent via team Nord cannot be made responsible in team Mitte by hand');
select is(public.plan_visit('00000000-0000-4000-a000-000000000210', pg_temp.today() + 6, '10:00', '10:30', 30, 0, 0, false,
          '00000000-0000-4000-a000-000000000901', 'a5000000-0000-4000-8000-000000000033') ->> 'result', 'ok',
  '(e) a colleague of Mitte who is available can');
reset role;
select is((select count(*)::int from public.care_visits where case_id = '00000000-0000-4000-a000-000000000210'
           and visit_date = pg_temp.today() + 6 and time_start = '10:00'), 1, '(e) only the accepted plan wrote a visit');

-- 6. The absence is withdrawn: the moved and released Nord visit returns to her ---------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.change_absence((select absence_id from public.team_absences() where team_id = '00000000-0000-4000-a000-000000000101'
             and starts_at = ((pg_temp.today() + 3) + time '00:00') at time zone 'Europe/Zurich'), true, null, null,
          'a5000000-0000-4000-8000-000000000050') ->> 'returned', '1',
  'withdrawn by the recorder: the visit moved into the absence returns (linked release)');
reset role;
select is(pg_temp.resp(pg_temp.vid('move_in')), '00000000-0000-4000-a000-000000000902'::uuid, 'the moved visit is hers again');
select is(pg_temp.resp(pg_temp.vid('mitte_move')), null, 'the unlinked Mitte visit stays open in the team (deviation, ADR-061)');

-- Another organisation cannot plan for her.
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 9, '08:00', '08:30', 30, 0, 0, false,
          '00000000-0000-4000-a000-000000000902', 'a5000000-0000-4000-8000-000000000060') ->> 'reason', 'not_team_member',
  'another organisation is refused before any absence check');
reset role;

select * from finish();
rollback;
