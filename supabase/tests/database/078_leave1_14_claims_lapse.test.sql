-- LEAVE1-14: nothing she claimed keeps others from acting once her access ends (migration 0078, ADR-091). Brief
-- `docs/agents/briefs/LEAVE1.md` LEAVE1-14 (PO 2026-10-26 02:14 CET); `cra` CGR-62 (blocking, S1).
-- LEAVE1-C3 (COND1-1, migration 0080, ADR-093): the restore block follows option (a) (a restore does not revive a take).
-- Users: registered nurse …902 and care assistant …906 (org A, Testteam Nord …101) · operations …904 · admin …905
-- (org A …011). Synthetic user added here: …7801, a registered nurse of Testteam Nord, the leaver. Case …208 (org A,
-- Testteam Nord). All data synthetic; every step goes through the real commands, except the steps marked
-- "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(50);

-- Pinned clock (DST1 pattern, #399/#409 class): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a7800000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a7800000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;

-- The leaver: a registered nurse of Testteam Nord (as the table owner).
insert into auth.users (id, email) values (pg_temp.u(7801), 'leave14-l@navora.test');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u(7801), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u(7801), 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(7801), 'Synthetisch Leaver'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(902), 'Synthetisch Kollegin')
on conflict (organization_id, user_id) do update set display_name = excluded.display_name;

-- A P1 no-show signal for visit n (responsible: the registered nurse …902, who departs and records the no-show).
-- VIS1-5: the no-show fixture is dated today, 23:59 (still ahead, so no overdue signal of its own); a visit dated
-- after today cannot be departed or recorded as a no-show (CGR-87). Before VIS1 it was tomorrow 09:00.
create function pg_temp.no_show(p_n integer) returns void language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, billable, status, responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.v(p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', pg_temp.today(), '23:59', false, 'planned', '00000000-0000-4000-a000-000000000902');
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000902');
  set local role authenticated;
  perform public.depart_visit(pg_temp.v(p_n), pg_temp.k(100 + p_n));
  perform public.record_no_show(pg_temp.v(p_n), 'Synthetisch: niemand öffnet', pg_temp.k(200 + p_n), true);
  reset role;
end;
$$;
create function pg_temp.sig(p_n integer) returns uuid language sql as $$
  select id from public.safety_signals where visit_id = pg_temp.v(p_n) and ended_at is null
$$;
create function pg_temp.take(p_user integer, p_n integer, p_key integer) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  set local role authenticated;
  r := public.take_signal(pg_temp.sig(p_n), pg_temp.k(p_key));
  reset role;
  return r;
end;
$$;
create function pg_temp.escalated(p_n integer) returns boolean language sql as $$
  select escalated_at is not null from public.safety_signals where id = pg_temp.sig(p_n)
$$;
create function pg_temp.ops(p_n integer) returns integer language sql as $$
  select count(*)::int from public.signal_deliveries where signal_id = pg_temp.sig(p_n) and reason = 'untaken'
$$;
create function pg_temp.eval() returns integer language sql as $$
  select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true)
$$;
-- As the table owner: the signal started p_minutes ago (past the 15-minute signal_untaken default when > 15).
create function pg_temp.started_ago(p_n integer, p_minutes integer) returns void language plpgsql as $$
begin
  set local session_replication_role = replica;
  update public.safety_signals set created_at = private.now() - make_interval(mins => p_minutes) where id = pg_temp.sig(p_n);
  set local session_replication_role = origin;
end;
$$;
create function pg_temp.admin(p_cmd text, p_key integer) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000905');
  set local role authenticated;
  if p_cmd = 'end' then
    r := public.end_member_access(pg_temp.u(7801), 'access_withdrawn', pg_temp.k(p_key));
  else
    r := public.restore_member_access(pg_temp.u(7801), 'ended_in_error', pg_temp.k(p_key));
  end if;
  reset role;
  return r;
end;
$$;
-- What a colleague (the care assistant …906) reads for signal n.
create function pg_temp.seen(p_n integer) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000906');
  set local role authenticated;
  select to_jsonb(m) into r from public.my_signals() m where m.signal_id = pg_temp.sig(p_n);
  reset role;
  return r;
end;
$$;
create function pg_temp.position(p_n integer) returns integer language plpgsql as $$
declare r integer;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000906');
  set local role authenticated;
  select o.ordinality::int into r from public.my_signals() with ordinality as o where o.signal_id = pg_temp.sig(p_n);
  reset role;
  return r;
end;
$$;

-- Structure ---------------------------------------------------------------------------------------------------------------
select is((select string_agg(p.parameter_name, ',' order by p.ordinal_position) from information_schema.parameters p
           join information_schema.routines r on r.specific_name = p.specific_name
           where r.routine_schema = 'public' and r.routine_name = 'my_signals' and p.parameter_mode = 'OUT'
             and p.parameter_name in ('taken_by_name', 'taker_access_ended')),
  'taken_by_name,taker_access_ended', 'LEAVE1-14 (2): my_signals carries taker_access_ended');
select ok(has_function_privilege('authenticated', 'public.my_signals()', 'execute')
          and not has_function_privilege('anon', 'public.my_signals()', 'execute'), 'my_signals stays for signed-in users only');
select ok(position('LEAVE1-3' in pg_get_functiondef('public.my_signals()'::regprocedure)) > 0,
  'my_signals keeps the LEAVE1-3 guard (a leaver reads nothing)');

-- Cycle 1: the SIG1-5 step (outside channel off, so SIG2 makes no delivery) ------------------------------------------
select pg_temp.no_show(11);
select pg_temp.no_show(12);
select pg_temp.eval();
select ok(pg_temp.sig(11) is not null and pg_temp.sig(12) is not null, 'fixture: two P1 no-show signals');
select ok(exists (select 1 from public.signal_deliveries where signal_id = pg_temp.sig(11) and recipient_id = pg_temp.u(7801)),
  'fixture: the leaver-to-be is a recipient');
select is(pg_temp.take(7801, 11, 1) ->> 'operations_follows', 'false', 'the registered nurse …7801 takes no-show 11: the step stops');
select is(pg_temp.take(902, 12, 2) ->> 'operations_follows', 'false', 'a colleague registered nurse …902 takes no-show 12: the step stops');
select pg_temp.started_ago(11, 20);
select pg_temp.started_ago(12, 20);
select pg_temp.eval();
select ok(not pg_temp.escalated(11) and pg_temp.ops(11) = 0, 'before the end: her take stops the step past the threshold');

-- Her access ends.
create temp table r1 as select pg_temp.admin('end', 10) as r;
select is((select r ->> 'result' from r1), 'ok', 'fixture: the administrator ends her access');
select is((select (r ->> 'taken_signals')::int from r1), 1, 'LEAVE1-14 (3): the end result names the open signals she had taken');
select is((select (changes ->> 'taken_signals')::int from public.change_log where command = 'end_member_access'
           and idempotency_key = pg_temp.k(10)), 1, 'the change log carries the count');
select is((select (changed ->> 'taken_signals')::int from public.audit_events where command = 'end_member_access'
           and table_name = 'organization_memberships' and idempotency_key = pg_temp.k(10)), 1, 'the audit row carries the count');

select ok(not private.signal_taken_stops_step(pg_temp.sig(11)), 'LEAVE1-14 (1): her take no longer stops the step');
select ok(private.signal_taken_stops_step(pg_temp.sig(12)), 'a take by a colleague with open access still stops the step');

-- What the team reads (LEAVE1-14 (2)).
select is((select (r ->> 'taker_access_ended')::boolean from (select pg_temp.seen(11) as r) x), true,
  'a colleague reads the take as ended (text "Übernahme beendet – Zugang beendet")');
select ok((select r ->> 'taken_by_name' is null and r ->> 'taken_at' is null and r ->> 'taken_by_qualification' is null
                  and not (r ->> 'taken_by_me')::boolean and not (r ->> 'taken_awaits_rn')::boolean
           from (select pg_temp.seen(11) as r) x),
  'no name, no time, no qualification of the leaver; nothing pending on a care assistant''s take');
select ok((select r ->> 'taken_by_name' is not null and not (r ->> 'taker_access_ended')::boolean
           from (select pg_temp.seen(12) as r) x), 'the colleague''s take still shows her name');
select ok(pg_temp.position(11) < pg_temp.position(12),
  'sorted with the untaken signals: the older signal 11 comes before the newer, taken signal 12');

-- LEAVE1-C3 (CGR-63, option (a), migration 0080; replaces the 0078 "restore revives the take" block): a restore before
-- the step does not revive her earlier take.
select is(pg_temp.admin('restore', 11) ->> 'result', 'ok', 'fixture: her access is restored before the step');
select ok(not private.signal_taken_stops_step(pg_temp.sig(11)),
  'LEAVE1-C3: after the restore her earlier take (recorded before her access end) does not stop the step');
select is((select (r ->> 'taker_access_ended')::boolean from (select pg_temp.seen(11) as r) x), true,
  'LEAVE1-C3: the team still reads "Übernahme beendet – Zugang beendet" after the restore; the signal stays in the open list');
select pg_temp.eval();
select ok(pg_temp.escalated(11), 'LEAVE1-C3: SIG1-5 fires at the threshold (the signal started 20 minutes ago)');
select is(pg_temp.ops(11), (select count(*)::int from private.signal_operations_users('00000000-0000-4000-b000-000000000011')),
  'and delivers to Operations');
select ok(pg_temp.ops(11) >= 1, 'fixture: Operations has at least one receiver');
select ok(not pg_temp.escalated(12) and pg_temp.ops(12) = 0, 'the colleague''s take still holds signal 12');

-- She takes it again after the restore: that take counts (a new row; the earlier one stays as recorded).
select is(pg_temp.take(7801, 11, 5) ->> 'result', 'ok', 'LEAVE1-C3: she takes the signal again after the restore');
select ok(private.signal_taken_stops_step(pg_temp.sig(11)), 'LEAVE1-C3: her take after the restore stops the step');
select is((select (r ->> 'taker_access_ended')::boolean from (select pg_temp.seen(11) as r) x), false,
  'LEAVE1-C3: the team reads her new take');
select is((select count(*)::int from public.signal_takes where signal_id = pg_temp.sig(11) and taker_id = pg_temp.u(7801)), 2,
  'LEAVE1-C3: the new take is appended; the earlier take stays');

-- Ended again: her new take lapses too.
select is(pg_temp.admin('end', 12) ->> 'taken_signals', '1', 'her access ends again; the result names 1 open signal (her new take of 11)');
select ok(not private.signal_taken_stops_step(pg_temp.sig(11)), 'after the second end no take of hers stops the step');
create temp table before_ops as select pg_temp.ops(11) as n;
select pg_temp.eval();
select is(pg_temp.ops(11), (select n from before_ops), 'once: a second evaluation delivers nothing more');

-- LEAVE1-14 (4): nothing is rewritten.
select is((select string_agg(right(taker_id::text, 4) || ':' || stops_escalation, ',') from public.signal_takes
           where signal_id = pg_temp.sig(11)), '7801:true,7801:true', 'her takes stay as recorded (append-only)');
select is((select taken_by from public.safety_signals where id = pg_temp.sig(11)), pg_temp.u(7801),
  'safety_signals.taken_by stays the first take');
select is(private.signal_qualified_taken_at(pg_temp.sig(11)),
          (select min(taken_at) from public.signal_takes where signal_id = pg_temp.sig(11) and taker_id = pg_temp.u(7801)),
  'the SIGC/AN2 response measure keeps the historical take');

-- A colleague can take it now; "already taken" then names her, not the leaver.
select is(pg_temp.take(902, 11, 3) ->> 'result', 'ok', 'a colleague registered nurse can take the signal after the leaver''s take lapsed');
select is(pg_temp.take(906, 11, 4) ->> 'taken_by_name', 'Synthetisch Kollegin',
  '"already taken" names the colleague with open access, not the leaver');

-- Cycle 2: SIG2's immediate step (nobody reached outside the app) ---------------------------------------------------------
select is(pg_temp.admin('restore', 20) ->> 'result', 'ok', 'fixture: her access is restored');
update public.push_vendors set dpf_swiss_status = 'active', dpf_read_on = '2026-10-24';
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', true, pg_temp.k(21)), 'ok', 'fixture: the outside channel is on');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.register_push_subscription('https://fcm.googleapis.com/fcm/send/syn-l14', repeat('B', 87), repeat('a', 22), pg_temp.k(22)) ->> 'result',
  'ok', 'fixture: the colleague …902 opted in');
reset role;
update public.push_subscriptions set last_result = 'sent' where user_id = pg_temp.u(902);
select pg_temp.no_show(13);
select pg_temp.eval();
select ok(pg_temp.sig(13) is not null and exists (select 1 from public.signal_outside_deliveries o
          join public.signal_deliveries d on d.id = o.id where d.signal_id = pg_temp.sig(13)),
  'fixture: a P1 no-show handed to the sender outside the app');
select is(pg_temp.take(7801, 13, 23) ->> 'operations_follows', 'false', 'she takes it: the step stops');
set local session_replication_role = replica;
update public.signal_outside_deliveries set decided_at = private.now() - interval '3 minutes'
where id in (select d.id from public.signal_deliveries d where d.signal_id = pg_temp.sig(13));
set local session_replication_role = origin;
select pg_temp.eval();
select ok(not pg_temp.escalated(13), 'before the end: nobody reached outside the app, but her take holds the immediate step');
select is(pg_temp.admin('end', 24) ->> 'taken_signals', '1',
  'her access ends; the result names 1 open signal (13; her takes of 11 lapsed at the earlier ends, LEAVE1-C3)');
select pg_temp.eval();
select ok(pg_temp.escalated(13) and (select outside_none_at is not null from public.safety_signals where id = pg_temp.sig(13)),
  'LEAVE1-14 (1): SIG2''s immediate step fires as for an untaken signal');

-- LEAVE1-14 (5): no new claim for a person whose access has ended ---------------------------------------------------------
select ok(not private.may_perform_visit('00000000-0000-4000-a000-000000000101', pg_temp.u(7801), 0, false),
  'ABS1: no released visit returns to her (may_perform_visit)');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_primary_nurse('00000000-0000-4000-a000-000000000208', pg_temp.u(7801), null, null, pg_temp.k(30)), 'not_in_team',
  'set_primary_nurse refuses her with the existing code');
select is(public.plan_visit('00000000-0000-4000-a000-000000000208', pg_temp.today() + 3, '15:00', '15:30', 30, 0, 0, false,
                            pg_temp.u(7801), pg_temp.k(31)) ->> 'reason', 'responsible_not_in_team',
  'plan_visit refuses her as the responsible member with the existing code');
reset role;
-- PLAN2 (as the table owner: a primary nurse whose access ended, e.g. after a reopen).
update public.cases set primary_nurse_id = pg_temp.u(7801), medical_order_status = 'present',
                        medical_order_valid_until = pg_temp.today() + 90
where id = '00000000-0000-4000-a000-000000000208';
insert into public.care_plan_items (id, organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by)
values (pg_temp.v(900), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        'Synthetische Leistung L14', 'A', 20, '1x täglich', pg_temp.today() + 60, '00000000-0000-4000-a000-000000000902');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_care_plan_schedule(pg_temp.v(900), 7, 'week', array[1,2,3,4,5,6,7], '14:00', '14:30', pg_temp.k(32)) ->> 'result',
  'ok', 'fixture: the team schedules the item daily (PLAN2 generates its visits)');
reset role;
select private.generate_case_plan('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902');
select ok((select count(*) from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208' and plan_generated) > 0
          and not exists (select 1 from public.care_visits where case_id = '00000000-0000-4000-a000-000000000208'
                          and plan_generated and responsible_user_id = pg_temp.u(7801)),
  'PLAN2: generated visits never name a primary nurse whose access has ended');

select * from finish();
rollback;
