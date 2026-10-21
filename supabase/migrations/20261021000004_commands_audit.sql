-- =============================================================================
-- T10 — Audited, idempotent commands and a DB-enforced visit state machine
-- (ADR-003 as amended by ADR-019)
-- =============================================================================
-- 1. audit_events: append-only, written ONLY by a SECURITY DEFINER trigger on
--    teams and care_visits — every UPDATE is audited, whichever path it takes
--    (app command, direct REST call, future service). App users cannot insert,
--    change or delete audit rows. Only allowlisted columns are recorded, so no
--    free-text or health data enters the audit log.
-- 2. Command functions (SECURITY INVOKER: RLS from T9 stays the authority) with
--    an idempotency key. A replayed key returns 'duplicate' and changes nothing.
-- 3. Visit transitions for app users are limited to planned→started→completed
--    by a trigger, including direct REST updates.
-- 4. `billable` can no longer be changed by app users (SR-09). Billing facts
--    are derived later from validated time, approved documentation and tariff
--    rules (DOMAIN_RULES, DECIDED) — not part of this task.
-- =============================================================================

-- 1. Audit log -----------------------------------------------------------------
create table public.audit_events (
  id              bigint generated always as identity primary key,
  occurred_at     timestamptz not null default now(),
  organization_id uuid not null references public.organizations (id),
  actor_id        uuid,               -- auth.uid(); null for maintenance by database roles
  actor_role      text not null,      -- database role that executed the change
  table_name      text not null,
  entity_id       uuid not null,
  command         text,               -- set by command functions; null for other paths
  idempotency_key uuid,
  changed         jsonb not null      -- {"column": {"old": …, "new": …}} for allowlisted columns only
);

create index on public.audit_events (organization_id, occurred_at desc);
create index on public.audit_events (table_name, entity_id);
create unique index audit_events_actor_idempotency_key
  on public.audit_events (actor_id, idempotency_key)
  where idempotency_key is not null;

alter table public.audit_events enable row level security;
revoke all on public.audit_events from anon, authenticated;
grant select on public.audit_events to authenticated;

-- Placeholder (Q4): only organisation admins read the audit log.
create policy org_admins_read_audit on public.audit_events
  for select to authenticated
  using (private.has_org_role(organization_id, array['admin']));

-- Append-only, also for the table owner (TRUNCATE included).
create function private.forbid_audit_change()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  raise exception 'audit_events is append-only' using errcode = '42501';
end;
$$;

create trigger audit_events_no_update_delete
  before update or delete on public.audit_events
  for each row execute function private.forbid_audit_change();
create trigger audit_events_no_truncate
  before truncate on public.audit_events
  for each statement execute function private.forbid_audit_change();

-- Writer: called by triggers only. Columns to record come from TG_ARGV.
create function private.write_audit_event()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  col     text;
  diff    jsonb := '{}'::jsonb;
  old_row jsonb := to_jsonb(old);
  new_row jsonb := to_jsonb(new);
  key_txt text  := nullif(current_setting('navora.idempotency_key', true), '');
begin
  foreach col in array tg_argv loop
    if old_row -> col is distinct from new_row -> col then
      diff := diff || jsonb_build_object(col, jsonb_build_object('old', old_row -> col, 'new', new_row -> col));
    end if;
  end loop;

  insert into public.audit_events
    (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values
    -- current_user is the function owner here (SECURITY DEFINER), so the
    -- caller's role comes from the request's JWT claims.
    (new.organization_id, (select auth.uid()),
     coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', session_user::text),
     tg_table_name, new.id,
     nullif(current_setting('navora.command', true), ''), key_txt::uuid, diff);

  return new;
end;
$$;

revoke all on function private.write_audit_event(), private.forbid_audit_change() from public, anon, authenticated;

create trigger audit_teams
  after update on public.teams
  for each row execute function private.write_audit_event('priority', 'coach_name', 'status', 'open_slots', 'utilization');

create trigger audit_care_visits
  after update on public.care_visits
  for each row execute function private.write_audit_event('status', 'billable', 'team_id', 'visit_date', 'time_start', 'time_end');

-- 2. Visit state machine for app users ------------------------------------------
-- Only the transitions the app implements are allowed for the `authenticated`
-- role. The full field-tool state machine (DOMAIN_RULES draft) needs product /
-- clinical confirmation first (BACKLOG F2). Database maintenance roles are not
-- restricted, and every change they make is still audited.
create function private.enforce_visit_transition()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' and new.status is distinct from old.status then
    if not ((old.status, new.status) in (('planned', 'started'), ('started', 'completed'))) then
      raise exception 'visit transition % -> % is not allowed', old.status, new.status
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_visit_transition() from public, anon, authenticated;

create trigger care_visits_enforce_transition
  before update of status on public.care_visits
  for each row execute function private.enforce_visit_transition();

-- 3. billable is not writable by app users (SR-09) ------------------------------
revoke update on public.care_visits from authenticated;
grant update (status) on public.care_visits to authenticated;

-- 4. Command functions ------------------------------------------------------------
-- Return codes: 'ok' | 'duplicate' (idempotency key already applied by this
-- user — nothing changed) | 'rejected' (row not visible/permitted by RLS or not
-- in the expected state). Invalid input raises 22023.

create function private.begin_command(p_command text, p_key uuid)
returns boolean   -- true = this user already applied this key
language plpgsql security definer set search_path = ''
as $$
begin
  if p_key is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;
  -- Transaction-local; read by private.write_audit_event().
  perform set_config('navora.command', p_command, true);
  perform set_config('navora.idempotency_key', p_key::text, true);
  return exists (
    select 1 from public.audit_events a
    where a.actor_id = (select auth.uid()) and a.idempotency_key = p_key
  );
end;
$$;

revoke all on function private.begin_command(text, uuid) from public, anon;
grant execute on function private.begin_command(text, uuid) to authenticated;

-- Clears the command context so a later statement in the same transaction is
-- never attributed to this command (found by pgTAP: the settings are
-- transaction-local and would otherwise outlive the function call).
create function private.end_command(p_result text)
returns text
language plpgsql set search_path = ''
as $$
begin
  perform set_config('navora.command', '', true);
  perform set_config('navora.idempotency_key', '', true);
  return p_result;
end;
$$;

revoke all on function private.end_command(text) from public, anon;
grant execute on function private.end_command(text) to authenticated;

create function public.set_team_priority(p_team_id uuid, p_priority boolean, p_idempotency_key uuid)
returns text
language plpgsql security invoker set search_path = ''
as $$
begin
  if p_priority is null then
    raise exception 'priority is required' using errcode = '22023';
  end if;
  if private.begin_command('set_team_priority', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  update public.teams set priority = p_priority where id = p_team_id;
  return private.end_command(case when found then 'ok' else 'rejected' end);
end;
$$;

create function public.assign_team_coach(p_team_id uuid, p_coach_name text, p_idempotency_key uuid)
returns text
language plpgsql security invoker set search_path = ''
as $$
declare
  name_clean text := btrim(p_coach_name);
begin
  if name_clean is null or length(name_clean) not between 1 and 120 then
    raise exception 'coach name must have 1–120 characters' using errcode = '22023';
  end if;
  if private.begin_command('assign_team_coach', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  update public.teams set coach_name = name_clean where id = p_team_id;
  return private.end_command(case when found then 'ok' else 'rejected' end);
end;
$$;

create function public.start_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security invoker set search_path = ''
as $$
begin
  if private.begin_command('start_visit', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  update public.care_visits set status = 'started'
  where id = p_visit_id and status = 'planned';
  return private.end_command(case when found then 'ok' else 'rejected' end);
end;
$$;

create function public.complete_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security invoker set search_path = ''
as $$
begin
  if private.begin_command('complete_visit', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  -- No billable flag here (SR-09): completion is not a billing fact.
  update public.care_visits set status = 'completed'
  where id = p_visit_id and status = 'started';
  return private.end_command(case when found then 'ok' else 'rejected' end);
end;
$$;

revoke all on function
  public.set_team_priority(uuid, boolean, uuid),
  public.assign_team_coach(uuid, text, uuid),
  public.start_visit(uuid, uuid),
  public.complete_visit(uuid, uuid)
from public, anon;
grant execute on function
  public.set_team_priority(uuid, boolean, uuid),
  public.assign_team_coach(uuid, text, uuid),
  public.start_visit(uuid, uuid),
  public.complete_visit(uuid, uuid)
to authenticated;

-- 5. Future functions in public are not executable by anon by default.
alter default privileges for role postgres in schema public revoke execute on functions from anon, public;
