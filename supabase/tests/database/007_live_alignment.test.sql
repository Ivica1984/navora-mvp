-- TD-19 / ADR-022: columns aligned with the verified live schema.
begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

select col_not_null('public', 'match_candidates', 'fit_score', 'match_candidates.fit_score is NOT NULL (as in live)');
select col_not_null('public', 'match_candidates', 'status', 'match_candidates.status is NOT NULL (as in live)');
-- Deliberate deviations from live stay in place (drift report §2):
select col_default_is('public', 'care_visits', 'billable', 'false', 'care_visits.billable defaults to false (live: true; repo is safer)');
select col_default_is('public', 'care_visits', 'status', 'planned', 'care_visits.status defaults to planned (live: geplant, outside the value set)');

select * from finish();
rollback;
