-- CSR1, part 10: J5-C2 (PO 2026-10-23 16:55; billing integrity, strict default until D-22, `legal`). ADR-062.
-- Brief `docs/agents/briefs/CSR1.md` (review 16:55), `docs/agents/briefs/J5.md`.
--
-- Before: `build_billable_fact` (0043) read the case's medical order (`medical_order_status`,
--   `medical_order_valid_until`) at the moment the fact was built: on `generate_billable_facts`, on CGR-29's build at the
--   last lift, or for a correction version. Facts are built later than the visit, so an order or an order end date
--   recorded after the visit made that earlier visit billable.
-- Now: a fact's order basis is the case's order as recorded at the END of the visit date (Europe/Zurich), read from the
--   audited history (`audit_events`, 0013 trigger `audit_cases`, after insert or update, both order columns
--   allowlisted). It never depends on when the fact is built. The same for a correction version's fact and CGR-29's
--   build (both go through `build_billable_fact`).
--   * Cut-off: the first instant of the next day in Europe/Zurich. A change recorded before it counts (it was on file at
--     the end of the visit date), a change at or after it does not.
--   * Reconstruction: for each order column, the `old` value of the earliest audited change at or after the cut-off;
--     without such a change, the live value. Every insert and update of the two columns since they exist (0013) is
--     audited by the trigger, whichever path writes them, so the history is complete backwards from the live row.
--   * The existing order rules (CGR-07, 0043) are applied unchanged to the order as of the cut-off: B minutes without a
--     valid order -> `b_without_valid_order`; a present order without an end date -> `order_validity_missing`; an end
--     date before the visit date -> `order_expired`. A/C minutes without an order on file stay `without_order_ac`
--     (0022, unchanged).
--   * New reason `order_recorded_after_visit`: added when the order as of the cut-off yields an order reason and the
--     live order would yield none (the order or its end date was recorded after the visit date). It names why; it is
--     never the only reason.
--   * The fact records the cut-off (`order_as_of`) and the order it used (`order_recorded`: status and end date).
-- Catch-up (facts built before 0051 have `order_as_of` null): `private.rederive_fact_order` re-derives the order part of
--   the visit's latest J5-v3 fact from the same signed snapshot when it differs (cause `basis_changed`, like J5-C1);
--   it runs in `generate_billable_facts` and after the last lift of a hold. Under an open hold nothing is re-derived.
-- J5-C1 (0049) and the hold trigger (BL-8, CGR-29) are re-created only to carry the two new columns into their copies.
--
-- When D-22 is answered, only `private.order_cutoff` (and possibly the reconstruction rule) changes.
-- No clinical, tariff or legal rule is invented. RLS, column grants (table-level select, 0022) and audit stay as they are.

-- 1. Facts record the order they used ----------------------------------------------------------------------------------
alter table public.billable_facts
  add column if not exists order_as_of    timestamptz,
  add column if not exists order_recorded jsonb;
comment on column public.billable_facts.order_as_of is
  'CSR1 / J5-C2: the cut-off the order basis was read at (end of the visit date, Europe/Zurich). Null: built before 0051.';
comment on column public.billable_facts.order_recorded is
  'CSR1 / J5-C2: the medical order as recorded at order_as_of ({"status", "valid_until"}), from the audited history.';
comment on column public.billable_facts.cause is
  'report: built from a final report version. quality_hold: the previous fact made not billable by a hold (BL-8). '
  'hold_lifted: the fact before the hold, appended again when the last hold was lifted. basis_changed: the previous '
  'fact re-derived from the same signed snapshot, after intake corrected the payer (J5-C1) or for a fact built before '
  '0051 whose order basis differs from the order as recorded at the end of the visit date (J5-C2 catch-up).';

-- 2. The cut-off and the order as recorded at it ---------------------------------------------------------------------------
-- The single place D-22 changes.
create or replace function private.order_cutoff(p_visit_date date)
returns timestamptz
language sql immutable set search_path = ''
as $$
  select ((p_visit_date + 1)::timestamp at time zone 'Europe/Zurich')
$$;
revoke all on function private.order_cutoff(date) from public, anon, authenticated;

create or replace function private.case_order_as_of(p_case_id uuid, p_at timestamptz)
returns table (status text, valid_until date)
language plpgsql stable security definer set search_path = ''
as $$
declare
  live public.cases%rowtype;
  ch   jsonb;
begin
  select * into live from public.cases where id = p_case_id;
  if not found then return; end if;
  status := live.medical_order_status;
  valid_until := live.medical_order_valid_until;
  -- The earliest audited change at or after the cut-off holds the value in force before it (`old`).
  select a.changed -> 'medical_order_status' into ch from public.audit_events a
  where a.table_name = 'cases' and a.entity_id = p_case_id and a.occurred_at >= p_at
    and a.changed ? 'medical_order_status'
  order by a.occurred_at, a.id limit 1;
  if found then status := ch ->> 'old'; end if;
  select a.changed -> 'medical_order_valid_until' into ch from public.audit_events a
  where a.table_name = 'cases' and a.entity_id = p_case_id and a.occurred_at >= p_at
    and a.changed ? 'medical_order_valid_until'
  order by a.occurred_at, a.id limit 1;
  if found then valid_until := (ch ->> 'old')::date; end if;
  return next;
end;
$$;
revoke all on function private.case_order_as_of(uuid, timestamptz) from public, anon, authenticated;
comment on function private.case_order_as_of(uuid, timestamptz) is
  'CSR1 / J5-C2: the case''s medical order (status, end date) as recorded at p_at, from audit_events backwards from the '
  'live row.';

-- The CGR-07 order rules of 0043, unchanged, as one function of an order.
create or replace function private.order_reasons(p_status text, p_valid_until date, p_visit_date date, p_minutes_b integer)
returns table (basis text, reasons text[])
language plpgsql immutable set search_path = ''
as $$
declare
  has_order boolean := p_status is not distinct from 'present';
  order_ok  boolean := p_status is not distinct from 'present' and p_valid_until is not null and p_valid_until >= p_visit_date;
begin
  reasons := '{}';
  if coalesce(p_minutes_b, 0) > 0 then
    basis := case when order_ok then 'with_order' else 'b_without_valid_order' end;
  else
    basis := case when has_order then 'with_order' else 'without_order_ac' end;
  end if;
  if basis = 'b_without_valid_order' then reasons := array_append(reasons, 'b_without_valid_order'); end if;
  if has_order and p_valid_until is null then
    reasons := array_append(reasons, 'order_validity_missing');
  elsif has_order and p_valid_until < p_visit_date then
    reasons := array_append(reasons, 'order_expired');
  end if;
  return next;
end;
$$;
revoke all on function private.order_reasons(text, date, date, integer) from public, anon, authenticated;

-- The order part of a fact: basis, reasons (with order_recorded_after_visit), cut-off and the order used.
create or replace function private.order_basis_as_of(p_case_id uuid, p_visit_date date, p_minutes_b integer)
returns table (basis text, reasons text[], as_of timestamptz, recorded jsonb)
language plpgsql stable security definer set search_path = ''
as $$
declare
  o    record;
  live public.cases%rowtype;
  cur  record;
  lv   record;
begin
  as_of := private.order_cutoff(p_visit_date);
  select * into o from private.case_order_as_of(p_case_id, as_of);
  select * into live from public.cases where id = p_case_id;
  select * into cur from private.order_reasons(o.status, o.valid_until, p_visit_date, p_minutes_b);
  select * into lv from private.order_reasons(live.medical_order_status, live.medical_order_valid_until, p_visit_date, p_minutes_b);
  basis := cur.basis;
  reasons := cur.reasons;
  if cardinality(cur.reasons) > 0 and cardinality(lv.reasons) = 0 then
    reasons := array_append(reasons, 'order_recorded_after_visit');
  end if;
  recorded := jsonb_build_object('status', o.status, 'valid_until', o.valid_until);
  return next;
end;
$$;
revoke all on function private.order_basis_as_of(uuid, date, integer) from public, anon, authenticated;

-- 3. build_billable_fact (0043) with the order as of the visit date --------------------------------------------------------
create or replace function private.build_billable_fact(p_report_id uuid, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  r          public.visit_reports%rowtype;
  v          public.care_visits%rowtype;
  c          public.cases%rowtype;
  t          record;
  o          record;
  prev       uuid;
  wprev      uuid;
  reasons    text[] := '{}';
  warns      text[] := '{}';
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

  -- J5-C2: the order basis (CGR-07 rules) from the order as recorded at the end of the visit date, never at build time.
  select * into o from private.order_basis_as_of(c.id, v.visit_date, pb);
  reasons := reasons || o.reasons;
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
     billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, snapshot_hash,
     order_as_of, order_recorded)
  values
    (v.organization_id, v.id, v.case_id, v.team_id, r.id, prev, v.visit_date,
     pa, pb, pc, t.care_minutes,
     measured, ba, bb, bc, 'J5-v3',
     cardinality(reasons) = 0, reasons, warns, o.basis,
     jsonb_build_object('insurer', c.insurer_name, 'insurance_type', c.insurance_type,
                        'residence_canton', c.residence_canton, 'residence_municipality', c.residence_municipality),
     versions, p_actor, 'report', private.report_snapshot_hash(r.snapshot),
     o.as_of, o.recorded)
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

-- 4. Catch-up: a fact built before 0051 gets the order as of its visit date --------------------------------------------------
create or replace function private.rederive_fact_order(p_visit_id uuid, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  f       public.billable_facts%rowtype;
  o       record;
  reasons text[];
  fid     uuid;
begin
  if p_actor is null then return null; end if;
  perform 1 from public.care_visits where id = p_visit_id for update;   -- serialise with build and holds
  if private.visit_has_open_hold(p_visit_id) then return null; end if;   -- the last lift re-derives
  select * into f from public.billable_facts x
  where x.visit_id = p_visit_id and not exists (select 1 from public.billable_facts s where s.supersedes_id = x.id)
  order by x.created_at desc, x.id limit 1;
  if not found or f.rule_version <> 'J5-v3' or f.order_as_of is not null or f.cause = 'quality_hold' then return null; end if;
  select * into o from private.order_basis_as_of(f.case_id, f.visit_date, f.planned_minutes_b);
  reasons := array(select x from unnest(f.reasons) as x
                   where x not in ('b_without_valid_order', 'order_validity_missing', 'order_expired', 'order_recorded_after_visit'))
             || o.reasons;
  if o.basis = f.order_basis
     and (select coalesce(array_agg(x order by x), '{}') from unnest(reasons) x)
         = (select coalesce(array_agg(x order by x), '{}') from unnest(f.reasons) x) then
    return null;   -- same order basis: nothing to correct
  end if;
  insert into public.billable_facts
    (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
     planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
     measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
     billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash,
     order_as_of, order_recorded)
  values
    (f.organization_id, f.visit_id, f.case_id, f.team_id, f.report_id, f.id, f.visit_date,
     f.planned_minutes_a, f.planned_minutes_b, f.planned_minutes_c, f.actual_care_minutes,
     f.measured_care_minutes, f.billable_minutes_a, f.billable_minutes_b, f.billable_minutes_c, f.rule_version,
     cardinality(reasons) = 0, reasons, f.warnings, o.basis, f.payer_chain, f.tariff_versions, p_actor, 'basis_changed',
     null, f.snapshot_hash, o.as_of, o.recorded)
  returning id into fid;
  return fid;
end;
$$;
revoke all on function private.rederive_fact_order(uuid, uuid) from public, anon, authenticated;
comment on function private.rederive_fact_order(uuid, uuid) is
  'J5-C2 catch-up: the latest J5-v3 fact built before 0051 is re-derived from the same signed snapshot with the order '
  'as recorded at the end of its visit date (cause basis_changed) when its order basis differs.';

-- 5. J5-C1 (0049): unchanged, the copy carries the order columns ---------------------------------------------------------------
create or replace function private.rederive_fact_payer(p_visit_id uuid, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  f       public.billable_facts%rowtype;
  c       public.cases%rowtype;
  reasons text[];
  fid     uuid;
begin
  if p_actor is null then return null; end if;
  perform 1 from public.care_visits where id = p_visit_id for update;   -- serialise with build and holds
  if private.visit_has_open_hold(p_visit_id) then return null; end if;   -- the last lift re-derives
  select * into f from public.billable_facts x
  where x.visit_id = p_visit_id and not exists (select 1 from public.billable_facts s where s.supersedes_id = x.id)
  order by x.created_at desc, x.id limit 1;
  if not found or f.rule_version <> 'J5-v3' then return null; end if;
  select * into c from public.cases where id = f.case_id;
  if not found
     or ((f.payer_chain ->> 'insurer'), (f.payer_chain ->> 'insurance_type'))
        is not distinct from (c.insurer_name, c.insurance_type) then
    return null;
  end if;
  -- Only the payer reasons are recomputed (same tests as build_billable_fact); order reasons stay (J5-C2, D-22).
  reasons := array(select x from unnest(f.reasons) as x where x not in ('payer_not_modelled', 'no_insurer'));
  if c.insurance_type is distinct from 'KVG' then reasons := array_append(reasons, 'payer_not_modelled'); end if;
  if c.insurer_name is null then reasons := array_append(reasons, 'no_insurer'); end if;
  insert into public.billable_facts
    (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
     planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
     measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
     billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash,
     order_as_of, order_recorded)
  values
    (f.organization_id, f.visit_id, f.case_id, f.team_id, f.report_id, f.id, f.visit_date,
     f.planned_minutes_a, f.planned_minutes_b, f.planned_minutes_c, f.actual_care_minutes,
     f.measured_care_minutes, f.billable_minutes_a, f.billable_minutes_b, f.billable_minutes_c, f.rule_version,
     cardinality(reasons) = 0, reasons, f.warnings, f.order_basis,
     f.payer_chain || jsonb_build_object('insurer', c.insurer_name, 'insurance_type', c.insurance_type),
     f.tariff_versions, p_actor, 'basis_changed', null, f.snapshot_hash, f.order_as_of, f.order_recorded)
  returning id into fid;
  return fid;
end;
$$;
revoke all on function private.rederive_fact_payer(uuid, uuid) from public, anon, authenticated;

-- 6. Hold trigger (0043, 0049): unchanged, copies carry the order columns; the last lift also catches up J5-C2 -------------
create or replace function private.billable_fact_follow_hold()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  f    public.billable_facts%rowtype;
  rrid uuid;
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
         billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash,
         order_as_of, order_recorded)
      values
        (f.organization_id, f.visit_id, f.case_id, f.team_id, f.report_id, f.id, f.visit_date,
         f.planned_minutes_a, f.planned_minutes_b, f.planned_minutes_c, f.actual_care_minutes,
         f.measured_care_minutes, f.billable_minutes_a, f.billable_minutes_b, f.billable_minutes_c, f.rule_version,
         false, array_append(f.reasons, 'quality_hold'), f.warnings, f.order_basis, f.payer_chain, f.tariff_versions,
         new.set_by, 'quality_hold', new.id, f.snapshot_hash, f.order_as_of, f.order_recorded);
    end if;
  elsif tg_op = 'UPDATE' and old.lifted_at is null and new.lifted_at is not null
        and not private.visit_has_open_hold(new.visit_id) then
    -- CGR-29: the visit's latest final report version; if it has no J5-v3 fact (it became final during the hold),
    -- build it from that version instead of restoring the older fact.
    select r.id into rrid from public.visit_reports r
    where r.visit_id = new.visit_id and r.status = 'final'
    order by r.version desc limit 1;
    if rrid is not null and not exists (select 1 from public.billable_facts b
                                        where b.report_id = rrid and b.rule_version = 'J5-v3' and b.cause = 'report') then
      perform private.build_billable_fact(rrid, new.lifted_by);
    else
      if f.cause = 'quality_hold' then
        -- Append the fact that was in force before the hold again (it stays immutable; this is a new row).
        insert into public.billable_facts
          (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
           planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
           measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
           billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash,
           order_as_of, order_recorded)
        select p.organization_id, p.visit_id, p.case_id, p.team_id, p.report_id, f.id, p.visit_date,
               p.planned_minutes_a, p.planned_minutes_b, p.planned_minutes_c, p.actual_care_minutes,
               p.measured_care_minutes, p.billable_minutes_a, p.billable_minutes_b, p.billable_minutes_c, p.rule_version,
               p.billable, p.reasons, p.warnings, p.order_basis, p.payer_chain, p.tariff_versions,
               new.lifted_by, 'hold_lifted', new.id, p.snapshot_hash, p.order_as_of, p.order_recorded
        from public.billable_facts p where p.id = f.supersedes_id;
      end if;
      -- J5-C2: a fact restored from before 0051 gets the order as of its visit date.
      perform private.rederive_fact_order(new.visit_id, new.lifted_by);
      -- J5-C1: a payer corrected during the hold is re-derived now.
      perform private.rederive_fact_payer(new.visit_id, new.lifted_by);
    end if;
  end if;
  return null;
end;
$$;
revoke all on function private.billable_fact_follow_hold() from public, anon, authenticated;

-- 7. Generation (0049): J5-C2 catch-up before the J5-C1 catch-up ------------------------------------------------------------
create or replace function public.generate_billable_facts(p_month date)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  n   integer := 0;
  rid uuid;
  vid uuid;
begin
  if uid is null or p_month is null then return 0; end if;
  for rid in
    select r.id
    from public.visit_reports r
    join public.care_visits v on v.id = r.visit_id
    where r.status = 'final'
      and v.visit_date >= date_trunc('month', p_month)::date
      and v.visit_date < (date_trunc('month', p_month) + interval '1 month')::date
      and private.is_org_member(r.organization_id)
      and (private.is_team_member(r.team_id) or private.is_coordinator(r.organization_id))
      and not exists (select 1 from public.visit_reports s
                      where s.supersedes_id = r.id and s.status <> 'withdrawn')   -- latest version only
    order by r.created_at
  loop
    if private.build_billable_fact(rid, uid) is not null then n := n + 1; end if;
  end loop;
  -- J5-C2 (facts built before 0051) and J5-C1 (payer changed without a signed-in user) catch-up.
  for vid in
    select distinct f.visit_id
    from public.billable_facts f
    where f.visit_date >= date_trunc('month', p_month)::date
      and f.visit_date < (date_trunc('month', p_month) + interval '1 month')::date
      and private.is_org_member(f.organization_id)
      and (private.is_team_member(f.team_id) or private.is_coordinator(f.organization_id))
    order by 1
  loop
    if private.rederive_fact_order(vid, uid) is not null then n := n + 1; end if;
    if private.rederive_fact_payer(vid, uid) is not null then n := n + 1; end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.generate_billable_facts(date) from public, anon;
grant execute on function public.generate_billable_facts(date) to authenticated;
