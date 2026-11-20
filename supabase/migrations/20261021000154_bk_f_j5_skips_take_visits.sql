-- BK-f, contract 2026-11-20 06:39 point 2 (h), decision (a): finding BKF-F1 (docs/engineering/probes/BK-f_ADR_DRAFT.md).
-- Before (IMPLEMENTED, 0051): `public.generate_billable_facts` and the hold-lift trigger call
-- `private.build_billable_fact` for every `final` report, also for a BK take visit (`case_id = null`, 0138); the insert
-- into `public.billable_facts.case_id not null` failed, so the team's whole J5 month failed (pgTAP 154 red), and a BK
-- shift reached a KLV-modelled path (D-44, BK-10 exclude that).
-- Now: both functions are re-created verbatim from 0051 with exactly two additions: the month loop selects only visits
-- with a case, and `build_billable_fact` returns null for a case-less visit (reason in the comment; no error, so a hold
-- lift on a take visit never fails). No table, grant or policy change; grants are repeated as in 0051. Idempotent
-- (`create or replace`). Way back: re-create both functions from 0051 (brings the failure back).

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
  -- BKF-F1 (0154): a BK take visit has no case (0138). It is never a KLV-modelled J5 fact (D-44, BK-10); its billing
  -- is the team invoice draft of BK-f. Skipped with this reason, never an error (a hold lift must not fail).
  if v.case_id is null then return null; end if;
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
      and v.case_id is not null   -- BKF-F1: take visits (no case) are billed by BK-f, never by J5 (D-44, BK-10)
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
