-- HD-3s-F2 «Externer Auftrag mit zwei Blöcken» (brief docs/agents/briefs/HD-3s-F2.md; founder FE-133 (1); `cra` CGR-288;
-- ADR-229; migration 0183). Fixed, checkable rules; synthetic data only; rolled back.
-- Pinned clock Mon 2026-11-16 12:00 Europe/Zurich; split shift Thu 2026-11-19 07:00–11:30 und 16:00–20:00.
--   §1 permission: only lead/planner of the same home; viewer, stranger and another home's lead refused; access end raises.
--   §2 prepare and preview: a split gap is orderable, the prefill and the preview name both blocks and 8 h 30 min.
--   §3 send: ONE order row carries both blocks (window = whole day, pause in two columns), sentence with both blocks,
--      audit; the check constraint refuses a pause outside the window.
--   §4 take: one person takes the whole order; two visits (block 1, block 2), never a visit over the pause; the planned
--      minutes are the two blocks without the pause.
--   §5 CGR-288 (a): a second order inside the pause is refused for her (step 3) and stays open for a colleague.
--   §5 CGR-288 (b): her busy span ends at the end of block 2: an order from 20:00 is not blocked by this take, one
--      ending after 19:00 is (no rest-time rule exists in the order path today; this proves the reference point).
--   §6 qualification unchanged: a FaGe member is refused at step 1 for the HF split order.
--   §7 release before the start ends both visits (CGR-242), never only one.
--   §8 invoice draft per visit: one live draft per block, ordered minutes per block (270 and 240, never 780), no refusal.
--   §9 take_member_dropped per visit: block 2 is flagged only after its own start, under its own key.
--   §10 the order lists of the home and the team read the minutes without the pause.
-- Users: lead kundebs …9e8 (lead of «Testheim Rhein» …4c1, member of its client account …3c1); …a183-…02 viewer,
-- …03 stranger, …04 planner, the seed lead …9ed of another home (…4c2); nurses …11, …12 (HF), …13 (FaGe) in team …b183-…01 of
-- Testorganisation S (…b000-…019); …09 admin.
begin;
create extension if not exists pgtap with schema extensions;

select plan(57);

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
create function pg_temp.u(n text) returns uuid language sql as $$ select ('00000000-0000-4000-a183-0000000000' || n)::uuid $$;
create function pg_temp.inst() returns uuid language sql as $$ select '00000000-0000-4000-a000-0000000004c1'::uuid $$;
create function pg_temp.st() returns uuid language sql as $$ select '00000000-0000-4000-c183-000000000001'::uuid $$;
create function pg_temp.sp() returns uuid language sql as $$ select '00000000-0000-4000-c183-000000000003'::uuid $$;
create function pg_temp.team() returns uuid language sql as $$ select '00000000-0000-4000-b183-000000000001'::uuid $$;
create function pg_temp.org() returns uuid language sql as $$ select '00000000-0000-4000-b000-000000000019'::uuid $$;

-- Fixture (synthetic), as the table owner ----------------------------------------------------------------------------
insert into auth.users (id, aud, role, email)
  select pg_temp.u(n), 'authenticated', 'authenticated', 'hd3sf2-' || n || '.fixture@navora.test'
  from unnest(array['02', '03', '04', '09', '11', '12', '13']) n;
insert into public.institution_members (institution_id, user_id, role) values
  (pg_temp.inst(), pg_temp.u('02'), 'viewer'), (pg_temp.inst(), pg_temp.u('04'), 'planner');
insert into public.institution_stations (id, institution_id, name, sort) values (pg_temp.st(), pg_temp.inst(), 'Station F2', 1);
insert into public.institution_shift_types (id, institution_id, code, label, starts_at, block1_ends_at, block2_starts_at,
                                            ends_at, shift_class, sort) values
  (pg_temp.sp(), pg_temp.inst(), 'GT', 'Geteilt F2', '07:00', '11:30', '16:00', '20:00', 'split', 1);
insert into public.institution_staffing_rules (institution_id, station_id, shift_type_id, required_total, required_grade,
                                               required_grade_count, example) values
  (pg_temp.inst(), pg_temp.st(), pg_temp.sp(), 1, 'nurse_hf_fh', 1, true);
insert into public.teams (organization_id, id, name, region, status, max_distance_km) values
  (pg_temp.org(), pg_temp.team(), 'F2 Team', 'Basel-Landschaft', 'active', 10);
insert into public.team_service_postcodes (team_id, postcode) values (pg_temp.team(), '4102');
insert into public.organization_memberships (organization_id, user_id, role)
  select pg_temp.org(), pg_temp.u(n), case when n = '09' then 'admin' else 'nurse' end
  from unnest(array['09', '11', '12', '13']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  (pg_temp.team(), pg_temp.u('11'), 'registered_nurse'), (pg_temp.team(), pg_temp.u('12'), 'registered_nurse'),
  (pg_temp.team(), pg_temp.u('13'), 'registered_nurse');
insert into public.member_qualification_evidence (organization_id, user_id, requirement, grade, state, synthetic, valid_until)
  select pg_temp.org(), pg_temp.u(n), 'grade', case when n = '13' then 'fage_efz' else 'nurse_hf_fh' end, 'verified', true,
         null::date
  from unnest(array['11', '12', '13']) n
  union all  -- the matrix cell A1 × HF requires `practice_licence` (PROPOSED matrix, synthetic evidence only)
  select pg_temp.org(), pg_temp.u(n), 'practice_licence', null, 'verified', true, null from unnest(array['11', '12']) n;

create function pg_temp.prep(p_user text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.institution_prepare_gap_order(%L, %L, %L, %L)',
                                    pg_temp.inst(), pg_temp.st(), pg_temp.sp(), '2026-11-19'))
$$;
create temp table ids (k text primary key, id uuid);
grant all on ids to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql as $$ select id from ids where k = p_k $$;
create function pg_temp.order_at(p_start text, p_end text, p_key text) returns uuid language sql as $$
  select (pg_temp.cmd(pg_temp.lead(), format($q$select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1',
            '2026-11-19', %L, %L, '4102', 'nurse_hf_fh', '{A1}', '{}', null, %L)$q$, p_start, p_end, p_key))
          ->> 'order_id')::uuid
$$;

-- §1 Permission ------------------------------------------------------------------------------------------------------
select is(pg_temp.prep(pg_temp.u('02')::text) ->> 'result', 'rejected', '§1 a viewer cannot prepare the split order');
select is(pg_temp.prep(pg_temp.u('03')::text) ->> 'result', 'rejected', '§1 a stranger cannot prepare it');
select is(pg_temp.prep('00000000-0000-4000-a000-0000000009ed') ->> 'result', 'rejected',
          '§1 the lead of another home (seed …4c2) cannot prepare it');
select ok(not has_function_privilege('anon', 'private.order_set_pause(uuid, date, time, time)', 'execute')
          and not has_function_privilege('authenticated', 'private.order_set_pause(uuid, date, time, time)', 'execute'),
          '§1 the pause writer is private: no anon or authenticated execute');

-- §2 Prepare and preview ---------------------------------------------------------------------------------------------
create temp table r1 as select pg_temp.prep(pg_temp.u('04')::text) as r;
select is((select r ->> 'result' from r1), 'ok', '§2 the planner prepares an order from the split gap (no refusal)');
insert into ids select 'g1', (r ->> 'gap_order_id')::uuid from r1;
select is((select r -> 'prefill' ->> 'start_time' || '-' || (r -> 'prefill' ->> 'block1_end_time') || '/'
                  || (r -> 'prefill' ->> 'block2_start_time') || '-' || (r -> 'prefill' ->> 'end_time') from r1),
          '07:00-11:30/16:00-20:00', '§2 the prefill names both blocks');
select is((select (r -> 'prefill' ->> 'work_minutes')::numeric from r1), 510::numeric,
          '§2 working minutes 8 h 30 min, the pause not counted');
select is((select count(*)::int from public.institution_audit_events where command = 'institution_prepare_gap_order'
             and entity_id = pg_temp.id('g1')), 1, '§2 the prepare is audited');
create temp table pv as select pg_temp.cmd(pg_temp.lead(), format($q$select public.institution_preview_gap_order(%L, '4102',
  'nurse_hf_fh', '{A1}', '{}', null)$q$, pg_temp.id('g1'))) -> 'preview' as p;
select is((select p -> 'problems' from pv), '[]'::jsonb, '§2 the preview finds no problem');
select is((select p ->> 'duration_minutes' from pv), '510', '§2 the preview counts 510 minutes, not 780');
select matches((select p ->> 'sentence' from pv), '07:00 – 11:30 und 16:00 – 20:00 \(8 Std\. 30 Min\.\)',
               '§2 the preview sentence names both blocks and the minutes without the pause');

-- §3 Send: one order with both blocks ---------------------------------------------------------------------------------
select is(pg_temp.cmd(pg_temp.u('02')::text, format($q$select public.institution_send_gap_order(%L, '4102', 'nurse_hf_fh',
            '{A1}', '{}', null, 'eeee0000-0000-4000-8183-000000000001')$q$, pg_temp.id('g1'))) ->> 'result', 'rejected',
          '§3 a viewer cannot send');
create temp table r2 as select pg_temp.cmd(pg_temp.lead(), format($q$select public.institution_send_gap_order(%L, '4102',
  'nurse_hf_fh', '{A1}', '{}', null, 'eeee0000-0000-4000-8183-000000000002')$q$, pg_temp.id('g1'))) as r;
select is((select r ->> 'result' from r2), 'ok', '§3 the lead sends the split order');
insert into ids select 'o1', (r ->> 'order_id')::uuid from r2;
select is((select count(*)::int from public.partner_requests p join public.institution_gap_orders g on g.order_id = p.id
             where g.id = pg_temp.id('g1')), 1, '§3 exactly one order row for the split gap (no automatic split)');
select is((select to_char(starts_at at time zone 'Europe/Zurich', 'HH24:MI') || '|'
                  || to_char(pause_starts_at at time zone 'Europe/Zurich', 'HH24:MI') || '|'
                  || to_char(pause_ends_at at time zone 'Europe/Zurich', 'HH24:MI') || '|'
                  || to_char(ends_at at time zone 'Europe/Zurich', 'HH24:MI')
           from public.partner_requests where id = pg_temp.id('o1')), '07:00|11:30|16:00|20:00',
          '§3 window 07:00–20:00 with the pause 11:30–16:00 on the order');
select matches((select request_title from public.partner_requests where id = pg_temp.id('o1')),
               '^Schichtauftrag · .* 07:00 – 11:30 und 16:00 – 20:00 \(8 Std\. 30 Min\.\) · 4102 ',
               '§3 the order sentence the teams read names both blocks');
select is((select grade from public.partner_requests where id = pg_temp.id('o1')), 'nurse_hf_fh',
          '§3 the grade of the gap is kept');
select ok(exists (select 1 from public.audit_events a where a.entity_id = pg_temp.id('o1')
                    and a.changed ? 'pause_starts_at' and a.changed ? 'pause_ends_at'),
          '§3 the pause is in the audit of the order');
select throws_like(format($q$update public.partner_requests set pause_starts_at = starts_at - interval '1 hour'
                             where id = %L$q$, pg_temp.id('o1')),
                   '%partner_requests_pause_shape%', '§3 the database refuses a pause outside the window');
select throws_like(format($q$update public.partner_requests set pause_ends_at = null where id = %L$q$, pg_temp.id('o1')),
                   '%partner_requests_pause_shape%', '§3 the database refuses half a pause');
select is(pg_temp.cmd(pg_temp.lead(), format($q$select public.institution_send_gap_order(%L, '4102', 'nurse_hf_fh',
            '{A1}', '{}', null, 'eeee0000-0000-4000-8183-000000000003')$q$, pg_temp.id('g1'))) ->> 'result', 'already_sent',
          '§3 a second send changes nothing');

-- §4 Take: one person, two visits -------------------------------------------------------------------------------------
select is(private.order_member_step(pg_temp.id('o1'), pg_temp.team(), pg_temp.u('11')), 4, '§4 the HF nurse is eligible');
select pg_temp.act_as(pg_temp.u('11')::text);
set local role authenticated;
select is(public.take_order(pg_temp.id('o1'), pg_temp.team(), pg_temp.u('11'), 'ffff0000-0000-4000-8183-000000000001')
            ->> 'result', 'ok', '§4 she takes the whole order');
reset role;
select pg_temp.as_owner();
create temp table tv as
  select v.* from public.care_visits v join public.order_takes k on k.id = v.order_take_id
  where k.order_id = pg_temp.id('o1') and k.released_at is null;
select is((select count(*)::int from tv), 2, '§4 the take writes two visits');
select is((select string_agg(take_block::text || ':' || to_char(time_start, 'HH24:MI') || '-' || to_char(time_end, 'HH24:MI'),
                             ',' order by take_block) from tv), '1:07:00-11:30,2:16:00-20:00',
          '§4 block 1 07:00–11:30 and block 2 16:00–20:00; no visit over the pause');
select is((select count(distinct responsible_user_id)::int || '/' || count(distinct visit_date)::int || '/'
                  || min(status) || '/' || count(distinct team_id)::int from tv), '1/1/planned/1',
          '§4 one person, one work date, both planned, one team');
select ok((select bool_and(v.responsible_user_id = pg_temp.u('11')) from tv v), '§4 both visits name her');
select is((select sum(extract(epoch from (time_end - time_start)) / 60)::int from tv), 510,
          '§4 planned minutes of the two visits = 510, the pause not counted');
select is((select count(*)::int from public.visit_activities a where a.visit_id in (select id from tv)), 2,
          '§4 the order''s activity on each visit');
select throws_ok(format($q$insert into public.care_visits (organization_id, team_id, visit_date, time_start, time_end,
                    status, responsible_user_id, order_take_id, take_block) select organization_id, team_id, visit_date,
                    time_start, time_end, 'planned', responsible_user_id, order_take_id, 2 from public.care_visits
                    where id = %L$q$, (select id from tv where take_block = 2)),
                 '23505', null, '§4 one visit per block of a take (unique index)');
select is((select count(*)::int from public.audit_events a where a.entity_id in (select id from tv)
             and a.changed ? 'take_block'), 2, '§4 the block of each take visit is audited');

-- §5 CGR-288 (a) and (b) ----------------------------------------------------------------------------------------------
insert into ids values ('pause', pg_temp.order_at('12:00', '14:00', 'eeee0000-0000-4000-8183-000000000010'));
select ok(pg_temp.id('pause') is not null, '§5 precondition: a second order 12:00–14:00 inside the pause exists');
select is(private.order_member_step(pg_temp.id('pause'), pg_temp.team(), pg_temp.u('11')), 3,
          '§5 CGR-288 (a): the order inside the pause is refused for her (the pause is busy)');
select is(private.order_member_step(pg_temp.id('pause'), pg_temp.team(), pg_temp.u('12')), 4,
          '§5 CGR-288 (a): a colleague stays eligible for it');
select pg_temp.act_as(pg_temp.u('11')::text);
set local role authenticated;
select isnt(public.take_order(pg_temp.id('pause'), pg_temp.team(), pg_temp.u('11'), 'ffff0000-0000-4000-8183-000000000002')
              ->> 'result', 'ok', '§5 CGR-288 (a): her take of the order in the pause is refused');
reset role;
select pg_temp.as_owner();
insert into ids values ('after', pg_temp.order_at('20:00', '22:00', 'eeee0000-0000-4000-8183-000000000011'));
insert into ids values ('late', pg_temp.order_at('19:00', '21:00', 'eeee0000-0000-4000-8183-000000000012'));
select is(private.order_member_step(pg_temp.id('late'), pg_temp.team(), pg_temp.u('11')), 3,
          '§5 CGR-288 (b): an order overlapping block 2 is refused for her');
select is(private.order_member_step(pg_temp.id('after'), pg_temp.team(), pg_temp.u('11')), 4,
          '§5 CGR-288 (b): her busy span ends exactly at the end of block 2 (the rest reference point)');
select is((select ends_at from public.partner_requests where id = pg_temp.id('o1')),
          (select max(private.at_zurich(visit_date + time_end)) from tv),
          '§5 CGR-288 (b): the order end equals the end of the block-2 visit');

-- §6 Qualification unchanged ------------------------------------------------------------------------------------------
select is(private.order_member_step(pg_temp.id('o1'), pg_temp.team(), pg_temp.u('13')), 1,
          '§6 a FaGe member is refused at the grade step for the HF split order');

-- §7 A release before the start ends both visits (CGR-242) ------------------------------------------------------------
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  (pg_temp.org(), pg_temp.team(), pg_temp.u('11'), '2026-11-19 17:00:00+01', '2026-11-19 18:00:00+01', pg_temp.u('09'));
select ok((select released_at is not null from public.order_takes k where k.order_id = pg_temp.id('o1')
           and k.member_id = pg_temp.u('11')), '§7 her absence in block 2 releases the take before the start');
select is((select string_agg(status, ',' order by take_block) from public.care_visits where id in (select id from tv)),
          'cancelled,cancelled', '§7 both visits end, never only one');
select is((select count(*)::int from public.care_visits where id in (select id from tv)), 2, '§7 ended, never deleted');

-- §8 Invoice draft and time check per visit (brief scope 6; ADR-229 (4)) ---------------------------------------------
-- A second split order (Fri 20.11., 07:00–11:30 und 16:00–20:00), its pause set by the private writer as in the send
-- path; M12 takes it, works both blocks exactly and signs both reports.
create function pg_temp.split_order(p_day text, p_key text) returns uuid language plpgsql as $$
declare oid uuid;
begin
  oid := (pg_temp.cmd(pg_temp.lead(), format($q$select public.confirm_client_order('00000000-0000-4000-a000-0000000003c1',
            %L, '07:00', '20:00', '4102', 'nurse_hf_fh', '{A1}', '{}', null, %L)$q$, p_day, p_key)) ->> 'order_id')::uuid;
  perform private.order_set_pause(oid, p_day::date, '11:30', '16:00');
  return oid;
end $$;
insert into ids values ('o2', pg_temp.split_order('2026-11-20', 'eeee0000-0000-4000-8183-000000000020'));
select is(pg_temp.cmd(pg_temp.u('12')::text, format('select public.set_team_price(%L, 72.00, %L)', pg_temp.team(),
            'eeee0000-0000-4000-8183-000000000021')) ->> 'result', 'ok', '§8 the team sets its own price (Beispielwert, kein Tarif)');
select pg_temp.act_as(pg_temp.u('12')::text);
set local role authenticated;
select is(public.take_order(pg_temp.id('o2'), pg_temp.team(), pg_temp.u('12'), 'ffff0000-0000-4000-8183-000000000020')
            ->> 'result', 'ok', '§8 M12 takes the second split order');
reset role;
select pg_temp.as_owner();
create function pg_temp.bv(p_order uuid, p_block int) returns uuid language sql as $$
  select v.id from public.care_visits v join public.order_takes k on k.id = v.order_take_id
  where k.order_id = p_order and k.released_at is null and coalesce(v.take_block, 1) = p_block $$;
create function pg_temp.worked(p_visit uuid, p_from timestamptz, p_to timestamptz, p_n int) returns uuid language plpgsql as $$
declare rid uuid := ('a1830000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
begin
  insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at)
  select cv.organization_id, cv.id, cv.team_id, x.kind, x.f, x.t, pg_temp.u('12'), x.at
  from public.care_visits cv,
       (values ('departed', 'planned', 'on_the_way', p_from - interval '20 minutes', 0),
               ('started', 'on_the_way', 'started', p_from, 1),
               ('completed', 'started', 'completed', p_to, 2)) as x(kind, f, t, at, o)
  where cv.id = p_visit order by x.o;
  insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot,
                                    performer_id, countersign_required, created_by)
  select cv.organization_id, rid, cv.id, null, cv.team_id, 1, 'draft', private.visit_report_snapshot(cv.id),
         pg_temp.u('12'), false, pg_temp.u('12')
  from public.care_visits cv where cv.id = p_visit;
  return rid;
end $$;
create function pg_temp.sign(rid uuid, p_key text) returns text language sql as $$
  select pg_temp.cmd(pg_temp.u('12')::text, format('select public.sign_report(%L, %L, %L)', rid,
    (select private.report_snapshot_hash(private.visit_report_snapshot(r.visit_id)) from public.visit_reports r where r.id = rid),
    p_key)) ->> 'result' $$;
insert into ids values
  ('r1', pg_temp.worked(pg_temp.bv(pg_temp.id('o2'), 1), '2026-11-20 07:00+01', '2026-11-20 11:30+01', 1)),
  ('r2', pg_temp.worked(pg_temp.bv(pg_temp.id('o2'), 2), '2026-11-20 16:00+01', '2026-11-20 20:00+01', 2));
select set_config('navora.test_now', '2026-11-20 20:30:00+01', true);
select is(pg_temp.sign(pg_temp.id('r1'), 'eeee0000-0000-4000-8183-000000000022') || '/'
          || pg_temp.sign(pg_temp.id('r2'), 'eeee0000-0000-4000-8183-000000000023'), 'ok/ok', '§8 she signs both block reports');
create temp table drafts as
  select v.take_block, d.* from public.team_invoice_drafts d join public.care_visits v on v.id = d.visit_id
  where d.order_id = pg_temp.id('o2') and d.state in ('draft', 'sent');
select is((select count(*)::int from drafts), 2, '§8 one live draft per block (two for the one take), never already_drafted');
select is((select string_agg(take_block || ':' || ordered_minutes || '/' || recorded_minutes || '/' || amount_chf, ','
                             order by take_block) from drafts), '1:270.00/270.00/324.00,2:240.00/240.00/288.00',
          '§8 ordered minutes per block (never 780 with the pause), recorded from each signed report, amount per block');
select is((select count(distinct take_id)::int from drafts), 1, '§8 both drafts belong to the one take (one price snapshot)');
select is((select count(*)::int from public.team_invoice_drafts where order_id = pg_temp.id('o2') and state = 'refused'), 0,
          '§8 no refusal (no times_disagree against the whole window)');
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);

-- §9 take_member_dropped per visit (ADR-229 (5)) ------------------------------------------------------------------------
insert into ids values ('o3', pg_temp.split_order('2026-11-21', 'eeee0000-0000-4000-8183-000000000030'));
select pg_temp.act_as(pg_temp.u('11')::text);
set local role authenticated;
select is(public.take_order(pg_temp.id('o3'), pg_temp.team(), pg_temp.u('11'), 'ffff0000-0000-4000-8183-000000000030')
            ->> 'result', 'ok', '§9 M11 takes the third split order');
reset role;
select pg_temp.as_owner();
select set_config('navora.test_now', '2026-11-21 09:00:00+01', true);
insert into public.member_absences (organization_id, team_id, user_id, starts_at, ends_at, recorded_by) values
  (pg_temp.org(), pg_temp.team(), pg_temp.u('11'), '2026-11-21 08:30:00+01', '2026-11-21 21:00:00+01', pg_temp.u('09'));
create function pg_temp.dropped() returns text language sql as $$
  select coalesce(string_agg(replace(exception_key, (select id::text from public.order_takes k
                                                      where k.order_id = pg_temp.id('o3')), 'T'), ',' order by exception_key), '')
  from private.derived_exceptions_of(pg_temp.org(), array['take_member_dropped'])
  where entity_id in (pg_temp.bv(pg_temp.id('o3'), 1), pg_temp.bv(pg_temp.id('o3'), 2)) $$;
select is(pg_temp.dropped(), 'take_member_dropped:T',
          '§9 at 09:00 only block 1 is flagged (planned after its start); block 2 has not started, the key is unchanged');
select set_config('navora.test_now', '2026-11-21 16:30:00+01', true);
select is(pg_temp.dropped(), 'take_member_dropped:T,take_member_dropped:T:2',
          '§9 at 16:30 block 2 is flagged too, under its own key (never two rows with one key)');
select ok((select released_at is null from public.order_takes where order_id = pg_temp.id('o3')),
          '§9 after the start the take stays (CGR-242, CGR-250); the signal is the path');
select set_config('navora.test_now', '2026-11-16 12:00:00+01', true);

-- §10 Display minutes without the pause (team offers and the client list) ----------------------------------------------
select is(pg_temp.cmd(pg_temp.lead(), format('select x.duration_minutes from public.client_orders() x where x.id = %L',
            pg_temp.id('o2'))) #>> '{}', '510', '§10 the home''s order list reads 510 minutes, not 780');
select is(pg_temp.cmd(pg_temp.u('12')::text, format('select x.duration_minutes from public.team_order_offers() x where x.order_id = %L',
            pg_temp.id('o2'))) #>> '{}', '510', '§10 the team''s offer list reads 510 minutes, not 780');

-- One-block regression (pgTAP 148, 156, 161 stay unchanged): a one-block order writes one visit, take_block NULL.
insert into ids values ('one', pg_temp.order_at('07:00', '11:00', 'eeee0000-0000-4000-8183-000000000013'));
select pg_temp.act_as(pg_temp.u('12')::text);
set local role authenticated;
select is(public.take_order(pg_temp.id('one'), pg_temp.team(), pg_temp.u('12'), 'ffff0000-0000-4000-8183-000000000003')
            ->> 'result', 'ok', 'regression: a one-block order is taken as before');
reset role;
select pg_temp.as_owner();
select is((select count(*)::int || '/' || coalesce(max(take_block)::text, 'null') from public.care_visits v
             join public.order_takes k on k.id = v.order_take_id where k.order_id = pg_temp.id('one')), '1/null',
          'regression: one visit, no block number');

select * from finish();
rollback;
