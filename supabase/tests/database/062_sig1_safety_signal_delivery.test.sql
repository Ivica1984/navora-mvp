-- SIG1: safety signals reach a person (migration 0060, ADR-074). Brief `docs/agents/briefs/SIG1.md`.
-- Users: coach …901 (org A, no team) · nurse …902 and care assistant …906 (org A, Testteam Nord …101) ·
-- operations …904 · admin …905 (org A …011) · admin …903 (org B …012, no Operations user). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(54);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a6200000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a6200000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
-- A planned visit whose planned start is p_ago before now (Zurich wall time), case 208.
create function pg_temp.visit(p_n integer, p_team text, p_ago interval, p_responsible text, p_org text default '00000000-0000-4000-b000-000000000011',
                              p_case text default '00000000-0000-4000-a000-000000000208')
returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
  values (p_org::uuid, pg_temp.v(p_n), p_case::uuid, p_team::uuid,
          ((private.now() - p_ago) at time zone 'Europe/Zurich')::date, ((private.now() - p_ago) at time zone 'Europe/Zurich')::time(0), null, false,
          'planned', p_responsible::uuid)
$$;
create function pg_temp.recipients(p_n integer) returns text language sql as $$
  select coalesce(string_agg(right(d.recipient_id::text, 3) || '=' || d.reason, ',' order by d.recipient_id), '')
  from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
  where s.visit_id = pg_temp.v(p_n) and s.ended_at is null
$$;
create function pg_temp.eval() returns integer language sql as $$
  select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true)
$$;

-- Structure, privileges, RLS -----------------------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'public.safety_signals'::regclass), 'RLS is on for safety_signals');
select ok((select relrowsecurity from pg_class where oid = 'public.signal_deliveries'::regclass), 'RLS is on for signal_deliveries');
select ok(not has_table_privilege('authenticated', 'public.signal_deliveries', 'insert')
          and not has_table_privilege('authenticated', 'public.signal_deliveries', 'update')
          and not has_table_privilege('authenticated', 'public.safety_signals', 'insert')
          and not has_table_privilege('authenticated', 'public.safety_signals', 'update')
          and not has_table_privilege('authenticated', 'public.safety_signals', 'delete'),
  'users never write signals or deliveries directly (commands only)');
select ok(not has_table_privilege('anon', 'public.signal_deliveries', 'select') and not has_table_privilege('anon', 'public.safety_signals', 'select'),
  'anon reads nothing');
select ok(not has_function_privilege('authenticated', 'private.evaluate_signals(uuid, boolean)', 'execute'),
  'the writer is internal');
select is((select string_agg(column_name, ',' order by column_name) from information_schema.columns
           where table_schema = 'public' and table_name = 'signal_deliveries'),
  'created_at,id,organization_id,reason,recipient_id,signal_id,signal_kind,visit_id',
  'SIG1-1: a delivery holds kind, visit, recipient, reason and time; no name, no free text, no health data');
select is((select amount || ' ' || unit || ' ' || amount_direction from public.exception_rules where exception_type = 'signal_untaken'),
  '15 minutes delay', 'SIG1-5: the untaken threshold is an operating rule, 15 minutes, never later (PROVISIONAL, D-28)');

-- SIG1-1: a P1 overdue visit (planned start 2 h ago; P2 at the start, P1 after 1 h) ---------------------------------
select pg_temp.visit(1, '00000000-0000-4000-a000-000000000101', interval '2 hours', '00000000-0000-4000-a000-000000000902');
select ok(pg_temp.eval() >= 2, 'the evaluation writes rows');
select is((select count(*)::int from public.safety_signals where visit_id = pg_temp.v(1) and ended_at is null), 1,
  'one open signal for the visit');
select is((select signal_kind from public.safety_signals where visit_id = pg_temp.v(1)), 'visit_overdue', 'kind visit_overdue');
select is(pg_temp.recipients(1), '902=responsible,906=team',
  'SIG1-1: the responsible member and every member of the owning team; not the coach, not Operations, not the admin');
select is((select p1_at from public.safety_signals where visit_id = pg_temp.v(1)),
  private.at_zurich(((private.now() - interval '2 hours') at time zone 'Europe/Zurich')::date + ((private.now() - interval '2 hours') at time zone 'Europe/Zurich')::time(0))
    + interval '1 hour',
  'SIG1-9: the P1 time comes from the effective rule (planned start + 1 h)');

-- SIG1-2: exactly once ------------------------------------------------------------------------------------------------
select is(pg_temp.eval(), 0, 'SIG1-2: a second evaluation of the same open signal writes nothing');
select is((select count(*)::int from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id where s.visit_id = pg_temp.v(1)),
  2, 'SIG1-2: still two delivery rows');

-- P2 stays pull-only; SIG1-9: a stricter organisation rule delivers sooner (no second copy of a threshold) -----------
select pg_temp.visit(2, '00000000-0000-4000-a000-000000000101', interval '30 minutes', '00000000-0000-4000-a000-000000000906');
select pg_temp.eval();
select is((select count(*)::int from public.safety_signals where visit_id = pg_temp.v(2)), 0,
  'a P2 overdue visit (30 min) is not delivered (P2 and P3 stay pull-only)');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'visit_overdue', 'P2', 0, 0, pg_temp.k(1)), 'ok',
  'the admin sets visit_overdue to P1 at once (stricter)');
reset role;
select pg_temp.eval();
select is(pg_temp.recipients(2), '902=team,906=responsible', 'SIG1-9: with the stricter effective rule the 30-min visit is P1 and delivered');

-- SIG1-2: a signal that ends and starts again gets new rows -----------------------------------------------------------
update public.care_visits set suspended_at = private.now() where id = pg_temp.v(1);
select pg_temp.eval();
select ok((select ended_at is not null from public.safety_signals where visit_id = pg_temp.v(1)), 'the cause ended: the signal ends');
select is(pg_temp.recipients(1), '', 'no open delivery while the cause is gone');
update public.care_visits set suspended_at = null where id = pg_temp.v(1);
select pg_temp.eval();
select is((select count(*)::int from public.safety_signals where visit_id = pg_temp.v(1)), 2, 'SIG1-2: a new cause is a new signal');
select is((select count(*)::int from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id where s.visit_id = pg_temp.v(1)),
  4, 'SIG1-2: with new delivery rows (2 + 2)');

-- SIG1-4: take it ------------------------------------------------------------------------------------------------------
create temp table sig as select id from public.safety_signals where visit_id = pg_temp.v(1) and ended_at is null;
grant select on sig to authenticated;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.take_signal((select id from sig), pg_temp.k(10)) ->> 'reason', 'not_recipient', 'SIG1-4: a non-recipient is rejected');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.take_signal((select id from sig), pg_temp.k(11)) ->> 'result', 'rejected', 'SIG1-7: the coach (no team) is rejected');
select is((select count(*)::int from public.signal_deliveries), 0, 'SIG1-7: the coach without team membership receives nothing');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.take_signal((select id from sig), pg_temp.k(12)) ->> 'result', 'ok', 'SIG1-4: a recipient takes it with one tap');
select is(public.take_signal((select id from sig), pg_temp.k(12)) ->> 'result', 'duplicate', 'the same key returns duplicate');
select is((select taken_by_me from public.my_signals() where signal_id = (select id from sig)), true, 'she sees she took it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.take_signal((select id from sig), pg_temp.k(13)) ->> 'result', 'duplicate', 'SIG1-4: a second tap by a colleague returns duplicate');
select ok((select not taken_by_me and taken_by_name is not null and taken_at is not null from public.my_signals() where signal_id = (select id from sig)),
  'SIG1-4: every other recipient sees who took it');
select is((select count(*)::int from public.signal_deliveries where visit_id in (pg_temp.v(1), pg_temp.v(2))), 3,
  'SIG1-7 / RLS: she reads her own deliveries of the fixtures (visit 1 twice, visit 2 once)');
select ok((select bool_and(recipient_id = '00000000-0000-4000-a000-000000000902') from public.signal_deliveries), 'RLS: only rows addressed to her');
reset role;
select is((select ended_at from public.safety_signals where id = (select id from sig)), null::timestamptz,
  'SIG1-4 / CR-041: taking does not end the signal; it stays open until its cause ends');
select is((select count(*)::int from public.audit_events where table_name = 'safety_signals' and command = 'take_signal'
           and actor_id = '00000000-0000-4000-a000-000000000906' and idempotency_key = pg_temp.k(12)), 1,
  'SIG1-4: the take is audited with who, the command and the key');

-- Guards ---------------------------------------------------------------------------------------------------------------
select throws_ok($$ update public.safety_signals set taken_by = '00000000-0000-4000-a000-000000000902' where id = (select id from sig) $$,
  '42501', null, 'a take is recorded once and never changed');
select throws_ok($$ delete from public.signal_deliveries where signal_id = (select id from sig) $$,
  '42501', null, 'deliveries are never deleted');

-- SIG1-5: not taken ----------------------------------------------------------------------------------------------------
select is((select escalated_at from public.safety_signals where visit_id = pg_temp.v(2)), null::timestamptz,
  'SIG1-5: with the 15-min default a fresh untaken signal is not escalated yet');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'signal_untaken', 'P1', 30, null, pg_temp.k(2)), 'out_of_range',
  'SIG1-5: the threshold cannot be set above the default');
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'signal_untaken', 'P1', 0, null, pg_temp.k(3)), 'ok',
  'SIG1-5: it may be set stricter (0 minutes)');
reset role;
select pg_temp.eval();
select is(pg_temp.recipients(2), '902=team,904=untaken,906=responsible', 'SIG1-5: untaken past the threshold → Operations as well');
select is((select count(*)::int from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
           where s.id = (select id from sig) and d.reason = 'untaken'), 0, 'SIG1-5: taken before the threshold → no Operations row');
select pg_temp.eval();
select is((select count(*)::int from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
           where s.visit_id = pg_temp.v(2) and d.reason = 'untaken'), 1, 'SIG1-5: once');

-- No-show maps to its kind ----------------------------------------------------------------------------------------------
select pg_temp.visit(3, '00000000-0000-4000-a000-000000000101', interval '-1 day', '00000000-0000-4000-a000-000000000902');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.depart_visit(pg_temp.v(3), pg_temp.k(20)), 'ok', 'fixture: on the way');
select is(public.record_no_show(pg_temp.v(3), 'Synthetisch: niemand öffnet', pg_temp.k(21), true), 'ok', 'fixture: no-show recorded');
reset role;
select pg_temp.eval();
select is((select signal_kind from public.safety_signals where visit_id = pg_temp.v(3) and ended_at is null), 'no_show', 'a no-show is delivered as no_show');

-- SIG1-7: a removed member receives nothing for her former team (also as the visit's responsible) ---------------------
delete from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101' and user_id = '00000000-0000-4000-a000-000000000906';
select pg_temp.visit(6, '00000000-0000-4000-a000-000000000101', interval '2 hours', '00000000-0000-4000-a000-000000000906');
select pg_temp.eval();
select is(pg_temp.recipients(6), '902=team,904=untaken',
  'SIG1-7: the removed member gets no row, the remaining member does (Operations through the 0-min untaken rule set above)');

-- Fallback: nobody of the team is on duty → Operations; never another organisation -----------------------------------
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by, absence_group)
select '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000101', u, private.now() - interval '1 day', private.now() + interval '1 day',
       '00000000-0000-4000-a000-000000000905', gen_random_uuid()
from unnest(array['00000000-0000-4000-a000-000000000902', '00000000-0000-4000-a000-000000000906']::uuid[]) u;
select pg_temp.visit(4, '00000000-0000-4000-a000-000000000101', interval '20 minutes', '00000000-0000-4000-a000-000000000906');
select pg_temp.eval();
select is(pg_temp.recipients(4), '904=operations_fallback',
  'SIG1-1: the absent responsible member and an absent team → the Operations user only (not the coach, not the admin)');

select pg_temp.visit(5, '00000000-0000-4000-a000-000000000151', interval '2 hours', null, '00000000-0000-4000-b000-000000000012',
                     (select id::text from public.cases where organization_id = '00000000-0000-4000-b000-000000000012' limit 1));
select private.evaluate_signals('00000000-0000-4000-b000-000000000012', true);
select is(pg_temp.recipients(5), '903=operations_fallback', 'org B (no member in its team, no Operations user): its admin');
select is((select count(*)::int from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
           where s.organization_id = '00000000-0000-4000-b000-000000000012' and d.recipient_id <> '00000000-0000-4000-a000-000000000903'), 0,
  'SIG1-2 / SIG1-7: no row for another organisation''s people');
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.safety_signals where organization_id = '00000000-0000-4000-b000-000000000011'), 0,
  'SIG1-7: org B reads no signal of org A');
select is((select count(*)::int from public.my_signals() where visit_id = pg_temp.v(5)), 1, 'org B''s admin sees her own');
reset role;

-- A removed planned visit (PLAN2, remove_planned_visit) is not blocked by its signal; the signal ends -----------------
select pg_temp.visit(7, '00000000-0000-4000-a000-000000000101', interval '3 hours', '00000000-0000-4000-a000-000000000902');
select pg_temp.eval();
select lives_ok($$ delete from public.care_visits where id = pg_temp.v(7) $$, 'a visit with a signal can still be removed');
select pg_temp.eval();
select ok((select bool_and(ended_at is not null) from public.safety_signals where visit_id = pg_temp.v(7)), 'and its signal ends');

-- SIG1-6: AN2 measure 10 rows ------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.pilot_hypotheses((private.now() at time zone 'Europe/Zurich')::date)
           where measure in ('signal_taken_share', 'signal_minutes_to_take') and team_id = '00000000-0000-4000-a000-000000000101'), 2,
  'SIG1-6: both measures per team');
select ok((select bool_and(suppressed and value is null) from public.pilot_hypotheses((private.now() at time zone 'Europe/Zurich')::date)
           where measure in ('signal_taken_share', 'signal_minutes_to_take') and team_id = '00000000-0000-4000-a000-000000000101'),
  'SIG1-6: AN1 suppression applies (two people in Testteam Nord)');
reset role;

select * from finish();
rollback;
