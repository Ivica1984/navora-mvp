-- WORK1: the working day is proposed from the visits; the nurse confirms it instead of filling a timesheet
-- (PO brief docs/agents/briefs/WORK1.md, ADR-092; builds D-23 C plus D). Synthetic data only until go-live gate G-19.
--
-- Design (answers to the brief's engineering questions):
-- 1. Proposal (WORK1-1). `private.working_day_proposal(user, date)` derives segments from the person's OWN visit
--    events (`visit_events.actor_id`): for each of her events on that Zurich day, the segment runs to her next event of
--    the same visit (departed → travel, started/resumed → care, paused → visit_pause); a last event without a
--    successor gives an open segment (end null, never filled). Start and end are the stored instants (D-23 item 8a);
--    time corrections (F3) are not applied, she corrects in her confirmation. Open question 1: no report segment is
--    derived. A sign time (F7) has no reliable start (the draft is written during or after the visit), so the proposal
--    shows it as a point (`report_signed`, start = end = signed_at) and report time written later is entered by her as
--    "Administration". No location, client, case or visit identifier leaves the helper (visit_no is an ordinal).
--    `public.my_working_day(date)` returns it only to the signed-in person, for herself, after the information text
--    (WORK1-8) is acknowledged.
-- 2. Storage (open question 2). One append-only table `working_day_versions`, one row per confirmed version, the
--    entries (visit segments, breaks, work outside visits) as a validated JSON array. Readable only by the person
--    herself (one permissive policy `user_id = auth.uid()` plus the LEAVE1 restrictive policy); no command other
--    than `confirm_working_day` writes it. The day's numbers (paid, care, break minutes) are computed once by the
--    command from the stored instants (elapsed time, so the repeated hour of 25 October counts its real length).
-- 3. The day is never complete by default (WORK1-2): `breaks` and `outside_work` must each be "none" or a non-empty
--    list; anything else is `questions_open`. Day start and end are entered by her ("Beginn/Ende des Arbeitstags?").
-- 4. Paid minutes = elapsed(day start → day end) − breaks of 30 minutes or more (deviation from the brief's
--    "all segments minus breaks", ADR-092 (1): subtracting breaks presumes a span; the record content as `lca` read
--    ArGV 1 Art. 73 is start, end and breaks). Care minutes = the care entries she confirmed.
-- 5. Team North Star (WORK1-6): `pilot_kpis` replaces the placeholder team row `direct_care_share` by the ratio from
--    `private.team_confirmed_care_share(month)`; latest version per day, confirmed days only; hidden (value and base
--    null, too_few) when fewer than 3 people or fewer than 5 confirmed days. The organisation row stays a note (no
--    organisation figure, so no hidden team can be derived by difference).
-- 6. Nothing else reads the tables (WORK1-5, WORK1-7): no billing, J5, export-to-payer, push or signal function.
-- 7. Audit (WORK1-3, -4, -8): versions (work date, version, reason code; never the note, never a time of day),
--    acknowledgements (text version), exports (month, number of days, number of unconfirmed days). Idempotent commands.
-- No labour-law rule: no check or warning on breaks, rest, daily or weekly maxima (D-23 item 8). No clinical rule.
-- Idempotent: re-running this file changes nothing.

-- 0. Index for the person's own events (no reader gains a row) --------------------------------------------------------
create index if not exists visit_events_actor_idx on public.visit_events (actor_id, occurred_at);

-- 1. Information text acknowledgement (WORK1-8) -------------------------------------------------------------------------
create or replace function private.working_time_notice_version()
returns text language sql immutable set search_path = ''
as $$ select 'work1-notice-v1'::text $$;
revoke all on function private.working_time_notice_version() from public, anon;
grant execute on function private.working_time_notice_version() to authenticated;
comment on function private.working_time_notice_version() is
  'WORK1-8: version of the fixed information text (src/features/work/rules.ts NOTICE_VERSION). A new text needs a new '
  'version and a new acknowledgement.';

create table if not exists public.working_time_notice_acks (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  user_id         uuid not null references auth.users (id),
  text_version    text not null check (text_version ~ '^[a-z0-9-]{1,40}$'),
  acknowledged_at timestamptz not null default private.now(),
  unique (user_id, text_version)
);
comment on table public.working_time_notice_acks is
  'WORK1-8: the person acknowledged the information text (who, text version, when). Readable only by herself.';

-- 2. Confirmed day versions (WORK1-3) ---------------------------------------------------------------------------------
create table if not exists public.working_day_versions (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  user_id         uuid not null references auth.users (id),
  team_id         uuid references public.teams (id),
  work_date       date not null,
  version         integer not null check (version >= 1),
  day_start       timestamptz not null,
  day_end         timestamptz not null,
  breaks_answer   text not null check (breaks_answer in ('none', 'listed')),
  outside_answer  text not null check (outside_answer in ('none', 'listed')),
  entries         jsonb not null check (jsonb_typeof(entries) = 'array'),
  paid_minutes    numeric(7, 1) not null check (paid_minutes >= 0),
  care_minutes    numeric(7, 1) not null check (care_minutes >= 0),
  break_minutes   numeric(7, 1) not null check (break_minutes >= 0),
  reason_code     text check (reason_code in ('segment_missing', 'time_wrong', 'break_missing', 'other')),
  note            text check (note is null or char_length(note) between 1 and 200),
  confirmed_at    timestamptz not null default private.now(),
  unique (user_id, work_date, version),
  check (day_end > day_start),
  check ((version = 1) = (reason_code is null)),
  check (version > 1 or note is null)
);
create index if not exists working_day_versions_team_idx on public.working_day_versions (team_id, work_date);
comment on table public.working_day_versions is
  'WORK1-3: a confirmed working day, append-only, one row per version. Readable only by the person herself (WORK1-5); '
  'written only by confirm_working_day. Never read by billing (WORK1-7). The team sees only the WORK1-6 ratio.';
comment on column public.working_day_versions.note is
  'WORK1-3: optional note of a correction (at most 200 characters). Only she reads it; never audited, never exported.';
comment on column public.working_day_versions.entries is
  'WORK1-3: [{kind, start, end, minutes, from_proposal}] with kind travel | care | visit_pause | break | team_meeting '
  '| training | administration | on_call | call_out_travel | other. Instants as stored; minutes are elapsed time.';

-- 3. Privileges, RLS (only she reads), append-only, audit ---------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['working_time_notice_acks', 'working_day_versions'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('drop policy if exists own_rows_read on public.%I', t);
    execute format('create policy own_rows_read on public.%I for select to authenticated '
                   'using (user_id = (select auth.uid()))', t);
    -- LEAVE1-3 (0074): the restrictive policy every readable table carries.
    execute format('drop policy if exists leave1_access_open on public.%I', t);
    execute format('create policy leave1_access_open on public.%I as restrictive for all to authenticated '
                   'using (not (select private.access_ended((select auth.uid()))))', t);
  end loop;
end;
$$;

create or replace function private.guard_working_day_record()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception '% is append-only', tg_table_name using errcode = '42501';
end;
$$;
revoke all on function private.guard_working_day_record() from public, anon, authenticated;

drop trigger if exists working_day_versions_guard on public.working_day_versions;
create trigger working_day_versions_guard
  before update or delete on public.working_day_versions
  for each row execute function private.guard_working_day_record();
drop trigger if exists working_day_versions_no_truncate on public.working_day_versions;
create trigger working_day_versions_no_truncate
  before truncate on public.working_day_versions
  for each statement execute function private.guard_working_day_record();
drop trigger if exists working_time_notice_acks_guard on public.working_time_notice_acks;
create trigger working_time_notice_acks_guard
  before update or delete on public.working_time_notice_acks
  for each row execute function private.guard_working_day_record();
drop trigger if exists working_time_notice_acks_no_truncate on public.working_time_notice_acks;
create trigger working_time_notice_acks_no_truncate
  before truncate on public.working_time_notice_acks
  for each statement execute function private.guard_working_day_record();

-- Audit: codes only (date, version, reason code, text version). Never the note, never a time of the day.
drop trigger if exists audit_working_day_versions on public.working_day_versions;
create trigger audit_working_day_versions
  after insert on public.working_day_versions
  for each row execute function private.write_audit_event('work_date', 'version', 'reason_code');
drop trigger if exists audit_working_time_notice_acks on public.working_time_notice_acks;
create trigger audit_working_time_notice_acks
  after insert on public.working_time_notice_acks
  for each row execute function private.write_audit_event('text_version');

-- AUD1-1 value catalogue (0077): every audited key is classified.
insert into private.audit_value_classes (table_name, key, class) values
  ('working_day_versions',     'work_date',    'code'),
  ('working_day_versions',     'version',      'code'),
  ('working_day_versions',     'reason_code',  'code'),
  ('working_time_notice_acks', 'text_version', 'code'),
  ('working_day_exports',      'month',        'code'),
  ('working_day_exports',      'days',         'code'),
  ('working_day_exports',      'unconfirmed',  'code')
on conflict do nothing;

-- 4. Helpers ---------------------------------------------------------------------------------------------------------
-- The person's organisation and team for a day: her one team, else the one team of her events that day, else none.
create or replace function private.working_day_team(p_user uuid, p_date date)
returns uuid language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select min(tm.team_id::text)::uuid from public.team_memberships tm where tm.user_id = p_user
     having count(*) = 1),
    (select min(e.team_id::text)::uuid from public.visit_events e
     where e.actor_id = p_user and (private.at_zurich(e.occurred_at))::date = p_date and e.team_id is not null
       and exists (select 1 from public.team_memberships tm where tm.user_id = p_user and tm.team_id = e.team_id)
     having count(distinct e.team_id) = 1))
$$;
revoke all on function private.working_day_team(uuid, date) from public, anon, authenticated;

create or replace function private.working_day_org(p_user uuid, p_team uuid)
returns uuid language sql stable security definer set search_path = ''
as $$
  select coalesce((select t.organization_id from public.teams t where t.id = p_team),
                  (select min(m.organization_id::text)::uuid from public.organization_memberships m where m.user_id = p_user))
$$;
revoke all on function private.working_day_org(uuid, uuid) from public, anon, authenticated;

create or replace function private.working_minutes(p_start timestamptz, p_end timestamptz)
returns numeric language sql immutable set search_path = ''
as $$ select round((extract(epoch from (p_end - p_start)) / 60)::numeric, 1) $$;
revoke all on function private.working_minutes(timestamptz, timestamptz) from public, anon, authenticated;
comment on function private.working_minutes(timestamptz, timestamptz) is
  'WORK1-3: elapsed minutes between two stored instants (real length, also across a clock change).';

-- WORK1-1: the proposal. Never callable by an app role; only my_working_day, confirm_working_day and
-- export_working_month call it, always with the caller's own id.
create or replace function private.working_day_proposal(p_user uuid, p_date date)
returns table (seq integer, visit_no integer, kind text, starts_at timestamptz, ends_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  with own as (
    select e.id, e.visit_id, e.event_type, e.occurred_at,
           lead(e.occurred_at) over (partition by e.visit_id order by e.occurred_at, e.id) as next_at
    from public.visit_events e
    where p_user is not null and e.actor_id = p_user
      and e.visit_id in (select x.visit_id from public.visit_events x
                         where x.actor_id = p_user and (private.at_zurich(x.occurred_at))::date = p_date)
  ), seg as (
    select o.visit_id, o.id,
           case o.event_type when 'departed' then 'travel' when 'paused' then 'visit_pause' else 'care' end as kind,
           o.occurred_at as starts_at, o.next_at as ends_at
    from own o
    where o.event_type in ('departed', 'started', 'resumed', 'paused')
      and (private.at_zurich(o.occurred_at))::date = p_date
  ), numbered as (
    select s.*, dense_rank() over (order by v.first_at, s.visit_id)::integer as visit_no
    from seg s join (select visit_id, min(starts_at) as first_at from seg group by visit_id) v on v.visit_id = s.visit_id
  ), marks as (
    select null::integer as visit_no, 'report_signed'::text as kind, r.signed_at as starts_at, r.signed_at as ends_at,
           0::bigint as id
    from public.visit_reports r
    where p_user is not null and r.signed_by = p_user and r.signed_at is not null
      and (private.at_zurich(r.signed_at))::date = p_date
  )
  select (row_number() over (order by a.starts_at, a.visit_no nulls last, a.id))::integer, a.visit_no, a.kind,
         a.starts_at, a.ends_at
  from (select n.visit_no, n.kind, n.starts_at, n.ends_at, n.id from numbered n
        union all
        select m.visit_no, m.kind, m.starts_at, m.ends_at, m.id from marks m) a
  order by 1
$$;
revoke all on function private.working_day_proposal(uuid, date) from public, anon, authenticated;
comment on function private.working_day_proposal(uuid, date) is
  'WORK1-1: segments from the person''s own visit events of a Zurich day (stored instants, open end = null; a report '
  'sign time as a point). No location, client, case or visit identifier. Called only with the caller''s own id.';

-- WORK1-6: confirmed days per team and month (latest version per person and day). Never per person in any result.
create or replace function private.team_confirmed_care_share(p_month date)
returns table (team_id uuid, people integer, days integer, value numeric, too_few boolean)
language sql stable security definer set search_path = ''
as $$
  with latest as (
    select distinct on (w.user_id, w.work_date) w.team_id, w.user_id, w.care_minutes, w.paid_minutes
    from public.working_day_versions w
    where w.team_id is not null
      and w.work_date >= date_trunc('month', p_month)::date
      and w.work_date < (date_trunc('month', p_month) + interval '1 month')::date
    order by w.user_id, w.work_date, w.version desc
  )
  select l.team_id, count(distinct l.user_id)::integer, count(*)::integer,
         round(100.0 * sum(l.care_minutes) / nullif(sum(l.paid_minutes), 0), 1),
         (count(distinct l.user_id) < 3 or count(*) < 5)
  from latest l
  group by l.team_id
$$;
revoke all on function private.team_confirmed_care_share(date) from public, anon, authenticated;
comment on function private.team_confirmed_care_share(date) is
  'WORK1-6: care minutes ÷ paid minutes of the confirmed days per team and month; too_few when fewer than 3 people '
  'or fewer than 5 confirmed days (AN1 suppression). Read only by pilot_kpis.';

-- 5. Read models (only for herself) ------------------------------------------------------------------------------------
create or replace function public.my_working_time_notice()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  at_ timestamptz;
begin
  if uid is null or private.access_ended(uid) then return null; end if;  -- LEAVE1-3
  select a.acknowledged_at into at_ from public.working_time_notice_acks a
  where a.user_id = uid and a.text_version = private.working_time_notice_version();
  return jsonb_build_object('text_version', private.working_time_notice_version(),
                            'acknowledged', at_ is not null, 'acknowledged_at', at_);
end;
$$;
revoke all on function public.my_working_time_notice() from public, anon;
grant execute on function public.my_working_time_notice() to authenticated;

create or replace function public.my_working_day(p_date date)
returns table (seq integer, visit_no integer, kind text, starts_at timestamptz, ends_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
declare
  uid uuid := (select auth.uid());
begin
  if private.access_ended(uid) then return; end if;  -- LEAVE1-3
  if uid is null or p_date is null then return; end if;
  -- WORK1-8: no proposal before the information text is acknowledged.
  if not exists (select 1 from public.working_time_notice_acks a
                 where a.user_id = uid and a.text_version = private.working_time_notice_version()) then
    return;
  end if;
  return query select p.seq, p.visit_no, p.kind, p.starts_at, p.ends_at from private.working_day_proposal(uid, p_date) p;
end;
$$;
revoke all on function public.my_working_day(date) from public, anon;
grant execute on function public.my_working_day(date) to authenticated;
comment on function public.my_working_day(date) is
  'WORK1-1: the signed-in person''s own working-day proposal for a Zurich day (nobody else''s, no person argument). '
  'Empty until the WORK1-8 information text is acknowledged.';

create or replace function public.my_working_day_versions(p_date date)
returns table (version integer, confirmed_at timestamptz, day_start timestamptz, day_end timestamptz,
               breaks_answer text, outside_answer text, entries jsonb, paid_minutes numeric, care_minutes numeric,
               break_minutes numeric, reason_code text, note text)
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
declare
  uid uuid := (select auth.uid());
begin
  if private.access_ended(uid) then return; end if;  -- LEAVE1-3
  return query
    select w.version, w.confirmed_at, w.day_start, w.day_end, w.breaks_answer, w.outside_answer, w.entries,
           w.paid_minutes, w.care_minutes, w.break_minutes, w.reason_code, w.note
    from public.working_day_versions w
    where uid is not null and w.user_id = uid and w.work_date = p_date
    order by w.version desc;
end;
$$;
revoke all on function public.my_working_day_versions(date) from public, anon;
grant execute on function public.my_working_day_versions(date) to authenticated;
comment on function public.my_working_day_versions(date) is
  'WORK1-3: every confirmed version of the signed-in person''s day, newest first (earlier versions stay readable to her).';

-- 6. Commands ----------------------------------------------------------------------------------------------------------
-- WORK1-8. Return: {"result": "ok" | "unchanged" | "duplicate" | "invalid" | "rejected"}
create or replace function public.acknowledge_working_time_notice(p_text_version text, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('acknowledge_working_time_notice', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if p_text_version is distinct from private.working_time_notice_version() then
    return jsonb_build_object('result', private.end_command('invalid'));
  end if;
  if exists (select 1 from public.working_time_notice_acks a where a.user_id = uid and a.text_version = p_text_version) then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;
  org := private.working_day_org(uid, private.working_day_team(uid, (private.at_zurich(private.now()))::date));
  if org is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  insert into public.working_time_notice_acks (organization_id, user_id, text_version) values (org, uid, p_text_version);
  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.acknowledge_working_time_notice(text, uuid) from public, anon;
grant execute on function public.acknowledge_working_time_notice(text, uuid) to authenticated;

-- Parses one entry {kind, start, end}; null when malformed (caller answers `invalid`).
create or replace function private.working_entry(p_entry jsonb, p_kinds text[])
returns jsonb language plpgsql stable set search_path = ''
as $$
declare
  s timestamptz;
  e timestamptz;
begin
  if p_entry is null or jsonb_typeof(p_entry) <> 'object' or not (p_entry ->> 'kind' = any (p_kinds))
     or jsonb_typeof(p_entry -> 'start') <> 'string' or jsonb_typeof(p_entry -> 'end') <> 'string' then
    return null;
  end if;
  -- An instant must carry its offset (no local time is guessed).
  if (p_entry ->> 'start') !~ '(Z|[+-]\d\d:?\d\d)$' or (p_entry ->> 'end') !~ '(Z|[+-]\d\d:?\d\d)$' then
    return null;
  end if;
  begin
    s := (p_entry ->> 'start')::timestamptz;
    e := (p_entry ->> 'end')::timestamptz;
  exception when others then
    return null;
  end;
  if e <= s then return null; end if;
  return jsonb_build_object('kind', p_entry ->> 'kind', 'start', s, 'end', e,
                            'minutes', private.working_minutes(s, e));
end;
$$;
revoke all on function private.working_entry(jsonb, text[]) from public, anon, authenticated;

-- WORK1-2 / WORK1-3. Payload:
--   {"day_start": instant, "day_end": instant,
--    "segments": [{"kind": "travel"|"care"|"visit_pause", "start", "end"}],
--    "breaks": "none" | [{"start", "end"}],
--    "outside_work": "none" | [{"kind": "team_meeting"|"training"|"administration"|"on_call"|"call_out_travel"|"other",
--                               "start", "end"}],
--    "reason_code": (version 2 on) "segment_missing"|"time_wrong"|"break_missing"|"other", "note": text ≤ 200}
-- Return: {"result": "ok", "version": n} | {"result": "duplicate"} | {"result": "future"} | {"result": "questions_open",
--   "open": [...]} | {"result": "invalid", "field": ...} | {"result": "rejected"}. Access ended: 42501 access_ended.
create or replace function public.confirm_working_day(p_date date, p_payload jsonb, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  today    date := (private.at_zurich(private.now()))::date;
  team     uuid;
  org      uuid;
  ds       timestamptz;
  de       timestamptz;
  open_    text[] := '{}';
  entries  jsonb := '[]'::jsonb;
  x        jsonb;
  y        jsonb;
  ver      integer;
  reason   text;
  note_    text;
  b_ans    text;
  o_ans    text;
  brk      numeric := 0;
  care     numeric := 0;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('confirm_working_day', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if p_date is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'payload');
  end if;
  if p_date > today then
    return jsonb_build_object('result', private.end_command('future'));
  end if;

  -- WORK1-2: both questions answered explicitly; nothing is pre-answered.
  if not (p_payload -> 'breaks' = '"none"'::jsonb
          or (jsonb_typeof(p_payload -> 'breaks') = 'array' and jsonb_array_length(p_payload -> 'breaks') > 0)) then
    open_ := open_ || 'breaks'::text;
  end if;
  if not (p_payload -> 'outside_work' = '"none"'::jsonb
          or (jsonb_typeof(p_payload -> 'outside_work') = 'array' and jsonb_array_length(p_payload -> 'outside_work') > 0)) then
    open_ := open_ || 'outside_work'::text;
  end if;
  if jsonb_typeof(p_payload -> 'day_start') is distinct from 'string' then open_ := open_ || 'day_start'::text; end if;
  if jsonb_typeof(p_payload -> 'day_end') is distinct from 'string' then open_ := open_ || 'day_end'::text; end if;
  if cardinality(open_) > 0 then
    return jsonb_build_object('result', private.end_command('questions_open'), 'open', to_jsonb(open_));
  end if;

  -- Day start and end: instants with offset; the start lies on the confirmed Zurich day; one day at most 24 hours.
  x := private.working_entry(jsonb_build_object('kind', 'day', 'start', p_payload -> 'day_start', 'end', p_payload -> 'day_end'),
                             array['day']);
  if x is null then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'day');
  end if;
  ds := (x ->> 'start')::timestamptz;
  de := (x ->> 'end')::timestamptz;
  if (private.at_zurich(ds))::date <> p_date or de - ds > interval '24 hours' then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'day');
  end if;

  -- Visit segments (may be empty: a day without visits).
  if p_payload ? 'segments' and jsonb_typeof(p_payload -> 'segments') <> 'array' then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'segments');
  end if;
  for y in select v from jsonb_array_elements(coalesce(p_payload -> 'segments', '[]'::jsonb)) v loop
    x := private.working_entry(y, array['travel', 'care', 'visit_pause']);
    if x is null then
      return jsonb_build_object('result', private.end_command('invalid'), 'field', 'segments');
    end if;
    entries := entries || jsonb_build_array(x || jsonb_build_object('from_proposal', exists (
      select 1 from private.working_day_proposal(uid, p_date) p
      where p.kind = x ->> 'kind' and p.starts_at = (x ->> 'start')::timestamptz and p.ends_at = (x ->> 'end')::timestamptz)));
  end loop;

  -- Question 1: breaks of 30 minutes or more. The threshold is the content of the question; no value is refused or
  -- warned on (D-23 item 8).
  if p_payload -> 'breaks' = '"none"'::jsonb then
    b_ans := 'none';
  else
    b_ans := 'listed';
    for y in select v from jsonb_array_elements(p_payload -> 'breaks') v loop
      x := case when jsonb_typeof(y) = 'object'
                then private.working_entry(y || '{"kind": "break"}'::jsonb, array['break']) end;
      if x is null then
        return jsonb_build_object('result', private.end_command('invalid'), 'field', 'breaks');
      end if;
      entries := entries || jsonb_build_array(x || jsonb_build_object('from_proposal', false));
    end loop;
  end if;

  -- Question 2: work outside visits from the fixed list.
  if p_payload -> 'outside_work' = '"none"'::jsonb then
    o_ans := 'none';
  else
    o_ans := 'listed';
    for y in select v from jsonb_array_elements(p_payload -> 'outside_work') v loop
      x := private.working_entry(y, array['team_meeting', 'training', 'administration', 'on_call', 'call_out_travel', 'other']);
      if x is null then
        return jsonb_build_object('result', private.end_command('invalid'), 'field', 'outside_work');
      end if;
      entries := entries || jsonb_build_array(x || jsonb_build_object('from_proposal', false));
    end loop;
  end if;

  -- Every entry lies inside the day; breaks do not overlap each other (they would be counted twice).
  if exists (select 1 from jsonb_array_elements(entries) e
             where (e ->> 'start')::timestamptz < ds or (e ->> 'end')::timestamptz > de) then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'outside_day');
  end if;
  if exists (select 1 from jsonb_array_elements(entries) with ordinality a(v, i),
                          jsonb_array_elements(entries) with ordinality b(w, j)
             where a.v ->> 'kind' = 'break' and b.w ->> 'kind' = 'break' and a.i < b.j
               and (a.v ->> 'start')::timestamptz < (b.w ->> 'end')::timestamptz
               and (b.w ->> 'start')::timestamptz < (a.v ->> 'end')::timestamptz) then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'breaks_overlap');
  end if;

  -- Sorted by start for display and export.
  select coalesce(jsonb_agg(e order by (e ->> 'start')::timestamptz, e ->> 'kind'), '[]'::jsonb) into entries
  from jsonb_array_elements(entries) e;
  select coalesce(sum((e ->> 'minutes')::numeric) filter (where e ->> 'kind' = 'break'), 0),
         coalesce(sum((e ->> 'minutes')::numeric) filter (where e ->> 'kind' = 'care'), 0)
    into brk, care
  from jsonb_array_elements(entries) e;

  -- Version, reason code and note (a correction is a new version; the earlier one stays).
  perform pg_advisory_xact_lock(hashtextextended('work1:' || uid::text || ':' || p_date::text, 0));
  select coalesce(max(w.version), 0) + 1 into ver from public.working_day_versions w where w.user_id = uid and w.work_date = p_date;
  reason := nullif(p_payload ->> 'reason_code', '');
  note_ := nullif(btrim(coalesce(p_payload ->> 'note', '')), '');
  if ver = 1 and (reason is not null or note_ is not null) then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'reason_code');
  end if;
  if ver > 1 and (reason is null or reason not in ('segment_missing', 'time_wrong', 'break_missing', 'other')) then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'reason_code');
  end if;
  if note_ is not null and char_length(note_) > 200 then
    return jsonb_build_object('result', private.end_command('invalid'), 'field', 'note');
  end if;

  team := private.working_day_team(uid, p_date);
  org := private.working_day_org(uid, team);
  if org is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  insert into public.working_day_versions (organization_id, user_id, team_id, work_date, version, day_start, day_end,
                                           breaks_answer, outside_answer, entries, paid_minutes, care_minutes,
                                           break_minutes, reason_code, note)
  values (org, uid, team, p_date, ver, ds, de, b_ans, o_ans, entries, private.working_minutes(ds, de) - brk, care, brk,
          reason, note_);
  return jsonb_build_object('result', private.end_command('ok'), 'version', ver);
end;
$$;
revoke all on function public.confirm_working_day(date, jsonb, uuid) from public, anon;
grant execute on function public.confirm_working_day(date, jsonb, uuid) to authenticated;
comment on function public.confirm_working_day(date, jsonb, uuid) is
  'WORK1-2/-3: the signed-in person confirms her own day (no person argument). Refused: unanswered questions '
  '(questions_open), a future day (future), access ended (42501 access_ended). A later call is a new version with a '
  'reason code; the earlier version stays. Audited without the note.';

-- WORK1-4. Return: {"result": "ok"|"duplicate", "month": "YYYY-MM", "days": [...], "unconfirmed": [dates]} or
-- {"result": "rejected" | "invalid"}. The content is not stored again; the export is audited (month, days, unconfirmed).
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
    perform private.audit_command(org, 'working_day_exports', gen_random_uuid(),
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
  'case, address, visit identifier or note. Unconfirmed days by date. Audited (who, month, when, number of days).';

-- 7. AN1 North Star per team (WORK1-6) --------------------------------------------------------------------------------
do $$
declare
  def text := pg_get_functiondef('public.pilot_kpis(date)'::regprocedure);
  old_team constant text :=
    E'  select t.organization_id, t.id, t.name, ''direct_care_share'', null, null, false,\n'
    || E'         ''Noch nicht messbar: bezahlte Arbeitszeit wird noch nicht erfasst (D-23).''\n'
    || E'  from my_teams t\n';
  new_team constant text :=
    E'  -- WORK1-6: confirmed days only; hidden below 3 people or 5 confirmed days (AN1 suppression).\n'
    || E'  select t.organization_id, t.id, t.name, ''direct_care_share'',\n'
    || E'         case when not coalesce(w.too_few, true) then w.value end,\n'
    || E'         case when not coalesce(w.too_few, true) then w.days end,\n'
    || E'         coalesce(w.too_few, true),\n'
    || E'         ''Pflegeminuten ÷ bestätigte bezahlte Arbeitsminuten (ohne Pausen), nur bestätigte Arbeitstage (WORK1).''\n'
    || E'  from my_teams t left join private.team_confirmed_care_share(p_month) w on w.team_id = t.id\n';
  old_org constant text := E'''Noch nicht messbar: bezahlte Arbeitszeit wird noch nicht erfasst (D-23).''),\n';
  new_org constant text := E'''Nur pro Team ausgewiesen, aus bestätigten Arbeitstagen (WORK1).''),\n';
begin
  if position('WORK1-6' in def) > 0 then
    return;
  end if;
  if (length(def) - length(replace(def, old_team, ''))) / length(old_team) <> 1
     or (length(def) - length(replace(def, old_org, ''))) / length(old_org) <> 1 then
    raise exception '0079: pilot_kpis placeholder rows not found exactly once';
  end if;
  execute replace(replace(def, old_team, new_team), old_org, new_org);
end;
$$;
