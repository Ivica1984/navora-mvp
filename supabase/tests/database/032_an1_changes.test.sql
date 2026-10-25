-- AN1 changes requested by the PO (review 2026-10-22 14:30). Migration 0032.
-- Org B (team …151, case …251, admin …903 = coordinator): visits with known times, performed by three persons.
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.kpi(p_kpi text, p_team uuid default null) returns jsonb language sql as $$
  select to_jsonb(k) from public.pilot_kpis((private.now() at time zone 'Europe/Zurich')::date) k where k.kpi = p_kpi and k.team_id is not distinct from p_team
$$;

-- Six completed visits this month: five complete (15 min travel, 45 min care), one without departure.
-- Performers: three persons (the admin and two synthetic ids), so the team may show its figures.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000012', ('b2000000-0000-4000-8000-00000000000' || g)::uuid, '00000000-0000-4000-a000-000000000251',
       '00000000-0000-4000-a000-000000000151', date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date)::date, '08:00', '09:00', false, 'completed'
from generate_series(1, 6) g;
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
select '00000000-0000-4000-b000-000000000012', ('b2000000-0000-4000-8000-00000000000' || g)::uuid, '00000000-0000-4000-a000-000000000151',
       e.t, e.f, e.s,
       (array['00000000-0000-4000-a000-000000000903', 'b2000000-0000-4000-8000-0000000000f1', 'b2000000-0000-4000-8000-0000000000f2'])[1 + g % 3]::uuid,
       date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date) + e.at
from generate_series(1, 6) g
cross join (values ('departed', 'planned', 'on_the_way', interval '8 hours'),
                   ('started', 'on_the_way', 'started', interval '8 hours 15 minutes'),
                   ('completed', 'started', 'completed', interval '9 hours')) e(t, f, s, at)
where not (g = 6 and e.t = 'departed');      -- visit 6 has no departure

-- COVER1: two offered visits of the team; one covered without Operations, one covered after Operations took over.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, billable, status, created_at)
select '00000000-0000-4000-b000-000000000012', x.id, '00000000-0000-4000-a000-000000000251', '00000000-0000-4000-a000-000000000151',
       date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date)::date + 1, '10:00', false, 'planned', date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date) - interval '5 days'
from (values ('b2000000-0000-4000-8000-0000000000c1'::uuid), ('b2000000-0000-4000-8000-0000000000c2'::uuid)) x(id);
insert into public.cover_events (organization_id, visit_id, kind, nurse_id, team_id, created_at)
select '00000000-0000-4000-b000-000000000012', x.id, x.kind, x.nurse, null, (date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date)::date + 1 + time '10:00') at time zone 'Europe/Zurich' - x.before
from (values ('b2000000-0000-4000-8000-0000000000c1'::uuid, 'offered', null::uuid, interval '23 hours'),
             ('b2000000-0000-4000-8000-0000000000c1'::uuid, 'accepted', '00000000-0000-4000-a000-000000000903'::uuid, interval '18 hours'),
             ('b2000000-0000-4000-8000-0000000000c2'::uuid, 'offered', null::uuid, interval '23 hours'),
             ('b2000000-0000-4000-8000-0000000000c2'::uuid, 'accepted', '00000000-0000-4000-a000-000000000903'::uuid, interval '10 hours')) x(id, kind, nurse, before);
insert into public.exception_events (organization_id, exception_key, kind, actor_id, created_at)
values ('00000000-0000-4000-b000-000000000012', 'visit_uncovered:b2000000-0000-4000-8000-0000000000c2', 'take', '00000000-0000-4000-a000-000000000903',
        (date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date)::date + 1 + time '10:00') at time zone 'Europe/Zurich' - interval '12 hours');

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((pg_temp.kpi('care_share_in_visits') ->> 'value')::numeric, 75.0::numeric, 'the measured figure is the care share within visits');
select is((pg_temp.kpi('care_share_in_visits') ->> 'base')::int, 5, 'a visit without departure changes the base, not the share');
select is((pg_temp.kpi('incomplete_visits') ->> 'value')::numeric, 1::numeric, 'and is counted as incomplete');
select ok((pg_temp.kpi('care_share_in_visits') ->> 'note') like '%Nicht enthalten: Dokumentation, Rückweg%', 'its definition says what is not included');
select ok((pg_temp.kpi('direct_care_share') ->> 'value')::numeric is null and (pg_temp.kpi('direct_care_share') ->> 'note') like 'Noch nicht messbar%',
  'the North Star is a placeholder until paid working time is recorded');
select is((pg_temp.kpi('care_share_in_visits', '00000000-0000-4000-a000-000000000151') ->> 'value')::numeric, 75.0::numeric,
  'a team with three persons shows its figure');
select is((pg_temp.kpi('cover_without_operations') ->> 'value')::numeric, 50.0::numeric,
  'cover without Operations: the cover after Operations took over does not count');
select is((pg_temp.kpi('cover_without_operations') ->> 'base')::int, 2, 'of two offered visits');
select is((pg_temp.kpi('cover_median_hours') ->> 'value')::numeric, 10.0::numeric,
  'time to cover runs from entering the window (24 h before the start): 6 h and 14 h → median 10 h');
select ok((pg_temp.kpi('open_p1_exceptions') ->> 'note') like 'Stand jetzt%' and (pg_temp.kpi('open_p1_exceptions') ->> 'base')::int is not null,
  'open P1 exceptions say "Stand jetzt" and have a base');
reset role;

-- A two-person team (second team of org B, three visits by two persons): no team figures.
insert into public.teams (organization_id, id, name, region, status) values
  ('00000000-0000-4000-b000-000000000012', 'b2000000-0000-4000-8000-0000000000b2', 'Fremdteam B2', 'Bern West', 'active');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000012', ('b2000000-0000-4000-8000-0000000000d' || g)::uuid, '00000000-0000-4000-a000-000000000251',
       'b2000000-0000-4000-8000-0000000000b2', date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date)::date, '11:00', '12:00', false, 'completed'
from generate_series(1, 3) g;
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
select '00000000-0000-4000-b000-000000000012', ('b2000000-0000-4000-8000-0000000000d' || g)::uuid, 'b2000000-0000-4000-8000-0000000000b2',
       e.t, e.f, e.s,
       (array['b2000000-0000-4000-8000-0000000000f1', 'b2000000-0000-4000-8000-0000000000f2'])[1 + g % 2]::uuid,
       date_trunc('month', (private.now() at time zone 'Europe/Zurich')::date) + e.at
from generate_series(1, 3) g
cross join (values ('departed', 'planned', 'on_the_way', interval '11 hours'),
                   ('started', 'on_the_way', 'started', interval '11 hours 10 minutes'),
                   ('completed', 'started', 'completed', interval '12 hours')) e(t, f, s, at);
select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select ok((pg_temp.kpi('care_share_in_visits', 'b2000000-0000-4000-8000-0000000000b2') ->> 'value') is null
          and (pg_temp.kpi('care_share_in_visits', 'b2000000-0000-4000-8000-0000000000b2') ->> 'too_few')::boolean,
  'a team with two persons shows no figure');
-- AN1 condition (PO review 2026-10-22 17:15, built in 0057 with AN2): the hidden team's figure would be "organisation
-- minus the visible team", i.e. the two persons of Fremdteam B2, so the organisation figure is hidden too.
select ok((pg_temp.kpi('care_share_in_visits') ->> 'value') is null
          and (pg_temp.kpi('care_share_in_visits') ->> 'note') like 'Zu wenig Personen%',
  'the organisation figure is hidden while the persons of all hidden teams number 1 or 2 (AN1 condition)');
reset role;

select * from finish();
rollback;
