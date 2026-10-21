-- F3: reasoned, append-only time corrections; no future times; no out-of-order timelines.
-- Users (supabase/seed.sql): coach …901 (org A, no team) · nurse …902 (Testteam Nord) · foreign …903 (org B)
begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select ok(not has_table_privilege('authenticated', 'public.visit_time_corrections', 'insert'),
  'authenticated cannot insert corrections directly');
select function_privs_are('public', 'correct_visit_time', array['bigint','timestamp with time zone','text','uuid'],
  'anon', array[]::text[], 'anon cannot correct times');

-- Build a timeline on visit 501 (all events share now(): one transaction).
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.depart_visit('00000000-0000-4000-a000-000000000501', 'f3000000-0000-4000-8000-000000000001'), 'ok', 'depart');
select is(public.start_visit('00000000-0000-4000-a000-000000000501', 'f3000000-0000-4000-8000-000000000002'), 'ok', 'start');
select is(public.complete_visit('00000000-0000-4000-a000-000000000501', 'f3000000-0000-4000-8000-000000000003'), 'ok', 'complete');

create temp table ev as
  select id, event_type from public.visit_events where visit_id = '00000000-0000-4000-a000-000000000501';

select is(
  public.correct_visit_time((select id from ev where event_type = 'departed'), now() - interval '30 minutes',
                            'Losfahren vergessen zu tippen', 'f3000000-0000-4000-8000-000000000010'),
  'ok', 'a team member corrects the departure time with a reason');
select is(
  public.correct_visit_time((select id from ev where event_type = 'departed'), now() - interval '30 minutes',
                            'Losfahren vergessen zu tippen', 'f3000000-0000-4000-8000-000000000010'),
  'duplicate', 'the same key again is a duplicate');
select is(
  (select (events -> 0 ->> 'corrected')::boolean from public.field_visits(current_date)
   where visit_id = '00000000-0000-4000-a000-000000000501'),
  true, 'field_visits marks the corrected event');
select is(
  (select ((events -> 0 ->> 'recorded_at')::timestamptz - (events -> 0 ->> 'at')::timestamptz)
   from public.field_visits(current_date) where visit_id = '00000000-0000-4000-a000-000000000501'),
  interval '30 minutes', 'effective time is the correction; the recorded time stays visible');
select is(
  (select events -> 0 ->> 'reason' from public.field_visits(current_date)
   where visit_id = '00000000-0000-4000-a000-000000000501'),
  'Losfahren vergessen zu tippen', 'the reason is shown with the correction');

select throws_ok(
  format($$ select public.correct_visit_time(%s, now() - interval '1 hour', 'kurz', 'f3000000-0000-4000-8000-000000000011') $$,
         (select id from ev where event_type = 'started')),
  '22023', null, 'a reason shorter than 5 characters is refused');
select throws_ok(
  format($$ select public.correct_visit_time(%s, now() + interval '2 hours', 'Uhrzeit falsch', 'f3000000-0000-4000-8000-000000000012') $$,
         (select id from ev where event_type = 'started')),
  '22023', null, 'a corrected time in the future is refused');
select throws_ok(
  format($$ select public.correct_visit_time(%s, now() - interval '2 hours', 'Ende falsch erfasst', 'f3000000-0000-4000-8000-000000000013') $$,
         (select id from ev where event_type = 'completed')),
  '23514', null, 'completion before the start is refused (no negative care time)');
select throws_ok(
  format($$ select public.correct_visit_time(%s, now() - interval '45 minutes', 'Start falsch erfasst', 'f3000000-0000-4000-8000-000000000014') $$,
         (select id from ev where event_type = 'started')),
  '23514', null, 'a start before the (corrected) departure is refused');
select throws_ok(
  $$ insert into public.visit_time_corrections (organization_id, visit_id, event_id, corrected_at, reason, actor_id, idempotency_key)
     values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000501', 1, now(), 'direkt geschrieben', auth.uid(), gen_random_uuid()) $$,
  '42501', null, 'a direct insert is refused');
reset role;

select is(
  (select occurred_at from public.visit_events where id = (select id from ev where event_type = 'departed')),
  now(), 'the original event is unchanged');
select throws_ok($$ update public.visit_time_corrections set reason = 'geändert' $$, '42501', null,
  'corrections are append-only');
select throws_ok($$ delete from public.visit_time_corrections $$, '42501', null, 'corrections cannot be deleted');

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(
  public.correct_visit_time((select id from ev where event_type = 'started'), now() - interval '5 minutes',
                            'Coach korrigiert', 'f3000000-0000-4000-8000-000000000020'),
  'rejected', 'a coach outside the team cannot correct the team''s times');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(
  public.correct_visit_time((select id from ev where event_type = 'started'), now() - interval '5 minutes',
                            'fremde Organisation', 'f3000000-0000-4000-8000-000000000030'),
  'rejected', 'another organisation cannot correct times');
reset role;

select * from finish();
rollback;
