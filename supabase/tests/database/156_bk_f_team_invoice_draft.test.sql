-- BK-f, contract 2026-11-20 06:39 points 2 (b)–(g), (i), (j) and 5 (migration 0156): the invoice draft from the take
-- team to the client, built from the signed report.
-- Guards:
--   * positive: the carer signs a take report → one draft without any input; minutes from the signed snapshot, price
--     from the take snapshot, amount exact to 2 decimals; the report version and its snapshot hash are named; a member
--     of the take team sends it; the client reads its sent invoice (no member name, no tag);
--   * negative: no tolerance row → refused `no_tolerance` (and the report stays final); not final → `not_signed`;
--     second draft → `already_drafted`; outside the tolerance → `times_disagree`; open hold → `on_hold`; team without a
--     price → `no_price`; a failing build stores `build_failed` and leaves the report final; a correction voids the sent
--     invoice and a new draft is built; the client sees the void;
--   * permission: another team's member, a client-only user and anon cannot send; the client sees nothing before
--     «gesendet» and nothing of another client account; app roles read no invoice, tolerance or stop-rule row directly;
--     a client-only user reads no tariff_rates or billing_rules row (G-6);
--   * schema: no commission, percent, fee, IBAN, payment or paid column (FE-078); only allowed transitions; no delete.
-- The tolerance value 15 below is a pgTAP test parameter inserted as the table owner inside this rolled-back transaction;
-- it is not the lca simulation value (contract point 2 (d)) and is not shipped by any migration.
-- Fixture: organisation 019, T1 (M1, M3), T2 (M2, no price), client kundebs …9e8 (account …3cb), a second client C2
-- (account …3cc), postcode 4102. Synthetic data only; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(52);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
create function pg_temp.t(n text) returns uuid language sql as $$ select ('00000000-0000-4000-b156-0000000000' || n)::uuid $$;
create function pg_temp.m(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a156-0000000000' || n)::uuid $$;
create function pg_temp.key(n int) returns uuid language sql as $$ select ('eeee0000-0000-4000-8156-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.client() returns text language sql as $$ select '00000000-0000-4000-a000-0000000009e8' $$;
create function pg_temp.acct() returns uuid language sql as $$ select '00000000-0000-4000-a156-0000000003cb'::uuid $$;
-- Runs one statement as a user; returns its jsonb result, or the SQLSTATE as {"sqlstate": …}.
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r;
exception when others then
  execute 'reset role';
  perform pg_temp.as_owner();
  return jsonb_build_object('sqlstate', sqlstate);
end $$;

-- 0. Surface and FE-078 ------------------------------------------------------------------------------------------------
select has_table('public', 'team_invoice_drafts', 'BK-9: the invoice draft table exists');
select has_table('public', 'invoice_time_tolerances', 'BK-9n: the tolerance configuration table exists');
select is((select count(*)::int from public.invoice_time_tolerances), 0,
  'contract 2 (d): no migration ships a tolerance value (lca names it at the gate)');
select is((select count(*)::int from information_schema.columns
           where table_schema = 'public' and table_name = 'team_invoice_drafts'
             and column_name ~* '(commission|percent|fee|navora_|iban|payment|paid)'), 0,
  'FE-078: no commission, percent, NAVORA fee, IBAN, payment or paid column on team_invoice_drafts');
select ok(position('member' in pg_get_function_result('public.client_invoices()'::regprocedure)) = 0
          and position('tag' in pg_get_function_result('public.client_invoices()'::regprocedure)) = 0,
  'CGR-210 (c): the client view returns no member name and no tag');

-- 1. Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into public.client_accounts (id, organization_id, display_name, client_kind) values
  ('00000000-0000-4000-a156-0000000003cb', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-f Rechnung (synthetisch)', 'household'),
  ('00000000-0000-4000-a156-0000000003cc', '00000000-0000-4000-b000-000000000019', 'Haushalt BK-f Andere (synthetisch)', 'household');
insert into auth.users (id, aud, role, email)
  select pg_temp.m(n), 'authenticated', 'authenticated', 'bk-f-invoice-' || n || '.fixture@navora.test'
  from unnest(array['01', '02', '03', 'c2']) n;
insert into public.client_account_members (client_account_id, user_id) values
  ('00000000-0000-4000-a156-0000000003cb', '00000000-0000-4000-a000-0000000009e8'),
  ('00000000-0000-4000-a156-0000000003cc', '00000000-0000-4000-a156-0000000000c2');
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b156-000000000001', 'BK-f Rechnung T1', 'Basel-Landschaft', 'active', 10),
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b156-000000000002', 'BK-f Rechnung T2', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode)
  select t.id, '4102' from public.teams t where t.id::text like '00000000-0000-4000-b156-%';
insert into public.organization_memberships (organization_id, user_id, role)
  select '00000000-0000-4000-b000-000000000019', pg_temp.m(n), 'nurse' from unnest(array['01', '02', '03']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b156-000000000001', '00000000-0000-4000-a156-000000000001', 'care_assistant'),
  ('00000000-0000-4000-b156-000000000002', '00000000-0000-4000-a156-000000000002', 'care_assistant'),
  ('00000000-0000-4000-b156-000000000001', '00000000-0000-4000-a156-000000000003', 'care_assistant');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019', pg_temp.m(n), 'grade', 'fage_efz', 'verified', true, null
  from unnest(array['01', '02', '03']) n;

select is(pg_temp.cmd(pg_temp.m('01')::text, format('select public.set_team_price(%L, 72.00, %L)', pg_temp.t('01'), pg_temp.key(1))) ->> 'result',
  'ok', 'T1 sets its own price (Beispielwert, kein Tarif)');

-- Orders: o1 19.11., o2 20.11., o3 21.11., o4 22.11. (T1, M1), o5 20.11. (T2, M2); each 08:00–12:00 = 240 minutes.
create temp table made (k text primary key, r jsonb);
grant all on made to authenticated;
insert into made
  select 'o' || n, pg_temp.cmd(pg_temp.client(), format(
    'select public.confirm_client_order(%L, %L::date, time ''08:00'', time ''12:00'', ''4102'', ''fage_efz'', array[''C1''], array[''C1''], null, %L)',
    pg_temp.acct(), d, pg_temp.key(10 + n)))
  from (values (1, '2026-11-19'), (2, '2026-11-20'), (3, '2026-11-21'), (4, '2026-11-22'), (5, '2026-11-20')) x(n, d);
create function pg_temp.oid(k text) returns uuid language sql as $$ select (r ->> 'order_id')::uuid from made where made.k = $1 $$;
select is((select count(*)::int from made where pg_temp.oid(k) is not null), 5, 'the client confirms five synthetic orders');
create function pg_temp.take(actor text, k text, team text, n int) returns text language sql as $$
  select pg_temp.cmd(pg_temp.m(actor)::text, format('select public.take_order(%L, %L, %L, %L)',
    pg_temp.oid(k), pg_temp.t(team), pg_temp.m(actor), pg_temp.key(n))) ->> 'result' $$;
select is(pg_temp.take('01', 'o1', '01', 21) || pg_temp.take('01', 'o2', '01', 22) || pg_temp.take('01', 'o3', '01', 23)
          || pg_temp.take('01', 'o4', '01', 24) || pg_temp.take('02', 'o5', '02', 25), 'okokokokok',
  'M1 takes o1–o4 for T1, M2 takes o5 for T2 (each names herself)');
create function pg_temp.vid(k text) returns uuid language sql as $$
  select v.id from public.care_visits v join public.order_takes t on t.id = v.order_take_id
  where t.order_id = pg_temp.oid(k) and t.released_at is null $$;

-- F1–F4 instants written as the table owner (pattern pgTAP 148 section 14), then a draft report by the performer.
create function pg_temp.worked(k text, performer text, d text, s text, e text, n int) returns uuid language plpgsql as $$
declare v uuid := pg_temp.vid(k); rid uuid := ('a1560000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid;
begin
  insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
  select cv.organization_id, cv.id, cv.team_id, x.kind, x.f, x.t, pg_temp.m(performer), x.at
  from public.care_visits cv,
       (values ('departed', 'planned', 'on_the_way', (d || ' ' || s || '+01')::timestamptz - interval '20 minutes', 0),
               ('started', 'on_the_way', 'started', (d || ' ' || s || '+01')::timestamptz, 1),
               ('completed', 'started', 'completed', (d || ' ' || e || '+01')::timestamptz, 2)) as x(kind, f, t, at, o)
  where cv.id = v order by x.o;
  insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot,
                                    performer_id, countersign_required, created_by)
  select cv.organization_id, rid, cv.id, null, cv.team_id, 1, 'draft', private.visit_report_snapshot(cv.id),
         pg_temp.m(performer), false, pg_temp.m(performer)
  from public.care_visits cv where cv.id = v;
  return rid;
end $$;
create function pg_temp.sign(performer text, rid uuid, n int) returns text language sql as $$
  select pg_temp.cmd(pg_temp.m(performer)::text, format('select public.sign_report(%L, %L, %L)', rid,
    (select private.report_snapshot_hash(private.visit_report_snapshot(r.visit_id)) from public.visit_reports r where r.id = rid),
    pg_temp.key(n))) ->> 'result' $$;
create function pg_temp.last(k text) returns public.team_invoice_drafts language sql as $$
  select d.* from public.team_invoice_drafts d where d.visit_id = pg_temp.vid(k) order by d.seq desc limit 1 $$;
create function pg_temp.live(k text) returns public.team_invoice_drafts language sql as $$
  select d.* from public.team_invoice_drafts d where d.visit_id = pg_temp.vid(k) and d.state in ('draft', 'sent') $$;
create function pg_temp.status(rid uuid) returns text language sql as $$ select status from public.visit_reports where id = rid $$;

create temp table rep (k text primary key, id uuid);
insert into rep values
  ('o1', pg_temp.worked('o1', '01', '2026-11-19', '08:02', '12:00', 1)),   -- 238 minutes
  ('o2', pg_temp.worked('o2', '01', '2026-11-20', '08:00', '11:00', 2)),   -- 180 minutes
  ('o3', pg_temp.worked('o3', '01', '2026-11-21', '08:00', '12:00', 3)),
  ('o4', pg_temp.worked('o4', '01', '2026-11-22', '08:00', '12:00', 4)),
  ('o5', pg_temp.worked('o5', '02', '2026-11-20', '08:00', '12:00', 5));
create function pg_temp.r(k text) returns uuid language sql as $$ select id from rep where rep.k = $1 $$;

-- 2. No tolerance row: the signature stands, the draft is refused visibly ------------------------------------------------
select is(pg_temp.sign('01', pg_temp.r('o1'), 31), 'ok', 'M1 signs the o1 take report');
select is(pg_temp.status(pg_temp.r('o1')), 'final', 'the signed take report is final');
select is((pg_temp.last('o1')).refusal_reason, 'no_tolerance', 'contract 2 (d): no tolerance row → refused no_tolerance, no draft');
select is((select count(*)::int from public.team_invoice_drafts where visit_id = pg_temp.vid('o1') and state = 'draft'), 0,
  'no draft without a tolerance row');

-- pgTAP test parameter (not the lca value): 15 minutes.
insert into public.invoice_time_tolerances (key, tolerance_minutes, lca_ref) values ('take_invoice', 15, 'pgTAP 156 test parameter');

-- 3. Not final → not_signed --------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.m('01')::text, format('select public.build_team_invoice_draft(%L, %L)', pg_temp.r('o3'), pg_temp.key(40))) ->> 'reason',
  'not_signed', 'BK-8n: a report that is not final gets no draft (not_signed)');

-- 4. Positive: draft built, exact amount ---------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.m('01')::text, format('select public.build_team_invoice_draft(%L, %L)', pg_temp.r('o1'), pg_temp.key(41))) ->> 'state',
  'draft', 'with the tolerance row the take team builds the draft for o1');
select is((pg_temp.last('o1')).recorded_minutes, 238.00::numeric(8,2), 'minutes from the signed snapshot (08:02–12:00 = 238)');
select is((pg_temp.last('o1')).ordered_minutes, 240.00::numeric(8,2), 'ordered minutes from the order (240)');
select is((pg_temp.last('o1')).price_per_hour, 72.00::numeric(8,2), 'price from the take snapshot');
select is((pg_temp.last('o1')).amount_chf, 285.60::numeric(10,2), 'amount = 238 / 60 × 72.00 = 285.60, exact to 2 decimals');
select ok((pg_temp.last('o1')).report_id = pg_temp.r('o1') and (pg_temp.last('o1')).report_version = 1
          and (pg_temp.last('o1')).report_snapshot_hash
              = (select private.report_snapshot_hash(snapshot) from public.visit_reports where id = pg_temp.r('o1')),
  'CGR-210 (a): the draft names the final report version and its snapshot hash');
select is(pg_temp.cmd(pg_temp.m('01')::text, format('select public.build_team_invoice_draft(%L, %L)', pg_temp.r('o1'), pg_temp.key(42))) ->> 'reason',
  'already_drafted', 'BK-9n: a second draft for the same take is refused');
select is((select count(*)::int from public.team_invoice_drafts where take_id = (pg_temp.last('o1')).take_id and state in ('draft', 'sent')), 1,
  'one live draft per take');
select is((select count(*)::int from public.audit_events where entity_id = (pg_temp.live('o1')).id), 1,
  'the draft wrote one audit row');

-- 5. Permission before sending -------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.client(), 'select count(*)::int from public.client_invoices()')::int, 0,
  'the client sees nothing before «gesendet»');
select is(pg_temp.cmd(pg_temp.m('02')::text, format('select public.send_team_invoice_draft(%L, %L)', (pg_temp.live('o1')).id, pg_temp.key(50))) ->> 'result',
  'rejected', 'a member of another team cannot send T1''s draft');
select is(pg_temp.cmd(pg_temp.client(), format('select public.send_team_invoice_draft(%L, %L)', (pg_temp.live('o1')).id, pg_temp.key(51))) ->> 'result',
  'rejected', 'a client-only user cannot send a draft');
select throws_ok(format($$ set local role anon; select public.send_team_invoice_draft(%L, gen_random_uuid()) $$, (pg_temp.live('o1')).id),
  '42501', null, 'anon cannot call send_team_invoice_draft');
reset role;
select is(pg_temp.cmd(pg_temp.m('03')::text, 'select string_agg(coalesce(refusal_reason, state), '','' order by visit_date) from public.my_team_invoice_drafts()') #>> '{}',
  'draft,not_signed', 'a colleague in the take team sees the o1 draft and the newest o3 refusal on /team (not the replaced o1 refusal)');
select is(pg_temp.cmd(pg_temp.m('02')::text, 'select count(*)::int from public.my_team_invoice_drafts()')::int, 0,
  'another team sees no T1 invoice row');

-- 6. Send, client read ----------------------------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.m('03')::text, format('select public.send_team_invoice_draft(%L, %L)', (pg_temp.live('o1')).id, pg_temp.key(52))) ->> 'result',
  'ok', 'an active member of the take team confirms and sends (one tap)');
select ok((pg_temp.live('o1')).state = 'sent' and (pg_temp.live('o1')).sent_by = pg_temp.m('03'),
  'the invoice is sent and names the confirming person');
select is(pg_temp.cmd(pg_temp.client(), 'select jsonb_agg(jsonb_build_object(''a'', amount_chf, ''h'', hours, ''p'', price_per_hour, ''t'', team_name, ''s'', state)) from public.client_invoices()'),
  '[{"a": 285.60, "h": 3.97, "p": 72.00, "t": "BK-f Rechnung T1", "s": "sent"}]'::jsonb,
  'the client reads its sent invoice: hours, price, amount, team name, state');
select is(pg_temp.cmd(pg_temp.m('c2')::text, 'select count(*)::int from public.client_invoices()')::int, 0,
  'another client account sees nothing');
select is(pg_temp.cmd(pg_temp.m('03')::text, format('select public.send_team_invoice_draft(%L, %L)', (pg_temp.live('o1')).id, pg_temp.key(53))) ->> 'reason',
  'not_draft', 'a sent invoice is not sent twice');

-- 7. Correction voids the sent invoice; a new draft is built (CGR-210 (b)) -------------------------------------------------
create temp table corr (id uuid);
grant all on corr to authenticated;
insert into corr select (pg_temp.cmd(pg_temp.m('01')::text, format('select public.correct_report(%L, %L, null, %L)',
  pg_temp.r('o1'), 'Korrektur Testfall', pg_temp.key(60))) ->> 'report_id')::uuid;
select is(pg_temp.sign('01', (select id from corr), 61), 'ok', 'M1 signs the correction');
select is((select state || '/' || void_reason from public.team_invoice_drafts where visit_id = pg_temp.vid('o1') and sent_at is not null),
  'void/report_corrected', 'the correction voided the sent invoice in the same transaction');
select ok((pg_temp.last('o1')).state = 'draft' and (pg_temp.last('o1')).report_id = (select id from corr)
          and (pg_temp.last('o1')).report_version = 2,
  'a new draft is built from the corrected final version');
select is(pg_temp.cmd(pg_temp.client(), 'select string_agg(state, '','') from public.client_invoices()') #>> '{}', 'void',
  'the client sees the void of the sent invoice (and not the new unsent draft)');

-- 8. Refusals ---------------------------------------------------------------------------------------------------------------
select is(pg_temp.sign('01', pg_temp.r('o2'), 32), 'ok', 'M1 signs o2 (worked 180 of 240 minutes)');
select is((pg_temp.last('o2')).refusal_reason, 'times_disagree', 'BK-9n: outside the tolerance → times_disagree, no draft');
insert into public.quality_holds (organization_id, visit_id, team_id, reason, set_by, idempotency_key)
  values ('00000000-0000-4000-b000-000000000019', pg_temp.vid('o3'), pg_temp.t('01'), 'Testfall Sperre', pg_temp.m('03'), pg_temp.key(70));
select is(pg_temp.sign('01', pg_temp.r('o3'), 33), 'ok', 'M1 signs o3 while a quality hold is open (signature never blocked)');
select is((pg_temp.last('o3')).refusal_reason, 'on_hold', 'an open quality hold → on_hold, no draft');
select is(pg_temp.sign('02', pg_temp.r('o5'), 35), 'ok', 'M2 signs o5 (T2 has no price)');
select is((pg_temp.last('o5')).refusal_reason, 'no_price', 'no NAVORA default: a team without a price → no_price');

-- A failing build: the signature stands and the failure is visible.
alter table public.team_invoice_drafts add constraint pgtap_156_fail_drafts check (state <> 'draft') not valid;
select is(pg_temp.sign('01', pg_temp.r('o4'), 34), 'ok', 'M1 signs o4 while the draft build fails');
select is(pg_temp.status(pg_temp.r('o4')), 'final', 'contract 2 (b): a failing draft build leaves the report final');
select is((pg_temp.last('o4')).refusal_reason, 'build_failed', 'the failed build is stored as build_failed (never silent)');
alter table public.team_invoice_drafts drop constraint pgtap_156_fail_drafts;

-- 9. Table rules and least privilege (G-6) ------------------------------------------------------------------------------------
select throws_ok(format($$ update public.team_invoice_drafts set amount_chf = 1 where id = %L $$, (pg_temp.live('o1')).id),
  '42501', 'team_invoice_drafts: transition not allowed', 'a draft''s amount is never changed');
select throws_ok(format($$ delete from public.team_invoice_drafts where id = %L $$, (pg_temp.live('o1')).id),
  '42501', 'team_invoice_drafts rows are never deleted', 'invoice rows are never deleted');
select is(pg_temp.cmd(pg_temp.client(),
  'select jsonb_build_object(''t'', (select count(*) from public.tariff_rates), ''b'', (select count(*) from public.billing_rules))'),
  '{"t": 0, "b": 0}'::jsonb, 'G-6: a client-only user reads no tariff_rates or billing_rules row');
select is(pg_temp.cmd(pg_temp.client(), 'select count(*) from public.invoice_time_tolerances') ->> 'sqlstate', '42501',
  'G-6: app roles read no tolerance row directly');
select is(pg_temp.cmd(pg_temp.client(), 'select count(*) from public.report_draft_stop_rules') ->> 'sqlstate', '42501',
  'G-6: app roles read no stop-rule row directly');
select is(pg_temp.cmd(pg_temp.m('01')::text, 'select count(*) from public.team_invoice_drafts') ->> 'sqlstate', '42501',
  'app roles read no invoice row directly (only through the definer readers)');

select * from finish();
rollback;
