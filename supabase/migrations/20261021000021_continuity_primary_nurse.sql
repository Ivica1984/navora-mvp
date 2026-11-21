-- =============================================================================
-- J6 — Continuity of care: primary nurse (brief docs/agents/briefs/J6.md, queue rank 9)
-- =============================================================================
-- Design (ADR-037):
-- * Per CASE: one primary nurse and an optional deputy, both members of the assigned team.
--   This complements J3's per-VISIT responsible member (D-6: team plus responsible member);
--   it does not replace it.
-- * Set by a member of the assigned team. The first assignment needs no reason; changing or
--   removing an existing primary or deputy needs one (F0 rule), logged in change_log.
-- * An active case without a primary nurse is shown to the team (flag in team_cases).
-- * Planning: a visit whose responsible member is neither primary nor deputy gets the flag
--   'not_primary'. It never blocks planning (brief).
-- * Monthly measure per CLIENT: distinct performing nurses and the primary nurse's share of
--   visits. Visible to the team (own cases) and coordination roles. Never per nurse, never a
--   ranking: no per-person counts are returned.
-- =============================================================================

alter table public.cases
  add column primary_nurse_id uuid,
  add column deputy_nurse_id  uuid,
  add constraint cases_deputy_differs check (deputy_nurse_id is null or deputy_nurse_id <> primary_nurse_id);
grant select (primary_nurse_id, deputy_nurse_id) on public.cases to authenticated;

-- Command ------------------------------------------------------------------------------------------------
-- Return: 'ok' | 'duplicate' | 'unchanged' | 'rejected' | 'not_in_team'
create function public.set_primary_nurse(
  p_case_id uuid, p_primary uuid, p_deputy uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  c    public.cases%rowtype;
  why  text := nullif(btrim(p_reason), '');
  diff jsonb := '{}'::jsonb;
begin
  if uid is null then return 'rejected'; end if;
  if p_primary is null then
    raise exception 'a primary nurse is required' using errcode = '22023';
  end if;
  if p_deputy is not null and p_deputy = p_primary then
    raise exception 'the deputy must differ from the primary nurse' using errcode = '22023';
  end if;
  if why is not null and char_length(why) not between 3 and 300 then
    raise exception 'reason needs 3–300 characters' using errcode = '22023';
  end if;
  if private.begin_command('set_primary_nurse', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into c from public.cases where id = p_case_id for update;
  if not found or c.assigned_team_id is null or not private.is_org_member(c.organization_id)
     or not private.is_team_member(c.assigned_team_id) then
    return private.end_command('rejected');
  end if;
  if not exists (select 1 from public.team_memberships m where m.team_id = c.assigned_team_id and m.user_id = p_primary)
     or (p_deputy is not null and not exists (select 1 from public.team_memberships m
                                              where m.team_id = c.assigned_team_id and m.user_id = p_deputy)) then
    return private.end_command('not_in_team');
  end if;
  if c.primary_nurse_id is not distinct from p_primary and c.deputy_nurse_id is not distinct from p_deputy then
    return private.end_command('unchanged');
  end if;

  if c.primary_nurse_id is not null and c.primary_nurse_id <> p_primary then
    diff := diff || jsonb_build_object('primary_nurse_id', jsonb_build_object('old', c.primary_nurse_id, 'new', p_primary));
  end if;
  if c.deputy_nurse_id is not null and c.deputy_nurse_id is distinct from p_deputy then
    diff := diff || jsonb_build_object('deputy_nurse_id', jsonb_build_object('old', c.deputy_nurse_id, 'new', p_deputy));
  end if;
  if diff <> '{}'::jsonb and why is null then
    raise exception 'changing the primary nurse or deputy needs a reason' using errcode = '22023';
  end if;

  update public.cases set primary_nurse_id = p_primary, deputy_nurse_id = p_deputy where id = c.id;
  if diff <> '{}'::jsonb then
    insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
    values (c.organization_id, 'cases', c.id::text, 'set_primary_nurse', diff, why, uid, p_idempotency_key);
  end if;
  return private.end_command('ok');
end;
$$;
revoke all on function public.set_primary_nurse(uuid, uuid, uuid, text, uuid) from public, anon;
grant execute on function public.set_primary_nurse(uuid, uuid, uuid, text, uuid) to authenticated;

-- Audit the assignment on cases (who, when, what) next to the reason in change_log.
create trigger audit_cases_primary_nurse
  after update of primary_nurse_id, deputy_nurse_id on public.cases
  for each row execute function private.write_audit_event('primary_nurse_id', 'deputy_nurse_id');

-- Planning flag (non-blocking) ------------------------------------------------------------------------------
create or replace function private.visit_flags(p_case_id uuid, p_date date, p_minutes_b integer, p_responsible uuid,
                                               p_status text, p_time_start time)
returns text[]
language sql stable security definer set search_path = ''
as $$
  select array_remove(array[
    case when coalesce(p_minutes_b, 0) > 0 and c.medical_order_valid_until is not null
              and p_date > c.medical_order_valid_until then 'order_expired' end,
    case when p_date > (select min(i.review_date) from public.care_plan_items i where i.case_id = c.id and i.active)
         then 'reassessment_due' end,
    case when p_status = 'planned' and p_responsible is null
              and (p_date + coalesce(p_time_start, '00:00'::time)) at time zone 'Europe/Zurich'
                  between now() and now() + interval '24 hours'
         then 'uncovered' end,
    -- J6: responsible member is neither primary nor deputy (flag only)
    case when p_responsible is not null and c.primary_nurse_id is not null
              and p_responsible <> c.primary_nurse_id and p_responsible is distinct from c.deputy_nurse_id
         then 'not_primary' end
  ], null)
  from public.cases c where c.id = p_case_id;
$$;

-- Monthly continuity per client (no per-nurse figures) --------------------------------------------------------
create function public.continuity_by_case(p_month date)
returns table (
  case_id           uuid,
  client_label      text,
  team_name         text,
  primary_set       boolean,
  visits            integer,
  distinct_nurses   integer,
  primary_share_pct integer
)
language sql stable security definer set search_path = ''
as $$
  with bounds as (
    select date_trunc('month', p_month)::date as m_from, (date_trunc('month', p_month) + interval '1 month')::date as m_to
  ), done as (
    select v.case_id, v.team_id, private.visit_performer(v.id) as performer
    from public.care_visits v, bounds b
    where v.status = 'completed' and v.visit_date >= b.m_from and v.visit_date < b.m_to
  )
  select c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), t.name,
         c.primary_nurse_id is not null,
         count(d.case_id)::int,
         count(distinct d.performer)::int,
         case when count(d.performer) = 0 or c.primary_nurse_id is null then null
              else round(100.0 * count(*) filter (where d.performer = c.primary_nurse_id) / count(d.performer))::int end
  from public.cases c
  join public.teams t on t.id = c.assigned_team_id
  left join done d on d.case_id = c.id
  where p_month is not null and c.status = 'laufend'
    and private.is_org_member(c.organization_id)
    and (private.is_team_member(c.assigned_team_id) or private.is_coordinator(c.organization_id))
  group by c.id, c.first_name, c.last_name, t.name, c.primary_nurse_id
  order by t.name, c.last_name nulls last, c.id;
$$;
revoke all on function public.continuity_by_case(date) from public, anon;
grant execute on function public.continuity_by_case(date) to authenticated;

-- team_cases: primary and deputy for the team view ----------------------------------------------------------------
drop function public.team_cases();
create function public.team_cases()
returns table (
  case_id                  uuid,
  client_name              text,
  region                   text,
  urgency                  text,
  care_needs               text[],
  team_id                  uuid,
  team_name                text,
  needs_assessment_done    boolean,
  medical_order_status     text,
  medical_order_valid_until date,
  open_tasks               text[],
  care_plan                jsonb,
  members                  jsonb,
  upcoming                 jsonb,
  primary_nurse_id         uuid,
  deputy_nurse_id          uuid
)
language sql stable security definer set search_path = ''
as $$
  select c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), c.region, c.urgency, c.care_needs,
         t.id, t.name,
         c.needs_assessment_done_at is not null,
         c.medical_order_status, c.medical_order_valid_until,
         coalesce((select array_agg(k.kind order by k.kind) from public.case_tasks k where k.case_id = c.id and k.status = 'open'), '{}'),
         coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'service', i.service, 'category', i.category,
                                                       'minutes', i.planned_minutes, 'frequency', i.frequency,
                                                       'review_date', i.review_date, 'goal', i.goal) order by i.category, i.service)
                   from public.care_plan_items i where i.case_id = c.id and i.active), '[]'::jsonb),
         coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'qualification', m.qualification,
                                                       'me', m.user_id = (select auth.uid())) order by m.user_id)
                   from public.team_memberships m where m.team_id = t.id), '[]'::jsonb),
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'visit_id', x.id, 'date', x.visit_date, 'start', x.time_start, 'end', x.time_end, 'status', x.status,
                    'a', x.planned_minutes_a, 'b', x.planned_minutes_b, 'c', x.planned_minutes_c,
                    'needs_assessment', x.is_needs_assessment,
                    'responsible_me', x.responsible_user_id = (select auth.uid()),
                    'responsible_set', x.responsible_user_id is not null,
                    'flags', to_jsonb(private.visit_flags(c.id, x.visit_date, x.planned_minutes_b, x.responsible_user_id, x.status, x.time_start)),
                    'last_change', (select jsonb_build_object('change', pc.change, 'reason', pc.reason, 'at', pc.changed_at,
                                                              'own', pc.actor_id = (select auth.uid()))
                                    from public.visit_plan_changes pc where pc.visit_id = x.id
                                    order by pc.changed_at desc, pc.id desc limit 1))
                  order by x.visit_date, x.time_start)
           from (select v.* from public.care_visits v
                 where v.case_id = c.id and v.team_id = t.id
                   and v.visit_date >= (now() at time zone 'Europe/Zurich')::date - 1
                 order by v.visit_date, v.time_start limit 20) x
         ), '[]'::jsonb),
         c.primary_nurse_id, c.deputy_nurse_id
  from public.cases c
  join public.teams t on t.id = c.assigned_team_id
  join public.team_memberships tm on tm.team_id = t.id and tm.user_id = (select auth.uid())
  where c.status = 'laufend' and private.is_org_member(c.organization_id)
  order by c.last_name nulls last, c.id;
$$;
revoke all on function public.team_cases() from public, anon;
grant execute on function public.team_cases() to authenticated;
