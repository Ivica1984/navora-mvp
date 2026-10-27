# Pilot foundation: consolidated recommendation on D-11, D-12, D-2

**Prepared by:** Product Owner (`po`), 2026-10-27 12:05 CET, on owner instruction 2026-10-27 ("concrete recommendations, not only options").

**Objectives set by the owner:**
- fastest path to a safe pilot;
- lowest legal and regulatory risk;
- lowest operational complexity;
- the best foundation for future OKP billing;
- support for production later.

**Inputs consolidated:**
- `lca` sections in the D-11 package (2026-10-24 05:45, 09:53), D-12 (up to 2026-10-26 17:55) and D-2 (2026-10-24 13:50, 2026-10-26 15:43).
- Engineering impact as drafted in the packages (D-11 and D-2 drafted by po, not yet confirmed by `eng`).
- One new primary source read by the PO today: the Zurich licence guidance [Z1]. It is new evidence, so `lca` is asked to re-check.
- **Not yet confirmed for this consolidation:** `lca`, `cra` and `eng` were asked to confirm today (section 5). Where this report goes beyond their signed sections it says so.

**Status labels:**
- IMPLEMENTED: true in the repository today.
- PLANNED: recommended here.
- UNKNOWN: not established.

This is product and strategy advice, not legal advice. The legal questions named below still go to a legal adviser in the chosen canton.

---

## Summary: what NAVORA should do

| Decision | Recommended default | Confidence |
|---|---|---|
| **D-11** Pilot canton | **Canton of Zurich.** Two to five contiguous municipalities inside the licensed partner's existing service area. Only if the owner already has a committed team and partner in another German-speaking canton does that canton win; Bern is the fallback. | **Medium** |
| **D-12** Licence holder | **Option B:** an existing Spitex organisation already licensed and OKP-admitted in Zurich runs one pilot team on NAVORA, under the four partnership conditions. NAVORA stays the software provider and processor, never the care provider. If no partner has signed a letter of intent within 8 weeks, the fallback is **C:** the pilot team founds its own small provider and applies for the Zurich licence. NAVORA does not become a provider itself (A rejected). | **Medium** |
| **D-2** Hosting | **Staging now:** Supabase in Zurich (`eu-central-2`) plus Render in Frankfurt, deployed from CI, synthetic data only (the design po decided 2026-10-24). **Production:** the same stack in the same regions as the target, cleared by the production `lca` check and a legal adviser before the first real client. A Swiss-hosted fallback is prepared only if the adviser rejects the Singapore/US access paths. | **High** (staging) / **Medium-Low** (production) |

**One-line ask of the owner:** *"Approve Zurich as the pilot canton, approve B with the C fallback after 8 weeks, approve the staging spend and create the two staging services; name a legal adviser in Zurich."*

---

## D-11 — Pilot canton

**1 Recommended option.** **Canton of Zurich.** The municipalities follow the partner, not the other way round: two to five contiguous municipalities inside the partner's existing service area. Choose them so that most visits are within about 20 minutes of each other (travel time is direct-care time; COVER1 cover between colleagues needs short distances). Override only if the owner already has a committed self-organised team and a licensed partner in another German-speaking canton; then that canton, with Bern as the named fallback.

**2 Rationale.**
- *Partner availability decides speed.* With D-12 B the pilot needs a provider already licensed and admitted in the pilot canton (KVG Art. 36; `lca` 09:53). Zurich is the largest German-speaking home-care market, so the chance of finding a willing partner is highest there. This is a PO judgement; no market count has been read.
- *The licence conditions are known and moderate* [Z1], for the C fallback and the path to team ownership:
  - a nursing manager (Leitung Pflege) with a tertiary nursing diploma, a Zurich practice licence, at least two years of comprehensive nursing practice, leadership experience or training, knowledge of OKP billing, and a deputy;
  - CHF 5 million liability insurance;
  - CIRS and a complaints process;
  - a written operating concept that covers data protection and professional secrecy;
  - **no fixed staffing percentage**;
  - a complete application usually decided within about eight weeks; fee normally CHF 1,500, OKP admission CHF 900.

  No such threshold blocks a small self-organised provider. This is the largest gap `lca` named for all three cantons, now closed for Zurich.
- *The most law already read.* `lca` has read the Zurich health law, the patient law, the care-financing act and the Spitex data collection (D-11, D-30). Every package that waits for the canton gets answerable fastest here.
- *German only.* No translation layer is needed. A second language is the largest single engineering cost before a pilot (D-11, Engineering).
- *Hosting fit.* The staging database is planned in Zurich (D-2). This keeps the production question about Swiss hosting simple, if the canton or payers prefer it.

**3 Benefits.**
- Fastest legal clarity.
- Known, moderate licence conditions for the later team-owned provider (the care model's target).
- A large partner pool.
- German UI as built.
- The residence municipality pays the residual costs (Pflegegesetz § 9 Abs. 4, `lca` [K1]), a single, known payer per client.

**4 Risks.**
- **Residual financing outside a municipal mandate:** the residence municipality pays, but the rate a provider without a municipal mandate receives (the "Normdefizit") was not read: UNKNOWN. Non-nursing services are subsidised only for providers the municipality runs or commissions (`lca` [K1]). *Mitigation:* the partner's existing mandates and contracts carry the pilot; `lca` reads the current residual financing first.
- **Documentation tools:** [Z1] says nursing documentation is kept with recognised instruments (examples named: NEXUS, careCoach). Whether NAVORA's visit documentation must be such an instrument, or may sit next to the partner's recognised tool, is **UNKNOWN**: an `lca` question and an adviser question. It does not block a pilot under B: the partner's recognised tool stays the record of the needs assessment (D-13 B).
- Many municipalities each with their own practice: the pilot is limited to two to five of them.
- Market competition among established Spitex providers may make partners cautious.

**5 Regulatory and compliance implications.**
- Licensing and OKP admission follow cantonal law (GesG ZH § 36; KVV Art. 51; KVG Art. 36). Under B the partner already holds both.
- Data protection: a private provider is under the federal DSG; whether a provider under a municipal mandate falls under the cantonal IDG for that task is UNKNOWN [Z1 names "DSG or IDG"] (adviser question 2 of D-11).
- Patient-record retention: Zurich law reads at least 10 years (`lca`); [Z1] recommends 20 years. This goes to D-4 (the final period is legal).
- Quality: CIRS and complaints management [Z1]; the federal KVV Art. 58g quality system for OKP. These are the partner's duties under B; NAVORA's QG1 supports them.

**6 Dependencies.**
- D-12 (partner in Zurich).
- A legal adviser in Zurich (the four D-11 questions, D-12 question 1, D-2 production questions 1-3).
- D-18 (tariff contract through the partner's association) and D-4 retention follow from it.

**7 If we delay.**
- At least nine packages stay at their current confidence: D-3, D-4, D-12, D-16, D-18, D-22, D-30, J5 cantonal reference data, the statistics hypothesis.
- No partner search can start, and that is the longest lead time on the pilot path.
- Every month of delay is a month added to the first real client, not to the build.

**8 Suggested implementation order.**
1. Owner confirms Zurich.
2. `lca` reads the current residual financing for a provider without a mandate, the IDG question and the documentation-instrument point (week 1).
3. Partner search in Zurich (weeks 1-8; D-12).
4. Municipalities fixed with the partner's letter of intent.
5. Engineering loads the dated Zurich reference rows (patient contribution, residual financing) once read, then pgTAP (one migration, reversible).
6. Q10 calendar with Zurich public holidays.

**9 Confidence: Medium.** The licence conditions are read from a primary source [Z1], and the law is the most read of any canton. What would change it: a committed team and partner the owner already has elsewhere, or an unfavourable residual rate for providers without a mandate (UNKNOWN).

---

## D-12 — Licence holder and operating organisation

**1 Recommended option.**
- **B for the pilot:** an existing Spitex organisation licensed and OKP-admitted in Zurich runs **one** self-organised pilot team (about four to eight nurses) on NAVORA.
- It does so under the four partnership conditions already in the package:
  1. teams decide in NAVORA; every intervention by the partner's nursing management is recorded and visible;
  2. aggregated pilot measures are shared;
  3. a path to a team-owned provider (C);
  4. the data terms: processor and confidentiality agreement, anonymised use only, the sub-processor term, access-end and no-code terms, and the provider's own follow-up and AI-use rules.
- **NAVORA is the software provider and processor, never the care provider.**
- **Fallback, decided now:** if no partner signs a letter of intent within **8 weeks** of the owner's decision, the pilot team founds its own provider and applies for the Zurich licence and OKP admission (C).
- **A is rejected:** NAVORA itself becoming a licensed provider.
- **D** (independent nurses each billing on their own admission) is not used for the pilot.

**2 Rationale.**
- Fastest safe path: the partner already has the licence, the OKP admission, the tariff and administrative contracts through its association, a nursing management, CIRS and insurance. The pilot tests the care model, not a licensing procedure.
- Lowest legal risk for NAVORA: provider liability, quality duties and employer duties stay with an organisation built for them. NAVORA stays a processor (DSG Art. 9) and an auxiliary under professional secrecy (StGB Art. 321), not a controller of health data in its own right.
- Best foundation for OKP billing: billing runs on an existing ZSR number and contract. NAVORA's billing estimate (J5) is checked against real invoices before NAVORA automates anything (D-18).
- Why C and not A as the fallback: A would make the software company a care provider. That mixes liabilities, makes NAVORA a controller of health data and contradicts the care model, in which teams own their work. In Zurich, C is feasible ([Z1]: no staffing threshold, about eight weeks), and it is the care model's own end state.

**3 Benefits.**
- Earliest first real visit.
- No licence procedure on the critical path.
- Billing on an existing admission and contract.
- The partner's nursing management can co-sign the clinical rules at go-live (G-1 route B, the co-signature).
- A clear exit to team ownership.

**4 Risks.**
- **Governance:** the partner's hierarchy can undo team autonomy. *Mitigation:* conditions 1 and 3, written into the contract; the AN2 measures show it.
- **Dependency on one partner:** the pilot stops if the partner leaves. *Mitigation:* the C fallback stays prepared (licence file template, nursing manager identified).
- **Legal question 1 is unresolved:** whether the *Hilfsperson* reading lets the partner entrust client health data to NAVORA under professional secrecy, and whether information or consent is needed (`lca`: unresolved, needs adviser). This applies to B, C and D alike. *Mitigation:* ask the Zurich adviser first.
- **Partner search may take longer than 8 weeks.** The fallback trigger is the mitigation.

**5 Regulatory and compliance implications.**
- Licence and OKP admission stay with the partner (GesG ZH § 36, KVV Art. 51, KVG Art. 36).
- NAVORA needs the following before the first real client:
  - a processor agreement and a confidentiality agreement (DSG Art. 9; StGB Art. 321 auxiliary);
  - a DPIA (DSG Art. 22; R-4);
  - production hosting cleared (D-2);
  - the partner's written approval of every sub-processor;
  - client information naming the hosting countries (DSG Art. 19).
- Quality and reporting (KVV Art. 58g, CIRS) are the partner's duties. NAVORA records events (QG1) and does not replace its reporting system.

**6 Dependencies.**
- D-11 (Zurich).
- The legal adviser (D-12 question 1).
- D-14 (fee model, owner) for the commercial terms.
- G-1 (Clinical Owner) and the partner's nursing management for the clinical go-live.
- D-1 (the live database: no real data from it may reach any pilot environment).

**7 If we delay.**
- No partner conversation can start.
- D-18 (tariff contract) cannot start, because it follows the admitted provider.
- D-14 cannot be negotiated, and the commercial model stays theoretical.
- The pilot start moves by the full delay plus the partner's own decision time.

**8 Suggested implementation order.**
1. Owner approves B with the fallback.
2. PO writes the partner profile and the term sheet from the four conditions (week 1).
3. Owner approaches two to four Zurich partners (weeks 1-6).
4. Letter of intent by week 8, or switch to C.
5. Adviser on question 1, then the processor and confidentiality agreements.
6. DPIA.
7. The partner's nursing management reviews the clinical package answers with the Clinical Owner.
8. Go-live gate.

**9 Confidence: Medium.** The direction is clear on every objective. It is not High because the processor and secrecy question is still with the adviser, and because no partner has yet been named.

---

## D-2 — Hosting strategy

**1 Recommended option.**
- **Staging now** (design decided by po 2026-10-24; only the owner's purchase and setup are missing):
  - one Supabase project in the **Zurich region `eu-central-2`** (Frankfurt `eu-central-1` only if Zurich is not offered), on a plan that does not pause;
  - one protected **Render** web service in **Frankfurt**;
  - migrations and the synthetic seed deployed from CI only;
  - the five `lca` conditions (specific region; nothing from the live project; test-domain accounts; EU function region; push only to the services cleared under D-32).
- **Production:** the **same stack and regions** as the target (Supabase Zurich, Render Frankfurt). It is released only after:
  - (a) the production `lca` check and a Zurich legal adviser answer the three D-2 questions (Supabase's contracting party in Singapore with support and incident access from Singapore and the US under SCCs; any Swiss-hosting requirement; the DPIA, including backup retention);
  - (b) the DPIA is complete;
  - (c) the partner approves the sub-processors.
- If the adviser rejects the Singapore/US access paths for health data, the fallback is a Swiss-operated Postgres host with the same schema. Engineering then prepares its cost and migration plan; it is not built speculatively.

**2 Rationale.**
- Staging carries synthetic data only. `lca` finds the design compliant under every plausible interpretation (conditions i-v). It is the only way to prove the safety jobs on a hosted clock before a real client: the SIG1 evaluator every minute, PLAN2 daily, the COVER1 events.
- The same stack for production avoids a second platform, a second set of migrations and a second operations model (lowest complexity). Zurich keeps the database in Switzerland, which removes the residency question for the database itself.
- Building a Swiss self-hosted stack now would buy nothing on synthetic data and would delay everything (D-2, option C).

**3 Benefits.**
- Hosted proof of the safety signals and planning jobs.
- An environment that later becomes production by a recorded decision, not by drift.
- Database residency in Switzerland.
- Small monthly cost for staging. Supabase Pro is commonly listed at about USD 25 a month plus compute; Render bills a workspace fee plus the instance. These are secondary sources, so the owner checks the price at signup.

**4 Risks.**
- **Production transfer risk:** Supabase's contracting party is Supabase Pte. Ltd (Singapore); support and incident access can come from Singapore and the US under SCCs (`lca` [H3], [H4]). For health data under professional secrecy this is unresolved until the adviser answers. *Mitigation:* the gate before the first real client; a Swiss fallback is ready to plan.
- **The app host also sees health data in transit.** Render is a US company (the vendor states Swiss-U.S. DPF certification; the DPF list was not checked). It goes through the same production check.
- Staging drifting into production: ADR-011 says staging is no production clearance.
- **Live project:** D-1 is still open. Nothing from `jwmfxrmougneeceldhsa` may be copied to staging (condition ii).

**5 Regulatory and compliance implications.**
- **Staging:** no personal data of clients, so no transfer, DPIA or processor duty arises from it (`lca`). Testers with real e-mail addresses are informed.
- **Production:**
  - DSG Art. 9 (processor; sub-processor approval by the partner);
  - Art. 16 (disclosure abroad: Zurich and Germany are covered; Singapore is not on the list, so SCCs and a transfer assessment are needed; US only for DPF-certified organisations);
  - Art. 19 (client information names the countries);
  - Art. 22 (DPIA);
  - StGB Art. 321 (professional secrecy; auxiliary status);
  - cantonal law on where the canton's residents' health data may be hosted (UNKNOWN for Zurich, adviser question 2).

**6 Dependencies.**
- Staging: only the owner's purchase and the two GitHub secrets.
- Production: D-11, D-12 (the partner as controller), the adviser, the DPIA, D-1 resolved.

**7 If we delay.**
- The SIG1 safety signals, PLAN2 and COVER1 jobs and SIG2 push stay unproven on a hosted clock.
- Accepted items keep their "hosted run unverified" deviation.
- The pilot cannot start even when partner and canton are ready, because staging is a precondition of the go-live gate.
- Staging can start today and is independent of D-11 and D-12, so delaying it costs time with no benefit.

**8 Suggested implementation order.**
1. Owner buys the plans and creates the Supabase Zurich project and the Render Frankfurt service, then adds the staging deploy secrets (this week).
2. Engineering wires the CI deploy and the seed (T12).
3. Owner checks the scheduled jobs (`cron.job`) and the time zone.
4. Engineering records the SIG1, PLAN2 and COVER1 hosted proof.
5. In parallel with D-11/D-12: the production `lca` check and the adviser.
6. DPIA.
7. Production project in Zurich created from the same migrations.
8. Go-live gate.

**9 Confidence:**
- **High for staging:** `lca` compliant; reversible; synthetic data.
- **Medium-Low for production:** the transfer and secrecy questions are open with the adviser.

---

## Overall order (one plan for all three)

| Week | Owner | Agents |
|---|---|---|
| 0 | Approve D-11 Zurich, D-12 B with the 8-week C fallback, D-2 staging spend; create staging; name a Zurich legal adviser; name the Clinical Owner (G-1) | `po` records the decisions, writes the partner profile and term sheet; `eng` wires the staging deploy |
| 1-2 | First partner conversations | `lca`: Zurich residual financing without a mandate, IDG, documentation instruments, D-12 question 1 briefing for the adviser; `eng`: hosted proof of SIG1/PLAN2/COVER1 |
| 3-8 | Letter of intent, or switch to C at week 8 | `eng`: Zurich reference rows; `po`: pilot agreement annex (four conditions); `cra`, `lca`: DPIA inputs |
| After the letter of intent | Processor and confidentiality agreements; municipalities fixed | Production hosting check; DPIA; Clinical Owner and partner nursing management go-live review |

## 5 Coordination (requested 2026-10-27)

- **`lca`:** re-check D-11 with the new primary source [Z1] (licence conditions; "recognised instruments" for nursing documentation; "DSG or IDG"). Confirm that the D-12 fallback C is not less protective than A on the sources read. No new D-2 analysis is asked: the staging verdict stands, and the production check stays as named.
- **`cra`:** D-12, clinical half. Is the partner's nursing management co-signing the Clinical Owner's rules at go-live sufficient, and what must the partner's CIRS and NAVORA's QG1 hand to each other?
- **`eng`:** confirm the drafted Engineering sections of D-11 and D-2 (Zurich reference rows; staging deploy). State whether Render offers a Swiss region (believed not: UNKNOWN).

## Sources

- [Z1] Kanton Zürich, Gesundheitsdirektion, *Merkblatt Betriebsbewilligung Spitex-Institution*, version September 2025 (zh.ch), read by po on 2026-10-27: legal basis (GesG § 36), Leitung Pflege requirements (Ziff. 3.4.2), staffing (3.4.6), liability insurance CHF 5 million (3.2), CIRS and complaints (3.5.7), data protection under DSG or IDG and recognised documentation instruments (3.5.1, 3.5.3), processing time about eight weeks and fees (4, 6).
- `lca` sources as cited in the D-11, D-12 and D-2 packages ([K1]-[K5], [E1]-[E7], [H1]-[H8]).
- Pricing (secondary, for the order of magnitude only): makerkit.dev and nocode.mba on Supabase plans; Render pricing pages as summarised by third parties. The owner confirms at signup.
