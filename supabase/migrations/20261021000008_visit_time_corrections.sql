-- =============================================================================
-- F3 — Time corrections as reasoned, append-only correction records
-- (ROADMAP Gate 2 item 2: "Zeitsegmente mit Korrekturevents";
--  DOMAIN_RULES: "Keine negativen Zeiten, ungeklärten Überlappungen oder
--  stillen Zeitkorrekturen.")
-- =============================================================================
-- * A visit event (F2) is never edited. A correction is a new row that names
--   the event, the corrected time, a reason (5–500 characters) and the actor.
--   The effective time of an event is its latest correction, else the
--   recorded time. The original stays visible.
-- * Who may correct: members of the visit's team (Teamautonomie, same rule as
--   the transitions). Review/approval of corrections is not decided (D-6/Q4)
--   and is not modelled here.
-- * The database refuses corrections that lie in the future or that would put
--   the visit's timeline out of order (→ no negative durations).
-- * Corrections are not payroll or billing facts.
-- =============================================================================

create table public.visit_time_corrections (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,
  team_id         uuid,
  event_id        bigint not null references public.visit_events (id),
  corrected_at    timestamptz not null,
  reason          text not null check (char_length(btrim(reason)) between 5 and 500),
  actor_id        uuid not null,
  created_at      timestamptz not null default now(),
  idempotency_key uuid not null,
  unique (actor_id, idempotency_key),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id)
);

create index visit_time_corrections_event_idx on public.visit_time_corrections (event_id, created_at desc, id desc);

comment on table public.visit_time_corrections is
  'F3: append-only, reasoned corrections of visit event times. Never edit visit_events.';

alter table public.visit_time_corrections enable row level security;
revoke all on public.visit_time_corrections from anon, authenticated;
grant select on public.visit_time_corrections to authenticated;

create policy org_members_read on public.visit_time_corrections
  for select to authenticated using (private.is_org_member(organization_id));

create trigger visit_time_corrections_no_update_delete
  before update or delete on public.visit_time_corrections
  for each row execute function private.forbid_audit_change();
create trigger visit_time_corrections_no_truncate
  before truncate on public.visit_time_corrections
  for each statement execute function private.forbid_audit_change();

-- Effective time: latest correction, else the recorded time.
create function private.effective_event_time(p_event_id bigint)
returns timestamptz
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select c.corrected_at from public.visit_time_corrections c
     where c.event_id = p_event_id order by c.created_at desc, c.id desc limit 1),
    (select e.occurred_at from public.visit_events e where e.id = p_event_id)
  );
$$;

revoke all on function private.effective_event_time(bigint) from public, anon;
grant execute on function private.effective_event_time(bigint) to authenticated;

-- Command. SECURITY DEFINER because app users have no INSERT privilege on the
-- table; every permission check is explicit and uses the caller's auth.uid().
-- Return codes as in T10: 'ok' | 'duplicate' | 'rejected'.
--   22023 invalid input (reason, time in the future, missing key)
--   23514 the correction would put the timeline out of order
create function public.correct_visit_time(
  p_event_id bigint, p_corrected_at timestamptz, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  ev     public.visit_events%rowtype;
  reason text := btrim(p_reason);
  prev   timestamptz;
  nxt    timestamptz;
begin
  if uid is null then
    return 'rejected';
  end if;
  if p_idempotency_key is null or p_corrected_at is null then
    raise exception 'event time and idempotency key are required' using errcode = '22023';
  end if;
  if reason is null or char_length(reason) not between 5 and 500 then
    raise exception 'a reason of 5–500 characters is required' using errcode = '22023';
  end if;
  if p_corrected_at > now() + interval '1 minute' then
    raise exception 'a corrected time cannot lie in the future' using errcode = '22023';
  end if;

  if exists (select 1 from public.visit_time_corrections c
             where c.actor_id = uid and c.idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;

  select * into ev from public.visit_events e where e.id = p_event_id;
  if not found
     or not private.is_org_member(ev.organization_id)
     or ev.team_id is null
     or not private.is_team_member(ev.team_id) then
    return 'rejected';
  end if;

  -- Neighbours in the visit's timeline (recording order) with their effective times.
  select private.effective_event_time(e.id) into prev
  from public.visit_events e where e.visit_id = ev.visit_id and e.id < ev.id
  order by e.id desc limit 1;
  select private.effective_event_time(e.id) into nxt
  from public.visit_events e where e.visit_id = ev.visit_id and e.id > ev.id
  order by e.id asc limit 1;

  if (prev is not null and p_corrected_at < prev) or (nxt is not null and p_corrected_at > nxt) then
    raise exception 'the corrected time would put the visit timeline out of order' using errcode = '23514';
  end if;

  insert into public.visit_time_corrections
    (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key)
  values
    (ev.organization_id, ev.visit_id, ev.team_id, ev.id, p_corrected_at, reason, uid, p_idempotency_key);

  return 'ok';
end;
$$;

revoke all on function public.correct_visit_time(bigint, timestamptz, text, uuid) from public, anon;
grant execute on function public.correct_visit_time(bigint, timestamptz, text, uuid) to authenticated;

-- field_visits: effective times plus provenance of corrections ----------------------
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
  -- [{"id", "type", "at" (effective), "recorded_at", "corrected", "reason"}] in recording order; no actor ids
  events            jsonb
)
language sql stable security invoker set search_path = ''
as $$
  select v.id, v.visit_date, v.time_start, v.time_end, v.status, v.services_provided,
         t.id, t.name,
         c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         c.care_needs, c.address, c.plz, c.ort,
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'id', e.id,
                    'type', e.event_type,
                    'at', coalesce(lc.corrected_at, e.occurred_at),
                    'recorded_at', e.occurred_at,
                    'corrected', lc.corrected_at is not null,
                    'reason', lc.reason)
                  order by e.id)
           from public.visit_events e
           left join lateral (
             select x.corrected_at, x.reason from public.visit_time_corrections x
             where x.event_id = e.id order by x.created_at desc, x.id desc limit 1
           ) lc on true
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
  'F1–F3: visits of the caller''s teams on one day, minimal client context, timeline with effective (corrected) times. Assignment model pending D-6.';
