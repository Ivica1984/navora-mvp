-- ASM1 (ADR-123): the needs assessment is recorded once, as a signed fact, and the care plan shows which assessment it
-- rests on. PO brief docs/agents/briefs/ASM1.md (approved 2026-10-27; amended 21:15, 22:15 and 2026-10-28 02:10 for
-- `aia` AUT-2, `cra` CGR-81 and CGR-84). D-13 option B (po-decided 2026-10-25, criteria 1-5 from `lca` and `cra`),
-- D-36 option A. Synthetic data only (real-data gate: D-29, D-11/D-12).
--
-- No clinical, legal or tariff rule is made here. NAVORA records what the assessing nurse's tool says and computes
-- nothing from it: no reassessment interval or due date, no signal, no exception, no category mapping (D-15), no
-- import (D-13 A), no designated instrument (D-37), no list of periods (CGR-84: KLV Art. 8 periods UNKNOWN), no sum of
-- planned minutes (CGR-81). J3 planning and J5 billing read nothing of this (ASM1-8).
--
-- Before (IMPLEMENTED, read in a database built from 0001-0099):
--   * The assessment is a visit flag (`care_visits.is_needs_assessment`, 0014) and a first-completion date
--     (`cases.needs_assessment_done_at`, set once by coalesce, 0014). A reassessment leaves no trace.
--   * `care_plan_items` (0014, 0025) carry service, category, planned minutes per occurrence and a free-text frequency
--     (optional structured frequency, 0025); nothing links an item to an assessment.
--   * J5 billing facts take the minutes of the visit (`care_visits.planned_minutes_*`, measured times, 0022/0023/0043),
--     never the care plan's minutes.
--   * No member stores a GLN (ADM1, 0035/0059: name, role, team, qualification); qualification verification is D-29.
-- Now (IMPLEMENTED in this migration):
--   1. ASM1-6 `assessment_instruments`: per organisation name, version, valid from, valid to, and whether the name is a
--      third party's mark (shown as such). Names only. Administrators add an entry and may end its validity (never
--      before an assessment recorded with it). No "designated" column (D-37). Every member of the organisation reads
--      the list (no personal data); the author columns are not selectable.
--   2. ASM1-1 to ASM1-5 `assessment_records`: append-only, several per case. Date, instrument entry, assessing
--      registered nurse (a member of the case's team with the recorded qualification `registered_nurse`; verification
--      is D-29, UNKNOWN; no GLN field: who would verify it is D-29), document reference, minutes per category each
--      with its period as entered, author and time. No item, score, scale, CAP, output or finding column.
--      * Period: the text entered, non-empty, at most 60 characters; no check on its values (CGR-84).
--      * Minutes: an integer 0..99999 per category, or none; a minutes value without its period, or a period without
--        minutes, is refused. 99999 is a storage bound only (no tariff or clinical meaning).
--      * Reference (ASM1-3): an opaque identifier, 3..64 characters, letters, digits and `_ : # -`, at least one digit,
--        starting with a letter or digit: no space, no dot, no slash, so no file name or path. NAVORA stores no document.
--      * Minutes need the reference (ASM1-4).
--      * Supersede (ASM1-2): a new record names the record it supersedes (same case, not yet superseded) with a reason
--        of 10..500 characters. The old record stays and is never current. No update or delete for any role (trigger,
--        also for the table owner).
--      * Confirmation (ASM1-5): a record entered by the named nurse is confirmed; otherwise it is "nicht bestätigt"
--        until that nurse records the confirmation (`assessment_confirmations`, append-only, audited). Nobody else can
--        confirm. Planning may use an unconfirmed record; the team sees the state.
--      The integrity rules hold on every write path (BEFORE INSERT trigger), the command returns them as reasons.
--   3. ASM1-7 `care_plan_items.assessment_id`: set on every insert, by trigger, to the case's current assessment at that
--      moment (a value a writer passes is overwritten). Existing items keep null (written before any record; no
--      history is guessed). The plan's basis is the oldest current version among its active items' assessments; when
--      a current assessment of a later date exists (or the plan has an item written before any record), the reader
--      returns its date for "Neuere Bedarfsabklärung vom <Datum>". No block, no signal, no exception.
--   4. ASM1-9 reads: the records, confirmations and the plan basis are read by the members of the case's assigned team
--      (RLS2 `private.reads_case`) through the table (act columns closed, RLS4 pattern) and through
--      `public.team_case_assessments()`. Operations, coaches and administrators read no record, minutes or reference
--      (no policy, no reader); nothing is widened.
--   5. ASM1-11 (4) the dated facts that exist today and are younger than the current assessment: resume after a pause
--      and a pause for a hospital stay (`case_lifecycle_events`, C1 0024), a serious quality event (`quality_events`,
--      severity high or critical as `private.is_serious`, QG1 0020). Returned per kind with the latest date; nothing is
--      derived or blocked. No new event type.
-- Idempotent: `create table if not exists`, `add column if not exists`, `create or replace`, `drop ... if exists`,
-- `on conflict do nothing`.

-- 1. ASM1-6 instrument reference list ------------------------------------------------------------------------------------
create table if not exists public.assessment_instruments (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id),
  name             text not null check (char_length(btrim(name)) between 2 and 120),
  version          text not null check (char_length(btrim(version)) between 1 and 40),
  valid_from       date not null,
  valid_to         date check (valid_to is null or valid_to >= valid_from),
  third_party_mark boolean not null default false,
  created_by       uuid not null,
  created_at       timestamptz not null default private.now(),
  ended_by         uuid,
  ended_at         timestamptz,
  unique (organization_id, name, version, valid_from),
  unique (id, organization_id)
);
comment on table public.assessment_instruments is
  'ASM1-6 (ADR-123): the organisation''s list of assessment instruments: name, version, validity, third-party mark. '
  'Names only: no logo, no item text, no licence or endorsement claim, no designation (D-37). Synthetic in the seed.';
comment on column public.assessment_instruments.third_party_mark is
  'ASM1-6 / D-36 A (lca terms (a)-(c)): the name is a third party''s mark; the list shows it as such.';

alter table public.assessment_instruments enable row level security;
revoke all on public.assessment_instruments from anon, authenticated;
grant select (id, organization_id, name, version, valid_from, valid_to, third_party_mark, created_at)
  on public.assessment_instruments to authenticated;
drop policy if exists org_members_read on public.assessment_instruments;
create policy org_members_read on public.assessment_instruments
  for select to authenticated
  using (private.is_org_member(organization_id));

drop trigger if exists audit_assessment_instruments on public.assessment_instruments;
create trigger audit_assessment_instruments
  after insert or update on public.assessment_instruments
  for each row execute function private.write_audit_event('valid_from', 'valid_to', 'third_party_mark');

-- 2. ASM1-1 to ASM1-4 the record ------------------------------------------------------------------------------------------
create table if not exists public.assessment_records (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id),
  case_id          uuid not null,
  team_id          uuid not null,
  assessment_date  date not null,
  instrument_id    uuid not null,
  assessor_id      uuid not null,
  document_ref     text check (document_ref is null
                               or (document_ref ~ '^[A-Za-z0-9][A-Za-z0-9_:#-]{2,63}$' and document_ref ~ '[0-9]')),
  minutes_a        integer check (minutes_a is null or minutes_a between 0 and 99999),
  period_a         text check (period_a is null or char_length(btrim(period_a)) between 1 and 60),
  minutes_b        integer check (minutes_b is null or minutes_b between 0 and 99999),
  period_b         text check (period_b is null or char_length(btrim(period_b)) between 1 and 60),
  minutes_c        integer check (minutes_c is null or minutes_c between 0 and 99999),
  period_c         text check (period_c is null or char_length(btrim(period_c)) between 1 and 60),
  supersedes_id    uuid unique references public.assessment_records (id),
  supersede_reason text check (supersede_reason is null or char_length(btrim(supersede_reason)) between 10 and 500),
  entered_by       uuid not null,
  created_at       timestamptz not null default private.now(),
  -- ASM1-1: minutes only with their period, a period only with minutes
  constraint assessment_minutes_with_period check ((minutes_a is null) = (period_a is null)
                                                  and (minutes_b is null) = (period_b is null)
                                                  and (minutes_c is null) = (period_c is null)),
  -- ASM1-4: minutes only with the reference to the full assessment
  constraint assessment_minutes_need_reference check (
    (minutes_a is null and minutes_b is null and minutes_c is null) or document_ref is not null),
  -- ASM1-2: a supersede always carries its reason, a reason only a supersede
  constraint assessment_supersede_reason check ((supersedes_id is null) = (supersede_reason is null)),
  foreign key (case_id, organization_id) references public.cases (id, organization_id),
  foreign key (team_id, organization_id) references public.teams (id, organization_id),
  foreign key (instrument_id, organization_id) references public.assessment_instruments (id, organization_id)
);
create index if not exists assessment_records_case_idx on public.assessment_records (case_id, assessment_date);
comment on table public.assessment_records is
  'ASM1-1 (ADR-123, D-13 B): one needs assessment of a case as a recorded fact. Append-only; corrected by a new record '
  'naming the one it supersedes (ASM1-2). No item, score, scale, CAP, output or finding column. Nothing is computed '
  'from it: J3 planning and J5 billing do not read it (ASM1-8).';
comment on column public.assessment_records.document_ref is
  'ASM1-3: opaque identifier of the full assessment in the provider''s tool, 3..64 of [A-Za-z0-9_:#-] with a digit; '
  'never a file name, title or free text. NAVORA stores no document.';
comment on column public.assessment_records.period_a is
  'ASM1-1 / CGR-84: the period the minutes refer to, as entered from the assessment. No list, no default, no derivation.';

alter table public.assessment_records enable row level security;
revoke all on public.assessment_records from anon, authenticated;
-- RLS4 pattern: the act columns (assessor_id, entered_by) are read per record through team_case_assessments only.
grant select (id, organization_id, case_id, team_id, assessment_date, instrument_id, document_ref,
              minutes_a, period_a, minutes_b, period_b, minutes_c, period_c, supersedes_id, supersede_reason, created_at)
  on public.assessment_records to authenticated;
drop policy if exists case_team_read on public.assessment_records;
create policy case_team_read on public.assessment_records
  for select to authenticated
  using (private.is_org_member(organization_id) and private.reads_case(case_id));

drop trigger if exists assessment_records_no_update_delete on public.assessment_records;
create trigger assessment_records_no_update_delete
  before update or delete on public.assessment_records
  for each row execute function private.forbid_audit_change();
drop trigger if exists assessment_records_no_truncate on public.assessment_records;
create trigger assessment_records_no_truncate
  before truncate on public.assessment_records
  for each statement execute function private.forbid_audit_change();
drop trigger if exists audit_assessment_records on public.assessment_records;
create trigger audit_assessment_records
  after insert on public.assessment_records
  for each row execute function private.write_audit_event(
    'case_id', 'assessment_date', 'instrument_id', 'assessor_id', 'minutes_a', 'minutes_b', 'minutes_c', 'supersedes_id');

-- Integrity on every write path (the command returns the same conditions as reasons first).
create or replace function private.guard_assessment_record()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cases%rowtype;
  s public.assessment_records%rowtype;
begin
  select * into c from public.cases where id = new.case_id;
  if not found or c.assigned_team_id is distinct from new.team_id then
    raise exception 'ASM1: the record belongs to the case''s assigned team' using errcode = '23514';
  end if;
  if new.assessment_date > private.at_zurich(private.now())::date then
    raise exception 'ASM1: the assessment date is not in the future' using errcode = '23514';
  end if;
  if not exists (select 1 from public.assessment_instruments i
                 where i.id = new.instrument_id and i.organization_id = new.organization_id
                   and i.valid_from <= new.assessment_date
                   and (i.valid_to is null or i.valid_to >= new.assessment_date)) then
    raise exception 'ASM1-6: the instrument entry is not valid on the assessment date' using errcode = '23514';
  end if;
  if not private.is_registered_nurse(new.team_id, new.assessor_id) or private.access_ended(new.assessor_id) then
    raise exception 'ASM1-1: the assessor is a registered nurse of the case''s team' using errcode = '23514';
  end if;
  if new.supersedes_id is not null then
    select * into s from public.assessment_records where id = new.supersedes_id;
    if not found or s.case_id <> new.case_id then
      raise exception 'ASM1-2: a record supersedes a record of the same case' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.guard_assessment_record() from public, anon, authenticated;
drop trigger if exists assessment_records_guard on public.assessment_records;
create trigger assessment_records_guard
  before insert on public.assessment_records
  for each row execute function private.guard_assessment_record();

-- 3. ASM1-5 confirmation by the named nurse ------------------------------------------------------------------------------
create table if not exists public.assessment_confirmations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  record_id       uuid not null unique references public.assessment_records (id),
  confirmed_by    uuid not null,
  confirmed_at    timestamptz not null default private.now()
);
comment on table public.assessment_confirmations is
  'ASM1-5 (ADR-123): the named assessing nurse confirms a record someone else entered. Append-only; one per record.';
alter table public.assessment_confirmations enable row level security;
revoke all on public.assessment_confirmations from anon, authenticated;
grant select (id, organization_id, record_id, confirmed_at) on public.assessment_confirmations to authenticated;
drop policy if exists case_team_read on public.assessment_confirmations;
create policy case_team_read on public.assessment_confirmations
  for select to authenticated
  using (private.is_org_member(organization_id)
         and exists (select 1 from public.assessment_records r
                     where r.id = record_id and private.reads_case(r.case_id)));

create or replace function private.guard_assessment_confirmation()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  r public.assessment_records%rowtype;
begin
  select * into r from public.assessment_records where id = new.record_id;
  if not found or r.organization_id <> new.organization_id
     or new.confirmed_by <> r.assessor_id or r.entered_by = r.assessor_id then
    raise exception 'ASM1-5: only the named assessor confirms a record someone else entered' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_assessment_confirmation() from public, anon, authenticated;
drop trigger if exists assessment_confirmations_guard on public.assessment_confirmations;
create trigger assessment_confirmations_guard
  before insert on public.assessment_confirmations
  for each row execute function private.guard_assessment_confirmation();
drop trigger if exists assessment_confirmations_no_update_delete on public.assessment_confirmations;
create trigger assessment_confirmations_no_update_delete
  before update or delete on public.assessment_confirmations
  for each row execute function private.forbid_audit_change();
drop trigger if exists assessment_confirmations_no_truncate on public.assessment_confirmations;
create trigger assessment_confirmations_no_truncate
  before truncate on public.assessment_confirmations
  for each statement execute function private.forbid_audit_change();
drop trigger if exists audit_assessment_confirmations on public.assessment_confirmations;
create trigger audit_assessment_confirmations
  after insert on public.assessment_confirmations
  for each row execute function private.write_audit_event('record_id');

-- 4. Current record and chain head -------------------------------------------------------------------------------------
-- The current assessment of a case: the non-superseded record with the latest assessment date (then the latest entry).
create or replace function private.current_assessment(p_case uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select r.id from public.assessment_records r
  where r.case_id = p_case
    and not exists (select 1 from public.assessment_records s where s.supersedes_id = r.id)
  order by r.assessment_date desc, r.created_at desc, r.id desc
  limit 1
$$;

-- The current version of a record: follow its supersedes to the end.
create or replace function private.assessment_head(p_record uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  with recursive chain(id, depth) as (
    select p_record, 0
    union all
    select s.id, ch.depth + 1 from chain ch join public.assessment_records s on s.supersedes_id = ch.id
    where ch.depth < 1000
  )
  select id from chain order by depth desc limit 1
$$;

create or replace function private.assessment_confirmed(p_record uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select r.entered_by = r.assessor_id
      or exists (select 1 from public.assessment_confirmations k where k.record_id = r.id)
  from public.assessment_records r where r.id = p_record
$$;
revoke all on function private.current_assessment(uuid), private.assessment_head(uuid),
  private.assessment_confirmed(uuid) from public, anon, authenticated;

-- 5. ASM1-7 the care plan item is written against the current assessment --------------------------------------------------
alter table public.care_plan_items add column if not exists assessment_id uuid references public.assessment_records (id);
comment on column public.care_plan_items.assessment_id is
  'ASM1-7 (ADR-123): the case''s current assessment when the item was written (set by trigger on insert; null: written '
  'before any assessment record). Display only: nothing is blocked or derived.';
-- 0099 (RLS4) keeps every non-act column of this table selectable; the new column follows that list.
grant select (assessment_id) on public.care_plan_items to authenticated;

create or replace function private.set_care_plan_item_assessment()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.assessment_id := private.current_assessment(new.case_id);
  return new;
end;
$$;
revoke all on function private.set_care_plan_item_assessment() from public, anon, authenticated;
drop trigger if exists care_plan_items_assessment on public.care_plan_items;
create trigger care_plan_items_assessment
  before insert on public.care_plan_items
  for each row execute function private.set_care_plan_item_assessment();

drop trigger if exists audit_care_plan_items on public.care_plan_items;
create trigger audit_care_plan_items
  after insert or update on public.care_plan_items
  for each row execute function private.write_audit_event('category', 'planned_minutes', 'review_date', 'active', 'assessment_id');

-- 6. AUD1-1 value catalogue: every audited key of the new columns is a code (ids, dates, numbers, flags).
insert into private.audit_value_classes (table_name, key, class) values
  ('assessment_instruments',   'valid_from',       'code'),
  ('assessment_instruments',   'valid_to',         'code'),
  ('assessment_instruments',   'third_party_mark', 'code'),
  ('assessment_records',       'case_id',          'code'),
  ('assessment_records',       'assessment_date',  'code'),
  ('assessment_records',       'instrument_id',    'code'),
  ('assessment_records',       'assessor_id',      'code'),
  ('assessment_records',       'minutes_a',        'code'),
  ('assessment_records',       'minutes_b',        'code'),
  ('assessment_records',       'minutes_c',        'code'),
  ('assessment_records',       'supersedes_id',    'code'),
  ('assessment_confirmations', 'record_id',        'code'),
  ('care_plan_items',          'assessment_id',    'code')
on conflict (table_name, key) do nothing;

-- 7. Commands ------------------------------------------------------------------------------------------------------------
-- Return jsonb {"result": "ok"|"duplicate"|"rejected", "reason": code?, "record_id": uuid?, "state": text?}.
-- Reasons: not_team_member, date_in_future, instrument_not_valid, assessor_not_rn, reference_invalid,
-- reference_required, period_required, minutes_invalid, supersede_not_found, already_superseded, reason_required.
create or replace function public.record_assessment(
  p_case_id uuid, p_assessment_date date, p_instrument_id uuid, p_assessor_id uuid, p_document_ref text,
  p_minutes_a integer, p_period_a text, p_minutes_b integer, p_period_b text, p_minutes_c integer, p_period_c text,
  p_supersedes_id uuid, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  c    public.cases%rowtype;
  ref  text := nullif(btrim(p_document_ref), '');
  pa   text := nullif(btrim(p_period_a), '');
  pb   text := nullif(btrim(p_period_b), '');
  pc   text := nullif(btrim(p_period_c), '');
  why  text := nullif(btrim(p_reason), '');
  s    public.assessment_records%rowtype;
  rid  uuid;
  rej  text;
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if private.begin_command('record_assessment', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;

  select * into c from public.cases where id = p_case_id for update;
  if not found or c.assigned_team_id is null
     or not private.is_org_member(c.organization_id) or not private.is_team_member(c.assigned_team_id) then
    rej := 'not_team_member';
  elsif p_assessment_date is null or p_assessment_date > private.at_zurich(private.now())::date then
    rej := 'date_in_future';
  elsif not exists (select 1 from public.assessment_instruments i
                    where i.id = p_instrument_id and i.organization_id = c.organization_id
                      and i.valid_from <= p_assessment_date
                      and (i.valid_to is null or i.valid_to >= p_assessment_date)) then
    rej := 'instrument_not_valid';
  elsif p_assessor_id is null or not private.is_registered_nurse(c.assigned_team_id, p_assessor_id)
        or private.access_ended(p_assessor_id) then
    rej := 'assessor_not_rn';
  elsif ref is not null and not (ref ~ '^[A-Za-z0-9][A-Za-z0-9_:#-]{2,63}$' and ref ~ '[0-9]') then
    rej := 'reference_invalid';
  elsif coalesce(p_minutes_a, p_minutes_b, p_minutes_c) is not null and ref is null then
    rej := 'reference_required';
  elsif (p_minutes_a is null) <> (pa is null) or (p_minutes_b is null) <> (pb is null)
        or (p_minutes_c is null) <> (pc is null) then
    rej := 'period_required';
  elsif coalesce(p_minutes_a, 0) not between 0 and 99999 or coalesce(p_minutes_b, 0) not between 0 and 99999
        or coalesce(p_minutes_c, 0) not between 0 and 99999
        or char_length(coalesce(pa, '')) > 60 or char_length(coalesce(pb, '')) > 60 or char_length(coalesce(pc, '')) > 60 then
    rej := 'minutes_invalid';
  elsif p_supersedes_id is not null then
    select * into s from public.assessment_records where id = p_supersedes_id;
    if not found or s.case_id <> c.id then
      rej := 'supersede_not_found';
    elsif exists (select 1 from public.assessment_records x where x.supersedes_id = s.id) then
      rej := 'already_superseded';
    elsif why is null or char_length(why) not between 10 and 500 then
      rej := 'reason_required';
    end if;
  elsif why is not null then
    rej := 'reason_required';   -- a reason belongs to a supersede only
  end if;
  if rej is not null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', rej);
  end if;

  insert into public.assessment_records
    (organization_id, case_id, team_id, assessment_date, instrument_id, assessor_id, document_ref,
     minutes_a, period_a, minutes_b, period_b, minutes_c, period_c, supersedes_id, supersede_reason, entered_by)
  values
    (c.organization_id, c.id, c.assigned_team_id, p_assessment_date, p_instrument_id, p_assessor_id, ref,
     p_minutes_a, pa, p_minutes_b, pb, p_minutes_c, pc, p_supersedes_id, why, uid)
  returning id into rid;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'record_id', rid,
                            'state', case when uid = p_assessor_id then 'confirmed' else 'unconfirmed' end);
end;
$$;

-- Reasons: not_assessor (also: not visible), already_confirmed, superseded.
create or replace function public.confirm_assessment(p_record_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.assessment_records%rowtype;
  rej text;
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_assessor');
  end if;
  if private.begin_command('confirm_assessment', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into r from public.assessment_records where id = p_record_id;
  if not found or r.assessor_id <> uid or not private.is_org_member(r.organization_id)
     or not private.reads_case(r.case_id) then
    rej := 'not_assessor';
  elsif private.assessment_confirmed(r.id) then
    rej := 'already_confirmed';
  elsif exists (select 1 from public.assessment_records s where s.supersedes_id = r.id) then
    rej := 'superseded';
  end if;
  if rej is not null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', rej);
  end if;
  insert into public.assessment_confirmations (organization_id, record_id, confirmed_by) values (r.organization_id, r.id, uid);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'record_id', r.id, 'state', 'confirmed');
end;
$$;

-- ASM1-6 list maintenance: administrators of the organisation. Reasons: not_admin, invalid, records_after_end.
create or replace function public.add_assessment_instrument(
  p_organization_id uuid, p_name text, p_version text, p_valid_from date, p_valid_to date, p_third_party_mark boolean,
  p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  iid uuid;
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_admin');
  end if;
  if private.begin_command('add_assessment_instrument', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  if not private.has_org_role(p_organization_id, array['admin']) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_admin');
  end if;
  if p_valid_from is null or (p_valid_to is not null and p_valid_to < p_valid_from)
     or char_length(btrim(coalesce(p_name, ''))) not between 2 and 120
     or char_length(btrim(coalesce(p_version, ''))) not between 1 and 40 then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'invalid');
  end if;
  insert into public.assessment_instruments (organization_id, name, version, valid_from, valid_to, third_party_mark, created_by)
  values (p_organization_id, btrim(p_name), btrim(p_version), p_valid_from, p_valid_to, coalesce(p_third_party_mark, false), uid)
  on conflict (organization_id, name, version, valid_from) do nothing
  returning id into iid;
  if iid is null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'invalid');
  end if;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'instrument_id', iid);
end;
$$;

create or replace function public.end_assessment_instrument(p_instrument_id uuid, p_valid_to date, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  i   public.assessment_instruments%rowtype;
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_admin');
  end if;
  if private.begin_command('end_assessment_instrument', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into i from public.assessment_instruments where id = p_instrument_id for update;
  if not found or not private.has_org_role(i.organization_id, array['admin']) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_admin');
  end if;
  if p_valid_to is null or p_valid_to < i.valid_from then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'invalid');
  end if;
  if exists (select 1 from public.assessment_records r where r.instrument_id = i.id and r.assessment_date > p_valid_to) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'records_after_end');
  end if;
  update public.assessment_instruments set valid_to = p_valid_to, ended_by = uid, ended_at = private.now() where id = i.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'instrument_id', i.id);
end;
$$;

-- 8. Reader (ASM1-7, ASM1-9, ASM1-10, ASM1-11) ---------------------------------------------------------------------------
-- Per case of the caller's teams (RLS2 reads_case): the records with their state, the plan basis, the marker date and the
-- dated facts younger than the current assessment. Per record only (D-23 term b): no list, count or filter per person.
create or replace function public.team_case_assessments()
returns table (case_id uuid, records jsonb, current_id uuid, plan_basis_date date, plan_without_basis boolean,
               newer_assessment_date date, newer_events jsonb)
language sql stable security definer set search_path = ''
as $$
  with my_cases as (
    select c.id, c.organization_id from public.cases c
    where c.assigned_team_id is not null
      and private.is_org_member(c.organization_id) and private.is_team_member(c.assigned_team_id)
      and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  ),
  cur as (
    select mc.id as case_id, mc.organization_id, private.current_assessment(mc.id) as current_id from my_cases mc
  ),
  basis as (
    select i.case_id,
           min(h.assessment_date) as basis_date,
           bool_or(i.assessment_id is null) as without_basis,
           count(*) as items
    from public.care_plan_items i
    join cur on cur.case_id = i.case_id
    left join lateral (select r.assessment_date from public.assessment_records r
                       where r.id = private.assessment_head(i.assessment_id)) h on i.assessment_id is not null
    where i.active
    group by i.case_id
  )
  select cur.case_id,
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'id', r.id,
                    'assessment_date', r.assessment_date,
                    'instrument_name', ins.name,
                    'instrument_version', ins.version,
                    'instrument_third_party_mark', ins.third_party_mark,
                    'assessor_name', private.member_name(r.organization_id, r.assessor_id),
                    'assessor_is_me', r.assessor_id = (select auth.uid()),
                    'state', case when private.assessment_confirmed(r.id) then 'confirmed' else 'unconfirmed' end,
                    'document_ref', r.document_ref,
                    'minutes_a', r.minutes_a, 'period_a', r.period_a,
                    'minutes_b', r.minutes_b, 'period_b', r.period_b,
                    'minutes_c', r.minutes_c, 'period_c', r.period_c,
                    'supersedes_id', r.supersedes_id,
                    'superseded_by', (select s.id from public.assessment_records s where s.supersedes_id = r.id),
                    'supersede_reason', r.supersede_reason,
                    'current', r.id = cur.current_id,
                    'created_at', r.created_at)
                  order by r.assessment_date desc, r.created_at desc)
           from public.assessment_records r
           join public.assessment_instruments ins on ins.id = r.instrument_id
           where r.case_id = cur.case_id), '[]'::jsonb),
         cur.current_id,
         b.basis_date,
         coalesce(b.without_basis, false),
         case when cur.current_id is not null and b.items > 0
                   and (b.without_basis or ca.assessment_date > b.basis_date)
              then ca.assessment_date end,
         case when cur.current_id is null then '[]'::jsonb else coalesce((
           select jsonb_agg(jsonb_build_object('kind', e.kind, 'date', e.d) order by e.d desc, e.kind)
           from (
             select x.kind, max(x.d) as d from (
               select case when l.kind = 'resume' then 'resume' else 'hospital_stay' end as kind,
                      private.at_zurich(l.created_at)::date as d
               from public.case_lifecycle_events l
               where l.case_id = cur.case_id
                 and (l.kind = 'resume' or (l.kind = 'pause' and l.reason_code = 'hospital_stay'))
               union all
               select 'serious_quality_event', private.at_zurich(coalesce(q.occurred_at, q.created_at))::date
               from public.quality_events q
               where q.case_id = cur.case_id and private.is_serious(q.severity)
             ) x
             where x.d > ca.assessment_date
             group by x.kind
           ) e), '[]'::jsonb) end
  from cur
  left join basis b on b.case_id = cur.case_id
  left join public.assessment_records ca on ca.id = cur.current_id;
$$;
comment on function public.team_case_assessments() is
  'ASM1-7/-9/-10/-11 (ADR-123): per case of the caller''s teams the assessment records (state, superseded marks), the '
  'care plan''s basis date, the "Neuere Bedarfsabklärung" date and the dated facts younger than the current assessment. '
  'Members of the assigned team only; never a list, count or filter per person. Nothing is computed from the minutes.';

revoke all on function
  public.record_assessment(uuid, date, uuid, uuid, text, integer, text, integer, text, integer, text, uuid, text, uuid),
  public.confirm_assessment(uuid, uuid),
  public.add_assessment_instrument(uuid, text, text, date, date, boolean, uuid),
  public.end_assessment_instrument(uuid, date, uuid),
  public.team_case_assessments()
from public, anon;
grant execute on function
  public.record_assessment(uuid, date, uuid, uuid, text, integer, text, integer, text, integer, text, uuid, text, uuid),
  public.confirm_assessment(uuid, uuid),
  public.add_assessment_instrument(uuid, text, text, date, date, boolean, uuid),
  public.end_assessment_instrument(uuid, date, uuid),
  public.team_case_assessments()
to authenticated;
