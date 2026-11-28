-- PROBE (do not merge): HD-PEN-HAND (eng proposal, PO decision ENG-PH1 «yes», 2026-11-28 01:39). Red reproduction on
-- recovery/main: a HAND assignment (public.institution_assign_staff) of a person without Pensum, or in a home without
-- Wochensoll, is saved at once, without the hours check and without any warning (fail open). «übernehmen» refuses the
-- same person since HD-3a-F1 (pgTAP 185), so the hand path is the remaining silent path.
-- Expected behaviour (PLANNED, wording and code name by `cra`; `hours_unknown` is a placeholder of this probe):
--   the first call answers `warning` with the rule named and writes nothing; a call that confirms it saves the shift
--   with the rule in override_rules (as for pensum_full); a person with Pensum in a home with Wochensoll is unchanged.
-- Cases with a monthly target (HD-3a-F3, not merged when this probe was written) are added after its merge:
--   a target for the month of the shift → no hours_unknown (R-m checks the hours).
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

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
create function pg_temp.d(n int) returns date language sql as $$ select (private.at_zurich(private.now()))::date + 230 + n $$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select k, (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'PenHand ' || k, 'fage_efz')) ->> 'staff_id')::uuid
  from (values ('p'), ('q')) v(k);
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'PenHand Station')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'PH', 'PenHand Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L, %L::jsonb)', pg_temp.id('f'), 'early', pg_temp.exp_class(pg_temp.id('f'))));
-- P: no Pensum (as added). Q: Pensum 100, shift model any.
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L, %L::jsonb)', pg_temp.id('q'), 'any', pg_temp.exp_staff(pg_temp.id('q'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, null, %L, %L::jsonb)', pg_temp.id('p'), 'any', pg_temp.exp_staff(pg_temp.id('p'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));

create function pg_temp.assign(person text, n int, confirm text[]) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L, %L::text[])',
    pg_temp.inst(), pg_temp.id('st'), pg_temp.id('f'), pg_temp.d(n), pg_temp.id(person), confirm))
$$;
create function pg_temp.has(person text, n int) returns boolean language sql as $$
  select exists (select 1 from public.institution_assignments where staff_id = pg_temp.id(person)
                 and shift_type_id = pg_temp.id('f') and work_date = pg_temp.d(n))
$$;
create temp table res (k text primary key, v jsonb);

select is((select pensum_pct from public.institution_staff where id = pg_temp.id('p')), null::int,
          'fixture: P has no Pensum, the home has Wochensoll 42');

-- 1. Person without Pensum, by hand, no confirmation ----------------------------------------------------------------
insert into res values ('p1', pg_temp.assign('p', 1, null));
select is((select v ->> 'result' from res where k = 'p1'), 'warning',
          'RED today: hand assignment of a person without Pensum answers a warning (today: ok, saved silently)');
select ok(not pg_temp.has('p', 1), 'RED today: nothing is saved before the warning is confirmed');
select ok(coalesce((select v -> 'rules' from res where k = 'p1') ? 'hours_unknown', false),
          'RED today: the warning names the rule (placeholder code hours_unknown, wording cra)');

-- 2. Confirmed by hand -> saved, the rule kept in override_rules (auditable, as for pensum_full) ----------------------
insert into res values ('p2', pg_temp.assign('p', 3, array['hours_unknown']));
select is((select v ->> 'result' from res where k = 'p2') || '/' ||
          coalesce((select array_to_string(override_rules, ',') from public.institution_assignments
                    where staff_id = pg_temp.id('p') and work_date = pg_temp.d(3)), '-'),
          'ok/hours_unknown', 'RED today: the confirmed shift is saved with override_rules {hours_unknown}');

-- 3. Control: Pensum 100 and Wochensoll 42 -> unchanged, no warning (green today and after) ---------------------------
insert into res values ('q1', pg_temp.assign('q', 1, null));
select is((select v ->> 'result' from res where k = 'q1') || '/' || pg_temp.has('q', 1)::text, 'ok/true',
          'control: a person with Pensum in a home with Wochensoll is saved without a warning');

-- 4. Home without Wochensoll, person with Pensum -> the same warning -----------------------------------------------
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, null, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), null::numeric,
          'fixture: the home has no Wochensoll now (set by the command)');
insert into res values ('q2', pg_temp.assign('q', 9, null));
select is((select v ->> 'result' from res where k = 'q2') || '/' || pg_temp.has('q', 9)::text, 'warning/false',
          'RED today: in a home without Wochensoll the hand assignment warns and saves nothing');

select * from finish();
rollback;
