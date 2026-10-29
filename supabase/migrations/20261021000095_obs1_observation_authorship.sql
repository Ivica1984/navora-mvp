-- OBS1: every observation shows who wrote it, and whether her qualification was recorded when she wrote it
-- (PO brief docs/agents/briefs/OBS1.md, approved by po 2026-10-29 14:35; `cra` CGR-93, advisory S2, H-04, PS-82;
-- `lca` 13:57 D-15 re-check: author shown in handover and snapshot is compliant under every plausible interpretation
-- on the sources read; ADR-118).
-- No clinical rule: whether a member without a recorded qualification may write observations, or whether they need a
-- review, stays the Clinical Owner's (D-15, D-10). The marker only DISPLAYS a recorded fact; nothing refuses, hides,
-- reorders, ranks, routes or escalates by it (no signal, OPS1 exception, quality event or billing fact reads it).
--
-- Before (IMPLEMENTED, read in the database built from 0001-0094):
--   * `record_observation` (0040) accepts an observation from any active member of the visit's team; `author_id` is
--     stored, but no qualification fact.
--   * `field_notes` (0009) returns only `own` per observation; HAND1 (`private.handover_entries`, 0033) returns the
--     author as a member code ("Teammitglied 3").
--   * `private.visit_report_snapshot` (0016) holds per observation `content`, `recorded_at`, `handover`, `edited`; it is
--     the only snapshot builder: `create_report_draft`, `update_report_draft`, `sign_report` (stores the fresh snapshot
--     whose hash the signer saw), `correct_report`, `return_report` and the draft view of `field_reports` all call it.
-- Now (IMPLEMENTED in this migration):
--   1. OBS1-1 `visit_observations.author_qualification_recorded` (boolean): set by a BEFORE INSERT trigger on every
--      insert, from the ADM2-16 rule (`private.actor_may_perform_visit`: a recorded qualification in the visit's team,
--      or for the covering nurse of a covered visit in the cover team), evaluated for the author at that moment. Any
--      value a writer passes is overwritten. Rows are append-only (0009 trigger), so a later
--      `set_member_qualification` never changes it. Null = recorded before this migration (no backfill: the table
--      forbids updates and no history is guessed; nothing is deployed, D-1). No observation is refused.
--   2. The column is not selectable through the table API (`authenticated` keeps column grants on the twelve existing
--      columns only, the RLS3-4 pattern of 0070), so nobody can list or filter it per person. It is read only per
--      observation through `field_notes`, the HAND1 entries and the report snapshot.
--   3. OBS1-2 `field_notes(date)`: two new columns per row, `author_name` (ADM1 display name, as the team list shows
--      it; null when the member has none) and `author_qualification_missing` (true only when the marker was recorded as
--      missing). Still SECURITY INVOKER: the rows stay those of the caller's visits under RLS; the marker comes through
--      `private.observation_qualification_missing(id)`, which answers only for an observation of a team the caller is
--      an active member of (null otherwise). HAND1 entries of kind `observation` carry the same two keys in `detail`.
--   4. OBS1-3 the snapshot builder adds per observation `author_id`, `author_name` (at the time of the snapshot) and
--      `author_qualification_missing`. Signed snapshots are not touched (CSR1: the guard forbids it and this migration
--      writes no `visit_reports` row); drafts show the new shape on their next refresh, as every other fact.
-- Idempotent: `add column if not exists`, `create or replace`, `drop ... if exists`; the HAND1 patch carries a marker
-- and is skipped when present.

-- 1. OBS1-1: the marker, fixed at write time --------------------------------------------------------------------------------
alter table public.visit_observations add column if not exists author_qualification_recorded boolean;
comment on column public.visit_observations.author_qualification_recorded is
  'OBS1-1 / CGR-93 / ADR-118: whether the author had a recorded qualification in the visit''s team (or, covering, in the '
  'cover team) when she wrote it (ADM2-16 rule). Set by trigger on insert; append-only. Null: written before 0095. '
  'Display only: never refuses, hides, ranks or routes. Not selectable through the table API.';

create or replace function private.observation_author_qualified(p_visit_id uuid, p_team_id uuid, p_author uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.has_qualification(p_team_id, p_author)
      or exists (select 1 from public.care_visits v
                 where v.id = p_visit_id and v.cover_team_id is not null and v.covered_by = p_author
                   and private.has_qualification(v.cover_team_id, p_author))
$$;
-- The same rule as private.actor_may_perform_visit (0094), for the stored author; only the insert trigger calls it.
revoke all on function private.observation_author_qualified(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function private.set_observation_author_qualification()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.author_qualification_recorded := private.observation_author_qualified(new.visit_id, new.team_id, new.author_id);
  return new;
end;
$$;
revoke all on function private.set_observation_author_qualification() from public, anon, authenticated;

drop trigger if exists visit_observations_author_qualification on public.visit_observations;
create trigger visit_observations_author_qualification
  before insert on public.visit_observations
  for each row execute function private.set_observation_author_qualification();

-- 2. Not selectable through the table API (RLS3-4 pattern) -------------------------------------------------------------------
revoke select on public.visit_observations from authenticated;
revoke select (author_qualification_recorded) on public.visit_observations from authenticated;
grant select (id, organization_id, visit_id, case_id, team_id, author_id, recorded_at, source, content, for_handover,
              supersedes_id, idempotency_key) on public.visit_observations to authenticated;
revoke all on public.visit_observations from anon;

-- Per observation, for a team the caller is an active member of (LEAVE1-3 included in is_team_member); null otherwise.
create or replace function private.observation_qualification_missing(p_observation_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select o.author_qualification_recorded = false
  from public.visit_observations o
  where o.id = p_observation_id and private.is_org_member(o.organization_id) and private.is_team_member(o.team_id)
$$;
revoke all on function private.observation_qualification_missing(uuid) from public, anon;
grant execute on function private.observation_qualification_missing(uuid) to authenticated;
comment on function private.observation_qualification_missing(uuid) is
  'OBS1-2 / ADR-118: the OBS1-1 marker of ONE observation, only for a member of its team; null otherwise. '
  'Private schema (not exposed through the API); called by the INVOKER reader public.field_notes.';

-- 3. OBS1-2: the handover names the author --------------------------------------------------------------------------------
drop function if exists public.field_notes(date);
create function public.field_notes(p_date date)
returns table (kind text, visit_id uuid, id uuid, content text, for_handover boolean, recorded_at timestamptz,
               own boolean, edited boolean, source_date date, author_name text, author_qualification_missing boolean)
language sql stable set search_path = ''
as $$
  with my_visits as (
    select v.id, v.case_id, v.team_id, v.visit_date
    from public.care_visits v
    join public.team_memberships tm on tm.team_id = v.team_id and tm.user_id = (select auth.uid())
    where p_date is not null and v.visit_date = p_date
  ),
  current_obs as (
    select o.id, o.organization_id, o.visit_id, o.case_id, o.team_id, o.author_id, o.content, o.for_handover,
           o.recorded_at, o.supersedes_id, sv.visit_date as obs_visit_date
    from public.visit_observations o
    join public.care_visits sv on sv.id = o.visit_id
    where not exists (select 1 from public.visit_observations s where s.supersedes_id = o.id)
  ),
  rows as (
    select 'observation' as kind, mv.id as visit_id, o.id, o.content, o.for_handover, o.recorded_at,
           o.author_id = (select auth.uid()) as own, o.supersedes_id is not null as edited, o.obs_visit_date as source_date,
           o.organization_id, o.author_id
    from my_visits mv
    join current_obs o on o.visit_id = mv.id
    union all
    select 'handover', mv.id, o.id, o.content, o.for_handover, o.recorded_at,
           o.author_id = (select auth.uid()), o.supersedes_id is not null, o.obs_visit_date,
           o.organization_id, o.author_id
    from my_visits mv
    join current_obs o
      on o.for_handover
     and o.case_id = mv.case_id
     and o.team_id = mv.team_id
     and o.visit_id <> mv.id
     and o.recorded_at >= (mv.visit_date - 14)::timestamptz
     and o.obs_visit_date <= mv.visit_date
  )
  select r.kind, r.visit_id, r.id, r.content, r.for_handover, r.recorded_at, r.own, r.edited, r.source_date,
         (select p.display_name from public.member_profiles p
          where p.organization_id = r.organization_id and p.user_id = r.author_id),
         coalesce(private.observation_qualification_missing(r.id), false)
  from rows r
  order by 2, 1 desc, 6;
$$;
revoke all on function public.field_notes(date) from public, anon;
grant execute on function public.field_notes(date) to authenticated;
comment on function public.field_notes(date) is
  'F4 / HAND1 / OBS1-2: observations of the caller''s visits on a date and current handover notes of the same case '
  '(14 days). Per observation: author display name and the OBS1-1 marker (true only when recorded as missing). '
  'Never a list, count or filter per person (OBS1-5, D-23 term b). SECURITY INVOKER under RLS.';

-- HAND1 ("seit deinem letzten Einsatz"): the observation entries carry the same two facts in `detail`.
do $patch$
declare
  def    text := pg_get_functiondef('private.handover_entries(uuid,uuid)'::regprocedure);
  marker text := '''author_qualification_missing''';
  old    text := 'jsonb_build_object(''content'', o.content, ''for_handover'', o.for_handover, ''edited'', o.supersedes_id is not null) as detail';
  new    text := 'jsonb_build_object(''content'', o.content, ''for_handover'', o.for_handover, ''edited'', o.supersedes_id is not null, '
                 '''author_name'', private.member_name(o.organization_id, o.author_id), '
                 '''author_qualification_missing'', coalesce(o.author_qualification_recorded = false, false)) as detail';
  n      integer;
begin
  if position(marker in def) > 0 then
    return;   -- already patched
  end if;
  n := (length(def) - length(replace(def, old, ''))) / length(old);
  if n <> 1 then
    raise exception '0095 HAND1 patch must match once, matched %', n;
  end if;
  execute replace(def, old, new);
end;
$patch$;

-- 4. OBS1-3: the snapshot names the author (new snapshots only) --------------------------------------------------------------
create or replace function private.visit_report_snapshot(p_visit_id uuid)
returns jsonb
language sql stable security definer set search_path = '' set "TimeZone" = 'UTC'
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
                                          'handover', o.for_handover, 'edited', o.supersedes_id is not null,
                                          -- OBS1-3: who wrote it (name at the time of the snapshot) and the OBS1-1 marker
                                          'author_id', o.author_id,
                                          'author_name', private.member_name(o.organization_id, o.author_id),
                                          'author_qualification_missing', o.author_qualification_recorded = false)
                       order by o.recorded_at)
      from public.visit_observations o
      where o.visit_id = v.id
        and not exists (select 1 from public.visit_observations s where s.supersedes_id = o.id)), '[]'::jsonb)
  )
  from public.care_visits v where v.id = p_visit_id;
$$;
revoke all on function private.visit_report_snapshot(uuid) from public, anon, authenticated;
