#!/usr/bin/env bash
# B1.1-1b CGR-201 (ADR-187; PO 06:39 point 3): «Zuordnen» of a legacy region text racing a new case that carries the
# same text, in two real, parallel database sessions, in both orders. pgTAP runs inside one transaction and cannot open
# a second session, so this uses two psql processes (as cover-accept.sh). Probe:
# docs/engineering/probes/CGR-201_MAPPING_RACE.md (on migration 0127 alone both orders leave the case on the old text).
#
# Each order: the first session holds its transaction open 2 s after its statement; the second starts 0.7 s later.
#   map first:    Operations (…904, authenticated) runs map_legacy_region; the insert must wait and take the list name.
#   insert first: a service_role insert of a case runs the trigger; the mapping must wait and its rewrite see the case.
# Expected in both orders: the mapping returns ok and the raced case carries Basel-Stadt (never the old text).
# Commits its own synthetic fixture rows (fixed ids, values «Wettlauf B128 …») and removes them again.
# Usage: DB_URL=... region-map-race.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
ORG=00000000-0000-4000-b000-000000000011
OPS=00000000-0000-4000-a000-000000000904
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }

# id suffixes: f = fixture case (registers the value), c = raced case, k = idempotency key of the mapping
id() { echo "b1280000-0000-4000-8000-00000000${1}${2}"; }

cleanup() {
  psql_q <<SQL
set session_replication_role = replica;
delete from public.audit_events
  where entity_id in ('$(id 0a f0)', '$(id 0a c0)', '$(id 0b f0)', '$(id 0b c0)')
     or idempotency_key in ('$(id 0a 00)', '$(id 0b 00)')
     or (table_name = 'region_legacy_values' and changed ->> 'from' like 'Wettlauf B128%');
delete from public.cases where id in ('$(id 0a f0)', '$(id 0a c0)', '$(id 0b f0)', '$(id 0b c0)');
delete from public.region_legacy_values where organization_id = '$ORG' and legacy_value like 'Wettlauf B128%';
SQL
}
trap cleanup EXIT
cleanup

copy_case() {  # $1 new id, $2 region: a copy of org A's first seed case with a new id and region
  cat <<SQL
insert into public.cases
  select (jsonb_populate_record(null::public.cases, to_jsonb(c)
          || jsonb_build_object('id', '$1', 'region', '$2', 'source_partner_request_id', null, 'access_notes', null))).*
  from public.cases c where c.organization_id = '$ORG' and c.id::text not like 'b1280000-%' order by c.id limit 1;
SQL
}

map_session() {  # $1 value, $2 key
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
select set_config('request.jwt.claims', '{"sub":"$OPS","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '$OPS', true);
set local role authenticated;
select 'map=' || public.map_legacy_region('$ORG', '$1',
  (select id from public.regions where organization_id = '$ORG' and name = 'Basel-Stadt'), '$2');
select pg_sleep(2);
commit;
SQL
}

insert_session() {  # $1 case id, $2 value
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
set local role service_role;
$(copy_case "$1" "$2")
select pg_sleep(2);
commit;
select 'insert=done';
SQL
}

fail=0
for order in map-first insert-first; do
  if [ "$order" = map-first ]; then tag=0a; else tag=0b; fi
  value="Wettlauf B128 $order"
  # Fixture as table owner: the trigger registers the value as an unmapped legacy value and keeps the text.
  psql_q -c "$(copy_case "$(id $tag f0)" "$value")"
  registered=$(psql "$DB_URL" -X -At -c "select count(*) from public.region_legacy_values
    where organization_id = '$ORG' and legacy_value = '$value' and region_id is null")
  tmp=$(mktemp -d)
  if [ "$order" = map-first ]; then
    map_session "$value" "$(id $tag 00)" > "$tmp/m" 2>&1 &
    sleep 0.7
    insert_session "$(id $tag c0)" "$value" > "$tmp/i" 2>&1 &
  else
    insert_session "$(id $tag c0)" "$value" > "$tmp/i" 2>&1 &
    sleep 0.7
    map_session "$value" "$(id $tag 00)" > "$tmp/m" 2>&1 &
  fi
  wait
  m=$(grep -E '^map=' "$tmp/m" || true)
  i=$(grep -E '^insert=' "$tmp/i" || true)
  raced=$(psql "$DB_URL" -X -At -c "select coalesce((select region from public.cases where id = '$(id $tag c0)'), '<missing>')")
  fixture=$(psql "$DB_URL" -X -At -c "select region from public.cases where id = '$(id $tag f0)'")
  echo "$order: registered=$registered, $m, $i, raced case region=$raced, fixture case region=$fixture"
  if [ "$registered" = "1" ] && [ "$m" = "map=ok" ] && [ "$i" = "insert=done" ] \
     && [ "$raced" = "Basel-Stadt" ] && [ "$fixture" = "Basel-Stadt" ]; then
    echo "ok - $order: the raced case carries Basel-Stadt, not the old text (CGR-201)"
  else
    echo "not ok - $order: expected map=ok, insert=done and Basel-Stadt on both cases"
    echo "--- map session:"; cat "$tmp/m"; echo "--- insert session:"; cat "$tmp/i"
    fail=1
  fi
done
exit $fail
