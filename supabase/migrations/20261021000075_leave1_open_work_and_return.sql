-- LEAVE1 part (b): the leaver's open work stays visible, and a wrong report of a performer who is no longer available
-- never becomes final (brief docs/agents/briefs/LEAVE1.md: LEAVE1-5, LEAVE1-11, LEAVE1-12; LEAVE1-6 is the app screen;
-- ADR-088). Part (a) is migration 0074 (ADR-087).
--
-- Design (ADR-088):
--   * LEAVE1-11 (CGR-49): `return_report` no longer refuses with `performer_not_in_team`. When the performer's access
--     ended (0074) or she is no longer in the report's team, the return is recorded as in F6R (append-only row, reason
--     readable by the team's RNs and the performer only) with `performer_unavailable = true`, and **no draft version is
--     opened**: the returned version stays `signed` (immutable, 0016), is never countersigned (`countersign_report`
--     refuses `returned_performer_unavailable`; the report guard refuses signed → final for it as defence in depth), so
--     it is never final and never billable; `report_not_final` keeps raising (no version is final). Who completes it is
--     D-30 (`clinical`); nothing here decides that. A version is returned at most once (0065 `unique (report_id)`).
--     After a restore (LEAVE1-7) a later return of another version opens the normal F6R draft again; a version returned
--     while she was unavailable stays as it is (no automatic draft: that would decide D-30's route).
--   * `correct_report` refuses a correction of a final report whose performer's access ended (`performer_unavailable`),
--     for the same reason 0044 refuses it while she is not in the team: only she signs a correction (CR-048 interim).
--   * LEAVE1-12 (CGR-50): `private.open_reports_of(user)` lists her open reports by kind (`unsigned`: a completed visit
--     she performed without a signed version; `correction_draft`; `returned`: a returned draft, or a version returned
--     while she was unavailable). `member_open_reports(user)` shows kind, visit date and team (no content, no reason) to
--     the organisation's administrators and to the registered nurses of the report's team; `end_member_access` returns
--     the same counts by kind (it is not refused by them, LEAVE1-2).
--   * LEAVE1-5 / LEAVE1-12 (3): the team RNs' countersignature queue gains the leaver's open reports with the marker
--     "Zugang beendet" (date only, no reason code) and a `kind`; HAND1 (`field_since_last`) shows every team member who
--     reads that client's visit an entry `performer_access_ended` for each open report of a performer whose access
--     ended (kind and date; never the return reason, never the access reason code). The entry is a state, not an
--     event: it shows on every visit of the client until the report is closed (deviation, ADR-088).
--   * `/field` (`field_reports`) gains `performer_unavailable` and `performer_access_ended`; `i_can_return` agrees with
--     `return_report` and `i_can_countersign` with `countersign_report` in every case.
--
-- No clinical, tariff or legal rule is invented: D-30 and CR-048 apply as before. RLS, column grants and audit as in
-- 0065/0074; every read model keeps the LEAVE1-3 guard. Idempotent: create or replace, if-not-exists, drop-if-exists.

-- 0. Helpers ------------------------------------------------------------------------------------------------------------
-- The time her current access end took effect (null while her access is open). Reads only the time, never the code.
create or replace function private.access_ended_at(p_user uuid)
returns timestamptz
language sql stable security definer set search_path = ''
as $$
  select max(e.created_at) from public.member_access_events e
  where e.user_id = p_user and e.kind = 'ended' and private.access_ended(p_user)
$$;
revoke all on function private.access_ended_at(uuid) from public, anon, authenticated;
comment on function private.access_ended_at(uuid) is
  'LEAVE1-5: when the person''s current access end took effect; null while her access is open. Never the reason code.';

-- 1. The return record: whether the performer was unavailable (LEAVE1-11) ------------------------------------------------
alter table public.visit_report_returns
  add column if not exists performer_unavailable boolean not null default false;
comment on column public.visit_report_returns.performer_unavailable is
  'LEAVE1-11: the performer''s access had ended or she was no longer in the team. No draft was opened; the returned '
  'version stays signed, is never countersigned and waits on D-30''s route.';

drop trigger if exists audit_visit_report_returns on public.visit_report_returns;
create trigger audit_visit_report_returns
  after insert on public.visit_report_returns
  for each row execute function private.write_audit_event('report_id', 'report_version', 'returned_by', 'snapshot_hash',
                                                          'performer_unavailable');

-- True while this version was returned with its performer unavailable (it then has no successor).
create or replace function private.report_returned_unavailable(p_report_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.visit_report_returns rt
                 where rt.report_id = p_report_id and rt.performer_unavailable)
$$;
revoke all on function private.report_returned_unavailable(uuid) from public, anon, authenticated;
comment on function private.report_returned_unavailable(uuid) is
  'LEAVE1-11: the version was returned while its performer was unavailable. Reads no reason.';

-- 2. The report guard: such a version never becomes final (defence in depth; countersign_report refuses first) ----------
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
  -- LEAVE1-11: a version returned while its performer was unavailable is known to be wrong; it never becomes final.
  if old.status = 'signed' and new.status = 'final' and private.report_returned_unavailable(old.id) then
    raise exception 'a returned report version never becomes final' using errcode = '42501';
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

-- 3. return_report (0065) with LEAVE1-11 --------------------------------------------------------------------------------
-- Return: {result: ok, report_id (the new draft, null when none), return_id, performer_unavailable} | {result: duplicate}
--       | {result: rejected, reason: not_team_member | reason_too_short | not_latest | not_awaiting_countersignature
--                                    | own_report | rn_required}
create or replace function public.return_report(p_report_id uuid, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  r     public.visit_reports%rowtype;
  why   text := btrim(p_reason);
  nxt   integer;
  ret   uuid;
  rid   uuid;
  unavl boolean;
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
  -- LEAVE1-11: a version already returned (while its performer was unavailable) no longer awaits countersignature.
  if r.status <> 'signed' or not r.countersign_required or private.report_returned_unavailable(r.id) then
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
  -- LEAVE1-11 (replaces the CR-048 refusal `performer_not_in_team` of 0065): the return is recorded either way; a draft
  -- that only the performer could sign is opened only while she is in the team and her access is open.
  unavl := private.access_ended(r.performer_id) or not private.user_in_team(r.team_id, r.performer_id);

  insert into public.visit_report_returns
    (organization_id, team_id, visit_id, report_id, report_version, snapshot_hash, reason, performer_id, returned_by,
     performer_unavailable)
  values
    (r.organization_id, r.team_id, r.visit_id, r.id, r.version, private.report_snapshot_hash(r.snapshot), why,
     r.performer_id, uid, unavl)
  returning id into ret;

  if not unavl then
    select max(x.version) + 1 into nxt from public.visit_reports x where x.visit_id = r.visit_id;
    insert into public.visit_reports
      (organization_id, visit_id, case_id, team_id, version, supersedes_id, correction_reason, return_id, status, snapshot,
       summary, performer_id, countersign_required, created_by)
    values
      (r.organization_id, r.visit_id, r.case_id, r.team_id, nxt, r.id, null, ret, 'draft',
       private.visit_report_snapshot(r.visit_id), r.summary, r.performer_id, r.countersign_required, uid)
    returning id into rid;
  end if;

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', rid, 'return_id', ret, 'performer_unavailable', unavl);
end;
$$;
revoke all on function public.return_report(uuid, text, uuid) from public, anon;
grant execute on function public.return_report(uuid, text, uuid) to authenticated;
comment on function public.return_report(uuid, text, uuid) is
  'F6R-1 + LEAVE1-11: a registered nurse of the team (not the performer) returns the latest signed version awaiting '
  'countersignature with a reason (10–500). Appends a return row; opens a draft for the performer only while she is in '
  'the team with open access (otherwise performer_unavailable, no draft, the version never becomes final).';

-- 4. countersign_report: never a version returned while its performer was unavailable ----------------------------------
create or replace function public.countersign_report(p_report_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.visit_reports%rowtype;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if private.begin_command('countersign_report', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into r from public.visit_reports where id = p_report_id for update;
  if not found or not private.is_org_member(r.organization_id) or not private.is_team_member(r.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  -- F6R: a returned version stays signed but is no longer the latest; it never becomes final.
  if exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn') then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_latest');
  end if;
  -- LEAVE1-11: returned while its performer was unavailable: known to be wrong, waits on D-30's route.
  if private.report_returned_unavailable(r.id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'returned_performer_unavailable');
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
  update public.visit_reports set status = 'final', countersigned_by = uid, countersigned_at = private.now() where id = r.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', r.id);
end;
$$;
revoke all on function public.countersign_report(uuid, uuid) from public, anon;
grant execute on function public.countersign_report(uuid, uuid) to authenticated;

-- 5. correct_report: not while the performer's access ended (she alone signs a correction; CR-048 interim) -------------
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
  -- LEAVE1 (same reason): her access ended, so she cannot sign it either.
  if private.access_ended(r.performer_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'performer_unavailable');
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

-- 6. LEAVE1-12: a person's open reports by kind ---------------------------------------------------------------------------
--   unsigned          a completed visit she performed without a signed or final version (a first draft, or none at all)
--   correction_draft  the latest version is her correction draft
--   returned          the latest version is a draft a return opened for her, or a version returned while she was
--                     unavailable (LEAVE1-11)
create or replace function private.open_reports_of(p_user uuid)
returns table (organization_id uuid, team_id uuid, visit_id uuid, report_id uuid, kind text)
language sql stable security definer set search_path = ''
as $$
  with latest as (
    select r.* from public.visit_reports r
    where r.performer_id = p_user and r.status in ('draft', 'signed')
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
  )
  select l.organization_id, l.team_id, l.visit_id, l.id,
         case when l.return_id is not null or l.status = 'signed' then 'returned'
              when l.correction_reason is not null then 'correction_draft'
              else 'unsigned' end
  from latest l
  where l.status = 'draft' or private.report_returned_unavailable(l.id)
  union all
  select v.organization_id, v.team_id, v.id, null::uuid, 'unsigned'
  from public.care_visits v
  where v.status = 'completed'
    and exists (select 1 from public.visit_events e where e.visit_id = v.id and e.event_type = 'started' and e.actor_id = p_user)
    and private.visit_performer(v.id) = p_user
    and not exists (select 1 from public.visit_reports r where r.visit_id = v.id and r.status <> 'withdrawn')
$$;
revoke all on function private.open_reports_of(uuid) from public, anon, authenticated;
comment on function private.open_reports_of(uuid) is
  'LEAVE1-12: the person''s open reports (unsigned, correction_draft, returned). Codes and ids only; no content, no reason.';

-- Counts by kind, for the end_member_access result.
create or replace function private.open_report_counts(p_user uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'unsigned', count(*) filter (where o.kind = 'unsigned'),
    'correction_draft', count(*) filter (where o.kind = 'correction_draft'),
    'returned', count(*) filter (where o.kind = 'returned'))
  from private.open_reports_of(p_user) o
$$;
revoke all on function private.open_report_counts(uuid) from public, anon, authenticated;

-- The list (1): kind, visit date and team; to the organisation's administrators and the report team's RNs.
drop function if exists public.member_open_reports(uuid);
create function public.member_open_reports(p_user_id uuid)
returns table (kind text, visit_date date, team_name text)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
  select o.kind, v.visit_date, t.name
  from private.open_reports_of(p_user_id) o
  join public.care_visits v on v.id = o.visit_id
  join public.teams t on t.id = o.team_id
  where p_user_id is not null
    and (private.is_org_admin(o.organization_id)
         or (private.is_org_member(o.organization_id) and private.is_team_member(o.team_id)
             and private.is_registered_nurse(o.team_id, (select auth.uid()))))
  order by v.visit_date, o.kind, o.visit_id;
end
$$;
revoke all on function public.member_open_reports(uuid) from public, anon;
grant execute on function public.member_open_reports(uuid) to authenticated;
comment on function public.member_open_reports(uuid) is
  'LEAVE1-12 (1): the person''s open reports by kind with visit date and team (no content, no reason), for the '
  'organisation''s administrators and the registered nurses of the report''s team.';

-- The RN's view (1): her teams' members who have open reports, with counts by kind (to see before an access end).
drop function if exists public.team_open_reports();
create function public.team_open_reports()
returns table (user_id uuid, member_name text, team_name text, unsigned integer, correction_draft integer, returned integer,
               access_ended_on date)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
  select m.user_id, private.member_name(t.organization_id, m.user_id), t.name,
         count(*) filter (where o.kind = 'unsigned')::int,
         count(*) filter (where o.kind = 'correction_draft')::int,
         count(*) filter (where o.kind = 'returned')::int,
         (private.at_zurich(private.access_ended_at(m.user_id)))::date
  from public.team_memberships m
  join public.teams t on t.id = m.team_id
  cross join lateral private.open_reports_of(m.user_id) o
  where o.team_id = m.team_id and m.user_id <> (select auth.uid())
    and private.is_org_member(t.organization_id) and private.is_team_member(t.id)
    and private.is_registered_nurse(t.id, (select auth.uid()))
  group by m.user_id, t.id, t.organization_id, t.name
  order by t.name, 2;
end
$$;
revoke all on function public.team_open_reports() from public, anon;
grant execute on function public.team_open_reports() to authenticated;
comment on function public.team_open_reports() is
  'LEAVE1-12 (1): for a registered nurse, the members of her teams with open reports in that team, counts by kind, and '
  '"Zugang beendet" as a date. No content, no reason.';

-- 7. end_member_access (0074): the result carries the open-report counts (LEAVE1-12 (2)); not refused by them ------------
do $$
declare
  def text := pg_get_functiondef('public.end_member_access(uuid, text, uuid)'::regprocedure);
  old_ text := E'  return jsonb_build_object(''result'', private.end_command(''ok''), ''push_subscriptions_removed'', subs);\n';
  new_ text := E'  -- LEAVE1-12 (2): her open reports by kind (they never refuse the command, LEAVE1-2).\n' ||
               E'  return jsonb_build_object(''result'', private.end_command(''ok''), ''push_subscriptions_removed'', subs,\n' ||
               E'                            ''open_reports'', private.open_report_counts(p_user_id));\n';
begin
  if position('LEAVE1-12 (2)' in def) > 0 then return; end if;
  if (length(def) - length(replace(def, old_, ''))) / length(old_) <> 1 then
    raise exception '0075: end_member_access result line not found exactly once';
  end if;
  execute replace(def, old_, new_);
end $$;

-- 8. /field read models ---------------------------------------------------------------------------------------------------
-- field_reports (0065, guarded 0074) plus performer_unavailable and performer_access_ended; i_can_return and
-- i_can_countersign agree with the commands.
drop function if exists public.field_reports(date);
create function public.field_reports(p_date date)
returns table (
  visit_id               uuid,
  report_id              uuid,
  version                integer,
  status                 text,
  summary                text,
  snapshot               jsonb,
  correction_reason      text,
  countersign_required   boolean,
  signed_at              timestamptz,
  countersigned_at       timestamptz,
  i_am_performer         boolean,
  i_signed               boolean,
  i_can_countersign      boolean,
  signed_by_name         text,
  countersigned_by_name  text,
  snapshot_hash          text,
  returned               boolean,
  return_reason          text,
  returned_at            timestamptz,
  returned_by_name       text,
  returned_snapshot      jsonb,
  i_can_return           boolean,
  performer_unavailable  boolean,
  performer_access_ended boolean
)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
  select x.visit_id, x.id, x.version, x.status, x.summary, x.shown, x.correction_reason, x.countersign_required,
         x.signed_at, x.countersigned_at,
         x.performer_id = (select auth.uid()),
         x.signed_by = (select auth.uid()),
         x.awaiting and x.performer_id <> (select auth.uid())
           and private.is_registered_nurse(x.team_id, (select auth.uid())),
         private.member_name(x.organization_id, x.signed_by),
         private.member_name(x.organization_id, x.countersigned_by),
         private.report_snapshot_hash(x.shown),
         x.return_id is not null or x.unavl,
         case when x.may_see_return then rt.reason end,
         case when x.may_see_return then rt.returned_at end,
         case when x.may_see_return then private.member_name(x.organization_id, rt.returned_by) end,
         case when x.may_see_return then rv.snapshot end,
         -- LEAVE1-11: a return is possible whether or not the performer is still available (return_report decides
         -- whether a draft opens).
         x.awaiting and x.performer_id <> (select auth.uid())
           and private.is_registered_nurse(x.team_id, (select auth.uid())),
         x.unavl,
         private.access_ended(x.performer_id)
  from (
    select r.*,
           case when r.status = 'draft' then private.visit_report_snapshot(r.visit_id) else r.snapshot end as shown,
           r.performer_id = (select auth.uid()) or private.is_registered_nurse(r.team_id, (select auth.uid())) as may_see_return,
           private.report_returned_unavailable(r.id) as unavl,
           r.status = 'signed' and r.countersign_required and not private.report_returned_unavailable(r.id) as awaiting
    from public.visit_reports r
    join public.care_visits v on v.id = r.visit_id
    where p_date is not null and v.visit_date = p_date
      and private.is_org_member(r.organization_id) and private.is_team_member(r.team_id)
      and r.status <> 'withdrawn'
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
  ) x
  left join public.visit_report_returns rt on rt.id = x.return_id or (x.unavl and rt.report_id = x.id)
  left join public.visit_reports rv on rv.id = rt.report_id
  order by x.visit_id;
end
$$;
revoke all on function public.field_reports(date) from public, anon;
grant execute on function public.field_reports(date) to authenticated;

-- The RN's queue (0065, guarded 0074) plus LEAVE1-5: the open reports of members whose access ended, with the marker.
--   kind: awaiting_countersignature | returned | returned_performer_unavailable | unsigned | correction_draft
drop function if exists public.field_countersign_queue();
create function public.field_countersign_queue()
returns table (
  report_id               uuid,
  visit_id                uuid,
  visit_date              date,
  time_start              time,
  client_name             text,
  team_name               text,
  signed_at               timestamptz,
  returned                boolean,
  returned_at             timestamptz,
  performer_name          text,
  kind                    text,
  performer_access_ended  date
)
language plpgsql stable security definer set search_path = ''
as $$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
  with q as (
    -- F7 + F6R-5: awaiting countersignature, returned (draft), returned while the performer was unavailable.
    select r.organization_id, r.team_id, r.visit_id, r.id as report_id, r.signed_at, r.performer_id,
           case when r.status = 'draft' then 'returned'
                when private.report_returned_unavailable(r.id) then 'returned_performer_unavailable'
                else 'awaiting_countersignature' end as kind,
           coalesce(rt.returned_at, ru.returned_at) as returned_at
    from public.visit_reports r
    left join public.visit_report_returns rt on rt.id = r.return_id
    left join public.visit_report_returns ru on ru.report_id = r.id and ru.performer_unavailable
    where r.countersign_required
      and (r.status = 'signed' or (r.status = 'draft' and r.return_id is not null))
      and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id and s.status <> 'withdrawn')
    union all
    -- LEAVE1-5: the other open reports of a member whose access ended (whether or not they need a countersignature).
    select o.organization_id, o.team_id, o.visit_id, o.report_id, null::timestamptz, m.user_id, o.kind, null::timestamptz
    from public.team_memberships m
    cross join lateral private.open_reports_of(m.user_id) o
    where private.access_ended(m.user_id) and o.team_id = m.team_id and o.kind in ('unsigned', 'correction_draft')
      and private.is_team_member(m.team_id) and private.is_registered_nurse(m.team_id, (select auth.uid()))
  )
  select q.report_id, q.visit_id, v.visit_date, v.time_start,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), t.name, q.signed_at,
         q.kind in ('returned', 'returned_performer_unavailable'), q.returned_at,
         private.member_name(q.organization_id, q.performer_id),
         q.kind,
         (private.at_zurich(private.access_ended_at(q.performer_id)))::date
  from q
  join public.care_visits v on v.id = q.visit_id
  join public.teams t on t.id = q.team_id
  left join public.cases c on c.id = v.case_id
  where q.performer_id <> (select auth.uid())
    and private.is_org_member(q.organization_id) and private.is_team_member(q.team_id)
    and private.is_registered_nurse(q.team_id, (select auth.uid()))
  order by coalesce(q.signed_at, q.returned_at, v.visit_date::timestamptz), q.visit_id;
end
$$;
revoke all on function public.field_countersign_queue() from public, anon;
grant execute on function public.field_countersign_queue() to authenticated;
comment on function public.field_countersign_queue() is
  'F7 + F6R-5 + LEAVE1-5: latest versions of the caller''s teams awaiting her countersignature, returned to their '
  'performer, returned while the performer was unavailable, and the other open reports of members whose access ended '
  '(performer_access_ended = the date, never the reason). Registered nurses of the team only; never the return reason.';

-- 9. HAND1 (LEAVE1-5, LEAVE1-12 (3)): "Zugang beendet" on a client's visits while a report of that performer is open -----
do $$
declare
  def text := pg_get_functiondef('private.handover_entries(uuid, uuid)'::regprocedure);
  anchor text := E'  )\n  select * from entries order by at, entry_id\n';
  add_ text := E'    union all\n' ||
    E'    -- LEAVE1-5 / LEAVE1-12 (3): an open report of a performer whose access ended. A state, shown until the report\n' ||
    E'    -- is closed (not filtered by since_at); every team member who reads this card sees it. Kind and date only:\n' ||
    E'    -- never the return reason, never the access reason code.\n' ||
    E'    select ''performer_access_ended'', ''leave1:'' || sv.id::text, private.access_ended_at(pm.user_id), sv.visit_date, sv.time_start,\n' ||
    E'           private.member_code(k.team_id, pm.user_id, p_user),\n' ||
    E'           jsonb_build_object(''report_kind'', o.kind,\n' ||
    E'                              ''access_ended_on'', (private.at_zurich(private.access_ended_at(pm.user_id)))::date)\n' ||
    E'    from card k\n' ||
    E'    join public.care_visits sv on sv.case_id = k.case_id and sv.organization_id = k.organization_id\n' ||
    E'    cross join lateral (select private.visit_performer(sv.id) as user_id) pm\n' ||
    E'    cross join lateral private.open_reports_of(pm.user_id) o\n' ||
    E'    where sv.status = ''completed'' and private.access_ended(pm.user_id) and o.visit_id = sv.id\n' ||
    E'      and private.user_in_team(sv.team_id, p_user)\n';
begin
  if position('LEAVE1-5 / LEAVE1-12 (3)' in def) > 0 then return; end if;
  if (length(def) - length(replace(def, anchor, ''))) / length(anchor) <> 1 then
    raise exception '0075: handover_entries anchor not found exactly once';
  end if;
  execute replace(def, anchor, add_ || anchor);
end $$;
revoke all on function private.handover_entries(uuid, uuid) from public, anon, authenticated;
