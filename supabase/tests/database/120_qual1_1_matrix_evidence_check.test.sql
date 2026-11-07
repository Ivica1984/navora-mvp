-- QUAL1 part 1 (brief docs/agents/briefs/QUAL1.md, migration 0120, ADR-163): matrix as versioned data, evidence states,
-- delegation record and the one decision function `private.qual_check` / `private.qual_may_perform`.
-- Simulation · synthetische Daten · Regeln PROPOSED (QUAL1-14): every name, grade and evidence row below is synthetic
-- and created by this file (QUAL1-12: own fixture, not the seed people). Passing it is NOT a clinical release (CGR-145).
-- Not yet here (QUAL1 part 2): the check on each assignment path and at visit start (QUAL1-10, -17), S1-S8 e2e.
--
-- Fixture: organisation SIM (simulation = true), team A, team B. Case K1, K2 (team A).
--   n1  nurse_hf_fh verified, practice licence verified          (delegator)
--   n2  nurse_hf_fh verified, practice licence verified          (supervisor)
--   n3  nurse_hf_fh verified, practice licence EXPIRED           (lapsed delegator, NT-8)
--   n4  nurse_hf_fh verified until exactly V1's end              (QUAL1-4 boundary minute)
--   n5  nurse_hf_fh verified until V1's end + 1 minute, licence  (just covers)
--   m2  fage_efz verified; delegations B3 + B7 for K1            (matrix §7 M2, S1)
--   m3  fage_efz verified; B3 for K1, B7 for K1 ended yesterday  (M3, S3b)
--   m4  fage_efz self_confirmed only                             (M4, S2)
--   m5  ags_eba verified                                         (M5)
--   m7  fage_efz verified + a second record ags_eba              (NT-6 contradictory)
--   m8  fage_efz verified; B3 for K1 from n3                     (NT-8)
--   o1  nurse_hf_fh verified, team B only                        (QUAL1-16 RLS)
-- Visits on day D = T+2: V1 K1 09:00-09:30 {C1, B3, B7}; V4 K1 {B4I}; V5 K1 needs assessment, no activity row (A1);
-- V6 K1 KLV-B minutes, no activity row (B13); V8 K2 {B3}. Outside the simulation: VL in Testorganisation A (…011),
-- team Nord (…101), case 208, KLV-B minutes; la (care_assistant), lr (registered_nurse).
begin;
create extension if not exists pgtap with schema extensions;

select plan(51);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;
create function pg_temp.at(p_day date, p_time time) returns timestamptz language sql stable as $$
  select (p_day + p_time) at time zone 'Europe/Zurich' $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select ('a1200000-0000-4000-a000-0000000000' || case n
           when 'n1' then '01' when 'n2' then '02' when 'n3' then '03' when 'n4' then '04' when 'n5' then '05'
           when 'm2' then '12' when 'm3' then '13' when 'm4' then '14' when 'm5' then '15' when 'm7' then '17'
           when 'm8' then '18' when 'o1' then '21' when 'la' then '31' when 'lr' then '32' end)::uuid $$;
create function pg_temp.org() returns uuid language sql immutable as $$ select 'a1200000-0000-4000-b000-000000000001'::uuid $$;
create function pg_temp.lorg() returns uuid language sql immutable as $$ select '00000000-0000-4000-b000-000000000011'::uuid $$;
create function pg_temp.ta() returns uuid language sql immutable as $$ select 'a1200000-0000-4000-a000-000000000011'::uuid $$;
create function pg_temp.tb() returns uuid language sql immutable as $$ select 'a1200000-0000-4000-a000-000000000012'::uuid $$;
create function pg_temp.c(n int) returns uuid language sql immutable as $$
  select ('a1200000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a1200000-0000-4000-d000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a1201000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.count_as(p_user text, p_sql text) returns integer language plpgsql as $$
declare n integer;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select count(*) from (%s) x', p_sql) into n;
  execute 'reset role';
  return n;
end $$;
-- "activity=result" per activity, in matrix order (no client datum).
create function pg_temp.chk(p_visit int, p_user text) returns text language sql stable as $$
  select string_agg(coalesce(c.activity_code, '-') || '=' || c.result, ',' order by q.sort nulls first)
  from private.qual_check(pg_temp.v(p_visit), pg_temp.u(p_user)) c
  left join public.qual_activities q on q.code = c.activity_code $$;
create function pg_temp.may(p_visit int, p_user text) returns boolean language sql stable as $$
  select private.qual_may_perform(pg_temp.v(p_visit), pg_temp.u(p_user)) $$;
create function pg_temp.deleg(p_by text, p_case int, p_act text, p_to text, p_sup text, p_key int) returns text language sql as $$
  select pg_temp.res(p_by, format('select public.record_delegation(%L, %L, %L, %L, %L, %L, %L, %L, null, %L)',
    pg_temp.ta(), pg_temp.c(p_case), p_act, pg_temp.u(p_to), pg_temp.u(p_sup), pg_temp.t() - 1, pg_temp.t(),
    pg_temp.t() + 30, pg_temp.k(p_key))) $$;

-- Fixtures (as the table owner, before any request claim is set) ---------------------------------------------------------------
insert into public.organizations (id, name, simulation) values (pg_temp.org(), 'Synthetische Simulation QUAL1', true);
insert into auth.users (id, email)
select pg_temp.u(n), 'qual1-' || n || '@navora.test'
from unnest(array['n1', 'n2', 'n3', 'n4', 'n5', 'm2', 'm3', 'm4', 'm5', 'm7', 'm8', 'o1', 'la', 'lr']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select pg_temp.org(), pg_temp.u(n), 'nurse'
from unnest(array['n1', 'n2', 'n3', 'n4', 'n5', 'm2', 'm3', 'm4', 'm5', 'm7', 'm8', 'o1']) n
union all select pg_temp.lorg(), pg_temp.u(n), 'nurse' from unnest(array['la', 'lr']) n;
insert into public.teams (organization_id, id, name, region, status)
values (pg_temp.org(), pg_temp.ta(), 'Synth Station A (QUAL1)', 'Basel', 'active'),
       (pg_temp.org(), pg_temp.tb(), 'Synth Team B (QUAL1)', 'Basel', 'active');
-- The old column stays as it is (CR-007 outside the simulation); in the simulation the matrix decides.
insert into public.team_memberships (team_id, user_id, qualification)
select pg_temp.ta(), pg_temp.u(n), case when n like 'n%' then 'registered_nurse' else 'care_assistant' end
from unnest(array['n1', 'n2', 'n3', 'n4', 'n5', 'm2', 'm3', 'm4', 'm5', 'm7', 'm8']) n
union all select pg_temp.tb(), pg_temp.u('o1'), 'registered_nurse'
union all select '00000000-0000-4000-a000-000000000101', pg_temp.u('la'), 'care_assistant'
union all select '00000000-0000-4000-a000-000000000101', pg_temp.u('lr'), 'registered_nurse';
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team_id, primary_nurse_id)
values (pg_temp.org(), pg_temp.c(1), 'Synth Bewohnerin K1', 'Synth', 'K1', 'Basel', 'laufend', 'mittel', pg_temp.ta(), pg_temp.u('n1')),
       (pg_temp.org(), pg_temp.c(2), 'Synth Bewohnerin K2', 'Synth', 'K2', 'Basel', 'laufend', 'mittel', pg_temp.ta(), pg_temp.u('n1'));
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status,
                                planned_minutes_a, planned_minutes_b, is_needs_assessment)
values (pg_temp.v(1), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '09:00', '09:30', 'planned', 0, 0, false),
       (pg_temp.v(4), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '11:00', '11:15', 'planned', 0, 0, false),
       (pg_temp.v(5), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '13:00', '14:00', 'planned', 0, 0, true),
       (pg_temp.v(6), pg_temp.org(), pg_temp.c(1), pg_temp.ta(), pg_temp.t() + 2, '15:00', '15:20', 'planned', 0, 20, false),
       (pg_temp.v(8), pg_temp.org(), pg_temp.c(2), pg_temp.ta(), pg_temp.t() + 2, '16:00', '16:15', 'planned', 0, 0, false),
       (pg_temp.v(9), pg_temp.lorg(), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        pg_temp.t() + 2, '17:00', '17:20', 'planned', 0, 20, false);
insert into public.visit_activities (organization_id, visit_id, activity_code)
values (pg_temp.org(), pg_temp.v(1), 'C1'), (pg_temp.org(), pg_temp.v(1), 'B3'), (pg_temp.org(), pg_temp.v(1), 'B7'),
       (pg_temp.org(), pg_temp.v(4), 'B4I'), (pg_temp.org(), pg_temp.v(8), 'B3');
-- Evidence ("verified (synthetisch)": fixture rows only, QUAL1-2).
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, valid_until)
select pg_temp.org(), pg_temp.u(n), 'grade', g, 'verified', null
from (values ('n1', 'nurse_hf_fh'), ('n2', 'nurse_hf_fh'), ('n3', 'nurse_hf_fh'), ('m2', 'fage_efz'), ('m3', 'fage_efz'),
             ('m5', 'ags_eba'), ('m7', 'fage_efz'), ('m8', 'fage_efz'), ('o1', 'nurse_hf_fh')) x (n, g);
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, valid_until)
values (pg_temp.org(), pg_temp.u('n4'), 'grade', 'nurse_hf_fh', 'verified', pg_temp.at(pg_temp.t() + 2, '09:30')),
       (pg_temp.org(), pg_temp.u('n5'), 'grade', 'nurse_hf_fh', 'verified', pg_temp.at(pg_temp.t() + 2, '09:31'));
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, valid_until)
select pg_temp.org(), pg_temp.u(n), 'practice_licence', null, 'verified',
       case n when 'n3' then pg_temp.at(pg_temp.t(), '09:00') end
from unnest(array['n1', 'n2', 'n3', 'n4', 'n5', 'o1']) n;
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, recorded_by)
values (pg_temp.org(), pg_temp.u('m4'), 'grade', 'fage_efz', 'self_confirmed', true, pg_temp.u('m4')),
       (pg_temp.org(), pg_temp.u('m7'), 'grade', 'ags_eba', 'self_confirmed', true, pg_temp.u('m7'));
-- Delegations recorded earlier (fixture), for case K1.
insert into public.qual_delegations (organization_id, team_id, case_id, activity_code, delegate_id, delegator_id, supervisor_id,
                                     matrix_version, instructed_on, valid_from, valid_until)
select pg_temp.org(), pg_temp.ta(), pg_temp.c(1), x.act, pg_temp.u(x.dlg), pg_temp.u(x.byn), pg_temp.u('n2'), 'QAM-0.2',
       pg_temp.t() - 20, pg_temp.t() - 20, x.until
from (values ('B3', 'm2', 'n1', pg_temp.t() + 30), ('B7', 'm2', 'n1', pg_temp.t() + 30),
             ('B3', 'm3', 'n1', pg_temp.t() + 30), ('B7', 'm3', 'n1', pg_temp.t() - 1),
             ('B3', 'm8', 'n3', pg_temp.t() + 30)) x (act, dlg, byn, until);

-- QUAL1-7 The matrix as versioned data --------------------------------------------------------------------------------------
select is(private.qual_matrix_version(), 'QAM-0.2', 'QUAL1-7: the version in use is QAM v0.2');
select is((select count(*)::int from public.qual_matrix_cells where version = 'QAM-0.2'), 115,
  'QUAL1-7: one cell per activity (23) and grade (5)');
select is((select count(*)::int from public.qual_matrix_cells where status <> 'PROPOSED')
          + (select count(*)::int from public.qual_matrix_versions where status <> 'PROPOSED'), 0,
  'QUAL1-7: every cell and the version are PROPOSED in Phase A');
select throws_ok($$ update public.qual_matrix_cells set value = 'E' where activity_code = 'B4I' and grade = 'fage_efz' $$,
  '42501', null, 'QUAL1-7: a cell is never changed in place, even by the owner (a change is a new version)');

-- QUAL1-8 / matrix §7: the decision per member ------------------------------------------------------------------------------
select is(pg_temp.chk(1, 'n1'), 'B3=allowed_own,B7=allowed_own,C1=allowed_own', 'S1/AK-2: HF/FH, own scope for C1, B3, B7');
select ok(pg_temp.may(1, 'n1'), 'S1/AK-2: HF/FH may be responsible');
select is(pg_temp.chk(1, 'm2'), 'B3=allowed_delegated,B7=allowed_delegated,C1=allowed_own',
  'S1/AK-2: FaGe with valid delegations for B3 and B7 of this case');
select ok(pg_temp.may(1, 'm2'), 'S1/AK-2: FaGe with valid delegations may be responsible');
select is((select string_agg(c.label, ',' order by c.activity_code) from private.qual_check(pg_temp.v(1), pg_temp.u('m2')) c),
  'geeignet_mit_delegation,geeignet_mit_delegation,geeignet', 'CR-183: the labels geeignet / geeignet mit Delegation');
select is((select max(c.delegation_until) from private.qual_check(pg_temp.v(1), pg_temp.u('m2')) c), pg_temp.t() + 30,
  'S1: the delegation''s end date comes with the result ("gültig bis")');
select is(pg_temp.chk(1, 'm3'), 'B3=allowed_delegated,B7=delegation_expired,C1=allowed_own',
  'S3b/AK-3/NT-2: the B7 delegation ended yesterday');
select ok(not pg_temp.may(1, 'm3'), 'S3b: not suitable with one expired delegation');
select is(pg_temp.chk(1, 'm4'), 'B3=evidence_missing,B7=evidence_missing,C1=evidence_missing',
  'S2/AK-3/NT-1: a self-confirmed grade is no evidence');
select is((select min(c.reason) from private.qual_check(pg_temp.v(1), pg_temp.u('m4')) c), 'grade:self_confirmed',
  'S2: the reason names the self-confirmed grade ("Nachweis fehlt: Ausbildung")');
select is(pg_temp.chk(1, 'm5'), 'B3=not_allowed,B7=not_allowed,C1=allowed_own', 'AK-3: AGS, B3 and B7 not in her scope');
select is((select string_agg(distinct c.label, ',') from private.qual_check(pg_temp.v(1), pg_temp.u('m5')) c
           where c.activity_code in ('B3', 'B7')), 'nicht_geeignet', 'CR-183: nicht geeignet');
select is(pg_temp.chk(1, 'm7'), 'B3=evidence_contradictory,B7=evidence_contradictory,C1=evidence_contradictory',
  'QUAL1-5/NT-6: two grade records disagree: contradictory, nothing resolved automatically');
select is(pg_temp.chk(1, 'm8'), 'B3=delegation_review_needed,B7=delegation_missing,C1=allowed_own',
  'NT-8: the delegator''s licence lapsed: her delegation needs review and does not count');
select is((select count(*)::int from public.qual_delegations where delegator_id = pg_temp.u('n3')), 1,
  'NT-8: nothing is deleted');
select is(pg_temp.chk(4, 'm2'), 'B4I=unresolved', 'S4/NT-3: insulin is "?" for FaGe (K-2)');
select is((select c.reason from private.qual_check(pg_temp.v(4), pg_temp.u('m2')) c), 'cell:?:K-2',
  'S4: the reason names the open question');
select is((select c.label from private.qual_check(pg_temp.v(4), pg_temp.u('m2')) c), 'ungeklaert',
  'CR-183: "?" is ungeklärt, never suitable');
select is(pg_temp.chk(4, 'n1'), 'B4I=allowed_own', 'S4: only HF/FH candidates remain');
select is(pg_temp.chk(8, 'm2'), 'B3=delegation_missing', 'NT-7: a delegation for another case does not count');

-- QUAL1-6 Fallbacks for visits without an activity row -------------------------------------------------------------------------
select is(pg_temp.chk(5, 'n1'), 'A1=allowed_own', 'QUAL1-6: a needs assessment counts as A1; HF/FH with licence');
select is(pg_temp.chk(5, 'm2'), 'A1=not_allowed', 'QUAL1-6: A1 is never delegable to FaGe');
select is(pg_temp.chk(6, 'm2'), 'B13=unresolved', 'QUAL1-6: KLV-B minutes without an activity count as B13 ("?" for FaGe)');

-- QUAL1-4 Expiry from the instant (test clock) ------------------------------------------------------------------------------
select is(pg_temp.chk(1, 'n4'), 'B3=evidence_expired,B7=evidence_expired,C1=evidence_expired',
  'QUAL1-4/S8: evidence ending exactly at the visit''s end does not cover it');
select is(pg_temp.chk(1, 'n5'), 'B3=allowed_own,B7=allowed_own,C1=allowed_own',
  'QUAL1-4: evidence ending one minute after the visit covers it');

-- QUAL1-9 / CR-176a / QUAL1-16 Delegation record --------------------------------------------------------------------------
select is(pg_temp.deleg('m2', 1, 'B7', 'm3', 'n2', 1), 'not_allowed_to_delegate', 'QUAL1-16: a fage_efz cannot delegate');
select is(pg_temp.deleg('n3', 1, 'B7', 'm3', 'n2', 2), 'not_allowed_to_delegate',
  'QUAL1-9: a nurse with a lapsed practice licence cannot delegate');
select is(pg_temp.deleg('n1', 1, 'B3', 'm5', 'n2', 3), 'activity_not_delegable',
  'CR-176a: B3 is "-" for AGS: no delegation can be recorded');
select is(pg_temp.deleg('n1', 1, 'B4I', 'm2', 'n2', 4), 'activity_not_delegable',
  'CR-176a: a "?" cell is never delegable');
select is(pg_temp.deleg('n1', 1, 'B7', 'm4', 'n2', 5), 'delegate_evidence_self_confirmed',
  'QUAL1-9: no delegation to a member without verified evidence');
select is(pg_temp.deleg('n1', 1, 'B7', 'm3', 'n3', 6), 'supervisor_not_qualified',
  'QUAL1-9: the supervising nurse must meet the same test');
select is(pg_temp.deleg('n1', 1, 'B7', 'm3', 'n2', 7), 'ok', 'S3a: a verified HF/FH records the B7 delegation (a human act)');
select is(pg_temp.deleg('n1', 1, 'B7', 'm3', 'n2', 7), 'duplicate', 'the same idempotency key is a duplicate');
select ok(pg_temp.may(1, 'm3'), 'S3a: with the new delegation M3 may be responsible');
select is((select count(*)::int from public.audit_events a where a.table_name = 'qual_delegations'
           and a.command = 'record_delegation' and a.actor_id = pg_temp.u('n1')), 1,
  'QUAL1-15/AK-10: the delegation is in the audit trail');
select is(pg_temp.res('m2', format('select public.revoke_delegation(%L, %L)',
            (select id from public.qual_delegations where delegate_id = pg_temp.u('m3') and activity_code = 'B7'
             order by seq desc limit 1), pg_temp.k(8))), 'rejected', 'only the delegating or supervising nurse or F4 revoke');
select is(pg_temp.res('n2', format('select public.revoke_delegation(%L, %L)',
            (select id from public.qual_delegations where delegate_id = pg_temp.u('m3') and activity_code = 'B7'
             order by seq desc limit 1), pg_temp.k(9))), 'ok', 'AK-6: the supervising nurse revokes it');
select ok(not pg_temp.may(1, 'm3'), 'AK-6: after the revocation M3 is not suitable again');

-- QUAL1-3 / QUAL1-16 Nobody but a fixture sets "verified" ---------------------------------------------------------------------
select is(pg_temp.cmd('m4', format('select public.confirm_my_qualification(%L, %L, %L, %L)', pg_temp.org(), 'grade',
            'fage_efz', pg_temp.k(10))) ->> 'state', 'self_confirmed', 'QUAL1-3: the member''s confirmation is self_confirmed');
select throws_ok(format($$ insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state)
                           values (%L, %L, 'grade', 'fage_efz', 'verified') $$, pg_temp.org(), pg_temp.u('m4')),
  '42501', null, 'QUAL1-3: inside a user request nothing may write verified evidence, not even the owner role');
-- Without a request claim (as a fixture would run), but inside a command, or outside a simulation organisation: refused too.
select set_config('request.jwt.claims', '', true), set_config('request.jwt.claim.sub', '', true);
select set_config('navora.command', 'qual1_test', true);
select throws_ok(format($$ insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state)
                           values (%L, %L, 'grade', 'fage_efz', 'verified') $$, pg_temp.org(), pg_temp.u('m4')),
  '42501', 'no app user, command or agent may record verified evidence (QUAL1-3, D-29)',
  'QUAL1-3/NT-10: no command (and so no agent path) writes verified evidence');
select set_config('navora.command', '', true);
select throws_ok(format($$ insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state)
                           values (%L, %L, 'grade', 'fage_efz', 'verified') $$, pg_temp.lorg(), pg_temp.u('la')),
  '42501', 'verified evidence exists only as a synthetic fixture in a simulation organisation (Phase A, D-29)',
  'QUAL1-1/D-29: no verified evidence outside a simulation organisation, not even as a fixture');
select is(pg_temp.count_as('o1', format('select 1 from public.qual_delegations where team_id = %L', pg_temp.ta()))
          + pg_temp.count_as('o1', format('select 1 from public.visit_qualification_check(%L, %L)', pg_temp.v(1), pg_temp.u('m2'))),
  0, 'QUAL1-16: a member of another team reads neither the delegations nor the check');
select is(private.aig1_prohibited_target('qual_delegations', 'valid_until'), 'qualification',
  'QUAL1-9: no agent may aim at a delegation (AIG1 prohibited target)');

-- QUAL1-1 Outside the simulation the old rule holds, unchanged ------------------------------------------------------------
select is(array[private.qual_may_perform(pg_temp.v(9), pg_temp.u('la')), private.qual_may_perform(pg_temp.v(9), pg_temp.u('lr'))],
          array[false, true],
  'QUAL1-1/CGR-145 (e): outside a simulation organisation CR-007 holds: KLV-B only for a registered nurse');
select is(array[private.qual_may_perform(pg_temp.v(9), pg_temp.u('la')), private.qual_may_perform(pg_temp.v(9), pg_temp.u('lr'))],
          array[private.may_perform_visit('00000000-0000-4000-a000-000000000101', pg_temp.u('la'), 20, false),
                private.may_perform_visit('00000000-0000-4000-a000-000000000101', pg_temp.u('lr'), 20, false)],
  'QUAL1-1: outside a simulation organisation the answer is private.may_perform_visit''s, unchanged');
select is((select count(*)::int from public.visit_qualification_check(pg_temp.v(9), pg_temp.u('lr'))), 0,
  'QUAL1-1: no matrix check is reported outside a simulation organisation');

select * from finish();
rollback;
