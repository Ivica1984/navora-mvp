-- BK-e1b / CGR-248, UXR-241 (#1428; brief docs/agents/briefs/BK.md §PO amendment 2026-11-18 06:39 (2); `cra` 06:27
-- smaller remedy, answer to ADR-203 (10); ADR-203 (13)).
-- Before: `cancel_visit` (0054) ended any planned or on-the-way visit of the caller's team, also a visit written from
--   a take (0138). The take stayed live, so the order read «gedeckt» (or «nicht gedeckt» by the ADR-199 (5) net) with
--   no planned visit and was not offered again; nobody was signalled.
-- Now (IMPLEMENTED in this migration): a visit with `order_take_id` is refused with the stated result `take_visit`,
--   for every caller, before anything is written: visit, take, client cover and status notes stay unchanged. The
--   member's way out before «unterwegs» stays the release with a reason (CGR-242, `release_named_take`).
-- Unchanged: signature, grants, reason list, the CSR1 / CGR-34 responsible_absent rule and every visit not from a take.
-- The body is the 0054 body as rewritten by 0067 (ADR-081: private.now(), private.at_zurich). Idempotent (create or
-- replace); no data change.

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
  -- BK-e1b / CGR-248: a visit written from a take is never ended by a person command while the take stays live.
  if v.order_take_id is not null then return private.end_command('take_visit'); end if;
  if v.status not in ('planned', 'on_the_way') then return private.end_command('wrong_state'); end if;   -- before it starts
  -- CSR1 / CGR-34: the CGR-32 condition, read before the status changes; stored, never taken from the caller.
  absent := v.status = 'planned'
            and v.visit_date < private.at_zurich(private.now())::date  -- ADR-081 form (0067 rewrote 0054)
            and private.visit_responsible_absent(v.id);
  insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, note, actor_id, idempotency_key,
                                         responsible_absent)
  values (v.organization_id, v.id, 'cancelled', p_reason_code, why, uid, p_idempotency_key, absent);
  update public.care_visits set status = 'cancelled', suspended_at = null where id = v.id;
  return private.end_command('ok');
end;
$$;
revoke all on function public.cancel_visit(uuid, text, text, uuid) from public, anon;
grant execute on function public.cancel_visit(uuid, text, text, uuid) to authenticated;
comment on function public.cancel_visit(uuid, text, text, uuid) is
  'C1: cancel a planned or on-the-way visit with a reason (client_cancelled, client_in_hospital, team_cancelled, other '
  'with a note). CSR1 / CGR-34: a planned visit dated before today whose responsible member is recorded absent at its '
  'interval is cancelled with responsible_absent = true on its status note (server side). BK-e1b / CGR-248: a visit '
  'written from a take (order_take_id) is refused with take_visit; the way out is the release (CGR-242).';
