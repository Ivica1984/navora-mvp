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
3. **STAB1-F5:** the smoke removes the orders it creates; the `/order` list stays bounded (as agreed 09:39).
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
- [ ] `staging-smoke` on the merge commit: all paths green incl. 3, 5, 6; the smoke leaves no orders behind (STAB1-F5); a docs-only merge starts no smoke (STAB1-F2).
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
