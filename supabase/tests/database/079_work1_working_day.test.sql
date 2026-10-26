-- WORK1: the working day is proposed from the visits; the nurse confirms it (migration 0079, ADR-092). Brief
-- `docs/agents/briefs/WORK1.md` (WORK1-1 to WORK1-10). Users from the seed: nurse …902 (registered nurse, Testteam Nord
-- …101) · nurse …906 (care assistant, Nord) · coach …901 · operations …904 · admin …905 (org A, no team).
-- Synthetic users added here: …7901 care assistant of Nord, whose day is proposed and confirmed; …7902-…7904 members of
-- the synthetic Testteam W (three people), …7905-…7906 members of Testteam Z (two people). All data synthetic; every
-- step goes through the real commands, except the steps marked "as the table owner". The clock is pinned per step
-- (DST1 test clock), so the result does not depend on the day CI runs.
begin;
create extension if not exists pgtap with schema extensions;

select plan(68);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns text language sql immutable as $$
  select case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                when 'admin' then '00000000-0000-4000-a000-000000000905'
                else 'a0790000-0000-4000-a000-00000000790' || substr(n, 2, 1) end
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0791000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.pin(p_at text) returns void language sql as $$ select set_config('navora.test_now', p_at, true) $$;
-- Run a statement as a user through `authenticated` at a pinned clock, then return to the table owner.
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
create function pg_temp.confirm(p_user text, p_date text, p_payload jsonb, k int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.confirm_working_day(%L::date, %L::jsonb, %L::uuid)', p_date, p_payload, pg_temp.k(k))) $$;
create function pg_temp.ack(p_user text, k int) returns text language sql as $$
  select pg_temp.cmd(p_user, format('select public.acknowledge_working_time_notice(%L, %L::uuid)', 'work1-notice-v1', pg_temp.k(k))) ->> 'result' $$;
create function pg_temp.day(p_start text, p_end text, p_segments jsonb, p_breaks jsonb, p_outside jsonb) returns jsonb language sql as $$
  select jsonb_build_object('day_start', p_start, 'day_end', p_end, 'segments', p_segments, 'breaks', p_breaks, 'outside_work', p_outside) $$;
-- WORK1-5 catalogue: a fingerprint of everything the user reads through every readable table (selectable columns
-- only) and every stable set-returning read model (date arguments = her day). Compared before and after her actions.
create function pg_temp.fingerprint(p_user text) returns text language plpgsql as $$
declare t record; f record; cols text; arg text; h text; acc text := '';
begin
  perform pg_temp.pin('2026-10-26 12:00:00+01');
  for t in select c.oid, c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
           where s.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p', 'f')
             and has_any_column_privilege('authenticated', c.oid, 'select') order by 2 loop
    select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into cols from pg_attribute a
    where a.attrelid = t.oid and a.attnum > 0 and not a.attisdropped and has_column_privilege('authenticated', t.oid, a.attnum, 'select');
    perform pg_temp.act_as(pg_temp.u(p_user));
    execute 'set local role authenticated';
    execute format('select md5(coalesce(string_agg(x, '','' order by x), '''')) from (select md5(row(%s)::text) x from public.%I) y', cols, t.relname) into h;
    execute 'reset role';
    acc := acc || t.relname || '=' || h || ' ';
  end loop;
  for f in select p.oid, p.proname, p.proargtypes::regtype[] ty from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and p.prokind = 'f' and p.proretset and p.provolatile in ('s', 'i')
             and has_function_privilege('authenticated', p.oid, 'execute') order by 2 loop
    select string_agg(case x::text when 'date' then '''2026-10-22''::date' when 'boolean' then 'true' else 'null::' || x::text end, ', ')
      into arg from unnest(f.ty) x;
    perform pg_temp.act_as(pg_temp.u(p_user));
    execute 'set local role authenticated';
    begin
      execute format('select md5(coalesce(string_agg(x, '','' order by x), '''')) from (select md5(r::text) x from public.%I(%s) r) y',
                     f.proname, coalesce(arg, '')) into h;
    exception when others then h := 'error:' || sqlstate;
    end;
    execute 'reset role';
    acc := acc || f.proname || '=' || h || ' ';
  end loop;
  return acc;
end $$;

-- Synthetic accounts and teams (as the table owner) ------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u('w' || i)::uuid, 'work1-w' || i || '@navora.test' from generate_series(1, 6) i;
insert into public.organization_memberships (organization_id, user_id, role)
select '00000000-0000-4000-b000-000000000011', pg_temp.u('w' || i)::uuid, 'nurse' from generate_series(1, 6) i;
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000011', 'a0790000-0000-4000-a000-000000007990', 'Testteam W', 'Testregion', 'active'),
  ('00000000-0000-4000-b000-000000000011', 'a0790000-0000-4000-a000-000000007991', 'Testteam Z', 'Testregion', 'active');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('w1')::uuid, 'care_assistant'),
  ('a0790000-0000-4000-a000-000000007990', pg_temp.u('w2')::uuid, 'registered_nurse'),
  ('a0790000-0000-4000-a000-000000007990', pg_temp.u('w3')::uuid, 'care_assistant'),
  ('a0790000-0000-4000-a000-000000007990', pg_temp.u('w4')::uuid, 'care_assistant'),
  ('a0790000-0000-4000-a000-000000007991', pg_temp.u('w5')::uuid, 'registered_nurse'),
  ('a0790000-0000-4000-a000-000000007991', pg_temp.u('w6')::uuid, 'care_assistant');

-- Visits of w1 (Nord, case 208): three on 2026-10-22, one on 2026-10-23 (left unconfirmed); one of Testteam W in October.
create temp table fx (n int primary key, id uuid not null, d date not null, t time not null, team uuid not null);
grant select on fx to authenticated, service_role;
insert into fx values
  (1, 'a0790000-0000-4000-8000-000000000001', '2026-10-22', '07:15', '00000000-0000-4000-a000-000000000101'),
  (2, 'a0790000-0000-4000-8000-000000000002', '2026-10-22', '08:25', '00000000-0000-4000-a000-000000000101'),
  (3, 'a0790000-0000-4000-8000-000000000003', '2026-10-22', '09:20', '00000000-0000-4000-a000-000000000101'),
  (4, 'a0790000-0000-4000-8000-000000000004', '2026-10-23', '08:00', '00000000-0000-4000-a000-000000000101'),
  (5, 'a0790000-0000-4000-8000-000000000005', '2026-10-20', '08:00', 'a0790000-0000-4000-a000-000000007990');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, case when f.n < 5 then '00000000-0000-4000-a000-000000000208'::uuid end,
       f.team, f.d, f.t, f.t + interval '30 minutes', false, case when f.n < 5 then 'planned' else 'completed' end, 20, 0, 10,
       case when f.n < 5 then pg_temp.u('w1')::uuid end
from fx f;
create function pg_temp.vid(n int) returns uuid language sql as $$ select id from fx where fx.n = $1 $$;
create function pg_temp.step(p_cmd text, n int, p_at text, k int) returns text language sql as $$
  select pg_temp.cmd('w1', format('select to_jsonb(public.%s(%L::uuid, %L::uuid))', p_cmd, pg_temp.vid(n), pg_temp.k(k)), p_at) #>> '{}' $$;

select is(string_agg(r, ',' order by o), 'ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,ok', 'fixture: w1 runs her visits through the real commands')
from (values
  (1, pg_temp.step('depart_visit', 1, '2026-10-22 07:00:00+02', 1)), (2, pg_temp.step('start_visit', 1, '2026-10-22 07:15:00+02', 2)),
  (3, pg_temp.step('pause_visit', 1, '2026-10-22 07:30:00+02', 3)), (4, pg_temp.step('resume_visit', 1, '2026-10-22 07:40:00+02', 4)),
  (5, pg_temp.step('complete_visit', 1, '2026-10-22 08:00:00+02', 5)), (6, pg_temp.step('depart_visit', 2, '2026-10-22 08:10:00+02', 6)),
  (7, pg_temp.step('start_visit', 2, '2026-10-22 08:25:00+02', 7)), (8, pg_temp.step('complete_visit', 2, '2026-10-22 09:00:00+02', 8)),
  (9, pg_temp.step('depart_visit', 3, '2026-10-22 09:10:00+02', 9)), (10, pg_temp.step('start_visit', 3, '2026-10-22 09:20:00+02', 10)),
  (11, pg_temp.step('complete_visit', 3, '2026-10-22 10:00:00+02', 11)), (12, pg_temp.step('depart_visit', 4, '2026-10-23 07:50:00+02', 12)),
  (13, pg_temp.step('start_visit', 4, '2026-10-23 08:00:00+02', 13)), (14, pg_temp.step('complete_visit', 4, '2026-10-23 08:30:00+02', 14)),
  (15, 'ok'), (16, 'ok')) s(o, r);

-- WORK1-5: what everyone else reads, before any working-day action of w1.
create temp table before_fp as
select p, pg_temp.fingerprint(p) fp from unnest(array['rn', 'ca', 'coach', 'ops', 'admin']) p;

-- WORK1-8: information before first use -------------------------------------------------------------------------------
select is(pg_temp.cmd('w1', 'select public.my_working_time_notice()') ->> 'acknowledged', 'false', 'WORK1-8: not acknowledged yet');
select is(pg_temp.seen('w1', $$ select 1 from public.my_working_day('2026-10-22') $$), 0, 'WORK1-8: no proposal before the information text');
select is(pg_temp.cmd('w1', format('select public.acknowledge_working_time_notice(%L, %L::uuid)', 'v0', pg_temp.k(100))) ->> 'result',
  'invalid', 'WORK1-8: only the current text version can be acknowledged');
select is(pg_temp.ack('w1', 101), 'ok', 'WORK1-8: she acknowledges once');
select is(pg_temp.ack('w1', 101), 'duplicate', 'same key: duplicate');
select is(pg_temp.ack('w1', 102), 'unchanged', 'a second acknowledgement records nothing');
select is((select text_version || ':' || (user_id = pg_temp.u('w1')::uuid) from public.working_time_notice_acks), 'work1-notice-v1:true',
  'WORK1-8: the acknowledgement is recorded (who, text version, when)');
select is((select count(*)::int from public.audit_events where table_name = 'working_time_notice_acks' and actor_id = pg_temp.u('w1')::uuid
           and changed -> 'text_version' ->> 'new' = 'work1-notice-v1'), 1, 'WORK1-8: audited');

-- WORK1-1: the proposal from her own events ---------------------------------------------------------------------------
select is(pg_temp.cmd('w1', $$ select to_jsonb(string_agg(visit_no || ':' || kind || ':' || to_char(starts_at at time zone 'UTC', 'HH24:MI') || '-'
                                         || coalesce(to_char(ends_at at time zone 'UTC', 'HH24:MI'), 'open'), ',' order by seq))
                               from public.my_working_day('2026-10-22') $$) #>> '{}',
  '1:travel:05:00-05:15,1:care:05:15-05:30,1:visit_pause:05:30-05:40,1:care:05:40-06:00,2:travel:06:10-06:25,2:care:06:25-07:00,3:travel:07:10-07:20,3:care:07:20-08:00',
  'WORK1-1: three visits give exactly their segments, with the stored instants');
select is(pg_temp.cmd('w1', $$ select to_jsonb(count(*)) from public.my_working_day('2026-10-21') $$)::int, 0,
  'WORK1-1: a day without her events has no segments (gaps are not filled)');
select is((select string_agg(a.attname, ',' order by a.attnum) from pg_proc p, unnest(p.proargnames, p.proargmodes) with ordinality a(attname, md, attnum)
           where p.oid = 'public.my_working_day(date)'::regprocedure and md = 't'),
  'seq,visit_no,kind,starts_at,ends_at', 'WORK1-1: no client, case, visit identifier or location in the result');
select is((select string_agg(x || '=' || pg_temp.seen(x, $$ select 1 from public.my_working_day('2026-10-22') $$), ',' order by x)
           from unnest(array['admin', 'ca', 'coach', 'ops', 'rn']) x),
  'admin=0,ca=0,coach=0,ops=0,rn=0', 'WORK1-1: a colleague, her RN, a coach, Operations and an administrator get zero rows for her date');
select is((select count(*)::int from pg_proc where proname = 'my_working_day' and pronargs = 1), 1,
  'WORK1-1: the read model takes no person argument (only the caller''s own day)');

-- WORK1-2: the day is never complete by default -----------------------------------------------------------------------
create temp table seg as select '[{"kind":"travel","start":"2026-10-22T07:00:00+02:00","end":"2026-10-22T07:15:00+02:00"},
  {"kind":"care","start":"2026-10-22T07:15:00+02:00","end":"2026-10-22T07:30:00+02:00"},
  {"kind":"visit_pause","start":"2026-10-22T07:30:00+02:00","end":"2026-10-22T07:40:00+02:00"},
  {"kind":"care","start":"2026-10-22T07:40:00+02:00","end":"2026-10-22T08:00:00+02:00"},
  {"kind":"travel","start":"2026-10-22T08:10:00+02:00","end":"2026-10-22T08:25:00+02:00"},
  {"kind":"care","start":"2026-10-22T08:25:00+02:00","end":"2026-10-22T09:00:00+02:00"},
  {"kind":"travel","start":"2026-10-22T09:10:00+02:00","end":"2026-10-22T09:20:00+02:00"},
  {"kind":"care","start":"2026-10-22T09:20:00+02:00","end":"2026-10-22T10:00:00+02:00"}]'::jsonb s;
create function pg_temp.seg() returns jsonb language sql as $$ select s from seg $$;
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.seg() || jsonb_build_object(), 200) ->> 'result', 'invalid',
  'a payload that is not an object: invalid');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:00:00+02:00', pg_temp.seg(), null, '"none"'), 201),
  '{"open": ["breaks"], "result": "questions_open"}'::jsonb, 'WORK1-2: breaks unanswered: questions_open');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:00:00+02:00', pg_temp.seg(), '[]', '"none"'), 202) -> 'open',
  '["breaks"]'::jsonb, 'WORK1-2: an empty list is not an answer');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:00:00+02:00', pg_temp.seg(), '"none"', null), 203) -> 'open',
  '["outside_work"]'::jsonb, 'WORK1-2: work outside visits unanswered: questions_open');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day(null, null, pg_temp.seg(), '"none"', '"none"'), 204) -> 'open',
  '["day_start", "day_end"]'::jsonb, 'WORK1-2: start and end of the day are hers to enter');
select is((select count(*)::int from public.working_day_versions), 0, 'WORK1-2: nothing was stored by a refused confirmation');

-- WORK1-3: confirm, correct, audited -----------------------------------------------------------------------------------
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:00:00+02:00', pg_temp.seg(),
            '[{"start":"2026-10-22T12:00:00+02:00","end":"2026-10-22T12:30:00+02:00"}]',
            '[{"kind":"administration","start":"2026-10-22T10:15:00+02:00","end":"2026-10-22T10:45:00+02:00"}]'), 210),
  '{"result": "ok", "version": 1}'::jsonb, 'WORK1-3: she confirms her day (version 1)');
select is(pg_temp.confirm('w1', '2026-10-22', '{}', 210) ->> 'result', 'duplicate', 'same key: duplicate');
select is((select paid_minutes || '/' || care_minutes || '/' || break_minutes || '/' || breaks_answer || '/' || outside_answer
           from public.working_day_versions where version = 1), '525.0/110.0/30.0/listed/listed',
  'WORK1-3: elapsed minutes from the stored instants (paid = day − breaks; care = care segments)');
select is((select bool_and((e ->> 'from_proposal')::boolean) from public.working_day_versions w, jsonb_array_elements(w.entries) e
           where w.version = 1 and e ->> 'kind' in ('travel', 'care', 'visit_pause')), true, 'the visit segments are the proposal''s');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:30:00+02:00', pg_temp.seg(), '"none"', '"none"'), 211) ->> 'field',
  'reason_code', 'WORK1-3: a second version needs a reason code');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:30:00+02:00', pg_temp.seg(),
            '[{"start":"2026-10-22T12:00:00+02:00","end":"2026-10-22T12:30:00+02:00"}]', '"none"')
          || '{"reason_code": "time_wrong", "note": "Synthetisch: Ende später"}', 212),
  '{"result": "ok", "version": 2}'::jsonb, 'WORK1-3: the correction is a new version with a reason code and a note');
select is(pg_temp.cmd('w1', $$ select jsonb_agg(version || ':' || coalesce(reason_code, '-') || ':' || coalesce(note, '-') || ':' || paid_minutes order by version)
                               from public.my_working_day_versions('2026-10-22') $$),
  '["1:-:-:525.0", "2:time_wrong:Synthetisch: Ende später:555.0"]'::jsonb, 'WORK1-3: both versions stay readable to her');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:30:00+02:00', pg_temp.seg(), '"none"', '"none"')
          || jsonb_build_object('reason_code', 'other', 'note', repeat('x', 201)), 213) ->> 'field', 'note', 'the note has at most 200 characters');
select is(pg_temp.confirm('w1', '2026-10-27', pg_temp.day('2026-10-27T07:00:00+01:00', '2026-10-27T15:00:00+01:00', '[]', '"none"', '"none"'), 214) ->> 'result',
  'future', 'WORK1-3: a day in the future is refused');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-21T22:00:00+02:00', '2026-10-22T06:00:00+02:00', '[]', '"none"', '"none"')
          || '{"reason_code": "other"}', 215) ->> 'field', 'day', 'the day starts on the confirmed date');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45:00+02:00', '2026-10-22T16:30:00+02:00',
            '[{"kind":"care","start":"2026-10-22T06:00:00+02:00","end":"2026-10-22T07:00:00+02:00"}]', '"none"', '"none"')
          || '{"reason_code": "other"}', 216) ->> 'field', 'outside_day', 'an entry outside the day is refused');
select is(pg_temp.confirm('w1', '2026-10-22', pg_temp.day('2026-10-22T06:45', '2026-10-22T16:30', '[]', '"none"', '"none"')
          || '{"reason_code": "other"}', 217) ->> 'field', 'day', 'an instant without an offset is refused (no local time is guessed)');
select is((select string_agg(changed::text, ' | ' order by id) from public.audit_events where table_name = 'working_day_versions'),
  '{"version": {"new": 1, "old": null}, "work_date": {"new": "2026-10-22", "old": null}, "reason_code": {"new": null, "old": null}} | {"version": {"new": 2, "old": null}, "work_date": {"new": "2026-10-22", "old": null}, "reason_code": {"new": "time_wrong", "old": null}}',
  'WORK1-3: audited (date, version, reason code), never the note or a time of the day');
select is((select count(*)::int from public.audit_events where table_name = 'working_day_versions' and actor_id = pg_temp.u('w1')::uuid
           and command = 'confirm_working_day'), 2, 'WORK1-3: … with actor, command and time');
select throws_ok($$ update public.working_day_versions set note = null $$, '42501', 'working_day_versions is append-only',
  'the versions are append-only, also for the owner');
-- DST1 test clock: a segment across the repeated hour of 2026-10-25 counts its real length (item 8c).
select is(pg_temp.confirm('w1', '2026-10-25', pg_temp.day('2026-10-25T02:00:00+02:00', '2026-10-25T03:30:00+01:00',
            '[{"kind":"care","start":"2026-10-25T02:30:00+02:00","end":"2026-10-25T02:30:00+01:00"}]', '"none"', '"none"'), 220) ->> 'result',
  'ok', 'a day across the clock change is confirmed');
select is((select care_minutes || '/' || paid_minutes from public.working_day_versions where work_date = '2026-10-25'), '60.0/150.0',
  'WORK1-3: 02:30 CEST to 02:30 CET is 60 minutes; the day 02:00 CEST to 03:30 CET is 150 minutes');

-- WORK1-4: export on her action ----------------------------------------------------------------------------------------
create temp table ex as select pg_temp.cmd('w1', format('select public.export_working_month(%L::date, %L::uuid)', '2026-10-01', pg_temp.k(300))) j;
select is((select j ->> 'result' || ':' || (j ->> 'month') || ':' || jsonb_array_length(j -> 'days') || ':' || (j -> 'unconfirmed')::text from ex),
  'ok:2026-10:2:["2026-10-23"]', 'WORK1-4: her confirmed days of the month; the day with events and no confirmation is listed by date');
select is((select string_agg((d ->> 'date') || ':v' || (d ->> 'version'), ',') from ex, jsonb_array_elements(j -> 'days') d),
  '2026-10-22:v2,2026-10-25:v1', 'WORK1-4: the latest version per day');
select ok((select position(pg_temp.vid(1)::text in j::text) = 0 and position('Synthetisch' in j::text) = 0
                  and position('from_proposal' in j::text) = 0 and position('00000000-0000-4000-a000-000000000208' in j::text) = 0 from ex),
  'WORK1-4: no client, case, visit identifier or note in the export');
select is((select changed::text from public.audit_events where table_name = 'working_day_exports' and actor_id = pg_temp.u('w1')::uuid),
  '{"days": 2, "month": "2026-10", "unconfirmed": 1}', 'WORK1-4: the export is audited (who, month, when, number of days)');
select is(pg_temp.cmd('w1', format('select public.export_working_month(%L::date, %L::uuid)', '2026-10-01', pg_temp.k(300))) ->> 'result',
  'duplicate', 'a repeated export key returns the file again without a second audit row');
select is((select count(*)::int from public.audit_events where table_name = 'working_day_exports'), 1, '… one audit row');

-- WORK1-5: nobody else reads her working day ---------------------------------------------------------------------------
select is((select string_agg(b.p, ',' order by b.p) from before_fp b where b.fp <> pg_temp.fingerprint(b.p)), null,
  'WORK1-5 catalogue: every readable table and read model shows a teammate, her RN, a coach, Operations and an administrator exactly what it showed before her acknowledgement, confirmations and export');
select is((select string_agg(x || '=' || pg_temp.seen(x, 'select 1 from public.working_day_versions') || '/'
                             || pg_temp.seen(x, 'select 1 from public.working_time_notice_acks'), ',' order by x)
           from unnest(array['admin', 'ca', 'coach', 'ops', 'rn']) x),
  'admin=0/0,ca=0/0,coach=0/0,ops=0/0,rn=0/0', 'WORK1-5: no other person reads her versions, notes or acknowledgement');
select is(pg_temp.seen('w1', 'select 1 from public.working_day_versions'), 3, 'she reads her own versions');
select is((select string_agg(c.relname || ':' || p.polname || ':' || p.polpermissive, ',' order by c.relname, p.polname)
           from pg_policy p join pg_class c on c.oid = p.polrelid where c.relname in ('working_day_versions', 'working_time_notice_acks')),
  'working_day_versions:leave1_access_open:false,working_day_versions:own_rows_read:true,working_time_notice_acks:leave1_access_open:false,working_time_notice_acks:own_rows_read:true',
  'WORK1-5: one permissive policy (her own rows) and the LEAVE1 restrictive policy on each table');
select is((select string_agg(pg_get_expr(p.polqual, p.polrelid), ',') from pg_policy p join pg_class c on c.oid = p.polrelid
           where c.relname in ('working_day_versions', 'working_time_notice_acks') and p.polname = 'own_rows_read'),
  '(user_id = ( SELECT auth.uid() AS uid)),(user_id = ( SELECT auth.uid() AS uid))', 'WORK1-5: … which is the caller''s own id only');
select ok(not has_table_privilege('anon', 'public.working_day_versions', 'select')
          and not has_table_privilege('authenticated', 'public.working_day_versions', 'insert')
          and not has_table_privilege('authenticated', 'public.working_day_versions', 'update'), 'no table write for app roles, no anon read');
select is((select string_agg(p.oid::regprocedure::text, ',' order by p.oid::regprocedure::text collate "C")
           from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname in ('public', 'private')
             and p.prosrc ~ '(working_day_versions|working_time_notice_acks|working_day_proposal|team_confirmed_care_share)'),
  'acknowledge_working_time_notice(text,uuid),confirm_working_day(date,jsonb,uuid),export_working_month(date,uuid),my_working_day(date),my_working_day_versions(date),my_working_time_notice(),pilot_kpis(date),private.team_confirmed_care_share(date)',
  'WORK1-5 / WORK1-7 catalogue: the working-day data is read only by her read models and commands and the WORK1-6 team aggregate (no billing, J5, export-to-payer, push or signal function)');
select ok(not has_function_privilege('authenticated', 'private.working_day_proposal(uuid, date)', 'execute')
          and not has_function_privilege('authenticated', 'private.team_confirmed_care_share(date)', 'execute'),
  'WORK1-5: the helpers that take a person or aggregate are not callable by app roles');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and (p.proname ~ '(billable|billing|invoice|payer)') and p.prosrc ~ 'working_'), null,
  'WORK1-7: no billing function reads working time');

-- WORK1-6: team North Star -------------------------------------------------------------------------------------------
create function pg_temp.wday(p_user text, p_date text, p_care_until text, k int, p_extra jsonb default '{}') returns text language sql as $$
  select pg_temp.confirm(p_user, p_date, pg_temp.day(p_date || 'T08:00:00+02:00', p_date || 'T12:00:00+02:00',
           jsonb_build_array(jsonb_build_object('kind', 'care', 'start', p_date || 'T08:30:00+02:00', 'end', p_date || p_care_until)),
           '"none"', '"none"') || p_extra, k) ->> 'result' $$;
create function pg_temp.share(p_team text) returns text language sql security definer as $$
  select coalesce((select people || '/' || days || '/' || coalesce(value::text, '-') || '/' || too_few
                   from private.team_confirmed_care_share('2026-10-01') where team_id = p_team::uuid), 'none') $$;
select is(pg_temp.wday('w2', '2026-10-20', 'T11:30:00+02:00', 400) || pg_temp.wday('w2', '2026-10-21', 'T10:30:00+02:00', 401)
          || pg_temp.wday('w3', '2026-10-20', 'T10:30:00+02:00', 402) || pg_temp.wday('w3', '2026-10-21', 'T10:30:00+02:00', 403),
  'okokokok', 'Testteam W: two people confirm four days');
select is(pg_temp.share('a0790000-0000-4000-a000-000000007990'), '2/4/56.3/true', 'WORK1-6: fewer than 3 people: hidden');
select is(pg_temp.wday('w4', '2026-10-20', 'T10:30:00+02:00', 404), 'ok', 'a third person confirms one day');
select is(pg_temp.share('a0790000-0000-4000-a000-000000007990'), '3/5/55.0/false', 'WORK1-6: 3 people and 5 days: shown');
select is(pg_temp.wday('w4', '2026-10-21', 'T09:30:00+02:00', 405) || pg_temp.wday('w4', '2026-10-21', 'T10:30:00+02:00', 406, '{"reason_code": "time_wrong"}'),
  'okok', 'a sixth day, then corrected');
select is(pg_temp.share('a0790000-0000-4000-a000-000000007990'), '3/6/54.2/false',
  'WORK1-6: 6 confirmed days: care 780 ÷ paid 1440 minutes = 54.2 %, only the latest version counts');
select is((select (k ->> 'value') || '/' || (k ->> 'base') || '/' || (k ->> 'too_few')
           from jsonb_array_elements(pg_temp.cmd('coach', $$ select jsonb_agg(to_jsonb(k)) from public.pilot_kpis('2026-10-01') k
                                                            where k.kpi = 'direct_care_share' $$)) k
           where k ->> 'team_id' = 'a0790000-0000-4000-a000-000000007990'), '54.2/6/false',
  'WORK1-6: AN1 shows the team''s share of direct care in confirmed paid time, with the number of confirmed days');
select is(pg_temp.wday('w5', '2026-10-20', 'T10:30:00+02:00', 410) || pg_temp.wday('w5', '2026-10-21', 'T10:30:00+02:00', 411)
          || pg_temp.wday('w5', '2026-10-22', 'T10:30:00+02:00', 412) || pg_temp.wday('w6', '2026-10-20', 'T10:30:00+02:00', 413)
          || pg_temp.wday('w6', '2026-10-21', 'T10:30:00+02:00', 414) || pg_temp.wday('w6', '2026-10-22', 'T10:30:00+02:00', 415),
  'okokokokokok', 'Testteam Z: two people confirm six days');
select is(pg_temp.share('a0790000-0000-4000-a000-000000007991'), '2/6/50.0/true', 'WORK1-6: a team of 2 is suppressed');
select is((select (k ->> 'value') || '/' || coalesce(k ->> 'base', '-') || '/' || (k ->> 'too_few')
           from jsonb_array_elements(pg_temp.cmd('rn', $$ select jsonb_agg(to_jsonb(k)) from public.pilot_kpis('2026-10-01') k
                                                         where k.kpi = 'direct_care_share' and k.team_id is not null $$)) k), null,
  'WORK1-6: the Nord row (one person with confirmed days) shows neither value nor base');
select is((select string_agg(nm, ',' order by nm) from pg_proc p, unnest(p.proargnames, p.proargmodes) a(nm, md)
           where p.oid = 'private.team_confirmed_care_share(date)'::regprocedure and md = 't'), 'days,people,team_id,too_few,value',
  'WORK1-6: no per-person row or column in the aggregate');

-- WORK1-9: leaver ------------------------------------------------------------------------------------------------------
create temp table kept as select count(*) n, md5(string_agg(to_jsonb(w)::text, '' order by w.id)) h from public.working_day_versions w
  where w.user_id = pg_temp.u('w1')::uuid;
select is(pg_temp.cmd('admin', format('select public.end_member_access(%L::uuid, %L, %L::uuid)', pg_temp.u('w1'), 'employment_ended', pg_temp.k(500))) ->> 'result',
  'ok', 'WORK1-9: her access ends');
select is(pg_temp.seen('w1', 'select 1 from public.working_day_versions') + pg_temp.seen('w1', 'select 1 from public.working_time_notice_acks')
          + pg_temp.seen('w1', $$ select 1 from public.my_working_day('2026-10-22') $$) + pg_temp.seen('w1', $$ select 1 from public.my_working_day_versions('2026-10-22') $$),
  0, 'WORK1-9: she reads nothing of her working days after the access end');
select throws_ok(format($$ select pg_temp.confirm('w1', '2026-10-23', pg_temp.day('2026-10-23T07:00:00+02:00', '2026-10-23T12:00:00+02:00', '[]', '"none"', '"none"'), 501) $$),
  '42501', 'access_ended', 'WORK1-9 / WORK1-3: she confirms nothing (access_ended)');
select throws_ok(format($$ select pg_temp.cmd('w1', 'select public.export_working_month(''2026-10-01''::date, ''%s''::uuid)') $$, pg_temp.k(502)),
  '42501', 'access_ended', 'WORK1-9: she exports nothing');
select is((select row(count(*), md5(string_agg(to_jsonb(w)::text, '' order by w.id)))::text from public.working_day_versions w
           where w.user_id = pg_temp.u('w1')::uuid), (select row(n, h)::text from kept), 'WORK1-9 / LEAVE1-4: her confirmed days and versions are kept unchanged');

select * from finish();
rollback;
