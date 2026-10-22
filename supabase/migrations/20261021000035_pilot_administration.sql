-- ADM1: pilot administration — member profiles, invitations, teams and operating rules
-- (PO brief docs/agents/briefs/ADM1.md, ADR-046).
--
-- * Profiles (answer to the brief's question): a separate table `member_profiles`, keyed by
--   (organization, user) and bound to the organisation membership. It holds a display name only,
--   never health data. Readable by members of the same organisation, written only by commands.
--   No names are invented: members without a profile keep the neutral labels.
-- * Invitations: an administrator records an invitation (email, role, optional team and
--   qualification, display name). The app sends the sign-in link through Supabase Auth; on the
--   first sign-in with that confirmed email, `accept_my_invitations()` creates the memberships.
--   No service-role key is needed.
-- * Members and teams: role change (never the last administrator), team membership add/remove
--   (removal refused while the person is primary nurse or deputy of an open case of the team),
--   qualification (existing F0 command), team create, rename/region, deactivate (refused while the
--   team has open cases; a deactivated team is `status = 'closed'`, which J2 already excludes).
-- * Operating rules: response deadlines (existing J2 command, now with history) and organisation
--   overrides of exception thresholds and priorities within safe ranges:
--     - priority never below the platform default (P1 stays P1);
--     - threshold for a P1-default rule never above the default (alert never later);
--     - other thresholds 0 … 2 × default (max 720), same unit; escalation hours never above the default.
--   Ranges are an engineering default (D-21 for the PO); they only restrict.
-- * Tariffs and reference data (J5) stay migration-only: no command touches them.
-- * Every command: admin of the organisation only, idempotent, audited; reasons where the F0
--   rule requires one (qualification, role, removal, deactivation).

-- 0. Helpers ----------------------------------------------------------------------------------------------------
create function private.is_org_admin(org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select org is not null and private.has_org_role(org, array['admin']) $$;
revoke all on function private.is_org_admin(uuid) from public, anon;
grant execute on function private.is_org_admin(uuid) to authenticated;

-- Writes one audit row for a command (duplicate detection reads audit_events by actor and key).
create function private.audit_command(p_org uuid, p_table text, p_entity uuid, p_changed jsonb)
returns void language sql security definer set search_path = ''
as $$
  insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values (p_org, (select auth.uid()), 'authenticated', p_table, p_entity,
          nullif(current_setting('navora.command', true), ''),
          nullif(current_setting('navora.idempotency_key', true), '')::uuid, coalesce(p_changed, '{}'::jsonb));
$$;
revoke all on function private.audit_command(uuid, text, uuid, jsonb) from public, anon, authenticated;

-- 1. Member profiles ---------------------------------------------------------------------------------------------
create table public.member_profiles (
  id              uuid not null default gen_random_uuid() unique,
  organization_id uuid not null,
  user_id         uuid not null,
  display_name    text not null check (char_length(btrim(display_name)) between 2 and 80),
  updated_by      uuid,
  updated_at      timestamptz not null default now(),
  primary key (organization_id, user_id),
  foreign key (organization_id, user_id) references public.organization_memberships (organization_id, user_id) on delete cascade
);
comment on table public.member_profiles is
  'ADM1: display name per organisation member. No health data. Written only by commands.';

alter table public.member_profiles enable row level security;
revoke all on public.member_profiles from anon, authenticated;
grant select on public.member_profiles to authenticated;
create policy org_members_read on public.member_profiles
  for select to authenticated using (private.is_org_member(organization_id));

create trigger audit_member_profiles
  after insert or update on public.member_profiles
  for each row execute function private.write_audit_event('display_name');

create function private.member_name(p_org uuid, p_user uuid)
returns text language sql stable security definer set search_path = ''
as $$ select p.display_name from public.member_profiles p where p.organization_id = p_org and p.user_id = p_user $$;
-- Only for SECURITY DEFINER readers that already scope the caller; never callable directly.
revoke all on function private.member_name(uuid, uuid) from public, anon, authenticated;

-- An administrator names any member; a member may set their own name.
-- Return: 'ok' | 'unchanged' | 'duplicate' | 'rejected'
create function public.set_display_name(p_organization_id uuid, p_user_id uuid, p_display_name text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  v_name text;
  old    text;
begin
  if uid is null then return 'rejected'; end if;
  v_name := private.check_text(p_display_name, 2, 80, 'display name');
  if private.begin_command('set_display_name', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not (private.is_org_admin(p_organization_id) or (p_user_id = uid and private.is_org_member(p_organization_id)))
     or not exists (select 1 from public.organization_memberships m
                    where m.organization_id = p_organization_id and m.user_id = p_user_id) then
    return private.end_command('rejected');
  end if;
  select p.display_name into old from public.member_profiles p
    where p.organization_id = p_organization_id and p.user_id = p_user_id for update;
  if old = v_name then
    return private.end_command('unchanged');
  end if;
  insert into public.member_profiles (organization_id, user_id, display_name, updated_by)
  values (p_organization_id, p_user_id, v_name, uid)
  on conflict (organization_id, user_id) do update set display_name = excluded.display_name, updated_by = uid, updated_at = now();
  return private.end_command('ok');
end;
$$;

-- 2. Invitations ----------------------------------------------------------------------------------------------
create table public.member_invitations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  email           text not null check (email = lower(btrim(email)) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  role            text not null check (role in ('admin', 'coach', 'operations', 'nurse')),
  display_name    text not null check (char_length(btrim(display_name)) between 2 and 80),
  team_id         uuid references public.teams (id),
  qualification   text check (qualification in ('registered_nurse', 'care_assistant')),
  invited_by      uuid not null,
  created_at      timestamptz not null default now(),
  expires_at      timestamptz not null default now() + interval '14 days',
  accepted_at     timestamptz,
  accepted_user   uuid,
  revoked_at      timestamptz,
  check ((team_id is null) = (qualification is null))
);
create unique index member_invitations_one_open on public.member_invitations (organization_id, email)
  where accepted_at is null and revoked_at is null;
comment on table public.member_invitations is
  'ADM1: invitations by NAVORA administrators. Accepted on first sign-in with the confirmed email.';

alter table public.member_invitations enable row level security;
revoke all on public.member_invitations from anon, authenticated;
grant select on public.member_invitations to authenticated;
create policy admins_read on public.member_invitations
  for select to authenticated using (private.is_org_admin(organization_id));

create trigger audit_member_invitations
  after insert or update on public.member_invitations
  for each row execute function private.write_audit_event('email', 'role', 'team_id', 'qualification', 'accepted_at', 'revoked_at');

-- Return: 'ok' | 'already_member' | 'already_invited' | 'duplicate' | 'rejected'
create function public.invite_member(
  p_organization_id uuid, p_email text, p_role text, p_display_name text,
  p_team_id uuid, p_qualification text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  mail  text := lower(btrim(p_email));
  v_name text;
begin
  if uid is null then return 'rejected'; end if;
  if mail is null or mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or char_length(mail) > 254 then
    raise exception 'a valid email is required' using errcode = '22023';
  end if;
  if p_role is null or p_role not in ('admin', 'coach', 'operations', 'nurse') then
    raise exception 'role must be admin, coach, operations or nurse' using errcode = '22023';
  end if;
  if (p_team_id is null) <> (p_qualification is null)
     or (p_qualification is not null and p_qualification not in ('registered_nurse', 'care_assistant')) then
    raise exception 'a team membership needs a qualification (registered_nurse, care_assistant)' using errcode = '22023';
  end if;
  v_name := private.check_text(p_display_name, 2, 80, 'display name');
  if private.begin_command('invite_member', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id)
     or (p_team_id is not null and private.team_organization(p_team_id) is distinct from p_organization_id) then
    return private.end_command('rejected');
  end if;
  if exists (select 1 from public.organization_memberships m join auth.users u on u.id = m.user_id
             where m.organization_id = p_organization_id and lower(u.email) = mail) then
    return private.end_command('already_member');
  end if;
  if exists (select 1 from public.member_invitations i
             where i.organization_id = p_organization_id and i.email = mail
               and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()) then
    return private.end_command('already_invited');
  end if;
  -- An expired open invitation is closed so the new one can be recorded.
  update public.member_invitations set revoked_at = now()
    where organization_id = p_organization_id and email = mail and accepted_at is null and revoked_at is null;
  insert into public.member_invitations (organization_id, email, role, display_name, team_id, qualification, invited_by)
  values (p_organization_id, mail, p_role, v_name, p_team_id, p_qualification, uid);
  return private.end_command('ok');
end;
$$;

-- Return: 'ok' | 'wrong_state' | 'duplicate' | 'rejected'
create function public.revoke_invitation(p_invitation_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  inv public.member_invitations;
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('revoke_invitation', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into inv from public.member_invitations where id = p_invitation_id for update;
  if not found or not private.is_org_admin(inv.organization_id) then
    return private.end_command('rejected');
  end if;
  if inv.accepted_at is not null or inv.revoked_at is not null then
    return private.end_command('wrong_state');
  end if;
  update public.member_invitations set revoked_at = now() where id = inv.id;
  return private.end_command('ok');
end;
$$;

-- Called by the app after every sign-in. Accepts the caller's open invitations, matched on the
-- confirmed email of the Auth account. Returns how many were accepted. Naturally idempotent.
create function public.accept_my_invitations()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  mail text;
  inv  public.member_invitations;
  n    integer := 0;
begin
  if uid is null then return 0; end if;
  select lower(u.email) into mail from auth.users u where u.id = uid and u.email_confirmed_at is not null;
  if mail is null then return 0; end if;
  for inv in
    select * from public.member_invitations i
    where i.email = mail and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
    order by i.created_at
    for update
  loop
    perform set_config('navora.command', 'accept_invitation', true);
    insert into public.organization_memberships (organization_id, user_id, role)
    values (inv.organization_id, uid, inv.role)
    on conflict (organization_id, user_id) do nothing;
    insert into public.member_profiles (organization_id, user_id, display_name, updated_by)
    values (inv.organization_id, uid, inv.display_name, inv.invited_by)
    on conflict (organization_id, user_id) do nothing;
    if inv.team_id is not null then
      insert into public.team_memberships (team_id, user_id, qualification)
      values (inv.team_id, uid, inv.qualification)
      on conflict (team_id, user_id) do nothing;
    end if;
    update public.member_invitations set accepted_at = now(), accepted_user = uid where id = inv.id;
    perform private.audit_command(inv.organization_id, 'organization_memberships', inv.id,
      jsonb_build_object('user_id', uid, 'role', inv.role, 'team_id', inv.team_id, 'qualification', inv.qualification));
    perform set_config('navora.command', '', true);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- 3. Roles and team memberships -------------------------------------------------------------------------------
-- Return: 'ok' | 'unchanged' | 'last_admin' | 'duplicate' | 'rejected'
create function public.set_member_role(p_organization_id uuid, p_user_id uuid, p_role text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  old text;
  why text;
begin
  if uid is null then return 'rejected'; end if;
  if p_role is null or p_role not in ('admin', 'coach', 'operations', 'nurse') then
    raise exception 'role must be admin, coach, operations or nurse' using errcode = '22023';
  end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('set_member_role', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then
    return private.end_command('rejected');
  end if;
  select m.role into old from public.organization_memberships m
    where m.organization_id = p_organization_id and m.user_id = p_user_id for update;
  if not found then
    return private.end_command('rejected');
  end if;
  if old = p_role then
    return private.end_command('unchanged');
  end if;
  if old = 'admin' and (select count(*) from public.organization_memberships m
                        where m.organization_id = p_organization_id and m.role = 'admin') <= 1 then
    return private.end_command('last_admin');
  end if;
  update public.organization_memberships set role = p_role
    where organization_id = p_organization_id and user_id = p_user_id;
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (p_organization_id, 'organization_memberships', p_user_id::text, 'set_member_role',
          jsonb_build_object('role', jsonb_build_object('old', old, 'new', p_role)), why, uid, p_idempotency_key);
  perform private.audit_command(p_organization_id, 'organization_memberships', p_user_id,
          jsonb_build_object('role', jsonb_build_object('old', old, 'new', p_role)));
  return private.end_command('ok');
end;
$$;

-- Return: 'ok' | 'already_member' | 'duplicate' | 'rejected'
create function public.add_team_member(p_team_id uuid, p_user_id uuid, p_qualification text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid := private.team_organization(p_team_id);
begin
  if uid is null then return 'rejected'; end if;
  if p_qualification is null or p_qualification not in ('registered_nurse', 'care_assistant') then
    raise exception 'qualification must be registered_nurse or care_assistant' using errcode = '22023';
  end if;
  if private.begin_command('add_team_member', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(org)
     or not exists (select 1 from public.organization_memberships m where m.organization_id = org and m.user_id = p_user_id)
     or exists (select 1 from public.teams t where t.id = p_team_id and t.status = 'closed') then
    return private.end_command('rejected');
  end if;
  if exists (select 1 from public.team_memberships m where m.team_id = p_team_id and m.user_id = p_user_id) then
    return private.end_command('already_member');
  end if;
  insert into public.team_memberships (team_id, user_id, qualification) values (p_team_id, p_user_id, p_qualification);
  perform private.audit_command(org, 'team_memberships', p_team_id,
          jsonb_build_object('user_id', p_user_id, 'added', true, 'qualification', p_qualification));
  return private.end_command('ok');
end;
$$;

-- Refused while the person is primary nurse or deputy of an open case of the team (J6 continuity):
-- the team hands the case over first. Return: 'ok' | 'has_cases' | 'duplicate' | 'rejected'
create function public.remove_team_member(p_team_id uuid, p_user_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  org  uuid := private.team_organization(p_team_id);
  why  text;
  qual text;
begin
  if uid is null then return 'rejected'; end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('remove_team_member', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(org) then
    return private.end_command('rejected');
  end if;
  select m.qualification into qual from public.team_memberships m
    where m.team_id = p_team_id and m.user_id = p_user_id for update;
  if not found then
    return private.end_command('rejected');
  end if;
  if exists (select 1 from public.cases c
             where c.assigned_team_id = p_team_id and c.lifecycle <> 'closed'
               and p_user_id in (c.primary_nurse_id, c.deputy_nurse_id)) then
    return private.end_command('has_cases');
  end if;
  delete from public.team_memberships where team_id = p_team_id and user_id = p_user_id;
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'team_memberships', p_team_id::text || '/' || p_user_id::text, 'remove_team_member',
          jsonb_build_object('membership', jsonb_build_object('old', qual, 'new', null)), why, uid, p_idempotency_key);
  perform private.audit_command(org, 'team_memberships', p_team_id,
          jsonb_build_object('user_id', p_user_id, 'removed', true, 'qualification', qual));
  return private.end_command('ok');
end;
$$;

-- 4. Teams ------------------------------------------------------------------------------------------------------
alter table public.teams add column deactivated_at timestamptz;

-- Return: 'ok' | 'name_taken' | 'duplicate' | 'rejected'
create function public.create_team(p_organization_id uuid, p_name text, p_region text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  v_name   text;
  v_region text;
  new_id uuid;
begin
  if uid is null then return 'rejected'; end if;
  v_name := private.check_text(p_name, 2, 80, 'team name');
  v_region := private.check_text(p_region, 2, 80, 'region');
  if private.begin_command('create_team', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then
    return private.end_command('rejected');
  end if;
  if exists (select 1 from public.teams t where t.organization_id = p_organization_id
             and lower(t.name) = lower(v_name) and t.status is distinct from 'closed') then
    return private.end_command('name_taken');
  end if;
  insert into public.teams (organization_id, name, region, status, open_slots, priority)
  values (p_organization_id, v_name, v_region, 'active', 0, false)
  returning id into new_id;
  perform private.audit_command(p_organization_id, 'teams', new_id, jsonb_build_object('name', v_name, 'region', v_region, 'created', true));
  return private.end_command('ok');
end;
$$;

-- Return: 'ok' | 'unchanged' | 'name_taken' | 'duplicate' | 'rejected'
create function public.update_team(p_team_id uuid, p_name text, p_region text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  org    uuid := private.team_organization(p_team_id);
  v_name   text;
  v_region text;
  t      public.teams;
begin
  if uid is null then return 'rejected'; end if;
  v_name := private.check_text(p_name, 2, 80, 'team name');
  v_region := private.check_text(p_region, 2, 80, 'region');
  if private.begin_command('update_team', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(org) then
    return private.end_command('rejected');
  end if;
  select * into t from public.teams where id = p_team_id for update;
  if t.status = 'closed' then
    return private.end_command('rejected');
  end if;
  if t.name = v_name and t.region is not distinct from v_region then
    return private.end_command('unchanged');
  end if;
  if exists (select 1 from public.teams x where x.organization_id = org and x.id <> p_team_id
             and lower(x.name) = lower(v_name) and x.status is distinct from 'closed') then
    return private.end_command('name_taken');
  end if;
  update public.teams set name = v_name, region = v_region where id = p_team_id;
  perform private.audit_command(org, 'teams', p_team_id, jsonb_build_object(
    'name', jsonb_build_object('old', t.name, 'new', v_name), 'region', jsonb_build_object('old', t.region, 'new', v_region)));
  return private.end_command('ok');
end;
$$;

-- Refused while the team has open (active or paused) cases: they are handed over first.
-- Return: 'ok' | 'has_cases' | 'wrong_state' | 'duplicate' | 'rejected'
create function public.deactivate_team(p_team_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid := private.team_organization(p_team_id);
  why text;
  t   public.teams;
begin
  if uid is null then return 'rejected'; end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('deactivate_team', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(org) then
    return private.end_command('rejected');
  end if;
  select * into t from public.teams where id = p_team_id for update;
  if t.status = 'closed' then
    return private.end_command('wrong_state');
  end if;
  if exists (select 1 from public.cases c where c.assigned_team_id = p_team_id and c.lifecycle <> 'closed') then
    return private.end_command('has_cases');
  end if;
  update public.teams set status = 'closed', deactivated_at = now() where id = p_team_id;
  -- Open offers to this team lapse: J2 eligibility already requires status 'active'.
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'teams', p_team_id::text, 'deactivate_team',
          jsonb_build_object('status', jsonb_build_object('old', t.status, 'new', 'closed')), why, uid, p_idempotency_key);
  return private.end_command('ok');   -- audited by the teams trigger (status)
end;
$$;

-- 5. Response deadlines: who changed what and when ------------------------------------------------------------
-- The J2 command already records updated_by/updated_at and audits; the list for the admin area:
create function public.admin_response_deadlines(p_organization_id uuid)
returns table (referral_type text, amount integer, unit text, is_default boolean,
               default_amount integer, default_unit text, updated_by_name text, updated_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select d.referral_type,
         coalesce(o.amount, d.amount), coalesce(o.unit, d.unit), o.id is null,
         d.amount, d.unit,
         case when o.id is not null then coalesce(private.member_name(p_organization_id, o.updated_by), 'Administration') end,
         o.updated_at
  from public.response_deadlines d
  left join public.response_deadlines o on o.organization_id = p_organization_id and o.referral_type = d.referral_type
  where d.organization_id is null and private.is_org_admin(p_organization_id)
  order by d.referral_type;
$$;

-- 6. Exception thresholds and priorities per organisation ----------------------------------------------------
create table public.exception_rule_overrides (
  id                         uuid primary key default gen_random_uuid(),
  organization_id            uuid not null references public.organizations (id),
  exception_type             text not null references public.exception_rules (exception_type),
  priority                   text not null check (priority in ('P1', 'P2', 'P3')),
  amount                     integer check (amount is null or amount between 0 and 720),
  escalate_to_p1_after_hours integer check (escalate_to_p1_after_hours is null or escalate_to_p1_after_hours between 0 and 720),
  updated_by                 uuid not null,
  updated_at                 timestamptz not null default now(),
  unique (organization_id, exception_type)
);
comment on table public.exception_rule_overrides is
  'ADM1: organisation overrides of the OPS1 exception rules, within the safe ranges of private.exception_rule_range.';

alter table public.exception_rule_overrides enable row level security;
revoke all on public.exception_rule_overrides from anon, authenticated;
grant select on public.exception_rule_overrides to authenticated;
create policy coordinators_read on public.exception_rule_overrides
  for select to authenticated using (private.is_coordinator(organization_id));

create trigger audit_exception_rule_overrides
  after insert or update on public.exception_rule_overrides
  for each row execute function private.write_audit_event('priority', 'amount', 'escalate_to_p1_after_hours');

-- Safe range for an override (engineering default, D-21).
create function private.exception_rule_range(p_type text)
returns table (min_priority_rank integer, max_amount integer, max_escalate integer)
language sql stable security definer set search_path = ''
as $$
  select case r.priority when 'P1' then 1 when 'P2' then 2 else 3 end,
         case when r.amount is null then null
              when r.priority = 'P1' then r.amount
              else least(720, greatest(r.amount * 2, 1)) end,
         r.escalate_to_p1_after_hours
  from public.exception_rules r where r.exception_type = p_type
$$;
revoke all on function private.exception_rule_range(text) from public, anon, authenticated;

-- Effective rules of an organisation: platform default with the organisation's override.
create function private.effective_exception_rules(p_org uuid)
returns setof public.exception_rules
language sql stable security definer set search_path = ''
as $$
  select r.exception_type, coalesce(o.priority, r.priority), coalesce(o.amount, r.amount), r.unit,
         case when o.id is null then r.escalate_to_p1_after_hours else o.escalate_to_p1_after_hours end,
         r.label, r.next_step, coalesce(o.updated_at, r.updated_at)
  from public.exception_rules r
  left join public.exception_rule_overrides o on o.organization_id = p_org and o.exception_type = r.exception_type
$$;
revoke all on function private.effective_exception_rules(uuid) from public, anon, authenticated;

-- Return: 'ok' | 'out_of_range' | 'duplicate' | 'rejected'
create function public.set_exception_rule(p_organization_id uuid, p_exception_type text, p_priority text,
                                          p_amount integer, p_escalate_to_p1_after_hours integer, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  def  public.exception_rules;
  rng  record;
  rank integer;
begin
  if uid is null then return 'rejected'; end if;
  select * into def from public.exception_rules where exception_type = p_exception_type;
  if not found or p_priority is null or p_priority not in ('P1', 'P2', 'P3') then
    raise exception 'known exception type and priority (P1, P2, P3) required' using errcode = '22023';
  end if;
  if private.begin_command('set_exception_rule', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then
    return private.end_command('rejected');
  end if;
  select * into rng from private.exception_rule_range(p_exception_type);
  rank := case p_priority when 'P1' then 1 when 'P2' then 2 else 3 end;
  if rank > rng.min_priority_rank
     or (def.amount is null) <> (p_amount is null)
     or (p_amount is not null and p_amount not between 0 and rng.max_amount)
     or (def.escalate_to_p1_after_hours is null and p_escalate_to_p1_after_hours is not null)
     or (def.escalate_to_p1_after_hours is not null
         and (p_escalate_to_p1_after_hours is null or p_escalate_to_p1_after_hours not between 0 and rng.max_escalate)) then
    return private.end_command('out_of_range');
  end if;
  insert into public.exception_rule_overrides (organization_id, exception_type, priority, amount, escalate_to_p1_after_hours, updated_by)
  values (p_organization_id, p_exception_type, p_priority, p_amount, p_escalate_to_p1_after_hours, uid)
  on conflict (organization_id, exception_type) do update
    set priority = excluded.priority, amount = excluded.amount,
        escalate_to_p1_after_hours = excluded.escalate_to_p1_after_hours, updated_by = uid, updated_at = now();
  return private.end_command('ok');
end;
$$;

-- Back to the platform default. Return: 'ok' | 'unchanged' | 'duplicate' | 'rejected'
create function public.reset_exception_rule(p_organization_id uuid, p_exception_type text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  o   public.exception_rule_overrides;
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('reset_exception_rule', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then
    return private.end_command('rejected');
  end if;
  delete from public.exception_rule_overrides
    where organization_id = p_organization_id and exception_type = p_exception_type
    returning * into o;
  if o.id is null then
    return private.end_command('unchanged');
  end if;
  perform private.audit_command(p_organization_id, 'exception_rule_overrides', o.id,
          jsonb_build_object('reset', true, 'exception_type', o.exception_type,
                             'priority', o.priority, 'amount', o.amount, 'escalate_to_p1_after_hours', o.escalate_to_p1_after_hours));
  return private.end_command('ok');
end;
$$;

create function public.admin_exception_rules(p_organization_id uuid)
returns table (exception_type text, label text, unit text,
               priority text, amount integer, escalate_to_p1_after_hours integer, is_default boolean,
               default_priority text, default_amount integer, default_escalate integer,
               max_amount integer, max_escalate integer, updated_by_name text, updated_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select r.exception_type, r.label, r.unit,
         coalesce(o.priority, r.priority), coalesce(o.amount, r.amount),
         case when o.id is null then r.escalate_to_p1_after_hours else o.escalate_to_p1_after_hours end,
         o.id is null, r.priority, r.amount, r.escalate_to_p1_after_hours,
         g.max_amount, g.max_escalate,
         case when o.id is not null then coalesce(private.member_name(p_organization_id, o.updated_by), 'Administration') end,
         o.updated_at
  from public.exception_rules r
  cross join lateral private.exception_rule_range(r.exception_type) g
  left join public.exception_rule_overrides o on o.organization_id = p_organization_id and o.exception_type = r.exception_type
  where private.is_org_admin(p_organization_id)
  order by r.priority, r.exception_type;
$$;

-- 7. Regenerate readers from their current definitions (no hand copy; every patch must match) -------------
-- p_pairs: find1, replace1, find2, replace2, … applied together, then one CREATE (after DROP when the
-- result columns change).
create function private.adm1_patch(p_fn text, p_pairs text[], p_drop boolean default false)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if position(p_pairs[i] in def) = 0 then
      raise exception 'ADM1 patch for % did not match: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if p_drop then
    execute format('drop function %s', p_fn);
  end if;
  execute def;
end;
$$;

-- 7a. Exceptions use the organisation's effective rules; the list names who took an exception over.
select private.adm1_patch('private.derived_exceptions(uuid)', array[
  'with rules as (select * from public.exception_rules)',
  'with rules as (select * from private.effective_exception_rules(p_org))']);
select private.adm1_patch('public.operations_exceptions()', array[
  E'''[]''::jsonb)\n  from d\n  join public.exception_rules r on r.exception_type = d.exception_type',
  E'''[]''::jsonb),\n         case when l.kind = ''take'' then private.member_name(d.organization_id, l.actor_id) end\n  from d\n  join lateral private.effective_exception_rules(d.organization_id) r on r.exception_type = d.exception_type',
  E')\n LANGUAGE sql', E', owner_name text)\n LANGUAGE sql'], true);
revoke all on function public.operations_exceptions() from public, anon;
grant execute on function public.operations_exceptions() to authenticated;

-- 7b. Team view: member names and the responsible member of each upcoming visit (jsonb, same columns).
select private.adm1_patch('public.team_cases()', array[
  E'''me'', m.user_id = (select auth.uid())) order by m.user_id)',
  E'''me'', m.user_id = (select auth.uid()), ''name'', private.member_name(t.organization_id, m.user_id)) order by m.user_id)',
  E'''responsible_set'', x.responsible_user_id is not null,',
  E'''responsible_set'', x.responsible_user_id is not null,\n                    ''responsible_id'', x.responsible_user_id,']);

-- 7c. Report signature and countersignature, quality-event author: names.
select private.adm1_patch('public.field_reports(date)', array[
  E'and private.is_registered_nurse(r.team_id, (select auth.uid()))\n  from public.visit_reports r',
  E'and private.is_registered_nurse(r.team_id, (select auth.uid())),\n         private.member_name(r.organization_id, r.signed_by),\n         private.member_name(r.organization_id, r.countersigned_by)\n  from public.visit_reports r',
  E')\n LANGUAGE sql', E', signed_by_name text, countersigned_by_name text)\n LANGUAGE sql'], true);
revoke all on function public.field_reports(date) from public, anon;
grant execute on function public.field_reports(date) to authenticated;

select private.adm1_patch('public.field_quality(date)', array[
  E'coalesce(q.occurred_at, q.created_at), q.author_id = (select auth.uid())\n',
  E'coalesce(q.occurred_at, q.created_at), q.author_id = (select auth.uid()),\n         private.member_name(v.organization_id, q.author_id)\n',
  E'h.set_by = (select auth.uid())\n',
  E'h.set_by = (select auth.uid()),\n         private.member_name(v.organization_id, h.set_by)\n',
  E')\n LANGUAGE sql', E', person_name text)\n LANGUAGE sql'], true);
revoke all on function public.field_quality(date) from public, anon;
grant execute on function public.field_quality(date) to authenticated;

drop function private.adm1_patch(text, text[], boolean);

-- 8. Grants -----------------------------------------------------------------------------------------------------
revoke all on function
  public.set_display_name(uuid, uuid, text, uuid),
  public.invite_member(uuid, text, text, text, uuid, text, uuid),
  public.revoke_invitation(uuid, uuid),
  public.accept_my_invitations(),
  public.set_member_role(uuid, uuid, text, text, uuid),
  public.add_team_member(uuid, uuid, text, uuid),
  public.remove_team_member(uuid, uuid, text, uuid),
  public.create_team(uuid, text, text, uuid),
  public.update_team(uuid, text, text, uuid),
  public.deactivate_team(uuid, text, uuid),
  public.admin_response_deadlines(uuid),
  public.set_exception_rule(uuid, text, text, integer, integer, uuid),
  public.reset_exception_rule(uuid, text, uuid),
  public.admin_exception_rules(uuid)
from public, anon;
grant execute on function
  public.set_display_name(uuid, uuid, text, uuid),
  public.invite_member(uuid, text, text, text, uuid, text, uuid),
  public.revoke_invitation(uuid, uuid),
  public.accept_my_invitations(),
  public.set_member_role(uuid, uuid, text, text, uuid),
  public.add_team_member(uuid, uuid, text, uuid),
  public.remove_team_member(uuid, uuid, text, uuid),
  public.create_team(uuid, text, text, uuid),
  public.update_team(uuid, text, text, uuid),
  public.deactivate_team(uuid, text, uuid),
  public.admin_response_deadlines(uuid),
  public.set_exception_rule(uuid, text, text, integer, integer, uuid),
  public.reset_exception_rule(uuid, text, uuid),
  public.admin_exception_rules(uuid)
to authenticated;

-- 9. Admin read model: members of the organisation (admin only) ------------------------------------------------
create function public.admin_members(p_organization_id uuid)
returns table (user_id uuid, email text, display_name text, role text, teams jsonb, joined_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select m.user_id, u.email::text, p.display_name, m.role,
         coalesce((select jsonb_agg(jsonb_build_object('team_id', t.id, 'team', t.name, 'qualification', tm.qualification) order by t.name)
                   from public.team_memberships tm join public.teams t on t.id = tm.team_id
                   where tm.user_id = m.user_id and t.organization_id = m.organization_id), '[]'::jsonb),
         m.created_at
  from public.organization_memberships m
  join auth.users u on u.id = m.user_id
  left join public.member_profiles p on p.organization_id = m.organization_id and p.user_id = m.user_id
  where m.organization_id = p_organization_id and private.is_org_admin(p_organization_id)
  order by coalesce(p.display_name, u.email);
$$;
revoke all on function public.admin_members(uuid) from public, anon;
grant execute on function public.admin_members(uuid) to authenticated;
