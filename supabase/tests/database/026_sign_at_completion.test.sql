-- F7: sign at completion (PO brief docs/agents/briefs/F7.md).
-- Users: nurse …902 (Testteam Nord, registered nurse) · coach …901 (joins Testteam Nord as care assistant here)
--        foreign admin …903 (org B) · operations …904 (org A, no team)
-- Visit a7…701 (inserted here, today, category A, run by the care assistant).
begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

-- CSR1 / CGR-02 (0041): sign_report carries the hash of the snapshot /field shows (field_reports.snapshot_hash).
create function pg_temp.shown_hash(rid uuid) returns text language sql as $f$
  select f.snapshot_hash from public.visit_reports r join public.care_visits v on v.id = r.visit_id
  cross join lateral public.field_reports(v.visit_date) f where r.id = rid and f.report_id = rid
$f$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select ok(not has_function_privilege('anon', 'public.field_countersign_queue()', 'execute'), 'anon cannot read the queue');

insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status, planned_minutes_a)
values ('00000000-0000-4000-b000-000000000011', 'a7000000-0000-4000-8000-000000000701', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', (now() at time zone 'Europe/Zurich')::date, '16:00', '16:30', array['Grundpflege'], false, 'planned', 30);

-- The care assistant completes the visit; the draft exists at once and she signs it with one confirmation.
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
do $$ begin
  perform public.start_visit('a7000000-0000-4000-8000-000000000701', 'a7000000-0000-4000-8000-000000000001');
  perform public.complete_visit('a7000000-0000-4000-8000-000000000701', 'a7000000-0000-4000-8000-000000000002');
end $$;
select is(public.create_report_draft('a7000000-0000-4000-8000-000000000701', null, 'a7000000-0000-4000-8000-000000000003') ->> 'result',
  'ok', 'completion opens the draft (built from the visit data)');
select ok((select snapshot -> 'planned' ->> 'a' = '30' and jsonb_array_length(snapshot -> 'events') >= 2
           from public.visit_reports where visit_id = 'a7000000-0000-4000-8000-000000000701'),
  'the draft carries the visit data, no re-entry');
select is(public.sign_report((select id from public.visit_reports where visit_id = 'a7000000-0000-4000-8000-000000000701'), pg_temp.shown_hash((select id from public.visit_reports where visit_id = 'a7000000-0000-4000-8000-000000000701')),
          'a7000000-0000-4000-8000-000000000004') ->> 'result', 'ok', 'she signs at completion');
select is((select count(*)::int from public.field_countersign_queue()), 0, 'nobody countersigns their own report: not in her queue');
reset role;

-- The countersignature request reaches the team's registered nurses at once, in their day view.
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok(exists (select 1 from public.field_countersign_queue() where visit_id = 'a7000000-0000-4000-8000-000000000701'),
  'a registered nurse of the team sees the request in her queue');
select is(public.countersign_report((select report_id from public.field_countersign_queue() where visit_id = 'a7000000-0000-4000-8000-000000000701'),
          'a7000000-0000-4000-8000-000000000005') ->> 'result', 'ok', 'and countersigns from it');
select is((select count(*)::int from public.field_countersign_queue() where visit_id = 'a7000000-0000-4000-8000-000000000701'), 0,
  'a final report leaves the queue');
reset role;

-- Nobody outside the team sees the queue.
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from public.field_countersign_queue()), 0, 'Operations sees no countersignature queue');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.field_countersign_queue()), 0, 'another organisation sees nothing');
reset role;

select * from finish();
rollback;
