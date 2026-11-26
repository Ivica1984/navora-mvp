-- HD-3s «Geteilter Dienst (zwei Blöcke) im Heimplan, feste Regeln» (brief docs/agents/briefs/HD-3s.md, PO contract
-- 2026-11-26 11:39; founder parameters FE-127 (3)). Synthetic simulation only; fixed, checkable rules, no AI.
--   * Storage: a split shift keeps starts_at (start of block 1) and ends_at (end of block 2), so every existing reading
--     of a shift (overlap and absence in institution_assign_staff, rest in institution_rule_breaches, institution_shift_
--     days, the cell lock) sees the whole working day without change: a shift inside the pause is `busy` (K3), rest is
--     counted after block 2 and before block 1, never between the blocks (founder point 2), one work date = one working
--     day (founder point 3). The two new columns block1_ends_at and block2_starts_at mark the pause; both NULL = one
--     block (every existing row). shift_class `split` exactly when the blocks are set (check constraint).
--   * V1-V5 as check constraints, named so PostgreSQL tests them in this order (alphabetical), and as
--     private.institution_split_problem for the command: time_format, zero_length, block_crosses_midnight, block_order,
--     no_pause; the same codes as src/features/home-plan/split.ts. No minimum or maximum pause (not given, not invented).
--   * R-h: private.institution_shift_minutes counts block 1 plus block 2, never the pause (founder point 1);
--     institution_rule_breaches uses it on both sides of the weekly sum.
--   * R-c: a split shift fits shift models `any` and `no_night` only (founder 2026-11-25 ca. 00:20).
--   * New commands (lead only, LEAVE1-3, membership before the row lock, audit): institution_set_split_shift_type and
--     institution_set_work_days_per_week (S5 «Arbeitstage pro Woche», default 5, 1-7; the daily target is a hint, never
--     a block). A separate command instead of a new institution_set_planning_limits signature: no drop, so the app
--     that runs on Render while the staging job applies this migration keeps working.
--   * institution_set_shift_type and institution_set_shift_class refuse a split type (`shift_type_is_split`), so blocks
--     and class change together. institution_prepare_gap_order and institution_gap_order_args refuse a split shift
--     (`split_shift_not_orderable`, fail closed: an order has one time window; follow-up HD-3s-F2).
--   * institution_plan returns block1_ends_at, block2_starts_at and work_days_per_week.
-- Not built (brief «Out of scope»): R-i 50 h, R-j 14 h span, R-k night rule, S6 pause hint (no founder value; `lca` in the
-- gate of this package; follow-up HD-3s-F1).
-- RLS and table grants unchanged (no grant to anon/authenticated on any institution table). Every function is created
-- whole from its canonical file (STAB-1, TESTS 6). Idempotent (add column if not exists, drop constraint if exists, create
-- or replace). Way back: re-create the 0172/0173/0175/0177 versions of the six changed functions from git, drop the two new
-- commands and two helpers, delete split rows (none exist outside tests), drop the five split constraints and
-- institutions_work_days_per_week_check, restore the 0172 shift_class check, drop the three columns.

alter table public.institution_shift_types
  add column if not exists block1_ends_at time,
  add column if not exists block2_starts_at time;
comment on column public.institution_shift_types.block1_ends_at is
  'HD-3s: end of block 1 of a split shift (block 1 = starts_at..block1_ends_at); NULL = a shift with one block';
comment on column public.institution_shift_types.block2_starts_at is
  'HD-3s: start of block 2 of a split shift (block 2 = block2_starts_at..ends_at); NULL = a shift with one block';
alter table public.institution_shift_types drop constraint if exists institution_shift_types_shift_class_check;
alter table public.institution_shift_types add constraint institution_shift_types_shift_class_check
  check (shift_class is null or shift_class in ('early', 'late', 'night', 'split'));
alter table public.institution_shift_types drop constraint if exists institution_shift_types_split_blocks;
alter table public.institution_shift_types add constraint institution_shift_types_split_blocks
  check ((block1_ends_at is null) = (block2_starts_at is null)
         and (shift_class is not distinct from 'split') = (block1_ends_at is not null));
alter table public.institution_shift_types drop constraint if exists institution_shift_types_split_v1_time_format;
alter table public.institution_shift_types add constraint institution_shift_types_split_v1_time_format
  check (block1_ends_at is null or (
         extract(second from starts_at) = 0 and extract(second from block1_ends_at) = 0
     and extract(second from block2_starts_at) = 0 and extract(second from ends_at) = 0
     and starts_at < '24:00'::time and block1_ends_at < '24:00'::time
     and block2_starts_at < '24:00'::time and ends_at < '24:00'::time));
alter table public.institution_shift_types drop constraint if exists institution_shift_types_split_v2_zero_length;
alter table public.institution_shift_types add constraint institution_shift_types_split_v2_zero_length
  check (block1_ends_at is null or (block1_ends_at <> starts_at and ends_at <> block2_starts_at));
alter table public.institution_shift_types drop constraint if exists institution_shift_types_split_v3_block_crosses_midnight;
alter table public.institution_shift_types add constraint institution_shift_types_split_v3_block_crosses_midnight
  check (block1_ends_at is null or (block1_ends_at >= starts_at and ends_at >= block2_starts_at));
alter table public.institution_shift_types drop constraint if exists institution_shift_types_split_v4_block_order;
alter table public.institution_shift_types add constraint institution_shift_types_split_v4_block_order
  check (block1_ends_at is null or block2_starts_at >= block1_ends_at);
alter table public.institution_shift_types drop constraint if exists institution_shift_types_split_v5_no_pause;
alter table public.institution_shift_types add constraint institution_shift_types_split_v5_no_pause
  check (block1_ends_at is null or block2_starts_at <> block1_ends_at);

alter table public.institutions
  add column if not exists work_days_per_week integer not null default 5
    constraint institutions_work_days_per_week_check check (work_days_per_week between 1 and 7);
comment on column public.institutions.work_days_per_week is
  'HD-3s S5 (FE-127 (3)): Arbeitstage pro Woche of the home, default 5; daily target = weekly_target_hours / this (hint only)';

-- Whole-file re-creation from supabase/schema/functions (STAB-1); generated by scripts/fn-source.mjs.

-- private.institution_split_problem: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.institution_split_problem). No text patch.

-- private.institution_split_problem(p_b1_starts time without time zone, p_b1_ends time without time zone, p_b2_starts time without time zone, p_b2_ends time without time zone)
CREATE OR REPLACE FUNCTION private.institution_split_problem(p_b1_starts time without time zone, p_b1_ends time without time zone, p_b2_starts time without time zone, p_b2_ends time without time zone)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  -- HD-3s (brief HD-3s.md scope 1; rules draft §1): the shape of a split shift (two blocks on one day), checked in this
  -- order; the first failing check is the reason, the same code the screen shows (src/features/home-plan/split.ts
  -- validateSplitShift) and the same checks as the check constraints v1-v5 of institution_shift_types. NULL = valid.
  -- NAVORA sets no minimum or maximum pause (not given by the founder, not invented).
  select case
    when p_b1_starts is null or p_b1_ends is null or p_b2_starts is null or p_b2_ends is null
      or extract(second from p_b1_starts) <> 0 or extract(second from p_b1_ends) <> 0
      or extract(second from p_b2_starts) <> 0 or extract(second from p_b2_ends) <> 0
      or p_b1_starts >= '24:00'::time or p_b1_ends >= '24:00'::time
      or p_b2_starts >= '24:00'::time or p_b2_ends >= '24:00'::time then 'time_format'
    when p_b1_ends = p_b1_starts or p_b2_ends = p_b2_starts then 'zero_length'
    when p_b1_ends < p_b1_starts or p_b2_ends < p_b2_starts then 'block_crosses_midnight'
    when p_b2_starts < p_b1_ends then 'block_order'
    when p_b2_starts = p_b1_ends then 'no_pause'
  end
$function$;

revoke all on function private.institution_split_problem(p_b1_starts time without time zone, p_b1_ends time without time zone, p_b2_starts time without time zone, p_b2_ends time without time zone) from public, anon, authenticated, service_role;

-- private.institution_shift_minutes: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.institution_shift_minutes). No text patch.

-- private.institution_shift_minutes(p_work_date date, p_starts time without time zone, p_ends time without time zone, p_block1_ends time without time zone, p_block2_starts time without time zone)
CREATE OR REPLACE FUNCTION private.institution_shift_minutes(p_work_date date, p_starts time without time zone, p_ends time without time zone, p_block1_ends time without time zone, p_block2_starts time without time zone)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  -- HD-3s R-h (founder FE-127 (3) point 1: the pause is not working time): the working minutes of one shift on its work
  -- date. One block: the whole span (HD-3a). A split shift: block 1 plus block 2, each turned into instants on its own
  -- (private.institution_shift_span, so a DST change counts as in HD-3a), the pause in between never counted. The same
  -- reading as src/features/home-plan/draft.ts shiftMinutes().
  select case
    when p_block1_ends is null or p_block2_starts is null then
      extract(epoch from upper(private.institution_shift_span(p_work_date, p_starts, p_ends))
                       - lower(private.institution_shift_span(p_work_date, p_starts, p_ends))) / 60
    else
      extract(epoch from upper(private.institution_shift_span(p_work_date, p_starts, p_block1_ends))
                       - lower(private.institution_shift_span(p_work_date, p_starts, p_block1_ends))) / 60
      + extract(epoch from upper(private.institution_shift_span(p_work_date, p_block2_starts, p_ends))
                         - lower(private.institution_shift_span(p_work_date, p_block2_starts, p_ends))) / 60
  end
$function$;

revoke all on function private.institution_shift_minutes(p_work_date date, p_starts time without time zone, p_ends time without time zone, p_block1_ends time without time zone, p_block2_starts time without time zone) from public, anon, authenticated, service_role;

-- private.institution_rule_breaches: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration private.institution_rule_breaches). No text patch.

-- private.institution_rule_breaches(p_staff_id uuid, p_shift_type_id uuid, p_work_date date, p_self uuid)
CREATE OR REPLACE FUNCTION private.institution_rule_breaches(p_staff_id uuid, p_shift_type_id uuid, p_work_date date, p_self uuid)
 RETURNS text[]
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  p public.institution_staff;
  t public.institution_shift_types;
  h public.institutions;
  span tstzrange;
  breaches text[] := '{}';
  run int := 1;
  d date;
  week_start date;
  used numeric;
begin
  -- HD-3a (FE-123, Q3): the planning rules a shift of this person breaks, read against every other assignment of the
  -- person (p_self = the shift itself when it is already stored, else NULL). One reading for the hand assignment
  -- (institution_assign_staff) and the plan (institution_plan); the same rules as the draft (src/features/home-plan/
  -- draft.ts R-c, R-f, R-g, R-h). Absence and double booking are not here: they stay blocked in the commands.
  -- Order fixed: shift_model, rest, consecutive, pensum_full. Rest time and days in a row: founder parameters,
  -- «Arbeitszeitgesetz nicht abschliessend geprüft» (`lca` before real data).
  select * into p from public.institution_staff where id = p_staff_id;
  select * into t from public.institution_shift_types where id = p_shift_type_id;
  if p.id is null or t.id is null or p_work_date is null then
    return breaches;
  end if;
  select * into h from public.institutions where id = p.institution_id;
  -- R-c: a restricted model fits only its classes, never an unclassified type. HD-3s (founder FE-127 (3)): a split
  -- shift fits `any` and `no_night` only, never «nur Früh», «nur Spät» or «nur Nacht».
  if p.shift_model <> 'any' and not coalesce(
       (p.shift_model = 'early_only' and t.shift_class = 'early')
    or (p.shift_model = 'late_only' and t.shift_class = 'late')
    or (p.shift_model = 'night_only' and t.shift_class = 'night')
    or (p.shift_model = 'no_night' and t.shift_class in ('early', 'late', 'split')), false) then
    breaches := breaches || 'shift_model'::text;
  end if;
  -- HD-3s: starts_at..ends_at is the whole working day of a split shift (start of block 1 to end of block 2), so rest
  -- is counted from the end of block 2 and to the start of block 1, never between the blocks (founder FE-127 (3)).
  span := private.institution_shift_span(p_work_date, t.starts_at, t.ends_at);
  -- R-f: less than min_rest_hours between this shift and another one (an overlap is blocked by the commands).
  if exists (select 1 from public.institution_assignments a
             join public.institution_shift_types o on o.id = a.shift_type_id
             cross join lateral (select private.institution_shift_span(a.work_date, o.starts_at, o.ends_at) as s) x
             where a.staff_id = p.id and a.id is distinct from p_self
               and a.work_date between p_work_date - 3 and p_work_date + 3
               and not (x.s && span)
               and greatest(lower(span) - upper(x.s), lower(x.s) - upper(span)) < make_interval(hours => h.min_rest_hours)) then
    breaches := breaches || 'rest'::text;
  end if;
  -- R-g: working days in a row (by work date; a second shift on a day already worked does not lengthen the run).
  d := p_work_date - 1;
  while run <= h.max_consecutive_days and exists (select 1 from public.institution_assignments a
        where a.staff_id = p.id and a.id is distinct from p_self and a.work_date = d) loop
    run := run + 1;
    d := d - 1;
  end loop;
  d := p_work_date + 1;
  while run <= h.max_consecutive_days and exists (select 1 from public.institution_assignments a
        where a.staff_id = p.id and a.id is distinct from p_self and a.work_date = d) loop
    run := run + 1;
    d := d + 1;
  end loop;
  if run > h.max_consecutive_days then
    breaches := breaches || 'consecutive'::text;
  end if;
  -- R-h: shift minutes per ISO week (Monday, by work date) over Pensum x weekly target hours. Not checked when the
  -- Pensum or the target hours are not entered (the draft does not plan such a person at all). HD-3s: working minutes
  -- only (private.institution_shift_minutes), the pause of a split shift is not working time (founder FE-127 (3)).
  if p.pensum_pct is not null and h.weekly_target_hours is not null then
    week_start := p_work_date - (extract(isodow from p_work_date)::int - 1);
    select coalesce(sum(private.institution_shift_minutes(a.work_date, o.starts_at, o.ends_at, o.block1_ends_at,
                                                          o.block2_starts_at)), 0) into used
      from public.institution_assignments a
      join public.institution_shift_types o on o.id = a.shift_type_id
      where a.staff_id = p.id and a.id is distinct from p_self
        and a.work_date >= week_start and a.work_date < week_start + 7;
    if used + private.institution_shift_minutes(p_work_date, t.starts_at, t.ends_at, t.block1_ends_at, t.block2_starts_at)
       > floor(p.pensum_pct * round(h.weekly_target_hours * 60) / 100) then
      breaches := breaches || 'pensum_full'::text;
    end if;
  end if;
  return breaches;
end $function$;

revoke all on function private.institution_rule_breaches(p_staff_id uuid, p_shift_type_id uuid, p_work_date date, p_self uuid) from public, anon, authenticated, service_role;

-- public.institution_set_shift_type: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_set_shift_type). No text patch.

-- public.institution_set_shift_type(p_institution_id uuid, p_code text, p_label text, p_starts_at time without time zone, p_ends_at time without time zone)
CREATE OR REPLACE FUNCTION public.institution_set_shift_type(p_institution_id uuid, p_code text, p_label text, p_starts_at time without time zone, p_ends_at time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  t_id uuid;
  cur public.institution_shift_types;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_code is null or char_length(btrim(p_code)) not between 1 and 12 or p_label is null
     or char_length(btrim(p_label)) not between 1 and 40 or p_starts_at is null or p_ends_at is null
     or p_starts_at = p_ends_at then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('input_not_valid'));
  end if;
  -- HD-1 R2: the times of a shift type that is used in the plan never change (they are part of every plan, past ones
  -- included); the home creates a new shift type instead. The row lock serialises with institution_assign_staff.
  select * into cur from public.institution_shift_types
    where institution_id = p_institution_id and code = btrim(p_code) for update;
  -- HD-3s: a split shift (two blocks) is changed only through institution_set_split_shift_type, so its blocks and its
  -- class always change together (the check constraints refuse a half-changed row).
  if cur.id is not null and cur.shift_class = 'split' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('shift_type_is_split'));
  end if;
  if cur.id is not null and (cur.starts_at <> p_starts_at or cur.ends_at <> p_ends_at)
     and exists (select 1 from public.institution_assignments a where a.shift_type_id = cur.id) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('shift_type_in_use'));
  end if;
  insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, sort)
    values (p_institution_id, btrim(p_code), btrim(p_label), p_starts_at, p_ends_at,
            coalesce((select max(sort) + 1 from public.institution_shift_types where institution_id = p_institution_id), 0))
    on conflict (institution_id, code) do update
      set label = excluded.label, starts_at = excluded.starts_at, ends_at = excluded.ends_at
    returning id into t_id;
  perform private.institution_audit(p_institution_id, 'institution_set_shift_type', 'institution_shift_types', t_id,
    jsonb_build_object('starts_at', to_char(p_starts_at, 'HH24:MI'), 'ends_at', to_char(p_ends_at, 'HH24:MI')));
  return jsonb_build_object('result', 'ok', 'shift_type_id', t_id);
end $function$;

revoke all on function public.institution_set_shift_type(p_institution_id uuid, p_code text, p_label text, p_starts_at time without time zone, p_ends_at time without time zone) from public, anon, authenticated, service_role;
grant execute on function public.institution_set_shift_type(p_institution_id uuid, p_code text, p_label text, p_starts_at time without time zone, p_ends_at time without time zone) to authenticated;
grant execute on function public.institution_set_shift_type(p_institution_id uuid, p_code text, p_label text, p_starts_at time without time zone, p_ends_at time without time zone) to service_role;

-- public.institution_set_shift_class: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_set_shift_class). No text patch.

-- public.institution_set_shift_class(p_shift_type_id uuid, p_shift_class text)
CREATE OR REPLACE FUNCTION public.institution_set_shift_class(p_shift_type_id uuid, p_shift_class text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  t public.institution_shift_types;
  inst_id uuid;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  -- Membership first, then the row lock (a non-member never holds a lock on the home's shift type row).
  select st.institution_id into inst_id from public.institution_shift_types st where st.id = p_shift_type_id;
  if p_shift_type_id is null or inst_id is null or not private.is_institution_member(inst_id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  -- FE-123 (Q2): the home chooses the class of each shift type; NULL = no class (then only persons with `any`).
  -- There is no day class. NAVORA sets no times and no class itself.
  if p_shift_class is not null and p_shift_class not in ('early', 'late', 'night') then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('shift_class_not_valid'));
  end if;
  -- Same row lock as institution_set_shift_type (R2); institution_assign_staff reads the type `for share`.
  select * into t from public.institution_shift_types where id = p_shift_type_id for update;
  if t.id is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  -- HD-3s: the class `split` belongs to the two blocks; it is set and kept by institution_set_split_shift_type only.
  if t.shift_class = 'split' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('shift_type_is_split'));
  end if;
  update public.institution_shift_types set shift_class = p_shift_class where id = t.id;
  perform private.institution_audit(t.institution_id, 'institution_set_shift_class', 'institution_shift_types', t.id,
    jsonb_build_object('shift_class', jsonb_build_object('old', t.shift_class, 'new', p_shift_class)));
  -- No assignment is removed or changed. The count names the assignments from today on whose person's shift model
  -- does not allow the new class, so the home sees them at once (the cell warning is built in HD-3a, #1729).
  return jsonb_build_object('result', 'ok',
    'affected_assignments', (select count(*) from public.institution_assignments a
                             join public.institution_staff s on s.id = a.staff_id
                             where a.shift_type_id = t.id
                               and a.work_date >= (private.at_zurich(private.now()))::date
                               and s.shift_model <> 'any'
                               and not (p_shift_class is not null and (
                                     (s.shift_model = 'early_only' and p_shift_class = 'early')
                                  or (s.shift_model = 'late_only' and p_shift_class = 'late')
                                  or (s.shift_model = 'night_only' and p_shift_class = 'night')
                                  or (s.shift_model = 'no_night' and p_shift_class in ('early', 'late'))))));
end $function$;

revoke all on function public.institution_set_shift_class(p_shift_type_id uuid, p_shift_class text) from public, anon, authenticated, service_role;
grant execute on function public.institution_set_shift_class(p_shift_type_id uuid, p_shift_class text) to authenticated;
grant execute on function public.institution_set_shift_class(p_shift_type_id uuid, p_shift_class text) to service_role;

-- public.institution_set_split_shift_type: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_set_split_shift_type). No text patch.

-- public.institution_set_split_shift_type(p_institution_id uuid, p_code text, p_label text, p_block1_starts_at time without time zone, p_block1_ends_at time without time zone, p_block2_starts_at time without time zone, p_block2_ends_at time without time zone)
CREATE OR REPLACE FUNCTION public.institution_set_split_shift_type(p_institution_id uuid, p_code text, p_label text, p_block1_starts_at time without time zone, p_block1_ends_at time without time zone, p_block2_starts_at time without time zone, p_block2_ends_at time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  t_id uuid;
  cur public.institution_shift_types;
  problem text;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  -- HD-3s (brief HD-3s.md scope 1): a shift type with two blocks (class `split`). Shift types are master data of the
  -- home: the lead only, as institution_set_shift_type and institution_set_shift_class (a planner plans with them).
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  if p_code is null or char_length(btrim(p_code)) not between 1 and 12 or p_label is null
     or char_length(btrim(p_label)) not between 1 and 40 then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('input_not_valid'));
  end if;
  -- V1-V5 in fixed order, the same codes as the screen and the check constraints.
  problem := private.institution_split_problem(p_block1_starts_at, p_block1_ends_at, p_block2_starts_at, p_block2_ends_at);
  if problem is not null then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array(problem));
  end if;
  -- HD-1 R2: the times of a shift type that is used in the plan never change (the home creates a new type instead). The
  -- row lock serialises with institution_assign_staff (`for share` on the type) and the other shift type commands.
  select * into cur from public.institution_shift_types
    where institution_id = p_institution_id and code = btrim(p_code) for update;
  if cur.id is not null
     and (cur.starts_at <> p_block1_starts_at or cur.ends_at <> p_block2_ends_at
          or cur.block1_ends_at is distinct from p_block1_ends_at or cur.block2_starts_at is distinct from p_block2_starts_at)
     and exists (select 1 from public.institution_assignments a where a.shift_type_id = cur.id) then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('shift_type_in_use'));
  end if;
  insert into public.institution_shift_types (institution_id, code, label, starts_at, ends_at, block1_ends_at,
                                              block2_starts_at, shift_class, sort)
    values (p_institution_id, btrim(p_code), btrim(p_label), p_block1_starts_at, p_block2_ends_at, p_block1_ends_at,
            p_block2_starts_at, 'split',
            coalesce((select max(sort) + 1 from public.institution_shift_types where institution_id = p_institution_id), 0))
    on conflict (institution_id, code) do update
      set label = excluded.label, starts_at = excluded.starts_at, ends_at = excluded.ends_at,
          block1_ends_at = excluded.block1_ends_at, block2_starts_at = excluded.block2_starts_at, shift_class = 'split'
    returning id into t_id;
  perform private.institution_audit(p_institution_id, 'institution_set_split_shift_type', 'institution_shift_types', t_id,
    jsonb_build_object('block1', to_char(p_block1_starts_at, 'HH24:MI') || '-' || to_char(p_block1_ends_at, 'HH24:MI'),
                       'block2', to_char(p_block2_starts_at, 'HH24:MI') || '-' || to_char(p_block2_ends_at, 'HH24:MI'),
                       'shift_class', jsonb_build_object('old', cur.shift_class, 'new', 'split')));
  return jsonb_build_object('result', 'ok', 'shift_type_id', t_id);
end $function$;

revoke all on function public.institution_set_split_shift_type(p_institution_id uuid, p_code text, p_label text, p_block1_starts_at time without time zone, p_block1_ends_at time without time zone, p_block2_starts_at time without time zone, p_block2_ends_at time without time zone) from public, anon, authenticated, service_role;
grant execute on function public.institution_set_split_shift_type(p_institution_id uuid, p_code text, p_label text, p_block1_starts_at time without time zone, p_block1_ends_at time without time zone, p_block2_starts_at time without time zone, p_block2_ends_at time without time zone) to authenticated;
grant execute on function public.institution_set_split_shift_type(p_institution_id uuid, p_code text, p_label text, p_block1_starts_at time without time zone, p_block1_ends_at time without time zone, p_block2_starts_at time without time zone, p_block2_ends_at time without time zone) to service_role;

-- public.institution_set_work_days_per_week: canonical source (STAB-1). Generated by scripts/fn-source.mjs from the database; edit THIS file and
-- ship the whole file in a new migration (node scripts/fn-source.mjs migration public.institution_set_work_days_per_week). No text patch.

-- public.institution_set_work_days_per_week(p_institution_id uuid, p_work_days_per_week integer)
CREATE OR REPLACE FUNCTION public.institution_set_work_days_per_week(p_institution_id uuid, p_work_days_per_week integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  h public.institutions;
begin
  perform private.assert_access_open();  -- LEAVE1-3
  -- HD-3s S5 (founder FE-127 (3)): «Arbeitstage pro Woche» of the home, for the daily target hint only (weekly target
  -- hours / working days); never a block. The lead only, as institution_set_planning_limits.
  if p_institution_id is null or not private.is_institution_member(p_institution_id, array['lead']) then
    return jsonb_build_object('result', 'rejected');
  end if;
  -- 1-7 is an input check (days of a week), not a working-time rule.
  if p_work_days_per_week is null or p_work_days_per_week < 1 or p_work_days_per_week > 7 then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('work_days_per_week_not_valid'));
  end if;
  select * into h from public.institutions where id = p_institution_id for update;
  if h.id is null then
    return jsonb_build_object('result', 'rejected');
  end if;
  update public.institutions set work_days_per_week = p_work_days_per_week where id = h.id;
  perform private.institution_audit(h.id, 'institution_set_work_days_per_week', 'institutions', h.id,
    jsonb_build_object('work_days_per_week', jsonb_build_object('old', h.work_days_per_week, 'new', p_work_days_per_week)));
  return jsonb_build_object('result', 'ok');
end $function$;

revoke all on function public.institution_set_work_days_per_week(p_institution_id uuid, p_work_days_per_week integer) from public, anon, authenticated, service_role;
grant execute on function public.institution_set_work_days_per_week(p_institution_id uuid, p_work_days_per_week integer) to authenticated;
grant execute on function public.institution_set_work_days_per_week(p_institution_id uuid, p_work_days_per_week integer) to service_role;

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
      -- HD-3a: the home's planning inputs (FE-119, FE-123), read by the draft and the screen.
      'min_rest_hours', inst.min_rest_hours, 'max_consecutive_days', inst.max_consecutive_days,
      'weekly_target_hours', inst.weekly_target_hours,
      -- HD-3s S5: «Arbeitstage pro Woche» for the daily target hint (never a block).
      'work_days_per_week', inst.work_days_per_week,
      'can_order', exists (select 1 from public.client_accounts ca
                           where ca.institution_id = inst.id and private.is_client_member(ca.id))),
    'from', p_from, 'to', p_to,
    'stations', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.sort, s.name)
                          from public.institution_stations s where s.institution_id = inst.id), '[]'::jsonb),
    'shift_types', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'code', t.code, 'label', t.label,
                                     'starts_at', to_char(t.starts_at, 'HH24:MI'), 'ends_at', to_char(t.ends_at, 'HH24:MI'),
                                     'shift_class', t.shift_class,
                                     -- HD-3s: a split shift is block 1 starts_at..block1_ends_at, block 2
                                     -- block2_starts_at..ends_at; NULL for a shift with one block.
                                     'block1_ends_at', to_char(t.block1_ends_at, 'HH24:MI'),
                                     'block2_starts_at', to_char(t.block2_starts_at, 'HH24:MI'))
                                   order by t.sort, t.starts_at)
                             from public.institution_shift_types t where t.institution_id = inst.id), '[]'::jsonb),
    'staff', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'display_name', p.display_name, 'grade', p.grade,
                               'home_station_id', p.home_station_id, 'active', p.active,
                               'pensum_pct', p.pensum_pct, 'shift_model', p.shift_model) order by p.display_name, p.id)
                       from public.institution_staff p where p.institution_id = inst.id), '[]'::jsonb),
    'absences', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'staff_id', a.staff_id,
                                  'starts_on', a.starts_on, 'ends_on', a.ends_on) order by a.starts_on, a.id)
                          from public.institution_absences a
                          where a.institution_id = inst.id and a.starts_on <= p_to and a.ends_on >= p_from), '[]'::jsonb),
    -- HD-3a wishes (FE-125): read like the other person data of the home; the draft uses them as an order only.
    'wishes', coalesce((select jsonb_agg(jsonb_build_object('staff_id', w.staff_id, 'weekday', w.weekday, 'kind', w.kind,
                                'shift_type_id', w.shift_type_id) order by w.staff_id, w.weekday, w.kind, w.shift_type_id)
                        from public.institution_staff_wishes w where w.institution_id = inst.id), '[]'::jsonb),
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
                                              'grade', p.grade, 'absent', ab.absent, 'inactive', not p.active,
                                              -- HD-3a Q3: the rules this shift breaks now (one reading with the
                                              -- command) and those confirmed by hand when it was saved.
                                              'rules', to_jsonb(private.institution_rule_breaches(p.id, t.id, d.d::date, ia.id)),
                                              'override_rules', to_jsonb(ia.override_rules))
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
  -- HD-3s (fail closed): an order has one start and one end time; a split shift has two blocks, so the order would ask
  -- for the whole day including the pause. Not orderable until a package builds orders with two blocks (HD-3s-F2).
  if t.shift_class = 'split' then
    return jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('split_shift_not_orderable'));
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
  -- HD-3s (fail closed, as institution_prepare_gap_order): no order for a split shift (two blocks, one order time).
  if t.shift_class = 'split' then
    return jsonb_build_object('problems', jsonb_build_array('split_shift_not_orderable'));
  end if;
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
