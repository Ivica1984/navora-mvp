-- CSR1, second PR (migration 0039; Clinical Governance Report 2026-10-22 22:30): OPS1's findings CGR-05 and CGR-06.
-- Users: coach …901 (coordinator of org A, may handle serious quality events) · ops …904 (operations, org A)
--        · nurse …902 (registered nurse, Testteam Nord …101) · admin …905 (org A).
-- CGR-05: a serious quality event stays an exception while `in_review` and keeps escalating; only `closed` ends it.
-- CGR-06: a safety exception (effective rule P1 or escalating to P1) is not closed by hand (`cause_persists`); a
--         close written before 0039 does not hide it while the cause persists; it closes when the cause is resolved.
-- Fixtures are synthetic. Legacy closes are inserted as the table owner, as a fixture for data written before 0039.
begin;
create extension if not exists pgtap with schema extensions;

select plan(38);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Fixtures: a visit for a no-show (in 1 h, Nord) and a missed planned visit (2 h ago, Nord, responsible …902).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                responsible_user_id, planned_minutes_a)
select '00000000-0000-4000-b000-000000000011', x.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       ((private.now() + x.shift) at time zone 'Europe/Zurich')::date, ((private.now() + x.shift) at time zone 'Europe/Zurich')::time, null, false, 'planned',
       '00000000-0000-4000-a000-000000000902', 30
from (values ('a3900000-0000-4000-8000-0000000000a1'::uuid, interval '1 hour'),
             ('a3900000-0000-4000-8000-0000000000a2'::uuid, interval '-2 hours')) x(id, shift);
-- A close written before 0039 for the missed visit (the old command allowed it).
insert into public.exception_events (organization_id, exception_key, kind, text, actor_id)
values ('00000000-0000-4000-b000-000000000011', 'visit_overdue:a3900000-0000-4000-8000-0000000000a2', 'close',
        'Vor 0039 geschlossen', '00000000-0000-4000-a000-000000000904');

-- Which types are safety exceptions (pilot defaults) ----------------------------------------------------------------
select is((select string_agg(exception_type, ',' order by exception_type) from public.exception_rules
           where private.exception_is_safety('00000000-0000-4000-b000-000000000011', exception_type)),
  'cover_without_access,no_show_open,quality_serious_open,signal_untaken,visit_overdue,visit_stuck,visit_uncovered_hospital',
  'safety exceptions = P1 or escalating to P1 (pilot defaults; SIG1 signal_untaken (0060) is the P1 operating rule for untaken signals, no exception key of that type exists)');
select ok(not private.exception_is_safety('00000000-0000-4000-b000-000000000011', 'unknown_type'), 'an unknown type is not a safety exception');
select ok(not has_function_privilege('authenticated', 'private.exception_is_safety(uuid, text)', 'execute'),
  'the safety helper is internal');

-- CGR-05: a serious quality event in review stays and keeps escalating ----------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
create temp view q701 as
  select * from public.operations_exceptions() where exception_key = 'quality_serious_open:00000000-0000-4000-a000-000000000701';
select is((select priority from q701), 'P1', 'the seeded serious event (6 h) is P1');
select is(public.set_quality_event_status('00000000-0000-4000-a000-000000000701', 'in_review', null, 'a3900000-0000-4000-8000-000000000001'),
  'ok', 'the coach takes the serious event into review');
select is((select count(*)::int from q701), 1, 'CGR-05: the exception stays while the event is in review');
select is((select priority from q701), 'P1', 'CGR-05: escalation continues in review (P1 after 4 h, from creation)');
select ok((select detail from q701) like '%in Bearbeitung', 'the detail says it is in review');
select is((select closable from q701), false, 'the screen offers no close for it');
select is(public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'take', null,
          'a3900000-0000-4000-8000-000000000002'), 'ok', 'Operations takes it over');
select is(public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'close', 'Team hat übernommen',
          'a3900000-0000-4000-8000-000000000003'), 'cause_persists', 'CGR-06: it is not closed by hand');
select is((select taken_by_me from q701), true, 'still taken over by the coach');
select is(public.set_quality_event_status('00000000-0000-4000-a000-000000000701', 'closed', 'Massnahmen umgesetzt, geprüft',
          'a3900000-0000-4000-8000-000000000004'), 'ok', 'the event is closed with a note (QG1)');
select is((select count(*)::int from q701), 0, 'a closed event ends the exception');
select ok(public.sync_exceptions() >= 1, 'the handled exception is closed automatically');
reset role;
select is((select kind from public.exception_events where exception_key = 'quality_serious_open:00000000-0000-4000-a000-000000000701'
           order by id desc limit 1), 'auto_close', 'with an automatic note, not a manual close');
select is((select count(*)::int from public.exception_events
           where exception_key = 'quality_serious_open:00000000-0000-4000-a000-000000000701' and kind = 'close'), 0,
  'no manual close was written');

-- CGR-06: a no-show stays P1 until its outcome is recorded ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin perform public.depart_visit('a3900000-0000-4000-8000-0000000000a1', 'a3900000-0000-4000-8000-000000000010'); end $$;
select is(public.record_no_show('a3900000-0000-4000-8000-0000000000a1', 'Niemand öffnet, Telefon ohne Antwort',
          'a3900000-0000-4000-8000-000000000011', true), 'ok', 'the nurse records that the client was not reached');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
create temp view ns as
  select * from public.operations_exceptions() where exception_key = 'no_show_open:a3900000-0000-4000-8000-0000000000a1';
select is((select priority || '/' || closable::text from ns), 'P1/false', 'the no-show is P1 and not closable');
select is(public.handle_exception('no_show_open:a3900000-0000-4000-8000-0000000000a1', 'close', 'Wird schon gut sein',
          'a3900000-0000-4000-8000-000000000012'), 'cause_persists', 'CGR-06: a no-show without outcome is not closed by hand');
select is(public.handle_exception('no_show_open:a3900000-0000-4000-8000-0000000000a1', 'close', 'Wird schon gut sein',
          'a3900000-0000-4000-8000-000000000012'), 'cause_persists', 'resending the refused close is refused again');
select is((select count(*)::int from ns), 1, 'it stays in the list');
select is(public.handle_exception('no_show_open:a3900000-0000-4000-8000-0000000000a1', 'comment', 'Team ruft Tochter an',
          'a3900000-0000-4000-8000-000000000013'), 'ok', 'notes remain possible');
reset role;
-- A close written before 0039 must not silence it either.
insert into public.exception_events (organization_id, exception_key, kind, text, actor_id)
values ('00000000-0000-4000-b000-000000000011', 'no_show_open:a3900000-0000-4000-8000-0000000000a1', 'close',
        'Vor 0039 geschlossen', '00000000-0000-4000-a000-000000000904');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from ns), 1, 'a legacy close does not hide the no-show while the outcome is missing');
select is((select taken from ns), false, 'after a legacy close it shows as open, not taken');
select is(public.handle_exception('no_show_open:a3900000-0000-4000-8000-0000000000a1', 'take', null,
          'a3900000-0000-4000-8000-000000000014'), 'ok', 'Operations can take it over again');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_no_show_outcome('a3900000-0000-4000-8000-0000000000a1', 'emergency_contact_informed', 'Tochter informiert, besucht heute',
          'a3900000-0000-4000-8000-000000000015', 'emergency'), 'ok', 'the team records the outcome');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from ns), 0, 'the recorded outcome resolves the cause: the exception ends');
select ok(public.sync_exceptions() >= 1, 'and is closed automatically');
reset role;

-- CGR-06 with a legacy close: a missed visit stays visible to Operations and to the team ----------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority || '/' || closable::text from public.operations_exceptions()
           where exception_key = 'visit_overdue:a3900000-0000-4000-8000-0000000000a2'), 'P1/false',
  'the missed visit closed before 0039 is shown again (P1, not closable)');
select is(public.handle_exception('visit_overdue:a3900000-0000-4000-8000-0000000000a2', 'close', 'Nochmals schliessen',
          'a3900000-0000-4000-8000-000000000020'), 'cause_persists', 'and cannot be closed again');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.team_visit_alerts() where exception_key = 'visit_overdue:a3900000-0000-4000-8000-0000000000a2'), 1,
  'the team sees it despite the legacy close');
select is(public.cancel_visit('a3900000-0000-4000-8000-0000000000a2', 'client_cancelled', 'Klientin hat abgesagt',
          'a3900000-0000-4000-8000-000000000021'), 'ok', 'the team resolves the cause: the visit is cancelled');
select is((select count(*)::int from public.team_visit_alerts() where exception_key = 'visit_overdue:a3900000-0000-4000-8000-0000000000a2'), 0,
  'the alert ends with its cause');
reset role;

-- Every listed exception: closable exactly when it does not close only with its cause ----------------------------------
-- (0044, CSR1 / CGR-22: since then visit_uncovered also closes only with its cause, without becoming a safety type)
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
create temp table listed as select exception_type, closable from public.operations_exceptions();
reset role;
select is((select count(*)::int from listed
           where closable = private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', exception_type)), 0,
  'closable = not a safety exception and not visit_uncovered, for every listed exception');
-- This fixture lists only visit_uncovered besides safety types; closing an overdue offer by hand is tested in 019.
select ok(not private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'offer_overdue')
          and not private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'report_not_final')
          and not private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'case_not_ready'),
  'other non-safety exceptions (an overdue offer, a missing report, a case not ready) stay closable');

-- An organisation that raises a type to P1 (ADM1 override) makes it a safety exception too --------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'team_cancellation_late', 'P1', 24, null,
          'a3900000-0000-4000-8000-000000000030'), 'ok', 'the administrator raises late team cancellations to P1');
reset role;
select ok(private.exception_is_safety('00000000-0000-4000-b000-000000000011', 'team_cancellation_late'),
  'a type raised to P1 is a safety exception for that organisation');

select * from finish();
rollback;
