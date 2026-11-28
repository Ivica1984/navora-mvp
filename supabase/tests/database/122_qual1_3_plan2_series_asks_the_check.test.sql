-- QUAL1 part 2, slice 2 (brief docs/agents/briefs/QUAL1.md QUAL1-10; migration 0122, ADR-165): the PLAN2 series asks the one
-- decision function. Before 0122 the series named the primary nurse by the J3 rule and the 0121 backstop refused the
-- insert, so in a simulation organisation every care-plan change, page-load refresh and daily run with a member the
-- check refuses failed as a whole (found 2026-11-07 on the #943 head `b457329`). Now the series names the primary nurse,
-- else the deputy (under the old deputy rule), only when the check confirms every activity; else the visit stays open in
-- the team (the existing PLAN2 "nobody" outcome). The backstop is unchanged.
-- Simulation · synthetische Daten · Regeln PROPOSED (QUAL1-14): every name, grade and evidence row below is synthetic and
-- created by this file (QUAL1-12: own fixture). Passing it is NOT a clinical release (CGR-145).
--
-- Fixture: organisation SIM (simulation = true), team A.
--   n1  nurse_hf_fh verified, practice licence verified        m1  fage_efz verified
-- Cases (needs assessment done, order present, auto planning on):
--   K1 primary m1, deputy n1     K2 primary m1, no deputy     K3 primary n1     K4 primary m1, no deputy
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select ('a1220000-0000-4000-a000-0000000000' || case n when 'n1' then '01' when 'm1' then '11' end)::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select 'a1220000-0000-4000-b000-000000000001'::uuid $$;
create function pg_temp.ta() returns uuid language sql immutable as $$ select 'a1220000-0000-4000-a000-000000000011'::uuid $$;
create function pg_temp.c(n int) returns uuid language sql immutable as $$
  select ('a1220000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid $$;
-- A care-plan item with a daily schedule (the PLAN2 trigger generates the series); run as the table owner.
create function pg_temp.add_item(p_case int, p_category text, p_start time, p_end time) returns text language plpgsql as $$
declare st text; msg text;
begin
  insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency,
                                      review_date, created_by, freq_times, freq_period, window_start, window_end)
  values (pg_temp.org(), pg_temp.c(p_case), pg_temp.ta(), 'Synth Leistung ' || p_category, p_category, 20, 'täglich',
          current_date + 90, pg_temp.u('n1'), 1, 'day', p_start, p_end);
  return null;
exception when others then
  get stacked diagnostics st = returned_sqlstate, msg = message_text;
  return st || ' ' || msg;
end $$;
-- Future generated visits of a case, by responsible member ('open' for none).
create function pg_temp.who(p_case int) returns text language sql stable as $$
  select coalesce(string_agg(distinct x.w, ',' order by x.w), '')
  from (select case when v.responsible_user_id is null then 'open' when v.responsible_user_id = pg_temp.u('n1') then 'n1'
                    when v.responsible_user_id = pg_temp.u('m1') then 'm1' else 'other' end as w
        from public.care_visits v
        where v.case_id = pg_temp.c(p_case) and v.plan_generated and v.status = 'planned') x $$;
create function pg_temp.refused(p_sql text) returns text language plpgsql as $$
declare st text; msg text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics st = returned_sqlstate, msg = message_text;
  return st || ' ' || msg;
end $$;
create function pg_temp.n(p_case int) returns int language sql stable as $$
  select count(*)::int from public.care_visits v where v.case_id = pg_temp.c(p_case) and v.plan_generated $$;

-- Fixtures (as the table owner) -----------------------------------------------------------------------------------------------
insert into public.organizations (id, name, simulation) values (pg_temp.org(), 'Synthetische Simulation QUAL1 Serie', true);
insert into auth.users (id, email) select pg_temp.u(n), 'qual1s-' || n || '@navora.test' from unnest(array['n1', 'm1']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['n1', 'm1']) n;
insert into public.teams (organization_id, id, name, region, status)
values (pg_temp.org(), pg_temp.ta(), 'Synth Station A (QUAL1 Serie)', 'Basel', 'active');
insert into public.team_memberships (team_id, user_id, qualification)
values (pg_temp.ta(), pg_temp.u('n1'), 'registered_nurse'), (pg_temp.ta(), pg_temp.u('m1'), 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, valid_until)
values (pg_temp.org(), pg_temp.u('n1'), 'grade', 'nurse_hf_fh', 'verified', null),
       (pg_temp.org(), pg_temp.u('n1'), 'practice_licence', null, 'verified', null),
       (pg_temp.org(), pg_temp.u('m1'), 'grade', 'fage_efz', 'verified', null);
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id,
                          primary_nurse_id, deputy_nurse_id, needs_assessment_done_at, medical_order_status)
values (pg_temp.org(), pg_temp.c(1), 'Synth K1', 'Synth', 'K1', 'Basel', 'laufend', 'mittel', pg_temp.ta(), pg_temp.u('m1'), pg_temp.u('n1'), now(), 'present'),
       (pg_temp.org(), pg_temp.c(2), 'Synth K2', 'Synth', 'K2', 'Basel', 'laufend', 'mittel', pg_temp.ta(), pg_temp.u('m1'), null, now(), 'present'),
       (pg_temp.org(), pg_temp.c(3), 'Synth K3', 'Synth', 'K3', 'Basel', 'laufend', 'mittel', pg_temp.ta(), pg_temp.u('n1'), null, now(), 'present'),
       (pg_temp.org(), pg_temp.c(4), 'Synth K4', 'Synth', 'K4', 'Basel', 'laufend', 'mittel', pg_temp.ta(), pg_temp.u('m1'), null, now(), 'present');

-- 1. Outside the simulation the series is unchanged (QUAL1-1, CGR-145 (e)) -----------------------------------------------------
select is((select count(*)::int
           from public.care_visits v join public.organizations o on o.id = v.organization_id and not o.simulation
           where private.qual_plan2_who(v.id, v.team_id, v.responsible_user_id, null) is distinct from v.responsible_user_id
              or private.qual_plan2_who(v.id, v.team_id, v.responsible_user_id, pg_temp.u('n1')) is distinct from v.responsible_user_id),
  0, 'QUAL1-1: outside a simulation organisation the series keeps the member the J3 rule chose, for every seed visit');
select ok((select count(*) from public.care_visits v join public.organizations o on o.id = v.organization_id and not o.simulation) > 0,
  'QUAL1-1: the seed has visits outside the simulation to compare (the test above is not empty)');
select ok((select p.prosrc like '%QUAL1-10 PLAN2%' from pg_proc p where p.oid = 'private.generate_case_plan(uuid, uuid)'::regprocedure),
  'QUAL1-10: the PLAN2 series asks the one decision function (marker present)');

-- 2. A refused primary nurse no longer breaks the series ----------------------------------------------------------------------
select is(pg_temp.add_item(1, 'A', '08:00', '08:30'), null,
  'QUAL1-10: a category A item for a case whose primary nurse (FaGe) the check refuses is saved, the series generated');
select ok(pg_temp.n(1) > 0, 'K1: the series has visits');
select is(pg_temp.who(1), 'n1', 'K1: every generated visit names the deputy (HF/FH), whom the check confirms for A1');
select is(pg_temp.add_item(2, 'A', '08:00', '08:30'), null, 'K2: saved although neither primary nor deputy may do it');
select ok(pg_temp.n(2) > 0, 'K2: the series has visits');
select is(pg_temp.who(2), 'open', 'K2: every generated visit stays open in the team (the PLAN2 "nobody" outcome), never m1');
select is(pg_temp.refused(format(
  'update public.care_visits set responsible_user_id = %L where id = (select id from public.care_visits where case_id = %L '
  'and plan_generated order by visit_date limit 1)', pg_temp.u('m1'), pg_temp.c(2))), '42501 qualification_not_allowed',
  'K2: naming m1 by hand is still refused by the 0121 backstop (unchanged, no override)');
select is(pg_temp.add_item(3, 'A', '08:00', '08:30'), null, 'K3: saved');
select is(pg_temp.who(3), 'n1', 'control: the HF/FH primary nurse is named as before');
select is(pg_temp.add_item(4, 'C', '09:00', '10:00'), null, 'K4: a category C item is saved');
select is(pg_temp.who(4), 'm1', 'control: the FaGe primary nurse is named where the check confirms the activity (C1)');

-- 3. Regeneration (the update path) and no churn --------------------------------------------------------------------------------
select is(pg_temp.add_item(4, 'A', '09:00', '10:00'), null,
  'K4: adding an A item to the same window regenerates the visits (A and C minutes) without an error');
select ok((select count(*) from public.visit_plan_changes x where x.case_id = pg_temp.c(4) and x.change = 'regenerated') > 0,
  'K4: the existing visits were regenerated in place (the update path), not dropped and recreated');
select is(pg_temp.who(4), 'open', 'K4: the regenerated visits are open: m1 is not confirmed for A1 and there is no deputy');
select is((private.generate_case_plan(pg_temp.c(1), private.plan_system_actor()) ->> 'regenerated')::int, 0,
  'no churn: a second run regenerates nothing (the compared member is the one the check confirms)');

select * from finish();
rollback;
