-- F1: /field — a nurse's own visits for one day (PRODUCT_REQUIREMENTS "Pflegekraft / Field Tool").
--
-- "Own" = visits of the teams the signed-in user belongs to (team_memberships).
-- Per-nurse assignment is NOT modelled yet: it needs the owner's decision D-6
-- (team vs. nurse vs. both). Until then the team is the assignee, which matches
-- Teamautonomie and the T9 write rule (only team members may move a visit).
--
-- SECURITY INVOKER: the caller's RLS still applies on every table read here
-- (organisation scope from T9), so this function can only narrow access.
--
-- Data minimisation (DOMAIN_RULES "Datenschutz", SR-22): only what a nurse needs
-- to find the client and do the visit. No diagnosis, cognitive/mobility status,
-- date of birth, insurance, phone or free-text case notes.

create function public.field_visits(p_date date)
returns table (
  visit_id          uuid,
  visit_date        date,
  time_start        time,
  time_end          time,
  status            text,
  services_provided text[],
  team_id           uuid,
  team_name         text,
  case_id           uuid,
  client_name       text,
  care_needs        text[],
  address           text,
  plz               text,
  ort               text
)
language sql stable security invoker set search_path = ''
as $$
  select v.id, v.visit_date, v.time_start, v.time_end, v.status, v.services_provided,
         t.id, t.name,
         c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         c.care_needs, c.address, c.plz, c.ort
  from public.care_visits v
  join public.team_memberships tm
    on tm.team_id = v.team_id and tm.user_id = (select auth.uid())
  join public.teams t on t.id = v.team_id
  left join public.cases c on c.id = v.case_id
  where p_date is not null
    and v.visit_date = p_date
  order by v.time_start nulls last, v.id;
$$;

revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;

comment on function public.field_visits(date) is
  'F1: visits of the caller''s teams on one day, with minimal client context. Assignment model pending D-6.';
