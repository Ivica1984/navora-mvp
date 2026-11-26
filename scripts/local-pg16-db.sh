#!/usr/bin/env bash
# Local database for `eng` sessions whose proxy blocks the Supabase Docker images (HD-3s-F2, `eng` 2026-11-27).
# Developer tool only: CI (`db` job, Supabase CLI) stays the test environment of record; a local pass never replaces it.
#
# It starts a plain PostgreSQL 16 (Ubuntu package), adds a minimal Supabase shim (roles anon/authenticated/service_role,
# schema auth with uid()/role()/jwt(), auth.users/auth.identities, default privileges as on Supabase, pgcrypto, btree_gist,
# pgTAP from source), applies every migration in order (each in one transaction), then supabase/seed.sql (synthetic).
# Checked on 2026-11-27: 180 migrations apply, `node scripts/fn-source.mjs check` reports «78 definitions in 77 files match
# the database», pgTAP 182 67/67.
#
#   scripts/local-pg16-db.sh start          initdb + start on port 54399 (socket /var/tmp/pgx), install pgTAP if missing
#   scripts/local-pg16-db.sh rebuild        drop + create database nav, shim, all migrations, seed
#   scripts/local-pg16-db.sh test [files]   run pgTAP files (default: all) and print failures; output in /var/tmp/pgx/tap
#   FN_DB_URL="postgresql://postgres@/nav?host=/var/tmp/pgx&port=54399" node scripts/fn-source.mjs check|dump
#
# Known local differences (not product facts): pgTAP 164 and 178 read call counters (track_functions = all is set by
# `start`) and CI timing; judge them in CI only. Synthetic seed only; never point this at staging or production.
set -euo pipefail
cd "$(dirname "$0")/.."
BIN=/usr/lib/postgresql/16/bin
ROOT=/var/tmp/pgx
PORT=54399
P0=(psql -h "$ROOT" -p "$PORT" -U postgres -X -q -v ON_ERROR_STOP=1)

shim() {
  cat <<'EOF'
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    create role authenticator login noinherit; create role supabase_admin superuser; create role dashboard_user;
  end if;
end $$;
grant anon, authenticated, service_role to authenticator;
create schema auth; create schema extensions; create schema storage;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;
create table auth.users (id uuid primary key default gen_random_uuid(), email text, raw_user_meta_data jsonb,
  raw_app_meta_data jsonb, created_at timestamptz default now(), encrypted_password text, email_confirmed_at timestamptz,
  aud text, role text, instance_id uuid, updated_at timestamptz, confirmation_token text, recovery_token text,
  email_change_token_new text, email_change text, last_sign_in_at timestamptz, is_sso_user boolean default false,
  deleted_at timestamptz, phone text);
create table auth.identities (id uuid primary key, user_id uuid references auth.users (id) on delete cascade,
  provider_id text, identity_data jsonb, provider text, last_sign_in_at timestamptz, created_at timestamptz,
  updated_at timestamptz, email text);
create or replace function auth.uid() returns uuid language sql stable as $f$
  select nullif(coalesce(current_setting('request.jwt.claim.sub', true),
                         (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')), '')::uuid $f$;
create or replace function auth.role() returns text language sql stable as $f$
  select coalesce(current_setting('request.jwt.claim.role', true),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')) $f$;
create or replace function auth.jwt() returns jsonb language sql stable as $f$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}') $f$;
grant usage on schema auth, extensions, public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter database nav set search_path = "$user", public, extensions;
create extension if not exists pgtap with schema extensions;
EOF
}

case "${1:-}" in
  start)
    mkdir -p "$ROOT" && chown postgres "$ROOT"
    if [ ! -f /usr/share/postgresql/16/extension/pgtap.control ]; then
      tmp=$(mktemp -d) && git clone -q --depth 1 https://github.com/theory/pgtap.git "$tmp/pgtap"
      v=$(sed -n "s/^default_version = '\(.*\)'/\1/p" "$tmp/pgtap/pgtap.control")
      sed -e 's,MODULE_PATHNAME,$libdir/pgtap,g' -e 's/__OS__/linux/g' -e "s/__VERSION__/${v%.*}/g" \
        "$tmp/pgtap/sql/pgtap.sql.in" > "/usr/share/postgresql/16/extension/pgtap--$v.sql"
      grep -v module_pathname "$tmp/pgtap/pgtap.control" > /usr/share/postgresql/16/extension/pgtap.control
    fi
    [ -d "$ROOT/data" ] || su postgres -s /bin/bash -c "$BIN/initdb -D $ROOT/data -U postgres -A trust >/dev/null"
    su postgres -s /bin/bash -c "$BIN/pg_ctl -D $ROOT/data -o '-p $PORT -k $ROOT' -l $ROOT/log -w start"
    "${P0[@]}" -c "alter system set track_functions = 'all'" -c "select pg_reload_conf()" >/dev/null ;;
  rebuild)
    "${P0[@]}" -c "drop database if exists nav" -c "create database nav" >/dev/null
    shim | "${P0[@]}" -d nav >/dev/null 2>&1
    n=0
    for f in supabase/migrations/*.sql; do
      "${P0[@]}" -d nav -1 -f "$f" > "$ROOT/mig.out" 2>&1 || { echo "FAIL $f"; grep -A4 ERROR "$ROOT/mig.out" | head; exit 1; }
      n=$((n + 1))
    done
    "${P0[@]}" -d nav -f supabase/seed.sql > "$ROOT/seed.out" 2>&1 || { echo "SEED FAIL"; grep -A4 ERROR "$ROOT/seed.out" | head; exit 1; }
    echo "local-pg16-db: $n migrations and the seed applied" ;;
  test)
    shift; out="$ROOT/tap"; mkdir -p "$out"; pass=0; fail=0
    files=("$@"); [ ${#files[@]} -gt 0 ] || files=(supabase/tests/database/*.test.sql)
    for t in "${files[@]}"; do
      b=$(basename "$t" .test.sql)
      timeout 600 psql -h "$ROOT" -p "$PORT" -U postgres -X -At -d nav -f "$t" > "$out/$b.out" 2>&1 || true
      plan=$(grep -m1 -o '^1\.\.[0-9]*' "$out/$b.out" | cut -d. -f3 || true)
      ok=$(grep -c '^ok' "$out/$b.out" || true); nok=$(grep -c '^not ok' "$out/$b.out" || true)
      err=$(grep -c 'ERROR' "$out/$b.out" || true)
      if [ "$nok" = 0 ] && [ "$err" = 0 ] && [ -n "$plan" ] && [ "$ok" = "$plan" ]; then pass=$((pass + 1))
      else fail=$((fail + 1)); echo "FAIL $b plan=${plan:-none} ok=$ok not_ok=$nok errors=$err"; fi
    done
    echo "local-pg16-db: $pass files passed, $fail failed (output in $out)"
    [ "$fail" = 0 ] ;;
  *) echo "usage: $0 start | rebuild | test [files...]" >&2; exit 2 ;;
esac
