-- RLS3: coordination roles and teammates read no more than their task needs (migration 0070, ADR-083).
-- Brief `docs/agents/briefs/RLS3.md` (RLS3-1 to RLS3-6); inventory `docs/engineering/READ_PATHS.md` (F-2, F-4, F-5).
-- Users: nurse …902 (registered nurse, Testteam Nord …101) · care assistant …906 (Nord) · coach …901 · operations …904 ·
-- admin …905 (org A, no team) · admin …903 (org B). Synthetic users added here: …7101 registered nurse of Testteam Mitte
-- …102 (same organisation, no cover), …7102 registered nurse of Mitte who covers Nord visits, …7104 an account without
-- any membership. Cases …208 (Nord) and …205 (Mitte). All data synthetic; fixtures are written as the table owner, reads
-- go through `authenticated`.
begin;
create extension if not exists pgtap with schema extensions;

select plan(88);

create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'rn' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'coach' then '00000000-0000-4000-a000-000000000901' when 'ops' then '00000000-0000-4000-a000-000000000904'
                 when 'admin' then '00000000-0000-4000-a000-000000000905' when 'admin_b' then '00000000-0000-4000-a000-000000000903'
                 when 'mitte' then 'a0710000-0000-4000-a000-000000007101' when 'cover' then 'a0710000-0000-4000-a000-000000007102'
                 when 'outsider' then 'a0710000-0000-4000-a000-000000007104' end)::uuid
$$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a0710000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0710000-0000-4000-9000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.today() returns date language sql stable as $$ select (private.now() at time zone 'Europe/Zurich')::date $$;
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
-- Does `p_user`'s statement fail with insufficient privilege?
create function pg_temp.refused(p_user text, p_sql text) returns boolean language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', pg_temp.u(p_user)::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql;
  exception when insufficient_privilege then
    execute 'reset role';
    return true;
  end;
  execute 'reset role';
  return false;
end $$;

-- Synthetic accounts and fixtures (as the table owner) -----------------------------------------------------------------
insert into auth.users (id, email) values
  (pg_temp.u('mitte'), 'rls3-mitte@navora.test'), (pg_temp.u('cover'), 'rls3-cover@navora.test'),
  (pg_temp.u('outsider'), 'rls3-outsider@navora.test');
insert into public.organization_memberships (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('mitte'), 'nurse'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.u('cover'), 'nurse');
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), 'registered_nurse'),
  ('00000000-0000-4000-a000-000000000102', pg_temp.u('cover'), 'registered_nurse');
insert into public.member_profiles (organization_id, user_id, display_name)
select '00000000-0000-4000-b000-000000000011', x.u, x.n
from (values (pg_temp.u('rn'), 'Synth RN Nord'), (pg_temp.u('ca'), 'Synth FaGe Nord'), (pg_temp.u('cover'), 'Synth RN Cover')) x(u, n)
where not exists (select 1 from public.member_profiles p where p.organization_id = '00000000-0000-4000-b000-000000000011' and p.user_id = x.u);

-- v1: Nord, yesterday, performed by …906, countersigned by …902, final, billed; its `started` event corrected twice.
-- v2: Nord, tomorrow, covered by …7102 (Mitte), no report: a no-show note, cover events.
-- v3: Mitte, tomorrow: a note, a working-time fact, an offer.
-- v4: Nord, yesterday, covered and performed by …7102, final: the covering author's trail after the cover read ended.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, billable, status) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   pg_temp.today() - 1, '06:10', '06:40', false, 'completed'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   pg_temp.today() + 1, '07:10', '07:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000205', '00000000-0000-4000-a000-000000000102',
   pg_temp.today() + 1, '08:10', '08:40', false, 'planned'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(4), '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   pg_temp.today() - 1, '09:10', '09:40', false, 'completed');
update public.care_visits set covered_by = pg_temp.u('cover'), covered_at = private.now(), cover_team_id = '00000000-0000-4000-a000-000000000102'
where id in (pg_temp.v(2), pg_temp.v(4));

insert into public.visit_events (organization_id, visit_id, team_id, event_type, from_status, to_status, actor_id, occurred_at) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000101', 'departed', 'planned', 'on_the_way', pg_temp.u('ca'), private.now() - interval '26 hours'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000101', 'started', 'on_the_way', 'started', pg_temp.u('ca'), private.now() - interval '25 hours'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(4), '00000000-0000-4000-a000-000000000101', 'started', 'on_the_way', 'started', pg_temp.u('cover'), private.now() - interval '24 hours'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000102', 'departed', 'planned', 'on_the_way', pg_temp.u('mitte'), private.now() - interval '20 minutes');
-- Two corrections of v1 `started` (…906, then …902) and one of v4 `started` (…7102).
insert into public.visit_time_corrections (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key, created_at)
select e.organization_id, e.visit_id, e.team_id, e.id, e.occurred_at - interval '5 minutes', 'Synthetisch: RLS3 erste Korrektur',
       pg_temp.u('ca'), pg_temp.k(1), private.now() - interval '23 hours'
from public.visit_events e where e.visit_id = pg_temp.v(1) and e.event_type = 'started';
insert into public.visit_time_corrections (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key, created_at)
select e.organization_id, e.visit_id, e.team_id, e.id, e.occurred_at - interval '7 minutes', 'Synthetisch: RLS3 zweite Korrektur',
       pg_temp.u('rn'), pg_temp.k(2), private.now() - interval '22 hours'
from public.visit_events e where e.visit_id = pg_temp.v(1) and e.event_type = 'started';
insert into public.visit_time_corrections (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key, created_at)
select e.organization_id, e.visit_id, e.team_id, e.id, e.occurred_at - interval '3 minutes', 'Synthetisch: RLS3 Korrektur Cover',
       pg_temp.u('cover'), pg_temp.k(3), private.now() - interval '21 hours'
from public.visit_events e where e.visit_id = pg_temp.v(4) and e.event_type = 'started';

insert into public.visit_reports (organization_id, id, visit_id, case_id, team_id, version, status, snapshot, performer_id,
                                  countersign_required, created_by, signed_by, signed_at, countersigned_by, countersigned_at)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(11), pg_temp.v(1), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', 1, 'final', '{}', pg_temp.u('ca'), true,
        pg_temp.u('ca'), pg_temp.u('ca'), private.now() - interval '20 hours', pg_temp.u('rn'), private.now() - interval '19 hours'),
       ('00000000-0000-4000-b000-000000000011', pg_temp.v(14), pg_temp.v(4), '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', 1, 'final', '{}', pg_temp.u('cover'), false,
        pg_temp.u('cover'), pg_temp.u('cover'), private.now() - interval '20 hours', null, null);
insert into public.billable_facts (organization_id, visit_id, case_id, team_id, report_id, visit_date, billable, reasons, order_basis,
                                   payer_chain, tariff_versions, created_by, created_at, rule_version, cause)
select v.organization_id, v.id, v.case_id, v.team_id, pg_temp.v(11), v.visit_date, true, '{}', 'with_order', '{}'::jsonb, '{}'::jsonb,
       pg_temp.u('rn'), private.now() - interval '18 hours', 'J5-v3', 'report'
from public.care_visits v where v.id = pg_temp.v(1);

insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key, at_door) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), 'no_show', 'Synthetisch: RLS3 Notiz Nord', pg_temp.u('rn'), pg_temp.k(21), true),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), 'no_show', 'Synthetisch: RLS3 Notiz Mitte', pg_temp.u('mitte'), pg_temp.k(22), true);
insert into public.cover_events (organization_id, visit_id, kind, nurse_id, team_id) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), 'offered', null, null),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(2), 'accepted', pg_temp.u('cover'), '00000000-0000-4000-a000-000000000102'),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), 'offered', null, null);
insert into public.working_time_facts (organization_id, visit_id, team_id, performer_id, visit_date, care_minutes) values
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), '00000000-0000-4000-a000-000000000101', pg_temp.u('ca'), pg_temp.today() - 1, 25),
  ('00000000-0000-4000-b000-000000000011', pg_temp.v(3), '00000000-0000-4000-a000-000000000102', pg_temp.u('mitte'), pg_temp.today() + 1, 25);
insert into public.care_plan_items (organization_id, case_id, team_id, service, category, planned_minutes, frequency, review_date, created_by) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
   'RLS3 Testleistung Nord', 'A', 20, 'täglich', pg_temp.today() + 30, pg_temp.u('rn')),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000205', '00000000-0000-4000-a000-000000000102',
   'RLS3 Testleistung Mitte', 'A', 20, 'täglich', pg_temp.today() + 30, pg_temp.u('mitte'));
insert into public.case_lifecycle_events (organization_id, case_id, kind, reason_code, actor_id, idempotency_key, created_at) values
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000208', 'resume', null, pg_temp.u('rn'), pg_temp.k(31), private.now() - interval '30 days'),
  ('00000000-0000-4000-b000-000000000011', '00000000-0000-4000-a000-000000000205', 'resume', null, pg_temp.u('mitte'), pg_temp.k(32), private.now() - interval '30 days');

create temp table q (name text primary key, sql text not null);
grant select on q to authenticated;
insert into q values
  ('vsn_nord',  format('select 1 from public.visit_status_notes where visit_id = %L', pg_temp.v(2))),
  ('vsn_mitte', format('select 1 from public.visit_status_notes where visit_id = %L', pg_temp.v(3))),
  ('ce_nord',   format('select 1 from public.cover_events where visit_id = %L', pg_temp.v(2))),
  ('ce_mitte',  format('select 1 from public.cover_events where visit_id = %L', pg_temp.v(3))),
  ('wtf_nord',  format('select 1 from public.working_time_facts where visit_id = %L', pg_temp.v(1))),
  ('wtf_mitte', format('select 1 from public.working_time_facts where visit_id = %L', pg_temp.v(3))),
  ('cpi_nord',  'select 1 from public.care_plan_items where case_id = ''00000000-0000-4000-a000-000000000208'' and service like ''RLS3%'''),
  ('cpi_mitte', 'select 1 from public.care_plan_items where case_id = ''00000000-0000-4000-a000-000000000205'' and service like ''RLS3%'''),
  ('cle_nord',  format('select 1 from public.case_lifecycle_events where idempotency_key = %L', pg_temp.k(31))),
  ('cle_mitte', format('select 1 from public.case_lifecycle_events where idempotency_key = %L', pg_temp.k(32))),
  ('hist_v1',   format('select * from public.visit_correction_history(%L)', pg_temp.v(1))),
  ('hist_v4',   format('select * from public.visit_correction_history(%L)', pg_temp.v(4)));
create function pg_temp.n(p_user text, p_q text) returns integer language sql as $$
  select pg_temp.seen(p_user, (select sql from q where name = p_q)) $$;

-- RLS3-1 structure: one team-scoped read policy per table, no coordination role in it; anon reads nothing --------------
select is((select string_agg(c.relname || ':' || p.polname, ',' order by c.relname)
           from pg_policy p join pg_class c on c.oid = p.polrelid
           where c.relname in ('visit_status_notes', 'cover_events', 'working_time_facts') and p.polcmd in ('r', '*')),
  'cover_events:team_scoped_read,visit_status_notes:team_scoped_read,working_time_facts:team_scoped_read',
  'RLS3-1: each of the three tables has exactly one read policy, team_scoped_read');
select is((select count(*)::int from pg_policy p join pg_class c on c.oid = p.polrelid
           where c.relname in ('visit_status_notes', 'cover_events', 'working_time_facts')
             and pg_get_expr(p.polqual, p.polrelid) ~ '(is_coordinator|has_org_role|is_intake_role|is_org_admin)'), 0,
  'RLS3-1: no read policy of the three tables admits a coordination role');
select is((select count(*)::int from pg_policy p join pg_class c on c.oid = p.polrelid
           where c.relname = 'visit_status_notes' and pg_get_expr(p.polqual, p.polrelid) ~ 'care_visits'), 0,
  'RLS3-1: visit_status_notes no longer inherits the visit''s coordination read');
select throws_ok('set local role anon; select 1 from public.visit_status_notes', '42501', null, 'RLS3-1: anon reads no visit_status_notes');
reset role;
select throws_ok('set local role anon; select 1 from public.cover_events', '42501', null, 'RLS3-1: anon reads no cover_events');
reset role;
select throws_ok('set local role anon; select 1 from public.working_time_facts', '42501', null, 'RLS3-1: anon reads no working_time_facts');
reset role;

-- RLS3-1 visit_status_notes ----------------------------------------------------------------------------------------------
select is(pg_temp.n('rn', 'vsn_nord'), 1, 'RLS3-1 notes: a member of the visit''s team reads the note');
select is(pg_temp.n('ca', 'vsn_nord'), 1, 'RLS3-1 notes: the care assistant of the team reads it too');
select is(pg_temp.n('mitte', 'vsn_nord'), 0, 'RLS3-1 notes: a nurse of another team of the same organisation reads 0');
select is(pg_temp.n('mitte', 'vsn_mitte'), 1, 'RLS3-1 notes: … and her own team''s note');
select is(pg_temp.n('ops', 'vsn_nord'), 0, 'RLS3-1 notes: Operations reads 0 through the table API');
select is(pg_temp.n('coach', 'vsn_nord'), 0, 'RLS3-1 notes: the coach reads 0');
select is(pg_temp.n('admin', 'vsn_nord'), 0, 'RLS3-1 notes: the administrator reads 0');
select is(pg_temp.n('admin_b', 'vsn_nord'), 0, 'RLS3-1 notes: another organisation reads 0');
select is(pg_temp.n('outsider', 'vsn_nord'), 0, 'RLS3-1 notes: an account without membership reads 0');
select is(pg_temp.n('cover', 'vsn_nord'), 1, 'RLS3-1 notes: the covering member reads the note while her cover runs');

-- RLS3-1 cover_events ------------------------------------------------------------------------------------------------------
select is(pg_temp.n('rn', 'ce_nord'), 2, 'RLS3-1 cover: the visit''s team reads its cover events');
select is(pg_temp.n('cover', 'ce_nord'), 1, 'RLS3-1 cover: the nurse the event names reads her own row only');
select is(pg_temp.n('ops', 'ce_nord'), 0, 'RLS3-1 cover: Operations reads 0');
select is(pg_temp.n('coach', 'ce_nord'), 0, 'RLS3-1 cover: the coach reads 0');
select is(pg_temp.n('admin', 'ce_nord'), 0, 'RLS3-1 cover: the administrator reads 0');
select is(pg_temp.n('admin_b', 'ce_nord'), 0, 'RLS3-1 cover: another organisation reads 0');
select is(pg_temp.n('outsider', 'ce_nord'), 0, 'RLS3-1 cover: an account without membership reads 0');
select is(pg_temp.n('mitte', 'ce_mitte'), 1, 'RLS3-1 cover: Mitte reads the offer of its own visit');

-- RLS3-1 working_time_facts ------------------------------------------------------------------------------------------------
select is(pg_temp.n('rn', 'wtf_nord'), 1, 'RLS3-1 working time: the row''s team reads it');
select is(pg_temp.n('mitte', 'wtf_nord'), 0, 'RLS3-1 working time: another team of the organisation reads 0');
select is(pg_temp.n('mitte', 'wtf_mitte'), 1, 'RLS3-1 working time: … and its own row');
select is(pg_temp.n('ops', 'wtf_nord'), 0, 'RLS3-1 working time: Operations reads 0');
select is(pg_temp.n('coach', 'wtf_nord'), 0, 'RLS3-1 working time: the coach reads 0');
select is(pg_temp.n('admin', 'wtf_nord'), 0, 'RLS3-1 working time: the administrator reads 0');
select is(pg_temp.n('admin_b', 'wtf_nord'), 0, 'RLS3-1 working time: another organisation reads 0');

-- RLS3-3 / F-5: negative table-API cases ---------------------------------------------------------------------------------
select is(pg_temp.n('rn', 'cpi_nord'), 1, 'RLS3-3: a member of team A reads its care plan item');
select is(pg_temp.n('mitte', 'cpi_nord'), 0, 'RLS3-3: a nurse of another team of the organisation reads 0 care plan items of team A');
select is(pg_temp.n('mitte', 'cpi_mitte'), 1, 'RLS3-3: … and her own team''s item');
select is(pg_temp.n('rn', 'cle_nord'), 1, 'RLS3-3: a member of team A reads its case lifecycle event');
select is(pg_temp.n('mitte', 'cle_nord'), 0, 'RLS3-3: a nurse of another team reads 0 case lifecycle events of team A');
select is(pg_temp.n('mitte', 'cle_mitte'), 1, 'RLS3-3: … and her own case''s event');
select is(pg_temp.n('mitte', 'ce_nord'), 0, 'RLS3-3: a nurse of another team (not the one named) reads 0 cover events of team A');

-- RLS3-2: the team's read model still returns the note (the coordination read models are covered by 019, 042, 045, 067) --
select is(pg_temp.as_user('rn', format('select note from public.field_visit_status_notes(%L::date) where visit_id = %L', pg_temp.today() + 1, pg_temp.v(2))),
  'Synthetisch: RLS3 Notiz Nord', 'RLS3-2: field_visit_status_notes still shows the team its note');
select lives_ok(format('select pg_temp.seen(%L, %L)', 'ops', 'select * from public.operations_exceptions()'),
  'RLS3-2: operations_exceptions() still runs for Operations after the narrowing');

-- RLS3-4 / F-4: no actor_id through the table API --------------------------------------------------------------------------
select ok(not has_column_privilege('authenticated', 'public.visit_events', 'actor_id', 'select'),
  'RLS3-4: authenticated cannot select visit_events.actor_id');
select ok(not has_column_privilege('authenticated', 'public.visit_time_corrections', 'actor_id', 'select'),
  'RLS3-4: authenticated cannot select visit_time_corrections.actor_id');
select ok(not has_table_privilege('authenticated', 'public.visit_events', 'select')
          and not has_table_privilege('authenticated', 'public.visit_time_corrections', 'select'),
  'RLS3-4: no table-wide select grant remains on the two tables');
select is((select count(*)::int from information_schema.columns c
           where c.table_schema = 'public' and c.table_name in ('visit_events', 'visit_time_corrections') and c.column_name <> 'actor_id'
             and not has_column_privilege('authenticated', format('public.%I', c.table_name), c.column_name, 'select')), 0,
  'RLS3-4: every other column stays selectable (team and cover rows, RLS2)');
select ok(not has_any_column_privilege('anon', 'public.visit_events', 'select')
          and not has_any_column_privilege('anon', 'public.visit_time_corrections', 'select'), 'RLS3-4: anon selects no column');
select ok(pg_temp.refused('ca', format('select actor_id from public.visit_events where visit_id = %L', pg_temp.v(1))),
  'RLS3-4: a teammate''s table-API select of visit_events.actor_id is refused');
select ok(pg_temp.refused('ca', format('select actor_id from public.visit_time_corrections where visit_id = %L', pg_temp.v(1))),
  'RLS3-4: a teammate''s table-API select of visit_time_corrections.actor_id is refused');
select ok(pg_temp.refused('rn', 'select * from public.visit_events'), 'RLS3-4: select * through the table API is refused too');
select is(pg_temp.seen('ca', format('select id, event_type, occurred_at from public.visit_events where visit_id = %L', pg_temp.v(1))), 2,
  'RLS3-4: the team still reads the events of its visit without who recorded them');
select is(pg_temp.as_user('ca', format($$ select count(*)::text from public.field_visits(%L::date) where visit_id = %L $$, pg_temp.today() - 1, pg_temp.v(1))),
  '1', 'RLS3-4: a nurse still sees her visit''s events on /field (field_visits reads no actor_id)');
-- The functions that return a member's identity together with a visit event or correction time are a fixed list
-- (READ_PATHS.md names the care task of each). A new reader fails here until it is listed.
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'execute') and p.proretset
             and p.prosrc ~ '(public\.visit_events|public\.visit_time_corrections|visit_report_snapshot|private\.visit_times|effective_event_time|\.snapshot\M)'
             and (p.prosrc ~ '(member_name|member_code|display_name)'
                  or exists (select 1 from unnest(p.proargnames, p.proargmodes) a(nm, md)
                             where md in ('t', 'o') and nm in ('actor_id', 'performer_id', 'user_id', 'nurse_id', 'member_id')))),
  'field_reports,report_returns,visit_correction_history',
  'RLS3-4: identity with event or correction times only through field_reports (J5 signing), report_returns (F6R) and visit_correction_history (RLS3-4b)');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('field_reports', 'report_returns', 'visit_correction_history')
             and (p.prosrc ~* '(group by|count\(|string_agg|array_agg\(distinct)')), null,
  'RLS3-4 / D-23 (b): none of the listed readers groups or counts per person');

-- RLS3-4b: the correction trail, two levels --------------------------------------------------------------------------------
select function_privs_are('public', 'visit_correction_history', array['uuid'], 'anon', array[]::text[], 'RLS3-4b: anon cannot read a correction trail');
select function_privs_are('public', 'visit_correction_history', array['uuid'], 'authenticated', array['EXECUTE'], 'RLS3-4b: members call the reader');
-- (a) full trail
select is(pg_temp.n('rn', 'hist_v1'), 2, 'RLS3-4b (a): the countersigning RN sees both corrections of the visit');
select is(pg_temp.as_user('rn', format($$ select string_agg(corrector_name || '|' || reason, ';' order by corrected_on) from public.visit_correction_history(%L) $$, pg_temp.v(1))),
  'Synth FaGe Nord|Synthetisch: RLS3 erste Korrektur;Synth RN Nord|Synthetisch: RLS3 zweite Korrektur',
  'RLS3-4b (a): … with who corrected the event and why');
select is(pg_temp.as_user('ca', format($$ select string_agg(corrected_by_me::text, ',' order by corrected_on) from public.visit_correction_history(%L) where full_trail $$, pg_temp.v(1))),
  'true,false', 'RLS3-4b (a): the report''s author sees the full trail and which correction is hers');
select is(pg_temp.as_user('rn', format($$ select bool_and(old_at is not null and new_at is not null and corrected_on is not null)::text
                                           from public.visit_correction_history(%L) $$, pg_temp.v(1))),
  'true', 'RLS3-4b (a): old value, new value and time of each correction');
select is(pg_temp.as_user('rn', format($$ select ((select new_at from public.visit_correction_history(%1$L) order by corrected_on limit 1)
                                                  = (select old_at from public.visit_correction_history(%1$L) order by corrected_on desc limit 1))::text $$, pg_temp.v(1))),
  'true', 'RLS3-4b: the old value of the second correction is the new value of the first');
select is(pg_temp.as_user('rn', format($$ select (old_at = recorded_at)::text from public.visit_correction_history(%L) order by corrected_on limit 1 $$, pg_temp.v(1))),
  'true', 'RLS3-4b: the old value of the first correction is the recorded time');
select is(pg_temp.as_user('cover', format($$ select corrector_name || '|' || reason from public.visit_correction_history(%L) $$, pg_temp.v(4))),
  'Synth RN Cover|Synthetisch: RLS3 Korrektur Cover', 'RLS3-4b (a): a covering author keeps her report''s trail after the report is final');
select is(pg_temp.n('cover', 'hist_v1'), 0, 'RLS3-4b: the covering member of another visit reads no trail of v1');
-- (b) billing view
select is(pg_temp.n('admin', 'hist_v1'), 2, 'RLS3-4b (b): the administrator receives the corrections of the visit');
select is(pg_temp.n('coach', 'hist_v1'), 2, 'RLS3-4b (b): the coach receives them');
select is(pg_temp.n('ops', 'hist_v1'), 2, 'RLS3-4b (b): Operations receives them');
select is(pg_temp.as_user('admin', format($$ select string_agg(coalesce(reason, '-') || '|' || coalesce(corrector_name, '-') || '|' || coalesce(corrected_by_me::text, '-') || '|' || full_trail::text, ';')
                                              from public.visit_correction_history(%L) $$, pg_temp.v(1))),
  '-|-|-|false;-|-|-|false', 'RLS3-4b (b): the administrator gets no reason and no corrector');
select is(pg_temp.as_user('coach', format($$ select count(*)::text from public.visit_correction_history(%L) where reason is not null or corrector_name is not null or corrected_by_me is not null $$, pg_temp.v(1))),
  '0', 'RLS3-4b (b): the coach gets no reason and no corrector');
select is(pg_temp.as_user('ops', format($$ select count(*)::text from public.visit_correction_history(%L) where reason is not null or corrector_name is not null or corrected_by_me is not null $$, pg_temp.v(1))),
  '0', 'RLS3-4b (b): Operations gets no reason and no corrector');
select is(pg_temp.as_user('ops', format($$ select bool_and(old_at is not null and new_at is not null and corrected_on is not null and old_at <> new_at)::text
                                            from public.visit_correction_history(%L) $$, pg_temp.v(1))),
  'true', 'RLS3-4b (b): … but the old and new value and the time of each correction');
select is(pg_temp.as_user('admin', format($$ select distinct fact_report_version || '|' || fact_countersigned_by_name from public.visit_correction_history(%L) $$, pg_temp.v(1))),
  '1|Synth RN Nord', 'RLS3-4b (b): … and the signed version the billing fact is based on with its countersigner');
-- Nobody else
select is(pg_temp.n('mitte', 'hist_v1'), 0, 'RLS3-4b: a nurse of another team reads no trail');
select is(pg_temp.n('mitte', 'hist_v4'), 0, 'RLS3-4b: a member of the cover team who is neither author nor covering reads no trail');
select is(pg_temp.n('admin_b', 'hist_v1'), 0, 'RLS3-4b: another organisation reads no trail');
select is(pg_temp.n('outsider', 'hist_v1'), 0, 'RLS3-4b: an account without membership reads no trail');
-- No listed reader returns the reason outside the visit's team and cover
select is(pg_temp.as_user('admin', format($$ select count(*)::text from public.field_reports(%L::date) where visit_id = %L $$, pg_temp.today() - 1, pg_temp.v(1))),
  '0', 'RLS3-4b: field_reports (its snapshot carries the correction reason) returns nothing to the administrator');
select is(pg_temp.as_user('ops', format($$ select count(*)::text from public.field_reports(%L::date) where visit_id = %L $$, pg_temp.today() - 1, pg_temp.v(1))),
  '0', 'RLS3-4b: … nor to Operations');
select is(pg_temp.as_user('coach', format($$ select count(*)::text from public.report_returns(%L) $$, pg_temp.v(1))),
  '0', 'RLS3-4b: report_returns returns nothing to the coach');
select is(pg_temp.as_user('mitte', format($$ select count(*)::text from public.field_reports(%L::date) where visit_id = %L $$, pg_temp.today() - 1, pg_temp.v(1))),
  '0', 'RLS3-4b: field_reports returns nothing to a nurse of another team');
select is((select string_agg(nm, ',' order by nm) from pg_proc p, unnest(p.proargnames, p.proargmodes) a(nm, md)
           where p.oid = 'public.visit_correction_history(uuid)'::regprocedure and md = 't'
             and nm in ('actor_id', 'user_id', 'nurse_id', 'member_id', 'performer_id', 'corrector_id')), null,
  'RLS3-4b / D-23 (b): the reader returns no person id column (a name per correction, per visit)');

-- FUP1-3 / RLS3-4c (CGR-59, 0071, ADR-084): billed or not, per correction ---------------------------------------------------
-- v1's two corrections (-23 h, -22 h) were made before the countersignature of version 1 (-19 h), on which the billing
-- fact rests. A third correction after it (-10 h) is not in the billed version.
select is(pg_temp.as_user('admin', format($$ select string_agg(in_billed_version::text, ',' order by corrected_on) from public.visit_correction_history(%L) $$, pg_temp.v(1))),
  'true,true', 'FUP1-3 (b): corrections made before the countersignature of the billed version → in_billed_version true');
insert into public.visit_time_corrections (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key, created_at)
select e.organization_id, e.visit_id, e.team_id, e.id, e.occurred_at - interval '9 minutes', 'Synthetisch: FUP1 Korrektur nach Gegenzeichnung',
       pg_temp.u('rn'), pg_temp.k(4), private.now() - interval '10 hours'
from public.visit_events e where e.visit_id = pg_temp.v(1) and e.event_type = 'started';
select is(pg_temp.as_user('admin', format($$ select string_agg(in_billed_version::text, ',' order by corrected_on) from public.visit_correction_history(%L) $$, pg_temp.v(1))),
  'true,true,false', 'FUP1-3 (b): a correction made after the countersignature → in_billed_version false');
select is(pg_temp.as_user('rn', format($$ select string_agg(in_billed_version::text, ',' order by corrected_on) from public.visit_correction_history(%L) where full_trail $$, pg_temp.v(1))),
  'true,true,false', 'FUP1-3 (a): the full trail carries the same flag');
select is(pg_temp.as_user('ops', format($$ select count(*)::text from public.visit_correction_history(%L) where reason is not null or corrector_name is not null or corrected_by_me is not null $$, pg_temp.v(1))),
  '0', 'FUP1-3 (b): the billing view still returns no reason and no corrector');
-- v4: final report without countersignature (signed -20 h), no billing fact yet.
select is(pg_temp.as_user('admin', format($$ select coalesce(string_agg(coalesce(in_billed_version::text, 'null'), ','), '-') from public.visit_correction_history(%L) $$, pg_temp.v(4))),
  'null', 'FUP1-3: a visit without a billing fact → in_billed_version null');
insert into public.billable_facts (organization_id, visit_id, case_id, team_id, report_id, visit_date, billable, reasons, order_basis,
                                   payer_chain, tariff_versions, created_by, created_at, rule_version, cause)
select v.organization_id, v.id, v.case_id, v.team_id, pg_temp.v(14), v.visit_date, true, '{}', 'with_order', '{}'::jsonb, '{}'::jsonb,
       pg_temp.u('cover'), private.now() - interval '19 hours', 'J5-v3', 'report'
from public.care_visits v where v.id = pg_temp.v(4);
insert into public.visit_time_corrections (organization_id, visit_id, team_id, event_id, corrected_at, reason, actor_id, idempotency_key, created_at)
select e.organization_id, e.visit_id, e.team_id, e.id, e.occurred_at - interval '4 minutes', 'Synthetisch: FUP1 Korrektur nach Signatur',
       pg_temp.u('cover'), pg_temp.k(5), private.now() - interval '8 hours'
from public.visit_events e where e.visit_id = pg_temp.v(4) and e.event_type = 'started';
select is(pg_temp.as_user('admin', format($$ select string_agg(in_billed_version::text, ',' order by corrected_on) from public.visit_correction_history(%L) $$, pg_temp.v(4))),
  'true,false', 'FUP1-3: no countersignature required → the signature time decides (before → true, after → false)');
select is((select string_agg(nm, ',' order by nm) from pg_proc p, unnest(p.proargnames, p.proargmodes) a(nm, md)
           where p.oid = 'public.visit_correction_history(uuid)'::regprocedure and md = 't' and nm = 'in_billed_version'),
  'in_billed_version', 'FUP1-3: the reader returns in_billed_version (one flag per correction, no instant per person)');

-- Cover end: the covering member's note read ends with her cover (RLS3-1) ----------------------------------------------------
update public.care_visits set covered_by = null, covered_at = null, cover_team_id = null where id = pg_temp.v(2);
select is(pg_temp.n('cover', 'vsn_nord'), 0, 'RLS3-1 notes: the former covering member reads 0 after her cover ended');
select is(pg_temp.n('cover', 'ce_nord'), 1, 'RLS3-1 cover: … she keeps her own cover event');

select * from finish();
rollback;
