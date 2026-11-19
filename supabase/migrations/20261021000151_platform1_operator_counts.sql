-- PLATFORM1 (ADR-213; founder live session 2026-11-19): the NAVORA operator cockpit `/platform`, counts only.
-- Source: Blueprint V3.2 §2.4 Rollenrechte, row «NAVORA-Betrieb»: sees counts and exceptions («nicht gedeckt»), never
-- care content or addresses; §3.3: no operator dashboard shows the care revenue of a team, only aggregated counts.
-- Handbook V2.2 §2 route `/platform`. No money column (FE-078: no money flows through NAVORA, no commission field).
-- Idempotent. No clinical, legal or tariff rule is set here.

-- 1. Who is NAVORA operations. Written only by the table owner (seed or a reviewed migration); no API role and no
--    command can read or write it, so no app path changes it (an admin command with audit is PLANNED, ADR-213 (4)).
create table if not exists private.platform_operators (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default private.now(),
  note       text not null check (length(trim(note)) > 0)
);
revoke all on private.platform_operators from public, anon, authenticated;
-- B0-7-1: every table has row level security on; no policy, so only the owner (and definer functions) read it.
alter table private.platform_operators enable row level security;
comment on table private.platform_operators is
  'PLATFORM1 (ADR-213): members of NAVORA operations. Owner-written only (seed, reviewed migration). Grants nothing '
  'but the count read model public.platform_overview().';

-- 2. Am I NAVORA operations? (navigation only; the read model checks again)
create or replace function public.am_platform_operator()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from private.platform_operators p where p.user_id = (select auth.uid()))
     and not private.access_ended((select auth.uid()));  -- LEAVE1-3
$$;
revoke all on function public.am_platform_operator() from public, anon;
grant execute on function public.am_platform_operator() to authenticated;

-- 3. Counts per organisation. Empty for everybody who is not NAVORA operations. Upcoming orders = ends_at in the
--    future; their cover state comes from private.order_cover (0136), the same mapping the client sees.
--    Returns no person, no name of a person, no address, no care content, no amount of money.
create or replace function public.platform_overview()
returns table (organization_id uuid, organization_name text, simulation boolean, teams integer, members integer,
               client_accounts integer, orders_upcoming integer, orders_covered integer, orders_waiting integer,
               orders_not_covered integer)
language sql stable security definer set search_path = ''
as $$
  with me as (
    select 1 from private.platform_operators p where p.user_id = (select auth.uid())
      and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  ),
  up as (
    select r.organization_id, c.cover_state
    from public.partner_requests r
    cross join lateral private.order_cover(r.id, private.now()) c
    where r.order_kind is not null and r.ends_at > private.now()
  )
  select o.id, o.name, o.simulation,
         (select count(*)::int from public.teams t where t.organization_id = o.id),
         (select count(distinct m.user_id)::int from public.organization_memberships m where m.organization_id = o.id),
         (select count(*)::int from public.client_accounts a where a.organization_id = o.id),
         (select count(*)::int from up where up.organization_id = o.id),
         (select count(*)::int from up where up.organization_id = o.id and up.cover_state = 'covered'),
         (select count(*)::int from up where up.organization_id = o.id
                                       and up.cover_state in ('open', 'pending_acknowledgement')),
         (select count(*)::int from up where up.organization_id = o.id
                                       and up.cover_state in ('not_covered', 'no_longer_covered'))
  from public.organizations o
  where exists (select 1 from me)
  order by o.name, o.id;
$$;
revoke all on function public.platform_overview() from public, anon;
grant execute on function public.platform_overview() to authenticated;
comment on function public.platform_overview() is
  'PLATFORM1 (ADR-213): counts per organisation for NAVORA operations only (Blueprint V3.2 §2.4). No person, '
  'address, care content or money.';
