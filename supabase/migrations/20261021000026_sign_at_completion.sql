-- F7: sign at completion (PO brief docs/agents/briefs/F7.md, ADR-043).
--
-- Answer to the brief's question: no new report state. Completing a visit opens its F6 draft at once
-- (the app calls create_report_draft right after complete), and the nurse signs it with one confirmation
-- (an edited summary is saved first). Signing later keeps the F6 flow and the OPS1 "report not final"
-- exception unchanged. Every F6 guarantee stays as it is (who and when, immutability, versions, team scope).
--
-- New here: the countersignature queue for a registered nurse's day view, across dates, so the request
-- reaches the team at the moment of signing (D-10 rule unchanged).

create function public.field_countersign_queue()
returns table (
  report_id   uuid,
  visit_id    uuid,
  visit_date  date,
  time_start  time,
  client_name text,
  team_name   text,
  signed_at   timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select r.id, r.visit_id, v.visit_date, v.time_start,
         nullif(btrim(concat_ws(' ', c.first_name, c.last_name)), ''), t.name, r.signed_at
  from public.visit_reports r
  join public.care_visits v on v.id = r.visit_id
  join public.teams t on t.id = r.team_id
  left join public.cases c on c.id = v.case_id
  where r.status = 'signed' and r.countersign_required
    and r.performer_id <> (select auth.uid())
    and private.is_org_member(r.organization_id) and private.is_team_member(r.team_id)
    and private.is_registered_nurse(r.team_id, (select auth.uid()))
    and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id)
  order by r.signed_at;
$$;
revoke all on function public.field_countersign_queue() from public, anon;
grant execute on function public.field_countersign_queue() to authenticated;
