-- AN1: pilot impact dashboard (PO brief docs/agents/briefs/AN1.md).
-- Org B (team …151, case …251) gets five completed visits here with known times; its admin …903 is a coordinator.
-- Org A: operations …904 (coordinator), nurse …902 (Testteam Nord only).
begin;
create extension if not exists pgtap with schema extensions;

select plan(11);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

select ok(not has_function_privilege('anon', 'public.pilot_kpis(date)', 'execute'), 'anon cannot read the KPIs');

-- Five completed visits: 15 min travel, 45 min care → direct care share 75 %; one with a time correction.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status)
select '00000000-0000-4000-b000-000000000012', ('ab000000-0000-4000-8000-00000000000' || g)::uuid, '00000000-0000-4000-a000-000000000251',
       '00000000-0000-4000-a000-000000000151', date_trunc('month', current_date)::date, '08:00', '09:00', false, 'completed'
from generate_series(1, 5) g;
insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
select '00000000-0000-4000-b000-000000000012', ('ab000000-0000-4000-8000-00000000000' || g)::uuid, '00000000-0000-4000-a000-000000000151',
       e.t, e.f, e.s, '00000000-0000-4000-a000-000000000903', date_trunc('month', current_date) + e.at
from generate_series(1, 5) g
cross join (values ('departed', 'planned', 'on_the_way', interval '8 hours'),
                   ('started', 'on_the_way', 'started', interval '8 hours 15 minutes'),
                   ('completed', 'started', 'completed', interval '9 hours')) e(t, f, s, at);
insert into public.visit_time_corrections (organization_id, visit_id, event_id, corrected_at, reason, actor_id, idempotency_key)
select e.organization_id, e.visit_id, e.id, e.occurred_at, 'Zeit nachgetragen', '00000000-0000-4000-a000-000000000903', gen_random_uuid()
from public.visit_events e where e.visit_id = 'ab000000-0000-4000-8000-000000000001' and e.event_type = 'completed';

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select value from public.pilot_kpis(current_date) where team_id is null and kpi = 'care_share_in_visits'), 75.0::numeric,
  'care share within visits: care ÷ travel, care and pause minutes (AN1 change: named honestly)');
select is((select base from public.pilot_kpis(current_date) where team_id is null and kpi = 'care_share_in_visits'), 5, 'with its base count');
select is((select too_few from public.pilot_kpis(current_date) where team_id is null and kpi = 'care_share_in_visits'), false, 'five visits are enough');
select is((select value from public.pilot_kpis(current_date) where team_id is null and kpi = 'time_correction_share'), 20.0::numeric,
  'share of visits with a time correction');
select ok((select value is null and too_few and note like 'Zu wenig Personen%' from public.pilot_kpis(current_date)
           where team_id = '00000000-0000-4000-a000-000000000151' and kpi = 'care_share_in_visits'),
  'a team with fewer than 3 persons shows no figure (no per-nurse inference)');
select is((select count(*)::int from public.pilot_kpis(current_date) where organization_id = '00000000-0000-4000-b000-000000000011'), 0,
  'nothing of another organisation');
select ok(exists (select 1 from public.pilot_kpis(current_date) where kpi = 'p1_median_close_hours' and value is null and note is not null),
  'what cannot be measured yet says so');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select is((select count(*)::int from public.pilot_kpis(current_date) where team_id is null), 0, 'a nurse sees no organisation figures');
select is((select count(*)::int from public.pilot_kpis(current_date) where team_id is distinct from '00000000-0000-4000-a000-000000000101'), 0,
  'and only her own team');
reset role;

select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'pilot_kpis'
             and exists (select 1 from unnest(p.proargnames) a where a in ('performer_id', 'nurse_id', 'user_id', 'client_name'))), 0,
  'the read model has no per-person or client columns');

select * from finish();
rollback;
