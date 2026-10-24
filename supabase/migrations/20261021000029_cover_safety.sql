-- COVER1 changes requested by the PO (review 2026-10-22 14:30, patient safety). ADR-045 amended.
--
-- * Cover is OFF until D-3: `cover_settings.cover_enabled` (platform default false). While off, no visit is
--   open for cover, `cover_offers` is empty and `accept_cover` returns 'disabled'.
-- * A covered visit stays safe until it can be performed: acceptance records the covering nurse
--   (`covered_by`) but no longer sets the responsible member, because she cannot see or start the visit
--   before D-3. So the case team keeps its "uncovered" flag, and OPS1 shows "Übernahme ohne Zugriff"
--   (P2, P1 from 4 h before the start) instead of the plain uncovered-visit exception.
-- * Withdraw: the covering nurse hands a cover back with a reason up to the fallback lead; the visit is
--   offered again; the case team sees it in its plan change log.
-- * Offer events at the right time: a job (pg_cron, every 10 minutes, where available) records "offered"
--   when a visit enters the window and "expired" when it leaves it; the page-load sync stays as backup.
-- * Two empty regions never match.
-- * Not built: context access for the covering nurse (D-3). Until then cover stays off.

-- 1. Switch and events ------------------------------------------------------------------------------------------
alter table public.cover_settings add column cover_enabled boolean not null default false;

alter table public.cover_events drop constraint cover_events_kind_check;
alter table public.cover_events add constraint cover_events_kind_check
  check (kind in ('offered', 'accepted', 'expired', 'withdrawn'));
alter table public.cover_events add column reason text check (reason is null or char_length(btrim(reason)) between 3 and 300);
-- Order of events inside one transaction (now() is the same for all of them).
alter table public.cover_events add column seq bigint generated always as identity;
-- A visit can be offered, accepted and withdrawn again; the current round is what counts.
drop index public.cover_events_once;
create unique index cover_events_one_expiry on public.cover_events (visit_id) where kind = 'expired';

create or replace function private.cover_window(p_org uuid)
returns table (offer_lead interval, fallback_lead interval)
language sql stable security definer set search_path = ''
as $$
  select make_interval(hours => s.offer_lead_hours), make_interval(hours => s.fallback_lead_hours)
  from public.cover_settings s where s.organization_id = p_org or s.organization_id is null
  order by s.organization_id nulls last limit 1
$$;

create function private.cover_enabled(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((select s.cover_enabled from public.cover_settings s
                   where s.organization_id = p_org or s.organization_id is null
                   order by s.organization_id nulls last limit 1), false)
$$;
revoke all on function private.cover_enabled(uuid) from public, anon, authenticated;

-- Open for cover: as before, and only where cover is on.
create or replace function private.cover_open_visits(p_org uuid)
returns setof public.care_visits
language sql stable security definer set search_path = ''
as $$
  select v.* from public.care_visits v
  join public.cases c on c.id = v.case_id
  join public.teams t on t.id = v.team_id
  cross join private.cover_window(p_org) w
  where private.cover_enabled(p_org)
    and v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.covered_by is null
    and v.suspended_at is null and c.lifecycle = 'active' and t.status = 'active'
    and private.visit_start_at(v.visit_date, v.time_start) > now() + w.fallback_lead
    and private.visit_start_at(v.visit_date, v.time_start) <= now() + w.offer_lead
$$;

-- Same organisation and a real, equal region (two empty regions never match).
create or replace function private.cover_team_for(p_visit public.care_visits, p_user uuid)
returns uuid language sql stable security definer set search_path = ''
as $$
  select m.team_id
  from public.team_memberships m
  join public.teams mine on mine.id = m.team_id
  join public.teams own on own.id = p_visit.team_id
  where m.user_id = p_user and mine.organization_id = p_visit.organization_id and mine.id <> p_visit.team_id
    and mine.status = 'active' and nullif(btrim(mine.region), '') is not null and mine.region = own.region
    and not exists (select 1 from public.team_memberships x where x.team_id = p_visit.team_id and x.user_id = p_user)
    and ((coalesce(p_visit.planned_minutes_b, 0) = 0 and not coalesce(p_visit.is_needs_assessment, false))
         or m.qualification = 'registered_nurse')
  order by (m.qualification = 'registered_nurse') desc, mine.name
  limit 1
$$;

-- 2. Event recording at the right time --------------------------------------------------------------------------
create function private.sync_cover_events(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  n integer := 0;
  k integer;
begin
  -- Offered: open now, and no offer recorded since the last withdrawal (or ever).
  insert into public.cover_events (organization_id, visit_id, kind)
  select v.organization_id, v.id, 'offered' from private.cover_open_visits(p_org) v
  where not exists (select 1 from public.cover_events e where e.visit_id = v.id and e.kind = 'offered'
                      and e.seq > coalesce((select max(w.seq) from public.cover_events w
                                            where w.visit_id = v.id and w.kind = 'withdrawn'), 0));
  get diagnostics k = row_count; n := n + k;
  -- Expired: offered, not covered, and the fallback lead has passed.
  insert into public.cover_events (organization_id, visit_id, kind)
  select distinct e.organization_id, e.visit_id, 'expired'
  from public.cover_events e
  join public.care_visits v on v.id = e.visit_id
  cross join private.cover_window(p_org) w
  where e.organization_id = p_org and e.kind = 'offered' and v.covered_by is null
    and private.visit_start_at(v.visit_date, v.time_start) <= now() + w.fallback_lead
  on conflict do nothing;
  get diagnostics k = row_count; n := n + k;
  return n;
end;
$$;
revoke all on function private.sync_cover_events(uuid) from public, anon, authenticated;

create or replace function public.sync_cover_offers()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  n   integer := 0;
  org uuid;
begin
  if uid is null then return 0; end if;
  for org in select o.organization_id from public.organization_memberships o where o.user_id = uid loop
    n := n + private.sync_cover_events(org);
  end loop;
  return n;
end;
$$;

create function private.sync_all_cover_events()
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  n integer := 0;
  org uuid;
begin
  for org in select o.id from public.organizations o loop
    n := n + private.sync_cover_events(org);
  end loop;
  return n;
end;
$$;
revoke all on function private.sync_all_cover_events() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      execute $cron$select cron.schedule('navora-cover1-events', '*/10 * * * *', 'select private.sync_all_cover_events()')$cron$;
    exception when others then
      raise notice 'COVER1: cover job not scheduled (%); page-load sync records the events', sqlerrm;
    end;
  else
    raise notice 'COVER1: pg_cron not available; page-load sync records the events';
  end if;
end;
$$;

-- 3. Acceptance without access keeps the visit uncovered for the team; withdraw ---------------------------------
-- Return: 'ok' | 'taken' | 'disabled' | 'duplicate' | 'rejected'
create or replace function public.accept_cover(p_visit_id uuid, p_idempotency_key uuid)
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
  if not private.cover_enabled(v.organization_id) then
    return private.end_command('disabled');
  end if;
  team := private.cover_team_for(v, uid);
  if team is null then
    return private.end_command('rejected');
  end if;
  if not exists (select 1 from private.cover_open_visits(v.organization_id) o where o.id = v.id) then
    return private.end_command('taken');     -- covered, assigned, outside the window or no longer planned
  end if;
  -- The responsible member stays empty until she can perform the visit (D-3): the team keeps its flag.
  update public.care_visits set covered_by = uid, covered_at = now(), cover_team_id = team where id = v.id;
  perform private.sync_cover_events(v.organization_id);
  insert into public.cover_events (organization_id, visit_id, kind, nurse_id, team_id)
  values (v.organization_id, v.id, 'accepted', uid, team);
  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  select x.organization_id, x.id, x.case_id, x.team_id, 'moved', private.visit_slot_json(v), private.visit_slot_json(x),
         'cover by another team', uid
  from public.care_visits x where x.id = v.id;
  return private.end_command('ok');
end;
$$;

-- The covering nurse hands the cover back, with a reason, up to the fallback lead. Return: 'ok' | 'too_late' |
-- 'duplicate' | 'rejected'
create function public.withdraw_cover(p_visit_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text;
begin
  if uid is null then return 'rejected'; end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('withdraw_cover', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into v from public.care_visits where id = p_visit_id for update;
  if not found or v.covered_by is distinct from uid or v.status <> 'planned' then
    return private.end_command('rejected');
  end if;
  if private.visit_start_at(v.visit_date, v.time_start) <= now() + (select w.fallback_lead from private.cover_window(v.organization_id) w) then
    return private.end_command('too_late');
  end if;
  update public.care_visits set covered_by = null, covered_at = null, cover_team_id = null where id = v.id;
  insert into public.cover_events (organization_id, visit_id, kind, nurse_id, team_id, reason)
  values (v.organization_id, v.id, 'withdrawn', uid, v.cover_team_id, why);
  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  select x.organization_id, x.id, x.case_id, x.team_id, 'moved', private.visit_slot_json(v), private.visit_slot_json(x),
         left('cover withdrawn: ' || why, 300), uid
  from public.care_visits x where x.id = v.id;
  perform private.sync_cover_events(v.organization_id);   -- offered again
  return private.end_command('ok');
end;
$$;
revoke all on function public.withdraw_cover(uuid, text, uuid) from public, anon;
grant execute on function public.withdraw_cover(uuid, text, uuid) to authenticated;

-- my_covers: a withdrawn cover disappears (covered_by is cleared); unchanged otherwise.

-- 4. OPS1: "Übernahme ohne Zugriff" replaces the plain uncovered exception for covered visits ------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  ('cover_without_access', 'P2', 24, 'hours', 20, 'Übernahme ohne Zugriff',
   'Die übernehmende Pflegeperson sieht den Einsatz noch nicht (D-3): Team und Pflegeperson kontaktieren und den Einsatz sicherstellen.');

do $$
declare
  def  text := pg_get_functiondef('private.derived_exceptions(uuid)'::regprocedure);
  f1   text := $f$  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.suspended_at is null$f$;
  f2   text := $f$  -- J3: medical order expiring within the threshold or expired, on a running case$f$;
begin
  if position(f1 in def) = 0 or position(f2 in def) = 0 then raise exception 'COVER1 fix: derived_exceptions patch did not match'; end if;
  def := replace(def, f1, f1 || ' and v.covered_by is null');
  def := replace(def, f2, $r$  -- COVER1: covered by another team but not yet performable (no access before D-3); since = start − 24 h,
  -- so the rule's escalation (20 h) makes it P1 from 4 h before the start
  select 'cover_without_access:' || v.id, 'cover_without_access',
         (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich' - interval '24 hours', v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
           || ' · übernommen von ' || coalesce((select t.name from public.teams t where t.id = v.cover_team_id), 'einem anderen Team')
  from public.care_visits v
  join rules r on r.exception_type = 'cover_without_access'
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.suspended_at is null
    and v.covered_by is not null
    and (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich'
        between now() and private.after_threshold(now(), r.amount, r.unit)
  union all
$r$ || f2);
  execute def;
end;
$$;
