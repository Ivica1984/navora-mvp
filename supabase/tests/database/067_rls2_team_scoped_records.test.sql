-- RLS2: visit and case records are read only by the people who care for the client (migration 0066, ADR-080).
-- Brief `docs/agents/briefs/RLS2.md` (RLS2-1 to RLS2-7); inventory `docs/engineering/READ_PATHS.md`.
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · care assistant …906 (Nord) · coach …901 · operations …904 ·
-- admin …905 (org A, no team) · admin …903 (org B). Synthetic users added here: …6701 registered nurse of Testteam Mitte …102
-- (same organisation and region as Nord, no cover), …6702 registered nurse of Mitte who covers one Nord visit, …6703 care
-- assistant of Nord who is removed during the test, …6704 an account without any membership. Cases …208 (Nord) and
-- …205 (Mitte); the matching request is on the unassigned case …201. All data synthetic; fixtures are written as the table owner, reads go through `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(128);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                 when 'admin' then '00000000-0000-4000-a000-000000000905' when 'admin_b' then '00000000-0000-4000-a000-000000000903'
                 when 'mitte' then 'a0670000-0000-4000-a000-000000006701' when 'cover' then 'a0670000-0000-4000-a000-000000006702'
                 when 'leaver' then 'a0670000-0000-4000-a000-000000006703' when 'outsider' then 'a0670000-0000-4000-a000-000000006704' end)::uuid
$$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a0670000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0670000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid $$;
-- Count what `p_user` reads through `authenticated` (RLS and grants apply), then return to the table owner.
create function pg_temp.seen(p_user text, p_sql text) returns integer language plpgsql as $$
declare n integer;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.u(p_user)::text, true);
  execute 'set local role authenticated';
  execute 'select count(*)::int from (' || p_sql || ') x' into n;
  execute 'reset role';
  return n;
end $$;
create function pg_temp.as_user(p_user text, p_sql text) returns text language plpgsql as $$
declare r text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.u(p_user)::text, true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end $$;

-- Synthetic accounts and fixtures (as the table owner) -----------------------------------------------------------------
insert into auth.users (id, email) values
  (pg_temp.u('mitte'), 'rls2-mitte@navora.test'), (pg_temp.u('cover'), 'rls2-cover@navora.test'),
  (pg_temp.u('leaver'), 'rls2-leaver@navora.test'), (pg_temp.u('outsider'), 'rls2-outsider@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('cover'), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('leaver'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('cover'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000101', pg_temp.u('leaver'), 'care_assistant');

-- v1, v2: Nord (case 208); v2 is covered by …6702 of Mitte. v3: Mitte (case 205).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   (private.now() at time zone 'Europe/Zurich')::date + 1, '06:10', '06:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   (private.now() at time zone 'Europe/Zurich')::date + 1, '07:10', '07:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000205', '00000000-0000-4000-a000-000000000102',
   (private.now() at time zone 'Europe/Zurich')::date + 1, '08:10', '08:40', false, 'planned');
update public.care_visits set covered_by = pg_temp.u('cover'), covered_at = private.now(), cover_team_id = '00000000-0000-4000-a000-000000000102'
where id = pg_temp.v(2);

insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000101', 'departed', 'planned', 'on_the_way', pg_temp.u('rn'), private.now() - interval '50 minutes'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000101', 'started', 'on_the_way', 'started', pg_temp.u('rn'), private.now() - interval '40 minutes'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000101', 'departed', 'planned', 'on_the_way', pg_temp.u('ca'), private.now() - interval '30 minutes'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000102', 'departed', 'planned', 'on_the_way', pg_temp.u('mitte'), private.now() - interval '20 minutes');
insert into public.visit_time_corrections (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key)
select e.organization_id, e.visit_id, e.team_id, e.id, e.occurred_at - interval '5 minutes', 'Synthetisch: RLS2 Korrekturgrund ' || e.visit_id,
       e.actor_id, pg_temp.k(e.id::int)
from public.visit_events e where e.visit_id in (pg_temp.v(1), pg_temp.v(2), pg_temp.v(3)) and e.event_type = 'departed';

insert into public.matching_requests (id, organization_id, case_id, request_title, region, urgency, status) values
  (pg_temp.v(10), '00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000201', 'RLS2 Anfrage', 'Bern West', 'mittel', 'open');
insert into public.team_decisions (organization_id, matching_request_id, case_id, team_id, decision, reason, reason_code, actor_id, idempotency_key) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(10), '00000000-0000-4000-a000-000000000201', '00000000-0000-4000-a000-000000000101',
   'decline', 'Synthetisch: RLS2 Ablehnungsgrund Nord', 'capacity', pg_temp.u('rn'), pg_temp.k(101)),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(10), '00000000-0000-4000-a000-000000000201', '00000000-0000-4000-a000-000000000102',
   'decline', 'Synthetisch: RLS2 Ablehnungsgrund Mitte', 'distance', pg_temp.u('mitte'), pg_temp.k(102));

insert into public.case_tasks (organization_id, case_id, kind) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'access_unknown'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000205', 'language_unknown');

create temp table q (name text primary key, sql text not null);
grant select on q to authenticated;
insert into q values
  ('ve_nord',  format('select 1 from public.visit_events where visit_id in (%L, %L)', pg_temp.v(1), pg_temp.v(2))),
  ('ve_v1',    format('select 1 from public.visit_events where visit_id = %L', pg_temp.v(1))),
  ('ve_v2',    format('select 1 from public.visit_events where visit_id = %L', pg_temp.v(2))),
  ('ve_v3',    format('select 1 from public.visit_events where visit_id = %L', pg_temp.v(3))),
  ('vtc_nord', format('select 1 from public.visit_time_corrections where visit_id in (%L, %L)', pg_temp.v(1), pg_temp.v(2))),
  ('vtc_v1',   format('select 1 from public.visit_time_corrections where visit_id = %L', pg_temp.v(1))),
  ('vtc_v2',   format('select 1 from public.visit_time_corrections where visit_id = %L', pg_temp.v(2))),
  ('vtc_v3',   format('select 1 from public.visit_time_corrections where visit_id = %L', pg_temp.v(3))),
  ('td_nord',  format('select 1 from public.team_decisions where matching_request_id = %L and team_id = %L', pg_temp.v(10), '00000000-0000-4000-a000-000000000101')),
  ('td_mitte', format('select 1 from public.team_decisions where matching_request_id = %L and team_id = %L', pg_temp.v(10), '00000000-0000-4000-a000-000000000102')),
  ('td_all',   'select 1 from public.team_decisions'),
  ('ct_nord',  'select 1 from public.case_tasks where case_id = ''00000000-0000-4000-a000-000000000208'''),
  ('ct_mitte', 'select 1 from public.case_tasks where case_id = ''00000000-0000-4000-a000-000000000205''');
create function pg_temp.n(p_user text, p_q text) returns integer language sql as $$
  select pg_temp.seen(p_user, (select sql from q where name = p_q)) $$;

-- Structure: one team-scoped read policy per table; no coordination role in it; anon reads nothing -------------------
select is((select string_agg(c.relname || ':' || p.polname, ',' order by c.relname)
           from pg_policy p join pg_class c on c.oid = p.polrelid
           where c.relname in ('visit_events', 'visit_time_corrections', 'team_decisions', 'case_tasks') and p.polcmd in ('r', '*') and p.polpermissive),  -- LEAVE1 (0074) adds a restrictive policy to every table
  'case_tasks:team_scoped_read,team_decisions:team_scoped_read,visit_events:team_scoped_read,visit_time_corrections:team_scoped_read',
  'RLS2-2: each of the four tables has exactly one permissive read policy, team_scoped_read');
select is((select count(*)::int from pg_policy p join pg_class c on c.oid = p.polrelid
           where c.relname in ('visit_events', 'visit_time_corrections', 'team_decisions', 'case_tasks')
             and pg_get_expr(p.polqual, p.polrelid) ~ '(is_coordinator|has_org_role|is_intake_role|is_org_admin)'), 0,
  'RLS2-2 (c): no read policy of the four tables admits a coordination role');
select ok(not has_function_privilege('anon', 'private.reads_visit(uuid)', 'execute')
          and not has_function_privilege('anon', 'private.reads_case(uuid)', 'execute'), 'anon cannot execute the predicates');
select throws_ok('set local role anon; select 1 from public.visit_events', '42501', null, 'RLS2-2: anon reads no visit_events');
reset role;
select throws_ok('set local role anon; select 1 from public.visit_time_corrections', '42501', null, 'RLS2-2: anon reads no visit_time_corrections');
reset role;
select throws_ok('set local role anon; select 1 from public.team_decisions', '42501', null, 'RLS2-2: anon reads no team_decisions');
reset role;
select throws_ok('set local role anon; select 1 from public.case_tasks', '42501', null, 'RLS2-2: anon reads no case_tasks');
reset role;

-- RLS2-2 visit_events -------------------------------------------------------------------------------------------------
select is(pg_temp.n('rn', 've_nord'), 3, 'visit_events: a nurse of Nord reads Nord''s rows');
select is(pg_temp.n('ca', 've_nord'), 3, 'visit_events: a care assistant of Nord reads them too (team, not person)');
select is(pg_temp.n('mitte', 've_nord'), 0, 'visit_events: a nurse of Mitte (same organisation, same region) reads 0 rows of Nord');
select is(pg_temp.n('mitte', 've_v3'), 1, 'visit_events: … and reads her own team''s row');
select is(pg_temp.n('admin_b', 've_nord'), 0, 'visit_events: a member of another organisation reads 0');
select is(pg_temp.n('outsider', 've_nord'), 0, 'visit_events: an account without membership reads 0');
select is(pg_temp.n('ops', 've_nord'), 0, 'visit_events: Operations reads 0 rows through the table API (RLS2-2 c)');
select is(pg_temp.n('coach', 've_nord'), 0, 'visit_events: a coach reads 0');
select is(pg_temp.n('admin', 've_nord'), 0, 'visit_events: an administrator reads 0');
select is(pg_temp.n('cover', 've_v2'), 1, 'visit_events: the covering member reads the covered visit''s row while the cover is active');
select is(pg_temp.n('cover', 've_v1'), 0, 'visit_events: … but no other visit of the case');
-- RLS2-2 visit_time_corrections -------------------------------------------------------------------------------------
select is(pg_temp.n('rn', 'vtc_nord'), 2, 'visit_time_corrections: a nurse of Nord reads Nord''s rows');
select is(pg_temp.n('mitte', 'vtc_nord'), 0, 'visit_time_corrections: a nurse of Mitte reads 0 rows of Nord');
select is(pg_temp.n('mitte', 'vtc_v3'), 1, 'visit_time_corrections: … and her own team''s row');
select is(pg_temp.n('admin_b', 'vtc_nord'), 0, 'visit_time_corrections: another organisation reads 0');
select is(pg_temp.n('ops', 'vtc_nord'), 0, 'visit_time_corrections: Operations reads 0');
select is(pg_temp.n('coach', 'vtc_nord'), 0, 'visit_time_corrections: a coach reads 0');
select is(pg_temp.n('admin', 'vtc_nord'), 0, 'visit_time_corrections: an administrator reads 0');
select is(pg_temp.n('cover', 'vtc_v2'), 1, 'visit_time_corrections: the covering member reads the covered visit''s row');
select is(pg_temp.n('cover', 'vtc_v1'), 0, 'visit_time_corrections: … and nothing else of Nord');
-- RLS2-2 team_decisions -----------------------------------------------------------------------------------------------
select is(pg_temp.n('rn', 'td_nord'), 1, 'team_decisions: a nurse of Nord reads Nord''s decision');
select is(pg_temp.n('rn', 'td_mitte'), 0, 'team_decisions: … not Mitte''s (other teams'' decisions stay invisible, 0017)');
select is(pg_temp.n('mitte', 'td_nord'), 0, 'team_decisions: a nurse of Mitte reads 0 of Nord');
select is(pg_temp.n('admin_b', 'td_all'), 0, 'team_decisions: another organisation reads 0');
select is(pg_temp.n('ops', 'td_all'), 0, 'team_decisions: Operations reads 0 rows (0017 allowed every coordination role)');
select is(pg_temp.n('coach', 'td_all'), 0, 'team_decisions: a coach reads 0');
select is(pg_temp.n('admin', 'td_all'), 0, 'team_decisions: an administrator reads 0');
select is(pg_temp.n('cover', 'td_nord'), 0, 'team_decisions: a cover never opens the case''s decisions');
-- RLS2-2 case_tasks ---------------------------------------------------------------------------------------------------
select is(pg_temp.n('rn', 'ct_nord'), 1, 'case_tasks: a nurse of Nord reads the task of Nord''s case');
select is(pg_temp.n('mitte', 'ct_nord'), 0, 'case_tasks: a nurse of Mitte reads 0 of Nord''s case');
select is(pg_temp.n('mitte', 'ct_mitte'), 1, 'case_tasks: … and her own team''s case task');
select is(pg_temp.n('admin_b', 'ct_nord'), 0, 'case_tasks: another organisation reads 0');
select is(pg_temp.n('ops', 'ct_nord'), 0, 'case_tasks: Operations reads 0 rows through the table API');
select is(pg_temp.n('coach', 'ct_nord'), 0, 'case_tasks: a coach reads 0');
select is(pg_temp.n('admin', 'ct_nord'), 0, 'case_tasks: an administrator reads 0');
select is(pg_temp.n('cover', 'ct_nord'), 0, 'case_tasks: a cover never opens the case''s tasks');
select is(pg_temp.as_user('ops', $$ select array_to_string(open_tasks, ',') from public.case_funding_facts('00000000-0000-4000-a000-000000000208') $$),
  'access_unknown', 'case_tasks: Operations (intake role) still sees the open task kind through case_funding_facts (named task: intake)');
select is(pg_temp.as_user('rn', $$ select array_to_string(open_tasks, ',') from public.team_cases() where case_id = '00000000-0000-4000-a000-000000000208' $$),
  'access_unknown', 'case_tasks: Nord sees its open task kind in team_cases (unchanged)');

-- Cover ends: the read ends with it -------------------------------------------------------------------------------------
update public.care_visits set covered_by = null, covered_at = null, cover_team_id = null where id = pg_temp.v(2);
select is(pg_temp.n('cover', 've_v2'), 0, 'visit_events: 0 rows after the cover ends (withdrawn)');
select is(pg_temp.n('cover', 'vtc_v2'), 0, 'visit_time_corrections: 0 rows after the cover ends');
update public.care_visits set covered_by = pg_temp.u('cover'), covered_at = private.now(), cover_team_id = '00000000-0000-4000-a000-000000000102'
where id = pg_temp.v(2);
delete from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000102' and user_id = pg_temp.u('cover');
select is(pg_temp.n('cover', 've_v2'), 0, 'visit_events: 0 rows once the covering member has left her cover team');
insert into public.team_memberships (team_id, user_id, qualification) values ('00000000-0000-4000-a000-000000000102', pg_temp.u('cover'), 'registered_nurse');
select is(pg_temp.n('cover', 've_v2'), 1, 'fixture: the cover is active again');
-- A final report ends the covering read (D-3 PO 2026-10-22 14:30: "until its report is final"). Synthetic report row, as the owner.
insert into public.visit_reports (organization_id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by, signed_by, signed_at)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        1, 'final', '{}'::jsonb, pg_temp.u('rn'), false, pg_temp.u('rn'), pg_temp.u('rn'), private.now());
select is(pg_temp.n('cover', 've_v2'), 0, 'visit_events: 0 rows once the covered visit''s report is final');
select is(pg_temp.n('cover', 'vtc_v2'), 0, 'visit_time_corrections: 0 rows once the covered visit''s report is final');
select is(pg_temp.n('rn', 've_v2'), 1, 'visit_events: the team keeps reading the visit after its report is final');

-- RLS2-7: a removed member reads nothing of her former team immediately --------------------------------------------------
select is(pg_temp.n('leaver', 've_nord'), 3, 'fixture: a member of Nord reads Nord''s events');
select is(pg_temp.n('leaver', 'ct_nord'), 1, 'fixture: … and its case task');
delete from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000101' and user_id = pg_temp.u('leaver');
select is(pg_temp.n('leaver', 've_nord'), 0, 'RLS2-7: visit_events: 0 immediately after removal');
select is(pg_temp.n('leaver', 'vtc_nord'), 0, 'RLS2-7: visit_time_corrections: 0 immediately after removal');
select is(pg_temp.n('leaver', 'td_nord'), 0, 'RLS2-7: team_decisions: 0 immediately after removal');
select is(pg_temp.n('leaver', 'ct_nord'), 0, 'RLS2-7: case_tasks: 0 immediately after removal');

-- RLS2-3: free-text reasons stay in the team ---------------------------------------------------------------------------
select is(pg_temp.as_user('ops', format($$ select count(*)::text from public.matching_escalations()
                                             where matching_request_id = %L $$, pg_temp.v(10))), '1',
  'fixture: both eligible teams declined, the request escalates to Operations');
select is(pg_temp.as_user('ops', format($$ select string_agg((d ? 'reason')::text, ',') from public.matching_escalations() m, jsonb_array_elements(m.declines) d
                                             where m.matching_request_id = %L $$, pg_temp.v(10))), 'false,false',
  'RLS2-3: the escalation carries no decline free text');
select is(pg_temp.as_user('ops', format($$ select string_agg(d ->> 'code', ',' order by d ->> 'code') from public.matching_escalations() m, jsonb_array_elements(m.declines) d
                                             where m.matching_request_id = %L $$, pg_temp.v(10))), 'capacity,distance',
  'RLS2-3: … but keeps the reason codes (J2 escalation task)');
select is((select string_agg((d ? 'reason')::text, ',') from private.matching_escalations_for('00000000-0000-4000-b000-000000000011') m,
           jsonb_array_elements(m.declines) d where m.matching_request_id = pg_temp.v(10)), 'false,false',
  'RLS2-3: the internal escalation reader carries no decline free text either');
select is(pg_temp.as_user('mitte', format($$ select count(*)::text from public.field_visits(%L::date) where visit_id in (%L, %L) $$,
                                              (private.now() at time zone 'Europe/Zurich')::date + 1, pg_temp.v(1), pg_temp.v(2))), '0',
  'RLS2-3: field_visits shows Mitte no Nord visit, hence no Nord correction reason');
select is(pg_temp.as_user('rn', format($$ select e ->> 'reason' from public.field_visits(%L::date) f, jsonb_array_elements(f.events) e
                                           where f.visit_id = %L and e ->> 'type' = 'departed' $$,
                                           (private.now() at time zone 'Europe/Zurich')::date + 1, pg_temp.v(1))),
  'Synthetisch: RLS2 Korrekturgrund ' || pg_temp.v(1), 'RLS2-3: the team itself still sees its correction reason on /field (unchanged)');
-- Every function that reads the two reason columns is on a fixed list (READ_PATHS.md decides each one).
select is((select string_agg(n.nspname || '.' || p.proname, ',' order by n.nspname, p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prosrc ~ 'visit_time_corrections' and p.prosrc ~ '\.reason\M'),
  'private.visit_report_snapshot,public.field_visits,public.pilot_kpis,public.visit_correction_history',
  'RLS2-3: the functions that read visit_time_corrections and a reason column are a fixed list (READ_PATHS.md: the team''s report snapshot and day view; pilot_kpis reads visit_plan_changes.reason as a filter, never as output; visit_correction_history returns the reason to the visit''s team and cover only, RLS3-4b, 071)');
select is((select string_agg(n.nspname || '.' || p.proname, ',' order by n.nspname, p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public', 'private') and p.prosrc ~ 'team_decisions' and p.prosrc ~ 'd\.reason\M'),
  null, 'RLS2-3: no function returns team_decisions.reason');

-- RLS2-4: no per-person day for others -----------------------------------------------------------------------------------
select is(pg_temp.as_user('ca', format($$ select string_agg(e ->> 'type', ',' order by e ->> 'type') from public.field_visits(%L::date) f, jsonb_array_elements(f.events) e
                                           where f.visit_id = %L $$, (private.now() at time zone 'Europe/Zurich')::date + 1, pg_temp.v(1))),
  'departed,started', 'RLS2-4: a member of the same team sees the visit''s status times (care coordination)');
select is(pg_temp.as_user('ca', format($$ select count(*)::text from public.field_visits(%L::date) f, jsonb_array_elements(f.events) e
                                           where f.visit_id = %L and (e ? 'actor_id' or e ? 'actor') $$, (private.now() at time zone 'Europe/Zurich')::date + 1, pg_temp.v(1))),
  '0', 'RLS2-4: … without who recorded them');
select is((select string_agg(distinct p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
                  unnest(p.proargnames, p.proargmodes) a(nm, md)
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
             and p.prosrc ~ '(visit_events|visit_time_corrections)' and md in ('t', 'o')
             and nm in ('actor_id', 'user_id', 'nurse_id', 'member_id', 'performer_id', 'person', 'member')),
  null, 'RLS2-4: no function that reads visit events or corrections returns a per-person column');
select is((select string_agg(distinct p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
             and p.prosrc ~ '(visit_events|visit_time_corrections)' and p.proretset),
  'field_visits,pilot_hypotheses,pilot_kpis,visit_correction_history', 'RLS2-4: the readers of visit events are the team''s day view, the AN1/AN2 team measures and the per-visit correction trail (RLS3-4b, 071)');

-- RLS2-5: further organisation-wide path narrowed: uncovered_visits() -----------------------------------------------------
update public.care_visits set visit_date = ((private.now() + interval '2 hours') at time zone 'Europe/Zurich')::date,
                              time_start = ((private.now() + interval '2 hours') at time zone 'Europe/Zurich')::time(0),
                              time_end = null, covered_by = null, covered_at = null, cover_team_id = null
where id = pg_temp.v(2);
select is(pg_temp.as_user('ops', format($$ select count(*)::text from public.uncovered_visits() where visit_id = %L $$, pg_temp.v(2))), '1',
  'RLS2-5: Operations still lists the uncovered Nord visit');
select is(pg_temp.as_user('rn', format($$ select count(*)::text from public.uncovered_visits() where visit_id = %L $$, pg_temp.v(2))), '1',
  'RLS2-5: … and so does Nord');
select is(pg_temp.as_user('mitte', format($$ select count(*)::text from public.uncovered_visits() where visit_id = %L $$, pg_temp.v(2))), '0',
  'RLS2-5: a nurse of Mitte no longer sees Nord''s uncovered visit (was every member, 0014)');

-- RLS2-7: another team's ids do not widen the scope ---------------------------------------------------------------------
select is(pg_temp.as_user('mitte', $$ select count(*)::text from public.case_funding_facts('00000000-0000-4000-a000-000000000208') $$), '0',
  'RLS2-7: case_funding_facts with Nord''s case id returns nothing to Mitte');
select is(pg_temp.as_user('mitte', format($$ select count(*)::text from public.report_returns(%L) $$, pg_temp.v(1))), '0',
  'RLS2-7: report_returns with Nord''s visit id returns nothing to Mitte');
select is(pg_temp.as_user('mitte', format($$ select count(*)::text from public.linkable_cases(%L) $$, pg_temp.v(10))), '0',
  'RLS2-7: linkable_cases returns nothing to a nurse');
select is(pg_temp.as_user('mitte', format($$ select public.correct_visit_time((select min(id) from public.visit_events where visit_id = %L) , private.now(), 'Synthetisch: fremd', %L) $$,
                                             pg_temp.v(1), pg_temp.k(500))), 'rejected',
  'RLS2-7: Mitte cannot correct a Nord event');
select is(pg_temp.as_user('mitte', format($$ select public.complete_case_task('00000000-0000-4000-a000-000000000208', 'review_after_pause', %L) $$, pg_temp.k(501))),
  'rejected', 'RLS2-7: Mitte cannot close a task of Nord''s case');

-- cra 22:26 (PR #321): after the narrowing, a no-show and an overdue visit of Nord still reach Operations ------------------
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status, responsible_user_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(4), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   ((private.now() - interval '3 hours') at time zone 'Europe/Zurich')::date, ((private.now() - interval '3 hours') at time zone 'Europe/Zurich')::time(0), null, false, 'planned', pg_temp.u('rn')),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(5), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   -- VIS1-5: dated today (was tomorrow 09:30); a visit dated after today cannot be departed (CGR-87).
   (private.now() at time zone 'Europe/Zurich')::date, '23:58', '23:59', false, 'planned', pg_temp.u('rn'));
select is(pg_temp.as_user('rn', format($$ select public.depart_visit(%L, %L) $$, pg_temp.v(5), pg_temp.k(600))), 'ok', 'fixture: on the way');
select is(pg_temp.as_user('rn', format($$ select public.record_no_show(%L, 'Synthetisch: niemand öffnet', %L, true) $$, pg_temp.v(5), pg_temp.k(601))), 'ok',
  'fixture: no-show recorded');
select is(pg_temp.as_user('ops', format($$ select string_agg(exception_type, ',' order by exception_type) from public.operations_exceptions()
                                            where entity_id = %L $$, pg_temp.v(5))), 'no_show_open',
  'cra: the no-show of Nord still reaches Operations (OPS1)');
select ok(pg_temp.as_user('ops', format($$ select count(*)::text from public.operations_exceptions() where entity_id = %L $$, pg_temp.v(4)))::int >= 1,
  'cra: the overdue visit of Nord still reaches Operations (OPS1)');
select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true);
select private.evaluate_signals('00000000-0000-4000-b000-000000000011', true);
select is(pg_temp.as_user('rn', format($$ select string_agg(signal_kind, ',' order by signal_kind) from public.my_signals() where visit_id in (%L, %L) $$,
                                          pg_temp.v(4), pg_temp.v(5))), 'no_show,visit_overdue',
  'cra: SIG1 still delivers both signals to the responsible nurse of Nord');

-- RLS2-1 / RLS2-7 sweep: every reader in READ_PATHS.md, called by a nurse of Mitte, returns no row of Nord ----------------
-- (no row whose case is …208, whose team is Nord, or whose visit is one of Nord's). Positive controls for Nord follow.
create temp table nord_visits as select id from public.care_visits where team_id = '00000000-0000-4000-a000-000000000101';
grant select on nord_visits to authenticated;
create temp table sweep (call text primary key);
grant select on sweep to authenticated;
insert into sweep
select format(c, (private.now() at time zone 'Europe/Zurich')::date + d)
from unnest(array['public.field_visits(%L)', 'public.field_notes(%L)', 'public.field_quality(%L)', 'public.field_reports(%L)',
                  'public.field_since_last(%L)', 'public.field_visit_status_notes(%L)', 'public.team_open_visits(%L)']) c,
     unnest(array[0, 1]) d
union all
select unnest(array['public.field_countersign_queue()', 'public.field_returned_reports()', 'public.team_cases()', 'public.team_case_lifecycle()',
                    'public.team_plan_status()', 'public.team_visit_alerts()', 'public.my_covers()', 'public.my_signals()', 'public.cover_offers()',
                    'public.final_report_visits()', 'public.uncovered_visits()', 'public.visits_outside_watched_hours()', 'public.intake_cases()', 'public.ops_case_lifecycle()',
                    'public.operations_exceptions()', 'public.matching_escalations()', 'public.team_offers()',
                    format('public.continuity_by_case(%L)', date_trunc('month', private.now() at time zone 'Europe/Zurich')::date),
                    format('public.pilot_kpis(%L)', date_trunc('month', private.now() at time zone 'Europe/Zurich')::date),
                    format('public.pilot_hypotheses(%L)', date_trunc('month', private.now() at time zone 'Europe/Zurich')::date),
                    format('public.billing_preview(%L)', date_trunc('month', private.now() at time zone 'Europe/Zurich')::date),
                    format('public.case_funding_facts(%L)', '00000000-0000-4000-a000-000000000208'),
                    format('public.report_returns(%L)', pg_temp.v(1)), format('public.linkable_cases(%L)', pg_temp.v(10))]);
create function pg_temp.nord_rows(p_call text) returns text language sql as $$
  select format($q$ select count(*)::text from %s x
                   where to_jsonb(x) ->> 'case_id' = '00000000-0000-4000-a000-000000000208'
                      or to_jsonb(x) ->> 'team_id' = '00000000-0000-4000-a000-000000000101'
                      or (to_jsonb(x) ->> 'visit_id')::uuid in (select id from nord_visits) $q$, p_call) $$;
select is(pg_temp.as_user('mitte', pg_temp.nord_rows(call)), '0', 'RLS2-7 sweep: ' || call || ' returns no row of Nord to Mitte')
from sweep order by call;
select ok(pg_temp.as_user('rn', pg_temp.nord_rows(format('public.field_visits(%L)', (private.now() at time zone 'Europe/Zurich')::date + 1)))::int > 0,
  'sweep control: field_visits returns Nord''s rows to Nord');
select ok(pg_temp.as_user('rn', pg_temp.nord_rows('public.team_cases()'))::int > 0, 'sweep control: team_cases returns Nord''s case to Nord');
select ok(pg_temp.as_user('ops', pg_temp.nord_rows('public.operations_exceptions()'))::int > 0,
  'sweep control: operations_exceptions returns Nord''s exceptions to Operations (coordination task OPS1)');

-- RLS2-1: catalogue check: every client-, case- or visit-linked table readable by authenticated has a scope decision -------
select is((select string_agg(c.relname, ',' order by c.relname) from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p', 'f') and has_any_column_privilege('authenticated', c.oid, 'select')
             and exists (select 1 from pg_attribute a where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
                         and a.attname in ('case_id', 'visit_id', 'client_id'))),
  'billable_facts,care_notes,care_plan_items,care_visits,case_gp_notices,case_lifecycle_events,case_tasks,cover_events,matching_requests,'
  'quality_events,quality_holds,safety_signals,signal_deliveries,team_decisions,visit_events,visit_observations,visit_plan_changes,'
  'visit_report_returns,visit_reports,visit_status_notes,visit_time_corrections,working_time_facts',
  'RLS2-1: the tables with a case, visit or client column readable by authenticated are exactly the ones in READ_PATHS.md');
select is((select string_agg(distinct p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
                  unnest(p.proargnames, p.proargmodes) a(nm, md)
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute')
             and md in ('t', 'o') and nm in ('case_id', 'visit_id', 'client_id')),
  'case_funding_facts,continuity_by_case,cover_offers,field_countersign_queue,field_door_notes,field_notes,field_quality,field_reports,'
  'field_returned_reports,field_safety_alert_history,field_safety_alerts,field_since_last,field_visit_status_notes,field_visits,final_report_visits,intake_cases,linkable_cases,'
  'my_covers,my_signals,operations_exceptions,ops_case_lifecycle,team_case_lifecycle,team_cases,team_open_visits,team_plan_status,'
  'team_visit_alerts,uncovered_visits,visits_outside_watched_hours',
  'RLS2-1: the functions returning a case, visit or client column are exactly the ones in READ_PATHS.md');
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('v', 'm') and has_any_column_privilege('authenticated', c.oid, 'select')), 0,
  'RLS2-1: no view or materialised view is readable by authenticated');
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and has_any_column_privilege('authenticated', c.oid, 'select') and not c.relrowsecurity), 0,
  'RLS2-1: every table readable by authenticated has RLS on');

select * from finish();
rollback;
