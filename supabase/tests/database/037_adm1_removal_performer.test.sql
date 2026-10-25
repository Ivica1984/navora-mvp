-- ADM1 follow-up, CGR-18 (Clinical Governance Report 2026-10-23 02:28; migration 0037).
-- Documentation belongs to the performer (first `started` actor). Removal is refused while she performs a visit of
-- the team that is not completed, or performed a completed visit that has no signed or final report.
-- Users: admin …905 · nurse …902 (registered nurse, Testteam Nord …101, responsible for the colleague visit)
--        · nurse …906 (care assistant, Nord: the performer B who is removed) · coach …901 (joins Nord here as a
--        registered nurse, for the `final` case).
-- The CGR-18 cases (1)-(4) of the report: (1) B starts A's visit → refused, nothing released; (2) completed, no
-- report → refused; (3) draft → refused; (4) signed (awaiting countersignature) or final → allowed.
-- All visit and report steps go through the real commands (start, pause, resume, complete, draft, sign).
begin;
create extension if not exists pgtap with schema extensions;

select plan(24);

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
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'registered_nurse');

create temp table fx (name text primary key, id uuid not null);
grant select on fx to authenticated;
insert into fx values
  ('colleague', '00000000-0000-4000-a037-000000000001'),   -- …902 responsible; …906 starts and performs it
  ('mine',      '00000000-0000-4000-a037-000000000002'),   -- …906 responsible, planned tomorrow: released at removal
  ('rn',        '00000000-0000-4000-a037-000000000003');   -- …902 responsible; coach …901 performs and signs (final)

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end,
                                services_provided, billable, status, planned_minutes_a, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', x.d, x.t, x.t + interval '30 minutes', array['Grundpflege'], false,
       'planned', 30, x.who
from fx f join (values
  ('colleague', (private.now() at time zone 'Europe/Zurich')::date,     time '07:00', '00000000-0000-4000-a000-000000000902'::uuid),
  ('mine',      (private.now() at time zone 'Europe/Zurich')::date + 1, time '09:00', '00000000-0000-4000-a000-000000000906'::uuid),
  ('rn',        (private.now() at time zone 'Europe/Zurich')::date,     time '08:00', '00000000-0000-4000-a000-000000000902'::uuid)
) as x(name, d, t, who) on x.name = f.name;

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.resp(n text) returns uuid language sql as $$
  select v.responsible_user_id from public.care_visits v where v.id = pg_temp.vid(n) $$;
create function pg_temp.is_member(u text) returns boolean language sql as $$
  select exists (select 1 from public.team_memberships
                 where team_id = '00000000-0000-4000-a000-000000000101' and user_id = u::uuid) $$;
-- Remove a member of Testteam Nord; called as the administrator …905 (act_as + role authenticated); returns the result code.
create function pg_temp.remove(u text, k text) returns text language sql as $$
  select public.remove_team_member('00000000-0000-4000-a000-000000000101', u::uuid, 'Wechsel nach Mitte', k::uuid) ->> 'result' $$;

-- (1) B starts A's visit: performer without being responsible -------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.start_visit(pg_temp.vid('colleague'), 'a3700000-0000-4000-8000-000000000001'), 'ok',
  'the care assistant starts a colleague''s visit (any team member may)');
reset role;
select is(pg_temp.resp('colleague'), '00000000-0000-4000-a000-000000000902'::uuid, 'the colleague stays the responsible member');
select is(private.visit_performer(pg_temp.vid('colleague')), '00000000-0000-4000-a000-000000000906'::uuid,
  'the care assistant is the performer');

select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(pg_temp.remove('00000000-0000-4000-a000-000000000906', 'a3700000-0000-4000-8000-000000000010'), 'has_visit_in_progress',
  'CGR-18 (1): removing the performer of a started visit is refused');
reset role;
select ok(pg_temp.is_member('00000000-0000-4000-a000-000000000906'), 'CGR-18 (1): she stays a member');
select is(pg_temp.resp('mine'), '00000000-0000-4000-a000-000000000906'::uuid, 'CGR-18 (1): the refused removal releases nothing');

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.pause_visit(pg_temp.vid('colleague'), 'a3700000-0000-4000-8000-000000000002'), 'ok', 'she pauses the visit');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(pg_temp.remove('00000000-0000-4000-a000-000000000906', 'a3700000-0000-4000-8000-000000000011'), 'has_visit_in_progress',
  'CGR-18 (1): removing the performer of a paused visit is refused');
reset role;

-- (2) completed, no report ------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.resume_visit(pg_temp.vid('colleague'), 'a3700000-0000-4000-8000-000000000003'), 'ok', 'she resumes the visit');
select is(public.complete_visit(pg_temp.vid('colleague'), 'a3700000-0000-4000-8000-000000000004'), 'ok', 'and completes it');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(pg_temp.remove('00000000-0000-4000-a000-000000000906', 'a3700000-0000-4000-8000-000000000012'), 'has_unsigned_reports',
  'CGR-18 (2): a completed visit she performed without a report refuses the removal');
reset role;
select ok(pg_temp.is_member('00000000-0000-4000-a000-000000000906'), 'CGR-18 (2): she stays a member');

-- (3) draft ---------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.create_report_draft(pg_temp.vid('colleague'), 'Synthetischer Bericht', 'a3700000-0000-4000-8000-000000000005') ->> 'result',
  'ok', 'she drafts the report');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(pg_temp.remove('00000000-0000-4000-a000-000000000906', 'a3700000-0000-4000-8000-000000000013'), 'has_unsigned_reports',
  'CGR-18 (3): a draft report refuses the removal');
reset role;
select is(pg_temp.resp('mine'), '00000000-0000-4000-a000-000000000906'::uuid, 'CGR-18 (3): the refused removal releases nothing');

-- (4a) signed, awaiting countersignature: allowed ---------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.sign_report((select id from public.visit_reports where visit_id = pg_temp.vid('colleague')), pg_temp.shown_hash((select id from public.visit_reports where visit_id = pg_temp.vid('colleague'))),
          'a3700000-0000-4000-8000-000000000006') ->> 'result', 'ok', 'she signs her report');
reset role;
select is((select status from public.visit_reports where visit_id = pg_temp.vid('colleague')), 'signed',
  'a care assistant''s report waits for the countersignature of another registered nurse');

select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.remove_team_member('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000906', 'Wechsel nach Mitte',
          'a3700000-0000-4000-8000-000000000014'),
  jsonb_build_object('result', 'ok', 'released', 1), 'CGR-18 (4): with her report signed she can be removed; her planned visit is released');
reset role;
select ok(not pg_temp.is_member('00000000-0000-4000-a000-000000000906'), 'she is no longer a member');
select is(pg_temp.resp('mine'), null, 'her future planned visit has no responsible member');
select is(pg_temp.resp('colleague'), '00000000-0000-4000-a000-000000000902'::uuid, 'the colleague''s completed visit is untouched');

-- (4b) final: allowed -----------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('rn'), 'a3700000-0000-4000-8000-000000000020');
  perform public.complete_visit(pg_temp.vid('rn'), 'a3700000-0000-4000-8000-000000000021');
  perform public.create_report_draft(pg_temp.vid('rn'), null, 'a3700000-0000-4000-8000-000000000022');
end $$;
select is(public.sign_report((select id from public.visit_reports where visit_id = pg_temp.vid('rn')), pg_temp.shown_hash((select id from public.visit_reports where visit_id = pg_temp.vid('rn'))),
          'a3700000-0000-4000-8000-000000000023') ->> 'result', 'ok', 'a registered nurse signs her report');
reset role;
select is((select status from public.visit_reports where visit_id = pg_temp.vid('rn')), 'final',
  'a registered nurse''s report is final at once');
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(pg_temp.remove('00000000-0000-4000-a000-000000000901', 'a3700000-0000-4000-8000-000000000015'), 'ok',
  'CGR-18 (4): with her report final she can be removed');
reset role;

select * from finish();
rollback;
