-- Owner directive 2026-11-03 (#824, relayed by `po`; ADR-141, migration 0107): the AIG1 register can never point an
-- assistant at billing or at a safety signal's priority, and no AIG1 path writes those tables.
--   (1) `private.aig1_prohibited_target(table, column)` names the class of every billing and safety-signal-priority
--       target and returns null for the one field the register holds today (care_visits.responsible_user_id);
--   (2) the field register refuses such a target for an agent, class `record` as well as `schedule` (42501);
--   (3) no field in the register points at such a target (catalogue, holds for every later migration);
--   (4) no function that reads the suggestion ledger or the confirmations, or applies a confirmed value, writes a
--       billing or safety-signal table (catalogue over pg_proc, holds for every later migration);
--   (5) no agent of kind `ai` is registered (D-35 rule A; the switch refusal itself is pinned by pgTAP 097 test
--       "AIG1-1: an agent of kind ai is refused with its reason (D-35 rule A)").
-- Guards that already had tests before this file (named in the PR): AIG1-1 kind `ai` refused at switch-on (097), level
-- G/H refused (097), a value becomes record content only through confirm_suggestion(s) and a named confirmer (097,
-- AIG1-3), no grant on the ledger or confirmations for app roles (097, AIG1-11).
-- Nothing here calls an AI service or touches a live project. Synthetic data only; no seed user is needed.
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

-- A synthetic rule agent for the register writes below (rolled back with the transaction).
insert into public.ai_agent_definitions (key, name, level, kind, version, provider, region, fixture, eval_bar, brief)
values ('g108_test_rule', 'Synth Register 108', 'L', 'rule', '1', null, null, null, null, 'AIG1');

-- (1) the classification -----------------------------------------------------------------------------------------------
select is(private.aig1_prohibited_target('billable_facts', 'billable'), 'billing',
  '#824: billable_facts is a billing target');
select is(private.aig1_prohibited_target('billing_rules', 'rule'), 'billing', '#824: billing_rules is a billing target');
select is(private.aig1_prohibited_target('tariff_rates', 'rate'), 'billing', '#824: tariff_rates is a billing target');
select is(private.aig1_prohibited_target('quality_holds', 'lifted_at'), 'billing',
  '#824: a quality hold (the single billing rule visit_has_open_hold) is a billing target');
select is(private.aig1_prohibited_target('safety_signals', 'p1_at'), 'safety_signal',
  '#824: safety_signals is a safety-signal target');
select is(private.aig1_prohibited_target('signal_deliveries', 'reason'), 'safety_signal',
  '#824: signal_deliveries is a safety-signal target');
select is(private.aig1_prohibited_target('signal_takes', 'taken_by'), 'safety_signal',
  '#824: every signal_* table is a safety-signal target');
select is(private.aig1_prohibited_target('exception_rules', 'priority'), 'safety_signal',
  '#824: the exception rules that make a signal P1 are a safety-signal target');
select is(private.aig1_prohibited_target('exception_rule_overrides', 'priority'), 'safety_signal',
  '#824: an organisation''s priority override is a safety-signal target');
select is(private.aig1_prohibited_target('care_visits', 'responsible_user_id'), null,
  '#824: the responsible member of a visit (AIG1-5, CGR-78) is not a prohibited target');

-- (2) the register refuses, whatever the class ---------------------------------------------------------------------------
select throws_ok($$ insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
                   values ('g108_test_rule', 'billable', 'billable_facts', 'billable', 'record') $$, '42501', null,
  '#824: a record-class field on billable_facts is refused');
select throws_ok($$ insert into public.ai_agent_fields values ('g108_test_rule', 'billable_s', 'billable_facts', 'billable',
                   'schedule', 'AIG1', 'cra test') $$, '42501', null,
  '#824: a schedule-class field on billable_facts is refused');
select throws_ok($$ insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
                   values ('g108_test_rule', 'tariff', 'tariff_rates', 'rate', 'record') $$, '42501', null,
  '#824: a field on tariff_rates is refused');
select throws_ok($$ insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
                   values ('g108_test_rule', 'hold', 'quality_holds', 'lifted_at', 'record') $$, '42501', null,
  '#824: a field on quality_holds is refused');
select throws_ok($$ insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
                   values ('g108_test_rule', 'signal', 'safety_signals', 'p1_at', 'record') $$, '42501', null,
  '#824: a field on safety_signals is refused');
select throws_ok($$ insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
                   values ('g108_test_rule', 'prio', 'exception_rules', 'priority', 'record') $$, '42501', null,
  '#824: a field on the exception priority is refused');
select throws_ok($$ insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
                   values ('g108_test_rule', 'prio_o', 'exception_rule_overrides', 'priority', 'record') $$, '42501', null,
  '#824: a field on an organisation''s priority override is refused');
-- An allowed field is still accepted (the guard narrows, nothing else changes), and cannot be moved onto billing.
insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
values ('g108_test_rule', 'note', 'care_visits', 'notes', 'record');
select throws_ok($$ update public.ai_agent_fields set target_table = 'billable_facts', target_column = 'billable'
                   where agent_key = 'g108_test_rule' and field = 'note' $$, '42501', null,
  '#824: an existing field cannot be moved onto a billing target');

-- (3) the register as it stands ------------------------------------------------------------------------------------------
select is((select count(*)::int from public.ai_agent_fields f
           where private.aig1_prohibited_target(f.target_table, f.target_column) is not null), 0,
  '#824: no field in the register points at billing or a safety signal''s priority');

-- (4) no AIG1 path writes billing or safety-signal tables ------------------------------------------------------------------
create temp table g108_aig1_fns on commit drop as
select p.oid::regprocedure::text as fn, p.prosrc
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and (p.prosrc ~* '\m(ai_suggestions|ai_confirmations)\M' or p.proname ~ '^aig1_apply');
select ok((select count(*) from g108_aig1_fns) >= 3,
  '#824: the catalogue check finds the AIG1 functions it guards (ledger readers, confirm, apply)');
select is((select coalesce(string_agg(fn, ', ' order by fn), '') from g108_aig1_fns
           where prosrc ~* '(insert\s+into|update|delete\s+from|truncate(\s+table)?)\s+public\.(billable_facts|billing_rules|tariff_rates|quality_holds|safety_signals|signal_[a-z_]+|exception_rules|exception_rule_overrides)\M'),
  '',
  '#824: no function that reads the AIG1 ledger or applies a confirmed value writes billing or safety-signal tables');

-- (5) no AI model registered --------------------------------------------------------------------------------------------
select is((select count(*)::int from public.ai_agent_definitions where kind = 'ai'), 0,
  '#824 / D-35 rule A: no agent of kind ai is registered (synthetic rule agents only)');

select * from finish();
rollback;
