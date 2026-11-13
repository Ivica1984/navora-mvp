---
id: BK
title: Durchgehender Kern «Schichtauftrag Heim» (Referenzfall 4052 Basel, Spätschicht Demenz)
author: po
status: approved   # starts as active block when B1.1 (cut to B1.1-1 … B1.1-1c) is accepted
updated: 2026-11-13
---

# BK — Durchgehender Kern «Schichtauftrag Heim»

Founder decision **FE-073** (2026-11-13). Phase A only: **simulation, synthetic data.** No release for real persons and data.

## Problem
A nursing home that loses a shift at 14:15 for 16:30 today phones staffing agencies. The agency charges about 75 CHF/h and passes about 28 CHF/h to the carer (founder figures, illustrative, not verified). NAVORA has most parts of the chain (referral, matching, team decision, `/field`, report signature), but **no single path** carries one shift order from the home to an invoice, and the parts that make it valuable (PLZ distance, a verified experience attribute, an offer card that explains itself, dictation, an invoice to the home) do not exist yet. The PO has been spending blocks on legacy data instead of the chain (FE-073).

## Users and views
- **Heim (Referral/Client Portal, B2B):** the person on the ward who enters the need and sees whether it is covered.
- **Team (Team Portal):** the self-organised team that gets the offer and decides; an authorised member accepts.
- **Pflegekraft (`/field`):** carries out the shift, records time, dictates, signs.
- **NAVORA operator:** sees nothing of the content; sees only that the chain ran (counts).
- Not involved: Operations as dispatcher (no step in the happy path), coach, relatives.

## Reference scenario (seeded, synthetic)
- Synthetic nursing home in **PLZ 4052 Basel** (synthetic name, not a real institution), ward «Demenz».
- Need entered at 14:15 for **16:30–21:30 (5 h)**, level **AGS / SRK-Pflegehelfer:in**, tags `Grundpflege`, `Demenzerfahrung`, `Abendmobilisation`.
- Synthetic teams: «Basel Ost» (one member «Sara M.» with level AGS and a **confirmed** dementia-experience attribute, free that evening), a second team nearer but without the attribute, a third team with the attribute but busy, a fourth team outside the distance.
- Price in the order: **52 CHF/h**, a synthetic example value set by the order, not a tariff.

## Outcome
On one named commit, an e2e test drives the reference scenario through all five steps on 390 px and 1440 px, and every hard rule visibly stops the wrong match.

## Acceptance criteria
**Step 1 — Bedarf erfassen (Heim)**
- [ ] BK-1 The home enters a shift order with place of care **PLZ** (from the BS/BL list), date, start and end, qualification level, activity tags, price per hour; nothing else is required. Postcode outside the list is refused with a reason.
- [ ] BK-1n A team member cannot create a shift order for a home; a home cannot see another home's orders.

**Step 2 — Prüfen und Empfehlen (deterministic first, then AI)**
- [ ] BK-2 Hard filters, deterministic, in the database: PLZ distance within the order's radius, qualification level allowed for the tags (QUALIFICATION_MATRIX, PROPOSED, simulation only), availability in the slot, and every tag marked «required» held as a **confirmed** attribute. Each excluded team carries its reason.
- [ ] BK-2n The «nearer team without the attribute» and the «busy team» and the «team outside the distance» are **never** offered, whatever the ranking says (test asserts on the offer rows, not on the UI).
- [ ] BK-3 Among the eligible, a ranking orders the offers (experience, continuity with this home, language, distance). The ranking can only reorder eligible teams; it can add none. Ranking runs on synthetic data; no client or staff data leave NAVORA (D-35 rule A, FE-051 Muster 1/4).
- [ ] BK-4 The offer card says **why** in plain words, built from the facts used: «Spätschicht 16:30–21:30, Demenzabteilung, 4052 Basel, 2,1 km · passt: AGS, Demenzerfahrung bestätigt (Sara M.), frei». No percentage score (a number reads as a guarantee; the guarantee is the hard filter). Wording `uxa`.

**Step 3 — Teamentscheid**
- [ ] BK-5 The team sees the offer on its dashboard; an authorised member takes it with one tap («Schicht übernehmen»); the automatic rule check (BK-2) runs again at that moment; the home sees «Schicht gedeckt durch Team Basel Ost» within seconds.
- [ ] BK-5n No one assigns the shift for the team (product invariant, FE-039). A member who no longer meets BK-2 at the tap is refused with the reason, and the offer stays open.
- [ ] BK-6 **Not covered stays visible:** while no team has taken it, the home sees «noch nicht gedeckt» with the time to shift start; at shift start without a team the order shows «nicht gedeckt» to the home. No silent expiry. (This is core, not a special case: a dementia ward without cover must know it.)

**Step 4 — Einsatz und Bericht (`/field`)**
- [ ] BK-7 Sara sees the shift as her next item; start, end, and the activity list come from the order; time is recorded with the existing F1-F4 path.
- [ ] BK-8 Dictation or typed input after the shift produces a **draft** report (FE-051: Muster 3 structured/rule-based is the core path; Muster 4 own model only on synthetic data). The draft names its source text; nothing is invented. Sara reviews, edits, and signs («Freigeben & Signieren»); until then the report is a draft and no billable fact exists.
- [ ] BK-8n A draft can never be signed by anyone but the carer who did the shift; an unsigned draft creates no invoice line.

**Step 5 — Abrechnung**
- [ ] BK-9 After signature, one **invoice draft to the home**: 5.0 h × 52.00 CHF = 260.00 CHF, issued by the team; **no NAVORA commission line** (FE subscription model). The NAVORA subscription lives in its own ledger and never appears on the care invoice (revenue separation).
- [ ] BK-9n Recorded time and order time disagree → no invoice, visible error (existing VIS2/F3 facts); a second invoice for the same shift is refused.
- [ ] BK-10 Simulated B2B service invoice only; **no KVG/KLV billing** in BK (whether and how an external team's shift in a home is billed is `lca` D-44 territory).

**Whole block**
- [ ] BK-11 One e2e test runs steps 1-5 on the reference scenario, green in `ci` and 10/10 in `ci-repeat` on a named commit; the protocol counts human actions per step (AUT-74): target ≤ 1 action for the home, 1 for the team, ≤ 3 for the carer after the shift.

## Rules and their input class
| Rule | Input class | Status |
|---|---|---|
| PLZ distance within radius | visit/schedule fact | buildable |
| Qualification level allowed for an activity tag | clinical content (matrix) | **simulation only**, QUALIFICATION_MATRIX v0.1 PROPOSED; Clinical Owner before real data (D-27) |
| Required attribute must be confirmed | care-context fact recorded by a person | buildable; marked **for the adviser** (it routes) |
| Availability in the slot | visit/schedule fact | buildable |
| Ranking among the eligible | visit/schedule fact + confirmed attributes | buildable; ranks only |

## AI leverage
1. **Remove:** phoning agencies, dispatching, typing a report from scratch, writing an invoice.
2. **Rules:** BK-2 hard filters, BK-9 invoice arithmetic.
3. **Monitor:** BK-6 cover state until shift start.
4. **AI prepares:** ranking explanation (BK-4) and report draft (BK-8); input = synthetic order and profile facts; output = text field class «Entwurf»; level L/G; stop rule: no source → no sentence.
5. **Human reviews:** the team reads the card; the carer reads the draft.
6. **Human decides:** the team takes the shift.
7. **Human signs:** the carer signs the report.
- Gate: D-35 rule A stays; synthetic data only. The AI never adds a team, never removes a hard filter, never signs, never sets a price.

## Out of scope (after BK, FE-073 (4))
Rejection with reason by Operations (B1.1-2), deadline exceptions (B1.1-3), status-line variants (B1.1-4), requester vs. entering role (B1.1-5), hospital and private-person orders, recurring shifts, cancellation by the home, partial shifts, real tariffs, KVG/KLV billing, payment, payroll, social insurance, contracts and legal form (D-44), real data.

## Dependencies
B1.1 accepted (cut: B1.1-1, #1181, #1184, B1.1-1c). Builds on J1/J2 (B1), QUAL1 (B2), F1-F4 (B4), F6/F7 (B6). New: shift order type, PLZ list with distances for BS/BL, confirmed attribute, invoice draft to a home.

## Reviews required per PR
`cra` (BK-2, BK-6, BK-8: safety and documentation), `lca` (PLZ data source and terms, attribute as staff data, invoice wording, D-44 note), `uxa` (BK-1, BK-4, BK-5, BK-6, BK-8 texts and 390 px), `aia` (BK-3, BK-4, BK-8 AI contract).

## Vision check (FE-070 (7))
1. Direct care time: carer spends ≤ 3 actions on admin after the shift. 2. Continuity: ranking prefers a team that already knows the home. 3. Nurse income: no intermediary margin on the invoice. 4. Team autonomy: the team decides, no assignment. 5. Less administration: no phone chain, no typed report, no manual invoice. 6. Patient outcome: only verified dementia experience reaches the ward; uncovered stays visible. 7. Scalability: same path for hospital and private orders later. 8. Platform: first full chain from client portal to invoice.

## Open questions for engineering
1. Slice proposal: BK-a order + PLZ list + hard filters (steps 1-2 without AI); BK-b offer card, team decision, cover state (steps 2-3); BK-c `/field` link and report draft (step 4); BK-d invoice draft (step 5); BK-e whole e2e. One PR each.
2. Which existing tables carry a shift order (reuse `partner_requests` / cases, or a new order type)? ADR first.
3. Source for PLZ distances in BS/BL (synthetic table vs. public geodata; `lca` checks terms; for an institution the PLZ is the home's business address, not a client's data).
