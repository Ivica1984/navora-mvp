-- ASM1-C6 with C6 (8) (ADR-140): "Irrtümlich erfasst" as an append-only void act per assessment record, with the P-37
-- preset reason, and the care plan's basis read by identity, not by date. PO brief docs/agents/briefs/ASM1.md, decisions
-- of 2026-10-30 10:15 (C6 from `cra` CGR-103; `lca` 09:40 (a)-(c)), 11:10, 13:28 (wording, hint, output rule),
-- 15:00 (C6 (8) from `cra` CGR-104), 15:55 (basis head = effective basis; act then void), 18:25 (P-37 in force with the
-- `cra` supersede sentence; no review act without a current record). `uxa` 2026-10-30 15:50 wording.
-- Synthetic data only. Deadline of the condition: before the first real assessment record (ASM1 real-data gate).
--
-- No clinical, legal or tariff rule is made here. Who may void is the PO's provisional default (a registered nurse of
-- the case's team, the set ASM1-1 and ASM1-C4 use); whether a void needs the named assessor's confirmation is the
-- Clinical Owner's (after G-1), UNKNOWN, not required until then. Whether misfiled content stays in the wrong client's
-- record is the legal adviser's (D-4 item 7, UNKNOWN); the protective form (fields withheld, nothing deleted) holds.
-- Whether a case may hold two records of one date that do not replace each other is the Clinical Owner's (UNKNOWN);
-- NAVORA adds no refusal for it; the identity rule below protects either way.
--
-- Before (IMPLEMENTED, 0100/0101):
--   * A record can only be superseded; a record entered in the wrong case stays a basis candidate and its minutes,
--     periods, instrument and reference are read by the team (table and reader).
--   * The "Neuere Bedarfsabklärung" marker compares dates only: a same-date parallel record leaves the plan resting on
--     a record that is not current with no marker and no act (`nothing_to_review`) (CGR-104).
-- Now (IMPLEMENTED in this migration):
--   1. `assessment_voids`: one append-only row per voided record: reason kind (`wrong_client` | `other`), the reason text
--      as shown (the preset text for `wrong_client`, 10..500 characters for `other`), who, when. No update, delete or
--      truncate for any role; audited (record and kind; the free text is not copied into the audit trail, as the
--      supersede reason is not). Not selectable through the table (RLS4 pattern); read per case through the reader.
--   2. Only a record that is not superseded is voided (its chain's head); a voided record is never superseded,
--      confirmed or current again. `private.assessment_withheld(record)`: the record's chain head is voided. A withheld
--      record (the voided head and every record it superseded) is not selectable through `assessment_records` and its
--      fields are not returned by the reader (C6 (3), (7) output rule).
--   3. `private.current_assessment` skips voided records: the current record falls back to the next non-superseded,
--      non-voided one or none. New care-plan items are never written against a voided record (0100 insert trigger).
--   4. `public.void_assessment(record, kind, reason, key)`. Reasons: not_team_member, not_rn, already_voided, superseded,
--      reason_kind_invalid, reason_required.
--   5. `record_assessment` refuses a supersede of a voided record (`voided`); `confirm_assessment` refuses a voided
--      record (`voided`). Everything else in both commands is unchanged.
--   6. C6 (8): `review_care_plan_against_assessment` is offered whenever an active item's effective basis
--      (`private.plan_item_basis`, po 15:55 deviation 4) is not the current record (newer, same-date parallel, voided
--      head) or was corrected (C5) or is missing; with no current record it keeps refusing `not_current` (0101:131).
--   7. `public.team_case_assessments()` is recreated (return type changes): `records` lists only records that are not
--      withheld; `voided_records` lists each voided record as the void only (id, void date, who, reason, whether it
--      names the caller); `basis_fact` = `voided` | `not_current` | null; `plan_basis_date` and the C5 columns never
--      come from a withheld record; `plan_review` names no date of a withheld record (`record_voided`). The rest of its
--      output is unchanged.
-- Nothing is summed, coloured or blocked; no due date, reminder or signal (ASM1 negative). J3 planning, PLAN2
-- generation, visit minutes and J5 billing read nothing of this (pgTAP 107 hashes).
-- Idempotent: `create table if not exists`, `create or replace`, `drop ... if exists`, `on conflict do nothing`.

-- 1. The void act ---------------------------------------------------------------------------------------------------------------
create table if not exists public.assessment_voids (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  record_id       uuid not null unique references public.assessment_records (id),
  reason_kind     text not null check (reason_kind in ('wrong_client', 'other')),
  reason          text not null check (char_length(btrim(reason)) between 10 and 500),
  voided_by       uuid not null,
  voided_at       timestamptz not null default private.now(),
  -- P-37 (lca 13:42 (b)): the stored reason of the preset is its text as shown. A changed preset text gets a new kind.
  constraint assessment_void_preset_text check (
    reason_kind <> 'wrong_client' or reason = 'Falsche Klientin oder falscher Klient gewählt')
);
comment on table public.assessment_voids is
  'ASM1-C6 (ADR-140, cra CGR-103): "Irrtümlich erfasst". One append-only act per record: reason kind, reason as shown, '
  'who, when. The record stays (update and delete refused) and its fields are withheld from every team read path. '
  'Not selectable through the table; read per case through team_case_assessments (voided_records).';
comment on column public.assessment_voids.reason is
  'ASM1-C6 (4) / P-37: the preset text exactly as shown (wrong_client), or the free text 10..500 characters (other). '
  'Hint, not enforced: no other person named.';

alter table public.assessment_voids enable row level security;
revoke all on public.assessment_voids from anon, authenticated;
-- No grant and no policy: the table is read only through public.team_case_assessments() (SECURITY DEFINER).

drop trigger if exists assessment_voids_no_update_delete on public.assessment_voids;
create trigger assessment_voids_no_update_delete
  before update or delete on public.assessment_voids
  for each row execute function private.forbid_audit_change();
drop trigger if exists assessment_voids_no_truncate on public.assessment_voids;
create trigger assessment_voids_no_truncate
  before truncate on public.assessment_voids
  for each statement execute function private.forbid_audit_change();
drop trigger if exists audit_assessment_voids on public.assessment_voids;
create trigger audit_assessment_voids
  after insert on public.assessment_voids
  for each row execute function private.write_audit_event('record_id', 'reason_kind');

insert into private.audit_value_classes (table_name, key, class) values
  ('assessment_voids', 'record_id',   'code'),
  ('assessment_voids', 'reason_kind', 'code')
on conflict (table_name, key) do nothing;

-- 2. Helpers ----------------------------------------------------------------------------------------------------------------------
create or replace function private.assessment_voided(p_record uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.assessment_voids v where v.record_id = p_record)
$$;

-- A record whose chain head is voided: the voided record and every record it superseded (one wrong entry, corrected).
create or replace function private.assessment_withheld(p_record uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_record is not null and private.assessment_voided(private.assessment_head(p_record))
$$;
revoke all on function private.assessment_voided(uuid), private.assessment_withheld(uuid) from public, anon, authenticated;
-- The read policy of assessment_records (section 3) calls it as the invoker (RLS2 pattern: reads_case). It returns one
-- boolean per record id the caller already names; no field.
grant execute on function private.assessment_withheld(uuid) to authenticated;

-- Integrity on every write path (the command returns the same conditions as reasons first).
create or replace function private.guard_assessment_void()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  r public.assessment_records%rowtype;
  c public.cases%rowtype;
begin
  select * into r from public.assessment_records where id = new.record_id;
  if not found or r.organization_id <> new.organization_id then
    raise exception 'ASM1-C6: the void names a record of its organisation' using errcode = '23514';
  end if;
  if exists (select 1 from public.assessment_records s where s.supersedes_id = r.id) then
    raise exception 'ASM1-C6: a superseded record is not voided; its current version is' using errcode = '23514';
  end if;
  select * into c from public.cases where id = r.case_id;
  if c.assigned_team_id is null or not private.is_registered_nurse(c.assigned_team_id, new.voided_by)
     or private.access_ended(new.voided_by) then
    raise exception 'ASM1-C6 (6): a registered nurse of the case''s team voids a record' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_assessment_void() from public, anon, authenticated;
drop trigger if exists assessment_voids_guard on public.assessment_voids;
create trigger assessment_voids_guard
  before insert on public.assessment_voids
  for each row execute function private.guard_assessment_void();

-- A voided record is never superseded (also outside the command).
create or replace function private.guard_assessment_record_not_voided()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.supersedes_id is not null and private.assessment_voided(new.supersedes_id) then
    raise exception 'ASM1-C6: a voided record is not superseded' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_assessment_record_not_voided() from public, anon, authenticated;
drop trigger if exists assessment_records_not_voided on public.assessment_records;
create trigger assessment_records_not_voided
  before insert on public.assessment_records
  for each row execute function private.guard_assessment_record_not_voided();

-- 3. The current record skips voided records ------------------------------------------------------------------------------------
create or replace function private.current_assessment(p_case uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select r.id from public.assessment_records r
  where r.case_id = p_case
    and not exists (select 1 from public.assessment_records s where s.supersedes_id = r.id)
    and not exists (select 1 from public.assessment_voids v where v.record_id = r.id)   -- ASM1-C6 (1)
  order by r.assessment_date desc, r.created_at desc, r.id desc
  limit 1
$$;
revoke all on function private.current_assessment(uuid) from public, anon, authenticated;

-- ASM1-C6 (7) output rule: a withheld record is not selectable through the table (no minutes, period, instrument, reference).
drop policy if exists case_team_read on public.assessment_records;
create policy case_team_read on public.assessment_records
  for select to authenticated
  using (private.is_org_member(organization_id) and private.reads_case(case_id) and not private.assessment_withheld(id));

-- 4. The void command ----------------------------------------------------------------------------------------------------------
-- Returns jsonb {"result": "ok"|"duplicate"|"rejected", "reason": code?, "void_id": uuid?}.
create or replace function public.void_assessment(p_record_id uuid, p_reason_kind text, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  r      public.assessment_records%rowtype;
  c      public.cases%rowtype;
  why    text := nullif(btrim(p_reason), '');
  preset constant text := 'Falsche Klientin oder falscher Klient gewählt';
  vid    uuid;
  rej    text;
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if private.begin_command('void_assessment', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;

  select * into r from public.assessment_records where id = p_record_id;
  if found then
    -- the case row is locked so the fallback of the current record is decided once
    select * into c from public.cases where id = r.case_id for update;
  end if;
  if r.id is null or c.id is null or c.assigned_team_id is null
     or not private.is_org_member(c.organization_id) or not private.is_team_member(c.assigned_team_id)
     or private.access_ended(uid) then
    rej := 'not_team_member';
  elsif not private.is_registered_nurse(c.assigned_team_id, uid) then
    rej := 'not_rn';   -- provisional set (PO 2026-10-30 10:15, C6 (6)): a registered nurse of the case's team
  elsif private.assessment_voided(r.id) then
    rej := 'already_voided';
  elsif exists (select 1 from public.assessment_records s where s.supersedes_id = r.id) then
    rej := 'superseded';
  elsif p_reason_kind is null or p_reason_kind not in ('wrong_client', 'other')
        or (p_reason_kind = 'wrong_client' and why is not null) then
    rej := 'reason_kind_invalid';   -- P-37: two choices; the preset carries no free text
  elsif p_reason_kind = 'other' and (why is null or char_length(why) not between 10 and 500) then
    rej := 'reason_required';
  end if;
  if rej is not null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', rej);
  end if;

  insert into public.assessment_voids (organization_id, record_id, reason_kind, reason, voided_by)
  values (r.organization_id, r.id, p_reason_kind, case when p_reason_kind = 'wrong_client' then preset else why end, uid)
  returning id into vid;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'void_id', vid);
end;
$$;
comment on function public.void_assessment(uuid, text, text, uuid) is
  'ASM1-C6 (ADR-140): "Irrtümlich erfasst". A registered nurse of the case''s team (provisional) voids a record that is '
  'not superseded; the record stays, is never current again, and its fields are withheld from the team.';

-- 5. record_assessment and confirm_assessment: a voided record is not superseded or confirmed (rest unchanged, 0100) ----------------
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
  elsif p_assessment_date is null or p_assessment_date > (private.at_zurich(private.now()))::date then
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
    elsif private.assessment_voided(s.id) then
      rej := 'voided';   -- ASM1-C6: a voided record is not superseded
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
  elsif private.assessment_withheld(r.id) then
    rej := 'voided';   -- ASM1-C6 (5): a voided record (or one it superseded) is not confirmed
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

-- 6. The review act: offered whenever an item's effective basis is not the current record (C6 (8) (iv)) -----------------------
create or replace function public.review_care_plan_against_assessment(p_case_id uuid, p_record_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  c     public.cases%rowtype;
  r     public.assessment_records%rowtype;
  items uuid[];
  rid   uuid;
  rej   text;
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if private.begin_command('review_care_plan_against_assessment', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;

  select * into c from public.cases where id = p_case_id for update;
  if not found or c.assigned_team_id is null
     or not private.is_org_member(c.organization_id) or not private.is_team_member(c.assigned_team_id)
     or private.access_ended(uid) then
    rej := 'not_team_member';
  elsif not private.is_registered_nurse(c.assigned_team_id, uid) then
    rej := 'not_rn';   -- provisional set (PO 2026-10-30 09:15): a registered nurse of the case's team
  elsif p_record_id is null or p_record_id is distinct from private.current_assessment(c.id) then
    rej := 'not_current';   -- also: no current record at all (po 2026-10-30 18:25: no review "against nothing")
  else
    select * into r from public.assessment_records where id = p_record_id;
    select array_agg(b.item_id order by b.item_id) into items from private.plan_item_bases(c.id) b;
    if items is null then
      rej := 'no_items';
    elsif not exists (select 1 from private.plan_item_bases(c.id) b
                      where b.basis_id is null              -- written before any record
                         or b.basis_id <> b.head_id         -- ASM1-C5: the basis was corrected since
                         or b.head_id <> r.id) then         -- ASM1-7 / C6 (8): newer, same-date parallel or voided head
      rej := 'nothing_to_review';
    end if;
  end if;
  if rej is not null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', rej);
  end if;

  insert into public.care_plan_assessment_reviews (organization_id, case_id, record_id, record_state, item_ids, reviewed_by)
  values (c.organization_id, c.id, r.id,
          case when private.assessment_confirmed(r.id) then 'confirmed' else 'unconfirmed' end, items, uid)
  returning id into rid;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'review_id', rid);
end;
$$;

-- 7. Reader ---------------------------------------------------------------------------------------------------------------------
drop function if exists public.team_case_assessments();
create function public.team_case_assessments()
returns table (case_id uuid, records jsonb, current_id uuid, plan_basis_date date, plan_without_basis boolean,
               newer_assessment_date date, newer_events jsonb, corrected_basis_date date, corrected_on date,
               plan_review jsonb, basis_fact text, voided_records jsonb)
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
  bases as (
    select cur.case_id, b.item_id, b.basis_id, b.head_id,
           (b.head_id is not null and private.assessment_voided(b.head_id)) as head_voided
    from cur cross join lateral private.plan_item_bases(cur.case_id) b
  ),
  basis as (
    select bs.case_id,
           -- C6 (8) (iii): never the date of a withheld record
           min(h.assessment_date) filter (where not bs.head_voided) as basis_date,
           bool_or(bs.basis_id is null) as without_basis,
           bool_or(bs.head_voided) as voided_basis,
           -- C6 (8) (i): a head that is not current and not older than the current record (same-date parallel, or none current)
           bool_or(bs.head_id is not null and not bs.head_voided and bs.head_id is distinct from cur.current_id
                   and (ca.id is null or h.assessment_date >= ca.assessment_date)) as parallel_basis,
           count(*) as items
    from bases bs
    join cur on cur.case_id = bs.case_id
    left join public.assessment_records h on h.id = bs.head_id
    left join public.assessment_records ca on ca.id = cur.current_id
    group by bs.case_id
  ),
  -- ASM1-C5 (CGR-102): an active item's basis was superseded since; never for a voided chain (C6 (8) sentence instead).
  corrected as (
    select distinct on (bs.case_id) bs.case_id, s.assessment_date as stored_date,
           private.at_zurich(h.created_at)::date as corrected_on
    from bases bs
    join public.assessment_records s on s.id = bs.basis_id
    join public.assessment_records h on h.id = bs.head_id
    where bs.basis_id <> bs.head_id and not bs.head_voided
    order by bs.case_id, s.assessment_date, h.created_at desc
  ),
  -- ASM1-C4: the case's latest act, read per case only.
  last_review as (
    select distinct on (v.case_id) v.case_id, v.record_id, v.record_state, v.reviewed_at, v.reviewed_by, v.organization_id
    from public.care_plan_assessment_reviews v
    join cur on cur.case_id = v.case_id
    order by v.case_id, v.seq desc
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
           where r.case_id = cur.case_id and not private.assessment_withheld(r.id)), '[]'::jsonb),
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
           ) e), '[]'::jsonb) end,
         co.stored_date,
         co.corrected_on,
         case when lr.case_id is null then null else jsonb_build_object(
           'record_id', lr.record_id,
           'assessment_date', case when private.assessment_withheld(lr.record_id) then null
                                   else (select r.assessment_date from public.assessment_records r where r.id = lr.record_id) end,
           'record_voided', private.assessment_withheld(lr.record_id),
           'state_at_review', lr.record_state,
           'reviewed_on', private.at_zurich(lr.reviewed_at)::date,
           'reviewer_name', private.member_name(lr.organization_id, lr.reviewed_by)) end,
         case when coalesce(b.voided_basis, false) then 'voided'
              when coalesce(b.parallel_basis, false) then 'not_current' end,
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'id', r.id,
                    'voided_on', private.at_zurich(v.voided_at)::date,
                    'voided_by_name', private.member_name(v.organization_id, v.voided_by),
                    'reason', v.reason,
                    'assessor_is_me', r.assessor_id = (select auth.uid()))
                  order by v.voided_at desc, r.id)
           from public.assessment_voids v
           join public.assessment_records r on r.id = v.record_id
           where r.case_id = cur.case_id), '[]'::jsonb)
  from cur
  left join basis b on b.case_id = cur.case_id
  left join corrected co on co.case_id = cur.case_id
  left join last_review lr on lr.case_id = cur.case_id
  left join public.assessment_records ca on ca.id = cur.current_id;
$$;
comment on function public.team_case_assessments() is
  'ASM1-7/-9/-10/-11, ASM1-C4/-C5/-C6 (ADR-123, ADR-125, ADR-140): per case of the caller''s teams the assessment records '
  'that are not withheld (state, superseded marks), the voided records as the void only, the care plan''s basis date, the '
  '"Neuere Bedarfsabklärung" date, the basis fact (voided / not current, by identity), the dated facts younger than the '
  'current assessment, a corrected basis and the latest review act. Members of the assigned team only; never a list, '
  'count or filter per person. Nothing is computed from the minutes; no field of a voided record is returned.';

revoke all on function
  public.void_assessment(uuid, text, text, uuid),
  public.record_assessment(uuid, date, uuid, uuid, text, integer, text, integer, text, integer, text, uuid, text, uuid),
  public.confirm_assessment(uuid, uuid),
  public.review_care_plan_against_assessment(uuid, uuid, uuid),
  public.team_case_assessments()
from public, anon;
grant execute on function
  public.void_assessment(uuid, text, text, uuid),
  public.record_assessment(uuid, date, uuid, uuid, text, integer, text, integer, text, integer, text, uuid, text, uuid),
  public.confirm_assessment(uuid, uuid),
  public.review_care_plan_against_assessment(uuid, uuid, uuid),
  public.team_case_assessments()
to authenticated;
