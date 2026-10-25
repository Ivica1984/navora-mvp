-- DOOR1 part (b): safety-alert category list and append-only values (migration 0073, ADR-086). Brief
-- `docs/agents/briefs/DOOR1.md` DOOR1-2, -3, -4 (code guard), -7 (values in HAND1), and -8, -9, -10 for this part.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · care assistant …906 (Nord) · operations …904 · admin …905
-- (org A, no team) · coach …901 (org A, no team) · admin …903 (org B). Synthetic users added here: …7301 registered nurse of
-- Testteam Mitte …102 (same organisation, no cover), …7302 registered nurse of Mitte who covers Nord visits, …7304 an account
-- without any membership (stands for a client or partner account). Case …208 (Nord), …205 (Mitte, no value). All data
-- synthetic; fixtures are written as the table owner, everything else goes through `authenticated` and the commands.
begin;
create extension if not exists pgtap with schema extensions;

select plan(68);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'ops' then '00000000-0000-4000-a000-000000000904' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'coach' then '00000000-0000-4000-a000-000000000901' when 'admin_b' then '00000000-0000-4000-a000-000000000903'
                 when 'mitte' then 'a0730000-0000-4000-a000-000000007301' when 'cover' then 'a0730000-0000-4000-a000-000000007302'
                 when 'outsider' then 'a0730000-0000-4000-a000-000000007304' end)::uuid
$$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a0730000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0730000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid $$;
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
-- The SQLSTATE a statement of the table owner fails with, or 'ok'.
create function pg_temp.owner_state(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
-- `p_user` records a value on case …208 (Nord).
create function pg_temp.rec(p_user text, p_value text, p_note text, p_source text, n int, p_case text default '00000000-0000-4000-a000-000000000208',
                            p_category text default 'access_arrangement') returns text language sql as $$
  select pg_temp.as_user(p_user, format($q$ select public.record_safety_alert_value(%L, %L, %L, %L, %L, %L) $q$,
                                        p_case, p_category, p_value, p_note, p_source, pg_temp.k(n)))
$$;
create function pg_temp.rec_state(p_user text, p_value text, p_note text, p_source text, n int, p_category text default 'access_arrangement')
returns text language sql as $$
  select pg_temp.state(p_user, format($q$ select public.record_safety_alert_value(%L, %L, %L, %L, %L, %L) $q$,
                                      '00000000-0000-4000-a000-000000000208', p_category, p_value, p_note, p_source, pg_temp.k(n)))
$$;
-- What `p_user` reads from field_safety_alerts for visit n: 'value|source|note|actor_kind' ('∅' for nulls), or null.
create function pg_temp.alert(p_user text, n int) returns text language sql as $$
  select pg_temp.as_user(p_user, format(
    $q$ select coalesce(value, '∅') || '|' || coalesce(source, '∅') || '|' || coalesce(note, '∅') || '|' || coalesce(actor_kind, '∅')
        from public.field_safety_alerts(%L) where visit_id = %L and category_code = 'access_arrangement' $q$,
    (select visit_date from public.care_visits where id = pg_temp.v(n)), pg_temp.v(n)))
$$;

-- Synthetic accounts and fixtures (as the table owner) -----------------------------------------------------------------
insert into auth.users (id, email) values
  (pg_temp.u('mitte'), 'door1b-mitte@navora.test'), (pg_temp.u('cover'), 'door1b-cover@navora.test'),
  (pg_temp.u('outsider'), 'door1b-outsider@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('cover'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('cover'), 'registered_nurse');

-- v1 Nord today planned · v2 Nord today covered by …7302 (cover runs) · v3 Nord yesterday covered by …7302, final report
-- (cover ended) · v4 Mitte (case …205, no value) today · v7 Nord tomorrow (HAND1 card).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '06:10', '06:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today(), '07:10', '07:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() - 1, '07:10', '07:40', false, 'completed'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(4), '00000000-0000-4000-a000-000000000205', '00000000-0000-4000-a000-000000000102', pg_temp.today(), '08:10', '08:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(7), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101', pg_temp.today() + 1, '09:10', '09:40', false, 'planned');
update public.care_visits set covered_by = pg_temp.u('cover'), covered_at = private.now(), cover_team_id = '00000000-0000-4000-a000-000000000102'
where id in (pg_temp.v(2), pg_temp.v(3));
insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by, signed_by, signed_at)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(13), pg_temp.v(3), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', 1, 'final', '{}', pg_temp.u('cover'), false,
        pg_temp.u('cover'), pg_temp.u('cover'), private.now() - interval '20 hours');

-- DOOR1-8 baseline, before any value exists.
create temp table door1b_before as
  select private.case_readiness('00000000-0000-4000-a000-000000000208')::text as readiness,
         (select count(*) from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000208') as tasks,
         (select count(*) from private.derived_exceptions('00000000-0000-4000-b000-000000000011')) as exceptions;

-- DOOR1-2: the category list -------------------------------------------------------------------------------------------
select is((select string_agg(code || ':' || class || ':v' || version, ',') from private.active_alert_categories(pg_temp.today())),
  'access_arrangement:organisational:v1', 'DOOR1-2: the list ships with one active category, the access arrangement (organisational)');
select is((select count(*)::int from private.active_alert_categories(pg_temp.today()) where class = 'clinical'), 0,
  'DOOR1-2: no active clinical category');
select is((select help_text from public.safety_alert_categories where code = 'access_arrangement' and version = 1),
  'Ort und wer den Schlüssel hat, nie den Code', 'DOOR1-4: the access arrangement carries the help text of the brief');
select ok((select refuses_codes and source <> '' and active_from <= pg_temp.today() from public.safety_alert_categories
           where code = 'access_arrangement' and version = 1),
  'DOOR1-2: version, active from and source are recorded; the access arrangement refuses codes');
select is(pg_temp.owner_state($q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source)
                                   values ('door1b_clinical', 1, 'Synthetisch klinisch', 'clinical', date '2026-01-01', 'Synthetischer Test') $q$),
  '23514', 'DOOR1-2: a clinical category cannot be inserted without an approval reference (even by the table owner)');
select is(pg_temp.owner_state($q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source, approval_ref)
                                   values ('door1b_clinical', 1, 'Synthetisch klinisch', 'clinical', current_date + 3650, 'Synthetischer Test',
                                           'Synthetische Freigabe-Referenz') $q$),
  'ok', 'DOOR1-2: with an approval reference it can (here a synthetic row that starts in ten years)');
select is((select count(*)::int from private.active_alert_categories(pg_temp.today()) where class = 'clinical'), 0,
  'DOOR1-2: a clinical version is not active before its start date');
select is(pg_temp.owner_state($q$ update public.safety_alert_categories set label = 'Geändert' where code = 'access_arrangement' $q$),
  '42501', 'DOOR1-2: a category version cannot be updated (a change is a new version)');
select is(pg_temp.owner_state($q$ delete from public.safety_alert_categories where code = 'door1b_clinical' $q$),
  '42501', 'DOOR1-2: a category version cannot be deleted');
select is(pg_temp.owner_state($q$ truncate public.safety_alert_categories cascade $q$),
  '42501', 'DOOR1-2: the list cannot be truncated');
select is(pg_temp.owner_state($q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source, withdrawn)
                                   values ('door1b_org', 1, 'Synthetisch', 'organisational', date '2026-01-01', 'Synthetischer Test', false),
                                          ('door1b_org', 2, 'Synthetisch', 'organisational', date '2026-01-02', 'Synthetischer Test', true) $q$),
  'ok', 'fixture: an organisational category whose version 2 withdraws it');
select is((select string_agg(code, ',') from private.active_alert_categories(pg_temp.today())), 'access_arrangement',
  'DOOR1-2: the highest started version decides; a withdrawing version ends the category');
select is(pg_temp.state('rn', $q$ insert into public.safety_alert_categories (code, version, label, class, active_from, source)
                                 values ('door1b_app', 1, 'App', 'organisational', current_date, 'App') $q$),
  '42501', 'DOOR1-2: an app user cannot add a category');
select is(pg_temp.as_user('rn', $q$ select string_agg(code, ',') from public.active_safety_alert_categories() $q$), 'access_arrangement',
  'DOOR1-2: the form list returns the active categories');
select ok(not has_function_privilege('anon', 'public.active_safety_alert_categories()', 'execute'),
  'DOOR1-2: anon cannot read the form list');

-- DOOR1-3: values, refusals ---------------------------------------------------------------------------------------------
select is(pg_temp.rec_state('rn', 'ja', null, 'team', 1), '22023', 'DOOR1-3: "ja" without a note is refused');
select is(pg_temp.rec_state('rn', 'ja', '   ', 'team', 2), '22023', 'DOOR1-3: a blank note counts as no note');
select is(pg_temp.rec_state('rn', 'nein', repeat('x', 301), 'team', 3), '22023', 'DOOR1-3: a note over 300 characters is refused');
select is(pg_temp.rec_state('rn', 'vielleicht', null, 'team', 4), '22023', 'DOOR1-3: only ja, nein or unbekannt');
select is(pg_temp.rec_state('rn', 'nein', null, 'nachbar', 5), '22023', 'DOOR1-3: only the five sources');
select is(pg_temp.rec_state('rn', 'nein', null, 'team', 6, 'door1b_org'), '22023', 'DOOR1-3: a withdrawn category takes no value');
select is(pg_temp.rec_state('rn', 'nein', null, 'team', 7, 'door1b_clinical'), '22023', 'DOOR1-3: a category that has not started takes no value');
select is((select count(*)::int from public.case_safety_alert_values), 0, 'DOOR1-3: nothing was stored by the refusals');

-- DOOR1-4: the code guard -----------------------------------------------------------------------------------------------
select is(pg_temp.rec_state('rn', 'ja', 'Synthetisch: Schlüsselsafe Code 4711', 'team', 8), 'NV004',
  'DOOR1-4: four digits in a row are refused ("Bitte keinen Code erfassen")');
select is(pg_temp.rec_state('rn', 'ja', 'Synthetisch: Safe 47 11 neben Tür', 'team', 9), 'NV004', 'DOOR1-4: also with a space between');
select is(pg_temp.rec_state('rn', 'nein', 'Synthetisch: früher 4-7-1-1', 'team', 10), 'NV004', 'DOOR1-4: also with dashes, and with any value');
select ok(not private.looks_like_code('Synthetisch: Schlüssel bei Nachbarin Nr. 12, 2. Stock'),
  'DOOR1-4: house numbers and floors with fewer than four digits pass');
select is(pg_temp.owner_state(format($q$ insert into public.case_safety_alert_values (organization_id, case_id, category_id, value, note, source, actor_id, idempotency_key)
                                         values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
                                                 (select id from public.safety_alert_categories where code = 'access_arrangement' and version = 1),
                                                 'ja', 'Synthetisch: 1234', 'team', %L, %L) $q$, pg_temp.u('rn'), pg_temp.k(11))),
  'NV004', 'DOOR1-4: the guard holds for the table owner too (trigger), so no code is ever stored');
select is((select count(*)::int from public.case_safety_alert_values), 0, 'DOOR1-4: no code-like note was stored');

-- DOOR1-3: who may record -----------------------------------------------------------------------------------------------
select is(pg_temp.rec('rn', 'unbekannt', null, 'team', 20), 'ok', 'DOOR1-3: the case''s team records "unbekannt" without a note');
select is(pg_temp.rec('ops', 'nein', 'Synthetisch: laut Zuweisung öffnet die Klientin selbst', 'referral', 21), 'ok',
  'DOOR1-3: Operations records at intake (source referral)');
select is(pg_temp.rec('mitte', 'nein', null, 'team', 22), 'rejected', 'DOOR1-3: a member of another team cannot record');
select is(pg_temp.rec('cover', 'nein', null, 'team', 23), 'rejected', 'DOOR1-3: the covering member reads, but does not record, the case''s values');
select is(pg_temp.rec('coach', 'nein', null, 'team', 24), 'rejected', 'DOOR1-3: a coach outside the team cannot record');
select is(pg_temp.rec('admin_b', 'nein', null, 'team', 25), 'rejected', 'DOOR1-3: a member of another organisation cannot record');
select is(pg_temp.rec('outsider', 'nein', null, 'team', 26), 'rejected', 'DOOR1-3: an account without membership cannot record');
select is(pg_temp.rec('rn', 'ja', 'Synthetisch: Schlüssel bei der Nachbarin links, 2. Stock', 'relative', 27), 'ok',
  'DOOR1-3: "ja" with a note is recorded');
select is(pg_temp.rec('rn', 'ja', 'Synthetisch: Schlüssel bei der Nachbarin links, 2. Stock', 'relative', 27), 'duplicate',
  'DOOR1-3: the same idempotency key applies once');
select is((select count(*)::int from public.case_safety_alert_values where case_id = '00000000-0000-4000-a000-000000000208'), 3,
  'DOOR1-3: three values, none overwritten');

-- DOOR1-3: append-only for every role -----------------------------------------------------------------------------------
select is(pg_temp.owner_state($q$ update public.case_safety_alert_values set value = 'nein' $q$), '42501', 'DOOR1-3: no update (table owner)');
select is(pg_temp.owner_state($q$ delete from public.case_safety_alert_values $q$), '42501', 'DOOR1-3: no delete (table owner)');
select is(pg_temp.owner_state($q$ truncate public.case_safety_alert_values $q$), '42501', 'DOOR1-3: no truncate (table owner)');
select is(pg_temp.state('rn', $q$ select count(*) from public.case_safety_alert_values $q$), '42501',
  'DOOR1-9: the table has no read grant for app users (readers only)');
select is(pg_temp.state('rn', $q$ insert into public.case_safety_alert_values (organization_id, case_id, category_id, value, source, actor_id, idempotency_key)
                               values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
                                       (select id from public.safety_alert_categories limit 1), 'nein', 'team', auth.uid(), gen_random_uuid()) $q$),
  '42501', 'DOOR1-3: no direct insert for app users (the command is the only path)');
select ok(not has_function_privilege('anon', 'public.record_safety_alert_value(uuid,text,text,text,text,uuid)', 'execute')
          and not has_function_privilege('anon', 'public.field_safety_alerts(date)', 'execute'),
  'DOOR1-9: anon executes neither the command nor the reader');

-- Audit without the note
select ok((select bool_and(a.changed ? 'value' and a.changed ? 'source' and not (a.changed ? 'note') and a.command = 'record_safety_alert_value')
           from public.audit_events a where a.table_name = 'case_safety_alert_values'),
  'DOOR1-3: each value is audited (value, source) without the note');
select is((select count(*)::int from public.audit_events a where a.table_name = 'case_safety_alert_values'), 3, 'DOOR1-3: one audit row per value');

-- DOOR1-3/-4: latest wins, with who, when and source; read scope (DOOR1-9) -----------------------------------------------
select is(pg_temp.alert('rn', 1), 'ja|relative|Synthetisch: Schlüssel bei der Nachbarin links, 2. Stock|me',
  'DOOR1-3: the card reads the latest value (latest wins) with source and who');
select is(pg_temp.alert('ca', 1), 'ja|relative|Synthetisch: Schlüssel bei der Nachbarin links, 2. Stock|team',
  'DOOR1-4: the care assistant of the team reads it, recorded by a team member');
select ok(pg_temp.as_user('rn', format($q$ select (recorded_at is not null)::text from public.field_safety_alerts(%L) where visit_id = %L $q$,
                                       pg_temp.today(), pg_temp.v(1)))::boolean, 'DOOR1-4: with the time it was recorded');
select is(pg_temp.alert('mitte', 1), null, 'DOOR1-9: a member of another team (same organisation, no cover) reads nothing');
select is(pg_temp.alert('admin_b', 1), null, 'DOOR1-9: a member of another organisation reads nothing');
select is(pg_temp.alert('outsider', 1), null, 'DOOR1-9: an account without membership (client or partner account) reads nothing');
select is(pg_temp.alert('ops', 1), null, 'DOOR1-9: Operations reads no value, not even the one it recorded');
select is(pg_temp.alert('admin', 1), null, 'DOOR1-9: the administrator reads no value');
select is(pg_temp.alert('cover', 2), 'ja|relative|Synthetisch: Schlüssel bei der Nachbarin links, 2. Stock|team',
  'DOOR1-9: the covering member reads the value while her cover runs (recorded by a member of the visit''s team)');
select is(pg_temp.alert('cover', 1), null, 'DOOR1-9: the covering member reads nothing of a visit she does not cover');
select is(pg_temp.alert('cover', 3), null, 'DOOR1-9: after the cover ended (final report) the covering member reads nothing');
select is(pg_temp.alert('mitte', 4), '∅|∅|∅|∅', 'DOOR1-4: a category with no value comes back as a row with nulls ("nicht erfasst")');

-- DOOR1-7: HAND1 --------------------------------------------------------------------------------------------------------
select is((select string_agg(e.detail ->> 'value', ',' order by x.seq) from private.handover_entries(pg_temp.v(7), pg_temp.u('rn')) e
           join public.case_safety_alert_values x on x.id::text = e.entry_id
           where e.kind = 'safety_alert'), 'unbekannt,nein,ja', 'DOOR1-7: each new value appears in "since you were last here"');
select ok((select bool_and(e.author is not null and e.at is not null and e.detail ->> 'label' = 'Schlüssel- und Zugangsregelung')
           from private.handover_entries(pg_temp.v(7), pg_temp.u('rn')) e where e.kind = 'safety_alert'),
  'DOOR1-7: with who, when and the category');
select is((select count(*)::int from private.handover_entries(pg_temp.v(4), pg_temp.u('mitte')) e where e.kind = 'safety_alert'), 0,
  'DOOR1-9: another case''s card in HAND1 carries none of them');

-- DOOR1-8: display only -------------------------------------------------------------------------------------------------
select is(pg_temp.rec('rn', 'unbekannt', null, 'team', 28), 'ok', 'fixture: the access arrangement is now "unbekannt"');
select is(private.case_readiness('00000000-0000-4000-a000-000000000208')::text, (select readiness from door1b_before),
  'DOOR1-8: J1 readiness is unchanged with the access arrangement "unbekannt"');
select is((select count(*) from public.case_tasks where case_id = '00000000-0000-4000-a000-000000000208'), (select tasks from door1b_before),
  'DOOR1-8: no task is opened by a value (access_unknown only from an empty access note, 0013)');
select is((select count(*) from private.derived_exceptions('00000000-0000-4000-b000-000000000011')), (select exceptions from door1b_before),
  'DOOR1-8: no exception or signal is derived from a value');
select is(pg_temp.owner_state($q$ insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
                                   values ('00000000-0000-4000-b000-000000000011', 'a0730000-0000-4000-8000-000000000099',
                                           '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
                                           (private.now() at time zone 'Europe/Zurich')::date + 3, '10:10', '10:40', false, 'planned') $q$),
  'ok', 'DOOR1-8: planning a visit of the case is not blocked');

-- DOOR1-9: catalogue check: which functions read the values -------------------------------------------------------------
select is((select string_agg(p.oid::regprocedure::text, ',' order by p.oid::regprocedure::text collate "C")
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prokind = 'f' and p.prosrc ~ 'case_safety_alert_values'),
  'field_safety_alerts(date),private.handover_entries(uuid,uuid),record_safety_alert_value(uuid,text,text,text,text,uuid)',
  'DOOR1-9: only the /field reader, HAND1 and the command read the values (no AN1, AN2, billing, export, push or Operations function)');

select * from finish();
rollback;
