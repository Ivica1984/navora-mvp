---
id: BK
title: Durchgehender Kern — vom Auftrag bis zur Abrechnung (generisch für Heim, Spital, Privatperson)
author: po
status: approved   # starts as active block when B1.1 (cut to B1.1-1 … B1.1-1c) is accepted
updated: 2026-11-13
---

# BK — Durchgehender Kern: Auftrag → Prüfung → Empfehlung → Teamentscheid → Einsatz → Bericht → Rechnung

Founder decisions **FE-073** (core chain first) and **FE-074** (generic logic, client view with AI capture, synthetic variety), 2026-11-13. Phase A only: **simulation, synthetic data.** No release for real persons and data.

**Generic, not one case.** BK builds one logic for every order type (shift in a home or hospital ward, care at a private household), every shift type (früh, spät, nacht, Wochenende) and every level (AGS, FaGe, HF). The Lehenmatt late shift (FE-073 (5)) is **one** of the acceptance scenarios, not the design.

## Problem
A home, a hospital ward or a private household that needs care at short notice phones agencies; the agency keeps the margin, a dispatcher decides, the carer types reports, someone writes the invoice. NAVORA has parts of the chain but no single path from an order to an invoice, and no view in which the client states the need in its own words.

## Users and views
- **Auftraggeber-Ansicht (Referral/Client Portal):** home, hospital ward, private person. States the need by voice or free text, checks the recognised fields, confirms.
- **Team-Dashboard:** gets the offer with reasons; an authorised member takes it.
- **`/field`:** the carer runs the shift, records time, dictates, signs.
- **NAVORA operator:** counts only (the chain ran); no content.
- Not in the happy path: Operations as dispatcher, coach, relatives.

## Acceptance criteria

### Step 1: capture (client view, AI-assisted)
- [ ] BK-1 The client enters the need **by voice or free text** (e.g. «Brauche für Sonntag Nachtdienst eine FaGe, 22:00–07:00 Uhr»), or fills the form directly; both end in the same structured order.
- [ ] BK-1a **Extraction** fills the required fields: date(s), start and end, shift type (früh/spät/nacht/Wochenende, derived from the times), place of care as **PLZ** (BS/BL list), qualification level (AGS, FaGe, HF), activity tags. Every field shows whether it was **recognised** or **entered**.
- [ ] BK-1b **Nothing is guessed silently:** a relative date («Sonntag») is shown as a concrete date; a field that cannot be recognised stays empty and is asked for; a contradiction (e.g. «Nachtdienst 14:00–18:00») is shown and must be resolved by the client. No default fills a required field.
- [ ] BK-1c **A night shift across midnight is one order** (start date + end next day, 9 h for 22:00–07:00), never two days or a negative duration (known risk CGR-200).
- [ ] BK-1d The order is binding only after **«Bestätigen & Absenden»** on a summary of all fields; before that nothing reaches teams. Client can correct any field in the summary.
- [ ] BK-1e **Data minimisation in the capture:** the view asks for the need, not for a patient story; for a **private household** only the PLZ is used for matching, the street address is released to the team only after it has taken the order. Free text that is not mapped to a field is not stored with the order (wording and rule `lca`, `uxa`).
- [ ] BK-1n A team member cannot create or confirm an order for a client; a client sees only its own orders.

### Step 2: deterministic check, then AI ranking (the heart)
- [ ] BK-2 **Hard filters**, deterministic, in the database, before any AI: PLZ distance within the order's radius; qualification level allowed for every tag (`QUALIFICATION_MATRIX`, PROPOSED, simulation only); availability for the **whole** slot (including night and weekend); every tag marked «required» held as a **confirmed** attribute. Each excluded team carries its reason.
- [ ] BK-2n A team failing any hard filter is **never** offered, whatever the ranking says (test asserts on offer rows).
- [ ] BK-3 **Ranking** among the eligible only: practice experience, prior knowledge, continuity with this client, distance. The ranking can reorder, never add. AI ranking runs on synthetic data only (D-35 rule A; FE-051 Muster 1/4).
- [ ] BK-4 The **offer card** gives reasons built from the facts used («Nachtdienst So 22:00–Mo 07:00, 4102 Binningen, 3,4 km · passt: FaGe, Demenzerfahrung bestätigt, frei, kennt diese Einrichtung»). No percentage score. Wording `uxa`.

### Step 3: offer and team decision (best team first, never waiting silently)
- [ ] BK-5 **Offer cascade:** the best-ranked team receives the offer first, on its dashboard, for an **exclusive window**; if it declines or the window ends, the next eligible team receives it, and so on. The window is a parameter per order, shorter when the shift starts soon (default PROPOSED by `eng` in the ADR; not a clinical rule).
- [ ] BK-5a An authorised member takes it with one tap («Übernehmen»); the hard filters run again at that moment; the client sees «gedeckt durch Team …» within seconds.
- [ ] BK-5n No one assigns the order for a team (product invariant, FE-039). A member who no longer meets BK-2 at the tap is refused with the reason; the cascade continues.
- [ ] BK-6 **Not covered stays visible:** the client sees at every moment «Angebot bei Team 1 von 4», «noch nicht gedeckt, Beginn in 2 h 10»; when every eligible team has declined or the shift starts, «nicht gedeckt» is shown to the client and raised as an Operations exception. No silent expiry.

### Step 4: shift and report (`/field`)
- [ ] BK-7 The carer sees the order as her next item (times, place, tags from the order); time is recorded with the existing F1-F4 path, including a shift across midnight.
- [ ] BK-8 Dictation or typed input produces a **draft** report (FE-051 Muster 3 core; Muster 4 only on synthetic data); each sentence traces to the input; nothing invented. The carer reviews, edits and signs; until then no billable fact.
- [ ] BK-8n Only the carer who did the shift signs; an unsigned draft creates no invoice line.

### Step 5: invoice
- [ ] BK-9 After signature, one **invoice draft from the team to the client**: hours × price of the order (synthetic example values, not tariffs); **no NAVORA commission line**; the NAVORA subscription lives in its own ledger.
- [ ] BK-9n Recorded and ordered times disagree → no invoice, visible error; a second invoice for the same order is refused.
- [ ] BK-10 Simulated service invoice only; **no KVG/KLV billing** in BK (D-44, D-18 for later).

### Whole block: synthetic variety (FE-074 (3))
- [ ] BK-11 The seed and the e2e set cover a **scenario matrix**, all synthetic, in BS and BL: at least three fictitious institutions (home, hospital ward, second home) and two private households; shift types früh, spät, nacht (across midnight), Wochenende; levels AGS, FaGe, HF; teams that pass and teams that fail each hard filter. Scenario table in the ADR.
- [ ] BK-12 Acceptance: the e2e set runs every scenario of the matrix through steps 1-5 (and the stop cases of BK-1b, BK-2n, BK-5n, BK-6, BK-8n, BK-9n), green in `ci` and 10/10 in `ci-repeat` on a named commit. Protocol counts human actions per step (AUT-74).

## Rules and their input class
| Rule | Input class | Status |
|---|---|---|
| Field extraction from voice/text | none (client confirms every field) | buildable; AI prepares only |
| PLZ distance within radius | visit/schedule fact | buildable |
| Level allowed for a tag | clinical content (matrix) | **simulation only**, matrix PROPOSED; Clinical Owner before real data (D-27) |
| Required attribute confirmed | care-context fact recorded by a person | buildable; **for the adviser** (it routes) |
| Availability for the whole slot | visit/schedule fact | buildable |
| Ranking among the eligible | schedule fact + confirmed attributes | buildable; ranks only |
| Cascade window | operational parameter | buildable; not a clinical rule |

## AI leverage
1. **Remove:** phone chain, dispatcher, retyping the need, typed reports, manual invoice.
2. **Rules:** BK-2 filters, BK-1c duration, BK-9 arithmetic.
3. **Monitor:** BK-6 cover state until start.
4. **AI prepares:** field extraction (BK-1a), ranking reasons (BK-4), report draft (BK-8). Input synthetic; output class «Entwurf»/«erkannt»; level L/G; stop rule: no source → empty field or no sentence.
5. **Human reviews:** client checks the summary; team reads the card; carer reads the draft.
6. **Human decides:** client confirms the order; team takes it.
7. **Human signs:** carer signs the report.
- Gate: D-35 rule A; synthetic data only. Before real data: AI path D-41 (Muster 4, legal opinion, DSFA), because client free text may carry personal or health data. The AI never adds a team, removes a filter, fills a required field without showing it, confirms an order, signs, or sets a price.

## Out of scope (after BK, FE-073 (4))
B1.1-2 to -5, recurring orders, cancellation and change after confirmation, partial cover, real tariffs and KVG/KLV, payment, payroll, social insurance, contracts and legal form (D-44), real data.

## Dependencies
B1.1 accepted (cut). Builds on J1/J2 (B1), QUAL1 (B2), F1-F4 (B4), F6/F7 (B6). New: client view with capture, order type with shift fields, PLZ list with distances (BS/BL), confirmed attribute, offer cascade, invoice draft to a client.

## Reviews required per PR
`cra` (BK-1c, BK-2, BK-5, BK-6, BK-8), `lca` (BK-1e minimisation, PLZ source and terms, attributes as staff data, invoice wording, D-44 note), `uxa` (client view, summary, card, cascade state, 390 px), `aia` (BK-1a, BK-3, BK-4, BK-8 AI contracts).

## Vision check (FE-070 (7))
1. Direct care time: ≤ 3 admin actions for the carer after a shift. 2. Continuity: ranking prefers a team known to the client. 3. Nurse income: no intermediary margin on the invoice. 4. Team autonomy: the team decides; cascade offers, never assigns. 5. Less administration: one sentence and one tap for the client. 6. Patient outcome: only verified qualifications reach the client; uncovered stays visible. 7. Scalability: one logic for home, hospital and household. 8. Platform: first full chain from client portal to invoice.

## Slices (proposal; `eng` may change in the ADR)
BK-a order type + client form + summary/confirm (no AI) · BK-b PLZ list + hard filters · BK-c ranking + card + cascade + cover state · BK-d AI capture (BK-1a/b) on synthetic data · BK-e `/field` link + report draft · BK-f invoice draft · BK-g scenario matrix seed + whole e2e. One PR each, gates per PR.

## Open questions for engineering
1. Reuse `partner_requests`/cases or a new order type? ADR first.
2. PLZ distance source for BS/BL (`lca` checks terms; synthetic table acceptable for Phase A).
3. How does the cascade relate to today's open search and the «1 Team prüft» signal (FE-072 (4))? Propose; FE-074 (2) wins for BK.
