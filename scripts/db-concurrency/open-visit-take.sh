#!/usr/bin/env bash
# ABS1 (migration 0046): two team members take the same open visit in two real, parallel database sessions —
# exactly one may become responsible, the other gets "already_taken". pgTAP runs inside one transaction and
# cannot open a second session, so this check uses two psql processes (as cover-accept.sh).
# Commits its own synthetic fixture rows (fixed ids) and removes them again. Usage: DB_URL=... open-visit-take.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
VISIT=a0460000-0000-4000-8000-0000000000aa
ORG=00000000-0000-4000-b000-000000000011
K1=a0460000-0000-4000-8000-0000000000a1
K2=a0460000-0000-4000-8000-0000000000a2
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }

cleanup() {
  psql_q <<SQL
set session_replication_role = replica;
delete from public.visit_plan_changes where visit_id = '$VISIT';
delete from public.audit_events where entity_id = '$VISIT' or idempotency_key in ('$K1', '$K2');
delete from public.care_visits where id = '$VISIT';
SQL
}
trap cleanup EXIT
cleanup

# Both Testteam Nord members (…902 registered nurse, …906 care assistant) may take a category A visit.
psql_q <<SQL
insert into public.care_visits (organization_id, id, case_id, team_id, visit_date, time_start, services_provided, billable, status, planned_minutes_a)
values ('$ORG', '$VISIT', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000101',
        ((now() + interval '10 hours') at time zone 'Europe/Zurich')::date,
        date_trunc('minute', ((now() + interval '10 hours') at time zone 'Europe/Zurich'))::time, array['Grundpflege'], false, 'planned', 30);
SQL

take() {  # $1 user, $2 idempotency key
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$1","role":"authenticated"}', true);
set local role authenticated;
select public.take_open_visit('$VISIT', '$2') ->> 'result';
-- hold the transaction a moment so the two takes overlap
select pg_sleep(0.3);
commit;
SQL
}
tmp=$(mktemp -d)
take 00000000-0000-4000-a000-000000000902 "$K1" > "$tmp/a" &
take 00000000-0000-4000-a000-000000000906 "$K2" > "$tmp/b" &
wait
results=$(cat "$tmp/a" "$tmp/b" | grep -E '^(ok|already_taken|rejected|not_open|duplicate|not_qualified|absent)$' | sort | tr '\n' ' ')
taken=$(psql "$DB_URL" -X -At -c "select count(*) from public.visit_plan_changes where visit_id = '$VISIT' and change = 'taken'")
resp=$(psql "$DB_URL" -X -At -c "select count(*) from public.care_visits where id = '$VISIT' and responsible_user_id is not null")
echo "results: $results; taken rows: $taken; responsible set: $resp"
if [ "$results" = "already_taken ok " ] && [ "$taken" = "1" ] && [ "$resp" = "1" ]; then
  echo "ok - two parallel takes: one wins, the other gets \"already_taken\""
else
  echo "not ok - expected one ok and one already_taken with one take logged"; exit 1
fi
