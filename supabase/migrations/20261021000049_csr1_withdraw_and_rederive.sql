-- CSR1, part 9: CGR-24-W (PO decision 2026-10-23 15:25), CGR-29 (J5, advisory S3, `cra` 2026-10-23 14:30) and J5-C1
-- (J5 condition, PO 2026-10-23 11:25). ADR-060. Brief `docs/agents/briefs/CSR1.md` (part 9), `docs/agents/briefs/J5.md`.
-- All three keep "signed means fixed" true for billing and the record without costing a nurse a signature for nothing.
--
-- CGR-24-W: the performer withdraws her own correction draft while it is untouched.
--   * `withdraw_report_correction(report, key)`: one command, no reason (nothing changed, nothing to explain).
--   * Untouched = status `draft`, it is a correction (`supersedes_id` set), no time correction and no observation was
--     recorded on the visit since the draft was opened, and its summary equals the summary of the version it corrects.
--     The summary check is stricter than the criterion's wording (recorded deviation, ADR-060): a summary she typed
--     would otherwise be dropped without a trace in a signed version.
--   * The row is kept: status `withdrawn`, `withdrawn_by`, `withdrawn_at`; never deleted; terminal (the guard refuses
--     every later change). The audit trigger records it with the command and key.
--   * A withdrawn version is not a successor: the final version it corrected is again the latest, so the visit's times
--     and observations are locked as before (0040), `report_correction_open` (0047) ends, /field shows the final
--     version, and a later correction can be opened again (it takes the next free version number, so the withdrawn
--     number is never reused and the gap stays visible).
--   * Refused, nothing written: `not_team_member`; `not_performer` (anyone else); `not_correction` (a first draft is
--     not a correction; withdrawing it would leave a completed visit without a report); `awaiting_countersignature`
--     (a signed correction: whether a countersigner may return a report is D-10); `not_draft` (final);
--     `draft_has_changes` (those changes must be signed, so record and signed snapshot never diverge).
--   * Idempotent: the same key returns `duplicate`; a new key on an already withdrawn draft returns `ok` again with
--     `already_withdrawn` and writes nothing.
--
-- CGR-29: when the last open hold of a visit is lifted and the visit's latest final report version has no J5-v3
--   `report` fact (a correction became final during the hold, so `build_billable_fact` returned null), the fact is
--   built from that version (the same function) instead of restoring the fact in force before the hold.
--
-- J5-C1: a payer correction in intake (insurance type, insurer) re-derives the visit's latest J5-v3 fact from the
--   SAME signed snapshot: a new fact (cause `basis_changed`, `created_by` = who changed the case) supersedes it; no
--   report version is created. Only the payer reasons (`payer_not_modelled`, `no_insurer`) and the payer fields of
--   `payer_chain` are recomputed; every other value is copied. **Order changes are not re-derived** (strict default
--   until D-22, `legal`): the order reasons of the previous fact stay, so a later order end date never makes an
--   earlier visit billable through this path. Under an open hold nothing is re-derived; the last lift re-derives.
--   `generate_billable_facts` re-derives too (catch-up for a change made without a signed-in user).
--
-- No clinical, tariff or legal rule is invented. RLS, column grants and audit stay as they are.

-- 1. Report versions: a terminal `withdrawn` status ------------------------------------------------------------------
alter table public.visit_reports
  add column if not exists withdrawn_by uuid,
  add column if not exists withdrawn_at timestamptz;

alter table public.visit_reports drop constraint if exists visit_reports_status_check;
alter table public.visit_reports add constraint visit_reports_status_check
  check (status in ('draft', 'signed', 'final', 'withdrawn'));
alter table public.visit_reports drop constraint if exists visit_reports_check1;
alter table public.visit_reports add constraint visit_reports_check1
  check (status in ('draft', 'withdrawn') or (signed_by is not null and signed_at is not null));
alter table public.visit_reports drop constraint if exists visit_reports_withdrawn_check;
alter table public.visit_reports add constraint visit_reports_withdrawn_check
  check ((status = 'withdrawn') = (withdrawn_by is not null and withdrawn_at is not null)
         and (status <> 'withdrawn' or (supersedes_id is not null and signed_by is null)));

-- One live successor per version; a withdrawn version does not count, so the corrected version can be corrected again.
drop index if exists public.visit_reports_one_successor;
create unique index if not exists visit_reports_one_successor
  on public.visit_reports (supersedes_id) where supersedes_id is not null and status <> 'withdrawn';

comment on column public.visit_reports.withdrawn_by is
  'CSR1 / CGR-24-W: the performer who withdrew this untouched correction draft. A withdrawn version never took effect.';

-- Guard: a withdrawn version is immutable; a draft becomes withdrawn only with who and when, nothing else changes.
create or replace function private.guard_visit_report()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'visit reports are never deleted' using errcode = '42501';
  end if;
  if old.status = 'final' then
    raise exception 'a final report is immutable; correct it with a new version' using errcode = '42501';
  end if;
  if old.status = 'withdrawn' then
    raise exception 'a withdrawn report version is immutable' using errcode = '42501';
  end if;
  if old.status = 'signed' and not (
       new.status = 'final' and new.countersigned_by is not null
       and (new.snapshot, new.summary, new.signed_by, new.signed_at, new.version, new.visit_id)
           is not distinct from (old.snapshot, old.summary, old.signed_by, old.signed_at, old.version, old.visit_id)) then
    raise exception 'a signed report is immutable' using errcode = '42501';
  end if;
  if new.status = 'withdrawn' and not (
       old.status = 'draft'
       and (new.snapshot, new.summary, new.version, new.visit_id, new.supersedes_id, new.performer_id)
           is not distinct from (old.snapshot, old.summary, old.version, old.visit_id, old.supersedes_id, old.performer_id)) then
    raise exception 'only an unchanged draft is withdrawn' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists audit_visit_reports on public.visit_reports;
create trigger audit_visit_reports
  after insert or update on public.visit_reports
  for each row execute function private.write_audit_event('status', 'version', 'signed_by', 'countersigned_by',
                                                          'countersign_required', 'withdrawn_by');

-- 2. "Latest version" ignores a withdrawn successor -------------------------------------------------------------------
create or replace function private.visit_facts_locked(p_visit_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.visit_reports r
    where r.visit_id = p_visit_id
      and r.status in ('signed', 'final')
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
  );
$$;
revoke all on function private.visit_facts_locked(uuid) from public, anon, authenticated;

create function private.csr1j_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'CSR1 part 9 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

-- /field: the latest version per visit is never a withdrawn one.
select private.csr1j_patch('public.field_reports(date)', array[
  E'and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)\n',
  E'and r.status <> ''withdrawn''\n      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> ''withdrawn'')\n'
]);

-- CGR-24 signal: only an open correction (draft or signed awaiting countersignature); a withdrawn one has ended.
select private.csr1j_patch('private.derived_exceptions(uuid)', array[
  E'c.supersedes_id is not null and c.status <> ''final''\n',
  E'c.supersedes_id is not null and c.status in (''draft'', ''signed'')\n'
]);

drop function private.csr1j_patch(text, text[]);
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- correct_report (0044) with: latest = no live successor; the next free version number.
create or replace function public.correct_report(p_report_id uuid, p_reason text, p_summary text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.visit_reports%rowtype;
  why text := private.check_text(p_reason, 3, 300, 'reason');
  rid uuid;
  nxt integer;
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
  -- CGR-24-W: a withdrawn correction is not a successor.
  if exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn') then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_latest');
  end if;
  -- CSR1 / CGR-19 (interim, D-30): only the performer signs a correction (sign_report), so a correction of a report
  -- whose performer is no longer in the team could never become final. Refuse it; the final version stays in force.
  if not private.user_in_team(r.team_id, r.performer_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'performer_not_in_team');
  end if;
  -- CGR-24-W: a withdrawn version keeps its number; the next correction takes the next free one.
  select max(x.version) + 1 into nxt from public.visit_reports x where x.visit_id = r.visit_id;
  insert into public.visit_reports
    (organization_id, visit_id, case_id, team_id, version, supersedes_id, correction_reason, status, snapshot,
     summary, performer_id, countersign_required, created_by)
  values
    (r.organization_id, r.visit_id, r.case_id, r.team_id, nxt, r.id, why, 'draft',
     private.visit_report_snapshot(r.visit_id), coalesce(nullif(btrim(p_summary), ''), r.summary),
     r.performer_id, r.countersign_required, uid)
  returning id into rid;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', rid);
end;
$$;
revoke all on function public.correct_report(uuid, text, text, uuid) from public, anon;
grant execute on function public.correct_report(uuid, text, text, uuid) to authenticated;

-- 3. CGR-24-W: the command -------------------------------------------------------------------------------------------
-- Return: {result: ok, report_id[, already_withdrawn]} | {result: duplicate}
--       | {result: rejected, reason: not_team_member | not_performer | not_correction | awaiting_countersignature
--                                    | not_draft | draft_has_changes}
create function public.withdraw_report_correction(p_report_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  r    public.visit_reports%rowtype;
  prev public.visit_reports%rowtype;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if private.begin_command('withdraw_report_correction', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  -- Serialise with correct_visit_time / record_observation / sign_report, which lock the visit's report rows.
  perform 1 from public.visit_reports x
  where x.visit_id = (select y.visit_id from public.visit_reports y where y.id = p_report_id) for update;
  select * into r from public.visit_reports where id = p_report_id;
  if not found or not private.is_org_member(r.organization_id) or not private.is_team_member(r.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if r.performer_id <> uid then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_performer');
  end if;
  if r.supersedes_id is null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_correction');
  end if;
  if r.status = 'withdrawn' then
    perform private.end_command('ok');
    return jsonb_build_object('result', 'ok', 'report_id', r.id, 'already_withdrawn', true);
  end if;
  if r.status = 'signed' then
    -- D-10: whether a countersigner may return a signed report is not decided.
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'awaiting_countersignature');
  end if;
  if r.status <> 'draft' then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_draft');
  end if;
  select * into prev from public.visit_reports where id = r.supersedes_id;
  if exists (select 1 from public.visit_time_corrections c where c.visit_id = r.visit_id and c.created_at >= r.created_at)
     or exists (select 1 from public.visit_observations o where o.visit_id = r.visit_id and o.recorded_at >= r.created_at)
     or r.summary is distinct from prev.summary then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'draft_has_changes');
  end if;
  update public.visit_reports set status = 'withdrawn', withdrawn_by = uid, withdrawn_at = now() where id = r.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', r.id);
end;
$$;
revoke all on function public.withdraw_report_correction(uuid, uuid) from public, anon;
grant execute on function public.withdraw_report_correction(uuid, uuid) to authenticated;
comment on function public.withdraw_report_correction(uuid, uuid) is
  'CSR1 / CGR-24-W: the performer withdraws her own correction draft while untouched (no time correction, observation '
  'or summary change since it was opened). Kept as status withdrawn; the corrected final version stays in force.';

-- 4. Facts: cause `basis_changed` (J5-C1) ------------------------------------------------------------------------------
alter table public.billable_facts drop constraint if exists billable_facts_cause_check;
alter table public.billable_facts add constraint billable_facts_cause_check
  check (cause in ('report', 'quality_hold', 'hold_lifted', 'basis_changed')
         and ((cause in ('quality_hold', 'hold_lifted')) = (hold_id is not null)));
comment on column public.billable_facts.cause is
  'report: built from a final report version. quality_hold: the previous fact made not billable by a hold (BL-8). '
  'hold_lifted: the fact before the hold, appended again when the last hold was lifted. basis_changed (J5-C1): the '
  'previous fact re-derived from the same signed snapshot after intake corrected the payer (insurance type, insurer).';

-- J5-C1: re-derive the visit's latest J5-v3 fact when the case's payer differs from the one the fact used.
create function private.rederive_fact_payer(p_visit_id uuid, p_actor uuid)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  f       public.billable_facts%rowtype;
  c       public.cases%rowtype;
  reasons text[];
  fid     uuid;
begin
  if p_actor is null then return null; end if;
  perform 1 from public.care_visits where id = p_visit_id for update;   -- serialise with build and holds
  if private.visit_has_open_hold(p_visit_id) then return null; end if;   -- the last lift re-derives
  select * into f from public.billable_facts x
  where x.visit_id = p_visit_id and not exists (select 1 from public.billable_facts s where s.supersedes_id = x.id)
  order by x.created_at desc, x.id limit 1;
  if not found or f.rule_version <> 'J5-v3' then return null; end if;
  select * into c from public.cases where id = f.case_id;
  if not found
     or ((f.payer_chain ->> 'insurer'), (f.payer_chain ->> 'insurance_type'))
        is not distinct from (c.insurer_name, c.insurance_type) then
    return null;
  end if;
  -- Only the payer reasons are recomputed (same tests as build_billable_fact); order reasons stay (D-22).
  reasons := array(select x from unnest(f.reasons) as x where x not in ('payer_not_modelled', 'no_insurer'));
  if c.insurance_type is distinct from 'KVG' then reasons := array_append(reasons, 'payer_not_modelled'); end if;
  if c.insurer_name is null then reasons := array_append(reasons, 'no_insurer'); end if;
  insert into public.billable_facts
    (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
     planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
     measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
     billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash)
  values
    (f.organization_id, f.visit_id, f.case_id, f.team_id, f.report_id, f.id, f.visit_date,
     f.planned_minutes_a, f.planned_minutes_b, f.planned_minutes_c, f.actual_care_minutes,
     f.measured_care_minutes, f.billable_minutes_a, f.billable_minutes_b, f.billable_minutes_c, f.rule_version,
     cardinality(reasons) = 0, reasons, f.warnings, f.order_basis,
     f.payer_chain || jsonb_build_object('insurer', c.insurer_name, 'insurance_type', c.insurance_type),
     f.tariff_versions, p_actor, 'basis_changed', null, f.snapshot_hash)
  returning id into fid;
  return fid;
end;
$$;
revoke all on function private.rederive_fact_payer(uuid, uuid) from public, anon, authenticated;
comment on function private.rederive_fact_payer(uuid, uuid) is
  'J5-C1: a payer correction re-derives the latest J5-v3 fact from the same signed snapshot (cause basis_changed). '
  'Order fields are never re-derived here (strict default until D-22).';

create function private.billable_fact_follow_payer()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  vid uuid;
begin
  for vid in select distinct f.visit_id from public.billable_facts f where f.case_id = new.id order by 1 loop
    perform private.rederive_fact_payer(vid, (select auth.uid()));
  end loop;
  return null;
end;
$$;
revoke all on function private.billable_fact_follow_payer() from public, anon, authenticated;

drop trigger if exists billable_facts_follow_payer on public.cases;
create trigger billable_facts_follow_payer
  after update of insurance_type, insurer_name on public.cases
  for each row
  when ((old.insurance_type, old.insurer_name) is distinct from (new.insurance_type, new.insurer_name))
  execute function private.billable_fact_follow_payer();

-- 5. CGR-29 + J5-C1 on the hold trigger (0043) ------------------------------------------------------------------------
create or replace function private.billable_fact_follow_hold()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  f    public.billable_facts%rowtype;
  rrid uuid;
begin
  -- Serialise with build_billable_fact on the same visit.
  perform 1 from public.care_visits where id = new.visit_id for update;
  select * into f from public.billable_facts x
  where x.visit_id = new.visit_id and not exists (select 1 from public.billable_facts s where s.supersedes_id = x.id)
  order by x.created_at desc, x.id limit 1;
  if not found then return null; end if;

  if tg_op = 'INSERT' and new.lifted_at is null then
    if f.billable then
      insert into public.billable_facts
        (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
         planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
         measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
         billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash)
      values
        (f.organization_id, f.visit_id, f.case_id, f.team_id, f.report_id, f.id, f.visit_date,
         f.planned_minutes_a, f.planned_minutes_b, f.planned_minutes_c, f.actual_care_minutes,
         f.measured_care_minutes, f.billable_minutes_a, f.billable_minutes_b, f.billable_minutes_c, f.rule_version,
         false, array_append(f.reasons, 'quality_hold'), f.warnings, f.order_basis, f.payer_chain, f.tariff_versions,
         new.set_by, 'quality_hold', new.id, f.snapshot_hash);
    end if;
  elsif tg_op = 'UPDATE' and old.lifted_at is null and new.lifted_at is not null
        and not private.visit_has_open_hold(new.visit_id) then
    -- CGR-29: the visit's latest final report version; if it has no J5-v3 fact (it became final during the hold),
    -- build it from that version instead of restoring the older fact. This also covers a hold over a fact that was
    -- not billable (no hold fact was appended then, but the correction still had no fact).
    select r.id into rrid from public.visit_reports r
    where r.visit_id = new.visit_id and r.status = 'final'
    order by r.version desc limit 1;
    if rrid is not null and not exists (select 1 from public.billable_facts b
                                        where b.report_id = rrid and b.rule_version = 'J5-v3' and b.cause = 'report') then
      perform private.build_billable_fact(rrid, new.lifted_by);
    else
      if f.cause = 'quality_hold' then
        -- Append the fact that was in force before the hold again (it stays immutable; this is a new row).
        insert into public.billable_facts
          (organization_id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date,
           planned_minutes_a, planned_minutes_b, planned_minutes_c, actual_care_minutes,
           measured_care_minutes, billable_minutes_a, billable_minutes_b, billable_minutes_c, rule_version,
           billable, reasons, warnings, order_basis, payer_chain, tariff_versions, created_by, cause, hold_id, snapshot_hash)
        select p.organization_id, p.visit_id, p.case_id, p.team_id, p.report_id, f.id, p.visit_date,
               p.planned_minutes_a, p.planned_minutes_b, p.planned_minutes_c, p.actual_care_minutes,
               p.measured_care_minutes, p.billable_minutes_a, p.billable_minutes_b, p.billable_minutes_c, p.rule_version,
               p.billable, p.reasons, p.warnings, p.order_basis, p.payer_chain, p.tariff_versions,
               new.lifted_by, 'hold_lifted', new.id, p.snapshot_hash
        from public.billable_facts p where p.id = f.supersedes_id;
      end if;
      -- J5-C1: a payer corrected during the hold is re-derived now.
      perform private.rederive_fact_payer(new.visit_id, new.lifted_by);
    end if;
  end if;
  return null;
end;
$$;
revoke all on function private.billable_fact_follow_hold() from public, anon, authenticated;

-- 6. Generation (0022/0043): latest = no live successor; J5-C1 catch-up --------------------------------------------------
create or replace function public.generate_billable_facts(p_month date)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  n   integer := 0;
  rid uuid;
  vid uuid;
begin
  if uid is null or p_month is null then return 0; end if;
  for rid in
    select r.id
    from public.visit_reports r
    join public.care_visits v on v.id = r.visit_id
    where r.status = 'final'
      and v.visit_date >= date_trunc('month', p_month)::date
      and v.visit_date < (date_trunc('month', p_month) + interval '1 month')::date
      and private.is_org_member(r.organization_id)
      and (private.is_team_member(r.team_id) or private.is_coordinator(r.organization_id))
      and not exists (select 1 from public.visit_reports s
                      where s.supersedes_id = r.id and s.status <> 'withdrawn')   -- latest version only
    order by r.created_at
  loop
    if private.build_billable_fact(rid, uid) is not null then n := n + 1; end if;
  end loop;
  -- J5-C1: facts whose payer was corrected without a signed-in user (or before 0049) are re-derived here.
  for vid in
    select distinct f.visit_id
    from public.billable_facts f
    where f.visit_date >= date_trunc('month', p_month)::date
      and f.visit_date < (date_trunc('month', p_month) + interval '1 month')::date
      and private.is_org_member(f.organization_id)
      and (private.is_team_member(f.team_id) or private.is_coordinator(f.organization_id))
    order by 1
  loop
    if private.rederive_fact_payer(vid, uid) is not null then n := n + 1; end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.generate_billable_facts(date) from public, anon;
grant execute on function public.generate_billable_facts(date) to authenticated;
