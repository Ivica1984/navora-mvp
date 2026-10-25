-- ADM1 changes (PO review 2026-10-22 20:15, docs/agents/briefs/ADM1.md; migration 0036).
-- Users: admin …905 · nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord)
--        · foreign admin …903 (org B).
-- 1. Removal releases her future planned visits (one release rule, reused by ABS1).
--    Privacy: the team-readable plan change log has a fixed text, never the administrator's reason.
--    CGR-09: pause → removal → resume: her suspended visits come back uncovered, not covered by a non-member.
--    CGR-10: removal is refused while a visit of hers is on the way, started or paused.
-- 2. Role change keeps her team membership, qualification and visits; she can still start them.
-- 3. Display names in report signatures and quality authors; never another organisation's; null without a profile.
begin;
create extension if not exists pgtap with schema extensions;

select plan(39);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
-- …906 is also a member of Testteam Mitte (…102), so we can check another team's visit stays untouched.
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000906', 'care_assistant');

create temp table fx (name text primary key, id uuid not null);
grant select on fx to authenticated;
insert into fx values
  ('near',      '00000000-0000-4000-a036-000000000001'),   -- planned, in ~2 h: released, becomes uncovered
  ('later',     '00000000-0000-4000-a036-000000000002'),   -- planned, in 3 days: released
  ('started',   '00000000-0000-4000-a036-000000000003'),   -- started today: refuses removal (CGR-10)
  ('otw',       '00000000-0000-4000-a036-000000000009'),   -- on the way today: refuses removal (CGR-10)
  ('paused',    '00000000-0000-4000-a036-000000000010'),   -- paused today: refuses removal (CGR-10)
  ('past',      '00000000-0000-4000-a036-000000000004'),   -- planned yesterday: unchanged
  ('completed', '00000000-0000-4000-a036-000000000005'),   -- completed today: unchanged
  ('other',     '00000000-0000-4000-a036-000000000007'),   -- planned, Testteam Mitte: unchanged
  ('rn',        '00000000-0000-4000-a036-000000000008');   -- planned tomorrow, …902 responsible (role change)

insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, status, responsible_user_id, suspended_at)
select f.id, '00000000-0000-4000-b000-000000000011', x.case_id, x.team_id, x.d, x.t, x.status, x.who, x.susp
from fx f join (values
  ('near',      '00000000-0000-4000-a000-000000000208'::uuid, '00000000-0000-4000-a000-000000000101'::uuid,
                ((private.now() + interval '2 hours') at time zone 'Europe/Zurich')::date,
                date_trunc('minute', ((private.now() + interval '2 hours') at time zone 'Europe/Zurich'))::time,
                'planned', '00000000-0000-4000-a000-000000000906'::uuid, null::timestamptz),
  ('later',     '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                (private.now() at time zone 'Europe/Zurich')::date + 3, time '09:00', 'planned', '00000000-0000-4000-a000-000000000906', null),
  ('started',   '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                (private.now() at time zone 'Europe/Zurich')::date, time '07:00', 'started', '00000000-0000-4000-a000-000000000906', null),
  ('past',      '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                (private.now() at time zone 'Europe/Zurich')::date - 1, time '09:00', 'planned', '00000000-0000-4000-a000-000000000906', null),
  ('completed', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                (private.now() at time zone 'Europe/Zurich')::date, time '06:00', 'completed', '00000000-0000-4000-a000-000000000906', null),
  ('otw',       '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                (private.now() at time zone 'Europe/Zurich')::date, time '07:30', 'on_the_way', '00000000-0000-4000-a000-000000000906', null),
  ('paused',    '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                (private.now() at time zone 'Europe/Zurich')::date, time '07:45', 'paused', '00000000-0000-4000-a000-000000000906', null),
  ('other',     '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102',
                (private.now() at time zone 'Europe/Zurich')::date + 2, time '09:00', 'planned', '00000000-0000-4000-a000-000000000906', null),
  ('rn',        '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                (private.now() at time zone 'Europe/Zurich')::date + 1, time '10:00', 'planned', '00000000-0000-4000-a000-000000000902', null)
) as x(name, case_id, team_id, d, t, status, who, susp) on x.name = f.name;

create function pg_temp.resp(n text) returns uuid language sql as $$
  select v.responsible_user_id from public.care_visits v join fx on fx.id = v.id where fx.name = n $$;
create function pg_temp.suspended(n text) returns boolean language sql as $$
  select v.suspended_at is not null from public.care_visits v join fx on fx.id = v.id where fx.name = n $$;
-- Test setup only (as the test owner, not a command): hands a fixture visit to …906 or to …902.
create function pg_temp.hand(n text, who text) returns void language sql as $$
  update public.care_visits set responsible_user_id = who::uuid where id = (select id from fx where name = n) $$;

-- Structure ---------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('authenticated', 'private.release_member_visits(uuid, uuid, date, date, text, uuid)', 'execute'),
  'the release rule is not callable by app users (only through commands)');
select is((select pg_get_function_result('public.remove_team_member(uuid, uuid, text, uuid)'::regprocedure)), 'jsonb',
  'removal returns the result and the number of released visits');

-- 1. Removal releases her future planned visits --------------------------------------------------------------------
select ok(not ('uncovered' = any (private.visit_flags(v.case_id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start))),
  'before: her near visit looks covered')
from public.care_visits v join fx on fx.id = v.id where fx.name = 'near';

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Fremdzugriff',
          'a3600000-0000-4000-8000-000000000001') ->> 'result', 'rejected', 'an administrator of another organisation cannot remove');
reset role;
select is(pg_temp.resp('near'), '00000000-0000-4000-a000-000000000906'::uuid, 'a refused removal releases nothing');

-- CGR-10: a visit in progress refuses the removal, each status on its own ---------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Wechsel nach Mitte',
          'a3600000-0000-4000-8000-000000000020') ->> 'result', 'has_visit_in_progress',
  'CGR-10: removal is refused while she has visits in progress');
reset role;
select is(pg_temp.resp('near'), '00000000-0000-4000-a000-000000000906'::uuid, 'CGR-10: the refused removal releases nothing');
select ok(exists (select 1 from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101'
                  and user_id = '00000000-0000-4000-a000-000000000906'), 'CGR-10: and she stays a member');

select pg_temp.hand('started', '00000000-0000-4000-a000-000000000902'), pg_temp.hand('otw', '00000000-0000-4000-a000-000000000902');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Wechsel nach Mitte',
          'a3600000-0000-4000-8000-000000000021') ->> 'result', 'has_visit_in_progress', 'CGR-10: a paused visit alone refuses it');
reset role;
select pg_temp.hand('paused', '00000000-0000-4000-a000-000000000902'), pg_temp.hand('otw', '00000000-0000-4000-a000-000000000906');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Wechsel nach Mitte',
          'a3600000-0000-4000-8000-000000000022') ->> 'result', 'has_visit_in_progress', 'CGR-10: a visit on the way alone refuses it');
reset role;
select pg_temp.hand('otw', '00000000-0000-4000-a000-000000000902'), pg_temp.hand('started', '00000000-0000-4000-a000-000000000906');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Wechsel nach Mitte',
          'a3600000-0000-4000-8000-000000000023') ->> 'result', 'has_visit_in_progress', 'CGR-10: a started visit alone refuses it');
reset role;
-- She finished her visits (here: handed over for the test); nothing in progress any more.
select pg_temp.hand('started', '00000000-0000-4000-a000-000000000902');

-- CGR-09: the case is paused before the removal; her future visits are suspended ---------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'client_absence', null, null,
          'a3600000-0000-4000-8000-000000000030'), 'ok', 'CGR-09: the team pauses the case');
reset role;
select ok(pg_temp.suspended('near') and pg_temp.suspended('later'), 'CGR-09: her two future visits are suspended');

select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Wechsel nach Mitte',
          'a3600000-0000-4000-8000-000000000002'),
  jsonb_build_object('result', 'ok', 'released', 2), 'the removal releases her two future planned visits (suspended included) and says how many');
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Wechsel nach Mitte',
          'a3600000-0000-4000-8000-000000000002') ->> 'result', 'duplicate', 'resend is a duplicate and releases nothing more');
reset role;

select ok(not exists (select 1 from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101'
                      and user_id = '00000000-0000-4000-a000-000000000906'), 'she is no longer a member of the team');
select is(pg_temp.resp('near'), null, 'CGR-09: the suspended near visit no longer names her');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.resume_case('00000000-0000-4000-a000-000000000208', 'a3600000-0000-4000-8000-000000000031'), 'ok',
  'CGR-09: the team resumes the case');
reset role;
select ok(not pg_temp.suspended('near') and not pg_temp.suspended('later'), 'CGR-09: after resume her visits are active again');
select is(pg_temp.resp('near'), null, 'the near visit has no responsible member');
select is(pg_temp.resp('later'), null, 'the later visit has no responsible member');
select ok('uncovered' = any (private.visit_flags(v.case_id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start)),
  'the released near visit carries the J3 flag uncovered')
from public.care_visits v join fx on fx.id = v.id where fx.name = 'near';
select ok(exists (select 1 from private.derived_exceptions('00000000-0000-4000-b000-000000000011') e
                  where e.entity_id = (select id from fx where name = 'near') and e.exception_type like 'visit_uncovered%'),
  'and appears in OPS1 as an uncovered visit');
select is(pg_temp.resp('completed'), '00000000-0000-4000-a000-000000000906'::uuid, 'her completed visit is unchanged');
select is(pg_temp.resp('past'), '00000000-0000-4000-a000-000000000906'::uuid, 'her past visit is unchanged');
select is(pg_temp.resp('other'), '00000000-0000-4000-a000-000000000906'::uuid, 'another team''s visit is untouched');
select is((select count(*)::int from public.visit_plan_changes pc join fx on fx.id = pc.visit_id
           where pc.change = 'released' and pc.reason = 'Mitglied aus dem Team entfernt'
             and pc.actor_id = '00000000-0000-4000-a000-000000000905'
             and pc.before ->> 'responsible_id' = '00000000-0000-4000-a000-000000000906' and pc.after ->> 'responsible_id' is null), 2,
  'each release is in the plan change log with the neutral fixed text');
select ok(not exists (select 1 from public.visit_plan_changes where reason like '%Wechsel nach Mitte%'),
  'privacy: the administrator''s reason is in no team-readable plan change row');
select ok(exists (select 1 from public.change_log where command = 'remove_team_member' and reason = 'Wechsel nach Mitte'
                  and entity_id like '%/00000000-0000-4000-a000-000000000906'),
  'privacy: the reason stays in the administration change log');
select ok(exists (select 1 from public.audit_events a join fx on fx.id = a.entity_id
                  where fx.name = 'near' and a.table_name = 'care_visits' and a.command = 'remove_team_member'
                    and a.changed ? 'responsible_user_id'),
  'the release is audited under the removal command');
select ok((select (changes ->> 'released_visits')::int = 2 from public.change_log
           where command = 'remove_team_member' and entity_id like '%/00000000-0000-4000-a000-000000000906'),
  'the removal''s change log names the number released');

-- 2. Role change: membership, qualification and visits stay; she can still start them -------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_member_role('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'coach', 'Wechsel ins Coaching',
          'a3600000-0000-4000-8000-000000000010'), 'ok', 'a nurse responsible for a future visit becomes coach');
reset role;
select ok((select qualification = 'registered_nurse' from public.team_memberships
           where team_id = '00000000-0000-4000-a000-000000000101' and user_id = '00000000-0000-4000-a000-000000000902'),
  'her team membership and qualification are unchanged');
select is(pg_temp.resp('rn'), '00000000-0000-4000-a000-000000000902'::uuid, 'her future visit stays assigned to her');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit((select id from fx where name = 'rn'), 'a3600000-0000-4000-8000-000000000011'), 'ok',
  'and she can still start it');
reset role;

-- 3. Names where people appear --------------------------------------------------------------------------------------
-- …902 has a profile in her organisation; …906 has none there, but one in organisation B (must never show).
insert into public.member_profiles (organization_id, user_id, display_name)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'Anna Muster');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000906', 'nurse');
insert into public.member_profiles (organization_id, user_id, display_name)
values ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000906', 'Fremder Name');
insert into public.visit_reports (organization_id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by, signed_by, signed_at, countersigned_by, countersigned_at)
values ('00000000-0000-4000-b000-000000000011', (select id from fx where name = 'started'), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', 1, 'final', '{}', '00000000-0000-4000-a000-000000000902', true,
        '00000000-0000-4000-a000-000000000902', '00000000-0000-4000-a000-000000000902', private.now(),
        '00000000-0000-4000-a000-000000000906', private.now());
insert into public.quality_events (organization_id, visit_id, case_id, team_id, event_type, severity, title, author_id) values
  ('00000000-0000-4000-b000-000000000011', (select id from fx where name = 'started'), '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', 'other', 'low', 'Testereignis A', '00000000-0000-4000-a000-000000000902'),
  ('00000000-0000-4000-b000-000000000011', (select id from fx where name = 'started'), '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', 'other', 'low', 'Testereignis B', '00000000-0000-4000-a000-000000000906');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select signed_by_name from public.field_reports((private.now() at time zone 'Europe/Zurich')::date)
           where visit_id = (select id from fx where name = 'started')), 'Anna Muster',
  'the report shows the signer''s display name');
select is((select countersigned_by_name from public.field_reports((private.now() at time zone 'Europe/Zurich')::date)
           where visit_id = (select id from fx where name = 'started')), null,
  'without a profile in this organisation the countersigner''s name is null (neutral label), never another organisation''s');
select is((select person_name from public.field_quality((private.now() at time zone 'Europe/Zurich')::date) where label = 'Testereignis A'),
  'Anna Muster', 'the quality event shows the author''s display name');
select is((select person_name from public.field_quality((private.now() at time zone 'Europe/Zurich')::date) where label = 'Testereignis B'),
  null, 'an author without a profile here has no name, never another organisation''s');
reset role;

select * from finish();
rollback;
