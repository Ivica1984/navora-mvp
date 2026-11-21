-- BK-e1b / UXR-237, UXR-239 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 05:39; ADR-203 (11)).
-- `public.field_visits` returns `from_take boolean` (true exactly when `care_visits.order_take_id` is set), so the /field
-- card of a visit written from a take can name the kind («Übernommene Schicht», UXR-239) and the simulation limit of the
-- place line (UXR-237). Only a flag: no take id, no order data and no client identifier is added (`lca`, CGR-243).
-- Presentation only: no rule about planning, covering or releasing changes. Idempotent: the patch carries the marker
-- BK-E1B-F and is skipped when present; it must match exactly once, otherwise the migration stops.

do $$
declare
  def text := pg_get_functiondef('public.field_visits(date)'::regprocedure);
  f1  text := E'v.system_end_reason  -- BK-E1B-R (CGR-242 (c))\n  from public.care_visits v';
  f2  text := E', system_end_reason text)\n LANGUAGE sql';
begin
  if position('BK-E1B-F' in def) > 0 then
    return;
  end if;
  if (length(def) - length(replace(def, f1, ''))) / length(f1) <> 1
     or (length(def) - length(replace(def, f2, ''))) / length(f2) <> 1 then
    raise exception '0140: field_visits patch did not match exactly once';
  end if;
  def := replace(def, f1, E'v.system_end_reason,  -- BK-E1B-R (CGR-242 (c))\n'
                       || E'         v.order_take_id is not null  -- BK-E1B-F (UXR-237, UXR-239)\n  from public.care_visits v');
  def := replace(def, f2, E', system_end_reason text, from_take boolean)\n LANGUAGE sql');
  execute 'drop function public.field_visits(date)';
  execute def;
end;
$$;
revoke all on function public.field_visits(date) from public, anon;
grant execute on function public.field_visits(date) to authenticated;
