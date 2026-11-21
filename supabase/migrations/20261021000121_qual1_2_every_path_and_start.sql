-- QUAL1 part 2, slice 1 (brief docs/agents/briefs/QUAL1.md QUAL1-10, QUAL1-17; issue #931; ADR-164). Stacked on part 1
-- (migration 0120, PR #939). Matrix QAM v0.2, every cell PROPOSED. Passing anything here is NOT a clinical release
-- (CGR-145, CGR-146, FE-039). Remediation plan: clinical/remediation/CGR-145.md.
--
-- What it adds (IMPLEMENTED in this migration):
--   1. `private.qual_may_perform_in(visit, team, user)`: the one answer of part 1 (`private.qual_may_perform`) for a member
--      of a given team (the visit's own team, or the cover team for a covering member). In a simulation organisation:
--      member of that team, access open, every activity `allowed_own` or `allowed_delegated`. Elsewhere it returns
--      exactly `private.may_perform_visit(team, user, visit's KLV-B minutes, visit's needs-assessment flag)`, the call it
--      replaces, so every organisation that is not a simulation keeps CR-007/CR-164 unchanged (QUAL1-1, CGR-145 (e)).
--   2. Every path that asks "may she be responsible for this visit" now asks (1) (QUAL1-10), patched in place, marker
--      `QUAL1-10`: `take_open_visit` (take), `team_open_visits` (the "Übernehmen" flag), `change_absence` (ABS1
--      re-assignment after an absence), `private.aig1_apply_visit_responsible` (AIG1 confirm and re-check of a PLAN3 or
--      cover proposal), `private.plan3_lines` (PLAN3 day proposal: the member is not proposed).
--   3. Backstop on `care_visits` (QUAL1-10, S7): an AFTER row trigger refuses, in a simulation organisation, any write
--      that makes a member responsible for or covering an active visit (`planned`, `on_the_way`, `started`, `paused`)
--      she may not perform, and any move of such a visit (date, time, team) that would leave her so. It covers every
--      other path at once: hand assignment (`plan_visit`), PLAN2 series, swap (both sides: each side is a row write),
--      cover (`accept_cover`), and direct writes. AFTER, so the check reads the written row (an insert included).
--      No override parameter. errcode 42501, message `qualification_not_allowed`.
--   4. Activities added later (QUAL1-6 with QUAL1-10): adding an activity to an active visit whose responsible or covering
--      member may not perform it is refused (`qualification_not_allowed`), so "assign first, add the activity after" is
--      no bypass. Releasing the visit instead (QUAL1-20 (2)) is PLANNED (part 2 slice with QUAL1-20).
--   5. Check at visit start (QUAL1-17, CGR-148, CR-183): a transition into `on_the_way` or `started` (first start and
--      resume) in a simulation organisation runs (1) again for the person doing it; a grade evidence, delegation or a
--      delegating nurse's access that lapsed since planning refuses it (`qualification_lapsed`, 42501). Nothing is
--      written (the statement is rolled back). PLANNED (next slice): the structured command refusal with its audit row,
--      the release of the visit to the team as open with a coverage fact (CR-051 pattern).
-- The refusal names the first activity that fails and its CR-183 label (`ungeklaert`, `nicht_geeignet`); the reason
-- (which may name a member's evidence) only when the caller is that member, an administrator, or the system (CGR-152).
-- Unchanged: every non-simulation organisation (pgTAP 121 proves the fallback is the old call, visit by visit and member
-- by member, on the seed); overlap stays a fact (QUAL1-11); the PLAN3 reason code stays `needs_rn` (deviation, ADR-164:
-- the QUAL1 wording on the screen and in the AN2 split comes with the UI slice).
-- No clinical, tariff or legal rule is invented: the cells are part 1's copy of matrix v0.2 §4.2, all PROPOSED.
-- Idempotent: `create or replace`, `drop … if exists`; every patch carries the marker and is skipped when present.

-- 1. The one answer, for a member of a given team ----------------------------------------------------------------------------
create or replace function private.qual_is_simulation(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((select o.simulation from public.organizations o where o.id = p_org), false)
$$;
revoke all on function private.qual_is_simulation(uuid) from public, anon, authenticated;

create or replace function private.qual_may_perform_in(p_visit uuid, p_team uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case
    when coalesce(o.simulation, false) then
      p_user is not null and private.user_in_team(p_team, p_user) and not private.access_ended(p_user)
      and not exists (select 1 from private.qual_check(v.id, p_user) c
                      where c.result not in ('allowed_own', 'allowed_delegated'))
    else private.may_perform_visit(p_team, p_user, v.planned_minutes_b, v.is_needs_assessment)
  end
  from public.care_visits v join public.organizations o on o.id = v.organization_id
  where v.id = p_visit
$$;
revoke all on function private.qual_may_perform_in(uuid, uuid, uuid) from public, anon, authenticated;
comment on function private.qual_may_perform_in(uuid, uuid, uuid) is
  'QUAL1-10 / ADR-164: may this member of this team (the visit''s team, or the cover team) be responsible for or cover '
  'the visit. Simulation organisation: the QUAL1-8 check (every activity allowed_own or allowed_delegated). Elsewhere: '
  'exactly private.may_perform_visit(team, user, KLV-B minutes, needs assessment), unchanged. No override parameter.';

-- Why not, as "membership_or_access" (not an active member of that team) or the first activity that fails as
-- "<activity>:<label>[:<reason>]" (codes only; the reason per CGR-152).
create or replace function private.qual_refusal_detail(p_visit uuid, p_team uuid, p_user uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select case when p_user is null or not private.user_in_team(p_team, p_user) or private.access_ended(p_user)
              then 'membership_or_access'
              else coalesce((select x.d from (
    select c.activity_code || ':' || c.label
           || case when (select auth.uid()) is null or (select auth.uid()) = p_user or private.is_org_admin(v.organization_id)
                   then ':' || coalesce(c.reason, '') else '' end as d
    from public.care_visits v
    cross join lateral private.qual_check(v.id, p_user) c
    left join public.qual_activities q on q.code = c.activity_code
    where v.id = p_visit and c.result not in ('allowed_own', 'allowed_delegated')
    order by q.sort nulls first
    limit 1
  ) x), 'membership_or_access') end
$$;
revoke all on function private.qual_refusal_detail(uuid, uuid, uuid) from public, anon, authenticated;

-- 2. Every proposal and command path asks (1) --------------------------------------------------------------------------------
create or replace function private.qual2_patch(p_fn text, p_find text, p_replace text, p_count int, p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  src text;
  def text;
  n   int;
begin
  select p.prosrc, pg_get_functiondef(p.oid) into src, def from pg_proc p where p.oid = p_fn::regprocedure;
  if src like '%' || p_marker || '%' then
    return;                                        -- already patched (idempotent)
  end if;
  n := (length(src) - length(replace(src, p_find, ''))) / length(p_find);
  if n <> p_count then
    raise exception 'QUAL1 patch of %: expected % occurrence(s) of the call, found %', p_fn, p_count, n;
  end if;
  execute replace(def, p_find, p_replace);
end;
$$;
revoke all on function private.qual2_patch(text, text, text, int, text) from public, anon, authenticated;

select private.qual2_patch('public.take_open_visit(uuid, uuid, boolean)',
  'private.may_perform_visit(v.team_id, uid, v.planned_minutes_b, v.is_needs_assessment)',
  'private.qual_may_perform_in(v.id, v.team_id, uid) /* QUAL1-10 */', 1, 'QUAL1-10');
select private.qual2_patch('public.team_open_visits(date)',
  'private.may_perform_visit(o.team_id, (select uid from me), o.planned_minutes_b, o.is_needs_assessment)',
  'private.qual_may_perform_in(o.id, o.team_id, (select uid from me)) /* QUAL1-10 */', 1, 'QUAL1-10');
select private.qual2_patch('public.change_absence(uuid, boolean, date, time without time zone, uuid)',
  'private.may_perform_visit(g.team_id, g.user_id, x.planned_minutes_b, x.is_needs_assessment)',
  'private.qual_may_perform_in(x.id, g.team_id, g.user_id) /* QUAL1-10 */', 1, 'QUAL1-10');
select private.qual2_patch('private.aig1_apply_visit_responsible(uuid, uuid, uuid, uuid)',
  'private.may_perform_visit(v.team_id, p_user, v.planned_minutes_b, v.is_needs_assessment)',
  'private.qual_may_perform_in(v.id, v.team_id, p_user) /* QUAL1-10 */', 2, 'QUAL1-10');
select private.qual2_patch('private.plan3_lines(uuid, date, boolean)',
  'private.may_perform_visit(p_team, mem[i], v.planned_minutes_b, v.is_needs_assessment)',
  'private.qual_may_perform_in(v.id, p_team, mem[i]) /* QUAL1-10 */', 1, 'QUAL1-10');

drop function private.qual2_patch(text, text, text, int, text);

-- 3. Backstop: no path makes a member responsible for, or covering, a visit she may not perform -------------------------------
create or replace function private.qual_guard_assignment()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  moved boolean;
begin
  if new.status not in ('planned', 'on_the_way', 'started', 'paused') or not private.qual_is_simulation(new.organization_id) then
    return null;
  end if;
  moved := tg_op = 'UPDATE' and (new.visit_date is distinct from old.visit_date or new.time_start is distinct from old.time_start
                                 or new.time_end is distinct from old.time_end or new.team_id is distinct from old.team_id);
  if new.responsible_user_id is not null
     and (tg_op = 'INSERT' or moved or new.responsible_user_id is distinct from old.responsible_user_id)
     and not private.qual_may_perform_in(new.id, new.team_id, new.responsible_user_id) then
    raise exception 'qualification_not_allowed' using errcode = '42501',
      detail = 'QUAL1-10: ' || private.qual_refusal_detail(new.id, new.team_id, new.responsible_user_id),
      hint = 'QUAL1 (Simulation, Regeln PROPOSED): every activity must be geeignet or geeignet mit Delegation';
  end if;
  if new.covered_by is not null
     and (tg_op = 'INSERT' or moved or new.covered_by is distinct from old.covered_by
          or new.cover_team_id is distinct from old.cover_team_id)
     and not private.qual_may_perform_in(new.id, coalesce(new.cover_team_id, new.team_id), new.covered_by) then
    raise exception 'qualification_not_allowed' using errcode = '42501',
      detail = 'QUAL1-10: ' || private.qual_refusal_detail(new.id, coalesce(new.cover_team_id, new.team_id), new.covered_by),
      hint = 'QUAL1 (Simulation, Regeln PROPOSED): every activity must be geeignet or geeignet mit Delegation';
  end if;
  return null;
end;
$$;
revoke all on function private.qual_guard_assignment() from public, anon, authenticated;
drop trigger if exists care_visits_qual1_assignment on public.care_visits;
create trigger care_visits_qual1_assignment
  after insert or update of responsible_user_id, covered_by, cover_team_id, visit_date, time_start, time_end, team_id
  on public.care_visits
  for each row execute function private.qual_guard_assignment();

-- 4. An activity added later is checked against the member already set ------------------------------------------------------
create or replace function private.qual_guard_added_activity()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v public.care_visits%rowtype;
begin
  select * into v from public.care_visits x where x.id = new.visit_id;
  if v.id is null or v.status not in ('planned', 'on_the_way', 'started', 'paused')
     or not private.qual_is_simulation(v.organization_id) then
    return null;
  end if;
  if v.responsible_user_id is not null and not private.qual_may_perform_in(v.id, v.team_id, v.responsible_user_id) then
    raise exception 'qualification_not_allowed' using errcode = '42501',
      detail = 'QUAL1-10: ' || private.qual_refusal_detail(v.id, v.team_id, v.responsible_user_id),
      hint = 'QUAL1: the responsible member may not perform the added activity; release the visit first';
  end if;
  if v.covered_by is not null
     and not private.qual_may_perform_in(v.id, coalesce(v.cover_team_id, v.team_id), v.covered_by) then
    raise exception 'qualification_not_allowed' using errcode = '42501',
      detail = 'QUAL1-10: ' || private.qual_refusal_detail(v.id, coalesce(v.cover_team_id, v.team_id), v.covered_by),
      hint = 'QUAL1: the covering member may not perform the added activity; release the cover first';
  end if;
  return null;
end;
$$;
revoke all on function private.qual_guard_added_activity() from public, anon, authenticated;
drop trigger if exists visit_activities_qual1_recheck on public.visit_activities;
create trigger visit_activities_qual1_recheck after insert on public.visit_activities
  for each row execute function private.qual_guard_added_activity();

-- 5. Check at visit start (QUAL1-17) -----------------------------------------------------------------------------------------
create or replace function private.qual_guard_start()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid;
  tm    uuid;
begin
  if new.status not in ('on_the_way', 'started') or new.status is not distinct from old.status
     or not private.qual_is_simulation(new.organization_id) then
    return new;
  end if;
  -- The person doing it; a system path without a caller checks the member who performs the visit.
  actor := coalesce((select auth.uid()), new.covered_by, new.responsible_user_id);
  if actor is null then
    return new;
  end if;
  tm := case when new.cover_team_id is not null and actor = new.covered_by then new.cover_team_id else new.team_id end;
  if not private.qual_may_perform_in(new.id, tm, actor) then
    raise exception 'qualification_lapsed' using errcode = '42501',
      detail = 'QUAL1-17: ' || private.qual_refusal_detail(new.id, tm, actor),
      hint = 'QUAL1-17 (CR-183): the check runs again at the start; a lapsed evidence or delegation refuses it';
  end if;
  return new;
end;
$$;
revoke all on function private.qual_guard_start() from public, anon, authenticated;
drop trigger if exists care_visits_qual1_start on public.care_visits;
create trigger care_visits_qual1_start before update of status on public.care_visits
  for each row execute function private.qual_guard_start();
