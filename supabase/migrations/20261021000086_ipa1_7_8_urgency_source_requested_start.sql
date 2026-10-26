-- IPA1-7, IPA1-8 (brief `docs/agents/briefs/IPA1.md`, PO addendum 2026-10-26 18:10; `cra` CGR-69; ADR-100;
-- remediation plan `docs/agents/clinical/remediation/CGR-69.md`).
--
-- IPA1-7: the intake urgency has no preset and a recorded source.
--   * `urgency_source` on partner_requests, cases and matching_requests: 'referrer_stated' ("vom Zuweiser
--     angegeben") | 'intake_assessed' ("bei der Aufnahme eingeschätzt") | 'unknown' ("Quelle nicht erfasst").
--     Existing rows read 'unknown' and are never back-filled as either recorded value. The column default stays
--     'unknown' so a writer that does not name a source records exactly that, never a guess.
--   * public.record_partner_request (the only intake command that sets an urgency) refuses a missing urgency
--     (`urgency_required`) and a missing or unknown source (`urgency_source_required`).
--   * The case path (convert_partner_request 0013, link_returning_referral 0034) copies `urgency` from the request;
--     a BEFORE INSERT trigger copies the source with it, and the matching request takes both from the case
--     (private.open_matching_if_ready 0034). No other command sets an urgency (ADR-100 lists the writers).
--   * public.team_offers returns `urgency_source`. Its ORDER BY (G3) is not touched.
--   * The person who recorded the source is the actor already in the audit trail; no new person field.
-- IPA1-8: the referrer's requested first-visit date.
--   * `referrer_requested_start` (date, optional) on the same three tables; refused before the request's creation
--     date (Europe/Zurich); copied like the source; returned by team_offers. It is not read by any order, filter,
--     escalation, deadline or readiness rule. It is a different fact from `cases.requested_start` (0013), which
--     the intake person records in the case facts (deviation (1), ADR-100).
--
-- No clinical rule is added: NAVORA sets no criteria for any urgency level or for choosing a source (D-34 question 7
-- stays with `clinical`). Idempotent: every statement can run twice.

-- 1. Columns ------------------------------------------------------------------------------------------------------
alter table public.partner_requests
  add column if not exists urgency_source text not null default 'unknown'
    constraint partner_requests_urgency_source_check check (urgency_source in ('referrer_stated', 'intake_assessed', 'unknown')),
  add column if not exists referrer_requested_start date;
alter table public.cases
  add column if not exists urgency_source text not null default 'unknown'
    constraint cases_urgency_source_check check (urgency_source in ('referrer_stated', 'intake_assessed', 'unknown')),
  add column if not exists referrer_requested_start date;
alter table public.matching_requests
  add column if not exists urgency_source text not null default 'unknown'
    constraint matching_requests_urgency_source_check check (urgency_source in ('referrer_stated', 'intake_assessed', 'unknown')),
  add column if not exists referrer_requested_start date;

-- IPA1-8: never before the day the request was recorded (Zurich calendar day).
alter table public.partner_requests drop constraint if exists partner_requests_referrer_start_not_before_request;
alter table public.partner_requests add constraint partner_requests_referrer_start_not_before_request
  check (referrer_requested_start is null or referrer_requested_start >= (created_at at time zone 'Europe/Zurich')::date);

comment on column public.partner_requests.urgency_source is
  'IPA1-7: who set the urgency: referrer_stated | intake_assessed | unknown (rows before IPA1-7). No criteria in NAVORA.';
comment on column public.partner_requests.referrer_requested_start is
  'IPA1-8: first-visit date the referrer asked for. Shown only; never orders, filters, escalates or sets a deadline.';
comment on column public.cases.urgency_source is 'IPA1-7: copied from the partner request at case creation.';
comment on column public.cases.referrer_requested_start is
  'IPA1-8: copied from the partner request; not the intake fact requested_start (0013).';
comment on column public.matching_requests.urgency_source is 'IPA1-7: copied from the case when matching opens.';
comment on column public.matching_requests.referrer_requested_start is 'IPA1-8: copied from the case when matching opens.';

-- Column grants: partner_requests keeps its table-level SELECT for coordinators (RLS coordinators_read, 0015), so
-- /intake reads both columns. cases and matching_requests get no new column grant: teams read them through
-- public.team_offers only (data minimisation, ADR-100 (3)). App roles have no INSERT or UPDATE on the three tables
-- (0003, 0010); every write goes through a SECURITY DEFINER command.

-- 2. The source and the date travel with the urgency -------------------------------------------------------------
create or replace function private.case_takes_request_provenance()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.source_partner_request_id is not null then
    select r.urgency_source, r.referrer_requested_start
      into new.urgency_source, new.referrer_requested_start
      from public.partner_requests r
     where r.id = new.source_partner_request_id;
    new.urgency_source := coalesce(new.urgency_source, 'unknown');
  end if;
  return new;
end;
$$;
revoke all on function private.case_takes_request_provenance() from public, anon, authenticated;

drop trigger if exists cases_take_request_provenance on public.cases;
create trigger cases_take_request_provenance
  before insert on public.cases
  for each row execute function private.case_takes_request_provenance();

create or replace function private.matching_takes_case_provenance()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.case_id is not null then
    select c.urgency_source, c.referrer_requested_start
      into new.urgency_source, new.referrer_requested_start
      from public.cases c
     where c.id = new.case_id;
    new.urgency_source := coalesce(new.urgency_source, 'unknown');
  end if;
  return new;
end;
$$;
revoke all on function private.matching_takes_case_provenance() from public, anon, authenticated;

drop trigger if exists matching_requests_take_case_provenance on public.matching_requests;
create trigger matching_requests_take_case_provenance
  before insert on public.matching_requests
  for each row execute function private.matching_takes_case_provenance();

-- 3. The intake command -------------------------------------------------------------------------------------------
-- Two parameters appended (defaults null so a call that omits them is refused, not ambiguous); the old 11-argument
-- signature is dropped so no caller can record an urgency without its source.
drop function if exists public.record_partner_request(uuid, text, text, text, text, text, text, text, text, text[], uuid);

create or replace function public.record_partner_request(
  p_organization_id    uuid,
  p_partner_name       text,
  p_partner_type       text,
  p_region             text,
  p_city               text,
  p_urgency            text,
  p_time_info          text,
  p_request_title      text,
  p_need_summary       text,
  p_requested_services text[],
  p_idempotency_key    uuid,
  p_urgency_source     text default null,
  p_requested_start    date default null)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  services text[];
begin
  if (select auth.uid()) is null
     or not private.has_org_role(p_organization_id, array['admin', 'operations']) then
    return 'rejected';
  end if;
  if nullif(btrim(p_urgency), '') is null then
    raise exception 'urgency_required' using errcode = '22023';
  end if;
  if p_urgency not in ('niedrig', 'mittel', 'hoch') then
    raise exception 'urgency must be niedrig, mittel or hoch' using errcode = '22023';
  end if;
  if p_urgency_source is null or p_urgency_source not in ('referrer_stated', 'intake_assessed') then
    raise exception 'urgency_source_required' using errcode = '22023';
  end if;
  if p_requested_start is not null and p_requested_start < (private.now() at time zone 'Europe/Zurich')::date then
    raise exception 'requested_start_before_request' using errcode = '22023';
  end if;
  select coalesce(array_agg(btrim(s)) filter (where btrim(s) <> ''), '{}')
    into services from unnest(coalesce(p_requested_services, '{}')) as s;
  if cardinality(services) > 20 or exists (select 1 from unnest(services) s where char_length(s) > 80) then
    raise exception 'at most 20 services of up to 80 characters' using errcode = '22023';
  end if;

  if private.begin_command('record_partner_request', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;

  insert into public.partner_requests
    (organization_id, partner_name, partner_type, region, city, urgency, urgency_source, referrer_requested_start,
     time_info, request_title, need_summary, requested_services, status)
  values
    (p_organization_id,
     private.check_text(p_partner_name, 2, 120, 'partner name'),
     nullif(btrim(p_partner_type), ''),
     private.check_text(p_region, 2, 80, 'region'),
     nullif(btrim(p_city), ''),
     p_urgency,
     p_urgency_source,
     p_requested_start,
     nullif(btrim(p_time_info), ''),
     private.check_text(p_request_title, 3, 160, 'title'),
     private.check_text(p_need_summary, 3, 2000, 'need summary'),
     services,
     'open');

  return private.end_command('ok');
end;
$$;
revoke all on function public.record_partner_request(uuid, text, text, text, text, text, text, text, text, text[], uuid, text, date)
  from public, anon;
grant execute on function public.record_partner_request(uuid, text, text, text, text, text, text, text, text, text[], uuid, text, date)
  to authenticated;

-- 4. The team sees the source (and the referrer's date) beside the level before it decides --------------------------
-- Body as 0034 with two columns added; the ORDER BY (G3) is unchanged.
drop function if exists public.team_offers();
create function public.team_offers()
returns table (matching_request_id uuid, team_id uuid, team_name text, request_title text, region text, urgency text,
               required_services text[], created_at timestamptz, my_team_declined boolean, requested_start date,
               expected_hours_per_week numeric, required_qualification text, response_due_at timestamptz,
               returning_client boolean, first_refusal_until timestamptz,
               urgency_source text, referrer_requested_start date)
language sql stable security definer set search_path = ''
as $$
  -- RET1: only the preferred (previous) team sees "returning" and its window; other teams see the J2 offer
  -- without any mention of an earlier case, and only once the window is over or declined.
  select m.id, t.id, t.name, m.request_title, m.region, m.urgency, m.required_services, m.created_at,
         exists (select 1 from public.team_decisions d
                 where d.matching_request_id = m.id and d.team_id = t.id and d.decision = 'decline'),
         c.requested_start, c.expected_hours_per_week, m.required_qualification, m.response_due_at,
         coalesce(m.preferred_team_id = t.id, false), case when m.preferred_team_id = t.id then m.first_refusal_until end,
         m.urgency_source, m.referrer_requested_start
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

-- 5. Audit: the source and the referrer's date are recorded with the urgency ----------------------------------------
drop trigger if exists audit_partner_requests on public.partner_requests;
create trigger audit_partner_requests
  after insert or update on public.partner_requests
  for each row execute function private.write_audit_event(
    'status', 'urgency', 'region', 'converted_case_id', 'urgency_source', 'referrer_requested_start');
drop trigger if exists audit_cases on public.cases;
create trigger audit_cases
  after insert or update on public.cases
  for each row execute function private.write_audit_event(
    'status', 'urgency', 'region', 'assigned_team_id', 'intake_consent_confirmed_at',
    'ready_for_matching_at', 'residence_canton', 'insurance_type', 'medical_order_status', 'medical_order_valid_until',
    'urgency_source', 'referrer_requested_start');
drop trigger if exists audit_matching_requests on public.matching_requests;
create trigger audit_matching_requests
  after insert or update on public.matching_requests
  for each row execute function private.write_audit_event(
    'status', 'urgency', 'region', 'case_id', 'selected_team_id', 'urgency_source', 'referrer_requested_start');

-- AUD1-1 value catalogue (0077): every audited key is classified.
insert into private.audit_value_classes (table_name, key, class) values
  ('partner_requests',  'urgency_source',           'code'),   -- fixed values, constraint above
  ('partner_requests',  'referrer_requested_start', 'code'),   -- date
  ('cases',             'urgency_source',           'code'),
  ('cases',             'referrer_requested_start', 'code'),
  ('matching_requests', 'urgency_source',           'code'),
  ('matching_requests', 'referrer_requested_start', 'code')
on conflict do nothing;
