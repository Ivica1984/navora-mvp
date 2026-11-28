-- ADM2-16: a member without a recorded qualification performs no visit (PO brief docs/agents/briefs/ADM2.md ADM2-16,
-- po 2026-10-29 10:15; `cra` CGR-92, blocking for ADM2 acceptance, S2; `lca` 09:45: compliant under every plausible
-- interpretation; ADR-117).
-- No clinical rule: this is the gate ADM2-6 already states ("never responsible or covering until her qualification is
-- recorded"), applied to performing a visit. Whether a visit already performed by such a member is billable stays D-29
-- (no billing rule is coded from this criterion).
--
-- Before (IMPLEMENTED defect, CGR-92): 0091 made `team_memberships.qualification` nullable for a member admitted by
--   her team. Planning, take, PLAN2, cover and the `care_visits` backstop refuse her as responsible, but `start_visit`
--   and `complete_visit` run as the member (`private.transition_visit`, security invoker, 0007), any team member may
--   update the visit status (0003 column grant) and `private.enforce_visit_transition` checked qualification only for
--   category B and needs assessments (CGR-12, 0038/0090). She could depart, start and complete any other visit of her team.
-- Now (IMPLEMENTED in this migration):
--   1. `private.actor_may_perform_visit(team, cover_team, covered_by)`: the caller (auth.uid()) has a recorded
--      qualification in the visit's team, or she is the covering nurse of a covered visit and has one in the cover team.
--      It answers only about the caller (no user parameter), so it cannot be used to probe a colleague.
--   2. Command path (`depart_visit`, `start_visit`, `resume_visit`, `complete_visit` through `private.transition_visit`):
--      after the VIS1 day rule and before the state update, a transition into `on_the_way`, `started` or `completed` by
--      such a caller returns `qualification_missing`. Nothing changes (status, `visit_events`); ONE `audit_events` row
--      through `private.write_visit_refusal` (outcome code, no idempotency key, ADR-111 (3)). Order: begin_command →
--      visibility → day rule → qualification → state. A caller outside the team gets the command's own `rejected`.
--   3. Direct path: `private.enforce_visit_transition` refuses the same transitions for such a caller with
--      `qualification_missing` (errcode 42501, as the ADM2-6 backstop in 0091). The statement is rolled back, so no row
--      is written (as VIS1-9 for direct writes); the app never writes status directly.
-- Unchanged: members with a recorded qualification (every seeded member); pause (`started` -> `paused`); CGR-12 (B and
--   needs assessment by a registered nurse); VIS1 day rule; `record_no_show` and `end_visit_not_completed` (SECURITY
--   DEFINER, they do not write through the authenticated branch of the trigger and record that a visit did not happen
--   or was interrupted, not that care was given; ADR-117 deviation 1).
-- Idempotent: create or replace; the transition_visit patch carries a marker and is skipped when present.

-- 1. The caller may perform a visit of this team -----------------------------------------------------------------------
create or replace function private.actor_may_perform_visit(p_team uuid, p_cover_team uuid, p_covered_by uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.has_qualification(p_team, (select auth.uid()))
      or (p_cover_team is not null and p_covered_by = (select auth.uid())
          and private.has_qualification(p_cover_team, (select auth.uid())))
$$;
revoke all on function private.actor_may_perform_visit(uuid, uuid, uuid) from public, anon;
grant execute on function private.actor_may_perform_visit(uuid, uuid, uuid) to authenticated;
comment on function private.actor_may_perform_visit(uuid, uuid, uuid) is
  'ADM2-16 / CGR-92 / ADR-117: the caller has a recorded qualification in the visit''s team, or is the covering nurse '
  'of a covered visit with one in the cover team. Answers only about auth.uid().';

-- 2. Command path: the refusal with its audit row ------------------------------------------------------------------------
create or replace function private.visit_qualification_refusal(p_command text, p_visit_id uuid, p_to text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v public.care_visits%rowtype;
begin
  if p_to not in ('on_the_way', 'started', 'completed') then
    return null;   -- pause passes
  end if;
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then
    return null;   -- not visible to her: the command's own check refuses it
  end if;
  if private.actor_may_perform_visit(v.team_id, v.cover_team_id, v.covered_by) then
    return null;
  end if;
  return private.write_visit_refusal(v, p_command, 'qualification_missing');
end;
$$;
revoke all on function private.visit_qualification_refusal(text, uuid, text) from public, anon;
grant execute on function private.visit_qualification_refusal(text, uuid, text) to authenticated;
comment on function private.visit_qualification_refusal(text, uuid, text) is
  'ADM2-16 / CGR-92 / ADR-117: depart, start, resume and complete refuse a caller without a recorded qualification '
  'with qualification_missing; one audit row per refusal; null when the action may go on. Team members only.';

do $$
declare
  fn     regprocedure := 'private.transition_visit(text, uuid, text[], text, uuid)'::regprocedure;
  def    text := pg_get_functiondef(fn);
  p_from text := E'  update public.care_visits set status = p_to\n';
  p_to   text := E'  -- ADM2-16 / CGR-92: no visit without a recorded qualification; one audit row, nothing else changes.
  declare
    adm2_out text := private.visit_qualification_refusal(p_command, p_visit_id, p_to);
  begin
    if adm2_out is not null then
      return private.end_command(adm2_out);
    end if;
  end;
  update public.care_visits set status = p_to\n';
begin
  if position('ADM2-16 / CGR-92' in def) > 0 then
    return;   -- already applied
  end if;
  if (length(def) - length(replace(def, p_from, ''))) / length(p_from) <> 1 then
    raise exception 'ADM2-16 patch for transition_visit must match exactly once';
  end if;
  execute replace(def, p_from, p_to);
end;
$$;

-- 3. Direct path: the state machine ----------------------------------------------------------------------------------------
-- Same body as 0090 plus the ADM2-16 block after CGR-12.
create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  vis1_out text;
begin
  if current_user = 'authenticated' and new.status is distinct from old.status then
    if not ((old.status, new.status) in (
      ('planned',    'on_the_way'),
      ('planned',    'started'),
      ('on_the_way', 'started'),
      ('started',    'paused'),
      ('paused',     'started'),
      ('started',    'completed')
    )) then
      raise exception 'visit transition % -> % is not allowed', old.status, new.status
        using errcode = '23514';
    end if;
    if old.suspended_at is not null then
      raise exception 'the visit is suspended because the case is paused' using errcode = '23514';
    end if;
    -- VIS1-9 / CGR-90: the visit's day on every write path (the later of the old and new date, so a combined write
    -- cannot move the date and start in one statement).
    vis1_out := private.visit_status_day_refusal(old.id, greatest(old.visit_date, new.visit_date), old.status, new.status);
    if vis1_out is not null then
      raise exception '%', vis1_out using errcode = '23514', hint = 'VIS1: the visit is worked on its day (Europe/Zurich)';
    end if;
    -- CGR-12: every transition into `started` (first start and resume) and into `completed`.
    if new.status in ('started', 'completed')
       and (coalesce(new.planned_minutes_b, 0) > 0 or new.is_needs_assessment)
       and not private.is_registered_nurse(new.team_id, (select auth.uid())) then
      raise exception 'category B and needs-assessment visits are started, resumed and completed by a registered nurse'
        using errcode = 'NV001';
    end if;
    -- ADM2-16 / CGR-92: no depart, start, resume or completion without a recorded qualification.
    if new.status in ('on_the_way', 'started', 'completed')
       and not private.actor_may_perform_visit(new.team_id, new.cover_team_id, new.covered_by) then
      raise exception 'qualification_missing' using errcode = '42501',
        hint = 'ADM2-16: a member performs visits once her qualification is recorded';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_visit_transition() from public, anon, authenticated;
