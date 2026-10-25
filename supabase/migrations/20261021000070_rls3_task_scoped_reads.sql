-- RLS3: coordination roles and teammates read no more than their task needs (brief docs/agents/briefs/RLS3.md, ADR-083,
-- inventory docs/engineering/READ_PATHS.md findings F-2, F-4, F-5). D-3 real-data gate (iv); D-23 item 9; Q13 (po
-- 2026-10-25 08:10 CET); RLS3-4b (po 2026-10-25 10:12, sharpened 12:12 CET; CGR-55).
--
-- Before this migration (catalogue, local run 2026-10-25):
--   * `visit_status_notes` (0024) inherited the visit's RLS (`care_visits`: team + every coordination role), so admin,
--     coach and Operations read every team's no-show and interruption note row by row through the table API.
--   * `cover_events` (0028) and `working_time_facts` (0022) named `private.is_coordinator` in their policies: the same
--     organisation-wide coordination read.
--   * `visit_events.actor_id` and `visit_time_corrections.actor_id` were selectable by every reader of the row (team,
--     cover; 0066), so a teammate could list which colleague recorded which event and when (F-4, D-23 term b).
--   * No function returned a visit's correction history with two levels (RLS3-4b).
--   Every read model over these tables that a coordination role uses is SECURITY DEFINER (catalogue: the only INVOKER
--   reader is `field_visits`, which joins the caller's own team memberships and reads no `actor_id`), so narrowing the
--   table policies empties no read model (RLS3-2; brief open question 1).
--
-- After this migration (ADR-083):
--   1. Table-API row scope (RLS3-1):
--        `visit_status_notes`: an active member of the visit's team or its active covering member (`private.reads_visit`).
--        `cover_events`:       an active member of the visit's team, or the nurse the event names (own row). The row's
--                              own `team_id` is the covering nurse's team (accepted events); it is NOT used, because it
--                              would widen the read to that team (deviation from the brief's generic wording).
--        `working_time_facts`: an active member of the row's team.
--      No coordination role reads a row of a team it is not a member of. Operations, coaches and administrators keep
--      their read models (OPS1, SIG1, AN1/AN2, billing), which are SECURITY DEFINER and unchanged.
--   2. `actor_id` of `visit_events` and `visit_time_corrections` is not selectable by `authenticated` (column grants:
--      every other column stays selectable; RLS3-4). A member's identity together with an event or correction time is
--      returned only per visit by the listed readers (READ_PATHS.md, fixed list in pgTAP 071).
--   3. `public.visit_correction_history(visit)` (RLS3-4b): per visit, two levels by who reads:
--        (a) full trail (corrector, time of the correction, old and new value, reason): active members of the visit's
--            team, the active covering member (`private.reads_visit`), and the report's author or its countersigning
--            registered nurse while she is still a member of the visit's team or of its cover team (so a covering author
--            keeps her report's trail after the report is final; a removed member reads nothing, RLS2-7);
--        (b) billing view for every other coordination role of the organisation (the readers of `billing_preview`
--            through `teams_in_scope`): that the visit has a correction, old and new value, time of the correction, and
--            the signed report version the current billing fact is based on with its countersigner; `reason` and the
--            corrector are null. Nobody else reads a row.
--      Both levels also return `in_billed_version` per correction (RLS3-4c, Q15): true when the correction was made at or
--      before the countersignature (the signature when none is required) of the version the current billing fact rests
--      on, false after it, null without a billing fact. Never grouped or counted per person.
-- One read is added, as the brief requires: the active covering member now reads the status notes of the visit she covers
-- (before: no policy admitted her, because `care_visits` has no cover clause); it ends with her cover (0066). Nothing
-- else is widened. No signal, threshold, priority, clinical rule, tariff or screen changes. Idempotent: re-running
-- drops and re-creates the same policies, grants and function.

-- 1. RLS3-1: table-API row scope -------------------------------------------------------------------------------------------
drop policy if exists scoped_read on public.visit_status_notes;
drop policy if exists team_scoped_read on public.visit_status_notes;
create policy team_scoped_read on public.visit_status_notes
  for select to authenticated
  using (private.is_org_member(organization_id) and private.reads_visit(visit_id));

drop policy if exists scoped_read on public.cover_events;
drop policy if exists team_scoped_read on public.cover_events;
create policy team_scoped_read on public.cover_events
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (exists (select 1 from public.care_visits v where v.id = visit_id and private.is_team_member(v.team_id))
              or nurse_id = (select auth.uid())));

drop policy if exists scoped_read on public.working_time_facts;
drop policy if exists team_scoped_read on public.working_time_facts;
create policy team_scoped_read on public.working_time_facts
  for select to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id));

-- 2. RLS3-4: no per-person column through the table API --------------------------------------------------------------------
do $$
declare
  t    text;
  cols text;
begin
  foreach t in array array['visit_events', 'visit_time_corrections'] loop
    select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
    from information_schema.columns
    where table_schema = 'public' and table_name = t and column_name <> 'actor_id';
    execute format('revoke select on public.%I from authenticated', t);
    execute format('revoke select (actor_id) on public.%I from authenticated', t);
    execute format('grant select (%s) on public.%I to authenticated', cols, t);
  end loop;
end
$$;

-- 3. RLS3-4b: the correction trail of one visit, two levels ---------------------------------------------------------------
-- RLS3-4c (Q15, po 2026-10-25 14:13 CET, CGR-59) added `in_billed_version`; drop first so a re-run can change the columns.
drop function if exists public.visit_correction_history(uuid);
create function public.visit_correction_history(p_visit_id uuid)
returns table (
  correction_id bigint,
  event_id bigint,
  event_type text,
  recorded_at timestamptz,            -- the event as recorded
  old_at timestamptz,                 -- value before this correction (previous correction or the recorded time)
  new_at timestamptz,                 -- value after this correction
  corrected_on timestamptz,           -- when the correction was made
  full_trail boolean,                 -- (a) true, (b) false
  reason text,                        -- (a) only
  corrector_name text,                -- (a) only
  corrected_by_me boolean,            -- (a) only
  fact_report_version integer,        -- signed report version the current billing fact is based on (null: no fact yet)
  fact_countersigned_by_name text,    -- its countersigner (already on the report)
  in_billed_version boolean           -- RLS3-4c: correction made at or before that version's countersignature (its
                                      -- signature when none is required); null without a billing fact or that instant
)
language sql stable security definer set search_path = ''
as $$
  with v as (
    select cv.id, cv.organization_id,
           case
             when private.reads_visit(cv.id)
               or (exists (select 1 from public.visit_reports r
                           where r.visit_id = cv.id
                             and (r.performer_id = (select auth.uid()) or r.countersigned_by = (select auth.uid())))
                   and (private.is_team_member(cv.team_id)
                        or (cv.cover_team_id is not null and private.is_team_member(cv.cover_team_id))))
               then 'a'
             when private.is_coordinator(cv.organization_id) then 'b'
           end as lvl
    from public.care_visits cv
    where cv.id = p_visit_id
      and private.is_org_member(cv.organization_id)
  ), fact as (
    select r.version, private.member_name(r.organization_id, r.countersigned_by) as countersigner,
           case when r.countersign_required then r.countersigned_at else r.signed_at end as billed_at
    from v
    join public.billable_facts f on f.visit_id = v.id
    join public.visit_reports r on r.id = f.report_id
    where not exists (select 1 from public.billable_facts s where s.supersedes_id = f.id)
    order by f.created_at desc, f.id desc
    limit 1
  )
  select x.id, e.id, e.event_type, e.occurred_at,
         coalesce((select y.corrected_at from public.visit_time_corrections y
                   where y.event_id = x.event_id and (y.created_at, y.id) < (x.created_at, x.id)
                   order by y.created_at desc, y.id desc limit 1), e.occurred_at),
         x.corrected_at,
         x.created_at,
         v.lvl = 'a',
         case when v.lvl = 'a' then x.reason end,
         case when v.lvl = 'a' then private.member_name(x.organization_id, x.actor_id) end,
         case when v.lvl = 'a' then x.actor_id = (select auth.uid()) end,
         (select fact.version from fact),
         (select fact.countersigner from fact),
         x.created_at <= (select fact.billed_at from fact)
  from v
  join public.visit_time_corrections x on x.visit_id = v.id
  join public.visit_events e on e.id = x.event_id
  where v.lvl is not null
  order by e.id, x.created_at, x.id;
$$;

revoke all on function public.visit_correction_history(uuid) from public, anon;
grant execute on function public.visit_correction_history(uuid) to authenticated;

comment on function public.visit_correction_history(uuid) is
  'RLS3-4b (ADR-083): correction trail of one visit. (a) full trail with reason and corrector for the report''s author and countersigner, the visit''s team and its active covering member; (b) billing view (values and times, no reason, no corrector) for other coordination roles of the organisation. Never per person.';
