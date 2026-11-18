-- BK-e1b CGR-233 (brief docs/agents/briefs/BK.md criterion 3, PO 2026-11-17 09:39 (4); ADR-202 (4), ADR-203 (4), (19)).
-- Gate «Simulation, synthetic data» only. No clinical, legal or tariff rule is set or changed here.
--
-- A take writes a visit for its named member in the same transaction (0138) under the person lock
-- `order_take_member:<member>`; `take_order` takes that lock before its step-3 availability check (0135, CGR-229).
-- The hand-assignment paths (plan_visit, reschedule_visit, move_visit_to_today, take_open_visit, AIG1 apply through
-- private.plan3_confirm_overlaps) never refuse for an overlap; they all read the one member-overlap definition
-- `private.member_visit_overlap` (PLAN3-16, ADR-161) after their write, under the `plan3_busy:<member>:<day>` lock only.
-- The two locks never met, so a take and a hand assignment of the same member could each read the other as absent:
-- a hand path reported `member_overlap: false` beside a live take visit, or a take passed step 3 beside an
-- overlapping visit just assigned to her (scripts/db-concurrency/take-visit.sh, red before this migration).
--
-- Change: `private.member_visit_overlap` takes `order_take_member:<member>` first, then `plan3_busy:<member>:<day>`,
-- then reads. Every hand path holds its own write by then, so whichever transaction takes the person lock first is
-- seen by the other: the hand path reports the take visit as an overlap, or the take refuses with step 3.
-- Lock order: the person lock before plan3_busy everywhere (no path takes plan3_busy and then the person lock).
-- Nothing is refused that was not refused before; result shapes, signatures and grants are unchanged.
-- Not changed (named reason, ADR-203 (19)): COVER1 `accept_cover` (sets covered_by, has no member-overlap reading and
-- refuses nothing for one, so any interleaving equals the serial order «take, then cover»); the PLAN2 series by rule.
-- Idempotent: create or replace with the full body (marker BK-E1B-L).

create or replace function private.member_visit_overlap(p_visit_id uuid, p_user uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v public.care_visits%rowtype;
begin
  select * into v from public.care_visits x where x.id = p_visit_id;
  if not found or p_user is null then
    return false;
  end if;
  -- BK-E1B-L (CGR-233): the take's person lock first, so a take of this member and this reading serialise.
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || p_user::text, 0));
  -- PLAN3-14 / PLAN3-16: serialise every assignment of one member and day (PLAN3 confirm and the hand paths).
  perform pg_advisory_xact_lock(hashtextextended('plan3_busy:' || p_user::text || ':' || v.visit_date::text, 0));
  return exists (
    select 1 from public.care_visits x
    where x.organization_id = v.organization_id and x.visit_date = v.visit_date and x.status <> 'cancelled'
      and x.responsible_user_id = p_user and x.id <> v.id
      and private.visit_interval(x) && private.visit_interval(v));
end;
$$;
revoke all on function private.member_visit_overlap(uuid, uuid) from public, anon, authenticated;
comment on function private.member_visit_overlap(uuid, uuid) is
  'PLAN3-14 (2) / PLAN3-16 (ADR-146, ADR-161): whether the member has another non-cancelled visit that day (any team of '
  'the organisation) whose planned interval overlaps the visit. Takes the order_take_member person lock (BK-e1b CGR-233, '
  'ADR-203 (19), marker BK-E1B-L) and then the plan3_busy advisory lock on member and day. '
  'Internal: no permission check; nothing but the yes/no reaches a caller.';
