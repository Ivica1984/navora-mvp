-- IPA1-7, IPA1-8 (migration 0086, ADR-100; brief `docs/agents/briefs/IPA1.md`, PO addendum 18:10; `cra` CGR-69):
-- the intake urgency has no preset and a recorded source; the referrer's requested first-visit date is recorded.
-- Neither changes the order of public.team_offers (G3).
-- Users: nurse …902 (Testteam Nord, Bern West) · operations …904 (org A …011). All data synthetic; every step goes
-- through the real commands, except the step marked "as the table owner".
begin;
create extension if not exists pgtap with schema extensions;

select plan(29);

-- Pinned clock (DST1 pattern): 10:00 Zurich today, so no step depends on the hour CI runs.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.k(n integer) returns uuid language sql immutable as $$
  select ('a0860000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
-- One request in Bern West (org A) through the real command.
create function pg_temp.rec(p_title text, p_urgency text, p_source text, p_start date, p_key integer) returns text
language sql as $$
  select public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital IPA1', 'Spital', 'Bern West', null,
    p_urgency, null, p_title, 'Synthetischer Bedarf', array['Grundpflege'], pg_temp.k(p_key), p_source, p_start)
$$;
-- Convert it with complete facts so the case is ready and the matching request opens.
create function pg_temp.conv(p_title text, p_last text, p_key integer) returns jsonb
language sql as $$
  select public.convert_partner_request((select id from public.partner_requests where request_title = p_title),
    'Klient', p_last, true, jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BE',
      'insurer_name', 'Testkasse', 'insurance_type', 'KVG', 'requested_start', pg_temp.today() + 1),
    pg_temp.k(p_key))
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- Schema --------------------------------------------------------------------------------------------------------------
select col_not_null('public', 'partner_requests', 'urgency_source', 'the request always carries a source value');
select col_not_null('public', 'cases', 'urgency_source', 'the case always carries a source value');
select col_not_null('public', 'matching_requests', 'urgency_source', 'the matching request always carries a source value');
select is(
  (select count(*)::int from public.partner_requests where urgency_source <> 'unknown')
  + (select count(*)::int from public.cases where urgency_source <> 'unknown')
  + (select count(*)::int from public.matching_requests where urgency_source <> 'unknown'),
  0, 'rows recorded before IPA1-7 read "unknown", never back-filled as a recorded source');
select ok(not has_column_privilege('authenticated', 'public.cases', 'urgency_source', 'select')
          and not has_column_privilege('authenticated', 'public.cases', 'referrer_requested_start', 'select'),
  'cases add no column read: teams read the source through team_offers only');

-- Refusals (operations) ---------------------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000904');
set local role authenticated;

select throws_ok($$ select pg_temp.rec('IPA1 ohne Stufe', null, 'referrer_stated', null, 1) $$,
  '22023', 'urgency_required', 'a request without urgency is refused');
select throws_ok($$ select pg_temp.rec('IPA1 leere Stufe', '', 'referrer_stated', null, 2) $$,
  '22023', 'urgency_required', 'an empty urgency is refused (no preset)');
select throws_ok($$ select pg_temp.rec('IPA1 ohne Quelle', 'mittel', null, null, 3) $$,
  '22023', 'urgency_source_required', 'a request without a source is refused');
select throws_ok($$ select pg_temp.rec('IPA1 Quelle unbekannt', 'mittel', 'unknown', null, 4) $$,
  '22023', 'urgency_source_required', '"unknown" cannot be recorded as a new source');
select throws_ok(
  $$ select public.record_partner_request('00000000-0000-4000-b000-000000000011', 'Spital IPA1', 'Spital', 'Bern West',
       null, 'mittel', null, 'IPA1 alte Signatur', 'Bedarf', null, pg_temp.k(5)) $$,
  '22023', 'urgency_source_required', 'a call in the old form (no source argument) is refused');
select throws_ok($$ select pg_temp.rec('IPA1 Datum gestern', 'mittel', 'referrer_stated', pg_temp.today() - 1, 6) $$,
  '22023', 'requested_start_before_request', 'a requested date before the request''s creation date is refused');
select is((select count(*)::int from public.partner_requests where request_title like 'IPA1 %'), 0,
  'no refused request was stored');

-- Recording and the path to the team --------------------------------------------------------------------------------
select is(pg_temp.rec('IPA1 A', 'hoch', 'intake_assessed', null, 10), 'ok', 'operations records an assessed urgency');
select is(pg_temp.rec('IPA1 B', 'mittel', 'referrer_stated', pg_temp.today() + 5, 11), 'ok',
  'operations records a stated urgency with the referrer''s date');
select is(pg_temp.rec('IPA1 C', 'mittel', 'referrer_stated', null, 12), 'ok', 'a request without a date is recorded');
select is(pg_temp.rec('IPA1 D', 'mittel', 'intake_assessed', pg_temp.today(), 13), 'ok',
  'the creation day itself is accepted as the requested date');
select is(
  (select string_agg(request_title || ':' || urgency_source || ':' || coalesce((referrer_requested_start - pg_temp.today())::text, '-'), ',' order by request_title)
   from public.partner_requests where request_title like 'IPA1 %'),
  'IPA1 A:intake_assessed:-,IPA1 B:referrer_stated:5,IPA1 C:referrer_stated:-,IPA1 D:intake_assessed:0',
  'source and date are stored on the request');

select ok((pg_temp.conv('IPA1 A', 'IPA1A', 20) ->> 'ready')::boolean
      and (pg_temp.conv('IPA1 B', 'IPA1B', 21) ->> 'ready')::boolean
      and (pg_temp.conv('IPA1 C', 'IPA1C', 22) ->> 'ready')::boolean
      and (pg_temp.conv('IPA1 D', 'IPA1D', 23) ->> 'ready')::boolean,
  'the four requests become ready cases');
reset role;

select is(
  (select string_agg(last_name || ':' || urgency || ':' || urgency_source || ':' || coalesce((referrer_requested_start - pg_temp.today())::text, '-'), ',' order by last_name)
   from public.cases where last_name like 'IPA1%'),
  'IPA1A:hoch:intake_assessed:-,IPA1B:mittel:referrer_stated:5,IPA1C:mittel:referrer_stated:-,IPA1D:mittel:intake_assessed:0',
  'the case carries the level, the source and the referrer''s date');
select is(
  (select string_agg(c.last_name || ':' || m.urgency_source || ':' || coalesce((m.referrer_requested_start - pg_temp.today())::text, '-'), ',' order by c.last_name)
   from public.matching_requests m join public.cases c on c.id = m.case_id where c.last_name like 'IPA1%'),
  'IPA1A:intake_assessed:-,IPA1B:referrer_stated:5,IPA1C:referrer_stated:-,IPA1D:intake_assessed:0',
  'the matching request carries the source and the referrer''s date');
create temp table ipa1_ent as
  select id, urgency_source from public.partner_requests where request_title like 'IPA1 %'
  union all select id, urgency_source from public.cases where last_name like 'IPA1%'
  union all select m.id, m.urgency_source from public.matching_requests m join public.cases c on c.id = m.case_id
            where c.last_name like 'IPA1%';
select is(
  (select count(*)::int from ipa1_ent e
   where exists (select 1 from public.audit_events a
                 where a.entity_id = e.id and a.changed -> 'urgency_source' ->> 'new' = e.urgency_source
                   and a.actor_id = '00000000-0000-4000-a000-000000000904')),
  12, 'the audit trail records the source on the request, the case and the matching request, with the recording person as actor');

-- As the table owner: distinct creation instants and one response deadline, so the order below is defined.
-- B (latest date) is the oldest, D (earliest date, assessed) the newest; C has no date.
update public.matching_requests m set created_at = private.now() - make_interval(mins => x.age),
                                      response_due_at = private.now() + interval '4 hours'
from (values ('IPA1A', 1), ('IPA1B', 30), ('IPA1C', 20), ('IPA1D', 10)) as x(last_name, age), public.cases c
where c.id = m.case_id and c.last_name = x.last_name;
create temp table ipa1_req as
  select m.id, c.last_name from public.matching_requests m join public.cases c on c.id = m.case_id where c.last_name like 'IPA1%';
grant select on ipa1_req to authenticated;

-- The team (nurse of Testteam Nord) ---------------------------------------------------------------------------------
select pg_temp.act_as('00000000-0000-4000-a000-000000000902');
set local role authenticated;

select is(
  (select o.urgency || ':' || o.urgency_source from public.team_offers() o join ipa1_req r on r.id = o.matching_request_id
   where r.last_name = 'IPA1B'),
  'mittel:referrer_stated', 'team_offers returns the level with its source');
select is(
  (select o.referrer_requested_start - pg_temp.today() from public.team_offers() o join ipa1_req r on r.id = o.matching_request_id
   where r.last_name = 'IPA1B'),
  5, 'team_offers returns the referrer''s requested date');
select is(
  (select o.requested_start - pg_temp.today() from public.team_offers() o join ipa1_req r on r.id = o.matching_request_id
   where r.last_name = 'IPA1B'),
  1, 'the intake fact requested_start stays a separate value');
select is(
  (select string_agg(r.last_name, ',' order by o.ord) from
     (select matching_request_id, row_number() over () as ord from public.team_offers()
      where team_id = '00000000-0000-4000-a000-000000000101') o
   join ipa1_req r on r.id = o.matching_request_id),
  'IPA1A,IPA1B,IPA1C,IPA1D',
  'G3 unchanged: level first, then deadline and age; neither the source nor the referrer''s date moves an offer');
select is(
  (select array_agg(a order by a) from unnest((select proargnames from pg_proc where oid = 'public.team_offers()'::regprocedure)) a
   where a in ('first_name', 'last_name', 'client_name', 'name', 'address', 'phone')),
  null, 'offers still carry no client identity');
reset role;

-- G3 reads neither new column: the ORDER BY of team_offers names only the level, the deadline and the age.
select ok(
  (select pg_get_functiondef('public.team_offers()'::regprocedure)
     ~ 'order by case m\.urgency when ''hoch'' then 0 when ''mittel'' then 1 else 2 end, m\.response_due_at nulls last, m\.created_at;'),
  'the ORDER BY of team_offers is the 0034 rule, unchanged');
select ok(position('LEAVE1-3' in (select prosrc from pg_proc where oid = 'public.team_offers()'::regprocedure)) > 0,
  'team_offers keeps the LEAVE1-3 access guard (a person whose access ended reads no offer)');
select ok(
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname in ('public', 'private')
                and p.prosrc ~ 'referrer_requested_start'
                and p.proname not in ('record_partner_request', 'team_offers', 'case_takes_request_provenance',
                                      'matching_takes_case_provenance')),
  'IPA1-8: no other function reads the referrer''s date (no order, filter, escalation or deadline)');

select * from finish();
rollback;
