-- CSR1 part 4: CGR-02 "she signs what she saw" (F6, F7) (Clinical Governance Report 2026-10-22 22:30; migration 0041,
-- ADR-052). The sign command carries the hash of the snapshot /field showed (field_reports.snapshot_hash) and is
-- rejected with `facts_changed`, writing nothing, when observations or times changed since.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Testteam Nord).
-- All visit and report steps go through the real commands (start, observe, correct, complete, draft, sign, countersign).
begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Privileges ------------------------------------------------------------------------------------------------------------
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'sign_report'), 1, 'exactly one sign_report remains');
select ok(to_regprocedure('public.sign_report(uuid, uuid)') is null, 'the sign command without the shown snapshot is gone');
select ok(has_function_privilege('authenticated', 'public.sign_report(uuid, text, uuid)', 'execute'), 'members can sign');
select ok(not has_function_privilege('anon', 'public.sign_report(uuid, text, uuid)', 'execute'), 'anon cannot sign');
select ok(not has_function_privilege('authenticated', 'private.report_snapshot_hash(jsonb)', 'execute'),
  'the hash helper is internal');

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
create temp table fx (name text primary key, id uuid not null);
grant select on fx to authenticated;
insert into fx values
  ('rn', '00000000-0000-4000-a041-000000000001'),   -- …902 performs and signs (final, no countersignature)
  ('ca', '00000000-0000-4000-a041-000000000002');   -- …906 performs and signs (signed, awaiting countersignature)

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (now() at time zone 'Europe/Zurich')::date, x.t,
       x.t + interval '30 minutes', array['Grundpflege'], false, 'planned', 30, x.who
from fx f join (values
  ('rn', time '05:00', '00000000-0000-4000-a000-000000000902'::uuid),
  ('ca', time '05:30', '00000000-0000-4000-a000-000000000906'::uuid)
) as x(name, t, who) on x.name = f.name;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.latest_report(n text) returns uuid language sql as $$
  select r.id from public.visit_reports r
  where r.visit_id = pg_temp.vid(n) and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id) $$;
-- What /field shows for the visit's latest report version (the caller's view).
create function pg_temp.shown(n text) returns table (snapshot jsonb, snapshot_hash text, status text) language sql as $$
  select f.snapshot, f.snapshot_hash, f.status from public.field_reports((now() at time zone 'Europe/Zurich')::date) f
  where f.visit_id = pg_temp.vid(n) $$;
create function pg_temp.started_event(n text) returns bigint language sql as $$
  select e.id from public.visit_events e where e.visit_id = pg_temp.vid(n) and e.event_type = 'started' $$;
create temp table seen (step text primary key, hash text);
grant all on seen to authenticated;

-- The draft shows the live facts, with the hash of exactly what it shows ----------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('rn'), 'a4100000-0000-4000-8000-000000000001');
  perform public.record_observation(pg_temp.vid('rn'), 'Synthetisch: Klientin wach.', false, null, 'a4100000-0000-4000-8000-000000000002');
  perform public.complete_visit(pg_temp.vid('rn'), 'a4100000-0000-4000-8000-000000000003');
end $$;
select is(public.create_report_draft(pg_temp.vid('rn'), null, 'a4100000-0000-4000-8000-000000000004') ->> 'result', 'ok',
  'completion opens the draft');
insert into seen select 'first', snapshot_hash from pg_temp.shown('rn');
select is((select jsonb_array_length(snapshot -> 'observations') from pg_temp.shown('rn')), 1, 'she sees one observation');
reset role;
select is((select hash from seen where step = 'first'),
          private.report_snapshot_hash(private.visit_report_snapshot(pg_temp.vid('rn'))),
  'the shown hash is the hash of the current facts');

-- A colleague's observation after she looked: signing is refused, nothing written -----------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: Kollegin ergänzt: Sturzgefahr.', false, null,
          'a4100000-0000-4000-8000-000000000010'), 'ok', 'a colleague records an observation while the report is a draft');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.sign_report(pg_temp.latest_report('rn'), (select hash from seen where step = 'first'),
          'a4100000-0000-4000-8000-000000000011') ->> 'reason', 'facts_changed',
  'CGR-02: signing with the hash of what she saw before the change is refused');
reset role;
select ok((select status = 'draft' and signed_by is null and signed_at is null
           from public.visit_reports where id = pg_temp.latest_report('rn')), 'the refused signature writes nothing');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select jsonb_array_length(snapshot -> 'observations') from pg_temp.shown('rn')), 2,
  'the reloaded draft shows the colleague''s observation');
select isnt((select snapshot_hash from pg_temp.shown('rn')), (select hash from seen where step = 'first'),
  'and carries a new hash');
select is(public.sign_report(pg_temp.latest_report('rn'), null, 'a4100000-0000-4000-8000-000000000012') ->> 'reason',
  'facts_changed', 'a signature without a shown snapshot is refused');

-- F7: the summary is saved first, then she signs what she saw (the summary is not part of the facts) ------------------------
insert into seen select 'second', snapshot_hash from pg_temp.shown('rn');
select is(public.update_report_draft(pg_temp.latest_report('rn'), 'Synthetische Zusammenfassung', 'a4100000-0000-4000-8000-000000000013')
          ->> 'result', 'ok', 'she saves the summary');
select is(public.sign_report(pg_temp.latest_report('rn'), (select hash from seen where step = 'second'),
          'a4100000-0000-4000-8000-000000000014') ->> 'result', 'ok', 'she signs the facts she saw');
reset role;
select ok((select status = 'final' and signed_by = '00000000-0000-4000-a000-000000000902'
           from public.visit_reports where id = pg_temp.latest_report('rn')), 'signed by a registered nurse: final');
select is((select private.report_snapshot_hash(snapshot) from public.visit_reports where id = pg_temp.latest_report('rn')),
          (select hash from seen where step = 'second'), 'the stored signed snapshot is exactly the one she saw');
select is((select jsonb_array_length(snapshot -> 'observations') from public.visit_reports where id = pg_temp.latest_report('rn')),
  2, 'it holds both observations');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok((select status = 'final' and snapshot_hash = (select hash from seen where step = 'second') from pg_temp.shown('rn')),
  'a signed version shows its frozen snapshot and that snapshot''s hash');
select is(public.sign_report(pg_temp.latest_report('rn'), (select hash from seen where step = 'second'),
          'a4100000-0000-4000-8000-000000000015') ->> 'reason', 'not_draft', 'a final report is not signed again');

-- Correction version: a time correction after she looked is refused the same way ------------------------------------------
select is(public.correct_report(pg_temp.latest_report('rn'), 'Startzeit prüfen', null, 'a4100000-0000-4000-8000-000000000020')
          ->> 'result', 'ok', 'a correction draft is opened');
insert into seen select 'correction', snapshot_hash from pg_temp.shown('rn');
select is(public.correct_visit_time(pg_temp.started_event('rn'), now() - interval '25 minutes', 'Start zu spät getippt',
          'a4100000-0000-4000-8000-000000000021'), 'ok', 'the time is corrected in the correction draft');
select is(public.sign_report(pg_temp.latest_report('rn'), (select hash from seen where step = 'correction'),
          'a4100000-0000-4000-8000-000000000022') ->> 'reason', 'facts_changed',
  'CGR-02: a time corrected after she looked is not signed unseen');
select is(public.sign_report(pg_temp.latest_report('rn'), (select snapshot_hash from pg_temp.shown('rn')),
          'a4100000-0000-4000-8000-000000000023') ->> 'result', 'ok', 'after reloading she signs the corrected version');
reset role;
select ok((select snapshot -> 'events' @> '[{"type": "started", "corrected": true}]' from public.visit_reports where id = pg_temp.latest_report('rn')),
  'the correction version carries the corrected time');

-- The hash does not depend on the session time zone -------------------------------------------------------------------------
create temp table tz as select private.report_snapshot_hash(private.visit_report_snapshot(pg_temp.vid('rn'))) as h;
set local timezone to 'America/New_York';
select is(private.report_snapshot_hash(private.visit_report_snapshot(pg_temp.vid('rn'))), (select h from tz),
  'the same facts give the same hash in any session time zone');
reset timezone;

-- Countersignature path unchanged: she signs what she saw, a registered nurse countersigns the frozen version -------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('ca'), 'a4100000-0000-4000-8000-000000000030');
  perform public.complete_visit(pg_temp.vid('ca'), 'a4100000-0000-4000-8000-000000000031');
  perform public.create_report_draft(pg_temp.vid('ca'), null, 'a4100000-0000-4000-8000-000000000032');
end $$;
select is(public.sign_report(pg_temp.latest_report('ca'), (select snapshot_hash from pg_temp.shown('ca')),
          'a4100000-0000-4000-8000-000000000033') ->> 'result', 'ok', 'the care assistant signs what she sees');
select is((select status from pg_temp.shown('ca')), 'signed', 'awaiting countersignature');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.countersign_report(pg_temp.latest_report('ca'), 'a4100000-0000-4000-8000-000000000034') ->> 'result', 'ok',
  'a registered nurse countersigns (no hash needed: the signed snapshot is immutable)');
reset role;

select * from finish();
rollback;
