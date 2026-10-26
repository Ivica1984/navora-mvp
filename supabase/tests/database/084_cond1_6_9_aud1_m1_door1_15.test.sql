-- COND1-6 = AUD1-M1 and COND1-9 = DOOR1-15. Migration 0084, ADR-097. Brief docs/agents/briefs/COND1.md; specification
-- in AUD1.md (*Conditions*, AUD1-M1) and DOOR1.md / COND1.md (*PO decision 2026-10-26 14:30*, CGR-66).
-- Org A (…011): admin …905 (member of no team until the fixture adds her), nurse …902 (Testteam Nord …101), case …208
-- (Testteam Nord). Synthetic data only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

create function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid::text, true);
$$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a0840000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
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
create function pg_temp.intake(p_note text, p_key integer) returns text language sql as $$
  select pg_temp.state(905, format('select public.update_case_intake(%L, %L::jsonb, %L)', '00000000-0000-4000-a000-000000000208',
                                   jsonb_build_object('access_notes', p_note), pg_temp.k(p_key)))
$$;

-- COND1-6 = AUD1-M1: purpose billing returns code values only, also inside the team ---------------------------------
select pg_temp.act_as(pg_temp.u(902));
set local role authenticated;
select is(public.set_quality_hold('00000000-0000-4000-a000-000000000502', 'Synthetischer Haltegrund COND1-6',
                                  pg_temp.k(1)), 'ok', 'fixture: the nurse sets a hold with a reason');
reset role;
create temp table fx as
  select h.id as hold_id from public.quality_holds h
  where h.visit_id = '00000000-0000-4000-a000-000000000502' and h.lifted_at is null;
grant select on fx to authenticated;
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', pg_temp.u(905), 'registered_nurse');   -- fixture: the admin joins the team
select ok(exists (select 1 from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101' and user_id = pg_temp.u(905)),
  'fixture: the administrator …905 is a member of the hold''s team');
select is(pg_temp.as_user(905, $q$ select (r.changed -> 'reason')::text || '|' || r.text_withheld::text || '|' || array_to_string(r.withheld_keys, ',')
                                   from public.read_audit_record('quality_holds', (select hold_id from fx), 'billing') r
                                   where r.command = 'set_quality_hold' $q$),
  'null|true|reason',
  'AUD1-M1: an administrator in the team reading a hold with purpose billing gets reason null, text_withheld true');
select is(pg_temp.as_user(905, $q$ select (r.changed::text ~ 'Synthetischer Haltegrund')::text || '|' || (r.changed ? 'reason')::text
                                          || '|' || (r.occurred_at is not null and r.actor_id is not null)::text
                                   from public.read_audit_record('quality_holds', (select hold_id from fx), 'billing') r
                                   where r.command = 'set_quality_hold' $q$),
  'false|true|true', 'AUD1-M1: with billing the text appears nowhere; the key, the time and the actor stay');
select is(pg_temp.as_user(905, $q$ select (r.changed -> 'reason' ->> 'new') || '|' || r.text_withheld::text
                                   from public.read_audit_record('quality_holds', (select hold_id from fx), 'compliance') r
                                   where r.command = 'set_quality_hold' $q$),
  'Synthetischer Haltegrund COND1-6|false', 'AUD1-M1: with compliance the administrator in the team reads the reason');
select is(pg_temp.as_user(905, $q$ select (r.changed -> 'reason' ->> 'new') || '|' || r.text_withheld::text
                                   from public.read_audit_record('quality_holds', (select hold_id from fx), 'safety_review') r
                                   where r.command = 'set_quality_hold' $q$),
  'Synthetischer Haltegrund COND1-6|false', 'AUD1-M1: safety_review is unchanged (in the team: the reason is read)');
select is((select string_agg(l.purpose, ',' order by l.id) from public.audit_read_log l join fx on l.entity_id = fx.hold_id),
  'billing,billing,compliance,safety_review', 'AUD1-5 unchanged: each billing read is recorded like any other');

-- COND1-9 = DOOR1-15: the guard stays; the help text names the phone number ------------------------------------------
select is(pg_temp.intake('079 123 45 67', 10), '22023 Bitte keinen Code erfassen',
  'DOOR1-15: a phone number in the intake access note stays refused (22023)');
select is(pg_temp.intake('8004 Zürich', 11), '22023 Bitte keinen Code erfassen',
  'DOOR1-15: a postal code in the intake access note stays refused (22023)');
select is(pg_temp.intake('Schlüssel bei der Tochter, Hintereingang', 12), 'ok',
  'DOOR1-15: "Schlüssel bei der Tochter, Hintereingang" is accepted');
select is((select access_notes from public.cases where id = '00000000-0000-4000-a000-000000000208'),
  'Schlüssel bei der Tochter, Hintereingang', 'DOOR1-15: the accepted note is stored as written');

select is((select help_text || '|v' || version || '|' || refuses_codes::text || '|' || class
           from private.active_alert_categories(pg_temp.today()) where code = 'access_arrangement'),
  'Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code|v2|true|organisational',
  'DOOR1-15: the active access arrangement (version 2) carries the help text of the decision and still refuses codes');
select is((select help_text from public.safety_alert_categories where code = 'access_arrangement' and version = 1),
  'Ort und wer den Schlüssel hat, nie den Code', 'DOOR1-15: version 1 is kept unchanged (append-only list)');
select is(pg_temp.as_user(902, $q$ select string_agg(help_text, ',') from public.active_safety_alert_categories() where code = 'access_arrangement' $q$),
  'Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code', 'DOOR1-15: the record forms read the new help text');

-- A value recorded under version 1 is still the case's current value (readers match by code, not by version).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
values ('00000000-0000-4000-b000-000000000011', 'a0840000-0000-4000-8000-000000000001', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.today() + 2, '08:00', '08:30', false, 'planned');
insert into public.case_safety_alert_values (organization_id, case_id, category_id, value, note, source, actor_id, idempotency_key)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        (select id from public.safety_alert_categories where code = 'access_arrangement' and version = 1),
        'ja', 'Synthetisch: Schlüssel bei der Nachbarin', 'team', pg_temp.u(902), pg_temp.k(20));
select is(pg_temp.as_user(902, format($q$ select value || '|' || note || '|' || help_text from public.field_safety_alerts(%L)
                                          where visit_id = 'a0840000-0000-4000-8000-000000000001' and category_code = 'access_arrangement' $q$,
                                       pg_temp.today() + 2)),
  'ja|Synthetisch: Schlüssel bei der Nachbarin|Ort und wer den Schlüssel hat (ohne Telefonnummer), nie den Code',
  'DOOR1-15: a value recorded under version 1 still shows on the card, with the new help text');
select is(pg_temp.state(902, format('select public.record_safety_alert_value(%L, %L, %L, %L, %L, %L)', '00000000-0000-4000-a000-000000000208',
                                    'access_arrangement', 'ja', 'Synthetisch: Tochter 079 123 45 67', 'relative', pg_temp.k(21))),
  'NV004 Bitte keinen Code erfassen', 'DOOR1-15: the DOOR1-4 note refuses a phone number under version 2 too');

select * from finish();
rollback;
