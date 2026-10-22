-- J5: billable facts and monthly preview (PO brief docs/agents/briefs/J5.md).
-- Users: nurse …902 (Testteam Nord, RN) · coach …901 (coordinator, not an intake role) · ops …904 (intake role) · foreign …903
-- Case …208 (Testteam Nord). Visits: …501 (A 20 + C 15 min) and two inserted here (X: hold, Y: B without order).
begin;
create extension if not exists pgtap with schema extensions;

select plan(27);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Reference data -----------------------------------------------------------------------------------------------
select is((select amount from public.tariff_rates where region = 'CH' and payer = 'insurer' and category = 'A'), 76.90::numeric,
  'federal insurer rate A on file, with version and source');
select is((select count(*)::int from public.tariff_rates where payer in ('patient', 'residual')), 0,
  'no cantonal patient or residual rates are invented (D-11)');
select is(private.min_billable_minutes('BE', current_date), 10, 'minimum billable minutes come from reference data');
select ok(not has_function_privilege('anon', 'public.generate_billable_facts(date)', 'execute'), 'anon cannot generate facts');

-- Fixtures (as owner) -------------------------------------------------------------------------------------------
update public.cases set insurer_name = 'Testkasse', insurance_type = 'KVG', residence_canton = 'BE',
                        residence_municipality = 'Teststadt', medical_order_status = null, medical_order_valid_until = null
  where id = '00000000-0000-4000-a000-000000000208';
update public.care_visits set planned_minutes_a = 20, planned_minutes_c = 15 where id = '00000000-0000-4000-a000-000000000501';
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, planned_minutes_c, planned_minutes_b) values
  ('00000000-0000-4000-b000-000000000011', 'ac000000-0000-4000-8000-0000000000aa', '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', current_date, '16:00', '16:30', false, 'planned', 30, 0),
  ('00000000-0000-4000-b000-000000000011', 'ac000000-0000-4000-8000-0000000000bb', '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', current_date, '17:00', '17:30', false, 'planned', 0, 20);

-- The nurse runs three visits; visit 501 had 30 minutes of care (start corrected, F3)
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.start_visit('00000000-0000-4000-a000-000000000501', 'ac000000-0000-4000-8000-000000000001');
  perform public.complete_visit('00000000-0000-4000-a000-000000000501', 'ac000000-0000-4000-8000-000000000002');
  perform public.correct_visit_time((select id from public.visit_events where visit_id = '00000000-0000-4000-a000-000000000501' and event_type = 'started'),
    now() - interval '30 minutes', 'Start zu spät getippt', 'ac000000-0000-4000-8000-000000000003');
  perform public.start_visit('ac000000-0000-4000-8000-0000000000aa', 'ac000000-0000-4000-8000-000000000004');
  perform public.complete_visit('ac000000-0000-4000-8000-0000000000aa', 'ac000000-0000-4000-8000-000000000005');
  perform public.start_visit('ac000000-0000-4000-8000-0000000000bb', 'ac000000-0000-4000-8000-000000000006');
  perform public.complete_visit('ac000000-0000-4000-8000-0000000000bb', 'ac000000-0000-4000-8000-000000000007');
end $$;
select is(public.generate_billable_facts(current_date), 0, 'no fact without a final report');

do $$ declare r jsonb; begin
  r := public.create_report_draft('00000000-0000-4000-a000-000000000501', null, 'ac000000-0000-4000-8000-000000000010');
  perform public.sign_report((r ->> 'report_id')::uuid, 'ac000000-0000-4000-8000-000000000011');
  perform public.set_quality_hold('ac000000-0000-4000-8000-0000000000aa', 'Leistung strittig', 'ac000000-0000-4000-8000-000000000012');
  r := public.create_report_draft('ac000000-0000-4000-8000-0000000000aa', null, 'ac000000-0000-4000-8000-000000000013');
  perform public.sign_report((r ->> 'report_id')::uuid, 'ac000000-0000-4000-8000-000000000014');
  r := public.create_report_draft('ac000000-0000-4000-8000-0000000000bb', null, 'ac000000-0000-4000-8000-000000000015');
  perform public.sign_report((r ->> 'report_id')::uuid, 'ac000000-0000-4000-8000-000000000016');
end $$;

select is(public.generate_billable_facts(current_date), 2, 'facts for final reports without a hold (the held visit gets none)');
select is(public.generate_billable_facts(current_date), 0, 'generation is idempotent');
select is((select count(*)::int from public.billable_facts where visit_id = 'ac000000-0000-4000-8000-0000000000aa'), 0,
  'a visit with an open quality hold never becomes a fact');

-- The fact for visit 501 --------------------------------------------------------------------------------------------
select ok((select billable and order_basis = 'without_order_ac' and planned_minutes_a = 20 and planned_minutes_c = 15
           from public.billable_facts where visit_id = '00000000-0000-4000-a000-000000000501'), 'billable A/C without an order');
select ok((select actual_care_minutes between 29 and 31 from public.billable_facts where visit_id = '00000000-0000-4000-a000-000000000501'),
  'actual care minutes are measured from the (corrected) events');
select ok((select 'actual_below_planned' = any (warnings) from public.billable_facts where visit_id = '00000000-0000-4000-a000-000000000501'),
  'measured below planned is a warning (Q11), not a reason');
select is((select tariff_versions ->> 'A' from public.billable_facts where visit_id = '00000000-0000-4000-a000-000000000501'),
  'KLV-7-2026', 'the tariff version used is recorded');
select is((select payer_chain ->> 'insurer' || '/' || (payer_chain ->> 'residence_canton') from public.billable_facts
           where visit_id = '00000000-0000-4000-a000-000000000501'), 'Testkasse/BE', 'the payer chain is recorded');
select ok((select not billable and 'b_without_valid_order' = any (reasons) and order_basis = 'b_without_valid_order'
           from public.billable_facts where visit_id = 'ac000000-0000-4000-8000-0000000000bb'),
  'category B without a valid order is not billable, with the reason');
select ok((select care_minutes between 29 and 31 and performer_id = '00000000-0000-4000-a000-000000000902'
           from public.working_time_facts where visit_id = '00000000-0000-4000-a000-000000000501'),
  'working time is a separate fact type');

-- Preview ------------------------------------------------------------------------------------------------------------------
select ok((select minutes_a = 20 and minutes_c = 15 and insurer_chf = 38.78 and insurer_complete
           from public.billing_preview(current_date) where team_id = '00000000-0000-4000-a000-000000000101'),
  'the preview shows billable minutes per category and the insurer estimate (20×76.90/60 + 15×52.60/60)');
select ok((select not patient_on_file and not residual_on_file from public.billing_preview(current_date)
           where team_id = '00000000-0000-4000-a000-000000000101'), 'patient and residual shares are marked as not on file');
select ok((select not_billable @> '[{"reasons": ["quality_hold"]}]'::jsonb and not_billable @> '[{"reasons": ["b_without_valid_order"]}]'::jsonb
           from public.billing_preview(current_date) where team_id = '00000000-0000-4000-a000-000000000101'),
  'every non-billable visit is listed with its reason');
reset role;

select throws_ok($$ update public.billable_facts set billable = false $$, '42501', null, 'facts are immutable');
select throws_ok($$ delete from public.working_time_facts $$, '42501', null, 'working-time facts are immutable');

-- Correction: a new final report version creates a new fact referencing the old one ------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ declare r jsonb; begin
  r := public.correct_report((select id from public.visit_reports where visit_id = '00000000-0000-4000-a000-000000000501'),
                             'Leistung ergänzt', null, 'ac000000-0000-4000-8000-000000000020');
  perform public.sign_report((r ->> 'report_id')::uuid, 'ac000000-0000-4000-8000-000000000021');
end $$;
select is(public.generate_billable_facts(current_date), 1, 'the corrected report yields a new fact');
select is((select count(*)::int from public.billable_facts f where f.visit_id = '00000000-0000-4000-a000-000000000501'
           and f.supersedes_id = (select o.id from public.billable_facts o where o.visit_id = f.visit_id and o.supersedes_id is null)), 1,
  'the new fact references the old one');
select is((select billable_visits from public.billing_preview(current_date) where team_id = '00000000-0000-4000-a000-000000000101'), 1,
  'the preview counts only the latest fact per visit');
reset role;

-- Hold set after the fact: the visit stops counting -------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin perform public.set_quality_hold('00000000-0000-4000-a000-000000000501', 'Nachträglich strittig', 'ac000000-0000-4000-8000-000000000030'); end $$;
select is((select billable_visits from public.billing_preview(current_date) where team_id = '00000000-0000-4000-a000-000000000101'), 0,
  'a hold set later stops the visit from counting');
reset role;

-- Scope --------------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.billable_facts), 0, 'a coach does not read facts (they carry insurer data, J1)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok((select count(*) from public.billable_facts) >= 3, 'operations (intake role) reads the facts');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.billable_facts) + (select count(*)::int from public.billing_preview(current_date)
           where team_id = '00000000-0000-4000-a000-000000000101'), 0, 'another organisation sees nothing');
reset role;

select * from finish();
rollback;
