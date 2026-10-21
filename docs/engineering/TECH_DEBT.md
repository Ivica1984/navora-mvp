# NAVORA — Technical Debt Register

**Last updated:** 2026-10-21 · Scope: `recovery/main`. Security-relevant debt lives in `SECURITY_RISKS.md`.
**Cost:** S (< ½ day) · M (½–2 days) · L (> 2 days).

| ID | Debt | Where | Cost | Plan | Status |
|---|---|---|---|---|---|
| TD-01 | Inline style objects everywhere; Tailwind configured but unused; no tokens | all UI | L | design system introduced with `/field` (M4) | OPEN |
| TD-02 | Fixed desktop grids, not responsive | all UI | L | F1 sets the mobile pattern | OPEN |
| TD-03 | Three competing fonts (Geist loaded, Arial in CSS, "Inter" requested but not loaded) | layout, globals, pages | S | with TD-01 | OPEN |
| TD-04 | Template metadata, `lang="en"` | `layout.tsx` | S | — | DONE (PR #1) |
| TD-05 | Hand-written row types drift from DB | `features/*/types.ts` | M | `getCases` fixed, mistyped query removed (PR #1); generated `database.types.ts` moved to T10 | PARTLY DONE |
| TD-06 | `as any` casts | operations, teams | S | — | DONE (PR #1) |
| TD-07 | Duplicate helpers across files (`getVisitTimeRange`, `getAverageUtilization`, …) | features + clients | S | Operations copies removed (PR #1); rest in T10 | PARTLY DONE |
| TD-08 | Server computes 13 KPIs the client ignores and recomputes | operations | S | T10 | OPEN |
| TD-09 | Duplicate attention items for one case | `operations/rules.ts` | S | behaviour pinned by test; fix after Q2 | OPEN |
| TD-10 | Backup UI files in route folder | `app/operations/` | S | not imported; arrive via owner zip → `docs/legacy-ui/` | DONE (by exclusion) |
| TD-11 | Unused modules | features | S | `getCasesWithVisits` removed; `getCases`, `startVisit` in T10 | PARTLY DONE |
| TD-12 | `alert()` for command errors in Teams/Visits; no shared error/toast model | teams, visits | S | T8 replaced `window.location.*` with server redirects and `router.refresh()`; error UI in T10 | PARTLY DONE |
| TD-13 | Regions "Bern West" / "Zürich Pilot" hard-coded in Teams grouping — teams in other regions do not render | teams client | S | after T9 | OPEN |
| TD-14 | Static Operations mock on `main` | `main` | — | replaced by M2 | IN REVIEW |
| TD-15 | README was create-next-app text | root | S | — | DONE (M2 PR) |
| TD-16 | No typecheck/test scripts | `package.json` | S | — | DONE (PR #1) |
| TD-17 | Errors only logged to console; generic thrown errors | queries/clients | M | after M3 (structured logging without health data) | OPEN |
| TD-18 | Handover docs describe pre-recovery state | docs | S | proposed update `docs/proposals/CURRENT_IMPLEMENTATION_STATUS.update.md` (owner applies, per `CLAUDE.md`) | IN REVIEW |
| TD-19 | Baseline schema is reconstructed, column types partly guessed; `orders`, PostGIS objects missing | `supabase/migrations/…0001` | M | replace with live pull (O-F) | OPEN |
| TD-20 | Reconstructed tables have no CHECK constraints on status/urgency/severity text columns | DB | M | with T9/T10 once value sets are confirmed | OPEN |
| TD-21 | `supabase/setup-cli@v1` runs on deprecated Node 20 runtime | CI | S | bump when a newer major is published | OPEN |
| TD-22 | CI uses `ubuntu-latest`, which migrates to Ubuntu 26 from 2026-10-19 | CI | S | watch first failures; pin `ubuntu-24.04` if needed | OPEN |
| TD-23 | `requireUser()` runs once per query/command, so `/operations` makes several Auth round-trips per request | `lib/auth/session.ts` | S | memoise per request with React `cache()` once measured | OPEN |
| TD-24 | Test users without roles/memberships | `supabase/seed.sql` | S | — | DONE (T9) |
| TD-25 | Memberships can only be created by SQL; no admin flow, no audit of membership changes | DB | M | after Q5 | OPEN |
| TD-26 | Role names (`admin`, `coach`, `operations`, `nurse`) are a CHECK constraint, not data | `organization_memberships` | S | revisit with Q4 | OPEN |
