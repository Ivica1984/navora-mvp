-- COND1-8 = LEAVE1-C5 (migration 0085, ADR-098; brief `docs/agents/briefs/COND1.md`, PO 14:30, CGR-67): an OPS1
-- exception take and an `in_review` quality claim count only if recorded after the person's latest access end; a restore
-- does not bring her name back; a take or claim recorded after the restore counts. (COND1-5b is pgTAP 083.)
-- Users: registered nurse …902 (org A, Testteam Nord …101) · operations …904 · admin …905 (org A …011). Synthetic users
-- added here: …8501 a second operations user (the OPS1 take), …8502 a registered nurse of Testteam Nord (the quality
-- claim). Case …208 (Nord). All data synthetic; every step goes through the real commands, except the steps marked
-- "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(25);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select (case when n < 1000 then '00000000-0000-4000-a000-' else 'a0850000-0000-4000-a000-' end || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a0850000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a0850000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.c(n integer) returns uuid language sql immutable as $$
  select ('a0850000-0000-4000-b000-' || lpad(n::text, 12, '0'))::uuid
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
create function pg_temp.end_(p_who integer, p_key integer) returns text language sql as $$
  select pg_temp.as_user(905, format('select public.end_member_access(%L::uuid, %L, %L::uuid) ->> ''result''',
                                     pg_temp.u(p_who), 'access_withdrawn', pg_temp.k(p_key)))
$$;
create function pg_temp.restore(p_who integer, p_key integer) returns text language sql as $$
  select pg_temp.as_user(905, format('select public.restore_member_access(%L::uuid, %L, %L::uuid) ->> ''result''',
                                     pg_temp.u(p_who), 'ended_in_error', pg_temp.k(p_key)))
$$;
-- Operations' reading of the exception: taken | taken_by_me | owner name | taken at | flags.
create function pg_temp.ops_row(p_key text) returns text language sql as $$
  select pg_temp.as_user(904, format($q$ select taken::text || '|' || taken_by_me::text || '|' || coalesce(owner_name, '∅') || '|'
                                           || case when taken_at is null then '∅' else 'at' end || '|' || array_to_string(flags, ',')
                                        from public.operations_exceptions() where exception_key = %L $q$, p_key))
$$;
create function pg_temp.claim_ended(p_event integer) returns text language sql as $$
  select pg_temp.as_user(902, format('select claim_ended::text from public.field_quality(%L) where id = %L',
                                     pg_temp.today(), pg_temp.c(p_event)))
$$;

-- Fixtures (as the table owner) ---------------------------------------------------------------------------------------
insert into auth.users (id, email) values (pg_temp.u(8501), 'cond1-8-ops@navora.test'), (pg_temp.u(8502), 'cond1-8-rn@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8501), 'operations'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8502), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u(8502), 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8501), 'Synthetisch Disponentin Fuenf'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8502), 'Synthetisch Pflegende Fuenf')
on conflict (organization_id, user_id) do update set display_name = excluded.display_name;
-- An overdue visit of Testteam Nord (07:00 today, not started): its OPS1 exception.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        pg_temp.today(), '07:00', '07:30', false, 'planned', pg_temp.u(902));
create temp table ex as
  select pg_temp.as_user(904, format('select exception_key from public.operations_exceptions() where exception_type = %L and entity_id = %L',
                                     'visit_overdue', pg_temp.v(1))) as key;
-- Three quality events on that visit, recorded by …902 (as the table owner).
insert into public.quality_events (id, organization_id, case_id, visit_id, team_id, event_type, severity, title, status, author_id)
select pg_temp.c(n), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', pg_temp.v(1),
       '00000000-0000-4000-a000-000000000101', 'synthetic', 'low', 'Synthetisches Ereignis ' || n, 'open', pg_temp.u(902)
from generate_series(1, 2) n;

-- Before the end -----------------------------------------------------------------------------------------------------
select ok((select key from ex) is not null, 'fixture: the overdue visit is an OPS1 exception');
select is(pg_temp.as_user(8501, format('select public.handle_exception(%L, %L, null, %L)', (select key from ex), 'take', pg_temp.k(1))),
  'ok', 'fixture: the operations user …8501 takes it');
select is((select access_seq from public.exception_events where actor_id = pg_temp.u(8501) and kind = 'take'), 0::bigint,
  'LEAVE1-C5: the take records her latest access-end sequence (0 = none)');
select is(pg_temp.ops_row((select key from ex)), 'true|false|Synthetisch Disponentin Fuenf|at|',
  'before the end: Operations reads her take with her name and time');
select is(pg_temp.as_user(8502, format('select public.set_quality_event_status(%L, %L, %L, %L)', pg_temp.c(1), 'in_review', '', pg_temp.k(2))),
  'ok', 'fixture: the nurse …8502 sets event 1 in review (owner)');
select is((select access_seq from public.quality_event_log where event_id = pg_temp.c(1) and to_status = 'in_review'), 0::bigint,
  'LEAVE1-C5: the in_review transition records her latest access-end sequence (0 = none)');
select is(pg_temp.claim_ended(1), 'false', 'before the end: the claim is held by a person with access');

-- Both accesses end, then both are restored --------------------------------------------------------------------------
select is(pg_temp.end_(8501, 10) || '|' || pg_temp.end_(8502, 11), 'ok|ok', 'fixture: the administrator ends both accesses');
select is(pg_temp.ops_row((select key from ex)), 'false|false|∅|∅|take_access_ended', 'LEAVE1-C4 still: while ended, the take reads as untaken');
select is(pg_temp.claim_ended(1), 'true', 'LEAVE1-C4 still: while ended, the claim reads as ended');
select is(pg_temp.restore(8501, 12) || '|' || pg_temp.restore(8502, 13), 'ok|ok', 'fixture: the administrator restores both accesses');

select is(pg_temp.ops_row((select key from ex)), 'false|false|∅|∅|take_access_ended',
  'LEAVE1-C5: after the restore Operations still reads her earlier take as untaken, without name or time, flagged');
select is(pg_temp.as_user(902, format($q$ select taken::text || '|' || array_to_string(flags, ',')
                                          from public.team_visit_alerts() where exception_key = %L $q$, (select key from ex))),
  'false|take_access_ended', 'LEAVE1-C5: the team reads it as untaken too');
select is(pg_temp.as_user(904, format('select count(*)::text from public.operations_exceptions() x where exception_key = %L and to_jsonb(x)::text like %L',
                                      (select key from ex), '%Fuenf%')), '0', 'LEAVE1-C5: no Operations row carries her name');
select is(pg_temp.claim_ended(1), 'true', 'LEAVE1-C5: after the restore the team still reads her earlier claim as ended');
select is(pg_temp.as_user(902, format('select count(*)::text from public.field_quality(%L) q where to_jsonb(q)::text like %L',
                                      pg_temp.today(), '%Pflegende Fuenf%')), '0', 'LEAVE1-C5: no team quality row carries her name');
select is((select count(*)::int from public.exception_events where exception_key = (select key from ex) and kind = 'take')::text
          || '|' || (select status || ':' || right(owner_id::text, 4) from public.quality_events where id = pg_temp.c(1)),
  '1|in_review:8502', 'LEAVE1-C5: nothing is rewritten (her take stays in the log; status and owner stay)');

-- A take or claim recorded after the restore counts ------------------------------------------------------------------
select is(pg_temp.as_user(8501, format('select public.handle_exception(%L, %L, null, %L)', (select key from ex), 'take', pg_temp.k(3))),
  'ok', 'LEAVE1-C5: she takes the exception again after the restore (a new row)');
select is((select max(access_seq) from public.exception_events where actor_id = pg_temp.u(8501) and kind = 'take'),
  private.latest_access_end_seq(pg_temp.u(8501)), 'LEAVE1-C5: the new take records her latest access-end sequence');
select ok(private.latest_access_end_seq(pg_temp.u(8501)) > 0, 'fixture: that sequence is her access end (not 0)');
select is(pg_temp.ops_row((select key from ex)), 'true|false|Synthetisch Disponentin Fuenf|at|',
  'LEAVE1-C5: the take after the restore counts: Operations reads it with her name, without the flag');
select is(pg_temp.as_user(8502, format('select public.set_quality_event_status(%L, %L, %L, %L)', pg_temp.c(2), 'in_review', '', pg_temp.k(4))),
  'ok', 'LEAVE1-C5: she claims event 2 after the restore');
select is(pg_temp.claim_ended(2) || '|' || pg_temp.claim_ended(1), 'false|true',
  'LEAVE1-C5: the claim after the restore counts; the earlier claim stays ended');

-- A claim without a recorded in_review transition (as the table owner): no time to compare, read as ended -------------
insert into public.quality_events (id, organization_id, case_id, visit_id, team_id, event_type, severity, title, status, author_id, owner_id)
values (pg_temp.c(3), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', pg_temp.v(1),
        '00000000-0000-4000-a000-000000000101', 'synthetic', 'low', 'Synthetisches Ereignis 3', 'in_review', pg_temp.u(902), pg_temp.u(8502));
select is(pg_temp.claim_ended(3), 'true',
  'LEAVE1-C5: a claim with no recorded transition, whose owner has an access end, reads as ended (safe side)');
select is(private.quality_claim_lapsed(pg_temp.c(3), pg_temp.u(902))::text, 'false',
  'LEAVE1-C5: the same claim held by a person who never had an access end counts');

select * from finish();
rollback;
