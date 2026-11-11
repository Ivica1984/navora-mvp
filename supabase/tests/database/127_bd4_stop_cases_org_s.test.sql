-- BD-4 (brief docs/agents/briefs/BD.md; inventory docs/engineering/DURCHGANG_INVENTORY.md §2): the IMPLEMENTED stop cases of
-- steps 1 to 2 as negative steps on the BD case shape, i.e. on Testorganisation S through the same commands the BD run uses
-- (referral → case → team takes it → assessment visit → care plan → visits). Test only: no grant, policy, rule, command or
-- seed change. No rule is added or interpreted (BD-6): each assertion reads a refusal that exists today.
--   S1 `assessment_first` (CR-002): no care visit before the completed assessment visit; nothing is stored.
--   S2 the assessment visit is category A only.
--   S3 QUAL1 (simulation organisation, matrix QAM-0.2 PROPOSED, D-43): a care assistant is not made responsible for the
--      assessment visit or a KLV-B visit; nothing is stored; the registered nurse is (control).
--   S4 a KLV-B visit without a present medical order is refused at planning (`order_required`).
--   N  the BD negative: a nurse of another organisation, Operations (no dispatcher) and `anon` neither read nor plan the case.
-- Not here: the billing stop cases (report not final, B minutes without a valid order at the fact, correction open) stay
-- with pgTAP 022, 043, 047, 049, 051 until the BD run reaches step 9 on org S; evidence missing or expired with pgTAP 120 to
-- 122 (no org S member lacks evidence in the seed). Synthetische Daten.
-- Seed: org S …019, Testteam Basel …1b9, opsbs …9e5 (operations), pflegebs …9e6 (registered nurse), assistbs …9e7 (care
-- assistant); Testorganisation A nurse …902 (Testteam Nord).
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.org_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;
create function pg_temp.team_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001b9'::uuid $$;
create function pg_temp.ops() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e5'::uuid $$;
create function pg_temp.nurse() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e6'::uuid $$;
create function pg_temp.assist() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e7'::uuid $$;
create function pg_temp.nurse_a() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-000000000902'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1270000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
-- plan_visit as `authenticated` for uid: 'ok', the refusal reason, or '<sqlstate> <message>' when a check raises.
create function pg_temp.plan_as(uid uuid, p_case uuid, d date, s time, e time, a int, b int, c int, na boolean, resp uuid, key uuid)
returns text language plpgsql as $$
declare r jsonb; st text; msg text;
begin
  perform pg_temp.act_as(uid);
  execute 'set local role authenticated';
  begin
    r := public.plan_visit(p_case, d, s, e, a, b, c, na, resp, key);
  exception when others then
    get stacked diagnostics st = returned_sqlstate, msg = message_text;
    execute 'reset role';
    perform pg_temp.as_owner();
    return st || ' ' || msg;
  end;
  execute 'reset role';
  perform pg_temp.as_owner();
  return coalesce(r ->> 'reason', r ->> 'result');
end $$;
-- A query run as p_role (authenticated for uid, or anon); its rows as a jsonb array, or 'refused <sqlstate>'.
create function pg_temp.rows_as(p_role text, uid uuid, p_sql text) returns text language plpgsql as $$
declare r jsonb; st text;
begin
  if uid is not null then perform pg_temp.act_as(uid); end if;
  execute format('set local role %I', p_role);
  begin
    execute format('select coalesce(jsonb_agg(to_jsonb(q)), ''[]''::jsonb) from (%s) q', p_sql) into r;
  exception when others then
    get stacked diagnostics st = returned_sqlstate;
    execute 'reset role';
    perform pg_temp.as_owner();
    return 'refused ' || st;
  end;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r::text;
end $$;

-- Step 1: referral → case → Testteam Basel takes it (J1, J2), as in the BD run ------------------------------------------------
select pg_temp.act_as(pg_temp.ops());
set local role authenticated;
do $$
begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000019', 'Spital BD4 (synthetisch)', 'Spital',
    'Basel-Stadt', null, 'mittel', null, 'BD4 Anfrage', 'Bedarf BD4', array['Grundpflege'],
    'a1270000-0000-4000-8000-000000000101', 'referrer_stated');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'BD4 Anfrage'),
    'Synth', 'BD4neu', true, jsonb_build_object('residence_municipality', 'Basel', 'residence_canton', 'BS',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG',
      'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 1, 'medical_order_status', 'requested'),
    'a1270000-0000-4000-8000-000000000102');
end $$;
reset role;
select pg_temp.act_as(pg_temp.nurse());
set local role authenticated;
do $$ begin
  perform public.decide_matching_request(
    (select o.matching_request_id from public.team_offers() o where o.request_title = 'Teamsuche: BD4 Anfrage'),
    '00000000-0000-4000-a000-0000000001b9', 'accept', null, 'a1270000-0000-4000-8000-000000000103');
end $$;
reset role;
select pg_temp.as_owner();
create temp table bd4 as select id from public.cases where last_name = 'BD4neu';
grant select on bd4 to authenticated;

select is((select assigned_team_id from public.cases where id = (select id from bd4)), pg_temp.team_s(),
  'BD step 1: the org S referral became a case that Testteam Basel took over (commands only)');

-- S1, S2: assessment first, category A only ----------------------------------------------------------------------------------
select is(pg_temp.plan_as(pg_temp.nurse(), (select id from bd4), pg_temp.today() + 1, '09:00', '09:45', 0, 0, 30, false, null,
                          pg_temp.k(1)),
  'assessment_first', 'BD-4 S1: no care visit before the completed assessment visit (assessment_first, CR-002)');
select is((select count(*)::int from public.care_visits where case_id = (select id from bd4)), 0,
  'BD-4 S1: the refused visit is not stored');
select is(pg_temp.plan_as(pg_temp.nurse(), (select id from bd4), pg_temp.today(), '09:00', '10:00', 45, 15, 0, true, null,
                          pg_temp.k(2)),
  'assessment_category_a_only', 'BD-4 S2: the assessment visit is category A only');

-- S3 (assessment): the care assistant is not made responsible; the registered nurse is ------------------------------------------
select isnt(pg_temp.plan_as(pg_temp.nurse(), (select id from bd4), pg_temp.today(), '09:00', '10:00', 60, 0, 0, true,
                            pg_temp.assist(), pg_temp.k(3)),
  'ok', 'BD-4 S3: the assessment visit is refused with the care assistant responsible (QUAL1 A1 or CR-007)');
select is((select count(*)::int from public.care_visits where case_id = (select id from bd4)), 0,
  'BD-4 S3: nothing is stored for the refused assessment visit');
select is(pg_temp.plan_as(pg_temp.nurse(), (select id from bd4), pg_temp.today(), '09:00', '10:00', 60, 0, 0, true,
                          pg_temp.nurse(), pg_temp.k(4)),
  'ok', 'BD-4 S3 control: the team plans the assessment visit with its registered nurse responsible');

-- Step 1b: the nurse runs the assessment visit; the care plan opens planning (as in the BD run) ---------------------------------
select pg_temp.act_as(pg_temp.nurse());
set local role authenticated;
select is(public.start_visit((select id from public.care_visits where case_id = (select id from bd4) and is_needs_assessment),
          pg_temp.k(5)), 'ok', 'BD step 1b: the registered nurse starts the assessment visit (QUAL1 start check passes)');
select is(public.complete_visit((select id from public.care_visits where case_id = (select id from bd4) and is_needs_assessment),
          pg_temp.k(6)), 'ok', 'BD step 1b: and completes it');
select is((select needs_assessment_done from public.team_cases() where case_id = (select id from bd4)), true,
  'BD step 1b: the case is marked assessed');
select is(public.add_care_plan_item((select id from bd4), 'Grundpflege', 'C', 30, '1x täglich', pg_temp.today() + 30,
          null, pg_temp.k(7)), 'ok', 'BD step 1b: the team records a category C care-plan item');
select is(public.add_care_plan_item((select id from bd4), 'Wundversorgung', 'B', 15, '3x pro Woche', pg_temp.today() + 30,
          null, pg_temp.k(8)), 'ok', 'BD step 1b: and a category B item');
reset role;
select pg_temp.as_owner();

-- S4: KLV-B minutes need a present medical order --------------------------------------------------------------------------------
select is(pg_temp.plan_as(pg_temp.nurse(), (select id from bd4), pg_temp.today() + 2, '08:00', '08:45', 0, 15, 30, false,
                          pg_temp.nurse(), pg_temp.k(9)),
  'order_required', 'BD-4 S4: a KLV-B visit without a present medical order is refused (order_required)');

-- S3 (KLV-B): with a present order (fixture, as pgTAP 014), the care assistant is still not made responsible ---------------------
update public.cases set medical_order_status = 'present', medical_order_valid_until = pg_temp.today() + 30
where id = (select id from bd4);
select isnt(pg_temp.plan_as(pg_temp.nurse(), (select id from bd4), pg_temp.today() + 3, '08:00', '08:45', 0, 15, 30, false,
                            pg_temp.assist(), pg_temp.k(10)),
  'ok', 'BD-4 S3: a KLV-B visit is refused with the care assistant responsible (QUAL1 B13 or CR-007)');
select is((select count(*)::int from public.care_visits where case_id = (select id from bd4) and visit_date = pg_temp.today() + 3), 0,
  'BD-4 S3: nothing is stored for the refused KLV-B visit');
select is(pg_temp.plan_as(pg_temp.nurse(), (select id from bd4), pg_temp.today() + 3, '08:00', '08:45', 0, 15, 30, false,
                          pg_temp.nurse(), pg_temp.k(11)),
  'ok', 'BD-4 S3 control: the same KLV-B visit is planned with the registered nurse responsible');

-- N: nobody outside the team reads or plans the run's case ----------------------------------------------------------------------
select is(pg_temp.rows_as('authenticated', pg_temp.nurse_a(),
            format('select id from public.cases where id = %L', (select id from bd4))), '[]',
  'BD negative: a nurse of Testorganisation A reads no row of the org S case (RLS)');
select is(pg_temp.plan_as(pg_temp.nurse_a(), (select id from bd4), pg_temp.today() + 4, '12:00', '12:30', 0, 0, 30, false, null,
                          pg_temp.k(12)),
  'not_team_member', 'BD negative: a nurse of Testorganisation A cannot plan a visit of the org S case');
select is(pg_temp.rows_as('authenticated', pg_temp.ops(),
            format('select case_id from public.team_cases() where case_id = %L', (select id from bd4))), '[]',
  'BD negative: Operations of org S has no team view of the case (no dispatcher)');
select is(pg_temp.plan_as(pg_temp.ops(), (select id from bd4), pg_temp.today() + 4, '12:00', '12:30', 0, 0, 30, false, null,
                          pg_temp.k(13)),
  'not_team_member', 'BD negative: Operations of org S cannot plan the team''s visit');
select ok(not has_function_privilege('anon',
            'public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid, boolean, boolean)', 'execute')
          and not has_function_privilege('anon', 'public.start_visit(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.team_cases()', 'execute'),
  'BD negative: anon may not plan, start or list team cases');
select ok(pg_temp.rows_as('anon', null, format('select id from public.cases where id = %L', (select id from bd4)))
            in ('[]', 'refused 42501'),
  'BD negative: anon reads no row of the org S case (no grant or RLS)');

select * from finish();
rollback;
