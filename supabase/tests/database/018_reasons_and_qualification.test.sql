-- F0 remainder: mandatory reasons (PO rule) and qualification administration (D-5).
-- Users: ops …904 (org A; promoted to admin here) · nurse …902 (Testteam Nord, registered nurse)
--        coach …901 (joins Testteam Nord as care assistant here) · foreign admin …903 (org B)
begin;
create extension if not exists pgtap with schema extensions;

select plan(25);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant');

-- Structure ------------------------------------------------------------------------------------------------
select col_not_null('public', 'team_memberships', 'qualification', 'every member has exactly one qualification');
select throws_ok($$ insert into public.team_memberships (team_id, user_id, qualification)
                    values ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000902', 'doctor') $$,
  '23514', null, 'only registered_nurse or care_assistant');
select ok(not has_table_privilege('authenticated', 'public.team_memberships', 'update'), 'no direct membership updates');
select ok(not has_table_privilege('authenticated', 'public.change_log', 'insert'), 'no direct change-log inserts');
select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname ~ '(cancel|close|reopen|no_show|pause_case|lift_|_hold)'
     and not ('p_reason' = any (coalesce(p.proargnames, '{}')))),
  null, 'guard: every command that cancels, closes, reopens or lifts a hold takes a reason (PO rule)');
select is(
  (select array_agg(x order by x) from unnest(array['correct_visit_time', 'reschedule_visit', 'remove_planned_visit',
     'retire_care_plan_item', 'decide_matching_request', 'correct_report', 'update_case_intake', 'set_member_qualification']) x
   where not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'public' and p.proname = x and 'p_reason' = any (p.proargnames))),
  null, 'every command on the PO list takes a reason');

-- Qualification read scope --------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select qualification from public.team_memberships
           where team_id = '00000000-0000-4000-a000-000000000101' and user_id = '00000000-0000-4000-a000-000000000901'),
  'care_assistant', 'the member''s own team reads a colleague''s qualification');
select throws_ok($$ update public.team_memberships set qualification = 'registered_nurse'
                    where user_id = '00000000-0000-4000-a000-000000000902' $$,
  '42501', null, 'a nurse cannot change her own qualification');
select is(public.set_member_qualification('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901',
          'registered_nurse', 'Diplom nachgereicht', 'a8000000-0000-4000-8000-000000000001'), 'rejected',
  'a nurse cannot change a colleague''s qualification');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101'), 0,
  'nobody outside the organisation reads the qualification');
select is(public.set_member_qualification('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901',
          'registered_nurse', 'Fremdzugriff', 'a8000000-0000-4000-8000-000000000002'), 'rejected',
  'an admin of another organisation cannot change it');
reset role;

-- Administrators set it, with a reason, audited ---------------------------------------------------------------
update public.organization_memberships set role = 'admin'
  where organization_id = '00000000-0000-4000-b000-000000000011' and user_id = '00000000-0000-4000-a000-000000000904';
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select throws_ok($$ select public.set_member_qualification('00000000-0000-4000-a000-000000000101',
          '00000000-0000-4000-a000-000000000901', 'registered_nurse', null, 'a8000000-0000-4000-8000-000000000003') $$,
  '22023', null, 'a qualification change needs a reason');
select is(public.set_member_qualification('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901',
          'registered_nurse', 'Diplom HF nachgereicht', 'a8000000-0000-4000-8000-000000000004'), 'ok',
  'a NAVORA administrator changes the qualification');
select is(public.set_member_qualification('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901',
          'registered_nurse', 'Diplom HF nachgereicht', 'a8000000-0000-4000-8000-000000000004'), 'duplicate',
  'resend is a duplicate');
select is(public.set_member_qualification('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901',
          'registered_nurse', 'Nochmals', 'a8000000-0000-4000-8000-000000000005'), 'unchanged',
  'setting the same value changes nothing');
select is((select changes -> 'qualification' ->> 'old' || '→' || (changes -> 'qualification' ->> 'new') || ' / ' || reason
           from public.change_log where command = 'set_member_qualification'),
  'care_assistant→registered_nurse / Diplom HF nachgereicht', 'the change log keeps old, new and why');
select is((select count(*)::int from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101'), 3,
  'coordination roles read the team''s qualifications (nurse, seeded care assistant, coach)');
reset role;
select ok(exists (select 1 from public.audit_events where command = 'set_member_qualification'
                  and actor_id = '00000000-0000-4000-a000-000000000904'), 'the change is in the audit trail');
select ok(private.is_registered_nurse('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901'),
  'J3 sees the new qualification through the shared rule');
select ok(private.team_has_registered_nurse('00000000-0000-4000-a000-000000000101'),
  'J2 eligibility uses the same rule');

-- Reason when changing funding facts on a ready case ---------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
do $$ begin
  perform public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital F0', 'Spital', 'Bern West', null,
    'mittel', null, 'F0 Anfrage', 'Bedarf F0', array['Grundpflege'], 'a8000000-0000-4000-8000-000000000010');
  perform public.convert_partner_request((select id from public.partner_requests where request_title = 'F0 Anfrage'),
    'Klient', 'F0R', true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', current_date + 2),
    'a8000000-0000-4000-8000-000000000011');
end $$;
select ok((select ready_for_matching_at is not null from public.cases where last_name = 'F0R'), 'fixture: the case is ready for matching');
select throws_ok($$ select public.update_case_intake((select id from public.cases where last_name = 'F0R'),
          '{"insurer_name": "Andere Testkasse"}'::jsonb, 'a8000000-0000-4000-8000-000000000012') $$,
  '22023', null, 'changing the insurer of a ready case needs a reason');
select is(public.update_case_intake((select id from public.cases where last_name = 'F0R'),
          '{"language_notes": "Deutsch"}'::jsonb, 'a8000000-0000-4000-8000-000000000013') ->> 'result', 'ok',
  'adding another fact to a ready case needs no reason (not on the PO list)');
select is(public.update_case_intake((select id from public.cases where last_name = 'F0R'),
          '{"insurer_name": "Andere Testkasse", "medical_order_status": "requested"}'::jsonb,
          'a8000000-0000-4000-8000-000000000014', 'Versicherer vom Spital korrigiert') ->> 'result', 'ok',
  'with a reason the change is saved');
select is((select (changes ? 'insurer_name')::text || '/' || (changes ? 'medical_order_status')::text || '/' || (changes ->> 'insurance_type' is null)::text || '/' || reason
           from public.change_log where command = 'update_case_intake'),
  'true/true/true/Versicherer vom Spital korrigiert', 'the change log names exactly the changed funding facts and why');
reset role;

select * from finish();
rollback;
