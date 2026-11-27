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
--   * Per visit instead of per take where a reading means «the visit» (ADR-229 (4), (5)): the invoice draft (ordered
--     minutes of the visit's own block; «already_drafted», the live index, the correction void and the newest refusal
--     per visit) and the `take_member_dropped` exception (block 2 keyed `…:2`, flagged only after its own start). A
--     one-block take has exactly one visit, so every existing result is unchanged. The order lists of the home and the
--     team (client_orders, team_order_offers) count the minutes without the pause (same signatures).
-- RLS unchanged (no new table, no new policy). Grants: take_block gets the column select of order_take_id (0138); the
-- two order columns fall under the existing table select and RLS of partner_requests, exactly like starts_at/ends_at
-- (no write grant to anon or authenticated). Audit: the three new columns are audited keys, classified `code`. Every function is created whole from its canonical file (STAB-1, TESTS 6).
-- Idempotent (add column if not exists, drop constraint/index if exists, create index if not exists, create or replace).
-- Way back: re-create the previous canonical files of the changed functions from git, drop the new helper functions,
-- cancel and delete no row (block-2 visits exist only for split orders; delete them with their order in a test reset),
-- create care_visits_one_per_take and team_invoice_drafts_one_live again (only after a two-block take has no second
-- visit or live draft), drop the two new indexes, take_block, the order check and the two order columns.

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

-- 3. Invoice draft per visit (brief scope 6; ADR-229 (4)): one live draft per visit instead of per take. A one-block
--    take has exactly one visit, so every existing row and result is the same; a two-block take gets one draft per block.
create unique index if not exists team_invoice_drafts_one_live_visit on public.team_invoice_drafts (visit_id)
  where state in ('draft', 'sent');
drop index if exists public.team_invoice_drafts_one_live;

-- 4. Functions, whole from supabase/schema/functions (STAB-1)
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

-- private.take_invoice_build: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.take_invoice_build). No text patch.

-- private.take_invoice_build(p_report_id uuid, p_actor uuid)
CREATE OR REPLACE FUNCTION private.take_invoice_build(p_report_id uuid, p_actor uuid)
 RETURNS team_invoice_drafts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'UTC'
AS $function$
declare
  r    public.visit_reports;
  v    public.care_visits;
  k    public.order_takes;
  o    public.partner_requests;
  pr   public.order_take_prices;
  tol  public.invoice_time_tolerances;
  t    record;
  row_ public.team_invoice_drafts;
  reason text;
  ordered numeric;
  recorded numeric;
begin
  select * into r from public.visit_reports where id = p_report_id;
  if r.id is null then return null; end if;
  select * into v from public.care_visits where id = r.visit_id;
  if v.order_take_id is null then return null; end if;   -- not a take visit: the BK path does not apply
  select * into k from public.order_takes where id = v.order_take_id;
  select * into o from public.partner_requests where id = k.order_id;
  -- one build per take at a time (trigger and command)
  perform pg_advisory_xact_lock(hashtextextended('take_invoice:' || k.id::text, 0));

  -- HD-3s-F2 (ADR-229 (4), brief scope 6): the ordered minutes of THIS visit: its block of a two-block order (block 1
  -- starts_at .. pause_starts_at, block 2 pause_ends_at .. ends_at), else the whole window as before. Never the pause.
  ordered := round((extract(epoch from (
               case when v.take_block = 2 then o.ends_at else coalesce(o.pause_starts_at, o.ends_at) end
             - case when v.take_block = 2 then o.pause_ends_at else o.starts_at end)) / 60)::numeric, 2);
  if r.status = 'final' then
    select * into t from private.snapshot_times(r.snapshot);
    recorded := t.care_minutes_exact;
  end if;
  select * into pr from public.order_take_prices where take_id = k.id;
  select * into tol from public.invoice_time_tolerances where key = 'take_invoice';

  if r.status <> 'final' then
    reason := 'not_signed';
  elsif exists (select 1 from public.visit_reports s
                where s.supersedes_id = r.id and s.status = 'final') then
    reason := 'superseded';
  -- HD-3s-F2: one live draft per visit (a one-block take has one visit, so per take as before).
  elsif exists (select 1 from public.team_invoice_drafts d where d.visit_id = v.id and d.state in ('draft', 'sent')) then
    reason := 'already_drafted';
  elsif exists (select 1 from public.quality_holds h where h.visit_id = v.id and h.lifted_at is null) then
    reason := 'on_hold';
  elsif tol.key is null then
    reason := 'no_tolerance';
  elsif pr.price_per_hour is null then
    reason := 'no_price';
  elsif recorded is null or ordered is null then
    reason := 'no_times';
  elsif abs(recorded - ordered) > tol.tolerance_minutes then
    reason := 'times_disagree';
  end if;

  insert into public.team_invoice_drafts
    (organization_id, team_id, client_account_id, order_id, take_id, visit_id, report_id, report_version,
     report_snapshot_hash, state, refusal_reason, ordered_minutes, recorded_minutes, tolerance_minutes,
     price_per_hour, amount_chf, created_by)
  values
    (k.organization_id, k.team_id, o.client_account_id, o.id, k.id, v.id, r.id, r.version,
     private.report_snapshot_hash(r.snapshot),
     case when reason is null then 'draft' else 'refused' end, reason, ordered, recorded, tol.tolerance_minutes,
     pr.price_per_hour,
     case when reason is null then round(recorded * pr.price_per_hour / 60, 2) end,
     p_actor)
  returning * into row_;
  return row_;
end;
$function$;

revoke all on function private.take_invoice_build(p_report_id uuid, p_actor uuid) from public, anon, authenticated, service_role;
comment on function private.take_invoice_build(p_report_id uuid, p_actor uuid) is 'BK-f / BK-9, BK-9n: one draft or one visible refusal for a take report version (not_signed, superseded, already_drafted, on_hold, no_tolerance, no_price, no_times, times_disagree). Minutes from the signed snapshot (snapshot_times, CGR-03), price from the take snapshot (0155), amount = minutes × price / 60, 2 decimals (multiply first, BKF-F2).';

-- private.take_report_final_invoice: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.take_report_final_invoice). No text patch.

-- private.take_report_final_invoice()
CREATE OR REPLACE FUNCTION private.take_report_final_invoice()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  take uuid;
  actor uuid := coalesce((select auth.uid()), new.signed_by);
begin
  if new.status <> 'final' or (tg_op = 'UPDATE' and old.status = 'final') then return null; end if;
  select v.order_take_id into take from public.care_visits v where v.id = new.visit_id;
  if take is null then return null; end if;
  -- CGR-210 (b): a correction voids the live draft or sent invoice of this visit (HD-3s-F2: per visit; a one-block take
  -- has one visit), in this transaction.
  if new.supersedes_id is not null then
    begin
      update public.team_invoice_drafts
        set state = 'void', void_reason = 'report_corrected', voided_at = private.now()
        where visit_id = new.visit_id and state in ('draft', 'sent') and report_id <> new.id;
    exception when others then
      null;  -- the next build then shows already_drafted; the signature stays
    end;
  end if;
  begin
    perform private.take_invoice_build(new.id, actor);
  exception when others then
    perform private.take_invoice_build_failed(new.id, actor);
  end;
  return null;
end $function$;

revoke all on function private.take_report_final_invoice() from public, anon, authenticated, service_role;

-- public.my_team_invoice_drafts: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.my_team_invoice_drafts). No text patch.

-- public.my_team_invoice_drafts()
CREATE OR REPLACE FUNCTION public.my_team_invoice_drafts()
 RETURNS TABLE(id uuid, team_id uuid, team_name text, client_name text, visit_date date, state text, refusal_reason text, ordered_minutes numeric, recorded_minutes numeric, price_per_hour numeric, amount_chf numeric, currency text, report_id uuid, report_version integer, created_at timestamp with time zone, sent_at timestamp with time zone, voided_at timestamp with time zone, void_reason text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select d.id, d.team_id, t.name, ca.display_name, v.visit_date, d.state, d.refusal_reason,
         d.ordered_minutes, d.recorded_minutes, d.price_per_hour, d.amount_chf, d.currency, d.report_id, d.report_version,
         d.created_at, d.sent_at, d.voided_at, d.void_reason
  from public.team_invoice_drafts d
  join public.teams t on t.id = d.team_id
  join public.care_visits v on v.id = d.visit_id
  left join public.client_accounts ca on ca.id = d.client_account_id
  where private.take_team_member(d.team_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
    and (d.state in ('draft', 'sent')
         or (d.state = 'void' and d.sent_at is not null)
         or (d.state = 'refused'
             -- HD-3s-F2: the newest refusal per visit (a one-block take has one visit, so per take as before)
             and not exists (select 1 from public.team_invoice_drafts l
                             where l.visit_id = d.visit_id and l.state in ('draft', 'sent'))
             and d.seq = (select max(n.seq) from public.team_invoice_drafts n where n.visit_id = d.visit_id)))
  order by v.visit_date desc, d.seq desc
$function$;

revoke all on function public.my_team_invoice_drafts() from public, anon, authenticated, service_role;
grant execute on function public.my_team_invoice_drafts() to authenticated;
grant execute on function public.my_team_invoice_drafts() to service_role;
comment on function public.my_team_invoice_drafts() is 'BK-f /team «Rechnungsentwürfe»: drafts, sent invoices, invoices voided after sending and the newest refusal per take of the caller''s own teams. A former member (LEAVE1-3) reads nothing.';

-- private.derived_exceptions_of: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.derived_exceptions_of). No text patch.

-- private.derived_exceptions_of(p_org uuid, p_types text[])
CREATE OR REPLACE FUNCTION private.derived_exceptions_of(p_org uuid, p_types text[])
 RETURNS TABLE(exception_key text, exception_type text, since timestamp with time zone, case_id uuid, team_id uuid, entity_type text, entity_id uuid, detail text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with rules as (select * from private.effective_exception_rules(p_org))
  -- J1: case not ready for matching after the threshold (working time from the referral)
  select 'case_not_ready:' || c.id, 'case_not_ready', p.created_at, c.id, null::uuid, 'case', c.id,
         (select string_agg(m.value ->> 'reason', '; ' order by m.ord) /* UXR-181 */ from jsonb_array_elements(private.case_readiness(c.id)) with ordinality m(value, ord))
  from public.cases c
  join public.partner_requests p on p.id = c.source_partner_request_id, rules r
  where r.exception_type = 'case_not_ready' and c.organization_id = p_org and c.ready_for_matching_at is null
    and private.now() >= private.after_threshold(p.created_at, r.amount, r.unit)
    and (p_types is null or 'case_not_ready' = any(p_types))  -- PERF1 gate
  union all
  -- SAFE-D11 R2 (ADR-184): a reopened case without a team and without an open team search (closes with its cause)
  select 'case_reopened_no_team:' || c.id || ':' || extract(epoch from c.reopened_at)::bigint, 'case_reopened_no_team',
         c.reopened_at, c.id, null::uuid, 'case', c.id,
         (select string_agg(m.value ->> 'reason', '; ' order by m.ord) /* UXR-181 */ from jsonb_array_elements(private.case_readiness(c.id)) with ordinality m(value, ord))
  from public.cases c
  join rules r on r.exception_type = 'case_reopened_no_team'
  where c.organization_id = p_org and c.lifecycle = 'active' and c.assigned_team_id is null
    and c.reopened_at is not null and c.ready_for_matching_at is not null
    and not exists (select 1 from public.matching_requests m where m.case_id = c.id and m.status = 'open')
    and (p_types is null or 'case_reopened_no_team' = any(p_types))  -- PERF1 gate
  union all
  -- SAFE-D11 R4: a reopened case whose team is no longer active (closes with its cause; never reassigns)
  select 'case_reopened_team_inactive:' || c.id || ':' || extract(epoch from c.reopened_at)::bigint, 'case_reopened_team_inactive',
         c.reopened_at, c.id, c.assigned_team_id, 'case', c.id, null::text
  from public.cases c
  join public.teams t on t.id = c.assigned_team_id
  join rules r on r.exception_type = 'case_reopened_team_inactive'
  where c.organization_id = p_org and c.lifecycle <> 'closed' and c.reopened_at is not null
    and t.status is distinct from 'active'
    and (p_types is null or 'case_reopened_team_inactive' = any(p_types))  -- PERF1 gate
  union all
  -- BK-C1 (ADR-199 (9)): a confirmed shift order that is not covered (closes with its cause)
  select 'order_not_covered:' || p.id, 'order_not_covered', c.latest_cover_at, null::uuid, null::uuid,
         'order', p.id, c.cover_detail
  from public.partner_requests p
  cross join lateral private.order_cover(p.id, private.now()) c
  join rules r on r.exception_type = 'order_not_covered'
  where p.organization_id = p_org and p.order_kind is not null and p.confirmed_at is not null
    and (p_types is null or 'order_not_covered' = any(p_types))  -- PERF1 gate: no order_cover call for a caller that does not read this type
    and c.cover_state = 'not_covered'
  union all
  -- BK-E1B-S (CGR-246, ADR-203 (12)): a live take whose named member no longer passes while its visit is under way
  -- or still planned after the start; P1 to her own team and to her (SIG1), closes with its cause; code detail only
  -- HD-3s-F2 (ADR-229 (5)): one row per take visit. A two-block take has two visits: block 2 keys `…:2` and reads its own
  -- start (pause_ends_at), so block 2 is not flagged while block 1 runs; block 1 and a one-block take keep the key.
  select 'take_member_dropped:' || k.id || case when v.take_block = 2 then ':2' else '' end, 'take_member_dropped',
         case when v.status = 'planned' then bs.at else coalesce(last.at, bs.at) end,
         v.case_id, k.team_id, 'visit', v.id, 'step_' || st.step
  from public.order_takes k
  join public.partner_requests o on o.id = k.order_id
  join public.care_visits v on v.order_take_id = k.id
  cross join lateral (select case when v.take_block = 2 then o.pause_ends_at else o.starts_at end as at) bs
  cross join lateral (select private.order_member_step(o.id, k.team_id, k.member_id) as step) st
  left join lateral (select max(e.occurred_at) as at from public.visit_events e where e.visit_id = v.id) last on true
  join rules r on r.exception_type = 'take_member_dropped'
  where k.organization_id = p_org and k.released_at is null and st.step < 4
    and (v.status in ('on_the_way', 'started', 'paused')
         or (v.status = 'planned' and private.now() >= bs.at))
    and (p_types is null or 'take_member_dropped' = any(p_types))  -- PERF1 gate
  union all
  -- J2: team search escalations (deadline passed, candidates exhausted, no deadline)
  select case e.reason when 'deadline_passed' then 'offer_overdue:' when 'deadline_not_configured' then 'deadline_missing:'
                       else 'candidates_exhausted:' end || e.matching_request_id,
         case e.reason when 'deadline_passed' then 'offer_overdue' when 'deadline_not_configured' then 'deadline_missing'
                       else 'candidates_exhausted' end,
         coalesce(e.response_due_at, e.created_at), m.case_id, null::uuid, 'matching_request', e.matching_request_id,
         e.request_title || coalesce(' · Absagen: ' || (select string_agg(coalesce(d ->> 'team', 'Team') || ' (' || coalesce(d ->> 'code', '?') || ')', ', ')
                                                        from jsonb_array_elements(e.declines) d), '')
  from private.matching_escalations_for(p_org) e
  join public.matching_requests m on m.id = e.matching_request_id
  where (p_types is null or p_types && array['offer_overdue', 'deadline_missing', 'candidates_exhausted'])  -- PERF1 gate
  union all
  -- J3: uncovered visits in the next 24 h (P1 when the case came as a hospital discharge)
  select case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital:' else 'visit_uncovered:' end || v.id,
         case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end,
         private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
  from public.care_visits v
  left join lateral (select x.referral_type from public.matching_requests x where x.case_id = v.case_id order by x.created_at desc limit 1) mr on true
  join rules r on r.exception_type = case when mr.referral_type = 'hospital_discharge' then 'visit_uncovered_hospital' else 'visit_uncovered' end
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.suspended_at is null and v.covered_by is null
    and (p_types is null or p_types && array['visit_uncovered', 'visit_uncovered_hospital'])  -- PERF1 gate
    and (private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
          <= private.after_threshold(private.now(), r.amount, r.unit)
         -- SIG2-6: a window that opens outside the watched hours opens at the end of the last watched period before
         or (r.exception_type = 'visit_uncovered_hospital'
             and private.lookahead_raised(p_org, private.now(), /* SIG2-14 (ADR-078) */
                   private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
                   - (private.after_threshold(private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), r.amount, r.unit)
                      - private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))))))
  union all
  -- COVER1: covered by another team but not yet performable (no access before D-3); since = start − 24 h,
  -- so the rule's escalation (20 h) makes it P1 from 4 h before the start
  select 'cover_without_access:' || v.id, 'cover_without_access',
         private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))) - interval '24 hours', v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
           || ' · übernommen von ' || coalesce((select t.name from public.teams t where t.id = v.cover_team_id), 'einem anderen Team')
  from public.care_visits v
  join rules r on r.exception_type = 'cover_without_access'
  where v.organization_id = p_org and v.status = 'planned' and v.responsible_user_id is null and v.suspended_at is null
    and v.covered_by is not null
    and (p_types is null or 'cover_without_access' = any(p_types))  -- PERF1 gate
    and private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
        between private.now() and private.after_threshold(private.now(), r.amount, r.unit)
  union all
  -- J3: medical order expiring within the threshold or expired, on a running case
  select 'order_expiring:' || c.id || ':' || c.medical_order_valid_until, 'order_expiring',
         (c.medical_order_valid_until - make_interval(days => coalesce(r.amount, 0)))::timestamptz, c.id, c.assigned_team_id, 'case', c.id,
         'gültig bis ' || to_char(c.medical_order_valid_until, 'DD.MM.YYYY')
  from public.cases c, rules r
  where r.exception_type = 'order_expiring' and c.organization_id = p_org
    and c.assigned_team_id is not null and c.medical_order_status = 'present' and c.medical_order_valid_until is not null
    and c.medical_order_valid_until <= (private.at_zurich(private.now()))::date + coalesce(r.amount, 0)
    and (p_types is null or 'order_expiring' = any(p_types))  -- PERF1 gate
  union all
  -- J3: care-plan review overdue
  select 'care_plan_review_overdue:' || i.case_id || ':' || min(i.review_date), 'care_plan_review_overdue',
         min(i.review_date)::timestamptz, i.case_id, min(i.team_id::text)::uuid, 'case', i.case_id,
         'Überprüfung fällig seit ' || to_char(min(i.review_date), 'DD.MM.YYYY')
  from public.care_plan_items i
  join public.cases c on c.id = i.case_id
  where c.organization_id = p_org and i.active
    and (p_types is null or 'care_plan_review_overdue' = any(p_types))  -- PERF1 gate
  group by i.case_id
  having min(i.review_date) < (private.at_zurich(private.now()))::date
  union all
  -- QG1/legacy: serious quality event open (high, critical); priority escalates after the threshold
  select 'quality_serious_open:' || q.id, 'quality_serious_open', q.created_at, q.case_id, q.team_id, 'quality_event', q.id,
         q.title || case when q.status = 'in_review' then ' · in Bearbeitung' else '' end
  from public.quality_events q
  where q.organization_id = p_org and q.status in ('open', 'in_review') and q.severity in ('high', 'critical')
    and (p_types is null or 'quality_serious_open' = any(p_types))  -- PERF1 gate
  union all
  -- F6: report not final 24 h after the visit ended
  select 'report_not_final:' || v.id, 'report_not_final', ended.at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.')
  from public.care_visits v
  join lateral (select max(e.occurred_at) as at from public.visit_events e where e.visit_id = v.id and e.event_type = 'completed') ended on true
  , rules r
  where r.exception_type = 'report_not_final' and v.organization_id = p_org and v.status = 'completed'
    and ended.at is not null
    and private.now() >= private.after_threshold(ended.at, r.amount, r.unit)
    and not exists (select 1 from public.visit_reports vr where vr.visit_id = v.id and vr.status = 'final')
    and (p_types is null or 'report_not_final' = any(p_types))  -- PERF1 gate

  union all
  -- C1: client not reached (no-show) — P1 until the team records the outcome
  select 'no_show_open:' || v.id, 'no_show_open', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         private.no_show_ops_detail(v.id)  -- DOOR1-11: codes only, no note text
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'no_show'
  where v.organization_id = p_org and v.status = 'no_show'
    and not exists (select 1 from public.visit_status_notes o where o.visit_id = v.id and o.kind = 'no_show_outcome')
    and (p_types is null or 'no_show_open' = any(p_types))  -- PERF1 gate
  union all
  -- C1: visit cancelled by the team shortly before it was due (continuity)
  select 'team_cancellation_late:' || v.id, 'team_cancellation_late', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'cancelled' and s.reason_code = 'team_cancelled', rules r
  where r.exception_type = 'team_cancellation_late' and v.organization_id = p_org and v.status = 'cancelled'
    -- open until closed in OPS1, or until the team planned a replacement for the case on that day
    and not exists (select 1 from public.care_visits x where x.case_id = v.case_id and x.visit_date = v.visit_date
                      and x.status <> 'cancelled' and x.created_at > s.created_at)
    and private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00')))
        < private.after_threshold(s.created_at, r.amount, r.unit)
    and (p_types is null or 'team_cancellation_late' = any(p_types))  -- PERF1 gate
  union all
  -- CSR1 / CGR-04: planned visit not started after its planned start (whoever is responsible)
  select 'visit_overdue:' || v.id, 'visit_overdue',
         private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '') || ' · '
           || case
                when v.responsible_user_id is null and v.covered_by is not null then 'von einem anderen Team übernommen'
                when v.responsible_user_id is null then 'niemand zuständig'
                when not exists (select 1 from public.team_memberships tm
                                 where tm.team_id = v.team_id and tm.user_id = v.responsible_user_id)
                  then 'zuständige Person nicht mehr im Team'
                else 'zuständig: ' || coalesce(private.member_name(v.organization_id, v.responsible_user_id), 'Teammitglied')
              end
  from public.care_visits v
  join rules r on r.exception_type = 'visit_overdue'
  where v.organization_id = p_org and v.status = 'planned' and v.suspended_at is null
    and private.now() >= private.after_threshold(private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))), r.amount, r.unit)
    and (p_types is null or 'visit_overdue' = any(p_types))  -- PERF1 gate
  union all
  -- CSR1 / CGR-04: visit left on the way, started or paused (from the last status change; started: not before the planned end)
  select 'visit_stuck:' || v.id || ':' || coalesce(last.id::text, '0'), 'visit_stuck', st.ref, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '') || ' · '
           || case v.status when 'on_the_way' then 'unterwegs' when 'started' then 'begonnen' else 'pausiert' end
           || ' seit ' || to_char(private.at_zurich(coalesce(last.at, st.ref)), 'DD.MM. HH24:MI')
  from public.care_visits v
  left join lateral (select e.id, e.occurred_at as at from public.visit_events e
                     where e.visit_id = v.id order by e.occurred_at desc, e.id desc limit 1) last on true
  cross join lateral (select case
           when v.status = 'started' and coalesce(v.time_end, v.time_start) is not null
             then greatest(coalesce(last.at, '-infinity'::timestamptz),
                           private.at_zurich((v.visit_date + coalesce(v.time_end, v.time_start)
                              + case when v.time_end < v.time_start then interval '1 day' else interval '0' end)))
           else coalesce(last.at, private.at_zurich((v.visit_date + coalesce(v.time_start, time '00:00'))))
         end as ref) st
  join rules r on r.exception_type = 'visit_stuck'
  where v.organization_id = p_org and v.status in ('on_the_way', 'started', 'paused')
    and private.now() >= private.after_threshold(st.ref, r.amount, r.unit)
    and (p_types is null or 'visit_stuck' = any(p_types))  -- PERF1 gate
  union all
  -- CSR1 / CGR-25 (PROVISIONAL, D-31): a visit ended as not completed, until a person records the follow-up decision
  select 'visit_interrupted:' || v.id, 'visit_interrupted', s.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '') || ' · '
           || case s.reason_code
                when 'client_transferred' then 'Klient:in verlegt bzw. ins Spital gebracht'
                when 'client_declined' then 'Klient:in lehnt die Fortsetzung ab'
                when 'nurse_unavailable' then 'Pflegeperson abberufen oder unwohl'
                when 'started_by_mistake' then 'Irrtümlich gestartet'
                else 'Anderer Grund'
              end
           || case when s.note is not null then ' · Notiz im Team' else '' end  -- DOOR1-11
           || case when s.reason_code = 'client_transferred' then
                coalesce(' · nächster geplanter Einsatz: ' || (
                  select to_char(n.visit_date, 'DD.MM.') || coalesce(' ' || to_char(n.time_start, 'HH24:MI'), '')
                  from public.care_visits n
                  where n.case_id = v.case_id and n.organization_id = v.organization_id and n.id <> v.id
                    and n.status = 'planned'
                    and private.at_zurich((n.visit_date + coalesce(n.time_start, time '23:59'))) >= s.created_at
                  order by n.visit_date, n.time_start nulls last, n.id
                  limit 1), ' · kein weiterer Einsatz geplant')
              else '' end
  from public.care_visits v
  join public.visit_status_notes s on s.visit_id = v.id and s.kind = 'interrupted'
  join rules r on r.exception_type = 'visit_interrupted'
  where v.organization_id = p_org and v.status = 'interrupted'
    and not exists (select 1 from public.visit_status_notes f where f.visit_id = v.id and f.kind = 'interruption_followup')
    and (p_types is null or 'visit_interrupted' = any(p_types))  -- PERF1 gate
  union all
  -- CSR1 / CGR-24 (PROVISIONAL, D-28): a report correction that is not final after the report_not_final threshold
  select 'report_correction_open:' || c.id, 'report_correction_open', c.created_at, v.case_id, v.team_id, 'visit', v.id,
         to_char(v.visit_date, 'DD.MM.') || coalesce(' ' || to_char(v.time_start, 'HH24:MI'), '')
           || ' · Korrektur Version ' || c.version
           || case when c.status = 'signed' then ' · unterschrieben, Gegenzeichnung offen' else ' · nicht unterschrieben' end
  from public.visit_reports c
  join public.care_visits v on v.id = c.visit_id and v.organization_id = c.organization_id
  join rules t on t.exception_type = 'report_not_final'
  join rules r on r.exception_type = 'report_correction_open'
  where c.organization_id = p_org and c.supersedes_id is not null and c.status in ('draft', 'signed')
    and c.return_id is null  -- F6R: a return version is no correction; report_not_final still raises
    and private.now() >= private.after_threshold(c.created_at, t.amount, t.unit)
    and (p_types is null or 'report_correction_open' = any(p_types))  -- PERF1 gate
  union all
  -- ORD0-4 (CGR-38): B care on an order present without an end date; a prompt, never a block (closes with its cause)
  select 'order_without_end_date:' || c.id || coalesce(':' || e.id, ''), 'order_without_end_date',
         coalesce(e.started_at, private.now()), c.id, c.assigned_team_id, 'case', c.id,
         'Verordnung vorhanden, ohne Enddatum · B-Leistung aktiv'
  from public.cases c
  join rules r on r.exception_type = 'order_without_end_date'
  left join private.order_open_end_episodes e on e.case_id = c.id and e.ended_at is null
  where c.organization_id = p_org and private.order_without_end_date_holds(c.id)
    and (p_types is null or 'order_without_end_date' = any(p_types))  -- PERF1 gate
  union all
  -- ADM2-15 (b) (CGR-72): an open case still names a primary or deputy nurse whose access ended (closes with its cause)
  select 'successor_needed:' || s.case_id || ':' || s.role || ':' || s.user_id, 'successor_needed',
         coalesce(private.adm2_contract_ended_at(s.user_id), private.now()), s.case_id, s.team_id, 'case', s.case_id,
         case s.role when 'primary' then 'Bezugspflege' else 'Stellvertretung' end || ' · Zugang beendet'
  from private.successor_needed(p_org) s
  join rules r on r.exception_type = 'successor_needed'
  where (p_types is null or 'successor_needed' = any(p_types))  -- PERF1 gate
  union all
  -- AIG1-8: an agent stopped by its threshold or a version change (AIG1-C5: listed per stop while it has an open line)
  select 'agent_stopped:' || st.id, 'agent_stopped', st.created_at, null::uuid, null::uuid, 'ai_agent_stop', st.id,
         d.name || ' · ' || 'Werte: ' || (select count(*) from private.aig1_lookback(st.id) l where not l.superseded
           and private.aig1_record_open(l.entity_type, l.entity_id)) || ' offen · '
         || (select count(*) from private.aig1_lookback(st.id) l where not l.superseded
           and not private.aig1_record_open(l.entity_type, l.entity_id)) || ' nicht mehr offen' /* AIG1-C1 */
  from public.ai_agent_stops st
  join public.ai_agent_definitions d on d.key = st.agent_key
  join rules r on r.exception_type = 'agent_stopped'
  where st.organization_id = p_org
    and exists (select 1 from private.aig1_lookback(st.id) l where not l.superseded
                and private.aig1_record_open(l.entity_type, l.entity_id))
    and (p_types is null or 'agent_stopped' = any(p_types))  -- PERF1 gate
$function$;

revoke all on function private.derived_exceptions_of(p_org uuid, p_types text[]) from public, anon, authenticated, service_role;
comment on function private.derived_exceptions_of(p_org uuid, p_types text[]) is 'PERF1 (ADR-226): the exception branches of private.derived_exceptions, each gated by its type. p_types = null computes every branch (= derived_exceptions); a caller passes the types it reads, so a branch it never reads (order_not_covered: one order_cover call per confirmed order) is not computed. Callers keep their own type filter. Read-only.';

-- public.team_order_offers: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.team_order_offers). No text patch.

-- public.team_order_offers()
CREATE OR REPLACE FUNCTION public.team_order_offers()
 RETURNS TABLE(order_id uuid, team_id uuid, sentence text, starts_at timestamp with time zone, ends_at timestamp with time zone, duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[], required_tags text[], distance_km numeric, limit_km numeric, offer_state text, taken_member_id uuid, taken_by uuid, taken_at timestamp with time zone, acknowledged_at timestamp with time zone, latest_cover_at timestamp with time zone, caller_free boolean, release_kind text, released_member_id uuid, reasons text[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- ORDER-F1-F3: the cost of one call follows the caller's own teams, not the platform. `me` is the caller's teams,
  -- each checked once by private.is_team_member (LEAVE1-3 inside), so f.team_id in `me` is exactly
  -- is_team_member(f.team_id); the clock is read once; ended or withdrawn orders and other teams' rows are removed
  -- before any per-row helper runs; last_release looks only at orders where one of her teams has a release, but still
  -- takes the latest release of ALL teams for such an order (a later release by another team hides hers, as before).
  with me as materialized (
    select distinct tm.team_id from public.team_memberships tm
    where tm.user_id = (select auth.uid()) and private.is_team_member(tm.team_id)   -- LEAVE1-3 inside
  ),
  clock as materialized (select private.now() as now_),
  last_release as materialized (
    select distinct on (x.order_id) x.order_id, x.team_id, x.member_id, x.taken_by, x.taken_at, x.acknowledged_at,
           case x.release_reason when 'member_cannot' then 'member_cannot' when 'not_acknowledged' then 'not_acknowledged'
                when 'withdrawn' then 'order_withdrawn'  -- HD-2 slice 5: the client took the order back
                else 'no_longer_eligible' end as kind
    from public.order_takes x
    where x.released_at is not null
      and x.order_id in (select y.order_id from public.order_takes y join me on me.team_id = y.team_id
                         join public.partner_requests q on q.id = y.order_id
                         where y.released_at is not null and q.ends_at > (select c.now_ from clock c))
    order by x.order_id, x.released_at desc, x.id desc
  ),
  mine as materialized (
    select f.order_id, f.team_id, f.round, f.distance_km, f.limit_km
    from public.order_offers f
    join me on me.team_id = f.team_id
    join public.partner_requests p on p.id = f.order_id
    where p.ends_at > (select c.now_ from clock c)
      and p.withdrawn_at is null   -- HD-2 slice 5: a withdrawn order is offered to no team any more
  )
  select f.order_id, f.team_id, p.request_title, p.starts_at, p.ends_at,
         private.order_work_minutes(p.starts_at, p.pause_starts_at, p.pause_ends_at, p.ends_at),  -- HD-3s-F2: no pause
         p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, f.distance_km, f.limit_km,
         case when k.id is null then 'open' else 'taken_by_us' end, k.member_id,
         k.taken_by, k.taken_at, k.acknowledged_at, private.order_latest_cover_at(p.id),
         private.order_member_step(p.id, f.team_id, (select auth.uid())) = 4,
         case when k.id is null and r.team_id = f.team_id then r.kind end,
         case when k.id is null and r.team_id = f.team_id then r.member_id end,
         -- BK-c3: reasons explain an open offer only; a taken row carries none.
         case when k.id is null then private.order_offer_reasons(p.id, f.team_id) else '{}'::text[] end
  from mine f
  join public.partner_requests p on p.id = f.order_id
  left join public.order_takes k on k.order_id = f.order_id and k.released_at is null
  left join last_release r on r.order_id = f.order_id
  where f.round = private.order_round(f.order_id)
    and not exists (select 1 from public.order_declines d
                    where d.order_id = f.order_id and d.round = f.round and d.team_id = f.team_id)
    and (k.id is null or k.team_id = f.team_id)
  union all
  -- CGR-234 (d): the own team's take was released and the new round offers it nothing: it still sees the release.
  -- HD-2 slice 5: a take released because the client withdrew the order is shown to its team as well (no new round).
  select r.order_id, r.team_id, p.request_title, p.starts_at, p.ends_at,
         private.order_work_minutes(p.starts_at, p.pause_starts_at, p.pause_ends_at, p.ends_at),  -- HD-3s-F2: no pause
         p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, null::numeric, null::numeric, 'released', null::uuid,
         r.taken_by, r.taken_at, r.acknowledged_at, private.order_latest_cover_at(p.id), false, r.kind, r.member_id,
         '{}'::text[]
  from last_release r
  join me on me.team_id = r.team_id
  join public.partner_requests p on p.id = r.order_id
  where p.ends_at > (select c.now_ from clock c)
    and not exists (select 1 from public.order_takes t where t.order_id = r.order_id and t.released_at is null)
    and ((p.withdrawn_at is not null and r.kind = 'order_withdrawn')
         or not exists (select 1 from public.order_offers f
                        where f.order_id = r.order_id and f.team_id = r.team_id and f.round = private.order_round(r.order_id)))
  order by 4, 1, 2
$function$;

revoke all on function public.team_order_offers() from public, anon, authenticated, service_role;
grant execute on function public.team_order_offers() to authenticated;
grant execute on function public.team_order_offers() to service_role;
comment on function public.team_order_offers() is 'BK-c1/c2/c3 (ADR-199, ADR-200, ADR-201): the caller''s own teams'' shift-order offers, ordered by starts_at then ids (order A). `reasons` are clause codes for an open row only; no rank, no other team, no count.';

-- public.client_orders: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.client_orders). No text patch.

-- public.client_orders()
CREATE OR REPLACE FUNCTION public.client_orders()
 RETURNS TABLE(id uuid, client_account_id uuid, sentence text, starts_at timestamp with time zone, ends_at timestamp with time zone, duration_minutes integer, postcode text, place_name text, grade text, activity_tags text[], required_tags text[], radius_km numeric, shift_label text, confirmed_at timestamp with time zone, cover_state text, cover_detail text, latest_cover_at timestamp with time zone, covered_team_name text, taken_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select p.id, p.client_account_id, p.request_title, p.starts_at, p.ends_at,
         private.order_work_minutes(p.starts_at, p.pause_starts_at, p.pause_ends_at, p.ends_at),  -- HD-3s-F2: no pause
         p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, p.radius_km, p.shift_label, p.confirmed_at,
         c.cover_state, c.cover_detail, c.latest_cover_at,
         (select t.name from public.teams t where t.id = c.covered_team_id),
         c.taken_at
  from public.partner_requests p
  -- HD-2: one reading of the cover for /order and the home plan (private.order_client_state).
  cross join lateral private.order_client_state(p.id, private.now()) c
  where p.order_kind is not null and private.is_client_member(p.client_account_id)
    and not (select private.access_ended((select auth.uid())))  -- LEAVE1-3; ORDER-F1: read once per call, not per row
  order by p.starts_at
$function$;

revoke all on function public.client_orders() from public, anon, authenticated, service_role;
grant execute on function public.client_orders() to authenticated;
grant execute on function public.client_orders() to service_role;
