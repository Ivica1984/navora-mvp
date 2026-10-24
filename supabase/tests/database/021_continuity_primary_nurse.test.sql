-- J6: primary nurse and continuity measure (PO brief docs/agents/briefs/J6.md).
-- Users: nurse …902 (Testteam Nord, RN) · coach …901 and ops …904 join Testteam Nord as care assistants here · foreign …903
-- Case …208 (Testteam Nord, laufend) · visit …501 (today, planned)
begin;
create extension if not exists pgtap with schema extensions;

select plan(19);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000901', 'care_assistant'),
  ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000904', 'care_assistant');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is(public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902',
          '00000000-0000-4000-a000-000000000901', null, 'ab000000-0000-4000-8000-000000000001'), 'ok',
  'the team names a primary nurse and a deputy (first assignment, no reason needed)');
select is(public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902',
          '00000000-0000-4000-a000-000000000901', null, 'ab000000-0000-4000-8000-000000000001'), 'duplicate', 'resend is a duplicate');
select is(public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902',
          '00000000-0000-4000-a000-000000000901', null, 'ab000000-0000-4000-8000-000000000002'), 'unchanged', 'same values change nothing');
select is(public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000903',
          null, 'Fremd', 'ab000000-0000-4000-8000-000000000003'), 'not_in_team', 'the primary nurse must be in the assigned team');
select throws_ok($$ select public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000902',
          '00000000-0000-4000-a000-000000000902', null, 'ab000000-0000-4000-8000-000000000004') $$, '22023', null,
  'the deputy differs from the primary nurse');
select throws_ok($$ select public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000901',
          '00000000-0000-4000-a000-000000000902', null, 'ab000000-0000-4000-8000-000000000005') $$, '22023', null,
  'changing the primary nurse needs a reason');
select is(public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000901',
          '00000000-0000-4000-a000-000000000902', 'Wechsel wegen Ferien', 'ab000000-0000-4000-8000-000000000006'), 'ok',
  'with a reason the primary nurse changes');
select is((select primary_nurse_id from public.team_cases() where case_id = '00000000-0000-4000-a000-000000000208'),
  '00000000-0000-4000-a000-000000000901'::uuid, 'the team view shows the primary nurse');
reset role;

select is((select reason || ' / ' || (changes ? 'primary_nurse_id')::text from public.change_log where command = 'set_primary_nurse'),
  'Wechsel wegen Ferien / true', 'the change is logged with its reason');
select ok(exists (select 1 from public.audit_events where table_name = 'cases' and command = 'set_primary_nurse'), 'and audited');

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is(public.set_primary_nurse('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000903',
          null, 'x y z', 'ab000000-0000-4000-8000-000000000007'), 'rejected', 'another organisation cannot set it');
reset role;

-- Planning: flag, never block -----------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok((select r ->> 'result' = 'ok' and (r -> 'flags') ? 'not_primary'
           from (select public.plan_visit('00000000-0000-4000-a000-000000000208', (now() at time zone 'Europe/Zurich')::date + 2, '15:00', '15:30', 30, 0, 0, false,
                                          '00000000-0000-4000-a000-000000000904', 'ab000000-0000-4000-8000-000000000010') r) x),
  'a visit for someone who is neither primary nor deputy is planned, with a flag');
select ok((select not ((r -> 'flags') ? 'not_primary')
           from (select public.plan_visit('00000000-0000-4000-a000-000000000208', (now() at time zone 'Europe/Zurich')::date + 3, '15:00', '15:30', 30, 0, 0, false,
                                          '00000000-0000-4000-a000-000000000902', 'ab000000-0000-4000-8000-000000000011') r) x),
  'the deputy raises no flag');

-- Continuity measure ----------------------------------------------------------------------------------------------------
do $$ begin
  perform public.start_visit('00000000-0000-4000-a000-000000000501', 'ab000000-0000-4000-8000-000000000020');
  perform public.complete_visit('00000000-0000-4000-a000-000000000501', 'ab000000-0000-4000-8000-000000000021');
end $$;
select ok((select visits >= 1 and distinct_nurses >= 1 and primary_set from public.continuity_by_case((now() at time zone 'Europe/Zurich')::date)
           where case_id = '00000000-0000-4000-a000-000000000208'), 'the team sees visits and distinct nurses per client this month');
select is((select primary_share_pct from public.continuity_by_case((now() at time zone 'Europe/Zurich')::date) where case_id = '00000000-0000-4000-a000-000000000208'), 0,
  'and the share of visits by the primary nurse');
reset role;
select is(
  (select array_agg(a) from unnest((select proargnames from pg_proc where oid = 'public.continuity_by_case(date)'::regprocedure)) a
   where a ~ '(user|nurse_id|performer|member)'),
  null, 'no per-nurse figures: the measure is never an individual ranking');

select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select ok((select count(*) from public.continuity_by_case((now() at time zone 'Europe/Zurich')::date)) > 0, 'coordination roles (coach) see the measure');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.continuity_by_case((now() at time zone 'Europe/Zurich')::date) where case_id = '00000000-0000-4000-a000-000000000208'), 0,
  'another organisation sees nothing');
reset role;
select ok(private.visit_flags('00000000-0000-4000-a000-000000000208', (now() at time zone 'Europe/Zurich')::date + 5, 0,
          '00000000-0000-4000-a000-000000000901', 'planned', '10:00') = '{}'::text[] or
          not ('not_primary' = any (private.visit_flags('00000000-0000-4000-a000-000000000208', (now() at time zone 'Europe/Zurich')::date + 5, 0,
          '00000000-0000-4000-a000-000000000901', 'planned', '10:00'))), 'the primary nurse raises no flag');

select * from finish();
rollback;
