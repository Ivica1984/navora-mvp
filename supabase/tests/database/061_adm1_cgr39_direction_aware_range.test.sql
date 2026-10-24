-- ADM1 changes (PO 2026-10-24 07:10, ADM1-R1 to R4): CGR-39, direction-aware safe range (migration 0059, ADR-072).
-- Users: admin …905 (org A …011) · operations …904 (org A) · foreign admin …903 (org B …012). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(49);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

create function pg_temp.set_rule(p_type text, p_priority text, p_amount integer, p_escalate integer, p_n integer)
returns text language sql as $$
  select public.set_exception_rule('00000000-0000-4000-b000-000000000011', p_type, p_priority, p_amount, p_escalate,
                                   ('a6100000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid)
$$;

-- ADM1-R1: a direction for every amount-bearing rule ---------------------------------------------------------------
select is((select string_agg(exception_type || '=' || amount_direction, ',' order by exception_type)
           from public.exception_rules where amount is not null),
  'case_not_ready=delay,cover_without_access=look_ahead,order_expiring=look_ahead,report_not_final=delay,'
  'signal_untaken=delay,team_cancellation_late=look_ahead,visit_overdue=delay,visit_stuck=delay,visit_uncovered=look_ahead,'
  'visit_uncovered_hospital=look_ahead',
  'every amount-bearing rule has its direction (look-ahead: uncovered, hospital, order, late cancellation, cover)');
select is((select count(*)::int from public.exception_rules where (amount is null) <> (amount_direction is null)), 0,
  'no rule has an amount without a direction, or a direction without an amount');
select throws_ok($$ insert into public.exception_rules (exception_type, priority, amount, unit, label, next_step)
                    values ('adm1_test_new', 'P3', 5, 'hours', 'Test', 'Test') $$,
  '23514', null, 'a new amount-bearing rule without a direction cannot be inserted');
select throws_ok($$ insert into public.exception_rules (exception_type, priority, amount, unit, amount_direction, label, next_step)
                    values ('adm1_test_new', 'P3', 5, 'hours', 'later', 'Test', 'Test') $$,
  '23514', null, 'only look_ahead or delay');
select ok((select count(*) = 19 from private.effective_exception_rules('00000000-0000-4000-b000-000000000011')),   -- SIG1 signal_untaken (0060), ORD0 order_without_end_date (0061)
  'the effective rules still list every rule (row type with the new column)');

-- ADM1-R4: behaviour with the default (before any override) --------------------------------------------------------
-- Case 208 came as a hospital discharge; an unassigned planned visit starts in 36 h.
insert into public.matching_requests (organization_id, case_id, request_title, region, urgency, status, referral_type, selected_team_id)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'Teamsuche CGR-39', 'Bern West', 'mittel',
        'accepted', 'hospital_discharge', '00000000-0000-4000-a000-000000000101');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000011', 'a6100000-0000-4000-8000-000000000601', '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (now() at time zone 'Europe/Zurich' + interval '36 hours')::date,
       (now() at time zone 'Europe/Zurich' + interval '36 hours')::time, null, false, 'planned';

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions()
           where exception_type = 'visit_uncovered_hospital' and entity_id = 'a6100000-0000-4000-8000-000000000601'), 0,
  'with the 24 h default, an unassigned hospital-discharge visit in 36 h raises no P1 exception yet');
reset role;

-- ADM1-R2 / R4: the admin command ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
-- look-ahead: never below the default, at most 4x
select is(pg_temp.set_rule('visit_uncovered_hospital', 'P1', 12, null, 1), 'out_of_range', 'hospital P1: 12 h would come later');
select is(pg_temp.set_rule('visit_uncovered_hospital', 'P1', 0, null, 2), 'out_of_range', 'hospital P1: 0 h would never fire');
select is(pg_temp.set_rule('visit_uncovered_hospital', 'P2', 24, null, 3), 'out_of_range', 'hospital P1: priority cannot be lowered');
select is(pg_temp.set_rule('visit_uncovered_hospital', 'P1', 97, null, 4), 'out_of_range', 'hospital P1: at most 4x the default (96 h)');
select is(pg_temp.set_rule('visit_uncovered_hospital', 'P1', 48, null, 5), 'ok', 'hospital P1: 48 h is stricter');
select is(pg_temp.set_rule('visit_uncovered', 'P2', 0, null, 6), 'out_of_range', 'uncovered: 0 h would never fire');
select is(pg_temp.set_rule('visit_uncovered', 'P2', 23, null, 7), 'out_of_range', 'uncovered: below the default');
select is(pg_temp.set_rule('visit_uncovered', 'P2', 36, null, 8), 'ok', 'uncovered: 36 h is stricter');
select is(pg_temp.set_rule('order_expiring', 'P3', 0, null, 9), 'out_of_range', 'order: 0 days only on the end date');
select is(pg_temp.set_rule('order_expiring', 'P3', 3, null, 10), 'out_of_range', 'order: 3 days would come later');
select is(pg_temp.set_rule('order_expiring', 'P3', 29, null, 11), 'out_of_range', 'order: at most 4x the default (28 days)');
select is(pg_temp.set_rule('order_expiring', 'P3', 14, null, 12), 'ok', 'order: 14 days is stricter');
select is(pg_temp.set_rule('team_cancellation_late', 'P2', 0, null, 13), 'out_of_range', 'late cancellation: 0 h would never fire');
select is(pg_temp.set_rule('team_cancellation_late', 'P2', 48, null, 14), 'ok', 'late cancellation: 48 h is stricter');
select is(pg_temp.set_rule('cover_without_access', 'P2', 0, 20, 15), 'out_of_range', 'cover without access: 0 h would never fire');
select is(pg_temp.set_rule('cover_without_access', 'P2', 48, 20, 16), 'ok', 'cover without access: 48 h is stricter');
-- delay: never above the default
select is(pg_temp.set_rule('visit_stuck', 'P2', 2, 3, 17), 'out_of_range', 'stuck: 2 h would come later');
select is(pg_temp.set_rule('visit_stuck', 'P2', 0, 3, 18), 'out_of_range', 'stuck: floor 1 h (0 would flag every visit at its start)');
select is(pg_temp.set_rule('visit_stuck', 'P2', 1, 4, 19), 'out_of_range', 'stuck: escalation never later');
select is(pg_temp.set_rule('visit_stuck', 'P2', 1, 2, 20), 'ok', 'stuck: 1 h with an earlier escalation');
select is(pg_temp.set_rule('report_not_final', 'P3', 48, null, 21), 'out_of_range', 'report: 48 h would come later');
select is(pg_temp.set_rule('report_not_final', 'P3', 12, null, 22), 'ok', 'report: 12 h is stricter');
select is(pg_temp.set_rule('visit_overdue', 'P2', 1, 1, 23), 'out_of_range', 'overdue: 1 h would come later than at the start');
select is(pg_temp.set_rule('visit_overdue', 'P1', 0, 1, 24), 'ok', 'overdue: raised to P1 at the default');
select is(pg_temp.set_rule('case_not_ready', 'P3', 2, null, 25), 'out_of_range', 'case not ready: 2 working days would come later');
select is(pg_temp.set_rule('case_not_ready', 'P3', 0, null, 26), 'ok', 'case not ready: at once');
-- rules without an amount, escalation of serious quality events (unchanged)
select is(pg_temp.set_rule('quality_serious_open', 'P2', null, 5, 27), 'out_of_range', 'serious quality events: escalation never later');
select is(pg_temp.set_rule('quality_serious_open', 'P2', 4, 4, 28), 'out_of_range', 'no amount on a rule without one');
select is(pg_temp.set_rule('quality_serious_open', 'P2', null, 2, 29), 'ok', 'serious quality events: earlier escalation');

select ok((select amount_direction = 'look_ahead' and min_amount = 24 and max_amount = 96 and amount = 48 and not is_default
           from public.admin_exception_rules('00000000-0000-4000-b000-000000000011') where exception_type = 'visit_uncovered_hospital'),
  '/admin reads direction, lower bound, upper bound and the override (hospital: 24 to 96 h)');
select ok((select amount_direction = 'delay' and min_amount = 0 and max_amount = 24
           from public.admin_exception_rules('00000000-0000-4000-b000-000000000011') where exception_type = 'report_not_final'),
  '/admin: report 0 to 24 h');
select ok((select amount_direction = 'delay' and min_amount = 1 and max_amount = 1
           from public.admin_exception_rules('00000000-0000-4000-b000-000000000011') where exception_type = 'visit_stuck'),
  '/admin: stuck 1 to 1 h');
select ok((select amount_direction = 'look_ahead' and min_amount = 7 and max_amount = 28
           from public.admin_exception_rules('00000000-0000-4000-b000-000000000011') where exception_type = 'order_expiring'),
  '/admin: order 7 to 28 days');
select ok((select amount_direction is null and min_amount is null and max_amount is null
           from public.admin_exception_rules('00000000-0000-4000-b000-000000000011') where exception_type = 'quality_serious_open'),
  '/admin: a rule without an amount has no direction');
reset role;

-- ADM1-R4: behaviour with the accepted stricter override -------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from public.operations_exceptions()
           where exception_type = 'visit_uncovered_hospital' and entity_id = 'a6100000-0000-4000-8000-000000000601'), 'P1',
  'with the accepted 48 h override, the same visit in 36 h raises the P1 exception');
reset role;
select is((select amount from private.effective_exception_rules('00000000-0000-4000-b000-000000000012')
           where exception_type = 'visit_uncovered_hospital'), 24, 'other organisations keep the default');

-- ADM1-R3: existing overrides outside the range are reset, audited ---------------------------------------------------
-- Simulated as the table owner: two overrides the old range accepted (later than the default) and one valid one.
insert into public.exception_rule_overrides (organization_id, exception_type, priority, amount, escalate_to_p1_after_hours, updated_by)
values ('00000000-0000-4000-b000-000000000012', 'visit_uncovered_hospital', 'P1', 0, null, '00000000-0000-4000-a000-000000000903'),
       ('00000000-0000-4000-b000-000000000012', 'visit_stuck', 'P2', 2, 3, '00000000-0000-4000-a000-000000000903'),
       ('00000000-0000-4000-b000-000000000012', 'order_expiring', 'P3', 14, null, '00000000-0000-4000-a000-000000000903');
select is(private.adm1_reset_out_of_range_overrides(), 2, 'the reset finds the two overrides outside the range (org A''s are all valid)');
select is((select string_agg(exception_type, ',' order by exception_type) from public.exception_rule_overrides
           where organization_id = '00000000-0000-4000-b000-000000000012'), 'order_expiring',
  'they are back at the platform default; the valid override stays');
select is((select count(*)::int from public.audit_events
           where command = 'adm1_range_reset' and organization_id = '00000000-0000-4000-b000-000000000012'), 2,
  'one audit row per reset');
select ok((select changed ->> 'amount' = '0' and changed ->> 'exception_type' = 'visit_uncovered_hospital' and actor_id is null
           from public.audit_events where command = 'adm1_range_reset' and changed ->> 'exception_type' = 'visit_uncovered_hospital'),
  'the audit row names the old value');
select is((select amount from private.effective_exception_rules('00000000-0000-4000-b000-000000000012')
           where exception_type = 'visit_uncovered_hospital'), 24, 'org B uses the 24 h default again');
select is(private.adm1_reset_out_of_range_overrides(), 0, 'a second run resets nothing (idempotent)');
select ok(not has_function_privilege('authenticated', 'private.adm1_reset_out_of_range_overrides()', 'execute'),
  'users cannot run the reset');

select * from finish();
rollback;
