-- OBS1: every observation shows who wrote it, and whether her qualification was recorded when she wrote it
-- (migration 0095, ADR-118, `cra` CGR-93, `lca` 13:57). Brief `docs/agents/briefs/OBS1.md` OBS1-1 to OBS1-5 and Negative.
-- Seed users: pflege …902 (RN, Nord) · assist …906 (CA, Nord) · coach …901 · ops …904 · admin …905 (org A).
-- Synthetic users added here: …9501 the admitted member without a qualification (the 094 member, own ids)
-- · …9502 a Mitte registered nurse. Case …208 is Nord's. All data synthetic.
begin;
create extension if not exists pgtap with schema extensions;

select plan(47);

-- Pinned clock (DST1 pattern): 10:00 Zurich today.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                 when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'nq' then 'a0950000-0000-4000-a000-000000009501' when 'mitte' then 'a0950000-0000-4000-a000-000000009502' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0951000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
-- Rows of a set-returning reader as the user, as one jsonb array.
create function pg_temp.rows(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]'') from (%s) x', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create temp table fx (name text primary key, id uuid);
grant all on fx to authenticated;
create function pg_temp.id(n text) returns uuid language sql stable as $$ select id from fx where name = n $$;
-- One observation row of field_notes(date) as the user, by observation id and kind.
create function pg_temp.note(p_user text, p_date date, p_obs uuid, p_kind text) returns jsonb language sql as $$
  select x from jsonb_array_elements(pg_temp.rows(p_user, format('select * from public.field_notes(%L)', p_date))) x
  where x ->> 'id' = p_obs::text and x ->> 'kind' = p_kind $$;

-- Setup: an admitted member through ADM2 without a recorded qualification (as pgTAP 094) -------------------------------------
insert into auth.users (id, email, email_confirmed_at) values
  (pg_temp.u('nq'), 'obs1-nq@navora.test', now()), (pg_temp.u('mitte'), 'obs1-mitte@navora.test', now());
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse');
select is(pg_temp.res('admin', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(1))),
          'ok', 'setup: team admission on');
insert into fx select 'P', (pg_temp.cmd('p', format('select public.propose_team_candidate(%L, %L, %L, %L, %L)',
  '00000000-0000-4000-a000-000000000101', 'Kandidatin Olga Test', 'care_assistant', '40-60', pg_temp.k(2))) ->> 'proposal_id')::uuid;
select is(pg_temp.cmd('ca', format('select public.decide_team_candidate(%L, %L, %L, %L)', pg_temp.id('P'),
          'consent', null, pg_temp.k(3))) ->> 'outcome', 'admitted', 'setup: admitted by the team');
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, %L, null, %L)', pg_temp.id('P'),
          'obs1-nq@navora.test', pg_temp.today(), pg_temp.k(4))), 'ok', 'setup: "Vertrag erfasst"');
select ok(exists (select 1 from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101'
                  and user_id = pg_temp.u('nq') and qualification is null), 'setup: Nord member without a recorded qualification');
select is(pg_temp.res('p', format('select public.set_display_name(%L, %L, %L, %L)', '00000000-0000-4000-b000-000000000011',
          pg_temp.u('p'), 'Pflegefachfrau Paula Test', pg_temp.k(5))), 'ok', 'setup: the registered nurse names herself (ADM1)');

-- Visit 1 (today, category A) is started by the care assistant; visit 2 (tomorrow) of the same case reads the handover.
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status, planned_minutes_a)
values ('a0950000-0000-4000-8000-000000000001', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today(), '09:00', '09:30', 'planned', 30),
       ('a0950000-0000-4000-8000-000000000002', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today() + 1, '09:00', '09:30', 'planned', 30),
       ('a0950000-0000-4000-8000-000000000003', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today(), '11:00', '11:30', 'planned', 30);
insert into fx values ('v1', 'a0950000-0000-4000-8000-000000000001'), ('v2', 'a0950000-0000-4000-8000-000000000002'),
                      ('v3', 'a0950000-0000-4000-8000-000000000003');
select is(pg_temp.res('ca', format('select public.start_visit(%L, %L)', pg_temp.id('v1'), pg_temp.k(10))), 'ok',
          'setup: the care assistant starts visit 1');

-- OBS1-1: marker recorded at the time of writing; never refused -------------------------------------------------------------
select is(pg_temp.res('nq', format('select public.record_observation(%L, %L, true, null, %L)', pg_temp.id('v1'),
          'Synthetisch: Klientin gestürzt, Knie gerötet', pg_temp.k(11))), 'ok',
          'OBS1-1: the member without a qualification records an observation on a visit a care assistant started (never refused)');
insert into fx select 'o_nq', id from public.visit_observations where author_id = pg_temp.u('nq') and visit_id = pg_temp.id('v1');
select is(pg_temp.res('p', format('select public.record_observation(%L, %L, true, null, %L)', pg_temp.id('v1'),
          'Synthetisch: Verband gewechselt', pg_temp.k(12))), 'ok', 'OBS1-1: a qualified colleague records one too');
insert into fx select 'o_p', id from public.visit_observations where author_id = pg_temp.u('p') and visit_id = pg_temp.id('v1');
select is((select author_qualification_recorded from public.visit_observations where id = pg_temp.id('o_nq')), false,
          'OBS1-1: her observation is stored with "no recorded qualification"');
select is((select author_qualification_recorded from public.visit_observations where id = pg_temp.id('o_p')), true,
          'OBS1-1: the qualified colleague''s observation is stored with "qualification recorded"');
insert into public.visit_observations (organization_id, visit_id, case_id, team_id, author_id, content, idempotency_key,
                                       author_qualification_recorded)
values ('00000000-0000-4000-b000-000000000011', pg_temp.id('v1'), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.u('nq'), 'Synthetisch: direkt geschrieben', pg_temp.k(13), true);
select is((select author_qualification_recorded from public.visit_observations where idempotency_key = pg_temp.k(13)), false,
          'OBS1-1: a value passed by a writer is overwritten by the recorded fact');
select throws_ok($$update public.visit_observations set author_qualification_recorded = true where idempotency_key = 'a0951000-0000-4000-8000-000000000013'$$,
          null, null, 'OBS1-1: the marker cannot be changed afterwards (append-only)');

-- OBS1-5: the marker is not selectable through the table API ----------------------------------------------------------------
select ok(not has_column_privilege('authenticated', 'public.visit_observations', 'author_qualification_recorded', 'select'),
          'OBS1-5: authenticated cannot select the marker column');
-- OBS1-7 (0096, OBS1-C1): author_id and recorded_at are closed too; the other ten columns stay selectable.
select ok(not has_column_privilege('authenticated', 'public.visit_observations', 'author_id', 'select')
          and has_column_privilege('authenticated', 'public.visit_observations', 'content', 'select')
          and not has_table_privilege('authenticated', 'public.visit_observations', 'select'),
          'OBS1-5 / OBS1-7: the other columns stay selectable through column grants (not author_id), no table-wide grant');
select ok(not has_any_column_privilege('anon', 'public.visit_observations', 'select'), 'OBS1-5: anon selects no column');
select throws_ok($$select pg_temp.rows('p', 'select author_qualification_recorded from public.visit_observations')$$,
          '42501', null, 'OBS1-5: a teammate''s table-API select of the marker is refused');
select ok(jsonb_array_length(pg_temp.rows('p', format('select id, content from public.visit_observations where visit_id = %L', pg_temp.id('v1')))) = 3,
          'OBS1-5: the team still reads its observations through the table API');

-- OBS1-2: the handover (field_notes) names the author and shows the marker ---------------------------------------------------
select is(pg_temp.note('p', pg_temp.today(), pg_temp.id('o_nq'), 'observation') ->> 'author_name', 'Kandidatin Olga Test',
          'OBS1-2: a colleague reads the author''s display name (ADM1)');
select is(pg_temp.note('p', pg_temp.today(), pg_temp.id('o_nq'), 'observation') ->> 'author_qualification_missing', 'true',
          'OBS1-2: … and the marker on her observation');
select is(pg_temp.note('p', pg_temp.today(), pg_temp.id('o_nq'), 'observation') ->> 'own', 'false', 'OBS1-2: own is kept');
select is(pg_temp.note('ca', pg_temp.today(), pg_temp.id('o_p'), 'observation') ->> 'author_name', 'Pflegefachfrau Paula Test',
          'OBS1-2: a qualified member''s observation names her');
select is(pg_temp.note('ca', pg_temp.today(), pg_temp.id('o_p'), 'observation') ->> 'author_qualification_missing', 'false',
          'OBS1-2: … with no marker');
select is(pg_temp.note('p', pg_temp.today() + 1, pg_temp.id('o_nq'), 'handover') ->> 'author_name', 'Kandidatin Olga Test',
          'OBS1-2: the next day''s handover names her');
select is(pg_temp.note('p', pg_temp.today() + 1, pg_temp.id('o_nq'), 'handover') ->> 'author_qualification_missing', 'true',
          'OBS1-2: … and carries the marker');
select is((select count(*)::int from jsonb_array_elements(pg_temp.rows('p', format('select * from public.field_since_last(%L)', pg_temp.today() + 1))) x
           where x ->> 'visit_id' = pg_temp.id('v2')::text and x ->> 'entry_id' = pg_temp.id('o_nq')::text and x -> 'detail' ->> 'author_name' = 'Kandidatin Olga Test'
             and x -> 'detail' ->> 'author_qualification_missing' = 'true'), 1,
          'OBS1-2: HAND1 ("seit deinem letzten Einsatz") names her and carries the marker');
select is((select x -> 'detail' ->> 'author_qualification_missing' from jsonb_array_elements(pg_temp.rows('p',
           format('select * from public.field_since_last(%L)', pg_temp.today() + 1))) x
           where x ->> 'visit_id' = pg_temp.id('v2')::text and x ->> 'entry_id' = pg_temp.id('o_p')::text), 'false',
          'OBS1-2: HAND1: no marker on the qualified colleague''s observation');

-- OBS1-3: the report snapshot names the author ------------------------------------------------------------------------------
select is(pg_temp.res('ca', format('select public.complete_visit(%L, %L)', pg_temp.id('v1'), pg_temp.k(20))), 'ok', 'setup: visit 1 completed');
select is(pg_temp.res('ca', format('select public.create_report_draft(%L, null, %L)', pg_temp.id('v1'), pg_temp.k(21))), 'ok',
          'setup: the performer drafts her report');
create function pg_temp.snap_obs(p_user text, p_visit uuid, p_author text) returns jsonb language sql as $$
  select o from jsonb_array_elements(pg_temp.rows(p_user, format('select * from public.field_reports(%L)', pg_temp.today()))) r,
       jsonb_array_elements(r -> 'snapshot' -> 'observations') o
  where r ->> 'visit_id' = p_visit::text and o ->> 'author_id' = pg_temp.u(p_author)::text limit 1 $$;
select is(pg_temp.snap_obs('ca', pg_temp.id('v1'), 'nq') ->> 'author_name', 'Kandidatin Olga Test',
          'OBS1-3: the draft the performer sees names the author of a colleague''s observation');
select is(pg_temp.snap_obs('ca', pg_temp.id('v1'), 'nq') ->> 'author_qualification_missing', 'true', 'OBS1-3: … with the marker');
select is(pg_temp.snap_obs('ca', pg_temp.id('v1'), 'p') ->> 'author_qualification_missing', 'false',
          'OBS1-3: no marker on the qualified colleague''s observation');
select is((select snapshot -> 'observations' -> 0 ->> 'author_id' from public.visit_reports where visit_id = pg_temp.id('v1')),
          pg_temp.u('nq')::text, 'OBS1-3: the stored draft snapshot holds the author''s identity');
-- Sign exactly what she saw; the signed snapshot then stays as signed.
select is(pg_temp.res('ca', format('select public.sign_report(%L, %L, %L)',
          (select id from public.visit_reports where visit_id = pg_temp.id('v1')),
          (select x ->> 'snapshot_hash' from jsonb_array_elements(pg_temp.rows('ca', format('select * from public.field_reports(%L)', pg_temp.today()))) x
           where x ->> 'visit_id' = pg_temp.id('v1')::text), pg_temp.k(22))), 'ok', 'setup: the performer signs');
select is(pg_temp.snap_obs('p', pg_temp.id('v1'), 'nq') ->> 'author_qualification_missing', 'true',
          'OBS1-3: the registered nurse who countersigns sees the author and the marker in the signed version');
create temp table signed_v1 as select id, snapshot::text as snap from public.visit_reports where visit_id = pg_temp.id('v1');

-- After the qualification is recorded: a new observation has no marker; the old one keeps it --------------------------------
select is(pg_temp.res('admin', format('select public.set_member_qualification(%L, %L, %L, %L, %L)', '00000000-0000-4000-a000-000000000101',
          pg_temp.u('nq'), 'care_assistant', 'Diplom geprüft', pg_temp.k(30))), 'ok', 'setup: qualification recorded (ADM2-6 path)');
select is(pg_temp.res('ca', format('select public.start_visit(%L, %L)', pg_temp.id('v3'), pg_temp.k(31))), 'ok', 'setup: visit 3 started');
select is(pg_temp.res('nq', format('select public.record_observation(%L, %L, false, null, %L)', pg_temp.id('v3'),
          'Synthetisch: Klientin wach, orientiert', pg_temp.k(32))), 'ok', 'OBS1-2: she records a new observation');
select is((select x ->> 'author_qualification_missing' from jsonb_array_elements(pg_temp.rows('p', format('select * from public.field_notes(%L)', pg_temp.today()))) x
           where x ->> 'visit_id' = pg_temp.id('v3')::text and x ->> 'kind' = 'observation'), 'false',
          'OBS1-2: after set_member_qualification her new observation carries no marker');
select is(pg_temp.note('p', pg_temp.today(), pg_temp.id('o_nq'), 'observation') ->> 'author_qualification_missing', 'true',
          'OBS1-2: … and the old one keeps it');
select is((select snap from signed_v1), (select snapshot::text from public.visit_reports where id = (select id from signed_v1)),
          'OBS1-3 / CSR1: the signed snapshot is unchanged after the qualification and a later observation');

-- A snapshot written before 0095 (no author keys) is read back byte for byte, never rewritten ---------------------------------
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status, planned_minutes_a)
values ('a0950000-0000-4000-8000-000000000004', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today(), '13:00', '13:30', 'completed', 30);
insert into public.visit_reports (organization_id, visit_id, case_id, team_id, version, status, snapshot, summary, performer_id,
                                  countersign_required, created_by, signed_by, signed_at)
select organization_id, 'a0950000-0000-4000-8000-000000000004', case_id, team_id, 1, 'signed',
       jsonb_set(snapshot, '{observations}', '[{"content": "Synthetisch: alte Fassung", "recorded_at": "2026-10-01T08:00:00+00:00", "handover": false, "edited": false}]'),
       null, performer_id, countersign_required, created_by, signed_by, signed_at
from public.visit_reports where visit_id = pg_temp.id('v1');
create temp table old_v4 as select snapshot::text as snap from public.visit_reports where visit_id = 'a0950000-0000-4000-8000-000000000004';
select is((select (x -> 'snapshot')::text from jsonb_array_elements(pg_temp.rows('ca', format('select * from public.field_reports(%L)', pg_temp.today()))) x
           where x ->> 'visit_id' = 'a0950000-0000-4000-8000-000000000004'), (select snap from old_v4),
          'OBS1-3: a signed snapshot without author is shown exactly as stored (no guessed name)');
select is((select snapshot::text from public.visit_reports where visit_id = 'a0950000-0000-4000-8000-000000000004'), (select snap from old_v4),
          'OBS1-3: … and stays byte for byte unchanged');

-- OBS1-5: no read widened ---------------------------------------------------------------------------------------------------
select is((select count(*)::int from jsonb_array_elements(pg_temp.rows('mitte', format('select * from public.field_notes(%L)', pg_temp.today()))) x
           where x ->> 'id' = pg_temp.id('o_nq')::text), 0, 'OBS1-5: a nurse of another team reads no author through field_notes');
select is((select count(*)::int from jsonb_array_elements(pg_temp.rows('coach', format('select * from public.field_notes(%L)', pg_temp.today()))) x
           where x ->> 'id' = pg_temp.id('o_nq')::text)
        + (select count(*)::int from jsonb_array_elements(pg_temp.rows('ops', format('select * from public.field_notes(%L)', pg_temp.today()))) x
           where x ->> 'id' = pg_temp.id('o_nq')::text)
        + (select count(*)::int from jsonb_array_elements(pg_temp.rows('admin', format('select * from public.field_reports(%L)', pg_temp.today()))) x
           where x ->> 'visit_id' = pg_temp.id('v1')::text), 0,
          'OBS1-5: the coach, Operations and the administrator read no author through field_notes or field_reports');
select is(pg_temp.cmd('mitte', format('select private.observation_qualification_missing(%L)', pg_temp.id('o_nq'))) #>> '{}', null,
          'OBS1-5: the marker helper answers nothing outside the observation''s team');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
             and p.prosrc ~ '(visit_observations|visit_report_snapshot|observation_qualification_missing|handover_entries)'),
          'correct_report,create_report_draft,field_notes,field_reports,field_since_last,record_observation,remove_planned_visit,return_report,sign_report,update_report_draft,withdraw_report_correction',
          'OBS1-5: no AN1, AN2, OPS1 or export reader reads observations or their author (fixed list of callable functions)');
select is((select string_agg(n.nspname || '.' || p.proname, ',' order by n.nspname, p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prosrc ~ 'author_qualification_recorded'),
          'private.handover_entries,private.observation_qualification_missing,private.set_observation_author_qualification,private.visit_report_snapshot',
          'Negative: no signal, OPS1 exception, quality event or billing fact reads the marker');

select * from finish();
rollback;
