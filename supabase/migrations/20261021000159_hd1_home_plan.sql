-- HD-1 / HD-2 (founder FE-108 (2), founder live message 2026-11-20 ca. 17:45: «das Pflegeheim muss die Wochenplanung,
-- die Monatsplanung und den Plan für die Mitarbeiter machen können»; Blueprint V3.2 §4.5 B2B module 1, §5.4 P4;
-- brief docs/agents/briefs/HD.md, ARCH1 review finding A1).
--
-- The home plans ITS OWN staff. NAVORA is software, not an intermediary and not a dispatcher: nobody but the home's own
-- members reads or writes these rows. External teams are a separate product; the only bridge (gap → order) is HD-3.
--
-- What this migration adds:
--   * a home tenant `institutions` with its own members and roles (lead, planner, viewer), independent of any NAVORA
--     network organisation; every existing client account of kind `home` gets one (backfill, idempotent);
--   * stations, shift types, staff (synthetic names only in Phase A, grade code from the existing list), staffing
--     requirements per station and shift type (DATA OF THE HOME, NAVORA sets no staffing ratio and no clinical rule),
--     assignments and absences (no reason column: an absence never carries a reason);
--   * one read function `institution_plan(from, to)` for week, month and the plan per staff member (one status source);
--   * commands that check the role, lock the staff row and refuse an absent or double-booked person;
--   * an append-only audit table of every command.
--
-- Fixed, checkable rules only (no AI): a cell is «gap» when fewer present persons than the home's requirement are
-- assigned, or fewer of the required grade (exact grade code; no grade ordering is invented). Working-time law is NOT
-- checked (labelled on screen). Access: tables have RLS on and no grant to anon/authenticated; read and write only
-- through the SECURITY DEFINER functions below, each checking `private.is_institution_member`.
-- Idempotent (if not exists / create or replace / on conflict). Way back: drop the functions and the tables (no other
-- object reads them) and the column `client_accounts.institution_id`.

-- 1. Tenant ----------------------------------------------------------------------------------------------------------
create table if not exists public.institutions (
  id           uuid primary key default gen_random_uuid(),
  display_name text not null check (char_length(btrim(display_name)) between 2 and 120),
  kind         text not null check (kind in ('home', 'hospital_ward', 'household')),
  simulation   boolean not null default false,
  created_at   timestamptz not null default private.now()
);
comment on table public.institutions is
  'HD-1: a home (later hospital) as a B2B tenant for planning its own staff. Not a NAVORA network organisation. '
  'Read and written only through the institution_* functions.';
alter table public.institutions enable row level security;
revoke all on public.institutions from public, anon, authenticated;

create table if not exists public.institution_members (
  institution_id uuid not null references public.institutions (id) on delete cascade,
  user_id        uuid not null references auth.users (id) on delete cascade,
  role           text not null check (role in ('lead', 'planner', 'viewer')),
  created_at     timestamptz not null default private.now(),
  primary key (institution_id, user_id)
);
comment on table public.institution_members is
  'HD-1: who works in the home''s planning module and with which right: lead (everything, settings), planner (plan, '
  'staff, absences), viewer (read only).';
alter table public.institution_members enable row level security;
revoke all on public.institution_members from public, anon, authenticated;

alter table public.client_accounts add column if not exists institution_id uuid references public.institutions (id);

-- 2. Planning data ---------------------------------------------------------------------------------------------------
create table if not exists public.institution_stations (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions (id) on delete cascade,
  name           text not null check (char_length(btrim(name)) between 1 and 60),
  sort           integer not null default 0,
  created_at     timestamptz not null default private.now(),
  unique (institution_id, name),
  unique (id, institution_id)
);

create table if not exists public.institution_shift_types (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions (id) on delete cascade,
  code           text not null check (char_length(btrim(code)) between 1 and 12),
  label          text not null check (char_length(btrim(label)) between 1 and 40),
  starts_at      time not null,
  ends_at        time not null check (ends_at <> starts_at),
  sort           integer not null default 0,
  unique (institution_id, code),
  unique (id, institution_id)
);

create table if not exists public.institution_staff (
  id              uuid primary key default gen_random_uuid(),
  institution_id  uuid not null references public.institutions (id) on delete cascade,
  display_name    text not null check (char_length(btrim(display_name)) between 2 and 80),
  grade           text not null check (grade in ('ags_eba', 'fage_efz', 'nurse_hf_fh')),
  home_station_id uuid,
  active          boolean not null default true,
  created_at      timestamptz not null default private.now(),
  unique (id, institution_id),
  foreign key (home_station_id, institution_id) references public.institution_stations (id, institution_id)
);
comment on table public.institution_staff is
  'HD-1: the home''s own staff (B2B). Phase A: synthetic names only. Grade = the home''s confirmed level, codes of the '
  'existing list (QUAL1, PROPOSED). Never readable by a NAVORA team, network admin, coordinator or another home.';

create table if not exists public.institution_staffing_rules (
  institution_id       uuid not null references public.institutions (id) on delete cascade,
  station_id           uuid not null,
  shift_type_id        uuid not null,
  required_total       integer not null check (required_total between 0 and 50),
  required_grade       text check (required_grade is null or required_grade in ('ags_eba', 'fage_efz', 'nurse_hf_fh')),
  required_grade_count integer not null default 0 check (required_grade_count between 0 and 50),
  example              boolean not null default false,
  primary key (station_id, shift_type_id),
  foreign key (station_id, institution_id) references public.institution_stations (id, institution_id) on delete cascade,
  foreign key (shift_type_id, institution_id) references public.institution_shift_types (id, institution_id) on delete cascade,
  check ((required_grade is null) = (required_grade_count = 0)),
  check (required_grade_count <= required_total)
);
comment on table public.institution_staffing_rules is
  'HD-1: the minimum staffing per station and shift type AS SET BY THE HOME. NAVORA ships no value; example = true '
  'marks synthetic example values («Beispielwert des Heims, keine Vorgabe»).';

create table if not exists public.institution_assignments (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions (id) on delete cascade,
  station_id     uuid not null,
  shift_type_id  uuid not null,
  work_date      date not null,
  staff_id       uuid not null,
  created_by     uuid,
  created_at     timestamptz not null default private.now(),
  unique (staff_id, work_date, shift_type_id),
  foreign key (station_id, institution_id) references public.institution_stations (id, institution_id) on delete cascade,
  foreign key (shift_type_id, institution_id) references public.institution_shift_types (id, institution_id) on delete cascade,
  foreign key (staff_id, institution_id) references public.institution_staff (id, institution_id) on delete cascade
);
create index if not exists institution_assignments_by_date on public.institution_assignments (institution_id, work_date);

create table if not exists public.institution_absences (
  id             uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions (id) on delete cascade,
  staff_id       uuid not null,
  starts_on      date not null,
  ends_on        date not null,
  created_by     uuid,
  created_at     timestamptz not null default private.now(),
  check (ends_on >= starts_on and ends_on - starts_on <= 366),
  foreign key (staff_id, institution_id) references public.institution_staff (id, institution_id) on delete cascade
);
comment on table public.institution_absences is
  'HD-2: a staff member is absent from starts_on to ends_on. Deliberately no reason column (Blueprint §5.4).';
create index if not exists institution_absences_by_staff on public.institution_absences (staff_id, starts_on);

create table if not exists public.institution_audit_events (
  id             bigint generated always as identity primary key,
  occurred_at    timestamptz not null default private.now(),
  institution_id uuid not null references public.institutions (id) on delete cascade,
  actor_id       uuid,
  command        text not null,
  entity_table   text not null,
  entity_id      uuid,
  changed        jsonb not null default '{}'::jsonb
);
create index if not exists institution_audit_by_inst on public.institution_audit_events (institution_id, occurred_at desc);

do $$
declare t text;
begin
  foreach t in array array['institution_stations', 'institution_shift_types', 'institution_staff',
                           'institution_staffing_rules', 'institution_assignments', 'institution_absences',
                           'institution_audit_events'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
  end loop;
end $$;

create or replace function private.institution_audit_append_only()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'institution_audit_events is append-only' using errcode = '42501';
end $$;
revoke all on function private.institution_audit_append_only() from public, anon, authenticated;
drop trigger if exists institution_audit_append_only on public.institution_audit_events;
create trigger institution_audit_append_only before update or delete on public.institution_audit_events
  for each row when (pg_trigger_depth() < 1) execute function private.institution_audit_append_only();

-- 3. Membership check ------------------------------------------------------------------------------------------------
create or replace function private.is_institution_member(p_institution_id uuid, p_roles text[] default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.institution_members m
    where m.institution_id = p_institution_id
      and m.user_id = (select auth.uid())
      and (p_roles is null or m.role = any (p_roles))
      and not private.access_ended((select auth.uid())))  -- LEAVE1-3: a person whose access ended is nobody's member
$$;
revoke all on function private.is_institution_member(uuid, text[]) from public, anon;
grant execute on function private.is_institution_member(uuid, text[]) to authenticated;

create or replace function private.institution_audit(p_institution_id uuid, p_command text, p_table text, p_entity uuid,
                                                     p_changed jsonb)
returns void language sql security definer set search_path = '' as $$
  insert into public.institution_audit_events (institution_id, actor_id, command, entity_table, entity_id, changed)
  values (p_institution_id, (select auth.uid()), p_command, p_table, p_entity, coalesce(p_changed, '{}'::jsonb))
$$;
revoke all on function private.institution_audit(uuid, text, text, uuid, jsonb) from public, anon, authenticated;

-- A person is never member of a home and of a NAVORA network organisation the home orders from (same rule as BK-a).
create or replace function private.institution_member_not_org_member()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.client_accounts a
             join public.organization_memberships m on m.organization_id = a.organization_id
             where a.institution_id = new.institution_id and m.user_id = new.user_id) then
    raise exception 'institution_member_is_org_member' using errcode = '23514';
  end if;
  return new;
end $$;
revoke all on function private.institution_member_not_org_member() from public, anon, authenticated;
drop trigger if exists institution_member_not_org_member on public.institution_members;
create trigger institution_member_not_org_member before insert or update on public.institution_members
  for each row execute function private.institution_member_not_org_member();

-- 4. Backfill: every home client account gets its tenant; its client members become «lead» -------------------------
do $$
declare a record; inst uuid;
begin
  for a in select ca.id, ca.display_name, ca.client_kind, o.simulation
           from public.client_accounts ca join public.organizations o on o.id = ca.organization_id
           where ca.client_kind = 'home' and ca.institution_id is null loop
    insert into public.institutions (display_name, kind, simulation)
      values (a.display_name, a.client_kind, coalesce(a.simulation, false)) returning id into inst;
    update public.client_accounts set institution_id = inst where id = a.id;
    insert into public.institution_members (institution_id, user_id, role)
      select inst, cm.user_id, 'lead' from public.client_account_members cm where cm.client_account_id = a.id
      on conflict do nothing;
  end loop;
end $$;

-- 5. Reads -----------------------------------------------------------------------------------------------------------
create or replace function public.my_institutions()
returns table (id uuid, display_name text, kind text, role text, simulation boolean)
language sql stable security definer set search_path = '' as $$
  select i.id, i.display_name, i.kind, m.role, i.simulation
  from public.institution_members m join public.institutions i on i.id = m.institution_id
  where m.user_id = (select auth.uid())
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by i.display_name, i.id
$$;
revoke all on function public.my_institutions() from public, anon;
grant execute on function public.my_institutions() to authenticated;

-- The one status source for week, month and the plan per staff member (HD-2).
create or replace function public.institution_plan(p_institution_id uuid, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  inst public.institutions;
begin
  -- LEAVE1-3: is_institution_member is false for a person whose access ended.
  if p_institution_id is null or not private.is_institution_member(p_institution_id) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 41 then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('range_not_valid'));
  end if;
  select * into inst from public.institutions where id = p_institution_id;
  return jsonb_build_object(
    'result', 'ok',
    'institution', jsonb_build_object('id', inst.id, 'display_name', inst.display_name, 'simulation', inst.simulation,
      'role', (select m.role from public.institution_members m
               where m.institution_id = inst.id and m.user_id = (select auth.uid()))),
    'from', p_from, 'to', p_to,
    'stations', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.sort, s.name)
                          from public.institution_stations s where s.institution_id = inst.id), '[]'::jsonb),
    'shift_types', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'code', t.code, 'label', t.label,
                                     'starts_at', to_char(t.starts_at, 'HH24:MI'), 'ends_at', to_char(t.ends_at, 'HH24:MI'))
                                   order by t.sort, t.starts_at)
                             from public.institution_shift_types t where t.institution_id = inst.id), '[]'::jsonb),
    'staff', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'display_name', p.display_name, 'grade', p.grade,
                               'home_station_id', p.home_station_id, 'active', p.active) order by p.display_name, p.id)
                       from public.institution_staff p where p.institution_id = inst.id), '[]'::jsonb),
    'absences', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'staff_id', a.staff_id,
                                  'starts_on', a.starts_on, 'ends_on', a.ends_on) order by a.starts_on, a.id)
                          from public.institution_absences a
                          where a.institution_id = inst.id and a.starts_on <= p_to and a.ends_on >= p_from), '[]'::jsonb),
    'cells', coalesce((
      select jsonb_agg(jsonb_build_object(
               'date', c.d, 'station_id', c.station_id, 'shift_type_id', c.shift_type_id,
               'required_total', c.required_total, 'required_grade', c.required_grade,
               'required_grade_count', c.required_grade_count, 'example', c.example,
               'assigned', c.assigned, 'present', c.present, 'grade_present', c.grade_present,
               'missing', greatest(coalesce(c.required_total, 0) - c.present, 0),
               'status', case when c.required_total is null then 'no_rule'
                              when c.present >= c.required_total and c.grade_present >= c.required_grade_count then 'ok'
                              else 'gap' end)
             order by c.d, c.station_sort, c.station_name, c.shift_sort, c.shift_starts)
      from (
        select d.d::date as d, s.id as station_id, s.sort as station_sort, s.name as station_name,
               t.id as shift_type_id, t.sort as shift_sort, t.starts_at as shift_starts,
               r.required_total, r.required_grade, coalesce(r.required_grade_count, 0) as required_grade_count,
               coalesce(r.example, false) as example,
               coalesce(x.assigned, '[]'::jsonb) as assigned,
               coalesce(x.present, 0) as present,
               coalesce(x.grade_present, 0) as grade_present
        from generate_series(p_from, p_to, interval '1 day') d(d)
        cross join public.institution_stations s
        cross join public.institution_shift_types t
        left join public.institution_staffing_rules r on r.station_id = s.id and r.shift_type_id = t.id
        left join lateral (
          select jsonb_agg(jsonb_build_object('assignment_id', ia.id, 'staff_id', p.id, 'display_name', p.display_name,
                                              'grade', p.grade, 'absent', ab.absent) order by p.display_name, p.id) as assigned,
                 count(*) filter (where not ab.absent)::int as present,
                 count(*) filter (where not ab.absent and p.grade = r.required_grade)::int as grade_present
          from public.institution_assignments ia
          join public.institution_staff p on p.id = ia.staff_id
          cross join lateral (select exists (select 1 from public.institution_absences a
                                             where a.staff_id = p.id and d.d::date between a.starts_on and a.ends_on)
                              as absent) ab
          where ia.station_id = s.id and ia.shift_type_id = t.id and ia.work_date = d.d::date
        ) x on true
        where s.institution_id = inst.id and t.institution_id = inst.id
      ) c), '[]'::jsonb));
end $$;
revoke all on function public.institution_plan(uuid, date, date) from public, anon;
grant execute on function public.institution_plan(uuid, date, date) to authenticated;

-- 6. Commands --------------------------------------------------------------------------------------------------------
-- Interval of one shift on one date (a shift whose end is not after its start ends on the next day).
create or replace function private.institution_shift_span(p_date date, p_starts time, p_ends time)
returns tstzrange language sql immutable set search_path = '' as $$
  select tstzrange(private.at_zurich((p_date + p_starts)::timestamp),
                   private.at_zurich_end((case when p_ends > p_starts then p_date else p_date + 1 end + p_ends)::timestamp),
                   '[)')
$$;
revoke all on function private.institution_shift_span(date, time, time) from public, anon, authenticated;

create or replace function public.institution_assign_staff(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid,
                                                           p_work_date date, p_staff_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p    public.institution_staff;
  t    public.institution_shift_types;
  span tstzrange;
  new_id uuid;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  -- Lock the person: two planners assigning the same person at the same time are serialised here.
  select * into p from public.institution_staff where id = p_staff_id and institution_id = p_institution_id for update;
  select * into t from public.institution_shift_types where id = p_shift_type_id and institution_id = p_institution_id;
  if p.id is null or t.id is null or p_work_date is null
     or not exists (select 1 from public.institution_stations s where s.id = p_station_id and s.institution_id = p_institution_id) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_found'));
  end if;
  if not p.active then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('staff_inactive'));
  end if;
  if exists (select 1 from public.institution_assignments a where a.staff_id = p.id and a.work_date = p_work_date
             and a.shift_type_id = t.id) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('already_assigned'));
  end if;
  if exists (select 1 from public.institution_absences a where a.staff_id = p.id and p_work_date between a.starts_on and a.ends_on) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('staff_absent'));
  end if;
  span := private.institution_shift_span(p_work_date, t.starts_at, t.ends_at);
  if exists (select 1 from public.institution_assignments a
             join public.institution_shift_types o on o.id = a.shift_type_id
             where a.staff_id = p.id and a.work_date between p_work_date - 1 and p_work_date + 1
               and private.institution_shift_span(a.work_date, o.starts_at, o.ends_at) && span) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('staff_overlap'));
  end if;
  insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id, created_by)
    values (p_institution_id, p_station_id, t.id, p_work_date, p.id, (select auth.uid()))
    returning id into new_id;
  perform private.institution_audit(p_institution_id, 'institution_assign_staff', 'institution_assignments', new_id,
    jsonb_build_object('staff_id', p.id, 'station_id', p_station_id, 'shift_type_id', t.id, 'work_date', p_work_date));
  return jsonb_build_object('result', 'ok', 'assignment_id', new_id);
end $$;
revoke all on function public.institution_assign_staff(uuid, uuid, uuid, date, uuid) from public, anon;
grant execute on function public.institution_assign_staff(uuid, uuid, uuid, date, uuid) to authenticated;

create or replace function public.institution_unassign_staff(p_assignment_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a public.institution_assignments;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  select * into a from public.institution_assignments where id = p_assignment_id for update;
  if a.id is null or not private.is_institution_member(a.institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  delete from public.institution_assignments where id = a.id;
  perform private.institution_audit(a.institution_id, 'institution_unassign_staff', 'institution_assignments', a.id,
    jsonb_build_object('staff_id', a.staff_id, 'station_id', a.station_id, 'shift_type_id', a.shift_type_id,
                       'work_date', a.work_date));
  return jsonb_build_object('result', 'ok');
end $$;
revoke all on function public.institution_unassign_staff(uuid) from public, anon;
grant execute on function public.institution_unassign_staff(uuid) to authenticated;

create or replace function public.institution_record_absence(p_institution_id uuid, p_staff_id uuid, p_starts_on date,
                                                             p_ends_on date)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p public.institution_staff;
  new_id uuid;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  select * into p from public.institution_staff where id = p_staff_id and institution_id = p_institution_id for update;
  if p.id is null then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_found'));
  end if;
  if p_starts_on is null or p_ends_on is null or p_ends_on < p_starts_on or p_ends_on - p_starts_on > 366 then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('dates_not_valid'));
  end if;
  if exists (select 1 from public.institution_absences a where a.staff_id = p.id
             and a.starts_on <= p_ends_on and a.ends_on >= p_starts_on) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('absence_overlaps'));
  end if;
  insert into public.institution_absences (institution_id, staff_id, starts_on, ends_on, created_by)
    values (p_institution_id, p.id, p_starts_on, p_ends_on, (select auth.uid()))
    returning id into new_id;
  -- The assignments stay: the plan then shows the person as absent and the cell as a gap (the home decides).
  perform private.institution_audit(p_institution_id, 'institution_record_absence', 'institution_absences', new_id,
    jsonb_build_object('staff_id', p.id, 'starts_on', p_starts_on, 'ends_on', p_ends_on));
  return jsonb_build_object('result', 'ok', 'absence_id', new_id,
    'affected_assignments', (select count(*) from public.institution_assignments a
                             where a.staff_id = p.id and a.work_date between p_starts_on and p_ends_on));
end $$;
revoke all on function public.institution_record_absence(uuid, uuid, date, date) from public, anon;
grant execute on function public.institution_record_absence(uuid, uuid, date, date) to authenticated;

create or replace function public.institution_remove_absence(p_absence_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a public.institution_absences;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  select * into a from public.institution_absences where id = p_absence_id for update;
  if a.id is null or not private.is_institution_member(a.institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  delete from public.institution_absences where id = a.id;
  perform private.institution_audit(a.institution_id, 'institution_remove_absence', 'institution_absences', a.id,
    jsonb_build_object('staff_id', a.staff_id, 'starts_on', a.starts_on, 'ends_on', a.ends_on));
  return jsonb_build_object('result', 'ok');
end $$;
revoke all on function public.institution_remove_absence(uuid) from public, anon;
grant execute on function public.institution_remove_absence(uuid) to authenticated;

create or replace function public.institution_add_staff(p_institution_id uuid, p_display_name text, p_grade text,
                                                        p_home_station_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  new_id uuid;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_display_name is null or char_length(btrim(p_display_name)) not between 2 and 80
     or p_grade is null or p_grade not in ('ags_eba', 'fage_efz', 'nurse_hf_fh')
     or (p_home_station_id is not null and not exists (select 1 from public.institution_stations s
                                                       where s.id = p_home_station_id and s.institution_id = p_institution_id)) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('input_not_valid'));
  end if;
  insert into public.institution_staff (institution_id, display_name, grade, home_station_id)
    values (p_institution_id, btrim(p_display_name), p_grade, p_home_station_id)
    returning id into new_id;
  perform private.institution_audit(p_institution_id, 'institution_add_staff', 'institution_staff', new_id,
    jsonb_build_object('grade', p_grade, 'home_station_id', p_home_station_id));
  return jsonb_build_object('result', 'ok', 'staff_id', new_id);
end $$;
revoke all on function public.institution_add_staff(uuid, text, text, uuid) from public, anon;
grant execute on function public.institution_add_staff(uuid, text, text, uuid) to authenticated;

create or replace function public.institution_set_staff_active(p_staff_id uuid, p_active boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p public.institution_staff;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  select * into p from public.institution_staff where id = p_staff_id for update;
  if p.id is null or p_active is null or not private.is_institution_member(p.institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  update public.institution_staff set active = p_active where id = p.id;
  perform private.institution_audit(p.institution_id, 'institution_set_staff_active', 'institution_staff', p.id,
    jsonb_build_object('active', jsonb_build_object('old', p.active, 'new', p_active)));
  return jsonb_build_object('result', 'ok');
end $$;
revoke all on function public.institution_set_staff_active(uuid, boolean) from public, anon;
grant execute on function public.institution_set_staff_active(uuid, boolean) to authenticated;

create or replace function public.institution_add_station(p_institution_id uuid, p_name text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  new_id uuid;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 60 then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('input_not_valid'));
  end if;
  insert into public.institution_stations (institution_id, name, sort)
    values (p_institution_id, btrim(p_name),
            coalesce((select max(sort) + 1 from public.institution_stations where institution_id = p_institution_id), 0))
    on conflict (institution_id, name) do nothing
    returning id into new_id;
  if new_id is null then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('name_exists'));
  end if;
  perform private.institution_audit(p_institution_id, 'institution_add_station', 'institution_stations', new_id, '{}'::jsonb);
  return jsonb_build_object('result', 'ok', 'station_id', new_id);
end $$;
revoke all on function public.institution_add_station(uuid, text) from public, anon;
grant execute on function public.institution_add_station(uuid, text) to authenticated;

create or replace function public.institution_set_shift_type(p_institution_id uuid, p_code text, p_label text,
                                                             p_starts_at time, p_ends_at time)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  t_id uuid;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_code is null or char_length(btrim(p_code)) not between 1 and 12 or p_label is null
     or char_length(btrim(p_label)) not between 1 and 40 or p_starts_at is null or p_ends_at is null
     or p_starts_at = p_ends_at then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('input_not_valid'));
  end if;
  insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, sort)
    values (p_institution_id, btrim(p_code), btrim(p_label), p_starts_at, p_ends_at,
            coalesce((select max(sort) + 1 from public.institution_shift_types where institution_id = p_institution_id), 0))
    on conflict (institution_id, code) do update
      set label = excluded.label, starts_at = excluded.starts_at, ends_at = excluded.ends_at
    returning id into t_id;
  perform private.institution_audit(p_institution_id, 'institution_set_shift_type', 'institution_shift_types', t_id,
    jsonb_build_object('starts_at', to_char(p_starts_at, 'HH24:MI'), 'ends_at', to_char(p_ends_at, 'HH24:MI')));
  return jsonb_build_object('result', 'ok', 'shift_type_id', t_id);
end $$;
revoke all on function public.institution_set_shift_type(uuid, text, text, time, time) from public, anon;
grant execute on function public.institution_set_shift_type(uuid, text, text, time, time) to authenticated;

create or replace function public.institution_set_staffing_rule(p_institution_id uuid, p_station_id uuid,
                                                                p_shift_type_id uuid, p_required_total integer,
                                                                p_required_grade text, p_required_grade_count integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if not exists (select 1 from public.institution_stations where id = p_station_id and institution_id = p_institution_id)
     or not exists (select 1 from public.institution_shift_types where id = p_shift_type_id and institution_id = p_institution_id)
     or p_required_total is null or p_required_total not between 0 and 50
     or coalesce(p_required_grade_count, 0) not between 0 and 50
     or coalesce(p_required_grade_count, 0) > p_required_total
     or (p_required_grade is null) <> (coalesce(p_required_grade_count, 0) = 0)
     or (p_required_grade is not null and p_required_grade not in ('ags_eba', 'fage_efz', 'nurse_hf_fh')) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('input_not_valid'));
  end if;
  insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total,
                                                 required_grade, required_grade_count, example)
    values (p_institution_id, p_station_id, p_shift_type_id, p_required_total, p_required_grade,
            coalesce(p_required_grade_count, 0), false)
    on conflict (station_id, shift_type_id) do update
      set required_total = excluded.required_total, required_grade = excluded.required_grade,
          required_grade_count = excluded.required_grade_count, example = false;
  perform private.institution_audit(p_institution_id, 'institution_set_staffing_rule', 'institution_staffing_rules',
    p_station_id, jsonb_build_object('shift_type_id', p_shift_type_id, 'required_total', p_required_total,
                                     'required_grade', p_required_grade, 'required_grade_count', p_required_grade_count));
  return jsonb_build_object('result', 'ok');
end $$;
revoke all on function public.institution_set_staffing_rule(uuid, uuid, uuid, integer, text, integer) from public, anon;
grant execute on function public.institution_set_staffing_rule(uuid, uuid, uuid, integer, text, integer) to authenticated;

-- Synthetic example (simulation tenants only, once): two stations, three shift types, eight synthetic persons,
-- example staffing values of the home and the plan of the given week. Every value is marked as example.
create or replace function public.institution_load_example(p_institution_id uuid, p_week_start date)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  inst public.institutions;
  s1 uuid; s2 uuid; f uuid; sp uuid; n uuid;
  d date;
  staff_ids uuid[];
  i int;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  select * into inst from public.institutions where id = p_institution_id for update;
  if inst.id is null or not private.is_institution_member(inst.id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if not inst.simulation then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_simulation'));
  end if;
  if p_week_start is null or exists (select 1 from public.institution_stations where institution_id = inst.id)
     or exists (select 1 from public.institution_staff where institution_id = inst.id) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_empty'));
  end if;
  insert into public.institution_stations (institution_id, name, sort) values (inst.id, 'Rhein 1', 0) returning id into s1;
  insert into public.institution_stations (institution_id, name, sort) values (inst.id, 'Rhein 2', 1) returning id into s2;
  insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, sort) values
    (inst.id, 'F', 'Früh', '07:00', '15:30', 0) returning id into f;
  insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, sort) values
    (inst.id, 'S', 'Spät', '14:30', '23:00', 1) returning id into sp;
  insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, sort) values
    (inst.id, 'N', 'Nacht', '22:30', '07:15', 2) returning id into n;
  insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total,
                                                 required_grade, required_grade_count, example) values
    (inst.id, s1, f, 2, 'nurse_hf_fh', 1, true), (inst.id, s1, sp, 2, 'nurse_hf_fh', 1, true),
    (inst.id, s1, n, 1, null, 0, true),
    (inst.id, s2, f, 3, 'nurse_hf_fh', 1, true), (inst.id, s2, sp, 2, 'nurse_hf_fh', 1, true),
    (inst.id, s2, n, 1, null, 0, true);
  with ins as (
    insert into public.institution_staff (institution_id, display_name, grade, home_station_id)
    select inst.id, v.name, v.grade, case when v.st = 1 then s1 else s2 end
    from (values ('Anna Muster', 'nurse_hf_fh', 2, 1), ('Ben Beispiel', 'fage_efz', 2, 2), ('Carla Test', 'fage_efz', 2, 3),
                 ('David Probe', 'ags_eba', 2, 4), ('Eva Fiktiv', 'nurse_hf_fh', 1, 5), ('Felix Demo', 'fage_efz', 1, 6),
                 ('Gina Simul', 'nurse_hf_fh', 2, 7), ('Hugo Platz', 'ags_eba', 1, 8)) v(name, grade, st, ord)
    order by v.ord
    returning id, display_name)
  select array_agg(id order by display_name) into staff_ids from ins;
  -- staff_ids by name: 1 Anna(HF,R2) 2 Ben(FaGe,R2) 3 Carla(FaGe,R2) 4 David(AGS,R2) 5 Eva(HF,R1) 6 Felix(FaGe,R1)
  --                    7 Gina(HF,R2) 8 Hugo(AGS,R1)
  for i in 0..6 loop
    d := p_week_start + i;
    -- Rhein 2 Früh: Anna, Ben, Carla (Mon–Fri), weekend only two (a visible gap)
    insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id)
      values (inst.id, s2, f, d, staff_ids[1]), (inst.id, s2, f, d, staff_ids[2]);
    if i < 5 then
      insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id)
        values (inst.id, s2, f, d, staff_ids[3]);
    end if;
    -- Rhein 2 Spät: Gina, David
    insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id)
      values (inst.id, s2, sp, d, staff_ids[7]), (inst.id, s2, sp, d, staff_ids[4]);
    -- Rhein 1 Früh: Eva, Felix; Rhein 1 Spät: Hugo only (gap, HF missing)
    insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id)
      values (inst.id, s1, f, d, staff_ids[5]), (inst.id, s1, f, d, staff_ids[6]), (inst.id, s1, sp, d, staff_ids[8]);
  end loop;
  perform private.institution_audit(inst.id, 'institution_load_example', 'institutions', inst.id,
    jsonb_build_object('week_start', p_week_start));
  return jsonb_build_object('result', 'ok');
end $$;
revoke all on function public.institution_load_example(uuid, date) from public, anon;
grant execute on function public.institution_load_example(uuid, date) to authenticated;
