-- CSR1 part 6: J5's clinical-gate findings (Clinical Governance Report 2026-10-22 22:30 and 23:05; migration 0043,
-- ADR-054). CGR-03 (J5 part): billing reads the signed snapshot. CGR-07: no bill on a missing, expired or unmodelled
-- basis. CGR-08: unvalidated reference data is marked. BL-8: a later hold makes the fact not billable, lifting restores
-- it. BL-9: working-time facts follow the signed correction.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · coach …901 (lifts holds) · anon.
-- Case …208 (Testteam Nord). All visit, report and hold steps go through the real commands. Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(49);

create function pg_temp.shown_hash(rid uuid) returns text language sql as $f$
  select f.snapshot_hash from public.visit_reports r join public.care_visits v on v.id = r.visit_id
  cross join lateral public.field_reports(v.visit_date) f where r.id = rid and f.report_id = rid
$f$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

create temp table fx (name text primary key, id uuid not null);
grant select on fx to authenticated;
insert into fx values
  ('s1', 'a0430000-0000-4000-8000-000000000001'),   -- signed snapshot vs live drift; later held and lifted (BL-8)
  ('o1', 'a0430000-0000-4000-8000-000000000002'),   -- order present without end date
  ('o2', 'a0430000-0000-4000-8000-000000000003'),   -- order expired (A/C minutes)
  ('p1', 'a0430000-0000-4000-8000-000000000004'),   -- insurance type private
  ('p2', 'a0430000-0000-4000-8000-000000000005'),   -- insurance type missing
  ('b1', 'a0430000-0000-4000-8000-000000000006'),   -- B with a valid order, KVG: billable (control)
  ('c1', 'a0430000-0000-4000-8000-000000000007'),   -- report corrected with changed times (BL-9)
  ('h0', 'a0430000-0000-4000-8000-000000000008');   -- held before any fact
create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.started_event(n text) returns bigint language sql as $$
  select e.id from public.visit_events e where e.visit_id = pg_temp.vid(n) and e.event_type = 'started' $$;
create function pg_temp.latest_report(n text) returns uuid language sql as $$
  select r.id from public.visit_reports r
  where r.visit_id = pg_temp.vid(n) and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id) $$;
create function pg_temp.head_fact(n text) returns public.billable_facts language sql as $$
  select f.* from public.billable_facts f
  where f.visit_id = pg_temp.vid(n) and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id) $$;
create function pg_temp.head_wt(n text) returns public.working_time_facts language sql as $$
  select w.* from public.working_time_facts w
  where w.visit_id = pg_temp.vid(n) and not exists (select 1 from public.working_time_facts s where s.supersedes_id = w.id) $$;
-- start, complete, set the start 30 minutes earlier (F3), draft and sign (registered nurse: final)
create function pg_temp.run_and_sign(n text, k int) returns void language plpgsql as $$
declare r jsonb;
begin
  perform public.start_visit(pg_temp.vid(n), ('a0431000-0000-4000-8000-' || lpad((k * 10 + 1)::text, 12, '0'))::uuid);
  perform public.complete_visit(pg_temp.vid(n), ('a0431000-0000-4000-8000-' || lpad((k * 10 + 2)::text, 12, '0'))::uuid);
  perform public.correct_visit_time(pg_temp.started_event(n), private.now() - interval '30 minutes', 'Start zu spät getippt',
                                    ('a0431000-0000-4000-8000-' || lpad((k * 10 + 3)::text, 12, '0'))::uuid);
  r := public.create_report_draft(pg_temp.vid(n), null, ('a0431000-0000-4000-8000-' || lpad((k * 10 + 4)::text, 12, '0'))::uuid);
  perform public.sign_report((r ->> 'report_id')::uuid, pg_temp.shown_hash((r ->> 'report_id')::uuid),
                             ('a0431000-0000-4000-8000-' || lpad((k * 10 + 5)::text, 12, '0'))::uuid);
end $$;

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date, x.t, x.t + interval '30 minutes', false, 'planned', x.a, x.b, x.c
from fx f join (values
  ('s1', time '05:00', 20, 0, 10), ('o1', time '05:30', 20, 0, 10), ('o2', time '06:00', 20, 0, 10),
  ('p1', time '06:30', 20, 0, 10), ('p2', time '07:00', 20, 0, 10), ('b1', time '07:30', 0, 30, 0),
  ('c1', time '08:00', 20, 0, 10), ('h0', time '08:30', 20, 0, 10)
) as x(name, t, a, b, c) on x.name = f.name;
update public.cases set insurer_name = 'Testkasse', insurance_type = 'KVG', residence_canton = 'BE',
                        residence_municipality = 'Teststadt', medical_order_status = null, medical_order_valid_until = null
  where id = '00000000-0000-4000-a000-000000000208';

-- CGR-08: the reference data says it is not validated ------------------------------------------------------------------
select ok((select bool_and(not validated and validation_note like '%nicht validiert (CGR-08)%') from public.tariff_rates),
  'CGR-08: every seeded tariff rate is marked unvalidated, with the note');
select ok((select bool_and(not validated and validation_note like '%nicht validiert (CGR-08)%') from public.billing_rules),
  'CGR-08: the seeded minimum rule is marked unvalidated, with the note');
select ok(not has_function_privilege('authenticated', 'private.snapshot_times(jsonb)', 'execute')
          and not has_function_privilege('anon', 'private.snapshot_times(jsonb)', 'execute'),
  'the snapshot time helper is internal');

-- CGR-03: the fact reads the signed snapshot, not the live times or the live plan ----------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('s1', 1);
select is((select status from public.visit_reports where id = pg_temp.latest_report('s1')), 'final', 's1 is signed and final');
reset role;
-- After signature the live data drifts (as the table owner, bypassing every command): a later start and a new plan.
insert into public.visit_time_corrections (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key)
values ('00000000-0000-4000-b000-000000000011', pg_temp.vid('s1'), '00000000-0000-4000-a000-000000000101', pg_temp.started_event('s1'),
        private.now() - interval '60 minutes', 'Synthetisch: Abweichung nach Unterschrift', '00000000-0000-4000-a000-000000000902',
        'a0432000-0000-4000-8000-000000000001');
update public.care_visits set planned_minutes_a = 50 where id = pg_temp.vid('s1');
select is((select care_minutes from private.visit_times(pg_temp.vid('s1'))), 60, 'the live times now say 60 minutes');
select is((select care_minutes_exact from private.snapshot_times((select snapshot from public.visit_reports where id = pg_temp.latest_report('s1')))),
  30.00::numeric, 'the signed snapshot says 30 minutes');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date) >= 1, true, 'generation creates the fact');
reset role;
select ok((select measured_care_minutes = 30.00 and actual_care_minutes = 30 and planned_minutes_a = 20 and planned_minutes_c = 10
                  and billable_minutes_a = 20 and billable_minutes_c = 10 and rule_version = 'J5-v3' and cause = 'report'
           from pg_temp.head_fact('s1')),
  'CGR-03: minutes and plan come from the signed snapshot (30 measured, A 20, C 10), not the live 60 minutes or A 50');
select is((select snapshot_hash from pg_temp.head_fact('s1')),
  (select private.report_snapshot_hash(snapshot) from public.visit_reports where id = pg_temp.latest_report('s1')),
  'the fact names the hash of the signed snapshot it was built from');
select ok((select billable and reasons = '{}' from pg_temp.head_fact('s1')), 'KVG, no order, A/C minutes: billable');
select ok((select 'reference_not_validated' = any (warnings) from pg_temp.head_fact('s1')),
  'CGR-08: the fact carries the warning that its rate and minimum are not validated');
select ok((select care_minutes = 30 and source = 'signed_snapshot' and report_id = pg_temp.latest_report('s1')
           from pg_temp.head_wt('s1')), 'BL-9: the working-time fact comes from the same signed snapshot');

-- CGR-07: missing, expired or unmodelled basis -------------------------------------------------------------------------------
update public.cases set medical_order_status = 'present', medical_order_valid_until = null where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('o1', 2);
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 1, 'one new fact (o1)');
reset role;
select ok((select not billable and 'order_validity_missing' = any (reasons) and order_basis = 'with_order' from pg_temp.head_fact('o1')),
  'CGR-07: an order without an end date is not billable (order_validity_missing), also for A and C minutes');

update public.cases set medical_order_valid_until = (private.now() at time zone 'Europe/Zurich')::date - 1 where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('o2', 3);
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 1, 'one new fact (o2)');
reset role;
select ok((select not billable and reasons = array['order_expired'] from pg_temp.head_fact('o2')),
  'CGR-07: an expired order stops A and C minutes too (order_expired)');

update public.cases set medical_order_valid_until = (private.now() at time zone 'Europe/Zurich')::date + 30, insurance_type = 'private' where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('p1', 4);
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 1, 'one new fact (p1)');
reset role;
select ok((select not billable and reasons = array['payer_not_modelled'] and payer_chain ->> 'insurance_type' = 'private'
           from pg_temp.head_fact('p1')), 'CGR-07: a case that is not KVG is not estimated (payer_not_modelled)');

update public.cases set insurance_type = null where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('p2', 5);
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 1, 'one new fact (p2)');
reset role;
select ok((select not billable and 'payer_not_modelled' = any (reasons) from pg_temp.head_fact('p2')),
  'CGR-07: a missing insurance type is not modelled either');
-- Checked before the payer is set back to KVG: since 0049 (J5-C1) that correction re-derives every fact of the case
-- from its signed snapshot, so payer_not_modelled disappears from the preview afterwards (pgTAP 049 covers it).
select ok((select not_billable @> '[{"reasons": ["order_validity_missing"]}]'::jsonb
                  and not_billable @> '[{"reasons": ["order_expired"]}]'::jsonb
                  and not_billable @> '[{"reasons": ["payer_not_modelled"]}]'::jsonb
           from public.billing_preview((private.now() at time zone 'Europe/Zurich')::date) where team_id = '00000000-0000-4000-a000-000000000101'),
  'CGR-07: the preview lists the three new reasons');

update public.cases set insurance_type = 'KVG' where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('b1', 6);
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 1, 'one new fact (b1)');
reset role;
select ok((select billable and order_basis = 'with_order' and billable_minutes_b = 30 and reasons = '{}' from pg_temp.head_fact('b1')),
  'control: B minutes with a dated, valid order and KVG stay billable');

-- CGR-08 in the preview ------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select reference_validated from public.billing_preview((private.now() at time zone 'Europe/Zurich')::date) where team_id = '00000000-0000-4000-a000-000000000101'),
  false, 'CGR-08: the preview says the reference data is not validated');
reset role;

-- BL-8: a hold set after the fact makes it not billable; lifting restores it ----------------------------------------------------
create temp table s1_before as select (pg_temp.head_fact('s1')).id as fact_id, (select billing.billable_visits
  from public.billing_preview((private.now() at time zone 'Europe/Zurich')::date) billing where billing.team_id = '00000000-0000-4000-a000-000000000101') as visits,
  (select count(*)::int from public.billable_facts where visit_id = pg_temp.vid('s1')) as facts;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_quality_hold(pg_temp.vid('s1'), 'Synthetisch: Leistung nachträglich strittig', 'a0432000-0000-4000-8000-000000000010'),
  'ok', 'the nurse sets a hold on the billed visit');
reset role;
select ok((select not f.billable and f.cause = 'quality_hold' and 'quality_hold' = any (f.reasons)
                  and f.hold_id = (select h.id from public.quality_holds h where h.visit_id = pg_temp.vid('s1'))
                  and f.supersedes_id = (select fact_id from s1_before)
           from pg_temp.head_fact('s1') f),
  'BL-8: the hold appends a not-billable fact (quality_hold) that supersedes the billable one');
select ok((select billable and cause in ('report', 'basis_changed') from public.billable_facts where id = (select fact_id from s1_before)),
  'BL-8: the earlier fact is kept unchanged (history)');
select is((select billable_visits from public.billing_preview((private.now() at time zone 'Europe/Zurich')::date) where team_id = '00000000-0000-4000-a000-000000000101'),
  (select visits - 1 from s1_before), 'the preview stops counting the held visit');
select ok((select not_billable @> jsonb_build_array(jsonb_build_object('visit_id', pg_temp.vid('s1'), 'reasons', array['quality_hold']))
           from public.billing_preview((private.now() at time zone 'Europe/Zurich')::date) where team_id = '00000000-0000-4000-a000-000000000101'),
  'the preview lists it as quality_hold');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 0, 'no new fact while the hold is open');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.lift_quality_hold((select h.id from public.quality_holds h where h.visit_id = pg_temp.vid('s1')),
  'Synthetisch: geklärt', 'a0432000-0000-4000-8000-000000000011'), 'ok', 'the coach lifts the hold');
reset role;
select ok((select f.billable and f.cause = 'hold_lifted' and f.reasons = '{}' and f.measured_care_minutes = 30.00
                  and f.supersedes_id = (select x.id from public.billable_facts x where x.visit_id = f.visit_id and x.cause = 'quality_hold')
           from pg_temp.head_fact('s1') f),
  'BL-8: lifting the hold appends the earlier fact again, billable, after the hold fact');
select is((select count(*)::int from public.billable_facts where visit_id = pg_temp.vid('s1')), (select facts + 2 from s1_before),
  'BL-8: history kept: billable → held → billable again');
select is((select billable_visits from public.billing_preview((private.now() at time zone 'Europe/Zurich')::date) where team_id = '00000000-0000-4000-a000-000000000101'),
  (select visits from s1_before), 'the preview counts the visit again');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 0, 'generation stays idempotent after the lift');
reset role;

-- A hold before any fact: no fact is created, none while held ----------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('h0', 7);
select is(public.set_quality_hold(pg_temp.vid('h0'), 'Synthetisch: strittig vor Erfassung', 'a0432000-0000-4000-8000-000000000020'),
  'ok', 'a hold on a signed visit without a fact');
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 0, 'no fact for the held visit');
reset role;
select is((select count(*)::int from public.billable_facts where visit_id = pg_temp.vid('h0')), 0, 'the hold itself creates no fact');

-- BL-9 and CGR-03: a correction version with changed times ---------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('c1', 8);
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 1, 'one new fact (c1)');
create temp table c1_first as select (pg_temp.head_wt('c1')).id as wt_id, (pg_temp.head_fact('c1')).id as fact_id;
do $$ declare r jsonb; begin
  r := public.correct_report(pg_temp.latest_report('c1'), 'Startzeit war früher', null, 'a0432000-0000-4000-8000-000000000030');
  perform public.correct_visit_time(pg_temp.started_event('c1'), private.now() - interval '45 minutes', 'Start war früher',
                                    'a0432000-0000-4000-8000-000000000031');
  perform public.sign_report((r ->> 'report_id')::uuid, pg_temp.shown_hash((r ->> 'report_id')::uuid), 'a0432000-0000-4000-8000-000000000032');
end $$;
select is((select status from public.visit_reports where id = pg_temp.latest_report('c1')), 'final', 'the correction version is final');
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 1, 'the correction version yields one new fact');
reset role;
select ok((select f.measured_care_minutes = 45.00 and f.supersedes_id = (select fact_id from c1_first)
                  and f.report_id = pg_temp.latest_report('c1') from pg_temp.head_fact('c1') f),
  'CGR-03: the new fact takes the corrected minutes from the signed correction version and supersedes the old fact');
select ok((select w.care_minutes = 45 and w.supersedes_id = (select wt_id from c1_first) and w.report_id = pg_temp.latest_report('c1')
                  and w.source = 'signed_snapshot' from pg_temp.head_wt('c1') w),
  'BL-9: the working-time fact is replaced from the corrected snapshot and references the earlier one');
select is((select care_minutes from public.working_time_facts where id = (select wt_id from c1_first)), 30,
  'BL-9: the earlier working-time fact keeps its values (never updated)');
select is((select count(*)::int from public.working_time_facts where visit_id = pg_temp.vid('c1')), 2, 'two working-time facts for c1');

-- CGR-08: once reference data is validated, the preview says so ----------------------------------------------------------------
update public.tariff_rates set validated = true;
update public.billing_rules set validated = true;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select reference_validated from public.billing_preview((private.now() at time zone 'Europe/Zurich')::date) where team_id = '00000000-0000-4000-a000-000000000101'),
  true, 'CGR-08: validated reference data is shown as validated');
reset role;

-- Integrity --------------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ insert into public.billable_facts (organization_id, visit_id, case_id, team_id, report_id, visit_date, billable,
                                                      order_basis, payer_chain, tariff_versions, created_by)
                    values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), (private.now() at time zone 'Europe/Zurich')::date,
                            true, 'with_order', '{}', '{}', gen_random_uuid()) $$,
  '42501', null, 'app users cannot write billing facts directly');
reset role;
select throws_ok($$ update public.billable_facts set billable = true where cause = 'quality_hold' $$, '42501', null,
  'hold facts are immutable too');
select ok(position('J5-v3' in pg_get_functiondef('public.pilot_kpis(date)'::regprocedure)) > 0,
  'AN1 billable minutes per care minute reads the current rule (J5-v3)');

select * from finish();
rollback;
