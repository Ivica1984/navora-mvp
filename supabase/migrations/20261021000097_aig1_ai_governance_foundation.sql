-- AIG1 part (a): AI governance foundation in the database (ADR-120). PO brief docs/agents/briefs/AIG1.md (approved,
-- amended 2026-10-27 15:20 / 18:10, AIG1-11 2026-10-29 21:15, AIG1-12 2026-10-29 22:10). Stage 0 of D-35: synthetic
-- data only, no AI service. No clinical, legal or tariff rule: the threshold, minimum and window are written by the
-- administrator who switches an agent on (AIG1 ships no value); the one-by-one list is the Clinical Owner's (D-17 part 3,
-- G-1, empty until set); the only field classed `schedule` is the one `cra` confirmed on #555 (CGR-78).
--
-- Before (IMPLEMENTED, read in a database built from 0001-0096): no table, command or reader for machine proposals.
-- Now (IMPLEMENTED in this migration):
--   1. AIG1-1 register: `ai_agent_definitions` (key, name, level L/G/H, kind rule/ai, version, provider, region,
--      evaluation fixture and bar; written by migrations only) and `ai_agent_settings` per organisation (state off/on/
--      stopped, the written stop threshold, who switched it on and the version, provider and region at switch-on).
--      `set_agent_state` is the only writer: an organisation administrator, audited, idempotent. Refused with a stated
--      reason: kind `ai` (D-35 rule A, every environment), level G or H (D-34), no threshold (AIG1-8), no fixture
--      (AIG1-9).
--   2. AIG1-2 ledger: `ai_suggestions`, one row per proposed value (rows of one proposal share `proposal_id`): agent key
--      and version, team, case, target record, input references (table and id only, checked), proposed value or
--      `not_found`, time. Update, delete and truncate are refused for every role, the owner and service_role included.
--   3. AIG1-3/-4 provenance: `ai_confirmations`, append-only, one row per confirmed value (confirmed, corrected,
--      rejected, not_found) with confirmer and time. A value becomes record content only through `confirm_suggestion`
--      or `confirm_suggestions`, which run the consuming command's checks again per value (J3 for a visit's
--      responsible member). A `not_found` proposal is confirmed only as "nicht gefunden" and never writes a value.
--   4. AIG1-5 classes: `ai_agent_fields` (class `record` by default). `schedule` is accepted only for
--      care_visits.responsible_user_id with its brief and the `cra` reference; any other target, and every safety-alert,
--      care-plan, medical-order or assessment target, is refused. `ai_one_by_one_fields` is the Clinical Owner's list
--      (no command yet: G-1 OPEN). Bulk confirm only for schedule fields of level-L rule agents not on the list.
--   5. AIG1-6 scope: the synthetic test agent proposes only for a visit of a team the caller is an active member of;
--      otherwise 42501 and no ledger row.
--   6. AIG1-7 `agent_correction_rates(month)`: per agent, field, team and month; no person column; a cell with fewer
--      than three distinct confirmers is suppressed (ADR-120 answers the PO's small-team question per cell).
--   7. AIG1-8 stop: `private.aig1_check` stops an agent when a closed window crosses its threshold or when its
--      version, provider or region changed since the switch-on; `ai_agent_stops` keeps each stop; OPS1 exception
--      `agent_stopped` ("Assistent gestoppt", detail: the agent's name); a restart is a new audited switch-on.
--   8. AIG1-10 `agent_health(org)` for coordinators; AIG1-11: no grant on the ledger or confirmation tables for app
--      roles (stronger than column grants: every direct select is 42501); the confirmer is read per value through
--      `value_provenance(entity_type, entity_id, field)` and per record through `read_audit_record`.
--   9. AIG1-12 `agent_stop_lookback(stop)`: the records holding a value of that agent confirmed unchanged in the stop
--      window (or since the switch-on, for a version change); no person and no outcome column; record readers and
--      coordinators only; a line leaves once the value is confirmed again or corrected after the stop. AIG1-13 (po
--      23:15, `aia` AUT-23): a value on a look-back list (any decided value) is never confirmed in bulk; a listed value
--      the record no longer holds stays on the list as superseded with its date and is not counted as open in OPS1.
--  10. AIG1-9 synthetic test agent `aig1_test_primary_nurse` (kind rule, level L): proposes the case's primary nurse
--      for an unassigned visit; its pure rule `private.aig1_rule_primary_nurse` is evaluated by the fixture
--      `private.aig1_eval_aig1_test_primary_nurse()` (pgTAP 097 runs every agent's fixture against its bar).
-- Idempotent: `if not exists`, `create or replace`, `on conflict do nothing`, the OPS1 patch carries a marker.

-- 0. Patch helper (removed at the end) ------------------------------------------------------------------------------------
create or replace function private.aig1_patch(p_fn text, p_pairs text[], p_marker text)
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
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 3 loop
    n := (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]);
    if n <> p_pairs[i + 2]::integer then
      raise exception '0097 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0097 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.aig1_patch(text, text[], text) from public, anon, authenticated;

-- 1. Register (AIG1-1) ---------------------------------------------------------------------------------------------------
create table if not exists public.ai_agent_definitions (
  key      text primary key check (key ~ '^[a-z][a-z0-9_]{2,62}$'),
  name     text not null check (char_length(btrim(name)) between 2 and 80),
  level    text not null check (level in ('L', 'G', 'H')),
  kind     text not null check (kind in ('rule', 'ai')),
  version  text not null check (char_length(version) between 1 and 40),
  provider text check (provider is null or char_length(provider) between 1 and 80),
  region   text check (region is null or char_length(region) between 1 and 80),
  fixture  text check (fixture is null or fixture ~ '^aig1_eval_[a-z0-9_]{3,60}$'),
  eval_bar numeric(5, 2) check (eval_bar is null or eval_bar between 0 and 100),
  brief    text not null check (brief ~ '^[A-Z][A-Z0-9-]{1,15}$'),
  check ((kind = 'rule' and provider is null and region is null)
         or (kind = 'ai' and provider is not null and region is not null)),
  check ((fixture is null) = (eval_bar is null))
);
comment on table public.ai_agent_definitions is
  'AIG1-1: every NAVORA assistant (rule or AI), its level (D-34), version, provider and region (null for rule agents) '
  'and its evaluation fixture and bar (AIG1-9). Written by migrations only; read through agent_health.';

create table if not exists public.ai_agent_settings (
  id                 uuid not null default gen_random_uuid() unique,
  organization_id    uuid not null references public.organizations (id),
  agent_key          text not null references public.ai_agent_definitions (key),
  state              text not null default 'off' check (state in ('off', 'on', 'stopped')),
  stop_share         numeric(5, 2) check (stop_share is null or stop_share between 0 and 100),
  stop_min_proposals integer check (stop_min_proposals is null or stop_min_proposals between 1 and 100000),
  stop_window_days   integer check (stop_window_days is null or stop_window_days between 1 and 366),
  switched_on_by     uuid references auth.users (id),
  switched_on_at     timestamptz,
  on_version         text,
  on_provider        text,
  on_region          text,
  last_stop_id       uuid,
  updated_at         timestamptz not null default private.now(),
  primary key (organization_id, agent_key),
  check (state = 'off' or (stop_share is not null and stop_min_proposals is not null and stop_window_days is not null
                           and switched_on_by is not null and switched_on_at is not null and on_version is not null)),
  check (state <> 'stopped' or last_stop_id is not null)
);
comment on table public.ai_agent_settings is
  'AIG1-1/-8: per organisation: state (off, on, stopped), the stop threshold written by the administrator who switched '
  'the agent on (share in percent, minimum number of decided proposals, window in days), who switched it on and the '
  'version, provider and region at that moment. Written by set_agent_state and the stop check only.';

create table if not exists public.ai_agent_stops (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  organization_id uuid not null references public.organizations (id),
  agent_key       text not null references public.ai_agent_definitions (key),
  reason          text not null check (reason in ('threshold', 'version_changed')),
  window_from     timestamptz not null,
  window_to       timestamptz not null,
  decided         integer check (decided is null or decided >= 0),
  share           numeric(5, 2) check (share is null or share between 0 and 100),
  suggestion_seq  bigint not null default 0,     -- newest ledger row when the agent stopped
  confirmation_seq bigint not null default 0,    -- newest confirmation when the agent stopped
  created_at      timestamptz not null default private.now(),
  check (window_to >= window_from),
  check ((reason = 'threshold') = (decided is not null and share is not null))
);
comment on table public.ai_agent_stops is
  'AIG1-8/-12: one row per automatic stop: why (threshold or version, provider or region changed), the window that '
  'crossed the threshold or the period since the switch-on, the counts. No person column. Append-only.';

create table if not exists public.ai_agent_fields (
  agent_key     text not null references public.ai_agent_definitions (key),
  field         text not null check (field ~ '^[a-z][a-z0-9_]{1,62}$'),
  target_table  text not null check (target_table ~ '^[a-z_]{1,63}$'),
  target_column text not null check (target_column ~ '^[a-z_]{1,63}$'),
  class         text not null default 'record' check (class in ('schedule', 'record')),
  class_brief   text check (class_brief is null or class_brief ~ '^[A-Z][A-Z0-9-]{1,15}$'),
  class_cra_ref text check (class_cra_ref is null or char_length(class_cra_ref) between 3 and 120),
  primary key (agent_key, field),
  check (class = 'record' or (class_brief is not null and class_cra_ref is not null))
);
comment on table public.ai_agent_fields is
  'AIG1-5: every field an agent proposes and its class. record is the default; schedule only for the responsible '
  'member of a visit (care_visits.responsible_user_id), named by its brief and the cra confirmation (CGR-78).';

create table if not exists public.ai_one_by_one_fields (
  id              uuid not null default gen_random_uuid() unique,
  organization_id uuid not null references public.organizations (id),
  agent_key       text not null,
  field           text not null,
  added_at        timestamptz not null default private.now(),
  primary key (organization_id, agent_key, field),
  foreign key (agent_key, field) references public.ai_agent_fields (agent_key, field)
);
comment on table public.ai_one_by_one_fields is
  'AIG1-5: the organisation''s one-by-one list, owned by the Clinical Owner (D-17 part 3, G-1). A field on it is never '
  'confirmed in bulk, whatever its class. Empty until set; no command until the Clinical Owner role exists (OPEN).';

-- 2. Ledger and confirmations (AIG1-2, AIG1-3, AIG1-4) --------------------------------------------------------------------
create or replace function private.aig1_refs_ok(p_refs jsonb)
returns boolean language sql immutable set search_path = ''
as $$
  select jsonb_typeof(p_refs) = 'array' and jsonb_array_length(p_refs) between 1 and 50
     and not exists (
       select 1 from jsonb_array_elements(p_refs) e
       where jsonb_typeof(e) <> 'object'
          or (select array_agg(k order by k) from jsonb_object_keys(e) k) <> array['id', 'table']
          or coalesce(e ->> 'table', '') !~ '^[a-z_]{1,63}$'
          or coalesce(e ->> 'id', '') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
$$;
revoke all on function private.aig1_refs_ok(jsonb) from public, anon, authenticated;
comment on function private.aig1_refs_ok(jsonb) is
  'AIG1-2: input references are identifiers of the rows read ({table, id}), never a copy of their content.';

create table if not exists public.ai_suggestions (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  proposal_id     uuid not null,
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id),
  case_id         uuid references public.cases (id),
  agent_key       text not null,
  agent_version   text not null,
  field           text not null,
  entity_type     text not null check (entity_type ~ '^[a-z_]{1,63}$'),
  entity_id       uuid not null,
  input_refs      jsonb not null check (private.aig1_refs_ok(input_refs)),
  not_found       boolean not null default false,
  proposed_value  jsonb,
  created_at      timestamptz not null default private.now(),
  foreign key (agent_key, field) references public.ai_agent_fields (agent_key, field),
  check (not_found = (proposed_value is null))
);
create index if not exists ai_suggestions_entity_idx on public.ai_suggestions (entity_type, entity_id, field, seq);
create index if not exists ai_suggestions_agent_idx on public.ai_suggestions (organization_id, agent_key, created_at);
create index if not exists ai_suggestions_team_idx on public.ai_suggestions (team_id, created_at);
comment on table public.ai_suggestions is
  'AIG1-2: the suggestion ledger, one row per proposed value. Append-only for every role (trigger); kept for the D-4 '
  'final period (no deletion path). No grant to app roles; read through the AIG1 functions.';

create table if not exists public.ai_confirmations (
  id              uuid primary key default gen_random_uuid(),
  seq             bigint generated always as identity unique,
  suggestion_id   uuid not null references public.ai_suggestions (id),
  organization_id uuid not null references public.organizations (id),
  team_id         uuid not null references public.teams (id),
  outcome         text not null check (outcome in ('confirmed', 'corrected', 'rejected', 'not_found')),
  final_value     jsonb,
  bulk            boolean not null default false,
  confirmed_by    uuid not null references auth.users (id),
  confirmed_at    timestamptz not null default private.now(),
  check ((outcome in ('confirmed', 'corrected')) = (final_value is not null)),
  check (not bulk or outcome = 'confirmed')
);
create index if not exists ai_confirmations_suggestion_idx on public.ai_confirmations (suggestion_id, seq);
comment on table public.ai_confirmations is
  'AIG1-3/-11: one row per value a named person confirmed (confirmed, corrected, rejected, not_found), with confirmer '
  'and time. Append-only. No grant to app roles: the confirmer is read per value (value_provenance) or per record '
  '(read_audit_record), never listed per person.';

-- No table read or write for app roles (AIG1-11 (1)); RLS on with no policy as a second wall.
do $$
declare t text;
begin
  foreach t in array array['ai_agent_definitions', 'ai_agent_settings', 'ai_agent_stops', 'ai_agent_fields',
                           'ai_one_by_one_fields', 'ai_suggestions', 'ai_confirmations'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
  end loop;
end;
$$;

create or replace function private.aig1_append_only()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception '% is append-only (AIG1-2)', tg_table_name using errcode = '42501';
end;
$$;
revoke all on function private.aig1_append_only() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['ai_suggestions', 'ai_confirmations', 'ai_agent_stops'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_append_only', t);
    execute format('create trigger %I before update or delete on public.%I for each row '
                   'execute function private.aig1_append_only()', t || '_append_only', t);
    execute format('drop trigger if exists %I on public.%I', t || '_no_truncate', t);
    execute format('create trigger %I before truncate on public.%I for each statement '
                   'execute function private.aig1_append_only()', t || '_no_truncate', t);
  end loop;
end;
$$;

-- AIG1-5 (e): the class rule, enforced on every write of the field register.
create or replace function private.aig1_never_schedule(p_table text, p_column text)
returns text language sql immutable set search_path = ''
as $$
  select case
    when p_table ~ '^(case_)?safety_alert' then 'safety_alert'                                -- D-17 (both tables)
    when p_table = 'care_plan_items' then 'care_plan'
    when p_table = 'cases' and p_column like 'medical_order%' then 'medical_order'
    when p_table in ('case_gp_notices') then 'medical_order'
    when p_table in ('assessment_records', 'needs_assessments') then 'assessment'              -- ASM1 (not built)
    when p_table = 'care_visits' and p_column in ('visit_date', 'time_start', 'time_end', 'team_id', 'cover_team_id',
                                                  'planned_minutes_a', 'planned_minutes_b', 'planned_minutes_c',
                                                  'is_needs_assessment', 'services_provided')
      then 'visit_slot'                                                                         -- CGR-78 (a)
  end
$$;
revoke all on function private.aig1_never_schedule(text, text) from public, anon, authenticated;
comment on function private.aig1_never_schedule(text, text) is
  'AIG1-5 (e): targets that can never be classed schedule: safety alerts, care plan, medical order, assessment record '
  '(ASM1), and a visit''s date, time, team, minutes or category (CGR-78 (a)).';

create or replace function private.aig1_guard_field_class()
returns trigger language plpgsql set search_path = ''
as $$
declare why text;
begin
  if new.class = 'schedule' then
    why := private.aig1_never_schedule(new.target_table, new.target_column);
    if why is not null then
      raise exception 'a % field can never be classed schedule (AIG1-5)', why using errcode = '42501';
    end if;
    if not (new.target_table = 'care_visits' and new.target_column = 'responsible_user_id') then
      raise exception 'schedule means only the responsible member of a visit (AIG1-5, CGR-78 (a))' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.aig1_guard_field_class() from public, anon, authenticated;
drop trigger if exists ai_agent_fields_class_guard on public.ai_agent_fields;
create trigger ai_agent_fields_class_guard before insert or update on public.ai_agent_fields
  for each row execute function private.aig1_guard_field_class();

-- Audit: settings by the administrator's command; ledger and confirmations by the person who called; the one-by-one
-- list. Stops are written by the system (no actor) through private.aig1_audit_system.
drop trigger if exists audit_ai_agent_settings on public.ai_agent_settings;
create trigger audit_ai_agent_settings after insert or update on public.ai_agent_settings
  for each row when (new.state <> 'stopped')
  execute function private.write_audit_event('agent_key', 'state', 'stop_share', 'stop_min_proposals',
                                             'stop_window_days', 'switched_on_by', 'on_version', 'on_provider', 'on_region');
drop trigger if exists audit_ai_suggestions on public.ai_suggestions;
create trigger audit_ai_suggestions after insert on public.ai_suggestions
  for each row execute function private.write_audit_event('proposal_id', 'agent_key', 'agent_version', 'field',
                                                          'entity_type', 'entity_id', 'not_found');
drop trigger if exists audit_ai_confirmations on public.ai_confirmations;
create trigger audit_ai_confirmations after insert on public.ai_confirmations
  for each row execute function private.write_audit_event('suggestion_id', 'outcome', 'final_value', 'bulk');
drop trigger if exists audit_ai_one_by_one_fields on public.ai_one_by_one_fields;
create trigger audit_ai_one_by_one_fields after insert on public.ai_one_by_one_fields
  for each row execute function private.write_audit_event('agent_key', 'field');

create or replace function private.aig1_audit_system(p_org uuid, p_table text, p_entity uuid, p_changed jsonb)
returns void language sql security definer set search_path = ''
as $$
  insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, changed)
  values (p_org, null, 'system', p_table, p_entity, 'aig1_stop', coalesce(p_changed, '{}'::jsonb));
$$;
revoke all on function private.aig1_audit_system(uuid, text, uuid, jsonb) from public, anon, authenticated;

insert into private.audit_value_classes (table_name, key, class) values
  ('ai_agent_settings',    'agent_key',          'code'),
  ('ai_agent_settings',    'state',              'code'),
  ('ai_agent_settings',    'stop_share',         'code'),
  ('ai_agent_settings',    'stop_min_proposals', 'code'),
  ('ai_agent_settings',    'stop_window_days',   'code'),
  ('ai_agent_settings',    'switched_on_by',     'code'),
  ('ai_agent_settings',    'on_version',         'code'),
  ('ai_agent_settings',    'on_provider',        'code'),
  ('ai_agent_settings',    'on_region',          'code'),
  ('ai_agent_settings',    'stop_id',            'code'),
  ('ai_agent_settings',    'reason',             'code'),
  ('ai_suggestions',       'proposal_id',        'code'),
  ('ai_suggestions',       'agent_key',          'code'),
  ('ai_suggestions',       'agent_version',      'code'),
  ('ai_suggestions',       'field',              'code'),
  ('ai_suggestions',       'entity_type',        'code'),
  ('ai_suggestions',       'entity_id',          'code'),
  ('ai_suggestions',       'not_found',          'code'),
  ('ai_confirmations',     'suggestion_id',      'code'),
  ('ai_confirmations',     'outcome',            'code'),
  ('ai_confirmations',     'final_value',        'code'),  -- a value the commands set (an id for the schedule field)
  ('ai_confirmations',     'bulk',               'code'),
  ('ai_one_by_one_fields', 'agent_key',          'code'),
  ('ai_one_by_one_fields', 'field',              'code')
on conflict (table_name, key) do nothing;

-- 3. The synthetic test agent (AIG1-9) -------------------------------------------------------------------------------------
insert into public.ai_agent_definitions (key, name, level, kind, version, provider, region, fixture, eval_bar, brief)
values ('aig1_test_primary_nurse', 'Testassistent Bezugspflege', 'L', 'rule', '1', null, null,
        'aig1_eval_aig1_test_primary_nurse', 100, 'AIG1')
on conflict (key) do nothing;
insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class, class_brief, class_cra_ref)
values ('aig1_test_primary_nurse', 'responsible_user_id', 'care_visits', 'responsible_user_id', 'schedule', 'AIG1',
        'cra 2026-10-27 17:35 #555, CGR-78')
on conflict (agent_key, field) do nothing;

-- The rule, pure: the case's primary nurse, or not_found (null).
create or replace function private.aig1_rule_primary_nurse(p_primary_nurse uuid)
returns jsonb language sql immutable set search_path = ''
as $$ select case when p_primary_nurse is null then null else to_jsonb(p_primary_nurse::text) end $$;
revoke all on function private.aig1_rule_primary_nurse(uuid) from public, anon, authenticated;

-- Its fixture: synthetic inputs and expected values (AIG1-9). Pure; reads no table.
create or replace function private.aig1_eval_aig1_test_primary_nurse()
returns table (fixture_case text, expected jsonb, actual jsonb)
language sql immutable set search_path = ''
as $$
  select f.label, f.expected, private.aig1_rule_primary_nurse(f.primary_nurse)
  from (values
    ('primary nurse recorded', 'a0970000-0000-4000-8000-000000000001'::uuid,
     to_jsonb('a0970000-0000-4000-8000-000000000001'::text)),
    ('another primary nurse', 'a0970000-0000-4000-8000-000000000002'::uuid,
     to_jsonb('a0970000-0000-4000-8000-000000000002'::text)),
    ('no primary nurse: not_found', null::uuid, null::jsonb)
  ) f(label, primary_nurse, expected)
$$;
revoke all on function private.aig1_eval_aig1_test_primary_nurse() from public, anon, authenticated;
comment on function private.aig1_eval_aig1_test_primary_nurse() is
  'AIG1-9: evaluation fixture of the synthetic test agent (synthetic ids only). pgTAP 097 runs every agent''s fixture '
  'and fails below its eval_bar.';

-- 4. State, windows and the stop rule (AIG1-8) -----------------------------------------------------------------------------
-- Decided proposals of one agent in one organisation created in [p_from, p_to): the newest confirmation of each counts.
-- Correction share = (corrected + rejected) / (confirmed + corrected + rejected); not_found and open proposals are not
-- decided (ADR-120).
create or replace function private.aig1_window_stats(p_org uuid, p_key text, p_from timestamptz, p_to timestamptz)
returns table (decided integer, corrections integer, share numeric)
language sql stable security definer set search_path = ''
as $$
  with latest as (
    select (select c.outcome from public.ai_confirmations c where c.suggestion_id = s.id order by c.seq desc limit 1) as outcome
    from public.ai_suggestions s
    where s.organization_id = p_org and s.agent_key = p_key and s.created_at >= p_from and s.created_at < p_to
  )
  select count(*) filter (where outcome in ('confirmed', 'corrected', 'rejected'))::int,
         count(*) filter (where outcome in ('corrected', 'rejected'))::int,
         case when count(*) filter (where outcome in ('confirmed', 'corrected', 'rejected')) = 0 then null
              else round(100.0 * count(*) filter (where outcome in ('corrected', 'rejected'))
                         / count(*) filter (where outcome in ('confirmed', 'corrected', 'rejected')), 2) end
  from latest
$$;
revoke all on function private.aig1_window_stats(uuid, text, timestamptz, timestamptz) from public, anon, authenticated;

create or replace function private.aig1_stop(p_org uuid, p_key text, p_reason text, p_from timestamptz, p_to timestamptz,
                                             p_decided integer, p_share numeric)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare sid uuid;
begin
  insert into public.ai_agent_stops (organization_id, agent_key, reason, window_from, window_to, decided, share,
                                     suggestion_seq, confirmation_seq)
  values (p_org, p_key, p_reason, p_from, p_to, p_decided, p_share,
          coalesce((select max(x.seq) from public.ai_suggestions x), 0),
          coalesce((select max(y.seq) from public.ai_confirmations y), 0))
  returning id into sid;
  update public.ai_agent_settings
  set state = 'stopped', last_stop_id = sid, updated_at = private.now()
  where organization_id = p_org and agent_key = p_key;
  perform private.aig1_audit_system(p_org, 'ai_agent_settings',
    (select s.id from public.ai_agent_settings s where s.organization_id = p_org and s.agent_key = p_key),
    jsonb_build_object('state', jsonb_build_object('old', 'on', 'new', 'stopped'),
                       'stop_id', jsonb_build_object('old', null, 'new', sid),
                       'reason', jsonb_build_object('old', null, 'new', p_reason)));
  return sid;
end;
$$;
revoke all on function private.aig1_stop(uuid, text, text, timestamptz, timestamptz, integer, numeric)
  from public, anon, authenticated;

-- Evaluates one agent for one organisation and returns its state after the check ('off' when no row).
create or replace function private.aig1_check(p_org uuid, p_key text)
returns text language plpgsql security definer set search_path = ''
as $$
declare
  s   public.ai_agent_settings%rowtype;
  d   public.ai_agent_definitions%rowtype;
  w   interval;
  k   integer;
  ws  timestamptz;
  st  record;
begin
  select * into s from public.ai_agent_settings x where x.organization_id = p_org and x.agent_key = p_key for update;
  if not found then
    return 'off';
  end if;
  if s.state <> 'on' then
    return s.state;
  end if;
  select * into d from public.ai_agent_definitions x where x.key = p_key;
  -- Version, provider or region changed without a new switch-on: stop; look back since the switch-on.
  if d.version is distinct from s.on_version or d.provider is distinct from s.on_provider
     or d.region is distinct from s.on_region then
    perform private.aig1_stop(p_org, p_key, 'version_changed', s.switched_on_at, private.now(), null, null);
    return 'stopped';
  end if;
  -- Closed windows since the switch-on, oldest first; the first that crosses the threshold stops the agent.
  w := make_interval(days => s.stop_window_days);
  k := 0;
  loop
    ws := s.switched_on_at + k * w;
    exit when ws + w > private.now();
    select * into st from private.aig1_window_stats(p_org, p_key, ws, ws + w);
    if st.decided >= s.stop_min_proposals and st.share > s.stop_share then
      perform private.aig1_stop(p_org, p_key, 'threshold', ws, ws + w, st.decided, st.share);
      return 'stopped';
    end if;
    k := k + 1;
  end loop;
  return 'on';
end;
$$;
revoke all on function private.aig1_check(uuid, text) from public, anon, authenticated;
comment on function private.aig1_check(uuid, text) is
  'AIG1-8: stops an agent that is on when a closed window crosses its written threshold (share above stop_share over at '
  'least stop_min_proposals decided proposals) or when its version, provider or region changed since the switch-on.';

-- Return: {result: ok | unchanged | duplicate | rejected | refused, reason}
create or replace function public.set_agent_state(p_organization_id uuid, p_agent_key text, p_on boolean,
                                                  p_stop_share numeric, p_stop_min_proposals integer,
                                                  p_stop_window_days integer, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  d   public.ai_agent_definitions%rowtype;
  s   public.ai_agent_settings%rowtype;
  had boolean;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_on is null then
    raise exception 'on is required' using errcode = '22023';
  end if;
  if private.begin_command('set_agent_state', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if not private.is_org_admin(p_organization_id) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  select * into d from public.ai_agent_definitions x where x.key = p_agent_key;
  if not found then
    return jsonb_build_object('result', private.end_command('rejected'), 'reason', 'unknown_agent');
  end if;
  select * into s from public.ai_agent_settings x
  where x.organization_id = p_organization_id and x.agent_key = p_agent_key for update;
  had := found;

  if not p_on then
    if not had or s.state = 'off' then
      return jsonb_build_object('result', private.end_command('unchanged'));
    end if;
    update public.ai_agent_settings set state = 'off', updated_at = private.now() where id = s.id;
    return jsonb_build_object('result', private.end_command('ok'));
  end if;

  -- Switch-on refusals, each with its stated reason.
  if d.kind = 'ai' then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'ai_not_allowed',
      'detail', 'D-35 Regel A: Kein KI-Dienst in irgendeiner Umgebung, bis der Inhaber Stufe 1 freigibt.');
  end if;
  if d.level in ('G', 'H') then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'level_not_allowed',
      'detail', 'D-34: Assistenten der Stufe G oder H gehören zum klinischen Modul und sind hier nicht einschaltbar.');
  end if;
  if p_stop_share is null or p_stop_share not between 0 and 100
     or p_stop_min_proposals is null or p_stop_min_proposals not between 1 and 100000
     or p_stop_window_days is null or p_stop_window_days not between 1 and 366 then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'threshold_missing',
      'detail', 'AIG1-8: Ohne schriftliche Stoppschwelle (Anteil, Mindestzahl, Zeitfenster) wird nicht eingeschaltet.');
  end if;
  if d.fixture is null or to_regprocedure('private.' || d.fixture || '()') is null then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'no_fixture',
      'detail', 'AIG1-9: Ohne Testfälle wird nicht eingeschaltet.');
  end if;
  if had and s.state = 'on' and s.stop_share = p_stop_share and s.stop_min_proposals = p_stop_min_proposals
     and s.stop_window_days = p_stop_window_days and s.on_version = d.version then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;

  insert into public.ai_agent_settings (organization_id, agent_key, state, stop_share, stop_min_proposals,
                                        stop_window_days, switched_on_by, switched_on_at, on_version, on_provider,
                                        on_region, last_stop_id, updated_at)
  values (p_organization_id, p_agent_key, 'on', p_stop_share, p_stop_min_proposals, p_stop_window_days, uid,
          private.now(), d.version, d.provider, d.region, null, private.now())
  on conflict (organization_id, agent_key) do update
    set state = 'on', stop_share = excluded.stop_share, stop_min_proposals = excluded.stop_min_proposals,
        stop_window_days = excluded.stop_window_days, switched_on_by = excluded.switched_on_by,
        switched_on_at = excluded.switched_on_at, on_version = excluded.on_version, on_provider = excluded.on_provider,
        on_region = excluded.on_region, last_stop_id = null, updated_at = excluded.updated_at;
  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.set_agent_state(uuid, text, boolean, numeric, integer, integer, uuid) from public, anon;
grant execute on function public.set_agent_state(uuid, text, boolean, numeric, integer, integer, uuid) to authenticated;
comment on function public.set_agent_state(uuid, text, boolean, numeric, integer, integer, uuid) is
  'AIG1-1/-8: an organisation administrator switches an agent on (with its written stop threshold) or off. Audited, '
  'idempotent. Refused with a stated reason: kind ai (D-35 rule A), level G/H (D-34), no threshold, no fixture. A '
  'restart after a stop is a new switch-on.';

-- 5. Proposing (AIG1-2, AIG1-4, AIG1-6): the synthetic test agent ----------------------------------------------------------
-- Return: {result: ok | duplicate | rejected | agent_off | agent_stopped | not_applicable, suggestion_id, not_found}
create or replace function public.propose_visit_responsible(p_visit_id uuid, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  v     public.care_visits%rowtype;
  pn    uuid;
  val   jsonb;
  st    text;
  sid   uuid;
  agent constant text := 'aig1_test_primary_nurse';
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if private.begin_command('propose_visit_responsible', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  select * into v from public.care_visits x where x.id = p_visit_id;
  -- AIG1-6: computed only with the caller's own access (an active member of the visit's team, as RLS2/RLS3).
  if not found or not private.is_org_member(v.organization_id) or not private.is_team_member(v.team_id) then
    raise exception 'this visit is outside your access (AIG1-6)' using errcode = '42501';
  end if;
  st := private.aig1_check(v.organization_id, agent);
  if st <> 'on' then
    return jsonb_build_object('result', private.end_command(case st when 'stopped' then 'agent_stopped' else 'agent_off' end));
  end if;
  if v.responsible_user_id is not null or v.status <> 'planned' or v.suspended_at is not null or v.covered_by is not null
     or v.visit_date < (private.at_zurich(private.now()))::date then
    return jsonb_build_object('result', private.end_command('not_applicable'));
  end if;
  select c.primary_nurse_id into pn from public.cases c where c.id = v.case_id;
  val := private.aig1_rule_primary_nurse(pn);
  insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field,
                                     entity_type, entity_id, input_refs, not_found, proposed_value)
  values (gen_random_uuid(), v.organization_id, v.team_id, v.case_id, agent,
          (select d.version from public.ai_agent_definitions d where d.key = agent), 'responsible_user_id',
          'care_visits', v.id,
          jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', v.id),
                            jsonb_build_object('table', 'cases', 'id', v.case_id)),
          val is null, val)
  returning id into sid;
  return jsonb_build_object('result', private.end_command('ok'), 'suggestion_id', sid, 'not_found', val is null);
end;
$$;
revoke all on function public.propose_visit_responsible(uuid, uuid) from public, anon;
grant execute on function public.propose_visit_responsible(uuid, uuid) to authenticated;
comment on function public.propose_visit_responsible(uuid, uuid) is
  'AIG1-9 synthetic test agent (rule, level L): proposes the case''s primary nurse as responsible member of an '
  'unassigned visit, or not_found. Only for a visit of a team the caller is an active member of (AIG1-6); writes a '
  'ledger row, never the visit.';

-- 6. Applying a confirmed value: the consuming command's checks per value (J3 for the visit's responsible member) -------
-- p_expected: the value the record must still hold for a change (null for a first assignment). Result code.
create or replace function private.aig1_apply_visit_responsible(p_visit_id uuid, p_user uuid, p_expected uuid, p_actor uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare v public.care_visits%rowtype;
begin
  select * into v from public.care_visits x where x.id = p_visit_id for update;
  if not found then
    return 'not_open';
  end if;
  if v.responsible_user_id is not distinct from p_user then
    return 'ok';                                          -- the record already holds this value (a re-confirmation)
  end if;
  if v.responsible_user_id is distinct from p_expected then
    return 'already_taken';                               -- stale proposal: someone assigned the visit meanwhile
  end if;
  if v.status <> 'planned' or v.suspended_at is not null or v.covered_by is not null
     or v.visit_date < (private.at_zurich(private.now()))::date then
    return 'not_open';
  end if;
  if not private.may_perform_visit(v.team_id, p_user, v.planned_minutes_b, v.is_needs_assessment) then
    return 'not_qualified';                              -- membership, access, qualification, RN for B / assessment
  end if;
  if not private.adm2_in_contract(v.organization_id, p_user, v.visit_date) then
    return 'outside_contract';
  end if;
  if private.member_absent_during(v.team_id, p_user, lower(private.visit_interval(v)), upper(private.visit_interval(v))) then
    return 'absent';
  end if;
  update public.care_visits set responsible_user_id = p_user where id = v.id;
  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  values (v.organization_id, v.id, v.case_id, v.team_id, 'taken',
          private.visit_slot_json(v) || jsonb_build_object('responsible_id', v.responsible_user_id),
          private.visit_slot_json(v) || jsonb_build_object('responsible_id', p_user),
          'Bestätigter Vorschlag (AIG1)', p_actor);
  return 'ok';
end;
$$;
revoke all on function private.aig1_apply_visit_responsible(uuid, uuid, uuid, uuid) from public, anon, authenticated;

create or replace function private.aig1_apply(p_s public.ai_suggestions, p_value jsonb, p_actor uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  f    public.ai_agent_fields%rowtype;
  prev jsonb;
  u    uuid;
begin
  select * into f from public.ai_agent_fields x where x.agent_key = p_s.agent_key and x.field = p_s.field;
  -- The value the record holds from this suggestion's last applied confirmation (a re-check may replace only that).
  select c.final_value into prev from public.ai_confirmations c
  where c.suggestion_id = p_s.id and c.outcome in ('confirmed', 'corrected') order by c.seq desc limit 1;
  if f.target_table = 'care_visits' and f.target_column = 'responsible_user_id' and p_s.entity_type = 'care_visits' then
    begin
      u := (p_value #>> '{}')::uuid;
    exception when invalid_text_representation then
      raise exception 'the value must be a member id' using errcode = '22023';
    end;
    return private.aig1_apply_visit_responsible(p_s.entity_id, u, (prev #>> '{}')::uuid, p_actor);
  end if;
  raise exception 'no consuming command for %.% (AIG1-3)', f.target_table, f.target_column using errcode = '0A000';
end;
$$;
revoke all on function private.aig1_apply(public.ai_suggestions, jsonb, uuid) from public, anon, authenticated;

-- 7. Confirming one value (AIG1-3, AIG1-4) ---------------------------------------------------------------------------------
-- p_outcome: confirmed (value as proposed) | corrected (p_value, hers) | rejected | not_found (only for a not_found
-- proposal: "nicht gefunden"). Return {result: ok | duplicate | rejected | refused, reason}.
create or replace function public.confirm_suggestion(p_suggestion_id uuid, p_outcome text, p_value jsonb,
                                                     p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  s   public.ai_suggestions%rowtype;
  val jsonb;
  r   text;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_outcome is null or p_outcome not in ('confirmed', 'corrected', 'rejected', 'not_found') then
    raise exception 'outcome must be confirmed, corrected, rejected or not_found' using errcode = '22023';
  end if;
  if private.begin_command('confirm_suggestion', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  select * into s from public.ai_suggestions x where x.id = p_suggestion_id;
  if not found or not private.is_org_member(s.organization_id) or not private.is_team_member(s.team_id) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  -- AIG1-4: a not_found proposal is confirmed only as "nicht gefunden", never turned into a value or an empty value.
  if s.not_found then
    if p_outcome <> 'not_found' or p_value is not null then
      raise exception '"nicht gefunden" is confirmed only as "nicht gefunden" (AIG1-4)' using errcode = '22023';
    end if;
    insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, confirmed_by)
    values (s.id, s.organization_id, s.team_id, 'not_found', null, uid);
    return jsonb_build_object('result', private.end_command('ok'));
  end if;
  if p_outcome = 'not_found' then
    raise exception 'the agent proposed a value; confirm, correct or reject it' using errcode = '22023';
  end if;
  if p_outcome = 'rejected' then
    if p_value is not null then
      raise exception 'a rejection carries no value' using errcode = '22023';
    end if;
    insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, confirmed_by)
    values (s.id, s.organization_id, s.team_id, 'rejected', null, uid);
    return jsonb_build_object('result', private.end_command('ok'));
  end if;
  if p_outcome = 'confirmed' then
    if p_value is not null and p_value is distinct from s.proposed_value then
      raise exception 'a changed value is a correction' using errcode = '22023';
    end if;
    val := s.proposed_value;
  else
    if p_value is null or jsonb_typeof(p_value) = 'null' or p_value #>> '{}' = '' then
      raise exception 'a correction needs the value (never an empty one)' using errcode = '22023';
    end if;
    if p_value = s.proposed_value then
      raise exception 'an unchanged value is confirmed, not corrected' using errcode = '22023';
    end if;
    val := p_value;
  end if;
  r := private.aig1_apply(s, val, uid);
  if r <> 'ok' then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', r);
  end if;
  insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, confirmed_by)
  values (s.id, s.organization_id, s.team_id, p_outcome, val, uid);
  return jsonb_build_object('result', private.end_command('ok'));
end;
$$;
revoke all on function public.confirm_suggestion(uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.confirm_suggestion(uuid, text, jsonb, uuid) to authenticated;
comment on function public.confirm_suggestion(uuid, text, jsonb, uuid) is
  'AIG1-3/-4: a named team member confirms, corrects or rejects ONE proposed value; the consuming command''s checks run '
  'again (J3); a not_found proposal is confirmed only as "nicht gefunden". One audited confirmation row per call.';

-- 8. Bulk confirm of a ticked list (AIG1-5) --------------------------------------------------------------------------------
-- Return {result: ok | duplicate | rejected, confirmed, refused: [{suggestion_id, reason}]}. The whole list is refused
-- (42501) when one value is not eligible for bulk; a value the consuming command refuses is returned with its reason and
-- stays unconfirmed (PLAN3-9).
create or replace function public.confirm_suggestions(p_suggestion_ids uuid[], p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  s    public.ai_suggestions%rowtype;
  i    uuid;
  n    integer := 0;
  bad  jsonb := '[]'::jsonb;
  r    text;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_suggestion_ids is null or cardinality(p_suggestion_ids) = 0 or cardinality(p_suggestion_ids) > 200
     or (select count(distinct x) from unnest(p_suggestion_ids) x) <> cardinality(p_suggestion_ids)
     or array_position(p_suggestion_ids, null) is not null then
    raise exception 'a ticked list of 1 to 200 distinct values is required' using errcode = '22023';
  end if;
  if private.begin_command('confirm_suggestions', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  -- Every value must be the caller's to confirm and eligible for bulk; otherwise nothing is confirmed.
  foreach i in array p_suggestion_ids loop
    select * into s from public.ai_suggestions x where x.id = i;
    if not found or not private.is_org_member(s.organization_id) or not private.is_team_member(s.team_id) then
      return jsonb_build_object('result', private.end_command('rejected'));
    end if;
    if not exists (select 1 from public.ai_agent_fields f where f.agent_key = s.agent_key and f.field = s.field
                   and f.class = 'schedule') then
      raise exception 'bulk confirm refused: % is a record field, confirm it one by one (AIG1-5)', s.field
        using errcode = '42501';
    end if;
    if not exists (select 1 from public.ai_agent_definitions d where d.key = s.agent_key and d.kind = 'rule'
                   and d.level = 'L') then
      raise exception 'bulk confirm refused: only values of level-L rule agents (AIG1-5)' using errcode = '42501';
    end if;
    if exists (select 1 from public.ai_one_by_one_fields o where o.organization_id = s.organization_id
               and o.agent_key = s.agent_key and o.field = s.field) then
      raise exception 'bulk confirm refused: % is on the one-by-one list (AIG1-5, D-17)', s.field using errcode = '42501';
    end if;
    if s.not_found then
      raise exception 'bulk confirm refused: "nicht gefunden" is confirmed one by one (AIG1-4)' using errcode = '42501';
    end if;
    if exists (select 1 from public.ai_confirmations c where c.suggestion_id = s.id) then
      raise exception 'bulk confirm refused: a value already decided (a look-back line included) is confirmed one by one (AIG1-13)'
        using errcode = '42501';
    end if;
    if private.aig1_check(s.organization_id, s.agent_key) <> 'on' then
      raise exception 'bulk confirm refused: the agent is not on; confirm one by one (ADR-120)' using errcode = '42501';
    end if;
  end loop;
  foreach i in array p_suggestion_ids loop
    select * into s from public.ai_suggestions x where x.id = i;
    r := private.aig1_apply(s, s.proposed_value, uid);
    if r <> 'ok' then
      bad := bad || jsonb_build_array(jsonb_build_object('suggestion_id', s.id, 'reason', r));
      continue;
    end if;
    insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, bulk, confirmed_by)
    values (s.id, s.organization_id, s.team_id, 'confirmed', s.proposed_value, true, uid);
    n := n + 1;
  end loop;
  if n = 0 then
    -- Nothing was written, so record the call for idempotency (no value, no person beyond the caller's own audit row).
    perform private.audit_command(s.organization_id, 'ai_confirmations', s.id, jsonb_build_object('bulk', true));
  end if;
  return jsonb_build_object('result', private.end_command('ok'), 'confirmed', n, 'refused', bad);
end;
$$;
revoke all on function public.confirm_suggestions(uuid[], uuid) from public, anon;
grant execute on function public.confirm_suggestions(uuid[], uuid) to authenticated;
comment on function public.confirm_suggestions(uuid[], uuid) is
  'AIG1-5: confirms a ticked list unchanged, only when every value is a schedule field of a level-L rule agent that is '
  'on and not on the one-by-one list; one confirmation row per value; J3 runs per value and a refused value is '
  'returned with its reason.';

-- 9. Readers -------------------------------------------------------------------------------------------------------------
-- 9a. Open proposals of the caller's team (confirm screen): no confirmer, nothing decided.
create or replace function public.open_suggestions(p_team_id uuid)
returns table (suggestion_id uuid, agent_key text, agent_name text, field text, entity_type text, entity_id uuid,
               visit_date date, time_start time, not_found boolean, proposed_value jsonb, proposed_name text,
               bulk_allowed boolean, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select s.id, s.agent_key, d.name, s.field, s.entity_type, s.entity_id, v.visit_date, v.time_start, s.not_found,
         s.proposed_value,
         case when s.field = 'responsible_user_id' and not s.not_found
              then private.member_name(s.organization_id, (s.proposed_value #>> '{}')::uuid) end,
         f.class = 'schedule' and d.kind = 'rule' and d.level = 'L' and not s.not_found
           and not exists (select 1 from public.ai_one_by_one_fields o where o.organization_id = s.organization_id
                           and o.agent_key = s.agent_key and o.field = s.field),
         s.created_at
  from public.ai_suggestions s
  join public.ai_agent_definitions d on d.key = s.agent_key
  join public.ai_agent_fields f on f.agent_key = s.agent_key and f.field = s.field
  left join public.care_visits v on s.entity_type = 'care_visits' and v.id = s.entity_id
  where s.team_id = p_team_id
    and not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(s.organization_id) and private.is_team_member(s.team_id)
    and not exists (select 1 from public.ai_confirmations c where c.suggestion_id = s.id)
  order by v.visit_date nulls last, v.time_start nulls last, s.seq
$$;
revoke all on function public.open_suggestions(uuid) from public, anon;
grant execute on function public.open_suggestions(uuid) to authenticated;
comment on function public.open_suggestions(uuid) is
  'AIG1-3/-5: undecided proposals of one team for its active members (confirm screen). No confirmer, no outcome.';

-- 9b. AIG1-3 / AIG1-11 (2a): the provenance of ONE value, for the people who may read the record.
create or replace function public.value_provenance(p_entity_type text, p_entity_id uuid, p_field text)
returns table (agent_name text, agent_version text, proposed_at timestamptz, status text, not_found boolean,
               confirmer_name text, confirmed_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select d.name, s.agent_version, s.created_at,
         case c.outcome when 'confirmed' then 'bestätigt' when 'corrected' then 'geändert'
                        when 'rejected' then 'abgelehnt' when 'not_found' then 'nicht gefunden' else 'offen' end,
         s.not_found,
         case when c.id is not null then private.member_name(s.organization_id, c.confirmed_by) end,
         c.confirmed_at
  from (select x.* from public.ai_suggestions x
        where x.entity_type = p_entity_type and x.entity_id = p_entity_id and x.field = p_field
        order by x.seq desc limit 1) s
  join public.ai_agent_definitions d on d.key = s.agent_key
  left join lateral (select y.id, y.outcome, y.confirmed_by, y.confirmed_at from public.ai_confirmations y
                     where y.suggestion_id = s.id order by y.seq desc limit 1) c on true
  where not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(s.organization_id) and private.is_team_member(s.team_id)
$$;
revoke all on function public.value_provenance(text, uuid, text) from public, anon;
grant execute on function public.value_provenance(text, uuid, text) to authenticated;
comment on function public.value_provenance(text, uuid, text) is
  'AIG1-3/-11: "vorgeschlagen von <Agent> / bestätigt von <Name> am <Datum>" for ONE value (entity and field), for the '
  'active members of its team. At most one row; the only function that returns a confirmer with an outcome.';

-- 9c. AIG1-7: correction rate per agent, field, team and month; no person column; small cells suppressed.
create or replace function public.agent_correction_rates(p_month date)
returns table (team_id uuid, team_name text, agent_key text, agent_name text, field text, month date,
               proposals integer, confirmed_unchanged integer, corrected integer, rejected integer, not_found integer,
               suppressed boolean)
language sql stable security definer set search_path = ''
as $$
  with m as (select date_trunc('month', p_month)::date as m0,
                    (date_trunc('month', p_month) + interval '1 month')::date as m1),
  rows as (
    select s.organization_id, s.team_id, s.agent_key, s.field, c.outcome, c.confirmed_by
    from m, public.ai_suggestions s
    left join lateral (select y.outcome, y.confirmed_by from public.ai_confirmations y
                       where y.suggestion_id = s.id order by y.seq desc limit 1) c on true
    where p_month is not null and not private.access_ended((select auth.uid()))              -- LEAVE1-3
      and (private.at_zurich(s.created_at))::date >= m.m0 and (private.at_zurich(s.created_at))::date < m.m1
      and private.is_org_member(s.organization_id)
      and (private.is_team_member(s.team_id) or private.is_coordinator(s.organization_id))
  ),
  cells as (
    select r.team_id, r.agent_key, r.field,
           count(*)::int as proposals,
           count(*) filter (where r.outcome = 'confirmed')::int as confirmed_unchanged,
           count(*) filter (where r.outcome = 'corrected')::int as corrected,
           count(*) filter (where r.outcome = 'rejected')::int as rejected,
           count(*) filter (where r.outcome = 'not_found')::int as not_found,
           count(distinct r.confirmed_by) < 3 as suppressed     -- AN1's three, per cell (ADR-120)
    from rows r
    group by r.team_id, r.agent_key, r.field
  )
  select c.team_id, t.name, c.agent_key, d.name, c.field, (select m0 from m),
         c.proposals,
         case when c.suppressed then null else c.confirmed_unchanged end,
         case when c.suppressed then null else c.corrected end,
         case when c.suppressed then null else c.rejected end,
         case when c.suppressed then null else c.not_found end,
         c.suppressed
  from cells c
  join public.teams t on t.id = c.team_id
  join public.ai_agent_definitions d on d.key = c.agent_key
  order by t.name, d.name, c.field
$$;
revoke all on function public.agent_correction_rates(date) from public, anon;
grant execute on function public.agent_correction_rates(date) to authenticated;
comment on function public.agent_correction_rates(date) is
  'AIG1-7: per agent, field, team and Zurich month: proposals, confirmed unchanged, corrected, rejected, not_found. '
  'No person column, filter or export. A cell with fewer than three distinct confirmers shows only the proposal count '
  '(suppressed). The team reads its own rows; coordinators (OPS1) all teams of their organisation.';

-- 9d. AIG1-10: agent health for coordinators (operations, coach, administrator). Runs the stop check first.
create or replace function public.agent_health(p_organization_id uuid)
returns table (agent_key text, agent_name text, level text, kind text, version text, state text,
               last_proposal_at timestamptz, last_window_share numeric, last_window_decided integer,
               stop_reason text, stopped_at timestamptz, stop_id uuid)
language plpgsql volatile security definer set search_path = ''
as $$
#variable_conflict use_column
declare k text;
begin
  if (select auth.uid()) is null or private.access_ended((select auth.uid()))              -- LEAVE1-3
     or not private.is_coordinator(p_organization_id) then
    return;
  end if;
  for k in select s.agent_key from public.ai_agent_settings s where s.organization_id = p_organization_id loop
    perform private.aig1_check(p_organization_id, k);
  end loop;
  return query
  select d.key, d.name, d.level, d.kind, d.version, coalesce(s.state, 'off'),
         (select max(x.created_at) from public.ai_suggestions x where x.organization_id = p_organization_id and x.agent_key = d.key),
         lw.share, lw.decided,
         st.reason, st.created_at, st.id
  from public.ai_agent_definitions d
  left join public.ai_agent_settings s on s.organization_id = p_organization_id and s.agent_key = d.key
  left join public.ai_agent_stops st on st.id = s.last_stop_id and s.state = 'stopped'
  left join lateral (
    select w.share, w.decided
    from private.aig1_window_stats(p_organization_id, d.key,
           s.switched_on_at + (floor(extract(epoch from (private.now() - s.switched_on_at))
                                     / extract(epoch from make_interval(days => s.stop_window_days))) - 1)
                              * make_interval(days => s.stop_window_days),
           s.switched_on_at + floor(extract(epoch from (private.now() - s.switched_on_at))
                                    / extract(epoch from make_interval(days => s.stop_window_days)))
                              * make_interval(days => s.stop_window_days)) w
    where s.switched_on_at is not null
      and private.now() >= s.switched_on_at + make_interval(days => s.stop_window_days)
  ) lw on true
  order by d.name;
end;
$$;
revoke all on function public.agent_health(uuid) from public, anon;
grant execute on function public.agent_health(uuid) to authenticated;
comment on function public.agent_health(uuid) is
  'AIG1-10: one line per agent for coordinators of the organisation: state, last proposal, last closed window''s '
  'correction share and decided count, and why it stopped. No person column.';

-- 9e. AIG1-12 / AIG1-13: look-back after a stop, per agent and window, never per person.
-- The record's current value of a field (only fields with a consuming command; null otherwise).
create or replace function private.aig1_current_value(p_entity_type text, p_entity_id uuid, p_field text)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select case when p_entity_type = 'care_visits' and p_field = 'responsible_user_id'
              then (select to_jsonb(v.responsible_user_id::text) from public.care_visits v where v.id = p_entity_id) end
$$;
revoke all on function private.aig1_current_value(text, uuid, text) from public, anon, authenticated;

-- AIG1-13 (b): when the record last took a value other than the listed one (from its audit trail; null if unknown).
create or replace function private.aig1_superseded_at(p_entity_type text, p_entity_id uuid, p_field text, p_value jsonb)
returns timestamptz language sql stable security definer set search_path = ''
as $$
  select max(a.occurred_at) from public.audit_events a
  where p_entity_type = 'care_visits' and p_field = 'responsible_user_id'
    and a.table_name = 'care_visits' and a.entity_id = p_entity_id and a.changed ? 'responsible_user_id'
    and (a.changed -> 'responsible_user_id' -> 'new') is distinct from p_value
$$;
revoke all on function private.aig1_superseded_at(text, uuid, text, jsonb) from public, anon, authenticated;

-- All lines of one stop, without access filter (callers filter). A line: a suggestion of the stopped agent in the stop
-- window (threshold) or since the switch-on (version change) whose newest confirmation at the stop was `confirmed`
-- and that was not confirmed again or corrected since (AIG1-12 (iv)). `superseded`: the record no longer holds the
-- listed value (AIG1-13 (b)); the line stays, labelled, and is not counted as open.
create or replace function private.aig1_lookback(p_stop_id uuid)
returns table (suggestion_id uuid, organization_id uuid, entity_type text, entity_id uuid, field text, team_id uuid,
               case_id uuid, proposed_at timestamptz, superseded boolean, superseded_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select s.id, s.organization_id, s.entity_type, s.entity_id, s.field, s.team_id, s.case_id, s.created_at,
         cur.value is distinct from c.final_value,
         case when cur.value is distinct from c.final_value
              then private.aig1_superseded_at(s.entity_type, s.entity_id, s.field, c.final_value) end
  from public.ai_agent_stops st
  join public.ai_suggestions s
    on s.organization_id = st.organization_id and s.agent_key = st.agent_key
   and s.created_at >= st.window_from
   and (s.created_at < st.window_to or (st.reason = 'version_changed' and s.seq <= st.suggestion_seq))
  cross join lateral (select y.outcome, y.final_value from public.ai_confirmations y
                      where y.suggestion_id = s.id and y.seq <= st.confirmation_seq order by y.seq desc limit 1) c
  cross join lateral (select private.aig1_current_value(s.entity_type, s.entity_id, s.field) as value) cur
  where st.id = p_stop_id
    and c.outcome = 'confirmed'                                            -- unchanged at the stop
    and not exists (select 1 from public.ai_confirmations z                -- not re-checked since the stop
                    where z.suggestion_id = s.id and z.seq > st.confirmation_seq)
$$;
revoke all on function private.aig1_lookback(uuid) from public, anon, authenticated;

create or replace function public.agent_stop_lookback(p_stop_id uuid)
returns table (entity_type text, entity_id uuid, field text, team_id uuid, team_name text, case_ref text,
               visit_date date, proposed_at timestamptz, superseded boolean, superseded_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select l.entity_type, l.entity_id, l.field, l.team_id, t.name, private.case_reference(l.case_id), v.visit_date,
         l.proposed_at, l.superseded, l.superseded_at
  from private.aig1_lookback(p_stop_id) l
  join public.teams t on t.id = l.team_id
  left join public.care_visits v on l.entity_type = 'care_visits' and v.id = l.entity_id
  where not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(l.organization_id)
    and (private.is_coordinator(l.organization_id) or private.is_team_member(l.team_id))
  order by l.superseded, v.visit_date nulls last, t.name, l.proposed_at
$$;
revoke all on function public.agent_stop_lookback(uuid) from public, anon;
grant execute on function public.agent_stop_lookback(uuid) to authenticated;
comment on function public.agent_stop_lookback(uuid) is
  'AIG1-12/-13: records holding a value of the stopped agent confirmed unchanged in the stop window (threshold) or '
  'since the switch-on (version change), not confirmed again or corrected since; a line whose record no longer holds '
  'the value stays, marked superseded ("überholt am <Datum>"). No person, no outcome column. Coordinators see every '
  'line; a member only the lines of her own teams'' records. Writes nothing.';

-- 10. OPS1: "Assistent gestoppt" (AIG1-8), existing exception path, no new signal class ----------------------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step)
values ('agent_stopped', 'P2', null, null, null, 'Assistent gestoppt',
        'Der Assistent schlägt nichts mehr vor. Die Liste der unverändert bestätigten Werte aus dem Stoppfenster öffnen '
        || '(AIG1-12). Ob, von wem und bis wann sie nachgeprüft werden, ist offen (klinische Verantwortung, D-17). '
        || 'Neustart nur durch erneutes Einschalten in der Administration.')
on conflict (exception_type) do nothing;

select private.aig1_patch('private.derived_exceptions(uuid)', array[
  E'  from private.successor_needed(p_org) s\n  join rules r on r.exception_type = ''successor_needed''\n',
  E'  from private.successor_needed(p_org) s\n  join rules r on r.exception_type = ''successor_needed''\n'
  || E'  union all\n'
  || E'  -- AIG1-8: an agent stopped by its threshold or a version change (closes when it is switched on again)\n'
  || E'  select ''agent_stopped:'' || st.id, ''agent_stopped'', st.created_at, null::uuid, null::uuid, ''ai_agent_stop'', st.id,\n'
  || E'         d.name || '' · '' || (select count(*) from private.aig1_lookback(st.id) l where not l.superseded) || '' offen''\n'
  || E'  from public.ai_agent_settings g\n'
  || E'  join public.ai_agent_stops st on st.id = g.last_stop_id\n'
  || E'  join public.ai_agent_definitions d on d.key = g.agent_key\n'
  || E'  join rules r on r.exception_type = ''agent_stopped''\n'
  || E'  where g.organization_id = p_org and g.state = ''stopped''\n',
  '1'], 'AIG1-8');

drop function private.aig1_patch(text, text[], text);
