-- CSR1 part 3: F1-F4's clinical-gate findings (Clinical Governance Report 2026-10-22 22:30; migration 0040, ADR-051).
-- CGR-01: only the author supersedes her observation; a colleague's supersede is `rejected`, she adds her own instead.
-- CGR-03 (F3/F4 part): signed means fixed. While the latest report version is `signed` or `final`, time corrections
--   and observations are refused; a report correction version (F6 `correct_report`) reopens them and carries the
--   changed facts into the next signed version, while the earlier signed version stays unchanged.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Testteam Nord).
-- All visit and report steps go through the real commands (start, complete, draft, sign, correct, countersign).
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

-- CSR1 / CGR-02 (0041): sign_report carries the hash of the snapshot /field shows (field_reports.snapshot_hash).
create function pg_temp.shown_hash(rid uuid) returns text language sql as $f$
  select f.snapshot_hash from public.visit_reports r join public.care_visits v on v.id = r.visit_id
  cross join lateral public.field_reports(v.visit_date) f where r.id = rid and f.report_id = rid
$f$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
select ok(not has_function_privilege('authenticated', 'private.visit_facts_locked(uuid)', 'execute'),
  'the lock helper is internal (no report state leaks to callers)');

create temp table fx (name text primary key, id uuid not null);
grant select on fx to authenticated;
insert into fx values
  ('rn', '00000000-0000-4000-a040-000000000001'),   -- …902 performs and signs (final, no countersignature)
  ('ca', '00000000-0000-4000-a040-000000000002');   -- …906 performs and signs (signed, awaiting countersignature)

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', (private.now() at time zone 'Europe/Zurich')::date, x.t,
       x.t + interval '30 minutes', array['Grundpflege'], false, 'planned', 30, x.who
from fx f join (values
  ('rn', time '06:00', '00000000-0000-4000-a000-000000000902'::uuid),
  ('ca', time '06:30', '00000000-0000-4000-a000-000000000906'::uuid)
) as x(name, t, who) on x.name = f.name;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.started_event(n text) returns bigint language sql as $$
  select e.id from public.visit_events e where e.visit_id = pg_temp.vid(n) and e.event_type = 'started' $$;
create function pg_temp.latest_report(n text) returns uuid language sql as $$
  select r.id from public.visit_reports r
  where r.visit_id = pg_temp.vid(n) and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id) $$;
create function pg_temp.obs(content_like text) returns uuid language sql as $$
  select o.id from public.visit_observations o where o.content like content_like $$;

-- CGR-01: only the author supersedes -----------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.start_visit(pg_temp.vid('rn'), 'a4000000-0000-4000-8000-000000000001'), 'ok', 'the registered nurse starts the visit');
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: Klientin wach, isst gut.', false, null,
          'a4000000-0000-4000-8000-000000000002'), 'ok', 'she records an observation');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: Klientin isst wenig.', false,
          pg_temp.obs('Synthetisch: Klientin wach, isst gut.'), 'a4000000-0000-4000-8000-000000000003'),
  'rejected', 'CGR-01: a colleague cannot supersede her observation');
reset role;
select is((select count(*)::int from public.visit_observations where supersedes_id = pg_temp.obs('Synthetisch: Klientin wach, isst gut.')),
  0, 'CGR-01: the refused supersede writes nothing');
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: aus meiner Sicht isst sie wenig.', false, null,
          'a4000000-0000-4000-8000-000000000004'), 'ok', 'CGR-01: the colleague adds her own observation instead');
select is((select count(*)::int from public.field_notes((private.now() at time zone 'Europe/Zurich')::date)
           where kind = 'observation' and visit_id = pg_temp.vid('rn')),
  2, 'both statements stay current, side by side');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: Klientin wach, isst gut, trinkt wenig.', false,
          pg_temp.obs('Synthetisch: Klientin wach, isst gut.'), 'a4000000-0000-4000-8000-000000000005'),
  'ok', 'the author supersedes her own observation');
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: fremde Fassung ändern', false,
          pg_temp.obs('Synthetisch: aus meiner Sicht isst sie wenig.'), 'a4000000-0000-4000-8000-000000000006'),
  'rejected', 'CGR-01: the same holds the other way round');

-- CGR-03: open while the report is a draft ---------------------------------------------------------------------------
select is(public.complete_visit(pg_temp.vid('rn'), 'a4000000-0000-4000-8000-000000000010'), 'ok', 'she completes the visit');
select is(public.create_report_draft(pg_temp.vid('rn'), null, 'a4000000-0000-4000-8000-000000000011') ->> 'result', 'ok',
  'the draft is created');
reset role;
select ok(not private.visit_facts_locked(pg_temp.vid('rn')), 'a draft does not lock the facts');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_visit_time(pg_temp.started_event('rn'), private.now() - interval '20 minutes', 'Start zu spät getippt',
          'a4000000-0000-4000-8000-000000000012'), 'ok', 'a time correction before signing is accepted');
select is(public.sign_report(pg_temp.latest_report('rn'), pg_temp.shown_hash(pg_temp.latest_report('rn')), 'a4000000-0000-4000-8000-000000000013') ->> 'result', 'ok',
  'she signs');
reset role;
select is((select status from public.visit_reports where id = pg_temp.latest_report('rn')), 'final',
  'a registered nurse''s signature makes the report final');

-- CGR-03: final → fixed ---------------------------------------------------------------------------------------------
select ok(private.visit_facts_locked(pg_temp.vid('rn')), 'CGR-03: a final report locks the facts');
create temp table signed_v1 as
  select id, snapshot from public.visit_reports where id = pg_temp.latest_report('rn');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_visit_time(pg_temp.started_event('rn'), private.now() - interval '40 minutes', 'nachträglich anders',
          'a4000000-0000-4000-8000-000000000020'), 'rejected', 'CGR-03: a time correction after final is refused');
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: nachträglich ergänzt', false, null,
          'a4000000-0000-4000-8000-000000000021'), 'rejected', 'CGR-03: a new observation after final is refused');
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: nachträglich geändert', false,
          pg_temp.obs('Synthetisch: Klientin wach, isst gut, trinkt wenig.'), 'a4000000-0000-4000-8000-000000000022'),
  'rejected', 'CGR-03: superseding her own observation after final is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: Kollegin ergänzt', false, null,
          'a4000000-0000-4000-8000-000000000023'), 'rejected', 'CGR-03: a colleague''s observation after final is refused');
reset role;
select is((select count(*)::int from public.visit_time_corrections where visit_id = pg_temp.vid('rn')), 1,
  'CGR-03: nothing was written after final (one correction, from before signing)');
select is((select count(*)::int from public.visit_observations where visit_id = pg_temp.vid('rn')), 3,
  'CGR-03: nothing was written after final (three observation rows, from before signing)');

-- F6 path: a correction version reopens the facts and carries them ---------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('rn'), 'Startzeit und Beobachtung ergänzt', null,
          'a4000000-0000-4000-8000-000000000030') ->> 'result', 'ok', 'a correction version is opened');
reset role;
select ok(not private.visit_facts_locked(pg_temp.vid('rn')), 'the correction draft reopens the facts');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_visit_time(pg_temp.started_event('rn'), private.now() - interval '25 minutes', 'Start laut Notiz',
          'a4000000-0000-4000-8000-000000000031'), 'ok', 'a time correction goes through the correction version');
select is(public.record_observation(pg_temp.vid('rn'), 'Synthetisch: Korrekturfassung ergänzt', false, null,
          'a4000000-0000-4000-8000-000000000032'), 'ok', 'an observation goes through the correction version');
select is(public.sign_report(pg_temp.latest_report('rn'), pg_temp.shown_hash(pg_temp.latest_report('rn')), 'a4000000-0000-4000-8000-000000000033') ->> 'result', 'ok',
  'she signs the correction version');
reset role;
select ok((select snapshot::text like '%Korrekturfassung ergänzt%' from public.visit_reports where id = pg_temp.latest_report('rn')),
  'the signed correction version carries the new observation');
select ok((select r.snapshot = s.snapshot from public.visit_reports r join signed_v1 s on s.id = r.id),
  'the earlier signed version is unchanged');
select ok(private.visit_facts_locked(pg_temp.vid('rn')), 'the signed correction version locks the facts again');

-- `signed` (awaiting countersignature) locks too ----------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('ca'), 'a4000000-0000-4000-8000-000000000040');
  perform public.complete_visit(pg_temp.vid('ca'), 'a4000000-0000-4000-8000-000000000041');
  perform public.create_report_draft(pg_temp.vid('ca'), null, 'a4000000-0000-4000-8000-000000000042');
  perform public.sign_report(pg_temp.latest_report('ca'), pg_temp.shown_hash(pg_temp.latest_report('ca')), 'a4000000-0000-4000-8000-000000000043');
end $$;
select is(public.correct_visit_time(pg_temp.started_event('ca'), private.now() - interval '10 minutes', 'Start zu spät getippt',
          'a4000000-0000-4000-8000-000000000044'), 'rejected',
  'CGR-03: while the report awaits countersignature, a time correction is refused');
reset role;
select is((select status from public.visit_reports where id = pg_temp.latest_report('ca')), 'signed',
  'the care assistant''s report awaits countersignature');

select * from finish();
rollback;
