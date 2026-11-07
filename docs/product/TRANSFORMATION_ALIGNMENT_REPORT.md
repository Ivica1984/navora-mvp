# NAVORA Transformation Alignment Report

**Author:** Product Owner (`po`) · **Date:** 2026-10-26 (Europe/Zurich) · **Requested by:** the owner ("Vision Alignment Review") · **Status:** strategic review. It approves no build beyond what §8 names. **Repository state read:** `recovery/main` at f85219e.

**Question:** is NAVORA digitising existing healthcare structures, or redesigning them?

**Sources.**
- The NAVORA roadmap and queue: `docs/agents/NEXT_CAPABILITY.md` (35 queue items, challenge-review table), `ROADMAP.md`.
- The briefs, in particular ABS1, COVER1, HAND1, RET1, PLAN2, F6, F6R, J1-J7, OPS1, QG1, SIG1, WORK1, REF2, ORD1.
- `CARE_OPERATING_MODEL.md` and `NURSING_HOME_TRANSFORMATION.md` (NH0-NH9).
- The decision packages.
- As the challenge source: the *interRAI LTCF CH — Umsetzungsempfehlung Schweiz für die relevanten PAG- und MQI-Items* (BESA QSys, edition 30.08.2024). Its pages are quoted as recorded in the Nursing Home Transformation Report ("QSys p. n"). The PO did not re-read the source for this report.

**Status labels:** IMPLEMENTED (exists, synthetic data only) · PLANNED · OPEN (needs a decision) · UNKNOWN (not in a source; to be verified).

**What this report does not do:**
- It invents no clinical, legal, tariff, PAG, MQI or LTCF rule, and reproduces no calculation logic.
- It removes no control. A human control is retired only when a replacement is shown to control the same risk at least as well (§2).
- Where a home-care or nursing-home structure is not described in a source, it is marked **UNKNOWN (not in source)**. Pilot interviews must confirm it.

---

## 1. Answer in one page

**Coordination: NAVORA is redesigning it.** Every coordination layer NAVORA has touched was removed by design, not digitised:
- the dispatcher (J2 team pull);
- the scheduling administrator (PLAN2);
- the handover meeting (HAND1);
- the phone chain for absence and cover (ABS1, COVER1);
- re-intake after a hospital stay (RET1);
- the person watching a screen (SIG1, SIG2);
- documenting after the shift (F7);
- billing preparation (J5);
- the timesheet (WORK1).

**Control: NAVORA has not yet redesigned it. It has mostly added to it.**
- Since 2026-10-24, most accepted items are controls and conditions: RLS2, RLS3, AUD1, LEAVE1, DOOR1, DST1, SIGC, FUP1, COND1. They are needed, and several are superior controls: structural, tested and audited.
- But few human control steps have been **retired** in exchange:
  - every care-assistant report is still countersigned (D-10);
  - a coach or administrator lifts every quality hold (QG1);
  - a central administrator still admits members (D-20 is decided, ADM2 is not built);
  - Operations still types every referral (J1; REF2 is blocked).
- Of the 35 queue items, about 14 remove a role, a meeting or a manual task. About 20 are foundation or control.

**Assessment, documentation and quality: still mostly traditional.**
- In home care, the visit report is a narrative document signed and countersigned like paper.
- Care-plan review follows a calendar date.
- The KLV category is chosen by hand per service.
- Quality is measured by process (on time, signed) and not yet by outcome (G-5).

**Nursing homes: the NH proposals digitise LTCF more than they redesign it.**
- NH3 (assessment-cycle autopilot), NH4 (coding draft agent), NH5 (status-change sentinel) and NH6 (controlling pack) make the classification apparatus faster and cheaper.
- They keep its logic: periodic, project-style evidence collected to defend a payment level.
- They are also the capabilities with the highest medical-device exposure (D-34 assessment, §6: level H).
- A first-principles redesign separates **knowing the resident's needs** (continuous, owned by the primary nurse) from **classifying for payment** (an output of the licensed tool, computed elsewhere). It builds the evidence layer, not the classifier (§6.1).

**The biggest brake on transformation is not engineering. It is NAVORA's own approval queue.**
- REF2, ORD1, J7, ADM2, COVER1 switched on, risk-based countersignature and the approved KLV catalogue are each waiting for an owner, legal or clinical decision.
- 26 decisions are open; every `clinical` one waits for a Clinical Owner who is not named (G-1).
- The same centralisation NAVORA removes from care teams has reappeared in its own governance (§7).

---

## 2. Principles used for every verdict

1. **Name the risk before removing the role.** Every role, meeting, review and approval controls a risk. The verdict is about the **control**, not the person.
2. **A superior control** is one that is:
   - (a) **structural**: the wrong state cannot be entered, for example a signed report is immutable;
   - (b) **continuous**, not periodic;
   - (c) **complete**, not a sample;
   - (d) **evidenced**: an audit trail, a test, a measure;
   - (e) **owned by the people closest to the client**.

   A control that only one of these describes is not superior by default.
3. **Parallel run, then retire (proposed rule, §8 P-1).** A human control step is retired only after its replacement ran alongside it in the pilot and detected the same failures at least as well, on a written decision rule (threshold, minimum base), in the AN2 pattern. Until then both run.
4. **Never trade patient safety, data protection, the licence holder's non-delegable duties, or a registered nurse's legal signature** (KLV Art. 8a as quoted at QSys p. 49; D-12 condition 1).
5. **No reproduction of interRAI, PAG or MQI logic.** NAVORA builds the evidence and the workflow around licensed instruments. It does not rebuild them (D-13 B, D-24, D-34 module rule).

Mechanisms used in the tables: **A** automation · **S** structured data · **R** rule engine (approved, versioned rules) · **T** audit trail · **I** intelligent agent (drafts, a person confirms) · **O** self-organised team · **W** workflow orchestration.

Verdicts: **Disappear** (the value is not needed, or is achieved elsewhere) · **Transform** (the value stays, the mechanism changes) · **Keep** (a legal or clinical core) · **Strengthen** (the control is too weak today).

---

## 3. Home care

### 3.1 Roles and hierarchy

| Element | 1 Why it exists | 2 Risk it controls | 3 Value | 4 Still needed? | 5 Superior mechanism | NAVORA today | Verdict |
|---|---|---|---|---|---|---|---|
| Licence holder, nursing management named in the licence (UNKNOWN per canton, D-12, D-25) | legal accountability to canton and insurers | unlicensed care; nobody answerable | accountability | **yes**, legally | named functions, not a line layer: serious-event review, qualification confirmation, clinical-rule approval, untaken escalations as signals and records (T, W, R) | PROPOSED (D-12 condition 1, operating-model row "nursing-management line layer") | **Keep the duty, transform the layer** |
| Team lead (*Teamleitung*) (UNKNOWN, not in source) | rosters, first escalation, conduct | gaps, conflicts | coordination | **no**, as a rank | PLAN2, ABS1, COVER1, J2; rotating roles (O, W) | IMPLEMENTED (no line roles in the model) | **Disappear** |
| Dispatcher, scheduling (*Einsatzplanung*) (UNKNOWN) | assign visits | missed visits | coverage | **no** | team pull (J2), plan from the care plan (PLAN2), release on absence (ABS1), signals (SIG1) (A, W, O) | IMPLEMENTED | **Disappeared** |
| Intake coordinator | take referrals, check completeness | incomplete or unsafe start | a ready case | **the check yes, the role no** | structured referral by the referrer; readiness check by rule; exceptions only (S, R, W) | J1 IMPLEMENTED but **Operations re-types**; REF2 DRAFT (D-9, D-3) | **Transform: blocked** |
| Coach (Buurtzorg 1 : 47 teams) | absences, disputes, finances | team failure | support | **yes, on call** | called by signals (OPS1, AN1); absences to COVER1; finances to J7 (W, O) | partly IMPLEMENTED; J7 draft (D-14) | **Transform** |
| **NAVORA Operations** (our own role) | exceptions nobody else takes | a visit or case falls through | safety net | **yes, as a fallback** | each recurring exception type gets an automation owner and a shrink target; Operations sees only what teams did not take (SIG1-5) (A, W) | IMPLEMENTED, but it also does intake (J1) and closes exceptions by hand | **Transform**: shrink target missing (§8 P-3) |
| Quality officer (UNKNOWN) | collect and report quality | unnoticed harm | learning | **the function yes** | events from the visit (QG1), decision rules (AN2), team-owned review (O, R) | IMPLEMENTED for events; outcome measures UNKNOWN (G-5) | **Transform and strengthen** |
| Data-protection officer reading logs | find improper reads | privacy breach | detection | **the duty yes; periodic reading no** | improper reads impossible by design (RLS2, RLS3); a purpose-bound read leaves a log row (AUD1); only exceptional reads raise a signal (S, T) | IMPLEMENTED (D-3 gate iv met) | **Superior control in place** |
| Billing back office | prepare invoices | billing errors | revenue | **the release yes** | facts from signed reports (J5), invoice with a human release (A, T) | facts IMPLEMENTED; invoicing after D-12, D-18 | **Transform: blocked** |

### 3.2 Meetings

| Meeting | Why | Risk | Value | Needed? | Superior mechanism | NAVORA | Verdict |
|---|---|---|---|---|---|---|---|
| Daily handover (*Rapport*) | share what changed | information loss | continuity | **the information yes, the meeting no** | "Since your last visit" from the record (HAND1) (S, T) | IMPLEMENTED | **Disappeared** |
| Weekly team planning meeting (UNKNOWN) | distribute visits | gaps, overload | fairness | **no** for routine | PLAN2 series; team handles exceptions (A, O) | IMPLEMENTED | **Disappeared** |
| Case discussion | difficult situations | clinical drift | shared judgement | **yes**, for decisions | keep for decisions only; the record carries facts in advance (O) | not modelled | **Keep, slimmer** |
| Monthly pilot or quality review | read figures, decide changes | late reaction | steering | **the decision yes, the calendar no** | each hypothesis carries its decision rule; NAVORA marks the crossing (AN2) (R, A) | IMPLEMENTED (AN2) | **Disappeared, replaced** |

### 3.3 Review steps and approvals

| Element | Why | Risk | Value | Needed? | Superior mechanism | NAVORA | Verdict |
|---|---|---|---|---|---|---|---|
| Countersignature of every care-assistant report | an RN checks delegated work | a wrong or incomplete report; delegation outside competence | supervision | **the risk yes; a blanket check UNKNOWN** | risk-based review with a measured value: share returned (F6R-9), time to countersign; structural locks (F7 hash; immutable versions) (R, T) | blanket, stricter than recommended; F6R gives the return path; A vs B is `clinical` (D-10) | **Transform after evidence** (P-1) |
| Report signature by the performing nurse | accountability for what was done | unaccountable record | legal record | **yes** | sign at completion over a fact hash (F7) (S, T) | IMPLEMENTED | **Keep, improved** |
| Hold lift by coach or admin | someone checks before billing resumes | billing a care event that needs review | billing integrity | **yes** | lift by a named role with a reason; who may lift is `clinical` (D-16); review after the lift (option B) (T, R) | IMPLEMENTED, stricter (coach/admin) | **Transform after D-16** |
| Admission of a member by central admin | verify the person | unqualified care | safety | **verification yes, admission no** | the team decides membership; the employer records the contract once; qualification verified (D-20 D, D-29) (O, S) | D-20 decided by po; ADM2 not built (D-29, D-26) | **Transform: blocked** |
| Time-correction approval | prevent wrong times | billing fraud, wrong pay | integrity | **the trail yes, an approver no** | the nurse corrects with a reason; the original stays; billing reads the signed snapshot (T, S) | IMPLEMENTED (F3, J5-v3) | **Superior control in place** |
| Absence approval | coverage, fairness | uncovered visits | continuity | **no** | the member says so once; visits released by one rule (ABS1) (A, W) | IMPLEMENTED | **Disappeared** |
| Care-plan review on a fixed date | keep the plan current | outdated care | quality | **the review yes; the calendar is a proxy** | a review prompted by recorded change. The calendar stays as the floor where a rule requires it. Clinical inputs are D-34 module territory (§6) | date only (`care_plan_review_overdue`) | **Transform**, inputs per D-34 |
| Threshold overrides by admin | adapt signals | missed escalation | flexibility | **bounded** | the Clinical Owner sets a band; the team chooses inside it; an override can only make a signal earlier (D-28 C, ADM1-R) (R) | IMPLEMENTED (direction-aware range) | **Superior control in place** |

### 3.4 Coordination activities

| Activity | Why | Risk | Value | Needed? | Superior mechanism | NAVORA | Verdict |
|---|---|---|---|---|---|---|---|
| Phone chain when a nurse is absent | find a substitute | uncovered visit | continuity | **no** | ABS1 release, COVER1 offer, SIG1 to the team (A, W, O) | IMPLEMENTED (COVER1 switched off, D-3) | **Disappeared** |
| Matching by phone between hospital and providers | find a provider | delayed discharge | access | **no** | one referral to all eligible teams, a deadline, escalation (J2, REF2) (W) | J2 IMPLEMENTED; REF2 DRAFT | **Transform: blocked** |
| Chasing GP practices for orders | a valid order | billing without an order; care without a mandate | legality | **the order yes, the chasing no** | prepared renewal sent by the primary nurse, confirmed digitally (ORD1); doctor link task (ORD0) (A, W) | ORD0 IMPLEMENTED; ORD1 DRAFT (D-22, D-9) | **Transform: blocked** |
| Relatives phoning to ask when the nurse comes | certainty | distress, missed access | service | **no** | shared visit window with consent (W, S) | HYPOTHESIS (D-9) | **Transform** |
| Phoning a relative at the door for the key-safe code | entry | lost care time | access | **yes for now**: no code is stored (privacy precondition) | the provider's own key arrangement outside NAVORA; measured first | HYPOTHESIS (2026-10-26 13:15) | **Keep, measure** |
| Transfer to hospital, return home | information transfer | loss at transitions | continuity | **the information yes** | one record across settings; paused case resumes; returning client to the known team (RET1, HAND1) (S, W) | RET1 IMPLEMENTED | **Transform, partly done** |

### 3.5 Assessment, planning and documentation

| Activity | Why | Risk | Value | Needed? | Superior mechanism | NAVORA | Verdict |
|---|---|---|---|---|---|---|---|
| Needs assessment by an RN (KLV) | determine need; legal basis for billing | wrong care, unbillable care | the care plan | **yes**, legal core | RN performs it (DB-enforced, J3); instrument-neutral record with a reference to the licensed tool (D-13 B) (S, R) | IMPLEMENTED (RN rule); D-13 B decided | **Keep** |
| KLV category chosen per service by hand | billing basis | mis-billing | correct billing | **the category yes, the choice no** | approved service catalogue; the team changes it only with a reason (D-15 C) (S, R) | free choice IMPLEMENTED; catalogue is `clinical` (G-10) | **Transform: blocked** |
| Visit planning by hand | schedule care | gaps | regularity | **no** | PLAN2 (A) | IMPLEMENTED | **Disappeared** |
| Six status taps per visit | verified time | wrong billing, wrong pay | evidence | **start and end yes; the rest UNKNOWN** | infer travel and pause; measure the correction share first (A) | HYPOTHESIS | **Transform after evidence** |
| Visit report as a narrative written after care | record of care | lost information | legal record | **the record yes; re-writing known facts no** | report built from visit facts, signed at completion (F6, F7) (S, A) | IMPLEMENTED | **Transformed** |
| Documenting care given as planned | proof of delivery | billing without delivery | evidence | **no** if the visit facts already prove delivery | **exception reporting**: the record states deviations; delivery is proven by events and signature. The LTCF source already calls the care report an exception report, "not proof of delivery" (QSys p. 3) | not stated as a principle | **Transform** (§8 P-2) |
| Mandatory reason codes for facts NAVORA knows | traceability | unexplained changes | audit | **the trail yes; re-stating known facts no** | the server stores the known fact; a reason only when a person decides something new (CGR-34 pattern) (S, T) | partly IMPLEMENTED (CGR-34); hypothesis for `cancel_visit` "other" | **Transform** |
| Timesheet | working-time law, pay | wrong pay | compliance | **the record yes, the sheet no** | day proposed from visit events, confirmed by the nurse (WORK1) (A, T) | IMPLEMENTED | **Transformed**; the monthly export still open (challenge row) |
| Statutory statistics compiled by hand | cantonal duty | non-compliance | reporting | **yes** | generated from facts (A) | HYPOTHESIS (D-11) | **Transform** |

---

## 4. Nursing homes (challenge source: interRAI LTCF CH, QSys)

### 4.1 Hierarchy and staffing structures (QSys pp. 49-53, as recorded)

| Role | Why it exists | Risk it controls | Value | Still needed? | Superior mechanism | NH proposal | Verdict and correction |
|---|---|---|---|---|---|---|---|
| Home director (*Heimleitung*) | overall responsibility for the LTCF system (p. 51) | unaccountable institution | accountability | **yes**, as licence holder | named duties as signals and records (T, W) | shrinks (NH report §3) | **Keep the duty** |
| Head of care | professional standards (p. 52) | clinical drift across wards | governance | **the function yes** | network clinical lead (O, T); cantonal requirement UNKNOWN (D-25) | NH8 | **Transform** |
| Ward leader (UNKNOWN, not in source) | rosters, handover, escalation | coordination failure | coordination | **no**, as a rank | ward team, NH1, HAND1, COVER1 (O, A) | NH0, NH1 | **Disappear** |
| LTCF coordinator (1 : 8) | run the observation period and code it (pp. 49-50) | missing or wrong classification | a correct PAG | **the legal assessment yes, the role no**; the source prefers the primary nurse (p. 4) | evidence captured at the point of care; the primary nurse confirms (S, O) | NH2-NH4 automate the coordinator's work | **Disappear as a role**. **Correction:** do not rebuild the coordinator as an agent (NH3, NH4). Remove the need for the project (§6.1) |
| LTCF supervisor (1 : 16) | check PAG, documentation and care plans (pp. 50-51) | unsupported codes that insurers reject | correctness | **the clinical part yes; the checking layer no** | structural completeness and traceability before signature (S, T); the licensed tool's own validation | NH4 coherence agent | **Transform**: the check becomes a property of the evidence, not an AI reviewer |
| LTCF expert (≥ 1 per home) | audits, insurer controlling, training (pp. 51-53) | payment defence | trust of insurers | **yes, at network level** | full traceability instead of samples (T); evidence packs (A) | NH6, NH8 | **Transform** (network pool) |
| Quality steering group (pp. 52-53) | interpret QI, MQI | late improvement | learning | **the learning yes, the group no** | team-owned indicators with decision rules (AN2 pattern); MQI from the licensed definitions, computed outside NAVORA or in a qualified module (D-34) | NH7 | **Transform**; MQI computation per D-34 |
| Scheduling administrator (UNKNOWN) | 24 h rosters | uncovered shifts, labour-law breaches | coverage | **no** | roster from care plans and qualification mix, labour rules as configuration from `legal` (A, R, O) | NH1 | **Disappear** |
| Intake and discharge coordinators (UNKNOWN) | admission and transfer | information loss; financing gaps | transitions | **contracts and financing yes** | REF2, RET1, HAND1; a small admissions service for contracts (W, S) | NH report §3 | **Mostly disappear** |

### 4.2 LTCF assessment workflow (QSys pp. 3-5, 49-50, as recorded)

| Step | Why | Risk | Value | Still needed? | Superior mechanism | Verdict |
|---|---|---|---|---|---|---|
| Due dates every 180 / 270 / 90 days (p. 50) | periodic re-classification | an outdated PAG level | payment accuracy | **as a floor, yes**: it is in the system's rules | dates shown to the primary nurse (A). This is bookkeeping, not redesign | **Keep as a floor** |
| 7-day (3-day) observation period as a project (pp. 4-5) | collect evidence for every PAG item | unsupported classification | evidence | **the evidence yes, the project no** | evidence is continuous from routine documentation; the period becomes a **confirmation that evidence is complete**, not a collection effort (S) | **Transform** |
| Documenting stable items once per period, "even when stable" (p. 4) | prove an unchanged state | a stale item coded | evidence | **only because evidence is periodic** | a dated, signed "unchanged since" statement over existing evidence, if the licensed rules accept it: **UNKNOWN** (licence, insurer contract, D-24) | **Transform if allowed**; otherwise keep |
| Focus, planning and closing meetings (3 per period) | coordinate the period | missed items | coordination | **no** for coordination; **yes** for the resident's focus conversation (p. 4) | missing-evidence list for the team (A); the focus conversation stays | **Disappear except the conversation** |
| "Who documents which item on which day" (p. 50) | spread the work | gaps | coverage | **no** | not needed when evidence is continuous | **Disappear** |
| Coding by the coordinator; check by the supervisor; sample audit by the expert | correct codes | rejected classification; over- or under-payment | payment integrity | **the signed determination yes** (RN, KLV Art. 8a) | the primary nurse codes in the **licensed tool** from complete, traceable evidence; NAVORA shows which entries support it (T); no NAVORA-computed code (D-13 B, D-34) | **Transform**; do not build NH4 as a NAVORA coding agent first (§6.1) |
| Co-signature by the delegating RN when the coordinator is not an RN (p. 49) | legal accountability | unqualified determination | legality | **yes** while a non-RN codes | the primary nurse is an RN; the co-signature then falls away by itself | **Disappears by design**, not by removing the rule |
| Physician signs the needs report (p. 49) | medical co-responsibility | care without medical knowledge | legality | **yes** | prepared report sent digitally (ORD1 pattern); D-22 for the valid form | **Keep, digitise the hand-off** |
| Status change: upward needs a full period, downward a direct edit (p. 3) | payment control | over-payment | tariff integrity | **the asymmetry controls payment, not care** | a symmetric change signal for care (NH5), **but** a sentinel reading documented support patterns is D-34 level H | **Transform the care view; the tariff rule is not NAVORA's to change** (insurer contract, D-24) |
| Insurer controlling defended by the expert (p. 52) | payment defence | lost revenue | trust | **yes**, with full evidence | evidence pack per resident from the trail (A, T) | **Transform** (NH6) |

### 4.3 PAG and MQI workflows

| Element | Why | Risk | Value | Needed? | Superior mechanism | Verdict |
|---|---|---|---|---|---|---|
| PAG group and tariff level 1-12 (Merkblatt pp. 55-62) | payment by care dependency | mispayment | fair funding | **yes**, it is the tariff system | computed by the licensed tool, never by NAVORA; NAVORA delivers complete evidence and the signature path | **Keep, outside NAVORA** |
| MQI collection and reporting | national quality indicators | invisible quality differences | accountability | **yes** | from routine data with licensed definitions only; computed in the licensed tool or a qualified module (D-34); teams read their own each month | **Transform the work, not the definition** |
| Quality steering group reading QI/MQI | improvement | late action | learning | **the action yes** | decision rules on indicators (AN2), team-owned, plus balancing measures | **Transform** |

---

## 5. Cross-cutting findings

### 5.1 Duplicated work
1. **Intake typed twice:** by the referrer and again by Operations (J1). Fix: REF2 (blocked: D-9, D-3).
2. **Stable items documented again to prove they are stable** (QSys p. 4). The redesign is in §6.1; acceptance is UNKNOWN (licence).
3. **The KLV category chosen per service** while a catalogue could carry it (D-15).
4. **Reason codes restating facts NAVORA already holds** (CGR-34 pattern; `cancel_visit` "other").
5. **The working day exported monthly** to hand to the employer, although the record exists (WORK1-7, challenge row).
6. **Assessment evidence collected in a separate project** beside routine documentation (LTCF).
7. **Order details re-typed from paper** (D-22 structured order record).

### 5.2 Unnecessary hierarchy
1. Nursing homes: up to five levels above the bedside nurse (coordinator → supervisor → expert → head of care → director; QSys pp. 49-53). The target is **two** (ward team; accountable licence holder with network experts).
2. Home care: team lead and dispatcher layers. Already removed in NAVORA's model.
3. **A nursing-management line that comes with the licence** (D-12, hypothesis): only its duties are needed, as named functions.
4. **NAVORA's own decision queue** (§7).

### 5.3 Manual validation that could disappear (after a parallel run, P-1)
- The supervisor's documentation check: replaced by structural completeness before signature, provided the licensed tool or a qualified module does any item-level check.
- The expert's sample audit: replaced by a complete trail; keep a small human sample during the parallel run.
- Blanket countersignature: replaced by a risk-based review (D-10 B), only on F6R-9 evidence.
- The data-protection officer reading logs: done (RLS2, RLS3, AUD1).
- Operations closing exceptions by hand: exceptions close with their cause (CGR-06, CGR-22, IMPLEMENTED).

### 5.4 Meetings that could disappear
- *Rapport* (done: HAND1).
- Weekly planning (done: PLAN2).
- LTCF focus team meeting, planning meeting and closing meeting, **except the resident's focus conversation** (p. 4).
- The monthly pilot review (done: AN2 decision rules).
- The quality steering group as a standing meeting (NH7 with decision rules).

### 5.5 Approvals that could disappear
- Absence approval (done).
- Time-correction approval (never introduced; trail instead).
- Central member admission (D-20 decided; ADM2 blocked).
- Roster approval by a ward leader (NH1: the team approves).
- Equipment sign-off by a host organisation (Buurtzorg UK lesson; not in NAVORA).
- The coach or admin hold lift, **narrowed** (D-16, `clinical`).

### 5.6 Quality controls that should be strengthened
1. **Outcome indicators** (falls, pressure injuries, unplanned hospital admissions, as candidates only). The set is `clinical` (G-5, G-1). Today every NAVORA quality measure is a process measure.
2. **Balancing measures beside every efficiency measure.** For example, the direct care share is read only beside safety measures (rule of 2026-10-26 10:15). Extend the rule to PLAN2 adherence, cover share and time to first visit.
3. **A measured value for every human review that stays.** Countersignature return share and latency (F6R-9); hold-lift reasons; time to take a signal (AN2 measure 10). A review whose value is never measured cannot be improved or retired.
4. **AI draft controls before any agent ships:**
   - correction rate by the human;
   - errors found later;
   - a forced-attention design so that confirmation is not a click-through (automation bias, H-03, D-34 §8 R4).
5. **Client voice.** A client or relative can see the visit window and raise a concern without a phone call (hypothesis, D-9). Today no control in NAVORA is client-initiated.

---

## 6. First-principles redesigns (answer to question 3)

### 6.1 Assessment and classification: build the evidence layer, not the classifier
**Today's logic (LTCF):** assessment is periodic, evidence is a project, and correctness is checked afterwards by people (NH report, executive summary). The NH proposals keep the periodic logic and automate the people (NH3 autopilot, NH4 coding agent, NH5 sentinel).

**From first principles:**
- The resident's needs are known **continuously** by the primary nurse from routine care.
- The payment classification is a **derived output**, produced by the licensed instrument from the same evidence and signed by an RN.

NAVORA's job:
- (a) make documentation at the point of care **complete, sourced and dated** (S, T);
- (b) let the nurse link an entry to an instrument item **herself** (a recorded choice, input class N, not a NAVORA interpretation);
- (c) show the primary nurse which required items have **no** linked entry in the window (completeness, not judgement);
- (d) hand the evidence and the signature path to the licensed tool (D-13 B).

**Why it is superior:**
- It removes the observation project and the "who documents what" plan.
- It also removes the supervisor's completeness check, because completeness is visible before signature.
- It keeps the RN's determination and the licensed computation.
- It avoids rebuilding interRAI.
- It keeps NAVORA at the low device-risk level (documentation), while NH2 as written (automatic mapping), NH4 and NH5 are level H (D-34 assessment, §6).

**Proposed re-sequencing (PLANNED; needs D-24, licence):**
- NH2′ "evidence linked by the nurse" first.
- NH3 due dates.
- NH6 evidence pack.
- NH4 and NH5 only later, as a qualified module, if the evidence shows the nurse-linked layer is not enough.

UNKNOWN: whether the licensed rules and the insurers accept continuous, nurse-linked evidence instead of a period (D-24 question).

### 6.2 Supervision: from people checking people to properties of the record
A record that cannot be signed when its facts changed (F7), cannot be countersigned when wrong (F6R), cannot be read outside the team (RLS2, RLS3) and cannot be altered after signature (F6) already controls most of what supervision checked by hand.

Two pieces are missing:
- (1) a measured, targeted human review where the evidence shows risk (D-10 B after F6R-9);
- (2) the parallel-run rule (P-1), so that the supervisor layer is not re-created "to be safe".

### 6.3 Quality: from periodic reporting to decision rules on outcomes
AN2's written decision rules already replace the review meeting. Two pieces are missing:
- **outcomes** (G-5, Clinical Owner);
- **balancing pairs**.

The care loop then closes without NAVORA interpreting clinical content:
- the team sees measured minutes against plan, quality events and outcome counts per client as **facts**;
- the team changes the plan.

An AI proposal is not the first step: it would be D-34 level H, and the team can act on facts.

### 6.4 Operations: a shrinking exception service, not a control tower
Operations should be the fallback for what teams did not take (SIG1-5), with:
- a target of teams per Operations person;
- one automation owner per recurring exception type.

The legacy `/operations` control-tower panels ("Top Risiko-Fälle", "Kapazitätsmonitor", "SLA Monitor") are traditional healthcare software. They go with IPA1. Intake leaves Operations with REF2.

### 6.5 Documentation: exception reporting with proof of delivery from events
Adopt the LTCF source's own principle ("the care report is an exception report, not proof of delivery", QSys p. 3) for home care:
- **delivery** is proven by visit events and the signed facts;
- the nurse writes only what deviates from the plan or what the next nurse must know (HAND1).

Measure it: words written per visit and the share of reports with free text, beside the continuity and quality measures.

### 6.6 Planning and staffing: the care plan drives the roster
PLAN2 already generates visits from the care plan. The nursing-home extension:
- NH1 generates shifts from residents' care plans and the qualification mix;
- labour-law rules come as configuration from `legal`;
- the team approves.

Value: no scheduling administrator, and qualification mix as a rule rather than a manager's memory.

### 6.7 Transitions: one record, not a transfer summary
A transfer summary is a re-written extract. The superior design is a consented, scoped view of the same record for the receiving team (RET1, REF2, HAND1), so nothing is re-typed. D-9 and D-3 gate it.

---

## 7. NAVORA's own governance: the hierarchy it must not rebuild
The care model removes central approval from teams. NAVORA's own delivery currently routes most transformation through one approver:
- 26 open decisions; 9 `clinical` packages wait for a Clinical Owner who is not named (G-1), and 17 packages await the owner;
- the owner-level asks include D-1, D-2, D-7, D-8, D-9, D-11, D-12, D-14, D-29 and D-34.

This is not a criticism of the decision process: the packages exist so that each ask is one line. It is a finding: **the three highest-leverage transformation acts are not builds.** They are:
1. **Name the Clinical Owner (G-1).** This unblocks D-10 (risk-based countersignature), D-15 (catalogue instead of hand classification), D-16 (hold lift), D-28 (signal thresholds), D-17 part 3 and outcome indicators (G-5).
2. **Name a legal and a regulatory adviser.** This unblocks D-9 (REF2 and ORD1, the intake and doctor coordination layers), D-22, D-33's reassessment and D-34.
3. **Choose the pilot entity and canton (D-12, D-11).** This unblocks billing and invoicing (D-18), team economics (J7, D-14) and therefore the nurse-income value.

---

## 8. Proposals from this review

| # | Proposal | Type | Status |
|---|---|---|---|
| P-1 | **Parallel run, then retire:** a human control step is retired only after its replacement ran alongside it in the pilot and was shown, on a written decision rule, to detect the same failures at least as well; the rule names the risk, the replacement, the measure and the threshold | operating-model principle; challenge row | PLANNED (recorded in `CARE_OPERATING_MODEL.md`) |
| P-2 | **Exception reporting in home care:** delivery is proven by events and the signed facts; free text only for deviations and handover; measured (words per visit, share with free text) beside continuity and quality | hypothesis | challenge row |
| P-3 | **Operations shrink target:** teams per Operations person and one automation owner per recurring exception type, read in AN2 | hypothesis | challenge row |
| P-4 | **NH re-sequencing:** NH2′ (evidence linked by the nurse, completeness shown) before NH4 and NH5; no NAVORA-computed code, sentinel or score in the core | change to the NH report §9-§10 | recorded there; needs D-24, licence |
| P-5 | **Balancing pairs:** every efficiency measure in AN1 or AN2 is read beside a named safety or quality measure | rule for briefs | challenge row |
| P-6 | **IPA1** (from the D-34 assessment): the control-tower panels and the "Risiko" wording go | brief | approved, *Next up* 2 |

---

## 9. Explicit answers

### 9.1 Which parts of the current roadmap already support the NAVORA vision?
**Removing coordination roles:**
- J2 team pull (no dispatcher);
- PLAN2 (no scheduling administrator);
- HAND1 (no *Rapport*);
- ABS1 and COVER1 (no phone chain);
- RET1 (no re-intake);
- SIG1 and SIG2 (no one watching a screen);
- F7 (no after-shift documentation);
- J5 (no billing preparation);
- WORK1 (no timesheet);
- AN2 (no review meeting);
- F6R (no countersigning a known-wrong version);
- ORD0 (the doctor link does not depend on memory).

**Superior controls:**
- immutable signed versions and the fact hash (F6, F7);
- team-scoped reads by design (RLS2, RLS3);
- purpose-bound audit reading (AUD1);
- access ends with employment (LEAVE1);
- exceptions that close only with their cause (CGR-06, CGR-22);
- direction-aware thresholds (ADM1-R);
- the input-class control (D-34).

**Decided redesigns waiting for a build or a gate:**
- team admission (D-20);
- instrument-neutral assessment (D-13 B);
- REF2, ORD1, J7.

### 9.2 Which parts still resemble traditional healthcare software?
- The **legacy `/operations` control tower**: "Top Risiko-Fälle", "Kapazitätsmonitor", "SLA Monitor" (IPA1).
- **Operations as intake**: J1 is re-typed by Operations until REF2.
- **Blanket countersignature** of care-assistant reports (D-10).
- **Hold lift by coach or admin** (D-16).
- **The care-plan review by calendar date**, and the KLV category chosen by hand (D-15).
- **The narrative visit report** as the proof of delivery (P-2).
- **Mandatory reasons** that restate known facts.
- **Process-only quality measures**, with no outcomes (G-5).
- **The monthly export** of the working day.
- **NH3, NH4, NH5 and NH7 as written:** a faster LTCF apparatus (periodic cycle, coding agent, supervisor-like coherence agent, steering-group indicators) rather than its replacement.

### 9.3 Which future capabilities should be redesigned from first principles?
1. **LTCF/interRAI assessment** (NH2-NH5): an evidence layer linked by the nurse, completeness shown, classification in the licensed tool (§6.1).
2. **Quality management** (NH7, AN1): outcomes plus balancing pairs, team-owned decision rules (§6.3).
3. **The care loop and care-plan review:** facts to the team first; AI proposals only as a qualified module (§6.3; D-34).
4. **AI drafting** (intake extraction, documentation drafts, transition summaries):
   - designed against automation bias, with correction rates measured;
   - placed in a module where it interprets clinical content (D-34);
   - transfer summaries replaced by a consented view of the same record where possible (§6.7).
5. **Operations** as a shrinking exception service (§6.4).
6. **Documentation** as exception reporting (§6.5).
7. **NAVORA's own decision governance** (§7): the named Clinical Owner and advisers are the unlock, not more agents.

**Bottom line:** NAVORA is systematically redesigning **coordination**, and partly redesigning **control** by making it structural. It is at risk of digitising **assessment and quality**, especially in the nursing-home proposals. The correction is to build the evidence layer and the decision rules around licensed instruments, never the instruments themselves, and to retire human controls only through a measured parallel run.
