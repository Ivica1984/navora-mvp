-- COND1-5 (brief docs/agents/briefs/COND1.md): WORK1-C2 and WORK1-C3 (docs/agents/briefs/WORK1.md, PO 2026-10-26 08:15,
-- after `lca` 07:45, D-23 item 15). ADR-096. Builds on 0079 (WORK1), 0081 (COND1-3), 0074-0078 and 0080 (LEAVE1).
--
-- WORK1-C2 Information text v2. `private.working_time_notice_version()` returns `work1-notice-v2` (the text itself lives
--   in src/features/work/rules.ts NOTICE_PARAGRAPHS; still a draft for the employer, G-19 item 2). A v1 acknowledgement
--   does not carry over: `my_working_time_notice` reads the current version, so she sees v2 as not acknowledged, and
--   `my_working_day` returns nothing until she acknowledges v2 (both already compare with the current version, 0079 and
--   0081; no change needed there). `acknowledge_working_time_notice` accepts only v2 from now on ('invalid' for v1).
--   Existing v1 rows stay as they are (append-only; who acknowledged what, when).
-- WORK1-C3 A leaver's unexported days are counted, for administrators only (lca terms a-d).
--   * Definition (brief): a confirmed day counts as unexported if no export of its month was made after its latest
--     confirmed version. NAVORA can only know what it exported, not what the employer received (lca term c).
--   * Source of "an export of its month was made, and when". Until now an export left only an audit row (0079). The
--     count does NOT read the audit log: the v2 text tells her the log "is read only for a stated audit purpose", and
--     the AUD1-1 reader catalogue (0077) stays as it is. Instead `export_working_month` now also appends one row to
--     `working_day_exports` (who, organisation, month, when; no day, time, figure or content). Append-only, no table
--     privilege for any app role (not even her: no reader returns its rows or ids, D-23 item 15 (1)); read only by
--     `private.unexported_working_days`. The audit row is unchanged in content; its entity id is now this row's id.
--   * Order. "After" compares `working_day_exports.exported_at` with the latest version's `confirmed_at`; both are set by
--     the same clock (`private.now()`, DST1 test clock), strictly later. Two commands of hers in one transaction do not
--     occur in the app (each server action is its own request).
--   * `private.unexported_working_days(person, organisation)`: one integer, computed at the moment of the call; no
--     date, month, time or content leaves it; nothing is stored (lca term b). Organisation null = all of hers (/work).
--   * (a) `public.member_unexported_working_days(person)`: the count for an administrator of an organisation of hers
--     (`private.leave1_org_for`, the same scoping as end_member_access); null for everybody else (her team's registered
--     nurses, care assistants, coaches, Operations, another organisation's administrators). The LEAVE1-12 lists of the
--     RNs (`team_open_reports`, `member_open_reports`) are not changed. `end_member_access` returns `unexported_days`
--     in its result (never in its change-log or audit row: no stored per-person figure).
--   * (d) `public.my_unexported_working_days()`: her own count while her access is open (null after the end, LEAVE1-3).
--   * No export on her behalf is built (G-19 item 4; legal adviser).
--
-- No labour-law, clinical or tariff rule. Idempotent: create or replace / if not exists / drop if exists; the
-- end_member_access patch is skipped when its marker is present. A second run changes nothing.

-- 1. WORK1-C2: the information text version ----------------------------------------------------------------------------
create or replace function private.working_time_notice_version()
returns text language sql immutable set search_path = ''
as $$ select 'work1-notice-v2'::text $$;
revoke all on function private.working_time_notice_version() from public, anon;
grant execute on function private.working_time_notice_version() to authenticated;
comment on function private.working_time_notice_version() is
  'WORK1-8 / WORK1-C2: version of the fixed information text (src/features/work/rules.ts NOTICE_VERSION). A new text '
  'needs a new version and a new acknowledgement; an earlier acknowledgement does not carry over (v2 since 0083).';

-- 2. WORK1-C3: the export record ---------------------------------------------------------------------------------------
create table if not exists public.working_day_exports (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  user_id         uuid not null references auth.users (id),
  month           date not null check (extract(day from month) = 1),
  exported_at     timestamptz not null default private.now()
);
create index if not exists working_day_exports_user_idx on public.working_day_exports (user_id, month, exported_at);
comment on table public.working_day_exports is
  'WORK1-C3: one row per export of a month by the person herself (who, organisation, month, when; no day, time, figure '
  'or content). Append-only; no app role reads or writes it. Read only by private.unexported_working_days.';

alter table public.working_day_exports enable row level security;
revoke all on public.working_day_exports from public, anon, authenticated, service_role;
-- LEAVE1-3 (0074): the restrictive policy every table carries (no permissive policy: no app role reads a row).
drop policy if exists leave1_access_open on public.working_day_exports;
create policy leave1_access_open on public.working_day_exports as restrictive for all to authenticated
  using (not (select private.access_ended((select auth.uid()))));

drop trigger if exists working_day_exports_guard on public.working_day_exports;
create trigger working_day_exports_guard
  before update or delete on public.working_day_exports
  for each row execute function private.guard_working_day_record();
drop trigger if exists working_day_exports_no_truncate on public.working_day_exports;
create trigger working_day_exports_no_truncate
  before truncate on public.working_day_exports
  for each statement execute function private.guard_working_day_record();

-- 3. WORK1-4 export: also records the export (WORK1-C3); otherwise as 0079 ---------------------------------------------
create or replace function public.export_working_month(p_month date, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  today date := (private.at_zurich(private.now()))::date;
  m0    date;
  m1    date;
  org   uuid;
  dup   boolean;
  days  jsonb;
  open_ jsonb;
  n     integer;
  xid_  uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  dup := private.begin_command('export_working_month', p_idempotency_key);
  if p_month is null then
    return jsonb_build_object('result', private.end_command('invalid'));
  end if;
  m0 := date_trunc('month', p_month)::date;
  m1 := (date_trunc('month', p_month) + interval '1 month')::date;
  select coalesce(jsonb_agg(jsonb_build_object('date', w.work_date, 'version', w.version, 'confirmed_at', w.confirmed_at,
                                               'day_start', w.day_start, 'day_end', w.day_end,
                                               'breaks_answer', w.breaks_answer, 'outside_answer', w.outside_answer,
                                               'paid_minutes', w.paid_minutes,
                                               'entries', (select coalesce(jsonb_agg(e - 'from_proposal'), '[]'::jsonb)
                                                           from jsonb_array_elements(w.entries) e))
                            order by w.work_date), '[]'::jsonb), count(*)::integer
    into days, n
  from (select distinct on (v.work_date) v.* from public.working_day_versions v
        where v.user_id = uid and v.work_date >= m0 and v.work_date < m1
        order by v.work_date, v.version desc) w;
  -- Days with her own visit events and no confirmed version: listed by date, never filled.
  select coalesce(jsonb_agg(d order by d), '[]'::jsonb) into open_
  from (select distinct (private.at_zurich(e.occurred_at))::date as d from public.visit_events e
        where e.actor_id = uid and e.occurred_at >= private.at_zurich(m0::timestamp) - interval '1 day'
          and e.occurred_at < private.at_zurich(m1::timestamp) + interval '1 day') x
  where x.d >= m0 and x.d < m1 and x.d <= today
    and not exists (select 1 from public.working_day_versions w where w.user_id = uid and w.work_date = x.d);
  if not dup then
    org := private.working_day_org(uid, private.working_day_team(uid, today));
    if org is null then
      return jsonb_build_object('result', private.end_command('rejected'));
    end if;
    -- WORK1-C3: the export of this month is recorded (who, month, when), so a later count knows it was made.
    insert into public.working_day_exports (organization_id, user_id, month) values (org, uid, m0) returning id into xid_;
    perform private.audit_command(org, 'working_day_exports', xid_,
            jsonb_build_object('month', to_char(m0, 'YYYY-MM'), 'days', n, 'unconfirmed', jsonb_array_length(open_)));
  end if;
  return jsonb_build_object('result', private.end_command(case when dup then 'duplicate' else 'ok' end),
                            'month', to_char(m0, 'YYYY-MM'), 'days', days, 'unconfirmed', open_);
end;
$$;
revoke all on function public.export_working_month(date, uuid) from public, anon;
grant execute on function public.export_working_month(date, uuid) to authenticated;
comment on function public.export_working_month(date, uuid) is
  'WORK1-4: the signed-in person''s confirmed days of a month (latest version per day) for her CSV export; no client, '
  'case, address, visit identifier or note. Unconfirmed days by date. Audited (who, month, when, number of days). '
  'WORK1-C3: the export is recorded in working_day_exports (who, month, when) for the unexported-days count.';

-- 4. WORK1-C3: the count -----------------------------------------------------------------------------------------------
-- Never callable by an app role; only the three callers below pass a person, each after its own scoping.
create or replace function private.unexported_working_days(p_user uuid, p_org uuid)
returns integer language sql stable security definer set search_path = ''
as $$
  select count(*)::integer
  from (select distinct on (w.work_date) w.work_date, w.confirmed_at, w.organization_id
        from public.working_day_versions w
        where w.user_id = p_user
        order by w.work_date, w.version desc) l
  where p_user is not null
    and (p_org is null or l.organization_id = p_org)
    and not exists (select 1 from public.working_day_exports x
                    where x.user_id = p_user
                      and x.month = make_date(extract(year from l.work_date)::int, extract(month from l.work_date)::int, 1)
                      and x.exported_at > l.confirmed_at)
$$;
revoke all on function private.unexported_working_days(uuid, uuid) from public, anon, authenticated;
comment on function private.unexported_working_days(uuid, uuid) is
  'WORK1-C3: number of the person''s confirmed days (latest version per day) with no export of their month made after '
  'that version; organisation null = all of hers. One number, computed at the call; nothing stored.';

-- (d) Her own count on /work while her access is open.
create or replace function public.my_unexported_working_days()
returns integer language plpgsql stable security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null or private.access_ended(uid) then return null; end if;  -- LEAVE1-3
  return private.unexported_working_days(uid, null);
end;
$$;
revoke all on function public.my_unexported_working_days() from public, anon;
grant execute on function public.my_unexported_working_days() to authenticated;
comment on function public.my_unexported_working_days() is
  'WORK1-C3 (d): the signed-in person''s own number of confirmed days not yet exported (no person argument). Null '
  'after her access end.';

-- (a) The administrator's count in the LEAVE1-12 list, only for an organisation of hers the caller administers.
create or replace function public.member_unexported_working_days(p_user_id uuid)
returns integer language plpgsql stable security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null or private.access_ended(uid) then return null; end if;  -- LEAVE1-3
  if p_user_id is null then return null; end if;
  org := private.leave1_org_for(p_user_id);  -- an organisation of hers that the caller administers, else null
  if org is null then return null; end if;
  return private.unexported_working_days(p_user_id, org);
end;
$$;
revoke all on function public.member_unexported_working_days(uuid) from public, anon;
grant execute on function public.member_unexported_working_days(uuid) to authenticated;
comment on function public.member_unexported_working_days(uuid) is
  'WORK1-C3 (a): "Bestätigte Tage, die sie noch nicht exportiert hat": one number for one person at this moment, only '
  'for an administrator of her organisation (null for her team''s registered nurses and everybody else). No date, '
  'month, time or content.';

-- 5. end_member_access: the count in its result (WORK1-C3 (a)); never in the change log or audit row --------------------
create or replace function private.cond1_5_patch(p_fn text, p_old text, p_new text, p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  n := (length(def) - length(replace(def, p_old, ''))) / length(p_old);
  if n <> 1 then
    raise exception '0083 patch for % must match once, matched %: %', p_fn, n, p_old;
  end if;
  execute replace(def, p_old, p_new);
end;
$$;
revoke all on function private.cond1_5_patch(text, text, text, text) from public, anon, authenticated;

select private.cond1_5_patch('public.end_member_access(uuid, text, uuid)',
  E'                            ''taken_signals'', taken);\n',
  E'                            ''taken_signals'', taken,\n'
  || E'                            -- WORK1-C3 (a): her confirmed days not yet exported, one number, only in this result.\n'
  || E'                            ''unexported_days'', private.unexported_working_days(p_user_id, org));\n',
  'WORK1-C3');

drop function private.cond1_5_patch(text, text, text, text);
