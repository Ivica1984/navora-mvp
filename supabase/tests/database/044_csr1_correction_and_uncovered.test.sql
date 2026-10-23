-- CSR1, seventh PR (migration 0044, ADR-055): CGR-19 (F6) and CGR-22 (OPS1), the PO's interim criteria in
-- `docs/agents/briefs/CSR1.md`. Clinical Governance Report sections 2026-10-23 02:28 (CGR-19) and 06:30 (CGR-22).
-- CGR-19: `correct_report` is refused (`performer_not_in_team`) while the report's performer is not a member of the
--         team; no draft row; the final version stays in force. Performer still a member → allowed as today.
-- CGR-22: the hand close of `visit_uncovered` is refused (`cause_persists`) while the visit is planned and nobody is
--         responsible; it ends with its cause (someone starts it or becomes responsible, or the visit is cancelled).
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · nurse …906 (care assistant, Nord) · ops …904
--        (operations, org A). All data synthetic. Steps go through the real commands; leaving the team and the plan
--        regeneration that sets a responsible member are simulated as the table owner (marked below).
begin;
create extension if not exists pgtap with schema extensions;

select plan(34);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Privileges and the helper -----------------------------------------------------------------------------------------
select ok(not has_function_privilege('authenticated', 'private.exception_closes_with_cause(uuid, text)', 'execute'),
  'the closes-with-cause helper is internal');
select ok(private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'visit_uncovered'),
  'CGR-22: visit_uncovered closes only with its cause');
select ok(private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'visit_uncovered_hospital'),
  'a safety exception still does (CGR-06)');
select ok(not private.exception_closes_with_cause('00000000-0000-4000-b000-000000000011', 'report_not_final'),
  'an administrative exception does not');
select ok(not private.exception_is_safety('00000000-0000-4000-b000-000000000011', 'visit_uncovered'),
  'visit_uncovered is not made a safety exception: its priority stays with D-28');
select ok(has_function_privilege('authenticated', 'public.correct_report(uuid, text, text, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.correct_report(uuid, text, text, uuid)', 'execute'),
  'correct_report: members yes, anon no');

-- Fixtures (synthetic) ----------------------------------------------------------------------------------------------
create temp table fx (name text primary key, id uuid not null, at timestamptz not null, resp uuid);
grant select on fx to authenticated;
insert into fx values
  ('unc',    '00000000-0000-4000-a044-000000000001', now() + interval '3 hours', null),   -- ends by a start
  ('unc2',   '00000000-0000-4000-a044-000000000002', now() + interval '5 hours', null),   -- ends by a cancellation
  ('legacy', '00000000-0000-4000-a044-000000000003', now() + interval '6 hours', null),   -- closed before 0044
  ('rep_rn', '00000000-0000-4000-a044-000000000011', now() - interval '3 hours', '00000000-0000-4000-a000-000000000902'),
  ('rep_ca', '00000000-0000-4000-a044-000000000012', now() - interval '2 hours', '00000000-0000-4000-a000-000000000906');

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, responsible_user_id)
select '00000000-0000-4000-b000-000000000011', f.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       (f.at at time zone 'Europe/Zurich')::date, (f.at at time zone 'Europe/Zurich')::time,
       ((f.at + interval '30 minutes') at time zone 'Europe/Zurich')::time, array['Grundpflege'], false, 'planned', 30, f.resp
from fx f;

-- A close written before 0044 (the old command allowed it for visit_uncovered).
insert into public.exception_events (organization_id, exception_key, kind, text, actor_id)
values ('00000000-0000-4000-b000-000000000011', 'visit_uncovered:00000000-0000-4000-a044-000000000003', 'close',
        'Vor 0044 geschlossen: Team kümmert sich', '00000000-0000-4000-a000-000000000904');

create function pg_temp.vid(n text) returns uuid language sql as $$ select id from fx where name = n $$;
create function pg_temp.ops(n text) returns table (exception_key text, priority text, closable boolean) language sql as $$
  select x.exception_key, x.priority, x.closable from public.operations_exceptions() x
  where x.exception_type = 'visit_uncovered' and x.entity_id = pg_temp.vid(n) $$;
create function pg_temp.latest_report(n text) returns uuid language sql as $$
  select r.id from public.visit_reports r
  where r.visit_id = pg_temp.vid(n) and not exists (select 1 from public.visit_reports s where s.supersedes_id = r.id) $$;
create function pg_temp.shown_hash(n text) returns text language sql as $$
  -- the visit's own Zurich date: a visit 2-3 hours ago is yesterday shortly after midnight
  select f.snapshot_hash from fx x, public.field_reports((x.at at time zone 'Europe/Zurich')::date) f
  where x.name = n and f.visit_id = x.id $$;

-- CGR-22: the uncovered exception cannot be closed by hand ------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select priority from pg_temp.ops('unc')), 'P2', 'the uncovered visit is listed, priority unchanged (P2, D-28)');
select is((select closable from pg_temp.ops('unc')), false, 'CGR-22: Operations is not offered "Schliessen" for it');
select is(public.handle_exception((select exception_key from pg_temp.ops('unc')), 'close', 'Team kümmert sich',
          'a4400000-0000-4000-8000-000000000001'), 'cause_persists', 'CGR-22: a hand close is refused (cause_persists)');
select is(public.handle_exception((select exception_key from pg_temp.ops('unc')), 'take', null,
          'a4400000-0000-4000-8000-000000000002'), 'ok', 'Operations can still take it over');
select is(public.handle_exception((select exception_key from pg_temp.ops('unc')), 'comment', 'Synthetisch: Team angefragt',
          'a4400000-0000-4000-8000-000000000003'), 'ok', 'and add a note');
select is((select count(*)::int from pg_temp.ops('unc')), 1, 'it stays listed after take over and note');
select is((select count(*)::int from pg_temp.ops('legacy')), 1, 'a close written before 0044 no longer hides it');
select is((select closable from pg_temp.ops('legacy')), false, 'and it is not closable either');
select is(public.handle_exception((select exception_key from pg_temp.ops('legacy')), 'take', null,
          'a4400000-0000-4000-8000-000000000004'), 'ok', 'the legacy-closed exception can be taken over');
reset role;
select is((select count(*)::int from public.exception_events
           where exception_key = 'visit_uncovered:00000000-0000-4000-a044-000000000001' and kind = 'close'), 0,
  'the refused close wrote nothing');

-- It ends with its cause: a start, a cancellation, a responsible member --------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select lives_ok($$ select public.start_visit(pg_temp.vid('unc'), 'a4400000-0000-4000-8000-000000000010') $$,
  'a team member starts the uncovered visit');
select is(public.cancel_visit(pg_temp.vid('unc2'), 'team_cancelled', null, 'a4400000-0000-4000-8000-000000000011'), 'ok',
  'a team member cancels the other uncovered visit');
reset role;
-- Simulated as the table owner: the plan regeneration (0030) sets a responsible member on the legacy visit.
update public.care_visits set responsible_user_id = '00000000-0000-4000-a000-000000000902' where id = pg_temp.vid('legacy');

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is((select count(*)::int from pg_temp.ops('unc')), 0, 'started: the exception ends with its cause');
select is((select count(*)::int from pg_temp.ops('unc2')), 0, 'cancelled: the exception ends with its cause');
select is((select count(*)::int from pg_temp.ops('legacy')), 0, 'someone responsible: the exception ends with its cause');
select is((select count(*)::int from public.operations_exceptions() where closable and exception_type = 'visit_uncovered'), 0,
  'no listed uncovered visit is closable');
reset role;

-- CGR-19: reports, final, by a registered nurse (…902) and by a care assistant countersigned by …902 ------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('rep_rn'), 'a4400000-0000-4000-8000-000000000020');
  perform public.complete_visit(pg_temp.vid('rep_rn'), 'a4400000-0000-4000-8000-000000000021');
  perform public.create_report_draft(pg_temp.vid('rep_rn'), 'Synthetisch', 'a4400000-0000-4000-8000-000000000022');
  perform public.sign_report(pg_temp.latest_report('rep_rn'), pg_temp.shown_hash('rep_rn'), 'a4400000-0000-4000-8000-000000000023');
end $$;
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
do $$ begin
  perform public.start_visit(pg_temp.vid('rep_ca'), 'a4400000-0000-4000-8000-000000000030');
  perform public.complete_visit(pg_temp.vid('rep_ca'), 'a4400000-0000-4000-8000-000000000031');
  perform public.create_report_draft(pg_temp.vid('rep_ca'), 'Synthetisch', 'a4400000-0000-4000-8000-000000000032');
  perform public.sign_report(pg_temp.latest_report('rep_ca'), pg_temp.shown_hash('rep_ca'), 'a4400000-0000-4000-8000-000000000033');
end $$;
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.countersign_report(pg_temp.latest_report('rep_ca'), 'a4400000-0000-4000-8000-000000000034') ->> 'result', 'ok',
  'the registered nurse countersigns the care assistant''s report');
reset role;
select ok((select bool_and(r.status = 'final') from public.visit_reports r where r.visit_id in (pg_temp.vid('rep_rn'), pg_temp.vid('rep_ca'))),
  'both reports are final');

-- Simulated as the table owner: the registered nurse …902 leaves Testteam Nord.
create temp table saved_membership as
  select * from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101' and user_id = '00000000-0000-4000-a000-000000000902';
delete from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101' and user_id = '00000000-0000-4000-a000-000000000902';

select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('rep_rn'), 'Synthetisch: Zeit prüfen', null, 'a4400000-0000-4000-8000-000000000040')
          ->> 'reason', 'performer_not_in_team', 'CGR-19: a correction of a report whose performer left the team is refused');
select is(public.correct_report(pg_temp.latest_report('rep_rn'), 'Synthetisch: Zeit prüfen', null, 'a4400000-0000-4000-8000-000000000040')
          ->> 'reason', 'performer_not_in_team', 'the same request again is refused the same way (a refusal records nothing)');
reset role;
select is((select count(*)::int from public.visit_reports where visit_id = pg_temp.vid('rep_rn')), 1, 'no correction draft row was written');
select ok((select status = 'final' from public.visit_reports where id = pg_temp.latest_report('rep_rn')),
  'the final version stays in force');
select ok(private.visit_facts_locked(pg_temp.vid('rep_rn')), 'and the visit''s facts stay locked');
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is((select f.status from fx x, public.field_reports((x.at at time zone 'Europe/Zurich')::date) f
            where x.name = 'rep_rn' and f.visit_id = x.id),
  'final', 'the team still reads the final report');
select is(public.correct_report(pg_temp.latest_report('rep_ca'), 'Synthetisch: Massnahme ergänzen', null, 'a4400000-0000-4000-8000-000000000041')
          ->> 'result', 'ok', 'a correction of a report whose performer is still a member is allowed as today');
reset role;
select ok((select status = 'draft' and performer_id = '00000000-0000-4000-a000-000000000906' and version = 2
           from public.visit_reports where id = pg_temp.latest_report('rep_ca')),
  'it is a correction draft carrying the performer');
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('rep_rn'), 'Synthetisch: Zeit prüfen', null, 'a4400000-0000-4000-8000-000000000042')
          ->> 'reason', 'not_team_member', 'the performer herself, outside the team, is refused as before');
reset role;

-- She returns to the team: the refusal follows the membership, it is not a mark on the report.
insert into public.team_memberships select * from saved_membership;
select pg_temp.act_as('00000000-0000-4000-a000-000000000906');
set local role authenticated;
select is(public.correct_report(pg_temp.latest_report('rep_rn'), 'Synthetisch: Zeit prüfen', null, 'a4400000-0000-4000-8000-000000000043')
          ->> 'result', 'ok', 'with the performer back in the team the correction is allowed');
reset role;

select * from finish();
rollback;
