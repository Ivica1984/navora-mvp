-- CSR1 part 11: CGR-34 (ABS1 condition, docs/agents/briefs/ABS1.md, PO 2026-10-23 20:15; `cra` addendum 19:57). ADR-066.
-- Product decision of the PO (a documentation-integrity rule, not a clinical rule). Whether care that was due and not
-- given must be made up or reported is a clinical question (D-28, D-31) and is not decided here.
--
-- Before: a past planned visit flagged by CGR-32 (0053: planned, its responsible member absent at its interval) can be
--   closed only with `cancel_visit` (0024). The flag is computed from the absence, so once the visit is cancelled the
--   record reads as an ordinary cancellation: that it was not done because the responsible member was absent is lost.
-- Now (IMPLEMENTED in this migration):
--   1. `visit_status_notes.responsible_absent boolean not null default false`. Only a `cancelled` note can carry true
--      (check constraint). The table stays append-only (0024 trigger), so the stored fact is immutable: withdrawing or
--      shortening the absence later does not erase it. `authenticated` has no insert, update or delete privilege; the
--      caller cannot set it. Existing rows get false (nothing was recorded before this migration).
--   2. `cancel_visit` sets it server-side when the CGR-32 condition holds at the moment of the cancellation: the visit
--      is `planned`, dated before today (Europe/Zurich), and `private.visit_responsible_absent` (0053) is true. No new
--      reason code, no new parameter, no extra tap.
--   3. The audit trigger on `visit_status_notes` records the new column with kind and reason_code.
--   4. Readers: `field_visit_status_notes` (/field card) returns the column; HAND1 (`private.handover_entries`) adds it
--      to the detail of a status-note entry; OPS1 (`operations_exceptions`) gives a `team_cancellation_late` row the
--      flag `not_done_responsible_absent` when its cancellation stored the fact (a team cancellation of a past visit
--      is listed there, 0024/0031). The app shows the fixed text
--      "nicht durchgeführt: zuständige Person abwesend gemeldet"; no reason for the absence exists to show.
-- Unchanged: the reason list of `cancel_visit`, who may cancel, the CGR-32 flag on overdue alerts (still computed).

-- 1. The stored fact -------------------------------------------------------------------------------------------------
alter table public.visit_status_notes add column if not exists responsible_absent boolean not null default false;
alter table public.visit_status_notes drop constraint if exists visit_status_notes_responsible_absent_kind;
alter table public.visit_status_notes add constraint visit_status_notes_responsible_absent_kind
  check (not responsible_absent or kind = 'cancelled');
comment on column public.visit_status_notes.responsible_absent is
  'CSR1 / CGR-34: set by cancel_visit (server side, never by the caller) when the cancelled visit was planned, dated '
  'before today and its responsible member was recorded absent at its interval (CGR-32). Append-only, so immutable.';

-- 2. Audited with kind and reason code ------------------------------------------------------------------------------
drop trigger if exists audit_visit_status_notes on public.visit_status_notes;
create trigger audit_visit_status_notes after insert on public.visit_status_notes
  for each row execute function private.write_audit_event('kind', 'reason_code', 'responsible_absent');

-- 3. cancel_visit stores it (same signature and grants as 0024) ------------------------------------------------------
create or replace function public.cancel_visit(p_visit_id uuid, p_reason_code text, p_reason text, p_idempotency_key uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v   public.care_visits%rowtype;
  why text := nullif(btrim(p_reason), '');
  absent boolean;
begin
  if uid is null then return 'rejected'; end if;
  if p_reason_code is null or p_reason_code not in ('client_cancelled', 'client_in_hospital', 'team_cancelled', 'other') then
    raise exception 'cancel reason: client_cancelled, client_in_hospital, team_cancelled or other' using errcode = '22023';
  end if;
  if p_reason_code = 'other' and (why is null or char_length(why) < 3) then
    raise exception 'reason "other" needs a note' using errcode = '22023';
  end if;
  if private.begin_command('cancel_visit', p_idempotency_key) then return private.end_command('duplicate'); end if;
  select * into v from private.visit_for_team(p_visit_id);
  if v.id is null then return private.end_command('rejected'); end if;
  if v.status not in ('planned', 'on_the_way') then return private.end_command('wrong_state'); end if;   -- before it starts
  -- CSR1 / CGR-34: the CGR-32 condition, read before the status changes; stored, never taken from the caller.
  absent := v.status = 'planned'
            and v.visit_date < (now() at time zone 'Europe/Zurich')::date
            and private.visit_responsible_absent(v.id);
  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key,
                                         responsible_absent)
  values (v.organization_id, v.id, 'cancelled', p_reason_code, why, uid, p_idempotency_key, absent);
  update public.care_visits set status = 'cancelled', suspended_at = null where id = v.id;
  return private.end_command('ok');
end;
$$;
comment on function public.cancel_visit(uuid, text, text, uuid) is
  'C1: cancel a planned or on-the-way visit with a reason (client_cancelled, client_in_hospital, team_cancelled, other '
  'with a note). CSR1 / CGR-34: a planned visit dated before today whose responsible member is recorded absent at its '
  'interval is cancelled with responsible_absent = true on its status note (server side).';

-- 4a. /field card: the column ---------------------------------------------------------------------------------------
drop function if exists public.field_visit_status_notes(date);
create function public.field_visit_status_notes(p_date date)
returns table (visit_id uuid, kind text, reason_code text, note text, created_at timestamptz,
               actor_kind text, actor_name text, actor_qualification text, actor_role text, responsible_absent boolean)
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
         end,
         s.responsible_absent
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
  'a label (me, team member with name and qualification, coordination role with name, or former); no user id. '
  'CGR-34: responsible_absent on a cancellation of a visit not done because its responsible member was absent.';

-- 4b. HAND1: the detail of a status-note entry carries it -------------------------------------------------------------
do $do$
declare
  fn   text := 'private.handover_entries(uuid, uuid)';
  def  text := pg_get_functiondef(fn::regprocedure);
  find text := $f$jsonb_build_object('reason_code', n.reason_code, 'note', n.note)$f$;
  repl text := $r$jsonb_build_object('reason_code', n.reason_code, 'note', n.note, 'responsible_absent', n.responsible_absent)$r$;
  hits int  := (length(def) - length(replace(def, find, ''))) / length(find);
begin
  if position(repl in def) > 0 then
    return;   -- already applied (idempotent)
  end if;
  if hits <> 1 then
    raise exception 'CGR-34 patch for % must match exactly once, found %', fn, hits;
  end if;
  execute replace(def, find, repl);
end;
$do$;

-- 4c. OPS1: a late team cancellation carries the stored fact as a flag (return type unchanged, no drop) -------------
do $do$
declare
  fn   text := 'public.operations_exceptions()';
  def  text := pg_get_functiondef(fn::regprocedure);
  find text := $f$then array['responsible_absent'] else array[]::text[] end$f$;
  repl text := $r$then array['responsible_absent']
              -- CSR1 / CGR-34: stored on the cancellation (0054), not computed
              when d.exception_type = 'team_cancellation_late' and exists (
                     select 1 from public.visit_status_notes sn
                     where sn.visit_id = d.entity_id and sn.kind = 'cancelled' and sn.responsible_absent)
              then array['not_done_responsible_absent'] else array[]::text[] end$r$;
  hits int  := (length(def) - length(replace(def, find, ''))) / length(find);
begin
  if position('not_done_responsible_absent' in def) > 0 then
    return;   -- already applied (idempotent)
  end if;
  if hits <> 1 then
    raise exception 'CGR-34 patch for % must match exactly once, found %', fn, hits;
  end if;
  execute replace(def, find, repl);
end;
$do$;
