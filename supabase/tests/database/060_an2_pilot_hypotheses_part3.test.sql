-- AN2 part 3 (migration 0058, ADR-071; brief docs/agents/briefs/AN2.md): measures 1, 2, 4, 8 (with AN2-M8a) and 10 of
-- "Pilot-Hypothesen". Org B (…012, admin …903 = coordination role, member of no team), case …251. One team "AN3 Drei"
-- with three performers (p1, p2, p3, synthetic accounts) in every month, so its rows are not suppressed.
-- Fixed past months, one measure family per month so fixtures do not cross: May 2025 = measures 1, 2, 4;
-- June 2025 = measure 10; July 2025 = measure 8. All data synthetic; fixtures are written as the table owner; the read
-- model is called as `authenticated`. Suppression, access and "no person" checks for every row are in pgTAP 059.
begin;
create extension if not exists pgtap with schema extensions;

select plan(48);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.id(n text) returns uuid language sql immutable as $$
  select ('a0600000-0000-4000-8000-' || left(md5(n), 12))::uuid $$;
create function pg_temp.at(d date, t time) returns timestamptz language sql immutable as $$
  select (d + t) at time zone 'Europe/Zurich' $$;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
select '00000000-0000-0000-0000-000000000000', pg_temp.id(p), 'authenticated', 'authenticated', p || '.an2p3@navora.test', '',
       now(), '{}', '{}', now(), now(), '', '', '', ''
from unnest(array['p1', 'p2', 'p3']) p;

insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('t3'), 'AN3 Drei', 'Test', 'active');

-- A visit 08:00-09:00 of case …251 in team t3. `events` lists (type, from, to, minutes after 08:00 on its date).
create function pg_temp.visit(p_id text, p_date date, p_resp text, p_status text, p_events text[][],
                              p_created timestamptz default null) returns void language plpgsql as $$
declare i int;
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                  responsible_user_id, created_at)
  values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), '00000000-0000-4000-a000-000000000251',
          pg_temp.id('t3'), p_date, '08:00', '09:00', false, p_status, pg_temp.id(p_resp), coalesce(p_created, now()));
  for i in 1 .. coalesce(array_length(p_events, 1), 0) loop
    insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
    values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), pg_temp.id('t3'), p_events[i][1], p_events[i][2],
            p_events[i][3], coalesce(pg_temp.id(p_resp), pg_temp.id('p2')),
            pg_temp.at(p_date, '08:00') + make_interval(mins => p_events[i][4]::int));
  end loop;
end $$;
-- Three completed visits (one per performer) make the team visible in a month.
create function pg_temp.people(p_date date) returns void language sql as $$
  select pg_temp.visit('done' || p || p_date, p_date, p, 'completed',
    array[array['started', 'on_the_way', 'started', '0'], array['completed', 'started', 'completed', '60']])
  from unnest(array['p1', 'p2', 'p3']) p $$;
-- A plan change of a fixture visit; the slot is 08:00-09:00 on p_date (before and after the same unless moved).
create function pg_temp.change(p_visit text, p_change text, p_at timestamptz, p_date date, p_before_resp text, p_after_resp text,
                               p_after_date date default null, p_absent boolean default false) returns void language sql as $$
  insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, before, after, reason, actor_id,
                                         changed_at, responsible_absent)
  values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_visit), '00000000-0000-4000-a000-000000000251', pg_temp.id('t3'),
          p_change,
          jsonb_build_object('date', p_date, 'start', '08:00:00', 'end', '09:00:00', 'responsible_id', pg_temp.id(p_before_resp)),
          jsonb_build_object('date', coalesce(p_after_date, p_date), 'start', '08:00:00', 'end', '09:00:00',
                             'responsible_id', pg_temp.id(p_after_resp)),
          case when p_change = 'moved' then 'Synthetisch verschoben' end, pg_temp.id('p2'), p_at, p_absent) $$;

create function pg_temp.h(p_month date, p_measure text, p_detail text default null) returns jsonb language sql as $$
  select to_jsonb(x) from public.pilot_hypotheses(p_month) x
  where x.measure = p_measure and x.team_id = pg_temp.id('t3') and x.detail is not distinct from p_detail $$;
create function pg_temp.hv(p_month date, p_measure text, p_detail text default null) returns numeric language sql as $$
  select (pg_temp.h(p_month, p_measure, p_detail) ->> 'value')::numeric $$;
create function pg_temp.hb(p_month date, p_measure text, p_detail text default null) returns int language sql as $$
  select (pg_temp.h(p_month, p_measure, p_detail) ->> 'base')::int $$;
create function pg_temp.ho(p_month date, p_measure text, p_detail text default null) returns numeric language sql as $$
  select (to_jsonb(x) ->> 'value')::numeric from public.pilot_hypotheses(p_month) x
  where x.measure = p_measure and x.team_id is null and x.detail is not distinct from p_detail $$;

-- =====================================================================================================================
-- May 2025: measures 1, 2, 4
-- =====================================================================================================================
select pg_temp.people('2025-05-02');
-- U1: p1 responsible; released 20 h before its start (absence), taken by p2 from "Offen im Team" 2 h later.
select pg_temp.visit('U1', '2025-05-20', 'p2', 'completed',
  array[array['started', 'on_the_way', 'started', '0'], array['completed', 'started', 'completed', '60']], pg_temp.at('2025-05-01', '08:00'));
select pg_temp.change('U1', 'released', pg_temp.at('2025-05-19', '12:00'), '2025-05-20', 'p1', null),
       pg_temp.change('U1', 'taken',    pg_temp.at('2025-05-19', '14:00'), '2025-05-20', null, 'p2');
-- U2: planned with nobody responsible; Operations took the exception over before p2 took the visit (after its start).
select pg_temp.visit('U2', '2025-05-21', 'p2', 'planned', null, pg_temp.at('2025-05-01', '08:00'));
select pg_temp.change('U2', 'taken', pg_temp.at('2025-05-21', '10:00'), '2025-05-21', null, 'p2');
insert into public.exception_events (organization_id, exception_key, kind, actor_id, created_at)
values ('00000000-0000-4000-b000-000000000012', 'visit_uncovered:' || pg_temp.id('U2'), 'take',
        '00000000-0000-4000-a000-000000000903', pg_temp.at('2025-05-21', '09:00'));
-- U3: released and taken again days before its window opened: no exception.
select pg_temp.visit('U3', '2025-05-22', 'p2', 'completed',
  array[array['started', 'on_the_way', 'started', '0'], array['completed', 'started', 'completed', '60']], pg_temp.at('2025-05-01', '08:00'));
select pg_temp.change('U3', 'released', pg_temp.at('2025-05-10', '12:00'), '2025-05-22', 'p1', null),
       pg_temp.change('U3', 'taken',    pg_temp.at('2025-05-15', '12:00'), '2025-05-22', null, 'p2');
-- M1: moved 12 h before its start (late); M2: moved five days before (not late).
select pg_temp.visit('M1', '2025-05-07', 'p1', 'planned', null), pg_temp.visit('M2', '2025-05-07', 'p1', 'planned', null);
select pg_temp.change('M1', 'moved', pg_temp.at('2025-05-05', '20:00'), '2025-05-06', 'p1', 'p1', '2025-05-07'),
       pg_temp.change('M2', 'moved', pg_temp.at('2025-05-01', '08:00'), '2025-05-06', 'p1', 'p1', '2025-05-07');
-- F1, F2: ended as not completed at 08:30; "Folgeeinsatz geplant" after 30 and 120 minutes. A visit of the case is
-- planned 6 h after F1's decision; none within 48 h after F2's.
select pg_temp.visit('F1', '2025-05-08', 'p1', 'interrupted',
         array[array['started', 'on_the_way', 'started', '0'], array['interrupted', 'started', 'interrupted', '30']]),
       pg_temp.visit('F2', '2025-05-09', 'p1', 'interrupted',
         array[array['started', 'on_the_way', 'started', '0'], array['interrupted', 'started', 'interrupted', '30']]);
insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, actor_id, idempotency_key, created_at)
values ('00000000-0000-4000-b000-000000000012', pg_temp.id('F1'), 'interruption_followup', 'follow_up_planned', pg_temp.id('p1'),
        gen_random_uuid(), pg_temp.at('2025-05-08', '09:00')),
       ('00000000-0000-4000-b000-000000000012', pg_temp.id('F2'), 'interruption_followup', 'follow_up_planned', pg_temp.id('p1'),
        gen_random_uuid(), pg_temp.at('2025-05-09', '10:30'));
insert into public.visit_plan_changes (organization_id, visit_id, case_id, team_id, change, after, actor_id, changed_at)
values ('00000000-0000-4000-b000-000000000012', pg_temp.id('F1next'), '00000000-0000-4000-a000-000000000251', pg_temp.id('t3'),
        'planned', jsonb_build_object('date', '2025-05-10', 'start', '08:00:00', 'end', '09:00:00'), pg_temp.id('p1'),
        pg_temp.at('2025-05-08', '15:00'));

-- =====================================================================================================================
-- June 2025: measure 10
-- =====================================================================================================================
select pg_temp.people('2025-06-02');
-- O1: started 30 min late (ended by a command); O2: never started, closed by hand at 08:45; O3: never started, still open.
select pg_temp.visit('O1', '2025-06-10', 'p1', 'completed',
         array[array['started', 'on_the_way', 'started', '30'], array['completed', 'started', 'completed', '90']]),
       pg_temp.visit('O2', '2025-06-11', 'p1', 'planned', null),
       pg_temp.visit('O3', '2025-06-12', 'p1', 'planned', null);
-- S1: started on time, completed at 11:00 (stuck from 10:00, ended by a command); S2: still started, closed by hand at 10:30.
select pg_temp.visit('S1', '2025-06-13', 'p1', 'completed',
         array[array['started', 'on_the_way', 'started', '0'], array['completed', 'started', 'completed', '180']]),
       pg_temp.visit('S2', '2025-06-14', 'p1', 'started', array[array['started', 'on_the_way', 'started', '0']]);
insert into public.exception_events (organization_id, exception_key, kind, text, actor_id, created_at)
values ('00000000-0000-4000-b000-000000000012', 'visit_overdue:' || pg_temp.id('O2'), 'close', 'Synthetisch geschlossen',
        '00000000-0000-4000-a000-000000000903', pg_temp.at('2025-06-11', '08:45')),
       ('00000000-0000-4000-b000-000000000012',
        'visit_stuck:' || pg_temp.id('S2') || ':' || (select e.id from public.visit_events e where e.visit_id = pg_temp.id('S2')),
        'close', 'Synthetisch geschlossen', '00000000-0000-4000-a000-000000000903', pg_temp.at('2025-06-14', '10:30'));

-- =====================================================================================================================
-- July 2025: measure 8 (absences of p1 in team t3)
-- =====================================================================================================================
select pg_temp.people('2025-07-01');
create function pg_temp.absence(p_id text, p_from timestamptz, p_until timestamptz, p_by text, p_created timestamptz,
                                p_withdrawn timestamptz default null) returns void language sql as $$
  insert into public.member_absences (id, organization_id, team_id, user_id, starts_at, ends_at, recorded_by, created_at,
                                      withdrawn_at, withdrawn_by)
  values (pg_temp.id(p_id), '00000000-0000-4000-b000-000000000012', pg_temp.id('t3'), pg_temp.id('p1'), p_from, p_until,
          pg_temp.id(p_by), p_created, p_withdrawn, case when p_withdrawn is not null then pg_temp.id('p1') end) $$;
-- A1: recorded by colleague p2 on 11 July with a start of yesterday; withdrawn by p1 herself 3 h later.
select pg_temp.absence('A1', pg_temp.at('2025-07-10', '00:00'), pg_temp.at('2025-07-12', '00:00'), 'p2',
                       pg_temp.at('2025-07-11', '09:00'), pg_temp.at('2025-07-11', '12:00'));
-- A2: recorded by herself on its first day, never changed.
select pg_temp.absence('A2', pg_temp.at('2025-07-20', '00:00'), pg_temp.at('2025-07-25', '00:00'), 'p1', pg_temp.at('2025-07-20', '07:00'));
-- A3: recorded on 6 July with a start three days earlier (command path); A6, recorded 24 h later, continues it.
select pg_temp.absence('A3', pg_temp.at('2025-07-03', '00:00'), pg_temp.at('2025-07-08', '00:00'), 'p1', pg_temp.at('2025-07-06', '10:00'));
select pg_temp.absence('A6', pg_temp.at('2025-07-08', '00:00'), pg_temp.at('2025-07-10', '00:00'), 'p1', pg_temp.at('2025-07-07', '10:00'));
-- A4: recorded the evening before, shortened 16 h later (the audit row of change_absence).
select pg_temp.absence('A4', pg_temp.at('2025-07-28', '08:00'), pg_temp.at('2025-07-29', '00:00'), 'p1', pg_temp.at('2025-07-27', '18:00'));
insert into public.audit_events (occurred_at, organization_id, actor_id, actor_role, table_name, entity_id, command, changed)
values (pg_temp.at('2025-07-28', '10:00'), '00000000-0000-4000-b000-000000000012', pg_temp.id('p1'), 'authenticated',
        'member_absences', pg_temp.id('A4'), 'change_absence',
        jsonb_build_object('ends_at', jsonb_build_object('old', pg_temp.at('2025-07-30', '00:00'), 'new', pg_temp.at('2025-07-29', '00:00'))));
-- Past planned visits naming p1 inside an absence when it was recorded (CGR-32), and how they ended:
-- P1 (A1): started late by p2 the next morning.
select pg_temp.visit('P1', '2025-07-10', 'p1', 'completed', null);
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
values ('00000000-0000-4000-b000-000000000012', pg_temp.id('P1'), pg_temp.id('t3'), 'started', 'planned', 'started', pg_temp.id('p2'),
        pg_temp.at('2025-07-11', '10:00')),
       ('00000000-0000-4000-b000-000000000012', pg_temp.id('P1'), pg_temp.id('t3'), 'completed', 'started', 'completed', pg_temp.id('p2'),
        pg_temp.at('2025-07-11', '11:00'));
-- P2 (A3): cancelled with the stored CGR-34 mark.
select pg_temp.visit('P2', '2025-07-04', 'p1', 'cancelled', null);
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
values ('00000000-0000-4000-b000-000000000012', pg_temp.id('P2'), pg_temp.id('t3'), 'cancelled', 'planned', 'cancelled', pg_temp.id('p2'),
        pg_temp.at('2025-07-06', '11:00'));
insert into public.visit_status_notes (organization_id, visit_id, kind, reason_code, actor_id, idempotency_key, created_at, responsible_absent)
values ('00000000-0000-4000-b000-000000000012', pg_temp.id('P2'), 'cancelled', 'team_cancelled', pg_temp.id('p2'), gen_random_uuid(),
        pg_temp.at('2025-07-06', '11:00'), true);
-- P3 (A3): moved forward with the stored CGR-35 mark (planned on 5 July then, on 9 July now).
select pg_temp.visit('P3', '2025-07-09', 'p1', 'planned', null);
select pg_temp.change('P3', 'moved', pg_temp.at('2025-07-06', '12:00'), '2025-07-05', 'p1', 'p1', '2025-07-09', true);
-- P4 (A3): moved forward before the mark was captured (AN2-M8a): "vor Erfassung (nicht gezählt)".
select pg_temp.visit('P4', '2025-07-09', 'p1', 'planned', null);
select pg_temp.change('P4', 'moved', pg_temp.at('2025-07-06', '13:00'), '2025-07-04', 'p1', 'p1', '2025-07-09', false);
-- P5 (A3): still planned, nothing happened.
select pg_temp.visit('P5', '2025-07-05', 'p1', 'planned', null);

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;

-- 1. Uncovered visits taken by the team -----------------------------------------------------------------------------
select is(pg_temp.hv('2025-05-01', 'uncovered_taken_by_team_share'), 50.0::numeric,
  '1: U1 (taken by the team inside the window) counts; U2 (Operations took the exception over first) does not');
select is(pg_temp.hb('2025-05-01', 'uncovered_taken_by_team_share'), 2,
  '1: base = uncovered exceptions; U3 (released and taken before the window opened) never had one');
select ok((pg_temp.h('2025-05-01', 'uncovered_taken_by_team_share') ->> 'too_few')::boolean, '1: a base below 5 says "zu wenig Daten"');
select is(pg_temp.hv('2025-05-01', 'uncovered_hours_to_take'), 2.0::numeric, '1: median hours from the exception to the take (U1: 2 h)');
select is(pg_temp.hb('2025-05-01', 'uncovered_hours_to_take'), 1, '1: only takes by the team are in the median');
select ok((pg_temp.h('2025-05-01', 'uncovered_taken_by_team_share') ->> 'note') like '%D-28%', '1: the threshold is named as provisional (D-28)');
select is(pg_temp.ho('2025-05-01', 'uncovered_taken_by_team_share'), 50.0::numeric, '1: the organisation row (only this team) agrees');

-- 2. Follow-up after an interrupted visit -----------------------------------------------------------------------------
select is(pg_temp.hv('2025-05-01', 'followup_without_visit_share'), 50.0::numeric,
  '2: F2 has no visit of the case planned within 48 h after "Folgeeinsatz geplant"; F1 has one');
select is(pg_temp.hb('2025-05-01', 'followup_without_visit_share'), 2, '2: base = follow_up_planned decisions');
select ok((pg_temp.h('2025-05-01', 'followup_without_visit_share') ->> 'note') like '%D-31%',
  '2: the row says the decision is a statement, not a check (D-31)');
select is(pg_temp.hv('2025-05-01', 'followup_decision_minutes'), 75::numeric,
  '2: median minutes from the not-completed end to the decision (30, 120) = 75');
select is(pg_temp.hb('2025-05-01', 'followup_decision_minutes'), 2, '2: base = decisions');

-- 4. Single visits given away by hand ---------------------------------------------------------------------------------
select is(pg_temp.hb('2025-05-01', 'late_moves_per_100'), 10, '4: base = the ten visits of May');
select is(pg_temp.hv('2025-05-01', 'late_moves_per_100'), 10.0::numeric,
  '4: one move less than 24 h before the planned start (M1) per ten visits; M2, five days before, does not count');
select is(pg_temp.hv('2025-05-01', 'late_responsible_changes_per_100'), 20.0::numeric,
  '4: U1''s release and take (20 h and 18 h before) count; U2''s take after the start and U3''s days before do not');

-- 10. How exceptions end ----------------------------------------------------------------------------------------------
select is(pg_temp.hb('2025-06-01', 'overdue_ended_by_command_share'), 3,
  '10: three overdue visits (O1, O2, O3); the on-time starts raised none');
select is(pg_temp.hv('2025-06-01', 'overdue_ended_by_command_share'), 33.3::numeric, '10: O1 ended by its start (a visit command)');
select is(pg_temp.hv('2025-06-01', 'overdue_closed_by_hand_share'), 33.3::numeric, '10: O2 closed by hand in OPS1; O3 is still open');
select is(pg_temp.hb('2025-06-01', 'stuck_ended_by_command_share'), 2,
  '10: two stuck visits (S1, S2); O1 and the completed visits ended before the visit_stuck threshold');
select is(pg_temp.hv('2025-06-01', 'stuck_ended_by_command_share'), 50.0::numeric, '10: S1 ended by its completion');
select is(pg_temp.hv('2025-06-01', 'stuck_closed_by_hand_share'), 50.0::numeric, '10: S2 closed by hand on its event key');
select ok((pg_temp.h('2025-06-01', 'stuck_closed_by_hand_share') ->> 'note') like '%D-28%', '10: the threshold is named as provisional (D-28)');

-- 8. Absences ---------------------------------------------------------------------------------------------------------
select is(pg_temp.hb('2025-07-01', 'absences_per_100'), 8, '8: base = the eight visits of July');
select is(pg_temp.hv('2025-07-01', 'absences_per_100'), 62.5::numeric, '8: five absences starting in July per eight visits');
select is(pg_temp.hv('2025-07-01', 'absences_by_colleague_share'), 20.0::numeric, '8: one of five recorded by a colleague (A1)');
select is(pg_temp.hb('2025-07-01', 'absences_by_colleague_share'), 5, '8: base = absences');
select is(pg_temp.hv('2025-07-01', 'absences_withdrawn_by_member_share'), 100.0::numeric,
  '8: of those recorded by a colleague, A1 was withdrawn by the member herself');
select is(pg_temp.hb('2025-07-01', 'absences_withdrawn_by_member_share'), 1, '8: base = absences recorded by a colleague');
select is(pg_temp.hv('2025-07-01', 'absences_revised_share'), 60.0::numeric,
  '8: revised within 48 h: A1 withdrawn, A4 shortened, A3 followed by an adjacent new absence (A6); A2 and A6 not');
select is(pg_temp.hv('2025-07-01', 'absences_start_yesterday_share'), 20.0::numeric, '8: one absence with a start of yesterday (A1)');
select is(pg_temp.hv('2025-07-01', 'absences_start_before_yesterday'), 1::numeric,
  '8: one absence starting earlier than yesterday (A3, command path)');
select is(pg_temp.hv('2025-07-01', 'absence_past_visits_per_100'), 100.0::numeric,
  '8: five flagged past visits (P1-P5) per five absences');
select is(pg_temp.hb('2025-07-01', 'absence_past_visit_end', 'moved'), 5, '8: base of the endings = flagged past visits');
select is(pg_temp.hv('2025-07-01', 'absence_past_visit_end', 'started_late'), 1::numeric, '8: P1 started late');
select is(pg_temp.hv('2025-07-01', 'absence_past_visit_end', 'cancelled'), 1::numeric, '8: P2 cancelled with the CGR-34 mark');
select is(pg_temp.hv('2025-07-01', 'absence_past_visit_end', 'still_open'), 1::numeric, '8: P5 still open');
select is(pg_temp.hv('2025-07-01', 'absence_past_visit_end', 'cancelled_without_mark'), 0::numeric, '8: no cancellation without the mark');

-- AN2-M8a ---------------------------------------------------------------------------------------------------------------
select is(pg_temp.hv('2025-07-01', 'absence_past_visit_end', 'moved'), 1::numeric,
  'AN2-M8a: a move counts only from the stored responsible_absent (P3), not P4');
select is(pg_temp.hv('2025-07-01', 'absence_past_visit_end', 'moved_before_capture'), 1::numeric,
  'AN2-M8a: P4, moved before the mark was captured, is in its own row');
select ok((pg_temp.h('2025-07-01', 'absence_past_visit_end', 'moved_before_capture') ->> 'note') like 'vor Erfassung (nicht gezählt)%',
  'AN2-M8a: and that row says "vor Erfassung (nicht gezählt)"');
select is(pg_temp.hv('2025-07-01', 'absence_past_visit_end', 'other'), 0::numeric,
  'AN2-M8a: no move is shown as an ending other than "moved" or "vor Erfassung" (never "nicht abwesend")');
select is((select count(*)::int from public.pilot_hypotheses('2025-07-01')
           where team_id = pg_temp.id('t3') and measure = 'absence_past_visit_end'), 7,
  '8: every ending has its row (fixed codes), also with value 0');
-- AN2-M9a (PO 2026-10-24 07:10): measure 9 names the threshold it used (org B: visit_stuck 1 h, P1 after 3 h).
select is(pg_temp.h('2025-06-01', 'visits_open_past_p1') ->> 'note',
  'Schwelle heute: geplantes Ende + 1 Std. + 3 Std. bis P1. Wie heute eingestellt (provisorisch, D-28).',
  'AN2-M9a: the measure-9 row names the threshold value used today');
select is(pg_temp.ho('2025-07-01', 'absences_by_colleague_share'), 20.0::numeric,
  '8: the organisation row counts each absence once (one group per absence)');
reset role;

-- Every new measure appears in every scope, also in a month without events --------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(distinct measure)::int from public.pilot_hypotheses('2025-09-01') where team_id is null
           and measure in ('uncovered_taken_by_team_share', 'uncovered_hours_to_take', 'followup_without_visit_share',
                           'followup_decision_minutes', 'late_moves_per_100', 'late_responsible_changes_per_100',
                           'absences_per_100', 'absences_by_colleague_share', 'absences_withdrawn_by_member_share',
                           'absences_revised_share', 'absences_start_yesterday_share', 'absences_start_before_yesterday',
                           'absence_past_visits_per_100', 'absence_past_visit_end', 'overdue_ended_by_command_share',
                           'overdue_closed_by_hand_share', 'stuck_ended_by_command_share', 'stuck_closed_by_hand_share')), 18,
  'the eighteen measures of part 3 appear in a month without events');
select ok((select bool_and(detail is null or detail ~ '^[a-z_]+$') from public.pilot_hypotheses('2025-07-01')),
  'details are fixed codes only (no person, date or reason text)');
reset role;

-- A nurse sees no AN2 row of a team she is not in -------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.pilot_hypotheses('2025-07-01') where team_id = pg_temp.id('t3')), 0,
  'a nurse of another organisation sees no row of this team');
reset role;

select is((select count(*)::int from private.an2_capture_starts where capture = 'visit_plan_changes.responsible_absent'), 1,
  'AN2-M8a: the capture start is recorded once');

select * from finish();
rollback;
