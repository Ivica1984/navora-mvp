-- CSR1 part 11: CGR-32 (ABS1 acceptance condition, docs/agents/briefs/ABS1.md, PO 2026-10-23 19:12). ADR-065.
-- Product decision of the PO (a display and command rule, not a clinical rule). Whether the care that was due must be
-- made up is a clinical question (D-28, D-31) and is not decided here.
--
-- Before: an absence may start in the past ("krank seit gestern"). The one release rule (0046) acts from today on, so
--   a planned, not started visit dated before today inside the new absence kept the absent member as responsible and
--   its `visit_overdue` alert read "zuständig: <Name>" as if she simply had not started it yet.
-- Now (IMPLEMENTED in this migration):
--   1. `record_absence` returns `past_planned`: the number of planned, not started visits dated before today whose
--      interval (private.visit_interval, 0048) lies inside the new absence and that name the absent member, counted
--      over the caller's own teams only (ABS1-N1 rule). The absence is never refused for them, and they are not
--      released: they keep their responsible member (one accountable trail; a released past visit would invite a
--      take nobody can perform and could not be closed by hand, CGR-22).
--      `change_absence` only withdraws or shortens (the start never moves earlier), so it can never add such visits;
--      it returns no `past_planned`.
--   2. `team_visit_alerts()` (/team) and `operations_exceptions()` (OPS1) gain a column `flags text[]`. A
--      `visit_overdue` row carries `responsible_absent` when the visit is planned and its responsible member is
--      absent at the visit's interval. The app shows the fixed label "Zuständige Person abwesend gemeldet"; no
--      reason and no free text exist to show.
--   3. The flag is computed from the absence at read time (not stored): withdrawing or shortening the absence clears
--      it. Generic on purpose (like ABS1-C5): it tests "planned, named member absent at its interval", not "before
--      today"; from today on the release rule leaves no such visit, so in practice it marks exactly CGR-32's visits.
-- Unchanged: today's and later visits are released as in 0046/0048; overdue thresholds stay PROVISIONAL (D-28).
-- Both readers are regenerated from their current definitions (each find must match once); a new return column
-- needs drop and create, so grants and comments are restated.

create function private.cgr32_patch(p_fn text, p_pairs text[], p_drop boolean)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'CGR-32 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if p_drop then
    execute 'drop function ' || p_fn;
  end if;
  execute def;
end;
$$;

-- 1. The flag: a planned visit names a member who is absent at its interval -----------------------------------------
create function private.visit_responsible_absent(p_visit_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce((
    select v.status = 'planned' and v.responsible_user_id is not null
           and private.member_absent_during(v.team_id, v.responsible_user_id,
                                            lower(private.visit_interval(v)), upper(private.visit_interval(v)))
    from public.care_visits v where v.id = p_visit_id), false)
$$;
revoke all on function private.visit_responsible_absent(uuid) from public, anon, authenticated;
comment on function private.visit_responsible_absent(uuid) is
  'CSR1 / CGR-32: true when the planned visit names a responsible member who is absent at its interval (0048). '
  'Computed from the absence, never stored.';

-- 2. record_absence: count her past planned visits inside the absence (caller's teams only) -------------------------
select private.cgr32_patch('public.record_absence(uuid, uuid, date, date, time, time, uuid)', array[
E'  released integer := 0;\n',
E'  released integer := 0;\n  past_planned integer := 0;\n',
E'    if private.is_team_member(t.team_id) then\n      released := released + n;\n    end if;',
E'    if private.is_team_member(t.team_id) then
      released := released + n;
      -- CSR1 / CGR-32: her planned visits dated before today inside the absence are not released (the release rule
      -- acts from today on); they keep her and are counted, so the caller learns they need a team decision.
      past_planned := past_planned + (
        select count(*)::int from public.care_visits x
        where x.team_id = t.team_id and x.responsible_user_id = who and x.status = ''planned''
          and x.visit_date < (now() at time zone ''Europe/Zurich'')::date
          and private.visit_interval(x) && tstzrange(s_at, e_at, ''[)''));
    end if;',
E'''released'', released, ''teams'', n_teams)',
E'''released'', released, ''teams'', n_teams, ''past_planned'', past_planned)'
], false);
comment on function public.record_absence(uuid, uuid, date, date, time, time, uuid) is
  'ABS1: records that a member (herself, or a colleague of one of her teams) is not available; no reason, no '
  'approval. Applies to every team of hers in the organisation (one row per team, one absence_group, ABS1-C3) and '
  'releases her planned visits from today on in each team at once (fixed text Abwesenheit). CGR-32: her planned '
  'visits dated before today inside the absence keep her and are counted in past_planned (caller''s teams only). '
  'Returns {result, absence_id, released, teams, past_planned}.';

-- 3. /team: visit alerts carry the flag ------------------------------------------------------------------------------
select private.cgr32_patch('public.team_visit_alerts()', array[
E'visit_id uuid, taken boolean)',
E'visit_id uuid, taken boolean, flags text[])',
E'         coalesce(l.kind = ''take'', false)\n  from d',
E'         coalesce(l.kind = ''take'', false),
         -- CSR1 / CGR-32: computed from the absence, never stored
         case when d.exception_type = ''visit_overdue'' and private.visit_responsible_absent(d.entity_id)
              then array[''responsible_absent''] else array[]::text[] end
  from d'
], true);
revoke all on function public.team_visit_alerts() from public, anon;
grant execute on function public.team_visit_alerts() to authenticated;
comment on function public.team_visit_alerts() is
  'CSR1: overdue and stuck visits (CGR-04, PROVISIONAL thresholds, D-28), interrupted visits waiting for a follow-up '
  'decision (CGR-25, PROVISIONAL, D-31) and report corrections not final after the report_not_final threshold (CGR-24, '
  'PROVISIONAL, D-28) of the caller''s teams. flags: responsible_absent on an overdue visit whose responsible member '
  'is absent at its interval (CGR-32). Read-only.';

-- 4. OPS1: the same flag ---------------------------------------------------------------------------------------------
select private.cgr32_patch('public.operations_exceptions()', array[
E'owner_name text, closable boolean)',
E'owner_name text, closable boolean, flags text[])',
E'''visit_uncovered'', ''visit_interrupted'', ''report_correction_open''))\n  from d',
E'''visit_uncovered'', ''visit_interrupted'', ''report_correction_open'')),
         -- CSR1 / CGR-32: computed from the absence, never stored
         case when d.exception_type = ''visit_overdue'' and private.visit_responsible_absent(d.entity_id)
              then array[''responsible_absent''] else array[]::text[] end
  from d'
], true);
revoke all on function public.operations_exceptions() from public, anon;
grant execute on function public.operations_exceptions() to authenticated;
comment on function public.operations_exceptions() is
  'OPS1: open exceptions for coordinators. closable = false for exceptions that close only with their cause: safety '
  'exceptions (P1 or escalating, CSR1 / CGR-06), visit_uncovered (CSR1 / CGR-22, PROVISIONAL until D-28), '
  'visit_interrupted (CSR1 / CGR-25, PROVISIONAL until D-31) and report_correction_open (CSR1 / CGR-30, PROVISIONAL '
  'until D-28). flags: responsible_absent on an overdue visit whose responsible member is absent at its interval '
  '(CSR1 / CGR-32).';

drop function private.cgr32_patch(text, text[], boolean);
