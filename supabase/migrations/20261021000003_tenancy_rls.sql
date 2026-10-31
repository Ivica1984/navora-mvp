-- =============================================================================
-- T9 — Tenancy and row-level security (ADR-005, ADR-018)
-- =============================================================================
-- Replaces the legacy `{public}` policies (0002) in the same migration that adds
-- the scoped replacements, so there is no window without RLS and no window with
-- both. Proven by supabase/tests/database/004_tenancy_rls.test.sql.
--
-- ROLE MODEL — ENGINEERING PLACEHOLDER (BACKLOG Q4, ADR-005).
-- The real permission matrix is OPEN (MASTER_CONTEXT). Until it is decided:
--   read          : any member of the organisation (all roles)
--   teams.update  : organisation roles admin, coach   ("Coach-Fokus", coach name)
--   visits.update : members of the visit's own team    (Teamautonomie, DOMAIN_RULES DECIDED)
--   insert/delete : nobody through the API (the app has no create/delete flows yet)
--   anon          : no table privileges at all
--
-- LIVE DATABASE NOTE: engineering never applies this to the live project
-- (ADR-008). If it is applied there later (M5), existing rows are attached to a
-- single "Legacy-Organisation" by the backfill below; real organisation
-- assignment needs an owner decision before real users get memberships.
-- =============================================================================

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- 1. Identity tables ----------------------------------------------------------
create table public.organizations (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name       text not null check (length(trim(name)) > 0)
);

create table public.organization_memberships (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  role            text not null check (role in ('admin', 'coach', 'operations', 'nurse')),
  created_at      timestamptz not null default now(),
  primary key (organization_id, user_id)
);
create index on public.organization_memberships (user_id);

create table public.team_memberships (
  team_id    uuid not null references public.teams (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (team_id, user_id)
);
create index on public.team_memberships (user_id);

-- 2. organization_id on every care table, with backfill -----------------------
do $$
declare
  t text;
  legacy_org uuid := '00000000-0000-4000-b000-000000000001';
  has_rows boolean := false;
begin
  foreach t in array array['teams','cases','partner_requests','matching_requests',
                           'match_candidates','care_visits','care_notes','quality_events']
  loop
    execute format('alter table public.%I add column organization_id uuid references public.organizations (id)', t);
    execute format('select exists (select 1 from public.%I)', t) into has_rows;
    if has_rows then
      insert into public.organizations (id, name)
      values (legacy_org, 'Legacy-Organisation (Backfill, Zuordnung offen)')
      on conflict (id) do nothing;
      execute format('update public.%I set organization_id = %L where organization_id is null', t, legacy_org);
    end if;
    execute format('alter table public.%I alter column organization_id set not null', t);
    execute format('create index on public.%I (organization_id)', t);
  end loop;
end
$$;

-- 3. Cross-tenant integrity: a row may only reference rows of its own organisation.
alter table public.teams             add constraint teams_id_org_key             unique (id, organization_id);
alter table public.cases             add constraint cases_id_org_key             unique (id, organization_id);
alter table public.care_visits       add constraint care_visits_id_org_key       unique (id, organization_id);
alter table public.matching_requests add constraint matching_requests_id_org_key unique (id, organization_id);

alter table public.cases add constraint cases_team_same_org
  foreign key (assigned_team_id, organization_id) references public.teams (id, organization_id);
alter table public.partner_requests add constraint partner_requests_case_same_org
  foreign key (converted_case_id, organization_id) references public.cases (id, organization_id);
alter table public.matching_requests add constraint matching_requests_case_same_org
  foreign key (case_id, organization_id) references public.cases (id, organization_id);
alter table public.matching_requests add constraint matching_requests_team_same_org
  foreign key (selected_team_id, organization_id) references public.teams (id, organization_id);
alter table public.match_candidates add constraint match_candidates_request_same_org
  foreign key (matching_request_id, organization_id) references public.matching_requests (id, organization_id);
alter table public.match_candidates add constraint match_candidates_team_same_org
  foreign key (team_id, organization_id) references public.teams (id, organization_id);
alter table public.care_visits add constraint care_visits_case_same_org
  foreign key (case_id, organization_id) references public.cases (id, organization_id);
alter table public.care_visits add constraint care_visits_team_same_org
  foreign key (team_id, organization_id) references public.teams (id, organization_id);
alter table public.care_notes add constraint care_notes_visit_same_org
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id);
alter table public.care_notes add constraint care_notes_case_same_org
  foreign key (case_id, organization_id) references public.cases (id, organization_id);
alter table public.care_notes add constraint care_notes_team_same_org
  foreign key (team_id, organization_id) references public.teams (id, organization_id);
alter table public.quality_events add constraint quality_events_visit_same_org
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id);
alter table public.quality_events add constraint quality_events_case_same_org
  foreign key (case_id, organization_id) references public.cases (id, organization_id);
alter table public.quality_events add constraint quality_events_team_same_org
  foreign key (team_id, organization_id) references public.teams (id, organization_id);

-- 4. Membership helpers --------------------------------------------------------
-- SECURITY DEFINER so policies can read the membership tables without recursive
-- RLS evaluation. Fixed empty search_path; schema `private` is not exposed by
-- the Data API, so these are not callable over REST.
create function private.is_org_member(org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = org and m.user_id = (select auth.uid())
  );
$$;

create function private.has_org_role(org uuid, roles text[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = org and m.user_id = (select auth.uid()) and m.role = any (roles)
  );
$$;

create function private.is_team_member(team uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.team_memberships tm
    where tm.team_id = team and tm.user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_org_member(uuid), private.has_org_role(uuid, text[]),
  private.is_team_member(uuid) from public, anon;
grant execute on function private.is_org_member(uuid), private.has_org_role(uuid, text[]),
  private.is_team_member(uuid) to authenticated;

-- 5. Replace legacy policies (SR-01) ------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['teams','cases','partner_requests','matching_requests',
                           'match_candidates','care_visits','care_notes','quality_events']
  loop
    execute format('drop policy legacy_public_all on public.%I', t);
    -- Defence in depth: anon has no privileges at all, so even a future
    -- permissive policy could not expose a table to anon.
    execute format('revoke all on public.%I from anon', t);
    -- The API offers no create/delete flows; only SELECT and UPDATE remain.
    execute format('revoke insert, delete, truncate, references, trigger on public.%I from authenticated', t);
    execute format(
      'create policy org_members_read on public.%I for select to authenticated using (private.is_org_member(organization_id))',
      t
    );
  end loop;
end
$$;

create policy coaches_update_teams on public.teams
  for update to authenticated
  using (private.has_org_role(organization_id, array['admin', 'coach']))
  with check (private.has_org_role(organization_id, array['admin', 'coach']));

create policy team_members_update_visits on public.care_visits
  for update to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id))
  with check (private.is_org_member(organization_id) and private.is_team_member(team_id));

-- Columns that must never change through an UPDATE from the app.
revoke update on public.teams from authenticated;
grant update (priority, coach_name) on public.teams to authenticated;
revoke update on public.care_visits from authenticated;
grant update (status, billable) on public.care_visits to authenticated;
-- Remaining care tables: read-only for authenticated.
revoke update on public.cases, public.partner_requests, public.matching_requests,
  public.match_candidates, public.care_notes, public.quality_events from authenticated;

-- 6. RLS on the identity tables -------------------------------------------------
alter table public.organizations            enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.team_memberships         enable row level security;

revoke all on public.organizations, public.organization_memberships, public.team_memberships from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.organizations, public.organization_memberships, public.team_memberships from authenticated;

create policy members_read_own_org on public.organizations
  for select to authenticated using (private.is_org_member(id));

create policy read_own_org_membership on public.organization_memberships
  for select to authenticated using (user_id = (select auth.uid()));

create policy read_own_team_membership on public.team_memberships
  for select to authenticated using (user_id = (select auth.uid()));

-- 7. Future tables in public get no anon privileges by default.
alter default privileges for role postgres in schema public revoke all on tables from anon;
