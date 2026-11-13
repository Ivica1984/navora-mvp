#!/usr/bin/env bash
# B1.1 CGR-203 (brief docs/agents/briefs/B1.1.md §PO 09:40 point 2; ADR-188): «Zuordnen» of a legacy region text racing
# the real conversion of a referral («Fall eröffnen», public.convert_partner_request) that carries the same text, in
# two real, parallel database sessions. region-map-race.sh (CGR-201) proves the lock on a raw service_role insert;
# this script runs the application's own conversion command as Operations, so the case insert, the readiness check and
# the team search (matching_requests) are the real ones.
#
# Orders (the first session starts at t=0, the second 0.7 s later; each holds its transaction open after its call):
#   map-first:      the mapping commits first; the conversion must wait and put case and team search on Basel-Stadt.
#   convert-first:  the conversion commits first; the mapping must wait and rewrite case and team search.
#   deadlock-map:   ADR-187 known residue. The conversion session locks its referral first (the same `for update` the
#                   function takes as its first lock), then calls the function 1.5 s later; meanwhile the mapping locks
#                   the legacy value and waits for the referral. PostgreSQL detects the deadlock (40P01). The mapping
#                   session detects it first (default deadlock_timeout), so the mapping is rolled back whole: the
#                   conversion succeeds on the old text and the value stays listed in «Region nicht zugeordnet».
#   deadlock-convert: as deadlock-map, but the mapping session raises its own deadlock_timeout to 10 s, so the
#                   conversion detects it and is rolled back whole: the referral stays open with no case, the user sees
#                   «Speichern fehlgeschlagen.» (unit b1-1-cgr203-failed-save), and the mapping completes.
# The two deadlock orders widen a window that, in the real function, lies between two statements of one call; the
# early lock is the function's own first lock, taken earlier in the same transaction, not a different lock.
#
# Invariant asserted in every order (PO 09:40 point 2): never a case, referral or team search on the old text after
# the mapping committed; never both commands failed; a failed command raised an error (no silent loss); a failed
# conversion leaves the referral open without a case; a failed mapping leaves the value unmapped and listed.
# Commits its own synthetic fixture rows (fixed ids, values «Wettlauf B203 …») and removes them again.
# Usage: DB_URL=... region-map-convert-race.sh
set -euo pipefail
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
ORG=00000000-0000-4000-b000-000000000011
OPS=00000000-0000-4000-a000-000000000904
psql_q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 "$@"; }
q() { psql "$DB_URL" -X -At -v ON_ERROR_STOP=1 -c "$1"; }

ORDERS="map-first convert-first deadlock-map deadlock-convert"
tag_of() { case "$1" in map-first) echo 0a;; convert-first) echo 0b;; deadlock-map) echo 0c;; deadlock-convert) echo 0d;; esac; }
# id suffixes: e0 = referral, f0 = key of the mapping, c0 = key of the conversion
id() { echo "b2030000-0000-4000-8000-00000000${1}${2}"; }

cleanup() {
  local refs="" keys=""
  for o in $ORDERS; do
    t=$(tag_of "$o")
    refs="$refs,'$(id "$t" e0)'"; keys="$keys,'$(id "$t" f0)','$(id "$t" c0)'"
  done
  refs=${refs#,}; keys=${keys#,}
  psql_q > /dev/null <<SQL
set session_replication_role = replica;
create function pg_temp.drop_tree(p_table regclass, p_ids uuid[], p_depth int default 0) returns void language plpgsql as \$\$
declare fk record; child uuid[];
begin
  -- Children first (FK checks are off under replica, so order only avoids orphans); depth 3 stops at FK cycles.
  if p_ids is null or cardinality(p_ids) = 0 or p_depth > 3 then return; end if;
  for fk in
    select c.conrelid::regclass as tbl, a.attname as col
    from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and c.confrelid = p_table and c.conrelid <> p_table
  loop
    if exists (select 1 from pg_attribute where attrelid = fk.tbl and attname = 'id' and atttypid = 'uuid'::regtype) then
      execute format('select array_agg(id) from %s where %I = any(\$1)', fk.tbl, fk.col) into child using p_ids;
      perform pg_temp.drop_tree(fk.tbl, child, p_depth + 1);
    end if;
    execute format('delete from %s where %I = any(\$1)', fk.tbl, fk.col) using p_ids;
  end loop;
  execute format('delete from %s where id = any(\$1)', p_table) using p_ids;
end \$\$;
create temp table b203_cases as select id from public.cases where source_partner_request_id in ($refs);
delete from public.audit_events
  where entity_id in (select id from b203_cases)
     or entity_id in (select id from public.matching_requests where case_id in (select id from b203_cases))
     or entity_id in ($refs)
     or idempotency_key in ($keys)
     or (table_name = 'region_legacy_values' and changed ->> 'from' like 'Wettlauf B203%');
select pg_temp.drop_tree('public.cases', (select array_agg(id) from b203_cases));
select pg_temp.drop_tree('public.partner_requests', array[$refs]::uuid[]);
delete from public.region_legacy_values where organization_id = '$ORG' and legacy_value like 'Wettlauf B203%';
SQL
}
trap cleanup EXIT
cleanup

claims() {
  cat <<SQL
select set_config('request.jwt.claims', '{"sub":"$OPS","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '$OPS', true);
set local role authenticated;
SQL
}

map_session() {  # $1 value, $2 key, $3 deadlock_timeout or empty
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
${3:+set local deadlock_timeout = '$3';}
$(claims)
select 'map=' || public.map_legacy_region('$ORG', '$1',
  (select id from public.regions where organization_id = '$ORG' and name = 'Basel-Stadt'), '$2');
select pg_sleep(2);
commit;
select 'map=committed';
SQL
}

# Blocking facts per 012/019 (synthetic): with them the case is ready and the server opens the team search.
FACTS="jsonb_build_object('residence_municipality', 'Teststadt', 'residence_canton', 'BS', 'insurer_name', 'Testkasse',
  'insurance_type', 'KVG', 'requested_start', (private.now() at time zone 'Europe/Zurich')::date + 2,
  'medical_order_status', 'requested', 'gp_named', true)"

convert_session() {  # $1 referral id, $2 key, $3 "early" = lock the referral first and wait 1.5 s
  local early=""
  if [ "$3" = early ]; then
    early="select 1 from public.partner_requests where id = '$1' for update; select pg_sleep(1.5);"
  fi
  psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL
begin;
$early
$(claims)
select 'convert=' || (r ->> 'result') || ' ready=' || coalesce(r ->> 'ready', '?')
  from (select public.convert_partner_request('$1', 'Klient', 'Wettlauf B203', true, $FACTS, '$2') as r) x;
select pg_sleep(2);
commit;
select 'convert=committed';
SQL
}

fail=0
passed=0; failed=0
check() {  # $1 condition result (t/f), $2 text
  if [ "$1" = t ]; then echo "ok - $order: $2"; passed=$((passed + 1))
  else echo "not ok - $order: $2"; fail=1; failed=$((failed + 1)); fi
}
for order in $ORDERS; do
  tag=$(tag_of "$order")
  value="Wettlauf B203 $order"
  ref=$(id "$tag" e0)
  # Fixture as table owner: a copy of org A's first open seed referral with a new id and the legacy text; the trigger
  # registers the value as an unmapped legacy value and keeps the text.
  psql_q -c "insert into public.partner_requests
    select (jsonb_populate_record(null::public.partner_requests, to_jsonb(p)
            || jsonb_build_object('id', '$ref', 'region', '$value', 'status', 'open', 'converted_case_id', null,
                                  'request_title', 'Wettlauf B203 $order'))).*
    from public.partner_requests p where p.organization_id = '$ORG' and p.status = 'open'
      and p.id::text not like 'b2030000-%' order by p.id limit 1;"
  registered=$(q "select count(*) from public.region_legacy_values
    where organization_id = '$ORG' and legacy_value = '$value' and region_id is null")
  tmp=$(mktemp -d)
  case "$order" in
    map-first)
      map_session "$value" "$(id $tag f0)" "" > "$tmp/m" 2>&1 &
      sleep 0.7
      convert_session "$ref" "$(id $tag c0)" "" > "$tmp/c" 2>&1 & ;;
    convert-first)
      convert_session "$ref" "$(id $tag c0)" "" > "$tmp/c" 2>&1 &
      sleep 0.7
      map_session "$value" "$(id $tag f0)" "" > "$tmp/m" 2>&1 & ;;
    deadlock-map)
      convert_session "$ref" "$(id $tag c0)" early > "$tmp/c" 2>&1 &
      sleep 0.7
      map_session "$value" "$(id $tag f0)" "" > "$tmp/m" 2>&1 & ;;
    deadlock-convert)
      convert_session "$ref" "$(id $tag c0)" early > "$tmp/c" 2>&1 &
      sleep 0.7
      map_session "$value" "$(id $tag f0)" 10s > "$tmp/m" 2>&1 & ;;
  esac
  wait || true
  m_ok=f; c_ok=f; m_dead=f; c_dead=f
  grep -qx 'map=committed' "$tmp/m" && grep -qx 'map=ok' "$tmp/m" && m_ok=t
  grep -qx 'convert=committed' "$tmp/c" && grep -qx 'convert=ok ready=true' "$tmp/c" && c_ok=t
  grep -q 'deadlock detected' "$tmp/m" && m_dead=t
  grep -q 'deadlock detected' "$tmp/c" && c_dead=t
  old_rows=$(q "select (select count(*) from public.cases where organization_id = '$ORG' and region = '$value')
    + (select count(*) from public.partner_requests where organization_id = '$ORG' and region = '$value')
    + (select count(*) from public.matching_requests where organization_id = '$ORG' and region = '$value')
    + (select count(*) from public.teams where organization_id = '$ORG' and region = '$value')")
  case_region=$(q "select coalesce((select region from public.cases where source_partner_request_id = '$ref'), '<none>')")
  search_region=$(q "select coalesce((select string_agg(m.region || '/' || m.status, ',') from public.matching_requests m
    join public.cases c on c.id = m.case_id where c.source_partner_request_id = '$ref'), '<none>')")
  ref_state=$(q "select status || '/' || region || '/' || coalesce(converted_case_id::text, 'no-case')
    from public.partner_requests where id = '$ref'")
  mapped=$(q "select coalesce((select r.name from public.region_legacy_values l join public.regions r on r.id = l.region_id
    where l.organization_id = '$ORG' and l.legacy_value = '$value'), '<unmapped>')")
  map_audit=$(q "select count(*) from public.audit_events where idempotency_key = '$(id $tag f0)'
    and table_name = 'region_legacy_values'")
  # «Region nicht zugeordnet» as Operations sees it (the security-definer listing checks the role itself).
  listed=$(psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 <<SQL | tail -1
begin;
$(claims)
select coalesce((select cases || '/' || open_searches from public.unmapped_regions('$ORG') where legacy_value = '$value'),
                'not-listed');
rollback;
SQL
)
  echo "$order: registered=$registered map_ok=$m_ok convert_ok=$c_ok map_deadlock=$m_dead convert_deadlock=$c_dead" \
       "mapped=$mapped map_audit=$map_audit old_rows=$old_rows case=$case_region search=$search_region" \
       "referral=$ref_state listed=$listed"

  # Invariant (every order)
  check "$([ "$registered" = 1 ] && echo t || echo f)" "the fixture referral registered the value as unmapped"
  check "$([ "$m_ok" = t ] || [ "$c_ok" = t ] && echo t || echo f)" "never both commands failed"
  check "$([ "$m_ok" = t ] || [ "$m_dead" = t ] && echo t || echo f)" "a failed mapping raised an error"
  check "$([ "$c_ok" = t ] || [ "$c_dead" = t ] && echo t || echo f)" "a failed conversion raised an error"
  if [ "$m_ok" = t ]; then
    check "$([ "$old_rows" = 0 ] && [ "$mapped" = Basel-Stadt ] && [ "$map_audit" = 1 ] && echo t || echo f)" \
      "mapping committed: no case, referral, team search or team left on the old text; one audit row"
  else
    check "$([ "$mapped" = '<unmapped>' ] && [ "$map_audit" = 0 ] && [ "$listed" != not-listed ] && echo t || echo f)" \
      "mapping failed: the value stays unmapped, unaudited and listed in «Region nicht zugeordnet»"
  fi
  if [ "$c_ok" = t ]; then
    if [ "$m_ok" = t ]; then want=Basel-Stadt; else want=$value; fi
    check "$([ "$case_region" = "$want" ] && [ "$search_region" = "$want/open" ] && echo t || echo f)" \
      "conversion committed: case and open team search on «$want»"
  else
    check "$(case "$ref_state" in open/*/no-case) echo t;; *) echo f;; esac)" \
      "conversion failed: the referral stays open without a case"
    check "$([ "$case_region" = '<none>' ] && echo t || echo f)" "conversion failed: no case row"
  fi
  # Expected outcome per order (deterministic by construction)
  case "$order" in
    map-first|convert-first)
      check "$([ "$m_ok" = t ] && [ "$c_ok" = t ] && [ "$case_region" = Basel-Stadt ] && echo t || echo f)" \
        "both commands succeed, case and team search on Basel-Stadt" ;;
    deadlock-map)
      check "$([ "$m_dead" = t ] && [ "$m_ok" = f ] && [ "$c_ok" = t ] && [ "$listed" = 1/1 ] && echo t || echo f)" \
        "deadlock: the mapping is rolled back, the case and its team search stay listed (1 case, 1 open search)" ;;
    deadlock-convert)
      check "$([ "$c_dead" = t ] && [ "$c_ok" = f ] && [ "$m_ok" = t ] && [ "$ref_state" = "open/Basel-Stadt/no-case" ] \
               && echo t || echo f)" \
        "deadlock: the conversion is rolled back, the referral is open on Basel-Stadt, the mapping completed" ;;
  esac
  if [ "$failed" -gt 0 ]; then
    echo "--- map session:"; cat "$tmp/m"; echo "--- convert session:"; cat "$tmp/c"
  fi
  rm -rf "$tmp"
done
echo "CGR-203 region-map-convert-race: $passed ok, $failed not ok (orders: $ORDERS)"
exit $fail
