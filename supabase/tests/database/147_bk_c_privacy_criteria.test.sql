-- BK-c privacy criteria (brief `docs/agents/briefs/BK.md` §PO amendment 2026-11-14 00:39 (4) (a), (b), (d) and §PO
-- review 2026-11-17 21:39 point 1; `lca` D-44 G-2, G-3, G-6). Test only: no migration, no grant, no rule changes.
-- Expected green on `recovery/main` `7fccdae` (the PO found no code defect; this file pins what the code already does).
--
-- What it guards:
--   * G-2 (i), (ii): for an order of a `household` client account, no street, contact, name or activity-tag key is an
--     audited key of class `code`; the audited keys the order path writes are all classified; the household's name
--     reaches no audit value. Checked twice: on the audit rows the order path really wrote (confirm, decline, take) and
--     on the trigger column lists of the four tables that path writes (covers update paths not run here).
--   * G-3 (2): before «Übernehmen» no team-side read carries the household's synthetic person name or a `partner_name`
--     key (offer list, take candidates, the order tables under RLS, `partner_requests`, the client reads); positive:
--     after the take the client sees the taking team's name.
--   * G-6: one person U is a client-account member in network A (Testorganisation S, …019) and an active team member in
--     network B (a second simulation organisation made here). Reading used (named in the PR, `lca` may object): as client
--     U reads no team-side row of A (teams, offers, exclusions, takes, declines), although A's teams hold such rows for
--     U's own order; U's team view (B) never lists U's own A order; U's client view lists only U's own account's order,
--     never a B order (not even the one U's B team took) and never another A account's order. Reverse: a client-only
--     user of B reads no team-side row, a member-only user of A reads no client row.
--
-- Users (all made here, synthetic): U …10 (client of HA in A; nurse of B, team TB1), MA1 …11 (TA1), MA2 …12 (TA2),
-- MB2 …13 (TB2), W …14 (client of HB in B only); kundebs …9e8 (seed client) as member of HA2.
-- All in postcode 4102, 10 km, FaGe, activity C1 (the fixture of pgTAP 146). Pinned clock. Synthetic only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(31);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b147-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a147-0000000000' || n)::uuid $$;
create function pg_temp.org_a() returns uuid language sql as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;
create function pg_temp.org_b() returns uuid language sql as $$ select '00000000-0000-4000-b147-0000000000b0'::uuid $$;
create function pg_temp.ha() returns uuid language sql as $$ select '00000000-0000-4000-a147-0000000003a1'::uuid $$;
create function pg_temp.ha2() returns uuid language sql as $$ select '00000000-0000-4000-a147-0000000003a2'::uuid $$;
create function pg_temp.hb() returns uuid language sql as $$ select '00000000-0000-4000-a147-0000000003b1'::uuid $$;
-- The household's display name: a synthetic person name (not a real person). The token is what the scans look for.
create function pg_temp.name_token() returns text language sql as $$ select 'Testperson-Muster' $$;

-- 1. Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.organizations (id, name, simulation) values
  (pg_temp.org_b(), 'Testorganisation BK-c 147 (synthetisches Netzwerk B)', true);
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  (pg_temp.ha(),  pg_temp.org_a(), 'Frieda Testperson-Muster (synthetisch)', 'household'),
  (pg_temp.ha2(), pg_temp.org_a(), 'Haushalt BK-c 147 zweites Konto (synthetisch)', 'household'),
  (pg_temp.hb(),  pg_temp.org_b(), 'Hans Beispiel-Testkunde (synthetisch)', 'household');
insert into auth.users (id, aud, role, email)
  select pg_temp.m(n), 'authenticated', 'authenticated', 'bk-c-147-' || n || '.fixture@navora.test'
  from unnest(array['10', '11', '12', '13', '14']) n;
insert into public.client_account_members (client_account_id, user_id) values
  (pg_temp.ha(), pg_temp.m('10')),
  (pg_temp.ha2(), '00000000-0000-4000-a000-0000000009e8'),
  (pg_temp.hb(), pg_temp.m('14'));
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  (pg_temp.org_a(), pg_temp.t('01'), 'BK-c 147 Team A1', 'Basel-Landschaft', 'active', 10),
  (pg_temp.org_a(), pg_temp.t('02'), 'BK-c 147 Team A2', 'Basel-Landschaft', 'active', 10),
  (pg_temp.org_b(), pg_temp.t('03'), 'BK-c 147 Team B1', 'Basel-Landschaft', 'active', 10),
  (pg_temp.org_b(), pg_temp.t('04'), 'BK-c 147 Team B2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select pg_temp.t(n), '4102' from unnest(array['01', '02', '03', '04']) n;
-- U is an organisation member of B only: the 0129 guard allows a client of A to be a member of another network.
insert into public.organization_memberships (organization_id, user_id, role) values
  (pg_temp.org_b(), pg_temp.m('10'), 'nurse'), (pg_temp.org_a(), pg_temp.m('11'), 'nurse'),
  (pg_temp.org_a(), pg_temp.m('12'), 'nurse'), (pg_temp.org_b(), pg_temp.m('13'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.t('03'), pg_temp.m('10'), 'care_assistant'), (pg_temp.t('01'), pg_temp.m('11'), 'care_assistant'),
  (pg_temp.t('02'), pg_temp.m('12'), 'care_assistant'), (pg_temp.t('04'), pg_temp.m('13'), 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until) values
  (pg_temp.org_b(), pg_temp.m('10'), 'grade', 'fage_efz', 'verified', true, null),
  (pg_temp.org_a(), pg_temp.m('11'), 'grade', 'fage_efz', 'verified', true, null),
  (pg_temp.org_a(), pg_temp.m('12'), 'grade', 'fage_efz', 'verified', true, null),
  (pg_temp.org_b(), pg_temp.m('13'), 'grade', 'fage_efz', 'verified', true, null);

-- 2. Orders, as each client ---------------------------------------------------------------------------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(actor uuid, k text, acct uuid, d date, key text) returns void language plpgsql as $$
begin
  perform pg_temp.act_as(actor::text);
  set local role authenticated;
  insert into made select k, public.confirm_client_order(acct, d, time '08:00', time '12:00', '4102', 'fage_efz',
                                                         array['C1'], array['C1'], null, key::uuid);
  reset role;
  perform pg_temp.as_owner();
end;
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
select pg_temp.co(pg_temp.m('10'), 'oA', pg_temp.ha(), date '2026-11-18', 'dddd0000-0000-4000-8147-000000000001');
select pg_temp.co('00000000-0000-4000-a000-0000000009e8'::uuid, 'oA2', pg_temp.ha2(), date '2026-11-19',
                  'dddd0000-0000-4000-8147-000000000002');
select pg_temp.co(pg_temp.m('14'), 'oB', pg_temp.hb(), date '2026-11-18', 'dddd0000-0000-4000-8147-000000000003');
select pg_temp.co(pg_temp.m('10'), 'xB', pg_temp.hb(), date '2026-11-20', 'dddd0000-0000-4000-8147-000000000004');

create function pg_temp.call(actor text, f text, k text, team text, member text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  if f = 'take' then
    res := public.take_order(pg_temp.oid(k), pg_temp.t(team), pg_temp.m(member), key::uuid);
  else
    res := public.decline_order(pg_temp.oid(k), pg_temp.t(team), key::uuid);
  end if;
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;

select is(array[(select r ->> 'result' from made where k = 'oA'), (select r ->> 'result' from made where k = 'oA2'),
                (select r ->> 'result' from made where k = 'oB'), (select r ->> 'result' from made where k = 'xB')],
          array['ok', 'ok', 'ok', 'rejected'],
          'precondition: U orders for HA, kundebs for HA2, W for HB; U cannot order for HB (not its member)');
select is((select string_agg(case o.order_id when pg_temp.oid('oA') then 'oA' else 'oB' end || ':' || right(o.team_id::text, 2),
                             ', ' order by o.order_id = pg_temp.oid('oB'), o.team_id)
           from public.order_offers o
           where o.order_id in (pg_temp.oid('oA'), pg_temp.oid('oB')) and o.team_id::text like '00000000-0000-4000-b147-%'),
          'oA:01, oA:02, oB:03, oB:04',
          'precondition: oA is offered to TA1 and TA2 (network A), oB to TB1 and TB2 (network B); own network only');

-- 3. Team-side reads, captured as text (G-3 (2)) -----------------------------------------------------------------------
create temp table seen (who text, phase text, src text, body text);
grant all on seen to authenticated;
create function pg_temp.look(member text, phase text) returns void language plpgsql as $$
begin
  perform pg_temp.act_as(pg_temp.m(member)::text);
  set local role authenticated;
  insert into seen select member, phase, 'team_order_offers', to_jsonb(x)::text from public.team_order_offers() x;
  insert into seen select member, phase, 'order_take_candidates', to_jsonb(x)::text
    from (select pg_temp.oid('oA') o, t.id tid from public.teams t where t.id = any (array[pg_temp.t('01'), pg_temp.t('02')])) q
    cross join lateral public.order_take_candidates(q.o, q.tid) x;
  insert into seen select member, phase, 'order_offers', to_jsonb(x)::text from public.order_offers x;
  insert into seen select member, phase, 'order_exclusions', to_jsonb(x)::text from public.order_exclusions x;
  insert into seen select member, phase, 'order_takes', to_jsonb(x)::text from public.order_takes x;
  insert into seen select member, phase, 'order_declines', to_jsonb(x)::text from public.order_declines x;
  insert into seen select member, phase, 'partner_requests', to_jsonb(x)::text from public.partner_requests x;
  insert into seen select member, phase, 'teams', to_jsonb(x)::text from public.teams x;
  insert into seen select member, phase, 'client_orders', to_jsonb(x)::text from public.client_orders() x;
  insert into seen select member, phase, 'my_client_accounts', to_jsonb(x)::text from public.my_client_accounts() x;
  reset role;
  perform pg_temp.as_owner();
end;
$$;
select pg_temp.look('11', 'before_take');
select pg_temp.look('12', 'before_take');

select is((select count(*)::int from seen where who = '11' and src = 'team_order_offers'
           and body like '%' || pg_temp.oid('oA')::text || '%' and body like '%"offer_state": "open"%'), 1,
          'G-3 (2) precondition: TA1 sees the household order oA as an open offer (the scan below is not empty)');
select is((select count(*)::int from seen where who in ('11', '12') and src = 'partner_requests'), 0,
          'G-3 (2): a team member reads no partner_requests row (coordinators only), so never partner_name');
select ok(not has_table_privilege('authenticated', 'public.client_accounts', 'select')
          and not has_table_privilege('authenticated', 'public.client_account_members', 'select'),
          'G-3 (2): no app role reads client_accounts or client_account_members directly');
select is((select count(*)::int from seen where who in ('11', '12') and phase = 'before_take'
           and body ilike '%' || pg_temp.name_token() || '%'), 0,
          'G-3 (2): no team-side read before the take carries the household''s name');
select is((select count(*)::int from seen where who in ('11', '12') and body ~ '"(partner_name|display_name|partner_type)"'), 0,
          'G-3 (2): no team-side read carries a partner_name, display_name or partner_type key');
select is((select count(*)::int from pg_proc p, unnest(p.proargnames, p.proargmodes) as a(n, md)
           where p.oid = 'public.team_order_offers()'::regprocedure and a.md = 't'
             and a.n ~* '(partner|display_name|client|first_name|last_name)'), 0,
          'G-3 (2): the offer list has no partner, name or client column');
select is((select string_agg(p.proname, ', ' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
             and p.prosrc ~ 'order_(offers|takes|declines|exclusions)' and p.prosrc ~ '(partner_name|display_name)'), null,
          'G-3 (2): no app-callable function that reads the order tables touches partner_name or display_name');

-- 4. Decline (TA2) and take (TA1, self-named) of the household order; the client then sees the taking team --------------
select is(array[pg_temp.call('12', 'decline', 'oA', '02', null, 'ffff0000-0000-4000-8147-000000000001') ->> 'result',
                pg_temp.call('11', 'take', 'oA', '01', '11', 'ffff0000-0000-4000-8147-000000000002') ->> 'result',
                pg_temp.call('13', 'decline', 'oB', '04', null, 'ffff0000-0000-4000-8147-000000000003') ->> 'result',
                pg_temp.call('10', 'take', 'oB', '03', '10', 'ffff0000-0000-4000-8147-000000000004') ->> 'result'],
          array['ok', 'ok', 'ok', 'ok'],
          'precondition: TA2 declines oA, TA1 takes oA (self); TB2 declines oB, U takes oB for TB1 (self)');
select pg_temp.look('12', 'after_take');
select is((select count(*)::int from seen where who = '12' and phase = 'after_take' and body ilike '%' || pg_temp.name_token() || '%'), 0,
          'G-3 (2): the team that declined still reads no household name after the take');

create function pg_temp.client_view(actor uuid) returns table (id uuid, cover_state text, covered_team_name text)
language plpgsql as $$
begin
  perform pg_temp.act_as(actor::text);
  set local role authenticated;
  return query select x.id, x.cover_state, x.covered_team_name from public.client_orders() x;
  reset role;
  perform pg_temp.as_owner();
end;
$$;
create temp table cview as select pg_temp.m('10') as who, v.* from pg_temp.client_view(pg_temp.m('10')) v;
insert into cview select pg_temp.m('14'), v.* from pg_temp.client_view(pg_temp.m('14')) v;
insert into cview select pg_temp.m('11'), v.* from pg_temp.client_view(pg_temp.m('11')) v;
reset role;
select pg_temp.as_owner();
select is((select c.cover_state || ' / ' || c.covered_team_name from cview c where c.who = pg_temp.m('10') and c.id = pg_temp.oid('oA')),
          'covered / BK-c 147 Team A1', 'G-3 (2) positive: after the take the client sees the taking team');

-- 5. The audit keys of the household order (G-2 (i), (ii)) -----------------------------------------------------------
create temp table ents as
  select pg_temp.oid('oA') as id union select pg_temp.ha()
  union select k.id from public.order_takes k where k.order_id = pg_temp.oid('oA')
  union select d.id from public.order_declines d where d.order_id = pg_temp.oid('oA');
create temp table ak as
  select distinct e.table_name, k.key
  from public.audit_events e cross join lateral jsonb_object_keys(e.changed) k(key)
  where e.entity_id in (select id from ents);
create function pg_temp.forbidden() returns text language sql as $$
  select '(street|strasse|address|adress|contact|kontakt|phone|telefon|mail|activity|tag|name|city|place|summary|title|note|text)'
$$;

select is((select array_agg(distinct table_name order by table_name) from ak),
          array['client_accounts', 'order_declines', 'order_takes', 'partner_requests']::text[],
          'G-2 precondition: the household order path wrote audit rows for the account, the order, the decline and the take');
select is((select string_agg(a.table_name || '.' || a.key, ', ') from ak a
           where not exists (select 1 from private.audit_value_classes v where v.table_name = a.table_name and v.key = a.key)),
          null, 'G-2: every audited key of the household order path is classified');
select is((select string_agg(a.table_name || '.' || a.key, ', ') from ak a
           join private.audit_value_classes v on v.table_name = a.table_name and v.key = a.key
           where v.class = 'code' and a.key ~* pg_temp.forbidden()),
          null, 'G-2 (i), (ii): no street, contact, name or activity-tag key is audited as class code for a household order');
select is((select string_agg(a.table_name || '.' || a.key, ', ') from ak a
           where a.key in ('activity_tags', 'required_tags', 'partner_name', 'display_name', 'city', 'need_summary', 'request_title')),
          null, 'G-2 (ii): the activity tags, the name, the place and the order sentence are not audited at all');
select is((select count(*)::int from public.audit_events e where e.entity_id in (select id from ents)
           and e.changed::text ilike '%' || pg_temp.name_token() || '%'), 0,
          'G-2: the household''s name reaches no audit value');
select is((select string_agg(distinct c.relname || '.' || a.col, ', ')
           from pg_trigger t
           join pg_proc p on p.oid = t.tgfoid and p.proname = 'write_audit_event'
           join pg_class c on c.oid = t.tgrelid
           cross join lateral unnest(string_to_array(rtrim(encode(t.tgargs, 'escape'), '\000'), '\000')) a(col)
           left join private.audit_value_classes v on v.table_name = c.relname and v.key = a.col
           where not t.tgisinternal
             and c.relname in ('partner_requests', 'client_accounts', 'order_takes', 'order_declines')
             and (a.col in ('activity_tags', 'required_tags', 'partner_name', 'display_name', 'city', 'need_summary', 'request_title')
                  or (coalesce(v.class, 'code') = 'code' and a.col ~* pg_temp.forbidden()))),
          null, 'G-2 (i), (ii): the audit trigger column lists of the order path (all update paths) hold no such key as code');
select is((select count(*)::int from private.audit_value_classes v
           where v.class = 'code' and (v.table_name, v.key) in (('client_accounts', 'display_name'), ('partner_requests', 'partner_name'),
                                                                ('partner_requests', 'city'), ('partner_requests', 'activity_tags'))), 0,
          'G-2: a household name, place or activity tag is never catalogued as code (a future name key is free_text)');

-- 6. Role separation across networks (G-6) ----------------------------------------------------------------------------
select ok(exists (select 1 from public.organization_memberships where organization_id = pg_temp.org_b() and user_id = pg_temp.m('10'))
          and exists (select 1 from public.team_memberships where team_id = pg_temp.t('03') and user_id = pg_temp.m('10'))
          and exists (select 1 from public.client_account_members where client_account_id = pg_temp.ha() and user_id = pg_temp.m('10'))
          and not exists (select 1 from public.organization_memberships where organization_id = pg_temp.org_a() and user_id = pg_temp.m('10')),
          'G-6 precondition: U is a client of HA (network A) and a team member of TB1 (network B), not a member of A');
select ok((select count(*) from public.order_offers where order_id = pg_temp.oid('oA')) > 0
          and (select count(*) from public.order_takes where order_id = pg_temp.oid('oA')) > 0
          and (select count(*) from public.order_declines where order_id = pg_temp.oid('oA')) > 0,
          'G-6 precondition: network A holds offers, a take and a decline for U''s own order');

select pg_temp.look('10', 'g6');
select pg_temp.look('14', 'g6');
select pg_temp.look('11', 'g6');
create function pg_temp.org_of(body text) returns uuid language sql immutable as $$
  select nullif(body::jsonb ->> 'organization_id', '')::uuid
$$;
select is((select count(*)::int from seen where who = '10' and phase = 'g6'
           and src in ('teams', 'order_offers', 'order_exclusions', 'order_takes', 'order_declines')
           and pg_temp.org_of(body) = pg_temp.org_a()), 0,
          'G-6: as client of A, U reads no team, offer, exclusion, take or decline row of network A (not even for the own order)');
select ok((select count(*) from seen where who = '10' and phase = 'g6' and src = 'order_takes'
           and body like '%' || pg_temp.oid('oB')::text || '%') = 1,
          'G-6 positive: as member of TB1, U reads the own team''s take of oB in network B');
select is((select coalesce(array_agg(distinct (body::jsonb ->> 'order_id')::uuid), '{}') from seen
           where who = '10' and phase = 'g6' and src = 'team_order_offers'
             and (body::jsonb ->> 'order_id')::uuid in (select (r ->> 'order_id')::uuid from made where r ? 'order_id')),
          array[pg_temp.oid('oB')], 'G-6: U''s team view lists the B order only, never U''s own A order');
select is((select array_agg(c.id order by c.id) from cview c where c.who = pg_temp.m('10')),
          array[pg_temp.oid('oA')], 'G-6: U''s client view lists only the own account''s order (no B order, no other A account)');
select is((select array_agg((body::jsonb ->> 'id')::uuid) from seen where who = '10' and phase = 'g6' and src = 'my_client_accounts'),
          array[pg_temp.ha()], 'G-6: U''s client accounts are HA only');
select is(array[pg_temp.call('10', 'take', 'oA', '03', '10', 'ffff0000-0000-4000-8147-000000000010') ->> 'reason',
                pg_temp.call('10', 'take', 'oA', '01', '10', 'ffff0000-0000-4000-8147-000000000011') ->> 'reason'],
          array['not_offered', 'not_team_member'],
          'G-6: U cannot take the own A order, neither for the B team nor for an A team');
select is((select count(*)::int from seen where who = '14' and phase = 'g6'
           and src in ('teams', 'order_offers', 'order_exclusions', 'order_takes', 'order_declines', 'team_order_offers')), 0,
          'G-6 reverse: a client-only user of B reads no team-side row at all');
select is((select array_agg(c.id) from cview c where c.who = pg_temp.m('14')), array[pg_temp.oid('oB')],
          'G-6 reverse: the B client sees the own order only');
select is((select count(*)::int from cview c where c.who = pg_temp.m('11')), 0,
          'G-6 reverse: a member-only user of A reads no client_orders() row of A');
select is((select count(*)::int from seen where who = '11' and phase = 'g6' and src = 'my_client_accounts'), 0,
          'G-6 reverse: and no client account');

select * from finish();
rollback;
