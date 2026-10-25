-- LEAVE1 part (b): the leaver's open work stays visible; a wrong report of an unavailable performer never becomes final
-- (migration 0075, ADR-088). Brief `docs/agents/briefs/LEAVE1.md` LEAVE1-5, LEAVE1-11 (CGR-49), LEAVE1-12 (CGR-50).
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · admin …905 (org A) ·
-- admin …903 (org B). Synthetic users added here: …7501 care assistant of Nord, the leaver; …7502 care assistant of
-- Nord, removed from the team; …7503 registered nurse of Testteam Mitte …102 (another team). Case …208 (Nord). All data
-- synthetic; every step goes through the real commands, except the steps marked "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(47);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns text language sql immutable as $$
  select case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                when 'admin' then '00000000-0000-4000-a000-000000000905' when 'admin_b' then '00000000-0000-4000-a000-000000000903'
                when 'l1' then 'a0750000-0000-4000-a000-000000007501' when 'l2' then 'a0750000-0000-4000-a000-000000007502'
                when 'rnm' then 'a0750000-0000-4000-a000-000000007503' end
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0751000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
-- Run SQL as a user through `authenticated`, then return to the table owner.
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.seen(p_user text, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;

-- Synthetic accounts (as the table owner) -----------------------------------------------------------------------------
insert into auth.users (id, email) values
  (pg_temp.u('l1')::uuid, 'leave1b-l1@navora.test'), (pg_temp.u('l2')::uuid, 'leave1b-l2@navora.test'),
  (pg_temp.u('rnm')::uuid, 'leave1b-rnm@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('l1')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('l2')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('rnm')::uuid, 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('l1')::uuid, 'care_assistant'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('l2')::uuid, 'care_assistant'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('rnm')::uuid, 'registered_nurse');

-- Visits of today (Nord, case 208). l1: u1, u2 unsigned; s1 signed (returned after her access ended); s2 returned
-- before (F6R draft); f1 final. l2: t1 signed (returned after her removal). h1: a planned visit of …906 (HAND1 card).
-- r3 (inserted after her restore): a visit of l1.
create temp table fx (name text primary key, id uuid not null, t time not null, resp uuid not null);
grant select on fx to authenticated, service_role;
insert into fx values
  ('u1', 'a0750000-0000-4000-8000-000000000001', '03:00', pg_temp.u('l1')::uuid),
  ('u2', 'a0750000-0000-4000-8000-000000000002', '03:30', pg_temp.u('l1')::uuid),
  ('s1', 'a0750000-0000-4000-8000-000000000003', '04:00', pg_temp.u('l1')::uuid),
  ('s2', 'a0750000-0000-4000-8000-000000000004', '04:30', pg_temp.u('l1')::uuid),
  ('f1', 'a0750000-0000-4000-8000-000000000005', '05:00', pg_temp.u('l1')::uuid),
  ('t1', 'a0750000-0000-4000-8000-000000000006', '05:30', pg_temp.u('l2')::uuid),
  ('h1', 'a0750000-0000-4000-8000-000000000008', '23:00', pg_temp.u('ca')::uuid);
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (private.at_zurich(private.now()))::date, f.t, f.t + interval '20 minutes',
       false, 'planned', 20, 0, 0, f.resp
from fx f;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.report_v(n text, v int) returns public.visit_reports language sql security definer as $$
  select r.* from public.visit_reports r where r.visit_id = pg_temp.vid(n) and r.version = v $$;
create function pg_temp.versions(n text) returns text language sql security definer as $$
  select string_agg(r.version || ':' || r.status, ',' order by r.version) from public.visit_reports r where r.visit_id = pg_temp.vid(n) $$;
create function pg_temp.shown(n text) returns jsonb language sql as $$
  select to_jsonb(f) from public.field_reports(pg_temp.today()) f where f.visit_id = pg_temp.vid(n) $$;
create function pg_temp.run(n text, k int) returns jsonb language plpgsql as $$
begin
  perform public.start_visit(pg_temp.vid(n), pg_temp.k(k * 10 + 1));
  perform public.complete_visit(pg_temp.vid(n), pg_temp.k(k * 10 + 3));
  return public.create_report_draft(pg_temp.vid(n), 'Synthetisch: Verlauf ruhig', pg_temp.k(k * 10 + 4));
end $$;
create function pg_temp.sign(n text, v int, k int) returns jsonb language sql as $$
  select public.sign_report((pg_temp.report_v(n, v)).id, pg_temp.shown(n) ->> 'snapshot_hash', pg_temp.k(k)) $$;
create function pg_temp.ret(n text, v int, k int) returns jsonb language sql as $$
  select public.return_report((pg_temp.report_v(n, v)).id, 'Synthetisch: Startzeit falsch erfasst', pg_temp.k(k)) $$;
create function pg_temp.list(p_user text, p_who text) returns text language sql as $$
  select coalesce(pg_temp.seen(p_user, format(
    'select string_agg(x.e, '','' order by x.e)
     from (select o.kind as e from public.member_open_reports(%L::uuid) o) x',
    pg_temp.u(p_who))), '') $$;
create function pg_temp.queue(p_user text) returns text language sql as $$
  select coalesce(pg_temp.seen(p_user,
    'select string_agg(x.e, '','' order by x.e)
     from (select (select f.name from fx f where f.id = q.visit_id) || ''='' || q.kind
                  || case when q.performer_access_ended is not null then ''+ended'' else '''' end as e
           from public.field_countersign_queue() q where q.visit_id in (select id from fx)) x'), '') $$;

-- Fixture work, through the commands ---------------------------------------------------------------------------------
select pg_temp.act_as(pg_temp.u('l1'));
set local role authenticated;
select pg_temp.run('u1', 1);
select pg_temp.run('u2', 2);
select pg_temp.run('s1', 3);
select pg_temp.sign('s1', 1, 35);
select pg_temp.run('s2', 4);
select pg_temp.sign('s2', 1, 45);
select pg_temp.run('f1', 5);
select pg_temp.sign('f1', 1, 55);
select pg_temp.act_as(pg_temp.u('l2'));
select pg_temp.run('t1', 6);
select pg_temp.sign('t1', 1, 65);
select pg_temp.act_as(pg_temp.u('rn'));
select pg_temp.ret('s2', 1, 46);
select public.countersign_report((pg_temp.report_v('f1', 1)).id, pg_temp.k(56));
reset role;

select is((select string_agg(f.name || '=' || pg_temp.versions(f.name), ' ' order by f.name) from fx f
           where f.name in ('u1', 'u2', 's1', 's2', 'f1', 't1')),
  'f1=1:final s1=1:signed s2=1:signed,2:draft t1=1:signed u1=1:draft u2=1:draft',
  'fixtures: u1, u2 unsigned; s1 and t1 await countersignature; s2 returned (F6R draft); f1 final');

-- LEAVE1-12 (1): the open work is listed before the access ends --------------------------------------------------------
select is(pg_temp.list('admin', 'l1'), 'returned,unsigned,unsigned', 'the administrator sees her 3 open reports by kind');
select is(pg_temp.list('rn', 'l1'), 'returned,unsigned,unsigned', 'a registered nurse of her team sees the same 3');
select is(pg_temp.list('ca', 'l1'), '', 'a care-assistant colleague does not see the list');
select is(pg_temp.list('rnm', 'l1'), '', 'a registered nurse of another team sees nothing');
select is(pg_temp.list('admin_b', 'l1'), '', 'another organisation sees nothing');
select is(pg_temp.seen('admin', format('select string_agg(distinct coalesce(o.team_name, ''-'') || '':'' || o.visit_date::text, '','')
                                         from public.member_open_reports(%L::uuid) o', pg_temp.u('l1'))),
  'Testteam Nord:' || pg_temp.today()::text, 'each entry carries only kind, visit date and team');
select is(pg_temp.seen('rn', format('select string_agg(coalesce(o.member_name, ''?'') || '':'' || o.unsigned || ''/'' || o.correction_draft || ''/''
                                      || o.returned || '':'' || coalesce(o.access_ended_on::text, ''open''), '','')
                                      from public.team_open_reports() o where o.user_id = %L::uuid', pg_temp.u('l1'))),
  (select coalesce(private.member_name('00000000-0000-4000-b000-000000000011', pg_temp.u('l1')::uuid), '?') || ':2/0/1:open'),
  'the registered nurse''s team list: counts by kind, access still open');
select is(pg_temp.seen('rnm', 'select count(*)::text from public.team_open_reports()'), '0', 'another team''s nurse: empty team list');
-- She signs one: 2 remain.
select is(pg_temp.cmd('l1', format('select public.sign_report(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('u1', 1)).id,
                                   pg_temp.cmd('l1', format('select to_jsonb(f) from public.field_reports(%L::date) f where f.visit_id = %L::uuid',
                                                            pg_temp.today(), pg_temp.vid('u1'))) ->> 'snapshot_hash', pg_temp.k(15))) ->> 'result',
  'ok', 'she signs u1');
select is(pg_temp.list('admin', 'l1'), 'returned,unsigned', 'after her signature: 2 open reports');

-- LEAVE1-12 (2): the access end returns the counts by kind and is not refused by them ---------------------------------
select is(pg_temp.cmd('admin', format('select public.end_member_access(%L::uuid, ''employment_ended'', %L::uuid)', pg_temp.u('l1'), pg_temp.k(900)))
            -> 'open_reports',
  '{"unsigned": 1, "correction_draft": 0, "returned": 1}'::jsonb, 'end_member_access: ok, with her open reports by kind');

-- LEAVE1-5: the team RNs' queue shows her open work with "Zugang beendet" --------------------------------------------------
select is(pg_temp.queue('rn'),
  's1=awaiting_countersignature+ended,s2=returned+ended,t1=awaiting_countersignature,u1=awaiting_countersignature+ended,u2=unsigned+ended',
  'RN queue: her open and awaiting reports carry the marker; the open draft u2 is listed as unsigned');
select is(pg_temp.seen('rn', format('select string_agg(distinct q.performer_access_ended::text, '','') from public.field_countersign_queue() q
                                      where q.visit_id = %L::uuid', pg_temp.vid('u2'))),
  pg_temp.today()::text, 'the marker is the date of the access end (no reason code)');
select is(pg_temp.queue('rnm'), '', 'another team''s nurse: no row of Nord');
select is(pg_temp.queue('ca'), '', 'a care assistant has no countersignature queue');

-- LEAVE1-11 (a): returned after her access ended: recorded, no draft, never final ---------------------------------------
select is((pg_temp.cmd('rn', format('select to_jsonb(f) from public.field_reports(%L::date) f where f.visit_id = %L::uuid',
                                    pg_temp.today(), pg_temp.vid('s1'))) ->> 'i_can_return')::boolean, true,
  '(d) /field offers the return of s1 (performer unavailable)');
select is((select x ->> 'result' || ':' || (x ->> 'performer_unavailable') || ':' || coalesce(x ->> 'report_id', 'no draft')
           from pg_temp.cmd('rn', format('select public.return_report(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('s1', 1)).id,
                                         'Synthetisch: Dauer stimmt nicht', pg_temp.k(36))) x),
  'ok:true:no draft', '(a) the return is accepted, performer unavailable, no draft opened');
select is(pg_temp.versions('s1'), '1:signed', '(a) no draft version was created; the returned version stays signed');
select is((select performer_unavailable::text || ':' || reason from public.visit_report_returns where report_id = (pg_temp.report_v('s1', 1)).id),
  'true:Synthetisch: Dauer stimmt nicht', '(a) the return row is recorded as in F6R (append-only), flagged');
select is(pg_temp.cmd('rn', format('select public.countersign_report(%L::uuid, %L::uuid)', (pg_temp.report_v('s1', 1)).id, pg_temp.k(37))) ->> 'reason',
  'returned_performer_unavailable', '(a) countersignature of that version is refused');
select is(pg_temp.cmd('rn', format('select public.return_report(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('s1', 1)).id,
                                   'Synthetisch: noch einmal zurück', pg_temp.k(38))) ->> 'reason',
  'not_awaiting_countersignature', '(d) a second return of the same version is refused');
select is((select (x ->> 'i_can_return') || ':' || (x ->> 'i_can_countersign') || ':' || (x ->> 'returned') || ':'
                  || (x ->> 'performer_unavailable') || ':' || (x ->> 'performer_access_ended') || ':' || coalesce(x ->> 'return_reason', '-')
           from pg_temp.cmd('rn', format('select to_jsonb(f) from public.field_reports(%L::date) f where f.visit_id = %L::uuid',
                                         pg_temp.today(), pg_temp.vid('s1'))) x),
  'false:false:true:true:true:Synthetisch: Dauer stimmt nicht', '(d) /field agrees: no return, no countersignature; the RN reads the reason');
select is((select coalesce(x ->> 'return_reason', 'hidden') || ':' || (x ->> 'performer_unavailable')
           from pg_temp.cmd('ca', format('select to_jsonb(f) from public.field_reports(%L::date) f where f.visit_id = %L::uuid',
                                         pg_temp.today(), pg_temp.vid('s1'))) x),
  'hidden:true', 'a care-assistant colleague sees the state, not the return reason');
select throws_ok(format($$ update public.visit_reports set status = 'final', countersigned_by = %L::uuid, countersigned_at = now()
                           where id = %L::uuid $$, pg_temp.u('rn'), (pg_temp.report_v('s1', 1)).id),
  '42501', 'a returned report version never becomes final', '(c) as the table owner: the guard refuses signed → final');
select is(pg_temp.queue('rn'),
  's1=returned_performer_unavailable+ended,s2=returned+ended,t1=awaiting_countersignature,u1=awaiting_countersignature+ended,u2=unsigned+ended',
  'RN queue: s1 now "returned, performer unavailable"');
select is(pg_temp.list('admin', 'l1'), 'returned,returned,unsigned', 'her open list now counts s1 as returned');
-- Billing reads only final versions (J5): nothing for s1.
select is(pg_temp.cmd('rn', format('select to_jsonb(public.generate_billable_facts(%L::date))', pg_temp.today())) is not null, true,
  'billing facts generated for today');
select is((select count(*)::int from public.billable_facts where visit_id = pg_temp.vid('s1')), 0, '(a) s1 is not billable');

-- CR-048 interim kept: a final report of hers is not corrected while her access is ended -------------------------------
select is(pg_temp.cmd('rn', format('select public.correct_report(%L::uuid, ''Synthetisch: Dauer'', null, %L::uuid)',
                                   (pg_temp.report_v('f1', 1)).id, pg_temp.k(57))) ->> 'reason',
  'performer_unavailable', 'a correction only she could sign is refused; the final version stays in force');

-- LEAVE1-5 / LEAVE1-12 (3): HAND1 shows "Zugang beendet" to every team member who reads the client's visit ---------------
select is(pg_temp.seen('ca', format(
  'select string_agg((select f.name from fx f where f.id = s.visit_id) || ''<-'' || (s.detail ->> ''report_kind''), '','' order by s.source_visit_start)
   from public.field_since_last(%L::date) s where s.kind = ''performer_access_ended'' and s.visit_id = %L::uuid', pg_temp.today(), pg_temp.vid('h1'))),
  'h1<-unsigned,h1<-returned,h1<-returned', 'the care assistant''s card h1: the three open reports (u2, s1, s2)');
select is(pg_temp.seen('ca', format(
  'select string_agg(distinct (select string_agg(k, ''+'' order by k) from jsonb_object_keys(s.detail) k), '','')
   from public.field_since_last(%L::date) s where s.kind = ''performer_access_ended''', pg_temp.today())),
  'access_ended_on+report_kind', 'the entry carries kind and date only (no return reason, no access reason code)');
select is(pg_temp.seen('rnm', format('select count(*)::text from public.field_since_last(%L::date) s where s.kind = ''performer_access_ended''',
                                     pg_temp.today())), '0', 'a nurse of another team sees no marker');
select is(pg_temp.seen('ca', 'select count(*)::text from public.member_access_events'), '0',
  'the team still reads no access record (only the marker)');

-- LEAVE1-11 (b): the same after a team removal ------------------------------------------------------------------------
select is(pg_temp.cmd('admin', format('select public.remove_team_member(%L::uuid, %L::uuid, ''Synthetisch'', %L::uuid)',
                                      '00000000-0000-4000-a000-000000000101', pg_temp.u('l2'), pg_temp.k(910))) ->> 'result',
  'ok', 'l2 is removed from the team (her report is signed)');
select is((pg_temp.cmd('rn', format('select to_jsonb(f) from public.field_reports(%L::date) f where f.visit_id = %L::uuid',
                                    pg_temp.today(), pg_temp.vid('t1'))) ->> 'i_can_return')::boolean, true,
  '(d) /field offers the return of t1');
select is((select x ->> 'result' || ':' || (x ->> 'performer_unavailable') || ':' || coalesce(x ->> 'report_id', 'no draft')
           from pg_temp.cmd('rn', format('select public.return_report(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('t1', 1)).id,
                                         'Synthetisch: Startzeit stimmt nicht', pg_temp.k(66))) x),
  'ok:true:no draft', '(b) after a team removal: accepted, no draft');
select is(pg_temp.cmd('rn', format('select public.countersign_report(%L::uuid, %L::uuid)', (pg_temp.report_v('t1', 1)).id, pg_temp.k(67))) ->> 'reason',
  'returned_performer_unavailable', '(b) and never countersigned');

-- (c) no path makes a returned version final -----------------------------------------------------------------------------
select is((select count(*)::int from public.visit_reports r join public.visit_report_returns rt on rt.report_id = r.id
           where r.status = 'final'), 0, '(c) no returned version is final (F6R and LEAVE1-11 returns alike)');

-- (e) restored and still in the team: the next return opens the normal F6R draft ---------------------------------------
select is(pg_temp.cmd('admin', format('select public.restore_member_access(%L::uuid, ''employment_resumed'', %L::uuid)', pg_temp.u('l1'), pg_temp.k(920)))
            ->> 'result', 'ok', 'her access is restored');
-- (as the table owner) r3 is planned only now: a planned visit of hers would refuse the access end (LEAVE1-2).
insert into fx values ('r3', 'a0750000-0000-4000-8000-000000000007', '06:00', pg_temp.u('l1')::uuid);
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.vid('r3'), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today(), '06:00', '06:20', false, 'planned', 20, 0, 0, pg_temp.u('l1')::uuid);
select is(pg_temp.cmd('l1', format('select pg_temp.run(%L, 7)', 'r3')) ->> 'result', 'ok', 'after the restore she documents r3');
select is(pg_temp.cmd('l1', format('select public.sign_report(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('r3', 1)).id,
                                   pg_temp.cmd('l1', format('select to_jsonb(f) from public.field_reports(%L::date) f where f.visit_id = %L::uuid',
                                                            pg_temp.today(), pg_temp.vid('r3'))) ->> 'snapshot_hash', pg_temp.k(75))) ->> 'result',
  'ok', 'and signs it');
select is((select x ->> 'result' || ':' || (x ->> 'performer_unavailable') || ':' || (x ->> 'report_id' is not null)::text
           from pg_temp.cmd('rn', format('select public.return_report(%L::uuid, %L, %L::uuid)', (pg_temp.report_v('r3', 1)).id,
                                         'Synthetisch: Beobachtung fehlt', pg_temp.k(76))) x),
  'ok:false:true', '(e) the return opens the normal F6R draft');
select is(pg_temp.versions('r3') || ' / ' || pg_temp.versions('s1'), '1:signed,2:draft / 1:signed',
  '(e) r3 has its draft; s1 (returned while she was unavailable) stays as it was, waiting on D-30');
select is(pg_temp.seen('ca', format('select count(*)::text from public.field_since_last(%L::date) s where s.kind = ''performer_access_ended''',
                                    pg_temp.today())), '0', 'after the restore no "Zugang beendet" marker remains');

-- Surface and catalogue ---------------------------------------------------------------------------------------------------
select ok(has_function_privilege('authenticated', 'public.member_open_reports(uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.team_open_reports()', 'execute')
          and not has_function_privilege('anon', 'public.member_open_reports(uuid)', 'execute')
          and not has_function_privilege('anon', 'public.team_open_reports()', 'execute')
          and not has_function_privilege('authenticated', 'private.open_reports_of(uuid)', 'execute')
          and not has_function_privilege('authenticated', 'private.access_ended_at(uuid)', 'execute'),
  'the two read models are callable by members, not by anon; the helpers are private');
select is((select string_agg(p.oid::regprocedure::text, ',' order by p.oid::regprocedure::text)
           from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname in ('public', 'private') and p.prosrc ~ '(open_reports_of|open_report_counts|access_ended_at)'
             and p.proname not in ('open_reports_of', 'open_report_counts', 'access_ended_at')),
  'end_member_access(uuid,text,uuid),field_countersign_queue(),member_open_reports(uuid),private.handover_entries(uuid,uuid),team_open_reports()',
  'catalogue: only the access command, the queue, HAND1 and the two lists read the open-work helpers (no AN1, AN2, billing, export or push)');

select * from finish();
rollback;
