-- CSR1, part 8 (migration 0047, ADR-058): CGR-24 (F1-F4, F6) and CGR-26 (OPS1), the PO's criteria in
-- `docs/agents/briefs/CSR1.md` (2026-10-23 11:25; Clinical Governance Report section 2026-10-23 10:29).
-- CGR-24: a report correction that is not final after the `report_not_final` threshold raises `report_correction_open`
--         (P3, PROVISIONAL, D-28) for the team and Operations, until the correction version is final.
--         CGR-30 (`cra` 2026-10-23 14:30): it closes only with its cause; a hand close is refused, an earlier close
--         hides nothing.
-- CGR-26: `field_visit_status_notes` says who ended an interrupted visit (label, never a user id) and why.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · ops …904
--        (operations, org A) · fremd …903 (admin of org B). All data synthetic; every step goes through the real
--        commands, except three steps simulated as the table owner (marked below): ageing a correction draft past the
--        threshold, an organisation override of the threshold, and a member leaving the team.
begin;
create extension if not exists pgtap with schema extensions;

select plan(39);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Surface -----------------------------------------------------------------------------------------------------------
select is((select priority || '/' || coalesce(amount::text, '-') || '/' || coalesce(escalate_to_p1_after_hours::text, '-')
           from public.exception_rules where exception_type = 'report_correction_open'),
  'P3/-/-', 'report_correction_open: P3, no own threshold, not escalating (PROVISIONAL, D-28)');
select ok(private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'report_correction_open'),
  'CGR-30: report_correction_open closes only with its cause');
select ok(not private.exception_is_safety('00000000-0000-4000-b000-000000000011', 'report_correction_open'),
  'it is not made a safety exception: its priority stays with D-28');
select ok(has_function_privilege('authenticated', 'public.field_visit_status_notes(date)', 'execute')
          and not has_function_privilege('anon', 'public.field_visit_status_notes(date)', 'execute'),
  'field_visit_status_notes: members yes, anon no');
select is((select string_agg(a, ',' order by n) from unnest(
             (select proargnames from pg_proc where oid = 'public.field_visit_status_notes(date)'::regprocedure)) with ordinality u(a, n)
           where a not like 'p\_%'),
  -- CGR-34 (0054) adds responsible_absent (a boolean fact, no user id)
  'visit_id,kind,reason_code,note,created_at,actor_kind,actor_name,actor_qualification,actor_role,responsible_absent',
  'CGR-26: the reader returns who recorded a note as a label; no user id column');

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
create temp table fx (name text primary key, id uuid not null, at timestamptz not null, resp uuid);
grant select on fx to authenticated;
insert into fx values
  ('rep',  '00000000-0000-4000-a047-000000000001', private.now() - interval '3 hours', '00000000-0000-4000-a000-000000000902'),
  ('ca',   '00000000-0000-4000-a047-000000000002', private.now() - interval '2 hours', '00000000-0000-4000-a000-000000000906'),
  ('by_team', '00000000-0000-4000-a047-000000000011', private.now() - interval '1 hour', '00000000-0000-4000-a000-000000000902'),
  ('by_ops',  '00000000-0000-4000-a047-000000000012', private.now() - interval '1 hour', '00000000-0000-4000-a000-000000000902'),
  ('by_me',   '00000000-0000-4000-a047-000000000013', private.now() - interval '1 hour', '00000000-0000-4000-a000-000000000902');

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (private.now() at time zone 'Europe/Zurich')::date, (f.at at time zone 'Europe/Zurich')::time,
       ((f.at + interval '30 minutes') at time zone 'Europe/Zurich')::time, array['Grundpflege'], false, 'planned', 30, f.resp
from fx f;

create temp table seen_key (exception_key text);
grant select, insert on seen_key to authenticated;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.latest_report(n text) returns uuid language sql as $$
  select r.id from public.visit_reports r
  where r.visit_id = pg_temp.vid(n) and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id) $$;
create function pg_temp.shown_hash(n text) returns text language sql as $$
  select f.snapshot_hash from public.field_reports((private.now() at time zone 'Europe/Zurich')::date) f where f.visit_id = pg_temp.vid(n) $$;
create function pg_temp.ops(n text) returns table (exception_key text, priority text, detail text) language sql as $$
  select x.exception_key, x.priority, x.detail from public.operations_exceptions() x
  where x.exception_type = 'report_correction_open' and x.entity_id = pg_temp.vid(n) $$;
create function pg_temp.team(n text) returns table (exception_key text, priority text) language sql as $$
  select x.exception_key, x.priority from public.team_visit_alerts() x
  where x.exception_type = 'report_correction_open' and x.visit_id = pg_temp.vid(n) $$;
-- Simulated as the table owner: the correction draft was opened `h` hours ago (the guard refuses any update).
create function pg_temp.age_correction(n text, h int) returns void language plpgsql as $$
begin
  alter table public.visit_reports disable trigger visit_reports_guard;
  update public.visit_reports set created_at = private.now() - make_interval(hours => h)
  where visit_id = pg_temp.vid(n) and supersedes_id is not null and status <> 'final';
  alter table public.visit_reports enable trigger visit_reports_guard;
end $$;

-- CGR-24: a final report by the registered nurse, then a correction draft -----------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('rep'), 'a4700000-0000-4000-8000-000000000001');
  perform public.complete_visit(pg_temp.vid('rep'), 'a4700000-0000-4000-8000-000000000002');
  perform public.create_report_draft(pg_temp.vid('rep'), 'Synthetisch', 'a4700000-0000-4000-8000-000000000003');
  perform public.sign_report(pg_temp.latest_report('rep'), pg_temp.shown_hash('rep'), 'a4700000-0000-4000-8000-000000000004');
end $$;
select is(public.correct_report(pg_temp.latest_report('rep'), 'Synthetisch: Zeit prüfen', null, 'a4700000-0000-4000-8000-000000000005')
          ->> 'result', 'ok', 'a correction draft is opened');
select is((select count(*)::int from pg_temp.team('rep')), 0, 'a fresh correction draft raises nothing yet (team)');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('rep')), 0, 'nor for Operations, before the threshold');
reset role;

select pg_temp.age_correction('rep', 23);
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('rep')), 0, '23 h old: still under the report_not_final threshold (24 h)');
reset role;

select pg_temp.age_correction('rep', 25);
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from pg_temp.ops('rep')), 'P3', 'CGR-24: 25 h old, Operations sees report_correction_open (P3)');
select is((select x.closable from public.operations_exceptions() x where x.exception_type = 'report_correction_open'
           and x.entity_id = pg_temp.vid('rep')), false, 'CGR-30: Operations is not offered "Schliessen" for it');
select is(public.handle_exception((select exception_key from pg_temp.ops('rep')), 'close', 'Synthetisch: erledigt',
          'a4700000-0000-4000-8000-000000000030'), 'cause_persists', 'CGR-30: a hand close is refused (cause_persists)');
select is((select detail from pg_temp.ops('rep')) ~ 'Korrektur Version 2 · nicht unterschrieben$', true,
  'its detail names the version and that it is not signed, and no clinical text');
insert into seen_key select exception_key from pg_temp.ops('rep');
reset role;
select is((select exception_key from seen_key),
  'report_correction_open:' || (select id from public.visit_reports where visit_id = pg_temp.vid('rep') and version = 2),
  'the key carries the correction version, so a later correction raises a new signal');
-- A close written before (or around) this rule, simulated as the table owner, hides it neither for the team nor for Operations.
insert into public.exception_events (organization_id, exception_key, kind, text, actor_id)
select '00000000-0000-4000-b000-000000000011', exception_key, 'close', 'Synthetisch: früher geschlossen', '00000000-0000-4000-a000-000000000904'
from seen_key;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is((select priority from pg_temp.team('rep')), 'P3', 'CGR-24: every member of the visit''s team sees it (team view), an earlier close does not hide it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('rep')), 1, 'CGR-30: nor for Operations');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.team_visit_alerts() where exception_type = 'report_correction_open'), 0,
  'another organisation sees nothing');
reset role;

-- One threshold: an organisation override of report_not_final applies to the correction signal too.
-- Simulated as the table owner (the admin command is tested in 019/039).
insert into public.exception_rule_overrides (organization_id, exception_type, priority, amount, escalate_to_p1_after_hours, updated_by)
values ('00000000-0000-4000-b000-000000000011', 'report_not_final', 'P3', 48, null, '00000000-0000-4000-a000-000000000905');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('rep')), 0, 'with report_not_final set to 48 h, a 25 h old correction is not listed');
reset role;
delete from public.exception_rule_overrides
where organization_id = '00000000-0000-4000-b000-000000000011' and exception_type = 'report_not_final';

-- It ends when the correction version is final (signed by the performer).
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.sign_report(pg_temp.latest_report('rep'), pg_temp.shown_hash('rep'), 'a4700000-0000-4000-8000-000000000006') ->> 'result',
  'ok', 'the performer signs the correction');
select is((select count(*)::int from pg_temp.team('rep')), 0, 'final: the signal ends for the team');
reset role;
select ok((select status = 'final' from public.visit_reports where id = pg_temp.latest_report('rep')), 'the correction is final');
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('rep')), 0, 'and for Operations');
reset role;

-- Stricter than "signed": a care assistant's correction, signed but not yet countersigned, keeps the signal.
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('ca'), 'a4700000-0000-4000-8000-000000000010');
  perform public.complete_visit(pg_temp.vid('ca'), 'a4700000-0000-4000-8000-000000000011');
  perform public.create_report_draft(pg_temp.vid('ca'), 'Synthetisch', 'a4700000-0000-4000-8000-000000000012');
  perform public.sign_report(pg_temp.latest_report('ca'), pg_temp.shown_hash('ca'), 'a4700000-0000-4000-8000-000000000013');
end $$;
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.countersign_report(pg_temp.latest_report('ca'), 'a4700000-0000-4000-8000-000000000014') ->> 'result', 'ok',
  'the first version is countersigned and final');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('ca'), 'Synthetisch: Massnahme ergänzen', null, 'a4700000-0000-4000-8000-000000000015')
          ->> 'result', 'ok', 'the care assistant opens a correction');
select is(public.sign_report(pg_temp.latest_report('ca'), pg_temp.shown_hash('ca'), 'a4700000-0000-4000-8000-000000000016') ->> 'result',
  'ok', 'and signs it');
reset role;
select is((select status from public.visit_reports where id = pg_temp.latest_report('ca')), 'signed',
  'the correction waits for the countersignature');
select pg_temp.age_correction('ca', 25);
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select detail from pg_temp.ops('ca')) ~ 'unterschrieben, Gegenzeichnung offen$', true,
  'signed but not countersigned after the threshold: the signal stays and says what is missing');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.countersign_report(pg_temp.latest_report('ca'), 'a4700000-0000-4000-8000-000000000017') ->> 'result', 'ok',
  'the registered nurse countersigns the correction');
select is((select count(*)::int from pg_temp.team('ca')), 0, 'countersigned and final: the signal ends');
reset role;

-- CGR-26: who ended an interrupted visit ----------------------------------------------------------------------------
-- Simulated as the table owner: the care assistant has a display name (ADM1 member profile; the command is tested in 035).
insert into public.member_profiles (organization_id, user_id, display_name, updated_by)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000906', 'Synthetisch Anna', '00000000-0000-4000-a000-000000000905');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('by_team'), 'a4700000-0000-4000-8000-000000000020');
  perform public.start_visit(pg_temp.vid('by_ops'), 'a4700000-0000-4000-8000-000000000021');
  perform public.start_visit(pg_temp.vid('by_me'), 'a4700000-0000-4000-8000-000000000022');
end $$;
select is(public.end_visit_not_completed(pg_temp.vid('by_me'), 'started_by_mistake', null, 'a4700000-0000-4000-8000-000000000023'),
  'ok', 'the performer ends one visit herself');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.end_visit_not_completed(pg_temp.vid('by_team'), 'nurse_unavailable', 'Synthetisch: abberufen', 'a4700000-0000-4000-8000-000000000024'),
  'ok', 'a team colleague ends the second');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.end_visit_not_completed(pg_temp.vid('by_ops'), 'client_transferred', null, 'a4700000-0000-4000-8000-000000000025'),
  'ok', 'Operations ends the third');
reset role;

create function pg_temp.ended(n text) returns table (reason_code text, note text, actor_kind text, actor_name text,
                                                     actor_qualification text, actor_role text)
language sql as $$
  select s.reason_code, s.note, s.actor_kind, s.actor_name, s.actor_qualification, s.actor_role
  from public.field_visit_status_notes((private.now() at time zone 'Europe/Zurich')::date) s
  where s.visit_id = pg_temp.vid(n) and s.kind = 'interrupted' $$;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select row(actor_kind, actor_name, actor_qualification, actor_role)::text from pg_temp.ended('by_team')),
  '(team,"Synthetisch Anna",care_assistant,)', 'CGR-26: the performer sees that a team colleague ended it, by name and qualification');
select is((select reason_code || ' – ' || note from pg_temp.ended('by_team')), 'nurse_unavailable – Synthetisch: abberufen',
  'and why');
select is((select row(actor_kind, actor_name, actor_role)::text from pg_temp.ended('by_ops')), '(coordination,,operations)',
  'an end recorded by Operations is labelled with the role (no profile name set)');
select is((select actor_kind from pg_temp.ended('by_me')), 'me', 'her own end is labelled as hers');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is((select actor_kind from pg_temp.ended('by_me')), 'team', 'the colleague sees the performer as a team member');
reset role;

-- Simulated as the table owner: the care assistant leaves Testteam Nord; her name is no longer shown.
delete from public.team_memberships
where team_id = '00000000-0000-4000-a000-000000000101' and user_id = '00000000-0000-4000-a000-000000000906';
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select row(actor_kind, actor_name, actor_qualification)::text from pg_temp.ended('by_team')), '(former,,)',
  'a member who has left is shown as former, without name or qualification');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.field_visit_status_notes((private.now() at time zone 'Europe/Zurich')::date)
           where visit_id in (pg_temp.vid('by_team'), pg_temp.vid('by_ops'), pg_temp.vid('by_me'))), 0,
  'another organisation reads no status notes');
reset role;

select * from finish();
rollback;
