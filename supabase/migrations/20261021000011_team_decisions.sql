-- =============================================================================
-- J2 — Team decision on open matching requests (team pull, no ranking)
-- ARCHITECTURE.md: "… → matching_requests → serverseitige Kandidaten → Teamentscheid → care_visits"
-- DOMAIN_RULES: Teamautonomie (teams decide on case acceptance themselves);
--   Matching hard filters: active team, competence, verified qualification,
--   actual capacity, service area, open safety holds; weights OPEN.
-- ROADMAP Gate 4: "atomarer Teamentscheid".
-- =============================================================================
-- Scope (ADR-027):
-- * Offers: an open matching request is offered to ACTIVE teams whose region
--   equals the request's region. These are the only two hard filters today's
--   data can evaluate. Competence, qualification, capacity and safety holds are
--   NOT evaluated (no data) and are reported as "not checked" in the UI. No
--   ranking, no fit score (legacy scores are DEPRECATED).
-- * Before acceptance a team sees need, region, urgency and services — not the
--   client's name (data minimisation).
-- * Decision: accept or decline, by a member of the team, recorded append-only in
--   team_decisions. The first acceptance assigns the case to the team atomically
--   (row lock on the request); later acceptances are rejected. Declines do not
--   block other teams.
-- =============================================================================

create table public.team_decisions (
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references public.organizations (id),
  matching_request_id uuid not null,
  case_id             uuid,
  team_id             uuid not null,
  decision            text not null check (decision in ('accept', 'decline')),
  reason              text check (reason is null or char_length(reason) between 1 and 500),
  actor_id            uuid not null,
  decided_at          timestamptz not null default now(),
  idempotency_key     uuid not null,
  unique (actor_id, idempotency_key),
  -- one decision per team and request (a team can't flip-flop silently)
  unique (matching_request_id, team_id),
  foreign key (matching_request_id, organization_id) references public.matching_requests (id, organization_id),
  foreign key (team_id, organization_id) references public.teams (id, organization_id)
);

comment on table public.team_decisions is
  'J2: append-only team decisions (accept/decline) on matching requests. First accept assigns the case.';

alter table public.team_decisions enable row level security;
revoke all on public.team_decisions from anon, authenticated;
grant select on public.team_decisions to authenticated;

create policy org_members_read on public.team_decisions
  for select to authenticated using (private.is_org_member(organization_id));

create trigger team_decisions_no_update_delete
  before update or delete on public.team_decisions
  for each row execute function private.forbid_audit_change();
create trigger team_decisions_no_truncate
  before truncate on public.team_decisions
  for each statement execute function private.forbid_audit_change();

-- Is this request offered to this team? (the two hard filters available today)
create function private.request_offered_to_team(p_request_id uuid, p_team_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.matching_requests m
    join public.teams t on t.id = p_team_id
    join public.cases c on c.id = m.case_id
    where m.id = p_request_id
      and m.status = 'open'
      and c.assigned_team_id is null
      and t.organization_id = m.organization_id
      and t.status = 'active'
      and t.region = m.region
  );
$$;

revoke all on function private.request_offered_to_team(uuid, uuid) from public, anon;
grant execute on function private.request_offered_to_team(uuid, uuid) to authenticated;

-- Offers for the caller's teams ---------------------------------------------------------
create function public.team_offers()
returns table (
  matching_request_id uuid,
  team_id             uuid,
  team_name           text,
  request_title       text,
  region              text,
  urgency             text,
  required_services   text[],
  created_at          timestamptz,
  my_team_declined    boolean
)
language sql stable security definer set search_path = ''
as $$
  select m.id, t.id, t.name, m.request_title, m.region, m.urgency, m.required_services, m.created_at,
         exists (select 1 from public.team_decisions d
                 where d.matching_request_id = m.id and d.team_id = t.id and d.decision = 'decline')
  from public.team_memberships tm
  join public.teams t on t.id = tm.team_id
  join public.matching_requests m on m.organization_id = t.organization_id and m.region = t.region
  join public.cases c on c.id = m.case_id
  where tm.user_id = (select auth.uid())
    and private.is_org_member(t.organization_id)
    and t.status = 'active'
    and m.status = 'open'
    and c.assigned_team_id is null
  order by case m.urgency when 'hoch' then 0 when 'mittel' then 1 else 2 end, m.created_at;
$$;

revoke all on function public.team_offers() from public, anon;
grant execute on function public.team_offers() to authenticated;

-- Command ---------------------------------------------------------------------------------
-- Return: 'ok' | 'duplicate' | 'rejected' | 'taken' (another team accepted first).
create function public.decide_matching_request(
  p_request_id uuid, p_team_id uuid, p_decision text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid     uuid := (select auth.uid());
  req     public.matching_requests%rowtype;
  tm_name text;
  why     text := nullif(btrim(p_reason), '');
begin
  if uid is null then
    return 'rejected';
  end if;
  if p_idempotency_key is null or p_decision not in ('accept', 'decline') then
    raise exception 'decision must be accept or decline, with an idempotency key' using errcode = '22023';
  end if;
  if why is not null and char_length(why) > 500 then
    raise exception 'reason too long' using errcode = '22023';
  end if;

  if exists (select 1 from public.team_decisions d where d.actor_id = uid and d.idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;

  -- Serialise decisions on one request.
  select * into req from public.matching_requests where id = p_request_id for update;
  if not found
     or not private.is_org_member(req.organization_id)
     or not private.is_team_member(p_team_id) then
    return 'rejected';
  end if;

  if exists (select 1 from public.team_decisions d where d.matching_request_id = req.id and d.team_id = p_team_id) then
    return 'rejected';   -- this team already decided
  end if;

  if not private.request_offered_to_team(req.id, p_team_id) then
    -- still open for the team's region but someone else was faster?
    if req.status <> 'open' or exists (select 1 from public.cases c where c.id = req.case_id and c.assigned_team_id is not null) then
      return 'taken';
    end if;
    return 'rejected';
  end if;

  perform set_config('navora.command', 'decide_matching_request', true);
  perform set_config('navora.idempotency_key', p_idempotency_key::text, true);

  insert into public.team_decisions
    (organization_id, matching_request_id, case_id, team_id, decision, reason, actor_id, idempotency_key)
  values
    (req.organization_id, req.id, req.case_id, p_team_id, p_decision, why, uid, p_idempotency_key);

  if p_decision = 'accept' then
    select name into tm_name from public.teams where id = p_team_id;
    update public.matching_requests set status = 'accepted', selected_team_id = p_team_id where id = req.id;
    update public.cases
      set assigned_team_id = p_team_id, assigned_team = tm_name, status = 'laufend', next_step = 'Einsätze planen'
      where id = req.case_id;
  end if;

  perform set_config('navora.command', '', true);
  perform set_config('navora.idempotency_key', '', true);
  return 'ok';
end;
$$;

revoke all on function public.decide_matching_request(uuid, uuid, text, text, uuid) from public, anon;
grant execute on function public.decide_matching_request(uuid, uuid, text, text, uuid) to authenticated;
