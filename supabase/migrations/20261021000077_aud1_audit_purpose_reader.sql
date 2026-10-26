-- AUD1: administrators read the audit log only for a stated purpose, without the team's free text
-- (PO brief docs/agents/briefs/AUD1.md, ADR-090; READ_PATHS.md finding F-3; D-4 provisional rule, gate r3).
--
-- Design:
-- 1. No standing table read (AUD1-2). The placeholder policy `org_admins_read_audit` (0004, "Q4") is dropped. RLS stays
--    on and no policy is left, so `authenticated` reads 0 rows of `audit_events` through the table API (the existing
--    column-less SELECT grant is kept so the result is "0 rows", as the brief states, not an error); `anon` has no
--    grant and is refused. The SECURITY DEFINER readers that derive facts from the log (begin_command, HAND1
--    handover_entries, J6 last_primary_nurse, CSR1 case_order_as_of, AN2 pilot_hypotheses) run as the table owner
--    and are unchanged.
-- 2. One value catalogue (AUD1-1). `private.audit_value_classes` classifies every key that can appear in
--    `audit_events.changed`, per audited table: `code` (closed value set, number, date, time, id, flag or a value
--    only commands set) or `free_text` (typed by a person: names, regions, reasons). Columns recorded by the audit
--    trigger whose type cannot carry text are classified `code` from the catalogue at migration time; every text
--    column is listed by hand. pgTAP 077 fails when an audited column is not in the catalogue, and fixes the
--    free-text list.
-- 3. One purpose reader (AUD1-3, AUD1-4). `public.read_audit_record(entity_type, entity_id, purpose)` returns the
--    audit rows of ONE record to an administrator of the record's organisation, only for `compliance`, `billing`
--    or `safety_review` (D-4 provisional rule). Values of `free_text` keys are returned only to an administrator
--    who is also an active member of the record's team; otherwise the key stays with value null, is named in
--    `withheld_keys` and `text_withheld` is true. A key that is not in the catalogue is withheld for everyone
--    (fail closed). No grouping, counting or ranking per member.
-- 4. Each read is recorded (AUD1-5) in the append-only `public.audit_read_log` (caller, time, organisation, entity
--    type and id, purpose code, rows returned; no client field, no free text). Administrators read their
--    organisation's rows through `public.org_audit_read_log(organisation)`: the rows only, no per-person aggregate.
-- No clinical rule, no new purpose code. Idempotent: re-running this file changes nothing.

-- 1. No standing table read -------------------------------------------------------------------------------------
drop policy if exists org_admins_read_audit on public.audit_events;
revoke all on public.audit_events from anon;
comment on table public.audit_events is
  'Append-only audit log. No table read for app roles (AUD1, ADR-090): administrators read one record''s rows for a '
  'stated purpose through public.read_audit_record; SECURITY DEFINER readers derive facts.';

-- 2. Value catalogue ----------------------------------------------------------------------------------------------
create table if not exists private.audit_value_classes (
  table_name text not null,
  key        text not null,
  class      text not null check (class in ('code', 'free_text')),
  primary key (table_name, key)
);
revoke all on private.audit_value_classes from public, anon, authenticated;
comment on table private.audit_value_classes is
  'AUD1-1: class of every key in audit_events.changed per audited table. free_text is withheld outside the team.';

-- 2a. Trigger-audited columns whose type cannot carry text: code.
insert into private.audit_value_classes (table_name, key, class)
select distinct c.relname::text, a.col, 'code'
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid and p.proname = 'write_audit_event'
join pg_class c on c.oid = t.tgrelid
cross join lateral unnest(string_to_array(rtrim(encode(t.tgargs, 'escape'), '\000'), '\000')) a(col)
join information_schema.columns ic
  on ic.table_schema = 'public' and ic.table_name = c.relname and ic.column_name = a.col
where not t.tgisinternal
  and ic.data_type not in ('text', 'character varying', 'character', 'json', 'jsonb', 'ARRAY', 'USER-DEFINED')
on conflict do nothing;

-- 2b. Text-typed trigger columns, by hand (constraint or command named), and keys written by the direct writers
--     (private.audit_command, set_member_qualification, plan_from_care_plan, set_auto_planning, the visit delete and
--     move triggers, the ADM1 range reset).
insert into private.audit_value_classes (table_name, key, class) values
  -- free text typed by a person (AUD1-1 inventory)
  ('quality_holds',            'reason',                     'free_text'),  -- 3..500 characters, may describe health
  ('quality_holds',            'lift_reason',                'free_text'),  -- 3..500 characters
  ('teams',                    'coach_name',                 'free_text'),  -- typed name (assign_team_coach)
  ('teams',                    'name',                       'free_text'),  -- typed team name (create_team, update_team)
  ('teams',                    'region',                     'free_text'),  -- typed region (create_team, update_team)
  ('cases',                    'region',                     'free_text'),  -- typed at intake (2..80)
  ('partner_requests',         'region',                     'free_text'),  -- typed at intake (2..80)
  ('matching_requests',        'region',                     'free_text'),  -- copied from the case
  ('member_profiles',          'display_name',               'free_text'),  -- typed name (2..80)
  ('member_invitations',       'email',                      'free_text'),  -- personal address typed by an admin
  -- closed value sets (CHECK constraint) or values only commands set (no column grant to app roles)
  ('care_plan_items',          'category',                   'code'),
  ('care_plan_items',          'freq_period',                'code'),
  ('care_plan_items',          'freq_weekdays',              'code'),
  ('care_visits',              'status',                     'code'),       -- state machine trigger (0004)
  ('care_visits',              'deleted',                    'code'),       -- delete trigger (0012)
  ('case_gp_notices',          'channel',                    'code'),
  ('case_lifecycle_events',    'kind',                       'code'),
  ('case_lifecycle_events',    'reason_code',                'code'),
  ('case_safety_alert_values', 'source',                     'code'),
  ('case_safety_alert_values', 'value',                      'code'),       -- ja | nein | unbekannt (the note is not audited)
  ('case_tasks',               'kind',                       'code'),
  ('case_tasks',               'status',                     'code'),
  ('cases',                    'insurance_type',             'code'),
  ('cases',                    'medical_order_status',       'code'),
  ('cases',                    'residence_canton',           'code'),
  ('cases',                    'status',                     'code'),       -- commands only
  ('cases',                    'urgency',                    'code'),       -- niedrig | mittel | hoch (commands)
  ('cases',                    'auto_planning',              'code'),
  ('cases',                    'result',                     'code'),       -- plan_from_care_plan summary
  ('cases',                    'created',                    'code'),
  ('cases',                    'regenerated',                'code'),
  ('cases',                    'dropped',                    'code'),
  ('cases',                    'kept',                       'code'),
  ('cases',                    'reasons',                    'code'),
  ('cover_events',             'kind',                       'code'),
  ('exception_rule_overrides', 'priority',                   'code'),
  ('exception_rule_overrides', 'reset',                      'code'),
  ('exception_rule_overrides', 'exception_type',             'code'),
  ('exception_rule_overrides', 'reason',                     'code'),       -- fixed literal of the ADM1 range reset
  ('matching_requests',        'status',                     'code'),
  ('matching_requests',        'urgency',                    'code'),
  ('member_access_events',     'kind',                       'code'),
  ('member_access_events',     'reason_code',                'code'),
  ('member_invitations',       'qualification',              'code'),
  ('member_invitations',       'role',                       'code'),
  ('organization_memberships', 'user_id',                    'code'),
  ('organization_memberships', 'role',                       'code'),
  ('organization_memberships', 'team_id',                    'code'),
  ('organization_memberships', 'qualification',              'code'),
  ('organization_memberships', 'access',                     'code'),
  ('organization_memberships', 'reason_code',                'code'),
  ('organization_memberships', 'push_subscriptions_removed', 'code'),
  ('organization_memberships', 'released_visits',            'code'),       -- {team_id: count}
  ('organization_watched_hours', 'hours',                    'code'),       -- weekday and times
  ('partner_requests',         'status',                     'code'),
  ('partner_requests',         'urgency',                    'code'),
  ('push_subscriptions',       'last_result',                'code'),
  ('push_subscriptions',       'vendor',                     'code'),
  ('push_subscriptions',       'deleted',                    'code'),
  ('push_subscriptions',       'reason',                     'code'),       -- gone | access_ended
  ('quality_events',           'severity',                   'code'),
  ('quality_events',           'status',                     'code'),
  ('referral_links',           'kind',                       'code'),
  ('response_deadlines',       'referral_type',              'code'),
  ('response_deadlines',       'unit',                       'code'),
  ('safety_signals',           'signal_kind',                'code'),
  ('signal_deliveries',        'reason',                     'code'),
  ('signal_deliveries',        'signal_kind',                'code'),       -- copied from safety_signals (CHECK there)
  ('signal_outside_deliveries', 'failure',                   'code'),
  ('signal_outside_deliveries', 'result',                    'code'),
  ('signal_takes',             'qualification',              'code'),
  ('team_memberships',         'user_id',                    'code'),
  ('team_memberships',         'qualification',              'code'),
  ('team_memberships',         'added',                      'code'),
  ('team_memberships',         'removed',                    'code'),
  ('team_memberships',         'released_visits',            'code'),
  ('teams',                    'status',                     'code'),       -- commands only
  ('teams',                    'created',                    'code'),
  ('visit_plan_changes',       'change',                     'code'),
  ('visit_plan_changes',       'responsible_absent',         'code'),
  ('visit_report_returns',     'snapshot_hash',              'code'),       -- 64 hex characters
  ('visit_reports',            'status',                     'code'),
  ('visit_status_notes',       'disclosure_basis',           'code'),
  ('visit_status_notes',       'kind',                       'code'),
  ('visit_status_notes',       'reason_code',                'code')
on conflict (table_name, key) do update set class = excluded.class;

-- 3. The record's team (for AUD1-4). Only records that carry free text need it; anything else has no team here, so
--    its free text is withheld for every reader.
create or replace function private.audit_record_team(p_table text, p_entity uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select case p_table
    when 'quality_holds'     then (select h.team_id from public.quality_holds h where h.id = p_entity)
    when 'teams'             then (select t.id from public.teams t where t.id = p_entity)
    when 'cases'             then (select c.assigned_team_id from public.cases c where c.id = p_entity)
    when 'matching_requests' then (select m.selected_team_id from public.matching_requests m where m.id = p_entity)
  end
$$;
revoke all on function private.audit_record_team(text, uuid) from public, anon, authenticated;

-- 4. Read record (AUD1-5) --------------------------------------------------------------------------------------------
create table if not exists public.audit_read_log (
  id              bigint generated always as identity primary key,
  read_at         timestamptz not null default private.now(),  -- ADR-081
  organization_id uuid references public.organizations (id),  -- null when the call returned no row
  reader_id       uuid not null,
  entity_type     text not null check (entity_type ~ '^[a-z_]{1,63}$'),
  entity_id       uuid not null,
  purpose         text not null check (purpose in ('compliance', 'billing', 'safety_review')),
  rows_returned   integer not null check (rows_returned >= 0)
);
create index if not exists audit_read_log_org_time on public.audit_read_log (organization_id, read_at desc);
alter table public.audit_read_log enable row level security;
revoke all on public.audit_read_log from public, anon, authenticated;
comment on table public.audit_read_log is
  'AUD1-5: one row per purpose read of the audit log. Append-only. Evidence of purpose, never a rating of the reader; '
  'not the DSV Art. 4 read log (D-3 gate i).';

create or replace function private.forbid_audit_read_log_change()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  raise exception 'audit_read_log is append-only' using errcode = '42501';
end;
$$;
revoke all on function private.forbid_audit_read_log_change() from public, anon, authenticated;

drop trigger if exists audit_read_log_no_update_delete on public.audit_read_log;
create trigger audit_read_log_no_update_delete
  before update or delete on public.audit_read_log
  for each row execute function private.forbid_audit_read_log_change();
drop trigger if exists audit_read_log_no_truncate on public.audit_read_log;
create trigger audit_read_log_no_truncate
  before truncate on public.audit_read_log
  for each statement execute function private.forbid_audit_read_log_change();

-- 5. The purpose reader (AUD1-3, AUD1-4) -----------------------------------------------------------------------------
create or replace function public.read_audit_record(p_entity_type text, p_entity_id uuid, p_purpose text)
returns table (
  occurred_at   timestamptz,
  actor_id      uuid,
  actor_role    text,
  command       text,
  changed       jsonb,
  withheld_keys text[],
  text_withheld boolean
)
language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid     uuid := (select auth.uid());
  team    uuid;
  in_team boolean;
  org     uuid;
  n       integer;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  perform private.assert_access_open();  -- LEAVE1-3: nothing for a person whose access ended
  if p_purpose is null or p_purpose not in ('compliance', 'billing', 'safety_review') then
    raise exception 'purpose must be compliance, billing or safety_review' using errcode = '22023';
  end if;
  if p_entity_type is null or p_entity_type !~ '^[a-z_]{1,63}$' or p_entity_id is null then
    raise exception 'one record (entity type and id) is required' using errcode = '22023';
  end if;

  team := private.audit_record_team(p_entity_type, p_entity_id);
  in_team := team is not null and private.is_team_member(team);

  return query
  select a.occurred_at, a.actor_id, a.actor_role, a.command,
         coalesce((select jsonb_object_agg(e.key, case when s.shown then e.value else 'null'::jsonb end)
                   from jsonb_each(a.changed) e
                   left join private.audit_value_classes vc on vc.table_name = a.table_name and vc.key = e.key
                   cross join lateral (select coalesce(vc.class = 'code' or (vc.class = 'free_text' and in_team), false)
                                              as shown) s), '{}'::jsonb),
         coalesce((select array_agg(e.key order by e.key)
                   from jsonb_each(a.changed) e
                   left join private.audit_value_classes vc on vc.table_name = a.table_name and vc.key = e.key
                   where not coalesce(vc.class = 'code' or (vc.class = 'free_text' and in_team), false)), '{}'::text[]),
         exists (select 1
                 from jsonb_each(a.changed) e
                 left join private.audit_value_classes vc on vc.table_name = a.table_name and vc.key = e.key
                 where not coalesce(vc.class = 'code' or (vc.class = 'free_text' and in_team), false))
  from public.audit_events a
  where a.table_name = p_entity_type
    and a.entity_id = p_entity_id
    and private.has_org_role(a.organization_id, array['admin'])
  order by a.occurred_at, a.id;
  get diagnostics n = row_count;

  -- AUD1-5: one row per call, also when nothing was returned (organisation then unknown: null).
  select min(a.organization_id::text)::uuid into org
  from public.audit_events a
  where a.table_name = p_entity_type and a.entity_id = p_entity_id
    and private.has_org_role(a.organization_id, array['admin']);
  insert into public.audit_read_log (organization_id, reader_id, entity_type, entity_id, purpose, rows_returned)
  values (org, uid, p_entity_type, p_entity_id, p_purpose, n);
end;
$$;
revoke all on function public.read_audit_record(text, uuid, text) from public, anon;
grant execute on function public.read_audit_record(text, uuid, text) to authenticated;
comment on function public.read_audit_record(text, uuid, text) is
  'AUD1-3/-4: audit rows of one record for an administrator of its organisation, for compliance, billing or '
  'safety_review only; free text withheld unless the administrator is an active member of the record''s team. '
  'Every call is recorded in audit_read_log.';

-- 6. Reader of the read record (AUD1-5): rows only, no per-person aggregate ------------------------------------------
create or replace function public.org_audit_read_log(p_organization_id uuid)
returns table (
  read_at       timestamptz,
  reader_id     uuid,
  entity_type   text,
  entity_id     uuid,
  purpose       text,
  rows_returned integer
)
language sql stable security definer set search_path = ''
as $$
  select l.read_at, l.reader_id, l.entity_type, l.entity_id, l.purpose, l.rows_returned
  from public.audit_read_log l
  where l.organization_id = p_organization_id
    and private.has_org_role(p_organization_id, array['admin'])
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3 (has_org_role already refuses her)
  order by l.read_at desc, l.id desc
$$;
revoke all on function public.org_audit_read_log(uuid) from public, anon;
grant execute on function public.org_audit_read_log(uuid) to authenticated;
comment on function public.org_audit_read_log(uuid) is
  'AUD1-5: an administrator reads her organisation''s purpose-read rows. No grouping, counting or ranking per reader.';
