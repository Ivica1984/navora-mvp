-- BK-e1b / CGR-250 (brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 08:39 (1), PO choice (b); `cra` 08:27;
-- ADR-203 (15)). Red first: pgTAP 148 §13 (commit 8437a29) fails on (b) and (d) before this migration.
-- Before: `record_absence` (and every other caller of `private.release_visits_between`: the member removal of ADM1,
--   the qualification change of CGR-11, the move into an absence of ABS1-C4) released a member's planned visits in the
--   period, take visits included. After `starts_at` the take is kept (CGR-242: no automatic release after the start),
--   so the take visit became memberless while its take stayed live: the take's visit had nobody named, was recorded
--   as «released» in the team plan and in `absence_releases`, and could be returned or offered as an open visit.
--   Before `starts_at` the same absence had already released the take and ended its visit (0139), so the release
--   found nothing; the hole was the case after the start.
-- Now (IMPLEMENTED in this migration): the one release rule never selects a visit with `order_take_id`. A take visit
--   keeps its named member, date, times and status on every path through the rule; the take's own course decides:
--   before the start the take is released by `private.recheck_member_takes` and its visit ended with its stored reason
--   by `private.end_take_visit` (unchanged); after the start take and visit stay and the client reads «nicht gedeckt»
--   through the unchanged ADR-199 (5) safety net. `change_absence` only returns visits recorded in `absence_releases`,
--   so it never reaches a take visit either (pgTAP 148 §13 (c)).
-- Also (IMPLEMENTED, found by pgTAP 148 §13 (d)): `private.aig1_apply_visit_responsible`, the apply step of a confirmed
--   AI proposal, re-assigned a take visit when called for it (the visit had a member equal to the expected one). No
--   proposal for a take visit can be created today (`propose_visit_responsible` refuses it, 0142), so the path was not
--   reachable through the commands; it now answers `not_open` for a take visit before anything is read or written
--   (defence in depth, same result as for a visit that is no longer open).
-- The CGR-246 signal for the case after the start is not built here (PLANNED, same slice).
-- Unchanged: signature, grants, every visit not from a take, every result shape. Patch is checked to match exactly once
-- and carries the marker BK-E1B-A (idempotent: a patched body is skipped). No data change. No clinical, legal or tariff
-- rule is set here.

do $$
declare
  fn   text := 'private.release_visits_between(uuid, uuid, timestamptz, timestamptz, text, uuid, boolean)';
  def  text := pg_get_functiondef(fn::regprocedure);
  find text := E'      and x.status = ''planned''                       -- suspended included (CGR-09); in progress never (CGR-10/18)\n';
  n    integer;
begin
  if position('BK-E1B-A' in def) > 0 then
    return;
  end if;
  n := (length(def) - length(replace(def, find, ''))) / length(find);
  if n <> 1 then
    raise exception '0143 patch for % must match once, matched %', fn, n;
  end if;
  def := replace(def, find, find
    || E'      and x.order_take_id is null  -- BK-E1B-A (CGR-250): a take visit is never released; its take decides\n');
  execute def;
end;
$$;
revoke all on function private.release_visits_between(uuid, uuid, timestamptz, timestamptz, text, uuid, boolean)
  from public, anon, authenticated;

do $$
declare
  fn   text := 'private.aig1_apply_visit_responsible(uuid, uuid, uuid, uuid)';
  def  text := pg_get_functiondef(fn::regprocedure);
  find text := E'  if not found then\n    return ''not_open'';\n  end if;\n';
  n    integer;
begin
  if position('BK-E1B-A' in def) > 0 then
    return;
  end if;
  n := (length(def) - length(replace(def, find, ''))) / length(find);
  if n <> 1 then
    raise exception '0143 patch for % must match once, matched %', fn, n;
  end if;
  def := replace(def, find, find
    || E'  if v.order_take_id is not null then  -- BK-E1B-A (CGR-250 (d)): an AI proposal never re-assigns a take visit\n'
    || E'    return ''not_open'';\n  end if;\n');
  execute def;
end;
$$;
revoke all on function private.aig1_apply_visit_responsible(uuid, uuid, uuid, uuid) from public, anon, authenticated;
comment on function private.release_visits_between(uuid, uuid, timestamptz, timestamptz, text, uuid, boolean) is
  'ABS1: the one release rule (absence, member removal, qualification change, move into an absence). Releases the '
  'member''s planned visits of the team in the period, never a visit written from a take (BK-e1b / CGR-250): its take '
  'decides (released before the start with its visit ended, kept after it). Returns the released visit ids.';
