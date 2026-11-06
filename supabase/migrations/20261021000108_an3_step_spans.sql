-- AN3 "Where the non-care time goes" (brief docs/agents/briefs/AN3.md, approved po 2026-11-03 14:00; ADR-144).
-- Synthetic data only (owner directive 2026-11-03); `lca` reads it against D-23 term (b) before any real data (G-19).
--
-- Read-only. No table, column, field, command or tap is added to any care record (AN3-1). One new function:
--
--   public.pilot_step_spans(p_month date) → one row per (scope, measure). Scope = the organisation (coordination roles
--   only) and each team the caller may see: the AN1 access rule (ADR-044), copied from `pilot_hypotheses` (0057).
--   Suppression is AN1's, through the existing helpers `private.pilot_team_people` and `private.pilot_org_suppressed`:
--   a team below 3 persons with visits in the month and a hidden organisation row show neither value nor base
--   ("zu wenig Personen"); "zu wenig Daten" when the base is below 5 (AN3-4). No new threshold.
--
--   Measures (sources per figure, AN3-1 "Engineering names the exact source columns"):
--     travel_share_in_visits        AN3-2. `private.visit_times` (departed → started, with time corrections) of
--                                   completed visits dated in the month with travel and care measured: travel ÷
--                                   (travel + care + pause), the same visits and denominator as AN1
--                                   `care_share_in_visits`. Travel to the visit only.
--     referral_to_case_ready_hours  AN3-1 (c). `partner_requests.created_at` → `cases.ready_for_matching_at` (the
--                                   time J1 records the case as ready, 0013), via `cases.source_partner_request_id`;
--                                   cases that became ready in the month. Team = `cases.assigned_team_id`; a case
--                                   without a team counts on the organisation row only.
--     inform_gp_done_hours          AN3-1 (d). `case_tasks` of kind `inform_gp` (the ORD0 task): `created_at` →
--                                   `done_at`, tasks whose `done_at` falls in the month. `done_at` is written only by a
--                                   person's act (ORD0 `record_gp_informed`, 0061; J1/RET1 paths); a case close sets
--                                   `status = 'done'` without `done_at` (0024, 0031), so such tasks are not "done" here.
--     inform_gp_open_at_month_end   AN3-1 (d). `inform_gp` tasks open at the month's end (in the current month: now,
--     inform_gp_open_age_days       `private.now()`), and their median age in days at that instant. Closed = `done_at`,
--                                   or for a case close the first `case_lifecycle_events` `close` after the task was
--                                   created; a task marked done with neither is left out (its close time is unknown).
--     proposal_decided_hours        AN3-1 (e). `ai_suggestions.created_at` → the first `ai_confirmations.confirmed_at`
--                                   of the proposal, when that first decision is `confirmed`, `corrected` or `rejected`;
--                                   proposals decided in the month.
--     proposals_corrected           CGR-112 (`cra` 2026-11-03 09:30, advisory S3): the decisions of `proposal_decided_hours`
--     proposals_rejected            whose first outcome was `corrected` / `rejected` (value), of all those decisions
--                                   (base), so (e) is never shown without them.
--     proposals_expired_undecided   AN3-1 (e), AIG1-C4. Proposals created in the month with no confirmation whose record
--                                   is no longer open (`private.aig1_record_open`, 0104): counted apart, never in the
--                                   median. Base = proposals created in the month.
--   Reused, not recomputed (AN3-1 "reuse, do not duplicate"): (a) AN1 `report_final_minutes`; (b) AN2
--   `countersign_latency_hours` with `report_returned_share` (F6R-9, 0065) and AN1 `time_correction_share`; the care
--   share stays WORK1-6 `direct_care_share` as built (AN3-6). /analytics places them in one block.
--
--   Access end (LEAVE1-3, pgTAP 074 catalogue): every scope derives from `my_orgs`, which is empty once the caller's
--   access ended, so she gets no rows.
--   Never per person (AN3-3): no person column in the result; every figure is grouped by team or organisation. No WORK1
--   day or segment table is read (AN3-6, D-23 term (b)). Month boundaries are Europe/Zurich calendar dates
--   (`private.at_zurich`), "now" is the test clock `private.now()` (DST1, AN3-7). No clinical rule, target, ranking or
--   colour (AN3-5): the database returns facts and base counts only.
-- Idempotent: `create or replace`, grants re-applied.

create or replace function public.pilot_step_spans(p_month date)
returns table (organization_id uuid, team_id uuid, team_name text, measure text,
               value numeric, base integer, too_few boolean, suppressed boolean, note text)
language sql stable security definer set search_path = ''
as $$
  with params as (
    select date_trunc('month', p_month)::date as m0, (date_trunc('month', p_month) + interval '1 month')::date as m1
  ), bounds as (
    select p.m0, p.m1,
           private.at_zurich(p.m0::timestamp) as t0,
           private.at_zurich(p.m1::timestamp) as t1,
           least(private.at_zurich(p.m1::timestamp), private.now()) as t_end
    from params p
  ), my_orgs as (
    select o.organization_id, private.is_coordinator(o.organization_id) as coordinator
    from public.organization_memberships o where o.user_id = (select auth.uid())
      and not private.access_ended((select auth.uid()))  -- LEAVE1-3: no rows once her access ended
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
  -- AN3-2: travel within visits (AN1 visits and denominator) ----------------------------------------------------------
  travel as (
    select v.organization_id, v.team_id, t.travel_minutes, t.care_minutes, t.pause_minutes
    from public.care_visits v
    cross join bounds b
    cross join lateral private.visit_times(v.id) t
    where v.status = 'completed' and v.visit_date >= b.m0 and v.visit_date < b.m1
      and v.team_id in (select id from my_teams)
      and t.travel_minutes is not null and t.care_minutes is not null
  ), s_travel as (
    select x.organization_id, x.team_id, 'travel_share_in_visits'::text as measure,
           round(100.0 * sum(x.travel_minutes)
                 / nullif(sum(x.travel_minutes + x.care_minutes + coalesce(x.pause_minutes, 0)), 0), 1) as value,
           count(*)::int as base
    from travel x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
  ),
  -- AN3-1 (c): partner request received → case ready (J1) ---------------------------------------------------------------
  referrals as (
    select c.organization_id, c.assigned_team_id as team_id,
           extract(epoch from (c.ready_for_matching_at - r.created_at)) / 3600 as hours
    from public.cases c
    join public.partner_requests r on r.id = c.source_partner_request_id and r.organization_id = c.organization_id
    join my_orgs o on o.organization_id = c.organization_id
    cross join bounds b
    where c.ready_for_matching_at >= b.t0 and c.ready_for_matching_at < b.t1
      and (o.coordinator or c.assigned_team_id in (select id from my_teams))
  ), s_referral as (
    select x.organization_id, x.team_id, 'referral_to_case_ready_hours'::text as measure,
           round((percentile_cont(0.5) within group (order by x.hours))::numeric, 1) as value, count(*)::int as base
    from referrals x where x.team_id is not null group by x.organization_id, x.team_id
    union all
    select x.organization_id, null::uuid, 'referral_to_case_ready_hours',
           round((percentile_cont(0.5) within group (order by x.hours))::numeric, 1), count(*)::int
    from referrals x group by x.organization_id
  ),
  -- AN3-1 (d): ORD0 task "Hausärztin/Hausarzt informieren" ---------------------------------------------------------------
  gp_tasks as (
    select k.organization_id, c.assigned_team_id as team_id, k.created_at, k.done_at, k.status,
           coalesce(k.done_at,
                    case when k.status = 'done' then
                      (select min(e.created_at) from public.case_lifecycle_events e
                       where e.case_id = k.case_id and e.kind = 'close' and e.created_at >= k.created_at) end) as closed_at
    from public.case_tasks k
    join public.cases c on c.id = k.case_id and c.organization_id = k.organization_id
    join my_orgs o on o.organization_id = k.organization_id
    where k.kind = 'inform_gp'
      and (o.coordinator or c.assigned_team_id in (select id from my_teams))
  ), gp_done as (
    select g.organization_id, g.team_id, extract(epoch from (g.done_at - g.created_at)) / 3600 as hours
    from gp_tasks g cross join bounds b
    where g.done_at >= b.t0 and g.done_at < b.t1
  ), gp_open as (
    select g.organization_id, g.team_id, extract(epoch from (b.t_end - g.created_at)) / 86400 as age_days
    from gp_tasks g cross join bounds b
    where b.t_end >= b.t0 and g.created_at < b.t_end
      and (g.status = 'open' or (g.closed_at is not null and g.closed_at >= b.t_end))
  ), s_gp as (
    select x.organization_id, x.team_id, 'inform_gp_done_hours'::text as measure,
           round((percentile_cont(0.5) within group (order by x.hours))::numeric, 1) as value, count(*)::int as base
    from gp_done x where x.team_id is not null group by x.organization_id, x.team_id
    union all
    select x.organization_id, null::uuid, 'inform_gp_done_hours',
           round((percentile_cont(0.5) within group (order by x.hours))::numeric, 1), count(*)::int
    from gp_done x group by x.organization_id
    union all
    select x.organization_id, x.team_id, 'inform_gp_open_at_month_end', count(*)::numeric, count(*)::int
    from gp_open x where x.team_id is not null group by x.organization_id, x.team_id
    union all
    select x.organization_id, null::uuid, 'inform_gp_open_at_month_end', count(*)::numeric, count(*)::int
    from gp_open x group by x.organization_id
    union all
    select x.organization_id, x.team_id, 'inform_gp_open_age_days',
           round((percentile_cont(0.5) within group (order by x.age_days))::numeric, 1), count(*)::int
    from gp_open x where x.team_id is not null group by x.organization_id, x.team_id
    union all
    select x.organization_id, null::uuid, 'inform_gp_open_age_days',
           round((percentile_cont(0.5) within group (order by x.age_days))::numeric, 1), count(*)::int
    from gp_open x group by x.organization_id
  ),
  -- AN3-1 (e): AIG1 proposal created → decided; expired apart (AIG1-C4) -------------------------------------------------
  proposals as (
    select s.organization_id, s.team_id, s.created_at, s.entity_type, s.entity_id, f.outcome, f.confirmed_at
    from public.ai_suggestions s
    join my_orgs o on o.organization_id = s.organization_id
    left join lateral (select c.outcome, c.confirmed_at from public.ai_confirmations c
                       where c.suggestion_id = s.id order by c.seq limit 1) f on true
    where o.coordinator or s.team_id in (select id from my_teams)
  ), decided as (
    select p.organization_id, p.team_id, p.outcome, extract(epoch from (p.confirmed_at - p.created_at)) / 3600 as hours
    from proposals p cross join bounds b
    where p.outcome in ('confirmed', 'corrected', 'rejected') and p.confirmed_at >= b.t0 and p.confirmed_at < b.t1
  ), created as (
    select p.organization_id, p.team_id,
           p.confirmed_at is null and not private.aig1_record_open(p.entity_type, p.entity_id) as expired
    from proposals p cross join bounds b
    where p.created_at >= b.t0 and p.created_at < b.t1
  ), s_aig1 as (
    select x.organization_id, x.team_id, 'proposal_decided_hours'::text as measure,
           round((percentile_cont(0.5) within group (order by x.hours))::numeric, 1) as value, count(*)::int as base
    from decided x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
    union all
    -- CGR-112 (`cra` 2026-11-03 09:30): (e) stands beside the changed and rejected counts of the same decisions
    select x.organization_id, x.team_id, 'proposals_corrected',
           (count(*) filter (where x.outcome = 'corrected'))::numeric, count(*)::int
    from decided x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
    union all
    select x.organization_id, x.team_id, 'proposals_rejected',
           (count(*) filter (where x.outcome = 'rejected'))::numeric, count(*)::int
    from decided x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
    union all
    select x.organization_id, x.team_id, 'proposals_expired_undecided',
           (count(*) filter (where x.expired))::numeric, count(*)::int
    from created x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))
  ),
  computed as (
    select * from s_travel union all select * from s_referral union all select * from s_gp union all select * from s_aig1
  ),
  -- Every measure appears in every scope, also without events (base 0) --------------------------------------------------
  scopes as (
    select o.organization_id, null::uuid as team_id from my_orgs o where o.coordinator
    union all
    select t.organization_id, t.id from my_teams t
  ), catalogue(measure) as (
    values ('travel_share_in_visits'), ('referral_to_case_ready_hours'), ('inform_gp_done_hours'),
           ('inform_gp_open_at_month_end'), ('inform_gp_open_age_days'), ('proposal_decided_hours'),
           ('proposals_corrected'), ('proposals_rejected'), ('proposals_expired_undecided')
  ), rows_all as (
    select s.organization_id, s.team_id, k.measure,
           c.value, coalesce(c.base, 0) as base
    from scopes s cross join catalogue k
    left join computed c on c.organization_id = s.organization_id and c.team_id is not distinct from s.team_id
                        and c.measure = k.measure
  )
  select r.organization_id, r.team_id, t.name, r.measure,
         case when h.hide then null else r.value end,
         case when h.hide then null else r.base end,
         not h.hide and r.base < 5,
         h.hide,
         case when h.hide and r.team_id is null
                then 'Zu wenig Personen: die Organisationszahl wird verborgen, solange sie auf weniger als 3 Pflegende zurückgeführt werden könnte.'
              when h.hide
                then 'Zu wenig Personen: Teamzahlen erst ab 3 Pflegenden mit Einsätzen im Zeitraum.'
         end
  from rows_all r
  left join my_teams t on t.id = r.team_id
  cross join lateral (select case when r.team_id is null then coalesce((select oh.hidden from org_hidden oh
                                                                         where oh.organization_id = r.organization_id), true)
                                  else coalesce((select p.people from people p where p.team_id = r.team_id), 0) < 3 end as hide) h
  order by 1, 2 nulls first, 4;
$$;
revoke all on function public.pilot_step_spans(date) from public, anon;
grant execute on function public.pilot_step_spans(date) to authenticated;
comment on function public.pilot_step_spans(date) is
  'AN3 (ADR-144): per team and organisation and calendar month (Europe/Zurich), never per person, the median span of '
  'administrative steps NAVORA already timestamps (travel within visits, partner request to case ready, ORD0 inform-GP '
  'task, AIG1 proposal to decision beside changed, rejected and expired counts), with base counts. AN1 access and suppression. No target.';
