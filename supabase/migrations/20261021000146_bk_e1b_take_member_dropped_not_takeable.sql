-- BK-e1b / CGR-253 / UXR-245 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 11:39 (1), PO choice (b);
-- issue #1445; `cra` 11:26, `uxa` 10:48; ADR-203 (18)). Red first: pgTAP 148 §10 and §13 (b) (commit d8db695) fail
-- before this migration. Gate «Simulation, synthetic data» only.
--
-- Before: `take_signal` accepted a take of a `take_member_dropped` signal (0144, CGR-246) like any other kind. The take
--   neither moves the visit nor sends anybody, but it removed the card from the team's open list (`splitSignals`) and,
--   for a take that stops the step, silenced the SIG1 step to Operations: a false «handled» state while nobody goes.
-- Now (IMPLEMENTED in this migration): `take_signal` refuses a signal of the kind `take_member_dropped` for every
--   caller (the named member, a colleague, Operations) with `{"result": "rejected", "reason": "kind_not_takeable"}`.
--   The refusal comes after the recipient check, so a caller who is not a recipient still gets the unchanged
--   `not_recipient` (no fact about another team's signal). No `signal_takes` row is written and `taken_by` stays null,
--   so the signal stays open for every recipient and the SIG1 step to Operations runs at its time as without a take
--   (the untaken threshold `signal_untaken` is unchanged, PROVISIONAL D-28). The command log records the refusal
--   through the existing `private.end_command('rejected')`.
-- Unchanged: signature, grants, every other signal kind, `my_signals`, recipients, the escalation rule. No data change
--   (no take of this kind exists outside synthetic test runs; pgTAP rolls back). The real hand-over action is
--   H-BK-10:39 (a later slice, Clinical Owner first); until then this signal is information only and cannot be
--   silenced. Who acts and the lead time after the signal stay with the Clinical Owner (CR-232). No clinical, legal or
--   tariff rule is set here.
-- Body patch carries the marker BK-E1B-T and must match exactly once (idempotent: a patched body is skipped).

create or replace function private.bk_e1b_t_patch(p_fn text, p_find text, p_replace text, p_marker text)
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  n   integer;
begin
  if position(p_marker in def) > 0 then
    return;
  end if;
  n := (length(def) - length(replace(def, p_find, ''))) / length(p_find);
  if n <> 1 then
    raise exception '0146 patch for % must match once, matched %: %', p_fn, n, p_find;
  end if;
  def := replace(def, p_find, p_replace);
  if position(p_marker in def) = 0 then
    raise exception '0146 patch for % lacks its marker %', p_fn, p_marker;
  end if;
  execute def;
end;
$$;
revoke all on function private.bk_e1b_t_patch(text, text, text, text) from public, anon, authenticated;

select private.bk_e1b_t_patch('public.take_signal(uuid, uuid)',
  E'    return jsonb_build_object(''result'', private.end_command(''rejected''), ''reason'', ''not_recipient'');\n'
  || E'  end if;\n',
  E'    return jsonb_build_object(''result'', private.end_command(''rejected''), ''reason'', ''not_recipient'');\n'
  || E'  end if;\n'
  || E'  -- BK-E1B-T (CGR-253, PO 11:39 choice (b)): nobody takes a take_member_dropped signal; it stays open and the\n'
  || E'  -- SIG1 step to Operations runs as without a take.\n'
  || E'  if s.signal_kind = ''take_member_dropped'' then\n'
  || E'    return jsonb_build_object(''result'', private.end_command(''rejected''), ''reason'', ''kind_not_takeable'');\n'
  || E'  end if;\n',
  'BK-E1B-T');

drop function private.bk_e1b_t_patch(text, text, text, text);

comment on function public.take_signal(uuid, uuid) is
  'SIG1-4 (ADR-074) with SIG1-C1, LEAVE1-14, LEAVE1-C3: the caller, a recipient, takes the signal. BK-e1b / CGR-253 '
  '(0146, ADR-203 (18)): a take_member_dropped signal is refused for every caller (kind_not_takeable); no take row.';
