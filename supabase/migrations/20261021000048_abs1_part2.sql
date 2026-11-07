-- ABS1 part 2 (docs/agents/briefs/ABS1.md, PO review 2026-10-23 14:16; ADR-059).
-- Clinical gate: Clinical Governance Report section 2026-10-23 14:30, CGR-27 (blocking, S1: the visit interval of
-- visits without a start or without an end time). Confirmed unchanged in the 15:00 section (PR #203, not merged).
--
-- What this changes (IMPLEMENTED in this migration):
--   1. ABS1-C1 / CGR-27: one visit interval for every absence check (release, take, "Offen im Team", known_by,
--      change_absence). Arithmetic, not a clinical rule:
--        * no start time            -> the whole date, 00:00 to 24:00 (Europe/Zurich);
--        * start, no end time (or end = start) -> start + planned minutes (A+B+C); without planned minutes, to the end of the date;
--        * start and end            -> as before (an end before the start runs past midnight).
--      PLAN2 slots always have a window (care_plan_items check, 0025), so PLAN2 keeps its slot window check.
--   2. ABS1-C3 (PO decision): availability belongs to the person. An absence applies to every team of the member in
--      the organisation: one row per team (each team reads only its own row, as before), linked by
--      `absence_group`. Overlaps are checked across all her teams. Withdraw and shorten change the whole group.
--      Whoever may record it for her (a colleague in any of her teams) records it for all; the absent member or that
--      colleague may change it. `member_absent_during` asks about the person in the organisation, so a team she
--      joins later also respects an absence already recorded (its visits are not released: see ADR-059).
--      `team_absences` shows an absence once to a caller who shares several teams with the member.
--   3. ABS1-C2: overlap label ("überschneidet sich") needs a start time on both visits; an untimed visit has no
--      time to clash at.
--   4. AN1 (three measures, team and organisation level, small-team rule as in AN1):
--        absence_taken_before_cover_lead  share of released visits taken by the own team before the COVER1 lead time;
--        absence_last_take_minutes        median minutes from recording an absence to its last released visit taken;
--        absence_taken_by_known_share     share of taken released visits taken by the case's deputy or primary nurse.
--      Aggregates only: AN1 never shows who was absent.
-- Not here: CGR-28 (an absence also ends her accepted covers) is advisory while cover is off (D-3), PLANNED.

-- 1. One visit interval (CGR-27) ----------------------------------------------------------------------------------------
create or replace function private.visit_interval(v public.care_visits)
returns tstzrange language sql stable set search_path = ''
as $$
  select case
    when v.time_start is null then
      tstzrange((v.visit_date + time '00:00') at time zone 'Europe/Zurich',
                ((v.visit_date + 1) + time '00:00') at time zone 'Europe/Zurich', '[)')
    when v.time_end is null or v.time_end = v.time_start then
      tstzrange((v.visit_date + v.time_start) at time zone 'Europe/Zurich',
                case when coalesce(v.planned_minutes_a, 0) + coalesce(v.planned_minutes_b, 0) + coalesce(v.planned_minutes_c, 0) > 0
                     then (v.visit_date + v.time_start) at time zone 'Europe/Zurich'
                          + make_interval(mins => coalesce(v.planned_minutes_a, 0) + coalesce(v.planned_minutes_b, 0)
                                                  + coalesce(v.planned_minutes_c, 0))
                     else ((v.visit_date + 1) + time '00:00') at time zone 'Europe/Zurich' end,
                '[)')
    else
      tstzrange((v.visit_date + v.time_start) at time zone 'Europe/Zurich',
                (v.visit_date + v.time_end + case when v.time_end < v.time_start then interval '1 day' else interval '0' end)
                  at time zone 'Europe/Zurich',
                '[)')
  end
$$;
revoke all on function private.visit_interval(public.care_visits) from public, anon, authenticated;
comment on function private.visit_interval(public.care_visits) is
  'ABS1/CGR-27: the time a planned visit occupies (Europe/Zurich). No start: its whole date. Start without end: start '
  '+ planned minutes A+B+C, else to the end of its date. Used by every absence check.';

-- 2. Absence groups (ABS1-C3) -------------------------------------------------------------------------------------------
alter table public.member_absences add column absence_group uuid;
update public.member_absences set absence_group = id where absence_group is null;
alter table public.member_absences alter column absence_group set not null;
-- A row inserted without a group is its own group.
create function private.member_absence_group() returns trigger language plpgsql set search_path = ''
as $$
begin
  new.absence_group := coalesce(new.absence_group, new.id);
  return new;
end;
$$;
revoke all on function private.member_absence_group() from public, anon, authenticated;
create trigger member_absences_group before insert on public.member_absences
  for each row execute function private.member_absence_group();
create index member_absences_group on public.member_absences (absence_group);
create index member_absences_person on public.member_absences (organization_id, user_id, starts_at) where withdrawn_at is null;
comment on column public.member_absences.absence_group is
  'ABS1-C3: the rows of one absence, one per team of the member in the organisation. Not readable by the app.';

-- The person, not the team: absent in any of her teams of the same organisation.
create or replace function private.member_absent_during(p_team uuid, p_user uuid, p_from timestamptz, p_until timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select p_team is not null and p_user is not null and exists (
    select 1 from public.member_absences a
    where a.organization_id = private.team_organization(p_team) and a.user_id = p_user and a.withdrawn_at is null
      and a.starts_at < coalesce(p_until, p_from + interval '1 minute') and a.ends_at > p_from)
$$;
revoke all on function private.member_absent_during(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- 3. Record an absence for every team of the member ------------------------------------------------------------------
-- Same signature and results as 0046; adds "teams" (number of her teams the absence applies to).
create or replace function public.record_absence(p_team_id uuid, p_user_id uuid, p_from date, p_until date,
                                                 p_from_time time, p_until_time time, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  who      uuid := coalesce(p_user_id, (select auth.uid()));
  org      uuid := private.team_organization(p_team_id);
  d_from   date := coalesce(p_from, (now() at time zone 'Europe/Zurich')::date);
  d_until  date := coalesce(p_until, p_from, (now() at time zone 'Europe/Zurich')::date);
  s_at     timestamptz;
  e_at     timestamptz;
  other    uuid;
  grp      uuid := gen_random_uuid();
  t        record;
  aid      uuid;
  n_teams  integer := 0;
  released integer := 0;
  n        integer;
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
  if org is null or not private.is_org_member(org) or not private.is_team_member(p_team_id)
     or not exists (select 1 from public.team_memberships m where m.team_id = p_team_id and m.user_id = who) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  -- Serialise absences of one person in the organisation: lock all her memberships there, in a fixed order.
  perform 1 from public.team_memberships m join public.teams tt on tt.id = m.team_id
    where m.user_id = who and tt.organization_id = org
    order by m.team_id
    for update of m;
  if e_at <= now() then
    return jsonb_build_object('result', private.end_command('in_past'));
  end if;
  select a.id into other from public.member_absences a
    where a.organization_id = org and a.user_id = who and a.withdrawn_at is null
      and a.starts_at < e_at and a.ends_at > s_at
    order by (a.team_id = p_team_id) desc, a.starts_at limit 1;
  if found then
    -- The id of a row of another team is not readable by the caller; return it only when it is her team's row.
    return jsonb_build_object('result', private.end_command('overlaps'),
      'absence_id', (select a.id from public.member_absences a where a.id = other and private.is_team_member(a.team_id)));
  end if;

  for t in
    select m.team_id from public.team_memberships m join public.teams tt on tt.id = m.team_id
    where m.user_id = who and tt.organization_id = org
    order by (m.team_id = p_team_id) desc, m.team_id
  loop
    insert into public.member_absences (id, organization_id, team_id, user_id, starts_at, ends_at, recorded_by, absence_group)
    values (case when t.team_id = p_team_id then grp else gen_random_uuid() end, org, t.team_id, who, s_at, e_at, uid, grp)
    returning id into aid;
    insert into public.absence_releases (absence_id, visit_id)
    select aid, r from private.release_visits_between(t.team_id, who, s_at, e_at, 'Abwesenheit', uid, false) r;
    get diagnostics n = row_count;
    released := released + n;
    n_teams := n_teams + 1;
  end loop;

  return jsonb_build_object('result', private.end_command('ok'), 'absence_id', grp, 'released', released, 'teams', n_teams);
end;
$$;
revoke all on function public.record_absence(uuid, uuid, date, date, time, time, uuid) from public, anon;
grant execute on function public.record_absence(uuid, uuid, date, date, time, time, uuid) to authenticated;
comment on function public.record_absence(uuid, uuid, date, date, time, time, uuid) is
  'ABS1: records that a member (herself, or a colleague of one of her teams) is not available; no reason, no '
  'approval. Applies to every team of hers in the organisation (one row per team, one absence_group, ABS1-C3) and '
  'releases her planned visits in each team at once (fixed text Abwesenheit). Returns {result, absence_id, released, teams}.';

-- 4. Withdraw or shorten the whole absence -------------------------------------------------------------------------
create or replace function public.change_absence(p_absence_id uuid, p_withdraw boolean, p_until date, p_until_time time,
                                                 p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  a        public.member_absences%rowtype;
  g        public.member_absences%rowtype;
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
  select * into a from public.member_absences where id = p_absence_id;
  if not found or a.withdrawn_at is not null
     or uid not in (a.user_id, a.recorded_by)
     or not private.is_org_member(a.organization_id) or not private.is_team_member(a.team_id) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  -- Lock the whole group in a fixed order, then re-read the row the caller named.
  perform 1 from public.member_absences x where x.absence_group = a.absence_group order by x.id for update;
  select * into a from public.member_absences where id = p_absence_id;
  if a.withdrawn_at is not null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if a.ends_at <= now() then
    return jsonb_build_object('result', private.end_command('already_ended'));
  end if;
  if not coalesce(p_withdraw, false) then
    new_end := case when p_until_time is null then ((p_until + 1) + time '00:00') at time zone 'Europe/Zurich'
                    else (p_until + p_until_time) at time zone 'Europe/Zurich' end;
    if new_end >= a.ends_at or new_end <= a.starts_at then
      return jsonb_build_object('result', private.end_command('not_shorter'));
    end if;
  end if;

  -- Change every row of the group first: the absent check below asks about the person in all her teams.
  if coalesce(p_withdraw, false) then
    update public.member_absences set withdrawn_at = now(), withdrawn_by = uid
      where absence_group = a.absence_group and withdrawn_at is null;
  else
    update public.member_absences set ends_at = new_end
      where absence_group = a.absence_group and withdrawn_at is null and ends_at > new_end;
  end if;

  for g in
    select * from public.member_absences x
    where x.absence_group = a.absence_group
      and case when coalesce(p_withdraw, false) then x.withdrawn_at = now() else x.withdrawn_at is null end
    order by x.id
  loop

    -- Released visits nobody has taken, no longer inside the absence, return to her if she may still perform them.
    for v in
      select x.* from public.absence_releases r
      join public.care_visits x on x.id = r.visit_id
      where r.absence_id = g.id
        and x.team_id = g.team_id and x.status = 'planned' and x.responsible_user_id is null and x.covered_by is null
        and x.visit_date >= (now() at time zone 'Europe/Zurich')::date
        and (coalesce(p_withdraw, false) or not (private.visit_interval(x) && tstzrange(g.starts_at, new_end, '[)')))
        and private.may_perform_visit(g.team_id, g.user_id, x.planned_minutes_b, x.is_needs_assessment)
        and not private.member_absent_during(g.team_id, g.user_id, lower(private.visit_interval(x)), upper(private.visit_interval(x)))
      order by x.visit_date, x.time_start
      for update of x
    loop
      update public.care_visits set responsible_user_id = g.user_id where id = v.id;
      insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
      values (v.organization_id, v.id, v.case_id, v.team_id, 'returned',
              private.visit_slot_json(v) || jsonb_build_object('responsible_id', null),
              private.visit_slot_json(v) || jsonb_build_object('responsible_id', g.user_id),
              'Abwesenheit beendet', uid);
      returned := returned + 1;
    end loop;
  end loop;

  return jsonb_build_object('result', private.end_command('ok'), 'returned', returned);
end;
$$;
revoke all on function public.change_absence(uuid, boolean, date, time, uuid) from public, anon;
grant execute on function public.change_absence(uuid, boolean, date, time, uuid) to authenticated;
comment on function public.change_absence(uuid, boolean, date, time, uuid) is
  'ABS1: withdraws or shortens an absence in all teams of the member (ABS1-C3), by the absent member or the colleague '
  'who recorded it. Released visits nobody took return to her (fixed text Abwesenheit beendet); taken visits stay.';

-- 4b. The caller sees an absence once, even when she shares several teams with the absent member.
create or replace function public.team_absences()
returns table (absence_id uuid, team_id uuid, member text, is_me boolean, recorded_by_me boolean,
               starts_at timestamptz, ends_at timestamptz, may_change boolean)
language sql stable security definer set search_path = ''
as $$
  select x.id, x.team_id, x.member, x.is_me, x.recorded_by_me, x.starts_at, x.ends_at, x.may_change
  from (
    select distinct on (a.absence_group)
           a.id, a.team_id, a.starts_at, a.ends_at,
           case when a.user_id = (select auth.uid()) then 'me'
                else coalesce(private.member_name(a.organization_id, a.user_id), 'Teammitglied') end as member,
           a.user_id = (select auth.uid()) as is_me, a.recorded_by = (select auth.uid()) as recorded_by_me,
           (select auth.uid()) in (a.user_id, a.recorded_by) as may_change
    from public.member_absences a
    where a.withdrawn_at is null and a.ends_at > now()
      and private.is_org_member(a.organization_id) and private.is_team_member(a.team_id)
    order by a.absence_group, a.team_id) x
  order by x.starts_at, x.id
$$;
revoke all on function public.team_absences() from public, anon;
grant execute on function public.team_absences() to authenticated;
comment on function public.team_absences() is
  'ABS1: current and future absences of the caller''s teams (who, from, to), once per absence (ABS1-C3: one row per '
  'team underneath). No reason exists to show.';

-- 5. Overlap needs a time on both visits (ABS1-C2) ------------------------------------------------------------------
do $patch$
declare
  def  text := pg_get_functiondef('public.team_open_visits(date)'::regprocedure);
  find text := '            and private.visit_interval(x) && o.iv)';
begin
  if (length(def) - length(replace(def, find, ''))) / length(find) <> 1 then
    raise exception 'ABS1 part 2: team_open_visits no longer matches the overlap patch';
  end if;
  execute replace(def, find,
    '            and o.time_start is not null and x.time_start is not null
            and private.visit_interval(x) && o.iv)');
end
$patch$;

-- 6. AN1: three absence measures --------------------------------------------------------------------------------------
do $patch$
declare
  def text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  a   text := '  all_rows as (
    select * from visit_kpis';
  b   text := 'union all select * from returning_kpi
  )';
  c   text := '              when r.kpi = ''open_p1_exceptions'' then';
begin
  if position(a in def) = 0 or position(b in def) = 0 or position(c in def) = 0 then
    raise exception 'pilot_kpis no longer matches the ABS1 part 2 patch';
  end if;
  def := replace(def, a, '  -- ABS1: visits released by absences recorded this month (withdrawn or returned untaken, and cancelled ones,
  -- left out). taken_at = first take after the absence was recorded; the taker is always of the own team.
  absence_released as (
    select ab.id as absence_id, ab.organization_id, ab.team_id, ab.created_at as recorded_at,
           tk.changed_at as taken_at, tk.actor_id as taker, c.primary_nurse_id, c.deputy_nurse_id,
           private.visit_start_at(v.visit_date, v.time_start) - (select w.offer_lead from private.cover_window(v.organization_id) w) as lead_at
    from public.member_absences ab
    join public.absence_releases rl on rl.absence_id = ab.id
    join public.care_visits v on v.id = rl.visit_id
    left join public.cases c on c.id = v.case_id
    left join lateral (
      select pc.changed_at, pc.actor_id from public.visit_plan_changes pc
      where pc.visit_id = v.id and pc.change = ''taken'' and pc.changed_at >= ab.created_at
      order by pc.changed_at limit 1) tk on true
    , params p
    where ab.created_at >= p.m0 and ab.created_at < p.m1 and ab.team_id in (select id from my_teams)
      and v.status <> ''cancelled''
      and (tk.changed_at is not null or not exists (
            select 1 from public.visit_plan_changes pr where pr.visit_id = v.id and pr.change = ''returned''
              and pr.changed_at >= ab.created_at))
  ),
  absence_last_take as (
    select r.organization_id, r.team_id, extract(epoch from (max(r.taken_at) - min(r.recorded_at))) / 60 as minutes
    from absence_released r
    group by r.absence_id, r.organization_id, r.team_id
    having count(*) = count(r.taken_at)
  ),
  absence_kpi as (
    select r.organization_id, r.team_id, ''absence_taken_before_cover_lead'' as kpi,
           round(100.0 * count(*) filter (where r.taken_at is not null and r.taken_at <= r.lead_at) / count(*), 1) as value,
           count(*)::int as base
    from absence_released r where r.lead_at is not null
    group by grouping sets ((r.organization_id, r.team_id), (r.organization_id))
    union all
    select l.organization_id, l.team_id, ''absence_last_take_minutes'',
           round((percentile_cont(0.5) within group (order by l.minutes))::numeric, 0), count(*)::int
    from absence_last_take l
    group by grouping sets ((l.organization_id, l.team_id), (l.organization_id))
    union all
    select r.organization_id, r.team_id, ''absence_taken_by_known_share'',
           round(100.0 * count(*) filter (where r.taker in (r.deputy_nurse_id, r.primary_nurse_id)) / count(*), 1),
           count(*)::int
    from absence_released r where r.taken_at is not null
    group by grouping sets ((r.organization_id, r.team_id), (r.organization_id))
  ),
' || a);
  def := replace(def, b, 'union all select * from returning_kpi
    union all select * from absence_kpi
  )');
  def := replace(def, c, '              when r.kpi = ''absence_taken_before_cover_lead''
                then ''Freigegebene Einsätze aus Abwesenheiten dieses Monats; übernommen im eigenen Team vor der Vorlaufzeit für Nachbarteams.''
              when r.kpi = ''absence_last_take_minutes''
                then ''Nur Abwesenheiten, deren freigegebene Einsätze alle übernommen sind. Pro Team gezählt.''
              when r.kpi = ''absence_taken_by_known_share''
                then ''Bezugs- oder Stellvertretungsperson des Falls, wie heute erfasst.''
' || c);
  execute def;
end
$patch$;
