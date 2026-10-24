-- CSR1, eighth PR: CGR-25 (OPS1, advisory S2), the PO's strict provisional default in `docs/agents/briefs/CSR1.md`
-- (criterion added 2026-10-23 11:25; `cra` section 10:29). Completes CSR1 part 7 with CGR-22 (0044). ADR-056.
--
-- Problem: since 0042 a visit ended as *not completed* (`interrupted`) drops every alert: `visit_stuck` ends with its
-- cause, and there is no report obligation. Care that was due (medication, wound care) was then seen only at the next
-- visit, and nobody had to decide about it.
--
-- Change (interim safe default until D-31, `clinical` with `legal`; rule register CR-050):
--   * New exception type `visit_interrupted` (P2, no threshold, not escalating; PROVISIONAL): it exists from the
--     moment a visit is ended as not completed until a person records a **follow-up decision** for it.
--     Its detail carries the visit's date and time, the interruption reason and note, and for `client_transferred`
--     the case's next planned visit (or "kein weiterer Einsatz geplant").
--   * New command `public.record_interruption_followup(visit, decision, note, idempotency_key)`: audited
--     (audit_visit_status_notes), idempotent, a decision from a short list: `follow_up_planned` ("Folgeeinsatz
--     geplant"), `no_longer_needed` ("nicht mehr nötig"), `other` (needs a note). Allowed for any member of the
--     visit's team and for a coordination role of the organisation (admin, coach, operations), as the not-completed
--     end itself (0042). One decision per visit (unique index); a second one returns `already_decided`.
--   * The exception **closes only with its cause** (the decision), like CGR-06/CGR-22: OPS1's generic hand close
--     returns `cause_persists` and `closable = false`, so a close without one of the listed reasons is impossible.
--     Take over and notes stay.
--   * Visible to the team: `team_visit_alerts` (0038) now also returns `visit_interrupted` (shown on `/team` and, new,
--     on `/field`); Operations sees it in `operations_exceptions`. HAND1 (0033) lists the decision automatically
--     (every `visit_status_notes` row of another visit of the case) as `visit_interruption_followup`.
--   * What the follow-up must contain, who may decide it and whether a decision can be corrected stay D-31.
--     Nothing here plans a visit: "Folgeeinsatz geplant" records a person's statement, it does not check a plan.
-- No clinical rule is invented. Same signatures for every changed reader; no data migration.

-- 1. The decision: a visit_status_notes row of a new kind -------------------------------------------------------------
alter table public.visit_status_notes drop constraint visit_status_notes_kind_check;
alter table public.visit_status_notes add constraint visit_status_notes_kind_check
  check (kind in ('cancelled', 'no_show', 'no_show_outcome', 'interrupted', 'interruption_followup'));

alter table public.visit_status_notes drop constraint visit_status_notes_reason_code_check;
alter table public.visit_status_notes add constraint visit_status_notes_reason_code_check
  check (reason_code is null or reason_code in (
    'client_cancelled', 'client_in_hospital', 'team_cancelled', 'case_paused', 'case_closed', 'other',
    'client_reached', 'emergency_contact_informed', 'emergency_services_called',
    -- CSR1 / CGR-20 (0042)
    'client_transferred', 'client_declined', 'nurse_unavailable', 'started_by_mistake',
    -- CSR1 / CGR-25 (0045)
    'follow_up_planned', 'no_longer_needed'));

-- A follow-up decision always carries a decision code; `other` also a note (the command checks the same).
alter table public.visit_status_notes add constraint visit_status_notes_followup_reason
  check (kind <> 'interruption_followup'
         or (reason_code in ('follow_up_planned', 'no_longer_needed', 'other') and (reason_code <> 'other' or note is not null)));

-- One decision per interrupted visit (a parallel second decision fails here, not silently twice).
create unique index visit_status_notes_one_followup on public.visit_status_notes (visit_id) where kind = 'interruption_followup';

comment on table public.visit_status_notes is
  'C1: append-only reasons for cancelled and no-show visits and no-show outcomes; CSR1 / CGR-20: reasons for visits '
  'ended as not completed; CSR1 / CGR-25: the follow-up decision after such an end.';

-- 2. The exception type (PROVISIONAL, D-31) ---------------------------------------------------------------------------
-- No threshold (raised at once), not escalating. Organisations may only raise it to P1 (exception_rule_range).
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  ('visit_interrupted', 'P2', null, null, null, 'Einsatz nicht abgeschlossen: Entscheid offen',
   'Das Team entscheidet über die noch fällige Pflege: Folgeeinsatz planen oder festhalten, dass sie nicht mehr nötig ist. Provisorische Regel (D-31, klinisch offen).');

-- 3. Which exceptions close only with their cause: add visit_interrupted (0044 + CGR-25) -------------------------------
create or replace function private.exception_closes_with_cause(p_org uuid, p_type text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_type in ('visit_uncovered', 'visit_interrupted') or private.exception_is_safety(p_org, p_type)
$$;
revoke all on function private.exception_closes_with_cause(uuid, text) from public, anon, authenticated;
comment on function private.exception_closes_with_cause(uuid, text) is
  'CSR1: true for safety exceptions (CGR-06), for visit_uncovered (CGR-22, PROVISIONAL until D-28) and for '
  'visit_interrupted (CGR-25, PROVISIONAL until D-31). Such exceptions are not closed by hand; they end when their '
  'cause is resolved (visit_interrupted: a follow-up decision, public.record_interruption_followup).';

-- 4. Readers, regenerated from their current definitions (every find must match exactly once) ------------------------
create function private.csr1h_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'CSR1 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

-- 4a. The derived exception, appended after the last branch (visit_stuck, 0038).
select private.csr1h_patch('private.derived_exceptions(uuid)', array[
  E'    and now() >= private.after_threshold(st.ref, r.amount, r.unit)\n',
  E'    and now() >= private.after_threshold(st.ref, r.amount, r.unit)
  union all
  -- CSR1 / CGR-25 (PROVISIONAL, D-31): a visit ended as not completed, until a person records the follow-up decision
  select ''visit_interrupted:'' || v.id, ''visit_interrupted'', s.created_at, v.case_id, v.team_id, ''visit'', v.id,
         to_char(v.visit_date, ''DD.MM.'') || coalesce('' '' || to_char(v.time_start, ''HH24:MI''), '''') || '' · ''
           || case s.reason_code
                when ''client_transferred'' then ''Klient:in verlegt bzw. ins Spital gebracht''
                when ''client_declined'' then ''Klient:in lehnt die Fortsetzung ab''
                when ''nurse_unavailable'' then ''Pflegeperson abberufen oder unwohl''
                when ''started_by_mistake'' then ''Irrtümlich gestartet''
                else ''Anderer Grund''
              end
           || coalesce('' – '' || left(s.note, 200), '''')
           || case when s.reason_code = ''client_transferred'' then
                coalesce('' · nächster geplanter Einsatz: '' || (
                  select to_char(n.visit_date, ''DD.MM.'') || coalesce('' '' || to_char(n.time_start, ''HH24:MI''), '''')
                  from public.care_visits n
                  where n.case_id = v.case_id and n.organization_id = v.organization_id and n.id <> v.id
                    and n.status = ''planned''
                    and (n.visit_date + coalesce(n.time_start, time ''23:59'')) at time zone ''Europe/Zurich'' >= s.created_at
                  order by n.visit_date, n.time_start nulls last, n.id
                  limit 1), '' · kein weiterer Einsatz geplant'')
              else '''' end
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = ''interrupted''
  join rules r on r.exception_type = ''visit_interrupted''
  where v.organization_id = p_org and v.status = ''interrupted''
    and not exists (select 1 from public.visit_status_notes f where f.visit_id = v.id and f.kind = ''interruption_followup'')
'
]);

-- 4b. OPS1 reader: not closable, and an earlier close never hides it.
select private.csr1h_patch('public.operations_exceptions()', array[
  E'or d.exception_type = ''visit_uncovered'')\n',
  E'or d.exception_type in (''visit_uncovered'', ''visit_interrupted''))\n',
  E'     or d.exception_type = ''visit_uncovered''\n',
  E'     or d.exception_type in (''visit_uncovered'', ''visit_interrupted'')  -- CGR-25 (PROVISIONAL, D-31)\n'
]);

-- 4c. Team view: interrupted visits waiting for a decision are visible to every member of the visit's team.
select private.csr1h_patch('public.team_visit_alerts()', array[
  E'x.exception_type in (''visit_overdue'', ''visit_stuck'')',
  E'x.exception_type in (''visit_overdue'', ''visit_stuck'', ''visit_interrupted'')',
  E'  where l.kind is null or l.kind = ''take'' or r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null\n',
  E'  where l.kind is null or l.kind = ''take'' or r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null\n     or d.exception_type = ''visit_interrupted''  -- CGR-25: an earlier close never hides it\n'
]);

drop function private.csr1h_patch(text, text[]);

revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;
revoke all on function public.operations_exceptions() from public, anon;
grant execute on function public.operations_exceptions() to authenticated;
revoke all on function public.team_visit_alerts() from public, anon;
grant execute on function public.team_visit_alerts() to authenticated;
comment on function public.operations_exceptions() is
  'OPS1: open exceptions for coordinators. closable = false for exceptions that close only with their cause: safety '
  'exceptions (P1 or escalating, CSR1 / CGR-06), visit_uncovered (CSR1 / CGR-22, PROVISIONAL until D-28) and '
  'visit_interrupted (CSR1 / CGR-25, PROVISIONAL until D-31).';
comment on function public.team_visit_alerts() is
  'CSR1: overdue and stuck visits (CGR-04, PROVISIONAL thresholds, D-28) and interrupted visits waiting for a '
  'follow-up decision (CGR-25, PROVISIONAL, D-31) of the caller''s teams. Read-only.';

-- 5. The command ------------------------------------------------------------------------------------------------------
-- Return: 'ok' | 'duplicate' | 'rejected' (not signed in, not in the visit's team and not a coordinator of its
-- organisation, or no such visit) | 'wrong_state' (the visit is not interrupted) | 'already_decided'.
-- Invalid decision or note → 22023.
create function public.record_interruption_followup(p_visit_id uuid, p_decision text, p_note text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := nullif(btrim(p_note), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_decision is null or p_decision not in ('follow_up_planned', 'no_longer_needed', 'other') then
    raise exception 'decision: follow_up_planned, no_longer_needed or other' using errcode = '22023';
  end if;
  if why is not null and char_length(why) not between 3 and 1000 then
    raise exception 'the note needs 3–1000 characters' using errcode = '22023';
  end if;
  if p_decision = 'other' and why is null then
    raise exception 'decision "other" needs a note' using errcode = '22023';
  end if;
  if private.begin_command('record_interruption_followup', p_idempotency_key) then return private.end_command('duplicate'); end if;

  -- Lock the visit: a parallel decision waits and then sees the first one.
  select * into v from public.care_visits where id = p_visit_id for update;
  if v.id is null
     or not private.is_org_member(v.organization_id)
     or not (private.is_team_member(v.team_id) or private.is_coordinator(v.organization_id)) then
    return private.end_command('rejected');
  end if;
  if v.status <> 'interrupted' then return private.end_command('wrong_state'); end if;
  if exists (select 1 from public.visit_status_notes f where f.visit_id = v.id and f.kind = 'interruption_followup') then
    return private.end_command('already_decided');
  end if;

  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key)
  values (v.organization_id, v.id, 'interruption_followup', p_decision, why, uid, p_idempotency_key);
  return private.end_command('ok');
end;
$$;

revoke all on function public.record_interruption_followup(uuid, text, text, uuid) from public, anon;
grant execute on function public.record_interruption_followup(uuid, text, text, uuid) to authenticated;

comment on function public.record_interruption_followup(uuid, text, text, uuid) is
  'CSR1 / CGR-25: records the follow-up decision for a visit ended as not completed (follow_up_planned, '
  'no_longer_needed, other with a note); ends its visit_interrupted exception. Team member or coordinator. '
  'Interim safe default until D-31.';
