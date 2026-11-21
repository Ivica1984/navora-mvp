-- HD-2 slice 5 «Auftrag zurückziehen» (brief docs/agents/briefs/HD.md §3 rows A, K, N; PO 2026-11-21 05:39 (1), 06:39;
-- migration 0163). Red on 0162 (no `institution_withdraw_gap_order`, no `withdrawn_at`), green on 0163.
-- Positive: A (offer out, no take) is withdrawn: no team is offered it any more, no new round is screened, the cell
--   is a gap without an order and can be ordered again. N (the confirmed person dropped out, the take still live,
--   FE-110 (b) safety net) is withdrawn: the live take is released with reason `withdrawn` (never deleted), the team's
--   planned visit is cancelled with `order_withdrawn`, the team reads that the order was withdrawn, take_order refuses.
--   Audit: institution_audit_events (command, take_released) and audit_events (partner_requests.withdrawn_at,
--   order_takes.release_reason).
-- Negative: a draft (not_sent), T (awaiting_acknowledgement), G (covered), after the start (order_started), a second
--   withdrawal (already_withdrawn).
-- Permission: viewer and stranger rejected; a planner of the home who may not order (not_client_member); after the
--   access end the call raises (LEAVE1-3); partner_requests.withdrawn_at is not writable by `authenticated`.
-- Synthetic data only; rolled back. Pinned clock Mon 2026-11-16 12:00 Europe/Zurich; shifts Thu 2026-11-19.
begin;
create extension if not exists pgtap with schema extensions;

select plan(40);

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.as_owner() returns void language sql as $$
  select set_config('request.jwt.claims', '', true);
  select set_config('request.jwt.claim.sub', '', true);
$$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  perform pg_temp.as_owner();
  return r;
end $$;
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
create function pg_temp.lead() returns text language sql as $$ select '00000000-0000-4000-a000-0000000009e8' $$;
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a162-0000000000' || n)::uuid $$;
create function pg_temp.inst() returns uuid language sql as $$ select '00000000-0000-4000-a000-0000000004c1'::uuid $$;
create function pg_temp.st() returns uuid language sql as $$ select '00000000-0000-4000-c162-000000000001'::uuid $$;
create function pg_temp.fr() returns uuid language sql as $$ select '00000000-0000-4000-c162-000000000002'::uuid $$;
create function pg_temp.sp() returns uuid language sql as $$ select '00000000-0000-4000-c162-000000000003'::uuid $$;
create function pg_temp.mara() returns uuid language sql as $$ select '00000000-0000-4000-c162-000000000011'::uuid $$;
create function pg_temp.lena() returns uuid language sql as $$ select '00000000-0000-4000-c162-000000000012'::uuid $$;

-- Fixture (synthetic), as the table owner ---------------------------------------------------------------------------
insert into auth.users (id, aud, role, email)
  select pg_temp.u(n), 'authenticated', 'authenticated', 'hd2w-' || n || '.fixture@navora.test'
  from unnest(array['02', '03', '09', '11', '12']) n;
insert into public.institution_members (institution_id, user_id, role) values (pg_temp.inst(), pg_temp.u('02'), 'viewer');
insert into public.institution_stations (id, institution_id, name, sort) values (pg_temp.st(), pg_temp.inst(), 'Station HD-2w', 1);
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, ends_at, sort) values
  (pg_temp.fr(), pg_temp.inst(), 'F3', 'Früh HD-2w', '07:00', '15:30', 1),
  (pg_temp.sp(), pg_temp.inst(), 'S3', 'Spät HD-2w', '15:00', '23:00', 2);
insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total, required_grade,
                                               required_grade_count, example) values
  (pg_temp.inst(), pg_temp.st(), pg_temp.fr(), 1, 'nurse_hf_fh', 1, true),
  (pg_temp.inst(), pg_temp.st(), pg_temp.sp(), 1, null, 0, true);
insert into public.institution_staff (id, institution_id, display_name, grade, home_station_id) values
  (pg_temp.mara(), pg_temp.inst(), 'Mara Test HD-2w', 'nurse_hf_fh', pg_temp.st()),
  (pg_temp.lena(), pg_temp.inst(), 'Lena Test HD-2w', 'nurse_hf_fh', pg_temp.st());
insert into public.institution_assignments (institution_id, station_id, shift_type_id, work_date, staff_id) values
  (pg_temp.inst(), pg_temp.st(), pg_temp.fr(), date '2026-11-19', pg_temp.mara());
insert into public.institution_absences (institution_id, staff_id, starts_on, ends_on) values
  (pg_temp.inst(), pg_temp.mara(), date '2026-11-19', date '2026-11-19');
-- One HF team in Basel-Landschaft serving 4102.
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  ('00000000-0000-4000-b000-000000000019', '00000000-0000-4000-b162-000000000001', 'HD-2w Team HF', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values ('00000000-0000-4000-b162-000000000001', '4102');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('11'), 'nurse'),
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('12'), 'nurse'),
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('09'), 'admin');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-b162-000000000001', pg_temp.u('11'), 'registered_nurse'),
  ('00000000-0000-4000-b162-000000000001', pg_temp.u('12'), 'registered_nurse');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select '00000000-0000-4000-b000-000000000019'::uuid, pg_temp.u(n), 'grade', 'nurse_hf_fh', 'verified', true, null::date
  from unnest(array['11', '12']) n
  union all  -- the matrix cell A1 × HF requires `practice_licence` (PROPOSED matrix, synthetic evidence only)
  select '00000000-0000-4000-b000-000000000019', pg_temp.u(n), 'practice_licence', null, 'verified', true, null
  from unnest(array['11', '12']) n;

create function pg_temp.cell(p_shift uuid) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := pg_temp.cmd(pg_temp.lead(), format('select public.institution_plan(%L, %L, %L)', pg_temp.inst(), '2026-11-19', '2026-11-19'));
  return (select c from jsonb_array_elements(r -> 'cells') c
          where c ->> 'station_id' = pg_temp.st()::text and c ->> 'shift_type_id' = p_shift::text);
end $$;
create function pg_temp.prep(p_user text, p_shift uuid) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_prepare_gap_order(%L, %L, %L, %L)',
                                    pg_temp.inst(), pg_temp.st(), p_shift, '2026-11-19'))
$$;
create function pg_temp.send(p_user text, p_gap uuid, p_grade text, p_tags text, p_key text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_send_gap_order(%L, %L, %L, %L::text[], %L::text[], null, %L)',
                                    p_gap, '4102', p_grade, p_tags, '{}', p_key))
$$;
create temp table ids (k text primary key, id uuid);
grant all on ids to authenticated;


create function pg_temp.wd(p_user text, p_gap uuid) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_withdraw_gap_order(%L)', p_gap))
$$;
create function pg_temp.offers_for(p_user text, p_order uuid) returns text language sql as $$
  select coalesce((pg_temp.cmd(p_user, format($q$select string_agg(x.offer_state || coalesce('/' || x.release_kind, ''), ',')
                                              from public.team_order_offers() x where x.order_id = %L$q$, p_order))) #>> '{}', 'none')
$$;
create function pg_temp.client_state(p_order uuid) returns text language sql as $$
  select (pg_temp.cmd(pg_temp.lead(), format('select x.cover_state || coalesce(''/'' || x.cover_detail, '''') from public.client_orders() x where x.id = %L',
                                             p_order))) #>> '{}'
$$;
create function pg_temp.id(p_k text) returns uuid language sql as $$ select id from ids where k = p_k $$;
-- A planner of the home who is not a member of its client account; a planner whose access will end.
insert into auth.users (id, aud, role, email)
  select pg_temp.u(n), 'authenticated', 'authenticated', 'hd2w-' || n || '.fixture@navora.test' from unnest(array['04', '05']) n;
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.inst(), pg_temp.u('04'), 'planner'), (pg_temp.inst(), pg_temp.u('05'), 'planner');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('05'), 'nurse');

-- 1. A: a sent order with an open offer and no take ----------------------------------------------------------------
insert into ids select 'gA', (pg_temp.prep(pg_temp.lead(), pg_temp.sp()) ->> 'gap_order_id')::uuid;
select is(pg_temp.wd(pg_temp.lead(), pg_temp.id('gA')) -> 'problems', '["not_sent"]'::jsonb, 'a draft is not withdrawn (it is discarded)');
insert into ids select 'oA', (pg_temp.send(pg_temp.lead(), pg_temp.id('gA'), 'nurse_hf_fh', '{A1}',
                                           'eeee0000-0000-4000-8162-000000000001') ->> 'order_id')::uuid;
select is(pg_temp.client_state(pg_temp.id('oA')), 'open', 'precondition A: the order is offered');
select is(pg_temp.offers_for(pg_temp.u('12')::text, pg_temp.id('oA')), 'open', 'precondition A: the HF team sees the open offer');
select is(pg_temp.wd(pg_temp.u('02')::text, pg_temp.id('gA')) ->> 'result', 'rejected', 'a viewer cannot withdraw');
select is(pg_temp.wd(pg_temp.u('03')::text, pg_temp.id('gA')) ->> 'result', 'rejected', 'a stranger cannot withdraw');
select is(pg_temp.wd(pg_temp.u('04')::text, pg_temp.id('gA')) -> 'problems', '["not_client_member"]'::jsonb,
          'a planner who may not order for the home cannot withdraw');
create temp table wA as select pg_temp.wd(pg_temp.lead(), pg_temp.id('gA')) as r;
select is((select (r ->> 'result') || '/' || (r ->> 'take_released') from wA), 'ok/false', 'the lead withdraws A; no take to release');
select is(pg_temp.client_state(pg_temp.id('oA')), 'withdrawn', '/order reads the withdrawn state');
select is(pg_temp.offers_for(pg_temp.u('12')::text, pg_temp.id('oA')), 'none', 'no team is offered a withdrawn order any more');
select is(pg_temp.cmd(pg_temp.u('12')::text, format('select public.take_order(%L, %L, %L, %L)', pg_temp.id('oA'),
            '00000000-0000-4000-b162-000000000001', pg_temp.u('12'), 'ffff0000-0000-4000-8162-000000000001')) ->> 'reason',
          'order_withdrawn', 'take_order refuses a withdrawn order');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.id('oA')), 0, 'no take was written');
select private.screen_order_reach(pg_temp.id('oA'), 2);
select is(private.order_round(pg_temp.id('oA')), 1, 'a withdrawn order is never screened again (no round 2)');
select is((select state from public.institution_gap_orders where id = pg_temp.id('gA')), 'withdrawn', 'the gap order is withdrawn');
select is(pg_temp.cell(pg_temp.sp()) -> 'order', 'null'::jsonb, 'the cell has no active order any more');
select is(pg_temp.cell(pg_temp.sp()) ->> 'status', 'gap', 'the cell is a gap');
select is(pg_temp.prep(pg_temp.lead(), pg_temp.sp()) ->> 'result', 'ok', 'the gap can be ordered again (it left the one-active-order index)');
select is(pg_temp.wd(pg_temp.lead(), pg_temp.id('gA')) ->> 'result', 'already_withdrawn', 'a second withdrawal changes nothing');
select is((select count(*)::int from public.institution_audit_events where entity_id = pg_temp.id('gA')
             and command = 'institution_withdraw_gap_order' and actor_id = pg_temp.lead()::uuid
             and changed ->> 'take_released' = 'false'), 1, 'one audit row names the lead and the withdrawal');
select is((select count(*)::int from public.audit_events where table_name = 'partner_requests' and entity_id = pg_temp.id('oA')
             and changed ? 'withdrawn_at' and changed ? 'withdrawn_by'), 1, 'the order''s withdrawal is in the audit trail');

-- 2. T and G are not withdrawn here; N is --------------------------------------------------------------------------
insert into ids select 'gN', (pg_temp.prep(pg_temp.lead(), pg_temp.fr()) ->> 'gap_order_id')::uuid;
insert into ids select 'oN', (pg_temp.send(pg_temp.lead(), pg_temp.id('gN'), 'nurse_hf_fh', '{A1}',
                                           'eeee0000-0000-4000-8162-000000000002') ->> 'order_id')::uuid;
select is(pg_temp.cmd(pg_temp.u('12')::text, format('select public.take_order(%L, %L, %L, %L)', pg_temp.id('oN'),
            '00000000-0000-4000-b162-000000000001', pg_temp.u('11'), 'ffff0000-0000-4000-8162-000000000002')) ->> 'result',
          'ok', 'a colleague takes the order naming the HF nurse …11');
select is(pg_temp.wd(pg_temp.lead(), pg_temp.id('gN')) -> 'problems', '["awaiting_acknowledgement"]'::jsonb,
          'T (the named person confirms still) is not withdrawn');
select is(pg_temp.cmd(pg_temp.u('11')::text, format('select public.acknowledge_take(%L, %L)', pg_temp.id('oN'),
            'ffff0000-0000-4000-8162-000000000003')) ->> 'result', 'ok', 'she confirms');
select is(pg_temp.client_state(pg_temp.id('oN')), 'covered', 'precondition G: covered');
select is(pg_temp.wd(pg_temp.lead(), pg_temp.id('gN')) -> 'problems', '["covered"]'::jsonb,
          'G (a confirmed person) is not withdrawn here');
insert into ids select 'kN', id from public.order_takes where order_id = pg_temp.id('oN') and released_at is null;
select is((select status from public.care_visits where order_take_id = pg_temp.id('kN')), 'planned',
          'precondition: her planned visit was written from the take');
-- Her contract end passes before the shift, no command runs (FE-110 (b) path): N with the take still live.
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('11'), null, date '2026-11-17', pg_temp.u('09'));
select set_config('navora.test_now', '2026-11-18 10:00:00+01', true);
select is(pg_temp.client_state(pg_temp.id('oN')), 'no_longer_covered/no_offer_open', 'precondition N: no longer covered, no offer open');
create temp table wN as select pg_temp.wd(pg_temp.lead(), pg_temp.id('gN')) as r;
select is((select (r ->> 'result') || '/' || (r ->> 'take_released') from wN), 'ok/true', 'the lead withdraws N; the live take is released');
select is((select release_reason from public.order_takes where id = pg_temp.id('kN')), 'withdrawn',
          'the take is released with reason `withdrawn`, never deleted');
select is((select count(*)::int from public.order_takes where order_id = pg_temp.id('oN') and released_at is null), 0, 'no live take remains');
select is((select status || '/' || system_end_reason from public.care_visits where order_take_id = pg_temp.id('kN')),
          'cancelled/order_withdrawn', 'the team''s planned visit is cancelled with `order_withdrawn`, never deleted');
select is(pg_temp.client_state(pg_temp.id('oN')), 'withdrawn', '/order reads the withdrawn state');
select is(pg_temp.offers_for(pg_temp.u('12')::text, pg_temp.id('oN')), 'released/order_withdrawn',
          'the team whose take was released reads that the order was withdrawn; no open offer');
select is(private.order_round(pg_temp.id('oN')), 1, 'no new round was screened after the release');
select is((select count(*)::int from public.audit_events where table_name = 'order_takes' and entity_id = pg_temp.id('kN')
             and changed -> 'release_reason' ->> 'new' = 'withdrawn'), 1, 'the release is in the audit trail');
select is((select changed ->> 'take_released' from public.institution_audit_events where entity_id = pg_temp.id('gN')
             and command = 'institution_withdraw_gap_order'), 'true', 'the home''s audit row says a take was released');
select is(pg_temp.cell(pg_temp.fr()) ->> 'status', 'gap', 'the cell is a gap without an order');

-- 3. After the start, access end, direct writes --------------------------------------------------------------------
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
insert into ids select 'gS', (pg_temp.prep(pg_temp.lead(), pg_temp.fr()) ->> 'gap_order_id')::uuid;
select is(pg_temp.send(pg_temp.lead(), pg_temp.id('gS'), 'nurse_hf_fh', '{A1}', 'eeee0000-0000-4000-8162-000000000004') ->> 'result',
          'ok', 'the gap is ordered again');
select set_config('navora.test_now', '2026-11-19 08:00:00+01', true);
select is(pg_temp.wd(pg_temp.lead(), pg_temp.id('gS')) -> 'problems', '["order_started"]'::jsonb, 'after the start nothing is withdrawn');
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);
insert into public.member_access_events (organization_id, user_id, kind, reason_code, actor_id) values
  ('00000000-0000-4000-b000-000000000019', pg_temp.u('05'), 'ended', 'employment_ended', pg_temp.u('09'));
select pg_temp.act_as(pg_temp.u('05')::text);
set local role authenticated;
select throws_ok(format('select public.institution_withdraw_gap_order(%L)', pg_temp.id('gS')), '42501', null,
                 'after the access end the withdrawal raises (LEAVE1-3)');
select throws_ok(format($q$update public.partner_requests set withdrawn_at = now() where id = %L$q$, pg_temp.id('gS')), '42501', null,
                 'authenticated cannot write partner_requests.withdrawn_at');
reset role;
select pg_temp.as_owner();

select * from finish();
rollback;
