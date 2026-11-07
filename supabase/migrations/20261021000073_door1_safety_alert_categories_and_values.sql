-- DOOR1 part (b): the safety-alert category list and the append-only values (`docs/agents/briefs/DOOR1.md`, PO 2026-10-24
-- 23:10). ADR-086. Part (a) is migration 0072 (ADR-085).
-- Criteria built here: DOOR1-2, DOOR1-3, DOOR1-4 (database half: the code guard), DOOR1-7 for the values, and DOOR1-8,
-- DOOR1-9, DOOR1-10 for this part.
-- Sources: D-17 parts 1-2 (decided by po: option B form, organisational part first), `cra` 2026-10-24 22:26 (D-17 (2)-(3):
-- "unbekannt" distinct, who/when/source, append-only, display only), `lca` 17:57 (minimisation: never a code).
-- No clinical rule: the list ships with ONE organisational category (the access arrangement) and NO clinical category;
-- clinical categories come only from the Clinical Owner (D-17 part 3) and need an approval reference to be inserted.
--
-- Before: the access arrangement existed only as the free-text `cases.access_notes` (0013); no structured, versioned,
-- append-only record said whether it was known, who said so, and from which source.
-- Now (IMPLEMENTED in this migration):
--   1. `public.safety_alert_categories`: versioned reference list (code, label, class `organisational` | `clinical`,
--      version, active from, source, help text, `refuses_codes`, `approval_ref`, `withdrawn`). A `clinical` row cannot
--      exist without an approval reference (check constraint). Rows are immutable (no update, delete, truncate for any
--      role: trigger); a change is a new version. No write grant to any API role; read for `authenticated` (labels only).
--      Seeded with `access_arrangement` v1 (organisational).
--   2. `public.case_safety_alert_values`: one row per recorded value (case, category version, `ja` | `nein` | `unbekannt`,
--      note <= 300 characters, source `referral` | `client` | `relative` | `doctor` | `team`, actor, time). "ja" requires
--      the note. Append-only: no update, delete or truncate for any role (trigger). Audited without the note. No table
--      grant to `anon` or `authenticated`: the values are read only through the readers below.
--   3. Code guard: for a category with `refuses_codes` (the access arrangement), a note with four or more digits in a row,
--      also when single spaces, dots, commas, colons, slashes or dashes separate them ("1234", "12 34", "1-2-3-4"), is
--      refused with NV004 "Bitte keinen Code erfassen". Checked in the command and again in a BEFORE INSERT trigger.
--   4. `public.record_safety_alert_value(case, category, value, note, source, key)`: the case's team (`private.reads_case`)
--      or, at intake, an admin or operations member of the case's organisation. Idempotent; rejected otherwise.
--   5. `public.field_safety_alerts(date)`: for each visit of that date the caller reads (`private.reads_visit`: the team, or
--      the covering member while her cover runs) and each active category, the latest value (latest wins; earlier rows
--      stay) with who, when and source; no value → nulls ("nicht erfasst" on the card).
--   6. `public.active_safety_alert_categories()`: the active category versions (for the intake and card forms).
--   7. HAND1 (`private.handover_entries`): a new value appears in "since you were last here" with who and when.
-- Unchanged (DOOR1-8): no value raises a signal, changes J1 readiness, blocks planning, opens a task or ranks anything;
--   `access_unknown` (0013) stays the only task from an empty access note. DOOR1-9: no AN1, AN2, billing, export or push
--   function reads the values (pgTAP 073 catalogue check). Nothing widened (RLS2, RLS3).
-- Idempotent: tables and constraints with if not exists / drop if exists; functions with create or replace; the seed row
--   with on conflict do nothing; the HAND1 patch skips when already applied. A second run changes nothing.

-- 1. The category list -----------------------------------------------------------------------------------------------------
create table if not exists public.safety_alert_categories (
  id            uuid primary key default gen_random_uuid(),
  code          text not null check (code ~ '^[a-z][a-z0-9_]{2,40}$'),
  version       integer not null check (version >= 1),
  label         text not null check (char_length(btrim(label)) between 2 and 80),
  class         text not null check (class in ('organisational', 'clinical')),
  active_from   date not null,
  source        text not null check (char_length(btrim(source)) between 3 and 300),
  help_text     text check (help_text is null or char_length(btrim(help_text)) between 3 and 200),
  refuses_codes boolean not null default false,
  approval_ref  text check (approval_ref is null or char_length(btrim(approval_ref)) between 3 and 200),
  withdrawn     boolean not null default false,
  created_at    timestamptz not null default private.now(),
  unique (code, version)
);
alter table public.safety_alert_categories drop constraint if exists safety_alert_categories_clinical_approval;
alter table public.safety_alert_categories add constraint safety_alert_categories_clinical_approval
  check (class <> 'clinical' or approval_ref is not null);
comment on table public.safety_alert_categories is
  'DOOR1-2 (0073): versioned list of safety-alert categories. A change is a new version (rows are immutable). A clinical '
  'category needs approval_ref (the Clinical Owner''s approval, D-17 part 3); none ships. Display only.';
comment on column public.safety_alert_categories.refuses_codes is
  'DOOR1-4: the note of a value refuses four or more digits in a row (a door or key-safe code is never stored).';
comment on column public.safety_alert_categories.withdrawn is
  'A version with withdrawn = true ends the category from its active_from on (a new version, never an update).';

alter table public.safety_alert_categories enable row level security;
revoke all on public.safety_alert_categories from anon, authenticated;
grant select on public.safety_alert_categories to authenticated;
drop policy if exists catalogue_read on public.safety_alert_categories;
create policy catalogue_read on public.safety_alert_categories for select to authenticated using (true);

create or replace function private.forbid_door1_change()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  raise exception '% is append-only (DOOR1)', tg_table_name using errcode = '42501';
end;
$$;
revoke all on function private.forbid_door1_change() from public, anon, authenticated;

drop trigger if exists safety_alert_categories_no_update_delete on public.safety_alert_categories;
create trigger safety_alert_categories_no_update_delete before update or delete on public.safety_alert_categories
  for each row execute function private.forbid_door1_change();
drop trigger if exists safety_alert_categories_no_truncate on public.safety_alert_categories;
create trigger safety_alert_categories_no_truncate before truncate on public.safety_alert_categories
  for each statement execute function private.forbid_door1_change();

-- The one category this item ships: organisational, no clinical content (D-17 part 2, po 2026-10-24 23:10).
insert into public.safety_alert_categories (code, version, label, class, active_from, source, help_text, refuses_codes)
values ('access_arrangement', 1, 'Schlüssel- und Zugangsregelung', 'organisational', date '2026-10-24',
        'D-17 Teil 2 (po 2026-10-24 23:10), Brief DOOR1-2', 'Ort und wer den Schlüssel hat, nie den Code', true)
on conflict (code, version) do nothing;

-- Active versions on a day: per code the highest version that has started, unless that version withdraws the category.
create or replace function private.active_alert_categories(p_day date)
returns setof public.safety_alert_categories
language sql stable security definer set search_path = ''
as $$
  select c.* from (
    select distinct on (x.code) x.*
    from public.safety_alert_categories x
    where x.active_from <= p_day
    order by x.code, x.version desc
  ) c
  where not c.withdrawn
  order by c.class desc, c.code   -- organisational before clinical, then by code
$$;
revoke all on function private.active_alert_categories(date) from public, anon;
grant execute on function private.active_alert_categories(date) to authenticated;

create or replace function public.active_safety_alert_categories()
returns table (code text, version integer, label text, class text, help_text text, refuses_codes boolean)
language sql stable security definer set search_path = ''
as $$
  select c.code, c.version, c.label, c.class, c.help_text, c.refuses_codes
  from private.active_alert_categories((private.at_zurich(private.now()))::date) c
  where (select auth.uid()) is not null
$$;
revoke all on function public.active_safety_alert_categories() from public, anon;
grant execute on function public.active_safety_alert_categories() to authenticated;
comment on function public.active_safety_alert_categories() is
  'DOOR1-2/-4 (0073): the active category versions (today, Europe/Zurich) for the record forms. Labels only, no values.';

-- 2. The values ------------------------------------------------------------------------------------------------------------
create table if not exists public.case_safety_alert_values (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  case_id         uuid not null,
  category_id     uuid not null references public.safety_alert_categories (id),
  value           text not null check (value in ('ja', 'nein', 'unbekannt')),
  note            text check (note is null or char_length(btrim(note)) between 1 and 300),
  source          text not null check (source in ('referral', 'client', 'relative', 'doctor', 'team')),
  actor_id        uuid not null,
  idempotency_key uuid not null,
  created_at      timestamptz not null default private.now(),
  -- Insertion order: "latest" is the last recorded row, also when two rows share created_at (one transaction, or the
  -- pinned test clock).
  seq             bigint generated always as identity,
  unique (actor_id, idempotency_key),
  foreign key (case_id, organization_id) references public.cases (id, organization_id)
);
alter table public.case_safety_alert_values drop constraint if exists case_safety_alert_values_ja_note;
alter table public.case_safety_alert_values add constraint case_safety_alert_values_ja_note
  check (value <> 'ja' or note is not null);
create index if not exists case_safety_alert_values_latest
  on public.case_safety_alert_values (case_id, category_id, seq desc);
comment on table public.case_safety_alert_values is
  'DOOR1-3 (0073): append-only values per case and category version (ja / nein / unbekannt, note <= 300, source, who, '
  'when). The latest row per category is the current value; an earlier row is never overwritten. Display only. Read '
  'only through field_safety_alerts (team, or covering member while the cover runs) and HAND1.';
comment on column public.case_safety_alert_values.note is
  'Free text <= 300 characters, required with "ja". Never audited. For a category with refuses_codes no run of four or '
  'more digits (DOOR1-4).';

alter table public.case_safety_alert_values enable row level security;
revoke all on public.case_safety_alert_values from anon, authenticated;
-- No select policy and no grant for any API role: the values are read only through the SECURITY DEFINER readers.

drop trigger if exists case_safety_alert_values_no_update_delete on public.case_safety_alert_values;
create trigger case_safety_alert_values_no_update_delete before update or delete on public.case_safety_alert_values
  for each row execute function private.forbid_door1_change();
drop trigger if exists case_safety_alert_values_no_truncate on public.case_safety_alert_values;
create trigger case_safety_alert_values_no_truncate before truncate on public.case_safety_alert_values
  for each statement execute function private.forbid_door1_change();

-- Audit: category, value and source, never the note.
drop trigger if exists audit_case_safety_alert_values on public.case_safety_alert_values;
create trigger audit_case_safety_alert_values after insert on public.case_safety_alert_values
  for each row execute function private.write_audit_event('case_id', 'category_id', 'value', 'source');

-- 3. The code guard ------------------------------------------------------------------------------------------------------
-- Four or more digits in a row, also with single separators between them. Engineering's proposal for the brief's
-- "run of four or more digits" (DOOR1-4): "12 34" and "1-2-3-4" are codes too. Same pattern in src/features/door/rules.ts.
create or replace function private.looks_like_code(p_note text)
returns boolean
language sql immutable set search_path = ''
as $$ select coalesce(p_note ~ '[0-9]([ .,:/-]?[0-9]){3}', false) $$;
revoke all on function private.looks_like_code(text) from public, anon;
grant execute on function private.looks_like_code(text) to authenticated;

create or replace function private.guard_safety_alert_value()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if exists (select 1 from public.safety_alert_categories c where c.id = new.category_id and c.refuses_codes)
     and private.looks_like_code(new.note) then
    raise exception 'Bitte keinen Code erfassen' using errcode = 'NV004';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_safety_alert_value() from public, anon, authenticated;
drop trigger if exists case_safety_alert_values_guard on public.case_safety_alert_values;
create trigger case_safety_alert_values_guard before insert on public.case_safety_alert_values
  for each row execute function private.guard_safety_alert_value();

-- 4. The command -----------------------------------------------------------------------------------------------------------
create or replace function public.record_safety_alert_value(p_case_id uuid, p_category text, p_value text, p_note text,
                                                            p_source text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  cat public.safety_alert_categories%rowtype;
  why text := nullif(btrim(p_note), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_value is null or p_value not in ('ja', 'nein', 'unbekannt') then
    raise exception 'value: ja, nein or unbekannt' using errcode = '22023';
  end if;
  if p_source is null or p_source not in ('referral', 'client', 'relative', 'doctor', 'team') then
    raise exception 'source: referral, client, relative, doctor or team' using errcode = '22023';
  end if;
  if why is not null and char_length(why) > 300 then
    raise exception 'the note has at most 300 characters' using errcode = '22023';
  end if;
  if p_value = 'ja' and why is null then
    raise exception '"ja" needs a note' using errcode = '22023';
  end if;
  select * into cat from private.active_alert_categories((private.at_zurich(private.now()))::date) a where a.code = p_category;
  if cat.id is null then
    raise exception 'no active category %', p_category using errcode = '22023';
  end if;
  if cat.refuses_codes and private.looks_like_code(why) then
    raise exception 'Bitte keinen Code erfassen' using errcode = 'NV004';
  end if;
  if private.begin_command('record_safety_alert_value', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from public.cases where id = p_case_id;
  if c.id is null
     or not private.is_org_member(c.organization_id)
     or not (private.reads_case(c.id) or private.has_org_role(c.organization_id, array['admin', 'operations'])) then
    return private.end_command('rejected');
  end if;
  insert into public.case_safety_alert_values (organization_id, case_id, category_id, value, note, source, actor_id, idempotency_key)
  values (c.organization_id, c.id, cat.id, p_value, why, p_source, uid, p_idempotency_key);
  return private.end_command('ok');
end;
$$;
revoke all on function public.record_safety_alert_value(uuid, text, text, text, text, uuid) from public, anon;
grant execute on function public.record_safety_alert_value(uuid, text, text, text, text, uuid) to authenticated;
comment on function public.record_safety_alert_value(uuid, text, text, text, text, uuid) is
  'DOOR1-3 (0073): appends a value (ja / nein / unbekannt, note, source) for an active category of a case. The case''s '
  'team, or admin/operations at intake. "ja" needs the note; a code-like note is refused (NV004). Display only.';

-- 5. The /field reader -----------------------------------------------------------------------------------------------------
create or replace function public.field_safety_alerts(p_date date)
returns table (visit_id uuid, case_id uuid, category_code text, category_label text, category_class text, help_text text,
               refuses_codes boolean, value text, note text, source text, recorded_at timestamptz, actor_kind text,
               actor_name text)
language sql stable security definer set search_path = ''
as $$
  select v.id, v.case_id, cat.code, cat.label, cat.class, cat.help_text, cat.refuses_codes,
         l.value, l.note, l.source, l.created_at, a.kind,
         case when a.kind in ('team', 'coordination') then
           (select p.display_name from public.member_profiles p
            where p.organization_id = v.organization_id and p.user_id = l.actor_id)
         end
  from public.care_visits v
  cross join lateral private.active_alert_categories(v.visit_date) cat
  left join lateral (
    select x.id, x.value, x.note, x.source, x.created_at, x.actor_id
    from public.case_safety_alert_values x
    join public.safety_alert_categories xc on xc.id = x.category_id
    where x.case_id = v.case_id and x.organization_id = v.organization_id and xc.code = cat.code
    order by x.seq desc
    limit 1
  ) l on true
  cross join lateral (select case
      when l.id is null then null
      when l.actor_id = (select auth.uid()) then 'me'
      when exists (select 1 from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = l.actor_id) then 'team'
      when exists (select 1 from public.organization_memberships om
                   where om.organization_id = v.organization_id and om.user_id = l.actor_id
                     and om.role in ('admin', 'coach', 'operations')) then 'coordination'
      else 'former'
    end as kind) a
  where p_date is not null and v.visit_date = p_date and v.case_id is not null
    and (select auth.uid()) is not null
    and private.reads_visit(v.id)
  order by v.time_start nulls last, v.id, cat.class desc, cat.code
$$;
revoke all on function public.field_safety_alerts(date) from public, anon;
grant execute on function public.field_safety_alerts(date) to authenticated;
comment on function public.field_safety_alerts(date) is
  'DOOR1-3/-4 (0073): per visit on p_date that the caller reads (private.reads_visit: the team, or the covering member '
  'while her cover runs) and per active category, the latest value with who, when and source; nulls when none ("nicht '
  'erfasst"). Display only.';

-- 6. DOOR1-7: HAND1 carries a new value (case's team only, as the other case facts) -------------------------------------
do $$
declare
  def text := pg_get_functiondef('private.handover_entries(uuid,uuid)'::regprocedure);
  old_fragment constant text :=
    E'    where q.created_at > k.since_at and private.user_in_team(q.team_id, p_user) and q.visit_id is distinct from k.id\n';
  new_fragment constant text := old_fragment || E'    union all\n'
    || E'    -- DOOR1-7 (0073): a safety-alert value recorded since (category, value, note and source; who and when).\n'
    || E'    select ''safety_alert'', sa.id::text, sa.created_at, null, null, private.member_code(k.team_id, sa.actor_id, p_user),\n'
    || E'           jsonb_build_object(''category'', sc.code, ''label'', sc.label, ''value'', sa.value, ''note'', sa.note, ''source'', sa.source)\n'
    || E'    from case_ok k\n'
    || E'    join public.case_safety_alert_values sa on sa.case_id = k.case_id and sa.organization_id = k.organization_id\n'
    || E'    join public.safety_alert_categories sc on sc.id = sa.category_id\n'
    || E'    where sa.created_at > k.since_at\n';
begin
  if position('case_safety_alert_values' in def) > 0 then
    return;   -- already applied
  end if;
  if (length(def) - length(replace(def, old_fragment, ''))) / length(old_fragment) <> 1 then
    raise exception 'DOOR1 (b) HAND1 patch must match exactly once';
  end if;
  execute replace(def, old_fragment, new_fragment);
end $$;
