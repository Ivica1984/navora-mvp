-- DOOR1 part (a): what the nurse needs at the door (`docs/agents/briefs/DOOR1.md`, PO 2026-10-24 23:10). ADR-085.
-- Criteria built here: DOOR1-1, DOOR1-5, DOOR1-6, DOOR1-7, DOOR1-11, and DOOR1-8/-9/-10 for these parts.
-- Part (b) (DOOR1-2, -3, -4: the versioned category list and the append-only values) follows in its own PR (brief, open
-- question 3: "(a) DOOR1-1, -5, -6, -7 and (b) the category table, in that order").
-- Sources: D-17 parts 1-2, D-19 part 2 (decided by po), CGR-51 (`cra` 2026-10-25 02:26, decided by po as DOOR1-11),
-- `lca` 22:50 (basis of a disclosure to an emergency contact). No clinical rule: no category, no protocol step, no
-- waiting time, no signal, no readiness or planning change (D-17 part 3 and D-19 part 1 stay with the Clinical Owner).
--
-- Before:
--   * `cases.access_notes` and `cases.language_notes` (0013, 0017) were recorded at intake but no /field reader returned
--     them (H-03).
--   * `record_no_show` stored only a free-text note: a phone attempt read like "did not open at the door" (D-19 (2)).
--   * `record_no_show_outcome` stored "Notfallkontakt informiert" without the basis of that disclosure (`lca` 22:50).
--   * `operations_exceptions()` showed Operations the first 120 (no-show) or 200 (interruption) characters of the
--     nurse's free-text note (`READ_PATHS.md` F-1).
-- Now (IMPLEMENTED in this migration):
--   1. `visit_status_notes.at_door boolean` (only on `no_show`) and `.disclosure_basis text` (only on a
--      `no_show_outcome` with `emergency_contact_informed`: `recorded_consent`, `emergency`, `other`). Rows written
--      before this migration keep null and read "nicht erfasst". A BEFORE INSERT guard requires both facts on new rows
--      (the commands are the only insert path; the guard is defence in depth). Both columns are audited (codes only,
--      never the note). Append-only stays (0024 trigger).
--   2. `record_no_show(visit, note, key, p_at_door)`: the door fact is required (22023 without it); the note stays
--      required. The three-argument form is dropped, so no caller can skip the fact.
--   3. `record_no_show_outcome(visit, outcome, note, key, p_basis)`: `emergency_contact_informed` requires a basis;
--      every other outcome refuses one (22023). With `other` the note (already required) says which.
--   4. `field_visit_status_notes` returns `at_door` and `disclosure_basis` (team read, unchanged scope).
--   5. HAND1 (`private.handover_entries`): a no-show or outcome of another visit carries both facts, with who and when
--      (as every status note already does).
--   6. DOOR1-11 / F-1: `private.no_show_ops_detail(visit)` builds the Operations line of a no-show from codes only:
--      date, time of the no-show, "an der Tür: ja/nein/nicht erfasst", "Ergebnis offen" or the outcome with its basis and
--      time, and "Notiz im Team". `private.derived_exceptions` uses it; the interruption line keeps its reason label and
--      shows "Notiz im Team" instead of the note excerpt. The excerpt is removed at the source, so no Operations reader
--      can carry it. The team's own alert list (`team_visit_alerts`) shows the team its note as before.
--   7. DOOR1-1: `field_door_notes(p_date)`: access and language notes of the visits of that date the caller reads
--      (`private.reads_visit`: an active member of the visit's team, or the covering member while her cover runs, RLS3).
-- Unchanged: the no-show P1 exception and signal (open until an outcome is recorded, whatever the door fact), J1
--   readiness, planning, `access_unknown` (0013), the RLS of `visit_status_notes` (0070), every AN1/AN2/billing/export/
--   push function (none reads the new columns or the case notes; pgTAP 072 catalogue check).
-- Idempotent: columns and constraints with if not exists / drop if exists; functions with create or replace or drop if
--   exists; the function patches skip when already applied. A second run changes nothing.

-- 1. The two facts --------------------------------------------------------------------------------------------------------
alter table public.visit_status_notes add column if not exists at_door boolean;
alter table public.visit_status_notes add column if not exists disclosure_basis text;
alter table public.visit_status_notes drop constraint if exists visit_status_notes_at_door_kind;
alter table public.visit_status_notes add constraint visit_status_notes_at_door_kind
  check (at_door is null or kind = 'no_show');
alter table public.visit_status_notes drop constraint if exists visit_status_notes_disclosure_basis;
alter table public.visit_status_notes add constraint visit_status_notes_disclosure_basis
  check (disclosure_basis is null
         or (kind = 'no_show_outcome' and reason_code = 'emergency_contact_informed'
             and disclosure_basis in ('recorded_consent', 'emergency', 'other')));
comment on column public.visit_status_notes.at_door is
  'DOOR1-5: on a no_show, whether the nurse was at the door (true) or not (false, e.g. only a phone attempt). Null on '
  'rows recorded before 0072 ("nicht erfasst"). Display and record only: raises no signal, ranks nothing.';
comment on column public.visit_status_notes.disclosure_basis is
  'DOOR1-6: on a no_show_outcome emergency_contact_informed, the basis of the disclosure: recorded_consent, emergency or '
  'other (the note says which). Null on every other row and on rows recorded before 0072 ("nicht erfasst").';

-- New rows must carry the facts (old rows keep null). The commands check first; this guard is defence in depth.
create or replace function private.guard_door_facts()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.kind = 'no_show' and new.at_door is null then
    raise exception 'a no-show needs the fact "an der Tür: ja/nein"' using errcode = '22023';
  end if;
  if new.kind = 'no_show_outcome' and new.reason_code = 'emergency_contact_informed' and new.disclosure_basis is null then
    raise exception 'emergency_contact_informed needs a basis: recorded_consent, emergency or other' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_door_facts() from public, anon, authenticated;
drop trigger if exists visit_status_notes_door_facts on public.visit_status_notes;
create trigger visit_status_notes_door_facts before insert on public.visit_status_notes
  for each row execute function private.guard_door_facts();

-- Audit: the codes, never the note (0054 recorded kind, reason_code, responsible_absent).
drop trigger if exists audit_visit_status_notes on public.visit_status_notes;
create trigger audit_visit_status_notes after insert on public.visit_status_notes
  for each row execute function private.write_audit_event('kind', 'reason_code', 'responsible_absent', 'at_door', 'disclosure_basis');

-- 2. record_no_show with the door fact ------------------------------------------------------------------------------------
drop function if exists public.record_no_show(uuid, text, uuid);
create or replace function public.record_no_show(p_visit_id uuid, p_reason text, p_idempotency_key uuid,
                                                 p_at_door boolean default null)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := private.check_text(p_reason, 3, 1000, 'note');
begin
  if uid is null then return 'rejected'; end if;
  if p_at_door is null then
    raise exception 'an der Tür: ja/nein is required' using errcode = '22023';
  end if;
  if private.begin_command('record_no_show', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then return private.end_command('rejected'); end if;
  if v.status <> 'on_the_way' then return private.end_command('wrong_state'); end if;   -- after arrival at the address
  insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key, at_door)
  values (v.organization_id, v.id, 'no_show', why, uid, p_idempotency_key, p_at_door);
  update public.care_visits set status = 'no_show' where id = v.id;
  return private.end_command('ok');
end;
$$;
revoke all on function public.record_no_show(uuid, text, uuid, boolean) from public, anon;
grant execute on function public.record_no_show(uuid, text, uuid, boolean) to authenticated;
comment on function public.record_no_show(uuid, text, uuid, boolean) is
  'C1 + DOOR1-5 (0072): records that the client was not reached, with the required fact "an der Tür" (p_at_door) and a '
  'note (3-1000 characters). Team members only; after departure (on_the_way).';

-- 3. record_no_show_outcome with the basis --------------------------------------------------------------------------------
drop function if exists public.record_no_show_outcome(uuid, text, text, uuid);
create or replace function public.record_no_show_outcome(p_visit_id uuid, p_outcome text, p_reason text, p_idempotency_key uuid,
                                                         p_basis text default null)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := nullif(btrim(p_reason), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_outcome is null or p_outcome not in ('client_reached', 'emergency_contact_informed', 'emergency_services_called', 'other') then
    raise exception 'outcome: client_reached, emergency_contact_informed, emergency_services_called or other' using errcode = '22023';
  end if;
  if why is null or char_length(why) not between 3 and 1000 then
    raise exception 'the outcome needs a note (3–1000 characters)' using errcode = '22023';
  end if;
  if p_outcome = 'emergency_contact_informed' then
    if p_basis is null or p_basis not in ('recorded_consent', 'emergency', 'other') then
      raise exception 'emergency_contact_informed needs a basis: recorded_consent, emergency or other' using errcode = '22023';
    end if;
  elsif p_basis is not null then
    raise exception 'a basis is recorded only with emergency_contact_informed' using errcode = '22023';
  end if;
  if private.begin_command('record_no_show_outcome', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then return private.end_command('rejected'); end if;
  if v.status <> 'no_show' then return private.end_command('wrong_state'); end if;
  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key, disclosure_basis)
  values (v.organization_id, v.id, 'no_show_outcome', p_outcome, why, uid, p_idempotency_key, p_basis);
  return private.end_command('ok');
end;
$$;
revoke all on function public.record_no_show_outcome(uuid, text, text, uuid, text) from public, anon;
grant execute on function public.record_no_show_outcome(uuid, text, text, uuid, text) to authenticated;
comment on function public.record_no_show_outcome(uuid, text, text, uuid, text) is
  'C1 + DOOR1-6 (0072): the outcome of a no-show with a note. emergency_contact_informed requires p_basis '
  '(recorded_consent, emergency, other; with other the note says which); every other outcome refuses a basis.';

-- 4. The team's /field reader returns both facts --------------------------------------------------------------------------
drop function if exists public.field_visit_status_notes(date);
create function public.field_visit_status_notes(p_date date)
returns table (visit_id uuid, kind text, reason_code text, note text, created_at timestamptz, actor_kind text,
               actor_name text, actor_qualification text, actor_role text, responsible_absent boolean,
               at_door boolean, disclosure_basis text)
language sql stable security definer set search_path = ''
as $$
  select s.visit_id, s.kind, s.reason_code, s.note, s.created_at,
         a.kind,
         case when a.kind in ('team', 'coordination') then
           (select p.display_name from public.member_profiles p
            where p.organization_id = v.organization_id and p.user_id = s.actor_id)
         end,
         case when a.kind = 'team' then
           (select tm.qualification from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = s.actor_id)
         end,
         case when a.kind = 'coordination' then
           (select om.role from public.organization_memberships om
            where om.organization_id = v.organization_id and om.user_id = s.actor_id
              and om.role in ('admin', 'coach', 'operations')
            order by case om.role when 'operations' then 1 when 'coach' then 2 else 3 end limit 1)
         end,
         s.responsible_absent,
         s.at_door,
         s.disclosure_basis
  from public.visit_status_notes s
  join public.care_visits v on v.id = s.visit_id
  cross join lateral (select case
      when s.actor_id = (select auth.uid()) then 'me'
      when exists (select 1 from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = s.actor_id) then 'team'
      when exists (select 1 from public.organization_memberships om
                   where om.organization_id = v.organization_id and om.user_id = s.actor_id
                     and om.role in ('admin', 'coach', 'operations')) then 'coordination'
      else 'former'
    end as kind) a
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  order by s.visit_id, s.created_at;
$$;
revoke all on function public.field_visit_status_notes(date) from public, anon;
grant execute on function public.field_visit_status_notes(date) to authenticated;
comment on function public.field_visit_status_notes(date) is
  'C1/CSR1 reasons of the caller''s team visits on /field, with who recorded them (CGR-26), the CGR-34 fact (0054) and '
  'the DOOR1 facts at_door and disclosure_basis (0072). Team members only.';

-- 5./6. Function patches (HAND1, Operations detail, team alerts) ----------------------------------------------------------
-- Replace each old fragment exactly once; skip a pair whose new fragment is already present (second run).
create or replace function private.door1_patch(p_fn text, p_pairs text[])
returns void
language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
  changed boolean := false;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if position(p_pairs[i + 1] in def) > 0 and position(p_pairs[i] in def) = 0 then
      continue;   -- already applied
    end if;
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'DOOR1 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
    changed := true;
  end loop;
  if changed then execute def; end if;
end;
$$;
revoke all on function private.door1_patch(text, text[]) from public, anon, authenticated;

-- 5. DOOR1-7: HAND1 carries both facts of a no-show or outcome of another visit (with who and when, as before).
select private.door1_patch('private.handover_entries(uuid,uuid)', array[
  E'jsonb_build_object(''reason_code'', n.reason_code, ''note'', n.note, ''responsible_absent'', n.responsible_absent)',
  E'jsonb_build_object(''reason_code'', n.reason_code, ''note'', n.note, ''responsible_absent'', n.responsible_absent,\n                             ''at_door'', n.at_door, ''disclosure_basis'', n.disclosure_basis)'
]);

-- 6. DOOR1-11: the Operations line of a no-show, from codes only.
create or replace function private.no_show_ops_detail(p_visit uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  select to_char(v.visit_date, 'DD.MM.')
         || ' · nicht angetroffen ' || to_char(private.at_zurich(s.created_at), 'HH24:MI')
         || ' · an der Tür: ' || case s.at_door when true then 'ja' when false then 'nein' else 'nicht erfasst' end
         || ' · ' || coalesce(
              'Ergebnis: ' || case o.reason_code
                                when 'client_reached' then 'Klient:in erreicht'
                                when 'emergency_contact_informed' then 'Notfallkontakt informiert'
                                when 'emergency_services_called' then 'Rettungsdienst alarmiert'
                                else 'anderes' end
              || case when o.reason_code = 'emergency_contact_informed' then
                   ' (Grundlage: ' || case o.disclosure_basis
                                        when 'recorded_consent' then 'erfasste Einwilligung'
                                        when 'emergency' then 'Notfall'
                                        when 'other' then 'andere'
                                        else 'nicht erfasst' end || ')'
                 else '' end
              || ' ' || to_char(private.at_zurich(o.created_at), 'HH24:MI'),
              'Ergebnis offen')
         || ' · Notiz im Team'
  from public.care_visits v
  join lateral (select x.created_at, x.at_door from public.visit_status_notes x
                where x.visit_id = v.id and x.kind = 'no_show' order by x.created_at desc, x.id desc limit 1) s on true
  left join lateral (select x.reason_code, x.disclosure_basis, x.created_at from public.visit_status_notes x
                     where x.visit_id = v.id and x.kind = 'no_show_outcome' order by x.created_at desc, x.id desc limit 1) o on true
  where v.id = p_visit
$$;
revoke all on function private.no_show_ops_detail(uuid) from public, anon, authenticated;
comment on function private.no_show_ops_detail(uuid) is
  'DOOR1-11 (CGR-51, F-1, 0072): what Operations reads about a no-show: date, time, "an der Tür: ja/nein/nicht erfasst", '
  '"Ergebnis offen" or the outcome with its basis and time, and "Notiz im Team". Codes only, never the free text.';

select private.door1_patch('private.derived_exceptions(uuid)', array[
  -- the no-show line: codes only
  E'         to_char(v.visit_date, ''DD.MM.'') || '' · '' || left(s.note, 120)\n',
  E'         private.no_show_ops_detail(v.id)  -- DOOR1-11: codes only, no note text\n',
  -- the interruption line: the reason label stays, the note excerpt goes
  E'           || coalesce('' – '' || left(s.note, 200), '''')\n',
  E'           || case when s.note is not null then '' · Notiz im Team'' else '''' end  -- DOOR1-11\n'
]);

-- The team keeps its note: its alert list puts the excerpt back where the marker stands (same text as before 0072).
create or replace function private.team_alert_detail(p_type text, p_visit uuid, p_detail text)
returns text
language sql stable security definer set search_path = ''
as $$
  select case when p_type = 'visit_interrupted' and p_detail like '% · Notiz im Team%' then
           replace(p_detail, ' · Notiz im Team',
                   coalesce((select ' – ' || left(s.note, 200) from public.visit_status_notes s
                             where s.visit_id = p_visit and s.kind = 'interrupted'
                             order by s.created_at desc, s.id desc limit 1), ''))
         else p_detail end
$$;
revoke all on function private.team_alert_detail(text, uuid, text) from public, anon, authenticated;
comment on function private.team_alert_detail(text, uuid, text) is
  'DOOR1-11 (0072): the team''s own alert list (team_visit_alerts) shows the interruption note excerpt as before; '
  'Operations reads the line without it.';

select private.door1_patch('public.team_visit_alerts()', array[
  E'r.label, d.detail, d.since',
  E'r.label, private.team_alert_detail(d.exception_type, d.entity_id, d.detail), d.since'
]);

drop function private.door1_patch(text, text[]);

-- 7. DOOR1-1: access and language notes on the /field card ---------------------------------------------------------------
create or replace function public.field_door_notes(p_date date)
returns table (visit_id uuid, case_id uuid, access_notes text, language_notes text)
language sql stable security definer set search_path = ''
as $$
  select v.id, c.id, nullif(btrim(c.access_notes), ''), nullif(btrim(c.language_notes), '')
  from public.care_visits v
  join public.cases c on c.id = v.case_id and c.organization_id = v.organization_id
  where p_date is not null and v.visit_date = p_date
    and (select auth.uid()) is not null
    and private.reads_visit(v.id)
  order by v.time_start nulls last, v.id
$$;
revoke all on function public.field_door_notes(date) from public, anon;
grant execute on function public.field_door_notes(date) to authenticated;
comment on function public.field_door_notes(date) is
  'DOOR1-1 (0072): access and language notes of the case of each visit on p_date that the caller reads '
  '(private.reads_visit: an active member of the visit''s team, or the covering member while her cover runs). Empty '
  'notes return null ("nicht erfasst" on the card). Display only.';
