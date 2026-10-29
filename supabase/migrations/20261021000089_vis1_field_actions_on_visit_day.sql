-- VIS1: field actions happen on the visit's day (PO brief docs/agents/briefs/VIS1.md, `cra` CGR-87, ADR-111).
-- Visit/schedule fact (the visit date and the Zurich calendar day, DAY-1). No clinical rule, no tolerance, no rule for
-- past-dated visits (VIS1-6: UNKNOWN, Clinical Owner and PO).
--
-- Before (IMPLEMENTED defect, CGR-87): `depart_visit`, `start_visit`, `complete_visit` (0007, `private.transition_visit`),
--   `record_no_show` (0024, 0072) and `end_visit_not_completed` (0042) changed status by state only. A visit dated
--   next week could be departed, started and completed today: on its real date it was no longer `planned`, so no
--   overdue or missed signal (CSR1, SIG1, H-01) was raised; the record and the billable facts (by `visit_date`)
--   named a day on which no care was given (H-05).
-- Now (IMPLEMENTED in this migration):
--   1. `depart_visit`, `start_visit`, `record_no_show`, `end_visit_not_completed` refuse a visit whose `visit_date` is
--      after today (Europe/Zurich: `private.at_zurich(private.now())::date`) with the outcome `not_today`.
--   2. `complete_visit` refuses, with the outcome `started_before_date`, a visit dated after today or one whose latest
--      `started` event (Zurich calendar day) lies before its `visit_date`. After (1) this can only be a visit started
--      before this migration (or a status written by maintenance); it can still be ended as not completed from its
--      date on (CSR1). Whether more is needed for such a visit is late documentation (UNKNOWN, Clinical Owner and PO).
--   3. A refusal changes nothing: status unchanged, no `visit_events` row, no status note. It writes ONE
--      `audit_events` row: table `care_visits`, entity = the visit, the command, changed = {outcome: {old: null,
--      new: <outcome>}}. The idempotency key is NOT stored on that row: `begin_command` treats a stored key as
--      "already applied" and the app maps `duplicate` to success, so a retry with the same key after the visit has
--      been moved to today must be evaluated again, not answered as a duplicate.
--   4. Order inside each command: begin_command (duplicate, LEAVE1 access end) → visibility (team member; otherwise
--      the command's own `rejected`) → the date rule → the state rule. A team member asking about a future visit
--      therefore gets `not_today`, never `wrong_state`; nobody outside the team learns the visit date.
-- Unchanged: pause and resume; past-dated and today's visits (a forgotten tap can still be recorded); F3 time
--   corrections (CGR-65 (a)); who may move a visit and `reschedule_visit` (J3, ABS1-C4, ABS1-C5, CGR-35), which stays
--   the audited route for a visit done early: move it to today, then start it.
-- Engineering question 1 (brief): no job or command in the database calls these commands (PLAN2 generation, COVER1,
--   ABS1 release, LEAVE1 return only insert, release or move visits). Checked with a search of every migration.
-- Idempotent: re-running this file changes nothing (patches carry a marker; create or replace; catalogue upsert).

-- 1. Audit value catalogue (AUD1-1): the new key is a closed code -------------------------------------------------------
insert into private.audit_value_classes (table_name, key, class)
values ('care_visits', 'outcome', 'code')
on conflict (table_name, key) do nothing;

-- 2. The refusal row ---------------------------------------------------------------------------------------------------
create or replace function private.write_visit_refusal(p_visit public.care_visits, p_command text, p_outcome text)
returns text
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.audit_events
    (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values
    (p_visit.organization_id, (select auth.uid()),
     coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', session_user::text),
     'care_visits', p_visit.id, p_command, null,
     jsonb_build_object('outcome', jsonb_build_object('old', null, 'new', p_outcome)));
  return p_outcome;
end;
$$;
revoke all on function private.write_visit_refusal(public.care_visits, text, text) from public, anon, authenticated;
comment on function private.write_visit_refusal(public.care_visits, text, text) is
  'VIS1 / ADR-111: one audit row for a refused field action (outcome code only, no idempotency key). Called only by '
  'SECURITY DEFINER commands.';

-- 3. The day rule ------------------------------------------------------------------------------------------------------
-- Returns the refusal outcome for a team member of the visit, or null (the command goes on with its own checks).
create or replace function private.visit_day_refusal(p_command text, p_visit_id uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v          public.care_visits%rowtype;
  today      date := (private.at_zurich(private.now()))::date;
  started_on date;
begin
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then
    return null;   -- not visible to her: the command's own check refuses it
  end if;
  if p_command in ('depart_visit', 'start_visit', 'record_no_show', 'end_visit_not_completed') then
    if v.visit_date > today then
      return private.write_visit_refusal(v, p_command, 'not_today');
    end if;
  elsif p_command = 'complete_visit' then
    select (private.at_zurich(max(e.occurred_at)))::date into started_on
    from public.visit_events e
    where e.visit_id = v.id and e.event_type = 'started';
    -- A started visit dated after today was necessarily started before its date (also without an event row, e.g. a
    -- status written by maintenance before VIS1).
    if v.visit_date > today or (started_on is not null and started_on < v.visit_date) then
      return private.write_visit_refusal(v, p_command, 'started_before_date');
    end if;
  end if;
  return null;
end;
$$;
revoke all on function private.visit_day_refusal(text, uuid) from public, anon;
grant execute on function private.visit_day_refusal(text, uuid) to authenticated;
comment on function private.visit_day_refusal(text, uuid) is
  'VIS1 / ADR-111 / CGR-87: depart, start, no-show and not-completed refuse a visit dated after today (Europe/Zurich) '
  'with not_today; complete refuses a visit started on a day before its visit_date with started_before_date. '
  'Writes one audit row per refusal; null when the action may go on. Team members of the visit only.';

-- 4. Patch the commands from their own current definitions (signature, grants, security unchanged) --------------------
create or replace function private.vis1_patch(p_fn text, p_from text, p_to text, p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
begin
  if position(p_marker in def) > 0 then
    return;   -- already applied (idempotent)
  end if;
  if (length(def) - length(replace(def, p_from, ''))) / length(p_from) <> 1 then
    raise exception 'VIS1 patch for % must match exactly once: %', p_fn, p_from;
  end if;
  execute replace(def, p_from, p_to);
end;
$$;

-- 4a. depart, start, complete (pause and resume pass through: the rule returns null for them).
select private.vis1_patch('private.transition_visit(text, uuid, text[], text, uuid)',
E'  update public.care_visits set status = p_to\n',
E'  -- VIS1 / CGR-87: the visit\'s day (not_today, started_before_date); one audit row, nothing else changes.
  declare
    vis1_out text := private.visit_day_refusal(p_command, p_visit_id);
  begin
    if vis1_out is not null then
      return private.end_command(vis1_out);
    end if;
  end;
  update public.care_visits set status = p_to\n',
'VIS1 / CGR-87');

-- 4b. record_no_show: after the visibility check, before the state check.
select private.vis1_patch('public.record_no_show(uuid, text, uuid, boolean)',
E'  if v.status <> \'on_the_way\' then return private.end_command(\'wrong_state\'); end if;',
E'  -- VIS1 / CGR-87: not on a visit dated after today.
  if v.visit_date > (private.at_zurich(private.now()))::date then
    return private.end_command(private.write_visit_refusal(v, \'record_no_show\', \'not_today\'));
  end if;
  if v.status <> \'on_the_way\' then return private.end_command(\'wrong_state\'); end if;',
'VIS1 / CGR-87');

-- 4c. end_visit_not_completed: after the lock and the access check, before the state check.
select private.vis1_patch('public.end_visit_not_completed(uuid, text, text, uuid)',
E'  if v.status not in (\'started\', \'paused\') then return private.end_command(\'wrong_state\'); end if;',
E'  -- VIS1 / CGR-87: not on a visit dated after today.
  if v.visit_date > (private.at_zurich(private.now()))::date then
    return private.end_command(private.write_visit_refusal(v, \'end_visit_not_completed\', \'not_today\'));
  end if;
  if v.status not in (\'started\', \'paused\') then return private.end_command(\'wrong_state\'); end if;',
'VIS1 / CGR-87');

drop function private.vis1_patch(text, text, text, text);

comment on function public.depart_visit(uuid, uuid) is
  'F2 + VIS1: planned → on_the_way. Refused with not_today for a visit dated after today (Europe/Zurich).';
comment on function public.start_visit(uuid, uuid) is
  'F2 + VIS1: planned/on_the_way → started. Refused with not_today for a visit dated after today (Europe/Zurich).';
comment on function public.complete_visit(uuid, uuid) is
  'F2 + VIS1: started → completed. Refused with started_before_date when it was started on a day before its '
  'visit_date (Europe/Zurich). No billable flag (SR-09).';
comment on function public.record_no_show(uuid, text, uuid, boolean) is
  'C1 + DOOR1-5 (0072): records that the client was not reached, with the required fact "an der Tür" (p_at_door) and a '
  'note (3-1000 characters). Team members only; after departure (on_the_way). VIS1: refused with not_today for a '
  'visit dated after today (Europe/Zurich).';
comment on function public.end_visit_not_completed(uuid, text, text, uuid) is
  'CSR1 / CGR-20: ends a started or paused visit as not completed (status interrupted) with a reason. Team member or '
  'coordinator. No billable fact, no report obligation, not counted as completed. Interim safe default until D-31. '
  'VIS1: refused with not_today for a visit dated after today (Europe/Zurich).';
