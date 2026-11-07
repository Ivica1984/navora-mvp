-- CSR1, sixth PR: J5's clinical-gate findings (Clinical Governance Report 2026-10-22 22:30, CGR-03 J5 part, CGR-07,
-- CGR-08; Architect section 23:05 and PO 2026-10-23 01:10, BL-8 and BL-9). ADR-054. Rule J5-v3.
--
-- CGR-03 (J5 part, blocking): billing read the LIVE visit times (private.visit_times / visit_care_minutes_exact over
--   visit_events + visit_time_corrections) and the live planned minutes of care_visits. Now every billing fact and every
--   working-time fact is computed from the SNAPSHOT of the final report version it belongs to (the facts the nurse
--   signed, 0016/0041): planned minutes per category and the event times. private.snapshot_times(snapshot) reads the
--   same events the snapshot shows, with the same arithmetic as visit_times (0022) and visit_care_minutes_exact (0023).
--   The fact records the snapshot hash (0041) it was built from. A correction goes only through a report correction
--   version (F6, 0040 lock); its signed snapshot yields a new fact that supersedes the old one.
-- CGR-07 (blocking): three new not-billable reasons; no tariff rule is added, the estimate is refused instead:
--   * order_validity_missing: the case's medical order is `present` without an end date (it was valid forever);
--   * order_expired: the order's end date is before the visit date, for A and C minutes too;
--   * payer_not_modelled: the case's insurance type is not KVG (IV, UV, MV, private, unknown or missing).
--   Existing reasons stay (a B visit without a valid order keeps b_without_valid_order as well).
-- CGR-08 (advisory, condition): tariff_rates and billing_rules carry `validated` (default false) and a
--   `validation_note`. The seeded rows (canton-sourced values seeded as federal CH) are marked unvalidated. A fact that
--   used an unvalidated rate or minimum carries the warning reference_not_validated, and billing_preview returns
--   `reference_validated` so /team and /operations show "nicht validiert". Re-seeding waits for D-11 and D-18.
-- BL-8 (advisory, condition): a fact never stays billable under a later hold. When a quality hold opens on a visit
--   whose latest fact is billable, a superseding fact (cause `quality_hold`, billable false, reason quality_hold) is
--   appended. When the visit's last open hold is lifted, the fact before the hold is appended again (cause
--   `hold_lifted`, billable as before). Every reader of the latest fact (J5 preview, AN1 billable minutes per care
--   minute, a future invoice) reads the same rule. History is kept: facts stay immutable.
-- BL-9 (advisory, condition): working-time facts follow the signed truth. One working-time fact per final report
--   version, from its snapshot; a new one supersedes the visit's previous one (supersedes_id), never an update.
--
-- Unchanged: who generates (team members, coordination roles), RLS on facts (J1 insurer scope), immutability
-- (forbid_audit_change), the Q11 rule (billable minutes never above measured, scaled below plan, ADR-040), the
-- minimum duration and the rates themselves. No clinical, tariff or legal rule is invented.

-- 1. CGR-08: reference data carries its validation state ---------------------------------------------------------------
alter table public.tariff_rates
  add column if not exists validated       boolean not null default false,
  add column if not exists validation_note text;
alter table public.billing_rules
  add column if not exists validated       boolean not null default false,
  add column if not exists validation_note text;
comment on column public.tariff_rates.validated is
  'CSR1 / CGR-08: true only once the rate is confirmed for its region by the owner of D-11 / D-18. Seeded rows: false.';
comment on column public.billing_rules.validated is
  'CSR1 / CGR-08: true only once the rule is confirmed for its region by the owner of D-11 / D-18. Seeded rows: false.';

update public.tariff_rates
   set validation_note = 'Kantonale Quelle (Graubünden 2026) als Bund (CH) erfasst; nicht validiert (CGR-08). Neu erfassen nach D-11 und D-18.'
 where version = 'KLV-7-2026' and validation_note is null;
update public.billing_rules
   set validation_note = 'Kantonale Quelle (Basel-Stadt Merkblatt 2026) als Bund (CH) erfasst; nicht validiert (CGR-08). Neu erfassen nach D-11 und D-18.'
 where version = 'J5-2026' and validation_note is null;

-- The minimum rule as a row (the integer helper of 0022 stays for its callers).
create or replace function private.billing_rule(p_region text, p_day date)
returns public.billing_rules
language sql stable security definer set search_path = ''
as $$
  select r.* from public.billing_rules r
  where r.region in (coalesce(p_region, 'CH'), 'CH') and r.valid_from <= p_day and (r.valid_to is null or r.valid_to > p_day)
  order by (r.region = 'CH'), r.valid_from desc
  limit 1
$$;
revoke all on function private.billing_rule(text, date) from public, anon, authenticated;

-- 2. CGR-03: times from the signed snapshot -----------------------------------------------------------------------------
-- Same arithmetic as private.visit_times (0022) and private.visit_care_minutes_exact (0023), over the events the
-- snapshot lists (in their stored order, which is the event id order of 0016).
create or replace function private.snapshot_times(p_snapshot jsonb)
returns table (travel_minutes integer, care_minutes integer, pause_minutes integer, care_minutes_exact numeric)
language sql stable set search_path = ''
as $$
  with ev as (
    select x.e ->> 'type' as event_type, (x.e ->> 'at')::timestamptz as at, x.seq
    from jsonb_array_elements(case when jsonb_typeof(p_snapshot -> 'events') = 'array' then p_snapshot -> 'events'
                                   else '[]'::jsonb end) with ordinality as x(e, seq)
  ), marks as (
    select (select min(at) from ev where event_type = 'departed')  as departed,
           (select min(at) from ev where event_type = 'started')   as started,
           (select max(at) from ev where event_type = 'completed') as completed
  ), pauses as (
    select coalesce(sum(extract(epoch from (r.at - p.at)) / 60), 0) as minutes
    from ev p
    join lateral (select min(x.at) as at from ev x where x.event_type = 'resumed' and x.seq > p.seq) r on r.at is not null
    where p.event_type = 'paused'
  )
  select case when m.departed is not null and m.started is not null
              then greatest(0, round(extract(epoch from (m.started - m.departed)) / 60))::int end,
         case when m.started is not null and m.completed is not null
              then greatest(0, round(extract(epoch from (m.completed - m.started)) / 60 - (select minutes from pauses)))::int end,
         round((select minutes from pauses))::int,
         case when m.started is not null and m.completed is not null
              then round(greatest(0, extract(epoch from (m.completed - m.started)) / 60 - (select minutes from pauses))::numeric, 2) end
  from marks m
$$;
revoke all on function private.snapshot_times(jsonb) from public, anon, authenticated;
comment on function private.snapshot_times(jsonb) is
  'CSR1 / CGR-03: travel, care and pause minutes of a report snapshot. Billing and working time read the signed snapshot, never live times.';

-- 3. Facts: cause, hold link, snapshot hash ------------------------------------------------------------------------------
alter table public.billable_facts
  add column if not exists cause         text not null default 'report',
  add column if not exists hold_id       uuid references public.quality_holds (id),
  add column if not exists snapshot_hash text;
alter table public.billable_facts drop constraint if exists billable_facts_cause_check;
alter table public.billable_facts add constraint billable_facts_cause_check
  check (cause in ('report', 'quality_hold', 'hold_lifted') and ((cause = 'report') = (hold_id is null)));
-- One fact per report version and rule from the report itself; hold facts repeat the report (BL-8).
alter table public.billable_facts drop constraint if exists billable_facts_report_rule_key;
create unique index if not exists billable_facts_one_per_report_rule
  on public.billable_facts (report_id, rule_version) where cause = 'report';
comment on column public.billable_facts.cause is
  'report: built from a final report version. quality_hold: the previous fact made not billable by a hold (BL-8). hold_lifted: the fact before the hold, appended again when the last hold was lifted.';

alter table public.working_time_facts
  add column if not exists report_id     uuid references public.visit_reports (id),
  add column if not exists supersedes_id uuid references public.working_time_facts (id),
  add column if not exists source        text not null default 'live';
alter table public.working_time_facts drop constraint if exists working_time_facts_source_check;
alter table public.working_time_facts add constraint working_time_facts_source_check
  check (source in ('live', 'signed_snapshot') and ((source = 'signed_snapshot') = (report_id is not null)));
alter table public.working_time_facts drop constraint if exists working_time_facts_visit_id_key;
create unique index if not exists working_time_facts_one_per_report
  on public.working_time_facts (report_id) where report_id is not null;
create unique index if not exists working_time_facts_one_successor
  on public.working_time_facts (supersedes_id) where supersedes_id is not null;
comment on table public.working_time_facts is
  'J5 / BL-9: working-time facts per final report version, from its signed snapshot. A correction appends a new fact that supersedes the previous one; the latest has no successor. Rows before 0043 are source live.';

-- 4. Generation, rule J5-v3 ----------------------------------------------------------------------------------------------
create or replace function private.build_billable_fact(p_report_id uuid, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  r          public.visit_reports%rowtype;
  v          public.care_visits%rowtype;
  c          public.cases%rowtype;
  t          record;
  prev       uuid;
  wprev      uuid;
  reasons    text[] := '{}';
  warns      text[] := '{}';
  basis      text;
  brule      public.billing_rules;
  minimum    integer;
  pa         integer;
  pb         integer;
  pc         integer;
  planned    integer;
  measured   numeric;
  factor     numeric := 1;
  ba         numeric;
  bb         numeric;
  bc         numeric;
  fid        uuid;
  versions   jsonb := '{}'::jsonb;
  cat        text;
  mins       integer;
  rate       public.tariff_rates;
  unvalid    boolean := false;
  has_order  boolean;
  order_ok   boolean;
begin
  select * into r from public.visit_reports where id = p_report_id;
  if not found or r.status <> 'final' then return null; end if;
  -- Serialise with a hold being set on the same visit (BL-8 trigger locks the same row).
  select * into v from public.care_visits where id = r.visit_id for update;
  if private.visit_has_open_hold(r.visit_id)
     or exists (select 1 from public.billable_facts f where f.report_id = r.id and f.rule_version = 'J5-v3' and f.cause = 'report') then
    return null;
  end if;
  select * into c from public.cases where id = v.case_id;

  -- CGR-03: the signed snapshot, never the live times or the live plan.
  select * into t from private.snapshot_times(r.snapshot);
  measured := t.care_minutes_exact;
  pa := coalesce(nullif(r.snapshot #>> '{planned,a}', '')::int, 0);
  pb := coalesce(nullif(r.snapshot #>> '{planned,b}', '')::int, 0);
  pc := coalesce(nullif(r.snapshot #>> '{planned,c}', '')::int, 0);
  planned := pa + pb + pc;
  brule := private.billing_rule(c.residence_canton, v.visit_date);
  minimum := coalesce(brule.min_billable_minutes, 0);
  if brule.id is not null and not brule.validated then unvalid := true; end if;

  -- Q11 (ADR-040): billable minutes never above measured; below plan, scaled proportionally.
  if measured is not null and planned > 0 then
    if measured < planned then
      factor := measured / planned;
    elsif measured > planned then
      warns := array_append(warns, 'above_plan');
    end if;
  end if;
  ba := round(pa * factor, 2);
  bb := round(pb * factor, 2);
  bc := round(pc * factor, 2);
  if measured is not null and measured < planned then
    warns := array_append(warns, 'scaled_to_measured');
  end if;

  -- Order basis (CGR-07): a present order needs an end date, and it must not have expired on the visit date.
  has_order := c.medical_order_status = 'present';
  order_ok  := has_order and c.medical_order_valid_until is not null and c.medical_order_valid_until >= v.visit_date;
  if pb > 0 then
    basis := case when order_ok then 'with_order' else 'b_without_valid_order' end;
  else
    basis := case when has_order then 'with_order' else 'without_order_ac' end;
  end if;

  if basis = 'b_without_valid_order' then reasons := array_append(reasons, 'b_without_valid_order'); end if;
  if has_order and c.medical_order_valid_until is null then
    reasons := array_append(reasons, 'order_validity_missing');
  elsif has_order and c.medical_order_valid_until < v.visit_date then
    reasons := array_append(reasons, 'order_expired');
  end if;
  if c.insurance_type is distinct from 'KVG' then reasons := array_append(reasons, 'payer_not_modelled'); end if;
  if c.insurer_name is null then reasons := array_append(reasons, 'no_insurer'); end if;
  if planned = 0 then reasons := array_append(reasons, 'no_planned_minutes'); end if;
  if measured is null then reasons := array_append(reasons, 'no_measured_time');
  elsif ba + bb + bc < minimum then reasons := array_append(reasons, 'below_minimum');
  end if;

  foreach cat in array array['A', 'B', 'C'] loop
    rate := private.tariff_rate(c.residence_canton, 'insurer', cat, v.visit_date);
    versions := versions || jsonb_build_object(cat, rate.version);
    mins := case cat when 'A' then pa when 'B' then pb else pc end;
    if mins > 0 and rate.id is not null and not rate.validated then unvalid := true; end if;
  end loop;
  if unvalid then warns := array_append(warns, 'reference_not_validated'); end if;   -- CGR-08

  -- Correction rule: the newest fact of this visit (older report version, older rule, or a hold fact) is superseded.
  select f.id into prev from public.billable_facts f
  where f.visit_id = v.id and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
  order by f.created_at desc, f.id limit 1;

  insert into public.billable_facts
    (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
     planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
     measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
     billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, snapshot_hash)
  values
    (v.organization_id, v.id, v.case_id, v.team_id, r.id, prev, v.visit_date,
     pa, pb, pc, t.care_minutes,
     measured, ba, bb, bc, 'J5-v3',
     cardinality(reasons) = 0, reasons, warns, basis,
     jsonb_build_object('insurer', c.insurer_name, 'insurance_type', c.insurance_type,
                        'residence_canton', c.residence_canton, 'residence_municipality', c.residence_municipality),
     versions, p_actor, 'report', private.report_snapshot_hash(r.snapshot))
  returning id into fid;

  -- BL-9: one working-time fact per final report version, from the same snapshot; it supersedes the previous one.
  if not exists (select 1 from public.working_time_facts w where w.report_id = r.id) then
    select w.id into wprev from public.working_time_facts w
    where w.visit_id = v.id and not exists (select 1 from public.working_time_facts s where s.supersedes_id = w.id)
    order by w.created_at desc, w.id limit 1;
    insert into public.working_time_facts
      (organization_id, visit_id, team_id, performer_id, visit_date, travel_minutes, care_minutes, pause_minutes,
       report_id, supersedes_id, source)
    values
      (v.organization_id, v.id, v.team_id, r.performer_id, v.visit_date, t.travel_minutes, t.care_minutes, t.pause_minutes,
       r.id, wprev, 'signed_snapshot');
  end if;

  return fid;
end;
$$;
revoke all on function private.build_billable_fact(uuid, uuid) from public, anon, authenticated;

-- 5. BL-8: a hold makes the latest fact not billable; lifting the last hold restores it -----------------------------------
create or replace function private.billable_fact_follow_hold()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  f   public.billable_facts%rowtype;
begin
  -- Serialise with build_billable_fact on the same visit.
  perform 1 from public.care_visits where id = new.visit_id for update;
  select * into f from public.billable_facts x
  where x.visit_id = new.visit_id and not exists (select 1 from public.billable_facts s where s.supersedes_id = x.id)
  order by x.created_at desc, x.id limit 1;
  if not found then return null; end if;

  if tg_op = 'INSERT' and new.lifted_at is null then
    if f.billable then
      insert into public.billable_facts
        (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
         planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
         measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
         billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash)
      values
        (f.organization_id, f.visit_id, f.case_id, f.team_id, f.report_id, f.id, f.visit_date,
         f.planned_minutes_a, f.planned_minutes_b, f.planned_minutes_c, f.actual_care_minutes,
         f.measured_care_minutes, f.billable_minutes_a, f.billable_minutes_b, f.billable_minutes_c, f.rule_version,
         false, array_append(f.reasons, 'quality_hold'), f.warnings, f.order_basis, f.payer_chain, f.tariff_versions,
         new.set_by, 'quality_hold', new.id, f.snapshot_hash);
    end if;
  elsif tg_op = 'UPDATE' and old.lifted_at is null and new.lifted_at is not null
        and not private.visit_has_open_hold(new.visit_id) and f.cause = 'quality_hold' then
    -- Append the fact that was in force before the hold again (it stays immutable; this is a new row).
    insert into public.billable_facts
      (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
       planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
       measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
       billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash)
    select p.organization_id, p.visit_id, p.case_id, p.team_id, p.report_id, f.id, p.visit_date,
           p.planned_minutes_a, p.planned_minutes_b, p.planned_minutes_c, p.actual_care_minutes,
           p.measured_care_minutes, p.billable_minutes_a, p.billable_minutes_b, p.billable_minutes_c, p.rule_version,
           p.billable, p.reasons, p.warnings, p.order_basis, p.payer_chain, p.tariff_versions,
           new.lifted_by, 'hold_lifted', new.id, p.snapshot_hash
    from public.billable_facts p where p.id = f.supersedes_id;
  end if;
  return null;
end;
$$;
revoke all on function private.billable_fact_follow_hold() from public, anon, authenticated;

drop trigger if exists billable_facts_follow_hold_set on public.quality_holds;
create trigger billable_facts_follow_hold_set
  after insert on public.quality_holds
  for each row execute function private.billable_fact_follow_hold();
drop trigger if exists billable_facts_follow_hold_lift on public.quality_holds;
create trigger billable_facts_follow_hold_lift
  after update of lifted_at on public.quality_holds
  for each row execute function private.billable_fact_follow_hold();

-- Holds already open when this migration runs: their visit's latest billable fact gets its hold fact now (idempotent:
-- afterwards the latest fact is not billable).
insert into public.billable_facts
  (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
   planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
   measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
   billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash)
select f.organization_id, f.visit_id, f.case_id, f.team_id, f.report_id, f.id, f.visit_date,
       f.planned_minutes_a, f.planned_minutes_b, f.planned_minutes_c, f.actual_care_minutes,
       f.measured_care_minutes, f.billable_minutes_a, f.billable_minutes_b, f.billable_minutes_c, f.rule_version,
       false, array_append(f.reasons, 'quality_hold'), f.warnings, f.order_basis, f.payer_chain, f.tariff_versions,
       h.set_by, 'quality_hold', h.id, f.snapshot_hash
from public.quality_holds h
join public.billable_facts f on f.visit_id = h.visit_id
where h.lifted_at is null and f.billable
  and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id);

-- 6. Preview: reference validation (CGR-08) --------------------------------------------------------------------------------
drop function if exists public.billing_preview(date);
create function public.billing_preview(p_month date)
returns table (
  team_id             uuid,
  team_name           text,
  billable_visits     integer,
  minutes_a           numeric,
  minutes_b           numeric,
  minutes_c           numeric,
  insurer_chf         numeric,
  insurer_complete    boolean,
  patient_on_file     boolean,
  residual_on_file    boolean,
  not_billable        jsonb,
  reference_validated boolean       -- CGR-08: false when a rate or minimum used (or on file for the month) is not validated
)
language sql stable security definer set search_path = ''
as $$
  with bounds as (
    select date_trunc('month', p_month)::date as m_from, (date_trunc('month', p_month) + interval '1 month')::date as m_to
  ), teams_in_scope as (
    select t.* from public.teams t
    where private.is_org_member(t.organization_id) and (private.is_team_member(t.id) or private.is_coordinator(t.organization_id))
  ), latest_facts as (
    select f.*,
           coalesce(f.billable_minutes_a, f.planned_minutes_a) as bm_a,
           coalesce(f.billable_minutes_b, f.planned_minutes_b) as bm_b,
           coalesce(f.billable_minutes_c, f.planned_minutes_c) as bm_c
    from public.billable_facts f, bounds b
    where f.visit_date >= b.m_from and f.visit_date < b.m_to
      and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
  ), priced as (
    select f.*, c.residence_canton,
           private.tariff_rate(c.residence_canton, 'insurer', 'A', f.visit_date) as ra,
           private.tariff_rate(c.residence_canton, 'insurer', 'B', f.visit_date) as rb,
           private.tariff_rate(c.residence_canton, 'insurer', 'C', f.visit_date) as rc,
           private.billing_rule(c.residence_canton, f.visit_date) as mrule
    from latest_facts f join public.cases c on c.id = f.case_id
    where f.billable and not private.visit_has_open_hold(f.visit_id)
  ), completed as (
    select v.* from public.care_visits v, bounds b
    where v.status = 'completed' and v.visit_date >= b.m_from and v.visit_date < b.m_to
  ), missing as (
    select v.team_id, jsonb_build_object(
             'visit_id', v.id, 'date', v.visit_date,
             'client', (select nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), '') from public.cases c where c.id = v.case_id),
             'reasons', to_jsonb(
               case
                 when private.visit_has_open_hold(v.id) then array['quality_hold']
                 when not exists (select 1 from public.visit_reports r where r.visit_id = v.id and r.status = 'final') then array['report_not_final']
                 when f.id is null then array['not_generated']
                 else f.reasons end)) as item
    from completed v
    left join latest_facts f on f.visit_id = v.id
    where f.id is null or not f.billable or private.visit_has_open_hold(v.id)
  ), unvalidated_on_file as (
    select exists (select 1 from public.tariff_rates r, bounds b
                   where not r.validated and r.valid_from < b.m_to and (r.valid_to is null or r.valid_to > b.m_from))
        or exists (select 1 from public.billing_rules r, bounds b
                   where not r.validated and r.valid_from < b.m_to and (r.valid_to is null or r.valid_to > b.m_from)) as found_any
  )
  select t.id, t.name,
         coalesce((select count(*) from priced p where p.team_id = t.id), 0)::int,
         coalesce((select sum(p.bm_a) from priced p where p.team_id = t.id), 0),
         coalesce((select sum(p.bm_b) from priced p where p.team_id = t.id), 0),
         coalesce((select sum(p.bm_c) from priced p where p.team_id = t.id), 0),
         coalesce((select round(sum(p.bm_a * coalesce((p.ra).amount, 0) / 60.0
                                   + p.bm_b * coalesce((p.rb).amount, 0) / 60.0
                                   + p.bm_c * coalesce((p.rc).amount, 0) / 60.0), 2)
                   from priced p where p.team_id = t.id), 0),
         not exists (select 1 from priced p where p.team_id = t.id
                     and ((p.bm_a > 0 and (p.ra).id is null) or (p.bm_b > 0 and (p.rb).id is null)
                          or (p.bm_c > 0 and (p.rc).id is null))),
         exists (select 1 from public.tariff_rates r where r.payer = 'patient'),
         exists (select 1 from public.tariff_rates r where r.payer = 'residual'),
         coalesce((select jsonb_agg(m.item order by m.item ->> 'date') from missing m where m.team_id = t.id), '[]'::jsonb),
         case
           when exists (select 1 from priced p where p.team_id = t.id) then
             not exists (select 1 from priced p where p.team_id = t.id
                         and ((p.bm_a > 0 and (p.ra).id is not null and not (p.ra).validated)
                              or (p.bm_b > 0 and (p.rb).id is not null and not (p.rb).validated)
                              or (p.bm_c > 0 and (p.rc).id is not null and not (p.rc).validated)
                              or ((p.mrule).id is not null and not (p.mrule).validated)))
           else not (select u.found_any from unvalidated_on_file u)
         end
  from teams_in_scope t
  where p_month is not null
  order by t.name;
$$;
revoke all on function public.billing_preview(date) from public, anon;
grant execute on function public.billing_preview(date) to authenticated;

-- 7. AN1: "billable minutes per care minute" reads facts of rule J5-v2 and J5-v3 (same measured basis) ----------------------
do $$
declare
  def  text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  find text := $f$and f.rule_version = 'J5-v2' and f.billable$f$;
begin
  if position($r$f.rule_version in ('J5-v2', 'J5-v3')$r$ in def) > 0 then return; end if;   -- already patched
  if position(find in def) = 0 then raise exception 'CSR1 J5: pilot_kpis patch did not match'; end if;
  def := replace(def, find, $r$and f.rule_version in ('J5-v2', 'J5-v3') and f.billable$r$);
  execute def;
end;
$$;
