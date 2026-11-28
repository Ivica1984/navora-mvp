-- PLAN3 part (a): day-plan and continuity proposal in the database (ADR-145). PO brief docs/agents/briefs/PLAN3.md
-- (approved; amended 2026-10-27 15:20 / 18:10, 2026-10-30 00:15 / 01:10 / 03:10 / 21:25 / 22:15, 2026-10-31 00:10 /
-- 02:25 / 02:55). Stage 0 of D-35: synthetic data only, no AI service. No clinical, legal, tariff or labour-law rule is
-- added: the hard limits are the existing J3 / ADM2 / LEAVE1 / ABS1 checks, the order is the PO's stated planning
-- preference (PLAN3-3), and NAVORA sets no maximum load (PLAN3-4, D-23).
--
-- Before (IMPLEMENTED, read in a database built from 0001-0104): AIG1 has a register, a ledger, confirmations and one
-- synthetic test agent; nobody proposes who takes a team's open visits of a day. A visit's responsible member is set by
-- hand (J3) or through a confirmed AIG1 value whose apply step expects the visit to be unassigned (or to hold the value
-- of the suggestion's own last confirmation).
-- Now (IMPLEMENTED in this migration):
--   1. PLAN3-6 agent `plan3_day_proposal` ("Tagesvorschlag", kind rule, level L, version 1, fixture
--      `aig1_eval_plan3_day_proposal`, bar 100) and its field `responsible_user_id` (class `schedule`, CGR-78). Off by
--      default: no `ai_agent_settings` row is written; an administrator switches it on with a written threshold.
--   2. PLAN3-10 team switch `team_day_proposal_settings` (one row per team; enabled, last switch-on time; NO actor
--      column). `set_team_day_proposal` is the only writer: an active member of that team only, audited (the actor is
--      in the audit row only), idempotent. `team_day_proposal_state(team)` tells the team whether it may ask.
--   3. PLAN3-3 pure rule `private.plan3_choose(candidates, primary, deputy)`: among candidates that pass every limit,
--      the primary nurse, then the deputy, then the most completed visits to the client in the last 90 days, then the
--      fewest planned minutes that day; ties broken by the member id as text, ascending (stable, not random). With no
--      eligible candidate: `not_found` with the limit the closest candidate failed. Its fixture is synthetic.
--   4. PLAN3-1/-2 `private.plan3_lines(team, date, include_assigned)`: the open visits of the team and day (planned,
--      not suspended, not covered by another team; unassigned, or every one when "auch zugewiesene neu vorschlagen"),
--      in time order, each evaluated against every team member: active membership with a recorded qualification and
--      access open (ADM2-6, LEAVE1), contract not ended (ADM2), registered nurse for B minutes or a needs assessment
--      (J3, 0014:244), no recorded absence covering the visit (ABS1), no overlap with a visit of the same team already
--      assigned to her that day or proposed to her earlier in the same run (planned times through
--      private.visit_interval, DST1). Reads only the team's visits, cases and members (PLAN3-8).
--   5. PLAN3-1/-5 `propose_day_plan(team, date, include_assigned, key)`: an active member of the team, for today to
--      14 days ahead; refused (no ledger row) when the agent is off or stopped, the team switch is off, the date is out
--      of range, or an earlier proposal of that team and day still has undecided lines. Writes one AIG1 ledger row per
--      line (shared proposal id) and one `day_plan_lines` row (reason, visits known, the limit for "kein Vorschlag",
--      the member assigned before). Never writes `care_visits`.
--   6. PLAN3-5 confirm: through AIG1 `confirm_suggestion` / `confirm_suggestions` unchanged. `private.aig1_apply` now
--      takes the member a PLAN3 line found on the visit as the expected value when the suggestion has no applied
--      confirmation yet, so a re-proposed assigned visit can be confirmed or corrected; every J3 check runs again.
--   7. PLAN3-3/-4/-9 readers `day_plan(team, date)` (the newest proposal's lines: time, minutes per category, member,
--      reason, flags, decision state; no confirmer) and `day_plan_load(team, date)` (per member: planned minutes now
--      and with the undecided lines). Team members only; nothing for anyone else.
-- Not in this migration (PLANNED, ADR-145): the `/team` screen (PLAN3-9/-10/-11/-12, part (b)), the PLAN3-7 and
-- PLAN3-13 measures, the e2e tests.
-- Idempotent: `if not exists`, `create or replace`, `on conflict do nothing`, `drop trigger if exists`.

-- 1. The agent and its field (PLAN3-6, AIG1-1, AIG1-5) ---------------------------------------------------------------------
insert into public.ai_agent_definitions (key, name, level, kind, version, provider, region, fixture, eval_bar, brief)
values ('plan3_day_proposal', 'Tagesvorschlag', 'L', 'rule', '1', null, null, 'aig1_eval_plan3_day_proposal', 100,
        'PLAN3')
on conflict (key) do nothing;
insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class, class_brief, class_cra_ref)
values ('plan3_day_proposal', 'responsible_user_id', 'care_visits', 'responsible_user_id', 'schedule', 'PLAN3',
        'cra 2026-10-27 17:35 #555, CGR-78')
on conflict (agent_key, field) do nothing;

-- 2. The team switch (PLAN3-10) -------------------------------------------------------------------------------------------
create table if not exists public.team_day_proposal_settings (
  id              uuid not null default gen_random_uuid() unique,
  organization_id uuid not null references public.organizations (id),
  team_id         uuid primary key references public.teams (id),
  enabled         boolean not null default false,
  switched_on_at  timestamptz,
  updated_at      timestamptz not null default private.now(),
  check (not enabled or switched_on_at is not null)
);
comment on table public.team_day_proposal_settings is
  'PLAN3-10: whether a team uses the day-plan proposal ("Tagesvorschlag"), set by the team itself. Default off (no '
  'row). No actor column: who switched is in the audit row only, readable per record through read_audit_record.';
alter table public.team_day_proposal_settings enable row level security;
revoke all on public.team_day_proposal_settings from public, anon, authenticated;

drop trigger if exists audit_team_day_proposal_settings on public.team_day_proposal_settings;
create trigger audit_team_day_proposal_settings after insert or update on public.team_day_proposal_settings
  for each row execute function private.write_audit_event('team_id', 'enabled');
insert into private.audit_value_classes (table_name, key, class) values
  ('team_day_proposal_settings', 'team_id', 'code'),
  ('team_day_proposal_settings', 'enabled', 'code')
on conflict (table_name, key) do nothing;

-- Return: ok | unchanged | duplicate | rejected
create or replace function public.set_team_day_proposal(p_team_id uuid, p_on boolean, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
  cur boolean;
begin
  if uid is null then return 'rejected'; end if;
  if p_team_id is null or p_on is null then
    raise exception 'team and on are required' using errcode = '22023';
  end if;
  if private.begin_command('set_team_day_proposal', p_idempotency_key) then
    return private.end_command('duplicate');
  end if;
  org := private.team_organization(p_team_id);
  -- PLAN3-10: an active member of this team only; Operations, coach and administrator are refused unless they are one.
  if org is null or not private.is_org_member(org) or not private.is_team_member(p_team_id) then
    return private.end_command('rejected');
  end if;
  select s.enabled into cur from public.team_day_proposal_settings s where s.team_id = p_team_id for update;
  if coalesce(cur, false) = p_on then
    return private.end_command('unchanged');
  end if;
  insert into public.team_day_proposal_settings (organization_id, team_id, enabled, switched_on_at, updated_at)
  values (org, p_team_id, p_on, case when p_on then private.now() end, private.now())
  on conflict (team_id) do update
    set enabled = excluded.enabled,
        switched_on_at = case when excluded.enabled then excluded.switched_on_at
                              else public.team_day_proposal_settings.switched_on_at end,
        updated_at = excluded.updated_at;
  return private.end_command('ok');
end;
$$;
revoke all on function public.set_team_day_proposal(uuid, boolean, uuid) from public, anon;
grant execute on function public.set_team_day_proposal(uuid, boolean, uuid) to authenticated;
comment on function public.set_team_day_proposal(uuid, boolean, uuid) is
  'PLAN3-10: an active member of the team switches "Tagesvorschlag" on or off for her own team. Audited (actor in '
  'the audit row only), idempotent. No other role sets it.';

-- The team's view: may it ask? No actor, no name.
create or replace function public.team_day_proposal_state(p_team_id uuid)
returns table (team_enabled boolean, enabled_since date, agent_state text)
language sql stable security definer set search_path = ''
as $$
  select coalesce(s.enabled, false),
         case when s.enabled then (private.at_zurich(s.switched_on_at))::date end,
         coalesce((select a.state from public.ai_agent_settings a
                   where a.organization_id = t.organization_id and a.agent_key = 'plan3_day_proposal'), 'off')
  from public.teams t
  left join public.team_day_proposal_settings s on s.team_id = t.id
  where t.id = p_team_id
    and not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(t.organization_id) and private.is_team_member(t.id)
$$;
revoke all on function public.team_day_proposal_state(uuid) from public, anon;
grant execute on function public.team_day_proposal_state(uuid) to authenticated;
comment on function public.team_day_proposal_state(uuid) is
  'PLAN3-6/-10: for an active member of the team: whether the team uses the proposal, since when (date only, no '
  'name), and the organisation''s agent state (off, on, stopped: "Vorschlag zurzeit nicht verfügbar" unless on).';

-- 3. The rule, pure (PLAN3-3) and its fixture (AIG1-9) ---------------------------------------------------------------------
-- p_candidates: [{id, fail (null when every limit passes, else not_active | needs_rn | absent | overlap), known, load}]
-- Returns {member, reason, known} or {not_found_reason}.
create or replace function private.plan3_choose(p_candidates jsonb, p_primary uuid, p_deputy uuid)
returns jsonb language sql immutable set search_path = ''
as $$
  with c as (
    select (e ->> 'id')::uuid as id, e ->> 'fail' as fail, coalesce((e ->> 'known')::int, 0) as known,
           coalesce((e ->> 'load')::int, 0) as load
    from jsonb_array_elements(coalesce(p_candidates, '[]'::jsonb)) e
  ), ranked as (
    select c.*, case when c.id = p_primary then 1 when c.id = p_deputy then 2 when c.known > 0 then 3 else 4 end as rk
    from c where c.fail is null
  ), best as (
    select r.* from ranked r
    order by r.rk, case when r.rk = 3 then -r.known else 0 end, r.load, r.id::text
    limit 1
  )
  select coalesce(
    (select jsonb_build_object('member', b.id::text,
                               'reason', case b.rk when 1 then 'primary_nurse' when 2 then 'deputy'
                                                   when 3 then 'knows_client' else 'free_capacity' end,
                               'known', b.known)
     from best b),
    jsonb_build_object('not_found_reason',
      coalesce((select c.fail from c
                order by case c.fail when 'overlap' then 4 when 'absent' then 3 when 'needs_rn' then 2 else 1 end desc
                limit 1), 'not_active')))
$$;
revoke all on function private.plan3_choose(jsonb, uuid, uuid) from public, anon, authenticated;
comment on function private.plan3_choose(jsonb, uuid, uuid) is
  'PLAN3-3: pure ranking among candidates that pass every PLAN3-2 limit: primary nurse, deputy, most completed visits '
  'to the client (90 days), fewest planned minutes that day, then member id as text ascending. Without one: '
  'not_found with the limit the closest candidate failed (overlap, absent, needs_rn, not_active).';

create or replace function private.aig1_eval_plan3_day_proposal()
returns table (fixture_case text, expected jsonb, actual jsonb)
language sql immutable set search_path = ''
as $$
  select f.label, f.expected, private.plan3_choose(f.cands, f.pn, f.dp)
  from (values
    ('primary nurse passes every limit',
     '[{"id":"a1090000-0000-4000-8000-000000000001","known":0,"load":90},
       {"id":"a1090000-0000-4000-8000-000000000002","known":5,"load":0}]'::jsonb,
     'a1090000-0000-4000-8000-000000000001'::uuid, 'a1090000-0000-4000-8000-000000000002'::uuid,
     '{"member":"a1090000-0000-4000-8000-000000000001","reason":"primary_nurse","known":0}'::jsonb),
    ('primary nurse absent: deputy',
     '[{"id":"a1090000-0000-4000-8000-000000000001","fail":"absent"},
       {"id":"a1090000-0000-4000-8000-000000000002","known":0,"load":60},
       {"id":"a1090000-0000-4000-8000-000000000003","known":4,"load":0}]'::jsonb,
     'a1090000-0000-4000-8000-000000000001'::uuid, 'a1090000-0000-4000-8000-000000000002'::uuid,
     '{"member":"a1090000-0000-4000-8000-000000000002","reason":"deputy","known":0}'::jsonb),
    ('neither: the member with the most visits to the client',
     '[{"id":"a1090000-0000-4000-8000-000000000001","fail":"overlap"},
       {"id":"a1090000-0000-4000-8000-000000000003","known":1,"load":0},
       {"id":"a1090000-0000-4000-8000-000000000004","known":3,"load":120}]'::jsonb,
     'a1090000-0000-4000-8000-000000000001'::uuid, null::uuid,
     '{"member":"a1090000-0000-4000-8000-000000000004","reason":"knows_client","known":3}'::jsonb),
    ('equal visits to the client: fewer planned minutes',
     '[{"id":"a1090000-0000-4000-8000-000000000003","known":2,"load":60},
       {"id":"a1090000-0000-4000-8000-000000000004","known":2,"load":30}]'::jsonb,
     null::uuid, null::uuid,
     '{"member":"a1090000-0000-4000-8000-000000000004","reason":"knows_client","known":2}'::jsonb),
    ('nobody knows the client: fewest planned minutes',
     '[{"id":"a1090000-0000-4000-8000-000000000003","known":0,"load":60},
       {"id":"a1090000-0000-4000-8000-000000000004","known":0,"load":30}]'::jsonb,
     null::uuid, null::uuid,
     '{"member":"a1090000-0000-4000-8000-000000000004","reason":"free_capacity","known":0}'::jsonb),
    ('full tie: the smaller member id',
     '[{"id":"a1090000-0000-4000-8000-000000000004","known":0,"load":30},
       {"id":"a1090000-0000-4000-8000-000000000003","known":0,"load":30}]'::jsonb,
     null::uuid, null::uuid,
     '{"member":"a1090000-0000-4000-8000-000000000003","reason":"free_capacity","known":0}'::jsonb),
    ('nobody passes: the closest limit is named',
     '[{"id":"a1090000-0000-4000-8000-000000000003","fail":"absent"},
       {"id":"a1090000-0000-4000-8000-000000000004","fail":"overlap"},
       {"id":"a1090000-0000-4000-8000-000000000005","fail":"needs_rn"}]'::jsonb,
     null::uuid, null::uuid, '{"not_found_reason":"overlap"}'::jsonb),
    ('B minutes and only a care assistant free',
     '[{"id":"a1090000-0000-4000-8000-000000000005","fail":"needs_rn"},
       {"id":"a1090000-0000-4000-8000-000000000006","fail":"not_active"}]'::jsonb,
     null::uuid, null::uuid, '{"not_found_reason":"needs_rn"}'::jsonb),
    ('no member at all', '[]'::jsonb, null::uuid, null::uuid, '{"not_found_reason":"not_active"}'::jsonb)
  ) f(label, cands, pn, dp, expected)
$$;
revoke all on function private.aig1_eval_plan3_day_proposal() from public, anon, authenticated;
comment on function private.aig1_eval_plan3_day_proposal() is
  'AIG1-9: evaluation fixture of plan3_day_proposal (synthetic ids only). pgTAP 097 and 110 run it against its bar.';

-- 4. The lines of one team and day (PLAN3-1, PLAN3-2, PLAN3-8) -------------------------------------------------------------
create or replace function private.plan3_visit_open(v public.care_visits, p_include_assigned boolean)
returns boolean language sql immutable set search_path = ''
as $$
  select v.status = 'planned' and v.suspended_at is null and v.covered_by is null
     and (v.responsible_user_id is null or p_include_assigned)
$$;
revoke all on function private.plan3_visit_open(public.care_visits, boolean) from public, anon, authenticated;

create or replace function private.plan3_visit_minutes(v public.care_visits)
returns integer language sql immutable set search_path = ''
as $$ select coalesce(v.planned_minutes_a, 0) + coalesce(v.planned_minutes_b, 0) + coalesce(v.planned_minutes_c, 0) $$;
revoke all on function private.plan3_visit_minutes(public.care_visits) from public, anon, authenticated;

create or replace function private.plan3_lines(p_team uuid, p_date date, p_include_assigned boolean)
returns table (visit_id uuid, case_id uuid, member_id uuid, reason text, known_visits integer,
               not_found_reason text, assigned_before uuid)
language plpgsql stable security definer set search_path = ''
as $$
declare
  org   uuid := private.team_organization(p_team);
  today date := (private.at_zurich(private.now()))::date;
  mem   uuid[];
  lod   integer[] := '{}';
  bus   tstzmultirange[] := '{}';
  v     public.care_visits%rowtype;
  pn    uuid;
  dp    uuid;
  rng   tstzrange;
  cands jsonb;
  pick  jsonb;
  f     text;
  k     integer;
  i     integer;
  m     uuid;
begin
  select coalesce(array_agg(tm.user_id order by tm.user_id::text), '{}') into mem
  from public.team_memberships tm where tm.team_id = p_team;
  -- Each member's day before the run: the team's visits of that day assigned to her that are not re-proposed now.
  for i in 1 .. cardinality(mem) loop
    lod[i] := (select coalesce(sum(private.plan3_visit_minutes(x)), 0)::int
               from public.care_visits x
               where x.team_id = p_team and x.visit_date = p_date and x.status <> 'cancelled'
                 and x.responsible_user_id = mem[i] and not private.plan3_visit_open(x, p_include_assigned));
    bus[i] := (select coalesce(range_agg(private.visit_interval(x)), '{}'::tstzmultirange)
               from public.care_visits x
               where x.team_id = p_team and x.visit_date = p_date and x.status <> 'cancelled'
                 and x.responsible_user_id = mem[i] and not private.plan3_visit_open(x, p_include_assigned));
  end loop;

  for v in
    select x.* from public.care_visits x
    where x.team_id = p_team and x.visit_date = p_date and private.plan3_visit_open(x, p_include_assigned)
    order by x.time_start nulls last, x.time_end nulls last, x.id::text
  loop
    select c.primary_nurse_id, c.deputy_nurse_id into pn, dp from public.cases c where c.id = v.case_id;
    rng := private.visit_interval(v);
    cands := '[]'::jsonb;
    for i in 1 .. cardinality(mem) loop
      f := case
        when not private.may_perform_visit(p_team, mem[i], 0, false)
             or not private.adm2_in_contract(org, mem[i], v.visit_date) then 'not_active'
        when not private.may_perform_visit(p_team, mem[i], v.planned_minutes_b, v.is_needs_assessment) then 'needs_rn'
        when private.member_absent_during(p_team, mem[i], lower(rng), upper(rng)) then 'absent'
        when bus[i] && rng then 'overlap'
      end;
      k := 0;
      if f is null then
        -- Completed visits to this client in the last 90 days whose performer (first start event, F6) is she.
        select count(*)::int into k from public.care_visits h
        where h.case_id = v.case_id and h.team_id = p_team and h.status = 'completed'
          and h.visit_date between today - 90 and today and private.visit_performer(h.id) = mem[i];
      end if;
      cands := cands || jsonb_build_array(jsonb_build_object('id', mem[i], 'fail', f, 'known', k, 'load', lod[i]));
    end loop;
    pick := private.plan3_choose(cands, pn, dp);
    m := (pick ->> 'member')::uuid;
    if m is not null then
      i := array_position(mem, m);
      lod[i] := lod[i] + private.plan3_visit_minutes(v);
      bus[i] := bus[i] + tstzmultirange(rng);
    end if;
    visit_id := v.id;
    case_id := v.case_id;
    member_id := m;
    reason := pick ->> 'reason';
    known_visits := case when m is null then null else (pick ->> 'known')::int end;
    not_found_reason := pick ->> 'not_found_reason';
    assigned_before := v.responsible_user_id;
    return next;
  end loop;
end;
$$;
revoke all on function private.plan3_lines(uuid, date, boolean) from public, anon, authenticated;
comment on function private.plan3_lines(uuid, date, boolean) is
  'PLAN3-1/-2/-3: the proposal for one team and day, computed (writes nothing). Every PLAN3-2 limit is an existing '
  'check (ADM2-6/LEAVE1 membership and access, ADM2 contract, J3 RN rule, ABS1 absence) plus the overlap with her '
  'visits of that team and day. Reads only that team''s visits, cases and members.';

-- 5. The stored lines (PLAN3-3 reasons; PLAN3-5 expected value) ------------------------------------------------------------
create table if not exists public.day_plan_lines (
  suggestion_id    uuid primary key references public.ai_suggestions (id),
  proposal_id      uuid not null,
  organization_id  uuid not null references public.organizations (id),
  team_id          uuid not null references public.teams (id),
  visit_id         uuid not null references public.care_visits (id),
  plan_date        date not null,
  include_assigned boolean not null,
  reason           text check (reason in ('primary_nurse', 'deputy', 'knows_client', 'free_capacity')),
  known_visits     integer check (known_visits is null or known_visits >= 0),
  not_found_reason text check (not_found_reason in ('not_active', 'needs_rn', 'absent', 'overlap')),
  assigned_before  uuid,
  created_at       timestamptz not null default private.now(),
  check ((reason is null) <> (not_found_reason is null))
);
create index if not exists day_plan_lines_team_idx on public.day_plan_lines (team_id, plan_date, created_at);
comment on table public.day_plan_lines is
  'PLAN3: one row per proposed line next to its AIG1 ledger row: the stated reason (or the limit for "kein Vorschlag"), '
  'the visits known, and the member the visit had when proposed (the expected value at confirm time). Append-only; '
  'no grant to app roles; read through day_plan and day_plan_load.';
alter table public.day_plan_lines enable row level security;
revoke all on public.day_plan_lines from public, anon, authenticated;
drop trigger if exists day_plan_lines_append_only on public.day_plan_lines;
create trigger day_plan_lines_append_only before update or delete on public.day_plan_lines
  for each row execute function private.aig1_append_only();
drop trigger if exists day_plan_lines_no_truncate on public.day_plan_lines;
create trigger day_plan_lines_no_truncate before truncate on public.day_plan_lines
  for each statement execute function private.aig1_append_only();

-- 6. Asking for a proposal (PLAN3-1, PLAN3-6, PLAN3-8, PLAN3-10) -------------------------------------------------------------
-- Return {result: ok | duplicate | rejected | refused | nothing_open, reason, proposal_id, lines, not_found}
-- refused reasons: agent_off | agent_stopped | team_off | date_out_of_range | open_proposal (with its proposal_id)
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
  if not coalesce((select s.enabled from public.team_day_proposal_settings s where s.team_id = p_team_id), false) then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'team_off');
  end if;
  today := (private.at_zurich(private.now()))::date;
  if p_date < today or p_date > today + 14 then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'date_out_of_range');
  end if;
  -- One proposal of a team and day at a time: an earlier one with undecided lines of still-open visits is decided first.
  select dl.proposal_id into pid
  from public.day_plan_lines dl
  join public.care_visits v on v.id = dl.visit_id
  where dl.team_id = p_team_id and dl.plan_date = p_date
    and not exists (select 1 from public.ai_confirmations c where c.suggestion_id = dl.suggestion_id)
    and v.status = 'planned' and v.suspended_at is null and v.covered_by is null
  order by dl.created_at desc limit 1;
  if pid is not null then
    return jsonb_build_object('result', private.end_command('refused'), 'reason', 'open_proposal', 'proposal_id', pid);
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
    return jsonb_build_object('result', private.end_command('nothing_open'));
  end if;
  return jsonb_build_object('result', private.end_command('ok'), 'proposal_id', pid, 'lines', n, 'not_found', nf);
end;
$$;
revoke all on function public.propose_day_plan(uuid, date, boolean, uuid) from public, anon;
grant execute on function public.propose_day_plan(uuid, date, boolean, uuid) to authenticated;
comment on function public.propose_day_plan(uuid, date, boolean, uuid) is
  'PLAN3-1/-6/-8/-10: an active member asks for her team''s day plan (today to 14 days ahead). Refused with no ledger '
  'row when the agent is off or stopped, the team switch is off or an earlier proposal of that day is undecided. One '
  'AIG1 ledger row per line; never writes care_visits.';

-- 7. Confirm: the expected value of a re-proposed assigned visit (PLAN3-5) ----------------------------------------------------
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
  -- PLAN3-5 (0109): before its first applied confirmation, a day-plan line expects the member the visit had when it
  -- was proposed (null for an unassigned visit), so "auch zugewiesene neu vorschlagen" lines can be decided.
  if prev is null then
    select to_jsonb(dl.assigned_before::text) into prev from public.day_plan_lines dl where dl.suggestion_id = p_s.id;
  end if;
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

-- 8. Readers (PLAN3-3, PLAN3-4, PLAN3-9) ------------------------------------------------------------------------------------
-- The newest proposal of a team and day, line by line. No confirmer; the decision state only.
create or replace function public.day_plan(p_team_id uuid, p_date date)
returns table (suggestion_id uuid, proposal_id uuid, proposed_at timestamptz, visit_id uuid, case_id uuid,
               time_start time, time_end time, minutes_a integer, minutes_b integer, minutes_c integer,
               is_needs_assessment boolean, member_id uuid, member_name text, reason text, known_visits integer,
               not_found_reason text, changes_assignment boolean, not_continuity boolean, decision text,
               bulk_allowed boolean)
language sql stable security definer set search_path = ''
as $$
  with newest as (
    select dl.proposal_id from public.day_plan_lines dl
    where dl.team_id = p_team_id and dl.plan_date = p_date
    order by dl.created_at desc, dl.suggestion_id limit 1
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
                           and o.agent_key = s.agent_key and o.field = s.field)
  from newest nw
  join public.day_plan_lines dl on dl.proposal_id = nw.proposal_id
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
  'PLAN3-3/-9: the newest day-plan proposal of a team and day for its active members: visit time and minutes per '
  'category, proposed member and reason (or the limit for "kein Vorschlag"), "ändert bisherige Zuteilung", "nicht '
  'Bezugspflege/Stellvertretung", the decision state. No confirmer.';

-- Per member: planned minutes of that team and day now, and with the newest proposal's undecided lines (PLAN3-4). No limit.
create or replace function public.day_plan_load(p_team_id uuid, p_date date)
returns table (member_id uuid, member_name text, minutes_now integer, minutes_with_proposal integer)
language sql stable security definer set search_path = ''
as $$
  with newest as (
    select dl.proposal_id from public.day_plan_lines dl
    where dl.team_id = p_team_id and dl.plan_date = p_date
    order by dl.created_at desc, dl.suggestion_id limit 1
  ), open_lines as (
    select v.responsible_user_id, private.plan3_visit_minutes(v) as minutes, (s.proposed_value #>> '{}')::uuid as proposed
    from newest nw
    join public.day_plan_lines dl on dl.proposal_id = nw.proposal_id
    join public.ai_suggestions s on s.id = dl.suggestion_id and not s.not_found
    join public.care_visits v on v.id = dl.visit_id
    where not exists (select 1 from public.ai_confirmations k where k.suggestion_id = s.id)
      and v.status = 'planned' and v.suspended_at is null and v.covered_by is null
  )
  select tm.user_id, private.member_name(t.organization_id, tm.user_id), now_m.m,
         now_m.m
         - coalesce((select sum(o.minutes) from open_lines o
                     where o.responsible_user_id = tm.user_id and o.proposed <> tm.user_id), 0)::int
         + coalesce((select sum(o.minutes) from open_lines o
                     where o.proposed = tm.user_id and o.responsible_user_id is distinct from tm.user_id), 0)::int
  from public.teams t
  join public.team_memberships tm on tm.team_id = t.id
  cross join lateral (
    select coalesce(sum(private.plan3_visit_minutes(x)), 0)::int as m from public.care_visits x
    where x.team_id = t.id and x.visit_date = p_date and x.status <> 'cancelled' and x.responsible_user_id = tm.user_id
  ) now_m
  where t.id = p_team_id and exists (select 1 from newest)
    and not private.access_ended((select auth.uid()))                                          -- LEAVE1-3
    and private.is_org_member(t.organization_id) and private.is_team_member(t.id)
    and not private.access_ended(tm.user_id)
  order by private.member_name(t.organization_id, tm.user_id) nulls last, tm.user_id::text
$$;
revoke all on function public.day_plan_load(uuid, date) from public, anon;
grant execute on function public.day_plan_load(uuid, date) to authenticated;
comment on function public.day_plan_load(uuid, date) is
  'PLAN3-4: per member of the team, planned minutes of that day now and with the newest proposal''s undecided lines. '
  'Shown to the team; NAVORA sets no maximum (D-23).';
