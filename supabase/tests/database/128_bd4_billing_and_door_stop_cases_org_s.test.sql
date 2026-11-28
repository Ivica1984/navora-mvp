-- BD-4 part 2 (brief docs/agents/briefs/BD.md, amendment 02:39 CGR-175; inventory docs/engineering/DURCHGANG_INVENTORY.md §2):
-- the remaining IMPLEMENTED stop cases of steps 5 to 9 as negative steps on the BD case shape, i.e. on Testorganisation S
-- through the same commands the BD run uses (referral → case → Testteam Basel takes it → assessment visit → care plan →
-- visits → report → billing facts). Test only: no grant, policy, rule, command or seed change. No rule is added or
-- interpreted (BD-6): each assertion reads a behaviour that exists today.
--   R1 report not final (draft) → no billable fact (0051 `build_billable_fact`: only `final` reports).
--   R2 KLV-B minutes, the medical order withdrawn by intake after planning → the fact exists, not billable,
--      `b_without_valid_order` (0051 `order_basis_as_of`; the order as of the visit date, here the live value).
--   R3 the start is refused at the door when the member's evidence is no longer verified since planning
--      (`qualification_lapsed`, 0121 QUAL1-17; simulation organisation, matrix QAM-0.2 PROPOSED, D-43). The evidence
--      becomes `contradictory` (a second grade record, CR-181 / pgTAP 120 NT-6), because evidence is append-only and is
--      checked up to the visit's end at planning already, so a pure expiry between planning and start cannot occur today.
--   N  the BD negative for the billing step: a nurse of Testorganisation A reads no fact of the run; anon cannot build facts.
-- Not here (stay «nicht nachgewiesen», brief 02:39): (a), (b) evidence lapsing while resuming, (e). Correction open: pgTAP
-- 047, 049, 066. Synthetische Daten.
-- Seed: org S …019, Testteam Basel …1b9, opsbs …9e5 (operations), pflegebs …9e6 (registered nurse); Testorganisation A
-- nurse …902 (Testteam Nord).
begin;
create extension if not exists pgtap with schema extensions;

select plan(25);

create function pg_temp.org_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;
create function pg_temp.team_s() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000001b9'::uuid $$;
create function pg_temp.ops() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e5'::uuid $$;
create function pg_temp.nurse() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-0000000009e6'::uuid $$;
create function pg_temp.nurse_a() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-000000000902'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1280000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
-- One SQL expression run as `authenticated` for uid: its value as text, or '<sqlstate> <message>' when it raises.
create function pg_temp.run_as(uid uuid, p_sql text) returns text language plpgsql as $$
declare r text; st text; msg text;
begin
  perform pg_temp.act_as(uid);
  execute 'set local role authenticated';
  begin
    execute format('select (%s)::text', p_sql) into r;
  exception when others then
    get stacked diagnostics st = returned_sqlstate, msg = message_text;
    execute 'reset role';
    perform pg_temp.as_owner();
    return st || ' ' || msg;
  end;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r;
end $$;
-- plan_visit as uid: 'ok' or the refusal reason (or '<sqlstate> <message>').
create function pg_temp.plan_as(uid uuid, p_case uuid, d date, s time, e time, a int, b int, c int, na boolean, resp uuid, key uuid)
returns text language plpgsql as $$
declare r text;
begin
  r := pg_temp.run_as(uid, format('public.plan_visit(%L::uuid, %L::date, %L::time, %L::time, %s, %s, %s, %L::boolean, %L::uuid, %L::uuid)',
                                  p_case, d, s, e, a, b, c, na, resp, key));
  if r like '{%' then return coalesce(r::jsonb ->> 'reason', r::jsonb ->> 'result'); end if;
  return r;
end $$;

-- Step 1: referral → case → Testteam Basel takes it (J1, J2), as in the BD run ------------------------------------------------
select pg_temp.act_as(pg_temp.ops());
set local role authenticated;
do $$
begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000019', 'Spital BD4b (synthetisch)', 'Spital',
    'Basel-Stadt', null, 'mittel', null, 'BD4b Anfrage', 'Bedarf BD4b', array['Grundpflege'],
    'a1280000-0000-4000-8000-000000000101', 'referrer_stated');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'BD4b Anfrage'),
    'Synth', 'BD4bneu', true, jsonb_build_object('residence_municipality', 'Basel', 'residence_canton', 'BS',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG',
      'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 1, 'medical_order_status', 'requested'),
    'a1280000-0000-4000-8000-000000000102');
end $$;
reset role;
select pg_temp.act_as(pg_temp.nurse());
set local role authenticated;
do $$ begin
  perform public.decide_matching_request(
    (select o.matching_request_id from public.team_offers() o where o.request_title = 'Teamsuche: BD4b Anfrage'),
    '00000000-0000-4000-a000-0000000001b9', 'accept', null, 'a1280000-0000-4000-8000-000000000103');
end $$;
reset role;
select pg_temp.as_owner();
create temp table bd4 as select id from public.cases where last_name = 'BD4bneu';
grant select on bd4 to authenticated;
create function pg_temp.case_id() returns uuid language sql stable as $$ select id from bd4 $$;
create function pg_temp.visit_at(s time) returns uuid language sql stable security definer as $$
  select v.id from public.care_visits v where v.case_id = pg_temp.case_id() and v.time_start = s $$;
create function pg_temp.report_of(s time) returns public.visit_reports language sql stable security definer as $$
  select r.* from public.visit_reports r where r.visit_id = pg_temp.visit_at(s)
  order by r.version desc limit 1 $$;
create function pg_temp.facts_of(s time) returns setof public.billable_facts language sql stable security definer as $$
  select f.* from public.billable_facts f where f.visit_id = pg_temp.visit_at(s) $$;
-- start, complete, the start set 30 minutes earlier (F3, Q-BD-1 (A)), report draft; signed only when p_sign.
create function pg_temp.run_visit(s time, base int, p_sign boolean) returns text language plpgsql as $$
declare v uuid := pg_temp.visit_at(s); r jsonb; out text; ev bigint;
begin
  out := public.start_visit(v, pg_temp.k(base + 1));
  out := out || '|' || public.complete_visit(v, pg_temp.k(base + 2));
  select e.id into ev from public.visit_events e where e.visit_id = v and e.event_type = 'started';
  out := out || '|' || public.correct_visit_time(ev, private.now() - interval '30 minutes',
                                                 'Testlauf: simulierte Einsatzdauer', pg_temp.k(base + 3));
  r := public.create_report_draft(v, 'Synthetisch: Verlauf ruhig', pg_temp.k(base + 4));
  out := out || '|' || coalesce(r ->> 'result', '?') || coalesce(':' || (r ->> 'reason'), '');
  if p_sign then
    r := public.sign_report((r ->> 'report_id')::uuid,
      (select f.snapshot_hash from public.field_reports(pg_temp.today()) f where f.visit_id = v), pg_temp.k(base + 5));
    out := out || '|' || coalesce(r ->> 'result', '?') || coalesce(':' || (r ->> 'reason'), '');
  end if;
  return out;
end $$;

select is((select assigned_team_id from public.cases where id = pg_temp.case_id()), pg_temp.team_s(),
  'BD step 1: the org S referral became a case that Testteam Basel took over (commands only)');

-- Step 1b: assessment visit run by the registered nurse; care plan with a C and a B item (as in the BD run) -------------------
select is(pg_temp.plan_as(pg_temp.nurse(), pg_temp.case_id(), pg_temp.today(), '09:00', '10:00', 60, 0, 0, true,
                          pg_temp.nurse(), pg_temp.k(1)),
  'ok', 'BD step 1b: the team plans the assessment visit with its registered nurse responsible');
select is(pg_temp.run_as(pg_temp.nurse(), format('public.start_visit(%L::uuid, %L::uuid)', pg_temp.visit_at('09:00'), pg_temp.k(2)))
          || '|' ||
          pg_temp.run_as(pg_temp.nurse(), format('public.complete_visit(%L::uuid, %L::uuid)', pg_temp.visit_at('09:00'), pg_temp.k(3))),
  'ok|ok', 'BD step 1b: the registered nurse starts and completes the assessment visit');
select is(pg_temp.run_as(pg_temp.nurse(), format('public.add_care_plan_item(%L::uuid, ''Grundpflege'', ''C'', 30, ''1x täglich'', %L::date, null, %L::uuid)',
                                                 pg_temp.case_id(), pg_temp.today() + 30, pg_temp.k(4)))
          || '|' ||
          pg_temp.run_as(pg_temp.nurse(), format('public.add_care_plan_item(%L::uuid, ''Wundversorgung'', ''B'', 15, ''3x pro Woche'', %L::date, null, %L::uuid)',
                                                 pg_temp.case_id(), pg_temp.today() + 30, pg_temp.k(5))),
  'ok|ok', 'BD step 1b: the team records a category C and a category B care-plan item');

-- R1: a report that is not final gives no billable fact (H-05) ------------------------------------------------------------------
select is(pg_temp.plan_as(pg_temp.nurse(), pg_temp.case_id(), pg_temp.today(), '11:00', '11:30', 0, 0, 30, false,
                          pg_temp.nurse(), pg_temp.k(10)),
  'ok', 'BD-4 R1 setup: a category C care visit is planned for today');
select is(pg_temp.run_as(pg_temp.nurse(), 'pg_temp.run_visit(''11:00'', 100, false)'), 'ok|ok|ok|ok',
  'BD-4 R1 setup: the nurse runs the visit and writes the report draft, without signing');
select is((select status from pg_temp.report_of('11:00')), 'draft', 'BD-4 R1: the report is a draft (not final)');
select ok(pg_temp.run_as(pg_temp.nurse(), format('public.generate_billable_facts(%L::date)', pg_temp.today())) ~ '^[0-9]+$',
  'BD-4 R1: the team builds the billing facts of the month (as the BD run does at step 9)');
select is((select count(*)::int from pg_temp.facts_of('11:00')), 0,
  'BD-4 R1: no billable fact exists for the visit whose report is not final');

-- R2: KLV-B minutes, the order withdrawn after planning: the fact is not billable, b_without_valid_order -------------------------
-- As the table owner: the intake records a present order (fixture, as pgTAP 014 and 127) ...
update public.cases set medical_order_status = 'present', medical_order_valid_until = pg_temp.today() + 30
where id = pg_temp.case_id();
select is(pg_temp.plan_as(pg_temp.nurse(), pg_temp.case_id(), pg_temp.today(), '12:00', '12:45', 0, 15, 30, false,
                          pg_temp.nurse(), pg_temp.k(20)),
  'ok', 'BD-4 R2 setup: with a present order the KLV-B visit is planned for today');
-- ... and, after planning, the intake edit withdraws it again (status back to requested, no end date; audited).
update public.cases set medical_order_status = 'requested', medical_order_valid_until = null
where id = pg_temp.case_id();
select is((select coalesce(medical_order_status, '-') from public.cases where id = pg_temp.case_id()), 'requested',
  'BD-4 R2 setup: the order is no longer present on the visit date');
select is(pg_temp.run_as(pg_temp.nurse(), 'pg_temp.run_visit(''12:00'', 200, true)'), 'ok|ok|ok|ok|ok',
  'BD-4 R2 setup: the nurse runs the visit, writes and signs the report');
select is((select status from pg_temp.report_of('12:00')), 'final', 'BD-4 R2: the registered nurse''s report is final');
select ok(pg_temp.run_as(pg_temp.nurse(), format('public.generate_billable_facts(%L::date)', pg_temp.today())) ~ '^[1-9][0-9]*$',
  'BD-4 R2: building the facts records at least one new fact');
select is((select count(*)::int from pg_temp.facts_of('12:00')), 1, 'BD-4 R2: one fact exists for the signed KLV-B visit');
select ok((select not f.billable and 'b_without_valid_order' = any (f.reasons) and f.order_basis = 'b_without_valid_order'
           from pg_temp.facts_of('12:00') f),
  'BD-4 R2: the fact is not billable, reason b_without_valid_order (the order as of the visit date)');
select is((select count(*)::int from pg_temp.facts_of('11:00')), 0,
  'BD-4 R1 after the second build: still no fact for the visit whose report is not final');

-- R3: evidence no longer verified since planning: the start is refused at the door -----------------------------------------------
select is(pg_temp.plan_as(pg_temp.nurse(), pg_temp.case_id(), pg_temp.today(), '14:00', '14:30', 0, 0, 30, false,
                          pg_temp.nurse(), pg_temp.k(30)),
  'ok', 'BD-4 R3 setup: a category C visit is planned for today with the registered nurse responsible');
-- As the table owner: a second, disagreeing grade record for her (synthetic fixture, as pgTAP 120 NT-6; append-only).
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
values (pg_temp.org_s(), pg_temp.nurse(), 'grade', 'fage_efz', 'verified', true, null);
select is((select state from private.qual_evidence_state(pg_temp.org_s(), pg_temp.nurse(), 'grade', private.now())),
  'contradictory', 'BD-4 R3 setup: her grade evidence is contradictory now (nothing resolved automatically)');
select is(pg_temp.run_as(pg_temp.nurse(), format('public.start_visit(%L::uuid, %L::uuid)', pg_temp.visit_at('14:00'), pg_temp.k(31))),
  '42501 qualification_lapsed', 'BD-4 R3: the start is refused at the door (QUAL1-17, qualification_lapsed)');
select is((select status from public.care_visits where id = pg_temp.visit_at('14:00')), 'planned',
  'BD-4 R3: nothing was started');
select is((select count(*)::int from public.visit_events where visit_id = pg_temp.visit_at('14:00') and event_type = 'started'), 0,
  'BD-4 R3: no start event was written');

-- N: nobody outside the team reads or builds the run's facts ----------------------------------------------------------------------
select is(pg_temp.run_as(pg_temp.nurse_a(),
            format('(select count(*) from public.billable_facts where case_id = %L)', pg_temp.case_id())), '0',
  'BD negative: a nurse of Testorganisation A reads no billing fact of the org S case (RLS)');
select ok(not has_function_privilege('anon', 'public.generate_billable_facts(date)', 'execute'),
  'BD negative: anon may not build billing facts');
select ok(pg_temp.run_as(pg_temp.nurse_a(), format('public.generate_billable_facts(%L::date)', pg_temp.today())) ~ '^[0-9]+$'
          and (select count(*)::int from public.billable_facts where case_id = pg_temp.case_id()) = 1,
  'BD negative: a nurse of Testorganisation A may run the build, and it adds no fact to the org S case');

select * from finish();
rollback;
