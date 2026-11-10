-- B0-7 NEGATIVE PROBE (ADR-176): deliberately wrong. Lives only on a repeat/2/ probe branch; never merged.
-- Expected: pgTAP 123 red on B0-7-1, B0-7-2, B0-7-3, B0-7-6, B0-7-7; pgTAP 067 (RLS2-1 table catalogue) may go red as well, because Supabase grants a new table to authenticated.
create table public.b0_7_probe_no_rls (id int primary key);
grant select on public.b0_7_probe_no_rls to anon;
create function private.b0_7_probe_definer() returns int language sql security definer set search_path = public as $$ select 1 $$;
grant execute on function private.b0_7_probe_definer() to anon;
