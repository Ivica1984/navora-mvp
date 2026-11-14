-- =============================================================================
-- J5 change (PO review 2026-10-22 12:00, answers Q11): billable minutes follow measured care time
-- =============================================================================
-- Design (ADR-040, amends ADR-038):
-- * Billable minutes per category never exceed the MEASURED care minutes. When the measured total
--   is below the planned total, planned minutes per category are scaled down proportionally.
-- * Measured minutes above the planned total are not billed; warning 'above_plan' (team reviews
--   the care plan, J3).
-- * The minimum billable duration is checked on the billable minutes after this rule.
-- * Exact minutes (two decimals, from second-precise effective event times): no rounding, no time
--   units until D-18 (tariff-contract billing rules) is answered.
-- * Facts stay immutable. Each fact carries rule_version; facts computed under the old rule
--   (J5-v1) are not rewritten — generation adds a J5-v2 fact that references the old one
--   (the brief's correction rule).
-- =============================================================================

alter table public.billable_facts
  add column rule_version          text not null default 'J5-v1',
  add column measured_care_minutes numeric(8,2),
  add column billable_minutes_a    numeric(8,2),
  add column billable_minutes_b    numeric(8,2),
  add column billable_minutes_c    numeric(8,2);
alter table public.billable_facts alter column rule_version set default 'J5-v2';
alter table public.billable_facts drop constraint billable_facts_report_id_key;
alter table public.billable_facts add constraint billable_facts_report_rule_key unique (report_id, rule_version);

-- Exact measured care minutes (effective times incl. F3 corrections, pauses removed).
create function private.visit_care_minutes_exact(p_visit_id uuid)
returns numeric
language sql stable security definer set search_path = ''
as $$
  with ev as (
    select e.event_type, coalesce(lc.corrected_at, e.occurred_at) as at, e.id
    from public.visit_events e
    left join lateral (select x.corrected_at from public.visit_time_corrections x where x.event_id = e.id
                       order by x.created_at desc, x.id desc limit 1) lc on true
    where e.visit_id = p_visit_id
  ), marks as (
    select (select min(at) from ev where event_type = 'started') as started,
           (select max(at) from ev where event_type = 'completed') as completed
  ), pauses as (
    select coalesce(sum(extract(epoch from (r.at - p.at)) / 60), 0) as minutes
    from ev p
    join lateral (select min(x.at) as at from ev x where x.event_type = 'resumed' and x.id > p.id) r on r.at is not null
    where p.event_type = 'paused'
  )
  select case when m.started is not null and m.completed is not null
              then round(greatest(0, extract(epoch from (m.completed - m.started)) / 60 - (select minutes from pauses))::numeric, 2) end
  from marks m
$$;
revoke all on function private.visit_care_minutes_exact(uuid) from public, anon, authenticated;

create or replace function private.build_billable_fact(p_report_id uuid, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  r        public.visit_reports%rowtype;
  v        public.care_visits%rowtype;
  c        public.cases%rowtype;
  t        record;
  prev     uuid;
  reasons  text[] := '{}';
  warns    text[] := '{}';
  basis    text;
  minimum  integer;
  pa       integer;
  pb       integer;
  pc       integer;
  planned  integer;
  measured numeric;
  factor   numeric := 1;
  ba       numeric;
  bb       numeric;
  bc       numeric;
  fid      uuid;
  versions jsonb := '{}'::jsonb;
  cat      text;
  rate     public.tariff_rates;
begin
  select * into r from public.visit_reports where id = p_report_id;
  if not found or r.status <> 'final' or private.visit_has_open_hold(r.visit_id)
     or exists (select 1 from public.billable_facts f where f.report_id = r.id and f.rule_version = 'J5-v2') then
    return null;
  end if;
  select * into v from public.care_visits where id = r.visit_id;
  select * into c from public.cases where id = v.case_id;
  select * into t from private.visit_times(v.id);
  measured := private.visit_care_minutes_exact(v.id);

  pa := coalesce(v.planned_minutes_a, 0);
  pb := coalesce(v.planned_minutes_b, 0);
  pc := coalesce(v.planned_minutes_c, 0);
  planned := pa + pb + pc;
  minimum := coalesce(private.min_billable_minutes(c.residence_canton, v.visit_date), 0);

  -- Billable minutes: planned per category, scaled down to the measured total; never above it.
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

  if pb > 0 then
    basis := case when c.medical_order_status = 'present'
                    and (c.medical_order_valid_until is null or c.medical_order_valid_until >= v.visit_date)
                  then 'with_order' else 'b_without_valid_order' end;
  else
    basis := case when c.medical_order_status = 'present' then 'with_order' else 'without_order_ac' end;
  end if;

  if basis = 'b_without_valid_order' then reasons := array_append(reasons, 'b_without_valid_order'); end if;
  if c.insurer_name is null then reasons := array_append(reasons, 'no_insurer'); end if;
  if planned = 0 then reasons := array_append(reasons, 'no_planned_minutes'); end if;
  if measured is null then reasons := array_append(reasons, 'no_measured_time');
  elsif ba + bb + bc < minimum then reasons := array_append(reasons, 'below_minimum');   -- after the rule
  end if;

  foreach cat in array array['A', 'B', 'C'] loop
    rate := private.tariff_rate(c.residence_canton, 'insurer', cat, v.visit_date);
    versions := versions || jsonb_build_object(cat, rate.version);
  end loop;

  -- Correction rule: the newest fact of this visit (older report version or older rule) is superseded.
  select f.id into prev from public.billable_facts f
  where f.visit_id = v.id and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
  order by f.created_at desc limit 1;

  insert into public.billable_facts
    (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
     planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
     measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
     billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by)
  values
    (v.organization_id, v.id, v.case_id, v.team_id, r.id, prev, v.visit_date,
     pa, pb, pc, t.care_minutes,
     measured, ba, bb, bc, 'J5-v2',
     cardinality(reasons) = 0, reasons, warns, basis,
     jsonb_build_object('insurer', c.insurer_name, 'insurance_type', c.insurance_type,
                        'residence_canton', c.residence_canton, 'residence_municipality', c.residence_municipality),
     versions, p_actor)
  returning id into fid;

  insert into public.working_time_facts (organization_id, visit_id, team_id, performer_id, visit_date, travel_minutes, care_minutes, pause_minutes)
  values (v.organization_id, v.id, v.team_id, r.performer_id, v.visit_date, t.travel_minutes, t.care_minutes, t.pause_minutes)
  on conflict (visit_id) do nothing;

  return fid;
end;
$$;
revoke all on function private.build_billable_fact(uuid, uuid) from public, anon, authenticated;

-- Preview: billable minutes (J5-v2), falling back to planned minutes only for facts that predate the rule.
drop function public.billing_preview(date);
create function public.billing_preview(p_month date)
returns table (
  team_id            uuid,
  team_name          text,
  billable_visits    integer,
  minutes_a          numeric,
  minutes_b          numeric,
  minutes_c          numeric,
  insurer_chf        numeric,
  insurer_complete   boolean,
  patient_on_file    boolean,
  residual_on_file   boolean,
  not_billable       jsonb
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
           private.tariff_rate(c.residence_canton, 'insurer', 'C', f.visit_date) as rc
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
         coalesce((select jsonb_agg(m.item order by m.item ->> 'date') from missing m where m.team_id = t.id), '[]'::jsonb)
  from teams_in_scope t
  where p_month is not null
  order by t.name;
$$;
revoke all on function public.billing_preview(date) from public, anon;
grant execute on function public.billing_preview(date) to authenticated;
