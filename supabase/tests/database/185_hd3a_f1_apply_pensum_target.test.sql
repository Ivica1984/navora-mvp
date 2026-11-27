-- HD-3a-F1 (brief docs/agents/briefs/HD-3a-F1.md, issue #1745): «übernehmen» checks Pensum and Wochensoll in the
-- database, fail closed. The red cases of probe #1794 (363e50dd) are taken over and must be green after migration 0186.
--   1. control: Pensum and Wochensoll entered -> the row is saved;
--   2. Pensum emptied after the draft was shown -> that row refused `pensum_missing`, the other person's row saved;
--   3. Wochensoll emptied -> the whole call `invalid` / `weekly_target_missing`: no row, no run record, no audit event;
--   4. a retry with the apply id of a call that saved rows answers `already_applied`, even after the target was emptied;
--   5. a lowered (not emptied) Pensum is checked on the current value: R-h refuses the row as `planning_rule`;
--   6. catalogue: the function still locks the home `for share` and keeps its guards (with pgTAP 157 and 175);
--   7. R-7-2 read-back public.institution_draft_run_refusals (migration 0187): the lead reads the refused row with
--      `pensum_missing`, a planner of the home too; a viewer, a non-member, a lead whose access ended (LEAVE1-3, through
--      the membership check), the lead of another home and anon cannot; a run of another home is not_found.
-- Kept guards (membership, other home, planner, LEAVE1-3, anon, idempotency, cell locks, rest time, days in a row, shift
-- model, absence, double booking) are proven by 175, 176, 177 and 182 against the same, re-created function.
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(25);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a185-0000000000' || n)::uuid $$;
create function pg_temp.d(n int) returns date language sql as $$ select (private.at_zurich(private.now()))::date + 200 + n $$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
insert into ids select k, (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'HD3aF1t ' || k, 'fage_efz')) ->> 'staff_id')::uuid
  from (values ('p'), ('q'), ('r'), ('s')) v(k);
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'HD3aF1t Station')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'FF', 'HD3aF1t Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids values ('a1', pg_temp.u('a1')), ('a2', pg_temp.u('a2')), ('a3', pg_temp.u('a3')), ('a4', pg_temp.u('a4')), ('a5', pg_temp.u('a5'));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L, %L::jsonb)', pg_temp.id('f'), 'early', pg_temp.exp_class(pg_temp.id('f'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L, %L::jsonb)', pg_temp.id(k), 'any', pg_temp.exp_staff(pg_temp.id(k))))
  from (values ('p'), ('q'), ('r'), ('s')) v(k);
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 4, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f')));

create function pg_temp.dr(person text, n int) returns jsonb language sql as $$
  select jsonb_build_object('date', pg_temp.d(n)::text, 'station_id', pg_temp.id('st'),
                            'shift_type_id', pg_temp.id('f'), 'staff_id', pg_temp.id(person))
$$;
create function pg_temp.apply(k text, p_rows jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)',
    pg_temp.inst(), pg_temp.id(k), p_rows))
$$;
create function pg_temp.has(person text, n int) returns boolean language sql as $$
  select exists (select 1 from public.institution_assignments where staff_id = pg_temp.id(person)
                 and shift_type_id = pg_temp.id('f') and work_date = pg_temp.d(n))
$$;
create temp table res (k text primary key, v jsonb);
create function pg_temp.runs(k text) returns bigint language sql as $$
  select count(*) from public.institution_draft_runs where id = pg_temp.id(k)
$$;
create function pg_temp.audits(k text) returns bigint language sql as $$
  select count(*) from public.institution_audit_events where command = 'institution_apply_draft' and entity_id = pg_temp.id(k)
$$;

-- 1. Control ------------------------------------------------------------------------------------------------------------
insert into res values ('a1', pg_temp.apply('a1', jsonb_build_array(pg_temp.dr('p', 1))));
select is(pg_temp.id('p') is not null and pg_temp.id('st') is not null and pg_temp.id('f') is not null, true,
          'fixture: persons, station and shift type were created by the commands');
select is((select v ->> 'result' from res where k = 'a1') || '/' || (select v ->> 'applied' from res where k = 'a1')
          || '/' || pg_temp.has('p', 1)::text, 'ok/1/true',
          'control: with Pensum 100 and Wochensoll 42 the draft row is saved');

-- 2. Pensum emptied after the draft was shown -> that row only -----------------------------------------------------------
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, null, %L, %L::jsonb)', pg_temp.id('q'), 'any', pg_temp.exp_staff(pg_temp.id('q'))));
select is((select pensum_pct from public.institution_staff where id = pg_temp.id('q')), null::int,
          'fixture: Q has no Pensum now (set by the command)');
insert into res values ('a2', pg_temp.apply('a2', jsonb_build_array(pg_temp.dr('q', 3), pg_temp.dr('r', 3))));
select ok(not pg_temp.has('q', 3), 'a row of a person without Pensum is not saved by «übernehmen» (R-6-1, fail closed)');
select is((select x ->> 'reason' from res, jsonb_array_elements(v -> 'refused') x
           where k = 'a2' and x ->> 'staff_id' = pg_temp.id('q')::text), 'pensum_missing',
          'the refused row names the person and the code pensum_missing');
select is((select v ->> 'result' from res where k = 'a2') || '/' || (select v ->> 'applied' from res where k = 'a2')
          || '/' || pg_temp.has('r', 3)::text, 'ok/1/true',
          'the other person''s row in the same call is still saved (row logic, partial take-over)');
select is(jsonb_array_length((select v -> 'refused' from res where k = 'a2')), 1, 'exactly one row is refused');

-- 4 (prepared). A retry id whose first call saves rows while the target is set --------------------------------------------
insert into res values ('a4', pg_temp.apply('a4', jsonb_build_array(pg_temp.dr('s', 7))));
select is((select v ->> 'applied' from res where k = 'a4') || '/' || pg_temp.has('s', 7)::text, '1/true',
          'fixture: the first call of the retry id saves its row');

-- 3. Wochensoll emptied -> the whole call -------------------------------------------------------------------------------
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, null, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));
select is((select weekly_target_hours from public.institutions where id = pg_temp.inst()), null::numeric,
          'fixture: the home has no Wochensoll now (set by the command)');
insert into res values ('a3', pg_temp.apply('a3', jsonb_build_array(pg_temp.dr('r', 5), pg_temp.dr('s', 5))));
select is((select v from res where k = 'a3'),
          '{"result": "invalid", "problems": ["weekly_target_missing"]}'::jsonb,
          'without Wochensoll «übernehmen» refuses the whole call with weekly_target_missing');
select ok(not pg_temp.has('r', 5) and not pg_temp.has('s', 5), 'without Wochensoll no row at all is saved');
select is(pg_temp.runs('a3') + pg_temp.audits('a3'), 0::bigint,
          'the refused call leaves no run record and no audit event (as every invalid)');

-- 4. Retry after the target was emptied ---------------------------------------------------------------------------------
select is((pg_temp.apply('a4', jsonb_build_array(pg_temp.dr('s', 7)))) ->> 'result', 'already_applied',
          'a retry of a call that saved rows answers already_applied, not weekly_target_missing');
select is(pg_temp.audits('a4'), 1::bigint, 'the retry writes no second audit event');

-- 5. Lowered, not emptied: R-h on the current value -----------------------------------------------------------------------
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));
-- P has the shift of day 1 (8.5 h); Pensum 10 % of 42 h = 4.2 h per week: another shift in the same ISO week breaks R-h.
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 10, %L, %L::jsonb)', pg_temp.id('p'), 'any', pg_temp.exp_staff(pg_temp.id('p'))));
insert into res values ('a5', pg_temp.apply('a5', jsonb_build_array(pg_temp.dr('p', 2))));
select ok(not pg_temp.has('p', 2) and (select x ->> 'reason' from res, jsonb_array_elements(v -> 'refused') x
                                        where k = 'a5') = 'planning_rule',
          'a lowered Pensum is checked on the current value: the row is refused as planning_rule (R-h)');

-- 6. Catalogue ------------------------------------------------------------------------------------------------------------
select ok((select prosecdef and proconfig @> array['search_path=""']
           from pg_proc where oid = 'public.institution_apply_draft(uuid, uuid, jsonb)'::regprocedure),
          'institution_apply_draft stays security definer with an empty search_path');

-- 7. Read-back of the refused rows (R-7-2) ---------------------------------------------------------------------------
insert into auth.users (id, email) values (pg_temp.u('b1'), 'v.hd3af1@navora.test'), (pg_temp.u('b2'), 'l.hd3af1@navora.test'),
  (pg_temp.u('b3'), 'p.hd3af1@navora.test'), (pg_temp.u('b4'), 'e.hd3af1@navora.test'), (pg_temp.u('b5'), 'n.hd3af1@navora.test');
insert into public.institutions (id, display_name, kind, simulation) values
  (pg_temp.u('c1'), 'Testheim HD-3a-F1 (synthetisch)', 'home', true);
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.inst(), pg_temp.u('b1'), 'viewer'), (pg_temp.u('c1'), pg_temp.u('b2'), 'lead'),
  (pg_temp.inst(), pg_temp.u('b3'), 'planner'), (pg_temp.inst(), pg_temp.u('b4'), 'lead');
-- B4 is a lead of this home whose access ended (LEAVE1-3); the same events as 175.
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('b4'), 'nurse');
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('b4'), 'ended', 'employment_ended', pg_temp.u('b2'));
create function pg_temp.refusals(p_user text, p_inst uuid, k text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_draft_run_refusals(%L, %L)', p_inst, pg_temp.id(k)))
$$;
select is((select x from jsonb_array_elements(pg_temp.refusals(pg_temp.lead(), pg_temp.inst(), 'a2') -> 'refused') x),
          jsonb_build_object('staff_id', pg_temp.id('q')::text, 'date', pg_temp.d(3)::text,
                             'shift_type_id', pg_temp.id('f')::text, 'reason', 'pensum_missing'),
          'the lead reads back the refused row: person, day, shift type and pensum_missing');
select is((pg_temp.refusals(pg_temp.lead(), pg_temp.inst(), 'a2') ->> 'applied'), '1', 'and the saved count of the run');
select is((pg_temp.refusals(pg_temp.u('b1')::text, pg_temp.inst(), 'a2')), '{"result": "rejected"}'::jsonb,
          'a viewer of the home cannot read the run');
select is(jsonb_array_length(pg_temp.refusals(pg_temp.u('b3')::text, pg_temp.inst(), 'a2') -> 'refused'), 1,
          'a planner of the home reads the refused row too');
select is((pg_temp.refusals(pg_temp.u('b5')::text, pg_temp.inst(), 'a2')), '{"result": "rejected"}'::jsonb,
          'a signed-in user without membership cannot read the run');
select is((pg_temp.refusals(pg_temp.u('b4')::text, pg_temp.inst(), 'a2')), '{"result": "rejected"}'::jsonb,
          'a lead of the home whose access ended cannot read the run (LEAVE1-3 through the membership check)');
select is((pg_temp.refusals(pg_temp.u('b2')::text, pg_temp.u('c1'), 'a2')), '{"result": "not_found"}'::jsonb,
          'the lead of another home asking for this run under her own home gets not_found (nothing of it)');
select is((pg_temp.refusals(pg_temp.u('b2')::text, pg_temp.inst(), 'a2')), '{"result": "rejected"}'::jsonb,
          'the lead of another home cannot read this home''s run');
select ok(not has_function_privilege('anon', 'public.institution_draft_run_refusals(uuid, uuid)', 'execute')
          and (select prosecdef and proconfig @> array['search_path=""'] from pg_proc
               where oid = 'public.institution_draft_run_refusals(uuid, uuid)'::regprocedure),
          'anon has no execute; the reader is security definer with an empty search_path');

select * from finish();
rollback;
