-- CSR1, seventh PR: CGR-19 (F6) and CGR-22 (OPS1), both advisory (S2), as the PO's interim criteria in
-- `docs/agents/briefs/CSR1.md` (CGR-19: 2026-10-23 03:10; CGR-22: 2026-10-23 07:10). ADR-055.
-- Clinical Governance Report sections 2026-10-23 02:28 (CGR-19) and 06:30 (CGR-22); unchanged in 10:29.
--
-- CGR-19 (F6, interim safe default until D-30, `clinical` with `legal`): a report correction carries the original
--   performer, and only she may sign it (0016 `correct_report` copies `performer_id`; 0041 `sign_report` requires
--   the performer). Once she has left the visit's team, a correction draft could never become final, and since 0040
--   an open correction draft also unlocks the visit's times and observations with no end (CGR-24).
--   `correct_report` now refuses with `performer_not_in_team` while the report's performer is not a member of the
--   report's team. Nothing is written; the current final version stays in force and readable. Who may correct and
--   sign in that case is D-30 (OPEN); this refusal is replaced when D-30 is answered. Rule register CR-048.
--   Not changed (OPEN, recorded in ADR-055): a correction draft opened while she was still a member stays open if she
--   leaves afterwards (0037 does not refuse the removal for a correction draft, CR-036).
--
-- CGR-22 (OPS1, strict provisional default until D-28, `clinical`): `visit_uncovered` (P2, not escalating) could be
--   closed by hand, and a close made a day ahead silenced it for that visit for good. It now **closes only with its
--   cause**, like a safety exception (CGR-06, 0039): `handle_exception(…, 'close', …)` returns `cause_persists`;
--   take over and notes stay; `operations_exceptions().closable` is false; a close written before this migration no
--   longer hides it. The exception exists exactly while the visit is planned, nobody is responsible, it is not
--   suspended and not covered (derived_exceptions, 0019 / 0038), so it ends by assigning someone, cancelling the
--   visit (or suspending it / a cover, which already end it today). Its priority (P2) and window (24 h) do not
--   change: whether it is a safety signal and at which priority stays D-28. Rule register CR-049.
--   An organisation that raises it to P1 or makes it escalate already gets the same through CGR-06.
--
-- Same signatures and return shapes; no data migration; no new grants beyond the existing ones.

-- 1. CGR-19: refuse a correction whose performer has left the team ---------------------------------------------------
create or replace function public.correct_report(p_report_id uuid, p_reason text, p_summary text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.visit_reports%rowtype;
  why text := private.check_text(p_reason, 3, 300, 'reason');
  rid uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if p_summary is not null and char_length(p_summary) > 4000 then
    raise exception 'summary too long' using errcode = '22023';
  end if;
  if private.begin_command('correct_report', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into r from public.visit_reports where id = p_report_id for update;
  if not found or not private.is_org_member(r.organization_id) or not private.is_team_member(r.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if r.status <> 'final' then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_final');
  end if;
  if exists (select 1 from public.visit_reports s where s.supersedes_id = r.id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_latest');
  end if;
  -- CSR1 / CGR-19 (interim, D-30): only the performer signs a correction (sign_report), so a correction of a report
  -- whose performer is no longer in the team could never become final. Refuse it; the final version stays in force.
  if not private.user_in_team(r.team_id, r.performer_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'performer_not_in_team');
  end if;
  insert into public.visit_reports
    (organization_id, visit_id, case_id, team_id, version, supersedes_id, correction_reason, status, snapshot,
     summary, performer_id, countersign_required, created_by)
  values
    (r.organization_id, r.visit_id, r.case_id, r.team_id, r.version + 1, r.id, why, 'draft',
     private.visit_report_snapshot(r.visit_id), coalesce(nullif(btrim(p_summary), ''), r.summary),
     r.performer_id, r.countersign_required, uid)
  returning id into rid;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', rid);
end;
$$;
revoke all on function public.correct_report(uuid, text, text, uuid) from public, anon;
grant execute on function public.correct_report(uuid, text, text, uuid) to authenticated;
comment on function public.correct_report(uuid, text, text, uuid) is
  'F6: opens a correction draft of the latest final report (team member, reason). CSR1 / CGR-19 (interim, D-30): '
  'refused with performer_not_in_team while the performer is not a member of the team; the final version stays.';

-- 2. CGR-22: which exceptions close only with their cause ------------------------------------------------------------
-- Safety exceptions (CGR-06: P1 or escalating to P1) and, as a strict provisional default, `visit_uncovered`.
create function private.exception_closes_with_cause(p_org uuid, p_type text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_type = 'visit_uncovered' or private.exception_is_safety(p_org, p_type)
$$;
revoke all on function private.exception_closes_with_cause(uuid, text) from public, anon, authenticated;
comment on function private.exception_closes_with_cause(uuid, text) is
  'CSR1: true for safety exceptions (CGR-06) and for visit_uncovered (CGR-22, PROVISIONAL until D-28). '
  'Such exceptions are not closed by hand; they end when their cause is resolved.';

-- 3. CGR-22: commands ------------------------------------------------------------------------------------------------
create or replace function private.open_exception_org(p_key text)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select o.organization_id
  from public.organization_memberships o
  where o.user_id = (select auth.uid()) and private.is_coordinator(o.organization_id)
    and exists (select 1 from private.derived_exceptions(o.organization_id) x where x.exception_key = p_key)
    and (private.exception_closes_with_cause(o.organization_id, split_part(p_key, ':', 1))
         or coalesce((select ev.kind from public.exception_events ev
                      where ev.organization_id = o.organization_id and ev.exception_key = p_key and ev.kind in ('take', 'close', 'auto_close')
                      order by ev.id desc limit 1), 'take') = 'take')
  limit 1
$$;
revoke all on function private.open_exception_org(text) from public, anon, authenticated;

-- Return: 'ok' | 'duplicate' | 'rejected' (not a coordinator, or the exception does not exist / is closed)
--       | 'cause_persists' (CGR-06 / CGR-22: this exception is not closed by hand; resolve its cause instead)
create or replace function public.handle_exception(p_key text, p_kind text, p_text text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
  txt text := nullif(btrim(p_text), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_kind is null or p_kind not in ('take', 'comment', 'close') or p_idempotency_key is null then
    raise exception 'kind must be take, comment or close, with an idempotency key' using errcode = '22023';
  end if;
  if p_kind in ('comment', 'close') and (txt is null or char_length(txt) < 3 or char_length(txt) > 1000) then
    raise exception 'a comment or a closing reason needs 3–1000 characters' using errcode = '22023';
  end if;
  if exists (select 1 from public.exception_events e where e.actor_id = uid and e.idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;
  org := private.open_exception_org(p_key);
  if org is null then return 'rejected'; end if;
  if p_kind = 'close' and private.exception_closes_with_cause(org, split_part(p_key, ':', 1)) then
    return 'cause_persists';
  end if;
  insert into public.exception_events (organization_id, exception_key, kind, text, actor_id, idempotency_key)
  values (org, p_key, p_kind, case when p_kind = 'take' then null else txt end, uid, p_idempotency_key);
  return 'ok';
end;
$$;
revoke all on function public.handle_exception(text, text, text, uuid) from public, anon;
grant execute on function public.handle_exception(text, text, text, uuid) to authenticated;

-- 4. CGR-22: the OPS1 reader (regenerated from the current definition; every find must match exactly once) -----------
create function private.csr1g_patch(p_fn text, p_pairs text[])
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

select private.csr1g_patch('public.operations_exceptions()', array[
  E'         not (r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null)\n',
  E'         not (r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null or d.exception_type = ''visit_uncovered'')\n',
  E'  where l.kind is null or l.kind = ''take'' or r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null\n',
  E'  -- CGR-22 (PROVISIONAL, D-28): visit_uncovered also closes only with its cause (private.exception_closes_with_cause)\n  where l.kind is null or l.kind = ''take'' or r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null\n     or d.exception_type = ''visit_uncovered''\n'
]);
drop function private.csr1g_patch(text, text[]);

revoke all on function public.operations_exceptions() from public, anon;
grant execute on function public.operations_exceptions() to authenticated;
comment on function public.operations_exceptions() is
  'OPS1: open exceptions for coordinators. closable = false for exceptions that close only with their cause: safety '
  'exceptions (P1 or escalating, CSR1 / CGR-06) and visit_uncovered (CSR1 / CGR-22, PROVISIONAL until D-28).';
