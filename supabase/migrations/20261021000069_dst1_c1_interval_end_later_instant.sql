-- DST1-C1 (CGR-53): an interval used in a safety overlap check is never shorter than its wall-clock length.
-- ADR-081 (addendum 2026-10-25). Brief `docs/agents/briefs/DST1.md`. Engineering fix; no threshold, release or flag rule
-- changes (ABS1 rules stay as accepted; thresholds stay PROVISIONAL, D-28).
--
-- Cause (IMPLEMENTED before this migration, 0067): 0067 re-created every function with `private.at_zurich`, which reads
-- an ambiguous local time (autumn repeated hour 02:00-02:59) as the EARLIER instant. That is right for a start, but it
-- also gave the END of an interval the earlier instant: a visit 01:30-02:30 on 2026-10-25 occupied 23:30-00:30 UTC
-- instead of 23:30-01:30 UTC, so an absence of its responsible nurse from 01:00 UTC no longer overlapped it and ABS1
-- neither released the visit nor flagged `responsible_absent` (H-01, H-17). Before 0067 the end was the later instant.
--
-- Now (IMPLEMENTED): the END of every interval used for an absence overlap test is read with `private.at_zurich_end`
-- (ambiguous → the later instant; non-existent → CET reading, as `private.at_zurich`). Starts stay `private.at_zurich`.
--   1. `private.visit_interval(care_visits)`: the end of a visit with an explicit end. A visit without end keeps
--      start + planned minutes (an elapsed duration, never shorter) or the next midnight (never ambiguous in Zurich).
--      Every absence check reads this one interval: record_absence (release, CSR1 past_planned), change_absence,
--      release_visits_between, plan_visit, reschedule_visit, take_open_visit, private.visit_responsible_absent (the
--      `responsible_absent` flag), team_open_visits (overlap with the caller's own visit), member_working_span (SIG2),
--      pilot_hypotheses (AN2).
--      A visit that starts in the spring gap and ends after it (2027-03-28 02:30-03:10: start read as 01:30 UTC, end
--      01:10 UTC) made tstzrange fail with "range lower bound must be less than or equal to range upper bound" since
--      0048, so every absence command touching that visit failed. Such an interval now covers both readings: from
--      the end instant minus its wall-clock length to the start instant plus it (00:30-02:10 UTC for the example).
--      Only that case changes: wherever the end instant is not before the start, it is [start, at_zurich_end(end)).
--   2. `public.record_absence`: the absence end typed as a local time.
--   3. `public.change_absence`: the new (shorter) absence end typed as a local time.
-- Not changed (ADR-081 addendum lists them): the CSR1 stuck reference in `private.derived_exceptions` keeps the earlier
-- end (an earlier reference raises the alert sooner; accepted by the PO); `private.release_member_visits` ends at a
-- midnight (unambiguous); `private.generate_case_plan` compares wall-clock times, not instants.
-- Idempotent: a second run changes nothing and the guards still hold. The migration fails if a body is not as expected.

-- 1. The visit interval ------------------------------------------------------------------------------------------------
create or replace function private.visit_interval(v public.care_visits)
returns tstzrange
language sql
stable
set search_path = ''
as $$
  select case
    when v.time_start is null then
      tstzrange(private.at_zurich((v.visit_date + time '00:00')),
                private.at_zurich_end(((v.visit_date + 1) + time '00:00')), '[)')
    when v.time_end is null or v.time_end = v.time_start then
      tstzrange(private.at_zurich((v.visit_date + v.time_start)),
                case when coalesce(v.planned_minutes_a, 0) + coalesce(v.planned_minutes_b, 0) + coalesce(v.planned_minutes_c, 0) > 0
                     then private.at_zurich((v.visit_date + v.time_start))
                          + make_interval(mins => coalesce(v.planned_minutes_a, 0) + coalesce(v.planned_minutes_b, 0)
                                                  + coalesce(v.planned_minutes_c, 0))
                     else private.at_zurich_end(((v.visit_date + 1) + time '00:00')) end,
                '[)')
    else
      (select case when e.e >= e.s then tstzrange(e.s, e.e, '[)')
                    else tstzrange(e.e - (e.le - e.ls), e.s + (e.le - e.ls), '[)') end
       from (select l.ls, l.le, private.at_zurich(l.ls) as s, private.at_zurich_end(l.le) as e
             from (select v.visit_date + v.time_start as ls,
                          v.visit_date + v.time_end
                            + case when v.time_end < v.time_start then interval '1 day' else interval '0' end as le) l) e)
  end
$$;
revoke all on function private.visit_interval(public.care_visits) from public, anon, authenticated;
comment on function private.visit_interval(public.care_visits) is
  'ABS1/CGR-27: the time a planned visit occupies (Europe/Zurich). No start: its whole date. Start without end: start '
  '+ planned minutes A+B+C, else to the end of its date. Used by every absence check. DST1-C1 / CGR-53: the start '
  'reads the repeated hour as the earlier instant, the end as the later instant (never shorter than the wall clock).';

-- 2./3. Absence ends ---------------------------------------------------------------------------------------------------
do $$
declare
  def text;
begin
  def := pg_get_functiondef('public.record_absence(uuid, uuid, date, date, time, time, uuid)'::regprocedure);
  def := replace(def, 'then private.at_zurich(((d_until + 1) + time ''00:00''))',
                      'then private.at_zurich_end(((d_until + 1) + time ''00:00''))');
  def := replace(def, 'else private.at_zurich((d_until + p_until_time)) end;',
                      'else private.at_zurich_end((d_until + p_until_time)) end;');
  execute def;

  def := pg_get_functiondef('public.change_absence(uuid, boolean, date, time, uuid)'::regprocedure);
  def := replace(def, 'then private.at_zurich(((p_until + 1) + time ''00:00''))',
                      'then private.at_zurich_end(((p_until + 1) + time ''00:00''))');
  def := replace(def, 'else private.at_zurich((p_until + p_until_time)) end;',
                      'else private.at_zurich_end((p_until + p_until_time)) end;');
  execute def;

  -- Guards: the ends read the later instant; the starts still the earlier one.
  def := pg_get_functiondef('public.record_absence(uuid, uuid, date, date, time, time, uuid)'::regprocedure);
  if def not like '%e_at := case when p_until_time is null then private.at_zurich_end(((d_until + 1) + time ''00:00''))%'
     or def not like '%else private.at_zurich_end((d_until + p_until_time)) end;%'
     or def not like '%s_at := private.at_zurich((d_from + coalesce(p_from_time, time ''00:00'')));%' then
    raise exception 'DST1-C1: public.record_absence does not read the absence end with private.at_zurich_end';
  end if;
  def := pg_get_functiondef('public.change_absence(uuid, boolean, date, time, uuid)'::regprocedure);
  if def not like '%new_end := case when p_until_time is null then private.at_zurich_end(((p_until + 1) + time ''00:00''))%'
     or def not like '%else private.at_zurich_end((p_until + p_until_time)) end;%' then
    raise exception 'DST1-C1: public.change_absence does not read the new absence end with private.at_zurich_end';
  end if;
end;
$$;

-- 4. DST1-7 / DST1-C2: a watched-hours window is never shorter than its wall-clock length ------------------------------
-- Found while writing the DST1-C2 assertions (IMPLEMENTED in the code before this migration): `private.watched_inside`
-- compared the Zurich wall clock with the period, while `private.watched_raise_at` (0067) reads the period END as an
-- instant with `private.at_zurich_end`. On 2027-03-28 a period 00:00-02:30 (end in the missing hour, DST1-3 reading
-- 01:30 UTC) was therefore "outside" from 01:00 UTC (03:00 CEST) although its end instant is 01:30 UTC, and
-- `watched_raise_at` then looked a week back for the last period. Now a time is inside when EITHER reading covers it:
-- the wall clock (as before) OR the instants of today's period (start `private.at_zurich`, end `private.at_zurich_end`).
-- On every ordinary day both readings agree, so nothing changes there; on the two clock-change nights the window only
-- gets longer, never shorter (CGR-52 (4)). No period, weekday or route changes (SIG2 rules unchanged).
create or replace function private.watched_inside(p_org uuid, p_t timestamptz)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.organization_watched_hours h
    where h.organization_id = p_org
      and h.weekday = extract(isodow from (private.at_zurich(p_t)))::int
      and (
        (h.starts <= (private.at_zurich(p_t))::time
         and (h.ends = time '24:00' or (private.at_zurich(p_t))::time < h.ends))
        or (p_t >= private.at_zurich(((private.at_zurich(p_t))::date + h.starts))
            and p_t < private.at_zurich_end(((private.at_zurich(p_t))::date + h.ends)))
      )
  )
$$;
revoke all on function private.watched_inside(uuid, timestamptz) from public, anon, authenticated;
comment on function private.watched_inside(uuid, timestamptz) is
  'SIG2-12 / DST1-7: true when p_t lies in a watched period of its Zurich weekday, by the wall clock or by the period '
  'instants (start: earlier instant; end: later instant). Never shorter than the wall-clock length on DST nights.';
