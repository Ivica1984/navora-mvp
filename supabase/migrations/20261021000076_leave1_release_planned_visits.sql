-- LEAVE1 part (b), LEAVE1-13 (PO 2026-10-25 22:10 CET): her planned visits go to the team, not back to the
-- administrator (brief docs/agents/briefs/LEAVE1.md; ADR-089). Builds on 0074 (ADR-087) and 0075 (ADR-088).
--
-- Design (ADR-089):
--   * `end_member_access` no longer refuses with `has_planned_visits` for planned visits where she is the responsible
--     member. After every refusal check, in the same command (same command context, so the visit audit rows carry
--     `end_member_access` and its key), it releases her planned visits from today, per team, through the one release
--     rule `private.release_member_visits(team, user, null, null, ...)`, exactly as `remove_team_member` does (0036,
--     0037; ABS1 0046): suspended visits included, visits in progress never, visits dated before today never. The
--     released visits are then uncovered, so the existing J3 flag, OPS1 `visit_uncovered` exception and SIG1 signals
--     apply unchanged.
--   * The plan change row, which every team member reads, carries the fixed text "Zugang beendet" only, never the
--     reason code (LEAVE1-8). The code stays in `member_access_events`, `change_log` and `audit_events`.
--   * The result gains `released`: the number released per team, as an object {team_id: n} ({} when none). The
--     change log and the audit row carry the same object.
--   * A planned visit she covers for another team (`covered_by`) keeps the refusal `has_planned_visits` (COVER1 is not
--     switched on; its end path is a COVER1 switch-on item). `has_cases` and `has_visit_in_progress` stay refusals.
--   * The release is limited to the administrator's organisation (as every other check of this command). Teams are
--     taken from the visits, so a visit of a team she has already left is released too.
--
-- No clinical, tariff or legal rule: the release rule and its exceptions are the ones reviewed for ADM1/ABS1 (CGR-09,
-- CGR-10, CGR-34, CGR-35). Idempotent: create or replace, same signature, grants restated.

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
                             'released_visits', released),
          p_reason_code, uid, p_idempotency_key);
  perform private.audit_command(org, 'organization_memberships', p_user_id,
          jsonb_build_object('access', 'ended', 'reason_code', p_reason_code, 'push_subscriptions_removed', subs,
                             'released_visits', released));
  -- LEAVE1-12 (2): her open reports by kind (they never refuse the command, LEAVE1-2). LEAVE1-13: released per team.
  return jsonb_build_object('result', private.end_command('ok'), 'push_subscriptions_removed', subs,
                            'open_reports', private.open_report_counts(p_user_id), 'released', released);
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
  '(private.release_member_visits, fixed text "Zugang beendet"). Deletes her push subscriptions; deletes nothing else. '
  'Returns {result, push_subscriptions_removed, open_reports, released: {team_id: n}}.';
