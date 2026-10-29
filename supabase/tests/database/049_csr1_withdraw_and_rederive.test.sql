-- CSR1, part 9 (migration 0049, ADR-060): CGR-24-W (PO 2026-10-23 15:25), CGR-29 (`cra` 2026-10-23 14:30, advisory
-- S3) and J5-C1 (PO 2026-10-23 11:25), the criteria in `docs/agents/briefs/CSR1.md` and `docs/agents/briefs/J5.md`.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · coach …901 (lifts
-- holds) · ops …904 (operations, org A). Case …208. All data synthetic; every step goes through the real commands,
-- except the steps marked "as the table owner": ageing a correction draft past the signal threshold and the intake
-- edits of the case's payer and order (the J5-C1 trigger fires on the table, whichever command writes it).
begin;
create extension if not exists pgtap with schema extensions;

select plan(56);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.nobody() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
create temp table fx (name text primary key, id uuid not null, t time not null, resp uuid not null,
                      a int not null, b int not null, c int not null);
grant select on fx to authenticated;
insert into fx values
  ('w1', 'a0490000-0000-4000-8000-000000000001', '05:00', '00000000-0000-4000-a000-000000000902', 20, 0, 10),  -- withdraw
  ('w2', 'a0490000-0000-4000-8000-000000000002', '05:30', '00000000-0000-4000-a000-000000000906', 20, 0, 10),  -- care assistant
  ('w3', 'a0490000-0000-4000-8000-000000000003', '06:00', '00000000-0000-4000-a000-000000000902', 20, 0, 10),  -- first draft
  ('w4', 'a0490000-0000-4000-8000-000000000004', '06:30', '00000000-0000-4000-a000-000000000902', 20, 0, 10),  -- observation
  ('w5', 'a0490000-0000-4000-8000-000000000005', '06:45', '00000000-0000-4000-a000-000000000902', 20, 0, 10),  -- summary
  ('k1', 'a0490000-0000-4000-8000-000000000011', '07:00', '00000000-0000-4000-a000-000000000902', 20, 0, 10),  -- CGR-29
  ('j1', 'a0490000-0000-4000-8000-000000000021', '07:30', '00000000-0000-4000-a000-000000000902', 20, 0, 10),  -- J5-C1 payer
  ('j2', 'a0490000-0000-4000-8000-000000000022', '08:00', '00000000-0000-4000-a000-000000000902', 0, 30, 0);   -- J5-C1 order

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date, f.t, f.t + interval '30 minutes', false, 'planned', f.a, f.b, f.c, f.resp
from fx f;
-- Billing basis for the CGR-29 part: KVG, insurer, no order (A/C minutes are billable).
update public.cases set insurer_name = 'Testkasse', insurance_type = 'KVG', residence_canton = 'BE',
                        residence_municipality = 'Teststadt', medical_order_status = null, medical_order_valid_until = null
  where id = '00000000-0000-4000-a000-000000000208';

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
-- The latest version as every reader sees it since 0049: never a withdrawn one.
create function pg_temp.latest_report(n text) returns uuid language sql as $$
  select r.id from public.visit_reports r
  where r.visit_id = pg_temp.vid(n) and r.status <> 'withdrawn'
    and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn') $$;
-- OBS1-7 (0096): snapshot, signed_by and signed_at are not selectable through the table API, so the helper names the
-- columns it reads (it runs as the nurse too); signed_by is read as the table owner where a test asserts it.
create type pg_temp.report_row as (id uuid, version int, status text, supersedes_id uuid, withdrawn_by uuid, withdrawn_at timestamptz);
create function pg_temp.report_v(n text, v int) returns pg_temp.report_row language sql as $$
  select row(r.id, r.version, r.status, r.supersedes_id, r.withdrawn_by, r.withdrawn_at)::pg_temp.report_row
  from public.visit_reports r where r.visit_id = pg_temp.vid(n) and r.version = v $$;
create function pg_temp.shown_hash(n text) returns text language sql as $$
  select f.snapshot_hash from public.field_reports((private.now() at time zone 'Europe/Zurich')::date) f where f.visit_id = pg_temp.vid(n) $$;
create function pg_temp.started_event(n text) returns bigint language sql as $$
  select e.id from public.visit_events e where e.visit_id = pg_temp.vid(n) and e.event_type = 'started' $$;
create function pg_temp.head_fact(n text) returns public.billable_facts language sql as $$
  select f.* from public.billable_facts f
  where f.visit_id = pg_temp.vid(n) and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id) $$;
create function pg_temp.k(n int) returns uuid language sql as $$
  select ('a0491000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
-- start, complete, set the start 30 minutes earlier (F3), draft and sign as the current user
create function pg_temp.run_and_sign(n text, k int) returns void language plpgsql as $$
declare r jsonb;
begin
  perform public.start_visit(pg_temp.vid(n), pg_temp.k(1000 + k * 10 + 1));
  perform public.complete_visit(pg_temp.vid(n), pg_temp.k(1000 + k * 10 + 2));
  perform public.correct_visit_time(pg_temp.started_event(n), private.now() - interval '30 minutes', 'Synthetisch: Start nachgetragen',
                                    pg_temp.k(1000 + k * 10 + 5));
  r := public.create_report_draft(pg_temp.vid(n), 'Synthetisch: Verlauf ruhig', pg_temp.k(1000 + k * 10 + 3));
  perform public.sign_report((r ->> 'report_id')::uuid, pg_temp.shown_hash(n), pg_temp.k(1000 + k * 10 + 4));
end $$;
-- As the table owner: the open correction was opened `h` hours ago (the guard refuses any update of a version), and
-- the visit's earlier time corrections an hour before that.
create function pg_temp.age_correction(n text, h int) returns void language plpgsql as $$
begin
  alter table public.visit_reports disable trigger visit_reports_guard;
  update public.visit_reports set created_at = private.now() - make_interval(hours => h)
  where visit_id = pg_temp.vid(n) and status = 'draft' and supersedes_id is not null;
  alter table public.visit_reports enable trigger visit_reports_guard;
  -- The time correction made before version 1 was signed is older than the draft, as it would be in reality.
  alter table public.visit_time_corrections disable trigger visit_time_corrections_no_update_delete;
  update public.visit_time_corrections set created_at = private.now() - make_interval(hours => h + 1) where visit_id = pg_temp.vid(n);
  alter table public.visit_time_corrections enable trigger visit_time_corrections_no_update_delete;
end $$;

-- Surface -----------------------------------------------------------------------------------------------------------
select ok(has_function_privilege('authenticated', 'public.withdraw_report_correction(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.withdraw_report_correction(uuid, uuid)', 'execute'),
  'withdraw_report_correction: members yes, anon no');
select ok(not has_function_privilege('authenticated', 'private.rederive_fact_payer(uuid, uuid)', 'execute'),
  'the J5-C1 re-derivation is internal');
select ok(not has_column_privilege('authenticated', 'public.visit_reports', 'withdrawn_by', 'update')
          and not has_table_privilege('authenticated', 'public.visit_reports', 'update'),
  'no direct write on report versions');

-- CGR-24-W: an untouched correction draft is withdrawn by its performer ------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('w1', 1);
select is(public.correct_report(pg_temp.latest_report('w1'), 'Synthetisch: aus Versehen geöffnet', null, pg_temp.k(15)) ->> 'result',
  'ok', 'the performer opens a correction (version 2, draft)');
reset role;
select pg_temp.age_correction('w1', 25);
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() x
           where x.exception_type = 'report_correction_open' and x.entity_id = pg_temp.vid('w1')), 1,
  'before: the open correction raises report_correction_open (CGR-24)');
reset role;
select ok(not private.visit_facts_locked(pg_temp.vid('w1')), 'before: the draft unlocks the visit''s facts');

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.withdraw_report_correction((pg_temp.report_v('w1', 2)).id, pg_temp.k(16)),
  '{"result": "rejected", "reason": "not_performer"}'::jsonb, 'a colleague of the team cannot withdraw it');
reset role;
select is((pg_temp.report_v('w1', 2)).status, 'draft', 'nothing written');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.withdraw_report_correction((pg_temp.report_v('w1', 2)).id, pg_temp.k(17)) ->> 'result', 'ok',
  'the performer withdraws her untouched draft');
reset role;
select ok((select status = 'withdrawn' and withdrawn_by = '00000000-0000-4000-a000-000000000902' and withdrawn_at is not null
                  and (select r.signed_by from public.visit_reports r where r.id = x.id) is null
           from pg_temp.report_v('w1', 2) x),
  'the row is kept: status withdrawn, who and when');
select is((select r.version || '/' || r.status from public.visit_reports r where r.id = pg_temp.latest_report('w1')), '1/final',
  'the last final version (1) stays in force');
select ok(private.visit_facts_locked(pg_temp.vid('w1')), 'visit_facts_locked is true again');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_visit_time(pg_temp.started_event('w1'), private.now() - interval '40 minutes', 'Synthetisch: nach Rückzug',
                                    pg_temp.k(18)), 'rejected', 'a time correction is refused again (locked)');
select is((select f.version || '/' || f.status from public.field_reports((private.now() at time zone 'Europe/Zurich')::date) f where f.visit_id = pg_temp.vid('w1')), '1/final',
  '/field shows the final version again');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.operations_exceptions() x
           where x.exception_type = 'report_correction_open' and x.entity_id = pg_temp.vid('w1')), 0,
  'report_correction_open ends');
reset role;
select is((select count(*)::int from public.audit_events a
           where a.table_name = 'visit_reports' and a.entity_id = (pg_temp.report_v('w1', 2)).id
             and a.command = 'withdraw_report_correction' and a.idempotency_key = pg_temp.k(17)
             and a.actor_id = '00000000-0000-4000-a000-000000000902'), 1,
  'audit: one row with the command, the key and the actor');

-- Idempotent
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.withdraw_report_correction((pg_temp.report_v('w1', 2)).id, pg_temp.k(17)) ->> 'result', 'duplicate',
  'the same key again: duplicate');
select is(public.withdraw_report_correction((pg_temp.report_v('w1', 2)).id, pg_temp.k(19)),
  jsonb_build_object('result', 'ok', 'report_id', (pg_temp.report_v('w1', 2)).id, 'already_withdrawn', true),
  'a second call with a new key: the same result, nothing written');
reset role;
select is((select count(*)::int from public.audit_events a
           where a.table_name = 'visit_reports' and a.entity_id = (pg_temp.report_v('w1', 2)).id
             and a.command = 'withdraw_report_correction'), 1, 'still one audit row');
select throws_ok($$ update public.visit_reports set status = 'draft', withdrawn_by = null, withdrawn_at = null
                    where visit_id = 'a0490000-0000-4000-8000-000000000001' and version = 2 $$,
  '42501', null, 'a withdrawn version is immutable, even for the table owner');

-- A new correction later: next free number, supersedes version 1
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('w1'), 'Synthetisch: Startzeit korrigieren', null, pg_temp.k(20)) ->> 'result',
  'ok', 'a later correction can be opened again');
reset role;
select ok((select version = 3 and status = 'draft' and supersedes_id = (pg_temp.report_v('w1', 1)).id from pg_temp.report_v('w1', 3)),
  'it is version 3 and corrects version 1; the withdrawn number 2 is not reused');

-- A draft with changes must be signed
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_visit_time(pg_temp.started_event('w1'), private.now() - interval '40 minutes', 'Synthetisch: Start früher',
                                    pg_temp.k(21)), 'ok', 'the draft unlocks the times: a correction is recorded');
select is(public.withdraw_report_correction((pg_temp.report_v('w1', 3)).id, pg_temp.k(22)),
  '{"result": "rejected", "reason": "draft_has_changes"}'::jsonb, 'a draft with a time correction cannot be withdrawn');
reset role;
select is((pg_temp.report_v('w1', 3)).status, 'draft', 'nothing written: it stays a draft to be signed');

-- Observation since the draft was opened
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('w4', 4);
select is(public.correct_report(pg_temp.latest_report('w4'), 'Synthetisch: Beobachtung ergänzen', null, pg_temp.k(45)) ->> 'result',
  'ok', 'w4: a correction is opened');
select is(public.record_observation(pg_temp.vid('w4'), 'Synthetisch: Haut intakt', false, null, pg_temp.k(46)), 'ok',
  'w4: an observation is recorded on the draft');
select is(public.withdraw_report_correction(pg_temp.latest_report('w4'), pg_temp.k(47)) ->> 'reason', 'draft_has_changes',
  'a draft with a new observation cannot be withdrawn');
-- Summary edited (stricter than the criterion: her words would be dropped without a signed version)
select pg_temp.run_and_sign('w5', 8);
select is(public.correct_report(pg_temp.latest_report('w5'), 'Synthetisch: Zusammenfassung', null, pg_temp.k(85)) ->> 'result',
  'ok', 'w5: a correction is opened');
select is(public.update_report_draft(pg_temp.latest_report('w5'), 'Synthetisch: neue Zusammenfassung', pg_temp.k(86)) ->> 'result',
  'ok', 'w5: its summary is edited');
select is(public.withdraw_report_correction(pg_temp.latest_report('w5'), pg_temp.k(87)) ->> 'reason', 'draft_has_changes',
  'a draft with an edited summary cannot be withdrawn');
reset role;

-- A first draft is not a correction
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('w3'), pg_temp.k(31));
  perform public.complete_visit(pg_temp.vid('w3'), pg_temp.k(32));
  if not exists (select 1 from public.visit_reports r where r.visit_id = pg_temp.vid('w3')) then
    perform public.create_report_draft(pg_temp.vid('w3'), null, pg_temp.k(34));
  end if;
end $$;
select is(public.withdraw_report_correction(pg_temp.latest_report('w3'), pg_temp.k(33)) ->> 'reason', 'not_correction',
  'a first report draft is not withdrawn (the visit would have no report)');
reset role;

-- A signed correction awaiting the countersignature (D-10)
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select pg_temp.run_and_sign('w2', 2);
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.countersign_report(pg_temp.latest_report('w2'), pg_temp.k(25)) ->> 'result', 'ok', 'w2: version 1 countersigned');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('w2'), 'Synthetisch: Massnahme ergänzen', null, pg_temp.k(26)) ->> 'result', 'ok',
  'w2: the care assistant opens a correction');
select is(public.sign_report(pg_temp.latest_report('w2'), pg_temp.shown_hash('w2'), pg_temp.k(27)) ->> 'result', 'ok', 'and signs it');
select is(public.withdraw_report_correction(pg_temp.latest_report('w2'), pg_temp.k(28)),
  '{"result": "rejected", "reason": "awaiting_countersignature"}'::jsonb,
  'a signed correction awaiting the countersignature cannot be withdrawn (D-10)');
reset role;
select is((select status from public.visit_reports where id = pg_temp.latest_report('w2')), 'signed', 'nothing written');

-- CGR-29: a correction that became final during a hold is the fact after the lift ------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('k1', 5);
select ok(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date) >= 1, 'k1: the fact of version 1 is built');
reset role;
create temp table k1_v1 as select (pg_temp.head_fact('k1')).report_id as report_id, (pg_temp.head_fact('k1')).measured_care_minutes as m;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_quality_hold(pg_temp.vid('k1'), 'Synthetisch: Leistung strittig', pg_temp.k(51)), 'ok', 'a hold is set');
select is(public.correct_report(pg_temp.latest_report('k1'), 'Synthetisch: Start früher', null, pg_temp.k(52)) ->> 'result', 'ok',
  'during the hold a correction is opened');
select is(public.correct_visit_time(pg_temp.started_event('k1'), private.now() - interval '45 minutes', 'Synthetisch: Start früher',
                                    pg_temp.k(53)), 'ok', 'its time is corrected');
select is(public.sign_report(pg_temp.latest_report('k1'), pg_temp.shown_hash('k1'), pg_temp.k(54)) ->> 'result', 'ok',
  'and signed: version 2 is final during the hold');
select is(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date), 0, 'no fact while the hold is open');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.lift_quality_hold((select h.id from public.quality_holds h where h.visit_id = pg_temp.vid('k1')),
  'Synthetisch: geklärt', pg_temp.k(55)), 'ok', 'the coach lifts the hold');
reset role;
select ok((select f.report_id = pg_temp.latest_report('k1') and f.report_id <> (select report_id from k1_v1)
                  and f.cause = 'report' and f.rule_version = 'J5-v3' and f.billable
                  and f.snapshot_hash = (select private.report_snapshot_hash(r.snapshot) from public.visit_reports r
                                         where r.id = pg_temp.latest_report('k1'))
                  and f.measured_care_minutes > (select m from k1_v1)
                  and f.created_by = '00000000-0000-4000-a000-000000000901'
                  and (select x.cause from public.billable_facts x where x.id = f.supersedes_id) = 'quality_hold'
           from pg_temp.head_fact('k1') f),
  'CGR-29: the head fact carries version 2''s report_id and snapshot hash, superseding the hold fact');
select is((select count(*)::int from public.billable_facts f where f.visit_id = pg_temp.vid('k1') and f.cause = 'hold_lifted'), 0,
  'the older version''s fact is not restored');

-- J5-C1: a payer correction re-derives the fact from the same signed snapshot ---------------------------------------------
update public.cases set insurance_type = 'IV' where id = '00000000-0000-4000-a000-000000000208';   -- as the table owner
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('j1', 6);
select ok(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date) >= 1, 'j1: fact built');
reset role;
create temp table j1_before as select (pg_temp.head_fact('j1')).* ;
select ok((select not billable and reasons = array['payer_not_modelled'] from j1_before), 'j1: IV is payer_not_modelled');

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');   -- intake corrects the insurance type (as the table owner)
update public.cases set insurance_type = 'KVG' where id = '00000000-0000-4000-a000-000000000208';
select ok((select f.billable and f.reasons = '{}' and f.cause = 'basis_changed' and f.hold_id is null
                  and f.supersedes_id = (select id from j1_before)
                  and f.report_id = (select report_id from j1_before)
                  and f.snapshot_hash = (select snapshot_hash from j1_before)
                  and f.measured_care_minutes = (select measured_care_minutes from j1_before)
                  and f.payer_chain ->> 'insurance_type' = 'KVG'
                  and f.created_by = '00000000-0000-4000-a000-000000000904'
           from pg_temp.head_fact('j1') f),
  'J5-C1: KVG set → a new billable fact (basis_changed) supersedes it, same report and snapshot hash, with who changed it');
select is((select count(*)::int from public.visit_reports r where r.visit_id = pg_temp.vid('j1')), 1, 'no new report version');

-- Order change: not re-derived until D-22
update public.cases set medical_order_status = 'present', medical_order_valid_until = null where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select pg_temp.run_and_sign('j2', 7);
select ok(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date) >= 1, 'j2: fact built');
reset role;
create temp table j2_before as select (pg_temp.head_fact('j2')).* ;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
update public.cases set medical_order_valid_until = (private.now() at time zone 'Europe/Zurich')::date + 30 where id = '00000000-0000-4000-a000-000000000208';
select ok((select f.id = (select id from j2_before) and not f.billable and 'order_validity_missing' = any (f.reasons)
           from pg_temp.head_fact('j2') f),
  'J5-C1 / D-22: an order end date entered later does not make the earlier visit billable');
update public.cases set insurer_name = 'Testkasse Zwei' where id = '00000000-0000-4000-a000-000000000208';
select ok((select f.cause = 'basis_changed' and not f.billable and f.reasons @> array['b_without_valid_order', 'order_validity_missing']
                  and f.payer_chain ->> 'insurer' = 'Testkasse Zwei'
           from pg_temp.head_fact('j2') f),
  'a later payer correction re-derives the payer only: the order reasons stay');

-- Catch-up: a change without a signed-in user is re-derived by the next generation
select pg_temp.nobody();
update public.cases set insurer_name = null where id = '00000000-0000-4000-a000-000000000208';
select is((select f.payer_chain ->> 'insurer' from pg_temp.head_fact('j1') f), 'Testkasse Zwei',
  'without a signed-in user nothing is re-derived at once');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok(public.generate_billable_facts((private.now() at time zone 'Europe/Zurich')::date) >= 1, 'the next generation re-derives');
reset role;
select ok((select f.cause = 'basis_changed' and not f.billable and f.reasons = array['no_insurer']
           from pg_temp.head_fact('j1') f), 'j1: no_insurer after the catch-up');

select * from finish();
rollback;
