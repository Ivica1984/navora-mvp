-- BK-e2 Abschlusspaket (PO package contract 2026-11-19 16:40, point 5: pgTAP «ledger: own team only, append-only, no
-- text column filled»; negatives «no threshold row, non-simulation organisation, other team»), ADR-215, migration 0151.
--
-- What it guards:
--   * registration: `report_draft_model` is kind ai, level G, provider anthropic, region us, and `set_agent_state`
--     still refuses to switch it on (D-35 rule A unchanged);
--   * the key and the stop-rule table have no grant; without a threshold row the model is closed (the shipped `cra`
--     simulation row of 0153, pinned in pgTAP 153, is removed inside this transaction to prove it);
--   * the gate and the record command refuse: non-simulation organisation, no threshold row, other organisation's
--     member, a team member who is not the performer, a signed report; and the stop rule once the correction share of
--     the window exceeds the threshold;
--   * a recorded proposal: one ledger row per line, no text (keys exactly line_index, sources, digest, length, model;
--     the digest is keyed, not the plain SHA-256 of the line), input references = report and visit; a repeat of the key
--     returns the same rows; append-only; no direct read for app roles;
--   * a decision: one line per call, never bulk; confirmed only with the unchanged text, corrected only with a changed
--     text, rejected without text; only the performer, only on a draft;
--   * `aia` AUT-158 check 9 (ADR-217): the model agent's lines are counted by the AIG1 reader `agent_correction_rates`
--     per agent, field and team, with no person column; one confirmer is under three, so the cell is suppressed; a
--     member of another organisation sees no cell.
-- The stop-rule row written here is a synthetic test fixture (share 50, minimum 4, window 30 days), not a clinical
-- threshold. All data synthetic; rolled back.
-- Seed users: Testorganisation S …019 (simulation, Testteam Basel …1b9): pflegebs …9e6 (performer), assistbs …9e7 (same
-- team). Testorganisation A …011 (not a simulation, Testteam Nord …101): pflege …902 (performer of report 3), admin …905.
-- `organizations.simulation` is set only by a migration or the seed (CGR-177), so the two organisations are the fixtures.
begin;
create extension if not exists pgtap with schema extensions;

select plan(42);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-0000000009e6' when 'a' then '00000000-0000-4000-a000-0000000009e7'
                 when 'c' then '00000000-0000-4000-a000-000000000902' when 'admin' then '00000000-0000-4000-a000-000000000905'
          end)::uuid $$;
create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('a1510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1511000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.gate(p_user text, p_report int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.report_draft_model_gate(%L)', pg_temp.id(p_report))) $$;
-- 0170 (#1697 R7): a proposal names its call's reservation; key n uses the fixture reservation id(900 + n) (below).
create function pg_temp.rec(p_user text, p_report int, p_lines jsonb, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.record_report_draft_proposal(%L, %L, %L, %L::jsonb, %L)',
    pg_temp.id(p_report), pg_temp.id(900 + p_key), 'claude-test-model', p_lines, pg_temp.k(p_key))) $$;
create function pg_temp.dec(p_user text, p_sid uuid, p_outcome text, p_text text, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.decide_report_draft_line(%L, %L, %L, %L)',
    p_sid, p_outcome, p_text, pg_temp.k(p_key))) $$;
create function pg_temp.sid(p_key int, p_line int) returns uuid language sql as $$
  select s.id from public.ai_suggestions s
  where s.proposal_id = pg_temp.k(p_key) and (s.proposed_value ->> 'line_index')::int = p_line $$;
create function pg_temp.rows() returns int language sql as $$
  select count(*)::int from public.ai_suggestions where agent_key = 'report_draft_model' $$;

-- Fixtures (as the table owner) ----------------------------------------------------------------------------------------------
-- Org S: a synthetic case, two visits, an open draft (1) and a signed report (2) by 9e6. Org A: an open draft (3) by 902.
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(200), 'Synth Klientin L151', 'Synth', 'L151', 'Basel-Stadt',
        'laufend', 'mittel', '00000000-0000-4000-a000-0000000001b9');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b)
select '00000000-0000-4000-b000-000000000019', pg_temp.id(100 + n), pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9',
       (private.now() at time zone 'Europe/Zurich')::date + 2, time '08:00' + make_interval(hours => n),
       time '08:30' + make_interval(hours => n), 'planned', 30, 0
from generate_series(1, 2) n;
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.id(103), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date - 1, '08:00', '08:30',
        array['Grundpflege'], false, 'completed', 30, 0, pg_temp.u('c'));
insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by, signed_by, signed_at)
select o, pg_temp.id(n), pg_temp.id(100 + n), c, t, 1, case n when 2 then 'signed' else 'draft' end, '{"synthetic": true}'::jsonb,
       pf, false, pf, case n when 2 then pf end, case n when 2 then private.now() end
from (values (1, '00000000-0000-4000-b000-000000000019'::uuid, pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9'::uuid, pg_temp.u('p')),
             (2, '00000000-0000-4000-b000-000000000019'::uuid, pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9'::uuid, pg_temp.u('p')),
             (3, '00000000-0000-4000-b000-000000000011'::uuid, '00000000-0000-4000-a000-000000000208'::uuid,
                 '00000000-0000-4000-a000-000000000101'::uuid, pg_temp.u('c'))) f(n, o, c, t, pf);
-- 0170 (#1697 R7): the two proposals on report 1 (keys 10, 30) each need a reserved call settled ok. Synthetic fixture
-- rows as the table owner (the reservation path itself is pgTAP 166/170); version = the current agent version.
insert into private.model_call_reservations (id, organization_id, team_id, function_key, report_id, attempt, idempotency_key,
                                             zurich_day, reserved_micro_chf, settled_at, outcome, settled_micro_chf,
                                             cost_basis, agent_version)
select pg_temp.id(900 + key), '00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000001b9',
       'report_draft_model', pg_temp.id(1), att, pg_temp.k(800 + key), (private.at_zurich(private.now()))::date, 0,
       private.now(), 'ok', 0, 'measured_tokens',
       (select d.version from public.ai_agent_definitions d where d.key = 'report_draft_model')
from (values (10, 1), (30, 2)) v(key, att);

-- 1. Registration and grants -----------------------------------------------------------------------------------------------
select is((select jsonb_build_object('kind', kind, 'level', level, 'provider', provider, 'region', region)
           from public.ai_agent_definitions where key = 'report_draft_model'),
          '{"kind": "ai", "level": "G", "provider": "anthropic", "region": "us"}'::jsonb,
  'ADR-215: report_draft_model is registered as kind ai, level G, provider anthropic, region us');
select is((select target_table || '.' || target_column || ':' || class from public.ai_agent_fields
           where agent_key = 'report_draft_model' and field = 'summary_line'),
          'visit_reports.summary:record', 'ADR-215: its one field is the report summary, class record');
select is(pg_temp.cmd('admin', format('select public.set_agent_state(%L, %L, true, 10, 5, 7, %L)',
            '00000000-0000-4000-b000-000000000011', 'report_draft_model', pg_temp.k(900))) ->> 'reason',
          'ai_not_allowed', 'D-35 rule A unchanged: set_agent_state still refuses to switch the model agent on');
select is((select count(*)::int from public.ai_agent_settings where agent_key = 'report_draft_model'), 0,
  'no organisation has a setting row for the model agent');
select ok(not has_table_privilege('authenticated', 'private.report_draft_ledger_key', 'select')
          and not has_table_privilege('authenticated', 'public.report_draft_stop_rules', 'select')
          and not has_table_privilege('authenticated', 'public.report_draft_stop_rules', 'insert'),
  'no grant on the HMAC key or the stop-rule table for app users');
select is((select count(*)::int from private.report_draft_ledger_key where octet_length(key) = 32), 1,
  'one 32-byte key, generated in the database');
-- 0153 ships the cra simulation row (pinned in pgTAP 153). To keep proving the fail-closed path, this transaction removes
-- it first (rolled back at the end); the fixture below then sets its own synthetic values.
delete from public.report_draft_stop_rules where agent_key = 'report_draft_model';
select is((select count(*)::int from public.report_draft_stop_rules), 0,
  'AUT-152 test setup: with the shipped row removed in this transaction, the table is empty');

-- 2. Gate refusals before any ledger row ---------------------------------------------------------------------------------
select is(pg_temp.gate('c', 3) ->> 'reason', 'not_simulation_org',
  'negative: the performer of an open draft in an organisation that is not a simulation gets no model draft');
select is(pg_temp.gate('p', 1), '{"result": "ok", "open": false, "reason": "no_threshold"}'::jsonb,
  'AUT-152: no threshold row: the model stays closed (fail closed)');
select is(pg_temp.rec('p', 1, '[{"text": "Patientin mobilisiert.", "sources": ["s1"]}]', 1) ->> 'reason', 'no_threshold',
  'AUT-152: the record command refuses too without a threshold row');
select is(pg_temp.rows(), 0, 'no ledger row was written while the model is closed');

-- Synthetic test fixture (not a clinical value): share 50, minimum 4 decided lines, window 30 days.
insert into public.report_draft_stop_rules (agent_key, stop_share, stop_min_decided, stop_window_days, cra_ref)
values ('report_draft_model', 50, 4, 30, 'pgTAP 151 synthetic fixture');
select is(pg_temp.gate('p', 1), '{"result": "ok", "open": true, "reason": null}'::jsonb,
  'with a threshold row the performer of the open draft may get a model draft');
select is(pg_temp.gate('a', 1) ->> 'reason', 'not_performer', 'negative: a team member who is not the performer is refused');
select is(pg_temp.gate('c', 1) ->> 'reason', 'not_team_member', 'negative: a member of another organisation is refused');
select is(pg_temp.gate('c', 3) ->> 'reason', 'not_simulation_org', 'negative: still closed outside a simulation organisation');
select is(pg_temp.gate('p', 2) ->> 'reason', 'not_draft', 'negative: a signed report gets no model draft');
select is(pg_temp.rec('c', 1, '[{"text": "Patientin mobilisiert.", "sources": ["s1"]}]', 2) ->> 'reason', 'not_team_member',
  'negative: another organisation''s member cannot write into this team''s ledger');
select throws_ok(format($$ select public.record_report_draft_proposal(%L, %L, 'm', '[{"text": "x", "sources": []}]', %L) $$,
                        pg_temp.id(1), pg_temp.id(910), pg_temp.k(3)), '22023', null, 'a line without a source is refused');

-- 3. A recorded proposal: no text ----------------------------------------------------------------------------------------
select is(pg_temp.rec('p', 1, '[{"text": "Patientin um 08:10 mobilisiert.", "sources": ["s1", "f1"]},
                                {"text": "Verband gewechselt.", "sources": ["s2"]}]', 10) ->> 'result', 'ok',
  'the performer records a two-line model draft');
select is(pg_temp.rows(), 2, 'one ledger row per line');
select is((select string_agg(distinct k, ',' order by k) from public.ai_suggestions s, jsonb_object_keys(s.proposed_value) k
           where s.proposal_id = pg_temp.k(10)), 'digest,length,line_index,model,sources',
  'contract point 4: the value holds only line_index, sources, digest, length and model');
select is((select count(*)::int from public.ai_suggestions s where s.proposal_id = pg_temp.k(10)
           and (s.proposed_value::text ~ 'mobilisiert|Verband' or s.input_refs::text ~ 'mobilisiert|Verband')), 0,
  'no text of a line is in the ledger');
select is((select s.proposed_value ->> 'digest' = encode(extensions.digest('Patientin um 08:10 mobilisiert.', 'sha256'), 'hex')
           from public.ai_suggestions s where s.id = pg_temp.sid(10, 0)), false,
  'the digest is keyed (HMAC), not the plain SHA-256 of the line');
select is((select jsonb_build_object('len', (s.proposed_value ->> 'length')::int, 'src', s.proposed_value -> 'sources',
                                     'hex', s.proposed_value ->> 'digest' ~ '^[0-9a-f]{64}$')
           from public.ai_suggestions s where s.id = pg_temp.sid(10, 0)),
          '{"len": 31, "src": ["f1", "s1"], "hex": true}'::jsonb, 'length, source ids and a 64-hex digest per line');
select is((select s.input_refs from public.ai_suggestions s where s.id = pg_temp.sid(10, 1)),
          jsonb_build_array(jsonb_build_object('table', 'visit_reports', 'id', pg_temp.id(1)),
                            jsonb_build_object('table', 'care_visits', 'id', pg_temp.id(101))),
  'input references are the report and its visit (identifiers only)');
select is((pg_temp.rec('p', 1, '[{"text": "Patientin um 08:10 mobilisiert.", "sources": ["s1", "f1"]},
                                 {"text": "Verband gewechselt.", "sources": ["s2"]}]', 10) -> 'lines' -> 1 ->> 'suggestion_id')::uuid,
          pg_temp.sid(10, 1), 'a repeat of the key returns the same rows');
select is(pg_temp.rows(), 2, 'and writes no new row');
select throws_ok(format($$ update public.ai_suggestions set proposed_value = '{}'::jsonb where id = %L $$, pg_temp.sid(10, 0)),
  '42501', null, 'the ledger is append-only (update refused)');
select pg_temp.act_as(pg_temp.u('p'));
set local role authenticated;
select throws_ok($$ select count(*) from public.ai_suggestions $$, '42501', null, 'app users cannot read the ledger directly');
reset role;

-- 4. Decisions, one line per call ----------------------------------------------------------------------------------------
select is(pg_temp.dec('p', pg_temp.sid(10, 0), 'confirmed', 'Patientin um 08:10 nicht mobilisiert.', 20) ->> 'reason',
          'text_changed', 'confirmed needs the unchanged text');
select is(pg_temp.dec('p', pg_temp.sid(10, 0), 'confirmed', 'Patientin um 08:10 mobilisiert.', 21) ->> 'result', 'ok',
  'the performer confirms the first line unchanged');
select is(pg_temp.dec('a', pg_temp.sid(10, 1), 'rejected', null, 22) ->> 'reason', 'not_performer',
  'negative: a team member who is not the performer cannot decide');
select is(pg_temp.dec('p', pg_temp.sid(10, 1), 'corrected', 'Verband am linken Bein gewechselt.', 23) ->> 'result', 'ok',
  'the performer corrects the second line');
select throws_ok(format($$ select public.decide_report_draft_line(%L, 'rejected', 'x', %L) $$, pg_temp.sid(10, 1), pg_temp.k(24)),
  '22023', null, 'a rejected line carries no text');
select is((select jsonb_build_object('bulk', bool_or(c.bulk), 'same', bool_and(c.final_value ->> 'digest' = s.proposed_value ->> 'digest')
                                                      filter (where c.outcome = 'confirmed'),
                                     'textless', bool_and(c.final_value::text !~ 'mobilisiert|Verband'))
           from public.ai_confirmations c join public.ai_suggestions s on s.id = c.suggestion_id
           where s.proposal_id = pg_temp.k(10)),
          '{"bulk": false, "same": true, "textless": true}'::jsonb,
  'never bulk; a confirmed value carries the proposed digest; no decision stores text');

-- 5. Stop rule (threshold 50 %, minimum 4): decided so far confirmed + corrected; then rejected, rejected -> 3 of 4 = 75 %
select is(pg_temp.rec('p', 1, '[{"text": "Puls 72.", "sources": ["s3"]}, {"text": "Blutdruck 120/80.", "sources": ["s4"]}]', 30)
          ->> 'result', 'ok', 'a second proposal is recorded');
select is((pg_temp.dec('p', pg_temp.sid(30, 0), 'rejected', null, 31) ->> 'result') || ',' || (pg_temp.gate('p', 1) ->> 'open'),
          'ok,true', 'with 3 decided lines (below the minimum of 4) the model stays open');
select is(pg_temp.dec('p', pg_temp.sid(30, 1), 'rejected', null, 32) ->> 'result', 'ok', 'the fourth line is rejected');
select is((pg_temp.gate('p', 1) ->> 'reason') || ',' || (pg_temp.rec('p', 1, '[{"text": "Puls 72.", "sources": ["s3"]}]', 40)
          ->> 'reason'), 'stop_rule,stop_rule',
  'AUT-152: once the correction share of the window (75 %) exceeds the threshold, gate and record command close the model');

-- 6. aia check 9: correction rate per agent, field and team, never per person (AIG1-7 reader, 0097) ----------------------
select is(pg_temp.cmd('p', format($q$ select jsonb_build_object('cells', count(*), 'proposals', sum(proposals),
                                       'suppressed', bool_and(suppressed), 'corrected', max(corrected))
                                     from public.agent_correction_rates(%L)
                                     where agent_key = 'report_draft_model' and field = 'summary_line' and team_id = %L $q$,
            (select private.at_zurich(created_at)::date from public.ai_suggestions where id = pg_temp.sid(10, 0)),
            '00000000-0000-4000-a000-0000000001b9')),
          '{"cells": 1, "proposals": 4, "suppressed": true, "corrected": null}'::jsonb,
  'check 9: the team reads one cell for report_draft_model / summary_line with all four lines; one confirmer -> suppressed');
select is(pg_temp.cmd('c', format($q$ select count(*)::int from public.agent_correction_rates(%L)
                                     where agent_key = 'report_draft_model' $q$,
            (select private.at_zurich(created_at)::date from public.ai_suggestions where id = pg_temp.sid(10, 0)))),
          '0'::jsonb, 'check 9 negative: a member of another organisation sees no cell of this team');
select is((select array_agg(u.n order by u.o)
           from pg_proc p, unnest(p.proargnames, p.proargmodes) with ordinality u(n, m, o)
           where p.proname = 'agent_correction_rates' and p.pronamespace = 'public'::regnamespace and u.m = 't'),
          array['team_id', 'team_name', 'agent_key', 'agent_name', 'field', 'month', 'proposals', 'confirmed_unchanged',
                'corrected', 'rejected', 'not_found', 'suppressed'],
  'check 9: the reader has no person column');

select * from finish();
rollback;
