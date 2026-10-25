-- RLS2: visit and case records are read only by the people who care for the client (brief docs/agents/briefs/RLS2.md,
-- ADR-080, read-path inventory docs/engineering/READ_PATHS.md). D-3 real-data gate (iv); D-23 precondition 3 (a).
--
-- Before this migration (catalogue, local run 2026-10-25):
--   * `visit_events` (0007), `visit_time_corrections` (0008) and `case_tasks` (0013) were readable by EVERY member of the
--     organisation through the table API (`org_members_read`).
--   * `team_decisions` was already narrowed by 0017 to the deciding team PLUS every coordination role (admin, coach,
--     operations), free-text `reason` included. The brief lists it as organisation-wide (0011); the code had moved on.
--     Deviation recorded in the status row; the narrowing below still applies.
--   * `public.uncovered_visits()` (0014) returned visit, team, date and time of every uncovered visit of the
--     organisation to every member (`is_org_member` only). No screen calls it (src/: no `.rpc("uncovered_visits")`).
--   * `public.matching_escalations()` and `private.matching_escalations_for()` returned the declining teams' free-text
--     `reason` to coordination roles. No screen calls either (src/: no `.rpc("matching_escalations")`).
--
-- After this migration (ADR-080):
--   1. Row scope of the four tables (table API):
--        (a) an active member of the row's team, directly (`team_id`) or through the row's visit (its team) or case
--            (its assigned team);
--        (b) for the two visit-linked tables only: the covering member of a covered visit while her cover is active:
--            `care_visits.covered_by` = her, she is still a member of the cover team (`cover_team_id`) and of the
--            organisation, and the visit has no `final` report yet (D-3 PO 2026-10-22 14:30: "from acceptance until its
--            report is final"). A withdrawn cover clears `covered_by` (0029), so the read ends with it.
--        (c) coordination roles: none. Operations, coaches and administrators read these facts only through the
--            `security definer` read models named in READ_PATHS.md (OPS1, SIG1, AN1/AN2, intake), never row by row.
--      A removed member reads nothing of her former team at once: membership is a row in `team_memberships`, deleted on
--      removal (0035-0037), and every predicate reads it at query time.
--   2. Free text: `visit_time_corrections.reason` and `team_decisions.reason` are returned only under (a)/(b) (row scope
--      above) and by the team's own read models (`field_visits`, 0006/0008, `visit_report_snapshot`). The two escalation
--      readers drop the decline `reason`: the code, team and time stay (J2 escalation task). No column grant changes:
--      `field_visits` is SECURITY INVOKER and reads `reason` for the caller's own team, which (a) already allows.
--   3. `uncovered_visits()` is narrowed to coordination roles (its stated purpose: "Operations", 0014:495) and the
--      members of the visit's own team.
-- Nothing is widened. No signal, threshold, priority, clinical rule or screen changes. Idempotent: re-running drops and
-- re-creates the same policies and functions; the text patch of the escalation readers is a no-op once applied.

-- 1. Predicates ---------------------------------------------------------------------------------------------------------
-- Is the caller one of the people caring for this visit? (a) a member of the visit's team; (b) its active covering member.
create or replace function private.reads_visit(p_visit uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.care_visits v
    where v.id = p_visit
      and private.is_org_member(v.organization_id)
      and (private.is_team_member(v.team_id)
           or (v.covered_by = (select auth.uid())
               and v.cover_team_id is not null
               and private.is_team_member(v.cover_team_id)
               and not exists (select 1 from public.visit_reports r where r.visit_id = v.id and r.status = 'final')))
  );
$$;

-- Is the caller a member of the team the case is assigned to? (no cover: a cover is one visit, never the case)
create or replace function private.reads_case(p_case uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.cases c
    where c.id = p_case
      and c.assigned_team_id is not null
      and private.is_org_member(c.organization_id)
      and private.is_team_member(c.assigned_team_id)
  );
$$;

revoke all on function private.reads_visit(uuid), private.reads_case(uuid) from public, anon;
grant execute on function private.reads_visit(uuid), private.reads_case(uuid) to authenticated;

comment on function private.reads_visit(uuid) is
  'RLS2 (ADR-080): the caller is a member of the visit''s team, or its active covering member (covered_by, still in the cover team, no final report yet).';
comment on function private.reads_case(uuid) is
  'RLS2 (ADR-080): the caller is a member of the team the case is assigned to.';

-- 2. Row scope of the four tables -----------------------------------------------------------------------------------------
drop policy if exists org_members_read on public.visit_events;
drop policy if exists team_scoped_read on public.visit_events;
create policy team_scoped_read on public.visit_events
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_team_member(team_id) or private.reads_visit(visit_id)));

drop policy if exists org_members_read on public.visit_time_corrections;
drop policy if exists team_scoped_read on public.visit_time_corrections;
create policy team_scoped_read on public.visit_time_corrections
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_team_member(team_id) or private.reads_visit(visit_id)));

-- 0017 `scoped_read` let every coordination role read every team's decision and its free-text reason.
drop policy if exists org_members_read on public.team_decisions;
drop policy if exists scoped_read on public.team_decisions;
drop policy if exists team_scoped_read on public.team_decisions;
create policy team_scoped_read on public.team_decisions
  for select to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id));

drop policy if exists org_members_read on public.case_tasks;
drop policy if exists team_scoped_read on public.case_tasks;
create policy team_scoped_read on public.case_tasks
  for select to authenticated
  using (private.is_org_member(organization_id) and private.reads_case(case_id));

-- 3. Escalation readers: no decline free text (code, team and time stay) -------------------------------------------------
do $$
declare
  fn  text;
  def text;
  pat constant text := '''reason'', d.reason, ';
begin
  foreach fn in array array['public.matching_escalations()', 'private.matching_escalations_for(uuid)'] loop
    def := pg_get_functiondef(fn::regprocedure);
    if position(pat in def) > 0 then
      if (length(def) - length(replace(def, pat, ''))) / length(pat) <> 1 then
        raise exception 'RLS2: expected exactly one decline reason in %', fn;
      end if;
      execute replace(def, pat, '');
    end if;
  end loop;
end
$$;

-- 4. uncovered_visits(): Operations (coordination roles) and the visit's own team, not every member ----------------------
create or replace function public.uncovered_visits()
returns table (visit_id uuid, team_id uuid, team_name text, visit_date date, time_start time)
language sql stable security definer set search_path = ''
as $$
  select v.id, t.id, t.name, v.visit_date, v.time_start
  from public.care_visits v
  join public.teams t on t.id = v.team_id
  where private.is_org_member(v.organization_id)
    and (private.is_coordinator(v.organization_id) or private.is_team_member(v.team_id))
    and 'uncovered' = any (private.visit_flags(v.case_id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start))
  order by v.visit_date, v.time_start;
$$;

revoke all on function public.uncovered_visits() from public, anon;
grant execute on function public.uncovered_visits() to authenticated;
