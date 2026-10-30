-- AIG1 part (a): AI governance foundation (migration 0097, ADR-120). Brief `docs/agents/briefs/AIG1.md` (AIG1-1 to
-- AIG1-12). All data synthetic; no AI service is called.
-- Seed users: pflege …902 (RN, Nord …101) · assist …906 (CA, Nord) · ops …904 · admin …905 (org A …011) · fremd …903
-- (admin of org B). Synthetic users added here: …9701 "x1", …9702 "x2" registered nurses of Nord; …9703 "m" a
-- registered nurse of Mitte …102. Case …208 (Nord). Visits a0970000-…-0000000001xx are created here.
begin;
create extension if not exists pgtap with schema extensions;

select plan(110);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;
create function pg_temp.at(p_local timestamp) returns void language sql as $$
  select set_config('navora.test_now', private.at_zurich(p_local)::text, true) $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'ops' then '00000000-0000-4000-a000-000000000904' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'fremd' then '00000000-0000-4000-a000-000000000903'
                 when 'x1' then 'a0970000-0000-4000-a000-000000009701' when 'x2' then 'a0970000-0000-4000-a000-000000009702'
                 when 'm' then 'a0970000-0000-4000-a000-000000009703' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0971000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a0970000-0000-4000-8000-' || lpad((100 + n)::text, 12, '0'))::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.res(p_user text, p_sql text) returns text language sql as $$
  select coalesce(r ->> 'result', r #>> '{}') from (select pg_temp.cmd(p_user, p_sql) as r) s $$;
create function pg_temp.rows(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]'') from (%s) x', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.refused(p_user text, p_sql text) returns boolean language plpgsql as $$
begin
  perform pg_temp.rows(p_user, p_sql);
  return false;
exception when insufficient_privilege then
  execute 'reset role';
  return true;
end $$;
-- The SQLSTATE a command raises for the user ('none' when it does not raise).
create function pg_temp.err(p_user text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.rows(p_user, p_sql);
  return 'none';
exception when others then
  execute 'reset role';
  return sqlstate;
end $$;
-- Propose for visit n as the user; returns the suggestion id (null when none was written).
create function pg_temp.propose(p_user text, n int, key int) returns uuid language sql as $$
  select (pg_temp.cmd(p_user, format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(n), pg_temp.k(key)))
          ->> 'suggestion_id')::uuid $$;
create function pg_temp.sug(n int) returns uuid language sql stable as $$
  select s.id from public.ai_suggestions s where s.entity_id = pg_temp.v(n) order by s.seq desc limit 1 $$;
create function pg_temp.confirm(p_user text, n int, p_outcome text, p_value jsonb, key int) returns text language sql as $$
  select pg_temp.res(p_user, format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', pg_temp.sug(n), p_outcome,
                                    p_value::text, pg_temp.k(key))) $$;
create function pg_temp.bulk(p_user text, ns int[], key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.confirm_suggestions(%L::uuid[], %L)',
                                    (select array_agg(pg_temp.sug(n) order by o) from unnest(ns) with ordinality u(n, o)),
                                    pg_temp.k(key))) $$;

-- Fixtures (as the table owner): three synthetic registered nurses, a display name, the primary nurse of case 208,
-- unassigned Nord visits on T+1 (20 minutes A), one with B minutes.
insert into auth.users (id, email)
select pg_temp.u(n), 'aig1-' || n || '@navora.test' from unnest(array['x1', 'x2', 'm']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select '00000000-0000-4000-b000-000000000011', pg_temp.u(n), 'nurse' from unnest(array['x1', 'x2', 'm']) n;
insert into public.team_memberships (team_id, user_id, qualification)
select case n when 'm' then '00000000-0000-4000-a000-000000000102'::uuid else '00000000-0000-4000-a000-000000000101'::uuid end,
       pg_temp.u(n), 'registered_nurse' from unnest(array['x1', 'x2', 'm']) n;
insert into public.member_profiles (organization_id, user_id, display_name)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('p'), 'Synth Pflege P'),
       ('00000000-0000-4000-b000-000000000011', pg_temp.u('ca'), 'Synth Assistenz CA');
update public.cases set primary_nurse_id = pg_temp.u('p') where id = '00000000-0000-4000-a000-000000000208';
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.t() + 1, (time '06:00' + n * interval '20 minutes')::time,
       (time '06:15' + n * interval '20 minutes')::time, array['Grundpflege'], false, 'planned',
       case when n = 5 then 0 else 15 end, case when n = 5 then 15 else 0 end
from generate_series(1, 30) n;

-- AIG1-1: the register and the switch --------------------------------------------------------------------------------------
insert into public.ai_agent_definitions (key, name, level, kind, version, provider, region, fixture, eval_bar, brief)
values ('aig1_test_ai', 'Synth KI', 'L', 'ai', '1', 'synthetic', 'CH', 'aig1_eval_aig1_test_primary_nurse', 100, 'AIG1'),
       ('aig1_test_g', 'Synth G', 'G', 'rule', '1', null, null, 'aig1_eval_aig1_test_primary_nurse', 100, 'AIG1'),
       ('aig1_test_nofix', 'Synth ohne Testfälle', 'L', 'rule', '1', null, null, null, null, 'AIG1');
select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_ai', pg_temp.k(1))) ->> 'reason', 'ai_not_allowed',
  'AIG1-1: an agent of kind ai is refused with its reason (D-35 rule A)');
select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_g', pg_temp.k(2))) ->> 'reason', 'level_not_allowed',
  'AIG1-1: an agent of level G is refused with its reason (D-34)');
select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, null, null, null, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(3))) ->> 'reason', 'threshold_missing',
  'AIG1-8: no switch-on without a written threshold');
select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_nofix', pg_temp.k(4))) ->> 'reason', 'no_fixture',
  'AIG1-9: an agent without a fixture cannot be switched on');
select is(pg_temp.res('p', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(5))), 'rejected',
  'AIG1-1: only an administrator of the organisation switches an agent');
select is(pg_temp.res('fremd', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(6))), 'rejected',
  'AIG1-1: an administrator of another organisation is refused');
-- Scoped to Testorganisation A: the seed holds the AIG1 part (b) fixtures of organisations E and F (ADR-129).
select is((select count(*)::int from public.ai_agent_settings where organization_id = '00000000-0000-4000-b000-000000000011'), 0, 'AIG1-1: no refused switch wrote a setting');
select is(pg_temp.res('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(7))), 'ok',
  'AIG1-1: the administrator switches the rule agent on with its threshold');
select ok((select state = 'on' and switched_on_by = pg_temp.u('admin') and on_version = '1' and stop_share = 50
                  and stop_min_proposals = 2 and stop_window_days = 7
           from public.ai_agent_settings where agent_key = 'aig1_test_primary_nurse' and organization_id = '00000000-0000-4000-b000-000000000011'),
  'AIG1-1: the register holds state, threshold, version and who switched it on');
select is((select count(*)::int from public.audit_events where table_name = 'ai_agent_settings' and actor_id = pg_temp.u('admin')
           and command = 'set_agent_state' and changed -> 'state' ->> 'new' = 'on'), 1, 'AIG1-1: the switch-on is audited');
select is(pg_temp.res('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(8))), 'unchanged',
  'AIG1-1: switching on again with the same threshold changes nothing');

-- AIG1-6 and AIG1-2: proposing within the caller's own access; the ledger ----------------------------------------------
select ok(pg_temp.propose('ca', 1, 10) is not null, 'AIG1-6: a member of the visit''s team gets a proposal');
select ok((select proposed_value = to_jsonb(pg_temp.u('p')::text) and not not_found and agent_version = '1'
                  and field = 'responsible_user_id' and case_id = '00000000-0000-4000-a000-000000000208'
                  and input_refs = jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', pg_temp.v(1)),
                                                     jsonb_build_object('table', 'cases', 'id', '00000000-0000-4000-a000-000000000208'))
           from public.ai_suggestions where id = pg_temp.sug(1)),
  'AIG1-2: the ledger row holds agent and version, case, input references (ids only) and the proposed value');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(1)), null::uuid,
  'AIG1-3: a proposal writes nothing into the record');
select is(pg_temp.err('m', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(2), pg_temp.k(11))), '42501',
  'AIG1-6: a nurse of another team is refused');
select is(pg_temp.err('fremd', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(2), pg_temp.k(12))), '42501',
  'AIG1-6: a person of another organisation is refused');
select is((select count(*)::int from public.ai_suggestions where entity_id = pg_temp.v(2)), 0,
  'AIG1-6: a refused proposal writes no ledger row');
select throws_ok($$ insert into public.ai_suggestions (proposal_id, organization_id, team_id, agent_key, agent_version, field,
                     entity_type, entity_id, input_refs, proposed_value)
                   values (gen_random_uuid(), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101',
                     'aig1_test_primary_nurse', '1', 'responsible_user_id', 'care_visits', gen_random_uuid(),
                     '[{"table": "cases", "id": "00000000-0000-4000-a000-000000000208", "last_name": "Muster"}]',
                     '"x"') $$, '23514', null, 'AIG1-2: an input reference carrying content is refused');
select throws_ok(format('update public.ai_suggestions set proposed_value = %L where id = %L', '"x"', pg_temp.sug(1)),
  '42501', null, 'AIG1-2: the ledger refuses an update by the table owner');
set local role service_role;
select throws_ok(format('delete from public.ai_suggestions where id = %L', pg_temp.sug(1)), '42501', null,
  'AIG1-2: the ledger refuses a delete by service_role');
reset role;
select throws_ok('truncate public.ai_suggestions cascade', '42501', null, 'AIG1-2: the ledger refuses truncate');

-- AIG1-3: a signed report does not confirm a proposed value -------------------------------------------------------------
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(0), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.t(), '16:00', '16:30', array['Grundpflege'], false, 'planned', 30);
select ok(pg_temp.propose('ca', 0, 20) is not null, 'fixture: a proposal for today''s visit');
select is(pg_temp.res('p', format('select public.start_visit(%L, %L)', pg_temp.v(0), pg_temp.k(21))), 'ok', 'fixture: she starts');
select is(pg_temp.res('p', format('select public.complete_visit(%L, %L)', pg_temp.v(0), pg_temp.k(22))), 'ok', 'fixture: she completes');
select is(pg_temp.res('p', format('select public.create_report_draft(%L, %L, %L)', pg_temp.v(0), 'Synthetisch', pg_temp.k(23))),
  'ok', 'fixture: she drafts the report');
select is(pg_temp.res('p', format('select public.sign_report(%L, %L, %L)', (select id from public.visit_reports where visit_id = pg_temp.v(0)),
            (select f ->> 'snapshot_hash' from jsonb_array_elements(pg_temp.rows('p', format('select * from public.field_reports(%L)', pg_temp.t()))) f
             where f ->> 'visit_id' = pg_temp.v(0)::text), pg_temp.k(24))), 'ok', 'fixture: she signs the report');
select is(pg_temp.rows('ca', format('select status, confirmer_name from public.value_provenance(%L, %L, %L)',
                                    'care_visits', pg_temp.v(0), 'responsible_user_id')),
  '[{"status": "offen", "confirmer_name": null}]'::jsonb,
  'AIG1-3: the signed report leaves the proposed value unconfirmed');

-- AIG1-3: confirm one value; the record line and the AUD1 reader -----------------------------------------------------------
select is(pg_temp.confirm('p', 1, 'confirmed', null, 30), 'ok', 'AIG1-3: she confirms the proposed value');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(1)), pg_temp.u('p'),
  'AIG1-3: only the confirm command writes the value into the record');
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.v(1) and change = 'taken'
           and reason = 'Bestätigter Vorschlag (AIG1)' and actor_id = pg_temp.u('p')), 1,
  'AIG1-3: the assignment is logged like a hand assignment, by the confirming person');
select is(pg_temp.rows('ca', format('select agent_name, status, confirmer_name, confirmed_at is not null as dated '
                                    'from public.value_provenance(%L, %L, %L)', 'care_visits', pg_temp.v(1), 'responsible_user_id')),
  '[{"agent_name": "Testassistent Bezugspflege", "status": "bestätigt", "confirmer_name": "Synth Pflege P", "dated": true}]'::jsonb,
  'AIG1-3/-11: the team reads "vorgeschlagen von / bestätigt von / am" for the one value');
select is(jsonb_array_length(pg_temp.rows('m', format('select * from public.value_provenance(%L, %L, %L)',
                                                      'care_visits', pg_temp.v(1), 'responsible_user_id'))), 0,
  'AIG1-11: a nurse of another team reads no provenance');
select is(pg_temp.rows('admin', format('select actor_id, changed -> ''outcome'' ->> ''new'' as outcome from public.read_audit_record(%L, %L, %L)',
            'ai_confirmations', (select id from public.ai_confirmations where suggestion_id = pg_temp.sug(1)), 'compliance')),
  jsonb_build_array(jsonb_build_object('actor_id', pg_temp.u('p'), 'outcome', 'confirmed')),
  'AIG1-11 (2b): read_audit_record gives the confirmer of one confirmation with a stated purpose');
select throws_ok(format('update public.ai_confirmations set outcome = %L where suggestion_id = %L', 'rejected', pg_temp.sug(1)),
  '42501', null, 'AIG1-3: a confirmation is never changed afterwards');

-- AIG1-11 (1): the confirmer, outcome and time are not selectable through the table API ---------------------------------
select ok(pg_temp.refused('ca', 'select confirmed_by from public.ai_confirmations'), 'AIG1-11: confirmed_by is refused (42501)');
select ok(pg_temp.refused('ca', 'select outcome from public.ai_confirmations'), 'AIG1-11: outcome is refused (42501)');
select ok(pg_temp.refused('ca', 'select confirmed_at from public.ai_confirmations'), 'AIG1-11: confirmed_at is refused (42501)');
select ok(pg_temp.refused('admin', 'select * from public.ai_confirmations'), 'AIG1-11: select * is refused, administrators included');
select ok(pg_temp.refused('ops', 'select confirmed_by, count(*) from public.ai_confirmations group by 1'),
  'AIG1-11: a count grouped by confirmer is refused');
select ok(pg_temp.refused('ca', 'select * from public.ai_suggestions'), 'AIG1-11: the ledger is not selectable either');
select is((select count(*)::int from information_schema.columns c
           where c.table_schema = 'public' and c.table_name in ('ai_suggestions', 'ai_confirmations', 'ai_agent_settings',
                                                                 'ai_agent_stops', 'ai_agent_definitions', 'ai_agent_fields',
                                                                 'ai_one_by_one_fields')
             and (has_column_privilege('authenticated', format('public.%I', c.table_name), c.column_name, 'select')
                  or has_column_privilege('anon', format('public.%I', c.table_name), c.column_name, 'select'))), 0,
  'AIG1-11: no AIG1 column is selectable by authenticated or anon');

-- Corrected, rejected, and the consuming command's checks per value ------------------------------------------------------
select ok(pg_temp.propose('ca', 3, 31) is not null, 'fixture: a proposal for visit 3');
select is(pg_temp.err('ca', format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', pg_temp.sug(3), 'corrected',
                                   to_jsonb(pg_temp.u('p')::text)::text, pg_temp.k(32))), '22023',
  'AIG1-3: an unchanged value is confirmed, not corrected');
select is(pg_temp.err('ca', format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', pg_temp.sug(3), 'corrected',
                                   '""', pg_temp.k(33))), '22023', 'AIG1-4: a correction is never an empty value');
select is(pg_temp.confirm('ca', 3, 'corrected', to_jsonb(pg_temp.u('x1')::text), 34), 'ok', 'AIG1-3: she corrects the value');
select ok((select responsible_user_id = pg_temp.u('x1') from public.care_visits where id = pg_temp.v(3))
          and (select outcome = 'corrected' from public.ai_confirmations where suggestion_id = pg_temp.sug(3))
          and (select proposed_value = to_jsonb(pg_temp.u('p')::text) from public.ai_suggestions where id = pg_temp.sug(3)),
  'AIG1-3: the record holds her value; the proposal stays in the ledger as corrected');
select ok(pg_temp.propose('ca', 4, 35) is not null, 'fixture: a proposal for visit 4');
select is(pg_temp.confirm('ca', 4, 'rejected', null, 36), 'ok', 'AIG1-3: she rejects the value');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(4)), null::uuid,
  'AIG1-3: a rejected value never reaches the record');
update public.cases set primary_nurse_id = pg_temp.u('ca') where id = '00000000-0000-4000-a000-000000000208';
select ok(pg_temp.propose('p', 5, 37) is not null, 'fixture: the agent proposes the care assistant for a B visit');
select is(pg_temp.cmd('p', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug(5), 'confirmed', pg_temp.k(38))),
  '{"result": "refused", "reason": "not_qualified"}'::jsonb,
  'AIG1-5 / J3: the consuming command refuses a B visit for a care assistant; the reason is returned');
select ok((select responsible_user_id is null from public.care_visits where id = pg_temp.v(5))
          and not exists (select 1 from public.ai_confirmations where suggestion_id = pg_temp.sug(5)),
  'AIG1-3: a refused value writes neither the record nor a confirmation');

-- AIG1-4: not_found ---------------------------------------------------------------------------------------------------------
update public.cases set primary_nurse_id = null where id = '00000000-0000-4000-a000-000000000208';
select is(pg_temp.cmd('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(7), pg_temp.k(40))) ->> 'not_found',
  'true', 'AIG1-4: no primary nurse: the agent returns not_found');
select ok((select not_found and proposed_value is null from public.ai_suggestions where id = pg_temp.sug(7)),
  'AIG1-4: the ledger holds not_found, never an empty value');
select is(pg_temp.err('ca', format('select public.confirm_suggestion(%L, %L, %L::jsonb, %L)', pg_temp.sug(7), 'corrected', '""',
                                   pg_temp.k(41))), '22023', 'AIG1-4: not_found cannot be turned into an empty value');
select is(pg_temp.err('ca', format('select public.confirm_suggestion(%L, %L, null, %L)', pg_temp.sug(7), 'confirmed', pg_temp.k(42))),
  '22023', 'AIG1-4: not_found cannot be confirmed as a value');
select is(pg_temp.confirm('ca', 7, 'not_found', null, 43), 'ok', 'AIG1-4: not_found is confirmed as "nicht gefunden"');
select ok((select responsible_user_id is null from public.care_visits where id = pg_temp.v(7))
          and (select status = 'nicht gefunden' from public.value_provenance('care_visits', pg_temp.v(7), 'responsible_user_id')),
  'AIG1-4: the record stays empty and the line reads "nicht gefunden"');
update public.cases set primary_nurse_id = pg_temp.u('p') where id = '00000000-0000-4000-a000-000000000208';

-- AIG1-5: field classes and bulk confirm ------------------------------------------------------------------------------------
select throws_ok($$ insert into public.ai_agent_fields values ('aig1_test_g', 'plan_item', 'care_plan_items', 'minutes',
                   'schedule', 'AIG1', 'cra test') $$, '42501', null, 'AIG1-5 (e): a care-plan field is never schedule');
select throws_ok($$ insert into public.ai_agent_fields values ('aig1_test_g', 'order_status', 'cases', 'medical_order_status',
                   'schedule', 'AIG1', 'cra test') $$, '42501', null, 'AIG1-5 (e): a medical-order field is never schedule');
select throws_ok($$ insert into public.ai_agent_fields values ('aig1_test_g', 'alert', 'case_safety_alert_values', 'value',
                   'schedule', 'AIG1', 'cra test') $$, '42501', null, 'AIG1-5 (e): a safety-alert field is never schedule');
select throws_ok($$ insert into public.ai_agent_fields values ('aig1_test_g', 'assessment', 'assessment_records', 'minutes',
                   'schedule', 'AIG1', 'cra test') $$, '42501', null, 'AIG1-5 (e): an assessment field is never schedule');
select ok(not exists (select 1 from unnest(array['visit_date', 'time_start', 'team_id', 'planned_minutes_b', 'is_needs_assessment']) c
                          where private.aig1_never_schedule('care_visits', c) is null),
  'AIG1-5 (e) / CGR-78 (a): a visit''s date, time, team, minutes or category is never schedule');
select throws_ok($$ insert into public.ai_agent_fields values ('aig1_test_g', 'visit_day', 'care_visits', 'visit_date',
                   'schedule', 'AIG1', 'cra test') $$, '42501', null, 'AIG1-5 (e): the visit date field is refused as schedule');
select throws_ok($$ insert into public.ai_agent_fields values ('aig1_test_g', 'visit_team', 'care_visits', 'team_id',
                   'schedule', 'AIG1', 'cra test') $$, '42501', null, 'AIG1-5 (e): the visit team field is refused as schedule');
select throws_ok($$ insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
                   values ('aig1_test_g', 'unnamed', 'care_visits', 'responsible_user_id', 'schedule') $$, '23514', null,
  'AIG1-5: schedule needs the brief and the cra reference that confirmed it');
-- (a) a record field in the list
insert into public.ai_agent_fields values ('aig1_test_primary_nurse', 'visit_note', 'care_visits', 'notes', 'record', null, null);
insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field, entity_type,
                                   entity_id, input_refs, proposed_value)
values (gen_random_uuid(), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101',
        '00000000-0000-4000-a000-000000000208', 'aig1_test_primary_nurse', '1', 'visit_note', 'care_visits', pg_temp.v(20),
        jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', pg_temp.v(20))), '"synthetisch"');
select ok(pg_temp.propose('ca', 8, 50) is not null and pg_temp.propose('ca', 9, 51) is not null
          and pg_temp.propose('ca', 10, 52) is not null, 'fixture: three schedule proposals (visits 8, 9, 10)');
select is(pg_temp.err('ca', format('select public.confirm_suggestions(%L::uuid[], %L)', array[pg_temp.sug(8), pg_temp.sug(20)], pg_temp.k(53))),
  '42501', 'AIG1-5 (a): a bulk confirm containing a record field is refused');
select ok(not exists (select 1 from public.ai_confirmations where suggestion_id in (pg_temp.sug(8), pg_temp.sug(20))),
  'AIG1-5 (a): a refused bulk confirms nothing');
-- (b) schedule fields of the level-L rule agent: two ticked of three
select is(pg_temp.bulk('ca', array[8, 10], 54) - 'refused', '{"result": "ok", "confirmed": 2}'::jsonb,
  'AIG1-5 (b): two ticked of three are confirmed, exactly two');
select is((select count(*)::int from public.ai_confirmations where suggestion_id in (pg_temp.sug(8), pg_temp.sug(10))
           and bulk and outcome = 'confirmed' and confirmed_by = pg_temp.u('ca')), 2,
  'AIG1-5 (b): one confirmation row per value, each with confirmer and time');
select ok(not exists (select 1 from public.ai_confirmations where suggestion_id = pg_temp.sug(9))
          and (select count(*) = 2 from public.audit_events where table_name = 'ai_confirmations' and actor_id = pg_temp.u('ca')
               and idempotency_key = pg_temp.k(54)),
  'AIG1-5 (b): the unticked line stays open; each value is audited');
-- (c) a value of a G or ai agent
insert into public.ai_agent_fields values ('aig1_test_g', 'responsible_user_id', 'care_visits', 'responsible_user_id', 'schedule',
                                           'AIG1', 'synthetic'),
                                          ('aig1_test_ai', 'responsible_user_id', 'care_visits', 'responsible_user_id', 'schedule',
                                           'AIG1', 'synthetic');
insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field, entity_type,
                                   entity_id, input_refs, proposed_value)
select gen_random_uuid(), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101',
       '00000000-0000-4000-a000-000000000208', a, '1', 'responsible_user_id', 'care_visits', pg_temp.v(n),
       jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', pg_temp.v(n))), to_jsonb(pg_temp.u('p')::text)
from (values ('aig1_test_g', 21), ('aig1_test_ai', 22)) x(a, n);
select is(pg_temp.err('ca', format('select public.confirm_suggestions(%L::uuid[], %L)', array[pg_temp.sug(9), pg_temp.sug(21)], pg_temp.k(55))),
  '42501', 'AIG1-5 (c): a value of a level-G agent is refused in bulk');
select is(pg_temp.err('ca', format('select public.confirm_suggestions(%L::uuid[], %L)', array[pg_temp.sug(22)], pg_temp.k(56))),
  '42501', 'AIG1-5 (c): a value of an ai agent is refused in bulk');
-- (d) the organisation's one-by-one list
insert into public.ai_one_by_one_fields (organization_id, agent_key, field)
values ('00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', 'responsible_user_id');
select is(pg_temp.err('ca', format('select public.confirm_suggestions(%L::uuid[], %L)', array[pg_temp.sug(9)], pg_temp.k(57))),
  '42501', 'AIG1-5 (d): a schedule field on the organisation''s one-by-one list is refused in bulk');
select is(pg_temp.rows('ca', format('select bulk_allowed from public.open_suggestions(%L) where suggestion_id = %L',
                                    '00000000-0000-4000-a000-000000000101', pg_temp.sug(9))), '[{"bulk_allowed": false}]'::jsonb,
  'AIG1-5 (d): the confirm screen shows the line as one by one');
delete from public.ai_one_by_one_fields;
select is(pg_temp.err('ca', format('select public.confirm_suggestions(%L::uuid[], %L)', array[pg_temp.sug(7)], pg_temp.k(58))),
  '42501', 'AIG1-4/-5: "nicht gefunden" is never confirmed in bulk');

-- AIG1-7: correction rate per agent, field and team; small cells suppressed -----------------------------------------------
select is(pg_temp.rows('ca', format('select proposals, confirmed_unchanged, suppressed from public.agent_correction_rates(%L) '
                                    'where agent_key = %L and field = %L', pg_temp.t(), 'aig1_test_primary_nurse', 'responsible_user_id')),
  '[{"proposals": 9, "suppressed": true, "confirmed_unchanged": null}]'::jsonb,
  'AIG1-7: two confirmers in the cell: only the proposal count is shown');
select ok(pg_temp.propose('ca', 11, 60) is not null, 'fixture: a proposal for visit 11');
select is(pg_temp.confirm('x2', 11, 'confirmed', null, 61), 'ok', 'fixture: a third person confirms one value');
select is(pg_temp.rows('ca', format('select proposals, confirmed_unchanged, corrected, rejected, not_found, suppressed '
                                    'from public.agent_correction_rates(%L) where agent_key = %L and field = %L',
                                    pg_temp.t(), 'aig1_test_primary_nurse', 'responsible_user_id')),
  '[{"proposals": 10, "corrected": 1, "rejected": 1, "not_found": 1, "suppressed": false, "confirmed_unchanged": 4}]'::jsonb,
  'AIG1-7: with three confirmers the cell shows proposals, unchanged, corrected, rejected, not_found');
select is((select count(*)::int from unnest((select proargnames from pg_proc where oid = 'public.agent_correction_rates(date)'::regprocedure)) a
           where a ~ '(confirm|user|person|member|actor|by$|name$)' and a not in ('team_name', 'agent_name', 'confirmed_unchanged')), 0,
  'AIG1-7: the reader has no person column or filter');
select is(jsonb_array_length(pg_temp.rows('ops', format('select * from public.agent_correction_rates(%L) where team_name = %L and agent_key = %L and field = %L',
                                                        pg_temp.t(), 'Testteam Nord', 'aig1_test_primary_nurse', 'responsible_user_id'))), 1, 'AIG1-7: Operations reads the Nord row');
select is(jsonb_array_length(pg_temp.rows('m', format('select * from public.agent_correction_rates(%L)', pg_temp.t()))), 0,
  'AIG1-7: a member of another team reads no Nord row');
select is(jsonb_array_length(pg_temp.rows('fremd', format('select * from public.agent_correction_rates(%L)', pg_temp.t()))), 0,
  'AIG1-7: another organisation reads nothing');

-- AIG1-8: a version change stops the agent; OPS1; AIG1-12 look-back ------------------------------------------------------
update public.ai_agent_definitions set version = '2' where key = 'aig1_test_primary_nurse';
select is(pg_temp.res('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(12), pg_temp.k(70))), 'agent_stopped',
  'AIG1-8: a changed version stops the agent');
select ok((select state = 'stopped' from public.ai_agent_settings where agent_key = 'aig1_test_primary_nurse' and organization_id = '00000000-0000-4000-b000-000000000011')
          and not exists (select 1 from public.ai_suggestions where entity_id = pg_temp.v(12))
          and (select reason = 'version_changed' from public.ai_agent_stops order by seq desc limit 1),
  'AIG1-8: state stopped, reason version_changed, and no new ledger row');
create temp table stop1 as select id from public.ai_agent_stops order by seq desc limit 1;
select is(pg_temp.rows('ops', format('select label, detail from public.operations_exceptions() where exception_key = %L',
                                     'agent_stopped:' || (select id from stop1))),
  '[{"label": "Assistent gestoppt", "detail": "Testassistent Bezugspflege · 4 offen · 0 nicht mehr offen"}]'::jsonb,
  'AIG1-8 / AIG1-C1: one OPS1 exception "Assistent gestoppt" names the agent, the open look-back lines and those of visits no longer open');
select is((select string_agg(e ->> 'entity_id', ',' order by e ->> 'entity_id')
           from jsonb_array_elements(pg_temp.rows('ops', format('select entity_id from public.agent_stop_lookback(%L)', (select id from stop1)))) e),
  (select string_agg(x::text, ',' order by x::text) from unnest(array[pg_temp.v(1), pg_temp.v(8), pg_temp.v(10), pg_temp.v(11)]) x),
  'AIG1-12: the look-back lists exactly the records with a value confirmed unchanged since the switch-on');
select is((select count(*)::int from unnest((select proargnames from pg_proc where oid = 'public.agent_stop_lookback(uuid)'::regprocedure)) a
           where a ~ '(confirm|outcome|status|user|person|member|actor|by$|nurse)'), 0,
  'AIG1-12 (i): the look-back has no person and no outcome column');
select is(jsonb_array_length(pg_temp.rows('m', format('select * from public.agent_stop_lookback(%L)', (select id from stop1)))), 0,
  'AIG1-12 (iii): a member of another team gets no line of a record she cannot read');
select is(pg_temp.confirm('p', 1, 'confirmed', null, 71), 'ok', 'AIG1-12 (iv): she re-checks one value through the confirm command');
select ok(not exists (select 1 from jsonb_array_elements(pg_temp.rows('ca', format('select entity_id from public.agent_stop_lookback(%L)',
                                                                                    (select id from stop1)))) e
                      where e ->> 'entity_id' = pg_temp.v(1)::text),
  'AIG1-12 (iv): the re-checked record leaves the list');
-- AIG1-13 (b): the record no longer holds a listed value (assigned by hand meanwhile): labelled, not removed
update public.care_visits set responsible_user_id = pg_temp.u('x1') where id = pg_temp.v(10);
select is(pg_temp.rows('ops', format('select superseded, superseded_at is not null as dated from public.agent_stop_lookback(%L) '
                                     'where entity_id = %L', (select id from stop1), pg_temp.v(10))),
  '[{"dated": true, "superseded": true}]'::jsonb, 'AIG1-13 (b): a superseded listed value stays on the list, "überholt am <Datum>"');
select is(pg_temp.rows('ops', format('select detail from public.operations_exceptions() where exception_key = %L',
                                     'agent_stopped:' || (select id from stop1))),
  '[{"detail": "Testassistent Bezugspflege · 2 offen · 0 nicht mehr offen"}]'::jsonb,
  'AIG1-13 (b): re-checked and superseded lines are not counted as open');

-- AIG1-8: restart (on T+1), then a closed window over the threshold stops it ------------------------------------------------
select pg_temp.at((pg_temp.t() + 1) + time '07:00');
select is(pg_temp.res('admin', format('select public.set_agent_state(%L, %L, true, 50, 2, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse', pg_temp.k(72))), 'ok',
  'AIG1-8: restarting is a new audited switch-on');
select is((select count(*)::int from private.derived_exceptions('00000000-0000-4000-b000-000000000011') where exception_type = 'agent_stopped'), 0,
  'AIG1-8: the OPS1 exception closes with its cause');
select ok(pg_temp.propose('ca', 13, 73) is not null and pg_temp.propose('ca', 14, 74) is not null
          and pg_temp.propose('ca', 15, 75) is not null, 'fixture: three proposals in the new window');
select is(pg_temp.err('ca', format('select public.confirm_suggestions(%L::uuid[], %L)', array[pg_temp.sug(13), pg_temp.sug(8)], pg_temp.k(81))),
  '42501', 'AIG1-13 (a): a bulk confirm containing a look-back value is refused');
select ok(not exists (select 1 from public.ai_confirmations where suggestion_id = pg_temp.sug(13))
          and (select count(*) = 1 from public.ai_confirmations where suggestion_id = pg_temp.sug(8)),
  'AIG1-13 (a): the refused bulk writes nothing');
select ok(pg_temp.confirm('ca', 13, 'rejected', null, 76) = 'ok' and pg_temp.confirm('ca', 14, 'rejected', null, 77) = 'ok'
          and pg_temp.confirm('ca', 15, 'confirmed', null, 78) = 'ok', 'fixture: two rejected, one confirmed (share 66.67)');
select is(pg_temp.res('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(16), pg_temp.k(79))), 'ok',
  'AIG1-8: the window is still open: the agent keeps proposing');
select pg_temp.at((pg_temp.t() + 8) + time '07:00');
select is(pg_temp.res('ca', format('select public.propose_visit_responsible(%L, %L)', pg_temp.v(17), pg_temp.k(80))), 'agent_stopped',
  'AIG1-8: the closed window crossed the threshold: stopped');
select ok((select reason = 'threshold' and decided = 3 and share = 66.67 from public.ai_agent_stops order by seq desc limit 1)
          and not exists (select 1 from public.ai_suggestions where entity_id = pg_temp.v(17)),
  'AIG1-8: the stop records the window''s counts; no new ledger row');
select is((select string_agg(e ->> 'entity_id', ',')
           from jsonb_array_elements(pg_temp.rows('ops', format('select entity_id from public.agent_stop_lookback(%L)',
                                                                (select id from public.ai_agent_stops order by seq desc limit 1)))) e),
  pg_temp.v(15)::text, 'AIG1-12 (ii): the look-back holds only the window''s unchanged confirmation');
select is(pg_temp.rows('ops', format('select state, stop_reason from public.agent_health(%L) where agent_key = %L',
                                     '00000000-0000-4000-b000-000000000011', 'aig1_test_primary_nurse')),
  '[{"state": "stopped", "stop_reason": "threshold"}]'::jsonb, 'AIG1-10: the health list shows the state and why it stopped');
select is(jsonb_array_length(pg_temp.rows('ca', format('select * from public.agent_health(%L)', '00000000-0000-4000-b000-000000000011'))), 0,
  'AIG1-10: a team member without a coordination role reads no health list');

-- AIG1-9: every agent's fixture meets its bar ----------------------------------------------------------------------------------
create function pg_temp.eval_share(p_fixture text) returns numeric language plpgsql as $$
declare r numeric;
begin
  execute format('select round(100.0 * count(*) filter (where expected is not distinct from actual) / nullif(count(*), 0), 2) '
                 'from private.%I()', p_fixture) into r;
  return r;
end $$;
select is((select string_agg(d.key, ',') from public.ai_agent_definitions d
           where d.fixture is not null
             and (to_regprocedure('private.' || d.fixture || '()') is null or pg_temp.eval_share(d.fixture) < d.eval_bar)), null,
  'AIG1-9: every agent with a fixture meets its evaluation bar on synthetic cases');

-- AIG1-11 (4) and Negative: catalogue ----------------------------------------------------------------------------------------
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
             and p.prosrc ~ 'public\.ai_confirmations'
             and (p.prosrc ~ '(member_name|display_name)\([^;]*confirmed_by'
                  or exists (select 1 from unnest(p.proargnames, p.proargmodes) a(nm, md)
                             where md in ('t', 'o') and nm ~ '^(confirmer|confirmed_by|actor)'))),
  'value_provenance', 'AIG1-11 (4): the confirmer is returned only by value_provenance (plus the AUD1 reader on audit_events)');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prosrc ~ 'ai_(suggestions|confirmations|agent)'
             and p.prosrc ~* '(net\.http|http_post|pg_net|https?://)'), 0,
  'Negative: no AIG1 function calls an outside service');

select * from finish();
rollback;
