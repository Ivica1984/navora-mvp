-- RLS4 (migration 0099, ADR-122): who did an act is read per record through its reader, never selectable, listed or
-- counted per person through the table API; who is responsible now stays readable to the team. Brief
-- `docs/agents/briefs/RLS4.md` (RLS4-1 to RLS4-4, tests, negative). All data synthetic.
-- Seed users: pflege …902 (registered nurse, Nord …101) · assist …906 (care assistant, Nord) · fremd …903 (org B).
-- Fixtures are written through the commands as these users, or as the table owner where 071 does the same.
begin;
create extension if not exists pgtap with schema extensions;

select plan(50);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'fremd' then '00000000-0000-4000-a000-000000000903' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0991000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.v(n int) returns uuid language sql immutable as $$
  select ('a0990000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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
-- Rows of a query as the user, as one jsonb array (raises what the query raises).
create function pg_temp.rows(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_user)::text);
  execute 'set local role authenticated';
  execute format('select coalesce(jsonb_agg(to_jsonb(x)), ''[]'') from (%s) x', p_sql) into r;
  execute 'reset role';
  return r;
end $$;
-- True when the query is refused with 42501 for the user.
create function pg_temp.refused(p_user text, p_sql text) returns boolean language plpgsql as $$
begin
  perform pg_temp.rows(p_user, p_sql);
  return false;
exception when insufficient_privilege then
  execute 'reset role';
  return true;
end $$;

-- RLS4-1: the act columns, one row each (the brief's list) ---------------------------------------------------------------------
create temp table acts (t text, c text);
insert into acts values
  ('visit_reports', 'created_by'), ('visit_reports', 'countersigned_by'), ('visit_reports', 'withdrawn_by'),
  ('visit_report_returns', 'returned_by'), ('care_visits', 'suspended_by'), ('visit_plan_changes', 'actor_id'),
  ('visit_status_notes', 'actor_id'), ('working_time_facts', 'performer_id'), ('care_plan_items', 'created_by'),
  ('care_plan_items', 'retired_by'), ('case_tasks', 'done_by'), ('case_lifecycle_events', 'actor_id'),
  ('case_gp_notices', 'recorded_by'), ('cases', 'intake_consent_confirmed_by'), ('team_decisions', 'actor_id'),
  ('quality_events', 'author_id'), ('quality_event_log', 'actor_id'), ('quality_holds', 'set_by'),
  ('quality_holds', 'lifted_by'), ('billable_facts', 'created_by'), ('safety_signals', 'taken_by'),
  ('referral_links', 'actor_id');
-- RLS4-2: the assignment columns that stay readable to the team
create temp table keeps (t text, c text);
insert into keeps values
  ('cases', 'primary_nurse_id'), ('cases', 'deputy_nurse_id'), ('care_visits', 'responsible_user_id'),
  ('care_visits', 'covered_by'), ('cover_events', 'nurse_id'), ('visit_reports', 'performer_id'),
  ('visit_report_returns', 'performer_id'), ('quality_events', 'owner_id');
grant select on acts, keeps to authenticated;

-- Fixtures: three Nord visits of case 208 today; a display name for the registered nurse ------------------------------------------
insert into public.member_profiles (organization_id, user_id, display_name, updated_by)
values ('00000000-0000-4000-b000-000000000011', pg_temp.u('p'), 'Synthetisch RN Nord', pg_temp.u('p'))
on conflict (organization_id, user_id) do update set display_name = excluded.display_name;
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status, planned_minutes_a)
select '00000000-0000-4000-b000-000000000011', pg_temp.v(n), '00000000-0000-4000-a000-000000000208',
       '00000000-0000-4000-a000-000000000101', pg_temp.t(), s, s + interval '20 minutes', array['Grundpflege'], false, 'planned', 20
from (values (1, time '18:10'), (2, time '18:40'), (3, time '19:10')) x(n, s);

-- The care assistant performs visits 2 and 3 and signs; the registered nurse countersigns 2 and returns 3.
create function pg_temp.run_and_sign(n int, k int) returns text language plpgsql as $$
declare rid uuid; h text;
begin
  perform pg_temp.cmd('ca', format('select public.start_visit(%L, %L)', pg_temp.v(n), pg_temp.k(k)));
  perform pg_temp.cmd('ca', format('select public.complete_visit(%L, %L)', pg_temp.v(n), pg_temp.k(k + 1)));
  perform pg_temp.cmd('ca', format('select public.create_report_draft(%L, %L, %L)', pg_temp.v(n), 'Synthetisch', pg_temp.k(k + 2)));
  select id into rid from public.visit_reports where visit_id = pg_temp.v(n);
  select f ->> 'snapshot_hash' into h
  from jsonb_array_elements(pg_temp.rows('ca', format('select * from public.field_reports(%L)', pg_temp.t()))) f
  where f ->> 'report_id' = rid::text;
  return pg_temp.res('ca', format('select public.sign_report(%L, %L, %L)', rid, h, pg_temp.k(k + 3)));
end $$;
select is(pg_temp.run_and_sign(2, 10), 'ok', 'fixture: the care assistant signs visit 2');
select is(pg_temp.run_and_sign(3, 20), 'ok', 'fixture: the care assistant signs visit 3');
select is(pg_temp.res('p', format('select public.countersign_report(%L, %L)',
            (select id from public.visit_reports where visit_id = pg_temp.v(2)), pg_temp.k(30))), 'ok',
          'fixture: the registered nurse countersigns visit 2');
select is(pg_temp.res('p', format('select public.return_report(%L, %L, %L)',
            (select id from public.visit_reports where visit_id = pg_temp.v(3)), 'Synthetisch: Zeit prüfen', pg_temp.k(31))), 'ok',
          'fixture: the registered nurse returns visit 3');
-- A quality event and a hold on visit 1, by the registered nurse (an approved test type as in 020).
insert into public.quality_event_types (code, label, sets_hold, serious_default, approved_by)
values ('test_info', 'Testtyp ohne Stopp', false, false, 'pgTAP fixture') on conflict do nothing;
select is(pg_temp.res('p', format('select public.record_quality_event(%L, %L, %L, %L, %L, %L)', pg_temp.v(1), 'test_info', 'low',
            private.now(), 'Synthetisch: RLS4 Ereignis', pg_temp.k(40))), 'ok', 'fixture: the registered nurse records a quality event');
select is(pg_temp.res('p', format('select public.set_quality_hold(%L, %L, %L)', pg_temp.v(1), 'Synthetisch: RLS4 Stopp', pg_temp.k(41))), 'ok',
          'fixture: she sets a hold');
-- A status note on visit 1 by the registered nurse, written as the table owner (as 071).
insert into public.visit_status_notes (organization_id, visit_id, kind, note, actor_id, idempotency_key, at_door)
values ('00000000-0000-4000-b000-000000000011', pg_temp.v(1), 'no_show', 'Synthetisch: RLS4 Notiz', pg_temp.u('p'), pg_temp.k(42), true);

-- RLS4-1: an active member of the record's team gets 42501 on each act column --------------------------------------------------
select is((select string_agg(a.t || '.' || a.c, ',' order by a.t, a.c) from acts a
           where not pg_temp.refused('ca', format('select %I from public.%I', a.c, a.t))), null,
          'RLS4-1: the care assistant of the team gets 42501 on a direct select of every act column');
select is((select string_agg(a.t || '.' || a.c, ',' order by a.t, a.c) from acts a
           where not pg_temp.refused('p', format('select %I from public.%I', a.c, a.t))), null,
          'RLS4-1: … and so does the registered nurse who did the acts (her own acts too, per record only)');
select ok(pg_temp.refused('ca', format('select countersigned_by from public.visit_reports where visit_id = %L', pg_temp.v(2))),
          'RLS4-1: visit_reports.countersigned_by of a report of her own team is refused');
select ok(pg_temp.refused('ca', format('select returned_by from public.visit_report_returns where visit_id = %L', pg_temp.v(3))),
          'RLS4-1: visit_report_returns.returned_by of her own returned report is refused');
select ok(pg_temp.refused('ca', format('select author_id from public.quality_events where visit_id = %L', pg_temp.v(1))),
          'RLS4-1: quality_events.author_id is refused');
select ok(pg_temp.refused('ca', format('select set_by from public.quality_holds where visit_id = %L', pg_temp.v(1))),
          'RLS4-1: quality_holds.set_by is refused');
select ok(pg_temp.refused('ca', format('select actor_id from public.visit_status_notes where visit_id = %L', pg_temp.v(1))),
          'RLS4-1: visit_status_notes.actor_id is refused');
select ok(pg_temp.refused('ca', format('select created_by from public.visit_reports where visit_id = %L', pg_temp.v(2))),
          'RLS4-1: visit_reports.created_by is refused');
select ok(pg_temp.refused('ca', 'select performer_id from public.working_time_facts'),
          'RLS4-1: working_time_facts.performer_id is refused (also for her own rows)');
-- … no list, count or filter per person
select is((select string_agg(a.t || '.' || a.c, ',' order by a.t, a.c) from acts a
           where not pg_temp.refused('ca', format('select %I, count(*) from public.%I group by 1', a.c, a.t))), null,
          'RLS4-1: a group by on any act column is refused');
select is((select string_agg(a.t || '.' || a.c, ',' order by a.t, a.c) from acts a
           where not pg_temp.refused('ca', format('select count(*) from public.%I where %I = %L', a.t, a.c, pg_temp.u('p')))), null,
          'RLS4-1: a filter on any act column is refused');
select is((select string_agg(distinct a.t, ',' order by a.t) from acts a
           where not pg_temp.refused('ca', format('select * from public.%I limit 1', a.t))), null,
          'RLS4-1: select * on each of the 18 tables is refused');
select ok(pg_temp.refused('ca', 'select count(distinct actor_id) from public.visit_plan_changes'),
          'RLS4-1: no count of distinct actors either');
-- … the grants themselves
select is((select string_agg(a.t || '.' || a.c, ',' order by a.t, a.c) from acts a
           where has_column_privilege('authenticated', format('public.%I', a.t), a.c, 'select')), null,
          'RLS4-1: authenticated holds no select on any act column');
select is((select string_agg(distinct a.t, ',' order by a.t) from acts a
           where has_table_privilege('authenticated', format('public.%I', a.t), 'select')), null,
          'RLS4-1: no table-wide select grant remains on the 18 tables');
select is((select string_agg(c.table_name || '.' || c.column_name, ',' order by c.table_name, c.column_name)
           from information_schema.columns c
           where c.table_schema = 'public'
             and c.table_name in ('visit_report_returns', 'care_visits', 'visit_plan_changes', 'visit_status_notes',
                                  'working_time_facts', 'care_plan_items', 'case_tasks', 'case_lifecycle_events', 'team_decisions',
                                  'quality_events', 'quality_event_log', 'quality_holds', 'billable_facts', 'referral_links')
             and not has_column_privilege('authenticated', format('public.%I', c.table_name), c.column_name, 'select')),
          'billable_facts.created_by,care_plan_items.created_by,care_plan_items.retired_by,care_visits.suspended_by,'
          || 'case_lifecycle_events.actor_id,case_tasks.done_by,quality_event_log.actor_id,quality_events.author_id,'
          || 'quality_holds.lifted_by,quality_holds.set_by,referral_links.actor_id,team_decisions.actor_id,'
          || 'visit_plan_changes.actor_id,visit_report_returns.returned_by,visit_status_notes.actor_id,working_time_facts.performer_id',
          'RLS4-1: on the 14 tables that had a table-wide grant exactly the act columns are closed; every other column stays selectable');
select ok(has_column_privilege('authenticated', 'public.cases', 'assigned_team_id', 'select')
          and has_column_privilege('authenticated', 'public.case_gp_notices', 'informed_on', 'select')
          and has_column_privilege('authenticated', 'public.safety_signals', 'signal_kind', 'select')
          and has_column_privilege('authenticated', 'public.visit_reports', 'status', 'select'),
          'RLS4-1: on the four column-grant tables the other granted columns stay selectable');
select ok(not has_column_privilege('authenticated', 'public.cases', 'diagnosis_tags', 'select')
          and not has_column_privilege('authenticated', 'public.visit_reports', 'snapshot', 'select'),
          'RLS4-1: … and a column that was closed before stays closed (nothing widened)');
select is((select string_agg(distinct a.t, ',' order by a.t) from (select t from acts union select t from keeps) a
           where has_any_column_privilege('anon', format('public.%I', a.t), 'select')
              or has_table_privilege('anon', format('public.%I', a.t), 'insert, update, delete')), null,
          'RLS4: anon holds nothing on these tables');

-- RLS4-2: the assignment columns stay readable to the team ----------------------------------------------------------------
select is((select string_agg(k.t || '.' || k.c, ',' order by k.t, k.c) from keeps k
           where not has_column_privilege('authenticated', format('public.%I', k.t), k.c, 'select')), null,
          'RLS4-2: authenticated keeps select on every assignment column');
select is((select string_agg(k.t || '.' || k.c, ',' order by k.t, k.c) from keeps k
           where pg_temp.refused('p', format('select %I from public.%I limit 1', k.c, k.t))), null,
          'RLS4-2: a member of the team selects every assignment column');
select is(jsonb_array_length(pg_temp.rows('ca', 'select primary_nurse_id, deputy_nurse_id from public.cases where id = ''00000000-0000-4000-a000-000000000208''')), 1,
          'RLS4-2: the team reads the case''s primary and deputy nurse (J6)');
select is(jsonb_array_length(pg_temp.rows('ca', format('select responsible_user_id, covered_by from public.care_visits where id = %L', pg_temp.v(1)))), 1,
          'RLS4-2: the team reads who is responsible for the visit and who covers it (J3, COVER1)');
select is(pg_temp.rows('ca', format('select performer_id from public.visit_reports where visit_id = %L', pg_temp.v(2))) #>> '{0,performer_id}',
          pg_temp.u('ca')::text, 'RLS4-2: the team reads who must act on the report (F6R)');
select is(pg_temp.rows('ca', format('select performer_id from public.visit_report_returns where visit_id = %L', pg_temp.v(3))) #>> '{0,performer_id}',
          pg_temp.u('ca')::text, 'RLS4-2: the performer reads that the returned report is hers to correct');
select is(jsonb_array_length(pg_temp.rows('ca', format('select owner_id from public.quality_events where visit_id = %L', pg_temp.v(1)))), 1,
          'RLS4-2: the team reads who handles the quality event now');

-- RLS4-3: each reader still returns the person per record to her team -----------------------------------------------------
create function pg_temp.fr(p_user text, n int) returns jsonb language sql as $$
  select f from jsonb_array_elements(pg_temp.rows(p_user, format('select * from public.field_reports(%L)', pg_temp.t()))) f
  where f ->> 'visit_id' = pg_temp.v(n)::text $$;
select is(pg_temp.fr('ca', 2) ->> 'countersigned_by_name', 'Synthetisch RN Nord',
          'RLS4-3: field_reports gives the team who countersigned the report (J5), per report');
select is(pg_temp.fr('ca', 2) ->> 'status', 'final', 'RLS4-3: … the countersigned report is final');
select is(pg_temp.fr('ca', 3) ->> 'returned_by_name', 'Synthetisch RN Nord',
          'RLS4-3: field_reports gives the performer who returned her report (F6R), per report');
select is(pg_temp.rows('ca', format('select returned_by_name from public.report_returns(%L)', pg_temp.v(3))) #>> '{0,returned_by_name}',
          'Synthetisch RN Nord', 'RLS4-3: report_returns gives the returner per returned report');
select is(pg_temp.rows('ca', 'select returned_by_name from public.field_returned_reports()') #>> '{0,returned_by_name}',
          'Synthetisch RN Nord', 'RLS4-3: field_returned_reports gives the returner per report');
select is((select f ->> 'person_name' from jsonb_array_elements(pg_temp.rows('ca', format('select * from public.field_quality(%L)', pg_temp.t()))) f
           where f ->> 'visit_id' = pg_temp.v(1)::text and f ->> 'kind' = 'event'), 'Synthetisch RN Nord',
          'RLS4-3: field_quality gives the team who reported the event ("gemeldet von"), per event');
select is((select f ->> 'person_name' from jsonb_array_elements(pg_temp.rows('ca', format('select * from public.field_quality(%L)', pg_temp.t()))) f
           where f ->> 'visit_id' = pg_temp.v(1)::text and f ->> 'kind' = 'hold'), 'Synthetisch RN Nord',
          'RLS4-3: field_quality gives the team who set the hold, per hold');
select ok((select (f ->> 'own')::boolean from jsonb_array_elements(pg_temp.rows('p', format('select * from public.field_quality(%L)', pg_temp.t()))) f
           where f ->> 'visit_id' = pg_temp.v(1)::text and f ->> 'kind' = 'event'),
          'RLS4-3: field_quality tells the author that the event is her own');
select is((select f ->> 'actor_name' from jsonb_array_elements(pg_temp.rows('ca', format('select * from public.field_visit_status_notes(%L)', pg_temp.t()))) f
           where f ->> 'visit_id' = pg_temp.v(1)::text), 'Synthetisch RN Nord',
          'RLS4-3: field_visit_status_notes gives the team who wrote the status note, per note');
select is(jsonb_array_length(pg_temp.rows('ca', format('select * from public.field_reports(%L) where visit_id in (%L, %L)',
                                                        pg_temp.t(), pg_temp.v(2), pg_temp.v(3)))), 2,
          'RLS4-3: the readers give one row per record, not one per person');
-- … and nothing to another organisation
select is(jsonb_array_length(pg_temp.rows('fremd', format('select * from public.field_quality(%L)', pg_temp.t()))), 0,
          'RLS4-3: field_quality gives another organisation nothing');
select is(jsonb_array_length(pg_temp.rows('fremd', format('select * from public.report_returns(%L)', pg_temp.v(3)))), 0,
          'RLS4-3: report_returns gives another organisation nothing');

-- Negative: rows unchanged (RLS untouched), no new per-person reader ---------------------------------------------------------
select is(jsonb_array_length(pg_temp.rows('ca', format('select id, status from public.care_visits where id in (%L, %L, %L)',
                                                        pg_temp.v(1), pg_temp.v(2), pg_temp.v(3)))), 3,
          'Negative: the team still reads the visit rows (other columns, RLS unchanged)');
select is(jsonb_array_length(pg_temp.rows('fremd', format('select id from public.care_visits where id = %L', pg_temp.v(1)))), 0,
          'Negative: another organisation still reads no row');
select is(jsonb_array_length(pg_temp.rows('ca', format('select id, set_at, lifted_at from public.quality_holds where visit_id = %L', pg_temp.v(1)))), 1,
          'Negative: the open-holds read of the app (id, visit, reason, set_at) still works');
select ok(not pg_temp.refused('ca', 'select case_id, informed_on, channel, recorded_at from public.case_gp_notices limit 1'),
          'Negative: the GP-notice read of the app (case, date, channel, time) still works');
select ok(not pg_temp.refused('ca', 'select id, created_at, name, first_name, last_name, region, ort, status, urgency, bedarf, care_needs, assigned_team, assigned_team_id from public.cases limit 1'),
          'Negative: the case-summary read of the app (CASE_SUMMARY_COLUMNS) still works');
select is((select string_agg(p.proname, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname ~ '(^|_)(acts|actors|by_person|per_person)(_|$)'), null,
          'Negative: no reader lists acts per person');

select * from finish();
rollback;
