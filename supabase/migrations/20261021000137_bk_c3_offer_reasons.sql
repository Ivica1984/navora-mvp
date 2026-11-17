-- BK-c3: reasons on the team's own offer list (brief docs/agents/briefs/BK.md §PO amendment 2026-11-17 17:39; ADR-201;
-- pgTAP 146). Gate «Simulation, synthetic data» only.
--
-- The reasons explain an open offer of ONE team, from stored facts only; they never rank teams against each other, never
-- add or remove an offer row (AUT-128 / V-8), and never reach the client or another team (FE-078 (2), ADR-199 (8),
-- D-44 (2) (a)). List order stays A (`starts_at` first, then ids; PO 17:39 (2), CGR-236 (a)). Engine 2 stays a rule
-- (AUT-115): no AI call, no `ai_suggestions` row (D-35 rule A).
--
-- Codes (never words, never a number):
--   member_free   at least one active member of the team is at step 4 of private.order_member_step now (AUT-130).
--   knows_client  the same team holds a take of an earlier order for the same client account whose slot has ended,
--                 that was acknowledged and never released (PO 17:39 (3); no time window in Phase A; the window before
--                 real persons is OPEN with the PO and the Clinical Owner). Not a statement of clinical suitability.
-- Not built (PO 17:39 (4)-(6)): holds_all_tags (step 2 checks evidence only for «E» cells, 0133), language (no source),
-- price (AUT-119 (c)), within_reach (true on every offer row; UXR-233).
--
-- No table, no column, no grant on a table, no write: nothing to audit. Idempotent: `create or replace`, and the read
-- model is dropped and created (its return type grows, as in 0136).

-- 1. The clause codes of one (order, team) --------------------------------------------------------------------------------
create or replace function private.order_offer_reasons(p_order_id uuid, p_team_id uuid)
returns text[] language sql stable security definer set search_path = ''
as $$
  select array_remove(array[
    case when exists (select 1 from public.team_memberships m
                      where m.team_id = p_team_id
                        and private.order_member_step(p_order_id, p_team_id, m.user_id) = 4)
         then 'member_free' end,
    case when exists (select 1 from public.order_takes t
                      join public.partner_requests q on q.id = t.order_id
                      join public.partner_requests o on o.id = p_order_id
                      where t.team_id = p_team_id
                        and q.id <> o.id
                        and q.client_account_id = o.client_account_id
                        and q.ends_at <= private.now()
                        and t.acknowledged_at is not null
                        and t.released_at is null)
         then 'knows_client' end
  ], null)
$$;
revoke all on function private.order_offer_reasons(uuid, uuid) from public, anon, authenticated;
comment on function private.order_offer_reasons(uuid, uuid) is
  'BK-c3 / ADR-201: clause codes for one open offer of one team (member_free, knows_client), each from a stored fact; '
  'empty when no fact holds. Never a rank, score or count; read only through public.team_order_offers(). Private.';

-- 2. The team's offer list gains `reasons` (body of 0136 unchanged otherwise) ---------------------------------------------
drop function if exists public.team_order_offers();
create function public.team_order_offers()
returns table (order_id uuid, team_id uuid, sentence text, starts_at timestamptz, ends_at timestamptz,
               duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[],
               required_tags text[], distance_km numeric, limit_km numeric, offer_state text, taken_member_id uuid,
               taken_by uuid, taken_at timestamptz, acknowledged_at timestamptz, latest_cover_at timestamptz,
               caller_free boolean, release_kind text, released_member_id uuid, reasons text[])
language sql stable security definer set search_path = ''
as $$
  with last_release as (
    select distinct on (x.order_id) x.order_id, x.team_id, x.member_id, x.taken_by, x.taken_at, x.acknowledged_at,
           case x.release_reason when 'member_cannot' then 'member_cannot' when 'not_acknowledged' then 'not_acknowledged'
                else 'no_longer_eligible' end as kind
    from public.order_takes x
    where x.released_at is not null
    order by x.order_id, x.released_at desc, x.id desc
  )
  select f.order_id, f.team_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, f.distance_km, f.limit_km,
         case when k.id is null then 'open' else 'taken_by_us' end, k.member_id,
         k.taken_by, k.taken_at, k.acknowledged_at, private.order_latest_cover_at(p.id),
         private.order_member_step(p.id, f.team_id, (select auth.uid())) = 4,
         case when k.id is null and r.team_id = f.team_id then r.kind end,
         case when k.id is null and r.team_id = f.team_id then r.member_id end,
         -- BK-c3: reasons explain an open offer only; a taken row carries none.
         case when k.id is null then private.order_offer_reasons(p.id, f.team_id) else '{}'::text[] end
  from public.order_offers f
  join public.partner_requests p on p.id = f.order_id
  left join public.order_takes k on k.order_id = f.order_id and k.released_at is null
  left join last_release r on r.order_id = f.order_id
  where private.is_team_member(f.team_id)   -- LEAVE1-3 inside
    and f.round = private.order_round(f.order_id)
    and p.ends_at > private.now()
    and not exists (select 1 from public.order_declines d
                    where d.order_id = f.order_id and d.round = f.round and d.team_id = f.team_id)
    and (k.id is null or k.team_id = f.team_id)
  union all
  -- CGR-234 (d): the own team's take was released and the new round offers it nothing: it still sees the release.
  select r.order_id, r.team_id, p.request_title, p.starts_at, p.ends_at,
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, null::numeric, null::numeric, 'released', null::uuid,
         r.taken_by, r.taken_at, r.acknowledged_at, private.order_latest_cover_at(p.id), false, r.kind, r.member_id,
         '{}'::text[]
  from last_release r
  join public.partner_requests p on p.id = r.order_id
  where private.is_team_member(r.team_id)
    and p.ends_at > private.now()
    and not exists (select 1 from public.order_takes t where t.order_id = r.order_id and t.released_at is null)
    and not exists (select 1 from public.order_offers f
                    where f.order_id = r.order_id and f.team_id = r.team_id and f.round = private.order_round(r.order_id))
  order by 4, 1, 2
$$;
revoke all on function public.team_order_offers() from public, anon;
grant execute on function public.team_order_offers() to authenticated;
comment on function public.team_order_offers() is
  'BK-c1/c2/c3 (ADR-199, ADR-200, ADR-201): the caller''s own teams'' shift-order offers, ordered by starts_at then ids '
  '(order A). `reasons` are clause codes for an open row only; no rank, no other team, no count.';
