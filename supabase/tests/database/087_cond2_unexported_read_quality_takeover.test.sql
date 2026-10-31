-- COND2-1 (= COND1-C1) and COND2-2 (= COND1-C2): migration 0087, ADR-101, brief `docs/agents/briefs/COND2.md`.
-- COND2-1: the unexported-days count is returned only by the recorded access-end step (prepare_member_access_end) and
--   in the end_member_access result; the standing reader member_unexported_working_days is gone.
-- COND2-2: a lapsed in_review quality claim can be taken over by a team member with the open → in_review permission.
-- Users: coach …901, registered nurse …902 (org A, Testteam Nord …101), admin of org B …903, operations …904, admin
-- …905 (org A …011). Synthetic users added here: …8701 a registered nurse of Testteam Nord (the leaver and first
-- owner), …8702 a registered nurse of Testteam Mitte …102 (another team). Case …208 (Nord). All data synthetic; every
-- step goes through the real commands, except the steps marked "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;
select plan(36);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select (case when n < 1000 then '00000000-0000-4000-a000-' else 'a0870000-0000-4000-a000-' end || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a0870000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a0870000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.c(n integer) returns uuid language sql immutable as $$
  select ('a0870000-0000-4000-b000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
-- Run p_sql as user p_user through `authenticated` and return its single value as text.
create function pg_temp.as_user(p_user integer, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
-- prepare_member_access_end for p_who as p_caller: "result/count" (count '∅' when absent).
create function pg_temp.prepare(p_caller integer, p_who integer, p_key integer) returns text language sql as $$
  select pg_temp.as_user(p_caller, format(
    $q$ select (j ->> 'result') || '/' || coalesce(j ->> 'unexported_days', '∅')
        from (select public.prepare_member_access_end(%L::uuid, %L::uuid) j) x $q$, pg_temp.u(p_who), pg_temp.k(p_key)))
$$;
create function pg_temp.end_(p_who integer, p_key integer) returns jsonb language sql as $$
  select pg_temp.as_user(905, format('select public.end_member_access(%L::uuid, %L, %L::uuid)::text',
                                     pg_temp.u(p_who), 'employment_ended', pg_temp.k(p_key)))::jsonb
$$;
create function pg_temp.restore(p_who integer, p_key integer) returns text language sql as $$
  select pg_temp.as_user(905, format('select public.restore_member_access(%L::uuid, %L, %L::uuid) ->> ''result''',
                                     pg_temp.u(p_who), 'ended_in_error', pg_temp.k(p_key)))
$$;
create function pg_temp.status(p_user integer, p_event integer, p_to text, p_key integer) returns text language sql as $$
  select pg_temp.as_user(p_user, format('select public.set_quality_event_status(%L, %L, %L, %L)',
                                        pg_temp.c(p_event), p_to, 'Synthetische Abschlussnotiz', pg_temp.k(p_key)))
$$;
create function pg_temp.claim_ended(p_event integer) returns text language sql as $$
  select pg_temp.as_user(902, format('select claim_ended::text from public.field_quality(%L) where id = %L',
                                     pg_temp.today(), pg_temp.c(p_event)))
$$;
create function pg_temp.owner(p_event integer) returns text language sql as $$
  select status || ':' || right(owner_id::text, 4) from public.quality_events where id = pg_temp.c(p_event)
$$;

-- Fixtures (as the table owner) ---------------------------------------------------------------------------------------
insert into auth.users (id, email) values (pg_temp.u(8701), 'cond2-rn-nord@navora.test'), (pg_temp.u(8702), 'cond2-rn-mitte@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8701), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8702), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u(8701), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u(8702), 'registered_nurse');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        pg_temp.today(), '07:00', '07:30', false, 'planned', pg_temp.u(902));
-- Four low-severity quality events on that visit, recorded by …902.
insert into public.quality_events (id, organization_id, case_id, visit_id, team_id, event_type, severity, title, status, author_id)
select pg_temp.c(n), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', pg_temp.v(1),
       '00000000-0000-4000-a000-000000000101', 'synthetic', 'low', 'Synthetisches Ereignis ' || n, 'open', pg_temp.u(902)
from generate_series(1, 4) n;

-- COND2-1: no standing reader ----------------------------------------------------------------------------------------
select ok(to_regprocedure('public.member_unexported_working_days(uuid)') is null,
  'COND2-1: the standing per-person reader member_unexported_working_days no longer exists (an administrator gets no count)');
select ok(has_function_privilege('authenticated', 'public.prepare_member_access_end(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.prepare_member_access_end(uuid, uuid)', 'execute'),
  'COND2-1: the access-end step is a command for signed-in users only');
-- COND2-1: the recorded read in the access-end step --------------------------------------------------------------------
select is(pg_temp.prepare(905, 8701, 1), 'ok/0', 'COND2-1: the administrator opening the end step for her gets the count');
select is((select string_agg(a.changed::text, ',') from public.audit_events a
           where a.command = 'prepare_member_access_end' and a.entity_id = pg_temp.u(8701) and a.actor_id = pg_temp.u(905)),
  '{"access_end_prepared": true}', 'COND2-1: the read is recorded (who, for whom, when), never the count');
select is(pg_temp.prepare(905, 8701, 1) || '|' || (select count(*)::text from public.audit_events
                                                   where command = 'prepare_member_access_end' and entity_id = pg_temp.u(8701)),
  'duplicate/∅|1', 'COND2-1: the same key returns duplicate without a count and records nothing more');
select is(pg_temp.prepare(902, 8701, 2) || ',' || pg_temp.prepare(904, 8701, 3) || ',' || pg_temp.prepare(901, 8701, 4)
          || ',' || pg_temp.prepare(903, 8701, 5),
  'rejected/∅,rejected/∅,rejected/∅,rejected/∅',
  'COND2-1: her team''s registered nurse, Operations, a coach and another organisation''s administrator get no count');
select is(pg_temp.prepare(905, 905, 6), 'self/∅', 'COND2-1: an administrator does not prepare her own end');
select is((select count(*)::int from public.audit_events where command = 'prepare_member_access_end'), 1,
  'COND2-1: refused calls record no read');
select is(pg_temp.as_user(8701, 'select public.my_unexported_working_days()::text'), '0',
  'COND2-1: my_unexported_working_days on /work is unchanged for the nurse herself');

-- COND2-2: claims before the end ---------------------------------------------------------------------------------------
select is(pg_temp.status(8701, 1, 'in_review', 10) || ',' || pg_temp.status(8701, 2, 'in_review', 11), 'ok,ok',
  'fixture: …8701 takes events 1 and 2 in review (owner)');
select is(pg_temp.status(902, 1, 'in_review', 12), 'rejected',
  'COND2-2 (b): a live claim (owner''s access not ended) stays refused with rejected');
select is(pg_temp.owner(1), 'in_review:8701', 'COND2-2 (b): the refused take-over changes nothing');

-- The access end ------------------------------------------------------------------------------------------------------
create temp table ended as select pg_temp.end_(8701, 20) j;
select is((select (j ->> 'result') || '/' || (j ->> 'unexported_days') from ended), 'ok/0',
  'COND2-1: the end result still carries her count (0083)');
select is(pg_temp.prepare(905, 8701, 7), 'unchanged/∅', 'COND2-1: after her end the step returns no count');
select is(pg_temp.claim_ended(1) || '|' || pg_temp.claim_ended(2), 'true|true', 'fixture: both claims have lapsed (0085)');

-- COND2-2 (c): a caller without the open → in_review permission ------------------------------------------------------
select is(pg_temp.status(904, 2, 'in_review', 30) || ',' || pg_temp.status(901, 2, 'in_review', 31) || ','
          || pg_temp.status(8702, 2, 'in_review', 32) || ',' || pg_temp.status(905, 2, 'in_review', 33),
  'rejected,rejected,rejected,rejected',
  'COND2-2 (c): Operations, a coach, another team''s nurse and an administrator (low severity) are refused');
select is(pg_temp.owner(2), 'in_review:8701', 'COND2-2 (c): the refused calls change nothing');

-- COND2-2 (a): a team member takes over the lapsed claim -----------------------------------------------------------
select is(pg_temp.status(902, 1, 'in_review', 40), 'ok', 'COND2-2 (a): a team member takes over the lapsed claim');
select is(pg_temp.owner(1), 'in_review:0902', 'COND2-2 (a): she is the new owner; the event stays in review');
select is(pg_temp.claim_ended(1), 'false', 'COND2-2 (a): the team reads the claim as held again');
select is(pg_temp.status(902, 1, 'in_review', 40), 'duplicate', 'COND2-2: the same key is a duplicate');
select is(pg_temp.status(902, 1, 'in_review', 41), 'rejected', 'COND2-2: her own live claim cannot be taken again');

-- COND2-2 (d): the log holds both owners in order; nothing is rewritten -----------------------------------------------
select is((select string_agg(coalesce(from_status, '∅') || '>' || to_status || ':' || right(actor_id::text, 4), ',' order by id)
           from public.quality_event_log where event_id = pg_temp.c(1)),
  'open>in_review:8701,in_review>in_review:0902', 'COND2-2 (d): the log holds both owners in order');
select is((select access_seq from public.quality_event_log where event_id = pg_temp.c(1) and actor_id = pg_temp.u(902)),
  private.latest_access_end_seq(pg_temp.u(902)), 'COND2-2 (d): the take-over records the new owner''s access_seq (0085)');
select ok((select access_seq from public.quality_event_log where event_id = pg_temp.c(1) and actor_id = pg_temp.u(8701)) = 0,
  'COND2-2 (d): the first owner''s row stays as it was (access_seq 0)');
select is((select count(*)::int from public.quality_event_log where event_id = pg_temp.c(1) and actor_id = pg_temp.u(8701)
             and from_status = 'open' and to_status = 'in_review'), 1,
  'COND2-2 (d): the old claim''s log row stays (append-only; nothing rewritten)');
select is((select count(*)::int from public.audit_events a where a.table_name = 'quality_events' and a.entity_id = pg_temp.c(1)
             and a.command = 'set_quality_event_status' and a.actor_id = pg_temp.u(902) and a.changed ? 'owner_id'), 1,
  'COND2-2: the owner change is audited (0020 trigger)');

-- COND2-2 (e): a restore of the former owner does not give the claim back ----------------------------------------------
select is(pg_temp.restore(8701, 50), 'ok', 'fixture: the administrator restores …8701');
select is(pg_temp.owner(1) || '|' || pg_temp.claim_ended(1), 'in_review:0902|false',
  'COND2-2 (e): after the restore the claim stays with the new owner');
select is(pg_temp.status(8701, 1, 'in_review', 51), 'rejected', 'COND2-2 (e): the former owner cannot take back a live claim');
select is(pg_temp.claim_ended(2), 'true', 'LEAVE1-C5 still: her earlier claim on event 2 stays lapsed after the restore');
select is(pg_temp.status(902, 2, 'in_review', 52) || '|' || pg_temp.owner(2), 'ok|in_review:0902',
  'COND2-2 (a): the lapsed claim on event 2 is taken over after the restore as well');

-- Unchanged paths --------------------------------------------------------------------------------------------------------
select is(pg_temp.status(902, 3, 'in_review', 60), 'ok', 'QG1 unchanged: open → in_review');
select is(pg_temp.status(902, 4, 'closed', 61) || ',' || pg_temp.status(902, 4, 'in_review', 62), 'ok,rejected',
  'QG1 unchanged: a closed event is not taken back into review');
select is(pg_temp.status(902, 1, 'closed', 63), 'ok', 'QG1 unchanged: the new owner closes the event with a note');
select is(pg_temp.as_user(8702, format('select count(*)::text from public.field_quality(%L) where id = %L', pg_temp.today(), pg_temp.c(1))), '0',
  'negative: another team''s nurse still reads no event of Nord (no read widened)');

select * from finish();
rollback;
