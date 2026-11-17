-- BK-c3 reasons on the team's own offer list (brief `docs/agents/briefs/BK.md` §PO amendment 2026-11-17 17:39;
-- ADR-201; draft `docs/engineering/probes/BK-c3_ADR_DRAFT.md`). Red first (FE-071 (2)): on `recovery/main` `33353d4`
-- `private.order_offer_reasons` and the column `team_order_offers().reasons` do not exist.
--
-- What it guards (each line names its source):
--   * PO 17:39 (1) / criterion (1): each clause appears with its stored fact and is absent without it.
--       `member_free`  at least one active member of the team is at step 4 of `private.order_member_step` now.
--       `knows_client` an ended, acknowledged, never released take of the SAME team for the same client account
--                      (PO 17:39 (3); no time window in Phase A).
--   * criterion (5) / CGR-236 (c): a released take, a never acknowledged take and a take of a not-ended slot give no
--     `knows_client`.
--   * PO 17:39 (4) / CGR-236 (b): `holds_all_tags` is dropped (step 2 checks evidence only for «E» cells, not for a
--     «D» tag; migration 0133 `private.member_activity_ok`), so no such code is ever returned.
--   * criterion (2) / AUT-128 / V-8: the (order, team) rows of `team_order_offers()` equal the current-round offer
--     rows minus the team's declines; reasons never add or remove a row.
--   * criterion (3): no rank, score, count, points, position or percent column.
--   * criterion (4): another team and the client read no reason (no other team's row; `client_orders()` has no
--     reason column).
--   * criterion (6): list order A (`starts_at`, then ids; PO 17:39 (2), CGR-236 (a)); reasons never reorder.
-- Not here: the words (vitest `tests/unit/bk-c3-offer-reasons.test.ts`), the card (Playwright, same PR).
--
-- Users: kundebs …9e8 (client). Fixture: T1 (M1, M2), T2 (M3, M4), T3 (M5, M6), T4 (M7, no grade evidence); all in
-- postcode 4102, 10 km; FaGe. Pinned clock, moved forward only. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.clock(ts text) returns void language sql as $$ select set_config('navora.test_now', ts, true) $$;
select pg_temp.clock('2026-11-16 12:00:00+01');
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b146-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a146-0000000000' || n)::uuid $$;
create function pg_temp.out_cols(fn text) returns setof text language sql as $$
  select n from pg_proc p, unnest(p.proargnames, p.proargmodes) as a(n, m)
  where p.oid = fn::regprocedure and a.m = 't'
$$;

-- 0. The new surface (non-aborting checks first) --------------------------------------------------------------------
select has_function('private', 'order_offer_reasons', array['uuid', 'uuid'], 'BK-c3: private.order_offer_reasons exists');
select is((select count(*)::int from pg_temp.out_cols('public.team_order_offers()') c where c = 'reasons'), 1,
          'BK-c3: team_order_offers() returns a reasons column');
select is((select count(*)::int from pg_temp.out_cols('public.team_order_offers()') c
           where c ~* '(rank|score|count|points|position|percent|weight)'), 0,
          'criterion (3): no rank, score, count, points, position, percent or weight column');
select is((select count(*)::int from pg_temp.out_cols('public.client_orders()') c where c ~* 'reason'), 0,
          'criterion (4) / D-44 (2) (a): the client read model carries no reason');

-- 1. Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a000-0000000003ce', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-c3 Fixture (synthetisch)', 'household');
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a000-0000000003ce', '00000000-0000-4000-a000-0000000009e8');
insert into public.teams (organization_id, id, name, region, status, max_distance_km)
  select '00000000-0000-4000-b000-000000000019', pg_temp.t(n), 'BK-c3 Fixture T' || n, 'Basel-Landschaft', 'active', 10
  from unnest(array['01', '02', '03', '04']) n;
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b146-%';
insert into auth.users (id, aud, role, email)
  select pg_temp.m(n), 'authenticated', 'authenticated', 'bk-c3-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03', '04', '05', '06', '07']) n;
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', pg_temp.m(n), 'nurse'
  from unnest(array['01', '02', '03', '04', '05', '06', '07']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.t('01'), pg_temp.m('01'), 'care_assistant'), (pg_temp.t('01'), pg_temp.m('02'), 'care_assistant'),
  (pg_temp.t('02'), pg_temp.m('03'), 'care_assistant'), (pg_temp.t('02'), pg_temp.m('04'), 'care_assistant'),
  (pg_temp.t('03'), pg_temp.m('05'), 'care_assistant'), (pg_temp.t('03'), pg_temp.m('06'), 'care_assistant'),
  (pg_temp.t('04'), pg_temp.m('07'), 'care_assistant');
-- M7 has no grade evidence: T4 has no member at step 4 for any order.
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', pg_temp.m(n), 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02', '03', '04', '05', '06']) n;

-- 2. Earlier orders for the same client account (FaGe, C1, 08:00 – 12:00) ----------------------------------------------
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
create function pg_temp.co(k text, d date, key text) returns void language sql as $$
  insert into made select k, public.confirm_client_order('00000000-0000-4000-a000-0000000003ce', d, time '08:00', time '12:00',
                                                         '4102', 'fage_efz', array['C1'], array['C1'], null, key::uuid)
$$;
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select pg_temp.co('p1', date '2026-11-18', 'dddd0000-0000-4000-8146-000000000001');  -- T1 self-named, ends: knows_client
select pg_temp.co('p2', date '2026-11-19', 'dddd0000-0000-4000-8146-000000000002');  -- T2 colleague «Ich kann nicht»: released
select pg_temp.co('p3', date '2026-11-20', 'dddd0000-0000-4000-8146-000000000003');  -- T3 colleague never acknowledges
select pg_temp.co('n1', date '2026-11-28', 'dddd0000-0000-4000-8146-000000000004');  -- T2 self-named, not ended at the read
reset role;
select pg_temp.as_owner();

create function pg_temp.take(actor text, k text, team text, member text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.take_order(pg_temp.oid(k), pg_temp.t(team), pg_temp.m(member), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.cannot(actor text, k text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.release_named_take(pg_temp.oid(k), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;
create function pg_temp.decline(actor text, k text, team text, key text) returns jsonb language plpgsql as $$
declare res jsonb;
begin
  perform pg_temp.act_as(pg_temp.m(actor)::text);
  set local role authenticated;
  res := public.decline_order(pg_temp.oid(k), pg_temp.t(team), key::uuid);
  reset role;
  perform pg_temp.as_owner();
  return res;
end;
$$;

select is(
  array[pg_temp.take('01', 'p1', '01', '01', 'ffff0000-0000-4000-8146-000000000001') ->> 'result',
        pg_temp.take('03', 'p2', '02', '04', 'ffff0000-0000-4000-8146-000000000002') ->> 'result',
        pg_temp.cannot('04', 'p2', 'ffff0000-0000-4000-8146-000000000003') ->> 'result',
        pg_temp.take('05', 'p3', '03', '06', 'ffff0000-0000-4000-8146-000000000004') ->> 'result',
        pg_temp.take('03', 'n1', '02', '03', 'ffff0000-0000-4000-8146-000000000005') ->> 'result'],
  array['ok', 'ok', 'ok', 'ok', 'ok'],
  'precondition: T1 takes p1 (self); T2 takes p2 naming M4, who says «Ich kann nicht»; T3 takes p3 naming M6; T2 takes n1 (self)');

-- 3. Later: p1 to p3 have ended; two open orders for the same client (ol confirmed first, starts later) -----------------
select pg_temp.clock('2026-11-21 12:00:00+01');
select pg_temp.act_as('00000000-0000-4000-a000-0000000009e8');
set local role authenticated;
select pg_temp.co('ol', date '2026-11-26', 'dddd0000-0000-4000-8146-000000000011');
select pg_temp.co('oe', date '2026-11-24', 'dddd0000-0000-4000-8146-000000000012');
reset role;
select pg_temp.as_owner();
select is((select array_agg(o.team_id order by o.team_id) from public.order_offers o
           where o.order_id = pg_temp.oid('oe') and o.round = private.order_round(o.order_id)
             and o.team_id::text like '00000000-0000-4000-b146-%'),
          array[pg_temp.t('01'), pg_temp.t('02'), pg_temp.t('03')], 'precondition: oe is offered to T1, T2, T3 (not T4)');
select ok((select (t.acknowledged_at is null and t.released_at is null) or t.release_reason = 'not_acknowledged'
           from public.order_takes t where t.order_id = pg_temp.oid('p3') order by t.taken_at desc limit 1),
          'precondition: the p3 take was never acknowledged');
select is(pg_temp.decline('05', 'ol', '03', 'ffff0000-0000-4000-8146-000000000020') ->> 'result', 'ok', 'precondition: T3 declines ol');

-- Capture what one member reads, in the returned order.
create temp table seen (member text, n bigint, order_id uuid, team_id uuid, offer_state text, reasons text[]);
grant all on seen to authenticated;
create function pg_temp.look(member text) returns void language plpgsql as $$
begin
  delete from seen where seen.member = $1;
  perform pg_temp.act_as(pg_temp.m(member)::text);
  set local role authenticated;
  insert into seen select member, x.ordinality, x.order_id, x.team_id, x.offer_state, x.reasons
    from public.team_order_offers() with ordinality x
    where x.order_id in (select (r ->> 'order_id')::uuid from made);
  reset role;
  perform pg_temp.as_owner();
end;
$$;
create function pg_temp.rs(member text, k text) returns text[] language sql as $$
  select s.reasons from seen s where s.member = $1 and s.order_id = pg_temp.oid(k)
$$;
select pg_temp.look('01');
select pg_temp.look('03');
select pg_temp.look('05');

-- 4. Clauses: present with the fact, absent without it (criteria (1), (5)) ---------------------------------------------
select is(pg_temp.rs('01', 'oe'), array['member_free', 'knows_client'],
          'criterion (1): T1 has a free member and an ended, acknowledged, never released take for this client');
select is(pg_temp.rs('03', 'oe'), array['member_free'],
          'criterion (5): T2 holds a released take (p2) and a take of a not-ended slot (n1): no knows_client');
select is(pg_temp.rs('05', 'oe'), array['member_free'],
          'criterion (5): T3 holds a take that was never acknowledged (p3): no knows_client');
select is(private.order_offer_reasons(pg_temp.oid('oe'), pg_temp.t('04')), '{}'::text[],
          'criterion (1) negative: no member of T4 is at step 4, so no member_free (and no other fact)');
select is(private.order_offer_reasons(pg_temp.oid('oe'), pg_temp.t('01')), array['member_free', 'knows_client'],
          'the read model and the function agree');
select is((select count(*)::int from seen s, unnest(s.reasons) c where c not in ('member_free', 'knows_client')), 0,
          'PO 17:39 (4)-(6): only the two published codes (no holds_all_tags, language, price or within_reach)');

-- 5. Rows and order (criteria (2), (4), (6)) ----------------------------------------------------------------------------
create function pg_temp.offer_set(member text, team text) returns text[] language sql as $$
  select coalesce(array_agg(o.order_id::text order by o.order_id), '{}') from public.order_offers o
  where o.team_id = pg_temp.t(team) and o.round = private.order_round(o.order_id)
    and o.order_id in (select (r ->> 'order_id')::uuid from made)
    and exists (select 1 from public.partner_requests p where p.id = o.order_id and p.ends_at > private.now())
    and not exists (select 1 from public.order_declines d where d.order_id = o.order_id and d.round = o.round and d.team_id = o.team_id)
    and not exists (select 1 from public.order_takes k where k.order_id = o.order_id and k.released_at is null and k.team_id <> o.team_id)
$$;
select is((select coalesce(array_agg(s.order_id::text order by s.order_id), '{}') from seen s where s.member = '01'),
          pg_temp.offer_set('01', '01'), 'criterion (2) / AUT-128: T1''s rows equal its current-round offers');
select is((select coalesce(array_agg(s.order_id::text order by s.order_id), '{}') from seen s where s.member = '05'),
          pg_temp.offer_set('05', '03'), 'criterion (2): T3''s rows equal its offers minus its decline (ol absent)');
select ok((select count(*) from seen s where s.member = '05' and s.order_id = pg_temp.oid('ol')) = 0,
          'and the declined ol is not read by T3, reasons or not');
select is((select count(*)::int from seen s where (s.member = '01' and s.team_id <> pg_temp.t('01'))
                                              or (s.member = '03' and s.team_id <> pg_temp.t('02'))
                                              or (s.member = '05' and s.team_id <> pg_temp.t('03'))), 0,
          'criterion (4): a member reads only her own team''s rows, so never another team''s reasons');
select is((select array_agg(s.order_id order by s.n) from seen s where s.member = '01'),
          array[pg_temp.oid('oe'), pg_temp.oid('ol')],
          'criterion (6): order A, the earlier shift first (ol was confirmed first; both carry the same reasons)');
select is((select array_agg(s.order_id order by s.n) from seen s where s.member = '03'),
          (select array_agg(s.order_id order by p.starts_at, s.order_id, s.team_id)
           from seen s join public.partner_requests p on p.id = s.order_id where s.member = '03'),
          'criterion (6): T2''s list is ordered by starts_at, then ids');

-- 6. Reasons explain an open offer only -------------------------------------------------------------------------------
select is(pg_temp.take('01', 'oe', '01', '01', 'ffff0000-0000-4000-8146-000000000030') ->> 'result', 'ok', 'M1 takes oe');
select pg_temp.look('01');
select is((select s.offer_state || '/' || cardinality(s.reasons)::text from seen s where s.member = '01' and s.order_id = pg_temp.oid('oe')),
          'taken_by_us/0', 'a taken row carries no reason line (the recommendation explains an open offer)');

select * from finish();
rollback;
