-- COND1-3: WORK1-C1 (care cannot exceed paid time) and WORK1-C4 (one time per visit event). Migration 0081, ADR-094.
-- Brief `docs/agents/briefs/COND1.md`, conditions in `docs/agents/briefs/WORK1.md` (PO review 07:15 and 10:15).
-- Synthetic users added here: …8101 care assistant of Testteam Nord (…101, seed), whose visit events are corrected;
-- …8102-…8104 members of the synthetic Testteam C (three people) for the team ratio. All data synthetic; every step
-- goes through the real commands, except the steps marked "as the table owner". The clock is pinned per step (DST1
-- test clock), so the result does not depend on the day CI runs.
begin;
create extension if not exists pgtap with schema extensions;

select plan(21);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns text language sql immutable as $$
  select 'a0810000-0000-4000-a000-00000000810' || substr(n, 2, 1) $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0811000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.confirm(p_user text, p_date text, p_payload jsonb, k int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.confirm_working_day(%L::date, %L::jsonb, %L::uuid)', p_date, p_payload, pg_temp.k(k))) $$;
create function pg_temp.day(p_start text, p_end text, p_segments jsonb, p_breaks jsonb) returns jsonb language sql as $$
  select jsonb_build_object('day_start', p_start, 'day_end', p_end, 'segments', p_segments, 'breaks', p_breaks, 'outside_work', '"none"'::jsonb) $$;
create function pg_temp.care(p_start text, p_end text) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'care', 'start', p_start, 'end', p_end) $$;
-- Her proposal as text: kind:start-end(UTC):corrected, in proposal order.
create function pg_temp.proposal(p_date text) returns text language sql as $$
  select pg_temp.cmd('c1', format($q$ select to_jsonb(string_agg(visit_no || ':' || kind || ':' || to_char(starts_at at time zone 'UTC', 'MM-DD HH24:MI')
                                       || '-' || coalesce(to_char(ends_at at time zone 'UTC', 'HH24:MI'), 'open') || ':' || corrected, ',' order by seq))
                                   from public.my_working_day(%L::date) $q$, p_date)) #>> '{}' $$;
-- Row fingerprints of the two visit-time tables (as the table owner).
create function pg_temp.visit_time_fp() returns text language sql as $$
  select (select md5(coalesce(string_agg(to_jsonb(e)::text, '' order by e.id), '')) from public.visit_events e) || '/'
      || (select md5(coalesce(string_agg(to_jsonb(c)::text, '' order by c.id), '')) from public.visit_time_corrections c) $$;

-- Synthetic accounts and team (as the table owner) -------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u('c' || i)::uuid, 'cond1-3-c' || i || '@navora.test' from generate_series(1, 4) i;
insert into public.organization_memberships (organization_id, user_id, role)
select '00000000-0000-4000-b000-000000000011', pg_temp.u('c' || i)::uuid, 'nurse' from generate_series(1, 4) i;
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000011', 'a0810000-0000-4000-a000-000000008190', 'Testteam C', 'Testregion', 'active');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('c1')::uuid, 'care_assistant'),
  ('a0810000-0000-4000-a000-000000008190', pg_temp.u('c2')::uuid, 'registered_nurse'),
  ('a0810000-0000-4000-a000-000000008190', pg_temp.u('c3')::uuid, 'care_assistant'),
  ('a0810000-0000-4000-a000-000000008190', pg_temp.u('c4')::uuid, 'care_assistant');

-- WORK1-C1: care cannot exceed paid time --------------------------------------------------------------------------------
select is(pg_temp.confirm('c2', '2026-10-19', pg_temp.day('2026-10-19T08:00:00+02:00', '2026-10-19T12:00:00+02:00',
            jsonb_build_array(pg_temp.care('2026-10-19T09:00:00+02:00', '2026-10-19T10:00:00+02:00'),
                              pg_temp.care('2026-10-19T09:30:00+02:00', '2026-10-19T10:30:00+02:00')), '"none"'), 1) ->> 'result',
  'ok', 'WORK1-C1: two overlapping care segments are stored as confirmed, never refused');
select is((select care_minutes || '/' || paid_minutes || '/' || jsonb_array_length(entries) from public.working_day_versions
           where user_id = pg_temp.u('c2')::uuid and work_date = '2026-10-19'), '90.0/240.0/2',
  'WORK1-C1 (a): care segments 09:00-10:00 and 09:30-10:30 count 90 minutes (union), both segments kept');
select is(pg_temp.confirm('c3', '2026-10-19', pg_temp.day('2026-10-19T08:00:00+02:00', '2026-10-19T14:00:00+02:00',
            jsonb_build_array(pg_temp.care('2026-10-19T12:00:00+02:00', '2026-10-19T13:00:00+02:00')),
            '[{"start":"2026-10-19T12:30:00+02:00","end":"2026-10-19T13:00:00+02:00"}]'), 2) ->> 'result',
  'ok', 'a care segment with a declared break inside it is confirmed');
select is((select care_minutes || '/' || paid_minutes || '/' || break_minutes from public.working_day_versions
           where user_id = pg_temp.u('c3')::uuid and work_date = '2026-10-19'), '30.0/330.0/30.0',
  'WORK1-C1 (b): care 12:00-13:00 with a break 12:30-13:00 counts 30 minutes');
-- (c) Testteam C: three people, five days. On each day the plain sum of the care segments exceeds paid time.
create function pg_temp.over(p_user text, p_date text, k int) returns text language sql as $$
  select pg_temp.confirm(p_user, p_date, pg_temp.day(p_date || 'T08:00:00+02:00', p_date || 'T12:00:00+02:00',
           jsonb_build_array(pg_temp.care(p_date || 'T08:00:00+02:00', p_date || 'T11:00:00+02:00'),
                             pg_temp.care(p_date || 'T08:00:00+02:00', p_date || 'T11:00:00+02:00'),
                             pg_temp.care(p_date || 'T08:30:00+02:00', p_date || 'T11:30:00+02:00')),
           jsonb_build_array(jsonb_build_object('start', p_date || 'T10:00:00+02:00', 'end', p_date || 'T12:00:00+02:00'))), k) ->> 'result' $$;
select is(pg_temp.over('c2', '2026-10-20', 10) || pg_temp.over('c2', '2026-10-21', 11) || pg_temp.over('c3', '2026-10-20', 12)
          || pg_temp.over('c4', '2026-10-20', 13) || pg_temp.over('c4', '2026-10-21', 14),
  'okokokokok', 'Testteam C: three people confirm five days whose care segments sum to 540 of 120 paid minutes each');
select is((select string_agg(distinct care_minutes || '/' || paid_minutes, ',') from public.working_day_versions
           where team_id = 'a0810000-0000-4000-a000-000000008190' and work_date between '2026-10-20' and '2026-10-21'), '120.0/120.0',
  'WORK1-C1 (c): each such day stores care 120 (union 08:00-11:30 = 210, minus break overlap 10:00-11:30 = 90) of paid 120');
create function pg_temp.share(p_team text) returns text language sql security definer as $$
  select coalesce((select people || '/' || days || '/' || coalesce(value::text, '-') || '/' || too_few
                   from private.team_confirmed_care_share('2026-10-01') where team_id = p_team::uuid), 'none') $$;
select is(pg_temp.share('a0810000-0000-4000-a000-000000008190'), '3/7/' ||
          (select round(100.0 * sum(care_minutes) / sum(paid_minutes), 1)::text from public.working_day_versions
           where team_id = 'a0810000-0000-4000-a000-000000008190') || '/false',
  'WORK1-C1 (c): the team ratio is computed from the stored figures');
select ok((select value <= 100 from private.team_confirmed_care_share('2026-10-01')
           where team_id = 'a0810000-0000-4000-a000-000000008190'), 'WORK1-C1 (c): the team ratio stays at or below 100 %');
select is((select count(*)::int from public.working_day_versions where care_minutes > paid_minutes), 0,
  'WORK1-C1: care <= paid for every version stored here');
select is((select pg_get_constraintdef(c.oid) from pg_constraint c
           where c.conrelid = 'public.working_day_versions'::regclass and c.conname = 'working_day_versions_care_le_paid'),
  'CHECK ((care_minutes <= paid_minutes)) NOT VALID', 'WORK1-C1: a check constraint holds care <= paid for every new version');
select throws_ok($$ insert into public.working_day_versions (organization_id, user_id, team_id, work_date, version, day_start, day_end,
                      breaks_answer, outside_answer, entries, paid_minutes, care_minutes, break_minutes)
                    values ('00000000-0000-4000-b000-000000000011', pg_temp.u('c4')::uuid, null, '2026-10-01', 1,
                            '2026-10-01 08:00+02', '2026-10-01 09:00+02', 'none', 'none', '[]', 60, 61, 0) $$,
  '23514', null, 'WORK1-C1: a row with care above paid is refused, even as the table owner');

-- WORK1-C4: one time per visit event --------------------------------------------------------------------------------
-- c1 runs two visits of Nord (case 208): Y on 2026-10-22 at 08:15, X on 2026-10-23 at 00:15 (just after midnight).
create temp table fx (n int primary key, id uuid not null, d date not null, t time not null);
grant select on fx to authenticated, service_role;
insert into fx values
  (1, 'a0810000-0000-4000-8000-000000000001', '2026-10-22', '08:15'),
  (2, 'a0810000-0000-4000-8000-000000000002', '2026-10-23', '00:15');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       f.d, f.t, f.t + interval '30 minutes', false, 'planned', 20, 0, 10, pg_temp.u('c1')::uuid
from fx f;
create function pg_temp.vid(n int) returns uuid language sql as $$ select id from fx where fx.n = $1 $$;
create function pg_temp.step(p_cmd text, n int, p_at text, k int) returns text language sql as $$
  select pg_temp.cmd('c1', format('select to_jsonb(public.%s(%L::uuid, %L::uuid))', p_cmd, pg_temp.vid(n), pg_temp.k(k)), p_at) #>> '{}' $$;
create function pg_temp.ev(n int, p_type text) returns bigint language sql as $$
  select e.id from public.visit_events e where e.visit_id = pg_temp.vid(n) and e.event_type = p_type order by e.id limit 1 $$;
create function pg_temp.fix(n int, p_type text, p_at text, k int) returns text language sql as $$
  select pg_temp.cmd('c1', format('select to_jsonb(public.correct_visit_time(%s, %L::timestamptz, %L, %L::uuid))',
                                  pg_temp.ev(n, p_type), p_at, 'Synthetisch: COND1-3 Zeitkorrektur', pg_temp.k(k))) #>> '{}' $$;

select is(string_agg(r, ',' order by o), 'ok,ok,ok,ok,ok,ok', 'fixture: c1 runs her visits through the real commands')
from (values
  (1, pg_temp.step('depart_visit', 1, '2026-10-22 08:00:00+02', 101)), (2, pg_temp.step('start_visit', 1, '2026-10-22 08:15:00+02', 102)),
  (3, pg_temp.step('complete_visit', 1, '2026-10-22 09:00:00+02', 103)), (4, pg_temp.step('depart_visit', 2, '2026-10-23 00:10:00+02', 104)),
  (5, pg_temp.step('start_visit', 2, '2026-10-23 00:20:00+02', 105)), (6, pg_temp.step('complete_visit', 2, '2026-10-23 00:50:00+02', 106))) s(o, r);
select is(pg_temp.cmd('c1', format('select public.acknowledge_working_time_notice(%L, %L::uuid)', 'work1-notice-v2', pg_temp.k(107))) ->> 'result',
  'ok', 'c1 acknowledges the information text');
select is(pg_temp.proposal('2026-10-22'), '1:travel:10-22 06:00-06:15:false,1:care:10-22 06:15-07:00:false',
  'before any correction: the recorded instants, corrected false');
-- F3 corrections (the visit's own command): the start of Y twice, the departure of X to the previous Zurich date.
select is(pg_temp.fix(1, 'started', '2026-10-22 08:10:00+02', 110) || ',' || pg_temp.fix(1, 'started', '2026-10-22 08:20:00+02', 111)
          || ',' || pg_temp.fix(2, 'departed', '2026-10-22 23:55:00+02', 112), 'ok,ok,ok', 'fixture: three F3 corrections');
create temp table fp_before as select pg_temp.visit_time_fp() as fp;
grant select on fp_before to authenticated;

select is(pg_temp.proposal('2026-10-22'),
  '1:travel:10-22 06:00-06:20:true,1:care:10-22 06:20-07:00:true,2:travel:10-22 21:55-22:20:true',
  'WORK1-C4 (a): an event with two corrections gives the latest corrected instant, corrected true (start and end); the departure moved to 22 October places its segment on that date');
select is(pg_temp.proposal('2026-10-23'), '1:care:10-22 22:20-22:50:false',
  'WORK1-C4 (a): … and removes it from 23 October; an uncorrected segment stays corrected false');
select is((select string_agg(a.attname, ',' order by a.attnum) from pg_proc p, unnest(p.proargnames, p.proargmodes) with ordinality a(attname, md, attnum)
           where p.oid = 'public.my_working_day(date)'::regprocedure and md = 't'),
  'seq,visit_no,kind,starts_at,ends_at,corrected', 'WORK1-C4 (a): `corrected` is the only new column (no reason, no corrector, no visit identifier)');

-- Confirming the day at the effective times: the segments are the proposal's; nothing is written back.
select is(pg_temp.confirm('c1', '2026-10-22', pg_temp.day('2026-10-22T07:30:00+02:00', '2026-10-23T01:30:00+02:00',
            (select jsonb_agg(jsonb_build_object('kind', kind, 'start', starts_at, 'end', ends_at) order by seq)
             from private.working_day_proposal(pg_temp.u('c1')::uuid, '2026-10-22')), '"none"'), 120) ->> 'result',
  'ok', 'she confirms 22 October with the proposal''s segments');
select is((select string_agg((e ->> 'from_proposal'), ',' order by e ->> 'start') from public.working_day_versions w, jsonb_array_elements(w.entries) e
           where w.user_id = pg_temp.u('c1')::uuid and w.work_date = '2026-10-22'), 'true,true,true',
  'WORK1-C4 (a): the effective times are the proposal''s (from_proposal true)');
select is(pg_temp.visit_time_fp(), (select fp from fp_before),
  'WORK1-C4 (c): confirming leaves visit_events and visit_time_corrections unchanged (row fingerprint before and after)');

select * from finish();
rollback;
