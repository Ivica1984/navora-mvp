-- PLAN3-11: after a stop, the team finds the look-back lines of its own records where it plans (ADR-149). PO brief
-- docs/agents/briefs/PLAN3.md PLAN3-11 (added 2026-10-30 21:25, amended 22:15 and 2026-10-31 02:55 by AIG1-C5 (d)).
-- Stage 0 of D-35: synthetic data only, no AI service. No clinical rule, no threshold, no new read.
--
-- Before (IMPLEMENTED in 0097/0104): `public.agent_stop_lookback(stop)` already returns to a team member only the lines
-- of her own teams' records (coordinators every line); but a member had no way to learn which stops exist, because
-- `ai_agent_stops` has no grant for app roles (AIG1-11) and the stop reaches the screen only as the OPS1 exception.
-- Now (IMPLEMENTED in this migration):
--   1. `public.team_lookback_stops()`: per stop and team, for the caller's own active teams only (never a role, never
--      a coordinator who is not a team member), the agent's name, the stop time and the two AIG1-C1 counts ("offen",
--      "nicht mehr offen") over the same `private.aig1_lookback` lines `agent_stop_lookback` returns. Only rows with at
--      least one open line (AIG1-C5 (d): no entry at "0 offen"), whatever the agent's state now: the lines hang on the
--      stop, not on the agent's setting. No person, outcome or confirmer column (AIG1-11 (4)). Writes nothing.
-- No table, so no RLS policy, column grant or audit trigger is added; the function is the only new object.
-- Idempotent: `create or replace`.

create or replace function public.team_lookback_stops()
returns table (stop_id uuid, agent_name text, team_id uuid, team_name text, stopped_at timestamptz,
               open_count integer, not_open_count integer)
language sql stable security definer set search_path = ''
as $$
  select st.id, d.name, l.team_id, t.name, st.created_at,
         (count(*) filter (where not l.superseded and private.aig1_record_open(l.entity_type, l.entity_id)))::int,
         (count(*) filter (where not l.superseded and not private.aig1_record_open(l.entity_type, l.entity_id)))::int
  from public.ai_agent_stops st
  join public.ai_agent_definitions d on d.key = st.agent_key
  cross join lateral private.aig1_lookback(st.id) l
  join public.teams t on t.id = l.team_id
  where not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(st.organization_id)
    and private.is_team_member(l.team_id)                    -- PLAN3-11: the caller's own teams, never widened by role
  group by st.id, d.name, l.team_id, t.name, st.created_at
  having count(*) filter (where not l.superseded and private.aig1_record_open(l.entity_type, l.entity_id)) > 0
  order by st.created_at desc, t.name
$$;
revoke all on function public.team_lookback_stops() from public, anon;
grant execute on function public.team_lookback_stops() to authenticated;
comment on function public.team_lookback_stops() is
  'PLAN3-11: per stop and team of the caller''s own teams, the stopped agent''s name, the stop time and the AIG1-C1 '
  'counts of its look-back lines (open, no longer open); only stops with at least one open line (AIG1-C5 (d)), '
  'whatever the agent''s state now. No person, outcome or confirmer. Coordinators who are not team members get no row; '
  'Operations keeps the full list (agent_stop_lookback). Writes nothing.';
