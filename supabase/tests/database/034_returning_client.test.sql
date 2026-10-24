-- RET1: returning client returns to her team (migration 0034, ADR-048).
-- Org A: Operations …904 (intake role), nurse …902 (Testteam Nord …101), here nurse …908 in Testteam Mitte …102.
-- Case …208 (team …101, primary …902) is closed 10 days ago; case …210 (team …102) is paused for a hospital stay;
-- case …209 closed 200 days ago; case …206 (team …103, not active) closed 5 days ago; case …251 belongs to org B.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.close(p_case uuid, p_days integer) returns void language sql as $$
  insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, actor_id, idempotency_key, created_at)
  select c.organization_id, c.id, 'close', 'moved_inpatient', '00000000-0000-4000-a000-000000000904', gen_random_uuid(), now() - make_interval(days => p_days)
  from public.cases c where c.id = p_case;
  update public.cases set lifecycle = 'closed', status = 'abgeschlossen', primary_nurse_id = null, deputy_nurse_id = null where id = p_case;
$$;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
values ('00000000-0000-0000-0000-000000000000', 'c4000000-0000-4000-8000-000000000908', 'authenticated', 'authenticated',
        'mitte.ret1@navora.test', '', now(), '{}', '{}', now(), now(), '', '', '', '');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', 'c4000000-0000-4000-8000-000000000908', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', 'c4000000-0000-4000-8000-000000000908', 'registered_nurse');

-- Closed and paused cases.
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-000000000902' where id = '00000000-0000-4000-a000-000000000208';
select pg_temp.close('00000000-0000-4000-a000-000000000208', 10);
select pg_temp.close('00000000-0000-4000-a000-000000000209', 200);
select pg_temp.close('00000000-0000-4000-a000-000000000206', 5);
insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, actor_id, idempotency_key, created_at) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000210', 'pause', 'hospital_stay',
   '00000000-0000-4000-a000-000000000904', gen_random_uuid(), now() - interval '3 days'),
  ('00000000-0000-4000-b000-000000000012', '00000000-0000-4000-a000-000000000251', 'pause', 'hospital_stay',
   '00000000-0000-4000-a000-000000000903', gen_random_uuid(), now() - interval '3 days');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, suspended_at)
values ('00000000-0000-4000-b000-000000000011', 'c4000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-a000-000000000210',
        '00000000-0000-4000-a000-000000000102', (now() at time zone 'Europe/Zurich')::date + 3, '09:00', '09:30', false, 'planned', now() - interval '3 days');
update public.cases set lifecycle = 'paused' where id in ('00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000251');

-- Two more hospital referrals (Bern West).
insert into public.partner_requests (organization_id, id, partner_name, partner_type, region, urgency, request_title, need_summary, requested_services, status)
select '00000000-0000-4000-b000-000000000011', x.id, 'Synthetisches Spital', 'Spital', x.region, 'mittel', 'Synthetisch: Austritt', 'Synthetisch', array['Grundpflege'], 'open'
from (values ('c4000000-0000-4000-8000-000000000301'::uuid, 'Bern West'), ('c4000000-0000-4000-8000-000000000302'::uuid, 'Bern West'),
             ('c4000000-0000-4000-8000-000000000303'::uuid, 'Zürich Pilot')) x(id, region);

create temp table facts as select '{"residence_municipality": "Teststadt", "residence_canton": "BE", "insurer_name": "Synthetische Kasse",
  "insurance_type": "KVG", "requested_start": "2026-11-02"}'::jsonb as f;
grant select on facts to authenticated;

create temp table before_resume as
  select (select count(*) from public.cases) as cases,
         (select count(*) from public.matching_requests where case_id = '00000000-0000-4000-a000-000000000210') as requests;

-- Who may link ---------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.link_returning_referral('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000208', 'Rückkehr nach Spital',
          'Testfall', '08', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e01') ->> 'result', 'rejected', 'only intake roles can link');
select is((select count(*)::int from public.linkable_cases('00000000-0000-4000-a000-000000000301')), 0, 'and only they see linkable cases');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok(exists (select 1 from public.linkable_cases('00000000-0000-4000-a000-000000000301') where case_id = '00000000-0000-4000-a000-000000000208' and lifecycle = 'closed'),
  'a case closed 10 days ago is linkable');
select ok(exists (select 1 from public.linkable_cases('00000000-0000-4000-a000-000000000301') where case_id = '00000000-0000-4000-a000-000000000210'
                  and lifecycle = 'paused' and reason_code = 'hospital_stay'), 'a paused case is linkable, with its pause reason');
select ok(not exists (select 1 from public.linkable_cases('00000000-0000-4000-a000-000000000301')
                      where case_id in ('00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000205', '00000000-0000-4000-a000-000000000251')),
  'not: closed too long ago, active, or another organisation');
select is(public.link_returning_referral('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000209', 'Rückkehr nach Spital',
          'Testfall', '09', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e02') ->> 'result', 'not_linkable',
  'no link to a case closed longer ago than the configured period');
select is(public.link_returning_referral('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000251', 'Rückkehr nach Spital',
          'Fremd', 'B', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e03') ->> 'result', 'not_linkable', 'no link across organisations');
select is(public.link_returning_referral('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000205', 'Rückkehr',
          'Testfall', '05', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e04') ->> 'result', 'not_linkable', 'no link to an active case');
select throws_ok($$ select public.link_returning_referral('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000208', ' ',
          'Testfall', '08', true, '{}'::jsonb, 'c4000000-0000-4000-8000-000000000e05') $$, '22023', null, 'the link needs a reason');

-- Paused case: resume, no new case, no new matching ------------------------------------------------------------------------
select is(public.link_returning_referral('00000000-0000-4000-a000-000000000303', '00000000-0000-4000-a000-000000000210', 'Austritt nach Spitalaufenthalt',
          null, null, true, '{"medical_order_status": "present", "medical_order_valid_until": "2027-01-31"}'::jsonb,
          'c4000000-0000-4000-8000-000000000e10') ->> 'kind', 'resume', 'a referral linked to a paused case resumes it');
reset role;
select is((select lifecycle from public.cases where id = '00000000-0000-4000-a000-000000000210'), 'active', 'the case is active again');
select is((select assigned_team_id from public.cases where id = '00000000-0000-4000-a000-000000000210'), '00000000-0000-4000-a000-000000000102'::uuid,
  'with its team');
select ok((select b.cases = (select count(*) from public.cases)
              and b.requests = (select count(*) from public.matching_requests where case_id = '00000000-0000-4000-a000-000000000210') from before_resume b),
  'no new case and no new matching');
select is((select suspended_at from public.care_visits where id = 'c4000000-0000-4000-8000-0000000000a1'), null, 'its future visits are no longer suspended');
select is((select detail from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000210' and kind = 'review_after_pause' and status = 'open'),
  'hospital_stay', 'the team gets the non-blocking review task with the pause reason');
select ok((select changes ? 'medical_order_status' and reason = 'Austritt nach Spitalaufenthalt' from public.change_log
           where entity_id = '00000000-0000-4000-a000-000000000210' and idempotency_key = 'c4000000-0000-4000-8000-000000000e10'),
  'changed order facts are logged with the link reason');
select ok((select status = 'converted' and converted_case_id = '00000000-0000-4000-a000-000000000210' from public.partner_requests
           where id = '00000000-0000-4000-a000-000000000303'), 'the referral is converted into the resumed case');
select ok(exists (select 1 from public.audit_events where idempotency_key = 'c4000000-0000-4000-8000-000000000e10' and table_name = 'referral_links'),
  'the link is audited');
select pg_temp.act_as('c4000000-0000-4000-8000-000000000908');
set local role authenticated;
select is((select review_after_pause_reason from public.team_cases() where case_id = '00000000-0000-4000-a000-000000000210'), 'hospital_stay',
  'the team sees the task');
select is(public.complete_case_task('00000000-0000-4000-a000-000000000210', 'review_after_pause', 'c4000000-0000-4000-8000-000000000e11'), 'ok',
  'and closes it when it has decided');
reset role;

-- Closed case: new case, first refusal by the previous team --------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
create temp table ret as select (public.link_returning_referral('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000208',
  'Bekannte Klientin nach Spital', 'Testfall', '08', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e20') ->> 'case_id')::uuid as id;
reset role;
alter table ret add column rid uuid;
update ret set rid = (select m.id from public.matching_requests m where m.case_id = ret.id);
grant select on ret to authenticated;
select is((select previous_case_id from public.cases where id = (select id from ret)), '00000000-0000-4000-a000-000000000208'::uuid,
  'a new case references the previous one');
select ok((select m.preferred_team_id = '00000000-0000-4000-a000-000000000101' and m.first_refusal_until > now()
                  and m.first_refusal_until <= m.response_due_at
           from public.matching_requests m where m.case_id = (select id from ret)),
  'its request goes first to the previous team, inside the response deadline');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok((select returning_client from public.team_offers() where matching_request_id = (select rid from ret)),
  'the previous team sees it labelled as a returning client');
reset role;
select pg_temp.act_as('c4000000-0000-4000-8000-000000000908');
set local role authenticated;
select is((select count(*)::int from public.team_offers() where matching_request_id = (select rid from ret)), 0,
  'other eligible teams do not see it during the window');
select is(public.decide_matching_request((select rid from ret),
          '00000000-0000-4000-a000-000000000102', 'accept', null, 'c4000000-0000-4000-8000-000000000e21'), 'rejected', 'nor can they accept it');
select is((select count(*)::int from public.cases where id = '00000000-0000-4000-a000-000000000208'), 0, 'a team never sees another team''s earlier case');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.decide_matching_request((select rid from ret),
          '00000000-0000-4000-a000-000000000101', 'accept', null, 'c4000000-0000-4000-8000-000000000e22'), 'ok', 'the previous team accepts');
select is((select proposed_primary_nurse_id from public.team_cases() where case_id = (select id from ret)), '00000000-0000-4000-a000-000000000902'::uuid,
  'and its previous primary nurse is proposed, not assigned');
reset role;

-- Window over: everyone eligible, without any mention of the earlier case ----------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
create temp table ret2 as select (public.link_returning_referral('c4000000-0000-4000-8000-000000000301', '00000000-0000-4000-a000-000000000208',
  'Bekannte Klientin, zweite Zuweisung', 'Testfall', '08b', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e30') ->> 'case_id')::uuid as id;
reset role;
-- Case …208 is still closed within the period; the window is then forced to have passed.
update public.matching_requests set first_refusal_until = now() - interval '1 minute' where case_id = (select id from ret2);
alter table ret2 add column rid uuid;
update ret2 set rid = (select m.id from public.matching_requests m where m.case_id = ret2.id);
grant select on ret2 to authenticated;
select pg_temp.act_as('c4000000-0000-4000-8000-000000000908');
set local role authenticated;
select ok((select returning_client = false and first_refusal_until is null from public.team_offers()
           where matching_request_id = (select rid from ret2)),
  'after the window, other teams get the usual offer with no mention of the previous team');
reset role;

-- Previous team not eligible: the window is skipped ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
create temp table ret3 as select (public.link_returning_referral('c4000000-0000-4000-8000-000000000303', '00000000-0000-4000-a000-000000000206',
  'Bekannte Klientin', 'Testfall', '06', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e40') ->> 'case_id')::uuid as id;
reset role;
select ok((select preferred_team_id is null and first_refusal_until is null from public.matching_requests where case_id = (select id from ret3)),
  'an inactive previous team: no window, normal matching at once');

-- Idempotent ------------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.link_returning_referral('c4000000-0000-4000-8000-000000000303', '00000000-0000-4000-a000-000000000206',
  'Bekannte Klientin', 'Testfall', '06', true, (select f from facts), 'c4000000-0000-4000-8000-000000000e40') ->> 'result', 'duplicate', 'a retried link is applied once');

reset role;
-- AN1 condition (0057, ADR-070): the seed's small teams would hide the organisation row of org A. Three more synthetic
-- persons with one completed visit each this month, in two small teams of their own (no case, no client, no
-- departure), make the hidden teams' persons number 3 or more, so the organisation figures under test may show.
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000011', 'ad570000-0000-4000-8000-0000000000b1', 'AN1 Fixture 1', 'Test', 'active'),
  ('00000000-0000-4000-b000-000000000011', 'ad570000-0000-4000-8000-0000000000b2', 'AN1 Fixture 2', 'Test', 'active');
insert into public.care_visits (organization_id, id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000011', ('ad570000-0000-4000-8000-00000000000' || g)::uuid,
       case when g < 3 then 'ad570000-0000-4000-8000-0000000000b1' else 'ad570000-0000-4000-8000-0000000000b2' end::uuid,
       date_trunc('month', (now() at time zone 'Europe/Zurich')::date)::date, '06:00', '06:30', false, 'completed'
from generate_series(1, 3) g;
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
select v.organization_id, v.id, v.team_id, 'started', 'on_the_way', 'started',
       ('ad570000-0000-4000-8000-0000000000f' || right(v.id::text, 1))::uuid, (v.visit_date + time '06:00') at time zone 'Europe/Zurich'
from public.care_visits v where v.team_id in ('ad570000-0000-4000-8000-0000000000b1', 'ad570000-0000-4000-8000-0000000000b2');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
-- AN1 -------------------------------------------------------------------------------------------------------------------------
select ok((select k.value = 100 and k.base = 2 from public.pilot_kpis((now() at time zone 'Europe/Zurich')::date) k where k.kpi = 'returning_previous_team_share' and k.team_id is null),
  'AN1: returning clients served by their previous team (resumed case and accepted return)');
reset role;

select * from finish();
rollback;
