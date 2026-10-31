-- COVER1: cross-team cover without a dispatcher (PO brief docs/agents/briefs/COVER1.md).
-- Testteam Nord (…101) and Testteam Mitte (…102) are both in region "Bern West".
-- Here: coach …901 joins Mitte as care assistant, operations …904 joins Mitte as registered nurse.
-- Nurse …902 is in Nord (the visits' own team). Foreign admin …903 is in org B.
-- Visits of Nord, case …208, uncovered: X (A, in 10 h), Y (B, in 10 h), Z (A, in 30 h), W (A, in 2 h).
begin;
create extension if not exists pgtap with schema extensions;

select plan(18);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'care_assistant'),
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000904', 'registered_nurse');
update public.cases set primary_nurse_id = '00000000-0000-4000-a000-000000000902', medical_order_status = 'present'
  where id = '00000000-0000-4000-a000-000000000208';
-- Cover is off by default until D-3 (migration 0029); this file tests the mechanism with it switched on for org A.
insert into public.cover_settings (organization_id, offer_lead_hours, fallback_lead_hours, cover_enabled)
values ('00000000-0000-4000-b000-000000000011', 24, 4, true);

insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status,
                                planned_minutes_a, planned_minutes_b, planned_minutes_c)
select '00000000-0000-4000-b000-000000000011', x.id, '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
       ((private.now() + x.lead) at time zone 'Europe/Zurich')::date, date_trunc('minute', ((private.now() + x.lead) at time zone 'Europe/Zurich'))::time,
       null, array['Grundpflege'], false, 'planned', x.a, x.b, 0
from (values ('ac000000-0000-4000-8000-00000000000a'::uuid, interval '10 hours', 30, 0),
             ('ac000000-0000-4000-8000-00000000000b'::uuid, interval '10 hours', 0, 20),
             ('ac000000-0000-4000-8000-00000000000c'::uuid, interval '30 hours', 30, 0),
             ('ac000000-0000-4000-8000-00000000000d'::uuid, interval '2 hours', 30, 0)) x(id, lead, a, b);

select ok(not has_function_privilege('anon', 'public.cover_offers()', 'execute'), 'anon sees no offers');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'cover_offers'
             and exists (select 1 from unnest(p.proargnames) a where a ~ '(client|first_name|last_name|address|phone|case_id)')), 0,
  'an offer carries no client identity');

-- Offers ----------------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select ok(exists (select 1 from public.cover_offers() where visit_id = 'ac000000-0000-4000-8000-00000000000a'),
  'a member of a neighbouring team in the same region is offered the visit');
select ok(not exists (select 1 from public.cover_offers() where visit_id = 'ac000000-0000-4000-8000-00000000000b'),
  'a care assistant is never offered category B work');
select ok(not exists (select 1 from public.cover_offers() where visit_id in ('ac000000-0000-4000-8000-00000000000c', 'ac000000-0000-4000-8000-00000000000d')),
  'only inside the offer window (more than 4 h, at most 24 h before the start)');
select ok(public.sync_cover_offers() >= 2, 'offers are recorded the first time they are seen');
select is(public.accept_cover('ac000000-0000-4000-8000-00000000000b', 'ac000000-0000-4000-8000-000000000001'), 'rejected',
  'a care assistant cannot accept B work');
select is(public.accept_cover('ac000000-0000-4000-8000-00000000000a', 'ac000000-0000-4000-8000-000000000002'), 'ok', 'she accepts in one tap');
select ok(exists (select 1 from public.my_covers() where visit_id = 'ac000000-0000-4000-8000-00000000000a'), 'and sees her accepted cover');
select isnt(public.depart_visit('ac000000-0000-4000-8000-00000000000a', 'ac000000-0000-4000-8000-000000000003'), 'ok',
  'context access waits for D-3: she cannot run the visit in the app yet');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select ok(exists (select 1 from public.cover_offers() where visit_id = 'ac000000-0000-4000-8000-00000000000b'),
  'a registered nurse of the neighbouring team is offered the B visit');
select is(public.accept_cover('ac000000-0000-4000-8000-00000000000a', 'ac000000-0000-4000-8000-000000000004'), 'taken',
  'the first acceptance wins');
reset role;

select ok((select responsible_user_id is null and covered_by = '00000000-0000-4000-a000-000000000901'
                  and cover_team_id = '00000000-0000-4000-a000-000000000102' and team_id = '00000000-0000-4000-a000-000000000101'
           from public.care_visits where id = 'ac000000-0000-4000-8000-00000000000a')
          and (select primary_nurse_id = '00000000-0000-4000-a000-000000000902' from public.cases where id = '00000000-0000-4000-a000-000000000208'),
  'one visit is covered (no responsible member until it can be performed); case, team and primary nurse stay');

select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;
select ok(not exists (select 1 from public.cover_offers() where visit_id::text like 'ac000000%'),
  'the own team is not offered its own visits');
select ok(exists (select 1 from public.team_cases() tc, jsonb_array_elements(tc.upcoming) u
                  where u ->> 'visit_id' = 'ac000000-0000-4000-8000-00000000000a' and u ->> 'covered_by_team' = 'Testteam Mitte'
                    and u -> 'flags' ? 'uncovered'),
  'the own team sees who covered, and the visit stays flagged uncovered until it can be performed');
reset role;

select pg_temp.act_as('00000000-0000-4000-a000-000000000903');
set local role authenticated;
select is((select count(*)::int from public.cover_offers()), 0, 'another organisation never sees the offers');
reset role;

-- Expiry: after the fallback lead nobody accepts; OPS1 takes over unchanged.
insert into public.cover_events (organization_id, visit_id, kind)
values ('00000000-0000-4000-b000-000000000011', 'ac000000-0000-4000-8000-00000000000d', 'offered');
select pg_temp.act_as('00000000-0000-4000-a000-000000000901');
set local role authenticated;
select ok(public.sync_cover_offers() >= 1, 'sync records the expiry');
reset role;
select ok(exists (select 1 from public.cover_events where visit_id = 'ac000000-0000-4000-8000-00000000000d' and kind = 'expired')
          and exists (select 1 from public.cover_events where visit_id = 'ac000000-0000-4000-8000-00000000000a' and kind = 'accepted'
                      and nurse_id = '00000000-0000-4000-a000-000000000901'),
  'offer, acceptance and expiry are recorded');

select * from finish();
rollback;
