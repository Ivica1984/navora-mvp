-- ABS1-C5 (docs/agents/briefs/ABS1.md, PO review 2026-10-23 18:15; patient safety, rides along with CSR1 part 10).
-- ADR-063. Strict default within product authority, not a clinical rule.
--
-- Before (0050, ABS1-C4): `reschedule_visit` into the absence of the visit's responsible member writes the move and
--   then releases the visit through the one release rule. That rule never touches visits dated before today (0046),
--   so a move to yesterday (allowed by `check_visit_slot`) inside her absence left the visit with her: a past visit that
--   names an absent member as responsible looks settled although it was never done or was done by someone else.
-- Now: when, after the move and the ABS1-C4 release, the visit would still name a responsible member absent at its
--   interval (`member_absent_during`, the one interval of 0048), the command returns
--   {"result": "rejected", "reason": "responsible_absent"} and writes nothing: the move, the `moved` log row and any
--   release are undone together (one subtransaction), audit rows included, so a replay is evaluated again like every
--   other rejection.
--   Generic on purpose: it does not test "before today", it tests the outcome the PO named, so any future gap in the
--   release rule is refused the same way.
-- Unchanged: a move into her absence on a date the release rule covers still releases (ABS1-C4 (c)); a move outside
--   any absence is unchanged. Whether a planned visit may be moved into the past at all is not decided here (PO).
-- No clinical, labour-law or leave rule is modelled.

create function private.abs1c5_patch(p_fn text, p_pairs text[])
returns void language plpgsql set search_path = ''
as $$
declare
  def text := pg_get_functiondef(p_fn::regprocedure);
  i   integer;
begin
  for i in 1 .. coalesce(array_length(p_pairs, 1), 0) by 2 loop
    if (length(def) - length(replace(def, p_pairs[i], ''))) / length(p_pairs[i]) <> 1 then
      raise exception 'ABS1-C5 patch for % must match exactly once: %', p_fn, p_pairs[i];
    end if;
    def := replace(def, p_pairs[i], p_pairs[i + 1]);
  end loop;
  execute def;
end;
$$;

select private.abs1c5_patch('public.reschedule_visit(uuid, date, time, time, text, uuid)', array[
E'  before := private.visit_slot_json(v);\n',
E'  -- ABS1-C5: the move, its log and the ABS1-C4 release run in one subtransaction, undone together when refused.
  begin
  before := private.visit_slot_json(v);\n',
E'    n_rel := case when v.responsible_user_id is null then 1 else 0 end;\n  end if;\n',
E'    n_rel := case when v.responsible_user_id is null then 1 else 0 end;\n  end if;

  -- ABS1-C5: never leave the visit with a member absent at its interval (the release rule skips past visits).
  if v.responsible_user_id is not null
     and private.member_absent_during(v.team_id, v.responsible_user_id,
                                      lower(private.visit_interval(v)), upper(private.visit_interval(v))) then
    raise exception using errcode = ''NVC05'', message = ''abs1-c5: responsible member absent after the move'';
  end if;
  exception when sqlstate ''NVC05'' then
    perform private.end_command(''rejected'');
    return jsonb_build_object(''result'', ''rejected'', ''reason'', ''responsible_absent'');
  end;
'
]);
comment on function public.reschedule_visit(uuid, date, time, time, text, uuid) is
  'J3: moves a planned visit with a reason. ABS1-C4: a move into the absence of its responsible member is not '
  'refused; the visit is released (fixed text Abwesenheit) and returns {result, visit_id, released: true, flags}. '
  'ABS1-C5: when the visit would still name a member absent at its interval (a date the release rule does not cover, '
  'i.e. before today), the move is refused with responsible_absent and nothing is written.';

drop function private.abs1c5_patch(text, text[]);
