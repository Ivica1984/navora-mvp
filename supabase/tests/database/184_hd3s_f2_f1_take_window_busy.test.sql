-- HD-3s-F2-F1 «Handweg sieht die Pause einer geteilten Übernahme als belegt» (brief docs/agents/briefs/HD-3s-F2-F1.md;
-- `cra` CGR-289 (a)–(c); PO decision (c): the hand path refuses and names the take). Fixed, checkable rules; synthetic
-- data only; rolled back. Red first (TESTS 1): pushed before the fix, where the hand path compares visits only, reads the
-- pause as free and the save silently releases the whole split take (recheck_member_takes, step 3).
-- Pinned clock Mon 2026-11-16 12:00 Europe/Zurich; split take Thu 2026-11-19 07:00–11:30 und 16:00–20:00 of nurse …11.
--   §1 precondition: the split take is live with its two block visits.
--   §2 CGR-289 (b): the form's read (member_slot_overlap) 12:00–13:00 busy; 20:00–21:00 and 06:00–07:00 free.
--   §3 PO (c): plan_visit 12:00–13:00 for her is rejected with reason member_take_window and the take's facts; nothing is
--      written; the take stays live, both block visits unchanged, no take_member_dropped, the home still reads covered.
--   §4 the other hand commands: take_open_visit, reschedule_visit, move_visit_to_today into the pause are rejected too.
--   §5 regression: a hand visit outside every take window is saved; a one-block take refuses inside its window only.
--   §6 backstop: a direct write of a non-take visit into her live take window raises (no writer releases silently).
--   §7 privacy (CGR-137): a lead of another team of hers reads the date and blocks, never the home.
-- Users: lead kundebs …9e8 of «Testheim Rhein» …4c1 (client account …3c1); nurses …11 (split take), …12 (lead of the
-- hand plan, one-block take), …13 (other team) in Testorganisation S (…b000-…019); team …b184-…01, second team …b184-…02.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a184-0000000000' || n)::uuid $$;
create function pg_temp.us(n text) returns text language sql as $$ select pg_temp.u(n)::text $$;
create function pg_temp.inst() returns uuid language sql as $$ select '00000000-0000-4000-a000-0000000004c1'::uuid $$;
create function pg_temp.st() returns uuid language sql as $$ select '00000000-0000-4000-c184-000000000001'::uuid $$;
create function pg_temp.sp() returns uuid language sql as $$ select '00000000-0000-4000-c184-000000000003'::uuid $$;
create function pg_temp.team(n int default 1) returns uuid language sql as $$
  select ('00000000-0000-4000-b184-00000000000' || n)::uuid $$;
create function pg_temp.org() returns uuid language sql as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;
create function pg_temp.c(n int default 1) returns uuid language sql as $$
  select ('00000000-0000-4000-c184-00000000010' || n)::uuid $$;
create function pg_temp.k(n int) returns uuid language sql as $$
  select ('eeee0000-0000-4000-8184-' || lpad(n::text, 12, '0'))::uuid $$;
create temp table ids (k text primary key, id uuid);
grant all on ids to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql as $$ select id from ids where k = p_k $$;

-- Fixture (synthetic), as the table owner ----------------------------------------------------------------------------
insert into auth.users (id, aud, role, email)
  select pg_temp.u(n), 'authenticated', 'authenticated', 'hd3sf2f1-' || n || '.fixture@navora.test'
  from unnest(array['11', '12', '13']) n;
insert into public.institution_stations (id, institution_id, name, sort) values (pg_temp.st(), pg_temp.inst(), 'Station F1', 1);
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, block1_ends_at, block2_starts_at,
                                            ends_at, shift_class, sort) values
  (pg_temp.sp(), pg_temp.inst(), 'GF', 'Geteilt F1', '07:00', '11:30', '16:00', '20:00', 'split', 1);
insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total, required_grade,
                                               required_grade_count, example) values
  (pg_temp.inst(), pg_temp.st(), pg_temp.sp(), 1, 'nurse_hf_fh', 1, true);
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  (pg_temp.org(), pg_temp.team(1), 'F1 Team', 'Basel-Landschaft', 'active', 10),
  (pg_temp.org(), pg_temp.team(2), 'F1 Zweitteam', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values (pg_temp.team(1), '4102');
insert into public.organization_memberships (organization_id, user_id, role)
  select pg_temp.org(), pg_temp.u(n), 'nurse' from unnest(array['11', '12', '13']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.team(1), pg_temp.u('11'), 'registered_nurse'), (pg_temp.team(1), pg_temp.u('12'), 'registered_nurse'),
  (pg_temp.team(2), pg_temp.u('11'), 'registered_nurse'), (pg_temp.team(2), pg_temp.u('13'), 'registered_nurse');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select pg_temp.org(), pg_temp.u(n), 'grade', 'nurse_hf_fh', 'verified', true, null::date from unnest(array['11', '12']) n
  union all  -- the matrix cell A1 × HF requires `practice_licence` (PROPOSED matrix, synthetic evidence only)
  select pg_temp.org(), pg_temp.u(n), 'practice_licence', null, 'verified', true, null from unnest(array['11', '12']) n;
-- Two home-care cases (copies of the synthetic seed case …208), one per team, needs assessment done.
create temp table kc as select * from public.cases where id = '00000000-0000-4000-a000-000000000208';
insert into public.cases
select (jsonb_populate_record(k, jsonb_build_object('id', pg_temp.c(n), 'organization_id', pg_temp.org(),
          'assigned_team_id', pg_temp.team(n), 'auto_planning', false, 'primary_nurse_id', null, 'deputy_nurse_id', null,
          'proposed_primary_nurse_id', null, 'previous_case_id', null, 'source_partner_request_id', null))).*
from kc k, unnest(array[1, 2]) n;

-- The split order of the home, taken by …11 (as in pgTAP 183 §3–§4).
create temp table g as select pg_temp.cmd(pg_temp.lead(), format('select public.institution_prepare_gap_order(%L, %L, %L, %L)',
  pg_temp.inst(), pg_temp.st(), pg_temp.sp(), '2026-11-19')) as r;
insert into ids select 'g1', (r ->> 'gap_order_id')::uuid from g;
insert into ids select 'o1', (pg_temp.cmd(pg_temp.lead(), format($q$select public.institution_send_gap_order(%L, '4102',
  'nurse_hf_fh', '{A1}', '{}', null, %L)$q$, pg_temp.id('g1'), pg_temp.k(1))) ->> 'order_id')::uuid;
select pg_temp.act_as(pg_temp.us('11'));
set local role authenticated;
create temp table t1 as select public.take_order(pg_temp.id('o1'), pg_temp.team(1), pg_temp.u('11'), pg_temp.k(2)) as r;
reset role;
select pg_temp.as_owner();
create temp table tv as
  select v.id, v.take_block, v.time_start, v.time_end, v.status from public.care_visits v
  join public.order_takes t on t.id = v.order_take_id where t.order_id = pg_temp.id('o1');

create function pg_temp.live() returns boolean language sql as $$
  select exists (select 1 from public.order_takes where order_id = pg_temp.id('o1') and member_id = pg_temp.u('11')
                   and released_at is null) $$;
create function pg_temp.slot(p_lead text, p_case uuid, s time, e time) returns jsonb language sql as $$
  select pg_temp.cmd(p_lead, format('select public.member_slot_overlap(%L, null, %L, %L, %L, %L)',
    p_case, pg_temp.u('11'), '2026-11-19', s, e)) $$;
create function pg_temp.plan(p_lead text, p_case uuid, p_member text, s time, e time, key int) returns jsonb language sql as $$
  select pg_temp.cmd(p_lead, format('select public.plan_visit(%L, %L, %L, %L, 30, 0, 0, false, %L, %L, null, null)',
    p_case, '2026-11-19', s, e, pg_temp.u(p_member), pg_temp.k(key))) $$;

-- §1 Precondition -----------------------------------------------------------------------------------------------------
select is((select r ->> 'result' from t1) || '/' || (select count(*)::int from tv)::text || '/' || pg_temp.live()::text,
          'ok/2/true', '§1 precondition: she took the split order; two block visits; the take is live');

-- §2 CGR-289 (b): the form's read --------------------------------------------------------------------------------------
select is(pg_temp.slot(pg_temp.us('12'), pg_temp.c(1), '12:00', '13:00'), 'true'::jsonb,
          '§2 CGR-289 (b): 12:00–13:00 in the pause of her split take reads busy');
select is(pg_temp.slot(pg_temp.us('12'), pg_temp.c(1), '20:00', '21:00'), 'false'::jsonb,
          '§2 CGR-289 (b): 20:00–21:00 after block 2 reads free (touching end)');
select is(pg_temp.slot(pg_temp.us('12'), pg_temp.c(1), '06:00', '07:00'), 'false'::jsonb,
          '§2 CGR-289 (b): 06:00–07:00 before block 1 reads free (touching start)');

-- §3 PO (c): the hand save in the pause is rejected with the take named -----------------------------------------------
create temp table p1 as select pg_temp.plan(pg_temp.us('12'), pg_temp.c(1), '11', '12:00', '13:00', 10) as r;
select is((select r ->> 'result' || '/' || coalesce(r ->> 'reason', '') from p1), 'rejected/member_take_window',
          '§3 PO (c): plan_visit 12:00–13:00 for her is rejected with reason member_take_window');
select is((select r -> 'take' ->> 'work_date' from p1), '2026-11-19', '§3 the reason names the date of the take');
select is((select r -> 'take' ->> 'blocks' from p1), '07:00 – 11:30 und 16:00 – 20:00',
          '§3 the reason names both blocks');
select is((select r -> 'take' ->> 'client_name' from p1), 'Testheim Rhein (synthetisch)',
          '§3 the lead of the take''s own team reads the home');
select is((select count(*)::int from public.care_visits where case_id = pg_temp.c(1)), 0,
          '§3 nothing is written for the case');
select ok(pg_temp.live(), '§3 the take stays live (no silent release)');
select is((select string_agg(v.take_block || ':' || v.status || ':' || to_char(v.time_start, 'HH24:MI'), ',' order by v.take_block)
           from public.care_visits v where v.id in (select id from tv)), '1:planned:07:00,2:planned:16:00',
          '§3 both block visits unchanged');
select is((select count(*)::int from private.derived_exceptions_of(pg_temp.org(), array['take_member_dropped'])), 0,
          '§3 no take_member_dropped');
select is(pg_temp.cmd(pg_temp.lead(), format('select x.cover_state from public.client_orders() x where x.id = %L',
            pg_temp.id('o1'))) #>> '{}', 'covered', '§3 the home still reads the order as covered');
select is((select count(*)::int from public.audit_events a where a.idempotency_key = pg_temp.k(10)), 0,
          '§3 like every plan_visit rejection: no row under its key, so nothing was written');

-- §4 The other hand commands --------------------------------------------------------------------------------------------
-- An open visit of the case at 12:00 (no responsible person) and a visit of hers at 21:00, written as the owner.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided,
                                billable, status, planned_minutes_a, responsible_user_id)
values (pg_temp.org(), 'dddd0000-0000-4000-8184-000000000001', pg_temp.c(1), pg_temp.team(1), '2026-11-19', '12:00',
        '12:30', array['Grundpflege'], false, 'planned', 30, null),
       (pg_temp.org(), 'dddd0000-0000-4000-8184-000000000002', pg_temp.c(1), pg_temp.team(1), '2026-11-19', '21:00',
        '21:30', array['Grundpflege'], false, 'planned', 30, pg_temp.u('11'));
select is(pg_temp.cmd(pg_temp.us('11'), format('select public.take_open_visit(%L, %L, null)',
            'dddd0000-0000-4000-8184-000000000001', pg_temp.k(20))) ->> 'reason', 'member_take_window',
          '§4 take_open_visit of a 12:00 visit by her is rejected (member_take_window)');
select is(pg_temp.cmd(pg_temp.us('12'), format($q$select public.reschedule_visit(%L, '2026-11-19', '12:00', '12:30',
            'synthetic', %L, null, null)$q$, 'dddd0000-0000-4000-8184-000000000002', pg_temp.k(21))) ->> 'reason',
          'member_take_window', '§4 reschedule_visit of her 21:00 visit into the pause is rejected');
select is((select to_char(time_start, 'HH24:MI') from public.care_visits where id = 'dddd0000-0000-4000-8184-000000000002'),
          '21:00', '§4 the rejected reschedule changed nothing');
select ok(pg_temp.live(), '§4 the take is still live after the rejected hand commands');

-- §5 Regression ----------------------------------------------------------------------------------------------------------
select is(pg_temp.plan(pg_temp.us('12'), pg_temp.c(1), '11', '20:00', '20:30', 30) ->> 'result', 'ok',
          '§5 a hand visit for her outside every take window (20:00) is saved');
select ok(pg_temp.live(), '§5 and the take stays live');
-- A one-block take of …12 (08:00–10:00, another order of the home).
insert into ids select 'o2', (pg_temp.cmd(pg_temp.lead(), format($q$select public.confirm_client_order(
  '00000000-0000-4000-a000-0000000003c1', '2026-11-19', '08:00', '10:00', '4102', 'nurse_hf_fh', '{A1}', '{}', null, %L)$q$,
  pg_temp.k(31))) ->> 'order_id')::uuid;
select pg_temp.act_as(pg_temp.us('12'));
set local role authenticated;
select is(public.take_order(pg_temp.id('o2'), pg_temp.team(1), pg_temp.u('12'), pg_temp.k(32)) ->> 'result', 'ok',
          '§5 precondition: …12 takes a one-block order 08:00–10:00');
reset role;
select pg_temp.as_owner();
select is(pg_temp.plan(pg_temp.us('11'), pg_temp.c(1), '12', '10:00', '10:30', 33) ->> 'result', 'ok',
          '§5 one-block take: a hand visit after its window is saved');
select is(pg_temp.plan(pg_temp.us('11'), pg_temp.c(1), '12', '09:00', '09:30', 34) ->> 'reason', 'member_take_window',
          '§5 one-block take: a hand visit inside its window is rejected the same way');
select ok(exists (select 1 from public.order_takes where order_id = pg_temp.id('o2') and released_at is null),
          '§5 the one-block take stays live');

-- §6 Backstop: no writer releases a take silently -----------------------------------------------------------------------
select throws_ok(format($q$insert into public.care_visits (organization_id, case_id, team_id, visit_date, time_start,
                    time_end, services_provided, billable, status, planned_minutes_a, responsible_user_id)
                    values (%L, %L, %L, '2026-11-19', '13:00', '13:30', array['Grundpflege'], false, 'planned', 30, %L)$q$,
                    pg_temp.org(), pg_temp.c(1), pg_temp.team(1), pg_temp.u('11')),
                 'P0001', null, '§6 a direct insert of a non-take visit into her take window raises');
select throws_ok(format($q$update public.care_visits set time_start = '14:00', time_end = '14:30' where id = %L$q$,
                    'dddd0000-0000-4000-8184-000000000002'),
                 'P0001', null, '§6 a direct move of her visit into the pause raises');
select ok(pg_temp.live(), '§6 the take is still live');

-- §7 Privacy across teams (CGR-137) ---------------------------------------------------------------------------------
create temp table p7 as select pg_temp.plan(pg_temp.us('13'), pg_temp.c(2), '11', '12:00', '13:00', 40) as r;
select is((select r ->> 'reason' from p7), 'member_take_window', '§7 the other team''s lead is rejected the same way');
select is((select (r -> 'take' ->> 'work_date') || '|' || (r -> 'take' ->> 'blocks') from p7),
          '2026-11-19|07:00 – 11:30 und 16:00 – 20:00', '§7 she reads the date and the blocks');
select ok((select not (r -> 'take' ? 'client_name') and r::text not like '%Testheim%' from p7),
          '§7 she never reads the home of another team''s take');

-- §8 Catalogue (review (d) on #1825): the trigger does not re-check a change of order_take_id alone. No client role may
-- update that column, and no migration does so after insert; a change of this needs its own guard first.
reset role;
select ok(not has_column_privilege('authenticated', 'public.care_visits', 'order_take_id', 'UPDATE'),
          '§8 authenticated cannot update care_visits.order_take_id');
select ok(not has_column_privilege('anon', 'public.care_visits', 'order_take_id', 'UPDATE'),
          '§8 anon cannot update care_visits.order_take_id');

select * from finish();
rollback;
