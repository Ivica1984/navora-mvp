-- AI1 (brief docs/agents/briefs/AI1.md, PO package contract 2026-11-22 08:39, fixed residual list item 1; ADR-227
-- points 1, 2, 3, 5): the database side of the first connected model function. Phase A only: synthetic data,
-- simulation organisations, `navora-staging`. No clinical rule, no threshold and no price is set here.
--
-- Before (IMPLEMENTED, 0151/0153): the app reads `report_draft_model_gate` before the provider call and writes the
-- ledger after it. Nothing counts calls, so two taps or two tabs both call the model; the only kill switch is the
-- Render environment (`AI_KILL_SWITCH`, needs a restart).
-- Now (IMPLEMENTED in this migration):
--   1. `private.ai_function_limits`: one row per AI function with the day call cap (300, brief §5), the month cap
--      (CHF 50 = 50 000 000 micro-CHF, founder FE-099 (7) (2)), the reserve per call (input tokens 6 000 and output
--      tokens 1 024: an engineering upper estimate, not a measurement) and the price per million tokens. The price
--      columns ship NULL: until a reviewed migration writes a dated reading of the provider's published price (`lca`
--      in its AI1 gate, contract item 5), every reservation is refused (`price_missing`, fail closed).
--   2. `private.model_call_budget` (per organisation and Zurich day: calls, charged micro-CHF) and
--      `private.model_call_reservations` (one row per reserved call: report version, attempt 1 or 2, key, reserve,
--      then outcome, tokens, latency, settled cost; team level, no person column, no text).
--   3. `private.ai_function_switch_events`: the database kill switch, append-only (the event history is its audit);
--      «all organisations» (organization_id null) or one organisation. Read by `private.ai_function_off` inside
--      `private.report_draft_model_closed`, so gate, record and reservation close on the next request, no restart.
--      Written only by a reviewed migration or SQL statement on staging (ADR-227 point 3); no grant to any API role.
--   4. `public.reserve_report_draft_call(report, key)`: closed-check, then a repeat of the key returns the same
--      reservation (no second call), at most two attempts per report version, then the global day and month caps under
--      one advisory lock, then the reservation. Counted whatever happens afterwards.
--   5. `public.settle_report_draft_call(reservation, outcome, tokens, latency)`: once, by the performer, organisation
--      from the reservation; replaces the reserve with the measured cost (or keeps the reserve when nothing was measured).
-- Function sources: supabase/schema/functions/ (STAB-1); `private.report_draft_model_closed` was defined only in 0151
-- (no later migration names it); its new file keeps every check of 0151 in the same order and adds `switched_off`.
-- Way back: a forward migration drops the two public functions and re-creates the 0151 closed-check; signed reports,
-- the ledger and the signature path are unchanged by this migration.
-- Idempotent: `if not exists`, `create or replace`, `on conflict do nothing`.

-- 1. Limits ----------------------------------------------------------------------------------------------------------------
create table if not exists private.ai_function_limits (
  function_key                 text primary key references public.ai_agent_definitions (key),
  day_calls                    integer not null check (day_calls between 1 and 100000),
  month_cap_micro_chf          bigint  not null check (month_cap_micro_chf between 1 and 10000000000),
  reserve_input_tokens         integer not null check (reserve_input_tokens between 1 and 1000000),
  max_output_tokens            integer not null check (max_output_tokens between 1 and 100000),
  price_in_micro_chf_per_mtok  bigint check (price_in_micro_chf_per_mtok > 0),
  price_out_micro_chf_per_mtok bigint check (price_out_micro_chf_per_mtok > 0),
  price_source                 text check (char_length(btrim(price_source)) between 3 and 300),
  updated_at                   timestamptz not null default private.now(),
  check ((price_in_micro_chf_per_mtok is null) = (price_out_micro_chf_per_mtok is null)),
  check (price_in_micro_chf_per_mtok is null or price_source is not null)
);
alter table private.ai_function_limits enable row level security;
revoke all on private.ai_function_limits from public, anon, authenticated, service_role;
comment on table private.ai_function_limits is
  'AI1, ADR-227 points 1 and 5: caps and price per AI function. Written by reviewed migrations only. Price NULL = no '
  'call (fail closed) until a dated reading of the provider''s published price is recorded with its source.';
insert into private.ai_function_limits (function_key, day_calls, month_cap_micro_chf, reserve_input_tokens, max_output_tokens)
values ('report_draft_model', 300, 50000000, 6000, 1024)
on conflict (function_key) do nothing;

-- 2. Budget and reservations ---------------------------------------------------------------------------------------------
create table if not exists private.model_call_budget (
  organization_id   uuid not null references public.organizations (id),
  function_key      text not null references private.ai_function_limits (function_key),
  zurich_day        date not null,
  calls             integer not null default 0 check (calls >= 0),
  charged_micro_chf bigint  not null default 0 check (charged_micro_chf >= 0),
  primary key (organization_id, function_key, zurich_day)
);
alter table private.model_call_budget enable row level security;
revoke all on private.model_call_budget from public, anon, authenticated, service_role;
comment on table private.model_call_budget is
  'AI1, ADR-227 point 1: reserved model calls and their charged cost per organisation, function and Zurich day. '
  'Written only by reserve_report_draft_call and settle_report_draft_call under one advisory lock per function.';

create table if not exists private.model_call_reservations (
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references public.organizations (id),
  team_id            uuid not null references public.teams (id),
  function_key       text not null references private.ai_function_limits (function_key),
  report_id          uuid not null references public.visit_reports (id),
  attempt            smallint not null check (attempt in (1, 2)),
  idempotency_key    uuid not null unique,
  zurich_day         date not null,
  reserved_micro_chf bigint not null check (reserved_micro_chf >= 0),
  created_at         timestamptz not null default private.now(),
  settled_at         timestamptz,
  outcome            text check (outcome in ('ok', 'invalid', 'max_tokens', 'timeout', 'provider_error')),
  input_tokens       integer check (input_tokens >= 0),
  output_tokens      integer check (output_tokens >= 0),
  latency_ms         integer check (latency_ms >= 0),
  settled_micro_chf  bigint check (settled_micro_chf >= 0),
  cost_basis         text check (cost_basis in ('measured_tokens', 'reserve')),
  unique (report_id, attempt),
  check ((settled_at is null) = (outcome is null)),
  check ((settled_at is null) = (settled_micro_chf is null))
);
alter table private.model_call_reservations enable row level security;
revoke all on private.model_call_reservations from public, anon, authenticated, service_role;
comment on table private.model_call_reservations is
  'AI1, ADR-227 points 1 and 2: one row per reserved model call (report version, attempt 1 or 2). Outcome, tokens and '
  'latency at team level; no person column and no text. A reservation never settled stays charged at its reserve.';

-- 3. Database kill switch -------------------------------------------------------------------------------------------------
create table if not exists private.ai_function_switch_events (
  seq             bigint generated always as identity primary key,
  function_key    text not null references public.ai_agent_definitions (key),
  organization_id uuid references public.organizations (id),
  off             boolean not null,
  reason          text not null check (reason in ('manual', 'stop_rule', 'evaluation_failed', 'cleared')),
  note            text check (char_length(btrim(note)) between 3 and 300),
  created_at      timestamptz not null default private.now(),
  check (off or reason = 'cleared')
);
create index if not exists ai_function_switch_events_scope_idx
  on private.ai_function_switch_events (function_key, organization_id, seq desc);
alter table private.ai_function_switch_events enable row level security;
revoke all on private.ai_function_switch_events from public, anon, authenticated, service_role;
comment on table private.ai_function_switch_events is
  'AI1, ADR-227 point 3: kill switch events of an AI function, append-only (insert only, by a reviewed migration or SQL '
  'statement on staging; clearing needs eng and cra). organization_id null = all organisations. Newest event per scope wins.';
-- Append-only (the history is the audit): the AIG1 guard refuses update, delete and truncate, also for the owner.
drop trigger if exists ai_function_switch_events_append_only on private.ai_function_switch_events;
create trigger ai_function_switch_events_append_only before update or delete on private.ai_function_switch_events
  for each row execute function private.aig1_append_only();
drop trigger if exists ai_function_switch_events_no_truncate on private.ai_function_switch_events;
create trigger ai_function_switch_events_no_truncate before truncate on private.ai_function_switch_events
  for each statement execute function private.aig1_append_only();

-- 4. Functions (whole files from supabase/schema/functions, STAB-1) --------------------------------------------------------
-- Whole-file re-creation from supabase/schema/functions (STAB-1); generated by scripts/fn-source.mjs.

-- private.ai_function_off: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.ai_function_off). No text patch.

-- private.ai_function_off(p_function_key text, p_org uuid)
CREATE OR REPLACE FUNCTION private.ai_function_off(p_function_key text, p_org uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- AI1 / ADR-227 point 3: true while the newest switch event for all organisations is «off», or (when «all» is not
  -- off) the newest event of this organisation is «off». No event = on. Append-only events, so the history is the audit.
  select coalesce((select e.off from private.ai_function_switch_events e
                   where e.function_key = p_function_key and e.organization_id is null
                   order by e.seq desc limit 1), false)
      or coalesce((select e.off from private.ai_function_switch_events e
                   where e.function_key = p_function_key and e.organization_id = p_org
                   order by e.seq desc limit 1), false)
$function$;

revoke all on function private.ai_function_off(p_function_key text, p_org uuid) from public, anon, authenticated, service_role;
comment on function private.ai_function_off(p_function_key text, p_org uuid) is 'AI1, ADR-227 point 3: the database kill switch of one AI function for one organisation (newest event wins; «all» off wins over an organisation). Takes effect on the next request, no restart.';

-- private.report_draft_model_closed: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.report_draft_model_closed). No text patch.

-- private.report_draft_model_closed(p_report visit_reports, p_uid uuid)
CREATE OR REPLACE FUNCTION private.report_draft_model_closed(p_report visit_reports, p_uid uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  rule public.report_draft_stop_rules%rowtype;
  st   record;
begin
  if p_uid is null or p_report.id is null or not private.is_org_member(p_report.organization_id)
     or not private.is_team_member(p_report.team_id) or private.access_ended(p_uid) then
    return 'not_team_member';
  end if;
  if p_report.status <> 'draft' then return 'not_draft'; end if;
  if p_report.performer_id <> p_uid then return 'not_performer'; end if;
  if not coalesce((select o.simulation from public.organizations o where o.id = p_report.organization_id), false) then
    return 'not_simulation_org';
  end if;
  -- AI1 / ADR-227 point 3: the database kill switch, read on every request (no restart). The newest event for all
  -- organisations wins over an organisation's own event; an organisation event only applies while «all» is not off.
  if private.ai_function_off('report_draft_model', p_report.organization_id) then return 'switched_off'; end if;
  if not exists (select 1 from public.ai_agent_fields f where f.agent_key = 'report_draft_model' and f.field = 'summary_line') then
    return 'ledger_missing';
  end if;
  select * into rule from public.report_draft_stop_rules r where r.agent_key = 'report_draft_model';
  if not found then return 'no_threshold'; end if;
  select * into st from private.aig1_window_stats(p_report.organization_id, 'report_draft_model',
                                                  private.now() - make_interval(days => rule.stop_window_days),
                                                  private.now() + interval '1 second');
  if st.decided >= rule.stop_min_decided and st.share > rule.stop_share then return 'stop_rule'; end if;
  return null;
end;
$function$;

revoke all on function private.report_draft_model_closed(p_report visit_reports, p_uid uuid) from public, anon, authenticated, service_role;
comment on function private.report_draft_model_closed(p_report visit_reports, p_uid uuid) is 'ADR-215, ADR-227: why the caller may not get a model report draft for this report now (null = open): not_team_member (incl. LEAVE1 access end), not_draft, not_performer, not_simulation_org, switched_off, ledger_missing, no_threshold, stop_rule. Shared by gate, record and reservation.';

-- public.reserve_report_draft_call: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.reserve_report_draft_call). No text patch.

-- public.reserve_report_draft_call(p_report_id uuid, p_idempotency_key uuid)
CREATE OR REPLACE FUNCTION public.reserve_report_draft_call(p_report_id uuid, p_idempotency_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid     uuid := (select auth.uid());
  r       public.visit_reports%rowtype;
  lim     private.ai_function_limits%rowtype;
  prior   private.model_call_reservations%rowtype;
  why     text;
  n       integer;
  today   date := (private.now() at time zone 'Europe/Zurich')::date;
  m0      date;
  used    integer;
  charged bigint;
  reserve bigint;
  rid     uuid;
begin
  if p_idempotency_key is null then
    raise exception 'idempotency key is required' using errcode = '22023';
  end if;
  perform private.assert_access_open();  -- LEAVE1: an ended access never reserves a model call
  -- The report row lock serialises two taps on the same report version (T-2): the second sees the first reservation.
  select * into r from public.visit_reports v where v.id = p_report_id for update;
  -- The same rule as gate and record (performer, team, access end, open draft, simulation, switch, stop rule).
  why := private.report_draft_model_closed(r, uid);
  if why is not null then
    return jsonb_build_object('result', 'rejected', 'reason', why);
  end if;
  select * into prior from private.model_call_reservations m where m.idempotency_key = p_idempotency_key;
  if prior.id is not null then
    if prior.report_id <> r.id then
      raise exception 'idempotency key already used for another report' using errcode = '22023';
    end if;
    return jsonb_build_object('result', 'duplicate', 'reservation_id', prior.id, 'attempt', prior.attempt,
                              'settled', prior.settled_at is not null);
  end if;
  -- One draft per report version plus one retry (ADR-227 point 2); a version is one visit_reports row.
  select count(*)::int into n from private.model_call_reservations m where m.report_id = r.id;
  if n >= 2 then
    return jsonb_build_object('result', 'rejected', 'reason', 'attempt_limit');
  end if;
  select * into lim from private.ai_function_limits l where l.function_key = 'report_draft_model';
  if lim.function_key is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'limits_missing');
  end if;
  -- ADR-227 point 5 / AI1 contract item 5: no reviewed price reading, no money cap, no call (fail closed).
  if lim.price_in_micro_chf_per_mtok is null or lim.price_out_micro_chf_per_mtok is null then
    return jsonb_build_object('result', 'rejected', 'reason', 'price_missing');
  end if;
  reserve := ceil((lim.reserve_input_tokens::numeric * lim.price_in_micro_chf_per_mtok
                   + lim.max_output_tokens::numeric * lim.price_out_micro_chf_per_mtok) / 1000000)::bigint;
  -- One lock per function for the whole platform: the day and month caps are global (the founder's money), so two
  -- reservations at cap - 1 in any two organisations are serialised and exactly one is admitted.
  perform pg_advisory_xact_lock(hashtextextended('navora.model_call_budget:report_draft_model', 0));
  select coalesce(sum(b.calls), 0)::int into used from private.model_call_budget b
    where b.function_key = 'report_draft_model' and b.zurich_day = today;
  if used >= lim.day_calls then
    return jsonb_build_object('result', 'rejected', 'reason', 'budget_day');
  end if;
  m0 := date_trunc('month', today)::date;
  select coalesce(sum(b.charged_micro_chf), 0)::bigint into charged from private.model_call_budget b
    where b.function_key = 'report_draft_model' and b.zurich_day >= m0 and b.zurich_day < (m0 + interval '1 month')::date;
  if charged + reserve > lim.month_cap_micro_chf then
    return jsonb_build_object('result', 'rejected', 'reason', 'budget_month');
  end if;
  insert into private.model_call_budget as b (organization_id, function_key, zurich_day, calls, charged_micro_chf)
  values (r.organization_id, 'report_draft_model', today, 1, reserve)
  on conflict (organization_id, function_key, zurich_day)
  do update set calls = b.calls + 1, charged_micro_chf = b.charged_micro_chf + excluded.charged_micro_chf;
  -- The call counts from here, whatever happens next (invalid answer, timeout, lost settle): fail closed for money.
  insert into private.model_call_reservations (organization_id, team_id, function_key, report_id, attempt,
                                               idempotency_key, zurich_day, reserved_micro_chf)
  values (r.organization_id, r.team_id, 'report_draft_model', r.id, n + 1, p_idempotency_key, today, reserve)
  returning id into rid;
  return jsonb_build_object('result', 'ok', 'reservation_id', rid, 'attempt', n + 1);
end;
$function$;

revoke all on function public.reserve_report_draft_call(p_report_id uuid, p_idempotency_key uuid) from public, anon, authenticated, service_role;
grant execute on function public.reserve_report_draft_call(p_report_id uuid, p_idempotency_key uuid) to authenticated;
comment on function public.reserve_report_draft_call(p_report_id uuid, p_idempotency_key uuid) is 'AI1, ADR-227 points 1, 2, 5: reserves one model call for the performer''s open report before the provider is called. Same closed-check as the gate; at most two attempts per report version; a repeat of the key returns the same reservation (no second call); global day and month caps under one lock; no reviewed price reading = refused. Result ok | duplicate | rejected (reason).';

-- public.settle_report_draft_call: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.settle_report_draft_call). No text patch.

-- public.settle_report_draft_call(p_reservation_id uuid, p_outcome text, p_input_tokens integer, p_output_tokens integer, p_latency_ms integer)
CREATE OR REPLACE FUNCTION public.settle_report_draft_call(p_reservation_id uuid, p_outcome text, p_input_tokens integer, p_output_tokens integer, p_latency_ms integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid     uuid := (select auth.uid());
  m       private.model_call_reservations%rowtype;
  r       public.visit_reports%rowtype;
  lim     private.ai_function_limits%rowtype;
  settled bigint;
  basis   text;
begin
  if p_outcome is null or p_outcome not in ('ok', 'invalid', 'max_tokens', 'timeout', 'provider_error') then
    raise exception 'outcome invalid' using errcode = '22023';
  end if;
  if (p_input_tokens is null) <> (p_output_tokens is null)
     or p_input_tokens not between 0 and 1000000 or p_output_tokens not between 0 and 100000 then
    raise exception 'token counts invalid' using errcode = '22023';
  end if;
  if p_latency_ms is null or p_latency_ms not between 0 and 600000 then
    raise exception 'latency invalid' using errcode = '22023';
  end if;
  perform private.assert_access_open();  -- LEAVE1: an ended access settles nothing; the call stays charged at its reserve
  select * into m from private.model_call_reservations x where x.id = p_reservation_id for update;
  if m.id is not null then
    select * into r from public.visit_reports v where v.id = m.report_id;
  end if;
  -- Organisation and team come from the reservation, never from a parameter: no caller can move another budget.
  if m.id is null or uid is null or r.performer_id is distinct from uid or not private.is_org_member(m.organization_id)
     or not private.is_team_member(m.team_id) then
    return jsonb_build_object('result', 'rejected', 'reason', 'not_found');
  end if;
  if m.settled_at is not null then
    return jsonb_build_object('result', 'duplicate', 'settled_micro_chf', m.settled_micro_chf);
  end if;
  select * into lim from private.ai_function_limits l where l.function_key = m.function_key;
  if p_input_tokens is null or lim.price_in_micro_chf_per_mtok is null or lim.price_out_micro_chf_per_mtok is null then
    settled := m.reserved_micro_chf;  -- nothing measured: the call stays charged at its reserve
    basis := 'reserve';
  else
    settled := ceil((p_input_tokens::numeric * lim.price_in_micro_chf_per_mtok
                     + p_output_tokens::numeric * lim.price_out_micro_chf_per_mtok) / 1000000)::bigint;
    basis := 'measured_tokens';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('navora.model_call_budget:' || m.function_key, 0));
  update private.model_call_budget b
     set charged_micro_chf = b.charged_micro_chf + (settled - m.reserved_micro_chf)
   where b.organization_id = m.organization_id and b.function_key = m.function_key and b.zurich_day = m.zurich_day;
  update private.model_call_reservations x
     set settled_at = private.now(), outcome = p_outcome, input_tokens = p_input_tokens, output_tokens = p_output_tokens,
         latency_ms = p_latency_ms, settled_micro_chf = settled, cost_basis = basis
   where x.id = m.id;
  return jsonb_build_object('result', 'ok', 'settled_micro_chf', settled, 'cost_basis', basis);
end;
$function$;

revoke all on function public.settle_report_draft_call(p_reservation_id uuid, p_outcome text, p_input_tokens integer, p_output_tokens integer, p_latency_ms integer) from public, anon, authenticated, service_role;
grant execute on function public.settle_report_draft_call(p_reservation_id uuid, p_outcome text, p_input_tokens integer, p_output_tokens integer, p_latency_ms integer) to authenticated;
comment on function public.settle_report_draft_call(p_reservation_id uuid, p_outcome text, p_input_tokens integer, p_output_tokens integer, p_latency_ms integer) is 'AI1, ADR-227 point 1: records outcome, measured tokens and latency of one reserved model call (team level, no person column, no text) and replaces the reserve with the measured cost. Only the performer of the reserved report; once only; organisation from the reservation.';

comment on function public.report_draft_model_gate(uuid) is
  'AUT-138, AUT-152, ADR-215, ADR-227: whether the caller may get a model report draft for this report now (open) or why '
  'not (not_team_member, not_draft, not_performer, not_simulation_org, switched_off, ledger_missing, no_threshold, '
  'stop_rule). Reads only.';
