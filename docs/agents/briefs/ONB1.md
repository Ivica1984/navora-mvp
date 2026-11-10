---
id: ONB1
title: Team-founding assistant for legal structure and professional liability insurance (Phase A: information and simulation only)
author: po
status: approved
updated: 2026-11-11
---

# ONB1 — Legal and insurance assistant in team founding (Phase A)

**Approved 2026-11-11 00:05 CET for information and simulation only** under founder decision **FE-055** (5). Built after B0 and BD. **Nothing is concluded in NAVORA** (no company, no contract, no insurance) until `lca` has reviewed the content, the legal advice of Q1 2027 (FE-050) is in, and a registered insurance broker is a partner (`lca` L-12).

## Problem
Nurses who simply start working together form, without noticing, a simple partnership (einfache Gesellschaft), whose partners are jointly and severally liable without limit. Today NAVORA's team founding says nothing about structure or insurance.

## Users and journey step
Nurses founding or joining a GM-1 team. Step: before Referral (team onboarding).

## Outcome
During team founding, a team sees the structure options, what each means for liability, admission and insurance, which one is already decided as NAVORA's first path, and a checklist of what is still missing; the steps run as a simulation.

## Acceptance criteria
- [ ] ONB1-1: the assistant is part of team founding and cannot be skipped silently: a team either records "structure chosen" (simulated), or "not yet" with the warning on the simple partnership shown.
- [ ] ONB1-2: options are shown from a versioned content table owned by `po` and reviewed by `lca`; first option is the decided path D-12 B (operating-model partnership with a licensed partner). Every other option (own GmbH, cooperative, self-employment) is shown as "in legal review" until `lca` signs its text; no option is labelled "rechtssicher".
- [ ] ONB1-3: the insurance step shows what cover is needed as a checklist (text reviewed by `lca`); there is no premium, no offer and no conclusion button in Phase A.
- [ ] ONB1-4: every simulated choice is stored with the content version shown, the time and the members who confirmed it (audit trail); changing the content never changes a past record.
- [ ] ONB1-5: every screen carries "Information, keine Rechtsberatung" and names who reviewed the content and when.
- [ ] ONB1-6: the BD flow test starts from a team founded through ONB1.
- [ ] Negative cases: no member can record a choice for the team alone where the team agreement requires all members; no external data leave NAVORA (no broker interface in Phase A).
- [ ] ONB1-7 (added 2026-11-11 00:39, po, `lca` D-44 00:45): the checklist names no insurer, no product and no premium, and the assistant suggests none; test: the content table and every assistant output of the step contain none of a test list of insurer and product names, and no CHF amount. A referral to a broker partner is not part of ONB1 (it waits for adviser question Q-44d).

## Rules and their input class
Content table: legal information (not a NAVORA rule), reviewed by `lca`, never written by an agent as a legal determination. No clinical content.

## AI leverage
1. Remove: searching structure and insurance information piecemeal. 2. Rules: the content table and its versions. 3. Monitor: teams with "not yet" after 30 days get a reminder (team level). 4. AI prepares: none in Phase A; a legal choice is not an AI recommendation. 5-7. The team decides and confirms. The AI must never recommend a legal form or an insurance product.

## Out of scope
Company formation, contracts, insurance brokerage, premiums, payment.

## Constraints and references
FE-050, FE-055 (5); D-12 (decided B), D-44, L-9, L-11, L-12 (insurance intermediation: registration duty of NAVORA vs. broker partner).

## Open questions for engineering
1. Where does the content table live so that `lca` can review a version without a code change?
