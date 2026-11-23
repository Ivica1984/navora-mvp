-- AI1 (PO package contract 2026-11-22 08:39, fixed residual list item 1; ADR-227 points 1, 2, 3, 5), migration 0166.
--
-- What it guards:
--   * catalogue: the four new tables have RLS on and no privilege for any API role; the shipped limits row is 300 calls
--     per day and CHF 50 per month with no price (fail closed);
--   * no reviewed price reading → every reservation is refused (`price_missing`) and nothing is counted;
--   * with a synthetic price fixture (rolled back; not a price reading): the performer reserves attempt 1; a repeat of the
--     key returns the same reservation and counts nothing (double tap = one call, T-2); a second key is attempt 2; a third
--     is refused (`attempt_limit`);
--   * refusals with the gate's own reasons: a team member who is not the performer, another organisation's member, a
--     non-simulation organisation, a signed report; the database switch for one organisation and for all (gate, record
--     command and reservation close on the next call), and clearing it opens again;
--   * the global day cap and the month cap (serialisation proof in one session under the advisory lock; the two-session
--     race is OPEN, see ADR-227 tests);
--   * settle: only the performer, once; the organisation comes from the reservation, so another organisation's member
--     cannot change this budget; measured tokens replace the reserve; nothing measured keeps the reserve;
--   * LEAVE1: an ended access neither reserves nor settles (42501);
--   * the switch events are append-only.
-- Seed users as in pgTAP 151: Testorganisation S …019 (simulation, Testteam Basel …1b9): pflegebs …9e6 (performer),
-- assistbs …9e7 (same team), operations …9e5. Testorganisation A …011 (not a simulation, Testteam Nord …101): pflege …902.
-- All data synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(47);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-0000000009e6' when 'a' then '00000000-0000-4000-a000-0000000009e7'
                 when 'c' then '00000000-0000-4000-a000-000000000902' when 'ops' then '00000000-0000-4000-a000-0000000009e5'
          end)::uuid $$;
create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('a1660000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1661000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
-- 0167 (AUT-167): every reservation carries the app's prompt digest; here the registered digest of the current version.
select set_config('t166.dg', (select pv.prompt_digest from public.ai_agent_definitions d
                              join private.ai_agent_prompt_versions pv on pv.agent_key = d.key and pv.version = d.version
                              where d.key = 'report_draft_model'), true) is not null as digest;
create function pg_temp.res(p_user text, p_report int, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.reserve_report_draft_call(%L, %L, %L)', pg_temp.id(p_report), pg_temp.k(p_key),
                                    current_setting('t166.dg'))) $$;
create function pg_temp.settle(p_user text, p_rid uuid, p_outcome text, p_in int, p_out int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.settle_report_draft_call(%L, %L, %s, %s, 1200)', p_rid, p_outcome,
                                    coalesce(p_in::text, 'null'), coalesce(p_out::text, 'null'))) $$;
create function pg_temp.gate(p_user text, p_report int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.report_draft_model_gate(%L)', pg_temp.id(p_report))) $$;
create function pg_temp.calls() returns int language sql as $$
  select coalesce(sum(calls), 0)::int from private.model_call_budget where function_key = 'report_draft_model' $$;
create function pg_temp.charged() returns bigint language sql as $$
  select coalesce(sum(charged_micro_chf), 0)::bigint from private.model_call_budget where function_key = 'report_draft_model' $$;
create function pg_temp.rid(p_key int) returns uuid language sql as $$
  select m.id from private.model_call_reservations m where m.idempotency_key = pg_temp.k(p_key) $$;

-- Fixtures (as the table owner) ----------------------------------------------------------------------------------------------
-- Org S: one synthetic case, visits 101-106, open drafts 1, 4, 5, 6 and a signed report 2 by 9e6. Org A: open draft 3 by 902.
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(200), 'Synth Klientin L166', 'Synth', 'L166', 'Basel-Stadt',
        'laufend', 'mittel', '00000000-0000-4000-a000-0000000001b9');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b)
select '00000000-0000-4000-b000-000000000019', pg_temp.id(100 + n), pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9',
       (private.now() at time zone 'Europe/Zurich')::date + 2, time '07:00' + make_interval(hours => n),
       time '07:30' + make_interval(hours => n), 'planned', 30, 0
from (values (1), (2), (4), (5), (6)) v(n);
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
             (4, '00000000-0000-4000-b000-000000000019'::uuid, pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9'::uuid, pg_temp.u('p')),
             (5, '00000000-0000-4000-b000-000000000019'::uuid, pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9'::uuid, pg_temp.u('p')),
             (6, '00000000-0000-4000-b000-000000000019'::uuid, pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9'::uuid, pg_temp.u('p')),
             (3, '00000000-0000-4000-b000-000000000011'::uuid, '00000000-0000-4000-a000-000000000208'::uuid,
                 '00000000-0000-4000-a000-000000000101'::uuid, pg_temp.u('c'))) f(n, o, c, t, pf);

-- 1. Catalogue ---------------------------------------------------------------------------------------------------------------
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'private' and c.relrowsecurity
             and c.relname in ('ai_function_limits', 'model_call_budget', 'model_call_reservations', 'ai_function_switch_events')),
          4, 'RLS is on for all four new tables');
select is((select count(*)::int from information_schema.role_table_grants g
           where g.table_schema = 'private'
             and g.table_name in ('ai_function_limits', 'model_call_budget', 'model_call_reservations', 'ai_function_switch_events')
             and g.grantee in ('PUBLIC', 'anon', 'authenticated', 'service_role')),
          0, 'no table privilege for any API role');
select ok(has_function_privilege('authenticated', 'public.reserve_report_draft_call(uuid, uuid, text)', 'execute')
          and has_function_privilege('authenticated', 'public.settle_report_draft_call(uuid, text, integer, integer, integer)', 'execute')
          and not has_function_privilege('anon', 'public.reserve_report_draft_call(uuid, uuid, text)', 'execute')
          and not has_function_privilege('anon', 'public.settle_report_draft_call(uuid, text, integer, integer, integer)', 'execute')
          and not has_function_privilege('authenticated', 'private.ai_function_off(text, uuid)', 'execute'),
  'reserve and settle: authenticated only; the switch reader has no API grant');
select is((select jsonb_build_object('day', day_calls, 'month', month_cap_micro_chf, 'out', max_output_tokens,
                                     'price', price_in_micro_chf_per_mtok, 'src', price_source)
           from private.ai_function_limits where function_key = 'report_draft_model'),
          '{"day": 300, "month": 50000000, "out": 1024, "price": null, "src": null}'::jsonb,
  'shipped limits: 300 calls per day, CHF 50 per month, 1024 output tokens, no price (fail closed)');

-- 2. No price reading: refused, nothing counted --------------------------------------------------------------------------
select is(pg_temp.res('p', 1, 1), '{"result": "rejected", "reason": "price_missing"}'::jsonb,
  'contract item 5: without a reviewed price reading every reservation is refused');
select is(pg_temp.calls(), 0, 'and nothing is counted');

-- Synthetic test fixture, NOT a price reading: CHF 3 / CHF 15 per million input / output tokens.
update private.ai_function_limits
   set price_in_micro_chf_per_mtok = 3000000, price_out_micro_chf_per_mtok = 15000000,
       price_source = 'pgTAP 166 synthetic fixture, not a provider price'
 where function_key = 'report_draft_model';

-- 3. Reservation, double tap, retry, third attempt -------------------------------------------------------------------------
select is(pg_temp.res('p', 1, 10) - 'reservation_id', '{"result": "ok", "attempt": 1}'::jsonb,
  'the performer of the open draft reserves attempt 1');
select is((select reserved_micro_chf from private.model_call_reservations where id = pg_temp.rid(10)), 33360::bigint,
  'the reserve is the upper estimate: 6000 input and 1024 output tokens at the fixture price = 33 360 micro-CHF');
select is((pg_temp.res('p', 1, 10) ->> 'reservation_id')::uuid, pg_temp.rid(10),
  'T-2: a repeat of the key (double tap) returns the same reservation');
select is(pg_temp.res('p', 1, 10) ->> 'result', 'duplicate', 'marked duplicate, so the app makes no second call');
select is(pg_temp.calls(), 1, 'the double tap counted one call');
select is(pg_temp.res('p', 1, 11) - 'reservation_id', '{"result": "ok", "attempt": 2}'::jsonb, 'a second key is the one retry');
select is(pg_temp.res('p', 1, 12), '{"result": "rejected", "reason": "attempt_limit"}'::jsonb,
  'ADR-227 point 2: a third attempt on the same report version is refused');
select is(pg_temp.calls(), 2, 'two calls counted for report 1');
select is((select zurich_day from private.model_call_budget where organization_id = '00000000-0000-4000-b000-000000000019'),
          (private.now() at time zone 'Europe/Zurich')::date, 'the budget row is the Zurich day');
select pg_temp.act_as(pg_temp.u('p'));
set local role authenticated;
select throws_ok(format($$ select public.reserve_report_draft_call(%L, %L, %L) $$, pg_temp.id(4), pg_temp.k(10), current_setting('t166.dg')),
  '22023', null, 'a key used for another report is refused');
reset role;

-- 4. Refusals with the gate's reasons --------------------------------------------------------------------------------------
select is(pg_temp.res('a', 4, 20) ->> 'reason', 'not_performer', 'negative: a team member who is not the performer');
select is(pg_temp.res('c', 4, 21) ->> 'reason', 'not_team_member', 'negative: another organisation''s member');
select is(pg_temp.res('c', 3, 22) ->> 'reason', 'not_simulation_org', 'negative: a non-simulation organisation');
select is(pg_temp.res('p', 2, 23) ->> 'reason', 'not_draft', 'negative: a signed report');
select is(pg_temp.calls(), 2, 'no refusal counted a call');

-- Database switch for organisation S, then for all, then cleared.
insert into private.ai_function_switch_events (function_key, organization_id, off, reason, note)
values ('report_draft_model', '00000000-0000-4000-b000-000000000019', true, 'manual', 'pgTAP 166 fixture');
select is(pg_temp.res('p', 4, 30) ->> 'reason', 'switched_off', 'switch on for the organisation: the reservation is refused');
select is(pg_temp.gate('p', 4) ->> 'reason', 'switched_off', 'and the gate closes on the same request (no restart)');
select is(pg_temp.cmd('p', format('select public.record_report_draft_proposal(%L, %L, %L::jsonb, %L)', pg_temp.id(4),
            'claude-test-model', '[{"text": "Synthetische Zeile.", "sources": ["s1"]}]', pg_temp.k(31))) ->> 'reason',
          'switched_off', 'and the ledger record command refuses too');
insert into private.ai_function_switch_events (function_key, organization_id, off, reason, note)
values ('report_draft_model', '00000000-0000-4000-b000-000000000019', false, 'cleared', 'pgTAP 166 fixture');
select is(pg_temp.gate('p', 4) ->> 'open', 'true', 'cleared for the organisation: open again');
insert into private.ai_function_switch_events (function_key, organization_id, off, reason, note)
values ('report_draft_model', null, true, 'evaluation_failed', 'pgTAP 166 fixture');
select is(pg_temp.res('p', 4, 32) ->> 'reason', 'switched_off', 'switch on for all organisations: refused');
insert into private.ai_function_switch_events (function_key, organization_id, off, reason, note)
values ('report_draft_model', null, false, 'cleared', 'pgTAP 166 fixture');
select is(pg_temp.gate('p', 4) ->> 'open', 'true', 'cleared for all: open again');
select throws_ok($$ update private.ai_function_switch_events set off = false $$, '42501', null,
  'switch events are append-only (update refused, also for the owner)');
select throws_ok($$ insert into private.ai_function_switch_events (function_key, organization_id, off, reason)
                    values ('report_draft_model', null, false, 'manual') $$, '23514', null,
  'only «cleared» may switch back on');
select is(pg_temp.calls(), 2, 'no call counted while switched off');

-- 5. Global day cap and month cap (one session; the advisory lock serialises every reservation of the function) -----------
update private.ai_function_limits set day_calls = 3 where function_key = 'report_draft_model';
select is(pg_temp.res('p', 4, 40) ->> 'result', 'ok', 'day cap 3, used 2: one more reservation is admitted');
select is(pg_temp.res('p', 5, 41), '{"result": "rejected", "reason": "budget_day"}'::jsonb,
  'used 3 of 3: the next one is refused (budget_day), whichever report');
update private.ai_function_limits set day_calls = 300, month_cap_micro_chf = pg_temp.charged() + 33359
 where function_key = 'report_draft_model';
select is(pg_temp.res('p', 5, 42), '{"result": "rejected", "reason": "budget_month"}'::jsonb,
  'month cap 1 micro-CHF short of one more reserve: refused (budget_month)');
select is(pg_temp.calls(), 3, 'refusals at the caps counted nothing');
update private.ai_function_limits set month_cap_micro_chf = 50000000 where function_key = 'report_draft_model';

-- 6. Settle -------------------------------------------------------------------------------------------------------------
select is(pg_temp.settle('a', pg_temp.rid(10), 'ok', 1000, 200), '{"result": "rejected", "reason": "not_found"}'::jsonb,
  'negative: a team member who is not the performer cannot settle');
select is(pg_temp.settle('c', pg_temp.rid(10), 'ok', 0, 0) ->> 'reason', 'not_found',
  'negative: another organisation''s member cannot touch this budget');
select is(pg_temp.charged(), 3 * 33360::bigint, 'so the charged sum is unchanged (three reserves)');
select is(pg_temp.settle('p', pg_temp.rid(10), 'ok', 1000, 200),
          '{"result": "ok", "cost_basis": "measured_tokens", "settled_micro_chf": 6000}'::jsonb,
  'the performer settles: 1000 input and 200 output tokens = 6000 micro-CHF, measured');
select is(pg_temp.charged(), 2 * 33360::bigint + 6000, 'the measured cost replaced the reserve in the budget');
select is(pg_temp.settle('p', pg_temp.rid(10), 'ok', 1, 1) ->> 'result', 'duplicate', 'settled once only');
select is(pg_temp.settle('p', pg_temp.rid(11), 'timeout', null, null) ->> 'cost_basis', 'reserve',
  'a timeout with nothing measured stays charged at its reserve');
select is((select jsonb_build_object('outcome', outcome, 'in', input_tokens, 'ms', latency_ms)
           from private.model_call_reservations where id = pg_temp.rid(10)),
          '{"outcome": "ok", "in": 1000, "ms": 1200}'::jsonb, 'outcome, tokens and latency are recorded (no text, no person column)');
select is((select count(*)::int from information_schema.columns where table_schema = 'private'
           and table_name in ('model_call_reservations', 'model_call_budget')
           and column_name ~ '(user|member|performer|text|note|by)$'), 0,
  'no person or text column in reservations and budget (team level only)');
select throws_ok(format($$ select public.settle_report_draft_call(%L, 'ok', 5, null, 10) $$, pg_temp.rid(40)),
  '22023', null, 'token counts come in pairs');

-- 7. LEAVE1: an ended access neither reserves nor settles ------------------------------------------------------------------
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.u('p'), 'ended', 'access_withdrawn', pg_temp.u('ops'));
-- The reservation id is read as the owner first: a helper reading private tables under the app role would fail with
-- 42501 for the wrong reason.
select set_config('t166.rid40', pg_temp.rid(40)::text, true);
select pg_temp.act_as(pg_temp.u('p'));
set local role authenticated;
select throws_ok(format($$ select public.reserve_report_draft_call(%L, %L, %L) $$, pg_temp.id(6), pg_temp.k(50), current_setting('t166.dg')),
  '42501', null, 'LEAVE1: an ended access cannot reserve a model call');
select throws_ok(format($$ select public.settle_report_draft_call(%L, 'ok', 1, 1, 10) $$, current_setting('t166.rid40')),
  '42501', null, 'LEAVE1: an ended access cannot settle');
reset role;
select is(pg_temp.calls(), 3, 'nothing counted after the access end');

select * from finish();
rollback;
