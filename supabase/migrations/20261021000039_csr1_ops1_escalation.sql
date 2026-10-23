-- CSR1, second PR: OPS1's clinical-gate findings CGR-05 and CGR-06 (Clinical Governance Report 2026-10-22 22:30;
-- ADR-050).
--
-- CGR-05 (blocking, OPS1 and QG1): a serious quality event left OPS1 as soon as it was set to `in_review`.
--   `quality_serious_open` is now derived while the event is `open` **or** `in_review`; only `closed` ends it. The
--   key is unchanged (`quality_serious_open:<event>`), so take-over, notes and the escalation clock (`created_at`,
--   P2 → P1 after the configured hours, Q9 / CR-020) continue through the review. The detail says "in Bearbeitung".
--
-- CGR-06 (blocking, OPS1): a person's close silenced an exception for good, P1 included (`no_show_open` without an
--   outcome). Engineering's choice (ADR-050): a **safety exception cannot be closed by hand; it closes only when its
--   cause is resolved** (auto close). A safety exception is one whose effective rule (platform default with the
--   organisation's override, ADM1) is P1 **or escalates to P1** (`escalate_to_p1_after_hours` set): closing a P2
--   that becomes P1 later would silence that P1 in advance. With the pilot defaults these are
--   `no_show_open`, `visit_uncovered_hospital`, `quality_serious_open`, `visit_overdue`, `visit_stuck` and
--   `cover_without_access` (COVER1, switched off; P2 → P1 4 h before the start).
--   * `handle_exception(…, 'close', …)` returns the new result `cause_persists` for them; take over and notes stay.
--   * A close written before this migration no longer hides a safety exception whose cause persists: OPS1, the
--     team view and the commands treat it as open and not taken (re-open, so no legacy close silences a P1).
--   * The same holds for an auto close followed by the same cause again (e.g. a discharge visit assigned, then
--     released again): the exception is shown again.
--   * `operations_exceptions()` gains `closable` so the screen offers "Schliessen" only where it is allowed.
--   No threshold, priority or escalation rule changes; nothing clinical is invented (rule register CR-041).

-- 1. Which exception types are safety exceptions (P1 or escalating to P1), per organisation ---------------------------
create function private.exception_is_safety(p_org uuid, p_type text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((select r.priority = 'P1' or r.escalate_to_p1_after_hours is not null
                   from private.effective_exception_rules(p_org) r
                   where r.exception_type = p_type), false)
$$;
revoke all on function private.exception_is_safety(uuid, text) from public, anon, authenticated;
comment on function private.exception_is_safety(uuid, text) is
  'CSR1 / CGR-06: true when the effective rule is P1 or escalates to P1. Such exceptions close only with their cause.';

-- 2. Patch helper (regenerate from the current definition; every find must match exactly once) ------------------------
create function private.csr1b_patch(p_fn text, p_pairs text[], p_drop boolean default false)
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
  if p_drop then
    execute format('drop function %s', p_fn);
  end if;
  execute def;
end;
$$;

-- 3. CGR-05: a serious quality event stays an exception until it is closed ---------------------------------------------
select private.csr1b_patch('private.derived_exceptions(uuid)', array[
  E'select ''quality_serious_open:'' || q.id, ''quality_serious_open'', q.created_at, q.case_id, q.team_id, ''quality_event'', q.id, q.title\n',
  E'select ''quality_serious_open:'' || q.id, ''quality_serious_open'', q.created_at, q.case_id, q.team_id, ''quality_event'', q.id,\n         q.title || case when q.status = ''in_review'' then '' · in Bearbeitung'' else '''' end\n',
  E'where q.organization_id = p_org and q.status = ''open'' and q.severity in (''high'', ''critical'')',
  E'where q.organization_id = p_org and q.status in (''open'', ''in_review'') and q.severity in (''high'', ''critical'')'
]);

-- 4. CGR-06: readers show a safety exception while its cause persists, whatever was closed before -----------------------
-- Handling state of a safety exception: a close or auto close counts as "open, not taken"; only a later take counts.
select private.csr1b_patch('public.operations_exceptions()', array[
  E'         l.kind = ''take'' and l.actor_id = (select auth.uid()),\n',
  E'         coalesce(l.kind = ''take'' and l.actor_id = (select auth.uid()), false),\n',
  E'''[]''::jsonb),\n         case when l.kind = ''take'' then private.member_name(d.organization_id, l.actor_id) end\n  from d',
  E'''[]''::jsonb),\n         case when l.kind = ''take'' then private.member_name(d.organization_id, l.actor_id) end,\n         not (r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null)\n  from d',
  E'  where l.kind is null or l.kind = ''take''          -- closed exceptions stay closed for this cause\n',
  E'  -- closed exceptions stay closed for this cause, except safety exceptions (CSR1 / CGR-06): they close only with it\n  where l.kind is null or l.kind = ''take'' or r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null\n',
  E', owner_name text)\n LANGUAGE sql',
  E', owner_name text, closable boolean)\n LANGUAGE sql'
], true);
revoke all on function public.operations_exceptions() from public, anon;
grant execute on function public.operations_exceptions() to authenticated;
comment on function public.operations_exceptions() is
  'OPS1: open exceptions for coordinators. closable = false for safety exceptions (P1 or escalating), which close only with their cause (CSR1 / CGR-06).';

select private.csr1b_patch('public.team_visit_alerts()', array[
  E'  where l.kind is null or l.kind = ''take''\n',
  E'  where l.kind is null or l.kind = ''take'' or r.priority = ''P1'' or r.escalate_to_p1_after_hours is not null\n'
]);

drop function private.csr1b_patch(text, text[], boolean);

-- 5. CGR-06: commands --------------------------------------------------------------------------------------------------
-- The exception must exist; a non-safety exception must not be closed already. A safety exception that exists is
-- open by definition (its cause persists), whatever was written before.
create or replace function private.open_exception_org(p_key text)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select o.organization_id
  from public.organization_memberships o
  where o.user_id = (select auth.uid()) and private.is_coordinator(o.organization_id)
    and exists (select 1 from private.derived_exceptions(o.organization_id) x where x.exception_key = p_key)
    and (private.exception_is_safety(o.organization_id, split_part(p_key, ':', 1))
         or coalesce((select ev.kind from public.exception_events ev
                      where ev.organization_id = o.organization_id and ev.exception_key = p_key and ev.kind in ('take', 'close', 'auto_close')
                      order by ev.id desc limit 1), 'take') = 'take')
  limit 1
$$;
revoke all on function private.open_exception_org(text) from public, anon, authenticated;

-- Return: 'ok' | 'duplicate' | 'rejected' (not a coordinator, or the exception does not exist / is closed)
--       | 'cause_persists' (CSR1 / CGR-06: a safety exception is not closed by hand; resolve its cause instead)
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
  if p_kind = 'close' and private.exception_is_safety(org, split_part(p_key, ':', 1)) then
    return 'cause_persists';
  end if;
  insert into public.exception_events (organization_id, exception_key, kind, text, actor_id, idempotency_key)
  values (org, p_key, p_kind, case when p_kind = 'take' then null else txt end, uid, p_idempotency_key);
  return 'ok';
end;
$$;
revoke all on function public.handle_exception(text, text, text, uuid) from public, anon;
grant execute on function public.handle_exception(text, text, text, uuid) to authenticated;
