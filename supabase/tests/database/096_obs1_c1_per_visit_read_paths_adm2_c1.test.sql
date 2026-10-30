-- OBS1-C1 (= OBS1-7 (a)) and ADM2-C1 (migration 0096, ADR-119). Briefs `docs/agents/briefs/OBS1.md` OBS1-7 and
-- `docs/agents/briefs/ADM2.md` condition ADM2-C1. All data synthetic.
-- Seed users: pflege …902 (RN, Nord) · assist …906 (CA, Nord) · ops …904 · admin …905 (org A) · fremd …903 (org B).
-- Synthetic users added here: …9601 "L", a Nord care assistant whose contract ends today · …9602 "K", a Nord care
-- assistant who stays.
begin;
create extension if not exists pgtap with schema extensions;

select plan(39);

-- Pinned clock (DST1 pattern): 10:00 Zurich today = day T.
select set_config('navora.test_now',
  (((private.now() at time zone 'Europe/Zurich')::date + time '10:00') at time zone 'Europe/Zurich')::text, true);
create temp table d0 as select (private.now() at time zone 'Europe/Zurich')::date as t;
create function pg_temp.t() returns date language sql stable as $$ select t from d0 $$;
create function pg_temp.at(p_local timestamp) returns void language sql as $$
  select set_config('navora.test_now', private.at_zurich(p_local)::text, true) $$;

create function pg_temp.act_as(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  select set_config('request.jwt.claim.sub', uid, true);
$$;
create function pg_temp.u(n text) returns uuid language sql immutable as $$
  select (case n when 'p' then '00000000-0000-4000-a000-000000000902' when 'ca' then '00000000-0000-4000-a000-000000000906'
                 when 'ops' then '00000000-0000-4000-a000-000000000904' when 'admin' then '00000000-0000-4000-a000-000000000905'
                 when 'fremd' then '00000000-0000-4000-a000-000000000903'
                 when 'l' then 'a0960000-0000-4000-a000-000000009601' when 'k' then 'a0960000-0000-4000-a000-000000009602' end)::uuid
$$;
create function pg_temp.k(n int) returns uuid language sql immutable as $$
  select ('a0961000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;
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

-- The visit: Nord, case 208, today; pflege performs, writes an observation, signs (as in 016).
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status, planned_minutes_a)
values ('00000000-0000-4000-b000-000000000011', 'a0960000-0000-4000-8000-000000000001', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.t(), '16:00', '16:30', array['Grundpflege'], false, 'planned', 30);
select is(pg_temp.res('p', format('select public.start_visit(%L, %L)', 'a0960000-0000-4000-8000-000000000001', pg_temp.k(1))), 'ok',
          'fixture: the registered nurse starts the visit');
select is(pg_temp.res('p', format('select public.record_observation(%L, %L, false, null, %L)', 'a0960000-0000-4000-8000-000000000001',
                                  'Synthetisch: OBS1-7 Beobachtung', pg_temp.k(2))), 'ok', 'fixture: she records an observation');
select is(pg_temp.res('p', format('select public.complete_visit(%L, %L)', 'a0960000-0000-4000-8000-000000000001', pg_temp.k(3))), 'ok',
          'fixture: she completes the visit');
select is(pg_temp.res('p', format('select public.create_report_draft(%L, %L, %L)', 'a0960000-0000-4000-8000-000000000001',
                                  'Synthetisch', pg_temp.k(4))), 'ok', 'fixture: she drafts the report');
create temp table r1 as select id from public.visit_reports where visit_id = 'a0960000-0000-4000-8000-000000000001';
select is(pg_temp.res('p', format('select public.sign_report(%L, %L, %L)', (select id from r1),
            (select f ->> 'snapshot_hash' from jsonb_array_elements(pg_temp.rows('p', format('select * from public.field_reports(%L)', pg_temp.t()))) f
             where f ->> 'report_id' = (select id from r1)::text), pg_temp.k(5))), 'ok', 'fixture: she signs what she saw');

-- OBS1-7 (a): the five columns are refused through the table API -----------------------------------------------------------
select ok(pg_temp.refused('ca', format('select snapshot from public.visit_reports where id = %L', (select id from r1))),
          'OBS1-7: an active member of the visit''s team gets 42501 on visit_reports.snapshot');
select ok(pg_temp.refused('ca', format('select signed_by from public.visit_reports where id = %L', (select id from r1))),
          'OBS1-7: … on visit_reports.signed_by');
select ok(pg_temp.refused('ca', format('select signed_at from public.visit_reports where id = %L', (select id from r1))),
          'OBS1-7: … on visit_reports.signed_at');
select ok(pg_temp.refused('ca', format('select author_id from public.visit_observations where visit_id = %L', 'a0960000-0000-4000-8000-000000000001')),
          'OBS1-7: … on visit_observations.author_id');
select ok(pg_temp.refused('ca', format('select recorded_at from public.visit_observations where visit_id = %L', 'a0960000-0000-4000-8000-000000000001')),
          'OBS1-7: … on visit_observations.recorded_at');
select ok(pg_temp.refused('p', 'select * from public.visit_reports'), 'OBS1-7: select * on visit_reports is refused, also for the signer');
select ok(pg_temp.refused('p', 'select * from public.visit_observations'), 'OBS1-7: select * on visit_observations is refused, also for the author');
select ok(pg_temp.refused('ca', 'select count(*) from public.visit_observations group by author_id'),
          'OBS1-7: no count per author through the table API');
select ok(not has_table_privilege('authenticated', 'public.visit_reports', 'select')
          and not has_table_privilege('authenticated', 'public.visit_observations', 'select'),
          'OBS1-7: no table-wide select grant remains on the two tables');
select is((select string_agg(c.table_name || '.' || c.column_name, ',' order by c.table_name, c.column_name)
           from information_schema.columns c
           where c.table_schema = 'public' and c.table_name in ('visit_reports', 'visit_observations')
             and not has_column_privilege('authenticated', format('public.%I', c.table_name), c.column_name, 'select')),
          'visit_observations.author_id,visit_observations.author_qualification_recorded,visit_observations.recorded_at,'
          || 'visit_reports.countersigned_by,visit_reports.created_by,visit_reports.signed_at,visit_reports.signed_by,'
          || 'visit_reports.snapshot,visit_reports.withdrawn_by',
          'OBS1-7 and RLS4-1 (0099): exactly these columns are closed (RLS3-4 pattern); every other column stays selectable');
select ok(not has_any_column_privilege('anon', 'public.visit_reports', 'select')
          and not has_any_column_privilege('anon', 'public.visit_observations', 'select'), 'OBS1-7: anon selects no column');
select is(jsonb_array_length(pg_temp.rows('ca', format('select id, status, version, performer_id, countersigned_at from public.visit_reports where id = %L', (select id from r1)))), 1,
          'OBS1-7: the team still reads the report row''s other columns (RLS unchanged)');

-- The per-visit read paths still give the values to the team ----------------------------------------------------------------
create function pg_temp.fr(p_user text) returns jsonb language sql as $$
  select f from jsonb_array_elements(pg_temp.rows(p_user, format('select * from public.field_reports(%L)', pg_temp.t()))) f
  where f ->> 'visit_id' = 'a0960000-0000-4000-8000-000000000001' $$;
select is(pg_temp.fr('ca') #>> '{snapshot,observations,0,author_id}', pg_temp.u('p')::text,
          'field_reports: a teammate reads the observation author in the signed snapshot');
select is(pg_temp.fr('ca') #>> '{snapshot,observations,0,content}', 'Synthetisch: OBS1-7 Beobachtung',
          'field_reports: … and its content');
select ok((pg_temp.fr('ca') ->> 'signed_at') is not null and (pg_temp.fr('ca') ->> 'i_signed')::boolean = false,
          'field_reports: a teammate reads when it was signed (not by her)');
select ok((pg_temp.fr('p') ->> 'i_signed')::boolean, 'field_reports: the signer reads that she signed it');
create function pg_temp.note(p_user text) returns jsonb language sql as $$
  select n from jsonb_array_elements(pg_temp.rows(p_user, format('select * from public.field_notes(%L)', pg_temp.t()))) n
  where n ->> 'visit_id' = 'a0960000-0000-4000-8000-000000000001' and n ->> 'kind' = 'observation' $$;
select ok((pg_temp.note('ca') ->> 'recorded_at') is not null and (pg_temp.note('ca') ->> 'own')::boolean = false,
          'field_notes: a teammate reads the time of the observation, not hers');
select ok((pg_temp.note('p') ->> 'own')::boolean, 'field_notes: the author reads it as her own');
select is(pg_temp.rows('ops', format('select * from public.field_notes(%L)', pg_temp.t())), '[]'::jsonb,
          'field_notes: Operations (no team) reads nothing');
select is((select count(*)::int from jsonb_array_elements(pg_temp.rows('fremd', format('select * from public.field_reports(%L)', pg_temp.t())))), 0,
          'field_reports: another organisation reads nothing');

-- `cra` 17:30 condition on OBS1-7: the countersigning registered nurse and F6R still read snapshot, signer and author ----------
-- Visit 2 (Nord, case 208, today 17:00): the care assistant performs it, writes an observation and signs.
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, time_end, services_provided, billable, status, planned_minutes_a)
values ('00000000-0000-4000-b000-000000000011', 'a0960000-0000-4000-8000-000000000002', '00000000-0000-4000-a000-000000000208',
        '00000000-0000-4000-a000-000000000101', pg_temp.t(), '17:00', '17:30', array['Grundpflege'], false, 'planned', 30);
create function pg_temp.fr2(p_user text) returns jsonb language sql as $$
  select f from jsonb_array_elements(pg_temp.rows(p_user, format('select * from public.field_reports(%L)', pg_temp.t()))) f
  where f ->> 'visit_id' = 'a0960000-0000-4000-8000-000000000002' $$;
select ok(pg_temp.res('ca', format('select public.start_visit(%L, %L)', 'a0960000-0000-4000-8000-000000000002', pg_temp.k(20))) = 'ok'
          and pg_temp.res('ca', format('select public.record_observation(%L, %L, true, null, %L)', 'a0960000-0000-4000-8000-000000000002',
                                       'Synthetisch: OBS1-7 Beobachtung FaGe', pg_temp.k(21))) = 'ok'
          and pg_temp.res('ca', format('select public.complete_visit(%L, %L)', 'a0960000-0000-4000-8000-000000000002', pg_temp.k(22))) = 'ok'
          and pg_temp.res('ca', format('select public.create_report_draft(%L, null, %L)', 'a0960000-0000-4000-8000-000000000002', pg_temp.k(23))) = 'ok',
          'fixture: the care assistant performs visit 2, writes an observation and drafts the report');
create temp table r2 as select id from public.visit_reports where visit_id = 'a0960000-0000-4000-8000-000000000002';
select is(pg_temp.res('ca', format('select public.sign_report(%L, %L, %L)', (select id from r2), pg_temp.fr2('ca') ->> 'snapshot_hash', pg_temp.k(24))),
          'ok', 'fixture: she signs what she saw (countersignature required)');
select ok(exists (select 1 from jsonb_array_elements(pg_temp.rows('p', 'select * from public.field_countersign_queue()')) q
                  where q ->> 'report_id' = (select id from r2)::text),
          'the countersigning registered nurse finds it in her queue');
select ok(pg_temp.fr2('p') #>> '{snapshot,observations,0,author_id}' = pg_temp.u('ca')::text
          and (pg_temp.fr2('p') ->> 'signed_at') is not null and (pg_temp.fr2('p') ->> 'i_can_countersign')::boolean,
          'field_reports: the countersigning registered nurse reads the author in the snapshot and when it was signed');
select is(pg_temp.res('p', format('select public.return_report(%L, %L, %L)', (select id from r2), 'Synthetisch: bitte Zeiten prüfen', pg_temp.k(25))),
          'ok', 'fixture: she returns it (F6R)');
select ok((select bool_and(x #>> '{snapshot,observations,0,author_id}' = pg_temp.u('ca')::text)
           from jsonb_array_elements(pg_temp.rows('ca', format('select * from public.report_returns(%L)', 'a0960000-0000-4000-8000-000000000002'))) x)
          and (select bool_and(x #>> '{snapshot,observations,0,author_id}' = pg_temp.u('ca')::text)
               from jsonb_array_elements(pg_temp.rows('p', format('select * from public.report_returns(%L)', 'a0960000-0000-4000-8000-000000000002'))) x)
          and jsonb_array_length(pg_temp.rows('ca', format('select * from public.report_returns(%L)', 'a0960000-0000-4000-8000-000000000002'))) = 1,
          'report_returns (F6R): the performer and the registered nurse read the returned snapshot with its author');

-- ADM2-C1: the sweep deletes the push subscriptions of an access her contract end ended ---------------------------------------
insert into auth.users (id, email)
select pg_temp.u(n), 'adm2c1-' || n || '@navora.test' from unnest(array['l', 'k']) n;
insert into public.organization_memberships (organization_id, user_id, role)
select '00000000-0000-4000-b000-000000000011', pg_temp.u(n), 'nurse' from unnest(array['l', 'k']) n;
insert into public.team_memberships (team_id, user_id, qualification)
select '00000000-0000-4000-a000-000000000101', pg_temp.u(n), 'care_assistant' from unnest(array['l', 'k']) n;
insert into public.push_subscriptions (organization_id, user_id, vendor, endpoint, p256dh, auth_secret, last_result)
select '00000000-0000-4000-b000-000000000011', pg_temp.u(n), 'google_fcm',
       'https://fcm.googleapis.com/fcm/send/adm2c1-' || n, repeat('A', 87), repeat('B', 22), 'sent'
from unnest(array['l', 'k']) n;
select is(pg_temp.res('admin', format('select public.set_team_admission(%L, true, %L)', '00000000-0000-4000-b000-000000000011', pg_temp.k(10))),
          'ok', 'fixture: the administrator switches team admission on');
select is(pg_temp.cmd('admin', format('select public.set_member_contract_end(%L, %L, %L)', pg_temp.u('l'), pg_temp.t(), pg_temp.k(11))) ->> 'result',
          'ok', 'fixture: L''s contract ends today (ADM2-11)');

create function pg_temp.subs(p_who text) returns int language sql as $$
  select count(*)::int from public.push_subscriptions where user_id = pg_temp.u(p_who) $$;
select pg_temp.at((pg_temp.t() + time '23:59')::timestamp);
select lives_ok($$select pg_temp.cmd('admin', format('select public.admin_team_admissions(%L)', '00000000-0000-4000-b000-000000000011'))$$,
                'a sweep runs at 23:59 on her last day (administrator page load)');
select is(pg_temp.subs('l'), 1, 'ADM2-C1: at 23:59 her subscription is still there (her access is open)');
select pg_temp.at((pg_temp.t() + 1 + time '00:00:30')::timestamp);
select ok(private.access_ended(pg_temp.u('l')), 'fixture: after 00:00 her access has ended (ADM2-13)');
select lives_ok($$select pg_temp.cmd('admin', format('select public.admin_team_admissions(%L)', '00000000-0000-4000-b000-000000000011'))$$,
                'the first sweep after 00:00');
select ok(pg_temp.subs('l') = 0 and pg_temp.subs('k') = 1,
          'ADM2-C1: her subscription is gone after the first sweep after 00:00; a colleague''s stays');
select is((select count(*)::int from public.audit_events a
           where a.table_name = 'push_subscriptions' and a.actor_id is null and a.actor_role = 'system'
             and a.changed = jsonb_build_object('deleted', true, 'reason', 'contract_ended')), 1,
          'ADM2-C1: one audit row per deleted subscription, as the system, reason contract_ended (code only)');

select * from finish();
rollback;
