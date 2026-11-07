-- COND2-1 and COND2-2 (brief docs/agents/briefs/COND2.md, PO 2026-10-27 01:40). ADR-101. COND2-3 is app code only.
-- Builds on 0020 (QG1), 0074-0078 (LEAVE1), 0083 (WORK1-C3) and 0085 (LEAVE1-C5).
--
-- COND2-1 = COND1-C1 (COND1 deviation 16): a nurse's unexported-days count is readable only in the access-end path.
--   * `public.member_unexported_working_days(uuid)` (0083) is DROPPED. An administrator who calls it outside the access
--     end gets no count: the function no longer exists (the call is refused with "function does not exist").
--   * New command `public.prepare_member_access_end(person, key)`: the administrator opens the access-end step for a
--     person. It is a recorded read: one audit row per call (`audit_events`, table `organization_memberships`, entity
--     = the person, command `prepare_member_access_end`, changed `{"access_end_prepared": true}`). The audit row holds
--     WHO opened the step for WHOM and WHEN, never the count (WORK1-C3 (b): no stored per-person figure). It returns
--     `{"result": "ok", "unexported_days": n}` only for an administrator of an organisation of hers
--     (`private.leave1_org_for`, the scoping of end_member_access), while her access is open, and not for herself.
--     Otherwise `rejected` / `self` / `unchanged` (already ended) / `duplicate` (same key), each without a count.
--   * Why a recorded prepare (brief, open question): the count is needed BEFORE the end (the administrator's prompt
--     "Sie hat n bestätigte Tage noch nicht exportiert", G-19 item 4), so returning it only in the end result is too
--     late. An administrator can still open the step at any time, but every read now leaves an audit row naming her
--     (AUD1 catalogue, 0077); there is no silent, standing per-person view.
--   * `end_member_access` keeps `unexported_days` in its result (0083); `my_unexported_working_days` on /work unchanged.
-- COND2-2 = COND1-C2 (`cra` CGR-70, PS-59): a lapsed `in_review` quality claim can be taken over.
--   * `set_quality_event_status(event, 'in_review', …)` is accepted from `in_review` when, and only when, the current
--     claim has lapsed (`private.quality_claim_lapsed(event, owner)`, 0085). The caller needs the permission that already
--     allows open → in_review (`private.can_handle_quality_event`, 0020); no new role. A live claim stays `rejected`.
--   * The update sets the new owner (audited by the 0020 trigger on owner_id) and appends one `quality_event_log` row
--     in_review → in_review with the actor, key and `access_seq` (0085 trigger). Nothing is rewritten; the old claim
--     and its log row stay readable. A restore of the former owner gives nothing back: the newest in_review row is the
--     new owner's, and readers judge only the current owner.
--
-- No clinical, tariff, labour-law or legal rule; no threshold ("too long in review" stays D-16, clinical). No read
-- scope is widened. Idempotent: create or replace / drop if exists; the patch is skipped when its marker is present.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.cond2_patch(p_fn text, p_find text, p_replace text, p_marker text)
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
    raise exception '0087 patch for % must match once, matched %: %', p_fn, n, p_find;
  end if;
  def := replace(def, p_find, p_replace);
  if position(p_marker in def) = 0 then
    raise exception '0087 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.cond2_patch(text, text, text, text) from public, anon, authenticated;

-- 1. COND2-1: the standing reader goes ------------------------------------------------------------------------------
drop function if exists public.member_unexported_working_days(uuid);

-- 2. COND2-1: the recorded read when the access-end step opens -------------------------------------------------------
create or replace function public.prepare_member_access_end(p_user_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_idempotency_key is null then
    raise exception 'an idempotency key is required' using errcode = '22023';
  end if;
  -- begin_command also refuses a caller whose own access has ended (LEAVE1-3).
  if private.begin_command('prepare_member_access_end', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if p_user_id is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if p_user_id = uid then
    return jsonb_build_object('result', private.end_command('self'));
  end if;
  org := private.leave1_org_for(p_user_id);  -- an organisation of hers that the caller administers, else null
  if org is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if private.access_ended(p_user_id) then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;
  -- The recorded read: who opened the end step for whom, when. Never the count.
  perform private.audit_command(org, 'organization_memberships', p_user_id,
          jsonb_build_object('access_end_prepared', true));
  return jsonb_build_object('result', private.end_command('ok'),
                            'unexported_days', private.unexported_working_days(p_user_id, org));
end;
$$;
revoke all on function public.prepare_member_access_end(uuid, uuid) from public, anon;
grant execute on function public.prepare_member_access_end(uuid, uuid) to authenticated;
comment on function public.prepare_member_access_end(uuid, uuid) is
  'COND2-1 (COND1-C1, ADR-101): an administrator of the person''s organisation opens the access-end step. Recorded '
  '(one audit row: who, for whom, when; no count). Returns unexported_days (WORK1-C3) only on ok, i.e. for an '
  'administrator of her organisation while her access is open; rejected, self, unchanged or duplicate carry no count.';

-- AUD1-1 (0077): the key the recorded read writes is a flag (code), so the value catalogue stays complete.
insert into private.audit_value_classes (table_name, key, class)
values ('organization_memberships', 'access_end_prepared', 'code')
on conflict (table_name, key) do update set class = excluded.class;

-- 3. COND2-2: a lapsed in_review claim can be taken over ------------------------------------------------------------
select private.cond2_patch('public.set_quality_event_status(uuid, text, text, uuid)',
  $f$  if q.status = 'closed' or (p_status = 'in_review' and q.status <> 'open') then return 'rejected'; end if;$f$,
  $r$  -- COND2-2 (COND1-C2, ADR-101): from in_review only when the current claim has lapsed (0085); same permission.
  if q.status = 'closed' or (p_status = 'in_review' and q.status <> 'open'
                             and not (q.status = 'in_review' and q.owner_id is not null
                                      and private.quality_claim_lapsed(q.id, q.owner_id))) then
    return 'rejected';
  end if;$r$,
  'COND2-2');

comment on function public.set_quality_event_status(uuid, text, text, uuid) is
  'QG1 (0020): open → in_review (the caller becomes owner); open | in_review → closed (closing note required). '
  'COND2-2 (ADR-101): in_review → in_review (take-over) only when the current claim has lapsed '
  '(private.quality_claim_lapsed, 0085); the caller needs the same permission (can_handle_quality_event). Every '
  'transition is appended to quality_event_log with access_seq.';

drop function private.cond2_patch(text, text, text, text);
