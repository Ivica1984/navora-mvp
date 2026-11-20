-- BK-e2b (PO package contract 2026-11-19 16:40 point 2, BK brief criterion 5 «the signed version records its input»;
-- `lca` D-4 storage reading 2026-11-18 04:20: every input segment once with its decision, discarded segments kept with
-- the report for its lifetime, never under billing), ADR-219. Phase A: synthetic data only.
--
-- Before (IMPLEMENTED, read in 0001-0151): the carer's typed notes and her per-sentence decisions exist only in the
-- browser. The summary she signs holds the taken lines and inserted sentences; what she left out, and that she decided
-- it, is not stored anywhere. The AIG1 ledger (0151) holds model lines without text.
-- Now (IMPLEMENTED in this migration):
--   1. `public.visit_report_inputs`: one row each time she places a decided draft into the summary of her open report:
--      every segment of her notes once, in order (s1 … sN, none missing), with its text and her decision
--      (`taken`: in a taken line; `dropped`: only in lines she rejected; `inserted`: listed «nicht übernommen» and put
--      in; `omitted`: listed and deliberately left out); the lines as source ids and decision only (no line text:
--      a taken line's text is in the summary, a rejected one is not kept, data minimisation).
--      Append-only, no grant for app roles; written only by the command; audited without text.
--   2. `public.record_report_input(report, origin, segments, lines, key)`: performer of the open draft, in her team,
--      access not ended; checks that each segment has exactly one decision consistent with the lines; refuses a signed
--      report (the record belongs to the version she signs and cannot be added afterwards).
--   Billing reads only `final` reports (0051 `generate_billable_facts`); nothing here touches billing.
-- Phase B (documented in ADR-219, not built): retention and deletion of the typed text for real persons are decided by
-- the owner and the legal adviser (OPEN); whether the input record is Patientendokumentation stays with the legal
-- adviser (BK brief 2026-11-18 point 6).
-- Idempotent: `if not exists`, `create or replace`, `drop trigger if exists`, `on conflict do nothing`.

create table if not exists public.visit_report_inputs (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null,
  report_id       uuid not null references public.visit_reports (id),
  origin          text not null check (origin in ('rule', 'model')),
  segment_count   integer not null check (segment_count between 1 and 400),
  segments        jsonb not null,
  lines           jsonb not null,
  created_by      uuid not null,
  created_at      timestamptz not null default private.now(),
  foreign key (team_id, organization_id) references public.teams (id, organization_id)
);
create index if not exists visit_report_inputs_report_idx on public.visit_report_inputs (report_id, created_at);
alter table public.visit_report_inputs enable row level security;
revoke all on public.visit_report_inputs from public, anon, authenticated;
comment on table public.visit_report_inputs is
  'BK-e2b, ADR-219: the carer''s typed notes of a report draft, each segment once with her decision, and the draft '
  'lines as source ids and decisions (no line text). Append-only; written by record_report_input only; no app read.';

drop trigger if exists visit_report_inputs_append_only on public.visit_report_inputs;
create trigger visit_report_inputs_append_only before update or delete on public.visit_report_inputs
  for each row execute function private.aig1_append_only();
drop trigger if exists visit_report_inputs_no_truncate on public.visit_report_inputs;
create trigger visit_report_inputs_no_truncate before truncate on public.visit_report_inputs
  for each statement execute function private.aig1_append_only();

-- Audit: codes only, never the typed text.
drop trigger if exists audit_visit_report_inputs on public.visit_report_inputs;
create trigger audit_visit_report_inputs after insert on public.visit_report_inputs
  for each row execute function private.write_audit_event('report_id', 'origin', 'segment_count');
insert into private.audit_value_classes (table_name, key, class) values
  ('visit_report_inputs', 'report_id',     'code'),
  ('visit_report_inputs', 'origin',        'code'),
  ('visit_report_inputs', 'segment_count', 'code')
on conflict do nothing;

-- Shape and consistency of one input record; true when valid.
create or replace function private.report_input_ok(p_segments jsonb, p_lines jsonb)
returns boolean language sql immutable set search_path = ''
as $$
  with seg as (
    select e, n from jsonb_array_elements(case when jsonb_typeof(p_segments) = 'array' then p_segments else '[]' end)
                     with ordinality s(e, n)
  ),
  lin as (
    select e from jsonb_array_elements(case when jsonb_typeof(p_lines) = 'array' then p_lines else '[]' end) l(e)
  ),
  cites as (   -- segment id, decision of a line that cites it
    select (x #>> '{}') as sid, l.e ->> 'decision' as d
    from lin l, jsonb_array_elements(case when jsonb_typeof(l.e -> 'sources') = 'array' then l.e -> 'sources' else '[]' end) x
    where jsonb_typeof(x) = 'string' and (x #>> '{}') like 's%'
  )
  select jsonb_typeof(p_segments) = 'array' and jsonb_typeof(p_lines) = 'array'
     and jsonb_array_length(p_segments) between 1 and 400
     and jsonb_array_length(p_lines) <= 400
     -- every segment: object, id s<n> in order (none missing or repeated), text, one decision
     and not exists (
       select 1 from seg
       where jsonb_typeof(e) <> 'object'
          or e ->> 'id' is distinct from ('s' || n)
          or jsonb_typeof(e -> 'text') is distinct from 'string'
          or char_length(btrim(e ->> 'text')) not between 1 and 8000
          or (e ->> 'decision') is null or (e ->> 'decision') not in ('taken', 'dropped', 'inserted', 'omitted'))
     and (select coalesce(sum(char_length(e ->> 'text')), 0) from seg) <= 8000
     -- every line: object, sources s<n>/f<n> (segments must exist), decision taken or dropped, no text kept
     and not exists (
       select 1 from lin
       where jsonb_typeof(e) <> 'object' or e ? 'text'
          or (e ->> 'decision') is null or (e ->> 'decision') not in ('taken', 'dropped')
          or jsonb_typeof(e -> 'sources') is distinct from 'array'
          or jsonb_array_length(e -> 'sources') not between 1 and 50
          or exists (select 1 from jsonb_array_elements(e -> 'sources') x
                     where jsonb_typeof(x) <> 'string' or (x #>> '{}') !~ '^[sf][1-9][0-9]{0,3}$'))
     and not exists (select 1 from cites c where not exists (select 1 from seg where seg.e ->> 'id' = c.sid))
     -- consistency between a segment's decision and the lines that cite it
     and not exists (
       select 1 from seg
       where case e ->> 'decision'
               when 'taken' then not exists (select 1 from cites c where c.sid = e ->> 'id' and c.d = 'taken')
               when 'dropped' then not exists (select 1 from cites c where c.sid = e ->> 'id')
                                   or exists (select 1 from cites c where c.sid = e ->> 'id' and c.d = 'taken')
               else exists (select 1 from cites c where c.sid = e ->> 'id')
             end)
$$;
revoke all on function private.report_input_ok(jsonb, jsonb) from public, anon, authenticated;

create or replace function public.record_report_input(p_report_id uuid, p_origin text, p_segments jsonb, p_lines jsonb,
                                                      p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r   public.visit_reports%rowtype;
begin
  if p_origin is null or p_origin not in ('rule', 'model') then
    raise exception 'origin invalid' using errcode = '22023';
  end if;
  if not private.report_input_ok(p_segments, p_lines) then
    raise exception 'input record invalid' using errcode = '22023';
  end if;
  if private.begin_command('record_report_input', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into r from public.visit_reports v where v.id = p_report_id for update;
  if r.id is null or uid is null or not private.is_org_member(r.organization_id) or not private.is_team_member(r.team_id)
     or private.access_ended(uid) then
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
  insert into public.visit_report_inputs (organization_id, team_id, report_id, origin, segment_count, segments, lines,
                                          created_by)
  values (r.organization_id, r.team_id, r.id, p_origin, jsonb_array_length(p_segments), p_segments, p_lines, uid);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok');
end;
$$;
revoke all on function public.record_report_input(uuid, text, jsonb, jsonb, uuid) from public, anon;
grant execute on function public.record_report_input(uuid, text, jsonb, jsonb, uuid) to authenticated;
comment on function public.record_report_input(uuid, text, jsonb, jsonb, uuid) is
  'BK-e2b, ADR-219: the performer records her typed notes with one decision per segment when she places a decided '
  'draft into the summary of her open report. Refused on a signed report, for another member or team.';
