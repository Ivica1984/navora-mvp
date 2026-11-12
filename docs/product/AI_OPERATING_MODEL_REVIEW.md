# NAVORA AI Operating Model Review

**Maintained by:** AI & Automation Architect (`aia`) from 2026-10-27 (owner). The staged AI path approved by the owner on 2026-10-27 is in [`STRATEGIC_ALIGNMENT_REVIEW.md`](STRATEGIC_ALIGNMENT_REVIEW.md) §3; findings go to [`../agents/reports/AUTOMATION_REVIEW.md`](../agents/reports/AUTOMATION_REVIEW.md).

**Author:** Product Owner (`po`) · **Date:** 2026-10-26 (Europe/Zurich) · **Requested by:** the owner ("Follow-up Review", after the [Transformation Alignment Report](TRANSFORMATION_ALIGNMENT_REPORT.md)) · **Status:** strategic review. It approves no build. It opens one decision (D-35, §9). **Repository state read:** `recovery/main` after #458.

**Question:** what does a care operating system look like when it is designed AI-first? The aim is not a better LTCF or interRAI workflow, but a superior operating system for self-organised care.

**Status labels:** IMPLEMENTED (exists, synthetic data only) · PLANNED · OPEN (needs a decision) · UNKNOWN.

**Superseded doctrine (`aia` 2026-11-03 14:40):** the design order of this review ("graph-first, agents at the edges", §1, §7) is replaced by the owner's AI-first method and its mandatory human-in-the-loop sequence in [`AI_FIRST_ARCHITECTURE_UPDATE.md`](AI_FIRST_ARCHITECTURE_UPDATE.md) §0 and §3 (PO #822, owner directives 2026-11-03). The controls in §8 and §12 remain in force and apply to every agent of the update's ten domains.

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
| A6 | Control health | job runs, deliveries, agent ledgers | "what is not working" list | Operations, admin | nobody does this today | safety | L (rules, no AI needed) | none (first PLANNED instance: J5-S catch-up and team count, B8; `aia` 2026-11-11 20:20, AUT-92) |
| A7 | Dictation to entry | the nurse's speech | structured entry in her words | the nurse | typing on a phone | 1 | **G** (transcription; adviser to confirm) | D-35, D-34 |
| A8 | Intake extraction | discharge letter | structured referral and safety values | receiving nurse | re-typing | 1, 5 | **H** | D-34 module, Clinical Owner, D-9, D-35 |
| A9 | Report and handover drafter | visit facts, notes | report text or handover summary | performing nurse; next nurse | writing | 1 | **H** | D-34 module, Clinical Owner, D-35 |
| A10 | Care-plan review proposer | observations, events, measured minutes | review proposal | primary nurse | calendar review | 6, 2 | **H** (L if it only shows facts) | D-34 module, Clinical Owner |
| A11 | Evidence link suggester (NH2′) | observations | suggested item links | primary nurse | coordinator's project | 1 | **H** | D-24, licence, D-34 module |
| A12 | Transfer drafter | the graph | transfer draft | sending nurse | transfer letter | 2 | **H** (prefer a scoped view, L) | D-9, D-3, D-34 |
| A13 | Demand pooling matcher (POOL1, PLANNED; added 2026-11-11 by `aia`, AUT-84) | team idle intervals from existing facts (plan, ABS1), QUAL1 state in context NH-EXT, released demand | matches shown to the named member, fixed published order | the named member, within the team's pooling mandate (AUT-83) | phone and agency chains for short-term cover | 1, 4 | L (a deterministic rule, kind `rule`, stage 0) | `po`, `cra` CGR-173, `lca` L-7 before real use |

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
- **Updated 2026-10-29 08:25 (`aia` review 9):** VIS1-3c to VIS1-3g, VIS1-8, VIS1-9 IMPLEMENTED (#633, merged `35b5a96`); VIS1-10 IMPLEMENTED (#655, merged `dcd5ffa`, ADR-116), the first built case of the "stored value is the shown value" control (`day_changed`, confirmation offered again); `cra` VIS1-7 gate on #655 pending. VIS1-11 (AUT-19) PLANNED as UX2-17.

**Ownerless visits and owner proposals (AUT-20, OPEN; `aia` 2026-10-29 08:25):**
- **IMPLEMENTED:** `visit_uncovered` (0044, CR-049; P2, 24 h, PROVISIONAL until D-28) is a deterministic monitor of an ownerless planned visit; at P2 it is shown on OPS1 only, and SIG1 delivers it to the owning team only at P1.
- **Design order for P-30:** the existing monitor delivered to the team (its priority and window are D-28: `cra`, Clinical Owner) comes before any agent that proposes a named owner.
- **Control for a PLAN3 (or later) owner proposal:** the candidate order is a fixed rule shown with its reason (primary nurse, deputy, knows the client, free capacity); the proposal is confirmed only by the named person's own tap through `take_open_visit`; a person who does not take it leaves no record about her (no per-person decline count, no per-person view of confirmations); correction rate per agent and field at team level only; nothing assigns responsibility by itself.
- **Control for every proposal, signal or item that asks for an action (PO general rule 2026-10-29 08:15, ADM2-15 (c)):** it links to the place where the action is done, and any identifier it shows is visible on that place.

**Authorship and provenance of clinical entries (OBS1; `aia` 2026-10-29 14:55):**
- **PLANNED (OBS1 approved by the PO 14:35, PR #670 open, not built):** every observation shows its author and, where set, a marker fixed at write time that the author had no recorded qualification in the visit's team; handover and new report snapshots carry both; signed snapshots unchanged; per entry only (RLS3-4).
- **Control for any later documentation draft (A-catalogue drafts, D-35 stage 1 or later):** the author shown is always the confirming person; the draft origin (agent and version) is a separate per-entry fact on the same line, never in place of the author; an agent is never shown as an author; origin is never shown as a list, count or filter per person. This is the §8 "provenance per value" control applied to clinical entries.

**Confirmer read per value only (AUT-22, OPEN; `aia` 2026-10-29 20:20; #686):** the per-value confirmer and outcome (§8 "provenance per value", AIG1-2, AIG1-3) are not selectable through the table API; they are read per value on the record line ("vorgeschlagen von / bestätigt von") and through the AUD1 purpose reader only (D-35 `lca` term 9; the RLS3-4 pattern of 0070 and OBS1-7). The correction rate (AIG1-7) remains the only aggregate and has no person key. This is the table-level form of "no per-person view of confirmations" (§7, *agents not to build*).

**Authorship state (OBS1; `aia` 2026-10-29 20:20):** IMPLEMENTED (#673, 0095, ADR-118, accepted with OBS1-C1 and OBS1-C2 by the PO 19:40): author and marker per observation in the handover and in new report snapshots; OBS1-C1 (per-visit read paths only) PLANNED.

**Stage 1 precondition added (`aia` 2026-10-29 20:20):** the owner precaution of 2026-10-29 (no real client data for tests or pilot runs until D-1 is clarified) applies to every agent path in addition to the D-35 entry conditions.

**Confirmer read per value only, state (`aia` 2026-10-29 23:15):** adopted by the PO as AIG1-11 (21:15, with the AUD1 reader as the per-record `read_audit_record`); PLANNED with AIG1 (claimed by `eng` 23:07).

**Stop with a recovery path (AIG1-12, PO 22:10 from `cra` CGR-95; PLANNED):** a stopped agent's OPS1 exception links to the records holding a value from it confirmed unchanged in the stop window (or since the last switch-on after a version, provider or region change); no person column or filter, existing record readers and Operations only. **Control added (AUT-23, OPEN):** re-confirmation from that list is always value by value, whatever the field class (no bulk confirm of a stopped agent's values); a value the record no longer holds leaves the list as "überholt" by rule, unless the Clinical Owner names fields where a superseded value still needs a clinical re-check (UNKNOWN, D-17 part 3).

**AIG1 part (a) delivered (`aia` 2026-10-30 02:18; #701, 0097, ADR-120):** IMPLEMENTED at database level: append-only ledger (every role), provenance per value, confirmer per value or per record only (no table grant at all; AUT-22 closed), field classes and bulk rules (bulk only while `on`, never for a decided or look-back value; AUT-23 (a)), correction share per agent, field, team and month with the rule of three per cell, stop rule with OPS1 `agent_stopped` (evaluated at the next proposal, bulk confirm or health read), fixture harness with a synthetic test agent, look-back with superseded values labelled "überholt" and out of the open count (not removed; AUT-23 (b) in the PO's form). Screens and e2e (part (b)) PLANNED. The only registered agent is the synthetic test agent.
- **Control added: a confirmation never stands for a check that did not run** (AIG1-15, `cra` CGR-98, PLANNED): a re-confirmation from the look-back list runs the open-visit, qualification, contract and absence checks of a first confirmation; on refusal no confirmation row is written.
- **Control added: monitor the monitor** (AIG1-16, `cra` CGR-100, PLANNED): a threshold that cannot fire is refused; the health list shows the written threshold and whether the last window reached its minimum count.
- **`not_found` is no stop criterion at stage 0** (ADR-120 (4), accepted): each agent's brief states whether its "no proposal" share is one, and its share is measured per team as the agent's usefulness (AUT-25, OPEN for PLAN3).

**Team switch under the organisation's switch (PLAN3-10, PLANNED; `aia` 2026-10-30 02:18):** the organisation's AIG1 switch is for accountability (threshold, stop); whether a team uses an assistant for its own work is the team's switch, default off, audited with the actor per record only (no per-person list of switches). A team switch can only narrow use. This is the default pattern for every later assistant that supports a team's own planning or coordination.

**AIG1 part (b) database half and a stop that can end (`aia` 2026-10-30 20:18):** IMPLEMENTED (#770, 0103, ADR-128): AIG1-15 (a re-confirmation on an open visit runs the first confirmation's checks; refusal writes nothing) and AIG1-16 (a threshold that cannot fire is refused; the health read returns threshold and minimum reached). PLANNED: AIG1-C1 (no re-confirmation recorded on a visit no longer open). **Control added (AUT-29, high, #774, OPEN):** a monitor's open count holds only what someone can still act on. A look-back line that no action can clear (a past visit) stays listed, labelled as a visit fact ("Besuch nicht mehr offen"), and is counted apart; a stop exception must be able to reach "0 offen" while the agent stays stopped, so that restarting a stopped agent is never the way to silence it. Re-check duty for past values: Clinical Owner (D-17, UNKNOWN).

**A stop's follow-up ends with its work, not with the agent's state (`aia` 2026-10-31 02:40):** IMPLEMENTED (#787, 0104, ADR-130): AIG1-C1/-C2/-C3; a past-visit look-back line is labelled "Einsatz nicht mehr offen" and counted apart (AUT-29 closed), and a team member re-confirms or changes an open-visit line one by one on the record page. **Control added (AUT-30, high, #793, OPEN):** a stop's exception and its link to the look-back list live as long as the stop has open lines, whatever the agent's state (switching a stopped agent off or on never removes the path to open lines), and close by themselves at "0 offen"; the agent's state is a status, never a to-do. **Expired proposals (AIG1-C4, PLANNED, PO 02:25):** an undecided proposal of a visit no longer open leaves the team's list without anyone's act and is never a correction; its share and lead time are a usefulness measure per team, never a stop criterion or a fault shown to the team (AUT-31, low).

**Administrator steps after a team decision (AUT-21, OPEN; `aia` 2026-10-29 14:55):** where a team decision is followed by an employer act (ADM2 "Vertrag erfasst", the qualification under D-29), all acts of that sitting are offered on one card, each still the administrator's own explicit choice (no preselected value, no accept-all), and a state that blocks the team (a member who cannot perform) stays visible where it is resolved.

**Care-plan review after a reassessment (AUT-26, OPEN, #732; `aia` 2026-10-30 08:25):** ASM1 (#727, in review) marks a care plan resting on an older assessment. **Control:** the marker is cleared by one confirmed review act per plan (actor per record only), never by retyping unchanged items; who may confirm is `cra`/Clinical Owner (UNKNOWN). A later care-plan review proposer (A10) ends in that act, its proposed item changes confirmed value by value (care-plan fields are never `schedule`, §8); no due date, reminder or signal until the Clinical Owner sets an interval.

**Care-plan review after a reassessment, state (`aia` 2026-10-30 15:04):** the AUT-26 control is built as ASM1-C4 on PR #747 (migration 0101, ADR-125; open, CI green on head `fcb84eb` as GitHub reports, `cra` 13:30 clear to merge): one act per plan, append-only, actor not selectable, no `care_plan_items` row changed (pgTAP 101 hash), one confirming step (ASM1-C4 (d), P-36 measures whether it stays). IMPLEMENTED once merged. **Basis by identity (ASM1-C6 (8), `cra` CGR-104, PLANNED):** the plan's basis is compared with the current record by which record it is, not by date; any later agent reading "which assessment is this plan based on" reads the same identity, never a date match.

**A void states its cause, not a story (ASM1-C6 (4), P-37, PROPOSED; `aia` 2026-10-30 15:04):** where a correction act needs a reason, the expected common cause is one tap ("Falsche Klientin oder falscher Klient gewählt") and free text only for "Anderer Grund"; nothing preselected. Less typing and less third-party detail in free text. Pattern for later correction acts, including the rejection of an agent's draft (§8 correction rate per field counts the preset reasons, never per person).

**Acts per record only, state (`aia` 2026-10-30 08:25):** IMPLEMENTED for the care records (RLS4, #715, 0099, ADR-122; G-18 met). The SIG1 "übernommen von <Name>" reader stays per signal (AUT-24 closed, pgTAP 099). Any later per-value confirmer display follows the same pattern.

**One decision per name in data reconciliation (AUT-27, medium, OPEN):** where a person must map legacy free text to members (RLS4-C1, G-25), the person decides once per name and team, exceptions per visit; never automatic name matching; count before and after.

**One decision per name, state (`aia` 2026-11-03 02:40):** IMPLEMENTED (#792, `OWNER_RUNBOOK.md` §5c, pgTAP 105): grouped by team and legacy name, a person decides once per name and team, exceptions per visit, no matching rule; AUT-27 closed. **AUT-30 state:** adopted as AIG1-C5 (PO 2026-10-31 02:55), PLANNED with AIG1-C4.

**Measure before automating (AUT-32, OPEN; `aia` 2026-11-03 02:40):** a bottleneck proposed for elimination or automation has a team-level baseline from timestamps NAVORA already stores before the change reaches the pilot (P-19: report draft → signed, countersign latency, travel share beside WORK1-6, ORD0 task age, request → case ready), per team and month with AN1 suppression, no new tap, never per person. Without it no agent or rule can show its gain, and the governance work an assistant creates (look-back, expiry, confirmations) cannot be weighed against the work it removes.

**Measure acts, not only spans (AUT-33, OPEN; `aia` 2026-11-03 08:20):** AN3 (P-19, draft, PO 2026-11-03 06:30) answers AUT-32 with per-step spans. An elimination removes acts (a countersignature, an order task, a hand-set responsible member, a changed proposal), so the baseline also counts recorded acts per 100 completed visits per team and month, from rows NAVORA already writes; one definition per measure (AUT-34: the countersign span is `countersign_latency_hours`, F6R-9). Minutes per act stay UNKNOWN until observed.

**Human acts per proposal do not rise (AUT-38, OPEN; `aia` 2026-11-03 14:40):** under the mandatory sequence (update §3), review and decision are one act by the named confirmer with sources and "nicht gefunden" in view, unless a law or the Clinical Owner requires a second person; a signature is named only where one exists or is legally required. Each brief states the human acts per proposal before and after; the count is measured per team (AUT-33), never per person.

**Contract before switch-on, harness before provider (AUT-37, OPEN; `aia` 2026-11-03 14:40):** every agent in the AIG1 register carries its contract (update §5.1) before it can be switched on, and each agent version runs its synthetic evaluation set in CI against its written stop threshold. The model-call pipeline, minimisation step and provider adapter are designed with the D-35 stage-1 package, not before.

**Rank by recoverable time (AUT-36, OPEN; `aia` 2026-11-03 14:40):** the opportunity ranking shows the bottleneck-map rank beside the value order; the largest estimated bottleneck (travel and day order) has a stage-0 candidate on synthetic geography (AUT-5), pending the owner's allowed list and Q7.

**Stage-0 state (2026-11-03 14:40):** AIG1-C4/-C5 built on #814 (open; AUT-30 met on head); AN3 approved; allowed on synthetic data: PLAN3, AN3, AIO1, OPS2, HAND2 (owner 14:00); D-39, D-40 frozen.

**An answer goes where the question arises; a read is not a proposal (AUT-40, OPEN; `aia` 2026-11-03 20:30):** an assistant screen is added only for an intent no existing screen can answer (at stage 0 none: the four M6 intents of domain 10 read only `field_visits`, `field_since_last`, `team_open_visits` and `field_reports`, which C-01, the visit card and the absence flow already show). The AIG1 ledger records proposals with a target field and a confirmer, never reads, so the correction rate per agent and field stays the stop rule. Domain 10 (A-catalogue row "AI Nurse Assistant", update §5) returns as an entry point with the first language intent (A7 dictation, A9 drafting; D-35 stage 2, D-34 module).

**Stage-0 state (2026-11-03 20:30):** Delivery Program M1-M10 merged (PLAN3, AN3 in M4 2026-12-18; AIO1, OPS2, HAND2 in M8 2027-02-19; PO targets); AN3 built on #841 (AUT-34 met, AUT-33 open); AIR1 guards for the prohibitions on #828; AIG1-C4/-C5 on #814; all open, none merged.

**AUT-40 decided (PO 2026-11-03 22:00):** no assistant screen at stage 0; reads never enter the ledger (M6 pgTAP criterion). The control above is adopted; status PLANNED until M6 is built.

**A time recorded without a connection enters billing only through the audited correction path, without an extra act (AUT-41, OPEN; `aia` 2026-11-04 02:20):** a timeline tap made offline is queued as a reasoned F3 correction with the device time as the claimed time and a preset reason set by the command kind, so the nurse does not re-type times from memory after reconnecting; the server time stays the server time (`cra` CGR-122 (2), (3)). Whether the device time is the documented time: Clinical Owner with `lca`, UNKNOWN. No AI involved.

**AUT-41 state (PO 2026-11-04 06:10):** adopted as the target design (`DELIVERY_PROGRAM.md` §0c (3), ADR-143 1b), gated on the Clinical Owner with `lca` (which time is the documented time of an offline visit) and `cra` (offline corrections told apart by reason kind); until then CGR-122 (1): timeline commands are never queued. The offline share per team and month is measured first (pilot hypothesis).

**Nothing that raises a safety signal waits in a queue; no act with one possible outcome (CGR-123, AUT-42, AUT-43; `aia` 2026-11-04 08:18):** no-show, broken-off visit and absence are never queued (PO §0c (2)); the escalation is a phone call now, and membership of the never-queued list is derived from the migrations by a failing test, not reviewed by hand (ADR-143 1d). An entry refused only for a device clock ahead of the server is resent once automatically without the device time, with "Gerätezeit verworfen" recorded and shown (AUT-42, OPEN, `cra` and `eng` to confirm); a mandatory tap with a single outcome is not a control. The double report of an offline no-show (call, then the entry) is measured from stored spans before any design (AUT-43, low).

**A relative's view is rule-based and costs the team one act (D-40, FAM1; AUT-44, AUT-45; `aia` 2026-11-04 14:20):** the owner excluded AI from the relative path; no agent, suggestion row or AIG1 path may reference the relative principal (FAM1-12, AIR1 pattern). Recording a relative's consent is proposed as the same act that invites her (AUT-44, OPEN), and the pilot gain is measured without a running count of calls by nurses (AUT-45, OPEN). D-39 decided A: no sensor or prediction agent at any stage of the pilot.

**No derived consent, no periodic re-confirmation (CGR-130, AUT-46, AUT-47; `aia` 2026-11-04 20:20):** a relative consent's capacity fact is an explicit act of the recording RN; no AIG1 path writes the consent record, and no function reads assessment, diagnosis or AI output to set, pre-fill, check or revoke it (CGR-130 (2), AIR1 pattern). A consent question with one possible answer is stated, not asked (AUT-46, OPEN). A later capacity re-check, if the Clinical Owner sets one, appears as an exception line on events already recorded, never as a calendar re-confirmation of every consent (AUT-47, OPEN).

**Stage-1 checklist (D-34, `lca` 2026-11-04 05:20; PO 06:10):** the eleven minimum AI-provider terms and the stage-1 contents list are the checklist for D-35 stage 1 when the owner opens it; domain 10 "no open clinical Q&A" is a tested technical limit. Stage 1 not opened; D-39 and D-40 escalated with recommendation A.

**First agent beyond the test agent built at database level (PLAN3 part (a), #872, not merged; `aia` 2026-11-05 14:20):** the day-plan rule agent carries every stage-0 control of §8 in the database (ledger, provenance, named confirmer without a per-person view, ticked-list bulk only for `schedule`, explicit `not_found`, stop, synthetic fixture, team switch, no record write). Added control: **a fresh request replaces stale lines without manual clean-up** (AUT-51, OPEN): when the situation changes (absence, sick call), a new proposal for the same team and day closes the earlier undecided lines with a recorded outcome instead of refusing until each is decided by hand; one list per visit stays (H-20) and every line is still re-checked at confirm.

**Mandated rule lines (PLAN4, Blueprint SV-7, FE-028; `aia` 2026-11-06 14:40, review 34):**
- **PLANNED (no brief; draft due 2026-12-04):** routine assignment applied by a team-set deterministic rule under an explicit, revocable team mandate. Not an AI agent; no AI service.
- **Controls the brief must carry:** (1) the mandate is a recorded team act with the members who set it, revocable by any member; (2) only `schedule`-class fields (AIG1-5) can be applied, never a `record` field, a date, time, minutes or category; (3) every applied line is a ledger row with its own outcome and the rule version; (4) undo by any member in one act, counted with the other planning acts (M-11); (5) the PLAN3-2 limits and any unclear qualification, conflict or overlap leave the line as a proposal for a person; (6) the stop rule applies: an undo rate per team over the team's own threshold returns the mandate to proposals; (7) no per-person view of applied or undone lines. Gates: `cra`, `lca` (automated decision affecting staff).

**Documentation drafts (DOC-AI, Blueprint §1, FE-028; AUT-54, high; `aia` 2026-11-06 14:40):**
- **IMPLEMENTED:** the structured report is a deterministic server snapshot of the recorded facts (F6, F7, F6R, OBS1). It is a rule, needs no agent and no review step.
- **Proposed scope (OPEN, `po`):** an agent only at the edge, turning the nurse's own unstructured note into proposed observations with their source span, confirmed value by value (A7 limits apply); a narrative report or handover text stays A9 in the separate clinical module (D-34 C). Level of DOC-AI: the Blueprint says G, §7 says A9 is H: UNKNOWN until `cra`.

**Administration measures (Blueprint §10.2 M-11, M-15; AUT-55, AUT-56; `aia` 2026-11-06 14:40):** M-15 is computed from recorded administrative segments and acts, never as paid minus care time (that holds travel, meetings and training); in a ward no time tap per resident is introduced for measurement. M-11 counts undo and override of mandated lines.

**State 2026-11-06 20:20 (`aia` review 35):**
- **IMPLEMENTED on `recovery/main`:** the stage-0 governance layer of §8 for the register: AIG1 with C1 to C5 (#814, 0105: expired proposals counted apart from decisions, a stop followed up by its open lines whatever the agent's state) and AIR1 (#828, 0107: no register field on a billing or safety-signal target, refused in code). Only the synthetic test agent is registered on the main line; PLAN3 is on the unmerged stack. The D-35 stage-1 entry condition "governance layer merged" is met; provider, contract and pilot months are not.
- **DOC-AI (AUT-54 adopted by the PO 15:00; `cra` 17:30):** level G; H as soon as a proposal interprets. Controls the brief must carry: a validator "a proposal restates a span; it never adds a finding"; the note stays in the record beside the confirmed observations; unproposed spans marked inline in the same confirm list, no extra "read" act (AUT-60, OPEN).
- **Billing pre-send checks (BILL1, AUT-59, OPEN):** a check that can be stated as a rule raises a QG1 hold (stage 0); an AI check, if D-41 allows it, reads only free text and shows a remark beside the hold list; it can never raise a hold or propose a billing value (AIR1). Which checks exist: UNKNOWN (`cra`, Clinical Owner, `lca`).

**State 2026-11-07 02:20 (`aia` review 36):**
- **IMPLEMENTED on `recovery/main`:** PLAN3, the day-plan rule agent (level L), with its stage-0 controls (#934, `48cdb0c`, accepted 2026-11-07 01:39): the first registered agent beyond the synthetic test agent. D-35 stage-1 entry conditions now met: governance layer, first rule agent with controls; missing: provider and contract (D-41, escalated), pilot months (Phase B).
- **Qualification boundary (QUAL1, #939 not merged):** the AIR1 prohibited targets gain the class `qualification` (evidence, delegations, matrix): no agent proposes an evidence state, a delegation or a matrix value. A member's own confirmation writes `self_confirmed`, which never counts for E or D. Control added: **an agent never drafts into a prohibited table; a qualification profile draft, if one is built, lands in a separate `record`-class draft field, from unstructured input only, on synthetic data only** (AUT-64, OPEN).
- **Care-graph rule for QUAL1 activities (AUT-61, OPEN, `cra`):** the activity list of a visit is inherited from its case, order line or series, never entered per generated visit; a change re-runs the check on future planned visits.
- **QUAL1 on `recovery/main` (`4878ace`, `f1bfe55`):** the prohibited class `qualification` is IMPLEMENTED; PLAN3 proposes no member who fails the QUAL1 check and re-checks at confirm (rule before agent). The care-graph rule above is adopted as QUAL1-20 (PLANNED). Controls added: **a lapse foreseeable from recorded end dates is shown at planning, never first at the start** (AUT-67, OPEN); **a refusal at confirm caused by a lapse after the proposal is counted apart from the agent's correction rate, per team only** (AUT-68, OPEN).
- **Expiry forecast before release (AUT-63, OPEN):** expiring evidence and delegations are shown as a self-closing fact on the affected planned visits and limit the day-plan proposal, so the release at the instant of expiry stays the backstop, not the normal path.
- **M-DOK (FE-040 GM-2 add-on, AUT-65, OPEN):** within the DOC-AI scope (AUT-54); any recording of a conversation needs a recorded consent of everyone present before it starts; no real audio or text to any AI service before D-41.

**State 2026-11-07 14:20 (`aia` review 38):**
- **Ward planning (NH-A1, approved 13:39, PLANNED, synthetic only):** no agent. The continuity default ("wie letzte <Schicht>") is a deterministic rule on schedule facts, outside the AIG1 ledger; if it is ever registered as an agent it needs the full §8 set. Control added: **a rule default on schedule facts takes effect with a logged source and stays changeable in one act; it is not wrapped in a team-wide accept-all confirm, and an "uncovered" list counts only what is left empty after the default** (AUT-69, OPEN, #969; whether a clinical acknowledgement is needed: UNKNOWN, `cra`). Own recurring shift patterns as a series with exceptions (AUT-70, OPEN). Ward measures come from the responsibility and roster events, never from a time tap per resident (AUT-71, AUT-55 rule).
- **QUAL1:** AUT-67 adopted as QUAL1-22 (PLANNED); AUT-68 adopted as the QUAL1-15 refusal record shape (PLANNED).

**State 2026-11-10 02:20 (`aia` review 39; FE-051, FE-052):**
- **Model path per FE-051 (proposal to the D-41 package, OPEN, `po`):** patterns 1 to 3 run as rules, solvers and SQL aggregates inside NAVORA's database and need no AI service (stage 0, kind `rule`); a language model exists only under pattern 4, in NAVORA's own Swiss hosting (option C's hosting with option B's governance: orchestrator only route, minimisation allow-list, model version in the ledger, evaluation harness with the Clinical Owner's bar, stop rule and kill switch reaching the model server, kind-`ai` refusal lifted per approved agent). An external model provider is at most a synthetic-only stand-in (`lca` O-4 (i)-(iv)). Order inside pattern 4: unstructured referral intake (L) before A7 (G) (AUT-73).
- **Field allow-list for every agent, rule agents included:** the `cra` list of admitted planning facts (17:29) is a register field per agent with a test that refuses any other field (AIR1-C1, CGR-115); facts that are health data (KLV category, activity name, condition-naming signal kinds, ward plus *zuständig*) stay inside the database and never reach a model.
- **Documentation step of Phase A (E-3, AUT-72, OPEN, owner):** report by rule (pattern 3) plus A7 at the edge, behind the pattern 4 interface; no model re-drafts the structured report (AUT-54).
- **Phase A measures administration, not only stops (AUT-74, OPEN, `po`):** acts per flow step from existing events, team level only.
- **FE-052:** nothing is block-accepted; every IMPLEMENTED control above is "gemergt" with CI on its PR, not "abgenommen".

**State 2026-11-10 08:30 (`aia` review 40):**
- **Model path (D-41, PO 04:39):** the default now reads "C's hosting with B's governance for real data; an external provider only as a synthetic-only stand-in" (AUT-73 closed). The next-stage entry condition is a model server inside the D-2 hosting, not a provider contract.
- **Documentation step (E-3, PO recommendation 04:39, owner decides):** report by rule plus A7 at the edge behind the pattern 4 interface (AUT-72 closed on the recommendation).
- **Control added: a due date the record already holds is shown before it passes, never only as overdue** (AUT-76, OPEN): today an order end is shown 7 days ahead, a care-plan review date only after it passed. The lead value is a clinical rule (`cra`), UNKNOWN. The same control applies to evidence and delegation end dates (AUT-67, QUAL1-22) and must be part of the block test, not only the start backstop (AUT-77, OPEN).
- **Control added: a lapse recorded after assignment releases the dependent visits at once, and the person whose act causes the release sees the count before saving** (2026-11-10 14:30; AUT-77 closed: QUAL1-22 (1) is IMPLEMENTED as a refusal at every assignment path (CGR-164), QUAL1-22 (2) is PLANNED as B2-T12b with (b2), (b3)). The preview is one function with the release, shows a team-level count only and adds no step when nothing is released (AUT-78, OPEN); a released visit must reach the team's normal open list and PLAN3 request, not a migration listing (AUT-79, OPEN).
- No agent added or removed.
- **Control added: a one-way state is not a safe state** (2026-11-10 20:30; AUT-80, OPEN): a qualification contradiction refuses assignment and start (CR-181), but it must end through a recorded fact owned by the verification path (never an app user or agent), or every later release it causes becomes permanent re-planning work for the team. A delegation correction records the replacement before revoking (AUT-81, OPEN). AUT-78 adopted as B2-T12d, AUT-79 as B2-T12b (b4).

**State 2026-11-11 02:30 (`aia` review 43; FE-053 to FE-055):**
- **A13 added (PLANNED):** the POOL1 matcher is a rule registered in AIG1 like PLAN3 (kind `rule`, off by default, ledger, stop threshold, allow-list without residents' or institution staff data), not an AI model (AUT-84). Idle capacity is derived from facts NAVORA already holds, never from a new availability entry, and the named member accepts within a standing team mandate (AUT-83, OPEN).
- **Control added: a fee or other incentive must not penalise the entries NAVORA's measures depend on** (AUT-82, CGR-172): the working-time record feeds the North Star and the administration measure; a fee taken from it at the margin rewards leaving days unconfirmed and declaring less administration.
- **Control added: every state only a verification path can end has an age signal to that path** (AUT-86; CR-205 option B adopted as B2-T12e test basis, AUT-80 adopted).
- FEE1, GMSEP, ONB1 and RDATA1 state "no AI"; confirmed. Stage 0 only; stage 1 entry conditions unchanged (D-41, D-2 OPEN).

**State 2026-11-11 08:20 (`aia` review 44; BD, D-18):**
- **Control added: no agent input reads a billing parameter, tested deny-by-default on both sides** (D-18 invariant (I1), `cra` 05:26): database side pgTAP 125 (#1064, OPEN until merged); app side AUT-87 (OPEN): every source file guarded except a named list of billing readers, so each new agent folder (A7, A13) is covered from its first commit.
- **Measurement before AI:** BD-2 is the first end-to-end run; AUT-88 (OPEN) proposes the human-act count per step there, so later agent stages are compared against a measured baseline, not an estimate.
- No agent added or removed. Stage 0 only; stage 1 entry conditions unchanged (D-41, D-2 OPEN).

**State 2026-11-11 14:24 (`aia` review 45; D-18 M3, B8 items):**
- **(I1) control IMPLEMENTED on both sides:** pgTAP 125 and the deny-by-default app guard (#1064 merged; AUT-87 closed).
- **Control added: a consistency check runs where the person who knows the facts acts, not only on a later record** (AUT-93, OPEN): the sequence and overlap check of CGR-180 (2) is shown at the F3 save, never as a refusal, and the fact carries the warning only for what was saved knowingly. One check function for both places.
- **Control added: a background derivation that may fail has a team-level monitor, not a manual catch-up act** (AUT-92, OPEN; CGR-181): derive-on-sign plus a scheduled catch-up and a count of final reports without a fact.
- **Re-entry is a rule gap, not a form detail** (AUT-91, AUT-94, OPEN): values the care graph already holds (care-plan minutes, the client's municipality) are offered as defaults; PLAN3 uses the same source.
- No agent added or removed. Stage 0 only; stage 1 entry conditions unchanged (D-41, D-2 OPEN).

**State 2026-11-11 20:20 (`aia` review 46; AUT-88 measured, J5-S K-3):**
- **Measurement before AI IMPLEMENTED:** the BD-2 spec counts human acts per step; the measured baseline (61 product acts on the synthetic seed, CI run 43037240509) is the BD reference (PO 18:39; AUT-88 closed). Later agent stages are compared with the same counter.
- **A6 control health, first PLANNED instance:** J5-S scheduled catch-up with one team count and no catch-up button (PO 16:39 K-3; AUT-92 closed). A deterministic job, kind `rule`, stage 0. The consistency check at the F3 save is adopted (CGR-180 (2), CGR-183; AUT-93 closed).
- **Control added: one entry for a value, every display derived from it** (AUT-95, OPEN): a care-plan item's frequency is entered once as structure and its text generated, so what the next nurse reads and what a planner (PLAN2, PLAN3, later A3) uses cannot differ. Any agent input must read the structure, never a parallel free text.
- No agent added or removed. Stage 0 only; stage 1 entry conditions unchanged (D-41, D-2 OPEN).

**State 2026-11-12 02:22 (`aia` review 47; CGR-184 aligned, ORD0-C3):**
- **Control added: a signal that an upstream fact changed after planning is derived at read time, in one family and one team count** (AUT-97, OPEN): ORD0-C3 joins `order_expired` in `visit_flags`; no stored task or exception to close by hand. Any later agent that reads visit signals (A3, A6) reads the derived flag, never a copy.
- **Correction:** my review-46 support of the CGR-182 text is replaced by support of CGR-184 (whoever holds the right to plan sees the count only). The control "no per-person view" is unaffected.
- No agent added or removed. Stage 0 only; stage 1 entry conditions unchanged (D-41 OPEN; staging Free with synthetic data only, FE-059; Phase B billing inputs OPEN, FE-060).

**State 2026-11-12 14:25 (`aia` review 49; PO questions on the departure tap, AN2 no-show category, «Fall eröffnen»):**
- **Control added: an automation never derives a fact the person did not record** (AUT-100): a gap between visits is not «travel» in the working-day proposal; only a `departed` event makes a travel segment. The departure tap stays optional (IMPLEMENTED).
- **Measures count what they say** (AUT-101): AN2 measure 8 classifies the first event other than `departed`, so «picked up» and «not reached» stay apart; AN2 stays a pilot hypothesis, never a safety monitor.
- **Intake as rule plus monitor** (AUT-102, OPEN): complete referrals open the team search by a deterministic check with the CGR-193 controls done where data are entered; people handle exceptions. The edge for a later stage (structured alerts proposed from the referrer's free text for a named team confirmer) is named, not proposed: real referral text is client data (D-35 rule A).
- No agent added or removed. Stage 0 only; stage 1 entry conditions unchanged.

**State 2026-11-12 08:23 (`aia` review 48; #1109 measured, PO challenge on minutes):**
- **PLAN3 ledger exercised in the BD run (IMPLEMENTED in test, #1109):** one proposed line, one-tap confirmation, `day_plan` line with reason and state read back through RLS. Correction rate and stop rule are not exercised by a one-line run (B5 measure).
- **Control added: a planning default may come from a confirmed care-graph value of the same unit; a clinical translation between units is never carried** (AUT-98, OPEN): visit minutes may default from the care-plan item (minutes per occurrence, AUT-91); the care-plan item never defaults from the assessment (minutes per period, ADR-123, CGR-84). Any later agent (A3, A10) follows the same line.
- **Measurement before AI:** the act counter reports each act's scope (once, per day, per visit, per case) so a proposer's per-visit cost is read correctly (AUT-99, OPEN). Measured: 75 product acts (#1109) against the 61-act baseline.
- No agent added or removed. Stage 0 only; stage 1 entry conditions unchanged (D-41 OPEN; production on synthetic data only is an application host, not an AI host, FE-062 to FE-064).

**Matching: rules decide eligibility, no score, no AI order among parallel offers (`aia` 2026-11-12 20:20, AUT-103 to AUT-105; input to FE-070 Lieferung 3):**
- **Control:** team eligibility for an offer and for «Versorgung zugesagt» is a versioned deterministic rule; each criterion is shown as checked, not met or not checked, never as a number. No score among teams, also none that only explains. While every eligible team receives the offer at once, an AI order of teams has no reader and is not built; the only preference among teams is RET1 continuity (a rule, window set by the organisation, CGR-196).
- **Control:** in a simulation organisation the offer and the commitment ask the same QUAL1 answer the planning paths ask, at team level, never a membership label alone (AUT-104, PLANNED for B1.2; activity mapping UNKNOWN, `cra`).
- **Edge:** the only AI role in matching is upstream: structured facts and alert proposals from a referrer's text for a named confirmer (A8, H, stage 2 or later). It never decides eligibility, fills a missing qualification, ranks teams or commits.
- **Measures:** team or organisation level only; the «Wir prüfen» signal is never read as a team's responsiveness (AUT-105).

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
| 2026-10-29 08:25 | `aia` | §12: VIS1 state updated (VIS1-10 built, #655); added the ownerless-visit design order and owner-proposal controls (AUT-20) and the "item links to the place of action" control (PO 08:15). No agent added or removed |
| 2026-10-29 14:55 | `aia` | §12: added the authorship and provenance control for clinical entries (OBS1; agent drafts show the confirmer as author and their origin beside it) and the "employer acts of one sitting on one card" control (AUT-21). No agent added or removed |
| 2026-10-29 20:20 | `aia` | §12: added the "confirmer read per value only" control (AUT-22, D-35 term 9 at table level), the OBS1 authorship state (IMPLEMENTED) and the D-1 precaution as an added stage-1 precondition. No agent added or removed |
| 2026-10-29 23:15 | `aia` | §12: AIG1-11 state (adopted); added the stop recovery path (AIG1-12) and the look-back controls of AUT-23 (one by one, "überholt" by rule pending the Clinical Owner). No agent added or removed |
| 2026-10-30 02:18 | `aia` | §12: AIG1 part (a) state (IMPLEMENTED at database level, synthetic test agent only); added the controls "a confirmation never stands for a check that did not run" (AIG1-15), "monitor the monitor" (AIG1-16), the usefulness measure for "no proposal" (AUT-25) and the team switch pattern (PLAN3-10). No agent added or removed |
| 2026-10-30 08:25 | `aia` | §12: added the care-plan review control after a reassessment (AUT-26: one confirmed act, no retype; A10 ends in it), the RLS4 acts-per-record state (IMPLEMENTED, AUT-24 closed) and the one-decision-per-name reconciliation rule (AUT-27). No agent added or removed |
| 2026-10-30 15:04 | `aia` | §12: care-plan review control state (ASM1-C4 built on #747, open; AUT-26 met in code), basis-by-identity control (ASM1-C6 (8), CGR-104) and the preset-reason pattern for correction acts (P-37). No agent added or removed |
| 2026-10-30 20:18 | `aia` | §12: AIG1 part (b) database half state (AIG1-15/-16 IMPLEMENTED, AIG1-C1 PLANNED) and the control "an open count holds only what can still be acted on; a stop exception can reach 0 while the agent stays stopped" (AUT-29). No agent added or removed |
| 2026-10-31 02:40 | `aia` | §12: AIG1-C1/-C2/-C3 state (IMPLEMENTED, AUT-29 closed); added the control "a stop's follow-up ends with its open lines, not with the agent's state" (AUT-30) and the expired-proposal control (AIG1-C4, AUT-31). No agent added or removed |
| 2026-11-03 02:40 | `aia` | §12: one-decision-per-name state (IMPLEMENTED, AUT-27 closed), AUT-30 adopted as AIG1-C5; added the control "measure before automating" (AUT-32). No agent added or removed |
| 2026-11-03 08:20 | `aia` | §12: AUT-32 answered by the AN3 draft; added the control "measure acts, not only spans" (AUT-33) and one definition per measure (AUT-34). No agent added or removed |
| 2026-11-03 14:40 | `aia` | Header: doctrine of §1/§7 marked superseded by the AI-first update §0/§3 (controls of §8/§12 stay). §12: added "human acts per proposal do not rise" (AUT-38), "contract before switch-on, harness before provider" (AUT-37), "rank by recoverable time" (AUT-36), stage-0 state. No agent added or removed |
| 2026-11-03 20:30 | `aia` | §12: added the control "an answer goes where the question arises; a read is not a proposal" (AUT-40) and the stage-0 state after the Delivery Program. No agent added or removed |
| 2026-11-04 02:20 | `aia` | §12: AUT-40 marked decided (PO 22:00); added the control "an offline time enters billing only through the audited correction path, without an extra act" (AUT-41). No agent added or removed |
| 2026-11-04 08:18 | `aia` | §12: AUT-41 state (target behind the Clinical Owner gate); added the control "nothing that raises a safety signal waits in a queue; no act with one possible outcome" (CGR-123, AUT-42, AUT-43) and the D-34 stage-1 checklist. No agent added or removed |
| 2026-11-04 14:20 | `aia` | §12: added the control "a relative's view is rule-based and costs the team one act" (D-40 owner decision, FAM1, AUT-44, AUT-45); D-39 A recorded (no sensor or prediction agent in the pilot). No agent added or removed |
| 2026-11-04 20:20 | `aia` | §12: added the control "no derived consent, no periodic re-confirmation" (CGR-130 (2), AUT-46, AUT-47). No agent added or removed |
| 2026-11-06 02:15 | `aia` | No control changed: the PLAN3 stack (#880 to #888, not merged) meets the stage-0 controls on screen (unticked list, no "select all", no per-person view, team look-back entry keyed on the stop); CGR-140 (rejected lines in neither share) answered with a separate share; AUT-52 (the team sees its own assistant measures). No agent added or removed |
| 2026-11-06 08:25 | `aia` | No control changed: the correction rate per agent now includes rejections ("Abgelehnt", #890) and reaches the team that holds the switch (#894); AUT-53 withdraws my own "no primary nurse set" clause (not a stored "kein Vorschlag" reason). No agent added or removed |
| 2026-11-05 20:20 | `aia` | No control changed: PLAN3-14 (#876, not merged) meets "every line re-checked at confirm" for the cross-team overlap limit, with no other team's data in ledger or readers; AUT-51 shown in the #876 code (a line refused at confirm blocks a fresh proposal). No agent added or removed |
| 2026-11-05 14:20 | `aia` | §12: PLAN3 part (a) recorded as the first agent beyond the test agent with every §8 control at database level (#872, not merged); added the control "a fresh request replaces stale lines without manual clean-up" (AUT-51). AUT-48 closed (owner merge decision). No agent added or removed |
| 2026-11-05 10:15 | `aia` | No control changed: `cra` option C conditions and CGR-135 are repository merge controls, not AI controls; AUT-50 proposes a deterministic gate-head check. AIG1 (#814) and AIR1 (#828) still unmerged (AUT-48). No agent added or removed |
| 2026-11-05 08:20 | `aia` | No control changed: CGR-132 (both pairs), CGR-134 and the `lca` AUT-46 addition are wording and deterministic refusals covered by the 2026-11-04 controls; AUT-49 is a repository process finding. AIG1 (#814) and AIR1 (#828) still unmerged (AUT-48, owner option C). No agent added or removed |
| 2026-11-05 02:25 | `aia` | No control changed: AUT-46 form and CGR-131 to CGR-133 are single-source wording, covered by the 2026-11-04 controls; AIG1 (#814) and AIR1 (#828) still unmerged (AUT-48, delivery hand-off). No agent added or removed |
| 2026-11-06 14:40 | `aia` | §12: added the controls for mandated rule lines (PLAN4, seven conditions), the DOC-AI scope note (AUT-54: structured report stays the F7 rule; agent only for unstructured input; level UNKNOWN until `cra`) and the administration-measure rule (AUT-55, AUT-56). No agent added or removed |
| 2026-11-06 20:20 | `aia` | §12: governance-layer state (AIG1-C1 to C5 and AIR1 IMPLEMENTED on `recovery/main`; stage-1 entry condition "layer merged" met), DOC-AI level G with its validator and inline omission control (AUT-54, AUT-60), billing pre-send checks bounded by AIR1 (AUT-59). No agent added or removed |
| 2026-11-07 02:20 | `aia` | §12: PLAN3 recorded as the first rule agent on `recovery/main` (stage-1 entry condition met); added the controls "no agent drafts into a prohibited table; a profile draft lands in a separate `record`-class field" (AUT-64), the inherited activity list (AUT-61), the expiry forecast before release (AUT-63) and consent of everyone present for M-DOK recordings (AUT-65). No agent added or removed |
| 2026-11-07 08:20 | `aia` | §12: QUAL1 state on `recovery/main` (prohibited class `qualification` IMPLEMENTED, PLAN3 rule before agent, AUT-61 adopted as QUAL1-20); added the controls "a foreseeable lapse is shown at planning" (AUT-67) and "a confirm-time lapse is not a correction" (AUT-68). No agent added or removed |
| 2026-11-07 14:20 | `aia` | §12: NH-A1 recorded (no agent; continuity default is a rule); added the control "a rule default takes effect with a logged source, no team-wide accept-all confirm; uncovered counts what stays empty" (AUT-69), own shift patterns (AUT-70), ward measures from events (AUT-71); AUT-67/-68 adopted. No agent added or removed |
| 2026-11-10 02:20 | `aia` | §12: FE-051 model path mapped (patterns 1-3 without an AI service; pattern 4 own Swiss hosting with option B governance; external provider synthetic-only stand-in at most; AUT-73), field allow-list for every agent (`cra` 17:29), E-3 documentation step as rule plus A7 (AUT-72), Phase A administration measure (AUT-74), FE-052 wording (gemergt, not abgenommen). No agent added or removed |
| 2026-11-10 08:30 | `aia` | §12: D-41 default and E-3 recommendation as amended by the PO (AUT-72, AUT-73 closed); control "a recorded due date is shown before it passes, never only as overdue" added (AUT-76), with QUAL1-22 as block test (AUT-77). No agent added or removed |
| 2026-11-10 14:30 | `aia` | §12: QUAL1-22 state corrected (part 1 IMPLEMENTED as refusal, part 2 PLANNED as B2-T12b; AUT-77 closed); control "a post-assignment lapse releases at once, with a count shown to the acting person before saving" added (AUT-78), released visits through the normal open list and PLAN3 (AUT-79). No agent added or removed |
| 2026-11-10 20:30 | `aia` | §12: control "a one-way state is not a safe state" added (AUT-80: grade contradiction has no resolution path in code; AUT-81: delegation correction order); AUT-78/-79 adopted into B2. No agent added or removed |
| 2026-11-11 02:30 | `aia` | §7: A13 demand pooling matcher (rule, stage 0, PLANNED) added; §12: FE-055 briefs recorded, controls "no fee penalises the entries the measures depend on" (AUT-82) and "a state only verification can end has an age signal" (AUT-86) added, AUT-80/-81 adopted. One agent added (A13, rule) |
| 2026-11-11 08:20 | `aia` | §12: control "no agent input reads a billing parameter, deny-by-default on both sides" (D-18 (I1), pgTAP 125, AUT-87) and "measure acts before agent stages" (AUT-88, BD-2) added. No agent added or removed |
| 2026-11-11 14:24 | `aia` | §12: controls "a consistency check runs where the person who knows the facts acts" (AUT-93) and "a failing background derivation has a monitor, not a catch-up act" (AUT-92) added; re-entry of care-graph values recorded as a rule gap (AUT-91, AUT-94); (I1) control IMPLEMENTED (AUT-87 closed). No agent added or removed |
| 2026-11-11 20:20 | `aia` | §7 A6: first PLANNED instance (J5-S catch-up and team count, AUT-92) noted in the gate column; §12: measured act baseline IMPLEMENTED (AUT-88 closed), AUT-92/-93 adopted, control "one entry for a value, every display derived" (AUT-95) added. No agent added or removed |
| 2026-11-12 02:22 | `aia` | §12: control "a changed upstream fact is a derived signal in one family and one count" (AUT-97, ORD0-C3) added; review-46 CGR-182 support corrected to CGR-184. No agent added or removed |
| 2026-11-12 08:23 | `aia` | §12: PLAN3 ledger exercised in the BD run (#1109); control "a planning default from a same-unit care-graph value, never a carried clinical translation" (AUT-98) and the scoped act counter (AUT-99) added. No agent added or removed |
| 2026-11-12 14:25 | `aia` | §12: controls «no derived fact the person did not record» (AUT-100) and «measures count what they say» (AUT-101); intake as rule plus monitor with the later-stage edge named (AUT-102). No agent added or removed |
| 2026-11-12 20:20 | `aia` | §12: matching controls «rules decide eligibility, no score, no AI order among parallel offers», «QUAL1 answer at offer and commitment» and «signal never read as responsiveness» (AUT-103 to AUT-105, input to FE-070 Lieferung 3). No agent added or removed |
