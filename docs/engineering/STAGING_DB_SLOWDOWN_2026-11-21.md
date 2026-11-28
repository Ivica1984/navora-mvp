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

## 4. Addendum 2026-11-21 14:20: cause of the red `staging-smoke` path 3 (FE-110 (3), *Active now* 13:39)

Author: `eng` (scheduled run 2026-11-21 14:10 Europe/Zurich). **Root cause from raw data, not a guess.** Read-only: GitHub job logs, Supabase `navora-staging` edge and Postgres logs, `cron.job_run_details`, `pg_roles`. Nothing written; synthetic data only.

### 4.1 Facts (IMPLEMENTED state, measured)

| Run (commit) | Failing step | What the logs show |
|---|---|---|
| `staging-smoke` 44902700301 job 136841753355 (`b44b96a`, Render served `b44b96a` before and after) | path 3, after «Losfahren»: card shows «Wird gespeichert …», then «Losfahren» again; «Unterwegs» never appears (20 s) | `rpc/depart_visit` **200** (3.2 s, 12:24:24 UTC) — the command was written. The refresh of `/field` that follows (12:24:27–28) calls `rpc/team_visit_alerts` twice: **500 after 11.7 s / 11.8 s**; Postgres logs «canceling statement due to statement timeout» at 12:24:37 and 12:24:38. |
| `staging-smoke` 44906414779 job 136852845393 (`4d88399`, docs-only PO merge, Render served `4d88399` before and after) | path 3, after the three time corrections and `page.reload()`: the «Bericht unterschreiben» form never appears (test timeout 240 s) | `rpc/correct_visit_time` **200** three times (13:09:39–44 UTC). Every `team_visit_alerts` call from 13:09:40 to 13:09:46 is **500 after 10.1–12.3 s**; after 13:09:46 no further `/field` data call: the reloaded page did not render. |

- Statement timeout of role `authenticated` on staging: **8 s** (`pg_roles.rolconfig`).
- `team_visit_alerts` in the minute before (13:08:37–13:09:32, same run): 2.2–7.2 s, i.e. already close to the 8 s limit before it was crossed.
- Minute evaluator `navora-sig1-signals`: 12:22 UTC 361 ms, 12:23 **2964 ms**, 12:24 started 5 s late and took **5212 ms** (overlapping the failing step); mean of the last hour **2103 ms** (08:00 UTC: 1184 ms, §1).
- `partner_requests` on staging: **102** (10:09: 71). Staging migration level: `20261021000163`.

### 4.2 Chain (IMPLEMENTED code)

1. The nurse's command succeeds (`depart_visit`, `correct_visit_time`: 200).
2. `/field` re-renders on the server (`router.refresh()` in `field-client.tsx` `run()`, or `page.reload()`); `page.tsx` loads `getTeamVisitAlerts()` together with the day's data.
3. `public.team_visit_alerts` computes every branch of `private.derived_exceptions`, including `order_cover` for every confirmed order (§2); under the smoke's own parallel load plus the minute evaluator it runs past 8 s and is cancelled (57014 → HTTP 500).
4. `getTeamVisitAlerts()` throws on any error (`src/features/team/queries.ts`), so the **whole `/field` render fails**: in run 1 the client keeps the old card («Geplant», «Losfahren») although the visit is already «Unterwegs»; in run 2 the reloaded page shows no report form.

So path 3 is red because of (a) the linear cost of §2 (ADR-226 (A)), which crosses the 8 s statement timeout as the smoke adds about 10 orders an hour, and (b) a **fail-hard design in `/field`**: a failing auxiliary hint list (overdue/stuck visits) takes down the carer's whole day view, so she sees a stale state after a successful command. Not the Next.js upgrade, not a Render deploy (both runs: same commit before and after), not old test data. (b) is a real availability defect for carers, not only a test artefact; it will hit any organisation whose `team_visit_alerts` call fails.

### 4.3 Consequence and proposal (PLANNED, decision `po`)

- **Every further `staging-smoke` run is likely red at path 3** until (A) lands (growth since 10:09: evaluator +78 %, orders +44 %; estimate). Paths 4–6 are then not reached, so «verified on staging» for UXR-269 (#1661) after its merge is likely blocked by this, not by #1661.
- **PERF1 scope proposal for the brief:** (1) ADR-226 (A) as agreed; (2) STAB1-F5 and STAB1-F2 as agreed; (3) **new, needs `po` and a `uxa`/`cra` view:** `/field` must not fail as a whole when `team_visit_alerts` (or another hint list) fails: keep the day view and show one visible line «Hinweise zu Einsätzen konnten nicht geladen werden» instead of the list (a silent omission of safety hints would be wrong; a visible notice keeps the carer informed). Test: unit/e2e with a failing RPC; T-2 «one interrupted step» fits exactly this. (4) PERF1 `db` budget: `team_visit_alerts` on the CI seed with N orders below a stated limit.
- Until then the PO may read path 3 red with the evidence above; no test is weakened or skipped.
