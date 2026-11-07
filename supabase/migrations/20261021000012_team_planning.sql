-- =============================================================================
-- J3 — Team planning: the team schedules visits for its own cases
-- ARCHITECTURE workflow: "… Teamentscheid → Teamplanung → Einsatz …"
-- DOMAIN_RULES Teamautonomie: "Selbstorganisiertes Team plant Einsätze … selbst.
--   Kein Linienvorgesetzter durch UI-/Rollenmodell erzeugen."
-- =============================================================================
-- * Any member of the team a case is assigned to may plan, move or remove
--   PLANNED visits of that case. No coach/operations override (no dispatcher).
-- * A planned visit belongs to the team (assignee = team until D-6).
-- * Times: end after start, both within the day. Dates: from yesterday (Swiss
--   time) up to 366 days ahead — typing errors, not a clinical rule.
-- * Only visits in status `planned` can be moved or removed. Started or
--   completed visits are facts (F2) and stay. Removal of a planned visit is a
--   hard delete of a plan, audited; cancellation of a confirmed visit with
--   client-facing consequences is D-6 (cancelled / no_show) and not modelled.
-- * Every plan, move and removal is audited (care_visits audit trigger now also
--   covers INSERT and DELETE).
-- =============================================================================

-- Audit inserts and deletes of visits too (updates were audited since T10).
create function private.write_audit_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.audit_events
    (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values
    (old.organization_id, (select auth.uid()),
     coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', session_user::text),
     tg_table_name, old.id,
     nullif(current_setting('navora.command', true), ''),
     nullif(current_setting('navora.idempotency_key', true), '')::uuid,
     jsonb_build_object('deleted', true, 'status', old.status, 'visit_date', old.visit_date));
  return old;
end;
$$;

revoke all on function private.write_audit_delete() from public, anon, authenticated;

create trigger audit_care_visits_insert
  after insert on public.care_visits
  for each row execute function private.write_audit_event('status', 'team_id', 'case_id', 'visit_date', 'time_start', 'time_end');
create trigger audit_care_visits_delete
  after delete on public.care_visits
  for each row execute function private.write_audit_delete();

create function private.check_visit_slot(p_date date, p_start time, p_end time)
returns void
language plpgsql stable set search_path = ''
as $$
begin
  if p_date is null or p_start is null or p_end is null then
    raise exception 'date, start and end are required' using errcode = '22023';
  end if;
  if p_end <= p_start then
    raise exception 'end must be after start' using errcode = '22023';
  end if;
  if p_date < (now() at time zone 'Europe/Zurich')::date - 1
     or p_date > (now() at time zone 'Europe/Zurich')::date + 366 then
    raise exception 'date out of planning range' using errcode = '22023';
  end if;
end;
$$;

revoke all on function private.check_visit_slot(date, time, time) from public, anon;
grant execute on function private.check_visit_slot(date, time, time) to authenticated;

-- Commands -------------------------------------------------------------------------------
-- SECURITY DEFINER: app users have no INSERT/DELETE on care_visits. Explicit
-- checks on the caller's auth.uid(). Return 'ok' | 'duplicate' | 'rejected'.

create function public.plan_visit(
  p_case_id uuid, p_visit_date date, p_time_start time, p_time_end time,
  p_services text[], p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  c        public.cases%rowtype;
  services text[];
begin
  if (select auth.uid()) is null then
    return 'rejected';
  end if;
  perform private.check_visit_slot(p_visit_date, p_time_start, p_time_end);
  select coalesce(array_agg(btrim(s)) filter (where btrim(s) <> ''), '{}')
    into services from unnest(coalesce(p_services, '{}')) as s;
  if cardinality(services) > 20 then
    raise exception 'at most 20 services' using errcode = '22023';
  end if;

  if private.begin_command('plan_visit', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;

  select * into c from public.cases where id = p_case_id;
  if not found
     or c.assigned_team_id is null
     or not private.is_org_member(c.organization_id)
     or not private.is_team_member(c.assigned_team_id) then
    return private.end_command('rejected');
  end if;

  insert into public.care_visits
    (organization_id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status)
  values
    (c.organization_id, c.id, c.assigned_team_id, p_visit_date, p_time_start, p_time_end, services, false, 'planned');

  return private.end_command('ok');
end;
$$;

create function public.reschedule_visit(
  p_visit_id uuid, p_visit_date date, p_time_start time, p_time_end time, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v public.care_visits%rowtype;
begin
  if (select auth.uid()) is null then
    return 'rejected';
  end if;
  perform private.check_visit_slot(p_visit_date, p_time_start, p_time_end);
  if private.begin_command('reschedule_visit', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;

  select * into v from public.care_visits where id = p_visit_id for update;
  if not found
     or v.status <> 'planned'
     or not private.is_org_member(v.organization_id)
     or not private.is_team_member(v.team_id) then
    return private.end_command('rejected');
  end if;

  update public.care_visits
    set visit_date = p_visit_date, time_start = p_time_start, time_end = p_time_end
    where id = v.id;
  return private.end_command('ok');
end;
$$;

create function public.remove_planned_visit(p_visit_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v public.care_visits%rowtype;
begin
  if (select auth.uid()) is null then
    return 'rejected';
  end if;
  if private.begin_command('remove_planned_visit', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;

  select * into v from public.care_visits where id = p_visit_id for update;
  if not found
     or v.status <> 'planned'
     or not private.is_org_member(v.organization_id)
     or not private.is_team_member(v.team_id)
     -- a plan that already has documentation or events is not "just a plan"
     or exists (select 1 from public.visit_events e where e.visit_id = v.id)
     or exists (select 1 from public.visit_observations o where o.visit_id = v.id)
     or exists (select 1 from public.care_notes n where n.visit_id = v.id)
     or exists (select 1 from public.quality_events q where q.visit_id = v.id) then
    return private.end_command('rejected');
  end if;

  delete from public.care_visits where id = v.id;
  return private.end_command('ok');
end;
$$;

revoke all on function
  public.plan_visit(uuid, date, time, time, text[], uuid),
  public.reschedule_visit(uuid, date, time, time, uuid),
  public.remove_planned_visit(uuid, uuid)
from public, anon;
grant execute on function
  public.plan_visit(uuid, date, time, time, text[], uuid),
  public.reschedule_visit(uuid, date, time, time, uuid),
  public.remove_planned_visit(uuid, uuid)
to authenticated;

-- Read model: the caller's team cases with their planned visits -----------------------------
-- SECURITY INVOKER: organisation RLS applies; narrowed to the caller's teams.
-- Client context = what the team needs to plan (name, region, needs); no health fields.
create function public.team_cases()
returns table (
  case_id       uuid,
  client_name   text,
  region        text,
  urgency       text,
  care_needs    text[],
  team_id       uuid,
  team_name     text,
  upcoming      jsonb      -- [{"visit_id", "date", "start", "end", "status"}], from yesterday on, max 20
)
language sql stable security invoker set search_path = ''
as $$
  select c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), c.region, c.urgency, c.care_needs,
         t.id, t.name,
         coalesce((
           select jsonb_agg(jsonb_build_object('visit_id', x.id, 'date', x.visit_date, 'start', x.time_start,
                                               'end', x.time_end, 'status', x.status)
                            order by x.visit_date, x.time_start)
           from (select v.* from public.care_visits v
                 where v.case_id = c.id and v.team_id = t.id
                   and v.visit_date >= (now() at time zone 'Europe/Zurich')::date - 1
                 order by v.visit_date, v.time_start limit 20) x
         ), '[]'::jsonb)
  from public.cases c
  join public.teams t on t.id = c.assigned_team_id
  join public.team_memberships tm on tm.team_id = t.id and tm.user_id = (select auth.uid())
  where c.status = 'laufend'
  order by c.last_name nulls last, c.id;
$$;

revoke all on function public.team_cases() from public, anon;
grant execute on function public.team_cases() to authenticated;
