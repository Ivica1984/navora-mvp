-- =============================================================================
-- F0 step 1 — Team-scoped clinical read on the legacy care tables
-- Brief docs/agents/briefs/F0.md, criteria 3c/3d; report docs/agents/reports/F0.md.
-- Closes SR-22 for the legacy tables (T9 placeholder "any org member reads all").
-- Applies D-3 option B, which the approved F0 brief makes a product requirement:
--   * nurses (and any member without a coordination role) read cases, visits,
--     visit reports and quality events ONLY of their own teams;
--   * coordination roles (admin, coach, operations) keep organisation-wide read
--     of these rows, for Operations and intake — but health fields are not
--     readable through the table API by ANYONE (column grants, below);
--   * referrals, matching requests and candidates: coordination roles only.
--     Teams see offers through public.team_offers() (no client identity).
-- Read models that teams use (field_visits, field_notes, team_cases,
-- team_offers, case_funding_facts) keep working: they read only granted
-- columns or are SECURITY DEFINER with explicit membership checks.
-- Role names remain placeholders (D-3/Q4).
-- =============================================================================

create function private.is_coordinator(org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$ select private.has_org_role(org, array['admin', 'coach', 'operations']) $$;

revoke all on function private.is_coordinator(uuid) from public, anon;
grant execute on function private.is_coordinator(uuid) to authenticated;

-- 1. Row scope ----------------------------------------------------------------------
drop policy org_members_read on public.cases;
create policy scoped_read on public.cases
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_coordinator(organization_id) or private.is_team_member(assigned_team_id)));

drop policy org_members_read on public.care_visits;
create policy scoped_read on public.care_visits
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_coordinator(organization_id) or private.is_team_member(team_id)));

drop policy org_members_read on public.care_notes;
create policy scoped_read on public.care_notes
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_coordinator(organization_id) or private.is_team_member(team_id)));

drop policy org_members_read on public.quality_events;
create policy scoped_read on public.quality_events
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_coordinator(organization_id) or private.is_team_member(team_id)));

drop policy org_members_read on public.partner_requests;
create policy coordinators_read on public.partner_requests
  for select to authenticated using (private.is_coordinator(organization_id));

drop policy org_members_read on public.matching_requests;
create policy coordinators_read on public.matching_requests
  for select to authenticated using (private.is_coordinator(organization_id));

drop policy org_members_read on public.match_candidates;
create policy coordinators_read on public.match_candidates
  for select to authenticated using (private.is_coordinator(organization_id));

-- 2. Health fields: not readable through the table API --------------------------------
-- Name, region, needs and the address remain readable (needed to find the
-- client; the row scope above limits who). These columns are not used by any
-- screen today; a team-only read model follows when one needs them.
revoke select (date_of_birth, gender, phone, emergency_contact_name, emergency_contact_phone,
               mobility_status, cognitive_status, diagnosis_tags, care_level, insurance_provider, notes)
  on public.cases from authenticated;

-- Visit-report content: the Operations view needs only the status (CARE_NOTE_STATUS_COLUMNS).
do $$
declare
  cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
  from information_schema.columns
  where table_schema = 'public' and table_name = 'care_notes' and column_name <> 'content';
  execute 'revoke select on public.care_notes from authenticated';
  execute format('grant select (%s) on public.care_notes to authenticated', cols);
end
$$;
