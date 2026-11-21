-- HD-2 «Lücke → externer Auftrag → Status zurück» (brief docs/agents/briefs/HD.md §3, §3a, §4 row HD-2; founder
-- FE-109 (C), FE-110). Synthetic simulation only; fixed, checkable rules, no AI.
--   * `institutions.order_postcode`: the home's postcode for its orders, set by the home (first sent order); never
--     invented by NAVORA.
--   * `institution_gap_orders`: an order prepared from one gap cell (prepared → sent | discarded). The order itself is
--     an ordinary client order made by `confirm_client_order` on the home's client account (no second order path).
--     At most one active order per cell: a transaction lock per cell plus a partial unique index (double-order lock).
--     RLS on, no grant: read and written only through the definer functions below.
--   * `private.order_client_state`: the one client reading of an order's cover, moved out of `client_orders()`
--     unchanged and now shared with `institution_plan` (week, month and plan per person read what /order reads).
--   * `institution_plan`: each cell carries its active order (`order`: state, cover_state, cover_detail) and
--     `external_covered`. Only a covered order (G: the person confirmed and was checked, BK-c/BK-e) fills a slot of
--     its grade; prepared (E), offered (A), taken-not-confirmed (T), not covered (K) and no longer covered (N) never do.
--   * Commands (role lead or planner; LEAVE1-3 through assert_access_open / is_institution_member; audit through
--     `institution_audit`): `institution_prepare_gap_order` (refuses: not a gap, already ordered, past shift; a missing
--     grade fixes the grade), `institution_preview_gap_order` → `preview_client_order`, `institution_send_gap_order` →
--     `confirm_client_order` (row lock; refuses: wrong grade for a missing grade, the gap closed meanwhile; a second
--     send is `already_sent`), `institution_discard_gap_order` (a draft only). The commands read the cell through the
--     plan itself (`private.institution_plan_cell`): one status source.
--   * Not here (named on PR #1641): withdrawing a sent order (no client withdraw command exists yet).
-- Every function is created whole from its canonical file (STAB-1, TESTS 6, scripts/fn-source.mjs migration);
-- `client_orders` and `institution_plan` keep security definer, search_path, grants and their LEAVE1-3 guards (157).
-- Idempotent (if not exists / create or replace). Way back: drop the seven new functions and the table and column,
-- re-create client_orders and institution_plan from their previous files.

-- 1. Data of the home: the postcode its external orders go to (set once by the home, never invented) ---------------
alter table public.institutions add column if not exists order_postcode text references public.postcodes (postcode);
comment on column public.institutions.order_postcode is
  'HD-2: the postcode of the home for its external shift orders; set by the home on its first gap order (review '
  'screen), chosen from the postcode list. Null until the home sets it.';

-- 2. Gap orders: one external order prepared from one plan cell ------------------------------------------------------
create table if not exists public.institution_gap_orders (
  id                uuid primary key default gen_random_uuid(),
  institution_id    uuid not null references public.institutions (id) on delete cascade,
  station_id        uuid not null,
  shift_type_id     uuid not null,
  work_date         date not null,
  client_account_id uuid not null references public.client_accounts (id),
  grade_fixed       text check (grade_fixed is null or grade_fixed in ('ags_eba', 'fage_efz', 'nurse_hf_fh')),
  state             text not null default 'prepared' check (state in ('prepared', 'sent', 'discarded')),
  order_id          uuid unique references public.partner_requests (id),
  prepared_by       uuid not null,
  prepared_at       timestamptz not null default private.now(),
  sent_by           uuid,
  sent_at           timestamptz,
  discarded_by      uuid,
  discarded_at      timestamptz,
  foreign key (station_id, institution_id) references public.institution_stations (id, institution_id) on delete cascade,
  foreign key (shift_type_id, institution_id) references public.institution_shift_types (id, institution_id) on delete cascade,
  check ((state = 'sent') = (order_id is not null and sent_at is not null and sent_by is not null)),
  check ((state = 'discarded') = (discarded_at is not null and discarded_by is not null))
);
comment on table public.institution_gap_orders is
  'HD-2: an external shift order prepared from one gap cell of the home plan (state prepared → sent | discarded). '
  'The order itself is a partner_requests row made by confirm_client_order (no second order path). At most one '
  'active (prepared or sent) row per cell. Read and written only through the institution_* functions.';
-- The double-order lock: at most one active order per cell (the commands also take a transaction lock per cell).
create unique index if not exists institution_gap_orders_one_active
  on public.institution_gap_orders (station_id, shift_type_id, work_date) where state in ('prepared', 'sent');
create index if not exists institution_gap_orders_inst_date on public.institution_gap_orders (institution_id, work_date);
alter table public.institution_gap_orders enable row level security;
revoke all on public.institution_gap_orders from public, anon, authenticated;

-- Whole-file re-creation from supabase/schema/functions (STAB-1); generated by scripts/fn-source.mjs.

-- private.order_client_state: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.order_client_state). No text patch.

-- private.order_client_state(p_order_id uuid, p_at timestamp with time zone)
CREATE OR REPLACE FUNCTION private.order_client_state(p_order_id uuid, p_at timestamp with time zone)
 RETURNS TABLE(cover_state text, cover_detail text, latest_cover_at timestamp with time zone, covered_team_id uuid, taken_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when c.cover_state = 'pending_acknowledgement' then 'open'
              -- UXR-225 (a) with `lca` F-2 (PO 12:39 (2)): «nicht mehr gedeckt» only if the client was ever shown
              -- «gedeckt», i.e. some take of this order was acknowledged (self-named takes are acknowledged at once).
              when c.cover_state = 'no_longer_covered' and not ever_covered.yes then 'open'
              else c.cover_state end,
         case when c.cover_state = 'pending_acknowledgement' then 'awaiting_acknowledgement'
              -- HD-2 / FE-110 (b): the safety net (`no_offer_open`) never reads as «the offer goes out again».
              when c.cover_state = 'no_longer_covered' and not ever_covered.yes and c.cover_detail = 'no_offer_open'
                then 'take_fell_away_no_offer'
              when c.cover_state = 'no_longer_covered' and not ever_covered.yes then 'take_fell_away'
              when c.cover_detail in ('no_team_eligible', 'all_declined') then 'no_team_free'   -- F-1
              when c.cover_detail = 'not_acknowledged' then 'cover_time_reached'
              else c.cover_detail end,
         c.latest_cover_at,
         case when c.cover_state = 'covered' then c.take_team_id end,
         case when c.cover_state = 'covered' then c.taken_at end
  from private.order_cover(p_order_id, p_at) c
  cross join lateral (select exists (select 1 from public.order_takes t
                                     where t.order_id = p_order_id and t.acknowledged_at is not null) as yes) ever_covered
$function$;

revoke all on function private.order_client_state(p_order_id uuid, p_at timestamp with time zone) from public, anon, authenticated, service_role;

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
         (extract(epoch from (p.ends_at - p.starts_at)) / 60)::int, p.postcode, p.city, p.grade, p.activity_tags,
         p.required_tags, p.radius_km, p.shift_label, p.confirmed_at,
         c.cover_state, c.cover_detail, c.latest_cover_at,
         (select t.name from public.teams t where t.id = c.covered_team_id),
         c.taken_at
  from public.partner_requests p
  -- HD-2: one reading of the cover for /order and the home plan (private.order_client_state).
  cross join lateral private.order_client_state(p.id, private.now()) c
  where p.order_kind is not null and private.is_client_member(p.client_account_id)
    and not private.access_ended((select auth.uid()))  -- LEAVE1-3
  order by p.starts_at
$function$;

revoke all on function public.client_orders() from public, anon, authenticated, service_role;
grant execute on function public.client_orders() to authenticated;
grant execute on function public.client_orders() to service_role;

-- public.institution_plan: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_plan). No text patch.

-- public.institution_plan(p_institution_id uuid, p_from date, p_to date)
CREATE OR REPLACE FUNCTION public.institution_plan(p_institution_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  inst public.institutions;
begin
  -- LEAVE1-3: is_institution_member is false for a person whose access ended.
  if p_institution_id is null or not private.is_institution_member(p_institution_id) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 41 then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('range_not_valid'));
  end if;
  select * into inst from public.institutions where id = p_institution_id;
  return jsonb_build_object(
    'result', 'ok',
    'institution', jsonb_build_object('id', inst.id, 'display_name', inst.display_name, 'simulation', inst.simulation,
      'role', (select m.role from public.institution_members m
               where m.institution_id = inst.id and m.user_id = (select auth.uid())),
      'order_postcode', inst.order_postcode,
      'can_order', exists (select 1 from public.client_accounts ca
                           where ca.institution_id = inst.id and private.is_client_member(ca.id))),
    'from', p_from, 'to', p_to,
    'stations', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.sort, s.name)
                          from public.institution_stations s where s.institution_id = inst.id), '[]'::jsonb),
    'shift_types', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'code', t.code, 'label', t.label,
                                     'starts_at', to_char(t.starts_at, 'HH24:MI'), 'ends_at', to_char(t.ends_at, 'HH24:MI'))
                                   order by t.sort, t.starts_at)
                             from public.institution_shift_types t where t.institution_id = inst.id), '[]'::jsonb),
    'staff', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'display_name', p.display_name, 'grade', p.grade,
                               'home_station_id', p.home_station_id, 'active', p.active) order by p.display_name, p.id)
                       from public.institution_staff p where p.institution_id = inst.id), '[]'::jsonb),
    'absences', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'staff_id', a.staff_id,
                                  'starts_on', a.starts_on, 'ends_on', a.ends_on) order by a.starts_on, a.id)
                          from public.institution_absences a
                          where a.institution_id = inst.id and a.starts_on <= p_to and a.ends_on >= p_from), '[]'::jsonb),
    'cells', coalesce((
      select jsonb_agg(jsonb_build_object(
               'date', c.d, 'station_id', c.station_id, 'shift_type_id', c.shift_type_id,
               'required_total', c.required_total, 'required_grade', c.required_grade,
               'required_grade_count', c.required_grade_count, 'example', c.example,
               'assigned', c.assigned, 'present', c.present, 'grade_present', c.grade_present,
               'external_covered', c.ext,
               'missing', greatest(coalesce(c.required_total, 0) - c.present - c.ext, 0),
               'status', case when c.required_total is null then 'no_rule'
                              when c.present + c.ext >= c.required_total
                                   and c.grade_present + c.ext_grade >= c.required_grade_count then 'ok'
                              else 'gap' end,
               'order', c.gap_order)
             order by c.d, c.station_sort, c.station_name, c.shift_sort, c.shift_starts)
      from (
        select d.d::date as d, s.id as station_id, s.sort as station_sort, s.name as station_name,
               t.id as shift_type_id, t.sort as shift_sort, t.starts_at as shift_starts,
               r.required_total, r.required_grade, coalesce(r.required_grade_count, 0) as required_grade_count,
               coalesce(r.example, false) as example,
               coalesce(x.assigned, '[]'::jsonb) as assigned,
               coalesce(x.present, 0) as present,
               coalesce(x.grade_present, 0) as grade_present,
               (go.cover_state is not distinct from 'covered')::int as ext,
               (go.cover_state is not distinct from 'covered' and go.grade = r.required_grade)::int as ext_grade,
               case when go.id is null then null else jsonb_build_object(
                 'gap_order_id', go.id, 'state', go.state, 'order_id', go.order_id, 'grade', go.grade,
                 'grade_fixed', go.grade_fixed is not null, 'starts_at', go.starts_at,
                 'cover_state', go.cover_state, 'cover_detail', go.cover_detail,
                 'latest_cover_at', go.latest_cover_at) end as gap_order
        from generate_series(p_from, p_to, interval '1 day') d(d)
        cross join public.institution_stations s
        cross join public.institution_shift_types t
        left join public.institution_staffing_rules r on r.station_id = s.id and r.shift_type_id = t.id
        left join lateral (
          select jsonb_agg(jsonb_build_object('assignment_id', ia.id, 'staff_id', p.id, 'display_name', p.display_name,
                                              'grade', p.grade, 'absent', ab.absent, 'inactive', not p.active)
                           order by p.display_name, p.id) as assigned,
                 -- HD-1 R1: an inactive person never counts as present (she stays listed, marked inactive).
                 count(*) filter (where p.active and not ab.absent)::int as present,
                 count(*) filter (where p.active and not ab.absent and p.grade = r.required_grade)::int as grade_present
          from public.institution_assignments ia
          join public.institution_staff p on p.id = ia.staff_id
          -- HD-1 R3: an absence covers whole calendar days; a shift touching one of them (the night D-1 -> D) is absent.
          cross join lateral (select exists (select 1 from public.institution_absences a
                                             where a.staff_id = p.id
                                               and daterange(a.starts_on, a.ends_on, '[]')
                                                   && private.institution_shift_days(d.d::date, t.starts_at, t.ends_at))
                              as absent) ab
          where ia.station_id = s.id and ia.shift_type_id = t.id and ia.work_date = d.d::date
        ) x on true
        -- HD-2: the active external order of the cell (at most one) and its cover, read like /order reads it.
        left join lateral (
          select g.id, g.state, g.order_id, g.grade_fixed, coalesce(pr.grade, g.grade_fixed) as grade, pr.starts_at,
                 cs.cover_state, cs.cover_detail, cs.latest_cover_at
          from public.institution_gap_orders g
          left join public.partner_requests pr on pr.id = g.order_id
          left join lateral private.order_client_state(g.order_id, private.now()) cs on g.order_id is not null
          where g.station_id = s.id and g.shift_type_id = t.id and g.work_date = d.d::date
            and g.state in ('prepared', 'sent')
        ) go on true
        where s.institution_id = inst.id and t.institution_id = inst.id
      ) c), '[]'::jsonb));
end $function$;

revoke all on function public.institution_plan(p_institution_id uuid, p_from date, p_to date) from public, anon, authenticated, service_role;
grant execute on function public.institution_plan(p_institution_id uuid, p_from date, p_to date) to authenticated;
grant execute on function public.institution_plan(p_institution_id uuid, p_from date, p_to date) to service_role;

-- private.institution_plan_cell: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.institution_plan_cell). No text patch.

-- private.institution_plan_cell(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date)
CREATE OR REPLACE FUNCTION private.institution_plan_cell(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select c from jsonb_array_elements(public.institution_plan(p_institution_id, p_work_date, p_work_date) -> 'cells') c
  where c ->> 'station_id' = p_station_id::text and c ->> 'shift_type_id' = p_shift_type_id::text
$function$;

revoke all on function private.institution_plan_cell(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date) from public, anon, authenticated, service_role;

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
  -- Double-order lock: one transaction per cell at a time (the partial unique index is the backstop).
  perform pg_advisory_xact_lock(hashtextextended('institution_gap:' || p_station_id || ':' || p_shift_type_id || ':'
                                                 || p_work_date, 0));
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
    'grade', fixed, 'grade_fixed', fixed is not null,
    'postcode', (select i.order_postcode from public.institutions i where i.id = p_institution_id),
    'activity_tags', coalesce(to_jsonb(prev.activity_tags), '[]'::jsonb),
    'required_tags', coalesce(to_jsonb(prev.required_tags), '[]'::jsonb),
    'activities_from_last_order', prev.activity_tags is not null));
end $function$;

revoke all on function public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date) from public, anon, authenticated, service_role;
grant execute on function public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date) to authenticated;
grant execute on function public.institution_prepare_gap_order(p_institution_id uuid, p_station_id uuid, p_shift_type_id uuid, p_work_date date) to service_role;

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
  if g.grade_fixed is not null and p_grade is distinct from g.grade_fixed then
    return jsonb_build_object('problems', jsonb_build_array('grade_not_missing'));
  end if;
  cell := private.institution_plan_cell(g.institution_id, g.station_id, g.shift_type_id, g.work_date);
  -- The gap may have closed meanwhile (a person was assigned): then there is nothing to order.
  if cell is null or cell ->> 'status' <> 'gap' then
    return jsonb_build_object('problems', jsonb_build_array('not_a_gap'));
  end if;
  return jsonb_build_object('problems', '[]'::jsonb, 'start_date', g.work_date, 'start_time', t.starts_at,
                            'end_time', t.ends_at);
end $function$;

revoke all on function private.institution_gap_order_args(g institution_gap_orders, p_grade text) from public, anon, authenticated, service_role;

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
  return jsonb_build_object('result', 'ok', 'preview',
    public.preview_client_order(g.client_account_id, (a ->> 'start_date')::date, (a ->> 'start_time')::time,
                                (a ->> 'end_time')::time, p_postcode, p_grade, p_activity_tags, p_required_tags,
                                p_radius_km));
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

-- public.institution_discard_gap_order: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_discard_gap_order). No text patch.

-- public.institution_discard_gap_order(p_gap_order_id uuid)
CREATE OR REPLACE FUNCTION public.institution_discard_gap_order(p_gap_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  g public.institution_gap_orders;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  select * into g from public.institution_gap_orders where id = p_gap_order_id for update;
  if g.id is null or not private.is_institution_member(g.institution_id, array['lead', 'planner']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if g.state <> 'prepared' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('not_prepared'), 'state', g.state);
  end if;
  update public.institution_gap_orders set state = 'discarded', discarded_by = (select auth.uid()),
    discarded_at = private.now() where id = g.id;
  perform private.institution_audit(g.institution_id, 'institution_discard_gap_order', 'institution_gap_orders', g.id,
    '{}'::jsonb);
  return jsonb_build_object('result', 'ok');
end $function$;

revoke all on function public.institution_discard_gap_order(p_gap_order_id uuid) from public, anon, authenticated, service_role;
grant execute on function public.institution_discard_gap_order(p_gap_order_id uuid) to authenticated;
grant execute on function public.institution_discard_gap_order(p_gap_order_id uuid) to service_role;
