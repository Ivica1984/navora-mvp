-- AN2 part 2 (`docs/agents/briefs/AN2.md`, PO 2026-10-23 15:25 and later updates; ADR-070): the section
-- "Pilot-Hypothesen" on /analytics, computed from events, and the AN1 organisation-level suppression condition
-- (PO review of AN1, 2026-10-22 17:15, "in engineering's next PR that touches `pilot_kpis`", repeated as an AN2
-- dependency). Read-only: no table, no command, no visit, alert or record changes.
--
-- 1. One rule for "too few persons" (AN1, ADR-044) as two private helpers, shared by AN1 and AN2:
--    * `private.pilot_team_people(org, m0, m1)`: persons with visits per team = distinct performers (the first
--      `started` actor, `private.visit_performer`) of completed visits dated in the period. Same definition as AN1's
--      `team_people`; every team of the organisation, also those the caller does not see.
--    * `private.pilot_org_suppressed(org, m0, m1)`: the organisation row is hidden when the organisation has fewer
--      than 3 such persons, or when the persons of all hidden teams (fewer than 3) together number 1 or 2
--      (otherwise "organisation minus visible teams" would point at them).
-- 2. `pilot_kpis` (AN1) is patched: organisation rows follow that condition (value null, "zu wenig Personen"), except
--    `open_p1_exceptions` ("Stand jetzt", a count of open exceptions that OPS1 shows anyway, no person behind it).
-- 3. `public.pilot_hypotheses(p_month)`: one row per (scope, measure[, detail]). Scope = the organisation (coordination
--    roles only) and each team the caller may see (AN1 access rule). Period = visits dated in the month (Europe/Zurich
--    calendar dates, as `visit_date` is), with their later events up to now. A team below 3 persons shows neither
--    value nor base ("zu wenig Personen"); the organisation row follows (1). "zu wenig Daten" when the base is below 5.
--    No client, no person, no free text: only counts, shares, medians and fixed reason codes.
--    Measures in this part (the brief's numbering; sources named per measure):
--      3  coordinator_ends                     visit_events `interrupted` from started/paused; actor a coordination role
--                                               of the organisation outside the visit's team (the CGR-26 'coordination'
--                                               label)
--      5  correction_versions_per_100          visit_reports: correction versions (supersedes_id set, withdrawn ones
--         correction_minutes_after_signature   included) per 100 first versions signed; minutes from the signature of the
--         correction_unchanged_share           superseded version; share of signed corrections whose snapshot hash
--                                               (`private.report_snapshot_hash`) AND summary equal the superseded
--                                               version's (signed again with no change)
--      6  correction_open_signals              report_correction_open as derived (0047): starts when a correction older
--         correction_open_hours                than the effective report_not_final threshold is still draft/signed; ends
--         correction_open_withdrawn_share      when it becomes final (signature, or countersignature where required) or
--         correction_open_signed_share         is withdrawn (CSR1 CGR-24-W); base of the first row = all correction versions
--      7  not_billable_facts                   billable_facts of the month's visits with billable = false; total
--         not_billable_reason (detail = code)  excludes facts whose only reason is `below_minimum` (AN2-M7, CR-029
--         not_billable_days_to_billable        under legal review, D-18); per-reason rows, `below_minimum` always shown
--                                               with its fixed note; median days to a later billable fact of the visit
--      9  visits_many_pauses                   more than two `paused` events
--         visits_open_past_p1                  open (start to completed/interrupted, or now) beyond the planned end plus
--                                               the effective visit_stuck threshold plus its P1 escalation (0038/0039)
--      11 hold_lift_hours, holds_still_open    quality_holds: hours from set to lift; holds still open
--      12 late_report_facts_share              cause 'report' facts built more than 24 h after the visit's end (last
--         basis_changed_per_100                completed event, with time corrections); basis_changed facts per 100
--    Measures 1, 2, 4, 8 and 10 follow in the next part (PLANNED).
-- Thresholds are read from `private.effective_exception_rules` as they are now (no history of rule values exists);
-- none is invented or changed (D-28 stays `clinical`). Day boundaries are calendar dates; no `current_date`.

-- 1. Persons with visits (AN1 rule) -----------------------------------------------------------------------------------
create or replace function private.pilot_team_people(p_org uuid, p_m0 date, p_m1 date)
returns table (team_id uuid, people integer)
language sql stable security definer set search_path = ''
as $$
  select t.id,
         (select count(distinct private.visit_performer(v.id))::int from public.care_visits v
          where v.team_id = t.id and v.status = 'completed' and v.visit_date >= p_m0 and v.visit_date < p_m1)
  from public.teams t
  where t.organization_id = p_org
$$;
revoke all on function private.pilot_team_people(uuid, date, date) from public, anon, authenticated;
comment on function private.pilot_team_people(uuid, date, date) is
  'AN1/AN2: persons with visits per team in [m0, m1): distinct performers of completed visits (ADR-044, ADR-070).';

create or replace function private.pilot_org_suppressed(p_org uuid, p_m0 date, p_m1 date)
returns boolean
language sql stable security definer set search_path = ''
as $$
  with performed as (
    select v.team_id, private.visit_performer(v.id) as performer
    from public.care_visits v
    where v.organization_id = p_org and v.status = 'completed' and v.visit_date >= p_m0 and v.visit_date < p_m1
  ), hidden as (
    select tp.team_id from private.pilot_team_people(p_org, p_m0, p_m1) tp where tp.people < 3
  )
  select (select count(distinct p.performer) from performed p) < 3
      or (select count(distinct p.performer) from performed p where p.team_id in (select h.team_id from hidden h)) between 1 and 2
$$;
revoke all on function private.pilot_org_suppressed(uuid, date, date) from public, anon, authenticated;
comment on function private.pilot_org_suppressed(uuid, date, date) is
  'AN1 condition (PO 2026-10-22 17:15) / AN2: true when the organisation has fewer than 3 persons with visits in the '
  'period, or the persons of all hidden teams together number 1 or 2. The organisation row then shows no value.';

-- 2. AN1: organisation rows follow the condition ----------------------------------------------------------------------
do $patch$
declare
  def text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  a   text := '  all_rows as (
    select * from visit_kpis';
  b   text := '         case when r.team_id is not null and coalesce(tp.people, 0) < 3 then null else r.value end,';
  c   text := '         (r.base is not null and r.base < 5) or (r.team_id is not null and coalesce(tp.people, 0) < 3),';
  d   text := '         case when r.team_id is not null and coalesce(tp.people, 0) < 3
                then ''Zu wenig Personen';
  e   text := '  join my_orgs o on o.organization_id = r.organization_id
  where (r.team_id is null and o.coordinator) or r.team_id in (select id from my_teams)';
  f   text;
begin
  foreach f in array array[a, b, c, d, e] loop
    if (length(def) - length(replace(def, f, ''))) / length(f) <> 1 then
      raise exception 'AN2: pilot_kpis no longer matches the organisation suppression patch (%)', left(f, 60);
    end if;
  end loop;
  def := replace(def, a, '  -- AN1 condition (ADR-070): the organisation row is hidden when it would point at 1 or 2 persons.
  org_hidden as (
    select o.organization_id, private.pilot_org_suppressed(o.organization_id, p.m0, p.m1) as hidden
    from my_orgs o, params p
  ),
' || a);
  def := replace(def, b, '         case when r.team_id is not null and coalesce(tp.people, 0) < 3 then null
              when r.team_id is null and r.kpi <> ''open_p1_exceptions'' and oh.hidden then null
              else r.value end,');
  def := replace(def, c, '         (r.base is not null and r.base < 5) or (r.team_id is not null and coalesce(tp.people, 0) < 3)
           or (r.team_id is null and r.kpi <> ''open_p1_exceptions'' and coalesce(oh.hidden, false)),');
  def := replace(def, d, '         case when r.team_id is null and r.kpi <> ''open_p1_exceptions'' and oh.hidden
                then ''Zu wenig Personen: die Organisationszahl wird verborgen, solange sie auf weniger als 3 Pflegende zurückgeführt werden könnte.''
              when r.team_id is not null and coalesce(tp.people, 0) < 3
                then ''Zu wenig Personen');
  def := replace(def, e, '  join my_orgs o on o.organization_id = r.organization_id
  left join org_hidden oh on oh.organization_id = r.organization_id
  where (r.team_id is null and o.coordinator) or r.team_id in (select id from my_teams)');
  execute def;
end
$patch$;

-- 3. AN2: Pilot-Hypothesen ---------------------------------------------------------------------------------------------
create or replace function public.pilot_hypotheses(p_month date)
returns table (organization_id uuid, team_id uuid, team_name text, measure text, detail text,
               value numeric, base integer, too_few boolean, suppressed boolean, note text)
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
  ), people as (
    select tp.team_id, tp.people
    from my_orgs o, params p, lateral private.pilot_team_people(o.organization_id, p.m0, p.m1) tp
  ), org_hidden as (
    select o.organization_id, private.pilot_org_suppressed(o.organization_id, p.m0, p.m1) as hidden
    from my_orgs o, params p where o.coordinator
  ),
  -- The month's visits of the teams the caller may see -------------------------------------------------------------
  visits as (
    select v.id, v.organization_id, v.team_id, v.status, v.visit_date, v.time_start, v.time_end
    from public.care_visits v, params p
    where v.visit_date >= p.m0 and v.visit_date < p.m1 and v.team_id in (select id from my_teams)
  ),
  -- 3. Coordinator ends (CGR-26 'coordination': admin/coach/operations of the organisation, not in the visit's team) -
  ends as (
    select v.organization_id, v.team_id,
           exists (select 1 from public.organization_memberships om
                   where om.organization_id = v.organization_id and om.user_id = e.actor_id
                     and om.role in ('admin', 'coach', 'operations'))
           and not exists (select 1 from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = e.actor_id)
             as by_coordination
    from visits v
    join public.visit_events e on e.visit_id = v.id and e.event_type = 'interrupted' and e.from_status in ('started', 'paused')
  ), m3 as (
    select x.organization_id, x.team_id, 'coordinator_ends'::text as measure, null::text as detail,
           (count(*) filter (where x.by_coordination))::numeric as value, count(*)::int as base
    from ends x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
  ),
  -- 5. Correction rounds -----------------------------------------------------------------------------------------------
  first_signed as (
    select r.id, r.visit_id, v.organization_id, v.team_id,
           (select count(*) from public.visit_reports c where c.visit_id = r.visit_id and c.supersedes_id is not null) as corrections
    from public.visit_reports r join visits v on v.id = r.visit_id
    where r.supersedes_id is null and r.signed_at is not null
  ), corrections as (
    select c.id, c.status, c.signed_at, c.created_at, c.withdrawn_at, c.countersigned_at, c.visit_id,
           v.organization_id, v.team_id, s.signed_at as previous_signed_at,
           private.report_snapshot_hash(c.snapshot) = private.report_snapshot_hash(s.snapshot)
             and c.summary is not distinct from s.summary as unchanged
    from public.visit_reports c
    join public.visit_reports s on s.id = c.supersedes_id
    join visits v on v.id = c.visit_id
  ), m5 as (
    select f.organization_id, f.team_id, 'correction_versions_per_100'::text as measure, null::text as detail,
           round(100.0 * sum(f.corrections) / count(*), 1) as value, count(*)::int as base
    from first_signed f group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
    union all
    select c.organization_id, c.team_id, 'correction_minutes_after_signature', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (c.created_at - c.previous_signed_at)) / 60))::numeric, 0),
           count(*)::int
    from corrections c where c.previous_signed_at is not null
    group by grouping sets ((c.organization_id, c.team_id), (c.organization_id))
    union all
    select c.organization_id, c.team_id, 'correction_unchanged_share', null,
           round(100.0 * count(*) filter (where c.unchanged) / count(*), 1), count(*)::int
    from corrections c where c.signed_at is not null
    group by grouping sets ((c.organization_id, c.team_id), (c.organization_id))
  ),
  -- 6. Open corrections (report_correction_open, 0047: report_not_final threshold, ends with final or withdrawal) ------
  signals as (
    select c.organization_id, c.team_id, s.started_at,
           case when c.status = 'final' then coalesce(c.countersigned_at, c.signed_at)
                when c.status = 'withdrawn' then c.withdrawn_at end as ended_at,
           c.status
    from corrections c
    cross join lateral (
      select private.after_threshold(c.created_at, r.amount, r.unit) as started_at
      from private.effective_exception_rules(c.organization_id) r where r.exception_type = 'report_not_final') s
  ), raised as (
    select * from signals g
    where g.started_at <= now() and (g.ended_at is null or g.ended_at > g.started_at)
  ), m6 as (
    -- value: corrections that raised the signal; base: all correction versions of the month's visits
    select g.organization_id, g.team_id, 'correction_open_signals'::text as measure, null::text as detail,
           (count(*) filter (where g.started_at <= now() and (g.ended_at is null or g.ended_at > g.started_at)))::numeric as value,
           count(*)::int as base
    from signals g group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
    union all
    select g.organization_id, g.team_id, 'correction_open_hours', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (g.ended_at - g.started_at)) / 3600))::numeric, 1),
           count(*)::int
    from raised g where g.ended_at is not null
    group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
    union all
    select g.organization_id, g.team_id, 'correction_open_withdrawn_share', null,
           round(100.0 * count(*) filter (where g.status = 'withdrawn') / count(*), 1), count(*)::int
    from raised g where g.ended_at is not null
    group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
    union all
    select g.organization_id, g.team_id, 'correction_open_signed_share', null,
           round(100.0 * count(*) filter (where g.status = 'final') / count(*), 1), count(*)::int
    from raised g where g.ended_at is not null
    group by grouping sets ((g.organization_id, g.team_id), (g.organization_id))
  ),
  -- 7. Not-billable facts (AN2-M7: below_minimum on its own row, never in the total) -----------------------------------
  facts as (
    select f.id, f.visit_id, f.organization_id, f.team_id, f.billable, f.reasons, f.created_at, f.cause
    from public.billable_facts f join visits v on v.id = f.visit_id
  ), not_billable as (
    select f.*, f.reasons <@ array['below_minimum']::text[] and cardinality(f.reasons) > 0 as only_below_minimum,
           (select min(l.created_at) from public.billable_facts l
            where l.visit_id = f.visit_id and l.billable and l.created_at > f.created_at) as billable_at
    from facts f where not f.billable
  ), nb_totals as (
    select nb.organization_id, nb.team_id, count(*) as n
    from not_billable nb group by grouping sets ((nb.organization_id, nb.team_id), (nb.organization_id))
  ), nb_reasons as (
    select nb.organization_id, nb.team_id, coalesce(r.code, 'none') as code, count(*) as n
    from not_billable nb
    left join lateral unnest(nullif(nb.reasons, '{}'::text[])) r(code) on true
    group by grouping sets ((nb.organization_id, nb.team_id, coalesce(r.code, 'none')), (nb.organization_id, coalesce(r.code, 'none')))
  ), m7 as (
    select f.organization_id, f.team_id, 'not_billable_facts'::text as measure, null::text as detail,
           (count(*) filter (where not f.billable and not coalesce(nb.only_below_minimum, false)))::numeric as value,
           count(*)::int as base
    from facts f left join not_billable nb on nb.id = f.id
    group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
    union all
    select r.organization_id, r.team_id, 'not_billable_reason', r.code, r.n::numeric, coalesce(t.n, 0)::int
    from nb_reasons r
    left join nb_totals t on t.organization_id = r.organization_id and t.team_id is not distinct from r.team_id
    union all
    select nb.organization_id, nb.team_id, 'not_billable_days_to_billable', null,
           round((percentile_cont(0.5) within group (order by extract(epoch from (nb.billable_at - nb.created_at)) / 86400))::numeric, 1),
           count(*)::int
    from not_billable nb where nb.billable_at is not null and not nb.only_below_minimum
    group by grouping sets ((nb.organization_id, nb.team_id), (nb.organization_id))
  ),
  -- 9. Long or fragmented visits (CGR-23) ------------------------------------------------------------------------------
  started_visits as (
    select v.organization_id, v.team_id,
           (select count(*) from public.visit_events e where e.visit_id = v.id and e.event_type = 'paused') as pauses,
           (select min(e.occurred_at) from public.visit_events e where e.visit_id = v.id and e.event_type = 'started') as started_at,
           (select max(e.occurred_at) from public.visit_events e
            where e.visit_id = v.id and e.event_type in ('completed', 'interrupted')) as ended_at,
           case when v.time_end is not null then
             (v.visit_date + v.time_end + case when v.time_end < v.time_start then interval '1 day' else interval '0' end)
               at time zone 'Europe/Zurich' end as planned_end,
           (select private.after_threshold(private.after_threshold(
                     (v.visit_date + v.time_end + case when v.time_end < v.time_start then interval '1 day' else interval '0' end)
                       at time zone 'Europe/Zurich', r.amount, r.unit), r.escalate_to_p1_after_hours, 'hours')
            from private.effective_exception_rules(v.organization_id) r where r.exception_type = 'visit_stuck') as p1_at
    from visits v
    where exists (select 1 from public.visit_events e where e.visit_id = v.id and e.event_type = 'started')
  ), m9 as (
    select s.organization_id, s.team_id, 'visits_many_pauses'::text as measure, null::text as detail,
           (count(*) filter (where s.pauses > 2))::numeric as value, count(*)::int as base
    from started_visits s group by grouping sets ((s.organization_id, s.team_id), (s.organization_id))
    union all
    select s.organization_id, s.team_id, 'visits_open_past_p1', null,
           (count(*) filter (where coalesce(s.ended_at, now()) > s.p1_at))::numeric, count(*)::int
    from started_visits s where s.p1_at is not null
    group by grouping sets ((s.organization_id, s.team_id), (s.organization_id))
  ),
  -- 11. Quality holds ------------------------------------------------------------------------------------------------
  holds as (
    select h.set_at, h.lifted_at, v.organization_id, v.team_id
    from public.quality_holds h join visits v on v.id = h.visit_id
  ), m11 as (
    select h.organization_id, h.team_id, 'hold_lift_hours'::text as measure, null::text as detail,
           round((percentile_cont(0.5) within group (order by extract(epoch from (h.lifted_at - h.set_at)) / 3600))::numeric, 1),
           count(*)::int
    from holds h where h.lifted_at is not null
    group by grouping sets ((h.organization_id, h.team_id), (h.organization_id))
    union all
    select h.organization_id, h.team_id, 'holds_still_open', null,
           (count(*) filter (where h.lifted_at is null))::numeric, count(*)::int
    from holds h group by grouping sets ((h.organization_id, h.team_id), (h.organization_id))
  ),
  -- 12. Late billing facts -------------------------------------------------------------------------------------------
  report_facts as (
    select f.organization_id, f.team_id, f.created_at,
           (select max(coalesce(lc.corrected_at, e.occurred_at)) from public.visit_events e
              left join lateral (select x.corrected_at from public.visit_time_corrections x where x.event_id = e.id
                                 order by x.created_at desc, x.id desc limit 1) lc on true
            where e.visit_id = f.visit_id and e.event_type = 'completed') as ended_at
    from facts f where f.cause = 'report'
  ), m12 as (
    select r.organization_id, r.team_id, 'late_report_facts_share'::text as measure, null::text as detail,
           round(100.0 * count(*) filter (where r.created_at > r.ended_at + interval '24 hours') / count(*), 1),
           count(*)::int
    from report_facts r where r.ended_at is not null
    group by grouping sets ((r.organization_id, r.team_id), (r.organization_id))
    union all
    select f.organization_id, f.team_id, 'basis_changed_per_100', null,
           round(100.0 * count(*) filter (where f.cause = 'basis_changed') / count(*), 1), count(*)::int
    from facts f group by grouping sets ((f.organization_id, f.team_id), (f.organization_id))
  ),
  computed as (
    select * from m3 union all select * from m5 union all select * from m6 union all select * from m7
    union all select * from m9 union all select * from m11 union all select * from m12
  ),
  -- Every measure appears in every scope, also without events (base 0) ------------------------------------------------
  scopes as (
    select o.organization_id, null::uuid as team_id from my_orgs o where o.coordinator
    union all
    select t.organization_id, t.id from my_teams t
  ), catalogue(measure, detail) as (
    values ('coordinator_ends', null::text), ('correction_versions_per_100', null), ('correction_minutes_after_signature', null),
           ('correction_unchanged_share', null), ('correction_open_signals', null), ('correction_open_hours', null),
           ('correction_open_withdrawn_share', null), ('correction_open_signed_share', null), ('not_billable_facts', null),
           ('not_billable_reason', 'below_minimum'), ('not_billable_days_to_billable', null), ('visits_many_pauses', null),
           ('visits_open_past_p1', null), ('hold_lift_hours', null), ('holds_still_open', null),
           ('late_report_facts_share', null), ('basis_changed_per_100', null)
  ), rows_all as (
    select s.organization_id, s.team_id, k.measure, k.detail, c.value, coalesce(c.base, 0) as base
    from scopes s cross join catalogue k
    left join computed c on c.organization_id = s.organization_id and c.team_id is not distinct from s.team_id
                        and c.measure = k.measure and c.detail is not distinct from k.detail
    union all
    -- per-reason rows beyond the catalogue (codes only)
    select c.organization_id, c.team_id, c.measure, c.detail, c.value, c.base
    from computed c join scopes s on s.organization_id = c.organization_id and s.team_id is not distinct from c.team_id
    where c.measure = 'not_billable_reason' and c.detail is distinct from 'below_minimum'
  )
  select r.organization_id, r.team_id, t.name, r.measure, r.detail,
         case when h.hide then null else r.value end,
         case when h.hide then null else r.base end,
         not h.hide and r.base < 5,
         h.hide,
         case when h.hide and r.team_id is null
                then 'Zu wenig Personen: die Organisationszahl wird verborgen, solange sie auf weniger als 3 Pflegende zurückgeführt werden könnte.'
              when h.hide
                then 'Zu wenig Personen: Teamzahlen erst ab 3 Pflegenden mit Einsätzen im Zeitraum.'
              when r.measure = 'not_billable_reason' and r.detail = 'below_minimum'
                then 'Regel in rechtlicher Prüfung (D-18), nicht als Verlust werten. Nicht in der Summe der nicht abrechenbaren Fakten.'
              when r.measure in ('correction_open_signals', 'visits_open_past_p1')
                then 'Schwelle wie heute eingestellt (provisorisch, D-28).'
         end
  from rows_all r
  left join my_teams t on t.id = r.team_id
  cross join lateral (select case when r.team_id is null then coalesce((select oh.hidden from org_hidden oh
                                                                         where oh.organization_id = r.organization_id), true)
                                  else coalesce((select p.people from people p where p.team_id = r.team_id), 0) < 3 end as hide) h
  order by 1, 2 nulls first, 4, 5 nulls first;
$$;
revoke all on function public.pilot_hypotheses(date) from public, anon;
grant execute on function public.pilot_hypotheses(date) to authenticated;
comment on function public.pilot_hypotheses(date) is
  'AN2: pilot hypotheses measured from events, per team and organisation (never per nurse), for the visits dated in '
  'the month. AN1 access and suppression (ADR-044, ADR-070): a team below 3 persons and a hidden organisation row show '
  'neither value nor base. Measures 3, 5, 6, 7, 9, 11, 12 (part 2); 1, 2, 4, 8, 10 follow.';
