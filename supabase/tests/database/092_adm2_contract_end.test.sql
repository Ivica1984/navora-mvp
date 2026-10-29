-- ADM2 part (b): the recorded contract end ends access on time (migration 0092, ADR-115). Brief `docs/agents/briefs/ADM2.md`
-- ADM2-11 to ADM2-15; `cra` CGR-72 remediation plan. All data synthetic.
-- Seed users: pflege …902 (RN, Nord) · assist …906 (CA, Nord) · coach …901 · ops …904 · admin …905 (org A) · fremd …903
-- (admin of org B). Synthetic users added here: …9201 "L", Nord RN who leaves (primary nurse of case X = 208, deputy of
-- case Y) · …9202 Mitte RN · …9203 "L2" Nord RN whose end date is moved · …9204 / …9205 Nord care assistants whose
-- contracts end on the nights around the clock change · …9206 Nord care assistant whose contract starts later.
begin;
create extension if not exists pgtap with schema extensions;

select plan(100);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create function pg_temp.t0() returns date language sql as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
create temp table d0 as select pg_temp.t0() as t;   -- day T, fixed for the whole file
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;
-- E = T + 20: L's contract end.
create function pg_temp.e() returns date language sql stable as $$ select pg_temp.t() + 20 $$;
create function pg_temp.at(p_local timestamp) returns void language sql as $$
  select set_config('navora.test_now', private.at_zurich(p_local)::text, true) $$;
create function pg_temp.at_utc(p_instant timestamptz) returns void language sql as $$
  select set_config('navora.test_now', p_instant::text, true) $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                 when 'admin' then '00000000-0000-4000-a000-000000000905' when 'fremd' then '00000000-0000-4000-a000-000000000903'
                 when 'l' then 'a0920000-0000-4000-a000-000000009201' when 'mitte' then 'a0920000-0000-4000-a000-000000009202'
                 when 'l2' then 'a0920000-0000-4000-a000-000000009203' when 'd1' then 'a0920000-0000-4000-a000-000000009204'
                 when 'd2' then 'a0920000-0000-4000-a000-000000009205' when 's' then 'a0920000-0000-4000-a000-000000009206' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0921000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.cmd(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select to_jsonb(x) from (%s) s(x)', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
create function pg_temp.res(p_user text, p_sql text) returns text language sql as $$
  select coalesce(r ->> 'result', r #>> '{}') from (select pg_temp.cmd(p_user, p_sql) as r) s $$;
create function pg_temp.set_end(p_user text, p_who text, p_end date, k int) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, format('select public.set_member_contract_end(%L, %L, %L)', pg_temp.u(p_who), p_end, pg_temp.k(k))) $$;
create function pg_temp.handover(p_user text) returns jsonb language sql as $$
  select pg_temp.cmd(p_user, 'select public.contract_end_handover()') $$;
create function pg_temp.leaver(p_user text, p_who text) returns jsonb language sql as $$
  select x from jsonb_array_elements(pg_temp.handover(p_user)) x where x ->> 'user_id' = pg_temp.u(p_who)::text $$;
create function pg_temp.items(p_user text) returns text language sql as $$
  select coalesce(string_agg(x ->> 'case_id' || '=' || (x ->> 'role'), ',' order by x ->> 'case_id', x ->> 'role'), '')
  from jsonb_array_elements(pg_temp.cmd(p_user, 'select public.team_successor_items()')) x $$;
create function pg_temp.ops_successor() returns text language sql as $$
  select coalesce(string_agg((x ->> 'case_id') || '=' || split_part(x ->> 'exception_key', ':', 3), ','
                             order by x ->> 'case_id', split_part(x ->> 'exception_key', ':', 3)), '')
  from jsonb_array_elements(pg_temp.cmd('ops', 'select coalesce(jsonb_agg(to_jsonb(o)), ''[]'') from public.operations_exceptions() o')) x
  where x ->> 'exception_type' = 'successor_needed' $$;
create function pg_temp.ended(p_who text) returns boolean language sql as $$ select private.access_ended(pg_temp.u(p_who)) $$;

-- Synthetic accounts and data (as the table owner) -------------------------------------------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), 'adm2b-' || n || '@navora.test' from unnest(array['l', 'mitte', 'l2', 'd1', 'd2', 's']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select '00000000-0000-4000-b000-000000000011', pg_temp.u(n), 'nurse' from unnest(array['l', 'mitte', 'l2', 'd1', 'd2', 's']) n;
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('l'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('l2'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('d1'), 'care_assistant'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('d2'), 'care_assistant'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('s'), 'care_assistant');
-- Case X = 208 (Nord): L is primary nurse. Case Y (Nord, synthetic): L is deputy, pflege primary.
insert into public.cases (organization_id, id, name, first_name, last_name, region, status, urgency, assigned_team, assigned_team_id)
values ('00000000-0000-4000-b000-000000000011', 'a0920000-0000-4000-8000-0000000002f1', 'Testfall Y', 'Testfall', 'Y',
        'Bern West', 'laufend', 'mittel', 'Testteam Nord', '00000000-0000-4000-a000-000000000101');
update public.cases set primary_nurse_id = pg_temp.u('l') where id = '00000000-0000-4000-a000-000000000208';
update public.cases set primary_nurse_id = pg_temp.u('p'), deputy_nurse_id = pg_temp.u('l') where id = 'a0920000-0000-4000-8000-0000000002f1';
-- L's planned visits: v1 on E (stays hers), v2 on E + 1 (released when the end date is recorded).
insert into public.care_visits (id, organization_id, case_id, team_id, visit_date, time_start, time_end, status, planned_minutes_a, responsible_user_id)
values ('a0920000-0000-4000-8000-000000000501', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.e(), '15:00', '15:30', 'planned', 30, pg_temp.u('l')),
       ('a0920000-0000-4000-8000-000000000502', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.e() + 1, '15:00', '15:30', 'planned', 30, pg_temp.u('l')),
       ('a0920000-0000-4000-8000-000000000503', '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.t() + 4, '15:00', '15:30', 'planned', 30, pg_temp.u('l2'));

-- ADM2-11 Who may record it ---------------------------------------------------------------------------------------------------
select is(pg_temp.set_end('admin', 'l', pg_temp.e(), 1) ->> 'result', 'admission_off',
          'ADM2-11: the switch is off: admission_off (ADM1 and LEAVE1 unchanged)');
select is(pg_temp.res('admin', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(2))),
          'ok', 'the administrator switches team admission on');
select is(pg_temp.set_end('p', 'l', pg_temp.e(), 3) ->> 'result', 'rejected', 'ADM2-11: a registered nurse cannot record it');
select is(pg_temp.set_end('coach', 'l', pg_temp.e(), 4) ->> 'result', 'rejected', 'ADM2-11: a coach cannot record it');
select is(pg_temp.set_end('ops', 'l', pg_temp.e(), 5) ->> 'result', 'rejected', 'ADM2-11: Operations cannot record it');
select is(pg_temp.set_end('fremd', 'l', pg_temp.e(), 6) ->> 'result', 'rejected', 'ADM2-11: another organisation''s administrator cannot');
select is(pg_temp.set_end('admin', 'admin', pg_temp.e(), 7) ->> 'result', 'self', 'ADM2-11: not for herself');
select is(pg_temp.set_end('admin', 'l', pg_temp.t() - 1, 8) ->> 'result', 'in_past',
          'ADM2-11: an end date before today is refused (an earlier end needs end_member_access, G-23)');
select is(pg_temp.set_end('admin', 'l', null, 9) ->> 'result', 'no_contract', 'ADM2-11: nothing to remove without a contract record');

-- ADM2-11 Recorded: release in the same command -----------------------------------------------------------------------------
select is(pg_temp.set_end('admin', 'l', pg_temp.e(), 10),
          jsonb_build_object('result', 'ok', 'released', jsonb_build_object('00000000-0000-4000-a000-000000000101', 1),
                             'access_ends_on', pg_temp.e() + 1),
          'ADM2-11: recorded for an ADM1 member; her one planned visit after the end date is released to Nord; no count');
select is((select responsible_user_id from public.care_visits where id = 'a0920000-0000-4000-8000-000000000502'), null,
          'ADM2-11: the visit after the end date is open in the team');
select is((select responsible_user_id from public.care_visits where id = 'a0920000-0000-4000-8000-000000000501'), pg_temp.u('l'),
          'ADM2-11: the visit on the end date is unchanged');
select is((select pc.reason from public.visit_plan_changes pc where pc.visit_id = 'a0920000-0000-4000-8000-000000000502'
           order by pc.id desc limit 1), 'Vertragsende', 'ADM2-11: the release rule writes the fixed team text');
select is((select count(*)::int from public.audit_events a where a.command = 'set_member_contract_end'
             and a.table_name = 'care_visits' and a.entity_id = 'a0920000-0000-4000-8000-000000000502'), 1,
          'ADM2-11: the release is audited in the command''s context');
select ok(exists (select 1 from public.audit_events a where a.command = 'set_member_contract_end' and a.table_name = 'member_contract_events'
                  and a.actor_id = pg_temp.u('admin')), 'ADM2-11: the contract row is audited with the administrator');
select is((select start_date is null and end_date = pg_temp.e() from public.member_contract_events where user_id = pg_temp.u('l')), true,
          'ADM2-11: an ADM1 member''s contract record carries the end date only');
select is((select array_agg(column_name::text order by column_name) from information_schema.columns
           where table_schema = 'public' and table_name = 'member_contract_events'),
          array['actor_id', 'created_at', 'end_date', 'id', 'organization_id', 'seq', 'start_date', 'user_id'],
          'Negative: the contract record holds dates only, no field for who ended the contract or why');
select is(pg_temp.set_end('admin', 'l', pg_temp.e(), 11) ->> 'result', 'unchanged', 'ADM2-11: the same date again: unchanged');
select is(pg_temp.set_end('admin', 'l', pg_temp.e(), 10) ->> 'result', 'duplicate', 'ADM2-11: a resend is a duplicate');

-- ADM2-11 Refused as responsible after the end date --------------------------------------------------------------------------
select is(pg_temp.cmd('p', format('select public.plan_visit(%L, %L, %L, %L, 30, 0, 0, false, %L, %L)',
          '00000000-0000-4000-a000-000000000208', pg_temp.e() + 3, '09:00', '09:30', pg_temp.u('l'), pg_temp.k(20))) ->> 'reason',
          'outside_contract', 'ADM2-11: planning refuses her for a visit after the end date');
select isnt(pg_temp.cmd('p', format('select public.plan_visit(%L, %L, %L, %L, 30, 0, 0, false, %L, %L)',
          '00000000-0000-4000-a000-000000000208', pg_temp.e(), '09:00', '09:30', pg_temp.u('l'), pg_temp.k(21))) ->> 'reason',
          'outside_contract', 'ADM2-11: planning on the end date itself is not refused for the contract');
select is(pg_temp.res('l', format('select public.take_open_visit(%L, %L)', 'a0920000-0000-4000-8000-000000000502', pg_temp.k(22))),
          'outside_contract', 'ADM2-11: take refuses her for the released visit');
select is(pg_temp.cmd('l', format('select coalesce(bool_or(may_take), false) from public.team_open_visits(%L) where visit_id = %L',
          pg_temp.e(), 'a0920000-0000-4000-8000-000000000502')), 'false'::jsonb, 'ADM2-11: "Offen im Team" does not offer it to her');
select throws_ok($$update public.care_visits set responsible_user_id = 'a0920000-0000-4000-a000-000000009201'
                   where id = 'a0920000-0000-4000-8000-000000000502'$$, '42501', 'outside_contract',
                 'ADM2-11: no other path makes her responsible after the end date (backstop)');
select is((select private.adm2_in_contract('00000000-0000-4000-b000-000000000011', pg_temp.u('l'), pg_temp.e()) and
                  not private.adm2_in_contract('00000000-0000-4000-b000-000000000011', pg_temp.u('l'), pg_temp.e() + 1)), true,
          'ADM2-11: cover and PLAN2 use the same window (end date inclusive)');
select ok(position('adm2_in_contract' in (select prosrc from pg_proc where oid = 'private.cover_team_for(public.care_visits, uuid)'::regprocedure)) > 0
          and position('adm2_in_contract' in (select prosrc from pg_proc where oid = 'private.generate_case_plan(uuid, uuid)'::regprocedure)) > 0
          and position('adm2_in_contract' in (select prosrc from pg_proc
                                              where oid = 'public.change_absence(uuid, boolean, date, time without time zone, uuid)'::regprocedure)) > 0,
          'ADM2-11: cover, PLAN2 generation and the ABS1 return read the window');

-- ADM2-12 / ADM2-15 (a) / ADM2-14 Day 15: nothing shown ---------------------------------------------------------------------
select pg_temp.at((pg_temp.e() - 15) + time '10:00');
select is(pg_temp.leaver('p', 'l'), null, 'ADM2-12: day 15 before the end: not listed to the team''s RN');
select is(pg_temp.leaver('admin', 'l'), null, 'ADM2-12: day 15: not listed to the administrator');
select is(pg_temp.cmd('l', 'select public.my_contract_end()'), null::jsonb, 'ADM2-14 (a): day 15: no notice for her');

-- Day 14: listed ------------------------------------------------------------------------------------------------------------
select pg_temp.at((pg_temp.e() - 14) + time '00:00');
select is(pg_temp.leaver('p', 'l') ->> 'end_date', pg_temp.e()::text, 'ADM2-12: day 14: listed to the team''s RN with her end date');
select is(pg_temp.leaver('p', 'l') ->> 'access_ends_on', (pg_temp.e() + 1)::text, 'ADM2-12: with the day her access ends');
select is((select string_agg(x ->> 'role' || '@' || (x ->> 'case_id'), ',' order by x ->> 'role')
           from jsonb_array_elements(pg_temp.leaver('p', 'l') -> 'cases') x),
          'deputy@a0920000-0000-4000-8000-0000000002f1,primary@00000000-0000-4000-a000-000000000208',
          'ADM2-15 (a): her open cases as primary and deputy nurse');
select is((select string_agg(k, ',' order by k) from jsonb_array_elements(pg_temp.leaver('p', 'l') -> 'cases') x
           cross join lateral jsonb_object_keys(x) k where x ->> 'role' = 'primary'), 'case_id,case_ref,role,team',
          'ADM2-15 (a): a case entry is reference and role only (no client name, address or health content)');
select is((select x ->> 'case_ref' from jsonb_array_elements(pg_temp.leaver('p', 'l') -> 'cases') x where x ->> 'role' = 'primary'),
          '000208', 'ADM2-15 (a): the case reference is the last six digits of the case id');
select is((select string_agg((x ->> 'visit_date') || ':' || (x ->> 'role'), ',') from jsonb_array_elements(pg_temp.leaver('p', 'l') -> 'visits') x),
          pg_temp.e()::text || ':responsible,' || pg_temp.e()::text || ':responsible',
          'ADM2-15 (a): her visits up to and including the end date (v1 and the one planned above; the released one is gone)');
select is((select string_agg(distinct k, ',' order by k) from jsonb_array_elements(pg_temp.leaver('p', 'l') -> 'visits') x
           cross join lateral jsonb_object_keys(x) k), 'case_ref,role,team,visit_date', 'ADM2-15 (a): a visit entry is reference, date and role only');
select ok(pg_temp.leaver('admin', 'l') is not null and jsonb_array_length(pg_temp.leaver('admin', 'l') -> 'cases') = 2,
          'ADM2-12 / ADM2-15 (a): day 14: listed to the administrator with both cases');
select is(pg_temp.leaver('mitte', 'l'), null, 'ADM2-12: not to a nurse of another team');
select is(pg_temp.leaver('coach', 'l'), null, 'ADM2-12: not to a coach');
select is(pg_temp.leaver('ops', 'l'), null, 'ADM2-12: not to Operations');
select is(pg_temp.leaver('fremd', 'l'), null, 'ADM2-12: not to another organisation');
select is(pg_temp.leaver('ca', 'l'), null, 'ADM2-12: not to a care assistant of her team (registered nurses and administrators)');
select is(pg_temp.handover('l'), '[]'::jsonb, 'ADM2-12: she does not see herself in the list');
select is(pg_temp.cmd('l', 'select public.my_contract_end()'),
          jsonb_build_object('end_date', pg_temp.e(), 'access_ends_on', pg_temp.e() + 1),
          'ADM2-14 (a): day 14: she reads the date her access ends (her count stays my_unexported_working_days)');
select is(pg_temp.cmd('p', 'select public.my_contract_end()'), null::jsonb, 'ADM2-14 (a): a colleague without an end date reads nothing');
select is(pg_temp.res('admin', format('select public.prepare_member_access_end(%L, %L)', pg_temp.u('l'), pg_temp.k(30))), 'ok',
          'ADM2-14 (b): the administrator''s entry opens the recorded access-end read (0087)');
select is((select count(*)::int from public.audit_events a where a.command = 'prepare_member_access_end'
             and a.entity_id = pg_temp.u('l') and a.changed ? 'access_end_prepared' and not (a.changed ? 'unexported_days')), 1,
          'ADM2-14 (b): the read leaves its 0087 audit row, without the count');
select ok(pg_temp.handover('admin')::text !~ 'unexported' and pg_temp.cmd('l', 'select public.my_contract_end()')::text !~ 'unexported'
          and pg_temp.set_end('admin', 'l', pg_temp.e(), 11)::text !~ 'unexported',
          'ADM2-14: no new reader returns the count (recording the end date does not either)');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prosrc ~ 'my_unexported_working_days|working_day_versions'
             and p.proname in ('contract_end_handover', 'my_contract_end', 'set_member_contract_end', 'team_successor_items')), null,
          'ADM2-14: COND2-1 unchanged: none of the ADM2 functions reads the working-day record');

-- ADM2-13 Access ends without a command at the start of the Zurich day after the end date ------------------------------------
select pg_temp.at(pg_temp.e() + time '23:59');
select is(pg_temp.ended('l'), false, 'ADM2-13: on the end date at 23:59 her access is open');
select is(pg_temp.items('p'), '', 'ADM2-15 (b): before the access end no successor item');
select pg_temp.at((pg_temp.e() + 1) + time '00:00');
select is(pg_temp.ended('l'), true, 'ADM2-13: at 00:00 on the day after, her access has ended, without a command');
select is(pg_temp.cmd('l', 'select count(*) from public.cases'), '0'::jsonb, 'ADM2-13 (LEAVE1-3): she reads no case');
select throws_ok($$select pg_temp.cmd('l', format('select public.take_open_visit(%L, %L)', 'a0920000-0000-4000-8000-000000000502', pg_temp.k(40)))$$,
                 '42501', 'access_ended', 'ADM2-13 (LEAVE1-3): every command is refused for her');
select is(pg_temp.cmd('l', 'select public.my_access_state()') ->> 'ended', 'true', 'ADM2-13 (LEAVE1-6): her own state: ended');
select is((pg_temp.cmd('l', 'select public.my_access_state()') ->> 'ended_at')::timestamptz,
          private.at_zurich((pg_temp.e() + 1) + time '00:00'), 'ADM2-13: ended at the start of the day after the end date');
select ok(not (pg_temp.cmd('l', 'select public.my_access_state()') ? 'reason_code'), 'ADM2-13: her state carries no reason code');
select is(private.signal_take_lapsed(pg_temp.u('l'), null, private.at_zurich(pg_temp.e() + time '20:00')), true,
          'ADM2-13 (LEAVE1-14): a take of hers made before the end has lapsed');
select ok(not exists (select 1 from private.signal_recipients('a0920000-0000-4000-8000-000000000501') r where r.user_id = pg_temp.u('l')),
          'ADM2-13 (LEAVE1-3): she is in no signal receiver set');
select is(pg_temp.leaver('p', 'l'), null, 'ADM2-12: once her access ended she leaves the handover list');
select is((select count(*)::int from public.member_access_events where user_id = pg_temp.u('l')), 0,
          'ADM2-13 (deviation 1, ADR-115): evaluated at read time; no row in the access record');

-- ADM2-15 (b) The day after: the team and Operations see the open responsibilities ---------------------------------------------
select is(pg_temp.items('p'), '00000000-0000-4000-a000-000000000208=primary,a0920000-0000-4000-8000-0000000002f1=deputy',
          'ADM2-15 (b): Nord sees "Bezugspflege neu bestimmen" (X) and "Stellvertretung neu bestimmen" (Y)');
select is(pg_temp.items('ca'), '00000000-0000-4000-a000-000000000208=primary,a0920000-0000-4000-8000-0000000002f1=deputy',
          'ADM2-15 (b): every active member of the team sees them');
select is(pg_temp.items('mitte'), '', 'ADM2-15 (b): another team sees nothing');
select is(pg_temp.items('coach'), '', 'ADM2-15 (b): a coach sees nothing');
select is(pg_temp.ops_successor(), '00000000-0000-4000-a000-000000000208=primary,a0920000-0000-4000-8000-0000000002f1=deputy',
          'ADM2-15 (b): Operations: one OPS1 exception per case');
select is((select priority || '|' || coalesce(amount::text, '-') || '|' || coalesce(escalate_to_p1_after_hours::text, '-')
           from public.exception_rules where exception_type = 'successor_needed'), 'P2|-|-',
          'ADM2-15 (b): no threshold and no escalation clock (OPS1 continuity class)');
select is(pg_temp.res('ops', format('select public.handle_exception(%L, %L, null, %L)',
          'successor_needed:00000000-0000-4000-a000-000000000208:primary:' || pg_temp.u('l'), 'take', pg_temp.k(50))), 'ok',
          'ADM2-15 (b): Operations takes it over (existing lifecycle)');
select is(pg_temp.res('p', format('select public.set_primary_nurse(%L, %L, null, %L, %L)', '00000000-0000-4000-a000-000000000208',
          pg_temp.u('p'), 'Synthetisch: Austritt', pg_temp.k(51))), 'ok', 'ADM2-15 (b): the team names a new primary nurse (J6, unchanged)');
select is(pg_temp.items('p'), 'a0920000-0000-4000-8000-0000000002f1=deputy', 'ADM2-15 (b): X''s item is gone');
select is(pg_temp.cmd('ops', 'select public.sync_exceptions()'), '1'::jsonb, 'ADM2-15 (b): the sync closes X''s exception');
select is((select text from public.exception_events where exception_key = 'successor_needed:00000000-0000-4000-a000-000000000208:primary:'
           || pg_temp.u('l') and kind = 'auto_close'), 'Ursache behoben – automatisch geschlossen', 'ADM2-15 (b): automatically, with the note');
select is(pg_temp.ops_successor(), 'a0920000-0000-4000-8000-0000000002f1=deputy', 'ADM2-15 (b): only Y''s exception is left');
select is((select deputy_nurse_id from public.cases where id = 'a0920000-0000-4000-8000-0000000002f1'), pg_temp.u('l'),
          'ADM2-15 (b): NAVORA names nobody (the deputy is not replaced or promoted)');
select is(pg_temp.res('admin', format('select public.restore_member_access(%L, %L, %L)', pg_temp.u('l'), 'employment_resumed', pg_temp.k(52))),
          'ok', 'ADM2-13: restore_member_access works as today');
select is(pg_temp.ended('l'), false, 'ADM2-13: after the restore her access is open');
select is(pg_temp.items('p') || '|' || pg_temp.ops_successor(), '|', 'ADM2-15 (b): the restore clears Y''s item and exception');
select is(pg_temp.res('admin', format('select public.end_member_access(%L, %L, %L)', pg_temp.u('l'), 'employment_ended', pg_temp.k(53))),
          'has_cases', 'ADM2-15: the manual end_member_access still refuses with has_cases (LEAVE1-2)');
select is(pg_temp.set_end('admin', 'l', pg_temp.e(), 54) ->> 'result', 'in_past',
          'ADM2-11: after the end a new date must lie ahead (the past one stays recorded)');

-- ADM2-13 A changed end date before it passes moves the access end; released visits stay released -----------------------------
select pg_temp.at(pg_temp.t() + time '10:00');
select is(pg_temp.set_end('admin', 'l2', pg_temp.t() + 3, 60) ->> 'result', 'ok', 'ADM2-11: L2''s end date recorded (T + 3)');
select is((select responsible_user_id from public.care_visits where id = 'a0920000-0000-4000-8000-000000000503'), null,
          'ADM2-11: her visit on T + 4 is released');
select is(pg_temp.set_end('admin', 'l2', pg_temp.t() + 5, 61) ->> 'result', 'ok', 'ADM2-13: the end date is moved to T + 5');
select pg_temp.at((pg_temp.t() + 4) + time '00:00');
select is(pg_temp.ended('l2'), false, 'ADM2-13: the old access end has moved with it');
select is((select responsible_user_id from public.care_visits where id = 'a0920000-0000-4000-8000-000000000503'), null,
          'ADM2-13: the visit already released stays released');
select pg_temp.at((pg_temp.t() + 6) + time '00:00');
select is(pg_temp.ended('l2'), true, 'ADM2-13: access ends at the new date');

-- ADM2-13 / DST1: the nights the clocks change (2026-10-25 02:00-02:59 is repeated) ---------------------------------------------
select pg_temp.at(timestamp '2026-10-20 10:00');
select is(pg_temp.set_end('admin', 'd1', date '2026-10-24', 70) ->> 'result', 'ok', 'DST1: contract ends on Saturday 24 October');
select is(pg_temp.set_end('admin', 'd2', date '2026-10-25', 71) ->> 'result', 'ok', 'DST1: contract ends on Sunday 25 October');
select pg_temp.at_utc(timestamptz '2026-10-24 21:59:00+00');
select is(pg_temp.ended('d1'), false, 'DST1: 23:59 CEST on the 24th: open');
select pg_temp.at_utc(timestamptz '2026-10-24 22:00:00+00');
select is(pg_temp.ended('d1'), true, 'DST1: 00:00 CEST on the 25th (22:00 UTC): ended');
select pg_temp.at_utc(timestamptz '2026-10-25 22:30:00+00');
select is(pg_temp.ended('d2'), false, 'DST1: 23:30 CET on the 25th (a 25-hour day; 24 h after its midnight is 23:00 local): open');
select pg_temp.at_utc(timestamptz '2026-10-25 23:00:00+00');
select is(pg_temp.ended('d2'), true, 'DST1: 00:00 CET on the 26th (23:00 UTC): ended');

-- ADM2-6 Before the start date: no access ----------------------------------------------------------------------------------------
select pg_temp.at(pg_temp.t() + time '10:00');
insert into public.member_contract_events (organization_id, user_id, start_date, end_date, actor_id)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('s'), pg_temp.t() + 2, null, pg_temp.u('admin'));
select is(pg_temp.cmd('s', 'select public.my_access_state()') ->> 'starts_on', (pg_temp.t() + 2)::text,
          'ADM2-6: before her start date she has no access; her state names the start date');
select is(pg_temp.cmd('s', 'select count(*) from public.cases'), '0'::jsonb, 'ADM2-6: she reads nothing before the start date');
select pg_temp.at((pg_temp.t() + 2) + time '00:00');
select is(pg_temp.ended('s'), false, 'ADM2-6: from the start date her access is open');

-- ADM2-8 clarified (po 2026-10-29 06:10): an admitted proposal without "Vertrag erfasst" lapses 14 days after admission -----
select pg_temp.at((pg_temp.t() + 30) + time '10:00');
create temp table fx8 as
select (pg_temp.cmd('p', format('select public.propose_team_candidate(%L, %L, %L, %L, %L)', '00000000-0000-4000-a000-000000000101',
        'Kandidatin Ohne Vertrag', 'care_assistant', '40-60', pg_temp.k(80))) ->> 'proposal_id')::uuid as id;
select pg_temp.cmd('ca', format('select public.decide_team_candidate(%L, %L, null, %L)', (select id from fx8), 'consent', pg_temp.k(81)));
select is(pg_temp.cmd('s', format('select public.decide_team_candidate(%L, %L, null, %L)', (select id from fx8), 'consent', pg_temp.k(82)))
          ->> 'outcome', 'admitted', 'ADM2-8: the team admits her (two consents)');
select pg_temp.at((pg_temp.t() + 44) + time '09:59');
select is((select x ->> 'outcome' from jsonb_array_elements(pg_temp.cmd('p', format('select public.team_admissions(%L)',
           '00000000-0000-4000-a000-000000000101')) -> 'proposals') x where x ->> 'proposal_id' = (select id::text from fx8)), 'admitted',
          'ADM2-8: one minute before 14 days after the admission she is still admitted');
select is((select count(*)::int from public.team_candidates where proposal_id = (select id from fx8)), 1,
          'ADM2-8: with her candidate record');
select pg_temp.at((pg_temp.t() + 44) + time '10:00');
select is(pg_temp.res('admin', format('select public.record_member_contract(%L, %L, %L, null, %L)', (select id from fx8),
          'adm2b-mitte@navora.test', pg_temp.t() + 44, pg_temp.k(83))), 'not_admitted',
          'ADM2-8: 14 days after the admission without a contract: lapsed, "Vertrag erfasst" refused');
select is(private.adm2_outcome((select id from fx8))::text, 'lapsed', 'ADM2-8: the outcome is lapsed');
select is((select count(*)::int from public.team_candidates where proposal_id = (select id from fx8)), 0,
          'ADM2-8: her candidate data are deleted in the same transaction');

select * from finish();
rollback;
