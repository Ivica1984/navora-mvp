-- ADM2 part (a): the team admits its colleagues; the employer records "Vertrag erfasst" once (PO brief
-- docs/agents/briefs/ADM2.md, ADM2-1 to ADM2-10; D-20 po-decided, `lca` 00:50 protective shape; ADR-114).
-- Part (b) (ADM2-11 to ADM2-15: the contract end ends access on time) follows in a later migration of the same PR.
--
-- Design (ADR-114):
-- * Switch (ADM2-1): `team_admission_settings`, one row per organisation, default off, set only by an administrator
--   (`set_team_admission`, audited). Off: every ADM2 command returns `admission_off`. ADM1 is not touched.
-- * Three records (ADM2-3, `lca` binding):
--     - `team_admission_proposals`: the decision record's head. team, proposer, time. Append-only. No name.
--     - `team_admission_events`: the decision record's body. consent / objection (reason code) / objection withdrawn /
--       outcome (admitted, withdrawn, lapsed, contract_recorded), who and when. Append-only. No text column at all:
--       kind and reason are enum types, so no free text can ever be stored (pgTAP).
--     - `team_candidates`: the only place with candidate data (display name, claimed qualification, Pensum band).
--       Deletable; deleted in the same transaction as the outcome (ADM2-8, D-4 addendum: 0 days). No audit row ever
--       carries the name (the audit trigger logs the proposal reference only).
-- * Consent rule (ADM2-5, organisational product rule, D-20): admitted when at least ADM2_CONSENTS (2) active members
--   other than the proposer consent (all other active members when fewer than two exist) and no objection stands. Each
--   member's current stance is her newest consent / objection / objection-withdrawn event. A proposal without outcome
--   lapses ADM2_LAPSE_DAYS (14) Zurich calendar days after it was made (DST-safe local arithmetic). Lapse is
--   evaluated by every ADM2 command and reader of the organisation (`private.adm2_sweep`, the OPS1 page-load pattern;
--   no hosted job exists, D-2).
-- * "Vertrag erfasst" (ADM2-6): `record_member_contract` by an administrator for an admitted proposal: the hand-made
--   account (D-26 default A), start date, optional end date. It creates the organisation membership with role `nurse`
--   when she has none (an existing role is never changed, ADM2-7), the team membership WITHOUT qualification, and a
--   `member_contract_events` row (dates only, ADM2 Negative). It takes no judgement field.
-- * Qualification (ADM2-6, engineering question 3): `team_memberships.qualification` becomes nullable; only ADM2
--   creates a null. The existing `set_member_qualification` (0018, patched by ABS1 0046) sets it unchanged: it reads
--   the old value (null), compares (`null = x` is not true) and updates. Until it is set she is never responsible:
--   `private.has_qualification` is added to `may_perform_visit` (take, ABS1 return), to PLAN2 generation (primary and
--   deputy), to `plan_visit` (new code `qualification_missing`) and to `cover_team_for` (cover offers and accept); a
--   BEFORE trigger on `care_visits` refuses any other path that would make her responsible or covering (backstop).
-- * Reads (ADM2-4): no direct table read for `authenticated`; two SECURITY DEFINER readers, `team_admissions(team)`
--   for the team's active members and the organisation's administrators, `admin_team_admissions(org)` for
--   administrators. No AN1, AN2, OPS1, AUD1 or export function reads these tables (pgTAP catalogue check).
-- * ADM2-7: no ADM2 command takes a role, a second team or a primary/deputy parameter (pgTAP on the signatures).
-- Idempotent commands (begin_command), audited (audit triggers + audit_command), no free text except the candidate's
-- display name (deletable).

-- 0. Patch helper (removed at the end) ------------------------------------------------------------------------------------
create or replace function private.adm2_patch(p_fn text, p_pairs text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]);
    if n <> p_pairs[i + 2]::integer then
      raise exception '0091 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0091 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.adm2_patch(text, text[], text) from public, anon, authenticated;

-- 1. Constants (ADR-114; organisational product rules of D-20, measured in the pilot) -------------------------------------
create or replace function private.adm2_consents() returns integer language sql immutable set search_path = ''
as $$ select 2 $$;
create or replace function private.adm2_lapse_days() returns integer language sql immutable set search_path = ''
as $$ select 14 $$;
create or replace function private.adm2_candidate_retention_days() returns integer language sql immutable set search_path = ''
as $$ select 0 $$;  -- D-4 addendum 04:10: 0 days; deleted in the same transaction as the outcome.
revoke all on function private.adm2_consents(), private.adm2_lapse_days(), private.adm2_candidate_retention_days()
  from public, anon, authenticated;
comment on function private.adm2_consents() is 'ADM2-5: consents needed from members other than the proposer (D-20, ADR-114).';
comment on function private.adm2_lapse_days() is 'ADM2-5: Zurich calendar days after which an open proposal lapses (ADR-114).';
comment on function private.adm2_candidate_retention_days() is
  'ADM2-8: days candidate data are kept after an outcome. 0 (D-4 addendum 2026-10-27 04:10); only 0 is implemented.';

-- 2. Switch (ADM2-1) -------------------------------------------------------------------------------------------------------
create table if not exists public.team_admission_settings (
  id              uuid not null default gen_random_uuid() unique,
  organization_id uuid primary key references public.organizations (id) on delete cascade,
  enabled         boolean not null default false,
  updated_by      uuid not null,
  updated_at      timestamptz not null default private.now()
);
comment on table public.team_admission_settings is
  'ADM2-1: per-organisation switch for team admission, default off (no row = off). Written only by set_team_admission.';
alter table public.team_admission_settings enable row level security;
revoke all on public.team_admission_settings from public, anon, authenticated;
drop trigger if exists audit_team_admission_settings on public.team_admission_settings;
create trigger audit_team_admission_settings
  after insert or update on public.team_admission_settings
  for each row execute function private.write_audit_event('enabled', 'updated_by');

create or replace function private.team_admission_on(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce((select s.enabled from public.team_admission_settings s where s.organization_id = p_org), false) $$;
revoke all on function private.team_admission_on(uuid) from public, anon, authenticated;

-- Return: 'ok' | 'unchanged' | 'duplicate' | 'rejected'
create or replace function public.set_team_admission(p_organization_id uuid, p_enabled boolean, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then return 'rejected'; end if;
  if p_enabled is null then
    raise exception 'enabled is required' using errcode = '22023';
  end if;
  if private.begin_command('set_team_admission', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then
    return private.end_command('rejected');
  end if;
  if private.team_admission_on(p_organization_id) = p_enabled then
    return private.end_command('unchanged');
  end if;
  insert into public.team_admission_settings (organization_id, enabled, updated_by, updated_at)
  values (p_organization_id, p_enabled, uid, private.now())
  on conflict (organization_id) do update set enabled = excluded.enabled, updated_by = excluded.updated_by,
                                              updated_at = excluded.updated_at;
  return private.end_command('ok');
end;
$$;
revoke all on function public.set_team_admission(uuid, boolean, uuid) from public, anon;
grant execute on function public.set_team_admission(uuid, boolean, uuid) to authenticated;
comment on function public.set_team_admission(uuid, boolean, uuid) is
  'ADM2-1: an organisation administrator switches team admission on or off (default off). Audited, idempotent.';

-- 3. The records (ADM2-2, ADM2-3) ------------------------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'team_admission_event_kind') then
    create type public.team_admission_event_kind as enum
      ('consent', 'objection', 'objection_withdrawn', 'admitted', 'withdrawn', 'lapsed', 'contract_recorded');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'team_admission_objection') then
    create type public.team_admission_objection as enum
      ('team_full', 'availability_mismatch', 'qualification_mix', 'wants_to_meet_first');
  end if;
end;
$$;
comment on type public.team_admission_objection is
  'ADM2-3: objection reason codes (the brief''s list; PO may extend). No free text.';

create table if not exists public.team_admission_proposals (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id),
  proposed_by     uuid not null references auth.users (id),
  created_at      timestamptz not null default private.now()
);
create index if not exists team_admission_proposals_team_idx on public.team_admission_proposals (team_id, created_at);
create index if not exists team_admission_proposals_org_idx on public.team_admission_proposals (organization_id, created_at);
comment on table public.team_admission_proposals is
  'ADM2-3: head of the team''s admission decision record. Append-only, carries no candidate data; its id is the '
  'candidate reference that survives the deletion of team_candidates.';

create table if not exists public.team_admission_events (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  proposal_id     uuid not null references public.team_admission_proposals (id),
  organization_id uuid not null,
  team_id         uuid not null,
  kind            public.team_admission_event_kind not null,
  reason          public.team_admission_objection,
  actor_id        uuid not null,
  created_at      timestamptz not null default private.now(),
  check ((kind = 'objection') = (reason is not null))
);
create index if not exists team_admission_events_proposal_idx on public.team_admission_events (proposal_id, seq);
comment on table public.team_admission_events is
  'ADM2-3: each member''s consent or objection (reason code) and the outcome, who and when. Append-only, no text '
  'column. actor_id is the nil UUID for a lapse (system).';

create table if not exists public.team_candidates (
  id                    uuid primary key default gen_random_uuid(),
  proposal_id           uuid not null unique references public.team_admission_proposals (id),
  organization_id       uuid not null,
  team_id               uuid not null,
  display_name          text not null check (char_length(btrim(display_name)) between 2 and 80),
  claimed_qualification text not null check (claimed_qualification in ('registered_nurse', 'care_assistant')),
  pensum_band           text not null check (pensum_band in ('20-40', '40-60', '60-80', '80-100'))
);
comment on table public.team_candidates is
  'ADM2-2/-3/-8: the only candidate data: display name, claimed qualification, Pensum band. No other field may be '
  'added (pgTAP schema test). Deleted in the same transaction as the outcome (0 days, D-4).';

do $$
declare t text;
begin
  foreach t in array array['team_admission_proposals', 'team_admission_events', 'team_candidates'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
  end loop;
end;
$$;

create or replace function private.guard_team_admission_record()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception '% is append-only', tg_table_name using errcode = '42501';
end;
$$;
revoke all on function private.guard_team_admission_record() from public, anon, authenticated;
drop trigger if exists team_admission_proposals_guard on public.team_admission_proposals;
create trigger team_admission_proposals_guard before update or delete on public.team_admission_proposals
  for each row execute function private.guard_team_admission_record();
drop trigger if exists team_admission_proposals_no_truncate on public.team_admission_proposals;
create trigger team_admission_proposals_no_truncate before truncate on public.team_admission_proposals
  for each statement execute function private.guard_team_admission_record();
drop trigger if exists team_admission_events_guard on public.team_admission_events;
create trigger team_admission_events_guard before update or delete on public.team_admission_events
  for each row execute function private.guard_team_admission_record();
drop trigger if exists team_admission_events_no_truncate on public.team_admission_events;
create trigger team_admission_events_no_truncate before truncate on public.team_admission_events
  for each statement execute function private.guard_team_admission_record();
-- Candidates: no update (the three fields are entered once); delete is the deletion of ADM2-8.
create or replace function private.guard_team_candidate_update()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'team_candidates rows are not edited; withdraw and propose again' using errcode = '42501';
end;
$$;
revoke all on function private.guard_team_candidate_update() from public, anon, authenticated;
drop trigger if exists team_candidates_no_update on public.team_candidates;
create trigger team_candidates_no_update before update on public.team_candidates
  for each row execute function private.guard_team_candidate_update();

-- Audit: proposal and events with their codes; candidates with the proposal reference only (never the name).
drop trigger if exists audit_team_admission_proposals on public.team_admission_proposals;
create trigger audit_team_admission_proposals after insert on public.team_admission_proposals
  for each row execute function private.write_audit_event('team_id', 'proposed_by');
drop trigger if exists audit_team_admission_events on public.team_admission_events;
create trigger audit_team_admission_events after insert on public.team_admission_events
  for each row execute function private.write_audit_event('proposal_id', 'kind', 'reason', 'actor_id');
drop trigger if exists audit_team_candidates on public.team_candidates;
create trigger audit_team_candidates after insert on public.team_candidates
  for each row execute function private.write_audit_event('proposal_id');

-- Deletion is audited too (who deleted which candidate reference, never the content), through the shared writer.
create or replace function private.audit_team_candidate_delete()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.audit_command(old.organization_id, 'team_candidates', old.id,
                                jsonb_build_object('proposal_id', old.proposal_id, 'deleted', true));
  return old;
end;
$$;
revoke all on function private.audit_team_candidate_delete() from public, anon, authenticated;
drop trigger if exists audit_team_candidates_delete on public.team_candidates;
create trigger audit_team_candidates_delete after delete on public.team_candidates
  for each row execute function private.audit_team_candidate_delete();

-- Contract fact (ADM2-6; part (b) adds the end-date consequences). Dates only (ADM2 Negative).
create table if not exists public.member_contract_events (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  organization_id uuid not null,
  user_id         uuid not null,
  start_date      date,
  end_date        date,
  actor_id        uuid not null,
  created_at      timestamptz not null default private.now(),
  foreign key (organization_id, user_id) references public.organization_memberships (organization_id, user_id),
  check (end_date is null or start_date is null or end_date >= start_date)
);
create index if not exists member_contract_events_user_idx on public.member_contract_events (user_id, organization_id, seq);
comment on table public.member_contract_events is
  'ADM2-6/-11: "Vertrag erfasst": contract start and optional end date per organisation membership; the newest row is '
  'current. Append-only, dates only: no field for who ended the contract or why (lca 03:50 (1)). Written only by '
  'record_member_contract (and the part (b) end-date command). Readable by the organisation''s administrators and '
  'the person herself.';
alter table public.member_contract_events enable row level security;
revoke all on public.member_contract_events from public, anon, authenticated;
grant select on public.member_contract_events to authenticated;
drop policy if exists contract_events_admin_or_self_read on public.member_contract_events;
create policy contract_events_admin_or_self_read on public.member_contract_events
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_org_admin(organization_id));
drop policy if exists leave1_access_open on public.member_contract_events;
create policy leave1_access_open on public.member_contract_events
  as restrictive for all to authenticated
  using (not (select private.access_ended((select auth.uid()))));
drop trigger if exists member_contract_events_guard on public.member_contract_events;
create trigger member_contract_events_guard before update or delete on public.member_contract_events
  for each row execute function private.guard_team_admission_record();
drop trigger if exists member_contract_events_no_truncate on public.member_contract_events;
create trigger member_contract_events_no_truncate before truncate on public.member_contract_events
  for each statement execute function private.guard_team_admission_record();
drop trigger if exists audit_member_contract_events on public.member_contract_events;
create trigger audit_member_contract_events after insert on public.member_contract_events
  for each row execute function private.write_audit_event('user_id', 'start_date', 'end_date', 'actor_id');

-- 4. Rule (ADM2-5) and lapse -----------------------------------------------------------------------------------------------
-- Active member of the team: in the team and access not ended (LEAVE1-3).
create or replace function private.adm2_active_member(p_team uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select p_user is not null
     and exists (select 1 from public.team_memberships m where m.team_id = p_team and m.user_id = p_user)
     and not private.access_ended(p_user)
$$;
revoke all on function private.adm2_active_member(uuid, uuid) from public, anon, authenticated;

create or replace function private.adm2_outcome(p_proposal uuid)
returns public.team_admission_event_kind language sql stable security definer set search_path = ''
as $$
  select e.kind from public.team_admission_events e
  where e.proposal_id = p_proposal and e.kind in ('admitted', 'withdrawn', 'lapsed', 'contract_recorded')
  order by e.seq desc limit 1
$$;
revoke all on function private.adm2_outcome(uuid) from public, anon, authenticated;

-- Current stance per member: her newest consent / objection / objection_withdrawn. Only active members of the team
-- other than the proposer count (a member who joined after the proposal takes part; one whose access ended does not).
create or replace function private.adm2_tally(p_proposal uuid)
returns table (consents integer, objections integer, needed integer, reasons public.team_admission_objection[])
language sql stable security definer set search_path = ''
as $$
  with p as (select * from public.team_admission_proposals where id = p_proposal),
  others as (
    select m.user_id from public.team_memberships m, p
    where m.team_id = p.team_id and m.user_id <> p.proposed_by and not private.access_ended(m.user_id)),
  stance as (
    select distinct on (e.actor_id) e.actor_id, e.kind, e.reason
    from public.team_admission_events e
    where e.proposal_id = p_proposal and e.kind in ('consent', 'objection', 'objection_withdrawn')
      and e.actor_id in (select user_id from others)
    order by e.actor_id, e.seq desc)
  select (select count(*) from stance where kind = 'consent')::integer,
         (select count(*) from stance where kind = 'objection')::integer,
         least(private.adm2_consents(), (select count(*) from others))::integer,
         coalesce((select array_agg(reason order by reason) from stance where kind = 'objection'), '{}')
$$;
revoke all on function private.adm2_tally(uuid) from public, anon, authenticated;

-- Appends the outcome and deletes the candidate in the same transaction (ADM2-8: 0 days).
create or replace function private.adm2_close(p_proposal uuid, p_kind public.team_admission_event_kind, p_actor uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare p public.team_admission_proposals%rowtype;
begin
  select * into p from public.team_admission_proposals where id = p_proposal;
  insert into public.team_admission_events (proposal_id, organization_id, team_id, kind, actor_id)
  values (p.id, p.organization_id, p.team_id, p_kind, p_actor);
  if p_kind in ('withdrawn', 'lapsed', 'contract_recorded') then
    delete from public.team_candidates where proposal_id = p.id;
  end if;
end;
$$;
revoke all on function private.adm2_close(uuid, public.team_admission_event_kind, uuid) from public, anon, authenticated;

-- Admits when the rule is met; returns the outcome after evaluation (null = still open).
create or replace function private.adm2_evaluate(p_proposal uuid)
returns public.team_admission_event_kind language plpgsql security definer set search_path = ''
as $$
declare t record;
begin
  if private.adm2_outcome(p_proposal) is not null then
    return private.adm2_outcome(p_proposal);
  end if;
  select * into t from private.adm2_tally(p_proposal);
  if t.objections = 0 and t.consents >= t.needed then
    perform private.adm2_close(p_proposal, 'admitted', coalesce((select auth.uid()), '00000000-0000-0000-0000-000000000000'));
    return 'admitted';
  end if;
  return null;
end;
$$;
revoke all on function private.adm2_evaluate(uuid) from public, anon, authenticated;

-- Lapse: an open proposal lapses at the same Zurich local time ADM2_LAPSE_DAYS calendar days later (DST1-safe).
create or replace function private.adm2_lapse_at(p_created timestamptz)
returns timestamptz language sql stable set search_path = ''
as $$ select private.at_zurich(private.at_zurich(p_created) + make_interval(days => private.adm2_lapse_days())) $$;
revoke all on function private.adm2_lapse_at(timestamptz) from public, anon, authenticated;

create or replace function private.adm2_sweep(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n integer := 0;
  cmd text := current_setting('navora.command', true);
  key text := current_setting('navora.idempotency_key', true);
begin
  -- The lapse is the system's act, not the caller's command: no command context on its rows.
  perform set_config('navora.command', '', true);
  perform set_config('navora.idempotency_key', '', true);
  for r in select p.id from public.team_admission_proposals p
           where p.organization_id = p_org and private.adm2_lapse_at(p.created_at) <= private.now()
             and private.adm2_outcome(p.id) is null
           for update of p loop
    perform private.adm2_close(r.id, 'lapsed', '00000000-0000-0000-0000-000000000000');
    n := n + 1;
  end loop;
  perform set_config('navora.command', coalesce(cmd, ''), true);
  perform set_config('navora.idempotency_key', coalesce(key, ''), true);
  return n;
end;
$$;
revoke all on function private.adm2_sweep(uuid) from public, anon, authenticated;

-- 5. Commands (ADM2-2, ADM2-5) ------------------------------------------------------------------------------------------
-- Return jsonb {result: 'ok'|'admission_off'|'duplicate'|'rejected', proposal_id?, outcome?}
create or replace function public.propose_team_candidate(
  p_team_id uuid, p_display_name text, p_claimed_qualification text, p_pensum_band text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  org  uuid := private.team_organization(p_team_id);
  name text;
  pid  uuid;
  res  public.team_admission_event_kind;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  name := private.check_text(p_display_name, 2, 80, 'display_name');
  if p_claimed_qualification is null or p_claimed_qualification not in ('registered_nurse', 'care_assistant') then
    raise exception 'qualification must be registered_nurse or care_assistant' using errcode = '22023';
  end if;
  if p_pensum_band is null or p_pensum_band not in ('20-40', '40-60', '60-80', '80-100') then
    raise exception 'pensum band must be 20-40, 40-60, 60-80 or 80-100' using errcode = '22023';
  end if;
  if private.begin_command('propose_team_candidate', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  if org is null or not private.team_admission_on(org) then
    perform private.end_command('admission_off');
    return jsonb_build_object('result', 'admission_off');
  end if;
  if not private.adm2_active_member(p_team_id, uid)
     or exists (select 1 from public.teams t where t.id = p_team_id and t.status = 'closed') then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  perform private.adm2_sweep(org);
  insert into public.team_admission_proposals (organization_id, team_id, proposed_by)
  values (org, p_team_id, uid) returning id into pid;
  insert into public.team_candidates (proposal_id, organization_id, team_id, display_name, claimed_qualification, pensum_band)
  values (pid, org, p_team_id, name, p_claimed_qualification, p_pensum_band);
  res := private.adm2_evaluate(pid);  -- a team with no other active member: admitted at once (ADR-114, OPEN for po)
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'proposal_id', pid, 'outcome', res);
end;
$$;
revoke all on function public.propose_team_candidate(uuid, text, text, text, uuid) from public, anon;
grant execute on function public.propose_team_candidate(uuid, text, text, text, uuid) to authenticated;
comment on function public.propose_team_candidate(uuid, text, text, text, uuid) is
  'ADM2-2: an active member of the team proposes a candidate with display name, claimed qualification and Pensum '
  'band only. Switch off: admission_off.';

-- p_decision: 'consent' | 'objection' (with p_reason) | 'withdraw_objection' | 'withdraw_proposal' (proposer only).
-- Return jsonb {result: 'ok'|'unchanged'|'admission_off'|'own_proposal'|'not_proposer'|'no_objection'|'closed'|
--               'duplicate'|'rejected', outcome?}
create or replace function public.decide_team_candidate(
  p_proposal_id uuid, p_decision text, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  p    public.team_admission_proposals%rowtype;
  why  public.team_admission_objection;
  cur  public.team_admission_event_kind;
  res  public.team_admission_event_kind;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_decision is null or p_decision not in ('consent', 'objection', 'withdraw_objection', 'withdraw_proposal') then
    raise exception 'decision must be consent, objection, withdraw_objection or withdraw_proposal' using errcode = '22023';
  end if;
  if p_decision = 'objection' then
    if p_reason is null or p_reason not in ('team_full', 'availability_mismatch', 'qualification_mix', 'wants_to_meet_first') then
      raise exception 'an objection needs a reason code' using errcode = '22023';
    end if;
    why := p_reason::public.team_admission_objection;
  elsif p_reason is not null then
    raise exception 'only an objection takes a reason code' using errcode = '22023';
  end if;
  if private.begin_command('decide_team_candidate', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into p from public.team_admission_proposals where id = p_proposal_id;
  if not found or not private.adm2_active_member(p.team_id, uid) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  if not private.team_admission_on(p.organization_id) then
    perform private.end_command('admission_off');
    return jsonb_build_object('result', 'admission_off');
  end if;
  perform 1 from public.team_admission_proposals where id = p.id for update;
  perform private.adm2_sweep(p.organization_id);
  if private.adm2_outcome(p.id) is not null then
    perform private.end_command('closed');
    return jsonb_build_object('result', 'closed', 'outcome', private.adm2_outcome(p.id));
  end if;

  if p_decision = 'withdraw_proposal' then
    if p.proposed_by <> uid then
      perform private.end_command('not_proposer');
      return jsonb_build_object('result', 'not_proposer');
    end if;
    perform private.adm2_close(p.id, 'withdrawn', uid);
    perform private.end_command('ok');
    return jsonb_build_object('result', 'ok', 'outcome', 'withdrawn');
  end if;
  if p.proposed_by = uid then
    perform private.end_command('own_proposal');
    return jsonb_build_object('result', 'own_proposal');
  end if;

  select e.kind into cur from public.team_admission_events e
  where e.proposal_id = p.id and e.actor_id = uid and e.kind in ('consent', 'objection', 'objection_withdrawn')
  order by e.seq desc limit 1;
  if p_decision = 'withdraw_objection' and cur is distinct from 'objection' then
    perform private.end_command('no_objection');
    return jsonb_build_object('result', 'no_objection');
  end if;
  if p_decision = 'consent' and cur = 'consent' then
    perform private.end_command('unchanged');
    return jsonb_build_object('result', 'unchanged');
  end if;
  if p_decision = 'objection' and cur = 'objection'
     and (select e.reason from public.team_admission_events e where e.proposal_id = p.id and e.actor_id = uid
          order by e.seq desc limit 1) = why then
    perform private.end_command('unchanged');
    return jsonb_build_object('result', 'unchanged');
  end if;

  insert into public.team_admission_events (proposal_id, organization_id, team_id, kind, reason, actor_id)
  values (p.id, p.organization_id, p.team_id,
          (case p_decision when 'withdraw_objection' then 'objection_withdrawn' else p_decision end)::public.team_admission_event_kind,
          why, uid);
  res := private.adm2_evaluate(p.id);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'outcome', res);
end;
$$;
revoke all on function public.decide_team_candidate(uuid, text, text, uuid) from public, anon;
grant execute on function public.decide_team_candidate(uuid, text, text, uuid) to authenticated;
comment on function public.decide_team_candidate(uuid, text, text, uuid) is
  'ADM2-5: an active member other than the proposer consents, objects with a reason code or withdraws her '
  'objection; the proposer may withdraw her proposal. Admitted when ADM2_CONSENTS members consent and no objection '
  'stands; lapses after ADM2_LAPSE_DAYS Zurich days.';

-- 6. "Vertrag erfasst" (ADM2-6) ------------------------------------------------------------------------------------------
-- The administrator names the hand-made account by its e-mail (no list of accounts outside the organisation is shown).
-- Return jsonb {result: 'ok'|'admission_off'|'not_admitted'|'unknown_user'|'already_member'|'access_ended'|
--               'duplicate'|'rejected'}
create or replace function public.record_member_contract(
  p_proposal_id uuid, p_email text, p_start_date date, p_end_date date, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  p    public.team_admission_proposals%rowtype;
  c    public.team_candidates%rowtype;
  p_user_id uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_email is null or btrim(p_email) !~ '^[^@\s]+@[^@\s]+$' or p_start_date is null then
    raise exception 'account e-mail and start date are required' using errcode = '22023';
  end if;
  if p_end_date is not null and p_end_date < p_start_date then
    raise exception 'the end date is before the start date' using errcode = '22023';
  end if;
  if private.begin_command('record_member_contract', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into p from public.team_admission_proposals where id = p_proposal_id;
  if not found or not private.is_org_admin(p.organization_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  if not private.team_admission_on(p.organization_id) then
    perform private.end_command('admission_off');
    return jsonb_build_object('result', 'admission_off');
  end if;
  perform 1 from public.team_admission_proposals where id = p.id for update;
  perform private.adm2_sweep(p.organization_id);
  if private.adm2_outcome(p.id) is distinct from 'admitted' then
    perform private.end_command('not_admitted');
    return jsonb_build_object('result', 'not_admitted');
  end if;
  -- The account was made by hand (D-26 default A); the administrator names it by its e-mail.
  select u.id into p_user_id from auth.users u where lower(u.email) = lower(btrim(p_email)) and u.deleted_at is null;
  if p_user_id is null then
    perform private.end_command('unknown_user');
    return jsonb_build_object('result', 'unknown_user');
  end if;
  if private.access_ended(p_user_id) then
    perform private.end_command('access_ended');
    return jsonb_build_object('result', 'access_ended');
  end if;
  if exists (select 1 from public.team_memberships m where m.team_id = p.team_id and m.user_id = p_user_id) then
    perform private.end_command('already_member');
    return jsonb_build_object('result', 'already_member');
  end if;
  select * into c from public.team_candidates where proposal_id = p.id;

  -- Organisation membership: role nurse when she has none; an existing role is never changed (ADM2-7).
  insert into public.organization_memberships (organization_id, user_id, role)
  values (p.organization_id, p_user_id, 'nurse')
  on conflict (organization_id, user_id) do nothing;
  -- Team membership without qualification: only the administrator path sets it (ADM2-6, D-29).
  insert into public.team_memberships (team_id, user_id, qualification) values (p.team_id, p_user_id, null);
  -- Her display name from the candidate record, unless she already has one (ADM1 profile; a member's name, no health data).
  if c.display_name is not null then
    insert into public.member_profiles (organization_id, user_id, display_name, updated_by)
    values (p.organization_id, p_user_id, c.display_name, uid)
    on conflict (organization_id, user_id) do nothing;
  end if;
  insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id)
  values (p.organization_id, p_user_id, p_start_date, p_end_date, uid);
  perform private.audit_command(p.organization_id, 'team_memberships', p.team_id,
          jsonb_build_object('user_id', p_user_id, 'added', true, 'via', 'team_admission', 'proposal_id', p.id));
  perform private.adm2_close(p.id, 'contract_recorded', uid);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok');
end;
$$;
revoke all on function public.record_member_contract(uuid, text, date, date, uuid) from public, anon;
grant execute on function public.record_member_contract(uuid, text, date, date, uuid) to authenticated;
comment on function public.record_member_contract(uuid, text, date, date, uuid) is
  'ADM2-6: "Vertrag erfasst". An administrator records the contract fact for an admitted proposal: the hand-made '
  'account (by its e-mail), start date, optional end date. Creates the team membership without qualification; never a role change. '
  'No judgement field. Deletes the candidate record in the same transaction (ADM2-8).';

-- 7. Readers (ADM2-4, ADM2-9, ADM2-10) --------------------------------------------------------------------------------------
-- The team's view: switch, and its open and admitted proposals (contract not yet recorded). Active members of the team
-- and the organisation's administrators; everyone else gets null. Evaluates lapses first (volatile).
create or replace function public.team_admissions(p_team_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid := private.team_organization(p_team_id);
begin
  if uid is null or org is null or private.access_ended(uid)  -- LEAVE1-3
     or not (private.adm2_active_member(p_team_id, uid) or private.is_org_admin(org)) then
    return null;
  end if;
  perform private.adm2_sweep(org);
  return jsonb_build_object(
    'enabled', private.team_admission_on(org),
    'consents_needed', private.adm2_consents(),
    'lapse_days', private.adm2_lapse_days(),
    'proposals', coalesce((
      select jsonb_agg(jsonb_build_object(
               'proposal_id', p.id,
               'created_at', p.created_at,
               'lapses_at', private.adm2_lapse_at(p.created_at),
               'proposed_by_me', p.proposed_by = uid,
               'proposer_name', private.member_name(org, p.proposed_by),
               'display_name', c.display_name,
               'claimed_qualification', c.claimed_qualification,
               'pensum_band', c.pensum_band,
               'outcome', private.adm2_outcome(p.id),
               'consents', t.consents,
               'needed', t.needed,
               'objections', t.objections,
               'objection_reasons', to_jsonb(t.reasons),
               'my_stance', (select e.kind from public.team_admission_events e
                             where e.proposal_id = p.id and e.actor_id = uid
                               and e.kind in ('consent', 'objection', 'objection_withdrawn')
                             order by e.seq desc limit 1),
               'my_reason', (select e.reason from public.team_admission_events e
                             where e.proposal_id = p.id and e.actor_id = uid
                               and e.kind in ('consent', 'objection', 'objection_withdrawn')
                             order by e.seq desc limit 1))
             order by p.created_at)
      from public.team_admission_proposals p
      join public.team_candidates c on c.proposal_id = p.id
      cross join lateral private.adm2_tally(p.id) t
      where p.team_id = p_team_id
        and coalesce(private.adm2_outcome(p.id)::text, 'open') in ('open', 'admitted')), '[]'::jsonb));
end;
$$;
revoke all on function public.team_admissions(uuid) from public, anon;
grant execute on function public.team_admissions(uuid) to authenticated;
comment on function public.team_admissions(uuid) is
  'ADM2-4/-10: the team''s open and admitted proposals with consent count, objection codes and the reader''s own '
  'stance. Only active members of the team and the organisation''s administrators; null for everyone else.';

-- The administrator's view: the switch, every admission of the organisation with team, outcome and date (ADM2-9;
-- candidate fields only while the candidate record exists, i.e. for open and admitted proposals).
create or replace function public.admin_team_admissions(p_organization_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare uid uuid := (select auth.uid());
begin
  if uid is null or private.access_ended(uid) /* LEAVE1-3 */ or not private.is_org_admin(p_organization_id) then
    return null;
  end if;
  perform private.adm2_sweep(p_organization_id);
  return jsonb_build_object(
    'enabled', private.team_admission_on(p_organization_id),
    'proposals', coalesce((
      select jsonb_agg(jsonb_build_object(
               'proposal_id', p.id,
               'team_id', p.team_id,
               'team', t.name,
               'created_at', p.created_at,
               'outcome', coalesce(private.adm2_outcome(p.id)::text, 'open'),
               'outcome_at', (select e.created_at from public.team_admission_events e
                              where e.proposal_id = p.id and e.kind in ('admitted', 'withdrawn', 'lapsed', 'contract_recorded')
                              order by e.seq desc limit 1),
               'display_name', c.display_name,
               'claimed_qualification', c.claimed_qualification,
               'pensum_band', c.pensum_band)
             order by p.created_at desc)
      from public.team_admission_proposals p
      join public.teams t on t.id = p.team_id
      left join public.team_candidates c on c.proposal_id = p.id
      where p.organization_id = p_organization_id), '[]'::jsonb));
end;
$$;
revoke all on function public.admin_team_admissions(uuid) from public, anon;
grant execute on function public.admin_team_admissions(uuid) to authenticated;
comment on function public.admin_team_admissions(uuid) is
  'ADM2-9: every admission of the organisation with team, outcome and date, for administrators only. Candidate '
  'fields only while the candidate record exists.';

-- 8. No qualification, no responsibility (ADM2-6) ----------------------------------------------------------------------------
alter table public.team_memberships alter column qualification drop not null;
comment on column public.team_memberships.qualification is
  'D-5: registered_nurse | care_assistant. Null only for a member admitted by her team (ADM2) until an administrator '
  'sets it with set_member_qualification; until then she is never responsible or covering (private.has_qualification).';

create or replace function private.has_qualification(p_team uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.team_memberships m
                     where m.team_id = p_team and m.user_id = p_user and m.qualification is not null) $$;
revoke all on function private.has_qualification(uuid, uuid) from public, anon, authenticated;

create or replace function private.may_perform_visit(p_team uuid, p_user uuid, p_minutes_b integer, p_needs_assessment boolean)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.user_in_team(p_team, p_user)
     and not private.access_ended(p_user)  -- LEAVE1-14 (ADR-091)
     and private.has_qualification(p_team, p_user)  -- ADM2-6 (ADR-114)
     and (not (coalesce(p_minutes_b, 0) > 0 or coalesce(p_needs_assessment, false))
          or private.is_registered_nurse(p_team, p_user))
$$;
revoke all on function private.may_perform_visit(uuid, uuid, integer, boolean) from public, anon, authenticated;
comment on function private.may_perform_visit(uuid, uuid, integer, boolean) is
  'J3 qualification rule (CR-007) for a person in the team, with LEAVE1-14 (ADR-091): never a person whose access has '
  'ended (ABS1 returns no visit to her); ADM2-6 (ADR-114): never a member without a qualification.';

select private.adm2_patch('private.generate_case_plan(uuid, uuid)', array[
  E'and not private.access_ended(c.primary_nurse_id) /* LEAVE1-14 */',
  E'and not private.access_ended(c.primary_nurse_id) /* LEAVE1-14 */\n'
  || E'             and private.has_qualification(c.assigned_team_id, c.primary_nurse_id) /* ADM2-6 */',
  '1',
  E'and not private.access_ended(c.deputy_nurse_id) /* LEAVE1-14 */',
  E'and not private.access_ended(c.deputy_nurse_id) /* LEAVE1-14 */\n'
  || E'             and private.has_qualification(c.assigned_team_id, c.deputy_nurse_id) /* ADM2-6 */',
  '1'], 'ADM2-6');

select private.adm2_patch(
  'public.plan_visit(uuid, date, time without time zone, time without time zone, integer, integer, integer, boolean, uuid, uuid)',
  array[
    E'    -- ABS1-C4: never to a member absent',
    E'    -- ADM2-6: never to a member without a qualification (ADR-114).\n'
    || E'    if not private.has_qualification(c.assigned_team_id, p_responsible_user_id) then\n'
    || E'      perform private.end_command(''rejected'');\n'
    || E'      return jsonb_build_object(''result'', ''rejected'', ''reason'', ''qualification_missing'');\n'
    || E'    end if;\n'
    || E'    -- ABS1-C4: never to a member absent',
    '1'], 'ADM2-6');

select private.adm2_patch('private.cover_team_for(public.care_visits, uuid)', array[
  E'/* LEAVE1-3 */ and mine.organization_id',
  E'/* LEAVE1-3 */ and m.qualification is not null /* ADM2-6 */ and mine.organization_id',
  '1'], 'ADM2-6');

-- Backstop: no path makes a member without a qualification responsible for, or covering, a visit.
create or replace function private.adm2_guard_responsible()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.responsible_user_id is not null
     and (tg_op = 'INSERT' or new.responsible_user_id is distinct from old.responsible_user_id)
     and exists (select 1 from public.team_memberships m
                 where m.team_id = new.team_id and m.user_id = new.responsible_user_id and m.qualification is null) then
    raise exception 'qualification_missing' using errcode = '42501',
      detail = 'ADM2-6: a member without a qualification is not responsible for a visit.';
  end if;
  if new.covered_by is not null
     and (tg_op = 'INSERT' or new.covered_by is distinct from old.covered_by)
     and exists (select 1 from public.team_memberships m
                 where m.team_id = new.cover_team_id and m.user_id = new.covered_by and m.qualification is null) then
    raise exception 'qualification_missing' using errcode = '42501',
      detail = 'ADM2-6: a member without a qualification does not cover a visit.';
  end if;
  return new;
end;
$$;
revoke all on function private.adm2_guard_responsible() from public, anon, authenticated;
drop trigger if exists care_visits_adm2_qualification on public.care_visits;
create trigger care_visits_adm2_qualification
  before insert or update of responsible_user_id, covered_by on public.care_visits
  for each row execute function private.adm2_guard_responsible();

-- 9. AUD1-1 value catalogue: every audited key of ADM2 is a code (ids, dates, booleans, enum values; the candidate's
-- name is never audited) -------------------------------------------------------------------------------------------------
insert into private.audit_value_classes (table_name, key, class) values
  ('team_admission_settings',  'enabled',     'code'),
  ('team_admission_settings',  'updated_by',  'code'),
  ('team_admission_proposals', 'team_id',     'code'),
  ('team_admission_proposals', 'proposed_by', 'code'),
  ('team_admission_events',    'proposal_id', 'code'),
  ('team_admission_events',    'kind',        'code'),
  ('team_admission_events',    'reason',      'code'),
  ('team_admission_events',    'actor_id',    'code'),
  ('team_candidates',          'proposal_id', 'code'),
  ('team_candidates',          'deleted',     'code'),
  ('member_contract_events',   'user_id',     'code'),
  ('member_contract_events',   'start_date',  'code'),
  ('member_contract_events',   'end_date',    'code'),
  ('member_contract_events',   'actor_id',    'code'),
  ('team_memberships',         'via',         'code'),
  ('team_memberships',         'proposal_id', 'code')
on conflict (table_name, key) do nothing;

drop function private.adm2_patch(text, text[], text);
