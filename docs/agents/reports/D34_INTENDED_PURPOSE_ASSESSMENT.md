# D-34 Intended Purpose Assessment

**Author:** Product Owner (`po`) · **Date:** 2026-10-26 (Europe/Zurich) · **For:** the owner and the regulatory adviser named under [D-34](../decisions/D-34.md) · **Repository state read:** `recovery/main` at f85219e (migrations 0001-0080, `src/`)

> **Not a regulatory determination.** This report prepares the D-34 decision. It is not legal or regulatory advice, and it does not say whether NAVORA is a medical device. Only the manufacturer (the owner, or the legal entity of D-12), with a regulatory adviser, can state the intended purpose and have it assessed. The `cra` and `lca` analyses it cites are advisory (D-27, DECISION_PACKAGES). Every statement is marked **IMPLEMENTED**, **PLANNED**, **OPEN** or **UNKNOWN**. No tests were run for this report. The repository was read statically.

## 1. Summary

1. **The current core reads no clinical content to raise, rank or route anything (IMPLEMENTED, static reading).**
   - This holds for migrations 0001-0080 and the TypeScript in `src/`: no rule uses care notes, observations, vital signs, assessment items, medication or diagnoses as a rule input.
   - Clinical text is stored, shown, handed over and snapshotted into signed reports.
   - Rules check only whether documentation exists, never what it says.
   - This confirms the 2026-10-24 inventory (D-34, *Engineering impact*; `cra` 18:26) and extends it from 0062 to 0080.
2. **The grey zone is wider than the D-34 package says.**
   - The package names two rules that rank or escalate on a patient-specific care-context fact: `visit_uncovered_hospital` and `quality_serious_open`.
   - This reading finds **three more** (IMPLEMENTED):
     - team offers are ordered by intake urgency;
     - the response deadline depends on the referral type, and a missed deadline escalates;
     - a returning client's first-refusal window depends on the referral type.
   - **One legacy screen** also filters and sorts client cases under the heading "Top Risiko-Fälle" (`/operations`, in TypeScript). This contradicts the D-34 wording rule and the Handbook's frontend rule.
   - None of these interprets clinical content. All of them belong on the adviser's list (§7).
3. **One correction to the draft statement.** The hospital category is not "recorded by a nurse at intake". It is derived from the type of the referring partner ("Spital" → `hospital_discharge`, 0017:295-297), which admin or Operations staff enter (0010:89). The statement must describe what the software actually does (§9).
4. **The future direction moves toward medical-device territory (PLANNED).** The Architecture Handbook, the care operating model and the nursing-home report plan:
   - AI drafts of reports, assessments and codes;
   - care-plan change proposals from observations;
   - a status-change sentinel;
   - validated risk signals;
   - computed interRAI/PAG/MQI outputs.

   On the sources read, several of these plausibly qualify, possibly in class IIa or higher under rule 11 (UNKNOWN until assessed). **Option C** (a separately qualified module with documented boundaries) remains the only route that keeps the core outside, if the adviser confirms it (§5, §8).
5. **Recommendation, unchanged in substance:** A plus C. The decision support adds four things:
   - a corrected and complete intended-purpose statement (v2);
   - a three-level triage of every capability;
   - a list of capabilities for the adviser;
   - one small product change to bring the as-built texts into line (brief [IPA1](../briefs/IPA1.md)).

## 2. Method and sources

- **Repository (IMPLEMENTED facts):**
  - The D-34 inventory 0019-0062 (po, 2026-10-24 17:10) and the `cra` confirmation (18:26).
  - A full static reading of migrations 0063-0080 and a search of all migrations and `src/` on 2026-10-26. The search terms were the clinical columns (`visit_observations`, `care_notes`, `diagnosis_tags`, `cognitive_status`, `mobility_status`, `care_level`, `medication`, `vital`, `diagnos`, `observation`) and the UI words in §6.
  - The PO checked these claims in the code itself: 0017:211-229, 0017:295-297, 0034:144-149, 0034:245-249, 0080:425-437, and `operations-client.tsx` lines 104-121, 131-138, 182-195 and 595.
- **Planned capabilities (PLANNED):**
  - `ARCHITECTURE.md` (Bounded Contexts, Datenflüsse, Rule Engine, Geodaten und KI);
  - `docs/product/CARE_OPERATING_MODEL.md`;
  - `docs/product/NURSING_HOME_TRANSFORMATION.md` (NH0-NH9, AI agents);
  - the draft briefs REF2, ORD1, J7;
  - the challenge-review rows in `NEXT_CAPABILITY.md`;
  - the decision packages D-13, D-17, D-24.
- **Regulatory sources.** Read by `lca` on 2026-10-24 and re-read for this report where marked:
  - [M1] MepV (SR 812.213) Art. 3, Art. 4 (secondary reproduction).
  - [M2] Swissmedic, Merkblatt *Medizinprodukte-Software*, BW630_30_007, **version 3.0, valid from 21.04.2026**. Re-read on 2026-10-26 in its French version (*Logiciels de dispositifs médicaux*). Relevant sections:
    - §4: software is a device when it serves a medical purpose for an individual and processes data beyond storage, archiving, simple search, communication or lossless compression. Examples of non-devices: hospital resource planning, reimbursement, scheduling of visits, electronic records that replace paper.
    - §5.1: rule 11 strongly limits class I.
    - §5.3: modules qualified as a whole bring the whole system under device law.
    - §6: duties of a manufacturer.
  - [M3] MDCG 2019-11 rev.1 (17 June 2025). EU guidance to which [M2] refers. Rev.1 keeps the substance and adds the term "medical device AI" (MDAI), which also falls under the EU AI Act, and the requirement that each module's intended purpose and the dependencies between modules are documented (Emergo by UL summary, read 2026-10-26).
  - [M4], [M5] CJEU **C-427/24**, judgment of 2 July 2026 (secondary sources: Heuking 23 July 2026, Osborne Clarke 31 July 2026; Bird & Bird summary read 2026-10-26). There are two limbs:
    - a medical intended purpose in the manufacturer's use-related information, **and**
    - objective capability to perform a medical function.

    Healthcare marketing claims alone do not create a device. Conversely, calling a product "an administrative or workflow tool" does not keep it outside if its functions objectively support diagnosis, monitoring or treatment decisions. The judgment is not Swiss law; whether Swiss practice follows it is UNKNOWN (adviser question 1a).
  - [S4] Kanton Zürich, *Besonderheiten bei Medizinprodukten* (30 January 2026): software that summarises, prioritises or interprets clinical information is a grey zone.
- **Not read:** the MepV and MDR in the primary text (MDR Art. 2(12), Annex VIII rule 11); the EU AI Act; Swiss rules on AI. They are UNKNOWN here and go to the adviser.

## 3. Triage scale used in this report

The scale is the PO's working triage for the adviser. It is **not a classification**.

| Level | Meaning | Anchor in the sources read |
|---|---|---|
| **L — low** | Organises people, time, records or money. Clinical text is only stored, shown or sent | [M2] §4 non-device examples (planning, scheduling, reimbursement, records replacing paper); [M3] Annex I a) |
| **G — grey** | Processes a patient-specific **care-context fact** (recorded by a person, not computed) to **rank, route, escalate or block** something for a professional | [S4] "prioritises"; [M3] Annex I f.1) "reprioritisation based on patient data"; *Snitem* line restated in [M4] |
| **H — higher** | **Interprets clinical content** (observations, notes, assessments) to produce information for an individual's care decision: a draft, a proposal, a score, a trigger | [M3] Annex II example 2 (risk score triggering care), rule 11; [M2] §5.1 |

**Input class** (D-34 control, po 2026-10-24 19:09): **V** visit, schedule or administrative fact; **N** care-context fact recorded by a person; **C** clinical content. *Proposed wording change:* "recorded by a nurse" becomes "recorded by a person", because the hospital category and the urgency are entered by intake staff (§1 item 3).

## 4. Current intended purpose (IMPLEMENTED)

### 4.1 What NAVORA does today, in substance
NAVORA organises home care by self-organised nursing teams along the journey Referral → Case → Matching → Team Decision → Planning → Visit → Documentation → Quality → Billing → Analytics.
- It records referrals and cases, and offers each case to all eligible teams.
- It plans visits from the care plan the team wrote, and records the visit as it happens.
- It builds the visit report from those facts, which the performing nurse signs.
- It hands what changed to the next nurse, tells the right people which visit needs someone, derives billable facts, and measures the pilot per team.
- It runs on synthetic data only. No real client exists (D-1, D-3, D-9, D-29 real-data gates).

### 4.2 The draft statement in force (po 2026-10-24, D-34)
It is accurate in direction, with three gaps found in this reading:
- (a) the hospital category is attributed to a nurse (wrong source);
- (b) urgency ordering, referral-type deadlines and the returning-client window are not described;
- (c) the safety-alert values from DOOR1 (displayed only) are not mentioned.

Version 2 is in §9.

### 4.3 Map of every current capability

Category columns: **Co** care coordination · **Wf** workflow support · **Doc** documentation · **QM** quality management · **CDS** clinical decision support (in substance) · **MD** medical-device risk (L/G/H, §3). ● = primary, ○ = secondary.

| ID | Capability (IMPLEMENTED, synthetic data) | Co | Wf | Doc | QM | CDS | MD | Input |
|---|---|---|---|---|---|---|---|---|
| F0 | Shared access foundation: organisations, roles, team-scoped reads, reasons, audit | | ● | ○ | | | L | V |
| J1 | Referral intake → case → readiness check → matching request | ● | ○ | ○ | | | **G** (urgency, partner type) | V, N |
| J2 | Team decision: offer to all eligible teams, decline reasons, response deadline, escalation | ● | ○ | | | | **G** (urgency order, deadline by referral type) | V, N |
| J3 | Visit planning with billable basis: care-plan summary, KLV category, RN-only rules | ○ | ● | ○ | | | L | V |
| PLAN2 | Self-planning: visits generated from the team's care plan | ○ | ● | | | | L | V |
| F1-F4 | Field tool: visit states, time corrections, observations, handover notes | | ● | ● | | | L | V |
| F6 / F7 | Signed visit report from visit facts, sign at completion, countersignature | | ○ | ● | ○ | | L | V |
| F6R | Return a report instead of countersigning a wrong version | | ○ | ● | ○ | | L | V |
| HAND1 | "Since your last visit": what changed, oldest first, nothing summarised or ranked | ● | | ○ | | | L | V |
| J6 | Primary nurse and deputy; continuity measure per team | ● | ○ | | ○ | | L | V |
| C1 | Case and visit lifecycle: pause, close, cancel, no-show | ○ | ● | ○ | | | L | V |
| OPS1 / CSR1 | Exception list from state: overdue, stuck, uncovered, interrupted, report not final, order expiring, serious quality event | ● | ● | | ○ | | **G** (`visit_uncovered_hospital`, `quality_serious_open`) | V, N |
| SIG1 / SIGC / FUP1 / DST1 | P1 safety signals to the people of the visit, Operations fallback, qualified take, clock-change safety | ● | ● | | | | L (G through the two OPS1 rules it carries) | V |
| SIG2 | Fixed-text push outside the app within working time (Google/Microsoft only; Safari/Firefox in-app, D-33) | ● | ○ | | | | L | V |
| COVER1 | Cross-team cover offer without client identity (switched off) | ● | ○ | | | | L | V |
| ABS1 | Absence releases visits to the team | ● | ● | | | | L | V |
| RET1 | Returning client offered first to the previous team | ● | ○ | | | | **G** (window by referral type) | V, N |
| ORD0 | Doctor link: "GP informed" record, `inform_gp` task, order without end date | ● | ○ | ○ | | | L | V |
| DOOR1 | What the nurse needs at the door: access and language notes, safety-alert values ja/nein/unbekannt (no clinical category yet), at-the-door fact | ○ | | ● | | ○ (display of recorded facts) | L (display only; see §7.2) | N, displayed |
| QG1 | Quality events recorded by the team, billing hold ("Abrechnungssperre") | | ○ | ○ | ● | | L (G only through OPS1 escalation) | N |
| J5 | Billable facts from final reports, estimate preview | | ● | ○ | | | L | V |
| WORK1 | Working day proposed from her own visit events, confirmed by the nurse | | ● | ○ | | | L | V |
| AN1 / AN2 | Pilot measures per team and organisation, never per client or nurse | | | | ● | | L | V |
| ADM1 / LEAVE1 | Members, qualifications, invitations; access ends with employment | | ● | | ○ | | L | V |
| RLS2 / RLS3 / AUD1 | Read scope and purpose-bound audit reading | | ● | | ○ | | L | V |
| COND1 (parts 1-2) | Leaver takes count as untaken; no code in access notes | ○ | ● | | | | L | V |
| Legacy `/operations` dashboard | KPIs, "Top Risiko-Fälle" (cases without team, in review, or urgency "hoch", sorted by age), team "risk score" from utilisation | ● | | | | | **G** (wording, urgency filter) | V, N |
| Legacy `/matching` demo | Deprecated team-request score with invented data, hidden by default (ADR-006) | | ○ | | | | L, if unreachable in production (UNKNOWN) | V |

### 4.4 Each current capability: why, who benefits, clinical influence, device risk

"Influences clinical decisions" separates **organisational influence** (who acts, when, with which record) from **clinical influence** (what care is given). No current capability tells a professional what is wrong with a client or what to do clinically.

| ID | Why it exists | Who benefits | Influences clinical decisions? | Device risk and reason |
|---|---|---|---|---|
| F0 | Only the people who care for a client read her data; every change has a reason | client (privacy), teams, licence holder | No | L: access control and audit |
| J1 | One case per referral, readiness checked before matching, no re-typing | client, intake, teams | Organisational: whether a case is ready to be offered (administrative facts) | G: the urgency and the partner type set later order and timing (J2) |
| J2 | Teams pull work themselves; no dispatcher | teams (autonomy), client (faster start) | Organisational: which offer a team sees first, by when it must answer | **G**: ordered by intake urgency (0034:249); deadline by referral type (0017:211-229) escalates to Operations (0019:121-130) |
| J3 | Planning carries its billable basis; B services and needs assessment only by an RN | client (qualified care), licence holder (billing) | Enforces who may perform a visit (qualification rule), not what care | L: role and order rules; the KLV mapping itself is `clinical` (D-15) |
| PLAN2 | Visits follow the care plan the team wrote; no hand planning | teams (time), client (regularity) | No: it schedules what the nurse planned | L: scheduling |
| F1-F4 | Verified visit times and the nurse's own observations | nurse, next nurse, payer | Records the nurse's observations; NAVORA does not process their content | L: records replacing paper ([M2] §4) |
| F6 / F7 / F6R | A signed, immutable report from facts; a wrong version is returned, not countersigned | client (correct record), nurse (no double entry), payer | No: the nurse writes and signs; NAVORA locks and versions | L: documentation |
| HAND1 | No team meeting needed to learn what changed | next nurse, client (continuity) | Informs the nurse's judgement by **display** of recorded entries, in time order, unsummarised | L: display and simple selection by time window; a summary or a ranking would move it to G/H |
| J6 | Continuity of care: a named primary nurse | client, nurse | Organisational | L |
| C1 | Honest case and visit states with reasons | teams, Operations, client | Organisational; the on-site protocol is D-19 (`clinical`) | L |
| OPS1 / CSR1 | Exceptions instead of a dispatcher watching a board | client (nothing missed), teams, Operations | Organisational: which visit needs a person now | **G** for two rules: P1 for an uncovered visit of a hospital-referred client (0019:37, 168-175); a nurse-chosen severity shortens escalation (0020). The rest is L (visit and schedule facts) |
| SIG1 family | Safety signals reach a person; nobody watches a screen | client (safety), teams | Organisational: who is told about which visit. The **response** to a no-show can be clinical, but that is the nurse's judgement (`cra` 18:26) | L as service-delivery watching; carries the two G rules. Whether "service-delivery monitoring" reads as "Überwachung" in MepV Art. 3 is UNKNOWN (question 1) |
| SIG2 | The signal reaches the phone | nurse, client | As SIG1 | L |
| COVER1, ABS1, RET1 | Cover and absence without a phone chain; a returning client returns to her team | client (continuity), teams | Organisational | L; RET1 **G** for the referral-type window (0034:147-148) |
| ORD0 | The doctor link must not get lost | client, GP, licence holder | Opens a task when a service is active without an order: administrative, not a clinical judgement | L |
| DOOR1 | What the nurse needs at the door, recorded and shown | nurse, client (safety, access) | Shows values a person recorded (ja/nein/unbekannt); nothing ranks, signals, blocks or opens a task on them (0073:32-34; DOOR1-8) | L while display only. A clinical category needs an approved register row (DOOR1-14, D-17 part 3) |
| QG1 | Quality events recorded; billing held where needed | client, licence holder (quality duty) | Records the nurse's own classification; the hold blocks billing, not care | L; G only through `quality_serious_open` |
| J5 | Billing facts without a back office | licence holder, team income | No | L ([M2] reimbursement example) |
| WORK1 | No second timesheet; North Star measurable | nurse (less administration), team | No | L |
| AN1 / AN2 | Pilot hypotheses measured, never per client | teams, owner | No: aggregates per team or organisation ("for an individual" limb not met) | L |
| ADM1, LEAVE1, RLS2/3, AUD1, COND1 | Membership, access end, read scope, audit | client (privacy), licence holder | No | L |
| Legacy `/operations` dashboard | Inherited control-tower view (pre-recovery) | Operations | Organisational | **G by wording**: "Top Risiko-Fälle", "Nach Risiko sortiert", "Qualitätsrisiken", "Kapazitätsmonitor" present an organisational filter as client risk. It also breaches the Handbook rule "React-Komponenten dürfen keine geheime Scoring-… Regel enthalten" (ARCHITECTURE, Frontend). Fixed by IPA1 |
| Legacy `/matching` demo | Inherited demo, deprecated (ADR-006) | none | No | L if unreachable; removal recommended (IPA1) |

**Finding on the whole core:** every current capability is care coordination, workflow support, documentation or team-level quality management. **None is clinical decision support in substance** (`cra` 18:26 confirmed this for 0019-0062; this reading extends it to 0080). Six places are grey (G): five rules that rank, route or escalate on a care-context fact, and one legacy screen whose wording describes an organisational filter as client risk.

## 5. Future intended purpose (PLANNED)

### 5.1 The direction
NAVORA becomes the operating system for self-organised care teams: home care now, then transitions of care with hospitals, then nursing homes, then integrated care networks. It should remove administration and coordination layers (intake coordinators, dispatchers, scheduling administrators, assessment hierarchies) through software, AI drafts and team decisions (CARE_OPERATING_MODEL, NURSING_HOME_TRANSFORMATION).

### 5.2 The decision behind the future intended purpose
Two futures are possible. The owner chooses between them in D-34:

| Future | Intended purpose | What it allows | What it costs |
|---|---|---|---|
| **F-A (core only)** | Organisation, communication and documentation of care by teams, for ever | every L capability, and G capabilities the adviser clears | the clinical AI ambition (assessment from evidence, AI drafts of clinical content) is not built, or is left to licensed third-party tools |
| **F-C (core + qualified modules)** | The core as in F-A; plus one or more **separately qualified modules**, each with its own intended purpose, boundaries and interfaces ([M2] §5.3; [M3] §7) | the H capabilities in §6, in the module, after qualification | a quality system, technical documentation, a clinical evaluation, post-market duties **for the module**; the boundary must be enforced in review. Whether a module may share login, UI and database with the core is UNKNOWN (question 3) |

The PO recommends **F-C as the target and F-A as the state until a module is qualified** (D-34 A plus C). Reason, by the value order: the clinical AI work that removes the most administration from nurses (values 1 and 5) is in the H list, but device duties on the whole platform would slow every team-facing improvement. A separate module keeps the core fast and makes the clinical ambition possible.

## 6. Planned capabilities and their direction

| Planned capability | Source | Input class | Would it influence clinical decisions? | MD | Route |
|---|---|---|---|---|---|
| REF2 hospital referral without an intake coordinator | brief (draft; D-9, D-3) | V, N | Organisational | L, G if the referral's urgency ranks offers (as J2 today) | core |
| ORD1 order renewal prepared from the care plan | brief (draft; D-22, D-9) | V | Prepares a request the nurse sends; "NAVORA adds nothing clinical"; a GP change becomes a team proposal that does not apply itself | L | core |
| J7 team economics | brief (draft; D-14) | V | No | L | core |
| J4 capacity windows, ADM2 contract-driven access | status rows | V | No | L | core |
| Invoices from J5 facts; statutory statistics | challenge rows | V | No | L | core |
| Visit window shared with client or relative | challenge row (D-9) | V | No | L | core |
| Proposed order of the day and route | challenge row (Q7) | V | Organisational (travel); **G** if it ordered visits by a client's urgency | L/G | core; adviser if urgency enters |
| Care-plan review proposed when signals accumulate | challenge row (2026-10-22) | V or **C** | Yes, if it reads observations or quality-event content: it tells the nurse a client may need reassessment | **L** on dates and visit facts only (like `care_plan_review_overdue` today); **H** once it reads content (`cra` 18:26) | core only on V inputs; module otherwise |
| Care loop: measured minutes, observations and quality events flow back as a care-plan change proposal | CARE_OPERATING_MODEL, Handbook change proposal | V (minutes) or **C** (observations) | Yes: proposes a change to care | L for "measured minutes above plan" shown as a fact; **H** for proposals derived from observations | split: minutes in core; observation-driven proposals in a module |
| AI extraction of intake data from discharge letters | challenge row, Gate 4 | **C** | Yes: an allergy or precaution missed or invented reaches the card; automation bias (H-03) | **H** | module |
| AI draft of the visit report or documentation ("KI-Draft → menschlich freigegebener Bericht") | ARCHITECTURE data flow; Documentation & AI context | **C** | Yes, if it summarises or interprets clinical information ([S4] grey zone); less if it only transcribes the nurse's own dictation | **G/H**, UNKNOWN which | module, or the adviser clears a transcription-only variant |
| NH1 shift roster from care plans and qualification mix | NH report | V | Organisational | L | core |
| NH2 continuous evidence mapped to assessment items | NH report (licence) | **C** | Yes: decides which observation counts as evidence for which item | **H** (mapping clinical content to a licensed instrument) | module; licence |
| NH3 assessment cycle: due dates; missing evidence; status-change trigger | NH report (licence) | V (dates) / **C** (trigger) | Due dates no; trigger yes | L for due dates; **H** for the trigger | split |
| NH4 coding draft agent, coherence check | NH report (licence, `clinical`) | **C** | Yes: proposes assessment codes that drive classification and tariff | **H** | module |
| NH5 status-change sentinel | NH report (licence) | **C** | Yes: watches a resident's documented support pattern, which is close to "Überwachung" in MepV Art. 3 | **H** | module |
| NH6 audit and controlling evidence pack | NH report | V (links) | No: assembles what was recorded | L/G (billing control) | core, adviser to confirm |
| NH7 ward QI and MQI each month | NH report (licence) | C, aggregated | Quality steering at ward level, not individual care | G: computed from clinical items, but for a population, not an individual ([M2] §4 "for an individual") | adviser; licensed definitions only |
| NH8 network expert pool; NH9 restraint register | NH report | V / N | No / record only | L | core (NH9 with `legal`, `clinical`) |
| Computed interRAI HC/LTCF outputs (scales, CAPs) | D-13 A, D-24 | **C** | Yes | **H** (and a licence) | module; D-13 B (reference only) stays in core |
| D-17 clinical safety-alert categories (allergies, fall risk, infection precautions as candidates) | D-17 part 3 (`clinical`) | N | Display of what a person recorded | L while display only; **G** if a value ever ranks, signals or blocks | core, display only |
| "Quality/Clinical Intelligence: validated risk signals" | ARCHITECTURE bounded context | **C** | Yes | **H** | module |
| "Assessment/LTCF/PAG/MQI: Berechnungen" | ARCHITECTURE bounded context | **C** | Yes | **H** | module |
| Rule Engine / Architect Mode, "KI erzeugt Hinweise" | ARCHITECTURE | depends on the rule | Depends: managing approved rule versions is L; hints about an individual client's care are H | L/H | core for rule governance; hints in a module |

## 7. Lists for the decision

### 7.1 Capabilities that should remain outside medical-device scope (core), with the condition that keeps them there
1. **Referral, case, matching, team decision** (J1, J2, REF2): administrative facts only. The urgency is chosen by a person and used only to order work. It is never computed from clinical content.
2. **Planning and scheduling** (J3, PLAN2, NH1, day-order proposal): from the care plan the team wrote and from visit windows. Never from a client's clinical state.
3. **Field record, report, signature, return** (F1-F4, F6, F7, F6R): stored, versioned and shown as the nurse wrote it. No summary, ranking or interpretation of clinical text.
4. **Handover** (HAND1): display in time order, unsummarised.
5. **Exceptions and signals** (OPS1, SIG1, SIG2, SIGC, FUP1, DST1, COVER1, ABS1, LEAVE1 take rules): they name a visit, a person and a time. They are raised from visit and schedule facts. The two G rules stay as built until the adviser answers (removing them lowers protection, H-01).
6. **Door facts and safety-alert values** (DOOR1, D-17 parts 1-2): display only. No value ranks, signals or blocks.
7. **Doctor link and order renewal** (ORD0, ORD1): administrative order facts. A GP's change is a proposal the team decides on.
8. **Quality events and holds** (QG1): the nurse classifies. NAVORA does not.
9. **Billing, working time, team economics, invoices** (J5, WORK1, J7).
10. **Analytics** (AN1, AN2, NH7 only if the adviser clears it): per team or organisation, never per client.
11. **Administration, access, audit** (F0, ADM1, LEAVE1, RLS2, RLS3, AUD1).
12. **D-13 B assessment record**: date, instrument, assessor, a reference to the provider's licensed tool and minutes. No items, no scores.

### 7.2 Capabilities that would likely need additional regulatory assessment
**(a) Current, grey (G).** Assess before the first real client; no build needed now.

| # | Rule or screen | What to ask |
|---|---|---|
| G1 | `visit_uncovered_hospital` (P1 for an uncovered visit of a hospital-referred client; 0019:37, 168-175) | question 1: administrative prioritisation, or processing patient data to inform a professional? |
| G2 | `quality_serious_open` (escalation timing from a nurse-chosen severity; 0020) | same question |
| G3 | `team_offers()` ordered by intake urgency (0034:249; 0017:347) | **new question 7** |
| G4 | response deadline per referral type and `deadline_passed` escalation (0017:211-243; 0019:121-130) | **new question 7** |
| G5 | RET1 first-refusal window per referral type (0034:147-148) | **new question 7** |
| G6 | legacy `/operations` "Top Risiko-Fälle" | removed or renamed by IPA1 **before** the adviser sees the product, so that the use-related information ([M4], [M5]) matches the statement |

**(b) Planned, higher (H).** Each needs a module with its own intended purpose, after the adviser's answer and before any build that reaches real clients:
- AI intake extraction;
- AI documentation drafts that summarise or interpret;
- care-plan review or change proposals that read clinical content;
- NH2, NH3 (status-change trigger), NH4, NH5;
- computed interRAI outputs;
- "validated risk signals";
- client-level AI hints from the rule engine.

**(c) Planned, to confirm (G):**
- NH7 ward QI/MQI (population level, computed from clinical items);
- NH6 controlling pack;
- a transcription-only documentation aid;
- any day-order proposal that uses urgency;
- any use of D-17 clinical values beyond display.

## 8. Medical-device risk assessment (product view, not a determination)

| Risk | Likelihood (PO view) | Effect | Mitigation in force | Residual |
|---|---|---|---|---|
| R1 A clinical-interpretation feature is built into the core under delivery pressure; the whole platform then falls under device law ([M2] §5.3) | medium: the Handbook itself names "validated risk signals", "Berechnungen" and AI drafts inside its contexts | every release carries device duties; the pilot stops | input-class control in every brief (`_TEMPLATE.md`); `cra` checks it; class C not built in the core | Handbook wording still invites it → proposed Handbook change (§10 F-4) |
| R2 Use-related texts describe the core as monitoring clients ("Risiko", "Sicherheitssignal", "überwachte Zeiten") | present today (§4.4 legacy screen, §10 F-1) | the adviser assesses a description that the product's own texts contradict ([M4]: texts count as use-related information) | wording rule (D-34 17:10) | IPA1 removes the legacy texts; "Sicherheitssignal" stays as organisational wording (`lca` 19:55: safety framing alone does not create a medical purpose) |
| R3 The objective-capability limb catches a G rule even with a clean statement ([M4]) | UNKNOWN | that rule, or the core, is in scope | the statement describes all five G rules (v2, §9); they are listed for the adviser | adviser questions 1, 1a, 7 |
| R4 Automation bias in AI drafts: a confirmed draft becomes the record (H-03) | high, if built without controls | clinical harm, and a device under rule 11 | module rule (C); NH report rule: AI drafts, a named person confirms | applies to the module design, not the core |
| R5 The module boundary is not accepted (shared UI, login, database) | UNKNOWN | the core is qualified with the module | none yet | adviser question 3 |
| R6 Manufacturer unclear (owner personally vs. the D-12 entity); a free pilot may still be *Bereitstellung* | UNKNOWN | liability with the wrong person | no real client before the adviser | adviser question 2; D-12 |
| R7 EU AI Act or Swiss AI rules apply to an AI module (MDAI in [M3] rev.1) | UNKNOWN | extra duties for the module | none | **new question 8** |
| R8 EHDS or electronic-record rules apply to the record functions | UNKNOWN | interoperability and security duties, not device duties | none | **new question 9** (outside MepV; noted, not assessed here) |

**Overall, on the sources read:**
- The **current core** is closest to the non-device examples of [M2] §4 and [M3] Annex I a). It reads no clinical content.
- Its residual exposure is the five G rules and the legacy wording. All are small and testable.
- The **planned future** contains several capabilities that plausibly qualify. On F-C they are confined to a qualified module.
- Neither statement is certain: `lca` keeps the A plus C verdict **unresolved: needs owner and regulatory adviser**.

## 9. Recommended intended-purpose wording (draft v2, for the owner and the adviser)

This text invents no rule. It describes the as-built behaviour and the exclusions in force. Version 1 (2026-10-24 20:09) stays in D-34 for comparison.

> **Intended purpose (draft v2).** NAVORA is software for organising home care by self-organised nursing teams. It supports referral and case intake, offering a case to eligible teams and recording their decision, planning visits from the care plan written by the team, recording visit times, the nurse's own observations and the signed visit report, handing over what changed to the next nurse, communication within the team, team-level quality records, billing preparation, working-time records, and team-level measures.
>
> NAVORA shows the people responsible which visit, at what time, needs a person: a visit that is late, uncovered, not opened, broken off, or whose report is not final, or a medical order that ends. It orders and times this work from organisational facts that a person records:
> - a case marked urgent at intake is offered first;
> - a case referred by a hospital gets a shorter team response time and a shorter first-refusal window for a returning client;
> - an uncovered visit for a client referred by a hospital is shown as more urgent;
> - a quality event that the reporting nurse marks as serious is escalated sooner.
>
> NAVORA shows safety and access information that a person recorded for a client, as recorded, without ranking, scoring or acting on it.
>
> **NAVORA is not intended to** diagnose, monitor a person's health condition or physiological values, compute a risk score, prognosis or need, interpret care notes, observations or assessments, or recommend a diagnosis, care measure or treatment. Every care decision is made, documented and signed by a qualified professional.
>
> **Intended users:** registered nurses, care assistants, team members with coordination tasks and administrators of a licensed home-care organisation; not clients. **Intended environment:** home care in Switzerland, on the organisation's own devices and browsers.

*German, for the UI and product texts (same content, shorter):*

> NAVORA organisiert die Pflege zu Hause durch selbstorganisierte Teams: Aufnahme, Teamentscheid, Einsatzplanung aus dem Pflegeplan, Einsatzdokumentation und Bericht, Übergabe, Kommunikation, Qualitätsmeldungen, Abrechnungsvorbereitung und Arbeitszeit. NAVORA zeigt, welcher Einsatz wann eine zuständige Person braucht, und ordnet diese Arbeit nach organisatorischen Angaben, die eine Person erfasst hat (Dringlichkeit bei der Aufnahme, Zuweisung durch ein Spital, als schwer gemeldetes Qualitätsereignis). NAVORA stellt keine Diagnose, überwacht keinen Gesundheitszustand, berechnet kein Risiko und empfiehlt keine Massnahme. Jede Pflegeentscheidung trifft und dokumentiert eine Fachperson.

**Exclusion list v2 (product authority; in force now as the safe default; PROVISIONAL until the owner and the adviser answer):**
- No feature computes a score, risk, prognosis, need or proposal from clinical content.
- No ranking, routing, escalation or block on clinical content.
- A care-context fact recorded by a person may order or time work only in the five ways named in the statement. A new use is marked "for the adviser" in its brief.
- Signals name a visit, a person and a time.
- Recorded safety values are displayed only.
- UI and product texts never use "Risiko", "Überwachung", "Zustand" or "Gesundheit" for a client or a case.

## 10. Findings and actions (decision support)

| # | Finding | Status | Action |
|---|---|---|---|
| F-1 | Legacy `/operations` shows "Top Risiko-Fälle", "Nach Risiko sortiert", "Keine Risikofälle", "Qualitätsrisiken", "Kapazitätsmonitor" and "SLA Monitor", and filters and sorts client cases in TypeScript (`operations-client.tsx` 131-138, 182-195, 595); the team "risk score" is a utilisation score (104-121). The `/matching` demo scorer is deprecated (ADR-006) and hidden; whether it can be reached in production is UNKNOWN | IMPLEMENTED (legacy, pre-recovery) | **Brief [IPA1](../briefs/IPA1.md)** approved (product authority; wording and removal only; no new rule) |
| F-2 | The draft statement attributes the hospital category to a nurse. It is derived from the referring partner type entered by intake staff (0017:295-297; 0010:89) | IMPLEMENTED fact; statement wrong | statement v2 (§9); input class N renamed "recorded by a person" in `_TEMPLATE.md` |
| F-3 | Three further N-class ordering and timing rules are not in the D-34 inventory (G3-G5) | IMPLEMENTED | added "for the adviser"; new question 7 |
| F-4 | The Architecture Handbook places clinical interpretation (AI drafts, validated risk signals, LTCF/PAG/MQI calculations, AI hints) inside its core bounded contexts | PLANNED | **proposed Handbook change** (PO, no edit made here): mark "Documentation & AI" drafts that interpret, "Assessment/LTCF/PAG/MQI Berechnungen", "Quality/Clinical Intelligence" risk signals and client-level "KI-Hinweise" as **module (D-34 C), outside the core**, each with its own intended purpose. The owner approves Handbook changes |
| F-5 | "überwachte Zeit(en)" (SIG2 watched hours) refers to staffed hours, but reads like "Überwachung" | IMPLEMENTED texts (`src/features/signals/rules.ts`, `src/features/push/rules.ts`, `admin/outside-section.tsx`) | IPA1: "besetzte Zeit(en)" |
| F-6 | AI Act, Swiss AI rules and EHDS were not read | UNKNOWN | new questions 8, 9 |

**New questions for the regulatory adviser** (they join D-34 questions 1-5 and 1a):
7. Do G3-G5 (offers ordered by an urgency chosen at intake, and response and first-refusal deadlines by the referral source) count as administrative prioritisation, or as processing patient data to inform a professional? Does the answer change if the urgency is a clinical judgement in substance?
8. If a module under F-C uses AI (AI intake extraction, documentation drafts, NH4 coding drafts), which duties apply in Switzerland beyond the MepV, and, for EU users, under the AI Act as MDAI?
9. Do the record functions (F1-F4, F6) fall under any Swiss or EU electronic-health-record rule (e.g. EPDG interfaces, EHDS) that the intended purpose should address? This is outside the device question.

## 11. What this means for the D-34 decision

- **Status unchanged:** D-34 `awaiting-approval: owner`, confidence Medium. The package changed, so `lca` (statement v2, G3-G5, questions 7-9) and `cra` (classification of the planned list in §6) are asked to re-check.
- **Ask of the owner, sharpened:** "approve statement v2, the exclusion list v2 and the module rule (A plus C, target F-C) as NAVORA's working position, and name a regulatory adviser who assesses it with this report, the capability map and the input-class column before the first real client."
- **Default in force until then:**
  - statement v2 and exclusion list v2 as the safe default;
  - wording rule and input-class control;
  - no real client before the adviser's assessment (with the D-1, D-3, D-9, D-29 real-data gates).
- **Blocks:**
  - real clients;
  - every H capability in §6;
  - release to real clients of any G rule beyond G1-G5.
