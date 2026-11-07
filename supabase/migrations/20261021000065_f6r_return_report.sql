-- F6R: return a report instead of countersigning a version known to be wrong (brief docs/agents/briefs/F6R.md, ADR-079).
-- Product decision: D-10 sub-question R, decided by po 2026-10-24 19:09 (docs/agents/decisions/D-10.md). Who must
-- countersign (D-10 A vs. B, `clinical`) does not change: every report of a non-RN performer still needs it (0016).
--
-- Design (ADR-079):
--   * `return_report(report, reason, key)`: a registered nurse of the report's team, not the performer, returns the
--     LATEST version while it is `signed` and awaits countersignature. Reason 10–500 characters.
--   * The returned version is never changed (signed versions stay immutable, 0016 guard). The return appends:
--       1. one row in `visit_report_returns` (append-only: report, version, snapshot hash, reason, returner, time);
--       2. a new report version, status `draft`, `supersedes_id` = the returned version, `return_id` = that row, the
--          next free version number, the same performer and `countersign_required`. Brief open question: the draft
--          opens the NEXT version number (the returned number is never reused, as for withdrawn corrections, 0049).
--     The new draft is the latest version: the visit's facts unlock (0040 `visit_facts_locked`), but only for the
--     performer (F6R-3); she corrects through the existing commands and signs again (0041 `sign_report`, which already
--     admits only her); a team RN countersigns the new version (0016); only then is the report `final`.
--   * A return version is not a correction: `correction_reason` stays null (no withdraw button, 0049), it cannot be
--     withdrawn (`returned_report`), it does not raise `report_correction_open` (0047), and AN2 measure 5 does not count
--     it as a correction round. `report_not_final` (F6, CR-053) is unchanged: no version is final, so it keeps raising
--     with the same threshold until the corrected version is countersigned.
--   * Never stranded (condition a): the performer sees every returned report of hers at the top of /field, any date
--     (`field_returned_reports`); the team's RNs see it in the countersignature queue as "zurückgegeben"
--     (`field_countersign_queue` gains `returned`). The performer-left case keeps the CR-048 interim rule (D-30): a
--     return is refused while the performer is not in the team (`performer_not_in_team`), and `remove_team_member`
--     refuses to remove a performer while a returned report of hers is not signed again (`has_unsigned_reports`).
--   * The reason is health data (condition d): readable only by the performer and the team's registered nurses (RLS,
--     and the read models null it for anyone else). No analytics, billing, export or push reads the table (pgTAP).
--   * Billing (F6R-6): unchanged rule, facts only from `final` versions (J5, 0043/0051); a returned report has none.
--   * Evidence (F6R-9): AN2 gains `report_returned_share` and `countersign_latency_hours` (AN1 suppression).
--
-- Also: `countersign_report` refuses a version that is no longer the latest (`not_latest`): the returned version stays
-- `signed` and must never become final; AN1 `pilot_kpis` takes the first final version's time (a returned version
-- was never final).
--
-- No clinical, tariff or legal rule is invented. RLS, column grants and audit as in 0016. Idempotent: applying this file
-- twice changes nothing (if-not-exists, drop-if-exists, markers in patched bodies).

-- 0. Patch helper (pattern must match the stated number of times; idempotent through a marker) -------------------------
create or replace function private.f6r_patch(p_fn text, p_triples text[], p_marker text)
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
  for i in 1 .. coalesce(array_length(p_triples, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_triples[i], ''))) / length(p_triples[i]);
    if n <> p_triples[i + 2]::integer then
      raise exception '0065 patch for % must match % time(s), matched %: %', p_fn, p_triples[i + 2], n, p_triples[i];
    end if;
    def := replace(def, p_triples[i], p_triples[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0065 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.f6r_patch(text, text[], text) from public, anon, authenticated;

-- 1. The append-only return record (F6R-2) -------------------------------------------------------------------------------
create table if not exists public.visit_report_returns (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null,
  visit_id        uuid not null,
  report_id       uuid not null references public.visit_reports (id),
  report_version  integer not null check (report_version >= 1),
  snapshot_hash   text not null check (snapshot_hash ~ '^[0-9a-f]{64}$'),
  reason          text not null check (char_length(btrim(reason)) between 10 and 500),
  performer_id    uuid not null,
  returned_by     uuid not null,
  returned_at     timestamptz not null default now(),
  unique (report_id),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id),
  foreign key (team_id, organization_id) references public.teams (id, organization_id),
  check (returned_by <> performer_id)
);
create index if not exists visit_report_returns_visit_idx on public.visit_report_returns (visit_id, returned_at);

comment on table public.visit_report_returns is
  'F6R: a registered nurse returned a signed report version to its performer. Append-only (no role updates or deletes). '
  'The reason is health data: readable only by the performer and the team''s registered nurses; never read by analytics, '
  'billing, exports or push.';
comment on column public.visit_report_returns.reason is
  'F6R-7: health data. Visible only to the performer and the team''s registered nurses. Exception (PO 2026-10-24 20:09): '
  'a client''s own access extract, when one is built, includes it (D-4 gate r1).';

alter table public.visit_report_returns enable row level security;
revoke all on public.visit_report_returns from public, anon, authenticated, service_role;
grant select on public.visit_report_returns to authenticated;
drop policy if exists performer_and_team_rn_read on public.visit_report_returns;
create policy performer_and_team_rn_read on public.visit_report_returns
  for select to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id)
         and (performer_id = (select auth.uid()) or private.is_registered_nurse(team_id, (select auth.uid()))));

create or replace function private.guard_visit_report_return()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  raise exception 'a report return is append-only: it is never changed or deleted' using errcode = '42501';
end;
$$;
revoke all on function private.guard_visit_report_return() from public, anon, authenticated;

drop trigger if exists visit_report_returns_guard on public.visit_report_returns;
create trigger visit_report_returns_guard
  before update or delete on public.visit_report_returns
  for each row execute function private.guard_visit_report_return();
drop trigger if exists visit_report_returns_no_truncate on public.visit_report_returns;
create trigger visit_report_returns_no_truncate
  before truncate on public.visit_report_returns
  for each statement execute function private.guard_visit_report_return();
-- Audit without the reason (health data stays out of audit_events.changed).
drop trigger if exists audit_visit_report_returns on public.visit_report_returns;
create trigger audit_visit_report_returns
  after insert on public.visit_report_returns
  for each row execute function private.write_audit_event('report_id', 'report_version', 'returned_by', 'snapshot_hash');

-- 2. Report versions opened by a return ----------------------------------------------------------------------------------
alter table public.visit_reports
  add column if not exists return_id uuid references public.visit_report_returns (id);
create unique index if not exists visit_reports_one_per_return on public.visit_reports (return_id) where return_id is not null;
comment on column public.visit_reports.return_id is
  'F6R: set on the version a return opened (supersedes the returned version). Not a correction: correction_reason is null.';

alter table public.visit_reports drop constraint if exists visit_reports_check;
alter table public.visit_reports add constraint visit_reports_check
  check (supersedes_id is null or correction_reason is not null or return_id is not null);
alter table public.visit_reports drop constraint if exists visit_reports_return_check;
alter table public.visit_reports add constraint visit_reports_return_check
  check (return_id is null or (supersedes_id is not null and correction_reason is null));

-- Guard (0049) plus: return_id never changes; a return version is never withdrawn.
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
  -- F6R: the link to the return that opened a version is fixed.
  if new.return_id is distinct from old.return_id then
    raise exception 'the return of a report version is fixed' using errcode = '42501';
  end if;
  if old.status = 'signed' and not (
       new.status = 'final' and new.countersigned_by is not null
       and (new.snapshot, new.summary, new.signed_by, new.signed_at, new.version, new.visit_id)
           is not distinct from (old.snapshot, old.summary, old.signed_by, old.signed_at, old.version, old.visit_id)) then
    raise exception 'a signed report is immutable' using errcode = '42501';
  end if;
  if new.status = 'withdrawn' and not (
       old.status = 'draft' and old.return_id is null
       and (new.snapshot, new.summary, new.version, new.visit_id, new.supersedes_id, new.performer_id)
           is not distinct from (old.snapshot, old.summary, old.version, old.visit_id, old.supersedes_id, old.performer_id)) then
    raise exception 'only an unchanged correction draft is withdrawn' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists audit_visit_reports on public.visit_reports;
create trigger audit_visit_reports
  after insert or update on public.visit_reports
  for each row execute function private.write_audit_event('status', 'version', 'signed_by', 'countersigned_by',
                                                          'countersign_required', 'withdrawn_by', 'return_id');

-- Helper: the performer of the visit's open returned draft (latest live version, a return version, status draft).
create or replace function private.visit_open_return_performer(p_visit_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select r.performer_id from public.visit_reports r
  where r.visit_id = p_visit_id and r.status = 'draft' and r.return_id is not null
    and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
  limit 1;
$$;
revoke all on function private.visit_open_return_performer(uuid) from public, anon, authenticated;
comment on function private.visit_open_return_performer(uuid) is
  'F6R-3: the performer while the visit''s latest report version is a returned draft; null otherwise.';

-- 3. The command (F6R-1) -------------------------------------------------------------------------------------------------
-- Return: {result: ok, report_id (the new draft), return_id} | {result: duplicate}
--       | {result: rejected, reason: not_team_member | reason_too_short | not_latest | not_awaiting_countersignature
--                                    | own_report | rn_required | performer_not_in_team}
create or replace function public.return_report(p_report_id uuid, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.visit_reports%rowtype;
  why text := btrim(p_reason);
  nxt integer;
  ret uuid;
  rid uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if why is not null and char_length(why) > 500 then
    raise exception 'reason needs 10–500 characters' using errcode = '22023';
  end if;
  if private.begin_command('return_report', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  -- Serialise with sign_report, countersign_report, correct_visit_time and record_observation (they lock these rows).
  perform 1 from public.visit_reports x
  where x.visit_id = (select y.visit_id from public.visit_reports y where y.id = p_report_id) for update;
  select * into r from public.visit_reports where id = p_report_id;
  if not found or not private.is_org_member(r.organization_id) or not private.is_team_member(r.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if why is null or char_length(why) < 10 then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'reason_too_short');
  end if;
  if exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn') then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_latest');
  end if;
  if r.status <> 'signed' or not r.countersign_required then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_awaiting_countersignature');
  end if;
  if uid = r.performer_id then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'own_report');
  end if;
  if not private.is_registered_nurse(r.team_id, uid) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'rn_required');
  end if;
  -- CR-048 interim (D-30): only the performer signs again; she must still be in the team, or the report would strand.
  if not private.user_in_team(r.team_id, r.performer_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'performer_not_in_team');
  end if;

  insert into public.visit_report_returns
    (organization_id, team_id, visit_id, report_id, report_version, snapshot_hash, reason, performer_id, returned_by)
  values
    (r.organization_id, r.team_id, r.visit_id, r.id, r.version, private.report_snapshot_hash(r.snapshot), why,
     r.performer_id, uid)
  returning id into ret;

  select max(x.version) + 1 into nxt from public.visit_reports x where x.visit_id = r.visit_id;
  insert into public.visit_reports
    (organization_id, visit_id, case_id, team_id, version, supersedes_id, correction_reason, return_id, status, snapshot,
     summary, performer_id, countersign_required, created_by)
  values
    (r.organization_id, r.visit_id, r.case_id, r.team_id, nxt, r.id, null, ret, 'draft',
     private.visit_report_snapshot(r.visit_id), r.summary, r.performer_id, r.countersign_required, uid)
  returning id into rid;

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', rid, 'return_id', ret);
end;
$$;
revoke all on function public.return_report(uuid, text, uuid) from public, anon;
grant execute on function public.return_report(uuid, text, uuid) to authenticated;
comment on function public.return_report(uuid, text, uuid) is
  'F6R-1: a registered nurse of the team (not the performer) returns the latest signed version awaiting countersignature '
  'to its performer with a reason (10–500). Appends a return row and a new draft version; the returned version is unchanged.';

-- 4. Countersignature only on the latest version -----------------------------------------------------------------------
select private.f6r_patch('public.countersign_report(uuid, uuid)', array[
  E'  if r.status <> ''signed'' or not r.countersign_required then\n',
  E'  -- F6R: a returned version stays signed but is no longer the latest; it never becomes final.\n' ||
  E'  if exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> ''withdrawn'') then\n' ||
  E'    perform private.end_command(''rejected'');\n' ||
  E'    return jsonb_build_object(''result'', ''rejected'', ''reason'', ''not_latest'');\n' ||
  E'  end if;\n' ||
  E'  if r.status <> ''signed'' or not r.countersign_required then\n',
  '1'
], 'F6R: a returned version');

-- 5. F6R-3: after a return only the performer changes the facts ----------------------------------------------------------
select private.f6r_patch('public.correct_visit_time(bigint, timestamp with time zone, text, uuid)', array[
  E'  if private.visit_facts_locked(ev.visit_id) then\n    return ''rejected'';\n  end if;\n',
  E'  if private.visit_facts_locked(ev.visit_id) then\n    return ''rejected'';\n  end if;\n' ||
  E'  -- F6R-3: a returned report is corrected by its performer only.\n' ||
  E'  if private.visit_open_return_performer(ev.visit_id) is distinct from null\n' ||
  E'     and private.visit_open_return_performer(ev.visit_id) <> uid then\n' ||
  E'    return ''rejected'';\n  end if;\n',
  '1'
], 'F6R-3: a returned report');

select private.f6r_patch('public.record_observation(uuid, text, boolean, uuid, uuid)', array[
  E'  if private.visit_facts_locked(v.id) then\n    return ''rejected'';\n  end if;\n',
  E'  if private.visit_facts_locked(v.id) then\n    return ''rejected'';\n  end if;\n' ||
  E'  -- F6R-3: a returned report is corrected by its performer only.\n' ||
  E'  if private.visit_open_return_performer(v.id) is distinct from null\n' ||
  E'     and private.visit_open_return_performer(v.id) <> uid then\n' ||
  E'    return ''rejected'';\n  end if;\n',
  '1'
], 'F6R-3: a returned report');

-- 6. A return version is not a withdrawable correction -------------------------------------------------------------------
select private.f6r_patch('public.withdraw_report_correction(uuid, uuid)', array[
  E'  if r.supersedes_id is null then\n',
  E'  -- F6R: a returned report goes back to its countersigner only through a new signature.\n' ||
  E'  if r.return_id is not null then\n' ||
  E'    perform private.end_command(''rejected'');\n' ||
  E'    return jsonb_build_object(''result'', ''rejected'', ''reason'', ''returned_report'');\n' ||
  E'  end if;\n' ||
  E'  if r.supersedes_id is null then\n',
  '1'
], 'F6R: a returned report goes back');

-- 7. Signals: a return version is not an open correction (report_not_final covers it, unchanged) -------------------------
select private.f6r_patch('private.derived_exceptions(uuid)', array[
  E'c.supersedes_id is not null and c.status in (''draft'', ''signed'')\n',
  E'c.supersedes_id is not null and c.status in (''draft'', ''signed'')\n' ||
  E'    and c.return_id is null  -- F6R: a return version is no correction; report_not_final still raises\n',
  '1'
], 'F6R: a return version is no correction');
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- 8. Removing a performer: a returned report counts as unsigned until she signs again (CR-048 interim, D-30) ------------
select private.f6r_patch('public.remove_team_member(uuid, uuid, text, uuid)', array[
  E'               and not exists (select 1 from public.visit_reports r\n' ||
  E'                               where r.visit_id = v.id and r.status in (''signed'', ''final''))) then\n',
  E'               and not exists (select 1 from public.visit_reports r\n' ||
  E'                               where r.visit_id = v.id and r.status in (''signed'', ''final'')\n' ||
  E'                                 -- F6R: a returned version no longer counts as signed\n' ||
  E'                                 and not exists (select 1 from public.visit_reports s\n' ||
  E'                                                 where s.supersedes_id = r.id and s.return_id is not null))) then\n',
  '1'
], 'F6R: a returned version no longer counts');

-- 9. AN1: the time a visit's report first became final (a returned version never was) -----------------------------------
select private.f6r_patch('public.pilot_kpis(date)', array[
  E'           (select case when r.status = ''final'' or exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)\n' ||
  E'                        then coalesce(r.countersigned_at, r.signed_at) end\n' ||
  E'            from public.visit_reports r where r.visit_id = v.id and r.supersedes_id is null) as final_at\n',
  E'           -- F6R: the first final version (a returned version was never final; without returns: unchanged)\n' ||
  E'           (select min(coalesce(r.countersigned_at, r.signed_at))\n' ||
  E'            from public.visit_reports r where r.visit_id = v.id and r.status = ''final'') as final_at\n',
  '1'
], 'F6R: the first final version');

-- 10. AN2: return versions are no correction rounds; F6R-9 evidence -------------------------------------------------------
select private.f6r_patch('public.pilot_hypotheses(date)', array[
  -- measure 5: corrections only
  E'(select count(*) from public.visit_reports c where c.visit_id = r.visit_id and c.supersedes_id is not null) as corrections\n',
  E'(select count(*) from public.visit_reports c where c.visit_id = r.visit_id and c.supersedes_id is not null\n' ||
  E'              and c.return_id is null) as corrections  -- F6R: a return version is no correction round\n',
  '1',
  E'    join public.visit_reports s on s.id = c.supersedes_id\n    join visits v on v.id = c.visit_id\n',
  E'    join public.visit_reports s on s.id = c.supersedes_id\n    join visits v on v.id = c.visit_id\n' ||
  E'    where c.return_id is null\n',
  '1',
  -- F6R-9: share returned at least once; countersignature latency with returns included (first signature to the
  -- countersignature that made the report final). Reads only versions, never the return reason.
  E'  ),\n  computed as (\n',
  E'  ), cs_reports as (\n' ||
  E'    select v.organization_id, v.team_id,\n' ||
  E'           exists (select 1 from public.visit_reports x where x.visit_id = r.visit_id and x.return_id is not null) as returned,\n' ||
  E'           (select min(x.countersigned_at) from public.visit_reports x\n' ||
  E'            where x.visit_id = r.visit_id and x.status = ''final'' and x.countersigned_at is not null) - r.signed_at as latency\n' ||
  E'    from public.visit_reports r join visits v on v.id = r.visit_id\n' ||
  E'    where r.supersedes_id is null and r.countersign_required and r.signed_at is not null\n' ||
  E'  ), m13 as (\n' ||
  E'    select x.organization_id, x.team_id, ''report_returned_share''::text as measure, null::text as detail,\n' ||
  E'           round(100.0 * count(*) filter (where x.returned) / count(*), 1) as value, count(*)::int as base\n' ||
  E'    from cs_reports x group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n' ||
  E'    union all\n' ||
  E'    select x.organization_id, x.team_id, ''countersign_latency_hours'', null,\n' ||
  E'           round((percentile_cont(0.5) within group (order by extract(epoch from x.latency) / 3600))::numeric, 1),\n' ||
  E'           count(*)::int\n' ||
  E'    from cs_reports x where x.latency is not null\n' ||
  E'    group by grouping sets ((x.organization_id, x.team_id), (x.organization_id))\n' ||
  E'  ),\n  computed as (\n',
  '1',
  E'    union all select * from m10p\n',
  E'    union all select * from m10p\n    union all select * from m13\n',
  '1',
  E'           (''signal_outside_sent_share'', null), (''signal_taken_within_threshold_share'', null)\n',
  E'           (''signal_outside_sent_share'', null), (''signal_taken_within_threshold_share'', null),\n' ||
  E'           -- F6R-9\n' ||
  E'           (''report_returned_share'', null), (''countersign_latency_hours'', null)\n',
  '1',
  E'              when r.measure = ''followup_without_visit_share''\n',
  E'              when r.measure in (''report_returned_share'', ''countersign_latency_hours'')\n' ||
  E'                then ''Evidenz für D-10 (Gegenzeichnung A oder B): Berichte mit Gegenzeichnungspflicht; Latenz von der ersten Unterschrift bis zur Gegenzeichnung, Rückgaben eingeschlossen.''\n' ||
  E'              when r.measure = ''followup_without_visit_share''\n',
  '1'
], 'F6R-9');

-- 11. Read models -------------------------------------------------------------------------------------------------------
-- /field (0041, 0049) plus the return: `returned` for everyone in the team; reason, time, returner and the returned
-- version's snapshot only for the performer and the team's registered nurses (F6R-7).
drop function if exists public.field_reports(date);
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
  snapshot_hash         text,
  returned              boolean,
  return_reason         text,
  returned_at           timestamptz,
  returned_by_name      text,
  returned_snapshot     jsonb,
  i_can_return          boolean
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
         private.report_snapshot_hash(x.shown),
         x.return_id is not null,
         case when x.may_see_return then rt.reason end,
         case when x.may_see_return then rt.returned_at end,
         case when x.may_see_return then private.member_name(x.organization_id, rt.returned_by) end,
         case when x.may_see_return then rv.snapshot end,
         x.status = 'signed' and x.countersign_required and x.performer_id <> (select auth.uid())
           and private.is_registered_nurse(x.team_id, (select auth.uid()))
           and private.user_in_team(x.team_id, x.performer_id)
  from (
    select r.*,
           case when r.status = 'draft' then private.visit_report_snapshot(r.visit_id) else r.snapshot end as shown,
           r.performer_id = (select auth.uid()) or private.is_registered_nurse(r.team_id, (select auth.uid())) as may_see_return
    from public.visit_reports r
    join public.care_visits v on v.id = r.visit_id
    where p_date is not null and v.visit_date = p_date
      and private.is_org_member(r.organization_id) and private.is_team_member(r.team_id)
      and r.status <> 'withdrawn'
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
  ) x
  left join public.visit_report_returns rt on rt.id = x.return_id
  left join public.visit_reports rv on rv.id = rt.report_id
  order by x.visit_id;
$$;
revoke all on function public.field_reports(date) from public, anon;
grant execute on function public.field_reports(date) to authenticated;

-- The RN's queue (0026) plus returned reports awaiting their performer ("zurückgegeben", F6R-5).
drop function if exists public.field_countersign_queue();
create function public.field_countersign_queue()
returns table (
  report_id      uuid,
  visit_id       uuid,
  visit_date     date,
  time_start     time,
  client_name    text,
  team_name      text,
  signed_at      timestamptz,
  returned       boolean,
  returned_at    timestamptz,
  performer_name text
)
language sql stable security definer set search_path = ''
as $$
  select r.id, r.visit_id, v.visit_date, v.time_start,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), t.name, r.signed_at,
         r.status = 'draft', rt.returned_at, private.member_name(r.organization_id, r.performer_id)
  from public.visit_reports r
  join public.care_visits v on v.id = r.visit_id
  join public.teams t on t.id = r.team_id
  left join public.cases c on c.id = v.case_id
  left join public.visit_report_returns rt on rt.id = r.return_id
  where r.countersign_required
    and (r.status = 'signed' or (r.status = 'draft' and r.return_id is not null))
    and r.performer_id <> (select auth.uid())
    and private.is_org_member(r.organization_id) and private.is_team_member(r.team_id)
    and private.is_registered_nurse(r.team_id, (select auth.uid()))
    and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
  order by coalesce(r.signed_at, rt.returned_at);
$$;
revoke all on function public.field_countersign_queue() from public, anon;
grant execute on function public.field_countersign_queue() to authenticated;
comment on function public.field_countersign_queue() is
  'F7 + F6R-5: latest versions of the caller''s teams awaiting her countersignature (returned = false) or returned to '
  'their performer and not yet signed again (returned = true). Registered nurses of the team only; never the reason.';

-- The performer's returned reports, any date, until she signs again (F6R-5: never stranded).
create or replace function public.field_returned_reports()
returns table (
  report_id        uuid,
  visit_id         uuid,
  visit_date       date,
  time_start       time,
  client_name      text,
  team_name        text,
  reason           text,
  returned_at      timestamptz,
  returned_by_name text
)
language sql stable security definer set search_path = ''
as $$
  select r.id, r.visit_id, v.visit_date, v.time_start,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), t.name,
         rt.reason, rt.returned_at, private.member_name(r.organization_id, rt.returned_by)
  from public.visit_reports r
  join public.visit_report_returns rt on rt.id = r.return_id
  join public.care_visits v on v.id = r.visit_id
  join public.teams t on t.id = r.team_id
  left join public.cases c on c.id = v.case_id
  where r.status = 'draft' and r.performer_id = (select auth.uid())
    and private.is_org_member(r.organization_id) and private.is_team_member(r.team_id)
    and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
  order by rt.returned_at;
$$;
revoke all on function public.field_returned_reports() from public, anon;
grant execute on function public.field_returned_reports() to authenticated;

-- Every return of a visit's report, with the returned version (F6R-2: readable to the performer and the team's RNs).
create or replace function public.report_returns(p_visit_id uuid)
returns table (
  return_id        uuid,
  report_id        uuid,
  report_version   integer,
  snapshot_hash    text,
  snapshot         jsonb,
  summary          text,
  reason           text,
  returned_at      timestamptz,
  returned_by_name text
)
language sql stable security definer set search_path = ''
as $$
  select rt.id, rt.report_id, rt.report_version, rt.snapshot_hash, rv.snapshot, rv.summary, rt.reason, rt.returned_at,
         private.member_name(rt.organization_id, rt.returned_by)
  from public.visit_report_returns rt
  join public.visit_reports rv on rv.id = rt.report_id
  where rt.visit_id = p_visit_id
    and private.is_org_member(rt.organization_id) and private.is_team_member(rt.team_id)
    and (rt.performer_id = (select auth.uid()) or private.is_registered_nurse(rt.team_id, (select auth.uid())))
  order by rt.returned_at;
$$;
revoke all on function public.report_returns(uuid) from public, anon;
grant execute on function public.report_returns(uuid) to authenticated;

drop function private.f6r_patch(text, text[], text);
