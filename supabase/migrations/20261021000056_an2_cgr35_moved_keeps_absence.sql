-- AN2, first change: CGR-35 (ABS1 condition, docs/agents/briefs/ABS1.md, PO 2026-10-23 23:15; `cra` 22:30, advisory
-- S3, PS-28). ADR-069. Product decision of the PO (a documentation-integrity rule, not a clinical rule). Whether care
-- that was due and not given must be made up, and whether a move counts as making it up, stays `clinical` (D-28, D-31).
--
-- Before: a past planned visit flagged by CGR-32 (0053: planned, dated before today, its responsible member absent at
--   its interval) can be moved forward with `reschedule_visit` ("Folgeeinsatz"). The `moved` row in
--   `visit_plan_changes` reads as an ordinary planning change; once the absence is shortened or withdrawn, the fact
--   that the care due on the original date was not given because the responsible member was reported absent is lost.
--   CGR-34 (0054) closed the same gap for a cancellation.
-- Now (IMPLEMENTED in this migration):
--   1. `visit_plan_changes.responsible_absent boolean not null default false`. Only a `moved` row can carry true
--      (check constraint). The table stays append-only (0014 trigger), so the stored fact is immutable: a later
--      withdrawal or shortening of the absence does not erase it. `authenticated` keeps select only (0014); the caller
--      cannot set it. Existing rows get false (nothing was recorded before this migration).
--   2. `reschedule_visit` sets it server-side when, BEFORE the move, the CGR-34 condition holds: the visit is
--      `planned`, dated before today (Europe/Zurich, ADR-068), and `private.visit_responsible_absent` (0053) is true.
--      No new parameter, no new reason code, no extra tap; the typed reason stays as today.
--   3. Audit: `visit_plan_changes` had no audit trigger (it is itself an append-only log, and the move is audited on
--      `care_visits`). Its `id` is a bigint, so the generic `private.write_audit_event` (entity_id uuid) cannot be used.
--      A dedicated insert trigger writes one `audit_events` row per `moved` row: entity = the visit, table
--      `visit_plan_changes`, changed = {change, responsible_absent}, with the command and idempotency key of the
--      calling command (same shape as `write_audit_event`).
--   4. Readers of a `moved` row: HAND1 (`private.handover_entries`) adds the column to the detail of a `visit_moved`
--      entry; `/team` (`public.team_cases`, `last_change` of a planned visit) returns it. The app shows the fixed text
--      "nicht durchgeführt: zuständige Person abwesend gemeldet". No reason for the absence exists to show.
-- Unchanged: who may move, ABS1-C4 (release on a move into her absence), ABS1-C5 (refusal when she would stay
--   responsible while absent), the CGR-32 flag on overdue alerts (still computed), the reason rule of moves.

-- 1. The stored fact -------------------------------------------------------------------------------------------------
alter table public.visit_plan_changes add column if not exists responsible_absent boolean not null default false;
alter table public.visit_plan_changes drop constraint if exists visit_plan_changes_responsible_absent_change;
alter table public.visit_plan_changes add constraint visit_plan_changes_responsible_absent_change
  check (not responsible_absent or change = 'moved');
comment on column public.visit_plan_changes.responsible_absent is
  'AN2 / CGR-35: set by reschedule_visit (server side, never by the caller) when the moved visit was, before the move, '
  'planned, dated before today (Europe/Zurich) and its responsible member was recorded absent at its interval '
  '(CGR-32). Only on moved rows. Append-only, so immutable.';

-- 2. Audited: one row per move, entity = the visit -------------------------------------------------------------------
create or replace function private.audit_visit_plan_move()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.audit_events
    (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed)
  values
    (new.organization_id, (select auth.uid()),
     coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', session_user::text),
     tg_table_name, new.visit_id,
     nullif(current_setting('navora.command', true), ''),
     nullif(current_setting('navora.idempotency_key', true), '')::uuid,
     jsonb_build_object('change', jsonb_build_object('old', null, 'new', new.change),
                        'responsible_absent', jsonb_build_object('old', null, 'new', new.responsible_absent)));
  return new;
end;
$$;
revoke all on function private.audit_visit_plan_move() from public, anon, authenticated;
comment on function private.audit_visit_plan_move() is
  'AN2 / CGR-35: audit row for a moved visit_plan_changes row (entity = visit, since the log id is a bigint).';

drop trigger if exists audit_visit_plan_moves on public.visit_plan_changes;
create trigger audit_visit_plan_moves after insert on public.visit_plan_changes
  for each row when (new.change = 'moved') execute function private.audit_visit_plan_move();

-- 3. reschedule_visit stores it (patched from its own definition; signature, grants and behaviour otherwise unchanged)
create function private.cgr35_patch(p_fn text, p_pairs text[], p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  if position(p_marker in def) > 0 then
    return;   -- already applied (idempotent)
  end if;
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'CGR-35 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

select private.cgr35_patch('public.reschedule_visit(uuid, date, time, time, text, uuid)', array[
E'  n_rel  integer := 0;\n',
E'  n_rel  integer := 0;\n  absent boolean := false;\n',
E'  before := private.visit_slot_json(v);\n',
E'  before := private.visit_slot_json(v);
  -- AN2 / CGR-35: the CGR-32 condition, read before the move; stored, never taken from the caller.
  absent := v.status = \'planned\'
            and v.visit_date < (now() at time zone \'Europe/Zurich\')::date
            and private.visit_responsible_absent(v.id);\n',
E'insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id)
  values (v.organization_id, v.id, v.case_id, v.team_id, \'moved\', before, private.visit_slot_json(v), why, uid);',
E'insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id,
                                         responsible_absent)
  values (v.organization_id, v.id, v.case_id, v.team_id, \'moved\', before, private.visit_slot_json(v), why, uid, absent);'
], 'AN2 / CGR-35');
comment on function public.reschedule_visit(uuid, date, time, time, text, uuid) is
  'J3: moves a planned visit with a reason. ABS1-C4: a move into the absence of its responsible member is not '
  'refused; the visit is released (fixed text Abwesenheit) and returns {result, visit_id, released: true, flags}. '
  'ABS1-C5: when the visit would still name a member absent at its interval (a date the release rule does not cover, '
  'i.e. before today), the move is refused with responsible_absent and nothing is written. '
  'AN2 / CGR-35: a past planned visit whose responsible member is recorded absent at its interval is moved with '
  'responsible_absent = true on its moved row (server side).';

-- 4a. HAND1: the detail of a plan-change entry carries it -------------------------------------------------------------
select private.cgr35_patch('private.handover_entries(uuid, uuid)', array[
$f$'reason', case when pc.change = 'released' then null else pc.reason end)$f$,
$r$'reason', case when pc.change = 'released' then null else pc.reason end,
                              'responsible_absent', pc.responsible_absent)$r$
], $m$'responsible_absent', pc.responsible_absent$m$);

-- 4b. /team: the last change of a planned visit carries it ----------------------------------------------------------
select private.cgr35_patch('public.team_cases()', array[
$f$'own', pc.actor_id = (select auth.uid()))$f$,
$r$'own', pc.actor_id = (select auth.uid()),
                                                              'responsible_absent', pc.responsible_absent)$r$
], $m$'responsible_absent', pc.responsible_absent$m$);

drop function private.cgr35_patch(text, text[], text);
