-- BK-b1s (brief `docs/agents/briefs/BK.md`, PO amendment 2026-11-14 10:39 (3), AUT-117 (c); ADR-195 addendum 11:10):
-- the reader of the team's own reach screen «Unser Einsatzgebiet». App roles read no `teams` row directly (0130), so
-- the screen reads the caller's own teams' reach through this one function:
--   * one row per team the caller is an active member of (`private.is_team_member`: LEAVE1-3, a former member reads
--     nothing); no other team, no person, no order;
--   * columns: team id, name, status, service postcodes, maximum distance, date of the last reach change.
-- The only writer stays `public.set_team_reach` (0130, audited). No clinical, tariff or legal rule. Read only, no audit
-- row (a read of the caller's own team setting, as the other team readers). Idempotent: `create or replace`.

create or replace function public.my_team_reach()
returns table (
  team_id          uuid,
  team_name        text,
  team_status      text,
  postcodes        text[],
  max_distance_km  numeric,
  reach_changed_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select t.id, t.name, t.status,
         coalesce((select array_agg(s.postcode order by s.postcode) from public.team_service_postcodes s
                   where s.team_id = t.id), '{}'::text[]),
         t.max_distance_km, t.reach_changed_at
  from public.teams t
  where (select auth.uid()) is not null
    and private.is_team_member(t.id)
  order by t.name, t.id
$$;
comment on function public.my_team_reach() is
  'BK-b1s / AUT-117 (c): the reach (service postcodes, maximum distance) of the caller''s own teams only; a former '
  'member (LEAVE1-3) reads nothing. Written only by set_team_reach.';
revoke all on function public.my_team_reach() from public, anon;
grant execute on function public.my_team_reach() to authenticated;
