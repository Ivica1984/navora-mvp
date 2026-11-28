-- CSR1, fourth PR: CGR-02 "she signs what she saw" (F6, F7) (Clinical Governance Report 2026-10-22 22:30; ADR-052).
--
-- CGR-02 (blocking, F6, F7): `sign_report` (0016) rebuilt the snapshot at the moment of signing, and `/field` showed the
--   snapshot stored when the draft was created or last edited. A colleague's observation or a time correction recorded
--   in between was signed without the nurse ever seeing it.
--
-- Now:
--   1. The draft shows the facts as they are now. `field_reports` returns, for a `draft`, the snapshot built from the
--      live facts (the same builder `sign_report` uses), and for every version a `snapshot_hash` of exactly the snapshot
--      it returns. Signed and final versions show their stored, frozen snapshot as before.
--   2. The sign command carries that hash: `sign_report(p_report_id, p_snapshot_hash, p_idempotency_key)`. It rebuilds
--      the snapshot and signs only when its hash equals the one shown; otherwise it returns `rejected` with the reason
--      `facts_changed` and writes nothing. The screen reloads and shows the current facts; she checks them and signs
--      again. The stored snapshot of the signed version is the one whose hash she sent.
--   3. The old two-argument `sign_report(uuid, uuid)` is dropped, so no caller can sign without naming what was shown.
--   4. The snapshot builder runs with `timezone = UTC`, so its text (and the hash) does not depend on the session's
--      time zone setting. Stored snapshots keep their values; only the textual offset of new ones is fixed to UTC.
--
-- Unchanged: who may sign (the performer, a team member), countersignature (the signed snapshot is immutable, so the
-- countersigner signs the frozen version), corrections (F6 `correct_report`, 0040 lock), idempotency and audit
-- (`begin_command` / `end_command`, `audit_visit_reports`). No clinical rule is invented: this is the F6 rule
-- "the nurse signs the facts of the visit", enforced for the facts she actually saw.

-- 1. Deterministic snapshot text ----------------------------------------------------------------------------------------
alter function private.visit_report_snapshot(uuid) set timezone to 'UTC';

create function private.report_snapshot_hash(p_snapshot jsonb)
returns text
language sql immutable set search_path = ''
as $$
  select encode(sha256(convert_to(p_snapshot::text, 'UTF8')), 'hex');
$$;
revoke all on function private.report_snapshot_hash(jsonb) from public, anon, authenticated;
comment on function private.report_snapshot_hash(jsonb) is
  'CSR1 / CGR-02: sha256 of a report snapshot. field_reports shows it; sign_report signs only the snapshot with this hash.';

-- 2. Read model: drafts show the live facts, every row carries the hash of what it shows ---------------------------------
drop function public.field_reports(date);
create function public.field_reports(p_date date)
returns table (
  visit_id              uuid,
  report_id             uuid,
  version               integer,
  status                text,
  summary               text,
  snapshot              jsonb,
  correction_reason     text,
  countersign_required  boolean,
  signed_at             timestamptz,
  countersigned_at      timestamptz,
  i_am_performer        boolean,
  i_signed              boolean,
  i_can_countersign     boolean,
  signed_by_name        text,
  countersigned_by_name text,
  snapshot_hash         text
)
language sql stable security definer set search_path = ''
as $$
  select x.visit_id, x.id, x.version, x.status, x.summary, x.shown, x.correction_reason, x.countersign_required,
         x.signed_at, x.countersigned_at,
         x.performer_id = (select auth.uid()),
         x.signed_by = (select auth.uid()),
         x.status = 'signed' and x.countersign_required and x.performer_id <> (select auth.uid())
           and private.is_registered_nurse(x.team_id, (select auth.uid())),
         private.member_name(x.organization_id, x.signed_by),
         private.member_name(x.organization_id, x.countersigned_by),
         private.report_snapshot_hash(x.shown)
  from (
    select r.*,
           case when r.status = 'draft' then private.visit_report_snapshot(r.visit_id) else r.snapshot end as shown
    from public.visit_reports r
    join public.care_visits v on v.id = r.visit_id
    where p_date is not null and v.visit_date = p_date
      and private.is_org_member(r.organization_id) and private.is_team_member(r.team_id)
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)
  ) x
  order by x.visit_id;
$$;
revoke all on function public.field_reports(date) from public, anon;
grant execute on function public.field_reports(date) to authenticated;

-- 3. Sign exactly what was shown ----------------------------------------------------------------------------------------
drop function public.sign_report(uuid, uuid);
create function public.sign_report(p_report_id uuid, p_snapshot_hash text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  r     public.visit_reports%rowtype;
  fresh jsonb;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if private.begin_command('sign_report', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  -- The row lock serialises with correct_visit_time and record_observation (0040), which lock the report rows
  -- before they write: a fact recorded before this point is in `fresh`; one after it is refused (facts locked).
  select * into r from public.visit_reports where id = p_report_id for update;
  if not found or not private.is_org_member(r.organization_id) or not private.is_team_member(r.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if r.status <> 'draft' then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_draft');
  end if;
  if r.performer_id <> uid then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_performer');
  end if;
  -- CGR-02: she signs what she saw. Nothing is written when the facts changed since they were shown.
  fresh := private.visit_report_snapshot(r.visit_id);
  if p_snapshot_hash is null or p_snapshot_hash <> private.report_snapshot_hash(fresh) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'facts_changed');
  end if;
  update public.visit_reports
    set status = case when r.countersign_required then 'signed' else 'final' end,
        signed_by = uid, signed_at = now(),
        snapshot = fresh   -- exactly the snapshot whose hash she sent
    where id = r.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', r.id);
end;
$$;
revoke all on function public.sign_report(uuid, text, uuid) from public, anon;
grant execute on function public.sign_report(uuid, text, uuid) to authenticated;
comment on function public.sign_report(uuid, text, uuid) is
  'F6/F7 with CSR1 / CGR-02: signs the draft only when p_snapshot_hash equals the hash of the current facts '
  '(field_reports.snapshot_hash); otherwise rejected / facts_changed, nothing written.';
