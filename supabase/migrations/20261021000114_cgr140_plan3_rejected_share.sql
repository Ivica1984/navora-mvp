-- CGR-140 (`cra` 2026-11-06 01:30, advisory S3; `aia` review 32 supports option (a)): the PLAN3-7 measure counts a
-- rejected line, ADR-153. Corrects 0113 (ADR-151), which is not changed in place so its reviewed head stays as it was.
--
-- Before (IMPLEMENTED in 0113): `decided_lines` counted a proposed line whose latest AIG1 outcome is `confirmed`,
-- `corrected` or `rejected`, but `confirmed_unchanged_share` counted only `confirmed` and `corrected_share` only
-- `corrected`. A rejected line was in the base and in neither share, so the shares did not add up to 100 % and a team
-- that turned proposals down looked as if it had accepted them. The 0113 header also said "corrected_share … corrected
-- or rejected", which the code did not do.
-- Now (IMPLEMENTED in this migration), option (a): a third share
--   * rejected_share                            proposed lines whose latest outcome is `rejected`, in percent of
--                                               `decided_lines`; suppressed (null) with the other shares (AIG1-7).
-- So, per team and month: confirmed_unchanged_share + corrected_share + rejected_share = 100 % of decided_lines (each
-- rounded to 0.1, so the sum is 100 ± 0.1). `corrected_share` keeps its meaning (`corrected` only); it is not merged
-- with the rejections, because a correction ("right visit, other member") and a rejection ("this proposal is not
-- wanted") tell the team different things (`aia` review 32). AIG1-7 `agent_correction_rates` (0097) is unchanged: it
-- still counts corrected and rejected together as its correction rate per agent and field.
-- Everything else as 0113: scope (own teams; coordinators every team; LEAVE1-3), suppression (AIG1-7 three confirmers,
-- AN1 three performers), no person, confirmer or outcome column, no stop criterion, no threshold, writes nothing. No
-- clinical rule (`cra`: "not a clinical rule; a measure-integrity issue").
-- The return type changes, so the function is dropped and created again (in one transaction of the migration run);
-- no view, policy or other function depends on it. No table, so no RLS policy, column grant or audit trigger is added.
-- Idempotent: `drop function if exists` before `create`.

drop function if exists public.plan3_team_measures(date);

create function public.plan3_team_measures(p_month date)
returns table (team_id uuid, team_name text, month date, enabled_since date,
               day_plans integer, lines integer, decided_lines integer,
               confirmed_unchanged_share numeric, corrected_share numeric, rejected_share numeric,
               confirm_actions_per_plan numeric, minutes_to_last_decision_median numeric,
               no_proposal integer, no_proposal_share numeric,
               no_proposal_not_active integer, no_proposal_needs_rn integer, no_proposal_absent integer,
               no_proposal_overlap integer, proposal_suppressed boolean,
               continuity_before_share numeric, continuity_before_base integer,
               continuity_after_share numeric, continuity_after_base integer, continuity_suppressed boolean)
language sql stable security definer set search_path = ''
as $$
  with m as (select date_trunc('month', p_month)::date as m0,
                    (date_trunc('month', p_month) + interval '1 month')::date as m1),
  my_teams as (                                                        -- the scope of agent_correction_rates (0097)
    select t.id, t.organization_id, t.name,
           (select (private.at_zurich(s.switched_on_at))::date from public.team_day_proposal_settings s
            where s.team_id = t.id) as since
    from public.teams t
    where p_month is not null and not private.access_ended((select auth.uid()))                -- LEAVE1-3
      and private.is_org_member(t.organization_id)
      and (private.is_team_member(t.id) or private.is_coordinator(t.organization_id))
  ),
  sug as (                                                             -- the month's day-plan lines
    select s.id, s.team_id, s.proposal_id, s.created_at, s.not_found, dl.not_found_reason
    from m, my_teams t
    join public.ai_suggestions s on s.team_id = t.id and s.agent_key = 'plan3_day_proposal'
    left join public.day_plan_lines dl on dl.suggestion_id = s.id
    where (private.at_zurich(s.created_at))::date >= m.m0 and (private.at_zurich(s.created_at))::date < m.m1
  ),
  conf as (                                                            -- every confirmation of those lines
    select s.team_id, s.proposal_id, s.id as suggestion_id, y.seq, y.outcome, y.bulk, y.confirmed_by, y.confirmed_at
    from sug s join public.ai_confirmations y on y.suggestion_id = s.id
  ),
  latest as (
    select distinct on (c.suggestion_id) c.suggestion_id, c.outcome from conf c order by c.suggestion_id, c.seq desc
  ),
  first_dec as (
    select c.suggestion_id, min(c.confirmed_at) as at from conf c group by c.suggestion_id
  ),
  plans as (                                                           -- per plan: actions, fully decided, minutes
    select s.team_id, s.proposal_id,
           (select count(distinct case when c.bulk then c.confirmed_by::text || '@' || c.confirmed_at::text
                                       else c.suggestion_id::text || '#' || c.seq::text end)
            from conf c where c.proposal_id = s.proposal_id)::int as actions,
           bool_and(s.not_found or f.at is not null) as all_decided,
           bool_or(not s.not_found) as has_proposed,
           extract(epoch from (max(f.at) filter (where not s.not_found) - min(s.created_at))) / 60.0 as minutes
    from sug s left join first_dec f on f.suggestion_id = s.id
    group by s.team_id, s.proposal_id
  ),
  prop as (
    select s.team_id,
           count(distinct s.proposal_id)::int as day_plans,
           count(*)::int as lines,
           (count(*) filter (where not s.not_found and l.outcome in ('confirmed', 'corrected', 'rejected')))::int as decided,
           (count(*) filter (where not s.not_found and l.outcome = 'confirmed'))::int as unchanged,
           (count(*) filter (where not s.not_found and l.outcome = 'corrected'))::int as corrected,
           (count(*) filter (where not s.not_found and l.outcome = 'rejected'))::int as rejected,      -- CGR-140
           (count(*) filter (where s.not_found_reason is not null))::int as no_prop,
           (count(*) filter (where s.not_found_reason = 'not_active'))::int as np_not_active,
           (count(*) filter (where s.not_found_reason = 'needs_rn'))::int as np_needs_rn,
           (count(*) filter (where s.not_found_reason = 'absent'))::int as np_absent,
           (count(*) filter (where s.not_found_reason = 'overlap'))::int as np_overlap,
           (select count(distinct c.confirmed_by) from conf c where c.team_id = s.team_id) < 3 as suppressed  -- AIG1-7
    from sug s left join latest l on l.suggestion_id = s.id
    group by s.team_id
  ),
  plan_agg as (
    select p.team_id,
           round(sum(p.actions)::numeric / nullif(count(*) filter (where p.actions > 0), 0), 1) as actions_per_plan,
           round((percentile_cont(0.5) within group (order by p.minutes)
                    filter (where p.all_decided and p.has_proposed))::numeric, 1) as minutes_median
    from plans p group by p.team_id
  ),
  cont as (                                                            -- continuity (AN2 style), visits dated in the month
    select t.id as team_id,
           (count(*) filter (where t.since is null or v.visit_date < t.since))::int as before_base,
           (count(*) filter (where (t.since is null or v.visit_date < t.since)
                              and private.visit_performer(v.id) in (c.primary_nurse_id, c.deputy_nurse_id)))::int
             as before_hit,
           (count(*) filter (where t.since is not null and v.visit_date >= t.since))::int as after_base,
           (count(*) filter (where t.since is not null and v.visit_date >= t.since
                              and private.visit_performer(v.id) in (c.primary_nurse_id, c.deputy_nurse_id)))::int
             as after_hit
    from m, my_teams t
    join public.care_visits v on v.team_id = t.id
    join public.cases c on c.id = v.case_id
    where v.status = 'completed' and v.visit_date >= m.m0 and v.visit_date < m.m1
      and (c.primary_nurse_id is not null or c.deputy_nurse_id is not null)
    group by t.id
  ),
  people as (
    select tp.team_id, tp.people
    from m, (select distinct organization_id from my_teams) o,
         lateral private.pilot_team_people(o.organization_id, m.m0, m.m1) tp
  )
  select t.id, t.name, (select m0 from m), t.since,
         coalesce(p.day_plans, 0), coalesce(p.lines, 0),
         case when p.suppressed then null else p.decided end,
         case when p.suppressed then null else round(100.0 * p.unchanged / nullif(p.decided, 0), 1) end,
         case when p.suppressed then null else round(100.0 * p.corrected / nullif(p.decided, 0), 1) end,
         case when p.suppressed then null else round(100.0 * p.rejected / nullif(p.decided, 0), 1) end,  -- CGR-140
         case when p.suppressed then null else a.actions_per_plan end,
         case when p.suppressed then null else a.minutes_median end,
         case when p.suppressed then null else p.no_prop end,
         case when p.suppressed then null else round(100.0 * p.no_prop / nullif(p.lines, 0), 1) end,
         case when p.suppressed then null else p.np_not_active end,
         case when p.suppressed then null else p.np_needs_rn end,
         case when p.suppressed then null else p.np_absent end,
         case when p.suppressed then null else p.np_overlap end,
         coalesce(p.suppressed, false),
         case when coalesce(pp.people, 0) < 3 then null
              else round(100.0 * c.before_hit / nullif(c.before_base, 0), 1) end,
         coalesce(c.before_base, 0),
         case when coalesce(pp.people, 0) < 3 then null
              else round(100.0 * c.after_hit / nullif(c.after_base, 0), 1) end,
         coalesce(c.after_base, 0),
         coalesce(pp.people, 0) < 3                                                        -- AN1's three
  from my_teams t
  left join prop p on p.team_id = t.id
  left join plan_agg a on a.team_id = t.id
  left join cont c on c.team_id = t.id
  left join people pp on pp.team_id = t.id
  where p.team_id is not null or c.team_id is not null
  order by t.name
$$;
revoke all on function public.plan3_team_measures(date) from public, anon;
grant execute on function public.plan3_team_measures(date) to authenticated;
comment on function public.plan3_team_measures(date) is
  'PLAN3-7: per team and Zurich month, never per person: day plans and lines of the day-plan assistant; shares '
  'confirmed unchanged, corrected and rejected (CGR-140: the three add up to the decided lines); confirm actions per plan (a ticked list once); median minutes to the last '
  'decision; "kein Vorschlag" share by reason; share of completed visits by the primary nurse or deputy before and '
  'since the team''s switch-on date. Fewer than three confirmers (AIG1-7) or performers (AN1) in the month: shares '
  'null. Scope as AIG1-7 (own teams; coordinators all teams). No stop criterion. Writes nothing.';
