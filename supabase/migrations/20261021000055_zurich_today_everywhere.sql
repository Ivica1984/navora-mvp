-- One calendar "today" for the whole database: Europe/Zurich. ADR-068. Engineering fix, no product rule changes.
--
-- Before: most commands derive today as (now() at time zone 'Europe/Zurich')::date, but five function bodies still
--   use `current_date`, which follows the session time zone (UTC on Supabase and in CI). Between 00:00 and 02:00
--   Zurich time in summer (00:00 and 01:00 in winter) the two differ by one day, so for one or two hours a night:
--     * OPS1 `derived_exceptions`: "order expiring" and "care-plan review overdue" were computed against yesterday;
--     * `pause_case` accepted an expected end of yesterday;
--     * `apply_case_facts` (requested start window) and `add_care_plan_item` (review date not in the past) judged
--       dates against yesterday.
--   CI found it (2026-10-24 00:03 Zurich): seed, pgTAP and e2e mixed both definitions and went red in that window.
-- Now (IMPLEMENTED): every function in `public` and `private` (extension functions excluded) that mentions
--   `current_date` is re-created from its own current definition with `current_date` replaced by
--   (now() at time zone 'Europe/Zurich')::date. Signatures, owners, grants, security and search_path are unchanged
--   (CREATE OR REPLACE of the definition pg_get_functiondef returns). The migration fails if any remains.
--   Idempotent: a second run finds nothing to replace.
-- Guard: pgTAP 056 fails when a later migration brings `current_date` back into a function body.

do $$
declare
  r   record;
  def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prokind = 'f'
      and p.prosrc ~* '\mcurrent_date\M'
      and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    def := pg_get_functiondef(r.oid);
    execute regexp_replace(def, '\mcurrent_date\M', '(now() at time zone ''Europe/Zurich'')::date', 'gi');
  end loop;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
      and p.prosrc ~* '\mcurrent_date\M'
      and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  ) then
    raise exception 'ADR-068: a function body in public/private still uses current_date';
  end if;
end;
$$;
