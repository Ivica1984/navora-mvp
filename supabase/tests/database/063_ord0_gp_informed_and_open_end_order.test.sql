-- ORD0: the doctor link that must not get lost (migration 0061, ADR-075). Brief `docs/agents/briefs/ORD0.md`; the
-- `cra` case set of CGR-36, CGR-38 and CGR-40 (ORD0-5, ORD0-1).
-- Users: nurse …902 and care assistant …906 (org A, Testteam Nord …101) · operations …904 and coach …901 (org A, no
-- team) · admin …903 (org B …012). Cases …208 (org A, Testteam Nord) and …251 (org B). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(53);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a6300000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.rec(p_case text, p_date date, p_channel text, p_key integer) returns text language sql as $$
  select public.record_gp_informed(p_case::uuid, p_date, p_channel, pg_temp.k(p_key)) ->> 'result'
$$;
create function pg_temp.reason(p_case text, p_date date, p_channel text, p_key integer) returns text language sql as $$
  select public.record_gp_informed(p_case::uuid, p_date, p_channel, pg_temp.k(p_key)) ->> 'reason'
$$;
create function pg_temp.task(p_case text) returns text language sql as $$
  select coalesce(string_agg(status, ',' order by created_at), '') from public.case_tasks
  where case_id = p_case::uuid and kind = 'inform_gp'
$$;
create function pg_temp.exc(p_org text, p_case text) returns integer language sql as $$
  select count(*)::int from private.derived_exceptions(p_org::uuid) x
  where x.exception_type = 'order_without_end_date' and x.case_id = p_case::uuid
$$;
create function pg_temp.b_item(p_case text, p_org text, p_team text, p_cat text default 'B') returns uuid language sql as $$
  insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by)
  values (p_org::uuid, p_case::uuid, p_team::uuid, 'Synthetische Leistung', p_cat, 20, '1x täglich', pg_temp.today() + 60,
          '00000000-0000-4000-a000-000000000902')
  returning id
$$;

-- Structure, privileges, RLS --------------------------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'public.case_gp_notices'::regclass), 'RLS is on for case_gp_notices');
select ok(not has_table_privilege('authenticated', 'public.case_gp_notices', 'insert')
          and not has_table_privilege('authenticated', 'public.case_gp_notices', 'update')
          and not has_table_privilege('authenticated', 'public.case_gp_notices', 'delete'),
  'ORD0-1: users never write the record directly (command only)');
select ok(not has_table_privilege('anon', 'public.case_gp_notices', 'select'), 'anon reads nothing');
select is((select string_agg(column_name, ',' order by column_name) from information_schema.columns
           where table_schema = 'public' and table_name = 'case_gp_notices'),
  'case_id,channel,id,informed_on,organization_id,recorded_at,recorded_by,task_id,team_id',
  'ORD0-1: date, channel code, task, actor and time; no free text, no health data');
select ok(has_function_privilege('authenticated', 'public.record_gp_informed(uuid, date, text, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.record_gp_informed(uuid, date, text, uuid)', 'execute'),
  'the command is for signed-in users only');
select is((select priority || ' ' || coalesce(amount::text, '-') || ' ' || label from public.exception_rules
           where exception_type = 'order_without_end_date'),
  'P3 - Verordnung ohne Enddatum', 'ORD0-4: an operating rule, P3, no threshold');

-- CGR-36: an A/C visit planned without an order opens the task ------------------------------------------------------------
update public.cases set needs_assessment_done_at = now() - interval '2 days', medical_order_status = null,
                        created_at = now() - interval '20 days'
where id = '00000000-0000-4000-a000-000000000208';
-- the task was created 5 days ago (CGR-40: the doctor may have been informed before that, at the assessment)
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
select is((public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 2, '15:00', '15:30', 30, 0, 0, false,
                             '00000000-0000-4000-a000-000000000902', pg_temp.k(1)) ->> 'result'), 'ok',
  'an A/C visit is planned without a medical order');
reset role;
select is(pg_temp.task('00000000-0000-4000-a000-000000000208'), 'open', 'CGR-36: the inform_gp task is open');
update public.case_tasks set created_at = now() - interval '5 days'
where case_id = '00000000-0000-4000-a000-000000000208' and kind = 'inform_gp';

-- complete_case_task stays refused for inform_gp (separate command) ------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$select public.complete_case_task('00000000-0000-4000-a000-000000000208', 'inform_gp', 'a6300000-0000-4000-9000-000000000002')$$,
  '22023', null, 'ORD0-2: complete_case_task(''inform_gp'') stays refused');

-- Input checks ------------------------------------------------------------------------------------------------------------
select throws_ok($$select public.record_gp_informed('00000000-0000-4000-a000-000000000208', (now() at time zone 'Europe/Zurich')::date, 'fax', 'a6300000-0000-4000-9000-000000000003')$$,
  '22023', null, 'ORD0-1: only the fixed channel codes');
select throws_ok($$select public.record_gp_informed('00000000-0000-4000-a000-000000000208', null, 'telefon', 'a6300000-0000-4000-9000-000000000004')$$,
  '22023', null, 'ORD0-1: the date is required');

-- Who may record --------------------------------------------------------------------------------------------------------
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today(), 'telefon', 10), 'rejected',
  'ORD0-5: Operations (organisation member, not in the case''s team) → rejected');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today(), 'telefon', 11), 'rejected',
  'ORD0-5: the coach (not in the team) → rejected');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today(), 'telefon', 12), 'rejected',
  'ORD0-5: another organisation → rejected');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;

-- CGR-40 dates (the care assistant is a member of the case's team) -------------------------------------------------------
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today() + 1, 'telefon', 20), 'rejected',
  'CGR-40: a future date (Zurich day) → rejected');
select is(pg_temp.reason('00000000-0000-4000-a000-000000000208', pg_temp.today() + 1, 'telefon', 21), 'future', 'reason future');
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today() - 21, 'telefon', 22), 'rejected',
  'CGR-40: a date before the case was created → rejected');
select is(pg_temp.reason('00000000-0000-4000-a000-000000000208', pg_temp.today() - 21, 'telefon', 23), 'before_case', 'reason before_case');
reset role;
select is(pg_temp.task('00000000-0000-4000-a000-000000000208'), 'open', 'a refused record leaves the task open');
select is((select count(*)::int from public.case_gp_notices), 0, 'and writes no record');
select is((select count(*)::int from public.audit_events where command = 'record_gp_informed'), 0, 'and no audit row');

-- A team member records it with a date between case creation and task creation ------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today() - 10, 'persoenlich', 30), 'ok',
  'CGR-40: a date between case creation and task creation → ok');
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today() - 10, 'persoenlich', 30), 'duplicate',
  'ORD0-1: a replay of the key → duplicate');
select is((select count(*)::int from public.case_gp_notices), 1, 'the team reads the one record (RLS)');
reset role;
select is((select count(*)::int from public.case_gp_notices), 1, 'one record, not two');
select is((select informed_on - pg_temp.today() || ' ' || channel || ' ' || right(recorded_by::text, 3)
           from public.case_gp_notices), '-10 persoenlich 906', 'ORD0-1: date, channel and actor as recorded');
select is((select status || ' ' || right(done_by::text, 3) || ' ' || (done_at is not null)::text from public.case_tasks
           where case_id = '00000000-0000-4000-a000-000000000208' and kind = 'inform_gp'),
  'done 906 true', 'ORD0-2: the task is done, with done_by and the date');
select ok((select n.task_id = k.id from public.case_gp_notices n join public.case_tasks k on k.case_id = n.case_id and k.kind = 'inform_gp'),
  'the record names the task it closed');
select is((select count(*)::int from public.audit_events where table_name = 'case_gp_notices' and command = 'record_gp_informed'
           and idempotency_key = pg_temp.k(30)), 1, 'ORD0-5: one audit row for the record');
select is((select count(*)::int from public.audit_events where table_name = 'case_tasks' and command = 'record_gp_informed'
           and changed ? 'status'), 1, 'and one for the task');

-- RLS: who reads the record --------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.case_gp_notices), 1, 'Operations (coordinator) reads it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.case_gp_notices), 0, 'another organisation reads nothing');
reset role;

-- Immutable --------------------------------------------------------------------------------------------------------------
select throws_ok($$update public.case_gp_notices set channel = 'brief'$$, '42501', null, 'the record is never changed');
select throws_ok($$delete from public.case_gp_notices$$, '42501', null, 'nor deleted');

-- ORD0-2: no second task from planning or PLAN2 once recorded; no open task → unchanged ---------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
select is((public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 3, '15:00', '15:30', 30, 0, 0, false,
                             '00000000-0000-4000-a000-000000000902', pg_temp.k(40)) ->> 'result'), 'ok', 'another A/C visit is planned');
select is(private.generate_case_plan('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902') ->> 'result', 'ok',
  'PLAN2 runs');
reset role;
select is(pg_temp.task('00000000-0000-4000-a000-000000000208'), 'done',
  'ORD0-2 (Q12): planning and PLAN2 do not reopen the task once the doctor was recorded informed');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(pg_temp.rec('00000000-0000-4000-a000-000000000208', pg_temp.today(), 'telefon', 41), 'unchanged',
  'no open task → unchanged, nothing written');
reset role;
select is((select count(*)::int from public.case_gp_notices), 1, 'still one record');

-- ORD0-4 (CGR-38): B item + order present without an end date ------------------------------------------------------------
update public.cases set medical_order_status = 'present', medical_order_valid_until = null
where id = '00000000-0000-4000-a000-000000000208';
select is(pg_temp.exc('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208'), 0,
  'ORD0-4: an order without an end date on A/C care only → no exception');
select pg_temp.b_item('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101', 'C');
select is(pg_temp.exc('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208'), 0,
  'ORD0-4: a C item → still none');
create temp table t_item as select pg_temp.b_item('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-b000-000000000011',
                                                  '00000000-0000-4000-a000-000000000101') as id;
select is(pg_temp.exc('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208'), 1,
  'ORD0-4: an active B item + order present without an end date → the exception');
select is((select team_id::text || ' ' || entity_type from private.derived_exceptions('00000000-0000-4000-b000-000000000011')
           where exception_type = 'order_without_end_date'),
  '00000000-0000-4000-a000-000000000101 case', 'it belongs to the case''s team');

-- shown to the team and in OPS1; never closable by hand
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.team_visit_alerts() where exception_type = 'order_without_end_date' and visit_id is null), 1,
  'ORD0-4: /team shows it (a case alert, no visit)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority || ' ' || closable::text from public.operations_exceptions() where exception_type = 'order_without_end_date'),
  'P3 false', 'ORD0-4: OPS1 shows it, P3, not closable');
select is(public.handle_exception((select exception_key from public.operations_exceptions() where exception_type = 'order_without_end_date'),
                                  'close', 'Synthetisch: erledigt', pg_temp.k(50)),
  'cause_persists', 'ORD0-5: a hand close is refused while it holds');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'order_without_end_date'), 0,
  'ORD0-5: another organisation sees none');
reset role;

-- ends with its cause: end date entered
update public.cases set medical_order_valid_until = pg_temp.today() + 30 where id = '00000000-0000-4000-a000-000000000208';
select is(pg_temp.exc('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208'), 0,
  'ORD0-4: an end date entered → gone');
-- back again, then the B item retired
update public.cases set medical_order_valid_until = null where id = '00000000-0000-4000-a000-000000000208';
update public.care_plan_items set active = false where id = (select id from t_item);
select is(pg_temp.exc('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208'), 0,
  'ORD0-4: no active B item → gone');

-- ORD0-6: the episodes and their endings
select is((select string_agg(coalesce(ending, 'open'), ',' order by started_at, ended_at nulls last) from private.order_open_end_episodes
           where case_id = '00000000-0000-4000-a000-000000000208'),
  'end_date_entered,no_b_item', 'ORD0-6: two episodes, ended by the end date and by the retired B item');

-- another organisation's case never shows in org A
select pg_temp.b_item('00000000-0000-4000-a000-000000000251', '00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000151');
update public.cases set medical_order_status = 'present', medical_order_valid_until = null where id = '00000000-0000-4000-a000-000000000251';
select is(pg_temp.exc('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000251'), 0,
  'ORD0-5: org B''s case is not in org A''s list');
select is(pg_temp.exc('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000251'), 1,
  'and is in org B''s');

-- ORD0-6: AN2 measure 10 rows exist for the team (values follow AN1 suppression; Testteam Nord has 2 people → hidden)
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is((select count(*)::int from public.pilot_hypotheses(pg_temp.today())
           where team_id is null and (measure = 'order_open_end_ending' or measure = 'inform_gp_done_within_7d_share')), 6,
  'ORD0-6: measure 10 has five ending rows and the 7-day share for the organisation');
reset role;

select * from finish();
rollback;
