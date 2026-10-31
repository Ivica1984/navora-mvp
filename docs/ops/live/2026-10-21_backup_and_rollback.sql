-- NAVORA live project jwmfxrmougneeceldhsa — containment C-1, 2026-10-21
-- BACKUP: state captured BEFORE containment (pg_policies + role_table_grants, 2026-10-21 ~16:05 CEST).
-- Data is NOT touched by the containment; only policies and grants change. Row counts before:
-- cases 6, care_visits 3, teams 3, care_notes 3, orders 10, partner_requests 2,
-- matching_requests 4, match_candidates 12, quality_events 3, team_locations 0.
--
-- Policies before (all roles {public}):
--   care_visits  "Enable insert access for all users"  INSERT  with_check true
--   care_visits  "Enable read access for all users"    SELECT  using true
--   care_visits  "Enable update access for all users"  UPDATE  using true  with_check true
--   cases        "Enable insert access for all users"  INSERT  with_check true
--   cases        "Enable read access for all users"    SELECT  using true
--   cases        "Enable update access for all users"  UPDATE  using true  with_check true
--   teams        "Enable read access for all users"    SELECT  using true
--   teams        "Enable update access for all users"  UPDATE  using true  with_check true
--   orders       "service-role read"  / "service-role write"  (auth.role()='service_role') -- kept
-- Grants before: anon AND authenticated held SELECT, INSERT, UPDATE, DELETE, TRUNCATE,
--   REFERENCES, TRIGGER on all 10 public tables.
--
-- ROLLBACK (restores the exact previous exposure — only on explicit owner instruction):
/*
begin;
grant select, insert, update, delete, truncate, references, trigger
  on all tables in schema public to anon, authenticated;
alter default privileges in schema public grant all on tables to anon;
create policy "Enable insert access for all users" on public.care_visits for insert to public with check (true);
create policy "Enable read access for all users"   on public.care_visits for select to public using (true);
create policy "Enable update access for all users" on public.care_visits for update to public using (true) with check (true);
create policy "Enable insert access for all users" on public.cases for insert to public with check (true);
create policy "Enable read access for all users"   on public.cases for select to public using (true);
create policy "Enable update access for all users" on public.cases for update to public using (true) with check (true);
create policy "Enable read access for all users"   on public.teams for select to public using (true);
create policy "Enable update access for all users" on public.teams for update to public using (true) with check (true);
commit;
*/
