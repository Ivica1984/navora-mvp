-- =============================================================================
-- J1 — Referral intake: partner request → (review) → case + open matching request
-- ARCHITECTURE.md data flow: partner_requests → cases → matching_requests → …
-- DOMAIN_RULES: "Partneranfrage kann nach Prüfung in Klientenfall überführt
-- werden; Status- und Zustimmungsgates OPEN." / "Matching ist eigener Prozess;
-- Operations löst ihn nicht aus."
-- =============================================================================
-- * Who: organisation roles `admin` and `operations` (placeholders, Q4).
--   Coaches are excluded (NAVORA coaches, does not dispatch); nurses work in
--   /field. Teams take cases themselves (J2).
-- * Conversion is one atomic, idempotent, audited command. It creates the case
--   (status `neu`, no team) and an OPEN matching request for the case's region
--   and services. It does not pick, rank or notify teams: the team decision is J2.
-- * Consent gate (PROVISIONAL, ADR-026): conversion requires an explicit
--   confirmation that the client's consent to processing is present; who
--   confirmed and when is stored on the case. Whether this is the correct legal
--   basis is a legal decision (owner) — the gate only prevents silent creation.
-- * Audit: inserts and status changes of partner_requests, cases and
--   matching_requests are written to audit_events. Allowlisted columns only:
--   no names, needs or other free text enter the audit log.
-- =============================================================================

-- 1. Consent provenance on the case ------------------------------------------------
alter table public.cases
  add column intake_consent_confirmed_at timestamptz,
  add column intake_consent_confirmed_by uuid;

-- 2. Audit coverage for the intake tables --------------------------------------------
create trigger audit_partner_requests
  after insert or update on public.partner_requests
  for each row execute function private.write_audit_event('status', 'urgency', 'region', 'converted_case_id');
create trigger audit_cases
  after insert or update on public.cases
  for each row execute function private.write_audit_event('status', 'urgency', 'region', 'assigned_team_id', 'intake_consent_confirmed_at');
create trigger audit_matching_requests
  after insert or update on public.matching_requests
  for each row execute function private.write_audit_event('status', 'urgency', 'region', 'case_id', 'selected_team_id');

-- 3. Commands -------------------------------------------------------------------------
-- SECURITY DEFINER: app users have no INSERT privilege on these tables. Every
-- check is explicit and uses the caller's auth.uid() (pattern of ADR-024).
-- Return: 'ok' | 'duplicate' | 'rejected'. 22023 = invalid input.

create function private.check_text(p_value text, p_min int, p_max int, p_label text)
returns text
language plpgsql immutable set search_path = ''
as $$
declare
  v text := btrim(p_value);
begin
  if v is null or char_length(v) not between p_min and p_max then
    raise exception '% needs %–% characters', p_label, p_min, p_max using errcode = '22023';
  end if;
  return v;
end;
$$;

revoke all on function private.check_text(text, int, int, text) from public, anon;
grant execute on function private.check_text(text, int, int, text) to authenticated;

create function public.record_partner_request(
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
  p_idempotency_key    uuid)
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
  if p_urgency is null or p_urgency not in ('niedrig', 'mittel', 'hoch') then
    raise exception 'urgency must be niedrig, mittel or hoch' using errcode = '22023';
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
    (organization_id, partner_name, partner_type, region, city, urgency, time_info,
     request_title, need_summary, requested_services, status)
  values
    (p_organization_id,
     private.check_text(p_partner_name, 2, 120, 'partner name'),
     nullif(btrim(p_partner_type), ''),
     private.check_text(p_region, 2, 80, 'region'),
     nullif(btrim(p_city), ''),
     p_urgency,
     nullif(btrim(p_time_info), ''),
     private.check_text(p_request_title, 3, 160, 'title'),
     private.check_text(p_need_summary, 3, 2000, 'need summary'),
     services,
     'open');

  return private.end_command('ok');
end;
$$;

create function public.convert_partner_request(
  p_request_id        uuid,
  p_first_name        text,
  p_last_name         text,
  p_consent_confirmed boolean,
  p_idempotency_key   uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid     uuid := (select auth.uid());
  req     public.partner_requests%rowtype;
  first_n text;
  last_n  text;
  new_case uuid;
begin
  if uid is null then
    return 'rejected';
  end if;
  if p_consent_confirmed is distinct from true then
    raise exception 'consent confirmation is required (provisional gate, ADR-026)' using errcode = '22023';
  end if;
  first_n := private.check_text(p_first_name, 1, 100, 'first name');
  last_n  := private.check_text(p_last_name, 1, 100, 'last name');

  if private.begin_command('convert_partner_request', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;

  select * into req from public.partner_requests where id = p_request_id for update;
  if not found
     or not private.has_org_role(req.organization_id, array['admin', 'operations'])
     or req.status not in ('open', 'ready_to_convert') then
    return private.end_command('rejected');
  end if;

  insert into public.cases
    (organization_id, name, first_name, last_name, region, status, urgency, time_info,
     bedarf, care_needs, next_step, intake_consent_confirmed_at, intake_consent_confirmed_by)
  values
    (req.organization_id, first_n || ' ' || last_n, first_n, last_n, req.region, 'neu', req.urgency,
     req.time_info, req.request_title, req.requested_services, 'Teamentscheid ausstehend',
     now(), uid)
  returning id into new_case;

  insert into public.matching_requests
    (organization_id, case_id, request_title, region, urgency, required_services, status)
  values
    (req.organization_id, new_case, 'Teamsuche: ' || req.request_title, req.region, req.urgency,
     coalesce(req.requested_services, '{}'), 'open');

  update public.partner_requests
  set status = 'converted', converted_case_id = new_case
  where id = req.id;

  return private.end_command('ok');
end;
$$;

revoke all on function
  public.record_partner_request(uuid, text, text, text, text, text, text, text, text, text[], uuid),
  public.convert_partner_request(uuid, text, text, boolean, uuid)
from public, anon;
grant execute on function
  public.record_partner_request(uuid, text, text, text, text, text, text, text, text, text[], uuid),
  public.convert_partner_request(uuid, text, text, boolean, uuid)
to authenticated;
