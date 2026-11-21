-- QG1: quality events and quality holds (PO brief docs/agents/briefs/QG1.md).
-- Users: nurse …902 (Testteam Nord) · coach …901 (org A, no team) · ops …904 (org A, operations) · foreign admin …903 (org B)
-- Visits: …501, …502 (Testteam Nord, today) · …505 (Testteam Mitte, yesterday)
-- Event types are TEST FIXTURES only; the real list comes from the clinical decision D-16.
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select is((select count(*)::int from public.quality_event_types), 0, 'no clinical event types ship before D-16');
select ok(not has_table_privilege('authenticated', 'public.quality_holds', 'insert'), 'holds only through commands');
select ok(not has_table_privilege('authenticated', 'public.quality_events', 'insert'), 'events only through commands');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_quality_event('00000000-0000-4000-a000-000000000501', 'fall', 'high', private.now(), null,
          'aa000000-0000-4000-8000-000000000001') ->> 'reason', 'type_not_approved', 'without an approved type nothing is recorded');
reset role;

insert into public.quality_event_types (code, label, sets_hold, serious_default, approved_by) values
  ('test_hold', 'Testtyp mit Stopp', true, true, 'pgTAP fixture'),
  ('test_info', 'Testtyp ohne Stopp', false, false, 'pgTAP fixture');

-- Recording -----------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.record_quality_event('00000000-0000-4000-a000-000000000501', 'test_info', 'urgent', private.now(), null,
          'aa000000-0000-4000-8000-000000000002') $$, '22023', null, 'severity from the fixed set');
select is(public.record_quality_event('00000000-0000-4000-a000-000000000505', 'test_info', 'low', private.now(), null,
          'aa000000-0000-4000-8000-000000000003') ->> 'reason', 'not_team_member', 'not from another team''s visit');
select ok((select r ->> 'result' = 'ok' and (r ->> 'hold')::boolean = false
           from (select public.record_quality_event('00000000-0000-4000-a000-000000000501', 'test_info', 'medium', private.now() - interval '10 minutes',
                        'Synthetische Beobachtung', 'aa000000-0000-4000-8000-000000000004') r) x),
  'the nurse records an event from the visit; this type sets no hold');
select is(public.record_quality_event('00000000-0000-4000-a000-000000000501', 'test_info', 'medium', private.now() - interval '10 minutes',
          'Synthetische Beobachtung', 'aa000000-0000-4000-8000-000000000004') ->> 'result', 'duplicate', 'resend is a duplicate');
select ok((select (r ->> 'hold')::boolean from (select public.record_quality_event('00000000-0000-4000-a000-000000000502', 'test_hold', 'high', private.now(),
          null, 'aa000000-0000-4000-8000-000000000005') r) x), 'a type flagged by the clinical list sets a hold');
select ok(private.visit_has_open_hold('00000000-0000-4000-a000-000000000502'), 'the visit is on hold (J5 rule)');
reset role;  -- RLS4-1 (0099): the author is not selectable through the table API; the stored value as owner
select ok((select author_id = '00000000-0000-4000-a000-000000000902' and occurred_at is not null and case_id is not null
           from public.quality_events where event_type = 'test_info'), 'type, severity, time, case, visit and author are stored');

create temp table ev as select id, event_type from public.quality_events where event_type in ('test_info', 'test_hold');
grant select on ev to authenticated;

-- Visibility ---------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from public.quality_events where id in (select id from ev where event_type = 'test_hold')), 1,
  'a coach sees serious events');
select is((select count(*)::int from public.quality_events where id in (select id from ev where event_type = 'test_info')), 0,
  'a coach does not see minor events of a team she is not in');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.quality_events where id in (select id from ev)), 0,
  'operations reads no event content (serious ones reach it as OPS1 exceptions)');
select is((select count(*)::int from public.operations_exceptions() where exception_type = 'quality_serious_open'
           and entity_id in (select id from ev)), 1, 'the serious event is an Operations exception');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.quality_events where id in (select id from ev))
          + (select count(*)::int from public.quality_holds where visit_id = '00000000-0000-4000-a000-000000000502'), 0,
  'another organisation sees nothing');
reset role;

-- Status workflow -------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_quality_event_status((select id from ev where event_type = 'test_info'), 'in_review', null,
          'aa000000-0000-4000-8000-000000000010'), 'ok', 'the team takes the event into review');
select is((select owner_id from public.quality_events where id = (select id from ev where event_type = 'test_info')),
  '00000000-0000-4000-a000-000000000902'::uuid, 'with an owner');
select throws_ok($$ select public.set_quality_event_status((select id from ev where event_type = 'test_info'), 'closed', null,
          'aa000000-0000-4000-8000-000000000011') $$, '22023', null, 'closing needs a note');
select is(public.set_quality_event_status((select id from ev where event_type = 'test_info'), 'closed', 'Mit Angehörigen besprochen',
          'aa000000-0000-4000-8000-000000000012'), 'ok', 'the team closes it with a note');
select is((select string_agg(coalesce(from_status, '-') || '→' || to_status, ',' order by id) from public.quality_event_log
           where event_id = (select id from ev where event_type = 'test_info')), 'open→in_review,in_review→closed',
  'transitions are logged');
select is(public.set_quality_event_status((select id from ev where event_type = 'test_info'), 'in_review', null,
          'aa000000-0000-4000-8000-000000000013'), 'rejected', 'a closed event stays closed');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.set_quality_event_status((select id from ev where event_type = 'test_hold'), 'in_review', null,
          'aa000000-0000-4000-8000-000000000014'), 'ok', 'a coach may review a serious event');
reset role;

-- Holds: set by the team, lifted only by coach/admin with a reason ------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_quality_hold('00000000-0000-4000-a000-000000000501', 'Leistung strittig, Rückfrage beim Team',
          'aa000000-0000-4000-8000-000000000020'), 'ok', 'the team sets a manual hold with a reason');
select is(public.set_quality_hold('00000000-0000-4000-a000-000000000501', 'nochmals', 'aa000000-0000-4000-8000-000000000021'),
  'already_held', 'one open hold per visit');
select is(public.lift_quality_hold((select id from public.quality_holds where visit_id = '00000000-0000-4000-a000-000000000501'),
          'erledigt', 'aa000000-0000-4000-8000-000000000022'), 'rejected', 'the team cannot lift a hold');
select is((select count(*)::int from public.field_quality((private.now() at time zone 'Europe/Zurich')::date) where kind = 'hold' and status = 'open'), 2,
  '/field shows the open holds of the day');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.lift_quality_hold((select id from public.quality_holds where visit_id = '00000000-0000-4000-a000-000000000501'),
          'erledigt', 'aa000000-0000-4000-8000-000000000023'), 'rejected', 'operations cannot lift a hold (provisional, D-16)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select throws_ok($$ select public.lift_quality_hold((select id from public.quality_holds where visit_id = '00000000-0000-4000-a000-000000000501'),
          null, 'aa000000-0000-4000-8000-000000000024') $$, '22023', null, 'lifting needs a reason');
select is(public.lift_quality_hold((select id from public.quality_holds where visit_id = '00000000-0000-4000-a000-000000000501'),
          'Mit Team geklärt, Leistung korrekt', 'aa000000-0000-4000-8000-000000000025'), 'ok', 'a coach lifts the hold with a reason');
reset role;
select ok(not private.visit_has_open_hold('00000000-0000-4000-a000-000000000501'), 'the visit counts again');
select ok(exists (select 1 from public.audit_events where command = 'lift_quality_hold'), 'lifting is audited');
select throws_ok($$ update public.quality_holds set reason = 'anders' where visit_id = '00000000-0000-4000-a000-000000000501' $$,
  '42501', null, 'a lifted hold is immutable');
select throws_ok($$ delete from public.quality_holds $$, '42501', null, 'holds are never deleted');

select * from finish();
rollback;
