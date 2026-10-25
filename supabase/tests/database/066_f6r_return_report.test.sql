-- F6R: return a report instead of countersigning a version known to be wrong (migration 0065, ADR-079).
-- Brief `docs/agents/briefs/F6R.md` (F6R-1 to F6R-7, F6R-9). Users: nurse …902 (registered nurse, Testteam Nord …101) ·
-- nurse …906 (care assistant, Nord) · coach …901 (no team) · operations …904 · admin …905 (org A, no team).
-- Synthetic users added here: …6601 care assistant of Nord, …6602 registered nurse of Testteam West …104,
-- …6603 an account without any membership (stands for a client or partner account). Case …208. All data synthetic;
-- every step goes through the real commands, except the steps marked "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(82);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns text language sql immutable as $$
  select case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                when 'admin' then '00000000-0000-4000-a000-000000000905' when 'ca2' then 'a0660000-0000-4000-a000-000000006601'
                when 'rn_west' then 'a0660000-0000-4000-a000-000000006602' when 'outsider' then 'a0660000-0000-4000-a000-000000006603' end
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0661000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;

-- Synthetic accounts (as the table owner) -----------------------------------------------------------------------------
insert into auth.users (id, email) values
  (pg_temp.u('ca2')::uuid, 'f6r-ca2@navora.test'), (pg_temp.u('rn_west')::uuid, 'f6r-rn-west@navora.test'),
  (pg_temp.u('outsider')::uuid, 'f6r-outsider@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('ca2')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('rn_west')::uuid, 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('ca2')::uuid, 'care_assistant'),
  ('00000000-0000-4000-a000-000000000104', pg_temp.u('rn_west')::uuid, 'registered_nurse');

-- Fixtures: r1 returned and corrected (care assistant …906), r2 countersigned directly (…6601), r3 a registered nurse's own
-- report (no countersignature), r4 performer leaves before a return (…6601).
create temp table fx (name text primary key, id uuid not null, t time not null, resp uuid not null);
grant select on fx to authenticated, service_role;
insert into fx values
  ('r1', 'a0660000-0000-4000-8000-000000000001', '05:00', pg_temp.u('ca')::uuid),
  ('r2', 'a0660000-0000-4000-8000-000000000002', '05:30', pg_temp.u('ca2')::uuid),
  ('r3', 'a0660000-0000-4000-8000-000000000003', '06:00', pg_temp.u('rn')::uuid),
  ('r4', 'a0660000-0000-4000-8000-000000000004', '06:30', pg_temp.u('ca2')::uuid);
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date, f.t, f.t + interval '30 minutes',
       false, 'planned', 20, 0, 10, f.resp
from fx f;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.today() returns date language sql as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.report_v(n text, v int) returns public.visit_reports language sql security definer as $$
  select r.* from public.visit_reports r where r.visit_id = pg_temp.vid(n) and r.version = v $$;
create function pg_temp.shown(n text) returns jsonb language sql as $$
  select to_jsonb(f) from public.field_reports(pg_temp.today()) f where f.visit_id = pg_temp.vid(n) $$;
create function pg_temp.started_event(n text) returns bigint language sql security definer as $$
  select e.id from public.visit_events e where e.visit_id = pg_temp.vid(n) and e.event_type = 'started' $$;
create function pg_temp.returns_of(n text) returns integer language sql security definer as $$
  select count(*)::int from public.visit_report_returns where visit_id = pg_temp.vid(n) $$;
create function pg_temp.visible_returns(n text) returns integer language sql as $$
  select count(*)::int from public.visit_report_returns where visit_id = pg_temp.vid(n) $$;
-- start, record an observation, complete, draft and sign as the current user
create function pg_temp.run_and_sign(n text, k int) returns void language plpgsql as $$
declare r jsonb;
begin
  perform public.start_visit(pg_temp.vid(n), pg_temp.k(k * 10 + 1));
  perform public.record_observation(pg_temp.vid(n), 'Synthetisch: Haut intakt', false, null, pg_temp.k(k * 10 + 2));
  perform public.complete_visit(pg_temp.vid(n), pg_temp.k(k * 10 + 3));
  r := public.create_report_draft(pg_temp.vid(n), 'Synthetisch: Verlauf ruhig', pg_temp.k(k * 10 + 4));
  perform public.sign_report((r ->> 'report_id')::uuid, pg_temp.shown(n) ->> 'snapshot_hash', pg_temp.k(k * 10 + 5));
end $$;
create function pg_temp.ret(n text, v int, why text, k int) returns jsonb language sql as $$
  select public.return_report((pg_temp.report_v(n, v)).id, why, pg_temp.k(k)) $$;

-- Surface ------------------------------------------------------------------------------------------------------------
select ok(has_function_privilege('authenticated', 'public.return_report(uuid, text, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.return_report(uuid, text, uuid)', 'execute'),
  'return_report: members yes, anon no');
select ok((select relrowsecurity from pg_class where oid = 'public.visit_report_returns'::regclass), 'RLS is on for the return record');
select ok(not has_table_privilege('authenticated', 'public.visit_report_returns', 'insert')
          and not has_table_privilege('authenticated', 'public.visit_report_returns', 'update')
          and not has_table_privilege('authenticated', 'public.visit_report_returns', 'delete')
          and not has_table_privilege('service_role', 'public.visit_report_returns', 'update')
          and not has_table_privilege('service_role', 'public.visit_report_returns', 'delete')
          and not has_table_privilege('service_role', 'public.visit_report_returns', 'truncate')
          and not has_table_privilege('anon', 'public.visit_report_returns', 'select'),
  'no direct write on returns for app users or the service role; anon reads nothing');

-- Runs ---------------------------------------------------------------------------------------------------------------
select pg_temp.act_as(pg_temp.u('ca'));
set local role authenticated;
select pg_temp.run_and_sign('r1', 1);
select pg_temp.act_as(pg_temp.u('ca2'));
select pg_temp.run_and_sign('r2', 2);
select pg_temp.run_and_sign('r4', 4);
select pg_temp.act_as(pg_temp.u('rn'));
select pg_temp.run_and_sign('r3', 3);
reset role;
select is((select string_agg(f.name || '=' || r.status || ':' || r.countersign_required, ',' order by f.name)
           from fx f join public.visit_reports r on r.visit_id = f.id),
  'r1=signed:true,r2=signed:true,r3=final:false,r4=signed:true', 'fixtures: three reports await countersignature, r3 is final');

-- F6R-1: who may return ------------------------------------------------------------------------------------------------
set local role authenticated;
select pg_temp.act_as(pg_temp.u('ca'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit falsch', 101) ->> 'reason', 'own_report', 'the performer herself: refused');
select pg_temp.act_as(pg_temp.u('ca2'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit falsch', 102) ->> 'reason', 'rn_required', 'a care assistant of the team: refused');
select pg_temp.act_as(pg_temp.u('rn_west'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit falsch', 103) ->> 'reason', 'not_team_member', 'a registered nurse of another team: refused');
select pg_temp.act_as(pg_temp.u('admin'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit falsch', 104) ->> 'reason', 'not_team_member', 'an admin without team membership: refused');
select pg_temp.act_as(pg_temp.u('coach'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit falsch', 105) ->> 'reason', 'not_team_member', 'a coach: refused');
select pg_temp.act_as(pg_temp.u('ops'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit falsch', 106) ->> 'reason', 'not_team_member', 'operations: refused');
select pg_temp.act_as(pg_temp.u('outsider'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit falsch', 107) ->> 'reason', 'not_team_member', 'an account without membership (client or partner): refused');
select pg_temp.act_as(pg_temp.u('rn'));
select is(pg_temp.ret('r1', 1, 'zu kurz', 108) ->> 'reason', 'reason_too_short', 'a reason under 10 characters: refused');
select is(pg_temp.ret('r1', 1, null, 109) ->> 'reason', 'reason_too_short', 'no reason: refused');
select throws_ok($$ select pg_temp.ret('r1', 1, repeat('x', 501), 110) $$, '22023', null, 'a reason over 500 characters: refused');
select is(pg_temp.ret('r3', 1, 'Synthetisch: Startzeit falsch', 111) ->> 'reason', 'not_awaiting_countersignature',
  'a final report (no countersignature required): refused');
reset role;
select is(pg_temp.returns_of('r1'), 0, 'nothing written by a refusal');
select is((select count(*)::int from public.visit_reports where visit_id = pg_temp.vid('r1')), 1, 'still one version');

set local role authenticated;
select pg_temp.act_as(pg_temp.u('rn'));
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit stimmt nicht, bitte korrigieren', 120) ->> 'result', 'ok',
  'a registered nurse of the team returns the signed report');
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit stimmt nicht, bitte korrigieren', 120) ->> 'result', 'duplicate',
  'the same idempotency key again: duplicate');
select is(pg_temp.ret('r1', 1, 'Synthetisch: Startzeit stimmt nicht, bitte korrigieren', 121) ->> 'reason', 'not_latest',
  'a new key on the returned version: not_latest (already returned)');
select is(pg_temp.ret('r1', 2, 'Synthetisch: Startzeit stimmt nicht, bitte korrigieren', 122) ->> 'reason', 'not_awaiting_countersignature',
  'the new draft cannot be returned');
reset role;
select is(pg_temp.returns_of('r1'), 1, 'one return');
select is((select r.version || '/' || r.status || '/' || (r.supersedes_id = (pg_temp.report_v('r1', 1)).id)::text
                  || '/' || (r.correction_reason is null)::text || '/' || (r.performer_id = pg_temp.u('ca')::uuid)::text
           from public.visit_reports r where r.id = (pg_temp.report_v('r1', 2)).id),
  '2/draft/true/true/true', 'the return opens version 2: a draft for the performer, superseding version 1, not a correction');
select is((pg_temp.report_v('r1', 1)).status, 'signed', 'the returned version stays signed (never in place)');

-- F6R-2: the append-only record -------------------------------------------------------------------------------------
select ok((select x.report_id = (pg_temp.report_v('r1', 1)).id and x.report_version = 1
                  and x.snapshot_hash = private.report_snapshot_hash((pg_temp.report_v('r1', 1)).snapshot)
                  and x.reason = 'Synthetisch: Startzeit stimmt nicht, bitte korrigieren'
                  and x.returned_by = pg_temp.u('rn')::uuid and x.returned_at is not null
           from public.visit_report_returns x where x.visit_id = pg_temp.vid('r1')),
  'the return stores the version, its snapshot hash, the reason, the returner and the time');
select ok((select count(*) = 1 from public.audit_events a where a.table_name = 'visit_report_returns' and a.command = 'return_report'
                  and not (a.changed ? 'reason')),
  'the return is audited with its command, without the reason');
select throws_ok($$ update public.visit_report_returns set reason = 'Synthetisch: geändert, geändert' $$, '42501', null,
  'the table owner cannot update a return (trigger)');
select throws_ok($$ delete from public.visit_report_returns $$, '42501', null, 'the table owner cannot delete a return (trigger)');
select throws_ok($$ truncate public.visit_report_returns cascade $$, '42501', null, 'nor truncate');
set local role service_role;
select throws_ok($$ update public.visit_report_returns set reason = 'Synthetisch: geändert, geändert' $$, '42501', null,
  'the service role cannot update a return');
select throws_ok($$ delete from public.visit_report_returns $$, '42501', null, 'the service role cannot delete a return');
reset role;
set local role authenticated;
select pg_temp.act_as(pg_temp.u('rn'));
select throws_ok($$ update public.visit_report_returns set reason = 'Synthetisch: geändert, geändert' $$, '42501', null,
  'an app user cannot update a return');
select throws_ok($$ insert into public.visit_report_returns (organization_id, team_id, visit_id, report_id, report_version,
                     snapshot_hash, reason, performer_id, returned_by) select organization_id, team_id, visit_id, report_id,
                     2, snapshot_hash, reason, performer_id, returned_by from public.visit_report_returns $$, '42501', null,
  'nor insert one directly');

-- F6R-7: the reason is visible only to the performer and the team's registered nurses ---------------------------------
select is(pg_temp.visible_returns('r1'), 1, 'the returner (a team RN) reads the return');
select is(pg_temp.shown('r1') ->> 'return_reason', 'Synthetisch: Startzeit stimmt nicht, bitte korrigieren', 'and /field shows her the reason');
select pg_temp.act_as(pg_temp.u('ca'));
select is(pg_temp.visible_returns('r1'), 1, 'the performer reads the return');
select ok((select (f ->> 'returned')::boolean and f ->> 'return_reason' like 'Synthetisch: Startzeit%'
                  and f -> 'returned_snapshot' = (pg_temp.report_v('r1', 1)).snapshot
           from pg_temp.shown('r1') f),
  '/field shows the performer the reason and the returned version');
select is((select count(*)::int from public.report_returns(pg_temp.vid('r1')) x where x.report_version = 1 and x.snapshot is not null), 1,
  'report_returns lists the returned version for the performer');
select pg_temp.act_as(pg_temp.u('ca2'));
select is(pg_temp.visible_returns('r1'), 0, 'a care-assistant colleague does not read the return');
select ok((select (f ->> 'returned')::boolean and f ->> 'return_reason' is null and f ->> 'returned_snapshot' is null
                  and f ->> 'returned_by_name' is null from pg_temp.shown('r1') f),
  'she sees on /field that it was returned, not why');
select is((select count(*)::int from public.report_returns(pg_temp.vid('r1'))), 0, 'report_returns gives her nothing');
select pg_temp.act_as(pg_temp.u('rn_west'));
select is(pg_temp.visible_returns('r1'), 0, 'a registered nurse of another team does not read it');
select pg_temp.act_as(pg_temp.u('admin'));
select is(pg_temp.visible_returns('r1'), 0, 'an admin without membership does not read it');
reset role;
select is((select string_agg(distinct n.nspname || '.' || p.proname, ',' order by n.nspname || '.' || p.proname)
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private', 'auth', 'extensions') and p.prosrc ilike '%visit_report_returns%'),
  'private.report_returned_unavailable,public.field_countersign_queue,public.field_reports,public.field_returned_reports,public.report_returns,public.return_report',
  'only the return command, the four /field read models and the LEAVE1-11 flag (0075, no reason) read the return table (no AN1, AN2, billing, export or push function)');
select is((select count(*)::int from pg_views where definition ilike '%visit_report_returns%'), 0, 'no view reads it');

-- F6R-5: never stranded ----------------------------------------------------------------------------------------------
set local role authenticated;
select pg_temp.act_as(pg_temp.u('ca'));
select is((select string_agg(x.reason, ',') from public.field_returned_reports() x where x.visit_id = pg_temp.vid('r1')),
  'Synthetisch: Startzeit stimmt nicht, bitte korrigieren', 'the performer''s /field lists the returned report with the reason');
select pg_temp.act_as(pg_temp.u('rn'));
select is((select count(*)::int from public.field_returned_reports()), 0, 'the returner''s own list stays empty (not her report)');
select is((select string_agg(x.returned::text, ',') from public.field_countersign_queue() x where x.visit_id = pg_temp.vid('r1')), 'true',
  'the team''s countersignature queue shows it as returned');
reset role;
select is((select count(*)::int from private.derived_exceptions('00000000-0000-4000-b000-000000000011') x
           where x.exception_type in ('report_not_final', 'report_correction_open') and x.entity_id = pg_temp.vid('r1')), 0,
  'right after the return: no signal yet (report_not_final threshold not reached)');
update public.exception_rules set amount = 0 where exception_type = 'report_not_final';   -- as the table owner
select is((select string_agg(x.exception_type, ',') from private.derived_exceptions('00000000-0000-4000-b000-000000000011') x
           where x.exception_type in ('report_not_final', 'report_correction_open') and x.entity_id = pg_temp.vid('r1')),
  'report_not_final', 'after the threshold: report_not_final raises as before, and no "open correction" signal');

-- F6R-6: no billing fact while returned ------------------------------------------------------------------------------
set local role authenticated;
select pg_temp.act_as(pg_temp.u('rn'));
select public.generate_billable_facts(pg_temp.today());
select is((select count(*)::int from public.billable_facts where visit_id = pg_temp.vid('r1')), 0, 'a returned report produces no billing fact');

-- F6R-3: only the performer changes the content ------------------------------------------------------------------------
select is(public.correct_visit_time(pg_temp.started_event('r1'), private.now() - interval '20 minutes', 'Synthetisch: vom Rückgebenden',
                                    pg_temp.k(130)), 'rejected', 'the returner cannot correct a time');
select is(public.record_observation(pg_temp.vid('r1'), 'Synthetisch: vom Rückgebenden', false, null, pg_temp.k(131)), 'rejected',
  'nor record an observation');
select is(public.update_report_draft((pg_temp.report_v('r1', 2)).id, 'Synthetisch: fremd', pg_temp.k(132)) ->> 'reason', 'not_performer',
  'nor edit the summary');
select is(public.sign_report((pg_temp.report_v('r1', 2)).id, pg_temp.shown('r1') ->> 'snapshot_hash', pg_temp.k(133)) ->> 'reason', 'not_performer',
  'nor sign');
select is(public.countersign_report((pg_temp.report_v('r1', 1)).id, pg_temp.k(134)) ->> 'reason', 'not_latest',
  'the returned version can no longer be countersigned');
select pg_temp.act_as(pg_temp.u('ca2'));
select is(public.correct_visit_time(pg_temp.started_event('r1'), private.now() - interval '20 minutes', 'Synthetisch: von Kollegin',
                                    pg_temp.k(135)), 'rejected', 'a colleague cannot correct a time either');
reset role;
select is((select count(*)::int from public.visit_time_corrections where visit_id = pg_temp.vid('r1')), 0, 'nothing written');

-- CR-048 interim (D-30): the performer stays removable only after she signed again -----------------------------------
set local role authenticated;
select pg_temp.act_as(pg_temp.u('admin'));
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', pg_temp.u('ca')::uuid, 'Synthetisch', pg_temp.k(136)) ->> 'result',
  'has_unsigned_reports', 'while her returned report is open, she cannot be removed from the team');

select pg_temp.act_as(pg_temp.u('ca'));
select is(public.withdraw_report_correction((pg_temp.report_v('r1', 2)).id, pg_temp.k(137)) ->> 'reason', 'returned_report',
  'the performer cannot withdraw the returned draft');
select is(public.correct_visit_time(pg_temp.started_event('r1'), private.now() - interval '20 minutes', 'Synthetisch: Start war früher',
                                    pg_temp.k(138)), 'ok', 'the performer corrects the time');

-- F6R-4: an observation already visible changes only through a new row -----------------------------------------------
select is(public.record_observation(pg_temp.vid('r1'), 'Synthetisch: Haut gerötet (korrigiert)', false,
                                    (select o.id from public.visit_observations o where o.visit_id = pg_temp.vid('r1')), pg_temp.k(139)),
  'ok', 'the performer changes her observation');
select throws_ok($$ update public.visit_observations set content = 'x' where visit_id = 'a0660000-0000-4000-8000-000000000001' $$,
  '42501', null, 'no direct update of an observation');
select pg_temp.act_as(pg_temp.u('rn'));
select is((select string_agg(o.content || ':' || (o.supersedes_id is not null)::text, ',' order by (o.supersedes_id is not null), o.recorded_at)
           from public.visit_observations o where o.visit_id = pg_temp.vid('r1')),
  'Synthetisch: Haut intakt:false,Synthetisch: Haut gerötet (korrigiert):true',
  'a new row supersedes the earlier one; the earlier row is unchanged and visible to the team');

-- Sign again, countersign: final --------------------------------------------------------------------------------------
select pg_temp.act_as(pg_temp.u('ca'));
select is(public.sign_report((pg_temp.report_v('r1', 2)).id, pg_temp.shown('r1') ->> 'snapshot_hash', pg_temp.k(140)) ->> 'result', 'ok',
  'the performer signs the corrected version');
select is((select count(*)::int from public.field_returned_reports()), 0, 'her returned list is empty again');
select pg_temp.act_as(pg_temp.u('rn'));
select is((select string_agg(x.returned::text, ',') from public.field_countersign_queue() x where x.visit_id = pg_temp.vid('r1')), 'false',
  'the queue shows the signed version awaiting countersignature');
select is(public.countersign_report((pg_temp.report_v('r1', 2)).id, pg_temp.k(141)) ->> 'result', 'ok', 'the registered nurse countersigns');
select is((select r.version || '/' || r.status from public.visit_reports r where r.id = (pg_temp.shown('r1') ->> 'report_id')::uuid), '2/final',
  'the corrected version is final');
select is((select count(*)::int from public.field_countersign_queue() x where x.visit_id = pg_temp.vid('r1')), 0, 'gone from the queue');
reset role;
select is((select count(*)::int from private.derived_exceptions('00000000-0000-4000-b000-000000000011') x
           where x.exception_type = 'report_not_final' and x.entity_id = pg_temp.vid('r1')), 0, 'report_not_final ends');
select is((pg_temp.report_v('r1', 1)).status, 'signed', 'version 1 stays as returned: signed, never final');

-- F6R-6: one billing fact from the countersigned version, with the corrected minutes -----------------------------------
set local role authenticated;
select pg_temp.act_as(pg_temp.u('rn'));
select public.generate_billable_facts(pg_temp.today());
reset role;
select is((select count(*)::int from public.billable_facts where visit_id = pg_temp.vid('r1')), 1, 'one billing fact');
select ok((select f.report_id = (pg_temp.report_v('r1', 2)).id
                  and f.snapshot_hash = private.report_snapshot_hash((pg_temp.report_v('r1', 2)).snapshot)
                  and f.measured_care_minutes = (select t.care_minutes_exact from private.snapshot_times((pg_temp.report_v('r1', 2)).snapshot) t)
                  and f.measured_care_minutes > coalesce((select t.care_minutes_exact from private.snapshot_times((pg_temp.report_v('r1', 1)).snapshot) t), 0)
           from public.billable_facts f where f.visit_id = pg_temp.vid('r1')),
  'built from the countersigned version, with the corrected (longer) minutes');

-- CR-048 interim, changed by LEAVE1-11 (0075, CGR-49): a return while the performer is not in the team is recorded, but
-- opens no draft only she could sign (full behaviour in pgTAP 075) ------------------------------------------------------
set local role authenticated;
select pg_temp.act_as(pg_temp.u('admin'));
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', pg_temp.u('ca2')::uuid, 'Synthetisch', pg_temp.k(150)) ->> 'result',
  'ok', 'a performer whose reports are signed is removed');
select pg_temp.act_as(pg_temp.u('rn'));
select is((pg_temp.shown('r4') ->> 'i_can_return')::boolean, true, 'LEAVE1-11: /field offers the return of her report');
select is((select x ->> 'result' || ':' || (x ->> 'performer_unavailable') || ':' || coalesce(x ->> 'report_id', 'no draft')
           from pg_temp.ret('r4', 1, 'Synthetisch: Startzeit stimmt nicht', 151) x),
  'ok:true:no draft', 'LEAVE1-11: a report whose performer left is returned without a draft (it cannot strand a draft)');
select is(public.countersign_report((pg_temp.report_v('r2', 1)).id, pg_temp.k(152)) ->> 'result', 'ok', 'r2 is countersigned without a return');
reset role;

-- F6R-9: evidence (AN2, AN1 suppression); a return is no correction round ----------------------------------------------
set local role authenticated;
select pg_temp.act_as(pg_temp.u('rn'));
select is((select h.value || '/' || h.base from public.pilot_hypotheses(pg_temp.today()) h
           where h.team_id = '00000000-0000-4000-a000-000000000101' and h.measure = 'report_returned_share'),
  '33.3/3', 'share of countersign-required reports returned at least once (r1 of r1, r2, r4)');
select is((select h.base || ':' || (h.value is not null)::text from public.pilot_hypotheses(pg_temp.today()) h
           where h.team_id = '00000000-0000-4000-a000-000000000101' and h.measure = 'countersign_latency_hours'),
  '2:true', 'countersignature latency over the countersigned reports, returns included (r1, r2)');
select is((select h.value from public.pilot_hypotheses(pg_temp.today()) h
           where h.team_id = '00000000-0000-4000-a000-000000000101' and h.measure = 'correction_versions_per_100'),
  0.0::numeric, 'the return version is not counted as a correction round (AN2 measure 5)');
select pg_temp.act_as(pg_temp.u('admin'));
select is((select string_agg(h.measure || '=' || coalesce(h.value::text, '-') || '/' || coalesce(h.base::text, '-') || ':' || h.suppressed::text,
                             ',' order by h.measure)
           from public.pilot_hypotheses(pg_temp.today()) h
           where h.team_id is null and h.measure in ('report_returned_share', 'countersign_latency_hours')),
  'countersign_latency_hours=0.0/2:false,report_returned_share=33.3/3:false',
  'both measures also on the organisation row for an administrator, under the AN1 suppression rule');
reset role;

select * from finish();
rollback;
