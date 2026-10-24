-- SIG2: safety signals reach the nurse's phone (migration 0062, ADR-076). Brief `docs/agents/briefs/SIG2.md`.
-- Users: coach …901 (org A, no team) · nurse …902 and care assistant …906 (org A, Testteam Nord …101) ·
-- operations …904 · admin …905 (org A …011) · admin …903 (org B …012). Synthetic data and endpoints only;
-- no push service is called (the sender is not part of the database; its reports are simulated as service_role).
begin;
create extension if not exists pgtap with schema extensions;

select plan(106);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a6400000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a6400000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-' || lpad(n::text, 12, '0'))::uuid
$$;
-- A planned visit of Testteam Nord starting p_from_now from now (Zurich wall time).
create function pg_temp.visit(p_n integer, p_from_now interval, p_responsible uuid, p_case text default '00000000-0000-4000-a000-000000000208')
returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.v(p_n), p_case::uuid, '00000000-0000-4000-a000-000000000101',
          (now() at time zone 'Europe/Zurich' + p_from_now)::date, (now() at time zone 'Europe/Zurich' + p_from_now)::time(0), null, false,
          'planned', p_responsible)
$$;
-- "902=responsible:sent,906=team:not_active" for the open signal of a visit.
create function pg_temp.outside(p_n integer) returns text language sql as $$
  select coalesce(string_agg(right(d.recipient_id::text, 3) || '=' || d.reason || ':' || coalesce(o.result, '-'), ',' order by d.recipient_id), '')
  from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
  left join public.signal_outside_deliveries o on o.id = d.id
  where s.visit_id = pg_temp.v(p_n) and s.ended_at is null
$$;
create function pg_temp.eval() returns integer language sql as $$
  select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true)
$$;
create function pg_temp.sub(p_user integer) returns uuid language sql as $$
  select id from public.push_subscriptions where user_id = pg_temp.u(p_user) order by created_at limit 1
$$;
create function pg_temp.delivery(p_n integer, p_user integer) returns uuid language sql as $$
  select d.id from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
  where s.visit_id = pg_temp.v(p_n) and s.ended_at is null and d.recipient_id = pg_temp.u(p_user)
$$;
create function pg_temp.zurich(p text) returns timestamptz language sql immutable as $$
  select (p::timestamp) at time zone 'Europe/Zurich'
$$;

-- Structure, privileges, RLS (SIG2-8, SIG2-9) -------------------------------------------------------------------------
select ok((select bool_and(relrowsecurity) from pg_class where oid in ('public.push_subscriptions'::regclass, 'public.signal_outside_deliveries'::regclass,
           'public.organization_push_settings'::regclass, 'public.organization_watched_hours'::regclass, 'public.push_vendors'::regclass)),
  'RLS is on for every SIG2 table');
select ok(not has_table_privilege('authenticated', 'public.push_subscriptions', 'insert')
          and not has_table_privilege('authenticated', 'public.push_subscriptions', 'update')
          and not has_table_privilege('authenticated', 'public.push_subscriptions', 'delete')
          and not has_table_privilege('authenticated', 'public.signal_outside_deliveries', 'insert')
          and not has_table_privilege('authenticated', 'public.signal_outside_deliveries', 'update')
          and not has_table_privilege('authenticated', 'public.organization_push_settings', 'update')
          and not has_table_privilege('authenticated', 'public.push_vendors', 'update'),
  'users never write the SIG2 tables directly (commands only)');
select ok(not has_column_privilege('authenticated', 'public.push_subscriptions', 'endpoint', 'select')
          and not has_column_privilege('authenticated', 'public.push_subscriptions', 'p256dh', 'select')
          and not has_column_privilege('authenticated', 'public.push_subscriptions', 'auth_secret', 'select'),
  'SIG2-9: endpoint and keys are not readable by any user (the sender reads them as service_role)');
select ok(not has_function_privilege('authenticated', 'public.push_dispatch_claim(integer)', 'execute')
          and not has_function_privilege('authenticated', 'public.push_dispatch_report(text, uuid, jsonb)', 'execute')
          and not has_function_privilege('anon', 'public.push_dispatch_claim(integer)', 'execute')
          and has_function_privilege('service_role', 'public.push_dispatch_claim(integer)', 'execute'),
  'SIG2-9: only the sender (service_role) claims and reports');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name in ('push_subscriptions', 'signal_outside_deliveries')
             and column_name in ('payload', 'text', 'message', 'body', 'note', 'notes', 'title', 'detail', 'content')), 0,
  'SIG2-8: no free-text or payload column on the push tables (the text is one constant in the sender)');
select is((select string_agg(vendor || ':' || legal_entity || ':' || country, ',' order by vendor) from public.push_vendors),
  'google_fcm:Google LLC:USA,microsoft_wns:Microsoft Corporation:USA', 'SIG2-1: two vendors, named with entity and country');
select is((select count(*)::int from public.push_vendors where dpf_swiss_status is not null), 0,
  'SIG2-3: the migration records no DPF entry it could not read (fail closed)');
select is(private.push_vendor_for_endpoint('https://fcm.googleapis.com/fcm/send/x1'), null,
  'SIG2-3: without a recorded active DPF entry even a Google endpoint is not accepted');

-- SIG2-3: off by default; the switch needs a counted vendor; admins only --------------------------------------------
select is(private.outside_channel_on('00000000-0000-4000-b000-000000000011'), false, 'SIG2-3: the channel is off by default');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', true, pg_temp.k(1)), 'vendors_unverified',
  'SIG2-3: no vendor with a recorded DPF entry → the channel cannot be switched on');
reset role;
-- The fact the PR records (date read), as a later migration would; inside this test transaction only.
update public.push_vendors set dpf_swiss_status = 'active', dpf_read_on = '2026-10-24';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', true, pg_temp.k(2)), 'rejected', 'SIG2-3: a nurse cannot switch it on');
select is(public.register_push_subscription('https://fcm.googleapis.com/fcm/send/syn-902', repeat('B', 87), repeat('a', 22), pg_temp.k(3)) ->> 'result',
  'channel_off', 'SIG2-3: nothing is stored or sent while the organisation has not switched on');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', true, pg_temp.k(4)), 'ok', 'SIG2-3: the administrator switches it on');
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', true, pg_temp.k(4)), 'duplicate', 'idempotent');
reset role;
select is((select count(*)::int from public.audit_events where table_name = 'organization_push_settings' and command = 'set_outside_push'
           and actor_id = '00000000-0000-4000-a000-000000000905'), 1, 'the switch is audited with who and the command');

-- SIG2-1: opt-in, vendors by endpoint host ----------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.register_push_subscription('https://web.push.apple.com/syn-902', repeat('B', 87), repeat('a', 22), pg_temp.k(10)) ->> 'result',
  'not_available', 'SIG2-1: an Apple endpoint is refused (D-33)');
select is(public.register_push_subscription('https://updates.push.services.mozilla.com/wpush/v2/syn-902', repeat('B', 87), repeat('a', 22), pg_temp.k(11)) ->> 'result',
  'not_available', 'SIG2-1: a Mozilla endpoint is refused (D-33)');
select is(public.register_push_subscription('https://fcm.googleapis.com.evil.example/syn', repeat('B', 87), repeat('a', 22), pg_temp.k(12)) ->> 'result',
  'not_available', 'SIG2-1: a look-alike host is refused (exact host or a dot-suffix only)');
select is(public.register_push_subscription('http://fcm.googleapis.com/fcm/send/syn', repeat('B', 87), repeat('a', 22), pg_temp.k(13)) ->> 'result',
  'not_available', 'SIG2-1: plain http is refused');
select is((select count(*)::int from public.push_subscriptions), 0, 'SIG2-1: nothing was stored for a refused endpoint');
select is(public.register_push_subscription('https://fcm.googleapis.com/fcm/send/syn-902', repeat('B', 87), repeat('a', 22), pg_temp.k(14)) ->> 'result',
  'ok', 'SIG2-1: a Google (FCM) endpoint is stored');
select is((select vendor from public.push_subscriptions where user_id = pg_temp.u(902)), 'google_fcm', 'with its vendor; she reads her own row');
select is((public.my_push_state() ->> 'active')::boolean, false, 'SIG2-2: not active before the test message was sent');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.register_push_subscription('https://wns2-db5p.notify.windows.com/w/?token=syn-906', repeat('C', 87), repeat('b', 22), pg_temp.k(15)) ->> 'result',
  'ok', 'SIG2-1: a Microsoft (Windows push) endpoint is stored');
select is((select count(*)::int from public.push_subscriptions), 1, 'SIG2-9 / RLS: she reads only her own subscription');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.register_push_subscription('https://fcm.googleapis.com/fcm/send/syn-901', repeat('B', 87), repeat('a', 22), pg_temp.k(16)) ->> 'result',
  'channel_off', 'SIG2-9: a coach without team is not a recipient and cannot opt in');
reset role;

-- SIG2-2: the test message; status on /team ---------------------------------------------------------------------------
-- SIG2-11 fixture: where pg_cron runs (CI), the real job may already have recorded a run; start from none. The row
-- lock held until rollback keeps the job from writing it again during this test.
delete from private.signal_scheduler_runs where organization_id = '00000000-0000-4000-b000-000000000011';
set local role service_role;
select is((select count(*)::int from public.push_dispatch_claim(10) where kind = 'test'), 2, 'SIG2-2: opting in requests one test message per device');
select is((select count(*)::int from public.push_dispatch_claim(10)), 0, 'a claimed item is not handed out twice');
select is(public.push_dispatch_report('test', pg_temp.sub(902), jsonb_build_array(jsonb_build_object('subscription_id', pg_temp.sub(902), 'ok', true))),
  'sent', 'the test message to 902 was accepted by the push service');
select is(public.push_dispatch_report('test', pg_temp.sub(906), jsonb_build_array(jsonb_build_object('subscription_id', pg_temp.sub(906), 'ok', false))),
  'failed', 'the test message to 906 failed');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select string_agg(right(user_id::text, 3) || '=' || active, ',' order by user_id) from public.team_push_status()),
  '902=false,906=false', 'SIG2-11 (2): no run of the scheduled evaluator recorded → nobody is shown as active');
reset role;
-- Fixture (SIG2-11): the scheduled evaluator ran 1 minute ago for org A.
insert into private.signal_scheduler_runs (organization_id, ran_at) values ('00000000-0000-4000-b000-000000000011', now() - interval '1 minute')
on conflict (organization_id) do update set ran_at = excluded.ran_at;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select string_agg(right(user_id::text, 3) || '=' || active, ',' order by user_id) from public.team_push_status()),
  '902=true,906=false', 'SIG2-2: /team shows per member active / not active (a failed last send is not active)');
select is((public.my_push_state() ->> 'active')::boolean, true, 'SIG2-2: /settings says active while the evaluator runs');
reset role;
update private.signal_scheduler_runs set ran_at = now() - interval '6 minutes' where organization_id = '00000000-0000-4000-b000-000000000011';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select string_agg(right(user_id::text, 3) || '=' || active, ',' order by user_id) from public.team_push_status()),
  '902=false,906=false', 'SIG2-11 (2): last scheduled run 6 minutes ago → /team stops showing "aktiv"');
select ok(not (public.my_push_state() ->> 'active')::boolean and not (public.my_push_state() ->> 'evaluator_running')::boolean,
  'SIG2-11 (2): and /settings stops showing "aktiv"');
reset role;
update private.signal_scheduler_runs set ran_at = now() - interval '1 minute' where organization_id = '00000000-0000-4000-b000-000000000011';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from information_schema.routines r
           join information_schema.parameters p on p.specific_name = r.specific_name
           where r.routine_schema = 'public' and r.routine_name = 'team_push_status' and p.parameter_mode = 'OUT'), 5,
  'SIG2-2: team, member, name and active only');
reset role;

-- SIG2-4: outside recipients ------------------------------------------------------------------------------------------
-- 1) The responsible member always (active → pending); a colleague without a planned visit today → outside working time.
update public.push_subscriptions set last_result = 'sent' where user_id = pg_temp.u(906);   -- fixture: 906 active too
select pg_temp.visit(1, - interval '2 hours', pg_temp.u(902));
select pg_temp.eval();
select is(pg_temp.outside(1), '902=responsible:pending,906=team:outside_working_time',
  'SIG2-4: responsible → handed to the sender; colleague outside her planned working time → in the app only');
set local role service_role;
select is((select count(*)::int from public.push_dispatch_claim(10) where kind = 'signal' and ref_id = pg_temp.delivery(1, 902)), 1,
  'the sender receives the responsible member''s row with her device');
select is(public.push_dispatch_report('signal', pg_temp.delivery(1, 902),
            jsonb_build_array(jsonb_build_object('subscription_id', pg_temp.sub(902), 'ok', true))), 'sent', 'SIG2-4: sent');
reset role;
select is(pg_temp.outside(1), '902=responsible:sent,906=team:outside_working_time', 'SIG2-8: the result is recorded on the delivery');
select ok((select sent_at is not null and tapped_at is null from public.signal_outside_deliveries where id = pg_temp.delivery(1, 902)),
  'SIG2-8: send time stored; no tap yet; display is never claimed');
select is((select outside_none_at from public.safety_signals where visit_id = pg_temp.v(1) and ended_at is null), null::timestamptz,
  'SIG2-5: one recipient outside the app → no "kein Empfänger"');
select is((select count(*)::int from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
           where s.visit_id = pg_temp.v(1) and d.reason = 'untaken'), 0, 'SIG2-5: and no immediate Operations delivery');
select is((select count(*)::int from public.audit_events where table_name = 'signal_outside_deliveries' and command = 'push_dispatch'), 1,
  'the send result is audited (system write)');

-- 2) A colleague inside her span (planned visits today from the first start to the last end) → handed to the sender.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (now() at time zone 'Europe/Zurich')::date, t0, t1, false, 'planned', pg_temp.u(906)
from (values (50, time '00:00', time '00:01'), (51, time '23:58', time '23:59')) x(n, t0, t1);
select is(private.member_working_span('00000000-0000-4000-b000-000000000011', pg_temp.u(906), now()) @> now(), true,
  'fixture: 906 is inside her span today (00:00 to 23:59)');
select pg_temp.visit(2, - interval '2 hours', pg_temp.u(902));
select pg_temp.eval();
select is(pg_temp.outside(2), '902=responsible:pending,906=team:pending', 'SIG2-4: a colleague inside her span → handed to the sender');
select is(private.member_working_span('00000000-0000-4000-b000-000000000011', pg_temp.u(906), now() + interval '2 days'), null::tstzrange,
  'SIG2-4: on a day without planned visits she has no planned working time');

-- 3) No subscription → not_active.
delete from public.push_subscriptions where user_id = pg_temp.u(906);
select pg_temp.visit(3, - interval '2 hours', pg_temp.u(902));
select pg_temp.eval();
select is(pg_temp.outside(3), '902=responsible:pending,906=team:not_active', 'SIG2-4: no subscription → not_active');

-- 4) Every send fails → nobody outside → Operations at once (SIG2-5).
set local role service_role;
select is(public.push_dispatch_report('signal', pg_temp.delivery(3, 902),
            jsonb_build_array(jsonb_build_object('subscription_id', pg_temp.sub(902), 'ok', false))), 'failed', 'the only send fails');
reset role;
select ok((select outside_none_at is not null and escalated_at is not null from public.safety_signals where visit_id = pg_temp.v(3) and ended_at is null),
  'SIG2-5: every send failed → "kein Empfänger ausserhalb der App", escalated at once');
select is(pg_temp.outside(3), '902=responsible:failed,904=untaken:not_active,906=team:not_active',
  'SIG2-5 / SIG2-7: Operations has the untaken delivery immediately (in the app; 904 did not opt in)');

-- 5) The sender does not report within 2 minutes → failed (timeout) → Operations at once. The clock is not faked: the
--    fixture moves decided_at back with triggers off (the guard refuses it otherwise, checked first).
select throws_ok($$ update public.signal_outside_deliveries set decided_at = now() - interval '3 minutes' where id = pg_temp.delivery(2, 902) $$,
  '42501', null, 'decided_at cannot be changed once written (the guard)');
set local session_replication_role = replica;
update public.signal_outside_deliveries set decided_at = now() - interval '3 minutes' where id in (pg_temp.delivery(2, 902), pg_temp.delivery(2, 906));
set local session_replication_role = origin;
select pg_temp.eval();
select is((select string_agg(result || ':' || failure, ',') from public.signal_outside_deliveries where id in (pg_temp.delivery(2, 902), pg_temp.delivery(2, 906))),
  'failed:timeout,failed:timeout', 'SIG2-5: not reported within 2 minutes → failed (fail closed)');
select ok((select outside_none_at is not null and escalated_at is not null from public.safety_signals where visit_id = pg_temp.v(2) and ended_at is null),
  'SIG2-5: then Operations at once');

-- SIG2-5: the CGR-41 pgTAP: uncovered hospital-discharge visit, nobody has a planned visit outside the app -------------
insert into public.matching_requests (organization_id, case_id, request_title, region, urgency, status, referral_type, selected_team_id)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'Teamsuche SIG2', 'Bern West', 'mittel',
        'accepted', 'hospital_discharge', '00000000-0000-4000-a000-000000000101');
select pg_temp.visit(4, interval '20 hours', null, '00000000-0000-4000-a000-000000000208');
-- 902's planned visits today are her span; for this case nobody of the team is in a span: move 902's fixtures away.
update public.care_visits set visit_date = visit_date - 3 where id in (pg_temp.v(1), pg_temp.v(2), pg_temp.v(3));
update public.care_visits set visit_date = visit_date - 3 where id in (pg_temp.v(50), pg_temp.v(51));
update public.push_subscriptions set last_result = 'sent' where user_id = pg_temp.u(902);   -- fixture: 902 active again (her last send failed above)
select pg_temp.eval();
select is(pg_temp.outside(4), '902=team:outside_working_time,904=untaken:not_active,906=team:not_active',
  'SIG2-5 (CGR-41): zero outside recipients → Operations has the delivery at once');
select ok((select outside_none_at is not null and escalated_at is not null and taken_by is null
           from public.safety_signals where visit_id = pg_temp.v(4) and ended_at is null),
  'SIG2-5: the signal records "kein Empfänger ausserhalb der App" without waiting for signal_untaken');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select outside_none from public.my_signals() where visit_id = pg_temp.v(4)), true,
  'SIG2-5: Operations reads why it has the signal (kein Empfänger ausserhalb der App)');
reset role;

-- SIG2-7: the untaken step goes to Operations only; outside only to those who opted in -------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.register_push_subscription('https://fcm.googleapis.com/fcm/send/syn-904', repeat('D', 87), repeat('c', 22), pg_temp.k(20)) ->> 'result',
  'ok', 'Operations may opt in');
reset role;
update public.push_subscriptions set last_result = 'sent', test_requested_at = null where user_id = pg_temp.u(904);   -- fixture: test sent
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'signal_untaken', 'P1', 0, null, pg_temp.k(21)), 'ok',
  'fixture: untaken after 0 minutes');
reset role;
select pg_temp.visit(5, - interval '2 hours', pg_temp.u(902));
select pg_temp.eval();
select is((select string_agg(right(d.recipient_id::text, 3) || '=' || d.reason, ',' order by d.recipient_id)
           from public.signal_deliveries d join public.safety_signals s on s.id = d.signal_id
           where s.visit_id = pg_temp.v(5) and d.reason = 'untaken'), '904=untaken',
  'SIG2-7: the untaken step goes to Operations, never to the whole team');
-- SIG2-12: with no watched hours recorded no push goes to Operations; the signal is in the app.
select is((select o.result from public.signal_outside_deliveries o where o.id = pg_temp.delivery(5, 904)), 'outside_working_time',
  'SIG2-12: no watched hours recorded → Operations outside the app: outside_working_time');
select ok(pg_temp.delivery(5, 904) is not null, 'SIG2-12: the in-app delivery to Operations is present');
-- Inside a watched period (fixture: every day 00:00-24:00, so the run hour does not matter) → handed to the sender.
insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
select '00000000-0000-4000-b000-000000000011', d, time '00:00', time '24:00' from generate_series(1, 7) d;
select pg_temp.visit(9, - interval '2 hours', pg_temp.u(902));
select pg_temp.eval();
select is((select o.result from public.signal_outside_deliveries o where o.id = pg_temp.delivery(9, 904)), 'pending',
  'SIG2-7 / SIG2-12: inside the watched hours, outside the app to the Operations member who opted in');
set local role service_role;
select is(public.push_dispatch_report('signal', pg_temp.delivery(9, 904),
            jsonb_build_array(jsonb_build_object('subscription_id', pg_temp.sub(904), 'ok', true))), 'sent',
  'SIG2-12 / SIG2-13: the Operations push inside a watched period is sent (test transport)');
reset role;
delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';

-- SIG2-8: a tap is recorded; nothing else ------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_push_tap(), 1, 'SIG2-8: opening NAVORA from the message records the tap on her sent row');
select is(public.record_push_tap(), 0, 'a second open records nothing more');
select ok((select count(*) > 0 and bool_and(recipient_id = pg_temp.u(902)) from public.signal_outside_deliveries),
  'RLS: she reads only her own outside rows');
reset role;
select throws_ok($$ delete from public.signal_outside_deliveries where id = pg_temp.delivery(1, 902) $$,
  '42501', null, 'outside deliveries are never deleted');

-- SIG2-9: P2/P3, other organisation, channel off ---------------------------------------------------------------------
select pg_temp.visit(6, - interval '20 minutes', pg_temp.u(902));
select pg_temp.eval();
select is(pg_temp.outside(6), '', 'SIG2-9: a P2 overdue visit has no delivery, so nothing outside');
select is((select count(*)::int from public.signal_outside_deliveries where organization_id = '00000000-0000-4000-b000-000000000012'), 0,
  'SIG2-9: nothing outside for another organisation (channel off there)');
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.team_push_status()), 0, 'SIG2-9: org B sees no status of org A''s members');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_outside_push('00000000-0000-4000-b000-000000000011', false, pg_temp.k(30)), 'ok', 'the administrator switches it off');
reset role;
select pg_temp.visit(7, - interval '2 hours', pg_temp.u(902));
select pg_temp.eval();
select is(pg_temp.outside(7), '902=responsible:-,904=untaken:-,906=team:-',
  'SIG2-3: channel off → SIG1 unchanged, no outside row, no immediate step beyond SIG1');

-- SIG2-1: switching off deletes the subscription -----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.unregister_push_subscription(null, pg_temp.k(40)), 'ok', 'SIG2-1: she switches it off');
select is((select count(*)::int from public.push_subscriptions), 0, 'SIG2-1: her subscription is deleted');
select is(public.unregister_push_subscription(null, pg_temp.k(41)), 'unchanged', 'switching off again changes nothing');
reset role;
select is((select count(*)::int from public.audit_events where table_name = 'push_subscriptions' and changed ->> 'deleted' = 'true'
           and actor_id = '00000000-0000-4000-a000-000000000902'), 1, 'the deletion is audited (vendor only, no endpoint)');

-- SIG2-6: watched hours -----------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_watched_hours('00000000-0000-4000-b000-000000000011',
  (select jsonb_agg(jsonb_build_object('weekday', d, 'starts', '07:00', 'ends', '20:00')) from generate_series(1, 7) d), pg_temp.k(50)), 'ok',
  'SIG2-6: the administrator records watched hours 07:00-20:00 every day');
select is(public.set_watched_hours('00000000-0000-4000-b000-000000000011', '[{"weekday": 1, "starts": "07:00", "ends": "12:00"},
  {"weekday": 1, "starts": "11:00", "ends": "20:00"}]'::jsonb, pg_temp.k(51)), 'invalid', 'overlapping periods are refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_watched_hours('00000000-0000-4000-b000-000000000011', '[]'::jsonb, pg_temp.k(52)), 'rejected', 'a nurse cannot change them');
reset role;
-- 2026-10-26 is a Monday.
select is(private.watched_raise_at('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-26 08:00')), pg_temp.zurich('2026-10-26 08:00'),
  'SIG2-6: a window opening at 08:00 (inside) opens as today');
select is(private.watched_raise_at('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-26 22:00')), pg_temp.zurich('2026-10-26 18:00'),
  'SIG2-13: a window opening at 22:00 (outside 07:00-20:00) is raised at 18:00 (end minus 2 h)');
select is(private.watched_raise_at('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-27 05:00')), pg_temp.zurich('2026-10-26 18:00'),
  'SIG2-13: a window opening at 05:00 is raised at 18:00 the evening before');
select ok(private.watched_inside('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-26 18:00')),
  'SIG2-13: the raise time 18:00 lies inside a watched period (start inclusive, end exclusive)');
select ok(not private.watched_inside('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-26 20:00')),
  'SIG2-13 / SIG2-12: the end instant 20:00 is outside (the old raise time)');
select ok(private.watched_inside('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-26 14:00'))
          and not private.watched_inside('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-26 22:00')),
  'SIG2-12: 14:00 is inside (Operations push sent), 22:00 is outside (outside_working_time)');
-- SIG2-14: the look-ahead predicate at fixed instants (a hospital visit 30 h after the instant: its window opens 6 h after it).
select is((select string_agg(to_char(i, 'HH24:MI') || '=' || private.lookahead_raised('00000000-0000-4000-b000-000000000011',
                               pg_temp.zurich('2026-10-26 ' || i), pg_temp.zurich('2026-10-26 ' || i) + interval '6 hours'), ',' order by i)
           from unnest(array[time '03:00', time '12:00', time '17:59', time '18:00', time '19:30', time '22:30']) i),
  '03:00=false,12:00=false,17:59=false,18:00=true,19:30=true,22:30=true',
  'SIG2-14: at 03:00 and 12:00 the window opens inside (not yet); from 18:00 a window opening outside is raised');
select ok(not private.lookahead_raised('00000000-0000-4000-b000-000000000012', pg_temp.zurich('2026-10-26 22:30'), pg_temp.zurich('2026-10-27 04:30')),
  'SIG2-14: with no watched hours the effective rule applies at every instant');
-- SIG2-13: watched 07:00-08:30 only → a window opening at 22:00 is raised at 07:00 (the start bounds it).
reset role;
update public.organization_watched_hours set ends = time '08:30' where organization_id = '00000000-0000-4000-b000-000000000011';
select is(private.watched_raise_at('00000000-0000-4000-b000-000000000011', pg_temp.zurich('2026-10-26 22:00')), pg_temp.zurich('2026-10-26 07:00'),
  'SIG2-13: watched 07:00-08:30 only, window opens 22:00 → raised at 07:00 (never before the start)');
update public.organization_watched_hours set ends = time '20:00' where organization_id = '00000000-0000-4000-b000-000000000011';
select is(private.watched_raise_at('00000000-0000-4000-b000-000000000012', pg_temp.zurich('2026-10-26 22:00')), pg_temp.zurich('2026-10-26 22:00'),
  'SIG2-6: with no watched hours recorded nothing changes');
-- Integration: watched hours [now − 2 h, now − 2 h + 1 min) every day; a hospital visit in 30 h (window opens in 6 h,
-- outside) is raised at the end of the last watched period (about now − 2 h): it is an exception now.
select pg_temp.visit(8, interval '30 hours', null, '00000000-0000-4000-a000-000000000208');
-- "before" is judged with no watched hours, so it does not depend on the clock (0063 run: at 20:30 Zurich the window
-- opening at 02:30 lay outside 07:00-20:00 and was already raised).
delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';
select is((select count(*)::int from private.derived_exceptions('00000000-0000-4000-b000-000000000011') where exception_key = 'visit_uncovered_hospital:' || pg_temp.v(8)), 0,
  'before: the 24 h window opens in 6 h, no exception yet');
insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
select '00000000-0000-4000-b000-000000000011', d, x, x + interval '1 minute'
from generate_series(1, 7) d,
     (select case when t >= time '23:50' then t - interval '15 minutes' else t end as x
      from (select date_trunc('minute', (now() at time zone 'Europe/Zurich') - interval '2 hours')::time as t) q) w;
select is((select count(*)::int from private.derived_exceptions('00000000-0000-4000-b000-000000000011') where exception_key = 'visit_uncovered_hospital:' || pg_temp.v(8)), 1,
  'SIG2-6: the window would open outside the watched hours → raised earlier, now');
select is((select count(*)::int from private.derived_exceptions('00000000-0000-4000-b000-000000000011') where exception_key = 'visit_uncovered:' || pg_temp.v(8)), 0,
  'it is still the hospital-discharge kind (no other rule changes)');

-- SIG2-10: AN2 measure 10 ----------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.pilot_hypotheses((now() at time zone 'Europe/Zurich')::date)
           where measure in ('signal_outside_sent_share', 'signal_taken_within_threshold_share') and team_id = '00000000-0000-4000-a000-000000000101'), 2,
  'SIG2-10: both measures per team');
select ok((select bool_and(suppressed and value is null) from public.pilot_hypotheses((now() at time zone 'Europe/Zurich')::date)
           where measure in ('signal_outside_sent_share', 'signal_taken_within_threshold_share') and team_id = '00000000-0000-4000-a000-000000000101'),
  'SIG2-10: AN1 suppression applies (two people in Testteam Nord)');
reset role;

-- SIG2-11: the scheduled evaluator is seen to run ----------------------------------------------------------------------
select is((select count(*)::int from information_schema.routines where routine_schema = 'public' and routine_name = 'signal_evaluator_health'), 1,
  'SIG2-11: the health reader exists');
select ok(not has_function_privilege('anon', 'public.signal_evaluator_health()', 'execute')
          and not has_function_privilege('authenticated', 'private.evaluate_all_signals()', 'execute')
          and not has_function_privilege('authenticated', 'private.push_dispatch_kick()', 'execute'),
  'SIG2-11: users cannot run the scheduler or the dispatch request; anon cannot read the health');
update private.signal_scheduler_runs set ran_at = now() - interval '1 minute' where organization_id = '00000000-0000-4000-b000-000000000011';
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select string_agg(right(organization_id::text, 3) || '=' || running, ',') from public.signal_evaluator_health()), '011=true',
  'SIG2-11: last run 1 minute ago → no warning for Operations');
reset role;
update private.signal_scheduler_runs set ran_at = now() - interval '6 minutes' where organization_id = '00000000-0000-4000-b000-000000000011';
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select string_agg(right(organization_id::text, 3) || '=' || running, ',') from public.signal_evaluator_health()), '011=false',
  'SIG2-11: last run 6 minutes ago → "Signalprüfung läuft nicht" for Operations');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is((select string_agg(right(organization_id::text, 3) || '=' || running, ',') from public.signal_evaluator_health()), '011=false',
  'SIG2-11: and for /admin of the organisation');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select string_agg(right(organization_id::text, 3), ',') from public.signal_evaluator_health()), '012',
  'SIG2-11: another organisation''s administrator sees only her own organisation');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.signal_evaluator_health()), 0, 'SIG2-11: a nurse reads no evaluator health');
reset role;
-- A page poll does not count as a scheduled run; the scheduled entry point does.
select pg_temp.eval();
select ok((select ran_at < now() - interval '5 minutes' from private.signal_scheduler_runs where organization_id = '00000000-0000-4000-b000-000000000011'),
  'SIG2-11 (1): a page-poll evaluation records no scheduled run');
select private.evaluate_all_signals();
select ok((select ran_at = now() from private.signal_scheduler_runs where organization_id = '00000000-0000-4000-b000-000000000011')
          and private.signal_evaluator_live('00000000-0000-4000-b000-000000000011'),
  'SIG2-11 (1): the scheduled evaluator records its run time');
select is(private.push_dispatch_kick(), false,
  'SIG2-11 (3): without the channel on, pg_net and the Vault entries no dispatch request is sent (fail closed: 2-minute timeout)');
create function pg_temp.cron_has_evaluator() returns boolean language plpgsql as $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then return true; end if;
  return exists (select 1 from cron.job where command like '%private.evaluate_all_signals()%');
end;
$$;
select ok(pg_temp.cron_has_evaluator(), 'SIG2-11: when pg_cron exists, cron.job contains the evaluator job');

select * from finish();
rollback;
