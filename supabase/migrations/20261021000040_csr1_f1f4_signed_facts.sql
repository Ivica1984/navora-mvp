-- CSR1, third PR: F1-F4's clinical-gate findings CGR-01 and CGR-03 (F3/F4 part) (Clinical Governance Report
-- 2026-10-22 22:30; ADR-051).
--
-- CGR-01 (blocking, F1-F4): any team member could supersede a colleague's observation; the new version carried the
--   editor as author and the read models showed only the latest version, so a colleague's statement could be
--   replaced. `record_observation` now refuses a supersede unless the caller wrote the superseded version
--   (`prev.author_id = auth.uid()`): result `rejected`, nothing written. A colleague adds her own observation instead.
--
-- CGR-03, F3/F4 part (blocking, F3, F6): time corrections and observations were accepted after the visit report was
--   signed. The F6 report snapshot is frozen at signing, so the live facts drifted silently away from the signed
--   statement. Now the visit's facts are **locked while its latest report version is `signed` or `final`**:
--   `correct_visit_time` and `record_observation` return `rejected` and write nothing. Changes go only through the F6
--   correction path: `correct_report` opens a correction draft (a new latest version, status `draft`), which unlocks
--   the facts; the draft's snapshot is refreshed by `update_report_draft` and frozen again by `sign_report`, so the
--   correction version carries the changed facts and the earlier signed version stays unchanged.
--   * `signed` (awaiting countersignature) is locked too, stricter than the report's "after final": the countersigner
--     signs the frozen snapshot, so a live change in between would also be a silent change after signature.
--   * The J5 part of CGR-03 (billing facts from the signed snapshot, not live times) is J5's and not changed here.
--
-- Both commands keep their signature and their result contract ('ok' | 'duplicate' | 'rejected'); every other check
-- is unchanged from 0008 / 0009. No clinical rule is invented: who may correct a signed report is F6's existing rule.

-- 1. Lock helper --------------------------------------------------------------------------------------------------------
create function private.visit_facts_locked(p_visit_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.visit_reports r
    where r.visit_id = p_visit_id
      and r.status in ('signed', 'final')
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)
  );
$$;
-- Internal: called only from the security-definer commands below (no report state leaks to app users).
revoke all on function private.visit_facts_locked(uuid) from public, anon, authenticated;
comment on function private.visit_facts_locked(uuid) is
  'CSR1 / CGR-03: true while the latest report version of the visit is signed or final. Times and observations '
  'then change only through a report correction version (F6 correct_report).';

-- 2. F3: correct_visit_time (0008) plus the lock --------------------------------------------------------------------------
create or replace function public.correct_visit_time(
  p_event_id bigint, p_corrected_at timestamptz, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid    uuid := (select auth.uid());
  ev     public.visit_events%rowtype;
  reason text := btrim(p_reason);
  prev   timestamptz;
  nxt    timestamptz;
begin
  if uid is null then
    return 'rejected';
  end if;
  if p_idempotency_key is null or p_corrected_at is null then
    raise exception 'event time and idempotency key are required' using errcode = '22023';
  end if;
  if reason is null or char_length(reason) not between 5 and 500 then
    raise exception 'a reason of 5–500 characters is required' using errcode = '22023';
  end if;
  if p_corrected_at > now() + interval '1 minute' then
    raise exception 'a corrected time cannot lie in the future' using errcode = '22023';
  end if;

  if exists (select 1 from public.visit_time_corrections c
             where c.actor_id = uid and c.idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;

  select * into ev from public.visit_events e where e.id = p_event_id;
  if not found
     or not private.is_org_member(ev.organization_id)
     or ev.team_id is null
     or not private.is_team_member(ev.team_id) then
    return 'rejected';
  end if;

  -- CGR-03: signed means fixed. Only a report correction version (F6) reopens the facts.
  -- Serialise with sign_report / correct_report, which lock the report row.
  perform 1 from public.visit_reports r where r.visit_id = ev.visit_id for update;
  if private.visit_facts_locked(ev.visit_id) then
    return 'rejected';
  end if;

  -- Neighbours in the visit's timeline (recording order) with their effective times.
  select private.effective_event_time(e.id) into prev
  from public.visit_events e where e.visit_id = ev.visit_id and e.id < ev.id
  order by e.id desc limit 1;
  select private.effective_event_time(e.id) into nxt
  from public.visit_events e where e.visit_id = ev.visit_id and e.id > ev.id
  order by e.id asc limit 1;

  if (prev is not null and p_corrected_at < prev) or (nxt is not null and p_corrected_at > nxt) then
    raise exception 'the corrected time would put the visit timeline out of order' using errcode = '23514';
  end if;

  insert into public.visit_time_corrections
    (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key)
  values
    (ev.organization_id, ev.visit_id, ev.team_id, ev.id, p_corrected_at, reason, uid, p_idempotency_key);

  return 'ok';
end;
$$;

revoke all on function public.correct_visit_time(bigint, timestamptz, text, uuid) from public, anon;
grant execute on function public.correct_visit_time(bigint, timestamptz, text, uuid) to authenticated;

-- 3. F4: record_observation (0009) plus author check and lock -------------------------------------------------------------
create or replace function public.record_observation(
  p_visit_id uuid, p_content text, p_for_handover boolean, p_supersedes_id uuid, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid     uuid := (select auth.uid());
  v       public.care_visits%rowtype;
  prev    public.visit_observations%rowtype;
  body    text := btrim(p_content);
begin
  if uid is null then
    return 'rejected';
  end if;
  if p_idempotency_key is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;
  if body is null or char_length(body) not between 1 and 2000 then
    raise exception 'an observation needs 1–2000 characters' using errcode = '22023';
  end if;

  if exists (select 1 from public.visit_observations o
             where o.author_id = uid and o.idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;

  select * into v from public.care_visits where id = p_visit_id;
  if not found
     or v.team_id is null
     or not private.is_org_member(v.organization_id)
     or not private.is_team_member(v.team_id)
     -- during or after the visit, not before it
     or v.status not in ('on_the_way', 'started', 'paused', 'completed') then
    return 'rejected';
  end if;

  -- CGR-03: signed means fixed. Only a report correction version (F6) reopens the facts.
  perform 1 from public.visit_reports r where r.visit_id = v.id for update;
  if private.visit_facts_locked(v.id) then
    return 'rejected';
  end if;

  if p_supersedes_id is not null then
    select * into prev from public.visit_observations where id = p_supersedes_id;
    if not found
       or prev.visit_id <> v.id
       -- CGR-01: only the author supersedes her observation; a colleague adds her own instead.
       or prev.author_id <> uid
       or exists (select 1 from public.visit_observations s where s.supersedes_id = prev.id) then
      return 'rejected';   -- unknown, other visit, someone else's, or not the latest version
    end if;
  end if;

  insert into public.visit_observations
    (organization_id, visit_id, case_id, team_id, author_id, content, for_handover,
     supersedes_id, idempotency_key)
  values
    (v.organization_id, v.id, v.case_id, v.team_id, uid, body, coalesce(p_for_handover, false),
     p_supersedes_id, p_idempotency_key);

  return 'ok';
end;
$$;

revoke all on function public.record_observation(uuid, text, boolean, uuid, uuid) from public, anon;
grant execute on function public.record_observation(uuid, text, boolean, uuid, uuid) to authenticated;
