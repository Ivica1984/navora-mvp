-- COND1-8 and COND1-5b (brief docs/agents/briefs/COND1.md, PO 2026-10-26 14:30 and 17:15). ADR-098.
-- Builds on 0019/0020 (OPS1, QG1), 0074 (LEAVE1 access events), 0080 (LEAVE1-C3, -C4) and 0083 (WORK1-C2).
--
-- COND1-8 = LEAVE1-C5 (CGR-67, PO decision 14:30): an OPS1 exception take and an `in_review` quality claim count only
--   if they were recorded after the person's latest access end: the LEAVE1-C3 rule (0080), by the access-event sequence.
--   A restore does not bring her name back; a take or claim recorded after the restore counts.
--   * Each new `exception_events` row and each new `quality_event_log` row records `access_seq`, the sequence number of
--     its actor's latest `ended` access event when it was written (0 = none), set by a BEFORE INSERT trigger (every
--     writer records it). The tables stay append-only (their update/delete guards are unchanged).
--   * OPS1 take: lapsed by `private.signal_take_lapsed(actor, access_seq, created_at)` (the C3 predicate: her access is
--     ended now, or an `ended` event with a higher sequence exists). Rows written before 0085 (access_seq null) are
--     judged by time, as C3 does: lapsed once an `ended` event exists at or after the take.
--   * Quality claim: the claim is the newest `quality_event_log` row of the event with `to_status = 'in_review'` (the
--     owner's transition, 0020). `private.quality_claim_lapsed(event, owner)` applies the same predicate to it.
--     A claim with NO recorded transition (an in_review row written outside set_quality_event_status, e.g. as the table
--     owner) has no time to compare with: it is read as lapsed once the owner has any `ended` access event (the safe
--     side: the team sees "Übernahme beendet – Zugang beendet" and handles it). Proposed on the hand-off (PO 14:30, (2)).
--   * Readers changed: `operations_exceptions`, `team_visit_alerts` (take_ended), `field_quality` (claim_ended). Display
--     and counting only; nothing is rewritten; `handle_exception`, the P2 → P1 clock and the QG1 rules are unchanged.
-- COND1-5b (PO 17:15, lca 16:42 on D-23 point (2)): information text `work1-notice-v3` (src/features/work/rules.ts).
--   A v2 acknowledgement does not carry over (`my_working_time_notice` and `my_working_day` compare with the current
--   version, 0079/0081); `acknowledge_working_time_notice` accepts only v3 ('invalid' for v1 and v2). Rows stay as they are.
--
-- No clinical, tariff, labour-law or legal rule. Idempotent: add column if not exists / create or replace / drop trigger
-- if exists; each patch is skipped when its marker is present. A second run changes nothing.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.cond1_8_patch(p_fn text, p_find text, p_replace text, p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  n := (length(def) - length(replace(def, p_find, ''))) / length(p_find);
  if n <> 1 then
    raise exception '0085 patch for % must match once, matched %: %', p_fn, n, p_find;
  end if;
  def := replace(def, p_find, p_replace);
  if position(p_marker in def) = 0 then
    raise exception '0085 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.cond1_8_patch(text, text, text, text) from public, anon, authenticated;

-- 1. The access sequence on every new take and every new quality transition -----------------------------------------
alter table public.exception_events add column if not exists access_seq bigint;
comment on column public.exception_events.access_seq is
  'LEAVE1-C5 (CGR-67, ADR-098): sequence number of the actor''s latest `ended` access event when the row was written '
  '(0 = none). A later `ended` event lapses a take for good; a restore does not revive it. Null = written before 0085.';
alter table public.quality_event_log add column if not exists access_seq bigint;
comment on column public.quality_event_log.access_seq is
  'LEAVE1-C5 (CGR-67, ADR-098): sequence number of the actor''s latest `ended` access event when the transition was '
  'recorded (0 = none). For an in_review transition: a later `ended` event lapses the claim. Null = written before 0085.';

create or replace function private.stamp_access_seq()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  new.access_seq := case when new.actor_id is null then null else private.latest_access_end_seq(new.actor_id) end;
  return new;
end;
$$;
revoke all on function private.stamp_access_seq() from public, anon, authenticated;
comment on function private.stamp_access_seq() is
  'LEAVE1-C5 (ADR-098): records the actor''s latest access-end sequence on an exception event or a quality transition '
  '(null for an automatic close without actor).';

drop trigger if exists stamp_exception_events on public.exception_events;
create trigger stamp_exception_events before insert on public.exception_events
  for each row execute function private.stamp_access_seq();
drop trigger if exists stamp_quality_event_log on public.quality_event_log;
create trigger stamp_quality_event_log before insert on public.quality_event_log
  for each row execute function private.stamp_access_seq();

-- 2. The quality claim predicate -----------------------------------------------------------------------------------------
create or replace function private.quality_claim_lapsed(p_event_id uuid, p_owner uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.signal_take_lapsed(
           p_owner,
           (select l.access_seq from public.quality_event_log l
            where l.event_id = p_event_id and l.to_status = 'in_review' order by l.id desc limit 1),
           coalesce((select l.created_at from public.quality_event_log l
                     where l.event_id = p_event_id and l.to_status = 'in_review' order by l.id desc limit 1),
                    '-infinity'::timestamptz))
$$;
revoke all on function private.quality_claim_lapsed(uuid, uuid) from public, anon, authenticated;
comment on function private.quality_claim_lapsed(uuid, uuid) is
  'LEAVE1-C4 with LEAVE1-C5 (CGR-67, ADR-098): the in_review claim of the event no longer counts: the owner''s access '
  'is ended now, or an `ended` access event was recorded after her claim (also when her access was restored since). '
  'Without a recorded in_review transition: lapsed once the owner has any `ended` access event.';

-- 3. The readers (patched from their current definitions; markers make a second run a no-op) -------------------------
select private.cond1_8_patch('public.operations_exceptions()',
  $f$(ev.kind = 'take' and private.access_ended(ev.actor_id)) as take_ended  -- LEAVE1-C4$f$,
  $r$(ev.kind = 'take' and private.signal_take_lapsed(ev.actor_id, ev.access_seq, ev.created_at)) as take_ended  -- LEAVE1-C4, LEAVE1-C5$r$,
  'LEAVE1-C5');
select private.cond1_8_patch('public.team_visit_alerts()',
  $f$(ev.kind = 'take' and private.access_ended(ev.actor_id)) as take_ended  -- LEAVE1-C4$f$,
  $r$(ev.kind = 'take' and private.signal_take_lapsed(ev.actor_id, ev.access_seq, ev.created_at)) as take_ended  -- LEAVE1-C4, LEAVE1-C5$r$,
  'LEAVE1-C5');
select private.cond1_8_patch('public.field_quality(date)',
  $f$(q.status = 'in_review' and private.access_ended(q.owner_id))  -- LEAVE1-C4$f$,
  $r$(q.status = 'in_review' and private.quality_claim_lapsed(q.id, q.owner_id))  -- LEAVE1-C4, LEAVE1-C5$r$,
  'LEAVE1-C5');

comment on function public.field_quality(date) is
  'QG1 (0020) with LEAVE1-3 (0074), LEAVE1-C4 (ADR-093) and LEAVE1-C5 (ADR-098): events and holds of the day''s visits '
  'of the caller''s teams; person_name = who recorded it; claim_ended = an in_review event whose claim no longer counts '
  '(the owner''s access is ended, or ended after the claim, also when restored since: "Übernahme beendet – Zugang '
  'beendet"). No owner name is returned.';

drop function private.cond1_8_patch(text, text, text, text);

-- 4. COND1-5b: the information text version ----------------------------------------------------------------------------
create or replace function private.working_time_notice_version()
returns text language sql immutable set search_path = ''
as $$ select 'work1-notice-v3'::text $$;
revoke all on function private.working_time_notice_version() from public, anon;
grant execute on function private.working_time_notice_version() to authenticated;
comment on function private.working_time_notice_version() is
  'WORK1-8 / WORK1-C2 / COND1-5b: version of the fixed information text (src/features/work/rules.ts NOTICE_VERSION). '
  'A new text needs a new version and a new acknowledgement; an earlier acknowledgement does not carry over (v3 since '
  '0085).';
