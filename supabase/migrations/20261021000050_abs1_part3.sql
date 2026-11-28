-- ABS1 part 3 (docs/agents/briefs/ABS1.md, PO review 2026-10-23 16:18: ABS1-C4 and ABS1-N1; ADR-061).
-- Clinical gate: no Clinical Governance Report section covers ABS1-C4 (the newest sections, 14:30 and 15:00 on PR #203,
-- predate it); it is a PO patient-safety condition. Remediation plan docs/agents/clinical/remediation/ABS1-C4.md.
--
-- What this changes (IMPLEMENTED in this migration):
--   1. ABS1-C4, plan: `plan_visit` refuses a responsible member who is absent at the visit's interval
--      (`private.visit_interval`, the one interval of 0048) with reason `responsible_absent` and writes nothing.
--      The absence is the person's in the organisation (`member_absent_during`, 0048), so a member absent via
--      team A cannot be made responsible in team B, also when she joined team B after the absence was recorded.
--      Planning the same visit without a responsible member stays possible ("Offen im Team").
--   2. ABS1-C4, move: `reschedule_visit` that moves a visit into its responsible member's absence is not refused
--      (the move itself is legitimate). After the move is logged, the visit is released through the one release
--      rule (`private.release_visits_between`, fixed text 'Abwesenheit', J3 log `released`), so it shows in
--      "Offen im Team" and as uncovered. The release window is the part of the visit's interval inside the
--      absence; any other visit of hers in that window lies inside the absence too. The release is linked to the
--      absence row of the visit's team (`absence_releases`), so withdrawing or shortening the absence returns it
--      untaken, and AN1 counts it. Without a row for that team (she joined after the absence was recorded), the
--      visit is released but not linked. The result carries `released` (true/false).
--   3. ABS1-N1: `record_absence` returns `released` counted over the caller's own teams only, so a colleague of
--      team A no longer learns how many of her visits team B had in the period. `teams` is unchanged.
-- Not here: `accept_cover` by an absent member (COVER1 condition, PLANNED with D-3); CGR-28 (PLANNED with D-3).
-- No clinical, labour-law or leave rule is modelled; the interval is arithmetic over planned data (0048).

create function private.abs1c_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'ABS1 part 3 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

-- 1. plan_visit: never to a member absent at the visit's interval ----------------------------------------------------
select private.abs1c_patch('public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid)', array[
E'      return jsonb_build_object(''result'', ''rejected'', ''reason'', ''rn_required'');\n    end if;\n  end if;',
E'      return jsonb_build_object(''result'', ''rejected'', ''reason'', ''rn_required'');\n    end if;
    -- ABS1-C4: never to a member absent at the visit''s interval (the one interval of 0048; the person, not the team).
    if (select private.member_absent_during(c.assigned_team_id, p_responsible_user_id, lower(x.iv), upper(x.iv))
        from (select private.visit_interval(jsonb_populate_record(null::public.care_visits, jsonb_build_object(
                ''visit_date'', p_visit_date, ''time_start'', p_time_start, ''time_end'', p_time_end,
                ''planned_minutes_a'', a, ''planned_minutes_b'', b, ''planned_minutes_c'', cc))) as iv) x) then
      perform private.end_command(''rejected'');
      return jsonb_build_object(''result'', ''rejected'', ''reason'', ''responsible_absent'');
    end if;
  end if;'
]);
comment on function public.plan_visit(uuid, date, time, time, integer, integer, integer, boolean, uuid, uuid) is
  'J3: plans a visit for the caller''s team. Rejection reasons: not_team_member, assessment_first, '
  'assessment_already_planned, assessment_category_a_only, order_required, rn_required, responsible_not_in_team, '
  'responsible_absent (ABS1-C4: the responsible member is absent at the visit''s interval), minutes_exceed_window.';

-- 2. reschedule_visit: a move into her absence releases the visit ----------------------------------------------------
select private.abs1c_patch('public.reschedule_visit(uuid, date, time, time, text, uuid)', array[
E'  why    text := private.check_text(p_reason, 3, 300, ''reason'');',
E'  why    text := private.check_text(p_reason, 3, 300, ''reason'');
  ab_id  uuid;
  ab_rng tstzrange;
  n_rel  integer := 0;',
E'  values (v.organization_id, v.id, v.case_id, v.team_id, ''moved'', before, private.visit_slot_json(v), why, uid);\n',
E'  values (v.organization_id, v.id, v.case_id, v.team_id, ''moved'', before, private.visit_slot_json(v), why, uid);

  -- ABS1-C4: moved into the absence of its responsible member -> released through the one release rule (not refused).
  if v.responsible_user_id is not null
     and private.member_absent_during(v.team_id, v.responsible_user_id,
                                      lower(private.visit_interval(v)), upper(private.visit_interval(v))) then
    select case when a.team_id = v.team_id then a.id end,
           tstzrange(a.starts_at, a.ends_at, ''[)'') * private.visit_interval(v)
      into ab_id, ab_rng
      from public.member_absences a
      where a.organization_id = v.organization_id and a.user_id = v.responsible_user_id and a.withdrawn_at is null
        and tstzrange(a.starts_at, a.ends_at, ''[)'') && private.visit_interval(v)
      order by (a.team_id = v.team_id) desc, a.starts_at
      limit 1;
    if ab_id is not null then
      insert into public.absence_releases (absence_id, visit_id)
      select ab_id, r from private.release_visits_between(v.team_id, v.responsible_user_id, lower(ab_rng), upper(ab_rng),
                                                          ''Abwesenheit'', uid, false) r
      on conflict do nothing;
    else
      perform private.release_visits_between(v.team_id, v.responsible_user_id, lower(ab_rng), upper(ab_rng),
                                             ''Abwesenheit'', uid, false);
    end if;
    select * into v from public.care_visits where id = v.id;
    n_rel := case when v.responsible_user_id is null then 1 else 0 end;
  end if;
',
E'  return jsonb_build_object(''result'', ''ok'', ''visit_id'', v.id,\n    ''flags'', to_jsonb(private.visit_flags(v.case_id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start)));',
E'  return jsonb_build_object(''result'', ''ok'', ''visit_id'', v.id, ''released'', n_rel = 1,\n    ''flags'', to_jsonb(private.visit_flags(v.case_id, v.visit_date, v.planned_minutes_b, v.responsible_user_id, v.status, v.time_start)));'
]);
comment on function public.reschedule_visit(uuid, date, time, time, text, uuid) is
  'J3: moves a planned visit with a reason. ABS1-C4: a move into the absence of its responsible member is not '
  'refused; the visit is released (fixed text Abwesenheit) and returns {result, visit_id, released: true, flags}.';

-- 3. ABS1-N1: record_absence counts only the caller's teams ----------------------------------------------------------
select private.abs1c_patch('public.record_absence(uuid, uuid, date, date, time, time, uuid)', array[
E'    get diagnostics n = row_count;\n    released := released + n;',
E'    get diagnostics n = row_count;
    -- ABS1-N1: count only the caller''s own teams; another team''s visits are not hers to know about.
    if private.is_team_member(t.team_id) then
      released := released + n;
    end if;'
]);

drop function private.abs1c_patch(text, text[]);
