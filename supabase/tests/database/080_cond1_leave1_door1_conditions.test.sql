-- COND1-1 and COND1-2 (migration 0080, ADR-093). Brief `docs/agents/briefs/COND1.md`; specifications in the parent briefs
-- `LEAVE1.md` (*Conditions* LEAVE1-C2, -C4; LEAVE1-C3 is pgTAP 078) and `DOOR1.md` (DOOR1-12, -13, -14).
-- Users: registered nurse …902 and care assistant …906 (org A, Testteam Nord …101) · operations …904 · admin …905 (org A
-- …011). Synthetic users added here: …8001 registered nurse of Testteam Nord (the leaver of LEAVE1-C2 and of the quality
-- event), …8002 a second operations user (opted in to outside delivery; the leaver of the OPS1 take). Cases …208 (Nord)
-- and two synthetic cases …8101, …8102 of Testteam Nord. All data synthetic; every step goes through the real commands,
-- except the steps marked "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(58);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select (case when n < 1000 then '00000000-0000-4000-a000-' else 'a0800000-0000-4000-a000-' end || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.v(n integer) returns uuid language sql immutable as $$
  select ('a0800000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a0800000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.c(n integer) returns uuid language sql immutable as $$
  select ('a0800000-0000-4000-b000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
-- Run p_sql as user p_user through `authenticated` and return its single value as text.
create function pg_temp.as_user(p_user integer, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
-- The SQLSTATE and message p_user's statement fails with, or 'ok'.
create function pg_temp.state(p_user integer, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  execute 'set local role authenticated';
  begin
    execute p_sql;
  exception when others then
    execute 'reset role';
    return sqlstate || ' ' || sqlerrm;
  end;
  execute 'reset role';
  return 'ok';
end $$;
create function pg_temp.owner_state(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end $$;
create function pg_temp.end_(p_who integer, p_key integer) returns text language sql as $$
  select pg_temp.as_user(905, format('select public.end_member_access(%L::uuid, %L, %L::uuid) ->> ''result''',
                                     pg_temp.u(p_who), 'access_withdrawn', pg_temp.k(p_key)))
$$;
create function pg_temp.eval() returns integer language sql as $$
  select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true)
$$;
create function pg_temp.sig(p_n integer) returns uuid language sql as $$
  select id from public.safety_signals where visit_id = pg_temp.v(p_n) and ended_at is null
$$;
create function pg_temp.escalated(p_n integer) returns boolean language sql as $$
  select escalated_at is not null and outside_none_at is not null from public.safety_signals where id = pg_temp.sig(p_n)
$$;
create function pg_temp.ops(p_n integer) returns integer language sql as $$
  select count(*)::int from public.signal_deliveries where signal_id = pg_temp.sig(p_n) and reason = 'untaken'
$$;
-- "8001=responsible:sent,906=team:pending" for the open signal of visit n.
create function pg_temp.outside(p_n integer) returns text language sql as $$
  select coalesce(string_agg(right(d.recipient_id::text, 4) || '=' || d.reason || ':' || coalesce(o.result, '-'), ',' order by d.recipient_id), '')
  from public.signal_deliveries d left join public.signal_outside_deliveries o on o.id = d.id
  where d.signal_id = pg_temp.sig(p_n)
$$;
-- The banner's reading for the care assistant …906 (my_signals) of signal n.
create function pg_temp.banner(p_n integer) returns boolean language sql as $$
  select pg_temp.as_user(906, format('select operations_outside_app from public.my_signals() where signal_id = %L', pg_temp.sig(p_n)))::boolean
$$;
-- The sender (service_role) claims every pending item and reports it accepted by the push service.
create function pg_temp.send_all() returns integer language plpgsql as $$
declare r record; n integer := 0;
begin
  set local role service_role;
  for r in select * from public.push_dispatch_claim(50) where kind = 'signal' loop
    perform public.push_dispatch_report('signal', r.ref_id,
      jsonb_build_array(jsonb_build_object('subscription_id', r.subscription_id, 'ok', true)));
    n := n + 1;
  end loop;
  reset role;
  return n;
end $$;
-- A P1 no-show of visit n today 23:59 (Testteam Nord, case …208); p_user is responsible, departs and records it.
-- VIS1-5: the no-show fixture is dated today, 23:59 (still ahead, so no overdue signal of its own); a visit dated
-- after today cannot be departed or recorded as a no-show (CGR-87). Before VIS1 it was tomorrow 09:00.
create function pg_temp.no_show(p_n integer, p_user integer) returns void language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, billable, status, responsible_user_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.v(p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', pg_temp.today(), '23:59', false, 'planned', pg_temp.u(p_user));
  perform pg_temp.act_as(pg_temp.u(p_user));
  set local role authenticated;
  perform public.depart_visit(pg_temp.v(p_n), pg_temp.k(100 + p_n));
  perform public.record_no_show(pg_temp.v(p_n), 'Synthetisch: niemand öffnet', pg_temp.k(200 + p_n), true);
  reset role;
end $$;

-- Fixtures (as the table owner) ---------------------------------------------------------------------------------------
insert into auth.users (id, email) values (pg_temp.u(8001), 'cond1-l@navora.test'), (pg_temp.u(8002), 'cond1-ops@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8001), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8002), 'operations');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u(8001), 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8001), 'Synthetisch Leaverin'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(8002), 'Synthetisch Disponentin'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u(902), 'Synthetisch Kollegin')
on conflict (organization_id, user_id) do update set display_name = excluded.display_name;
-- The organisation's vendor facts, as a later migration would record them (inside this transaction only).
update public.push_vendors set dpf_swiss_status = 'active', dpf_read_on = '2026-10-24';
delete from private.signal_scheduler_runs where organization_id = '00000000-0000-4000-b000-000000000011';

-- LEAVE1-C2 (CGR-64): a delivery to a person who can no longer act reaches nobody ------------------------------------
select is(pg_temp.as_user(905, format('select public.set_outside_push(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(1))),
  'ok', 'fixture: the administrator switches the outside channel on');
select is(pg_temp.as_user(8001, format('select public.register_push_subscription(%L, %L, %L, %L) ->> ''result''',
            'https://fcm.googleapis.com/fcm/send/syn-8001', repeat('B', 87), repeat('a', 22), pg_temp.k(2))), 'ok',
  'fixture: the nurse …8001 opted in');
select is(pg_temp.as_user(906, format('select public.register_push_subscription(%L, %L, %L, %L) ->> ''result''',
            'https://wns2-db5p.notify.windows.com/w/?token=syn-906', repeat('C', 87), repeat('b', 22), pg_temp.k(3))), 'ok',
  'fixture: the care assistant …906 opted in');
select is(pg_temp.as_user(8002, format('select public.register_push_subscription(%L, %L, %L, %L) ->> ''result''',
            'https://fcm.googleapis.com/fcm/send/syn-8002', repeat('D', 87), repeat('c', 22), pg_temp.k(4))), 'ok',
  'fixture: the operations user …8002 opted in');
update public.push_subscriptions set last_result = 'sent'
where user_id in (pg_temp.u(8001), pg_temp.u(906), pg_temp.u(8002));   -- fixture: all three active
select ok(not private.watched_inside('00000000-0000-4000-b000-000000000011', private.now()),
  'fixture: no watched period runs (outside the watched hours)');

-- Signal 1: only the nurse …8001 is reached outside the app (…902 did not opt in; …906 has no planned working time today).
select pg_temp.no_show(1, 8001);
select pg_temp.eval();
select is(pg_temp.outside(1), '0902=team:not_active,0906=team:outside_working_time,8001=responsible:pending',
  'fixture: signal 1 is handed to the sender for …8001 only');
-- Signal 2: the colleague …906 is inside her planned working time too.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       pg_temp.today(), t0, t1, false, 'planned', pg_temp.u(906)
from (values (50, time '00:00', time '00:01'), (51, time '23:58', time '23:59')) x(n, t0, t1);
-- The operations user …8002 is inside her planned working time today too (the SIG2-4 rule applies to every recipient).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       pg_temp.today(), t0, t1, false, 'planned', pg_temp.u(8002)
from (values (52, time '00:02', time '00:03'), (53, time '23:56', time '23:57')) x(n, t0, t1);
select pg_temp.no_show(2, 8001);
select pg_temp.eval();
select is(pg_temp.outside(2), '0902=team:not_active,0906=team:pending,8001=responsible:pending', 'fixture: signal 2 is handed to the sender for both');
select ok(pg_temp.send_all() >= 3, 'fixture: the sender reports every item sent');
select pg_temp.eval();
select is(pg_temp.outside(1) || ' / ' || pg_temp.outside(2),
  '0902=team:not_active,0906=team:outside_working_time,8001=responsible:sent / 0902=team:not_active,0906=team:sent,8001=responsible:sent', 'fixture: all sent');
select ok(not pg_temp.escalated(1) and pg_temp.ops(1) = 0 and not pg_temp.escalated(2) and pg_temp.ops(2) = 0,
  'before the end: a sent delivery holds SIG2''s immediate step for both signals');
select ok(not pg_temp.banner(1) and not private.signal_step_outside_app(pg_temp.sig(1), private.now()),
  'before the end: the banner forecast and the step agree (Operations not reached outside the app; no watched period)');

-- LEAVE1-C4 fixtures, set up while …8001 and …8002 still have access.
-- (a) An overdue visit of Testteam Nord (07:00 today, not started) and its OPS1 exception, taken by …8002.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(60), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        pg_temp.today(), '07:00', '07:30', false, 'planned', pg_temp.u(902));
create temp table ex as
  select pg_temp.as_user(904, format('select exception_key from public.operations_exceptions() where exception_type = %L and entity_id = %L',
                                     'visit_overdue', pg_temp.v(60))) as key;
select ok((select key from ex) is not null, 'fixture: the overdue visit is an OPS1 exception');
select is(pg_temp.as_user(8002, format('select public.handle_exception(%L, %L, null, %L)', (select key from ex), 'take', pg_temp.k(5))),
  'ok', 'fixture: the operations user …8002 takes it');
select is(pg_temp.as_user(904, format('select taken::text || ''|'' || coalesce(owner_name, ''∅'') from public.operations_exceptions() where exception_key = %L',
                                      (select key from ex))), 'true|Synthetisch Disponentin', 'before the end: Operations reads her take with her name');
-- (b) A quality event on that visit, recorded by …902 (as the table owner) and set in review by …8001.
insert into public.quality_events (id, organization_id, case_id, visit_id, team_id, event_type, severity, title, status, author_id)
values (pg_temp.c(70), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', pg_temp.v(60),
        '00000000-0000-4000-a000-000000000101', 'synthetic', 'low', 'Synthetisches Ereignis', 'open', pg_temp.u(902));
select is(pg_temp.as_user(8001, format('select public.set_quality_event_status(%L, %L, %L, %L)', pg_temp.c(70), 'in_review', '', pg_temp.k(6))),
  'ok', 'fixture: the nurse …8001 sets the event in review (owner)');
select is(pg_temp.as_user(902, format('select claim_ended::text from public.field_quality(%L) where id = %L', pg_temp.today(), pg_temp.c(70))),
  'false', 'before the end: the review is held by a person with access');

-- From here a watched period runs (fixture: every day 00:00-24:00, so the run hour does not matter): Operations is
-- reached outside the app when the step comes (SIG2-12).
insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
select '00000000-0000-4000-b000-000000000011', d, time '00:00', time '24:00' from generate_series(1, 7) d;

-- Her access ends.
select is(pg_temp.end_(8001, 10), 'ok', 'fixture: the administrator ends the access of …8001');
select pg_temp.eval();
select ok(pg_temp.escalated(1), 'LEAVE1-C2: signal 1 (only sent delivery to her) records "kein Empfänger" and is escalated at the next evaluation');
select is(pg_temp.ops(1), (select count(*)::int from private.signal_operations_users('00000000-0000-4000-b000-000000000011')),
  'LEAVE1-C2: and Operations has the untaken delivery');
select ok(pg_temp.ops(1) = 2, 'fixture: both operations users receive it');
select ok(not pg_temp.escalated(2) and pg_temp.ops(2) = 0, 'LEAVE1-C2: a sent delivery to a colleague with open access still holds signal 2');
create temp table ops1 as select pg_temp.ops(1) as n, (select escalated_at from public.safety_signals where id = pg_temp.sig(1)) as at;
select pg_temp.eval();
select ok(pg_temp.ops(1) = (select n from ops1) and (select escalated_at from public.safety_signals where id = pg_temp.sig(1)) = (select at from ops1),
  'LEAVE1-C2: once: a second evaluation delivers nothing more and keeps the step time');
select ok(pg_temp.banner(2) and private.signal_step_outside_app(pg_temp.sig(2), private.now()) and not pg_temp.escalated(2),
  'LEAVE1-C2: signal 2: no step yet, and the banner forecast agrees (a watched period runs when it would fall due)');
select ok(exists (select 1 from public.signal_outside_deliveries o join public.signal_deliveries d on d.id = o.id
                  where d.signal_id = pg_temp.sig(1) and d.recipient_id = pg_temp.u(8002) and o.result in ('pending', 'sent')),
  'fixture: the step to Operations is handed to the sender for …8002');
select ok(pg_temp.banner(1) and private.signal_step_outside_app(pg_temp.sig(1), private.now()),
  'LEAVE1-C2: signal 1: the banner says Operations is reached outside the app, as the step does');

-- LEAVE1-C4 (b): the quality event she held in review.
select is(pg_temp.as_user(902, format('select claim_ended::text || ''|'' || coalesce(person_name, ''∅'') from public.field_quality(%L) where id = %L',
                                      pg_temp.today(), pg_temp.c(70))), 'true|Synthetisch Kollegin',
  'LEAVE1-C4: the team reads her review as ended ("Übernahme beendet – Zugang beendet"); the name shown is the author''s');
select is(pg_temp.as_user(902, format('select count(*)::text from public.field_quality(%L) q where to_jsonb(q)::text like %L',
                                      pg_temp.today(), '%Leaverin%')), '0', 'LEAVE1-C4: no team reader row carries her name');
select is((select status || '|' || right(owner_id::text, 4) from public.quality_events where id = pg_temp.c(70)), 'in_review|8001',
  'LEAVE1-C4: nothing is rewritten (status and owner stay)');
select is(pg_temp.as_user(906, format('select public.set_quality_event_status(%L, %L, %L, %L)', pg_temp.c(70), 'closed',
                                      'Synthetisch: im Team geklärt', pg_temp.k(7))), 'ok',
  'LEAVE1-C4: a team member can still close it (QG1 closing rules unchanged)');

-- LEAVE1-C2 in the banner's step reading: an Operations delivery to a person whose access has ended reaches nobody.
-- LEAVE1-C4 (a): the OPS1 take of …8002.
select is(pg_temp.end_(8002, 11), 'ok', 'fixture: the administrator ends the access of …8002');
select ok(not private.signal_step_outside_app(pg_temp.sig(1), private.now()) and not pg_temp.banner(1),
  'LEAVE1-C2: her pending or sent delivery no longer counts: the banner and the step read "not outside the app"');
select is(pg_temp.as_user(904, format($q$ select taken::text || '|' || taken_by_me::text || '|' || coalesce(owner_name, '∅') || '|'
                                             || coalesce(taken_at::text, '∅') || '|' || array_to_string(flags, ',')
                                          from public.operations_exceptions() where exception_key = %L $q$, (select key from ex))),
  'false|false|∅|∅|take_access_ended', 'LEAVE1-C4: Operations lists her take as untaken, without name or time, flagged "Übernahme beendet – Zugang beendet"');
select is(pg_temp.as_user(902, format($q$ select taken::text || '|' || array_to_string(flags, ',')
                                          from public.team_visit_alerts() where exception_key = %L $q$, (select key from ex))),
  'false|take_access_ended', 'LEAVE1-C4: the team reads it as untaken too');
select is((select count(*)::int from public.exception_events where exception_key = (select key from ex) and kind = 'take'), 1,
  'LEAVE1-C4: nothing is rewritten (her take stays in the log)');
select is(pg_temp.as_user(904, format('select public.handle_exception(%L, %L, null, %L)', (select key from ex), 'take', pg_temp.k(8))),
  'ok', 'LEAVE1-C4: another coordinator takes it over');
select is(pg_temp.as_user(904, format($q$ select taken_by_me::text || '|' || array_to_string(flags, ',') from public.operations_exceptions()
                                          where exception_key = %L $q$, (select key from ex))), 'true|', 'and it reads as hers, without the flag');

-- LEAVE1-C3: every take records the taker's access sequence (pgTAP 078 covers the restore) ---------------------------
select is(pg_temp.as_user(906, format('select public.take_signal(%L, %L) ->> ''result''', pg_temp.sig(2), pg_temp.k(9))), 'ok',
  'fixture: the colleague …906 takes signal 2');
select is((select access_seq from public.signal_takes where signal_id = pg_temp.sig(2) and taker_id = pg_temp.u(906)),
  private.latest_access_end_seq(pg_temp.u(906)), 'LEAVE1-C3: the take records her latest access-end sequence (0 = none)');

-- DOOR1-12: no code at intake either ----------------------------------------------------------------------------------
select is(pg_temp.state(905, format('select public.update_case_intake(%L, %L::jsonb, %L)', '00000000-0000-4000-a000-000000000208',
            '{"access_notes": "Synthetisch: Schlüsselsafe 4711 beim Eingang"}', pg_temp.k(20))),
  '22023 Bitte keinen Code erfassen', 'DOOR1-12: an intake note with a four-digit run is refused');
select is(pg_temp.state(905, format('select public.update_case_intake(%L, %L::jsonb, %L)', '00000000-0000-4000-a000-000000000208',
            '{"access_notes": "Synthetisch: Schlüsselsafe 47-1-1 beim Eingang"}', pg_temp.k(21))),
  '22023 Bitte keinen Code erfassen', 'DOOR1-12: with separators too (the DOOR1-4 guard)');
select is(pg_temp.state(905, format('select public.update_case_intake(%L, %L::jsonb, %L)', '00000000-0000-4000-a000-000000000208',
            '{"access_notes": "Synthetisch: Haus 123, Schlüssel bei der Nachbarin"}', pg_temp.k(22))),
  'ok', 'DOOR1-12: three digits are accepted');
select is((select access_notes from public.cases where id = '00000000-0000-4000-a000-000000000208'),
  'Synthetisch: Haus 123, Schlüssel bei der Nachbarin', 'fixture: the accepted note is stored');
select is(pg_temp.owner_state($q$ update public.cases set access_notes = 'Synthetisch: Code 4711' where id = '00000000-0000-4000-a000-000000000208' $q$),
  '22023 Bitte keinen Code erfassen', 'DOOR1-12: every writer, also the table owner');
-- An existing synthetic row from before the guard (triggers off, as the table owner): unchanged and still updatable.
set local session_replication_role = replica;
update public.cases set access_notes = 'Synthetisch: alter Eintrag 9876' where id = '00000000-0000-4000-a000-000000000210';
set local session_replication_role = origin;
select is(pg_temp.state(905, format('select public.update_case_intake(%L, %L::jsonb, %L)', '00000000-0000-4000-a000-000000000210',
            '{"language_notes": "Synthetisch: Deutsch"}', pg_temp.k(23))), 'ok',
  'DOOR1-12: an unrelated update of a case with an older note is not refused');
select is((select access_notes from public.cases where id = '00000000-0000-4000-a000-000000000210'), 'Synthetisch: alter Eintrag 9876',
  'DOOR1-12: no existing row is rewritten');
-- G-11: the owner's read-only count before the first real import (OWNER_RUNBOOK.md) finds it.
select is((select count(*)::int from public.cases where private.looks_like_code(access_notes)), 1,
  'DOOR1-12 / G-11: the runbook count finds the one older note the guard would refuse');

-- DOOR1-13: one access record, not two ----------------------------------------------------------------------------------
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, assigned_team, assigned_team_id, access_notes) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.c(8101), private.now() - interval '10 days', 'Synthetisch K1', 'Synthetisch', 'K1', 'Bern West',
   'laufend', 'mittel', 'Testteam Nord', '00000000-0000-4000-a000-000000000101', 'Synthetisch: Schlüssel im Briefkasten der Nachbarin'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.c(8102), private.now() - interval '10 days', 'Synthetisch K2', 'Synthetisch', 'K2', 'Bern West',
   'laufend', 'mittel', 'Testteam Nord', '00000000-0000-4000-a000-000000000101', null);
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(81), pg_temp.c(8101), '00000000-0000-4000-a000-000000000101', pg_temp.today() + 3, '08:00', '08:30', false, 'planned'),
       ('00000000-0000-4000-b000-000000000011', pg_temp.v(82), pg_temp.c(8102), '00000000-0000-4000-a000-000000000101', pg_temp.today() + 3, '09:00', '09:30', false, 'planned');
select is(pg_temp.as_user(902, format('select access_notes || ''|'' || intake_on::text from public.field_door_notes(%L) where visit_id = %L',
                                      pg_temp.today() + 3, pg_temp.v(81))),
  'Synthetisch: Schlüssel im Briefkasten der Nachbarin|' || (pg_temp.today() - 10)::text,
  'DOOR1-13: the card reads the intake note with the case''s intake date');
select is(pg_temp.as_user(902, format($q$ select string_agg(coalesce(value, '∅') || ':' || source || ':' || from_intake::text, ',')
                                          from public.field_safety_alert_history(%L) where case_id = %L $q$, pg_temp.today() + 3, pg_temp.c(8101))),
  '∅:referral:true', 'DOOR1-13: intake note only → its one entry is the intake note (source referral)');
select is(pg_temp.as_user(902, format('select public.record_safety_alert_value(%L, %L, %L, %L, %L, %L)', pg_temp.c(8101),
                                      'access_arrangement', 'ja', 'Synthetisch: Schlüssel bei der Nachbarin, 2. Stock', 'team', pg_temp.k(30))),
  'ok', 'fixture: the team records a later value');
select is(pg_temp.as_user(902, format($q$ select string_agg(coalesce(value, '∅') || ':' || source || ':' || from_intake::text, ',')
                                          from public.field_safety_alert_history(%L) where case_id = %L $q$, pg_temp.today() + 3, pg_temp.c(8101))),
  'ja:team:false,∅:referral:true', 'DOOR1-13: intake note plus a later team value → the team value first, the intake note as the earliest entry');
select is((select count(*)::int from public.case_safety_alert_values where case_id = pg_temp.c(8101)), 1,
  'DOOR1-13: the intake note is never copied into the value table');
select is(pg_temp.as_user(902, format('select count(*)::text from public.field_safety_alert_history(%L) where case_id = %L',
                                      pg_temp.today() + 3, pg_temp.c(8102))), '0', 'DOOR1-13: neither → no entry ("nicht erfasst")');
select is(pg_temp.as_user(904, format('select count(*)::text from public.field_safety_alert_history(%L)', pg_temp.today() + 3)), '0',
  'DOOR1-13: Operations reads no history (the readers of the card only, private.reads_visit)');
select is(pg_temp.as_user(8001, format('select count(*)::text from public.field_safety_alert_history(%L)', pg_temp.today() + 3)), '0',
  'LEAVE1-3: a person whose access has ended reads nothing');

-- DOOR1-14 (CGR-61): a clinical category needs a register reference CR-nnn --------------------------------------------
select is(left(pg_temp.owner_state($q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source, approval_ref)
                                       values ('cond1_clinical', 1, 'Synthetisch klinisch', 'clinical', current_date + 3650, 'Synthetischer Test', 'D-17') $q$), 5),
  '23514', 'DOOR1-14: approval_ref "D-17" is refused for a clinical row');
select is(left(pg_temp.owner_state($q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source, approval_ref)
                                       values ('cond1_clinical', 1, 'Synthetisch klinisch', 'clinical', current_date + 3650, 'Synthetischer Test', 'pending') $q$), 5),
  '23514', 'DOOR1-14: "pending" is refused');
select is(left(pg_temp.owner_state($q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source, approval_ref)
                                       values ('cond1_clinical', 1, 'Synthetisch klinisch', 'clinical', current_date + 3650, 'Synthetischer Test', '#396') $q$), 5),
  '23514', 'DOOR1-14: "#396" is refused');
select is(pg_temp.owner_state($q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source)
                                  values ('cond1_organisational', 1, 'Synthetisch organisatorisch', 'organisational', current_date + 3650, 'Synthetischer Test') $q$),
  'ok', 'DOOR1-14: an organisational row needs none (unchanged)');

select * from finish();
rollback;
