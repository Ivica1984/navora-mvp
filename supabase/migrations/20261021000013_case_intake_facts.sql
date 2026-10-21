-- =============================================================================
-- J1 (PO changes, brief docs/agents/briefs/J1.md): intake facts, readiness check,
-- matching only for ready cases, non-blocking tasks, protected insurer/order data
-- =============================================================================
-- * New case facts: residence (municipality, canton), health insurer and insurance
--   type (KVG, IV, UV, MV, private, unknown), medical order status (present,
--   requested, not-required-A/C-only) and validity end, GP named, other providers
--   active, requested start, language and access notes. Link to the source referral.
-- * Readiness (blocking): consent, residence, insurer + insurance type, care need
--   with requested start. Engineering interpretation (IMPLEMENTATION_STATUS
--   "Deviations"): insurance type `unknown` counts as missing, because such a case
--   cannot be billed — the PO may overrule.
-- * The matching request is created ONLY by a server-side command once the case
--   is ready (convert or update_case_intake), never from Operations.
-- * Missing non-blocking items become open tasks on the case (case_tasks) and
--   close automatically once the fact is recorded.
-- * Insurer and medical-order data are column-protected: no general SELECT for
--   `authenticated`; readable only through functions that check intake role
--   (admin/operations) or membership in the case's assigned team.
-- * Clinical sign-off of the checklist: D-15 (open). Legal basis of collecting
--   insurer data: D-9 (open) — flagged, not decided by engineering.
-- =============================================================================

-- 1. Case facts --------------------------------------------------------------------
alter table public.cases
  add column source_partner_request_id uuid,
  add column residence_municipality    text check (residence_municipality is null or char_length(residence_municipality) between 2 and 80),
  add column residence_canton          text check (residence_canton is null or residence_canton in
    ('AG','AI','AR','BE','BL','BS','FR','GE','GL','GR','JU','LU','NE','NW','OW','SG','SH','SO','SZ','TG','TI','UR','VD','VS','ZG','ZH')),
  add column insurer_name              text check (insurer_name is null or char_length(insurer_name) between 2 and 120),
  add column insurance_type            text check (insurance_type is null or insurance_type in ('KVG','IV','UV','MV','private','unknown')),
  add column medical_order_status      text check (medical_order_status is null or medical_order_status in ('present','requested','not-required-A/C-only')),
  add column medical_order_valid_until date,
  add column gp_named                  boolean,
  add column other_providers_active    boolean,
  add column requested_start           date,
  add column language_notes            text check (language_notes is null or char_length(language_notes) <= 500),
  add column access_notes              text check (access_notes is null or char_length(access_notes) <= 500),
  add column ready_for_matching_at     timestamptz;

alter table public.partner_requests add constraint partner_requests_id_org_key unique (id, organization_id);
alter table public.cases add constraint cases_source_request_same_org
  foreign key (source_partner_request_id, organization_id) references public.partner_requests (id, organization_id);
create unique index cases_one_per_referral on public.cases (source_partner_request_id) where source_partner_request_id is not null;

-- Backfill the link for cases converted before this migration.
update public.cases c set source_partner_request_id = p.id
from public.partner_requests p
where p.converted_case_id = c.id and c.source_partner_request_id is null;

-- 2. Column protection for insurer and medical-order data ---------------------------
-- NOTE (TD-31): columns added to `cases` later are NOT readable by `authenticated`
-- until a migration grants them explicitly — deliberate default-deny.
do $$
declare
  cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
  from information_schema.columns
  where table_schema = 'public' and table_name = 'cases'
    and column_name not in ('insurer_name', 'insurance_type', 'medical_order_status', 'medical_order_valid_until');
  execute 'revoke select on public.cases from authenticated';
  execute format('grant select (%s) on public.cases to authenticated', cols);
end
$$;

-- 3. Audit: also record readiness and the funding facts' categories (no free text) ---
drop trigger audit_cases on public.cases;
create trigger audit_cases
  after insert or update on public.cases
  for each row execute function private.write_audit_event(
    'status', 'urgency', 'region', 'assigned_team_id', 'intake_consent_confirmed_at',
    'ready_for_matching_at', 'residence_canton', 'insurance_type', 'medical_order_status', 'medical_order_valid_until');

-- 4. Tasks for missing non-blocking items --------------------------------------------------
create table public.case_tasks (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  case_id         uuid not null,
  kind            text not null check (kind in ('gp_missing', 'other_providers_unknown', 'language_unknown', 'access_unknown', 'inform_gp')),
  status          text not null default 'open' check (status in ('open', 'done')),
  created_at      timestamptz not null default now(),
  done_at         timestamptz,
  done_by         uuid,
  foreign key (case_id, organization_id) references public.cases (id, organization_id)
);
create unique index case_tasks_one_open_per_kind on public.case_tasks (case_id, kind) where status = 'open';

alter table public.case_tasks enable row level security;
revoke all on public.case_tasks from anon, authenticated;
grant select on public.case_tasks to authenticated;
create policy org_members_read on public.case_tasks
  for select to authenticated using (private.is_org_member(organization_id));

create trigger audit_case_tasks
  after insert or update on public.case_tasks
  for each row execute function private.write_audit_event('kind', 'status');

-- 5. Helpers ----------------------------------------------------------------------------
create function private.is_intake_role(org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select private.has_org_role(org, array['admin', 'operations']) $$;

revoke all on function private.is_intake_role(uuid) from public, anon;
grant execute on function private.is_intake_role(uuid) to authenticated;

-- Applies the recognised keys of p_facts to the case (validated by the column checks).
create function private.apply_case_facts(p_case_id uuid, p_facts jsonb)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  f jsonb := coalesce(p_facts, '{}'::jsonb);
  unknown text;
begin
  select k into unknown from jsonb_object_keys(f) k
  where k not in ('residence_municipality','residence_canton','insurer_name','insurance_type','medical_order_status',
                  'medical_order_valid_until','gp_named','other_providers_active','requested_start','language_notes','access_notes')
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
    access_notes              = case when f ? 'access_notes' then nullif(btrim(f ->> 'access_notes'), '') else c.access_notes end
  where c.id = p_case_id;
exception
  when invalid_text_representation or datetime_field_overflow or invalid_datetime_format then
    raise exception 'invalid intake value' using errcode = '22023';
  when check_violation then
    raise exception 'invalid intake value' using errcode = '22023';
end;
$$;

-- Blocking readiness items: [{"item": ..., "reason": ...}]; empty array = ready.
create function private.case_readiness(p_case_id uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('item', m.item, 'reason', m.reason) order by m.ord), '[]'::jsonb)
  from public.cases c,
  lateral (values
    (1, 'consent',   'Einwilligung nicht bestätigt',                 c.intake_consent_confirmed_at is null),
    (2, 'residence', 'Wohngemeinde und Kanton fehlen (Restfinanzierung)', c.residence_municipality is null or c.residence_canton is null),
    (3, 'insurer',   'Krankenversicherer fehlt',                     c.insurer_name is null),
    (4, 'insurance_type', 'Versicherungsart fehlt oder unbekannt',   c.insurance_type is null or c.insurance_type = 'unknown'),
    (5, 'care_need', 'Pflegebedarf fehlt',                           c.care_needs is null or cardinality(c.care_needs) = 0),
    (6, 'requested_start', 'Gewünschter Beginn fehlt',               c.requested_start is null)
  ) as m(ord, item, reason, missing)
  where c.id = p_case_id and m.missing;
$$;

-- Internal: only called from the SECURITY DEFINER commands and read models below.
revoke all on function private.apply_case_facts(uuid, jsonb), private.case_readiness(uuid) from public, anon, authenticated;

-- Opens/closes tasks for missing non-blocking items.
create function private.sync_case_tasks(p_case_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
  k text;
  needed boolean;
begin
  select * into c from public.cases where id = p_case_id;
  foreach k in array array['gp_missing', 'other_providers_unknown', 'language_unknown', 'access_unknown'] loop
    needed := case k
      when 'gp_missing' then c.gp_named is distinct from true
      when 'other_providers_unknown' then c.other_providers_active is null
      when 'language_unknown' then c.language_notes is null
      when 'access_unknown' then c.access_notes is null
    end;
    if needed then
      insert into public.case_tasks (organization_id, case_id, kind)
      values (c.organization_id, c.id, k)
      on conflict (case_id, kind) where status = 'open' do nothing;
    else
      update public.case_tasks set status = 'done', done_at = now(), done_by = (select auth.uid())
      where case_id = c.id and kind = k and status = 'open';
    end if;
  end loop;
end;
$$;

-- Creates the open matching request once the case is ready (exactly once per case).
create function private.open_matching_if_ready(p_case_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
  missing jsonb := private.case_readiness(p_case_id);
begin
  if jsonb_array_length(missing) > 0 then
    return missing;
  end if;
  select * into c from public.cases where id = p_case_id;
  if c.ready_for_matching_at is null then
    update public.cases set ready_for_matching_at = now(), next_step = 'Teamentscheid ausstehend' where id = c.id;
  end if;
  if not exists (select 1 from public.matching_requests m where m.case_id = c.id) then
    insert into public.matching_requests
      (organization_id, case_id, request_title, region, urgency, required_services, status)
    values
      (c.organization_id, c.id, 'Teamsuche: ' || coalesce(c.bedarf, 'Klientenfall'), c.region, c.urgency,
       coalesce(c.care_needs, '{}'), 'open');
  end if;
  return '[]'::jsonb;
end;
$$;

revoke all on function private.sync_case_tasks(uuid), private.open_matching_if_ready(uuid) from public, anon, authenticated;

-- 6. Commands -----------------------------------------------------------------------------
-- Return jsonb: {"result": "ok"|"duplicate"|"rejected", "case_id": uuid, "ready": bool, "missing": [...]}
drop function public.convert_partner_request(uuid, text, text, boolean, uuid);

create function public.convert_partner_request(
  p_request_id        uuid,
  p_first_name        text,
  p_last_name         text,
  p_consent_confirmed boolean,
  p_facts             jsonb,
  p_idempotency_key   uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  req      public.partner_requests%rowtype;
  first_n  text;
  last_n   text;
  new_case uuid;
  missing  jsonb;
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_consent_confirmed is distinct from true then
    raise exception 'consent confirmation is required (provisional gate, ADR-026)' using errcode = '22023';
  end if;
  first_n := private.check_text(p_first_name, 1, 100, 'first name');
  last_n  := private.check_text(p_last_name, 1, 100, 'last name');

  if private.begin_command('convert_partner_request', p_idempotency_key) then
    perform private.end_command('duplicate');
    select id into new_case from public.cases c
      where c.source_partner_request_id = p_request_id;
    return jsonb_build_object('result', 'duplicate', 'case_id', new_case);
  end if;

  select * into req from public.partner_requests where id = p_request_id for update;
  if not found
     or not private.is_intake_role(req.organization_id)
     or req.status not in ('open', 'ready_to_convert') then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;

  insert into public.cases
    (organization_id, source_partner_request_id, name, first_name, last_name, region, status, urgency, time_info,
     bedarf, care_needs, next_step, intake_consent_confirmed_at, intake_consent_confirmed_by)
  values
    (req.organization_id, req.id, first_n || ' ' || last_n, first_n, last_n, req.region, 'neu', req.urgency,
     req.time_info, req.request_title, req.requested_services, 'Aufnahme vervollständigen', now(), uid)
  returning id into new_case;

  perform private.apply_case_facts(new_case, p_facts);
  perform private.sync_case_tasks(new_case);
  missing := private.open_matching_if_ready(new_case);

  update public.partner_requests
  set status = 'converted', converted_case_id = new_case
  where id = req.id;

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'case_id', new_case,
                            'ready', jsonb_array_length(missing) = 0, 'missing', missing);
end;
$$;

create function public.update_case_intake(p_case_id uuid, p_facts jsonb, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  c       public.cases%rowtype;
  missing jsonb;
begin
  if (select auth.uid()) is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  if private.begin_command('update_case_intake', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate', 'case_id', p_case_id);
  end if;

  select * into c from public.cases where id = p_case_id for update;
  if not found or not private.is_intake_role(c.organization_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;

  perform private.apply_case_facts(c.id, p_facts);
  perform private.sync_case_tasks(c.id);
  missing := private.open_matching_if_ready(c.id);

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'case_id', c.id,
                            'ready', jsonb_array_length(missing) = 0, 'missing', missing);
end;
$$;

revoke all on function
  public.convert_partner_request(uuid, text, text, boolean, jsonb, uuid),
  public.update_case_intake(uuid, jsonb, uuid)
from public, anon;
grant execute on function
  public.convert_partner_request(uuid, text, text, boolean, jsonb, uuid),
  public.update_case_intake(uuid, jsonb, uuid)
to authenticated;

-- 7. Read models ----------------------------------------------------------------------------
-- Cases still in intake (not yet ready) for the caller's intake organisations.
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
  open_tasks                text[]
)
language sql stable security definer set search_path = ''
as $$
  select c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), c.region, c.urgency, c.care_needs, c.created_at,
         c.residence_municipality, c.residence_canton, c.insurer_name, c.insurance_type,
         c.medical_order_status, c.medical_order_valid_until, c.gp_named, c.other_providers_active,
         c.requested_start, c.language_notes, c.access_notes,
         private.case_readiness(c.id),
         coalesce((select array_agg(t.kind order by t.kind) from public.case_tasks t
                   where t.case_id = c.id and t.status = 'open'), '{}')
  from public.cases c
  where c.ready_for_matching_at is null
    and c.source_partner_request_id is not null
    and private.is_intake_role(c.organization_id)
  order by c.created_at;
$$;

-- Funding facts and tasks of one case: intake roles of the case's organisation, or
-- members of the case's assigned team (J3 needs the order status). Nobody else.
create function public.case_funding_facts(p_case_id uuid)
returns table (
  case_id                   uuid,
  residence_municipality    text,
  residence_canton          text,
  insurer_name              text,
  insurance_type            text,
  medical_order_status      text,
  medical_order_valid_until date,
  gp_named                  boolean,
  ready_for_matching_at     timestamptz,
  open_tasks                text[]
)
language sql stable security definer set search_path = ''
as $$
  select c.id, c.residence_municipality, c.residence_canton, c.insurer_name, c.insurance_type,
         c.medical_order_status, c.medical_order_valid_until, c.gp_named, c.ready_for_matching_at,
         coalesce((select array_agg(t.kind order by t.kind) from public.case_tasks t
                   where t.case_id = c.id and t.status = 'open'), '{}')
  from public.cases c
  where c.id = p_case_id
    and (private.is_intake_role(c.organization_id)
         or (c.assigned_team_id is not null and private.is_org_member(c.organization_id)
             and private.is_team_member(c.assigned_team_id)));
$$;

revoke all on function public.intake_cases(), public.case_funding_facts(uuid) from public, anon;
grant execute on function public.intake_cases(), public.case_funding_facts(uuid) to authenticated;
