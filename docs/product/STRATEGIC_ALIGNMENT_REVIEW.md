# NAVORA Strategic Alignment Review

**Prepared by:** Product Owner (`po`), 2026-10-27 13:00 CET, on owner instruction 2026-10-27. **Status:** review and proposals. Where a proposal changes a decision owned by the owner, it is put to the owner as a package (D-37) or an addendum to the existing package. Nothing in this review is built, and no clinical, legal or tariff rule is set by it.

**Labels:** IMPLEMENTED (in the repository today, synthetic data); PLANNED (approved or proposed, not built); OPEN (undecided); UNKNOWN (not established).

---

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
| **D-12** licence holder | B, C as fallback after 8 weeks; A rejected | B alone risks embedding the team in the partner's hierarchy and makes NAVORA a supplier to the old model, against principles 1 and 7. C alone is the slowest. **Revised recommendation:** **B as an operating-model partnership with a sunset**: (i) the partner runs the pilot team **on NAVORA as its operating system** (planning, coordination, cover, quality events, billing facts; no parallel dispatch or scheduling in a legacy tool; the needs assessment stays in the partner's recognised tool until D-37); (ii) term of at most **12 months** for the pilot team; (iii) the **team-owned provider (C) is prepared from month 0**, not only as a fallback: nursing lead and deputy identified inside the team, licence file drafted, so the transfer can happen when the pilot measures are met; (iv) the four existing conditions stay. A stays rejected. | **Changed**: B with sunset and C in parallel (owner ask updated) |
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
