-- AI1 (PO package contract 2026-11-22 08:39, fixed residual list item 2: AUT-167 via AUT-191), migration 0167.
--
-- What it guards:
--   * catalogue: `private.ai_agent_prompt_versions` has RLS on and no privilege for any API role; it is append-only;
--     version '1' of `report_draft_model` is registered with the digest the app computes today (the same literal is
--     pinned in `src/lib/ai/report-draft/prompt-version.ts` and checked by the unit test ai1-prompt-version);
--   * the reservation exists only with the prompt digest (one overload, three arguments); a wrong or missing digest is
--     refused (`prompt_version_mismatch`) and counts nothing; the right digest passes the check (and then meets the
--     shipped empty price, `price_missing`, so nothing is counted either);
--   * a new agent version without its registered row closes gate and reservation (`prompt_unregistered`);
--   * AUT-167 «a new version opens a fresh stop-rule window»: with the stop rule reached under version 1, registering
--     version 2 opens the model again because the corrections of version 1 are outside the new window; the old
--     version's digest is then refused.
-- The stop-rule row and the version-2 row are synthetic test fixtures (rolled back), not clinical values or a real prompt.
-- Seed users as in pgTAP 151: Testorganisation S …019 (simulation, Testteam Basel …1b9): pflegebs …9e6 (performer).
-- All data synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(17);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-0000000009e6' end)::uuid $$;
create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('a1670000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1671000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.gate(p_report int) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.report_draft_model_gate(%L)', pg_temp.id(p_report))) $$;
create function pg_temp.res(p_report int, p_key int, p_digest text) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.reserve_report_draft_call(%L, %L, %L)', pg_temp.id(p_report), pg_temp.k(p_key),
                                 p_digest)) $$;
create function pg_temp.rec(p_report int, p_lines jsonb, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.record_report_draft_proposal(%L, %L, %L::jsonb, %L)',
    pg_temp.id(p_report), 'claude-test-model', p_lines, pg_temp.k(p_key))) $$;
create function pg_temp.dec(p_sid uuid, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.decide_report_draft_line(%L, %L, %L, %L)', p_sid, 'rejected', null, pg_temp.k(p_key))) $$;
create function pg_temp.sid(p_key int, p_line int) returns uuid language sql as $$
  select s.id from public.ai_suggestions s
  where s.proposal_id = pg_temp.k(p_key) and (s.proposed_value ->> 'line_index')::int = p_line $$;
create function pg_temp.counted() returns int language sql as $$
  select (select count(*)::int from private.model_call_reservations where function_key = 'report_draft_model')
       + (select coalesce(sum(calls), 0)::int from private.model_call_budget where function_key = 'report_draft_model') $$;

-- The app's digest of prompt version 1 (prompt-version.ts); a synthetic digest for a version-2 fixture.
select set_config('t167.v1', '6385db265f21c2ac0ede72a630bd1ca93034661176bf0166b724fd560d74f3c9', true) is not null as v1;
select set_config('t167.v2', repeat('ab', 32), true) is not null as v2;

-- Fixtures (as the table owner): Org S, one synthetic case, an open draft (1) by 9e6 -------------------------------------------
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(200), 'Synth Klientin L167', 'Synth', 'L167', 'Basel-Stadt',
        'laufend', 'mittel', '00000000-0000-4000-a000-0000000001b9');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(101), pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9',
        (private.now() at time zone 'Europe/Zurich')::date + 2, '09:00', '09:30', 'planned', 30, 0);
insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(1), pg_temp.id(101), pg_temp.id(200),
        '00000000-0000-4000-a000-0000000001b9', 1, 'draft', '{"synthetic": true}'::jsonb, pg_temp.u('p'), false, pg_temp.u('p'));
-- Synthetic stop-rule fixture (not a clinical value): share 50, minimum 4 decided lines, window 30 days.
delete from public.report_draft_stop_rules where agent_key = 'report_draft_model';
insert into public.report_draft_stop_rules (agent_key, stop_share, stop_min_decided, stop_window_days, cra_ref)
values ('report_draft_model', 50, 4, 30, 'pgTAP 167 synthetic fixture');

-- 1. Catalogue ---------------------------------------------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'private.ai_agent_prompt_versions'::regclass)
          and not exists (select 1 from information_schema.role_table_grants g
                          where g.table_schema = 'private' and g.table_name = 'ai_agent_prompt_versions'
                            and g.grantee in ('PUBLIC', 'anon', 'authenticated', 'service_role')),
  'RLS is on and no API role has any privilege on the prompt versions');
select is((select pv.prompt_digest from public.ai_agent_definitions d
           join private.ai_agent_prompt_versions pv on pv.agent_key = d.key and pv.version = d.version
           where d.key = 'report_draft_model'),
          current_setting('t167.v1'), 'the current version (1) is registered with the digest the app computes');
select throws_ok($$ update private.ai_agent_prompt_versions set prompt_digest = repeat('0', 64) where agent_key = 'report_draft_model' $$,
  '42501', null, 'append-only: a registered digest cannot be changed');
select throws_ok($$ delete from private.ai_agent_prompt_versions where agent_key = 'report_draft_model' $$,
  '42501', null, 'append-only: a registered version cannot be deleted');
select is((select array_agg(pg_get_function_identity_arguments(p.oid)) from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname = 'reserve_report_draft_call'),
          array['p_report_id uuid, p_idempotency_key uuid, p_prompt_digest text'],
  'one reservation function only, and it takes the prompt digest (the two-argument form is gone)');
select ok(has_function_privilege('authenticated', 'public.reserve_report_draft_call(uuid, uuid, text)', 'execute')
          and not has_function_privilege('anon', 'public.reserve_report_draft_call(uuid, uuid, text)', 'execute'),
  'authenticated may call the reservation, anon may not');

-- 2. The digest check --------------------------------------------------------------------------------------------------------
select is(pg_temp.gate(1), '{"result": "ok", "open": true, "reason": null}'::jsonb, 'version 1 registered: the gate is open');
select is(pg_temp.res(1, 1, repeat('0', 64)) ->> 'reason', 'prompt_version_mismatch',
  'negative: a digest that is not the current version''s is refused');
select is(pg_temp.res(1, 2, null) ->> 'reason', 'prompt_version_mismatch', 'negative: no digest is refused');
select is(pg_temp.res(1, 3, current_setting('t167.v1')) ->> 'reason', 'price_missing',
  'the right digest passes the check (then the shipped empty price refuses, fail closed)');
select is(pg_temp.counted(), 0, 'no refused reservation counted a call or wrote a reservation row');

-- 3. Stop rule under version 1, then a new version opens a fresh window (AUT-167) -------------------------------------------
select is(pg_temp.rec(1, '[{"text": "A.", "sources": ["s1"]}, {"text": "B.", "sources": ["s2"]},
                           {"text": "C.", "sources": ["s3"]}, {"text": "D.", "sources": ["s4"]}]', 10) ->> 'result', 'ok',
  'version 1: a proposal with four lines is recorded');
select is((select string_agg(pg_temp.dec(pg_temp.sid(10, n), 20 + n) ->> 'result', ',' order by n) from generate_series(0, 3) n)
          || ';' || (pg_temp.gate(1) ->> 'reason'),
          'ok,ok,ok,ok;stop_rule', 'four rejected lines under version 1 reach the stop rule');
-- A version bump as a later migration would do it, without its registered row yet.
update public.ai_agent_definitions set version = '2' where key = 'report_draft_model';
select is((pg_temp.gate(1) ->> 'reason') || ',' || (pg_temp.res(1, 30, current_setting('t167.v1')) ->> 'reason'),
          'prompt_unregistered,prompt_unregistered',
  'negative: a current version without its registered digest closes gate and reservation (fail closed)');
-- Its row, registered one second after the version-1 corrections (the transaction clock does not move inside a test).
insert into private.ai_agent_prompt_versions (agent_key, version, prompt_digest, registered_at)
values ('report_draft_model', '2', current_setting('t167.v2'), private.now() + interval '1 second');
select is(pg_temp.gate(1), '{"result": "ok", "open": true, "reason": null}'::jsonb,
  'AUT-167: version 2 opens a fresh stop-rule window; the version-1 corrections no longer count');
select is(pg_temp.res(1, 31, current_setting('t167.v1')) ->> 'reason', 'prompt_version_mismatch',
  'negative: after the bump the version-1 digest is refused');
select is((pg_temp.res(1, 32, current_setting('t167.v2')) ->> 'reason') || ',' || pg_temp.counted(), 'price_missing,0',
  'the version-2 digest passes the check; nothing is counted');

select * from finish();
rollback;
