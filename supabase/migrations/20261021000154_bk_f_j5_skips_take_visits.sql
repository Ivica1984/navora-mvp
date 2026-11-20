-- BK-f, contract 2026-11-20 06:39 point 2 (h), decision (a): finding BKF-F1 (docs/engineering/probes/BK-f_ADR_DRAFT.md).
-- Before (IMPLEMENTED, 0051, guarded by 0074 LEAVE1-3): `public.generate_billable_facts` and the hold-lift trigger call
-- `private.build_billable_fact` for every `final` report, also for a BK take visit (`case_id = null`, 0138); the insert
-- into `public.billable_facts.case_id not null` failed, so the team's whole J5 month failed (pgTAP 154 red on 4c247b0,
-- SQLSTATE 23502), and a BK shift reached a KLV-modelled path (D-44, BK-10 exclude that).
-- Now: the live definitions are patched in place (pattern of 0138), with exactly two additions: the month loop selects
-- only visits with a case, and `build_billable_fact` returns null for a case-less visit (reason in the comment; no
-- error, so a hold lift on a take visit never fails). Every earlier patch (LEAVE1-3 guard of 0074) stays. No table,
-- grant or policy change (`create or replace` keeps grants). Idempotent: the patches carry the marker BKF-F1.
-- Way back: re-create both functions from their definitions before this migration (brings the failure back).

create or replace function private.bk_f_patch(p_fn text, p_pairs text[], p_marker text)
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
      raise exception '0154 patch for % must match % time(s), matched %: %', p_fn, p_pairs[i + 2], n, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  if position(p_marker in def) = 0 then
    raise exception '0154 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_f_patch(text, text[], text) from public, anon, authenticated;

select private.bk_f_patch('private.build_billable_fact(uuid, uuid)', array[
  E'  select * into v from public.care_visits where id = r.visit_id for update;\n',
  E'  select * into v from public.care_visits where id = r.visit_id for update;\n'
  || E'  -- BKF-F1 (0154): a BK take visit has no case (0138). It is never a KLV-modelled J5 fact (D-44, BK-10); its billing\n'
  || E'  -- is the team invoice draft of BK-f. Skipped with this reason, never an error (a hold lift must not fail).\n'
  || E'  if v.case_id is null then return null; end if;\n',
  '1'], 'BKF-F1');

select private.bk_f_patch('public.generate_billable_facts(date)', array[
  E'      and private.is_org_member(r.organization_id)\n',
  E'      and v.case_id is not null   -- BKF-F1: take visits (no case) are billed by BK-f, never by J5 (D-44, BK-10)\n'
  || E'      and private.is_org_member(r.organization_id)\n',
  '1'], 'BKF-F1');

drop function private.bk_f_patch(text, text[], text);
