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
  - *Amended 2026-11-11 00:39 (po, `lca` D-14 00:40 finding):* no screen, export or API returns another member's FTE or working-time figure. In a team of **two** active members, Σ FTE (and the fee itself, since G and P are visible) lets each member derive the other's workload. Product decision (po): hiding Σ FTE for n < 3 would be false protection, so the team sees it, and the team agreement text (simulated in Phase A, ONB1) states what the sum reveals in a team of two. Test: for n = 2 the team view carries that notice; for every n no member reads another member's FTE.
- [ ] FEE1-6: the computation is reproducible: same inputs and rule version give the same fee; a rule change never alters a past month (append-only fee record).
  - *Amended 2026-11-11 00:39 (po, `lca` note (2)):* the fee record stores only the team total (Σ FTE), the member count, G, P, the rule version and the fee; per-member FTE values are an intermediate result and are not persisted after the month closes. Reproducibility comes from the confirmed working time already kept by WORK1, not from a per-member copy in the fee record. pgTAP: the fee record table has no member column.
- [ ] FEE1-7: the fee record is U-N1 (GMSEP-2) and never touches care remuneration.
- [ ] FEE1-8: a worked example from `PRICING_MODEL_COMPARISON.md` §4 (Team K, Team G) is a unit test: with FTE weighting both pay 1.0P per FTE (G = 0).
- [ ] Negative cases: a member cannot read another member's FTE; an operator cannot back-date a parameter into a closed month.
- **Condition before real data (`lca` D-14 00:40, PLANNED, not a Phase A criterion):** FEE1 on real working time needs NAVORA's terms and the team agreement with the seven drafting items of the `lca` section (D-12 entity, D-42/D-38 templates; owner). Hours from POOL1 orders enter the FTE sum on real data only after adviser question Q-44c (widened) is answered; synthetic data are not affected. If POOL1 reaches real use before Q-44c, the PO asks the owner whether to exclude those hours meanwhile.

### Amendment 2026-11-11 02:39 CET (po, `cra` CGR-172 advisory S2; `aia` AUT-82)
Taken in for Phase A (synthetic); no price or founder decision changed:
- [ ] **FEE1-3a (CGR-172 (a)):** the fee never falls when a member leaves a day with completed visits unconfirmed. For such a member-day, FEE1 counts a **visit-derived floor**: the span of that day's completed visits from VIS1 start/end times (not billable minutes, categories or revenue, so FEE1-4 holds). pgTAP: removing the confirmation of a day that has visits does not lower the month's fee.
- [ ] **FEE1-5a (CGR-172 (b)):** the team view next to the fee shows the number of member-days with visits but no confirmation (team level, no names; WORK1-5 holds).
- [ ] **FEE1-3b (CGR-172 (c)):** hours above the 1.0 FTE cap stay unchanged in WORK1 and are shown at team level as a count of member-months above the reference (count only, no threshold; any limit is `lca` (ArG) and the Clinical Owner). Unit test: two members at 1.3 and three members at 0.87 for the same total hours give the count 2 and 0.
- **FEE1-4 (CGR-172 (d)):** the firewall test stays unchanged.
- **Cap and bands (owner, D-14):** whether the 1.0 cap stays, and `aia` AUT-82's proposal to take FTE in **bands** so declared outside-visit minutes move the fee only when a band changes, are pricing-model questions; added to the D-14 package as options for the owner, not decided here. Until then FEE1 is built with the cap as written and without bands.

### Amendment 2026-11-11 04:39 CET (po, `lca` D-14 re-check 04:20, advisory; product authority, synthetic data, no pricing choice made)
- [ ] **FEE1-3a (amended):** the visit-derived floor is a fee input only: it **never writes to WORK1** and is **never shown or labelled as working time** (as WORK1-C4). A confirmed member-day always uses the confirmed value, never the floor. Unit test: a confirmed day whose visit span is longer than the confirmed time counts the confirmed time; pgTAP: computing the fee leaves the member's WORK1 rows unchanged.
- [ ] **FEE1-5 (amended, team of two):** the option (b) sentence (the team agreement states what the team view reveals) covers the Σ FTE **and** the counts of FEE1-5a and FEE1-3b.
- [ ] **FEE1-3b (amended, label):** the count is labelled «Monate über Referenz»; never «Überzeit», «Überstunden» or any wording of an ArG or overtime check (ArG limits are weekly and yearly and depend on the employer, D-12). Unit test on the label text.
- Real-data conditions (`lca` (i)-(iii)) recorded; nothing is computed on real data (Phase A).

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
