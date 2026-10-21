# NAVORA — Technical Debt Register

**Last updated:** 2026-10-21 · Scope: `recovery/main`. Security-relevant debt lives in `SECURITY_RISKS.md`.
**Cost:** S (< ½ day) · M (½–2 days) · L (> 2 days).

| ID | Debt | Where | Cost | Plan | Status |
|---|---|---|---|---|---|
| TD-01 | Inline style objects everywhere; Tailwind configured but unused; no tokens. Also forces CSP `style-src 'unsafe-inline'` (ADR-020) | all UI | L | design system with `/field` (M4); then drop `unsafe-inline` from `style-src` | OPEN |
| TD-02 | Fixed desktop grids, not responsive | all UI | L | F1 sets the mobile pattern | OPEN |
| TD-03 | Three competing fonts (Geist loaded, Arial in CSS, "Inter" requested but not loaded) | layout, globals, pages | S | with TD-01 | OPEN |
| TD-04 | Template metadata, `lang="en"` | `layout.tsx` | S | — | DONE (PR #1) |
| TD-05 | Hand-written row types drift from DB | `features/*/types.ts` | M | T14: row types derived from generated schema; typed client; CI drift check | DONE (PR #11) |
| TD-06 | `as any` casts | operations, teams | S | — | DONE (PR #1) |
| TD-07 | Duplicate helpers across files (`getVisitTimeRange`, `getAverageUtilization`, …) | features + clients | S | Operations copies removed (PR #1); rest in T10 | PARTLY DONE |
| TD-08 | Server computed 13 KPIs the client ignored | operations | S | removed in T10 | DONE (PR #9) |
| TD-09 | Duplicate attention items for one case | `operations/rules.ts` | S | behaviour pinned by test; fix after Q2 | OPEN |
| TD-10 | Backup UI files in route folder | `app/operations/` | S | not imported; arrive via owner zip → `docs/legacy-ui/` | DONE (by exclusion) |
| TD-11 | Unused modules | features | S | `getCasesWithVisits` (PR #1), `visits/actions.ts` (T8), `getCases` (T10) removed | DONE |
| TD-12 | `alert()` for command errors | teams, visits | S | inline `CommandError` (role=alert), cleared on new selection | DONE (PR #12) |
| TD-13 | Teams page rendered only two hard-coded regions; teams elsewhere were invisible | teams client | S | grouped by regions present in the data; e2e with a third region | DONE (PR #12) |
| TD-14 | Static Operations mock on `main` | `main` | — | replaced by M2 | IN REVIEW |
| TD-15 | README was create-next-app text | root | S | — | DONE (M2 PR) |
| TD-16 | No typecheck/test scripts | `package.json` | S | — | DONE (PR #1) |
| TD-17 | Errors only logged to console; generic thrown errors | queries/clients | M | structured JSON logging via `src/lib/log.ts`, allowlisted fields, `no-console` lint rule (SR-25). User-facing errors stay generic German messages on purpose. Log shipping/retention: with T12 hosting | DONE (logging) |
| TD-18 | Handover docs describe pre-recovery state | docs | S | proposed update `docs/proposals/CURRENT_IMPLEMENTATION_STATUS.update.md` (owner applies, per `CLAUDE.md`) | IN REVIEW |
| TD-19 | Baseline schema is reconstructed, column types partly guessed; `orders`, PostGIS objects missing | `supabase/migrations/…0001` | M | verified against live 2026-10-21 (drift report); repo schema stays the target (ADR-022); stricter live rules adopted (migration 0005); location features wait for Q7 | DONE |
| TD-30 | Live defaults outside their value sets: `care_visits.status` `'geplant'`, `partner_requests`/`matching_requests.urgency` `'normal'` | live DB | S | not in repo (stricter); mapping needed only if live data is migrated (ADR-022) | OPEN (live only) |
| TD-20 | Reconstructed tables have no CHECK constraints on status/urgency/severity text columns | DB | M | with T9/T10 once value sets are confirmed | OPEN |
| TD-21 | `supabase/setup-cli@v1` runs on deprecated Node 20 runtime | CI | S | bump when a newer major is published | OPEN |
| TD-22 | CI uses `ubuntu-latest`, which migrates to Ubuntu 26 from 2026-10-19 | CI | S | watch first failures; pin `ubuntu-24.04` if needed | OPEN |
| TD-23 | `requireUser()` ran once per query/command | `lib/auth/session.ts` | S | memoised per request with React `cache()` | DONE (PR #12) |
| TD-24 | Test users without roles/memberships | `supabase/seed.sql` | S | — | DONE (T9) |
| TD-25 | Memberships can only be created by SQL; no admin flow, no audit of membership changes | DB | M | after Q5 | OPEN |
| TD-26 | Role names (`admin`, `coach`, `operations`, `nurse`) are a CHECK constraint, not data | `organization_memberships` | S | revisit with Q4 | OPEN |
| TD-27 | `audit_events` grows without retention or archival | DB | M | after Q6 (legal) | OPEN |
| TD-28 | Visit state machine only knew planned→started→completed | DB, visits | M | F2 (migration 0007): linear field path incl. on_the_way and paused. Still open: `assigned/accepted/cancelled/no_show` (D-6) | PARTLY DONE |
| TD-29 | Supabase CLI pinned to 2.121.0 in CI; upgrades are manual and regenerate `database.types.ts` | CI | S | review quarterly or on security advisories | OPEN |
