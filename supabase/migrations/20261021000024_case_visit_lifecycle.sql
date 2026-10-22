-- =============================================================================
-- C1 — Case and visit lifecycle: pause, resume, close, reopen, cancel, no-show
-- Brief docs/agents/briefs/C1.md (PO, approved 2026-10-22). Design: ADR-041.
-- =============================================================================
-- * Case lifecycle (new column cases.lifecycle: active | paused | closed) with an append-only
--   case_lifecycle_events log (who, when, reason code, note, expected end). Legacy cases.status
--   follows for the existing read models: closed → 'abgeschlossen', reopen → 'laufend' or 'neu'.
-- * Pause suspends the case's planned visits inside the pause (care_visits.suspended_at; kept,
--   not deleted). Answer to the brief's question: a reversible marker, not a visit state, because
--   resume must restore them. Suspended visits cannot start, are not uncovered, produce no facts.
-- * Close cancels all future planned visits with the close reason, closes open case tasks, ends
--   the primary-nurse assignment and withdraws open matching requests. Reports, quality events
--   and billing facts are untouched.
-- * Reopen (team or Operations): visits can be planned again only when the J1 readiness check
--   passes (trigger on care_visits insert).
-- * Visit end states cancelled and no_show join the state machine (D-6 lists them) and write
--   visit events. Reasons/notes go to the append-only visit_status_notes.
-- * No-show → P1 OPS1 exception at once, open until the team records the outcome. On-site steps
--   follow D-19 (clinical): the app records and escalates only.
-- * Team cancellation within 24 h of the visit → P2 OPS1 exception (configurable rule).
-- * Every command: reason (F0 rule), audited, idempotent; team or (close/reopen) Operations only.
-- =============================================================================

-- 1. Case lifecycle -----------------------------------------------------------------------------------------
alter table public.cases
  add column lifecycle text not null default 'active' check (lifecycle in ('active', 'paused', 'closed')),
  add column reopened_at timestamptz;
grant select (lifecycle, reopened_at) on public.cases to authenticated;

create table public.case_lifecycle_events (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  case_id         uuid not null,
  kind            text not null check (kind in ('pause', 'resume', 'close', 'reopen')),
  reason_code     text check (reason_code is null or reason_code in (
                    'hospital_stay', 'rehabilitation', 'client_absence',
                    'goal_reached', 'moved_inpatient', 'moved_away', 'declined', 'died', 'other')),
  note            text check (note is null or char_length(btrim(note)) between 3 and 500),
  expected_end    date,
  actor_id        uuid not null,
  idempotency_key uuid not null,
  created_at      timestamptz not null default now(),
  unique (actor_id, idempotency_key),
  foreign key (case_id, organization_id) references public.cases (id, organization_id)
);
comment on table public.case_lifecycle_events is 'C1: append-only case lifecycle (pause, resume, close, reopen) with reasons.';
alter table public.case_lifecycle_events enable row level security;
revoke all on public.case_lifecycle_events from anon, authenticated;
grant select on public.case_lifecycle_events to authenticated;
create policy scoped_read on public.case_lifecycle_events for select to authenticated
  using (exists (select 1 from public.cases c where c.id = case_id));   -- inherits the case's RLS
create trigger case_lifecycle_events_no_update_delete before update or delete on public.case_lifecycle_events
  for each row execute function private.forbid_audit_change();
create trigger audit_case_lifecycle_events after insert on public.case_lifecycle_events
  for each row execute function private.write_audit_event('kind', 'reason_code');

-- 2. Visits: suspension marker, end states, status notes ---------------------------------------------------
alter table public.care_visits
  add column suspended_at  timestamptz,
  add column suspended_by  uuid references public.case_lifecycle_events (id);
grant select (suspended_at) on public.care_visits to authenticated;

alter table public.visit_events drop constraint visit_events_event_type_check;
alter table public.visit_events add constraint visit_events_event_type_check
  check (event_type in ('departed', 'started', 'paused', 'resumed', 'completed', 'cancelled', 'no_show'));

create or replace function private.write_visit_event()
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
    when new.status = 'cancelled' then 'cancelled'
    when new.status = 'no_show' then 'no_show'
  end;
  if kind is null then
    return new;
  end if;
  insert into public.visit_events
    (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, command, idempotency_key)
  values
    (new.organization_id, new.id, new.team_id, kind, old.status, new.status, (select auth.uid()),
     nullif(current_setting('navora.command', true), ''),
     nullif(current_setting('navora.idempotency_key', true), '')::uuid);
  return new;
end;
$$;

-- Field transitions by app users: unchanged list; a suspended visit cannot be started or departed.
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
    if old.suspended_at is not null then
      raise exception 'the visit is suspended because the case is paused' using errcode = '23514';
    end if;
    if new.status = 'started' and old.status in ('planned', 'on_the_way')
       and (coalesce(new.planned_minutes_b, 0) > 0 or new.is_needs_assessment)
       and not private.is_registered_nurse(new.team_id, (select auth.uid())) then
      raise exception 'category B and needs-assessment visits are started by a registered nurse'
        using errcode = 'NV001';
    end if;
  end if;
  return new;
end;
$$;

create table public.visit_status_notes (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,
  kind            text not null check (kind in ('cancelled', 'no_show', 'no_show_outcome')),
  reason_code     text check (reason_code is null or reason_code in (
                    'client_cancelled', 'client_in_hospital', 'team_cancelled', 'case_paused', 'case_closed', 'other',
                    'client_reached', 'emergency_contact_informed', 'emergency_services_called')),
  note            text check (note is null or char_length(btrim(note)) between 3 and 1000),
  actor_id        uuid not null,
  idempotency_key uuid not null,
  created_at      timestamptz not null default now(),
  unique (actor_id, idempotency_key),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id)
);
comment on table public.visit_status_notes is 'C1: append-only reasons for cancelled and no-show visits and no-show outcomes.';
alter table public.visit_status_notes enable row level security;
revoke all on public.visit_status_notes from anon, authenticated;
grant select on public.visit_status_notes to authenticated;
create policy scoped_read on public.visit_status_notes for select to authenticated
  using (exists (select 1 from public.care_visits v where v.id = visit_id));   -- inherits the visit's RLS
create trigger visit_status_notes_no_update_delete before update or delete on public.visit_status_notes
  for each row execute function private.forbid_audit_change();
create trigger audit_visit_status_notes after insert on public.visit_status_notes
  for each row execute function private.write_audit_event('kind', 'reason_code');

-- Planning guard: no new visits for paused or closed cases; after a reopen only when J1 readiness passes.
create function private.guard_visit_planning()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
begin
  if new.case_id is null then return new; end if;
  select * into c from public.cases where id = new.case_id;
  if c.lifecycle = 'closed' then
    raise exception 'the case is closed' using errcode = 'NV002';
  end if;
  if c.lifecycle = 'paused' then
    raise exception 'the case is paused' using errcode = 'NV002';
  end if;
  if c.reopened_at is not null and jsonb_array_length(private.case_readiness(c.id)) > 0 then
    raise exception 'the reopened case is not ready (J1 readiness check)' using errcode = 'NV003';
  end if;
  return new;
end;
$$;
create trigger care_visits_guard_planning before insert on public.care_visits
  for each row execute function private.guard_visit_planning();

-- 3. Commands ---------------------------------------------------------------------------------------------------
-- Return text: 'ok' | 'duplicate' | 'rejected' | 'wrong_state'. Invalid input → 22023.
create function private.case_for_team_or_ops(p_case_id uuid, p_allow_ops boolean)
returns public.cases
language sql stable security definer set search_path = ''
as $$
  select c.* from public.cases c
  where c.id = p_case_id and private.is_org_member(c.organization_id)
    and ((c.assigned_team_id is not null and private.is_team_member(c.assigned_team_id))
         or (p_allow_ops and private.has_org_role(c.organization_id, array['admin', 'operations'])))
$$;
revoke all on function private.case_for_team_or_ops(uuid, boolean) from public, anon, authenticated;

create function public.pause_case(p_case_id uuid, p_reason_code text, p_reason text, p_expected_end date, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  ev  uuid;
  why text := nullif(btrim(p_reason), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_reason_code is null or p_reason_code not in ('hospital_stay', 'rehabilitation', 'client_absence', 'other') then
    raise exception 'pause reason: hospital_stay, rehabilitation, client_absence or other' using errcode = '22023';
  end if;
  if p_reason_code = 'other' and (why is null or char_length(why) < 3) then
    raise exception 'reason "other" needs a note' using errcode = '22023';
  end if;
  if p_expected_end is not null and p_expected_end < current_date then
    raise exception 'the expected end lies in the past' using errcode = '22023';
  end if;
  if private.begin_command('pause_case', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from private.case_for_team_or_ops(p_case_id, false);
  if c.id is null then return private.end_command('rejected'); end if;
  if c.lifecycle <> 'active' then return private.end_command('wrong_state'); end if;
  insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, note, expected_end, actor_id, idempotency_key)
  values (c.organization_id, c.id, 'pause', p_reason_code, why, p_expected_end, uid, p_idempotency_key)
  returning id into ev;
  update public.cases set lifecycle = 'paused' where id = c.id;
  update public.care_visits v set suspended_at = now(), suspended_by = ev
  where v.case_id = c.id and v.status = 'planned' and v.suspended_at is null
    and v.visit_date >= (now() at time zone 'Europe/Zurich')::date
    and (p_expected_end is null or v.visit_date <= p_expected_end);
  return private.end_command('ok');
end;
$$;

create function public.resume_case(p_case_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('resume_case', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from private.case_for_team_or_ops(p_case_id, false);
  if c.id is null then return private.end_command('rejected'); end if;
  if c.lifecycle <> 'paused' then return private.end_command('wrong_state'); end if;
  insert into public.case_lifecycle_events (organization_id, case_id, kind, actor_id, idempotency_key)
  values (c.organization_id, c.id, 'resume', uid, p_idempotency_key);
  update public.cases set lifecycle = 'active' where id = c.id;
  -- Suspended visits that still lie ahead are reactivated; past ones stay suspended for the team to replan.
  update public.care_visits v set suspended_at = null, suspended_by = null
  where v.case_id = c.id and v.suspended_at is not null and v.status = 'planned'
    and v.visit_date >= (now() at time zone 'Europe/Zurich')::date;
  return private.end_command('ok');
end;
$$;

create function public.close_case(p_case_id uuid, p_reason_code text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  why text := nullif(btrim(p_reason), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_reason_code is null or p_reason_code not in ('goal_reached', 'moved_inpatient', 'moved_away', 'declined', 'died', 'other') then
    raise exception 'close reason: goal_reached, moved_inpatient, moved_away, declined, died or other' using errcode = '22023';
  end if;
  if p_reason_code = 'other' and (why is null or char_length(why) < 3) then
    raise exception 'reason "other" needs a note' using errcode = '22023';
  end if;
  if private.begin_command('close_case', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from private.case_for_team_or_ops(p_case_id, true);
  if c.id is null then return private.end_command('rejected'); end if;
  if c.lifecycle = 'closed' then return private.end_command('wrong_state'); end if;

  insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, note, actor_id, idempotency_key)
  values (c.organization_id, c.id, 'close', p_reason_code, why, uid, p_idempotency_key);
  -- future planned visits are cancelled with the close reason
  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key)
  select v.organization_id, v.id, 'cancelled', 'case_closed', 'Fall abgeschlossen: ' || p_reason_code, uid, gen_random_uuid()
  from public.care_visits v
  where v.case_id = c.id and v.status = 'planned' and v.visit_date >= (now() at time zone 'Europe/Zurich')::date;
  update public.care_visits v set status = 'cancelled', suspended_at = null
  where v.case_id = c.id and v.status = 'planned' and v.visit_date >= (now() at time zone 'Europe/Zurich')::date;
  update public.case_tasks set status = 'done' where case_id = c.id and status = 'open';
  update public.matching_requests set status = 'withdrawn' where case_id = c.id and status = 'open';
  update public.cases
    set lifecycle = 'closed', status = 'abgeschlossen', primary_nurse_id = null, deputy_nurse_id = null,
        next_step = 'Fall abgeschlossen'
    where id = c.id;
  return private.end_command('ok');
end;
$$;

create function public.reopen_case(p_case_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  why text := private.check_text(p_reason, 3, 500, 'reason');
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('reopen_case', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from private.case_for_team_or_ops(p_case_id, true);
  if c.id is null then return private.end_command('rejected'); end if;
  if c.lifecycle <> 'closed' then return private.end_command('wrong_state'); end if;
  insert into public.case_lifecycle_events (organization_id, case_id, kind, note, actor_id, idempotency_key)
  values (c.organization_id, c.id, 'reopen', why, uid, p_idempotency_key);
  update public.cases
    set lifecycle = 'active', reopened_at = now(),
        status = case when c.assigned_team_id is not null then 'laufend' else 'neu' end,
        next_step = 'Wiedereröffnet: Angaben prüfen'
    where id = c.id;
  return private.end_command('ok');
end;
$$;

create function private.visit_for_team(p_visit_id uuid)
returns public.care_visits
language sql stable security definer set search_path = ''
as $$
  select v.* from public.care_visits v
  where v.id = p_visit_id and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
$$;
revoke all on function private.visit_for_team(uuid) from public, anon, authenticated;

create function public.cancel_visit(p_visit_id uuid, p_reason_code text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := nullif(btrim(p_reason), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_reason_code is null or p_reason_code not in ('client_cancelled', 'client_in_hospital', 'team_cancelled', 'other') then
    raise exception 'cancel reason: client_cancelled, client_in_hospital, team_cancelled or other' using errcode = '22023';
  end if;
  if p_reason_code = 'other' and (why is null or char_length(why) < 3) then
    raise exception 'reason "other" needs a note' using errcode = '22023';
  end if;
  if private.begin_command('cancel_visit', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then return private.end_command('rejected'); end if;
  if v.status not in ('planned', 'on_the_way') then return private.end_command('wrong_state'); end if;   -- before it starts
  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key)
  values (v.organization_id, v.id, 'cancelled', p_reason_code, why, uid, p_idempotency_key);
  update public.care_visits set status = 'cancelled', suspended_at = null where id = v.id;
  return private.end_command('ok');
end;
$$;

create function public.record_no_show(p_visit_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := private.check_text(p_reason, 3, 1000, 'note');
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('record_no_show', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then return private.end_command('rejected'); end if;
  if v.status <> 'on_the_way' then return private.end_command('wrong_state'); end if;   -- after arrival at the address
  insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key)
  values (v.organization_id, v.id, 'no_show', why, uid, p_idempotency_key);
  update public.care_visits set status = 'no_show' where id = v.id;
  return private.end_command('ok');
end;
$$;

create function public.record_no_show_outcome(p_visit_id uuid, p_outcome text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := nullif(btrim(p_reason), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_outcome is null or p_outcome not in ('client_reached', 'emergency_contact_informed', 'emergency_services_called', 'other') then
    raise exception 'outcome: client_reached, emergency_contact_informed, emergency_services_called or other' using errcode = '22023';
  end if;
  if why is null or char_length(why) not between 3 and 1000 then
    raise exception 'the outcome needs a note (3–1000 characters)' using errcode = '22023';
  end if;
  if private.begin_command('record_no_show_outcome', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then return private.end_command('rejected'); end if;
  if v.status <> 'no_show' then return private.end_command('wrong_state'); end if;
  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key)
  values (v.organization_id, v.id, 'no_show_outcome', p_outcome, why, uid, p_idempotency_key);
  return private.end_command('ok');
end;
$$;

revoke all on function
  public.pause_case(uuid, text, text, date, uuid), public.resume_case(uuid, uuid), public.close_case(uuid, text, text, uuid),
  public.reopen_case(uuid, text, uuid), public.cancel_visit(uuid, text, text, uuid), public.record_no_show(uuid, text, uuid),
  public.record_no_show_outcome(uuid, text, text, uuid)
from public, anon;
grant execute on function
  public.pause_case(uuid, text, text, date, uuid), public.resume_case(uuid, uuid), public.close_case(uuid, text, text, uuid),
  public.reopen_case(uuid, text, uuid), public.cancel_visit(uuid, text, text, uuid), public.record_no_show(uuid, text, uuid),
  public.record_no_show_outcome(uuid, text, text, uuid)
to authenticated;

-- 4. Uncovered only for active cases ---------------------------------------------------------------------------------
create or replace function private.visit_flags(p_case_id uuid, p_date date, p_minutes_b integer, p_responsible uuid,
                                               p_status text, p_time_start time)
returns text[]
language sql stable security definer set search_path = ''
as $$
  select array_remove(array[
    case when coalesce(p_minutes_b, 0) > 0 and c.medical_order_valid_until is not null
              and p_date > c.medical_order_valid_until then 'order_expired' end,
    case when p_date > (select min(i.review_date) from public.care_plan_items i where i.case_id = c.id and i.active)
         then 'reassessment_due' end,
    case when p_status = 'planned' and p_responsible is null and c.lifecycle = 'active'
              and (p_date + coalesce(p_time_start, '00:00'::time)) at time zone 'Europe/Zurich'
                  between now() and now() + interval '24 hours'
         then 'uncovered' end,
    -- J6: responsible member is neither primary nor deputy (flag only)
    case when p_responsible is not null and c.primary_nurse_id is not null
              and p_responsible <> c.primary_nurse_id and p_responsible is distinct from c.deputy_nurse_id
         then 'not_primary' end
  ], null)
  from public.cases c where c.id = p_case_id;
$$;

-- 5. OPS1: new exception types (Q9 classes) and derivation ------------------------------------------------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  ('no_show_open', 'P1', null, null, null, 'Klient:in nicht angetroffen',
   'Team kontaktieren; Ergebnis erfassen (erreicht, Notfallkontakt informiert, Rettungsdienst, anderes). Vorgehen vor Ort: D-19 (klinisch, offen).'),
  ('team_cancellation_late', 'P2', 24, 'hours', null, 'Kurzfristige Absage durch das Team',
   'Mit dem Team klären, ob ein Ersatz möglich ist; Klient:in informiert?');

create or replace function private.derived_exceptions(p_org uuid)
returns table (
  exception_key  text,
  exception_type text,
  since          timestamptz,
  case_id        uuid,
  team_id        uuid,
  entity_type    text,
  entity_id      uuid,
  detail         text
)
language sql stable security definer set search_path = ''
as $$
  with rules as (select * from public.exception_rules)
  -- J1: case not ready for matching after the threshold (working time from the referral)
  select 'case_not_ready:' || c.id, 'case_not_ready', p.created_at, c.id, null::uuid, 'case', c.id,
         (select string_agg(m ->> 'item', ', ') from jsonb_array_elements(private.case_readiness(c.id)) m)
  from public.cases c
  join public.partner_requests p on p.id = c.source_partner_request_id, rules r
  where r.exception_type = 'case_not_ready' and c.organization_id = p_org and c.ready_for_matching_at is null
    and now() >= private.after_threshold(p.created_at, r.amount, r.unit)
  union all
  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)
  select case e.reason when 'deadline_passed' then 'offer_overdue:' when 'deadline_not_configured' then 'deadline_missing:'
                       else 'candidates_exhausted:' end || e.matching_request_id,
         case e.reason when 'deadline_passed' then 'offer_overdue' when 'deadline_not_configured' then 'deadline_missing'
                       else 'candidates_exhausted' end,
         coalesce(e.response_due_at, e.created_at), m.case_id, null::uuid, 'matching_request', e.matching_request_id,
         e.request_title || coalesce(' · Absagen: ' || (select string_agg(coalesce(d ->> 'team', 'Team') || ' (' || coalesce(d ->> 'code', '?') || ')', ', ')
                                                        from jsonb_array_elements(e.declines) d), '')
  from private.matching_escalations_for(p_org) e
  join public.matching_requests m on m.id = e.matching_request_id
  union all
  -- J3: uncovered visits in the next 24 h (P1 when the case came as a hospital discharge)
  select case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital:' else 'visit_uncovered:' end || v.id,
         case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end,
         (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich', v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
  from public.care_visits v
  left join lateral (select x.referral_type from public.matching_requests x where x.case_id = v.case_id order by x.created_at desc limit 1) mr on true
  join rules r on r.exception_type = case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.suspended_at is null
    and (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich'
        between now() and private.after_threshold(now(), r.amount, r.unit)
  union all
  -- J3: medical order expiring within the threshold or expired, on a running case
  select 'order_expiring:' || c.id || ':' || c.medical_order_valid_until, 'order_expiring',
         (c.medical_order_valid_until - make_interval(days => coalesce(r.amount, 0)))::timestamptz, c.id, c.assigned_team_id, 'case', c.id,
         'gültig bis ' || to_char(c.medical_order_valid_until, 'DD.MM.YYYY')
  from public.cases c, rules r
  where r.exception_type = 'order_expiring' and c.organization_id = p_org
    and c.assigned_team_id is not null and c.medical_order_status = 'present' and c.medical_order_valid_until is not null
    and c.medical_order_valid_until <= current_date + coalesce(r.amount, 0)
  union all
  -- J3: care-plan review overdue
  select 'care_plan_review_overdue:' || i.case_id || ':' || min(i.review_date), 'care_plan_review_overdue',
         min(i.review_date)::timestamptz, i.case_id, min(i.team_id::text)::uuid, 'case', i.case_id,
         'Überprüfung fällig seit ' || to_char(min(i.review_date), 'DD.MM.YYYY')
  from public.care_plan_items i
  join public.cases c on c.id = i.case_id
  where c.organization_id = p_org and i.active
  group by i.case_id
  having min(i.review_date) < current_date
  union all
  -- QG1/legacy: serious quality event open (high, critical); priority escalates after the threshold
  select 'quality_serious_open:' || q.id, 'quality_serious_open', q.created_at, q.case_id, q.team_id, 'quality_event', q.id, q.title
  from public.quality_events q
  where q.organization_id = p_org and q.status = 'open' and q.severity in ('high', 'critical')
  union all
  -- F6: report not final 24 h after the visit ended
  select 'report_not_final:' || v.id, 'report_not_final', ended.at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.')
  from public.care_visits v
  join lateral (select max(e.occurred_at) as at from public.visit_events e where e.visit_id = v.id and e.event_type = 'completed') ended on true
  , rules r
  where r.exception_type = 'report_not_final' and v.organization_id = p_org and v.status = 'completed'
    and ended.at is not null
    and now() >= private.after_threshold(ended.at, r.amount, r.unit)
    and not exists (select 1 from public.visit_reports vr where vr.visit_id = v.id and vr.status = 'final')

  union all
  -- C1: client not reached (no-show) — P1 until the team records the outcome
  select 'no_show_open:' || v.id, 'no_show_open', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || ' · ' || left(s.note, 120)
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'no_show'
  where v.organization_id = p_org and v.status = 'no_show'
    and not exists (select 1 from public.visit_status_notes o where o.visit_id = v.id and o.kind = 'no_show_outcome')
  union all
  -- C1: visit cancelled by the team shortly before it was due (continuity)
  select 'team_cancellation_late:' || v.id, 'team_cancellation_late', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'cancelled' and s.reason_code = 'team_cancelled', rules r
  where r.exception_type = 'team_cancellation_late' and v.organization_id = p_org and v.status = 'cancelled'
    and v.visit_date >= current_date - 1
    and (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich'
        < private.after_threshold(s.created_at, r.amount, r.unit)
$$;
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- 6. Read model for /field: the reason and outcome state of the day's cancelled and no-show visits --------------------
create function public.field_visit_status_notes(p_date date)
returns table (visit_id uuid, kind text, reason_code text, note text, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select s.visit_id, s.kind, s.reason_code, s.note, s.created_at
  from public.visit_status_notes s join public.care_visits v on v.id = s.visit_id
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  order by s.visit_id, s.created_at;
$$;
revoke all on function public.field_visit_status_notes(date) from public, anon;
grant execute on function public.field_visit_status_notes(date) to authenticated;

-- 7. Read model for /team: lifecycle of the caller's teams' cases (incl. closed ones, for reopening) ------------------
create function public.team_case_lifecycle()
returns table (
  case_id       uuid,
  client_name   text,
  team_name     text,
  lifecycle     text,
  last_kind     text,
  last_reason   text,
  expected_end  date,
  changed_at    timestamptz,
  suspended_visits integer
)
language sql stable security definer set search_path = ''
as $$
  select c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), t.name, c.lifecycle,
         e.kind, e.reason_code, e.expected_end, e.created_at,
         (select count(*)::int from public.care_visits v where v.case_id = c.id and v.suspended_at is not null)
  from public.cases c
  join public.teams t on t.id = c.assigned_team_id
  left join lateral (select x.kind, x.reason_code, x.expected_end, x.created_at from public.case_lifecycle_events x
                     where x.case_id = c.id order by x.created_at desc limit 1) e on true
  where private.is_org_member(c.organization_id) and private.is_team_member(c.assigned_team_id)
    and (c.status = 'laufend' or c.lifecycle in ('paused', 'closed'))
  order by c.last_name nulls last, c.id;
$$;
revoke all on function public.team_case_lifecycle() from public, anon;
grant execute on function public.team_case_lifecycle() to authenticated;
