-- =============================================================================
-- RET1 — Returning client returns to her team (ADR-048)
-- Brief: docs/agents/briefs/RET1.md (PO, approved 2026-10-22).
-- =============================================================================
-- * Explicit link only: an intake role links a referral to a case of the same organisation that is paused,
--   or closed within the configured period (pilot default 180 days). Reason required, audited.
--   No automatic identity search or matching (D-9).
-- * Paused case: the referral resumes that case (team and primary nurse stay); no new case, no new matching;
--   funding and order facts are applied and the readiness check runs again; the team gets the non-blocking
--   task "review_after_pause".
-- * Closed case: a new case with a reference to the previous one. Its J2 request is first offered to the previous
--   team only (first-refusal window: 1 working hour for hospital discharge, 2 otherwise; inside the response
--   deadline, never extending it). Decline or window end → all eligible teams, as in J2. The window is skipped
--   when the previous team is not eligible under the J2/J3 rules (active, same region, registered nurse if required).
-- * The first-refusal window is a J2 offer with a restricted eligible set (one predicate), not a new mechanism.
-- * When the previous team accepts, the previous primary nurse is proposed (not assigned); the team confirms.
-- =============================================================================

-- 1. Configuration ----------------------------------------------------------------------------------------------
create table public.return_settings (
  id                          uuid primary key default gen_random_uuid(),
  organization_id             uuid references public.organizations (id),
  link_closed_days            integer not null check (link_closed_days between 1 and 3650),
  first_refusal_hours_discharge integer not null check (first_refusal_hours_discharge between 1 and 40),
  first_refusal_hours_other   integer not null check (first_refusal_hours_other between 1 and 40),
  unique nulls not distinct (organization_id)
);
comment on table public.return_settings is 'RET1: link period for closed cases and first-refusal windows (null org = default).';
insert into public.return_settings (organization_id, link_closed_days, first_refusal_hours_discharge, first_refusal_hours_other)
values (null, 180, 1, 2);
alter table public.return_settings enable row level security;
revoke all on public.return_settings from anon, authenticated;
grant select on public.return_settings to authenticated;
create policy members_read on public.return_settings for select to authenticated
  using (organization_id is null or private.is_org_member(organization_id));

create function private.return_setting(p_org uuid)
returns public.return_settings language sql stable security definer set search_path = ''
as $$
  select s.* from public.return_settings s where s.organization_id = p_org or s.organization_id is null
  order by s.organization_id nulls last limit 1
$$;

-- 2. Data -----------------------------------------------------------------------------------------------------------
alter table public.cases
  add column previous_case_id           uuid,
  add column proposed_primary_nurse_id  uuid,
  add constraint cases_previous_same_org foreign key (previous_case_id, organization_id)
    references public.cases (id, organization_id);
comment on column public.cases.previous_case_id is 'RET1: the earlier case of a returning client, linked by intake (no automatic matching).';
comment on column public.cases.proposed_primary_nurse_id is 'RET1: previous primary nurse, proposed when the previous team accepts; the team confirms (J6).';

alter table public.matching_requests
  add column preferred_team_id    uuid,
  add column first_refusal_until  timestamptz,
  add constraint matching_requests_preferred_same_org foreign key (preferred_team_id, organization_id)
    references public.teams (id, organization_id);

alter table public.case_tasks drop constraint case_tasks_kind_check;
alter table public.case_tasks add constraint case_tasks_kind_check check (kind in
  ('gp_missing', 'other_providers_unknown', 'language_unknown', 'access_unknown', 'inform_gp', 'review_after_pause'));
alter table public.case_tasks add column detail text check (detail is null or char_length(detail) <= 120);

create table public.referral_links (
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references public.organizations (id),
  partner_request_id  uuid not null unique references public.partner_requests (id),
  linked_case_id      uuid not null,
  new_case_id         uuid,
  kind                text not null check (kind in ('resume', 'return')),
  reason              text not null check (char_length(btrim(reason)) between 3 and 300),
  actor_id            uuid not null,
  idempotency_key     uuid not null,
  created_at          timestamptz not null default now(),
  unique (actor_id, idempotency_key),
  foreign key (linked_case_id, organization_id) references public.cases (id, organization_id),
  foreign key (new_case_id, organization_id) references public.cases (id, organization_id)
);
comment on table public.referral_links is 'RET1: a referral linked by intake to an earlier case (append-only).';
alter table public.referral_links enable row level security;
revoke all on public.referral_links from anon, authenticated;
grant select on public.referral_links to authenticated;
create policy intake_read on public.referral_links for select to authenticated using (private.is_intake_role(organization_id));
create trigger referral_links_no_update_delete before update or delete on public.referral_links
  for each row execute function private.forbid_audit_change();
create trigger referral_links_no_truncate before truncate on public.referral_links
  for each statement execute function private.forbid_audit_change();
create trigger audit_referral_links after insert on public.referral_links
  for each row execute function private.write_audit_event('kind', 'linked_case_id', 'new_case_id');

-- 3. Helpers --------------------------------------------------------------------------------------------------------
-- When a case was closed or paused (latest lifecycle event of that kind).
create function private.case_lifecycle_at(p_case uuid, p_kind text)
returns timestamptz language sql stable security definer set search_path = ''
as $$ select max(l.created_at) from public.case_lifecycle_events l where l.case_id = p_case and l.kind = p_kind $$;

-- 'paused' | 'closed' when a referral of p_org may be linked to the case, else null.
create function private.linkable_kind(p_case uuid, p_org uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select case
    when c.lifecycle = 'paused' then 'paused'
    when c.lifecycle = 'closed'
         and private.case_lifecycle_at(c.id, 'close') >= now() - make_interval(days => (private.return_setting(c.organization_id)).link_closed_days)
      then 'closed'
  end
  from public.cases c where c.id = p_case and c.organization_id = p_org
$$;

-- The previous primary nurse of a case: the last value the audit trail recorded (close clears it).
create function private.last_primary_nurse(p_case uuid)
returns uuid language sql stable security definer set search_path = ''
as $$
  select coalesce(c.primary_nurse_id, (
    select coalesce(a.changed -> 'primary_nurse_id' ->> 'new', a.changed -> 'primary_nurse_id' ->> 'old')::uuid
    from public.audit_events a
    where a.table_name = 'cases' and a.entity_id = p_case
      and (a.changed -> 'primary_nurse_id' -> 'old') is distinct from (a.changed -> 'primary_nurse_id' -> 'new')
      and coalesce(a.changed -> 'primary_nurse_id' ->> 'new', a.changed -> 'primary_nurse_id' ->> 'old') is not null
    order by a.id desc limit 1))
  from public.cases c where c.id = p_case
$$;

-- First refusal for a returning client's request: the previous team only, inside the response deadline.
create function private.set_first_refusal(p_request uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  m     public.matching_requests%rowtype;
  c     public.cases%rowtype;
  prev  public.cases%rowtype;
  t     public.teams%rowtype;
  s     public.return_settings;
  until timestamptz;
begin
  select * into m from public.matching_requests where id = p_request;
  select * into c from public.cases where id = m.case_id;
  if c.previous_case_id is null then return; end if;
  select * into prev from public.cases where id = c.previous_case_id and organization_id = c.organization_id;
  select * into t from public.teams where id = prev.assigned_team_id;
  -- Skipped when the previous team is not eligible under the J2/J3 rules.
  if t.id is null or t.organization_id <> m.organization_id or t.status <> 'active' or t.region is distinct from m.region
     or (m.required_qualification is not null and not private.team_has_registered_nurse(t.id)) then
    return;
  end if;
  s := private.return_setting(m.organization_id);
  until := private.add_working_time(now(),
             case when m.referral_type = 'hospital_discharge' then s.first_refusal_hours_discharge else s.first_refusal_hours_other end,
             'working_hours');
  if m.response_due_at is not null and m.response_due_at < until then
    until := m.response_due_at;        -- inside the deadline, never extending it
  end if;
  update public.matching_requests set preferred_team_id = t.id, first_refusal_until = until where id = m.id;
end;
$$;

-- Is the request (still) reserved for its preferred team?
create function private.first_refusal_open(p_request uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select m.preferred_team_id is not null and m.first_refusal_until is not null and now() < m.first_refusal_until
         and not exists (select 1 from public.team_decisions d where d.matching_request_id = m.id and d.team_id = m.preferred_team_id)
  from public.matching_requests m where m.id = p_request
$$;

revoke all on function private.return_setting(uuid), private.case_lifecycle_at(uuid, text), private.linkable_kind(uuid, uuid),
  private.last_primary_nurse(uuid), private.set_first_refusal(uuid), private.first_refusal_open(uuid)
  from public, anon, authenticated;

-- 4. J2 with the restricted eligible set ------------------------------------------------------------------------------
create or replace function private.open_matching_if_ready(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
  missing jsonb := private.case_readiness(p_case_id);
  rtype text;
  rid uuid;
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
    insert into public.matching_requests
      (organization_id, case_id, request_title, region, urgency, required_services, status,
       referral_type, response_due_at, required_qualification)
    values
      (c.organization_id, c.id, 'Teamsuche: ' || coalesce(c.bedarf, 'Klientenfall'), c.region, c.urgency,
       coalesce(c.care_needs, '{}'), 'open',
       rtype, private.response_due(c.organization_id, rtype, now()),
       private.required_qualification(c.id))
    returning id into rid;
    perform private.set_first_refusal(rid);   -- RET1: returning client
  end if;
  return '[]'::jsonb;
end;
$$;

create or replace function private.request_offered_to_team(p_request_id uuid, p_team_id uuid)
returns boolean language sql stable security definer set search_path = ''
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
      and (m.preferred_team_id = t.id or not private.first_refusal_open(m.id))   -- RET1
  );
$$;

drop function public.team_offers();
create function public.team_offers()
returns table (matching_request_id uuid, team_id uuid, team_name text, request_title text, region text, urgency text,
               required_services text[], created_at timestamptz, my_team_declined boolean, requested_start date,
               expected_hours_per_week numeric, required_qualification text, response_due_at timestamptz,
               returning_client boolean, first_refusal_until timestamptz)
language sql stable security definer set search_path = ''
as $$
  -- RET1: only the preferred (previous) team sees "returning" and its window; other teams see the J2 offer
  -- without any mention of an earlier case, and only once the window is over or declined.
  select m.id, t.id, t.name, m.request_title, m.region, m.urgency, m.required_services, m.created_at,
         exists (select 1 from public.team_decisions d
                 where d.matching_request_id = m.id and d.team_id = t.id and d.decision = 'decline'),
         c.requested_start, c.expected_hours_per_week, m.required_qualification, m.response_due_at,
         coalesce(m.preferred_team_id = t.id, false), case when m.preferred_team_id = t.id then m.first_refusal_until end
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
    and (m.preferred_team_id = t.id or not private.first_refusal_open(m.id))
  order by case m.urgency when 'hoch' then 0 when 'mittel' then 1 else 2 end, m.response_due_at nulls last, m.created_at;
$$;
revoke all on function public.team_offers() from public, anon;
grant execute on function public.team_offers() to authenticated;

-- The previous team accepts: propose the previous primary nurse if she is still in the team (J6 stays the team's call).
create function private.propose_previous_primary()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  prev uuid;
  nurse uuid;
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted'
     and new.preferred_team_id is not null and new.selected_team_id = new.preferred_team_id then
    select c.previous_case_id into prev from public.cases c where c.id = new.case_id;
    nurse := private.last_primary_nurse(prev);
    if nurse is not null and exists (select 1 from public.team_memberships m where m.team_id = new.selected_team_id and m.user_id = nurse) then
      update public.cases set proposed_primary_nurse_id = nurse where id = new.case_id;
    end if;
  end if;
  return null;
end;
$$;
revoke all on function private.propose_previous_primary() from public, anon, authenticated;
create trigger matching_requests_propose_primary after update of status on public.matching_requests
  for each row execute function private.propose_previous_primary();

-- The proposal ends once the team sets a primary nurse.
create function private.clear_primary_proposal()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.primary_nurse_id is distinct from old.primary_nurse_id and new.proposed_primary_nurse_id is not null then
    update public.cases set proposed_primary_nurse_id = null where id = new.id;
  end if;
  return null;
end;
$$;
revoke all on function private.clear_primary_proposal() from public, anon, authenticated;
create trigger cases_clear_primary_proposal after update of primary_nurse_id on public.cases
  for each row execute function private.clear_primary_proposal();

-- 5. Intake: which cases can a referral be linked to --------------------------------------------------------------------
create function public.linkable_cases(p_request_id uuid)
returns table (case_id uuid, client_name text, lifecycle text, team_name text, since timestamptz, reason_code text)
language sql stable security definer set search_path = ''
as $$
  select c.id, c.name, k.kind, t.name,
         private.case_lifecycle_at(c.id, case k.kind when 'paused' then 'pause' else 'close' end),
         (select l.reason_code from public.case_lifecycle_events l
          where l.case_id = c.id and l.kind = case k.kind when 'paused' then 'pause' else 'close' end
          order by l.created_at desc limit 1)
  from public.partner_requests r
  join public.cases c on c.organization_id = r.organization_id
  cross join lateral (select private.linkable_kind(c.id, r.organization_id) as kind) k
  left join public.teams t on t.id = c.assigned_team_id
  where r.id = p_request_id and private.is_intake_role(r.organization_id) and k.kind is not null
    and r.status in ('open', 'ready_to_convert')
  order by c.name, c.id
$$;
revoke all on function public.linkable_cases(uuid) from public, anon;
grant execute on function public.linkable_cases(uuid) to authenticated;

-- 6. Command: link a referral to an earlier case -----------------------------------------------------------------------
-- Return jsonb {"result": 'ok'|'duplicate'|'rejected'|'not_linkable', "kind": 'resume'|'return', "case_id", "ready", "missing"}
create function public.link_returning_referral(
  p_request_id uuid, p_case_id uuid, p_reason text, p_first_name text, p_last_name text,
  p_consent_confirmed boolean, p_facts jsonb, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  why      text;
  req      public.partner_requests%rowtype;
  prev     public.cases%rowtype;
  after    public.cases%rowtype;
  v_kind   text;
  first_n  text;
  last_n   text;
  new_case uuid;
  missing  jsonb;
  diff     jsonb := '{}'::jsonb;
  f        text;
  pause_reason text;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_consent_confirmed is distinct from true then
    raise exception 'consent confirmation is required (provisional gate, ADR-026)' using errcode = '22023';
  end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('link_returning_referral', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate',
      'case_id', (select coalesce(l.new_case_id, l.linked_case_id) from public.referral_links l where l.partner_request_id = p_request_id));
  end if;

  select * into req from public.partner_requests where id = p_request_id for update;
  if not found or not private.is_intake_role(req.organization_id) or req.status not in ('open', 'ready_to_convert') then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  select * into prev from public.cases where id = p_case_id and organization_id = req.organization_id for update;
  v_kind := case when found then private.linkable_kind(prev.id, req.organization_id) end;
  if v_kind is null then
    perform private.end_command('not_linkable');
    return jsonb_build_object('result', 'not_linkable');   -- other organisation, active, or closed too long ago
  end if;

  if v_kind = 'paused' then
    -- Resume the case with its team and primary nurse; apply changed funding and order facts; readiness again.
    perform private.apply_case_facts(prev.id, coalesce(p_facts, '{}'::jsonb));
    select * into after from public.cases where id = prev.id;
    foreach f in array array['insurer_name', 'insurance_type', 'medical_order_status', 'medical_order_valid_until'] loop
      if to_jsonb(prev) -> f is distinct from to_jsonb(after) -> f then
        diff := diff || jsonb_build_object(f, jsonb_build_object('old', to_jsonb(prev) -> f, 'new', to_jsonb(after) -> f));
      end if;
    end loop;
    if diff <> '{}'::jsonb then
      insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
      values (prev.organization_id, 'cases', prev.id::text, 'update_case_intake', diff, why, uid, p_idempotency_key);
    end if;
    perform private.sync_case_tasks(prev.id);
    missing := private.case_readiness(prev.id);

    select l.reason_code into pause_reason from public.case_lifecycle_events l
      where l.case_id = prev.id and l.kind = 'pause' order by l.created_at desc limit 1;
    insert into public.case_lifecycle_events (organization_id, case_id, kind, note, actor_id, idempotency_key)
    values (prev.organization_id, prev.id, 'resume', 'Rückkehr: ' || why, uid, p_idempotency_key);
    update public.cases set lifecycle = 'active' where id = prev.id;
    update public.care_visits v set suspended_at = null, suspended_by = null
    where v.case_id = prev.id and v.suspended_at is not null and v.status = 'planned'
      and v.visit_date >= (now() at time zone 'Europe/Zurich')::date;
    insert into public.case_tasks (organization_id, case_id, kind, detail)
    values (prev.organization_id, prev.id, 'review_after_pause', pause_reason)
    on conflict (case_id, kind) where status = 'open' do nothing;

    update public.partner_requests set status = 'converted', converted_case_id = prev.id where id = req.id;
    insert into public.referral_links (organization_id, partner_request_id, linked_case_id, kind, reason, actor_id, idempotency_key)
    values (req.organization_id, req.id, prev.id, 'resume', why, uid, p_idempotency_key);
    perform private.end_command('ok');
    return jsonb_build_object('result', 'ok', 'kind', 'resume', 'case_id', prev.id,
                              'ready', jsonb_array_length(missing) = 0, 'missing', missing);
  end if;

  -- Closed within the period: a new case (one case per referral) with a reference to the previous one.
  first_n := private.check_text(p_first_name, 1, 100, 'first name');
  last_n  := private.check_text(p_last_name, 1, 100, 'last name');
  insert into public.cases
    (organization_id, source_partner_request_id, name, first_name, last_name, region, status, urgency, time_info,
     bedarf, care_needs, next_step, intake_consent_confirmed_at, intake_consent_confirmed_by, previous_case_id)
  values
    (req.organization_id, req.id, first_n || ' ' || last_n, first_n, last_n, req.region, 'neu', req.urgency,
     req.time_info, req.request_title, req.requested_services, 'Aufnahme vervollständigen', now(), uid, prev.id)
  returning id into new_case;
  perform private.apply_case_facts(new_case, coalesce(p_facts, '{}'::jsonb));
  perform private.sync_case_tasks(new_case);
  missing := private.open_matching_if_ready(new_case);   -- sets the first-refusal window when matching opens
  update public.partner_requests set status = 'converted', converted_case_id = new_case where id = req.id;
  insert into public.referral_links (organization_id, partner_request_id, linked_case_id, new_case_id, kind, reason, actor_id, idempotency_key)
  values (req.organization_id, req.id, prev.id, new_case, 'return', why, uid, p_idempotency_key);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'kind', 'return', 'case_id', new_case,
                            'ready', jsonb_array_length(missing) = 0, 'missing', missing);
end;
$$;
revoke all on function public.link_returning_referral(uuid, uuid, text, text, text, boolean, jsonb, uuid) from public, anon;
grant execute on function public.link_returning_referral(uuid, uuid, text, text, text, boolean, jsonb, uuid) to authenticated;

-- 7. The team closes the non-blocking review task ------------------------------------------------------------------------
create function public.complete_case_task(p_case_id uuid, p_kind text, p_idempotency_key uuid)
returns text language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
begin
  if uid is null then return 'rejected'; end if;
  if p_kind is distinct from 'review_after_pause' then
    raise exception 'only the review task is closed by the team; the other tasks follow the case facts' using errcode = '22023';
  end if;
  if private.begin_command('complete_case_task', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from public.cases where id = p_case_id;
  if not found or not private.is_org_member(c.organization_id) or not private.is_team_member(c.assigned_team_id) then
    return private.end_command('rejected');
  end if;
  update public.case_tasks set status = 'done', done_at = now(), done_by = uid
  where case_id = c.id and kind = p_kind and status = 'open';
  if not found then return private.end_command('unchanged'); end if;
  return private.end_command('ok');
end;
$$;
revoke all on function public.complete_case_task(uuid, text, uuid) from public, anon;
grant execute on function public.complete_case_task(uuid, text, uuid) to authenticated;

-- 8. team_cases: the proposed primary nurse and the pause reason of the review task --------------------------------------
do $patch$
declare
  def text := pg_get_functiondef('public.team_cases()'::regprocedure);
  a   text := 'primary_nurse_id uuid, deputy_nurse_id uuid)';
  b   text := 'c.primary_nurse_id, c.deputy_nurse_id';
begin
  if position(a in def) = 0 or position(b in def) = 0 then
    raise exception 'team_cases no longer matches the RET1 patch';
  end if;
  def := replace(def, a, 'primary_nurse_id uuid, deputy_nurse_id uuid, proposed_primary_nurse_id uuid, review_after_pause_reason text)');
  def := replace(def, b, b || ', c.proposed_primary_nurse_id,
         (select k.detail from public.case_tasks k where k.case_id = c.id and k.kind = ''review_after_pause'' and k.status = ''open'')');
  drop function public.team_cases();
  execute def;
  revoke all on function public.team_cases() from public, anon;
  grant execute on function public.team_cases() to authenticated;
end
$patch$;

-- 9. AN1: returning clients ---------------------------------------------------------------------------------------------
do $patch$
declare
  def text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  a   text := '  all_rows as (
    select * from visit_kpis';
  b   text := 'union all select * from handover_kpi
  )';
  c   text := '              when r.kpi = ''open_p1_exceptions'' then';
begin
  if position(a in def) = 0 or position(b in def) = 0 or position(c in def) = 0 then
    raise exception 'pilot_kpis no longer matches the RET1 patch';
  end if;
  def := replace(def, a, '  -- RET1: referrals linked to an earlier case this month (coordination roles; organisation level only).
  returning_links as (
    select l.organization_id, l.kind, l.created_at,
           coalesce(l.new_case_id, l.linked_case_id) as case_id,
           (select c.assigned_team_id from public.cases c where c.id = coalesce(l.new_case_id, l.linked_case_id)) as now_team,
           (select c.assigned_team_id from public.cases c where c.id = l.linked_case_id) as prev_team,
           (select min(e.occurred_at) from public.care_visits v join public.visit_events e on e.visit_id = v.id and e.event_type = ''started''
            where v.case_id = coalesce(l.new_case_id, l.linked_case_id) and e.occurred_at >= l.created_at) as first_visit_at
    from public.referral_links l join my_orgs o on o.organization_id = l.organization_id and o.coordinator, params p
    where l.created_at >= p.m0 and l.created_at < p.m1
  ),
  returning_kpi as (
    select r.organization_id, null::uuid as team_id, ''returning_previous_team_share'' as kpi,
           round(100.0 * count(*) filter (where r.kind = ''resume'' or (r.now_team is not null and r.now_team = r.prev_team))
                 / nullif(count(*) filter (where r.kind = ''resume'' or r.now_team is not null), 0), 1) as value,
           (count(*) filter (where r.kind = ''resume'' or r.now_team is not null))::int as base
    from returning_links r group by r.organization_id
    union all
    select r.organization_id, null::uuid, ''returning_referral_to_first_visit_days'',
           round((percentile_cont(0.5) within group (order by extract(epoch from (r.first_visit_at - r.created_at)) / 86400))::numeric, 1),
           count(*)::int
    from returning_links r where r.first_visit_at is not null group by r.organization_id
  ),
' || a);
  def := replace(def, b, 'union all select * from handover_kpi union all select * from returning_kpi
  )');
  def := replace(def, c, '              when r.kpi = ''returning_previous_team_share''
                then ''Mit früherem Fall verknüpfte Zuweisungen; Basis: fortgesetzte Fälle und neue Fälle mit Team.''
              when r.kpi = ''returning_referral_to_first_visit_days''
                then ''Ab Verknüpfung bis zum ersten begonnenen Einsatz. Vergleich: «Zuweisung bis erster Einsatz» (alle Fälle).''
' || c);
  execute def;
end
$patch$;
