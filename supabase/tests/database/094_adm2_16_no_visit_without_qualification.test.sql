-- ADM2-16: a member without a recorded qualification performs no visit (migration 0094, ADR-117, `cra` CGR-92).
-- Brief `docs/agents/briefs/ADM2.md` ADM2-16 (i)-(iv); (iv) is pgTAP 038 and 090, unmodified.
-- Seed users: pflege …902 (RN, Nord, the proposer) · assist …906 (CA, Nord) · admin …905 (org A) · coach …901.
-- Synthetic users added here: …9401 the admitted member's hand-made account (no qualification until set) · …9402 a Mitte
-- registered nurse (cover check). Case …208 is Nord's. All data synthetic.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

-- Pinned clock (DST1 pattern): 10:00 Zurich today.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'nq' then 'a0940000-0000-4000-a000-000000009401' when 'mitte' then 'a0940000-0000-4000-a000-000000009402' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0941000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
-- A direct status write as a member (the column grant of 0003), for the backstop.
create function pg_temp.direct(p_user text, p_visit uuid, p_status text) returns void language plpgsql as $$
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  begin
    update public.care_visits set status = p_status where id = p_visit;
  exception when others then
    execute 'reset role';
    raise;
  end;
  execute 'reset role';
end $$;
create function pg_temp.status(p uuid) returns text language sql as $$ select status from public.care_visits where id = p $$;
create function pg_temp.refusals(p uuid, p_command text) returns int language sql as $$
  select count(*)::int from public.audit_events a where a.table_name = 'care_visits' and a.entity_id = p
     and a.command = p_command and a.changed #>> '{outcome,new}' = 'qualification_missing'
     and a.actor_id = pg_temp.u('nq') and a.idempotency_key is null $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create temp table fx (name text primary key, id uuid);
grant all on fx to authenticated;

-- Setup: an admitted member through ADM2 (Nord: proposer p, one other active member ca, so one consent admits) ----------
insert into auth.users (id, email, email_confirmed_at) values
  (pg_temp.u('nq'), 'adm2-16-nq@navora.test', now()), (pg_temp.u('mitte'), 'adm2-16-mitte@navora.test', now());
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse');

select is(pg_temp.res('admin', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(1))),
          'ok', 'setup: the administrator switches team admission on');
insert into fx select 'P', (pg_temp.cmd('p', format('select public.propose_team_candidate(%L, %L, %L, %L, %L)',
  '00000000-0000-4000-a000-000000000101', 'Kandidatin Nora Test', 'care_assistant', '40-60', pg_temp.k(2))) ->> 'proposal_id')::uuid;
select is(pg_temp.cmd('ca', format('select public.decide_team_candidate(%L, %L, %L, %L)', (select id from fx where name = 'P'),
          'consent', null, pg_temp.k(3))) ->> 'outcome', 'admitted', 'setup: admitted by the team');
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, %L, null, %L)', (select id from fx where name = 'P'),
          'adm2-16-nq@navora.test', pg_temp.today(), pg_temp.k(4))), 'ok', 'setup: "Vertrag erfasst"');
select ok(exists (select 1 from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101'
                  and user_id = pg_temp.u('nq') and qualification is null), 'setup: Nord member without a recorded qualification');

-- Visit 1: unassigned, category A only, planned, today. Visit 2: the same, started later by the care assistant.
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status, planned_minutes_a)
values ('a0940000-0000-4000-8000-000000000001', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today(), '10:00', '10:30', 'planned', 30),
       ('a0940000-0000-4000-8000-000000000002', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today(), '11:00', '11:30', 'planned', 30);
insert into fx values ('v1', 'a0940000-0000-4000-8000-000000000001'), ('v2', 'a0940000-0000-4000-8000-000000000002');

-- (i) Command path: refused, nothing changes, one audit row -------------------------------------------------------------------
select is(pg_temp.res('nq', format('select public.start_visit(%L, %L)', (select id from fx where name = 'v1'), pg_temp.k(10))),
          'qualification_missing', 'ADM2-16 (i): start_visit by a member without a qualification is refused');
select is(pg_temp.status((select id from fx where name = 'v1')), 'planned', 'ADM2-16 (i): status unchanged');
select is((select count(*)::int from public.visit_events where visit_id = (select id from fx where name = 'v1')), 0,
          'ADM2-16 (i): no visit event');
select is(pg_temp.refusals((select id from fx where name = 'v1'), 'start_visit'), 1,
          'ADM2-16 (i): one audit row (outcome code, her, no idempotency key)');
select is(pg_temp.res('nq', format('select public.start_visit(%L, %L)', (select id from fx where name = 'v1'), pg_temp.k(10))),
          'qualification_missing', 'ADM2-16 (i): a retry with the same key is evaluated again, not answered as duplicate');
select is(pg_temp.res('nq', format('select public.depart_visit(%L, %L)', (select id from fx where name = 'v1'), pg_temp.k(11))),
          'qualification_missing', 'ADM2-16: depart_visit refused');
select is(pg_temp.refusals((select id from fx where name = 'v1'), 'depart_visit'), 1, 'ADM2-16: depart refusal audited once');
select is(pg_temp.status((select id from fx where name = 'v1')), 'planned', 'ADM2-16: still planned after depart refusal');

-- (ii) Direct path -------------------------------------------------------------------------------------------------------------
select throws_ok(format($$select pg_temp.direct('nq', %L, 'started')$$, (select id from fx where name = 'v1')),
                 '42501', 'qualification_missing', 'ADM2-16 (ii): a direct update to started is refused');
select throws_ok(format($$select pg_temp.direct('nq', %L, 'on_the_way')$$, (select id from fx where name = 'v1')),
                 '42501', 'qualification_missing', 'ADM2-16 (ii): a direct update to on_the_way is refused');
select is(pg_temp.status((select id from fx where name = 'v1')), 'planned', 'ADM2-16 (ii): status unchanged');

-- Completion and resume of a visit a qualified colleague started -------------------------------------------------------------
select is(pg_temp.res('ca', format('select public.start_visit(%L, %L)', (select id from fx where name = 'v2'), pg_temp.k(20))),
          'ok', 'unchanged: a care assistant starts a category A visit');
select is(pg_temp.res('nq', format('select public.complete_visit(%L, %L)', (select id from fx where name = 'v2'), pg_temp.k(21))),
          'qualification_missing', 'ADM2-16: complete_visit by her is refused');
select is(pg_temp.status((select id from fx where name = 'v2')), 'started', 'ADM2-16: the visit stays started');
select throws_ok(format($$select pg_temp.direct('nq', %L, 'completed')$$, (select id from fx where name = 'v2')),
                 '42501', 'qualification_missing', 'ADM2-16 (ii): a direct update to completed is refused');
select is(pg_temp.res('nq', format('select public.pause_visit(%L, %L)', (select id from fx where name = 'v2'), pg_temp.k(22))),
          'ok', 'unchanged: pause is not performing (passes)');
select is(pg_temp.res('nq', format('select public.resume_visit(%L, %L)', (select id from fx where name = 'v2'), pg_temp.k(23))),
          'qualification_missing', 'ADM2-16: resume (into started) by her is refused');
select is(pg_temp.status((select id from fx where name = 'v2')), 'paused', 'ADM2-16: the visit stays paused');
select is(pg_temp.res('ca', format('select public.resume_visit(%L, %L)', (select id from fx where name = 'v2'), pg_temp.k(24))),
          'ok', 'unchanged: the qualified colleague resumes');

-- Cover: the covering nurse is checked in her cover team; nobody else through it ------------------------------------------------
select is(pg_temp.cmd('mitte', format('select private.actor_may_perform_visit(%L, %L, %L)', '00000000-0000-4000-a000-000000000101',
          '00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'))), 'true'::jsonb,
          'ADM2-16: the covering nurse with a qualification in the cover team may perform');
select is(pg_temp.cmd('mitte', format('select private.actor_may_perform_visit(%L, %L, %L)', '00000000-0000-4000-a000-000000000101',
          '00000000-0000-4000-a000-000000000102', pg_temp.u('p'))), 'false'::jsonb,
          'ADM2-16: a cover team qualification counts only for the covering nurse');
select is(pg_temp.cmd('nq', format('select private.actor_may_perform_visit(%L, null, null)', '00000000-0000-4000-a000-000000000101')),
          'false'::jsonb, 'ADM2-16: no qualification in the visit''s team, no cover: may not perform');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'private' and p.proname = 'actor_may_perform_visit'
             and exists (select 1 from unnest(p.proargnames) a where a ~ 'user')), 0,
          'ADM2-16: the check answers only about the caller (no user parameter)');

-- (iii) After the administrator records her qualification -------------------------------------------------------------------
select is(pg_temp.res('admin', format('select public.set_member_qualification(%L, %L, %L, %L, %L)', '00000000-0000-4000-a000-000000000101',
          pg_temp.u('nq'), 'care_assistant', 'Diplom geprüft', pg_temp.k(30))), 'ok', 'ADM2-16 (iii): qualification recorded (ADM2-6 path)');
select is(pg_temp.res('nq', format('select public.start_visit(%L, %L)', (select id from fx where name = 'v1'), pg_temp.k(31))),
          'ok', 'ADM2-16 (iii): the same start is ok');
select is(pg_temp.res('nq', format('select public.complete_visit(%L, %L)', (select id from fx where name = 'v2'), pg_temp.k(32))),
          'ok', 'ADM2-16 (iii): she completes the visit her colleague started');
select is(pg_temp.status((select id from fx where name = 'v1')), 'started', 'ADM2-16 (iii): started');
select is((select count(*)::int from public.audit_events a where a.changed #>> '{outcome,new}' = 'qualification_missing'), 5,
          'ADM2-16: exactly the five command refusals were audited (direct writes roll back)');

select * from finish();
rollback;
