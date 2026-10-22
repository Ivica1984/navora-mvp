#!/usr/bin/env bash
# COVER1 (PO review 2026-10-22): two nurses accept the same offered visit in two real, parallel database
# sessions — exactly one acceptance may win. pgTAP runs inside one transaction and cannot open a second
# session on Supabase (dblink needs credentials there), so this check uses two psql processes.
# Commits its own fixture rows (fixed ids) and removes them again. Usage: DB_URL=... cover-accept.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
VISIT=ae000000-0000-4000-8000-00000000000a
ORG=00000000-0000-4000-b000-000000000011
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }

cleanup() {
  psql_q <<SQL
set session_replication_role = replica;
delete from public.cover_events where visit_id = '$VISIT';
delete from public.visit_plan_changes where visit_id = '$VISIT';
delete from public.audit_events where entity_id = '$VISIT'
   or idempotency_key in ('ae000000-0000-4000-8000-000000000001', 'ae000000-0000-4000-8000-000000000002');
delete from public.care_visits where id = '$VISIT';
delete from public.cover_settings where organization_id = '$ORG';
delete from public.team_memberships where team_id = '00000000-0000-4000-a000-000000000102'
  and user_id in ('00000000-0000-4000-a000-000000000901', '00000000-0000-4000-a000-000000000904');
SQL
}
trap cleanup EXIT
cleanup

psql_q <<SQL
insert into public.cover_settings (organization_id, offer_lead_hours, fallback_lead_hours, cover_enabled) values ('$ORG', 24, 4, true);
insert into public.team_memberships (team_id, user_id, qualification) values
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000901', 'care_assistant'),
  ('00000000-0000-4000-a000-000000000102', '00000000-0000-4000-a000-000000000904', 'registered_nurse');
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, services_provided, billable, status, planned_minutes_a)
values ('$ORG', '$VISIT', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        (now() at time zone 'Europe/Zurich' + interval '10 hours')::date,
        date_trunc('minute', (now() at time zone 'Europe/Zurich' + interval '10 hours'))::time, array['Grundpflege'], false, 'planned', 30);
SQL

accept() {  # $1 user, $2 idempotency key
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$1","role":"authenticated"}', true);
set local role authenticated;
select public.accept_cover('$VISIT', '$2');
-- hold the transaction a moment so the two acceptances overlap
select pg_sleep(0.3);
commit;
SQL
}
tmp=$(mktemp -d)
accept 00000000-0000-4000-a000-000000000901 ae000000-0000-4000-8000-000000000001 > "$tmp/a" &
accept 00000000-0000-4000-a000-000000000904 ae000000-0000-4000-8000-000000000002 > "$tmp/b" &
wait
results=$(cat "$tmp/a" "$tmp/b" | grep -E '^(ok|taken|rejected|disabled|duplicate)$' | sort | tr '\n' ' ')
accepted=$(psql "$DB_URL" -X -At -c "select count(*) from public.cover_events where visit_id = '$VISIT' and kind = 'accepted'")
echo "results: $results; accepted events: $accepted"
if [ "$results" = "ok taken " ] && [ "$accepted" = "1" ]; then
  echo "ok - two parallel acceptances: one wins, the other gets \"taken\""
else
  echo "not ok - expected one ok and one taken with one accepted event"; exit 1
fi
