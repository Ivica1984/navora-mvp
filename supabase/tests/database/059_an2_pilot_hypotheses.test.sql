-- AN2 part 2 (migration 0057, ADR-070; brief docs/agents/briefs/AN2.md): the "Pilot-Hypothesen" read model and the
-- AN1 organisation-level suppression condition (PO review of AN1, 2026-10-22 17:15).
-- Org B (…012, admin …903 = coordination role, member of no team). Fixtures in fixed past months (2025), so the seed
-- and the time of day play no part. Teams created here:
--   T3 "AN2 Drei" (performers p1, p2, p3)   T2 "AN2 Zwei" (q1, q2)   T1 "AN2 Eins" (q3)   T2b "AN2 Zwei b" (q4, q5)
-- Performers are synthetic ids (no account); `pg_temp.id(name)` derives a fixed uuid from a fixture name. All data synthetic; fixtures are written as the table owner; the read
-- models are called as `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(57);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.id(n text) returns uuid language sql immutable as $$
  select ('a0590000-0000-4000-8000-' || left(md5(n), 12))::uuid $$;
-- Zurich wall-clock time on a date
create function pg_temp.at(d date, t time) returns timestamptz language sql immutable as $$
  select (d + t) at time zone 'Europe/Zurich' $$;

insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('b3'),  'AN2 Drei',   'Test', 'active'),
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('b2'),  'AN2 Zwei',   'Test', 'active'),
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('b1'),  'AN2 Eins',   'Test', 'active'),
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('b22'), 'AN2 Zwei b', 'Test', 'active');

-- A visit of org B's case …251 with its timeline. `events` lists (type, from, to, minutes after 08:00).
create function pg_temp.visit(p_id text, p_team text, p_date date, p_actor text, p_status text, p_events text[][])
returns void language plpgsql as $$
declare i int;
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
  values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), '00000000-0000-4000-a000-000000000251',
          pg_temp.id(p_team), p_date, '08:00', '09:00', false, p_status);
  for i in 1 .. coalesce(array_length(p_events, 1), 0) loop
    insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
    values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), pg_temp.id(p_team), p_events[i][1], p_events[i][2],
            p_events[i][3], case when p_events[i][1] = 'interrupted' and p_events[i][5] = 'coord'
                                 then '00000000-0000-4000-a000-000000000903'::uuid else pg_temp.id(p_actor) end,
            pg_temp.at(p_date, '08:00') + make_interval(mins => p_events[i][4]::int));
  end loop;
end $$;
create function pg_temp.done(p_id text, p_team text, p_date date, p_actor text) returns void language sql as $$
  select pg_temp.visit(p_id, p_team, p_date, p_actor, 'completed',
    array[array['started', 'on_the_way', 'started', '0', ''], array['completed', 'started', 'completed', '60', '']]) $$;

create function pg_temp.kpi(p_month date, p_kpi text) returns jsonb language sql as $$
  select to_jsonb(k) from public.pilot_kpis(p_month) k where k.kpi = p_kpi and k.team_id is null $$;
create function pg_temp.h(p_measure text, p_team text default null, p_detail text default null) returns jsonb language sql as $$
  select to_jsonb(x) from public.pilot_hypotheses('2025-04-01') x
  where x.measure = p_measure and x.team_id is not distinct from pg_temp.id(p_team) and x.detail is not distinct from p_detail $$;
create function pg_temp.hv(p_measure text, p_team text default null, p_detail text default null) returns numeric language sql as $$
  select (pg_temp.h(p_measure, p_team, p_detail) ->> 'value')::numeric $$;
create function pg_temp.hb(p_measure text, p_team text default null, p_detail text default null) returns int language sql as $$
  select (pg_temp.h(p_measure, p_team, p_detail) ->> 'base')::int $$;

-- =====================================================================================================================
-- A. AN1 condition: the organisation row in three fixtures (pilot_kpis, `time_correction_share` as the probe)
-- =====================================================================================================================
-- January: the only team with visits has two nurses.
select pg_temp.done('101', 'b2', '2025-01-10', 'q1'), pg_temp.done('102', 'b2', '2025-01-11', 'q2');
-- February: one visible three-person team and one hidden one-person team.
select pg_temp.done('201', 'b3', '2025-02-10', 'p1'), pg_temp.done('202', 'b3', '2025-02-10', 'p2'),
       pg_temp.done('203', 'b3', '2025-02-10', 'p3'), pg_temp.done('204', 'b1', '2025-02-11', 'q3');
-- March: two hidden teams of two persons each.
select pg_temp.done('301', 'b2', '2025-03-10', 'q1'), pg_temp.done('302', 'b2', '2025-03-10', 'q2'),
       pg_temp.done('303', 'b22', '2025-03-10', 'q4'), pg_temp.done('304', 'b22', '2025-03-10', 'q5');

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select ok((pg_temp.kpi('2025-01-01', 'time_correction_share') ->> 'value') is null
          and (pg_temp.kpi('2025-01-01', 'time_correction_share') ->> 'too_few')::boolean
          and (pg_temp.kpi('2025-01-01', 'time_correction_share') ->> 'note') like 'Zu wenig Personen%',
  'AN1: an organisation whose only team has two nurses shows no organisation value');
select ok((pg_temp.kpi('2025-02-01', 'time_correction_share') ->> 'value') is null,
  'AN1: one visible three-person team and one hidden one-person team: no organisation value');
select ok((select value is not null from public.pilot_kpis('2025-02-01') where team_id = pg_temp.id('b3') and kpi = 'time_correction_share'),
  'AN1: the visible three-person team still shows its value');
select is((pg_temp.kpi('2025-03-01', 'time_correction_share') ->> 'value')::numeric, 0.0::numeric,
  'AN1: two hidden teams of two persons each: the organisation value shows');
select ok((select count(*) = 2 and bool_and(value is null) from public.pilot_kpis('2025-03-01')
           where team_id in (pg_temp.id('b2'), pg_temp.id('b22')) and kpi = 'time_correction_share'),
  'AN1: and both two-person teams stay hidden');
select ok((pg_temp.kpi('2025-01-01', 'open_p1_exceptions') ->> 'value') is not null,
  'AN1: open P1 exceptions ("Stand jetzt", shown in OPS1 anyway) are not hidden');
reset role;

-- =====================================================================================================================
-- B. AN2 measures, April 2025. T3: p1, p2, p3 perform; T2: q1, q2; T1: q3 (hidden persons 3 → organisation visible)
-- =====================================================================================================================
-- Five completed visits with reports (r1 … r5), one long fragmented visit (l1), two not-completed ends (a1, a2).
select pg_temp.done('401', 'b3', '2025-04-10', 'p1'), pg_temp.done('402', 'b3', '2025-04-10', 'p2'),
       pg_temp.done('403', 'b3', '2025-04-10', 'p3'), pg_temp.done('404', 'b3', '2025-04-11', 'p1'),
       pg_temp.done('405', 'b3', '2025-04-11', 'p2');
-- l1: three pauses, completed at 14:00; planned end 09:00 + visit_stuck 1 h + P1 escalation 3 h = 13:00
select pg_temp.visit('406', 'b3', '2025-04-12', 'p3', 'completed', array[
  array['started', 'on_the_way', 'started', '0', ''],
  array['paused', 'started', 'paused', '20', ''], array['resumed', 'paused', 'started', '30', ''],
  array['paused', 'started', 'paused', '40', ''], array['resumed', 'paused', 'started', '50', ''],
  array['paused', 'started', 'paused', '60', ''], array['resumed', 'paused', 'started', '70', ''],
  array['completed', 'started', 'completed', '360', '']]);
-- a1: ended as not completed by the coordination role while started (counts in 3)
select pg_temp.visit('407', 'b3', '2025-04-13', 'p1', 'interrupted', array[
  array['started', 'on_the_way', 'started', '0', ''], array['interrupted', 'started', 'interrupted', '30', 'coord']]);
-- a2: ended as not completed by its own nurse while paused (does not count in 3)
select pg_temp.visit('408', 'b3', '2025-04-13', 'p2', 'interrupted', array[
  array['started', 'on_the_way', 'started', '0', ''], array['paused', 'started', 'paused', '10', ''],
  array['interrupted', 'paused', 'interrupted', '30', '']]);
-- T2 (two persons) with a coordinator end; T1 (one person)
select pg_temp.done('411', 'b2', '2025-04-10', 'q1'), pg_temp.done('412', 'b2', '2025-04-10', 'q2'),
       pg_temp.done('413', 'b1', '2025-04-10', 'q3');
select pg_temp.visit('414', 'b2', '2025-04-14', 'q1', 'interrupted', array[
  array['started', 'on_the_way', 'started', '0', ''], array['interrupted', 'started', 'interrupted', '30', 'coord']]);

-- Reports: first versions signed at 10:00 on the visit date; corrections (5, 6) -------------------------------------
create function pg_temp.report(p_id text, p_visit text, p_version int, p_supersedes text, p_status text, p_summary text,
                               p_created timestamptz, p_signed timestamptz, p_withdrawn timestamptz) returns void language sql as $$
  insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, supersedes_id, correction_reason,
                                    status, snapshot, summary, performer_id, countersign_required, created_by, created_at,
                                    signed_by, signed_at, withdrawn_by, withdrawn_at)
  select v.organization_id, pg_temp.id(p_id), v.id, v.case_id, v.team_id, p_version, pg_temp.id(p_supersedes),
         case when p_supersedes is not null then 'Synthetische Korrektur' end, p_status, '{"synthetic": true}'::jsonb, p_summary,
         '00000000-0000-4000-a000-000000000903', false, '00000000-0000-4000-a000-000000000903', p_created,
         case when p_signed is not null then '00000000-0000-4000-a000-000000000903'::uuid end, p_signed,
         case when p_withdrawn is not null then '00000000-0000-4000-a000-000000000903'::uuid end, p_withdrawn
  from public.care_visits v where v.id = pg_temp.id(p_visit) $$;
select pg_temp.report('e1', '401', 1, null, 'final', null, pg_temp.at('2025-04-10', '10:00'), pg_temp.at('2025-04-10', '10:00'), null),
       pg_temp.report('e2', '402', 1, null, 'final', null, pg_temp.at('2025-04-10', '10:00'), pg_temp.at('2025-04-10', '10:00'), null),
       pg_temp.report('e3', '403', 1, null, 'final', null, pg_temp.at('2025-04-10', '10:00'), pg_temp.at('2025-04-10', '10:00'), null),
       pg_temp.report('e4', '404', 1, null, 'final', null, pg_temp.at('2025-04-11', '10:00'), pg_temp.at('2025-04-11', '10:00'), null),
       pg_temp.report('e5', '405', 1, null, 'final', null, pg_temp.at('2025-04-11', '10:00'), pg_temp.at('2025-04-11', '10:00'), null);
-- c1: 30 min after the signature, signed 2 h later with the same snapshot and summary (unchanged; no open signal)
select pg_temp.report('c1', '401', 2, 'e1', 'final', null, pg_temp.at('2025-04-10', '10:30'), pg_temp.at('2025-04-10', '12:30'), null);
-- c3: 90 min after, a changed summary, final 30 h after it was opened (signal 24 h → 30 h: 6 h, ended by signature)
select pg_temp.report('c3', '403', 2, 'e3', 'final', 'Geänderte Zusammenfassung', pg_temp.at('2025-04-10', '11:30'),
                      pg_temp.at('2025-04-11', '17:30'), null);
-- c4: 10 min after, an untouched draft withdrawn 48 h after it was opened (signal 24 h, ended by withdrawal)
select pg_temp.report('c4', '404', 2, 'e4', 'withdrawn', null, pg_temp.at('2025-04-11', '10:10'), null, pg_temp.at('2025-04-13', '10:10'));
-- c5: 20 min after, a draft still open (signal open now)
select pg_temp.report('c5', '405', 2, 'e5', 'draft', null, pg_temp.at('2025-04-11', '10:20'), null, null);

-- Quality holds (11), set before any billing fact exists: lifted after 5 h and 9 h; one still open ------------------
insert into public.quality_holds (organization_id, visit_id, team_id, reason, set_by, set_at, lifted_by, lifted_at, lift_reason, idempotency_key)
select '00000000-0000-4000-b000-000000000012', pg_temp.id(x.v), pg_temp.id('b3'), 'Synthetische Sperre', '00000000-0000-4000-a000-000000000903',
       pg_temp.at('2025-04-15', '08:00'), case when x.h is not null then '00000000-0000-4000-a000-000000000903'::uuid end,
       pg_temp.at('2025-04-15', '08:00') + make_interval(hours => x.h), case when x.h is not null then 'Synthetisch geklärt' end,
       gen_random_uuid()
from (values ('402', 5), ('403', 9), ('404', null::int)) x(v, h);

-- Billing facts (7, 12) -----------------------------------------------------------------------------------------------
create function pg_temp.fact(p_id text, p_visit text, p_report text, p_billable boolean, p_reasons text[], p_cause text,
                             p_created timestamptz, p_supersedes text default null) returns void language sql as $$
  insert into public.billable_facts (organization_id, id, visit_id, case_id, team_id, report_id, supersedes_id, visit_date, billable,
                                     reasons, order_basis, payer_chain, tariff_versions, created_by, created_at, rule_version, cause)
  select v.organization_id, pg_temp.id(p_id), v.id, v.case_id, v.team_id, pg_temp.id(p_report), pg_temp.id(p_supersedes), v.visit_date,
         p_billable, p_reasons, 'with_order', '{}'::jsonb, '{}'::jsonb, '00000000-0000-4000-a000-000000000903', p_created, 'J5-v3', p_cause
  from public.care_visits v where v.id = pg_temp.id(p_visit) $$;
select pg_temp.fact('f1',  '401', 'e1', false, array['no_insurer'], 'report', pg_temp.at('2025-04-10', '10:00')),
       pg_temp.fact('f1b', '401', 'e1', true, '{}', 'basis_changed', pg_temp.at('2025-04-12', '10:00'), 'f1'),
       pg_temp.fact('f2',  '402', 'e2', false, array['below_minimum'], 'report', pg_temp.at('2025-04-10', '12:00')),
       pg_temp.fact('f3',  '403', 'e3', false, array['below_minimum', 'no_insurer'], 'report', pg_temp.at('2025-04-10', '12:00')),
       pg_temp.fact('f4',  '404', 'e4', true, '{}', 'report', pg_temp.at('2025-04-11', '12:00')),
       pg_temp.fact('f5',  '405', 'e5', true, '{}', 'report', pg_temp.at('2025-04-14', '12:00'));

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;

-- 3. Coordinator ends -----------------------------------------------------------------------------------------------
select is(pg_temp.hv('coordinator_ends', 'b3'), 1::numeric,
  '3: an end by a coordination role outside the team while started counts; the nurse''s own end while paused does not');
select is(pg_temp.hb('coordinator_ends', 'b3'), 2, '3: base = not-completed ends from started or paused');
select ok((pg_temp.h('coordinator_ends', 'b3') ->> 'too_few')::boolean, '3: a base below 5 says "zu wenig Daten"');
select is(pg_temp.hv('coordinator_ends'), 2::numeric, '3: the organisation row adds the hidden team''s end (2 of 3)');
select is(pg_temp.hb('coordinator_ends'), 3, '3: organisation base 3');

-- 5. Correction rounds ----------------------------------------------------------------------------------------------
select is(pg_temp.hv('correction_versions_per_100', 'b3'), 80.0::numeric,
  '5: four correction versions (a withdrawn one included) per five signed first versions = 80 per 100');
select is(pg_temp.hb('correction_versions_per_100', 'b3'), 5, '5: base = signed first versions');
select ok(not (pg_temp.h('correction_versions_per_100', 'b3') ->> 'too_few')::boolean, '5: a base of 5 is enough');
select is(pg_temp.hv('correction_minutes_after_signature', 'b3'), 25::numeric,
  '5: median minutes from the signature to the correction (10, 20, 30, 90) = 25');
select is(pg_temp.hv('correction_unchanged_share', 'b3'), 50.0::numeric,
  '5: of two signed corrections, one has the same snapshot hash and summary (signed again with no change)');
select is(pg_temp.hb('correction_unchanged_share', 'b3'), 2, '5: base = signed corrections only');

-- 6. Open corrections -----------------------------------------------------------------------------------------------
select is(pg_temp.hv('correction_open_signals', 'b3'), 3::numeric,
  '6: three corrections stayed open past the report_not_final threshold (one signed within 2 h never raised one)');
select is(pg_temp.hb('correction_open_signals', 'b3'), 4, '6: base = correction versions');
select is(pg_temp.hv('correction_open_hours', 'b3'), 15.0::numeric, '6: median hours open of the two that ended (6, 24) = 15');
select is(pg_temp.hb('correction_open_hours', 'b3'), 2, '6: the still-open one is not in the median');
select is(pg_temp.hv('correction_open_withdrawn_share', 'b3'), 50.0::numeric, '6: one ended by withdrawal (CGR-24-W)');
select is(pg_temp.hv('correction_open_signed_share', 'b3'), 50.0::numeric, '6: one ended by signature');
select ok((pg_temp.h('correction_open_signals', 'b3') ->> 'note') like '%D-28%', '6: the threshold is named as provisional (D-28)');

-- 7. Not-billable facts (AN2-M7) ------------------------------------------------------------------------------------
select is(pg_temp.hv('not_billable_facts', 'b3'), 2::numeric,
  '7 / AN2-M7: the total counts f1 and f3; f2, not billable only below the minimum, is not in it');
select is(pg_temp.hb('not_billable_facts', 'b3'), 6, '7: base = all facts of the month''s visits');
select is(pg_temp.hv('not_billable_reason', 'b3', 'below_minimum'), 2::numeric, '7: below_minimum has its own row (f2, f3)');
select ok((pg_temp.h('not_billable_reason', 'b3', 'below_minimum') ->> 'note')
            = 'Regel in rechtlicher Prüfung (D-18), nicht als Verlust werten. Nicht in der Summe der nicht abrechenbaren Fakten.',
  '7 / AN2-M7: with the fixed note');
select is(pg_temp.hv('not_billable_reason', 'b3', 'no_insurer'), 2::numeric, '7: per reason: no_insurer (f1, f3)');
select is(pg_temp.hb('not_billable_reason', 'b3', 'no_insurer'), 3, '7: per-reason base = not-billable facts');
select is(pg_temp.hv('not_billable_days_to_billable', 'b3'), 2.0::numeric, '7: f1 became billable 2 days later');
select is(pg_temp.hb('not_billable_days_to_billable', 'b3'), 1, '7: f3 never did; f2 (below minimum only) is left out');
select ok(pg_temp.h('not_billable_reason', 'b1', 'below_minimum') is not null,
  '7: the below_minimum row is present in every scope, also without such facts');

-- 9. Long or fragmented visits --------------------------------------------------------------------------------------
select is(pg_temp.hv('visits_many_pauses', 'b3'), 1::numeric, '9: one visit with more than two pauses (l1); a2 had one');
select is(pg_temp.hb('visits_many_pauses', 'b3'), 8, '9: base = started visits');
select is(pg_temp.hv('visits_open_past_p1', 'b3'), 1::numeric,
  '9: l1 was open past planned end + visit_stuck threshold + P1 escalation; the others ended in time');

-- 11. Quality holds -------------------------------------------------------------------------------------------------
select is(pg_temp.hv('hold_lift_hours', 'b3'), 7.0::numeric, '11: median hours from hold to lift (5, 9) = 7');
select is(pg_temp.hb('hold_lift_hours', 'b3'), 2, '11: base = lifted holds');
select is(pg_temp.hv('holds_still_open', 'b3'), 1::numeric, '11: one hold still open');

-- 12. Late billing facts --------------------------------------------------------------------------------------------
select is(pg_temp.hv('late_report_facts_share', 'b3'), 20.0::numeric,
  '12: one of five report facts was built more than 24 h after the visit''s end');
select is(pg_temp.hv('basis_changed_per_100', 'b3'), 16.7::numeric, '12: one basis_changed fact per six facts');

-- Suppression -------------------------------------------------------------------------------------------------------
select ok((select count(*) > 0 and bool_and(suppressed and value is null and base is null and note like 'Zu wenig Personen%')
           from public.pilot_hypotheses('2025-04-01') where team_id = pg_temp.id('b2')),
  'a two-person team shows "zu wenig Personen" on every AN2 row, with neither value nor base');
select ok((select bool_and(suppressed) from public.pilot_hypotheses('2025-04-01') where team_id = pg_temp.id('b1')),
  'and so does a one-person team');
select ok((select bool_and(not suppressed) from public.pilot_hypotheses('2025-04-01') where team_id is null),
  'the organisation row shows: the hidden teams'' persons number 3');
select ok((select count(*) > 0 and bool_and(suppressed and value is null and base is null)
           from public.pilot_hypotheses('2025-01-01') where team_id is null),
  'January (only a two-person team): the organisation rows are hidden too');
select is((select count(distinct measure)::int from public.pilot_hypotheses('2025-06-01') where team_id is null), 39,
  'every measure of parts 2 and 3 (and the two SIG1-6 measures, 0060, and the two ORD0-6 measures, 0061) appears, also in a month without events');
reset role;

-- Access ------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');   -- nurse of org A, Testteam Nord only
set local role authenticated;
select is((select count(*)::int from public.pilot_hypotheses('2025-04-01') where organization_id = '00000000-0000-4000-b000-000000000012'), 0,
  'a user of another organisation sees nothing of org B');
select is((select count(*)::int from public.pilot_hypotheses((now() at time zone 'Europe/Zurich')::date) where team_id is null), 0,
  'a nurse sees no organisation row');
select is((select count(*)::int from public.pilot_hypotheses((now() at time zone 'Europe/Zurich')::date)
           where team_id is distinct from '00000000-0000-4000-a000-000000000101'), 0,
  'and no row of a team she is not in');
select ok((select count(*) > 0 from public.pilot_hypotheses((now() at time zone 'Europe/Zurich')::date)
           where team_id = '00000000-0000-4000-a000-000000000101'), 'but her own team''s rows');
reset role;
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.pilot_hypotheses((now() at time zone 'Europe/Zurich')::date)
           where organization_id = '00000000-0000-4000-b000-000000000011'), 0,
  'a coordination role of org B sees nothing of org A');
reset role;
select ok(not has_function_privilege('anon', 'public.pilot_hypotheses(date)', 'execute'), 'anon cannot execute the read model');
select set_config('request.jwt.claims', '{"role": "anon"}', true);
set local role anon;
select throws_ok($$ select * from public.pilot_hypotheses('2025-04-01') $$, '42501', null, 'anon gets nothing');
reset role;

-- No person, no client, no free text --------------------------------------------------------------------------------
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'pilot_hypotheses'
             and exists (select 1 from unnest(p.proargnames) a
                         where a in ('performer_id', 'nurse_id', 'user_id', 'actor_id', 'client_name', 'case_id', 'visit_id', 'summary'))), 0,
  'the read model has no per-person, client or visit columns');
select ok((select bool_and(detail is null or detail ~ '^[a-z_]+$') from public.pilot_hypotheses('2025-04-01')),
  'details are fixed reason codes only');
select ok(not exists (select 1 from public.pilot_hypotheses('2025-04-01') where note ilike '%Synthetisch%' or note ilike '%Zusammenfassung%'),
  'no report text, hold reason or correction reason reaches a row');
select is((select provolatile::text from pg_proc where oid = 'public.pilot_hypotheses(date)'::regprocedure), 's',
  'the read model is read-only (stable)');

select * from finish();
rollback;
