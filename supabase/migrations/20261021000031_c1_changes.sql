-- C1 changes requested by the PO (review 2026-10-22 14:30). ADR-041 amended.
--
-- * Close withdraws matching (requests and their candidate rows); pgTAP proves no team can accept.
-- * The late team-cancellation P2 exception stays open until someone closes it in OPS1 or the team plans a
--   replacement visit for the case on that day, instead of disappearing after a day.
-- * /field marks suspended visits: `field_visits` returns `suspended` and the pause reason category.

create or replace function public.close_case(p_case_id uuid, p_reason_code text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  c   public.cases%rowtype;
  why text := nullif(btrim(p_reason), '');
begin
  if uid is null then return 'rejected'; end if;
  if p_reason_code is null or p_reason_code not in ('goal_reached', 'moved_inpatient', 'moved_away', 'declined', 'died', 'other') then
    raise exception 'close reason: goal_reached, moved_inpatient, moved_away, declined, died or other' using errcode = '22023';
  end if;
  if p_reason_code = 'other' and (why is null or char_length(why) < 3) then
    raise exception 'reason "other" needs a note' using errcode = '22023';
  end if;
  if private.begin_command('close_case', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into c from private.case_for_team_or_ops(p_case_id, true);
  if c.id is null then return private.end_command('rejected'); end if;
  if c.lifecycle = 'closed' then return private.end_command('wrong_state'); end if;

  insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, note, actor_id, idempotency_key)
  values (c.organization_id, c.id, 'close', p_reason_code, why, uid, p_idempotency_key);
  -- future planned visits are cancelled with the close reason
  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key)
  select v.organization_id, v.id, 'cancelled', 'case_closed', 'Fall abgeschlossen: ' || p_reason_code, uid, gen_random_uuid()
  from public.care_visits v
  where v.case_id = c.id and v.status = 'planned' and v.visit_date >= (now() at time zone 'Europe/Zurich')::date;
  update public.care_visits v set status = 'cancelled', suspended_at = null
  where v.case_id = c.id and v.status = 'planned' and v.visit_date >= (now() at time zone 'Europe/Zurich')::date;
  update public.case_tasks set status = 'done' where case_id = c.id and status = 'open';
  -- Matching ends: open requests are withdrawn, so no team can accept any more (team_offers and
  -- decide_matching_request only act on open requests); their candidate rows are marked too.
  update public.match_candidates set status = 'withdrawn'
    where matching_request_id in (select m.id from public.matching_requests m where m.case_id = c.id and m.status = 'open');
  update public.matching_requests set status = 'withdrawn' where case_id = c.id and status = 'open';
  update public.cases
    set lifecycle = 'closed', status = 'abgeschlossen', primary_nurse_id = null, deputy_nurse_id = null,
        next_step = 'Fall abgeschlossen'
    where id = c.id;
  return private.end_command('ok');
end;
$$;

do $$
declare
  def  text := pg_get_functiondef('private.derived_exceptions(uuid)'::regprocedure);
  find text := $f$  where r.exception_type = 'team_cancellation_late' and v.organization_id = p_org and v.status = 'cancelled'
    and v.visit_date >= current_date - 1$f$;
begin
  if position(find in def) = 0 then raise exception 'C1 changes: derived_exceptions patch did not match'; end if;
  execute replace(def, find, $r$  where r.exception_type = 'team_cancellation_late' and v.organization_id = p_org and v.status = 'cancelled'
    -- open until closed in OPS1, or until the team planned a replacement for the case on that day
    and not exists (select 1 from public.care_visits x where x.case_id = v.case_id and x.visit_date = v.visit_date
                      and x.status <> 'cancelled' and x.created_at > s.created_at)$r$);
end;
$$;

do $$
declare
  def  text := pg_get_functiondef('public.field_visits(date)'::regprocedure);
  f1   text := $f$where i.case_id = v.case_id and i.active and i.goal is not null), '{}')
  from public.care_visits v$f$;
  f2   text := E')\n LANGUAGE sql';
begin
  if position(f1 in def) = 0 or position(f2 in def) = 0 then raise exception 'C1 changes: field_visits patch did not match'; end if;
  def := replace(def, f1, $r$where i.case_id = v.case_id and i.active and i.goal is not null), '{}'),
         v.suspended_at is not null,
         case when v.suspended_at is not null then
           (select e.reason_code from public.case_lifecycle_events e where e.case_id = v.case_id and e.kind = 'pause'
            order by e.created_at desc limit 1) end
  from public.care_visits v$r$);
  def := replace(def, f2, E', suspended boolean, pause_reason text)\n LANGUAGE sql');
  execute 'drop function public.field_visits(date)';
  execute def;
end;
$$;
revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;
