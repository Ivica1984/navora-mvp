-- ORDER-F1 (brief docs/agents/briefs/ORDER-F1.md, PO 2026-11-25 21:39; migration 0178). The client order list stays
-- loadable as orders grow. Root cause (measured read-only on navora-staging, 2026-11-25): private.order_member_step
-- evaluated private.visit_interval for every active visit of the member (sequential scan, no index on the person);
-- public.client_orders() calls it once per order with a live take, so the list cost grew with orders x visits.
-- 0178 adds a cheap visit_date window before the exact interval test, plus two indexes. This file proves:
-- (1) Bounds (the lemmas the two windows rest on): for 5 200 synthetic visit shapes (both DST weeks of 2026, every branch of
--     visit_interval: no time, no end, end = start, overnight, planned minutes 0 / 1 / 3 x 600), visit_interval lies
--     within [visit_date - 2 days, visit_date + 3 days) UTC and within [t0 - 3 h, t0 + 29 h], t0 = visit_date + start
--     read as UTC; a visit without a date reads unbounded (and is kept).
-- (2) Predicate equivalence: over those shapes x 4-hour and 9-hour slots across both weeks, «window and overlap» is
--     exactly «overlap».
-- (3) Function equivalence: the previous definition (frozen copy of supabase/schema/functions/private.order_member_step.sql
--     at recovery/main b9f7dcf5, as pg_temp, security definer dropped) and the new one return the same step for a real
--     member and three real orders (normal day, both DST nights) while one real visit of hers takes 2 376 shapes around
--     each order; both outcomes (3 busy, 4 eligible) occur.
-- (3b) The take clause of step 3 in its range form returns the previous result over 1 000 shifted slots against 1 000
--     real takes of one member (the overlap is implied for every row partner_requests_order_shape allows).
-- (4) Budget, deterministic first (AUT-186): 1 000 orders of one client, each with a live acknowledged take by the
--     same member, who has 2 000 planned visits (two on each order day, none overlapping): client_orders() lists all
--     1 000, calls order_member_step once per order (positive control: the counter counts) and visit_interval at most
--     20 times per order (the date window alone holds at most 9 days x 2 visits; the previous definition: 2 000 per
--     order); a loose
--     wall-clock limit of 4 s (half the 8 s authenticated statement timeout; target set by eng, estimate of CI speed)
--     only catches order-of-magnitude regressions; the measured value is printed as a diagnostic.
-- (5) Isolation: a member who is not in the client account reads none of the orders (existing pgTAP 135/147 unchanged).
-- The function guards (security definer, search_path, LEAVE1-3 access_ended, the window and the null-date clause) are in
-- the generated pgTAP 157. Users: kundebs …9e8 (client). Synthetic: M1 (nurse in team T1, org 019, verified FaGe; and in
-- team TV of org 011 for her visits). Pinned clock, moved forward only. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(21);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.clock(ts text) returns void language sql as $$ select set_config('navora.test_now', ts, true) $$;
select pg_temp.clock('2026-10-20 10:00:00+02');
create function pg_temp.m1() returns uuid language sql immutable as $$ select '00000000-0000-4000-a178-000000000001'::uuid $$;
create function pg_temp.t1() returns uuid language sql immutable as $$ select '00000000-0000-4000-b178-000000000001'::uuid $$;
create function pg_temp.tv() returns uuid language sql immutable as $$ select '00000000-0000-4000-b178-000000000002'::uuid $$;
create function pg_temp.cv() returns uuid language sql immutable as $$ select '00000000-0000-4000-c178-000000000001'::uuid $$;
create function pg_temp.vv() returns uuid language sql immutable as $$ select '00000000-0000-4000-d178-000000000001'::uuid $$;
create function pg_temp.bo(i int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-e178-' || lpad(i::text, 12, '0'))::uuid $$;
create function pg_temp.calls(f text) returns bigint language sql volatile as $$
  select coalesce((select s.calls from pg_stat_xact_user_functions s where s.schemaname = 'private' and s.funcname = f), 0)
$$;

-- 0. Surface ---------------------------------------------------------------------------------------------------------------
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'care_visits'
                  and indexname = 'care_visits_responsible_date' and indexdef ilike '%(responsible_user_id, visit_date)%'),
          'ORDER-F1: care_visits is indexed by responsible person and date');
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'care_visits'
                  and indexname = 'care_visits_covered_by_date' and indexdef ilike '%(covered_by, visit_date)%'),
          'ORDER-F1: care_visits is indexed by covering person and date');
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and tablename = 'partner_requests'
                  and indexname = 'partner_requests_slot' and indexdef ilike '%gist%tstzrange(starts_at, ends_at%'),
          'ORDER-F1: an order''s slot is indexed as a range (overlap with her other live takes)');

-- 1. and 2. The bound and the predicate (pure, no rows written) -----------------------------------------------------------
create temp table shapes as
  select vd, ts, te, pm,
         private.visit_interval(jsonb_populate_record(null::public.care_visits, jsonb_build_object(
           'visit_date', vd, 'time_start', ts, 'time_end', te,
           'planned_minutes_a', pm, 'planned_minutes_b', pm, 'planned_minutes_c', pm))) as r
  from (select generate_series(date '2026-03-26', date '2026-04-01', interval '1 day')::date
        union all select generate_series(date '2026-10-23', date '2026-10-28', interval '1 day')::date) s(vd)
     , unnest(array[null, '00:00', '00:30', '01:59', '02:00', '02:30', '03:00', '12:00', '23:00', '23:59']::time[]) ts
     , unnest(array[null, '00:00', '00:30', '01:59', '02:00', '02:30', '03:00', '12:00', '23:00', '23:59']::time[]) te
     , unnest(array[null, 0, 1, 600]) pm;
select is((select count(*)::int from shapes), 5200, 'the grid holds 13 days x 10 x 10 times x 4 minute values');
select is((select count(*)::int from shapes
           where not isempty(r) and (lower_inf(r) or upper_inf(r)
                 or lower(r) < (vd - 2)::timestamp at time zone 'UTC' or upper(r) > (vd + 3)::timestamp at time zone 'UTC')),
          0, 'ORDER-F1 lemma: every dated visit interval lies within [visit_date - 2 days, visit_date + 3 days) UTC');
select is((select count(*)::int from shapes
           where not isempty(r) and (lower(r) < ((vd + coalesce(ts, time '00:00')) at time zone 'UTC') - interval '3 hours'
                 or upper(r) > ((vd + coalesce(ts, time '00:00')) at time zone 'UTC') + interval '29 hours')),
          0, 'ORDER-F1 lemma: every dated visit interval lies within [t0 - 3 h, t0 + 29 h], t0 = date + start (UTC)');
select ok((select lower_inf(r) and upper_inf(r) from (select private.visit_interval(
             jsonb_populate_record(null::public.care_visits, '{}'::jsonb)) as r) x),
          'a visit without a date reads unbounded, so the window keeps it (visit_date is null)');
create temp table slots as
  select s as starts_at, s + make_interval(hours => h) as ends_at
  from (select generate_series(timestamptz '2026-03-24 00:00+00', timestamptz '2026-04-03 00:00+00', interval '4 hours')
        union all select generate_series(timestamptz '2026-10-21 00:00+00', timestamptz '2026-10-31 00:00+00', interval '4 hours')) g(s)
     , unnest(array[4, 9]) h;
create temp table pred as
  select (x.r && tstzrange(y.starts_at, y.ends_at, '[)')) as old_p,
         ((x.vd is null or x.vd between (y.starts_at at time zone 'UTC')::date - 4 and (y.ends_at at time zone 'UTC')::date + 4)
          and (x.vd is null or ((x.vd + coalesce(x.ts, time '00:00')) at time zone 'UTC')
                                between y.starts_at - interval '32 hours' and y.ends_at + interval '6 hours')
          and x.r && tstzrange(y.starts_at, y.ends_at, '[)')) as new_p
  from shapes x, slots y;
select is((select count(*)::int from pred where old_p is distinct from new_p), 0,
          'ORDER-F1: over every shape x slot, «both windows and overlap» equals «overlap»');
select ok((select count(*) filter (where old_p) > 0 and count(*) filter (where not old_p) > 0 from pred),
          'the predicate grid holds overlapping and non-overlapping pairs (both outcomes tested)');

-- 3. Fixture (synthetic), as the table owner --------------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003d8', '00000000-0000-4000-b000-000000000019', 'Haushalt ORDER-F1 A (synthetisch)', 'household'),
  ('00000000-0000-4000-a000-0000000003d9', '00000000-0000-4000-b000-000000000019', 'Haushalt ORDER-F1 B (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003d8', '00000000-0000-4000-a000-0000000009e8'),
  ('00000000-0000-4000-a000-0000000003d9', '00000000-0000-4000-a000-0000000009e8');
insert into auth.users (id, aud, role, email) values (pg_temp.m1(), 'authenticated', 'authenticated', 'order-f1-m1.fixture@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'nurse'), ('00000000-0000-4000-b000-000000000011', pg_temp.m1(), 'nurse');
insert into public.member_profiles (organization_id, user_id, display_name) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.m1(), 'Synth ORDER-F1 M1');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.t1(), 'ORDER-F1 Fixture T1', 'Basel-Landschaft', 'active', 10);
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.tv(), 'ORDER-F1 Fixture TV', 'Bern Nord', 'active');
insert into public.team_service_postcodes (team_id, postcode) values (pg_temp.t1(), '4102');
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.t1(), pg_temp.m1(), 'care_assistant'), (pg_temp.tv(), pg_temp.m1(), 'registered_nurse');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  values ('00000000-0000-4000-b000-000000000019', pg_temp.m1(), 'grade', 'fage_efz', 'verified', true, null);
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.cv(), 'assigned_team_id', pg_temp.tv(),
          'auto_planning', false, 'primary_nurse_id', null, 'deputy_nurse_id', null, 'proposed_primary_nurse_id', null))).*
from kc k;

create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(k text, acct text, d date, s time, e time, key text) returns void language sql as $$
  insert into made select k, public.confirm_client_order(acct::uuid, d, s, e, '4102', 'fage_efz', array['C1'], array['C1'], null, key::uuid)
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select pg_temp.co('o1', '00000000-0000-4000-a000-0000000003d8', date '2026-10-24', time '22:00', time '07:00', 'dddd0000-0000-4000-8178-000000000001');  -- autumn DST night
select pg_temp.co('o2', '00000000-0000-4000-a000-0000000003d8', date '2026-10-27', time '08:00', time '12:00', 'dddd0000-0000-4000-8178-000000000002');  -- ordinary day
select pg_temp.co('o3', '00000000-0000-4000-a000-0000000003d8', date '2027-03-27', time '22:00', time '07:00', 'dddd0000-0000-4000-8178-000000000003');  -- spring DST night
select pg_temp.co('b0', '00000000-0000-4000-a000-0000000003d9', date '2026-10-29', time '08:00', time '12:00', 'dddd0000-0000-4000-8178-000000000004');  -- budget template
reset role;
select pg_temp.as_owner();
select is((select count(*)::int from made where r ->> 'result' = 'ok'), 4, 'the four fixture orders are confirmed');

-- 3. Function equivalence: previous definition (frozen copy) against the new one ------------------------------------------
CREATE FUNCTION pg_temp.order_member_step_old(p_order_id uuid, p_team_id uuid, p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  o    public.partner_requests;
  g    record;
  kind text;
begin
  select * into o from public.partner_requests where id = p_order_id;
  if o.id is null or o.starts_at is null or o.ends_at is null then return 0; end if;
  if not private.user_in_team(p_team_id, p_user_id) or private.access_ended(p_user_id) then return 0; end if;  -- LEAVE1-3

  -- Level: verified, equal to the ordered grade, still valid at the end of the slot (QUAL1-2, -4; CGR-205 (d)).
  select * into g from private.qual_evidence_state(o.organization_id, p_user_id, 'grade', o.ends_at);
  if g.state is distinct from 'verified' or g.grade is distinct from o.grade then return 1; end if;

  -- Activities: the one reading of 0133 (CGR-218 (A), CGR-219), through the client kind of the order's account.
  select a.client_kind into kind from public.client_accounts a where a.id = o.client_account_id;
  if not private.member_activity_ok(o.organization_id, p_user_id, kind, o.grade, o.activity_tags, o.required_tags,
                                    o.ends_at) then
    return 2;
  end if;

  -- Availability for the whole slot [start, end): her absences in any team, her open visits, and (BK-c1, AUT-130,
  -- CGR-224) her live take of ANOTHER shift order whose slot overlaps. The own order never counts.
  if exists (select 1 from public.member_absences x
             where x.user_id = p_user_id and x.withdrawn_at is null
               and x.starts_at < o.ends_at and x.ends_at > o.starts_at)
     or exists (select 1 from public.care_visits v
                where (v.responsible_user_id = p_user_id or v.covered_by = p_user_id)
                  and v.status in ('planned', 'on_the_way', 'started', 'paused')
                  and private.visit_interval(v) && tstzrange(o.starts_at, o.ends_at, '[)')
                  -- BK-E1B (CGR-232): the visit written from a take of THIS order never counts.
                  and not exists (select 1 from public.order_takes vt
                                  where vt.id = v.order_take_id and vt.order_id = o.id))
     or exists (select 1 from public.order_takes k
                join public.partner_requests q on q.id = k.order_id
                where k.member_id = p_user_id and k.released_at is null and k.order_id <> o.id
                  and q.starts_at < o.ends_at and q.ends_at > o.starts_at)
     -- BK-C2 (ADR-200 (4)): she said «Ich kann nicht» for THIS order; never re-offered as the going person.
     or exists (select 1 from public.order_takes c
                where c.order_id = o.id and c.member_id = p_user_id and c.release_reason = 'member_cannot') then
    return 3;
  end if;
  return 4;
end;
$function$;

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.vv(), pg_temp.cv(), pg_temp.tv(), date '2026-11-10', '14:00', '15:00',
        array['Grundpflege'], false, 'planned', 30, 0, pg_temp.m1());

create temp table eq (anchor date, vd date, ts time, te time, pm int, k text, old_step int, new_step int);
do $$
declare
  a date; off int; s time; e time; p int;
  times time[] := array[null, '00:00', '02:30', '06:59', '21:59', '23:59']::time[];
begin
  foreach a in array array[date '2026-10-24', date '2026-10-27', date '2027-03-27'] loop
    for off in -5..5 loop
      foreach s in array times loop
        foreach e in array times loop
          foreach p in array array[null, 600]::int[] loop
            update public.care_visits set visit_date = a + off, time_start = s, time_end = e,
                   planned_minutes_a = p, planned_minutes_b = p, planned_minutes_c = p
             where id = pg_temp.vv();
            insert into eq select a, a + off, s, e, p, x.k,
                                  pg_temp.order_member_step_old(pg_temp.oid(x.k), pg_temp.t1(), pg_temp.m1()),
                                  private.order_member_step(pg_temp.oid(x.k), pg_temp.t1(), pg_temp.m1())
                             from unnest(array['o1', 'o2', 'o3']) x(k);
          end loop;
        end loop;
      end loop;
    end loop;
  end loop;
end $$;
select is((select count(*)::int from eq), 3 * 11 * 6 * 6 * 2 * 3, 'every visit shape was compared for all three orders');
select is((select count(*)::int from eq where old_step is distinct from new_step), 0,
          'ORDER-F1: the new order_member_step returns the previous step for every visit shape and order');
select ok((select count(*) filter (where old_step = 3) > 0 and count(*) filter (where old_step = 4) > 0 from eq),
          'both outcomes occur: busy through the visit (3) and eligible (4)');
select ok((select bool_and(old_step in (3, 4)) from eq), 'the member passes level and activity, so only availability varies');

-- 4. Budget: 1 000 orders of one client, one live acknowledged take each, 2 000 visits of the member ----------------------
create function pg_temp.take(k text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m1()::text);
  set local role authenticated;
  res := public.take_order(pg_temp.oid(k), pg_temp.t1(), pg_temp.m1(), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end $$;
select is(pg_temp.take('b0', 'ffff0000-0000-4000-8178-000000000001') ->> 'result', 'ok',
          'M1 takes the budget template order naming herself');
-- Moved forward past the template: every budget order is in the past, as on staging, so no write re-checks a take.
select pg_temp.clock('2026-11-30 10:00:00+01');
create temp table bt as select * from public.partner_requests where id = pg_temp.oid('b0');
insert into public.partner_requests
select (jsonb_populate_record(b, jsonb_build_object('id', pg_temp.bo(i),
          'starts_at', b.starts_at - make_interval(days => i), 'ends_at', b.ends_at - make_interval(days => i)))).*
from bt b, generate_series(1, 999) i;
create temp table kt as select * from public.order_takes where order_id = pg_temp.oid('b0') and released_at is null;
insert into public.order_takes
select (jsonb_populate_record(k, jsonb_build_object('id', gen_random_uuid(), 'order_id', pg_temp.bo(i),
          'taken_at', k.taken_at - make_interval(days => i), 'acknowledged_at', k.acknowledged_at - make_interval(days => i)))).*
from kt k, generate_series(1, 999) i;
insert into public.care_visits (organization_id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.cv(), pg_temp.tv(), date '2026-10-29' - i, t.s, t.e,
       array['Grundpflege'], false, 'planned', 30, 0, pg_temp.m1()
from generate_series(0, 999) i, (values (time '06:00', time '07:00'), (time '14:00', time '15:00')) t(s, e);

-- As autovacuum would after such a load in operation: fresh statistics, so the planner sees 1 000 takes of one member.
analyze public.partner_requests;
analyze public.order_takes;
analyze public.care_visits;

-- The take clause of step 3 (another live take of hers whose slot overlaps), previous form against the new form, with
-- the 1 000 real takes: 200 orders x slots shifted by 0, 12, 21, 24 and 27 hours (24 h meets the next day's order).
create temp table tk as
  select o.id, h,
         exists (select 1 from public.order_takes k join public.partner_requests q on q.id = k.order_id
                 where k.member_id = pg_temp.m1() and k.released_at is null and k.order_id <> o.id
                   and q.starts_at < o.ends_at + make_interval(hours => h) and q.ends_at > o.starts_at + make_interval(hours => h)) as old_c,
         exists (select 1 from public.order_takes k join public.partner_requests q on q.id = k.order_id
                 where k.member_id = pg_temp.m1() and k.released_at is null and k.order_id <> o.id
                   and q.starts_at < o.ends_at + make_interval(hours => h) and q.ends_at > o.starts_at + make_interval(hours => h)
                   and tstzrange(q.starts_at, q.ends_at, '[)')
                       && tstzrange(o.starts_at + make_interval(hours => h), o.ends_at + make_interval(hours => h), '[)')) as new_c
  from public.partner_requests o, unnest(array[0, 12, 21, 24, 27]) h
  where o.id in (select pg_temp.bo(i) from generate_series(1, 200) i);
select is((select count(*)::int from tk where old_c is distinct from new_c), 0,
          'ORDER-F1: the range form of the take overlap returns the previous result for 1 000 slots');
select ok((select count(*) filter (where old_c) > 0 and count(*) filter (where not old_c) > 0 from tk),
          'both outcomes occur in the take comparison (an overlapping take of hers, and none)');

create temp table fstat0 as select funcid, calls, total_time, self_time from pg_stat_xact_user_functions where schemaname = 'private';
create temp table meas (ms numeric, n int, member_step bigint, visit_interval bigint);
grant all on meas to authenticated;
create function pg_temp.measure() returns void language plpgsql as $$
declare t0 timestamptz; n int; ms0 bigint := pg_temp.calls('order_member_step'); vi0 bigint := pg_temp.calls('visit_interval');
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
  set local role authenticated;
  t0 := clock_timestamp();
  select count(*) filter (where x.client_account_id = '00000000-0000-4000-a000-0000000003d9') into n from public.client_orders() x;
  insert into meas values (extract(epoch from clock_timestamp() - t0) * 1000, n, 0, 0);
  reset role;
  perform pg_temp.as_owner();
  update meas set member_step = pg_temp.calls('order_member_step') - ms0, visit_interval = pg_temp.calls('visit_interval') - vi0;
end $$;
select pg_temp.measure();
select diag('ORDER-F1 budget: client_orders() for 1 000 orders and 2 000 visits took ' || round(ms) || ' ms; order_member_step '
            || member_step || ' calls, visit_interval ' || visit_interval || ' calls') from meas;
-- Diagnostic only (no assertion): where the time goes, per private function, during the one measured call.
select diag('ORDER-F1 budget, per function: ' || string_agg(f.funcid::regprocedure::text || ' calls ' || (f.calls - coalesce(z.calls, 0))
            || ' total ' || round((f.total_time - coalesce(z.total_time, 0))::numeric) || ' ms self '
            || round((f.self_time - coalesce(z.self_time, 0))::numeric) || ' ms', '; '
            order by f.self_time - coalesce(z.self_time, 0) desc))
from pg_stat_xact_user_functions f left join fstat0 z using (funcid)
where f.schemaname = 'private' and f.calls > coalesce(z.calls, 0);
select is((select n from meas), 1000, 'the client lists all 1 000 budget orders');
select ok((select member_step >= 1000 and visit_interval <= 20 * 1000 from meas),
          'ORDER-F1: one eligibility check per order and at most 20 interval tests per order (previous: 2 000 per order)');
select ok((select ms < 4000 from meas), 'loose wall-clock limit: 1 000 orders list in under 4 s (statement timeout 8 s)');

-- 5. Isolation --------------------------------------------------------------------------------------------------------------
create function pg_temp.orders_seen_by(uid uuid) returns int language plpgsql as $$
declare n int;
begin
  perform pg_temp.act_as(uid::text);
  set local role authenticated;
  select count(*)::int into n from public.client_orders();
  reset role;
  perform pg_temp.as_owner();
  return n;
end $$;
select is(pg_temp.orders_seen_by(pg_temp.m1()), 0, 'a member outside the client account reads none of the orders');

select * from finish();
rollback;
