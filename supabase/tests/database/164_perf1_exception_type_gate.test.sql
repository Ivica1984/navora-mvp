-- PERF1 (ADR-226, brief docs/agents/briefs/PERF1.md scope (1) and (5), PO amendment 2026-11-21 20:39 (4); migration 0164).
-- Red on 0163: private.derived_exceptions_of does not exist, and team_visit_alerts / evaluate_signals call
-- private.order_cover once per confirmed order. Green on 0164.
-- (1) Equivalence: the pre-PERF1 bodies of derived_exceptions and team_visit_alerts (taken unchanged from their canonical
--     files at f02f429, the commit before the change, as pg_temp copies) return exactly the rows of the new path, for
--     every organisation of the seed plus N synthetic confirmed orders: derived_exceptions (operations_exceptions,
--     sync_exceptions, open_exception_org read it), the gated variant for the type list of each caller, and
--     team_visit_alerts for two nurses.
-- (2) Catalogue: every type private.signal_kind_of maps is in the evaluator's gate list, so a new signal type cannot be
--     gated out silently; every type the old body emits on the fixture is one of the 24 branch types named here.
-- (3) Budget, deterministic first (AUT-186): with N = 300 confirmed orders in one organisation (PO assumption for the
--     simulation horizon, not a measurement), team_visit_alerts and evaluate_signals call private.order_cover 0 times
--     (pg_stat_xact_user_functions; track_functions = all is set by the db job, asserted first, and the positive control
--     proves the counter counts); a loose wall-clock limit of 2 s per call (estimate) only catches order-of-magnitude
--     regressions, the measured values are printed as diagnostics.
-- Users: pflegebs …9e6 (nurse, Testteam Basel, org S), pflege …902 (nurse, Testteam Nord, org A). Fixture: client
-- account …3f1 and orders …c164-… in org S, 150 started in the past, 150 in the future. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.order_cover_calls() returns bigint language sql volatile as $$
  select coalesce((select s.calls from pg_stat_xact_user_functions s
                   where s.schemaname = 'private' and s.funcname = 'order_cover'), 0)
$$;

-- 0. Surface and counter ----------------------------------------------------------------------------------------------
select has_function('private', 'derived_exceptions_of', array['uuid', 'text[]'], 'ADR-226: private.derived_exceptions_of exists');
select is(current_setting('track_functions'), 'all', 'the db job sets track_functions = all, so the call counts below measure');

-- Pre-PERF1 bodies (frozen copies; security definer dropped: pg_temp, run by the test owner) ----------------------------
CREATE FUNCTION pg_temp.derived_exceptions_old(p_org uuid)
 RETURNS TABLE(exception_key text, exception_type text, since timestamp with time zone, case_id uuid, team_id uuid, entity_type text, entity_id uuid, detail text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  with rules as (select * from private.effective_exception_rules(p_org))
  -- J1: case not ready for matching after the threshold (working time from the referral)
  select 'case_not_ready:' || c.id, 'case_not_ready', p.created_at, c.id, null::uuid, 'case', c.id,
         (select string_agg(m.value ->> 'reason', '; ' order by m.ord) /* UXR-181 */ from jsonb_array_elements(private.case_readiness(c.id)) with ordinality m(value, ord))
  from public.cases c
  join public.partner_requests p on p.id = c.source_partner_request_id, rules r
  where r.exception_type = 'case_not_ready' and c.organization_id = p_org and c.ready_for_matching_at is null
    and private.now() >= private.after_threshold(p.created_at, r.amount, r.unit)
  union all
  -- SAFE-D11 R2 (ADR-184): a reopened case without a team and without an open team search (closes with its cause)
  select 'case_reopened_no_team:' || c.id || ':' || extract(epoch from c.reopened_at)::bigint, 'case_reopened_no_team',
         c.reopened_at, c.id, null::uuid, 'case', c.id,
         (select string_agg(m.value ->> 'reason', '; ' order by m.ord) /* UXR-181 */ from jsonb_array_elements(private.case_readiness(c.id)) with ordinality m(value, ord))
  from public.cases c
  join rules r on r.exception_type = 'case_reopened_no_team'
  where c.organization_id = p_org and c.lifecycle = 'active' and c.assigned_team_id is null
    and c.reopened_at is not null and c.ready_for_matching_at is not null
    and not exists (select 1 from public.matching_requests m where m.case_id = c.id and m.status = 'open')
  union all
  -- SAFE-D11 R4: a reopened case whose team is no longer active (closes with its cause; never reassigns)
  select 'case_reopened_team_inactive:' || c.id || ':' || extract(epoch from c.reopened_at)::bigint, 'case_reopened_team_inactive',
         c.reopened_at, c.id, c.assigned_team_id, 'case', c.id, null::text
  from public.cases c
  join public.teams t on t.id = c.assigned_team_id
  join rules r on r.exception_type = 'case_reopened_team_inactive'
  where c.organization_id = p_org and c.lifecycle <> 'closed' and c.reopened_at is not null
    and t.status is distinct from 'active'
  union all
  -- BK-C1 (ADR-199 (9)): a confirmed shift order that is not covered (closes with its cause)
  select 'order_not_covered:' || p.id, 'order_not_covered', c.latest_cover_at, null::uuid, null::uuid,
         'order', p.id, c.cover_detail
  from public.partner_requests p
  cross join lateral private.order_cover(p.id, private.now()) c
  join rules r on r.exception_type = 'order_not_covered'
  where p.organization_id = p_org and p.order_kind is not null and p.confirmed_at is not null
    and c.cover_state = 'not_covered'
  union all
  -- BK-E1B-S (CGR-246, ADR-203 (12)): a live take whose named member no longer passes while its visit is under way
  -- or still planned after the start; P1 to her own team and to her (SIG1), closes with its cause; code detail only
  select 'take_member_dropped:' || k.id, 'take_member_dropped',
         case when v.status = 'planned' then o.starts_at else coalesce(last.at, o.starts_at) end,
         v.case_id, k.team_id, 'visit', v.id, 'step_' || st.step
  from public.order_takes k
  join public.partner_requests o on o.id = k.order_id
  join public.care_visits v on v.order_take_id = k.id
  cross join lateral (select private.order_member_step(o.id, k.team_id, k.member_id) as step) st
  left join lateral (select max(e.occurred_at) as at from public.visit_events e where e.visit_id = v.id) last on true
  join rules r on r.exception_type = 'take_member_dropped'
  where k.organization_id = p_org and k.released_at is null and st.step < 4
    and (v.status in ('on_the_way', 'started', 'paused')
         or (v.status = 'planned' and private.now() >= o.starts_at))
  union all
  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)
  select case e.reason when 'deadline_passed' then 'offer_overdue:' when 'deadline_not_configured' then 'deadline_missing:'
                       else 'candidates_exhausted:' end || e.matching_request_id,
         case e.reason when 'deadline_passed' then 'offer_overdue' when 'deadline_not_configured' then 'deadline_missing'
                       else 'candidates_exhausted' end,
         coalesce(e.response_due_at, e.created_at), m.case_id, null::uuid, 'matching_request', e.matching_request_id,
         e.request_title || coalesce(' · Absagen: ' || (select string_agg(coalesce(d ->> 'team', 'Team') || ' (' || coalesce(d ->> 'code', '?') || ')', ', ')
                                                        from jsonb_array_elements(e.declines) d), '')
  from private.matching_escalations_for(p_org) e
  join public.matching_requests m on m.id = e.matching_request_id
  union all
  -- J3: uncovered visits in the next 24 h (P1 when the case came as a hospital discharge)
  select case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital:' else 'visit_uncovered:' end || v.id,
         case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end,
         private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
  from public.care_visits v
  left join lateral (select x.referral_type from public.matching_requests x where x.case_id = v.case_id order by x.created_at desc limit 1) mr on true
  join rules r on r.exception_type = case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.suspended_at is null and v.covered_by is null
    and (private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
          <= private.after_threshold(private.now(), r.amount, r.unit)
         -- SIG2-6: a window that opens outside the watched hours opens at the end of the last watched period before
         or (r.exception_type = 'visit_uncovered_hospital'
             and private.lookahead_raised(p_org, private.now(), /* SIG2-14 (ADR-078) */
                   private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
                   - (private.after_threshold(private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), r.amount, r.unit)
                      - private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))))))
  union all
  -- COVER1: covered by another team but not yet performable (no access before D-3); since = start − 24 h,
  -- so the rule's escalation (20 h) makes it P1 from 4 h before the start
  select 'cover_without_access:' || v.id, 'cover_without_access',
         private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))) - interval '24 hours', v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
           || ' · übernommen von ' || coalesce((select t.name from public.teams t where t.id = v.cover_team_id), 'einem anderen Team')
  from public.care_visits v
  join rules r on r.exception_type = 'cover_without_access'
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.suspended_at is null
    and v.covered_by is not null
    and private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
        between private.now() and private.after_threshold(private.now(), r.amount, r.unit)
  union all
  -- J3: medical order expiring within the threshold or expired, on a running case
  select 'order_expiring:' || c.id || ':' || c.medical_order_valid_until, 'order_expiring',
         (c.medical_order_valid_until - make_interval(days => coalesce(r.amount, 0)))::timestamptz, c.id, c.assigned_team_id, 'case', c.id,
         'gültig bis ' || to_char(c.medical_order_valid_until, 'DD.MM.YYYY')
  from public.cases c, rules r
  where r.exception_type = 'order_expiring' and c.organization_id = p_org
    and c.assigned_team_id is not null and c.medical_order_status = 'present' and c.medical_order_valid_until is not null
    and c.medical_order_valid_until <= (private.at_zurich(private.now()))::date + coalesce(r.amount, 0)
  union all
  -- J3: care-plan review overdue
  select 'care_plan_review_overdue:' || i.case_id || ':' || min(i.review_date), 'care_plan_review_overdue',
         min(i.review_date)::timestamptz, i.case_id, min(i.team_id::text)::uuid, 'case', i.case_id,
         'Überprüfung fällig seit ' || to_char(min(i.review_date), 'DD.MM.YYYY')
  from public.care_plan_items i
  join public.cases c on c.id = i.case_id
  where c.organization_id = p_org and i.active
  group by i.case_id
  having min(i.review_date) < (private.at_zurich(private.now()))::date
  union all
  -- QG1/legacy: serious quality event open (high, critical); priority escalates after the threshold
  select 'quality_serious_open:' || q.id, 'quality_serious_open', q.created_at, q.case_id, q.team_id, 'quality_event', q.id,
         q.title || case when q.status = 'in_review' then ' · in Bearbeitung' else '' end
  from public.quality_events q
  where q.organization_id = p_org and q.status in ('open', 'in_review') and q.severity in ('high', 'critical')
  union all
  -- F6: report not final 24 h after the visit ended
  select 'report_not_final:' || v.id, 'report_not_final', ended.at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.')
  from public.care_visits v
  join lateral (select max(e.occurred_at) as at from public.visit_events e where e.visit_id = v.id and e.event_type = 'completed') ended on true
  , rules r
  where r.exception_type = 'report_not_final' and v.organization_id = p_org and v.status = 'completed'
    and ended.at is not null
    and private.now() >= private.after_threshold(ended.at, r.amount, r.unit)
    and not exists (select 1 from public.visit_reports vr where vr.visit_id = v.id and vr.status = 'final')

  union all
  -- C1: client not reached (no-show) — P1 until the team records the outcome
  select 'no_show_open:' || v.id, 'no_show_open', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         private.no_show_ops_detail(v.id)  -- DOOR1-11: codes only, no note text
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'no_show'
  where v.organization_id = p_org and v.status = 'no_show'
    and not exists (select 1 from public.visit_status_notes o where o.visit_id = v.id and o.kind = 'no_show_outcome')
  union all
  -- C1: visit cancelled by the team shortly before it was due (continuity)
  select 'team_cancellation_late:' || v.id, 'team_cancellation_late', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'cancelled' and s.reason_code = 'team_cancelled', rules r
  where r.exception_type = 'team_cancellation_late' and v.organization_id = p_org and v.status = 'cancelled'
    -- open until closed in OPS1, or until the team planned a replacement for the case on that day
    and not exists (select 1 from public.care_visits x where x.case_id = v.case_id and x.visit_date = v.visit_date
                      and x.status <> 'cancelled' and x.created_at > s.created_at)
    and private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
        < private.after_threshold(s.created_at, r.amount, r.unit)
  union all
  -- CSR1 / CGR-04: planned visit not started after its planned start (whoever is responsible)
  select 'visit_overdue:' || v.id, 'visit_overdue',
         private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '') || ' · '
           || case
                when v.responsible_user_id is null and v.covered_by is not null then 'von einem anderen Team übernommen'
                when v.responsible_user_id is null then 'niemand zuständig'
                when not exists (select 1 from public.team_memberships tm
                                 where tm.team_id = v.team_id and tm.user_id = v.responsible_user_id)
                  then 'zuständige Person nicht mehr im Team'
                else 'zuständig: ' || coalesce(private.member_name(v.organization_id, v.responsible_user_id), 'Teammitglied')
              end
  from public.care_visits v
  join rules r on r.exception_type = 'visit_overdue'
  where v.organization_id = p_org and v.status = 'planned' and v.suspended_at is null
    and private.now() >= private.after_threshold(private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), r.amount, r.unit)
  union all
  -- CSR1 / CGR-04: visit left on the way, started or paused (from the last status change; started: not before the planned end)
  select 'visit_stuck:' || v.id || ':' || coalesce(last.id::text, '0'), 'visit_stuck', st.ref, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '') || ' · '
           || case v.status when 'on_the_way' then 'unterwegs' when 'started' then 'begonnen' else 'pausiert' end
           || ' seit ' || to_char(private.at_zurich(coalesce(last.at, st.ref)), 'DD.MM. HH24:MI')
  from public.care_visits v
  left join lateral (select e.id, e.occurred_at as at from public.visit_events e
                     where e.visit_id = v.id order by e.occurred_at desc, e.id desc limit 1) last on true
  cross join lateral (select case
           when v.status = 'started' and coalesce(v.time_end, v.time_start) is not null
             then greatest(coalesce(last.at, '-infinity'::timestamptz),
                           private.at_zurich((v.visit_date + coalesce(v.time_end, v.time_start)
                              + case when v.time_end < v.time_start then interval '1 day' else interval '0' end)))
           else coalesce(last.at, private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))))
         end as ref) st
  join rules r on r.exception_type = 'visit_stuck'
  where v.organization_id = p_org and v.status in ('on_the_way', 'started', 'paused')
    and private.now() >= private.after_threshold(st.ref, r.amount, r.unit)
  union all
  -- CSR1 / CGR-25 (PROVISIONAL, D-31): a visit ended as not completed, until a person records the follow-up decision
  select 'visit_interrupted:' || v.id, 'visit_interrupted', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '') || ' · '
           || case s.reason_code
                when 'client_transferred' then 'Klient:in verlegt bzw. ins Spital gebracht'
                when 'client_declined' then 'Klient:in lehnt die Fortsetzung ab'
                when 'nurse_unavailable' then 'Pflegeperson abberufen oder unwohl'
                when 'started_by_mistake' then 'Irrtümlich gestartet'
                else 'Anderer Grund'
              end
           || case when s.note is not null then ' · Notiz im Team' else '' end  -- DOOR1-11
           || case when s.reason_code = 'client_transferred' then
                coalesce(' · nächster geplanter Einsatz: ' || (
                  select to_char(n.visit_date, 'DD.MM.') || coalesce(' ' || to_char(n.time_start, 'HH24:MI'), '')
                  from public.care_visits n
                  where n.case_id = v.case_id and n.organization_id = v.organization_id and n.id <> v.id
                    and n.status = 'planned'
                    and private.at_zurich((n.visit_date + coalesce(n.time_start, time '23:59'))) >= s.created_at
                  order by n.visit_date, n.time_start nulls last, n.id
                  limit 1), ' · kein weiterer Einsatz geplant')
              else '' end
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'interrupted'
  join rules r on r.exception_type = 'visit_interrupted'
  where v.organization_id = p_org and v.status = 'interrupted'
    and not exists (select 1 from public.visit_status_notes f where f.visit_id = v.id and f.kind = 'interruption_followup')
  union all
  -- CSR1 / CGR-24 (PROVISIONAL, D-28): a report correction that is not final after the report_not_final threshold
  select 'report_correction_open:' || c.id, 'report_correction_open', c.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
           || ' · Korrektur Version ' || c.version
           || case when c.status = 'signed' then ' · unterschrieben, Gegenzeichnung offen' else ' · nicht unterschrieben' end
  from public.visit_reports c
  join public.care_visits v on v.id = c.visit_id and v.organization_id = c.organization_id
  join rules t on t.exception_type = 'report_not_final'
  join rules r on r.exception_type = 'report_correction_open'
  where c.organization_id = p_org and c.supersedes_id is not null and c.status in ('draft', 'signed')
    and c.return_id is null  -- F6R: a return version is no correction; report_not_final still raises
    and private.now() >= private.after_threshold(c.created_at, t.amount, t.unit)
  union all
  -- ORD0-4 (CGR-38): B care on an order present without an end date; a prompt, never a block (closes with its cause)
  select 'order_without_end_date:' || c.id || coalesce(':' || e.id, ''), 'order_without_end_date',
         coalesce(e.started_at, private.now()), c.id, c.assigned_team_id, 'case', c.id,
         'Verordnung vorhanden, ohne Enddatum · B-Leistung aktiv'
  from public.cases c
  join rules r on r.exception_type = 'order_without_end_date'
  left join private.order_open_end_episodes e on e.case_id = c.id and e.ended_at is null
  where c.organization_id = p_org and private.order_without_end_date_holds(c.id)
  union all
  -- ADM2-15 (b) (CGR-72): an open case still names a primary or deputy nurse whose access ended (closes with its cause)
  select 'successor_needed:' || s.case_id || ':' || s.role || ':' || s.user_id, 'successor_needed',
         coalesce(private.adm2_contract_ended_at(s.user_id), private.now()), s.case_id, s.team_id, 'case', s.case_id,
         case s.role when 'primary' then 'Bezugspflege' else 'Stellvertretung' end || ' · Zugang beendet'
  from private.successor_needed(p_org) s
  join rules r on r.exception_type = 'successor_needed'
  union all
  -- AIG1-8: an agent stopped by its threshold or a version change (AIG1-C5: listed per stop while it has an open line)
  select 'agent_stopped:' || st.id, 'agent_stopped', st.created_at, null::uuid, null::uuid, 'ai_agent_stop', st.id,
         d.name || ' · ' || 'Werte: ' || (select count(*) from private.aig1_lookback(st.id) l where not l.superseded
           and private.aig1_record_open(l.entity_type, l.entity_id)) || ' offen · '
         || (select count(*) from private.aig1_lookback(st.id) l where not l.superseded
           and not private.aig1_record_open(l.entity_type, l.entity_id)) || ' nicht mehr offen' /* AIG1-C1 */
  from public.ai_agent_stops st
  join public.ai_agent_definitions d on d.key = st.agent_key
  join rules r on r.exception_type = 'agent_stopped'
  where st.organization_id = p_org
    and exists (select 1 from private.aig1_lookback(st.id) l where not l.superseded
                and private.aig1_record_open(l.entity_type, l.entity_id))
$function$;

CREATE FUNCTION pg_temp.team_visit_alerts_old()
 RETURNS TABLE(exception_key text, exception_type text, priority text, label text, detail text, since timestamp with time zone, case_id uuid, client_name text, team_id uuid, team_name text, visit_id uuid, taken boolean, flags text[])
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$#variable_conflict use_column
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  return query
with my_teams as (
    select tm.team_id, t.organization_id, t.name
    from public.team_memberships tm
    join public.teams t on t.id = tm.team_id
    where tm.user_id = (select auth.uid())
  ), d as (
    select o.organization_id, x.*
    from (select distinct organization_id from my_teams) o, lateral pg_temp.derived_exceptions_old(o.organization_id) x
    where x.exception_type in ('visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date' /* ORD0-4 */)
      and x.team_id in (select mt.team_id from my_teams mt)
  ), latest as (
    select distinct on (ev.organization_id, ev.exception_key) ev.organization_id, ev.exception_key, ev.kind,
           (ev.kind = 'take' and private.signal_take_lapsed(ev.actor_id, ev.access_seq, ev.created_at)) as take_ended  -- LEAVE1-C4, LEAVE1-C5
    from public.exception_events ev
    where ev.organization_id in (select organization_id from my_teams) and ev.kind in ('take', 'close', 'auto_close')
      and ev.exception_key in (select d.exception_key from d)
    order by ev.organization_id, ev.exception_key, ev.id desc
  )
  select d.exception_key, d.exception_type,
         case when r.escalate_to_p1_after_hours is not null and private.now() >= d.since + make_interval(hours => r.escalate_to_p1_after_hours)
              then 'P1' else r.priority end,
         r.label, private.team_alert_detail(d.exception_type, d.entity_id, d.detail), d.since, d.case_id,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         d.team_id, (select mt.name from my_teams mt where mt.team_id = d.team_id limit 1),
         case when d.entity_type = 'visit' then d.entity_id end,  -- ORD0-4: a case alert has no visit
         coalesce(l.kind = 'take' and not l.take_ended, false),
         -- CSR1 / CGR-32: computed from the absence, never stored
         (case when d.exception_type = 'visit_overdue' and private.visit_responsible_absent(d.entity_id)
               then array['responsible_absent'] else array[]::text[] end)
         -- LEAVE1-C4: the take of a person whose access has ended
         || case when coalesce(l.take_ended, false) then array['take_access_ended'] else array[]::text[] end
  from d
  join lateral private.effective_exception_rules(d.organization_id) r on r.exception_type = d.exception_type
  left join latest l on l.organization_id = d.organization_id and l.exception_key = d.exception_key
  left join public.cases c on c.id = d.case_id
  where l.kind is null or l.kind = 'take' or r.priority = 'P1' or r.escalate_to_p1_after_hours is not null
     or d.exception_type in ('visit_interrupted', 'report_correction_open', 'order_without_end_date')  -- CGR-25, CGR-30: an earlier close never hides it
  order by 3, d.since;
end
$function$;

-- 1. Fixture: N = 300 confirmed shift orders in org S (synthetic) --------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003f1', '00000000-0000-4000-b000-000000000019', 'Haushalt PERF1 Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003f1', '00000000-0000-4000-a000-0000000009e8');
insert into public.partner_requests
  (id, organization_id, partner_name, partner_type, region, city, urgency, urgency_source, request_title, need_summary,
   status, order_kind, client_account_id, starts_at, ends_at, postcode, grade, activity_tags, required_tags, shift_label,
   confirmed_at, confirmed_by)
select ('00000000-0000-4000-c164-' || lpad(i::text, 12, '0'))::uuid, '00000000-0000-4000-b000-000000000019',
       'Haushalt PERF1 Fixture (synthetisch)', 'household', 'Basel-Landschaft', 'Binningen', null, 'unknown',
       'PERF1 Fixture ' || i, 'PERF1 Fixture', 'client_confirmed', 'shift', '00000000-0000-4000-a000-0000000003f1',
       private.now() + (i - 150) * interval '6 hours', private.now() + (i - 150) * interval '6 hours' + interval '4 hours',
       '4102', 'fage_efz', array['C1'], array['C1'], null,
       least(private.now(), private.now() + (i - 150) * interval '6 hours') - interval '7 days', '00000000-0000-4000-a000-0000000009e8'
from generate_series(1, 300) i;
select is((select count(*)::int from public.partner_requests p
           where p.organization_id = '00000000-0000-4000-b000-000000000019' and p.order_kind is not null
             and p.confirmed_at is not null and p.id::text like '00000000-0000-4000-c164-%'), 300,
          'fixture: N = 300 confirmed orders in org S');

-- 2. Equivalence -------------------------------------------------------------------------------------------------------
create temp table de_old on commit drop as
  select o.id as org, x.* from public.organizations o, lateral pg_temp.derived_exceptions_old(o.id) x;
create temp table de_new on commit drop as
  select o.id as org, x.* from public.organizations o, lateral private.derived_exceptions(o.id) x;
select ok((select count(*) from de_old where exception_type = 'order_not_covered') >= 150
          and (select count(distinct exception_type) from de_old) >= 3,
          'the equivalence below is not vacuous: order_not_covered rows and at least three types on the fixture');
select is((select count(*)::int from ((table de_old except all table de_new) union all (table de_new except all table de_old)) d), 0,
          'derived_exceptions(org) returns exactly the rows of the pre-PERF1 body, every organisation (operations_exceptions, sync_exceptions, open_exception_org)');
select is((select count(*)::int from (
             (select org, exception_key, exception_type, since, case_id, team_id, entity_type, entity_id, detail
                from de_old where exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date'])
              except all
              select o.id, x.* from public.organizations o, lateral private.derived_exceptions_of(o.id, array['visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date']) x
                where x.exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date']))
             union all
             (select o.id, x.* from public.organizations o, lateral private.derived_exceptions_of(o.id, array['visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date']) x
                where x.exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date'])
              except all
              select org, exception_key, exception_type, since, case_id, team_id, entity_type, entity_id, detail
                from de_old where exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date']))) d), 0,
          'gated for the team_visit_alerts types: the same rows of those types as the pre-PERF1 body');
select is((select count(*)::int from (
             (select org, exception_key, exception_type, since, case_id, team_id, entity_type, entity_id, detail
                from de_old where exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_uncovered_hospital', 'visit_interrupted', 'no_show_open', 'take_member_dropped'])
              except all
              select o.id, x.* from public.organizations o, lateral private.derived_exceptions_of(o.id, array['visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_uncovered_hospital', 'visit_interrupted', 'no_show_open', 'take_member_dropped']) x
                where x.exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_uncovered_hospital', 'visit_interrupted', 'no_show_open', 'take_member_dropped']))
             union all
             (select o.id, x.* from public.organizations o, lateral private.derived_exceptions_of(o.id, array['visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_uncovered_hospital', 'visit_interrupted', 'no_show_open', 'take_member_dropped']) x
                where x.exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_uncovered_hospital', 'visit_interrupted', 'no_show_open', 'take_member_dropped'])
              except all
              select org, exception_key, exception_type, since, case_id, team_id, entity_type, entity_id, detail
                from de_old where exception_type = any(array['visit_overdue', 'visit_stuck', 'visit_uncovered', 'visit_uncovered_hospital', 'visit_interrupted', 'no_show_open', 'take_member_dropped']))) d), 0,
          'gated for the signal types: the same rows of those types as the pre-PERF1 body');
select is((select count(*)::int from private.derived_exceptions_of('00000000-0000-4000-b000-000000000019', array['order_not_covered'])
           where exception_type <> 'order_not_covered'), 0,
          'a single-type gate returns no row of another single-type branch');

select pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
select results_eq('select * from public.team_visit_alerts() order by exception_key',
                  'select * from pg_temp.team_visit_alerts_old() order by exception_key',
                  'team_visit_alerts as the org S nurse: identical rows before and after');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
select results_eq('select * from public.team_visit_alerts() order by exception_key',
                  'select * from pg_temp.team_visit_alerts_old() order by exception_key',
                  'team_visit_alerts as the org A nurse: identical rows before and after');
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- 3. Catalogue ---------------------------------------------------------------------------------------------------------
select is((with lst as (
             select string_to_array(regexp_replace((regexp_match(pg_get_functiondef('private.evaluate_signals(uuid, boolean)'::regprocedure),
                      'derived_exceptions_of\(p_org, array\[([^]]*)\]'))[1], '[''\s]', '', 'g'), ',') as a)
           select array_agg(t order by t) from unnest(array['case_not_ready', 'case_reopened_no_team', 'case_reopened_team_inactive', 'order_not_covered', 'take_member_dropped', 'offer_overdue', 'deadline_missing', 'candidates_exhausted', 'visit_uncovered', 'visit_uncovered_hospital', 'cover_without_access', 'order_expiring', 'care_plan_review_overdue', 'quality_serious_open', 'report_not_final', 'no_show_open', 'team_cancellation_late', 'visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date', 'successor_needed', 'agent_stopped']) t, lst
           where private.signal_kind_of(t) is not null and not coalesce(t = any (lst.a), false)), null::text[],
          'every type private.signal_kind_of maps is in the gate list of evaluate_signals');
select is((select array_agg(distinct exception_type order by exception_type) from de_old
           where not exception_type = any (array['case_not_ready', 'case_reopened_no_team', 'case_reopened_team_inactive', 'order_not_covered', 'take_member_dropped', 'offer_overdue', 'deadline_missing', 'candidates_exhausted', 'visit_uncovered', 'visit_uncovered_hospital', 'cover_without_access', 'order_expiring', 'care_plan_review_overdue', 'quality_serious_open', 'report_not_final', 'no_show_open', 'team_cancellation_late', 'visit_overdue', 'visit_stuck', 'visit_interrupted', 'report_correction_open', 'order_without_end_date', 'successor_needed', 'agent_stopped'])), null::text[],
          'every type the pre-PERF1 body emits on the fixture is one of the 24 gated branch types');

-- 4. Budget: call count first, time second -------------------------------------------------------------------------------
create temp table budget (step text primary key, calls bigint, ms numeric) on commit drop;
do $$
declare c0 bigint; t0 timestamptz; n int;
begin
  c0 := pg_temp.order_cover_calls(); t0 := clock_timestamp();
  select count(*) into n from private.derived_exceptions('00000000-0000-4000-b000-000000000019');
  insert into budget values ('derived_exceptions', pg_temp.order_cover_calls() - c0, extract(epoch from clock_timestamp() - t0) * 1000);

  perform pg_temp.act_as('00000000-0000-4000-a000-0000000009e6');
  c0 := pg_temp.order_cover_calls(); t0 := clock_timestamp();
  select count(*) into n from public.team_visit_alerts();
  insert into budget values ('team_visit_alerts', pg_temp.order_cover_calls() - c0, extract(epoch from clock_timestamp() - t0) * 1000);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);

  c0 := pg_temp.order_cover_calls(); t0 := clock_timestamp();
  perform private.evaluate_signals('00000000-0000-4000-b000-000000000019', true);
  insert into budget values ('evaluate_signals', pg_temp.order_cover_calls() - c0, extract(epoch from clock_timestamp() - t0) * 1000);
end $$;
select diag('PERF1 budget (N = 300, CI runner): ' || string_agg(step || ' ' || calls || ' order_cover calls, ' || round(ms) || ' ms', '; ' order by step)) from budget;
select ok((select calls from budget where step = 'derived_exceptions') >= 300,
          'positive control: the full derivation calls order_cover at least once per confirmed order (the counter counts)');
select is((select calls from budget where step = 'team_visit_alerts'), 0::bigint,
          'AUT-186: team_visit_alerts calls order_cover 0 times with N = 300 orders');
select is((select calls from budget where step = 'evaluate_signals'), 0::bigint,
          'AUT-186: evaluate_signals calls order_cover 0 times with N = 300 orders');
select ok((select max(ms) from budget where step in ('team_visit_alerts', 'evaluate_signals')) < 2000,
          'secondary budget (estimate): team_visit_alerts and evaluate_signals each below 2 s on the CI runner with N = 300');

select * from finish();
rollback;
