-- COND1-4 = FUP1-C1 (Q16) and FUP1-C2 (CGR-60). Migration 0082, ADR-095. Brief `docs/agents/briefs/COND1.md`;
-- specification in `FUP1.md`, *PO decision 2026-10-25 18:12 CET*.
-- Org A (…011): Operations …904 (the only Operations member, so the step's Operations recipient), admin …905, care
-- assistant …906 and registered nurse …902 (Testteam Nord …101), case …208. Synthetic data only. Every instant is read
-- explicitly (p_at) on a day seven days ahead, so neither the hour CI runs nor the date matters, and the channel switched
-- on now (enabled_since = now()) is on at every reading.
begin;
create extension if not exists pgtap with schema extensions;

select plan(29);

create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.id(n text) returns uuid language sql immutable as $$
  select ('a0820000-0000-4000-8000-' || left(md5(n), 12))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a0820000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid $$;
-- The test day: seven days after today (Zurich), and an instant of it.
create function pg_temp.day() returns date language sql stable as $$ select (now() at time zone 'Europe/Zurich')::date + 7 $$;
create function pg_temp.at(t time) returns timestamptz language sql stable as $$
  select (pg_temp.day() + t) at time zone 'Europe/Zurich' $$;
create function pg_temp.as_user(p_user integer, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.hours(p_starts time, p_ends time) returns void language sql as $$
  delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';
  insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
  select '00000000-0000-4000-b000-000000000011', d, p_starts, p_ends from generate_series(1, 7) d where p_starts is not null;
$$;
-- A P1 no-show of Nord on the test day, created at p_created: with the untaken threshold of 15 minutes the step to
-- Operations is due at p_created + 15 minutes. Not taken, not escalated, no Operations delivery (the not-yet-made branch).
create function pg_temp.fsig(p_n text, p_created time) returns uuid language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                  responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.id('v' || p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', pg_temp.day(), '19:00', '19:30', false, 'planned', pg_temp.u(902));
  insert into public.safety_signals (organization_id, id, team_id, visit_id, signal_kind, exception_key, p1_at, created_at)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.id('s' || p_n), '00000000-0000-4000-a000-000000000101',
          pg_temp.id('v' || p_n), 'no_show', 'cond14:' || p_n, pg_temp.at(p_created), pg_temp.at(p_created));
  return pg_temp.id('s' || p_n);
end $$;
create function pg_temp.f(p_n text, p_at time) returns boolean language sql as $$
  select private.signal_step_outside_app(pg_temp.id('s' || p_n), pg_temp.at(p_at)) $$;

-- Fixtures ----------------------------------------------------------------------------------------------------------
-- (Wrapped in ok(): a bare 'ok' result row would be read as a TAP line.)
select ok(pg_temp.as_user(905, format('select public.set_exception_rule(%L, %L, %L, %s, null, %L)',
            '00000000-0000-4000-b000-000000000011', 'signal_untaken', 'P1', 15, pg_temp.k(1))) in ('ok', 'unchanged'),
  'fixture: the administrator sets the untaken threshold to 15 minutes');
select is((select r.amount::text || ' ' || r.unit from private.effective_exception_rules('00000000-0000-4000-b000-000000000011') r
           where r.exception_type = 'signal_untaken' limit 1), '15 minutes', 'fixture: the untaken threshold is 15 minutes');
select pg_temp.fsig('a', '19:44:30');   -- due 19:59:30
select pg_temp.fsig('b', '19:43');      -- due 19:58
select pg_temp.fsig('c', '19:44');      -- due 19:59
select pg_temp.hours('07:00', '20:00');
select is((select array_agg(o order by o) from private.signal_operations_users('00000000-0000-4000-b000-000000000011') o),
  array[pg_temp.u(904)], 'fixture: …904 is the Operations recipient of the step');
-- The organisation's vendor facts, as a later migration would record them (inside this transaction only).
update public.push_vendors set dpf_swiss_status = 'active', dpf_read_on = '2026-10-24';

-- FUP1-C2 (CGR-60): no promise without a reachable Operations recipient -------------------------------------------
select ok(not exists (select 1 from public.organization_push_settings where organization_id = '00000000-0000-4000-b000-000000000011' and enabled),
  'fixture: the outside channel is off');
select is(pg_temp.f('b', '19:45'), false, 'FUP1-C2: inside the watched period, channel off → false');
select is(pg_temp.as_user(905, format('select public.set_outside_push(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(2))),
  'ok', 'fixture: the administrator switches the outside channel on');
select is(pg_temp.f('b', '19:45'), false, 'FUP1-C2: channel on, no Operations member with an active subscription → false');
select is(pg_temp.as_user(904, format('select public.register_push_subscription(%L, %L, %L, %L) ->> ''result''',
            'https://fcm.googleapis.com/fcm/send/syn-cond14-904', repeat('E', 87), repeat('d', 22), pg_temp.k(3))), 'ok',
  'fixture: …904 opts in');
select is(pg_temp.f('b', '19:45'), false, 'FUP1-C2: her subscription is stored but no send has succeeded yet (not active) → false');
update public.push_subscriptions set last_result = 'sent' where user_id = pg_temp.u(904);   -- fixture: the test message arrived
select is(pg_temp.f('b', '19:45'), true, 'FUP1-C2: one Operations member with an active subscription → true');
select is(private.signal_step_outside_app(pg_temp.id('sb'), (now() - interval '1 day')), false,
  'FUP1-C2: read before the channel''s enabled_since → false');

-- FUP1-C1 (Q16): no promise in the last evaluator interval (channel on, …904 active) ---------------------------------
select is(private.signal_evaluator_interval(), interval '1 minute', 'FUP1-C1: the evaluator interval is one minute (the cron cadence)');
select is(pg_temp.f('a', '19:45'), false, 'FUP1-C1: watched until 20:00, step due 19:59:30 → false');
select is(pg_temp.f('b', '19:45'), true, 'FUP1-C1: watched until 20:00, step due 19:58 → true');
select is(pg_temp.f('c', '19:45'), false, 'FUP1-C1: due 19:59, one interval later is 20:00 (the end is exclusive) → false');
select pg_temp.hours('07:00', '21:00');
select is(pg_temp.f('a', '19:45'), true, 'FUP1-C1: watched until 21:00, step due 19:59:30 → true');
select pg_temp.hours('07:00', '20:00');

-- FUP1-C2: the subscription ends ---------------------------------------------------------------------------------------
select is(pg_temp.as_user(904, format('select public.unregister_push_subscription(null, %L)', pg_temp.k(4))), 'ok',
  'fixture: …904 switches outside delivery off on her device');
select is(pg_temp.f('b', '19:45'), false, 'FUP1-C2: the Operations member''s subscription ended → false');
select is(pg_temp.as_user(904, format('select public.register_push_subscription(%L, %L, %L, %L) ->> ''result''',
            'https://fcm.googleapis.com/fcm/send/syn-cond14-904b', repeat('F', 87), repeat('e', 22), pg_temp.k(5))), 'ok',
  'fixture: …904 opts in again');
update public.push_subscriptions set last_result = 'failed' where user_id = pg_temp.u(904);   -- fixture: the last send failed
select is(pg_temp.f('b', '19:45'), false, 'FUP1-C2: her last send failed (not active under push_active) → false');

-- The made-step branch is unchanged: it follows the real delivery, also with the channel off and outside the period.
insert into public.signal_deliveries (id, organization_id, signal_id, recipient_id, reason, signal_kind, visit_id)
values (pg_temp.id('da'), '00000000-0000-4000-b000-000000000011', pg_temp.id('sa'), pg_temp.u(904), 'untaken', 'no_show', pg_temp.id('va'));
insert into public.signal_outside_deliveries (id, organization_id, signal_id, recipient_id, result, sent_at)
values (pg_temp.id('da'), '00000000-0000-4000-b000-000000000011', pg_temp.id('sa'), pg_temp.u(904), 'sent', pg_temp.at('20:00'));
select is(pg_temp.as_user(905, format('select public.set_outside_push(%L, false, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(6))),
  'ok', 'fixture: the administrator switches the outside channel off');
select is(pg_temp.f('a', '20:30'), true, 'made-step branch unchanged: a sent Operations delivery → true, channel off, after the period');

-- COND1-4a (PO 15:16, ADR-095 deviation 1): the fallback recipient set. No Operations member with open access, so the
-- step goes to the administrator (signal_operations_users, 0074); her active subscription makes the forecast true.
select is(pg_temp.as_user(905, format('select public.set_outside_push(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(7))),
  'ok', 'fixture: the administrator switches the outside channel on again');
select is(pg_temp.as_user(905, format('select public.end_member_access(%L::uuid, %L, %L::uuid) ->> ''result''',
            pg_temp.u(904), 'access_withdrawn', pg_temp.k(8))), 'ok',
  'fixture: the access of …904, the only Operations member, ends');
select is((select array_agg(o order by o) from private.signal_operations_users('00000000-0000-4000-b000-000000000011') o),
  array[pg_temp.u(905)], 'COND1-4a fixture: no Operations member with open access → the administrator …905 is the step''s recipient');
select is(pg_temp.f('b', '19:45'), false, 'COND1-4a: fallback administrator without an active subscription → false');
select is(pg_temp.as_user(905, format('select public.register_push_subscription(%L, %L, %L, %L) ->> ''result''',
            'https://fcm.googleapis.com/fcm/send/syn-cond14-905', repeat('G', 87), repeat('f', 22), pg_temp.k(9))), 'ok',
  'fixture: …905 opts in');
update public.push_subscriptions set last_result = 'sent' where user_id = pg_temp.u(905);   -- fixture: the test message arrived
select is(pg_temp.f('b', '19:45'), true,
  'COND1-4a: no Operations member with open access, one administrator push_active in the fallback, inside the watched period → true');

-- Privileges: no app role runs the helpers.
select ok(not has_function_privilege('authenticated', 'private.signal_operations_reachable(uuid, timestamptz)', 'execute')
          and not has_function_privilege('anon', 'private.signal_evaluator_interval()', 'execute')
          and not has_function_privilege('authenticated', 'private.signal_step_outside_app(uuid, timestamptz)', 'execute'),
  'the helpers are not executable by anon or authenticated');

select * from finish();
rollback;
