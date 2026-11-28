-- LEAVE1 part (a): access ends when employment ends (PO brief docs/agents/briefs/LEAVE1.md, ADR-087).
--
-- Scope of this migration (part a): LEAVE1-1 command, LEAVE1-2 refusals, LEAVE1-3 reads and commands, LEAVE1-4 history
-- kept, LEAVE1-7 restore, LEAVE1-8 the record readable by administrators. Part (b), a later migration: LEAVE1-5 team
-- marker, LEAVE1-6 leaver screen, LEAVE1-11 return when the performer is unavailable, LEAVE1-12 open-work list.
--
-- Design (answers to the brief's engineering questions):
-- 1. The fact lives in its own append-only table `member_access_events` (kind `ended` | `restored`, reason code, actor,
--    time), per organisation membership. The current state is the newest event per (organisation, person).
--    `private.access_ended(user)` is one index probe; it is true while the newest event of ANY of her organisation
--    memberships is `ended` (a person in two organisations loses both: privacy first; no such person exists in the
--    pilot data model today, recorded as a deviation in ADR-087).
-- 2. Reads: every table the `authenticated` role can read gets a RESTRICTIVE policy `leave1_access_open`, so no
--    permissive policy, present or future, returns a row to her (except her own notice rows in
--    member_access_events). The membership helpers (`is_org_member`, `has_org_role` and so `is_org_admin`,
--    `is_team_member`) and `cover_team_for` return false for her, which closes the SECURITY DEFINER read models that
--    rely on them. Read models that do not (found by the pgTAP catalogue check 074) get an explicit guard here.
-- 3. Commands: `private.begin_command` raises `access_ended` (42501) for her; the plpgsql commands that do not use it
--    get the same guard at their start. Visit transitions (start, depart, pause, resume, complete) go through
--    `private.transition_visit`, which calls begin_command.
-- 4. Signals and push: she is in no SIG1 receiver set (`signal_recipients`, `signal_operations_users`); her stored push
--    subscriptions are deleted at access end (audited, as `unregister_push_subscription` does); after a restore the
--    app asks her to subscribe again.
-- 5. History: nothing is deleted except her push subscriptions. Memberships, reports, signatures, audit events and
--    analytics contributions stay; the auth.users row is never touched.
-- Idempotent commands, audited (actor, person, code, time) in audit_events and change_log. No free text.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.leave1_patch(p_fn text, p_pairs text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]);
    if n <> p_pairs[i + 2]::integer then
      raise exception '0074 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0074 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.leave1_patch(text, text[], text) from public, anon, authenticated;

-- 1. The append-only record (LEAVE1-1, LEAVE1-4, LEAVE1-8) --------------------------------------------------------------
create table if not exists public.member_access_events (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  organization_id uuid not null,
  user_id         uuid not null,
  kind            text not null check (kind in ('ended', 'restored')),
  reason_code     text not null,
  actor_id        uuid not null,
  created_at      timestamptz not null default private.now(),
  foreign key (organization_id, user_id) references public.organization_memberships (organization_id, user_id),
  check ((kind = 'ended' and reason_code in ('employment_ended', 'access_withdrawn'))
      or (kind = 'restored' and reason_code in ('employment_resumed', 'ended_in_error'))),
  check (actor_id <> user_id)
);
create index if not exists member_access_events_user_idx on public.member_access_events (user_id, organization_id, seq);
create index if not exists member_access_events_org_idx on public.member_access_events (organization_id, created_at);
comment on table public.member_access_events is
  'LEAVE1: access ended / restored per organisation membership. Append-only, written only by end_member_access and '
  'restore_member_access. Organisational fact, no health data, no free text. Readable by the organisation''s '
  'administrators and by the person herself (her access-ended notice); the team sees only the marker (part b). '
  'No analytics, billing, export or push function reads reason_code (LEAVE1-8, pgTAP 074).';
comment on column public.member_access_events.reason_code is
  'ended: employment_ended | access_withdrawn (brief). restored: employment_resumed | ended_in_error (engineering '
  'default, ADR-087; PO may rename).';

alter table public.member_access_events enable row level security;
revoke all on public.member_access_events from public, anon, authenticated, service_role;
grant select on public.member_access_events to authenticated;
drop policy if exists access_events_admin_or_self_read on public.member_access_events;
create policy access_events_admin_or_self_read on public.member_access_events
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_org_admin(organization_id));

create or replace function private.guard_member_access_event()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'member_access_events is append-only' using errcode = '42501';
end;
$$;
revoke all on function private.guard_member_access_event() from public, anon, authenticated;
drop trigger if exists member_access_events_guard on public.member_access_events;
create trigger member_access_events_guard
  before update or delete on public.member_access_events
  for each row execute function private.guard_member_access_event();
drop trigger if exists member_access_events_no_truncate on public.member_access_events;
create trigger member_access_events_no_truncate
  before truncate on public.member_access_events
  for each statement execute function private.guard_member_access_event();
drop trigger if exists audit_member_access_events on public.member_access_events;
create trigger audit_member_access_events
  after insert on public.member_access_events
  for each row execute function private.write_audit_event('user_id', 'kind', 'reason_code', 'actor_id');

-- 2. The helper ------------------------------------------------------------------------------------------------------------
create or replace function private.access_ended(p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select p_user is not null and exists (
    select 1 from public.member_access_events e
    where e.user_id = p_user and e.kind = 'ended'
      and not exists (select 1 from public.member_access_events l
                      where l.user_id = e.user_id and l.organization_id = e.organization_id and l.seq > e.seq))
$$;
revoke all on function private.access_ended(uuid) from public, anon;
grant execute on function private.access_ended(uuid) to authenticated;
comment on function private.access_ended(uuid) is
  'LEAVE1: true while the newest access event of any of the person''s organisation memberships is `ended`.';

create or replace function private.assert_access_open()
returns void language plpgsql stable security definer set search_path = ''
as $$
begin
  if private.access_ended((select auth.uid())) then
    raise exception 'access_ended' using errcode = '42501';
  end if;
end;
$$;
revoke all on function private.assert_access_open() from public, anon;
grant execute on function private.assert_access_open() to authenticated;

-- 3. Membership helpers return false for her (LEAVE1-3) -------------------------------------------------------------------
create or replace function private.is_org_member(org uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = org and m.user_id = (select auth.uid())
  ) and not private.access_ended((select auth.uid()));  -- LEAVE1-3
$$;

create or replace function private.has_org_role(org uuid, roles text[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = org and m.user_id = (select auth.uid()) and m.role = any (roles)
  ) and not private.access_ended((select auth.uid()));  -- LEAVE1-3
$$;

create or replace function private.is_team_member(team uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.team_memberships tm
    where tm.team_id = team and tm.user_id = (select auth.uid())
  ) and not private.access_ended((select auth.uid()));  -- LEAVE1-3
$$;

select private.leave1_patch('private.cover_team_for(public.care_visits, uuid)', array[
  E'where m.user_id = p_user and',
  E'where m.user_id = p_user and not private.access_ended(p_user) /* LEAVE1-3 */ and',
  '1'], 'LEAVE1-3');

-- SIG1 receiver sets: never her (LEAVE1-3). An Operations user whose access ended does not count as Operations.
create or replace function private.signal_operations_users(p_org uuid)
returns setof uuid language sql stable security definer set search_path = ''
as $$
  select m.user_id from public.organization_memberships m
  where m.organization_id = p_org and m.role = 'operations' and not private.access_ended(m.user_id)  -- LEAVE1-3
  union
  select m.user_id from public.organization_memberships m
  where m.organization_id = p_org and m.role = 'admin' and not private.access_ended(m.user_id)
    and not exists (select 1 from public.organization_memberships o
                    where o.organization_id = p_org and o.role = 'operations' and not private.access_ended(o.user_id))
$$;

select private.leave1_patch('private.signal_recipients(uuid)', array[
  E'select distinct on (d.user_id) d.user_id, d.reason from direct d\n',
  E'select distinct on (d.user_id) d.user_id, d.reason from direct d where not private.access_ended(d.user_id) /* LEAVE1-3 */\n',
  '1'], 'LEAVE1-3');

select private.leave1_patch('private.push_active(uuid)', array[
  E's.last_result = ''sent'')',
  E's.last_result = ''sent'') and not private.access_ended(p_user) /* LEAVE1-3 */',
  '1'], 'LEAVE1-3');

-- 4. Commands are refused (LEAVE1-3) ----------------------------------------------------------------------------------------
select private.leave1_patch('private.begin_command(text, uuid)', array[
  E'  -- Transaction-local; read by private.write_audit_event().\n',
  E'  -- LEAVE1-3: a person whose access ended runs no command.\n  perform private.assert_access_open();\n'
  || E'  -- Transaction-local; read by private.write_audit_event().\n',
  '1'], 'LEAVE1-3');

do $$
declare
  fn text;
begin
  -- plpgsql commands that do not go through begin_command (catalogue check 074 lists them all).
  foreach fn in array array[
    'public.correct_visit_time(bigint, timestamptz, text, uuid)',
    'public.record_observation(uuid, text, boolean, uuid, uuid)',
    'public.decide_matching_request(uuid, uuid, text, text, uuid, text)',
    'public.handle_exception(text, text, text, uuid)',
    'public.sync_exceptions()',
    'public.set_quality_event_status(uuid, text, text, uuid)',
    'public.generate_billable_facts(date)',
    'public.refresh_team_plans()',
    'public.sync_cover_offers()',
    'public.accept_my_invitations()',
    'public.record_push_tap()']
  loop
    perform private.leave1_patch(fn, array[
      E'\nbegin\n', E'\nbegin\n  perform private.assert_access_open();  -- LEAVE1-3\n', '1'], 'LEAVE1-3');
  end loop;
end;
$$;

-- my_signals is a volatile read model (it records the delivery as seen): she gets no rows.
select private.leave1_patch('public.my_signals()', array[
  E'\nbegin\n', E'\nbegin\n  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3\n', '1'], 'LEAVE1-3');

-- 4b. SECURITY DEFINER read models (they bypass RLS): she gets no rows (LEAVE1-3) -----------------------------------------
-- Every set-returning SQL read model in `public` that runs as its owner and that `authenticated` may call is rewritten
-- as plpgsql with the same signature, result, volatility and body: it returns nothing while her access is ended, and
-- otherwise `return query` runs the unchanged body (row order kept). `#variable_conflict use_column` keeps the SQL
-- rule that a column name wins over a parameter or result-column name. The catalogue check in pgTAP 074 asserts that
-- no such read model is left without the guard, so a new one cannot slip through.
do $$
declare
  f    record;
  body text;
begin
  for f in
    select p.oid, p.proname, p.provolatile, p.prosrc
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname = 'public' and p.prokind = 'f' and p.prosecdef and p.proretset and l.lanname = 'sql'
      and has_function_privilege('authenticated', p.oid, 'execute')
    order by p.proname
  loop
    body := regexp_replace(btrim(f.prosrc, E' \n\t'), ';\s*$', '');
    -- A second statement would fail the plpgsql syntax check here (a `;` in a comment or literal is fine).
    execute format(
      'create or replace function public.%I(%s) returns %s language plpgsql %s security definer set search_path = '''' as %L',
      f.proname, pg_get_function_arguments(f.oid), pg_get_function_result(f.oid),
      case f.provolatile when 'i' then 'immutable' when 's' then 'stable' else 'volatile' end,
      E'#variable_conflict use_column\nbegin\n'
      || E'  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3\n'
      || E'  return query\n' || body || E';\nend\n');
  end loop;
end;
$$;

-- 5. Reads: one restrictive policy on every table `authenticated` can read (LEAVE1-3) ---------------------------------------
do $$
declare
  t text;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and c.relrowsecurity
      and has_any_column_privilege('authenticated', c.oid, 'select')
    order by 1
  loop
    execute format('drop policy if exists leave1_access_open on public.%I', t);
    if t = 'member_access_events' then
      execute format('create policy leave1_access_open on public.%I as restrictive for all to authenticated '
                     'using (user_id = (select auth.uid()) or not (select private.access_ended((select auth.uid()))))', t);
    else
      execute format('create policy leave1_access_open on public.%I as restrictive for all to authenticated '
                     'using (not (select private.access_ended((select auth.uid()))))', t);
    end if;
  end loop;
end;
$$;

-- 6. Commands -------------------------------------------------------------------------------------------------------------
-- The organisation in which the caller administers the person (null when none: another organisation, or not admin).
create or replace function private.leave1_org_for(p_user uuid)
returns uuid language sql stable security definer set search_path = ''
as $$
  select m.organization_id from public.organization_memberships m
  where m.user_id = p_user and private.is_org_admin(m.organization_id)
  order by m.organization_id
  limit 1
$$;
revoke all on function private.leave1_org_for(uuid) from public, anon, authenticated;

-- LEAVE1-1 / LEAVE1-2. Return: {"result": "ok" | "unchanged" | "duplicate" | "rejected" | "self" | "last_admin"
--   | "has_cases" | "has_planned_visits" | "has_visit_in_progress", "push_subscriptions_removed"?: n}
-- Not refused by her unsigned reports, correction drafts or returned reports (only she can clear those).
create or replace function public.end_member_access(p_user_id uuid, p_reason_code text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  org   uuid;
  role_ text;
  today date := (private.at_zurich(private.now()))::date;
  r     record;
  subs  integer := 0;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_reason_code is null or p_reason_code not in ('employment_ended', 'access_withdrawn') then
    raise exception 'reason code must be employment_ended or access_withdrawn' using errcode = '22023';
  end if;
  if private.begin_command('end_member_access', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if p_user_id is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if p_user_id = uid then
    return jsonb_build_object('result', private.end_command('self'));
  end if;
  org := private.leave1_org_for(p_user_id);
  if org is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  select m.role into role_ from public.organization_memberships m
    where m.organization_id = org and m.user_id = p_user_id for update;
  if private.access_ended(p_user_id) then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;
  -- ADM1 rule: the organisation keeps at least one administrator with access.
  if role_ = 'admin' and (select count(*) from public.organization_memberships m
                          where m.organization_id = org and m.role = 'admin' and m.user_id <> p_user_id
                            and not private.access_ended(m.user_id)) < 1 then
    return jsonb_build_object('result', private.end_command('last_admin'));
  end if;
  -- LEAVE1-2: refused while someone else can clear the state (re-assign; the existing close path).
  if exists (select 1 from public.cases c join public.teams t on t.id = c.assigned_team_id
             where t.organization_id = org and c.lifecycle <> 'closed'
               and p_user_id in (c.primary_nurse_id, c.deputy_nurse_id)) then
    return jsonb_build_object('result', private.end_command('has_cases'));
  end if;
  if exists (select 1 from public.care_visits v
             where v.organization_id = org and v.status in ('on_the_way', 'started', 'paused')
               and (p_user_id in (v.responsible_user_id, v.covered_by) or private.visit_performer(v.id) = p_user_id)) then
    return jsonb_build_object('result', private.end_command('has_visit_in_progress'));
  end if;
  if exists (select 1 from public.care_visits v
             where v.organization_id = org and v.status = 'planned' and v.visit_date >= today
               and p_user_id in (v.responsible_user_id, v.covered_by)) then
    return jsonb_build_object('result', private.end_command('has_planned_visits'));
  end if;
  insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
  values (org, p_user_id, 'ended', p_reason_code, uid);
  -- Open question 3: her push subscriptions are deleted (no push can be queued for her); audited per subscription.
  for r in delete from public.push_subscriptions s where s.user_id = p_user_id returning s.id, s.organization_id loop
    perform private.audit_command(r.organization_id, 'push_subscriptions', r.id,
            jsonb_build_object('deleted', true, 'reason', 'access_ended'));
    subs := subs + 1;
  end loop;
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'organization_memberships', p_user_id::text, 'end_member_access',
          jsonb_build_object('access', jsonb_build_object('old', 'open', 'new', 'ended'), 'reason_code', p_reason_code),
          p_reason_code, uid, p_idempotency_key);
  perform private.audit_command(org, 'organization_memberships', p_user_id,
          jsonb_build_object('access', 'ended', 'reason_code', p_reason_code, 'push_subscriptions_removed', subs));
  return jsonb_build_object('result', private.end_command('ok'), 'push_subscriptions_removed', subs);
end;
$$;
revoke all on function public.end_member_access(uuid, text, uuid) from public, anon;
grant execute on function public.end_member_access(uuid, text, uuid) to authenticated;
comment on function public.end_member_access(uuid, text, uuid) is
  'LEAVE1-1: an organisation administrator ends a person''s access (reason code employment_ended | access_withdrawn). '
  'Refused for the caller herself (self), a person of another organisation (rejected), the last administrator with '
  'access (last_admin), and while she is primary or deputy nurse of an open case (has_cases), has a visit on the way, '
  'started or paused (has_visit_in_progress) or is responsible for or covers a planned visit from today on '
  '(has_planned_visits). Not refused by her open reports (LEAVE1-2). Deletes her push subscriptions; deletes nothing '
  'else. Returns {result, push_subscriptions_removed}.';

-- LEAVE1-7. Return: {"result": "ok" | "unchanged" | "duplicate" | "rejected"}
create or replace function public.restore_member_access(p_user_id uuid, p_reason_code text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_reason_code is null or p_reason_code not in ('employment_resumed', 'ended_in_error') then
    raise exception 'reason code must be employment_resumed or ended_in_error' using errcode = '22023';
  end if;
  if private.begin_command('restore_member_access', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if p_user_id is null or p_user_id = uid then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  org := private.leave1_org_for(p_user_id);
  if org is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  perform 1 from public.organization_memberships m where m.organization_id = org and m.user_id = p_user_id for update;
  if not exists (select 1 from public.member_access_events e
                 where e.organization_id = org and e.user_id = p_user_id
                 order by e.seq desc limit 1)
     or (select e.kind from public.member_access_events e
         where e.organization_id = org and e.user_id = p_user_id order by e.seq desc limit 1) <> 'ended' then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;
  insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
  values (org, p_user_id, 'restored', p_reason_code, uid);
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'organization_memberships', p_user_id::text, 'restore_member_access',
          jsonb_build_object('access', jsonb_build_object('old', 'ended', 'new', 'open'), 'reason_code', p_reason_code),
          p_reason_code, uid, p_idempotency_key);
  perform private.audit_command(org, 'organization_memberships', p_user_id,
          jsonb_build_object('access', 'restored', 'reason_code', p_reason_code));
  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.restore_member_access(uuid, text, uuid) from public, anon;
grant execute on function public.restore_member_access(uuid, text, uuid) to authenticated;
comment on function public.restore_member_access(uuid, text, uuid) is
  'LEAVE1-7: an organisation administrator restores a person''s access (reason code employment_resumed | '
  'ended_in_error). Memberships were never removed, so she gets exactly the access she had. Push must be switched on '
  'again by her. Returns {result}.';

-- The person's own state (LEAVE1-6 reads it; part b builds the screen). Callable after the access end.
create or replace function public.my_access_state()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'ended', private.access_ended((select auth.uid())),
    'ended_at', (select max(e.created_at) from public.member_access_events e
                 where e.user_id = (select auth.uid()) and e.kind = 'ended'
                   and private.access_ended((select auth.uid()))))
$$;
revoke all on function public.my_access_state() from public, anon;
grant execute on function public.my_access_state() to authenticated;
comment on function public.my_access_state() is
  'LEAVE1-6: {ended, ended_at} for the signed-in person; no reason code, no names, no counts.';

drop function private.leave1_patch(text, text[], text);
