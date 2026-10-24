-- =============================================================================
-- QG1 — Quality signals and quality hold (brief docs/agents/briefs/QG1.md, queue rank 8)
-- ARCHITECTURE.md: "… → menschlich freigegebener Bericht → Quality Gate → billable_facts"
-- =============================================================================
-- Design (ADR-036). No clinical content is invented here:
-- * Event TYPES, which types set a hold, and the serious default come from a clinically
--   approved list (D-16, `clinical`). The table quality_event_types ships EMPTY; until it is
--   filled by migration after D-16, events cannot be recorded with a type, and the UI says so.
--   Severity keeps the existing four values of quality_events (low, medium, high, critical);
--   "serious" = high or critical (as OPS1 already treats it).
-- * Everything else in the brief is mechanism and is built now:
--   - record an event from the visit (type, severity, time, case, visit, author);
--   - visibility: the assigned team; serious events also coach and admin (the brief's
--     "quality specialist" role does not exist yet: D-3); other teams never;
--   - status open → in_review → closed with owner and closing note; audited (quality_event_log);
--   - quality hold on a visit: set by an event type flagged sets_hold (after D-16) or by a
--     manual decision with a reason; lifted only by coach or admin with a reason (provisional,
--     stricter, until D-16 names the role);
--   - private.visit_has_open_hold(visit) is the single rule J5 must use: a held visit never counts.
-- =============================================================================

-- 1. Clinically approved event types (empty until D-16) --------------------------------------------------
create table public.quality_event_types (
  code           text primary key check (code ~ '^[a-z][a-z_]{1,39}$'),
  label          text not null check (char_length(btrim(label)) between 2 and 80),
  sets_hold      boolean not null,
  serious_default boolean not null,
  approved_by    text not null,        -- reference to the clinical decision (e.g. 'D-16 2026-11-…')
  active         boolean not null default true
);
comment on table public.quality_event_types is
  'QG1: clinically approved quality event types (D-16). Ships empty; filled by migration after the clinical decision.';
alter table public.quality_event_types enable row level security;
revoke all on public.quality_event_types from anon, authenticated;
grant select on public.quality_event_types to authenticated;
create policy members_read on public.quality_event_types for select to authenticated using (true);

-- 2. quality_events: workflow columns -------------------------------------------------------------------------
alter table public.quality_events
  add column occurred_at  timestamptz,
  add column author_id    uuid,
  add column owner_id     uuid,
  add column closing_note text check (closing_note is null or char_length(btrim(closing_note)) between 3 and 1000),
  add column closed_at    timestamptz;
alter table public.quality_events
  add constraint quality_events_status_check check (status in ('open', 'in_review', 'closed')) not valid,
  add constraint quality_events_severity_check check (severity in ('low', 'medium', 'high', 'critical')) not valid,
  add constraint quality_events_closed_needs_note check (status <> 'closed' or author_id is null or closing_note is not null) not valid;

-- Audited (also the basis of idempotency in begin_command).
create trigger audit_quality_events after insert or update on public.quality_events
  for each row execute function private.write_audit_event('status', 'severity', 'owner_id', 'closed_at');

create function private.is_serious(p_severity text)
returns boolean language sql immutable set search_path = ''
as $$ select p_severity in ('high', 'critical') $$;

-- Read scope: assigned team; serious events also coach and admin. Operations sees serious events
-- through the OPS1 exception read model (no event content beyond the title).
drop policy scoped_read on public.quality_events;
create policy scoped_read on public.quality_events
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_team_member(team_id)
              or (private.is_serious(severity) and private.has_org_role(organization_id, array['admin', 'coach']))));

create table public.quality_event_log (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id),
  event_id        uuid not null references public.quality_events (id),
  from_status     text,
  to_status       text not null,
  note            text,
  actor_id        uuid not null,
  idempotency_key uuid not null,
  created_at      timestamptz not null default now(),
  unique (actor_id, idempotency_key)
);
comment on table public.quality_event_log is 'QG1: append-only status transitions of quality events.';
alter table public.quality_event_log enable row level security;
revoke all on public.quality_event_log from anon, authenticated;
grant select on public.quality_event_log to authenticated;
create policy readable_with_event on public.quality_event_log
  for select to authenticated
  using (exists (select 1 from public.quality_events q where q.id = event_id));   -- inherits the event's RLS
create trigger quality_event_log_no_update_delete before update or delete on public.quality_event_log
  for each row execute function private.forbid_audit_change();
create trigger quality_event_log_no_truncate before truncate on public.quality_event_log
  for each statement execute function private.forbid_audit_change();

-- 3. Quality holds ---------------------------------------------------------------------------------------------------
create table public.quality_holds (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,
  team_id         uuid not null,
  event_id        uuid references public.quality_events (id),
  reason          text not null check (char_length(btrim(reason)) between 3 and 500),
  set_by          uuid not null,
  set_at          timestamptz not null default now(),
  lifted_by       uuid,
  lifted_at       timestamptz,
  lift_reason     text check (lift_reason is null or char_length(btrim(lift_reason)) between 3 and 500),
  idempotency_key uuid not null,
  unique (set_by, idempotency_key),
  check ((lifted_at is null) = (lifted_by is null) and (lifted_at is null) = (lift_reason is null)),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id),
  foreign key (team_id, organization_id) references public.teams (id, organization_id)
);
create unique index quality_holds_one_open_per_visit on public.quality_holds (visit_id) where lifted_at is null;
comment on table public.quality_holds is
  'QG1: quality hold on a visit. A visit with an open hold never counts as billable (J5 uses private.visit_has_open_hold).';
alter table public.quality_holds enable row level security;
revoke all on public.quality_holds from anon, authenticated;
grant select on public.quality_holds to authenticated;
create policy scoped_read on public.quality_holds
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_team_member(team_id) or private.is_coordinator(organization_id)));

-- Lifting is the only change; everything else is immutable.
create function private.guard_quality_hold()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then raise exception 'quality holds are never deleted' using errcode = '42501'; end if;
  if old.lifted_at is not null
     or (new.visit_id, new.team_id, new.event_id, new.reason, new.set_by, new.set_at)
        is distinct from (old.visit_id, old.team_id, old.event_id, old.reason, old.set_by, old.set_at) then
    raise exception 'a quality hold can only be lifted once' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger quality_holds_guard before update or delete on public.quality_holds
  for each row execute function private.guard_quality_hold();
create trigger audit_quality_holds after insert or update on public.quality_holds
  for each row execute function private.write_audit_event('reason', 'lifted_by', 'lift_reason');

-- The single rule for billing (J5) and every other consumer.
create function private.visit_has_open_hold(p_visit_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.quality_holds h where h.visit_id = p_visit_id and h.lifted_at is null) $$;
revoke all on function private.visit_has_open_hold(uuid) from public, anon;
grant execute on function private.visit_has_open_hold(uuid) to authenticated;

-- 4. Commands ---------------------------------------------------------------------------------------------------------
-- record_quality_event: from a visit of the caller's team. Returns jsonb {result, reason?, event_id?, hold?}.
create function public.record_quality_event(
  p_visit_id uuid, p_type_code text, p_severity text, p_occurred_at timestamptz, p_note text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  v    public.care_visits%rowtype;
  t    public.quality_event_types%rowtype;
  eid  uuid;
  note text := nullif(btrim(p_note), '');
  hold boolean := false;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if p_severity is null or p_severity not in ('low', 'medium', 'high', 'critical') then
    raise exception 'severity must be low, medium, high or critical' using errcode = '22023';
  end if;
  if p_occurred_at is null or p_occurred_at > now() + interval '5 minutes' or p_occurred_at < now() - interval '30 days' then
    raise exception 'occurred_at must lie within the last 30 days' using errcode = '22023';
  end if;
  if note is not null and char_length(note) > 2000 then
    raise exception 'note too long' using errcode = '22023';
  end if;
  if private.begin_command('record_quality_event', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into v from public.care_visits where id = p_visit_id;
  if not found or not private.is_org_member(v.organization_id) or not private.is_team_member(v.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  select * into t from public.quality_event_types where code = p_type_code and active;
  if not found then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'type_not_approved');
  end if;

  insert into public.quality_events
    (organization_id, case_id, visit_id, team_id, event_type, severity, title, description, status, occurred_at, author_id)
  values
    (v.organization_id, v.case_id, v.id, v.team_id, t.code, p_severity, t.label, note, 'open', p_occurred_at, uid)
  returning id into eid;

  if t.sets_hold and not private.visit_has_open_hold(v.id) then
    insert into public.quality_holds (organization_id, visit_id, team_id, event_id, reason, set_by, idempotency_key)
    values (v.organization_id, v.id, v.team_id, eid, 'Ereignistyp: ' || t.label, uid, p_idempotency_key);
    hold := true;
  end if;

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'event_id', eid, 'hold', hold);
end;
$$;

-- Who may handle an event: its team; for serious events also coach and admin.
create function private.can_handle_quality_event(q public.quality_events)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.is_org_member(q.organization_id)
     and (private.is_team_member(q.team_id)
          or (private.is_serious(q.severity) and private.has_org_role(q.organization_id, array['admin', 'coach'])))
$$;
revoke all on function private.can_handle_quality_event(public.quality_events) from public, anon, authenticated;

-- open → in_review (caller becomes owner); open|in_review → closed (closing note required).
create function public.set_quality_event_status(p_event_id uuid, p_status text, p_note text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  q    public.quality_events%rowtype;
  note text := nullif(btrim(p_note), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_status is null or p_status not in ('in_review', 'closed') or p_idempotency_key is null then
    raise exception 'status must be in_review or closed, with an idempotency key' using errcode = '22023';
  end if;
  if p_status = 'closed' and (note is null or char_length(note) not between 3 and 1000) then
    raise exception 'closing needs a note (3–1000 characters)' using errcode = '22023';
  end if;
  if exists (select 1 from public.quality_event_log l where l.actor_id = uid and l.idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;
  select * into q from public.quality_events where id = p_event_id for update;
  if not found or not private.can_handle_quality_event(q) then return 'rejected'; end if;
  if q.status = 'closed' or (p_status = 'in_review' and q.status <> 'open') then return 'rejected'; end if;

  perform set_config('navora.command', 'set_quality_event_status', true);
  perform set_config('navora.idempotency_key', p_idempotency_key::text, true);
  update public.quality_events
    set status = p_status,
        owner_id = case when p_status = 'in_review' then uid else coalesce(owner_id, uid) end,
        closing_note = case when p_status = 'closed' then note else closing_note end,
        closed_at = case when p_status = 'closed' then now() else closed_at end
    where id = q.id;
  insert into public.quality_event_log (organization_id, event_id, from_status, to_status, note, actor_id, idempotency_key)
  values (q.organization_id, q.id, q.status, p_status, note, uid, p_idempotency_key);
  perform private.end_command('ok');
  return 'ok';
end;
$$;

-- Manual quality hold by the team (or coach/admin), with a reason.
create function public.set_quality_hold(p_visit_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := private.check_text(p_reason, 3, 500, 'reason');
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('set_quality_hold', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into v from public.care_visits where id = p_visit_id;
  if not found or not private.is_org_member(v.organization_id)
     or not (private.is_team_member(v.team_id) or private.has_org_role(v.organization_id, array['admin', 'coach'])) then
    return private.end_command('rejected');
  end if;
  if private.visit_has_open_hold(v.id) then
    return private.end_command('already_held');
  end if;
  insert into public.quality_holds (organization_id, visit_id, team_id, reason, set_by, idempotency_key)
  values (v.organization_id, v.id, v.team_id, why, uid, p_idempotency_key);
  return private.end_command('ok');
end;
$$;

-- Lift: coach or admin only (provisional until D-16 names the role), with a reason.
create function public.lift_quality_hold(p_hold_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  h   public.quality_holds%rowtype;
  why text := private.check_text(p_reason, 3, 500, 'reason');
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('lift_quality_hold', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into h from public.quality_holds where id = p_hold_id for update;
  if not found or h.lifted_at is not null
     or not private.has_org_role(h.organization_id, array['admin', 'coach']) then
    return private.end_command('rejected');
  end if;
  update public.quality_holds set lifted_by = uid, lifted_at = now(), lift_reason = why where id = h.id;
  return private.end_command('ok');
end;
$$;

revoke all on function
  public.record_quality_event(uuid, text, text, timestamptz, text, uuid),
  public.set_quality_event_status(uuid, text, text, uuid),
  public.set_quality_hold(uuid, text, uuid),
  public.lift_quality_hold(uuid, text, uuid)
from public, anon;
grant execute on function
  public.record_quality_event(uuid, text, text, timestamptz, text, uuid),
  public.set_quality_event_status(uuid, text, text, uuid),
  public.set_quality_hold(uuid, text, uuid),
  public.lift_quality_hold(uuid, text, uuid)
to authenticated;

-- 5. Read model for /field: events and holds of the day's visits (team only) --------------------------------------------
create function public.field_quality(p_date date)
returns table (
  visit_id    uuid,
  kind        text,          -- 'event' | 'hold'
  id          uuid,
  label       text,
  severity    text,
  status      text,
  at          timestamptz,
  own         boolean
)
language sql stable security definer set search_path = ''
as $$
  select q.visit_id, 'event', q.id, q.title, q.severity, q.status, coalesce(q.occurred_at, q.created_at), q.author_id = (select auth.uid())
  from public.quality_events q join public.care_visits v on v.id = q.visit_id
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  union all
  select h.visit_id, 'hold', h.id, h.reason, null, case when h.lifted_at is null then 'open' else 'lifted' end, h.set_at,
         h.set_by = (select auth.uid())
  from public.quality_holds h join public.care_visits v on v.id = h.visit_id
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  order by 1, 7;
$$;
revoke all on function public.field_quality(date) from public, anon;
grant execute on function public.field_quality(date) to authenticated;
