-- COND1-1 and COND1-2 (brief docs/agents/briefs/COND1.md, PO 2026-10-26): the pre-pilot conditions LEAVE1-C2, -C3, -C4
-- (docs/agents/briefs/LEAVE1.md, *Conditions*, PO 06:10) and DOOR1-12, -13, -14 (docs/agents/briefs/DOOR1.md, PO 21:10
-- and 22:10). ADR-093. Builds on 0062/0063 (SIG2, SIG1-C1), 0019/0020 (OPS1, QG1), 0072/0073 (DOOR1), 0074-0078 (LEAVE1).
--
-- LEAVE1-C2 (CGR-64, S2): a `pending` or `sent` outside delivery counts as "reached outside the app" only while its
--   recipient's access is open (`not private.access_ended(recipient_id)`, evaluated live). Read in SIG2's immediate step
--   (`private.outside_settle`) and in the banner's forecast (`private.signal_step_outside_app`).
-- LEAVE1-C3 (CGR-63, S3, option (a)): a safety-signal take counts only when it was recorded after the taker's latest
--   access end. Each take records `access_seq`, the sequence number of the taker's latest `ended` access event when she
--   took (0 = none; set by a trigger, so every writer records it). A take is lapsed while her access is ended or once an
--   `ended` event with a higher sequence number exists. A restore therefore does not revive an earlier take; she takes the
--   signal again (a new, appended row: the unique key is now signal + taker + access_seq). Takes stay append-only;
--   `safety_signals.taken_by` and the SIGC/AN2 measure keep the historical first take. Rows recorded before this migration
--   carry no `access_seq` (null) and are judged by time instead: lapsed once an `ended` event exists at or after the take.
-- LEAVE1-C4 (deviation 15): an OPS1 exception take whose taker's access has ended reads as untaken in
--   `operations_exceptions` (Operations) and `team_visit_alerts` (team): `taken` false, no name, no time, flag
--   `take_access_ended` ("Übernahme beendet – Zugang beendet"). An `in_review` quality event whose owner's access has
--   ended carries `claim_ended` in `field_quality` (team); no reader returns an owner name. Nothing is rewritten; the
--   P2 → P1 clock, `handle_exception` and the QG1 closing rules are unchanged.
-- DOOR1-12: every writer of `cases.access_notes` refuses four or more digits in a row with "Bitte keinen Code erfassen"
--   (22023), by the DOOR1-4 predicate `private.looks_like_code` (one guard for both fields), in a BEFORE INSERT OR UPDATE
--   OF access_notes trigger. It acts only when the note is written or changed: existing rows are not rewritten and an
--   unrelated update of a case is not refused (G-11: the owner counts them before the first import, OWNER_RUNBOOK.md).
-- DOOR1-13: the card shows one "Zugang" line. `field_door_notes` returns the case's intake date (`intake_on`: the Zurich
--   date of `intake_consent_confirmed_at`, else of `created_at`), and `field_safety_alert_history(date)` returns every value
--   of the access arrangement of the day's cases, plus the intake note as the earliest entry (source `referral`,
--   `from_intake`). The intake note is never copied into the value table; `access_unknown` (0013) keeps reading
--   `cases.access_notes`.
-- DOOR1-14 (CGR-61): a `clinical` category needs `approval_ref` of the form CR-nnn (a Clinical Rule Register row). The
--   register status (APPROVED) is checked by scripts/agents-check.mjs on every migration. The card order is unchanged.
--
-- No clinical, tariff or legal rule: no threshold, recipient, step, category or readiness rule changes. Idempotent: if
-- not exists / drop if exists / create or replace; the patch skips when its marker is present. A second run changes nothing.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.cond1_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0080 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0080 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.cond1_patch(text, text[], text) from public, anon, authenticated;

-- 1. LEAVE1-C3: a take counts only when recorded after the taker's latest access end ------------------------------------
alter table public.signal_takes add column if not exists access_seq bigint;
comment on column public.signal_takes.access_seq is
  'LEAVE1-C3 (CGR-63, ADR-093): sequence number of the taker''s latest `ended` access event when she took (0 = none). '
  'A later `ended` event lapses the take for good; a restore does not revive it. Null = recorded before 0080.';

alter table public.signal_takes drop constraint if exists signal_takes_signal_id_taker_id_key;
alter table public.signal_takes drop constraint if exists signal_takes_signal_taker_access_key;
alter table public.signal_takes add constraint signal_takes_signal_taker_access_key
  unique nulls not distinct (signal_id, taker_id, access_seq);

create or replace function private.latest_access_end_seq(p_user uuid)
returns bigint language sql stable security definer set search_path = ''
as $$
  select coalesce(max(e.seq), 0) from public.member_access_events e where e.user_id = p_user and e.kind = 'ended'
$$;
revoke all on function private.latest_access_end_seq(uuid) from public, anon, authenticated;

create or replace function private.stamp_signal_take()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  new.access_seq := private.latest_access_end_seq(new.taker_id);
  return new;
end;
$$;
revoke all on function private.stamp_signal_take() from public, anon, authenticated;
drop trigger if exists stamp_signal_takes on public.signal_takes;
create trigger stamp_signal_takes before insert on public.signal_takes
  for each row execute function private.stamp_signal_take();

create or replace function private.signal_take_lapsed(p_taker uuid, p_access_seq bigint, p_taken_at timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.access_ended(p_taker)
      or exists (select 1 from public.member_access_events e
                 where e.user_id = p_taker and e.kind = 'ended'
                   and case when p_access_seq is null then e.created_at >= p_taken_at else e.seq > p_access_seq end)
$$;
revoke all on function private.signal_take_lapsed(uuid, bigint, timestamptz) from public, anon, authenticated;
comment on function private.signal_take_lapsed(uuid, bigint, timestamptz) is
  'LEAVE1-14 with LEAVE1-C3 (CGR-63, option (a), ADR-093): the take no longer counts: her access is ended now, or an '
  '`ended` access event was recorded after the take (also when her access was restored since).';

create or replace function private.signal_taken_stops_step(p_signal_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.signal_takes t
                 where t.signal_id = p_signal_id and t.stops_escalation
                   and not private.signal_take_lapsed(t.taker_id, t.access_seq, t.taken_at))  -- LEAVE1-14, LEAVE1-C3
$$;
revoke all on function private.signal_taken_stops_step(uuid) from public, anon, authenticated;
comment on function private.signal_taken_stops_step(uuid) is
  'SIG1-C1 (ADR-077) with LEAVE1-14 (ADR-091) and LEAVE1-C3 (ADR-093): somebody has taken the signal in a way that '
  'stops the step to Operations, and that take has not lapsed (her access is open and has not ended since she took). '
  'Read by the SIG1-5 step (evaluate_signals) and SIG2''s immediate step (outside_settle).';

create or replace function public.take_signal(p_signal_id uuid, p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  s     public.safety_signals%rowtype;
  stops boolean;
  shown uuid;
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
  -- Already taken by her (a take that still counts, LEAVE1-C3), or by somebody whose take stops the step.
  if exists (select 1 from public.signal_takes t where t.signal_id = s.id and t.taker_id = uid
               and not private.signal_take_lapsed(t.taker_id, t.access_seq, t.taken_at))
     or private.signal_taken_stops_step(s.id) then
    select t.taker_id into shown from public.signal_takes t
    where t.signal_id = s.id
    order by private.signal_take_lapsed(t.taker_id, t.access_seq, t.taken_at), t.stops_escalation desc, t.taken_at, t.id
    limit 1;  -- LEAVE1-14, LEAVE1-C3
    return jsonb_build_object('result', private.end_command('duplicate'),
                              'taken_by_name', coalesce(private.member_name(s.organization_id, coalesce(shown, s.taken_by)), 'Teammitglied'));
  end if;
  if s.ended_at is not null then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'signal_ended');
  end if;
  stops := private.signal_take_stops(s.id, uid);
  insert into public.signal_takes (organization_id, signal_id, taker_id, qualification, stops_escalation)
  values (s.organization_id, s.id, uid, private.signal_taker_qualification(s.id, uid), stops);
  if s.taken_by is null then
    update public.safety_signals set taken_by = uid, taken_at = private.now() where id = s.id;
  end if;
  return jsonb_build_object('result', private.end_command('ok'),
                            'operations_follows', not stops and s.escalated_at is null);
end;
$$;

-- my_signals: the 0078 body; a lapsed take (LEAVE1-C3) reads as ended, also after a restore.
create or replace function public.my_signals()
returns table (signal_id uuid, signal_kind text, visit_id uuid, visit_date date, time_start time, team_id uuid,
               team_name text, reason text, delivered_at timestamptz, p1_at timestamptz,
               taken_by_me boolean, taken_by_name text, taken_at timestamptz, outside_none boolean,
               taken_by_qualification text, taken_awaits_rn boolean, watched_now boolean,
               operations_outside_app boolean, taker_access_ended boolean)
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  if uid is null then return; end if;
  for org in select distinct om.organization_id from public.organization_memberships om where om.user_id = uid loop
    perform private.evaluate_signals(org, false);
  end loop;
  return query
    select s.id, s.signal_kind, s.visit_id, v.visit_date, v.time_start, s.team_id, t.name, d.reason, d.created_at, s.p1_at,
           coalesce(tk.taker_id = uid and not tk.ended, false),
           case when tk.taker_id is not null and not tk.ended
                then coalesce(private.member_name(s.organization_id, tk.taker_id), 'Teammitglied') end,
           case when not tk.ended then tk.taken_at end,
           s.outside_none_at is not null,
           case when not tk.ended then tk.qualification end,
           (tk.taker_id is not null and not tk.ended and not tk.stops_escalation),
           private.watched_inside(s.organization_id, private.now()),   -- SIG2-C1 (1), ADR-082
           private.signal_step_outside_app(s.id, private.now()),       -- FUP1-2, ADR-084
           coalesce(tk.ended, false)                                   -- LEAVE1-14 (ADR-091), LEAVE1-C3 (ADR-093)
    from public.signal_deliveries d
    join public.safety_signals s on s.id = d.signal_id
    join public.care_visits v on v.id = s.visit_id
    join public.teams t on t.id = s.team_id
    left join lateral (select x.taker_id, x.taken_at, x.qualification, x.stops_escalation,
                              private.signal_take_lapsed(x.taker_id, x.access_seq, x.taken_at) as ended
                       from public.signal_takes x
                       where x.signal_id = s.id
                       order by private.signal_take_lapsed(x.taker_id, x.access_seq, x.taken_at),
                                x.stops_escalation desc, x.taken_at, x.id
                       limit 1) tk on true
    where d.recipient_id = uid and s.ended_at is null and private.is_org_member(d.organization_id)
    order by (tk.taker_id is null or tk.ended or not tk.stops_escalation) desc, d.created_at desc, s.id;
end;
$$;
revoke all on function public.my_signals() from public, anon;
grant execute on function public.my_signals() to authenticated;

-- end_member_access: the open signals she had taken counts only takes that still count (LEAVE1-C3).
select private.cond1_patch('public.end_member_access(uuid, text, uuid)', array[
  E'  where tk.taker_id = p_user_id and s.organization_id = org and s.ended_at is null;',
  E'  where tk.taker_id = p_user_id and s.organization_id = org and s.ended_at is null\n'
  || E'    and not private.signal_take_lapsed(tk.taker_id, tk.access_seq, tk.taken_at);  -- LEAVE1-C3',
  '1'], 'LEAVE1-C3');

-- 2. LEAVE1-C2: a delivery to a person whose access has ended reaches nobody --------------------------------------------
create or replace function private.outside_settle(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  n   integer := 0;
  sig record;
begin
  update public.signal_outside_deliveries o set result = 'failed', failure = 'timeout'
  where o.organization_id = p_org and o.result = 'pending' and o.decided_at < private.now() - interval '2 minutes';
  for sig in
    select s.id, s.visit_id, s.signal_kind
    from public.safety_signals s
    where s.organization_id = p_org and s.ended_at is null and not private.signal_taken_stops_step(s.id) /* SIG1-C1 (ADR-077) */
      and s.escalated_at is null and s.outside_none_at is null
      and exists (select 1 from public.signal_outside_deliveries o where o.signal_id = s.id)
      and not exists (select 1 from public.signal_outside_deliveries o
                      where o.signal_id = s.id and o.result in ('pending', 'sent')
                        and not private.access_ended(o.recipient_id))  -- LEAVE1-C2 (CGR-64)
    for update of s skip locked
  loop
    insert into public.signal_deliveries (organization_id, signal_id, recipient_id, reason, signal_kind, visit_id)
    select p_org, sig.id, o, 'untaken', sig.signal_kind, sig.visit_id
    from private.signal_operations_users(p_org) o
    on conflict (signal_id, recipient_id) do nothing;
    update public.safety_signals set outside_none_at = private.now(), escalated_at = private.now() where id = sig.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function private.outside_settle(uuid) from public, anon, authenticated;

create or replace function private.signal_step_outside_app(p_signal_id uuid, p_at timestamptz)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case
    when s.escalated_at is not null
         or exists (select 1 from public.signal_deliveries d
                    where d.signal_id = s.id and d.reason in ('operations_fallback', 'untaken'))
      then exists (select 1 from public.signal_deliveries d
                   join public.signal_outside_deliveries o on o.id = d.id
                   where d.signal_id = s.id and d.reason in ('operations_fallback', 'untaken')
                     and o.result in ('pending', 'sent')
                     and not private.access_ended(o.recipient_id))  -- LEAVE1-C2 (CGR-64)
    else coalesce((select private.watched_inside(s.organization_id,
                                                 greatest(p_at, private.after_threshold(s.created_at, r.amount, r.unit)))
                   from private.effective_exception_rules(s.organization_id) r
                   where r.exception_type = 'signal_untaken'
                   limit 1), false)
  end
  from public.safety_signals s where s.id = p_signal_id
$$;
comment on function private.signal_step_outside_app(uuid, timestamptz) is
  'FUP1-2 (ADR-084) with LEAVE1-C2 (ADR-093): whether the step to Operations reaches Operations outside the app. After '
  'the step: an Operations outside delivery is pending or sent and its recipient''s access is open. Before: the forecast '
  '(a watched period runs when the step falls due).';

-- 3. LEAVE1-C4: no leaver's name on a claim nobody holds ---------------------------------------------------------------
create or replace function public.operations_exceptions()
returns table (exception_key text, exception_type text, priority text, label text, next_step text, detail text,
               since timestamptz, case_id uuid, case_label text, region text, team_name text, entity_type text,
               entity_id uuid, taken_by_me boolean, taken boolean, taken_at timestamptz, comments jsonb, owner_name text,
               closable boolean, flags text[])
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
with my_orgs as (
    select om.organization_id from public.organization_memberships om
    where om.user_id = (select auth.uid()) and private.is_coordinator(om.organization_id)
  ), d as (
    select o.organization_id, x.* from my_orgs o, lateral private.derived_exceptions(o.organization_id) x
  ), latest as (
    select distinct on (ev.organization_id, ev.exception_key) ev.organization_id, ev.exception_key, ev.kind, ev.actor_id, ev.created_at,
           (ev.kind = 'take' and private.access_ended(ev.actor_id)) as take_ended  -- LEAVE1-C4
    from public.exception_events ev
    where ev.organization_id in (select organization_id from my_orgs) and ev.kind in ('take', 'close', 'auto_close')
    order by ev.organization_id, ev.exception_key, ev.id desc
  )
  select d.exception_key, d.exception_type,
         case when r.escalate_to_p1_after_hours is not null and private.now() >= d.since + make_interval(hours => r.escalate_to_p1_after_hours)
              then 'P1' else r.priority end,
         r.label, r.next_step, d.detail, d.since, d.case_id,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), c.region,
         coalesce(t.name, ct.name), d.entity_type, d.entity_id,
         coalesce(l.kind = 'take' and not l.take_ended and l.actor_id = (select auth.uid()), false),
         coalesce(l.kind = 'take' and not l.take_ended, false),
         case when l.kind = 'take' and not l.take_ended then l.created_at end,
         coalesce((select jsonb_agg(jsonb_build_object('text', ev.text, 'at', ev.created_at, 'mine', ev.actor_id = (select auth.uid()))
                                    order by ev.id)
                   from public.exception_events ev
                   where ev.organization_id = d.organization_id and ev.exception_key = d.exception_key and ev.kind = 'comment'), '[]'::jsonb),
         case when l.kind = 'take' and not l.take_ended then private.member_name(d.organization_id, l.actor_id) end,
         not (r.priority = 'P1' or r.escalate_to_p1_after_hours is not null or d.exception_type in ('visit_uncovered', 'visit_interrupted', 'report_correction_open', 'order_without_end_date' /* ORD0-4 */)),
         -- CSR1 / CGR-32: computed from the absence, never stored
         (case when d.exception_type = 'visit_overdue' and private.visit_responsible_absent(d.entity_id)
               then array['responsible_absent']
               -- CSR1 / CGR-34: stored on the cancellation (0054), not computed
               when d.exception_type = 'team_cancellation_late' and exists (
                      select 1 from public.visit_status_notes sn
                      where sn.visit_id = d.entity_id and sn.kind = 'cancelled' and sn.responsible_absent)
               then array['not_done_responsible_absent'] else array[]::text[] end)
         -- LEAVE1-C4: the take of a person whose access has ended ("Übernahme beendet – Zugang beendet"; no name)
         || case when coalesce(l.take_ended, false) then array['take_access_ended'] else array[]::text[] end
  from d
  join lateral private.effective_exception_rules(d.organization_id) r on r.exception_type = d.exception_type
  left join latest l on l.organization_id = d.organization_id and l.exception_key = d.exception_key
  left join public.cases c on c.id = d.case_id
  left join public.teams t on t.id = d.team_id
  left join public.teams ct on ct.id = c.assigned_team_id
  -- closed exceptions stay closed for this cause, except safety exceptions (CSR1 / CGR-06): they close only with it
  -- CGR-22 (PROVISIONAL, D-28): visit_uncovered also closes only with its cause (private.exception_closes_with_cause)
  where l.kind is null or l.kind = 'take' or r.priority = 'P1' or r.escalate_to_p1_after_hours is not null
     or d.exception_type in ('visit_uncovered', 'visit_interrupted', 'report_correction_open', 'order_without_end_date' /* ORD0-4 */)  -- CGR-25 (D-31), CGR-30 (D-28)
  order by 3, d.since;
end
$$;

create or replace function public.team_visit_alerts()
returns table (exception_key text, exception_type text, priority text, label text, detail text, since timestamptz,
               case_id uuid, client_name text, team_id uuid, team_name text, visit_id uuid, taken boolean, flags text[])
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
with my_teams as (
    select tm.team_id, t.organization_id, t.name
    from public.team_memberships tm
    join public.teams t on t.id = tm.team_id
    where tm.user_id = (select auth.uid())
  ), d as (
    select o.organization_id, x.*
    from (select distinct organization_id from my_teams) o, lateral private.derived_exceptions(o.organization_id) x
    where x.exception_type in ('visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date' /* ORD0-4 */)
      and x.team_id in (select mt.team_id from my_teams mt)
  ), latest as (
    select distinct on (ev.organization_id, ev.exception_key) ev.organization_id, ev.exception_key, ev.kind,
           (ev.kind = 'take' and private.access_ended(ev.actor_id)) as take_ended  -- LEAVE1-C4
    from public.exception_events ev
    where ev.organization_id in (select organization_id from my_teams) and ev.kind in ('take', 'close', 'auto_close')
      and ev.exception_key in (select d.exception_key from d)
    order by ev.organization_id, ev.exception_key, ev.id desc
  )
  select d.exception_key, d.exception_type,
         case when r.escalate_to_p1_after_hours is not null and private.now() >= d.since + make_interval(hours => r.escalate_to_p1_after_hours)
              then 'P1' else r.priority end,
         r.label, private.team_alert_detail(d.exception_type, d.entity_id, d.detail), d.since, d.case_id,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         d.team_id, (select mt.name from my_teams mt where mt.team_id = d.team_id limit 1),
         case when d.entity_type = 'visit' then d.entity_id end,  -- ORD0-4: a case alert has no visit
         coalesce(l.kind = 'take' and not l.take_ended, false),
         -- CSR1 / CGR-32: computed from the absence, never stored
         (case when d.exception_type = 'visit_overdue' and private.visit_responsible_absent(d.entity_id)
               then array['responsible_absent'] else array[]::text[] end)
         -- LEAVE1-C4: the take of a person whose access has ended
         || case when coalesce(l.take_ended, false) then array['take_access_ended'] else array[]::text[] end
  from d
  join lateral private.effective_exception_rules(d.organization_id) r on r.exception_type = d.exception_type
  left join latest l on l.organization_id = d.organization_id and l.exception_key = d.exception_key
  left join public.cases c on c.id = d.case_id
  where l.kind is null or l.kind = 'take' or r.priority = 'P1' or r.escalate_to_p1_after_hours is not null
     or d.exception_type in ('visit_interrupted', 'report_correction_open', 'order_without_end_date')  -- CGR-25, CGR-30: an earlier close never hides it
  order by 3, d.since;
end
$$;

-- field_quality: one more column, `claim_ended` (an `in_review` event whose owner's access has ended).
drop function if exists public.field_quality(date);
create function public.field_quality(p_date date)
returns table (visit_id uuid, kind text, id uuid, label text, severity text, status text, at timestamptz, own boolean,
               person_name text, claim_ended boolean)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
select q.visit_id, 'event', q.id, q.title, q.severity, q.status, coalesce(q.occurred_at, q.created_at), q.author_id = (select auth.uid()),
         private.member_name(v.organization_id, q.author_id),
         (q.status = 'in_review' and private.access_ended(q.owner_id))  -- LEAVE1-C4
  from public.quality_events q join public.care_visits v on v.id = q.visit_id
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  union all
  select h.visit_id, 'hold', h.id, h.reason, null, case when h.lifted_at is null then 'open' else 'lifted' end, h.set_at,
         h.set_by = (select auth.uid()),
         private.member_name(v.organization_id, h.set_by),
         false
  from public.quality_holds h join public.care_visits v on v.id = h.visit_id
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  order by 1, 7;
end
$$;
revoke all on function public.field_quality(date) from public, anon;
grant execute on function public.field_quality(date) to authenticated;
comment on function public.field_quality(date) is
  'QG1 (0020) with LEAVE1-3 (0074) and LEAVE1-C4 (ADR-093): events and holds of the day''s visits of the caller''s '
  'teams; person_name = who recorded it; claim_ended = an in_review event whose owner''s access has ended ("Übernahme '
  'beendet – Zugang beendet"). No owner name is returned.';

-- 4. DOOR1-12: no code in the intake note either -----------------------------------------------------------------------
create or replace function private.guard_case_access_notes()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if private.looks_like_code(new.access_notes)
     and (tg_op = 'INSERT' or new.access_notes is distinct from old.access_notes) then
    raise exception 'Bitte keinen Code erfassen' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_case_access_notes() from public, anon, authenticated;
drop trigger if exists cases_access_notes_guard on public.cases;
create trigger cases_access_notes_guard before insert or update of access_notes on public.cases
  for each row execute function private.guard_case_access_notes();
comment on function private.guard_case_access_notes() is
  'DOOR1-12 (ADR-093): every writer of cases.access_notes refuses four or more digits in a row (private.looks_like_code, '
  'the DOOR1-4 guard) with "Bitte keinen Code erfassen" (22023). Only a written or changed note is checked; existing '
  'rows are not rewritten (G-11 count: OWNER_RUNBOOK.md).';

-- 5. DOOR1-13: one access record, not two ------------------------------------------------------------------------------
drop function if exists public.field_door_notes(date);
create function public.field_door_notes(p_date date)
returns table (visit_id uuid, case_id uuid, access_notes text, language_notes text, intake_on date)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
select v.id, c.id, nullif(btrim(c.access_notes), ''), nullif(btrim(c.language_notes), ''),
         (private.at_zurich(coalesce(c.intake_consent_confirmed_at, c.created_at)))::date  -- DOOR1-13
  from public.care_visits v
  join public.cases c on c.id = v.case_id and c.organization_id = v.organization_id
  where p_date is not null and v.visit_date = p_date
    and (select auth.uid()) is not null
    and private.reads_visit(v.id)
  order by v.time_start nulls last, v.id;
end
$$;
revoke all on function public.field_door_notes(date) from public, anon;
grant execute on function public.field_door_notes(date) to authenticated;
comment on function public.field_door_notes(date) is
  'DOOR1-1 (0072) with DOOR1-13 (ADR-093): per visit on p_date that the caller reads (private.reads_visit), the intake '
  'notes of its case and the intake date (Zurich date of the intake confirmation, else of the case''s creation).';

create or replace function public.field_safety_alert_history(p_date date)
returns table (case_id uuid, category_code text, value text, note text, source text, recorded_at timestamptz,
               actor_kind text, actor_name text, from_intake boolean)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  if p_date is null or (select auth.uid()) is null then return; end if;
  return query
  with cs as (
    select distinct v.case_id, v.organization_id, v.team_id
    from public.care_visits v
    where v.visit_date = p_date and v.case_id is not null and private.reads_visit(v.id)
  )
  select x.case_id, cat.code, x.value, x.note, x.source, x.created_at,
         case
           when x.actor_id = (select auth.uid()) then 'me'
           when exists (select 1 from public.team_memberships tm where tm.team_id = cs.team_id and tm.user_id = x.actor_id) then 'team'
           when exists (select 1 from public.organization_memberships om
                        where om.organization_id = cs.organization_id and om.user_id = x.actor_id
                          and om.role in ('admin', 'coach', 'operations')) then 'coordination'
           else 'former'
         end,
         (select p.display_name from public.member_profiles p
          where p.organization_id = cs.organization_id and p.user_id = x.actor_id),
         false
  from cs
  join public.case_safety_alert_values x on x.case_id = cs.case_id and x.organization_id = cs.organization_id
  join public.safety_alert_categories cat on cat.id = x.category_id
  where cat.code = 'access_arrangement'
  union all
  -- The intake note as the earliest entry of the access arrangement (source `referral`); never copied into the values.
  select c.id, 'access_arrangement', null, btrim(c.access_notes), 'referral',
         coalesce(c.intake_consent_confirmed_at, c.created_at), null, null, true
  from cs join public.cases c on c.id = cs.case_id and c.organization_id = cs.organization_id
  where nullif(btrim(c.access_notes), '') is not null
  order by 1, 9, 6 desc;
end
$$;
revoke all on function public.field_safety_alert_history(date) from public, anon;
grant execute on function public.field_safety_alert_history(date) to authenticated;
comment on function public.field_safety_alert_history(date) is
  'DOOR1-13 (ADR-093): for the cases of the visits on p_date that the caller reads (private.reads_visit), every '
  'recorded value of the access arrangement (newest first; who, when, source), then the intake note as the earliest '
  'entry (source referral, from_intake). Display only; the intake note is never copied into the value table.';

-- The team's actor names are shown with each value exactly as on the card (field_safety_alerts); values stay
-- append-only and readable only through the SECURITY DEFINER readers.

-- 6. DOOR1-14: a clinical category needs a Clinical Rule Register reference -------------------------------------------
alter table public.safety_alert_categories drop constraint if exists safety_alert_categories_clinical_register_ref;
alter table public.safety_alert_categories add constraint safety_alert_categories_clinical_register_ref
  check (class <> 'clinical' or approval_ref ~ '^CR-[0-9]{3}$');
comment on constraint safety_alert_categories_clinical_register_ref on public.safety_alert_categories is
  'DOOR1-14 (CGR-61, ADR-093): a clinical category names its Clinical Rule Register row (CR-nnn). That the row is '
  'APPROVED is checked by scripts/agents-check.mjs for every migration that inserts a clinical category.';

drop function private.cond1_patch(text, text[], text);
