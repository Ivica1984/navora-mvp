-- CSR1, fifth PR (migration 0042; Clinical Governance Report section 2026-10-23 06:30): CGR-20, an honest
-- "not completed" end for a started or paused visit. Interim safe default until D-31 (`clinical`, with `legal`).
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · coach …901
--        (coordinator of org A, in no team) · fremd …903 (admin of org B) · c4200000-…-907 (nurse of org A in
--        Testteam Mitte only, created here).
-- Every step goes through the real commands. Within one transaction now() is constant, so visit times are placed
-- relative to now(); the stuck fixture gets a synthetic earlier status event (inserted as the table owner).
begin;
create extension if not exists pgtap with schema extensions;

select plan(47);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
values ('00000000-0000-0000-0000-000000000000', 'c4200000-0000-4000-8000-000000000907', 'authenticated', 'authenticated',
        'mitte.csr1@navora.test', '', now(), '{}', '{}', now(), now(), '', '', '', '');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', 'c4200000-0000-4000-8000-000000000907', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', 'c4200000-0000-4000-8000-000000000907', 'registered_nurse');

create temp table fx (name text primary key, id uuid not null, status text not null, min_a int not null, min_b int not null,
                      na boolean not null);
grant select on fx to authenticated;
insert into fx values
  ('b_visit',  '00000000-0000-4000-a042-000000000001', 'planned', 0, 30, false),   -- started by the RN, ended by the care assistant
  ('stuck',    '00000000-0000-4000-a042-000000000002', 'paused',  30, 0, false),   -- paused 2 h ago: visit_stuck, ended by the coach
  ('own_a',    '00000000-0000-4000-a042-000000000003', 'planned', 30, 0, false),   -- the care assistant's own A visit, reason "other"
  ('guarded',  '00000000-0000-4000-a042-000000000004', 'planned', 30, 0, false),   -- refusals
  ('not_yet',  '00000000-0000-4000-a042-000000000005', 'planned', 30, 0, false),   -- planned: wrong state
  ('na_visit', '00000000-0000-4000-a042-000000000006', 'planned', 30, 0, true),    -- needs assessment ended as not completed
  ('later',    '00000000-0000-4000-a042-000000000007', 'planned', 30, 0, false);   -- a later visit of the case (HAND1)

-- One day for every fixture (the Swiss date 20 minutes ago); 'later' at the end of that day.
create temp table d as select ((now() - interval '20 minutes') at time zone 'Europe/Zurich')::date as day,
                              ((now() - interval '20 minutes') at time zone 'Europe/Zurich')::time as at;
grant select on d to authenticated;
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, is_needs_assessment, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       d.day, case when f.name = 'later' then time '23:58' else date_trunc('minute', d.at)::time end,
       case when f.name = 'later' then time '23:59' else null end,
       array['Grundpflege'], false, f.status, f.min_a, f.min_b, f.na, '00000000-0000-4000-a000-000000000902'
from fx f cross join d;

-- The stuck fixture: started 3 h ago, paused 2 h ago (synthetic events as the owner).
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, occurred_at, actor_id)
values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a042-000000000002', '00000000-0000-4000-a000-000000000101',
   'started', 'planned', 'started', now() - interval '3 hours', '00000000-0000-4000-a000-000000000902'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a042-000000000002', '00000000-0000-4000-a000-000000000101',
   'paused', 'started', 'paused', now() - interval '2 hours', '00000000-0000-4000-a000-000000000902');

-- Needs assessment: the case has none on record, so a wrongly counted completion would show.
update public.cases set needs_assessment_done_at = null where id = '00000000-0000-4000-a000-000000000208';

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.status(n text) returns text language sql as $$
  select v.status from public.care_visits v where v.id = pg_temp.vid(n) $$;
create function pg_temp.ops(t text, n text) returns bigint language sql as $$
  select count(*) from public.operations_exceptions() x where x.exception_type = t and x.entity_id = pg_temp.vid(n) $$;
create function pg_temp.team(t text, n text) returns bigint language sql as $$
  select count(*) from public.team_visit_alerts() x where x.exception_type = t and x.visit_id = pg_temp.vid(n) $$;

-- Surface ----------------------------------------------------------------------------------------------------------
select ok(has_function_privilege('authenticated', 'public.end_visit_not_completed(uuid, text, text, uuid)', 'execute'),
  'members can call the not-completed end');
select ok(not has_function_privilege('anon', 'public.end_visit_not_completed(uuid, text, text, uuid)', 'execute'),
  'anon cannot');

-- Start the fixtures through the real commands -----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.vid('b_visit'), 'a4200000-0000-4000-8000-000000000001'), 'ok', 'the registered nurse starts the B visit');
select is(public.start_visit(pg_temp.vid('guarded'), 'a4200000-0000-4000-8000-000000000002'), 'ok', 'she starts a visit for the refusals');
select is(public.start_visit(pg_temp.vid('na_visit'), 'a4200000-0000-4000-8000-000000000003'), 'ok', 'she starts the needs assessment');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.start_visit(pg_temp.vid('own_a'), 'a4200000-0000-4000-8000-000000000004'), 'ok', 'the care assistant starts her A visit');
reset role;

-- Who may record it ------------------------------------------------------------------------------------------------
select pg_temp.act_as('c4200000-0000-4000-8000-000000000907');
set local role authenticated;
select is(public.end_visit_not_completed(pg_temp.vid('guarded'), 'nurse_unavailable', null, 'a4200000-0000-4000-8000-000000000010'),
  'rejected', 'a member of the organisation outside the visit''s team cannot');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.end_visit_not_completed(pg_temp.vid('guarded'), 'nurse_unavailable', null, 'a4200000-0000-4000-8000-000000000011'),
  'rejected', 'an admin of another organisation cannot');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select throws_ok($$ select public.end_visit_not_completed(pg_temp.vid('guarded'), null, null, 'a4200000-0000-4000-8000-000000000012') $$,
  '22023', null, 'without a reason: refused');
select throws_ok($$ select public.end_visit_not_completed(pg_temp.vid('guarded'), 'client_cancelled', null, 'a4200000-0000-4000-8000-000000000013') $$,
  '22023', null, 'a reason outside the list: refused');
select throws_ok($$ select public.end_visit_not_completed(pg_temp.vid('guarded'), 'other', '  ', 'a4200000-0000-4000-8000-000000000014') $$,
  '22023', null, '"other" without a note: refused');
select is(public.end_visit_not_completed(pg_temp.vid('not_yet'), 'started_by_mistake', null, 'a4200000-0000-4000-8000-000000000015'),
  'wrong_state', 'a planned visit is not ended this way (cancel it)');
-- No shortcut around the reason: a direct status update is not an allowed transition.
select throws_ok($$ update public.care_visits set status = 'interrupted' where id = pg_temp.vid('guarded') $$,
  '23514', null, 'a direct update to interrupted is refused (the reason cannot be skipped)');
reset role;
select is(pg_temp.status('guarded'), 'started', 'after the refusals the visit is still started');
select is((select count(*)::int from public.visit_status_notes where visit_id = pg_temp.vid('guarded')), 0, 'and no reason was written');

-- A care assistant records the end of a B visit a registered nurse started (whatever her qualification) -------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.end_visit_not_completed(pg_temp.vid('b_visit'), 'client_transferred', 'Ins Spital gebracht', 'a4200000-0000-4000-8000-000000000020'),
  'ok', 'CGR-20: a care assistant ends a started B visit as not completed');
select is(public.end_visit_not_completed(pg_temp.vid('b_visit'), 'client_transferred', 'Ins Spital gebracht', 'a4200000-0000-4000-8000-000000000020'),
  'duplicate', 'the same request again is a duplicate');
select is(public.end_visit_not_completed(pg_temp.vid('b_visit'), 'other', 'nochmals', 'a4200000-0000-4000-8000-000000000021'),
  'wrong_state', 'a second end is refused');
select is(public.end_visit_not_completed(pg_temp.vid('own_a'), 'other', 'Klient:in wollte heute nicht', 'a4200000-0000-4000-8000-000000000022'),
  'ok', 'the performer ends her own visit with "other" and a note');
reset role;
select is(pg_temp.status('b_visit'), 'interrupted', 'the B visit is not completed');
select is((select reason_code || ' / ' || note from public.visit_status_notes where visit_id = pg_temp.vid('b_visit') and kind = 'interrupted'),
  'client_transferred / Ins Spital gebracht', 'reason and note are recorded');
select is((select actor_id from public.visit_status_notes where visit_id = pg_temp.vid('b_visit')),
  '00000000-0000-4000-a000-000000000906'::uuid, 'with the actor');
select is((select event_type || ':' || from_status || ':' || actor_id from public.visit_events
           where visit_id = pg_temp.vid('b_visit') order by occurred_at desc, id desc limit 1),
  'interrupted:started:00000000-0000-4000-a000-000000000906', 'the timeline gets an interrupted event with the actor');
select is((select count(*)::int from public.audit_events
           where table_name = 'care_visits' and entity_id = pg_temp.vid('b_visit') and command = 'end_visit_not_completed'
             and changed -> 'status' ->> 'new' = 'interrupted'), 1, 'audit row for the status change');
select is((select count(*)::int from public.audit_events
           where table_name = 'visit_status_notes' and command = 'end_visit_not_completed'
             and idempotency_key = 'a4200000-0000-4000-8000-000000000020'), 1, 'audit row for the reason');

-- A coordination role ends a paused, stuck visit; visit_stuck ends with its cause -----------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(pg_temp.ops('visit_stuck', 'stuck'), 1::bigint, 'before: the paused visit is stuck (OPS1)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team('visit_stuck', 'stuck'), 1::bigint, 'before: the team sees it stuck');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.end_visit_not_completed(pg_temp.vid('stuck'), 'nurse_unavailable', null, 'a4200000-0000-4000-8000-000000000030'),
  'ok', 'CGR-20: a coordinator (not in the team) ends the paused visit');
select is(pg_temp.ops('visit_stuck', 'stuck'), 0::bigint, 'visit_stuck is gone in OPS1, through its cause');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team('visit_stuck', 'stuck'), 0::bigint, 'and for the team');
reset role;
select is((select count(*)::int from public.exception_events where exception_key like 'visit_stuck:' || pg_temp.vid('stuck') || '%'),
  0, 'no hand close was needed');

-- A not-completed visit has no way out ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.complete_visit(pg_temp.vid('b_visit'), 'a4200000-0000-4000-8000-000000000040'), 'rejected', 'it cannot be completed');
select is(public.resume_visit(pg_temp.vid('stuck'), 'a4200000-0000-4000-8000-000000000041'), 'rejected', 'nor resumed');
select is(public.start_visit(pg_temp.vid('b_visit'), 'a4200000-0000-4000-8000-000000000042'), 'rejected', 'nor restarted');
select is(public.cancel_visit(pg_temp.vid('b_visit'), 'team_cancelled', null, 'a4200000-0000-4000-8000-000000000043'), 'wrong_state',
  'nor cancelled afterwards');
select throws_ok($$ update public.care_visits set status = 'completed' where id = pg_temp.vid('b_visit') $$,
  '23514', null, 'nor completed by a direct update');

-- No report obligation, no billing fact, not a completed visit ------------------------------------------------------
select is(public.create_report_draft(pg_temp.vid('b_visit'), null, 'a4200000-0000-4000-8000-000000000044') ->> 'reason',
  'visit_not_completed', 'no F6 report: the draft is refused (visit not completed)');
select is(public.end_visit_not_completed(pg_temp.vid('na_visit'), 'started_by_mistake', null, 'a4200000-0000-4000-8000-000000000045'),
  'ok', 'the registered nurse ends the needs assessment started by mistake');
select is(public.generate_billable_facts((select day from d)), 0, 'no billable fact is generated');
reset role;
select is((select count(*)::int from public.billable_facts where visit_id in (select id from fx)), 0, 'no billable fact exists');
select is((select count(*)::int from public.working_time_facts where visit_id in (select id from fx)), 0, 'no working-time fact exists');
select is((select needs_assessment_done_at from public.cases where id = '00000000-0000-4000-a000-000000000208'), null::timestamptz,
  'a needs assessment ended as not completed does not count as done');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*) from public.operations_exceptions() x
           where x.exception_type in ('report_not_final', 'visit_stuck', 'visit_overdue') and x.entity_id in (select id from fx where name <> 'not_yet' and name <> 'later')),
  0::bigint, 'OPS1: no report_not_final, stuck or overdue exception for the ended visits');
reset role;

-- Visible to the team: /field and HAND1 -----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select status from public.field_visits((select day from d)) where visit_id = pg_temp.vid('b_visit')), 'interrupted',
  '/field shows the visit as not completed');
select is((select reason_code from public.field_visit_status_notes((select day from d))
           where visit_id = pg_temp.vid('b_visit') and kind = 'interrupted'), 'client_transferred', '/field shows the reason');
select ok(exists (select 1 from public.field_since_last((select day from d)) s
                  where s.visit_id = pg_temp.vid('later') and s.kind = 'visit_interrupted'
                    and s.detail ->> 'reason_code' = 'client_transferred'),
  'HAND1: the next visit of the case shows the broken-off visit with its reason');
select is((select count(*)::int from public.visit_observations where visit_id = pg_temp.vid('b_visit')), 0,
  'nothing else was written for the visit');
reset role;

select * from finish();
rollback;
