-- DOOR1 part (a): what the nurse needs at the door (migration 0072, ADR-085). Brief `docs/agents/briefs/DOOR1.md`
-- DOOR1-1, -5, -6, -7, -11, and -8, -9, -10 for these parts. Part (b) (DOOR1-2, -3, -4) follows in its own PR.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · care assistant …906 (Nord) · operations …904 ·
-- admin …905 (org A, no team) · admin …903 (org B). Synthetic users added here: …7201 registered nurse of Testteam Mitte
-- …102 (same organisation, no cover), …7202 registered nurse of Mitte who covers Nord visits, …7204 an account without
-- any membership (stands for a client or partner account). Case …208 (Nord), …205 (Mitte, notes empty). All data
-- synthetic; fixtures are written as the table owner, everything else goes through `authenticated` and the commands.
begin;
create extension if not exists pgtap with schema extensions;

select plan(53);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'ops' then '00000000-0000-4000-a000-000000000904' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'admin_b' then '00000000-0000-4000-a000-000000000903'
                 when 'mitte' then 'a0720000-0000-4000-a000-000000007201' when 'cover' then 'a0720000-0000-4000-a000-000000007202'
                 when 'outsider' then 'a0720000-0000-4000-a000-000000007204' end)::uuid
$$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a0720000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0720000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
-- Run `p_sql` as `p_user` through `authenticated` (RLS and grants apply) and return its single value as text.
create function pg_temp.as_user(p_user text, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.u(p_user)::text, true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;
-- The SQLSTATE `p_user`'s statement fails with, or 'ok'.
create function pg_temp.state(p_user text, p_sql text) returns text language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.u(p_user)::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql;
  exception when others then
    execute 'reset role';
    return sqlstate;
  end;
  execute 'reset role';
  return 'ok';
end $$;
-- What `p_user` reads from field_door_notes for visit n: 'access|language' (null parts as '∅'), or null without a row.
create function pg_temp.door(p_user text, n int) returns text language sql as $$
  select pg_temp.as_user(p_user, format(
    $q$ select coalesce(access_notes, '∅') || '|' || coalesce(language_notes, '∅') from public.field_door_notes(%L) where visit_id = %L $q$,
    (select visit_date from public.care_visits where id = pg_temp.v(n)), pg_temp.v(n)))
$$;
-- Operations' exception line for visit n and type t (as the Operations user).
create function pg_temp.ops_detail(t text, n int) returns text language sql as $$
  select pg_temp.as_user('ops', format($q$ select detail from public.operations_exceptions() where exception_type = %L and entity_id = %L $q$, t, pg_temp.v(n)))
$$;
create function pg_temp.ops_priority(t text, n int) returns text language sql as $$
  select pg_temp.as_user('ops', format($q$ select priority from public.operations_exceptions() where exception_type = %L and entity_id = %L $q$, t, pg_temp.v(n)))
$$;

-- Synthetic accounts and fixtures (as the table owner) -----------------------------------------------------------------
insert into auth.users (id, email) values
  (pg_temp.u('mitte'), 'door1-mitte@navora.test'), (pg_temp.u('cover'), 'door1-cover@navora.test'),
  (pg_temp.u('outsider'), 'door1-outsider@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('cover'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('cover'), 'registered_nurse');

update public.cases set access_notes = 'Synthetisch: Schlüssel beim Nachbarn links, Klingel defekt',
                        language_notes = 'Synthetisch: spricht Italienisch, versteht Deutsch'
where id = '00000000-0000-4000-a000-000000000208';
update public.cases set access_notes = '  ', language_notes = null where id = '00000000-0000-4000-a000-000000000205';

-- v1 Nord today planned · v2 Nord today covered by …7202 (cover runs) · v3 Nord yesterday covered by …7202, final report
-- (cover ended) · v4 Mitte (case …205, empty notes) today · v5, v6, v8 Nord today on the way (no-shows) · v7 Nord tomorrow
-- (HAND1 card) · v9 Nord today started (interruption).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '06:10', '06:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '07:10', '07:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '07:10', '07:40', false, 'completed'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(4), '00000000-0000-4000-a000-000000000205', '00000000-0000-4000-a000-000000000102', pg_temp.today(), '08:10', '08:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(5), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '09:10', '09:40', false, 'on_the_way'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(6), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '09:50', '10:20', false, 'on_the_way'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(7), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() + 1, '09:10', '09:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(8), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '11:10', '11:40', false, 'on_the_way'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(9), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '12:10', '12:40', false, 'started');
update public.care_visits set covered_by = pg_temp.u('cover'), covered_at = private.now(), cover_team_id = '00000000-0000-4000-a000-000000000102'
where id in (pg_temp.v(2), pg_temp.v(3));
insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by, signed_by, signed_at)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(13), pg_temp.v(3), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', 1, 'final', '{}', pg_temp.u('cover'), false,
        pg_temp.u('cover'), pg_temp.u('cover'), private.now() - interval '20 hours');

-- DOOR1-1: access and language notes on the card -----------------------------------------------------------------------
select is(pg_temp.door('rn', 1), 'Synthetisch: Schlüssel beim Nachbarn links, Klingel defekt|Synthetisch: spricht Italienisch, versteht Deutsch',
  'DOOR1-1: a member of the visit''s team reads the access and the language note');
select is(pg_temp.door('ca', 1), 'Synthetisch: Schlüssel beim Nachbarn links, Klingel defekt|Synthetisch: spricht Italienisch, versteht Deutsch',
  'DOOR1-1: the care assistant of the team reads them too');
select is(pg_temp.door('mitte', 1), null, 'DOOR1-1: a member of another team (same organisation, no cover) reads nothing');
select is(pg_temp.door('admin_b', 1), null, 'DOOR1-1: a member of another organisation reads nothing');
select is(pg_temp.door('outsider', 1), null, 'DOOR1-1: an account without membership (client or partner account) reads nothing');
select is(pg_temp.door('ops', 1), null, 'DOOR1-9: Operations reads no door notes');
select is(pg_temp.door('admin', 1), null, 'DOOR1-9: the administrator reads no door notes');
select ok(not has_function_privilege('anon', 'public.field_door_notes(date)', 'execute')
          and has_function_privilege('authenticated', 'public.field_door_notes(date)', 'execute'),
  'DOOR1-1: anon cannot execute field_door_notes; authenticated can (scope inside)');
select is(pg_temp.door('cover', 2), 'Synthetisch: Schlüssel beim Nachbarn links, Klingel defekt|Synthetisch: spricht Italienisch, versteht Deutsch',
  'DOOR1-1: the covering member reads the notes while her cover runs');
select is(pg_temp.door('cover', 1), null, 'DOOR1-1: the covering member reads nothing of a visit she does not cover');
select is(pg_temp.door('cover', 3), null, 'DOOR1-1: after the cover ended (final report) the covering member reads nothing');
select is(pg_temp.door('mitte', 4), '∅|∅', 'DOOR1-1: empty or blank notes come back null, so the card shows "nicht erfasst"');

-- DOOR1-5: "an der Tür" ------------------------------------------------------------------------------------------------
select is(pg_temp.state('rn', format($q$ select public.record_no_show(%L, 'Synthetisch: niemand öffnet', %L) $q$, pg_temp.v(5), pg_temp.k(1))),
  '22023', 'DOOR1-5: a no-show without the door fact is refused');
select is(pg_temp.state('rn', format($q$ select public.record_no_show(%L, null, %L, true) $q$, pg_temp.v(5), pg_temp.k(2))),
  '22023', 'DOOR1-5: the note stays required');
select is(pg_temp.as_user('rn', format($q$ select public.record_no_show(%L, 'Synthetisch: niemand öffnet, Klingel', %L, true) $q$, pg_temp.v(5), pg_temp.k(3))),
  'ok', 'DOOR1-5: a no-show at the door is recorded');
select is(pg_temp.as_user('ca', format($q$ select public.record_no_show(%L, 'Synthetisch: nur telefonisch versucht', %L, false) $q$, pg_temp.v(6), pg_temp.k(4))),
  'ok', 'DOOR1-5: a no-show without being at the door is recorded');
select is((select at_door from public.visit_status_notes where visit_id = pg_temp.v(5) and kind = 'no_show'), true, 'DOOR1-5: "ja" is stored');
select is((select at_door from public.visit_status_notes where visit_id = pg_temp.v(6) and kind = 'no_show'), false, 'DOOR1-5: "nein" is stored');
select is(pg_temp.as_user('rn', format($q$ select at_door::text from public.field_visit_status_notes(%L) where visit_id = %L and kind = 'no_show' $q$,
                                      pg_temp.today(), pg_temp.v(6))), 'false', 'DOOR1-5: the team''s /field reader shows the fact');
select throws_ok(format($q$ insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key, at_door)
                           values ('00000000-0000-4000-b000-000000000011', %L, 'cancelled', 'Synthetisch', %L, %L, true) $q$,
                        pg_temp.v(1), pg_temp.u('rn'), pg_temp.k(5)),
  '23514', null, 'DOOR1-5: only a no-show carries the door fact (check constraint)');
select throws_ok(format($q$ insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key)
                           values ('00000000-0000-4000-b000-000000000011', %L, 'no_show', 'Synthetisch', %L, %L) $q$,
                        pg_temp.v(8), pg_temp.u('rn'), pg_temp.k(6)),
  '22023', null, 'DOOR1-5: a new no-show row without the fact is refused even for the table owner (guard)');
-- A row recorded before 0072 (the guard did not exist then): written with the guard off, as the table owner.
alter table public.visit_status_notes disable trigger visit_status_notes_door_facts;
insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(8), 'no_show', 'Synthetisch: alter Eintrag', pg_temp.u('rn'), pg_temp.k(7));
alter table public.visit_status_notes enable trigger visit_status_notes_door_facts;
update public.care_visits set status = 'no_show' where id = pg_temp.v(8);

-- DOOR1-11 and DOOR1-8: what Operations reads about an open no-show ------------------------------------------------------
select ok(pg_temp.ops_detail('no_show_open', 5) like '% · nicht angetroffen __:__ · an der Tür: ja · Ergebnis offen · Notiz im Team',
  'DOOR1-11: Operations reads the time, "an der Tür: ja", "Ergebnis offen" and that the note stays in the team');
select ok(pg_temp.ops_detail('no_show_open', 5) not like '%Synthetisch%', 'DOOR1-11: no note text reaches Operations (no-show)');
select ok(pg_temp.ops_detail('no_show_open', 6) like '% · an der Tür: nein · Ergebnis offen · Notiz im Team',
  'DOOR1-11: "an der Tür: nein" is shown');
select ok(pg_temp.ops_detail('no_show_open', 8) like '% · an der Tür: nicht erfasst · Ergebnis offen%',
  'DOOR1-5: a row recorded before this change reads "nicht erfasst"');
select is(pg_temp.ops_priority('no_show_open', 5), 'P1', 'DOOR1-10: a no-show at the door without an outcome stays P1');
select is(pg_temp.ops_priority('no_show_open', 6), 'P1', 'DOOR1-8: "an der Tür: nein" changes nothing: still P1');

-- DOOR1-6: the basis of "Notfallkontakt informiert" --------------------------------------------------------------------
select is(pg_temp.state('rn', format($q$ select public.record_no_show_outcome(%L, 'emergency_contact_informed', 'Synthetisch: Tochter informiert', %L) $q$,
                                     pg_temp.v(5), pg_temp.k(10))),
  '22023', 'DOOR1-6: "Notfallkontakt informiert" without a basis is refused');
select is(pg_temp.state('rn', format($q$ select public.record_no_show_outcome(%L, 'emergency_contact_informed', 'Synthetisch: Tochter informiert', %L, 'guess') $q$,
                                     pg_temp.v(5), pg_temp.k(11))),
  '22023', 'DOOR1-6: an unknown basis is refused');
select is(pg_temp.state('rn', format($q$ select public.record_no_show_outcome(%L, 'client_reached', 'Synthetisch: erreicht', %L, 'emergency') $q$,
                                     pg_temp.v(5), pg_temp.k(12))),
  '22023', 'DOOR1-6: a basis on another outcome is refused');
select is((select count(*)::int from public.visit_status_notes where visit_id = pg_temp.v(5) and kind = 'no_show_outcome'), 0,
  'DOOR1-6: nothing was stored by the refused calls');
select is(pg_temp.as_user('rn', format($q$ select public.record_no_show_outcome(%L, 'emergency_contact_informed', 'Synthetisch: Tochter informiert', %L, 'emergency') $q$,
                                       pg_temp.v(5), pg_temp.k(13))),
  'ok', 'DOOR1-6: "Notfallkontakt informiert" with the basis "Notfall" is recorded');
select is(pg_temp.as_user('ca', format($q$ select public.record_no_show_outcome(%L, 'emergency_contact_informed', 'Synthetisch: Nachbarin laut Auftrag der Tochter', %L, 'other') $q$,
                                       pg_temp.v(6), pg_temp.k(14))),
  'ok', 'DOOR1-6: with the basis "other" the note says which');
select is((select disclosure_basis from public.visit_status_notes where visit_id = pg_temp.v(5) and kind = 'no_show_outcome'), 'emergency',
  'DOOR1-6: the basis is stored');
select is(pg_temp.as_user('rn', format($q$ select disclosure_basis from public.field_visit_status_notes(%L) where visit_id = %L and kind = 'no_show_outcome' $q$,
                                      pg_temp.today(), pg_temp.v(5))), 'emergency', 'DOOR1-6: the team''s /field reader shows the basis');
select is(pg_temp.as_user('rn', format($q$ select public.record_no_show_outcome(%L, 'client_reached', 'Synthetisch: später erreicht', %L) $q$,
                                       pg_temp.v(8), pg_temp.k(15))),
  'ok', 'DOOR1-6: another outcome needs no basis');
select is((select disclosure_basis from public.visit_status_notes where visit_id = pg_temp.v(8) and kind = 'no_show_outcome'), null,
  'DOOR1-6: and stores none');
select ok(exists (select 1 from public.audit_events a join public.visit_status_notes s on s.id = a.entity_id
                  where s.visit_id = pg_temp.v(5) and s.kind = 'no_show_outcome' and a.changed -> 'disclosure_basis' ->> 'new' = 'emergency'
                    and a.changed::text not like '%Synthetisch%'),
  'DOOR1-6: the basis is audited, the note is not');
select ok(exists (select 1 from public.audit_events a join public.visit_status_notes s on s.id = a.entity_id
                  where s.visit_id = pg_temp.v(6) and s.kind = 'no_show' and a.changed -> 'at_door' ->> 'new' = 'false'
                    and a.changed::text not like '%Synthetisch%'),
  'DOOR1-5: the door fact is audited, the note is not');

-- DOOR1-11: the line with an outcome, and the open exception after it ---------------------------------------------------
select ok(private.no_show_ops_detail(pg_temp.v(5)) like '% · an der Tür: ja · Ergebnis: Notfallkontakt informiert (Grundlage: Notfall) __:__ · Notiz im Team',
  'DOOR1-11: with the outcome, Operations'' line carries the door fact, the outcome, its basis and its time');
select ok(private.no_show_ops_detail(pg_temp.v(5)) not like '%Synthetisch%', 'DOOR1-11: and no note text');
select ok(private.no_show_ops_detail(pg_temp.v(6)) like '% · an der Tür: nein · Ergebnis: Notfallkontakt informiert (Grundlage: andere) %',
  'DOOR1-11: the basis "andere" is shown');
select ok(private.no_show_ops_detail(pg_temp.v(8)) like '% · an der Tür: nicht erfasst · Ergebnis: Klient:in erreicht __:__ · Notiz im Team',
  'DOOR1-11: another outcome is shown without a basis');
select is(pg_temp.ops_detail('no_show_open', 5), null, 'DOOR1-10: the P1 exception closes with the outcome, as before (C1 unchanged)');

-- DOOR1-11: an interruption shows its reason code, not the note ---------------------------------------------------------
select is(pg_temp.as_user('rn', format($q$ select public.end_visit_not_completed(%L, 'client_declined', 'Synthetisch: lehnt ab, Gründe privat', %L) $q$,
                                       pg_temp.v(9), pg_temp.k(20))),
  'ok', 'fixture: the visit ends as not completed with a note');
select ok(pg_temp.ops_detail('visit_interrupted', 9) like '% · Klient:in lehnt die Fortsetzung ab · Notiz im Team',
  'DOOR1-11: Operations reads the interruption reason and that the note stays in the team');
select ok(pg_temp.ops_detail('visit_interrupted', 9) not like '%Synthetisch%', 'DOOR1-11: no note text reaches Operations (interruption)');
select ok(pg_temp.as_user('rn', format($q$ select detail from public.team_visit_alerts() where exception_type = 'visit_interrupted' and visit_id = %L $q$,
                                       pg_temp.v(9))) like '% · Klient:in lehnt die Fortsetzung ab – Synthetisch: lehnt ab, Gründe privat',
  'DOOR1-11: the team keeps its note in its own alert list');

-- DOOR1-7: HAND1 shows both facts with who and when --------------------------------------------------------------------
select is((select e.detail ->> 'at_door' from private.handover_entries(pg_temp.v(7), pg_temp.u('rn')) e
           where e.kind = 'visit_no_show' and e.source_visit_start = '09:50'), 'false',
  'DOOR1-7: "since you were last here" shows the door fact of the no-show');
select is((select e.detail ->> 'disclosure_basis' from private.handover_entries(pg_temp.v(7), pg_temp.u('rn')) e
           where e.kind = 'visit_no_show_outcome' and e.source_visit_start = '09:10'), 'emergency',
  'DOOR1-7: and the basis of the outcome');
select ok((select bool_and(e.author is not null and e.at is not null) from private.handover_entries(pg_temp.v(7), pg_temp.u('rn')) e
           where e.kind in ('visit_no_show', 'visit_no_show_outcome')),
  'DOOR1-7: each with who and when');

-- DOOR1-9: catalogue check: which functions read the case notes or the two facts ---------------------------------------
select is((select string_agg(p.oid::regprocedure::text, ',' order by p.oid::regprocedure::text collate "C")
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prokind = 'f'
             and p.prosrc ~ '(access_notes|language_notes|at_door|disclosure_basis)'),
  'field_door_notes(date),field_safety_alert_history(date),field_visit_status_notes(date),intake_cases(),private.apply_case_facts(uuid,jsonb),'
  'private.guard_case_access_notes(),private.guard_door_facts(),private.handover_entries(uuid,uuid),private.no_show_ops_detail(uuid),private.sync_case_tasks(uuid),'
  'record_no_show(uuid,text,uuid,boolean),record_no_show_outcome(uuid,text,text,uuid,text)',
  'DOOR1-9: only intake, the /field readers, HAND1, the commands, the DOOR1-12 write guard and the Operations codes line read '
  'the notes or facts (no AN1, AN2, billing, export or push function)');

-- DOOR1-8: display only ------------------------------------------------------------------------------------------------
select is((select count(*)::int from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000208' and kind = 'access_unknown' and status = 'open'),
          0, 'DOOR1-8: no task is opened by the door facts or the notes (access_unknown only from an empty access note, 0013)');

select * from finish();
rollback;
