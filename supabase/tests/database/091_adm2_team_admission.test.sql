-- ADM2 part (a): the team admits its colleagues; "Vertrag erfasst" is the employer's only step (migration 0091,
-- ADR-114). Brief `docs/agents/briefs/ADM2.md` ADM2-1 to ADM2-9.
-- Seed users: pflege …902 (RN, Nord, the proposer) · assist …906 (CA, Nord) · coach …901 · ops …904 · admin …905 (org A)
-- · fremd …903 (admin of org B). Synthetic users added here (all Nord unless stated): …9101 care assistant (added by
-- ADM1 while the switch is off) · …9102 Mitte nurse · …9103 Nord member whose access ended · …9104 joins Nord after
-- the proposals · …9105 the admitted candidate's hand-made account. Case …208 is Nord's. All data synthetic.
begin;
create extension if not exists pgtap with schema extensions;

select plan(83);

-- Pinned clock (DST1 pattern): 10:00 Zurich today.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                 when 'admin' then '00000000-0000-4000-a000-000000000905' when 'fremd' then '00000000-0000-4000-a000-000000000903'
                 when 'x1' then 'a0910000-0000-4000-a000-000000009101' when 'mitte' then 'a0910000-0000-4000-a000-000000009102'
                 when 'ended' then 'a0910000-0000-4000-a000-000000009103' when 'late' then 'a0910000-0000-4000-a000-000000009104'
                 when 'new' then 'a0910000-0000-4000-a000-000000009105' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0911000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
create function pg_temp.propose(p_user text, p_name text, k int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.propose_team_candidate(%L, %L, %L, %L, %L)',
    '00000000-0000-4000-a000-000000000101', p_name, 'care_assistant', '40-60', pg_temp.k(k))) $$;
create function pg_temp.decide(p_user text, p_prop uuid, p_dec text, p_reason text, k int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.decide_team_candidate(%L, %L, %L, %L)', p_prop, p_dec, p_reason, pg_temp.k(k))) $$;
create function pg_temp.nord(p_user text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.team_admissions(%L)', '00000000-0000-4000-a000-000000000101')) $$;
create function pg_temp.outcome(p uuid) returns text language sql as $$ select private.adm2_outcome(p)::text $$;
create temp table fx (name text primary key, id uuid);
grant all on fx to authenticated;

-- Synthetic accounts (as the table owner) ---------------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), 'adm2-' || n || '@navora.test' from unnest(array['x1', 'mitte', 'ended', 'late', 'new']) n;
create function pg_temp.mail(n text) returns text language sql stable as $$ select email from auth.users where id = pg_temp.u(n) $$;
insert into public.organization_memberships (organization_id, user_id, role)
select '00000000-0000-4000-b000-000000000011', pg_temp.u(n), 'nurse' from unnest(array['x1', 'mitte', 'ended', 'late']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('ended'), 'care_assistant');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('ended'), 'ended', 'employment_ended', pg_temp.u('admin'));

-- ADM2-1 Switch -------------------------------------------------------------------------------------------------------------
select is(pg_temp.propose('p', 'Kandidatin Aus', 1) ->> 'result', 'admission_off', 'ADM2-1: switch off by default: admission_off');
select is(pg_temp.res('admin', format('select public.add_team_member(%L, %L, %L, %L)', '00000000-0000-4000-a000-000000000101',
          pg_temp.u('x1'), 'care_assistant', pg_temp.k(2))), 'ok', 'ADM2-1: ADM1 add_team_member works with the switch off');
select is(pg_temp.res('p', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(3))),
          'rejected', 'ADM2-1: a nurse cannot switch it on');
select is(pg_temp.res('coach', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(4))),
          'rejected', 'ADM2-1: a coach cannot switch it on');
select is(pg_temp.res('admin', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(5))),
          'ok', 'ADM2-1: the administrator switches it on');
select ok(exists (select 1 from public.audit_events a where a.table_name = 'team_admission_settings'
                  and a.actor_id = pg_temp.u('admin') and a.command = 'set_team_admission'), 'ADM2-1: the switch is audited');
select is(pg_temp.res('admin', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(5))),
          'duplicate', 'ADM2-1: idempotent');
select is(pg_temp.res('fremd', format('select public.set_team_admission(%L, false, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(6))),
          'rejected', 'ADM2-1: an administrator of another organisation cannot switch it');

-- ADM2-2 Proposal ------------------------------------------------------------------------------------------------------------
select is((select string_agg(column_name::text, ',' order by column_name::text collate "C") from information_schema.columns
           where table_schema = 'public' and table_name = 'team_candidates'),
  'claimed_qualification,display_name,id,organization_id,pensum_band,proposal_id,team_id',
  'ADM2-2: the candidate record has exactly the three fields plus its keys (no e-mail, phone, address, birth date, pay, health, free text)');
select is(pg_temp.propose('mitte', 'Kandidatin X', 10) ->> 'result', 'rejected', 'ADM2-2: a member of another team cannot propose');
select is(pg_temp.propose('coach', 'Kandidatin X', 11) ->> 'result', 'rejected', 'ADM2-2: a coach cannot propose');
select is(pg_temp.propose('ops', 'Kandidatin X', 12) ->> 'result', 'rejected', 'ADM2-2: operations cannot propose');
select is(pg_temp.propose('admin', 'Kandidatin X', 13) ->> 'result', 'rejected', 'ADM2-2: an administrator who is not a member cannot propose');
select throws_ok($$select pg_temp.propose('ended', 'Kandidatin X', 14)$$, '42501', 'access_ended',
                 'ADM2-2: a person whose access has ended cannot propose');
select throws_ok($$select pg_temp.propose('p', 'K', 15)$$, '22023', null, 'ADM2-2: a display name needs 2 to 80 characters');
create function pg_temp.bad_band() returns jsonb language sql as $$
  select pg_temp.cmd('p', format('select public.propose_team_candidate(%L, %L, %L, %L, %L)',
    '00000000-0000-4000-a000-000000000101', 'Kandidatin X', 'care_assistant', '50 %', pg_temp.k(16))) $$;
select throws_ok($$select pg_temp.bad_band()$$, '22023', null, 'ADM2-2: availability is one fixed Pensum band');

insert into fx select 'A', (pg_temp.propose('p', 'Kandidatin Anna Test', 20) ->> 'proposal_id')::uuid;
insert into fx select 'B', (pg_temp.propose('p', 'Kandidatin Berta Test', 21) ->> 'proposal_id')::uuid;
select ok((select count(*) from fx where name in ('A', 'B') and id is not null) = 2, 'ADM2-2: an active member proposes');

-- ADM2-3 No person on the decision record -----------------------------------------------------------------------------------
select is((select count(*)::int from information_schema.columns where table_schema = 'public'
           and table_name in ('team_admission_events', 'team_admission_proposals')
           and data_type in ('text', 'character varying', 'character', 'json', 'jsonb')), 0,
          'ADM2-3: the decision record has no text column');
select throws_ok($$update public.team_admission_proposals set team_id = team_id$$, '42501', null, 'ADM2-3: the decision record is append-only (no update)');
select throws_ok($$delete from public.team_admission_proposals$$, '42501', null, 'ADM2-3: the decision record is append-only (no delete)');

-- ADM2-4 Reads ---------------------------------------------------------------------------------------------------------------
select is(jsonb_array_length(pg_temp.nord('ca') -> 'proposals'), 2, 'ADM2-4: an active member of the team reads the proposals');
select is(pg_temp.nord('ca') #>> '{proposals,0,display_name}', 'Kandidatin Anna Test', 'ADM2-4: with the candidate''s name');
select is(jsonb_array_length(pg_temp.nord('admin') -> 'proposals'), 2, 'ADM2-4: an administrator of the organisation reads them');
select is(pg_temp.nord('mitte'), null, 'ADM2-4: a nurse of another team in the same organisation reads nothing');
select is(pg_temp.nord('coach'), null, 'ADM2-4: a coach reads nothing');
select is(pg_temp.nord('ops'), null, 'ADM2-4: operations reads nothing');
select is(pg_temp.nord('fremd'), null, 'ADM2-4: an administrator of another organisation reads nothing');
select is(pg_temp.nord('ended'), null, 'ADM2-4: a member whose access has ended reads nothing');
select is(pg_temp.cmd('p', format('select public.admin_team_admissions(%L)', '00000000-0000-4000-b000-000000000011')), null,
          'ADM2-4: the administrator list is not readable by a nurse');
select throws_ok($$select pg_temp.cmd('ca', 'select count(*)::text::jsonb from public.team_candidates')$$, '42501', null,
                 'ADM2-4: no direct read of the candidate table');
select throws_ok($$select pg_temp.cmd('admin', 'select count(*)::text::jsonb from public.team_admission_events')$$, '42501', null,
                 'ADM2-4: no direct read of the decision record');
select is((select coalesce(array_agg(p.oid::regprocedure::text order by p.oid::regprocedure::text collate "C"), '{}') from pg_proc p
           join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private')
             and (p.prosrc ~ 'team_candidates' or p.prosrc ~ 'team_admission_')
             and p.proname not in ('propose_team_candidate', 'decide_team_candidate', 'record_member_contract', 'team_admissions',
                                   'admin_team_admissions', 'set_team_admission', 'team_admission_on', 'adm2_outcome',
                                   'adm2_tally', 'adm2_close', 'adm2_evaluate', 'adm2_sweep', 'audit_team_candidate_delete',
                                   'guard_team_admission_record', 'guard_team_candidate_update',
                                   'set_member_contract_end' /* 0092: the switch only */)),
          '{}'::text[], 'ADM2-4: no other function (AN1, AN2, OPS1, AUD1, export) reads the admission records');

-- ADM2-5 Consent decision ----------------------------------------------------------------------------------------------------
select is(pg_temp.decide('p', (select id from fx where name = 'A'), 'consent', null, 30) ->> 'result', 'own_proposal',
          'ADM2-5: the proposer cannot consent to her own proposal');
select is((select needed from private.adm2_tally((select id from fx where name = 'A'))), 2,
          'ADM2-5: two consents needed (Nord has two other active members; the ended member does not count)');
select is(pg_temp.decide('ca', (select id from fx where name = 'A'), 'consent', null, 31) ->> 'outcome', null,
          'ADM2-5: one consent does not admit');
select is(pg_temp.decide('ca', (select id from fx where name = 'A'), 'consent', null, 32) ->> 'result', 'unchanged',
          'ADM2-5: one consent per member');
select is(pg_temp.decide('x1', (select id from fx where name = 'A'), 'consent', null, 33) ->> 'outcome', 'admitted',
          'ADM2-5: two consents and no objection: admitted by the team');
select throws_ok($$select pg_temp.decide('ca', (select id from fx where name = 'B'), 'objection', null, 40)$$, '22023', null,
                 'ADM2-5: an objection needs a reason code');
select is(pg_temp.decide('ca', (select id from fx where name = 'B'), 'objection', 'wants_to_meet_first', 41) ->> 'result', 'ok',
          'ADM2-5: an objection with a reason code');
select is(pg_temp.decide('x1', (select id from fx where name = 'B'), 'consent', null, 42) ->> 'outcome', null,
          'ADM2-5: one objection blocks');
select is(pg_temp.res('admin', format('select public.add_team_member(%L, %L, %L, %L)', '00000000-0000-4000-a000-000000000101',
          pg_temp.u('late'), 'registered_nurse', pg_temp.k(43))), 'ok', 'ADM2-1: ADM1 add_team_member works with the switch on');
select is(pg_temp.decide('late', (select id from fx where name = 'B'), 'consent', null, 44) ->> 'outcome', null,
          'ADM2-5: a member who joined after the proposal takes part; the objection still blocks two consents');
select is(pg_temp.decide('x1', (select id from fx where name = 'B'), 'withdraw_objection', null, 45) ->> 'result', 'no_objection',
          'ADM2-5: only her own objection can be withdrawn');
select is(pg_temp.decide('ca', (select id from fx where name = 'B'), 'withdraw_objection', null, 46) ->> 'outcome', 'admitted',
          'ADM2-5: the objection withdrawn, the consents stand: admitted');

-- Withdrawal of an objection, then admitted on the next consent.
insert into fx select 'C', (pg_temp.propose('p', 'Kandidatin Clara Test', 50) ->> 'proposal_id')::uuid;
select is(pg_temp.decide('ca', (select id from fx where name = 'C'), 'objection', 'team_full', 51) ->> 'result', 'ok', 'ADM2-5: objection on C');
select is(pg_temp.decide('x1', (select id from fx where name = 'C'), 'consent', null, 52) ->> 'outcome', null, 'ADM2-5: C blocked');
select is(pg_temp.decide('ca', (select id from fx where name = 'C'), 'withdraw_objection', null, 53) ->> 'outcome', null,
          'ADM2-5: C: objection withdrawn, one consent: still open');
select is(pg_temp.decide('late', (select id from fx where name = 'C'), 'consent', null, 54) ->> 'outcome', 'admitted',
          'ADM2-5: C: admitted on the next consent');
select is(pg_temp.decide('ca', (select id from fx where name = 'C'), 'objection', 'team_full', 55) ->> 'result', 'closed',
          'ADM2-5: no decision after the outcome');
select throws_ok($$delete from public.team_admission_events$$, '42501', null, 'ADM2-3: consents and objections are append-only');

-- Lapse after 14 Zurich days. D is proposed one day earlier (10:00 yesterday), so the admitted proposals A and B (admitted
-- at 10:00 today) are still inside their own 14 days when D lapses (ADM2-8 clarified by po 2026-10-29, pgTAP 092).
select set_config('navora.test_now', ((((private.now() at time zone 'Europe/Zurich')::date - 1) + time '10:00')
                                      at time zone 'Europe/Zurich')::text, true);
insert into fx select 'D', (pg_temp.propose('p', 'Kandidatin Dora Test', 60) ->> 'proposal_id')::uuid;
select set_config('navora.test_now', ((private.now() at time zone 'Europe/Zurich' + interval '14 days' - interval '1 minute')
                                      at time zone 'Europe/Zurich')::text, true);
select is(pg_temp.nord('ca') #>> '{proposals,0,display_name}' is not null and pg_temp.outcome((select id from fx where name = 'D')) is null,
          true, 'ADM2-5: one minute before 14 days: still open');
select set_config('navora.test_now', ((private.now() at time zone 'Europe/Zurich' + interval '1 minute')
                                      at time zone 'Europe/Zurich')::text, true);
select is((select count(*)::int from jsonb_array_elements(pg_temp.nord('ca') -> 'proposals') x
           where x ->> 'proposal_id' = (select id::text from fx where name = 'D')), 0, 'ADM2-5: after 14 days it is gone from the team view');
select is(pg_temp.outcome((select id from fx where name = 'D')), 'lapsed', 'ADM2-5: lapsed');
select is((select actor_id from public.team_admission_events where proposal_id = (select id from fx where name = 'D') and kind = 'lapsed'),
          '00000000-0000-0000-0000-000000000000'::uuid, 'ADM2-5: the lapse is the system''s act');
select is(private.adm2_lapse_at('2026-10-20 10:00 Europe/Zurich'), '2026-11-03 10:00 Europe/Zurich'::timestamptz,
          'ADM2-5 DST1: the lapse keeps the Zurich local time across the night the clocks change');
-- Back to 10:00 of the first day (D lapsed at 10:00 on day 13): the contract of A and B is recorded below.
select set_config('navora.test_now', ((((private.now() at time zone 'Europe/Zurich')::date - 13) + time '10:00')
                                      at time zone 'Europe/Zurich')::text, true);

-- ADM2-8 Withdrawal deletes the candidate -------------------------------------------------------------------------------------
insert into fx select 'E', (pg_temp.propose('p', 'Kandidatin Emma Test', 70) ->> 'proposal_id')::uuid;
select is(pg_temp.decide('ca', (select id from fx where name = 'E'), 'withdraw_proposal', null, 71) ->> 'result', 'not_proposer',
          'ADM2-5: only the proposer withdraws her proposal');
select is(pg_temp.decide('p', (select id from fx where name = 'E'), 'withdraw_proposal', null, 72) ->> 'outcome', 'withdrawn',
          'ADM2-8: the proposer withdraws (decline)');
select is((select count(*)::int from public.team_candidates where proposal_id in (select id from fx where name in ('D', 'E'))), 0,
          'ADM2-8: candidate data deleted on lapse and on withdrawal, in the same transaction');

-- ADM2-6 "Vertrag erfasst" ------------------------------------------------------------------------------------------------------
select is(pg_temp.res('ca', format('select public.record_member_contract(%L, %L, current_date, null, %L)',
          (select id from fx where name = 'A'), upper(pg_temp.mail('new')), pg_temp.k(80))), 'rejected', 'ADM2-6: a nurse cannot record the contract');
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, current_date, null, %L)',
          (select id from fx where name = 'E'), upper(pg_temp.mail('new')), pg_temp.k(81))), 'not_admitted', 'ADM2-6: only for an admitted proposal');
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, current_date, null, %L)',
          (select id from fx where name = 'A'), 'nobody@navora.test', pg_temp.k(82))), 'unknown_user',
          'ADM2-6: the account must exist (made by hand, D-26)');
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, %L, %L, %L)',
          (select id from fx where name = 'A'), upper(pg_temp.mail('new')), (private.now() at time zone 'Europe/Zurich')::date,
          (private.now() at time zone 'Europe/Zurich')::date + 365, pg_temp.k(83))), 'ok', 'ADM2-6: the administrator records "Vertrag erfasst"');
select is((select role from public.organization_memberships where user_id = pg_temp.u('new')), 'nurse', 'ADM2-6: organisation role nurse');
select ok(exists (select 1 from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101'
                  and user_id = pg_temp.u('new') and qualification is null), 'ADM2-6: team membership without a qualification');
select is((select end_date - start_date from public.member_contract_events where user_id = pg_temp.u('new')), 365,
          'ADM2-6: the contract dates are recorded');
select is(pg_temp.outcome((select id from fx where name = 'A')), 'contract_recorded', 'ADM2-6: outcome contract_recorded');
select is((select count(*)::int from public.team_candidates where proposal_id = (select id from fx where name = 'A')), 0,
          'ADM2-8: candidate data deleted when the contract is recorded');
select ok((select count(*) from public.team_admission_events where proposal_id = (select id from fx where name = 'A')) >= 4,
          'ADM2-3: the decision record stays readable and nameless after the deletion');
select is((select count(*)::int from public.audit_events where changed::text ~ 'Kandidatin (Berta|Clara|Dora|Emma)'), 0,
          'ADM2-8: no audit row carries a candidate''s name');
select is((select string_agg(distinct table_name, ',') from public.audit_events where changed::text ~ 'Kandidatin Anna'), 'member_profiles',
          'ADM2-6: once she is a member, her name is only in her ADM1 profile (and its audit row), never in the admission records');

-- ADM2-6 No qualification, no responsibility (planning, take, backstop) ---------------------------------------------------------
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status, planned_minutes_a)
values ('a0910000-0000-4000-8000-000000000001', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date + 2, '15:00', '15:30', 'planned', 30);
select is(pg_temp.cmd('p', format('select public.plan_visit(%L, %L, %L, %L, 0, 0, 30, false, %L, %L)',
          '00000000-0000-4000-a000-000000000208', (private.now() at time zone 'Europe/Zurich')::date + 3, '15:00', '15:30',
          pg_temp.u('new'), pg_temp.k(90))) ->> 'reason', 'qualification_missing', 'ADM2-6: planning refuses her as responsible');
select is(pg_temp.res('new', format('select public.take_open_visit(%L, %L)', 'a0910000-0000-4000-8000-000000000001', pg_temp.k(91))),
          'not_qualified', 'ADM2-6: take refuses her');
select throws_ok($$update public.care_visits set responsible_user_id = 'a0910000-0000-4000-a000-000000009105'
                   where id = 'a0910000-0000-4000-8000-000000000001'$$, '42501', 'qualification_missing',
                 'ADM2-6: no other path makes her responsible (backstop)');
select is(pg_temp.res('admin', format('select public.set_member_qualification(%L, %L, %L, %L, %L)', '00000000-0000-4000-a000-000000000101',
          pg_temp.u('new'), 'care_assistant', 'Diplom geprüft', pg_temp.k(92))), 'ok',
          'ADM2-6: the existing administrator path sets her qualification, unchanged');
select is(pg_temp.res('new', format('select public.take_open_visit(%L, %L)', 'a0910000-0000-4000-8000-000000000001', pg_temp.k(93))),
          'ok', 'ADM2-6: with a qualification she takes the visit');

-- ADM2-7 No role change, no other team, no primary nurse ----------------------------------------------------------------------
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, current_date, null, %L)',
          (select id from fx where name = 'B'), upper(pg_temp.mail('coach')), pg_temp.k(100))), 'ok', 'ADM2-7: a coach admitted by the team');
select is((select role from public.organization_memberships where user_id = pg_temp.u('coach')), 'coach',
          'ADM2-7: her organisation role is not changed');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('set_team_admission', 'propose_team_candidate', 'decide_team_candidate',
                                                        'record_member_contract')
             and exists (select 1 from unnest(p.proargnames) a where a ~ '^p_(role|primary|deputy|qualification)')), 0,
          'ADM2-7: no ADM2 command takes a role, a primary or deputy nurse or a qualification to set');

-- ADM2-9 The administrator's list --------------------------------------------------------------------------------------------
select is((select x ->> 'outcome' from jsonb_array_elements(pg_temp.cmd('admin', format('select public.admin_team_admissions(%L)',
           '00000000-0000-4000-b000-000000000011')) -> 'proposals') x where x ->> 'proposal_id' = (select id::text from fx where name = 'A')),
          'contract_recorded', 'ADM2-9: every admission is listed for administrators with its outcome');
select is((select x ->> 'display_name' from jsonb_array_elements(pg_temp.cmd('admin', format('select public.admin_team_admissions(%L)',
           '00000000-0000-4000-b000-000000000011')) -> 'proposals') x where x ->> 'proposal_id' = (select id::text from fx where name = 'A')),
          null, 'ADM2-9: no candidate data after deletion');

-- ADM2-1 Switch off again --------------------------------------------------------------------------------------------------------
select is(pg_temp.res('admin', format('select public.set_team_admission(%L, false, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(110))),
          'ok', 'ADM2-1: switched off');
select is(pg_temp.decide('ca', (select id from fx where name = 'C'), 'consent', null, 111) ->> 'result', 'admission_off',
          'ADM2-1: switch off: every ADM2 command returns admission_off');
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, current_date, null, %L)',
          (select id from fx where name = 'C'), upper(pg_temp.mail('ops')), pg_temp.k(112))), 'admission_off',
          'ADM2-1: switch off: no contract recorded through ADM2');

select * from finish();
rollback;
