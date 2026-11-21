-- B0-7 (PRODUCT_BLOCKS.md §4, ADR-176): database privileges. Repository and database hardening only: no product
-- behaviour, no care rule, no data, no column, no new grant. Every statement only TAKES AWAY a privilege or turns RLS on.
--
-- pgTAP 123 (catalogue test over all migrations) found on migrations 0001-0122 (IMPLEMENTED fact, local PostgreSQL 16
-- stand-in with the Supabase default privileges, ADR-176; CI is the authority):
--   (1) four private tables without RLS: audit_value_classes, order_open_end_episodes, signal_evaluations,
--       signal_scheduler_runs. No grant on them for any API role and no SECURITY INVOKER function or policy reads them;
--       they are read and written only by SECURITY DEFINER functions owned by the table owner, which RLS without FORCE
--       does not restrict. Turning RLS on therefore changes no current path; it closes the table to any future grant.
--   (2) anon held SELECT, UPDATE, USAGE on the public sequences: Supabase's default privileges grant every new sequence
--       to anon; 0003 revoked the default for tables only. anon has no table privilege, so it never needs a sequence.
--   (3) private.now(), private.at_zurich(timestamp), private.at_zurich(timestamptz), private.at_zurich_end(timestamp)
--       were granted to anon explicitly (0067). anon has no USAGE on private, so it could never call them; the grant is
--       removed. authenticated and service_role keep EXECUTE (column defaults and invoker functions use them).
--   (4) five SECURITY DEFINER functions in private kept the default PUBLIC EXECUTE: four trigger functions
--       (guard_visit_planning, plan_after_case_change, plan_after_item_change, remember_removed_slot) and
--       plan_visit_untouched(care_visits). A trigger fires regardless of EXECUTE; plan_visit_untouched is called only
--       from SECURITY DEFINER functions owned by its owner. authenticated, which has USAGE on private, can no longer
--       call them directly.
-- Idempotent: REVOKE and ENABLE ROW LEVEL SECURITY are no-ops on a second run.

-- (1) RLS on the four private tables (no policy: no API role has a grant; the owner's functions are unaffected).
--     Named one by one on purpose: anything else pgTAP 123 finds later is a red test for a person to decide, not a
--     silent change by this migration.
alter table private.audit_value_classes     enable row level security;
alter table private.order_open_end_episodes enable row level security;
alter table private.signal_evaluations      enable row level security;
alter table private.signal_scheduler_runs   enable row level security;

-- (2) No anon privilege on any sequence in public, now or for sequences created later.
revoke all on all sequences in schema public from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;

-- (3) No anon EXECUTE on the clock and time-zone functions.
revoke execute on function private.now() from anon;
revoke execute on function private.at_zurich(timestamp) from anon;
revoke execute on function private.at_zurich(timestamptz) from anon;
revoke execute on function private.at_zurich_end(timestamp) from anon;

-- (4) No PUBLIC EXECUTE on the five SECURITY DEFINER functions named above (named one by one, as in (1)).
revoke execute on function private.guard_visit_planning() from public;
revoke execute on function private.plan_after_case_change() from public;
revoke execute on function private.plan_after_item_change() from public;
revoke execute on function private.remember_removed_slot() from public;
revoke execute on function private.plan_visit_untouched(public.care_visits) from public;
