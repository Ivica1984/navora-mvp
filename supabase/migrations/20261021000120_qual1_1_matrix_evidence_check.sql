-- QUAL1 part 1 (brief docs/agents/briefs/QUAL1.md, approved po 2026-11-06 22:30 for synthetic data only; issue #931;
-- ADR-163). Matrix: docs/agents/clinical/QUALIFICATION_MATRIX.md v0.2, every cell PROPOSED (CR-174 to CR-184).
-- Passing anything here is NOT a clinical release (CGR-145, CGR-146, FE-039). Remediation plan: clinical/remediation/CGR-145.md.
--
-- This slice is the data and the ONE decision function. It wires the function into NO assignment path yet: the paths
-- (PLAN3 proposal/confirm, hand assignment, take, swap, cover, ABS1, start) are touched by the open PLAN3 consolidation
-- PR #934, and the brief allows the database part earlier only if it touches no file of an open stack PR. Part 2 wires
-- `private.qual_may_perform` into every path (QUAL1-10, QUAL1-17) after #934 is merged.
--
-- What it adds (IMPLEMENTED in this migration):
--   1. `organizations.simulation` (QUAL1-1, CGR-145 (e)): the matrix rule is active only in an organisation marked as a
--      simulation. No grant: set only by a migration or a test fixture. Every other organisation keeps CR-007/CR-164
--      through `private.may_perform_visit`, unchanged.
--   2. The matrix as versioned data (QUAL1-7): `qual_activities` (A1-A4, B1-B13, C1-C3, N1, plus B3H "high-risk
--      medication" and B4I "insulin", which v0.2 splits out of B3/B4 as "?" for FaGe, K-2), `qual_matrix_versions`
--      ('QAM-0.2', PROPOSED) and `qual_matrix_cells` (version, activity, grade, E/D/-/?, status, conditions). Rows are
--      immutable; a change is a new version.
--   3. Evidence (QUAL1-2, -3, -4, -5; CR-181): `member_qualification_evidence`, append-only. A member's own
--      confirmation writes `self_confirmed` (public.confirm_my_qualification). `verified` is refused for every app user,
--      every command and outside a simulation organisation: in Phase A only a synthetic fixture writes it, labelled
--      synthetic (D-29 decides real verification). Derived states: missing, self_confirmed, verified, expired (from the
--      instant `valid_until` is reached), contradictory (two grade records disagree; nothing is resolved automatically).
--   4. Delegation (QUAL1-9; CR-176, CR-176a): `qual_delegations` and `qual_delegation_revocations`, append-only, audited.
--      `public.record_delegation` only by an active member of the team whose grade `nurse_hf_fh` and practice licence are
--      verified, for a delegate of the same team and a case of that team, for a cell that is D for the delegate's
--      verified grade; a fixed end date. `public.revoke_delegation` by the delegating or supervising nurse or the case's
--      primary nurse. No agent: both tables are AIG1 prohibited targets (class 'qualification').
--   5. Activities on the visit (QUAL1-6): `visit_activities`; without a row, a needs assessment counts as A1 and KLV-B
--      minutes as B13 (no existing visit row is changed).
--   6. `private.qual_check(visit, user)` (QUAL1-8): one row per activity with result allowed_own, allowed_delegated,
--      not_allowed, unresolved, evidence_missing, evidence_expired, evidence_contradictory, delegation_missing,
--      delegation_expired or delegation_review_needed; the CR-183 label (geeignet, geeignet_mit_delegation,
--      nicht_geeignet, ungeklaert), the reason, the matrix version and the cell status. "?" is never allowed.
--      `private.qual_may_perform(visit, user)`: in a simulation organisation every activity must be allowed_own or
--      allowed_delegated; elsewhere `private.may_perform_visit` (CR-007/CR-164) decides, unchanged. No override parameter.
--      `public.visit_qualification_check(visit, user)`: the rows for members of the visit's team and coordinators.
--
-- Strict defaults chosen here (PROPOSED, for `cra`; ADR-163): (a) a cell with an open question (K-2, K-3) is "?", also
-- HF/FH B8 ("specialist training ?"); (b) HF/FH A1-A4 and every delegator and supervisor need a verified practice
-- licence (matrix §4.3 "where the canton requires one"; canton not modelled yet, so always); (c) trained-other C1 needs a
-- recorded instruction (matrix §4.2 "with selection, instruction and supervision"); (d) replaced by CGR-149: KLV-A
-- minutes count as A1, KLV-C minutes and a visit without activity or minutes as C1; "no activity" is never allowed.
-- CGR-150: a delegation needs instruction <= start <= ..., no start in the past, and counts only if instructed by the
-- visit's day and recorded before the visit starts; a visit without an end time is checked at the day's end.
-- CGR-152: visit_qualification_check returns the reason only to the member herself and administrators. NOT checked in this slice (PLANNED, QUAL1 part 2/3): the medical order for Bst. b rows,
-- context modifiers NH-EXT / HOSP-IN (CR-180, QUAL1-18), the Einsatzvereinbarung, visit-start re-check (QUAL1-17).
-- No clinical, tariff or legal rule is invented: every cell is copied from matrix v0.2 §4.2 and stays PROPOSED.
-- Idempotent: `if not exists`, `create or replace`, `drop … if exists`, `on conflict do nothing`.

-- 1. Simulation flag ---------------------------------------------------------------------------------------------------------
alter table public.organizations add column if not exists simulation boolean not null default false;
comment on column public.organizations.simulation is
  'QUAL1-1 / CGR-145 (e) / ADR-163: true only for a synthetic simulation organisation. The qualification matrix rule '
  '(PROPOSED) is active only here; every other organisation keeps CR-007/CR-164. Set by a migration or a test fixture '
  'only (no grant).';

-- 2. The matrix as data ------------------------------------------------------------------------------------------------------
create table if not exists public.qual_activities (
  code       text primary key check (code ~ '^[ABCN][0-9]{1,2}[A-Z]?$'),
  label_de   text not null,
  klv        text,          -- 'a', 'b', 'c' or null (not KLV / unresolved)
  parent     text references public.qual_activities (code),
  sort       integer not null
);
comment on table public.qual_activities is
  'QUAL1-6/-7: matrix v0.2 §4.2 activity rows. B3H and B4I are the high-risk-medication and insulin parts v0.2 splits '
  'out of B3 and B4 (FaGe "?", K-2). Reference data, no client data.';

create table if not exists public.qual_matrix_versions (
  version    text primary key,
  status     text not null check (status in ('PROPOSED', 'APPROVED')),
  source     text not null,
  created_at timestamptz not null default private.now()
);

create table if not exists public.qual_matrix_cells (
  version       text not null references public.qual_matrix_versions (version),
  activity_code text not null references public.qual_activities (code),
  grade         text not null check (grade in ('nurse_hf_fh', 'fage_efz', 'ags_eba', 'pflegehelfer_srk', 'trained_other')),
  value         text not null check (value in ('E', 'D', '-', '?')),
  status        text not null check (status in ('PROPOSED', 'APPROVED')),
  requires      text[] not null default '{}'
                check (requires <@ array['practice_licence', 'experience_2y', 'experience_psych_2y', 'instruction_record']),
  open_question text,       -- K-n / L-n when the cell or one of its conditions is unresolved
  source        text not null,
  primary key (version, activity_code, grade)
);
comment on table public.qual_matrix_cells is
  'QUAL1-7 / CR-179: one row per (matrix version, activity, grade): E (own scope), D (only with a valid delegation), '
  '- (not to be planned), ? (unresolved, treated as - everywhere). Every Phase A row is PROPOSED. Immutable: a change is '
  'a new version.';

create or replace function private.qual_reference_immutable()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception '% is versioned reference data: add a new matrix version instead (QUAL1-7)', tg_table_name
    using errcode = '42501';
end;
$$;
revoke all on function private.qual_reference_immutable() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['qual_activities', 'qual_matrix_versions', 'qual_matrix_cells'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('drop policy if exists qual_reference_read on public.%I', t);
    execute format('create policy qual_reference_read on public.%I for select to authenticated using (true)', t);
    execute format('drop policy if exists leave1_access_open on public.%I', t);
    execute format('create policy leave1_access_open on public.%I as restrictive for all to authenticated '
                   'using (not (select private.access_ended((select auth.uid()))))', t);  -- LEAVE1-3
    execute format('drop trigger if exists %I on public.%I', t || '_immutable', t);
    execute format('create trigger %I before update or delete on public.%I for each row '
                   'execute function private.qual_reference_immutable()', t || '_immutable', t);
    execute format('drop trigger if exists %I on public.%I', t || '_no_truncate', t);
    execute format('create trigger %I before truncate on public.%I for each statement '
                   'execute function private.qual_reference_immutable()', t || '_no_truncate', t);
  end loop;
end;
$$;

insert into public.qual_activities (code, label_de, klv, parent, sort) values
  ('A1', 'Bedarfsabklärung und Massnahmenplanung', 'a', null, 10),
  ('A2', 'Beratung von Klientin und Angehörigen', 'a', null, 20),
  ('A3', 'Koordination in komplexen, instabilen Situationen', 'a', null, 30),
  ('A4', 'Psychiatrische Bedarfsabklärung', 'a', null, 40),
  ('B1', 'Vitalzeichen, Gewicht', 'b', null, 110),
  ('B2', 'Venöse und kapillare Blutentnahme', 'b', null, 120),
  ('B3', 'Medikamente richten und verabreichen', 'b', null, 130),
  ('B3H', 'Hochrisiko-Medikamente richten und verabreichen', 'b', 'B3', 131),
  ('B4', 'Subkutane und intramuskuläre Injektionen', 'b', null, 140),
  ('B4I', 'Insulin-Injektion', 'b', 'B4', 141),
  ('B5', 'Infusion ohne Zusätze an bestehendem peripherem Zugang', 'b', null, 150),
  ('B6', 'Sondenernährung an bestehendem Zugang', 'b', null, 160),
  ('B7', 'Verbandwechsel, primäre und sekundäre Wundheilung', 'b', null, 170),
  ('B8', 'Komplexe Wundversorgung', 'b', null, 180),
  ('B9', 'Blasenkatheter legen und entfernen', 'b', null, 190),
  ('B10', 'Atemunterstützung, Sauerstoff, Inhalation', 'b', null, 200),
  ('B11', 'Medizinische Kompressions- oder Antithrombosestrümpfe anziehen', null, null, 210),
  ('B12', 'Kompressionsverbände', 'b', null, 220),
  ('B13', 'Andere Leistung nach Bst. b', 'b', null, 230),
  ('C1', 'Grundpflege', 'c', null, 310),
  ('C2', 'Alltagsunterstützung bei psychischer Erkrankung', 'c', null, 320),
  ('C3', 'Notfall erkennen und Hilfe holen', null, null, 330),
  ('N1', 'Unterstützung ausserhalb KLV', null, null, 410)
on conflict (code) do nothing;

insert into public.qual_matrix_versions (version, status, source)
values ('QAM-0.2', 'PROPOSED', 'docs/agents/clinical/QUALIFICATION_MATRIX.md v0.2 §4.2 (cra 2026-11-06 22:35)')
on conflict (version) do nothing;

-- Grades in column order: nurse_hf_fh, fage_efz, ags_eba, pflegehelfer_srk, trained_other. Copied from v0.2 §4.2.
with rows (code, v_hf, v_fage, v_ags, v_ph, v_other, req_hf, req_other, oq_hf, oq_fage) as (values
  ('A1',  'E', '-', '-', '-', '-', array['practice_licence'], '{}'::text[], null, null),
  ('A2',  'E', '?', '-', '-', '-', array['practice_licence'], '{}', null, null),
  ('A3',  'E', '-', '-', '-', '-', array['practice_licence', 'experience_2y'], '{}', null, null),
  ('A4',  'E', '-', '-', '-', '-', array['practice_licence', 'experience_psych_2y'], '{}', null, null),
  ('B1',  'E', 'D', 'D', '?', '-', '{}', '{}', null, null),
  ('B2',  'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B3',  'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B3H', 'E', '?', '-', '-', '-', '{}', '{}', null, 'K-2'),
  ('B4',  'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B4I', 'E', '?', '-', '-', '-', '{}', '{}', null, 'K-2'),
  ('B5',  'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B6',  'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B7',  'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B8',  'E', '?', '-', '-', '-', '{}', '{}', 'K-3', 'K-3'),
  ('B9',  'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B10', 'E', 'D', '-', '-', '-', '{}', '{}', null, null),
  ('B11', 'E', '?', 'D', '?', '?', '{}', '{}', null, 'L-1'),
  ('B12', 'E', '?', '-', '-', '-', '{}', '{}', null, null),
  ('B13', 'E', '?', '-', '-', '-', '{}', '{}', null, null),
  ('C1',  'E', 'E', 'E', 'E', 'E', '{}', array['instruction_record'], null, null),
  ('C2',  'E', '?', '?', '?', '-', '{}', '{}', null, null),
  ('C3',  'E', 'E', 'E', 'E', 'E', '{}', '{}', null, null),
  ('N1',  'E', 'E', 'E', 'E', 'E', '{}', '{}', null, null)
)
insert into public.qual_matrix_cells (version, activity_code, grade, value, status, requires, open_question, source)
select 'QAM-0.2', r.code, g.grade, g.value, 'PROPOSED', g.req, g.oq, 'QAM v0.2 §4.2 row ' || r.code
from rows r
cross join lateral (values
  ('nurse_hf_fh', r.v_hf, r.req_hf::text[], r.oq_hf),
  ('fage_efz', r.v_fage, '{}'::text[], r.oq_fage),
  ('ags_eba', r.v_ags, '{}'::text[], null),
  ('pflegehelfer_srk', r.v_ph, '{}'::text[], null),
  ('trained_other', r.v_other, r.req_other::text[], null)
) g (grade, value, req, oq)
on conflict (version, activity_code, grade) do nothing;

create or replace function private.qual_matrix_version()
returns text language sql stable security definer set search_path = ''
as $$ select v.version from public.qual_matrix_versions v order by v.created_at desc, v.version desc limit 1 $$;
revoke all on function private.qual_matrix_version() from public, anon, authenticated;

-- 3. Evidence ----------------------------------------------------------------------------------------------------------------
create table if not exists public.member_qualification_evidence (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  organization_id uuid not null,
  user_id         uuid not null,
  requirement     text not null check (requirement in ('grade', 'practice_licence', 'experience_2y',
                                                       'experience_psych_2y', 'instruction_record')),
  grade           text check (grade in ('nurse_hf_fh', 'fage_efz', 'ags_eba', 'pflegehelfer_srk', 'trained_other')),
  state           text not null check (state in ('self_confirmed', 'verified')),
  synthetic       boolean not null default true,
  valid_until     timestamptz,
  recorded_by     uuid,     -- the member for self_confirmed; null for a fixture row
  created_at      timestamptz not null default private.now(),
  foreign key (organization_id, user_id) references public.organization_memberships (organization_id, user_id),
  check ((requirement = 'grade') = (grade is not null)),
  check (state <> 'verified' or synthetic)
);
create index if not exists member_qualification_evidence_user_idx
  on public.member_qualification_evidence (organization_id, user_id, requirement, seq);
comment on table public.member_qualification_evidence is
  'QUAL1-2/-3 / CR-181 / ADR-163: one record per statement about a member''s grade, practice licence, experience or '
  'instruction. Append-only. self_confirmed = the member says so (never counts); verified = checked (Phase A: synthetic '
  'fixture only, D-29). Derived by private.qual_evidence_state: missing, expired, contradictory. No document, no register '
  'entry, no health datum of the member.';

create or replace function private.qual_guard_evidence()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'member_qualification_evidence is append-only (QUAL1-2)' using errcode = '42501';
  end if;
  if new.state = 'verified' then
    -- FE-039/FE-040, QUAL1-3: no member confirmation, no command and no agent ever sets "verified".
    if (select auth.uid()) is not null
       or nullif(current_setting('navora.command', true), '') is not null
       or current_user in ('authenticated', 'anon', 'service_role') then
      raise exception 'no app user, command or agent may record verified evidence (QUAL1-3, D-29)' using errcode = '42501';
    end if;
    if not coalesce((select o.simulation from public.organizations o where o.id = new.organization_id), false) then
      raise exception 'verified evidence exists only as a synthetic fixture in a simulation organisation (Phase A, D-29)'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.qual_guard_evidence() from public, anon, authenticated;

-- One state per (organisation, member, requirement) at an instant (CR-181; QUAL1-4, QUAL1-5).
create or replace function private.qual_evidence_state(p_org uuid, p_user uuid, p_requirement text, p_at timestamptz)
returns table (state text, grade text, valid_until timestamptz)
language sql stable security definer set search_path = ''
as $$
  with e as (
    select * from public.member_qualification_evidence x
    where x.organization_id = p_org and x.user_id = p_user and x.requirement = p_requirement
  ), live as (
    select * from e where e.state = 'verified' and (e.valid_until is null or e.valid_until > p_at)
  )
  select case
           when not exists (select 1 from e) then 'missing'
           when p_requirement = 'grade' and (select count(distinct e.grade) from e) > 1 then 'contradictory'
           when exists (select 1 from live) then 'verified'
           when exists (select 1 from e where e.state = 'verified') then 'expired'
           else 'self_confirmed'
         end,
         case when p_requirement = 'grade' and (select count(distinct e.grade) from e) = 1
              then (select min(e.grade) from e) end,
         (select max(coalesce(l.valid_until, 'infinity'::timestamptz)) from live l)
$$;
revoke all on function private.qual_evidence_state(uuid, uuid, text, timestamptz) from public, anon, authenticated;

-- The member's own statement (QUAL1-3): always self_confirmed, simulation organisations only (Phase A).
create or replace function public.confirm_my_qualification(
  p_organization_id uuid, p_requirement text, p_grade text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare uid uuid := (select auth.uid());
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_requirement is null or (p_requirement = 'grade') <> (p_grade is not null) then
    raise exception 'a grade statement names the grade; other statements do not' using errcode = '22023';
  end if;
  if private.begin_command('confirm_my_qualification', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  if not private.is_org_member(p_organization_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  if not coalesce((select o.simulation from public.organizations o where o.id = p_organization_id), false) then
    perform private.end_command('not_simulation');
    return jsonb_build_object('result', 'not_simulation');
  end if;
  insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, recorded_by)
  values (p_organization_id, uid, p_requirement, p_grade, 'self_confirmed', uid);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'state', 'self_confirmed');
end;
$$;
revoke all on function public.confirm_my_qualification(uuid, text, text, uuid) from public, anon;
grant execute on function public.confirm_my_qualification(uuid, text, text, uuid) to authenticated;
comment on function public.confirm_my_qualification(uuid, text, text, uuid) is
  'QUAL1-3 / ADR-163: the member confirms one profile value. Writes self_confirmed, never verified (FE-039, FE-040). '
  'Simulation organisations only in Phase A.';

-- 4. Delegation (CR-176, CR-176a) ---------------------------------------------------------------------------------------------
create table if not exists public.qual_delegations (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id),
  case_id         uuid not null references public.cases (id),
  activity_code   text not null references public.qual_activities (code),
  delegate_id     uuid not null,
  delegator_id    uuid not null,
  supervisor_id   uuid not null,
  matrix_version  text not null references public.qual_matrix_versions (version),
  instructed_on   date not null,
  valid_from      date not null,
  valid_until     date not null,
  conditions      text check (conditions is null or length(conditions) <= 500),
  created_at      timestamptz not null default private.now(),
  check (valid_until >= valid_from),
  check (delegate_id <> delegator_id)
);
create index if not exists qual_delegations_lookup_idx
  on public.qual_delegations (delegate_id, case_id, activity_code, valid_until);
comment on table public.qual_delegations is
  'QUAL1-9 / CR-176 / ADR-163: a named nurse delegates one activity for one case to one member of her team, from an '
  'instruction date, between fixed dates, with a supervising nurse. Append-only; ended only by a revocation row or by its '
  'end date. Written only by public.record_delegation; never by an agent or a rule (AIG1 prohibited target).';

create table if not exists public.qual_delegation_revocations (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  organization_id uuid not null references public.organizations (id),
  delegation_id   uuid not null unique references public.qual_delegations (id),
  revoked_by      uuid not null,
  created_at      timestamptz not null default private.now()
);

-- 5. Activities on the visit (QUAL1-6) ---------------------------------------------------------------------------------------
create table if not exists public.visit_activities (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null references public.care_visits (id) on delete cascade,
  activity_code   text not null references public.qual_activities (code),
  created_at      timestamptz not null default private.now(),
  unique (visit_id, activity_code)
);
comment on table public.visit_activities is
  'QUAL1-6 / ADR-163: the matrix activities a visit requires. Without a row, private.qual_visit_activities counts a needs '
  'assessment as A1 and KLV-B minutes as B13. Part 1: written by fixtures only (the commands come with part 2).';

create or replace function private.qual_append_only()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception '% is append-only (QUAL1-9)', tg_table_name using errcode = '42501';
end;
$$;
revoke all on function private.qual_append_only() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['member_qualification_evidence', 'qual_delegations', 'qual_delegation_revocations',
                           'visit_activities'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('drop policy if exists leave1_access_open on public.%I', t);
    execute format('create policy leave1_access_open on public.%I as restrictive for all to authenticated '
                   'using (not (select private.access_ended((select auth.uid()))))', t);
    execute format('drop trigger if exists %I on public.%I', t || '_no_truncate', t);
    execute format('create trigger %I before truncate on public.%I for each statement '
                   'execute function private.qual_append_only()', t || '_no_truncate', t);
  end loop;
  foreach t in array array['qual_delegations', 'qual_delegation_revocations', 'visit_activities'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_append_only', t);
    execute format('create trigger %I before update or delete on public.%I for each row '
                   'execute function private.qual_append_only()', t || '_append_only', t);
  end loop;
end;
$$;
-- visit_activities rows go with their visit (on delete cascade): the row trigger above refuses a direct delete; the
-- cascade is a delete too, so allow it only when the visit itself is gone.
create or replace function private.qual_visit_activities_guard()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.care_visits v where v.id = old.visit_id) then
    return old;
  end if;
  raise exception 'visit_activities is append-only (QUAL1-6)' using errcode = '42501';
end;
$$;
revoke all on function private.qual_visit_activities_guard() from public, anon, authenticated;
drop trigger if exists visit_activities_append_only on public.visit_activities;
create trigger visit_activities_append_only before update or delete on public.visit_activities
  for each row execute function private.qual_visit_activities_guard();

drop trigger if exists member_qualification_evidence_guard on public.member_qualification_evidence;
create trigger member_qualification_evidence_guard before insert or update or delete on public.member_qualification_evidence
  for each row execute function private.qual_guard_evidence();

drop policy if exists qual_evidence_self_or_admin_read on public.member_qualification_evidence;
create policy qual_evidence_self_or_admin_read on public.member_qualification_evidence
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_org_admin(organization_id));
drop policy if exists qual_delegations_team_read on public.qual_delegations;
create policy qual_delegations_team_read on public.qual_delegations
  for select to authenticated
  using (private.is_team_member(team_id) or private.is_org_admin(organization_id));
drop policy if exists qual_revocations_team_read on public.qual_delegation_revocations;
create policy qual_revocations_team_read on public.qual_delegation_revocations
  for select to authenticated
  using (exists (select 1 from public.qual_delegations d where d.id = delegation_id
                 and (private.is_team_member(d.team_id) or private.is_org_admin(d.organization_id))));
drop policy if exists visit_activities_team_read on public.visit_activities;
create policy visit_activities_team_read on public.visit_activities
  for select to authenticated
  using (exists (select 1 from public.care_visits v where v.id = visit_id
                 and (private.is_team_member(v.team_id) or private.is_coordinator(v.organization_id))));

drop trigger if exists audit_member_qualification_evidence on public.member_qualification_evidence;
create trigger audit_member_qualification_evidence after insert on public.member_qualification_evidence
  for each row execute function private.write_audit_event('user_id', 'requirement', 'grade', 'state', 'valid_until');
drop trigger if exists audit_qual_delegations on public.qual_delegations;
create trigger audit_qual_delegations after insert on public.qual_delegations
  for each row execute function private.write_audit_event('case_id', 'activity_code', 'delegate_id', 'delegator_id',
                                                          'supervisor_id', 'matrix_version', 'valid_from', 'valid_until');
drop trigger if exists audit_qual_delegation_revocations on public.qual_delegation_revocations;
create trigger audit_qual_delegation_revocations after insert on public.qual_delegation_revocations
  for each row execute function private.write_audit_event('delegation_id', 'revoked_by');
-- AUD1-1 value catalogue: every audited key is a code (ids, dates, constrained or referenced codes; no free text).
insert into private.audit_value_classes (table_name, key, class) values
  ('member_qualification_evidence', 'user_id', 'code'), ('member_qualification_evidence', 'requirement', 'code'),
  ('member_qualification_evidence', 'grade', 'code'), ('member_qualification_evidence', 'state', 'code'),
  ('member_qualification_evidence', 'valid_until', 'code'),
  ('qual_delegations', 'case_id', 'code'), ('qual_delegations', 'activity_code', 'code'),
  ('qual_delegations', 'delegate_id', 'code'), ('qual_delegations', 'delegator_id', 'code'),
  ('qual_delegations', 'supervisor_id', 'code'), ('qual_delegations', 'matrix_version', 'code'),
  ('qual_delegations', 'valid_from', 'code'), ('qual_delegations', 'valid_until', 'code'),
  ('qual_delegation_revocations', 'delegation_id', 'code'), ('qual_delegation_revocations', 'revoked_by', 'code'),
  ('visit_activities', 'visit_id', 'code'), ('visit_activities', 'activity_code', 'code')
on conflict (table_name, key) do nothing;
drop trigger if exists audit_visit_activities on public.visit_activities;
create trigger audit_visit_activities after insert on public.visit_activities
  for each row execute function private.write_audit_event('visit_id', 'activity_code');

-- A nurse who may delegate or supervise at an instant: active in the team, verified nurse_hf_fh, verified licence.
create or replace function private.qual_may_delegate(p_org uuid, p_team uuid, p_user uuid, p_at timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.adm2_active_member(p_team, p_user)
     and exists (select 1 from private.qual_evidence_state(p_org, p_user, 'grade', p_at) g
                 where g.state = 'verified' and g.grade = 'nurse_hf_fh')
     and exists (select 1 from private.qual_evidence_state(p_org, p_user, 'practice_licence', p_at) l
                 where l.state = 'verified')
$$;
revoke all on function private.qual_may_delegate(uuid, uuid, uuid, timestamptz) from public, anon, authenticated;

create or replace function public.record_delegation(
  p_team_id uuid, p_case_id uuid, p_activity_code text, p_delegate_id uuid, p_supervisor_id uuid,
  p_instructed_on date, p_valid_from date, p_valid_until date, p_conditions text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  org   uuid;
  ver   text := private.qual_matrix_version();
  inst  timestamptz := private.now();
  dg    record;
  cell  public.qual_matrix_cells%rowtype;
  new_id uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_instructed_on is null or p_valid_from is null or p_valid_until is null then
    raise exception 'instruction date, start and a fixed end date are required (CR-176)' using errcode = '22023';
  end if;
  if p_valid_until < p_valid_from then
    raise exception 'the end date is before the start date' using errcode = '22023';
  end if;
  -- CGR-150: no instruction after the start or in the future, no start in the past (no retroactive delegation).
  if p_instructed_on > p_valid_from then
    return jsonb_build_object('result', 'instruction_after_start');
  end if;
  if p_instructed_on > (private.now() at time zone 'Europe/Zurich')::date then
    return jsonb_build_object('result', 'instruction_in_future');
  end if;
  if p_valid_from < (private.now() at time zone 'Europe/Zurich')::date then
    return jsonb_build_object('result', 'start_in_past');
  end if;
  if private.begin_command('record_delegation', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select t.organization_id into org from public.teams t where t.id = p_team_id;
  if org is null or not private.adm2_active_member(p_team_id, uid)
     or not exists (select 1 from public.cases c where c.id = p_case_id and c.assigned_team_id = p_team_id)
     or not private.adm2_active_member(p_team_id, p_delegate_id) or p_delegate_id = uid then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  if not coalesce((select o.simulation from public.organizations o where o.id = org), false) then
    perform private.end_command('not_simulation');
    return jsonb_build_object('result', 'not_simulation');
  end if;
  if not private.qual_may_delegate(org, p_team_id, uid, inst) then
    perform private.end_command('not_allowed_to_delegate');
    return jsonb_build_object('result', 'not_allowed_to_delegate');
  end if;
  if p_supervisor_id is null or not private.qual_may_delegate(org, p_team_id, p_supervisor_id, inst) then
    perform private.end_command('supervisor_not_qualified');
    return jsonb_build_object('result', 'supervisor_not_qualified');
  end if;
  select * into dg from private.qual_evidence_state(org, p_delegate_id, 'grade', inst);
  if dg.state <> 'verified' then
    perform private.end_command('delegate_evidence_' || dg.state);
    return jsonb_build_object('result', 'delegate_evidence_' || dg.state);
  end if;
  select * into cell from public.qual_matrix_cells c
  where c.version = ver and c.activity_code = p_activity_code and c.grade = dg.grade;
  if cell.value is distinct from 'D' or cell.open_question is not null then
    -- CR-176a: a delegation never covers a row that is E, - or ? for the delegate's grade.
    perform private.end_command('activity_not_delegable');
    return jsonb_build_object('result', 'activity_not_delegable', 'value', coalesce(cell.value, '?'));
  end if;
  insert into public.qual_delegations (organization_id, team_id, case_id, activity_code, delegate_id, delegator_id,
                                       supervisor_id, matrix_version, instructed_on, valid_from, valid_until, conditions)
  values (org, p_team_id, p_case_id, p_activity_code, p_delegate_id, uid, p_supervisor_id, ver, p_instructed_on,
          p_valid_from, p_valid_until, nullif(btrim(p_conditions), ''))
  returning id into new_id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'delegation_id', new_id);
end;
$$;
revoke all on function public.record_delegation(uuid, uuid, text, uuid, uuid, date, date, date, text, uuid) from public, anon;
grant execute on function public.record_delegation(uuid, uuid, text, uuid, uuid, date, date, date, text, uuid) to authenticated;
comment on function public.record_delegation(uuid, uuid, text, uuid, uuid, date, date, date, text, uuid) is
  'QUAL1-9 / CR-176 / CR-176a / ADR-163: a verified nurse_hf_fh with a verified practice licence, active in the team, '
  'delegates one D activity for one case of the team to one verified member of the team, with a supervising nurse who '
  'meets the same test, between fixed dates. Simulation organisations only (Phase A). A personal act; no agent.';

create or replace function public.revoke_delegation(p_delegation_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  d   public.qual_delegations%rowtype;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('revoke_delegation', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into d from public.qual_delegations where id = p_delegation_id;
  if d.id is null or not private.adm2_active_member(d.team_id, uid)
     or not (uid in (d.delegator_id, d.supervisor_id)
             or uid = (select c.primary_nurse_id from public.cases c where c.id = d.case_id)) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  if exists (select 1 from public.qual_delegation_revocations r where r.delegation_id = d.id) then
    perform private.end_command('already_revoked');
    return jsonb_build_object('result', 'already_revoked');
  end if;
  insert into public.qual_delegation_revocations (organization_id, delegation_id, revoked_by)
  values (d.organization_id, d.id, uid);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok');
end;
$$;
revoke all on function public.revoke_delegation(uuid, uuid) from public, anon;
grant execute on function public.revoke_delegation(uuid, uuid) to authenticated;
comment on function public.revoke_delegation(uuid, uuid) is
  'QUAL1-9 / CR-176 / ADR-163: the delegating or supervising nurse, or the case''s primary nurse (F4), ends a delegation '
  'at once. Append-only revocation row; nothing is deleted.';

-- No agent ever aims at qualification records (QUAL1-9, QUAL1-16; AIG1 field register, 0107).
create or replace function private.aig1_prohibited_target(p_table text, p_column text)
returns text language sql immutable set search_path = ''
as $$
  select case
    when p_table in ('billable_facts', 'billing_rules', 'tariff_rates', 'quality_holds') then 'billing'
    when p_table = 'safety_signals' or p_table like 'signal\_%' then 'safety_signal'
    when p_table in ('exception_rules', 'exception_rule_overrides') then 'safety_signal'
    when p_table in ('member_qualification_evidence', 'qual_delegations', 'qual_delegation_revocations',
                     'qual_matrix_cells', 'qual_matrix_versions', 'qual_activities') then 'qualification'
  end
$$;
revoke all on function private.aig1_prohibited_target(text, text) from public, anon, authenticated;
comment on function private.aig1_prohibited_target(text, text) is
  'Owner directive 2026-11-03 (#824, ADR-141): targets no assistant may ever propose a value for, whatever the class: '
  'billing (billable facts, billing rules, tariff rates, quality holds) and safety-signal priority (safety signals, '
  'their deliveries and takes, the exception rules and overrides that make a signal P1). QUAL1-9 (ADR-163): '
  'qualification evidence, delegations and the matrix (FE-039: no agent grants a delegation or upgrades evidence).';

-- 6. The one decision function (QUAL1-8) --------------------------------------------------------------------------------------
create or replace function private.qual_visit_activities(p_visit uuid)
returns setof text language sql stable security definer set search_path = ''
as $$
  -- CGR-149 (`cra` 2026-11-07 01:35): every minute class maps to a row when the visit lists none of that class, and a
  -- visit with no activity and no minutes counts as C1; so no visit is ever checked against "no activity".
  with v as (select * from public.care_visits x where x.id = p_visit),
  listed as (select a.activity_code as code from public.visit_activities a where a.visit_id = p_visit)
  select l.code from listed l
  union
  select 'A1' from v where v.is_needs_assessment
     or (coalesce(v.planned_minutes_a, 0) > 0 and not exists (select 1 from listed l where l.code like 'A%'))
  union
  select 'B13' from v
  where coalesce(v.planned_minutes_b, 0) > 0 and not exists (select 1 from listed l where l.code like 'B%')
  union
  select 'C1' from v
  where (coalesce(v.planned_minutes_c, 0) > 0 and not exists (select 1 from listed l where l.code like 'C%'))
     or (not exists (select 1 from listed) and not v.is_needs_assessment
         and coalesce(v.planned_minutes_a, 0) = 0 and coalesce(v.planned_minutes_b, 0) = 0)
$$;
revoke all on function private.qual_visit_activities(uuid) from public, anon, authenticated;

create or replace function private.qual_label(p_result text)
returns text language sql immutable set search_path = ''
as $$
  select case p_result
    when 'allowed_own' then 'geeignet'
    when 'allowed_delegated' then 'geeignet_mit_delegation'
    when 'not_allowed' then 'nicht_geeignet'
    else 'ungeklaert'                    -- CR-183: everything else is never shown as suitable
  end
$$;
revoke all on function private.qual_label(text) from public, anon, authenticated;

create or replace function private.qual_check(p_visit uuid, p_user uuid)
returns table (activity_code text, result text, label text, reason text, matrix_version text, rule_status text,
               delegation_id uuid, delegation_until date)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v     public.care_visits%rowtype;
  ver   text := private.qual_matrix_version();
  inst  timestamptz;
  v_start timestamptz;
  g     record;
  req   record;
  cell  public.qual_matrix_cells%rowtype;
  a     text;
  acts  text[];
  dl    record;
  r_res text;
  r_why text;
  missing_req text;
begin
  select * into v from public.care_visits x where x.id = p_visit;
  if v.id is null or p_user is null then return; end if;
  -- The evidence must cover the whole visit, and count as lapsed from the instant it ends (QUAL1-2, QUAL1-4).
  inst := greatest(private.at_zurich((v.visit_date + coalesce(v.time_end, time '23:59'))::timestamp),
                   private.now());
  -- CGR-150: a delegation counts only if it was instructed by the visit's day and recorded before the visit starts.
  v_start := private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))::timestamp);
  select * into g from private.qual_evidence_state(v.organization_id, p_user, 'grade', inst);
  select array_agg(f.code order by q.sort) into acts
  from private.qual_visit_activities(p_visit) as f (code) join public.qual_activities q on q.code = f.code;
  if acts is null then acts := array[null::text]; end if;

  foreach a in array acts loop
    activity_code := a; matrix_version := ver; delegation_id := null; delegation_until := null; rule_status := null;
    if g.state <> 'verified' then
      r_res := case g.state when 'expired' then 'evidence_expired' when 'contradictory' then 'evidence_contradictory'
                            else 'evidence_missing' end;
      r_why := 'grade:' || g.state;
    elsif a is null then
      r_res := 'unresolved'; r_why := 'no_activity_listed';   -- CGR-149: never allowed (not reachable since the C1 fallback)
    else
      select * into cell from public.qual_matrix_cells c where c.version = ver and c.activity_code = a and c.grade = g.grade;
      rule_status := cell.status;
      if cell.value is null then
        r_res := 'unresolved'; r_why := 'no_cell';
      elsif cell.value = '-' then
        r_res := 'not_allowed'; r_why := 'cell:-';
      elsif cell.value = '?' or cell.open_question is not null then
        r_res := 'unresolved'; r_why := 'cell:?' || coalesce(':' || cell.open_question, '');
      elsif cell.value = 'E' then
        missing_req := null;
        foreach r_why in array cell.requires loop
          select * into req from private.qual_evidence_state(v.organization_id, p_user, r_why, inst);
          if req.state <> 'verified' and missing_req is null then
            missing_req := r_why || ':' || req.state;
          end if;
        end loop;
        if missing_req is null then
          r_res := 'allowed_own'; r_why := 'cell:E';
        else
          r_res := case when missing_req like '%:expired' then 'evidence_expired' else 'evidence_missing' end;
          r_why := missing_req;
        end if;
      else  -- 'D'
        select d.id, d.valid_until into dl from public.qual_delegations d
        where d.organization_id = v.organization_id and d.team_id = v.team_id and d.case_id = v.case_id
          and d.activity_code = a and d.delegate_id = p_user
          and v.visit_date between d.valid_from and d.valid_until
          and d.instructed_on <= v.visit_date and d.created_at <= v_start
          and not exists (select 1 from public.qual_delegation_revocations r where r.delegation_id = d.id)
          and private.qual_may_delegate(v.organization_id, v.team_id, d.delegator_id, inst)
          and private.qual_may_delegate(v.organization_id, v.team_id, d.supervisor_id, inst)
        order by d.valid_until desc, d.seq desc limit 1;
        if dl.id is not null then
          r_res := 'allowed_delegated'; r_why := 'delegation';
          delegation_id := dl.id; delegation_until := dl.valid_until;
        else
          -- Why not: a delegation in force whose delegator or supervisor lapsed ("Überprüfung nötig", nothing deleted),
          -- else the newest one that ended before the visit, else none (another case or member never counts, NT-7).
          select d.id, d.valid_until into dl from public.qual_delegations d
          where d.organization_id = v.organization_id and d.team_id = v.team_id and d.case_id = v.case_id
            and d.activity_code = a and d.delegate_id = p_user
            and v.visit_date between d.valid_from and d.valid_until
          and d.instructed_on <= v.visit_date and d.created_at <= v_start
            and not exists (select 1 from public.qual_delegation_revocations r where r.delegation_id = d.id)
          order by d.valid_until desc, d.seq desc limit 1;
          if dl.id is not null then
            r_res := 'delegation_review_needed'; r_why := 'delegator_or_supervisor_lapsed';
            delegation_id := dl.id; delegation_until := dl.valid_until;
          else
            select d.id, d.valid_until into dl from public.qual_delegations d
            where d.organization_id = v.organization_id and d.team_id = v.team_id and d.case_id = v.case_id
              and d.activity_code = a and d.delegate_id = p_user and d.valid_until < v.visit_date
              and not exists (select 1 from public.qual_delegation_revocations r where r.delegation_id = d.id)
            order by d.valid_until desc, d.seq desc limit 1;
            if dl.id is not null then
              r_res := 'delegation_expired'; r_why := 'delegation_ended';
              delegation_id := dl.id; delegation_until := dl.valid_until;
            else
              r_res := 'delegation_missing'; r_why := 'no_delegation';
            end if;
          end if;
        end if;
      end if;
    end if;
    result := r_res; reason := r_why; label := private.qual_label(r_res);
    return next;
  end loop;
end;
$$;
revoke all on function private.qual_check(uuid, uuid) from public, anon, authenticated;
comment on function private.qual_check(uuid, uuid) is
  'QUAL1-8 / CR-177 / CR-183 / ADR-163: per activity of the visit, whether the member may do it (allowed_own, '
  'allowed_delegated) or why not (not_allowed, unresolved, evidence_*, delegation_*), with the CR-183 label, matrix '
  'version and cell status (PROPOSED). "?" is never allowed. No client datum in the result.';

create or replace function private.qual_may_perform(p_visit uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case
    when coalesce(o.simulation, false) then
      private.user_in_team(v.team_id, p_user) and not private.access_ended(p_user)
      and not exists (select 1 from private.qual_check(v.id, p_user) c
                      where c.result not in ('allowed_own', 'allowed_delegated'))
    else private.may_perform_visit(v.team_id, p_user, v.planned_minutes_b, v.is_needs_assessment)
  end
  from public.care_visits v join public.organizations o on o.id = v.organization_id
  where v.id = p_visit
$$;
revoke all on function private.qual_may_perform(uuid, uuid) from public, anon, authenticated;
comment on function private.qual_may_perform(uuid, uuid) is
  'QUAL1-1 / QUAL1-10 / ADR-163: the one answer every assignment path will ask (wired in QUAL1 part 2). In a simulation '
  'organisation: member of the team, access open, and every activity allowed_own or allowed_delegated. Elsewhere: '
  'private.may_perform_visit (CR-007/CR-164), unchanged. No override parameter.';

create or replace function public.visit_qualification_check(p_visit_id uuid, p_user_id uuid)
returns table (activity_code text, result text, label text, reason text, matrix_version text, rule_status text,
               delegation_until date)
language sql stable security definer set search_path = ''
as $$
  -- CGR-152: the reason (which may name a member's evidence) only for the member herself and administrators.
  select c.activity_code, c.result, c.label,
         case when p_user_id = (select auth.uid()) or private.is_org_admin(v.organization_id) then c.reason end,
         c.matrix_version, c.rule_status, c.delegation_until
  from public.care_visits v
  join public.organizations o on o.id = v.organization_id and o.simulation
  cross join lateral private.qual_check(v.id, p_user_id) c
  where v.id = p_visit_id
    and (private.is_team_member(v.team_id) or private.is_coordinator(v.organization_id))
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
    and private.user_in_team(v.team_id, p_user_id)
$$;
revoke all on function public.visit_qualification_check(uuid, uuid) from public, anon;
grant execute on function public.visit_qualification_check(uuid, uuid) to authenticated;
comment on function public.visit_qualification_check(uuid, uuid) is
  'QUAL1-8 / ADR-163: the activity check of one member of the visit''s team for that visit, for members of the team and '
  'coordinators; simulation organisations only. Activity codes and reason codes only, no client datum.';
