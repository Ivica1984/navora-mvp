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
- [ ] BK-5 **[SUPERSEDED 2026-11-14 by FE-078 part 2 (broadcast to every team that passes every hard check, no exclusive window): read PO amendment 2026-11-14 15:00 (1) below and the single BK-5 template `docs/design/BK5_OFFER_TEMPLATE.md`; marker added by `uxa` 2026-11-14 on founder instruction, wording below kept as history]** ~~**Offer cascade:** the best-ranked team receives the offer first, on its dashboard, for an **exclusive window**; if it declines or the window ends, the next eligible team receives it, and so on. The window is a parameter per order, shorter when the shift starts soon (default PROPOSED by `eng` in the ADR; not a clinical rule).~~
- [ ] BK-5a An authorised member takes it with one tap («Übernehmen»); the hard filters run again at that moment; the client sees «gedeckt durch Team …» within seconds.
- [ ] BK-5n No one assigns the order for a team (product invariant, FE-039). A member who no longer meets BK-2 at the tap is refused with the reason; the cascade continues **[read: the broadcast continues; FE-078 part 2]**.
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
BK-a order type + client form + summary/confirm (no AI) · BK-b PLZ list + hard filters · BK-c ranking + card + cascade **[broadcast since FE-078 part 2]** + cover state · BK-d AI capture (BK-1a/b) on synthetic data · BK-e `/field` link + report draft · BK-f invoice draft · BK-g scenario matrix seed + whole e2e. One PR each, gates per PR.

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

## PO amendment 2026-11-14 00:39 (scheduled PO run): UXR-198 to UXR-203 and `lca` G-1 to G-6 placed

Sources: `uxa` review 23:48 (#1243, merged `aab0d48`), `lca` D-44 section 00:20 (#1244, merged `e9acb2a`), PR #1238 head `45e07db` (`uxa` gate clear, `lca` advisory gate clear; the `cra` gate line is still missing, CGR-214). BK stays the only active block, slice order unchanged (a, b, c, e, f, d, g). This amendment decides operational WHAT only; it sets no clinical, legal or tariff rule (D-27), and the matrix stays PROPOSED. Everything below is PLANNED unless marked otherwise. None of it is a merge condition of #1238.

1. **BK-a acceptance criteria (next BK-a PR after #1238, before the BK-a acceptance record):**
   - (a) **UXR-199:** after «Bestätigen & Absenden» the form is cleared and focus moves to a confirmation block naming the order; a second press on the same filled form never creates a second order. Test (e2e or unit, red first): send, then send again without new input → exactly one order. Reason (value order 2, continuity): a duplicate order would ask two teams for one shift.
   - (b) **UXR-198:** the client's menu has a destination for `/order` (`nav.ts` `menuItemsFor`); test: a client-only user sees the entry, a team member without client account does not.
   - (c) **UXR-200:** each problem is also shown at its field (`aria-describedby`), not only on the summary.
   - (d) **UXR-201 (low):** «Datum nicht erkannt» is announced on leaving the field, not while typing; in the same PR if small, otherwise BK-g.
2. **UXR-202 waits for `cra`:** whether «Dringlichkeit fehlt» needs its own colour (not the grey of «niedrig») is a safety-signal question; `cra` confirms or rejects, then it goes into the next BK-a PR. OPEN.
3. **BK-b criteria:** `lca` G-4 (a)-(c): the team reach is stored as the team's area (postcodes or a base postcode plus km), never a member's address, never GPS; setter recorded as actor. UXR-203: the radius hint appears in the client form; wording as proposed in G-4, `uxa` owns the words.
4. **BK-c criteria (from `lca` G-2, G-3, G-6):**
   - (a) G-2 (i), (ii): for a household order no street, contact or `activity_tags` key is an audited key of class `code`; catalogue assertion in pgTAP 077.
   - (b) G-3 (2): the offer read model for a household order returns no `partner_name` before «Übernehmen»; test.
   - (c) G-3 (1): any command that changes start, end, level or postcode rebuilds the order sentence in the same transaction; test (change → sentence equals a fresh build). Applies to whichever slice first adds such a command.
   - (d) G-6 role separation: a person who is client in one network and team member in another sees, as client, none of the other network's team-side data, and the reverse; test.
   - (e) G-5: in the simulation the client line may show the named member's first name and surname under `lca` (a)-(e) (only after «Übernehmen», only that order, no other personal fields). **Real use: unresolved, needs the owner (L-11 legal form, privacy notice text).** OPEN.
5. **LEAVE1 (amendment 21:39 (6)) closed:** `lca` G-1 recommends keeping the uniform guard; the PO keeps it (074 not loosened).
6. **Least privilege on global configuration rows (`lca` G-6 first point):** product choice, not a legal blocker. PO direction: before Phase B (real external clients), a client-only user reads no tariff, billing or exception configuration rows; `eng` proposes the change in an ADR at BK-f at the latest. PLANNED.

Owners: `eng` (1, 3, 4, 6), `cra` (2, gate line on #1238), `uxa` (1 and 3 wording), `lca` (4 (e) real use with the owner). PO status of BK: **active**.

## PO amendment 2026-11-14 01:39 (scheduled PO run): #1238 merged; CGR-214 (b), CGR-217, UXR-202 placed

Sources: `cra` 01:35 (#1247, merged `fb388f1`; the near-identical 01:30 run #1248 is not merged, overlap), `cra-gate: #1238 45e07db clear` (Simulation, synthetic data), PR #1238 merged `abd6f82` (head `45e07db`), PR #1246 (retargeted to `recovery/main`, draft). BK stays the only active block; slice order unchanged (a, b, c, e, f, d, g). Operational WHAT only; no clinical, legal or tariff rule is set here (D-27); the matrix stays PROPOSED. Everything below is PLANNED unless marked otherwise.

1. **IMPLEMENTED (merged, not accepted):** BK-a first PR #1238 on `recovery/main` as `abd6f82`. BK-a is **not** accepted until (a) CI on the merge commit is green (met: run 43535200821, 4/4 `success`), (b) the BK-a follow-up criteria below and of amendment 00:39 (1) are merged, and (c) `ci-repeat` 10/10 (`db`, `e2e`) on a named integrated commit (README rule 12 (4)). Gate of the acceptance: «Simulation, synthetic data».
2. **BK-a acceptance criterion, CGR-214 (b):** one pgTAP assertion that an intake request with a referrer date writes `changed -> 'referrer_requested_start'` to the `partner_requests` audit (or a catalogue assertion that the trigger list contains every column of 0086:225). In #1246 or the next BK-a PR; regression guard, green on first run is acceptable and must be stated as such.
3. **BK-a acceptance criterion, UXR-202, on `cra`'s review position (01:35):** «Dringlichkeit fehlt» looks different from every stored level (outlined badge, dark text, the words «Dringlichkeit fehlt»), **not red** (red stays for safety signals, UX1-23), and the list order stays by arrival (no invented priority). Test: vitest that `urgencyBadgeClass(null)` differs from the class of each of the four levels and the badge text is «Dringlichkeit fehlt». Closes the OPEN of amendment 00:39 (2).
4. **CGR-217 into BK-b (advisory, S3):** `preview_client_order` returns an **information item, never a block**, when the same client account already has a confirmed order with the same start, end, level and postcode; the summary names it in words (`uxa` owns the words). pgTAP on the preview (positive: same order → item; negative: a different postcode or start → no item; a second order stays confirmable). Reason (value order 2, continuity; patient safety precondition): two teams asked for one shift wastes care time; two staff for one shift can be correct, so NAVORA informs and never forbids. Not a condition for #1246.
5. **#1246 scope stays UXR-198 and UXR-199.** UXR-200, UXR-201, 2 and 3 above may join #1246 before its gates or follow in one more BK-a PR; `eng` decides HOW. Gates for #1246 on its retargeted head: `cra` (duplicate-order path), `uxa`, `lca` (own-rows read).

Owners: `eng` (2, 3, 4, 5), `uxa` (4 wording), `cra` (gate on #1246). PO status of BK: **active**.

## PO amendment 2026-11-14 02:39 (scheduled PO run): `aia` AUT-121 and AUT-122 placed

Sources: `aia` review 55 (#1250, merged `c153cde`). BK stays the only active block; slice order unchanged (a, b, c, e, f, d, g). Operational WHAT only; no clinical, legal or tariff rule is set here (D-27); the matrix stays PROPOSED. Everything below is PLANNED.

1. **AUT-121 (low) into BK-g, optional earlier:** relative date words («heute», «morgen», «übermorgen», a weekday) are resolved against the Zurich date at the summary step, not at page load; when the two dates differ, the summary adds one line that the date was recalculated (`uxa` owns the words). Test: unit test with an injected clock (loaded 23:50 on D, resolved 00:10 on D+1 → «morgen» = D+2 plus the line; resolved on D → D+1, no line). **Not** a BK-a acceptance criterion: the summary already shows the concrete date and `starts_in_past` refuses a past start, so nothing is stored silently. `eng` may add it to a BK-a PR if it is small.
2. **AUT-122 (medium) as a binding criterion for every BK measure built from audit rows (BK-b reach changes, BK-8 «Bewusst weglassen», BK-g):** (a) the measure view or function returns no actor or member column (count by team and period only); (b) a team row is shown only for a team with at least *k* active members in the period, otherwise the figure is rolled into the organisation value; (c) *k* is a data-protection value set by `lca` (UNKNOWN); until it is set, **no team row of the BK-8 «weglassen» measure is shown on any screen** (CI scenario assertions without a screen are allowed). Tests: catalogue/pgTAP that the measure has no actor column; seed team with 1 active member → no team row, organisation total includes it. Reason: hard rule «no per-person performance view»; a team of one is a person.
3. **To `lca`:** set *k* (P-5/P-7 context) before the first measure screen; answer in an `lca` report row.

Owners: `eng` (1, 2), `uxa` (1 wording), `lca` (3). PO status of BK: **active**.

## PO amendment 2026-11-14 04:39 (scheduled PO run): `lca` K-1 to K-7 adopted for Phase A; UXR-204 to UXR-207 placed

Sources: `lca` D-44 section 04:20 (#1255, merged `81c2819`), `uxa` review 03:47 (#1254, merged `37c07ca`). BK stays the only active block; slice order unchanged (a, b, c, e, f, d, g). Operational WHAT only; no clinical, legal or tariff rule is set here (D-27); the matrix stays PROPOSED. Everything below is PLANNED.

1. **AUT-122, *k* adopted for Phase A only (gate «Simulation, synthetic data»):** the PO adopts `lca` K-1 to K-7 with k = 5 as product behaviour for every BK measure built from audit rows. This replaces 02:39 (2)(b) «at least *k* active members» by «at least 5 distinct **contributors** to the counted events in the period» (K-1), and adds: dominance, one person with 50 % or more of the events withholds the row (K-2); no recalculation from the organisation total (K-3); fixed calendar periods only, no free or sliding range (K-4); the team sees its own row, an organisation administrator only under K-1 to K-4, nobody outside the organisation (K-5); reach-change counts (AUT-117) may stay per team without K-1 to K-3 provided no actor column and no change text (K-6); *k* and the 50 % share as one configured constant (K-7). Tests: as listed in D-44 04:20 under K-7, in BK-b (reach changes) and BK-g (measures). 02:39 (2)(a) (no actor column) stays. `lca`'s role note is followed: `lca` proposed, the PO adopts for Phase A. **Not decided, OPEN for the owner before real data:** confirm k = 5 and 50 % (or stricter) and the privacy-notice sentence that team measures never appraise a person; any reader outside the team needs the legal-adviser question added to Q-44a. Reason (value order 4, team autonomy): a team learns from its own figures without them turning into a per-person monitor.
2. **UXR-204 (medium) as a BK-a acceptance criterion** (next BK-a PR after #1252, before the BK-a acceptance record): on the phone a client-account member with no organisation role has «Auftrag erfassen» (`order`) as her home tab; a tab bar with no tab and only «Mehr» is never shown. Test: unit test in `ux2-shell.test.ts`, `shellItemsFor({ roles: [], inTeam: false, clientAccount: true }).tabs` equals `["order"]`, staff cases unchanged. Tab word «Auftrag erfassen» (one label per destination, UX2-32); `uxa` may shorten it in its next review. Reason (value order 5, less administration): the client's only task must be one tap away.
3. **UXR-205, UXR-206, UXR-207 (low):** in #1252 if `eng` takes them before the gates, otherwise BK-g. Not a merge condition of #1252 and not a BK-a acceptance criterion.
4. **Words placed (PROPOSED, `uxa` 03:47):** the CGR-217 information item text for BK-b and the AUT-121 recalculation line for BK-g, as written in `UX_REVIEW.md` 03:47. `cra` may read the CGR-217 text; it is not a safety signal.

Owners: `eng` (1 tests in BK-b/BK-g, 2, 3), `uxa` (2 tab word), `lca` (Q-44a candidate), owner (1 OPEN before real data). PO status of BK: **active**.

## PO amendment 2026-11-14 08:39 (scheduled PO run): #1257 merged; AUT-123, AUT-124, UXR-208 placed

Sources: `aia` review 56 (#1263, merged `79ef9aa`), `uxa` review 07:48 (#1262, merged `bada97a`). BK stays the only active block; slice order unchanged (a, b, c, e, f, d, g). Operational WHAT only; no clinical, legal or tariff rule is set here (D-27). Everything below is PLANNED unless marked.

1. **UXR-204 IMPLEMENTED:** #1257 merged as `634ccb7` (head `8d92bfc`; `cra` clear on `d9d142d`, diff to head empty for `src supabase tests e2e .github` (AUT-50); `uxa` clear on `8d92bfc`). With it every BK-a criterion of the amendments 00:39, 01:39 and 04:39 (2) is merged. BK-a stays **merged, not accepted** until `ci` on `634ccb7` and `ci-repeat` 10/10 (`repeat/bk-a-accept-634ccb7`, started 08:45) are read from raw job logs.
2. **AUT-123 «Wieder erfassen» (medium), candidate for BK-g, not yet a criterion:** on an order in the client's own list, «Wieder erfassen» opens `/order` prefilled with times, postcode, grade, activities, required activities and radius; **the date is never copied**; the copy passes the same preview, summary and single «Bestätigen & Absenden» as a fresh order, and `confirm_client_order` re-checks every field. Not a recurring order (no order is created without the client's act; series stay out of BK scope). It becomes a BK-g criterion only after (a) a `cra` line on whether a copied activity list needs a check beyond the existing summary and (b) `uxa` words and place of the action. Tests then: unit (date empty after copy; copied fields equal the source; copy only from the client's own rows) and e2e (copy, set date, confirm; a tag no longer in the catalogue is refused at its field). Reason (value order 5, less administration; 4, no dispatcher between ward and team): a ward's repeat request takes seconds.
3. **AUT-124 (low) as a BK-g acceptance criterion:** the K-7 test set adds one scenario (fixture or seed scenario; HOW is `eng`'s) with a team of at least 6 contributors and no one at 50 % or more, so the shown path, the withheld path and K-3 run on one dataset; the BK-g acceptance record lists which seed teams show a row and which are withheld. *k* and the rule unchanged.
4. **UXR-208 (low):** the `/team` offer badge renders `urgencyBadgeText(offer.urgency)`; test: an offer with `urgency: null` shows «Dringlichkeit fehlt» with the outline class, the four levels unchanged. In the next BK PR that touches `/team`, otherwise BK-g with UXR-205 to UXR-207. Presentation only; `cra` keeps the colour (CGR-215 (d)).

Owners: `eng` (3, 4), `cra` and `uxa` (2 before it becomes a criterion). PO status of BK: **active**.

## PO acceptance 2026-11-14 09:39 (scheduled PO run): slice BK-a accepted for the simulation

**Decision: `accepted`**, gate **«Simulation, synthetic data»** (CGR-215 (a): no release for real persons before BK-c offers and the BK-6 exception exist). Named integrated commit: **`634ccb7`** (`recovery/main` after #1257; BK-a code merges #1238 `abd6f82`, #1246 `54aa56e`, #1252 `ad8eaef`, #1257 `634ccb7`). The PO did not run any test locally; every result below is read from GitHub Actions job logs or from the repository at `634ccb7`.

**Run evidence.**
- Push `ci` 43572223613 on `634ccb7`: `app`, `db`, `e2e`, `ui-screenshots` all `success`, every test step ran (step list read; skipped only the conditional «WORK1-C5 probe» and «Upload Playwright report», as on every green run).
- `ci-repeat` 43572290695 on `repeat/bk-a-accept-634ccb7` (head `634ccb7`), 08:41–08:56 Zurich (inside the day window): **20/20 jobs `success`, attempt 1, none cancelled or re-run.** Raw log content of all 20 jobs read (PO plus one read-only helper through the GitHub API): every `db` attempt «All tests successful. Files=135, Tests=4833 … Result: PASS»; every `e2e` attempt «174 passed», no flaky, failed or skipped line in the summary; concurrency checks (cover-accept, open-visit-take, SIG1 lock, CGR-201, «CGR-203 region-map-convert-race: 29 ok, 0 not ok») «ok» in all ten; the only «not ok» lines sit inside the B0-4 «before #922» reproduction (expected red by design). Known non-blocking observation, unchanged since 13.11. 18:40: `supabase db lint` reports `schema "net" does not exist` for `private.push_dispatch_kick` (step passes).

**Evidence table (criterion | result | evidence at `634ccb7`).**

| Criterion | Result | Evidence |
|---|---|---|
| BK-1c night across midnight is one order, 9 h for 22:00–07:00 | met | pgTAP 135 «one row, not two days»; e2e `bk-a-order.spec.ts` at 390 and 1440 px «confirms a night order as one order» |
| BK-1b / AUT-120 no silent date: «Sonntag» on a Sunday gives two candidates | met | `tests/unit/bk-a-client-order.test.ts` «BK-a relative date (AUT-120)», `relative_date_ambiguous` in `features/orders/rules.ts` |
| BK-1d binding only after «Bestätigen & Absenden» on the summary | met | e2e summary step before confirm; pgTAP 135 confirm path |
| BK-1n nobody confirms for a client; a client sees only its own orders | met | pgTAP 135 section 6 (nurse, Operations, admin refused, `not_client`; client A never sees B) |
| BK-1e (BK-a part) no street or coordinate on the order | met | pgTAP 135 «no street or coordinate column (P-8)»; free text and AI capture are BK-d |
| CGR-206 (d) clock change: 600 min «(10 Std.)», 480 min «(8 Std.)», 02:30 shown as 03:30 before confirmation | met | pgTAP 135 lines 180–194 (named here as required by amendment 21:39 (2)) |
| CGR-214 (b) audit keeps `referrer_requested_start` and every 0086 column | met, **green on first run (regression guard)** | pgTAP 086 lines 118–133 |
| CGR-215 (d) / UXR-202 «Dringlichkeit fehlt», never dropped, not red, distinct from the four levels | met | `bk-a-intake-urgency-missing.test.ts`, `bk-a-uxr202-urgency-missing-badge.test.ts` |
| UXR-196 sentence from labels, no code or ISO date | met | pgTAP 135 and e2e «Schichtauftrag · FaGe · …» |
| UXR-197 label «aus Ihrem Dienstplan», no label line when none matches, radius empty «Distanz: keine Vorgabe» | met | e2e «a time that matches no plan entry …»; unit tests in `bk-a-client-order.test.ts` |
| PO 18:40 (2)(d), first half: 22:00–07:00 valid and one row with or without a label | met | e2e no-label test plus pgTAP 135 one-row assertion |
| PO 18:40 (2)(d), second half: changing a shift plan never changes eligibility | **moved to BK-b** | no eligibility exists before BK-b; placed as a BK-b criterion below, not dropped |
| UXR-198 `/order` in the client's menu only | met | `bk-a-uxr198-199.test.ts`, e2e, `nav-access.test.ts` |
| UXR-199 one press, one order | met | pgTAP 135 idempotency «duplicate»; e2e count `before + 1`; unit test |
| UXR-200 problem at its field, UXR-201 «Datum nicht erkannt» on leaving | met | `bk-a-uxr200-201.test.ts`; e2e UXR-201 test |
| UXR-204 client's phone home tab «Auftrag erfassen», never a bar with only «Mehr» | met | `ux2-shell.test.ts` `tabs` equals `["order"]` |
| Gates per PR (`cra`, `uxa`, `lca` where named) | met | merge records on #1238, #1246, #1252, #1257; `cra` 09:35 «merged = cleared» |

**Business value.** A ward or household can now state a shift need in one form, sees exactly what will be sent (time, duration with the clock change, place, level) and sends it once; nothing reaches a team before confirmation. That is the intake half of the dispatcher's phone call, removed. Value order 5 (less administration) and 2 (continuity: no duplicate order asking two teams). No team sees the order yet: that is BK-b and BK-c.

**Not part of this acceptance:** AI or voice capture (BK-d); any filter, offer or team view (BK-b, BK-c); pricing (BK-f); private-person addresses beyond PLZ; release for real persons and data.

## PO amendment 2026-11-14 09:39 (scheduled PO run): BK-b active; answers to ADR-195 (probe) OPEN items

Sources: `eng` journal 09:09 (#1265) and probe branch `probe/bk-b-red-20261114` `87a98aa` (draft ADR-195, red pgTAP 136, unmerged); `cra` review 09:35 (#1266). Operational WHAT only; no clinical, legal or tariff rule (D-27); matrix stays PROPOSED. PLANNED unless marked.

1. **BK-b is the active slice.** Slice order unchanged: b, c, e, f, d, g.
2. **Split accepted (README rule 11, `eng` proposal ADR-195 (5)):** BK-b ships as two PRs, **BK-b1** (postcode distances, team reach with AUT-117 permissions, hard distance filter, CGR-217 info item) then **BK-b2** (per-member level CGR-204/CGR-216, confirmed attributes, availability). Reason: smaller PRs, each with its own gates; the distance filter is reviewable without the qualification rules. BK-b is accepted **once**, after both are merged, on one named commit with `ci-repeat` 10/10. BK-b2 does not merge before BK-b1.
3. **`building` teams are excluded** from the hard filter with their own reason (e.g. `team_not_active`), never offered by default. Fail-closed; a team still being set up must not receive an order. Test: a synthetic `building` team whose reach covers the order gets no offer row and carries the reason.
4. **Other organisations' teams:** Phase A screens only teams of the simulated organisation. Agreed with `eng`. Cross-organisation offers wait for D-44 (`lca`).
5. **Empty service area:** `set_team_reach` refuses an empty postcode list (problem code named by `eng`); a team that has never set its reach stays excluded with `no_service_area` (PO 18:40 (1)(c)). A deliberate pause of a team is not part of BK. Words: `uxa`.
6. **pgTAP 135 reference-table list gains `postcode_distances`:** reference data, readable under the same tighter guard `eng` chose on `f6fdcaf`, until `lca` answers amendment 21:39 (6). `lca` line requested.
7. **Moved from BK-a (see acceptance table):** red test in BK-b1 or BK-b2: changing a client's shift plan never changes any team's eligibility for an existing order.
8. **AUT-123 «Wieder erfassen» (BK-g candidate):** `cra` 09:35 gave its line: no tick per activity if (i) a copy shows the same full summary, (ii) a copy passes today's checks including CGR-216 `level_activity_conflict`, (iii) institutions only until the Clinical Owner answers for private persons (UNKNOWN). Becomes a BK-g criterion with (i)–(iii) as tests once `uxa` gives words and place. Still OPEN on `uxa`.

Gates per PR unchanged: `cra` (hard filters, CGR-216), `lca` (distance data source P-5, reference data 6), `uxa` (reach screen, words 5), `aia` (AUT-117 alignment). PO status of BK: **active, slice BK-b**.

## PO amendment 2026-11-14 10:39 (scheduled PO run): BK-b1 PR #1268 read; reach screen placed

Sources: PR #1268 (`eng` 10:12/10:38, head `f3b2a5c`, branch `feature/hourly-update-2026-11-14-1012-bk-b1`), read by the PO on the diff; ADR-195; PO amendment 09:39. Operational WHAT only; no clinical, legal or tariff rule (D-27); matrix stays PROPOSED. PLANNED unless marked. The PO did not run tests locally.

1. **#1268 not merged this run.** `ci` 43581473063 on head `f3b2a5c` was running at the PO's read (`app` success; `db`, `e2e`, `ui-screenshots` in progress; `mergeable_state` `blocked`). No gate line yet from `cra`, `lca`, `uxa` or `aia` (PO_MERGE_PROCESS §4 (1)–(3)). Merge when all four gate lines name an unchanged code head (AUT-50) and CI on that head is 4/4.
2. **PO reading of #1268 against amendment 09:39 (not an acceptance):**

| Point | Result | Evidence (diff at `f3b2a5c`) |
|---|---|---|
| (3) `building` team excluded, fail-closed | present | `private.screen_order_reach`: `status is distinct from 'active'` → `team_not_active`; pgTAP 136 fixture T7 «im Aufbau», no offer row |
| (4) own organisation only | present | `where t.organization_id = o.organization_id` |
| (5) empty service area refused | present | `set_team_reach` → `missing_service_postcode`; pgTAP 136 |
| (6) `postcode_distances` reference data, tighter guard | present | RLS on, no write grant, `leave1_access_open` restrictive; pgTAP 135 list gains the table |
| (7) shift-plan change never changes eligibility | present | pgTAP 136 «changing the client's shift plan changes no offer or exclusion row» |
| AUT-117 (a) who may set reach | present | active member of the team; `admin` only without active members; pgTAP 136 both directions |
| BK-2n every team in exactly one table | present | pgTAP 136 «never both, never missing» |
| CGR-217 information item, never a block | present | `preview_client_order` `info`, neutral style, confirm stays enabled; vitest + e2e |
| no person column in offer/exclusion | present | `order_offers`, `order_exclusions`: team only |

3. **Reach screen (AUT-117 (c)), `eng` OPEN in #1268: decided.** Not in #1268 (keep the open PR's gates on the code they started on). It becomes its own PR **BK-b1s** «Unser Einsatzgebiet» (team view), after #1268 and before the BK-b acceptance; it may merge before or after BK-b2. Reason (value 4, team autonomy): without the screen only the seed sets a team's reach, which is a central step; BK-b is not accepted while a team cannot set its own reach. Criteria: (a) an active member sees and changes postcodes and maximum distance of the own team only, through `set_team_reach`; (b) the three refusals (`missing_service_postcode`, `postcode_not_in_list`, `max_distance_not_positive`) appear at their fields in `uxa` words; (c) a member of another team and a former member (LEAVE1) cannot open or submit it (e2e negative); (d) the screen states that a change applies to new orders only (words `uxa`), because existing orders keep their screening (BK-2n, written once); (e) 390 and 1440 screenshots. Gates: `uxa` (words, place), `aia` (AUT-117), `cra` only if the words touch care.
4. **Observation for `uxa` and `lca`, not a finding:** a team member can read the exclusion row of the own team for an order (reason only, no order detail). The PO's product view: a team should see *why* an order did not reach it («ausserhalb Ihres Einsatzgebiets»), because that is how a team adjusts its own reach without anyone deciding for it. Whether and where the team sees this is `uxa`'s; whether the order's existence alone is a disclosure is `lca`'s (reference amendment 21:39 (6)). Until both answer, nothing is shown in the UI; the table stays as built.

PO status of BK: **active, slice BK-b** (BK-b1 PR open, BK-b1s and BK-b2 to follow).

## PO amendment 2026-11-14 11:39 (scheduled PO run): #1268 CI green, gates still missing; BK-b1s deviation (5) decided

Sources: PR #1268 (head `f3b2a5c`), draft PR #1270 (`eng` 11:10, head `1cb6e09`, stacked on #1268), ADR-195 addendum 11:10. Operational WHAT only; no clinical, legal or tariff rule (D-27); matrix stays PROPOSED. PLANNED unless marked. The PO did not run tests locally.

1. **#1268 not merged this run.** `ci` 43581473063 on head `f3b2a5c` is now 4/4 `success` (`db` 136 files / 4880 tests PASS; `e2e` 175 passed; `ui-screenshots` success), condition (1) holds for the checks. Still missing: gate lines from `cra`, `lca`, `uxa` and `aia` naming `f3b2a5c` (PO_MERGE_PROCESS §4 (2), (3); amendment 10:39 (1)); no review, no role journal since 10:39. Merge in the first PO run in which all four lines name an unchanged code head (AUT-50).
2. **#1270 (BK-b1s) read, not mergeable:** draft and based on the #1268 branch; `ci` 43586014799 had `app`, `db`, `ui-screenshots` `success` and `e2e` running at the PO's read. It is merged only after #1268, retargeted to `recovery/main`, with CI 4/4 on its own head and gate lines from `uxa` and `aia` (and `cra` only if `uxa` words touch care).
3. **Deviation (5) of ADR-195 addendum 11:10 (criterion (c), former member): decided, accepted with a condition.** For the BK-b1s merge, the former member (LEAVE1) is evidenced at the database (pgTAP 137 §4: reader empty, `set_team_reach` refused with `access_ended`, reach unchanged), because the database is where access is enforced and the screen only shows what `my_team_reach()` returns; e2e covers a member of another team and a person in no team. Ending a shared seeded member's access in e2e would change other specs, which is a worse test. **Condition:** a dedicated seeded former member (synthetic) with an e2e negative on `/team/einsatzgebiet` (no team data shown, submit refused) is added **before the BK block acceptance** (not before BK-b), in BK-b2 or its own small PR; until then criterion (c) reads «e2e: other team, no team; pgTAP: former member». Reason: privacy is enforced fail-closed at the database already; the e2e is a second line, not the control.
4. **Order unchanged:** #1268, then BK-b1s (#1270) and BK-b2 in either order, then the BK-b acceptance on a named commit (`ci` green, `ci-repeat` 10/10 `db` and `e2e`, raw logs).

PO status of BK: **active, slice BK-b** (BK-b1 #1268 waiting for gates; BK-b1s #1270 draft; BK-b2 to follow).


## PO amendment 2026-11-14 12:39 (scheduled PO run): `uxa` and `lca` gates on #1268; UXR-209 to UXR-213 and `lca` B-2, B-5, E-1 to E-4 placed; #1273 read

Sources: PR #1268 (head `f3b2a5c`), draft PRs #1270 (head `1cb6e09`) and #1273 (BK-b2, head `4b8a158`, both stacked on #1268), `UX_REVIEW.md` 11:48 (#1272, merged `9fb2f4a`), D-44 section `lca` 12:20 (#1274, merged `076dee3`), ADR-196. Operational WHAT only; no clinical, legal or tariff rule (D-27); matrix stays PROPOSED. PLANNED unless marked. The PO did not run tests locally.

1. **#1268 not merged this run.** Head unchanged at `f3b2a5c`; `ci` 43581473063 4/4 `success`. Gate lines now present: `uxa-gate: #1268 f3b2a5c clear` (11:48) and `lca-gate: #1268 f3b2a5c clear` (12:20, advisory). **Still missing: `cra` and `aia`** (PO_MERGE_PROCESS §4 (2); amendment 10:39 (1)). Merge in the first PO run in which both name the unchanged code head (AUT-50).
2. **UXR-209 (medium) placed: before the BK-b acceptance**, not a merge condition for #1270 (so the `uxa` gate on `1cb6e09` stays valid): the reach screen says that the distance is measured from the nearest chosen postcode and that the smaller of team reach and client limit applies (words `uxa`). In #1270 (new head, new `uxa` line) or a small follow-up PR. Reason (value 4): a team that cannot predict which orders reach it cannot steer its own area.
3. **`lca` B-5 placed with UXR-209, same timing:** the reach screen carries the G-4 (c) help line that the area is the team's working area, not anyone's home address (words `uxa`, substance `lca`).
4. **UXR-213 (low) placed: before the BK block acceptance:** the CGR-217 item on `/order` is shown only when the confirm button is enabled. In #1273 (it changes `order-form.tsx` already) or later.
5. **UXR-210, UXR-211 (low):** queued for BK-g (screen polish). **UXR-212 (low):** before Phase B (real postcode list).
6. **`lca` D-44 B-2 (b) adopted as a standing BK criterion (privacy, D-35 rule A spirit):** no order field leaves NAVORA to compute a distance; distances are read only from the precomputed `postcode_distances` table. Check at the BK-b acceptance: the PO reads the diff for any external call in screening, and the `aia` gate line confirms it. Phase B data source: swisstopo OGD precomputed offline with attribution is compliant on the sources `lca` read; any other source needs the owner (licence not read). Not decided here: the Phase B source itself (owner, before Phase B).
7. **`lca` B-4 E-1 to E-4 recorded, no view placed:** a «why not reached» view for teams is not built now. If it is ever placed, E-1 to E-3 are its criteria (reason and date only; private-person orders only as period counts; the client never sees exclusions), and real use needs the owner (privacy notice) and E-4 (legal adviser, across organisations).
8. **#1273 (BK-b2) read, not an acceptance:** draft, stacked on #1268; red first present (`4e2035f` alone: pgTAP 138 and vitest failing as expected in `ci` 43589501063). The pgTAP 136 change is named as a fixture addition (one verified synthetic FaGe per offered team, no assertion, plan or expected value changed); the PO checks this in the diff at merge. **ADR-196 (3) is a clinical reading** («D» passes only for a non-required activity; a required activity needs own scope with its evidence): the PO does not decide it; `cra` must confirm or change it before #1273 merges (D-27). Gates: `cra` (CGR-204 (a), CGR-216, ADR-196 (3)), `uxa` (conflict words, place), `lca` (P-5: a step, never a person), `aia` (no AI in the filter).
9. **Challenge hypothesis H-BK-12:39 (for the BK-c brief, PLANNED):** an order that no team reaches after screening must never wait silently or fall to a central dispatcher. The client sees at once one honest state («Zurzeit kann kein Team diesen Auftrag übernehmen», words `uxa`) without per-team reasons (compatible with E-3), and can widen its own limits or time window. Questions for `uxa` (words) and `lca` (whether the state itself discloses anything); no build before the BK-c brief.
10. **Order unchanged:** #1268, then #1270 and #1273 in either order, then the BK-b acceptance on a named commit (`ci` green, `ci-repeat` 10/10 `db` and `e2e`, raw logs).

PO status of BK: **active, slice BK-b** (BK-b1 #1268 waiting for `cra` and `aia`; BK-b1s #1270 and BK-b2 #1273 drafts).

## PO amendment 2026-11-14 13:39 (scheduled PO run): CGR-218 (A), CGR-219, CGR-220 placed

Sources: `cra` review 13:30 (#1277, merged `4c43e3b`), comments on #1268. BK stays the only active block; slice order unchanged (a, b, c, e, f, d, g). Operational WHAT only; the PO sets no clinical, legal or tariff rule (D-27). The matrix and its context modifiers (CR-180) stay PROPOSED. Everything below is PLANNED unless marked.

1. **#1268 not merged this run.** Head `f3b2a5c` unchanged, `ci` 43581473063 4/4 `success`. Gate lines `uxa` (11:48), `lca` (12:20) and now **`cra` (13:30, «Simulation, synthetic data»)** name the head. **Still missing: `aia`** (amendment 10:39 (1); B-2 (b) check: no external call in screening). Merge in the first PO run in which the `aia` line names the unchanged head (AUT-50).
2. **CGR-218: option (A) for #1273 (merge condition), (B) rejected.** Until the Clinical Owner decides CR-180, BK reads the activity cell in the **strictest context that fits the client kind** (the `cra` safe default): `home` orders under NH-EXT (every «D» and every Bst. b «E» counts as «?»), `hospital_ward` orders under HOSP-IN (every row «?»), `household` under the plain table. A «?» counts as «–» in every phase (CR-179). Reason: patient safety is the precondition; a simulation that shows behaviour the matrix forbids trains the wrong product and would carry into Phase B (by current direction a nursing home). The PO adopts the stricter of two `cra` review positions; it does not create or confirm a clinical rule. Product consequence, accepted for Phase A: in the simulation no `hospital_ward` order can be confirmed, and on `home` orders FaGe «D» activities and HF Bst. b «E» activities are refused at confirm. Tests (from `cra`): FaGe with B1 on a `home` order → refused at confirm, B1 named, no order row; HF with B7 on a `home` order → refused; any `hospital_ward` order with an activity → refused; the same FaGe/B1 on a `household` order → plain table.
3. **CGR-219: in #1273 (merge condition).** Confirm check and member step use **one** reading: an activity that no member can pass at the chosen grade under the active reading is refused at confirm, with the activity named; never «sent» and then excluded everywhere. Tests as `cra` 13:30 (FaGe with B1 required → `invalid`, no order row; not required → confirmed in the plain-table context) plus one consistency test over every grade × activity of QAM-0.2: «confirm accepts» implies «a member with that grade and evidence can pass». Code name and words: `eng` and `uxa`.
4. **Honest state for refused combinations (words `uxa`, before #1273 merge):** the refusal says which activity cannot be ordered at this level in this setting and that this is a safety limit of the simulation, not a team decision; for `hospital_ward` one sentence that hospital ward orders are not yet possible. No clinical explanation is invented in the words.
5. **CGR-220 (advisory, S3): placed before the BK-b acceptance, not a #1268 merge condition** (keeps the cleared head). A small Engineering PR after #1268 merges: the `audit_teams` trigger skips by **what changed**, not by a session value; pgTAP as `cra` 13:30 (with `navora.command = 'set_team_reach'` a direct `priority` update still writes one audit row; `set_team_reach` still writes exactly one). Reason: auditability above speed; no audit trigger may be switched off by a session setting.
6. **Note for the BK-b acceptance record (adopted from `cra`):** offer rows written while only BK-b1 was merged carry no member check; the record states that they are synthetic and are not read as eligible.
7. **#1270** (BK-b1s, `1cb6e09`): `cra` line present (not required). **#1276** (UXR-209 and B-5 follow-up, stacked on #1270): read, not mergeable; gate lines `uxa` and `aia` on a green head after retargeting.
8. **Challenge hypothesis H-BK-13:39 (PLANNED, questions to `uxa` and `aia`):** a refusal at confirm is still a round trip for the client. The order form should offer, at the moment the level is chosen, only the activities the active reading allows for this client kind, and show the others as «auf dieser Stufe hier nicht bestellbar» with a one-click «höhere Stufe wählen». Deterministic, from the same reading as the confirm check (no AI). Same guarantee, one step less. Not a #1273 condition; candidate for BK-g.
9. **Order unchanged:** #1268 (`aia`), then #1270 and #1273 (CGR-218 (A), CGR-219, new `cra` line), #1276, the CGR-220 PR, then the BK-b acceptance on a named commit (`ci` green, `ci-repeat` 10/10 `db` and `e2e`, raw logs).

Owners: `eng` (2, 3, 5), `uxa` (4, 8 words), `cra` (gate line on the new #1273 head), `aia` (#1268 line, 8), Clinical Owner (CR-180, meaning of «D» on a shift order: UNKNOWN until answered). PO status of BK: **active, slice BK-b**.

## PO amendment 2026-11-14 14:39 (scheduled PO run): #1268 merged; AUT-125, AUT-126 placed; H-BK-14:39

Sources: `aia` review 57 (#1280, merged `95678c5`), gate comments on #1268. BK stays the only active block; slice order unchanged (a, b, c, e, f, d, g). Operational WHAT only; the PO sets no clinical, legal or tariff rule (D-27). Everything below is PLANNED unless marked.

1. **#1268 (BK-b1) merged** as `9b691af` (head `f3b2a5c`; `ci` 43581473063 4/4; gate lines `uxa` 11:48, `lca` 12:20, `cra` 13:30, `aia` 14:22, all «Simulation, synthetic data»; merge record comment 6878119279). **Merged, not accepted.** The push `ci` on `9b691af` was cancelled by the next push (`95678c5`, docs only); the push `ci` on `95678c5` carries the integrated BK-b1 code and was running at publication. If it is red, `eng` is asked for a revert or fix-forward per FE-071 (3) in the next PO run. CGR-217 closes with this merge (`cra` 13:30).
2. **Stack after the merge (`eng`):** #1270 (BK-b1s) and #1273 (BK-b2) point at the merged branch `feature/hourly-update-2026-11-14-1012-bk-b1`; retarget both to `recovery/main`, #1276 stays on #1270. Gate lines on the new green heads (AUT-50). Next Engineering merge: **#1270**, then #1273 (CGR-218 (A), CGR-219, new `cra` line), #1276, the CGR-220 PR, then the BK-b acceptance on a named commit.
3. **AUT-125 (medium): placed in BK-g, not a BK-b condition.** The reach screen shows the team's own count of recent exclusions by reason (from `order_exclusions`), no order detail, no suggested value, the team decides. Reason: it turns a blind setting into a self-correcting one (team autonomy, fewer wasted offers), but it needs `lca` (team-level count without order detail is no disclosure) and `uxa` words first; adding it to #1270 would move a cleared slice. Preconditions before BK-g starts: `lca` line, `uxa` words, the fixed period named by `uxa`/`aia`. Tests as `aia` 14:22 (pgTAP: only own team, no order column, former member none; e2e: seeded order outside distance shows «1»).
4. **AUT-126 (low): adopted as the design for H-BK-13:39 (BK-g candidate)** with all three `aia` conditions: (a) the form receives the allowed set from the **same server function** as the confirm check, never a copy of the matrix in the client; (b) the confirm check stays unchanged as the guard; (c) where the active reading refuses every order of a client kind (`hospital_ward` under CGR-218 (A)), the page says so before the first input, in `uxa` words. Test: one test over the matrix that the offered set equals the accepted set for every (client kind, level).
5. **Challenge hypothesis H-BK-14:39 (PLANNED, questions to `uxa`, `lca`, `aia`):** with the hard distance filter merged, an order can be confirmed that reaches **no team at all** (every team excluded). The client then waits for an answer that cannot come, and someone has to notice by hand: exactly the dispatcher role NAVORA removes. Proposal: the preview runs the same deterministic reach screening and, when zero teams of the own organisation remain, says so before confirm («Für diese Postleitzahl ist zurzeit kein Team erreichbar»), with no team name, count or distance shown. Open questions: `lca` (is a yes/no on coverage a disclosure about teams?), `uxa` (words, what the client can do next), `aia` (same function as confirm, no copy). Not a condition for #1270 or #1273; candidate for BK-b acceptance criteria only if all three answer before #1273 merges, otherwise BK-c.
6. **UXR-213, `lca` B-5, UXR-209:** placements of 12:39 unchanged.

Owners: `eng` (2), `lca` (3, 5), `uxa` (3, 4, 5 words), `aia` (5), `cra` (gate line on the new #1273 head). Clinical Owner: CR-180 and «D» on a shift order (UNKNOWN until answered). PO status of BK: **active, slice BK-b (BK-b1 merged, not accepted)**.

## PO amendment 2026-11-14 15:00 (live session with the founder): FE-078 part 2, broadcast replaces the exclusive cascade

Source: `FOUNDER_DECISIONS.md` FE-078 (v29), founder message 2026-11-14. The newest founder decision overrides BK-5 as written (README rule 10). BK stays the only active block; slice order unchanged. Operational WHAT only; no clinical, legal or tariff rule is set here (D-27). Everything below is PLANNED unless marked otherwise.

1. **BK-5 replaced (broadcast):** when the client confirms, **every** team that passes **every** hard check of BK-2 (distance, level, required attributes, availability for the whole shift by one and the same member, valid evidence) sees the offer **at the same time**. No exclusive window, no «next team». The ranking (BK-3, BK-4) orders the list and explains it («Empfohlen für euch, weil …»); it never hides an eligible team. A team that declines drops out; the others keep seeing the offer. Tests: positive (three eligible teams → three offer rows at confirmation; ranking changes order only); negative (an ineligible team gets no row; the ranking never removes an eligible team; a declined offer stays open for the others).
2. **BK-5a kept and sharpened:** the first «Übernehmen mit …» that passes the hard re-check at that moment wins; a concurrent second tap is refused with «Bereits übernommen» and creates nothing (pgTAP with two sessions, as in the existing concurrency jobs). The client sees «gedeckt durch Team …» within seconds.
3. **BK-5n kept:** no one assigns the order for a team (FE-039); NAVORA never selects one team.
4. **BK-6 adjusted:** «Angebot bei Team 1 von 4» is replaced by a count of eligible teams that still see the offer; **[count part SUPERSEDED by PO amendment 20:40 (3): no team count reaches the client; marker `uxa` 2026-11-14 on founder instruction]** «nicht gedeckt» and the Operations exception stay when all eligible teams declined or the shift start comes near (threshold is an operational parameter, default by `eng` in the ADR; not a clinical rule). No silent expiry.
5. **Code state:** today all eligible teams already see an offer (Blueprint §6.3 row 4, IMPLEMENTED); the cascade was never built. `eng` checks in its ADR whether ADR-191/193 or the BK-b migrations assume a cascade and lists any change.
6. **Reviews asked (next runs):** `cra` (hazards of the broadcast: concurrent take-over, shift start without take-over, PS/H rows replacing «Kaskade»); `lca` (Q-44e re-read for the broadcast; the founder's AVG reasoning is his assessment, the verdict stays with `lca` and the adviser); `uxa` (offer card without window, «Bereits übernommen», client status wording); `aia` (Engine 2 as recommendation without exclusion; AUT findings on BK-3/BK-4).
7. **FE-078 part 3:** the `lca` corrections of PR #1220 (W-1 to W-7, C-1 to C-7, V-1 to V-7) are in the Blueprint since V3.2.4 and are now binding; any external use of the model figures keeps the labels «Beispielwerte, kein Tarif, kein Einkommensversprechen» (W-7).

Owners: `eng` (1, 2, 4, 5), `cra`, `lca`, `uxa`, `aia` (6). PO status of BK: **active**.

## PO amendment 2026-11-14 17:40 (scheduled PO run): `cra` CGR-221 to CGR-223 placed; merge order #1270, #1273, #1291

Source: `CLINICAL_GOVERNANCE.md` 17:26 (PR #1293, merged `c860cc3`); `eng` journal 17:10. Operational WHAT only; no clinical value is set (D-27). Everything below is PLANNED unless marked otherwise.

1. **CGR-222 (c), BK-c acceptance condition (next to CGR-211):** pgTAP with a pinned clock: an uncovered order one minute before the latest coverage time is «noch nicht gedeckt» with no exception; at that time it has the exception and the not-covered state, and the time is earlier than `starts_at`. A short-notice order whose coverage time is already past at confirm raises both at once. The value: simulation default per `eng` ADR, listed PROPOSED in the Clinical Rule Register; the Clinical Owner confirms or replaces it before real data (K-8). BK-6 (15:00 (4)) is read with this sentence (Blueprint V3.2.16 §6.2).
2. **CGR-223 (a) to (c), BK-c acceptance condition:** when the named member of a taken order stops passing before `starts_at` (absence overlapping the slot, access ended, grade or required evidence no longer `verified` at the slot end, an overlapping open visit), the order leaves «gedeckt» at once, the client sees it, and it goes back to the broadcast after a fresh hard check of every team; an exception exists if the coverage time has passed. The team may name another member who passes (no one else assigns, FE-039). Tests: pgTAP take with member M, then an absence for M overlapping the slot, and separately M's grade evidence expiring before the slot end: state no longer covered, offer rows again for the passing teams. CGR-223 (d) is in the Blueprint §6.2 diagram (V3.2.16).
3. **H-BK-15:39 (taken offer leaves the other teams' lists):** `cra` accepts it under three conditions, adopted as BK-c criteria: (i) the offer leaves a list only after the server has committed the take; (ii) after a failed take (2.) it returns to every team that still passes; (iii) an uncovered order never leaves an eligible team's list before «nicht gedeckt» is raised, and then stays in the Operations exception. `uxa` and `aia` answers still OPEN.
4. **Merge order (answer to `eng` 17:10 and `cra` 17:26):** #1270 first (waits only on the `aia` gate line on `1cb6e09`), then #1273 (`cra` line on `1dde2d8` now present; `uxa` and `aia` lines on that head still needed), then #1291 as its own PR after #1273 (not folded in, so the #1273 gate lines stay valid; it needs its own `uxa` line, `cra` line on `a036e59` present). #1276 after #1270. One Engineering merge per run.
5. **Blueprint text (CGR-221, CGR-222 (a), (b)):** transferred in V3.2.16 (Annex B replacement text word for word; §5.1, §6.2, §6.4 sentences). Annex B §2 row «3 Engine 1» and the Handbook part stay with Handbook V2.3 (`eng` V-1, `lca` S-3).

Owners: `eng` (1, 2, 3 in the BK-c ADR), `uxa` (words for «nicht gedeckt vor Beginn» and «nicht mehr gedeckt»), `cra` (closes CGR-221 to CGR-223 itself). PO status of BK: **active**, slice BK-b.

## PO amendment 2026-11-14 20:40 (scheduled PO run): #1270 merged; BK-c criteria from the FE-079 reservations

1. **#1270 (BK-b1s) merged** `a076731` (head `1cb6e09`; merge record comment on #1270). Merged, not accepted: BK-b is accepted only as a whole slice on a named integrated commit (`ci` green, `ci-repeat` 10/10, raw job logs), gate «Simulation, synthetic data». The seeded former-member e2e negative (amendment 11:39 (3)) stays due before the BK block acceptance.
2. **BK-c criterion (from `eng` V-8 and `aia` AUT-128, same finding):** on the order path, the set of teams a team-facing view shows equals the `order_offers` rows for that order, and the ranking only reorders them; positive test (every offered team sees it) and negative test (a team without an offer row never sees it, and no ranking change removes a team). Until BK-5 exists, Blueprint §6.3 step 4 is read as «case path IMPLEMENTED; order path: offer rows IMPLEMENTED, team view PLANNED».
3. **BK-c criterion (from `lca` 20:25, D-44 (2), option (a), advisory):** the client read model returns no team count (no exact, banded or live count) for every client kind, with its own zero state; negative test that no count field reaches the client. Any count variant stays `unresolved: needs owner`; the PO does not pick it.
4. **Unchanged:** CGR-222 4 h latest-coverage default PROPOSED for simulation only (`eng` V-7), value before real data with the Clinical Owner (K-8, OPEN). No clinical, legal or tariff rule set here.

Owners: `eng` (2, 3 in the BK-c ADR and tests), `uxa` (zero-state words for 3), `lca` (reads 3), `aia` (reads 2). PO status of BK: **active**, slice BK-b.

## PO amendment 2026-11-14 21:39 (scheduled PO run): BK-5 template placed; `cra` CGR-224 to CGR-226 placed

1. **Single BK-5 template placed** (`docs/design/BK5_OFFER_TEMPLATE.md`, `uxa`, merged with #1305 `b122a60`, PROPOSED): it is the one screen reference for BK-c (offer card, team states, client status, never-shown list). Where a picture differs, the template and this brief win (template §1). The SUPERSEDED markers `uxa` set in BK-5, BK-5n, slice list and 15:00 (4) are adopted by the PO as owner of this brief (merge record #1305). «Ablehnen» without a reason is accepted for BK-c as a presentation choice (value 5, less administration); a decline reason can come later only with a stated use.
2. **BK-c criterion (from `cra` CGR-224, advisory, S1 before real clients):** on the order path the same named person cannot be taken onto two shift orders whose slots overlap; a take that would overlap is refused with the reason, and a later visit or take never silently releases an existing take. Positive test (two non-overlapping takes of the same person pass) and negative test (an overlapping second take is refused, nothing stored; pgTAP with two sessions).
3. **BK-c criterion (from `cra` CGR-225, advisory):** when no team passes every hard check at confirmation (zero state of 20:40 (3)), the Operations exception is raised at once, not only at the latest coverage time. Positive and negative test. This sets no clinical value; the coverage-time value stays PROPOSED (4 h, simulation only) and with the Clinical Owner before real data (K-8, OPEN).
4. **CGR-226 (advisory, words):** «Pflegekraft benannt» must not claim more than the checked grade, and «Nicht gedeckt» needs a next step. Words: `uxa`; substance of the next step: `cra` (Blueprint §5.1, template §4 row UNKNOWN). Blocks no BK-b merge; BK-c acceptance needs both.
5. **Visible evidence for BK-c review (template §5, `uxa` proposal) decided:** the BK-c PR attaches the 390 px and 1440 px screenshots of the offer card and the client status (synthetic seed only) as images in a PR comment, and the `uxa` gate line names the images it looked at. A green `ui-screenshots` job alone is not a visual review.

Owners: `eng` (2, 3, 5 in the BK-c ADR and PR), `uxa` (4 words, 5 gate line), `cra` (4 substance; closes CGR-224 to CGR-226 itself). PO status of BK: **active**, slice BK-b. BK-c is **not active**; nothing here starts feature work (README rule 12).

## PO amendment 2026-11-15 02:40 (scheduled PO run): `aia` gate lines in; AUT-130 placed

1. **`aia` gate lines** on all four BK-b heads (#1273 `c2ffef1`, #1291 `6abf9f8`, #1276 `1600588`, #1295 `b0b0da4`, all «clear, Simulation, synthetic data», review 59, merged with #1322 `d3ebc82`). #1273 now waits only on the `uxa` gate line on `c2ffef1` and on `eng` taking the stack out of draft. Merge order unchanged: #1273, #1291, #1276, #1295; one Engineering merge per run.
2. **BK-c criterion (from `aia` AUT-130, low, advisory):** the eligibility re-check at the take (CGR-204 (b)) and the no-double-take rule (CGR-224, 21:39 (2)) run through the one member step `private.order_member_step`; an accepted take of the same person is one more availability source inside it (overlap with `[start, end)`). No second eligibility function for the take. Test (pgTAP): a member with an accepted overlapping take returns the availability step from `order_member_step`, and the take is refused with the same reason; a member without an overlapping take passes. This is a design rule for one code path, not a clinical rule; `cra` reads the availability sources.

Owners: `eng` (2 in the BK-c ADR and tests), `cra` (reads 2), `aia` (reads 2). PO status of BK: **active**, slice BK-b. BK-c is **not active**; nothing here starts feature work (README rule 12).

## PO amendment 2026-11-15 05:39 (scheduled PO run): #1276 merged; CGR-227 with STR-39 placed in this brief; acceptance-record rule

1. **#1276 (BK-b1s follow-up UXR-209 / `lca` B-5) merged** `792a5d3` (head `08b29c8`; merge record comment on #1276). `uxa` (15:51) and `aia` (02:17) lines on `1600588` carried by the patch-id line H-BK-03:39 (`da25ecea30fc…` on both heads over `src supabase tests e2e`, recomputed by the PO); `cra-gate: #1276 08b29c8 clear` (05:28). Merged, not accepted. BK-b has one PR left: #1295 (CGR-220).
2. **BK-g criterion (placed in the PO journal 01:40, now written here on `cra` 05:28 request):** `csa` STR-39 (a): rank and prior service per take are measured in the BK-g test output. `cra` CGR-227 (advisory, S2): a continuity preference, if ever built, only orders the broadcast; it never removes an eligible team, never delays the offer, never moves `latest_cover_at` and shows no team count. Test: every eligible team receives the offer at the same moment with and without the preference. STR-39 (b) goes to the Phase B metric list; STR-39 (c) (client-set preference) stays with `lca` within Q-44e and is not built before an `lca` answer and a `cra` line. No clinical or legal rule is set here.
3. **BK-b acceptance record (adopted from `cra` 05:28):** the record cites only completed `ci` runs whose four jobs (`app`, `db`, `e2e`, `ui-screenshots`) ended `success`; a cancelled run on the same commit (for example the `pull_request` run 43673483807 on `08e5d8e`, cancelled next to the green `push` run 43673480338) is named as cancelled and not counted. `ci-repeat` 10/10 (`db`, `e2e`) is read from raw job logs as before.

Owners: `eng` (#1295 merge-up, then the BK-b acceptance commit and `ci-repeat`), `cra` (closes CGR-227 itself when BK-g meets it), `csa` (reads 2). PO status of BK: **active**, slice BK-b.

## PO acceptance 2026-11-17 02:39 (scheduled PO run): slice BK-b accepted for the simulation

**Decision: `accepted`**, gate **«Simulation, synthetic data»**. Not released for real persons or data: no team sees or takes an order before BK-c (CGR-215 (a)); CR-180, K-8 and every matrix cell stay PROPOSED with the Clinical Owner (D-27). Named integrated commit: **`ab90875`** (`recovery/main` after #1295; BK-b code merges #1268 `9b691af`, #1270, #1273 `6c4b74b`, #1291, #1276 `792a5d3`, #1295 `ab90875`). The PO did not run any test locally; every result below is read from GitHub Actions job logs or from the repository at `ab90875`.

**Run evidence.**
- Push `ci` 43682107812 on `ab90875`: `app`, `db`, `e2e`, `ui-screenshots` all `success` (jobs API, read by the PO this run and at 00:39). No cancelled run on this commit is counted (amendment 05:39 (3)).
- `ci-repeat` **43994886883** on `repeat/bk-b-accept-ab90875-day` (head `ab90875`), attempt 1, 02:21:00 to 02:30:26 Zurich (inside the day window; every job started 02:21:02 or later): **20/20 jobs `success`**, none cancelled or re-run.
- Raw log content of all 20 jobs downloaded and read by the PO:
  - every `db` attempt: «All tests successful. Files=140, Tests=4965 … Result: PASS»; pgTAP 136, 137, 138, 139, 140 «ok» in all ten;
  - every `db` attempt: concurrency checks «ok», «CGR-203 region-map-convert-race: 29 ok, 0 not ok»; the only «not ok» lines sit inside the B0-4 «before #922» reproduction (expected red by design, one per log);
  - every `e2e` attempt: «182 passed», **0 skipped, 0 flaky, 0 failed** (no `skipped`, `flaky` or `failed` count line); `bk-b1s-reach.spec.ts` and `bk-b2-level-activity-conflict.spec.ts` «✓» in all ten.
- The night repeat 43977104731 (00:11–00:21, 3 skipped) does not count and is not part of this record.

**Evidence table (criterion | result | evidence at `ab90875`).**

| Criterion | Result | Evidence |
|---|---|---|
| BK-2 PLZ distance within the team maximum and, if set, the client radius (smaller one applies) | met | pgTAP 136 «order without radius: offered are …», «client radius 4: T2 … is excluded», «PO 18:40 (1)(c): the smaller of team maximum and client radius applies», «a team whose maximum is 1 km short (4 of 5) is excluded» |
| BK-2 distance is the minimum over the team's postcodes (ADR-193 (3)) | met | pgTAP 136 «ADR-193 (3): distance is the minimum over the team» |
| BK-2 level allowed for every tag (matrix PROPOSED), one reading at confirm and screening (CGR-216, CGR-218 (A), CGR-219) | met | pgTAP 138 «CGR-216 (a) …» rows; pgTAP 139 «one reading: whatever such a member passes, confirm accepts (no hidden second rule)», grid over every client kind × grade × activity × required; e2e `bk-b2-level-activity-conflict.spec.ts` |
| BK-2 availability for the whole slot, one member carries the team (CGR-204) | met | pgTAP 138 «qualified member away for part of the slot … not offered», «a team that passes only by combining two members is not offered»; V7 half-open slot, V8 withdrawn absence, V11 open visit, V6 access ended |
| BK-2 every excluded team carries its reason | met | pgTAP 136 reasons `no_service_area`, no maximum distance, `building`; pgTAP 138 «the reason check lists the BK-b2 reasons» |
| BK-2n a team failing any hard filter is never offered | met | pgTAP 138 «BK-2n: no team is both offered and excluded»; pgTAP 136 «the building team has no offer row (fail-closed)» |
| PO 09:39 (3) `building` teams excluded with their reason | met | pgTAP 136 two rows |
| PO 09:39 (5) empty service area refused; never-set reach excluded | met | pgTAP 136 «an empty service area is refused …», «a team without service postcode is excluded with its reason» |
| PO 09:39 (7) / moved from BK-a: changing a client's shift plan never changes eligibility | met | pgTAP 136 «PO 09:39 (7): changing the client …» |
| AUT-117 (a) to (d): who sets the reach, no retroactive change of offer rows, date stored, seed complete | met | pgTAP 136 AUT-117 rows; pgTAP 137; e2e `bk-b1s-reach.spec.ts` |
| P-4, P-5, P-8 (`lca`): no street or coordinate, rows name a team never a person, postcode only from the list | met | pgTAP 136 first rows |
| CGR-217 same-order info item | met | `tests/unit/bk-b1-cgr217-same-order.test.ts`; pgTAP 136 `same_order_already_confirmed` |
| UXR-209 / `lca` B-5 help lines on the reach screen | met | `tests/unit/bk-b1s-uxr209-reach-rule.test.ts` (#1276) |
| CGR-220 teams audit trigger skips by what changed, never by a session value | met | pgTAP 140 «ok» in all ten logs; `cra` closed CGR-220 (01:28) |
| The per-member check is private | met | pgTAP 138 «no public function exposes who is eligible», «a member of an excluded team (V2) reads no offer row of another team» |
| Gates per PR (`cra`, `lca`, `uxa`, `aia` where named) | met | merge records on #1268, #1270, #1273, #1291, #1276, #1295; `cra` 01:28 «Blocked: nothing» |

**Business value.** A confirmed order now reaches, deterministically and with a reason for every exclusion, exactly the teams that are near enough, have one free member of the right level for the whole slot, and are not still being set up. This is the dispatcher's mental filter, removed and made auditable (value 5, less administration; patient safety: a missing qualification can never be ranked into an offer). No direct care time is returned yet: teams cannot see or take the order until BK-c (`aia` map v4, AUT-128).

**Not part of this acceptance:** ranking, offer card, broadcast, take and «nicht gedeckt» (BK-c); re-check at the take and when a member stops passing (CGR-204 (b), CGR-223, BK-c); zero-reach statement before confirm (H-BK-14:39, BK-c candidate); AI or voice capture (BK-d); release for real persons and data.

**Consequence: BK-c is the active slice** (slice order b, c, e, f, d, g). Start per FE-071 (2): `eng` writes the BK-c ADR and red tests first, covering at least the criteria placed in this brief: CGR-211, CGR-222 (c), CGR-223 (a)–(c), H-BK-15:39 (i)–(iii), `eng` V-8 / `aia` AUT-128 (team view equals `order_offers`), `lca` D-44 (2) (a) (no team count to the client), CGR-215 (b), (c), the BK-5 template (`docs/design/BK5_OFFER_TEMPLATE.md`) and BK-5a, BK-5n, BK-6. Any open clinical or legal point cuts the slice smaller; it is not built as an assumed rule.

## PO amendment 2026-11-17 03:39 (scheduled PO run): BK-c in three PRs; take-over right in Phase A

Read: draft PR #1342 (head `b6f4cb7`), ADR-199 (PROPOSED, on the branch), `eng` journal `2026-11-17-0310-eng.md`. This is not a review of the merged state and not an acceptance; the PO ran no test.

1. **BK-c sub-slices (decided, on `eng` ADR-199 (1), README rule 11):** BK-c1 database (take, decline, screening rounds, team offer list, derived cover state, `order_not_covered`, re-coverage, backfill), BK-c2 screens (`/team` offer card, `/order` client status, `uxa` words, 390/1440 px screenshots in a PR comment, 21:39 (5)), BK-c3 ranking and reasons (BK-3, BK-4; deterministic facts first; Engine 2 only on synthetic data, D-35 rule A; `aia`). Order: BK-c1 first; BK-c2 and BK-c3 after it, in either order, one at a time. **One BK-c acceptance after all three**, on a named integrated commit (FE-071 (4)). The slice-list sentence «one PR each» is read as «one PR per sub-slice».
2. **Take-over right inside a team (decided for Phase A, simulation only; product rule, not a clinical rule):** every active member of a team that holds an offer row in the current round may take or decline for her team. There is no team-lead or coordinator role for this (FE-039; value 4, team autonomy). Operations, a coach and a client never take (BK-5n). The named member may be the caller or another active member of the same team, and only if that member passes `private.order_member_step` at the take (CGR-204 (b), AUT-130). Revisable when the Phase B partner's team rules are known.
3. **BK-c2 criterion (from 2.):** the named member sees her own take on `/team` (and, once BK-e exists, on `/field`); words `uxa`. Negative test: a member of another team never sees it.
4. **Question to `cra` (OPEN, before the BK-c acceptance, not a BK-c1 gate):** does a take that names a colleague need that colleague's acknowledgement before shift start (hazard: a named person who does not know she is named)? If yes, the substance is `cra`'s and the words `uxa`'s; the PO sets no rule here.
5. **Before the BK-c1 gates (from ADR-199, named by `eng` as PLANNED/UNKNOWN):** the two-session race script `scripts/db-concurrency/order-take.sh` in the PR and in `db`/`ci-repeat`; the list of every writer of `member_absences`, `member_access_events`, `member_qualification_evidence` and `care_visits` in the PR description, each shown to fire the re-check (CGR-223). The coverage lead of 240 min stays a simulation default, PROPOSED, with the Clinical Owner before real data (K-8); `order_not_covered` priority P2 stays PROPOSED until `cra` reads it (CGR-226).
6. **Gates on BK-c1:** `cra` (CGR-211, CGR-222 (c), CGR-223, CGR-224, CGR-225, availability sources), `lca` (D-44 (2) (a) no team count to the client; RLS: the client reads no take, decline or offer row), `aia` (V-8 / AUT-128 team view equals the offer rows; AUT-130 one member step). `uxa` only if BK-c1 changes a visible word (the `eng` journal says the client screen is unchanged).

Owners: `eng` (1, 3, 5), `cra` (4, 6), `lca` (6), `aia` (6), `uxa` (3). PO status of BK: **active**, slice BK-c (sub-slice BK-c1 in progress).

## PO amendment 2026-11-17 04:39 (scheduled PO run): BK-c1 ready for the gates; F-1 and UXR-221 placed in BK-c2

Read: PR #1342 (ready for review, head `9543ad1`), `eng` comment 04:37 and journal `2026-11-17-0410-eng.md` (on the branch), `lca` journal `2026-11-17-0420-lca.md` (#1345, merged), `uxa` journal `2026-11-17-0348-uxa.md` and `UX_REVIEW.md` 03:48 (#1344, merged). Not an acceptance; the PO ran no test. CI facts from the GitHub API and raw job logs.

1. **03:39 (5) done on the branch (interim evidence, not a merge).** `ci` 44010045598 on `9543ad1`: `app`, `ui-screenshots` success; `db` job 133794743572 raw log «Files=142, Tests=5055 … Result: PASS» and step `concurrency-order-take`: «two parallel takes: one wins, the other gets "already_taken"», «two teams: … live takes: 1; take rows: 1»; `e2e` job 133794743321 raw log «182 passed», no skipped, flaky or failed line. Writer list: ADR-199 addendum 04:25 (one gap found and fixed in 0135: `remove_team_member`, red pgTAP 142 observed first on `66e219c`). Red-first held twice (FE-071 (2)).
2. **Gate state on `9543ad1`:** `lca` clear on `10dd576`; `10dd576..9543ad1` changes only `scripts/db-concurrency/order-take.sh`, outside `lca`'s named scope; `lca` re-confirms in its next run. `cra` and `aia`: no line yet. **No merge this run** (§4 (2), FE-071 (3)). #1342 stays the next Engineering merge.
3. **BK-c2 criterion F-1 (from `lca`, placed):** the client read model (`client_orders()` and `/order`) shows **one** neutral zero-state detail for «no eligible team» and «all declined»; Operations keeps the full detail in `order_not_covered`. Negative test: a client never reads `all_declined` or `no_team_eligible` as separate values. If `cra` names a safety need for the difference, this becomes an owner question and is not built as assumed. Owner `eng`, words `uxa`.
4. **BK-c2 criterion UXR-221 (from `uxa`, placed):** the own team's card stays on `/team` after its take, state «Übernommen», naming the going person; the named person sees the shift as hers, also when a colleague took it; no primary button in BK-c (no un-take is specified). Playwright 390: after member A takes naming member B, A's and B's `/team` show the card with «Übernommen» and B's first name; a member of another team sees neither (refines 03:39 (3)). `uxa` extends `BK5_OFFER_TEMPLATE.md` §3. First names to other team members: `lca` G-5 (e) before real use. If `cra` answers 03:39 (4) with «acknowledgement needed», the acknowledge action replaces «no primary button» for her.
5. **Open, unchanged:** 03:39 (4) acknowledgement (`cra`); lead 240 min (K-8) and `order_not_covered` P2 (CGR-226) PROPOSED.

Owners: `cra`, `aia` (gate lines on `9543ad1`), `lca` (re-confirm), `eng` (3, 4 in BK-c2), `uxa` (template rows). PO status of BK: **active**, slice BK-c (BK-c1 awaiting gates).

## PO amendment 2026-11-17 05:39 (scheduled PO run): CGR-229 before the BK-c1 merge; CGR-230 and CGR-232 placed; #1337 merged

Read: `cra` journal `2026-11-17-0529-cra.md` and `CLINICAL_GOVERNANCE.md` 05:29 (#1347, merged `969350f`), `cra` gate comments on #1342 and #1337. Not an acceptance; the PO ran no test.

1. **#1337 / ADR-198 merged** (`abaddca`, head `0290404`, `cra-gate: #1337 0290404 clear`, CGR-228 met). BK acceptance tooling only; it changes no BK criterion. A label stays a pointer: every acceptance still reads the raw logs for 0 skipped (FE-071 (4)).
2. **CGR-229 before the BK-c1 merge (PO decision).** `cra` cleared `9543ad1` and marked CGR-229 advisory, «preferably in this PR». The PO makes it a merge condition of #1342 because (i) it is a double booking of one person, exactly the hazard BK-c removes from dispatching; (ii) the ADR-199 addendum states that no runtime path leaves a stale live take, and a merged record must not carry a known-false statement; (iii) the fix sits in the function this PR adds. Required on #1342: (a) serialise per person inside `take_order` before the re-check (`eng` chooses the mechanism: advisory transaction lock on the named member or an exclusion constraint on live takes); (b) a third `order-take.sh` case: one person in two teams, two overlapping orders, two sessions at once → exactly one `ok`, the other `member_not_eligible` step 3, exactly one live take; red first if feasible; (c) the ADR-199 `order_takes` writer row corrected. **Also in #1342** (same head move, cheap): the CGR-225 (b) test for a release whose new round has no eligible team. Then fresh gate lines on the new head from `cra`, `lca` and `aia` (AUT-50).
3. **CGR-230 placed in BK-c2 (PROPOSED, simulation only; substance `cra`, words `uxa`).** This answers 03:39 (4). A take that names a colleague other than the caller needs that colleague's acknowledgement; if she has not acknowledged by `latest_cover_at`, the take counts as released (re-coverage as for any release, ADR-199). Her `/team` card (UXR-221) then carries one primary action «Bestätigen» instead of «no primary button». Positive test: B acknowledges → take stays live; negative tests: no acknowledgement by `latest_cover_at` → released and the order is re-offered; a member of another team cannot acknowledge; a take naming the caller herself needs no acknowledgement. The lead time behind `latest_cover_at` (240 min) stays PROPOSED with the Clinical Owner (K-8). BK-c2 thereby has a small database part; it stays one PR.
4. **CGR-232 placed** as a criterion of the slice that first writes a visit from a take (BK-e or later): step 3 of the re-check excludes the visit written from that same take; pgTAP: writing the visit does not release the take of the person who is coming.
5. **F-1 settled without an owner question.** `cra` names no safety need for the client to see the cause; the need is the next step (CGR-226 (b)). F-1 stays as placed 04:39 (3). The zero state is designed around the client's next step; its substance stays OPEN with `cra`/Clinical Owner (CGR-226), words `uxa`.
6. **CGR-231** (`order_not_covered` P2 never escalates after the start) stays PROPOSED with the Clinical Owner (CR-226); not set by the PO.
7. **Challenge hypothesis H-BK-05:39 (PLANNED, measure only):** every acknowledgement is a coordination step. If the take names the caller by default and naming a colleague is the explicit exception, most takes need no acknowledgement. Measure in the simulation the share of takes that name someone other than the caller; if it is high, ask `uxa` and `aia` why the team does not let the going person take herself.

Owners: `eng` (2, then 3 in BK-c2), `cra` (2 gate, 3 substance, 5, 6), `lca` (2 re-confirm), `aia` (2 gate: V-8 / AUT-128, AUT-130), `uxa` (3 words, 5 words). PO status of BK: **active**, slice BK-c (BK-c1 changes requested: CGR-229, CGR-225 (b)).

## PO amendment 2026-11-17 06:39 (scheduled PO run): BK-c1 change request met on `abe0c5d`; awaits fresh gates

Read: `eng` comment 6939600897 on #1342, diff `9543ad1..abe0c5d` (migration 0135, pgTAP 143, `order-take.sh`, ADR-199 addendum 06:20), `ci` 44023229539 check runs and the raw `db` log. Interim review, not an acceptance; the PO ran no test.

| Criterion (PO 05:39 (2)) | Result | Evidence |
|---|---|---|
| CGR-229 (b) red first | met | `0e0a581`, `db` job 133835499750 failure «live takes of M1: 2» (journal `eng` 06:20; PR comment 6939309384) |
| CGR-229 (a) one person cannot be taken on two overlapping orders in two sessions | met (CI) | `take_order`: `pg_advisory_xact_lock(hashtextextended('order_take_member:' \|\| member, 0))` before `order_member_step`; lock order order row, then person (no cycle); `db` job 133837476095 race case 3 «member_not_eligible:3 ok ; live takes of M1: 1; take rows: 1» |
| CGR-229 (c) writer list | met | ADR-199 `order_takes` writer row corrected, addendum 06:20 |
| CGR-225 (b) empty new round | met (CI) | pgTAP 143 (14 assertions, positive and negative) «ok»; «Files=143, Tests=5069 … Result: PASS» |
| CI on head | green | `app` 133837476189, `db` 133837476095, `e2e` 133837476226 (182 passed per `eng`), `ui-screenshots` 133837476203: all success; `mergeable_state` clean |

1. **Merge still waits** for fresh gate lines on `abe0c5d` from `cra`, `lca`, `aia` (§4 (2), (3); AUT-50: the `cra` clearance names `9543ad1` and the diff touches `supabase/`).
2. **Residual (ADR-199 addendum 06:20), PO decision:** a visit written by another writer at the same instant as a take is **placed with CGR-232** as a criterion of the slice that first writes a visit from a take (BK-e or later), with a two-session race case there. It does not block BK-c1: BK-c1 writes no visit. `cra` may raise it as before-merge if it sees otherwise.
3. **Challenge hypothesis H-BK-06:39 (PLANNED, proposal to `uxa`/`aia` for BK-c2):** the person lock makes a failed take visible only after the tap («member_not_eligible»). If the offer list on `/team` shows per offer whether the caller herself is free for it (same `order_member_step`, read only), a nurse never taps an order she cannot take, and the race becomes the rare case. Measure in the simulation: share of takes refused with `member_not_eligible`. No new rule; the deterministic check stays the only gate.

Owners: `cra`, `lca`, `aia` (gate lines on `abe0c5d`), `eng` (none until gates), `uxa`/`aia` (3). PO status of BK: **active**, slice BK-c (BK-c1 awaiting gates on `abe0c5d`).

## PO amendment 2026-11-17 08:39 (scheduled PO run): `lca` and `aia` gates on `abe0c5d`; UXR-222, UXR-223, AUT-132 placed in BK-c2

Read: `lca-gate: #1342 abe0c5d clear` (comment 6941551680, journal `2026-11-17-0821-lca.md`), `aia-gate: #1342 abe0c5d clear` (comment 6941528774, journal `2026-11-17-0825-aia.md`), `uxa` `UX_REVIEW.md` 07:52 and issue #1351. Not an acceptance; the PO ran no test.

| Merge condition of #1342 on `abe0c5d` | Result | Evidence |
|---|---|---|
| §4 (1) CI | green | check runs `app`, `db`, `e2e`, `ui-screenshots` success (run 44023229539, read 06:39; head unchanged) |
| §4 (3) `lca` | met | `lca-gate: #1342 abe0c5d clear` |
| `aia` gate (V-8 / AUT-128, AUT-130) | met | `aia-gate: #1342 abe0c5d clear` |
| §4 (2) `cra` on the current head | **open** | last `cra` line names `9543ad1`; `9543ad1..abe0c5d` touches `supabase/` and `scripts/` (AUT-50) |

1. **#1342 merges once `cra` names `abe0c5d`** and the head is unchanged; no other open condition from the PO side.
2. **UXR-222 (#1351) placed in BK-c2 (PO decision, simulation only).** The named colleague gets, beside «Bestätigen», the action «Ich kann nicht». It releases the take at once through the existing ADR-199 release path (new round of offer rows, or `order_not_covered` when no team is eligible); no reason asked or stored; no team keeps a first right in Phase A (the new round follows the same deterministic `order_member_step`, so her own team takes again if another member passes). Reason: a known non-availability must reach the system when it is known, not at `latest_cover_at`, and the team corrects itself without a dispatcher (value 2, 4). Acceptance criteria: the five testable lines of #1351, plus a pgTAP case on the release reason (step code only). `cra` confirms the substance (release on «Ich kann nicht») and the safety-state words before the BK-c2 merge; `lca` confirms that no reason is stored or shown.
3. **UXR-223 decided for the simulation (CGR-230 leaves it to `po`/`uxa`).** While a take names a colleague who has not yet acknowledged, the client reads «Noch nicht gedeckt» with the `uxa` 07:52 detail; «Gedeckt» only after the acknowledgement or on a self-named take. Safety first: a client must not stop looking for cover on a take that can still lapse. Negative test: before the acknowledgement the client view never reads «Gedeckt». `cra` and `lca` may ask for a change before the BK-c2 merge.
4. **AUT-132 (low) placed in BK-c2**, together with H-BK-06:39: the offer card shows the caller only her own «frei / nicht frei» from `order_member_step` (read only); a colleague picker lists only members at step 4 and never shows a colleague's failing step. Negative test: no step code of another member reaches the caller.
5. **Template:** `uxa` transfers the UXR-221 rows and the 07:52 words into `BK5_OFFER_TEMPLATE.md` §3 in its next PR; `eng` builds BK-c2 from the template, not from the report.
6. **Challenge hypothesis H-BK-08:39 (PLANNED, proposal):** a nurse who knows she cannot work a shift should never need a colleague to undo it. If «Ich kann nicht» is as cheap as «Bestätigen», the measure is the time from take to release in the simulation (median minutes before `latest_cover_at`); the target is that releases arrive hours, not minutes, before the coverage time. No new rule.

Owners: `cra` (gate line on `abe0c5d`; substance of (2)), `lca` (2), (3), `uxa` (5), `aia` (4), `eng` (BK-c2 after the BK-c1 merge). PO status of BK: **active**, slice BK-c (BK-c1 awaiting the `cra` line on `abe0c5d`).

## PO amendment 2026-11-17 09:39 (scheduled PO run): BK-c1 (#1342) merged; CGR-234 and CGR-233 placed

Read: `cra-gate: #1342 abe0c5d clear` (comment 6942849366, `CLINICAL_GOVERNANCE.md` 09:30, journal `2026-11-17-0930-cra.md`, PR #1356). Merge record: PR #1342 comment 6943080778. Not an acceptance; the PO ran no test.

| Merge condition of #1342 on `abe0c5d` | Result | Evidence |
|---|---|---|
| §4 (1) CI | green | `ci` 44023229539: `app` 133837476189, `db` 133837476095, `e2e` 133837476226, `ui-screenshots` 133837476203, `sync` success; `mergeable_state` clean |
| §4 (2) `cra` on the current head | met | `cra-gate: #1342 abe0c5d clear`; CGR-229 (a)–(c), CGR-225 (b) met; «Blocked: nothing» |
| §4 (3) `lca` | met | `lca-gate: #1342 abe0c5d clear` |
| `aia` gate | met | `aia-gate: #1342 abe0c5d clear` |
| §4 (5) review threads | met | 0 threads, no review |
| Merge | done | `781944f` (merge commit, expected head `abe0c5d`) |

1. **BK-c1 merged, not accepted.** One BK-c acceptance after BK-c1 to BK-c3 (03:39 (1)), on an integrated commit with `ci` green and `ci-repeat` 10/10 (`db`, `e2e`), gate «Simulation, synthetic data».
2. **CGR-234 placed in BK-c2 as acceptance criteria of «Ich kann nicht» (08:39 (2)), PROPOSED for the simulation:** (a) a person's release gets its own release code distinct from step codes, and `released_by`; no reason field; (b) a release near `latest_cover_at` (± 1 min) raises `order_not_covered` at once when no team is eligible; (c) after `starts_at` the action is refused or raises an exception, never a silent release; (d) the taker and her team see the release. pgTAP for (a)–(c), e2e for (d). `lca` confirms `released_by` under G-5 before the BK-c2 merge.
3. **UXR-223 confirmed by `cra`** («Noch nicht gedeckt» until the acknowledgement); 08:39 (3) stands.
4. **CGR-233 (S2) placed with CGR-232** in the slice that first writes a visit from a take: visit writers take the same `order_take_member:` key before their conflict check, plus a two-session case visit against take. Not a BK-c2 condition.
5. **H-BK-08:39** supported by `cra` as a measure; no target value set.

Owners: `eng` (BK-c2 PR: ADR addendum and red tests first, FE-071 (2)), `uxa` (template rows, CGR-226 words), `lca` (`released_by`, F-1 words), `cra`, `aia` (BK-c2 gates). PO status of BK: **active**, slice BK-c (BK-c1 merged; BK-c2 next).

## PO amendment 2026-11-17 10:39 (scheduled PO run): merge-commit CI of BK-c1 green; PO pre-read of ADR-200 (#1358, draft) and the open points it names

Read: PR #1358 (draft, head `6de96b0`, `ci` 44057327890 running at the PO read; ADR-200 PROPOSED, eng 10:15); journal `2026-11-17-1015-eng.md` on the branch. Not a review of code, not an acceptance; the PO ran no test.

| Check | Result | Evidence |
|---|---|---|
| §5 merge-commit CI of #1342 (`781944f`) | green | `ci` 44048826903 push: `app` 133921182918, `db` 133921183371, `e2e` 133921183374, `ui-screenshots` 133921183226 all success |
| #1358 red-first order (FE-071 (2)) | met per PR text | commit `863ff98` tests and ADR-200 only, migration after |
| #1358 merge conditions | not yet | draft; CI running; no `cra`, `lca`, `aia`, `uxa` line |

1. **No revert needed.** BK-c1 stays merged on `781944f`; not accepted (one BK-c acceptance after BK-c3).
2. **ADR-200 against the placed criteria (PO reading, PLANNED until merged):** CGR-230 (1), (2); UXR-222 and CGR-234 (a)–(c) (2), (3); F-1 and UXR-223 (5) (client reads «kein Team frei» / «Deckungszeit erreicht» / «wartet auf Bestätigung» with no team name); UXR-221, CGR-234 (d), AUT-132 (6). Nothing in the ADR adds a third action to the named colleague (H-BK-09:39 holds: «Bestätigen», «Ich kann nicht»).
3. **PO decisions on the open points ADR-200 names (product scope, Phase A simulation only; no clinical rule):**
   - (a) *Taker withdraws a pending take:* **not in BK-c2.** The named colleague's «Ich kann nicht» and the lapse at `latest_cover_at` already release it; a second release path would add a writer and a word. Re-open only if the simulation shows takes naming the wrong colleague.
   - (b) *«Ich kann nicht» after the acknowledgement:* **refused in BK-c2, as the ADR proposes.** A confirmed person who later cannot go is a short-notice absence, not a take decision; it belongs to the absence-coordination path (B3), not to BK-c. OPEN for `cra`: does an acknowledged take that falls away before `starts_at` need the same immediate `order_not_covered` path as CGR-234 (b)? Answer before the BK-c acceptance, not before the BK-c2 merge.
   - (c) *ADR-200 (4) (her «Ich kann nicht» blocks her for that order only):* matches PO 08:39 (2); `cra` confirms the substance in its gate, as the ADR says.
   - (d) *Team name hidden from the client while the acknowledgement is pending (ADR-200 (5)):* stands for the simulation (UXR-223). `lca` may still ask for it under G-3.
   - K-8 (240 min lead) and `released_by` under G-5 stay with `cra`/Clinical Owner and `lca`; not decided here.
4. **Gates on #1358 when it leaves draft:** `cra`, `lca`, `aia` on the database part; `uxa` on the screens (visible words). All on the same head (AUT-50).

Owners: `eng` (#1358 migration and screens), `cra` (3 (b), (c)), `lca` (G-5, G-3), `uxa`, `aia`. PO status of BK: **active**, slice BK-c (BK-c1 merged, merge-commit CI green; BK-c2 in draft #1358).


## PO amendment 2026-11-17 11:39 (scheduled PO run): BK-c2 screens on #1358; what must be on the PR before it leaves draft

Read: PR #1358 (draft, head `7ebfd8e`, docs-only on top of `f3ea229`; `ci` 44066772979 running at the PO read); journal `2026-11-17-1115-eng.md` and ADR-200 addendum 11:15 (PROPOSED) on the branch. Not a review of code, not an acceptance; the PO ran no test.

| Check | Result | Evidence |
|---|---|---|
| `ci` on `recovery/main` `b3794e8` (PO merge #1359) | green | push 44059683782, PR 44059694935 success |
| #1358 red-first for the screens (FE-071 (2)) | met per PR text | `5677cc5` adds only `tests/unit/bk-c2-offer-states.test.ts`; implementation `6c81179` after |
| #1358 last code head `f3ea229` | 4/4 green per `eng` | `ci` 44065373848 (`app`, `db` 144 files PASS, `e2e` 184 passed, `ui-screenshots`); job logs not read by the PO this run |
| Changed existing test `bk-a-order.spec.ts` | named, not weakened (PO reading) | the BK-a placeholder «Stand: noch nicht gedeckt» replaced by the created order's own card and the F-1 words |
| #1358 merge conditions | not yet | draft; CI running on `7ebfd8e`; no gate line |

1. **Required on #1358 before it leaves draft (PO decision, product scope, simulation only):** the Playwright path of a take naming a colleague is a BK-c2 acceptance test, not optional. Positive: the taker names a colleague of the same team, the colleague sees «Für dich eingeteilt» first and confirms; a second case where she presses «Ich kann nicht» and the order is offered again. Negative: a member of another team never sees her card; the client reads «Noch nicht gedeckt» until the confirmation. pgTAP 144 and vitest do not replace it, because the visible path is what the slice delivers.
2. **Seed addition approved for this (synthetic only):** one more synthetic member with the same grade in one team, named in the PR. `eng` states in the PR which other BK specs' orders then reach that team and that their assertions are unchanged; any changed assertion is named, as for `bk-a-order.spec.ts`. No real name, no real address.
3. **Screenshots 390/1440 as images in a PR comment** (PO 2026-11-16 21:39 (5)) stay required before `uxa` gates; produced from CI artefacts is enough.
4. **Deviations in ADR-200 addendum (4), PO position (PLANNED until merged):**
   - No next-step line under «Nicht gedeckt»: **accepted for BK-c2** (cut smaller, FE-070 (3)); the line waits for `cra`/Clinical Owner (CGR-226 (b)). No invented line.
   - No relative time on the open client state: left to `uxa` in its gate; not a merge condition unless `uxa` asks.
   - No team name on «Nicht mehr gedeckt»: stands for the simulation (UXR-223, PO 10:39 (3)(d)).
   - Price line and «Warum empfohlen»: BK-c3, as placed (`aia`).
   - First names visible to the own team only: stands for Phase A; `lca` G-5 (e) before any real use.
5. **Challenge (PLANNED) H-BK-11:39:** the changed BK-a test shows an order no team could take because no member holds the grade. A team should see this as a fact about itself, not only the client as «Kein passendes Team ist frei»: «Diesen Monat 3 Aufträge nicht möglich: Stufe FaGe fehlt im Team». That turns lost orders into the team's own staffing decision (value 4 team autonomy, 3 income) without a dispatcher telling them. Not in BK-c; brief candidate after BK, aggregate counts only, no client data; `lca` and `aia` to check. Measure: share of not-covered orders whose only exclusion reason is grade (no target value).

Owners: `eng` (1–3 on #1358), `uxa` (relative time, words, screenshots), `cra` (CGR-226 (b); PO 10:39 (3)(b) still open), `lca` (G-5 (e)), `aia` (BK-c3). PO status of BK: **active**, slice BK-c (BK-c1 merged; BK-c2 in draft #1358).

## PO amendment 2026-11-17 12:39 (scheduled PO run): UXR-224 to UXR-228 and `lca` F-2 placed for BK-c2

Read: PR #1358 (draft, head `cb84250`; `ci` 44074369513 4/4 success per check runs, job logs not read by the PO); `eng` watch note 11:27 UTC (colleague-path spec `bk-c2-colleague-take.spec.ts` failed on `a96e33f`, card not re-read after «Bestätigen»; later head green); `uxa` `UX_REVIEW.md` 11:48 and issue #1361 (merged #1362); `lca` `decisions/D-44.md` 12:22 (merged #1363). Not a review of code, not an acceptance; the PO ran no test.

| Check | Result | Evidence |
|---|---|---|
| `ci` on `recovery/main` `3ff15e4` (PO merge #1360) | green | push 44069050555, PR 44069060945: `app`, `db`, `e2e`, `ui-screenshots` success |
| #1358 head `cb84250` | 4/4 green, still draft | `ci` 44074369513 (check runs API) |
| Colleague-path Playwright (PO 11:39 (1)) | on the branch; red on `a96e33f`, green on `cb84250` per check runs | `eng` comment 11:27 UTC; whether every 11:39 (1) case is covered is for `eng` to state in the PR |
| Screenshots 390/1440 in a PR comment (11:39 (3)) | not yet | no image comment on #1358 |

1. **UXR-224 (high, #1361) is a BK-c2 merge criterion (PO decision, product scope, simulation).** «Ich kann nicht» and «Ablehnen» open an inline step with one consequence sentence, the action and «Zurück»; the first tap writes nothing. One line under «Bestätigen» says the confirmation is final. Words: `uxa` 11:48 (template §3, PROPOSED); `cra` confirms the sentences as safety-state words before its gate line. Tests: Playwright 390, one tap writes nothing (offer row unchanged), «Zurück» restores the card, the second action releases or declines. Why: a slip of the thumb near `latest_cover_at` loses cover the team wanted to give (value 1, 2; safety precondition); two taps keep the take fast.
2. **UXR-225 with `lca` F-2: one rule for the client after a take falls away (PO decision, simulation).** (a) A take released or lapsed **before** the client ever read «Gedeckt» reads «Noch nicht gedeckt · Beginn …», never «Nicht mehr gedeckt». (b) After «Gedeckt» was shown, «Nicht mehr gedeckt» carries a detail that names **no person and no cause** (`lca` F-2; e.g. «Die Übernahme gilt nicht mehr. Das Angebot geht wieder an alle passenden Teams.»). Words owned by `uxa`, confirmed by `cra`; `eng` adds the distinguishing `cover_detail` in the client read model only. Negative tests: A names B, B presses «Ich kann nicht» → the client card never contains «Nicht mehr gedeckt»; an acknowledged take dropped by the ADR-199 safety net → the client card contains no «Person kann nicht». BK-c2 merge criterion (`lca` asks it before its gate line).
3. **UXR-226 placed in BK-c2:** with no candidate, one line «Niemand in eurem Team kann diese Schicht zurzeit übernehmen.», no «Du selbst …» line, no disabled primary; «Ablehnen» (with the step of (1)) stays. Vitest: empty candidates → no button «Person wählen». `lca` confirms no reason is implied.
4. **UXR-228 placed in BK-c2 (low):** footer words per template §2 (8); `cra` confirms.
5. **UXR-227 stays as placed 11:39 (4):** not a BK-c2 condition; the next-step line under «Nicht gedeckt» is required before any gate «released for real persons and data»; substance UNKNOWN (`cra`, Clinical Owner).
6. **`lca` H-2 and H-5 recorded as conditions before real use (PLANNED, not BK-c):** release rows not readable under purpose `billing` (or `released_by` classed so), retention with D-4; members' privacy notice on names and release categories seen by colleagues; `org_members_read` narrowed before more than one provider shares an organisation. Owner decisions where `lca` says «needs owner»; the PO decides none of them here.
7. **H-BK-11:39 data scope:** `lca` H-6 (i)–(v) (counts per period and grade only, own reach, cells under 5 shown as «weniger als 5», no other team, no person) become criteria of the later brief; across organisations it waits for the legal adviser (E-4).
8. **Label correction:** the 10:39 «G-3» and 11:39 «G-5 (e)» references pointed to the wrong `lca` points; the questions are answered in D-44 12:22 H-4 and H-5.

**Challenge (PLANNED) H-BK-12:39:** «Ich kann nicht» is today the only way a named colleague can hand a shift back, and it sends the shift to every team. In a self-organised team the natural move is a swap inside the team first: «Ich kann nicht · Kollegin fragen» would re-offer only to the own team's members who pass every check, and to all teams only if nobody takes it before a team-set time. Fewer orders leave the team (value 2 continuity, 3 income, 4 autonomy), no dispatcher. Not in BK-c (no new rule: the timing would be a team setting, never invented); `cra` (does a team-internal round delay cover?), `uxa` (words), `lca` (none expected beyond H-5). Measure in Phase A: share of «Ich kann nicht» releases re-taken by the same team.

Owners: `eng` (1–4 on #1358; screenshots), `uxa` (words of 1–4 and gate), `cra` (sentences 1, 2, 4; CGR-226 (b); PO 10:39 (3)(b)), `lca` (3; gate line), `aia` (BK-c3). PO status of BK: **active**, slice BK-c (BK-c1 merged; BK-c2 in draft #1358).

## PO amendment 2026-11-17 13:39 (scheduled PO run): `cra` CGR-235 placed; #1358 still draft

Read: `cra` `CLINICAL_GOVERNANCE.md` 13:28 (merged #1366 as `8a25928`); `lca` `decisions/D-44.md` 12:42, 12:57, 13:27 (merged #1364 as `17ede43`); PR #1358 (draft, head `7f6ae8d`). Not a review of code, not an acceptance; the PO ran no test.

| Check | Result | Evidence |
|---|---|---|
| `ci` on `recovery/main` `245f68c` (PO merge #1365) | green | push 44077837467 success |
| `ci` on merge commits `8a25928`, `17ede43` | running at publication | 44085501981, 44085528030 |
| #1358 head `7f6ae8d` | 4/4 green, still draft | `ci` 44083848265 (check runs API) |
| `cra` pgTAP read on #1358 (`2721f3f`) | 144 files, 5139 tests PASS (read by `cra`, not by the PO) | `cra` journal 13:28 |
| Gate lines on #1358 | none (draft) | PR comments |

1. **CGR-235 (a) placed in BK-c2 (PO decision, product scope, simulation).** A person who confirmed a take sees on her card where to go if she cannot come after all: one line pointing to her absence report, no new release button (the confirmation stays final, 12:39 (1)). Words owned by `uxa`; `cra` confirms; no new rule. Test: Vitest or Playwright 390, a confirmed card shows the line and no «Ich kann nicht». Why: a confirmed person with no visible way out may simply not come (value 2; safety precondition).
2. **CGR-235 (b) is a BK-c acceptance criterion** (not a BK-c2 merge criterion): pgTAP for an acknowledged colleague take that falls away after `latest_cover_at` (answers PO 10:39 (3)(b)). `eng` may add it in BK-c2 or BK-c3; BK-c is not accepted without it.
3. **CGR-235 (c) with UXR-225 (a):** the client detail after «Gedeckt» stays as decided 12:39 (2) (no person, no cause); final words `uxa`, `lca` states whether F-2 covers them before its gate line. S3, BK-c2.
4. **H-BK-12:39 stays PLANNED:** `cra` names four bounds for a team-internal round and no time value; the bound waits for the Clinical Owner (K-8). No brief before that.
5. **`lca` D-44 W/T/V (founder tasks of 2026-11-17)** recorded as FE-080 (Richtung) in `FOUNDER_DECISIONS.md`. No change to BK. The `lca` V-3 wording rules (no «Zuweisung», «Disposition», «Vermittlung», no hour price in order screens) are checked by `lca` in its gate line on #1358; `lca` found the current texts neutral.

Owners: `eng` (1 on #1358; (2) before BK-c acceptance; screenshots; leave draft), `uxa` (words of 1 and 3), `cra` (confirm 1; gate line), `lca` (3; V-3 in gate line), `aia` (BK-c3 unchanged). PO status of BK: **active**, slice BK-c (BK-c1 merged; BK-c2 in draft #1358).

## PO amendment 2026-11-17 14:30 (live session with the founder, FE-084): focus BK-c2

Founder FE-084 (7): PO and Engineering focus on finishing and merging #1358 (BK-c2). No new scope. What #1358 still needs before the PO can merge it (all from the 11:39, 12:39 and 13:39 amendments, unchanged): leave draft; screenshots 390/1440 in a PR comment; UXR-224, UXR-225/F-2 with CGR-235 (c), UXR-226, UXR-228, CGR-235 (a) on the head; gate lines of `cra`, `lca`, `aia`, `uxa` on the same head; `ci` 4/4 green on that head. CGR-235 (b) before BK-c acceptance.

Wording rule now binding for every screen (FE-083, FE-084 (4); Blueprint Anhang C §1.3 (10)): the platform says «Pflegeauftrag» / «Auftrag», never «Zuweisung», «Disposition», «Vermittlung»; the medical «Zuweisung» of a case stays allowed. `lca` checks it in its gate line on #1358 (V-3/G-5). The data model stays neutral to the legal form (no field fixing a person's AHV status; D-44 `lca` 13:53 (i)). Genossenschaft, employer role and payroll are not part of BK (PLANNED, after BK).

## PO amendment 2026-11-17 14:39 (scheduled PO run): FE-085, placement of AUT-135; #1358 still draft

Read: `aia` `AUTOMATION_REVIEW.md` reviews 63, 64 (merged #1371 as `9b18f00`); own live PR #1370 merged as `84655da`; PR #1358 (draft, head `e68a490`). Not a review of code, not an acceptance; the PO ran no test.

| Check | Result | Evidence |
|---|---|---|
| #1371 head `a0f7ac2` | 4/4 green, merged | `ci` 44094859298 (check runs API) |
| #1370 head `cd585db` | 4/4 green, merged | `ci` 44093639460 (check runs API) |
| #1358 head `e68a490` | draft; `ci` 44095130870 running (app success, db/e2e/screenshots in progress at reading) | check runs API |
| Gate lines on #1358 | none (draft) | PR comments |

1. **FE-085 recorded** in `FOUNDER_DECISIONS.md` v32 (founder messages in the `aia` session, not heard by the PO). No change to BK-c scope or to the BK-c2 merge criteria.
2. **AUT-135 placement (PO decision under README rule 12, `aia` AUT-136 (2)):** AUT-135 is **preparation for BK-d** (AI capture on synthetic data). `eng` may build on a branch now: the provider-neutral adapter interface, a deterministic fake used in CI, the control layer (proposal ledger, source per value, named confirmer with signature, no accept-all, correction rate per agent and field, stop rule) and red tests. **No merge into `recovery/main` before BK-d is the active slice** (no competing feature merge; FE-085 (3) «Blockregel gilt eisern»). BK-c2 and BK-c3 keep priority for `eng`.
3. **Conditions before the first real call to an external AI interface (synthetic data only, part of the BK-d brief):** (a) `aia` AUT-136 (1): the key exists only in an environment whose database holds only the synthetic seed; one switch stops every call; a test proves no call from an environment with non-synthetic data; (b) AUT-136 (3): the control layer above is merged and tested first; (c) the provider and its terms are chosen by the owner, `lca` reads the terms (also for test data); the PO names no provider; (d) any «KLV-Berichtsextraktion» draft is device level G or H: `cra` gate; whether care under KLV Art. 7 Abs. 2 Bst. b and c without a named assessment instrument meets the duty to assess need (KLV Art. 8) is **UNKNOWN** and goes to `cra` and `lca` (AUT-136 (4)); no rule is set by the PO.
4. **Naming deviation (not changed automatically):** FE-085 (3) calls the slice «BK-d: Schriftausführung /field»; this brief has BK-d = AI capture of the order (BK-1a/b) and BK-e = `/field` link and report draft. PO reading: the real voice-to-report connection waits until the slice that contains it is active (BK-d for capture, BK-e for the report draft), never earlier. The founder may correct the reading.
5. **D-36 and D-37 set aside by FE-085** (interRAI out of current planning); recorded in `OPEN_DECISIONS.md` and `decisions/INDEX.md`; no BK change (BK contains no interRAI content).

Owners: `eng` (#1358 first; AUT-135 on a branch only), `aia` (AUT-136 guard tests in the BK-d brief), `cra`/`lca` (3 (d)), `lca` (3 (c)), owner (provider). PO status of BK: **active**, slice BK-c (BK-c1 merged; BK-c2 in draft #1358).


## PO amendment 2026-11-17 16:40 (scheduled PO run): FE-087 merge procedure for #1358; follow-up items

PO did not run tests locally; facts from the GitHub API.

| Criterion | Result | Evidence |
|---|---|---|
| Not draft | met | `GET /pulls/1358` |
| CI green on head `9a7fc56` | met: `app`, `db` (incl. pgTAP 145), `e2e`, `ui-screenshots`, `staging` success | `ci` 44108460972, check runs API (`head_sha` = `9a7fc56`) |
| `mergeable_state` | clean | `GET /pulls/1358` |
| `lca` gate line | `lca-gate: #1358 9a7fc56 clear` (16:21) | PR comment 6952397890; `decisions/D-44.md` 16:21 |
| `cra` gate line (CGR-235) | **open**: none on `9a7fc56` (pre-read 13:28 on `2721f3f`) | PR comments |
| `uxa` gate line (#1361) | **open**: advisory 15:55 on `58aaf14` only; diff `58aaf14..9a7fc56` under `src supabase tests e2e` is only `tests/unit/stg1-staging-deploy.test.ts` (from #1087 via the `recovery/main` merge); no BK-c2 code change (PO `git diff --stat`); AUT-50 still needs a line naming `9a7fc56` | PR comments |

1. **FE-087 recorded** (`FOUNDER_DECISIONS.md` v34). It replaces the staging check of FE-086 (second entry) (2) and the screenshot condition PO 11:39 (3). The PO merges #1358 when CI is green on the head, the PR is not a draft, and the `cra` (CGR-235) and `uxa` (#1361) gate lines name that head, with the remaining `PO_MERGE_PROCESS.md` §4 conditions (head SHA in the merge call, no open review thread, no blocking finding).
2. **PO decision (follows from FE-087):** the BK-c2 merge criteria of PO 14:30 are reduced to the founder's list. **CGR-235 (c)** (client detail words after «Gedeckt») and **`uxa` UXR-229 to UXR-231** (words PROPOSED; `lca` confirmed UXR-230/231 from its side as follow-up) are **follow-up in BK-c3 or before any real client**, unless `cra` or `uxa` state in their gate line that one of them is a condition; then it stays a merge condition. UXR-232 likewise. CGR-235 (b) stays the BK-c acceptance criterion (pgTAP 145 exists on the branch). UXR-227, `lca` H-2/H-5 stay conditions before any real use.
3. **Ask to `cra` and `uxa`:** gate line on `9a7fc56` in your next run (`cra-gate: #1358 9a7fc56 clear` or a stop with finding ID; `uxa` likewise). `eng` keeps the head still until then (comment 16:25).
4. **After the merge (FE-087 (3)):** merge-commit CI must be green, else a revert PR from `eng`; `eng` applies migration 0136 to `navora-staging`; the founder tests `/team` live. #1361 (UXR-224) is closed by the PO only after the merge, with the merge commit.
5. **AI gate line:** FE-087 names `cra` and `uxa`; an `aia` gate line is welcome but not a merge condition for #1358 (`aia` pre-read 13:25 found AUT-128, AUT-130, AUT-132 met on the branch; no blocking AUT finding open).

PO status of BK: **active**, slice BK-c (BK-c1 merged; BK-c2 #1358 ready, waiting for two gate lines).

## PO amendment 2026-11-17 17:39 (scheduled PO run): BK-c3 scope from the `eng` draft #1381; #1358 still waits for the `uxa` line

PO did not run tests locally; facts from the GitHub API.

| Criterion (#1358, head `9a7fc56`) | Result | Evidence |
|---|---|---|
| CI green, not draft, `mergeable_state` clean | met (unchanged since 16:40) | `ci` 44108460972; `GET /pulls/1358` |
| `lca` gate line | met, 16:21 | PR comment |
| `cra` gate line (CGR-235) | **met**: `cra-gate: #1358 9a7fc56 clear` (17:29) | PR comment; `CLINICAL_GOVERNANCE.md` 17:29 (merged with #1382) |
| `uxa` gate line (#1361) | **met**: `uxa-gate: #1358 9a7fc56 clear` (17:48) | PR comment |
| Merge | **#1358 merged `25d7cdf`** (head `9a7fc56`); #1361 closed | merge record comment on #1358 |

**BK-c3 decisions (PO, product scope; answers to draft §5; no clinical rule set):**

1. BK-c3 = reason line per (order, own team) from stored facts plus, at most, the order of the team's own list. **No ranking between teams** is stored, returned or shown (FE-078 (2), ADR-199 (8), D-44 (2) (a)). This supersedes the cascade wording of BK-3 «the best-ranked team receives the offer first».
2. **List order A** (`starts_at` first, then ids) in Phase A (`cra` CGR-236 (a)). B (lexicographic, AUT-113 (1)) PLANNED, only after the Clinical Owner rules on continuity against time to start (CGR-196, K-8). **Deviation:** FE-078 (1) «orders the list and explains it»; in Phase A the ranking explains only. Reported, not changed.
3. `knows_client`: ended, acknowledged, never released take of the same team for the same `client_account_id`; no time window in Phase A; window before real persons OPEN (PO with Clinical Owner).
4. `holds_all_tags` only if step 2 checks evidence for every tag (CGR-236 (b) pgTAP); else dropped.
5. Language and practice experience: out of BK-c3 (no data source; staff data, `lca` Annex C). FE-073 (3) stands; separate later item, `lca` first.
6. Price line out until `lca` AUT-119 (c).

**BK-c3 acceptance criteria added (positive / negative):** pgTAP 146 (1) each clause present with its fact and absent without it; (2) row set of `team_order_offers()` unchanged by reasons (AUT-128 / V-8); (3) no `rank`, `score` or count column; (4) other team and client read no reason; (5) released, lapsed and not-ended takes give no `knows_client`; (6) order A asserted. vitest: unknown clause code shows nothing. Playwright 390/1440: reason line on the seeded team card. Gates: `cra`, `uxa` (words), `aia` (rule only, AUT-115), `lca` only if a staff-data field is added (none planned).

PO status of BK: **active**, slice BK-c (BK-c1 and BK-c2 merged, not accepted; BK-c3 scoped, PR may open; BK-c accepted only after BK-c3 on a named commit with `ci-repeat` 10/10).

## PO amendment 2026-11-17 19:39 (scheduled PO run): CGR-238 placed for BK-c3 (#1388, draft)

PO did not run tests locally; facts from the GitHub API and the `cra` 19:26 and `eng` 19:15 journals.

| Criterion (#1388, head `5c6f850`) | Result | Evidence |
|---|---|---|
| Not draft, CI green on head | **not met**: draft; `ci` 44149157435 `e2e` in progress at the PO's read (`app`, `db`, `ui-screenshots` success) | `GET /pulls/1388`, check runs |
| `cra` gate line | **not met**: none (CI unfinished at 19:26); CGR-236 (a) to (d) met in code and test per `cra` 19:26 | `CLINICAL_GOVERNANCE.md` 19:26 (#1389, merged) |
| `uxa` gate line (words, UXR-233) | not met: none yet | PR comments |
| `aia` gate line (AUT-115) | not met: none yet | PR comments |

**PO decisions (product scope; no clinical rule set):**

1. **CGR-238 (c) is fixed in #1388, not as follow-up:** when `member_free` is absent for (order, own team), the open card shows **no** «Empfohlen für euch» line, also not with `knows_client`. A recommendation on a card nobody in the team can staff pushes a team toward an order it cannot serve. Positive / negative tests: pgTAP or vitest asserts that `knows_client` alone yields no line; Playwright unchanged for the seeded `member_free` card.
2. CGR-238 (a) (`knows_client` rests on scheduling facts, not on a delivery record) and (b) (team-level fact, not person continuity): accepted as named limits for Phase A, «Simulation, synthetic data»; both OPEN before real persons, together with the `knows_client` window (decision 3 of 17:39; Clinical Owner, CGR-196).
3. Word form (`uxa` 18:48 asks `po`): the colon form «Empfohlen für euch: …» as built stands; `uxa` may still propose other words in its gate.
4. Merge order: #1388 after it leaves draft with green CI on its final head and the `cra`, `uxa` and `aia` gate lines on that head. Then BK-c acceptance on a named integrated commit (`ci` green, `ci-repeat` 10/10).

PO status of BK: **active**, slice BK-c (unchanged).
