-- OBS1-C1 (= OBS1-7 (a)) and ADM2-C1 (ADR-119).
-- OBS1-C1: authorship and signer columns are read only through the per-visit read paths (PO brief
-- docs/agents/briefs/OBS1.md OBS1-7, condition OBS1-C1 of the acceptance 2026-10-29 19:40; `lca` 16:05 D-23 re-check,
-- its most protective option, `po-decided`). ADM2-C1: after an automatic access end (ADM2-13) the leaver's push
-- subscriptions are deleted no later than the first ADM2 sweep after the access-end instant, as end_member_access does
-- (PO brief docs/agents/briefs/ADM2.md, condition ADM2-C1 of the acceptance 2026-10-29 14:35).
-- No clinical, legal or tariff rule: this migration only narrows reads and deletes device endpoints of a person whose
-- access has already ended.
--
-- Before (IMPLEMENTED, read in a database built from 0001-0095):
--   * `authenticated` holds a table-wide select on `visit_reports` (0016), so a member of the visit's team can select
--     `snapshot` (since 0095 with the author id and OBS1-1 marker of every observation), `signed_by` and `signed_at`
--     row by row through the Data API and filter them per person.
--   * `authenticated` holds column grants on `visit_observations` (0095) that still include `author_id` and
--     `recorded_at`.
--   * Every reader of these five columns, except `public.field_notes`, is SECURITY DEFINER and reads the table as its
--     owner: `field_reports`, `field_countersign_queue`, `field_returned_reports`, `report_returns`, `sign_report`,
--     `countersign_report`, `correct_report`, `return_report`, `create_report_draft`, `update_report_draft`,
--     `withdraw_report_correction`, `visit_correction_history`, `billing_preview`, `generate_billable_facts`,
--     `final_report_visits`, `pilot_kpis`, `pilot_hypotheses` (AN1/AN2), `private.derived_exceptions` (OPS1),
--     `private.working_day_proposal`, `private.handover_entries` (HAND1), `private.visit_report_snapshot`,
--     `private.build_billable_fact`, `private.billable_fact_follow_hold`. No RLS policy and no view reads the five
--     columns. The app reads neither table directly (only through the functions above).
--   * `private.adm2_sweep(org)` (0091/0092, run on the ADM2 page loads and commands) lapses admission proposals only.
--     An access ended by the recorded contract end (ADM2-13, evaluated at read time in `private.access_ended`) leaves
--     the person's push subscriptions in place; only `end_member_access` deletes them.
-- Now (IMPLEMENTED in this migration):
--   1. OBS1-7 (a): `authenticated` loses the table-wide select on `visit_reports` and keeps column grants on every
--      column except `snapshot`, `signed_by`, `signed_at`; on `visit_observations` it keeps column grants on every
--      column except `author_id`, `recorded_at` and (0095) `author_qualification_recorded`. RLS3-4 pattern of 0070.
--      `anon` keeps nothing.
--   2. `public.field_notes(date)` (the one INVOKER reader) reads author and time of each observation through
--      `private.observation_authorship(id)`, SECURITY DEFINER, which answers only for an observation of a team the
--      caller is an active member of (the `team_members_read` and LEAVE1 policies of the table, so the same rows), and
--      null otherwise. The rows stay those of the caller's visits under RLS; signature and output are unchanged.
--   3. ADM2-C1: `private.adm2_sweep(org)` also deletes the push subscriptions of every member of the organisation
--      whose access has ended (`private.access_ended`, which includes ADM2-13), one audit row per subscription
--      (`deleted`, reason `contract_ended`), as the system (no actor). A restore (LEAVE1-7) needs a new opt-in, as
--      after a manual end.
-- Idempotent: grants and revokes repeat cleanly, `create or replace`, the sweep patch carries a marker.

-- 1. OBS1-7 (a): the five columns are not selectable through the table API ------------------------------------------------
do $$
declare
  t    text;
  hide text[];
  cols text;
  c    text;
begin
  foreach t in array array['visit_reports', 'visit_observations'] loop
    hide := case t when 'visit_reports' then array['snapshot', 'signed_by', 'signed_at']
                   else array['author_id', 'recorded_at', 'author_qualification_recorded'] end;
    select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
    from information_schema.columns
    where table_schema = 'public' and table_name = t and column_name <> all (hide);
    execute format('revoke select on public.%I from authenticated', t);
    foreach c in array hide loop
      execute format('revoke select (%I) on public.%I from authenticated', c, t);
    end loop;
    execute format('grant select (%s) on public.%I to authenticated', cols, t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end
$$;

-- 2. The INVOKER reader keeps working through a per-observation function ------------------------------------------------
create or replace function private.observation_authorship(p_observation_id uuid)
returns table (author_id uuid, recorded_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select o.author_id, o.recorded_at
  from public.visit_observations o
  where o.id = p_observation_id
    and private.is_org_member(o.organization_id)
    and private.is_team_member(o.team_id)          -- LEAVE1-3 included
$$;
revoke all on function private.observation_authorship(uuid) from public, anon;
grant execute on function private.observation_authorship(uuid) to authenticated;
comment on function private.observation_authorship(uuid) is
  'OBS1-7 / ADR-119: author and time of ONE observation, only for an active member of its team (the rows the table '
  'policies show her); no row otherwise. Private schema (not exposed through the API); called by the INVOKER reader '
  'public.field_notes, so author and time are never listed or filtered per person through the table API.';

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
    select o.id, o.organization_id, o.visit_id, o.case_id, o.team_id, o.content, o.for_handover, o.supersedes_id,
           sv.visit_date as obs_visit_date
    from public.visit_observations o
    join public.care_visits sv on sv.id = o.visit_id
    where not exists (select 1 from public.visit_observations s where s.supersedes_id = o.id)
  ),
  candidates as (
    select 'observation' as kind, mv.id as visit_id, o.id, o.content, o.for_handover, o.supersedes_id,
           o.obs_visit_date, o.organization_id, null::date as since
    from my_visits mv
    join current_obs o on o.visit_id = mv.id
    union all
    select 'handover', mv.id, o.id, o.content, o.for_handover, o.supersedes_id,
           o.obs_visit_date, o.organization_id, mv.visit_date - 14
    from my_visits mv
    join current_obs o
      on o.for_handover
     and o.case_id = mv.case_id
     and o.team_id = mv.team_id
     and o.visit_id <> mv.id
     and o.obs_visit_date <= mv.visit_date
  ),
  rows as (
    select c.kind, c.visit_id, c.id, c.content, c.for_handover, a.recorded_at,
           a.author_id = (select auth.uid()) as own, c.supersedes_id is not null as edited, c.obs_visit_date as source_date,
           c.organization_id, a.author_id
    from candidates c
    cross join lateral private.observation_authorship(c.id) a
    where c.since is null or a.recorded_at >= c.since::timestamptz
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
  'F5 / HAND / OBS1-2: the caller''s observations and handover notes for one day (INVOKER: rows under RLS). Per '
  'observation the author''s display name and the OBS1-1 marker; since 0096 (OBS1-7, ADR-119) author and time come '
  'through private.observation_authorship, as the table API no longer gives them.';

-- 3. ADM2-C1: the sweep deletes the push subscriptions of an ended access ---------------------------------------------------
create or replace function private.adm2_end_push_subscriptions(p_org uuid)
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n integer := 0;
begin
  for r in delete from public.push_subscriptions s
           where exists (select 1 from public.organization_memberships m
                         where m.organization_id = p_org and m.user_id = s.user_id)
             and private.access_ended(s.user_id)
           returning s.id, s.organization_id loop
    -- The system's act (no actor, no command): the ADM2-13 end took effect at its instant, not by the viewer whose
    -- page load ran the sweep. Same keys as end_member_access (AUD1 classes `deleted`, `reason`: code).
    insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
    values (r.organization_id, null, 'system', 'push_subscriptions', r.id, null, null,
            jsonb_build_object('deleted', true, 'reason', 'contract_ended'));
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function private.adm2_end_push_subscriptions(uuid) from public, anon, authenticated;
comment on function private.adm2_end_push_subscriptions(uuid) is
  'ADM2-C1 / ADR-119: deletes the push subscriptions of every member of the organisation whose access has ended '
  '(private.access_ended: a recorded end, or ADM2-13 her contract end), one audit row each. Called by private.adm2_sweep.';

create or replace function private.adm2c1_patch(p_sig text, p_old text, p_new text, p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare d text := pg_get_functiondef(p_sig::regprocedure);
begin
  if position(p_marker in d) > 0 then return; end if;
  if position(p_old in d) = 0 then raise exception 'ADM2-C1 patch: anchor not found in %', p_sig; end if;
  execute replace(d, p_old, p_new);
end;
$$;
select private.adm2c1_patch('private.adm2_sweep(uuid)',
  E'  perform set_config(''navora.command'', coalesce(cmd, ''''), true);\n',
  E'  -- ADM2-C1 (ADR-119): the push subscriptions of an ended access (ADM2-13 included) go with the first sweep after it.\n'
  || E'  perform private.adm2_end_push_subscriptions(p_org);\n'
  || E'  perform set_config(''navora.command'', coalesce(cmd, ''''), true);\n',
  'ADM2-C1 (ADR-119)');
drop function private.adm2c1_patch(text, text, text, text);
revoke all on function private.adm2_sweep(uuid) from public, anon, authenticated;
