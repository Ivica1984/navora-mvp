-- ABS1, first PR: absence without the phone chain (docs/agents/briefs/ABS1.md; ADR-057).
-- Clinical gate: Clinical Governance Report findings CGR-15, CGR-11 (2026-10-22 22:30), CGR-09, CGR-10, CGR-12,
-- CGR-18 (reused rules), CGR-22 (PO amendment 2026-10-23 12:15: "Offen im Team" covers every uncovered visit).
--
-- What this adds (IMPLEMENTED in this migration):
--   1. `public.member_absences`: one row per absence of a team member, a time range [starts_at, ends_at), recorded
--      by herself or by a colleague of the same team. **No reason column and no free text** (data minimisation; the
--      command has no such parameter). No approval step. Withdrawn absences keep their row (withdrawn_at).
--      Readable only by members of the same team (RLS); coordination roles, other teams and AN1 never read it.
--   2. One release rule for every path that takes a person off visits (CGR-15):
--      `private.release_visits_between(team, member, from, until, reason, actor, rn_only)`. Released = `planned`
--      (suspended included, CGR-09), dated today (Europe/Zurich) or later, overlapping [from, until), of that team,
--      with that member responsible; with rn_only only category B and needs-assessment visits (CGR-11).
--      Visits on the way, started or paused are never released (CGR-10, CGR-18): they keep her as responsible and
--      performer and stay visible through `visit_stuck` (CGR-04). `private.release_member_visits` (ADM1, 0036) now
--      delegates to it with whole days, same result.
--   3. `public.record_absence` (own or a colleague's, same team): audited, idempotent, never refused because of
--      visits in progress or open reports (PO 03:10, CGR-18). Releases her visits in the period at once, logged in
--      the J3 change log as `released` with the fixed text 'Abwesenheit'.
--   4. `public.change_absence`: withdraw or shorten, by the absent member or the colleague who recorded it.
--      Released visits nobody has taken and that are no longer inside the absence return to her (`returned`,
--      fixed text 'Abwesenheit beendet'), if she may still perform them; taken visits stay with the taker.
--   5. `public.take_open_visit`: one tap, first wins (row lock): the taker becomes the responsible member of a
--      planned, not suspended, not covered visit of her team with nobody responsible, whatever made it uncovered
--      (absence, removal, qualification change, PLAN2 without deputy, hand-planned). J3 rule: category B and
--      needs-assessment visits only for a registered nurse (`not_qualified`). A member absent at the visit's time
--      cannot take it (`absent`). Logged as `taken`; the OPS1 `visit_uncovered` exception then ends with its cause.
--   6. `public.team_open_visits(p_from)`: "Offen im Team" for the caller's teams (14 days from p_from, at least
--      today): what /field shows for a team visit, plus `known_by` (the case's deputy, then primary nurse, if in the
--      team and not absent then; a label, not an assignment), `may_take` and the caller's overlapping own visit.
--   7. `public.team_absences()`: current and future absences of the caller's teams (from–to, who, may change).
--   8. PLAN2: generated visits are never assigned to a member absent during the slot (deputy if she may perform
--      it, else uncovered); a visit taken from "Offen im Team" counts as touched, so regeneration never reassigns
--      it (`plan_visit_untouched`).
--   9. CGR-11: `set_member_qualification` from registered_nurse to care_assistant releases the category B and
--      needs-assessment visits she may no longer perform, with the fixed text 'Qualifikation geändert'.
--  10. HAND1: a `released` change shows as the fact only (`visit_released`, no reason, no member id).
--
-- Not here (PLANNED, ABS1 part 2): AN1 measures (taken before the COVER1 lead time, median time to the last take,
-- share taken by deputy or primary nurse); phone-width e2e. No clinical, labour-law or leave rule is modelled.

-- 1. The plan change log knows a take and a return ------------------------------------------------------------------
alter table public.visit_plan_changes drop constraint visit_plan_changes_change_check;
alter table public.visit_plan_changes add constraint visit_plan_changes_change_check
  check (change in ('planned', 'moved', 'removed', 'regenerated', 'skipped', 'released', 'taken', 'returned'));

-- 2. Absences ---------------------------------------------------------------------------------------------------------
create table public.member_absences (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id),
  user_id         uuid not null references auth.users (id),
  starts_at       timestamptz not null,
  ends_at         timestamptz not null,
  recorded_by     uuid not null,
  created_at      timestamptz not null default now(),
  withdrawn_at    timestamptz,
  withdrawn_by    uuid,
  check (ends_at > starts_at),
  check ((withdrawn_at is null) = (withdrawn_by is null))
);
create index member_absences_member on public.member_absences (team_id, user_id, starts_at) where withdrawn_at is null;
comment on table public.member_absences is
  'ABS1: a team member is not available in [starts_at, ends_at). No reason and no free text are stored. '
  'Readable by members of the same team only; other teams, coordination roles and AN1 see only uncovered visits.';

alter table public.member_absences enable row level security;
revoke all on public.member_absences from anon, authenticated;
grant select (id, team_id, user_id, starts_at, ends_at, recorded_by, created_at, withdrawn_at)
  on public.member_absences to authenticated;
create policy team_members_read on public.member_absences
  for select to authenticated using (private.is_org_member(organization_id) and private.is_team_member(team_id));

create trigger audit_member_absences
  after insert or update on public.member_absences
  for each row execute function private.write_audit_event('team_id', 'user_id', 'starts_at', 'ends_at', 'recorded_by', 'withdrawn_at');

-- Which visits an absence released (to return the untaken ones on withdraw or shorten). Internal only.
create table public.absence_releases (
  absence_id uuid not null references public.member_absences (id),
  visit_id   uuid not null references public.care_visits (id) on delete cascade,
  primary key (absence_id, visit_id)
);
alter table public.absence_releases enable row level security;
revoke all on public.absence_releases from anon, authenticated;
comment on table public.absence_releases is 'ABS1: visits released by an absence. Read only by the absence commands.';

-- 3. Helpers ----------------------------------------------------------------------------------------------------------
-- A visit's planned interval (Europe/Zurich). Without a start: its whole day from 00:00 for one minute (as 0019).
create function private.visit_interval(v public.care_visits)
returns tstzrange language sql stable set search_path = ''
as $$
  select tstzrange(
    (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich',
    (v.visit_date + coalesce(v.time_end, coalesce(v.time_start, time '00:00') + interval '1 minute')
       + case when v.time_end < v.time_start then interval '1 day' else interval '0' end) at time zone 'Europe/Zurich',
    '[)')
$$;
revoke all on function private.visit_interval(public.care_visits) from public, anon, authenticated;

create function private.member_absent_during(p_team uuid, p_user uuid, p_from timestamptz, p_until timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select p_team is not null and p_user is not null and exists (
    select 1 from public.member_absences a
    where a.team_id = p_team and a.user_id = p_user and a.withdrawn_at is null
      and a.starts_at < coalesce(p_until, p_from + interval '1 minute') and a.ends_at > p_from)
$$;
revoke all on function private.member_absent_during(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- J3 qualification rule (CR-007), the same as private.enforce_visit_transition (CGR-12) and plan_visit.
create function private.may_perform_visit(p_team uuid, p_user uuid, p_minutes_b integer, p_needs_assessment boolean)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.user_in_team(p_team, p_user)
     and (not (coalesce(p_minutes_b, 0) > 0 or coalesce(p_needs_assessment, false))
          or private.is_registered_nurse(p_team, p_user))
$$;
revoke all on function private.may_perform_visit(uuid, uuid, integer, boolean) from public, anon, authenticated;

-- 4. One release rule ---------------------------------------------------------------------------------------------------
-- p_from / p_until: the period; null p_until = open end. Never visits dated before today (Europe/Zurich).
-- p_reason goes to visit_plan_changes, which every team member reads: callers pass a fixed neutral text.
-- Returns the released visit ids. Callers check permissions; not executable by app roles.
create function private.release_visits_between(p_team_id uuid, p_user_id uuid, p_from timestamptz, p_until timestamptz,
                                               p_reason text, p_actor uuid, p_rn_only boolean)
returns setof uuid
language plpgsql security definer set search_path = ''
as $$
declare
  today date := (now() at time zone 'Europe/Zurich')::date;
  lower_date date;
  v     public.care_visits%rowtype;
begin
  if p_team_id is null or p_user_id is null or p_actor is null or p_from is null
     or p_reason is null or char_length(btrim(p_reason)) < 3 then
    raise exception 'team, member, start, actor and reason are required' using errcode = '22023';
  end if;
  lower_date := greatest((p_from at time zone 'Europe/Zurich')::date, today);
  for v in
    select * from public.care_visits x
    where x.team_id = p_team_id and x.responsible_user_id = p_user_id
      and x.status = 'planned'                       -- suspended included (CGR-09); in progress never (CGR-10/18)
      and x.visit_date >= lower_date
      and private.visit_interval(x) && tstzrange(p_from, p_until, '[)')
      and (not coalesce(p_rn_only, false) or coalesce(x.planned_minutes_b, 0) > 0 or x.is_needs_assessment)
    order by x.visit_date, x.time_start
    for update
  loop
    update public.care_visits set responsible_user_id = null where id = v.id;
    insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
    values (v.organization_id, v.id, v.case_id, v.team_id, 'released',
            private.visit_slot_json(v) || jsonb_build_object('responsible_id', p_user_id),
            private.visit_slot_json(v) || jsonb_build_object('responsible_id', null),
            left(btrim(p_reason), 300), p_actor);
    return next v.id;
  end loop;
end;
$$;
revoke all on function private.release_visits_between(uuid, uuid, timestamptz, timestamptz, text, uuid, boolean)
  from public, anon, authenticated;

-- ADM1's whole-day release (0036) now uses the same rule. Same signature and result.
create or replace function private.release_member_visits(p_team_id uuid, p_user_id uuid, p_from date, p_until date,
                                                         p_reason text, p_actor uuid)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  today date := (now() at time zone 'Europe/Zurich')::date;
begin
  return (select count(*)::int from private.release_visits_between(
    p_team_id, p_user_id,
    (greatest(coalesce(p_from, today), today) + time '00:00') at time zone 'Europe/Zurich',
    case when p_until is null then null else ((p_until + 1) + time '00:00') at time zone 'Europe/Zurich' end,
    p_reason, p_actor, false));
end;
$$;
revoke all on function private.release_member_visits(uuid, uuid, date, date, text, uuid) from public, anon, authenticated;

-- 5. Record an absence ------------------------------------------------------------------------------------------------
-- p_user_id null = herself. p_from null = today; p_until null = p_from. Without times: whole days.
-- Return: {"result": "ok", "absence_id", "released"} | {"result": "overlaps", "absence_id"} | "in_past" | "duplicate" | "rejected"
create function public.record_absence(p_team_id uuid, p_user_id uuid, p_from date, p_until date,
                                      p_from_time time, p_until_time time, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  who      uuid := coalesce(p_user_id, (select auth.uid()));
  org      uuid := private.team_organization(p_team_id);
  today    date := (now() at time zone 'Europe/Zurich')::date;
  d_from   date := coalesce(p_from, (now() at time zone 'Europe/Zurich')::date);
  d_until  date := coalesce(p_until, p_from, (now() at time zone 'Europe/Zurich')::date);
  s_at     timestamptz;
  e_at     timestamptz;
  other    uuid;
  aid      uuid;
  released integer := 0;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  s_at := (d_from + coalesce(p_from_time, time '00:00')) at time zone 'Europe/Zurich';
  e_at := case when p_until_time is null then ((d_until + 1) + time '00:00') at time zone 'Europe/Zurich'
               else (d_until + p_until_time) at time zone 'Europe/Zurich' end;
  if e_at <= s_at then
    raise exception 'the absence must end after it starts' using errcode = '22023';
  end if;
  if private.begin_command('record_absence', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if org is null or not private.is_org_member(org) or not private.is_team_member(p_team_id) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  -- Serialise absences of one member of one team (overlap check + release in one step).
  perform 1 from public.team_memberships m where m.team_id = p_team_id and m.user_id = who for update;
  if not found then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if e_at <= now() then
    return jsonb_build_object('result', private.end_command('in_past'));
  end if;
  select a.id into other from public.member_absences a
    where a.team_id = p_team_id and a.user_id = who and a.withdrawn_at is null
      and a.starts_at < e_at and a.ends_at > s_at
    order by a.starts_at limit 1;
  if found then
    return jsonb_build_object('result', private.end_command('overlaps'), 'absence_id', other);
  end if;

  insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by)
  values (org, p_team_id, who, s_at, e_at, uid)
  returning id into aid;
  insert into public.absence_releases (absence_id, visit_id)
  select aid, r from private.release_visits_between(p_team_id, who, s_at, e_at, 'Abwesenheit', uid, false) r;
  get diagnostics released = row_count;

  return jsonb_build_object('result', private.end_command('ok'), 'absence_id', aid, 'released', released);
end;
$$;
revoke all on function public.record_absence(uuid, uuid, date, date, time, time, uuid) from public, anon;
grant execute on function public.record_absence(uuid, uuid, date, date, time, time, uuid) to authenticated;
comment on function public.record_absence(uuid, uuid, date, date, time, time, uuid) is
  'ABS1: records that a team member (herself, or a colleague of the same team) is not available; no reason, no '
  'approval. Releases her planned visits of the team in the period at once (private.release_visits_between, '
  'fixed text Abwesenheit). Never refused because of visits in progress or open reports. Returns {result, absence_id, released}.';

-- 6. Withdraw or shorten ------------------------------------------------------------------------------------------------
-- p_withdraw true: the absence ends entirely. Otherwise the new end (p_until, p_until_time as in record_absence).
-- Return: {"result": "ok", "returned"} | "not_shorter" | "already_ended" | "duplicate" | "rejected"
create function public.change_absence(p_absence_id uuid, p_withdraw boolean, p_until date, p_until_time time,
                                      p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  a        public.member_absences%rowtype;
  new_end  timestamptz;
  v        public.care_visits%rowtype;
  returned integer := 0;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if not coalesce(p_withdraw, false) and p_until is null then
    raise exception 'a new end date is required unless the absence is withdrawn' using errcode = '22023';
  end if;
  if private.begin_command('change_absence', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  select * into a from public.member_absences where id = p_absence_id for update;
  if not found or a.withdrawn_at is not null
     or uid not in (a.user_id, a.recorded_by)
     or not private.is_org_member(a.organization_id) or not private.is_team_member(a.team_id) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if a.ends_at <= now() then
    return jsonb_build_object('result', private.end_command('already_ended'));
  end if;

  if coalesce(p_withdraw, false) then
    update public.member_absences set withdrawn_at = now(), withdrawn_by = uid where id = a.id;
    new_end := a.starts_at;                     -- nothing of the absence remains
  else
    new_end := case when p_until_time is null then ((p_until + 1) + time '00:00') at time zone 'Europe/Zurich'
                    else (p_until + p_until_time) at time zone 'Europe/Zurich' end;
    if new_end >= a.ends_at or new_end <= a.starts_at then
      return jsonb_build_object('result', private.end_command('not_shorter'));
    end if;
    update public.member_absences set ends_at = new_end where id = a.id;
  end if;

  -- Released visits nobody has taken, no longer inside the absence, return to her if she may still perform them.
  for v in
    select x.* from public.absence_releases r
    join public.care_visits x on x.id = r.visit_id
    where r.absence_id = a.id
      and x.team_id = a.team_id and x.status = 'planned' and x.responsible_user_id is null and x.covered_by is null
      and x.visit_date >= (now() at time zone 'Europe/Zurich')::date
      and not (private.visit_interval(x) && tstzrange(a.starts_at, new_end, '[)'))
      and private.may_perform_visit(a.team_id, a.user_id, x.planned_minutes_b, x.is_needs_assessment)
      and not private.member_absent_during(a.team_id, a.user_id, lower(private.visit_interval(x)), upper(private.visit_interval(x)))
    order by x.visit_date, x.time_start
    for update of x
  loop
    update public.care_visits set responsible_user_id = a.user_id where id = v.id;
    insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
    values (v.organization_id, v.id, v.case_id, v.team_id, 'returned',
            private.visit_slot_json(v) || jsonb_build_object('responsible_id', null),
            private.visit_slot_json(v) || jsonb_build_object('responsible_id', a.user_id),
            'Abwesenheit beendet', uid);
    returned := returned + 1;
  end loop;

  return jsonb_build_object('result', private.end_command('ok'), 'returned', returned);
end;
$$;
revoke all on function public.change_absence(uuid, boolean, date, time, uuid) from public, anon;
grant execute on function public.change_absence(uuid, boolean, date, time, uuid) to authenticated;
comment on function public.change_absence(uuid, boolean, date, time, uuid) is
  'ABS1: withdraws or shortens an absence (the absent member or the colleague who recorded it). Released visits '
  'nobody took return to her (fixed text Abwesenheit beendet); taken visits stay with the taker.';

-- 7. Take an open visit ----------------------------------------------------------------------------------------------
-- Return: {"result": "ok"} | "already_taken" | "not_qualified" | "absent" | "not_open" | "duplicate" | "rejected"
create function public.take_open_visit(p_visit_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('take_open_visit', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  select * into v from public.care_visits where id = p_visit_id for update;   -- first wins
  if not found or not private.is_org_member(v.organization_id) or not private.is_team_member(v.team_id) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if v.responsible_user_id is not null then
    return jsonb_build_object('result', private.end_command('already_taken'));
  end if;
  if v.status <> 'planned' or v.suspended_at is not null or v.covered_by is not null
     or v.visit_date < (now() at time zone 'Europe/Zurich')::date then
    return jsonb_build_object('result', private.end_command('not_open'));
  end if;
  if not private.may_perform_visit(v.team_id, uid, v.planned_minutes_b, v.is_needs_assessment) then
    return jsonb_build_object('result', private.end_command('not_qualified'));
  end if;
  if private.member_absent_during(v.team_id, uid, lower(private.visit_interval(v)), upper(private.visit_interval(v))) then
    return jsonb_build_object('result', private.end_command('absent'));
  end if;

  update public.care_visits set responsible_user_id = uid where id = v.id;
  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  values (v.organization_id, v.id, v.case_id, v.team_id, 'taken',
          private.visit_slot_json(v) || jsonb_build_object('responsible_id', null),
          private.visit_slot_json(v) || jsonb_build_object('responsible_id', uid),
          'Übernommen aus «Offen im Team»', uid);
  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.take_open_visit(uuid, uuid) from public, anon;
grant execute on function public.take_open_visit(uuid, uuid) to authenticated;
comment on function public.take_open_visit(uuid, uuid) is
  'ABS1: a team member takes a planned, not suspended, not covered visit of her team with nobody responsible (one '
  'tap, first wins). J3 qualification rule; not while she is absent at its time. Logged as taken.';

-- 8. "Offen im Team" ------------------------------------------------------------------------------------------------
-- 14 days from p_from (never before today). Same visit facts /field shows for a team visit (F0); known_by is a
-- display name or 'me'; overlaps_my_visit is the start of the caller's own overlapping visit.
create function public.team_open_visits(p_from date)
returns table (visit_id uuid, team_id uuid, team_name text, visit_date date, time_start time, time_end time,
               case_id uuid, client_name text, services_provided text[], planned_minutes_a integer,
               planned_minutes_b integer, planned_minutes_c integer, is_needs_assessment boolean,
               known_by text, known_by_me boolean, may_take boolean, overlaps_my_visit time)
language sql stable security definer set search_path = ''
as $$
  with me as (select (select auth.uid()) as uid,
                     greatest(coalesce(p_from, (now() at time zone 'Europe/Zurich')::date),
                              (now() at time zone 'Europe/Zurich')::date) as d0),
  open as (
    select v.*, private.visit_interval(v) as iv
    from public.care_visits v
    join public.team_memberships tm on tm.team_id = v.team_id and tm.user_id = (select uid from me)
    where private.is_org_member(v.organization_id)
      and v.status = 'planned' and v.suspended_at is null and v.covered_by is null and v.responsible_user_id is null
      and v.visit_date between (select d0 from me) and (select d0 from me) + 13
  )
  select o.id, o.team_id, t.name, o.visit_date, o.time_start, o.time_end,
         c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         o.services_provided, o.planned_minutes_a, o.planned_minutes_b, o.planned_minutes_c, o.is_needs_assessment,
         case when k.uid = (select uid from me) then 'me'
              when k.uid is not null then coalesce(private.member_name(o.organization_id, k.uid), 'Teammitglied') end,
         k.uid is not null and k.uid = (select uid from me),
         private.may_perform_visit(o.team_id, (select uid from me), o.planned_minutes_b, o.is_needs_assessment)
           and not private.member_absent_during(o.team_id, (select uid from me), lower(o.iv), upper(o.iv)),
         (select min(x.time_start) from public.care_visits x
          where x.responsible_user_id = (select uid from me) and x.id <> o.id
            and x.status in ('planned', 'on_the_way', 'started', 'paused')
            and x.visit_date between o.visit_date - 1 and o.visit_date + 1
            and private.visit_interval(x) && o.iv)
  from open o
  join public.teams t on t.id = o.team_id
  left join public.cases c on c.id = o.case_id
  left join lateral (
    select n.uid from (values (1, c.deputy_nurse_id), (2, c.primary_nurse_id)) as n(ord, uid)
    where n.uid is not null and private.user_in_team(o.team_id, n.uid)
      and not private.member_absent_during(o.team_id, n.uid, lower(o.iv), upper(o.iv))
    order by n.ord limit 1) k on true
  order by o.visit_date, o.time_start nulls first, o.id
$$;
revoke all on function public.team_open_visits(date) from public, anon;
grant execute on function public.team_open_visits(date) to authenticated;
comment on function public.team_open_visits(date) is
  'ABS1: every planned, not suspended, not covered visit of the caller''s teams with nobody responsible, 14 days from '
  'p_from; known_by = deputy, then primary nurse, if in the team and not absent (label only); may_take = J3 '
  'qualification and not absent; overlaps_my_visit = start of her own overlapping visit.';

-- 9. Absences of my teams -------------------------------------------------------------------------------------------
create function public.team_absences()
returns table (absence_id uuid, team_id uuid, member text, is_me boolean, recorded_by_me boolean,
               starts_at timestamptz, ends_at timestamptz, may_change boolean)
language sql stable security definer set search_path = ''
as $$
  select a.id, a.team_id,
         case when a.user_id = (select auth.uid()) then 'me'
              else coalesce(private.member_name(a.organization_id, a.user_id), 'Teammitglied') end,
         a.user_id = (select auth.uid()), a.recorded_by = (select auth.uid()),
         a.starts_at, a.ends_at,
         (select auth.uid()) in (a.user_id, a.recorded_by)
  from public.member_absences a
  where a.withdrawn_at is null and a.ends_at > now()
    and private.is_org_member(a.organization_id) and private.is_team_member(a.team_id)
  order by a.starts_at, a.id
$$;
revoke all on function public.team_absences() from public, anon;
grant execute on function public.team_absences() to authenticated;
comment on function public.team_absences() is
  'ABS1: current and future absences of the caller''s teams (who, from, to). No reason exists to show.';

-- 10. Patches of existing functions, regenerated from their current definitions (each find must match once) --------
create function private.abs1_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'ABS1 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

-- 10a. PLAN2: never assign a generated visit to a member absent during the slot.
select private.abs1_patch('private.generate_case_plan(uuid, uuid)', array[
  'and (not rn_needed or private.is_registered_nurse(c.assigned_team_id, c.primary_nurse_id)) then c.primary_nurse_id',
  'and (not rn_needed or private.is_registered_nurse(c.assigned_team_id, c.primary_nurse_id))
             and not private.member_absent_during(c.assigned_team_id, c.primary_nurse_id,
                   (d + slot.window_start) at time zone ''Europe/Zurich'', (d + slot.window_end) at time zone ''Europe/Zurich'') then c.primary_nurse_id',
  'and (not rn_needed or private.is_registered_nurse(c.assigned_team_id, c.deputy_nurse_id)) then c.deputy_nurse_id',
  'and (not rn_needed or private.is_registered_nurse(c.assigned_team_id, c.deputy_nurse_id))
             and not private.member_absent_during(c.assigned_team_id, c.deputy_nurse_id,
                   (d + slot.window_start) at time zone ''Europe/Zurich'', (d + slot.window_end) at time zone ''Europe/Zurich'') then c.deputy_nurse_id'
]);

-- 10b. A visit taken from "Offen im Team" is touched: regeneration never reassigns it.
select private.abs1_patch('private.plan_visit_untouched(public.care_visits)', array[
  'pc.change = ''moved''', 'pc.change in (''moved'', ''taken'')'
]);

-- 10c. CGR-11: a registered nurse who becomes a care assistant loses the B and needs-assessment visits.
select private.abs1_patch('public.set_member_qualification(uuid, uuid, text, text, uuid)', array[
  E'  update public.team_memberships set qualification = p_qualification\n    where team_id = p_team_id and user_id = p_user_id;',
  E'  update public.team_memberships set qualification = p_qualification\n    where team_id = p_team_id and user_id = p_user_id;
  -- ABS1 / CGR-11: release what she may no longer perform (same rule as absence and removal; fixed team-readable text).
  if old = ''registered_nurse'' and p_qualification = ''care_assistant'' then
    perform private.release_visits_between(p_team_id, p_user_id,
      ((now() at time zone ''Europe/Zurich'')::date + time ''00:00'') at time zone ''Europe/Zurich'', null,
      ''Qualifikation geändert'', uid, true);
  end if;'
]);

-- 10d. HAND1: a released visit shows as the fact only ("wieder offen im Team"), never a reason or a member id.
select private.abs1_patch('private.handover_entries(uuid, uuid)', array[
  'jsonb_build_object(''before'', pc.before, ''after'', pc.after, ''reason'', pc.reason)',
  'jsonb_build_object(''before'', pc.before - ''responsible_id'', ''after'', pc.after - ''responsible_id'',
                              ''reason'', case when pc.change = ''released'' then null else pc.reason end)',
  'where pc.change in (''moved'', ''removed'') and pc.changed_at > k.since_at',
  'where pc.change in (''moved'', ''removed'', ''released'') and pc.changed_at > k.since_at'
]);

drop function private.abs1_patch(text, text[]);
