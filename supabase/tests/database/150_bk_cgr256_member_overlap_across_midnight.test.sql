-- CGR-256 (`cra` 2026-11-18 13:29, advisory S1 before real clients; PO brief `docs/agents/briefs/BK.md` §PO amendments
-- 13:39 (2), 14:39 (2), 20:39 and 21:39: first follow-up of slice BK-e; precondition before the 22:00–07:00 take leaves
-- simulation-only status). Red first (FE-071 (2)): pushed alone, before migration 0150, where the PLAN3-16 member-overlap
-- fact (`private.member_visit_overlap`, `public.member_slot_overlap`) only compares visits of the same `visit_date`, so a
-- 22:00–07:00 visit dated D is never seen beside a 06:00 visit of the same person dated D + 1.
--
-- What it guards (the `cra` pgTAP pair, amendment 13:39 (2), and its mirror cases):
--   * a member with a 22:00–07:00 visit on D: a hand visit for her on D + 1 at 06:00 reads `member_overlap` true;
--     at 07:30 false; at 07:00 (touching end) false; the same for the form's read (`member_slot_overlap`);
--   * the other direction: the night visit itself reads true against her 06:00 visit of D + 1;
--   * a night visit of D - 1 (ends D 07:00) is not seen on D + 1; a cancelled night visit is never seen;
--   * same-day cases are unchanged (control), and the fact stays one definition with the same locks
--     (PLAN3-16, ADR-161; BK-E1B-L person lock first, CGR-233).
-- The night visit stands for the visit a 22:00–07:00 take writes (BK-7, ADR-202 (2)): an ordinary `care_visits` row of
-- the named member with `time_end < time_start`; the overlap reading does not look at its origin. Information only:
-- nothing here is refused for an overlap. No rest-time rule (UNKNOWN, Clinical Owner, H-10). All data synthetic; rolled
-- back.
-- Seed users (Testorganisation A …011): pflege …902 (not in the synthetic teams). Synthetic here: team A (m1, m2), team B
-- (m1). Day D = T + 2 (pinned clock).
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.d() returns date language sql stable as $$ select t + 2 from d0 $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'm1' then 'a2560000-0000-4000-a000-0000000000a1' when 'm2' then 'a2560000-0000-4000-a000-0000000000a2'
                 when 'm3' then 'a2560000-0000-4000-a000-0000000000a3' end)::uuid
$$;
create function pg_temp.team(n text) returns uuid language sql immutable as $$
  select ('a2560000-0000-4000-a000-00000000000' || case n when 'A' then '1' else '2' end)::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000011'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a2561000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.c(n text) returns uuid language sql immutable as $$
  select ('a2560000-0000-4000-c000-00000000000' || case n when 'A' then '1' else '2' end)::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a2560000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
-- plan_visit of 30 min category A for case KA on day dt, as m2, for m1 (the hand path of a second planner).
create function pg_temp.plan(dt date, s time, e time, key int) returns jsonb language sql as $$
  select pg_temp.cmd('m2', format(
    'select public.plan_visit(%L, %L, %L, %L, 30, 0, 0, false, %L, %L, null, null)',
    pg_temp.c('A'), dt, s, e, pg_temp.u('m1'), pg_temp.k(key))) $$;
-- The form's read before saving (planning form of case KA), as m2, about m1.
create function pg_temp.slot(dt date, s time, e time) returns jsonb language sql as $$
  select pg_temp.cmd('m2', format('select public.member_slot_overlap(%L, null, %L, %L, %L, %L)',
    pg_temp.c('A'), pg_temp.u('m1'), dt, s, e)) $$;

-- Fixtures (as the table owner) ----------------------------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), 'cgr256-' || n || '@navora.test' from unnest(array['m1', 'm2', 'm3']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['m1', 'm2', 'm3']) n;
insert into public.member_profiles (organization_id, user_id, display_name)
select pg_temp.org(), pg_temp.u(n), 'Synth ' || upper(n) from unnest(array['m1', 'm2', 'm3']) n;
insert into public.teams (organization_id, id, name, region, status)
values (pg_temp.org(), pg_temp.team('A'), 'Synth Team CGR-256 A', 'Bern Nord', 'active'),
       (pg_temp.org(), pg_temp.team('B'), 'Synth Team CGR-256 B', 'Bern Nord', 'active');
insert into public.team_memberships (team_id, user_id, qualification)
values (pg_temp.team('A'), pg_temp.u('m1'), 'registered_nurse'), (pg_temp.team('A'), pg_temp.u('m2'), 'registered_nurse'),
       (pg_temp.team('B'), pg_temp.u('m1'), 'registered_nurse'), (pg_temp.team('B'), pg_temp.u('m3'), 'registered_nurse');
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.c(n), 'assigned_team_id', pg_temp.team(n),
          'auto_planning', false, 'primary_nurse_id', null, 'deputy_nurse_id', null, 'proposed_primary_nurse_id', null))).*
from kc k, unnest(array['A', 'B']) n;
create function pg_temp.mk(n int, k text, dt date, s time, e time, resp text, st text default 'planned')
returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                  billable, status, planned_minutes_a, planned_minutes_b, responsible_user_id)
  values (pg_temp.org(), pg_temp.v(n), pg_temp.c(k), pg_temp.team(k), dt, s, e, array['Grundpflege'], false,
          st, 30, 0, pg_temp.u(resp)) $$;
select pg_temp.mk(1, 'B', pg_temp.d(), '22:00', '07:00', 'm1');   -- N: m1's night in team B, D 22:00 to D+1 07:00

-- Contract: one definition, same locks (unchanged by CGR-256) ----------------------------------------------------------------
select ok((select prosrc ~ 'order_take_member:' and prosrc ~ 'plan3_busy:'
                  and position('order_take_member:' in prosrc) < position('plan3_busy:' in prosrc)
           from pg_proc where oid = 'private.member_visit_overlap(uuid, uuid)'::regprocedure),
  'CGR-233 / PLAN3-16: the overlap reading still takes the person lock first, then the member-and-day lock');
select ok((select prosrc ~ 'private\.member_visit_overlap\(' from pg_proc
           where oid = 'private.plan3_confirm_overlaps(uuid, uuid)'::regprocedure),
  'PLAN3-16: the PLAN3-14 confirm (AIG1 day plan) still reads the same member-overlap definition');

-- The form's read before saving (same fact), before m1 has any visit on D + 1 ----------------------------------------------
select is(pg_temp.slot(pg_temp.d() + 1, '06:00', '06:30'), 'true'::jsonb,
  'CGR-256: the form reads a 06:00 slot on D+1 as busy (night of D, team B)');
select is(pg_temp.slot(pg_temp.d() + 1, '07:30', '08:00'), 'false'::jsonb, 'CGR-256: the form reads 07:30 on D+1 as free');
select is(pg_temp.slot(pg_temp.d() + 1, '07:00', '07:30'), 'false'::jsonb, 'CGR-256: touching ends do not overlap');

-- The cra pair: a hand visit on D + 1 beside the night of D --------------------------------------------------------------------
create temp table r1 as select pg_temp.plan(pg_temp.d() + 1, '06:00', '06:30', 1) as r;
select is((select r ->> 'result' from r1), 'ok', 'CGR-256: a 06:00 visit on D+1 for m1 is saved, never refused');
select is((select r -> 'member_overlap' from r1), 'true'::jsonb,
  'CGR-256: 06:00 on D+1 meets her 22:00–07:00 night of D: member_overlap true');
-- The other direction, while the 06:00 visit of D + 1 is her only other visit: the night reads it.
select is(private.member_visit_overlap(pg_temp.v(1), pg_temp.u('m1')), true,
  'CGR-256: the 22:00–07:00 visit of D reads her 06:00 visit of D+1 as an overlap');
create temp table r2 as select pg_temp.plan(pg_temp.d() + 1, '07:30', '08:00', 2) as r;
select is((select r ->> 'result' || ':' || (r ->> 'member_overlap') from r2), 'ok:false',
  'CGR-256: 07:30 on D+1 is after the night: member_overlap false');
create temp table r3 as select pg_temp.plan(pg_temp.d() + 1, '07:00', '07:30', 3) as r;
select is((select r ->> 'result' || ':' || (r ->> 'member_overlap') from r3), 'ok:false',
  'CGR-256: 07:00 on D+1 only touches the night''s end: member_overlap false');
select is((select r ->> 'result' || ':' || (r ->> 'member_overlap') from (select pg_temp.plan(pg_temp.d(), '23:00', '23:30', 4) as r) s),
  'ok:true', 'control: 23:00 on D (same day as the night) stays true');
select ok((select r::text !~ (pg_temp.v(1)::text || '|' || pg_temp.c('B')::text || '|' || pg_temp.team('B')::text
                             || '|22:00|07:00|Team CGR-256 B') from r1),
  'CGR-256: nothing of the night (id, case, team, time) reaches the asking team, only yes/no');
select is(private.member_visit_overlap((select (r ->> 'visit_id')::uuid from r1), pg_temp.u('m2')), false,
  'a different member is never read (m2 has no visit)');

-- Not seen: a night two days back, and a cancelled night -----------------------------------------------------------------------
select pg_temp.mk(2, 'B', pg_temp.d() + 2, '22:00', '07:00', 'm1');   -- night of D+2, starts after every D+1 visit above
select is((select (pg_temp.plan(pg_temp.d() + 1, '20:00', '20:30', 5)) ->> 'member_overlap'), 'false',
  'a night of D+2 (from 22:00) is not met by a D+1 20:00 visit');
select is(private.member_visit_overlap(pg_temp.v(2), pg_temp.u('m1')), false,
  'the night of D+2 does not read the D+1 morning visits (they ended before 22:00)');
select pg_temp.mk(3, 'B', pg_temp.d() + 4, '22:00', '07:00', 'm1', 'cancelled');   -- cancelled night of D+4
select is((select (pg_temp.plan(pg_temp.d() + 5, '06:00', '06:30', 6)) ->> 'member_overlap'), 'false',
  'a cancelled night of D+4 is never read on D+5');
select pg_temp.mk(4, 'B', pg_temp.d() + 6, '22:00', '07:00', 'm1');   -- night of D+6, ends D+7 07:00
select is((select (pg_temp.plan(pg_temp.d() + 8, '06:00', '06:30', 7)) ->> 'member_overlap'), 'false',
  'a night of D+6 (ends D+7 07:00) is not seen on D+8 at 06:00');

select is((select count(*)::int from public.care_visits where responsible_user_id = pg_temp.u('m1')
           and team_id = pg_temp.team('A')), 7,
  'every hand visit above was saved (information only, nothing refused for an overlap)');

select * from finish();
rollback;
