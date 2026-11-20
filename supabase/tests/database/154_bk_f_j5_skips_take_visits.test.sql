-- BK-f, contract 2026-11-20 06:39 point 2 (h), decision (a): BKF-F1 was red first (4c247b0, CI run 44686853245, 23502);
-- migration 0154 makes the J5 path skip case-less take visits.
-- Reproduction for finding BKF-F1 (docs/engineering/probes/BK-f_ADR_DRAFT.md; probe branch probe/bk-f-j5-caseless-20261120).
--
-- Claim (from code reading):
--   A BK take visit has `case_id = null` (0138 writes it so). Once its report is `final`, the J5 monthly generation
--   `public.generate_billable_facts(month)` (0051) calls `private.build_billable_fact` for it, which inserts into
--   `public.billable_facts` whose `case_id` is `not null` (0022). Expected on current code: the whole call fails with
--   SQLSTATE 23502 for the team's month (or, if a helper raises earlier, with another SQLSTATE). Either way the J5
--   preview of that month breaks, and a KLV-modelled fact path is reached by a BK shift, which D-44/BK-10 exclude.
-- Expected after the fix (first commit of BK-f, or a safety fix if the PO names one): generation succeeds and writes no
-- J5 fact and no working-time fact through the J5 path for a case-less visit.
--
-- Fixture models the case-less part directly (visit with case_id null, final report); a full take chain is in pgTAP 148.
-- Seed: Testorganisation S …019, Testteam Basel …1b9, pflegebs …9e6. All data synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(3);

create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('a1540000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.gen_state(p_month date) returns text language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-a000-0000000009e6', 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', '00000000-0000-4000-a000-0000000009e6', true);
  execute 'set local role authenticated';
  perform public.generate_billable_facts(p_month);
  execute 'reset role';
  return 'ok';
exception when others then
  execute 'reset role';
  return sqlstate;
end $$;

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, status,
                                responsible_user_id)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(1), null, '00000000-0000-4000-a000-0000000001b9',
        (private.now() at time zone 'Europe/Zurich')::date - 1, '07:00', '15:00', 'completed',
        '00000000-0000-4000-a000-0000000009e6');
insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by, signed_by, signed_at)
values ('00000000-0000-4000-b000-000000000019', pg_temp.id(2), pg_temp.id(1), null,
        '00000000-0000-4000-a000-0000000001b9', 1, 'final', '{"synthetic": true}'::jsonb,
        '00000000-0000-4000-a000-0000000009e6', false, '00000000-0000-4000-a000-0000000009e6',
        '00000000-0000-4000-a000-0000000009e6', private.now());

select is(pg_temp.gen_state((private.now() at time zone 'Europe/Zurich')::date - 1), 'ok',
  'BKF-F1: J5 monthly generation succeeds when the month holds a final report on a case-less (take) visit');
select is((select count(*)::int from public.billable_facts where visit_id = pg_temp.id(1)), 0,
  'BKF-F1: no J5 (KLV-modelled) fact for a case-less visit (D-44, BK-10)');
select is((select count(*)::int from public.working_time_facts where visit_id = pg_temp.id(1)), 0,
  'BKF-F1: no working-time fact through the J5 path for a case-less visit (BK-f decides its own time record)');

select * from finish();
rollback;
