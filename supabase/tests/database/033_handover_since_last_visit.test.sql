-- HAND1: "since you were last here" (migration 0033, ADR-047).
-- Case …208 (Testteam Nord …101): nurse …902 (registered nurse), care assistant …906. Here: nurse …907 joins the team
-- without any visit of the client; coach …901 joins Testteam Mitte …102. Foreign admin …903 (org B).
begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.at(d integer, t time) returns timestamptz language sql as $$
  select ((current_date + d) + t) at time zone 'Europe/Zurich'
$$;
-- Entries of the card visit …c0 for the current user.
create function pg_temp.card() returns setof jsonb language sql as $$
  select to_jsonb(s) from public.field_since_last(current_date) s where s.visit_id = 'c3000000-0000-4000-8000-0000000000c0'
$$;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
values ('00000000-0000-0000-0000-000000000000', 'c3000000-0000-4000-8000-000000000907', 'authenticated', 'authenticated',
        'neu.hand1@navora.test', '', now(), '{}', '{}', now(), now(), '', '', '', '');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000907', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', 'c3000000-0000-4000-8000-000000000907', 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'registered_nurse');

-- Three completed visits of case …208: V1 (−5 days, by …902), V2 (−3, by …906), V3 (−1, by …906);
-- a cancelled visit V4 (−2); the card visit …c0 (today 23:00, planned).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000011', x.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       current_date + x.d, x.t, x.t + interval '1 hour', false, x.s
from (values ('c3000000-0000-4000-8000-0000000000a1'::uuid, -5, time '08:00', 'completed'),
             ('c3000000-0000-4000-8000-0000000000a2'::uuid, -3, time '08:00', 'completed'),
             ('c3000000-0000-4000-8000-0000000000a3'::uuid, -1, time '08:00', 'completed'),
             ('c3000000-0000-4000-8000-0000000000a4'::uuid, -2, time '08:00', 'cancelled'),
             ('c3000000-0000-4000-8000-0000000000c0'::uuid,  0, time '22:00', 'planned')) x(id, d, t, s);
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
select '00000000-0000-4000-b000-000000000011', x.id, '00000000-0000-4000-a000-000000000101', e.t, e.f, e.s, x.actor, pg_temp.at(x.d, e.at)
from (values ('c3000000-0000-4000-8000-0000000000a1'::uuid, -5, '00000000-0000-4000-a000-000000000902'::uuid),
             ('c3000000-0000-4000-8000-0000000000a2'::uuid, -3, '00000000-0000-4000-a000-000000000906'::uuid),
             ('c3000000-0000-4000-8000-0000000000a3'::uuid, -1, '00000000-0000-4000-a000-000000000906'::uuid)) x(id, d, actor)
cross join (values ('departed', 'planned', 'on_the_way', time '07:45'), ('started', 'on_the_way', 'started', time '08:00'),
                   ('completed', 'started', 'completed', time '09:00')) e(t, f, s, at);

-- Observations: one during V1 (before …902's last visit ended), one handover in V2 (edited once), one in V3.
insert into public.visit_observations (organization_id, id, visit_id, case_id, team_id, author_id, recorded_at, content, for_handover, supersedes_id, idempotency_key)
values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000b01', 'c3000000-0000-4000-8000-0000000000a1', '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000902', pg_temp.at(-5, '08:30'), 'Synthetisch: alte Beobachtung V1', false, null, gen_random_uuid()),
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000b02', 'c3000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', pg_temp.at(-3, '08:30'), 'Synthetisch: Übergabe erste Fassung', true, null, gen_random_uuid());
insert into public.visit_observations (organization_id, id, visit_id, case_id, team_id, author_id, recorded_at, content, for_handover, supersedes_id, idempotency_key)
values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000b03', 'c3000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', pg_temp.at(-3, '08:40'), 'Synthetisch: Übergabe geänderte Fassung', true,
   'c3000000-0000-4000-8000-000000000b02', gen_random_uuid()),
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000b04', 'c3000000-0000-4000-8000-0000000000a3', '00000000-0000-4000-a000-000000000208',
   '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', pg_temp.at(-1, '08:30'), 'Synthetisch: Beobachtung V3', false, null, gen_random_uuid());

-- C1: a pause and a resume of the case, a cancellation of V4.
insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, actor_id, idempotency_key, created_at) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'pause', 'hospital_stay', '00000000-0000-4000-a000-000000000906', gen_random_uuid(), pg_temp.at(-4, '12:00')),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'resume', null, '00000000-0000-4000-a000-000000000906', gen_random_uuid(), pg_temp.at(-4, '18:00'));
insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, actor_id, idempotency_key, created_at) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-0000000000a4', 'cancelled', 'client_in_hospital', '00000000-0000-4000-a000-000000000906', gen_random_uuid(), pg_temp.at(-4, '12:05'));

-- J6 and J1/J3: primary nurse and medical order changes with reasons (audit trail + change log).
insert into public.audit_events (organization_id, actor_id, actor_role, table_name, entity_id, command, idempotency_key, changed, occurred_at) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000906', 'authenticated', 'cases', '00000000-0000-4000-a000-000000000208',
   'set_primary_nurse', 'c3000000-0000-4000-8000-000000000e01',
   '{"primary_nurse_id": {"old": "00000000-0000-4000-a000-000000000902", "new": "00000000-0000-4000-a000-000000000906"}}', pg_temp.at(-2, '10:00')),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000904', 'authenticated', 'cases', '00000000-0000-4000-a000-000000000208',
   'update_case_intake', 'c3000000-0000-4000-8000-000000000e02',
   '{"medical_order_status": {"old": "requested", "new": "present"}}', pg_temp.at(-2, '11:00'));
insert into public.change_log (organization_id, entity_table, entity_id, command, changes, reason, actor_id, idempotency_key, created_at) values
  ('00000000-0000-4000-b000-000000000011', 'cases', '00000000-0000-4000-a000-000000000208', 'set_primary_nurse', '{}',
   'Synthetisch: Ferienvertretung', '00000000-0000-4000-a000-000000000906', 'c3000000-0000-4000-8000-000000000e01', pg_temp.at(-2, '10:00')),
  ('00000000-0000-4000-b000-000000000011', 'cases', '00000000-0000-4000-a000-000000000208', 'update_case_intake', '{}',
   'Synthetisch: Verordnung eingetroffen', '00000000-0000-4000-a000-000000000904', 'c3000000-0000-4000-8000-000000000e02', pg_temp.at(-2, '11:00'));

-- QG1: one event of Testteam Nord, one of another team on the same case (not visible to the team).
insert into public.quality_events (organization_id, id, created_at, case_id, visit_id, team_id, event_type, severity, title, status, author_id) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000d01', pg_temp.at(-3, '09:30'), '00000000-0000-4000-a000-000000000208',
   'c3000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-a000-000000000101', 'fall', 'medium', 'Synthetisch: Sturz', 'open', '00000000-0000-4000-a000-000000000906'),
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000d02', pg_temp.at(-3, '09:40'), '00000000-0000-4000-a000-000000000208',
   null, '00000000-0000-4000-a000-000000000102', 'fall', 'medium', 'Synthetisch: fremdes Team', 'open', '00000000-0000-4000-a000-000000000901');

-- A different case of the same client (same name), with an observation after the window start.
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, assigned_team_id) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000208', now() - interval '30 days', 'Testfall 08', 'Testfall', '08',
   'Bern West', 'laufend', 'mittel', '00000000-0000-4000-a000-000000000101');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-0000000000f1', 'c3000000-0000-4000-8000-000000000208',
   '00000000-0000-4000-a000-000000000101', current_date - 2, '14:00', '15:00', false, 'completed'),
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-0000000000f2', 'c3000000-0000-4000-8000-000000000208',
   '00000000-0000-4000-a000-000000000101', current_date, '21:00', '21:30', false, 'planned');
-- A case without any history, with a card today.
insert into public.cases (organization_id, id, created_at, name, first_name, last_name, region, status, urgency, assigned_team_id) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-000000000210', now(), 'Testfall 99', 'Testfall', '99',
   'Bern West', 'laufend', 'mittel', '00000000-0000-4000-a000-000000000101');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-0000000000f3', 'c3000000-0000-4000-8000-000000000210',
   '00000000-0000-4000-a000-000000000101', current_date, '20:00', '20:30', false, 'planned');
insert into public.visit_observations (organization_id, visit_id, case_id, team_id, author_id, recorded_at, content, idempotency_key) values
  ('00000000-0000-4000-b000-000000000011', 'c3000000-0000-4000-8000-0000000000f1', 'c3000000-0000-4000-8000-000000000208',
   '00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', pg_temp.at(-2, '14:30'), 'Synthetisch: anderer Fall', gen_random_uuid());

-- The nurse who did V1 ---------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select distinct x ->> 'rule' from pg_temp.card() x), 'since_own_visit', 'her own last completed visit sets the window');
select is((select distinct (x ->> 'since_date')::date from pg_temp.card() x), current_date - 5, 'and the card names its date');
select ok(not exists (select 1 from pg_temp.card() x where x -> 'detail' ->> 'content' like '%alte Beobachtung V1%'),
  'what was recorded before her last visit ended is not repeated');
select is((select x -> 'detail' ->> 'content' from pg_temp.card() x where x ->> 'entry_id' = 'c3000000-0000-4000-8000-000000000b03'),
  'Synthetisch: Übergabe geänderte Fassung', 'a handover from another visit is shown in full');
select is((select x ->> 'author' from pg_temp.card() x where x ->> 'entry_id' = 'c3000000-0000-4000-8000-000000000b03'), 'member:2',
  'with who recorded it as a member label');
select is((select x ->> 'source_visit_date' from pg_temp.card() x where x ->> 'entry_id' = 'c3000000-0000-4000-8000-000000000b03'),
  (current_date - 3)::text, 'and in which visit');
select ok(not exists (select 1 from pg_temp.card() x where x ->> 'entry_id' = 'c3000000-0000-4000-8000-000000000b02'),
  'an edited observation appears once, in its current version');
select is((select count(*)::int from pg_temp.card() x where x ->> 'kind' in ('case_pause', 'case_resume')), 2, 'pause and resume of the case');
select is((select x -> 'detail' ->> 'reason_code' from pg_temp.card() x where x ->> 'kind' = 'visit_cancelled'), 'client_in_hospital',
  'a cancellation with its reason');
select is((select x -> 'detail' ->> 'reason' from pg_temp.card() x where x ->> 'kind' = 'primary_nurse'), 'Synthetisch: Ferienvertretung',
  'a primary-nurse change with its reason');
select ok((select x -> 'detail' ->> 'primary_old' = 'me' and x -> 'detail' ->> 'primary_new' = 'member:2'
           from pg_temp.card() x where x ->> 'kind' = 'primary_nurse'), 'old and new as member labels');
select is((select x -> 'detail' -> 'status' ->> 'new' from pg_temp.card() x where x ->> 'kind' = 'medical_order'), 'present',
  'a medical order change');
select is((select x ->> 'author' from pg_temp.card() x where x ->> 'kind' = 'medical_order'), 'outside',
  'recorded by someone outside the team');
select is((select x -> 'detail' ->> 'status' from pg_temp.card() x where x ->> 'entry_id' = 'c3000000-0000-4000-8000-000000000d01'), 'open',
  'a quality event of the team with its current status');
select is((select count(*)::int from pg_temp.card() x where x ->> 'entry_id' = 'c3000000-0000-4000-8000-000000000d02'), 0,
  'a quality event the team cannot see under QG1 does not appear');
select ok(not exists (select 1 from pg_temp.card() x where x -> 'detail' ->> 'content' like '%anderer Fall%'),
  'entries from a different case of the same client do not appear');
select ok((select bool_and(a <= b) from (select (x ->> 'at')::timestamptz as a, lead((x ->> 'at')::timestamptz) over (order by ord) as b
                                         from pg_temp.card() with ordinality t(x, ord)) s where b is not null), 'oldest first');
select ok(not exists (select 1 from pg_temp.card() x where x::text like '%00000000-0000-4000-a000-000000000906%'
                                                         or x::text like '%00000000-0000-4000-a000-000000000904%'),
  'no user ids leave the database');
select ok((select bool_or(s.detail ->> 'content' like '%anderer Fall%') and not bool_or(s.detail::text like '%Übergabe%')
           from public.field_since_last(current_date) s where s.visit_id = 'c3000000-0000-4000-8000-0000000000f2'),
  'the other case''s card shows that case''s entries only');
reset role;

-- A nurse who never visited the client ---------------------------------------------------------------------------------
select pg_temp.act_as('c3000000-0000-4000-8000-000000000907');
set local role authenticated;
select ok((select bool_and(x ->> 'rule' = 'last_visits' and (x ->> 'lookback')::int = 3 and (x ->> 'since_date')::date = current_date - 5)
           from pg_temp.card() x), 'never here: the last 3 completed visits, from the oldest of them');
select ok(exists (select 1 from pg_temp.card() x where x -> 'detail' ->> 'content' like '%alte Beobachtung V1%'),
  'so the observation of V1 is included');
reset role;
insert into public.handover_settings (organization_id, lookback_visits) values ('00000000-0000-4000-b000-000000000011', 1);
select pg_temp.act_as('c3000000-0000-4000-8000-000000000907');
set local role authenticated;
select is((select distinct (x ->> 'since_date')::date from pg_temp.card() x), current_date - 1, 'the number of visits is configuration');
reset role;
delete from public.handover_settings where organization_id = '00000000-0000-4000-b000-000000000011';

-- Empty state: a card whose case has no history.
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select ok((select count(*) = 1 and bool_and(s.kind is null) and bool_and(s.rule = 'no_visits')
           from public.field_since_last(current_date) s where s.visit_id = 'c3000000-0000-4000-8000-0000000000f3'),
  'nothing recorded: one row with the rule, no entries');
reset role;

-- Access is not widened -------------------------------------------------------------------------------------------------
update public.care_visits set covered_by = '00000000-0000-4000-a000-000000000901' where id = 'c3000000-0000-4000-8000-0000000000c0';
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from pg_temp.card()), 0, 'another team''s nurse (also when covering) sees no entries');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.field_since_last(current_date)), 0, 'another organisation sees nothing');
reset role;
update public.care_visits set covered_by = null where id = 'c3000000-0000-4000-8000-0000000000c0';

-- No extra tap: the start records what the section held --------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
create temp table shown_before as select count(*)::int as n from pg_temp.card() x where x ->> 'kind' is not null;
do $$ begin
  perform public.depart_visit('c3000000-0000-4000-8000-0000000000c0', 'c3000000-0000-4000-8000-000000000e10');
  perform public.start_visit('c3000000-0000-4000-8000-0000000000c0', 'c3000000-0000-4000-8000-000000000e11');
end $$;
reset role;
select is((select count(*)::int from public.handover_shown where visit_id = 'c3000000-0000-4000-8000-0000000000c0'), 1,
  'starting the visit records one handover fact');
select ok((select h.entry_count = b.n and h.rule = 'since_own_visit' and h.nurse_id = '00000000-0000-4000-a000-000000000902'
           from public.handover_shown h, shown_before b where h.visit_id = 'c3000000-0000-4000-8000-0000000000c0'),
  'with the entries the section held and the rule');
select ok(not exists (select 1 from public.handover_shown h where h.visit_id = 'c3000000-0000-4000-8000-0000000000c0'
                      and h.entries::text like '%Synthetisch%'), 'references only, no copy of the content');
select throws_ok($$ delete from public.handover_shown $$, '42501', null, 'the handover fact is append-only');

-- AN1: the share is reported for coordination.
update public.care_visits set status = 'completed' where id = 'c3000000-0000-4000-8000-0000000000c0';
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok(exists (select 1 from public.pilot_kpis(current_date) k where k.kpi = 'handover_shown_before_start' and k.team_id is null
                  and k.note like 'Gezeigt heisst%'), 'AN1 reports the share with its definition');
reset role;

select * from finish();
rollback;
