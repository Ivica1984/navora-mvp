# Clinical Owner briefing pack

**Prepared by:** Product Owner (`po`), 2026-10-27 11:45 CET, on owner instruction 2026-10-27. **For:** the Clinical Owner once named (G-1, D-27). **Status:** current as of `recovery/main` on 2026-10-27; it is a reading guide, not a decision. The decision packages in [`../decisions/`](../decisions/INDEX.md) are the source; where this pack and a package differ, the package wins.

**What the agents may not do (D-27, owner):** no agent approves a clinical rule. The Clinical & Regulatory Architect (`cra`) and the Legal & Compliance Agent (`lca`) prepare and recommend; their analyses are advisory. **interRAI (owner 2026-10-27):** interRAI can inform, but not replace, your decisions. The *interRAI reference* sections in the packages are written at name level from general published knowledge and are **UNKNOWN until verified** against the licensed documentation (licence scope: [D-36](../decisions/D-36.md)). NAVORA computes nothing from interRAI (D-34).

**What is in force while you have not decided:** every clinical rule in the code is labelled `PROVISIONAL` or `UNVALIDATED` in the [Clinical Rule Register](../clinical/CLINICAL_RULE_REGISTER.md) (on 2026-10-27: 38 PROVISIONAL, 86 UNVALIDATED, 2 mixed, 4 deprecated). The provisional values are strict engineering defaults, not clinical evidence. NAVORA runs on synthetic data only; your decisions gate the first real client, not the build.

---

## 1 How to use this pack

For each decision: read the one-line ask, the default in force and what it blocks, then the package. Answer each ask with **approve**, **approve with changes** (state them), or **reject** (state why). Each answer is recorded in `OPEN_DECISIONS.md` with your name and date; `cra` checks that the code then matches it.

Suggested order: three sittings (section 5). The packages are long (about 460 KB together) because they keep every input and its history; read *Recommended default* and *Owner approval required?* first, then the sections those name.

## 2 Outstanding clinical decisions

Order is the decision index (tier 2 first: decisions named by open clinical findings, then tier 3). "interRAI" rates how much interRAI informs the decision: none, low, partial, substantial.

| # | ID | Question | The ask, in one line | Default in force until you decide | Blocks | interRAI |
|---|---|---|---|---|---|---|
| 1 | [D-28](../decisions/D-28.md) | When a planned visit has not started, or stays `on_the_way`, `started` or `paused`, when is an exception raised, at what priority, to whom? | Approve per visit safety signal a band (earliest P2, latest P1, a window for untimed visits) and the responders; say whether a pause stops the stuck clock (CGR-23); whether teams may choose inside the band; whether a care assistant may take a P1 alone or a registered nurse must take or confirm it (CGR-43) | Strict provisional values; no hand close of a safety signal; no organisation override later than the default; a non-RN take of `no_show` or `visit_interrupted` does not stop the step to Operations (SIG1-C1) | PROVISIONAL label of the CSR1 thresholds; team choice (option C) | none (a nurse-set "zeitkritisch" flag is proposed) |
| 2 | [D-31](../decisions/D-31.md) | How is a visit that was started and then broken off documented and followed up? | Approve 1b (short signed report of the care given; `started_by_mistake` records "keine Pflege erbracht") and set: who may decide *nicht mehr nötig*, the follow-up per reason, whether missed care is made up | Today's behaviour on synthetic data; not billable; go-live condition: care given before a break-off is documented | OPS1 PROVISIONAL label; the first real client | low to partial (reassessment after a hospital transfer proposed) |
| 3 | [D-3](../decisions/D-3.md) (b) | Which clinical fields may a colleague covering a visit read (COVER1 cover read)? | Approve the cover-read field list in package §3 | Cover read off; role read scopes as built (option B); real-data gates in force | Enabling COVER1 for real clients | none |
| 4 | [D-30](../decisions/D-30.md) | Who corrects and signs a visit report when its author has left the team? | (a) field classification (clinical authorship vs administrative); (b) a non-author's addendum stating facts relayed from the former author and how it is marked; (c) which route completes a version returned while its author was unavailable, and any time limit; (d) whether a return naming a clinically relevant error requires a safety follow-up and by when | Refusal as built (CR-048); option D (dated addendum, original unchanged) as the go-live floor; LEAVE1-11 hold | F6's PROVISIONAL correction path; then the legal adviser after D-11 | none |
| 5 | [D-16](../decisions/D-16.md) | Quality event types, severities, which set a quality hold, who lifts it | Approve a team RN who is not the author lifting the billing hold with a reason, with review of serious events by the licensed nursing management; a care-plan review signal instead of an automatic stop of care; name the event taxonomy with severity definitions | Type list empty (no typed event can be recorded); coach or admin lifts; serious events escalate and cannot be closed by hand; "Meldepflicht geprüft" recordable | QG1's relaxation; any typed quality event; then the legal adviser after D-11, D-12 | partial (indicator domains for type names; reassessment check after a serious event) |
| 6 | [D-19](../decisions/D-19.md) | What does a nurse do on site when the client does not open? | Approve the structure of option B (the decision points in `cra` 2026-10-24 22:26) and give its values (whom to call, in what order, how long to wait, when to call emergency services); answer (a) recording from `on_the_way`, (b) whether a care assistant does the on-site steps alone, (c) whether a registered nurse or Operations must be informed, and by when | Option A as built plus SIG1-C1 and SIG2: the no-show is recorded and signalled; no step text in NAVORA | Option B; CR-014 validation; PS-4 | none |
| 7 | [D-17](../decisions/D-17.md) | Which safety alerts must a nurse see before the first visit? | Approve the clinical categories, their form detail, what "unbekannt" requires, review triggers, who may record them and where they appear on the card; whether the key holder's reachability belongs on the card before a first visit | No clinical category; free text as built; form decided (ja / nein / unbekannt plus note, source, append-only, display only) | The clinical half of J1's safety-alert criterion; H-03 | substantial for the category list |
| 8 | [D-34](../decisions/D-34.md) question 7 (clinical half) | May an intake person (an `admin` or `operations` role, not necessarily a nurse) judge how urgent a referral is, and on what basis? | Say whether the intake urgency is a clinical judgement; if yes, who may make it and on what criteria | No preset urgency; its source is recorded ("vom Zuweiser angegeben" / "bei der Aufnahme eingeschätzt", IPA1-7); the urgency orders offers only | The regulatory adviser's answer on D-34 question 7 (owner package) | partial: interRAI has an intake-screening instrument (the Contact Assessment) built for this question; whether the licence covers it: UNKNOWN; NAVORA would record the nurse's judgement, never compute it |
| 9 | [D-15](../decisions/D-15.md) | J1 readiness checklist, J3 care-plan fields, service catalogue and KLV A/B/C mapping | Approve option C with conditions (i)-(iii): the catalogue proposes the service and its KLV category, the team may choose another listed service with a reason, audited and reviewed by a team RN; Abs. 2bis services gated until qualifications show experience (D-29); the readiness checklist plus the three `cra` items; the care-plan fields | As built on synthetic data; no real care plan while the category is chosen freely (CR-001, CR-007); nothing invoiced | J1, J3 clinical sign-off, BL-6, C-1, CR-010; the legal confirmation goes with D-18 | substantial for readiness and care-plan structure; low for the KLV mapping |
| 10 | [D-10](../decisions/D-10.md) | Must a registered nurse countersign the reports of visits a care assistant performed? | Confirm option A for the pilot (countersignature), option B after the pilot on AN2 evidence | Option A as built (countersignature required) | F6 relaxation | none |
| – | [Clinical Rule Register](../clinical/CLINICAL_RULE_REGISTER.md) | 126 rules not yet approved | Review by decision group; most rows are answered by the ten decisions above (column *Decision*) | PROVISIONAL / UNVALIDATED as labelled | Marking any rule clinically approved | – |

Not yours (for orientation): legal questions (D-9, D-18, D-22 and the legal halves of D-15, D-16, D-30, D-31) go to a legal adviser after D-11 and D-12; owner decisions (D-11, D-12, D-29, D-34) are commercial, strategic or regulatory-liability questions. Where the owner's answer changes a clinical package (for example the pilot canton), `po` updates the package and tells you.

## 3 Which decisions stay purely clinical governance after interRAI

Checked per package (*interRAI reference* sections, owner 2026-10-27). "Purely clinical governance" means interRAI offers no guidance that would let the decision be made, or substantially narrowed, from assessment content.

**Purely clinical governance (interRAI informs nothing material):**
- **D-28** thresholds, responders, the pause question and whether a care assistant may take a P1 alone.
- **D-30** all four parts (documentation and authorship are professional and legal questions).
- **D-19** the on-site protocol (not assessed against interRAI in detail; no relevant domain known to the PO).
- **D-10** countersignature, and **D-3 (b)** the cover-read field list.
- In **D-31**: the content of the short report and making up missed care.
- In **D-16**: who lifts a hold, reporting duties, and the taxonomy itself (an incident-reporting taxonomy, not interRAI).

**Informed, but still your decision:**
- **D-15**: readiness item "current needs assessment"; care-plan structure by CAP area. Remains yours: the reassessment interval, mandatory fields, the catalogue and the KLV category per service, deviation rules.
- **D-17**: the candidate category list (falls, cognition and communication, behaviour, home environment, informal helpers; allergies UNKNOWN). Remains yours: the final list, "unbekannt", who records, infection precautions.
- **D-16**: type names aligned with indicator domains; reassessment check after a serious event. Remains yours: severity, "serious", holds.
- **D-31**: reassessment before resuming after a hospital transfer or acute decline. Remains yours: whether required, by when, who decides *nicht mehr nötig*.
- **D-34 question 7**: intake urgency could rest on a recognised intake-screening instrument. Remains yours: whether it is a clinical judgement and who may make it.

No decision becomes non-clinical through interRAI. interRAI shortens the work on D-15, D-16 and D-17; it does not remove a single approval.

## 4 Proposals added to the asks on 2026-10-27 (not in force)

From the *interRAI reference* sections; each is a proposal for you, written as a question, with no effect on the code until you approve it:
1. D-15: readiness item "needs assessment on file and not older than the approved reassessment interval"; and what that interval is.
2. D-16: the review signal after a serious event names "check whether a reassessment is needed"; the event taxonomy from a recognised incident taxonomy, mapped to interRAI indicator domains where they overlap.
3. D-17: the category list starts from the interRAI-covered domains plus infection precautions, each recorded by a registered nurse with source and date.
4. D-28: a "zeitkritisch" flag a registered nurse sets from her assessment; whether it escalates earlier than the band.
5. D-31: after `client_transferred`, the case resumes only after a recorded reassessment or care-plan review by a registered nurse.

## 5 Suggested sittings

| Sitting | Decisions | Why together | Reading |
|---|---|---|---|
| 1 Safety at the visit | D-28, D-19, D-17, D-31 | the signals, the door and the break-off are one chain from a missed visit to its follow-up | four packages, about 130 KB |
| 2 Documentation and access | D-30, D-10, D-3 (b) | who writes, signs, corrects and reads a report | three packages, about 200 KB (D-3 is the longest) |
| 3 Catalogue, quality and intake | D-15, D-16, D-34 question 7, then the Clinical Rule Register by decision group | the service and quality model and the remaining rules | three packages, about 140 KB, plus the register |

Each sitting ends with your answers recorded; `po` updates the packages and the queue the same day, `cra` checks the code against your answers, and Engineering removes the `PROVISIONAL` label only where you approved.

## 6 Pending inputs that may change a package before you read it

- `cra` review of the six *interRAI reference* sections (requested 2026-10-27).
- `lca` on [D-36](../decisions/D-36.md) (licence scope; requested 2026-10-27); verification of the interRAI lines by a person entitled under the licence.
- Owner decisions D-11 (pilot canton) and D-12 (licensed provider): they decide which cantonal rules and which nursing management your rules must fit.
