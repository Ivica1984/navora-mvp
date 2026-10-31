-- OPS1: Operations exception center (PO brief docs/agents/briefs/OPS1.md, Q9 defaults).
-- Users: ops …904 (org A, operations = coordination role) · nurse …902 (Testteam Nord) · foreign admin …903 (org B)
-- Seed: quality event …701 "Testereignis hoch" (high, open 6 h, Testteam Mitte); …702 low.
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

-- CSR1 / CGR-02 (0041): sign_report carries the hash of the snapshot /field shows (field_reports.snapshot_hash).
create function pg_temp.shown_hash(rid uuid) returns text language sql as $f$
  select f.snapshot_hash from public.visit_reports r join public.care_visits v on v.id = r.visit_id
  cross join lateral public.field_reports(v.visit_date) f where r.id = rid and f.report_id = rid
$f$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Configuration ------------------------------------------------------------------------------------------
select is((select count(*)::int from public.exception_rules), 21, 'twenty-one operating rules are configured (10 from OPS1 + C1 no_show_open, team_cancellation_late + COVER1 cover_without_access + CSR1 visit_overdue, visit_stuck, visit_interrupted, report_correction_open + SIG1 signal_untaken, 0060 + ORD0 order_without_end_date, 0061 + ADM2 successor_needed, 0092 + AIG1 agent_stopped, 0097)');
select is((select string_agg(exception_type || '=' || priority, ',' order by exception_type) from public.exception_rules
           where exception_type in ('visit_uncovered_hospital', 'visit_uncovered', 'offer_overdue', 'case_not_ready', 'report_not_final')),
  'case_not_ready=P3,offer_overdue=P2,report_not_final=P3,visit_uncovered=P2,visit_uncovered_hospital=P1',
  'pilot priorities follow Q9');
select is((select escalate_to_p1_after_hours from public.exception_rules where exception_type = 'quality_serious_open'), 4,
  'a serious quality event becomes P1 after 4 hours (Q9)');
select ok(not has_table_privilege('authenticated', 'public.exception_events', 'insert'), 'handling only through commands');
select ok(not has_table_privilege('authenticated', 'public.exception_rules', 'update'), 'rules change by migration or admin tooling, not by users');

-- Fixtures (as owner) --------------------------------------------------------------------------------------
-- a fresh serious event (1 h) → still P2
insert into public.quality_events (organization_id, id, created_at, case_id, team_id, event_type, severity, title, status)
values ('00000000-0000-4000-b000-000000000011', 'a9000000-0000-4000-8000-000000000701', private.now() - interval '1 hour',
        '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', 'process', 'critical', 'Frisches Ereignis', 'open');
-- case 208 came as a hospital discharge; an uncovered visit in 3 hours
insert into public.matching_requests (organization_id, case_id, request_title, region, urgency, status, referral_type, selected_team_id)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'Teamsuche alt', 'Bern West', 'mittel',
        'accepted', 'hospital_discharge', '00000000-0000-4000-a000-000000000101');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000011', 'a9000000-0000-4000-8000-000000000601', '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', ((private.now() + interval '3 hours') at time zone 'Europe/Zurich')::date,
       ((private.now() + interval '3 hours') at time zone 'Europe/Zurich')::time, null, false, 'planned';
-- order expiring in 3 days; care-plan review overdue
update public.cases set medical_order_status = 'present', medical_order_valid_until = (private.now() at time zone 'Europe/Zurich')::date + 3
  where id = '00000000-0000-4000-a000-000000000208';
insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        'OPS1 Testleistung', 'A', 20, 'täglich', (private.now() at time zone 'Europe/Zurich')::date - 1, '00000000-0000-4000-a000-000000000902');
-- thresholds 0 so the time-based types exist now (configuration, not code)
update public.exception_rules set amount = 0 where exception_type in ('case_not_ready', 'report_not_final');

-- Intake: one referral left incomplete, one in a region without any team
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$ begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital OPS1', 'Spital', 'Bern West', null,
    'mittel', null, 'OPS1 unvollständig', 'Bedarf', array['Grundpflege'], 'a9000000-0000-4000-8000-000000000001', 'referrer_stated');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'OPS1 unvollständig'),
    'Klient', 'OPS1U', true, '{}'::jsonb, 'a9000000-0000-4000-8000-000000000002');
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital OPS1', 'Spital', 'Region ohne Team OPS1', null,
    'mittel', null, 'OPS1 ohne Team', 'Bedarf', array['Grundpflege'], 'a9000000-0000-4000-8000-000000000003', 'referrer_stated');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'OPS1 ohne Team'),
    'Klient', 'OPS1N', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 2),
    'a9000000-0000-4000-8000-000000000004');
end $$;
reset role;

-- Nurse runs visit 501 to completion (report not yet final)
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.start_visit('00000000-0000-4000-a000-000000000501', 'a9000000-0000-4000-8000-000000000010');
  perform public.complete_visit('00000000-0000-4000-a000-000000000501', 'a9000000-0000-4000-8000-000000000011');
end $$;
select is((select count(*)::int from public.operations_exceptions()), 0, 'a nurse sees no exceptions');
select is(public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'take', null,
          'a9000000-0000-4000-8000-000000000012'), 'rejected', 'a nurse cannot handle exceptions');
reset role;

-- Derivation (Operations) ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from public.operations_exceptions() where exception_type = 'quality_serious_open' and entity_id = '00000000-0000-4000-a000-000000000701'), 'P1',
  'a serious event open for 6 h is P1');
select is((select priority from public.operations_exceptions() where exception_type = 'quality_serious_open' and entity_id = 'a9000000-0000-4000-8000-000000000701'), 'P2',
  'a serious event open for 1 h is shown, not yet P1');
select is((select count(*)::int from public.operations_exceptions() where entity_id = '00000000-0000-4000-a000-000000000702'), 0,
  'a low-severity event is not an OPS1 exception');
select is((select priority from public.operations_exceptions() where exception_type = 'visit_uncovered_hospital' and entity_id = 'a9000000-0000-4000-8000-000000000601'), 'P1',
  'an uncovered visit within 24 h for a hospital-discharge case is P1');
select ok((select team_name = 'Testteam Nord' and case_label is not null from public.operations_exceptions() where exception_type = 'visit_uncovered_hospital' and entity_id = 'a9000000-0000-4000-8000-000000000601'), 'the exception names case and team');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'order_expiring' and case_id = '00000000-0000-4000-a000-000000000208'), 1,
  'an order expiring within 7 days is an exception');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'care_plan_review_overdue' and case_id = '00000000-0000-4000-a000-000000000208'), 1,
  'an overdue care-plan review is an exception');
select ok((select detail like '%insurer%' from public.operations_exceptions() where exception_type = 'case_not_ready' and case_label like '%OPS1U%'),
  'a case not ready for matching after the threshold is an exception, with what is missing');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'candidates_exhausted' and case_label like '%OPS1N%'), 1,
  'a team search without any eligible team is an exception');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'report_not_final' and entity_id = '00000000-0000-4000-a000-000000000501'), 1,
  'a completed visit without a final report after the threshold is an exception');
select is((select count(*)::int from public.operations_exceptions()
           where exception_type not in (select exception_type from public.exception_rules)), 0, 'every exception has a configured type');

-- Handling ----------------------------------------------------------------------------------------------------
select is(public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'take', null,
          'a9000000-0000-4000-8000-000000000020'), 'ok', 'Operations takes over an exception');
select is(public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'take', null,
          'a9000000-0000-4000-8000-000000000020'), 'duplicate', 'resend is a duplicate');
select ok((select taken_by_me from public.operations_exceptions() where exception_type = 'quality_serious_open' and entity_id = '00000000-0000-4000-a000-000000000701'),
  'who took it is visible');
select throws_ok($$ select public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'comment', 'x',
          'a9000000-0000-4000-8000-000000000021') $$, '22023', null, 'a comment needs text');
select is(public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'comment', 'Teamleitung angerufen',
          'a9000000-0000-4000-8000-000000000022'), 'ok', 'Operations comments');
select throws_ok($$ select public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'close', null,
          'a9000000-0000-4000-8000-000000000023') $$, '22023', null, 'closing needs a reason');
-- CSR1 / CGR-06 (migration 0039): a safety exception (P1 or escalating to P1) is not closed by hand; it stays.
select is(public.handle_exception('quality_serious_open:00000000-0000-4000-a000-000000000701', 'close', 'Mit Team geklärt',
          'a9000000-0000-4000-8000-000000000024'), 'cause_persists', 'a serious quality event is not closed by hand (CGR-06)');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'quality_serious_open' and entity_id = '00000000-0000-4000-a000-000000000701'), 1,
  'the safety exception stays in the list while its cause persists');
-- A continuity exception without escalation (P2) still closes with a reason.
select is(public.handle_exception((select exception_key from public.operations_exceptions() where exception_type = 'candidates_exhausted' and case_label like '%OPS1N%'),
          'close', 'Mit zuweisender Stelle geklärt', 'a9000000-0000-4000-8000-000000000026'), 'ok', 'Operations closes a P2 exception with a reason');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'candidates_exhausted' and case_label like '%OPS1N%'), 0,
  'a closed exception leaves the list');
select is(public.handle_exception((select exception_key from public.exception_events where text = 'Mit zuweisender Stelle geklärt'), 'comment', 'zu spät',
          'a9000000-0000-4000-8000-000000000025'), 'rejected', 'a closed exception takes no more handling');

-- Auto close when the cause is fixed: the team signs the report
select is(public.handle_exception('report_not_final:00000000-0000-4000-a000-000000000501', 'take', null,
          'a9000000-0000-4000-8000-000000000030'), 'ok', 'Operations takes over the missing report');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ declare r jsonb; begin
  r := public.create_report_draft('00000000-0000-4000-a000-000000000501', null, 'a9000000-0000-4000-8000-000000000031');
  perform public.sign_report((r ->> 'report_id')::uuid, pg_temp.shown_hash((r ->> 'report_id')::uuid), 'a9000000-0000-4000-8000-000000000032');
end $$;
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.sync_exceptions(), 1, 'the fixed cause closes the exception automatically');
select is((select text from public.exception_events where exception_key = 'report_not_final:00000000-0000-4000-a000-000000000501'
           and kind = 'auto_close'), 'Ursache behoben – automatisch geschlossen', 'with a note');
reset role;

select throws_ok($$ update public.exception_events set text = 'x' $$, '42501', null, 'handling events are append-only');

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() where case_id = '00000000-0000-4000-a000-000000000208'), 0,
  'another organisation sees none of org A''s exceptions');
reset role;

select * from finish();
rollback;
