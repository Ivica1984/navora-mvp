-- HD-3a slice 3 follow-up (migration 0176; review of PR #1729, 2026-11-25 04:25, findings 1 and 4): one cell lock for
-- «Entwurf übernehmen» and the external gap order.
--   * private.institution_cell_lock is the one key source; it is no app entry point (no execute for app roles);
--   * institution_prepare_gap_order and institution_apply_draft take the SAME advisory lock for the same cell (proved on
--     pg_locks: the apply adds no second lock for a cell prepare already holds, and one lock per further cell of its
--     own home; a row of another home's station takes no lock);
--   * the apply checks the role again after the person locks, before the run record (catalogue order);
--   * guards kept: security definer, empty search_path, LEAVE1-3, membership, audit, grants (also pgTAP 157).
-- The parallel interleavings themselves (two sessions) are concurrency cases G and H in
-- scripts/db-concurrency/home-plan-assign.sh. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

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
  pg_temp.inst(), 'HD3a Lock Xaver', 'fage_efz')) ->> 'staff_id')::uuid;
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3a Station Lock')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'LF', 'HD3a Lock Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids values ('a1', gen_random_uuid()), ('a2', gen_random_uuid());
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L)', pg_temp.id('f'), 'early'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L)', pg_temp.id('x'), 'any'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42)', pg_temp.inst()));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 1, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f')));
-- A station of another home (the seed's second institution is not needed: a fresh synthetic one).
insert into public.institutions (id, display_name, kind, simulation) values
  ('00000000-0000-4000-a176-000000000011', 'Testheim HD-3a Lock (synthetisch)', 'home', true);
insert into public.institution_stations (id, institution_id, name, sort) values
  ('00000000-0000-4000-a176-0000000000a1', '00000000-0000-4000-a176-000000000011', 'Fremde Station (synthetisch)', 1);

create function pg_temp.dr(n int, station uuid default null) returns jsonb language sql as $$
  select jsonb_build_object('date', pg_temp.d(n)::text, 'station_id', coalesce(station, pg_temp.id('st')),
                            'shift_type_id', pg_temp.id('f'), 'staff_id', pg_temp.id('x'))
$$;

-- 1. The helper --------------------------------------------------------------------------------------------------------
select has_function('private', 'institution_cell_lock', array['uuid', 'uuid', 'date'], 'one cell-lock helper');
select ok(not (select prosecdef from pg_proc where oid = 'private.institution_cell_lock(uuid, uuid, date)'::regprocedure),
          'the helper is not security definer (it only takes a lock)');
select ok(not has_function_privilege('authenticated', 'private.institution_cell_lock(uuid, uuid, date)', 'execute')
          and not has_function_privilege('anon', 'private.institution_cell_lock(uuid, uuid, date)', 'execute'),
          'no app role may call the helper');
select ok(pg_temp.src('private.institution_cell_lock') like '%to_char(p_work_date, ''YYYY-MM-DD'')%',
          'the key does not depend on the session DateStyle');

-- 2. Both commands use it, and no command keeps its own copy of the key -------------------------------------------------
select ok(pg_temp.src('public.institution_prepare_gap_order') like '%private.institution_cell_lock(p_station_id, p_shift_type_id, p_work_date)%',
          'prepare_gap_order takes the cell lock of the helper');
select ok(pg_temp.src('public.institution_apply_draft') like '%private.institution_cell_lock(c.station_id, c.shift_type_id, c.work_date)%',
          'apply_draft takes the cell lock of the helper');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname in ('public', 'private') and p.prosrc like '%''institution_gap:''%'),
          1, 'the key text «institution_gap:» exists in one function only (the helper)');

-- 3. Same key on pg_locks (one session: an advisory lock already held is not counted twice) ------------------------------
select is(pg_temp.n_cell_locks(), 0, 'no cell lock before the first command');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_prepare_gap_order(%L, %L, %L, %L)', pg_temp.inst(),
            pg_temp.id('st'), pg_temp.id('f'), pg_temp.d(1))) ->> 'result', 'ok', 'an order is prepared for the gap on day 1');
select is(pg_temp.n_cell_locks(), 1, 'prepare holds one cell lock');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)', pg_temp.inst(),
            pg_temp.id('a1'), jsonb_build_array(pg_temp.dr(1)))) -> 'refused' -> 0 ->> 'reason',
          'cell_has_order', 'a draft row into the ordered cell is refused');
select is(pg_temp.n_cell_locks(), 1, 'the apply took the same lock as prepare for that cell (no second key)');
select is(pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)', pg_temp.inst(),
            pg_temp.id('a2'), jsonb_build_array(pg_temp.dr(3), pg_temp.dr(5),
                                                pg_temp.dr(7, '00000000-0000-4000-a176-0000000000a1'::uuid)))) ->> 'applied',
          '2', 'two rows of the home are saved, the row of a foreign station is refused');
select is(pg_temp.n_cell_locks(), 3, 'one more lock per cell of the home; none for the foreign station');

-- 4. Role re-check after the person locks, before the run record (finding 4) ---------------------------------------------
select ok(position('is_institution_member' in substr(pg_temp.src('public.institution_apply_draft'),
                    position('for update' in pg_temp.src('public.institution_apply_draft'))))
          < position('insert into public.institution_draft_runs' in substr(pg_temp.src('public.institution_apply_draft'),
                    position('for update' in pg_temp.src('public.institution_apply_draft'))))
          and position('is_institution_member' in substr(pg_temp.src('public.institution_apply_draft'),
                    position('for update' in pg_temp.src('public.institution_apply_draft')))) > 0,
          'the role is checked again between the person locks and the run record');

-- 5. Guards kept --------------------------------------------------------------------------------------------------------
select ok(pg_temp.src('public.institution_prepare_gap_order') like '%private.assert_access_open()%'
          and pg_temp.src('public.institution_prepare_gap_order') like '%is_institution_member%'
          and pg_temp.src('public.institution_prepare_gap_order') like '%private.institution_audit(%',
          'prepare_gap_order keeps LEAVE1-3, membership and audit');
select ok(pg_temp.src('public.institution_apply_draft') like '%private.assert_access_open()%'
          and pg_temp.src('public.institution_apply_draft') like '%private.institution_audit(%',
          'apply_draft keeps LEAVE1-3 and audit');
select ok(not has_function_privilege('anon', 'public.institution_prepare_gap_order(uuid, uuid, uuid, date)', 'execute')
          and has_function_privilege('authenticated', 'public.institution_prepare_gap_order(uuid, uuid, uuid, date)', 'execute')
          and not has_function_privilege('anon', 'public.institution_apply_draft(uuid, uuid, jsonb)', 'execute')
          and has_function_privilege('authenticated', 'public.institution_apply_draft(uuid, uuid, jsonb)', 'execute'),
          'grants unchanged: authenticated may call both commands, anon neither');

select * from finish();
rollback;
