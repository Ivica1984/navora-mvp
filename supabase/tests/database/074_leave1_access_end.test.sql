-- LEAVE1 part (a): access ends when employment ends (migration 0074, ADR-087). Brief `docs/agents/briefs/LEAVE1.md`
-- (LEAVE1-1, -2, -3, -4, -7, -8, -10). Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care
-- assistant, Nord) · coach …901 · operations …904 · admin …905 (org A, no team) · admin …903 (org B).
-- Synthetic users added here: …7401 care assistant of Nord, the leaver with open reports; …7402 nurse of Nord with
-- states someone else can clear; …7403 a second operations user of org A. Case …208 (Nord). All data synthetic; every
-- step goes through the real commands, except the steps marked "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(67);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns text language sql immutable as $$
  select case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                when 'admin' then '00000000-0000-4000-a000-000000000905' when 'admin_b' then '00000000-0000-4000-a000-000000000903'
                when 'l1' then 'a0740000-0000-4000-a000-000000007401' when 'l2' then 'a0740000-0000-4000-a000-000000007402'
                when 'ops2' then 'a0740000-0000-4000-a000-000000007403' end
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0741000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
-- Run a command as a user through `authenticated`, then return to the table owner.
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.end_(p_by text, p_who text, p_code text, k int) returns text language sql as $$
  select pg_temp.cmd(p_by, format('select public.end_member_access(%L::uuid, %L, %L::uuid)', pg_temp.u(p_who), p_code, pg_temp.k(k))) ->> 'result' $$;
create function pg_temp.restore_(p_by text, p_who text, p_code text, k int) returns text language sql as $$
  select pg_temp.cmd(p_by, format('select public.restore_member_access(%L::uuid, %L, %L::uuid)', pg_temp.u(p_who), p_code, pg_temp.k(k))) ->> 'result' $$;
create function pg_temp.seen(p_user text, p_sql text) returns integer language plpgsql as $$
declare n integer;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute 'select count(*)::int from (' || p_sql || ') x' into n;
  execute 'reset role';
  return n;
end $$;
-- LEAVE1-3 catalogue: every table `authenticated` can read, with the rows the user sees (only non-zero ones listed).
create function pg_temp.tables_seen(p_user text) returns text language plpgsql as $$
declare t text; n integer; acc text := '';
begin
  for t in select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
           where s.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p', 'f')
             and has_any_column_privilege('authenticated', c.oid, 'select') order by 1 loop
    n := pg_temp.seen(p_user, format('select 1 from public.%I', t));
    if n > 0 then acc := acc || t || '=' || n || ' '; end if;
  end loop;
  return btrim(acc);
end $$;
-- LEAVE1-3 catalogue: every set-returning read model `authenticated` may call, called with today / null arguments.
create function pg_temp.read_models_seen(p_user text) returns text language plpgsql as $$
declare f record; arg text; n integer; acc text := '';
begin
  for f in select p.oid, p.proname, p.proargtypes::regtype[] ty from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and p.prokind = 'f' and p.proretset and p.provolatile in ('s', 'i')
             and has_function_privilege('authenticated', p.oid, 'execute') order by 2 loop
    select string_agg(case x::text when 'date' then '(private.at_zurich(private.now()))::date' when 'boolean' then 'true'
                                   else 'null::' || x::text end, ', ') into arg from unnest(f.ty) x;
    n := pg_temp.seen(p_user, format('select 1 from public.%I(%s)', f.proname, coalesce(arg, '')));
    if n > 0 then acc := acc || f.proname || '=' || n || ' '; end if;
  end loop;
  return btrim(acc);
end $$;

-- Synthetic accounts (as the table owner) -----------------------------------------------------------------------------
insert into auth.users (id, email) values
  (pg_temp.u('l1')::uuid, 'leave1-l1@navora.test'), (pg_temp.u('l2')::uuid, 'leave1-l2@navora.test'),
  (pg_temp.u('ops2')::uuid, 'leave1-ops2@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('l1')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('l2')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('ops2')::uuid, 'operations');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('l1')::uuid, 'care_assistant'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('l2')::uuid, 'registered_nurse');

-- Visits of today (Nord, case 208): o1-o3 the leaver's open reports, p1 planned and q1 in progress for …7402.
create temp table fx (name text primary key, id uuid not null, t time not null, resp uuid not null);
grant select on fx to authenticated, service_role;
insert into fx values
  ('o1', 'a0740000-0000-4000-8000-000000000001', '05:00', pg_temp.u('l1')::uuid),
  ('o2', 'a0740000-0000-4000-8000-000000000002', '05:30', pg_temp.u('l1')::uuid),
  ('o3', 'a0740000-0000-4000-8000-000000000003', '06:00', pg_temp.u('l1')::uuid),
  ('p1', 'a0740000-0000-4000-8000-000000000004', '23:00', pg_temp.u('l2')::uuid),
  ('q1', 'a0740000-0000-4000-8000-000000000005', '06:30', pg_temp.u('l2')::uuid);
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (private.at_zurich(private.now()))::date, f.t, f.t + interval '30 minutes',
       false, 'planned', 20, 0, 10, f.resp
from fx f;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.report_v(n text, v int) returns public.visit_reports language sql security definer as $$
  select r.* from public.visit_reports r where r.visit_id = pg_temp.vid(n) and r.version = v $$;
create function pg_temp.shown(n text) returns jsonb language sql as $$
  select to_jsonb(f) from public.field_reports(pg_temp.today()) f where f.visit_id = pg_temp.vid(n) $$;
create function pg_temp.run(n text, k int) returns jsonb language plpgsql as $$
begin
  perform public.start_visit(pg_temp.vid(n), pg_temp.k(k * 10 + 1));
  perform public.record_observation(pg_temp.vid(n), 'Synthetisch: Haut intakt', false, null, pg_temp.k(k * 10 + 2));
  perform public.complete_visit(pg_temp.vid(n), pg_temp.k(k * 10 + 3));
  return public.create_report_draft(pg_temp.vid(n), 'Synthetisch: Verlauf ruhig', pg_temp.k(k * 10 + 4));
end $$;
create function pg_temp.sign(n text, v int, k int) returns jsonb language sql as $$
  select public.sign_report((pg_temp.report_v(n, v)).id, pg_temp.shown(n) ->> 'snapshot_hash', pg_temp.k(k)) $$;

-- Open reports of the leaver: o1 an unsigned draft, o2 a returned report not signed again, o3 a correction draft.
select pg_temp.act_as(pg_temp.u('l1'));
set local role authenticated;
select pg_temp.run('o1', 1);
select pg_temp.run('o2', 2);
select pg_temp.sign('o2', 1, 25);
select pg_temp.run('o3', 3);
select pg_temp.sign('o3', 1, 35);
select pg_temp.act_as(pg_temp.u('rn'));
select public.return_report((pg_temp.report_v('o2', 1)).id, 'Synthetisch: Startzeit falsch erfasst', pg_temp.k(26));
select public.countersign_report((pg_temp.report_v('o3', 1)).id, pg_temp.k(36));
select pg_temp.act_as(pg_temp.u('l1'));
select public.correct_report((pg_temp.report_v('o3', 1)).id, 'Synthetisch: Dauer falsch', 'Synthetisch: Verlauf ruhig, korrigiert', pg_temp.k(37));
-- …7402 starts q1 (in progress).
select pg_temp.act_as(pg_temp.u('l2'));
select (public.start_visit(pg_temp.vid('q1'), pg_temp.k(51)) = 'ok') as q1_started;  -- not a bare 'ok' line (TAP)
reset role;

select is((select string_agg(f.name || '=' || r.version || ':' || r.status, ',' order by f.name, r.version)
           from fx f join public.visit_reports r on r.visit_id = f.id),
  'o1=1:draft,o2=1:signed,o2=2:draft,o3=1:final,o3=2:draft',
  'fixtures: o1 unsigned draft, o2 returned (new draft), o3 final with a correction draft');

-- (as the table owner) a push subscription of the leaver, and …7402 primary nurse of case 208.
insert into public.push_subscriptions (organization_id, user_id, vendor, endpoint, p256dh, auth_secret, last_result)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('l1')::uuid, 'google_fcm',
        'https://fcm.googleapis.com/fcm/send/leave1-synthetic', repeat('A', 87), repeat('B', 22), 'sent');
update public.cases set primary_nurse_id = pg_temp.u('l2')::uuid where id = '00000000-0000-4000-a000-000000000208';

-- History before (LEAVE1-4)
create temp table before_counts as
select (select count(*) from public.team_memberships where user_id = pg_temp.u('l1')::uuid) tm,
       (select count(*) from public.organization_memberships where user_id = pg_temp.u('l1')::uuid) om,
       (select count(*) from public.visit_reports where performer_id = pg_temp.u('l1')::uuid) rep,
       (select count(*) from public.visit_reports where signed_by = pg_temp.u('l1')::uuid) sig,
       (select count(*) from public.visit_events where actor_id = pg_temp.u('l1')::uuid) ev,
       (select count(*) from public.audit_events where actor_id = pg_temp.u('l1')::uuid) au;

-- Surface ---------------------------------------------------------------------------------------------------------------
select ok(has_function_privilege('authenticated', 'public.end_member_access(uuid, text, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.restore_member_access(uuid, text, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.end_member_access(uuid, text, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.restore_member_access(uuid, text, uuid)', 'execute'),
  'end and restore: members may call (the command checks the role), anon may not');
select ok((select relrowsecurity from pg_class where oid = 'public.member_access_events'::regclass)
          and not has_table_privilege('authenticated', 'public.member_access_events', 'insert')
          and not has_table_privilege('authenticated', 'public.member_access_events', 'update')
          and not has_table_privilege('authenticated', 'public.member_access_events', 'delete')
          and not has_table_privilege('anon', 'public.member_access_events', 'select'),
  'the access record: RLS on, no direct writes, anon reads nothing');
select is(pg_temp.seen('l1', 'select 1 from public.care_visits') > 0, true, 'before: the leaver reads her team''s visits');

-- LEAVE1-1: who may end an access --------------------------------------------------------------------------------------
select is(pg_temp.end_('rn', 'l1', 'employment_ended', 101), 'rejected', 'a nurse: refused');
select is(pg_temp.end_('coach', 'l1', 'employment_ended', 102), 'rejected', 'a coach: refused');
select is(pg_temp.end_('ops', 'l1', 'employment_ended', 103), 'rejected', 'operations: refused');
select is(pg_temp.end_('admin_b', 'l1', 'employment_ended', 104), 'rejected', 'the administrator of another organisation: refused');
select is(pg_temp.end_('admin', 'admin', 'employment_ended', 105), 'self', 'the administrator herself: refused');
select throws_ok($$ select pg_temp.end_('admin', 'l1', 'moved_away', 106) $$, '22023',
  'reason code must be employment_ended or access_withdrawn', 'no other reason code, no free text');
select ok(position('last_admin' in (select prosrc from pg_proc where oid = 'public.end_member_access(uuid, text, uuid)'::regprocedure)) > 0
          and position('not private.access_ended(m.user_id)' in (select prosrc from pg_proc where oid = 'public.end_member_access(uuid, text, uuid)'::regprocedure)) > 0,
  'ADM1 rule: the last administrator with access is never ended (the caller is always another administrator with access, so the guard is defence in depth)');
select is((select count(*)::int from public.member_access_events), 0, 'no refused attempt left a record');

-- LEAVE1-2: refused while someone else can clear it, and succeeds once cleared ------------------------------------------
select is(pg_temp.end_('admin', 'l2', 'employment_ended', 201), 'has_cases', 'primary nurse of an open case: has_cases');
update public.cases set primary_nurse_id = null where id = '00000000-0000-4000-a000-000000000208';  -- re-assigned (as the table owner)
select is(pg_temp.end_('admin', 'l2', 'employment_ended', 202), 'has_visit_in_progress', 'a visit in progress: has_visit_in_progress');
update public.care_visits set status = 'completed' where id = pg_temp.vid('q1');  -- closed (as the table owner)
-- LEAVE1-13 (0076): only a planned visit she covers still refuses; one she is responsible for is released (pgTAP 076).
update public.care_visits set responsible_user_id = pg_temp.u('ca')::uuid, covered_by = pg_temp.u('l2')::uuid, covered_at = private.now(),
                              cover_team_id = '00000000-0000-4000-a000-000000000101'
where id = pg_temp.vid('p1');  -- she covers p1 for …906 (as the table owner)
select is(pg_temp.end_('admin', 'l2', 'employment_ended', 203), 'has_planned_visits', 'covers a planned visit from today: has_planned_visits');
update public.care_visits set responsible_user_id = pg_temp.u('l2')::uuid, covered_by = null, covered_at = null, cover_team_id = null
where id = pg_temp.vid('p1');  -- cover ended; she is responsible for p1 again (as the table owner)
select is(pg_temp.end_('admin', 'l2', 'access_withdrawn', 204), 'ok',
  'cleared: the access ends (her completed visit without a report does not refuse; her planned visit p1 is released)');
select is((select responsible_user_id from public.care_visits where id = pg_temp.vid('p1')), null::uuid,
  'LEAVE1-13: the planned visit she was responsible for is released to the team');

select is(pg_temp.end_('admin', 'l1', 'employment_ended', 301), 'ok', 'LEAVE1-2: the leaver with an unsigned, a returned and a correction draft: ok');
select is(pg_temp.end_('admin', 'l1', 'employment_ended', 301), 'duplicate', 'same key: duplicate');
select is(pg_temp.end_('admin', 'l1', 'access_withdrawn', 302), 'unchanged', 'already ended: unchanged, no second record');
select is((select string_agg(kind || ':' || reason_code || ':' || (actor_id = pg_temp.u('admin')::uuid), ',')
           from public.member_access_events where user_id = pg_temp.u('l1')::uuid), 'ended:employment_ended:true',
  'one record: kind, code, actor');
select is((select count(*)::int from public.audit_events a
           where a.command = 'end_member_access' and a.entity_id = pg_temp.u('l1')::uuid
             and a.actor_id = pg_temp.u('admin')::uuid and a.changed ->> 'reason_code' = 'employment_ended'), 1,
  'audited: actor, person, code, time');
select is((select count(*)::int from public.change_log c where c.command = 'end_member_access' and c.entity_id = pg_temp.u('l1')),
  1, 'change log entry');

-- LEAVE1-3: she reads nothing and can do nothing ------------------------------------------------------------------------
select is(pg_temp.tables_seen('l1'), 'member_access_events=1', 'catalogue: every readable table returns zero rows for her, except her own notice');
select is(pg_temp.read_models_seen('l1'), '', 'catalogue: every read model returns zero rows for her');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and p.prokind = 'f' and p.prosecdef and p.proretset
             and has_function_privilege('authenticated', p.oid, 'execute') and position('LEAVE1-3' in p.prosrc) = 0), null,
  'catalogue: every SECURITY DEFINER read model carries the access guard (a new one cannot slip through)');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and p.prokind = 'f' and p.provolatile = 'v'
             and has_function_privilege('authenticated', p.oid, 'execute')
             and p.prosrc !~ '(begin_command|assert_access_open|private\.transition_visit|access_ended)'), null,
  'catalogue: every command reaches the access guard (begin_command, assert_access_open or a guarded transition)');
select is(pg_temp.tables_seen('rn') <> '', true, 'a colleague still reads (the policy is per person)');
select is((select string_agg(x, ',') from (select pg_temp.cmd('l1', format('select to_jsonb(%s)', f)) #>> '{}' x
           from unnest(array['private.is_team_member(''00000000-0000-4000-a000-000000000101'')',
                             'private.is_org_member(''00000000-0000-4000-b000-000000000011'')',
                             'private.has_org_role(''00000000-0000-4000-b000-000000000011'', array[''nurse''])']) f) y),
  'false,false,false', 'membership helpers return false for her');
select ok(position('access_ended(p_user)' in (select prosrc from pg_proc where oid = 'private.cover_team_for(public.care_visits, uuid)'::regprocedure)) > 0,
  'cover_team_for returns no team for her');

set local role authenticated;
select pg_temp.act_as(pg_temp.u('l1'));
select throws_ok(format('select public.start_visit(%L::uuid, %L::uuid)', pg_temp.vid('p1'), pg_temp.k(401)), '42501', 'access_ended',
  'a visit command: access_ended');
select throws_ok(format('select public.update_report_draft(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('o1', 1)).id, 'Synthetisch', pg_temp.k(402)),
  '42501', 'access_ended', 'her own draft: access_ended');
select throws_ok(format('select public.sign_report(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('o2', 2)).id, 'x', pg_temp.k(403)),
  '42501', 'access_ended', 'signing: access_ended');
select throws_ok(format('select public.record_observation(%L::uuid, %L, false, null, %L::uuid)', pg_temp.vid('o1'), 'Synthetisch', pg_temp.k(404)),
  '42501', 'access_ended', 'record_observation (own guard): access_ended');
select throws_ok('select public.accept_my_invitations()', '42501', 'access_ended', 'accepting an invitation: access_ended');
select throws_ok('select public.refresh_team_plans()', '42501', 'access_ended', 'refreshing plans: access_ended');
select throws_ok(format('select public.end_member_access(%L::uuid, %L, %L::uuid)', pg_temp.u('rn'), 'employment_ended', pg_temp.k(405)),
  '42501', 'access_ended', 'an access command: access_ended');
select is((select count(*)::int from public.my_signals()), 0, 'my_signals: nothing');
select is(public.my_access_state() ->> 'ended', 'true', 'her own state: ended');
select ok(not (public.my_access_state() ? 'reason_code'), 'her own state carries no reason code');
reset role;

-- Signals and push
select is((select count(*)::int from public.push_subscriptions where user_id = pg_temp.u('l1')::uuid), 0, 'her push subscriptions are removed');
select is((select count(*)::int from public.audit_events where table_name = 'push_subscriptions' and changed ->> 'reason' = 'access_ended'), 1,
  'the removal is audited');
select is(private.push_active(pg_temp.u('l1')::uuid), false, 'no outside delivery for her');
select is(pg_temp.end_('admin', 'ops2', 'employment_ended', 501), 'ok', 'a second operations user leaves');
select is((select string_agg(o::text, ',') from private.signal_operations_users('00000000-0000-4000-b000-000000000011') o),
  pg_temp.u('ops'), 'SIG1 operations receivers: never her');
select ok(position('not private.access_ended(d.user_id)' in (select prosrc from pg_proc where oid = 'private.signal_recipients(uuid)'::regprocedure)) > 0,
  'SIG1 team receivers: never her');

-- LEAVE1-4: her history stays -------------------------------------------------------------------------------------------
select is((select row(tm, om, rep, sig, ev)::text from before_counts),
  (select row((select count(*) from public.team_memberships where user_id = pg_temp.u('l1')::uuid),
              (select count(*) from public.organization_memberships where user_id = pg_temp.u('l1')::uuid),
              (select count(*) from public.visit_reports where performer_id = pg_temp.u('l1')::uuid),
              (select count(*) from public.visit_reports where signed_by = pg_temp.u('l1')::uuid),
              (select count(*) from public.visit_events where actor_id = pg_temp.u('l1')::uuid))::text),
  'memberships, reports, signatures and visit events unchanged');
select ok((select count(*) from public.audit_events where actor_id = pg_temp.u('l1')::uuid) = (select au from before_counts),
  'her audit events unchanged');
select is((select count(*)::int from auth.users where id = pg_temp.u('l1')::uuid), 1, 'the account row stays');
select is((select string_agg(r.version || ':' || r.status || ':' || (r.performer_id = pg_temp.u('l1')::uuid), ',' order by r.version)
           from public.visit_reports r where r.visit_id = pg_temp.vid('o2')), '1:signed:true,2:draft:true',
  'her reports still name her as performer');
select throws_ok($$ update public.member_access_events set reason_code = 'access_withdrawn' $$, '42501', 'member_access_events is append-only',
  'the record is append-only, also for the owner');

-- LEAVE1-8: who sees the record ------------------------------------------------------------------------------------------
select is(pg_temp.seen('admin', 'select 1 from public.member_access_events'), 3, 'the administrator reads every record of her organisation');
select is(pg_temp.seen('rn', 'select 1 from public.member_access_events'), 0, 'a colleague reads no record (the team marker is part b)');
select is(pg_temp.seen('ops', 'select 1 from public.member_access_events'), 0, 'operations reads no record');
select is(pg_temp.seen('admin_b', 'select 1 from public.member_access_events'), 0, 'another organisation reads nothing');
select is((select string_agg(p.oid::regprocedure::text, ',' order by p.oid::regprocedure::text collate "C")
           from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname in ('public', 'private') and p.prosrc like '%member_access_events%'),
  'end_member_access(uuid,text,uuid),my_access_state(),private.access_ended(uuid),private.access_ended_at(uuid),private.guard_member_access_event(),restore_member_access(uuid,text,uuid)',
  'catalogue: only the access commands and helpers read the record (no analytics, billing, export or push)');

-- LEAVE1-7: reversible ------------------------------------------------------------------------------------------------
select is(pg_temp.restore_('rn', 'l1', 'employment_resumed', 601), 'rejected', 'restore by a nurse: refused');
select is(pg_temp.restore_('admin_b', 'l1', 'employment_resumed', 602), 'rejected', 'restore by another organisation: refused');
select throws_ok($$ select pg_temp.restore_('admin', 'l1', 'because', 603) $$, '22023',
  'reason code must be employment_resumed or ended_in_error', 'restore: reason codes only');
select is(pg_temp.restore_('admin', 'rn', 'ended_in_error', 604), 'unchanged', 'restore of an open access: unchanged');
select is(pg_temp.restore_('admin', 'l1', 'ended_in_error', 605), 'ok', 'the administrator restores');
select is(pg_temp.seen('l1', 'select 1 from public.care_visits') > 0, true, 'after restore: she reads her team''s visits again');
select is(pg_temp.cmd('l1', 'select to_jsonb(private.is_team_member(''00000000-0000-4000-a000-000000000101''))') #>> '{}', 'true',
  'after restore: team member again');
select is(pg_temp.cmd('l1', 'select public.my_access_state()') ->> 'ended', 'false', 'after restore: her state is open');
select is((select count(*)::int from public.audit_events a where a.command = 'restore_member_access' and a.entity_id = pg_temp.u('l1')::uuid),
  1, 'the restore is audited');

-- LEAVE1-10: no regression ------------------------------------------------------------------------------------------------
select is(pg_temp.cmd('admin', format('select public.remove_team_member(%L::uuid, %L::uuid, %L, %L::uuid)',
            '00000000-0000-4000-a000-000000000101', pg_temp.u('l1'), 'Synthetisch: Austritt', pg_temp.k(701))) ->> 'result',
  'has_unsigned_reports', 'remove_team_member still refuses while her reports are open (0037, 0065 §8)');
select is(pg_temp.cmd('admin', format('select to_jsonb(public.set_member_role(%L::uuid, %L::uuid, %L, %L, %L::uuid))',
            '00000000-0000-4000-b000-000000000011', pg_temp.u('admin'), 'nurse', 'Synthetisch: Wechsel', pg_temp.k(703))) #>> '{}',
  'last_admin', 'ADM1 last-administrator rule unchanged');

select * from finish();
rollback;
