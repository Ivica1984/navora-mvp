---
id: FEE1
title: Platform fee by effective workload (FTE-weighted F3/F6), synthetic data
author: po
status: approved
updated: 2026-11-11
---

# FEE1 — Platform fee weighted by effective workload (Phase A, synthetic)

**Approved 2026-11-11 00:05 CET for synthetic data only** under founder decision **FE-055** (3). Built after B0 and BD (FE-054), first of the FE-055 items. **No price is set:** the fee is computed in the neutral unit **P** (`PRICING_MODEL_COMPARISON.md`) until D-14 fixes the price level. Use on real staff data waits for `lca` L-14.

## Problem
Every per-head fee (F3, F5, F6) charges small and part-time-heavy teams more per hour actually worked (`PRICING_MODEL_COMPARISON.md` §4: 2.0P vs 1.25P per FTE). That works against value 3 (higher nurse income). The founder excluded per-hour (F1) and revenue-share (F2) fees and chose an FTE-weighted variant.

## Users and journey step
Teams (see and check their fee), NAVORA (prepares the fee invoice to the team, U-N1). Step: Billing (team → NAVORA), Analytics (J7).

## Outcome
A team sees each month its fee = G + P × Σ(effective workload of active members), with every input and the rule version shown, and can check it.

## Acceptance criteria
- [ ] FEE1-1: fee per team and month = base G + P × Σ FTE of active members; G and P are versioned parameters (valid-from, valid-to), not code constants; G = 0 gives pure F3.
- [ ] FEE1-2: "active member" = at least one confirmed workday or visit in the month and access not ended (LEAVE1, WORK1), as already defined.
- [ ] FEE1-3: effective workload comes from **confirmed** working time (F1-F4, WORK1), not from a contract percentage typed in; capped at 1.0 FTE per member; the reference hours per FTE are a versioned parameter.
- [ ] FEE1-4: the fee has no input from billed hours, care categories, tariffs or revenue (F1/F2 firewall). Unit test and pgTAP: changing billable minutes, categories or revenue of a month leaves the fee unchanged; changing confirmed working time changes it.
- [ ] FEE1-5: the team sees only the team total and the sum of FTE, never another member's individual workload (J7 rule "no individual pay visible").
- [ ] FEE1-6: the computation is reproducible: same inputs and rule version give the same fee; a rule change never alters a past month (append-only fee record).
- [ ] FEE1-7: the fee record is U-N1 (GMSEP-2) and never touches care remuneration.
- [ ] FEE1-8: a worked example from `PRICING_MODEL_COMPARISON.md` §4 (Team K, Team G) is a unit test: with FTE weighting both pay 1.0P per FTE (G = 0).
- [ ] Negative cases: a member cannot read another member's FTE; an operator cannot back-date a parameter into a closed month.

## Rules and their input class
FTE from confirmed working time: *visit/schedule fact*. Fee formula: commercial rule (FE-055 (3)), no clinical content.

## AI leverage
Remove: manual fee calculation and disputes. Rules: deterministic formula. Monitor: monthly reconciliation total vs. sum of team fees. AI prepares: none (money calculation). The AI must never compute or adjust a fee.

## Out of scope
Price level (D-14), discounts for young teams (proposal, D-14), payment collection, VAT.

## Constraints and references
FE-023, FE-055; D-14; `PRICING_MODEL_COMPARISON.md`; J7, WORK1, LEAVE1, GMSEP. `lca` L-14: may NAVORA use confirmed working time per member (lohnnahe Daten) to compute the fee, and what must the team agreement say?

## Open questions for engineering
1. Is WORK1's confirmed working time complete enough per member and month, or does FEE1 need its own monthly snapshot?
