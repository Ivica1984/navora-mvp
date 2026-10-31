-- DST1: safety alerts are on time on the nights the clock changes (migration 0067, ADR-081). Brief `docs/agents/briefs/DST1.md`.
-- Every scenario runs at a PINNED clock (private.now() honours navora.test_now; the seed enables the test clock), so
-- this file gives the same result whatever instant CI runs it. Fixtures are explicit Zurich local dates and times.
-- Users: coach …901 (org A, Operations view) · nurse …902 (responsible, Testteam Nord …101) · care assistant …906
-- (Nord) · operations …904. Case …208. Synthetic data only. Thresholds are PROVISIONAL (D-28) and are not changed here:
-- visit_overdue is raised at the planned start as P2 and becomes P1 one hour later (CR-038); a P1 not taken within
-- 15 minutes also reaches Operations (SIG1-5, CR-072).
begin;
create extension if not exists pgtap with schema extensions;

select plan(44);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.pin(p_at text) returns timestamptz language sql as $$
  select set_config('navora.test_now', p_at, true);
  select private.now();
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a6800000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
-- A planned, unstarted visit at an explicit Zurich local date and time (no end), responsible nurse …902.
create function pg_temp.visit(p_n integer, p_date date, p_time time) returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.v(p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', p_date, p_time, null, false, 'planned', '00000000-0000-4000-a000-000000000902')
$$;
-- Priority of the overdue alert as Operations (coach …901) sees it; null when not raised.
create function pg_temp.ops_overdue(n integer) returns text language plpgsql as $$
declare p text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000901');
  set local role authenticated;
  select x.priority into p from public.operations_exceptions() x where x.exception_type = 'visit_overdue' and x.entity_id = pg_temp.v(n);
  reset role;
  return p;
end $$;
-- Priority of the overdue alert as the team (nurse …902) sees it on /team.
create function pg_temp.team_overdue(n integer) returns text language plpgsql as $$
declare p text;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000902');
  set local role authenticated;
  select x.priority into p from public.team_visit_alerts() x where x.exception_type = 'visit_overdue' and x.visit_id = pg_temp.v(n);
  reset role;
  return p;
end $$;
create function pg_temp.recipients(n integer) returns text language sql as $$
  select coalesce(string_agg(right(d.recipient_id::text, 3) || '=' || d.reason, ',' order by d.recipient_id), '')
  from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
  where s.visit_id = pg_temp.v(n) and s.ended_at is null
$$;
create function pg_temp.eval() returns integer language sql as $$
  select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true)
$$;

-- The conversion rule (DST1-2, DST1-3) ------------------------------------------------------------------------------
select is(private.at_zurich(timestamp '2026-10-25 02:30'), timestamptz '2026-10-25 00:30:00+00',
  'DST1-2: 02:30 in the repeated hour → the earlier instant (CEST), 00:30 UTC');
select is(private.at_zurich(timestamp '2026-10-25 02:00'), timestamptz '2026-10-25 00:00:00+00', 'DST1-2: 02:00 → 00:00 UTC (CEST)');
select is(private.at_zurich(timestamp '2026-10-25 02:59'), timestamptz '2026-10-25 00:59:00+00', 'DST1-2: 02:59 → 00:59 UTC (CEST)');
select is(private.at_zurich(timestamp '2026-10-25 01:59'), timestamptz '2026-10-24 23:59:00+00', 'before the repeated hour: unchanged');
select is(private.at_zurich(timestamp '2026-10-25 03:00'), timestamptz '2026-10-25 02:00:00+00', 'after the repeated hour: CET, unchanged');
select is(private.at_zurich(timestamp '2027-03-28 02:30'), timestamptz '2027-03-28 01:30:00+00',
  'DST1-3: 02:30 does not exist on 2027-03-28 → read in standard time (CET), 01:30 UTC');
select is(private.at_zurich(timestamp '2027-03-28 01:59'), timestamptz '2027-03-28 00:59:00+00', 'before the gap: CET, unchanged');
select is(private.at_zurich(timestamp '2027-03-28 03:00'), timestamptz '2027-03-28 01:00:00+00', 'after the gap: CEST, unchanged');
select is(private.at_zurich(timestamp '2026-07-01 12:00'), timestamptz '2026-07-01 10:00:00+00', 'an ordinary summer day: unchanged');
select is(private.at_zurich(timestamp '2026-12-01 12:00'), timestamptz '2026-12-01 11:00:00+00', 'an ordinary winter day: unchanged');
select is(private.at_zurich(timestamptz '2026-10-25 00:30:00+00'), timestamp '2026-10-25 02:30', 'the reverse is plain wall clock');

-- The test clock --------------------------------------------------------------------------------------------------------
select is(pg_temp.pin('2026-10-25 00:40:00+00'), timestamptz '2026-10-25 00:40:00+00', 'the clock can be pinned in CI');
select ok(not has_table_privilege('authenticated', 'private.test_clock', 'select')
          and not has_table_privilege('authenticated', 'private.test_clock', 'insert')
          and not has_table_privilege('anon', 'private.test_clock', 'select'),
  'no API role reads or writes the test-clock switch');
delete from private.test_clock;
select ok(private.now() = now(), 'without the seeded switch (staging, production) the setting is ignored: private.now() is now()');
insert into private.test_clock (enabled) values (true);
select is(private.now(), timestamptz '2026-10-25 00:40:00+00', 'with the switch the pinned clock holds again');

-- Repeated hour, first pass: 2026-10-25 00:40 UTC = 02:40 CEST (CGR-52: raised by 02:40 of the first occurrence) ---------------
select pg_temp.visit(1, date '2026-10-25', time '02:30');
select pg_temp.visit(2, date '2026-10-25', time '02:50');
select pg_temp.visit(3, date '2026-10-25', time '01:30');
select is(pg_temp.ops_overdue(1), 'P2',
  'DST1-2 / CGR-52: by 02:40 CEST a visit planned at 02:30 is overdue (P2), measured from 00:30 UTC (before: not raised until 01:30 UTC)');
select is(pg_temp.team_overdue(1), 'P2', 'DST1-2: the team sees it too, same priority');
select is(pg_temp.ops_overdue(2), null, 'a visit planned at 02:50 is still ahead');
select is(pg_temp.ops_overdue(3), 'P1', '01:30 CEST (70 min ago): P1 as on any other night');

-- Repeated hour, second pass: 2026-10-25 01:35 UTC = 02:35 CET ------------------------------------------------------------
select pg_temp.pin('2026-10-25 01:35:00+00');
select is(pg_temp.ops_overdue(1), 'P1',
  'DST1-2: at 02:35 CET the 02:30 visit is 65 min overdue → P1 (P2 from 00:30 UTC, P1 one hour later; before: P2 only)');
select is(pg_temp.team_overdue(1), 'P1', 'DST1-2: the team sees P1');
select is(pg_temp.ops_overdue(2), 'P2', 'the 02:50 visit (00:50 UTC) is overdue, P2');
select ok(pg_temp.eval() >= 1, 'SIG1: the evaluation writes rows');
select is((select p1_at from public.safety_signals where visit_id = pg_temp.v(1) and ended_at is null), timestamptz '2026-10-25 01:30:00+00',
  'DST1-2 / SIG1-9: the P1 time is 00:30 UTC + 1 h = 01:30 UTC');
select is((select signal_kind from public.safety_signals where visit_id = pg_temp.v(1) and ended_at is null), 'visit_overdue', 'kind visit_overdue');
select is(pg_temp.recipients(1), '902=responsible,906=team',
  'DST1-2 / SIG1-1: the P1 reaches the responsible member and the team, as on any other night');
select is((select count(*)::int from public.safety_signals where visit_id = pg_temp.v(2)), 0, 'the P2 visit stays pull-only');
-- Not taken for 15 minutes → Operations (SIG1-5).
select pg_temp.pin('2026-10-25 01:51:00+00');
select pg_temp.eval();
select is(pg_temp.recipients(1), '902=responsible,904=untaken,906=team',
  'DST1-2 / SIG1-5: untaken 15 min after the signal (01:51 UTC) → Operations as well, as on any other night');
select is((select count(*)::int from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
           where s.visit_id = pg_temp.v(1) and d.reason = 'untaken'), 1, 'once');

-- Missing hour: 2027-03-28 (02:00-02:59 does not exist) ------------------------------------------------------------------
select pg_temp.pin('2027-03-28 01:20:00+00');   -- 03:20 CEST
select pg_temp.visit(11, date '2027-03-28', time '02:30');
select pg_temp.visit(12, date '2027-03-28', time '03:10');
select is(pg_temp.ops_overdue(11), null,
  'DST1-3: a visit at the non-existent 02:30 is read as 01:30 UTC (CET): at 01:20 UTC it is still ahead');
select is(pg_temp.ops_overdue(12), 'P2', 'a visit at 03:10 CEST (01:10 UTC) is overdue, P2');
select pg_temp.pin('2027-03-28 01:40:00+00');   -- 03:40 CEST
select is(pg_temp.ops_overdue(11), 'P2', 'DST1-3: at 01:40 UTC the non-existent 02:30 is overdue, P2: not later than the CET reading');
select is(pg_temp.team_overdue(11), 'P2', 'DST1-3: the team sees it too');
select pg_temp.pin('2027-03-28 02:31:00+00');
select is(pg_temp.ops_overdue(11), 'P1', 'DST1-3: one hour after the CET reading it is P1');

-- An ordinary daytime instant: 2026-11-10 10:00 UTC = 11:00 CET ----------------------------------------------------------
select pg_temp.pin('2026-11-10 10:00:00+00');
select pg_temp.visit(21, date '2026-11-10', time '10:45');
select pg_temp.visit(22, date '2026-11-10', time '09:30');
select pg_temp.visit(23, date '2026-11-10', time '11:30');
select is(pg_temp.ops_overdue(21), 'P2', 'ordinary day: 15 min after the planned start, P2');
select is(pg_temp.ops_overdue(22), 'P1', 'ordinary day: 90 min after, P1');
select is(pg_temp.ops_overdue(23), null, 'ordinary day: still ahead');

-- CGR-52 (4): a SIG2 watched-hours window is never shorter than its wall-clock length --------------------------------
select is(private.at_zurich_end(timestamp '2026-10-25 02:30'), timestamptz '2026-10-25 01:30:00+00',
  'CGR-52 (4): a window END at 02:30 in the repeated hour → the later instant (CET), 01:30 UTC');
insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
values ('00000000-0000-4000-b000-000000000011', 7, time '00:00', time '02:30');   -- Sunday 2026-10-25, 00:00-02:30 local
select ok(private.watched_inside('00000000-0000-4000-b000-000000000011', timestamptz '2026-10-25 01:15:00+00'),
  'CGR-52 (4): the window 00:00-02:30 still covers 01:15 UTC (02:15 CET, second pass)');
select ok(not private.watched_inside('00000000-0000-4000-b000-000000000011', timestamptz '2026-10-25 01:35:00+00'),
  'and ends at 02:30 CET (01:35 UTC is outside)');
select is(private.watched_raise_at('00000000-0000-4000-b000-000000000011', timestamptz '2026-10-25 05:00:00+00'),
  timestamptz '2026-10-24 23:30:00+00',
  'CGR-52 (4) / SIG2-13: the look-ahead raise lies 2 h before the window end read as 01:30 UTC, inside the window');
delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';

-- Guards: no later migration brings the native forms back ---------------------------------------------------------------
select is((select count(*)::int
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private')
             and p.oid not in ('private.at_zurich(timestamp)'::regprocedure, 'private.at_zurich(timestamptz)'::regprocedure,
                               'private.at_zurich_end(timestamp)'::regprocedure, 'private.now()'::regprocedure)
             and p.prosrc ~* 'at\s+time\s+zone\s+\\?''{1,2}Europe/Zurich'
             and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')),
  0, 'ADR-081: no function body converts with a native AT TIME ZONE ''Europe/Zurich'' (use private.at_zurich)');
select is((select count(*)::int
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private')
             and p.oid <> 'private.now()'::regprocedure
             and p.prosrc ~ '(^|[^.\w])now\(\)'
             and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')),
  0, 'ADR-081: no function body reads now() directly (use private.now())');
select is((select count(*)::int from pg_attrdef d join pg_class c on c.oid = d.adrelid join pg_namespace n on n.oid = c.relnamespace
           where n.nspname in ('public', 'private') and pg_get_expr(d.adbin, d.adrelid) ~ '(^|[^.\w])now\(\)'),
  0, 'ADR-081: no column default reads now() directly');

select * from finish();
rollback;
