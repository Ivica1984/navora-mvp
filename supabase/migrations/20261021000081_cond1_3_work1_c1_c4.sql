-- COND1-3 (brief docs/agents/briefs/COND1.md): WORK1-C1 and WORK1-C4 (docs/agents/briefs/WORK1.md, PO review 07:15 and
-- PO review 10:15; CGR-65). ADR-094. Builds on 0079 (WORK1), 0008 (F3 corrections), 0023 (effective event time).
--
-- WORK1-C1 Care cannot exceed paid time. `confirm_working_day` stores as `care_minutes` the length of the UNION of the
--   confirmed care segments, clipped to the day (day start → day end), minus the union's overlap with the declared
--   breaks (`private.working_care_minutes`). Overlapping care segments are stored as she confirmed them (two visits
--   may have been open at once), never refused; only the number counts the overlap once. Breaks do not overlap each
--   other (0079 refuses that), all entries lie inside the day (0079), so union ∖ breaks ⊆ day ∖ breaks and
--   0 ≤ care ≤ paid holds exactly. Each figure is rounded to 0.1 minute on its own, so the command takes
--   least(care, paid) against a rounding step of at most a few tenths, and a check constraint `care_le_paid` makes the
--   inequality hold for every version stored from now on. It is added NOT VALID: append-only rows written before this
--   migration are not rewritten (synthetic data only; brief: "No existing version needs rewriting").
-- WORK1-C4 One time per visit event. `private.working_day_proposal` takes the EFFECTIVE time of each of her events: the
--   latest F3 correction, else the recorded time (the lateral join of 0023: order by created_at desc, id desc), for the
--   segment start and end, for the order of the segments and for the Zurich date the event belongs to. A segment whose
--   start or end came from a corrected event carries `corrected` true. No correction reason, no corrector, no visit
--   identifier is returned (the 0079 result stays identifier-free; `corrected` is the only new column). The working day
--   never writes `visit_events` or `visit_time_corrections` (no write-back; nothing here inserts or updates them).
--   `/work` shows, when she changes a visit segment, that the visit keeps its time and links to that visit's time
--   correction on /field (UI; ADR-094 (3)).
--
-- No labour-law, clinical or tariff rule: no break, rest or plan limit is checked (D-23 item 8); C1 is an integrity
-- check of the same kind as 0079's "breaks do not overlap". Idempotent: create or replace / drop if exists; the
-- constraint is added only when absent. A second run changes nothing.

-- 1. WORK1-C1: care minutes as a union, clipped to the day, minus the breaks -------------------------------------------
create or replace function private.working_care_minutes(p_entries jsonb, p_day_start timestamptz, p_day_end timestamptz)
returns numeric language sql immutable set search_path = ''
as $$
  with care as (
    select greatest((e ->> 'start')::timestamptz, p_day_start) as s, least((e ->> 'end')::timestamptz, p_day_end) as f
    from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) e
    where e ->> 'kind' = 'care'
  ), ordered as (
    select c.s, c.f, max(c.f) over (order by c.s, c.f rows between unbounded preceding and 1 preceding) as reach
    from care c
    where c.f > c.s
  ), grouped as (
    select o.s, o.f, sum(case when o.reach is null or o.s > o.reach then 1 else 0 end) over (order by o.s, o.f) as island
    from ordered o
  ), islands as (
    select min(g.s) as s, max(g.f) as f from grouped g group by g.island
  ), breaks as (
    select (b ->> 'start')::timestamptz as s, (b ->> 'end')::timestamptz as f
    from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) b
    where b ->> 'kind' = 'break'
  )
  select greatest(0, round(((
           coalesce((select sum(extract(epoch from (i.f - i.s))) from islands i), 0)
         - coalesce((select sum(greatest(0, extract(epoch from (least(i.f, b.f) - greatest(i.s, b.s)))))
                     from islands i cross join breaks b), 0)) / 60)::numeric, 1))
$$;
revoke all on function private.working_care_minutes(jsonb, timestamptz, timestamptz) from public, anon, authenticated;
comment on function private.working_care_minutes(jsonb, timestamptz, timestamptz) is
  'WORK1-C1: minutes of the union of the care entries, clipped to the day, minus their overlap with the break entries '
  '(breaks do not overlap each other, 0079). Overlapping care counts once; care inside a break is not care.';

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.working_day_versions'::regclass
                 and conname = 'working_day_versions_care_le_paid') then
    alter table public.working_day_versions
      add constraint working_day_versions_care_le_paid check (care_minutes <= paid_minutes) not valid;
  end if;
end;
$$;
comment on constraint working_day_versions_care_le_paid on public.working_day_versions is
  'WORK1-C1: care never exceeds paid time for every version stored from 0081 on (NOT VALID: earlier append-only rows '
  'are not rewritten).';

-- 2. WORK1-C4: the proposal uses the effective (F3-corrected) event time ------------------------------------------------
-- The result type gains `corrected`, so both functions are dropped and created again (same names, arguments, grants).
drop function if exists public.my_working_day(date);
drop function if exists private.working_day_proposal(uuid, date);

create function private.working_day_proposal(p_user uuid, p_date date)
returns table (seq integer, visit_no integer, kind text, starts_at timestamptz, ends_at timestamptz, corrected boolean)
language sql stable security definer set search_path = ''
as $$
  with ev as (
    select e.id, e.visit_id, e.event_type, coalesce(lc.corrected_at, e.occurred_at) as at, lc.corrected_at is not null as corr
    from public.visit_events e
    left join lateral (select x.corrected_at from public.visit_time_corrections x where x.event_id = e.id
                       order by x.created_at desc, x.id desc limit 1) lc on true
    where p_user is not null and e.actor_id = p_user
  ), own as (
    select v.id, v.visit_id, v.event_type, v.at, v.corr,
           lead(v.at) over w as next_at, coalesce(lead(v.corr) over w, false) as next_corr
    from ev v
    where v.visit_id in (select x.visit_id from ev x where (private.at_zurich(x.at))::date = p_date)
    window w as (partition by v.visit_id order by v.at, v.id)
  ), seg as (
    select o.visit_id, o.id,
           case o.event_type when 'departed' then 'travel' when 'paused' then 'visit_pause' else 'care' end as kind,
           o.at as starts_at, o.next_at as ends_at, (o.corr or (o.next_at is not null and o.next_corr)) as corrected
    from own o
    where o.event_type in ('departed', 'started', 'resumed', 'paused')
      and (private.at_zurich(o.at))::date = p_date
  ), numbered as (
    select s.*, dense_rank() over (order by v.first_at, s.visit_id)::integer as visit_no
    from seg s join (select visit_id, min(starts_at) as first_at from seg group by visit_id) v on v.visit_id = s.visit_id
  ), marks as (
    select null::integer as visit_no, 'report_signed'::text as kind, r.signed_at as starts_at, r.signed_at as ends_at,
           false as corrected, 0::bigint as id
    from public.visit_reports r
    where p_user is not null and r.signed_by = p_user and r.signed_at is not null
      and (private.at_zurich(r.signed_at))::date = p_date
  )
  select (row_number() over (order by a.starts_at, a.visit_no nulls last, a.id))::integer, a.visit_no, a.kind,
         a.starts_at, a.ends_at, a.corrected
  from (select n.visit_no, n.kind, n.starts_at, n.ends_at, n.corrected, n.id from numbered n
        union all
        select m.visit_no, m.kind, m.starts_at, m.ends_at, m.corrected, m.id from marks m) a
  order by 1
$$;
revoke all on function private.working_day_proposal(uuid, date) from public, anon, authenticated;
comment on function private.working_day_proposal(uuid, date) is
  'WORK1-1 / WORK1-C4: segments from the person''s own visit events of a Zurich day at their effective time (latest F3 '
  'correction, else recorded; also for the order and the date), open end = null; a report sign time as a point; '
  'corrected = start or end came from a corrected event. No location, client, case, visit identifier, correction '
  'reason or corrector. Called only with the caller''s own id.';

create function public.my_working_day(p_date date)
returns table (seq integer, visit_no integer, kind text, starts_at timestamptz, ends_at timestamptz, corrected boolean)
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
  return query select p.seq, p.visit_no, p.kind, p.starts_at, p.ends_at, p.corrected
               from private.working_day_proposal(uid, p_date) p;
end;
$$;
revoke all on function public.my_working_day(date) from public, anon;
grant execute on function public.my_working_day(date) to authenticated;
comment on function public.my_working_day(date) is
  'WORK1-1 / WORK1-C4: the signed-in person''s own working-day proposal for a Zurich day (nobody else''s, no person '
  'argument), at effective event times; `corrected` marks a segment from a corrected event. Empty until the WORK1-8 '
  'information text is acknowledged.';

-- 3. confirm_working_day with the WORK1-C1 care figure (otherwise unchanged from 0079) -----------------------------------
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
  paid     numeric := 0;
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
  select coalesce(sum((e ->> 'minutes')::numeric) filter (where e ->> 'kind' = 'break'), 0) into brk
  from jsonb_array_elements(entries) e;
  -- WORK1-C1: care = union of the care segments, clipped to the day, minus breaks; never above paid time (the
  -- least() only absorbs the separate 0.1-minute rounding of the figures).
  paid := private.working_minutes(ds, de) - brk;
  care := least(private.working_care_minutes(entries, ds, de), greatest(paid, 0));

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
  values (org, uid, team, p_date, ver, ds, de, b_ans, o_ans, entries, paid, care, brk, reason, note_);
  return jsonb_build_object('result', private.end_command('ok'), 'version', ver);
end;
$$;
revoke all on function public.confirm_working_day(date, jsonb, uuid) from public, anon;
grant execute on function public.confirm_working_day(date, jsonb, uuid) to authenticated;
comment on function public.confirm_working_day(date, jsonb, uuid) is
  'WORK1-2/-3: the signed-in person confirms her own day (no person argument). Refused: unanswered questions '
  '(questions_open), a future day (future), access ended (42501 access_ended). A later call is a new version with a '
  'reason code; the earlier version stays. Audited without the note. WORK1-C1 (0081): care minutes = union of the '
  'care segments minus breaks, so care <= paid for every version.';
