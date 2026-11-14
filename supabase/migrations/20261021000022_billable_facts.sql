-- =============================================================================
-- J5 — Billable visit facts and monthly revenue preview (brief docs/agents/briefs/J5.md, rank 10)
-- ARCHITECTURE.md: "… → Quality Gate → billable_facts → Tarif-/Kostenträgerabgleich"
-- =============================================================================
-- Design (ADR-038). No invoice, no e-billing (D-12 gates real invoicing, out of scope).
-- * Reference data, dated and versioned, never hard-coded in logic:
--     tariff_rates  (region CH or canton, payer, KLV category, amount, unit, validity, source)
--     billing_rules (region, minimum billable minutes per visit, validity, source)
--   Shipped: the federal insurer contributions per hour (KLV Art. 7 Abs. 2 a/b/c, valid
--   2026-01-01, source cited) and the 10-minute minimum from the PO brief (source cited).
--   NOT shipped: patient contribution and residual financing. Both are cantonal and wait for
--   the pilot canton (D-11); the preview shows them as "not on file".
-- * billable_facts: one immutable fact per visit and report version, created only from a FINAL
--   report (F6) with NO open quality hold (QG1). Records category minutes (planned) and actual
--   care minutes (measured), payer chain, order basis, tariff versions, billable flag and
--   reasons. A correction (new final report version) creates a new fact referencing the old.
-- * Which minutes count (Q11, PO): provisionally the PLANNED minutes per category of the signed
--   report, because actual time is measured per visit, not per category. When measured care
--   minutes are below the planned total, the fact carries the warning actual_below_planned.
-- * working_time_facts: separate type (travel, care, pause per visit and performing nurse).
-- * Preview: an estimate per month; per payer only where reference data exists.
-- =============================================================================

-- 1. Reference data ------------------------------------------------------------------------------------------
create table public.tariff_rates (
  id          uuid primary key default gen_random_uuid(),
  region      text not null check (region ~ '^(CH|[A-Z]{2})$'),
  payer       text not null check (payer in ('insurer', 'patient', 'residual')),
  category    text check (category is null or category in ('A', 'B', 'C')),
  amount      numeric(8,2) not null check (amount >= 0),
  unit        text not null check (unit in ('per_hour', 'per_day_cap')),
  valid_from  date not null,
  valid_to    date check (valid_to is null or valid_to > valid_from),
  version     text not null,
  source      text not null,
  unique (region, payer, category, valid_from)
);
comment on table public.tariff_rates is 'J5: dated, versioned tariff reference data (CH = federal). Never hard-coded in logic.';

create table public.billing_rules (
  id                   uuid primary key default gen_random_uuid(),
  region               text not null check (region ~ '^(CH|[A-Z]{2})$'),
  min_billable_minutes integer not null check (min_billable_minutes between 0 and 120),
  valid_from           date not null,
  valid_to             date check (valid_to is null or valid_to > valid_from),
  version              text not null,
  source               text not null,
  unique (region, valid_from)
);
comment on table public.billing_rules is 'J5: dated billing rules per region (CH default, canton overrides).';

insert into public.tariff_rates (region, payer, category, amount, unit, valid_from, version, source) values
  ('CH', 'insurer', 'A', 76.90, 'per_hour', '2026-01-01', 'KLV-7-2026',
   'KLV Art. 7 Abs. 2 lit. a; as published in Kanton Graubünden, Spitex ohne kommunalen Leistungsauftrag 2026 (gültig ab 01.01.2026)'),
  ('CH', 'insurer', 'B', 63.00, 'per_hour', '2026-01-01', 'KLV-7-2026',
   'KLV Art. 7 Abs. 2 lit. b; as published in Kanton Graubünden, Spitex ohne kommunalen Leistungsauftrag 2026 (gültig ab 01.01.2026)'),
  ('CH', 'insurer', 'C', 52.60, 'per_hour', '2026-01-01', 'KLV-7-2026',
   'KLV Art. 7 Abs. 2 lit. c; as published in Kanton Graubünden, Spitex ohne kommunalen Leistungsauftrag 2026 (gültig ab 01.01.2026)');
insert into public.billing_rules (region, min_billable_minutes, valid_from, version, source) values
  ('CH', 10, '2026-01-01', 'J5-2026', 'PO brief J5: at least 10 minutes billed per visit (Basel-Stadt Merkblatt 2026); confirm per pilot canton (D-11)');

alter table public.tariff_rates enable row level security;
alter table public.billing_rules enable row level security;
revoke all on public.tariff_rates, public.billing_rules from anon, authenticated;
grant select on public.tariff_rates, public.billing_rules to authenticated;
create policy members_read on public.tariff_rates for select to authenticated using (true);
create policy members_read on public.billing_rules for select to authenticated using (true);

-- Rate valid on a day: canton first, then federal.
create function private.tariff_rate(p_region text, p_payer text, p_category text, p_day date)
returns public.tariff_rates
language sql stable security definer set search_path = ''
as $$
  select r.* from public.tariff_rates r
  where r.payer = p_payer and r.category is not distinct from p_category
    and r.region in (coalesce(p_region, 'CH'), 'CH')
    and r.valid_from <= p_day and (r.valid_to is null or r.valid_to > p_day)
  order by (r.region = 'CH'), r.valid_from desc
  limit 1
$$;

create function private.min_billable_minutes(p_region text, p_day date)
returns integer
language sql stable security definer set search_path = ''
as $$
  select r.min_billable_minutes from public.billing_rules r
  where r.region in (coalesce(p_region, 'CH'), 'CH') and r.valid_from <= p_day and (r.valid_to is null or r.valid_to > p_day)
  order by (r.region = 'CH'), r.valid_from desc
  limit 1
$$;
revoke all on function private.tariff_rate(text, text, text, date), private.min_billable_minutes(text, date) from public, anon, authenticated;

-- 2. Measured times (effective, with F3 corrections) -------------------------------------------------------------
create function private.visit_times(p_visit_id uuid)
returns table (travel_minutes integer, care_minutes integer, pause_minutes integer)
language sql stable security definer set search_path = ''
as $$
  with ev as (
    select e.event_type, coalesce(lc.corrected_at, e.occurred_at) as at, e.id
    from public.visit_events e
    left join lateral (select x.corrected_at from public.visit_time_corrections x where x.event_id = e.id
                       order by x.created_at desc, x.id desc limit 1) lc on true
    where e.visit_id = p_visit_id
  ), marks as (
    select (select min(at) from ev where event_type = 'departed')  as departed,
           (select min(at) from ev where event_type = 'started')   as started,
           (select max(at) from ev where event_type = 'completed') as completed
  ), pauses as (
    select coalesce(sum(extract(epoch from (r.at - p.at)) / 60), 0) as minutes
    from ev p
    join lateral (select min(r.at) as at from ev r where r.event_type = 'resumed' and r.id > p.id) r on r.at is not null
    where p.event_type = 'paused'
  )
  select case when m.departed is not null and m.started is not null
              then greatest(0, round(extract(epoch from (m.started - m.departed)) / 60))::int end,
         case when m.started is not null and m.completed is not null
              then greatest(0, round(extract(epoch from (m.completed - m.started)) / 60 - (select minutes from pauses)))::int end,
         round((select minutes from pauses))::int
  from marks m
$$;
revoke all on function private.visit_times(uuid) from public, anon, authenticated;

-- 3. Facts -------------------------------------------------------------------------------------------------------------
create table public.billable_facts (
  id                    uuid primary key default gen_random_uuid(),
  organization_id       uuid not null references public.organizations (id),
  visit_id              uuid not null,
  case_id               uuid not null,
  team_id               uuid not null,
  report_id             uuid not null references public.visit_reports (id),
  supersedes_id         uuid references public.billable_facts (id),
  visit_date            date not null,
  planned_minutes_a     integer not null default 0,
  planned_minutes_b     integer not null default 0,
  planned_minutes_c     integer not null default 0,
  actual_care_minutes   integer,
  billable              boolean not null,
  reasons               text[] not null default '{}',   -- non-billable reasons
  warnings              text[] not null default '{}',
  order_basis           text not null check (order_basis in ('with_order', 'without_order_ac', 'b_without_valid_order')),
  payer_chain           jsonb not null,                  -- insurer, insurance type, residence canton/municipality
  tariff_versions       jsonb not null,                  -- {"A": "KLV-7-2026", …} or null per category
  created_by            uuid not null,
  created_at            timestamptz not null default now(),
  unique (report_id),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id)
);
create unique index billable_facts_one_successor on public.billable_facts (supersedes_id) where supersedes_id is not null;
comment on table public.billable_facts is
  'J5: immutable billing facts from final reports without an open quality hold. Corrections are new facts. Not an invoice.';

create table public.working_time_facts (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null unique,
  team_id         uuid not null,
  performer_id    uuid,
  visit_date      date not null,
  travel_minutes  integer,
  care_minutes    integer,
  pause_minutes   integer,
  created_at      timestamptz not null default now(),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id)
);
comment on table public.working_time_facts is 'J5: working-time facts per visit — a separate type from billing facts.';

alter table public.billable_facts enable row level security;
alter table public.working_time_facts enable row level security;
revoke all on public.billable_facts, public.working_time_facts from anon, authenticated;
grant select on public.billable_facts, public.working_time_facts to authenticated;
-- The payer chain carries insurer data, which J1 restricts to intake roles and the case's team.
create policy scoped_read on public.billable_facts for select to authenticated
  using (private.is_org_member(organization_id) and (private.is_team_member(team_id) or private.is_intake_role(organization_id)));
create policy scoped_read on public.working_time_facts for select to authenticated
  using (private.is_org_member(organization_id) and (private.is_team_member(team_id) or private.is_coordinator(organization_id)));

create trigger billable_facts_immutable before update or delete on public.billable_facts
  for each row execute function private.forbid_audit_change();
create trigger working_time_facts_immutable before update or delete on public.working_time_facts
  for each row execute function private.forbid_audit_change();

-- 4. Generation (idempotent): one fact per final report without an open hold ----------------------------------------
create function private.build_billable_fact(p_report_id uuid, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  r       public.visit_reports%rowtype;
  v       public.care_visits%rowtype;
  c       public.cases%rowtype;
  t       record;
  prev    uuid;
  reasons text[] := '{}';
  warns   text[] := '{}';
  basis   text;
  minimum integer;
  planned integer;
  fid     uuid;
  versions jsonb := '{}'::jsonb;
  cat     text;
  rate    public.tariff_rates;
begin
  select * into r from public.visit_reports where id = p_report_id;
  if not found or r.status <> 'final' or private.visit_has_open_hold(r.visit_id)
     or exists (select 1 from public.billable_facts f where f.report_id = r.id) then
    return null;
  end if;
  select * into v from public.care_visits where id = r.visit_id;
  select * into c from public.cases where id = v.case_id;
  select * into t from private.visit_times(v.id);

  planned := coalesce(v.planned_minutes_a, 0) + coalesce(v.planned_minutes_b, 0) + coalesce(v.planned_minutes_c, 0);
  minimum := coalesce(private.min_billable_minutes(c.residence_canton, v.visit_date), 0);

  if coalesce(v.planned_minutes_b, 0) > 0 then
    basis := case when c.medical_order_status = 'present'
                    and (c.medical_order_valid_until is null or c.medical_order_valid_until >= v.visit_date)
                  then 'with_order' else 'b_without_valid_order' end;
  else
    basis := case when c.medical_order_status = 'present' then 'with_order' else 'without_order_ac' end;
  end if;

  if basis = 'b_without_valid_order' then reasons := array_append(reasons, 'b_without_valid_order'); end if;
  if c.insurer_name is null then reasons := array_append(reasons, 'no_insurer'); end if;
  if planned = 0 then reasons := array_append(reasons, 'no_planned_minutes'); end if;
  if t.care_minutes is null then reasons := array_append(reasons, 'no_measured_time');
  elsif t.care_minutes < minimum then reasons := array_append(reasons, 'below_minimum');
  end if;
  if t.care_minutes is not null and t.care_minutes < planned then warns := array_append(warns, 'actual_below_planned'); end if;

  foreach cat in array array['A', 'B', 'C'] loop
    rate := private.tariff_rate(c.residence_canton, 'insurer', cat, v.visit_date);
    versions := versions || jsonb_build_object(cat, rate.version);
  end loop;

  -- Correction: a newer report version supersedes the fact of the older one.
  select f.id into prev from public.billable_facts f
  where f.visit_id = v.id and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
  order by f.created_at desc limit 1;

  insert into public.billable_facts
    (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
     planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
     billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by)
  values
    (v.organization_id, v.id, v.case_id, v.team_id, r.id, prev, v.visit_date,
     coalesce(v.planned_minutes_a, 0), coalesce(v.planned_minutes_b, 0), coalesce(v.planned_minutes_c, 0), t.care_minutes,
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

-- Team members (own visits) and coordination roles (organisation). Returns the number of new facts.
create function public.generate_billable_facts(p_month date)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  n   integer := 0;
  rid uuid;
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
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)   -- latest version only
    order by r.created_at
  loop
    if private.build_billable_fact(rid, uid) is not null then n := n + 1; end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.generate_billable_facts(date) from public, anon;
grant execute on function public.generate_billable_facts(date) to authenticated;

-- 5. Preview (estimate) --------------------------------------------------------------------------------------------------
-- Per team and month: billable minutes per category and insurer revenue (federal/cantonal rates on file);
-- patient and residual shown only when on file. Plus every completed visit that is not billable, with why.
create function public.billing_preview(p_month date)
returns table (
  team_id            uuid,
  team_name          text,
  billable_visits    integer,
  minutes_a          integer,
  minutes_b          integer,
  minutes_c          integer,
  insurer_chf        numeric,
  insurer_complete   boolean,      -- false when a rate was missing for some minutes
  patient_on_file    boolean,
  residual_on_file   boolean,
  not_billable       jsonb         -- [{"visit_id","date","client","reasons":[…]}]
)
language sql stable security definer set search_path = ''
as $$
  with bounds as (
    select date_trunc('month', p_month)::date as m_from, (date_trunc('month', p_month) + interval '1 month')::date as m_to
  ), teams_in_scope as (
    select t.* from public.teams t
    where private.is_org_member(t.organization_id) and (private.is_team_member(t.id) or private.is_coordinator(t.organization_id))
  ), latest_facts as (
    select f.* from public.billable_facts f, bounds b
    where f.visit_date >= b.m_from and f.visit_date < b.m_to
      and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
  ), priced as (
    select f.*, c.residence_canton,
           private.tariff_rate(c.residence_canton, 'insurer', 'A', f.visit_date) as ra,
           private.tariff_rate(c.residence_canton, 'insurer', 'B', f.visit_date) as rb,
           private.tariff_rate(c.residence_canton, 'insurer', 'C', f.visit_date) as rc
    from latest_facts f join public.cases c on c.id = f.case_id
    where f.billable and not private.visit_has_open_hold(f.visit_id)   -- a hold set later still stops counting
  ), completed as (
    select v.*, b.m_from from public.care_visits v, bounds b
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
         coalesce((select sum(p.planned_minutes_a) from priced p where p.team_id = t.id), 0)::int,
         coalesce((select sum(p.planned_minutes_b) from priced p where p.team_id = t.id), 0)::int,
         coalesce((select sum(p.planned_minutes_c) from priced p where p.team_id = t.id), 0)::int,
         coalesce((select round(sum(p.planned_minutes_a * coalesce((p.ra).amount, 0) / 60.0
                                   + p.planned_minutes_b * coalesce((p.rb).amount, 0) / 60.0
                                   + p.planned_minutes_c * coalesce((p.rc).amount, 0) / 60.0), 2)
                   from priced p where p.team_id = t.id), 0),
         not exists (select 1 from priced p where p.team_id = t.id
                     and ((p.planned_minutes_a > 0 and (p.ra).id is null) or (p.planned_minutes_b > 0 and (p.rb).id is null)
                          or (p.planned_minutes_c > 0 and (p.rc).id is null))),
         exists (select 1 from public.tariff_rates r where r.payer = 'patient'),
         exists (select 1 from public.tariff_rates r where r.payer = 'residual'),
         coalesce((select jsonb_agg(m.item order by m.item ->> 'date') from missing m where m.team_id = t.id), '[]'::jsonb)
  from teams_in_scope t
  where p_month is not null
  order by t.name;
$$;
revoke all on function public.billing_preview(date) from public, anon;
grant execute on function public.billing_preview(date) to authenticated;
