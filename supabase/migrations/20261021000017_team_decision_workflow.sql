-- =============================================================================
-- J2 changes — Team decision workflow (brief docs/agents/briefs/J2.md, queue rank 5)
-- plus F0 criterion 4 (offer fields before acceptance).
-- =============================================================================
-- Design (ADR-033):
-- * Offer fields before acceptance: care need, region, requested start, expected
--   hours per week (new optional intake fact) and required qualification. Never identity.
-- * Required qualification is DERIVED from rules already implemented, not invented:
--   - J3 (migration 0014): the needs assessment is started only by a registered nurse,
--     so every case without a completed needs assessment requires one;
--   - J3: category B work requires a medical order and a registered nurse, so a case
--     with a present order requires one.
--   Otherwise: no particular qualification. Clinical confirmation: D-15.
-- * Eligibility (hard filters): active team, same region, and a registered-nurse
--   member when required. Teams that are not eligible neither see nor can accept.
-- * Decline needs a reason code from the v1 list in the brief (capacity, qualification,
--   distance, other); "other" needs a text.
-- * Response deadline per referral type is CONFIGURATION (response_deadlines), set per
--   organisation by an admin. No values ship with this migration (Q8: values come with
--   the first pilot partner). Without a configured value the request has no deadline
--   and Operations sees "deadline not configured" instead of a silent wait.
-- * Referral type is derived from the partner type recorded at intake (J1).
-- * Escalation is a read model for coordination roles: no eligible team, every eligible
--   team declined, deadline passed, or deadline not configured — with all decline
--   reasons. Nothing is ever assigned automatically.
-- * Other teams' decisions are invisible to teams (team_decisions read scope).
-- =============================================================================

-- 1. Intake fact: expected hours per week (optional, shown to offered teams) ---------------------
alter table public.cases
  add column expected_hours_per_week numeric(4,1) check (expected_hours_per_week is null or (expected_hours_per_week > 0 and expected_hours_per_week <= 168));
grant select (expected_hours_per_week) on public.cases to authenticated;

create or replace function private.apply_case_facts(p_case_id uuid, p_facts jsonb)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  f jsonb := coalesce(p_facts, '{}'::jsonb);
  unknown text;
begin
  select k into unknown from jsonb_object_keys(f) k
  where k not in ('residence_municipality','residence_canton','insurer_name','insurance_type','medical_order_status',
                  'medical_order_valid_until','gp_named','other_providers_active','requested_start','language_notes','access_notes',
                  'expected_hours_per_week')
  limit 1;
  if unknown is not null then
    raise exception 'unknown intake field %', unknown using errcode = '22023';
  end if;
  if (f ? 'requested_start') and (f ->> 'requested_start') is not null
     and ((f ->> 'requested_start')::date < current_date - 30 or (f ->> 'requested_start')::date > current_date + 366) then
    raise exception 'requested start out of range' using errcode = '22023';
  end if;

  update public.cases c set
    residence_municipality    = case when f ? 'residence_municipality' then nullif(btrim(f ->> 'residence_municipality'), '') else c.residence_municipality end,
    residence_canton          = case when f ? 'residence_canton' then nullif(upper(btrim(f ->> 'residence_canton')), '') else c.residence_canton end,
    insurer_name              = case when f ? 'insurer_name' then nullif(btrim(f ->> 'insurer_name'), '') else c.insurer_name end,
    insurance_type            = case when f ? 'insurance_type' then nullif(f ->> 'insurance_type', '') else c.insurance_type end,
    medical_order_status      = case when f ? 'medical_order_status' then nullif(f ->> 'medical_order_status', '') else c.medical_order_status end,
    medical_order_valid_until = case when f ? 'medical_order_valid_until' then nullif(f ->> 'medical_order_valid_until', '')::date else c.medical_order_valid_until end,
    gp_named                  = case when f ? 'gp_named' then (f ->> 'gp_named')::boolean else c.gp_named end,
    other_providers_active    = case when f ? 'other_providers_active' then (f ->> 'other_providers_active')::boolean else c.other_providers_active end,
    requested_start           = case when f ? 'requested_start' then nullif(f ->> 'requested_start', '')::date else c.requested_start end,
    language_notes            = case when f ? 'language_notes' then nullif(btrim(f ->> 'language_notes'), '') else c.language_notes end,
    access_notes              = case when f ? 'access_notes' then nullif(btrim(f ->> 'access_notes'), '') else c.access_notes end,
    expected_hours_per_week   = case when f ? 'expected_hours_per_week' then nullif(f ->> 'expected_hours_per_week', '')::numeric else c.expected_hours_per_week end
  where c.id = p_case_id;
exception
  when invalid_text_representation or datetime_field_overflow or invalid_datetime_format then
    raise exception 'invalid intake value' using errcode = '22023';
  when check_violation or numeric_value_out_of_range then
    raise exception 'invalid intake value' using errcode = '22023';
end;
$$;

revoke all on function private.apply_case_facts(uuid, jsonb) from public, anon, authenticated;

drop function public.intake_cases();
create function public.intake_cases()
returns table (
  case_id                   uuid,
  client_name               text,
  region                    text,
  urgency                   text,
  care_needs                text[],
  created_at                timestamptz,
  residence_municipality    text,
  residence_canton          text,
  insurer_name              text,
  insurance_type            text,
  medical_order_status      text,
  medical_order_valid_until date,
  gp_named                  boolean,
  other_providers_active    boolean,
  requested_start           date,
  language_notes            text,
  access_notes              text,
  missing                   jsonb,
  open_tasks                text[],
  expected_hours_per_week   numeric
)
language sql stable security definer set search_path = ''
as $$
  select c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), c.region, c.urgency, c.care_needs, c.created_at,
         c.residence_municipality, c.residence_canton, c.insurer_name, c.insurance_type,
         c.medical_order_status, c.medical_order_valid_until, c.gp_named, c.other_providers_active,
         c.requested_start, c.language_notes, c.access_notes,
         private.case_readiness(c.id),
         coalesce((select array_agg(t.kind order by t.kind) from public.case_tasks t
                   where t.case_id = c.id and t.status = 'open'), '{}'),
         c.expected_hours_per_week
  from public.cases c
  where c.ready_for_matching_at is null
    and c.source_partner_request_id is not null
    and private.is_intake_role(c.organization_id)
  order by c.created_at;
$$;
revoke all on function public.intake_cases() from public, anon;
grant execute on function public.intake_cases() to authenticated;

-- 2. Response deadlines (configuration, no values shipped) -----------------------------------
create table public.response_deadlines (
  id              uuid not null default gen_random_uuid() unique,   -- for the audit writer
  organization_id uuid not null references public.organizations (id),
  referral_type   text not null check (referral_type in ('hospital_discharge', 'nursing_home', 'private', 'other')),
  response_hours  integer not null check (response_hours between 1 and 720),
  updated_by      uuid not null,
  updated_at      timestamptz not null default now(),
  primary key (organization_id, referral_type)
);
comment on table public.response_deadlines is
  'J2: team response time per referral type, configured per organisation (Q8). No defaults are shipped.';

alter table public.response_deadlines enable row level security;
revoke all on public.response_deadlines from anon, authenticated;
grant select on public.response_deadlines to authenticated;
create policy coordinators_read on public.response_deadlines
  for select to authenticated using (private.is_coordinator(organization_id));

create trigger audit_response_deadlines
  after insert or update on public.response_deadlines
  for each row execute function private.write_audit_event('referral_type', 'response_hours');

create function public.set_response_deadline(p_organization_id uuid, p_referral_type text, p_hours integer, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then return 'rejected'; end if;
  if p_referral_type is null or p_referral_type not in ('hospital_discharge', 'nursing_home', 'private', 'other')
     or p_hours is null or p_hours not between 1 and 720 then
    raise exception 'referral type and 1–720 hours are required' using errcode = '22023';
  end if;
  if private.begin_command('set_response_deadline', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.has_org_role(p_organization_id, array['admin']) then
    return private.end_command('rejected');
  end if;
  insert into public.response_deadlines (organization_id, referral_type, response_hours, updated_by)
  values (p_organization_id, p_referral_type, p_hours, uid)
  on conflict (organization_id, referral_type)
    do update set response_hours = excluded.response_hours, updated_by = uid, updated_at = now();
  -- Open requests of this type get the new deadline from their creation time.
  update public.matching_requests m
    set response_due_at = m.created_at + make_interval(hours => p_hours)
    where m.organization_id = p_organization_id and m.referral_type = p_referral_type and m.status = 'open';
  return private.end_command('ok');
end;
$$;
revoke all on function public.set_response_deadline(uuid, text, integer, uuid) from public, anon;
grant execute on function public.set_response_deadline(uuid, text, integer, uuid) to authenticated;

-- 3. Matching request facts ---------------------------------------------------------------------------
alter table public.matching_requests
  add column referral_type text check (referral_type is null or referral_type in ('hospital_discharge', 'nursing_home', 'private', 'other')),
  add column response_due_at timestamptz,
  add column required_qualification text check (required_qualification is null or required_qualification = 'registered_nurse');

-- Partner type (J1 intake list) → referral type of Q8. Unknown or missing → other.
create function private.referral_type_of(p_partner_type text)
returns text language sql immutable set search_path = ''
as $$ select case p_partner_type when 'Spital' then 'hospital_discharge' when 'Pflegeheim' then 'nursing_home'
                                 when 'Privat / Angehörige' then 'private' else 'other' end $$;

-- Derived from implemented J3 rules (see header); not a new clinical rule.
create function private.required_qualification(p_case_id uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select case when c.needs_assessment_done_at is null or c.medical_order_status = 'present' then 'registered_nurse' end
  from public.cases c where c.id = p_case_id
$$;

create function private.team_has_registered_nurse(p_team uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.team_memberships m where m.team_id = p_team and m.qualification = 'registered_nurse') $$;

revoke all on function private.referral_type_of(text), private.required_qualification(uuid), private.team_has_registered_nurse(uuid)
  from public, anon, authenticated;

-- Backfill open requests (seed / existing rows): facts are derived, deadlines only if configured.
update public.matching_requests m set
  referral_type = coalesce(m.referral_type, private.referral_type_of(
    (select p.partner_type from public.cases c join public.partner_requests p on p.id = c.source_partner_request_id where c.id = m.case_id))),
  required_qualification = private.required_qualification(m.case_id)
where m.status = 'open';

create or replace function private.open_matching_if_ready(p_case_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
  missing jsonb := private.case_readiness(p_case_id);
  rtype text;
  hours integer;
begin
  if jsonb_array_length(missing) > 0 then
    return missing;
  end if;
  select * into c from public.cases where id = p_case_id;
  if c.ready_for_matching_at is null then
    update public.cases set ready_for_matching_at = now(), next_step = 'Teamentscheid ausstehend' where id = c.id;
  end if;
  if not exists (select 1 from public.matching_requests m where m.case_id = c.id) then
    rtype := private.referral_type_of((select p.partner_type from public.partner_requests p where p.id = c.source_partner_request_id));
    select d.response_hours into hours from public.response_deadlines d
      where d.organization_id = c.organization_id and d.referral_type = rtype;
    insert into public.matching_requests
      (organization_id, case_id, request_title, region, urgency, required_services, status,
       referral_type, response_due_at, required_qualification)
    values
      (c.organization_id, c.id, 'Teamsuche: ' || coalesce(c.bedarf, 'Klientenfall'), c.region, c.urgency,
       coalesce(c.care_needs, '{}'), 'open',
       rtype, case when hours is not null then now() + make_interval(hours => hours) end,
       private.required_qualification(c.id));
  end if;
  return '[]'::jsonb;
end;
$$;
revoke all on function private.open_matching_if_ready(uuid) from public, anon, authenticated;

-- 4. Eligibility -----------------------------------------------------------------------------------------
create or replace function private.request_offered_to_team(p_request_id uuid, p_team_id uuid)
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
      and (m.required_qualification is null or private.team_has_registered_nurse(t.id))
  );
$$;

drop function public.team_offers();
create function public.team_offers()
returns table (
  matching_request_id     uuid,
  team_id                 uuid,
  team_name               text,
  request_title           text,
  region                  text,
  urgency                 text,
  required_services       text[],
  created_at              timestamptz,
  my_team_declined        boolean,
  requested_start         date,
  expected_hours_per_week numeric,
  required_qualification  text,
  response_due_at         timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select m.id, t.id, t.name, m.request_title, m.region, m.urgency, m.required_services, m.created_at,
         exists (select 1 from public.team_decisions d
                 where d.matching_request_id = m.id and d.team_id = t.id and d.decision = 'decline'),
         c.requested_start, c.expected_hours_per_week, m.required_qualification, m.response_due_at
  from public.team_memberships tm
  join public.teams t on t.id = tm.team_id
  join public.matching_requests m on m.organization_id = t.organization_id and m.region = t.region
  join public.cases c on c.id = m.case_id
  where tm.user_id = (select auth.uid())
    and private.is_org_member(t.organization_id)
    and t.status = 'active'
    and m.status = 'open'
    and c.assigned_team_id is null
    and (m.required_qualification is null or private.team_has_registered_nurse(t.id))
  order by case m.urgency when 'hoch' then 0 when 'mittel' then 1 else 2 end, m.response_due_at nulls last, m.created_at;
$$;
revoke all on function public.team_offers() from public, anon;
grant execute on function public.team_offers() to authenticated;

-- 5. Decisions: reason codes; other teams' decisions invisible ----------------------------------------------
alter table public.team_decisions
  add column reason_code text check (reason_code is null or reason_code in ('capacity', 'qualification', 'distance', 'other'));
alter table public.team_decisions
  add constraint team_decisions_decline_needs_code check (decision = 'accept' or reason_code is not null) not valid;

drop policy org_members_read on public.team_decisions;
create policy scoped_read on public.team_decisions
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_coordinator(organization_id) or private.is_team_member(team_id)));

drop function public.decide_matching_request(uuid, uuid, text, text, uuid);

-- Return: 'ok' | 'duplicate' | 'rejected' | 'taken' | 'not_qualified'
create function public.decide_matching_request(
  p_request_id uuid, p_team_id uuid, p_decision text, p_reason text, p_idempotency_key uuid,
  p_reason_code text default null)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid     uuid := (select auth.uid());
  req     public.matching_requests%rowtype;
  tm      public.teams%rowtype;
  why     text := nullif(btrim(p_reason), '');
  code    text := nullif(btrim(p_reason_code), '');
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
  if p_decision = 'decline' then
    if code is null or code not in ('capacity', 'qualification', 'distance', 'other') then
      raise exception 'a decline needs a reason code (capacity, qualification, distance, other)' using errcode = '22023';
    end if;
    if code = 'other' and (why is null or char_length(why) < 3) then
      raise exception 'reason "other" needs a short text' using errcode = '22023';
    end if;
  elsif code is not null then
    raise exception 'an acceptance takes no reason code' using errcode = '22023';
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
    if req.status <> 'open' or exists (select 1 from public.cases c where c.id = req.case_id and c.assigned_team_id is not null) then
      return 'taken';
    end if;
    select * into tm from public.teams where id = p_team_id;
    if tm.status = 'active' and tm.region = req.region and tm.organization_id = req.organization_id
       and req.required_qualification is not null and not private.team_has_registered_nurse(tm.id) then
      return 'not_qualified';
    end if;
    return 'rejected';
  end if;

  perform set_config('navora.command', 'decide_matching_request', true);
  perform set_config('navora.idempotency_key', p_idempotency_key::text, true);

  insert into public.team_decisions
    (organization_id, matching_request_id, case_id, team_id, decision, reason_code, reason, actor_id, idempotency_key)
  values
    (req.organization_id, req.id, req.case_id, p_team_id, p_decision, code, why, uid, p_idempotency_key);

  if p_decision = 'accept' then
    select * into tm from public.teams where id = p_team_id;
    update public.matching_requests set status = 'accepted', selected_team_id = p_team_id where id = req.id;
    update public.cases
      set assigned_team_id = p_team_id, assigned_team = tm.name, status = 'laufend', next_step = 'Einsätze planen'
      where id = req.case_id;
  end if;

  perform set_config('navora.command', '', true);
  perform set_config('navora.idempotency_key', '', true);
  return 'ok';
end;
$$;

revoke all on function public.decide_matching_request(uuid, uuid, text, text, uuid, text) from public, anon;
grant execute on function public.decide_matching_request(uuid, uuid, text, text, uuid, text) to authenticated;

-- 6. Escalation to Operations (coordination roles; never assigns) -----------------------------------------
-- reason: no_eligible_team | all_declined | deadline_passed | deadline_not_configured
create function public.matching_escalations()
returns table (
  matching_request_id uuid,
  request_title       text,
  region              text,
  urgency             text,
  referral_type       text,
  created_at          timestamptz,
  response_due_at     timestamptz,
  reason              text,
  eligible_teams      integer,
  declines            jsonb
)
language sql stable security definer set search_path = ''
as $$
  with open_requests as (
    select m.* from public.matching_requests m
    join public.cases c on c.id = m.case_id
    where m.status = 'open' and c.assigned_team_id is null
      and private.is_coordinator(m.organization_id)
  ), scored as (
    select r.*,
      (select count(*)::int from public.teams t
        where t.organization_id = r.organization_id and t.status = 'active' and t.region = r.region
          and (r.required_qualification is null or private.team_has_registered_nurse(t.id))) as eligible,
      (select count(*)::int from public.teams t
        where t.organization_id = r.organization_id and t.status = 'active' and t.region = r.region
          and (r.required_qualification is null or private.team_has_registered_nurse(t.id))
          and not exists (select 1 from public.team_decisions d where d.matching_request_id = r.id and d.team_id = t.id)) as undecided,
      coalesce((select jsonb_agg(jsonb_build_object('team', t.name, 'code', d.reason_code, 'reason', d.reason, 'at', d.decided_at)
                                 order by d.decided_at)
                from public.team_decisions d join public.teams t on t.id = d.team_id
                where d.matching_request_id = r.id and d.decision = 'decline'), '[]'::jsonb) as declines
    from open_requests r
  )
  select s.id, s.request_title, s.region, s.urgency, s.referral_type, s.created_at, s.response_due_at,
         case when s.eligible = 0 then 'no_eligible_team'
              when s.undecided = 0 then 'all_declined'
              when s.response_due_at is not null and s.response_due_at < now() then 'deadline_passed'
              else 'deadline_not_configured' end,
         s.eligible, s.declines
  from scored s
  where s.eligible = 0 or s.undecided = 0
     or (s.response_due_at is not null and s.response_due_at < now())
     or s.response_due_at is null
  order by s.created_at;
$$;
revoke all on function public.matching_escalations() from public, anon;
grant execute on function public.matching_escalations() to authenticated;
