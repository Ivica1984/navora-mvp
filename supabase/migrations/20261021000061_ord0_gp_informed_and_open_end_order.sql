-- ORD0: the doctor link that must not get lost (`docs/agents/briefs/ORD0.md`, PO 2026-10-24 03:10 and 07:10; ADR-075).
-- Findings CGR-36, CGR-38 (`cra` 2026-10-24 02:26, advisory S2) and CGR-40 (`cra` 06:30, advisory S3); remediation plans
-- `docs/agents/clinical/remediation/CGR-36.md` and `CGR-38.md`. Product decisions of the PO; no deadline, content, order
-- duration or billing effect is decided here (D-22, `legal` / `clinical`).
--
-- Before:
--   * CGR-36: `plan_visit` and PLAN2 open the case task `inform_gp` ("Hausärztin/Hausarzt informieren (A/C ohne
--     Verordnung)") when A/C care is planned without a present medical order. No command completes it
--     (`complete_case_task` refuses every kind but `review_after_pause`); only a case close sets it `done`. Whether,
--     when and how the doctor was informed is not recorded anywhere.
--   * CGR-38: an order `present` without an end date raises nothing (`order_expiring` needs an end date); PLAN2 keeps
--     generating B visits for it. Billing refuses it (CR-046), care does not prompt anybody.
-- Now (IMPLEMENTED in this migration):
--   1. ORD0-1 `public.case_gp_notices`: one row per "Hausärztin/Hausarzt informiert" record: case, team, the date it
--      happened, one channel code (`elektronisch`, `brief`, `telefon`, `persoenlich`), the task it closed, actor and time
--      set by the server. No free text, no health data. Append-only (guard trigger; no write grant), audited
--      (`private.write_audit_event`), readable by the case's team and coordinators of the organisation.
--   2. ORD0-1/2 `public.record_gp_informed(case, informed_on, channel, key)`: a member of the case's assigned team; the
--      date not after today and not before the case was created (Europe/Zurich days; CGR-40); the case not closed; an
--      open `inform_gp` task. Writes the row and sets the task `done` (`done_at`, `done_by`) in one transaction.
--      Idempotent: a replay of the key returns `duplicate`. `complete_case_task('inform_gp')` stays refused (separate
--      command, brief question 1).
--   3. ORD0-2 (engineering, ADR-075; decision Q12 for `po`): once a case has a record, planning (`plan_visit`) and PLAN2
--      (`private.generate_case_plan`) no longer reopen `inform_gp` for that case. Without this the next plan refresh
--      (every `/team` load) would reopen the task and ORD0-2 could not hold. When the team should be asked again (e.g.
--      after a new needs assessment) is Q12; a returning client gets a new case and therefore a new task as today.
--   4. ORD0-4 exception `order_without_end_date` (P3, operating rule, no threshold): a case with lifecycle `active`, an
--      assigned team, `medical_order_status = 'present'`, no `medical_order_valid_until` and at least one active care-plan
--      item of category B. Shown in OPS1 and on `/team` (`team_visit_alerts`); it closes only with its cause (end date
--      entered, order no longer `present`, no active B item, case no longer active): a hand close returns
--      `cause_persists` and an earlier close never hides it. Intake keeps accepting an order without an end date.
--   5. ORD0-6 evidence: `private.order_open_end_episodes` records each period in which the condition held (trigger-
--      maintained from `cases` and `care_plan_items`, backfilled as open from now for cases already in that state), with
--      how it ended. AN2 measure 10 gains `order_open_end_ending` (share per ending code) and
--      `inform_gp_done_within_7d_share` (share of `inform_gp` tasks created in the month that were closed by a record
--      within 7 days of their creation; evidence for D-22, not a deadline). Per team and organisation, AN1 suppression.
--   6. ORD0-3 HAND1: `private.handover_entries` lists the record as `gp_informed` (date, channel, member code).
-- Unchanged: who plans, intake, `order_expiring`, billing (CR-046), case close closing every open task, the SIG1
--   writer (P3 is never delivered; `signal_kind_of` ignores the new type).

-- 0. Patch helper: string replacement on a function's own definition, each pair matching the stated number of times;
--    idempotent through a marker that the patched body contains.
create function private.ord0_patch(p_fn text, p_triples text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;   -- already applied
  end if;
  for i in 1 .. coalesce(array_length(p_triples, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_triples[i], ''))) / length(p_triples[i]);
    if n <> p_triples[i + 2]::integer then
      raise exception 'ORD0 patch for % must match % time(s), matched %: %', p_fn, p_triples[i + 2], n, p_triples[i];
    end if;
    def := replace(def, p_triples[i], p_triples[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception 'ORD0 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.ord0_patch(text, text[], text) from public, anon, authenticated;

-- 1. ORD0-1: the record ------------------------------------------------------------------------------------------------
create table if not exists public.case_gp_notices (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  case_id         uuid not null,
  team_id         uuid not null references public.teams (id),
  informed_on     date not null,
  channel         text not null check (channel in ('elektronisch', 'brief', 'telefon', 'persoenlich')),
  task_id         uuid references public.case_tasks (id),
  recorded_by     uuid not null references auth.users (id),
  recorded_at     timestamptz not null default now(),
  foreign key (case_id, organization_id) references public.cases (id, organization_id)
);
create index if not exists case_gp_notices_case_idx on public.case_gp_notices (case_id, recorded_at desc);
comment on table public.case_gp_notices is
  'ORD0-1 (CGR-36): "Hausärztin/Hausarzt informiert" per case: the date it happened and a fixed channel code; actor and '
  'time set by public.record_gp_informed. No free text, no health data. Append-only and audited.';
comment on column public.case_gp_notices.informed_on is
  'The day the doctor was informed (Europe/Zurich): not after the recording day, not before the case was created (CGR-40).';

alter table public.case_gp_notices enable row level security;
revoke all on public.case_gp_notices from public, anon, authenticated;
grant select (id, organization_id, case_id, team_id, informed_on, channel, task_id, recorded_by, recorded_at)
  on public.case_gp_notices to authenticated;

drop policy if exists case_team_and_coordinators_read on public.case_gp_notices;
create policy case_team_and_coordinators_read on public.case_gp_notices
  for select to authenticated
  using (private.is_org_member(organization_id)
         and (private.is_team_member(team_id)
              or private.is_coordinator(organization_id)
              or private.is_team_member((select c.assigned_team_id from public.cases c where c.id = case_id))));

create or replace function private.case_gp_notices_immutable()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'a "doctor informed" record is never changed or deleted' using errcode = '42501';
end;
$$;
revoke all on function private.case_gp_notices_immutable() from public, anon, authenticated;
drop trigger if exists case_gp_notices_immutable on public.case_gp_notices;
create trigger case_gp_notices_immutable before update or delete on public.case_gp_notices
  for each row execute function private.case_gp_notices_immutable();

drop trigger if exists audit_case_gp_notices on public.case_gp_notices;
create trigger audit_case_gp_notices after insert on public.case_gp_notices
  for each row execute function private.write_audit_event('case_id', 'informed_on', 'channel', 'task_id');

-- 2. ORD0-1/2: the command ---------------------------------------------------------------------------------------------
create or replace function public.record_gp_informed(p_case_id uuid, p_informed_on date, p_channel text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  c     public.cases%rowtype;
  today date := (now() at time zone 'Europe/Zurich')::date;
  task  uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_signed_in'); end if;
  if p_case_id is null or p_informed_on is null or p_channel is null
     or p_channel not in ('elektronisch', 'brief', 'telefon', 'persoenlich') then
    raise exception 'a case, a date and one channel code (elektronisch, brief, telefon, persoenlich) are required'
      using errcode = '22023';
  end if;
  if private.begin_command('record_gp_informed', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;

  select * into c from public.cases where id = p_case_id;
  if not found or not private.is_org_member(c.organization_id) or c.assigned_team_id is null
     or not private.is_team_member(c.assigned_team_id) then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'not_team');
  end if;
  if c.lifecycle = 'closed' then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'case_closed');
  end if;
  if p_informed_on > today then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'future');
  end if;
  -- CGR-40: the doctor is often informed at the needs assessment, before the task exists; the case is the lower bound.
  if p_informed_on < (c.created_at at time zone 'Europe/Zurich')::date then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'before_case');
  end if;

  select k.id into task from public.case_tasks k
  where k.case_id = c.id and k.kind = 'inform_gp' and k.status = 'open'
  for update;
  if task is null then
    return jsonb_build_object('result', private.end_command('unchanged'), 'reason', 'no_open_task');
  end if;

  insert into public.case_gp_notices (organization_id, case_id, team_id, informed_on, channel, task_id, recorded_by)
  values (c.organization_id, c.id, c.assigned_team_id, p_informed_on, p_channel, task, uid);
  update public.case_tasks set status = 'done', done_at = now(), done_by = uid where id = task;

  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.record_gp_informed(uuid, date, text, uuid) from public, anon;
grant execute on function public.record_gp_informed(uuid, date, text, uuid) to authenticated;
comment on function public.record_gp_informed(uuid, date, text, uuid) is
  'ORD0-1/2 (CGR-36, CGR-40): a member of the case''s team records that the treating doctor was informed (date, channel '
  'code); closes the open inform_gp task. Audited, idempotent. Results: ok, duplicate, unchanged (no open task), '
  'rejected (not_team, case_closed, future, before_case, not_signed_in).';

-- 3. ORD0-2: a recorded case does not get the task back from planning or PLAN2 (ADR-075, Q12) ----------------------------
select private.ord0_patch(
  'public.plan_visit(uuid, date, time without time zone, time without time zone, integer, integer, integer, boolean, uuid, uuid)',
  array[
    E'  if b = 0 and c.medical_order_status is distinct from \'present\' and not na then\n',
    E'  -- ORD0-2 (ADR-075, Q12): not again once the team recorded that the doctor was informed.\n'
    || E'  if b = 0 and c.medical_order_status is distinct from \'present\' and not na\n'
    || E'     and not exists (select 1 from public.case_gp_notices g where g.case_id = c.id) then\n',
    '1'],
  'ORD0-2 (ADR-075, Q12)');

select private.ord0_patch('private.generate_case_plan(uuid, uuid)', array[
    E'  if no_order_ac then\n',
    E'  -- ORD0-2 (ADR-075, Q12): not again once the team recorded that the doctor was informed.\n'
    || E'  if no_order_ac and not exists (select 1 from public.case_gp_notices g where g.case_id = c.id) then\n',
    '1'],
  'ORD0-2 (ADR-075, Q12)');

-- 4. ORD0-4/6: the episodes of "order present without an end date on B care" ------------------------------------------
create table if not exists private.order_open_end_episodes (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  case_id         uuid not null,
  team_id         uuid,
  started_at      timestamptz not null default now(),
  ended_at        timestamptz,
  ending          text check (ending in ('end_date_entered', 'order_not_present', 'no_b_item', 'case_not_active')),
  check ((ended_at is null) = (ending is null))
);
create unique index if not exists order_open_end_episodes_one_open on private.order_open_end_episodes (case_id) where ended_at is null;
revoke all on private.order_open_end_episodes from public, anon, authenticated;
comment on table private.order_open_end_episodes is
  'ORD0-4/6 (CGR-38): periods in which a case met the order_without_end_date condition, and how each ended. Internal; '
  'read by derived_exceptions (since) and AN2 measure 10.';

-- The condition (one definition, used by the episodes and by derived_exceptions).
create or replace function private.order_without_end_date_holds(p_case_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select c.lifecycle = 'active' and c.assigned_team_id is not null
           and c.medical_order_status = 'present' and c.medical_order_valid_until is null
           and exists (select 1 from public.care_plan_items i where i.case_id = c.id and i.active and i.category = 'B')
    from public.cases c where c.id = p_case_id), false)
$$;
revoke all on function private.order_without_end_date_holds(uuid) from public, anon, authenticated;

create or replace function private.sync_order_open_end_episode(p_case_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  c    public.cases%rowtype;
  ep   uuid;
begin
  select * into c from public.cases where id = p_case_id;
  if not found then return; end if;
  select e.id into ep from private.order_open_end_episodes e where e.case_id = c.id and e.ended_at is null for update;
  if private.order_without_end_date_holds(c.id) then
    if ep is null then
      insert into private.order_open_end_episodes (organization_id, case_id, team_id) values (c.organization_id, c.id, c.assigned_team_id);
    end if;
  elsif ep is not null then
    update private.order_open_end_episodes set ended_at = now(),
      ending = case when c.lifecycle <> 'active' or c.assigned_team_id is null then 'case_not_active'
                    when c.medical_order_status is distinct from 'present' then 'order_not_present'
                    when c.medical_order_valid_until is not null then 'end_date_entered'
                    else 'no_b_item' end
    where id = ep;
  end if;
end;
$$;
revoke all on function private.sync_order_open_end_episode(uuid) from public, anon, authenticated;

create or replace function private.order_open_end_from_cases()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.sync_order_open_end_episode(new.id);
  return null;
end;
$$;
create or replace function private.order_open_end_from_plan_items()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  perform private.sync_order_open_end_episode(new.case_id);
  return null;
end;
$$;
revoke all on function private.order_open_end_from_cases() from public, anon, authenticated;
revoke all on function private.order_open_end_from_plan_items() from public, anon, authenticated;

drop trigger if exists ord0_order_open_end on public.cases;
create trigger ord0_order_open_end
  after insert or update of medical_order_status, medical_order_valid_until, lifecycle, assigned_team_id on public.cases
  for each row execute function private.order_open_end_from_cases();
drop trigger if exists ord0_order_open_end on public.care_plan_items;
create trigger ord0_order_open_end
  after insert or update of active, category on public.care_plan_items
  for each row execute function private.order_open_end_from_plan_items();

-- Backfill: cases already in that state get an open episode from now (no earlier history exists; ADR-075).
insert into private.order_open_end_episodes (organization_id, case_id, team_id)
select c.organization_id, c.id, c.assigned_team_id from public.cases c
where private.order_without_end_date_holds(c.id)
  and not exists (select 1 from private.order_open_end_episodes e where e.case_id = c.id and e.ended_at is null);

-- 5. ORD0-4: the exception ----------------------------------------------------------------------------------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step, amount_direction)
values ('order_without_end_date', 'P3', null, null, null, 'Verordnung ohne Enddatum',
        'Team: Enddatum der ärztlichen Verordnung erfassen oder die Verordnung klären. Bleibt sichtbar, bis ein Enddatum '
        || 'erfasst ist, die Verordnung nicht mehr vorliegt oder keine B-Leistung mehr aktiv ist. Ob eine Verordnung ohne '
        || 'Enddatum zulässig ist, ist offen (D-22).', null)
on conflict (exception_type) do nothing;

select private.ord0_patch('private.derived_exceptions(uuid)', array[
    E'    and now() >= private.after_threshold(c.created_at, t.amount, t.unit)\n',
    E'    and now() >= private.after_threshold(c.created_at, t.amount, t.unit)\n'
    || E'  union all\n'
    || E'  -- ORD0-4 (CGR-38): B care on an order present without an end date; a prompt, never a block (closes with its cause)\n'
    || E'  select \'order_without_end_date:\' || c.id || coalesce(\':\' || e.id, \'\'), \'order_without_end_date\',\n'
    || E'         coalesce(e.started_at, now()), c.id, c.assigned_team_id, \'case\', c.id,\n'
    || E'         \'Verordnung vorhanden, ohne Enddatum · B-Leistung aktiv\'\n'
    || E'  from public.cases c\n'
    || E'  join rules r on r.exception_type = \'order_without_end_date\'\n'
    || E'  left join private.order_open_end_episodes e on e.case_id = c.id and e.ended_at is null\n'
    || E'  where c.organization_id = p_org and private.order_without_end_date_holds(c.id)\n',
    '1'],
  'ORD0-4 (CGR-38)');
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- It closes only with its cause: in OPS1 (`closable`, the visibility filter) and in the close command.
select private.ord0_patch('private.exception_closes_with_cause(uuid, text)', array[
    E'p_type in (\'visit_uncovered\', \'visit_interrupted\', \'report_correction_open\')',
    E'p_type in (\'visit_uncovered\', \'visit_interrupted\', \'report_correction_open\', \'order_without_end_date\' /* ORD0-4 */)',
    '1'],
  'ORD0-4');

select private.ord0_patch('public.operations_exceptions()', array[
    E'd.exception_type in (\'visit_uncovered\', \'visit_interrupted\', \'report_correction_open\')',
    E'd.exception_type in (\'visit_uncovered\', \'visit_interrupted\', \'report_correction_open\', \'order_without_end_date\' /* ORD0-4 */)',
    '2'],
  'ORD0-4');

select private.ord0_patch('public.team_visit_alerts()', array[
    E'x.exception_type in (\'visit_overdue\', \'visit_stuck\', \'visit_interrupted\', \'report_correction_open\')',
    E'x.exception_type in (\'visit_overdue\', \'visit_stuck\', \'visit_interrupted\', \'report_correction_open\', \'order_without_end_date\' /* ORD0-4 */)',
    '1',
    E'd.exception_type in (\'visit_interrupted\', \'report_correction_open\')',
    E'd.exception_type in (\'visit_interrupted\', \'report_correction_open\', \'order_without_end_date\')',
    '1',
    E'(select mt.name from my_teams mt where mt.team_id = d.team_id limit 1), d.entity_id,',
    E'(select mt.name from my_teams mt where mt.team_id = d.team_id limit 1),\n'
    || E'         case when d.entity_type = \'visit\' then d.entity_id end,  -- ORD0-4: a case alert has no visit\n',
    '1'],
  'ORD0-4');

-- 6. ORD0-3: HAND1 lists the record -----------------------------------------------------------------------------------
select private.ord0_patch('private.handover_entries(uuid, uuid)', array[
    E'    union all\n    -- QG1: quality events of the caller\'s teams, with their current status.\n',
    E'    union all\n'
    || E'    -- ORD0-3: the doctor was informed (date and channel code, member code; no free text).\n'
    || E'    select \'gp_informed\', g.id::text, g.recorded_at, null, null, private.member_code(k.team_id, g.recorded_by, p_user),\n'
    || E'           jsonb_build_object(\'informed_on\', g.informed_on, \'channel\', g.channel)\n'
    || E'    from case_ok k join public.case_gp_notices g on g.case_id = k.case_id and g.organization_id = k.organization_id\n'
    || E'    where g.recorded_at > k.since_at\n'
    || E'    union all\n    -- QG1: quality events of the caller\'s teams, with their current status.\n',
    '1'],
  'ORD0-3');

-- 7. ORD0-6: AN2 measure 10 --------------------------------------------------------------------------------------------
select private.ord0_patch('public.pilot_hypotheses(date)', array[
    E'  ),\n  computed as (',
    E'  ), ord0_episodes as (\n'
    || E'    -- ORD0-6: how "Verordnung ohne Enddatum" ends (episodes started in the month; still open ones in the base)\n'
    || E'    select e.organization_id, e.team_id, coalesce(e.ending, \'still_open\') as ending\n'
    || E'    from private.order_open_end_episodes e, params p\n'
    || E'    where e.team_id in (select id from my_teams)\n'
    || E'      and (e.started_at at time zone \'Europe/Zurich\')::date >= p.m0 and (e.started_at at time zone \'Europe/Zurich\')::date < p.m1\n'
    || E'  ), ord0_endings(code) as (\n'
    || E'    values (\'end_date_entered\'), (\'order_not_present\'), (\'no_b_item\'), (\'case_not_active\'), (\'still_open\')\n'
    || E'  ), ord0_tasks as (\n'
    || E'    -- ORD0-6: inform_gp tasks created in the month; done by a record within 7 days (evidence for D-22, no deadline)\n'
    || E'    select c.organization_id, c.assigned_team_id as team_id,\n'
    || E'           exists (select 1 from public.case_gp_notices g where g.task_id = k.id and k.done_at <= k.created_at + interval \'7 days\') as within\n'
    || E'    from public.case_tasks k join public.cases c on c.id = k.case_id, params p\n'
    || E'    where k.kind = \'inform_gp\' and c.assigned_team_id in (select id from my_teams)\n'
    || E'      and (k.created_at at time zone \'Europe/Zurich\')::date >= p.m0 and (k.created_at at time zone \'Europe/Zurich\')::date < p.m1\n'
    || E'  ), m10o as (\n'
    || E'    select g.organization_id, g.team_id, \'order_open_end_ending\'::text as measure, k.code as detail,\n'
    || E'           round(100.0 * (select count(*) from ord0_episodes x where x.organization_id = g.organization_id\n'
    || E'                            and x.team_id is not distinct from g.team_id and x.ending = k.code) / g.n, 1) as value,\n'
    || E'           g.n::int as base\n'
    || E'    from (select x.organization_id, x.team_id, count(*) as n from ord0_episodes x\n'
    || E'          group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))) g\n'
    || E'    cross join ord0_endings k\n'
    || E'    union all\n'
    || E'    select x.organization_id, x.team_id, \'inform_gp_done_within_7d_share\', null,\n'
    || E'           round(100.0 * count(*) filter (where x.within) / count(*), 1), count(*)::int\n'
    || E'    from ord0_tasks x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n'
    || E'  ),\n  computed as (',
    '1',
    E'    union all select * from m10s\n',
    E'    union all select * from m10s\n    union all select * from m10o\n',
    '1',
    E'(''signal_taken_share'', null), (''signal_minutes_to_take'', null)\n',
    E'(''signal_taken_share'', null), (''signal_minutes_to_take'', null),\n'
    || E'           -- ORD0-6\n'
    || E'           (''order_open_end_ending'', ''end_date_entered''), (''order_open_end_ending'', ''order_not_present''),\n'
    || E'           (''order_open_end_ending'', ''no_b_item''), (''order_open_end_ending'', ''case_not_active''),\n'
    || E'           (''order_open_end_ending'', ''still_open''), (''inform_gp_done_within_7d_share'', null)\n',
    '1',
    E'              when r.measure = ''followup_without_visit_share''\n',
    E'              when r.measure = ''order_open_end_ending''\n'
    || E'                then ''Wie «Verordnung ohne Enddatum» endet. Ob eine Verordnung ohne Enddatum zulässig ist, ist offen (D-22).''\n'
    || E'              when r.measure = ''inform_gp_done_within_7d_share''\n'
    || E'                then ''Evidenz für D-22, keine Frist: Aufgaben «Hausärztin/Hausarzt informieren», die innerhalb von 7 Tagen mit «informiert» erledigt wurden.''\n'
    || E'              when r.measure = ''followup_without_visit_share''\n',
    '1'],
  'ORD0-6');

drop function private.ord0_patch(text, text[], text);
