-- F6 (PO brief docs/agents/briefs/F6.md): signed visit report.
-- Users: nurse …902 (Testteam Nord, registered nurse) · coach …901 (joins Testteam Nord as care assistant here)
--        foreign admin …903 (org B) · operations …904 (org A, coordinator, no team)
-- Visits: …501 (Testteam Nord, today, planned → run by the nurse) · …508 (tomorrow, planned)
--         a6…601 (inserted here, today, category A only → run by the care assistant)
begin;
create extension if not exists pgtap with schema extensions;

select plan(42);

-- CSR1 / CGR-02 (0041): sign_report carries the hash of the snapshot /field shows (field_reports.snapshot_hash).
create function pg_temp.shown_hash(rid uuid) returns text language sql as $f$
  select f.snapshot_hash from public.visit_reports r join public.care_visits v on v.id = r.visit_id
  cross join lateral public.field_reports(v.visit_date) f where r.id = rid and f.report_id = rid
$f$;
-- OBS1-7 (0096): snapshot, signed_by and signed_at are read through field_reports, not the table API.
create function pg_temp.fr(rid uuid) returns setof record language sql as $f$
  select f.snapshot, f.i_signed, f.signed_at from public.visit_reports r join public.care_visits v on v.id = r.visit_id
  cross join lateral public.field_reports(v.visit_date) f where r.id = rid and f.report_id = rid
$f$;
create function pg_temp.fr_snapshot(rid uuid) returns jsonb language sql as $f$
  select snapshot from pg_temp.fr(rid) as x(snapshot jsonb, i_signed boolean, signed_at timestamptz) $f$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Privileges: commands only ------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.visit_reports', 'insert'), 'no direct report inserts');
select ok(not has_table_privilege('authenticated', 'public.visit_reports', 'update'), 'no direct report updates');
select ok(not has_table_privilege('authenticated', 'public.visit_reports', 'delete'), 'no direct report deletes');
select ok(not has_function_privilege('anon', 'public.create_report_draft(uuid, text, uuid)', 'execute'), 'anon cannot draft');
select ok(not has_function_privilege('anon', 'public.field_reports(date)', 'execute'), 'anon cannot read reports');

-- Fixtures (as owner) -------------------------------------------------------------------------
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status, planned_minutes_a)
values ('00000000-0000-4000-b000-000000000011', 'a6000000-0000-4000-8000-000000000601', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date, '15:00', '15:30', array['Grundpflege'], false, 'planned', 30);

-- Registered nurse: draft → sign → final ---------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is(public.create_report_draft('00000000-0000-4000-a000-000000000508', null, 'a6000000-0000-4000-8000-000000000001') ->> 'reason',
  'visit_not_completed', 'no report before the visit is completed');

do $$ begin
  perform public.start_visit('00000000-0000-4000-a000-000000000501', 'a6000000-0000-4000-8000-000000000002');
  perform public.complete_visit('00000000-0000-4000-a000-000000000501', 'a6000000-0000-4000-8000-000000000003');
end $$;

select is(public.create_report_draft('00000000-0000-4000-a000-000000000501', 'Synthetische Zusammenfassung',
          'a6000000-0000-4000-8000-000000000004') ->> 'result', 'ok', 'the performing nurse drafts the report');
select is(public.create_report_draft('00000000-0000-4000-a000-000000000501', 'Synthetische Zusammenfassung',
          'a6000000-0000-4000-8000-000000000004') ->> 'result', 'duplicate', 'a resend with the same key changes nothing');
select is(public.create_report_draft('00000000-0000-4000-a000-000000000501', null,
          'a6000000-0000-4000-8000-000000000005') ->> 'reason', 'draft_exists', 'one report per visit (corrections are versions)');
select is((select count(*)::int from public.visit_reports where visit_id = '00000000-0000-4000-a000-000000000501'), 1,
  'exactly one report row after the resend');

create temp table r1 as select id from public.visit_reports where visit_id = '00000000-0000-4000-a000-000000000501';

select is((select status from public.visit_reports where id = (select id from r1)), 'draft', 'a new report is a draft');
select is(jsonb_array_length(pg_temp.fr_snapshot((select id from r1)) -> 'events'), 2,
  'the draft takes the times from the visit events (no re-entry)');
select is(pg_temp.fr_snapshot((select id from r1)) -> 'services' ->> 0, 'Grundpflege',
  'the draft takes the services from the visit');
select is((select countersign_required from public.visit_reports where id = (select id from r1)), false,
  'performed by a registered nurse → no countersignature (provisional rule, D-10)');
select is((select count(*)::int from public.final_report_visits() where visit_id = '00000000-0000-4000-a000-000000000501'), 0,
  'a draft never counts as final');

select is(public.update_report_draft((select id from r1), 'Ergänzte Zusammenfassung', 'a6000000-0000-4000-8000-000000000006') ->> 'result',
  'ok', 'the performing nurse edits the draft summary');
reset role;

-- Another team member cannot draft-edit or sign -------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select is(public.sign_report((select id from r1), pg_temp.shown_hash((select id from r1)), 'a6000000-0000-4000-8000-000000000010') ->> 'reason',
  'not_performer', 'only the performing nurse signs');
select is(public.update_report_draft((select id from r1), 'Fremd', 'a6000000-0000-4000-8000-000000000011') ->> 'reason',
  'not_performer', 'only the performing nurse edits the summary');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.sign_report((select id from r1), pg_temp.shown_hash((select id from r1)), 'a6000000-0000-4000-8000-000000000012') ->> 'result', 'ok', 'the nurse signs');
select is((select status from public.visit_reports where id = (select id from r1)), 'final', 'signed by a registered nurse → final');
-- As the signer …902 (OBS1-7: i_signed is signed_by = the reader).
select ok((select i_signed and signed_at is not null
           from pg_temp.fr((select id from r1)) as x(snapshot jsonb, i_signed boolean, signed_at timestamptz)),
  'the signature records who and when');
select is(public.update_report_draft((select id from r1), 'Nachträglich', 'a6000000-0000-4000-8000-000000000013') ->> 'reason',
  'not_draft', 'a signed report cannot be edited');
reset role;

-- Immutability holds even for database roles that bypass RLS ----------------------------------------
select throws_ok($$ update public.visit_reports set summary = 'geändert' where id = (select id from r1) $$,
  '42501', null, 'a final report is immutable');
select throws_ok($$ delete from public.visit_reports where id = (select id from r1) $$,
  '42501', null, 'a report is never deleted');

-- Correction: new version with reason and link ------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select throws_ok($$ select public.correct_report((select id from r1), 'x', null, 'a6000000-0000-4000-8000-000000000020') $$,
  '22023', null, 'a correction needs a reason');
select is(public.correct_report((select id from r1), 'Zeit falsch erfasst', null, 'a6000000-0000-4000-8000-000000000021') ->> 'result',
  'ok', 'a final report is corrected by a new version');
select ok((select version = 2 and status = 'draft' and supersedes_id = (select id from r1) and correction_reason = 'Zeit falsch erfasst'
             and summary = 'Ergänzte Zusammenfassung'
           from public.visit_reports where visit_id = '00000000-0000-4000-a000-000000000501' and version = 2),
  'the new version links the old one, keeps its summary and stores the reason');
select is(public.correct_report((select id from r1), 'Noch einmal', null, 'a6000000-0000-4000-8000-000000000022') ->> 'reason',
  'not_latest', 'only the latest version can be corrected');
select is((select version from public.field_reports((private.now() at time zone 'Europe/Zurich')::date) where visit_id = '00000000-0000-4000-a000-000000000501'), 2,
  '/field shows the latest version');
select is((select count(*)::int from public.final_report_visits() where visit_id = '00000000-0000-4000-a000-000000000501'), 1,
  'the signed version stays valid while its correction is a draft');
reset role;

-- Care assistant: signed → countersigned by a registered nurse → final ------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
do $$ begin
  perform public.start_visit('a6000000-0000-4000-8000-000000000601', 'a6000000-0000-4000-8000-000000000030');
  perform public.complete_visit('a6000000-0000-4000-8000-000000000601', 'a6000000-0000-4000-8000-000000000031');
  perform public.create_report_draft('a6000000-0000-4000-8000-000000000601', null, 'a6000000-0000-4000-8000-000000000032');
end $$;
create temp table r2 as select id from public.visit_reports where visit_id = 'a6000000-0000-4000-8000-000000000601';
select is((select countersign_required from public.visit_reports where id = (select id from r2)), true,
  'performed by a care assistant → countersignature required (provisional rule, D-10)');
select is(public.sign_report((select id from r2), pg_temp.shown_hash((select id from r2)), 'a6000000-0000-4000-8000-000000000033') ->> 'result', 'ok', 'the care assistant signs');
select is((select status from public.visit_reports where id = (select id from r2)), 'signed', 'signed, not yet final');
select is(public.countersign_report((select id from r2), 'a6000000-0000-4000-8000-000000000034') ->> 'reason',
  'own_report', 'nobody countersigns their own report');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select i_can_countersign from public.field_reports((private.now() at time zone 'Europe/Zurich')::date) where visit_id = 'a6000000-0000-4000-8000-000000000601'), true,
  'a registered nurse of the team is offered the countersignature');
select is(public.countersign_report((select id from r2), 'a6000000-0000-4000-8000-000000000035') ->> 'result', 'ok',
  'a registered nurse of the team countersigns');
select ok((select status = 'final' and countersigned_by = '00000000-0000-4000-a000-000000000902' and countersigned_at is not null
           from public.visit_reports where id = (select id from r2)), 'countersigned → final, with who and when');
select is(public.countersign_report((select id from r2), 'a6000000-0000-4000-8000-000000000036') ->> 'reason',
  'not_awaiting_countersignature', 'a final report is not countersigned twice');
reset role;

-- Scope: nobody outside the team reads; Operations sees only "final yes/no" ---------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.visit_reports), 0, 'operations (no team) reads no report content');
select is((select count(*)::int from public.final_report_visits()
           where visit_id in ('00000000-0000-4000-a000-000000000501', 'a6000000-0000-4000-8000-000000000601')), 2,
  'operations sees which visits have a final report');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.visit_reports) + (select count(*)::int from public.final_report_visits()), 0,
  'another organisation sees nothing');
reset role;

select ok((select count(*) from public.audit_events where table_name = 'visit_reports' and command = 'sign_report') >= 2,
  'signing is audited with the command name');

select * from finish();
rollback;
