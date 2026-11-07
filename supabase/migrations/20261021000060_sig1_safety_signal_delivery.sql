-- SIG1: safety signals reach a person, nobody watches a screen (brief `docs/agents/briefs/SIG1.md`, ADR-074).
-- CGR-37 (advisory S2, `reports/CLINICAL_GOVERNANCE.md` 2026-10-24 02:26); remediation plan `clinical/remediation/CGR-37.md`.
--
-- What this adds (no threshold, no priority and no hand-close rule changes: CR-038 to CR-041, CR-049, CR-053 unchanged):
--   * `public.safety_signals`: one row per P1 episode of a visit safety signal (an exception key that is P1 by the
--     effective rule, continuously). A signal that ends (cause gone, or no longer P1) gets `ended_at`; when the same
--     key comes back later it is a new episode with new delivery rows (SIG1-2).
--   * `public.signal_deliveries`: one row per recipient and episode: kind, visit, recipient, reason, created time.
--     No client name, no free text, no health data (SIG1-1).
--   * `private.evaluate_signals(org, force)`: the writer. It reads `private.derived_exceptions` and
--     `private.effective_exception_rules` (no second copy of a threshold, SIG1-9), opens, ends and escalates episodes.
--     Runs every minute through pg_cron where available, and on every poll of `/field`, `/team` and OPS1
--     (`public.my_signals`, throttled to once per 15 s per organisation), the OPS1 sync pattern.
--   * `public.take_signal(signal, key)`: "Ich übernehme" (SIG1-4). Audited, idempotent; a second tap is `duplicate`;
--     a non-recipient is `rejected`. Taking does not end the signal: it stays open until its cause ends (CR-041).
--   * Rule `signal_untaken` (operating rule, ADM1): an untaken P1 is delivered to Operations as well, once, after the
--     threshold (strict default 15 minutes, PROVISIONAL until D-28; direction `delay`, so an organisation may set it
--     shorter, never longer: the ADM1-R range guard) (SIG1-5). Unit `minutes` is new for operating rules.
--   * AN2 measure 10 gains `signal_taken_share` and `signal_minutes_to_take` per team and organisation (SIG1-6).
--
-- Signals delivered (PO brief): visit_overdue → "Einsatz überfällig", visit_stuck → "Einsatz hängt",
-- visit_uncovered and visit_uncovered_hospital → "Einsatz ohne Zuständige", visit_interrupted → "Einsatz abgebrochen",
-- no_show_open → "Klientin öffnet nicht". Each only while it is P1 by the effective rule (P2 and P3 stay pull-only).
-- `cover_without_access` is not delivered (not in the brief's list; deviation recorded, ADR-074).
--
-- Recipients (SIG1-1, SIG1-7; CGR-21: the owning team also for a covered visit):
--   * the responsible member: `responsible_user_id`, or the covering member (`covered_by`) of a covered visit,
--     if she is still a member of the owning team or is the covering member of the same organisation;
--   * every member of the owning team;
--   * nobody who is absent now (ABS1, `private.member_absent_during`): an absent member is not on duty;
--   * if that leaves nobody: the organisation's Operations users (role `operations`; if the organisation has none,
--     its admins). A coach without team membership receives nothing; a removed member, a client or a partner account
--     is never a team member and receives nothing.
--
-- No clinical, tariff or legal rule is invented. RLS on, column grants only, audit triggers, idempotent commands.

-- 1. Operating rule: signal_untaken (minutes) -----------------------------------------------------------------------
alter table public.exception_rules drop constraint if exists exception_rules_unit_check;
alter table public.exception_rules add constraint exception_rules_unit_check
  check (unit is null or unit in ('minutes', 'hours', 'days', 'working_days'));

create or replace function private.after_threshold(p_from timestamptz, p_amount integer, p_unit text)
returns timestamptz
language sql stable set search_path = ''
as $$
  select case
    when p_amount is null or p_amount = 0 then p_from
    when p_unit = 'working_days' then private.add_working_time(p_from, p_amount, 'working_days')
    when p_unit = 'days' then p_from + make_interval(days => p_amount)
    when p_unit = 'minutes' then p_from + make_interval(mins => p_amount)
    else p_from + make_interval(hours => p_amount) end
$$;

insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step, amount_direction)
values ('signal_untaken', 'P1', 15, 'minutes', null,
        'P1-Sicherheitssignal nicht übernommen (provisorisch, D-28)',
        'Operations erhält das Signal zusätzlich; jemand übernimmt mit «Ich übernehme».', 'delay')
on conflict (exception_type) do nothing;

-- 2. Tables -----------------------------------------------------------------------------------------------------------
create table if not exists public.safety_signals (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id),
  -- No foreign key to care_visits: a signal is a record and survives a removed planned visit (PLAN2, remove_planned_visit).
  visit_id        uuid not null,
  signal_kind     text not null check (signal_kind in ('visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_interrupted', 'no_show')),
  exception_key   text not null,
  p1_at           timestamptz not null,
  created_at      timestamptz not null default now(),
  ended_at        timestamptz,
  taken_by        uuid,
  taken_at        timestamptz,
  escalated_at    timestamptz,
  check ((taken_by is null) = (taken_at is null))
);
create unique index if not exists safety_signals_one_open on public.safety_signals (organization_id, exception_key) where ended_at is null;
create index if not exists safety_signals_visit on public.safety_signals (visit_id);
create index if not exists safety_signals_team_created on public.safety_signals (team_id, created_at);

comment on table public.safety_signals is
  'SIG1: one row per P1 episode of a visit safety signal (an exception key that is P1 by the effective rule). Written only by private.evaluate_signals; taken through take_signal. No client name, no free text, no health data.';

create table if not exists public.signal_deliveries (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  signal_id       uuid not null references public.safety_signals (id),
  recipient_id    uuid not null,
  reason          text not null check (reason in ('responsible', 'team', 'operations_fallback', 'untaken')),
  signal_kind     text not null,
  visit_id        uuid not null,
  created_at      timestamptz not null default now(),
  unique (signal_id, recipient_id)
);
create index if not exists signal_deliveries_recipient on public.signal_deliveries (recipient_id, created_at);

comment on table public.signal_deliveries is
  'SIG1-1: one row per recipient of a P1 safety signal: kind, visit, recipient, reason, created time. Never updated or deleted.';

-- Guards: a delivery never changes; a signal changes only once per field (ended, taken, escalated), nothing else.
create or replace function private.guard_signal_delivery()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'signal deliveries are never changed or deleted' using errcode = '42501';
end;
$$;

create or replace function private.guard_safety_signal()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'safety signals are never deleted' using errcode = '42501';
  end if;
  if (new.id, new.organization_id, new.team_id, new.visit_id, new.signal_kind, new.exception_key, new.p1_at, new.created_at)
     is distinct from (old.id, old.organization_id, old.team_id, old.visit_id, old.signal_kind, old.exception_key, old.p1_at, old.created_at)
     or (old.ended_at is not null and new.ended_at is distinct from old.ended_at)
     or (old.taken_by is not null and (new.taken_by, new.taken_at) is distinct from (old.taken_by, old.taken_at))
     or (old.escalated_at is not null and new.escalated_at is distinct from old.escalated_at) then
    raise exception 'a safety signal records end, take and escalation once; nothing else changes' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_signal_deliveries on public.signal_deliveries;
create trigger guard_signal_deliveries before update or delete on public.signal_deliveries
  for each row execute function private.guard_signal_delivery();
drop trigger if exists guard_safety_signals on public.safety_signals;
create trigger guard_safety_signals before update or delete on public.safety_signals
  for each row execute function private.guard_safety_signal();

drop trigger if exists audit_safety_signals on public.safety_signals;
create trigger audit_safety_signals after insert or update on public.safety_signals
  for each row execute function private.write_audit_event('signal_kind', 'ended_at', 'taken_by', 'taken_at', 'escalated_at');
drop trigger if exists audit_signal_deliveries on public.signal_deliveries;
create trigger audit_signal_deliveries after insert on public.signal_deliveries
  for each row execute function private.write_audit_event('recipient_id', 'reason', 'signal_kind');

-- RLS: a person reads only her own deliveries and the signals delivered to her. No writes by users.
alter table public.safety_signals enable row level security;
alter table public.signal_deliveries enable row level security;
revoke all on public.safety_signals from public, anon, authenticated;
revoke all on public.signal_deliveries from public, anon, authenticated;
grant select (id, organization_id, team_id, visit_id, signal_kind, p1_at, created_at, ended_at, taken_by, taken_at, escalated_at)
  on public.safety_signals to authenticated;
grant select (id, organization_id, signal_id, recipient_id, reason, signal_kind, visit_id, created_at)
  on public.signal_deliveries to authenticated;

drop policy if exists signal_deliveries_own on public.signal_deliveries;
create policy signal_deliveries_own on public.signal_deliveries for select to authenticated
  using (recipient_id = (select auth.uid()) and private.is_org_member(organization_id));
drop policy if exists safety_signals_delivered on public.safety_signals;
create policy safety_signals_delivered on public.safety_signals for select to authenticated
  using (exists (select 1 from public.signal_deliveries d
                 where d.signal_id = safety_signals.id and d.recipient_id = (select auth.uid())));

-- Throttle for the poll path (cron and tests force).
create table if not exists private.signal_evaluations (
  organization_id uuid primary key,
  evaluated_at    timestamptz not null
);
revoke all on private.signal_evaluations from public, anon, authenticated;

-- 3. Writer -----------------------------------------------------------------------------------------------------------
create or replace function private.signal_kind_of(p_exception_type text)
returns text language sql immutable set search_path = ''
as $$
  select case p_exception_type
    when 'visit_overdue' then 'visit_overdue'
    when 'visit_stuck' then 'visit_stuck'
    when 'visit_uncovered' then 'visit_uncovered'
    when 'visit_uncovered_hospital' then 'visit_uncovered'
    when 'visit_interrupted' then 'visit_interrupted'
    when 'no_show_open' then 'no_show'
  end
$$;

-- Operations users of an organisation (role operations; admins only when it has none). Never a coach.
create or replace function private.signal_operations_users(p_org uuid)
returns setof uuid language sql stable security definer set search_path = ''
as $$
  select m.user_id from public.organization_memberships m
  where m.organization_id = p_org and m.role = 'operations'
  union
  select m.user_id from public.organization_memberships m
  where m.organization_id = p_org and m.role = 'admin'
    and not exists (select 1 from public.organization_memberships o where o.organization_id = p_org and o.role = 'operations')
$$;

-- SIG1-1 / SIG1-7: who receives a signal now.
create or replace function private.signal_recipients(p_signal_id uuid)
returns table (user_id uuid, reason text)
language sql stable security definer set search_path = ''
as $$
  with s as (
    select s.*, v.responsible_user_id, v.covered_by
    from public.safety_signals s join public.care_visits v on v.id = s.visit_id
    where s.id = p_signal_id
  ), responsible as (
    select coalesce(s.responsible_user_id, s.covered_by) as user_id, s.team_id, s.organization_id from s
  ), direct as (
    -- the responsible member: still in the owning team, or the covering member of the same organisation
    select r.user_id, 'responsible'::text as reason from responsible r
    where r.user_id is not null
      and (exists (select 1 from public.team_memberships tm where tm.team_id = r.team_id and tm.user_id = r.user_id)
           or exists (select 1 from s join public.organization_memberships om
                        on om.organization_id = s.organization_id and om.user_id = s.covered_by
                      where s.covered_by = r.user_id))
      and not private.member_absent_during(r.team_id, r.user_id, now(), null)
    union
    -- every member of the owning team who is not absent now
    select tm.user_id, 'team' from s join public.team_memberships tm on tm.team_id = s.team_id
    where not private.member_absent_during(s.team_id, tm.user_id, now(), null)
  ), direct_one as (
    select distinct on (d.user_id) d.user_id, d.reason from direct d
    order by d.user_id, case d.reason when 'responsible' then 0 else 1 end
  )
  select d.user_id, d.reason from direct_one d
  union all
  select o, 'operations_fallback' from s, private.signal_operations_users(s.organization_id) o
  where not exists (select 1 from direct_one)
$$;

do $$
begin
  if to_regtype('private.sig1_current_signal') is null then
    create type private.sig1_current_signal as (exception_key text, exception_type text, visit_id uuid, team_id uuid, p1_at timestamptz);
  end if;
end;
$$;

create or replace function private.evaluate_signals(p_org uuid, p_force boolean default false)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  n       integer := 0;
  k       integer;
  untaken record;
  fresh_ids uuid[];
  cur     private.sig1_current_signal[];
begin
  if p_org is null then return 0; end if;
  -- One evaluation per organisation at a time; a concurrent one has the same result, so skip instead of waiting.
  if not pg_try_advisory_xact_lock(hashtext('navora.sig1'), hashtext(p_org::text)) then return 0; end if;
  if not p_force and exists (select 1 from private.signal_evaluations e
                             where e.organization_id = p_org and e.evaluated_at > now() - interval '15 seconds') then
    return 0;
  end if;
  insert into private.signal_evaluations (organization_id, evaluated_at) values (p_org, now())
  on conflict (organization_id) do update set evaluated_at = excluded.evaluated_at;
  -- System writes: no command, no key (audit records actor null).
  perform set_config('navora.command', 'evaluate_signals', true);
  perform set_config('navora.idempotency_key', '', true);

  -- The P1 visit safety signals now, read once (a variable, not a temporary table: lint-safe).
  select coalesce(array_agg(x), '{}') into cur from (
    select distinct on (d.exception_key)
           row(d.exception_key, d.exception_type, d.entity_id, d.team_id,
               case when r.priority = 'P1' then d.since else d.since + make_interval(hours => r.escalate_to_p1_after_hours) end
              )::private.sig1_current_signal as x
    from private.derived_exceptions(p_org) d
  join private.effective_exception_rules(p_org) r on r.exception_type = d.exception_type
  where private.signal_kind_of(d.exception_type) is not null
    and d.entity_type = 'visit' and d.entity_id is not null and d.team_id is not null
    and (r.priority = 'P1'
         or (r.escalate_to_p1_after_hours is not null and now() >= d.since + make_interval(hours => r.escalate_to_p1_after_hours)))
    order by d.exception_key) q;

  -- An episode ends when its key is no longer P1 (cause gone, or the rule changed).
  update public.safety_signals s set ended_at = now()
  where s.organization_id = p_org and s.ended_at is null
    and not exists (select 1 from unnest(cur) c where c.exception_key = s.exception_key);
  get diagnostics k = row_count; n := n + k;

  -- New episodes, then their deliveries (exactly once: the open-key index and the delivery key).
  -- Two statements: rows inserted by a data-modifying CTE are not visible to private.signal_recipients.
  with fresh as (
    insert into public.safety_signals (organization_id, team_id, visit_id, signal_kind, exception_key, p1_at)
    select p_org, c.team_id, c.visit_id, private.signal_kind_of(c.exception_type), c.exception_key, c.p1_at
    from unnest(cur) c
    where not exists (select 1 from public.safety_signals s
                      where s.organization_id = p_org and s.exception_key = c.exception_key and s.ended_at is null)
    on conflict (organization_id, exception_key) where ended_at is null do nothing
    returning id
  )
  select coalesce(array_agg(f.id), '{}') into fresh_ids from fresh f;

  insert into public.signal_deliveries (organization_id, signal_id, recipient_id, reason, signal_kind, visit_id)
  select p_org, s.id, r.user_id, r.reason, s.signal_kind, s.visit_id
  from public.safety_signals s cross join lateral private.signal_recipients(s.id) r
  where s.id = any (fresh_ids)
  on conflict (signal_id, recipient_id) do nothing;
  get diagnostics k = row_count; n := n + k;

  -- SIG1-5: untaken after the organisation's threshold → Operations as well, once.
  for untaken in
    select s.id, s.visit_id, s.signal_kind
    from public.safety_signals s
    cross join lateral (select r.amount, r.unit from private.effective_exception_rules(p_org) r
                        where r.exception_type = 'signal_untaken') t
    where s.organization_id = p_org and s.ended_at is null and s.taken_by is null and s.escalated_at is null
      and now() >= private.after_threshold(s.created_at, t.amount, t.unit)
    for update of s skip locked
  loop
    insert into public.signal_deliveries (organization_id, signal_id, recipient_id, reason, signal_kind, visit_id)
    select p_org, untaken.id, o, 'untaken', untaken.signal_kind, untaken.visit_id
    from private.signal_operations_users(p_org) o
    on conflict (signal_id, recipient_id) do nothing;
    update public.safety_signals set escalated_at = now() where id = untaken.id;
    n := n + 1;
  end loop;

  perform set_config('navora.command', '', true);
  return n;
end;
$$;

create or replace function private.evaluate_all_signals()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  n   integer := 0;
  org uuid;
begin
  for org in select o.id from public.organizations o order by o.id loop
    n := n + private.evaluate_signals(org, true);
  end loop;
  return n;
end;
$$;

revoke all on function private.signal_kind_of(text) from public, anon, authenticated;
revoke all on function private.signal_operations_users(uuid) from public, anon, authenticated;
revoke all on function private.signal_recipients(uuid) from public, anon, authenticated;
revoke all on function private.evaluate_signals(uuid, boolean) from public, anon, authenticated;
revoke all on function private.evaluate_all_signals() from public, anon, authenticated;
revoke all on function private.guard_signal_delivery() from public, anon, authenticated;
revoke all on function private.guard_safety_signal() from public, anon, authenticated;

-- Every minute through pg_cron where available; otherwise the poll of the open pages evaluates (notice, nothing fails).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      execute $cron$select cron.schedule('navora-sig1-signals', '* * * * *', 'select private.evaluate_all_signals()')$cron$;
    exception when others then
      raise notice 'SIG1: signal job not scheduled (%); the page poll evaluates', sqlerrm;
    end;
  else
    raise notice 'SIG1: pg_cron not available; the page poll evaluates';
  end if;
end;
$$;

-- 4. Reader and command -----------------------------------------------------------------------------------------------
-- SIG1-3: the caller's open P1 signals (evaluated first, throttled), newest first. Fixed kinds only; the UI maps the
-- text. `taken_by_name` is the colleague's display name (team context), never the client's.
create or replace function public.my_signals()
returns table (signal_id uuid, signal_kind text, visit_id uuid, visit_date date, time_start time, team_id uuid,
               team_name text, reason text, delivered_at timestamptz, p1_at timestamptz,
               taken_by_me boolean, taken_by_name text, taken_at timestamptz)
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null then return; end if;
  for org in select distinct om.organization_id from public.organization_memberships om where om.user_id = uid loop
    perform private.evaluate_signals(org, false);
  end loop;
  return query
    select s.id, s.signal_kind, s.visit_id, v.visit_date, v.time_start, s.team_id, t.name, d.reason, d.created_at, s.p1_at,
           coalesce(s.taken_by = uid, false),
           case when s.taken_by is not null
                then coalesce(private.member_name(s.organization_id, s.taken_by), 'Teammitglied') end,
           s.taken_at
    from public.signal_deliveries d
    join public.safety_signals s on s.id = d.signal_id
    join public.care_visits v on v.id = s.visit_id
    join public.teams t on t.id = s.team_id
    where d.recipient_id = uid and s.ended_at is null and private.is_org_member(d.organization_id)
    order by (s.taken_by is null) desc, d.created_at desc, s.id;
end;
$$;
revoke all on function public.my_signals() from public, anon;
grant execute on function public.my_signals() to authenticated;

-- SIG1-4: "Ich übernehme". Returns {result: ok|duplicate|rejected, reason?, taken_by_name?}.
create or replace function public.take_signal(p_signal_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  s   public.safety_signals%rowtype;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_recipient'); end if;
  if private.begin_command('take_signal', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  select * into s from public.safety_signals where id = p_signal_id for update;
  if s.id is null or not exists (select 1 from public.signal_deliveries d where d.signal_id = s.id and d.recipient_id = uid)
     or not private.is_org_member(s.organization_id) then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'not_recipient');
  end if;
  if s.taken_by is not null then
    return jsonb_build_object('result', private.end_command('duplicate'),
                              'taken_by_name', coalesce(private.member_name(s.organization_id, s.taken_by), 'Teammitglied'));
  end if;
  if s.ended_at is not null then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'signal_ended');
  end if;
  update public.safety_signals set taken_by = uid, taken_at = now() where id = s.id;
  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.take_signal(uuid, uuid) from public, anon;
grant execute on function public.take_signal(uuid, uuid) to authenticated;

-- 5. AN2 measure 10 (SIG1-6): share of P1 signals taken, median minutes from P1 to taken; per team and organisation,
--    never per nurse; AN1 suppression applies through the existing final select.
create function private.sig1_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'SIG1 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

select private.sig1_patch('public.pilot_hypotheses(date)', array[
  E'  ),\n  computed as (',
  E'  ), sig1_episodes as (\n'
  || E'    select s.organization_id, s.team_id, s.taken_at, s.p1_at\n'
  || E'    from public.safety_signals s, params p\n'
  || E'    where s.team_id in (select id from my_teams)\n'
  || E'      and (s.created_at at time zone ''Europe/Zurich'')::date >= p.m0 and (s.created_at at time zone ''Europe/Zurich'')::date < p.m1\n'
  || E'  ), m10s as (\n'
  || E'    select x.organization_id, x.team_id, ''signal_taken_share''::text as measure, null::text as detail,\n'
  || E'           round(100.0 * count(*) filter (where x.taken_at is not null) / count(*), 1) as value, count(*)::int as base\n'
  || E'    from sig1_episodes x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n'
  || E'    union all\n'
  || E'    select x.organization_id, x.team_id, ''signal_minutes_to_take'', null,\n'
  || E'           round((percentile_cont(0.5) within group (order by greatest(0, extract(epoch from (x.taken_at - x.p1_at)) / 60)))::numeric, 1),\n'
  || E'           count(*)::int\n'
  || E'    from sig1_episodes x where x.taken_at is not null group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n'
  || E'  ),\n  computed as (',
  E'    union all select * from m10\n',
  E'    union all select * from m10\n    union all select * from m10s\n',
  E'(''stuck_ended_by_command_share'', null), (''stuck_closed_by_hand_share'', null)\n',
  E'(''stuck_ended_by_command_share'', null), (''stuck_closed_by_hand_share'', null),\n           -- SIG1-6\n           (''signal_taken_share'', null), (''signal_minutes_to_take'', null)\n',
  E'''stuck_ended_by_command_share'', ''stuck_closed_by_hand_share'')',
  E'''stuck_ended_by_command_share'', ''stuck_closed_by_hand_share'', ''signal_taken_share'', ''signal_minutes_to_take'')'
]);

drop function private.sig1_patch(text, text[]);
