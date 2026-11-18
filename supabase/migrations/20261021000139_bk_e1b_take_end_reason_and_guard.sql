-- BK-e1b, second migration (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 04:39; `cra` 04:27 CGR-242 (a),
-- (c), (f) and CGR-244; ADR-203 (9), (10); pgTAP 148 sections 9–11). Gate «Simulation, synthetic data» only.
--
-- CGR-242 (a): a visit ended because its take was released carries a stored system reason
--   (`care_visits.system_end_reason`), written in the same statement as `cancelled`. It is not a cancellation by
--   anybody: no `visit_events` «cancelled» row is written for it (so the timeline and every count built on
--   `visit_events` or `visit_status_notes` never read it as a client or team cancellation); the audit row records it.
--   The code says which stored fact released the take at that moment: the take's `release_reason` (step_0, step_3)
--   and, for step 3, whether one of her own absences overlaps the slot. No other cause is inferred.
-- CGR-242 (c): `public.field_visits` returns the code, so /field shows the released member why the visit is no
--   longer hers (words: `uxa` 03:50, UX_REVIEW.md; member only: the take visit is only listed to its named member).
-- CGR-244: no path releases a take while its visit is under way or done (any status other than `planned` and
--   `cancelled`). The automatic path (`private.recheck_member_takes`) keeps the take, as after the start; the hand
--   path (`public.release_named_take`) refuses with the visible reason `visit_under_way`, never silently.
--   `private.lapse_unacknowledged_take` only ever sees an unacknowledged take, which has no visit (ADR-203 (2)).
--
-- No clinical, legal or tariff rule is set here; no lead time for a re-opened order (UNKNOWN, Clinical Owner).
-- Never bypasses RLS, the QUAL1/ADM2 guards or the audit triggers. Idempotent: `if not exists`, `create or replace`,
-- patches carrying the marker BK-E1B-R, `on conflict do nothing`.

-- 0. Patch helper (removed at the end) ----------------------------------------------------------------------------------
create or replace function private.bk_e1b_r_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0139 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0139 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_e1b_r_patch(text, text[], text) from public, anon, authenticated;

-- 1. The stored system reason (CGR-242 (a)) -------------------------------------------------------------------------------
alter table public.care_visits add column if not exists system_end_reason text;
alter table public.care_visits drop constraint if exists care_visits_system_end_reason_check;
alter table public.care_visits add constraint care_visits_system_end_reason_check
  check (system_end_reason is null
         or (system_end_reason in ('take_released', 'take_released_absence', 'take_released_busy',
                                   'take_released_left_team')
             and status = 'cancelled' and order_take_id is not null));
comment on column public.care_visits.system_end_reason is
  'BK-e1b / CGR-242 (a), ADR-203 (9): why the system ended a visit written from a take (the take was released before '
  'the start). take_released_absence: her own absence overlaps the slot; take_released_busy: another visit or take '
  'of hers overlaps; take_released_left_team: she is no longer an active member; take_released: any other release. '
  'Never a cancellation by the client or the team; written only by private.end_take_visit. Null for every other visit.';
grant select (system_end_reason) on public.care_visits to authenticated;   -- no insert or update grant

drop trigger if exists audit_care_visits on public.care_visits;
create trigger audit_care_visits
  after update on public.care_visits
  for each row execute function private.write_audit_event(
    'status', 'billable', 'team_id', 'visit_date', 'time_start', 'time_end',
    'planned_minutes_a', 'planned_minutes_b', 'planned_minutes_c', 'responsible_user_id', 'system_end_reason');
insert into private.audit_value_classes (table_name, key, class) values ('care_visits', 'system_end_reason', 'code')
on conflict do nothing;

-- 2. A system end is not a timeline cancellation (CGR-242 (a)) ---------------------------------------------------------
select private.bk_e1b_r_patch('private.write_visit_event()', array[
  E'  if kind is null then\n    return new;\n  end if;',
  E'  if kind is null then\n    return new;\n  end if;\n'
  || E'  -- BK-E1B-R (CGR-242 (a)): the end of a visit whose take was released is no cancellation by anybody; the\n'
  || E'  -- audit row keeps it, the timeline and the cancellation counts never read it.\n'
  || E'  if kind = ''cancelled'' and new.system_end_reason is not null then\n    return new;\n  end if;',
  '1'], 'BK-E1B-R');
revoke all on function private.write_visit_event() from public, anon, authenticated;

-- 3. End the visit with its reason (replaces the 0138 body; same guards and lock) ----------------------------------------
create or replace function private.end_take_visit(p_take_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  k   public.order_takes;
  o   public.partner_requests;
  why text;
begin
  select * into k from public.order_takes where id = p_take_id;
  if k.id is null or k.released_at is null then return; end if;
  select * into o from public.partner_requests where id = k.order_id;
  -- CGR-242 (e): never after the start (no automatic release after starts_at); a visit under way is untouched.
  if o.id is null or o.starts_at <= private.now() then
    return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || k.member_id::text, 0));
  -- CGR-242 (a): the stored fact that released the take, read now, in the same transaction.
  why := case
    when k.release_reason = 'step_0' then 'take_released_left_team'
    when k.release_reason = 'step_3' and exists (
           select 1 from public.member_absences x
           where x.user_id = k.member_id and x.withdrawn_at is null
             and x.starts_at < o.ends_at and x.ends_at > o.starts_at) then 'take_released_absence'
    when k.release_reason = 'step_3' then 'take_released_busy'
    else 'take_released'
  end;
  update public.care_visits set status = 'cancelled', system_end_reason = why
    where order_take_id = k.id and status = 'planned';
end;
$$;
revoke all on function private.end_take_visit(uuid) from public, anon, authenticated;

-- 4. CGR-244: no release while the take's visit is under way or done -----------------------------------------------------
create or replace function private.take_visit_under_way(p_take_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.care_visits v
                 where v.order_take_id = p_take_id
                   and v.status is distinct from 'planned' and v.status is distinct from 'cancelled')
$$;
revoke all on function private.take_visit_under_way(uuid) from public, anon, authenticated;
comment on function private.take_visit_under_way(uuid) is
  'BK-e1b / CGR-244: true when the visit written from this take is in any status other than planned or cancelled '
  '(on the way, started, paused, or ended by a person). Such a take is never released, automatically or by hand.';

-- Automatic path: the take stays, as after the start (`order_started`).
select private.bk_e1b_r_patch('private.recheck_member_takes(uuid)', array[
  E'    where t.member_id = p_user and t.released_at is null and p.starts_at > private.now()\n',
  E'    where t.member_id = p_user and t.released_at is null and p.starts_at > private.now()\n'
  || E'      and not private.take_visit_under_way(t.id)  -- BK-E1B-R (CGR-244): never while her visit is under way\n',
  '1'], 'BK-E1B-R');
revoke all on function private.recheck_member_takes(uuid) from public, anon, authenticated;

-- Hand path: refused with a visible reason, after the named-member check (the reason reaches only her).
select private.bk_e1b_r_patch('public.release_named_take(uuid, uuid)', array[
  E'  if k.member_id = k.taken_by then  -- no un-take in BK-c (UXR-221)\n',
  E'  if private.take_visit_under_way(k.id) then  -- BK-E1B-R (CGR-244): refused, never a silent release\n'
  || E'    perform private.end_command(''refused'');\n'
  || E'    return jsonb_build_object(''result'', ''refused'', ''reason'', ''visit_under_way'');\n'
  || E'  end if;\n'
  || E'  if k.member_id = k.taken_by then  -- no un-take in BK-c (UXR-221)\n',
  '1'], 'BK-E1B-R');
revoke all on function public.release_named_take(uuid, uuid) from public, anon;
grant execute on function public.release_named_take(uuid, uuid) to authenticated;

-- 5. /field returns the reason (CGR-242 (c)); the return type grows, so drop and create (as 0031) ---------------------
do $$
declare
  def text := pg_get_functiondef('public.field_visits(date)'::regprocedure);
  f1  text := E'order by e.created_at desc limit 1) end\n  from public.care_visits v';
  f2  text := E', suspended boolean, pause_reason text)\n LANGUAGE sql';
begin
  if position('BK-E1B-R' in def) > 0 then
    return;
  end if;
  if (length(def) - length(replace(def, f1, ''))) / length(f1) <> 1
     or (length(def) - length(replace(def, f2, ''))) / length(f2) <> 1 then
    raise exception '0139: field_visits patch did not match exactly once';
  end if;
  def := replace(def, f1, E'order by e.created_at desc limit 1) end,\n'
                       || E'         v.system_end_reason  -- BK-E1B-R (CGR-242 (c))\n  from public.care_visits v');
  def := replace(def, f2, E', suspended boolean, pause_reason text, system_end_reason text)\n LANGUAGE sql');
  execute 'drop function public.field_visits(date)';
  execute def;
end;
$$;
revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;

drop function private.bk_e1b_r_patch(text, text[], text);
