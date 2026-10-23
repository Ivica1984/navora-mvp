-- CSR1, part 8: CGR-24 (F1-F4, F6, advisory S2) and CGR-26 (OPS1, advisory S3), the PO's criteria in
-- `docs/agents/briefs/CSR1.md` (added 2026-10-23 11:25 from the Clinical Governance Report section 2026-10-23 10:29).
-- CGR-13 (QG1, UI label "Abrechnungssperre") is UI only and needs nothing here. ADR-058.
--
-- CGR-24 (strict provisional default; threshold PROVISIONAL, D-28 `clinical`): a report correction draft could stay
--   unsigned for good. Since 0040 an open correction draft also unlocks the visit's times and observations, and since
--   0044 the old final version stays in force meanwhile, so nothing told anyone that a correction was left half done.
--   New exception type `report_correction_open` (P3, not escalating): it exists while a correction version
--   (`visit_reports.supersedes_id` set) is not `final` and is older than the organisation's **`report_not_final`
--   threshold** (the brief: "longer than the report_not_final threshold"; one threshold, read from the effective
--   `report_not_final` rule, so an organisation's override applies to both). It ends when the correction version
--   becomes final. Stricter than the brief's wording (recorded deviation, ADR-058): a correction that is signed but
--   still waits for the countersignature (`signed`) also keeps the signal, because until it is final the old
--   version stays in force and billing reads only final versions (0043). There is no command to withdraw a
--   correction draft (UNKNOWN whether one is wanted; not built). Visible to the team (`team_visit_alerts`, `/team`)
--   and to Operations (`operations_exceptions`). Its key carries the correction's id, so a later correction of the
--   same visit raises a new signal. Like `report_not_final` it can be closed by hand in OPS1 (it is not made a safety
--   exception; OPEN, ADR-058). The detail carries no clinical text: date, time, version, and whether the
--   countersignature is missing.
--
-- CGR-26: the performer of an interrupted visit sees who ended it and why. `field_visit_status_notes` (0024) gains
--   who recorded each note, as a label the caller may see: `actor_kind` ('me', 'team' for a member of the visit's
--   team, 'coordination' for an admin/coach/operations member of the organisation outside the team, 'former' for
--   anyone else, e.g. a member who has left), the display name (ADM1 member profile of the same organisation; never
--   for 'former'), the team qualification ('team') or the organisation role ('coordination'). No user id is
--   returned. The reason was already returned. How an end recorded in error is corrected stays D-31; nothing is
--   built for it.
--
-- No clinical rule is invented. derived_exceptions and team_visit_alerts keep their signatures;
-- field_visit_status_notes is dropped and recreated with four more columns (only the app reads it); no data migration.

-- 1. CGR-24: the exception type (PROVISIONAL, D-28) -------------------------------------------------------------------
-- No own threshold: the `report_not_final` threshold applies (see the derivation). Organisations may only raise it to
-- a higher priority (exception_rule_range); its amount stays null.
insert into public.exception_rules (exception_type, priority, amount, unit, escalate_to_p1_after_hours, label, next_step) values
  ('report_correction_open', 'P3', null, null, null, 'Berichtskorrektur nicht abgeschlossen',
   'Die Pflegeperson, die den Einsatz geleistet hat, prüft die Korrektur und unterschreibt sie. Bis dahin gilt die bisherige Version. Provisorische Frist wie «Einsatzbericht nicht abgeschlossen» (D-28, klinisch offen).');

-- 2. Readers, regenerated from their current definitions (every find must match exactly once) ------------------------
create function private.csr1i_patch(p_fn text, p_pairs text[])
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

-- 2a. The derived exception, appended after the last branch (visit_interrupted, 0045).
select private.csr1i_patch('private.derived_exceptions(uuid)', array[
  E'    and not exists (select 1 from public.visit_status_notes f where f.visit_id = v.id and f.kind = ''interruption_followup'')\n',
  E'    and not exists (select 1 from public.visit_status_notes f where f.visit_id = v.id and f.kind = ''interruption_followup'')
  union all
  -- CSR1 / CGR-24 (PROVISIONAL, D-28): a report correction that is not final after the report_not_final threshold
  select ''report_correction_open:'' || c.id, ''report_correction_open'', c.created_at, v.case_id, v.team_id, ''visit'', v.id,
         to_char(v.visit_date, ''DD.MM.'') || coalesce('' '' || to_char(v.time_start, ''HH24:MI''), '''')
           || '' · Korrektur Version '' || c.version
           || case when c.status = ''signed'' then '' · unterschrieben, Gegenzeichnung offen'' else '' · nicht unterschrieben'' end
  from public.visit_reports c
  join public.care_visits v on v.id = c.visit_id and v.organization_id = c.organization_id
  join rules t on t.exception_type = ''report_not_final''
  join rules r on r.exception_type = ''report_correction_open''
  where c.organization_id = p_org and c.supersedes_id is not null and c.status <> ''final''
    and now() >= private.after_threshold(c.created_at, t.amount, t.unit)
'
]);

-- 2b. Team view: the team sees an open correction of its visits (CGR-24 "for the team and Operations").
select private.csr1i_patch('public.team_visit_alerts()', array[
  E'x.exception_type in (''visit_overdue'', ''visit_stuck'', ''visit_interrupted'')',
  E'x.exception_type in (''visit_overdue'', ''visit_stuck'', ''visit_interrupted'', ''report_correction_open'')'
]);

drop function private.csr1i_patch(text, text[]);

revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;
revoke all on function public.team_visit_alerts() from public, anon;
grant execute on function public.team_visit_alerts() to authenticated;
comment on function public.team_visit_alerts() is
  'CSR1: overdue and stuck visits (CGR-04, PROVISIONAL thresholds, D-28), interrupted visits waiting for a '
  'follow-up decision (CGR-25, PROVISIONAL, D-31) and report corrections not final after the report_not_final '
  'threshold (CGR-24, PROVISIONAL, D-28) of the caller''s teams. Read-only.';

-- 3. CGR-26: who recorded a status note, as a label --------------------------------------------------------------------
drop function public.field_visit_status_notes(date);
create function public.field_visit_status_notes(p_date date)
returns table (visit_id uuid, kind text, reason_code text, note text, created_at timestamptz,
               actor_kind text, actor_name text, actor_qualification text, actor_role text)
language sql stable security definer set search_path = ''
as $$
  select s.visit_id, s.kind, s.reason_code, s.note, s.created_at,
         a.kind,
         case when a.kind in ('team', 'coordination') then
           (select p.display_name from public.member_profiles p
            where p.organization_id = v.organization_id and p.user_id = s.actor_id)
         end,
         case when a.kind = 'team' then
           (select tm.qualification from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = s.actor_id)
         end,
         case when a.kind = 'coordination' then
           (select om.role from public.organization_memberships om
            where om.organization_id = v.organization_id and om.user_id = s.actor_id
              and om.role in ('admin', 'coach', 'operations')
            order by case om.role when 'operations' then 1 when 'coach' then 2 else 3 end limit 1)
         end
  from public.visit_status_notes s
  join public.care_visits v on v.id = s.visit_id
  cross join lateral (select case
      when s.actor_id = (select auth.uid()) then 'me'
      when exists (select 1 from public.team_memberships tm where tm.team_id = v.team_id and tm.user_id = s.actor_id) then 'team'
      when exists (select 1 from public.organization_memberships om
                   where om.organization_id = v.organization_id and om.user_id = s.actor_id
                     and om.role in ('admin', 'coach', 'operations')) then 'coordination'
      else 'former'
    end as kind) a
  where p_date is not null and v.visit_date = p_date
    and private.is_org_member(v.organization_id) and private.is_team_member(v.team_id)
  order by s.visit_id, s.created_at;
$$;
revoke all on function public.field_visit_status_notes(date) from public, anon;
grant execute on function public.field_visit_status_notes(date) to authenticated;
comment on function public.field_visit_status_notes(date) is
  'C1: reasons and outcomes of the day''s visits of the caller''s teams. CSR1 / CGR-26: who recorded each note, as '
  'a label (me, team member with name and qualification, coordination role with name, or former); no user id.';
