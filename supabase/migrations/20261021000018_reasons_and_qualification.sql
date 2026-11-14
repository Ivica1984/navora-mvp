-- =============================================================================
-- F0 remainder (brief docs/agents/briefs/F0.md, PO update 22:20 item 2; D-5 decided)
-- =============================================================================
-- Design (ADR-034):
-- * Mandatory reasons. Product rule (PO): a reason is mandatory when a command changes or
--   undoes something already recorded, or overrides a safety or billing rule; not for
--   forward steps. Commands that already require one: time corrections, plan move/remove,
--   care-plan retirement, team decline, report correction. Added here:
--     - changing insurer, insurance type or medical-order status on a case that is already
--       ready for matching (update_case_intake);
--     - changing a member's qualification (set_member_qualification, new).
--   Not built yet, so nothing to enforce today: case pause/close/reopen, visit cancellation
--   and no-show, lifting a quality hold (QG1). A structural pgTAP guard requires a p_reason
--   argument on any future command with such a name.
-- * change_log: append-only "why" next to the audit trail (who, when, what old → new, reason).
-- * Qualification (D-5): every team member has exactly one qualification; only NAVORA
--   administrators (role admin of the team's organisation) set or change it, with a reason;
--   the member's own team and the organisation's coordination roles read it; nobody outside.
-- * One shared rule: private.is_registered_nurse(team, user) is the only place that reads the
--   qualification for J2 (eligibility) and J3 (category B, needs assessment).
-- =============================================================================

-- 1. change_log ------------------------------------------------------------------------------------
create table public.change_log (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id),
  entity_table    text not null,
  entity_id       text not null,
  command         text not null,
  changes         jsonb not null,                 -- {"field": {"old": …, "new": …}}
  reason          text not null check (char_length(btrim(reason)) between 3 and 300),
  actor_id        uuid not null,
  idempotency_key uuid not null,
  created_at      timestamptz not null default now(),
  unique (actor_id, idempotency_key)
);
comment on table public.change_log is
  'F0: append-only reasons for changes to recorded facts (PO rule). Complements audit_events.';

alter table public.change_log enable row level security;
revoke all on public.change_log from anon, authenticated;
grant select on public.change_log to authenticated;
create policy coordinators_read on public.change_log
  for select to authenticated using (private.is_coordinator(organization_id));

create trigger change_log_no_update_delete
  before update or delete on public.change_log
  for each row execute function private.forbid_audit_change();
create trigger change_log_no_truncate
  before truncate on public.change_log
  for each statement execute function private.forbid_audit_change();

-- 2. Reason when changing funding facts on a case that is ready for matching ---------------------------
drop function public.update_case_intake(uuid, jsonb, uuid);

create function public.update_case_intake(p_case_id uuid, p_facts jsonb, p_idempotency_key uuid, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  c       public.cases%rowtype;
  after   public.cases%rowtype;
  missing jsonb;
  diff    jsonb := '{}'::jsonb;
  why     text := nullif(btrim(p_reason), '');
  f       text;
begin
  if (select auth.uid()) is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  if why is not null and char_length(why) not between 3 and 300 then
    raise exception 'reason needs 3–300 characters' using errcode = '22023';
  end if;
  if private.begin_command('update_case_intake', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate', 'case_id', p_case_id);
  end if;

  select * into c from public.cases where id = p_case_id for update;
  if not found or not private.is_intake_role(c.organization_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;

  perform private.apply_case_facts(c.id, p_facts);
  select * into after from public.cases where id = c.id;

  -- PO rule: changing recorded funding facts after the case went to matching needs a reason.
  if c.ready_for_matching_at is not null then
    foreach f in array array['insurer_name', 'insurance_type', 'medical_order_status'] loop
      if to_jsonb(c) -> f is distinct from to_jsonb(after) -> f then
        diff := diff || jsonb_build_object(f, jsonb_build_object('old', to_jsonb(c) -> f, 'new', to_jsonb(after) -> f));
      end if;
    end loop;
    if diff <> '{}'::jsonb then
      if why is null then
        raise exception 'changing insurer, insurance type or order status on a ready case needs a reason' using errcode = '22023';
      end if;
      insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
      values (c.organization_id, 'cases', c.id::text, 'update_case_intake', diff, why, (select auth.uid()), p_idempotency_key);
    end if;
  end if;

  perform private.sync_case_tasks(c.id);
  missing := private.open_matching_if_ready(c.id);

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'case_id', c.id,
                            'ready', jsonb_array_length(missing) = 0, 'missing', missing);
end;
$$;
revoke all on function public.update_case_intake(uuid, jsonb, uuid, text) from public, anon;
grant execute on function public.update_case_intake(uuid, jsonb, uuid, text) to authenticated;

-- 3. Qualification (D-5) ----------------------------------------------------------------------------------
-- Exactly one qualification per member. Rows without one get the less privileged value; there
-- are none in the seed, and live memberships are not migrated from here (ADR-022).
update public.team_memberships set qualification = 'care_assistant' where qualification is null;
alter table public.team_memberships alter column qualification set not null;

create function private.team_organization(p_team uuid)
returns uuid language sql stable security definer set search_path = ''
as $$ select t.organization_id from public.teams t where t.id = p_team $$;
revoke all on function private.team_organization(uuid) from public, anon;
grant execute on function private.team_organization(uuid) to authenticated;

-- Read: own row (existing policy), the member's own team, coordination roles of the organisation.
create policy team_members_read on public.team_memberships
  for select to authenticated using (private.is_team_member(team_id));
create policy coordinators_read on public.team_memberships
  for select to authenticated using (private.is_coordinator(private.team_organization(team_id)));

create function public.set_member_qualification(
  p_team_id uuid, p_user_id uuid, p_qualification text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  org  uuid := private.team_organization(p_team_id);
  old  text;
  why  text;
begin
  if uid is null then return 'rejected'; end if;
  if p_qualification is null or p_qualification not in ('registered_nurse', 'care_assistant') then
    raise exception 'qualification must be registered_nurse or care_assistant' using errcode = '22023';
  end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('set_member_qualification', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if org is null or not private.has_org_role(org, array['admin']) then
    return private.end_command('rejected');
  end if;
  select m.qualification into old from public.team_memberships m
    where m.team_id = p_team_id and m.user_id = p_user_id for update;
  if not found then
    return private.end_command('rejected');
  end if;
  if old = p_qualification then
    return private.end_command('unchanged');
  end if;
  update public.team_memberships set qualification = p_qualification
    where team_id = p_team_id and user_id = p_user_id;
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'team_memberships', p_team_id::text || '/' || p_user_id::text, 'set_member_qualification',
          jsonb_build_object('qualification', jsonb_build_object('old', old, 'new', p_qualification)), why, uid, p_idempotency_key);
  -- Duplicate detection reads audit_events (begin_command); record the command there too.
  insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values (org, uid, 'authenticated', 'team_memberships', p_team_id, 'set_member_qualification', p_idempotency_key,
          jsonb_build_object('user_id', p_user_id, 'qualification', jsonb_build_object('old', old, 'new', p_qualification)));
  return private.end_command('ok');
end;
$$;
revoke all on function public.set_member_qualification(uuid, uuid, text, text, uuid) from public, anon;
grant execute on function public.set_member_qualification(uuid, uuid, text, text, uuid) to authenticated;

-- 4. One shared qualification rule for J2 and J3 ---------------------------------------------------------------
create or replace function private.team_has_registered_nurse(p_team uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.team_memberships m
                     where m.team_id = p_team and private.is_registered_nurse(m.team_id, m.user_id)) $$;
