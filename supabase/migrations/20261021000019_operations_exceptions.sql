-- =============================================================================
-- OPS1 — Operations exception center (brief docs/agents/briefs/OPS1.md, Q9 answered)
-- ARCHITECTURE.md: Operations is an exception-based control tower, not dispatch.
-- =============================================================================
-- Design (ADR-035):
-- * Exceptions are DERIVED from state by public.operations_exceptions(); nobody enters one.
-- * Types, thresholds and priorities are configuration (exception_rules) with the PO pilot
--   defaults (Q9). Priorities: P1 safety, P2 continuity, P3 administration.
-- * Handling is an append-only event log (exception_events): take over, comment, close
--   (reason required) and auto_close (note written when the cause is gone). The current
--   handling state of an exception is its latest event.
-- * Each exception has a stable key "<type>:<entity>[:<cause>]", so a new cause (e.g. a new
--   order expiry date) is a new exception.
-- * Coordination roles only; data limited to what Operations may already read (case label,
--   region, team name; no health fields). No matching start and no case editing.
-- =============================================================================

-- 1. Rules (configuration) ----------------------------------------------------------------------------
create table public.exception_rules (
  exception_type text primary key,
  priority       text not null check (priority in ('P1', 'P2', 'P3')),
  -- Threshold after which the exception exists or escalates; meaning per type below.
  amount         integer check (amount is null or amount between 0 and 720),
  unit           text check (unit is null or unit in ('hours', 'days', 'working_days')),
  -- Optional escalation: after this many hours the priority becomes P1 (serious quality events).
  escalate_to_p1_after_hours integer check (escalate_to_p1_after_hours is null or escalate_to_p1_after_hours between 0 and 720),
  label          text not null,
  next_step      text not null,
  updated_at     timestamptz not null default now()
);
comment on table public.exception_rules is
  'OPS1: exception types with priority and thresholds. Pilot defaults from the PO (Q9).';

insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  -- P1 safety
  ('quality_serious_open',      'P2', null, null,           4,    'Schweres Qualitätsereignis offen',                 'Team kontaktieren und Sicherheit klären.'),
  ('visit_uncovered_hospital',  'P1', 24,   'hours',        null, 'Einsatz ohne Verantwortliche (Spitalaustritt)',    'Team informieren; das Team bestimmt, wer übernimmt.'),
  -- P2 continuity
  ('visit_uncovered',           'P2', 24,   'hours',        null, 'Einsatz ohne Verantwortliche',                     'Team informieren; das Team bestimmt, wer übernimmt.'),
  ('candidates_exhausted',      'P2', null, null,           null, 'Teamsuche: kein Team mehr verfügbar',              'Mit Teams und zuweisender Stelle klären; nie automatisch zuweisen.'),
  ('offer_overdue',             'P2', null, null,           null, 'Teamsuche: Antwortfrist abgelaufen',               'Teams nachfragen; zuweisende Stelle informieren.'),
  -- P3 administration
  ('deadline_missing',          'P3', null, null,           null, 'Teamsuche ohne Antwortfrist',                      'Antwortfrist für diese Zuweisungsart festlegen (Admin).'),
  ('case_not_ready',            'P3', 1,    'working_days', null, 'Fall nicht bereit für die Teamsuche',              'Fehlende Angaben bei der zuweisenden Stelle einholen.'),
  ('order_expiring',            'P3', 7,    'days',         null, 'Ärztliche Verordnung läuft ab oder ist abgelaufen', 'Team erinnern, Verlängerung beim Arzt anzufordern.'),
  ('care_plan_review_overdue',  'P3', null, null,           null, 'Überprüfung des Pflegeplans überfällig',           'Team an die Neubeurteilung erinnern.'),
  ('report_not_final',          'P3', 24,   'hours',        null, 'Einsatzbericht nicht abgeschlossen',               'Team an Bericht und Unterschrift erinnern.');

alter table public.exception_rules enable row level security;
revoke all on public.exception_rules from anon, authenticated;
grant select on public.exception_rules to authenticated;
create policy members_read on public.exception_rules for select to authenticated using (true);

-- 2. Handling events (append-only) ------------------------------------------------------------------------
create table public.exception_events (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id),
  exception_key   text not null check (char_length(exception_key) between 3 and 200),
  kind            text not null check (kind in ('take', 'comment', 'close', 'auto_close')),
  text            text check (text is null or char_length(btrim(text)) between 1 and 1000),
  actor_id        uuid,                       -- null for auto_close
  idempotency_key uuid,
  created_at      timestamptz not null default now(),
  unique (actor_id, idempotency_key),
  check (kind not in ('comment', 'close', 'auto_close') or text is not null)
);
create index exception_events_key_idx on public.exception_events (organization_id, exception_key, id desc);
comment on table public.exception_events is
  'OPS1: append-only handling of derived exceptions (take over, comment, close with reason, auto close with note).';

alter table public.exception_events enable row level security;
revoke all on public.exception_events from anon, authenticated;
grant select on public.exception_events to authenticated;
create policy coordinators_read on public.exception_events
  for select to authenticated using (private.is_coordinator(organization_id));
create trigger exception_events_no_update_delete
  before update or delete on public.exception_events
  for each row execute function private.forbid_audit_change();
create trigger exception_events_no_truncate
  before truncate on public.exception_events
  for each statement execute function private.forbid_audit_change();

-- 3. Derivation -------------------------------------------------------------------------------------------
-- Threshold helper: hours, calendar days or working days (J2 calendar) after a point in time.
create function private.after_threshold(p_from timestamptz, p_amount integer, p_unit text)
returns timestamptz language sql stable set search_path = ''
as $$
  select case
    when p_amount is null or p_amount = 0 then p_from
    when p_unit = 'working_days' then private.add_working_time(p_from, p_amount, 'working_days')
    when p_unit = 'days' then p_from + make_interval(days => p_amount)
    else p_from + make_interval(hours => p_amount) end
$$;
revoke all on function private.after_threshold(timestamptz, integer, text) from public, anon, authenticated;

-- J2's escalation logic for one organisation, without the caller check (internal).
create function private.matching_escalations_for(p_org uuid)
returns table (matching_request_id uuid, request_title text, created_at timestamptz, response_due_at timestamptz,
               reason text, declines jsonb)
language sql stable security definer set search_path = ''
as $$
  with open_requests as (
    select m.* from public.matching_requests m
    join public.cases c on c.id = m.case_id
    where m.status = 'open' and c.assigned_team_id is null and m.organization_id = p_org
  ), scored as (
    select r.*,
      (select count(*)::int from public.teams t
        where t.organization_id = r.organization_id and t.status = 'active' and t.region = r.region
          and (r.required_qualification is null or private.team_has_registered_nurse(t.id))) as eligible,
      (select count(*)::int from public.teams t
        where t.organization_id = r.organization_id and t.status = 'active' and t.region = r.region
          and (r.required_qualification is null or private.team_has_registered_nurse(t.id))
          and not exists (select 1 from public.team_decisions d where d.matching_request_id = r.id and d.team_id = t.id)) as undecided,
      coalesce((select jsonb_agg(jsonb_build_object('team', t.name, 'code', d.reason_code, 'reason', d.reason, 'at', d.decided_at)
                                 order by d.decided_at)
                from public.team_decisions d join public.teams t on t.id = d.team_id
                where d.matching_request_id = r.id and d.decision = 'decline'), '[]'::jsonb) as declines
    from open_requests r
  )
  select s.id, s.request_title, s.created_at, s.response_due_at,
         case when s.eligible = 0 then 'no_eligible_team'
              when s.undecided = 0 then 'all_declined'
              when s.response_due_at is not null and s.response_due_at < now() then 'deadline_passed'
              else 'deadline_not_configured' end,
         s.declines
  from scored s
  where s.eligible = 0 or s.undecided = 0
     or (s.response_due_at is not null and s.response_due_at < now())
     or s.response_due_at is null;
$$;
revoke all on function private.matching_escalations_for(uuid) from public, anon, authenticated;

-- Internal: all current causes of an organisation, without handling state.
create function private.derived_exceptions(p_org uuid)
returns table (
  exception_key  text,
  exception_type text,
  since          timestamptz,
  case_id        uuid,
  team_id        uuid,
  entity_type    text,
  entity_id      uuid,
  detail         text
)
language sql stable security definer set search_path = ''
as $$
  with rules as (select * from public.exception_rules)
  -- J1: case not ready for matching after the threshold (working time from the referral)
  select 'case_not_ready:' || c.id, 'case_not_ready', p.created_at, c.id, null::uuid, 'case', c.id,
         (select string_agg(m ->> 'item', ', ') from jsonb_array_elements(private.case_readiness(c.id)) m)
  from public.cases c
  join public.partner_requests p on p.id = c.source_partner_request_id, rules r
  where r.exception_type = 'case_not_ready' and c.organization_id = p_org and c.ready_for_matching_at is null
    and now() >= private.after_threshold(p.created_at, r.amount, r.unit)
  union all
  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)
  select case e.reason when 'deadline_passed' then 'offer_overdue:' when 'deadline_not_configured' then 'deadline_missing:'
                       else 'candidates_exhausted:' end || e.matching_request_id,
         case e.reason when 'deadline_passed' then 'offer_overdue' when 'deadline_not_configured' then 'deadline_missing'
                       else 'candidates_exhausted' end,
         coalesce(e.response_due_at, e.created_at), m.case_id, null::uuid, 'matching_request', e.matching_request_id,
         e.request_title || coalesce(' · Absagen: ' || (select string_agg(coalesce(d ->> 'team', 'Team') || ' (' || coalesce(d ->> 'code', '?') || ')', ', ')
                                                        from jsonb_array_elements(e.declines) d), '')
  from private.matching_escalations_for(p_org) e
  join public.matching_requests m on m.id = e.matching_request_id
  union all
  -- J3: uncovered visits in the next 24 h (P1 when the case came as a hospital discharge)
  select case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital:' else 'visit_uncovered:' end || v.id,
         case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end,
         (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich', v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
  from public.care_visits v
  left join lateral (select x.referral_type from public.matching_requests x where x.case_id = v.case_id order by x.created_at desc limit 1) mr on true
  join rules r on r.exception_type = case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null
    and (v.visit_date + coalesce(v.time_start, time '00:00')) at time zone 'Europe/Zurich'
        between now() and private.after_threshold(now(), r.amount, r.unit)
  union all
  -- J3: medical order expiring within the threshold or expired, on a running case
  select 'order_expiring:' || c.id || ':' || c.medical_order_valid_until, 'order_expiring',
         (c.medical_order_valid_until - make_interval(days => coalesce(r.amount, 0)))::timestamptz, c.id, c.assigned_team_id, 'case', c.id,
         'gültig bis ' || to_char(c.medical_order_valid_until, 'DD.MM.YYYY')
  from public.cases c, rules r
  where r.exception_type = 'order_expiring' and c.organization_id = p_org
    and c.assigned_team_id is not null and c.medical_order_status = 'present' and c.medical_order_valid_until is not null
    and c.medical_order_valid_until <= current_date + coalesce(r.amount, 0)
  union all
  -- J3: care-plan review overdue
  select 'care_plan_review_overdue:' || i.case_id || ':' || min(i.review_date), 'care_plan_review_overdue',
         min(i.review_date)::timestamptz, i.case_id, min(i.team_id::text)::uuid, 'case', i.case_id,
         'Überprüfung fällig seit ' || to_char(min(i.review_date), 'DD.MM.YYYY')
  from public.care_plan_items i
  join public.cases c on c.id = i.case_id
  where c.organization_id = p_org and i.active
  group by i.case_id
  having min(i.review_date) < current_date
  union all
  -- QG1/legacy: serious quality event open (high, critical); priority escalates after the threshold
  select 'quality_serious_open:' || q.id, 'quality_serious_open', q.created_at, q.case_id, q.team_id, 'quality_event', q.id, q.title
  from public.quality_events q
  where q.organization_id = p_org and q.status = 'open' and q.severity in ('high', 'critical')
  union all
  -- F6: report not final 24 h after the visit ended
  select 'report_not_final:' || v.id, 'report_not_final', ended.at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.')
  from public.care_visits v
  join lateral (select max(e.occurred_at) as at from public.visit_events e where e.visit_id = v.id and e.event_type = 'completed') ended on true
  , rules r
  where r.exception_type = 'report_not_final' and v.organization_id = p_org and v.status = 'completed'
    and ended.at is not null
    and now() >= private.after_threshold(ended.at, r.amount, r.unit)
    and not exists (select 1 from public.visit_reports vr where vr.visit_id = v.id and vr.status = 'final')
$$;
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

-- 4. Read model for Operations -------------------------------------------------------------------------------
create function public.operations_exceptions()
returns table (
  exception_key  text,
  exception_type text,
  priority       text,
  label          text,
  next_step      text,
  detail         text,
  since          timestamptz,
  case_id        uuid,
  case_label     text,
  region         text,
  team_name      text,
  entity_type    text,
  entity_id      uuid,
  taken_by_me    boolean,
  taken          boolean,
  taken_at       timestamptz,
  comments       jsonb
)
language sql stable security definer set search_path = ''
as $$
  with my_orgs as (
    select om.organization_id from public.organization_memberships om
    where om.user_id = (select auth.uid()) and private.is_coordinator(om.organization_id)
  ), d as (
    select o.organization_id, x.* from my_orgs o, lateral private.derived_exceptions(o.organization_id) x
  ), latest as (
    select distinct on (ev.organization_id, ev.exception_key) ev.organization_id, ev.exception_key, ev.kind, ev.actor_id, ev.created_at
    from public.exception_events ev
    where ev.organization_id in (select organization_id from my_orgs) and ev.kind in ('take', 'close', 'auto_close')
    order by ev.organization_id, ev.exception_key, ev.id desc
  )
  select d.exception_key, d.exception_type,
         case when r.escalate_to_p1_after_hours is not null and now() >= d.since + make_interval(hours => r.escalate_to_p1_after_hours)
              then 'P1' else r.priority end,
         r.label, r.next_step, d.detail, d.since, d.case_id,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), c.region,
         coalesce(t.name, ct.name), d.entity_type, d.entity_id,
         l.kind = 'take' and l.actor_id = (select auth.uid()),
         coalesce(l.kind = 'take', false),
         case when l.kind = 'take' then l.created_at end,
         coalesce((select jsonb_agg(jsonb_build_object('text', ev.text, 'at', ev.created_at, 'mine', ev.actor_id = (select auth.uid()))
                                    order by ev.id)
                   from public.exception_events ev
                   where ev.organization_id = d.organization_id and ev.exception_key = d.exception_key and ev.kind = 'comment'), '[]'::jsonb)
  from d
  join public.exception_rules r on r.exception_type = d.exception_type
  left join latest l on l.organization_id = d.organization_id and l.exception_key = d.exception_key
  left join public.cases c on c.id = d.case_id
  left join public.teams t on t.id = d.team_id
  left join public.teams ct on ct.id = c.assigned_team_id
  where l.kind is null or l.kind = 'take'          -- closed exceptions stay closed for this cause
  order by 3, d.since;
$$;
revoke all on function public.operations_exceptions() from public, anon;
grant execute on function public.operations_exceptions() to authenticated;

-- 5. Commands --------------------------------------------------------------------------------------------------
-- Return: 'ok' | 'duplicate' | 'rejected' (not a coordinator, or the exception does not exist / is closed)
create function private.open_exception_org(p_key text)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select o.organization_id
  from public.organization_memberships o
  where o.user_id = (select auth.uid()) and private.is_coordinator(o.organization_id)
    and exists (select 1 from private.derived_exceptions(o.organization_id) x where x.exception_key = p_key)
    and coalesce((select ev.kind from public.exception_events ev
                  where ev.organization_id = o.organization_id and ev.exception_key = p_key and ev.kind in ('take', 'close', 'auto_close')
                  order by ev.id desc limit 1), 'take') = 'take'
  limit 1
$$;
revoke all on function private.open_exception_org(text) from public, anon, authenticated;

create function public.handle_exception(p_key text, p_kind text, p_text text, p_idempotency_key uuid)
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
  insert into public.exception_events (organization_id, exception_key, kind, text, actor_id, idempotency_key)
  values (org, p_key, p_kind, case when p_kind = 'take' then null else txt end, uid, p_idempotency_key);
  return 'ok';
end;
$$;
revoke all on function public.handle_exception(text, text, text, uuid) from public, anon;
grant execute on function public.handle_exception(text, text, text, uuid) to authenticated;

-- Auto close: exceptions with open handling whose cause is gone get a note. Called when
-- Operations loads (idempotent: only writes for keys whose latest event is a take or comment).
create function public.sync_exceptions()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  n integer := 0;
  rec record;
begin
  if (select auth.uid()) is null then return 0; end if;
  for rec in
    select distinct on (ev.organization_id, ev.exception_key) ev.organization_id, ev.exception_key, ev.kind
    from public.exception_events ev
    join public.organization_memberships om on om.organization_id = ev.organization_id and om.user_id = (select auth.uid())
    where private.is_coordinator(ev.organization_id)
    order by ev.organization_id, ev.exception_key, ev.id desc
  loop
    if rec.kind in ('take', 'comment')
       and not exists (select 1 from private.derived_exceptions(rec.organization_id) x where x.exception_key = rec.exception_key) then
      insert into public.exception_events (organization_id, exception_key, kind, text)
      values (rec.organization_id, rec.exception_key, 'auto_close', 'Ursache behoben – automatisch geschlossen');
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.sync_exceptions() from public, anon;
grant execute on function public.sync_exceptions() to authenticated;
