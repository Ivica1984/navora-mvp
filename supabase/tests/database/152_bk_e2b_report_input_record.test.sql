-- BK-e2b (PO package contract 2026-11-19 16:40 point 2 and 5; BK brief criterion 5 «the signed version records its
-- input», shared test 40 segments; criterion 6 BK-8n «an unsigned draft creates no billable fact»), ADR-219, migration 0152.
--
-- What it guards:
--   * the table: RLS on, no grant for app roles, append-only, audited without text;
--   * the command: only the performer of the open draft in her team; refused for a team member who is not the
--     performer, another organisation's member, a signed report;
--   * the record: every segment once, in order, with one decision consistent with the lines; a missing, repeated or
--     undecided segment, a line with text, or a decision that contradicts the lines is refused;
--   * 40 segments: 40 stored, none lost; a repeat of the key writes nothing;
--   * BK-8n: a draft with a recorded input creates no billable fact.
-- Seed users as in pgTAP 151: Testorganisation S …019 (Testteam Basel …1b9): pflegebs …9e6 (performer), assistbs …9e7.
-- Testorganisation A …011: pflege …902. All data synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-0000000009e6' when 'a' then '00000000-0000-4000-a000-0000000009e7'
                 when 'c' then '00000000-0000-4000-a000-000000000902' end)::uuid $$;
create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('a1520000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1521000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.rec(p_user text, p_report int, p_segments jsonb, p_lines jsonb, p_key int) returns jsonb
language sql as $$
  select pg_temp.cmd(p_user, format('select public.record_report_input(%L, %L, %L::jsonb, %L::jsonb, %L)',
    pg_temp.id(p_report), 'rule', p_segments, p_lines, pg_temp.k(p_key))) $$;
-- An invalid record raises 22023 before any check of the caller; returns the SQLSTATE or 'ok'.
create function pg_temp.state(p_segments jsonb, p_lines jsonb, p_key int) returns text language plpgsql as $$
begin
  perform pg_temp.rec('p', 1, p_segments, p_lines, p_key);
  return 'ok';
exception when others then
  execute 'reset role';
  return sqlstate;
end $$;
create function pg_temp.rows() returns int language sql as $$
  select count(*)::int from public.visit_report_inputs where report_id in (pg_temp.id(1), pg_temp.id(2), pg_temp.id(3)) $$;

-- Fixtures (as the table owner): org S open draft (1) and signed report (2) by 9e6; org A open draft (3) by 902.
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(200), 'Synth Klientin L152', 'Synth', 'L152', 'Basel-Stadt',
        'laufend', 'mittel', '00000000-0000-4000-a000-0000000001b9');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b)
select '00000000-0000-4000-b000-000000000019', pg_temp.id(100 + n), pg_temp.id(200), '00000000-0000-4000-a000-0000000001b9',
       (private.now() at time zone 'Europe/Zurich')::date + 3, time '08:00' + make_interval(hours => n),
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

-- A small valid record: s1 taken via line 0, s2 dropped via line 1, s3 inserted, s4 omitted. Synthetic text only.
create function pg_temp.segs() returns jsonb language sql immutable as $$
  select '[{"id": "s1", "text": "Klientin wach.", "decision": "taken"},
           {"id": "s2", "text": "Verband gewechselt.", "decision": "dropped"},
           {"id": "s3", "text": "Im Bad gestürzt, keine sichtbare Verletzung.", "decision": "inserted"},
           {"id": "s4", "text": "Wetter schön.", "decision": "omitted"}]'::jsonb $$;
create function pg_temp.lines() returns jsonb language sql immutable as $$
  select '[{"sources": ["s1", "f1"], "decision": "taken"}, {"sources": ["s2"], "decision": "dropped"}]'::jsonb $$;

-- 1. Table and grants ----------------------------------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'public.visit_report_inputs'::regclass)
          and not has_table_privilege('authenticated', 'public.visit_report_inputs', 'select')
          and not has_table_privilege('authenticated', 'public.visit_report_inputs', 'insert')
          and not has_table_privilege('anon', 'public.visit_report_inputs', 'select'),
  'RLS on; no read or write grant for app roles');
select ok(has_function_privilege('authenticated', 'public.record_report_input(uuid, text, jsonb, jsonb, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.record_report_input(uuid, text, jsonb, jsonb, uuid)', 'execute'),
  'members may call the command, anon may not');

-- 2. Caller refusals -----------------------------------------------------------------------------------------------------
select is(pg_temp.rec('a', 1, pg_temp.segs(), pg_temp.lines(), 1) ->> 'reason', 'not_performer',
  'negative: a team member who is not the performer cannot record');
select is(pg_temp.rec('c', 1, pg_temp.segs(), pg_temp.lines(), 2) ->> 'reason', 'not_team_member',
  'negative: a member of another organisation cannot record into this team''s report');
select is(pg_temp.rec('p', 2, pg_temp.segs(), pg_temp.lines(), 3) ->> 'reason', 'not_draft',
  'negative: a signed report gets no input record afterwards');
select is(pg_temp.rows(), 0, 'no row was written by a refused call');

-- 3. A valid record ------------------------------------------------------------------------------------------------------
select is(pg_temp.rec('p', 1, pg_temp.segs(), pg_temp.lines(), 10) ->> 'result', 'ok', 'the performer records her input');
select is((select jsonb_build_object('n', segment_count, 'origin', origin, 'by', created_by = pg_temp.u('p'),
                                     'decisions', (select jsonb_agg(e ->> 'decision') from jsonb_array_elements(segments) e))
           from public.visit_report_inputs where report_id = pg_temp.id(1)),
          jsonb_build_object('n', 4, 'origin', 'rule', 'by', true, 'decisions', '["taken", "dropped", "inserted", "omitted"]'::jsonb),
  'each segment once with its decision, in order; origin and author stored');
select is(pg_temp.rec('p', 1, pg_temp.segs(), pg_temp.lines(), 10) ->> 'result', 'duplicate', 'a repeat of the key is a duplicate');
select is(pg_temp.rows(), 1, 'and writes no new row');
select is((select count(*)::int from public.audit_events a where a.table_name = 'visit_report_inputs'
           and a.changed::text ~ 'Klientin|Verband|gestürzt'), 0, 'the audit row carries no typed text');
select throws_ok($$ update public.visit_report_inputs set origin = 'model' $$, '42501', null, 'append-only (update refused)');

-- 4. Invalid records (fail closed, 22023) --------------------------------------------------------------------------------
select is(pg_temp.state(pg_temp.segs() - 1, pg_temp.lines(), 20), '22023', 'a missing segment (s2 gone, s3 follows s1) is refused');
select is(pg_temp.state(jsonb_set(pg_temp.segs(), '{3,decision}', '"open"'), pg_temp.lines(), 21), '22023',
  'an undecided segment is refused');
select is(pg_temp.state(jsonb_set(pg_temp.segs(), '{1,decision}', '"taken"'), pg_temp.lines(), 22), '22023',
  'a segment marked taken whose only line was rejected is refused');
select is(pg_temp.state(jsonb_set(pg_temp.segs(), '{2,decision}', '"taken"'), pg_temp.lines(), 23), '22023',
  'a listed segment cannot be marked taken without a taken line');
select is(pg_temp.state(pg_temp.segs(), '[{"sources": ["s1"], "decision": "taken", "text": "x"}, {"sources": ["s2"], "decision": "dropped"}]', 24),
  '22023', 'a line carrying text is refused (minimisation)');
select is(pg_temp.state(pg_temp.segs(), pg_temp.lines() || '[{"sources": ["s9"], "decision": "dropped"}]'::jsonb, 25), '22023',
  'a line citing a segment that does not exist is refused');

-- 5. Shared test: 40 segments -> 40 stored, none lost --------------------------------------------------------------------
select is(pg_temp.rec('p', 1,
            (select jsonb_agg(jsonb_build_object('id', 's' || n, 'text', 'Synthetischer Satz ' || n || '.',
                                                 'decision', case when n % 2 = 0 then 'taken' else 'omitted' end) order by n)
             from generate_series(1, 40) n),
            (select jsonb_agg(jsonb_build_object('sources', jsonb_build_array('s' || n), 'decision', 'taken') order by n)
             from generate_series(2, 40, 2) n), 30) ->> 'result', 'ok', 'a 40-segment record is accepted');
select is((select jsonb_build_object('n', segment_count, 'stored', jsonb_array_length(segments),
                                     'ids', (select count(distinct e ->> 'id') from jsonb_array_elements(segments) e))
           from public.visit_report_inputs where report_id = pg_temp.id(1) order by created_at desc, segment_count desc limit 1),
          '{"n": 40, "stored": 40, "ids": 40}'::jsonb, '40 segments placed or listed, 40 stored, none lost');

-- 6. BK-8n: a draft with its input recorded is no billable fact ----------------------------------------------------------
select is(pg_temp.cmd('p', format('select public.generate_billable_facts(%L)', (private.now() at time zone 'Europe/Zurich')::date + 3)) >= '0'::jsonb,
  true, 'billing generation runs for the performer');
select is((select count(*)::int from public.billable_facts where visit_id in (pg_temp.id(101), pg_temp.id(102))), 0,
  'BK-8n: the drafts of this test, one with its input recorded, create no billable fact');

select * from finish();
rollback;
