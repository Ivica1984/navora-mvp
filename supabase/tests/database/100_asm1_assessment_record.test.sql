-- ASM1 (migration 0100, ADR-123): the needs assessment is one append-only record per assessment; the care plan shows the
-- assessment it was written against. Brief `docs/agents/briefs/ASM1.md` (ASM1-1 to ASM1-11, negative). All data synthetic.
-- Seed users: pflege …902 (registered nurse, Nord …101) · assist …906 (care assistant, Nord) · fremd …903 (org B) ·
-- ops …904 (Operations, org A) · coach …901 (coach, org A) · admin …905 (administrator, org A).
-- Seed instruments (org A): …971 "Testinstrument Bedarf" 1.0 · …972 "Testmarke HC" 9.1 (third-party mark) · …973
-- "Testinstrument alt" 0.9, valid 2019-01-01 to 2020-12-31. Case 208 (Testfall 08) is Nord's, case 210 is Mitte's.
begin;
create extension if not exists pgtap with schema extensions;

select plan(74);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'fremd' then '00000000-0000-4000-a000-000000000903' when 'ops' then '00000000-0000-4000-a000-000000000904'
                 when 'coach' then '00000000-0000-4000-a000-000000000901' when 'admin' then '00000000-0000-4000-a000-000000000905'
            end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1001000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.ins(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-' || lpad((970 + n)::text, 12, '0'))::uuid $$;
create function pg_temp.c08() returns uuid language sql immutable as $$ select '00000000-0000-4000-a000-000000000208'::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
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
-- True when the statement (DML) is refused with 42501 for the user.
create function pg_temp.refused_dml(p_user text, p_sql text) returns boolean language plpgsql as $$
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute p_sql;
  execute 'reset role';
  return false;
exception when insufficient_privilege then
  execute 'reset role';
  return true;
end $$;
-- record_assessment as a user; returns the jsonb result.
create function pg_temp.rec(p_user text, p_date date, p_ins int, p_assessor text, p_ref text,
                            p_a int, p_pa text, p_b int, p_pb text, p_c int, p_pc text,
                            p_sup uuid, p_reason text, p_key int, p_case uuid default pg_temp.c08()) returns jsonb
language sql as $$
  select pg_temp.cmd(p_user, format('select public.record_assessment(%L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L)',
    p_case, p_date, pg_temp.ins(p_ins), pg_temp.u(p_assessor), p_ref, p_a, p_pa, p_b, p_pb, p_c, p_pc, p_sup, p_reason, pg_temp.k(p_key)))
$$;
create function pg_temp.reason(r jsonb) returns text language sql as $$ select coalesce(r ->> 'reason', r ->> 'result') $$;
create function pg_temp.view(p_user text) returns jsonb language sql as $$
  select f from jsonb_array_elements(pg_temp.rows(p_user, 'select * from public.team_case_assessments()')) f
  where f ->> 'case_id' = pg_temp.c08()::text $$;
-- A raw insert as the table owner; returns the SQLSTATE or 'ok'.
create function pg_temp.raw(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;

-- ASM1-8 baseline: billing preview of team Nord, billable facts, visit minutes and the J1 date before any record ---------------
create temp table before_state as
select (select md5(coalesce(string_agg(x::text, '|' order by x::text), '')) from jsonb_array_elements(
          pg_temp.rows('p', format('select * from public.billing_preview(%L)', pg_temp.t()))) x) as billing,
       (select md5(coalesce(string_agg(b::text, '|' order by b.id), '')) from public.billable_facts b) as facts,
       (select md5(coalesce(string_agg(concat_ws(',', v.id, v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c), '|' order by v.id), ''))
        from public.care_visits v) as visits,
       (select needs_assessment_done_at from public.cases where id = pg_temp.c08()) as done_at;

-- ASM1-1: the column list (no item, score, scale, CAP, output or free-text finding column) -------------------------------------
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
           where table_schema = 'public' and table_name = 'assessment_records'),
          'id,organization_id,case_id,team_id,assessment_date,instrument_id,assessor_id,document_ref,minutes_a,period_a,'
          || 'minutes_b,period_b,minutes_c,period_c,supersedes_id,supersede_reason,entered_by,created_at',
          'ASM1-1: the record has exactly date, instrument, assessor, reference, minutes and period per category, supersede, author and time');
select is((select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
           where table_schema = 'public' and table_name = 'assessment_instruments'),
          'id,organization_id,name,version,valid_from,valid_to,third_party_mark,created_by,created_at,ended_by,ended_at',
          'ASM1-6: the instrument list holds names, version, validity and the mark flag only (no designation, logo or item text)');
select ok((select bool_and(relrowsecurity) from pg_class
           where oid in ('public.assessment_records'::regclass, 'public.assessment_confirmations'::regclass,
                         'public.assessment_instruments'::regclass)), 'RLS is on for the three ASM1 tables');
-- CGR-84: the period columns are text with only a non-empty and length check; no enum, no list of values
select is((select string_agg(distinct data_type, ',') from information_schema.columns
           where table_schema = 'public' and table_name = 'assessment_records' and column_name like 'period_%'), 'text',
          'CGR-84: the three period columns are plain text (no enum)');
select is((select count(*)::int from pg_constraint
           where conrelid = 'public.assessment_records'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ~ 'period_'
             and pg_get_constraintdef(oid) ~* '(any \(|\min \(|array\[|~)'), 0,
          'CGR-84: no check constraint restricts the period values (no list, no pattern)');

-- ASM1-1/-5: a record entered by the care assistant naming the registered nurse stays unconfirmed --------------------------------
create temp table r as select pg_temp.rec('ca', pg_temp.t() - 20, 1, 'p', 'TST-1001', 120, 'pro Woche', null, null, 90, 'pro Woche',
                                          null, null, 1) as v;
select is((select v ->> 'result' from r), 'ok', 'ASM1-1: a team member records an assessment naming the registered nurse');
select is((select v ->> 'state' from r), 'unconfirmed', 'ASM1-5: entered by another member it is unconfirmed');
create temp table ids (n int, id uuid);
insert into ids select 1, (v ->> 'record_id')::uuid from r;
create function pg_temp.id(n int) returns uuid language sql stable as $$ select id from ids where ids.n = $1 $$;
select is(jsonb_array_length(pg_temp.view('p') -> 'records'), 1, 'ASM1-9: the case''s team reads the record');
select is(pg_temp.view('ca') -> 'records' -> 0 ->> 'state', 'unconfirmed', 'ASM1-5: the team sees "nicht bestätigt"');
select is(pg_temp.view('ca') -> 'records' -> 0 ->> 'period_a', 'pro Woche', 'ASM1-1: the period is returned as entered');
select is(pg_temp.view('ca') -> 'records' -> 0 ->> 'instrument_name', 'Testinstrument Bedarf', 'ASM1-10: the instrument name is shown');
select is((select count(*)::int from public.audit_events where table_name = 'assessment_records' and entity_id = pg_temp.id(1)
             and command = 'record_assessment'), 1, 'audit: the record''s insert is audited with its command');

-- ASM1-5: only the named nurse confirms ----------------------------------------------------------------------------------------
select is(pg_temp.reason(pg_temp.cmd('ca', format('select public.confirm_assessment(%L, %L)', pg_temp.id(1), pg_temp.k(2)))),
          'not_assessor', 'ASM1-5: the member who entered it cannot confirm it');
select is(pg_temp.reason(pg_temp.cmd('admin', format('select public.confirm_assessment(%L, %L)', pg_temp.id(1), pg_temp.k(3)))),
          'not_assessor', 'ASM1-5: an administrator cannot confirm it');
select is(pg_temp.cmd('p', format('select public.confirm_assessment(%L, %L)', pg_temp.id(1), pg_temp.k(4))) ->> 'state',
          'confirmed', 'ASM1-5: the named registered nurse confirms');
select is(pg_temp.view('ca') -> 'records' -> 0 ->> 'state', 'confirmed', 'ASM1-5: the team sees it confirmed');
select is(pg_temp.reason(pg_temp.cmd('p', format('select public.confirm_assessment(%L, %L)', pg_temp.id(1), pg_temp.k(5)))),
          'already_confirmed', 'ASM1-5: a second confirmation is refused');
select is((select count(*)::int from public.audit_events where table_name = 'assessment_confirmations'
             and command = 'confirm_assessment' and actor_id = pg_temp.u('p')), 1,
          'ASM1-5: the confirmation is audited (who and when)');
select is(pg_temp.raw(format($$insert into public.assessment_confirmations (organization_id, record_id, confirmed_by)
                               values ('00000000-0000-4000-b000-000000000011', %L, %L)$$, pg_temp.id(1), pg_temp.u('ca'))),
          '23514', 'ASM1-5: on any write path nobody but the named assessor confirms');
-- entered by the named nurse herself: confirmed at once
create temp table r2 as select pg_temp.rec('p', pg_temp.t() - 30, 2, 'p', null, null, null, null, null, null, null, null, null, 6) as v;
select is((select v ->> 'state' from r2), 'confirmed', 'ASM1-5: a record entered by the named nurse is confirmed');
select is(pg_temp.view('p') -> 'records' -> 1 ->> 'instrument_third_party_mark', 'true',
          'ASM1-6: an instrument name that is a third party''s mark is returned as such');

-- ASM1-1 / CGR-81 (1): minutes without a period are refused, on the command and on any write path -----------------------------------
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 5, 1, 'p', 'TST-1002', 60, null, null, null, null, null, null, null, 10)),
          'period_required', 'ASM1-1: minutes without a period are refused');
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 5, 1, 'p', 'TST-1002', null, 'pro Tag', null, null, null, null, null, null, 11)),
          'period_required', 'ASM1-1: a period without minutes is refused');
select is(pg_temp.raw(format($$insert into public.assessment_records (organization_id, case_id, team_id, assessment_date, instrument_id,
                                 assessor_id, document_ref, minutes_b, entered_by)
                               values ('00000000-0000-4000-b000-000000000011', %L, '00000000-0000-4000-a000-000000000101', %L, %L, %L,
                                       'TST-1003', 30, %L)$$, pg_temp.c08(), pg_temp.t() - 5, pg_temp.ins(1), pg_temp.u('p'), pg_temp.u('p'))),
          '23514', 'ASM1-1: a raw insert of minutes without a period is refused');
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 25, 1, 'p', 'TST-1004', 30, 'je Quartal laut Instrument', null, null, null, null,
                                     null, null, 12)), 'ok', 'CGR-84: any period text is stored as entered (no list)');

-- ASM1-3: the reference is an opaque identifier -------------------------------------------------------------------------------------
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 5, 1, 'p', 'TST 1005', 30, 'pro Tag', null, null, null, null, null, null, 13)),
          'reference_invalid', 'ASM1-3: a reference with a space is refused');
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 5, 1, 'p', 'A1' || repeat('x', 63), 30, 'pro Tag', null, null, null, null,
                                     null, null, 14)), 'reference_invalid', 'ASM1-3: a reference above 64 characters is refused');
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 5, 1, 'p', 'abklaerung2026.pdf', 30, 'pro Tag', null, null, null, null,
                                     null, null, 15)), 'reference_invalid', 'ASM1-3: a file name is refused (no dot)');
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 5, 1, 'p', 'Bedarfsabklaerung', 30, 'pro Tag', null, null, null, null,
                                     null, null, 16)), 'reference_invalid', 'ASM1-3: a title without a digit is refused');
select is(pg_temp.raw(format($$insert into public.assessment_records (organization_id, case_id, team_id, assessment_date, instrument_id,
                                 assessor_id, document_ref, entered_by)
                               values ('00000000-0000-4000-b000-000000000011', %L, '00000000-0000-4000-a000-000000000101', %L, %L, %L,
                                       'akte/2026 01', %L)$$, pg_temp.c08(), pg_temp.t() - 5, pg_temp.ins(1), pg_temp.u('p'), pg_temp.u('p'))),
          '23514', 'ASM1-3: a raw insert of a path with a space is refused');

-- ASM1-4: minutes only with the reference -------------------------------------------------------------------------------------------
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 5, 1, 'p', null, 30, 'pro Tag', null, null, null, null, null, null, 17)),
          'reference_required', 'ASM1-4: minutes without the reference are refused');
select is(pg_temp.raw(format($$insert into public.assessment_records (organization_id, case_id, team_id, assessment_date, instrument_id,
                                 assessor_id, minutes_a, period_a, entered_by)
                               values ('00000000-0000-4000-b000-000000000011', %L, '00000000-0000-4000-a000-000000000101', %L, %L, %L,
                                       30, 'pro Tag', %L)$$, pg_temp.c08(), pg_temp.t() - 5, pg_temp.ins(1), pg_temp.u('p'), pg_temp.u('p'))),
          '23514', 'ASM1-4: a raw insert of minutes without the reference is refused');

-- ASM1-1 assessor, ASM1-6 instrument validity, date ---------------------------------------------------------------------------------
select is(pg_temp.reason(pg_temp.rec('p', pg_temp.t() - 5, 1, 'ca', null, null, null, null, null, null, null, null, null, 18)),
          'assessor_not_rn', 'ASM1-1: the assessor must be a registered nurse of the case''s team');
select is(pg_temp.reason(pg_temp.rec('p', pg_temp.t() - 5, 3, 'p', null, null, null, null, null, null, null, null, null, 19)),
          'instrument_not_valid', 'ASM1-6: an entry no longer valid on the assessment date is refused');
select is(pg_temp.reason(pg_temp.rec('p', date '2020-06-01', 3, 'p', null, null, null, null, null, null, null, null, null, 20)),
          'ok', 'ASM1-6: the same entry is accepted for a date inside its validity');
select is(pg_temp.raw(format($$insert into public.assessment_records (organization_id, case_id, team_id, assessment_date, instrument_id,
                                 assessor_id, entered_by)
                               values ('00000000-0000-4000-b000-000000000011', %L, '00000000-0000-4000-a000-000000000101', %L, %L, %L, %L)$$,
                             pg_temp.c08(), pg_temp.t() - 5, pg_temp.ins(3), pg_temp.u('p'), pg_temp.u('p'))),
          '23514', 'ASM1-6: on any write path a record names only an entry valid on its date');
select is(pg_temp.reason(pg_temp.rec('p', pg_temp.t() + 1, 1, 'p', null, null, null, null, null, null, null, null, null, 21)),
          'date_in_future', 'an assessment date after today is refused');
select is(pg_temp.reason(pg_temp.rec('p', pg_temp.t() - 5, 1, 'p', null, null, null, null, null, null, null, null, null, 22,
                                     '00000000-0000-4000-a000-000000000210')),
          'not_team_member', 'a member of another team cannot record for that team''s case');

-- ASM1-2: supersede, never overwrite ----------------------------------------------------------------------------------------------
select ok(pg_temp.refused_dml('p', format('update public.assessment_records set minutes_a = 1 where id = %L', pg_temp.id(1))),
          'ASM1-2: an update through the table API is refused');
select ok(pg_temp.refused_dml('p', format('delete from public.assessment_records where id = %L', pg_temp.id(1))),
          'ASM1-2: a delete through the table API is refused');
select is(pg_temp.raw(format('update public.assessment_records set minutes_a = 1 where id = %L', pg_temp.id(1))), '42501',
          'ASM1-2: an update is refused for the table owner too');
select is(pg_temp.raw(format('delete from public.assessment_records where id = %L', pg_temp.id(1))), '42501',
          'ASM1-2: a delete is refused for the table owner too');
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 20, 1, 'p', 'TST-1006', 100, 'pro Woche', null, null, 90, 'pro Woche',
                                     pg_temp.id(1), null, 23)), 'reason_required', 'ASM1-2: a supersede needs a reason');
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 20, 1, 'p', 'TST-1006', 100, 'pro Woche', null, null, 90, 'pro Woche',
                                     pg_temp.id(1), 'zu kurz', 24)), 'reason_required', 'ASM1-2: a reason under 10 characters is refused');
create temp table r3 as select pg_temp.rec('ca', pg_temp.t() - 20, 1, 'p', 'TST-1006', 100, 'pro Woche', null, null, 90, 'pro Woche',
                                           pg_temp.id(1), 'Synthetisch: Minuten A falsch übertragen', 25) as v;
select is((select v ->> 'result' from r3), 'ok', 'ASM1-2: a correction supersedes the record with a reason');
insert into ids select 3, (v ->> 'record_id')::uuid from r3;
select is(pg_temp.reason(pg_temp.rec('ca', pg_temp.t() - 20, 1, 'p', 'TST-1007', 110, 'pro Woche', null, null, null, null,
                                     pg_temp.id(1), 'Synthetisch: zweite Korrektur desselben', 26)),
          'already_superseded', 'ASM1-2: a superseded record cannot be superseded again (correct the correction)');
select is((select count(*)::int from public.assessment_records where id = pg_temp.id(1) and minutes_a = 120), 1,
          'ASM1-2: the superseded record is kept unchanged');
select is((select (f ->> 'current')::boolean from jsonb_array_elements(pg_temp.view('p') -> 'records') f
           where f ->> 'id' = pg_temp.id(1)::text), false, 'ASM1-2: the superseded record is never current');
select is((select f ->> 'superseded_by' from jsonb_array_elements(pg_temp.view('p') -> 'records') f
           where f ->> 'id' = pg_temp.id(1)::text), pg_temp.id(3)::text, 'ASM1-10: history marks the superseded record and its successor');
select is(pg_temp.reason(pg_temp.cmd('p', format('select public.confirm_assessment(%L, %L)', pg_temp.id(3), pg_temp.k(27)))),
          'ok', 'ASM1-5: the correction is confirmed by the named nurse in its own right');

-- ASM1-7: the care plan against its assessment ------------------------------------------------------------------------------------
-- current now: record 3 (T-20, the correction of record 1). A plan item written now rests on it.
select is(pg_temp.cmd('p', format($$select public.add_care_plan_item(%L, 'Synthetisch Morgenpflege', 'C', 30, '2x täglich', %L, null, %L)$$,
                                  pg_temp.c08(), pg_temp.t() + 60, pg_temp.k(30))) #>> '{}', 'ok', 'fixture: a care plan item is written');
select is((select assessment_id from public.care_plan_items where case_id = pg_temp.c08() and service = 'Synthetisch Morgenpflege'),
          pg_temp.id(3), 'ASM1-7: the item stores the assessment it was written against (the current record)');
select is(pg_temp.raw(format($$insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes,
                                 frequency, review_date, created_by, assessment_id)
                               values ('00000000-0000-4000-b000-000000000011', %L, '00000000-0000-4000-a000-000000000101',
                                       'Synthetisch Abendpflege', 'C', 60, '1x wöchentlich', %L, %L, %L)$$,
                             pg_temp.c08(), pg_temp.t() + 60, pg_temp.u('p'), pg_temp.id(2))), 'ok', 'fixture: a raw item naming another record');
select is((select assessment_id from public.care_plan_items where case_id = pg_temp.c08() and service = 'Synthetisch Abendpflege'),
          pg_temp.id(3), 'ASM1-7: on any write path the stored basis is the current record, not a value the writer passes');
-- the plan has seed items too? the basis date is the oldest of its active items; only ours are active on case 208 in the seed
update public.care_plan_items set active = false where case_id = pg_temp.c08() and assessment_id is null;
select is((pg_temp.view('p') ->> 'plan_basis_date')::date, pg_temp.t() - 20, 'ASM1-7: the care plan shows the date it was written against');
select is(pg_temp.view('p') ->> 'newer_assessment_date', null, 'ASM1-7: no marker while the plan rests on the current assessment');
create temp table r4 as select pg_temp.rec('p', pg_temp.t() - 2, 1, 'p', 'TST-1008', 150, 'pro Woche', null, null, null, null, null, null, 31) as v;
insert into ids select 4, (v ->> 'record_id')::uuid from r4;
select is((pg_temp.view('ca') ->> 'newer_assessment_date')::date, pg_temp.t() - 2,
          'ASM1-7: a newer assessment is recorded → the team sees "Neuere Bedarfsabklärung vom <Datum>"');
select is(pg_temp.view('ca') ->> 'current_id', pg_temp.id(4)::text, 'ASM1-7: the newer record is now current');

-- ASM1-9: reads ----------------------------------------------------------------------------------------------------------------
select is(pg_temp.view('fremd'), null, 'ASM1-9: another organisation reads nothing');
select is(pg_temp.view('ops'), null, 'ASM1-9: Operations reads no assessment of the case');
select is(pg_temp.view('coach'), null, 'ASM1-9: a coach reads no assessment of the case');
select is(pg_temp.view('admin'), null, 'ASM1-9: an administrator reads no assessment of the case');
select is(jsonb_array_length(pg_temp.rows('ops', 'select id, minutes_a, document_ref from public.assessment_records')), 0,
          'ASM1-9: Operations selects no minutes or references through the table');
select is(jsonb_array_length(pg_temp.rows('admin', 'select id, minutes_a, document_ref from public.assessment_records')), 0,
          'ASM1-9: an administrator selects no minutes or references through the table');
select is(jsonb_array_length(pg_temp.rows('ca', format('select id, minutes_a, period_a, document_ref from public.assessment_records where case_id = %L',
                                                        pg_temp.c08()))), 6, 'ASM1-9: the case''s team selects its records through the table');
select ok(pg_temp.refused('ca', 'select assessor_id from public.assessment_records')
          and pg_temp.refused('ca', 'select entered_by from public.assessment_records')
          and pg_temp.refused('ca', 'select confirmed_by from public.assessment_confirmations'),
          'RLS4 pattern: who assessed, entered or confirmed is not selectable through the table (read per record only)');

-- ASM1-11 (4): a dated fact younger than the current assessment is named --------------------------------------------------------------
insert into public.case_lifecycle_events (organization_id, case_id, kind, actor_id, idempotency_key, created_at)
values ('00000000-0000-4000-b000-000000000011', pg_temp.c08(), 'resume', pg_temp.u('p'), pg_temp.k(40), private.now());
select is(pg_temp.view('p') -> 'newer_events' -> 0 ->> 'kind', 'resume',
          'ASM1-11 (4): a resume after the current assessment is returned as a dated fact');

-- ASM1-6: list maintenance -------------------------------------------------------------------------------------------------------------
select is(pg_temp.reason(pg_temp.cmd('p', format($$select public.add_assessment_instrument('00000000-0000-4000-b000-000000000011',
            'Testinstrument neu', '2.0', %L, null, false, %L)$$, pg_temp.t(), pg_temp.k(50)))), 'not_admin',
          'ASM1-6: a nurse cannot add an instrument entry');
select is(pg_temp.cmd('admin', format($$select public.add_assessment_instrument('00000000-0000-4000-b000-000000000011',
            'Testinstrument neu', '2.0', %L, null, false, %L)$$, pg_temp.t(), pg_temp.k(51))) ->> 'result', 'ok',
          'ASM1-6: an administrator adds an entry');
select is(pg_temp.reason(pg_temp.cmd('admin', format('select public.end_assessment_instrument(%L, %L, %L)',
            pg_temp.ins(1), pg_temp.t() - 10, pg_temp.k(52)))), 'records_after_end',
          'ASM1-6: an entry cannot end before an assessment recorded with it');

-- ASM1-8: planning and billing facts unchanged ----------------------------------------------------------------------------------------
select ok((select (select md5(coalesce(string_agg(x::text, '|' order by x::text), '')) from jsonb_array_elements(
                     pg_temp.rows('p', format('select * from public.billing_preview(%L)', pg_temp.t()))) x) = billing
                  and (select md5(coalesce(string_agg(b::text, '|' order by b.id), '')) from public.billable_facts b) = facts
                  and (select md5(coalesce(string_agg(concat_ws(',', v.id, v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c), '|' order by v.id), ''))
                       from public.care_visits v) = visits
           from before_state),
          'ASM1-8: the billing preview, the billable facts and the visit minutes of the seed are identical after the records');
select is((select needs_assessment_done_at from public.cases where id = pg_temp.c08()), (select done_at from before_state),
          'ASM1-8: cases.needs_assessment_done_at is unchanged in meaning (no record writes it)');

-- Negative: nothing computed, no due date, no per-person reader ---------------------------------------------------------------------
select is((select string_agg(p.proname, ',') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prosrc ~ 'assessment_records'
             and p.prosrc ~* '(sum\(|avg\(|interval ''[0-9]+ (day|month|week)|reassess|due_)'), null,
          'Negative: no function reading the records sums, averages or computes an interval or due date');
select is((select string_agg(p.proname, ',') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prosrc ~ 'assessment_records'
             and p.prosrc ~* 'group by\s+[a-z_.]*(assessor_id|entered_by|confirmed_by)'), null,
          'Negative / D-23 (b): no reader groups records per person');

select * from finish();
rollback;
