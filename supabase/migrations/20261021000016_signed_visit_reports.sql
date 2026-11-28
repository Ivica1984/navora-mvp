-- =============================================================================
-- F6 — Signed visit report (brief docs/agents/briefs/F6.md, queue rank 4)
-- ARCHITECTURE.md: "… → menschlich freigegebener Bericht → Quality Gate → billable_facts"
-- =============================================================================
-- Design (ADR-032):
-- * The report has its OWN lifecycle; the visit stays a fact ending at `completed`.
--   Report versions: draft → signed → final  (or signed → awaiting countersignature → final)
-- * The draft is a SNAPSHOT built by the server from F1–F4/J3 data — times (effective,
--   with corrections), planned minutes per KLV category, actual care/travel/pause
--   minutes, services, current observations, handover notes — plus an optional
--   summary written by the nurse. No re-entry of facts.
-- * Performing nurse = the actor of the visit's first `started` event (F2). Only she
--   drafts, edits the summary and signs. Signature = who + when, stored on the version.
--   A correction (new version after final) may be opened by any team member with a
--   reason; the performing nurse signs it again.
-- * While a correction is a draft, the previous final version stays the valid report.
-- * Countersignature (D-10 open, PROVISIONAL default, stricter = safer): required
--   when the performing nurse is not a registered nurse of the team. A registered
--   nurse of the team (not the performer) countersigns; then the report is final.
-- * Signed versions are immutable. A correction is a new version with a required
--   reason and a link to the previous version; it is signed again.
-- * Only `final` counts. Drafts never appear as final or billable.
-- * Team-only: read, sign, countersign and correct by members of the visit's team.
-- =============================================================================

create table public.visit_reports (
  id                     uuid primary key default gen_random_uuid(),
  organization_id        uuid not null references public.organizations (id),
  visit_id               uuid not null,
  case_id                uuid,
  team_id                uuid not null,
  version                integer not null check (version >= 1),
  supersedes_id          uuid references public.visit_reports (id),
  correction_reason      text check (correction_reason is null or char_length(btrim(correction_reason)) between 3 and 300),
  status                 text not null default 'draft' check (status in ('draft', 'signed', 'final')),
  snapshot               jsonb not null,
  summary                text check (summary is null or char_length(summary) <= 4000),
  performer_id           uuid not null,
  countersign_required   boolean not null,
  created_by             uuid not null,
  created_at             timestamptz not null default now(),
  signed_by              uuid,
  signed_at              timestamptz,
  countersigned_by       uuid,
  countersigned_at       timestamptz,
  unique (visit_id, version),
  foreign key (visit_id, organization_id) references public.care_visits (id, organization_id),
  foreign key (team_id, organization_id) references public.teams (id, organization_id),
  check (supersedes_id is null or correction_reason is not null),
  check (status = 'draft' or (signed_by is not null and signed_at is not null)),
  check (status <> 'final' or not countersign_required or countersigned_by is not null)
);

create unique index visit_reports_one_successor on public.visit_reports (supersedes_id) where supersedes_id is not null;
create index visit_reports_visit_idx on public.visit_reports (visit_id, version desc);

comment on table public.visit_reports is
  'F6: versioned visit reports. Snapshot built by the server; signed versions are immutable; only status final counts.';

alter table public.visit_reports enable row level security;
revoke all on public.visit_reports from anon, authenticated;
grant select on public.visit_reports to authenticated;
create policy team_members_read on public.visit_reports
  for select to authenticated
  using (private.is_org_member(organization_id) and private.is_team_member(team_id));

-- Immutability: once signed, only the countersignature may be added (signed → final).
create function private.guard_visit_report()
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
  if old.status = 'signed' and not (
       new.status = 'final' and new.countersigned_by is not null
       and (new.snapshot, new.summary, new.signed_by, new.signed_at, new.version, new.visit_id)
           is not distinct from (old.snapshot, old.summary, old.signed_by, old.signed_at, old.version, old.visit_id)) then
    raise exception 'a signed report is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger visit_reports_guard
  before update or delete on public.visit_reports
  for each row execute function private.guard_visit_report();

create trigger audit_visit_reports
  after insert or update on public.visit_reports
  for each row execute function private.write_audit_event('status', 'version', 'signed_by', 'countersigned_by', 'countersign_required');

-- Helpers ---------------------------------------------------------------------------
create function private.visit_performer(p_visit_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select e.actor_id from public.visit_events e
  where e.visit_id = p_visit_id and e.event_type = 'started' and e.actor_id is not null
  order by e.id limit 1;
$$;

-- Snapshot of the visit at draft time (effective times incl. corrections).
create function private.visit_report_snapshot(p_visit_id uuid)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'visit_date', v.visit_date,
    'planned', jsonb_build_object('start', v.time_start, 'end', v.time_end,
                                  'a', v.planned_minutes_a, 'b', v.planned_minutes_b, 'c', v.planned_minutes_c,
                                  'needs_assessment', v.is_needs_assessment),
    'services', coalesce(to_jsonb(v.services_provided), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object('type', e.event_type,
                                          'at', coalesce(lc.corrected_at, e.occurred_at),
                                          'corrected', lc.corrected_at is not null,
                                          'reason', lc.reason) order by e.id)
      from public.visit_events e
      left join lateral (select x.corrected_at, x.reason from public.visit_time_corrections x
                         where x.event_id = e.id order by x.created_at desc, x.id desc limit 1) lc on true
      where e.visit_id = v.id), '[]'::jsonb),
    'observations', coalesce((
      select jsonb_agg(jsonb_build_object('content', o.content, 'recorded_at', o.recorded_at,
                                          'handover', o.for_handover, 'edited', o.supersedes_id is not null)
                       order by o.recorded_at)
      from public.visit_observations o
      where o.visit_id = v.id
        and not exists (select 1 from public.visit_observations s where s.supersedes_id = o.id)), '[]'::jsonb)
  )
  from public.care_visits v where v.id = p_visit_id;
$$;

revoke all on function private.visit_performer(uuid), private.visit_report_snapshot(uuid) from public, anon, authenticated;

-- Commands (SECURITY DEFINER: no direct writes for app users; explicit checks on auth.uid()) -----
-- Return jsonb {"result": "ok"|"duplicate"|"rejected", "reason": code?, "report_id": uuid?}
-- Rejection reasons: not_team_member, visit_not_completed, no_performer, draft_exists,
--   not_draft, not_performer, not_awaiting_countersignature, rn_required, own_report,
--   not_final, not_latest

create function public.create_report_draft(p_visit_id uuid, p_summary text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  v    public.care_visits%rowtype;
  perf uuid;
  rid  uuid;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if p_summary is not null and char_length(p_summary) > 4000 then
    raise exception 'summary too long' using errcode = '22023';
  end if;
  if private.begin_command('create_report_draft', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;

  select * into v from public.care_visits where id = p_visit_id for update;
  if not found or not private.is_org_member(v.organization_id) or not private.is_team_member(v.team_id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if v.status <> 'completed' then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'visit_not_completed');
  end if;
  if exists (select 1 from public.visit_reports r where r.visit_id = v.id) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'draft_exists');
  end if;
  perf := private.visit_performer(v.id);
  if perf is null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'no_performer');
  end if;
  -- The summary is the performing nurse's statement: only she drafts (and later signs).
  if perf <> uid then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_performer');
  end if;

  insert into public.visit_reports
    (organization_id, visit_id, case_id, team_id, version, status, snapshot, summary,
     performer_id, countersign_required, created_by)
  values
    (v.organization_id, v.id, v.case_id, v.team_id, 1, 'draft', private.visit_report_snapshot(v.id),
     nullif(btrim(p_summary), ''), perf, not private.is_registered_nurse(v.team_id, perf), uid)
  returning id into rid;

  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', rid);
end;
$$;

create function public.update_report_draft(p_report_id uuid, p_summary text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.visit_reports%rowtype;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if p_summary is not null and char_length(p_summary) > 4000 then
    raise exception 'summary too long' using errcode = '22023';
  end if;
  if private.begin_command('update_report_draft', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
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
  -- Refresh the snapshot too: the draft reflects the latest facts until it is signed.
  update public.visit_reports
    set summary = nullif(btrim(p_summary), ''), snapshot = private.visit_report_snapshot(r.visit_id)
    where id = r.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', r.id);
end;
$$;

create function public.sign_report(p_report_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.visit_reports%rowtype;
begin
  if uid is null then return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member'); end if;
  if private.begin_command('sign_report', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
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
  update public.visit_reports
    set status = case when r.countersign_required then 'signed' else 'final' end,
        signed_by = uid, signed_at = now(),
        snapshot = private.visit_report_snapshot(r.visit_id)   -- freeze the latest facts at signing
    where id = r.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', r.id);
end;
$$;

create function public.countersign_report(p_report_id uuid, p_idempotency_key uuid)
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
  update public.visit_reports set status = 'final', countersigned_by = uid, countersigned_at = now() where id = r.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'report_id', r.id);
end;
$$;

create function public.correct_report(p_report_id uuid, p_reason text, p_summary text, p_idempotency_key uuid)
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

revoke all on function
  public.create_report_draft(uuid, text, uuid), public.update_report_draft(uuid, text, uuid),
  public.sign_report(uuid, uuid), public.countersign_report(uuid, uuid), public.correct_report(uuid, text, text, uuid)
from public, anon;
grant execute on function
  public.create_report_draft(uuid, text, uuid), public.update_report_draft(uuid, text, uuid),
  public.sign_report(uuid, uuid), public.countersign_report(uuid, uuid), public.correct_report(uuid, text, text, uuid)
to authenticated;

-- Read models -------------------------------------------------------------------------------
-- Latest report version per visit of the caller's teams on a day, for /field.
create function public.field_reports(p_date date)
returns table (
  visit_id             uuid,
  report_id            uuid,
  version              integer,
  status               text,
  summary              text,
  snapshot             jsonb,
  correction_reason    text,
  countersign_required boolean,
  signed_at            timestamptz,
  countersigned_at     timestamptz,
  i_am_performer       boolean,
  i_signed             boolean,
  i_can_countersign    boolean
)
language sql stable security definer set search_path = ''
as $$
  select r.visit_id, r.id, r.version, r.status, r.summary, r.snapshot, r.correction_reason, r.countersign_required,
         r.signed_at, r.countersigned_at,
         r.performer_id = (select auth.uid()),
         r.signed_by = (select auth.uid()),
         r.status = 'signed' and r.countersign_required and r.performer_id <> (select auth.uid())
           and private.is_registered_nurse(r.team_id, (select auth.uid()))
  from public.visit_reports r
  join public.care_visits v on v.id = r.visit_id
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(r.organization_id) and private.is_team_member(r.team_id)
    and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)
  order by r.visit_id;
$$;

-- Operations: which completed visits have a final report (no content, organisation scope).
create function public.final_report_visits()
returns table (visit_id uuid)
language sql stable security definer set search_path = ''
as $$
  select distinct r.visit_id from public.visit_reports r
  where r.status = 'final' and private.is_org_member(r.organization_id)
    and (private.is_coordinator(r.organization_id) or private.is_team_member(r.team_id));
$$;

revoke all on function public.field_reports(date), public.final_report_visits() from public, anon;
grant execute on function public.field_reports(date), public.final_report_visits() to authenticated;
