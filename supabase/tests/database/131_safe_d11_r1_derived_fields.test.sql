-- SAFE-D11 follow-up, CGR-194 with (b) (brief `docs/agents/briefs/SAFE-D11.md` §PO 20:39 (1) and §PO 21:39; ADR-184,
-- ADR-185): the new team search that R1 opens for a reopened case is derived like a first search, at the time of the
-- reopen, and is never a copy of the withdrawn row.
--
-- Fixture: a returning client (RET1, 0034) of Testteam Nord …101 whose first search lies one week in the past
-- (test clock `navora.test_now`, DST1 / ADR-081: local and CI only). Needs assessment not done, so the search needs a
-- registered nurse (J3, 0017). Hospital referral, so the response deadline is the platform default for
-- `hospital_discharge`. The case is closed while still in the search and reopened one week later.
-- What a copy would look like: the withdrawn row's deadline and first-refusal window both end before the reopen time;
-- assertions 9 to 13 fail for a copied row. Test-only: no migration is needed (the first-search insert of 0034, patched
-- by 0125, already derives every field); written after 0125, so there is no red run to quote.
--
-- Users: Operations …904 (org A) · Testteam Nord …101 (Basel-Stadt, the previous team of seed case …208). Synthetic data only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;

-- Two instants on a Tuesday 09:00 Zurich, one week apart, both before the real clock (working time on both).
create temp table clk as
  select private.at_zurich((date_trunc('week', private.at_zurich(pg_catalog.now())) - interval '13 days' + interval '9 hours')::timestamp) as t0;
alter table clk add column t1 timestamptz;
update clk set t1 = t0 + interval '7 days';
grant select on clk to authenticated;

select set_config('navora.test_now', (select t0 from clk)::text, true);

-- Seed case …208 (Testteam Nord …101) closed ten days before t0, so it is linkable (RET1).
insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, actor_id, idempotency_key, created_at)
values ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'close', 'moved_inpatient',
        '00000000-0000-4000-a000-000000000904', gen_random_uuid(), private.now() - interval '10 days');
update public.cases set lifecycle = 'closed', status = 'abgeschlossen', primary_nurse_id = null, deputy_nurse_id = null
  where id = '00000000-0000-4000-a000-000000000208';

insert into public.partner_requests (organization_id, id, partner_name, partner_type, region, urgency, request_title, need_summary,
                                     requested_services, status)
values ('00000000-0000-4000-b000-000000000011', 'd1940000-0000-4000-8000-000000000001', 'Synthetisches Spital', 'Spital', 'Basel-Stadt',
        'mittel', 'Synthetisch: Austritt D194', 'Synthetisch', array['Grundpflege'], 'open');

create temp table facts as select '{"residence_municipality": "Teststadt", "residence_canton": "BE", "insurer_name": "Synthetische Kasse",
  "insurance_type": "KVG"}'::jsonb || jsonb_build_object('requested_start', ((private.now() at time zone 'Europe/Zurich')::date + 8)::text) as f;
grant select on facts to authenticated;

-- First search at t0 ------------------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
create temp table d194 as select (public.link_returning_referral('d1940000-0000-4000-8000-000000000001',
  '00000000-0000-4000-a000-000000000208', 'Bekannte Klientin nach Spital', 'Klient', 'D194R', true, (select f from facts),
  'd1940000-0000-4000-8000-000000000010') ->> 'case_id')::uuid as case_id;
reset role;
alter table d194 add column first_id uuid;
update d194 set first_id = (select m.id from public.matching_requests m where m.case_id = d194.case_id);
grant select on d194 to authenticated;

select ok((select m.status = 'open' and m.preferred_team_id = '00000000-0000-4000-a000-000000000101'
                  and m.first_refusal_until is not null and m.created_at = (select t0 from clk)
           from public.matching_requests m where m.id = (select first_id from d194)),
  'setup: the returning client''s first search opens at t0, first refusal for her previous team');

select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select set_config('navora.test_now', ((select t0 from clk) + interval '1 hour')::text, true);
select is(public.close_case((select case_id from d194), 'declined', null, 'd1940000-0000-4000-8000-000000000011'), 'ok',
  'setup: Operations closes the case while it is still in the team search');
reset role;

select ok((select m.status = 'withdrawn' and m.response_due_at < (select t1 from clk) and m.first_refusal_until < (select t1 from clk)
           from public.matching_requests m where m.id = (select first_id from d194)),
  'fixture: the withdrawn search''s deadline and first-refusal window both end before the reopen time (a copy would be stale)');

-- Reopen one week later (t1) -------------------------------------------------------------------------------------------------
select set_config('navora.test_now', (select t1 from clk)::text, true);
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;
select is(public.reopen_case((select case_id from d194), 'Rückkehr nach Hause', 'd1940000-0000-4000-8000-000000000012'), 'ok',
  'Operations reopens the case at t1');
reset role;

create temp table d194_new as
  select m.* from public.matching_requests m where m.case_id = (select case_id from d194) and m.status = 'open';
create temp table d194_old as
  select m.* from public.matching_requests m where m.id = (select first_id from d194);

select is((select count(*)::int from d194_new where id <> (select first_id from d194)), 1,
  'R1: exactly one new open search, a new row');
select is((select reopened_at from public.cases where id = (select case_id from d194)), (select t1 from clk),
  'the reopen time is t1');

-- Copied from the case like a first search: equal to the withdrawn row's ------------------------------------------------------
select is((select n.region || ' | ' || coalesce(n.urgency, '-') || ' | ' || n.referral_type || ' | ' || coalesce(n.required_qualification, '-')
           from d194_new n),
          (select o.region || ' | ' || coalesce(o.urgency, '-') || ' | ' || o.referral_type || ' | ' || coalesce(o.required_qualification, '-')
           from d194_old o),
  'CGR-194: region, urgency, referral type and required qualification equal the withdrawn search''s');
select is((select n.region || ' | ' || n.referral_type || ' | ' || n.required_qualification from d194_new n),
  'Basel-Stadt | hospital_discharge | registered_nurse',
  'CGR-194: and they are the case''s facts (a registered nurse is needed: needs assessment not done)');

-- Derived at the reopen time, never copied: CGR-194 (b) ----------------------------------------------------------------------
select is((select n.response_due_at from d194_new n),
          private.response_due('00000000-0000-4000-b000-000000000011', 'hospital_discharge', (select t1 from clk)),
  'CGR-194: response_due_at = private.response_due(org, type, reopen time)');
select ok((select n.response_due_at > (select t1 from clk) from d194_new n),
  'CGR-194 (b): the new response deadline lies after the reopen time');
select isnt((select n.response_due_at from d194_new n), (select o.response_due_at from d194_old o),
  'CGR-194 (b): and differs from the withdrawn search''s deadline');
select ok((select n.first_refusal_until is not null and n.first_refusal_until > (select t1 from clk) from d194_new n),
  'CGR-194 (b): the first-refusal window is set and ends after the reopen time');
select ok((select n.first_refusal_until <= n.response_due_at from d194_new n),
  'CGR-194: the first-refusal window ends inside the response deadline');
select is((select n.preferred_team_id from d194_new n), '00000000-0000-4000-a000-000000000101'::uuid,
  'CGR-194: the first refusal goes to the returning team again');

select * from finish();
rollback;
