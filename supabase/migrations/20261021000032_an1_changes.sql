-- AN1 changes requested by the PO (review 2026-10-22 14:30). ADR-044 amended. Full redefinition of pilot_kpis.
--
-- * The measured figure is named honestly: `care_share_in_visits` ("Pflegeanteil im Einsatz") = care ÷ (travel +
--   care + pause) of visits with departure AND completion; incomplete visits are excluded and counted
--   (`incomplete_visits`). No reference line.
-- * `direct_care_share` (North Star) is a placeholder until paid working time is recorded (D-23).
-- * No per-nurse inference: team figures only for teams with at least 3 persons with visits in the period;
--   otherwise value null, "too few", and the note; the organisation figure stays.
-- * COVER1 figures: cover without Operations excludes covers where a coordination role took over or closed the
--   visit's exception before acceptance; time to cover runs from entering the offer window.
-- * Open P1 exceptions: "Stand jetzt", with all open exceptions as base.

create or replace function public.pilot_kpis(p_month date)
 RETURNS TABLE(organization_id uuid, team_id uuid, team_name text, kpi text, value numeric, base integer, too_few boolean, note text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    select v.id, v.organization_id, v.team_id, v.case_id, v.status, v.plan_generated, v.visit_date, v.time_start, v.created_at
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
  -- Persons with visits per team: team figures need at least 3, so no figure points at one nurse.
  team_people as (
    select d.team_id, count(distinct d.performer) as people from done d where d.performer is not null group by d.team_id
  ),
  visit_kpis as (
    -- Care share within visits: only visits with departure and completion (travel and care measured).
    select d.organization_id, d.team_id, 'care_share_in_visits' as kpi,
           round(100.0 * sum(d.care_minutes) / nullif(sum(d.travel_minutes + d.care_minutes + coalesce(d.pause_minutes, 0)), 0), 1) as value,
           count(*)::int as base
    from done d where d.care_minutes is not null and d.travel_minutes is not null
    group by grouping sets ((d.organization_id, d.team_id), (d.organization_id))
    union all
    select d.organization_id, d.team_id, 'incomplete_visits',
           count(*) filter (where d.care_minutes is null or d.travel_minutes is null)::numeric, count(*)::int
    from done d group by grouping sets ((d.organization_id, d.team_id), (d.organization_id))
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
           (select count(*) from public.operations_exceptions() x)::int as base
    from my_orgs o where o.coordinator
  ),
  -- COVER1: offered visits covered by a neighbouring team before anyone in a coordination role took over or
  -- closed the visit's exception; time from entering the offer window (not from a page load) to acceptance.
  cover_base as (
    select v.id, v.organization_id, v.team_id,
           (select min(e.created_at) from public.cover_events e where e.visit_id = v.id and e.kind = 'accepted') as accepted_at,
           greatest(private.visit_start_at(v.visit_date, v.time_start) - (select w.offer_lead from private.cover_window(v.organization_id) w),
                    v.created_at) as entered_at
    from visits v
    where exists (select 1 from public.cover_events e where e.visit_id = v.id and e.kind = 'offered')
  ),
  cover as (
    select b.organization_id, b.team_id, 'cover_without_operations' as kpi,
           round(100.0 * count(*) filter (where b.accepted_at is not null and not exists (
             select 1 from public.exception_events ev
             where ev.organization_id = b.organization_id and ev.kind in ('take', 'close')
               and ev.exception_key in ('visit_uncovered:' || b.id, 'visit_uncovered_hospital:' || b.id, 'cover_without_access:' || b.id)
               and ev.created_at < b.accepted_at)) / count(*), 1) as value,
           count(*)::int as base
    from cover_base b
    group by grouping sets ((b.organization_id, b.team_id), (b.organization_id))
    union all
    select b.organization_id, b.team_id, 'cover_median_hours',
           round((percentile_cont(0.5) within group (order by extract(epoch from (b.accepted_at - b.entered_at)) / 3600))::numeric, 1),
           count(*)::int
    from cover_base b where b.accepted_at is not null
    group by grouping sets ((b.organization_id, b.team_id), (b.organization_id))
  ),
  planning_actions as (
    select pc.organization_id, pc.team_id, 'planning_actions_per_client_week' as kpi,
           round(count(*)::numeric / nullif(count(distinct pc.case_id), 0)
                 / ((select (m1 - m0) from params)::numeric / 7), 2) as value,
           count(distinct pc.case_id)::int as base
    from public.visit_plan_changes pc, params p
    where pc.changed_at >= p.m0 and pc.changed_at < p.m1 and pc.team_id in (select id from my_teams)
      and pc.change in ('planned', 'moved', 'removed') and pc.actor_id <> private.plan_system_actor()
      and coalesce(pc.reason, '') not like 'care plan%' and coalesce(pc.reason, '') not like 'cover%'
    group by grouping sets ((pc.organization_id, pc.team_id), (pc.organization_id))
  ),
  all_rows as (
    select * from visit_kpis union all select * from billing union all select * from referral
    union all select * from offers union all select * from p1 union all select * from cover
    union all select * from planning_actions
  )
  select r.organization_id, r.team_id, t.name, r.kpi,
         case when r.team_id is not null and coalesce(tp.people, 0) < 3 then null else r.value end,
         r.base,
         (r.base is not null and r.base < 5) or (r.team_id is not null and coalesce(tp.people, 0) < 3),
         case when r.team_id is not null and coalesce(tp.people, 0) < 3
                then 'Zu wenig Personen: Teamzahlen erst ab 3 Pflegenden mit Einsätzen im Zeitraum (nur Organisation).'
              when r.kpi = 'care_share_in_visits'
                then 'Pflege ÷ (Weg + Pflege + Pause) im Einsatz. Nicht enthalten: Dokumentation, Rückweg, Zeit ausserhalb der Einsätze.'
              when r.kpi = 'open_p1_exceptions' then 'Stand jetzt; Basis: alle offenen Ausnahmen.'
         end
  from all_rows r
  left join my_teams t on t.id = r.team_id
  left join team_people tp on tp.team_id = r.team_id
  join my_orgs o on o.organization_id = r.organization_id
  where (r.team_id is null and o.coordinator) or r.team_id in (select id from my_teams)
  union all
  -- Not measurable yet, said plainly.
  select o.organization_id, null, null, k.kpi, null, null, false, k.note
  from my_orgs o cross join (values
    ('direct_care_share', 'Noch nicht messbar: bezahlte Arbeitszeit wird noch nicht erfasst (D-23).'),
    ('p1_median_close_hours', 'Noch nicht messbar: der Entstehungszeitpunkt einer Ausnahme wird nicht gespeichert.')) k(kpi, note)
  where o.coordinator
  union all
  -- The care share row is always shown to coordination roles, also before any measured visit exists.
  select o.organization_id, null, null, 'care_share_in_visits', null, 0, true,
         'Pflege ÷ (Weg + Pflege + Pause) im Einsatz. Nicht enthalten: Dokumentation, Rückweg, Zeit ausserhalb der Einsätze. Noch keine vollständigen Einsätze im Zeitraum.'
  from my_orgs o
  where o.coordinator and not exists (select 1 from all_rows r where r.organization_id = o.organization_id and r.team_id is null
                                        and r.kpi = 'care_share_in_visits')
  union all
  select t.organization_id, t.id, t.name, 'direct_care_share', null, null, false,
         'Noch nicht messbar: bezahlte Arbeitszeit wird noch nicht erfasst (D-23).'
  from my_teams t
  where exists (select 1 from visits v where v.team_id = t.id)
  order by 1, 2 nulls first, 4;
$function$;
