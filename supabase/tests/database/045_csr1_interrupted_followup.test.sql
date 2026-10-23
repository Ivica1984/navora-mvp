-- CSR1, eighth PR (migration 0045, ADR-056): CGR-25 (OPS1, advisory S2), the PO's strict provisional default in
-- `docs/agents/briefs/CSR1.md` (2026-10-23 11:25; Clinical Governance Report section 2026-10-23 10:29).
-- A visit ended as not completed keeps a signal (`visit_interrupted`, P2, PROVISIONAL until D-31) for its team and for
-- Operations until a person records the follow-up decision ("Folgeeinsatz geplant", "nicht mehr nötig", other with a
-- note). A close without a listed reason is refused.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · coach …901
--        (coordinator of org A, in no team) · fremd …903 (admin of org B) · c4500000-…-907 (nurse of org A in
--        Testteam Mitte only, created here). All data synthetic; every step goes through the real commands, except
--        one exception close written as the table owner to stand for a close made before 0045 (marked below).
begin;
create extension if not exists pgtap with schema extensions;

select plan(46);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Surface -----------------------------------------------------------------------------------------------------------
select ok(has_function_privilege('authenticated', 'public.record_interruption_followup(uuid, text, text, uuid)', 'execute'),
  'members can call the follow-up decision');
select ok(not has_function_privilege('anon', 'public.record_interruption_followup(uuid, text, text, uuid)', 'execute'),
  'anon cannot');
select is((select priority || '/' || coalesce(amount::text, '-') || '/' || coalesce(escalate_to_p1_after_hours::text, '-')
           from public.exception_rules where exception_type = 'visit_interrupted'),
  'P2/-/-', 'visit_interrupted: P2, raised at once, not escalating (PROVISIONAL, D-31)');
select ok(private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'visit_interrupted'),
  'CGR-25: visit_interrupted closes only with its cause');
select ok(not private.exception_is_safety('00000000-0000-4000-b000-000000000011', 'visit_interrupted'),
  'it is not made a safety exception');

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
values ('00000000-0000-0000-0000-000000000000', 'c4500000-0000-4000-8000-000000000907', 'authenticated', 'authenticated',
        'mitte.csr1h@navora.test', '', now(), '{}', '{}', now(), now(), '', '', '', '');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', 'c4500000-0000-4000-8000-000000000907', 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', 'c4500000-0000-4000-8000-000000000907', 'registered_nurse');

create temp table fx (name text primary key, id uuid not null, at timestamptz not null);
grant select on fx to authenticated;
insert into fx values
  ('transfer', '00000000-0000-4000-a045-000000000001', now() - interval '20 minutes'),  -- client_transferred; team decides
  ('declined', '00000000-0000-4000-a045-000000000002', now() - interval '20 minutes'),  -- client_declined; coordinator decides
  ('running',  '00000000-0000-4000-a045-000000000003', now() - interval '20 minutes'),  -- stays started: wrong state
  ('next',     '00000000-0000-4000-a045-000000000004', now() + interval '10 minutes');  -- the case's next planned visit

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, services_provided,
                                billable, status, planned_minutes_a, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (f.at at time zone 'Europe/Zurich')::date, date_trunc('minute', (f.at at time zone 'Europe/Zurich')::time),
       array['Grundpflege'], false, 'planned', 30, '00000000-0000-4000-a000-000000000902'
from fx f;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.ops(n text) returns table (exception_key text, priority text, closable boolean, detail text) language sql as $$
  select x.exception_key, x.priority, x.closable, x.detail from public.operations_exceptions() x
  where x.exception_type = 'visit_interrupted' and x.entity_id = pg_temp.vid(n) $$;
create function pg_temp.team(n text) returns bigint language sql as $$
  select count(*) from public.team_visit_alerts() x where x.exception_type = 'visit_interrupted' and x.visit_id = pg_temp.vid(n) $$;

-- Start and end the visits through the real commands ----------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.vid('transfer'), 'a4500000-0000-4000-8000-000000000001'), 'ok', 'the nurse starts the first visit');
select is(public.start_visit(pg_temp.vid('declined'), 'a4500000-0000-4000-8000-000000000002'), 'ok', 'and the second');
select is(public.start_visit(pg_temp.vid('running'), 'a4500000-0000-4000-8000-000000000003'), 'ok', 'and the third');
select is(public.end_visit_not_completed(pg_temp.vid('transfer'), 'client_transferred', 'Synthetisch: ins Spital gebracht',
          'a4500000-0000-4000-8000-000000000004'), 'ok', 'the first ends as not completed: client transferred');
select is(public.end_visit_not_completed(pg_temp.vid('declined'), 'client_declined', null, 'a4500000-0000-4000-8000-000000000005'),
  'ok', 'the second ends as not completed: client declined');
-- The team sees it at once (/team, /field)
select is(pg_temp.team('transfer'), 1::bigint, 'CGR-25: the team sees the interrupted visit');
select is((select priority from public.team_visit_alerts() where visit_id = pg_temp.vid('transfer') and exception_type = 'visit_interrupted'),
  'P2', 'as P2');
select ok((select detail from public.team_visit_alerts() where visit_id = pg_temp.vid('transfer') and exception_type = 'visit_interrupted')
          like '%Klient:in verlegt bzw. ins Spital gebracht – Synthetisch: ins Spital gebracht%',
  'its detail shows the interruption reason and note');
select is((select detail from public.team_visit_alerts() where visit_id = pg_temp.vid('transfer') and exception_type = 'visit_interrupted'),
  (select to_char(v.visit_date, 'DD.MM.') || ' ' || to_char(v.time_start, 'HH24:MI')
          || ' · Klient:in verlegt bzw. ins Spital gebracht – Synthetisch: ins Spital gebracht · nächster geplanter Einsatz: '
          || to_char(n.visit_date, 'DD.MM.') || ' ' || to_char(n.time_start, 'HH24:MI')
   from public.care_visits v, public.care_visits n where v.id = pg_temp.vid('transfer') and n.id = pg_temp.vid('next')),
  'client_transferred: the detail names the case''s next planned visit');
select ok((select detail from public.team_visit_alerts() where visit_id = pg_temp.vid('declined') and exception_type = 'visit_interrupted')
          like '%Klient:in lehnt die Fortsetzung ab' ,
  'another reason: no next-visit line');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team('declined'), 1::bigint, 'every member of the team sees it (care assistant)');
reset role;
select pg_temp.act_as('c4500000-0000-4000-8000-000000000907');
set local role authenticated;
select is(pg_temp.team('transfer'), 0::bigint, 'a nurse of another team does not');
reset role;

-- Operations sees it, cannot close it by hand ------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select priority from pg_temp.ops('transfer')), 'P2', 'CGR-25: Operations sees the interrupted visit (P2)');
select is((select closable from pg_temp.ops('transfer')), false, 'Operations is not offered "Schliessen"');
select is(public.handle_exception((select exception_key from pg_temp.ops('transfer')), 'close', 'Erledigt',
          'a4500000-0000-4000-8000-000000000010'), 'cause_persists', 'a close without a listed reason is refused (cause_persists)');
select is(public.handle_exception((select exception_key from pg_temp.ops('transfer')), 'take', null,
          'a4500000-0000-4000-8000-000000000011'), 'ok', 'Operations can take it over');
select is((select count(*)::int from pg_temp.ops('transfer')), 1, 'it stays listed');
reset role;
select is((select count(*)::int from public.exception_events
           where exception_key = 'visit_interrupted:' || pg_temp.vid('transfer') and kind = 'close'), 0,
  'the refused close wrote nothing');
-- As the table owner: a close row as if written before 0045; it does not hide the exception.
insert into public.exception_events (organization_id, exception_key, kind, text, actor_id)
values ('00000000-0000-4000-b000-000000000011', 'visit_interrupted:' || pg_temp.vid('declined'), 'close', 'Synthetisch: alt',
        '00000000-0000-4000-a000-000000000901');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('declined')), 1, 'an earlier close row does not hide it from Operations');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team('declined'), 1::bigint, 'nor from the team');
reset role;

-- Refusals of the decision -------------------------------------------------------------------------------------------
select pg_temp.act_as('c4500000-0000-4000-8000-000000000907');
set local role authenticated;
select is(public.record_interruption_followup(pg_temp.vid('transfer'), 'follow_up_planned', null, 'a4500000-0000-4000-8000-000000000020'),
  'rejected', 'a member of the organisation outside the visit''s team cannot decide');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.record_interruption_followup(pg_temp.vid('transfer'), 'follow_up_planned', null, 'a4500000-0000-4000-8000-000000000021'),
  'rejected', 'an admin of another organisation cannot');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select throws_ok($$ select public.record_interruption_followup(pg_temp.vid('transfer'), null, null, 'a4500000-0000-4000-8000-000000000022') $$,
  '22023', null, 'CGR-25: a close without a reason is refused');
select throws_ok($$ select public.record_interruption_followup(pg_temp.vid('transfer'), 'client_reached', null, 'a4500000-0000-4000-8000-000000000023') $$,
  '22023', null, 'a reason outside the list is refused');
select throws_ok($$ select public.record_interruption_followup(pg_temp.vid('transfer'), 'other', '  ', 'a4500000-0000-4000-8000-000000000024') $$,
  '22023', null, '"other" without a note is refused');
select is(public.record_interruption_followup(pg_temp.vid('running'), 'no_longer_needed', null, 'a4500000-0000-4000-8000-000000000025'),
  'wrong_state', 'a visit that is not interrupted gets no decision');
reset role;
select is((select count(*)::int from public.visit_status_notes where kind = 'interruption_followup' and visit_id in (select id from fx)), 0,
  'after the refusals no decision was written');
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team('transfer'), 1::bigint, 'and the team still sees it');
reset role;

-- A team member decides: the exception ends with its cause -----------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_interruption_followup(pg_temp.vid('transfer'), 'follow_up_planned', 'Synthetisch: morgen früh',
          'a4500000-0000-4000-8000-000000000030'), 'ok', 'CGR-25: a team member records "Folgeeinsatz geplant"');
select is(public.record_interruption_followup(pg_temp.vid('transfer'), 'follow_up_planned', 'Synthetisch: morgen früh',
          'a4500000-0000-4000-8000-000000000030'), 'duplicate', 'the same request again is a duplicate');
select is(pg_temp.team('transfer'), 0::bigint, 'the team no longer sees it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_interruption_followup(pg_temp.vid('transfer'), 'no_longer_needed', null, 'a4500000-0000-4000-8000-000000000031'),
  'already_decided', 'a second decision by a colleague is refused');
select is((select reason_code || ' / ' || note from public.field_visit_status_notes((select visit_date from public.care_visits where id = pg_temp.vid('transfer')))
           where visit_id = pg_temp.vid('transfer') and kind = 'interruption_followup'),
  'follow_up_planned / Synthetisch: morgen früh', '/field reads the decision with its note');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('transfer')), 0, 'Operations no longer sees it');
select is((select count(*)::int from public.sync_exceptions()) >= 1, true, 'the taken-over exception is auto-closed with a note');
reset role;
select is((select actor_id from public.visit_status_notes where visit_id = pg_temp.vid('transfer') and kind = 'interruption_followup'),
  '00000000-0000-4000-a000-000000000906'::uuid, 'the decision records the actor');
select is((select count(*)::int from public.audit_events
           where table_name = 'visit_status_notes' and command = 'record_interruption_followup'
             and idempotency_key = 'a4500000-0000-4000-8000-000000000030'), 1, 'audit row for the decision');

-- A coordination role decides the other one --------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.record_interruption_followup(pg_temp.vid('declined'), 'no_longer_needed', null, 'a4500000-0000-4000-8000-000000000040'),
  'ok', 'a coordinator (not in the team) records "nicht mehr nötig"');
select is((select count(*)::int from pg_temp.ops('declined')), 0, 'it is gone for Operations');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(pg_temp.team('declined'), 0::bigint, 'and for the team');
reset role;

-- No side effects on the visit ---------------------------------------------------------------------------------------
select is((select string_agg(status, ',' order by name) from fx join public.care_visits v on v.id = fx.id where fx.name in ('declined', 'transfer')),
  'interrupted,interrupted', 'the decision does not change the visits');

select * from finish();
rollback;
