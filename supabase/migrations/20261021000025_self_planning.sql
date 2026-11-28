-- PLAN2: self-planning — visits follow the care plan (PO brief docs/agents/briefs/PLAN2.md, ADR-042).
--
-- * Structured frequency per care-plan item (planning field, not clinical): times per day (1) or per
--   week (1–7), optional ISO weekdays (1 = Monday), and a time window. The free text `frequency` stays as
--   a note. Items without frequency AND window are not planned automatically; the team sees them.
-- * A rolling four-week series (tomorrow … +28 days) of planned visits per active case. Items due on the
--   same day with the same window form one visit (minutes summed per KLV category).
-- * Responsibility: the primary nurse when she may do the work (category B → registered nurse), else the
--   deputy under the same rule, else nobody (the existing "uncovered" flag).
-- * J3 rules unchanged: no generation before the needs assessment; B only with a present order and never
--   after its validity end (the B part is left out; the case shows why); an A/C visit without an order
--   opens the inform-GP task; B work is never assigned to a care assistant.
-- * The team stays in charge: a generated visit the team moved, started, cancelled or that C1 suspended is
--   "touched" and never overwritten; a slot the team removed is remembered and not recreated. Only future
--   untouched generated visits are regenerated or dropped. Every generated, regenerated or dropped visit
--   is in visit_plan_changes with the reason "care plan".
-- * C1: nothing is generated for a paused, closed or not-ready reopened case; switching the series off
--   (auto planning, with a reason) drops the future untouched generated visits.
-- * Reliability (answer to the brief's question): generation runs on every care-plan, schedule or relevant
--   case change (triggers), on the team action, on every team page load for cases not yet generated today
--   (`refresh_team_plans`, the OPS1 sync pattern), and daily through pg_cron when the extension exists.
--   The system actor for unattended runs is the nil UUID.

-- 1. Structure ---------------------------------------------------------------------------------------------------
alter table public.care_plan_items
  add column freq_times    smallint,
  add column freq_period   text,
  add column freq_weekdays smallint[],
  add column window_start  time,
  add column window_end    time,
  add constraint care_plan_items_schedule check (
    (freq_times is null and freq_period is null and freq_weekdays is null and window_start is null and window_end is null)
    or (freq_period in ('day', 'week') and window_start is not null and window_end > window_start
        and ((freq_period = 'day' and freq_times = 1 and freq_weekdays is null)
             or (freq_period = 'week' and freq_times between 1 and 7
                 and (freq_weekdays is null
                      or (cardinality(freq_weekdays) = freq_times and freq_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]))))));

alter table public.cases
  add column auto_planning      boolean not null default true,
  add column plan_generated_on  date;

alter table public.care_visits
  add column plan_generated  boolean not null default false,
  add column plan_slot_date  date,
  add column plan_slot_start time,
  add constraint care_visits_plan_slot check (not plan_generated or (plan_slot_date is not null and plan_slot_start is not null));
create unique index care_visits_plan_slot_unique on public.care_visits (case_id, plan_slot_date, plan_slot_start) where plan_generated;

-- Slots the team removed: never recreated.
create table public.plan_slot_skips (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  case_id         uuid not null,
  slot_date       date not null,
  slot_start      time not null,
  actor_id        uuid,
  created_at      timestamptz not null default now(),
  unique (case_id, slot_date, slot_start)
);
alter table public.plan_slot_skips enable row level security;
revoke all on public.plan_slot_skips from anon, authenticated;

-- The plan change log knows regeneration.
alter table public.visit_plan_changes drop constraint visit_plan_changes_change_check;
alter table public.visit_plan_changes add constraint visit_plan_changes_change_check
  check (change in ('planned', 'moved', 'removed', 'regenerated'));

-- 2. Helpers -----------------------------------------------------------------------------------------------------
create function private.plan_system_actor() returns uuid language sql immutable set search_path = ''
as $$ select '00000000-0000-0000-0000-000000000000'::uuid $$;

-- ISO weekdays an item is due on.
create function private.plan_weekdays(p_period text, p_times smallint, p_weekdays smallint[])
returns smallint[] language sql immutable set search_path = ''
as $$
  select case
    when p_period = 'day' then array[1,2,3,4,5,6,7]::smallint[]
    when p_weekdays is not null then p_weekdays
    -- Even spread when the team named no days (planning default, not a clinical rule).
    else (('{{1,0,0,0,0,0,0},{1,4,0,0,0,0,0},{1,3,5,0,0,0,0},{1,2,4,5,0,0,0},'
           '{1,2,3,4,5,0,0},{1,2,3,4,5,6,0},{1,2,3,4,5,6,7}}')::smallint[])[p_times:p_times][1:p_times] end
$$;

-- A team removing a generated visit leaves a skip, so the slot is not recreated.
create function private.remember_removed_slot()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if old.plan_generated and coalesce(current_setting('navora.plan_regen', true), '') <> 'on' then
    insert into public.plan_slot_skips (organization_id, case_id, slot_date, slot_start, actor_id)
    values (old.organization_id, old.case_id, old.plan_slot_date, old.plan_slot_start, (select auth.uid()))
    on conflict (case_id, slot_date, slot_start) do nothing;
  end if;
  return old;
end;
$$;
create trigger care_visits_remember_removed_slot after delete on public.care_visits
  for each row execute function private.remember_removed_slot();

-- A generated visit the team (or C1) changed is never overwritten.
create function private.plan_visit_untouched(v public.care_visits)
returns boolean language sql stable security definer set search_path = ''
as $$
  select v.plan_generated and v.status = 'planned' and v.suspended_at is null
     and v.visit_date = v.plan_slot_date and v.time_start = v.plan_slot_start
     and not exists (select 1 from public.visit_plan_changes pc where pc.visit_id = v.id and pc.change = 'moved')
$$;

-- 3. Generation --------------------------------------------------------------------------------------------------
-- Returns {"created","regenerated","dropped","kept","reasons":[…]}; reasons explain what was not planned.
create function private.generate_case_plan(p_case_id uuid, p_actor uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  c          public.cases%rowtype;
  today      date := (now() at time zone 'Europe/Zurich')::date;
  d          date;
  slot       record;
  v          public.care_visits%rowtype;
  rn_needed  boolean;
  who        uuid;
  created    integer := 0;
  regen      integer := 0;
  dropped    integer := 0;
  kept       integer := 0;
  reasons    text[] := '{}';
  wanted     text[] := '{}';
  no_order_ac boolean := false;
  vid        uuid;
begin
  select * into c from public.cases where id = p_case_id for update;
  if not found or c.assigned_team_id is null then
    return jsonb_build_object('result', 'skipped', 'reasons', array['no_team']);
  end if;
  perform set_config('navora.plan_regen', 'on', true);

  -- Series switched off: drop future untouched generated visits.
  if not c.auto_planning then
    for v in select * from public.care_visits x where x.case_id = c.id and x.plan_generated and x.visit_date > today loop
      if private.plan_visit_untouched(v) then
        insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, reason, actor_id)
        values (v.organization_id, v.id, v.case_id, v.team_id, 'removed', private.visit_slot_json(v), 'care plan: series switched off', p_actor);
        delete from public.care_visits where id = v.id;
        dropped := dropped + 1;
      end if;
    end loop;
    perform set_config('navora.plan_regen', '', true);
    update public.cases set plan_generated_on = today where id = c.id;
    return jsonb_build_object('result', 'ok', 'created', 0, 'regenerated', 0, 'dropped', dropped, 'kept', 0, 'reasons', array['series_off']);
  end if;

  if c.lifecycle <> 'active' then
    perform set_config('navora.plan_regen', '', true);
    return jsonb_build_object('result', 'skipped', 'reasons', array['case_' || c.lifecycle]);
  end if;
  if c.reopened_at is not null and jsonb_array_length(private.case_readiness(c.id)) > 0 then
    perform set_config('navora.plan_regen', '', true);
    return jsonb_build_object('result', 'skipped', 'reasons', array['reopened_not_ready']);
  end if;
  if c.needs_assessment_done_at is null then
    perform set_config('navora.plan_regen', '', true);
    return jsonb_build_object('result', 'skipped', 'reasons', array['assessment_first']);
  end if;
  if exists (select 1 from public.care_plan_items i where i.case_id = c.id and i.active and i.freq_period is null) then
    reasons := array_append(reasons, 'items_without_schedule');
  end if;

  for d in select g::date from generate_series(today + 1, today + 28, interval '1 day') g loop
    for slot in
      select i.window_start, max(i.window_end) as window_end,
             coalesce(sum(i.planned_minutes) filter (where i.category = 'A'), 0)::int as a,
             coalesce(sum(i.planned_minutes) filter (where i.category = 'B'
                        and c.medical_order_status = 'present'
                        and (c.medical_order_valid_until is null or d <= c.medical_order_valid_until)), 0)::int as b,
             coalesce(sum(i.planned_minutes) filter (where i.category = 'C'), 0)::int as cc,
             bool_or(i.category = 'B' and not (c.medical_order_status = 'present'
                        and (c.medical_order_valid_until is null or d <= c.medical_order_valid_until))) as b_left_out,
             array_agg(distinct i.service order by i.service) filter (where i.category <> 'B'
                        or (c.medical_order_status = 'present' and (c.medical_order_valid_until is null or d <= c.medical_order_valid_until))) as services
      from public.care_plan_items i
      where i.case_id = c.id and i.active and i.freq_period is not null
        and extract(isodow from d)::smallint = any (private.plan_weekdays(i.freq_period, i.freq_times, i.freq_weekdays))
      group by i.window_start
      order by i.window_start
    loop
      if slot.b_left_out and not ('order_missing_or_expired' = any (reasons)) then
        reasons := array_append(reasons, 'order_missing_or_expired');
      end if;
      continue when slot.a + slot.b + slot.cc = 0;
      if slot.a + slot.b + slot.cc > extract(epoch from (slot.window_end - slot.window_start)) / 60 then
        if not ('minutes_exceed_window' = any (reasons)) then reasons := array_append(reasons, 'minutes_exceed_window'); end if;
        continue;
      end if;
      wanted := array_append(wanted, d::text || ' ' || slot.window_start::text);
      continue when exists (select 1 from public.plan_slot_skips s
                            where s.case_id = c.id and s.slot_date = d and s.slot_start = slot.window_start);

      rn_needed := slot.b > 0;
      who := case
        when c.primary_nurse_id is not null
             and exists (select 1 from public.team_memberships m where m.team_id = c.assigned_team_id and m.user_id = c.primary_nurse_id)
             and (not rn_needed or private.is_registered_nurse(c.assigned_team_id, c.primary_nurse_id)) then c.primary_nurse_id
        when c.deputy_nurse_id is not null
             and exists (select 1 from public.team_memberships m where m.team_id = c.assigned_team_id and m.user_id = c.deputy_nurse_id)
             and (not rn_needed or private.is_registered_nurse(c.assigned_team_id, c.deputy_nurse_id)) then c.deputy_nurse_id
        end;
      if slot.b = 0 and c.medical_order_status is distinct from 'present' then
        no_order_ac := true;
      end if;

      select * into v from public.care_visits x
        where x.case_id = c.id and x.plan_generated and x.plan_slot_date = d and x.plan_slot_start = slot.window_start;
      if found then
        if not private.plan_visit_untouched(v) then
          kept := kept + 1;
        elsif (v.time_end, v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c, v.responsible_user_id, v.services_provided)
              is distinct from (slot.window_end, slot.a, slot.b, slot.cc, who, coalesce(slot.services, '{}')) then
          update public.care_visits
            set time_end = slot.window_end, planned_minutes_a = slot.a, planned_minutes_b = slot.b, planned_minutes_c = slot.cc,
                responsible_user_id = who, services_provided = coalesce(slot.services, '{}')
            where id = v.id;
          insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
          select x.organization_id, x.id, x.case_id, x.team_id, 'regenerated', private.visit_slot_json(v), private.visit_slot_json(x), 'care plan', p_actor
          from public.care_visits x where x.id = v.id;
          regen := regen + 1;
        end if;
      else
        insert into public.care_visits
          (organization_id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status,
           planned_minutes_a, planned_minutes_b, planned_minutes_c, is_needs_assessment, responsible_user_id,
           plan_generated, plan_slot_date, plan_slot_start)
        values
          (c.organization_id, c.id, c.assigned_team_id, d, slot.window_start, slot.window_end, coalesce(slot.services, '{}'), false, 'planned',
           slot.a, slot.b, slot.cc, false, who, true, d, slot.window_start)
        returning id into vid;
        insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, after, reason, actor_id)
        select x.organization_id, x.id, x.case_id, x.team_id, 'planned', private.visit_slot_json(x), 'care plan', p_actor
        from public.care_visits x where x.id = vid;
        created := created + 1;
      end if;
    end loop;
  end loop;

  -- Future untouched generated visits that the care plan no longer asks for are dropped.
  for v in select * from public.care_visits x where x.case_id = c.id and x.plan_generated and x.visit_date > today loop
    if not ((v.plan_slot_date::text || ' ' || v.plan_slot_start::text) = any (wanted)) and private.plan_visit_untouched(v) then
      insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, reason, actor_id)
      values (v.organization_id, v.id, v.case_id, v.team_id, 'removed', private.visit_slot_json(v), 'care plan', p_actor);
      delete from public.care_visits where id = v.id;
      dropped := dropped + 1;
    end if;
  end loop;

  if no_order_ac then
    insert into public.case_tasks (organization_id, case_id, kind)
    values (c.organization_id, c.id, 'inform_gp')
    on conflict (case_id, kind) where status = 'open' do nothing;
  end if;

  perform set_config('navora.plan_regen', '', true);
  update public.cases set plan_generated_on = today where id = c.id;
  return jsonb_build_object('result', 'ok', 'created', created, 'regenerated', regen, 'dropped', dropped, 'kept', kept, 'reasons', reasons);
end;
$$;
revoke all on function private.generate_case_plan(uuid, uuid) from public, anon, authenticated;

-- Regenerate on every care-plan change and on case changes that matter for the plan.
create function private.plan_after_item_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.generate_case_plan(new.case_id, coalesce((select auth.uid()), private.plan_system_actor()));
  return null;
end;
$$;
create trigger care_plan_items_regenerate after insert or update on public.care_plan_items
  for each row execute function private.plan_after_item_change();

create function private.plan_after_case_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if exists (select 1 from public.care_plan_items i where i.case_id = new.id and i.freq_period is not null)
     or exists (select 1 from public.care_visits v where v.case_id = new.id and v.plan_generated) then
    perform private.generate_case_plan(new.id, coalesce((select auth.uid()), private.plan_system_actor()));
  end if;
  return null;
end;
$$;
create trigger cases_regenerate_plan
  after update of primary_nurse_id, deputy_nurse_id, lifecycle, reopened_at, auto_planning, assigned_team_id,
                  medical_order_status, medical_order_valid_until, needs_assessment_done_at
  on public.cases
  for each row
  when ((old.primary_nurse_id, old.deputy_nurse_id, old.lifecycle, old.reopened_at, old.auto_planning, old.assigned_team_id,
         old.medical_order_status, old.medical_order_valid_until, old.needs_assessment_done_at)
        is distinct from
        (new.primary_nurse_id, new.deputy_nurse_id, new.lifecycle, new.reopened_at, new.auto_planning, new.assigned_team_id,
         new.medical_order_status, new.medical_order_valid_until, new.needs_assessment_done_at))
  execute function private.plan_after_case_change();

-- All active cases with a structured care plan; for the daily job.
create function private.generate_all_plans()
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  n  integer := 0;
  id uuid;
begin
  for id in select c.id from public.cases c
            where c.assigned_team_id is not null and c.lifecycle = 'active'
              and exists (select 1 from public.care_plan_items i where i.case_id = c.id and i.active and i.freq_period is not null)
  loop
    perform private.generate_case_plan(id, private.plan_system_actor());
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function private.generate_all_plans() from public, anon, authenticated;

-- Daily run through pg_cron where the extension can be enabled; otherwise the page-load refresh and the
-- triggers keep the window (a notice records the fallback, nothing fails).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    begin
      create extension if not exists pg_cron;
      -- 02:15 Europe/Zurich in winter (01:15 UTC); the four-week window tolerates the summer-time shift.
      execute $cron$select cron.schedule('navora-plan2-daily', '15 1 * * *', 'select private.generate_all_plans()')$cron$;
    exception when others then
      raise notice 'PLAN2: pg_cron not usable here (%); page-load refresh and triggers keep the window', sqlerrm;
    end;
  else
    raise notice 'PLAN2: pg_cron not available; page-load refresh and triggers keep the window';
  end if;
end;
$$;

-- 4. Commands ------------------------------------------------------------------------------------------------------
-- Structured frequency for one care-plan item; the trigger regenerates the case.
-- Return jsonb {"result": 'ok'|'duplicate'|'rejected', …generation summary}
create function public.set_care_plan_schedule(
  p_item_id uuid, p_times integer, p_period text, p_weekdays integer[], p_window_start time, p_window_end time, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  i   public.care_plan_items%rowtype;
  wd  smallint[];
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_period is null then
    -- Clear the schedule: the item is planned by hand again.
    null;
  elsif p_period not in ('day', 'week') or p_window_start is null or p_window_end is null or p_window_end <= p_window_start
        or (p_period = 'day' and (p_times is distinct from 1 or p_weekdays is not null))
        or (p_period = 'week' and (p_times is null or p_times not between 1 and 7
            or (p_weekdays is not null and (cardinality(p_weekdays) <> p_times
                or not (p_weekdays <@ array[1,2,3,4,5,6,7]) or (select count(distinct x) from unnest(p_weekdays) x) <> p_times)))) then
    raise exception 'frequency: once a day, or 1–7 times a week (optional weekdays 1–7, one per visit), and a time window' using errcode = '22023';
  end if;
  wd := case when p_weekdays is null then null else (select array_agg(x::smallint order by x) from unnest(p_weekdays) x) end;
  if private.begin_command('set_care_plan_schedule', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into i from public.care_plan_items where id = p_item_id for update;
  if not found or not i.active or not private.is_org_member(i.organization_id) or not private.is_team_member(i.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  update public.care_plan_items
    set freq_times = case when p_period is null then null else p_times end, freq_period = p_period, freq_weekdays = wd,
        window_start = case when p_period is null then null else p_window_start end,
        window_end = case when p_period is null then null else p_window_end end
    where id = i.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok') || (select private.plan_summary(i.case_id));
end;
$$;

-- The team's explicit action: plan the next four weeks now.
create function public.plan_from_care_plan(p_case_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  res jsonb;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('plan_from_care_plan', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into c from public.cases where id = p_case_id;
  if not found or c.assigned_team_id is null or not private.is_org_member(c.organization_id) or not private.is_team_member(c.assigned_team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  res := private.generate_case_plan(c.id, uid);
  insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values (c.organization_id, uid, 'authenticated', 'cases', c.id, 'plan_from_care_plan', p_idempotency_key, res);
  perform private.end_command('ok');
  return res || jsonb_build_object('result', case when res ->> 'result' = 'ok' then 'ok' else 'skipped' end);
end;
$$;

-- Switch the series off (with a reason; future untouched generated visits are dropped) or on again.
-- Return: 'ok' | 'unchanged' | 'duplicate' | 'rejected'
create function public.set_auto_planning(p_case_id uuid, p_enabled boolean, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  why text;
begin
  if uid is null then return 'rejected'; end if;
  if p_enabled is null then raise exception 'enabled is required' using errcode = '22023'; end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('set_auto_planning', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into c from public.cases where id = p_case_id for update;
  if not found or c.assigned_team_id is null or not private.is_org_member(c.organization_id) or not private.is_team_member(c.assigned_team_id) then
    return private.end_command('rejected');
  end if;
  if c.auto_planning = p_enabled then
    return private.end_command('unchanged');
  end if;
  update public.cases set auto_planning = p_enabled where id = c.id;   -- the case trigger regenerates or drops
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (c.organization_id, 'cases', c.id::text, 'set_auto_planning',
          jsonb_build_object('auto_planning', jsonb_build_object('old', c.auto_planning, 'new', p_enabled)), why, uid, p_idempotency_key);
  insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values (c.organization_id, uid, 'authenticated', 'cases', c.id, 'set_auto_planning', p_idempotency_key,
          jsonb_build_object('auto_planning', jsonb_build_object('old', c.auto_planning, 'new', p_enabled)));
  return private.end_command('ok');
end;
$$;

-- Called by the team page on load: cases of the caller's teams that were not generated today.
create function public.refresh_team_plans()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  n   integer := 0;
  id  uuid;
  today date := (now() at time zone 'Europe/Zurich')::date;
begin
  if uid is null then return 0; end if;
  for id in select c.id from public.cases c
            join public.team_memberships m on m.team_id = c.assigned_team_id and m.user_id = uid
            where c.lifecycle = 'active' and c.plan_generated_on is distinct from today
              and exists (select 1 from public.care_plan_items i where i.case_id = c.id and i.active and i.freq_period is not null)
  loop
    perform private.generate_case_plan(id, private.plan_system_actor());
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- 5. Read model ------------------------------------------------------------------------------------------------
-- Per case of the caller's teams: series state, what is not planned automatically and why.
create function private.plan_summary(p_case_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'generated_ahead', (select count(*) from public.care_visits v where v.case_id = c.id and v.plan_generated
                          and v.visit_date > (now() at time zone 'Europe/Zurich')::date),
    'unscheduled', coalesce((select jsonb_agg(i.service order by i.service) from public.care_plan_items i
                             where i.case_id = c.id and i.active and i.freq_period is null), '[]'::jsonb))
  from public.cases c where c.id = p_case_id
$$;
revoke all on function private.plan_summary(uuid) from public, anon, authenticated;

create function public.team_plan_status()
returns table (case_id uuid, auto_planning boolean, generated_ahead integer, unscheduled jsonb, blocked_reason text,
               b_until date, generated_on date)
language sql stable security definer set search_path = ''
as $$
  select c.id, c.auto_planning,
         (select count(*)::int from public.care_visits v where v.case_id = c.id and v.plan_generated
            and v.visit_date > (now() at time zone 'Europe/Zurich')::date),
         coalesce((select jsonb_agg(jsonb_build_object('item_id', i.id, 'service', i.service) order by i.service)
                   from public.care_plan_items i where i.case_id = c.id and i.active and i.freq_period is null), '[]'::jsonb),
         case when not c.auto_planning then 'series_off'
              when c.lifecycle <> 'active' then 'case_' || c.lifecycle
              when c.reopened_at is not null and jsonb_array_length(private.case_readiness(c.id)) > 0 then 'reopened_not_ready'
              when c.needs_assessment_done_at is null then 'assessment_first'
              when exists (select 1 from public.care_plan_items i where i.case_id = c.id and i.active and i.category = 'B' and i.freq_period is not null)
                   and c.medical_order_status is distinct from 'present' then 'order_missing'
         end,
         case when c.medical_order_status = 'present' then c.medical_order_valid_until end,
         c.plan_generated_on
  from public.cases c
  where c.assigned_team_id is not null and private.is_org_member(c.organization_id) and private.is_team_member(c.assigned_team_id)
  order by c.id;
$$;

revoke all on function
  public.set_care_plan_schedule(uuid, integer, text, integer[], time, time, uuid),
  public.plan_from_care_plan(uuid, uuid),
  public.set_auto_planning(uuid, boolean, text, uuid),
  public.refresh_team_plans(),
  public.team_plan_status()
from public, anon;
grant execute on function
  public.set_care_plan_schedule(uuid, integer, text, integer[], time, time, uuid),
  public.plan_from_care_plan(uuid, uuid),
  public.set_auto_planning(uuid, boolean, text, uuid),
  public.refresh_team_plans(),
  public.team_plan_status()
to authenticated;

-- 6. Team view: each care-plan item shows its structured frequency (jsonb; same columns) ----------------------
do $$
declare
  def  text := pg_get_functiondef('public.team_cases()'::regprocedure);
  find text := $f$'review_date', i.review_date, 'goal', i.goal)$f$;
begin
  if position(find in def) = 0 or position($f$'needs_assessment', x.is_needs_assessment,$f$ in def) = 0 then
    raise exception 'PLAN2: team_cases patch did not match';
  end if;
  def := replace(def, $f$'needs_assessment', x.is_needs_assessment,$f$,
                 $r$'needs_assessment', x.is_needs_assessment, 'generated', x.plan_generated,$r$);
  execute replace(def, find,
    $r$'review_date', i.review_date, 'goal', i.goal,
                                                       'freq_times', i.freq_times, 'freq_period', i.freq_period, 'freq_weekdays', i.freq_weekdays,
                                                       'window_start', i.window_start, 'window_end', i.window_end)$r$);
end;
$$;
