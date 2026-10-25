-- CGR-33 (Clinical Governance Report 2026-10-23 19:00, advisory S2; Safety Risk Register BL-15, owner eng).
-- Guard for J5-C2 (0051, ADR-062): a billing fact's order basis is reconstructed backwards from the live case row
-- through `audit_events`. That is correct only while
--   (1) the `audit_cases` trigger records EVERY insert and update of `medical_order_status` and
--       `medical_order_valid_until` (after, for each row, no column list, enabled), in the {old, new} shape that
--       `private.case_order_as_of` reads; and
--   (2) `audit_events` stays append-only (update, delete and truncate refused also for the table owner; app roles
--       can only read).
-- A later migration that re-creates `audit_cases` without one of the two columns (it was re-created in 0010 and 0013)
-- or weakens (2) fails this file. Test only: no rule, no schema change.
-- Users: none needed (table owner). Case …208 from the seed. All data synthetic.
begin;
create extension if not exists pgtap with schema extensions;

select plan(21);

create temp view t_audit_cases as
select t.tgtype, t.tgenabled, t.tgattr, t.tgfoid,
       string_to_array(encode(t.tgargs, 'escape'), '\000') as args
from pg_trigger t
where t.tgrelid = 'public.cases'::regclass and t.tgname = 'audit_cases' and not t.tgisinternal;

-- (1) The trigger: present, the audit writer, after insert or update, for each row, every column, enabled -------------
select has_trigger('public', 'cases', 'audit_cases', 'audit_cases exists on public.cases');
select trigger_is('public', 'cases', 'audit_cases', 'private', 'write_audit_event',
  'audit_cases calls private.write_audit_event');
select ok((select (tgtype & 1) = 1 from t_audit_cases), 'audit_cases fires for each row');
select ok((select (tgtype & 2) = 0 from t_audit_cases), 'audit_cases fires after the write (the row as stored)');
select ok((select (tgtype & 4) = 4 from t_audit_cases), 'audit_cases fires on insert');
select ok((select (tgtype & 16) = 16 from t_audit_cases), 'audit_cases fires on update');
select ok((select coalesce(array_length(tgattr::int2[], 1), 0) = 0 from t_audit_cases),
  'audit_cases has no UPDATE OF column list (every update is seen)');
select ok((select tgenabled in ('O', 'A') from t_audit_cases), 'audit_cases is enabled');
select ok((select 'medical_order_status' = any(args) from t_audit_cases),
  'audit_cases records medical_order_status');
select ok((select 'medical_order_valid_until' = any(args) from t_audit_cases),
  'audit_cases records medical_order_valid_until');

-- (1) Behaviour: an order edit leaves one audit row with both columns as {old, new}, read back by case_order_as_of -----
create temp table t_before as
select (select coalesce(max(id), 0) from public.audit_events) as id,
       c.medical_order_status as status, c.medical_order_valid_until as valid_until
from public.cases c where c.id = '00000000-0000-4000-a000-000000000208';
update public.cases
set medical_order_status = 'present', medical_order_valid_until = (private.now() at time zone 'Europe/Zurich')::date + 400
where id = '00000000-0000-4000-a000-000000000208';
update public.cases
set medical_order_status = 'requested', medical_order_valid_until = null
where id = '00000000-0000-4000-a000-000000000208';

select is(
  (select count(*)::int from public.audit_events a, t_before b
   where a.id > b.id and a.table_name = 'cases' and a.entity_id = '00000000-0000-4000-a000-000000000208'
     and a.changed ? 'medical_order_valid_until'),
  2, 'each order edit is audited');
select is(
  (select a.changed -> 'medical_order_valid_until' ->> 'new' from public.audit_events a, t_before b
   where a.id > b.id and a.table_name = 'cases' and a.entity_id = '00000000-0000-4000-a000-000000000208'
     and a.changed ? 'medical_order_valid_until'
   order by a.id limit 1),
  ((private.now() at time zone 'Europe/Zurich')::date + 400)::text, 'the end date is recorded as {old, new}');
select is(
  (select a.changed -> 'medical_order_status' ->> 'old' from public.audit_events a, t_before b
   where a.id > b.id and a.table_name = 'cases' and a.entity_id = '00000000-0000-4000-a000-000000000208'
     and a.changed ? 'medical_order_status'
   order by a.id desc limit 1),
  'present', 'the status is recorded as {old, new}');
-- Both edits share this transaction's private.now(): read at private.now(), the order is the one before the first edit (the earliest
-- audited change at or after the instant holds it as `old`); read just after, it is the live order.
select is(
  (select o.valid_until from private.case_order_as_of('00000000-0000-4000-a000-000000000208', private.now()) o),
  (select valid_until from t_before), 'case_order_as_of at the edit instant reads the end date before the edits');
select is(
  (select o.status from private.case_order_as_of('00000000-0000-4000-a000-000000000208', private.now()) o),
  (select status from t_before), 'case_order_as_of at the edit instant reads the status before the edits');
select is(
  (select o.status from private.case_order_as_of('00000000-0000-4000-a000-000000000208',
     private.now() + interval '1 second') o),
  'requested', 'case_order_as_of after the edits reads the live order');

-- (2) audit_events stays append-only, also for the table owner ---------------------------------------------------------
select throws_ok(
  $$update public.audit_events set command = command where id = (select max(id) from public.audit_events)$$,
  '42501', 'audit_events is append-only', 'update of an audit row is refused');
select throws_ok(
  $$delete from public.audit_events where id = (select max(id) from public.audit_events)$$,
  '42501', 'audit_events is append-only', 'delete of an audit row is refused');
select throws_ok($$truncate public.audit_events$$,
  '42501', 'audit_events is append-only', 'truncate of audit_events is refused');
select table_privs_are('public', 'audit_events', 'authenticated', array['SELECT'],
  'app users can only read audit_events');
select table_privs_are('public', 'audit_events', 'anon', array[]::text[], 'anon has no privilege on audit_events');

select * from finish();
rollback;
