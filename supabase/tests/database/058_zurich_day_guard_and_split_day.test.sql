-- DAY-1-R1 and DAY-1-R2 (PO 2026-10-24 01:15 in docs/agents/briefs/AN2.md; ADR-068 addendum). Synthetic data only.
--
-- R1: the guard of pgTAP 056 (`current_date` in function bodies) is widened. No function in `public` or `private`
--     (extension functions excluded) and no view or materialised view in those schemas derives a day from the
--     session time zone: `now()::date`, `current_timestamp::date`, `transaction_timestamp()`/`statement_timestamp()`/
--     `clock_timestamp()` cast to date, `localtimestamp`, `localtime`, `cast(now() as date)`, `date(now())`,
--     `date_trunc('day', now())`; views also not `current_date`. The day is (now() at time zone 'Europe/Zurich')::date.
--     The patterns are tested against samples first, so the guard cannot pass by matching nothing.
-- R2: behavioural proof at a split day, repeatable at any hour. Test clock method (ADR-068 addendum): the session
--     time zone is set, for this transaction only, to a zone whose calendar date differs from the Zurich date at the
--     moment the test runs (Pacific/Pago_Pago, UTC-11, before 12:00 Zurich time; Pacific/Kiritimati, UTC+14, from
--     12:00). `current_date`, `now()::date` and `localtimestamp` then give a different day than Zurich, exactly as
--     UTC does between 00:00 and 02:00 Zurich time. Each check uses a pair of values that gives the Zurich answer
--     only when the Zurich day is used: the session day one day earlier and one day later both give another answer.
--     Thresholds and priorities are read from `exception_rules`, unchanged (D-28).
begin;
create extension if not exists pgtap with schema extensions;

select plan(15);

-- DST1 / ADR-081: the CI db job pins the database clock (navora.test_now) for the suite; this file keeps its own clock
-- method (a session time zone chosen by the real hour), so the database clock is the real one for this transaction.
select set_config('navora.test_now', now()::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.today() returns date language sql as $$ select (now() at time zone 'Europe/Zurich')::date $$;

-- R1: the guard --------------------------------------------------------------------------------------------------------
create temp table day_pattern (name text primary key, re text not null);
insert into day_pattern values
  ('now_cast',        '\m(now|transaction_timestamp|statement_timestamp|clock_timestamp)\s*\(\s*\)\s*\)?\s*::\s*date\M'),
  ('ts_cast',         '\mcurrent_timestamp\s*\)?\s*::\s*date\M'),
  ('localtimestamp',  '\mlocaltime(stamp)?\M'),
  ('cast_as_date',    'cast\s*\(\s*(now\s*\(\s*\)|current_timestamp|transaction_timestamp\s*\(\s*\)|statement_timestamp\s*\(\s*\)|clock_timestamp\s*\(\s*\))\s+as\s+date\s*\)'),
  ('date_fn',         '\mdate\s*\(\s*(now\s*\(|current_timestamp|localtimestamp)'),
  ('date_trunc_day',  'date_trunc\s*\(\s*''day''\s*,\s*(now\s*\(|current_timestamp)');

select ok((select bool_and(s.bad ~* any (select re from day_pattern))
           from (values ('x := now()::date;'), ('where d < (now())::date'), ('current_timestamp::date'),
                        ('select localtimestamp'), ('cast(now() as date)'), ('date(now())'),
                        ('date_trunc(''day'', now())'), ('clock_timestamp() :: date')) s(bad)),
  'R1 self-test: every listed way to take the session day is matched by a guard pattern');
select ok((select not bool_or(s.good ~* any (select re from day_pattern))
           from (values ('(now() at time zone ''Europe/Zurich'')::date'), ('now() - interval ''1 day'''),
                        ('p_month::date'), ('(f ->> ''requested_start'')::date'), ('current_timestamp')) s(good)),
  'R1 self-test: the Zurich day and ordinary casts are not matched');

select is(
  (select string_agg(p.oid::regprocedure::text || ' [' || d.name || ']', ', ' order by 1)
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   join day_pattern d on p.prosrc ~* d.re
   where n.nspname in ('public', 'private')
     and not exists (select 1 from pg_depend x where x.classid = 'pg_proc'::regclass and x.objid = p.oid and x.deptype = 'e')),
  null,
  'R1: no function in public or private derives a day from the session time zone (only the Zurich day)');

select is(
  (select string_agg(c.oid::regclass::text, ', ' order by 1)
   from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname in ('public', 'private') and c.relkind in ('v', 'm')
     and not exists (select 1 from pg_depend x where x.classid = 'pg_class'::regclass and x.objid = c.oid and x.deptype = 'e')
     and (pg_get_viewdef(c.oid) ~* '\mcurrent_date\M'
          or exists (select 1 from day_pattern d where pg_get_viewdef(c.oid) ~* d.re))),
  null,
  'R1: no view or materialised view in public or private uses current_date or another session-day expression');

-- R2: the test clock ----------------------------------------------------------------------------------------------------
do $$
begin
  if extract(hour from now() at time zone 'Europe/Zurich') < 12 then
    perform set_config('timezone', 'Pacific/Pago_Pago', true);
  else
    perform set_config('timezone', 'Pacific/Kiritimati', true);
  end if;
end;
$$;
select isnt(current_date, pg_temp.today(),
  'R2 precondition: the session day (current_date) differs from the Zurich day for this transaction');
select ok(abs(current_date - pg_temp.today()) = 1, 'R2 precondition: by exactly one day');
select isnt((now())::date, pg_temp.today(), 'R2 precondition: now()::date follows the session day too');

-- Fixtures (as owner): two running cases of organisation A with a team, no care-plan items of their own.
create temp table rules as
  select (select coalesce(amount, 0)::int from public.exception_rules where exception_type = 'order_expiring') as order_days;
update public.cases set medical_order_status = 'present',
       medical_order_valid_until = pg_temp.today() + (select order_days from rules)       -- inside the threshold
  where id = '00000000-0000-4000-a000-000000000208';
update public.cases set medical_order_status = 'present',
       medical_order_valid_until = pg_temp.today() + (select order_days from rules) + 1   -- one day outside
  where id = '00000000-0000-4000-a000-000000000209';
insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        'DAY-1 Testleistung', 'A', 20, 'täglich', pg_temp.today() - 1, '00000000-0000-4000-a000-000000000902'),   -- due yesterday
       ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104',
        'DAY-1 Testleistung', 'A', 20, 'täglich', pg_temp.today(), '00000000-0000-4000-a000-000000000902');      -- due today

create function pg_temp.cases_with(t text) returns text language sql as $$
  select string_agg(right(e.case_id::text, 3), ',' order by e.case_id)
  from private.derived_exceptions('00000000-0000-4000-b000-000000000011') e
  where e.exception_type = t and e.case_id in ('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000209')
$$;

-- order_expiring: valid until today + threshold counts, one day later does not.
-- (Session day one earlier: neither counts. One later: both count.)
select is(pg_temp.cases_with('order_expiring'), '208',
  'R2: order_expiring judges the order end date against the Zurich day (threshold from exception_rules, unchanged)');
-- care_plan_review_overdue: a review date of yesterday is overdue, today is not.
-- (Session day one earlier: neither. One later: both.)
select is(pg_temp.cases_with('care_plan_review_overdue'), '208',
  'R2: care_plan_review_overdue judges the review date against the Zurich day');

-- The same through the OPS1 reader as Operations.
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select string_agg(right(x.case_id::text, 3), ',' order by x.case_id) from public.operations_exceptions() x
           where x.exception_type = 'order_expiring'
             and x.case_id in ('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000209')), '208',
  'R2: OPS1 (operations_exceptions) shows the same order_expiring result');
select is((select string_agg(right(x.case_id::text, 3), ',' order by x.case_id) from public.operations_exceptions() x
           where x.exception_type = 'care_plan_review_overdue'
             and x.case_id in ('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000209')), '208',
  'R2: OPS1 (operations_exceptions) shows the same care_plan_review_overdue result');
reset role;

-- pause_case: an expected end of Zurich today is accepted, Zurich yesterday is refused.
-- (Session day one later: today refused. One earlier: yesterday accepted.)
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.pause_case('00000000-0000-4000-a000-000000000208', 'hospital_stay', null, pg_temp.today() - 1,
                                             'a5800000-0000-4000-8000-000000000001') $$,
  '22023', null, 'R2: pause_case refuses an expected end of the Zurich yesterday');
select is(public.pause_case('00000000-0000-4000-a000-000000000208', 'hospital_stay', null, pg_temp.today(),
                            'a5800000-0000-4000-8000-000000000002'), 'ok',
  'R2: pause_case accepts an expected end of the Zurich today');
reset role;
select is((select expected_end from public.case_lifecycle_events
           where case_id = '00000000-0000-4000-a000-000000000208' and kind = 'pause'
             and idempotency_key = 'a5800000-0000-4000-8000-000000000002'), pg_temp.today(),
  'R2: the pause stores the Zurich today as its expected end');
select is((select lifecycle from public.cases where id = '00000000-0000-4000-a000-000000000208'), 'paused',
  'R2: the case is paused');

select * from finish();
rollback;
