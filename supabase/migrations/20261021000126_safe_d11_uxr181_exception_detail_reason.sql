-- SAFE-D11 follow-up, UXR-181 (`uxa`, medium; brief docs/agents/briefs/SAFE-D11.md §PO 20:39 (2) and §PO 21:39; ADR-185).
-- Documented safety exception, gate «Simulation, synthetic data». No new care rule, no new wording, no grant, policy or
-- column; visibility of both exception types unchanged (coordination roles only, `operations_exceptions`).
--
-- Before (IMPLEMENTED, 0024:465 and 0125 step 3): the detail of `case_not_ready` and of `case_reopened_no_team` is the
--   list of readiness ITEM CODES (`m ->> 'item'`, e.g. «insurance_type»), joined by «, ». Operations reads a code.
-- After (this migration): both details are the stored REASON of each missing item (`m ->> 'reason'`, the words of
--   `private.case_readiness`, 0013:166-171, e.g. «Versicherungsart fehlt oder unbekannt»), joined by «; », in readiness
--   order. Both types read the same `private.case_readiness` output in the same derived function, so one fact has one
--   wording. The reason texts are not changed and not copied here.
-- Idempotent: a patch of the current definition (pg_get_functiondef; the find must match exactly twice) carrying the
-- marker UXR-181, skipped when present.

create or replace function private.uxr181_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0126 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0126 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.uxr181_patch(text, text[], text) from public, anon, authenticated;

select private.uxr181_patch('private.derived_exceptions(uuid)', array[
  '(select string_agg(m ->> ''item'', '', '') from jsonb_array_elements(private.case_readiness(c.id)) m)',
  '(select string_agg(m.value ->> ''reason'', ''; '' order by m.ord) /* UXR-181 */'
  || ' from jsonb_array_elements(private.case_readiness(c.id)) with ordinality m(value, ord))',
  '2'], 'UXR-181');
revoke all on function private.derived_exceptions(uuid) from public, anon, authenticated;

drop function private.uxr181_patch(text, text[], text);
