-- ASM1-C6 with C6 (8) (migration 0106, ADR-140): "Irrtümlich erfasst" as an append-only void act per record, with the
-- P-37 preset reason; the current record falls back; a voided record's fields are withheld from every team read path;
-- the care plan's basis is read by identity, not by date. Brief `docs/agents/briefs/ASM1.md` (po 2026-10-30 13:28,
-- 15:00, 15:55, 18:25; `cra` CGR-103, CGR-104; `lca` 09:40, 12:50, 13:42, 17:45; `uxa` 15:50). All data synthetic.
-- Seed users: pflege …902 (registered nurse, Nord …101) · assist …906 (care assistant, Nord) · fremd …903 (org B) ·
-- ops …904 (Operations, org A). Test user mitte (registered nurse of Mitte …102, created below).
-- Seed instrument (org A): …971 "Testinstrument Bedarf" 1.0. Case 208 (Testfall 08) is Nord's.
begin;
create extension if not exists pgtap with schema extensions;

select plan(50);

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
                 when 'mitte' then 'a1070000-0000-4000-a000-000000010701'
            end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1071000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.raw(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
-- record_assessment on case 208 with the seed instrument …971, assessor pflege …902; minutes C only.
create function pg_temp.rec(p_user text, p_date date, p_ref text, p_c int, p_sup uuid, p_reason text, p_key int) returns jsonb
language sql as $$
  select pg_temp.cmd(p_user, format('select public.record_assessment(%L, %L, %L, %L, %L, null, null, null, null, %L, %L, %L, %L, %L)',
    pg_temp.c08(), p_date, '00000000-0000-4000-a000-000000000971', pg_temp.u('p'), p_ref, p_c,
    case when p_c is null then null else 'pro Woche' end, p_sup, p_reason, pg_temp.k(p_key)))
$$;
create function pg_temp.void(p_user text, p_record uuid, p_kind text, p_reason text, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.void_assessment(%L, %L, %L, %L)', p_record, p_kind, p_reason, pg_temp.k(p_key)))
$$;
create function pg_temp.review(p_user text, p_record uuid, p_key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.review_care_plan_against_assessment(%L, %L, %L)', pg_temp.c08(), p_record, pg_temp.k(p_key)))
$$;
create function pg_temp.reason(r jsonb) returns text language sql as $$ select coalesce(r ->> 'reason', r ->> 'result') $$;
create function pg_temp.view(p_user text) returns jsonb language sql as $$
  select f from jsonb_array_elements(pg_temp.rows(p_user, 'select * from public.team_case_assessments()')) f
  where f ->> 'case_id' = pg_temp.c08()::text $$;
-- the ids a member can select through the table for case 208 (RLS read path)
create function pg_temp.table_ids(p_user text) returns jsonb language sql as $$
  select coalesce(jsonb_agg(x -> 'id' order by x ->> 'id'), '[]') from jsonb_array_elements(
    pg_temp.rows(p_user, format('select id from public.assessment_records where case_id = %L', pg_temp.c08()))) x $$;
-- every care-plan item of case 208 as stored, the visit minutes, billable facts and the billing preview (ASM1-8)
create function pg_temp.items_hash() returns text language sql as $$
  select md5(coalesce(string_agg(to_jsonb(i)::text, '|' order by i.id), '')) from public.care_plan_items i where i.case_id = pg_temp.c08() $$;
create function pg_temp.planning_hash() returns text language sql as $$
  select md5(
    (select coalesce(string_agg(x::text, '|' order by x::text), '') from jsonb_array_elements(
       pg_temp.rows('p', format('select * from public.billing_preview(%L)', pg_temp.t()))) x)
    || (select coalesce(string_agg(b::text, '|' order by b.id), '') from public.billable_facts b)
    || (select coalesce(string_agg(concat_ws(',', v.id, v.status, v.visit_date, v.planned_minutes_a, v.planned_minutes_b,
                                             v.planned_minutes_c), '|' order by v.id), '') from public.care_visits v)) $$;

-- Synthetic account: a registered nurse of Testteam Mitte (another team of the same organisation).
insert into auth.users (id, email) values (pg_temp.u('mitte'), 'asm1c6-mitte@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse');

-- Fixture: record 1 (T-20, entered by the named RN, confirmed); the plan is one item written against it -----------------------
update public.care_plan_items set active = false where case_id = pg_temp.c08() and active;
create temp table ids (n int, id uuid);
insert into ids select 1, (pg_temp.rec('p', pg_temp.t() - 20, 'TST-7001', 300, null, null, 1) ->> 'record_id')::uuid;
create function pg_temp.id(n int) returns uuid language sql stable as $$ select id from ids where ids.n = $1 $$;
select is(pg_temp.cmd('p', format($$select public.add_care_plan_item(%L, 'Synthetisch Morgenpflege', 'C', 30, '2x täglich', %L, null, %L)$$,
                                  pg_temp.c08(), pg_temp.t() + 60, pg_temp.k(2))) #>> '{}', 'ok', 'fixture: an item written against record 1');
select is(pg_temp.view('p') ->> 'basis_fact', null, 'fixture: the plan rests on the current record, no basis fact');
create temp table before_state as select pg_temp.items_hash() as items, pg_temp.planning_hash() as planning;

-- The void table: append-only, not selectable through the table ----------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'public.assessment_voids'::regclass), 'ASM1-C6: RLS is on for the void acts');
select ok(pg_temp.refused('p', 'select voided_by from public.assessment_voids'), 'ASM1-C6: the actor column is not selectable through the table');
select ok(pg_temp.refused('p', 'select id, record_id, reason from public.assessment_voids'),
          'ASM1-C6: the void acts are read per case through the reader only');

-- C6 (8) (v) first case: record 2 with the same date, not a supersede (entered by the care assistant, names pflege) ---------------
-- The pinned clock moves on 5 minutes so the entry order is defined (created_at), not left to the id.
select set_config('navora.test_now', (((select t from d0) + time '10:05') at time zone 'Europe/Zurich')::text, true);
insert into ids select 2, (pg_temp.rec('ca', pg_temp.t() - 20, 'TST-7002', 330, null, null, 10) ->> 'record_id')::uuid;
select is((pg_temp.view('p') ->> 'current_id')::uuid, pg_temp.id(2), 'fixture: the same-date parallel record is current (later entry)');
select is(pg_temp.view('p') ->> 'newer_assessment_date', null, 'CGR-104 (the gap): a same-date parallel record shows no "Neuere" marker');
select is(pg_temp.view('p') ->> 'basis_fact', 'not_current', 'ASM1-C6 (8) (i): the basis head is not current → fact returned');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(2), 11)), 'ok', 'ASM1-C6 (8) (iv): the act is offered and accepted');
select is(pg_temp.view('p') ->> 'basis_fact', null, 'ASM1-C6 (8) (iv): the act clears the fact');
select is(jsonb_array_length(pg_temp.view('p') -> 'records'), 2, 'fixture: both records are listed with their fields');

-- Who may void (C6 (6), provisional: a registered nurse of the case's team); reason rules (C6 (4), P-37) ------------------------
select is(pg_temp.reason(pg_temp.void('ca', pg_temp.id(2), 'wrong_client', null, 20)), 'not_rn',
          'ASM1-C6 (7): refused for a member outside the set (care assistant of the team)');
select is(pg_temp.reason(pg_temp.void('mitte', pg_temp.id(2), 'wrong_client', null, 21)), 'not_team_member',
          'ASM1-C6 (7): refused for a registered nurse of another team');
select is(pg_temp.reason(pg_temp.void('fremd', pg_temp.id(2), 'wrong_client', null, 22)), 'not_team_member',
          'ASM1-C6 (7): refused for a member of another organisation');
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(2), 'other', 'zu kurz', 23)), 'reason_required',
          'P-37: "Anderer Grund" with fewer than 10 characters is refused');
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(2), 'bogus', 'Synthetisch: unbekannte Art', 24)), 'reason_kind_invalid',
          'P-37: only the two choices exist');
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(2), 'wrong_client', 'Synthetisch: eigener Text', 25)), 'reason_kind_invalid',
          'P-37: the preset carries no free text');
select is((select count(*)::int from public.assessment_voids), 0, 'ASM1-C6: no refused void wrote a row');

-- C6 (8) (v): act on record 2, then record 2 voided with the preset → falls back to record 1, fact returned ----------------------
select is(pg_temp.view('p') -> 'records' -> 0 ->> 'state', 'unconfirmed', 'fixture: record 2 names pflege and waits for her confirmation (C1)');
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(2), 'wrong_client', null, 30)), 'ok',
          'ASM1-C6 (1): a registered nurse of the team voids record 2 with the preset reason, no free text');
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(2), 'wrong_client', null, 30)), 'duplicate', 'ASM1-C6: a repeated command is idempotent');
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(2), 'wrong_client', null, 31)), 'already_voided', 'ASM1-C6: a record is voided once');
select is((select reason from public.assessment_voids where record_id = pg_temp.id(2)), 'Falsche Klientin oder falscher Klient gewählt',
          'P-37 (lca (b)): the stored reason is the preset text exactly as shown');
select is((pg_temp.view('p') ->> 'current_id')::uuid, pg_temp.id(1), 'ASM1-C6 (1): the current record falls back to record 1');
select is(pg_temp.view('p') ->> 'basis_fact', 'voided', 'ASM1-C6 (8) (v): act on record 2, then record 2 voided → fact returned');
select is(pg_temp.view('p') ->> 'plan_basis_date', null, 'ASM1-C6 (8) (iii): no basis date of a voided record is returned');
select ok(not (pg_temp.view('p') -> 'records') @> jsonb_build_array(jsonb_build_object('id', pg_temp.id(2))),
          'ASM1-C6 (5): record 2 leaves the record list (her open-confirmation line disappears)');
select is((select jsonb_agg(k order by k) from jsonb_object_keys(pg_temp.view('p') -> 'voided_records' -> 0) k),
          '["assessor_is_me", "id", "reason", "voided_by_name", "voided_on"]'::jsonb,
          'ASM1-C6 (3)/(7): the voided entry carries the void only: no minutes, period, instrument, reference or date of the record');
select is(pg_temp.view('p') -> 'voided_records' -> 0 ->> 'assessor_is_me', 'true',
          'ASM1-C6 (5): the named assessor sees the void on that record');
select is(pg_temp.view('p') -> 'voided_records' -> 0 ->> 'reason', 'Falsche Klientin oder falscher Klient gewählt',
          'ASM1-C6 (3): the team sees the reason as shown');
select is(pg_temp.table_ids('ca'), jsonb_build_array(pg_temp.id(1)::text),
          'ASM1-C6 (7) output rule: the voided record is not selectable through the table either');
select is(pg_temp.reason(pg_temp.cmd('p', format('select public.confirm_assessment(%L, %L)', pg_temp.id(2), pg_temp.k(32)))), 'voided',
          'ASM1-C6 (5): a voided record is not confirmed');
select is(pg_temp.reason(pg_temp.rec('p', pg_temp.t() - 20, 'TST-7003', 310, pg_temp.id(2), 'Synthetisch: Ersatz eines Irrtums', 33)), 'voided',
          'ASM1-C6: a voided record is not superseded');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(1), 34)), 'ok',
          'ASM1-C6 (8) (iv): with an older record left, the act is offered and accepted against it');
select is(pg_temp.view('p') ->> 'basis_fact', null, 'ASM1-C6 (8) (iv): and clears the fact');

-- C6 (8) (v): a supersede chain whose head is voided; a superseded record is not voided --------------------------------------------
insert into ids select 3, (pg_temp.rec('p', pg_temp.t() - 1, 'TST-7004', 280, null, null, 40) ->> 'record_id')::uuid;
insert into ids select 4, (pg_temp.rec('p', pg_temp.t() - 1, 'TST-7005', 290, pg_temp.id(3), 'Synthetisch: Minuten C falsch übertragen', 41)
                           ->> 'record_id')::uuid;
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(3), 'other', 'Synthetisch: gehört nicht in diesen Fall', 42)), 'superseded',
          'ASM1-C6: a superseded record is not voided; its head is');
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(4), 'other', 'Synthetisch: gehört nicht in diesen Fall', 43)), 'ok',
          'ASM1-C6 (4): "Anderer Grund" with its text');
select is((pg_temp.view('p') ->> 'current_id')::uuid, pg_temp.id(1), 'ASM1-C6 (1): the current record falls back past the voided chain');
select is(pg_temp.table_ids('p'), jsonb_build_array(pg_temp.id(1)::text),
          'ASM1-C6 (7): neither the voided head nor the record it superseded is selectable through the table');
select is(jsonb_array_length(pg_temp.view('p') -> 'records'), 1, 'ASM1-C6 (7): the reader lists no field of the voided chain');

-- C6 (8) (v), po 18:25: the only record left voided → fact returned, act refused not_current --------------------------------------
select is(pg_temp.reason(pg_temp.void('p', pg_temp.id(1), 'other', 'Synthetisch: Erfassung gehört nicht in diesen Fall', 50)), 'ok',
          'fixture: the last record is voided');
select is(pg_temp.view('p') ->> 'current_id', null, 'ASM1-C6 (1): no record is current any more');
select is(pg_temp.view('p') ->> 'basis_fact', 'voided', 'ASM1-C6 (8) (v): the only record voided → fact returned');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(1), 51)), 'not_current',
          'ASM1-C6 (8) (iv) po 18:25: no review "against nothing": refused not_current');
select ok(pg_temp.view('p') -> 'plan_review' ->> 'assessment_date' is null
          and pg_temp.view('p') -> 'plan_review' ->> 'record_voided' = 'true',
          'ASM1-C6 (8) (iii): the latest act names no date of the voided record it named');

-- Append-only, audit, reads and side effects ------------------------------------------------------------------------------------
select is(pg_temp.raw(format('update public.assessment_records set minutes_c = 1 where id = %L', pg_temp.id(1))) ||
          pg_temp.raw(format('delete from public.assessment_records where id = %L', pg_temp.id(1))), '4250142501',
          'ASM1-C6 (1)/(7): no assessment_records row is updated or deleted (also by the table owner)');
select is(pg_temp.raw('update public.assessment_voids set reason = ''Synthetisch: geändert'''), '42501',
          'ASM1-C6: a void act is never updated (also by the table owner)');
select is((select count(*)::int from public.audit_events where table_name = 'assessment_voids'
             and command = 'void_assessment' and actor_id = pg_temp.u('p')), 3,
          'ASM1-C6 (1): one audit row per void with actor and time');
select ok(pg_temp.view('fremd') is null and pg_temp.view('ops') is null and pg_temp.view('mitte') is null,
          'ASM1-9: another organisation, Operations and another team read no void of the case');
select ok((select items from before_state) = pg_temp.items_hash()
          and (select planning from before_state) = pg_temp.planning_hash(),
          'ASM1-8 / C6 (8) (v): no care-plan item changed; J3 visits, visit minutes, billable facts and the billing preview unchanged');

select * from finish();
rollback;
