-- =============================================================================
-- F2 — Visit state machine for the field workflow + append-only visit events
-- (ROADMAP Gate 2 item 2; DOMAIN_RULES "Einsatz und Zeit")
-- =============================================================================
-- Scope (ADR-023):
--   * Implements the linear part of the documented draft:
--       planned → on_the_way → started ↔ paused → completed
--     plus the existing shortcut planned → started (no travel recorded).
--   * NOT included until owner decision D-6: assigned, accepted (assignment
--     model), cancelled, no_show (who may do it, what it triggers).
--   * Every status change of a visit writes exactly one row to
--     public.visit_events (actor, time, idempotency key) — by trigger, in the
--     same transaction, whatever path changed the status. App users cannot
--     write events directly, so the timeline cannot be faked; events are
--     append-only.
--   * Travel / care / pause durations are derived from the events
--     (src/features/field/time.ts). Corrections come as separate, reasoned
--     correction events in F3 — never by editing an event.
-- =============================================================================

-- 1. Event table ------------------------------------------------------------------
create table public.visit_events (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,
  team_id         uuid,
  event_type      text not null check (event_type in ('departed', 'started', 'paused', 'resumed', 'completed')),
  from_status     text not null,
  to_status       text not null,
  occurred_at     timestamptz not null default now(),
  actor_id        uuid,                       -- auth.uid(); null for maintenance by database roles
  command         text,
  idempotency_key uuid,
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id)
);

create index visit_events_visit_idx on public.visit_events (visit_id, occurred_at);

comment on table public.visit_events is
  'F2: append-only visit timeline, written only by trigger on care_visits status changes.';

alter table public.visit_events enable row level security;
revoke all on public.visit_events from anon, authenticated;
grant select on public.visit_events to authenticated;

create policy org_members_read on public.visit_events
  for select to authenticated using (private.is_org_member(organization_id));

-- Append-only, also for database roles that bypass RLS.
create trigger visit_events_no_update_delete
  before update or delete on public.visit_events
  for each row execute function private.forbid_audit_change();
create trigger visit_events_no_truncate
  before truncate on public.visit_events
  for each statement execute function private.forbid_audit_change();

-- 2. Event writer -------------------------------------------------------------------
create function private.write_visit_event()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  kind text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  kind := case
    when new.status = 'on_the_way' then 'departed'
    when new.status = 'started' and old.status = 'paused' then 'resumed'
    when new.status = 'started' then 'started'
    when new.status = 'paused' then 'paused'
    when new.status = 'completed' then 'completed'
  end;

  -- Status changes outside the field workflow (maintenance) are audited
  -- (audit_care_visits) but are not timeline events.
  if kind is null then
    return new;
  end if;

  insert into public.visit_events
    (organization_id, visit_id, team_id, event_type, from_status, to_status,
     actor_id, command, idempotency_key)
  values
    (new.organization_id, new.id, new.team_id, kind, old.status, new.status,
     (select auth.uid()),
     nullif(current_setting('navora.command', true), ''),
     nullif(current_setting('navora.idempotency_key', true), '')::uuid);

  return new;
end;
$$;

revoke all on function private.write_visit_event() from public, anon, authenticated;

create trigger care_visits_write_event
  after update of status on public.care_visits
  for each row execute function private.write_visit_event();

-- 3. State machine for app users (replaces the T10 version) --------------------------
create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' and new.status is distinct from old.status then
    if not ((old.status, new.status) in (
      ('planned',    'on_the_way'),
      ('planned',    'started'),
      ('on_the_way', 'started'),
      ('started',    'paused'),
      ('paused',     'started'),
      ('started',    'completed')
    )) then
      raise exception 'visit transition % -> % is not allowed', old.status, new.status
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

-- 4. Commands -------------------------------------------------------------------------
-- One generic implementation; the named functions keep the RPC surface explicit
-- and typed. Return codes as in T10: 'ok' | 'duplicate' | 'rejected'.
create function private.transition_visit(
  p_command text, p_visit_id uuid, p_from text[], p_to text, p_idempotency_key uuid)
returns text
language plpgsql security invoker set search_path = ''
as $$
begin
  if private.begin_command(p_command, p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  update public.care_visits set status = p_to
  where id = p_visit_id and status = any (p_from);
  return private.end_command(case when found then 'ok' else 'rejected' end);
end;
$$;

revoke all on function private.transition_visit(text, uuid, text[], text, uuid) from public, anon;
grant execute on function private.transition_visit(text, uuid, text[], text, uuid) to authenticated;

create function public.depart_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text language sql security invoker set search_path = ''
as $$ select private.transition_visit('depart_visit', p_visit_id, array['planned'], 'on_the_way', p_idempotency_key) $$;

create or replace function public.start_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text language sql security invoker set search_path = ''
as $$ select private.transition_visit('start_visit', p_visit_id, array['planned', 'on_the_way'], 'started', p_idempotency_key) $$;

create function public.pause_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text language sql security invoker set search_path = ''
as $$ select private.transition_visit('pause_visit', p_visit_id, array['started'], 'paused', p_idempotency_key) $$;

create function public.resume_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text language sql security invoker set search_path = ''
as $$ select private.transition_visit('resume_visit', p_visit_id, array['paused'], 'started', p_idempotency_key) $$;

-- No billable flag here (SR-09): completion is not a billing fact.
create or replace function public.complete_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text language sql security invoker set search_path = ''
as $$ select private.transition_visit('complete_visit', p_visit_id, array['started'], 'completed', p_idempotency_key) $$;

revoke all on function
  public.depart_visit(uuid, uuid), public.start_visit(uuid, uuid), public.pause_visit(uuid, uuid),
  public.resume_visit(uuid, uuid), public.complete_visit(uuid, uuid)
from public, anon;
grant execute on function
  public.depart_visit(uuid, uuid), public.start_visit(uuid, uuid), public.pause_visit(uuid, uuid),
  public.resume_visit(uuid, uuid), public.complete_visit(uuid, uuid)
to authenticated;

-- 5. field_visits returns the visit timeline (F1 → F2) ----------------------------------
drop function public.field_visits(date);

create function public.field_visits(p_date date)
returns table (
  visit_id          uuid,
  visit_date        date,
  time_start        time,
  time_end          time,
  status            text,
  services_provided text[],
  team_id           uuid,
  team_name         text,
  case_id           uuid,
  client_name       text,
  care_needs        text[],
  address           text,
  plz               text,
  ort               text,
  events            jsonb            -- [{"type": "...", "at": "..."}] in time order; no actor ids
)
language sql stable security invoker set search_path = ''
as $$
  select v.id, v.visit_date, v.time_start, v.time_end, v.status, v.services_provided,
         t.id, t.name,
         c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         c.care_needs, c.address, c.plz, c.ort,
         coalesce((
           select jsonb_agg(jsonb_build_object('type', e.event_type, 'at', e.occurred_at)
                            order by e.occurred_at, e.id)
           from public.visit_events e
           where e.visit_id = v.id
         ), '[]'::jsonb)
  from public.care_visits v
  join public.team_memberships tm
    on tm.team_id = v.team_id and tm.user_id = (select auth.uid())
  join public.teams t on t.id = v.team_id
  left join public.cases c on c.id = v.case_id
  where p_date is not null
    and v.visit_date = p_date
  order by v.time_start nulls last, v.id;
$$;

revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;

comment on function public.field_visits(date) is
  'F1/F2: visits of the caller''s teams on one day, minimal client context and the visit timeline. Assignment model pending D-6.';
