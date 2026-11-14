-- LEAVE1-14 (PO 2026-10-26 02:14 CET, `changes-requested`; source `cra` 2026-10-26 01:26 CET CGR-62, blocking S1):
-- nothing she claimed keeps others from acting once her access ends (brief docs/agents/briefs/LEAVE1.md; ADR-091;
-- remediation plan docs/agents/clinical/remediation/CGR-62.md). Builds on 0063 (SIG1-C1), 0071 (my_signals), 0074,
-- 0076 (LEAVE1).
--
-- Design (ADR-091):
--   1. A safety-signal take whose taker's access has ended no longer stops the step: `private.signal_taken_stops_step`
--      counts only takes with `not private.access_ended(taker_id)`. Both steps read the one predicate (SIG1-5 untaken
--      after the threshold → Operations, in `evaluate_signals`; SIG2's immediate step, in `outside_settle`), so they fire
--      as for an untaken signal. A restore makes her take count again (the predicate is evaluated live, nothing is
--      rewritten). No threshold, recipient or step changes.
--   2. `my_signals` treats such a take as untaken: the shown take prefers a taker with open access; a take of a person
--      whose access has ended is sorted with the untaken signals and carries no name, qualification or time. A new
--      column `taker_access_ended` lets the banner show the fixed text "Übernahme beendet – Zugang beendet" (no reason
--      code, LEAVE1-8). `take_signal`'s "already taken" answer names a taker with open access first.
--   3. `end_member_access` returns `taken_signals`: the number of open signals she had taken (also in the change log
--      and the audit row).
--   4. Takes stay append-only; `safety_signals.taken_by` (the first take) and the SIGC/AN2 measure
--      (`signal_qualified_taken_at`) keep the historical take. Nothing is rewritten.
--   5. Claim inventory (ADR-091): a person whose access has ended is not available for a new claim either. The
--      automatic paths that would give her work again stop: the ABS1 return of released visits after an absence
--      (`may_perform_visit`), the PLAN2 responsible member (`generate_case_plan`: the primary or deputy nurse with an
--      ended access is skipped, so the visit stays uncovered and the existing exceptions apply), and the two manual
--      assignments refuse her with their existing codes (`set_primary_nurse` → `not_in_team`, `plan_visit` →
--      `responsible_not_in_team`; no reason code reaches the team).
--
-- No clinical, tariff or legal rule: the steps, thresholds and exceptions are the ones reviewed for SIG1, SIG2, ABS1
-- and PLAN2. Idempotent: create or replace; every patch carries a marker and is skipped when the marker is present.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.leave1_14_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0078 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0078 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.leave1_14_patch(text, text[], text) from public, anon, authenticated;

-- 1. The one predicate of both steps (LEAVE1-14 (1), CGR-62) -------------------------------------------------------------
create or replace function private.signal_taken_stops_step(p_signal_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.signal_takes t
                 where t.signal_id = p_signal_id and t.stops_escalation
                   and not private.access_ended(t.taker_id))  -- LEAVE1-14 (CGR-62)
$$;
revoke all on function private.signal_taken_stops_step(uuid) from public, anon, authenticated;
comment on function private.signal_taken_stops_step(uuid) is
  'SIG1-C1 (ADR-077) with LEAVE1-14 (CGR-62, ADR-091): somebody whose access is open has taken the signal in a way that '
  'stops the step to Operations. Read by the SIG1-5 step (evaluate_signals) and SIG2''s immediate step (outside_settle). '
  'A take by a person whose access has ended does not count; after a restore it counts again.';

-- 2. take_signal: "already taken" names a taker with open access first -------------------------------------------------
select private.leave1_14_patch('public.take_signal(uuid, uuid)', array[
  E'    where t.signal_id = s.id order by t.stops_escalation desc, t.taken_at, t.id limit 1;',
  E'    where t.signal_id = s.id\n'
  || E'    order by private.access_ended(t.taker_id), t.stops_escalation desc, t.taken_at, t.id limit 1;  -- LEAVE1-14',
  '1'], 'LEAVE1-14');

-- 3. my_signals: a take of a person whose access has ended reads as untaken (LEAVE1-14 (2)) -----------------------------
-- The 0071 body (with the 0074 guard) and one more column, `taker_access_ended`.
drop function if exists public.my_signals();
create function public.my_signals()
returns table (signal_id uuid, signal_kind text, visit_id uuid, visit_date date, time_start time, team_id uuid,
               team_name text, reason text, delivered_at timestamptz, p1_at timestamptz,
               taken_by_me boolean, taken_by_name text, taken_at timestamptz, outside_none boolean,
               taken_by_qualification text, taken_awaits_rn boolean, watched_now boolean,
               operations_outside_app boolean, taker_access_ended boolean)
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if private.access_ended((select auth.uid())) then return; end if;  -- LEAVE1-3
  if uid is null then return; end if;
  for org in select distinct om.organization_id from public.organization_memberships om where om.user_id = uid loop
    perform private.evaluate_signals(org, false);
  end loop;
  return query
    select s.id, s.signal_kind, s.visit_id, v.visit_date, v.time_start, s.team_id, t.name, d.reason, d.created_at, s.p1_at,
           coalesce(tk.taker_id = uid and not tk.ended, false),
           case when tk.taker_id is not null and not tk.ended
                then coalesce(private.member_name(s.organization_id, tk.taker_id), 'Teammitglied') end,
           case when not tk.ended then tk.taken_at end,
           s.outside_none_at is not null,
           case when not tk.ended then tk.qualification end,
           (tk.taker_id is not null and not tk.ended and not tk.stops_escalation),
           private.watched_inside(s.organization_id, private.now()),   -- SIG2-C1 (1), ADR-082
           private.signal_step_outside_app(s.id, private.now()),       -- FUP1-2, ADR-084
           coalesce(tk.ended, false)                                   -- LEAVE1-14, ADR-091
    from public.signal_deliveries d
    join public.safety_signals s on s.id = d.signal_id
    join public.care_visits v on v.id = s.visit_id
    join public.teams t on t.id = s.team_id
    left join lateral (select x.taker_id, x.taken_at, x.qualification, x.stops_escalation,
                              private.access_ended(x.taker_id) as ended
                       from public.signal_takes x
                       where x.signal_id = s.id
                       order by private.access_ended(x.taker_id), x.stops_escalation desc, x.taken_at, x.id
                       limit 1) tk on true
    where d.recipient_id = uid and s.ended_at is null and private.is_org_member(d.organization_id)
    order by (tk.taker_id is null or tk.ended or not tk.stops_escalation) desc, d.created_at desc, s.id;
end;
$$;
revoke all on function public.my_signals() from public, anon;
grant execute on function public.my_signals() to authenticated;
comment on function public.my_signals() is
  'SIG1-3 reader with SIG1-C1 (0063), SIG2-C1 (1) (ADR-082), FUP1-2 (ADR-084) and LEAVE1-14 (ADR-091): the caller''s '
  'open P1 safety signals; watched_now = a watched period of the organisation runs now; operations_outside_app = the '
  'step to Operations reaches Operations outside the app. A take by a person whose access has ended reads as untaken '
  '(no name, qualification or time; sorted with the untaken signals); taker_access_ended = the only take shown is such '
  'a take ("Übernahme beendet – Zugang beendet").';

-- 4. end_member_access: the number of open signals she had taken (LEAVE1-14 (3)) -----------------------------------------
-- The 0076 body with `taken_signals` in the result, the change log and the audit row.
create or replace function public.end_member_access(p_user_id uuid, p_reason_code text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  org      uuid;
  role_    text;
  today    date := (private.at_zurich(private.now()))::date;
  r        record;
  subs     integer := 0;
  t        record;
  n        integer;
  released jsonb := '{}'::jsonb;
  taken    integer := 0;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  if p_reason_code is null or p_reason_code not in ('employment_ended', 'access_withdrawn') then
    raise exception 'reason code must be employment_ended or access_withdrawn' using errcode = '22023';
  end if;
  if private.begin_command('end_member_access', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if p_user_id is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if p_user_id = uid then
    return jsonb_build_object('result', private.end_command('self'));
  end if;
  org := private.leave1_org_for(p_user_id);
  if org is null then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  select m.role into role_ from public.organization_memberships m
    where m.organization_id = org and m.user_id = p_user_id for update;
  if private.access_ended(p_user_id) then
    return jsonb_build_object('result', private.end_command('unchanged'));
  end if;
  -- ADM1 rule: the organisation keeps at least one administrator with access.
  if role_ = 'admin' and (select count(*) from public.organization_memberships m
                          where m.organization_id = org and m.role = 'admin' and m.user_id <> p_user_id
                            and not private.access_ended(m.user_id)) < 1 then
    return jsonb_build_object('result', private.end_command('last_admin'));
  end if;
  -- LEAVE1-2: refused while someone else can clear the state (re-assign; the existing close path).
  if exists (select 1 from public.cases c join public.teams tm on tm.id = c.assigned_team_id
             where tm.organization_id = org and c.lifecycle <> 'closed'
               and p_user_id in (c.primary_nurse_id, c.deputy_nurse_id)) then
    return jsonb_build_object('result', private.end_command('has_cases'));
  end if;
  if exists (select 1 from public.care_visits v
             where v.organization_id = org and v.status in ('on_the_way', 'started', 'paused')
               and (p_user_id in (v.responsible_user_id, v.covered_by) or private.visit_performer(v.id) = p_user_id)) then
    return jsonb_build_object('result', private.end_command('has_visit_in_progress'));
  end if;
  -- LEAVE1-13: only a planned visit she covers for another team still refuses (COVER1 off; its end path is a COVER1
  -- switch-on item). Visits where she is responsible are released below.
  if exists (select 1 from public.care_visits v
             where v.organization_id = org and v.status = 'planned' and v.visit_date >= today
               and v.covered_by = p_user_id) then
    return jsonb_build_object('result', private.end_command('has_planned_visits'));
  end if;
  -- LEAVE1-13: release her planned visits from today to the team, per team, by the one release rule (as removal does).
  -- Inside the command context, so the visit audit rows carry this command and key. Team-readable text only.
  for t in select distinct v.team_id from public.care_visits v
           where v.organization_id = org and v.responsible_user_id = p_user_id and v.status = 'planned'
             and v.visit_date >= today
           order by v.team_id loop
    n := private.release_member_visits(t.team_id, p_user_id, null, null, 'Zugang beendet', uid);
    if n > 0 then released := released || jsonb_build_object(t.team_id::text, n); end if;
  end loop;
  -- LEAVE1-14 (3): the open signals she had taken. From the end on her takes stop nothing (signal_taken_stops_step) and
  -- read as untaken (my_signals); the takes themselves stay as they are.
  select count(distinct tk.signal_id)::int into taken
  from public.signal_takes tk join public.safety_signals s on s.id = tk.signal_id
  where tk.taker_id = p_user_id and s.organization_id = org and s.ended_at is null;
  insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id)
  values (org, p_user_id, 'ended', p_reason_code, uid);
  -- Open question 3 (0074): her push subscriptions are deleted (no push can be queued for her); audited per subscription.
  for r in delete from public.push_subscriptions s where s.user_id = p_user_id returning s.id, s.organization_id loop
    perform private.audit_command(r.organization_id, 'push_subscriptions', r.id,
            jsonb_build_object('deleted', true, 'reason', 'access_ended'));
    subs := subs + 1;
  end loop;
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'organization_memberships', p_user_id::text, 'end_member_access',
          jsonb_build_object('access', jsonb_build_object('old', 'open', 'new', 'ended'), 'reason_code', p_reason_code,
                             'released_visits', released, 'taken_signals', taken),
          p_reason_code, uid, p_idempotency_key);
  perform private.audit_command(org, 'organization_memberships', p_user_id,
          jsonb_build_object('access', 'ended', 'reason_code', p_reason_code, 'push_subscriptions_removed', subs,
                             'released_visits', released, 'taken_signals', taken));
  -- LEAVE1-12 (2): her open reports by kind (they never refuse the command, LEAVE1-2). LEAVE1-13: released per team.
  return jsonb_build_object('result', private.end_command('ok'), 'push_subscriptions_removed', subs,
                            'open_reports', private.open_report_counts(p_user_id), 'released', released,
                            'taken_signals', taken);
end;
$$;
revoke all on function public.end_member_access(uuid, text, uuid) from public, anon;
grant execute on function public.end_member_access(uuid, text, uuid) to authenticated;
comment on function public.end_member_access(uuid, text, uuid) is
  'LEAVE1-1: an organisation administrator ends a person''s access (reason code employment_ended | access_withdrawn). '
  'Refused for the caller herself (self), a person of another organisation (rejected), the last administrator with '
  'access (last_admin), and while she is primary or deputy nurse of an open case (has_cases), has a visit on the way, '
  'started or paused (has_visit_in_progress) or covers a planned visit from today on (has_planned_visits). Not '
  'refused by her open reports (LEAVE1-2). LEAVE1-13: releases her planned visits from today to their teams '
  '(private.release_member_visits, fixed text "Zugang beendet"). LEAVE1-14: her takes of open safety signals stop '
  'counting (signal_taken_stops_step). Deletes her push subscriptions; deletes nothing else. Returns {result, '
  'push_subscriptions_removed, open_reports, released: {team_id: n}, taken_signals}.';

-- 5. Claim inventory: no new claim for a person whose access has ended (LEAVE1-14 (5), ADR-091) -------------------------
-- (a) ABS1 return of released visits after an absence, and the open-visit take list: the J3 rule plus open access.
create or replace function private.may_perform_visit(p_team uuid, p_user uuid, p_minutes_b integer, p_needs_assessment boolean)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.user_in_team(p_team, p_user)
     and not private.access_ended(p_user)  -- LEAVE1-14 (ADR-091)
     and (not (coalesce(p_minutes_b, 0) > 0 or coalesce(p_needs_assessment, false))
          or private.is_registered_nurse(p_team, p_user))
$$;
revoke all on function private.may_perform_visit(uuid, uuid, integer, boolean) from public, anon, authenticated;
comment on function private.may_perform_visit(uuid, uuid, integer, boolean) is
  'J3 qualification rule (CR-007) for a person in the team, with LEAVE1-14 (ADR-091): never a person whose access has '
  'ended (ABS1 returns no visit to her).';

-- (b) PLAN2: the primary or deputy nurse with an ended access is not the responsible member of a generated visit.
select private.leave1_14_patch('private.generate_case_plan(uuid, uuid)', array[
  E'm.team_id = c.assigned_team_id and m.user_id = c.primary_nurse_id)',
  E'm.team_id = c.assigned_team_id and m.user_id = c.primary_nurse_id)\n'
  || E'             and not private.access_ended(c.primary_nurse_id) /* LEAVE1-14 */',
  '1',
  E'm.team_id = c.assigned_team_id and m.user_id = c.deputy_nurse_id)',
  E'm.team_id = c.assigned_team_id and m.user_id = c.deputy_nurse_id)\n'
  || E'             and not private.access_ended(c.deputy_nurse_id) /* LEAVE1-14 */',
  '1'], 'LEAVE1-14');

-- (c) Manual assignments refuse her with their existing codes (no reason code reaches the team, LEAVE1-8).
select private.leave1_14_patch('public.set_primary_nurse(uuid, uuid, uuid, text, uuid)', array[
  E'm.team_id = c.assigned_team_id and m.user_id = p_primary)\n',
  E'm.team_id = c.assigned_team_id and m.user_id = p_primary)\n'
  || E'     or private.access_ended(p_primary) or private.access_ended(p_deputy) /* LEAVE1-14 */\n',
  '1'], 'LEAVE1-14');

select private.leave1_14_patch(
  'public.plan_visit(uuid, date, time without time zone, time without time zone, integer, integer, integer, boolean, uuid, uuid)',
  array[
    E'm.team_id = c.assigned_team_id and m.user_id = p_responsible_user_id) then',
    E'm.team_id = c.assigned_team_id and m.user_id = p_responsible_user_id)\n'
    || E'       or private.access_ended(p_responsible_user_id) /* LEAVE1-14 */ then',
    '1'], 'LEAVE1-14');

drop function private.leave1_14_patch(text, text[], text);
