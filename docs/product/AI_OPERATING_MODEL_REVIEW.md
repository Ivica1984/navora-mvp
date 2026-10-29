# NAVORA AI Operating Model Review

**Maintained by:** AI & Automation Architect (`aia`) from 2026-10-27 (owner). The staged AI path approved by the owner on 2026-10-27 is in [`STRATEGIC_ALIGNMENT_REVIEW.md`](STRATEGIC_ALIGNMENT_REVIEW.md) §3; findings go to [`../agents/reports/AUTOMATION_REVIEW.md`](../agents/reports/AUTOMATION_REVIEW.md).

**Author:** Product Owner (`po`) · **Date:** 2026-10-26 (Europe/Zurich) · **Requested by:** the owner ("Follow-up Review", after the [Transformation Alignment Report](TRANSFORMATION_ALIGNMENT_REPORT.md)) · **Status:** strategic review. It approves no build. It opens one decision (D-35, §9). **Repository state read:** `recovery/main` after #458.

**Question:** what does a care operating system look like when it is designed AI-first? The aim is not a better LTCF or interRAI workflow, but a superior operating system for self-organised care.

**Status labels:** IMPLEMENTED (exists, synthetic data only) · PLANNED · OPEN (needs a decision) · UNKNOWN.

**Boundaries this review keeps.** It does not weaken them; it designs around them.
- No clinical, PAG, MQI or LTCF rule is invented, and no licensed instrument is reproduced (D-13 B, D-24).
- Any AI that **interprets clinical content** to produce information for an individual's care is D-34 level **H**. It lives in a separately qualified module, after the regulatory adviser's answer and the Clinical Owner's approval (D-34 module rule, [Intended Purpose Assessment](../agents/reports/D34_INTENDED_PURPOSE_ASSESSMENT.md)).
- No AI provider, model or hosting country is chosen yet (`ARCHITECTURE.md`: "Anbieter und Betriebsort OPEN"). Sending client data to any AI service is a data-protection and professional-secrecy question (DSG, StGB Art. 321 as raised by `lca` in D-12). It is OPEN and opened here as **D-35**.
- No control is removed without a parallel run (principle P-1, `CARE_OPERATING_MODEL.md`).

---

## 1. Answer in one page

**1. Most of the work an AI agent would "take over" should disappear instead.**
- Coordination, re-typing, chasing, checking and meeting about information exist mainly because information is **fragmented**: across people, shifts, organisations, paper and periodic projects.
- If NAVORA keeps one **continuously updated care graph**, that work is not delegated to an agent; it stops existing. The graph links every client, need, plan, visit, observation, decision, person, order, consent and outcome, with source, time and access scope.
- NAVORA is already most of that graph. About 60 tables hold the case, plan, visits, events, observations, reports, signals, quality events, orders, safety values, memberships, absences, cover, working days and billing facts (IMPLEMENTED).

**2. The AI-first order of design:**
- (1) **eliminate** the work through the graph;
- (2) **automate** what is rule-shaped with deterministic, tested rules;
- (3) **monitor continuously** what can drift: service delivery, data completeness, controls, agents, access;
- (4) use **agents** only where the input is unstructured (letters, speech, free text) or the output is a draft for human judgement;
- (5) keep **people** for judgement, accountability and relationship.

This order is safer, cheaper and more auditable than putting an AI agent in every former role. It also keeps most of the gain at device-risk level **L**.

**3. Agents are worth most at the edges of the graph**, where information enters from outside:
- discharge letters, GP orders, dictation;
- documents leaving for insurers, cantons and GPs;
- drafts of text that people still have to write.

Inside the graph, rules and monitoring usually beat agents.

**4. The new control layer is AI governance itself.** Every AI suggestion is recorded in an append-only ledger, which makes AI-assisted care more auditable than today's human-only care:
- input reference;
- model and version;
- output;
- who confirmed it;
- what she changed.

Every agent carries:
- its correction rate;
- the errors found later;
- a stop switch.

**5. What stays human, and is strengthened:**
- the registered nurse's assessment, judgement and signature (KLV Art. 8a as quoted in the NH report);
- the team's decisions;
- the Clinical Owner's rules (D-27);
- the licence holder's accountability;
- the GP's order (D-22);
- the client's consent and preferences (D-9);
- the relationship at the door.

---

## 2. The care graph

### 2.1 What it is
A continuously updated, provenance-carrying record of the client's care. Its nodes and edges are written by the work itself: a visit event, a signature, a decision, a release, an order. Nobody types them for reporting. Every node carries:
- **who** wrote it, **when**, from **which source** (nurse, client, relative, GP, hospital, system);
- its **version** (append-only; corrections link to what they correct);
- its **access scope** (team, cover, purpose-bound reader; RLS2, RLS3, AUD1);
- its **consent basis** where one is needed (D-9 g4).

### 2.2 What NAVORA already holds (IMPLEMENTED, synthetic data)

| Graph area | Tables (migrations) |
|---|---|
| Client journey | `partner_requests`, `cases`, `referral_links` (RET1), `case_lifecycle_events`, `case_tasks` |
| Matching and team decision | `matching_requests`, `match_candidates`, `team_decisions`, `response_deadlines` |
| Plan | `care_plan_items`, `plan_slot_skips`, `visit_plan_changes` |
| Visit | `care_visits`, `visit_events`, `visit_time_corrections`, `visit_status_notes` (incl. at-the-door fact) |
| Documentation | `visit_observations`, `care_notes`, `visit_reports` (versions, snapshot hash), `visit_report_returns`, `handover_shown` |
| Safety and quality | `safety_signals`, `signal_deliveries`, `signal_takes`, `exception_events`, `quality_events`, `quality_holds`, `case_safety_alert_values` |
| Doctor link | `case_gp_notices` (ORD0); order status and validity on the case |
| People and work | `team_memberships`, `member_profiles`, `member_absences`, `absence_releases`, `cover_events`, `member_access_events`, `working_day_versions`, `working_time_facts` |
| Money | `billable_facts`, `tariff_rates`, `billing_rules` |
| Trust | `audit_events`, `audit_read_log`, `change_log` |

### 2.3 What the graph still misses
None of these is approved; each names its gate.

| Missing | Why it matters | Gate |
|---|---|---|
| **Consents per recipient** (who may see what, for which purpose) | every cross-boundary read (cover, hospital, GP, relative) depends on it | D-9 g4 (`owner`) |
| **Structured medical order** (issuer GLN or ZSR, issue and effective date, services) | ends re-typing and chasing (ORD1) | D-22 (`owner`) |
| **Assessment reference** (instrument, version, assessor, link to the licensed tool, minutes) | a needs assessment as a fact, not a document | D-13 B (decided), brief not written |
| **External actors as nodes**: GP practice, hospital discharge unit, relative or contact | most phone coordination is with them | REF2, ORD1, D-9, D-17 (contact) |
| **Outcome events** (candidates only: falls, pressure injuries, unplanned admissions) | quality by outcome, not process | G-5, Clinical Owner |
| **Client voice** (preferences, concerns, visit-window wishes) | the client as an actor, not an object | D-9 |
| **Nurse-linked evidence to instrument items** (NH2′) | assessment as a by-product of care | D-24, licence |
| **AI suggestion ledger** | auditable AI | D-35 (§9) |

### 2.4 What the graph must never become in the core
- It is **not** a clinical inference engine: no derived risk, score, prognosis or need in the core (D-34 exclusion list v2).
- It is **not** a person-performance profile: never per nurse, only per team (AN1, AN2, WORK1).
- It is **not** an identity matcher across cases without an explicit, audited link (RET1).
- It is **not** readable beyond its scopes for "AI training". Any secondary use is only anonymised and aggregated, judged in the DPIA (D-12 condition 4).

---

## 3. Roles

Columns:
1. **Automate:** a deterministic rule or the system does it.
2. **Monitor:** watched continuously instead of reviewed periodically.
3. **Agent:** an AI draft that a named person confirms.
4. **Fragmentation:** does the part exist only because information is scattered?
5. **Care graph:** does it disappear when the graph is current?

The last column gives the D-34 level of the agent part (L / G / H).

| Role (home care · nursing home) | 1 Automate | 2 Monitor | 3 Agent (confirmer) | 4 Fragmentation? | 5 Gone with the care graph? | Stays human | Agent level |
|---|---|---|---|---|---|---|---|
| **Dispatcher / scheduling administrator** | visit series from the plan (PLAN2); release on absence (ABS1); team pull (J2) | uncovered, overdue, stuck visits (SIG1) | day order and route proposal (team) | **yes**: who is free, qualified and near | **yes** (IMPLEMENTED for home care; NH1 for shifts) | the team's choice when two options are equal | L |
| **Intake coordinator** | readiness check (J1); missing-item list back to the referrer (REF2) | referral completeness; deadline | **intake extraction** from discharge letters (receiving nurse) | **yes**: letter, phone and form hold the same facts | **mostly**: a structured referral removes re-typing; extraction only for paper | the receiving nurse's acceptance; consent questions | **H** (extraction of clinical facts); L for administrative fields |
| **Team lead / ward leader** | rosters, release, cover (PLAN2, NH1, COVER1) | team health (AN2 decision rules) | roster proposal (team) | **yes**: the lead is the place where information meets | **yes as a rank** | conflicts, conduct, hiring (team decision, D-20) | L |
| **Coach** | – | signals call the coach (OPS1, AN2) | team-health brief from aggregates (coach) | partly | partly | coaching itself | L (aggregates only) |
| **LTCF coordinator** | due dates (NH3) | evidence completeness per item (NH2′) | none needed if evidence is nurse-linked; a link **suggestion** agent only as a module | **yes**: the observation project exists because evidence is not continuous | **yes as a role** (pending licence acceptance, UNKNOWN) | the primary nurse's assessment and signature | L for dates; **H** for link suggestions |
| **LTCF supervisor** | completeness before signature (structural) | completeness, staleness, contradictions **in presence and dates** | coherence check of content (signing nurse) | **yes**: checks after the fact because evidence was collected apart | **largely** | clinical care planning with the team | L structural; **H** content |
| **LTCF expert / controlling** | evidence pack from the trail (NH6) | full trail, not samples | controlling-answer drafter (expert or licence holder) | **yes**: insurers ask because the evidence is scattered | **largely**; network expert remains | the expert's judgement in a dispute | L (assembles facts) |
| **Quality manager / steering group** | indicators from routine data (AN1, AN2) | decision rules mark crossings; balancing pairs (P-5) | explanation of indicator changes (team) | partly: indicators were compiled by hand | **the compilation yes; the learning no** | the team's improvement choice; the Clinical Owner's rules | L (aggregates); G for MQI computed from clinical items |
| **Billing back office** | facts from signed reports (J5); invoice draft | billing blockers (holds, missing order) | invoice dispute drafter (licence holder) | **yes**: re-collecting what was done | **yes** for preparation | the release of an invoice | L |
| **Data-protection officer** | reads limited by design (RLS2, RLS3); purpose-bound reading (AUD1) | unusual read patterns (exceptional reads only) | access-request extract drafter (DPO) | partly | partly | judgement on a breach; DPIA | L |
| **Operations (NAVORA's own)** | exceptions closed by their cause | untaken signals only (SIG1-5) | exception summary for the person on duty | **yes** for intake; partly for exceptions | **shrinks** to a fallback (P-3) | the fallback decision | L |
| **Discharge planner (hospital side)** | one referral to all eligible teams (REF2, J2) | the answer deadline | – | **yes**: phoning several providers | **yes** (REF2) | the discharge decision | L |
| **GP practice (external)** | prepared renewal (ORD1) | order expiry (OPS1) | renewal request drafter from the care plan (primary nurse sends) | **yes**: fax and phone | **largely** (ORD1, D-22) | the medical order | L ("NAVORA adds nothing clinical", ORD1) |
| **Primary nurse** | – | her own open work (signals, reports) | dictation-to-structured-entry; draft of the report text (she confirms and signs) | no | no: the role grows | assessment, judgement, signature, relationship | G (transcription); **H** (interpretive drafts) |
| **Licence holder / nursing management** | named duties as signals and records | untaken escalations; serious events | compliance evidence pack (licence holder) | partly | the line layer yes; the duty no | accountability | L |

---

## 4. Meetings

| Meeting | 1 Automate | 2 Monitor | 3 Agent | 4 Fragmentation? | 5 Gone with the care graph? | What remains |
|---|---|---|---|---|---|---|
| Daily handover (*Rapport*) | "since your last visit" (HAND1) | – | a **summary** of changes (next nurse). HAND1 deliberately does not summarise | **yes** | **yes** (IMPLEMENTED) | a call when a nurse wants to talk |
| Weekly planning meeting | PLAN2 | uncovered and overload signals | – | **yes** | **yes** | – |
| LTCF focus, planning and closing meetings (QSys pp. 4-5, as recorded in the NH report) | due dates; completeness list | completeness | – | **yes** | **yes**, except the resident's focus conversation | the conversation with the resident |
| Case discussion | the graph prepares the facts in advance | – | a case brief from the record (team) | partly | the fact-gathering part yes | the shared clinical judgement |
| Quality steering group | indicators | decision-rule crossings | indicator explanation | partly | the standing meeting yes | an occasional decision |
| Monthly pilot review | AN2 decision rules | crossings marked | – | partly | **yes** (IMPLEMENTED) | – |
| Team meeting about finances | J7 figures | – | – | **yes** | largely (after D-14) | decisions about the surplus |

---

## 5. Validation activities and controls

| Validation or control | 1 Automate | 2 Monitor | 3 Agent | 4 Fragmentation? | 5 Gone with the care graph? | Superior replacement, after a parallel run (P-1) |
|---|---|---|---|---|---|---|
| Countersignature of care-assistant reports | locks on signature (F7 hash); return path (F6R) | return share and latency (F6R-9) | a pre-check drafting questions for the countersigner (H) | partly | no: the risk is competence, not information | risk-based review (D-10 B, `clinical`) |
| Supervisor coding check | presence of evidence per item | completeness and dates | coherence of content (H) | **yes** | **largely** | structural completeness plus a sampled human check during the parallel run |
| Expert sample audit | full trail | 100 %, continuously | – | **yes** | **yes** | full traceability |
| Billing plausibility (back office) | facts only from final, unheld reports (J5) | blockers | dispute drafter | **yes** | **yes** | rule-derived facts |
| Time-correction approval | trail, original kept (F3) | correction share (AN1) | – | partly | no approver needed (never introduced) | trail |
| Hold lift by coach or admin | hold by rule (QG1) | open holds and their age | – | no | no | named role with reason; review after lift (D-16 B, `clinical`) |
| Data-protection log reading | impossible reads (RLS) | exceptional reads | – | partly | largely | design plus targeted signal |
| Consent check at intake | consent as a coded record (D-9 g1-g4) | expiry, scope | – | **yes**: consent on paper | **yes** once recorded per recipient | coded consent |
| Order validity check | order dates (J3, J5) | expiry (OPS1) | – | **yes** | **yes** with the structured order (D-22) | structured order |
| Qualification check | RN rules in the database (J3) | qualification state (D-29) | – | partly | partly | verified qualification (D-29) |
| **Control health** (are the controls themselves working?) | evaluator liveness (SIG2-11, IMPLEMENTED) | **every** scheduled rule, sender and job | – | – | – | **new:** one control-health view, extending SIG2-11 to PLAN2, COVER1, the billing build and the AI agents |
| **Agent quality** (new) | ledger of every suggestion | correction rate, later errors, drift | – | – | – | **new:** per-agent stop rule (P-6) |

---

## 6. Documentation activities

| Documentation | 1 Automate | 2 Monitor | 3 Agent (confirmer) | 4 Fragmentation? | 5 Gone with the care graph? | Agent level |
|---|---|---|---|---|---|---|
| Re-typing a referral | structured referral (REF2) | completeness | extraction from a letter (receiving nurse) | **yes** | **yes** for digital referrers | **H** |
| Visit times and states | events at the tap (F1-F4) | missing or implausible times | – | no | already gone | – |
| Visit report narrative | report from facts (F6, F7) | free-text share (P-2) | dictation to entry (G); narrative draft from facts and notes (H) | partly: proof of delivery is re-written | the proof-of-delivery part yes (P-2) | G / **H** |
| Handover notes | flag on an observation (`for_handover`) | – | summary across visits (H) | **yes** | the meeting yes; the summary is optional | **H** |
| Stable items documented again (LTCF, QSys p. 4) | "unchanged since" over existing evidence, if the licence allows (UNKNOWN) | staleness per item | – | **yes** | **yes**, if allowed | L |
| Coding the assessment | – | completeness | coding draft (NH4; RN signs) | **yes** | the collection part yes; the determination no | **H** (module) |
| Timesheet | day from events (WORK1) | confirmation gaps | – | **yes** | already gone | – |
| Monthly working-time export | – | – | – | **yes** | **yes**: the employer reads the record (challenge row) | – |
| Invoice and statutory statistics | from facts | – | – | **yes** | **yes** | L |
| Transfer summary to a hospital or nursing home | – | – | transfer draft (sending nurse) | **yes** | **largely**: a consented, scoped view of the same graph replaces the extract (D-9, D-3) | **H** for a draft; L for a scoped view |
| GP information ("Hausärztin informiert") | task from rule (ORD0) | open task | message drafter from recorded facts (primary nurse sends) | **yes** | largely (ORD1) | L if it only states recorded facts |
| Access request (client's own data) | one-command extract (D-4 r1) | – | – | **yes** | **yes** | L |

---

## 7. The agent catalogue: where agents are worth it

Each agent:
- drafts and never decides;
- runs inside the team's access scope (F0, RLS2, RLS3);
- writes every suggestion to the ledger (§8);
- has a named confirmer, a correction-rate measure and a stop rule.

The order follows value and risk: **L first**, because L agents need no clinical approval and no device qualification. They are still subject to D-35 if any client data reaches an AI service.

| # | Agent | Input | Output (draft) | Confirmer | Replaces | Value | Level | Gate |
|---|---|---|---|---|---|---|---|---|
| A1 | Referral completeness | structured referral | list of missing administrative items to the referrer | referrer | intake re-typing and phoning | 5, 1 | L (may be a deterministic rule, no AI) | REF2, D-9 |
| A2 | Order renewal | care plan, order, GP | renewal request (ORD1) | primary nurse | GP chasing | 5, 2 | L | D-22, D-9, D-35 |
| A3 | Roster and day plan | plan, windows, qualifications, labour rules | roster or day order proposal | team | scheduling administrator | 1, 4 | L | NH1, Q7 (location), `legal` (labour rules) |
| A4 | Billing and dispute | J5 facts | invoice draft; answer to an insurer question | licence holder | back office | 9, 5 | L | D-12, D-18 |
| A5 | Compliance evidence | audit trail, decisions, gates | evidence pack for canton, insurer, DPIA | licence holder | manual compliance work | 5, 7 | L | D-4, D-12 |
| A6 | Control health | job runs, deliveries, agent ledgers | "what is not working" list | Operations, admin | nobody does this today | safety | L (rules, no AI needed) | none |
| A7 | Dictation to entry | the nurse's speech | structured entry in her words | the nurse | typing on a phone | 1 | **G** (transcription; adviser to confirm) | D-35, D-34 |
| A8 | Intake extraction | discharge letter | structured referral and safety values | receiving nurse | re-typing | 1, 5 | **H** | D-34 module, Clinical Owner, D-9, D-35 |
| A9 | Report and handover drafter | visit facts, notes | report text or handover summary | performing nurse; next nurse | writing | 1 | **H** | D-34 module, Clinical Owner, D-35 |
| A10 | Care-plan review proposer | observations, events, measured minutes | review proposal | primary nurse | calendar review | 6, 2 | **H** (L if it only shows facts) | D-34 module, Clinical Owner |
| A11 | Evidence link suggester (NH2′) | observations | suggested item links | primary nurse | coordinator's project | 1 | **H** | D-24, licence, D-34 module |
| A12 | Transfer drafter | the graph | transfer draft | sending nurse | transfer letter | 2 | **H** (prefer a scoped view, L) | D-9, D-3, D-34 |

**Agents not to build:**
- **Signal triage:** P1 signals stay deterministic and rule-based (D-28). An AI that re-ranks safety signals is H and less auditable than the rule.
- **Nurse performance scoring:** never per person.
- **Automatic coding or care-plan changes:** a person always confirms, and NAVORA never codes into a billing system by itself (NH report §5).
- **A general "care copilot" across all data:** it breaks the access scopes and the D-34 boundary at once.
- **Unconfirmed record entries** *(added by po 2026-10-26 16:20, D-35 `lca` 15:04 note 4 and condition 6):* no agent output enters the record without a named confirmer who can in fact reject it, with the source of each claim shown. No agent output is a decision.
- **A per-person view of confirmations** *(added by po 2026-10-26 18:10, D-35 `lca` 17:55 term 9):* the per-value confirmer is read per value, or through the AUD1 purpose reader for a stated audit; no reader, report or export aggregates confirmations, edits or rejections per person.
- **Dictation of a conversation** *(added by po 2026-10-26 18:10, D-35 `lca` 17:55 term 10):* A7 records only the nurse's own dictation, outside the client's presence, or with the consent of everyone present. A7 is not the first agent to use real data.

---

## 8. AI governance: the new control layer
PLANNED. Nothing here is built; D-35 decides the basis.

| Control | What it is | Why it is superior |
|---|---|---|
| **Suggestion ledger** | append-only row per suggestion: agent, model and version, input reference (no copy of the payload outside the scope), output, confirmer, edits, time | every AI influence on a record is traceable; today a human's influence is not |
| **Source per claim** | each drafted statement links to the entries it came from; unsupported statements are marked, not hidden | counters automation bias (H-03); follows the NH report rule "never codes without an entry" |
| **Forced attention on uncertainty** | the confirmer must act on each marked item; no "accept all" | confirmation is not a click-through |
| **Provenance per value** *(po 2026-10-26 18:10, `cra` D-35 2(a))* | an agent value is stored as a proposal (agent, version, input reference) and becomes record content only when a named person confirms it; the record shows "vorgeschlagen von … / bestätigt von … am …"; signing a draft is not confirming every value | the record says who stands behind each fact |
| **"Not found" is explicit** *(`cra` 2(b))* | "im Dokument nicht gefunden", never an empty or "keine" value; a safety field cannot be confirmed without the source open beside it | an omission never reads as "none" (H-03, H-20) |
| **No accept-all on safety fields** *(`cra` 2(c); scoped by field class in AIG1-5, see §12)* | fields that feed the safety alerts (D-17), the care plan or a medical order are confirmed one by one; the list is the Clinical Owner's (D-17 part 3) | the fields that hurt when wrong get the attention |
| **Correction rate and later errors** | per agent and field, per team; never per person (`cra` 2(e), `lca` term 9) | the agent earns its scope with evidence (P-1) |
| **Stop rule (P-6)** | an agent stops by itself when its correction rate or later-error count crosses its written threshold, or when its provider, region or model changes without review | no silent drift |
| **Evaluation on synthetic data first** | every agent is tested on synthetic cases before any real data | consistent with "synthetic only" until the gates |
| **Scope inheritance** | an agent reads only what its confirmer may read | no new access path (RLS2, RLS3) |
| **Provider and region** | chosen under D-35; data minimised before leaving the scope (`ARCHITECTURE.md`: minimisation → provider → schema → validation → human review → immutable approved state) | privacy by design |

---

## 9. Decision opened: D-35

**D-35 (package [decisions/D-35.md](../agents/decisions/D-35.md); decided by po 2026-10-26 18:10: option A as the pilot rule).** May NAVORA send client or staff data to an AI service, and on what basis? **Answer for the pilot: no.** B or C (provider, region, contract) is a later `owner` decision through a new package, on `lca` conditions 1-10 and the controls in §8.
- Covers provider and hosting country, processor terms, professional secrecy, consent or legal basis, minimisation, the suggestion ledger, and which agent levels (L, G, H) may run before which gates.
- **Safe default in force:** no client or staff data reaches any AI service; agents run only on synthetic data; L agents that need no AI are built as deterministic rules.
- Inputs: `eng`, `lca`, `cra`.

---

## 10. Explicit answers to the five questions, across the operating model

1. **Which part can be automated?** Everything rule-shaped:
   - planning, release, cover offers, deadlines, escalations;
   - billing facts, working time, completeness checks, consent and order validity;
   - evidence packs, statistics, extracts.

   Most of it is IMPLEMENTED or drafted. The rest waits for decisions (D-9, D-12, D-18, D-22), not for AI.
2. **Which part can be continuously monitored?** Service delivery (IMPLEMENTED), data completeness, staleness of evidence, the controls themselves (extending SIG2-11), agent quality, access, and team health through decision rules (AN2). **Not in the core:** a client's health condition (D-34: "Überwachung", level H).
3. **Which part can be delegated to an intelligent agent?** Drafting at the edges of the graph: referral and order requests, invoices and disputes, compliance packs, rosters (L); dictation (G); extraction, report and handover drafts, review proposals, evidence links, transfer drafts (H, module). Always with a named confirmer.
4. **Which part exists only because information is fragmented?**
   - re-typing, chasing, handover meetings, the observation project, "who documents what";
   - after-the-fact checking and sample audits;
   - transfer letters, monthly exports, compiled reports;
   - most of the intake and dispatch roles.

   On the PO's reading, this is the larger share of coordination and validation work. Its size is **UNKNOWN** and is measured in the pilot (hypothesis P-7).
5. **Which part disappears with a continuously updated care graph?** Everything in 4, once the missing nodes exist: consents, structured orders, assessment references, external actors, outcomes, client voice. **It does not remove:**
   - the nurse's judgement and signature;
   - the team's decisions;
   - the GP's order;
   - the Clinical Owner's rules;
   - the licence holder's accountability;
   - the relationship.

**Bottom line:** the AI-first care operating system is mostly a **graph-first** system. AI is the interface at its edges and the drafting help for people. The superior part is not that an agent does the coordinator's job. The coordinator's job, the meeting and the check stop being necessary, and every remaining control, human or AI, is continuous, complete and evidenced.

---

## 11. Proposals recorded

| # | Proposal | Where |
|---|---|---|
| P-6 | **Agent stop rule and suggestion ledger** before any agent touches real data | challenge row; D-35 |
| P-7 | **Fragmentation share hypothesis:** in the pilot, classify Operations and coordination minutes (AN2 events, Operations exceptions) by cause. If most are explained by a missing graph node (order, consent, external actor), the next brief completes that node before any agent is built | challenge row |
| P-8 | **Control-health view:** one list of every scheduled rule, sender and job that is not running, extending SIG2-11 | challenge row; brief when the first hosted environment exists (D-2) |
| P-9 | **Graph completion before agents:** the next capability briefs are, in order: the consent record (D-9 g4), the structured order (D-22), the D-13 B assessment reference, the external-actor nodes (REF2, ORD1) | `CARE_OPERATING_MODEL.md`; each waits for its decision |

---

## 12. Stage tracking and open control questions (`aia`)

The current state of each entry condition is in the newest section of [`AUTOMATION_REVIEW.md`](../agents/reports/AUTOMATION_REVIEW.md), §3 *Stage tracking*.

**Control question settled (AUT-1, #543; `aia` 2026-10-27 20:30):** how far does "no accept-all" (§8) reach?
- **PLANNED (approved brief, not built):** AIG1-5 as amended by po 2026-10-27 15:20 and 18:10, with `cra` CGR-78. The rule:
  - every proposed field has a class, `schedule` or `record`, and `record` is the default;
  - a bulk confirm is allowed only for `schedule` fields of level-L `rule` agents that are not on the Clinical Owner's list;
  - a bulk confirm is an unticked list with one tap per line, no "select all", and a confirm button that names its count;
  - each line is its own ledger confirmation, and the consuming command re-checks every line;
  - safety-alert, care-plan, order and assessment fields, and any field that sets a visit's date, time, team, minutes or category, can never be `schedule`.
- **First `schedule` field:** PLAN3 `responsible_user_id`.
- **Consequence for inferred values (AUT-7, closed):** an inferred visit time is a `record` value and is confirmed one by one (AIG1-3, AIG1-5; `cra` 17:35). Removing taps by inference therefore saves nothing at equal safety.

**Delivered rule proposers outside the register (`aia`, AUT-9):**
- WORK1 proposes the working day. Per-segment provenance (`from_proposal`) is IMPLEMENTED.
- It has no register entry, no correction-rate read and no stop rule. The PO decides after AIG1 whether to register it or exempt it, with `lca` on D-23 term (b).

**Assessed minutes as agent input (ASM1-1, ASM1-11; `cra` CGR-81, CGR-84; `aia` 2026-10-28 02:20):**
- **PLANNED (approved brief, not built):** ASM1 records assessed minutes per KLV category with the period they refer to, as entered or from the organisation's own list; no period list is hard-coded.
- **Control for A10 (care-plan review proposer) and any later agent reading these values:** no sum, difference or per-period conversion of assessed minutes against care-plan items, and no mark derived from them, until a brief with `cra` review allows it. Care-plan `planned_minutes` are per occurrence and `frequency` is free text, so any computed comparison today would show a false gap (H-24).
- **Import instead of transcription (AUT-13, low):** a later deterministic import of the header values (date, instrument, assessor, minutes, period; no item, score or CAP, D-36 A) from the provider's assessment tool into an ASM1 draft, confirmed value by value (assessment fields are never `schedule`). OPEN: the tool's export format and the licence and processor questions (`lca`, D-36).
- **`cra` conditions for that import (05:30, PR #582; `aia` 2026-10-28 08:20):** (1) an imported draft is no assessment record until confirmed value by value: it neither satisfies a reassessment due date nor feeds A10; (2) the period is imported as the tool states it, never mapped or converted (CGR-84); (3) the record keeps per value whether it was imported or typed (H-22). Condition (3) is the provenance-per-value control of §8.

**Derived readiness views are rules, not agents (AUT-14, AUT-15; `aia` 2026-10-28 14:41):**
- **OPEN (proposal, not briefed):** a provider transition's safety kinds (D-38 T15 (b)) shown as a read of the record (open signals without a taker, P1 reach, order validity, qualification), and kit entries that are record facts filled as a draft confirmed entry by entry.
- **Control:** such a view never sets or shows a level, threshold or pass mark (Clinical Owner, G-1); a kind without data is shown as manual, never as met; it proposes nothing and needs no ledger entry. Any AI drafting of kit text waits for a D-35 stage that allows it and `lca`.

**Early visits after VIS1 (AUT-16; `cra` CGR-87; `aia` 2026-10-28 20:19):**
- **PLANNED (VIS1 approved, not built):** field actions refuse a visit dated after today (Europe/Zurich).
- **Control for PLAN3, the day-order agent (AUT-5) and any shortcut:** a proposal to do a visit earlier is a proposed `reschedule_visit` (its date is a `record`-class field, confirmed one by one, AIG1-5), never a start; nothing starts a visit dated after today, and a one-confirmation move on `/field` (AUT-16, OPEN) calls the same audited command with its existing checks.
- **Added 2026-10-28 22:00 (`cra` CGR-89, `aia` review 7):** every proposed or one-confirmation earlier move shows, as a fact read from the plan, whether another visit for the client is planned on the date the visit leaves; no level, no "replacement needed" rule (Clinical Owner, UNKNOWN). The move reason stays typed by the confirmer; no agent drafts or prefills it (`cra` 21:30).
- **Updated 2026-10-29 02:45 (`aia` review 8):** VIS1-1 to VIS1-7, VIS1-3a and VIS1-3b are IMPLEMENTED (#624, merged `5d85b8f`); VIS1-3c to VIS1-3g, VIS1-8 to VIS1-10 PLANNED (#633 open; VIS1-10 placed in PO PR #640, open).
- **Control added (VIS1-10, PO challenge 02:15; AUT-18):** a command that means "now" (a move to today, a start, a proposal "do it today") takes its day from the database (`private.now()`, Europe/Zurich), never from a device or a rendered page. A value the database stores must be the value the confirmer saw: when the day changed between showing and confirming, the command refuses and the confirmer is shown the new value to confirm again; it is never silently replaced. This holds for every agent proposal as well (a proposal rendered yesterday is not confirmed today without being re-shown).
- **Taking a released visit (AUT-19, OPEN):** when a move releases a visit (ABS1-C4), the take-over is the existing `take_open_visit` with its existing checks (qualification `may_perform_visit`, absence, first wins, `taken` row); no agent and no shortcut assigns responsibility without that command and the person's own tap.

## Change log

| Date (Europe/Zurich) | Who | Change |
|---|---|---|
| 2026-10-27 14:48 | `aia` | First `aia` maintenance. Added §12: the stage-tracking pointer, the open "no accept-all" scope question (AUT-1, #543) and WORK1 as a rule proposer outside the register (AUT-9). Sections 1-11 unchanged |
| 2026-10-27 20:30 | `aia` | §12: the AUT-1 control question is marked settled. It records the AIG1-5 field-class rule as amended, with CGR-78, and its consequence for inferred values (AUT-7). §8: one pointer to §12 in the *No accept-all* row. No agent added or removed |
| 2026-10-28 02:20 | `aia` | §12: added the control on assessed minutes as agent input (no computed comparison before a `cra`-reviewed brief, CGR-81) and the import-instead-of-transcription note (AUT-13). No agent added or removed |
| 2026-10-28 08:20 | `aia` | §12: added `cra`'s three conditions for an assessment-header import (AUT-13). No agent added or removed |
| 2026-10-28 14:41 | `aia` | §12: added the control for derived readiness views (AUT-14, AUT-15): rules, no level or pass mark, no unmet kind shown as met. No agent added or removed |
| 2026-10-28 20:19 | `aia` | §12: added the control for early visits after VIS1 (AUT-16): a proposal to do a visit earlier is a confirmed move, never a start. No agent added or removed |
| 2026-10-28 22:00 | `aia` | §12: early-visit control extended with the CGR-89 fact line for every proposed move and a typed, never drafted reason. No agent added or removed |
| 2026-10-29 02:45 | `aia` | §12: VIS1 state updated; added the "now is the database's day, the stored value is the shown value" control (VIS1-10, AUT-18) and the take-over of a released visit through `take_open_visit` only (AUT-19). No agent added or removed |
