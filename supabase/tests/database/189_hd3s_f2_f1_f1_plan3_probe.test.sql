-- PROBE (do not merge) HD-3s-F2-F1-F1 «Tagesplan-Vorschlag sieht die Pause einer geteilten Übernahme als belegt»
-- (brief docs/agents/briefs/HD-3s-F2-F1-F1.md; `cra` CGR-291, `aia` AUT-235). Red reproduction (TESTS 1, WORKING MODE 7):
-- the day-plan proposer `private.plan3_lines` builds a member's busy time from visits only (her two block visits), reads
-- the pause of her live split take as free and proposes her for an open visit at 12:00. The hand path refuses the same
-- slot since HD-3s-F2-F1 (`private.member_take_window`, pgTAP 184). Fixed, checkable rule; synthetic data; rolled back.
-- Pinned clock Mon 2026-11-16 12:00 Europe/Zurich; split take Thu 2026-11-19 07:00–11:30 und 16:00–20:00 of nurse …11,
-- who is also the primary nurse of the home-care case (so the proposer ranks her first wherever she is free).
--   §1 precondition: take live, two block visits; the rule source reads her busy at 12:00 and free at 20:30.
--   §2 RED today: the 12:00 open visit is not proposed for her; the other team member …12 is proposed instead.
--   §3 positive: the 20:30 open visit (after block 2) is proposed for her as primary nurse.
--   §4 RED today, finding of this probe (not yet a brief criterion; decision `po`): with «zugewiesene neu planen»
--      (p_include_assigned) the proposer re-proposes the block visits of her take and drops them from her busy time;
--      the confirm refuses every such line with `not_open` (BK-E1B-A, aig1_apply_visit_responsible), so the lead again
--      sees a proposal that cannot be confirmed. Expected: a take visit (order_take_id set) is never a proposal line and
--      always counts as busy for its taker.
begin;
create extension if not exists pgtap with schema extensions;

select plan(9);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a189-0000000000' || n)::uuid $$;
create function pg_temp.us(n text) returns text language sql as $$ select pg_temp.u(n)::text $$;
create function pg_temp.inst() returns uuid language sql as $$ select '00000000-0000-4000-a000-0000000004c1'::uuid $$;
create function pg_temp.st() returns uuid language sql as $$ select '00000000-0000-4000-c189-000000000001'::uuid $$;
create function pg_temp.sp() returns uuid language sql as $$ select '00000000-0000-4000-c189-000000000003'::uuid $$;
create function pg_temp.team() returns uuid language sql as $$ select '00000000-0000-4000-b189-000000000001'::uuid $$;
create function pg_temp.org() returns uuid language sql as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;
create function pg_temp.c() returns uuid language sql as $$ select '00000000-0000-4000-c189-000000000101'::uuid $$;
create function pg_temp.k(n int) returns uuid language sql as $$
  select ('eeee0000-0000-4000-8189-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql as $$
  select ('dddd0000-0000-4000-8189-' || lpad(n::text, 12, '0'))::uuid $$;
create temp table ids (k text primary key, id uuid);
grant all on ids to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql as $$ select id from ids where k = p_k $$;

-- Fixture (synthetic), as the table owner; same shape as pgTAP 184 -----------------------------------------------------
insert into auth.users (id, aud, role, email)
  select pg_temp.u(n), 'authenticated', 'authenticated', 'hd3sf2f1f1-' || n || '.fixture@navora.test'
  from unnest(array['11', '12']) n;
insert into public.institution_stations (id, institution_id, name, sort) values (pg_temp.st(), pg_temp.inst(), 'Station P', 1);
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, block1_ends_at, block2_starts_at,
                                            ends_at, shift_class, sort) values
  (pg_temp.sp(), pg_temp.inst(), 'GP', 'Geteilt P', '07:00', '11:30', '16:00', '20:00', 'split', 1);
insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total, required_grade,
                                               required_grade_count, example) values
  (pg_temp.inst(), pg_temp.st(), pg_temp.sp(), 1, 'nurse_hf_fh', 1, true);
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  (pg_temp.org(), pg_temp.team(), 'P Team', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values (pg_temp.team(), '4102');
insert into public.organization_memberships (organization_id, user_id, role)
  select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['11', '12']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.team(), pg_temp.u('11'), 'registered_nurse'), (pg_temp.team(), pg_temp.u('12'), 'registered_nurse');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select pg_temp.org(), pg_temp.u(n), 'grade', 'nurse_hf_fh', 'verified', true, null::date from unnest(array['11', '12']) n
  union all  -- the matrix cell A1 × HF requires `practice_licence` (PROPOSED matrix, synthetic evidence only)
  select pg_temp.org(), pg_temp.u(n), 'practice_licence', null, 'verified', true, null from unnest(array['11', '12']) n;
-- One home-care case (copy of the synthetic seed case …208); …11 is its primary nurse.
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.c(), 'organization_id', pg_temp.org(),
          'assigned_team_id', pg_temp.team(), 'auto_planning', false, 'primary_nurse_id', pg_temp.u('11'),
          'deputy_nurse_id', null, 'proposed_primary_nurse_id', null, 'previous_case_id', null,
          'source_partner_request_id', null))).*
from kc k;

-- The split order of the home, taken by …11.
create temp table g as select pg_temp.cmd(pg_temp.lead(), format('select public.institution_prepare_gap_order(%L, %L, %L, %L)',
  pg_temp.inst(), pg_temp.st(), pg_temp.sp(), '2026-11-19')) as r;
insert into ids select 'g1', (r ->> 'gap_order_id')::uuid from g;
insert into ids select 'o1', (pg_temp.cmd(pg_temp.lead(), format($q$select public.institution_send_gap_order(%L, '4102',
  'nurse_hf_fh', '{A1}', '{}', null, %L)$q$, pg_temp.id('g1'), pg_temp.k(1))) ->> 'order_id')::uuid;
select pg_temp.act_as(pg_temp.us('11'));
set local role authenticated;
create temp table t1 as select public.take_order(pg_temp.id('o1'), pg_temp.team(), pg_temp.u('11'), pg_temp.k(2)) as r;
reset role;
select pg_temp.as_owner();

-- Two open visits of the case (no responsible person): 12:00 in the pause, 20:30 after block 2.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, responsible_user_id)
values (pg_temp.org(), pg_temp.v(1), pg_temp.c(), pg_temp.team(), '2026-11-19', '12:00', '12:30', array['Grundpflege'],
        false, 'planned', 30, null),
       (pg_temp.org(), pg_temp.v(2), pg_temp.c(), pg_temp.team(), '2026-11-19', '20:30', '21:00', array['Grundpflege'],
        false, 'planned', 30, null);
create temp table pl as select * from private.plan3_lines(pg_temp.team(), '2026-11-19', false);

-- §1 Precondition ---------------------------------------------------------------------------------------------------
select is((select r ->> 'result' from t1) || '/' ||
          (select count(*)::int from public.care_visits v join public.order_takes t on t.id = v.order_take_id
           where t.order_id = pg_temp.id('o1') and t.released_at is null)::text,
          'ok/2', '§1 precondition: she took the split order; its two block visits exist and the take is live');
select isnt(private.member_take_window(pg_temp.u('11'),
              tstzrange('2026-11-19 12:00+01', '2026-11-19 12:30+01', '[)'), null), null,
            '§1 the rule source (member_take_window) reads her busy at 12:00 (pause)');
select is(private.member_take_window(pg_temp.u('11'),
            tstzrange('2026-11-19 20:30+01', '2026-11-19 21:00+01', '[)'), null), null,
          '§1 the rule source reads her free at 20:30 (after block 2)');
select is((select count(*)::int from pl), 2, '§1 the proposer returns one line per open visit');

-- §2 RED today: the pause is not free for the proposer ---------------------------------------------------------------
select isnt((select member_id from pl where visit_id = pg_temp.v(1)), pg_temp.u('11'),
            '§2 the 12:00 open visit (pause of her split take) is not proposed for her');
select is((select member_id::text || '/' || reason from pl where visit_id = pg_temp.v(1)), pg_temp.us('12') || '/free_capacity',
          '§2 the 12:00 open visit is proposed for the free member …12 instead');

-- §3 Positive: after block 2 she is proposed ---------------------------------------------------------------------------
select is((select member_id::text || '/' || reason from pl where visit_id = pg_temp.v(2)), pg_temp.us('11') || '/primary_nurse',
          '§3 the 20:30 open visit is proposed for her as primary nurse');

-- §4 Re-plan with assigned visits: take block visits are no proposal lines -------------------------------------------
create temp table pa as select * from private.plan3_lines(pg_temp.team(), '2026-11-19', true);
select is((select count(*)::int from pa l join public.care_visits v on v.id = l.visit_id where v.order_take_id is not null), 0,
          '§4 with include_assigned no block visit of a take is a proposal line (the confirm would refuse it: not_open)');
select isnt((select member_id from pa where visit_id = pg_temp.v(1)), pg_temp.u('11'),
            '§4 with include_assigned the 12:00 open visit is still not proposed for her');

select * from finish();
rollback;
