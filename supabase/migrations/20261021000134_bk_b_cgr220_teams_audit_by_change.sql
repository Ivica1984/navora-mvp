-- BK-b, CGR-220 (`cra` 2026-11-14 13:30, advisory S3; PO amendment 13:39 (5), `docs/agents/briefs/BK.md`; ADR-197):
-- the `audit_teams` row trigger skips by WHAT CHANGED, never by a session value.
--
-- Before (0130): `WHEN (current_setting('navora.command') <> 'set_team_reach')`. A database session that set that
-- value could change any audited team column without an audit row (not reachable through the API, but an audit
-- control must not be switchable by a session setting).
--
-- After:
-- 1. The trigger is skipped only when the update changed nothing but the two columns `set_team_reach` owns
--    (`max_distance_km`, `reach_changed_at`) and at least one of them. That command writes its own audit row with old
--    and new distance and postcodes (0130, AUT-117 (d)). Every other update, including an update that changes nothing
--    and a mixed update, writes its trigger row exactly as before.
-- 2. `max_distance_km` joins the trigger's column list, so a mixed update records the distance too (class `code`,
--    already listed by 0130).
-- 3. `set_team_reach` updates the team row only when distance or change date actually differs, so a postcode-only
--    change in the same transaction as an earlier one is not a no-change update (which the trigger would record as an
--    extra empty row). Patched in place (anchor found exactly once), the rest of the 0130 body is unchanged.
-- Residual (ADR-197): a privileged database role that writes only the reach columns directly gets no trigger row. The
-- app has no write grant on these columns (pgTAP 140); such a role can also disable any trigger.
-- No clinical, tariff or legal rule. Idempotent: `drop ... if exists`, `create or replace`, anchor patch is skipped when
-- already applied.

drop trigger if exists audit_teams on public.teams;
create trigger audit_teams
  after update on public.teams
  for each row
  when (
    (to_jsonb(old) - array['max_distance_km', 'reach_changed_at'])
      is distinct from (to_jsonb(new) - array['max_distance_km', 'reach_changed_at'])
    or (old.max_distance_km, old.reach_changed_at) is not distinct from (new.max_distance_km, new.reach_changed_at)
  )
  execute function private.write_audit_event('priority', 'coach_name', 'status', 'open_slots', 'utilization', 'region',
                                             'max_distance_km');

insert into private.audit_value_classes (table_name, key, class) values ('teams', 'max_distance_km', 'code')
on conflict do nothing;

do $$
declare
  def text := pg_get_functiondef('public.set_team_reach(uuid, text[], numeric, uuid)'::regprocedure);
  old_line constant text :=
    E'  update public.teams set max_distance_km = p_max_distance_km, reach_changed_at = private.now() where id = t.id;\n';
  new_line constant text :=
    E'  update public.teams set max_distance_km = p_max_distance_km, reach_changed_at = private.now()\n'
    || E'   where id = t.id  -- CGR-220 (ADR-197): no no-change update, so no empty trigger row\n'
    || E'     and (max_distance_km, reach_changed_at) is distinct from (p_max_distance_km, private.now());\n';
begin
  if position(new_line in def) > 0 then
    return;  -- already applied
  end if;
  if (length(def) - length(replace(def, old_line, ''))) / length(old_line) <> 1 then
    raise exception 'CGR-220: set_team_reach anchor not found exactly once';
  end if;
  execute replace(def, old_line, new_line);
end;
$$;
revoke all on function public.set_team_reach(uuid, text[], numeric, uuid) from public, anon;
grant execute on function public.set_team_reach(uuid, text[], numeric, uuid) to authenticated;

comment on trigger audit_teams on public.teams is
  'CGR-220 / ADR-197: skipped only when nothing but max_distance_km / reach_changed_at changed (set_team_reach writes '
  'its own row); never by a session value.';
