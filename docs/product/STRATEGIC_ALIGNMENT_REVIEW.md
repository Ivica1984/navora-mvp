# NAVORA Strategic Alignment Review

**Prepared by:** Product Owner (`po`), 2026-10-27 13:00 CET, on owner instruction 2026-10-27. **Status:** review and proposals. Where a proposal changes a decision owned by the owner, it is put to the owner as a package (D-37) or an addendum to the existing package. Nothing in this review is built, and no clinical, legal or tariff rule is set by it.

**Labels:** IMPLEMENTED (in the repository today, synthetic data); PLANNED (approved or proposed, not built); OPEN (undecided); UNKNOWN (not established).

**Sections by the Chief Strategy Architect (`csa`)** come first, newest first, each dated. Never edit an earlier section; correct it in a new one. The PO's sections of 2026-10-27 13:00 follow below, unchanged.

---

## 2026-10-27 13:55 CET · csa · Strategic fit, week 1

**Scope.** First `csa` run. Read: README *Roles*, *Strategy review*; COORDINATION; DECISION_PACKAGES; `decisions/INDEX.md`; OPEN_DECISIONS; NEXT_CAPABILITY; JOURNAL 2026-10-20 to 2026-10-27 13:45; the mandate; STRATEGY; this review; CARE_OPERATING_MODEL; AUTOMATION_REVIEW (baseline only, no `aia` finding yet); the *Decision summary*, *Recommended default* and *Owner approval required?* sections of every package `awaiting-approval: owner`; the G-1 appointment report. Nothing here edits a package, a row or the queue. No legal, clinical or tariff interpretation is mine: where one is needed it is cited to `lca` or `cra`, or written UNKNOWN.

**Changed this week (evidence: INDEX, JOURNAL):**
- decided by the owner on 2026-10-27: strategic direction; D-12 (B as an operating-model partnership, 12-month sunset, C prepared from month 0); D-34 (A plus C, clinical module as the target); the staged AI path (D-35 stages 0-3); D-37 opened as a track; the roles `aia` and `csa`. D-33 decided on 2026-10-26.
- still `awaiting-approval: owner`: 15 packages (D-22, D-18, D-29, D-11, D-9, D-4 final periods, D-7, D-8, D-1, SR-26, D-2, D-26, D-14, D-24, D-25), plus G-1 (the Clinical Owner), which gates 9 packages `awaiting-approval: clinical`.
- queue: COND2 delivered (12:25); UX1, ADM2, UX2 approved; AIG1, ASM1, PLAN3 proposed and announced for the next PO cycle (PLANNED, no brief yet).

**Dimensions (columns *fit*):** T self-organised teams · O AI-assisted operations · P planning · Dc documentation · B billing preparation · I interRAI-supported care planning and governance · H independence from hierarchical operating models. `+` serves, `0` neutral, `−` harms.

### Strategic fit notes, one row per package awaiting the owner

| STR | Package | Fit | Lock-in risk | Challenge | Proposal (equal safety) |
|---|---|---|---|---|---|
| STR-1 | **D-11** Zurich, 2-5 municipalities in the partner's service area | T+ H+ (on `lca` 12:42 [Z1]: no fixed staffing percentage, so a small team-owned provider is licensable in Zurich); B 0; I UNKNOWN (`lca` question 5: whether "anerkannte Instrumente" bears on NAVORA). **Verdict: serves, with one condition** | **Medium.** Municipalities chosen only from the *partner's* service area tie the team-owned provider (C) to municipalities where the partner holds the service mandate. At the transfer the C provider serves the same clients in the same municipalities as its former host. Whether a new provider without a municipal mandate gets residual financing there is UNKNOWN (`lca` criterion 3, [K3] read for BE only) | none (adds no step) | Add to the owner's municipality choice one condition: **at least one pilot municipality where the residual-financing or mandate path for a new provider is known before the C file is submitted** (question for the Zurich adviser bundle, `lca`). Cost: one adviser question. Without it, the C transfer can be licensed and admitted and still not financed |
| STR-2 | **D-14** fee basis F3 (per active member per month) or F4 | B+ (volume-neutral: no gain from more hours or higher categories); T+; H **depends on who signs**. **Verdict: serves, with two changes** | **High.** Under D-12 B the partner pays the fee, so NAVORA's first customer is a traditional provider. An organisation-wide licence, exclusivity or a fee set per organisation would make NAVORA a supplier to the partner (the drift the mandate names) and would not carry over to C. Second: F3 charges a 20 % member the same as a 100 % member and rewards fewer members working more hours (`cra` 02:26, H-10); that works against part-time nurses joining a team | medium: none of the recommendation adds administration; the risk is the contract shape | (a) Ask the owner for F3 **with one term**: the fee is agreed **per pilot team**, transferable unchanged to the team-owned provider; no exclusivity and no organisation-wide licence with the partner. (b) Ask `lca` whether a **team-size band** variant of F3 (one fee per team per month by band, for example 1-4, 5-8, 9-12 active members) is as compliant as F3. It needs no new field (active count from LEAVE1), is neutral to part-time work, and keeps the small-team principle. The PO decides whether to put (b) to the owner |
| STR-3 | **D-29** qualification: option B, the member records evidence, a second person confirms "as someone the licence holder has authorised" | T+ (no central administrator step); H+; B+ (billing only on confirmed evidence). **Verdict: serves** | **Medium.** If the authorisation is kept per person by the partner, the partner's administration becomes the gatekeeper of every team, and at the C transfer every authorisation must be issued again | **medium:** a per-person authorisation list is an administration step whose patient-care benefit is already carried by the second confirmer. The licence holder's responsibility (`lca` 13:50) is a legal duty and stays; only its form is challenged | The licence holder authorises a **role** once, in its organisational policy ("a registered nurse of the same team with confirmed, unexpired evidence"), recorded as one versioned policy reference. At the C transfer the new provider's Leitung Pflege issues the same policy once. Whether a role-level authorisation satisfies the licence holder's duty: question for `lca` (UNKNOWN) |
| STR-4 | **D-26** production: no service-role key on the app host; invitations in Edge Functions | T+ H+ if approved. **The default A (a NAVORA operator creates every account by hand) is a central step:** once ADM2 ships, a team's admission by consent ends in a request to NAVORA. **Verdict: serves; time-critical** | low (the recommendation) | **medium, on the default, not the package:** manual account creation has no patient-care benefit; its safety benefit (no RLS-bypassing key on the app host) is kept by the recommended Edge Function | Escalate D-26 in the same owner bundle as the G-23 release gate of ADM2, so the team's admission works without NAVORA in the loop before the first real team (sequencing, below) |
| STR-5 | **D-22** valid medical order: care A/C without order with a recorded GP information step; billing only on a signed order issued before the visit | T+ (ORD1 renews without chasing the GP); B+ (billing integrity); Dc 0. **Verdict: serves** | low | none: the GP information step has a care-coordination benefit and is already automated as one `inform_gp` task (ORD0, IMPLEMENTED) | none beyond the bundle: it needs a legal adviser, like D-18, D-9, D-4 and D-25 (below) |
| STR-6 | **D-18** tariff time rules: exact minutes and estimate (C), contract as versioned reference data (A), after D-11, D-12 | B+; T 0. **Verdict: serves** | **Medium.** `lca` (on D-22): the tariff contract follows the admitted provider and its association membership. The partner's contract under B is not the C provider's contract | none | Keep option A **keyed by the provider's contract**, never by an organisation setting, so that the C provider's own contract is a new version, not a rebuild. Engineering confirms in its D-18 section (`eng`; currently drafted by po). No new owner question |
| STR-7 | **D-9** legal basis at intake, option D protective variant | T+ (REF2, the horizon-2 wedge, needs it); H+. **Verdict: serves** | **Medium.** `lca` (D-12 note 3): clients move to a new provider only with each client's consent. At the C transfer every client of the pilot team needs a consent step | none | Ask `lca` (question only, no rule): can the information given to the client at intake already name the team and the planned change of provider, so that the transfer consent is a confirmation rather than a new procedure? UNKNOWN until answered |
| STR-8 | **D-4** audit-log final periods | 0 on every dimension. **Verdict: neutral** | low; at the C transfer the retention duty of the old controller continues (UNKNOWN) | none | Add "retention and audit extract at a change of provider" to the adviser bundle (`lca`) |
| STR-9 | **D-2** staging now; production on the same stack, gated by the `lca` check including the AI processing location | O+ (hosting and AI cleared once, per review §2). **Verdict: serves** | low | none | none |
| STR-10 | **D-1, SR-26, D-7, D-8** live-project facts, key rotation, foreign table, ruleset, merge to `main` | 0 on the dimensions; precondition for every real-data gate. **Verdict: neutral, urgent** (D-1 marked urgent since 2026-10-24) | none | none | One owner session for all four, in the packages' order (D-1, SR-26, D-7, D-8). They cost minutes and nothing strategic waits on them except time |
| STR-11 | **D-24** nursing homes: A now; B (one ward, organisational change only) after the timing condition; C after a licence and D-34 | T+ H+ (design target removes the ward leader, keeps every licence role); I: the LTCF licence is a second interRAI licence conversation. **Verdict: serves** | **Medium.** Option D (partner with the home's LTCF vendor) makes NAVORA an add-on to the home's existing system: the supplier role in the sector where hierarchy is heaviest | none | (a) Owner approves A as recommended and records **D only as a fallback**, never the default entry route. (b) The LTCF licence question joins the **same** interRAI conversation as D-36/D-37 (HC), so there is one licence strategy, not two |
| STR-12 | **D-25** nursing-home leadership rules (only once D-24 moves past A) | T+ H+. **Verdict: serves** | low | none: every role the licence names stays (legal duty); only the ward leader's operational work moves | Prefer option D (ask the canton): an answer from the canton can be reused for every later home in that canton; a legal opinion is reused less easily. Not urgent |
| STR-13 | **G-1** the Clinical Owner: route B (independent, part-time mandate now) with the partner's nursing management co-signing at go-live | H+ **strongly** (route A would tie NAVORA's clinical rules to one partner and break at the C transfer); T+; I+ (D-37 intervals and triggers need it). **Verdict: serves; the single largest unblocker** (9 clinical packages and D-37) | low with B, high with A | none: the co-signature is the licence holder's duty (G-1 report, `lca` to confirm), not administration | The co-signature is given **per version of the rule set**, once, not per rule change; the C provider's Leitung Pflege co-signs the same version at the transfer. Ask the owner for G-1 **before** any other package in the pilot bundle |

### Challenge on the decision process (challenge duty)

| STR | Added | Patient-care benefit shown | Evidence | Leaner alternative at equal safety | Severity |
|---|---|---|---|---|---|
| STR-14 | Repeated re-checks and addenda on packages that already wait for a person: hourly PO entries "no new evidence", package addenda that leave the ask unchanged, owner asks spread over 15 packages of 14-54 KB each (472 KB together) | **none shown** for the repeat work: the safe default is already in force while a package waits, and the owner's question does not change | 83 journal lines "no new evidence" since 2026-10-24; 141 commits touching `decisions/` since 2026-10-20 out of 1,177 in total; the 15 owner packages total 472 KB (D-22 54 KB, D-4 51 KB); outside them D-23 is 132 KB and D-3 94 KB; the INDEX *Last change* cell is one paragraph of about 23 KB | (1) A package at `awaiting-approval` is **frozen** until new evidence or a person's answer, and the run writes nothing about it. (2) The owner gets **one page** with three bundles (below), each ask one line, linking the packages. (3) The PO keeps the INDEX *Last change* cell to the newest change; git keeps the rest. Safety is unchanged: every safe default stays in force and no package is decided by this | **high** (issue #540) |

**Proposed owner agenda (for the PO to adopt or change; `csa` does not escalate):**
1. **Now, one session, minutes each:** D-1 → SR-26 → D-7 → D-8 (live-project hygiene); **G-1** (name the Clinical Owner, route B). Strategic cost of further delay: every real-data gate waits on D-1, and 9 clinical packages plus D-37 wait on G-1.
2. **Pilot foundation, one decision meeting:** D-11 (with STR-1), D-2 (staging spend), D-26 (with STR-4), D-29 (with STR-3), D-14 (with STR-2); the partner's name and a Zurich legal adviser; the interRAI licence terms (D-36).
3. **Only once a legal adviser is named or a trigger holds:** D-22, D-18, D-9, D-4, D-24, D-25. Naming **one Zurich legal adviser** answers questions in at least six packages (D-22, D-18, D-9, D-4, D-25, and D-11/D-12 question 1).

### Drift check of the week

- **No hierarchy step accepted this week.** ADM2 (approved) replaces an administrator step with the team's consent; its remaining employer step ("Vertrag erfasst") records a contract fact and carries no judgement field (ADM2-6). Aligned.
- **Supplier-role risk, OPEN:** D-12 is decided as a partnership with a sunset, but the terms that make the sunset real are not yet written: client consent at transfer, the C provider's own tariff contract, municipal financing, the fee contract party, and what the partner gains from incubating a team that leaves. If the partner's letter of intent is signed without them, the sunset depends on the partner's goodwill. This is a **strategic finding** (STR-15, below), raised to the PO as an issue.
- **AI and interRAI: not postponed, not yet staged in the queue.** The queue still has no item for dimensions 2, 3, 4, 6 (review §4). AIG1, ASM1, PLAN3 are announced for the next PO cycle (journal 13:30). If they are not briefs by the next `csa` run, that is drift. Stage 1 AI can only start 3 stable pilot months after a pilot that has not started; every week of delay on the bundle-1 and bundle-2 decisions moves stage 1 by a week.

### Strategic finding

| STR | Finding | Evidence | Proposal | Severity | Route |
|---|---|---|---|---|---|
| STR-15 | **The C transfer has no written terms before the partner is named.** The 12-month sunset is decided; how clients, records, the tariff contract, municipal financing, the fee contract and the team members' employment move to the team-owned provider is not | D-12 owner decision 2026-10-27; `lca` D-12 notes 3 (no licence transfer; client consent), D-22 (contract follows the admitted provider); STR-1, STR-2, STR-6, STR-7 | The PO prepares a **package on the transfer terms of the partnership letter of intent**, before the owner signs one: (1) client information and transfer consent (`lca`); (2) the C provider's own tariff contract and association route (`lca`, D-18); (3) municipal financing (STR-1); (4) the fee agreed per team and transferable (STR-2); (5) whether team members' employment contracts with the partner may restrict joining the C provider (`lca`, UNKNOWN); (6) what the partner receives for incubating the team (owner: partnership). Owner-level (partnership) | high | issue #539 to `po` |

---

## Owner decisions on this review (2026-10-27)

The owner approved:
- the strategic direction as recorded;
- D-12 as revised;
- D-34 (A plus C, with the clinical module as the long-term target);
- the staged AI roadmap;
- D-37 as a strategic decision track, with expert review and licence clarification before the final decision;
- interRAI as a core clinical foundation;
- both role mandates, and the creation of both roles.

**Owner clarification:**
- NAVORA software is not merely a management tool; it is a core component of the operating model.
- AI should ultimately remove administrative burden and enable teams to organise themselves.
- Pilot safety requires a staged approach, but the long-term vision is reflected in every strategic decision.
- The partner organisation is a pilot vehicle, not the destination.

From now on, the strategy is kept in [`STRATEGY.md`](STRATEGY.md) by the Chief Strategy Architect.

## 0 The owner's strategic direction (2026-10-27), recorded

> NAVORA software is not merely a supporting tool for traditional care organisations. It is a core part of the operating model itself. The objective is a new care-delivery model that enables self-organised nursing teams with minimal hierarchy and significantly reduced administrative effort; the software platform is the foundation that makes this possible.

**Principles**
1. Self-organised teams remain a core principle.
2. Administrative work is automated wherever safely possible.
3. Planning, documentation, billing preparation and operational coordination are increasingly assisted by AI.
4. interRAI becomes an important clinical foundation for care planning, continuity, reassessment and governance, within licensing and regulatory limits.
5. Future recommendations are evaluated against the long-term vision, not only against the fastest path to a pilot.

**How the PO reads "AI-assisted" (consistent with `CARE_OPERATING_MODEL.md`, *AI-first means graph-first*).** The owner's direction confirms the design order already in force and turns it into a planned path:
1. work that exists only because information is fragmented **disappears** through the care graph;
2. rule-shaped work is **automated** by tested rules;
3. drift is **monitored**;
4. **AI agents** take the unstructured edges (letters, speech, free text) and **draft** for people;
5. people keep judgement, accountability and the relationship.

The direction is accepted in full. What was missing was a **staged path with entry conditions**, so that the pilot rules (D-34 statement v2, D-35 rule A) read as the first stage of an AI-assisted model, not as its limit. Section 3 proposes that path.

**What does not change:**
- Patient safety is a precondition.
- No agent output enters the record without a named confirmer.
- A clinical rule is approved only by the Clinical Owner (D-27).
- Safety signals stay deterministic.
- No per-person performance scoring.

---

## 1 Verdict per dimension

Scale: **strong**, **partial**, **weak**, judged against the long-term vision, not the pilot.

| # | Dimension | Today (IMPLEMENTED unless marked) | Verdict | Largest gap | What closes it |
|---|---|---|---|---|---|
| 1 | Self-organised care teams | Team decides on offers (J2), plans from the care plan (PLAN2), covers (COVER1), handles absence (ABS1), hands over without a meeting (HAND1); returning clients return to their team (RET1); Operations is an exception service (OPS1). Team admission by consent: ADM2 *Next up* 3 (PLANNED) | **strong** | Hierarchy steps that remain: a coach or admin lifts a quality hold (D-16, OPEN); the licence holder's nursing management sits above the team under D-12 B | D-16 option B (team RN lifts) at G-1; D-12 revised (§2) |
| 2 | AI-assisted operations | Deterministic exceptions and safety signals (OPS1, SIG1, SIG2), escalation rules, measures from events (AN1, AN2). No AI service (D-35 A) | **partial**: automation strong, AI absent | No AI governance infrastructure (suggestion ledger, evaluation harness, stop rule) exists, so no agent can be introduced safely even on synthetic data | **AIG1** (proposed, §4): the governance layer, built on synthetic data, no AI service |
| 3 | AI-assisted planning | Visits generated from the care plan (PLAN2); cover offers (COVER1); team decides. No optimisation of day order, travel or continuity | **partial** | No planning proposal: the nurse or team still orders the day and balances continuity and travel by hand | **PLAN3** (proposed, §4): day-plan and continuity proposal by a deterministic optimiser (agent A3, level L), team confirms |
| 4 | AI-assisted documentation | Structured visit lifecycle and door facts (DOOR1), signed reports with countersignature (F-series, D-10), corrections (F6). Report text written by the nurse | **weak** | Every drafting agent (A7 dictation, A9 report drafter, A8 intake extraction) is level G or H: it needs D-34's module route, D-35 B or C and the Clinical Owner | Short term: documentation by exception from events (no AI, Transformation Report §6.5). Long term: the qualified clinical module (D-34 C, §3 stage 3) |
| 5 | AI-assisted billing preparation | Billable facts derived continuously from signed visits; monthly revenue preview (J5); billing hold (QG1) | **strong** foundation | No invoice draft and no insurer-dispute support (agent A4, level L), because the tariff contract (D-18) and the licence holder (D-12) are open | A4 as deterministic invoice draft after D-12/D-18; AI only for dispute letters (stage 1) |
| 6 | interRAI-supported care planning and governance | Nothing: D-13 B (po-decided 2026-10-25) is instrument-neutral and **not built**; interRAI references in six packages are name level, UNKNOWN until verified (D-36) | **weak**, and **in tension with the owner's direction** | D-13 treats the instrument as the provider's choice; the owner now wants interRAI as NAVORA's clinical foundation | **D-37** (new owner package, §2) and **ASM1** (proposed, §4) |
| 7 | Long-term independence from hierarchical operating models | Care model and challenge table remove dispatch, scheduling administrators, intake coordinators, station leadership by design. But the pilot recommendation (D-12 B) places the team inside a traditional provider | **partial** | The path from a partner's licence to team-owned providers is a fallback, not a plan | D-12 revised (§2): partnership with a sunset, and the team-owned provider prepared from day 1 |

**Overall:** NAVORA is strong where the care graph and deterministic rules already replace coordination: teams, planning from the care plan, billing facts. It is weak where the vision needs AI on clinical text and interRAI, because those cross regulatory lines that the current safe defaults hold on purpose. The gap is not a wrong direction; it is a missing **staged path** across those lines, and two strategic decisions the owner has not yet taken: the clinical-module ambition (D-34) and interRAI as foundation (D-37).

---

## 2 Decision packages re-evaluated against the vision

| Decision | Recommendation before | Re-evaluated against the vision | Change |
|---|---|---|---|
| **D-11** pilot canton | Zurich (Medium) | Zurich also fits the long term: the licence guidance (September 2025) sets no fixed staffing threshold, so a **team-owned provider** can be licensed there with a nursing lead, a deputy, insurance and CIRS. Zurich is a credible home for the C model, not only for a fast B. | **Unchanged**, reasoning strengthened |
| **D-12** licence holder | B, C as fallback after 8 weeks; A rejected | B alone risks embedding the team in the partner's hierarchy and makes NAVORA a supplier to the old model, against principles 1 and 7. C alone is the slowest. **Revised recommendation:** **B as an operating-model partnership with a sunset**: (i) the partner runs the pilot team **on NAVORA as its operating system** (planning, coordination, cover, quality events, billing facts; no parallel dispatch or scheduling in a legacy tool; the needs assessment stays in the partner's recognised tool until D-37); (ii) term of at most **12 months** for the pilot team; (iii) the **team-owned provider (C) is prepared from month 0**, not only as a fallback: nursing lead and deputy identified inside the team, licence file drafted, so the transfer can happen when the pilot measures are met; (iv) the four existing conditions stay; (v) C carries `lca`'s five conditions (12:42), the first being that NAVORA holds **no control** over the team-owned provider. Licence and OKP admission are two procedures of about eight weeks each, so about four months, which is why C is prepared from month 0. A stays rejected. | **Changed**: B with sunset and C in parallel (owner ask updated) |
| **D-2** hosting | Staging now; production gated on the same stack | AI-assisted operations need an AI processing location that the same legal check covers. **Added:** the production `lca` check also covers the AI service's region and processor chain (D-35 B), so that hosting and AI are cleared once, in CH or the EU. | **Extended** |
| **D-13** assessment instrument | B, instrument-neutral record (po-decided) | Conflicts with principle 4: an instrument-neutral record keeps interRAI outside NAVORA. B's record is still the right first build (it is needed in every option). | **D-13 B stays as the first build; the strategic question moves to D-37** |
| **D-34** medical-device status | A plus C (module rule), awaiting owner | The vision needs AI documentation drafting and interRAI-based care-planning support. Both are level H (they interpret clinical content). They are only possible inside a **separately qualified clinical module** (C). So the owner's direction **implies** answering D-34 with "A plus C, with the clinical module as a stated target". The core stays non-device; the module carries the clinical intelligence and its own conformity route. | **Strategic answer recommended**: the owner approves A plus C **and** the module as a target (horizon 2) |
| **D-35** AI services | Rule A for the pilot (no client or staff data to any AI service) | Rule A is right as **stage 0**. Without stated exit criteria it would read as the end state. | **Addendum**: staged exit path (§3); a new owner package once a provider is named |

### D-37 (new, owner): interRAI HC as NAVORA's clinical foundation
**Question:** should NAVORA designate interRAI HC as its clinical foundation for care planning, continuity, reassessment and governance in home care, and through which licence and integration route? **Recommended default (PO, Medium-Low until D-36):**
1. **Yes, as the designated target instrument for home care.**
2. **Route:** integrate with the licensed Swiss tool the provider uses (D-13 option A). Assessment results (date, assessor, problem areas the tool reports, the assessor's signed care-planning conclusions) enter NAVORA as **signed facts from the licensed tool**. **NAVORA computes no scale or CAP itself** until the clinical module (D-34 C) and the licence allow it.
3. **Uses in NAVORA, in order:**
   - (a) reassessment due dates and significant-change prompts, with the interval and triggers set by the Clinical Owner;
   - (b) care-plan structure by problem area;
   - (c) continuity (the primary nurse sees the change since the last assessment);
   - (d) governance (aggregate quality indicators per team, never per person, after the licence and MQI-like definitions are cleared).
4. **Preconditions:**
   - D-36 (licence scope, `lca`);
   - D-12 (which provider and tool);
   - the Clinical Owner (G-1) for intervals and triggers;
   - D-34 for anything computed.

Package: [`../agents/decisions/D-37.md`](../agents/decisions/D-37.md).

---

## 3 The staged AI path (proposal; D-35 addendum)

| Stage | When | What runs | Data | Device level | Entry conditions |
|---|---|---|---|---|---|
| **0 Foundation** | now | AI governance layer (suggestion ledger, provenance per value, evaluation harness, stop rule, scope inheritance) built and tested; deterministic L automations (A1 referral completeness, A6 control health, PLAN3 optimiser, A4 invoice draft as rules) | synthetic only | L | none beyond the queue (D-35 A holds) |
| **1 Administrative AI** | pilot, after 3 stable months | L agents with AI where input is unstructured: A2 order-renewal request, A4 insurer-dispute letters, A5 compliance evidence pack; planning assistant explanations | staff and administrative data, minimised; no clinical free text | L | new `owner` package naming provider, model region (CH/EU) and contract; `lca` conditions 1-10; DPIA; partner's sub-processor approval |
| **2 Documentation assistance, low risk** | after stage 1 evidence | A7 dictation to entry (the nurse's own words, no interpretation) | the nurse's own dictation (D-35 term 10) | G (adviser to confirm) | regulatory adviser on G; Clinical Owner list of no-accept-all fields; stage-1 correction rates below threshold |
| **3 Clinical module** | horizon 2 | A9 report and handover drafter, A8 intake extraction, A10 care-plan review proposer, interRAI-based care-planning support | clinical content | H, as a separately qualified module (D-34 C) | owner approves the module target (D-34); conformity route; Clinical Owner; D-37 licence; evaluation evidence from stages 0-2 |

**Never, at any stage:** AI triage of P1 safety signals; per-person performance scoring; automatic coding or care-plan change; a general copilot across all data; unconfirmed record entries (AI Operating Model Review §7).

---

## 4 Roadmap: what should change

The queue in `NEXT_CAPABILITY.md` (COND2 delivered, then UX1, ADM2, UX2) supports dimensions 1 and 7 (ADM2) and adoption (UX1, UX2). It has **no item for dimensions 2, 3, 4 and 6**. Proposed briefs, PO drafts. The PO approves them in its next cycle **unless the owner objects**; none needs a legal or clinical decision for its synthetic-data build.

| Proposed | Capability | Dimension | Why now | Gate |
|---|---|---|---|---|
| **AIG1** | AI governance foundation: suggestion ledger (append-only), provenance per value ("vorgeschlagen von / bestätigt von"), "not found" explicit, no accept-all on listed fields, correction-rate measure per agent and field (never per person), stop rule, evaluation harness on synthetic cases | 2, 3, 4, 5 | Every later agent needs it; building it first makes stage 1 a configuration step, not a project. No AI service, no real data | none (synthetic) |
| **ASM1** | Assessment record and reassessment cycle: D-13 B with its five acceptance criteria; interRAI HC listed as the designated instrument in the reference list (D-37); "Neuere Bedarfsabklärung" marker; last-assessment date on the care plan; reassessment due display **only** once the Clinical Owner sets the interval | 6, 2 | It is needed in every D-37 option, and it closes the care graph's assessment gap (P-9) | due-date rule: Clinical Owner |
| **PLAN3** | Day-plan and continuity proposal: a deterministic optimiser proposes visit order and assignment inside the team, weighting continuity (same nurse), time windows, qualifications and travel; the team confirms or changes; every proposal goes to the AIG1 ledger | 3, 1 | Planning is the largest remaining manual coordination task after PLAN2; level L; replaces the scheduling administrator | labour rules: `legal` (existing Q) |
| later: **BILL2** | Invoice draft (A4 as rules) from J5 facts, for the licence holder's confirmation | 5 | After D-12 and D-18 name the contract | D-12, D-18 |

**Order after UX1 (proposed):** ADM2 → **AIG1** → **ASM1** → UX2 → **PLAN3** → BILL2. AIG1 goes before UX2 because it sets the pattern every assisted screen uses. UX2 follows, so the one shell already shows proposals and confirmations.

---

## 5 What the owner is asked

1. **Confirm the strategic direction as recorded in §0** (the PO has written it into `CARE_OPERATING_MODEL.md`).
2. **D-34:** approve "A plus C, with the clinical module as a stated target". The core stays non-device; the clinical intelligence goes into a separately qualified module.
3. **D-37:** approve interRAI HC as the designated target instrument, integrated through the provider's licensed tool, with nothing computed in NAVORA before the module (after D-36).
4. **D-12 (revised):** approve B as an operating-model partnership with a 12-month sunset and the team-owned provider prepared from month 0.
5. **Roles:** approve the mandates for the AI & Automation Architect and the Chief Strategy Architect ([proposal](../agents/reports/ROLE_PROPOSALS_AIA_CSA.md)), then create their schedules.
6. **No objection needed** for AIG1, ASM1 and PLAN3. The PO approves them next cycle unless the owner objects.
