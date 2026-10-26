-- COND1-5: WORK1-C2 (information text v2) and WORK1-C3 (a leaver's unexported days, for administrators only).
-- Migration 0083, ADR-096. Brief `docs/agents/briefs/COND1.md`, conditions in `docs/agents/briefs/WORK1.md` (PO 08:15).
-- Synthetic users added here: …8301 care assistant of Testteam Nord (…101, seed), the person whose days are counted and
-- whose access ends; …8302 registered nurse of Nord; …8303 care assistant of Nord; …8304 administrator of org A;
-- …8305 administrator of org B. All data synthetic; every step goes through the real commands, except the steps marked
-- "as the table owner". The clock is pinned per step (DST1 test clock), so the result does not depend on the day CI runs.
begin;
create extension if not exists pgtap with schema extensions;

select plan(26);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns text language sql immutable as $$
  select 'a0830000-0000-4000-a000-00000000830' || substr(n, 2, 1) $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0831000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.pin(p_at text) returns void language sql as $$ select set_config('navora.test_now', p_at, true) $$;
create function pg_temp.cmd(p_user text, p_sql text, p_at text default '2026-10-26 12:00:00+01') returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.pin(p_at);
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.seen(p_user text, p_sql text) returns integer language plpgsql as $$
declare n integer;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute 'select count(*)::int from (' || p_sql || ') x' into n;
  execute 'reset role';
  return n;
end $$;
-- A day with start, end and both questions answered (no visit segment, no break).
create function pg_temp.confirm(p_date text, k int, p_at text, p_extra jsonb default '{}') returns text language sql as $$
  select pg_temp.cmd('x1', format('select public.confirm_working_day(%L::date, %L::jsonb, %L::uuid)', p_date,
           jsonb_build_object('day_start', p_date || 'T08:00:00+02:00', 'day_end', p_date || 'T12:00:00+02:00',
                              'breaks', 'none', 'outside_work', 'none') || p_extra, pg_temp.k(k)), p_at) ->> 'result' $$;
create function pg_temp.export(p_month text, k int, p_at text) returns text language sql as $$
  select pg_temp.cmd('x1', format('select public.export_working_month(%L::date, %L::uuid)', p_month, pg_temp.k(k)), p_at) ->> 'result' $$;
-- The administrator's count of x1 as seen by p_user ('null' when none).
create function pg_temp.member_count(p_user text) returns text language sql as $$
  select coalesce(pg_temp.cmd(p_user, format('select to_jsonb(public.member_unexported_working_days(%L::uuid))', pg_temp.u('x1'))) #>> '{}', 'null') $$;
create function pg_temp.own_count(p_user text) returns text language sql as $$
  select coalesce(pg_temp.cmd(p_user, 'select to_jsonb(public.my_unexported_working_days())') #>> '{}', 'null') $$;

-- Synthetic accounts (as the table owner) ----------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u('x' || i)::uuid, 'cond1-5-x' || i || '@navora.test' from generate_series(1, 5) i;
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('x1')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('x2')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('x3')::uuid, 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('x4')::uuid, 'admin'),
  ('00000000-0000-4000-b000-000000000012', pg_temp.u('x5')::uuid, 'admin');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('x1')::uuid, 'care_assistant'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('x2')::uuid, 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('x3')::uuid, 'care_assistant');

-- WORK1-C2: information text v2; a v1 acknowledgement does not carry over --------------------------------------------
select is(private.working_time_notice_version(), 'work1-notice-v2', 'WORK1-C2: the current text version is work1-notice-v2');
-- x1 runs one visit of Nord (case 208) on 2026-10-22 through the real commands, so her day has a proposal.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', 'a0830000-0000-4000-8000-000000000001', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', '2026-10-22', '08:15', '08:45', false, 'planned', 20, 0, 10, pg_temp.u('x1')::uuid);
create function pg_temp.step(p_cmd text, p_at text, k int) returns text language sql as $$
  select pg_temp.cmd('x1', format('select to_jsonb(public.%s(%L::uuid, %L::uuid))', p_cmd, 'a0830000-0000-4000-8000-000000000001',
                                  pg_temp.k(k)), p_at) #>> '{}' $$;
select is(pg_temp.step('depart_visit', '2026-10-22 08:00:00+02', 1) || ',' || pg_temp.step('start_visit', '2026-10-22 08:15:00+02', 2)
          || ',' || pg_temp.step('complete_visit', '2026-10-22 09:00:00+02', 3), 'ok,ok,ok', 'fixture: x1 runs her visit through the real commands');
-- She acknowledged v1 before 0083 (as the table owner: the command accepts only the current version).
insert into public.working_time_notice_acks (organization_id, user_id, text_version, acknowledged_at)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('x1')::uuid, 'work1-notice-v1', '2026-10-21 09:00:00+02');
select is(pg_temp.cmd('x1', 'select public.my_working_time_notice()') - 'acknowledged_at',
  '{"text_version": "work1-notice-v2", "acknowledged": false}'::jsonb, 'WORK1-C2: with a v1 acknowledgement she is shown v2 as not acknowledged');
select is(pg_temp.seen('x1', $$ select 1 from public.my_working_day('2026-10-22') $$), 0,
  'WORK1-C2: my_working_day returns nothing for a v1-only acknowledgement');
select is(pg_temp.cmd('x1', format('select public.acknowledge_working_time_notice(%L, %L::uuid)', 'work1-notice-v1', pg_temp.k(10))) ->> 'result',
  'invalid', 'WORK1-C2: v1 can no longer be acknowledged');
select is(pg_temp.cmd('x1', format('select public.acknowledge_working_time_notice(%L, %L::uuid)', 'work1-notice-v2', pg_temp.k(11))) ->> 'result',
  'ok', 'WORK1-C2: she acknowledges v2');
select is(pg_temp.seen('x1', $$ select 1 from public.my_working_day('2026-10-22') $$), 2,
  'WORK1-C2: after v2 her proposal is shown (travel and care of her visit)');
select is((select string_agg(text_version, ',' order by text_version) from public.working_time_notice_acks where user_id = pg_temp.u('x1')::uuid),
  'work1-notice-v1,work1-notice-v2', 'both acknowledgements stay recorded (append-only)');

-- WORK1-C3: the count ------------------------------------------------------------------------------------------------
select is(pg_temp.confirm('2026-09-28', 20, '2026-10-26 10:00:00+01') || pg_temp.confirm('2026-09-29', 21, '2026-10-26 10:00:00+01')
          || pg_temp.confirm('2026-10-05', 22, '2026-10-26 10:00:00+01'), 'okokok', 'fixture: x1 confirms three days (two in September, one in October)');
select is(pg_temp.member_count('x4') || '/' || pg_temp.own_count('x1'), '3/3', 'before any export: three unexported days (administrator / herself)');
select is(pg_temp.export('2026-09-01', 30, '2026-10-26 11:00:00+01'), 'ok', 'she exports September after its two days');
select is(pg_temp.member_count('x4'), '1', 'WORK1-C3 (a): the administrator of her organisation sees 1');
select is(pg_temp.member_count('x2') || ',' || pg_temp.member_count('x3') || ',' || pg_temp.member_count('x5'), 'null,null,null',
  'WORK1-C3 (a): her team''s registered nurse, a care assistant and another organisation''s administrator see nothing');
select is(pg_temp.own_count('x1') || '/' || pg_temp.own_count('x2'), '1/0', 'WORK1-C3 (d): she sees her own count on /work; a colleague sees only her own (0)');
select is(pg_temp.export('2026-10-01', 31, '2026-10-26 11:30:00+01'), 'ok', 'she exports October');
select is(pg_temp.member_count('x4') || '/' || pg_temp.own_count('x1'), '0/0', 'WORK1-C3: after she exports, 0');
select is(pg_temp.export('2026-10-01', 31, '2026-10-26 11:30:00+01') || '/'
          || (select count(*) from public.working_day_exports where user_id = pg_temp.u('x1')::uuid),
  'duplicate/2', 'a repeated export key records no second export');
select is(pg_temp.confirm('2026-10-05', 23, '2026-10-26 12:00:00+01', '{"reason_code": "time_wrong"}'), 'ok',
  'she corrects an October day after the export (version 2)');
select is(pg_temp.member_count('x4') || '/' || pg_temp.own_count('x1'), '1/1', 'WORK1-C3: a correction after the export → 1 again');

-- WORK1-C3 (b): one number; the export record carries no day, time or content and is read by no app role --------------
select is((select string_agg(column_name::text, ',' order by ordinal_position) from information_schema.columns
           where table_schema = 'public' and table_name = 'working_day_exports'),
  'id,organization_id,user_id,month,exported_at', 'WORK1-C3 (b): the export record holds who, month and when only');
select ok(not has_table_privilege('authenticated', 'public.working_day_exports', 'select')
          and not has_table_privilege('authenticated', 'public.working_day_exports', 'insert')
          and not has_table_privilege('anon', 'public.working_day_exports', 'select')
          and not has_function_privilege('authenticated', 'private.unexported_working_days(uuid, uuid)', 'execute'),
  'WORK1-C3 (b): no app role reads the export record or calls the per-person helper');
select is((select count(*)::int from public.audit_events a join public.working_day_exports x on x.id = a.entity_id
           where a.table_name = 'working_day_exports' and x.user_id = pg_temp.u('x1')::uuid and a.changed ? 'month'
             and not a.changed ? 'unexported_days'), 2, 'each export stays audited (month, days, unconfirmed), keyed by its record');
select is((select string_agg(coalesce(array_to_string(proargnames, ','), ''), '|' order by proname) from pg_proc
           where oid in ('public.team_open_reports()'::regprocedure, 'public.member_open_reports(uuid)'::regprocedure)
             and array_to_string(proargnames, ',') ~ 'unexport'), null,
  'WORK1-C3 (a): the registered nurses'' LEAVE1-12 lists carry no unexported count');

-- WORK1-C3 (a): the access end result -----------------------------------------------------------------------------------
create temp table ended as
select pg_temp.cmd('x4', format('select public.end_member_access(%L::uuid, %L, %L::uuid)', pg_temp.u('x1'), 'employment_ended', pg_temp.k(40)),
                   '2026-10-26 13:00:00+01') j;
select is((select (j ->> 'result') || '/' || (j ->> 'unexported_days') from ended), 'ok/1',
  'WORK1-C3 (a): end_member_access returns her unexported days to the administrator');
select is((select count(*)::int from public.change_log where entity_id = pg_temp.u('x1') and command = 'end_member_access' and changes ? 'unexported_days')
          + (select count(*)::int from public.audit_events where entity_id = pg_temp.u('x1')::uuid and command = 'end_member_access'
               and changed ? 'unexported_days'), 0,
  'WORK1-C3 (b): the count is in the result only, never in the change log or audit row (no stored per-person figure)');
select is(pg_temp.own_count('x1') || '/' || pg_temp.member_count('x4'), 'null/1',
  'WORK1-C3 (d): after the end she sees no count (LEAVE1-3); the administrator still sees the one number');

select * from finish();
rollback;
