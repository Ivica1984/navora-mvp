-- PLAN3-9 (1) (`cra` CGR-138, advisory S3; PO note 2026-11-06 06:30 in PO PR #893, a PLAN3 acceptance condition):
-- a decided day-plan line never reads as a covered visit. ADR-156. Corrects 0109 (ADR-145), which is not changed in
-- place so its reviewed head stays as it was.
--
-- Before (IMPLEMENTED in 0109): `day_plan` returned the decision state of each line but no fact about the visit
-- itself. After "Ablehnen" or a decided "kein Vorschlag", `confirm_suggestion` writes nothing to `care_visits`
-- (0097), so the visit still has no responsible member, but the screen could not say so.
-- Now (IMPLEMENTED in this migration): one more column
--   * visit_has_responsible   boolean: the visit has a responsible member now (`care_visits.responsible_user_id` is
--                             not null). Yes/no only: no name, no member id, no other column. The team already reads
--                             the responsible member of its own visits on `/visits/<id>` (team scope), so no new read
--                             is granted to any role.
-- Everything else is exactly 0109: the newest proposal of the team and day, its active members only (LEAVE1-3,
-- `is_org_member`, `is_team_member`), no confirmer, the same columns in the same order before the new last one.
-- No clinical rule, no threshold: the screen shows "Noch offen" (the existing `/visits` wording) for a decided line
-- whose visit has nobody; the wording of the decided "kein Vorschlag" is the app's (OPEN for `uxa`).
-- The return type changes, so the function is dropped and created again (in one transaction of the migration run);
-- no view, policy or other SQL function depends on it (the app calls it through RPC). No table, so no RLS policy,
-- column grant or audit trigger is added; the reader writes nothing. Idempotent: `drop function if exists` first.

drop function if exists public.day_plan(uuid, date);

create function public.day_plan(p_team_id uuid, p_date date)
returns table (suggestion_id uuid, proposal_id uuid, proposed_at timestamptz, visit_id uuid, case_id uuid,
               time_start time, time_end time, minutes_a integer, minutes_b integer, minutes_c integer,
               is_needs_assessment boolean, member_id uuid, member_name text, reason text, known_visits integer,
               not_found_reason text, changes_assignment boolean, not_continuity boolean, decision text,
               bulk_allowed boolean, visit_has_responsible boolean)
language sql stable security definer set search_path = ''
as $$
  with newest as (
    select dl.proposal_id from public.day_plan_lines dl
    where dl.team_id = p_team_id and dl.plan_date = p_date
    order by dl.created_at desc, dl.suggestion_id limit 1
  )
  select s.id, dl.proposal_id, s.created_at, v.id, v.case_id, v.time_start, v.time_end, v.planned_minutes_a,
         v.planned_minutes_b, v.planned_minutes_c, v.is_needs_assessment,
         (s.proposed_value #>> '{}')::uuid,
         case when not s.not_found then private.member_name(s.organization_id, (s.proposed_value #>> '{}')::uuid) end,
         dl.reason, dl.known_visits, dl.not_found_reason,
         dl.assigned_before is not null and not s.not_found
           and dl.assigned_before is distinct from (s.proposed_value #>> '{}')::uuid,
         not s.not_found and (s.proposed_value #>> '{}')::uuid is distinct from c.primary_nurse_id
           and (s.proposed_value #>> '{}')::uuid is distinct from c.deputy_nurse_id,
         coalesce((select k.outcome from public.ai_confirmations k where k.suggestion_id = s.id
                   order by k.seq desc limit 1), 'open'),
         not s.not_found and not exists (select 1 from public.ai_confirmations k where k.suggestion_id = s.id)
           and not exists (select 1 from public.ai_one_by_one_fields o where o.organization_id = s.organization_id
                           and o.agent_key = s.agent_key and o.field = s.field),
         v.responsible_user_id is not null                                                    -- PLAN3-9 (1)
  from newest nw
  join public.day_plan_lines dl on dl.proposal_id = nw.proposal_id
  join public.ai_suggestions s on s.id = dl.suggestion_id
  join public.care_visits v on v.id = dl.visit_id
  join public.cases c on c.id = v.case_id
  where not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(dl.organization_id) and private.is_team_member(dl.team_id)
  order by v.time_start nulls last, v.time_end nulls last, v.id::text
$$;
revoke all on function public.day_plan(uuid, date) from public, anon;
grant execute on function public.day_plan(uuid, date) to authenticated;
comment on function public.day_plan(uuid, date) is
  'PLAN3-3/-9: the newest day-plan proposal of a team and day for its active members: visit time and minutes per '
  'category, proposed member and reason (or the limit for "kein Vorschlag"), "ändert bisherige Zuteilung", "nicht '
  'Bezugspflege/Stellvertretung", the decision state, and (PLAN3-9 (1), 0115) whether the visit has a responsible '
  'member now, yes/no only. No confirmer.';
