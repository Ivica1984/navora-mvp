-- CSR1, first PR: C1's clinical-gate findings (Clinical Governance Report 2026-10-22 22:30; ADR-049).
--
-- CGR-12 (blocking, J3 and C1): the registered-nurse rule held only for the first start
-- (`planned`/`on_the_way` → `started`, migration 0024). A care assistant could resume (`paused` → `started`) and
-- complete (`started` → `completed`) a category B or needs-assessment visit. The check now applies to **every**
-- transition into `started` and into `completed`. Same SQLSTATE NV001, same single rule
-- (private.is_registered_nurse). Rule register CR-007.
--
-- CGR-04 (blocking, OPS1 and C1): a visit that did not happen stayed invisible.
--   * `visit_overdue`: a planned (not suspended) visit whose planned start has passed without a start. Raised the
--     same way whoever is responsible; the detail says "niemand zuständig" or "zuständige Person nicht mehr im
--     Team" (CSR1 addition 2026-10-23 00:10: a removed member's visit dated before today).
--   * `visit_stuck`: a visit left `on_the_way`, `started` or `paused`. Measured from its last status change; for a
--     `started` visit not before its planned end. Each new status change is a new exception (the key carries the
--     last visit event), so closing one never silences a later one.
--   * `visit_uncovered` / `visit_uncovered_hospital` no longer disappear at the planned start: they stay while the
--     visit is planned and nobody is responsible (PS-2).
--   Both new types stay open until the cause is gone (the visit moves on, is cancelled, recorded as no-show or
--   suspended) or a coordinator closes them with a reason in OPS1. Both are visible to every member of the
--   visit's team through `public.team_visit_alerts()` (new), not only to Operations.
--   Thresholds are a `clinical` decision (D-28, OPEN). PROVISIONAL defaults, strict on purpose (raise early):
--     visit_overdue  P2 at the planned start (0 h), P1 one hour after the planned start;
--     visit_stuck    P2 one hour after the last status change (started: after the planned end), P1 after 3 h.
--   A visit without a planned time counts from 00:00 of its day, as the uncovered exception does (0019).
--   Organisations may only tighten or relax within the existing safe range (CR-021).
--
-- Not here (OPEN, later CSR1 PRs): CGR-05, CGR-06 (a P1 cannot be silenced while its cause persists; until then a
-- coordinator can close `visit_overdue` with a reason, as every OPS1 exception), CGR-01/02/03/07, CGR-08, CGR-13,
-- CGR-19, BL-8, BL-9. No clinical rule is invented: the thresholds are labelled PROVISIONAL (register CR-038..040).

-- 1. CGR-12: qualification on every start and on completion --------------------------------------------------------
create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' and new.status is distinct from old.status then
    if not ((old.status, new.status) in (
      ('planned',    'on_the_way'),
      ('planned',    'started'),
      ('on_the_way', 'started'),
      ('started',    'paused'),
      ('paused',     'started'),
      ('started',    'completed')
    )) then
      raise exception 'visit transition % -> % is not allowed', old.status, new.status
        using errcode = '23514';
    end if;
    if old.suspended_at is not null then
      raise exception 'the visit is suspended because the case is paused' using errcode = '23514';
    end if;
    -- CGR-12: every transition into `started` (first start and resume) and into `completed`.
    if new.status in ('started', 'completed')
       and (coalesce(new.planned_minutes_b, 0) > 0 or new.is_needs_assessment)
       and not private.is_registered_nurse(new.team_id, (select auth.uid())) then
      raise exception 'category B and needs-assessment visits are started, resumed and completed by a registered nurse'
        using errcode = 'NV001';
    end if;
  end if;
  return new;
end;
$$;

-- 2. CGR-04: exception types (PROVISIONAL thresholds, D-28) ---------------------------------------------------------
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  ('visit_overdue', 'P2', 0, 'hours', 1, 'Einsatz nicht begonnen',
   'Team kontaktieren: Findet der Einsatz statt, wer geht hin? Sonst absagen oder «nicht angetroffen» erfassen. Schwellen provisorisch (D-28, klinisch offen).'),
  ('visit_stuck', 'P2', 1, 'hours', 3, 'Einsatz nicht abgeschlossen (unterwegs, begonnen oder pausiert)',
   'Pflegeperson bzw. Team kontaktieren und den Stand klären. Schwellen provisorisch (D-28, klinisch offen).');

-- 3. Regenerate the reader from its current definition (no hand copy; every patch must match) ----------------------
create function private.csr1_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'CSR1 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

select private.csr1_patch('private.derived_exceptions(uuid)', array[
  -- PS-2: the uncovered exception stays after the planned start while the visit is planned and nobody responsible.
  E'    and (v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich''\n        between now() and private.after_threshold(now(), r.amount, r.unit)\n  union all\n  -- COVER1',
  E'    and (v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich''\n        <= private.after_threshold(now(), r.amount, r.unit)\n  union all\n  -- COVER1',
  -- CGR-04: overdue and stuck visits, appended after the last branch.
  E'        < private.after_threshold(s.created_at, r.amount, r.unit)\n',
  E'        < private.after_threshold(s.created_at, r.amount, r.unit)
  union all
  -- CSR1 / CGR-04: planned visit not started after its planned start (whoever is responsible)
  select ''visit_overdue:'' || v.id, ''visit_overdue'',
         (v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich'', v.case_id, v.team_id, ''visit'', v.id,
         to_char(v.visit_date, ''DD.MM.'') || coalesce('' '' || to_char(v.time_start, ''HH24:MI''), '''') || '' · ''
           || case
                when v.responsible_user_id is null and v.covered_by is not null then ''von einem anderen Team übernommen''
                when v.responsible_user_id is null then ''niemand zuständig''
                when not exists (select 1 from public.team_memberships tm
                                 where tm.team_id = v.team_id and tm.user_id = v.responsible_user_id)
                  then ''zuständige Person nicht mehr im Team''
                else ''zuständig: '' || coalesce(private.member_name(v.organization_id, v.responsible_user_id), ''Teammitglied'')
              end
  from public.care_visits v
  join rules r on r.exception_type = ''visit_overdue''
  where v.organization_id = p_org and v.status = ''planned'' and v.suspended_at is null
    and now() >= private.after_threshold((v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich'', r.amount, r.unit)
  union all
  -- CSR1 / CGR-04: visit left on the way, started or paused (from the last status change; started: not before the planned end)
  select ''visit_stuck:'' || v.id || '':'' || coalesce(last.id::text, ''0''), ''visit_stuck'', st.ref, v.case_id, v.team_id, ''visit'', v.id,
         to_char(v.visit_date, ''DD.MM.'') || coalesce('' '' || to_char(v.time_start, ''HH24:MI''), '''') || '' · ''
           || case v.status when ''on_the_way'' then ''unterwegs'' when ''started'' then ''begonnen'' else ''pausiert'' end
           || '' seit '' || to_char(coalesce(last.at, st.ref) at time zone ''Europe/Zurich'', ''DD.MM. HH24:MI'')
  from public.care_visits v
  left join lateral (select e.id, e.occurred_at as at from public.visit_events e
                     where e.visit_id = v.id order by e.occurred_at desc, e.id desc limit 1) last on true
  cross join lateral (select case
           when v.status = ''started'' and coalesce(v.time_end, v.time_start) is not null
             then greatest(coalesce(last.at, ''-infinity''::timestamptz),
                           (v.visit_date + coalesce(v.time_end, v.time_start)
                              + case when v.time_end < v.time_start then interval ''1 day'' else interval ''0'' end) at time zone ''Europe/Zurich'')
           else coalesce(last.at, (v.visit_date + coalesce(v.time_start, time ''00:00'')) at time zone ''Europe/Zurich'')
         end as ref) st
  join rules r on r.exception_type = ''visit_stuck''
  where v.organization_id = p_org and v.status in (''on_the_way'', ''started'', ''paused'')
    and now() >= private.after_threshold(st.ref, r.amount, r.unit)
'
]);

drop function private.csr1_patch(text, text[]);

-- 4. Team view: overdue and stuck visits of the caller's own teams (CSR1: visible to every member) ------------------
-- Same priority and closing logic as OPS1 (a coordinator's close ends it for the team too). No free text of
-- anyone else: the detail carries only date, time, status and the responsible member's display name.
create function public.team_visit_alerts()
returns table (exception_key text, exception_type text, priority text, label text, detail text, since timestamptz,
               case_id uuid, client_name text, team_id uuid, team_name text, visit_id uuid, taken boolean)
language sql stable security definer set search_path = ''
as $$
  with my_teams as (
    select tm.team_id, t.organization_id, t.name
    from public.team_memberships tm
    join public.teams t on t.id = tm.team_id
    where tm.user_id = (select auth.uid())
  ), d as (
    select o.organization_id, x.*
    from (select distinct organization_id from my_teams) o, lateral private.derived_exceptions(o.organization_id) x
    where x.exception_type in ('visit_overdue', 'visit_stuck')
      and x.team_id in (select mt.team_id from my_teams mt)
  ), latest as (
    select distinct on (ev.organization_id, ev.exception_key) ev.organization_id, ev.exception_key, ev.kind
    from public.exception_events ev
    where ev.organization_id in (select organization_id from my_teams) and ev.kind in ('take', 'close', 'auto_close')
      and ev.exception_key in (select d.exception_key from d)
    order by ev.organization_id, ev.exception_key, ev.id desc
  )
  select d.exception_key, d.exception_type,
         case when r.escalate_to_p1_after_hours is not null and now() >= d.since + make_interval(hours => r.escalate_to_p1_after_hours)
              then 'P1' else r.priority end,
         r.label, d.detail, d.since, d.case_id,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''),
         d.team_id, (select mt.name from my_teams mt where mt.team_id = d.team_id limit 1), d.entity_id,
         coalesce(l.kind = 'take', false)
  from d
  join lateral private.effective_exception_rules(d.organization_id) r on r.exception_type = d.exception_type
  left join latest l on l.organization_id = d.organization_id and l.exception_key = d.exception_key
  left join public.cases c on c.id = d.case_id
  where l.kind is null or l.kind = 'take'
  order by 3, d.since;
$$;
revoke all on function public.team_visit_alerts() from public, anon;
grant execute on function public.team_visit_alerts() to authenticated;
comment on function public.team_visit_alerts() is
  'CSR1 / CGR-04: overdue and stuck visits of the caller''s teams (PROVISIONAL thresholds, D-28). Read-only.';
