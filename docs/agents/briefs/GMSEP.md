---
id: GMSEP
title: Strict separation of business models GM-1 (team business) and GM-2 (B2B software) in data model and code
author: po
status: approved
updated: 2026-11-11
---

# GMSEP — GM-1 / GM-2 separation, enforced in the database

**Approved 2026-11-11 00:05 CET** under founder decision **FE-055** (2), (1). Built after B0 and BD (FE-054, FE-055 (7)). Synthetic data only.

## Problem
`BUSINESS_MODELS_AND_CONSTELLATIONS.md` §3 makes the separation of the three money flows a product rule (U-T care remuneration to the team, U-N1 platform fee team → NAVORA, U-N2 licence institution → NAVORA). Today it is a document rule only: no table records which business model an order, a contract, an invoice preparation or a metric belongs to, so nothing stops a care-remuneration amount from being counted as NAVORA revenue, or a team from seeing an institution's own staff (UNKNOWN in code until `eng`'s inventory, open question 1).

## Users and journey step
Teams (GM-1), institutions using NAVORA for their own staff (GM-2), NAVORA finance view. Steps: Referral/order → Billing → Analytics.

## Outcome
Every order, contract, billing preparation and revenue metric carries exactly one business model, and the database refuses every mix.

## Acceptance criteria
- [ ] GMSEP-1: every order or engagement record carries `business_model` ∈ {`gm1_team`, `gm2_b2b`} and a constellation (KON-1 … KON-5), not null, set at creation, never changed afterwards (correction = new record).
- [ ] GMSEP-2: care remuneration (U-T), platform fee (U-N1) and licence (U-N2) are three separate data types; no column, view or function sums U-T into NAVORA revenue. pgTAP: an attempt to write a U-T amount into a NAVORA revenue record is refused.
- [ ] GMSEP-3: no NAVORA record holds a percentage of, or an amount derived from, care remuneration (FE-055 (1)). pgTAP negative case: a fee row referencing a care-billing amount is refused.
- [ ] GMSEP-4: a GM-2 institution's own staff, shifts and residents are not readable by any GM-1 team member, also not when the same institution is a GM-1 client (KON-1); pgTAP for both directions (team → institution staff, institution staff → team-internal data beyond the order).
- [ ] GMSEP-5: a GM-1 order from an institution never creates a licence position, and a GM-2 licence never creates a team remuneration position (§3 rule 3).
- [ ] GMSEP-6: RLS, column grants and audit trigger on every new table (B0-7 check passes).
- [ ] GMSEP-7: the BD flow test (FE-054) runs green with a GM-1 order and a GM-2 institution side by side in one synthetic organisation set.
- [ ] Negative cases: an operator account cannot relabel a GM-2 engagement as GM-1; a team member cannot read a licence record.

## Rules and their input class
`business_model` and constellation: *visit/schedule fact* (contract metadata). No clinical content. No tariff rule is added: amounts stay as the existing billing preparation (J5) computes them.

## AI leverage
1. Remove: manual separation of revenue in reporting disappears. 2. Rules: the separation is a deterministic database rule. 3. Monitor: a nightly check counts records without a business model (must be 0). 4. AI prepares: none; a money boundary is not an AI task. 5-7: not applicable. The AI must never assign or change a business model.

## Out of scope
Prices (D-14), contracts' legal content (D-44), payment processing (L-10).

## Constraints and references
FE-023, FE-040, FE-055; `BUSINESS_MODELS_AND_CONSTELLATIONS.md` §2-3; J5, J7, AIR1; D-44, L-10.

## Open questions for engineering
1. Inventory: which existing tables (orders, billable facts, organisations) need the column, and is a separate `engagements` table cleaner than a column on `orders`?
2. Can GMSEP-4 reuse the existing organisation/team RLS, or does a GM-2 institution need its own tenant boundary?
