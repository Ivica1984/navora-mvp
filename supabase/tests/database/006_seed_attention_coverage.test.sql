-- T13: the synthetic seed exercises every Operations attention branch.
--
-- Source of truth for the rules: src/features/operations/rules.ts (IMPLEMENTED, legacy thresholds,
-- NOT clinically validated). This file mirrors those conditions in SQL only to prove the SEED covers
-- them, so a seed edit cannot silently remove a scenario the UI and e2e tests rely on.
-- If rules.ts changes, update the matching assertion here in the same PR.
--
-- Scope: organisation A (…b000…011), the organisation Operations users see.
-- Runs as the test superuser (RLS bypassed): it checks seed content, not access control (see 004).
-- Known gap: the "completed visit with a SUBMITTED note" branch is covered by
-- tests/unit/operations-rules.test.ts only; adding it to the seed would change the visit counts in 004.
begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

create temp view org_a_cases as
  select *, floor(extract(epoch from (private.now() - created_at)) / 3600)::int as hours_open
  from public.cases where organization_id = '00000000-0000-4000-b000-000000000011';
create temp view org_a_teams as
  select * from public.teams where organization_id = '00000000-0000-4000-b000-000000000011';
create temp view org_a_partner as
  select *, floor(extract(epoch from (private.now() - created_at)) / 3600)::int as hours_open
  from public.partner_requests where organization_id = '00000000-0000-4000-b000-000000000011';

-- ── capacity (teams) ───────────────────────────────────────────────────────────
select ok(exists (select 1 from org_a_teams where coalesce(utilization, 0) >= 90),
  'capacity P1: a team with utilization >= 90');
select ok(exists (select 1 from org_a_teams where coalesce(utilization, 0) between 80 and 89),
  'capacity P2: a team with 80 <= utilization < 90');
select ok(exists (select 1 from org_a_teams where coalesce(utilization, 0) < 80 and coalesce(open_slots, 0) <= 1),
  'capacity P2: a team below 80 % but with open_slots <= 1');
select ok(exists (select 1 from org_a_teams where coalesce(utilization, 0) < 80 and coalesce(open_slots, 0) > 1),
  'capacity negative: a team that raises no attention');

-- ── case without team ──────────────────────────────────────────────────────────
select ok(exists (select 1 from org_a_cases where assigned_team_id is null and status <> 'laufend'
                  and urgency = 'hoch' and hours_open < 24),
  'case-without-team P1 via urgency hoch (fresh)');
select ok(exists (select 1 from org_a_cases where assigned_team_id is null and status <> 'laufend'
                  and urgency <> 'hoch' and hours_open >= 24),
  'case-without-team P1 via age >= 24 h (not urgent)');
select ok(exists (select 1 from org_a_cases where assigned_team_id is null and status <> 'laufend'
                  and urgency <> 'hoch' and hours_open < 24),
  'case-without-team P2 (fresh, not urgent)');
select ok(exists (select 1 from org_a_cases where assigned_team_id is null and status <> 'laufend'
                  and hours_open >= 48),
  'case-without-team older than 48 h (SLA-violated scenario)');

-- ── team decision (teampruefung) ───────────────────────────────────────────────
select ok(exists (select 1 from org_a_cases where status = 'teampruefung' and hours_open >= 24),
  'team-decision P1 (>= 24 h)');
select ok(exists (select 1 from org_a_cases where status = 'teampruefung' and hours_open < 24
                  and assigned_team_id is not null),
  'team-decision P2 (fresh, team assigned)');
select ok(exists (select 1 from org_a_cases where status = 'teampruefung' and assigned_team_id is null),
  'TD-09 duplicate pair: teampruefung without team (raises two items today)');
select ok(exists (select 1 from org_a_cases where status = 'laufend'),
  'case negative: running cases raise no attention');

-- ── partner requests ───────────────────────────────────────────────────────────
select ok(exists (select 1 from org_a_partner where status in ('open', 'ready_to_convert')
                  and urgency = 'hoch' and hours_open < 24),
  'partner P1 via urgency hoch');
select ok(exists (select 1 from org_a_partner where status in ('open', 'ready_to_convert')
                  and urgency <> 'hoch' and hours_open >= 24),
  'partner P1 via age >= 24 h');
select ok(exists (select 1 from org_a_partner where status in ('open', 'ready_to_convert')
                  and urgency <> 'hoch' and hours_open < 24),
  'partner P2 (fresh, not urgent)');
select ok(exists (select 1 from org_a_partner where status = 'ready_to_convert'),
  'partner: ready_to_convert status is represented');
select ok(exists (select 1 from org_a_partner where status not in ('open', 'ready_to_convert')),
  'partner negative: a converted request raises no attention');

-- ── completed visits and reports ───────────────────────────────────────────────
select ok(exists (
    select 1 from public.care_visits v
    where v.organization_id = '00000000-0000-4000-b000-000000000011' and v.status = 'completed'
      and not exists (select 1 from public.care_notes n where n.visit_id = v.id)),
  'visit-report P2: completed visit without a note');
select ok(exists (
    select 1 from public.care_visits v join public.care_notes n on n.visit_id = v.id
    where v.organization_id = '00000000-0000-4000-b000-000000000011' and v.status = 'completed'
      and n.status = 'draft'),
  'visit-report P2: completed visit with a draft note');
select ok(exists (
    select 1 from public.care_visits v join public.care_notes n on n.visit_id = v.id
    where v.organization_id = '00000000-0000-4000-b000-000000000011' and v.status = 'completed'
      and n.status = 'approved'),
  'visit-report negative: completed visit with an approved note');

-- ── quality events ─────────────────────────────────────────────────────────────
select ok(exists (select 1 from public.quality_events where organization_id = '00000000-0000-4000-b000-000000000011'
                  and status = 'open' and severity in ('critical', 'high')),
  'quality P1: open event with severity high/critical');
select ok(exists (select 1 from public.quality_events where organization_id = '00000000-0000-4000-b000-000000000011'
                  and status = 'open' and severity not in ('critical', 'high')),
  'quality P2: open event with lower severity');

select * from finish();
rollback;
