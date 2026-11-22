---
id: PERF1
title: Staging stays usable as data grow; the carer page never fails on a hint list
author: po
status: approved
updated: 2026-11-21
---

# PERF1 — Staging stays usable as data grow; the carer page never fails on a hint list

Order: FE-111 (2), after UXR-269 (#1661). Block HEIM-DP stays the frame; PERF1 is a technical package (like STAB1), one Engineering PR. Written by the PO in the scheduled run 2026-11-21 14:39 from `eng`'s root cause and scope proposal (#1663, `docs/engineering/STAGING_DB_SLOWDOWN_2026-11-21.md` §2–§4; issue #1660 comment 7063134770). The PO ran no tests.

## Problem

IMPLEMENTED state, measured by `eng` from raw logs (§4.1):

- `private.derived_exceptions` computes every branch for every caller; the `order_not_covered` branch calls `order_cover` for every confirmed order, past and future, with no time bound (§2). Cost grows with the order count (staging: 71 → 102 orders between 10:09 and 14:10).
- `public.team_visit_alerts` now runs 10–12 s on staging and is cancelled by the 8 s statement timeout of `authenticated`.
- `/field` loads `getTeamVisitAlerts()` with the day's data and throws on any error, so the **whole carer page fails**: after a successful «Losfahren» the card still shows the old state, or the report form never appears. `staging-smoke` path 3 is red twice (44902700301, 44906414779), paths 4–6 are then not reached.
- This is a carer-facing availability and continuity defect, not only a test artefact: any organisation with months of orders reaches the same limit.

## Users and journey step

Carer (`/field`, Visit and Documentation steps); team and operations (exception lists); the founder and every reviewer (staging as the proof of delivery).

## Outcome

A carer's day view always renders after a successful command, also when a hint list cannot be loaded; and the exception derivation stays well below the timeout as orders grow, so `staging-smoke` is a reliable signal again.

## Scope (PO decision; HOW is `eng`'s)

1. **ADR-226 (A):** behaviour-preserving split of `derived_exceptions` so each caller computes only the branches it reads (`evaluate_signals` and `team_visit_alerts` no longer compute the `order` branch). Same rows, same texts for every caller (pgTAP equivalence).
2. **`/field` degrades visibly, never silently (new, from #1663 §4.3 (3)):** when `team_visit_alerts` (or another auxiliary hint list) fails, the day view and the visit commands stay; in place of the list one visible line says that the hints could not be loaded (working wording «Hinweise zu Einsätzen konnten nicht geladen werden»; final wording at the `uxa` gate, content check by `cra`). Hints are never dropped without that line.
3. ~~**STAB1-F5:** the smoke removes the orders it creates; the `/order` list stays bounded (as agreed 09:39).~~ Moved to follow-up STAB1-F5 (a) (PO amendment 2026-11-22 02:39).
4. **STAB1-F2:** no `staging-smoke` run for docs-only merges (`paths` filter).
5. **`db` performance budget:** `team_visit_alerts` (and the evaluator's derivation) on the CI seed with a stated number of orders below a stated limit; the limit and N are named in the ready report.

## Non-goals

- ADR-226 (B) (time bound for `order_not_covered`): changes what is shown; waits for `cra` (FE-111 PO note).
- Any change of statement timeouts on staging, of signal rules, thresholds or texts other than the one notice line in (2).
- New features; Supabase project settings (`eng` reads, never writes, the live projects; the PO never touches them).

## Acceptance criteria

- [ ] pgTAP: for the seed, the rows of every caller of the split derivation are identical before and after (equivalence test), incl. `operations_exceptions` with `order_not_covered`.
- [ ] pgTAP or a `db` timing test: `team_visit_alerts` below the stated budget on the seed with N orders.
- [ ] e2e: with `team_visit_alerts` failing (forced error), `/field` renders the day view, shows the notice line, and «Losfahren» still moves the card to «Unterwegs»; negative: no hint list is shown as empty without the notice.
- [ ] **T-1 «sent = shown» (FE-111):** after every carer command in path 3 the card shows the state the server stored (no stale card after a 200).
- [ ] **T-2 «one wrong, interrupted or double step» (FE-111):** interrupted = the failing hint list above; double = a double tap on «Losfahren» yields one state change.
- [ ] `staging-smoke` on the merge commit: all paths green incl. 3, 5, 6; ~~the smoke leaves no orders behind (STAB1-F5)~~ the smoke writes only the orders its paths need and withdraws what HD.md §3 allows (path 6) (PO amendment 2026-11-22 02:39); a docs-only merge starts no smoke (STAB1-F2).
- [ ] No test skipped or weakened; `ci` green on the head; after the merge `ci` green on the merge commit and `ci-repeat` 10/10 (`db`, `e2e`).

## Rules and their input class

No new rule. (1) moves computation, not decisions (equivalence test). (2) adds one display line of the class *visit/schedule fact* (a load state); it ranks, routes or escalates nothing.

## AI leverage

No AI leverage, by reason: PERF1 is reliability work under the first connected model (AI1). Removed work: the PO and `eng` no longer spend a cycle per red smoke on a known cause. Every function stays a fixed rule; no model, no test substitute.

## Gates (one window after `Paket prüfbereit:` on a stable green head)

- `uxa`: notice line wording and placement at 390 and 1440 px.
- `cra`: that a carer is never left without hints silently; the notice is enough for the simulation.
- No `lca`, no `aia` gate (no data flow, no model).

## Vision check (FE-070 (7), short)

More direct care time and continuity: the carer's screen does not break after a correct action. Team autonomy and administration: unchanged. Platform: staging becomes a trustworthy proof again, which AI1 needs.

## Open questions for engineering

- Name N and the budget for (5) from the measured staging curve.
- Whether other pages (`/team`, `/heim`) load an auxiliary list fail-hard in the same way; list them in the ready report (fix only `/field` in PERF1 unless the same helper covers them).

## PO amendment 2026-11-21 20:39 (before the package starts; no package was ready, so no merge condition is added to a ready head)

Inputs: `eng` 7063940738, 7067863141 (#1660), ADR-226 draft (#1666); `aia` AUT-184 to AUT-186 (#1667); `cra` CGR-272 to CGR-275 and the ADR-226 (B) recommendation (#1669, `CLINICAL_GOVERNANCE.md` 2026-11-21 20:33).

1. **`/team` in scope (AUT-184, CGR-272, `eng` proposal):** the same degrade helper and the same notice line for `team_visit_alerts` on `/team` (`team/page.tsx:42`); one more e2e (forced failure → team view stays, notice line visible). The `uxa` gate sees both pages.
2. **Degrade conditions (CGR-272), added to scope (2) and its e2e:** the notice line is shown on every render while the call fails (no cached empty list), sits where the list would be and above the visit cards, and each failure is counted per team and day (team level, never per person) in addition to the log line; the ready report names where the count can be read.
3. **Safety lists stay fail-hard (AUT-185, CGR-273):** `field_safety_alerts` and any list `cra` names are not behind the degrade helper in PERF1. Their failure form and whether a visit may start without them are open for the Clinical Owner (UNKNOWN); no PO decision.
4. **Budget (AUT-186):** the deterministic call-count proof (0 `order_cover` calls from `team_visit_alerts` and the evaluator derivation) is the primary acceptance signal; the timing budget is secondary. N = 300 confirmed orders per organisation is a **PO assumption** for the simulation horizon (not a measurement); `eng` names the final limit from the CI measurement. The CI setup line for `track_functions` (OPEN, `eng` 7067863141 (3)) is `eng`'s HOW; it must not weaken any other check.
5. **Evaluator (CGR-275):** the ready report names the run durations of `evaluate_all_signals` on staging during the slowdown from read-only data, or states UNKNOWN. Reporting duty only.
6. **ADR-226 (B) and `operations_exceptions` (CGR-274):** stay non-goals of PERF1. The `cra` recommendation (bound the live computation to orders not yet ended; keep an ended uncovered order as a stored open-or-handled record) is adopted as the direction of follow-up **PERF1-F1**, brief after PERF1; what handling an ended uncovered shift requires is for the Clinical Owner (UNKNOWN), not set here.

Gates unchanged: `uxa` (wording and placement, `/field` and `/team`), `cra` (CGR-272 conditions, CGR-273 boundary, equivalence for every caller).

## PO amendment 2026-11-22 02:39 (scope decision before the package is ready; removes a scope item, adds no merge condition, FE-089 (3))

Answer to `eng` 7070751986 (repeated in the latest #1671 comment), question «scope (3) STAB1-F5: (A) or (B)» (#1671). **PO decision: (A).**

1. Scope item 3 (STAB1-F5) leaves PERF1 and becomes its own follow-up item **STAB1-F5 (a)**: `client_orders()` returns orders not yet ended plus ended orders of the last *N* days; open and future work first (H-STAB1-F5). *N* and the «history on demand» design are OPEN for `po` with `uxa`; brief after PERF1. No delete path for orders, takes, visits or signed reports is built (audit and append-only stay, CSR1, CGR-03); no client or home cancellation of a covered order is invented (domain rule, CGR-234/242, `lca`).
2. The acceptance line «the smoke leaves no orders behind (STAB1-F5)» is replaced by: «the smoke writes only the orders its paths need and withdraws what HD.md §3 allows (path 6)». STAB1-F2 (a docs-only merge starts no smoke) stays as written.
3. Reason (WHAT/WHY): «no orders behind» cannot be met without either breaking audit or inventing a domain rule; PERF1's outcome does not depend on it (ADR-226 already removed order growth from `team_visit_alerts` and `my_signals`, pgTAP 164, as reported by `eng`). `cra` supports (A) (as reported by `eng` on #1671).
4. Order to S-1 (#1677): unchanged FE-112 (c). S-1 was ready first (7072089149) and is merged first once its gate window is `clear`; PERF1 then merges `recovery/main` in and needs green CI on its new head.

Gates unchanged.
