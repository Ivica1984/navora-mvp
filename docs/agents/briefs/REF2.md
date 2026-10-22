---
id: REF2
title: Hospital referral without an intake coordinator
author: po
status: draft
updated: 2026-10-22
---

# REF2 — Hospital referral without an intake coordinator

## Problem
Today NAVORA Operations re-types every referral (J1). On the hospital side, discharge planners phone several providers to find one that can start in time. This is the traditional intake coordinator role, duplicated on both sides. It is also NAVORA's wedge into transitions of care: a hospital that can refer once, digitally, and get a guaranteed answer has a reason to choose NAVORA.

## Users and journey step
Hospital discharge planners (partner users); NAVORA Operations only on exceptions. Journey: Referral → Case → Matching.

## Outcome
A discharge planner submits one structured referral. It becomes a case and reaches all eligible teams at once (J2). The planner sees the status and the accepting team within the response deadline, without a phone call.

## Acceptance criteria (draft)
- [ ] Partner organisations have accounts; a partner user sees only her own organisation's referrals and their status: received, ready, offered, accepted, first visit planned.
- [ ] The referral form collects exactly the J1 readiness facts, with consent captured by the referrer in the form required by D-9.
- [ ] A complete referral passes the J1 readiness check and opens matching without anyone at NAVORA touching it. An incomplete one returns to the referrer with the missing items, not to Operations.
- [ ] Operations sees only exceptions: unclear consent, a duplicate client, a case outside every team's region.
- [ ] Measured in AN1: share of referrals handled without Operations, and referral-to-first-visit time.

## Why draft
It depends on three owner and legal decisions:
- **D-9** (`legal`): the legal basis for receiving client data from the hospital.
- **D-3** (`owner`): partner read scope.
- Partner contracts (Gate 7).

It becomes approved once D-9 and D-3 are answered.

## Constraints and references
J1 (ADR-026, ADR-029), J2. PRODUCT_REQUIREMENTS: Partner, Spital: Überleitung/Nachversorgung (transition and follow-up care). `docs/product/CARE_OPERATING_MODEL.md`, horizon 2.
