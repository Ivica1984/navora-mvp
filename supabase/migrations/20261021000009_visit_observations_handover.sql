-- =============================================================================
-- F4 — Visit observations with provenance, team-scoped visibility, handover
-- (ROADMAP Gate 2 item 3: "Beobachtungen, Team-Sichtbarkeit, Übergabe";
--  DOMAIN_RULES "Dokumentation": author, source and time on every observation;
--  later changes as a new version)
-- =============================================================================
-- * Free text only. No clinical categories, scores or rules: those need a
--   validated source (CLAUDE.md: keine Erfindung von medizinischen Regeln).
-- * Provenance: author (auth.uid()), recorded_at (server time), source
--   ('direct' = typed by the nurse; voice/AI sources come with Gate 3).
-- * Immutable: a change is a new row that supersedes the previous version.
--   Only the latest version is current; older versions stay for audit.
-- * Visibility: members of the visit's team only (ADR-025). This is stricter
--   than the organisation-wide read of the legacy care tables (SR-22) and
--   follows option B of D-3 for new health data.
-- * Handover: an observation can be marked for handover; it is shown on the
--   same client's visits of the team for the following 14 days
--   (display default, not a clinical rule; owner/product may change it).
-- =============================================================================

create table public.visit_observations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,
  case_id         uuid,
  team_id         uuid not null,
  author_id       uuid not null,
  recorded_at     timestamptz not null default now(),
  source          text not null default 'direct' check (source in ('direct')),
  content         text not null check (char_length(btrim(content)) between 1 and 2000),
  for_handover    boolean not null default false,
  supersedes_id   uuid references public.visit_observations (id),
  idempotency_key uuid not null,
  unique (author_id, idempotency_key),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id),
  foreign key (team_id, organization_id) references public.teams (id, organization_id)
);

-- One successor per version: a version can be superseded only once.
create unique index visit_observations_one_successor on public.visit_observations (supersedes_id)
  where supersedes_id is not null;
create index visit_observations_visit_idx on public.visit_observations (visit_id, recorded_at);
create index visit_observations_case_handover_idx on public.visit_observations (case_id, recorded_at)
  where for_handover;

comment on table public.visit_observations is
  'F4: immutable, versioned visit observations with provenance; readable by the visit''s team only.';

alter table public.visit_observations enable row level security;
revoke all on public.visit_observations from anon, authenticated;
grant select on public.visit_observations to authenticated;

create policy team_members_read on public.visit_observations
  for select to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id));

create trigger visit_observations_no_update_delete
  before update or delete on public.visit_observations
  for each row execute function private.forbid_audit_change();
create trigger visit_observations_no_truncate
  before truncate on public.visit_observations
  for each statement execute function private.forbid_audit_change();

-- Command ------------------------------------------------------------------------------
-- SECURITY DEFINER: app users have no INSERT privilege; every check is explicit
-- and uses the caller's auth.uid() (same pattern as correct_visit_time, ADR-024).
-- Return: 'ok' | 'duplicate' | 'rejected'. 22023 = invalid input.
create function public.record_observation(
  p_visit_id uuid, p_content text, p_for_handover boolean, p_supersedes_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid     uuid := (select auth.uid());
  v       public.care_visits%rowtype;
  prev    public.visit_observations%rowtype;
  body    text := btrim(p_content);
begin
  if uid is null then
    return 'rejected';
  end if;
  if p_idempotency_key is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;
  if body is null or char_length(body) not between 1 and 2000 then
    raise exception 'an observation needs 1–2000 characters' using errcode = '22023';
  end if;

  if exists (select 1 from public.visit_observations o
             where o.author_id = uid and o.idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;

  select * into v from public.care_visits where id = p_visit_id;
  if not found
     or v.team_id is null
     or not private.is_org_member(v.organization_id)
     or not private.is_team_member(v.team_id)
     -- during or after the visit, not before it
     or v.status not in ('on_the_way', 'started', 'paused', 'completed') then
    return 'rejected';
  end if;

  if p_supersedes_id is not null then
    select * into prev from public.visit_observations where id = p_supersedes_id;
    if not found
       or prev.visit_id <> v.id
       or exists (select 1 from public.visit_observations s where s.supersedes_id = prev.id) then
      return 'rejected';   -- unknown, other visit, or not the latest version
    end if;
  end if;

  insert into public.visit_observations
    (organization_id, visit_id, case_id, team_id, author_id, content, for_handover,
     supersedes_id, idempotency_key)
  values
    (v.organization_id, v.id, v.case_id, v.team_id, uid, body, coalesce(p_for_handover, false),
     p_supersedes_id, p_idempotency_key);

  return 'ok';
end;
$$;

revoke all on function public.record_observation(uuid, text, boolean, uuid, uuid) from public, anon;
grant execute on function public.record_observation(uuid, text, boolean, uuid, uuid) to authenticated;

-- Read model for /field ------------------------------------------------------------------
-- kind = 'observation': current versions recorded on the day's visits.
-- kind = 'handover'   : current handover observations from OTHER visits of the same
--                       client by the same team, recorded in the 14 days before the
--                       target visit's day (shown on the target visit).
-- SECURITY INVOKER: the team-scoped RLS of visit_observations applies.
create function public.field_notes(p_date date)
returns table (
  kind          text,
  visit_id      uuid,          -- the visit card the note is shown on
  id            uuid,
  content       text,
  for_handover  boolean,
  recorded_at   timestamptz,
  own           boolean,       -- written by the caller (no author ids leave the database)
  edited        boolean,       -- this is a later version
  source_date   date           -- day of the visit the note was recorded on
)
language sql stable security invoker set search_path = ''
as $$
  with my_visits as (
    select v.id, v.case_id, v.team_id, v.visit_date
    from public.care_visits v
    join public.team_memberships tm on tm.team_id = v.team_id and tm.user_id = (select auth.uid())
    where p_date is not null and v.visit_date = p_date
  ),
  current_obs as (
    select o.*, sv.visit_date as obs_visit_date
    from public.visit_observations o
    join public.care_visits sv on sv.id = o.visit_id
    where not exists (select 1 from public.visit_observations s where s.supersedes_id = o.id)
  )
  select 'observation', mv.id, o.id, o.content, o.for_handover, o.recorded_at,
         o.author_id = (select auth.uid()), o.supersedes_id is not null, o.obs_visit_date
  from my_visits mv
  join current_obs o on o.visit_id = mv.id
  union all
  select 'handover', mv.id, o.id, o.content, o.for_handover, o.recorded_at,
         o.author_id = (select auth.uid()), o.supersedes_id is not null, o.obs_visit_date
  from my_visits mv
  join current_obs o
    on o.for_handover
   and o.case_id = mv.case_id
   and o.team_id = mv.team_id
   and o.visit_id <> mv.id
   and o.recorded_at >= (mv.visit_date - 14)::timestamptz
   and o.obs_visit_date <= mv.visit_date
  order by 2, 1 desc, 6;
$$;

revoke all on function public.field_notes(date) from public, anon;
grant execute on function public.field_notes(date) to authenticated;
