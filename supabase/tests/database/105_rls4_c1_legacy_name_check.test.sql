-- RLS4-C1 (po 2026-10-30 06:10 and 09:15; `cra` CGR-101; `lca` 05:55 D-1 notes 1-2 and 08:42 D-4; `aia` AUT-27;
-- ADR-122 addendum): the runbook check `docs/engineering/OWNER_RUNBOOK.md` §5c counts the non-cancelled visits dated
-- today or later whose only nurse record is the legacy free-text `team_member_name` (no `responsible_user_id`).
-- This file holds the same query (tests/unit/rls4-c1-runbook-check.test.ts keeps the two texts identical) and shows on
-- the synthetic seed:
--   * a Testteam Mitte visit dated today with "Pflegekraft Test 3" and no responsible member is counted once;
--   * a cancelled one, a past one (the seed's own Mitte visits are dated yesterday) and one with a responsible member
--     are not counted;
--   * the mapping step of the runbook (set by a person, one name and team, one transaction) brings the count back,
--     sets `responsible_user_id` only, never edits `team_member_name`, leaves one audit row naming the step, and maps
--     nothing to a person who is not a member of the visit's team;
--   * `team_member_name` stays and stays unreadable to `authenticated` (0099; retention until D-4 is final).
-- The seed holds other future visits with only a legacy name (Testteam Nord and others), so the counts are asserted
-- against the seed's baseline (ADR-122 addendum, deviation 1). No migration; nothing here runs on any live project.
-- Users (supabase/seed.sql): nurse …902 (registered nurse, Testteam Nord …101), care assistant …906 (Nord only).
-- Case …210 (Testfall 10, Testteam Mitte …102). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  private.at_zurich(((private.at_zurich(private.now()))::date + time '10:00')::timestamp)::text, true);

-- The runbook check, verbatim (OWNER_RUNBOOK.md §5c step 1) --------------------------------------------------------------
create function pg_temp.unmapped() returns integer language sql as $$
-- RLS4-C1 check begin
select count(*)::int as unmapped
from public.care_visits v
where v.status <> 'cancelled'
  and v.visit_date >= (private.at_zurich(private.now()))::date
  and v.team_member_name is not null
  and v.responsible_user_id is null;
-- RLS4-C1 check end
$$;
create function pg_temp.today() returns date language sql as $$ select (private.at_zurich(private.now()))::date $$;
create function pg_temp.v(n integer) returns uuid language sql as $$
  select ('00000000-0000-4000-a105-' || lpad(n::text, 12, '0'))::uuid $$;

create temp table rls4c1_base on commit drop as select pg_temp.unmapped() as n;

-- Fixtures (as the table owner) -----------------------------------------------------------------------------------------
-- v(1) Mitte, today, legacy name only: the case CGR-101 describes.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, team_member_name,
                                billable, status, planned_minutes_a)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000210',
        '00000000-0000-4000-a000-000000000102', pg_temp.today(), time '15:00', time '15:30', 'Pflegekraft Test 3',
        false, 'planned', 30);
select is(pg_temp.unmapped() - (select n from rls4c1_base), 1,
  'RLS4-C1 (2): the Testteam Mitte visit of today with only the legacy name is counted once');

-- v(2) cancelled, v(3) yesterday, v(4) tomorrow but with a responsible member: none is counted.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, team_member_name,
                                billable, status, planned_minutes_a, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000210',
        '00000000-0000-4000-a000-000000000102', pg_temp.today(), time '16:00', time '16:30', 'Pflegekraft Test 3',
        false, 'cancelled', 30, null),
       ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000210',
        '00000000-0000-4000-a000-000000000102', pg_temp.today() - 1, time '17:00', time '17:30', 'Pflegekraft Test 3',
        false, 'planned', 30, null);
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000902', 'registered_nurse');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, team_member_name,
                                billable, status, planned_minutes_a, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(4), '00000000-0000-4000-a000-000000000210',
        '00000000-0000-4000-a000-000000000102', pg_temp.today() + 1, time '15:00', time '15:30', 'Pflegekraft Test 3',
        false, 'planned', 30, '00000000-0000-4000-a000-000000000902');
select is(pg_temp.unmapped() - (select n from rls4c1_base), 1,
  'RLS4-C1 (1): cancelled, past and already-assigned visits are not counted');
select ok((select bool_and(visit_date < pg_temp.today() and team_member_name = 'Pflegekraft Test 3')
           from public.care_visits
           where id in ('00000000-0000-4000-a000-000000000505', '00000000-0000-4000-a000-000000000506')),
  'RLS4-C1: the seed''s own Testteam Mitte visits with this name are dated yesterday (outside the check)');

-- A wrong decision is refused by the runbook's membership guard: the care assistant is not in Testteam Mitte ------------
set local navora.command = 'rls4_c1_legacy_mapping';
with mapped as (
  update public.care_visits v set responsible_user_id = '00000000-0000-4000-a000-000000000906'
  where v.team_id = '00000000-0000-4000-a000-000000000102' and v.team_member_name = 'Pflegekraft Test 3'
    and v.responsible_user_id is null and v.status <> 'cancelled'
    and v.visit_date >= (private.at_zurich(private.now()))::date
    and exists (select 1 from public.team_memberships m
                where m.team_id = v.team_id and m.user_id = '00000000-0000-4000-a000-000000000906')
  returning v.id)
select is((select count(*)::int from mapped), 0,
  'RLS4-C1 (1): the mapping never makes a person responsible who is not a member of the visit''s team');

-- The decided mapping (runbook §5c step 4): one legacy name, one team, one member, as a person decided -------------------
with mapped as (
  update public.care_visits v set responsible_user_id = '00000000-0000-4000-a000-000000000902'
  where v.team_id = '00000000-0000-4000-a000-000000000102' and v.team_member_name = 'Pflegekraft Test 3'
    and v.responsible_user_id is null and v.status <> 'cancelled'
    and v.visit_date >= (private.at_zurich(private.now()))::date
    and exists (select 1 from public.team_memberships m
                where m.team_id = v.team_id and m.user_id = '00000000-0000-4000-a000-000000000902')
  returning v.id)
select is((select array_agg(id) from mapped), array[pg_temp.v(1)],
  'RLS4-C1 (1): the decided mapping updates exactly the counted visit');
select is(pg_temp.unmapped() - (select n from rls4c1_base), 0,
  'RLS4-C1 (2): after the mapping the check is back at the baseline (the Mitte visit is no longer counted)');
select is((select team_member_name from public.care_visits where id = pg_temp.v(1)), 'Pflegekraft Test 3',
  'RLS4-C1 (1), D-4: the mapping never edits team_member_name');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(3)), null::uuid,
  'RLS4-C1 (3): the past visit is not mapped (only today or later)');
select is((select count(*)::int from public.audit_events
           where entity_id = pg_temp.v(1) and table_name = 'care_visits' and command = 'rls4_c1_legacy_mapping'), 1,
  'RLS4-C1 (1): the mapping leaves one audit row naming the runbook step');
select is((select array_agg(k order by k) from public.audit_events e, jsonb_object_keys(e.changed) k
           where e.entity_id = pg_temp.v(1) and e.table_name = 'care_visits' and e.command = 'rls4_c1_legacy_mapping'),
  array['responsible_user_id'],
  'RLS4-C1 (1): the audit row records responsible_user_id only (no name is written or audited)');

-- Retention (RLS4-C1 (3)): the column stays, unreadable to every app role, until D-4's final rule ------------------------
select has_column('public', 'care_visits', 'team_member_name',
  'RLS4-C1 (3): team_member_name stays (not dropped or blanked before D-4 is final)');
select ok(not has_column_privilege('authenticated', 'public.care_visits', 'team_member_name', 'select')
          and not has_column_privilege('anon', 'public.care_visits', 'team_member_name', 'select'),
  'RLS4-C1 (3): team_member_name stays unreadable to authenticated and anon (0099)');

select * from finish();
rollback;
