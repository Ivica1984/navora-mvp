-- ADM1 changes (PO review 2026-10-22 20:15, docs/agents/briefs/ADM1.md; ADR-046 amendment).
--
-- 1. Removing a member from a team releases her future planned visits of that team in the same command.
--    Before this, `remove_team_member` deleted the membership and left every future visit with
--    `responsible_user_id` = that person: the visits looked covered, raised no J3 `uncovered` flag, no OPS1
--    exception and no COVER1 offer, and the person could no longer see them (silent miss).
--    The release rule is one private function, `private.release_member_visits`, which ABS1 reuses for a
--    date range (absence). Released = `planned`, not suspended, dated today (Europe/Zurich) or later, of
--    that team, with that person responsible. Started, completed, cancelled, suspended and past visits and
--    other teams' visits are never touched. Each release is written to `visit_plan_changes`
--    (change `released`, before/after responsible member, reason) and audited by the care_visits trigger
--    under the calling command.
--    `remove_team_member` now returns jsonb {"result", "released"} so /admin can show the count.
-- 2. Role change: `set_member_role` does not touch visits. Team membership and qualification are separate
--    from the organisation role, so a nurse who becomes coach or operations keeps her team membership and
--    qualification and can still start her visits (pgTAP 036). Removing her from the team (1.) is the
--    step that releases them. Stated in ADR-046.
-- Idempotent commands, admin of the organisation only, audit unchanged.

-- 1a. The plan change log knows a release --------------------------------------------------------------------
alter table public.visit_plan_changes drop constraint visit_plan_changes_change_check;
alter table public.visit_plan_changes add constraint visit_plan_changes_change_check
  check (change in ('planned', 'moved', 'removed', 'regenerated', 'skipped', 'released'));

-- 1b. One release rule (ADM1 removal now, ABS1 absence next) ------------------------------------------------
-- p_from / p_until: inclusive visit dates; null p_until = open end. Never earlier than today (Europe/Zurich).
-- Callers check permissions; this function is not executable by app roles.
create function private.release_member_visits(p_team_id uuid, p_user_id uuid, p_from date, p_until date,
                                              p_reason text, p_actor uuid)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  today date := (now() at time zone 'Europe/Zurich')::date;
  v     public.care_visits%rowtype;
  n     integer := 0;
begin
  if p_team_id is null or p_user_id is null or p_actor is null
     or p_reason is null or char_length(btrim(p_reason)) < 3 then
    raise exception 'team, member, actor and reason are required' using errcode = '22023';
  end if;
  for v in
    select * from public.care_visits x
    where x.team_id = p_team_id and x.responsible_user_id = p_user_id
      and x.status = 'planned' and x.suspended_at is null
      and x.visit_date >= greatest(coalesce(p_from, today), today)
      and (p_until is null or x.visit_date <= p_until)
    order by x.visit_date, x.time_start
    for update
  loop
    update public.care_visits set responsible_user_id = null where id = v.id;
    insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
    values (v.organization_id, v.id, v.case_id, v.team_id, 'released',
            private.visit_slot_json(v) || jsonb_build_object('responsible_id', p_user_id),
            private.visit_slot_json(v) || jsonb_build_object('responsible_id', null),
            left(btrim(p_reason), 300), p_actor);
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function private.release_member_visits(uuid, uuid, date, date, text, uuid) from public, anon, authenticated;

-- 1c. Removal releases her visits (return type changes: drop and recreate) ----------------------------------
-- Return: {"result": "ok", "released": n} | {"result": "has_cases" | "duplicate" | "rejected"}
drop function public.remove_team_member(uuid, uuid, text, uuid);
create function public.remove_team_member(p_team_id uuid, p_user_id uuid, p_reason text, p_idempotency_key uuid)
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
  -- Release first, inside the command context, so the visit audit rows carry this command and key.
  released := private.release_member_visits(p_team_id, p_user_id, null, null,
                                            'Mitglied aus dem Team entfernt: ' || why, uid);
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
  'ADM1: removes a team membership with a reason; refused while primary nurse or deputy of an open case; '
  'releases her future planned visits of the team (private.release_member_visits). Returns {result, released}.';
comment on function public.set_member_role(uuid, uuid, text, text, uuid) is
  'ADM1: changes the organisation role with a reason (never the last administrator). Team membership, '
  'qualification and responsible visits are unchanged (ADR-046): she can still start them.';
