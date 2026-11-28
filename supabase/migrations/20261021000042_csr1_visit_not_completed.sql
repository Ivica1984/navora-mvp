-- CSR1, fifth PR: CGR-20 (blocking S1 for OPS1, Clinical Governance Report section 2026-10-23 06:30; ADR-053).
--
-- Problem: a `started` or `paused` visit could only end as `completed` (0007, 0038). Since 0039 its `visit_stuck`
-- exception closes only with its cause, so a visit that really stopped (client taken to hospital, nurse called away,
-- started by mistake) ended either as a permanent P1 or as a false completion (care recorded that was not given).
--
-- Change (CSR1 criterion CGR-20; interim safe default until D-31, `clinical` with `legal`):
--   * New terminal visit status `interrupted` ("nicht abgeschlossen"), reached only through the new command
--     `public.end_visit_not_completed(visit, reason_code, note, idempotency_key)`: audited (audit_care_visits and
--     audit_visit_status_notes), idempotent, a mandatory reason from a list, the actor recorded.
--     Reasons: client_transferred (client transferred or taken to hospital), client_declined (client declined to
--     continue), nurse_unavailable (nurse called away or unwell), started_by_mistake, other (needs a note).
--   * Allowed for any member of the visit's team (the performer is one: 0037 refuses her removal while the visit is
--     in progress) and for a coordination role of the organisation (admin, coach, operations), whatever the
--     qualification: it records that care stopped, not care given. No registered-nurse check (CGR-12 applies to
--     transitions into `started` and `completed` only).
--   * App users cannot reach `interrupted` by a direct status update: the transition list of
--     private.enforce_visit_transition is unchanged, so the reason can never be skipped. `interrupted` has no way out:
--     no complete, no resume, no restart (no transition from it is allowed, and every command filters on its state).
--   * `visit_stuck` (0038) is derived from status `on_the_way` / `started` / `paused`, so it ends with its cause; no
--     hand close (0039 unchanged).
--   * No billable fact, no F6 report obligation, no `report_not_final`, not a completed visit in AN1, J6 or HAND1:
--     every one of them reads `status = 'completed'` (0016 create_report_draft, 0019/0024 report_not_final,
--     0021 J6, 0022/0023 J5, 0027/0032 AN1, 0033 HAND1); nothing to change there. pgTAP 042 checks it.
--   * Visible to the team: `field_visit_status_notes` (0024) returns the reason on `/field`; HAND1 (0033) already
--     lists every `visit_status_notes` row of another visit of the case, so "Seit deinem letzten Einsatz" shows it.
--     Observations already recorded stay unchanged; new ones are refused as before 0042 (record_observation lists
--     on_the_way, started, paused, completed only).
-- Rule register: CR-042 (PROVISIONAL, D-31). No clinical, documentation or billing rule is invented.

-- 1. Timeline and reasons --------------------------------------------------------------------------------------------
alter table public.visit_events drop constraint visit_events_event_type_check;
alter table public.visit_events add constraint visit_events_event_type_check
  check (event_type in ('departed', 'started', 'paused', 'resumed', 'completed', 'cancelled', 'no_show', 'interrupted'));

alter table public.visit_status_notes drop constraint visit_status_notes_kind_check;
alter table public.visit_status_notes add constraint visit_status_notes_kind_check
  check (kind in ('cancelled', 'no_show', 'no_show_outcome', 'interrupted'));

alter table public.visit_status_notes drop constraint visit_status_notes_reason_code_check;
alter table public.visit_status_notes add constraint visit_status_notes_reason_code_check
  check (reason_code is null or reason_code in (
    'client_cancelled', 'client_in_hospital', 'team_cancelled', 'case_paused', 'case_closed', 'other',
    'client_reached', 'emergency_contact_informed', 'emergency_services_called',
    -- CSR1 / CGR-20 (0042)
    'client_transferred', 'client_declined', 'nurse_unavailable', 'started_by_mistake'));

-- An `interrupted` note always carries a reason code; `other` also a note (the command checks the same).
alter table public.visit_status_notes add constraint visit_status_notes_interrupted_reason
  check (kind <> 'interrupted' or (reason_code in ('client_transferred', 'client_declined', 'nurse_unavailable',
                                                   'started_by_mistake', 'other')
                                   and (reason_code <> 'other' or note is not null)));

comment on table public.visit_status_notes is
  'C1: append-only reasons for cancelled and no-show visits and no-show outcomes; CSR1 / CGR-20: reasons for visits ended as not completed.';

-- 2. Event writer: `interrupted` is a timeline event when the command records it (as cancelled / no_show, 0024) -------
create or replace function private.write_visit_event()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  kind text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  kind := case
    when new.status = 'on_the_way' then 'departed'
    when new.status = 'started' and old.status = 'paused' then 'resumed'
    when new.status = 'started' then 'started'
    when new.status = 'paused' then 'paused'
    when new.status = 'completed' then 'completed'
    when new.status = 'cancelled' then 'cancelled'
    when new.status = 'no_show' then 'no_show'
    when new.status = 'interrupted' then 'interrupted'
  end;
  if kind is null then
    return new;
  end if;
  -- Cancellation, no-show and not-completed are timeline events only when a command records them;
  -- a maintenance status change outside a command stays audited but off the timeline (009).
  if kind in ('cancelled', 'no_show', 'interrupted') and coalesce(current_setting('navora.command', true), '') = '' then
    return new;
  end if;
  insert into public.visit_events
    (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, command, idempotency_key)
  values
    (new.organization_id, new.id, new.team_id, kind, old.status, new.status, (select auth.uid()),
     nullif(current_setting('navora.command', true), ''),
     nullif(current_setting('navora.idempotency_key', true), '')::uuid);
  return new;
end;
$$;

-- 3. The command ------------------------------------------------------------------------------------------------------
-- Return: 'ok' | 'duplicate' | 'rejected' (not signed in, not in the visit's team and not a coordinator of its
-- organisation, or no such visit) | 'wrong_state' (not started or paused). Invalid reason or note → 22023.
create function public.end_visit_not_completed(p_visit_id uuid, p_reason_code text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := nullif(btrim(p_reason), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_reason_code is null or p_reason_code not in
       ('client_transferred', 'client_declined', 'nurse_unavailable', 'started_by_mistake', 'other') then
    raise exception 'reason: client_transferred, client_declined, nurse_unavailable, started_by_mistake or other'
      using errcode = '22023';
  end if;
  if why is not null and char_length(why) not between 3 and 1000 then
    raise exception 'the note needs 3–1000 characters' using errcode = '22023';
  end if;
  if p_reason_code = 'other' and why is null then
    raise exception 'reason "other" needs a note' using errcode = '22023';
  end if;
  if private.begin_command('end_visit_not_completed', p_idempotency_key) then return private.end_command('duplicate'); end if;

  -- Lock the visit: a parallel complete or pause waits, and the state check below sees its result.
  select * into v from public.care_visits where id = p_visit_id for update;
  if v.id is null
     or not private.is_org_member(v.organization_id)
     or not (private.is_team_member(v.team_id) or private.is_coordinator(v.organization_id)) then
    return private.end_command('rejected');
  end if;
  if v.status not in ('started', 'paused') then return private.end_command('wrong_state'); end if;

  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key)
  values (v.organization_id, v.id, 'interrupted', p_reason_code, why, uid, p_idempotency_key);
  update public.care_visits set status = 'interrupted' where id = v.id;
  return private.end_command('ok');
end;
$$;

revoke all on function public.end_visit_not_completed(uuid, text, text, uuid) from public, anon;
grant execute on function public.end_visit_not_completed(uuid, text, text, uuid) to authenticated;

comment on function public.end_visit_not_completed(uuid, text, text, uuid) is
  'CSR1 / CGR-20: ends a started or paused visit as not completed (status interrupted) with a reason. Team member or '
  'coordinator. No billable fact, no report obligation, not counted as completed. Interim safe default until D-31.';
