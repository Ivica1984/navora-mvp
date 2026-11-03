# NAVORA AI Opportunity Map

**Author:** Product Owner (`po`) · **Date:** 2026-11-03 (Europe/Zurich) · **Basis:** owner's Strategic Architecture Directive (2026-11-03); [AI-First Architecture Update](AI_FIRST_ARCHITECTURE_UPDATE.md). **Status:** analysis. It approves no build.

**Status labels:** IMPLEMENTED (exists, synthetic data only) · PLANNED · OPEN · UNKNOWN · HYPOTHESIS (pilot data decides).

**Levels (D-34):**
- **L:** logistics, administration, operational facts.
- **G:** transcription, adviser to confirm.
- **H:** interprets clinical content for an individual. Only in the separately qualified clinical module.

**Stages (staged AI path, [Strategic Alignment Review](STRATEGIC_ALIGNMENT_REVIEW.md) §3):**
- **0:** governance and rules, synthetic data.
- **1:** administrative AI, after the owner's provider package.
- **2:** low-risk documentation assistance.
- **3:** the clinical module.

**Sources reviewed:**
- `ARCHITECTURE.md`, `CARE_OPERATING_MODEL.md`, `ROADMAP.md`, `NEXT_CAPABILITY.md`, `PRODUCT_REQUIREMENTS.md`;
- the Transformation Alignment, Strategic Alignment and AI Operating Model reviews;
- `NURSING_HOME_TRANSFORMATION.md` (NH0-NH9);
- the briefs HAND1, COVER1, PLAN2, PLAN3, RET1, ABS1, J1-J7, OPS1, AIG1, ASM1, AN3;
- `aia`'s bottleneck map v2 (`AUTOMATION_REVIEW.md`, review 18);
- the owner issues #816-#818.

---

## 1. Inventory: where the architecture assumes humans

| # | Assumption | Item (status) | Why it was built this way | AI-first verdict |
|---|---|---|---|---|
| 1 | **Coordination:** the team decides who takes an offered case | J2 (IMPLEMENTED) | team autonomy; no dispatcher | keep the decision; AI adds a fit summary (continuity, capacity, qualification) to each offer, L |
| 2 | **Coordination:** the responsible nurse is set visit by visit | J3 (IMPLEMENTED) | one accountable member per visit | PLAN3 proposes every assignment; the team confirms the list (approved; first `schedule` field, AIG1-5) |
| 3 | **Coordination:** cover is offered, a colleague takes it | COVER1 (IMPLEMENTED, off until D-3) | no phone chain | AI proposes the best-fitting cover (knows the client, qualification, travel), the colleague accepts; L |
| 4 | **Coordination:** absence releases visits to the team | ABS1 (IMPLEMENTED) | one statement, no approval | release plus a ready re-assignment proposal (continuity first); L |
| 5 | **Coordination:** Operations works the exceptions that teams leave | OPS1 (IMPLEMENTED) | escalation backstop | AI groups and explains exceptions and drafts the next step; Operations shrinks to the residue; L |
| 6 | **Manual workflow:** intake re-types the referral | J1 (IMPLEMENTED), REF2 (draft) | no structured referral source | structured referral plus completeness rule (A1, L); discharge letter extraction (A8, H) |
| 7 | **Manual workflow:** care-plan items typed by the RN | J3, PLAN2 (IMPLEMENTED) | plan is the RN's decision | draft plan items from the assessment and the referral, confirmed one by one; H (clinical module) |
| 8 | **Manual workflow:** assessment header re-typed from the provider's tool | ASM1 (IMPLEMENTED) | no export defined | import into a draft, confirmed value by value (AUT-13; L, D-36) |
| 9 | **Manual workflow:** GP order renewal chased by phone | ORD0 records the task (IMPLEMENTED), ORD1 (draft) | no structured order (D-22) | renewal request drafted and sent by the primary nurse, GP confirms digitally (A2, L) |
| 10 | **Manual review:** every care-assistant report countersigned | F6 (IMPLEMENTED), D-10 (clinical) | regulatory caution | risk-based review: monitors find the reports that need a second look; parallel run first (P-1) |
| 11 | **Manual review:** care plan reviewed on a calendar | J3 review date (IMPLEMENTED) | periodic review practice | continuous review proposal from observations, events and measured minutes (A10, H) |
| 12 | **Manual review:** quality holds reviewed and lifted by people | QG1 (IMPLEMENTED) | accountability for quality | stays human; AI prepares the evidence pack for the review, L |
| 13 | **Manual review:** pilot figures read monthly | AN1, AN2 (IMPLEMENTED) | evidence-based decisions | hypotheses carry decision rules; the monitor marks crossings (IMPLEMENTED in part, AN2) |
| 14 | **Manual communication:** relatives phone the team | none (HYPOTHESIS row) | no channel | Family Companion (domain 3), consented logistics facts, L |
| 15 | **Manual communication:** hospital discharge by phone | REF2 (draft) | no partner channel | structured referral with guaranteed answer, A1/A8 |
| 16 | **Manual communication:** handover between nurses | HAND1 digest (IMPLEMENTED) | no shift meeting | digest stays; AI summary with sources (H) |
| 17 | **Manual communication:** between visits nobody knows how the client is | none | visits are the only contact | Check-In Services (domain 4), Clinical Owner question sets |
| 18 | **Manual documentation:** free-text report per visit | F6/F7 (IMPLEMENTED: server-built draft from facts) | the record proves care | proof of delivery from events; text only for deviations (P-2); dictation (A7, G); drafting (A9, H) |
| 19 | **Manual documentation:** observations typed on a phone | OBS1 (IMPLEMENTED) | attribution per observation | dictation into a structured observation in her words (A7, G) |
| 20 | **Manual documentation:** working day confirmed by the nurse | WORK1 (IMPLEMENTED: proposed from events) | ArG working-time record | already AI-first in shape (proposal from events); register it as a rule agent (AUT-9) |
| 21 | **Manual workflow:** statistics and cantonal reports compiled by hand | none (HYPOTHESIS) | no generated reports | generated from facts with a human release, L; after D-11 (Basel, #816) |
| 22 | **Manual workflow:** invoice preparation | J5 facts (IMPLEMENTED), BILL2 (later) | D-12, D-18 open | invoice draft as rules (A4), licence holder releases; never automatic submission |

---

## 2. Workflow by workflow: current state and future state

Each row answers the directive's questions:
- **Automate:** can AI automate it?
- **Assist:** can AI assist it?
- **Monitor:** can AI continuously monitor it?
- **Admin:** does it reduce administration?
- **Continuity:** does it increase continuity of care?
- **Hierarchy:** does it reduce hierarchy?

### 2.1 Care documentation
- **Current:**
  - The performing nurse completes the visit.
  - A server-built report draft takes the times, the planned minutes per category, the services and the observations (F6, F7). She adds an optional summary and signs.
  - Care-assistant reports are countersigned by a registered nurse (D-10).
  - *Who:* the nurse, the countersigning RN.
  - *Why:* legal documentation duty, proof of delivery, billing basis (J5), continuity.
- **Future:**
  - **Automate:** proof of delivery from visit events and the plan, so no text is needed when the visit went as planned (P-2, L).
  - **Assist:** dictation into structured entries (A7, G, stage 2) and drafting of deviation text with a source per sentence (A9, H, stage 3).
  - **Monitor:** completeness before signature; late or missing reports (L, partly IMPLEMENTED in OPS1).
  - **Admin:** strong.
  - **Continuity:** better structured observations feed handover.
  - **Hierarchy:** countersignature becomes risk-based after a parallel run (D-10, P-1).
- **Stays human:** her words, her signature, the countersignature where required.
- **Gate:** D-35 stage 2 (A7), D-34 module and Clinical Owner (A9), D-10.

### 2.2 Handover
- **Current:**
  - "Seit deinem letzten Einsatz" on each `/field` card, oldest first: observations, handovers, plan changes, moves, with author and time (HAND1, IMPLEMENTED).
  - *Who:* the next nurse reads.
  - *Why:* continuity without a team meeting.
- **Future:**
  - **Automate:** ordering by rule (open signals, plan changes, safety values first) (L).
  - **Assist:** a summary across many entries with a source per claim and "nichts Neues" made explicit (H, stage 3).
  - **Monitor:** unread handovers before a visit starts (L).
  - **Admin:** fewer calls between colleagues.
  - **Continuity:** strong.
  - **Hierarchy:** the shift lead as knowledge carrier disappears (already true with HAND1).
- **Gate:** D-34 module for the summary.

### 2.3 Planning
- **Current:**
  - PLAN2 generates a rolling four-week series from the care plan (IMPLEMENTED).
  - The team sets the responsible nurse visit by visit (J3).
  - PLAN3 (approved, not built) proposes who takes each open visit, confirmed line by line through AIG1.
  - Day order and route: each nurse by hand.
  - *Why:* coverage, continuity, qualification.
- **Future:**
  - **Automate:** visit series (done) and the daily assignment proposal (PLAN3, L).
  - **Assist:** the day order and route proposal (A3, AUT-5, L); Q7 location data, D-11 geography.
  - **Monitor:** coverage gaps 24 h ahead, overlaps (VIS2, IMPLEMENTED), continuity drift per client (J6 measure).
  - **Admin:** removes the scheduling administrator.
  - **Continuity:** continuity is the first weight.
  - **Hierarchy:** strong.
- **Gate:** labour-law rules (`legal`), Q7, D-11 (#816).

### 2.4 Referrals
- **Current:**
  - Intake creates a case from a partner request; a readiness check with reasons (J1); the matching request is opened by intake.
  - REF2 (draft) moves the referral to the hospital.
  - *Who:* intake staff.
  - *Why:* a structured, ready case.
- **Future:**
  - **Automate:** completeness check back to the referrer at once (A1, rule, L).
  - **Assist:** extraction of a discharge letter into a referral draft, safety values confirmed one by one (A8, H).
  - **Monitor:** unanswered referrals and the response deadline (L).
  - **Admin:** the intake coordinator becomes an exception.
  - **Continuity:** RET1 links to a known team.
  - **Hierarchy:** strong.
- **Gate:** D-9, D-3, REF2; D-34 module for A8.

### 2.5 Operations monitoring
- **Current:**
  - OPS1 derives ten exception types in the database.
  - SIG1 delivers P1 safety signals to the responsible nurse and her team, and to Operations only when nobody takes them (IMPLEMENTED).
  - The AIG1 health list shows stopped agents.
  - *Who:* teams first, Operations last.
- **Future:**
  - **Automate:** control health (A6, rules: failed jobs, undelivered signals, evaluator runs).
  - **Assist:** grouping and explaining exceptions, drafting the next step (L; language under D-35 stage 1).
  - **Monitor:** continuous by design.
  - **Admin:** Operations shrinks to the residue.
  - **Hierarchy:** the control tower disappears.
- **Never:** AI re-ranking of P1 signals (AI-10).

### 2.6 Quality management
- **Current:**
  - Quality events and holds from the visit (QG1); KPIs (AN1); hypotheses with decision rules (AN2).
  - Holds are reviewed by people.
  - *Why:* quality accountability, payer and canton requirements.
- **Future:**
  - **Automate:** quality indicators from events, continuously (L).
  - **Assist:** clustering of quality-event narratives and an evidence pack for the hold review (H for clinical clustering; L for the pack).
  - **Monitor:** indicator crossings against written decision rules (AN2 pattern).
  - **Admin:** no manual quality report.
  - **Continuity:** indirect.
  - **Hierarchy:** the quality officer's sampling becomes continuous evidence.
- **Gate:** D-16, Clinical Owner, D-34 module.

### 2.7 Family communication
- **Current:** none in NAVORA. Relatives phone the team (challenge row, HYPOTHESIS).
  - *Who:* the nurse on the phone.
  - *Why:* uncertainty about time, who comes, changes.
- **Future:**
  - **Automate:** visit window, who comes and changes shown to a consented relative (L).
  - **Assist:** routing of questions; the drafted reply is sent by a team member (L for logistics; health content never automated).
  - **Monitor:** unanswered messages (L).
  - **Admin:** fewer calls.
  - **Continuity:** the relative becomes a first-class actor (handbook proposal).
  - **Hierarchy:** none.
- **Gate:** D-9, D-3, new D-40.

### 2.8 Workforce coordination
- **Current:**
  - Teams admit colleagues (ADM2, IMPLEMENTED), contract end, qualifications, working-day confirmation (WORK1), cross-team cover (COVER1).
  - *Who:* team, administrator.
- **Future:**
  - **Automate:** admission paperwork checklist, qualification gap list, contract-end hand-over list (L, partly IMPLEMENTED).
  - **Assist:** capacity view per team and week with a proposal to rebalance across teams (L).
  - **Monitor:** team load and continuity, never per person (AI-9).
  - **Admin:** less HR administration.
  - **Hierarchy:** no central HR dispatcher.
- **Gate:** labour law (`lca`), D-23.

### 2.9 Absence handling
- **Current:**
  - A member records an absence in two taps; her visits are released to her team (ABS1, IMPLEMENTED); cover offers (COVER1).
- **Future:**
  - **Automate:** a re-assignment proposal at the moment of release, continuity first (L, with PLAN3).
  - **Assist:** a message to affected clients or relatives through the Family Companion, with consent (L).
  - **Monitor:** visits still without a taker before their start (SIG1, IMPLEMENTED).
  - **Admin:** the phone chain disappears.
  - **Hierarchy:** the shift lead's role disappears.

### 2.10 Transitions of care
- **Current:**
  - Pause and resume around a hospital stay (C1); a returning client goes back to the known team (RET1); REF2 (draft) for discharge.
- **Future:**
  - **Automate:** the transfer view as a scoped read of the record instead of a letter (A12 preferred as view, L).
  - **Assist:** a transfer draft from the graph (A12, H); discharge letter extraction (A8, H).
  - **Monitor:** the discharge date against the first visit (P1 rule, IMPLEMENTED in OPS1).
  - **Admin:** strong.
  - **Continuity:** very strong (one record, not a transfer summary).
- **Gate:** D-9, D-3, D-34.

### 2.11 Nursing-home workflows (NH0-NH9, #818)
- **Current (source-based, not built):**
  - Station leadership plans shifts and checks documentation.
  - A coordinator runs the periodic assessment project; MQI reporting (`NURSING_HOME_TRANSFORMATION.md`).
- **Future:**
  - **Automate:** the roster from the residents' care plans (A3, L); MQI indicator preparation from the record (L where the definitions are licensed and approved).
  - **Assist:** the evidence layer for reassessment (A11, H); shift handover (domain 2).
  - **Monitor:** continuous MQI-relevant facts instead of a periodic project (L for completeness).
  - **Admin:** strong.
  - **Hierarchy:** station leadership becomes named licensed functions (`CARE_OPERATING_MODEL.md` *What disappears*).
- **Gate:** D-24 (owner answered past A, #818), D-25 (Basel rules), D-36, D-37, D-34, G-1.

### 2.12 LTCF / interRAI-related activities
- **Current:**
  - ASM1: one append-only, signed assessment record, the care plan shows the assessment it rests on (IMPLEMENTED).
  - No item, score, CAP or category computed (D-13 B, D-36 A).
- **Future:**
  - **Automate:** header import from the licensed tool (AUT-13, L).
  - **Assist:** evidence linking between assessments (A11, H) and a missing-evidence list before reassessment (H).
  - **Monitor:** reassessment due, only once the Clinical Owner sets the interval.
  - **Admin:** no re-typing.
  - **Continuity:** the assessment follows the client across settings (D-37).
- **Never:** NAVORA computes no licensed outputs outside the licensed tool and the clinical module.
- **Gate:** D-36, D-37, D-34 module, Clinical Owner.

---

## 3. Ranking (owner's value order; safety is a precondition)

| Rank | Opportunity | Values | Level | Can run before D-35 stage 1? | Next step |
|---|---|---|---|---|---|
| 1 | PLAN3 assignment proposal with continuity first (domain 5) | 2, 1, 4, 5 | L | **yes** (rule) | build (*Active now*) |
| 2 | AI orchestrator, agent contract and evaluation harness (foundation for all domains) | 7, safety | L | **yes** (synthetic) | brief **AIO1** (roadmap) |
| 3 | AN3 per-step baseline before any AI removes a step | 1, 5 | L | **yes** | `lca` read, then approve |
| 4 | Control health and exception explainer (domain 6, A6) | safety, 5 | L | rules yes; language no | brief **OPS2** |
| 5 | Handover digest ordered by rule (domain 2) | 2, 1 | L | **yes** | brief **HAND2** |
| 6 | Referral completeness (A1, domain 9) | 5, 1 | L | **yes** (rule) | with REF2 after D-9 |
| 7 | Proof of delivery from events, documentation by exception (domain 1) | 1, 5 | L | **yes** | brief **DOC2** (`cra` on P-2) |
| 8 | Family Companion, logistics only (domain 3) | 2, 5 | L | rules yes | D-40 package, D-9 |
| 9 | Order renewal request (A2) | 5, 2 | L | needs D-22 | after D-22 |
| 10 | Dictation (A7, domains 1 and 10) | 1 | G | no | D-35 stage 2, adviser |
| 11 | Check-In Services (domain 4) | 6, 2 | L/H | no | Clinical Owner, D-40, D-39 |
| 12 | Report and handover drafting, intake extraction, review proposals, evidence layer (A8-A11) | 1, 2, 6 | H | no | D-34 clinical module (stage 3) |

## Change log
- 2026-11-03 po: created from the owner's Strategic Architecture Directive.
