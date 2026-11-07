-- DST1 follow-up: DST1-C1 (CGR-53), DST1-C2 (DST1-7), DST1-C3 (b) (DST1-8 (b)). Migration 0069, ADR-081 addendum.
-- Brief `docs/agents/briefs/DST1.md`. Every scenario runs at a PINNED clock (private.now() honours navora.test_now; the
-- seed enables the test clock). Fixtures are explicit Zurich local dates and times; synthetic data only.
-- Users: coach …901 (org A) · nurse …902 (responsible, member of Testteam Nord …101) · operations …904. Case …208.
-- Thresholds stay PROVISIONAL (D-28); ABS1 rules are not changed here, only the instants their intervals end at.
-- DST1-8 (a) is proved by the CI step "Real clock before the seed" in .github/workflows/ci.yml (it must run before the
-- seed writes the test-clock row, so it cannot live in a pgTAP file, which runs after the seed).
begin;
create extension if not exists pgtap with schema extensions;

select plan(31);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.pin(p_at text) returns timestamptz language sql as $$
  select set_config('navora.test_now', p_at, true);
  select private.now();
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a7000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
-- A planned visit at explicit Zurich local date and times, responsible nurse …902, Testteam Nord.
create function pg_temp.visit(p_n integer, p_date date, p_from time, p_until time) returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.v(p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', p_date, p_from, p_until, false, 'planned', '00000000-0000-4000-a000-000000000902')
$$;
create function pg_temp.iv(n integer) returns tstzrange language sql as $$
  select private.visit_interval(v) from public.care_visits v where v.id = pg_temp.v(n)
$$;
-- An absence of nurse …902 in Testteam Nord between two instants (the ABS1 store, as record_absence writes it).
create function pg_temp.absent(p_from timestamptz, p_until timestamptz) returns void language sql as $$
  insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
  values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101',
          '00000000-0000-4000-a000-000000000902', p_from, p_until, '00000000-0000-4000-a000-000000000902')
$$;
-- ABS1 release rule for nurse …902 between two instants; true when the given visit is released.
create function pg_temp.releases(n integer, p_from timestamptz, p_until timestamptz) returns boolean language sql as $$
  select exists (select 1 from private.release_visits_between('00000000-0000-4000-a000-000000000101',
                   '00000000-0000-4000-a000-000000000902', p_from, p_until, 'Abwesenheit', '00000000-0000-4000-a000-000000000902', false) r
                 where r = pg_temp.v(n))
$$;

select pg_temp.pin('2026-10-24 10:00:00+00');   -- the day before the autumn night

-- DST1-C1: a visit interval is never shorter than its wall-clock length ---------------------------------------------
select pg_temp.visit(1, date '2026-10-25', time '01:30', time '02:30');   -- fall-back night
select pg_temp.visit(2, date '2026-11-10', time '01:30', time '02:30');   -- an ordinary night (CET)
select pg_temp.visit(3, date '2026-10-25', time '02:10', time '02:40');   -- both ends in the repeated hour
select pg_temp.visit(4, date '2027-03-28', time '02:30', time '03:10');   -- starts in the spring gap
select pg_temp.visit(5, date '2027-03-28', time '01:30', time '02:30');   -- ends in the spring gap
select pg_temp.visit(7, date '2026-10-25', time '02:30', time '03:30');   -- starts in the repeated hour
select is(pg_temp.iv(1), tstzrange('2026-10-24 23:30:00+00', '2026-10-25 01:30:00+00', '[)'),
  'DST1-C1 / CGR-53: a visit 01:30-02:30 on 2026-10-25 occupies 23:30-01:30 UTC (end: the later instant)');
select is(pg_temp.iv(2), tstzrange('2026-11-10 00:30:00+00', '2026-11-10 01:30:00+00', '[)'), 'an ordinary night: unchanged');
select is(pg_temp.iv(3), tstzrange('2026-10-25 00:10:00+00', '2026-10-25 01:40:00+00', '[)'),
  'DST1-C1: both ends in the repeated hour: start the earlier, end the later instant');
select is(pg_temp.iv(4), tstzrange('2027-03-28 00:30:00+00', '2027-03-28 02:10:00+00', '[)'),
  'DST1-C1: a visit 02:30-03:10 on 2027-03-28 no longer fails; it covers both readings (end - 40 min to start + 40 min)');
select is(pg_temp.iv(5), tstzrange('2027-03-28 00:30:00+00', '2027-03-28 01:30:00+00', '[)'),
  'DST1-3: an end in the spring gap is read in standard time (01:30 UTC)');
select is(pg_temp.iv(7), tstzrange('2026-10-25 00:30:00+00', '2026-10-25 02:30:00+00', '[)'),
  'CGR-53: a visit 02:30-03:30 on 2026-10-25 keeps its earlier start (00:30 UTC)');

-- ABS1 on the fall-back night acts exactly as on an ordinary night: an absence from 30 min before the visit end -------------
-- Ordinary night: the visit ends 02:30 CET = 01:30 UTC; the absence starts 02:00 CET = 01:00 UTC.
-- Fall-back night: the visit ends 02:30 CET (second pass) = 01:30 UTC; the absence starts 01:00 UTC (02:00 CET).
select pg_temp.absent('2026-10-25 01:00:00+00', '2026-10-25 05:00:00+00');
select pg_temp.absent('2026-11-10 01:00:00+00', '2026-11-10 05:00:00+00');
select ok(private.visit_responsible_absent(pg_temp.v(2)), 'ordinary night: the visit is flagged responsible_absent');
select ok(private.visit_responsible_absent(pg_temp.v(1)),
  'DST1-C1 / CGR-53: fall-back night: flagged responsible_absent as well (after 0067, before this fix: not flagged)');
delete from public.member_absences where user_id = '00000000-0000-4000-a000-000000000902'
  and starts_at in ('2026-10-25 01:00:00+00', '2026-11-10 01:00:00+00');
select ok(pg_temp.releases(2, '2026-11-10 01:00:00+00', '2026-11-10 05:00:00+00'), 'ordinary night: ABS1 releases the visit');
select ok(pg_temp.releases(1, '2026-10-25 01:00:00+00', '2026-10-25 05:00:00+00'),
  'DST1-C1 / CGR-53: fall-back night: ABS1 releases the visit too');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(1)), null, 'released: no responsible member');
select is((select count(*)::int from public.visit_plan_changes where visit_id = pg_temp.v(1) and change = 'released'), 1,
  'the release is audited once (visit_plan_changes)');
-- Before the visit end nothing changes: an absence from the visit end does not overlap it, on either night.
update public.care_visits set responsible_user_id = '00000000-0000-4000-a000-000000000902' where id in (pg_temp.v(1), pg_temp.v(2));
select ok(not pg_temp.releases(2, '2026-11-10 01:30:00+00', '2026-11-10 05:00:00+00'), 'ordinary night: an absence from the end does not release');
select ok(not pg_temp.releases(1, '2026-10-25 01:30:00+00', '2026-10-25 05:00:00+00'), 'fall-back night: an absence from the end does not release');

-- The commands: the absence END typed in the repeated hour takes the later instant; the start stays the earlier ------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((public.record_absence('00000000-0000-4000-a000-000000000101', null, date '2026-10-25', date '2026-10-25',
          time '00:00', time '02:30', 'a7000000-0000-4000-9000-000000000001') ->> 'result'), 'ok',
  'record_absence 00:00-02:30 on 2026-10-25 succeeds');
reset role;
select is((select ends_at from public.member_absences where user_id = '00000000-0000-4000-a000-000000000902'
           and starts_at = '2026-10-24 22:00:00+00' and withdrawn_at is null), timestamptz '2026-10-25 01:30:00+00',
  'DST1-C1: record_absence: an end at 02:30 in the repeated hour → the later instant, 01:30 UTC');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(1)), null,
  'DST1-C1: and it releases the 01:30-02:30 visit of that night');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((public.change_absence((select id from public.member_absences where user_id = '00000000-0000-4000-a000-000000000902'
           and starts_at = '2026-10-24 22:00:00+00'), false, date '2026-10-25', time '02:15',
          'a7000000-0000-4000-9000-000000000002') ->> 'result'), 'ok', 'change_absence to 02:15 succeeds (shorter)');
reset role;
select is((select ends_at from public.member_absences where user_id = '00000000-0000-4000-a000-000000000902'
           and starts_at = '2026-10-24 22:00:00+00' and withdrawn_at is null), timestamptz '2026-10-25 01:15:00+00',
  'DST1-C1: change_absence: a new end at 02:15 in the repeated hour → the later instant, 01:15 UTC');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((public.record_absence('00000000-0000-4000-a000-000000000101', null, date '2026-11-12', date '2026-11-12',
          time '08:00', time '12:00', 'a7000000-0000-4000-9000-000000000003') ->> 'result'), 'ok', 'an ordinary day: record_absence');
reset role;
select is((select tstzrange(starts_at, ends_at, '[)') from public.member_absences where user_id = '00000000-0000-4000-a000-000000000902'
           and starts_at = '2026-11-12 07:00:00+00'), tstzrange('2026-11-12 07:00:00+00', '2026-11-12 11:00:00+00', '[)'),
  'an ordinary day: 08:00-12:00 CET = 07:00-11:00 UTC, unchanged');

-- The CSR1 stuck reference keeps the earlier end (accepted deviation): a started visit is stuck from the earlier instant
select pg_temp.visit(6, date '2026-10-25', time '01:30', time '02:30');
update public.care_visits set status = 'started' where id = pg_temp.v(6);
select pg_temp.pin('2026-10-25 06:00:00+00');
select is((select since from private.derived_exceptions('00000000-0000-4000-b000-000000000011')
           where exception_type = 'visit_stuck' and entity_id = pg_temp.v(6)), timestamptz '2026-10-25 00:30:00+00',
  'DST1 deviation (c), accepted: the stuck reference of a started 01:30-02:30 visit is the earlier end, 00:30 UTC');

-- DST1-C2 (DST1-7): watched-hours windows are never shorter than their wall-clock length ---------------------------------
insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
values ('00000000-0000-4000-b000-000000000011', 7, time '02:30', time '06:00');   -- Sunday 2026-10-25, 02:30-06:00 local
select ok(private.watched_inside('00000000-0000-4000-b000-000000000011', timestamptz '2026-10-25 00:45:00+00'),
  'DST1-7: the window 02:30-06:00 on 2026-10-25 covers 00:45 UTC (02:45, first pass)');
select ok(not private.watched_inside('00000000-0000-4000-b000-000000000011', timestamptz '2026-10-25 00:25:00+00'),
  'and starts at the earlier 02:30 (00:25 UTC is outside)');
delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';
insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
values ('00000000-0000-4000-b000-000000000011', 7, time '00:00', time '02:30');   -- Sunday 2027-03-28, end in the gap
select ok(private.watched_inside('00000000-0000-4000-b000-000000000011', timestamptz '2027-03-28 01:15:00+00'),
  'DST1-7 / DST1-3: the window 00:00-02:30 on 2027-03-28 ends at the CET reading 01:30 UTC: 01:15 UTC is inside '
  '(0067: outside from 01:00 UTC)');
select ok(not private.watched_inside('00000000-0000-4000-b000-000000000011', timestamptz '2027-03-28 01:35:00+00'),
  'and 01:35 UTC is outside');
select is(private.watched_raise_at('00000000-0000-4000-b000-000000000011', timestamptz '2027-03-28 04:00:00+00'),
  timestamptz '2027-03-27 23:30:00+00',
  'SIG2-13: after that window the look-ahead raise is 2 h before its end read as 01:30 UTC (not a week earlier)');
delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';

-- DST1-C3 (b) (DST1-8 (b)): no app role can set, read or change the pin ---------------------------------------------------
select is((select count(*)::int
           from (values ('anon'), ('authenticated'), ('service_role')) r(role)
           cross join (values ('select'), ('insert'), ('update'), ('delete'), ('truncate'), ('references'), ('trigger')) p(priv)
           where has_table_privilege(r.role, 'private.test_clock', p.priv)),
  0, 'DST1-8 (b): anon, authenticated and service_role hold no privilege of any kind on private.test_clock');
select is((select count(*)::int
           from (values ('anon'), ('authenticated'), ('service_role')) r(role)
           cross join pg_attribute a
           where a.attrelid = 'private.test_clock'::regclass and a.attnum > 0 and not a.attisdropped
             and has_column_privilege(r.role, 'private.test_clock', a.attname, 'select,insert,update,references')),
  0, 'DST1-8 (b): and no column privilege');
select is((select coalesce(string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text), '')
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname not in ('pg_catalog', 'information_schema')
             and p.prosrc ~* 'test_clock'
             and p.oid <> 'private.now()'::regprocedure
             and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')
                  or has_function_privilege('service_role', p.oid, 'execute'))),
  '', 'DST1-8 (b): no function executable by anon, authenticated or service_role names test_clock, except private.now()');
select is((select p.provolatile::text || ':' || l.lanname::text from pg_proc p join pg_language l on l.oid = p.prolang where p.oid = 'private.now()'::regprocedure), 's:sql',
  'DST1-8 (b): private.now() is a STABLE SQL function (it cannot write the test-clock table)');

select * from finish();
rollback;
