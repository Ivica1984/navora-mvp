-- COVER1 (PO review 2026-10-22): two acceptances in parallel sessions — only one succeeds.
-- Uses dblink for two real sessions. Their data must be committed to be seen, so this file sets up and
-- removes its own rows (fixed ids) and leaves the database as it found it.
begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;

select plan(3);

create function pg_temp.connect(name text) returns boolean language plpgsql as $$
declare
  c text;
begin
  foreach c in array array[
    format('dbname=%s user=postgres', current_database()),
    format('dbname=%s user=postgres password=postgres host=127.0.0.1', current_database()),
    format('dbname=%s user=postgres host=/var/tmp/navora-pg port=54329', current_database())]
  loop
    begin
      perform dblink_connect(name, c);
      return true;
    exception when others then null;
    end;
  end loop;
  return false;
end $$;

select ok(pg_temp.connect('a') and pg_temp.connect('b'), 'two independent sessions');

-- Committed fixtures (session a): cover on for org A, coach …901 and ops …904 in Mitte, visit Q of Nord in 10 h.
select dblink_exec('a', $sql$
  set session_replication_role = replica;
  delete from public.cover_events where visit_id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.visit_plan_changes where visit_id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.audit_events where idempotency_key in ('ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000002')
    or entity_id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.care_visits where id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.cover_settings where organization_id = '00000000-0000-4000-b000-000000000011';
  delete from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000102'
    and user_id in ('00000000-0000-4000-a000-000000000901', '00000000-0000-4000-a000-000000000904');
  set session_replication_role = origin;
  insert into public.cover_settings (organization_id, offer_lead_hours, fallback_lead_hours, cover_enabled)
    values ('00000000-0000-4000-b000-000000000011', 24, 4, true);
  insert into public.team_memberships (team_id, user_id, qualification) values
    ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'care_assistant'),
    ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000904', 'registered_nurse');
  insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, services_provided, billable, status, planned_minutes_a)
    values ('00000000-0000-4000-b000-000000000011', 'ae000000-0000-4000-8000-00000000000a', '00000000-0000-4000-a000-000000000208',
            '00000000-0000-4000-a000-000000000101', (now() at time zone 'Europe/Zurich' + interval '10 hours')::date,
            date_trunc('minute', (now() at time zone 'Europe/Zurich' + interval '10 hours'))::time, array['Grundpflege'], false, 'planned', 30);
$sql$);

-- Both sessions accept at the same time, as two different nurses.
select dblink_exec('a', $sql$set "request.jwt.claims" to '{"sub":"00000000-0000-4000-a000-000000000901","role":"authenticated"}'$sql$);
select dblink_exec('b', $sql$set "request.jwt.claims" to '{"sub":"00000000-0000-4000-a000-000000000904","role":"authenticated"}'$sql$);
select dblink_exec('a', 'set role authenticated');
select dblink_exec('b', 'set role authenticated');
select dblink_send_query('a', $sql$select public.accept_cover('ae000000-0000-4000-8000-00000000000a', 'ae000000-0000-4000-8000-000000000001')$sql$);
select dblink_send_query('b', $sql$select public.accept_cover('ae000000-0000-4000-8000-00000000000a', 'ae000000-0000-4000-8000-000000000002')$sql$);
create temp table results as
  select r from dblink_get_result('a') as t(r text)
  union all
  select r from dblink_get_result('b') as t(r text);
-- Drain both connections (an async query ends with an empty result) before reusing them.
select count(*) from dblink_get_result('a') as t(r text);
select count(*) from dblink_get_result('b') as t(r text);

select is((select array_agg(r order by r) from results), array['ok', 'taken'], 'one acceptance wins, the other gets "taken"');
select is((select count(*)::int from dblink('a', $sql$select 1 from public.cover_events
           where visit_id = 'ae000000-0000-4000-8000-00000000000a' and kind = 'accepted'$sql$) as t(x int)), 1,
  'exactly one acceptance is recorded');

-- Clean up the committed rows.
select dblink_exec('a', 'reset role');
select dblink_exec('a', $sql$
  set session_replication_role = replica;
  delete from public.cover_events where visit_id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.visit_plan_changes where visit_id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.audit_events where idempotency_key in ('ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000002')
    or entity_id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.care_visits where id = 'ae000000-0000-4000-8000-00000000000a';
  delete from public.cover_settings where organization_id = '00000000-0000-4000-b000-000000000011';
  delete from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000102'
    and user_id in ('00000000-0000-4000-a000-000000000901', '00000000-0000-4000-a000-000000000904');
  set session_replication_role = origin;
$sql$);
select dblink_disconnect('a');
select dblink_disconnect('b');

select * from finish();
rollback;
