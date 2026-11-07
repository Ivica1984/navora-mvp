-- SIG2 follow-up: SIG2-11 (CGR-42), SIG2-12 (D-32 addendum, `lca` 15:05), SIG2-13 (CGR-45) and SIG2-14 (clock-free
-- pgTAP) from the PO conditions of 2026-10-24 15:10, 19:09 and 20:09 (`docs/agents/briefs/SIG2.md`). ADR-078.
-- No clinical rule, threshold, priority, response duty or response time is decided here (D-28 stays open). The two
-- numbers used are the PO's operating limits from the brief: 5 minutes (SIG2-11) and 2 hours (SIG2-13).
--
-- Before (0062, 0063):
--   * SIG2-11: nothing records whether the scheduled evaluator runs. `private.signal_evaluations` is also written by
--     every page poll, so an open page hides a dead job. The outside send path starts only from a page poll or from an
--     external caller of `/api/push/dispatch` that nothing in the repository schedules.
--   * SIG2-12: a push to an Operations member (the SIG1 fallback, the SIG2-5 immediate step, the SIG2-7 untaken step)
--     leaves at any hour.
--   * SIG2-13: a look-ahead raise time is the end instant of the last watched period, which the inside test treats as
--     outside (`watched_raise_at` returns `e`, `inside` uses `< ends`).
-- Now (IMPLEMENTED in this migration):
--   1. SIG2-11 (1): `private.signal_scheduler_runs` records, per organisation, the time of the last run of the
--      scheduled evaluator (`private.evaluate_all_signals`, the pg_cron job `navora-sig1-signals`). A page poll does not
--      write it.
--   2. SIG2-11 (2): `private.signal_evaluator_live(org)` is true while that run is at most 5 minutes old. Reader
--      `public.signal_evaluator_health()` (Operations and administrators of the organisation only) feeds
--      "Signalprüfung läuft nicht" on /operations and /admin. `my_push_state` and `team_push_status` report the outside
--      channel as active only while the evaluator is live.
--   3. SIG2-11 (3): each scheduled run also asks the sender to dispatch (`private.push_dispatch_kick`: pg_net POST to
--      `/api/push/dispatch` with the dispatch secret, both read from Supabase Vault). Without pg_net or without the two
--      Vault entries nothing is called (the owner sets them in the pilot project, OWNER_RUNBOOK); pending rows then fail
--      after 2 minutes and the signal goes to Operations at once, as before (fail closed). The page poll may still kick.
--      The job is (re)scheduled idempotently where pg_cron exists.
--   4. SIG2-12: `private.watched_inside(org, t)` (start inclusive, end exclusive, Europe/Zurich wall time) decides an
--      Operations push: inside a watched period → handed to the sender; outside, or with no watched hours recorded →
--      `outside_working_time` (in the app only). Responsible member and colleague rules are unchanged.
--   5. SIG2-13: the raise time is the later of the start of the last watched period that ends at or before the window
--      opens and that period's end minus 2 hours; it is inside by the SIG2-12 predicate and never later than before.
--   6. SIG2-14: the look-ahead predicate is one function with the instant as an argument
--      (`private.lookahead_raised(org, now, window_opens)`), so pgTAP asserts it at fixed instants.
-- Unchanged: SIG1 recipients and thresholds, SIG1-C1, the 2-minute sender timeout, the payload, RLS of the 0062 tables.

-- 0. Patch helper (each pattern must match exactly once; idempotent through a marker in the patched body) --------------
create function private.c64_patch(p_fn text, p_pairs text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception '0064 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0064 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.c64_patch(text, text[], text) from public, anon, authenticated;

-- 1. Watched hours: inside predicate and raise time (SIG2-12, SIG2-13) -------------------------------------------------
-- Inside a watched period: start inclusive, end exclusive ('24:00' = midnight at the end of the day).
create or replace function private.watched_inside(p_org uuid, p_t timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_watched_hours h
    where h.organization_id = p_org
      and h.weekday = extract(isodow from (p_t at time zone 'Europe/Zurich'))::int
      and h.starts <= (p_t at time zone 'Europe/Zurich')::time
      and (h.ends = time '24:00' or (p_t at time zone 'Europe/Zurich')::time < h.ends)
  )
$$;

-- SIG2-6 with SIG2-13: p_t when no watched hours are recorded or p_t is inside; otherwise, of the last watched period
-- that ends at or before p_t, the later of its start and its end minus 2 hours (inside, earlier, never later).
create or replace function private.watched_raise_at(p_org uuid, p_t timestamptz)
returns timestamptz language sql stable security definer set search_path = ''
as $$
  with local as (select (p_t at time zone 'Europe/Zurich') as lt),
  periods as (
    select ((l.lt::date - d) + h.starts) at time zone 'Europe/Zurich' as s,
           ((l.lt::date - d) + h.ends) at time zone 'Europe/Zurich' as e
    from local l cross join generate_series(0, 7) d
    join public.organization_watched_hours h
      on h.organization_id = p_org and h.weekday = extract(isodow from (l.lt::date - d))::int
  ),
  last_period as (
    select p.s, p.e from periods p where p.e <= p_t order by p.e desc limit 1
  )
  select case
    when not exists (select 1 from public.organization_watched_hours h where h.organization_id = p_org) then p_t
    when private.watched_inside(p_org, p_t) then p_t
    else coalesce((select greatest(lp.s, lp.e - interval '2 hours') from last_period lp), p_t) end
$$;

-- SIG2-14: the look-ahead predicate with the instant as an argument (derived_exceptions passes now()).
create or replace function private.lookahead_raised(p_org uuid, p_now timestamptz, p_window_opens timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$ select p_now >= private.watched_raise_at(p_org, p_window_opens) $$;

select private.c64_patch('private.derived_exceptions(uuid)', array[
  E'             and now() >= private.watched_raise_at(p_org,\n',
  E'             and private.lookahead_raised(p_org, now(), /* SIG2-14 (ADR-078) */\n'
], 'SIG2-14 (ADR-078)');
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- 2. SIG2-12: an Operations push only inside watched hours ------------------------------------------------------------
select private.c64_patch('private.outside_classify(uuid)', array[
  E'                then ''outside_working_time''\n              else ''pending'' end',
  E'                then ''outside_working_time''\n'
  || E'              -- SIG2-12 (ADR-078): Operations outside the app only while a watched period runs\n'
  || E'              when d.reason in (''operations_fallback'', ''untaken'')\n'
  || E'                   and not private.watched_inside(p_org, now())\n'
  || E'                then ''outside_working_time''\n'
  || E'              else ''pending'' end'
], 'SIG2-12 (ADR-078)');

-- 3. SIG2-11: the scheduled evaluator is seen to run -------------------------------------------------------------------
create table if not exists private.signal_scheduler_runs (
  organization_id uuid primary key references public.organizations (id),
  ran_at          timestamptz not null
);
revoke all on private.signal_scheduler_runs from public, anon, authenticated;
comment on table private.signal_scheduler_runs is
  'SIG2-11: the last run of the scheduled signal evaluator per organisation (pg_cron job navora-sig1-signals). Page polls do not write it.';

-- Live = the last scheduled run is at most 5 minutes old (the job runs every minute; PO operating limit).
create or replace function private.signal_evaluator_live(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from private.signal_scheduler_runs r
                 where r.organization_id = p_org and r.ran_at >= now() - interval '5 minutes')
$$;

-- SIG2-11 (3): ask the sender to dispatch. pg_net and two Vault entries (`navora_push_dispatch_url`,
-- `navora_push_dispatch_secret`) are needed; otherwise nothing is called and the 2-minute timeout keeps it fail closed.
-- Dynamic SQL: the function compiles where neither pg_net nor Vault exists (CI, local).
create or replace function private.push_dispatch_kick()
returns boolean language plpgsql security definer set search_path = ''
as $$
declare
  url    text;
  secret text;
begin
  if not exists (select 1 from public.organization_push_settings s where s.enabled) then return false; end if;
  if not exists (select 1 from pg_extension where extname = 'pg_net')
     or not exists (select 1 from pg_extension where extname = 'supabase_vault') then
    return false;
  end if;
  execute $q$select max(decrypted_secret) filter (where name = 'navora_push_dispatch_url'),
                    max(decrypted_secret) filter (where name = 'navora_push_dispatch_secret')
             from vault.decrypted_secrets
             where name in ('navora_push_dispatch_url', 'navora_push_dispatch_secret')$q$
    into url, secret;
  if url is null or url !~ '^https://' or secret is null or length(secret) < 32 then return false; end if;
  execute $q$select net.http_post(url := $1, body := '{}'::jsonb,
                                  headers := jsonb_build_object('Authorization', 'Bearer ' || $2, 'Content-Type', 'application/json'),
                                  timeout_milliseconds := 10000)$q$
    using url, secret;
  return true;
exception when others then
  raise notice 'SIG2-11: dispatch request not sent (%)', sqlstate;
  return false;
end;
$$;

-- The scheduled entry point: evaluate every organisation, record the run, then ask the sender to dispatch.
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
    -- SIG2-11 (ADR-078): this run is the scheduled evaluator (page polls call evaluate_signals directly).
    insert into private.signal_scheduler_runs (organization_id, ran_at) values (org, now())
    on conflict (organization_id) do update set ran_at = excluded.ran_at;
  end loop;
  perform private.push_dispatch_kick();
  return n;
end;
$$;

-- Reader for /operations and /admin: per organisation in which the caller is Operations or administrator.
create or replace function public.signal_evaluator_health()
returns table (organization_id uuid, last_run_at timestamptz, running boolean)
language sql stable security definer set search_path = ''
as $$
  select m.organization_id, r.ran_at, private.signal_evaluator_live(m.organization_id)
  from public.organization_memberships m
  left join private.signal_scheduler_runs r on r.organization_id = m.organization_id
  where m.user_id = (select auth.uid()) and m.role in ('operations', 'admin')
  order by m.organization_id
$$;

-- SIG2-11 (2): /settings and /team say "aktiv" only while the evaluator of that organisation runs.
create or replace function public.my_push_state()
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'channel_on', exists (select 1 from public.organization_memberships m
                          where m.user_id = (select auth.uid()) and private.outside_channel_on(m.organization_id)),
    'active', exists (select 1 from public.push_subscriptions s
                      where s.user_id = (select auth.uid()) and s.last_result = 'sent'
                        and private.signal_evaluator_live(s.organization_id)),
    'evaluator_running', coalesce((select bool_and(private.signal_evaluator_live(m.organization_id))
                                   from public.organization_memberships m where m.user_id = (select auth.uid())), false),
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

create or replace function public.team_push_status()
returns table (team_id uuid, team_name text, user_id uuid, member_name text, active boolean)
language sql stable security definer set search_path = ''
as $$
  select t.id, t.name, tm.user_id, coalesce(private.member_name(t.organization_id, tm.user_id), 'Teammitglied'),
         private.push_active(tm.user_id) and private.signal_evaluator_live(t.organization_id)
  from public.team_memberships mine
  join public.teams t on t.id = mine.team_id
  join public.team_memberships tm on tm.team_id = t.id
  where mine.user_id = (select auth.uid()) and private.is_org_member(t.organization_id)
  order by t.name, 4, tm.user_id
$$;

-- The job every minute where pg_cron exists (cron.schedule with the same name replaces it: idempotent).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      execute $cron$select cron.schedule('navora-sig1-signals', '* * * * *', 'select private.evaluate_all_signals()')$cron$;
    exception when others then
      raise notice 'SIG2-11: signal job not scheduled (%); /operations and /admin show "Signalprüfung läuft nicht"', sqlerrm;
    end;
  else
    raise notice 'SIG2-11: pg_cron not available; /operations and /admin show "Signalprüfung läuft nicht"';
  end if;
end;
$$;

drop function private.c64_patch(text, text[], text);

-- 4. Privileges ---------------------------------------------------------------------------------------------------------
revoke all on function private.watched_inside(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.watched_raise_at(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.lookahead_raised(uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.signal_evaluator_live(uuid) from public, anon, authenticated;
revoke all on function private.push_dispatch_kick() from public, anon, authenticated;
revoke all on function private.evaluate_all_signals() from public, anon, authenticated;
revoke all on function private.outside_classify(uuid) from public, anon, authenticated;
revoke all on function public.signal_evaluator_health() from public, anon;
grant execute on function public.signal_evaluator_health() to authenticated;
revoke all on function public.my_push_state() from public, anon;
grant execute on function public.my_push_state() to authenticated;
revoke all on function public.team_push_status() from public, anon;
grant execute on function public.team_push_status() to authenticated;
