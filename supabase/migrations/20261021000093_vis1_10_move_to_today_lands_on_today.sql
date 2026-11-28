-- VIS1-10: the move to today lands on today (PO brief docs/agents/briefs/VIS1.md, po 2026-10-29 02:15, amended 03:10
-- and 04:10; `cra` CGR-91; issue #638; ADR-116).
-- Visit/schedule fact (the visit date and the Zurich calendar day, DAY-1). No clinical rule, no tolerance.
--
-- Before (IMPLEMENTED defect, ADR-113 finding, CGR-91): "Heute machen" on /field called `reschedule_visit` with the date
--   the page computed when it rendered. A page rendered before 00:00 and confirmed after it sent yesterday's date;
--   `reschedule_visit` accepts a past date (the documented *Nachtrag* from /team, ADR-063 / ABS1-C5), so the visit was
--   moved to yesterday while the confirmation said "Heute". The `moved` fact then contradicted what happened.
-- Now (IMPLEMENTED in this migration):
--   1. `public.move_visit_to_today(visit, shown_date, start, end, reason, key)` is the command behind "Heute machen".
--      The caller says which date she was shown; the database decides what today is
--      (`private.at_zurich(private.now())::date`).
--   2. Shown date = the database's today → exactly `reschedule_visit(visit, today, …)` with all its checks (ABS1-C4,
--      ABS1-C5, CGR-35, audit, `moved` row) and its result. The stored date is the database's today, which is the date
--      she was shown and confirmed.
--   3. Shown date ≠ the database's today (page left open across midnight, or a device clock that is off) → refused with
--      `day_changed`: nothing changes (date, times, responsible member, no `moved` row), ONE `audit_events` row
--      (`private.write_visit_refusal`, command `move_visit_to_today`, outcome `day_changed`, no idempotency key, as
--      ADR-111 (2)), and the result carries `today` (the database's date) and the visit's unchanged `visit_date`, so the
--      app can show the new date and offer the confirmation again (amendment 03:10).
--   4. Order: uid → begin_command (key required, LEAVE1 access end, duplicate of an applied move) → visibility (team
--      member of the visit; otherwise `reschedule_visit`'s own `rejected`, so nobody outside the team learns a date)
--      → the day rule → `reschedule_visit`.
-- Unchanged: `reschedule_visit` itself (signature, grants, behaviour), so the /team move to a past date (*Nachtrag*)
--   still returns `ok`; who may move a visit; the VIS1-8 move fact; the 0089/0090 day rules.
-- Idempotent: create or replace; grants re-applied.

create or replace function public.move_visit_to_today(
  p_visit_id uuid, p_shown_date date, p_time_start time, p_time_end time, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  today date := (private.at_zurich(private.now()))::date;
  v     public.care_visits%rowtype;
begin
  if (select auth.uid()) is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  -- Key required, LEAVE1-3 access end, and a retry of a move already applied is a duplicate (no second check).
  if private.begin_command('move_visit_to_today', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  perform private.end_command('checked');

  select * into v from private.visit_for_team(p_visit_id);
  -- VIS1-10: the database's day decides. A team member shown another date gets `day_changed` and one audit row.
  if v.id is not null and p_shown_date is distinct from today then
    perform private.write_visit_refusal(v, 'move_visit_to_today', 'day_changed');
    return jsonb_build_object('result', 'day_changed', 'today', today, 'visit_date', v.visit_date);
  end if;

  -- Not visible to her (refused there without a date) or shown today: the existing move, to the database's today.
  return public.reschedule_visit(p_visit_id, today, p_time_start, p_time_end, p_reason, p_idempotency_key);
end;
$$;

revoke all on function public.move_visit_to_today(uuid, date, time, time, text, uuid) from public, anon;
grant execute on function public.move_visit_to_today(uuid, date, time, time, text, uuid) to authenticated;

comment on function public.move_visit_to_today(uuid, date, time, time, text, uuid) is
  'VIS1-10 / ADR-116 / CGR-91: "Heute machen" on /field. Moves the visit to the database''s today (Europe/Zurich) '
  'through reschedule_visit when that is the date she was shown; otherwise refuses with day_changed (nothing changes, '
  'one audit row) and returns today and the visit''s date. reschedule_visit (the /team move, also to a past date) is '
  'unchanged.';
