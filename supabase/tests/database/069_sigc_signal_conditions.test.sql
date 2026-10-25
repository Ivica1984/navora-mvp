-- SIGC: SIG1-C2 (CGR-47), SIG1-C3 (CGR-46), SIG2-C1 (1) and (2) (CGR-48). Migration 0068, ADR-082.
-- Briefs `docs/agents/briefs/SIGC.md`, `SIG1.md` and `SIG2.md` (PO conditions 2026-10-24 23:10).
-- Org A (…011): registered nurse …902 and care assistant …906 (Testteam Nord …101), Operations …904, admin …905;
-- synthetic accounts: cover_rn (registered nurse, Testteam Mitte …102), cover_ca (care assistant, Mitte), dual (care
-- assistant in Nord, registered nurse in Mitte). Org B (…012): admin …903; team "SIGC Drei" with three performers for the
-- AN2 rows (fixed past months, so fixtures do not cross). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(80);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.id(n text) returns uuid language sql immutable as $$
  select ('a6900000-0000-4000-8000-' || left(md5(n), 12))::uuid $$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a6900000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.u(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-a000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.at(d date, t time) returns timestamptz language sql stable as $$ select private.at_zurich(d + t) $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.at_zurich(private.now()))::date $$;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
                        created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
select '00000000-0000-0000-0000-000000000000', pg_temp.id(p), 'authenticated', 'authenticated', p || '.sigc@navora.test', '',
       private.now(), '{}', '{}', private.now(), private.now(), '', '', '', ''
from unnest(array['p1', 'p2', 'p3', 'cover_rn', 'cover_ca', 'dual']) p;
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.id('cover_rn'), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.id('cover_ca'), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.id('dual'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', pg_temp.id('cover_rn'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.id('cover_ca'), 'care_assistant'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.id('dual'), 'care_assistant'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.id('dual'), 'registered_nurse');

-- =====================================================================================================================
-- SIG1-C2 (CGR-47): AN2 counts the take that stops the step (org B, team "SIGC Drei", fixed past months)
-- =====================================================================================================================
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000012', pg_temp.id('t3'), 'SIGC Drei', 'Test', 'active');

-- A visit 08:00-09:00 of case …251 in team t3 (cancelled: the signal fixtures need a visit, not a performer).
create function pg_temp.visit(p_id text, p_date date, p_resp text, p_status text) returns void language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                  responsible_user_id)
  values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), '00000000-0000-4000-a000-000000000251',
          pg_temp.id('t3'), p_date, '08:00', '09:00', false, p_status, pg_temp.id(p_resp));
  if p_status = 'completed' then
    insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
    values ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), pg_temp.id('t3'), 'started', 'on_the_way', 'started',
            pg_temp.id(p_resp), pg_temp.at(p_date, '08:00')),
           ('00000000-0000-4000-b000-000000000012', pg_temp.id(p_id), pg_temp.id('t3'), 'completed', 'started', 'completed',
            pg_temp.id(p_resp), pg_temp.at(p_date, '09:00'));
  end if;
end $$;
-- Three completed visits (one per performer) make the team visible in a month (AN1).
create function pg_temp.people(p_date date) returns void language sql as $$
  select pg_temp.visit('done' || p || p_date, p_date, p, 'completed') from unnest(array['p1', 'p2', 'p3']) p $$;
-- An ended P1 signal of kind p_kind at 08:10 on p_date; takes: array of (person, qualification, stops, minutes after P1).
create function pg_temp.signal(p_name text, p_date date, p_kind text, p_takes text[][]) returns uuid language plpgsql as $$
declare
  sid uuid := pg_temp.id('sig' || p_name);
  p1  timestamptz := pg_temp.at(p_date, '08:10');
  i   int;
begin
  perform pg_temp.visit('v' || p_name, p_date, 'p1', 'cancelled');
  insert into public.safety_signals (organization_id, id, team_id, visit_id, signal_kind, exception_key, p1_at, created_at, ended_at,
                                     taken_by, taken_at)
  values ('00000000-0000-4000-b000-000000000012', sid, pg_temp.id('t3'), pg_temp.id('v' || p_name), p_kind, 'sigc:' || p_name,
          p1, p1, p1 + interval '3 hours',
          case when coalesce(array_length(p_takes, 1), 0) > 0 then pg_temp.id(p_takes[1][1]) end,
          case when coalesce(array_length(p_takes, 1), 0) > 0 then p1 + make_interval(mins => p_takes[1][4]::int) end);
  for i in 1 .. coalesce(array_length(p_takes, 1), 0) loop
    insert into public.signal_takes (organization_id, signal_id, taker_id, qualification, stops_escalation, taken_at)
    values ('00000000-0000-4000-b000-000000000012', sid, pg_temp.id(p_takes[i][1]), p_takes[i][2], p_takes[i][3]::boolean,
            p1 + make_interval(mins => p_takes[i][4]::int));
  end loop;
  return sid;
end $$;
create function pg_temp.h(p_month date, p_measure text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000903');
  set local role authenticated;
  select to_jsonb(x) into r from public.pilot_hypotheses(p_month) x where x.measure = p_measure and x.team_id = pg_temp.id('t3');
  reset role;
  return r;
end $$;
create function pg_temp.hv(p_month date, p_measure text) returns numeric language sql as $$
  select (pg_temp.h(p_month, p_measure) ->> 'value')::numeric $$;

-- August 2025: a care assistant takes a no-show at +2 min, a registered nurse at +20 min.
select pg_temp.people('2025-08-04');
select pg_temp.signal('aug', '2025-08-11', 'no_show',
  array[array['p1', 'care_assistant', 'false', '2'], array['p2', 'registered_nurse', 'true', '20']]);
-- September 2025: only a care assistant's take of a no-show.
select pg_temp.people('2025-09-01');
select pg_temp.signal('sep', '2025-09-08', 'no_show', array[array['p1', 'care_assistant', 'false', '3']]);
-- October 2025: a care assistant takes an overdue visit at +5 min (every take stops the step: as built).
select pg_temp.people('2025-10-06');
select pg_temp.signal('oct', '2025-10-13', 'visit_overdue', array[array['p1', 'care_assistant', 'true', '5']]);
-- November 2025: a broken-off visit, a care assistant's take only.
select pg_temp.people('2025-11-03');
select pg_temp.signal('nov', '2025-11-10', 'visit_interrupted', array[array['p1', 'care_assistant', 'false', '4']]);
-- December 2025: a no-show taken by a registered nurse, but only two performers in the team (AN1 suppression).
select pg_temp.visit('done-dec-p1', '2025-12-01', 'p1', 'completed');
select pg_temp.visit('done-dec-p2', '2025-12-01', 'p2', 'completed');
select pg_temp.signal('dec', '2025-12-08', 'no_show', array[array['p2', 'registered_nurse', 'true', '6']]);

select is(private.signal_qualified_taken_at(pg_temp.id('sigaug')), pg_temp.at('2025-08-11', '08:30'),
  'SIG1-C2: for a no-show the counted take is the first one that stops the step (+20 min), not the first (+2 min)');
select is(pg_temp.hv('2025-08-01', 'signal_minutes_to_take'), 20.0::numeric,
  'SIG1-C2: care assistant at +2 min, registered nurse at +20 min → the median time to take counts +20 min');
select is(pg_temp.hv('2025-08-01', 'first_take_any_minutes'), 2.0::numeric,
  'SIG1-C2: the first take of any member stays available as its own value (+2 min)');
select is(pg_temp.hv('2025-08-01', 'signal_taken_share'), 100.0::numeric, 'SIG1-C2: the no-show counts as taken (by the registered nurse)');
select is(pg_temp.hv('2025-08-01', 'signal_taken_within_threshold_share'), 0.0::numeric,
  'SIG1-C2: taken within the 15-minute untaken threshold is read from the qualified take (+20 min → not in time)');
select is(pg_temp.hv('2025-09-01', 'signal_taken_share'), 0.0::numeric,
  'SIG1-C2: only a care assistant''s take of a no-show → counted as not taken');
select is((pg_temp.h('2025-09-01', 'signal_taken_share') ->> 'base')::int, 1, 'the base still counts the signal');
select is((pg_temp.h('2025-09-01', 'signal_minutes_to_take') ->> 'base')::int, 0, 'no qualified take → no time to take');
select is(pg_temp.hv('2025-09-01', 'first_take_any_minutes'), 3.0::numeric, 'the care assistant''s first take is still its own value');
select is(pg_temp.hv('2025-09-01', 'signal_taken_within_threshold_share'), 0.0::numeric,
  'only a care assistant''s take → not taken within the threshold');
select is(pg_temp.hv('2025-10-01', 'signal_minutes_to_take'), 5.0::numeric, 'other kinds unchanged: an overdue visit counts its first take');
select is(pg_temp.hv('2025-10-01', 'signal_taken_within_threshold_share'), 100.0::numeric, 'other kinds unchanged: within the threshold');
select is(pg_temp.hv('2025-11-01', 'signal_taken_share'), 0.0::numeric,
  'SIG1-C2: a broken-off visit taken only by a care assistant → counted as not taken');
select ok((select bool_and((pg_temp.h('2025-12-01', m) ->> 'suppressed')::boolean and pg_temp.h('2025-12-01', m) ->> 'value' is null)
           from unnest(array['signal_taken_share', 'signal_minutes_to_take', 'first_take_any_minutes', 'signal_taken_within_threshold_share']) m),
  'AN1 suppression applies to the counted measures and to first_take_any_minutes (two performers)');
select ok(pg_temp.h('2025-08-01', 'first_take_any_minutes') ->> 'note' like '%Nicht die qualifizierte Antwort%',
  'first_take_any_minutes is labelled so it is never read as the qualified response');
select ok((select bool_and(pg_temp.h('2025-08-01', m) ->> 'note' like '%die Meldung an Operations stoppt (SIG1-C2)%')
           from unnest(array['signal_taken_share', 'signal_minutes_to_take', 'signal_taken_within_threshold_share']) m),
  'the three response measures say which take they count');
select ok(not exists (select 1 from jsonb_object_keys(pg_temp.h('2025-08-01', 'first_take_any_minutes')) k
                      where k in ('user_id', 'taker_id', 'member_name')),
  'the new measure has no per-person column (team and organisation only)');

-- =====================================================================================================================
-- SIG1-C3 (CGR-46): the untested take paths (org A, real commands)
-- =====================================================================================================================
-- A P1 no-show of case …208 (Testteam Nord) tomorrow 09:00, recorded by the registered nurse of Nord. Covered visits
-- have no responsible member of Nord; the covering member and her cover team are named on the visit.
create function pg_temp.no_show(p_n text, p_cover text) returns void language plpgsql as $$
begin
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, billable, status,
                                  responsible_user_id, covered_by, covered_at, cover_team_id)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.id(p_n), '00000000-0000-4000-a000-000000000208',
          '00000000-0000-4000-a000-000000000101', pg_temp.today() + 1, '09:00', false, 'planned',
          case when p_cover is null then '00000000-0000-4000-a000-000000000902'::uuid end,
          case when p_cover is not null then pg_temp.id(p_cover) end,
          case when p_cover is not null then private.now() end,
          case when p_cover is not null then '00000000-0000-4000-a000-000000000102'::uuid end);
  perform pg_temp.act_as('00000000-0000-4000-a000-000000000902');
  set local role authenticated;
  perform public.depart_visit(pg_temp.id(p_n), pg_temp.id('depart' || p_n));
  perform public.record_no_show(pg_temp.id(p_n), 'Synthetisch: niemand öffnet', pg_temp.id('noshow' || p_n), true);
  reset role;
end $$;
create function pg_temp.sig(p_n text) returns uuid language sql as $$
  select id from public.safety_signals where visit_id = pg_temp.id(p_n) and signal_kind = 'no_show' and ended_at is null
$$;
create function pg_temp.take(p_user uuid, p_n text, p_key integer) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(p_user::text);
  set local role authenticated;
  r := public.take_signal(pg_temp.sig(p_n), pg_temp.k(p_key));
  reset role;
  return r;
end $$;
create function pg_temp.stops(p_user uuid, p_n text) returns boolean language sql as $$
  select stops_escalation from public.signal_takes where signal_id = pg_temp.sig(p_n) and taker_id = p_user
$$;
create function pg_temp.escalated(p_n text) returns boolean language sql as $$
  select escalated_at is not null from public.safety_signals where id = pg_temp.sig(p_n)
$$;
create function pg_temp.ops(p_n text) returns integer language sql as $$
  select count(*)::int from public.signal_deliveries where signal_id = pg_temp.sig(p_n) and reason = 'untaken'
$$;
create function pg_temp.eval() returns integer language sql as $$
  select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true)
$$;

select pg_temp.no_show('c3a', 'cover_rn');
select pg_temp.no_show('c3b', 'cover_ca');
select pg_temp.no_show('c3c', null);
select pg_temp.no_show('c3d', null);
select pg_temp.eval();
select ok(pg_temp.sig('c3a') is not null and pg_temp.sig('c3b') is not null and pg_temp.sig('c3c') is not null and pg_temp.sig('c3d') is not null,
  'fixture: four P1 no-show signals (two covered visits, two of Nord)');
select ok(exists (select 1 from public.signal_deliveries where signal_id = pg_temp.sig('c3a') and recipient_id = pg_temp.id('cover_rn'))
          and exists (select 1 from public.signal_deliveries where signal_id = pg_temp.sig('c3b') and recipient_id = pg_temp.id('cover_ca')),
  'fixture: the covering member receives the covered visit''s signal');

select is(pg_temp.take(pg_temp.id('cover_rn'), 'c3a', 1) ->> 'operations_follows', 'false',
  'SIG1-C3 (a): the covering member, a registered nurse in her cover team, takes → the step stops');
select is(pg_temp.stops(pg_temp.id('cover_rn'), 'c3a'), true, 'SIG1-C3 (a): stops_escalation true');
select is((select qualification from public.signal_takes where signal_id = pg_temp.sig('c3a') and taker_id = pg_temp.id('cover_rn')),
  'registered_nurse', 'SIG1-C3 (a): her qualification is read in the cover team');
select is(pg_temp.take(pg_temp.id('cover_ca'), 'c3b', 2) ->> 'operations_follows', 'true',
  'SIG1-C3 (b): a covering care assistant takes → Operations still follows');
select is(pg_temp.stops(pg_temp.id('cover_ca'), 'c3b'), false, 'SIG1-C3 (b): stops_escalation false');
select is(pg_temp.take(pg_temp.u(906), 'c3c', 3) ->> 'result', 'ok', 'fixture: the care assistant of Nord takes no-show c3c');
select is(pg_temp.take(pg_temp.id('dual'), 'c3d', 4) ->> 'operations_follows', 'true',
  'SIG1-C3 (d): a care assistant of the owning team who is a registered nurse only in another team takes → Operations follows');
select is(pg_temp.stops(pg_temp.id('dual'), 'c3d'), false, 'SIG1-C3 (d): stops_escalation false');
select is((select qualification from public.signal_takes where signal_id = pg_temp.sig('c3d') and taker_id = pg_temp.id('dual')),
  'care_assistant', 'SIG1-C3 (d): her qualification is read in the owning team, not her other team');

select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'signal_untaken', 'P1', 0, null, pg_temp.k(10)), 'ok',
  'fixture: the untaken threshold set to 0 minutes, so the SIG1-5 step runs at the next evaluation');
reset role;
select pg_temp.eval();
select ok(not pg_temp.escalated('c3a') and pg_temp.ops('c3a') = 0,
  'SIG1-C3 (a): no Operations delivery after signal_untaken (covering registered nurse took it)');
select ok(pg_temp.escalated('c3b') and pg_temp.ops('c3b') = 1, 'SIG1-C3 (b): Operations receives it (covering care assistant took it)');
select ok(pg_temp.escalated('c3d') and pg_temp.ops('c3d') = 1, 'SIG1-C3 (d): Operations receives it');
select ok(pg_temp.escalated('c3c') and pg_temp.ops('c3c') = 1, 'fixture: Operations received no-show c3c (care assistant took it)');
select is(pg_temp.take(pg_temp.u(904), 'c3c', 5) ->> 'result', 'ok', 'SIG1-C3 (c): the Operations member who received it takes');
select is(pg_temp.stops(pg_temp.u(904), 'c3c'), true, 'SIG1-C3 (c): an Operations member''s take stops the step');

-- =====================================================================================================================
-- SIG2-C1 (1) (CGR-48): the reader says whether a watched period runs
-- =====================================================================================================================
create function pg_temp.watched_now_for(p_user uuid, p_n text) returns boolean language plpgsql as $$
declare r boolean;
begin
  perform pg_temp.act_as(p_user::text);
  set local role authenticated;
  select m.watched_now into r from public.my_signals() m where m.signal_id = pg_temp.sig(p_n);
  reset role;
  return r;
end $$;
create function pg_temp.hours(p_starts time, p_ends time) returns void language sql as $$
  delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';
  insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
  select '00000000-0000-4000-b000-000000000011', d, p_starts, p_ends from generate_series(1, 7) d where p_starts is not null;
$$;
create function pg_temp.now_local() returns time language sql stable as $$ select (private.at_zurich(private.now()))::time $$;

select pg_temp.hours(null, null);
select is(pg_temp.watched_now_for(pg_temp.u(902), 'c3b'), false, 'SIG2-C1 (1): no watched hours recorded → watched_now false');
select pg_temp.hours('00:00', '24:00');
select is(pg_temp.watched_now_for(pg_temp.u(902), 'c3b'), true, 'SIG2-C1 (1): a watched period runs now → watched_now true');
select pg_temp.hours(case when pg_temp.now_local() >= '12:00' then time '00:00' else time '23:00' end,
                     case when pg_temp.now_local() >= '12:00' then time '01:00' else time '24:00' end);
select is(pg_temp.watched_now_for(pg_temp.u(902), 'c3b'), false, 'SIG2-C1 (1): outside every watched period now → watched_now false');
select is(private.watched_inside('00000000-0000-4000-b000-000000000011', private.now()), false,
  'the flag is the SIG2-12 predicate at the reader''s instant');

-- =====================================================================================================================
-- SIG2-C1 (2) (CGR-48): planned visits of the next 7 days outside the watched hours
-- =====================================================================================================================
create function pg_temp.planned(p_n text, p_day integer, p_start time, p_end time, p_status text default 'planned',
                                p_org text default 'a') returns void language sql as $$
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status,
                                  responsible_user_id)
  values (case p_org when 'a' then '00000000-0000-4000-b000-000000000011'::uuid else '00000000-0000-4000-b000-000000000012'::uuid end,
          pg_temp.id(p_n),
          case p_org when 'a' then '00000000-0000-4000-a000-000000000208'::uuid else '00000000-0000-4000-a000-000000000251'::uuid end,
          case p_org when 'a' then '00000000-0000-4000-a000-000000000101'::uuid else pg_temp.id('t3') end,
          pg_temp.today() + p_day, p_start, p_end, false, p_status,
          case p_org when 'a' then '00000000-0000-4000-a000-000000000902'::uuid else pg_temp.id('p1') end)
$$;
create function pg_temp.listed(p_user uuid, p_n text, p_own boolean default false) returns boolean language plpgsql as $$
declare r boolean;
begin
  perform pg_temp.act_as(p_user::text);
  set local role authenticated;
  r := exists (select 1 from public.visits_outside_watched_hours(p_own) x where x.visit_id = pg_temp.id(p_n));
  reset role;
  return r;
end $$;
create function pg_temp.listed_count(p_user uuid) returns integer language plpgsql as $$
declare r integer;
begin
  perform pg_temp.act_as(p_user::text);
  set local role authenticated;
  select count(*)::int into r from public.visits_outside_watched_hours() x;
  reset role;
  return r;
end $$;

select pg_temp.planned('w2100', 1, '21:00', '21:30');
select pg_temp.planned('w1900', 1, '19:00', '19:30');
select pg_temp.planned('w1930', 1, '19:30', '20:30');
select pg_temp.planned('w0650', 2, '06:50', null);
select pg_temp.planned('wday6', 6, '21:00', '21:30');
select pg_temp.planned('wday7', 7, '21:00', '21:30');
select pg_temp.planned('wcanc', 1, '21:00', '21:30', 'cancelled');
select pg_temp.planned('wnite', 3, '23:30', '00:15');
select pg_temp.planned('wb2100', 1, '21:00', '21:30', 'planned', 'b');
select pg_temp.planned('wsusp', 1, '21:00', '21:30');
update public.care_visits set suspended_at = private.now() where id = pg_temp.id('wsusp');

select pg_temp.hours('07:00', '20:00');
select is(pg_temp.listed(pg_temp.u(905), 'w2100'), true, 'SIG2-C1 (2): watched 07:00-20:00, a visit 21:00-21:30 → listed');
select is(pg_temp.listed(pg_temp.u(905), 'w1900'), false, 'SIG2-C1 (2): a visit 19:00-19:30 → not listed');
select is(pg_temp.listed(pg_temp.u(905), 'w1930'), true,
  'a visit 19:30-20:30 is not wholly inside a watched period → listed (protective reading, ADR-082)');
select is(pg_temp.listed(pg_temp.u(905), 'w0650'), true, 'a visit at 06:50 without a planned end → listed');
select is(pg_temp.listed(pg_temp.u(905), 'wday6'), true, 'the 7th day (today + 6) is in the window');
select is(pg_temp.listed(pg_temp.u(905), 'wday7'), false, 'today + 7 is outside the 7-day window');
select ok(not pg_temp.listed(pg_temp.u(905), 'wcanc') and not pg_temp.listed(pg_temp.u(905), 'wsusp'),
  'cancelled and suspended visits are not planned visits → not listed');
select is(pg_temp.listed(pg_temp.u(905), 'wnite'), true, 'a visit across midnight (23:30-00:15) → listed');
select is(pg_temp.listed(pg_temp.u(905), 'wb2100'), false, 'SIG2-C1 (2): another organisation''s visits are never listed');
select is(pg_temp.listed(pg_temp.u(903), 'w2100'), false, 'the other organisation''s administrator never sees org A''s visits');

-- adjacent periods are one
delete from public.organization_watched_hours where organization_id = '00000000-0000-4000-b000-000000000011';
insert into public.organization_watched_hours (organization_id, weekday, starts, ends)
select '00000000-0000-4000-b000-000000000011', d, s, e from generate_series(1, 7) d,
       (values (time '07:00', time '19:15'), (time '19:15', time '22:00')) p(s, e);
select is(pg_temp.listed(pg_temp.u(905), 'w2100'), false, 'adjacent watched periods 07:00-19:15 and 19:15-22:00 cover 21:00-21:30 → not listed');
select is(pg_temp.listed(pg_temp.u(905), 'w1930'), false, 'and 19:30-20:30 across the boundary → not listed');

-- team scope
select pg_temp.hours(null, null);
select is(pg_temp.listed(pg_temp.u(902), 'w1900'), true, 'SIG2-C1 (2): no watched hours → every planned visit listed (team view, own team)');
select is(pg_temp.listed_count(pg_temp.u(905)),
  (select count(*)::int from public.care_visits v
   where v.organization_id = '00000000-0000-4000-b000-000000000011' and v.status = 'planned' and v.suspended_at is null
     and v.visit_date between pg_temp.today() and pg_temp.today() + 6),
  'SIG2-C1 (2): no watched hours → the administrator sees every planned visit of the organisation in the window');
select is(pg_temp.listed(pg_temp.id('cover_ca'), 'w1900'), false,
  'team view: a member of Mitte only never sees Nord''s visits');
insert into public.team_memberships (team_id, user_id, qualification)
values ('00000000-0000-4000-a000-000000000102', pg_temp.u(905), 'registered_nurse');
select is(pg_temp.listed(pg_temp.u(905), 'w1900', true), false,
  'team view (/team, own teams only): an administrator who is a member of Mitte sees none of Nord''s visits there');
select is(pg_temp.listed(pg_temp.u(905), 'w1900'), true, 'and still the whole organisation on /admin');
select is(pg_temp.listed(pg_temp.u(904), 'w1900'), false,
  'Operations (not an administrator, member of no team) reads no list (the brief names /admin and /team)');
select ok((select string_agg(a, ',' order by a) from unnest((select proargnames from pg_proc
             where oid = 'public.visits_outside_watched_hours(boolean)'::regprocedure)) a)
          = 'organization_id,p_own_teams,team_id,team_name,time_end,time_start,visit_date,visit_id',
  'the list holds date, times and team only: no client, case or person column');
select ok(not has_function_privilege('anon', 'public.visits_outside_watched_hours(boolean)', 'execute'), 'anon cannot read the list');

-- =====================================================================================================================
-- FUP1-1 (CGR-57, 0071, ADR-084): a planned visit without an end has the ABS1 length (private.visit_interval)
-- =====================================================================================================================
select pg_temp.planned('f1950m45', 1, '19:50', null);
select pg_temp.planned('f1950m0', 1, '19:50', null);
select pg_temp.planned('f0800m20', 1, '08:00', null);
select pg_temp.planned('f1930m20', 1, '19:30', null);
select pg_temp.planned('f1950eq', 1, '19:50', '19:50');
update public.care_visits set planned_minutes_a = 30, planned_minutes_b = 15 where id = pg_temp.id('f1950m45');
update public.care_visits set planned_minutes_a = 20 where id in (pg_temp.id('f0800m20'), pg_temp.id('f1930m20'));
update public.care_visits set planned_minutes_c = 45 where id = pg_temp.id('f1950eq');
select pg_temp.hours('07:00', '20:00');
select is(pg_temp.listed(pg_temp.u(905), 'f1950m45'), true,
  'FUP1-1: watched 07:00-20:00, a visit at 19:50 without an end and 45 planned minutes (to 20:35) → listed');
select is(pg_temp.listed(pg_temp.u(905), 'f1950m0'), true,
  'FUP1-1: a visit at 19:50 without an end and without planned minutes (to the end of its day) → listed');
select is(pg_temp.listed(pg_temp.u(905), 'f0800m20'), false,
  'FUP1-1: a visit at 08:00 without an end and 20 planned minutes → not listed');
select is(pg_temp.listed(pg_temp.u(905), 'f1930m20'), false,
  'FUP1-1: a visit at 19:30 without an end and 20 planned minutes (to 19:50) → not listed');
select is(pg_temp.listed(pg_temp.u(905), 'f1950eq'), true,
  'FUP1-1: end = start reads as no end, as in visit_interval (19:50 + 45 planned minutes) → listed');
select is(pg_temp.listed(pg_temp.u(905), 'w0650'), true, 'FUP1-1: the 06:50 case without a planned end stays listed');
select is((select upper(private.visit_wall_range(v)) from public.care_visits v where v.id = pg_temp.id('f1950m45')),
  (pg_temp.today() + 1) + time '20:35', 'FUP1-1: the wall-clock end is start + planned minutes A+B+C (20:35)');
select is((select private.at_zurich(upper(private.visit_interval(v))) = upper(private.visit_wall_range(v))
           from public.care_visits v where v.id = pg_temp.id('f1950m45')), true,
  'FUP1-1: the list and ABS1 (private.visit_interval) give the visit the same end');
select is((select upper(private.visit_wall_range(v)) from public.care_visits v where v.id = pg_temp.id('f1950m0')),
  (pg_temp.today() + 2)::timestamp, 'FUP1-1: without planned minutes the visit runs to the end of its day, as visit_interval');
select ok(not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'private' and p.proname = 'visit_wall_range' and p.pronargs = 3),
  'FUP1-1: the one-minute helper (date, time, time) is gone');

-- =====================================================================================================================
-- FUP1-2 (CGR-58, 0071, ADR-084): the banner follows the delivery, or the instant the step is due
-- =====================================================================================================================
select pg_temp.act_as('00000000-0000-4000-a000-000000000905');
set local role authenticated;
select is(public.set_exception_rule('00000000-0000-4000-b000-000000000011', 'signal_untaken', 'P1', 15, null, pg_temp.k(11)), 'ok',
  'fixture: the untaken threshold back to 15 minutes');
reset role;
-- A P1 no-show of Nord at a fixed instant (Monday 2 November 2026), taken by the care assistant of Nord (the take does not
-- stop the step), not escalated, no Operations delivery yet.
create function pg_temp.fsig(p_n text, p_created timestamptz) returns uuid language plpgsql as $$
begin
  perform pg_temp.planned('fv' || p_n, 1, '19:00', '19:30');
  insert into public.safety_signals (organization_id, id, team_id, visit_id, signal_kind, exception_key, p1_at, created_at)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.id('fs' || p_n), '00000000-0000-4000-a000-000000000101',
          pg_temp.id('fv' || p_n), 'no_show', 'fup1:' || p_n, p_created, p_created);
  insert into public.signal_takes (organization_id, signal_id, taker_id, qualification, stops_escalation, taken_at)
  values ('00000000-0000-4000-b000-000000000011', pg_temp.id('fs' || p_n), pg_temp.u(906), 'care_assistant', false,
          p_created + interval '5 minutes');
  return pg_temp.id('fs' || p_n);
end $$;
-- An Operations delivery of the signal (…904, reason untaken) with an outside result (null: no outside row).
create function pg_temp.fops(p_n text, p_result text) returns void language plpgsql as $$
begin
  insert into public.signal_deliveries (id, organization_id, signal_id, recipient_id, reason, signal_kind, visit_id)
  values (pg_temp.id('fd' || p_n), '00000000-0000-4000-b000-000000000011', pg_temp.id('fs' || p_n), pg_temp.u(904), 'untaken',
          'no_show', pg_temp.id('fv' || p_n));
  if p_result is not null then
    insert into public.signal_outside_deliveries (id, organization_id, signal_id, recipient_id, result, sent_at)
    values (pg_temp.id('fd' || p_n), '00000000-0000-4000-b000-000000000011', pg_temp.id('fs' || p_n), pg_temp.u(904), p_result,
            case when p_result = 'sent' then pg_temp.at('2026-11-02', '19:58') end);
  end if;
end $$;
select pg_temp.fsig('a', pg_temp.at('2026-11-02', '19:50'));   -- due 20:05
select pg_temp.fsig('b', pg_temp.at('2026-11-02', '19:50'));
select pg_temp.fsig('c', pg_temp.at('2026-11-02', '19:50'));

select pg_temp.hours('07:00', '20:00');
select is(private.watched_inside('00000000-0000-4000-b000-000000000011', pg_temp.at('2026-11-02', '19:55')), true,
  'fixture: 19:55 is inside the watched period 07:00-20:00 (watched_now at that instant would promise the message)');
select is(private.signal_step_outside_app(pg_temp.id('fsa'), pg_temp.at('2026-11-02', '19:55')), false,
  'FUP1-2: watched until 20:00, a care assistant takes at 19:55, the step is due at 20:05 → app only');
select is(private.signal_step_outside_app(pg_temp.id('fsa'), pg_temp.at('2026-11-02', '19:52')), false,
  'FUP1-2: judged at the due instant, not at the reading instant (19:52 → still app only)');
select pg_temp.hours('07:00', '21:00');
select is(private.signal_step_outside_app(pg_temp.id('fsa'), pg_temp.at('2026-11-02', '19:55')), true,
  'FUP1-2: watched until 21:00, the step due at 20:05 reaches Operations outside the app → the message follows');
select is(private.signal_step_outside_app(pg_temp.id('fsa'), pg_temp.at('2026-11-02', '21:10')), false,
  'FUP1-2: the step overdue and not yet made at 21:10 (after the watched period) → app only (never earlier than the reading)');

select pg_temp.fops('a', 'sent');
select pg_temp.hours('07:00', '20:00');
select is(private.signal_step_outside_app(pg_temp.id('fsa'), pg_temp.at('2026-11-02', '20:30')), true,
  'FUP1-2: an Operations delivery already sent outside the app → the flag follows it, also when read after the watched period');
select pg_temp.fops('b', 'outside_working_time');
select pg_temp.hours('00:00', '24:00');
select is(private.signal_step_outside_app(pg_temp.id('fsb'), pg_temp.at('2026-11-02', '19:55')), false,
  'FUP1-2: an Operations delivery classified outside_working_time → app only, even while a watched period runs');
select pg_temp.fops('c', null);
select is(private.signal_step_outside_app(pg_temp.id('fsc'), pg_temp.at('2026-11-02', '19:55')), false,
  'FUP1-2: the step made, but no outside delivery (channel off) → app only');

-- The reader: c3b was taken by a covering care assistant and went to Operations in the app only (no outside channel).
create function pg_temp.outside_app_for(p_user uuid, p_n text) returns boolean language plpgsql as $$
declare r boolean;
begin
  perform pg_temp.act_as(p_user::text);
  set local role authenticated;
  select m.operations_outside_app into r from public.my_signals() m where m.signal_id = pg_temp.sig(p_n);
  reset role;
  return r;
end $$;
select pg_temp.hours('00:00', '24:00');
select ok(pg_temp.watched_now_for(pg_temp.u(902), 'c3b') and not pg_temp.outside_app_for(pg_temp.u(902), 'c3b'),
  'FUP1-2 reader: a watched period runs now (watched_now) but the step was made in the app only → operations_outside_app false');
insert into public.signal_outside_deliveries (id, organization_id, signal_id, recipient_id, result, sent_at)
select d.id, d.organization_id, d.signal_id, d.recipient_id, 'sent', private.now()
from public.signal_deliveries d where d.signal_id = pg_temp.sig('c3b') and d.reason = 'untaken';
select pg_temp.hours(null, null);
select ok(not pg_temp.watched_now_for(pg_temp.u(902), 'c3b') and pg_temp.outside_app_for(pg_temp.u(902), 'c3b'),
  'FUP1-2 reader: the Operations delivery was sent outside the app → operations_outside_app true without a watched period');

select * from finish();
rollback;
