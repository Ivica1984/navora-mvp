-- RLS4 (ADR-122): who did an act is read per record, never listed per person; who is responsible stays visible.
-- Amended before merge by RLS4-5 and RLS4-6 (brief, po 2026-10-30 03:10): 26 columns on 19 tables.
-- PO brief docs/agents/briefs/RLS4.md (approved 2026-10-29 23:15, the OBS1-7 (c) inventory decided). Access narrowing
-- only: no clinical, legal or tariff rule; no row read is widened or narrowed (RLS unchanged).
--
-- Before (IMPLEMENTED, read in a database built from 0001-0098, `READ_PATHS.md` *Remaining person-linked column grants*):
--   * `authenticated` holds a table-wide select on 14 of the 18 care-record tables below and column grants on four
--     (`visit_reports`, `case_gp_notices`, `cases`, `safety_signals`) that include the act columns. A member of the
--     record's team (or the row scope of each table's policy) can select who decided, wrote, changed, completed, set,
--     lifted, returned, countersigned, withdrew, created, recorded, confirmed or took, row by row through the Data API,
--     and filter or count it per person (D-23 term b).
--   * Every function that reads one of these 22 columns is SECURITY DEFINER and reads the table as its owner (ADR-122
--     names them). The only INVOKER functions mentioning such a column are the trigger guards
--     `private.guard_visit_report`, `private.guard_quality_hold`, `private.guard_safety_signal`, which compare NEW and
--     OLD and select nothing. No view reads them; no RLS policy of another table reads them. The app reads
--     `quality_holds` (id, visit_id, reason, set_at), `case_gp_notices` (case_id, informed_on, channel, recorded_at),
--     `care_visits` (no person column) and `cases` (CASE_SUMMARY_COLUMNS) directly, none of them an act column.
--   * `authenticated` has only select on these tables (all writes go through SECURITY DEFINER commands).
-- Now (IMPLEMENTED in this migration):
--   RLS4-1, the RLS3-4 pattern of 0070 and 0096: on each table `authenticated` loses the table-wide select and the
--   act columns, and keeps a column grant on exactly the other columns it could select before (a column the table did
--   not grant before stays closed: nothing is widened). `anon` keeps nothing on these tables.
--   RLS4-5 (po 2026-10-30 03:10 after `lca` 02:45): `cover_events.nurse_id` (who accepted or handed back a cover, next
--   to her reason), `visit_reports.performer_id` and `visit_report_returns.performer_id` close the same way. Each has
--   only SECURITY DEFINER readers (`accept_cover`, `withdraw_cover`, `pilot_kpis`; the F6R/J5 report readers and
--   commands); the policy of `visit_report_returns` reads its own `performer_id`, which needs no column grant.
--   RLS4-6: `care_visits.team_member_name` (legacy free-text nurse name) is no longer selectable; /visits shows the
--   responsible member from `responsible_user_id` instead. The column is not dropped (D-1 live reconciliation first).
--   RLS4-2 assignment columns are not touched: `cases.primary_nurse_id`, `deputy_nurse_id`; `care_visits.
--   responsible_user_id`, `covered_by`; `quality_events.owner_id`.
-- Idempotent: the column list is read from the current privileges each run, so a second run grants the same list.
-- A column added to one of these tables later is not selectable until a migration grants it (as `visit_events` since
-- 0070).

do $$
declare
  acts constant jsonb := jsonb_build_object(
    'visit_reports',         jsonb_build_array('created_by', 'countersigned_by', 'withdrawn_by', 'performer_id'),
    'visit_report_returns',  jsonb_build_array('returned_by', 'performer_id'),
    'care_visits',           jsonb_build_array('suspended_by', 'team_member_name'),
    'cover_events',          jsonb_build_array('nurse_id'),
    'visit_plan_changes',    jsonb_build_array('actor_id'),
    'visit_status_notes',    jsonb_build_array('actor_id'),
    'working_time_facts',    jsonb_build_array('performer_id'),
    'care_plan_items',       jsonb_build_array('created_by', 'retired_by'),
    'case_tasks',            jsonb_build_array('done_by'),
    'case_lifecycle_events', jsonb_build_array('actor_id'),
    'case_gp_notices',       jsonb_build_array('recorded_by'),
    'cases',                 jsonb_build_array('intake_consent_confirmed_by'),
    'team_decisions',        jsonb_build_array('actor_id'),
    'quality_events',        jsonb_build_array('author_id'),
    'quality_event_log',     jsonb_build_array('actor_id'),
    'quality_holds',         jsonb_build_array('set_by', 'lifted_by'),
    'billable_facts',        jsonb_build_array('created_by'),
    'safety_signals',        jsonb_build_array('taken_by'),
    'referral_links',        jsonb_build_array('actor_id'));
  t    text;
  hide text[];
  keep text;
  c    text;
begin
  for t in select jsonb_object_keys(acts) loop
    hide := array(select jsonb_array_elements_text(acts -> t));
    -- every hidden column must exist, or the list is out of date and the migration stops
    if (select count(*) from information_schema.columns
        where table_schema = 'public' and table_name = t and column_name = any (hide)) <> cardinality(hide) then
      raise exception 'RLS4: % lacks one of %', t, hide;
    end if;
    -- the columns `authenticated` can select now, minus the act columns (never more than before)
    select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into keep
    from information_schema.columns
    where table_schema = 'public' and table_name = t and column_name <> all (hide)
      and has_column_privilege('authenticated', format('public.%I', t), column_name, 'select');
    execute format('revoke select on public.%I from authenticated', t);
    foreach c in array hide loop
      execute format('revoke select (%I) on public.%I from authenticated', c, t);
    end loop;
    if keep is not null then
      execute format('grant select (%s) on public.%I to authenticated', keep, t);
    end if;
    execute format('revoke all on public.%I from anon', t);
  end loop;
end
$$;

comment on column public.quality_events.author_id is
  'RLS4-1 (ADR-122): who reported the event. Not selectable through the table API; read per record ("gemeldet von") '
  'through field_quality (per visit day, team) and private.handover_entries.';
comment on column public.working_time_facts.performer_id is
  'RLS4-1 (ADR-122): whose working time the fact is. Not selectable through the table API; no screen reads this '
  'table (her working day is read through WORK1 my_working_day); billing reads it as owner (build_billable_fact).';
comment on column public.care_visits.team_member_name is
  'RLS4-6 (ADR-122): legacy free-text nurse name. Not selectable through the table API, not read or written by the app '
  '(/visits shows the responsible member from responsible_user_id). Kept until the D-1 live reconciliation.';
comment on column public.cover_events.nurse_id is
  'RLS4-5 (ADR-122): who accepted or handed back the cover. Not selectable through the table API; who covers now is '
  'care_visits.covered_by. Read as owner by accept_cover, withdraw_cover and pilot_kpis (team aggregate).';
