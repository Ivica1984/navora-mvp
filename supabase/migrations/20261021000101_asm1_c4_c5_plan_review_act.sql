-- ASM1-C4 and ASM1-C5 (ADR-125): one review act re-bases the care plan on the current assessment, and a corrected
-- basis is visible on the plan. PO brief docs/agents/briefs/ASM1.md, decisions of 2026-10-30 09:15 (ASM1-C4, `aia`
-- AUT-26) and 10:15 (`changes-requested`; ASM1-C5 from `cra` CGR-102; `cra` 09:30 conditions (a)-(c) on ASM1-C4).
-- Synthetic data only (real-data gate unchanged: D-29, D-11/D-12).
--
-- No clinical, legal or tariff rule is made here. Who may record the act is the PO's provisional default (a registered
-- nurse of the case's team, the set ASM1-1 already uses); whether the act may rest on a record still "nicht bestätigt"
-- is the Clinical Owner's (after G-1), allowed until then because the state stays visible (`cra` (a)).
--
-- Before (IMPLEMENTED, 0100):
--   * `care_plan_items.assessment_id` is set on insert only; the plan's basis is the oldest head-of-chain date among the
--     active items' stored records. The marker "Neuere Bedarfsabklärung vom <Datum>" (and `plan_without_basis`) clears
--     only when every item is retired and typed again (ADR-123 deviation 2).
--   * A supersede of the record the plan rests on, with the same assessment date, leaves no marker: the basis line reads
--     the head's date (CGR-102).
-- Now (IMPLEMENTED in this migration):
--   1. ASM1-C4 `care_plan_assessment_reviews`: one append-only row per act: the case, the record it names, that record's
--      state at the act (`cra` (a)), the active items it covered, who and when. No care-plan item is inserted, retired or
--      updated: an update of `care_plan_items` would fire PLAN2's regeneration trigger (0025) and the GP and order
--      triggers (0061, 0063), so the act changes no item at all (`cra` (c)). An item's basis is the record of the latest
--      act that covered it, else the record stored on its insert (`private.plan_item_basis`).
--      Not selectable through the table by anyone (no grant, no policy); the reader returns the latest act per case with
--      the reviewer's name (per record only, RLS4 pattern). Never counted or listed per person.
--   2. `public.review_care_plan_against_assessment(case, record, key)`: a registered nurse of the case's team (access not
--      ended) records the act against the case's current non-superseded record, while the marker, `plan_without_basis`
--      or the ASM1-C5 fact shows. Reasons: not_team_member, not_rn, not_current, no_items, nothing_to_review.
--   3. ASM1-C5: the reader also returns, per case, the stored basis whose record was superseded since (`corrected_basis_date`,
--      the stored record's assessment date) and the entry date of its correction (`corrected_on`, Zurich date of the
--      head's entry). The act clears it (the act stores the current record, which is a head).
--   4. `public.team_case_assessments()` is recreated with the item basis of (1), the ASM1-C5 columns and `plan_review`
--      (the case's latest act: record, its assessment date, the state at the act, date, reviewer's name). The rest of
--      its output is unchanged. Reads unchanged: members of the case's assigned team only (RLS2 `private.reads_case`).
-- Nothing is summed, compared beyond two dates or record identities, coloured or blocked; no due date, reminder or signal
-- (ASM1 negative). J3 planning, PLAN2 generation, visit minutes and J5 billing read nothing of this (pgTAP 101 hashes).
-- Idempotent: `create table if not exists`, `create or replace`, `drop ... if exists`, `on conflict do nothing`.

-- 1. The act --------------------------------------------------------------------------------------------------------------
create table if not exists public.care_plan_assessment_reviews (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  organization_id uuid not null references public.organizations (id),
  case_id         uuid not null,
  record_id       uuid not null references public.assessment_records (id),
  record_state    text not null check (record_state in ('confirmed', 'unconfirmed')),
  item_ids        uuid[] not null check (cardinality(item_ids) >= 1),
  reviewed_by     uuid not null,
  reviewed_at     timestamptz not null default private.now(),
  foreign key (case_id, organization_id) references public.cases (id, organization_id)
);
create index if not exists care_plan_assessment_reviews_case_idx on public.care_plan_assessment_reviews (case_id, seq);
comment on table public.care_plan_assessment_reviews is
  'ASM1-C4 (ADR-125, AUT-26): the team''s act "Pflegeplan gegen Bedarfsabklärung vom <Datum> geprüft". Append-only; '
  'stores the record named, its state at the act, the active items covered, who and when. Changes no care-plan item. '
  'Not selectable through the table; read per case through team_case_assessments (plan_review). Never counted per person.';

alter table public.care_plan_assessment_reviews enable row level security;
revoke all on public.care_plan_assessment_reviews from anon, authenticated;
-- No grant and no policy: the table is read only through public.team_case_assessments() (SECURITY DEFINER).

drop trigger if exists care_plan_assessment_reviews_no_update_delete on public.care_plan_assessment_reviews;
create trigger care_plan_assessment_reviews_no_update_delete
  before update or delete on public.care_plan_assessment_reviews
  for each row execute function private.forbid_audit_change();
drop trigger if exists care_plan_assessment_reviews_no_truncate on public.care_plan_assessment_reviews;
create trigger care_plan_assessment_reviews_no_truncate
  before truncate on public.care_plan_assessment_reviews
  for each statement execute function private.forbid_audit_change();
drop trigger if exists audit_care_plan_assessment_reviews on public.care_plan_assessment_reviews;
create trigger audit_care_plan_assessment_reviews
  after insert on public.care_plan_assessment_reviews
  for each row execute function private.write_audit_event('case_id', 'record_id', 'record_state');

insert into private.audit_value_classes (table_name, key, class) values
  ('care_plan_assessment_reviews', 'case_id',      'code'),
  ('care_plan_assessment_reviews', 'record_id',    'code'),
  ('care_plan_assessment_reviews', 'record_state', 'code')
on conflict (table_name, key) do nothing;

-- 2. An item's basis: the record of the latest act that covered it, else the record stored on its insert ----------------------
create or replace function private.plan_item_basis(p_item uuid, p_stored uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select coalesce((select v.record_id from public.care_plan_assessment_reviews v
                   where p_item = any (v.item_ids)
                   order by v.seq desc limit 1), p_stored)
$$;
revoke all on function private.plan_item_basis(uuid, uuid) from public, anon, authenticated;

-- Per case: the active items with their basis and that basis's head (shared by the reader and the command).
create or replace function private.plan_item_bases(p_case uuid)
returns table (item_id uuid, basis_id uuid, head_id uuid)
language sql stable security definer set search_path = ''
as $$
  select i.id, b.id, case when b.id is null then null else private.assessment_head(b.id) end
  from public.care_plan_items i
  cross join lateral (select private.plan_item_basis(i.id, i.assessment_id) as id) b
  where i.case_id = p_case and i.active
$$;
revoke all on function private.plan_item_bases(uuid) from public, anon, authenticated;

-- 3. The command ------------------------------------------------------------------------------------------------------------
-- Returns jsonb {"result": "ok"|"duplicate"|"rejected", "reason": code?, "review_id": uuid?}.
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
    rej := 'not_current';
  else
    select * into r from public.assessment_records where id = p_record_id;
    select array_agg(b.item_id order by b.item_id) into items from private.plan_item_bases(c.id) b;
    if items is null then
      rej := 'no_items';
    elsif not exists (select 1 from private.plan_item_bases(c.id) b
                      left join public.assessment_records h on h.id = b.head_id
                      where b.basis_id is null                 -- written before any record
                         or b.basis_id <> b.head_id            -- ASM1-C5: the basis was corrected since
                         or h.assessment_date < r.assessment_date) then  -- ASM1-7: a newer assessment exists
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
comment on function public.review_care_plan_against_assessment(uuid, uuid, uuid) is
  'ASM1-C4 (ADR-125): "Pflegeplan gegen Bedarfsabklärung vom <Datum> geprüft". A registered nurse of the case''s team '
  '(provisional, PO 2026-10-30 09:15) re-bases the active items on the current record; no item is changed.';

-- 4. Reader -------------------------------------------------------------------------------------------------------------------
-- The return type changes (ASM1-C5 and plan_review columns), so the function is dropped and created again.
drop function if exists public.team_case_assessments();
create function public.team_case_assessments()
returns table (case_id uuid, records jsonb, current_id uuid, plan_basis_date date, plan_without_basis boolean,
               newer_assessment_date date, newer_events jsonb, corrected_basis_date date, corrected_on date,
               plan_review jsonb)
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
    select cur.case_id, b.item_id, b.basis_id, b.head_id
    from cur cross join lateral private.plan_item_bases(cur.case_id) b
  ),
  basis as (
    select bs.case_id,
           min(h.assessment_date) as basis_date,
           bool_or(bs.basis_id is null) as without_basis,
           count(*) as items
    from bases bs
    left join public.assessment_records h on h.id = bs.head_id
    group by bs.case_id
  ),
  -- ASM1-C5 (CGR-102): an active item's basis was superseded since; the oldest such basis and its correction's entry date.
  corrected as (
    select distinct on (bs.case_id) bs.case_id, s.assessment_date as stored_date,
           private.at_zurich(h.created_at)::date as corrected_on
    from bases bs
    join public.assessment_records s on s.id = bs.basis_id
    join public.assessment_records h on h.id = bs.head_id
    where bs.basis_id <> bs.head_id
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
           ) e), '[]'::jsonb) end,
         co.stored_date,
         co.corrected_on,
         case when lr.case_id is null then null else jsonb_build_object(
           'record_id', lr.record_id,
           'assessment_date', (select r.assessment_date from public.assessment_records r where r.id = lr.record_id),
           'state_at_review', lr.record_state,
           'reviewed_on', private.at_zurich(lr.reviewed_at)::date,
           'reviewer_name', private.member_name(lr.organization_id, lr.reviewed_by)) end
  from cur
  left join basis b on b.case_id = cur.case_id
  left join corrected co on co.case_id = cur.case_id
  left join last_review lr on lr.case_id = cur.case_id
  left join public.assessment_records ca on ca.id = cur.current_id;
$$;
comment on function public.team_case_assessments() is
  'ASM1-7/-9/-10/-11, ASM1-C4/-C5 (ADR-123, ADR-125): per case of the caller''s teams the assessment records (state, '
  'superseded marks), the care plan''s basis date, the "Neuere Bedarfsabklärung" date, the dated facts younger than the '
  'current assessment, a corrected basis and the latest review act. Members of the assigned team only; never a list, '
  'count or filter per person. Nothing is computed from the minutes.';

revoke all on function
  public.review_care_plan_against_assessment(uuid, uuid, uuid),
  public.team_case_assessments()
from public, anon;
grant execute on function
  public.review_care_plan_against_assessment(uuid, uuid, uuid),
  public.team_case_assessments()
to authenticated;
