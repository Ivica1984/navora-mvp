-- ASM1-C4 and ASM1-C5 (migration 0101, ADR-125): one review act re-bases the care plan on the current assessment without
-- changing any care-plan item; a corrected basis is returned to the team until the act. Brief `docs/agents/briefs/ASM1.md`
-- (PO 2026-10-30 09:15 and 10:15; `cra` 09:30 (a)-(c); `cra` CGR-102). All data synthetic.
-- Seed users: pflege …902 (registered nurse, Nord …101) · assist …906 (care assistant, Nord) · fremd …903 (org B) ·
-- ops …904 (Operations, org A). Test user mitte (registered nurse of Mitte …102, created below).
-- Seed instrument (org A): …971 "Testinstrument Bedarf" 1.0. Case 208 (Testfall 08) is Nord's.
begin;
create extension if not exists pgtap with schema extensions;

select plan(33);

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
                 when 'mitte' then 'a1010000-0000-4000-a000-000000010101'
            end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1011000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
-- record_assessment on case 208 with the seed instrument …971; minutes C only.
create function pg_temp.rec(p_user text, p_date date, p_ref text, p_c int, p_sup uuid, p_reason text, p_key int) returns jsonb
language sql as $$
  select pg_temp.cmd(p_user, format('select public.record_assessment(%L, %L, %L, %L, %L, null, null, null, null, %L, %L, %L, %L, %L)',
    pg_temp.c08(), p_date, '00000000-0000-4000-a000-000000000971', pg_temp.u('p'), p_ref, p_c,
    case when p_c is null then null else 'pro Woche' end, p_sup, p_reason, pg_temp.k(p_key)))
$$;
create function pg_temp.review(p_user text, p_record uuid, p_key int, p_case uuid default pg_temp.c08()) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.review_care_plan_against_assessment(%L, %L, %L)', p_case, p_record, pg_temp.k(p_key)))
$$;
create function pg_temp.reason(r jsonb) returns text language sql as $$ select coalesce(r ->> 'reason', r ->> 'result') $$;
create function pg_temp.view(p_user text) returns jsonb language sql as $$
  select f from jsonb_array_elements(pg_temp.rows(p_user, 'select * from public.team_case_assessments()')) f
  where f ->> 'case_id' = pg_temp.c08()::text $$;
-- C4 (1), (c): every care-plan item of case 208 as stored, the visit minutes, billable facts and the billing preview.
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
insert into auth.users (id, email) values (pg_temp.u('mitte'), 'asm1c4-mitte@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse');

-- Fixture: case 208's plan is one active item written before any assessment record ----------------------------------------
update public.care_plan_items set active = false where case_id = pg_temp.c08() and active;
select is(pg_temp.cmd('p', format($$select public.add_care_plan_item(%L, 'Synthetisch Morgenpflege', 'C', 30, '2x täglich', %L, null, %L)$$,
                                  pg_temp.c08(), pg_temp.t() + 60, pg_temp.k(1))) #>> '{}', 'ok', 'fixture: an item written before any record');
create temp table before_state as select pg_temp.items_hash() as items, pg_temp.planning_hash() as planning;

-- The table: append-only, not selectable by anyone ---------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'public.care_plan_assessment_reviews'::regclass),
          'ASM1-C4: RLS is on for the review acts');
select ok(pg_temp.refused('p', 'select reviewed_by from public.care_plan_assessment_reviews'),
          'ASM1-C4 (4): the actor column is not selectable through the table');
select ok(pg_temp.refused('p', 'select id, case_id, record_id from public.care_plan_assessment_reviews'),
          'ASM1-C4 (4): the acts are not selectable through the table at all (read per case through the reader only)');

-- ASM1-C4 (3): a plan written before every record; record 1 entered by the care assistant (unconfirmed) -----------------------
create temp table ids (n int, id uuid);
insert into ids select 1, (pg_temp.rec('ca', pg_temp.t() - 20, 'TST-2001', 300, null, null, 10) ->> 'record_id')::uuid;
create function pg_temp.id(n int) returns uuid language sql stable as $$ select id from ids where ids.n = $1 $$;
select is(pg_temp.view('p') ->> 'plan_without_basis', 'true', 'fixture: the plan is written before every record');
select is((pg_temp.view('p') ->> 'newer_assessment_date')::date, pg_temp.t() - 20, 'fixture: the marker shows the record''s date');
select is(pg_temp.reason(pg_temp.review('ca', pg_temp.id(1), 12)), 'not_rn',
          'ASM1-C4 (2): refused for a member outside the provisional set (care assistant of the team)');
select is(pg_temp.reason(pg_temp.review('mitte', pg_temp.id(1), 13)), 'not_team_member',
          'ASM1-C4 (2): refused for a registered nurse of another team');
select is(pg_temp.reason(pg_temp.review('fremd', pg_temp.id(1), 14)), 'not_team_member',
          'ASM1-C4 (2): refused for a member of another organisation');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(1), 15)), 'ok', 'ASM1-C4: the registered nurse of the team records the act');
select is(pg_temp.view('ca') ->> 'plan_without_basis', 'false', 'ASM1-C4 (3): one act clears "Geschrieben vor jeder erfassten Bedarfsabklärung"');
select is(pg_temp.view('ca') ->> 'newer_assessment_date', null, 'ASM1-C4 (3): and the marker');
select is(pg_temp.view('ca') -> 'plan_review' ->> 'state_at_review', 'unconfirmed',
          '`cra` (a): the act stores the record''s state at the act (nicht bestätigt)');
select is(pg_temp.view('ca') -> 'records' -> 0 ->> 'state', 'unconfirmed',
          '`cra` (a): the record itself stays "nicht bestätigt" after the act');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(1), 16)), 'nothing_to_review', 'ASM1-C4: offered only while there is something to review');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(1), 15)), 'duplicate', 'ASM1-C4: a repeated command is idempotent');

-- ASM1-C4 (1): a newer record → marker; the act → marker gone, no item changed; audited ------------------------------------------
insert into ids select 2, (pg_temp.rec('p', pg_temp.t() - 2, 'TST-2002', 360, null, null, 20) ->> 'record_id')::uuid;
select is((pg_temp.view('p') ->> 'newer_assessment_date')::date, pg_temp.t() - 2, 'ASM1-C4 (1): a newer record shows the marker');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(1), 21)), 'not_current',
          'ASM1-C4 (2): refused for a record that is not the case''s current one');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(2), 22)), 'ok', 'ASM1-C4 (1): the act against the newer record');
select is(pg_temp.view('p') ->> 'newer_assessment_date', null, 'ASM1-C4 (1): the marker is gone');
select is((pg_temp.view('p') ->> 'plan_basis_date')::date, pg_temp.t() - 2, 'ASM1-C4 (1): the basis line names the newer record');
select is((select count(*)::int from public.audit_events where table_name = 'care_plan_assessment_reviews'
             and command = 'review_care_plan_against_assessment' and actor_id = pg_temp.u('p')
             and changed -> 'record_id' ->> 'new' = pg_temp.id(2)::text), 1,
          'ASM1-C4 (1): one audit row with actor, time and record');
select is(pg_temp.raw('update public.care_plan_assessment_reviews set record_state = ''confirmed'''), '42501',
          'ASM1-C4: an act is never updated (also by the table owner)');

-- ASM1-C5 (4): the record the plan rests on is corrected with the same date → the fact is returned until the act -------------------
insert into ids select 3, (pg_temp.rec('p', pg_temp.t() - 2, 'TST-2003', 330, pg_temp.id(2), 'Synthetisch: Minuten C falsch übertragen', 30)
                           ->> 'record_id')::uuid;
select is(pg_temp.view('ca') ->> 'newer_assessment_date', null, 'CGR-102 (the gap): a same-date correction leaves no "Neuere" marker');
select is((pg_temp.view('ca') ->> 'corrected_basis_date')::date, pg_temp.t() - 2,
          'ASM1-C5 (1): the team is told that the record the plan rests on was corrected (its date)');
select is((pg_temp.view('ca') ->> 'corrected_on')::date, pg_temp.t(), 'ASM1-C5 (1): and the correction''s entry date');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(2), 31)), 'not_current', 'ASM1-C4: a superseded record cannot be the basis of the act');
select is(pg_temp.reason(pg_temp.review('p', pg_temp.id(3), 32)), 'ok', 'ASM1-C5 (3): the act is offered while the fact shows');
select is(pg_temp.view('ca') ->> 'corrected_basis_date', null, 'ASM1-C5 (3): the act clears the fact');
-- a correction of a record no active item rests on is not returned
insert into ids select 4, (pg_temp.rec('p', pg_temp.t() - 20, 'TST-2004', 290, pg_temp.id(1), 'Synthetisch: Minuten C korrigiert', 40)
                           ->> 'record_id')::uuid;
select is(pg_temp.view('ca') ->> 'corrected_basis_date', null,
          'ASM1-C5 (4): a correction of a record no active item rests on is not returned');

-- Reads and side effects ------------------------------------------------------------------------------------------------------------
select ok(pg_temp.view('fremd') is null and pg_temp.view('ops') is null and pg_temp.view('mitte') is null,
          'ASM1-9: another organisation, Operations and another team read no review act or basis of the case');
select ok((select items from before_state) = pg_temp.items_hash(),
          'ASM1-C4 (1): no care-plan item was inserted, retired or changed by the acts (every column identical)');
select ok((select planning from before_state) = pg_temp.planning_hash(),
          '`cra` (c): PLAN2 visits, visit minutes, billable facts and the billing preview are unchanged by the acts');

select * from finish();
rollback;
