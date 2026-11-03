# NAVORA AI-First Architecture Update

**Author:** Product Owner (`po`) · **Date:** 2026-11-03 (Europe/Zurich) · **Requested by:** the owner, *Strategic Architecture Directive* (2026-11-03): "NAVORA is officially an AI-first platform." · **Status:** architecture and handbook update. It changes principles and the design method. It approves no build by itself and lifts no decision or gate. **Repository state read:** `recovery/main` @ `adf80a3`.

**Companion documents:** [AI Opportunity Map](AI_OPPORTUNITY_MAP.md) (workflow by workflow) · [AI Capability Roadmap](AI_CAPABILITY_ROADMAP.md) (stages, briefs, decisions) · earlier basis: [AI Operating Model Review](AI_OPERATING_MODEL_REVIEW.md) (2026-10-26), [Strategic Alignment Review](STRATEGIC_ALIGNMENT_REVIEW.md) §3 (staged AI path), [Transformation Alignment Report](TRANSFORMATION_ALIGNMENT_REPORT.md).

**Status labels:** IMPLEMENTED (exists, synthetic data only) · PLANNED · OPEN (needs a decision) · UNKNOWN.

---

## 0. Owner directive 2026-11-03 14:00 (post-PR #822): human-in-the-loop is mandatory

The principles of this document are the **default operating model** for every future brief, capability, epic and architecture proposal.

**AI may:** prepare, summarise, prioritise, draft, monitor, suggest.

**AI may not:**
- make accountable decisions;
- replace signatures;
- replace required approvals;
- execute clinical judgement.

**Mandatory sequence:**

> **Remove unnecessary work → Apply rules → Monitor continuously → AI prepares → Human reviews → Human decides → Human signs**

A proposal that violates this sequence is **rejected** by the PO (`changes-requested` on a brief, a flag on an architecture proposal). "Prioritise" never includes setting, lowering or suppressing the priority of a P1 safety signal (AI-10).

**Prohibited** (owner directive; `eng` enforces in code and architecture, flags violations):
- automatic billing decisions;
- automatic clinical recommendations to patients or relatives;
- automatic clinical prioritisation of safety signals;
- unrestricted general-purpose copilots on production data;
- AI replacing accountable human decisions.

**Freeze:** D-39 (sensors, IoT) and D-40 (Family Layer, Check-In Services) are specification only. No implementation, no database table, no migration and no production architecture until owner approval.

**Synthetic-data AI development allowed:** PLAN3, AN3, AIO1, OPS2, HAND2. Synthetic data only; no real patient, employee or production data; compliant with D-1, D-34 and D-35.

**Role duties (no overlapping ownership):**

| Role | Duty |
|---|---|
| `po` | decides what is built and in which order; rejects briefs that break the sequence |
| `eng` | enforces the restrictions in code and architecture and flags violations (§6.1) |
| `cra` | reviews every AI proposal for patient safety, accountability, clinical governance, auditability and human oversight; records clinical decision-support risk as a regulatory finding (§6.2) |
| `lca` | prepares the D-34 AI assessment as decision support; makes no regulatory determination without the owner (§6.3, D-34 package) |

---

## 1. What changes, in one page

1. **AI is a core architectural pillar, not a later feature.** Before this directive the doctrine was *graph-first, agents at the edges* (AI Operating Model Review §1): AI agents only where input is unstructured or a draft is needed. From now on the AI layer is designed together with every capability from its first brief. Every brief states how the work would be done if AI had existed from day one (§5, brief template).

2. **The design question changes.** It was "which step can an agent help with?". It is now: **"Which human work exists only because nobody could read, connect, summarise or watch the record continuously?"** That work is redesigned so the AI layer does it, and people keep judgement, relationship, accountability and signatures.

3. **AI-first does not mean "an AI in every former role".** The care graph (one continuously updated record) stays the foundation. An agent that re-types, chases or summarises fragmented information is worse than a record where that information is never fragmented. The new design order (§3) puts AI before manual process, but after the structured record.

4. **Human-in-the-loop stays mandatory** for every clinical and accountable decision. AI never overrides a clinical rule, never replaces accountability or a required signature, and never takes an uncontrolled clinical decision (§4).

5. **What the directive does not change.** These stay in force until the owner or the named role decides otherwise:
   - **D-35 rule A:** during the pilot, no client or staff data reaches any AI service.
   - **D-34 A plus C:** AI that interprets clinical content is built only as a separately qualified clinical module.
   - The owner rule of 2026-10-29: no real client data until D-1 is clarified.
   - **G-1:** clinical rules need the named Clinical Owner.
   - **P-1:** no control is retired without a parallel run.

   AI-first therefore starts with what can run now: the governance layer (IMPLEMENTED), deterministic and monitoring agents, and evaluation on synthetic data. Language-model agents follow when the owner opens the stage-1 package (provider, region, contract).

6. **Critical path for an AI-first pilot (owner asks):**
   - (a) open the D-35 stage-1 package: an AI provider with processing in Switzerland or the EU, a contract and a DPIA;
   - (b) name the regulatory adviser for D-34, including the EU AI Act question 8;
   - (c) name the Clinical Owner (G-1).

   Without (a) no language model runs on real data. Without (b) and (c) no clinical AI runs at all. See the [roadmap](AI_CAPABILITY_ROADMAP.md) §4.

---

## 2. Where today's architecture assumes humans (summary)

The [Opportunity Map](AI_OPPORTUNITY_MAP.md) §1 lists every case. In short:

| Assumption | Where it is built today | What stays human by design | What AI-first changes |
|---|---|---|---|
| **Human coordination** | team pull on offers (J2); responsible nurse chosen visit by visit (J3); COVER1 offers; ABS1 release; OPS1 exception centre | the team's decision; the licence holder's accountability | AI prepares every coordination decision as a ranked, explained proposal (PLAN3 pattern) and watches that it was taken. The team confirms instead of working the problem out |
| **Manual workflows** | intake re-typing (J1); care-plan entry (J3); assessment header typed from the provider's tool (ASM1) | the RN's assessment and plan decision | Capture once at the source (referral, assessment tool, dictation), extracted into a draft that is confirmed field by field |
| **Manual review** | countersignature of every care-assistant report (F6, D-10); calendar care-plan review; QG1 hold review; monthly KPI reading (AN1) | the signature where the law requires it; the Clinical Owner's rules | Continuous monitoring finds what needs review; review becomes risk-based and evidence-led (P-1 before any review is retired) |
| **Manual communication** | GP orders by phone and fax (ORD0 records only the task); relatives phoning the team; hospital discharge by phone; handover between shifts | the conversation at the door; consent; clinical advice | Structured messages drafted by AI, sent by a person; a consented family layer answers routine questions from the record; check-ins collect what the client reports |
| **Manual documentation** | free-text report per visit (F6/F7); observations typed on a phone (OBS1); handover notes | the nurse's own words and signature | Proof of delivery from events; documentation by exception (P-2); dictation into structured entries; drafts from the record with a source per claim |

---

## 3. The AI-first design method (mandatory sequence, owner 2026-11-03)

Every capability is designed in this order. Each step is asked in turn; a later step handles only what the earlier steps leave.

| Step | Question | Typical form | Device level (D-34) |
|---|---|---|---|
| **1 Remove unnecessary work** | Does this work exist only because information is fragmented, late or re-typed? Then it disappears through the care graph. | one record, events, structured facts at the source | L |
| **2 Apply rules** | Is the decision rule-shaped and approved (by the Clinical Owner when clinical)? | deterministic, versioned, tested rule; "Warum?" explanation | L, or the clinical rule's owner |
| **3 Monitor continuously** | Can drift, gaps, delays and risk be detected from the record as they happen, instead of by periodic checks? | monitors over the graph (controls, completeness, delivery, agents, access) | L for operational facts; H when interpreting clinical content |
| **4 AI prepares** | Is the input unstructured (letter, speech, free text), or is the output a draft, summary, ranked proposal or message for a person, including people outside the team (client, relative, GP, discharge planner)? | agents with a contract (§5.1): scoped input, typed output, source per claim, ledger | L, G or H by content |
| **5 Human reviews** | Who reviews the prepared output, with its sources and its "not found" items in view? | confirm list, record page; one by one for listed fields (AIG1-5) | – |
| **6 Human decides** | Who takes the accountable decision? | a named person confirms, changes or rejects; the record shows "vorgeschlagen von / bestätigt von" (AIG1-3) | – |
| **7 Human signs** | Which signature or required approval does the law or the Clinical Owner demand? | signed report, countersignature (D-10), hold lift, licence holder's release | – |

**Difference from the earlier order (2026-10-26):**
- Step 4 is no longer restricted to "the edges of the graph". AI may prepare any decision inside the graph, as a proposal with sources.
- Communication with people outside the team is prepared by AI and sent by a person.
- Steps 5 to 7 make review, decision and signature explicit and mandatory.

## 4. Updated architectural principles (AI pillar)

These principles are added to `ARCHITECTURE.md` (§ *Architekturprinzipien*, KI-Säule) and apply to every brief from 2026-11-03.

**AI-1 AI is a core capability.** Every brief contains the section *AI leverage* (brief template). It answers the seven steps of §3. "No AI leverage" is a valid answer only with a reason.

**AI-2 Record first, then AI.** AI reads and writes through the care graph. No agent keeps its own copy of client data, its own memory of a person or a parallel record. Output enters the record only as a proposal (AIG1-3).

**AI-3 Human-in-the-loop for clinical and accountable decisions.** AI never:
- overrides a clinical rule;
- replaces accountability;
- replaces a required signature;
- takes an uncontrolled clinical decision.

A proposal becomes record content only through a named person who can in fact reject it (AIG1-3, AIG1-5).

**AI-4 Every AI influence is evidence.** Every suggestion, prediction and draft is written to the append-only ledger, with input reference, model and version, output, confirmer and edits (AIG1-2, IMPLEMENTED). No second, parallel AI log: risk predictions and sensor-based outputs extend this ledger (#817).

**AI-5 Scope inheritance.** An agent reads only what its confirmer may read (RLS2 to RLS4, D-3). No agent has organisation-wide read access. A "copilot across all data" is not built.

**AI-6 Earn scope with measured evidence.**
- Each agent has a correction rate and a later-error count per agent and field, per team, never per person.
- Each agent has a written stop threshold (P-6, AIG1). A stop is automatic.
- A human control is retired only after a parallel run on a written decision rule (P-1).

**AI-7 Risk level decides the route.**
- Level L (logistics, administration, operational facts) runs in the core.
- Level G (transcription) needs the regulatory adviser's answer.
- Level H (interprets clinical content for an individual's care) runs only in the separately qualified clinical module (D-34 C), with the Clinical Owner.

**AI-8 Data stays protected.**
- Minimisation runs before any provider call.
- Provider, region and contract are decided by the owner (D-35); processing in Switzerland or the EU.
- No secondary use beyond anonymised aggregates.
- No training of external models on NAVORA data without a separate owner decision.
- Professional secrecy (StGB Art. 321) and DSG are reviewed by `lca` per agent.

**AI-9 Never per person.** No performance score, ranking or productivity profile of a care professional, from any agent or monitor. Team-level measures only. This is a product principle; `lca` checks it against the labour-law rule on monitoring employees' behaviour.

**AI-10 Deterministic where safety needs it.** P1 safety signals stay rule-based (D-28, SIG1). AI may explain, group or draft around a signal, but it never sets, lowers or suppresses its priority.

**AI-11 Explainable and reversible.**
- Every AI output names its sources, its time range, its uncertainty and what it did not find ("nicht gefunden", AIG1-4).
- Every applied proposal can be traced and reversed by a new attributed entry.

**AI-12 Designed to remove administration, measured.** Each AI capability names the administrative step it removes and its baseline measure (AN3 per-step spans, P-19). The North Star (direct care share) and its balancing measure (P-5) decide whether it stays.

---

## 5. Architecture of the AI layer

```text
              People: nurse · team · client/relative · GP · discharge planner · licence holder
                 ↑ confirm / reject / answer        ↑ consented, scoped channel
        Human surfaces: /field, /team, record page, confirm list, family layer, partner forms
                 ↑
   AI Orchestrator (server-side)
     intent/trigger → scope check → minimisation → model/rule → schema validation
     → source-per-claim check → ledger write → proposal
                 ↑                          ↑
   Agent registry (AIG1-1)          Evaluation harness (synthetic cases, per agent version)
   contracts: input scope,           correction rate, later errors, stop rule (AIG1, P-6)
   output schema, field classes,
   level L/G/H, confirmer
                 ↑
   Event stream and monitors (visit events, signals, exceptions, deliveries, agent health)
                 ↑
   Care graph (PostgreSQL, RLS, audit, provenance per value)    ← system of record
```

**IMPLEMENTED (synthetic data):**
- agent register, stop table, field classes and the one-by-one field list;
- suggestion ledger and confirmations (migration 0097, `ai_*` tables, AIG1);
- the look-back after a stop (0103, 0104);
- deterministic proposers: PLAN2 visit generation, WORK1 day proposal, HAND1 handover digest, OPS1 derived exceptions, SIG1 signals.

**PLANNED:**
- the AI orchestrator as one server-side component with the pipeline above (`ARCHITECTURE.md` *Geodaten und KI*);
- the evaluation harness as a CI job per agent version;
- the event-driven trigger layer for monitors.

**OPEN:** the provider, the region and the contract (D-35 stage 1); the clinical module's conformity route (D-34).

### 5.1 Agent contract (every agent, before it is built)

| Field | Content |
|---|---|
| Purpose and removed work | which human step it removes or shortens; baseline measure (AN3) |
| Trigger | event, schedule or user intent |
| Input scope | which rows, read through the confirmer's access; minimisation applied |
| Output | typed schema; field class `schedule` or `record` (AIG1-5); `not_found` explicit |
| Sources | every claim links to its rows; unsupported claims are marked |
| Confirmer | named role; one-by-one fields per the Clinical Owner's list (D-17 part 3) |
| Level and gate | L, G or H (D-34); D-35 stage; Clinical Owner where clinical |
| Measures | correction rate, later errors, removed minutes; balancing measure |
| Stop rule | threshold, automatic stop, look-back of applied values |
| Never | the agent's explicit "never" list (from §4 and the domain below) |

### 5.2 The ten AI domains

Each domain is an operational capability built from several agents and monitors under one contract family, not a chatbot. Opportunity detail per workflow: [Opportunity Map](AI_OPPORTUNITY_MAP.md) §2.

| # | Domain | What it does operationally | Built from | Confirmer | Level | Gate | Existing basis |
|---|---|---|---|---|---|---|---|
| 1 | **AI Documentation Copilot** | proof of delivery from visit events; documentation only for deviations (P-2); dictation into structured entries in the nurse's words; report draft from the visit's facts with a source per sentence; completeness shown before signature | event-to-report rule; A7 dictation; A9 drafter | performing nurse (signs); countersigner per D-10 | L (events, completeness) · G (dictation) · H (drafting from clinical content) | D-35 stage 2 (A7), D-34 module (A9), Clinical Owner | F6/F7 server-built draft from facts (IMPLEMENTED), OBS1 |
| 2 | **AI Handover Assistant** | per visit and per shift, what changed since she was last there, ordered by rule (open signals, plan changes, new observations); later a summary of the observations with sources | HAND1 digest (rule); A9 handover summary | the next nurse reads; nothing is applied | L (digest) · H (summary of clinical content) | D-34 module for the summary | HAND1 "Seit deinem letzten Einsatz" (IMPLEMENTED) |
| 3 | **AI Family Companion Layer** | for a client or a named relative, with consent: visit window, who comes, changes, how to reach the team; routine questions answered from logistics facts; anything else becomes a task for the team with a drafted reply the nurse sends | consented read of logistics facts; message router; reply drafter | a team member sends every non-logistics answer | L (logistics) · H (any health content: never automated) | D-9 (consent), D-3, **D-40** (opened 2026-11-03; **frozen, specification only**) | none; challenge row "relatives phone the team" (HYPOTHESIS) |
| 4 | **AI Check-In Services** | between visits, a scheduled, structured check-in with the client (app, phone or voice): the RN chooses the questions from a set the Clinical Owner approved; answers are stored as *client-reported facts* with time and channel; an answer outside the approved band becomes a team task (not a P1 signal unless the Clinical Owner makes it one); sensor readings (#817) can feed the same facts | check-in scheduler; question set (clinical rule); answer recorder; deviation rule | primary nurse | L (logistics questions) · H (health questions and any interpretation) | Clinical Owner (question sets, bands), D-34 adviser, D-9, **D-40** and **D-39** (sensors, #817; both **frozen, specification only**) | none |
| 5 | **AI Workforce Coordination** | proposals for who takes each open visit (continuity first), cover across teams, absence re-assignment, capacity per team and week, team admission paperwork; never per-person scoring | PLAN3 proposer (rule); COVER1/ABS1 proposers; capacity monitor | team (confirms line by line) | L | labour-law rules (`legal`), Q7 for travel, D-3 for cover reads | PLAN3 (approved), ABS1, COVER1, ADM2 (IMPLEMENTED) |
| 6 | **AI Operations Monitoring** | continuous watch of delivery and controls: late or stuck visits, undelivered signals, failed jobs, stopped agents, expired orders, unanswered referrals; groups and explains exceptions; drafts the next step; Operations sees only what teams did not resolve | OPS1 rules; A6 control health; exception explainer | team first, Operations last | L | none for rules; D-35 for language explanations | OPS1, SIG1, AIG1 health list (IMPLEMENTED) |
| 7 | **AI Quality Monitoring** | continuous quality indicators from events (documentation completeness, late reports, returns, corrections, holds, continuity); hypotheses with their decision rule (AN2); clusters of quality events for the team's review | AN1/AN2 rules; quality monitor; event clustering | team; Clinical Owner for serious events | L (indicators) · H (clustering clinical narratives) | D-16, Clinical Owner; D-34 module for clinical clustering | QG1, AN1, AN2 (IMPLEMENTED) |
| 8 | **AI Evidence Layer for Assessments** | between assessments, links the team's observations to the assessment domains as evidence for the assessing RN, shows what is missing before a reassessment, and imports the header of a licensed assessment instead of re-typing it; never scores, never computes CAPs or categories | evidence linker (A11); import (AUT-13) | assessing RN | H (linking clinical content) · L (header import) | D-36 licence, D-37, D-34 module, Clinical Owner | ASM1 assessment record (IMPLEMENTED) |
| 9 | **AI Referral Preparation** | a hospital or GP referral arrives structured; missing administrative items are asked back to the referrer at once; a discharge letter is extracted into a referral draft with safety values confirmed one by one | A1 completeness (rule); A8 extraction | referrer; receiving nurse | L (A1) · H (A8) | REF2, D-9, D-3; D-34 module for A8 | J1 intake (IMPLEMENTED); REF2 (draft) |
| 10 | **AI Nurse Assistant** | one assistant on `/field` with a fixed set of operational intents, each mapped to an existing query or command: what is next, what changed, record this (dictation), draft this (report, renewal request), who can cover, what is missing before I sign. No open clinical Q&A | intent router over domains 1, 2, 5, 9 | the nurse | inherits the level of the intent used | inherits | `/field` (IMPLEMENTED) |

**Not built in any domain:**
- AI triage or re-ranking of P1 safety signals;
- per-person performance scoring;
- automatic coding, care-plan changes or billing submissions;
- a general copilot across all data;
- unconfirmed record entries;
- clinical advice to clients or relatives by an AI;
- automatic billing from sensor data or predictions (#817: evidence attached to a signed report only).

---

## 6. Team alignment

### 6.1 Engineering (`eng`): how AI shapes design decisions
- **Design every write as a proposal-capable command.**
  - Each command can take its input from a person or from a confirmed proposal.
  - The command re-checks every value it receives (AIG1 pattern).
  - The record shows "vorgeschlagen von / bestätigt von".
- **Emit events, not only state.** Monitors and agents need the time series (who, what, when). New tables carry created and changed timestamps and the acting person. Status changes are events.
- **Structured first.** Every new field gets a type, a code list or a reference. Free text only where the content is narrative, and then with its author and time. AI extracts into structure; it does not compensate for missing structure.
- **One orchestrator.** All AI calls go through one server-side component. It handles scope check, minimisation, provider call, schema validation, source check and ledger write. Never call a model from a page or a client.
- **Agent contract and evaluation in CI.** Each agent ships with its contract (§5.1), its synthetic evaluation set and its stop threshold. A new agent version is evaluated before it can be switched on.
- **No new read paths for agents.** An agent uses the confirmer's functions. A reader that aggregates per person is refused in review.
- **Provider-neutral.** No provider SDK in domain code. The provider is a configuration under D-35.
- **Ask, in every ADR:** "How would this work if the AI layer did it from day one?", and name the agent or monitor it enables or blocks.
- **Enforce the owner's prohibitions (2026-11-03) in code and architecture, and flag violations:**
  - automatic billing decisions;
  - automatic clinical recommendations to patients or relatives;
  - automatic clinical prioritisation of safety signals;
  - unrestricted general-purpose copilots on production data;
  - AI replacing accountable human decisions.

  Where a guard can be tested (an `ai` agent cannot switch on under D-35 A; no agent writes a record value without a confirmation; no agent changes a signal priority), it gets a pgTAP or unit test.
- **Frozen:** no code, table, migration or production architecture for D-39 or D-40.

### 6.2 Clinical & Regulatory Architect (`cra`): how AI opportunities are reviewed
For each AI capability, before approval:
1. **Level:** does it interpret clinical content for an individual (H)? If yes, it belongs in the D-34 clinical module.
2. **Hazards:** omission ("not found" read as "none"), automation bias, wrong client or visit, stale data, over-alerting, under-alerting. Each gets a control and a test (`HAZARD_LOG.md`).
3. **Field classes:** which fields are confirmed one by one (the Clinical Owner's list, D-17 part 3).
4. **Clinical rules:** thresholds, question sets and bands are the Clinical Owner's. The agent never sets them.
5. **Parallel run:** which human control it relieves, the decision rule and the minimum base before that control is retired (P-1).
6. **Signals:** confirm that P1 signals stay deterministic and that the agent cannot suppress or delay one.
7. **Evaluation:** a synthetic case set covering the hazards; correction-rate and later-error thresholds proposed for the stop rule.
8. **Owner directive 2026-11-03:** review every AI proposal against patient safety, accountability, clinical governance, auditability and human oversight. Verify "AI prepares – Humans decide". Any proposal that risks entering **clinical decision-support territory** is recorded as a regulatory finding (CGR).

### 6.3 Legal & Compliance (`lca`): capabilities with regulatory implications
`lca` analysis is advisory; the legal adviser and the owner decide.

| Capability | Why it may have regulatory implications | Questions for `lca` |
|---|---|---|
| Any language-model agent on real data | DSG (processing, cross-border transfer, processor terms), professional secrecy (StGB Art. 321), information duties | D-35 stage-1 package: provider, region, contract, DPIA, sub-processors |
| Documentation drafting, handover summaries, evidence linking, intake extraction, check-in interpretation, risk prediction | medical device software (MepV, aligned with EU MDR); EU AI Act where EU persons or markets are reached (D-34 q8) | D-34 adviser questions; intended purpose of the clinical module |
| Family Companion, Check-In (client- or relative-facing AI) | transparency that the person is talking to an AI; consent and the legal basis per relative (D-9); representation of persons without capacity; liability for answers | new package **D-40** |
| Sensors and predictions (#817) | health data in a private home; consent of everyone in the household; retention; device law | proposed **D-39** |
| Workforce coordination, any staff-related monitor | labour law (rules on monitoring employees' behaviour, working-time records, D-23), co-determination, non-discrimination in assignment proposals | check AI-9 against labour law; terms for PLAN3 and cover proposals |
| Billing preparation from AI-assisted records | KVG/KLV: which documentation supports a billed service; tariff contract (D-18); medical order (D-22) | whether any billable service may rest on an AI draft without a signed record (#817 question 5) |
| Records drafted by AI | documentation duties and correction rights (D-30); provenance per value as evidence | whether the provenance line meets the canton's documentation duty |

---

## 7. Handbook statements (for every reader)

1. **AI is a core architectural pillar of NAVORA.** It is designed with every capability, not added later.
2. **Every future capability is evaluated for AI leverage** with the mandatory seven-step sequence (§3) and documented in its brief.
3. **Human-in-the-loop remains mandatory** for clinical and accountable decisions. AI proposes, explains, monitors and drafts; people decide, sign and answer for the care.
4. **AI is used to eliminate administrative overhead wherever it is safe.** "Safe" means: the level, the gate and the controls of §4 and §5 hold, and the removed step is measured.

## Change log
- 2026-11-03 po: created from the owner's Strategic Architecture Directive.
- 2026-11-03 14:00 po: owner directive *post-PR #822 alignment*: §0 added (mandatory sequence, prohibitions, freeze of D-39/D-40, synthetic-data list, role duties); §3 becomes the seven-step sequence.
