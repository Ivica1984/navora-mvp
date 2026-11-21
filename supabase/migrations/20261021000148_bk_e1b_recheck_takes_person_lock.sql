-- BK-e1b CGR-255 (CGR-233 condition, brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 13:39 (1); ADR-203 (20)).
-- Gate «Simulation, synthetic data» only. No clinical, legal or tariff rule is set or changed here.
--
-- Serial behaviour (IMPLEMENTED, 0135 §10, 0138 §3, 0139): a hand write that gives a member a visit overlapping one of
-- her live takes before its start fires `bk_c1_recheck_takes`; `private.recheck_member_takes` re-runs
-- `order_member_step`, step 3 fails, the take is released (`step_3`), its visit is cancelled and the order goes back to
-- the broadcast. Race (found by `cra` 13:29, CGR-255): the re-check read her takes without the person lock, so while a
-- take naming her was still uncommitted it saw nothing and released nothing; 0147 only serialised the later overlap
-- reading. After both commits the take stood «gedeckt» beside an overlapping visit of the same person.
--
-- Change: `private.recheck_member_takes` takes `order_take_member:<member>` before it reads her takes (a new statement,
-- so in READ COMMITTED it reads the committed take after the wait). `private.recheck_takes_trigger` takes the person
-- locks of a care_visits row (responsible member, covering member) in one fixed order (uuid order) first, so two
-- writes naming the same two people never wait on each other in a cycle. The lock is re-entrant in the take's own
-- session. Lock order stays: order row, then person, then plan3_busy.
-- Nothing is refused that was not refused before; result shapes, signatures, grants and the CGR-244 filter
-- (`take_visit_under_way`, 0139) are unchanged. Idempotent: create or replace with the full bodies (marker BK-E1B-S).

create or replace function private.recheck_member_takes(p_user uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  k    record;
  step integer;
begin
  if p_user is null then return; end if;
  -- BK-E1B-S (CGR-255): the take's person lock before reading her takes, so a take of hers still in flight is waited
  -- for and then seen as committed (the serial outcome «take, then hand»).
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || p_user::text, 0));
  for k in
    select t.id, t.order_id, t.team_id, t.member_id
    from public.order_takes t join public.partner_requests p on p.id = t.order_id
    where t.member_id = p_user and t.released_at is null and p.starts_at > private.now()
      and not private.take_visit_under_way(t.id)  -- BK-E1B-R (CGR-244): never while her visit is under way
    order by p.starts_at, t.id
  loop
    step := private.order_member_step(k.order_id, k.team_id, k.member_id);
    if step < 4 then
      update public.order_takes set released_at = private.now(), release_reason = 'step_' || step where id = k.id;
      -- CGR-223 (c): back to the broadcast after a fresh hard check of every team (the releasing team included).
      perform private.screen_order_reach(k.order_id, private.order_round(k.order_id) + 1);
    end if;
  end loop;
end;
$$;
revoke all on function private.recheck_member_takes(uuid) from public, anon, authenticated;
comment on function private.recheck_member_takes(uuid) is
  'BK-c1 (ADR-199 (5), CGR-223): releases every live take of the member before its start whose member no longer '
  'reaches step 4, and sends the order back to the broadcast. Never while her visit is under way (CGR-244). Takes the '
  'order_take_member person lock before reading (BK-e1b CGR-255, ADR-203 (20), marker BK-E1B-S). Internal.';

create or replace function private.recheck_takes_trigger()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_table_name = 'care_visits' then
    -- BK-E1B-S (CGR-255): both person locks of the row in one fixed order before either re-check (no wait cycle).
    if new.responsible_user_id is not null and new.covered_by is not null
       and new.covered_by is distinct from new.responsible_user_id then
      perform pg_advisory_xact_lock(hashtextextended('order_take_member:'
                || least(new.responsible_user_id, new.covered_by)::text, 0));
      perform pg_advisory_xact_lock(hashtextextended('order_take_member:'
                || greatest(new.responsible_user_id, new.covered_by)::text, 0));
    end if;
    perform private.recheck_member_takes(new.responsible_user_id);
    perform private.recheck_member_takes(new.covered_by);
  elsif tg_table_name = 'team_memberships' then
    -- Writer list (ADR-199 (5), pgTAP 142): `remove_team_member` deletes the row and writes no access event.
    if tg_op in ('DELETE', 'UPDATE') then perform private.recheck_member_takes(old.user_id); end if;
    if tg_op = 'UPDATE' and new.user_id is distinct from old.user_id then
      perform private.recheck_member_takes(new.user_id);
    end if;
  else
    perform private.recheck_member_takes(new.user_id);
  end if;
  return null;
end;
$$;
revoke all on function private.recheck_takes_trigger() from public, anon, authenticated;
