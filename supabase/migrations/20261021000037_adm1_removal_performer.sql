-- ADM1 follow-up: CGR-18 (Clinical Governance Report 2026-10-23 02:28, blocking S1; ADR-046 amendment).
--
-- Documentation belongs to the performer (the first `started` actor, private.visit_performer, 0016), not to the
-- responsible member. Any team member may start any visit of her team (RLS 0003), and only the performer may draft
-- and sign the report (create_report_draft, sign_report, 0016), and both require team membership.
-- Migration 0036 refused a removal only while she was the *responsible* member of a visit in progress (CGR-10).
-- So removing a member who performs a colleague's visit, or who completed a visit whose report is missing or
-- still a draft, left that care permanently undocumentable.
--
-- `remove_team_member` now also refuses:
--   * `has_visit_in_progress` while she is the performer of a visit of the team that is `on_the_way`, `started`
--     or `paused` (in addition to the responsible member, CGR-10);
--   * `has_unsigned_reports` while she is the performer of a `completed` visit of the team that has no report in
--     status `signed` (awaiting countersignature by another registered nurse) or `final`, i.e. no report at all
--     or only a `draft`.
-- A correction draft of a final report does not refuse: the final version stays in force. Who may sign a
-- correction for an author who left the team is CGR-19 (OPEN, decision for `clinical` + `legal`), not built here.
-- Nothing else changes: same signature, same return shape {"result", "released"}, same release rule, same audit.
-- Residual (OPEN, low, as for CGR-10): a draft or start between the check and the commit of the removal; the
-- membership row is locked, and drafting, signing and starting all require that membership.

create or replace function public.remove_team_member(p_team_id uuid, p_user_id uuid, p_reason text, p_idempotency_key uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid      uuid := (select auth.uid());
  org      uuid := private.team_organization(p_team_id);
  why      text;
  qual     text;
  released integer;
begin
  if uid is null then return jsonb_build_object('result', 'rejected'); end if;
  why := private.check_text(p_reason, 3, 300, 'reason');
  if private.begin_command('remove_team_member', p_idempotency_key) then
    return jsonb_build_object('result', private.end_command('duplicate'));
  end if;
  if not private.is_org_admin(org) then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  select m.qualification into qual from public.team_memberships m
    where m.team_id = p_team_id and m.user_id = p_user_id for update;
  if not found then
    return jsonb_build_object('result', private.end_command('rejected'));
  end if;
  if exists (select 1 from public.cases c
             where c.assigned_team_id = p_team_id and c.lifecycle <> 'closed'
               and p_user_id in (c.primary_nurse_id, c.deputy_nurse_id)) then
    return jsonb_build_object('result', private.end_command('has_cases'));
  end if;
  -- CGR-10: never remove her while she is on the way to, in, or pausing a visit of this team she is responsible for.
  if exists (select 1 from public.care_visits v
             where v.team_id = p_team_id and v.responsible_user_id = p_user_id
               and v.status in ('on_the_way', 'started', 'paused')) then
    return jsonb_build_object('result', private.end_command('has_visit_in_progress'));
  end if;
  -- CGR-18 (a): nor while she performs a visit of this team (also a colleague's) that is not completed yet.
  if exists (select 1 from public.visit_events e
             join public.care_visits v on v.id = e.visit_id
             where e.actor_id = p_user_id and e.event_type = 'started'
               and v.team_id = p_team_id and v.status in ('on_the_way', 'started', 'paused')
               and private.visit_performer(v.id) = p_user_id) then
    return jsonb_build_object('result', private.end_command('has_visit_in_progress'));
  end if;
  -- CGR-18 (b): nor while a completed visit she performed in this team has no signed or final report:
  -- only she can draft and sign it, and only while she is a member.
  if exists (select 1 from public.visit_events e
             join public.care_visits v on v.id = e.visit_id
             where e.actor_id = p_user_id and e.event_type = 'started'
               and v.team_id = p_team_id and v.status = 'completed'
               and private.visit_performer(v.id) = p_user_id
               and not exists (select 1 from public.visit_reports r
                               where r.visit_id = v.id and r.status in ('signed', 'final'))) then
    return jsonb_build_object('result', private.end_command('has_unsigned_reports'));
  end if;
  -- Release first, inside the command context, so the visit audit rows carry this command and key.
  released := private.release_member_visits(p_team_id, p_user_id, null, null,
                                            'Mitglied aus dem Team entfernt', uid);  -- team-readable: no reason
  delete from public.team_memberships where team_id = p_team_id and user_id = p_user_id;
  insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key)
  values (org, 'team_memberships', p_team_id::text || '/' || p_user_id::text, 'remove_team_member',
          jsonb_build_object('membership', jsonb_build_object('old', qual, 'new', null),
                             'released_visits', released), why, uid, p_idempotency_key);
  perform private.audit_command(org, 'team_memberships', p_team_id,
          jsonb_build_object('user_id', p_user_id, 'removed', true, 'qualification', qual, 'released_visits', released));
  return jsonb_build_object('result', private.end_command('ok'), 'released', released);
end;
$$;
revoke all on function public.remove_team_member(uuid, uuid, text, uuid) from public, anon;
grant execute on function public.remove_team_member(uuid, uuid, text, uuid) to authenticated;

comment on function public.remove_team_member(uuid, uuid, text, uuid) is
  'ADM1: removes a team membership with a reason; refused while primary nurse or deputy of an open case '
  '(has_cases), while a visit of the team she is responsible for or performs is on the way, started or paused '
  '(has_visit_in_progress; CGR-10, CGR-18), or while a completed visit she performed has no signed or final report '
  '(has_unsigned_reports; CGR-18). Releases her future planned visits of the team, suspended ones included '
  '(private.release_member_visits). The reason stays in change_log and audit, never in the team-readable plan '
  'change log. Returns {result, released}.';
