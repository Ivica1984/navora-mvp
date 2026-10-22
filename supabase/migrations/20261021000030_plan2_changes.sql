-- PLAN2 changes requested by the PO (review 2026-10-22 14:30). ADR-042 amended.
--
-- * No double planning: generation never creates a visit next to a non-cancelled visit of the case in the same
--   day and time window (hand-planned, moved there or covered); the skipped slot is logged once as
--   "already planned", and an untouched generated double is dropped.
-- * Withdrawn preconditions drop future untouched generated visits, with the reason logged: case closed,
--   reopened and not ready, needs assessment no longer done. A paused case keeps them (C1 suspends them).
-- * The team's plan status counts upcoming visits with B minutes after the order end (J3 flag "order_expired").
-- * AN1: "team planning actions per client per week" from the plan log (hand planning, moves, removals;
--   not the reason "care plan").

alter table public.visit_plan_changes drop constraint visit_plan_changes_change_check;
alter table public.visit_plan_changes add constraint visit_plan_changes_change_check
  check (change in ('planned', 'moved', 'removed', 'regenerated', 'skipped'));

-- Drops the future untouched generated visits of a case, each logged with the reason.
create function private.drop_generated_visits(p_case_id uuid, p_reason text, p_actor uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  v public.care_visits%rowtype;
  n integer := 0;
begin
  perform set_config('navora.plan_regen', 'on', true);
  for v in select * from public.care_visits x where x.case_id = p_case_id and x.plan_generated
             and x.visit_date > (now() at time zone 'Europe/Zurich')::date loop
    if private.plan_visit_untouched(v) then
      insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, reason, actor_id)
      values (v.organization_id, v.id, v.case_id, v.team_id, 'removed', private.visit_slot_json(v), left(p_reason, 300), p_actor);
      delete from public.care_visits where id = v.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function private.drop_generated_visits(uuid, text, uuid) from public, anon, authenticated;

create or replace function private.generate_case_plan(p_case_id uuid, p_actor uuid)
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
  other      public.care_visits%rowtype;
begin
  select * into c from public.cases where id = p_case_id for update;
  if not found or c.assigned_team_id is null then
    return jsonb_build_object('result', 'skipped', 'reasons', array['no_team']);
  end if;
  perform set_config('navora.plan_regen', 'on', true);

  -- Preconditions withdrawn: drop future untouched generated visits, with the reason in the plan log.
  -- (A paused case keeps them: C1 suspended them and resume restores them.)
  if not c.auto_planning then
    dropped := private.drop_generated_visits(c.id, 'care plan: series switched off', p_actor);
    perform set_config('navora.plan_regen', '', true);
    update public.cases set plan_generated_on = today where id = c.id;
    return jsonb_build_object('result', 'ok', 'created', 0, 'regenerated', 0, 'dropped', dropped, 'kept', 0, 'reasons', array['series_off']);
  end if;
  if c.lifecycle = 'paused' then
    perform set_config('navora.plan_regen', '', true);
    return jsonb_build_object('result', 'skipped', 'reasons', array['case_paused']);
  end if;
  if c.lifecycle <> 'active' then
    dropped := private.drop_generated_visits(c.id, 'care plan: case ' || c.lifecycle, p_actor);
    perform set_config('navora.plan_regen', '', true);
    return jsonb_build_object('result', 'skipped', 'dropped', dropped, 'reasons', array['case_' || c.lifecycle]);
  end if;
  if c.reopened_at is not null and jsonb_array_length(private.case_readiness(c.id)) > 0 then
    dropped := private.drop_generated_visits(c.id, 'care plan: reopened case not ready', p_actor);
    perform set_config('navora.plan_regen', '', true);
    return jsonb_build_object('result', 'skipped', 'dropped', dropped, 'reasons', array['reopened_not_ready']);
  end if;
  if c.needs_assessment_done_at is null then
    dropped := private.drop_generated_visits(c.id, 'care plan: needs assessment first', p_actor);
    perform set_config('navora.plan_regen', '', true);
    return jsonb_build_object('result', 'skipped', 'dropped', dropped, 'reasons', array['assessment_first']);
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

      -- Never next to a visit the case already has in this window (planned by hand, moved there, or covered):
      -- the slot is skipped and logged once as "already planned".
      select x.* into other from public.care_visits x
        where x.case_id = c.id and x.visit_date = d and x.status <> 'cancelled'
          and not (x.plan_generated and x.plan_slot_date = d and x.plan_slot_start = slot.window_start)
          and x.time_start < slot.window_end
          and coalesce(x.time_end, x.time_start + interval '1 minute') > slot.window_start
        order by x.time_start limit 1;
      if found then
        if not ('already_planned' = any (reasons)) then reasons := array_append(reasons, 'already_planned'); end if;
        if not exists (select 1 from public.visit_plan_changes pc where pc.visit_id = other.id and pc.change = 'skipped'
                         and pc.after ->> 'slot' = d::text || ' ' || slot.window_start::text) then
          insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, after, reason, actor_id)
          values (other.organization_id, other.id, other.case_id, other.team_id, 'skipped',
                  jsonb_build_object('slot', d::text || ' ' || slot.window_start::text), 'care plan: already planned', p_actor);
        end if;
        -- An untouched generated visit for this slot would be a double: drop it.
        select * into v from public.care_visits x
          where x.case_id = c.id and x.plan_generated and x.plan_slot_date = d and x.plan_slot_start = slot.window_start;
        if found and private.plan_visit_untouched(v) then
          insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, reason, actor_id)
          values (v.organization_id, v.id, v.case_id, v.team_id, 'removed', private.visit_slot_json(v), 'care plan: already planned', p_actor);
          delete from public.care_visits where id = v.id;
          dropped := dropped + 1;
        end if;
        wanted := array_remove(wanted, d::text || ' ' || slot.window_start::text);
        continue;
      end if;

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

-- Plan status: also the upcoming visits that carry the J3 order flag (B minutes after the order end).
drop function public.team_plan_status();
create function public.team_plan_status()
returns table (case_id uuid, auto_planning boolean, generated_ahead integer, unscheduled jsonb, blocked_reason text,
               b_until date, generated_on date, order_flagged integer)
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
         c.plan_generated_on,
         (select count(*)::int from public.care_visits v
            where v.case_id = c.id and v.status = 'planned' and v.visit_date >= (now() at time zone 'Europe/Zurich')::date
              and 'order_expired' = any (private.visit_flags(c.id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start)))
  from public.cases c
  where c.assigned_team_id is not null and private.is_org_member(c.organization_id) and private.is_team_member(c.assigned_team_id)
  order by c.id;
$$;
revoke all on function public.team_plan_status() from public, anon;
grant execute on function public.team_plan_status() to authenticated;

-- AN1: team planning actions per client per week (hand planning work; generated changes excluded).
do $$
declare
  def  text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  find text := $f$    union all select * from offers union all select * from p1 union all select * from cover
  )$f$;
begin
  if position(find in def) = 0 then raise exception 'PLAN2 changes: pilot_kpis patch did not match'; end if;
  def := replace(def, find, $r$    union all select * from offers union all select * from p1 union all select * from cover
    union all select * from planning_actions
  )$r$);
  def := replace(def, $f$  all_rows as ($f$, $r$  planning_actions as (
    select pc.organization_id, pc.team_id, 'planning_actions_per_client_week' as kpi,
           round(count(*)::numeric / nullif(count(distinct pc.case_id), 0)
                 / ((select (m1 - m0) from params)::numeric / 7), 2) as value,
           count(distinct pc.case_id)::int as base
    from public.visit_plan_changes pc, params p
    where pc.changed_at >= p.m0 and pc.changed_at < p.m1 and pc.team_id in (select id from my_teams)
      and pc.change in ('planned', 'moved', 'removed') and pc.actor_id <> private.plan_system_actor()
      and coalesce(pc.reason, '') not like 'care plan%' and coalesce(pc.reason, '') not like 'cover%'
    group by grouping sets ((pc.organization_id, pc.team_id), (pc.organization_id))
  ),
  all_rows as ($r$);
  execute def;
end;
$$;
