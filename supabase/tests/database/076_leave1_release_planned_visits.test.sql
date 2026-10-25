-- LEAVE1-13: her planned visits go to the team, not back to the administrator (migration 0076, ADR-089). Brief
-- `docs/agents/briefs/LEAVE1.md` LEAVE1-13 (PO 2026-10-25 22:10 CET).
-- Users: nurse …906 (care assistant, Nord) · admin …905 (org A). Synthetic user added here: …7601 care assistant of
-- Testteam Nord …101 and Testteam Mitte …102, the leaver. Cases …208 (Nord) and …210 (Mitte). All data synthetic; every
-- step goes through the real commands, except the steps marked "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'ca' then '00000000-0000-4000-a000-000000000906' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'l' then 'a0760000-0000-4000-a000-000000007601' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0761000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
-- Run a command as a user through `authenticated`, then return to the table owner.
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.end_(k int) returns jsonb language sql as $$
  select pg_temp.cmd('admin', format('select public.end_member_access(%L::uuid, %L, %L::uuid)',
                                     pg_temp.u('l'), 'employment_ended', pg_temp.k(k))) $$;

-- Synthetic account (as the table owner) ------------------------------------------------------------------------------
insert into auth.users (id, email) values (pg_temp.u('l'), 'leave1c-l@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('l'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('l'), 'care_assistant'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('l'), 'care_assistant');

create temp table fx (name text primary key, id uuid not null);
grant select on fx to authenticated;
insert into fx values
  ('today',    'a0760000-0000-4000-8000-000000000001'),   -- Nord, planned in ~2 h: released, uncovered exception
  ('tomorrow', 'a0760000-0000-4000-8000-000000000002'),   -- Mitte, planned tomorrow 09:00: released, inside 24 h
  ('week',     'a0760000-0000-4000-8000-000000000003'),   -- Nord, planned next week: released, outside the threshold
  ('susp',     'a0760000-0000-4000-8000-000000000004'),   -- Nord, planned in 3 days, suspended: released (CGR-09)
  ('past',     'a0760000-0000-4000-8000-000000000005'),   -- Nord, planned yesterday: not touched
  ('cover',    'a0760000-0000-4000-8000-000000000006'),   -- Mitte, …906 responsible, she covers it: refuses
  ('other',    'a0760000-0000-4000-8000-000000000007');   -- Nord, …906 responsible: not touched

insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, status, responsible_user_id, suspended_at)
select f.id, '00000000-0000-4000-b000-000000000011', x.case_id, x.team_id, x.d, x.t, 'planned', x.who, x.susp
from fx f join (values
  ('today',    '00000000-0000-4000-a000-000000000208'::uuid, '00000000-0000-4000-a000-000000000101'::uuid,
               ((private.now() + interval '2 hours') at time zone 'Europe/Zurich')::date,
               date_trunc('minute', ((private.now() + interval '2 hours') at time zone 'Europe/Zurich'))::time,
               pg_temp.u('l'), null::timestamptz),
  ('tomorrow', '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102',
               (private.now() at time zone 'Europe/Zurich')::date + 1, time '09:00', pg_temp.u('l'), null),
  ('week',     '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
               (private.now() at time zone 'Europe/Zurich')::date + 7, time '09:00', pg_temp.u('l'), null),
  ('susp',     '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
               (private.now() at time zone 'Europe/Zurich')::date + 3, time '09:00', pg_temp.u('l'), private.now()),
  ('past',     '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
               (private.now() at time zone 'Europe/Zurich')::date - 1, time '09:00', pg_temp.u('l'), null),
  ('cover',    '00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102',
               (private.now() at time zone 'Europe/Zurich')::date + 2, time '09:00', pg_temp.u('ca'), null),
  ('other',    '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
               (private.now() at time zone 'Europe/Zurich')::date + 1, time '11:00', pg_temp.u('ca'), null)
) as x(name, case_id, team_id, d, t, who, susp) on x.name = f.name;
-- She covers the Mitte visit for her team Nord (as the table owner; cover is not switched on in the app).
update public.care_visits set covered_by = pg_temp.u('l'), covered_at = private.now(),
                              cover_team_id = '00000000-0000-4000-a000-000000000101'
where id = (select id from fx where name = 'cover');

create function pg_temp.resp(n text) returns uuid language sql as $$
  select v.responsible_user_id from public.care_visits v join fx on fx.id = v.id where fx.name = n $$;
create function pg_temp.uncovered(n text) returns boolean language sql as $$
  select exists (select 1 from private.derived_exceptions('00000000-0000-4000-b000-000000000011') e
                 where e.entity_id = (select id from fx where name = n) and e.exception_type like 'visit_uncovered%') $$;

-- 1. A planned visit she covers still refuses, and nothing is released ------------------------------------------------
select is(pg_temp.end_(1) ->> 'result', 'has_planned_visits', 'a planned visit she covers for another team: has_planned_visits');
select is(pg_temp.resp('today'), pg_temp.u('l'), 'the refused end releases nothing');
select is((select count(*)::int from public.member_access_events where user_id = pg_temp.u('l')), 0, 'and records no access end');

update public.care_visits set covered_by = null, covered_at = null, cover_team_id = null
where id = (select id from fx where name = 'cover');  -- the cover ended (as the table owner)

-- 2. The end releases her planned visits, per team, in the same command ------------------------------------------------
create temp table res as select pg_temp.end_(2) r;
select is((select r ->> 'result' from res), 'ok', 'responsible for planned visits in two teams: the access ends');
select is((select r -> 'released' from res),
          jsonb_build_object('00000000-0000-4000-a000-000000000101', 3, '00000000-0000-4000-a000-000000000102', 1),
          'the result names the number released per team');
select ok((select r ? 'open_reports' and r ? 'push_subscriptions_removed' from res), 'the result keeps the open reports and push count');
select is(pg_temp.resp('today'), null::uuid, 'today''s visit has no responsible member');
select is(pg_temp.resp('tomorrow'), null::uuid, 'tomorrow''s visit (the other team) has no responsible member');
select is(pg_temp.resp('week'), null::uuid, 'next week''s visit has no responsible member');
select is(pg_temp.resp('susp'), null::uuid, 'a suspended visit is released too (CGR-09, as removal)');
select is(pg_temp.resp('past'), pg_temp.u('l'), 'a past planned visit is not touched (same start as removal)');
select is(pg_temp.resp('other'), pg_temp.u('ca'), 'a colleague''s visit is not touched');
select ok((select bool_and(v.status = 'planned') from public.care_visits v join fx on fx.id = v.id
           where fx.name in ('today', 'tomorrow', 'week', 'susp')), 'the released visits stay planned');

-- Same released state as after remove_team_member: plan change log row with the neutral fixed text only.
select is((select count(*)::int from public.visit_plan_changes pc join fx on fx.id = pc.visit_id
           where pc.change = 'released' and pc.reason = 'Zugang beendet' and pc.actor_id = pg_temp.u('admin')
             and (pc.before ->> 'responsible_id')::uuid = pg_temp.u('l') and pc.after ->> 'responsible_id' is null), 4,
  'each release is in the team''s plan change log with the fixed text "Zugang beendet"');
select ok(not exists (select 1 from public.visit_plan_changes pc join fx on fx.id = pc.visit_id
                      where pc.reason like '%employment%' or pc.reason like '%access_withdrawn%'),
  'LEAVE1-8: the reason code is in no team-readable plan change row');

-- The existing exceptions apply unchanged: uncovered inside the threshold (24 h), not outside.
select ok(pg_temp.uncovered('today') and pg_temp.uncovered('tomorrow'),
  'today''s and tomorrow''s released visits appear in OPS1 as uncovered (inside the threshold)');
select ok(not pg_temp.uncovered('week'), 'next week''s released visit is outside the threshold');

-- Audit and administration log.
select ok(exists (select 1 from public.audit_events a join fx on fx.id = a.entity_id
                  where fx.name = 'today' and a.table_name = 'care_visits' and a.command = 'end_member_access'
                    and a.changed ? 'responsible_user_id'),
  'the release is audited under the access end command');
select is((select changes -> 'released_visits' from public.change_log
           where command = 'end_member_access' and entity_id = pg_temp.u('l')::text),
          jsonb_build_object('00000000-0000-4000-a000-000000000101', 3, '00000000-0000-4000-a000-000000000102', 1),
  'the change log names the number released per team');

-- 3. Idempotent; a restore does not give the visits back -------------------------------------------------------------
select is(pg_temp.end_(2) ->> 'result', 'duplicate', 'same key: duplicate');
select is((select count(*)::int from public.visit_plan_changes pc join fx on fx.id = pc.visit_id where pc.change = 'released'), 4,
  'the duplicate releases nothing more');
select ok(pg_temp.cmd('admin', format('select public.restore_member_access(%L::uuid, %L, %L::uuid)',
                                      pg_temp.u('l'), 'ended_in_error', pg_temp.k(3))) ->> 'result' = 'ok'
          and pg_temp.resp('today') is null and pg_temp.resp('tomorrow') is null,
  'restored: the released visits stay open in the team (no automatic re-assignment; the team decides who takes them)');

select * from finish();
rollback;
