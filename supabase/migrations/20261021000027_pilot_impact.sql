-- AN1: pilot impact dashboard (PO brief docs/agents/briefs/AN1.md, ADR-044).
--
-- * One read model, `pilot_kpis(month)`: aggregates per team and for the organisation, never per nurse,
--   never client identity or health data. Each row carries its base count; fewer than 5 → "too few data".
-- * Scope: coordination roles (admin, coach, operations) see the organisation and every team; a team
--   member sees only her own teams. Exception KPIs (OPS1) are coordination figures.
-- * Answer to the brief's question: everything is computed live from the source tables for one month.
--   Pilot volumes are small; a nightly aggregate is only needed when a month takes too long to compute.
-- * Definitions (engineering, D-21 for the PO to confirm):
--     direct_care_share  = care minutes ÷ (travel + care + pause minutes) of completed visits (F1–F4 events
--                          with corrections). Non-visit working time is not recorded yet, so this is an upper bound.
--     report_final_minutes = median minutes from visit end to the final report (first version: signature,
--                          or countersignature where required).
-- * Not measurable yet (row with value null and a note): time to close a P1 exception (the time an
--   exception first appeared is not stored), COVER1 (not built).

create function public.pilot_kpis(p_month date)
returns table (
  organization_id uuid,
  team_id         uuid,           -- null = whole organisation
  team_name       text,
  kpi             text,
  value           numeric,
  base            integer,        -- number of visits / cases / requests / facts behind the figure
  too_few         boolean,
  note            text
)
language sql stable security definer set search_path = ''
as $$
  with params as (
    select date_trunc('month', p_month)::date as m0, (date_trunc('month', p_month) + interval '1 month')::date as m1
  ), my_orgs as (
    select o.organization_id, private.is_coordinator(o.organization_id) as coordinator
    from public.organization_memberships o where o.user_id = (select auth.uid())
  ), my_teams as (
    select t.id, t.organization_id, t.name from public.teams t join my_orgs o on o.organization_id = t.organization_id
    where o.coordinator or private.is_team_member(t.id)
  ),
  -- Visits of the month ------------------------------------------------------------------------------------
  visits as (
    select v.id, v.organization_id, v.team_id, v.case_id, v.status, v.plan_generated
    from public.care_visits v, params p
    where v.visit_date >= p.m0 and v.visit_date < p.m1 and v.team_id in (select id from my_teams)
  ), done as (
    select v.*, t.travel_minutes, t.care_minutes, t.pause_minutes, private.visit_performer(v.id) as performer,
           exists (select 1 from public.visit_time_corrections x where x.visit_id = v.id) as corrected,
           (select max(coalesce(lc.corrected_at, e.occurred_at)) from public.visit_events e
              left join lateral (select x.corrected_at from public.visit_time_corrections x where x.event_id = e.id
                                 order by x.created_at desc, x.id desc limit 1) lc on true
            where e.visit_id = v.id and e.event_type = 'completed') as ended_at,
           (select case when r.status = 'final' or exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)
                        then coalesce(r.countersigned_at, r.signed_at) end
            from public.visit_reports r where r.visit_id = v.id and r.supersedes_id is null) as final_at
    from visits v cross join lateral private.visit_times(v.id) t
    where v.status = 'completed'
  ), case_continuity as (
    select d.organization_id, d.team_id, d.case_id,
           count(distinct d.performer) as nurses,
           count(*) filter (where d.performer = c.primary_nurse_id) as by_primary, count(*) as n
    from done d join public.cases c on c.id = d.case_id
    where d.case_id is not null and d.performer is not null
    group by d.organization_id, d.team_id, d.case_id
  ),
  visit_kpis as (
    select d.organization_id, d.team_id, 'direct_care_share' as kpi,
           round(100.0 * sum(d.care_minutes) / nullif(sum(coalesce(d.travel_minutes, 0) + d.care_minutes + coalesce(d.pause_minutes, 0)), 0), 1) as value,
           count(*) filter (where d.care_minutes is not null)::int as base
    from done d where d.care_minutes is not null group by grouping sets ((d.organization_id, d.team_id), (d.organization_id))
    union all
    select d.organization_id, d.team_id, 'time_correction_share',
           round(100.0 * count(*) filter (where d.corrected) / count(*), 1), count(*)::int
    from done d group by grouping sets ((d.organization_id, d.team_id), (d.organization_id))
    union all
    select d.organization_id, d.team_id, 'report_final_minutes',
           round((percentile_cont(0.5) within group (order by extract(epoch from (d.final_at - d.ended_at)) / 60))::numeric, 0),
           count(*) filter (where d.final_at is not null and d.ended_at is not null)::int
    from done d where d.final_at is not null and d.ended_at is not null
    group by grouping sets ((d.organization_id, d.team_id), (d.organization_id))
    union all
    select d.organization_id, d.team_id, 'reports_final_within_10_min',
           round(100.0 * count(*) filter (where d.final_at is not null and d.ended_at is not null
                                           and d.final_at <= d.ended_at + interval '10 minutes') / count(*), 1),
           count(*)::int
    from done d group by grouping sets ((d.organization_id, d.team_id), (d.organization_id))
    union all
    select v.organization_id, v.team_id, 'plan_generated_share',
           round(100.0 * count(*) filter (where v.plan_generated) / count(*), 1), count(*)::int
    from visits v where v.status <> 'cancelled' group by grouping sets ((v.organization_id, v.team_id), (v.organization_id))
    union all
    select c.organization_id, c.team_id, 'distinct_nurses_per_client',
           round(avg(c.nurses), 2), sum(c.n)::int
    from case_continuity c group by grouping sets ((c.organization_id, c.team_id), (c.organization_id))
    union all
    select c.organization_id, c.team_id, 'primary_nurse_share',
           round(100.0 * sum(c.by_primary) / nullif(sum(c.n), 0), 1), sum(c.n)::int
    from case_continuity c group by grouping sets ((c.organization_id, c.team_id), (c.organization_id))
  ),
  -- Billing (J5): billable minutes per measured care minute, current facts (rule J5-v2) ---------------------
  billing as (
    select f.organization_id, f.team_id, 'billable_per_care_minute' as kpi,
           round(sum(coalesce(f.billable_minutes_a, 0) + coalesce(f.billable_minutes_b, 0) + coalesce(f.billable_minutes_c, 0))
                 / nullif(sum(f.measured_care_minutes), 0), 2) as value,
           count(*)::int as base
    from public.billable_facts f, params p
    where f.visit_date >= p.m0 and f.visit_date < p.m1 and f.team_id in (select id from my_teams)
      and f.rule_version = 'J5-v2' and f.billable and f.measured_care_minutes is not null
      and not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
    group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
  ),
  -- Referral to first visit (J1): cases whose first visit started this month -----------------------------------
  first_visits as (
    select c.organization_id, fv.team_id,
           extract(epoch from (fv.started_at - coalesce(pr.created_at, c.created_at))) / 86400 as days
    from public.cases c
    join lateral (
      select v.team_id, min(e.occurred_at) as started_at
      from public.care_visits v join public.visit_events e on e.visit_id = v.id and e.event_type = 'started'
      where v.case_id = c.id group by v.team_id order by min(e.occurred_at) limit 1
    ) fv on true
    left join public.partner_requests pr on pr.converted_case_id = c.id
    , params p
    where fv.started_at >= p.m0 and fv.started_at < p.m1 and fv.team_id in (select id from my_teams)
  ), referral as (
    select f.organization_id, f.team_id, 'referral_to_first_visit_days' as kpi,
           round((percentile_cont(0.5) within group (order by f.days))::numeric, 1) as value, count(*)::int as base
    from first_visits f group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
  ),
  -- Team decisions (J2): requests created this month, accepted by a team before the response deadline --------------
  offers as (
    select m.organization_id, null::uuid as team_id, 'first_offer_acceptance' as kpi,
           round(100.0 * count(*) filter (where exists (
             select 1 from public.team_decisions d where d.matching_request_id = m.id and d.decision = 'accept'
               and (m.response_due_at is null or d.decided_at <= m.response_due_at))) / count(*), 1) as value,
           count(*)::int as base
    from public.matching_requests m join my_orgs o on o.organization_id = m.organization_id and o.coordinator, params p
    where m.created_at >= p.m0 and m.created_at < p.m1
    group by m.organization_id
  ),
  -- OPS1: open P1 exceptions now (coordination only) ---------------------------------------------------------------
  p1 as (
    select o.organization_id, null::uuid as team_id, 'open_p1_exceptions' as kpi,
           (select count(*) from public.operations_exceptions() x where x.priority = 'P1')::numeric as value,
           null::int as base
    from my_orgs o where o.coordinator
  ),
  all_rows as (
    select * from visit_kpis union all select * from billing union all select * from referral
    union all select * from offers union all select * from p1
  )
  select r.organization_id, r.team_id, t.name, r.kpi, r.value, r.base,
         r.base is not null and r.base < 5,
         case when r.kpi = 'direct_care_share' then 'Näherung: Arbeitszeit ausserhalb der Einsätze wird noch nicht erfasst.' end
  from all_rows r
  left join my_teams t on t.id = r.team_id
  join my_orgs o on o.organization_id = r.organization_id
  where (r.team_id is null and o.coordinator) or r.team_id in (select id from my_teams)
  union all
  select o.organization_id, null, null, k.kpi, null, null, false, k.note
  from my_orgs o cross join (values
    ('p1_median_close_hours', 'Noch nicht messbar: der Entstehungszeitpunkt einer Ausnahme wird nicht gespeichert.'),
    ('cover_without_operations', 'Noch nicht messbar: COVER1 ist noch nicht gebaut.')) k(kpi, note)
  where o.coordinator
  order by 1, 2 nulls first, 4;
$$;
revoke all on function public.pilot_kpis(date) from public, anon;
grant execute on function public.pilot_kpis(date) to authenticated;
