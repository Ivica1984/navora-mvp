-- =============================================================================
-- HAND1 — Handover without the team meeting: "since you were last here" (ADR-047)
-- Brief: docs/agents/briefs/HAND1.md (PO, approved 2026-10-22).
-- =============================================================================
-- * One read-only query over the existing append-only records. No new copy of clinical data.
-- * Nothing is summarised, ranked or interpreted: every entry is the recorded fact with its source.
-- * Access is not widened beyond the F0/F1-F4 team scope:
--     - the card visit must belong to one of the caller's teams (organisation member);
--     - visit-bound entries come only from visits of the caller's teams;
--     - case-bound entries (pause/close, primary nurse, medical order) only when the caller is in the
--       case's assigned team (the cases read rule, ADR-031);
--     - care-plan entries only for items of the caller's teams; quality events only of the caller's teams.
--   A covering nurse (COVER1) is not a member of the visit's team, so she gets nothing here (D-3).
-- * Window: entries recorded after the caller's own last completed visit of this case. If she never
--   completed one: the case's last N completed visits (pilot default N = 3, handover_settings) and
--   everything since. The card says which rule applied.
-- * "Shown before the start" is recorded with the start event (trigger on visit_events), not on card opens.
-- =============================================================================

-- 1. Configuration --------------------------------------------------------------------------------------------
create table public.handover_settings (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid references public.organizations (id),
  lookback_visits  integer not null check (lookback_visits between 1 and 10),
  unique nulls not distinct (organization_id)
);
comment on table public.handover_settings is
  'HAND1: how many completed visits a nurse sees when she has never visited the client (null org = default).';
insert into public.handover_settings (organization_id, lookback_visits) values (null, 3);
alter table public.handover_settings enable row level security;
revoke all on public.handover_settings from anon, authenticated;
grant select on public.handover_settings to authenticated;
create policy members_read on public.handover_settings for select to authenticated
  using (organization_id is null or private.is_org_member(organization_id));

create function private.handover_lookback(p_org uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select s.lookback_visits from public.handover_settings s
  where s.organization_id = p_org or s.organization_id is null
  order by s.organization_id nulls last limit 1
$$;

-- 2. Care-plan schedule changes become visible in the audit trail (old → new) ------------------------------------
drop trigger audit_care_plan_items on public.care_plan_items;
create trigger audit_care_plan_items
  after insert or update on public.care_plan_items
  for each row execute function private.write_audit_event(
    'category', 'planned_minutes', 'review_date', 'active',
    'freq_times', 'freq_period', 'freq_weekdays', 'window_start', 'window_end');

-- 3. Helpers (explicit user; used by the reader and by the start trigger) -----------------------------------------
create function private.user_in_team(p_team uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select p_team is not null and p_user is not null
         and exists (select 1 from public.team_memberships m where m.team_id = p_team and m.user_id = p_user) $$;

-- "me", "member:<n>" (n = position in the team ordered by user id, as on /team), "system", "outside".
-- No user ids leave the database.
create function private.member_code(p_team uuid, p_member uuid, p_user uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select case
    when p_member is null or p_member = private.plan_system_actor() then 'system'
    when p_member = p_user then 'me'
    else coalesce((select 'member:' || x.n
                   from (select m.user_id, row_number() over (order by m.user_id) as n
                         from public.team_memberships m where m.team_id = p_team) x
                   where x.user_id = p_member), 'outside')
  end
$$;

-- Which window applies for this user on this visit.
create function private.handover_rule(p_visit uuid, p_user uuid)
returns table (rule text, since_at timestamptz, since_date date, lookback integer)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v    public.care_visits%rowtype;
  n    integer;
  pv   public.care_visits%rowtype;
  v_at timestamptz;
begin
  select * into v from public.care_visits where id = p_visit;
  if not found or v.case_id is null then return; end if;
  n := coalesce(private.handover_lookback(v.organization_id), 3);

  -- The user's own last completed visit of this case (not this one, not after this day).
  select x.* into pv from public.care_visits x
  where x.case_id = v.case_id and x.id <> v.id and x.status = 'completed' and x.visit_date <= v.visit_date
    and private.visit_performer(x.id) = p_user
  order by x.visit_date desc, x.time_start desc nulls last limit 1;
  if found then
    select max(e.occurred_at) into v_at from public.visit_events e where e.visit_id = pv.id and e.event_type = 'completed';
    return query select 'since_own_visit'::text,
                        coalesce(v_at, (pv.visit_date + coalesce(pv.time_end, time '23:59')) at time zone 'Europe/Zurich'),
                        pv.visit_date, n;
    return;
  end if;

  -- Never visited: the n-th most recent completed visit of the case on the user's teams.
  select x.* into pv from public.care_visits x
  where x.case_id = v.case_id and x.id <> v.id and x.status = 'completed' and x.visit_date <= v.visit_date
    and private.user_in_team(x.team_id, p_user)
  order by x.visit_date desc, x.time_start desc nulls last
  offset greatest(n - 1, 0) limit 1;
  if not found then
    -- fewer than n: the oldest one
    select x.* into pv from public.care_visits x
    where x.case_id = v.case_id and x.id <> v.id and x.status = 'completed' and x.visit_date <= v.visit_date
      and private.user_in_team(x.team_id, p_user)
    order by x.visit_date, x.time_start nulls first limit 1;
  end if;
  if found then
    select min(e.occurred_at) into v_at from public.visit_events e where e.visit_id = pv.id;
    return query select 'last_visits'::text,
                        coalesce(v_at, pv.visit_date::timestamp at time zone 'Europe/Zurich'), pv.visit_date, n;
    return;
  end if;

  return query select 'no_visits'::text, '-infinity'::timestamptz, null::date, n;
end;
$$;

-- Every entry recorded for the case after the window start, oldest first. Team-scoped for p_user.
create function private.handover_entries(p_visit uuid, p_user uuid)
returns table (kind text, entry_id text, at timestamptz, source_visit_date date, source_visit_start time,
               author text, detail jsonb)
language sql stable security definer set search_path = ''
as $$
  with card as (
    select v.id, v.organization_id, v.case_id, v.team_id, c.assigned_team_id, r.since_at
    from public.care_visits v
    join public.cases c on c.id = v.case_id and c.organization_id = v.organization_id
    cross join lateral private.handover_rule(v.id, p_user) r
    where v.id = p_visit
      and exists (select 1 from public.organization_memberships m
                  where m.organization_id = v.organization_id and m.user_id = p_user)
      and private.user_in_team(v.team_id, p_user)
  ),
  case_ok as (select * from card where private.user_in_team(assigned_team_id, p_user)),
  entries as (
    -- Observations and handovers from other visits (F4), current versions only.
    select 'observation' as kind, o.id::text as entry_id, o.recorded_at as at, sv.visit_date, sv.time_start,
           private.member_code(k.team_id, o.author_id, p_user) as author,
           jsonb_build_object('content', o.content, 'for_handover', o.for_handover, 'edited', o.supersedes_id is not null) as detail
    from card k
    join public.visit_observations o on o.case_id = k.case_id and o.organization_id = k.organization_id and o.visit_id <> k.id
    join public.care_visits sv on sv.id = o.visit_id
    where o.recorded_at > k.since_at and private.user_in_team(o.team_id, p_user)
      and not exists (select 1 from public.visit_observations s where s.supersedes_id = o.id)
    union all
    -- Care plan (J3): items added and retired (with reason), schedule changes (PLAN2; old → new from 0033 on).
    select 'care_plan_added', i.id::text, i.created_at, null, null, private.member_code(k.team_id, i.created_by, p_user),
           jsonb_build_object('service', i.service, 'category', i.category, 'minutes', i.planned_minutes,
                              'frequency', i.frequency, 'goal', i.goal)
    from card k join public.care_plan_items i on i.case_id = k.case_id and i.organization_id = k.organization_id
    where i.created_at > k.since_at and private.user_in_team(i.team_id, p_user)
    union all
    select 'care_plan_retired', i.id::text || ':retired', i.retired_at, null, null, private.member_code(k.team_id, i.retired_by, p_user),
           jsonb_build_object('service', i.service, 'category', i.category, 'reason', i.retire_reason)
    from card k join public.care_plan_items i on i.case_id = k.case_id and i.organization_id = k.organization_id
    where i.retired_at > k.since_at and private.user_in_team(i.team_id, p_user)
    union all
    select 'care_plan_schedule', 'audit:' || a.id, a.occurred_at, null, null, private.member_code(k.team_id, a.actor_id, p_user),
           jsonb_build_object('service', i.service, 'changed', a.changed)
    from card k
    join public.care_plan_items i on i.case_id = k.case_id and i.organization_id = k.organization_id
    join public.audit_events a on a.table_name = 'care_plan_items' and a.entity_id = i.id and a.command = 'set_care_plan_schedule'
    where a.occurred_at > k.since_at and private.user_in_team(i.team_id, p_user)
    union all
    -- Visit plan changes with reasons (J3 change log). Changes the plan generator derives from a care-plan
    -- change are represented by that care-plan entry.
    select 'visit_' || pc.change, 'plan:' || pc.id, pc.changed_at,
           coalesce((pc.before ->> 'date')::date, (pc.after ->> 'date')::date),
           coalesce((pc.before ->> 'start')::time, (pc.after ->> 'start')::time),
           private.member_code(k.team_id, pc.actor_id, p_user),
           jsonb_build_object('before', pc.before, 'after', pc.after, 'reason', pc.reason)
    from card k join public.visit_plan_changes pc on pc.case_id = k.case_id and pc.organization_id = k.organization_id
    where pc.change in ('moved', 'removed') and pc.changed_at > k.since_at and private.user_in_team(pc.team_id, p_user)
      and not (pc.actor_id = private.plan_system_actor() and coalesce(pc.reason, '') like 'care plan%')
    union all
    -- C1: pause, resume, close, reopen of the case.
    select 'case_' || l.kind, l.id::text, l.created_at, null, null, private.member_code(k.team_id, l.actor_id, p_user),
           jsonb_build_object('reason_code', l.reason_code, 'note', l.note, 'expected_end', l.expected_end)
    from case_ok k join public.case_lifecycle_events l on l.case_id = k.case_id and l.organization_id = k.organization_id
    where l.created_at > k.since_at
    union all
    -- C1: cancellations and no-shows of other visits.
    select 'visit_' || n.kind, n.id::text, n.created_at, sv.visit_date, sv.time_start, private.member_code(k.team_id, n.actor_id, p_user),
           jsonb_build_object('reason_code', n.reason_code, 'note', n.note)
    from card k
    join public.care_visits sv on sv.case_id = k.case_id and sv.organization_id = k.organization_id and sv.id <> k.id
    join public.visit_status_notes n on n.visit_id = sv.id
    where n.created_at > k.since_at and private.user_in_team(sv.team_id, p_user)
    union all
    -- J6: primary nurse and deputy (audit trail, reason from the change log).
    select 'primary_nurse', 'audit:' || a.id, a.occurred_at, null, null, private.member_code(k.team_id, a.actor_id, p_user),
           jsonb_strip_nulls(jsonb_build_object(
             'primary_old', case when (a.changed -> 'primary_nurse_id' -> 'old') is distinct from (a.changed -> 'primary_nurse_id' -> 'new') then private.member_code(k.team_id, (a.changed -> 'primary_nurse_id' ->> 'old')::uuid, p_user) end,
             'primary_new', case when (a.changed -> 'primary_nurse_id' -> 'old') is distinct from (a.changed -> 'primary_nurse_id' -> 'new') then private.member_code(k.team_id, (a.changed -> 'primary_nurse_id' ->> 'new')::uuid, p_user) end,
             'deputy_old', case when (a.changed -> 'deputy_nurse_id' -> 'old') is distinct from (a.changed -> 'deputy_nurse_id' -> 'new') then private.member_code(k.team_id, (a.changed -> 'deputy_nurse_id' ->> 'old')::uuid, p_user) end,
             'deputy_new', case when (a.changed -> 'deputy_nurse_id' -> 'old') is distinct from (a.changed -> 'deputy_nurse_id' -> 'new') then private.member_code(k.team_id, (a.changed -> 'deputy_nurse_id' ->> 'new')::uuid, p_user) end,
             'reason', cl.reason))
    from case_ok k
    join public.audit_events a on a.table_name = 'cases' and a.entity_id = k.case_id
                               and ((a.changed -> 'primary_nurse_id' -> 'old') is distinct from (a.changed -> 'primary_nurse_id' -> 'new') or (a.changed -> 'deputy_nurse_id' -> 'old') is distinct from (a.changed -> 'deputy_nurse_id' -> 'new'))
    left join public.change_log cl on cl.entity_table = 'cases' and cl.entity_id = k.case_id::text and cl.command = 'set_primary_nurse'
                                   and cl.actor_id = a.actor_id and cl.idempotency_key = a.idempotency_key
    where a.occurred_at > k.since_at
    union all
    -- J1/J3: medical order status and validity.
    select 'medical_order', 'audit:' || a.id, a.occurred_at, null, null, private.member_code(k.team_id, a.actor_id, p_user),
           jsonb_strip_nulls(jsonb_build_object('status', case when (a.changed -> 'medical_order_status' -> 'old') is distinct from (a.changed -> 'medical_order_status' -> 'new') then a.changed -> 'medical_order_status' end,
                                                'valid_until', case when (a.changed -> 'medical_order_valid_until' -> 'old') is distinct from (a.changed -> 'medical_order_valid_until' -> 'new') then a.changed -> 'medical_order_valid_until' end,
                                                'reason', cl.reason))
    from case_ok k
    join public.audit_events a on a.table_name = 'cases' and a.entity_id = k.case_id
                               and ((a.changed -> 'medical_order_status' -> 'old') is distinct from (a.changed -> 'medical_order_status' -> 'new') or (a.changed -> 'medical_order_valid_until' -> 'old') is distinct from (a.changed -> 'medical_order_valid_until' -> 'new'))
    left join public.change_log cl on cl.entity_table = 'cases' and cl.entity_id = k.case_id::text and cl.command = 'update_case_intake'
                                   and cl.actor_id = a.actor_id and cl.idempotency_key = a.idempotency_key
    where a.occurred_at > k.since_at
    union all
    -- QG1: quality events of the caller's teams, with their current status.
    select 'quality_event', q.id::text, q.created_at, sv.visit_date, sv.time_start, private.member_code(k.team_id, q.author_id, p_user),
           jsonb_build_object('title', q.title, 'severity', q.severity, 'status', q.status, 'occurred_at', q.occurred_at)
    from card k
    join public.quality_events q on q.case_id = k.case_id and q.organization_id = k.organization_id
    left join public.care_visits sv on sv.id = q.visit_id
    where q.created_at > k.since_at and private.user_in_team(q.team_id, p_user) and q.visit_id is distinct from k.id
  )
  select * from entries order by at, entry_id
$$;

revoke all on function private.handover_lookback(uuid), private.user_in_team(uuid, uuid), private.member_code(uuid, uuid, uuid),
  private.handover_rule(uuid, uuid), private.handover_entries(uuid, uuid) from public, anon, authenticated;

-- 4. Read model for /field --------------------------------------------------------------------------------------------
-- One row per entry; a card without entries still gets one row (kind null) carrying the rule.
create function public.field_since_last(p_date date)
returns table (
  visit_id           uuid,
  rule               text,       -- since_own_visit | last_visits | no_visits
  since_date         date,
  lookback           integer,
  kind               text,
  entry_id           text,
  at                 timestamptz,
  source_visit_date  date,
  source_visit_start time,
  author             text,       -- me | member:<n> | system | outside
  detail             jsonb
)
language sql stable security definer set search_path = ''
as $$
  select v.id, r.rule, r.since_date, r.lookback, e.kind, e.entry_id, e.at, e.source_visit_date, e.source_visit_start, e.author, e.detail
  from public.care_visits v
  cross join lateral private.handover_rule(v.id, (select auth.uid())) r
  left join lateral private.handover_entries(v.id, (select auth.uid())) e on true
  where p_date is not null and v.visit_date = p_date and v.case_id is not null
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  order by v.id, e.at nulls first, e.entry_id
$$;
revoke all on function public.field_since_last(date) from public, anon;
grant execute on function public.field_since_last(date) to authenticated;

-- 5. Audit fact: what the section held when the nurse started the visit ------------------------------------------
create table public.handover_shown (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id),
  visit_id        uuid not null,
  nurse_id        uuid not null,
  visit_event_id  bigint not null unique references public.visit_events (id),
  rule            text not null check (rule in ('since_own_visit', 'last_visits', 'no_visits')),
  since_at        timestamptz not null,
  entries         jsonb not null,     -- [{"kind": …, "id": …}] — references only, no content copy
  entry_count     integer not null,
  created_at      timestamptz not null default now(),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id)
);
comment on table public.handover_shown is
  'HAND1: entries the "since you were last here" section held when the nurse started the visit (append-only).';
create index handover_shown_visit_idx on public.handover_shown (visit_id);
alter table public.handover_shown enable row level security;
revoke all on public.handover_shown from anon, authenticated;
create trigger handover_shown_no_update_delete before update or delete on public.handover_shown
  for each row execute function private.forbid_audit_change();
create trigger handover_shown_no_truncate before truncate on public.handover_shown
  for each statement execute function private.forbid_audit_change();

create function private.record_handover_shown()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v public.care_visits%rowtype;
  r record;
  e jsonb;
begin
  if new.event_type <> 'started' or new.actor_id is null then return null; end if;
  select * into v from public.care_visits where id = new.visit_id;
  if not found or v.case_id is null or not private.user_in_team(v.team_id, new.actor_id) then return null; end if;
  select * into r from private.handover_rule(v.id, new.actor_id);
  if r.rule is null then return null; end if;
  select coalesce(jsonb_agg(jsonb_build_object('kind', x.kind, 'id', x.entry_id) order by x.at, x.entry_id), '[]'::jsonb)
    into e from private.handover_entries(v.id, new.actor_id) x;
  insert into public.handover_shown (organization_id, visit_id, nurse_id, visit_event_id, rule, since_at, entries, entry_count)
  values (v.organization_id, v.id, new.actor_id, new.id, r.rule, r.since_at, e, jsonb_array_length(e));
  return null;
end;
$$;
revoke all on function private.record_handover_shown() from public, anon, authenticated;
create trigger visit_events_handover_shown after insert on public.visit_events
  for each row execute function private.record_handover_shown();

-- 6. AN1: share of visits after another nurse's visit where the section was there at the start --------------------
do $patch$
declare
  def text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  a   text := '  all_rows as (
    select * from visit_kpis';
  b   text := '    union all select * from planning_actions
  )';
  c   text := '              when r.kpi = ''open_p1_exceptions'' then';
begin
  if position(a in def) = 0 or position(b in def) = 0 or position(c in def) = 0 then
    raise exception 'pilot_kpis no longer matches the HAND1 patch';
  end if;
  def := replace(def, a, '  -- HAND1: completed visits whose previous completed visit of the case was done by another nurse.
  handover_kpi as (
    select d.organization_id, d.team_id, ''handover_shown_before_start'' as kpi,
           round(100.0 * count(*) filter (where exists (select 1 from public.handover_shown h where h.visit_id = d.id
                                                          and h.nurse_id = d.performer)) / count(*), 1) as value,
           count(*)::int as base
    from done d
    cross join lateral (
      select private.visit_performer(pv.id) as performer from public.care_visits pv
      where pv.case_id = d.case_id and pv.id <> d.id and pv.status = ''completed''
        and (pv.visit_date < d.visit_date or (pv.visit_date = d.visit_date and pv.time_start < d.time_start))
      order by pv.visit_date desc, pv.time_start desc nulls last limit 1) prev
    where d.case_id is not null and d.performer is not null and prev.performer is not null and prev.performer <> d.performer
    group by grouping sets ((d.organization_id, d.team_id), (d.organization_id))
  ),
' || a);
  def := replace(def, b, '    union all select * from planning_actions union all select * from handover_kpi
  )');
  def := replace(def, c, '              when r.kpi = ''handover_shown_before_start''
                then ''Gezeigt heisst: beim Start im Abschnitt «Seit deinem letzten Einsatz» vorhanden. Ob gelesen wurde, wird nicht erfasst.''
' || c);
  execute def;
end
$patch$;
