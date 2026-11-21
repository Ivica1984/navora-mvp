# Staging database slowdown: root cause and proposal (2026-11-21)

Author: `eng` (scheduled run 2026-11-21 10:09 Europe/Zurich). Answers the follow-up «staging DB slowdown (OPEN, `eng`)» in *Active now* 2026-11-21 09:39 and journal `2026-11-21-0519-eng.md` (b). **Analysis and proposal only; no code, no migration.** Not in *Active now*: implementation needs a PO release (block rule).

All numbers below were read **read-only** on Supabase `navora-staging` (`qpmdryxkktbqqkqpsnkj`) between 10:09 and 10:20 Europe/Zurich: `pg_stat_statements`, `cron.job_run_details`, `pg_stat_user_tables`, `pg_get_functiondef`, and `explain analyze` inside `set transaction read only` on STABLE functions only. Nothing was written. Synthetic data only.

## 1. Facts (IMPLEMENTED state on staging, measured)

| Measure | Value |
|---|---|
| pg_cron `navora-sig1-signals` (`private.evaluate_all_signals()`, every minute), hourly mean | 2026-11-20 03:00 UTC: **189 ms** → 2026-11-21 08:00 UTC: **1184 ms** (×6.3 in 29 h); max 6.4–7.4 s; 0 failed runs |
| `public.team_visit_alerts()` via PostgREST | 715 calls, mean **1240 ms**, max 7.8 s — top user-facing cost |
| `public.my_signals()`, `client_orders()`, `team_order_offers()` | mean 316 / 376 / 322 ms, max 7.1 / 3.9 / 2.7 s |
| Data volume | 9 organisations, 104 visits, **71 `partner_requests`** (67 confirmed shift orders in the simulation organisation `…0019`, first 2026-11-20 08:00 UTC; 18 of them already ended) |
| `private.derived_exceptions(org)` for all 9 organisations | **976 ms**, 63 rows, 11 428 buffer hits (all cache): CPU-bound, not I/O |
| `private.order_cover(id, now())` for the 67 confirmed orders | **564 ms** = 8.4 ms per order |

## 2. Root cause (IMPLEMENTED code, read from `supabase/schema/functions/private.derived_exceptions.sql` and the staging definitions)

1. The BK-C1 branch of `private.derived_exceptions` (ADR-199 (9), `order_not_covered`) evaluates `private.order_cover(p.id, now())` for **every confirmed shift order of the organisation, past and future**, with no time bound. Cost grows linearly with the order count. The staging smoke creates orders on every run (about 60 a day, measured on 2026-11-20/21; STAB1-F4/F5), so the curve in §1 follows the smoke's order count, not real use.
2. `derived_exceptions` is `language sql security definer`, so the planner cannot inline it and cannot push a caller's filter into it. Every caller pays for **all** branches:
   - `private.evaluate_signals` keeps only `entity_type = 'visit'` rows, yet computes the `order` branch (564 of 976 ms of the derivation, about half of one evaluator run on staging today);
   - `public.team_visit_alerts` keeps five visit types (`visit_overdue`, `visit_stuck`, `visit_interrupted`, `report_correction_open`, `order_without_end_date`), yet computes every branch;
   - `public.operations_exceptions` is the only caller that needs `order_not_covered`.
3. `order_cover` itself costs 8.4 ms per order on tiny tables (`partner_requests` shows 3.5 M index scans for 71 rows), i.e. nested per-row function calls. UNKNOWN which inner call dominates; needs a function-level profile (`track_functions` is off on staging; not changed by me).

**Risk (OPEN):** at the current smoke rate the minute evaluator passes 2–3 s mean within about two days (estimate, linear fit) and the PostgREST statement timeout (`57014`, already seen at 03:05) hits `team_visit_alerts` and `my_signals` more often. The slow minute at 03:05 on 2026-11-21 coincided with the `staging-smoke` path 3 failure (journal 0519); a causal link is likely but UNKNOWN. In a real organisation with months of orders the same growth applies; this is a production risk, not only a staging artefact.

## 3. Proposal (PLANNED, for the PO; ADR draft, number assigned on merge to avoid a conflict with ADR-225 on #1641)

**ADR-226 (DRAFT) — Bound the exception derivation to what each caller needs**

- **(A) Behaviour-preserving, no clinical or product decision needed (recommended first):** split `derived_exceptions` into a visit part and an order/case part, or give it a kind filter evaluated *inside* each branch (`p_kinds text[]`; a branch is skipped when its type is not asked). `evaluate_signals` and `team_visit_alerts` ask only for the visit types they already filter on; `operations_exceptions` asks for all. Output for each caller is row-for-row identical: proved by a pgTAP equality test (old definition vs new, same seed, same `private.now()`), plus the kept guards (definer, `search_path ''`, grants, revokes) by the STAB1 catalogue test. Change through whole `create or replace` from the canonical files (TESTS 6). Expected effect on staging today (estimate): evaluator ≈ 1.1 s → ≈ 0.6 s, `team_visit_alerts` similar; the growth with order count disappears for these two paths.
- **(B) Needs a `po`/`cra` decision (not proposed for building now):** bound the BK-C1 branch in time, e.g. no `order_not_covered` for an order that has ended. This changes what Operations sees (does an uncovered past shift stay an open exception until closed?), so it is a product/clinical question, not an engineering one. OPEN for `po` with `cra`.
- **(C) Technical, after (A):** profile `order_cover` (8.4 ms per order) with `track_functions = pl` on the CI database (never on staging without a PO note) and remove repeated per-row lookups; same equality-test rule.
- **Related, already in the follow-up list:** STAB1-F5 (bounded `client_orders()`), STAB1-F2 (no smoke on docs-only merges). Fewer smoke orders slow the growth but do not remove the linear cost; (A) does.

**Way back:** (A) is one migration with whole `create or replace` of two or three functions from their source files; reverting is the previous source file in a new migration. No table, grant or RLS change.

**Not touched by this proposal:** HD-2 (#1641, ready-reported, stable head). (A) would be its own small `fix/` or `stab/` package after HD-2 merges, because HD-2's migration 0161 re-creates `order_cover`.
