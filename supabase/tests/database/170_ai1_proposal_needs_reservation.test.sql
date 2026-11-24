-- AI1 (PO package contract 2026-11-22 08:39, fixed residual list item 1; review finding R7 on draft #1697 and `aia`
-- AUT-197), migration 0170: a model ledger proposal needs a reserved provider call, settled ok, once.
--
-- What it guards:
--   * catalogue: one `record_report_draft_proposal` overload (report, reservation, model, lines, key); the 4-argument
--     form is gone; authenticated may execute, anon may not;
--   * the reservation stamps the agent version whose prompt digest it checked;
--   * refusals, each with no ledger row: no such reservation, a reservation of another report, an unsettled reservation,
--     one settled with another outcome, a reservation with no agent version (a row from before 0170), a second
--     proposal on a used reservation; a member of another organisation gets the gate's reason (nothing about the
--     reservation leaks); a missing reservation id is an error;
--   * the accepted proposal: one row per line, version from the reservation even after the current version changed,
--     the reservation names the proposal and the model; a repeat of the key returns the same rows;
--   * LEAVE1: an ended access records nothing (42501).
-- Seed users as in pgTAP 151/166: Testorganisation S …019 (simulation, Testteam Basel …1b9): pflegebs …9e6 (performer),
-- operations …9e5. Testorganisation A …011: pflege …902. The price and version-2 rows are synthetic fixtures (not a
-- price reading, not a real prompt). All data synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(24);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-0000000009e6' when 'c' then '00000000-0000-4000-a000-000000000902'
                 when 'ops' then '00000000-0000-4000-a000-0000000009e5' end)::uuid $$;
create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('a1700000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1701000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
select set_config('t170.dg', (select pv.prompt_digest from public.ai_agent_definitions d
                              join private.ai_agent_prompt_versions pv on pv.agent_key = d.key and pv.version = d.version
                              where d.key = 'report_draft_model'), true) is not null as digest;
create function pg_temp.res(p_report int, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.reserve_report_draft_call(%L, %L, %L)', pg_temp.id(p_report), pg_temp.k(p_key),
                                 current_setting('t170.dg'))) $$;
create function pg_temp.rid(p_key int) returns uuid language sql as $$
  select m.id from private.model_call_reservations m where m.idempotency_key = pg_temp.k(p_key) $$;
create function pg_temp.settle(p_rid uuid, p_outcome text) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.settle_report_draft_call(%L, %L, 900, 60, 1200)', p_rid, p_outcome)) $$;
create function pg_temp.rec(p_user text, p_report int, p_rid uuid, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.record_report_draft_proposal(%L, %L, %L, %L::jsonb, %L)',
    pg_temp.id(p_report), p_rid, 'claude-test-model',
    '[{"text": "Synthetische Zeile eins.", "sources": ["s1"]}, {"text": "Synthetische Zeile zwei.", "sources": ["s2"]}]',
    pg_temp.k(p_key))) $$;
create function pg_temp.rows() returns int language sql as $$
  select count(*)::int from public.ai_suggestions where agent_key = 'report_draft_model' $$;

-- Fixtures (as the table owner) ----------------------------------------------------------------------------------------------
-- Org S: one synthetic case, visits 101-104, open drafts 1-4 by 9e6.
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(200), 'Synth Klientin L170', 'Synth', 'L170', 'Basel-Stadt',
        'laufend', 'mittel', '00000000-0000-4000-a000-0000000001b9');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b)
select '00000000-0000-4000-b000-000000000019', pg_temp.id(100 + n), pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9',
       (private.now() at time zone 'Europe/Zurich')::date + 2, time '07:00' + make_interval(hours => n),
       time '07:30' + make_interval(hours => n), 'planned', 30, 0
from generate_series(1, 4) n;
insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by)
select '00000000-0000-4000-b000-000000000019', pg_temp.id(n), pg_temp.id(100 + n), pg_temp.id(200),
       '00000000-0000-4000-a000-0000000001b9', 1, 'draft', '{"synthetic": true}'::jsonb, pg_temp.u('p'), false, pg_temp.u('p')
from generate_series(1, 4) n;
-- Synthetic test fixture, NOT a price reading (as in pgTAP 166).
update private.ai_function_limits
   set price_in_micro_chf_per_mtok = 3000000, price_out_micro_chf_per_mtok = 15000000,
       price_source = 'pgTAP 170 synthetic fixture, not a provider price'
 where function_key = 'report_draft_model';

-- 1. Catalogue ---------------------------------------------------------------------------------------------------------------
select is((select array_agg(pg_get_function_identity_arguments(p.oid)) from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = 'record_report_draft_proposal'),
          array['p_report_id uuid, p_reservation_id uuid, p_model text, p_lines jsonb, p_idempotency_key uuid'],
  'one record function only, and it takes the reservation (the 4-argument form is gone)');
select ok(has_function_privilege('authenticated', 'public.record_report_draft_proposal(uuid, uuid, text, jsonb, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.record_report_draft_proposal(uuid, uuid, text, jsonb, uuid)', 'execute'),
  'authenticated may record, anon may not');

-- 2. Reservations: the version is stamped --------------------------------------------------------------------------------------
select is((pg_temp.res(1, 10) ->> 'result') || ',' || (pg_temp.res(2, 20) ->> 'result') || ',' || (pg_temp.res(3, 30) ->> 'result'),
          'ok,ok,ok', 'three reservations (reports 1, 2, 3)');
select is((select string_agg(distinct m.agent_version, ',') from private.model_call_reservations m
           where m.idempotency_key in (pg_temp.k(10), pg_temp.k(20), pg_temp.k(30))),
          (select d.version from public.ai_agent_definitions d where d.key = 'report_draft_model'),
  'each reservation carries the agent version whose digest it checked');

-- 3. Refusals: no ledger row without a settled ok call of the same report ------------------------------------------------------
select is(pg_temp.rec('p', 1, pg_temp.id(999), 1) ->> 'reason', 'reservation_missing', 'negative: no such reservation');
select is(pg_temp.rec('p', 1, pg_temp.rid(20), 2) ->> 'reason', 'reservation_missing',
  'negative: the reservation of another report (same performer) is refused');
select is(pg_temp.rec('p', 1, pg_temp.rid(10), 3) ->> 'reason', 'reservation_not_ok', 'negative: an unsettled reservation');
select is(pg_temp.settle(pg_temp.rid(30), 'timeout') ->> 'result', 'ok', 'report 3: the call timed out and is settled so');
select is(pg_temp.rec('p', 3, pg_temp.rid(30), 4) ->> 'reason', 'reservation_not_ok',
  'negative: a reservation settled with another outcome than ok');
select is(pg_temp.rec('c', 1, pg_temp.rid(10), 5) ->> 'reason', 'not_team_member',
  'negative: a member of another organisation gets the gate''s reason (nothing about the reservation)');
select is(pg_temp.rows(), 0, 'no refusal wrote a ledger row');
select pg_temp.act_as(pg_temp.u('p'));
set local role authenticated;
select throws_ok(format($$ select public.record_report_draft_proposal(%L, null, 'm', '[{"text": "x", "sources": ["s1"]}]', %L) $$,
                        pg_temp.id(1), pg_temp.k(6)), '22023', null, 'a missing reservation id is an error');
reset role;

-- 4. The accepted proposal ---------------------------------------------------------------------------------------------------
select is(pg_temp.settle(pg_temp.rid(10), 'ok') ->> 'result', 'ok', 'report 1: the call is settled ok');
-- A version bump between the call and the record (a later migration would do it, with its registered row).
insert into private.ai_agent_prompt_versions (agent_key, version, prompt_digest, registered_at)
values ('report_draft_model', '2', repeat('ef', 32), private.now());
update public.ai_agent_definitions set version = '2' where key = 'report_draft_model';
select is(pg_temp.rec('p', 1, pg_temp.rid(10), 7) ->> 'result', 'ok', 'the performer records the proposal of the settled call');
select is((select string_agg(distinct s.agent_version, ',') || ':' || count(*) from public.ai_suggestions s
           where s.proposal_id = pg_temp.k(7)),
          (select m.agent_version from private.model_call_reservations m where m.id = pg_temp.rid(10)) || ':2',
  'AUT-197: both lines carry the version the call was reserved under, not the version current at record time');
select isnt((select m.agent_version from private.model_call_reservations m where m.id = pg_temp.rid(10)), '2',
  'and that is not the bumped version');
select is((select jsonb_build_object('p', m.proposal_id, 'm', m.model) from private.model_call_reservations m
           where m.id = pg_temp.rid(10)),
          jsonb_build_object('p', pg_temp.k(7), 'm', 'claude-test-model'),
  'the reservation names its one proposal and the model id');
select is(pg_temp.rec('p', 1, pg_temp.rid(10), 7) ->> 'result', 'duplicate', 'a repeat of the key is a duplicate');
select is(pg_temp.rec('p', 1, pg_temp.rid(10), 8) ->> 'reason', 'reservation_used',
  'negative: a second proposal on the same call (new key) is refused');
select is(pg_temp.rows(), 2, 'one proposal of two lines in the ledger');
select throws_ok(format($$ update private.model_call_reservations set model = null where id = %L $$, pg_temp.rid(10)),
  '23514', null, 'a proposal id without a model id is refused by the table check');

-- 5. A reservation from before 0170 (no version): fail closed ------------------------------------------------------------------
insert into private.model_call_reservations (id, organization_id, team_id, function_key, report_id, attempt, idempotency_key,
                                             zurich_day, reserved_micro_chf, settled_at, outcome, settled_micro_chf,
                                             cost_basis)
values (pg_temp.id(940), '00000000-0000-4000-b000-000000000019', '00000000-0000-4000-a000-0000000001b9', 'report_draft_model',
        pg_temp.id(4), 1, pg_temp.k(940), (private.at_zurich(private.now()))::date, 0, private.now(), 'ok', 0, 'measured_tokens');
select is(pg_temp.rec('p', 4, pg_temp.id(940), 9) ->> 'reason', 'reservation_unversioned',
  'negative: a settled ok reservation with no agent version is refused');

-- 6. LEAVE1 ------------------------------------------------------------------------------------------------------------------
select set_config('t170.rid20', pg_temp.rid(20)::text, true);
select is(pg_temp.settle(pg_temp.rid(20), 'ok') ->> 'result', 'ok', 'report 2: the call is settled ok');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.u('p'), 'ended', 'access_withdrawn', pg_temp.u('ops'));
select pg_temp.act_as(pg_temp.u('p'));
set local role authenticated;
select throws_ok(format($$ select public.record_report_draft_proposal(%L, %L, 'm', '[{"text": "x", "sources": ["s1"]}]', %L) $$,
                        pg_temp.id(2), current_setting('t170.rid20'), pg_temp.k(11)), '42501', null,
  'LEAVE1: an ended access records nothing');
reset role;

select * from finish();
rollback;
