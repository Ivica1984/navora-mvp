-- HD-3s-F2-F1-F1 criterion 4 (`uxa` UXR-302; brief docs/agents/briefs/HD-3s-F2-F1-F1.md; ADR-230): the pre-save note of
-- the /team «Einsatz planen» and «Einsatz verschieben» forms must not read as plain information when the chosen time
-- lies in the window of the chosen person's live take (pause included), because the save is then always refused
-- (plan_visit / reschedule_visit / guard_take_window: member_take_window). public.member_slot_overlap answers yes/no only
-- and cannot tell the two cases apart; changing its return type would change every caller. New read, yes/no only:
--   public.member_slot_take_window(same arguments) → null exactly where member_slot_overlap is null (it calls it for
--   every guard: LEAVE1-3, the visit's or case's team, a member of that team, a complete slot), false where it is false,
--   else whether member_take_window finds a live take of that member meeting the slot (the take a moved visit was
--   written from never counts). Nothing about the take (no date, block, home or order): less than the hand-path refusal
--   already tells the same caller (CGR-289 (c)). Writes nothing.
-- SECURITY DEFINER, empty search_path, execute for authenticated and service_role only (as member_slot_overlap).
-- Fixed, checkable rule; no AI. Idempotent: create or replace + revoke + grant + comment.
-- Deploy window: migration before app → the old app never calls it; app before migration → the read fails, the hook
-- treats it as no take window and the note stays the information sentence (the save is still refused server-side).
-- Way back: drop function public.member_slot_take_window(uuid, uuid, uuid, date, time, time).

create or replace function public.member_slot_take_window(p_case_id uuid, p_visit_id uuid, p_member_id uuid,
                                                          p_visit_date date, p_time_start time, p_time_end time)
returns boolean
language plpgsql
stable security definer
set search_path to ''
as $function$
declare
  ov  boolean;
  rng tstzrange;
begin
  -- Every guard of member_slot_overlap (LEAVE1-3, team scope, member of that team, complete slot): null where it is
  -- null. No overlap at all: no take window either.
  ov := public.member_slot_overlap(p_case_id, p_visit_id, p_member_id, p_visit_date, p_time_start, p_time_end);
  if ov is distinct from true then
    return ov;
  end if;
  rng := private.visit_interval(jsonb_populate_record(null::public.care_visits, jsonb_build_object(
           'visit_date', p_visit_date, 'time_start', p_time_start, 'time_end', p_time_end)));
  return private.member_take_window(p_member_id, rng,
           (select x.order_take_id from public.care_visits x where x.id = p_visit_id)) is not null;
end;
$function$;

revoke all on function public.member_slot_take_window(uuid, uuid, uuid, date, time, time) from public, anon, authenticated, service_role;
grant execute on function public.member_slot_take_window(uuid, uuid, uuid, date, time, time) to authenticated;
grant execute on function public.member_slot_take_window(uuid, uuid, uuid, date, time, time) to service_role;
comment on function public.member_slot_take_window(uuid, uuid, uuid, date, time, time) is 'HD-3s-F2-F1-F1 (UXR-302, ADR-230): whether the busy answer of member_slot_overlap comes from the window of the member''s live take (pause included; member_take_window), so the save will be refused. Null where member_slot_overlap is null (same guards, LEAVE1-3), false where it is false. yes/no only: nothing about the take. Writes nothing.';
