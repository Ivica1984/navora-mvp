-- HD-3s-F2 «Externer Auftrag mit zwei Blöcken (geteilter Dienst), feste Regeln» (brief docs/agents/briefs/HD-3s-F2.md, PO
-- contract 2026-11-26 22:39, integration section 23:39; founder FE-133 (1); `cra` CGR-288; ADR-229). Synthetic simulation
-- only; fixed, checkable rules, no AI.
--   * The order keeps ONE window (starts_at = start of block 1, ends_at = end of block 2) and carries its pause in two new
--     columns pause_starts_at / pause_ends_at (both NULL = one block, every existing row). Every existing availability
--     reading (absence, open visits, another live take, recheck_member_takes) therefore sees the pause as busy for the
--     person who takes the order (PO decision (a), CGR-288 (a) by construction), and the rest reference is the end of
--     block 2 (CGR-288 (b)). One order row, no automatic split (FE-133 (1)).
--   * A split gap is orderable (institution_prepare_gap_order, private.institution_gap_order_args no longer refuse
--     `split_shift_not_orderable`); institution_send_gap_order calls confirm_client_order unchanged and sets the pause in
--     the same transaction (private.order_set_pause: shape with private.institution_split_problem, the HD-3s codes; the
--     sentence with both blocks). The preview shows both blocks and the minutes without the pause. No public signature
--     changes: the app that Render serves while the `staging` job applies this migration keeps working.
--   * One take writes one visit per block (care_visits.take_block 1/2; NULL on every other visit and on every existing
--     take visit, read as 1); the unique index care_visits_one_per_take becomes care_visits_one_per_take_block.
-- RLS unchanged (no new table, no new policy). Column grants: take_block readable like order_take_id (0138); the two
-- order columns are read only through definer functions, as starts_at/ends_at. Audit: the three new columns are
-- audited keys, classified `code`. Every function is created whole from its canonical file (STAB-1, TESTS 6).
-- Idempotent (add column if not exists, drop constraint/index if exists, create index if not exists, create or replace).
-- Way back: re-create the previous canonical files of the changed functions from git, drop the new helper functions,
-- cancel and delete no row (block-2 visits exist only for split orders; delete them with their order in a test reset),
-- create care_visits_one_per_take again, drop care_visits_one_per_take_block, take_block, the order check and columns.

-- 1. The order carries its pause ------------------------------------------------------------------------------------------
alter table public.partner_requests
  add column if not exists pause_starts_at timestamptz,
  add column if not exists pause_ends_at   timestamptz;
comment on column public.partner_requests.pause_starts_at is
  'HD-3s-F2: end of block 1 of an order with two blocks (split shift); NULL = one block. The order window starts_at..'
  'ends_at stays the whole working day, so the pause is busy for the person who takes it (PO decision (a)).';
comment on column public.partner_requests.pause_ends_at is
  'HD-3s-F2: start of block 2 of an order with two blocks (split shift); NULL = one block.';
alter table public.partner_requests drop constraint if exists partner_requests_pause_shape;
alter table public.partner_requests add constraint partner_requests_pause_shape
  check ((pause_starts_at is null) = (pause_ends_at is null)
         and (pause_starts_at is null
              or (order_kind = 'shift' and starts_at < pause_starts_at and pause_starts_at < pause_ends_at
                  and pause_ends_at < ends_at)));

drop trigger if exists audit_partner_requests on public.partner_requests;
create trigger audit_partner_requests
  after insert or update on public.partner_requests
  for each row execute function private.write_audit_event('status', 'urgency', 'region', 'converted_case_id',
                                                          'urgency_source', 'referrer_requested_start',
                                                          'starts_at', 'ends_at', 'postcode', 'grade', 'confirmed_at',
                                                          'withdrawn_at', 'withdrawn_by',
                                                          'pause_starts_at', 'pause_ends_at');
insert into private.audit_value_classes (table_name, key, class) values
  ('partner_requests', 'pause_starts_at', 'code'),
  ('partner_requests', 'pause_ends_at', 'code'),
  ('care_visits', 'take_block', 'code')
on conflict do nothing;

-- 2. One visit per block of a take ----------------------------------------------------------------------------------------
alter table public.care_visits add column if not exists take_block smallint;
alter table public.care_visits drop constraint if exists care_visits_take_block_check;
alter table public.care_visits add constraint care_visits_take_block_check
  check (take_block is null or (take_block in (1, 2) and order_take_id is not null));
comment on column public.care_visits.take_block is
  'HD-3s-F2: block of a take visit of an order with two blocks (1 or 2); NULL = the one visit of a one-block take, or no '
  'take visit. Written only by private.write_take_visit.';
create unique index if not exists care_visits_one_per_take_block on public.care_visits (order_take_id, coalesce(take_block, 1))
  where order_take_id is not null;
drop index if exists public.care_visits_one_per_take;
grant select (take_block) on public.care_visits to authenticated;

drop trigger if exists audit_care_visits_insert on public.care_visits;
create trigger audit_care_visits_insert after insert on public.care_visits
  for each row execute function private.write_audit_event('status', 'team_id', 'case_id', 'visit_date', 'time_start',
                                                          'time_end', 'order_take_id', 'take_block');

-- 3. Functions, whole from supabase/schema/functions (STAB-1)
-- Whole-file re-creation from supabase/schema/functions (STAB-1); generated by scripts/fn-source.mjs.

-- private.order_work_minutes: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.order_work_minutes). No text patch.

-- private.order_work_minutes(p_starts timestamp with time zone, p_pause_starts timestamp with time zone, p_pause_ends timestamp with time zone, p_ends timestamp with time zone)
CREATE OR REPLACE FUNCTION private.order_work_minutes(p_starts timestamp with time zone, p_pause_starts timestamp with time zone, p_pause_ends timestamp with time zone, p_ends timestamp with time zone)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  -- HD-3s-F2 (PO decision (b)): the working minutes of an order; the pause is never counted. One block: the window.
  select case
    when p_starts is null or p_ends is null then null
    when p_pause_starts is null or p_pause_ends is null then (extract(epoch from (p_ends - p_starts)) / 60)::int
    else ((extract(epoch from (p_pause_starts - p_starts)) + extract(epoch from (p_ends - p_pause_ends))) / 60)::int
  end
$function$;

revoke all on function private.order_work_minutes(p_starts timestamp with time zone, p_pause_starts timestamp with time zone, p_pause_ends timestamp with time zone, p_ends timestamp with time zone) from public, anon, authenticated, service_role;

-- private.order_split_sentence: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.order_split_sentence). No text patch.

-- private.order_split_sentence(p_grade text, p_starts timestamp with time zone, p_pause_starts timestamp with time zone, p_pause_ends timestamp with time zone, p_ends timestamp with time zone, p_postcode text, p_place text)
CREATE OR REPLACE FUNCTION private.order_split_sentence(p_grade text, p_starts timestamp with time zone, p_pause_starts timestamp with time zone, p_pause_ends timestamp with time zone, p_ends timestamp with time zone, p_postcode text, p_place text)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  -- HD-3s-F2 (brief scope 3): the order sentence names BOTH blocks and the working minutes without the pause, in the
  -- form of client_order_check: «Schichtauftrag · HF · Do 03.12.2026 07:00 – 11:30 und 16:00 – 20:00 (8 Std. 30 Min.) ·
  -- 4102 Binningen». Never only one block.
  select 'Schichtauftrag · ' || private.order_grade_label(p_grade) || ' · ' || private.order_local_text(p_starts)
         || ' – ' || to_char(private.at_zurich(p_pause_starts), 'HH24:MI')
         || ' und ' || to_char(private.at_zurich(p_pause_ends), 'HH24:MI')
         || ' – ' || to_char(private.at_zurich(p_ends), 'HH24:MI')
         || ' ' || private.order_duration_text(private.order_work_minutes(p_starts, p_pause_starts, p_pause_ends, p_ends))
         || ' · ' || p_postcode || ' ' || p_place
$function$;

revoke all on function private.order_split_sentence(p_grade text, p_starts timestamp with time zone, p_pause_starts timestamp with time zone, p_pause_ends timestamp with time zone, p_ends timestamp with time zone, p_postcode text, p_place text) from public, anon, authenticated, service_role;

-- private.order_set_pause: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.order_set_pause). No text patch.

-- private.order_set_pause(p_order_id uuid, p_work_date date, p_block1_ends time without time zone, p_block2_starts time without time zone)
CREATE OR REPLACE FUNCTION private.order_set_pause(p_order_id uuid, p_work_date date, p_block1_ends time without time zone, p_block2_starts time without time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  o   public.partner_requests;
  ps  timestamptz;
  pe  timestamptz;
  problem text;
  s   text;
begin
  -- HD-3s-F2 (ADR-229 (2)): called only by institution_send_gap_order, in the transaction that inserted the order, so no
  -- other session sees the order without its pause. Fail closed: any problem raises and undoes the whole send.
  select * into o from public.partner_requests where id = p_order_id for update;
  if o.id is null or o.order_kind is distinct from 'shift' or o.pause_starts_at is not null then
    raise exception 'order_set_pause: not a new shift order' using errcode = 'P0001';
  end if;
  -- The same shape check and codes as the split shift type (HD-3s V1-V5); blocks never cross midnight (V3), so both
  -- inner times lie on the work date.
  problem := private.institution_split_problem(private.at_zurich(o.starts_at)::time, p_block1_ends, p_block2_starts,
                                               private.at_zurich(o.ends_at)::time);
  if problem is not null or private.at_zurich(o.starts_at)::date <> p_work_date then
    raise exception 'order_set_pause: %', coalesce(problem, 'work_date') using errcode = 'P0001';
  end if;
  ps := private.at_zurich(p_work_date + p_block1_ends);
  pe := private.at_zurich(p_work_date + p_block2_starts);
  s := private.order_split_sentence(o.grade, o.starts_at, ps, pe, o.ends_at, o.postcode, o.city);
  update public.partner_requests
    set pause_starts_at = ps, pause_ends_at = pe, request_title = s, need_summary = s
    where id = o.id;
end;
$function$;

revoke all on function private.order_set_pause(p_order_id uuid, p_work_date date, p_block1_ends time without time zone, p_block2_starts time without time zone) from public, anon, authenticated, service_role;

-- private.institution_gap_order_args: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.institution_gap_order_args). No text patch.

-- private.institution_gap_order_args(g institution_gap_orders, p_grade text)
CREATE OR REPLACE FUNCTION private.institution_gap_order_args(g institution_gap_orders, p_grade text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  t public.institution_shift_types;
  cell jsonb;
begin
  select * into t from public.institution_shift_types where id = g.shift_type_id;
  -- HD-3s-F2 (ADR-229): a split shift gives the whole window plus its two inner times (NULL for one block); the caller
  -- sends one order and sets its pause in the same transaction (private.order_set_pause).
  if g.grade_fixed is not null and p_grade is distinct from g.grade_fixed then
    return jsonb_build_object('problems', jsonb_build_array('grade_not_missing'));
  end if;
  cell := private.institution_plan_cell(g.institution_id, g.station_id, g.shift_type_id, g.work_date);
  -- The gap may have closed meanwhile (a person was assigned): then there is nothing to order.
  if cell is null or cell ->> 'status' <> 'gap' then
    return jsonb_build_object('problems', jsonb_build_array('not_a_gap'));
  end if;
  return jsonb_build_object('problems', '[]'::jsonb, 'start_date', g.work_date, 'start_time', t.starts_at,
                            'end_time', t.ends_at, 'block1_end_time', t.block1_ends_at,
                            'block2_start_time', t.block2_starts_at);
end $function$;

revoke all on function private.institution_gap_order_args(g institution_gap_orders, p_grade text) from public, anon, authenticated, service_role;

-- public.institution_prepare_gap_order: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_prepare_gap_order). No text patch.

-- public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date)
CREATE OR REPLACE FUNCTION public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  acct  uuid;
  cell  jsonb;
  t     public.institution_shift_types;
  fixed text;
  prev  record;
  new_id uuid;
  other uuid;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  select ca.id into acct from public.client_accounts ca where ca.institution_id = p_institution_id
    order by ca.created_at, ca.id limit 1;
  if acct is null then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('no_client_account'));
  end if;
  -- Double-order lock: one transaction per cell at a time (the partial unique index is the backstop). The same cell lock
  -- as institution_apply_draft, so a draft row and an order for the same cell are serialised (HD-3a review finding 1).
  perform private.institution_cell_lock(p_station_id, p_shift_type_id, p_work_date);
  select g.id into other from public.institution_gap_orders g
    where g.station_id = p_station_id and g.shift_type_id = p_shift_type_id and g.work_date = p_work_date
      and g.state in ('prepared', 'sent');
  if other is not null then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('already_ordered'), 'gap_order_id', other);
  end if;
  select * into t from public.institution_shift_types where id = p_shift_type_id and institution_id = p_institution_id;
  cell := private.institution_plan_cell(p_institution_id, p_station_id, p_shift_type_id, p_work_date);
  if cell is null or t.id is null then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_found'));
  end if;
  if cell ->> 'status' <> 'gap' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_a_gap'));
  end if;
  -- HD-3s-F2 (FE-133 (1), ADR-229): a split shift is orderable as ONE order with both blocks; the order window is block-1
  -- start .. block-2 end (the pause is busy for the person, PO decision (a)), the pause is carried by the order
  -- (private.order_set_pause in institution_send_gap_order). The prefill names both blocks; never only one.
  if private.at_zurich(p_work_date + t.starts_at) <= private.now() then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('starts_in_past'));
  end if;
  -- A missing grade fixes the grade of the order (a lower grade would leave the gap open; no grade order is invented).
  if (cell ->> 'grade_present')::int < (cell ->> 'required_grade_count')::int then
    fixed := cell ->> 'required_grade';
  end if;
  -- Prefill of the activities: the last order this home sent for the same station (shown as such; the home checks it).
  select p.activity_tags, p.required_tags into prev
    from public.institution_gap_orders g join public.partner_requests p on p.id = g.order_id
    where g.institution_id = p_institution_id and g.station_id = p_station_id and g.state = 'sent'
    order by g.sent_at desc, g.id limit 1;
  insert into public.institution_gap_orders (institution_id, station_id, shift_type_id, work_date, client_account_id,
                                             grade_fixed, prepared_by)
    values (p_institution_id, p_station_id, p_shift_type_id, p_work_date, acct, fixed, (select auth.uid()))
    returning id into new_id;
  perform private.institution_audit(p_institution_id, 'institution_prepare_gap_order', 'institution_gap_orders', new_id,
    jsonb_build_object('station_id', p_station_id, 'shift_type_id', p_shift_type_id, 'work_date', p_work_date,
                       'grade_fixed', fixed));
  return jsonb_build_object('result', 'ok', 'gap_order_id', new_id, 'prefill', jsonb_build_object(
    'start_date', p_work_date, 'start_time', to_char(t.starts_at, 'HH24:MI'), 'end_time', to_char(t.ends_at, 'HH24:MI'),
    'block1_end_time', to_char(t.block1_ends_at, 'HH24:MI'), 'block2_start_time', to_char(t.block2_starts_at, 'HH24:MI'),
    'work_minutes', private.institution_shift_minutes(p_work_date, t.starts_at, t.ends_at, t.block1_ends_at,
                                                      t.block2_starts_at),
    'grade', fixed, 'grade_fixed', fixed is not null,
    'postcode', (select i.order_postcode from public.institutions i where i.id = p_institution_id),
    'activity_tags', coalesce(to_jsonb(prev.activity_tags), '[]'::jsonb),
    'required_tags', coalesce(to_jsonb(prev.required_tags), '[]'::jsonb),
    'activities_from_last_order', prev.activity_tags is not null));
end $function$;

revoke all on function public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date) from public, anon, authenticated, service_role;
grant execute on function public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date) to authenticated;
grant execute on function public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date) to service_role;

-- public.institution_preview_gap_order: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_preview_gap_order). No text patch.

-- public.institution_preview_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric)
CREATE OR REPLACE FUNCTION public.institution_preview_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  g public.institution_gap_orders;
  a jsonb;
  pv jsonb;
  ps timestamptz;
  pe timestamptz;
begin
  select * into g from public.institution_gap_orders where id = p_gap_order_id;
  if g.id is null or not private.is_institution_member(g.institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if g.state <> 'prepared' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_prepared'), 'state', g.state);
  end if;
  a := private.institution_gap_order_args(g, p_grade);
  if jsonb_array_length(a -> 'problems') > 0 then
    return jsonb_build_object('result', 'invalid', 'problems', a -> 'problems');
  end if;
  if not private.is_client_member(g.client_account_id) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_client_member'));
  end if;
  pv := public.preview_client_order(g.client_account_id, (a ->> 'start_date')::date, (a ->> 'start_time')::time,
                                    (a ->> 'end_time')::time, p_postcode, p_grade, p_activity_tags, p_required_tags,
                                    p_radius_km);
  -- HD-3s-F2 (ADR-229 (2)): a split shift previews both blocks and the working minutes without the pause, the same
  -- sentence the sent order carries (private.order_split_sentence); never only the outer window.
  if a ->> 'block1_end_time' is not null and pv ->> 'sentence' is not null then
    ps := private.at_zurich((a ->> 'start_date')::date + (a ->> 'block1_end_time')::time);
    pe := private.at_zurich((a ->> 'start_date')::date + (a ->> 'block2_start_time')::time);
    pv := pv || jsonb_build_object(
      'pause_starts_at', ps, 'pause_ends_at', pe,
      'duration_minutes', private.order_work_minutes((pv ->> 'starts_at')::timestamptz, ps, pe,
                                                     (pv ->> 'ends_at')::timestamptz),
      'sentence', private.order_split_sentence(p_grade, (pv ->> 'starts_at')::timestamptz, ps, pe,
                                               (pv ->> 'ends_at')::timestamptz, pv ->> 'postcode', pv ->> 'place_name'));
  end if;
  return jsonb_build_object('result', 'ok', 'preview', pv);
end $function$;

revoke all on function public.institution_preview_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric) from public, anon, authenticated, service_role;
grant execute on function public.institution_preview_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric) to authenticated;
grant execute on function public.institution_preview_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric) to service_role;

-- public.institution_send_gap_order: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_send_gap_order). No text patch.

-- public.institution_send_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric, p_idempotency_key uuid)
CREATE OR REPLACE FUNCTION public.institution_send_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric, p_idempotency_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  g public.institution_gap_orders;
  a jsonb;
  r jsonb;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  -- The row lock serialises two sends (or a send and a discard) of the same draft.
  select * into g from public.institution_gap_orders where id = p_gap_order_id for update;
  if g.id is null or not private.is_institution_member(g.institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if g.state = 'sent' then
    return jsonb_build_object('result', 'already_sent', 'order_id', g.order_id);
  end if;
  if g.state <> 'prepared' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_prepared'), 'state', g.state);
  end if;
  a := private.institution_gap_order_args(g, p_grade);
  if jsonb_array_length(a -> 'problems') > 0 then
    return jsonb_build_object('result', 'invalid', 'problems', a -> 'problems');
  end if;
  r := public.confirm_client_order(g.client_account_id, (a ->> 'start_date')::date, (a ->> 'start_time')::time,
                                   (a ->> 'end_time')::time, p_postcode, p_grade, p_activity_tags, p_required_tags,
                                   p_radius_km, p_idempotency_key);
  if r ->> 'result' = 'rejected' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_client_member'));
  end if;
  if r ->> 'result' <> 'ok' then
    return r;  -- invalid (with the problems of client_order_check) or duplicate: nothing changed here
  end if;
  -- HD-3s-F2 (ADR-229 (2)): a split shift is one order with both blocks; its pause is set in this transaction, before any
  -- other session can see the order. A shape problem undoes the whole send (raise), never an order without its pause.
  if a ->> 'block1_end_time' is not null then
    perform private.order_set_pause((r ->> 'order_id')::uuid, (a ->> 'start_date')::date,
                                    (a ->> 'block1_end_time')::time, (a ->> 'block2_start_time')::time);
  end if;
  update public.institution_gap_orders
    set state = 'sent', order_id = (r ->> 'order_id')::uuid, sent_by = (select auth.uid()), sent_at = private.now()
    where id = g.id;
  -- The home's postcode is the home's data: kept from its first sent order, never overwritten here.
  update public.institutions set order_postcode = btrim(p_postcode)
    where id = g.institution_id and order_postcode is null;
  perform private.institution_audit(g.institution_id, 'institution_send_gap_order', 'institution_gap_orders', g.id,
    jsonb_build_object('order_id', r ->> 'order_id', 'grade', p_grade, 'postcode', btrim(p_postcode)));
  return jsonb_build_object('result', 'ok', 'gap_order_id', g.id, 'order_id', r ->> 'order_id');
end $function$;

revoke all on function public.institution_send_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric, p_idempotency_key uuid) from public, anon, authenticated, service_role;
grant execute on function public.institution_send_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric, p_idempotency_key uuid) to authenticated;
grant execute on function public.institution_send_gap_order(p_gap_order_id uuid, p_postcode text, p_grade text, p_activity_tags text[], p_required_tags text[], p_radius_km numeric, p_idempotency_key uuid) to service_role;

-- private.write_take_visit: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.write_take_visit). No text patch.

-- private.write_take_visit(p_take_id uuid)
CREATE OR REPLACE FUNCTION private.write_take_visit(p_take_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  k   public.order_takes;
  o   public.partner_requests;
  vid uuid;
  first_vid uuid;
  b   record;
begin
  select * into k from public.order_takes where id = p_take_id;
  if k.id is null or k.released_at is not null or k.acknowledged_at is null then return null; end if;
  select * into o from public.partner_requests where id = k.order_id;
  if o.id is null or o.starts_at is null or o.ends_at is null or o.starts_at <= private.now() then return null; end if;
  -- CGR-233: the same person key as take_order, before any write that names her (re-entrant in the take's session).
  perform pg_advisory_xact_lock(hashtextextended('order_take_member:' || k.member_id::text, 0));
  -- HD-3s-F2 (ADR-229 (3), PO decision (b)): one visit per block. One block (no pause): one visit, take_block NULL, as
  -- before. Two blocks: block 1 = starts_at .. pause_starts_at, block 2 = pause_ends_at .. ends_at, the same member,
  -- team and activities; the pause is in no visit (planned minutes never cover it). Idempotent per block.
  for b in
    select 1 as no, o.starts_at as s, coalesce(o.pause_starts_at, o.ends_at) as e,
           case when o.pause_starts_at is null then null::smallint else 1::smallint end as blk
    union all
    select 2, o.pause_ends_at, o.ends_at, 2::smallint where o.pause_starts_at is not null
    order by 1
  loop
    vid := null;
    select v.id into vid from public.care_visits v
      where v.order_take_id = k.id and coalesce(v.take_block, 1) = b.no;
    if vid is null then
      insert into public.care_visits (organization_id, team_id, case_id, visit_date, time_start, time_end, status,
                                      responsible_user_id, order_take_id, take_block, services_provided)
        values (k.organization_id, k.team_id, null,
                private.at_zurich(b.s)::date,
                private.at_zurich(b.s)::time,
                private.at_zurich(b.e)::time,
                'planned', k.member_id, k.id, b.blk, o.activity_tags)   -- BK-7: the order's tags, no retyping
        returning id into vid;
      -- The order's activities, in the matrix catalogue only (QUAL1-6); the QUAL1 recheck on insert stays in force.
      insert into public.visit_activities (organization_id, visit_id, activity_code)
        select k.organization_id, vid, a.code
        from public.qual_activities a
        where a.code = any (coalesce(o.activity_tags, '{}'))
      on conflict do nothing;
    end if;
    if b.no = 1 then first_vid := vid; end if;
  end loop;
  return first_vid;  -- block 1 (or the one visit)
end;
$function$;

revoke all on function private.write_take_visit(p_take_id uuid) from public, anon, authenticated, service_role;
