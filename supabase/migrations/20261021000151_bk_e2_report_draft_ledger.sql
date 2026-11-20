-- BK-e2 Abschlusspaket (PO package contract 2026-11-19 16:40, brief docs/agents/briefs/BK.md; founder FE-095, FE-096):
-- the AIG1 ledger entry for a model report draft, without text, and the AUT-152 stop rule (ADR-215). Phase A only:
-- synthetic data, simulation organisations, `navora-staging`. No clinical, legal, documentation or tariff rule and no
-- threshold value is set here: the stop-rule value is the `cra` gate's (contract point 2), so this migration ships the
-- table empty and the model stays closed (fail closed) until a reviewed migration writes the row.
--
-- Before (IMPLEMENTED, read in a database built from 0001-0150): the AIG1 ledger (`ai_suggestions`, `ai_confirmations`,
-- 0097) holds rows of rule agents only; no agent of kind `ai` is registered (pgTAP 108 (5)); the report-draft model path
-- is closed in the app by the constant `MODEL_LEDGER_READY = false` (AUT-138, AUT-153; resolver guard on #1527).
-- Now (IMPLEMENTED in this migration):
--   1. Registration: agent `report_draft_model` (kind `ai`, level `G` as `cra` reads DOC-AI, provider `anthropic`,
--      region `us` = the `inference_geo` the app sets explicitly, `lca` 2026-11-19 03:43 (c) (2)); field `summary_line`
--      on `visit_reports.summary`, class `record`. It is never switched on through `set_agent_state`: that command keeps
--      refusing kind `ai` (D-35 rule A) and level G (D-34); no exception is added. The rule substitute gets no ledger row
--      (it is no AI, FE-088 (4)).
--   2. Value form (PO decision, contract point 4, Phase A): no text. `proposed_value` = {line_index, sources, digest,
--      length, model}; `final_value` = {digest, length}. `digest` = HMAC-SHA-256 of the line text with a key kept outside
--      the ledger (`private.report_draft_ledger_key`, 32 random bytes generated in the database at migration time, no
--      grant, never in code or an environment variable). The text itself lives only in the report the carer signs.
--   3. AUT-152 stop rule: `public.report_draft_stop_rules`, one row per agent (share, minimum decided lines, window in
--      days, the `cra` reference), written by migrations only. No row: the model is closed (`no_threshold`). With a row:
--      when the decided lines of the organisation in the trailing window reach the minimum and their correction share
--      (corrected + rejected, the AIG1 predicate `private.aig1_window_stats`) exceeds the share (as AIG1-8), the model is closed
--      (`stop_rule`). Read on every call; no stored stop state.
--   4. `public.report_draft_model_gate(report)`: may the caller get a model draft for this report now? Performer of the
--      open draft, in her team, access not ended, simulation organisation, agent registered, threshold row present,
--      stop rule not reached. The app's `MODEL_LEDGER_READY` is this answer (AUT-138, `aia` gate point 1).
--   5. `public.record_report_draft_proposal(report, model, lines, key)`: the same gate, then one `ai_suggestions` row per
--      proposed line sharing `proposal_id` = the idempotency key; `input_refs` = the report and its visit (identifiers
--      only, AIG1-2); returns the suggestion id per line. A repeat of the key returns the same rows.
--   6. `public.decide_report_draft_line(suggestion, outcome, text, key)`: the performer's decision on one line while the
--      report is a draft: `confirmed` (text unchanged, digest equal), `corrected` (changed text, new digest) or
--      `rejected` (no value). One line per call, `bulk = false` always (no accept-all, `aia` gate point 7). The confirmer
--      is not returned (AIG1-11 (4)); the correction rate stays the AIG1 reader per agent, field and team
--      (`agent_correction_rates`, no person column, cells under three confirmers suppressed; `aia` gate point 9).
-- Phase B (documented in ADR-215, not built): the ledger is append-only with no deletion path (0097); before real data
-- a deletion or anonymisation path and the value form are decided by the owner and the legal adviser (OPEN).
-- Idempotent: `if not exists`, `create or replace`, `on conflict do nothing`.

-- 1. Key outside the ledger ---------------------------------------------------------------------------------------------
create table if not exists private.report_draft_ledger_key (
  id         smallint primary key default 1 check (id = 1),
  key        bytea not null check (octet_length(key) = 32),
  created_at timestamptz not null default private.now()
);
alter table private.report_draft_ledger_key enable row level security;
revoke all on private.report_draft_ledger_key from public, anon, authenticated;
insert into private.report_draft_ledger_key (id, key) values (1, extensions.gen_random_bytes(32))
on conflict (id) do nothing;
comment on table private.report_draft_ledger_key is
  'ADR-215: the HMAC key for report-draft ledger digests. Generated in the database, kept outside the ledger, no grant. '
  'Without it a digest in the ledger cannot be confirmed by guessing a text.';

create or replace function private.report_draft_digest(p_text text)
returns text language plpgsql stable security definer set search_path = ''
as $$
declare k bytea := (select x.key from private.report_draft_ledger_key x where x.id = 1);
begin
  if k is null then
    raise exception 'report draft ledger key missing (ADR-215)' using errcode = '55000';
  end if;
  return encode(extensions.hmac(convert_to(p_text, 'UTF8'), k, 'sha256'), 'hex');
end;
$$;
revoke all on function private.report_draft_digest(text) from public, anon, authenticated;

-- 2. Registration --------------------------------------------------------------------------------------------------------
insert into public.ai_agent_definitions (key, name, level, kind, version, provider, region, fixture, eval_bar, brief)
values ('report_draft_model', 'KI-Berichtsentwurf (Claude)', 'G', 'ai', '1', 'anthropic', 'us', null, null, 'BK')
on conflict (key) do nothing;
insert into public.ai_agent_fields (agent_key, field, target_table, target_column, class)
values ('report_draft_model', 'summary_line', 'visit_reports', 'summary', 'record')
on conflict (agent_key, field) do nothing;

-- 3. AUT-152 stop rule (no row shipped) ----------------------------------------------------------------------------------
create table if not exists public.report_draft_stop_rules (
  agent_key        text primary key references public.ai_agent_definitions (key),
  stop_share       numeric(5, 2) not null check (stop_share >= 0 and stop_share < 100),  -- AIG1-16 (1): 100 is no threshold
  stop_min_decided integer not null check (stop_min_decided between 1 and 100000),
  stop_window_days integer not null check (stop_window_days between 1 and 366),
  cra_ref          text not null check (char_length(btrim(cra_ref)) between 3 and 120),
  created_at       timestamptz not null default private.now()
);
alter table public.report_draft_stop_rules enable row level security;
revoke all on public.report_draft_stop_rules from public, anon, authenticated;
comment on table public.report_draft_stop_rules is
  'AUT-152, ADR-215: the stop threshold of a model agent that is not switched on through set_agent_state. Written by a '
  'reviewed migration only, with the cra reference. No row: the model is closed.';

-- 4. The gate ------------------------------------------------------------------------------------------------------------
-- Shared check; returns null when open, else the reason. Locks nothing; the record command calls it again.
create or replace function private.report_draft_model_closed(p_report public.visit_reports, p_uid uuid)
returns text language plpgsql stable security definer set search_path = ''
as $$
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
$$;
revoke all on function private.report_draft_model_closed(public.visit_reports, uuid) from public, anon, authenticated;

create or replace function public.report_draft_model_gate(p_report_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  r   public.visit_reports%rowtype;
  why text;
begin
  select * into r from public.visit_reports v where v.id = p_report_id;
  why := private.report_draft_model_closed(r, (select auth.uid()));
  return jsonb_build_object('result', 'ok', 'open', why is null, 'reason', why);
end;
$$;
revoke all on function public.report_draft_model_gate(uuid) from public, anon;
grant execute on function public.report_draft_model_gate(uuid) to authenticated;
comment on function public.report_draft_model_gate(uuid) is
  'AUT-138, AUT-152, ADR-215: whether the caller may get a model report draft for this report now (open) or why not '
  '(not_team_member, not_draft, not_performer, not_simulation_org, ledger_missing, no_threshold, stop_rule). Reads only.';

-- 5. Recording a proposal ------------------------------------------------------------------------------------------------
create or replace function private.report_draft_lines_ok(p_lines jsonb)
returns boolean language sql immutable set search_path = ''
as $$
  select jsonb_typeof(p_lines) = 'array' and jsonb_array_length(p_lines) between 1 and 100
     and not exists (
       select 1 from jsonb_array_elements(p_lines) e
       where jsonb_typeof(e) <> 'object'
          or jsonb_typeof(e -> 'text') is distinct from 'string'
          or char_length(btrim(e ->> 'text')) not between 1 and 2000
          or jsonb_typeof(e -> 'sources') is distinct from 'array'
          or jsonb_array_length(e -> 'sources') not between 1 and 50
          or exists (select 1 from jsonb_array_elements(e -> 'sources') s
                     where jsonb_typeof(s) <> 'string' or (s #>> '{}') !~ '^[sf][1-9][0-9]{0,3}$'))
$$;
revoke all on function private.report_draft_lines_ok(jsonb) from public, anon, authenticated;

create or replace function public.record_report_draft_proposal(p_report_id uuid, p_model text, p_lines jsonb,
                                                               p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid  uuid := (select auth.uid());
  r    public.visit_reports%rowtype;
  why  text;
  ver  text;
  done jsonb;
begin
  if p_model is null or p_model !~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$' then
    raise exception 'model id invalid' using errcode = '22023';
  end if;
  if not private.report_draft_lines_ok(p_lines) then
    raise exception 'lines invalid' using errcode = '22023';
  end if;
  if private.begin_command('record_report_draft_proposal', p_idempotency_key) then
    perform private.end_command('duplicate');
    select jsonb_agg(jsonb_build_object('line_index', (s.proposed_value ->> 'line_index')::int, 'suggestion_id', s.id)
                     order by s.seq)
      into done from public.ai_suggestions s
      where s.proposal_id = p_idempotency_key and s.agent_key = 'report_draft_model' and s.entity_id = p_report_id;
    return jsonb_build_object('result', 'duplicate', 'proposal_id', p_idempotency_key, 'lines', coalesce(done, '[]'::jsonb));
  end if;
  select * into r from public.visit_reports v where v.id = p_report_id for update;
  why := private.report_draft_model_closed(r, uid);
  if why is not null then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', why);
  end if;
  select d.version into ver from public.ai_agent_definitions d where d.key = 'report_draft_model';
  insert into public.ai_suggestions (proposal_id, organization_id, team_id, case_id, agent_key, agent_version, field,
                                     entity_type, entity_id, input_refs, proposed_value)
  select p_idempotency_key, r.organization_id, r.team_id, r.case_id, 'report_draft_model', ver, 'summary_line',
         'visit_reports', r.id,
         jsonb_build_array(jsonb_build_object('table', 'visit_reports', 'id', r.id),
                           jsonb_build_object('table', 'care_visits', 'id', r.visit_id)),
         jsonb_build_object('line_index', (l.n - 1)::int,
                            'sources', (select jsonb_agg(distinct x) from jsonb_array_elements_text(l.e -> 'sources') x),
                            'digest', private.report_draft_digest(btrim(l.e ->> 'text')),
                            'length', char_length(btrim(l.e ->> 'text')),
                            'model', p_model)
  from jsonb_array_elements(p_lines) with ordinality l(e, n)
  order by l.n;
  select jsonb_agg(jsonb_build_object('line_index', (s.proposed_value ->> 'line_index')::int, 'suggestion_id', s.id)
                   order by s.seq)
    into done from public.ai_suggestions s
    where s.proposal_id = p_idempotency_key and s.agent_key = 'report_draft_model' and s.entity_id = r.id;
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'proposal_id', p_idempotency_key, 'lines', done);
end;
$$;
revoke all on function public.record_report_draft_proposal(uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.record_report_draft_proposal(uuid, text, jsonb, uuid) to authenticated;
comment on function public.record_report_draft_proposal(uuid, text, jsonb, uuid) is
  'ADR-215: records a model report draft in the AIG1 ledger before it is shown: one row per line, no text (line index, '
  'source ids, keyed digest, length, model id). Refused with the gate''s reason when the model is closed.';

-- 6. Deciding one line ---------------------------------------------------------------------------------------------------
create or replace function public.decide_report_draft_line(p_suggestion_id uuid, p_outcome text, p_text text,
                                                           p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  s   public.ai_suggestions%rowtype;
  r   public.visit_reports%rowtype;
  dg  text;
  fv  jsonb;
begin
  if p_outcome is null or p_outcome not in ('confirmed', 'corrected', 'rejected') then
    raise exception 'outcome invalid' using errcode = '22023';
  end if;
  if (p_outcome = 'rejected') <> (p_text is null) then
    raise exception 'a rejected line has no text; a taken line has its text' using errcode = '22023';
  end if;
  if p_text is not null and char_length(btrim(p_text)) not between 1 and 2000 then
    raise exception 'text length invalid' using errcode = '22023';
  end if;
  if private.begin_command('decide_report_draft_line', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate');
  end if;
  select * into s from public.ai_suggestions x where x.id = p_suggestion_id and x.agent_key = 'report_draft_model';
  if found then
    select * into r from public.visit_reports v where v.id = s.entity_id for update;
  end if;
  if r.id is null or uid is null or not private.is_org_member(r.organization_id) or not private.is_team_member(r.team_id)
     or private.access_ended(uid) then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_team_member');
  end if;
  if r.status <> 'draft' then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_draft');
  end if;
  if r.performer_id <> uid then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected', 'reason', 'not_performer');
  end if;
  if p_text is not null then
    dg := private.report_draft_digest(btrim(p_text));
    if (p_outcome = 'confirmed') <> (dg = s.proposed_value ->> 'digest') then
      perform private.end_command('rejected');
      return jsonb_build_object('result', 'rejected',
                                'reason', case when p_outcome = 'confirmed' then 'text_changed' else 'text_unchanged' end);
    end if;
    fv := jsonb_build_object('digest', dg, 'length', char_length(btrim(p_text)));
  end if;
  insert into public.ai_confirmations (suggestion_id, organization_id, team_id, outcome, final_value, bulk, confirmed_by)
  values (s.id, s.organization_id, s.team_id, p_outcome, fv, false, uid);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok');
end;
$$;
revoke all on function public.decide_report_draft_line(uuid, text, text, uuid) from public, anon;
grant execute on function public.decide_report_draft_line(uuid, text, text, uuid) to authenticated;
comment on function public.decide_report_draft_line(uuid, text, text, uuid) is
  'ADR-215: the performer decides one line of a model draft while the report is a draft: confirmed (unchanged), '
  'corrected (changed) or rejected. Never in bulk. Stores digests only.';
