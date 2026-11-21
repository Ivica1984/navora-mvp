-- QUAL1 part 2, slice 1 (brief docs/agents/briefs/QUAL1.md QUAL1-10, QUAL1-17; migration 0121, ADR-164): the one decision
-- function on every assignment path, the backstop on `care_visits`, activities added later, and the check at visit start.
-- Simulation · synthetische Daten · Regeln PROPOSED (QUAL1-14): every name, grade and evidence row below is synthetic and
-- created by this file (QUAL1-12: own fixture, not the seed people). Passing it is NOT a clinical release (CGR-145).
--
-- Fixture: organisation SIM (simulation = true), team A, cover team B. Case K1 (team A).
--   n1  nurse_hf_fh verified, practice licence verified (delegator)     n2  same (supervisor)
--   m2  fage_efz verified; B3 delegation for K1 (S1)                    m4  fage_efz self_confirmed only (S2)
--   m5  ags_eba verified (B3 not in scope)                              b1  fage_efz verified, cover team B only
-- Visits: V1 T+2 {C1, B3}; V2 T+2 {B4I}; V3 T+2 {C1}; V6 T+2 {C1, B3} open (take); V7 today 10:30 {B3}, m2 responsible
-- (start, QUAL1-17); V8 today 11:00 {C1}, n1 responsible (start, control).
begin;
create extension if not exists pgtap with schema extensions;

select plan(33);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select ('a1210000-0000-4000-a000-0000000000' || case n
           when 'n1' then '01' when 'n2' then '02' when 'm2' then '12' when 'm4' then '14' when 'm5' then '15'
           when 'b1' then '21' end)::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select 'a1210000-0000-4000-b000-000000000001'::uuid $$;
create function pg_temp.ta() returns uuid language sql immutable as $$ select 'a1210000-0000-4000-a000-000000000011'::uuid $$;
create function pg_temp.tb() returns uuid language sql immutable as $$ select 'a1210000-0000-4000-a000-000000000012'::uuid $$;
create function pg_temp.c(n int) returns uuid language sql immutable as $$
  select ('a1210000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1210000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1211000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.res(p_user text, p_sql text) returns text language sql as $$
  select coalesce(r ->> 'result', r #>> '{}') from (select pg_temp.cmd(p_user, p_sql) as r) s $$;
-- The refusal of a statement as "<sqlstate> <message> | <detail>" (null when it runs), run as p_user (null: owner).
create function pg_temp.refusal(p_user text, p_sql text) returns text language plpgsql as $$
declare st text; msg text; det text;
begin
  if p_user is null then perform pg_temp.as_owner(); else perform pg_temp.act_as(pg_temp.u(p_user)::text); end if;
  begin
    if p_user is not null then execute 'set local role authenticated'; end if;
    execute p_sql;
    execute 'reset role';
    return null;
  exception when others then
    get stacked diagnostics st = returned_sqlstate, msg = message_text, det = pg_exception_detail;
    execute 'reset role';
    return st || ' ' || msg || ' | ' || coalesce(det, '');
  end;
end $$;
create function pg_temp.resp(p_visit int, p_user text) returns text language sql as $$
  select pg_temp.refusal(null, format('update public.care_visits set responsible_user_id = %L where id = %L',
                                      pg_temp.u(p_user), pg_temp.v(p_visit))) $$;

-- Fixtures (as the table owner) -----------------------------------------------------------------------------------------------
insert into public.organizations (id, name, simulation) values (pg_temp.org(), 'Synthetische Simulation QUAL1 Teil 2', true);
insert into auth.users (id, email)
select pg_temp.u(n), 'qual1b-' || n || '@navora.test' from unnest(array['n1', 'n2', 'm2', 'm4', 'm5', 'b1']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['n1', 'n2', 'm2', 'm4', 'm5', 'b1']) n;
insert into public.teams (organization_id, id, name, region, status)
values (pg_temp.org(), pg_temp.ta(), 'Synth Station A (QUAL1 Teil 2)', 'Basel', 'active'),
       (pg_temp.org(), pg_temp.tb(), 'Synth Team B (QUAL1 Teil 2)', 'Basel', 'active');
insert into public.team_memberships (team_id, user_id, qualification)
select pg_temp.ta(), pg_temp.u(n), case when n like 'n%' then 'registered_nurse' else 'care_assistant' end
from unnest(array['n1', 'n2', 'm2', 'm4', 'm5']) n
union all select pg_temp.tb(), pg_temp.u('b1'), 'care_assistant';
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id, primary_nurse_id)
values (pg_temp.org(), pg_temp.c(1), 'Synth Bewohnerin K1', 'Synth', 'K1', 'Basel', 'laufend', 'mittel', pg_temp.ta(), pg_temp.u('n1'));
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b, is_needs_assessment)
values (pg_temp.v(1), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '09:00', '09:30', 'planned', 0, 0, false),
       (pg_temp.v(2), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '11:00', '11:15', 'planned', 0, 0, false),
       (pg_temp.v(3), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '13:00', '13:20', 'planned', 0, 0, false),
       (pg_temp.v(6), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '15:00', '15:30', 'planned', 0, 0, false),
       (pg_temp.v(7), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t(), '10:30', '11:00', 'planned', 0, 0, false),
       (pg_temp.v(8), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t(), '11:00', '11:20', 'planned', 0, 0, false);
insert into public.visit_activities (organization_id, visit_id, activity_code)
values (pg_temp.org(), pg_temp.v(1), 'C1'), (pg_temp.org(), pg_temp.v(1), 'B3'), (pg_temp.org(), pg_temp.v(2), 'B4I'),
       (pg_temp.org(), pg_temp.v(3), 'C1'), (pg_temp.org(), pg_temp.v(6), 'C1'), (pg_temp.org(), pg_temp.v(6), 'B3'),
       (pg_temp.org(), pg_temp.v(7), 'B3'), (pg_temp.org(), pg_temp.v(8), 'C1');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, valid_until)
select pg_temp.org(), pg_temp.u(n), 'grade', g, 'verified', null
from (values ('n1', 'nurse_hf_fh'), ('n2', 'nurse_hf_fh'), ('m2', 'fage_efz'), ('m5', 'ags_eba'), ('b1', 'fage_efz')) x (n, g);
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, valid_until)
select pg_temp.org(), pg_temp.u(n), 'practice_licence', null, 'verified', null from unnest(array['n1', 'n2']) n;
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, recorded_by)
values (pg_temp.org(), pg_temp.u('m4'), 'grade', 'fage_efz', 'self_confirmed', true, pg_temp.u('m4'));
insert into public.qual_delegations (organization_id, team_id, case_id, activity_code, delegate_id, delegator_id, supervisor_id,
                                     matrix_version, instructed_on, valid_from, valid_until)
values (pg_temp.org(), pg_temp.ta(), pg_temp.c(1), 'B3', pg_temp.u('m2'), pg_temp.u('n1'), pg_temp.u('n2'), 'QAM-0.2',
        pg_temp.t() - 20, pg_temp.t() - 20, pg_temp.t() + 30);

-- 1. Outside the simulation nothing changes (QUAL1-1, CGR-145 (e)) ---------------------------------------------------------------
select is((select count(*)::int
           from public.care_visits v
           join public.organizations o on o.id = v.organization_id and not o.simulation
           join public.team_memberships m on m.team_id = v.team_id
           where private.qual_may_perform_in(v.id, v.team_id, m.user_id)
                 is distinct from private.may_perform_visit(v.team_id, m.user_id, v.planned_minutes_b, v.is_needs_assessment)),
  0, 'QUAL1-1: outside a simulation organisation the answer is the old J3 rule, for every seed visit and team member');
select ok((select count(*) from public.care_visits v join public.organizations o on o.id = v.organization_id and not o.simulation) > 0,
  'QUAL1-1: the seed has visits outside the simulation to compare (the test above is not empty)');

-- 2. Every proposal and command path asks the one function (QUAL1-10) -------------------------------------------------------------
select is((select count(*)::int from pg_proc p
           where p.oid in ('public.take_open_visit(uuid, uuid, boolean)'::regprocedure, 'public.team_open_visits(date)'::regprocedure,
                           'public.change_absence(uuid, boolean, date, time without time zone, uuid)'::regprocedure,
                           'private.aig1_apply_visit_responsible(uuid, uuid, uuid, uuid)'::regprocedure,
                           'private.plan3_lines(uuid, date, boolean)'::regprocedure)
             and p.prosrc like '%private.qual_may_perform_in(%'), 5,
  'QUAL1-10: take, the open list, ABS1 re-assignment, the AIG1 confirm and the PLAN3 proposal ask qual_may_perform_in');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private')
             and p.prosrc ~ 'may_perform_visit\([^)]*planned_minutes_b'
             and p.oid <> 'private.qual_may_perform(uuid, uuid)'::regprocedure
             and p.oid <> 'private.qual_may_perform_in(uuid, uuid, uuid)'::regprocedure), 0,
  'QUAL1-10: no path asks the old visit rule directly any more (only the fallback inside the one function)');

-- 3. Backstop: the hand path (S1, S2, S4, S7) --------------------------------------------------------------------------------------
select is(pg_temp.resp(1, 'm4'), '42501 qualification_not_allowed | QUAL1-10: B3:ungeklaert:grade:self_confirmed',
  'S2/S7: a self-confirmed grade is refused as responsible; the system sees the activity, label and reason');
select is(pg_temp.resp(1, 'm5'), '42501 qualification_not_allowed | QUAL1-10: B3:nicht_geeignet:cell:-',
  'AK-3/S7: an AGS is refused for B3 (nicht geeignet)');
select is(pg_temp.resp(2, 'm2'), '42501 qualification_not_allowed | QUAL1-10: B4I:ungeklaert:cell:?:K-2',
  'S4/S7: insulin is "?" for FaGe: refused, never assignable');
create function pg_temp.detail_as(p_caller text, p_visit int, p_user text) returns text language plpgsql as $$
declare d text;
begin
  perform pg_temp.act_as(pg_temp.u(p_caller)::text);
  d := private.qual_refusal_detail(pg_temp.v(p_visit), pg_temp.ta(), pg_temp.u(p_user));
  perform pg_temp.as_owner();
  return d;
end $$;
select is(pg_temp.detail_as('n1', 1, 'm4'), 'B3:ungeklaert',
  'CGR-152: a colleague sees the activity and the label, not the colleague''s evidence');
select is(pg_temp.resp(1, 'm2'), null, 'S1: FaGe with a valid B3 delegation for this case may be responsible');
select is(pg_temp.resp(2, 'n1'), null, 'S4: HF/FH may be responsible for the insulin visit');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(1)), pg_temp.u('m2'),
  'S1: the allowed assignment is written');
select is(pg_temp.refusal(null, format(
  'insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status, '
  'planned_minutes_a, planned_minutes_b, is_needs_assessment, responsible_user_id) values (%L, %L, %L, %L, %L, ''17:00'', '
  '''17:20'', ''planned'', 0, 20, false, %L)', pg_temp.v(9), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2,
  pg_temp.u('m4'))), '42501 qualification_not_allowed | QUAL1-10: B13:ungeklaert:grade:self_confirmed',
  'S7: a new visit (PLAN2 series, plan_visit) with a member who may not perform it is refused on insert');
select is(pg_temp.refusal(null, format('update public.care_visits set responsible_user_id = %L where id = %L',
                                       pg_temp.u('m2'), pg_temp.v(3))), null, 'control: C1 only, FaGe responsible');
select is(pg_temp.refusal(null, format('update public.care_visits set visit_date = visit_date + 1 where id = %L', pg_temp.v(1))),
  null, 'moving a visit re-checks the member: the delegation still covers T+3');
select is(pg_temp.refusal(null, format('update public.care_visits set visit_date = %L where id = %L', pg_temp.t() + 40, pg_temp.v(1))),
  '42501 qualification_not_allowed | QUAL1-10: B3:ungeklaert:delegation_ended',
  'moving the visit past the delegation''s end is refused (the member would no longer qualify)');
select is((select string_agg(l.label, ',') from (select private.qual_label('delegation_expired') as label) l), 'ungeklaert',
  'CR-183: an expired delegation is shown as ungeklärt');

-- 4. Cover by another team (QUAL1-10 cover) --------------------------------------------------------------------------------------
select is(pg_temp.refusal(null, format('update public.care_visits set cover_team_id = %L, covered_by = %L where id = %L',
                                       pg_temp.tb(), pg_temp.u('b1'), pg_temp.v(3))), null,
  'cover: a verified FaGe of the cover team covers a C1 visit');
select is(pg_temp.refusal(null, format('update public.care_visits set cover_team_id = %L, covered_by = %L where id = %L',
                                       pg_temp.tb(), pg_temp.u('b1'), pg_temp.v(1))),
  '42501 qualification_not_allowed | QUAL1-10: B3:ungeklaert:no_delegation',
  'cover/S3a: she has no B3 delegation for this case: refused (the delegation of the visit''s team never transfers)');
select is(pg_temp.refusal(null, format('update public.care_visits set cover_team_id = %L, covered_by = %L where id = %L',
                                       pg_temp.ta(), pg_temp.u('b1'), pg_temp.v(6))),
  '42501 qualification_not_allowed | QUAL1-10: membership_or_access',
  'cover: a member of another team is never set as covering for a team she is not in');

-- 5. Take and the open list (QUAL1-10, S7) ---------------------------------------------------------------------------------------
create function pg_temp.may_take(p_user text, p_visit int) returns boolean language plpgsql as $$
declare b boolean;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  select o.may_take into b from public.team_open_visits(null) o where o.visit_id = pg_temp.v(p_visit);
  execute 'reset role';
  return b;
end $$;
select is(pg_temp.may_take('m4', 6), false, 'S2: the open list does not offer "Übernehmen" to a self-confirmed FaGe');
select is(pg_temp.may_take('m2', 6), true, 'S1: the open list offers it to the FaGe with a valid delegation');
select is(pg_temp.res('m4', format('select public.take_open_visit(%L, %L)', pg_temp.v(6), pg_temp.k(1))), 'not_qualified',
  'S2/S7 take: a self-confirmed FaGe cannot take the visit');
select is(pg_temp.res('m5', format('select public.take_open_visit(%L, %L)', pg_temp.v(6), pg_temp.k(2))), 'not_qualified',
  'S7 take: an AGS cannot take a B3 visit');
select is((select responsible_user_id from public.care_visits where id = pg_temp.v(6)), null,
  'S7 take: nothing was written by the refused takes');
select is(pg_temp.res('m2', format('select public.take_open_visit(%L, %L)', pg_temp.v(6), pg_temp.k(3))), 'ok',
  'S1 take: FaGe with a valid delegation takes it');

-- 6. An activity added later (QUAL1-6 with QUAL1-10) -------------------------------------------------------------------------------
select is(pg_temp.refusal(null, format('insert into public.visit_activities (organization_id, visit_id, activity_code) '
                                       'values (%L, %L, ''B4I'')', pg_temp.org(), pg_temp.v(6))),
  '42501 qualification_not_allowed | QUAL1-10: B4I:ungeklaert:cell:?:K-2',
  'no bypass: adding insulin to a visit the FaGe holds is refused (release first)');
select is((select count(*)::int from public.visit_activities where visit_id = pg_temp.v(6)), 2,
  'the refused activity was not added');
select is(pg_temp.refusal(null, format('insert into public.visit_activities (organization_id, visit_id, activity_code) '
                                       'values (%L, %L, ''B3'')', pg_temp.org(), pg_temp.v(2))), null,
  'control: adding B3 to the HF/FH visit is accepted');

-- 7. Check at visit start (QUAL1-17, CGR-148) ---------------------------------------------------------------------------------------
select is(pg_temp.refusal(null, format('update public.care_visits set responsible_user_id = %L where id = %L',
                                       pg_temp.u('m2'), pg_temp.v(7))), null, 'QUAL1-17 setup: m2 planned for V7 today');
select is(pg_temp.res('n1', format('select public.revoke_delegation(%L, %L)',
  (select id from public.qual_delegations where delegate_id = pg_temp.u('m2') and activity_code = 'B3'), pg_temp.k(4))), 'ok',
  'QUAL1-17 setup: the delegating nurse revokes the B3 delegation after planning');
select is(pg_temp.refusal('m2', format('update public.care_visits set status = ''started'' where id = %L', pg_temp.v(7))),
  '42501 qualification_lapsed | QUAL1-17: B3:ungeklaert:no_delegation',
  'QUAL1-17/AK-6: the start is refused once the delegation lapsed; she sees her own reason');
select is((select status from public.care_visits where id = pg_temp.v(7)), 'planned', 'QUAL1-17: nothing was started');
select is(coalesce(pg_temp.refusal(null, format('update public.care_visits set responsible_user_id = %L where id = %L',
                                       pg_temp.u('n1'), pg_temp.v(8))), '') || '|' ||
          coalesce(pg_temp.refusal('n1', format('update public.care_visits set status = ''started'' where id = %L', pg_temp.v(8))), 'started'),
  '|started', 'control: HF/FH starts her C1 visit');

select * from finish();
rollback;
