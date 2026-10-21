-- J2 changes (PO brief docs/agents/briefs/J2.md) + F0 criterion 4 (offer fields).
-- Users: ops …904 (org A; promoted to admin here to configure deadlines) · nurse …902 (Testteam Nord, registered nurse)
--        coach …901 (joins Testteam Mitte as care assistant here) · foreign admin …903 (org B)
-- Bern West, org A: Testteam Nord …101 (active, has a registered nurse), Testteam Mitte …102 (active, no registered nurse)
begin;
create extension if not exists pgtap with schema extensions;

select plan(36);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Fixtures (as owner)
update public.organization_memberships set role = 'admin'
  where organization_id = '00000000-0000-4000-b000-000000000011' and user_id = '00000000-0000-4000-a000-000000000904';
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'care_assistant');

select ok(not has_table_privilege('authenticated', 'public.response_deadlines', 'insert'), 'deadlines change only by command');
select ok(not has_function_privilege('anon', 'public.matching_escalations()', 'execute'), 'anon cannot read escalations');
select is(private.required_qualification('00000000-0000-4000-a000-000000000208'), null,
  'a case with a completed needs assessment and no present order needs no particular qualification');

-- Intake: two referrals (hospital, nursing home) in Bern West ---------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$
begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital J2v2', 'Spital', 'Bern West', null,
    'hoch', null, 'J2v2 Spital', 'Bedarf Spital', array['Grundpflege'], 'a7000000-0000-4000-8000-000000000001');
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Heim J2v2', 'Pflegeheim', 'Bern West', null,
    'mittel', null, 'J2v2 Heim', 'Bedarf Heim', array['Begleitung'], 'a7000000-0000-4000-8000-000000000002');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'J2v2 Spital'),
    'Klient', 'J2S', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', current_date + 2, 'expected_hours_per_week', 6),
    'a7000000-0000-4000-8000-000000000003');
  -- A region without any team (no eligible team at all)
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Privat J2v2', 'Privat / Angehörige', 'Testregion ohne Team', null,
    'niedrig', null, 'J2v2 Leer', 'Bedarf Leer', array['Begleitung'], 'a7000000-0000-4000-8000-000000000006');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'J2v2 Leer'),
    'Klient', 'J2L', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', current_date + 3),
    'a7000000-0000-4000-8000-000000000007');
end
$$;
select throws_ok(
  $$ select public.convert_partner_request((select id from public.partner_requests where request_title = 'J2v2 Heim'),
       'Klient', 'J2H', true, jsonb_build_object('expected_hours_per_week', 200), 'a7000000-0000-4000-8000-000000000004') $$,
  '22023', null, 'expected hours per week are checked (0–168)');
do $$ begin
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'J2v2 Heim'),
    'Klient', 'J2H', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', current_date + 3),
    'a7000000-0000-4000-8000-000000000005');
end $$;
reset role;

create temp table r as
  select m.id, c.last_name from public.matching_requests m join public.cases c on c.id = m.case_id
  where c.last_name in ('J2S', 'J2H', 'J2L');
grant select on r to authenticated;

select is((select referral_type from public.matching_requests where id = (select id from r where last_name = 'J2S')),
  'hospital_discharge', 'referral type is derived from the partner type (Spital)');
select is((select referral_type from public.matching_requests where id = (select id from r where last_name = 'J2H')),
  'nursing_home', 'referral type is derived from the partner type (Pflegeheim)');
select is((select response_due_at from public.matching_requests where id = (select id from r where last_name = 'J2S')), null,
  'no deadline is invented when none is configured');

-- Offer fields before acceptance (F0 criterion 4) --------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok((select requested_start = current_date + 2 and expected_hours_per_week = 6 and required_qualification = 'registered_nurse'
           from public.team_offers() where matching_request_id = (select id from r where last_name = 'J2S')),
  'the offer shows start, expected hours per week and required qualification');
select is(
  (select array_agg(a) from unnest((select proargnames from pg_proc where oid = 'public.team_offers()'::regprocedure)) a
   where a in ('first_name', 'last_name', 'client_name', 'name', 'address', 'phone', 'insurer_name', 'diagnosis_tags')),
  null, 'still no client identity or funding data in the offer');
reset role;

-- Qualification: a team without a registered nurse neither sees nor accepts -----------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.team_offers() where team_id = '00000000-0000-4000-a000-000000000102'
             and matching_request_id in (select id from r)), 0,
  'a team without a registered nurse is not offered a case that needs one');
select is(public.decide_matching_request((select id from r where last_name = 'J2S'), '00000000-0000-4000-a000-000000000102',
          'accept', null, 'a7000000-0000-4000-8000-000000000010'), 'not_qualified',
  'a team without a registered nurse cannot accept it');
reset role;

-- Deadlines: configuration by admins only ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.set_response_deadline('00000000-0000-4000-b000-000000000011', 'hospital_discharge', 4,
          'a7000000-0000-4000-8000-000000000020'), 'rejected', 'a coach cannot configure deadlines');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select reason from public.matching_escalations() where matching_request_id = (select id from r where last_name = 'J2S')),
  'deadline_not_configured', 'without a configured deadline the request is visible to Operations, not silent');
select throws_ok($$ select public.set_response_deadline('00000000-0000-4000-b000-000000000011', 'hospital_discharge', 0,
          'a7000000-0000-4000-8000-000000000021') $$, '22023', null, 'deadline hours are checked');
select is(public.set_response_deadline('00000000-0000-4000-b000-000000000011', 'hospital_discharge', 4,
          'a7000000-0000-4000-8000-000000000022'), 'ok', 'an admin configures the hospital-discharge deadline');
select is(public.set_response_deadline('00000000-0000-4000-b000-000000000011', 'hospital_discharge', 4,
          'a7000000-0000-4000-8000-000000000022'), 'duplicate', 'resend is a duplicate');
select ok((select response_due_at = created_at + interval '4 hours' from public.matching_requests
           where id = (select id from r where last_name = 'J2S')), 'open requests of that type get the deadline');
select is((select response_due_at from public.matching_requests where id = (select id from r where last_name = 'J2H')), null,
  'other referral types keep no deadline');
select is((select count(*)::int from public.matching_escalations() where matching_request_id = (select id from r where last_name = 'J2S')), 0,
  'within the deadline with an undecided eligible team: no escalation');
reset role;

-- Deadline passes → escalation (time moved as owner)
update public.matching_requests set response_due_at = now() - interval '1 minute' where id = (select id from r where last_name = 'J2S');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select reason from public.matching_escalations() where matching_request_id = (select id from r where last_name = 'J2S')),
  'deadline_passed', 'after the deadline the request escalates to Operations');
reset role;

-- Decline reasons ------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.decide_matching_request((select id from r where last_name = 'J2S'),
          '00000000-0000-4000-a000-000000000101', 'decline', 'kein Grund-Code', 'a7000000-0000-4000-8000-000000000030') $$,
  '22023', null, 'a decline needs a reason code');
select throws_ok($$ select public.decide_matching_request((select id from r where last_name = 'J2S'),
          '00000000-0000-4000-a000-000000000101', 'decline', null, 'a7000000-0000-4000-8000-000000000031', 'other') $$,
  '22023', null, '"other" needs a text');
select throws_ok($$ select public.decide_matching_request((select id from r where last_name = 'J2S'),
          '00000000-0000-4000-a000-000000000101', 'decline', null, 'a7000000-0000-4000-8000-000000000032', 'weather') $$,
  '22023', null, 'only the configured reason codes are accepted');
select throws_ok($$ select public.decide_matching_request((select id from r where last_name = 'J2S'),
          '00000000-0000-4000-a000-000000000101', 'accept', null, 'a7000000-0000-4000-8000-000000000033', 'capacity') $$,
  '22023', null, 'an acceptance takes no reason code');
select is(public.decide_matching_request((select id from r where last_name = 'J2S'), '00000000-0000-4000-a000-000000000101',
          'decline', 'Diese Woche voll', 'a7000000-0000-4000-8000-000000000034', 'capacity'), 'ok',
  'the only eligible team declines with a reason code');
reset role;

-- Another team's decision (inserted as owner for Testteam Mitte) stays invisible to the nurse
insert into public.team_decisions (organization_id, matching_request_id, case_id, team_id, decision, reason_code, reason, actor_id, idempotency_key)
select '00000000-0000-4000-b000-000000000011', m.id, m.case_id, '00000000-0000-4000-a000-000000000102', 'decline', 'distance', null,
       '00000000-0000-4000-a000-000000000901', 'a7000000-0000-4000-8000-000000000040'
from public.matching_requests m where m.id = (select id from r where last_name = 'J2H');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.team_decisions where team_id <> '00000000-0000-4000-a000-000000000101'), 0,
  'a team does not see other teams'' decisions');
select is((select count(*)::int from public.team_decisions where team_id = '00000000-0000-4000-a000-000000000101'
             and matching_request_id = (select id from r where last_name = 'J2S')), 1, 'a team sees its own decision');
select is((select count(*)::int from public.matching_escalations()), 0, 'a nurse sees no escalations');
reset role;

-- All eligible teams declined → escalation with reasons; never auto-assigned
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select reason from public.matching_escalations() where matching_request_id = (select id from r where last_name = 'J2S')),
  'all_declined', 'when every eligible team has declined, the request escalates');
select is((select declines -> 0 ->> 'code' from public.matching_escalations() where matching_request_id = (select id from r where last_name = 'J2S')),
  'capacity', 'the escalation carries the decline reasons');
select is((select declines -> 0 ->> 'team' from public.matching_escalations() where matching_request_id = (select id from r where last_name = 'J2S')),
  'Testteam Nord', 'Operations sees which team declined');
select is((select count(*)::int from public.team_decisions where matching_request_id = (select id from r where last_name = 'J2H')), 1,
  'coordination roles see all decisions of their organisation');
reset role;
select ok((select assigned_team_id is null and status <> 'laufend' from public.cases where last_name = 'J2S'),
  'nothing is assigned automatically');
select is((select status from public.matching_requests where id = (select id from r where last_name = 'J2S')), 'open',
  'the request stays open for Operations to act');

-- No eligible team at all (a region without teams)
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select reason || '/' || referral_type from public.matching_escalations() where matching_request_id = (select id from r where last_name = 'J2L')),
  'no_eligible_team/private', 'a request no team may take escalates immediately');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.matching_escalations() where matching_request_id in (select id from r)), 0,
  'another organisation sees no escalations of org A');
reset role;

select * from finish();
rollback;
