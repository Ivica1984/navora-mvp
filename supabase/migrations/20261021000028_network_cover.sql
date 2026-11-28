-- COVER1: cross-team cover without a dispatcher (PO brief docs/agents/briefs/COVER1.md, ADR-045).
--
-- * Answer to the brief's question: the J2 pattern is reused (offers derived from state, first decision
--   wins atomically, no identity before acceptance), but not its tables: a visit offer has no matching
--   request, so offers are derived per visit and the decisions live in `cover_events`.
-- * Offer window: a planned visit without a responsible member, not suspended, of an active case, whose
--   start lies between the fallback lead (default 4 h) and the offer lead (default 24 h). Platform defaults
--   in `cover_settings` (organisation override possible later through ADM1).
-- * Offered to members of OTHER active teams of the same organisation and region; category B or a needs
--   assessment only to registered nurses. The offer shows date, time window, area (town), services with
--   category and minutes, and the required qualification — never client identity.
-- * Acceptance assigns that one visit to the accepting nurse atomically (responsible member, covered_by,
--   cover_team_id). The case, its team and its primary nurse stay unchanged; J6 counts it "not primary";
--   J5 bills it as usual; F6: the covering nurse signs.
-- * Context access for the covering nurse (field view, starting the visit) waits for owner decision D-3:
--   until then RLS keeps the visit with its team, and the covering nurse sees only her accepted covers
--   with the same minimal facts as the offer.
-- * After the fallback lead nobody can accept; the OPS1 uncovered-visit exception is unchanged.
-- * Every offer (first time seen), acceptance and expiry is an append-only cover event; the own team sees
--   who covered (team name; names follow ADM1).

-- 1. Structure ------------------------------------------------------------------------------------------------
create table public.cover_settings (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid references public.organizations (id),
  offer_lead_hours     integer not null check (offer_lead_hours between 1 and 168),
  fallback_lead_hours  integer not null check (fallback_lead_hours between 0 and 72),
  check (fallback_lead_hours < offer_lead_hours),
  unique nulls not distinct (organization_id)
);
insert into public.cover_settings (organization_id, offer_lead_hours, fallback_lead_hours) values (null, 24, 4);
alter table public.cover_settings enable row level security;
revoke all on public.cover_settings from anon, authenticated;
grant select on public.cover_settings to authenticated;
create policy members_read on public.cover_settings for select to authenticated
  using (organization_id is null or private.is_org_member(organization_id));

alter table public.care_visits
  add column covered_by    uuid,
  add column covered_at    timestamptz,
  add column cover_team_id uuid references public.teams (id);

create table public.cover_events (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,
  kind            text not null check (kind in ('offered', 'accepted', 'expired')),
  nurse_id        uuid,
  team_id         uuid,             -- the covering nurse's team (accepted)
  created_at      timestamptz not null default now(),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id)
);
create unique index cover_events_once on public.cover_events (visit_id, kind) where kind in ('offered', 'expired', 'accepted');
alter table public.cover_events enable row level security;
revoke all on public.cover_events from anon, authenticated;
grant select on public.cover_events to authenticated;
create policy scoped_read on public.cover_events for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_coordinator(organization_id)
              or exists (select 1 from public.care_visits v where v.id = visit_id and private.is_team_member(v.team_id))
              or nurse_id = (select auth.uid())));
create trigger cover_events_no_update_delete before update or delete on public.cover_events
  for each row execute function private.forbid_audit_change();
create trigger audit_cover_events after insert on public.cover_events
  for each row execute function private.write_audit_event('kind', 'nurse_id', 'team_id');

-- 2. Helpers -------------------------------------------------------------------------------------------------------
create function private.visit_start_at(p_date date, p_time time)
returns timestamptz language sql immutable set search_path = ''
as $$ select (p_date + coalesce(p_time, '00:00'::time)) at time zone 'Europe/Zurich' $$;

create function private.cover_window(p_org uuid)
returns table (offer_lead interval, fallback_lead interval)
language sql stable security definer set search_path = ''
as $$
  select make_interval(hours => s.offer_lead_hours), make_interval(hours => s.fallback_lead_hours)
  from public.cover_settings s where s.organization_id = p_org or s.organization_id is null
  order by s.organization_id nulls last limit 1
$$;

-- Visits of an organisation that are open for cover right now.
create function private.cover_open_visits(p_org uuid)
returns setof public.care_visits
language sql stable security definer set search_path = ''
as $$
  select v.* from public.care_visits v
  join public.cases c on c.id = v.case_id
  join public.teams t on t.id = v.team_id
  cross join private.cover_window(p_org) w
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.covered_by is null
    and v.suspended_at is null and c.lifecycle = 'active' and t.status = 'active'
    and private.visit_start_at(v.visit_date, v.time_start) > now() + w.fallback_lead
    and private.visit_start_at(v.visit_date, v.time_start) <= now() + w.offer_lead
$$;
revoke all on function private.visit_start_at(date, time), private.cover_window(uuid), private.cover_open_visits(uuid) from public, anon, authenticated;

-- Can this user cover this visit? Member of another active team of the same organisation and region,
-- registered nurse there when the visit has category B or is a needs assessment. Returns her team.
create function private.cover_team_for(p_visit public.care_visits, p_user uuid)
returns uuid language sql stable security definer set search_path = ''
as $$
  select m.team_id
  from public.team_memberships m
  join public.teams mine on mine.id = m.team_id
  join public.teams own on own.id = p_visit.team_id
  where m.user_id = p_user and mine.organization_id = p_visit.organization_id and mine.id <> p_visit.team_id
    and mine.status = 'active' and mine.region is not distinct from own.region
    and not exists (select 1 from public.team_memberships x where x.team_id = p_visit.team_id and x.user_id = p_user)
    and ((coalesce(p_visit.planned_minutes_b, 0) = 0 and not coalesce(p_visit.is_needs_assessment, false))
         or m.qualification = 'registered_nurse')
  order by (m.qualification = 'registered_nurse') desc, mine.name
  limit 1
$$;
revoke all on function private.cover_team_for(public.care_visits, uuid) from public, anon, authenticated;

-- 3. Read models ---------------------------------------------------------------------------------------------------
-- Offers for the caller: minimal facts only, no client identity (J2 rule).
create function public.cover_offers()
returns table (visit_id uuid, visit_date date, time_start time, time_end time, area text, team_name text,
               services text[], minutes_a integer, minutes_b integer, minutes_c integer,
               required_qualification text, closes_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select v.id, v.visit_date, v.time_start, v.time_end, c.ort, t.name, v.services_provided,
         v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c,
         case when coalesce(v.planned_minutes_b, 0) > 0 or v.is_needs_assessment then 'registered_nurse' end,
         private.visit_start_at(v.visit_date, v.time_start) - w.fallback_lead
  from public.organization_memberships o
  cross join lateral private.cover_open_visits(o.organization_id) v
  cross join lateral private.cover_window(o.organization_id) w
  join public.cases c on c.id = v.case_id
  join public.teams t on t.id = v.team_id
  where o.user_id = (select auth.uid()) and private.cover_team_for(v, (select auth.uid())) is not null
  order by v.visit_date, v.time_start
$$;

-- The covering nurse's accepted covers: the same minimal facts (context access waits for D-3).
create function public.my_covers()
returns table (visit_id uuid, visit_date date, time_start time, time_end time, area text, team_name text,
               services text[], minutes_a integer, minutes_b integer, minutes_c integer, status text, covered_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select v.id, v.visit_date, v.time_start, v.time_end, c.ort, t.name, v.services_provided,
         v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c, v.status, v.covered_at
  from public.care_visits v
  join public.cases c on c.id = v.case_id
  join public.teams t on t.id = v.team_id
  where v.covered_by = (select auth.uid()) and private.is_org_member(v.organization_id)
    and v.visit_date >= (now() at time zone 'Europe/Zurich')::date - 1
  order by v.visit_date, v.time_start
$$;

-- 4. Commands ------------------------------------------------------------------------------------------------------
-- Records "offered" the first time a visit is open, and "expired" when the fallback lead passed without
-- acceptance. Called by the field page on load (OPS1 sync pattern). Returns the number of new events.
create function public.sync_cover_offers()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  n   integer := 0;
  k   integer;
  org uuid;
begin
  if uid is null then return 0; end if;
  for org in select o.organization_id from public.organization_memberships o where o.user_id = uid loop
    insert into public.cover_events (organization_id, visit_id, kind)
    select v.organization_id, v.id, 'offered' from private.cover_open_visits(org) v
    on conflict do nothing;
    get diagnostics k = row_count; n := n + k;
    insert into public.cover_events (organization_id, visit_id, kind)
    select e.organization_id, e.visit_id, 'expired'
    from public.cover_events e
    join public.care_visits v on v.id = e.visit_id
    cross join private.cover_window(org) w
    where e.organization_id = org and e.kind = 'offered'
      and v.covered_by is null and private.visit_start_at(v.visit_date, v.time_start) <= now() + w.fallback_lead
      and not exists (select 1 from public.cover_events x where x.visit_id = e.visit_id and x.kind in ('accepted', 'expired'))
    on conflict do nothing;
    get diagnostics k = row_count; n := n + k;
  end loop;
  return n;
end;
$$;

-- First acceptance wins. Return: 'ok' | 'taken' | 'duplicate' | 'rejected'
create function public.accept_cover(p_visit_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  v    public.care_visits%rowtype;
  team uuid;
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('accept_cover', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into v from public.care_visits where id = p_visit_id for update;
  if not found or not private.is_org_member(v.organization_id) then
    return private.end_command('rejected');
  end if;
  team := private.cover_team_for(v, uid);
  if team is null then
    return private.end_command('rejected');
  end if;
  if not exists (select 1 from private.cover_open_visits(v.organization_id) o where o.id = v.id) then
    return private.end_command('taken');     -- covered, assigned, outside the window or no longer planned
  end if;
  update public.care_visits
    set responsible_user_id = uid, covered_by = uid, covered_at = now(), cover_team_id = team
    where id = v.id;
  insert into public.cover_events (organization_id, visit_id, kind)
  values (v.organization_id, v.id, 'offered') on conflict do nothing;
  insert into public.cover_events (organization_id, visit_id, kind, nurse_id, team_id)
  values (v.organization_id, v.id, 'accepted', uid, team);
  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  select x.organization_id, x.id, x.case_id, x.team_id, 'moved', private.visit_slot_json(v), private.visit_slot_json(x),
         'cover by another team', uid
  from public.care_visits x where x.id = v.id;
  return private.end_command('ok');
end;
$$;

revoke all on function public.cover_offers(), public.my_covers(), public.sync_cover_offers(), public.accept_cover(uuid, uuid) from public, anon;
grant execute on function public.cover_offers(), public.my_covers(), public.sync_cover_offers(), public.accept_cover(uuid, uuid) to authenticated;

-- 5. The own team sees who covered (team view JSON; names follow ADM1) ----------------------------------------------
do $$
declare
  def  text := pg_get_functiondef('public.team_cases()'::regprocedure);
  find text := $f$'responsible_set', x.responsible_user_id is not null,$f$;
begin
  if position(find in def) = 0 then raise exception 'COVER1: team_cases patch did not match'; end if;
  execute replace(def, find, find || $r$
                    'covered_by_team', (select ct.name from public.teams ct where ct.id = x.cover_team_id),$r$);
end;
$$;

-- 6. AN1: uncovered visits resolved without Operations, and time to cover ------------------------------------------
do $$
declare
  def  text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  find text := $f$('cover_without_operations', 'Noch nicht messbar: COVER1 ist noch nicht gebaut.')) k(kpi, note)$f$;
  rows_find text := $f$  all_rows as (
    select * from visit_kpis union all select * from billing union all select * from referral
    union all select * from offers union all select * from p1
  )$f$;
begin
  if position(find in def) = 0 or position(rows_find in def) = 0 then raise exception 'COVER1: pilot_kpis patch did not match'; end if;
  def := replace(def, $f$,
    ('cover_without_operations', 'Noch nicht messbar: COVER1 ist noch nicht gebaut.')) k(kpi, note)$f$, $f$) k(kpi, note)$f$);
  def := replace(def, rows_find, $r$  cover as (
    select v.organization_id, v.team_id, 'cover_without_operations' as kpi,
           round(100.0 * count(*) filter (where exists (select 1 from public.cover_events e where e.visit_id = v.id and e.kind = 'accepted'))
                 / count(*), 1) as value,
           count(*)::int as base
    from visits v
    where exists (select 1 from public.cover_events e where e.visit_id = v.id and e.kind = 'offered')
    group by grouping sets ((v.organization_id, v.team_id), (v.organization_id))
    union all
    select v.organization_id, v.team_id, 'cover_median_hours',
           round((percentile_cont(0.5) within group (order by extract(epoch from (a.created_at - o.created_at)) / 3600))::numeric, 1),
           count(*)::int
    from visits v
    join public.cover_events o on o.visit_id = v.id and o.kind = 'offered'
    join public.cover_events a on a.visit_id = v.id and a.kind = 'accepted'
    group by grouping sets ((v.organization_id, v.team_id), (v.organization_id))
  ),
  all_rows as (
    select * from visit_kpis union all select * from billing union all select * from referral
    union all select * from offers union all select * from p1 union all select * from cover
  )$r$);
  execute def;
end;
$$;
