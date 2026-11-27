-- HD-3a slice 3c (migration 0177; review of PR #1729, 2026-11-25 07:15, finding R-3b-1): «Entwurf übernehmen» takes a
-- cell lock only for a cell of its own home, and one call spans at most 31 days.
--   * a row with a shift type of another home takes no advisory lock (before 0177 it took one per distinct cell, up to
--     2000 per call, in the shared lock table) and is refused as not_found;
--   * rows spanning more than 31 days are refused as a whole («period_too_long»): no lock, no run record, no row;
--   * exactly 31 days is accepted (one calendar month, the longest period the screen offers);
--   * guards kept: security definer, empty search_path, LEAVE1-3, membership, role re-check, audit, one overload, grants
--     (also pgTAP 157, 176).
-- Fixed, checkable rules; no AI. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

-- HD-3a-F1 R-6-2 (b), migration 0188: the planning commands take the values the form showed (`p_expected`). These
-- helpers read the current values as the test owner (authenticated cannot read the tables), so each call below states
-- «what the screen showed» = the current row; pgTAP 186 tests the refusal when they differ.
create function pg_temp.exp_limits(i uuid) returns jsonb language sql as $exp$
  select jsonb_build_object('min_rest_hours', h.min_rest_hours, 'max_consecutive_days', h.max_consecutive_days,
                            'weekly_target_hours', h.weekly_target_hours) from public.institutions h where h.id = i $exp$;
create function pg_temp.exp_staff(s uuid) returns jsonb language sql as $exp$
  select jsonb_build_object('pensum_pct', p.pensum_pct, 'shift_model', p.shift_model)
  from public.institution_staff p where p.id = s $exp$;
create function pg_temp.exp_class(t uuid) returns jsonb language sql as $exp$
  select jsonb_build_object('shift_class', x.shift_class) from public.institution_shift_types x where x.id = t $exp$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r;
exception when others then
  execute 'reset role';
  perform pg_temp.as_owner();
  return jsonb_build_object('sqlstate', sqlstate);
end $$;
create function pg_temp.lead() returns text language sql as $$ select '00000000-0000-4000-a000-0000000009e8' $$;
create function pg_temp.inst() returns uuid language sql as $$ select '00000000-0000-4000-a000-0000000004c1'::uuid $$;
create function pg_temp.d(n int) returns date language sql as $$ select (private.at_zurich(private.now()))::date + 120 + n $$;
-- Exclusive advisory locks on one 64-bit key held by this backend (pg_advisory_xact_lock(bigint) → objsubid 1).
create function pg_temp.n_cell_locks() returns int language sql as $$
  select count(*)::int from pg_locks where locktype = 'advisory' and pid = pg_backend_pid() and objsubid = 1
    and mode = 'ExclusiveLock' and granted
$$;
create function pg_temp.src(fn text) returns text language sql as $$
  select prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname || '.' || p.proname = fn
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select 'x', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3a Bound Xenia', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3a Station Bound')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'BF', 'HD3a Bound Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids values ('a1', gen_random_uuid()), ('a2', gen_random_uuid()), ('a3', gen_random_uuid());
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L, %L::jsonb)', pg_temp.id('f'), 'early', pg_temp.exp_class(pg_temp.id('f'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L, %L::jsonb)', pg_temp.id('x'), 'any', pg_temp.exp_staff(pg_temp.id('x'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 1, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f')));
-- A shift type of another (synthetic) home.
insert into public.institutions (id, display_name, kind, simulation) values
  ('00000000-0000-4000-a177-000000000011', 'Testheim HD-3a Bound (synthetisch)', 'home', true);
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, ends_at, sort) values
  ('00000000-0000-4000-a177-0000000000b1', '00000000-0000-4000-a177-000000000011', 'FX', 'Fremder Dienst (synthetisch)',
   '07:00', '15:30', 1);

create function pg_temp.dr(n int, shift uuid default null) returns jsonb language sql as $$
  select jsonb_build_object('date', pg_temp.d(n)::text, 'station_id', pg_temp.id('st'),
                            'shift_type_id', coalesce(shift, pg_temp.id('f')), 'staff_id', pg_temp.id('x'))
$$;
create function pg_temp.apply(apply_key text, rows jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)', pg_temp.inst(),
                     pg_temp.id(apply_key), rows))
$$;

-- 1. A foreign shift type takes no lock (R-3b-1) --------------------------------------------------------------------------
select is(pg_temp.n_cell_locks(), 0, 'no cell lock before the first call');
-- 30 rows, one per day, all with the foreign shift type: before 0177 this took 30 advisory locks.
select is(pg_temp.apply('a1', (select jsonb_agg(pg_temp.dr(i, '00000000-0000-4000-a177-0000000000b1'::uuid))
                               from generate_series(0, 29) i)) ->> 'applied',
          '0', 'no row with a foreign shift type is saved');
select is(pg_temp.n_cell_locks(), 0, 'rows with a shift type of another home take no cell lock');
select is((select count(*)::int from public.institution_draft_runs r, jsonb_array_elements(r.refused) e
            where r.id = pg_temp.id('a1') and e ->> 'reason' = 'not_found'),
          30, 'each such row is refused as not_found and recorded');

-- 2. More than 31 days in one call ---------------------------------------------------------------------------------------
select is(pg_temp.apply('a2', jsonb_build_array(pg_temp.dr(0), pg_temp.dr(31))),
          jsonb_build_object('result', 'invalid', 'problems', jsonb_build_array('period_too_long')),
          'rows spanning 32 days are refused as a whole: «period_too_long»');
select is(pg_temp.n_cell_locks(), 0, 'the refused call took no cell lock');
select is((select count(*)::int from public.institution_draft_runs where id = pg_temp.id('a2')), 0,
          'the refused call leaves no run record');
select is((select count(*)::int from public.institution_assignments where staff_id = pg_temp.id('x')), 0,
          'the refused call saves no row');

-- 3. Exactly 31 days is one calendar month: accepted, one lock per cell of the home -------------------------------------
select is(pg_temp.apply('a3', jsonb_build_array(pg_temp.dr(0), pg_temp.dr(30),
                                                pg_temp.dr(15, '00000000-0000-4000-a177-0000000000b1'::uuid))) ->> 'applied',
          '2', 'rows spanning 31 days are accepted; the two rows of the home are saved');
select is(pg_temp.n_cell_locks(), 2, 'one lock per cell of the home, none for the foreign shift type');

-- 4. Source and guards --------------------------------------------------------------------------------------------------
select ok(pg_temp.src('public.institution_apply_draft') ~
            'join public\.institution_shift_types t\s+on t\.id = \(e ->> ''shift_type_id''\)::uuid and t\.institution_id = p_institution_id',
          'the cell-lock loop joins the shift types of this home');
select ok(position('period_too_long' in pg_temp.src('public.institution_apply_draft'))
          < position('insert into public.institution_draft_runs' in pg_temp.src('public.institution_apply_draft')),
          'the period bound is checked before the run record');
select ok((select prosecdef and proconfig = array['search_path=""'] from pg_proc
            where oid = 'public.institution_apply_draft(uuid, uuid, jsonb)'::regprocedure),
          'apply_draft stays security definer with an empty search_path');
select ok(pg_temp.src('public.institution_apply_draft') like '%private.assert_access_open()%'
          and pg_temp.src('public.institution_apply_draft') like '%private.institution_audit(%'
          and (select count(*) from regexp_matches(pg_temp.src('public.institution_apply_draft'),
                                                   'private\.is_institution_member\(p_institution_id', 'g')) = 2,
          'apply_draft keeps LEAVE1-3, audit and both membership checks');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'institution_apply_draft'), 1, 'one overload only');
select ok(not has_function_privilege('anon', 'public.institution_apply_draft(uuid, uuid, jsonb)', 'execute')
          and has_function_privilege('authenticated', 'public.institution_apply_draft(uuid, uuid, jsonb)', 'execute'),
          'grants unchanged: authenticated may call it, anon may not');

select * from finish();
rollback;
