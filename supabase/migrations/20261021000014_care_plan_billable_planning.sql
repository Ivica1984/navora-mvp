-- =============================================================================
-- J3 (PO changes, brief docs/agents/briefs/J3.md): visit planning with billable basis
-- =============================================================================
-- * Member qualification as data (also F0): registered_nurse | care_assistant.
-- * Care-plan summary per case: service, KLV category A/B/C (KLV Art. 7),
--   planned minutes per visit, frequency, review date. Categories are chosen by
--   the team; NO automatic service→category mapping (clinical sign-off D-15).
-- * Every planned visit stores planned minutes PER CATEGORY (A, B, C).
-- * The first visit of a case is the needs-assessment visit (category A only);
--   until it is completed it is the only visit that can be planned (KLV Art. 8a).
-- * Category B requires a medical order with status `present` on the case;
--   a B visit after the order's validity end is allowed but flagged.
-- * Needs assessment and category B: if a responsible member is set, she must
--   be a registered nurse.
-- * A/C visits without an order create an open "inform GP" task on the case.
-- * Visits after the earliest active care-plan review date are flagged.
-- * Every plan / move / removal is logged with who and — for moves and
--   removals — a required reason; the original values stay in the log.
-- * A planned visit in the next 24 h without a responsible member is
--   "uncovered": flagged for the team and listed for Operations.
-- * Starting a category B or needs-assessment visit requires the person who
--   starts it to be a registered nurse of the team (any write path; SQLSTATE NV001).
-- * Care goals (optional, per care-plan service, written by the team) appear on
--   the nurse's /field card.
-- Not decided here: assignment model (D-6), countersignature (D-10), category
-- mapping and care-plan fields' clinical approval (D-15), exception thresholds (Q9).
-- =============================================================================

-- 1. Qualification ------------------------------------------------------------------
alter table public.team_memberships
  add column qualification text check (qualification is null or qualification in ('registered_nurse', 'care_assistant'));

-- 2. Case: needs assessment done ----------------------------------------------------------
alter table public.cases add column needs_assessment_done_at timestamptz;
do $$ begin execute 'grant select (needs_assessment_done_at) on public.cases to authenticated'; end $$;

-- 3. Visit: billable basis -----------------------------------------------------------------
alter table public.care_visits
  add column planned_minutes_a   integer check (planned_minutes_a is null or planned_minutes_a between 0 and 600),
  add column planned_minutes_b   integer check (planned_minutes_b is null or planned_minutes_b between 0 and 600),
  add column planned_minutes_c   integer check (planned_minutes_c is null or planned_minutes_c between 0 and 600),
  add column is_needs_assessment boolean not null default false,
  add column responsible_user_id uuid;

drop trigger audit_care_visits on public.care_visits;
create trigger audit_care_visits
  after update on public.care_visits
  for each row execute function private.write_audit_event(
    'status', 'billable', 'team_id', 'visit_date', 'time_start', 'time_end',
    'planned_minutes_a', 'planned_minutes_b', 'planned_minutes_c', 'responsible_user_id');

-- Completing a needs-assessment visit marks the case (any write path).
create function private.mark_needs_assessment_done()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.is_needs_assessment and new.status = 'completed' and old.status is distinct from 'completed' then
    update public.cases set needs_assessment_done_at = coalesce(needs_assessment_done_at, now()) where id = new.case_id;
  end if;
  return new;
end;
$$;
revoke all on function private.mark_needs_assessment_done() from public, anon, authenticated;
create trigger care_visits_needs_assessment_done
  after update of status on public.care_visits
  for each row execute function private.mark_needs_assessment_done();

-- 4. Care-plan summary --------------------------------------------------------------------
create table public.care_plan_items (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  case_id         uuid not null,
  team_id         uuid not null,
  service         text not null check (char_length(btrim(service)) between 2 and 120),
  category        text not null check (category in ('A', 'B', 'C')),
  planned_minutes integer not null check (planned_minutes between 1 and 600),
  frequency       text not null check (char_length(btrim(frequency)) between 1 and 60),
  review_date     date not null,
  goal            text check (goal is null or char_length(btrim(goal)) between 3 and 300),
  active          boolean not null default true,
  created_by      uuid not null,
  created_at      timestamptz not null default now(),
  retired_by      uuid,
  retired_at      timestamptz,
  retire_reason   text check (retire_reason is null or char_length(retire_reason) between 3 and 300),
  foreign key (case_id, organization_id) references public.cases (id, organization_id),
  foreign key (team_id, organization_id) references public.teams (id, organization_id)
);
create index care_plan_items_case_idx on public.care_plan_items (case_id) where active;

alter table public.care_plan_items enable row level security;
revoke all on public.care_plan_items from anon, authenticated;
grant select on public.care_plan_items to authenticated;
create policy team_members_read on public.care_plan_items
  for select to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id));

create trigger audit_care_plan_items
  after insert or update on public.care_plan_items
  for each row execute function private.write_audit_event('category', 'planned_minutes', 'review_date', 'active');

-- 5. Plan change log (who, what before/after, why) -----------------------------------------
create table public.visit_plan_changes (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,             -- no FK: removed plans keep their history
  case_id         uuid,
  team_id         uuid,
  change          text not null check (change in ('planned', 'moved', 'removed')),
  before          jsonb,
  after           jsonb,
  reason          text check (reason is null or char_length(reason) between 3 and 300),
  actor_id        uuid not null,
  changed_at      timestamptz not null default now()
);
create index visit_plan_changes_visit_idx on public.visit_plan_changes (visit_id, changed_at);

alter table public.visit_plan_changes enable row level security;
revoke all on public.visit_plan_changes from anon, authenticated;
grant select on public.visit_plan_changes to authenticated;
create policy team_members_read on public.visit_plan_changes
  for select to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id));
create trigger visit_plan_changes_no_update_delete
  before update or delete on public.visit_plan_changes
  for each row execute function private.forbid_audit_change();

-- 6. Helpers ---------------------------------------------------------------------------------
create function private.visit_slot_json(v public.care_visits)
returns jsonb language sql immutable set search_path = ''
as $$ select jsonb_build_object('date', v.visit_date, 'start', v.time_start, 'end', v.time_end,
                                'a', v.planned_minutes_a, 'b', v.planned_minutes_b, 'c', v.planned_minutes_c,
                                'needs_assessment', v.is_needs_assessment) $$;

create function private.is_registered_nurse(p_team uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.team_memberships m
                     where m.team_id = p_team and m.user_id = p_user and m.qualification = 'registered_nurse') $$;

-- Flags for one (planned) visit, computed from case and care-plan facts.
create function private.visit_flags(p_case_id uuid, p_date date, p_minutes_b integer, p_responsible uuid,
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
         then 'uncovered' end
  ], null)
  from public.cases c where c.id = p_case_id;
$$;

revoke all on function private.visit_slot_json(public.care_visits), private.is_registered_nurse(uuid, uuid),
  private.visit_flags(uuid, date, integer, uuid, text, time) from public, anon, authenticated;

-- 7. Commands (replace the J3 v1 signatures) ---------------------------------------------------
drop function public.plan_visit(uuid, date, time, time, text[], uuid);
drop function public.reschedule_visit(uuid, date, time, time, uuid);
drop function public.remove_planned_visit(uuid, uuid);

-- Return jsonb: {"result": "ok"|"duplicate"|"rejected", "reason": code?, "visit_id": uuid?, "flags": [...]}
-- Rejection reasons: not_team_member, assessment_first, assessment_already_planned,
-- assessment_category_a_only, order_required, rn_required, responsible_not_in_team, minutes_exceed_window
create function public.plan_visit(
  p_case_id uuid, p_visit_date date, p_time_start time, p_time_end time,
  p_minutes_a integer, p_minutes_b integer, p_minutes_c integer,
  p_needs_assessment boolean, p_responsible_user_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  c    public.cases%rowtype;
  a    integer := coalesce(p_minutes_a, 0);
  b    integer := coalesce(p_minutes_b, 0);
  cc   integer := coalesce(p_minutes_c, 0);
  na   boolean := coalesce(p_needs_assessment, false);
  vid  uuid;
  services text[];
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  perform private.check_visit_slot(p_visit_date, p_time_start, p_time_end);
  if a < 0 or b < 0 or cc < 0 or a + b + cc = 0 then
    raise exception 'planned minutes per category are required' using errcode = '22023';
  end if;

  if private.begin_command('plan_visit', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;

  select * into c from public.cases where id = p_case_id for update;
  if not found or c.assigned_team_id is null
     or not private.is_org_member(c.organization_id)
     or not private.is_team_member(c.assigned_team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;

  if a + b + cc > extract(epoch from (p_time_end - p_time_start)) / 60 then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'minutes_exceed_window');
  end if;

  -- Needs assessment first (KLV Art. 8a)
  if c.needs_assessment_done_at is null then
    if not na then
      perform private.end_command('rejected');
      return jsonb_build_object('result', 'rejected', 'reason', 'assessment_first');
    end if;
    if exists (select 1 from public.care_visits v where v.case_id = c.id and v.is_needs_assessment
               and v.status in ('planned', 'on_the_way', 'started', 'paused')) then
      perform private.end_command('rejected');
      return jsonb_build_object('result', 'rejected', 'reason', 'assessment_already_planned');
    end if;
  end if;
  if na and (b > 0 or cc > 0) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'assessment_category_a_only');
  end if;

  -- Category B needs a medical order
  if b > 0 and c.medical_order_status is distinct from 'present' then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'order_required');
  end if;

  -- Responsible member
  if p_responsible_user_id is not null then
    if not exists (select 1 from public.team_memberships m
                   where m.team_id = c.assigned_team_id and m.user_id = p_responsible_user_id) then
      perform private.end_command('rejected');
      return jsonb_build_object('result', 'rejected', 'reason', 'responsible_not_in_team');
    end if;
    if (b > 0 or na) and not private.is_registered_nurse(c.assigned_team_id, p_responsible_user_id) then
      perform private.end_command('rejected');
      return jsonb_build_object('result', 'rejected', 'reason', 'rn_required');
    end if;
  end if;

  select coalesce(array_agg(distinct i.service), c.care_needs, '{}') into services
  from public.care_plan_items i where i.case_id = c.id and i.active;

  insert into public.care_visits
    (organization_id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status,
     planned_minutes_a, planned_minutes_b, planned_minutes_c, is_needs_assessment, responsible_user_id)
  values
    (c.organization_id, c.id, c.assigned_team_id, p_visit_date, p_time_start, p_time_end,
     case when na then array['Bedarfsabklärung'] else coalesce(services, '{}') end,
     false, 'planned', a, b, cc, na, p_responsible_user_id)
  returning id into vid;

  -- A/C without a medical order → the GP must be informed
  if b = 0 and c.medical_order_status is distinct from 'present' and not na then
    insert into public.case_tasks (organization_id, case_id, kind)
    values (c.organization_id, c.id, 'inform_gp')
    on conflict (case_id, kind) where status = 'open' do nothing;
  end if;

  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, after, actor_id)
  select v.organization_id, v.id, v.case_id, v.team_id, 'planned', private.visit_slot_json(v), uid
  from public.care_visits v where v.id = vid;

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'visit_id', vid,
    'flags', to_jsonb(private.visit_flags(c.id, p_visit_date, b, p_responsible_user_id, 'planned', p_time_start)));
end;
$$;

create function public.reschedule_visit(
  p_visit_id uuid, p_visit_date date, p_time_start time, p_time_end time, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  v      public.care_visits%rowtype;
  before jsonb;
  why    text := private.check_text(p_reason, 3, 300, 'reason');
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  perform private.check_visit_slot(p_visit_date, p_time_start, p_time_end);
  if private.begin_command('reschedule_visit', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;

  select * into v from public.care_visits where id = p_visit_id for update;
  if not found or v.status <> 'planned'
     or not private.is_org_member(v.organization_id) or not private.is_team_member(v.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if coalesce(v.planned_minutes_a, 0) + coalesce(v.planned_minutes_b, 0) + coalesce(v.planned_minutes_c, 0)
     > extract(epoch from (p_time_end - p_time_start)) / 60 then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'minutes_exceed_window');
  end if;

  before := private.visit_slot_json(v);
  update public.care_visits set visit_date = p_visit_date, time_start = p_time_start, time_end = p_time_end
  where id = v.id returning * into v;

  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  values (v.organization_id, v.id, v.case_id, v.team_id, 'moved', before, private.visit_slot_json(v), why, uid);

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'visit_id', v.id,
    'flags', to_jsonb(private.visit_flags(v.case_id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start)));
end;
$$;

create function public.remove_planned_visit(p_visit_id uuid, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := private.check_text(p_reason, 3, 300, 'reason');
begin
  if uid is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if private.begin_command('remove_planned_visit', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;

  select * into v from public.care_visits where id = p_visit_id for update;
  if not found or v.status <> 'planned'
     or not private.is_org_member(v.organization_id) or not private.is_team_member(v.team_id)
     or exists (select 1 from public.visit_events e where e.visit_id = v.id)
     or exists (select 1 from public.visit_observations o where o.visit_id = v.id)
     or exists (select 1 from public.care_notes n where n.visit_id = v.id)
     or exists (select 1 from public.quality_events q where q.visit_id = v.id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_removable');
  end if;

  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, reason, actor_id)
  values (v.organization_id, v.id, v.case_id, v.team_id, 'removed', private.visit_slot_json(v), why, uid);
  delete from public.care_visits where id = v.id;

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'visit_id', v.id);
end;
$$;

create function public.add_care_plan_item(
  p_case_id uuid, p_service text, p_category text, p_planned_minutes integer, p_frequency text,
  p_review_date date, p_goal text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
begin
  if uid is null then return 'rejected'; end if;
  if p_category not in ('A', 'B', 'C') or p_planned_minutes is null or p_planned_minutes not between 1 and 600
     or p_review_date is null or p_review_date < current_date then
    raise exception 'category A/B/C, 1–600 minutes and a review date from today are required' using errcode = '22023';
  end if;
  if private.begin_command('add_care_plan_item', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into c from public.cases where id = p_case_id;
  if not found or c.assigned_team_id is null
     or not private.is_org_member(c.organization_id) or not private.is_team_member(c.assigned_team_id) then
    return private.end_command('rejected');
  end if;
  insert into public.care_plan_items
    (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, goal, created_by)
  values
    (c.organization_id, c.id, c.assigned_team_id, private.check_text(p_service, 2, 120, 'service'), p_category,
     p_planned_minutes, private.check_text(p_frequency, 1, 60, 'frequency'), p_review_date,
     case when nullif(btrim(p_goal), '') is null then null else private.check_text(p_goal, 3, 300, 'goal') end, uid);
  return private.end_command('ok');
end;
$$;

create function public.retire_care_plan_item(p_item_id uuid, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  i   public.care_plan_items%rowtype;
  why text := private.check_text(p_reason, 3, 300, 'reason');
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('retire_care_plan_item', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  select * into i from public.care_plan_items where id = p_item_id for update;
  if not found or not i.active
     or not private.is_org_member(i.organization_id) or not private.is_team_member(i.team_id) then
    return private.end_command('rejected');
  end if;
  update public.care_plan_items set active = false, retired_by = uid, retired_at = now(), retire_reason = why
  where id = i.id;
  return private.end_command('ok');
end;
$$;

revoke all on function
  public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid),
  public.reschedule_visit(uuid, date, time, time, text, uuid),
  public.remove_planned_visit(uuid, text, uuid),
  public.add_care_plan_item(uuid, text, text, integer, text, date, text, uuid),
  public.retire_care_plan_item(uuid, text, uuid)
from public, anon;
grant execute on function
  public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid),
  public.reschedule_visit(uuid, date, time, time, text, uuid),
  public.remove_planned_visit(uuid, text, uuid),
  public.add_care_plan_item(uuid, text, text, integer, text, date, text, uuid),
  public.retire_care_plan_item(uuid, text, uuid)
to authenticated;

-- 8. Read models -----------------------------------------------------------------------------
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
  medical_order_status     text,      -- team context for category B (J1 funding facts)
  medical_order_valid_until date,
  open_tasks               text[],
  care_plan                jsonb,     -- [{"id","service","category","minutes","frequency","review_date","goal"}]
  members                  jsonb,     -- [{"user_id","qualification","me"}] — no names (no profiles yet, D-5)
  upcoming                 jsonb      -- [{"visit_id","date","start","end","status","a","b","c","needs_assessment","responsible_me","responsible_set","flags","last_change"}]
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
         ), '[]'::jsonb)
  from public.cases c
  join public.teams t on t.id = c.assigned_team_id
  join public.team_memberships tm on tm.team_id = t.id and tm.user_id = (select auth.uid())
  where c.status = 'laufend' and private.is_org_member(c.organization_id)
  order by c.last_name nulls last, c.id;
$$;

revoke all on function public.team_cases() from public, anon;
grant execute on function public.team_cases() to authenticated;

-- Operations: uncovered planned visits in the next 24 h (org-wide, no client identity).
create function public.uncovered_visits()
returns table (visit_id uuid, team_id uuid, team_name text, visit_date date, time_start time)
language sql stable security definer set search_path = ''
as $$
  select v.id, t.id, t.name, v.visit_date, v.time_start
  from public.care_visits v
  join public.teams t on t.id = v.team_id
  where private.is_org_member(v.organization_id)
    and 'uncovered' = any (private.visit_flags(v.case_id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start))
  order by v.visit_date, v.time_start;
$$;

revoke all on function public.uncovered_visits() from public, anon;
grant execute on function public.uncovered_visits() to authenticated;

-- field_visits: planned minutes per category, needs-assessment marker, responsibility (F1–F3 → J3)
drop function public.field_visits(date);

create function public.field_visits(p_date date)
returns table (
  visit_id            uuid,
  visit_date          date,
  time_start          time,
  time_end            time,
  status              text,
  services_provided   text[],
  team_id             uuid,
  team_name           text,
  case_id             uuid,
  client_name         text,
  care_needs          text[],
  address             text,
  plz                 text,
  ort                 text,
  events              jsonb,
  planned_minutes_a   integer,
  planned_minutes_b   integer,
  planned_minutes_c   integer,
  is_needs_assessment boolean,
  responsible_me      boolean,
  responsible_set     boolean,
  care_goals          text[]          -- active care-plan goals of the case (team-only RLS on care_plan_items)
)
language sql stable security invoker set search_path = ''
as $$
  select v.id, v.visit_date, v.time_start, v.time_end, v.status, v.services_provided,
         t.id, t.name,
         c.id, nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         c.care_needs, c.address, c.plz, c.ort,
         coalesce((
           select jsonb_agg(jsonb_build_object(
                    'id', e.id,
                    'type', e.event_type,
                    'at', coalesce(lc.corrected_at, e.occurred_at),
                    'recorded_at', e.occurred_at,
                    'corrected', lc.corrected_at is not null,
                    'reason', lc.reason)
                  order by e.id)
           from public.visit_events e
           left join lateral (
             select x.corrected_at, x.reason from public.visit_time_corrections x
             where x.event_id = e.id order by x.created_at desc, x.id desc limit 1
           ) lc on true
           where e.visit_id = v.id
         ), '[]'::jsonb),
         v.planned_minutes_a, v.planned_minutes_b, v.planned_minutes_c, v.is_needs_assessment,
         v.responsible_user_id = (select auth.uid()), v.responsible_user_id is not null,
         coalesce((select array_agg(i.goal order by i.category, i.service) from public.care_plan_items i
                   where i.case_id = v.case_id and i.active and i.goal is not null), '{}')
  from public.care_visits v
  join public.team_memberships tm
    on tm.team_id = v.team_id and tm.user_id = (select auth.uid())
  join public.teams t on t.id = v.team_id
  left join public.cases c on c.id = v.case_id
  where p_date is not null
    and v.visit_date = p_date
  order by v.time_start nulls last, v.id;
$$;

revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;

-- 9. Registered nurse required to START category B and needs-assessment visits ------------------------
-- Planning checks the responsible member (above); this closes the gap when nobody
-- was named: whoever performs the visit must be a registered nurse of the team.
grant execute on function private.is_registered_nurse(uuid, uuid) to authenticated;

create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' and new.status is distinct from old.status then
    if not ((old.status, new.status) in (
      ('planned',    'on_the_way'),
      ('planned',    'started'),
      ('on_the_way', 'started'),
      ('started',    'paused'),
      ('paused',     'started'),
      ('started',    'completed')
    )) then
      raise exception 'visit transition % -> % is not allowed', old.status, new.status
        using errcode = '23514';
    end if;
    if new.status = 'started' and old.status in ('planned', 'on_the_way')
       and (coalesce(new.planned_minutes_b, 0) > 0 or new.is_needs_assessment)
       and not private.is_registered_nurse(new.team_id, (select auth.uid())) then
      raise exception 'category B and needs-assessment visits are started by a registered nurse'
        using errcode = 'NV001';
    end if;
  end if;
  return new;
end;
$$;
