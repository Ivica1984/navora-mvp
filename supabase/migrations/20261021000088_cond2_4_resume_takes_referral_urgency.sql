-- COND2-4 = IPA1-C2 (brief docs/agents/briefs/COND2.md, added by po 2026-10-27 02:10; `cra` CGR-71). ADR-102.
-- Builds on 0034 (RET1, link_returning_referral, team_cases), 0086 (IPA1-7/-8 columns) and 0074 (LEAVE1-3 guard).
--
-- Problem: when a returning referral resumes a PAUSED case, no case and no matching request is inserted, so the 0086
-- BEFORE INSERT triggers never carry the new referral's urgency, its source or the referrer's requested start. They
-- stayed on partner_requests, which the team cannot read; the team kept reading the first referral's values.
--
-- Choice (brief: "recording on the case is preferred"): the resume path RECORDS the new request's values on the case.
--   * public.link_returning_referral, resume branch only: after the case facts, one update sets
--       cases.urgency          := partner_requests.urgency            (not null on the request)
--       cases.urgency_source   := partner_requests.urgency_source     ('unknown' for a request recorded before IPA1-7)
--       cases.referrer_requested_start := coalesce(request date, case date)   (no date on the request: never blanked)
--     Old and new values go into the existing change_log row of the resume (same actor, reason and idempotency key as
--     the order and funding facts; command 'update_case_intake'), and audit_cases (0086) records them in audit_events.
--   * The "return" path (closed case → new case) and convert_partner_request are unchanged (0086 triggers).
--   * The body is the current one (0034 in the DST1 clock form of ADR-081: private.now(), private.at_zurich) with that
--     one step added (marked COND2-4) and the diff list extended; nothing else changes.
-- Team view: public.team_cases returns `return_urgency_source` and `return_referrer_requested_start` for a case only
--   while its `review_after_pause` task is open (the place where the team handles the return), else null.
--   COND2-4a (po 06:10, `cra` CGR-73): `return_referrer_requested_start` is read from THIS return's request (the case's
--   newest `referral_links` row of kind 'resume' and its `partner_requests` row), not from the case: when the request
--   carried no date the team reads null ("nicht angegeben"); the case's kept date is not shown as this referrer's
--   statement. Two resumes of one case are always separate transactions (a pause lies between them), so the newest
--   link by created_at is this return (CGR-74: created_at now defaults to private.now(), step 1b); id only breaks
--   an exact tie. team_cases
--   already returns `urgency`; it keeps its ORDER BY (name) and its LEAVE1-3 guard. No other column, no new grant.
-- Display only (as IPA1-8): no order, filter, deadline, signal, readiness item or visit reads the new values. A
--   resumed case has its team and its (closed or decided) matching request, so open_matching_if_ready does not run and
--   team_offers (G3) is not touched.
--
-- No clinical rule: which level or date the care decision relies on stays `clinical` (D-15, P-14). No read scope is
-- widened: the team reads its own case; the values are the referral's intake facts it would have seen in an offer.
-- Idempotent: create or replace; the team_cases patch is skipped when its marker is present.

-- 1. The resume path records the new referral's urgency, source and requested start ------------------------------------
create or replace function public.link_returning_referral(
  p_request_id uuid, p_case_id uuid, p_reason text, p_first_name text, p_last_name text,
  p_consent_confirmed boolean, p_facts jsonb, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  why      text;
  req      public.partner_requests%rowtype;
  prev     public.cases%rowtype;
  after    public.cases%rowtype;
  v_kind   text;
  first_n  text;
  last_n   text;
  new_case uuid;
  missing  jsonb;
  diff     jsonb := '{}'::jsonb;
  f        text;
  pause_reason text;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_consent_confirmed is distinct from true then
    raise exception 'consent confirmation is required (provisional gate, ADR-026)' using errcode = '22023';
  end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('link_returning_referral', p_idempotency_key) then
    perform private.end_command('duplicate');
    return jsonb_build_object('result', 'duplicate',
      'case_id', (select coalesce(l.new_case_id, l.linked_case_id) from public.referral_links l where l.partner_request_id = p_request_id));
  end if;

  select * into req from public.partner_requests where id = p_request_id for update;
  if not found or not private.is_intake_role(req.organization_id) or req.status not in ('open', 'ready_to_convert') then
    perform private.end_command('rejected');
    return jsonb_build_object('result', 'rejected');
  end if;
  select * into prev from public.cases where id = p_case_id and organization_id = req.organization_id for update;
  v_kind := case when found then private.linkable_kind(prev.id, req.organization_id) end;
  if v_kind is null then
    perform private.end_command('not_linkable');
    return jsonb_build_object('result', 'not_linkable');   -- other organisation, active, or closed too long ago
  end if;

  if v_kind = 'paused' then
    -- Resume the case with its team and primary nurse; apply changed funding and order facts; readiness again.
    perform private.apply_case_facts(prev.id, coalesce(p_facts, '{}'::jsonb));
    -- COND2-4 (IPA1-C2, CGR-71): the new referral's level, its source and the referrer's date are recorded on the case.
    -- A request without a date leaves the case's date as it is (never blanked). Display only: nothing orders by them.
    update public.cases c
       set urgency = req.urgency,
           urgency_source = coalesce(req.urgency_source, 'unknown'),
           referrer_requested_start = coalesce(req.referrer_requested_start, c.referrer_requested_start)
     where c.id = prev.id;
    select * into after from public.cases where id = prev.id;
    foreach f in array array['insurer_name', 'insurance_type', 'medical_order_status', 'medical_order_valid_until',
                             'urgency', 'urgency_source', 'referrer_requested_start'] loop
      if to_jsonb(prev) -> f is distinct from to_jsonb(after) -> f then
        diff := diff || jsonb_build_object(f, jsonb_build_object('old', to_jsonb(prev) -> f, 'new', to_jsonb(after) -> f));
      end if;
    end loop;
    if diff <> '{}'::jsonb then
      insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
      values (prev.organization_id, 'cases', prev.id::text, 'update_case_intake', diff, why, uid, p_idempotency_key);
    end if;
    perform private.sync_case_tasks(prev.id);
    missing := private.case_readiness(prev.id);

    select l.reason_code into pause_reason from public.case_lifecycle_events l
      where l.case_id = prev.id and l.kind = 'pause' order by l.created_at desc limit 1;
    insert into public.case_lifecycle_events (organization_id, case_id, kind, note, actor_id, idempotency_key)
    values (prev.organization_id, prev.id, 'resume', 'Rückkehr: ' || why, uid, p_idempotency_key);
    update public.cases set lifecycle = 'active' where id = prev.id;
    update public.care_visits v set suspended_at = null, suspended_by = null
    where v.case_id = prev.id and v.suspended_at is not null and v.status = 'planned'
      and v.visit_date >= (private.at_zurich(private.now()))::date;
    insert into public.case_tasks (organization_id, case_id, kind, detail)
    values (prev.organization_id, prev.id, 'review_after_pause', pause_reason)
    on conflict (case_id, kind) where status = 'open' do nothing;

    update public.partner_requests set status = 'converted', converted_case_id = prev.id where id = req.id;
    insert into public.referral_links (organization_id, partner_request_id, linked_case_id, kind, reason, actor_id, idempotency_key)
    values (req.organization_id, req.id, prev.id, 'resume', why, uid, p_idempotency_key);
    perform private.end_command('ok');
    return jsonb_build_object('result', 'ok', 'kind', 'resume', 'case_id', prev.id,
                              'ready', jsonb_array_length(missing) = 0, 'missing', missing);
  end if;

  -- Closed within the period: a new case (one case per referral) with a reference to the previous one.
  first_n := private.check_text(p_first_name, 1, 100, 'first name');
  last_n  := private.check_text(p_last_name, 1, 100, 'last name');
  insert into public.cases
    (organization_id, source_partner_request_id, name, first_name, last_name, region, status, urgency, time_info,
     bedarf, care_needs, next_step, intake_consent_confirmed_at, intake_consent_confirmed_by, previous_case_id)
  values
    (req.organization_id, req.id, first_n || ' ' || last_n, first_n, last_n, req.region, 'neu', req.urgency,
     req.time_info, req.request_title, req.requested_services, 'Aufnahme vervollständigen', private.now(), uid, prev.id)
  returning id into new_case;
  perform private.apply_case_facts(new_case, coalesce(p_facts, '{}'::jsonb));
  perform private.sync_case_tasks(new_case);
  missing := private.open_matching_if_ready(new_case);   -- sets the first-refusal window when matching opens
  update public.partner_requests set status = 'converted', converted_case_id = new_case where id = req.id;
  insert into public.referral_links (organization_id, partner_request_id, linked_case_id, new_case_id, kind, reason, actor_id, idempotency_key)
  values (req.organization_id, req.id, prev.id, new_case, 'return', why, uid, p_idempotency_key);
  perform private.end_command('ok');
  return jsonb_build_object('result', 'ok', 'kind', 'return', 'case_id', new_case,
                            'ready', jsonb_array_length(missing) = 0, 'missing', missing);
end;
$$;
revoke all on function public.link_returning_referral(uuid, uuid, text, text, text, boolean, jsonb, uuid) from public, anon;
grant execute on function public.link_returning_referral(uuid, uuid, text, text, text, boolean, jsonb, uuid) to authenticated;

-- 1b. CGR-74 (`cra` 09:30): referral_links.created_at follows the database clock (ADR-081), as the tables since 0073 do.
-- 0034 set `default now()`; team_cases picks this return's link by created_at, and with now() a pinned test clock could
-- not order two links. In production private.now() is now(), so nothing changes there. Idempotent.
alter table public.referral_links alter column created_at set default private.now();

-- 2. team_cases: the return's source and the referrer's date, while the team handles the return -------------------------
do $patch$
declare
  def text := pg_get_functiondef('public.team_cases()'::regprocedure);
  a   text := 'proposed_primary_nurse_id uuid, review_after_pause_reason text)';
  b   text := '(select k.detail from public.case_tasks k where k.case_id = c.id and k.kind = ''review_after_pause'' and k.status = ''open'')';
  add text := ',
         -- COND2-4: shown only while the review task of the return is open.
         case when exists (select 1 from public.case_tasks k where k.case_id = c.id and k.kind = ''review_after_pause'' and k.status = ''open'')
              then c.urgency_source end,
         -- COND2-4a (CGR-73): the date only from THIS return''s request (the newest resume link of the case and its
         -- partner_requests row); a request without a date reads null ("nicht angegeben"), never a kept earlier date.
         case when exists (select 1 from public.case_tasks k where k.case_id = c.id and k.kind = ''review_after_pause'' and k.status = ''open'')
              then (select pr.referrer_requested_start
                      from public.referral_links l join public.partner_requests pr on pr.id = l.partner_request_id
                     where l.linked_case_id = c.id and l.kind = ''resume''
                     order by l.created_at desc, l.id desc limit 1) end';
begin
  if position('COND2-4' in def) > 0 then
    return;   -- already applied
  end if;
  if position(a in def) = 0 or position(b in def) = 0 or position('LEAVE1-3' in def) = 0 then
    raise exception 'team_cases no longer matches the COND2-4 patch';
  end if;
  def := replace(def, a, 'proposed_primary_nurse_id uuid, review_after_pause_reason text, '
                         || 'return_urgency_source text, return_referrer_requested_start date)');
  def := replace(def, b, b || add);
  drop function public.team_cases();
  execute def;
  revoke all on function public.team_cases() from public, anon;
  grant execute on function public.team_cases() to authenticated;
end
$patch$;
