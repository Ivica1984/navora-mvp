---
id: BK
title: Durchgehender Kern — vom Auftrag bis zur Abrechnung (generisch für Heim, Spital, Privatperson)
author: po
status: approved   # ACTIVE block since 2026-11-13 18:40 CET (B1.1 accepted on 33523a5)
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
- [ ] BK-2 **Hard filters**, deterministic, in the database, before any AI: PLZ distance within the team's maximum travel distance and, if the client set one, within the order's radius (PO amendment 18:40); qualification level allowed for every tag (`QUALIFICATION_MATRIX`, PROPOSED, simulation only); availability for the **whole** slot (including night and weekend); every tag marked «required» held as a **confirmed** attribute. Each excluded team carries its reason.
- [ ] BK-2n A team failing any hard filter is **never** offered, whatever the ranking says (test asserts on offer rows).
- [ ] BK-3 **Ranking** among the eligible only: practice experience, prior knowledge, language (ranking only, not a filter; PO 13:40, FE-073 (3)), continuity with this client, distance. The ranking can reorder, never add. AI ranking runs on synthetic data only (D-35 rule A; FE-051 Muster 1/4).
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

## PO amendment 2026-11-13 13:40 (scheduled PO run): placement of `cra` CGR-204 to CGR-210; language in the ranking

Source: `cra` specification review 2026-11-13 13:30 (`CLINICAL_GOVERNANCE.md`, merged with #1205, `69548c3`). BK is still **not active** (B1.1 first, FE-073). This amendment changes the brief before the BK ADR, so `eng` can take the conditions in; it sets no care rule (D-27), and the matrix stays PROPOSED.

**BK acceptance conditions, gate «Simulation, synthetic data» (PLANNED):**

1. **CGR-204 (a)-(c), per-person eligibility:** BK-2 is read per **member**: a team is eligible only if one and the same member passes level, every required confirmed attribute and availability for the whole slot. «Übernehmen» names that member; the check re-runs for her at the tap and at shift start. The cover state tells «Team hat übernommen, Pflegekraft noch nicht benannt» apart from «gedeckt» (named, checked carer). Negative test: a team whose qualified member is unavailable and whose available member lacks the level is never offered. (d) service area: `eng` proposes in the ADR.
2. **CGR-206 (a)-(d), time basis:** durations and «whole slot» from Europe/Zurich timestamps, never clock-time differences; shift type derived as a set (Saturday night = night and weekend); CGR-200 fixed in BK-e or before BK-7 is accepted; scenario matrix (BK-g) adds a clock-change night and a night with an F3 correction after midnight (pinned clock), asserting order duration, availability, recorded duration and invoice hours.
3. **CGR-207 (a), latest cover time:** no offer window runs past a latest cover time before the start; when the remaining time is shorter, the client sees «nicht gedeckt» and Operations gets the exception **before** the start. The lead-time default is an operational `eng` value (PROPOSED), not a clinical rule.
4. **CGR-208 (a)-(c), no dropped facts (PO places this above the `cra` proposal):** BK-8 shows the source beside the draft; every input segment not used is listed «nicht übernommen» and must be taken in or discarded before signing; the signed version records its input; test with one safety observation and one filler sentence, signing refused until every listed segment is handled. Reason: a fluent draft that silently drops a fall or a refused medication is the patient-safety failure an AI-first report most easily creates; it is testable now with synthetic dictation. `aia` writes it into the BK-8 AI contract.
5. **CGR-209 (b):** the BK acceptance record and the founder demo state that hand-over at the place of care and escalation of an acute event are **not modelled** in Phase A.
6. **UXR-188 with `cra` conditions (1)-(3):** cover state line per server state on each load; «nicht gedeckt» as text, never colour alone.

**Real-data conditions (before «released for real persons and data»), not BK acceptance:** CGR-205 (a)-(e) (level vs tag contradictions shown to the client, «D» cells in a home only with an Einsatzvereinbarung, tags as matrix IDs; PH SRK for an «AGS» order is the Clinical Owner's); CGR-207 (b), (c) (no-start exception, decline log; `eng` may build them in BK if cheap); CGR-208 (d) and CGR-209 (a), (c) (hand-over step, escalation route: Clinical Owner, `lca`, L-7, D-44); CGR-210 (a)-(c) (invoice tied to the signed version; correction voids the draft; no tag on a private invoice unless `lca` says so). If `eng` builds CGR-210 (a), (b) in BK-f, the PO accepts it there.

**Language (`cra` CGR-205 (e), contradiction with FE-073 (3)):** FE-073 (3) names «Sprache» among the profile-matching inputs; BK-3 omitted it. Following `FOUNDER_DECISIONS.md` (README rule 10), BK-3 now reads: ranking among the eligible on practice experience, prior knowledge, **language**, continuity with this client, distance. Language is a **ranking input, not a hard filter**, in Phase A. Whether a missing shared language must exclude a carer (for example on a dementia ward) is a care question: UNKNOWN, Clinical Owner (D-27); until then no hard language filter is built, and the offer card states the language fact it used.

Owners: `eng` (ADR: 1-3, slices), `aia` (4), `uxa` (1 wording, 6), `cra` (gate per PR), `lca` (real-data items). PO status of BK: approved, not active.

## PO amendment 2026-11-13 16:39 (scheduled PO run): `uxa` UXR-191 and UXR-192 as BK acceptance criteria

Source: `uxa` review 16:20 (`UX_REVIEW.md`, merged with #1219), issues #1217 and #1218. Both apply CGR-204 and `lca` M-a to the screens; neither adds a clinical or legal rule. The Blueprint V3.2 wireframes that contradicted them are corrected in V3.2.1 (PO, this run). PLANNED, not built.

- **UXR-191 (BK-c, BK-e):**
  1. Component test: a team whose qualified member is unavailable and whose available member lacks the level renders **no** offer card.
  2. Component test: the «Passt, weil:» line lists only facts true for at least one and the same member.
  3. e2e at 390 px: the primary action is «Übernehmen mit …» and lists eligible members only; without a named member the client status reads «… hat übernommen · Pflegekraft noch nicht benannt» or «noch nicht gedeckt», never «Gedeckt»; «Gedeckt» only after naming. BK-5a («gedeckt durch Team …») is read with this point. Whether the client sees the member's name: `lca` (OPEN); until answered the client line shows no member name.
- **UXR-192 (BK-a capture, BK-1 planner, fixtures):**
  1. `git grep -i krankmeldung -- src tests docs/product/blueprint-v3` returns only rule texts that forbid it; no fixture, placeholder, hint or sample carries an absence reason.
  2. Component test: the planner's absence row renders no reason field. Unit test: a «Krankmeldung» segment in a capture is listed as unused («nicht übernommen», CGR-208) and is not written to the order.

Owners: `eng` (tests), `uxa` (wording, gate), `lca` (member name to client). PO status of BK: approved, not active (B1.1 acceptance first).

## PO amendment 2026-11-13 18:40 (scheduled PO run): BK active; answers to the two `po` OPEN items in ADR-191 and ADR-193 (#1228)

**BK is the active block from now** (B1.1 accepted on `33523a5`, `briefs/B1.1.md` §PO 18:40). Feature PRs merge in slice order BK-a, b, c, e, f, d, g; BK-a first. This amendment decides two operational WHAT questions that `eng` left to the PO; it sets no clinical, legal or tariff rule.

1. **Radius (ADR-191 decision 1, ADR-193 decision 4): no NAVORA-wide default.** Phase A, simulation only:
   - (a) The **team** sets its own maximum travel distance (km) together with its service postcodes (`team_service_postcodes`, ADR-193 (3)); it is set and changed by the team (or an organisation `admin` in the seed), with audit. Reason: value 4 (team autonomy); the team carries the travel time; a central default would be dispatching in disguise (challenge row 18:40).
   - (b) The client **may** narrow the distance per order (optional field, empty by default); the client is never asked for a radius to send an order.
   - (c) The hard filter (BK-2) uses the **smaller** of the team's maximum and the order's optional radius; an order without radius uses the team's maximum. A team without service postcode or without maximum distance is excluded with its reason (`no_service_area`), never included by default. **BK-2 now reads:** «PLZ distance within the team's maximum travel distance and, if the client set one, within the order's radius».
   - (d) Red tests (BK-b): an order without radius reaches a team whose maximum covers the distance; the same order does not reach a team whose maximum is 1 km short; a client radius smaller than the team's maximum excludes the team; a team without maximum gets no offer row and carries its reason.
   - (e) Not decided here: whether distance is a safety concern for timely arrival in an urgent order (`cra`, advisory), and P-5 wording (`lca`). Synthetic values only.
2. **Shift-type boundaries (ADR-191 decision 4): NAVORA sets no clock definition.**
   - (a) The binding facts of an order are its exact start and end (Europe/Zurich, CGR-206). Hard filters, availability, the cascade and the invoice use these, **never** the shift-type label.
   - (b) The label (früh, spät, nacht, Wochenende, as a set) comes from the **client's own shift plan** (start/end per label, per client account). In Phase A the seed holds one synthetic shift plan per synthetic client, marked `synthetic`; the extraction (BK-1a, BK-d) may propose a label only by matching the stated times to that plan, and shows it as «erkannt».
   - (c) A time that matches no label of the client's plan shows no label and asks nothing extra; the order is still valid. Weekend = start or end on Saturday or Sunday (calendar fact, not a rule).
   - (d) Red tests (BK-a/BK-d): an order 22:00–07:00 is valid and one row whether or not a label matches; changing a client's shift plan never changes any team's eligibility for an existing order.
   - (e) OPEN for `lca` (BK-f, before any invoice line uses it): whether night and Sunday surcharges and the ArG night-work definition apply to a team's invoice in the chosen legal structure (D-44). Until answered, the invoice draft shows no surcharge.

Owners: `eng` (ADR-191, ADR-193 text to follow these answers; schema HOW), `uxa` (radius field wording, label display), `cra` (1 (e), advisory), `lca` (1 (e), 2 (e)). PO status of BK: **active**.

## PO amendment 2026-11-13 20:40 (scheduled PO run): AUT-117 to AUT-120, UXR-190, UXR-195 to UXR-197 placed

Sources: `aia` review 54 (#1236, merged `b2f43b0`), `uxa` review 20:00 (#1234, merged `e713989`), issues #1232, #1233, #1235. BK stays the only active block, slice order unchanged (a, b, c, e, f, d, g). This amendment decides operational WHAT questions only; it sets no clinical, legal or tariff rule (D-27), and the matrix stays PROPOSED. Everything below is PLANNED, nothing built.

1. **AUT-117 (#1235, high): the team sets its own reach.** This applies the PO amendment 18:40 (1)(a); ADR-193 (3)/(4) («set by an organisation `admin`») contradicts it, and the newer PO text wins (README rule 10). `eng` aligns the ADR text in the BK-b ADR or PR.
   - (a) One audited command for the team's service postcodes and maximum distance, callable by an **active member of that team**; an organisation `admin` only for the seed and for a team without active members. Postcodes only from `postcodes` (P-8); distance > 0. No approval step, no new role.
   - (b) A change applies to new offers only; an offer row already written is not altered or withdrawn silently.
   - (c) The team view shows its reach with the date of the last change; a team without reach sees in words that it receives no orders, and the action to set it.
   - (d) Tests (BK-b, red first): pgTAP: a member of team A sets A's reach; a member of team B cannot set A's; an admin can; every change writes an audit row with old and new values; a reach change leaves an existing offer row unchanged. Scenario matrix: teams excluded `no_service_area` / `no_max_distance` after seed setup = 0; reach changes counted by team act vs admin act **per team, never per person**.
   - (e) Gates: `lca` (P-5: the reach is the team's area, never a member's home address; who may set it), `eng` (HOW).
2. **AUT-119 (medium): price, direction for BK-f; replaces the PO hypothesis of 19:40.**
   - (a) **BK-a builds no price column set by the client.** The `price_per_hour` on the client's order row in ADR-191 (1) is not built in BK-a; pricing is BK-f.
   - (b) Direction for the BK-f ADR (mirrors the radius answer): the team keeps a standing price per hour (team-set, audited, synthetic example value, never a NAVORA reference value); the client may set an optional ceiling per order (empty by default), and a team above it is excluded with its reason; at «Übernehmen» the team's price is copied onto the accepted offer (snapshot), so the client confirms nothing after the take. A per-order deviation is only possible **before** the take and is shown to the client as a new offer state.
   - (c) OPEN before BK-f: `lca` (price setting by self-employed teams, competition questions, W-7 labelling); the founder question «keine Zahlungsflüsse über NAVORA» (Blueprint ch. 11). Measure: time from «Übernehmen» to «gedeckt» unchanged by pricing.
3. **AUT-120 (low) into BK-a:** the preview fills a concrete date only when the words admit exactly one; otherwise it returns `relative_date_ambiguous` with both candidates for the client to pick. Test: on a Sunday fixture «Sonntag» returns two candidates; on a Wednesday one date; the confirmed row never carries a date the client did not see. Gates `cra` (CGR-200, CGR-206), `uxa` (pick wording).
4. **UXR-196 (medium) into BK-a:** the built order sentence uses the form's labels, never a code or an ISO date, e.g. «Schichtauftrag · FaGe · So 22.11.2026 22:00 – Mo 23.11.2026 07:00 (9 Std.) · 4102 Binningen» (synthetic). Test: the sentence for the 22:00–07:00 fixture equals the expected string and contains no `_`. P-7: `lca`.
5. **UXR-197 (medium) into BK-a, at 390 and 1440 px:** a matching label reads «Nacht · aus Ihrem Dienstplan»; with no matching label the summary shows the time line and **no** label line and no «keine Bezeichnung» (PO 18:40 (2)(c) stands over ADR-191 risk (c)), and «Bestätigen & Absenden» stays enabled; the radius field is empty by default and the summary reads «Distanz: keine Vorgabe». Radius words: `lca` (P-5).
6. **UXR-195 (#1233, high) and AUT-118 into BK-8 / BK-e:**
   - (a) **No time cap** on the report input. BK-8 at stage 0 is a rule over text; NAVORA receives and stores **no audio** in BK (catalogue test: no audio column or bucket in BK migrations).
   - (b) «Nicht übernommen (n)» above the sign button, one item per unused segment, with «Einfügen» and «Bewusst weglassen»; the draft shows its origin («regelbasiert, keine KI · synthetische Daten»).
   - (c) Two proposals differ: `uxa` (sign button disabled while n > 0) and `aia` (an unhandled segment defaults into the report; removal is an audited act). Either keeps the guarantee «nothing dictated is dropped without a decision». **`cra` decides** at the BK-e gate (CGR-213 (b)); the PO sets no documentation rule. Shared test, either way: 40 input segments → 40 placed or listed, none lost.
   - (d) Blueprint V3.2.5 §5.3 and `field.svg` (text) are corrected; the drawing of the block, a text input instead of a recording, and the PNG are `uxa`'s (#1233).
7. **UXR-190 (#1232, high, `cra` CGR-212) into BK-e, first criterion of that slice.** README rule 12 allows a separately named safety fix only while **no** block is active; with BK active a non-BK feature merge would compete with it. Phase A has no real persons, so no patient is exposed now; the defect still hides a safety signal in the simulation (every seed visit has a postcode and no street). BK-e touches `/field` anyway. Criterion: with an empty street and a postcode, the card shows «4052 Basel · Strasse fehlt – im Team klären» as text (not colour alone); unchanged when the street exists or everything is empty. Tests: unit test on the place builder for the three cases; e2e at 390 px: a seed visit without a street shows «Strasse fehlt», no horizontal scroll. **No release for real data without it.** Whether a visit without a street may be planned at all: OPEN for `cra` (advisory) and the DOOR1 intake; not decided here.

Owners: `eng` (ADR-193 text, tests), `uxa` (wording, P3 drawing), `cra` (6 (c), 7), `lca` (1 (e), 2 (c), 4, 5), `aia` (measures). PO status of BK: **active**.

## PO amendment 2026-11-13 21:39 (scheduled PO run): CGR-214 to CGR-216, CGR-206 (d), BK-8 variant

Sources: `cra` review 21:40 (#1239, merged `eb46681`), PR #1238 (BK-a, heads `3d9fb98` and `f6fdcaf`). BK stays the only active block, slice order unchanged (a, b, c, e, f, d, g). This amendment decides operational WHAT only; it sets no clinical, legal or tariff rule (D-27), and the matrix stays PROPOSED. Everything below is PLANNED unless marked otherwise.

1. **CGR-214 (blocking for #1238): merge condition of BK-a.** #1238 is merged only when the `partner_requests` audit trigger keeps every column it audited before 0129 (including `urgency_source` and `referrer_requested_start`, 0086:225), pgTAP 086 is green, and the guards 068 (DST1), 074 (LEAVE1) and 077 (AUD1) are green **without** any guard or assertion loosened. `eng` pushed `f6fdcaf` («audit list of 0086 kept», LEAVE1-3 guard, `private.at_zurich`, no `audit_events` read); CI was running at this run. PO_MERGE_PROCESS §4 (2), AUT-50: `cra` reads the new head and writes a gate line before the PO merges.
2. **CGR-206 (d) into BK-a (PO choice over «at the latest BK-g»):** BK-a is the slice that computes and stores the order's duration, so its tests carry the clock-change cases. pgTAP 135 (or a sibling file) asserts: night Sat 30.10.2027 22:00 – Sun 31.10.2027 07:00 = 600 min, sentence «(10 Std.)»; night Sat 27.03.2027 22:00 – Sun 28.03.2027 07:00 = 480 min, «(8 Std.)»; a start of 02:30 on 28.03.2027 is shown as 03:30 in the preview **before** confirmation, never shifted silently. Dates are calendar facts, not rules. If `cra` clears #1238 for the simulation without these, they are added in the next BK-a PR before the BK-a acceptance; the acceptance record names them.
3. **CGR-215 placed:**
   - (a) BK-a acceptance gate is «Simulation, synthetic data» only; no release for real persons before BK-c offers and the BK-6 exception exist.
   - (b) BK-c criterion (red test): an order confirmed before the BK-c migration is offered or raised as an Operations exception; none stays «noch nicht gedeckt» with no team and no exception.
   - (c) BK-c criterion: client orders in the exception list are ordered by time to start (CGR-207 (a)), never hidden or placed last because urgency is empty; test with an order starting in 2 h.
   - (d) BK-a (if not in #1238, the next BK-a PR): the intake list never drops a row silently for missing urgency; it shows «Dringlichkeit fehlt» or logs an error event; unit test.
4. **CGR-216 placed as a BK-b criterion** (before BK-b is accepted): the preview returns `level_activity_conflict` naming the activity when the matrix cell for the chosen level is «–» or «?», and confirm refuses it; pgTAP with a synthetic AGS order carrying an activity whose cell is «–» → refused with the activity named. No mapping from a higher to a lower level in code (CGR-205 (d)). The matrix stays PROPOSED; the cells are not set by the PO.
5. **BK-8 «Nicht übernommen (n)»: the `uxa` variant is the build target for the simulation gate.** Correction of amendment 20:40 (6)(c): I wrote «`cra` decides»; `cra` is a review role (D-27) and gave a review position, not a decision. The PO decides the product behaviour for Phase A on that review position: the sign button stays disabled while n > 0. Conditions (from `cra` 21:40 answer 1): (i) no bulk action («alle weglassen» or similar); (ii) «Bewusst weglassen» is one audited act per segment, and the discarded text stays in the signed version's input record (CGR-208 (c)); (iii) `aia` measures discarded segments per report, counted per team, never per person; (iv) shared test: 40 segments in, 40 placed or listed, none lost, signing refused while one is unhandled. **Before real data the Clinical Owner confirms or replaces this (D-27); OPEN.** The `aia` default-in proposal is recorded as considered and not chosen (reason: a default places text the carer did not read in context under her signature).
6. **Not decided here:** whether reference data (the BS/BL postcode list) may stay readable after access ends (LEAVE1, `lca`); `eng` chose the tighter guard on `f6fdcaf`, which the PO accepts as the default until `lca` answers. Street-less home visits and a distance threshold: UNKNOWN, Clinical Owner (`cra` 21:40 answers 2 and 3); no NAVORA default.

Owners: `eng` (1, 2, 3 (d), 4), `cra` (gate line on the new #1238 head), `uxa` (5 wording, #1233), `aia` (5 (iii)), `lca` (6). PO status of BK: **active**.
