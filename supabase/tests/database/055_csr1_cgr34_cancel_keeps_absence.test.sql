-- CSR1 part 11 / CGR-34 (migration 0054, ADR-066; PO 2026-10-23 20:15 in docs/agents/briefs/ABS1.md): a cancellation
-- of a past planned visit flagged by CGR-32 (its responsible member recorded absent at its interval) stores, server
-- side and immutably, `responsible_absent = true` on its status note. Any other cancellation stores false. The caller
-- cannot set it; withdrawing the absence later does not erase it. No new reason code.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) is absent · care assistant …906 (Nord) records the absence
-- and cancels. All data synthetic. Fixtures are written as the table owner; every step under test goes through the
-- real commands and readers as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(26);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;

create temp table fx (name text primary key, id uuid not null, d int not null, t0 time not null, resp uuid not null);
grant select on fx to authenticated;
insert into fx values
  -- yesterday 07:00, hers, inside the absence recorded below: flagged by CGR-32
  ('flagged', 'a0550000-0000-4000-8000-000000000001', -1, '07:00', '00000000-0000-4000-a000-000000000902'),
  -- two days ago 07:00, the colleague's; nobody absent then (the seed's ended absence of 906 covers yesterday only)
  ('plain',   'a0550000-0000-4000-8000-000000000002', -2, '07:00', '00000000-0000-4000-a000-000000000906'),
  -- tomorrow 09:00, hers: released by the absence (nobody responsible), then cancelled
  ('future',  'a0550000-0000-4000-8000-000000000003',  1, '09:00', '00000000-0000-4000-a000-000000000902');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       pg_temp.today() + f.d, f.t0, f.t0 + interval '30 minutes', array['Grundpflege'], false, 'planned', 30, 0, f.resp
from fx f;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.flag(n text) returns boolean language sql as $$
  select s.responsible_absent from public.visit_status_notes s where s.visit_id = pg_temp.vid(n) and s.kind = 'cancelled' $$;

-- 1. A colleague records her absent from yesterday 06:00 until tomorrow (whole day) -----------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
create temp table r1 as
  select public.record_absence('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902',
                               pg_temp.today() - 1, pg_temp.today() + 1, '06:00', null, 'a5500000-0000-4000-8000-000000000001') as r;
select is((select r ->> 'result' from r1), 'ok', 'the absence from yesterday 06:00 is recorded');
select ok(exists (select 1 from public.team_visit_alerts() a where a.exception_type = 'visit_overdue'
                  and a.visit_id = pg_temp.vid('flagged') and a.flags = array['responsible_absent']),
  'precondition (CGR-32): yesterday''s visit has its overdue alert, flagged responsible_absent');
reset role;
select is((select responsible_user_id from public.care_visits where id = pg_temp.vid('future')), null,
  'precondition: tomorrow''s visit is released (nobody responsible)');

-- 2. The team cancels the flagged visit with an existing reason ---------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.cancel_visit(pg_temp.vid('flagged'), 'team_cancelled', null, 'a5500000-0000-4000-8000-000000000002'), 'ok',
  'CGR-34: the flagged past visit is cancelled with team_cancelled (no new reason code, no extra parameter)');
select is(public.cancel_visit(pg_temp.vid('flagged'), 'team_cancelled', null, 'a5500000-0000-4000-8000-000000000002'), 'duplicate',
  'the same command again is a duplicate');
reset role;
select is(pg_temp.flag('flagged'), true, 'CGR-34 (1): its status note stores responsible_absent = true');
select is((select reason_code from public.visit_status_notes where visit_id = pg_temp.vid('flagged')), 'team_cancelled',
  'the chosen reason is kept as given');
select is((select count(*)::int from public.visit_status_notes where visit_id = pg_temp.vid('flagged')), 1,
  'exactly one status note for the visit');
select is((select status from public.care_visits where id = pg_temp.vid('flagged')), 'cancelled', 'the visit is cancelled');
select is((select (a.changed -> 'responsible_absent' ->> 'new')::boolean from public.audit_events a
           join public.visit_status_notes s on s.id = a.entity_id
           where a.table_name = 'visit_status_notes' and s.visit_id = pg_temp.vid('flagged')), true,
  'the audit event of the note records responsible_absent = true');

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select ok(not exists (select 1 from public.team_visit_alerts() a where a.visit_id = pg_temp.vid('flagged')),
  'the overdue alert ends with the cancellation');
select is((select n.responsible_absent from public.field_visit_status_notes(pg_temp.today() - 1) n
           where n.visit_id = pg_temp.vid('flagged') and n.kind = 'cancelled'), true,
  'CGR-34: /field (field_visit_status_notes) returns responsible_absent = true for the cancellation');

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select x.flags from public.operations_exceptions() x
           where x.exception_type = 'team_cancellation_late' and x.entity_id = pg_temp.vid('flagged')),
          array['not_done_responsible_absent'],
  'CGR-34: in OPS1 the late team cancellation of the flagged visit carries not_done_responsible_absent');
select ok(not exists (select 1 from public.operations_exceptions() x
                      where x.exception_type <> 'team_cancellation_late' and 'not_done_responsible_absent' = any (x.flags)),
  'only team cancellations carry that flag');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;

-- 3. A released future visit cancelled while the absence holds: false --------------------------------------------
select is(public.cancel_visit(pg_temp.vid('future'), 'client_cancelled', null, 'a5500000-0000-4000-8000-000000000003'), 'ok',
  'tomorrow''s released visit is cancelled');
reset role;
select is(pg_temp.flag('future'), false, 'CGR-34 (2): a cancel of a future visit (released, nobody responsible) stores false');

-- 4. Withdrawing the absence does not erase the stored fact -------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.change_absence((select (r ->> 'absence_id')::uuid from r1), true, null, null,
          'a5500000-0000-4000-8000-000000000004') ->> 'result', 'ok', 'the recorder withdraws the absence');
reset role;
select is(pg_temp.flag('flagged'), true, 'CGR-34 (2): after the withdrawal the note still has responsible_absent = true');

-- 5. A past visit without an absence: false -------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.cancel_visit(pg_temp.vid('plain'), 'team_cancelled', null, 'a5500000-0000-4000-8000-000000000005'), 'ok',
  'a past visit whose responsible member was not absent is cancelled with team_cancelled');
reset role;
select is(pg_temp.flag('plain'), false, 'CGR-34 (2): the same cancel on a past visit without an absence stores false');

-- 6. The caller cannot set or change it; only a cancellation can carry it ------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.visit_status_notes', 'insert')
          and not has_table_privilege('authenticated', 'public.visit_status_notes', 'update')
          and not has_table_privilege('authenticated', 'public.visit_status_notes', 'delete'),
  'CGR-34 (1): authenticated cannot insert, update or delete status notes (the flag is set only by cancel_visit)');
select ok(not exists (select 1 from information_schema.parameters p
                      where p.specific_schema = 'public' and p.specific_name like 'cancel_visit\_%'
                        and p.parameter_name ilike '%absent%'),
  'cancel_visit has no parameter for it');
select throws_ok($$ update public.visit_status_notes set responsible_absent = false where visit_id = pg_temp.vid('flagged') $$,
  '42501', null, 'the stored fact is immutable: status notes stay append-only, even for the table owner');
select throws_ok($$ insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key, responsible_absent)
                    values ('00000000-0000-4000-b000-000000000011', pg_temp.vid('plain'), 'no_show', 'Synthetisch',
                            '00000000-0000-4000-a000-000000000906', 'a5500000-0000-4000-8000-000000000006', true) $$,
  '23514', null, 'only a cancelled note can carry responsible_absent = true (check constraint)');

-- 7. HAND1 carries it in the detail of a status-note entry -----------------------------------------------------------
select ok(pg_get_functiondef('private.handover_entries(uuid, uuid)'::regprocedure)
          like '%''responsible_absent'', n.responsible_absent%',
  'HAND1 (handover_entries) adds responsible_absent to the detail of status-note entries');
select ok(not has_function_privilege('anon', 'public.field_visit_status_notes(date)', 'execute')
          and has_function_privilege('authenticated', 'public.field_visit_status_notes(date)', 'execute'),
  'field_visit_status_notes: authenticated may execute, anon may not (grants restated)');

select * from finish();
rollback;
