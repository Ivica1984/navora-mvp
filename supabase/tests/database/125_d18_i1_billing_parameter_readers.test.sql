-- D-18 clinical invariant (I1) (`cra` template 2026-11-11 05:26 in docs/agents/decisions/D-18.md; Engineering input
-- requested by `po` 2026-11-11 05:39): planned minutes come only from the needs assessment and the care plan; no
-- planning, proposal, reminder or AI function reads a billing parameter (minimum, unit, rate).
-- Before this file (I1) was IMPLEMENTED by reading only. This catalogue check pins it for every later migration:
--   (1) the check finds the billing readers it guards (sanity: the pattern still matches the code);
--   (2) the set of functions in `public` and `private` whose body names `billing_rules`, `tariff_rates`,
--       `min_billable_minutes`, or calls `billing_rule(`, `tariff_rate(` or `billing_preview(` is exactly the J5 billing
--       functions and the AIG1 classification (which names the tables only to refuse them, ADR-141). A new reader fails
--       here and must be reviewed against (I1) before the expected set is changed; the set is never widened to get green;
--   (3) no view in `public` or `private` reads those tables.
-- Limits (named, not hidden): a reader through dynamic SQL built from fragments, or through a function outside
-- `public`/`private`, is not seen; app code is guarded by tests/unit/d18-i1-no-billing-in-planning.test.ts.
-- No data is written; nothing here touches a live project. Synthetic seed only.
begin;
create extension if not exists pgtap with schema extensions;

select plan(3);

create temporary table g125_readers on commit drop as
select distinct n.nspname || '.' || p.proname as fn
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  and (p.prosrc ~* '\m(billing_rules|tariff_rates|min_billable_minutes)\M'
       or p.prosrc ~* '\m(billing_rule|tariff_rate|billing_preview)\s*\(');

select ok((select count(*) from g125_readers) >= 5,
  'D-18 (I1): the catalogue check finds the J5 billing readers it guards');

select is(
  (select coalesce(string_agg(fn, ', ' order by fn), '') from g125_readers),
  'private.aig1_prohibited_target, private.billing_rule, private.build_billable_fact, private.min_billable_minutes, '
    || 'private.tariff_rate, public.billing_preview',
  'D-18 (I1): only the J5 billing functions (and the AIG1 refusal list) read billing_rules, tariff_rates or the minimum; '
    || 'no planning, proposal, reminder or AI function does');

select is(
  (select coalesce(string_agg(schemaname || '.' || viewname, ', ' order by viewname), '')
   from pg_views
   where schemaname in ('public', 'private')
     and definition ~* '\m(billing_rules|tariff_rates|min_billable_minutes)\M'),
  '',
  'D-18 (I1): no view reads billing_rules or tariff_rates');

select * from finish();
rollback;
