-- HD-PEN-HAND (brief docs/agents/briefs/HD-PEN-HAND.md, PO decision ENG-PH1 2026-11-28; ADR-232; migration 0190).
-- «Stunden nicht prüfbar»: a HAND assignment (public.institution_assign_staff) of a person without Pensum and without a
-- monthly target for the month of the shift, or in a home without Wochensoll, was saved at once without the hours check
-- (probe #1858, red on recovery/main 1e1716ed). Now the one rule source private.institution_rule_breaches answers
-- `hours_unknown` in its last slot (never together with month_target_full or pensum_full) and the existing
-- warning/confirm loop applies: first call `warning`, nothing written; confirmed call saved with override_rules and audit.
-- Also: the plan marks stored shifts (confirmed and backlog), R-m still binds with a target (also in an ISO week across
-- a month end), «übernehmen» keeps its refusal codes, a confirmation given before a change of Pensum never saves a rule
-- that appeared since. The two-session race is case L of scripts/db-concurrency/home-plan-assign.sh (`db` job).
-- Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

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
-- M: a calendar month far from the seed and the other tests (from today + 290 days) whose last day is not a Sunday, so
-- the last day of M and the first day of M+1 lie in one ISO week (case 6).
create function pg_temp.m() returns date language sql as $$
  select min(x.m)::date from generate_series(date_trunc('month', ((private.at_zurich(private.now()))::date + 290)::timestamp)
                                             + interval '1 month', date_trunc('month', ((private.at_zurich(private.now()))::date + 290)::timestamp)
                                             + interval '3 months', interval '1 month') x(m)
  where extract(isodow from (x.m + interval '1 month' - interval '1 day')) <> 7 $$;
create function pg_temp.md(n int) returns date language sql as $$ select pg_temp.m() + n $$;  -- day n+1 of M
create function pg_temp.mlast() returns date language sql as $$ select (pg_temp.m() + interval '1 month')::date - 1 $$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated;
create function pg_temp.id(k text) returns uuid language sql as $$ select v from ids where ids.k = $1 $$;
-- P, C, R, S: no Pensum (as added). Q: Pensum 100, shift model any.
insert into ids select k, (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_staff(%L, %L, %L, null)',
  pg_temp.inst(), 'PenHand ' || k, 'fage_efz')) ->> 'staff_id')::uuid
  from (values ('p'), ('q'), ('c'), ('r'), ('s')) v(k);
insert into ids select 'st', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_add_station(%L, %L)',
  pg_temp.inst(), 'PenHand Station')) ->> 'station_id')::uuid;
insert into ids select 'f', (pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_type(%L, %L, %L, %L, %L)',
  pg_temp.inst(), 'PH', 'PenHand Früh', '07:00', '15:30')) ->> 'shift_type_id')::uuid;
insert into ids values ('a1', '00000000-0000-4000-a188-0000000000a1'), ('a2', '00000000-0000-4000-a188-0000000000a2');
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_shift_class(%L, %L, %L::jsonb)', pg_temp.id('f'), 'early', pg_temp.exp_class(pg_temp.id('f'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, 100, %L, %L::jsonb)', pg_temp.id('q'), 'any', pg_temp.exp_staff(pg_temp.id('q'))));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, 42, %L::jsonb)', pg_temp.inst(), pg_temp.exp_limits(pg_temp.inst())));
select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staffing_rule(%L, %L, %L, 6, null, 0)', pg_temp.inst(),
  pg_temp.id('st'), pg_temp.id('f')));

create function pg_temp.fmin() returns int language sql as $$
  select private.institution_shift_minutes(pg_temp.m(), '07:00', '15:30', null, null)::int $$;
create function pg_temp.assign(person text, p_date date, confirm text[]) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_assign_staff(%L, %L, %L, %L, %L, %L::text[])',
    pg_temp.inst(), pg_temp.id('st'), pg_temp.id('f'), p_date, pg_temp.id(person), confirm))
$$;
create function pg_temp.has(person text, p_date date) returns boolean language sql as $$
  select exists (select 1 from public.institution_assignments where staff_id = pg_temp.id(person)
                 and shift_type_id = pg_temp.id('f') and work_date = p_date)
$$;
create function pg_temp.n_of(person text) returns bigint language sql as $$
  select count(*) from public.institution_assignments where staff_id = pg_temp.id(person) $$;
create function pg_temp.audits(person text) returns bigint language sql as $$
  select count(*) from public.institution_audit_events
  where command = 'institution_assign_staff' and changed ->> 'staff_id' = pg_temp.id(person)::text $$;
create function pg_temp.breaches(person text, p_date date) returns text[] language sql as $$
  select private.institution_rule_breaches(pg_temp.id(person), pg_temp.id('f'), p_date, null) $$;
create function pg_temp.pensum(person text, pct int) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_staff_planning(%L, %s, %L, %L::jsonb)',
    pg_temp.id(person), coalesce(pct::text, 'null'), 'any', pg_temp.exp_staff(pg_temp.id(person))))
$$;
create function pg_temp.target(person text, p_month date, p_minutes int) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_monthly_target(%L, %L, %s, %L::jsonb)',
    pg_temp.id(person), p_month, p_minutes,
    jsonb_build_object('target_minutes', (select target_minutes from public.institution_monthly_targets
                                          where staff_id = pg_temp.id(person) and period_month = p_month))))
$$;
create function pg_temp.wochensoll(hours text) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_set_planning_limits(%L, 11, 6, %s, %L::jsonb)',
    pg_temp.inst(), hours, pg_temp.exp_limits(pg_temp.inst())))
$$;
-- The assigned entry of a person on a day as institution_plan returns it (the lead's own read).
create function pg_temp.planned(person text, p_date date) returns jsonb language sql as $$
  select a from jsonb_array_elements(
    (pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), p_date, p_date)))
    -> 'cells') c
  cross join jsonb_array_elements(c -> 'assigned') a
  where a ->> 'staff_id' = pg_temp.id(person)::text
$$;
create temp table res (k text primary key, v jsonb);

select is((select pensum_pct from public.institution_staff where id = pg_temp.id('p')), null::int,
          'fixture: P has no Pensum and no monthly target, the home has Wochensoll 42');

-- 1. Hand path: warning first, nothing written ---------------------------------------------------------------------------
insert into res values ('p1', pg_temp.assign('p', pg_temp.md(1), null));
select is(res.v, '{"result": "warning", "rules": ["hours_unknown"]}'::jsonb,
          'a hand assignment of a person without Pensum and monthly target answers warning hours_unknown')
  from res where k = 'p1';
select ok(not pg_temp.has('p', pg_temp.md(1)), 'nothing is saved before the warning is confirmed');
select is(pg_temp.audits('p'), 0::bigint, 'no audit event for the unconfirmed call');

-- 2. «abbrechen» = no second call: still nothing saved; a confirmation of a different rule does not save either ---------
select is(pg_temp.assign('p', pg_temp.md(1), array['rest']) ->> 'result', 'warning',
          'negative: confirming another rule than hours_unknown saves nothing');
select is(pg_temp.n_of('p'), 0::bigint, 'after the cancelled warning P has no shift');

-- 3. Confirmed: saved with override_rules and audit --------------------------------------------------------------------
insert into res values ('p2', pg_temp.assign('p', pg_temp.md(3), array['hours_unknown']));
select is((select v ->> 'result' from res where k = 'p2') || '/' ||
          coalesce((select array_to_string(override_rules, ',') from public.institution_assignments
                    where staff_id = pg_temp.id('p') and work_date = pg_temp.md(3)), '-'),
          'ok/hours_unknown', 'the confirmed shift is saved with override_rules {hours_unknown}');
select isnt((select override_by from public.institution_assignments where staff_id = pg_temp.id('p') and work_date = pg_temp.md(3)),
            null::uuid, 'the confirming person is recorded (override_by)');
select is((select changed -> 'override_rules' from public.institution_audit_events
           where command = 'institution_assign_staff' and entity_id = (select (v ->> 'assignment_id')::uuid from res where k = 'p2')),
          '["hours_unknown"]'::jsonb, 'the audit event of the confirmed shift carries hours_unknown');

-- 4. Control: Pensum 100 and Wochensoll 42 unchanged --------------------------------------------------------------------
insert into res values ('q1', pg_temp.assign('q', pg_temp.md(1), null));
select is((select v ->> 'result' from res where k = 'q1') || '/' || pg_temp.has('q', pg_temp.md(1))::text, 'ok/true',
          'control: a person with Pensum in a home with Wochensoll is saved without a warning');
select is((select override_rules from public.institution_assignments where staff_id = pg_temp.id('q') and work_date = pg_temp.md(1)),
          null::text[], 'control: no override_rules on the control shift');

-- 5. Plan view: the mark on stored shifts, confirmed and backlog ---------------------------------------------------------
select is(pg_temp.planned('p', pg_temp.md(3)) -> 'rules', '["hours_unknown"]'::jsonb, 'plan: the confirmed shift names hours_unknown');
select is(pg_temp.planned('p', pg_temp.md(3)) -> 'override_rules', '["hours_unknown"]'::jsonb, 'plan: … and that it was confirmed by hand');
-- Backlog: a shift stored before 0190 had no check (inserted directly, as the old function saved it).
insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id)
  values (pg_temp.inst(), pg_temp.id('st'), pg_temp.id('f'), pg_temp.md(5), pg_temp.id('p'));
select is((pg_temp.planned('p', pg_temp.md(5)) -> 'rules') || jsonb_build_array(pg_temp.planned('p', pg_temp.md(5)) -> 'override_rules'),
          '["hours_unknown", null]'::jsonb, 'plan: a backlog shift saved silently shows hours_unknown unconfirmed');
select is(pg_temp.planned('q', pg_temp.md(1)) -> 'rules', '[]'::jsonb, 'plan: the control shift has no rule');

-- 6. Monthly target: R-m binds, never hours_unknown; ISO week across the month end --------------------------------------
select is(pg_temp.target('r', pg_temp.m(), pg_temp.fmin()), '{"result": "ok"}'::jsonb, 'fixture: R gets a monthly target of one shift for M');
select is(pg_temp.breaches('r', pg_temp.md(8)), '{}'::text[], 'R with a target for the month of the shift: no hours_unknown');
select pg_temp.assign('r', pg_temp.md(8), null);
select is(pg_temp.breaches('r', pg_temp.md(10)), '{month_target_full}'::text[], 'R over its target: R-m binds (month_target_full, not hours_unknown)');
select is(pg_temp.target('s', pg_temp.m(), 20 * pg_temp.fmin()), '{"result": "ok"}'::jsonb, 'fixture: S gets a target for M only');
select is(pg_temp.mlast() - (extract(isodow from pg_temp.mlast())::int - 1), (pg_temp.mlast() + 1) - (extract(isodow from pg_temp.mlast() + 1)::int - 1),
          'fixture: the last day of M and the first day of M+1 lie in one ISO week');
select is(pg_temp.breaches('s', pg_temp.mlast()) || pg_temp.breaches('s', pg_temp.mlast() + 1), '{hours_unknown}'::text[],
          'one ISO week, target only in M: hours_unknown only for the shift in M+1 (the month without target)');

-- 7. Home without Wochensoll ---------------------------------------------------------------------------------------------
select is(pg_temp.wochensoll('null'), '{"result": "ok"}'::jsonb, 'fixture: the lead empties the Wochensoll');
insert into res values ('q2', pg_temp.assign('q', pg_temp.md(12), null));
select is((select v from res where k = 'q2') || jsonb_build_object('saved', pg_temp.has('q', pg_temp.md(12))),
          '{"result": "warning", "rules": ["hours_unknown"], "saved": false}'::jsonb,
          'a person with Pensum in a home without Wochensoll: warning hours_unknown, nothing saved');
select is(pg_temp.breaches('s', pg_temp.md(12)), '{}'::text[], 'without Wochensoll a person with a target for the month is checked by R-m');

-- 8. «übernehmen» keeps its refusal codes (no row becomes hours_unknown) -------------------------------------------------
create function pg_temp.dr(person text, p_date date) returns jsonb language sql as $$
  select jsonb_build_object('date', p_date::text, 'station_id', pg_temp.id('st'), 'shift_type_id', pg_temp.id('f'),
                            'staff_id', pg_temp.id(person))
$$;
create function pg_temp.apply(k text, p_rows jsonb) returns jsonb language sql as $$
  select pg_temp.cmd(pg_temp.lead(), format('select public.institution_apply_draft(%L, %L, %L::jsonb)',
    pg_temp.inst(), pg_temp.id(k), p_rows))
$$;
select is(pg_temp.apply('a1', jsonb_build_array(pg_temp.dr('q', pg_temp.md(14)))),
          '{"result": "invalid", "problems": ["weekly_target_missing"]}'::jsonb,
          '«übernehmen» without Wochensoll: the whole call is still refused with weekly_target_missing');
select pg_temp.wochensoll('42');
select is((select jsonb_agg(x ->> 'reason') from jsonb_array_elements(pg_temp.apply('a2', jsonb_build_array(pg_temp.dr('p', pg_temp.md(14)))) -> 'refused') x),
          '["pensum_missing"]'::jsonb, '«übernehmen» of a person without Pensum and target: still pensum_missing, never hours_unknown');

-- 9. A confirmation given before a change never saves a rule that appeared since (one session; two sessions: case L) --
select pg_temp.assign('c', pg_temp.md(16), null);
select pg_temp.pensum('c', 10);   -- 10 % of 42 h = 252 minutes per week: one early shift (510) breaks R-h
select is(pg_temp.assign('c', pg_temp.md(16), array['hours_unknown']) || jsonb_build_object('saved', pg_temp.has('c', pg_temp.md(16))),
          '{"result": "warning", "rules": ["pensum_full"], "saved": false}'::jsonb,
          'Pensum entered between warning and confirmation: recomputed, pensum_full is new and unconfirmed, nothing saved');
select pg_temp.pensum('c', null);
select is(pg_temp.assign('c', pg_temp.md(16), array['pensum_full']) || jsonb_build_object('saved', pg_temp.has('c', pg_temp.md(16))),
          '{"result": "warning", "rules": ["hours_unknown"], "saved": false}'::jsonb,
          'Pensum removed between warning and confirmation: hours_unknown unconfirmed, nothing saved');

-- 10. Kept properties of the rule source ---------------------------------------------------------------------------------
select is((select provolatile::text || '/' || prosecdef::text || '/' || array_to_string(proconfig, ',') from pg_proc
           where oid = 'private.institution_rule_breaches(uuid, uuid, date, uuid)'::regprocedure),
          's/false/search_path=""', 'rule source: STABLE, security invoker, empty search_path (unchanged)');
select ok(not has_function_privilege('authenticated', 'private.institution_rule_breaches(uuid, uuid, date, uuid)', 'execute')
          and not has_function_privilege('anon', 'private.institution_rule_breaches(uuid, uuid, date, uuid)', 'execute'),
          'rule source: no execute for anon or authenticated (revoke unchanged)');

select * from finish();
rollback;
