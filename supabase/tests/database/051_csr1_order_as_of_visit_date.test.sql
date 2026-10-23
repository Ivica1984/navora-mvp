-- CSR1, part 10 (migration 0051, ADR-062): J5-C2 (PO 2026-10-23 16:55; strict default until D-22, `legal`), the
-- criterion and pgTAP (a)-(d) in `docs/agents/briefs/CSR1.md` (review 16:55).
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · coach …901 (lifts holds) · ops …904 (intake edits).
-- Case …208. All data synthetic. Every visit, report and fact goes through the real commands. Steps "as the table
-- owner": the intake edits of the case's order and payer (the audit trigger records them whichever command writes
-- them), and dating those audit rows to the day they stand for (a test transaction has one `now()`), and, for the
-- catch-up, making one fact look as if it was built before 0051.
-- Timeline (D = current_date - 10, times 12:00 Europe/Zurich): D order `present` without an end date; visit a1 and c1 on
-- D+1; D+3 the end date D+30 is entered; visit b1 on D+5; D+7 the end date is removed again; generation today.
begin;
create extension if not exists pgtap with schema extensions;

select plan(35);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

create temp table d0 as select (current_date - 10) as d;
grant select on d0 to authenticated;
create function pg_temp.day(k int) returns date language sql as $$ select d + k from d0 $$;
create function pg_temp.noon(k int) returns timestamptz language sql as $$
  select ((pg_temp.day(k))::timestamp + interval '12 hours') at time zone 'Europe/Zurich' $$;

-- As the table owner: an intake edit of the order, dated to the moment it stands for.
create function pg_temp.set_order(p_status text, p_until date, p_at timestamptz) returns void language plpgsql as $$
declare before bigint := (select coalesce(max(id), 0) from public.audit_events);
begin
  update public.cases set medical_order_status = p_status, medical_order_valid_until = p_until
  where id = '00000000-0000-4000-a000-000000000208';
  alter table public.audit_events disable trigger audit_events_no_update_delete;
  update public.audit_events set occurred_at = p_at
  where id > before and table_name = 'cases' and entity_id = '00000000-0000-4000-a000-000000000208';
  alter table public.audit_events enable trigger audit_events_no_update_delete;
end $$;

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
create temp table fx (name text primary key, id uuid not null, k int not null, t time not null, a int, b int, c int);
grant select on fx to authenticated;
insert into fx values
  ('a1', 'a0510000-0000-4000-8000-000000000001', 1, '07:00', 0, 30, 0),   -- (a), then (c)
  ('c1', 'a0510000-0000-4000-8000-000000000002', 1, '08:00', 0, 30, 0),   -- CGR-29 build
  ('b1', 'a0510000-0000-4000-8000-000000000003', 5, '07:00', 0, 30, 0),   -- (b), then (d)
  ('e1', 'a0510000-0000-4000-8000-000000000004', 5, '08:00', 0, 30, 0);   -- catch-up of a fact built before 0051

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.day(f.k), f.t, f.t + interval '30 minutes', false, 'planned',
       f.a, f.b, f.c, '00000000-0000-4000-a000-000000000902'
from fx f;
-- Payer basis (read live, J5-C1): KVG with an insurer in a canton with rates.
update public.cases set insurer_name = 'Testkasse', insurance_type = 'KVG', residence_canton = 'BE',
                        residence_municipality = 'Teststadt'
  where id = '00000000-0000-4000-a000-000000000208';
-- As the table owner: the seeded case was taken on before D (its audit rows are dated D-2).
alter table public.audit_events disable trigger audit_events_no_update_delete;
update public.audit_events set occurred_at = pg_temp.noon(-2)
 where table_name = 'cases' and entity_id = '00000000-0000-4000-a000-000000000208';
alter table public.audit_events enable trigger audit_events_no_update_delete;
select pg_temp.set_order(null, null, pg_temp.noon(-1));
select pg_temp.set_order('present', null, pg_temp.noon(0));

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.vday(n text) returns date language sql as $$ select pg_temp.day(k) from fx where name = n $$;
create function pg_temp.latest_report(n text) returns uuid language sql as $$
  select r.id from public.visit_reports r
  where r.visit_id = pg_temp.vid(n) and r.status <> 'withdrawn'
    and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn') $$;
create function pg_temp.shown_hash(n text) returns text language sql as $$
  select f.snapshot_hash from public.field_reports(pg_temp.vday(n)) f where f.visit_id = pg_temp.vid(n) $$;
create function pg_temp.started_event(n text) returns bigint language sql as $$
  select e.id from public.visit_events e where e.visit_id = pg_temp.vid(n) and e.event_type = 'started' $$;
create function pg_temp.head_fact(n text) returns public.billable_facts language sql as $$
  select f.* from public.billable_facts f
  where f.visit_id = pg_temp.vid(n) and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id) $$;
create function pg_temp.key(n int) returns uuid language sql as $$
  select ('a0511000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.run_and_sign(n text, k int) returns void language plpgsql as $$
declare r jsonb;
begin
  perform public.start_visit(pg_temp.vid(n), pg_temp.key(1000 + k * 10 + 1));
  perform public.complete_visit(pg_temp.vid(n), pg_temp.key(1000 + k * 10 + 2));
  perform public.correct_visit_time(pg_temp.started_event(n), now() - interval '30 minutes', 'Synthetisch: Start nachgetragen',
                                    pg_temp.key(1000 + k * 10 + 5));
  r := public.create_report_draft(pg_temp.vid(n), 'Synthetisch: Verlauf ruhig', pg_temp.key(1000 + k * 10 + 3));
  perform public.sign_report((r ->> 'report_id')::uuid, pg_temp.shown_hash(n), pg_temp.key(1000 + k * 10 + 4));
end $$;

-- Surface -----------------------------------------------------------------------------------------------------------
select ok(not has_function_privilege('authenticated', 'private.case_order_as_of(uuid, timestamptz)', 'execute')
          and not has_function_privilege('authenticated', 'private.order_basis_as_of(uuid, date, integer)', 'execute')
          and not has_function_privilege('authenticated', 'private.rederive_fact_order(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'private.order_cutoff(date)', 'execute'),
  'the J5-C2 helpers are internal');
select ok(has_column_privilege('authenticated', 'public.billable_facts', 'order_as_of', 'select')
          and not has_column_privilege('authenticated', 'public.billable_facts', 'order_as_of', 'update')
          and not has_table_privilege('authenticated', 'public.billable_facts', 'insert'),
  'facts carry their cut-off; app users read, never write');

-- The cut-off: the first instant of the next day in Europe/Zurich -------------------------------------------------------
select is(private.order_cutoff('2026-07-01'), '2026-07-01 22:00:00+00'::timestamptz, 'summer: 24:00 CEST is 22:00 UTC');
select is(private.order_cutoff('2026-10-25'), '2026-10-25 23:00:00+00'::timestamptz, 'the day summer time ends: 24:00 CET');
select is(private.order_cutoff('2026-12-31'), '2026-12-31 23:00:00+00'::timestamptz, 'winter');

-- The order as recorded, from the audited history -----------------------------------------------------------------------
select pg_temp.set_order('present', pg_temp.day(30), pg_temp.noon(3));   -- D+3: end date entered
select is((select status || '/' || coalesce(valid_until::text, '-') from private.case_order_as_of('00000000-0000-4000-a000-000000000208',
          pg_temp.noon(-1) + interval '1 hour')), null, 'before the first order: nothing on file');
select is((select status || '/' || coalesce(valid_until::text, '-') from private.case_order_as_of('00000000-0000-4000-a000-000000000208',
          private.order_cutoff(pg_temp.day(1)))), 'present/-', 'end of D+1: present without an end date');
select is((select status || '/' || coalesce(valid_until::text, '-') from private.case_order_as_of('00000000-0000-4000-a000-000000000208',
          pg_temp.noon(3))), 'present/-', 'a change at the cut-off instant itself does not count (only changes before it)');
select is((select status || '/' || coalesce(valid_until::text, '-') from private.case_order_as_of('00000000-0000-4000-a000-000000000208',
          pg_temp.noon(3) + interval '1 second')), 'present/' || pg_temp.day(30), 'one second after the change: on file');

-- (a) Visit on D+1 with an order without end date; end date entered on D+3; first generation today: not billable ---------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('a1', 1);
select ok(public.generate_billable_facts(pg_temp.vday('a1')) >= 1, 'a1: the fact is built (today, long after D+3)');
reset role;
select ok((select not f.billable and f.cause = 'report' and f.order_basis = 'b_without_valid_order'
                  and f.reasons @> array['b_without_valid_order', 'order_validity_missing', 'order_recorded_after_visit']
                  and not ('order_expired' = any (f.reasons))
           from pg_temp.head_fact('a1') f),
  '(a) not billable: order_validity_missing (and order_recorded_after_visit), although the live order is valid now');
select ok((select f.order_as_of = private.order_cutoff(pg_temp.day(1))
                  and f.order_recorded = jsonb_build_object('status', 'present', 'valid_until', null)
           from pg_temp.head_fact('a1') f),
  '(a) the fact records the cut-off and the order it used');

-- (b) Visit on D+5, the order valid that day: billable, whenever the fact is built ---------------------------------------
select pg_temp.set_order('present', null, pg_temp.noon(7));   -- D+7: end date removed again (live: no end date)
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('b1', 2);
select ok(public.generate_billable_facts(pg_temp.vday('b1')) >= 1, 'b1: the fact is built today, after the D+7 change');
reset role;
select ok((select f.billable and f.reasons = '{}' and f.order_basis = 'with_order'
                  and f.order_recorded = jsonb_build_object('status', 'present', 'valid_until', pg_temp.day(30))
           from pg_temp.head_fact('b1') f),
  '(b) billable with the order as of D+5; the later removal of the end date does not reach it');
select is((select basis || ':' || array_to_string(reasons, ',') from private.order_basis_as_of('00000000-0000-4000-a000-000000000208',
          pg_temp.day(5), 30)), 'with_order:', '(b) the same basis whenever it is read');
select is((select basis || ':' || array_to_string(reasons, ',') from private.order_basis_as_of('00000000-0000-4000-a000-000000000208',
          pg_temp.day(1), 30)), 'b_without_valid_order:b_without_valid_order,order_validity_missing',
  'D+1 read today: the live order has no end date either, so order_recorded_after_visit is not claimed');

-- (c) Correction v2 of (a) signed final after the order fix: still not billable -------------------------------------------
select pg_temp.set_order('present', pg_temp.day(30), pg_temp.noon(8));   -- live order valid again
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('a1'), 'Synthetisch: Massnahme präzisiert', null, pg_temp.key(31)) ->> 'result',
  'ok', 'a1: the performer opens a correction');
select is(public.correct_visit_time(pg_temp.started_event('a1'), now() - interval '40 minutes', 'Synthetisch: Start früher',
                                    pg_temp.key(32)), 'ok', 'and corrects the start');
select is(public.sign_report(pg_temp.latest_report('a1'), pg_temp.shown_hash('a1'), pg_temp.key(33)) ->> 'result', 'ok',
  'and signs: version 2 is final');
select ok(public.generate_billable_facts(pg_temp.vday('a1')) >= 1, 'version 2''s fact is built');
reset role;
select ok((select f.report_id = pg_temp.latest_report('a1') and f.cause = 'report' and not f.billable
                  and f.reasons @> array['order_validity_missing', 'order_recorded_after_visit']
                  and f.order_as_of = private.order_cutoff(pg_temp.day(1))
           from pg_temp.head_fact('a1') f),
  '(c) version 2''s fact is still not billable (order as of D+1)');

-- CGR-29's build at the last lift reads the same order ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('c1', 3);
select ok(public.generate_billable_facts(pg_temp.vday('c1')) >= 1, 'c1: version 1''s fact is built before the hold');
select is(public.set_quality_hold(pg_temp.vid('c1'), 'Synthetisch: Leistung strittig', pg_temp.key(41)), 'ok', 'c1: a hold is set');
select is(public.correct_report(pg_temp.latest_report('c1'), 'Synthetisch: Start früher', null, pg_temp.key(42)) ->> 'result', 'ok',
  'during the hold a correction is opened');
select is(public.correct_visit_time(pg_temp.started_event('c1'), now() - interval '45 minutes', 'Synthetisch: Start früher',
                                    pg_temp.key(43)), 'ok', 'its time is corrected');
select is(public.sign_report(pg_temp.latest_report('c1'), pg_temp.shown_hash('c1'), pg_temp.key(44)) ->> 'result', 'ok',
  'and signed during the hold');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.lift_quality_hold((select h.id from public.quality_holds h where h.visit_id = pg_temp.vid('c1')),
  'Synthetisch: geklärt', pg_temp.key(45)), 'ok', 'the coach lifts the hold');
reset role;
select ok((select f.report_id = pg_temp.latest_report('c1') and f.cause = 'report' and not f.billable
                  and f.reasons @> array['order_validity_missing', 'order_recorded_after_visit']
                  and f.created_by = '00000000-0000-4000-a000-000000000901'
           from pg_temp.head_fact('c1') f),
  'CGR-29: the fact built at the lift reads the order as of D+1 too');

-- (d) J5-C1 unchanged: a payer correction re-derives the payer only, the order part is copied ----------------------------
create temp table b1_before as select (pg_temp.head_fact('b1')).*;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
update public.cases set insurance_type = 'IV' where id = '00000000-0000-4000-a000-000000000208';   -- as the table owner
select ok((select f.cause = 'basis_changed' and not f.billable and f.reasons = array['payer_not_modelled']
                  and f.supersedes_id = (select id from b1_before)
                  and f.order_basis = 'with_order'
                  and f.order_as_of = (select order_as_of from b1_before)
                  and f.order_recorded = (select order_recorded from b1_before)
                  and f.created_by = '00000000-0000-4000-a000-000000000904'
           from pg_temp.head_fact('b1') f),
  '(d) IV: payer_not_modelled; the order basis, cut-off and order used are copied');
update public.cases set insurance_type = 'KVG' where id = '00000000-0000-4000-a000-000000000208';
select ok((select f.cause = 'basis_changed' and f.billable and f.reasons = '{}' from pg_temp.head_fact('b1') f),
  '(d) KVG again: billable again');

-- Catch-up: a fact built before 0051 from a later order is re-derived by the next generation --------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('e1', 4);
select ok(public.generate_billable_facts(pg_temp.vday('e1')) >= 1, 'e1: fact built');
reset role;
-- As the table owner: make e1's fact look like a 0043 fact built from the live order (here: the order as of D+5 is
-- valid, so take a1 instead: its visit date D+1 had no valid order).
create temp table pre as select (pg_temp.head_fact('a1')).*;
alter table public.billable_facts disable trigger billable_facts_immutable;
update public.billable_facts set order_as_of = null, order_recorded = null, order_basis = 'with_order',
                                 reasons = '{}', billable = true
 where id = (select id from pre);
alter table public.billable_facts enable trigger billable_facts_immutable;
select ok((select f.billable and f.order_as_of is null from pg_temp.head_fact('a1') f), 'before: a billable pre-0051 fact');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok(public.generate_billable_facts(pg_temp.vday('a1')) >= 1, 'the next generation catches up');
reset role;
select ok((select f.cause = 'basis_changed' and not f.billable and f.supersedes_id = (select id from pre)
                  and f.report_id = (select report_id from pre) and f.snapshot_hash = (select snapshot_hash from pre)
                  and f.reasons @> array['b_without_valid_order', 'order_validity_missing', 'order_recorded_after_visit']
                  and f.order_as_of = private.order_cutoff(pg_temp.day(1))
                  and f.created_by = '00000000-0000-4000-a000-000000000902'
           from pg_temp.head_fact('a1') f),
  'J5-C2 catch-up: re-derived from the same snapshot with the order as of D+1 (basis_changed)');
select is((select count(*)::int from public.billable_facts f where f.visit_id = pg_temp.vid('e1')), 1,
  'a fact built since 0051 is never re-derived by the catch-up');

select * from finish();
rollback;
