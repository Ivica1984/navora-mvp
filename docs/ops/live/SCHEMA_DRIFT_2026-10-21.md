# Live schema vs. repository baseline — drift report (TD-19 / O-F)

**Date:** 2026-10-21 · **Live project:** `jwmfxrmougneeceldhsa` (Postgres 17, eu-west-1)
**Method:** read-only catalog queries via the Supabase connector (`information_schema`, `pg_constraint`, `pg_indexes`, `pg_proc`, `pg_extension`). Data checks used **counts and value sets only**; no personal content was selected.
**Compared with:** `supabase/migrations/20261021000001_baseline_reconstructed.sql`, which was reconstructed from code because live access was missing.
**Status of this document:** findings VERIFIED; proposals PLANNED. Per `CLAUDE.md`, nothing was changed automatically.

## 1. Objects in live that the repository does not have

| Object | Live definition (summary) | Used by the app? |
|---|---|---|
| `public.orders` | `session_id` (unique), `status`, `amount_total`, `currency`, `email`, `city`, `slot`, `receipt_url`, `payment_intent_id`, `charge_id`; policies `service-role read/write` | **No.** 10 rows, all `paid`, CHF, **all Stripe test-mode IDs** (`cs_test…`/`pi_test…`), created 2026-02-07…17 — before NAVORA's data (2026-08-13). Looks like a checkout table of another app (probably the Render service `Lumena-Health`, created 2026-01-26). Answers **Q1** (inferred) |
| `public.team_locations` | team bases/hubs with PostGIS `geography`, `location_status` CHECK, one active primary per team (partial unique index) | No (0 rows) |
| `private.geocoding_jobs` | queue: exactly one target (case/team/team_location), status CHECK, unique pending job per target | No |
| `private.calculate_case_team_distance_km(uuid, uuid)` | `SECURITY INVOKER` | No |
| Extensions | `postgis 3.3.7`, `uuid-ossp`, `pg_stat_statements`, `pgcrypto` | `pgcrypto` only |
| `teams` extra columns | `max_members` (12), `max_active_cases` (45), `target_utilization` (85), `base_location` geography, `location_status/accuracy/source/updated_at`, `service_radius_km` (> 0 CHECK) | No |
| `cases` extra columns | `location` geography (GiST), `location_status/accuracy/source/updated_at`, **`"assigned team"`** (column name with a space, 0 rows filled — dead duplicate of `assigned_team`) | No |

## 2. Shared tables: differences

| Table.column | Repository | Live | Assessment |
|---|---|---|---|
| `teams.open_slots`, `teams.utilization` | `integer` | **`bigint`** | harmless; repo is stricter |
| `teams.created_at`, `care_visits.created_at` | `not null` | nullable | repo is stricter |
| `care_visits.billable` default | `false` | **`true`** | repo is safer (T10 locks `billable`); keep repo |
| `care_visits.status` default | `'planned'` | **`'geplant'`** | **live default is outside the value set** the app and state machine know (`planned/started/completed…`). Live rows all have `completed`, so no harm so far |
| `partner_requests.urgency`, `matching_requests.urgency` default | none (`not null`) | **`'normal'`** | **outside the value set** `niedrig/mittel/hoch`; the attention rules treat it as non-urgent. Bug in live; repo is stricter (TD-30) |
| `quality_events.severity` default | none | `'medium'` | acceptable |
| `care_notes.note_type` default | none | `'visit_report'` | acceptable |
| `match_candidates.fit_score`, `.status` | nullable | `not null` | repo looser — adopt live |
| FK `care_notes.visit_id`, `match_candidates.matching_request_id` | no action | **`on delete cascade`** | cascading deletes of care documentation conflict with auditability; repo's `no action` is safer. Keep repo |
| FK indexes | 14 indexes | none | repo better |
| Status/urgency CHECK constraints | none (TD-20) | none | neither side has them |

Repository-only objects (tenancy, memberships, audit log, command functions; migrations 0003–0004) do not exist in live, as expected: live was never migrated.

## 3. Data characteristics (counts only)

- `cases`: 6 rows, all created on **2026-08-13**. No row has date of birth, phone, address, emergency contact, insurance or notes. 2 rows have `diagnosis_tags`, all 6 have `cognitive_status` and `mobility_status`. This pattern suggests demo data, but **cannot prove it**. The owner must still confirm (CONTAINMENT_REPORT §4.1).
- Value sets match the legacy UI (`neu/teampruefung/laufend`, `niedrig/mittel/hoch`).
- `orders`: 10 e-mail addresses (Stripe test mode). E-mail addresses are personal data, even for test purchases.

## 4. Conclusions

1. **The live project is not a NAVORA-only database.** It also holds a checkout table of another application (inferred). → **SR-26.**
2. Live is a **prototype schema** with features the code never used (PostGIS, geocoding, team capacity limits) and two defaults that violate its own value sets. The repository schema is stricter and safer in every shared column except the two `not null`s on `match_candidates`.
3. Replacing the repository baseline with the live schema (the original O-F plan) would **import weaker rules** (cascading deletes, invalid defaults, a column with a space) and unused PostGIS dependencies.

## 5. Proposal (ADR-021, PROPOSED)

- **The repository schema is the target. Live is legacy.** The baseline stays; its header changes from "reconstructed, verify against live" to "verified against live 2026-10-21, deliberate deviations listed in this report".
- Adopt from live now (no product decision needed): `not null` on `match_candidates.fit_score` and `.status`.
- **Do not adopt:** cascading FKs, `'geplant'` and `'normal'` defaults, `"assigned team"`, `bigint` counters.
- **Product decision before adopting** (location features belong to matching and DOMAIN_RULES): `team_locations`, PostGIS columns, `geocoding_jobs`, team capacity limits. Tracked as Q7.
- **`orders`:** does not belong in NAVORA. The owner decides whether to move it to Lumena-Health's own project or delete it. It is out of scope for NAVORA migrations either way.
- New environments (staging, D-2) start from the repository migrations, never from a dump of live.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
