-- SIG2: safety signals reach the nurse's phone (brief `docs/agents/briefs/SIG2.md`, ADR-076).
-- Product decisions: D-32 (po 2026-10-24 09:12, option B narrow variant) and its addendum for CGR-41 points 1-3
-- (po 11:09). Finding CGR-41 (`cra` 10:26, advisory S2); remediation plan `clinical/remediation/CGR-41.md`.
-- SIG1 (0060) is unchanged for every organisation that has not switched the channel on (the default).
--
-- What this adds:
--   * `public.push_vendors`: the two allowed push vendors (Google FCM, Microsoft Windows push), their endpoint hosts
--     and the Swiss-U.S. DPF list entry as read. A vendor counts only while its entry is recorded as `active` with the
--     date read (SIG2-3). This migration records NO entry: the official list could not be read in this run
--     (UNKNOWN), so no endpoint is accepted until the entry is recorded by a reviewed migration (fail closed).
--   * `public.organization_push_settings`: the channel, off by default, switched on only by an administrator and
--     only while at least one vendor counts (SIG2-3).
--   * `public.organization_watched_hours`: the organisation's watched hours per weekday (SIG2-6, operating rules).
--   * `public.push_subscriptions`: one row per device subscription, readable only by its owner (SIG2-1, SIG2-9).
--   * `public.signal_outside_deliveries`: the outside result of each SIG1 delivery row (SIG2-4, SIG2-8):
--     `pending` (handed to the sender), `sent`, `failed`, `not_active`, `outside_working_time`. Send and tap time.
--   * `safety_signals.outside_none_at`: "kein Empfänger ausserhalb der App" (SIG2-5); the signal then goes to
--     Operations at once as untaken (the SIG1-5 step, without waiting for `signal_untaken`).
--   * A look-ahead `visit_uncovered_hospital` whose window opens outside the watched hours is raised at the end of
--     the last watched period before (SIG2-6): earlier, never later.
--   * The sender (Next.js server, VAPID key in its environment, never in the database) claims pending rows through
--     `push_dispatch_claim` and reports through `push_dispatch_report`; both are executable by `service_role` only.
--     A row the sender has not reported within 2 minutes counts as failed (the sender may be down): fail closed.
--   * AN2 measure 10 gains `signal_outside_sent_share` and `signal_taken_within_threshold_share` (SIG2-10).
--
-- No clinical, tariff or legal rule is invented: no threshold, priority, response duty or response time is set
-- (D-28). The payload is one fixed text without client data (in the sender, SIG2-8). RLS on, column grants only,
-- audit triggers, idempotent commands.

-- 1. Vendors (platform facts, changed only by a reviewed migration) --------------------------------------------------
create table if not exists public.push_vendors (
  vendor        text primary key check (vendor in ('google_fcm', 'microsoft_wns')),
  legal_entity  text not null,
  country       text not null,
  hosts_exact   text[] not null default '{}',
  hosts_suffix  text[] not null default '{}',
  -- The official Swiss-U.S. DPF list entry as read (https://www.dataprivacyframework.gov/list), with the date read.
  dpf_swiss_status text check (dpf_swiss_status in ('active', 'inactive')),
  dpf_read_on   date,
  check ((dpf_swiss_status is null) = (dpf_read_on is null))
);
comment on table public.push_vendors is
  'SIG2-1/SIG2-3: allowed web-push vendors and their endpoint hosts. A vendor counts only with a Swiss-U.S. DPF entry recorded as active and the date read. Changed only by migration.';

insert into public.push_vendors (vendor, legal_entity, country, hosts_exact, hosts_suffix)
values ('google_fcm', 'Google LLC', 'USA', array['fcm.googleapis.com'], '{}'),
       ('microsoft_wns', 'Microsoft Corporation', 'USA', '{}', array['.notify.windows.com'])
on conflict (vendor) do nothing;

alter table public.push_vendors enable row level security;
revoke all on public.push_vendors from public, anon, authenticated;
grant select (vendor, legal_entity, country, dpf_swiss_status, dpf_read_on) on public.push_vendors to authenticated;
drop policy if exists push_vendors_read on public.push_vendors;
create policy push_vendors_read on public.push_vendors for select to authenticated using (true);

-- The vendor of an endpoint, only if the vendor counts (fail closed: an unknown host, http, a port, user info → null).
create or replace function private.push_vendor_for_endpoint(p_endpoint text)
returns text language sql stable security definer set search_path = ''
as $$
  with h as (
    select lower(substring(p_endpoint from '^https://([a-zA-Z0-9.-]+)/')) as host
  )
  select pv.vendor from public.push_vendors pv, h
  where h.host is not null and pv.dpf_swiss_status = 'active' and pv.dpf_read_on is not null
    and (h.host = any (pv.hosts_exact)
         or exists (select 1 from unnest(pv.hosts_suffix) s where right(h.host, length(s)) = s and length(h.host) > length(s)))
  order by pv.vendor limit 1
$$;

create or replace function private.push_vendors_counted()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.push_vendors where dpf_swiss_status = 'active' and dpf_read_on is not null) $$;

-- 2. Channel per organisation (off by default) ------------------------------------------------------------------------
create table if not exists public.organization_push_settings (
  organization_id uuid primary key references public.organizations (id),
  id              uuid not null default gen_random_uuid() unique,
  enabled         boolean not null default false,
  enabled_since   timestamptz,
  updated_by      uuid,
  updated_at      timestamptz not null default now(),
  check (enabled = (enabled_since is not null))
);
comment on table public.organization_push_settings is
  'SIG2-3: delivery outside the app per organisation; off unless an administrator switched it on.';

drop trigger if exists audit_organization_push_settings on public.organization_push_settings;
create trigger audit_organization_push_settings after insert or update on public.organization_push_settings
  for each row execute function private.write_audit_event('enabled', 'enabled_since', 'updated_by');

alter table public.organization_push_settings enable row level security;
revoke all on public.organization_push_settings from public, anon, authenticated;
grant select (organization_id, enabled, enabled_since, updated_by, updated_at) on public.organization_push_settings to authenticated;
drop policy if exists organization_push_settings_member on public.organization_push_settings;
create policy organization_push_settings_member on public.organization_push_settings for select to authenticated
  using (private.is_org_member(organization_id));

create or replace function private.outside_channel_on(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((select s.enabled from public.organization_push_settings s where s.organization_id = p_org), false)
         and private.push_vendors_counted()
$$;

-- Return: ok | unchanged | duplicate | rejected | vendors_unverified
create or replace function public.set_outside_push(p_organization_id uuid, p_enabled boolean, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  cur boolean;
begin
  if uid is null or p_enabled is null then return 'rejected'; end if;
  if private.begin_command('set_outside_push', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then return private.end_command('rejected'); end if;
  if p_enabled and not private.push_vendors_counted() then return private.end_command('vendors_unverified'); end if;
  select s.enabled into cur from public.organization_push_settings s where s.organization_id = p_organization_id for update;
  if coalesce(cur, false) = p_enabled then return private.end_command('unchanged'); end if;
  insert into public.organization_push_settings (organization_id, enabled, enabled_since, updated_by, updated_at)
  values (p_organization_id, p_enabled, case when p_enabled then now() end, uid, now())
  on conflict (organization_id) do update
    set enabled = excluded.enabled, enabled_since = excluded.enabled_since, updated_by = uid, updated_at = now();
  if not p_enabled then
    -- Nothing more leaves the app for this organisation: rows not yet sent are recorded as failed.
    update public.signal_outside_deliveries o set result = 'failed', failure = 'channel_off'
    where o.organization_id = p_organization_id and o.result = 'pending';
  end if;
  return private.end_command('ok');
end;
$$;

-- 3. Watched hours (SIG2-6) -------------------------------------------------------------------------------------------
create table if not exists public.organization_watched_hours (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  weekday         smallint not null check (weekday between 1 and 7),   -- ISO: 1 = Monday
  starts          time not null,
  ends            time not null,                                         -- '24:00' allowed for midnight
  created_by      uuid,
  created_at      timestamptz not null default now(),
  check (starts < ends)
);
create index if not exists organization_watched_hours_org on public.organization_watched_hours (organization_id, weekday);
comment on table public.organization_watched_hours is
  'SIG2-6: the hours in which the organisation watches signals (pilot plan, SIG1-8), per ISO weekday, Europe/Zurich wall time.';

drop trigger if exists audit_organization_watched_hours on public.organization_watched_hours;
create trigger audit_organization_watched_hours after insert on public.organization_watched_hours
  for each row execute function private.write_audit_event('weekday', 'starts', 'ends');

alter table public.organization_watched_hours enable row level security;
revoke all on public.organization_watched_hours from public, anon, authenticated;
grant select (id, organization_id, weekday, starts, ends, created_at) on public.organization_watched_hours to authenticated;
drop policy if exists organization_watched_hours_member on public.organization_watched_hours;
create policy organization_watched_hours_member on public.organization_watched_hours for select to authenticated
  using (private.is_org_member(organization_id));

-- Replace the whole week. p_hours: [{"weekday": 1, "starts": "07:00", "ends": "20:00"}, …]; [] clears it.
-- Return: ok | unchanged | duplicate | rejected | invalid
create or replace function public.set_watched_hours(p_organization_id uuid, p_hours jsonb, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  want jsonb;
  had  jsonb;
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('set_watched_hours', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  if not private.is_org_admin(p_organization_id) then return private.end_command('rejected'); end if;
  if p_hours is null or jsonb_typeof(p_hours) <> 'array' or jsonb_array_length(p_hours) > 28 then
    return private.end_command('invalid');
  end if;
  begin
    select coalesce(jsonb_agg(jsonb_build_object('weekday', w, 'starts', s::text, 'ends', e::text) order by w, s), '[]'::jsonb)
    into want
    from (select (x ->> 'weekday')::smallint as w, (x ->> 'starts')::time as s, (x ->> 'ends')::time as e
          from jsonb_array_elements(p_hours) x) q;
  exception when others then
    return private.end_command('invalid');
  end;
  if exists (select 1 from jsonb_array_elements(want) x
             where (x ->> 'weekday')::int not between 1 and 7 or (x ->> 'starts')::time >= (x ->> 'ends')::time)
     or exists (select 1 from jsonb_array_elements(want) with ordinality a(v, i), jsonb_array_elements(want) with ordinality b(v, j)
                where a.i < b.j and a.v ->> 'weekday' = b.v ->> 'weekday'
                  and (a.v ->> 'starts')::time < (b.v ->> 'ends')::time and (b.v ->> 'starts')::time < (a.v ->> 'ends')::time) then
    return private.end_command('invalid');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('weekday', h.weekday, 'starts', h.starts::text, 'ends', h.ends::text)
                            order by h.weekday, h.starts), '[]'::jsonb)
  into had from public.organization_watched_hours h where h.organization_id = p_organization_id;
  if had = want then return private.end_command('unchanged'); end if;
  delete from public.organization_watched_hours where organization_id = p_organization_id;
  perform private.audit_command(p_organization_id, 'organization_watched_hours', p_organization_id,
                                jsonb_build_object('hours', jsonb_build_object('old', had, 'new', want)));
  insert into public.organization_watched_hours (organization_id, weekday, starts, ends, created_by)
  select p_organization_id, (x ->> 'weekday')::smallint, (x ->> 'starts')::time, (x ->> 'ends')::time, uid
  from jsonb_array_elements(want) x;
  return private.end_command('ok');
end;
$$;

-- SIG2-6: the time at which a look-ahead signal whose window opens at p_t is raised.
-- p_t itself when the organisation records no watched hours or p_t lies inside a watched period; otherwise the end of
-- the last watched period before p_t (earlier, never later). Europe/Zurich wall time.
create or replace function private.watched_raise_at(p_org uuid, p_t timestamptz)
returns timestamptz language sql stable security definer set search_path = ''
as $$
  with local as (select (p_t at time zone 'Europe/Zurich') as lt),
  hours as (select h.weekday, h.starts, h.ends from public.organization_watched_hours h where h.organization_id = p_org),
  inside as (
    select 1 from hours h, local l
    where h.weekday = extract(isodow from l.lt)::int and h.starts <= l.lt::time
      and (h.ends = time '24:00' or l.lt::time < h.ends)
  ),
  last_end as (
    select max(e) as e from (
      select ((l.lt::date - d) + h.ends) at time zone 'Europe/Zurich' as e
      from local l cross join generate_series(0, 7) d join hours h on h.weekday = extract(isodow from (l.lt::date - d))::int
    ) q where q.e <= p_t
  )
  select case
    when not exists (select 1 from hours) then p_t
    when exists (select 1 from inside) then p_t
    else coalesce((select e from last_end), p_t) end
$$;

-- 4. Subscriptions (SIG2-1, SIG2-9) -----------------------------------------------------------------------------------
create table if not exists public.push_subscriptions (
  id                uuid primary key default gen_random_uuid(),
  organization_id   uuid not null references public.organizations (id),
  user_id           uuid not null,
  vendor            text not null references public.push_vendors (vendor),
  endpoint          text not null unique check (length(endpoint) <= 2048),
  p256dh            text not null check (p256dh ~ '^[A-Za-z0-9_-]{86,88}={0,2}$'),
  auth_secret       text not null check (auth_secret ~ '^[A-Za-z0-9_-]{21,24}={0,2}$'),
  created_at        timestamptz not null default now(),
  test_requested_at timestamptz,
  claimed_at        timestamptz,
  last_result       text check (last_result in ('sent', 'failed')),
  last_sent_at      timestamptz
);
create index if not exists push_subscriptions_user on public.push_subscriptions (user_id);
comment on table public.push_subscriptions is
  'SIG2-1: a device subscription for delivery outside the app. Only Google (FCM) and Microsoft (Windows push) endpoints are stored. Readable only by its owner; the endpoint and keys are read only by the sender (service role).';

drop trigger if exists audit_push_subscriptions on public.push_subscriptions;
create trigger audit_push_subscriptions after insert or update of vendor, user_id, last_result on public.push_subscriptions
  for each row execute function private.write_audit_event('vendor', 'user_id', 'last_result');

alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from public, anon, authenticated;
grant select (id, organization_id, user_id, vendor, created_at, last_result, last_sent_at) on public.push_subscriptions to authenticated;
drop policy if exists push_subscriptions_own on public.push_subscriptions;
create policy push_subscriptions_own on public.push_subscriptions for select to authenticated
  using (user_id = (select auth.uid()));

-- Active outside delivery = a stored subscription whose last send succeeded (the test message or a signal).
create or replace function private.push_active(p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.push_subscriptions s where s.user_id = p_user and s.last_result = 'sent') $$;

-- SIG2-1: switch on. Returns {result: ok|duplicate|not_available|channel_off|rejected, subscription_id?}.
-- An endpoint of any other vendor (Apple, Mozilla, other) is not stored: not_available (D-33).
create or replace function public.register_push_subscription(p_endpoint text, p_p256dh text, p_auth text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  org    uuid;
  vend   text;
  sub_id uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('register_push_subscription', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  -- Recipients of signals only: a team member, or Operations / admin. Never a client or partner account, never a coach
  -- without team. The organisation must have switched the channel on.
  select m.organization_id into org
  from public.organization_memberships m
  where m.user_id = uid and private.outside_channel_on(m.organization_id)
    and (m.role in ('operations', 'admin')
         or exists (select 1 from public.team_memberships tm join public.teams t on t.id = tm.team_id
                    where tm.user_id = uid and t.organization_id = m.organization_id))
  order by m.created_at, m.organization_id limit 1;
  if org is null then return jsonb_build_object('result', private.end_command('channel_off')); end if;
  vend := private.push_vendor_for_endpoint(p_endpoint);
  if vend is null then return jsonb_build_object('result', private.end_command('not_available')); end if;
  if p_p256dh is null or p_p256dh !~ '^[A-Za-z0-9_-]{86,88}={0,2}$'
     or p_auth is null or p_auth !~ '^[A-Za-z0-9_-]{21,24}={0,2}$' or length(p_endpoint) > 2048 then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  -- One device, one row: the same endpoint registered again (also by another person on a shared device) replaces it.
  insert into public.push_subscriptions (organization_id, user_id, vendor, endpoint, p256dh, auth_secret, test_requested_at)
  values (org, uid, vend, p_endpoint, p_p256dh, p_auth, now())
  on conflict (endpoint) do update
    set organization_id = excluded.organization_id, user_id = excluded.user_id, vendor = excluded.vendor,
        p256dh = excluded.p256dh, auth_secret = excluded.auth_secret, test_requested_at = now(),
        claimed_at = null, last_result = null, last_sent_at = null
  returning id into sub_id;
  return jsonb_build_object('result', private.end_command('ok'), 'subscription_id', sub_id);
end;
$$;

-- SIG2-1: switch off. p_endpoint null = every device of the caller. Return: ok | unchanged | duplicate | rejected.
create or replace function public.unregister_push_subscription(p_endpoint text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   record;
  n   integer := 0;
begin
  if uid is null then return 'rejected'; end if;
  if private.begin_command('unregister_push_subscription', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  for r in delete from public.push_subscriptions s
           where s.user_id = uid and (p_endpoint is null or s.endpoint = p_endpoint)
           returning s.id, s.organization_id, s.vendor loop
    perform private.audit_command(r.organization_id, 'push_subscriptions', r.id,
                                  jsonb_build_object('deleted', true, 'vendor', r.vendor));
    n := n + 1;
  end loop;
  return private.end_command(case when n > 0 then 'ok' else 'unchanged' end);
end;
$$;

-- The caller's own outside-delivery state for the settings page.
create or replace function public.my_push_state()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'channel_on', exists (select 1 from public.organization_memberships m
                          where m.user_id = (select auth.uid()) and private.outside_channel_on(m.organization_id)),
    'active', private.push_active((select auth.uid())),
    'devices', coalesce((select jsonb_agg(jsonb_build_object('vendor', s.vendor, 'created_at', s.created_at,
                                                             'last_result', s.last_result, 'last_sent_at', s.last_sent_at)
                                          order by s.created_at)
                         from public.push_subscriptions s where s.user_id = (select auth.uid())), '[]'::jsonb),
    'vendors', coalesce((select jsonb_agg(jsonb_build_object('vendor', v.vendor, 'legal_entity', v.legal_entity,
                                                             'country', v.country, 'dpf_read_on', v.dpf_read_on)
                                          order by v.vendor)
                         from public.push_vendors v where v.dpf_swiss_status = 'active' and v.dpf_read_on is not null), '[]'::jsonb))
  where (select auth.uid()) is not null
$$;

-- SIG2-2: per member of the caller's teams: active / not active. Nothing else about the member.
create or replace function public.team_push_status()
returns table (team_id uuid, team_name text, user_id uuid, member_name text, active boolean)
language sql stable security definer set search_path = ''
as $$
  select t.id, t.name, tm.user_id, coalesce(private.member_name(t.organization_id, tm.user_id), 'Teammitglied'),
         private.push_active(tm.user_id)
  from public.team_memberships mine
  join public.teams t on t.id = mine.team_id
  join public.team_memberships tm on tm.team_id = t.id
  where mine.user_id = (select auth.uid()) and private.is_org_member(t.organization_id)
  order by t.name, 4, tm.user_id
$$;

-- 5. Outside result per delivery (SIG2-4, SIG2-8) ---------------------------------------------------------------------
alter table public.safety_signals add column if not exists outside_none_at timestamptz;
comment on column public.safety_signals.outside_none_at is
  'SIG2-5: "kein Empfänger ausserhalb der App": nobody received the signal outside the app; Operations got it at once.';
grant select (outside_none_at) on public.safety_signals to authenticated;

create table if not exists public.signal_outside_deliveries (
  id              uuid primary key references public.signal_deliveries (id),   -- the SIG1 delivery row
  organization_id uuid not null references public.organizations (id),
  signal_id       uuid not null references public.safety_signals (id),
  recipient_id    uuid not null,
  result          text not null check (result in ('pending', 'sent', 'failed', 'not_active', 'outside_working_time')),
  failure         text check (failure in ('send_failed', 'timeout', 'no_device', 'channel_off')),
  decided_at      timestamptz not null default now(),
  claimed_at      timestamptz,
  sent_at         timestamptz,
  tapped_at       timestamptz,
  check ((result = 'sent') = (sent_at is not null)),
  check ((result = 'failed') = (failure is not null)),
  check (tapped_at is null or result = 'sent')
);
create index if not exists signal_outside_deliveries_signal on public.signal_outside_deliveries (signal_id);
create index if not exists signal_outside_deliveries_pending on public.signal_outside_deliveries (decided_at) where result = 'pending';
create index if not exists signal_outside_deliveries_recipient on public.signal_outside_deliveries (recipient_id, sent_at);
comment on table public.signal_outside_deliveries is
  'SIG2-4/SIG2-8: outside the app, per SIG1 delivery row: result, send time, tap time. Display on the device is never recorded or claimed. No free text.';

create or replace function private.guard_signal_outside_delivery()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'outside deliveries are never deleted' using errcode = '42501';
  end if;
  if (new.id, new.organization_id, new.signal_id, new.recipient_id, new.decided_at)
     is distinct from (old.id, old.organization_id, old.signal_id, old.recipient_id, old.decided_at)
     or (old.result <> 'pending' and (new.result, new.failure, new.sent_at) is distinct from (old.result, old.failure, old.sent_at))
     or (old.tapped_at is not null and new.tapped_at is distinct from old.tapped_at) then
    raise exception 'an outside delivery records its result and its tap once; nothing else changes' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_signal_outside_deliveries on public.signal_outside_deliveries;
create trigger guard_signal_outside_deliveries before update or delete on public.signal_outside_deliveries
  for each row execute function private.guard_signal_outside_delivery();
drop trigger if exists audit_signal_outside_deliveries on public.signal_outside_deliveries;
create trigger audit_signal_outside_deliveries after insert or update of result, failure, sent_at, tapped_at on public.signal_outside_deliveries
  for each row execute function private.write_audit_event('result', 'failure', 'sent_at', 'tapped_at');

alter table public.signal_outside_deliveries enable row level security;
revoke all on public.signal_outside_deliveries from public, anon, authenticated;
grant select (id, organization_id, signal_id, recipient_id, result, failure, decided_at, sent_at, tapped_at)
  on public.signal_outside_deliveries to authenticated;
drop policy if exists signal_outside_deliveries_own on public.signal_outside_deliveries;
create policy signal_outside_deliveries_own on public.signal_outside_deliveries for select to authenticated
  using (recipient_id = (select auth.uid()) and private.is_org_member(organization_id));

-- The SIG1 guard gains the SIG2-5 field (recorded once).
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
     or (old.escalated_at is not null and new.escalated_at is distinct from old.escalated_at)
     or (old.outside_none_at is not null and new.outside_none_at is distinct from old.outside_none_at) then
    raise exception 'a safety signal records end, take, escalation and outside result once; nothing else changes' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists audit_safety_signals on public.safety_signals;
create trigger audit_safety_signals after insert or update on public.safety_signals
  for each row execute function private.write_audit_event('signal_kind', 'ended_at', 'taken_by', 'taken_at', 'escalated_at', 'outside_none_at');

-- SIG2-4: a colleague's planned working time today = from the planned start of her first visit that day to the
-- planned end of her last visit that day (Zurich day of p_at); null when she has no planned visit that day.
create or replace function private.member_working_span(p_org uuid, p_user uuid, p_at timestamptz)
returns tstzrange language sql stable security definer set search_path = ''
as $$
  select case when count(*) = 0 then null
              else tstzrange(min(lower(private.visit_interval(v))), max(upper(private.visit_interval(v))), '[]') end
  from public.care_visits v
  where v.organization_id = p_org and v.visit_date = (p_at at time zone 'Europe/Zurich')::date
    and (v.responsible_user_id = p_user or v.covered_by = p_user)
    and v.status is distinct from 'cancelled' and v.suspended_at is null
$$;

-- SIG2-4 / SIG2-7: the outside result of every delivery row of the organisation that has none yet (only rows created
-- while the channel is on). Responsible member: always (SIG1 already leaves out an absent one). Colleague: inside her
-- planned working time only. Operations (fallback and the untaken step): every Operations member who opted in.
create or replace function private.outside_classify(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  k integer;
begin
  insert into public.signal_outside_deliveries (id, organization_id, signal_id, recipient_id, result)
  select d.id, d.organization_id, d.signal_id, d.recipient_id,
         case when not private.push_active(d.recipient_id) then 'not_active'
              when d.reason = 'team'
                   and not coalesce(private.member_working_span(p_org, d.recipient_id, now()) @> now(), false)
                then 'outside_working_time'
              else 'pending' end
  from public.signal_deliveries d
  join public.safety_signals s on s.id = d.signal_id
  join public.organization_push_settings ps on ps.organization_id = d.organization_id and ps.enabled
  where d.organization_id = p_org and s.ended_at is null and d.created_at >= ps.enabled_since
    and not exists (select 1 from public.signal_outside_deliveries o where o.id = d.id)
  on conflict (id) do nothing;
  get diagnostics k = row_count;
  return k;
end;
$$;

-- SIG2-5: a row the sender has not reported within 2 minutes counts as failed (fail closed: the sender may be down).
-- Then every open, untaken, not yet escalated signal whose rows are all decided and none `sent` records
-- "kein Empfänger ausserhalb der App" and goes to Operations at once as untaken (the SIG1-5 step, earlier).
create or replace function private.outside_settle(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  n   integer := 0;
  sig record;
begin
  update public.signal_outside_deliveries o set result = 'failed', failure = 'timeout'
  where o.organization_id = p_org and o.result = 'pending' and o.decided_at < now() - interval '2 minutes';
  for sig in
    select s.id, s.visit_id, s.signal_kind
    from public.safety_signals s
    where s.organization_id = p_org and s.ended_at is null and s.taken_by is null
      and s.escalated_at is null and s.outside_none_at is null
      and exists (select 1 from public.signal_outside_deliveries o where o.signal_id = s.id)
      and not exists (select 1 from public.signal_outside_deliveries o where o.signal_id = s.id and o.result in ('pending', 'sent'))
    for update of s skip locked
  loop
    insert into public.signal_deliveries (organization_id, signal_id, recipient_id, reason, signal_kind, visit_id)
    select p_org, sig.id, o, 'untaken', sig.signal_kind, sig.visit_id
    from private.signal_operations_users(p_org) o
    on conflict (signal_id, recipient_id) do nothing;
    update public.safety_signals set outside_none_at = now(), escalated_at = now() where id = sig.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

create or replace function private.outside_after_evaluate(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  n integer := 0;
begin
  if not private.outside_channel_on(p_org) then return 0; end if;
  n := private.outside_classify(p_org);
  n := n + private.outside_settle(p_org);
  n := n + private.outside_classify(p_org);   -- the Operations rows written by the settle step (SIG2-7)
  return n;
end;
$$;

-- Hook into the SIG1 writer: once per evaluation, after the untaken step (same transaction, same advisory lock).
create function private.sig2_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'SIG2 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

select private.sig2_patch('private.evaluate_signals(uuid, boolean)', array[
  E'  perform set_config(''navora.command'', '''', true);\n  return n;',
  E'  -- SIG2: outside results, sender timeouts, nobody reachable outside the app → Operations at once.\n'
  || E'  n := n + private.outside_after_evaluate(p_org);\n\n'
  || E'  perform set_config(''navora.command'', '''', true);\n  return n;'
]);

-- 6. Sender interface (service_role only; the VAPID private key lives in the sender's environment) ---------------------
-- Claims what is due: pending signal rows (one row per active device of the recipient) and requested test messages.
-- A claim older than 1 minute is claimed again (a sender that died); the 2-minute timeout above still applies.
create or replace function public.push_dispatch_claim(p_limit integer default 100)
returns table (kind text, ref_id uuid, subscription_id uuid, endpoint text, p256dh text, auth_secret text)
language plpgsql security definer set search_path = ''
as $$
begin
  perform set_config('navora.command', 'push_dispatch', true);
  perform set_config('navora.idempotency_key', '', true);
  return query
  with due as (
    select o.id from public.signal_outside_deliveries o
    where o.result = 'pending' and (o.claimed_at is null or o.claimed_at < now() - interval '1 minute')
      and private.outside_channel_on(o.organization_id)
    order by o.decided_at limit greatest(1, least(coalesce(p_limit, 100), 500))
    for update skip locked
  ), claimed as (
    update public.signal_outside_deliveries o set claimed_at = now() from due where o.id = due.id
    returning o.id, o.recipient_id
  ), tests_due as (
    select x.id from public.push_subscriptions x
    where x.test_requested_at is not null and (x.claimed_at is null or x.claimed_at < now() - interval '1 minute')
    order by x.test_requested_at limit greatest(1, least(coalesce(p_limit, 100), 500))
    for update skip locked
  ), tests as (
    update public.push_subscriptions s set claimed_at = now() from tests_due where s.id = tests_due.id
    returning s.id, s.endpoint, s.p256dh, s.auth_secret
  )
  -- A recipient without an active device any more comes back with null device fields: the sender reports it failed.
  select 'signal'::text, c.id, s.id, s.endpoint, s.p256dh, s.auth_secret
  from claimed c left join public.push_subscriptions s on s.user_id = c.recipient_id and s.last_result = 'sent'
  union all
  select 'test'::text, t.id, t.id, t.endpoint, t.p256dh, t.auth_secret from tests t;
end;
$$;

-- Reports one item. p_results: [{"subscription_id": uuid, "ok": bool, "gone": bool}]. A gone device (HTTP 404/410)
-- is deleted. Signal row: `sent` when one device accepted it, else `failed`. Returns the row's final result.
create or replace function public.push_dispatch_report(p_kind text, p_ref_id uuid, p_results jsonb)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  r      record;
  any_ok boolean := false;
  org    uuid;
  res    text;
begin
  perform set_config('navora.command', 'push_dispatch', true);
  perform set_config('navora.idempotency_key', '', true);
  if p_kind not in ('signal', 'test') or p_ref_id is null or jsonb_typeof(coalesce(p_results, 'null'::jsonb)) <> 'array' then
    return 'rejected';
  end if;
  for r in select (x ->> 'subscription_id')::uuid as sid, coalesce((x ->> 'ok')::boolean, false) as ok,
                  coalesce((x ->> 'gone')::boolean, false) as gone
           from jsonb_array_elements(p_results) x loop
    any_ok := any_ok or r.ok;
    if r.gone then
      delete from public.push_subscriptions s where s.id = r.sid returning s.organization_id into org;
      if org is not null then
        perform private.audit_command(org, 'push_subscriptions', r.sid, jsonb_build_object('deleted', true, 'reason', 'gone'));
      end if;
    else
      update public.push_subscriptions s
      set last_result = case when r.ok then 'sent' else 'failed' end, last_sent_at = now(), claimed_at = null,
          test_requested_at = case when p_kind = 'test' and s.id = p_ref_id then null else s.test_requested_at end
      where s.id = r.sid;
    end if;
  end loop;
  if p_kind = 'test' then
    update public.push_subscriptions set test_requested_at = null, claimed_at = null where id = p_ref_id;
    perform set_config('navora.command', '', true);
    return case when any_ok then 'sent' else 'failed' end;
  end if;
  update public.signal_outside_deliveries o
  set result = case when any_ok then 'sent' else 'failed' end,
      failure = case when any_ok then null when jsonb_array_length(p_results) = 0 then 'no_device' else 'send_failed' end,
      sent_at = case when any_ok then now() end
  where o.id = p_ref_id and o.result = 'pending'
  returning o.organization_id, o.result into org, res;
  if org is not null then
    perform private.outside_settle(org);
    perform private.outside_classify(org);
  else
    select o.result into res from public.signal_outside_deliveries o where o.id = p_ref_id;
  end if;
  perform set_config('navora.command', '', true);
  return coalesce(res, 'rejected');
end;
$$;

-- SIG2-8: a tap on the message opened NAVORA (/field?von=push). The message carries no ID, so the caller's sent,
-- untapped rows of the last 24 h are marked. Display on the device is never recorded.
create or replace function public.record_push_tap()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  k integer;
begin
  if (select auth.uid()) is null then return 0; end if;
  perform set_config('navora.command', 'record_push_tap', true);
  update public.signal_outside_deliveries o set tapped_at = now()
  where o.recipient_id = (select auth.uid()) and o.result = 'sent' and o.tapped_at is null
    and o.sent_at > now() - interval '24 hours' and private.is_org_member(o.organization_id);
  get diagnostics k = row_count;
  perform set_config('navora.command', '', true);
  return k;
end;
$$;

-- 7. SIG2-6: look-ahead hospital-discharge signal inside watched hours -------------------------------------------------
select private.sig2_patch('private.derived_exceptions(uuid)', array[
  E'    and (v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich''\n'
  || E'        <= private.after_threshold(now(), r.amount, r.unit)\n'
  || E'  union all\n'
  || E'  -- COVER1:',
  E'    and ((v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich''\n'
  || E'          <= private.after_threshold(now(), r.amount, r.unit)\n'
  || E'         -- SIG2-6: a window that opens outside the watched hours opens at the end of the last watched period before\n'
  || E'         or (r.exception_type = ''visit_uncovered_hospital''\n'
  || E'             and now() >= private.watched_raise_at(p_org,\n'
  || E'                   (v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich''\n'
  || E'                   - (private.after_threshold((v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich'', r.amount, r.unit)\n'
  || E'                      - (v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich''))))\n'
  || E'  union all\n'
  || E'  -- COVER1:'
]);
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- 8. AN2 measure 10 (SIG2-10) ----------------------------------------------------------------------------------------
select private.sig2_patch('public.pilot_hypotheses(date)', array[
  E'  ), ord0_episodes as (',
  E'  ), sig2_episodes as (\n'
  || E'    -- SIG2-10: P1 signals with at least one sent outside delivery; taken within the untaken threshold as set today\n'
  || E'    select s.organization_id, s.team_id,\n'
  || E'           exists (select 1 from public.signal_outside_deliveries o where o.signal_id = s.id and o.result = ''sent'') as sent,\n'
  || E'           s.taken_at is not null and s.taken_at <= (select private.after_threshold(s.created_at, er.amount, er.unit)\n'
  || E'                                                     from private.effective_exception_rules(s.organization_id) er\n'
  || E'                                                     where er.exception_type = ''signal_untaken'') as in_time\n'
  || E'    from public.safety_signals s, params p\n'
  || E'    where s.team_id in (select id from my_teams)\n'
  || E'      and (s.created_at at time zone ''Europe/Zurich'')::date >= p.m0 and (s.created_at at time zone ''Europe/Zurich'')::date < p.m1\n'
  || E'  ), m10p as (\n'
  || E'    select x.organization_id, x.team_id, ''signal_outside_sent_share''::text as measure, null::text as detail,\n'
  || E'           round(100.0 * count(*) filter (where x.sent) / count(*), 1) as value, count(*)::int as base\n'
  || E'    from sig2_episodes x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n'
  || E'    union all\n'
  || E'    select x.organization_id, x.team_id, ''signal_taken_within_threshold_share'', null,\n'
  || E'           round(100.0 * count(*) filter (where x.in_time) / count(*), 1), count(*)::int\n'
  || E'    from sig2_episodes x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n'
  || E'  ), ord0_episodes as (',
  E'    union all select * from m10o\n',
  E'    union all select * from m10o\n    union all select * from m10p\n',
  E'''still_open''), (''inform_gp_done_within_7d_share'', null)\n',
  E'''still_open''), (''inform_gp_done_within_7d_share'', null),\n'
  || E'           -- SIG2-10\n'
  || E'           (''signal_outside_sent_share'', null), (''signal_taken_within_threshold_share'', null)\n',
  E'''signal_taken_share'', ''signal_minutes_to_take'')',
  E'''signal_taken_share'', ''signal_minutes_to_take'',\n'
  || E'                                 ''signal_taken_within_threshold_share'')'
]);

drop function private.sig2_patch(text, text[]);

-- 8b. Reader ----------------------------------------------------------------------------------------------------------
-- SIG2-5: the reader says when Operations got a signal because nobody was reachable outside the app (one more column;
-- the rest is the 0060 body unchanged).
drop function if exists public.my_signals();
create function public.my_signals()
returns table (signal_id uuid, signal_kind text, visit_id uuid, visit_date date, time_start time, team_id uuid,
               team_name text, reason text, delivered_at timestamptz, p1_at timestamptz,
               taken_by_me boolean, taken_by_name text, taken_at timestamptz, outside_none boolean)
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
           s.taken_at, s.outside_none_at is not null
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

-- 9. Privileges ---------------------------------------------------------------------------------------------------------
revoke all on function private.push_vendor_for_endpoint(text) from public, anon, authenticated;
revoke all on function private.push_vendors_counted() from public, anon, authenticated;
revoke all on function private.outside_channel_on(uuid) from public, anon, authenticated;
revoke all on function private.watched_raise_at(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.push_active(uuid) from public, anon, authenticated;
revoke all on function private.member_working_span(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.outside_classify(uuid) from public, anon, authenticated;
revoke all on function private.outside_settle(uuid) from public, anon, authenticated;
revoke all on function private.outside_after_evaluate(uuid) from public, anon, authenticated;
revoke all on function private.guard_signal_outside_delivery() from public, anon, authenticated;

revoke all on function public.set_outside_push(uuid, boolean, uuid) from public, anon;
grant execute on function public.set_outside_push(uuid, boolean, uuid) to authenticated;
revoke all on function public.set_watched_hours(uuid, jsonb, uuid) from public, anon;
grant execute on function public.set_watched_hours(uuid, jsonb, uuid) to authenticated;
revoke all on function public.register_push_subscription(text, text, text, uuid) from public, anon;
grant execute on function public.register_push_subscription(text, text, text, uuid) to authenticated;
revoke all on function public.unregister_push_subscription(text, uuid) from public, anon;
grant execute on function public.unregister_push_subscription(text, uuid) to authenticated;
revoke all on function public.my_push_state() from public, anon;
grant execute on function public.my_push_state() to authenticated;
revoke all on function public.team_push_status() from public, anon;
grant execute on function public.team_push_status() to authenticated;
revoke all on function public.record_push_tap() from public, anon;
grant execute on function public.record_push_tap() to authenticated;
-- The sender only: never a signed-in user.
revoke all on function public.push_dispatch_claim(integer) from public, anon, authenticated;
grant execute on function public.push_dispatch_claim(integer) to service_role;
revoke all on function public.push_dispatch_report(text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.push_dispatch_report(text, uuid, jsonb) to service_role;
