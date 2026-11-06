-- PLAN3-15 (po 2026-11-06 06:30 in PO PR #893, not yet merged; `aia` AUT-51; `cra` 2026-11-05 15:00 conditions; a PLAN3
-- acceptance condition): a fresh request replaces the earlier undecided lines; no clean-up by hand at the busiest
-- moment. ADR-157. Decides ADR-145 deviation 3 (the `open_proposal` refusal is removed). Corrects 0109/0110/0114/0115,
-- which are not changed in place so their reviewed heads stay as they were. Stage 0 of D-35: synthetic data only.
--
-- No clinical, legal, tariff or labour-law rule is made here. Closing a line is not a decision about the visit: the
-- visit keeps whatever responsible member it has (none for an unassigned one), stays in the uncovered path until a new
-- line or a person sets it, and every new line is re-checked at confirm as before (PLAN3-5, PLAN3-14 (2)).
--
-- Before (IMPLEMENTED in 0109): `propose_day_plan` refused `open_proposal` while an earlier proposal of that team and
-- day had an undecided line of a still-open visit, so after a sick call the team first had to decide or reject every
-- old line before it could ask again (AUT-51).
-- Now (IMPLEMENTED in this migration):
--   1. `public.day_plan_line_closures`: one append-only row per closed line, next to the AIG1 ledger row it closes
--      (suggestion id, team, day, the proposal that closed it, time). The closing outcome of its own (`cra` condition 1):
--      not an `ai_confirmations` row, because that table is by definition a value a named person decided
--      (confirmed, corrected, rejected, not_found; AIG1-3/-11), and its readers count confirmers (AIG1-7 three-person
--      rule) and decision actions (PLAN3-7). No actor column: who asked is in the audit row only (as PLAN3-10). RLS on,
--      no grant to app roles, audited, append-only, never deleted.
--   2. `propose_day_plan`: the `open_proposal` refusal is removed. One request of a team and day at a time (row lock on
--      the team's switch). It writes the new lines first; then, if it wrote at least one, it closes every undecided,
--      not yet closed line of an EARLIER proposal of that team and day whose visit is still open (planned, not
--      suspended, not covered: the 0109 condition). A line already decided (confirmed, corrected, rejected,
--      not_found) is never closed. It returns `closed` (the number of lines it closed) with `ok` when it closed any.
--   3. `private.plan3_lines`: a visit that still holds the member of a confirmed or corrected PLAN3 line is not
--      proposed again, also with "auch zugewiesene neu vorschlagen"; it counts as her busy time and load, as any
--      assigned visit not re-proposed (0110 unchanged otherwise).
--   4. `open_suggestions` (the confirm list and the PLAN3-12 count) leaves closed lines out; `confirm_suggestion`
--      refuses `replaced` for a closed line whatever the outcome (no confirmation row is written, so it is never a
--      decision); `confirm_suggestions` returns a closed line in `refused` with `replaced` and sets the others.
--   5. `day_plan`: per visit of the team and day, the newest line that is not closed (ordered by the ledger sequence,
--      so two requests in one second are still ordered). Closed lines leave the day plan; a line decided earlier
--      (e.g. confirmed in the morning) stays visible next to the new lines: one line per visit. Columns unchanged (0115).
--   6. PLAN3-7 `plan3_team_measures` gains two counts, per team and month of closing, never per person, apart from the
--      three decision shares: `requests_closing` (requests that closed at least one earlier line) and `lines_closed`.
--      Like `day_plans` and `lines`, they count the team's requests, not a confirmer, so AIG1-7 does not suppress them.
--      The three shares are unchanged (a closed line is not in `decided_lines`).
-- Not changed: AIG1 `aig1_window_stats` and `agent_correction_rates` (a closed line has no confirmation, so it is
-- counted like an undecided one: never a correction); the look-back readers (they list confirmed values only);
-- `day_plan_load` (the undecided lines are those of the newest proposal; it now finds the newest in ledger order).
-- Idempotent: `if not exists`, `create or replace`, `drop function if exists` before a changed return type,
-- `drop trigger if exists`; text patches carry a marker and are skipped when present.

-- 0. Patch helper (removed at the end) ------------------------------------------------------------------------------------
create or replace function private.plan3o_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0116 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0116 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.plan3o_patch(text, text[], text) from public, anon, authenticated;

-- 1. The closing outcome (PLAN3-15, `cra` condition 1) --------------------------------------------------------------------
create table if not exists public.day_plan_line_closures (
  id                    uuid primary key default gen_random_uuid(),
  suggestion_id         uuid not null unique references public.ai_suggestions (id),
  organization_id       uuid not null references public.organizations (id),
  team_id               uuid not null references public.teams (id),
  plan_date             date not null,
  closed_by_proposal_id uuid not null,
  closed_at             timestamptz not null default private.now()
);
create index if not exists day_plan_line_closures_team_idx on public.day_plan_line_closures (team_id, closed_at);
comment on table public.day_plan_line_closures is
  'PLAN3-15: a day-plan line closed by a fresh request for the same team and day (its own outcome: not confirmed, '
  'corrected or rejected; not a decision). One row per closed AIG1 ledger row; the ledger row stays as it is. No actor '
  'column: who asked is in the audit row only. Append-only; no grant to app roles.';
alter table public.day_plan_line_closures enable row level security;
revoke all on public.day_plan_line_closures from public, anon, authenticated;
drop trigger if exists day_plan_line_closures_append_only on public.day_plan_line_closures;
create trigger day_plan_line_closures_append_only before update or delete on public.day_plan_line_closures
  for each row execute function private.aig1_append_only();
drop trigger if exists day_plan_line_closures_no_truncate on public.day_plan_line_closures;
create trigger day_plan_line_closures_no_truncate before truncate on public.day_plan_line_closures
  for each statement execute function private.aig1_append_only();
drop trigger if exists audit_day_plan_line_closures on public.day_plan_line_closures;
create trigger audit_day_plan_line_closures after insert on public.day_plan_line_closures
  for each row execute function private.write_audit_event('suggestion_id', 'team_id', 'plan_date', 'closed_by_proposal_id');
insert into private.audit_value_classes (table_name, key, class) values
  ('day_plan_line_closures', 'suggestion_id', 'code'),
  ('day_plan_line_closures', 'team_id', 'code'),
  ('day_plan_line_closures', 'plan_date', 'code'),
  ('day_plan_line_closures', 'closed_by_proposal_id', 'code')
on conflict (table_name, key) do nothing;

create or replace function private.plan3_line_closed(p_suggestion_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.day_plan_line_closures x where x.suggestion_id = p_suggestion_id) $$;
revoke all on function private.plan3_line_closed(uuid) from public, anon, authenticated;

-- 2. A confirmed line is not proposed again (PLAN3-15) --------------------------------------------------------------------
create or replace function private.plan3_visit_open_run(v public.care_visits, p_include_assigned boolean)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.plan3_visit_open(v, p_include_assigned)
     and not exists (
       select 1 from public.day_plan_lines dl
       cross join lateral (select c.outcome, c.final_value from public.ai_confirmations c
                           where c.suggestion_id = dl.suggestion_id order by c.seq desc limit 1) k
       where dl.visit_id = v.id and k.outcome in ('confirmed', 'corrected')
         and v.responsible_user_id is not distinct from (k.final_value #>> '{}')::uuid)
$$;
revoke all on function private.plan3_visit_open_run(public.care_visits, boolean) from public, anon, authenticated;
comment on function private.plan3_visit_open_run(public.care_visits, boolean) is
  'PLAN3-15: plan3_visit_open, and not a visit that still holds the member of a confirmed or corrected day-plan line.';

select private.plan3o_patch('private.plan3_lines(uuid, date, boolean)', array[
  'private.plan3_visit_open(x, p_include_assigned)',
  'private.plan3_visit_open_run(x, p_include_assigned)',
  '3'], 'plan3_visit_open_run');

-- 3. Asking for a proposal: a fresh request closes the earlier undecided lines (PLAN3-15) ---------------------------------
-- Return {result: ok | duplicate | rejected | refused | nothing_open, reason, proposal_id, lines, not_found, closed}
-- (`closed`, the number of earlier lines closed, only when it is at least 1)
-- refused reasons: agent_off | agent_stopped | team_off | date_out_of_range (0109's open_proposal is removed)
create or replace function public.propose_day_plan(p_team_id uuid, p_date date, p_include_assigned boolean,
                                                   p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid   uuid := (select auth.uid());
  org   uuid;
  today date;
  st    text;
  pid   uuid;
  sid   uuid;
  l     record;
  n     integer := 0;
  nf    integer := 0;
  cl    integer := 0;
  agent constant text := 'plan3_day_proposal';
  ver   text;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_team_id is null or p_date is null or p_include_assigned is null then
    raise exception 'team, date and include_assigned are required' using errcode = '22023';
  end if;
  if private.begin_command('propose_day_plan', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  org := private.team_organization(p_team_id);
  -- PLAN3-8 / AIG1-6: only an active member of this team asks; anyone else gets nothing and no ledger row.
  if org is null or not private.is_org_member(org) or not private.is_team_member(p_team_id) then
    raise exception 'this team is outside your access (PLAN3-8)' using errcode = '42501';
  end if;
  st := private.aig1_check(org, agent);
  if st <> 'on' then
    return jsonb_build_object('result', private.end_command('refused'),
                              'reason', case st when 'stopped' then 'agent_stopped' else 'agent_off' end);
  end if;
  -- PLAN3-15: one request of a team at a time (two members asking together never leave two lists for one visit).
  perform 1 from public.team_day_proposal_settings s where s.team_id = p_team_id for update;
  if not coalesce((select s.enabled from public.team_day_proposal_settings s where s.team_id = p_team_id), false) then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'team_off');
  end if;
  today := (private.at_zurich(private.now()))::date;
  if p_date < today or p_date > today + 14 then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'date_out_of_range');
  end if;

  select d.version into ver from public.ai_agent_definitions d where d.key = agent;
  pid := gen_random_uuid();
  for l in select * from private.plan3_lines(p_team_id, p_date, p_include_assigned) loop
    insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field,
                                       entity_type, entity_id, input_refs, not_found, proposed_value)
    values (pid, org, p_team_id, l.case_id, agent, ver, 'responsible_user_id', 'care_visits', l.visit_id,
            jsonb_build_array(jsonb_build_object('table', 'care_visits', 'id', l.visit_id),
                              jsonb_build_object('table', 'cases', 'id', l.case_id),
                              jsonb_build_object('table', 'teams', 'id', p_team_id)),
            l.member_id is null, case when l.member_id is null then null else to_jsonb(l.member_id::text) end)
    returning id into sid;
    insert into public.day_plan_lines (suggestion_id, proposal_id, organization_id, team_id, visit_id, plan_date,
                                       include_assigned, reason, known_visits, not_found_reason, assigned_before)
    values (sid, pid, org, p_team_id, l.visit_id, p_date, p_include_assigned, l.reason, l.known_visits,
            l.not_found_reason, l.assigned_before);
    n := n + 1;
    if l.member_id is null then nf := nf + 1; end if;
  end loop;
  if n = 0 then
    -- Nothing new to propose: the earlier lines, if any, stay as they are (nothing replaces them).
    return jsonb_build_object('result', private.end_command('nothing_open'));
  end if;
  -- PLAN3-15: the earlier proposals' undecided lines of still-open visits are closed with their own outcome. Decided
  -- lines (confirmed, corrected, rejected, not_found) are never closed; nothing is deleted; care_visits is not written.
  insert into public.day_plan_line_closures (suggestion_id, organization_id, team_id, plan_date, closed_by_proposal_id)
  select dl.suggestion_id, dl.organization_id, dl.team_id, dl.plan_date, pid
  from public.day_plan_lines dl
  join public.care_visits v on v.id = dl.visit_id
  where dl.team_id = p_team_id and dl.plan_date = p_date and dl.proposal_id <> pid
    and not exists (select 1 from public.ai_confirmations c where c.suggestion_id = dl.suggestion_id)
    and not exists (select 1 from public.day_plan_line_closures x where x.suggestion_id = dl.suggestion_id)
    and v.status = 'planned' and v.suspended_at is null and v.covered_by is null
  order by dl.created_at, dl.suggestion_id;
  get diagnostics cl = row_count;
  -- `closed` only when a line was closed, so a first request returns exactly 0109's result.
  return jsonb_build_object('result', private.end_command('ok'), 'proposal_id', pid, 'lines', n, 'not_found', nf)
         || case when cl > 0 then jsonb_build_object('closed', cl) else '{}'::jsonb end;
end;
$$;
revoke all on function public.propose_day_plan(uuid, date, boolean, uuid) from public, anon;
grant execute on function public.propose_day_plan(uuid, date, boolean, uuid) to authenticated;
comment on function public.propose_day_plan(uuid, date, boolean, uuid) is
  'PLAN3-1/-6/-8/-10/-15: an active member asks for her team''s day plan (today to 14 days ahead). Refused with no '
  'ledger row when the agent is off or stopped or the team switch is off. One AIG1 ledger row per line; a fresh '
  'request closes the earlier undecided lines of still-open visits (day_plan_line_closures, not a decision). Never '
  'writes care_visits.';

-- 4. Closed lines are neither listed nor decided (PLAN3-15) -----------------------------------------------------------------
select private.plan3o_patch('public.open_suggestions(uuid)', array[
  E'    and not exists (select 1 from public.ai_confirmations c where c.suggestion_id = s.id)\n',
  E'    and not exists (select 1 from public.ai_confirmations c where c.suggestion_id = s.id)\n'
  || E'    and not private.plan3_line_closed(s.id)                                                    -- PLAN3-15\n',
  '1'], 'plan3_line_closed');

select private.plan3o_patch('public.confirm_suggestion(uuid, text, jsonb, uuid)', array[
  E'    return jsonb_build_object(''result'', private.end_command(''rejected''));\n  end if;\n'
  || E'  -- AIG1-4: a not_found proposal',
  E'    return jsonb_build_object(''result'', private.end_command(''rejected''));\n  end if;\n'
  || E'  -- PLAN3-15: a line closed by a fresh request is not decided, whatever the outcome (no confirmation row).\n'
  || E'  if private.plan3_line_closed(s.id) then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''refused''), ''reason'', ''replaced'');\n'
  || E'  end if;\n'
  || E'  -- AIG1-4: a not_found proposal',
  '1'], 'plan3_line_closed');

select private.plan3o_patch('public.confirm_suggestions(uuid[], uuid)', array[
  E'    r := private.aig1_apply(s, s.proposed_value, uid);\n',
  E'    -- PLAN3-15: a closed line in a ticked list is returned with its reason; the other values are set.\n'
  || E'    if private.plan3_line_closed(s.id) then\n'
  || E'      bad := bad || jsonb_build_array(jsonb_build_object(''suggestion_id'', s.id, ''reason'', ''replaced''));\n'
  || E'      continue;\n'
  || E'    end if;\n'
  || E'    r := private.aig1_apply(s, s.proposed_value, uid);\n',
  '1'], 'plan3_line_closed');

-- The day load: the newest proposal in ledger order (two requests in one second are still ordered). Else as 0110.
select private.plan3o_patch('public.day_plan_load(uuid, date)', array[
  E'    select dl.proposal_id from public.day_plan_lines dl\n'
  || E'    where dl.team_id = p_team_id and dl.plan_date = p_date\n'
  || E'    order by dl.created_at desc, dl.suggestion_id limit 1\n',
  E'    select dl.proposal_id from public.day_plan_lines dl\n'
  || E'    join public.ai_suggestions s0 on s0.id = dl.suggestion_id                     -- PLAN3-15: ledger order\n'
  || E'    where dl.team_id = p_team_id and dl.plan_date = p_date\n'
  || E'    order by s0.seq desc limit 1\n',
  '1'], 'PLAN3-15: ledger order');

-- 5. The day plan: per visit the newest line that is not closed (PLAN3-9, PLAN3-15) -------------------------------------------
create or replace function public.day_plan(p_team_id uuid, p_date date)
returns table (suggestion_id uuid, proposal_id uuid, proposed_at timestamptz, visit_id uuid, case_id uuid,
               time_start time, time_end time, minutes_a integer, minutes_b integer, minutes_c integer,
               is_needs_assessment boolean, member_id uuid, member_name text, reason text, known_visits integer,
               not_found_reason text, changes_assignment boolean, not_continuity boolean, decision text,
               bulk_allowed boolean, visit_has_responsible boolean)
language sql stable security definer set search_path = ''
as $$
  with current_lines as (                                              -- PLAN3-15: one line per visit, none closed
    select distinct on (dl.visit_id) dl.suggestion_id
    from public.day_plan_lines dl
    join public.ai_suggestions s0 on s0.id = dl.suggestion_id
    where dl.team_id = p_team_id and dl.plan_date = p_date
      and not exists (select 1 from public.day_plan_line_closures x where x.suggestion_id = dl.suggestion_id)
    order by dl.visit_id, s0.seq desc
  )
  select s.id, dl.proposal_id, s.created_at, v.id, v.case_id, v.time_start, v.time_end, v.planned_minutes_a,
         v.planned_minutes_b, v.planned_minutes_c, v.is_needs_assessment,
         (s.proposed_value #>> '{}')::uuid,
         case when not s.not_found then private.member_name(s.organization_id, (s.proposed_value #>> '{}')::uuid) end,
         dl.reason, dl.known_visits, dl.not_found_reason,
         dl.assigned_before is not null and not s.not_found
           and dl.assigned_before is distinct from (s.proposed_value #>> '{}')::uuid,
         not s.not_found and (s.proposed_value #>> '{}')::uuid is distinct from c.primary_nurse_id
           and (s.proposed_value #>> '{}')::uuid is distinct from c.deputy_nurse_id,
         coalesce((select k.outcome from public.ai_confirmations k where k.suggestion_id = s.id
                   order by k.seq desc limit 1), 'open'),
         not s.not_found and not exists (select 1 from public.ai_confirmations k where k.suggestion_id = s.id)
           and not exists (select 1 from public.ai_one_by_one_fields o where o.organization_id = s.organization_id
                           and o.agent_key = s.agent_key and o.field = s.field),
         v.responsible_user_id is not null                                                    -- PLAN3-9 (1)
  from current_lines cur
  join public.day_plan_lines dl on dl.suggestion_id = cur.suggestion_id
  join public.ai_suggestions s on s.id = dl.suggestion_id
  join public.care_visits v on v.id = dl.visit_id
  join public.cases c on c.id = v.case_id
  where not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(dl.organization_id) and private.is_team_member(dl.team_id)
  order by v.time_start nulls last, v.time_end nulls last, v.id::text
$$;
revoke all on function public.day_plan(uuid, date) from public, anon;
grant execute on function public.day_plan(uuid, date) to authenticated;
comment on function public.day_plan(uuid, date) is
  'PLAN3-3/-9/-15: the day plan of a team and day for its active members, one line per visit: the newest line that a '
  'fresh request did not close (a line decided earlier stays). Visit time and minutes per category, proposed member '
  'and reason (or the limit for "kein Vorschlag"), "ändert bisherige Zuteilung", "nicht Bezugspflege/Stellvertretung", '
  'the decision state, and whether the visit has a responsible member now, yes/no only. No confirmer.';

-- 6. PLAN3-7 counts the closing apart from the three decision shares (PLAN3-15) ---------------------------------------------
-- The return type changes, so the function is dropped and created again (no view, policy or function depends on it).
-- Everything else is exactly 0114.
drop function if exists public.plan3_team_measures(date);

create function public.plan3_team_measures(p_month date)
returns table (team_id uuid, team_name text, month date, enabled_since date,
               day_plans integer, lines integer, decided_lines integer,
               confirmed_unchanged_share numeric, corrected_share numeric, rejected_share numeric,
               confirm_actions_per_plan numeric, minutes_to_last_decision_median numeric,
               no_proposal integer, no_proposal_share numeric,
               no_proposal_not_active integer, no_proposal_needs_rn integer, no_proposal_absent integer,
               no_proposal_overlap integer, proposal_suppressed boolean,
               continuity_before_share numeric, continuity_before_base integer,
               continuity_after_share numeric, continuity_after_base integer, continuity_suppressed boolean,
               requests_closing integer, lines_closed integer)
language sql stable security definer set search_path = ''
as $$
  with m as (select date_trunc('month', p_month)::date as m0,
                    (date_trunc('month', p_month) + interval '1 month')::date as m1),
  my_teams as (                                                        -- the scope of agent_correction_rates (0097)
    select t.id, t.organization_id, t.name,
           (select (private.at_zurich(s.switched_on_at))::date from public.team_day_proposal_settings s
            where s.team_id = t.id) as since
    from public.teams t
    where p_month is not null and not private.access_ended((select auth.uid()))                -- LEAVE1-3
      and private.is_org_member(t.organization_id)
      and (private.is_team_member(t.id) or private.is_coordinator(t.organization_id))
  ),
  sug as (                                                             -- the month's day-plan lines
    select s.id, s.team_id, s.proposal_id, s.created_at, s.not_found, dl.not_found_reason
    from m, my_teams t
    join public.ai_suggestions s on s.team_id = t.id and s.agent_key = 'plan3_day_proposal'
    left join public.day_plan_lines dl on dl.suggestion_id = s.id
    where (private.at_zurich(s.created_at))::date >= m.m0 and (private.at_zurich(s.created_at))::date < m.m1
  ),
  conf as (                                                            -- every confirmation of those lines
    select s.team_id, s.proposal_id, s.id as suggestion_id, y.seq, y.outcome, y.bulk, y.confirmed_by, y.confirmed_at
    from sug s join public.ai_confirmations y on y.suggestion_id = s.id
  ),
  latest as (
    select distinct on (c.suggestion_id) c.suggestion_id, c.outcome from conf c order by c.suggestion_id, c.seq desc
  ),
  first_dec as (
    select c.suggestion_id, min(c.confirmed_at) as at from conf c group by c.suggestion_id
  ),
  plans as (                                                           -- per plan: actions, fully decided, minutes
    select s.team_id, s.proposal_id,
           (select count(distinct case when c.bulk then c.confirmed_by::text || '@' || c.confirmed_at::text
                                       else c.suggestion_id::text || '#' || c.seq::text end)
            from conf c where c.proposal_id = s.proposal_id)::int as actions,
           bool_and(s.not_found or f.at is not null) as all_decided,
           bool_or(not s.not_found) as has_proposed,
           extract(epoch from (max(f.at) filter (where not s.not_found) - min(s.created_at))) / 60.0 as minutes
    from sug s left join first_dec f on f.suggestion_id = s.id
    group by s.team_id, s.proposal_id
  ),
  prop as (
    select s.team_id,
           count(distinct s.proposal_id)::int as day_plans,
           count(*)::int as lines,
           (count(*) filter (where not s.not_found and l.outcome in ('confirmed', 'corrected', 'rejected')))::int as decided,
           (count(*) filter (where not s.not_found and l.outcome = 'confirmed'))::int as unchanged,
           (count(*) filter (where not s.not_found and l.outcome = 'corrected'))::int as corrected,
           (count(*) filter (where not s.not_found and l.outcome = 'rejected'))::int as rejected,      -- CGR-140
           (count(*) filter (where s.not_found_reason is not null))::int as no_prop,
           (count(*) filter (where s.not_found_reason = 'not_active'))::int as np_not_active,
           (count(*) filter (where s.not_found_reason = 'needs_rn'))::int as np_needs_rn,
           (count(*) filter (where s.not_found_reason = 'absent'))::int as np_absent,
           (count(*) filter (where s.not_found_reason = 'overlap'))::int as np_overlap,
           (select count(distinct c.confirmed_by) from conf c where c.team_id = s.team_id) < 3 as suppressed  -- AIG1-7
    from sug s left join latest l on l.suggestion_id = s.id
    group by s.team_id
  ),
  plan_agg as (
    select p.team_id,
           round(sum(p.actions)::numeric / nullif(count(*) filter (where p.actions > 0), 0), 1) as actions_per_plan,
           round((percentile_cont(0.5) within group (order by p.minutes)
                    filter (where p.all_decided and p.has_proposed))::numeric, 1) as minutes_median
    from plans p group by p.team_id
  ),
  cont as (                                                            -- continuity (AN2 style), visits dated in the month
    select t.id as team_id,
           (count(*) filter (where t.since is null or v.visit_date < t.since))::int as before_base,
           (count(*) filter (where (t.since is null or v.visit_date < t.since)
                              and private.visit_performer(v.id) in (c.primary_nurse_id, c.deputy_nurse_id)))::int
             as before_hit,
           (count(*) filter (where t.since is not null and v.visit_date >= t.since))::int as after_base,
           (count(*) filter (where t.since is not null and v.visit_date >= t.since
                              and private.visit_performer(v.id) in (c.primary_nurse_id, c.deputy_nurse_id)))::int
             as after_hit
    from m, my_teams t
    join public.care_visits v on v.team_id = t.id
    join public.cases c on c.id = v.case_id
    where v.status = 'completed' and v.visit_date >= m.m0 and v.visit_date < m.m1
      and (c.primary_nurse_id is not null or c.deputy_nurse_id is not null)
    group by t.id
  ),
  closes as (                                                          -- PLAN3-15: per month of closing
    select x.team_id, count(distinct x.closed_by_proposal_id)::int as requests, count(*)::int as lines
    from m, my_teams t
    join public.day_plan_line_closures x on x.team_id = t.id
    where (private.at_zurich(x.closed_at))::date >= m.m0 and (private.at_zurich(x.closed_at))::date < m.m1
    group by x.team_id
  ),
  people as (
    select tp.team_id, tp.people
    from m, (select distinct organization_id from my_teams) o,
         lateral private.pilot_team_people(o.organization_id, m.m0, m.m1) tp
  )
  select t.id, t.name, (select m0 from m), t.since,
         coalesce(p.day_plans, 0), coalesce(p.lines, 0),
         case when p.suppressed then null else p.decided end,
         case when p.suppressed then null else round(100.0 * p.unchanged / nullif(p.decided, 0), 1) end,
         case when p.suppressed then null else round(100.0 * p.corrected / nullif(p.decided, 0), 1) end,
         case when p.suppressed then null else round(100.0 * p.rejected / nullif(p.decided, 0), 1) end,  -- CGR-140
         case when p.suppressed then null else a.actions_per_plan end,
         case when p.suppressed then null else a.minutes_median end,
         case when p.suppressed then null else p.no_prop end,
         case when p.suppressed then null else round(100.0 * p.no_prop / nullif(p.lines, 0), 1) end,
         case when p.suppressed then null else p.np_not_active end,
         case when p.suppressed then null else p.np_needs_rn end,
         case when p.suppressed then null else p.np_absent end,
         case when p.suppressed then null else p.np_overlap end,
         coalesce(p.suppressed, false),
         case when coalesce(pp.people, 0) < 3 then null
              else round(100.0 * c.before_hit / nullif(c.before_base, 0), 1) end,
         coalesce(c.before_base, 0),
         case when coalesce(pp.people, 0) < 3 then null
              else round(100.0 * c.after_hit / nullif(c.after_base, 0), 1) end,
         coalesce(c.after_base, 0),
         coalesce(pp.people, 0) < 3,                                                       -- AN1's three
         coalesce(cl.requests, 0), coalesce(cl.lines, 0)                                    -- PLAN3-15, never suppressed
  from my_teams t
  left join prop p on p.team_id = t.id
  left join plan_agg a on a.team_id = t.id
  left join cont c on c.team_id = t.id
  left join people pp on pp.team_id = t.id
  left join closes cl on cl.team_id = t.id
  where p.team_id is not null or c.team_id is not null
  order by t.name
$$;
revoke all on function public.plan3_team_measures(date) from public, anon;
grant execute on function public.plan3_team_measures(date) to authenticated;
comment on function public.plan3_team_measures(date) is
  'PLAN3-7: per team and Zurich month, never per person: day plans and lines of the day-plan assistant; shares '
  'confirmed unchanged, corrected and rejected (CGR-140: the three add up to the decided lines); confirm actions per plan (a ticked list once); median minutes to the last '
  'decision; "kein Vorschlag" share by reason; share of completed visits by the primary nurse or deputy before and '
  'since the team''s switch-on date. Fewer than three confirmers (AIG1-7) or performers (AN1) in the month: shares '
  'null. PLAN3-15 (0116): requests that closed earlier undecided lines and the lines closed, apart from the shares '
  '(not decisions; not suppressed, like the day-plan count). Scope as AIG1-7 (own teams; coordinators all teams). No '
  'stop criterion. Writes nothing.';

-- 7. Patch helper removed -------------------------------------------------------------------------------------------------
drop function if exists private.plan3o_patch(text, text[], text);
