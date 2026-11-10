-- B0-1 negative case PROBE (ADR-178). Deliberately red. Lives only on the probe branch
-- `probe/b0-1-negative-20261110`; never reaches recovery/main (the probe PR is closed unmerged). No data.
begin;
create extension if not exists pgtap with schema extensions;
select plan(1);
select ok(false, 'B0-1 probe: deliberately red, the merge-commit run must report red');
select * from finish();
rollback;
