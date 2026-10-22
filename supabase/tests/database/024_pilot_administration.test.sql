-- ADM1: pilot administration (PO brief docs/agents/briefs/ADM1.md).
-- Users: admin …905 (org A) · nurse …902 (Testteam Nord …101) · coach …901 · operations …904 · foreign admin …903 (org B)
-- Created here: invitee …906 (confirmed email) · invitee …907 (email not confirmed).
begin;
create extension if not exists pgtap with schema extensions;

select plan(67);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                        confirmation_token, recovery_token, email_change_token_new, email_change) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000906', 'authenticated', 'authenticated',
   'neu.test@navora.test', '', now(), '{}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-a000-000000000907', 'authenticated', 'authenticated',
   'spaet.test@navora.test', '', null, '{}', '{}', now(), now(), '', '', '', '');

-- The nurse is primary nurse of an open case of her team (J6), used for the removal guard.
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-000000000902'
where id = (select c.id from public.cases c where c.assigned_team_id = '00000000-0000-4000-a000-000000000101'
            and c.lifecycle <> 'closed' order by c.id limit 1);

-- Structure ---------------------------------------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.member_profiles', 'insert'), 'profiles only through commands');
select ok(not has_table_privilege('authenticated', 'public.member_invitations', 'insert'), 'invitations only through commands');
select ok(not has_table_privilege('authenticated', 'public.exception_rule_overrides', 'insert'), 'rule overrides only through commands');
select ok(not has_table_privilege('authenticated', 'public.tariff_rates', 'insert')
          and not has_table_privilege('authenticated', 'public.tariff_rates', 'update'), 'tariff data is not writable by users');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname ~ '(tariff|billing_rule)'), 0,
  'no command edits tariff or billing reference data (migration only)');

-- Only administrators of the organisation --------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'x@navora.test', 'nurse', 'Neue Person', null, null,
          'a2500000-0000-4000-8000-000000000001'), 'rejected', 'a nurse cannot invite');
select is((select count(*)::int from public.admin_members('00000000-0000-4000-b000-000000000011')), 0, 'a nurse sees no member administration');
select is((select count(*)::int from public.admin_exception_rules('00000000-0000-4000-b000-000000000011')), 0, 'a nurse sees no rule administration');
select is(public.create_team('00000000-0000-4000-b000-000000000011', 'Nurse Team', 'Zürich', 'a2500000-0000-4000-8000-000000000002'),
  'rejected', 'a nurse cannot create a team');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'x@navora.test', 'nurse', 'Neue Person', null, null,
          'a2500000-0000-4000-8000-000000000003'), 'rejected', 'a coach cannot invite');
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'visit_uncovered', 'P2', 12, null,
          'a2500000-0000-4000-8000-000000000004'), 'rejected', 'a coach cannot change exception rules');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'x@navora.test', 'nurse', 'Neue Person', null, null,
          'a2500000-0000-4000-8000-000000000005'), 'rejected', 'operations cannot invite');
select is(public.set_response_deadline('00000000-0000-4000-b000-000000000011', 'private', 3, 'working_days',
          'a2500000-0000-4000-8000-000000000006'), 'rejected', 'operations cannot change response deadlines');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'x@navora.test', 'nurse', 'Neue Person', null, null,
          'a2500000-0000-4000-8000-000000000007'), 'rejected', 'an administrator of another organisation cannot invite');
select is((select count(*)::int from public.admin_members('00000000-0000-4000-b000-000000000011')), 0,
  'an administrator of another organisation sees nothing');
select is(public.set_display_name('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'Fremd',
          'a2500000-0000-4000-8000-000000000008'), 'rejected', 'nor names its members');
reset role;

-- Display names ------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_display_name('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'Anna Muster',
          'a2500000-0000-4000-8000-000000000010'), 'ok', 'the administrator names a member');
select is(public.set_display_name('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'Anna Muster',
          'a2500000-0000-4000-8000-000000000010'), 'duplicate', 'resend is a duplicate');
select is((select count(*)::int from public.admin_members('00000000-0000-4000-b000-000000000011')), 4,
  'the administrator lists the organisation''s members');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_display_name('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000902', 'Anna M.',
          'a2500000-0000-4000-8000-000000000011'), 'ok', 'a member may set her own name');
select is(public.set_display_name('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000901', 'Coach X',
          'a2500000-0000-4000-8000-000000000012'), 'rejected', 'but not a colleague''s');
select ok(exists (select 1 from public.team_cases() tc, jsonb_array_elements(tc.members) m where m ->> 'name' = 'Anna M.'),
  'the team view shows the member''s name');
select ok(exists (select 1 from public.team_cases() tc where tc.primary_nurse_id = '00000000-0000-4000-a000-000000000902'),
  'the primary nurse is a named member of the team view');
select lives_ok($$ select * from public.field_reports(current_date) $$, 'report list with signer names');
select lives_ok($$ select * from public.field_quality(current_date) $$, 'quality list with author names');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.member_profiles where organization_id = '00000000-0000-4000-b000-000000000011'), 0,
  'another organisation reads no names');
reset role;

-- Invitations ---------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select throws_ok($$ select public.invite_member('00000000-0000-4000-b000-000000000011', 'kein-email', 'nurse', 'Neue Person', null, null,
          'a2500000-0000-4000-8000-000000000020') $$, '22023', null, 'a valid email is required');
select throws_ok($$ select public.invite_member('00000000-0000-4000-b000-000000000011', 'neu.test@navora.test', 'nurse', 'Neue Person',
          '00000000-0000-4000-a000-000000000101', null, 'a2500000-0000-4000-8000-000000000021') $$, '22023', null,
  'a team membership needs a qualification');
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'Neu.Test@navora.test', 'nurse', 'Nina Neu',
          '00000000-0000-4000-a000-000000000101', 'registered_nurse', 'a2500000-0000-4000-8000-000000000022'), 'ok',
  'the administrator invites a person with role, team and qualification');
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'neu.test@navora.test', 'nurse', 'Nina Neu', null, null,
          'a2500000-0000-4000-8000-000000000023'), 'already_invited', 'one open invitation per email');
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'pflege.test@navora.test', 'nurse', 'Doppelt', null, null,
          'a2500000-0000-4000-8000-000000000024'), 'already_member', 'members are not invited again');
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'spaet.test@navora.test', 'coach', 'Sam Spät', null, null,
          'a2500000-0000-4000-8000-000000000025'), 'ok', 'second invitation');
select is(public.invite_member('00000000-0000-4000-b000-000000000011', 'weg.test@navora.test', 'coach', 'Wanda Weg', null, null,
          'a2500000-0000-4000-8000-000000000026'), 'ok', 'third invitation');
select is(public.revoke_invitation((select id from public.member_invitations where email = 'weg.test@navora.test'),
          'a2500000-0000-4000-8000-000000000027'), 'ok', 'the administrator revokes an invitation');
select is(public.revoke_invitation((select id from public.member_invitations where email = 'weg.test@navora.test'),
          'a2500000-0000-4000-8000-000000000028'), 'wrong_state', 'a revoked invitation cannot be revoked again');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.accept_my_invitations(), 1, 'on first sign-in the invitation is accepted');
select is(public.accept_my_invitations(), 0, 'accepting again changes nothing');
reset role;
select ok((select m.role = 'nurse' from public.organization_memberships m
           where m.organization_id = '00000000-0000-4000-b000-000000000011' and m.user_id = '00000000-0000-4000-a000-000000000906')
          and (select tm.qualification = 'registered_nurse' from public.team_memberships tm
               where tm.team_id = '00000000-0000-4000-a000-000000000101' and tm.user_id = '00000000-0000-4000-a000-000000000906')
          and (select p.display_name = 'Nina Neu' from public.member_profiles p where p.user_id = '00000000-0000-4000-a000-000000000906'),
  'the invitee becomes a member with role, team, qualification and name');
select pg_temp.act_as('00000000-0000-4000-a000-000000000907');
set local role authenticated;
select is(public.accept_my_invitations(), 0, 'an unconfirmed email accepts nothing');
reset role;

-- Roles and team memberships ------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select throws_ok($$ select public.set_member_role('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000904', 'coach', null,
          'a2500000-0000-4000-8000-000000000030') $$, '22023', null, 'a role change needs a reason');
select is(public.set_member_role('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000904', 'coach', 'Wechsel ins Coaching',
          'a2500000-0000-4000-8000-000000000031'), 'ok', 'the administrator changes a role with a reason');
select is(public.set_member_role('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000905', 'nurse', 'Selbstversuch',
          'a2500000-0000-4000-8000-000000000032'), 'last_admin', 'the last administrator cannot be demoted');
select is(public.add_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant',
          'a2500000-0000-4000-8000-000000000033'), 'ok', 'the administrator adds a member to a team');
select is(public.add_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant',
          'a2500000-0000-4000-8000-000000000034'), 'already_member', 'a member is added once');
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902', 'Teamwechsel',
          'a2500000-0000-4000-8000-000000000035'), 'has_cases', 'a primary nurse of an open case is not removed before the hand-over');
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'Nur Aushilfe',
          'a2500000-0000-4000-8000-000000000036'), 'ok', 'the administrator removes a member with a reason');
reset role;
select is((select count(*)::int from public.change_log where command in ('set_member_role', 'remove_team_member')), 2,
  'role change and removal are logged with their reasons');

-- Teams ------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.create_team('00000000-0000-4000-b000-000000000011', 'Testteam Süd', 'Zürich Süd', 'a2500000-0000-4000-8000-000000000040'),
  'ok', 'the administrator creates a team');
select is(public.create_team('00000000-0000-4000-b000-000000000011', 'testteam süd', 'Zürich', 'a2500000-0000-4000-8000-000000000041'),
  'name_taken', 'team names are unique in the organisation');
select is(public.update_team((select id from public.teams where name = 'Testteam Süd'), 'Testteam Süd-West', 'Zürich West',
          'a2500000-0000-4000-8000-000000000042'), 'ok', 'renames it and sets the region');
select is(public.deactivate_team('00000000-0000-4000-a000-000000000101', 'Auflösung', 'a2500000-0000-4000-8000-000000000043'),
  'has_cases', 'a team with open cases is not deactivated');
select is(public.deactivate_team((select id from public.teams where name = 'Testteam Süd-West'), 'Pilot beendet',
          'a2500000-0000-4000-8000-000000000044'), 'ok', 'a team without open cases is deactivated');
select is(public.add_team_member((select id from public.teams where name = 'Testteam Süd-West'), '00000000-0000-4000-a000-000000000901',
          'care_assistant', 'a2500000-0000-4000-8000-000000000045'), 'rejected', 'a deactivated team takes no new members');
reset role;
select ok((select status = 'closed' and deactivated_at is not null from public.teams where name = 'Testteam Süd-West'),
  'the deactivated team is closed (J2 offers only active teams)');
select ok(exists (select 1 from public.audit_events where command = 'create_team'), 'team creation is audited');

-- Operating rules --------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_response_deadline('00000000-0000-4000-b000-000000000011', 'private', 3, 'working_days',
          'a2500000-0000-4000-8000-000000000050'), 'ok', 'the administrator changes a response deadline');
select ok((select not is_default and amount = 3 and updated_at is not null from public.admin_response_deadlines('00000000-0000-4000-b000-000000000011')
           where referral_type = 'private'), 'the change shows with who and when');
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'visit_uncovered_hospital', 'P2', 24, null,
          'a2500000-0000-4000-8000-000000000051'), 'out_of_range', 'a P1 safety rule cannot be lowered');
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'visit_uncovered_hospital', 'P1', 48, null,
          'a2500000-0000-4000-8000-000000000052'), 'out_of_range', 'a P1 safety alert cannot come later');
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'visit_uncovered_hospital', 'P1', 12, null,
          'a2500000-0000-4000-8000-000000000053'), 'ok', 'it can come earlier');
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'visit_uncovered', 'P2', 49, null,
          'a2500000-0000-4000-8000-000000000054'), 'out_of_range', 'other thresholds at most twice the default');
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'quality_serious_open', 'P2', null, 8,
          'a2500000-0000-4000-8000-000000000055'), 'out_of_range', 'escalation of serious quality events never later');
select ok((select not is_default and amount = 12 and updated_by_name is not null
           from public.admin_exception_rules('00000000-0000-4000-b000-000000000011') where exception_type = 'visit_uncovered_hospital'),
  'the override shows with who and when');
reset role;
select is((select amount from private.effective_exception_rules('00000000-0000-4000-b000-000000000011')
           where exception_type = 'visit_uncovered_hospital'), 12, 'the organisation''s exceptions use the override');
select is((select amount from private.effective_exception_rules('00000000-0000-4000-b000-000000000012')
           where exception_type = 'visit_uncovered_hospital'), 24, 'other organisations keep the default');
select lives_ok($$ select * from private.derived_exceptions('00000000-0000-4000-b000-000000000011') $$, 'exception derivation runs with overrides');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.reset_exception_rule('00000000-0000-4000-b000-000000000011', 'visit_uncovered_hospital', 'a2500000-0000-4000-8000-000000000056'),
  'ok', 'back to the platform default');
reset role;

select * from finish();
rollback;
