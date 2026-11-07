-- F2: field state machine (planned → on_the_way → started ↔ paused → completed) and visit_events.
-- Users (supabase/seed.sql): coach …901 (org A, no team) · nurse …902 (Testteam Nord …101)
-- Visits: 501 planned (Nord) · 503 on_the_way (West)
begin;
create extension if not exists pgtap with schema extensions;

select plan(24);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Contract ----------------------------------------------------------------------------
select has_table('public', 'visit_events', 'visit_events exists');
select ok(not has_table_privilege('authenticated', 'public.visit_events', 'insert'), 'authenticated cannot insert events');
select ok(not has_table_privilege('anon', 'public.visit_events', 'select'), 'anon cannot read events');
select function_privs_are('public', 'pause_visit', array['uuid','uuid'], 'anon', array[]::text[], 'anon cannot pause visits');

-- Full field path as the nurse ----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is(public.pause_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000000'),
  'rejected', 'pause on a planned visit is rejected');
select is(public.depart_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000001'),
  'ok', 'depart: planned → on_the_way');
select is(public.depart_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000001'),
  'duplicate', 'the same key again is a duplicate, not a second departure');
select is(public.start_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000002'),
  'ok', 'start: on_the_way → started');
select is(public.pause_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000003'),
  'ok', 'pause: started → paused');
select is(public.complete_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000004'),
  'rejected', 'complete while paused is rejected (resume first)');
select is(public.resume_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000005'),
  'ok', 'resume: paused → started');
select is(public.complete_visit('00000000-0000-4000-a000-000000000501', 'f2000000-0000-4000-8000-000000000006'),
  'ok', 'complete: started → completed');

select results_eq(
  $$ select event_type from public.visit_events
     where visit_id = '00000000-0000-4000-a000-000000000501' order by id $$,
  $$ values ('departed'), ('started'), ('paused'), ('resumed'), ('completed') $$,
  'exactly one event per transition, in order (the duplicate wrote none)');
-- RLS3-4 (0070): `actor_id` is not selectable through the table API, so the write check reads as the table owner.
reset role;
select is(
  (select count(*)::int from public.visit_events
   where visit_id = '00000000-0000-4000-a000-000000000501'
     and actor_id = '00000000-0000-4000-a000-000000000902' and idempotency_key is not null and command is not null),
  5, 'every event carries actor, command and idempotency key');
set local role authenticated;
select is(
  (select jsonb_array_length(events) from public.field_visits((private.now() at time zone 'Europe/Zurich')::date)
   where visit_id = '00000000-0000-4000-a000-000000000501'),
  5, 'field_visits returns the timeline');
select is(
  (select events -> 0 ->> 'type' from public.field_visits((private.now() at time zone 'Europe/Zurich')::date)
   where visit_id = '00000000-0000-4000-a000-000000000501'),
  'departed', 'timeline entries carry the event type');

-- Negative paths -------------------------------------------------------------------------
select is(public.depart_visit('00000000-0000-4000-a000-000000000503', 'f2000000-0000-4000-8000-000000000007'),
  'rejected', 'nurse cannot move a visit of another team');
select throws_ok(
  $$ update public.care_visits set status = 'on_the_way' where id = '00000000-0000-4000-a000-000000000502' $$,
  '23514', null, 'a direct update started → on_the_way is blocked by the state machine');
reset role;

-- Direct REST-style writes as the nurse
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok(
  $$ insert into public.visit_events (organization_id, visit_id, event_type, from_status, to_status)
     values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000502', 'completed', 'started', 'completed') $$,
  '42501', null, 'a nurse cannot write a fake event');
reset role;

select throws_ok(
  $$ update public.visit_events set occurred_at = private.now() - interval '1 hour' $$,
  '42501', null, 'events are append-only, even for the database owner');
select throws_ok(
  $$ delete from public.visit_events $$,
  '42501', null, 'events cannot be deleted');

-- Coach outside the team
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.depart_visit('00000000-0000-4000-a000-000000000502', 'f2000000-0000-4000-8000-000000000008'),
  'rejected', 'a coach who is not in the team cannot move its visit');
reset role;

-- Maintenance status changes are audited but are not timeline events
update public.care_visits set status = 'cancelled' where id = '00000000-0000-4000-a000-000000000502';
select is(
  (select count(*)::int from public.visit_events where visit_id = '00000000-0000-4000-a000-000000000502'),
  0, 'a maintenance status change (cancelled) writes no timeline event');
select ok(
  exists (select 1 from public.audit_events where entity_id = '00000000-0000-4000-a000-000000000502'),
  'but it is audited');

select * from finish();
rollback;
