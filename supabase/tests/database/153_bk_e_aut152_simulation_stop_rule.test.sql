-- BK-e contract point 2, migration 0153: pins the AUT-152 stop-rule row exactly as `cra` gave it on 2026-11-19 21:45
-- (comment 7021790626): a simulation test parameter, not a clinical threshold.
--
-- What it guards:
--   * exactly one stop-rule row exists, for `report_draft_model` only;
--   * its values are exactly share 50.00, minimum 10 decided lines, window 30 days, and the `cra` reference text;
--   * the table still has RLS on and no read or write grant for app roles (0151 unchanged);
--   * the gate's refusals with a row present (non-simulation organisation, other team, not the performer, signed
--     report) stay in pgTAP 151 §2, which now runs against this shipped row.
-- All data synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;

select plan(7);

select is((select count(*)::int from public.report_draft_stop_rules), 1,
  'AUT-152: exactly one stop-rule row is shipped');
select is((select agent_key from public.report_draft_stop_rules), 'report_draft_model',
  'the row belongs to the report-draft model agent');
select is((select stop_share from public.report_draft_stop_rules where agent_key = 'report_draft_model'), 50.00::numeric(5, 2),
  'cra 21:45: stop_share 50.00');
select is((select stop_min_decided from public.report_draft_stop_rules where agent_key = 'report_draft_model'), 10,
  'cra 21:45: stop_min_decided 10');
select is((select stop_window_days from public.report_draft_stop_rules where agent_key = 'report_draft_model'), 30,
  'cra 21:45: stop_window_days 30');
select is((select cra_ref from public.report_draft_stop_rules where agent_key = 'report_draft_model'),
  'cra 2026-11-19 21:45 simulation test parameter (seed.sql:477), not a clinical threshold',
  'cra_ref names the gate and marks the value as a simulation test parameter, not a clinical threshold');
select ok((select relrowsecurity from pg_class where oid = 'public.report_draft_stop_rules'::regclass)
          and not has_table_privilege('authenticated', 'public.report_draft_stop_rules', 'select')
          and not has_table_privilege('authenticated', 'public.report_draft_stop_rules', 'insert')
          and not has_table_privilege('authenticated', 'public.report_draft_stop_rules', 'update')
          and not has_table_privilege('authenticated', 'public.report_draft_stop_rules', 'delete')
          and not has_table_privilege('anon', 'public.report_draft_stop_rules', 'select'),
  'the stop-rule table keeps RLS on and no grant for app roles');

select * from finish();
rollback;
