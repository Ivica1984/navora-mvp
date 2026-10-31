-- ORD0-C2 (CGR-44) and SIG1-C1 (CGR-43, with the `cra` note on SIG2's immediate step): migration 0063, ADR-077.
-- Briefs `docs/agents/briefs/ORD0.md` (15:10, 16:20) and `docs/agents/briefs/SIG1.md` (15:10).
-- Users: nurse …902 (registered nurse) and care assistant …906 (org A, Testteam Nord …101) · operations …904 ·
-- admin …905 (org A …011). Case …208 (org A, Testteam Nord). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(49);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a6500000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a6500000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.task() returns text language sql as $$
  select coalesce(string_agg(status, ',' order by status), '') from public.case_tasks
  where case_id = '00000000-0000-4000-a000-000000000208' and kind = 'inform_gp'
$$;
create function pg_temp.item(p_cat text) returns uuid language sql as $$
  insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by)
  values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
          'Synthetische Leistung', p_cat, 20, '1x täglich', pg_temp.today() + 60, '00000000-0000-4000-a000-000000000902')
  returning id
$$;
-- The care assistant of the case's team records "Hausärztin/Hausarzt informiert".
create function pg_temp.rec(p_date date, p_key integer) returns text language plpgsql as $$
declare r text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000906');
  set local role authenticated;
  r := public.record_gp_informed('00000000-0000-4000-a000-000000000208', p_date, 'telefon', pg_temp.k(p_key)) ->> 'result';
  reset role;
  return r;
end;
$$;
-- A needs-assessment visit of the case that reaches `completed` today (fixture: status written directly).
create function pg_temp.assessment(p_n integer) returns void language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, billable, status,
                                  planned_minutes_a, is_needs_assessment, responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.v(p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', pg_temp.today(), '06:00', false, 'started', 30, true,
          '00000000-0000-4000-a000-000000000902');
  update public.care_visits set status = 'completed' where id = pg_temp.v(p_n);
end;
$$;

-- ORD0-C2 (CGR-44) ------------------------------------------------------------------------------------------------------
-- One transaction: every row has the same created_at, so pg_temp.task() lists the tasks by status.
update public.cases set medical_order_status = null, medical_order_valid_until = null, created_at = private.now() - interval '20 days'
where id = '00000000-0000-4000-a000-000000000208';
delete from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000208' and kind = 'inform_gp';

select pg_temp.item('C');
select is(pg_temp.task(), 'open', 'ORD0-C2 (a): an active C item without an order and without a record → one task');
select is(pg_temp.rec(pg_temp.today() - 5, 1), 'ok', 'fixture: recorded with a date 5 days ago');
select is(pg_temp.task(), 'done', 'ORD0-C2 (b): the record closes it');

select pg_temp.item('C');
select is(pg_temp.task(), 'done,open', 'ORD0-C2 (d): record, then a new active C item → one new task');
select is(private.generate_case_plan('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902') ->> 'result', 'ok',
  'fixture: PLAN2 refresh');
select is(private.generate_case_plan('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902') ->> 'result', 'ok',
  'fixture: a second PLAN2 refresh');
select pg_temp.item('A');
select is(pg_temp.task(), 'done,open', 'ORD0-C2 (d): refreshes and another A/C item while one is open → still one open task');

-- (a′) the needs assessment as a second trigger
select is(pg_temp.rec(pg_temp.today() - 4, 2), 'ok', 'fixture: recorded with a date 4 days ago');
select is(pg_temp.task(), 'done,done', 'the second task is closed');
select pg_temp.assessment(1);
select is(pg_temp.task(), 'done,done,open',
  'ORD0-C2 (d′): a record, then a completed (second) needs-assessment visit without an order → one new task');
select pg_temp.item('C');
select is(pg_temp.task(), 'done,done,open', 'ORD0-C2 (d′): a completed assessment and a new C item on the same day → still one task');

-- covered by a record dated on or after the event
select is(pg_temp.rec(pg_temp.today(), 3), 'ok', 'fixture: recorded today');
select pg_temp.item('A');
select is(pg_temp.task(), 'done,done,done', 'ORD0-C2 (d): a new A item with a record dated on its activation day → no task');
select pg_temp.assessment(2);
select is(pg_temp.task(), 'done,done,done', 'ORD0-C2 (a′): a completed assessment covered by a record of that day → no task');
create temp table t_retired as select pg_temp.item('C') as id;
update public.care_plan_items set active = false where id = (select id from t_retired);
update public.care_plan_items set active = true where id = (select id from t_retired);
select is(pg_temp.task(), 'done,done,done', 'a re-activated C item on a covered day → no task');
select is(private.generate_case_plan('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902') ->> 'result', 'ok',
  'fixture: PLAN2 refresh after the record');
select is(pg_temp.task(), 'done,done,done', 'ORD0-C2 (a): a refresh never reopens it for items already covered');

-- (c): an order present → no task from a B item, an A/C item or an assessment
update public.cases set medical_order_status = 'present', medical_order_valid_until = pg_temp.today() + 90
where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.item('B');
select pg_temp.item('C');
select is(pg_temp.task(), 'done,done,done', 'ORD0-C2 (c): a new B item or a C item with the order present → no task');
select pg_temp.assessment(3);
select is(pg_temp.task(), 'done,done,done', 'ORD0-C2 (d′): a completed assessment with the order present → no task');

-- a closed case opens nothing
update public.cases set medical_order_status = null, medical_order_valid_until = null, lifecycle = 'closed'
where id = '00000000-0000-4000-a000-000000000208';
select is((select count(*)::int from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000208'
           and kind = 'inform_gp' and status = 'open'), 0, 'no open task on the closed case');
update public.cases set lifecycle = 'active' where id = '00000000-0000-4000-a000-000000000208';

-- SIG1-C1 (CGR-43) -------------------------------------------------------------------------------------------------------
-- Structure
select ok((select relrowsecurity from pg_class where oid = 'public.signal_takes'::regclass), 'RLS is on for signal_takes');
select ok(not has_table_privilege('authenticated', 'public.signal_takes', 'select')
          and not has_table_privilege('authenticated', 'public.signal_takes', 'insert')
          and not has_table_privilege('anon', 'public.signal_takes', 'select'),
  'users never read or write takes directly (command and reader only)');
select is((select string_agg(column_name, ',' order by column_name) from information_schema.columns
           where table_schema = 'public' and table_name = 'signal_takes'),
  'access_seq,id,organization_id,qualification,signal_id,stops_escalation,taken_at,taker_id',
  'a take holds who, her qualification, when, and the access sequence she took under (LEAVE1-C3, 0080); no free text');

-- Fixtures: P1 no-show signals for visits 11-14 (responsible: the registered nurse); one P1 overdue visit 15.
-- VIS1-5: the no-show fixture is dated today, 23:59 (still ahead, so no overdue signal of its own); a visit dated
-- after today cannot be departed or recorded as a no-show (CGR-87). Before VIS1 it was tomorrow 09:00.
create function pg_temp.no_show(p_n integer) returns void language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, billable, status, responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.v(p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', pg_temp.today(), '23:59', false, 'planned', '00000000-0000-4000-a000-000000000902');
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000902');
  set local role authenticated;
  perform public.depart_visit(pg_temp.v(p_n), pg_temp.k(100 + p_n));
  perform public.record_no_show(pg_temp.v(p_n), 'Synthetisch: niemand öffnet', pg_temp.k(200 + p_n), true);
  reset role;
end;
$$;
create function pg_temp.sig(p_n integer) returns uuid language sql as $$
  select id from public.safety_signals where visit_id = pg_temp.v(p_n) and ended_at is null
$$;
create function pg_temp.take(p_user integer, p_n integer, p_key integer) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  set local role authenticated;
  r := public.take_signal(pg_temp.sig(p_n), pg_temp.k(p_key));
  reset role;
  return r;
end;
$$;
create function pg_temp.escalated(p_n integer) returns boolean language sql as $$
  select escalated_at is not null from public.safety_signals where id = pg_temp.sig(p_n)
$$;
create function pg_temp.ops(p_n integer) returns integer language sql as $$
  select count(*)::int from public.signal_deliveries where signal_id = pg_temp.sig(p_n) and reason = 'untaken'
$$;
create function pg_temp.eval() returns integer language sql as $$
  select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true)
$$;

-- SIG2's immediate step first (the 15-minute SIG1-5 default does not fire here): the channel on, the registered nurse's
-- device active, the care assistant takes within the 2 minutes, the sender never reports.
update public.push_vendors set dpf_swiss_status = 'active', dpf_read_on = '2026-10-24';
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', true, pg_temp.k(1)), 'ok', 'fixture: the outside channel is on');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.register_push_subscription('https://fcm.googleapis.com/fcm/send/syn-c63', repeat('B', 87), repeat('a', 22), pg_temp.k(2)) ->> 'result',
  'ok', 'fixture: the registered nurse opted in');
reset role;
update public.push_subscriptions set last_result = 'sent' where user_id = pg_temp.u(902);
select pg_temp.no_show(11);
select pg_temp.eval();
select ok(pg_temp.sig(11) is not null and not pg_temp.escalated(11), 'fixture: a P1 no-show signal, handed to the sender, not escalated');
select is(pg_temp.take(906, 11, 21) ->> 'result', 'ok', 'SIG1-C1 (a): the care assistant takes the no-show');
select is((pg_temp.take(906, 11, 22) ->> 'operations_follows'), null, 'a second tap by her → duplicate (nothing more to record)');
set local session_replication_role = replica;
update public.signal_outside_deliveries set decided_at = private.now() - interval '3 minutes'
where id in (select d.id from public.signal_deliveries d where d.signal_id = pg_temp.sig(11));
set local session_replication_role = origin;
select pg_temp.eval();
select ok(pg_temp.escalated(11) and pg_temp.ops(11) = 1,
  'SIG1-C1 / CGR-43 note: no outside send succeeded → Operations receives it although the care assistant took it');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', false, pg_temp.k(3)), 'ok', 'fixture: the outside channel is off again');
reset role;

-- SIG1-5 step: episodes are written with the 15-minute default; the takes come before the step runs.
select pg_temp.no_show(12);
select pg_temp.no_show(13);
select pg_temp.no_show(14);
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, billable, status, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(15), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        ((private.now() - interval '2 hours') at time zone 'Europe/Zurich')::date, ((private.now() - interval '2 hours') at time zone 'Europe/Zurich')::time(0),
        false, 'planned', '00000000-0000-4000-a000-000000000902');
select pg_temp.eval();
select ok(pg_temp.sig(12) is not null and pg_temp.sig(13) is not null and pg_temp.sig(14) is not null and pg_temp.sig(15) is not null,
  'fixture: four P1 signals (three no-shows, one overdue)');
select is((select signal_kind from public.safety_signals where id = pg_temp.sig(15)), 'visit_overdue', 'fixture: visit 15 is overdue');

select is(pg_temp.take(906, 12, 31) ->> 'operations_follows', 'true', 'SIG1-C1 (a): care assistant takes a P1 no-show → Operations follows');
select is(pg_temp.take(902, 13, 32) ->> 'operations_follows', 'false', 'SIG1-C1 (b): registered nurse takes → the step stops');
select is(pg_temp.take(906, 14, 33) ->> 'result', 'ok', 'care assistant takes no-show 14 first');
select is(pg_temp.take(902, 14, 34) ->> 'result', 'ok', 'SIG1-C1: then the registered nurse can still take it');
select is(pg_temp.take(906, 15, 35) ->> 'operations_follows', 'false', 'SIG1-C1 (c): care assistant takes visit_overdue → stops, as built');

-- what the people see before the step
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select taken_by_name is not null and taken_by_qualification = 'care_assistant' and taken_awaits_rn and not taken_by_me
           from public.my_signals() where signal_id = pg_temp.sig(12)), true,
  'SIG1-C1 (a): the registered nurse sees who took it, as care assistant, and that the step to Operations follows');
select is((select taken_by_me and taken_by_qualification = 'registered_nurse' and not taken_awaits_rn
           from public.my_signals() where signal_id = pg_temp.sig(14)), true,
  'after her own take the no-show shows the registered nurse''s take, nothing pending');
reset role;

select is(pg_temp.take(906, 13, 36) ->> 'result', 'duplicate', 'a care assistant tapping after the registered nurse → duplicate');

select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'signal_untaken', 'P1', 0, null, pg_temp.k(6)), 'ok',
  'fixture: the untaken threshold set stricter (0 minutes), so the SIG1-5 step runs at the next evaluation');
reset role;
select pg_temp.eval();
select ok(pg_temp.escalated(12) and pg_temp.ops(12) = 1, 'SIG1-C1 (d): care assistant takes a P1 no-show → escalated after signal_untaken');
select ok(not pg_temp.escalated(13) and pg_temp.ops(13) = 0, 'SIG1-C1 (d): registered nurse takes → not escalated');
select ok(not pg_temp.escalated(14) and pg_temp.ops(14) = 0, 'SIG1-C1 (d): care assistant then registered nurse → not escalated');
select ok(not pg_temp.escalated(15) and pg_temp.ops(15) = 0, 'SIG1-C1 (d): care assistant takes visit_overdue → not escalated (as built)');

-- record and guards
select is((select string_agg(right(taker_id::text, 3) || ':' || coalesce(qualification, '-') || ':' || stops_escalation, ',' order by stops_escalation, taker_id)
           from public.signal_takes where signal_id = pg_temp.sig(14)),
  '906:care_assistant:false,902:registered_nurse:true', 'SIG1-C1: both takes are kept, with qualification and effect');
select is((select taken_by from public.safety_signals where id = pg_temp.sig(14)), pg_temp.u(906),
  'safety_signals.taken_by stays the first take (AN2 measure 10 unchanged)');
select throws_ok($$ update public.signal_takes set stops_escalation = true $$, '42501', null, 'a take is never changed');
select is((select count(*)::int from public.audit_events where table_name = 'signal_takes' and command = 'take_signal'
           and idempotency_key = pg_temp.k(34)), 1, 'the registered nurse''s second take is audited with who, the command and the key');

select * from finish();
rollback;
