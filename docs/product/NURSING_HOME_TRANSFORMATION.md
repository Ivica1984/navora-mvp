# NAVORA Nursing Home Transformation Report

**Owner:** Product Owner (`po`) · **Stand:** 2026-10-22 14:45 · **Status:** strategic analysis. Nothing in this report is approved for building. The derived capabilities are drafts (NH1–NH3 in `docs/agents/NEXT_CAPABILITY.md`) and wait for decisions D-13 and D-24 to D-27.

## Source, method and labels

- **Source:** BESA QSys, *interRAI LTCF CH: Umsetzungsempfehlung Schweiz für die relevanten Pflegeaufwandgruppen (PAG)- und medizinischen Qualitätsindikatoren (MQI)-Items*, edition 30.08.2024. Pages 1–63 of 80 were provided. Pages 64–80 are missing, including the content of the Swiss-QI sheet.
- **How it is read:** not as an assessment specification, but as a description of how Swiss nursing homes organise assessment, documentation, quality control and financing today.
- **Labels:**
  - **SOURCE** (p. n): stated in the handbook.
  - **DERIVED:** arithmetic on source figures.
  - **ASSUMPTION:** common practice that the source does not describe; to verify with a pilot home.
  - **PROPOSAL:** NAVORA's design answer.
- **Boundaries:**
  - The handbook is licensed material. This report re-implements, changes or simplifies **no** PAG, CAP, scale, MQI or LTCF logic.
  - Every item code is quoted only to locate a responsibility.
  - The PO makes no clinical, legal or tariff judgement. Those are routed to their owners (D-13, D-24 to D-27).

---

## 1. Current operating model

### 1.1 The financing chain explains the organisation

| Step | What happens | Source |
|---|---|---|
| Assessment | interRAI LTCF CH, coded in the licensed software RAIsoft | p. 3, p. 50 |
| Classification | the coded items determine a care-effort group (PAG) with a CH-Index | p. 55 to 58 |
| Financing | each PAG maps to one of 12 tariff levels of care financing (1-a to 12-l) | p. 55 (sheet 5.30); a D/N variant on p. 60 (meaning of "D/N" not stated: UNKNOWN) |
| Control | administrative contracts between the associations (CURAVIVA, senesuisse) and the insurers regulate the processes, including the insurers' control of the providers | p. 3 |
| Change | a status change that raises the tariff level requires a full observation period. An expected **lower** level may be changed directly in RAIsoft with traceable documentation | p. 3 |

**Finding.** The assessment is the billing basis for nursing-home care, so most of the organisation around it exists to produce and defend **evidence for a classification that insurers control**. Care planning (CAPs) is the second purpose. This is the root cause of the hierarchy described below.

### 1.2 The assessment cycle

| Element | Rule | Source |
|---|---|---|
| Frequency | within the home's deadline of 180 or 270 days (90 for a short stay), plus every significant status change | p. 3, p. 50 |
| Observation period | 7 days (3 for a short stay) | p. 50 |
| Assessment phase (days 1–4) | *focus conversation* between the LTCF coordinator and the resident, done by the primary nurse where primary nursing is used; *focus meeting* (interdisciplinary, as a case conference or within the handover meeting); *planning conversation* between supervisor and coordinator, ideally on day 4 | p. 4 |
| Documentation phase (3 days) | entries on the PAG-relevant items: the status on day 1 and every change on the following days. "As in the care plan" is not accepted as an entry | p. 4 to 5 |
| ADL documentation | support level per episode, judged on the individual sub-steps of preparation, execution and follow-up | p. 18 to 20 |
| Signatures | everyone involved signs. Needs determination must be done by a registered nurse (KLV Art. 8a and the contracts); a coordinator who is not a registered nurse needs the delegating nurse's signature too. The result goes to the physician for information, and the physician signs the needs-report form | p. 49 |

### 1.3 Documentation principles

**SOURCE:**
- The care process is mandatory, and the care plan must be written and traceable. Care is assumed to be delivered as planned **without** a confirming entry: the care report is a **deviation report** (p. 3).
- **Exception:** in the documentation phase, delivery must be shown by entries (p. 4 to 5).
- Programmes such as a toilet plan, repositioning, or measures for mood, behaviour and dementia symptoms only count when a written care plan exists with problems, goals, measures and evaluation (p. 42 to 45). Behaviour measures are evaluated after 3 months at the latest (p. 44).
- Evaluation must be planned regularly because of the KVG Art. 32 criteria: effective, appropriate, economical (p. 3).
- Physician and APN visits (O6) and order changes (O7) are counted over 14 days and indicate clinical complexity (p. 46 to 47). Freedom-restricting measures (O8) are recorded together with whether the legal conditions are met (p. 47 to 48).

**Finding.** The same care is documented twice in two modes: as a plan with deviations (daily), and as positive evidence (in the documentation phase). The second mode exists only for classification and control.

### 1.4 The instrument's own organisation chart (SOURCE)

```text
Heimleitung (overall responsibility for the interRAI system)        p. 49, 51
  └ Leitung Betreuung und Pflege (supports the expert)              p. 52
      └ LTCF expert, 1 per institution: implementation, sample
        control, insurer controls, quality steering group           p. 51 to 53
          └ LTCF supervisors, registered nurses, 1 per 16 residents:
            correct PAG, care plans, control of entries             p. 50 to 51
              └ LTCF coordinators, 1 per 8 residents: plan the
                period, code, check                                 p. 49 to 50
                  └ care team, primary nurse, night shift,
                    therapists, physicians                          p. 4, 44 to 50
Quality steering group (interprets LTCF-QI and MQI)                 p. 52
```

Training is required for every role: a 2-day coordinator course by a licensed trainer; a supervisor course; an expert course with exam and yearly updates (p. 49 to 53).

**Not described in the source** (ASSUMPTION; verify with a pilot home): ward leaders and their daily tasks (the source names only "departments", p. 43 and p. 52), rostering, admission and discharge coordination, and the billing office.

---

## 2. Administrative burden analysis

| Activity | Who today (source) | Why it exists | Value for the resident | Verdict |
|---|---|---|---|---|
| Plan the observation period and the documentation phase (who documents what, on which day) | coordinator with supervisor (p. 50) | classification needs disciplined evidence | indirect | **Automate** (agent proposes, team confirms) |
| Focus conversation | coordinator or primary nurse (p. 4) | relationship and the resident's own view | **high** | **Keep**, always by the primary nurse |
| Focus meeting, planning conversation, final meeting | coordinator, supervisor, team (p. 4, p. 50) | bring scattered observations together | partly | **Replace** with one shared record and one short team decision |
| Documentation-phase entries | care team (p. 4 to 5) | prove the support level to the insurer | duplicates the care plan | **By-product** of structured care records (NH2; D-27) |
| Code the assessment form | coordinator (p. 50) | classification and care planning (CAPs) | needed | **Keep human coding**, prefilled from records (D-24) |
| Control the codings: supervisor periodically, expert by sample | supervisor, expert (p. 50 to 52) | a control of the control, against insurer findings | none directly | **Automate** the traceability check |
| Represent the PAG in insurer controls | expert (p. 52) | defend the classification | none | **Generate** the evidence pack |
| Watch the ADL index and initiate status changes | coordinator, supervisor (p. 50 to 51) | reassess on time | **high** (care follows need) | **Signal** to the primary nurse (NH3; D-26) |
| Build and evaluate the care plan from CAPs | supervisor with the team (p. 51) | care quality | **high** | **Team-owned**; evaluation dates tracked by software |
| Interpret quality indicators | expert, quality steering group (p. 52 to 53) | quality development | high if it reaches the team | **Signals to the team** (NH3) |
| Signatures, nurse countersignature, information to the physician | all; registered nurse; physician (p. 49) | legal duty (KLV Art. 8a) | safety and accountability | **Keep**, as one digital step each |
| Count physician/APN visits, order changes, restraint context | coordinator (p. 46 to 48) | complexity and legal protection | high (restraints) | **Capture as events** when they happen |

**DERIVED: size of the burden for a 64-resident home.**
- **Role-holders** at the recommended ratios: 8 coordinators, 4 supervisors and 1 expert, all of them care staff with assessment duties. Their time share is not stated (UNKNOWN).
- **Periodic observation periods:** 64 × 365 ÷ 270 ≈ 87 to 64 × 365 ÷ 180 ≈ 130 per year, before any status change.
- **Meetings:** each period has at least three coordination talks (focus meeting, planning conversation, final meeting). That is about **260 to 390 meetings a year**, and 7 days of evidence-driven documentation per resident and period.
- **Baseline needed:** the minutes per period are not in the source. The first step of the roadmap is to measure them in the pilot home, not to assume them.

---

## 3. Hierarchy analysis

The seven questions per role: (1) why does it exist, (2) which problem does it solve, (3) is it still necessary, (4) can it be automated, (5) can a self-organised team take it over, (6) can an AI agent do it, (7) can it disappear?

| Role | (1) Why it exists | (2) Problem solved | (3) Still necessary? | (4) Automate | (5) Team | (6) Agent | (7) Disappears? |
|---|---|---|---|---|---|---|---|
| **Nursing-home director** (Heimleitung; SOURCE p. 49, 51) | licence holder; overall responsibility, including for the interRAI system | accountability to canton, insurers and employees | **accountability yes**; management of care no | resource and compliance reporting | staffing and daily operations go to ward teams | compliance monitor | **as a hierarchy, yes.** A small accountable governance function stays: licence, finances, safety escalation |
| **Care managers** (head of care; SOURCE p. 52 by name, tasks ASSUMPTION) | professional oversight, standards, staffing | quality and staffing across wards | professional responsibility yes, possibly cantonal (UNKNOWN, route with D-11) | standards as configuration | staffing and standards inside the team | prepares signals | **as a line role, yes.** Replaced by a signal-driven coach and a network of clinical experts |
| **Ward leaders** (ASSUMPTION) | roster, daily allocation, handover, escalation, staff talks | coordination of a ward | **no** | handover from the record (HAND1); exceptions (OPS1) | roster, allocation, admissions (NH1) | roster proposal | **yes** |
| **LTCF coordinators** (SOURCE p. 49 to 50; 1 per 8) | plan the observation period; code; check | classification needs disciplined evidence | **coding yes, planning no** | planning the period | coding by the **primary nurse**, who knows the resident; a registered nurse signs (KLV 8a) | plans the period, prefills, checks completeness | **yes, as a separate role.** The competence moves into the team |
| **LTCF supervisors** (SOURCE p. 50 to 51; registered nurses, 1 per 16) | correct PAG; care plans from CAPs; control of entries | risk of misclassification and insurer findings | **the registered-nurse responsibility yes; the control layer no** | traceability check | care-plan evaluation in the team | traceability agent | **yes, as a layer.** The registered-nurse duty stays inside the team |
| **LTCF expert** (SOURCE p. 51 to 53; 1 per institution) | institution-wide correctness; insurer controls; QI; training | specialised knowledge | **the knowledge yes; one per home no** | evidence pack, QI preparation | – | evidence-pack agent | **per home, yes.** It becomes a network specialist serving many homes, called by signals |
| **Quality managers** (SOURCE: quality steering group, p. 52) | interpret QI and MQI; quality development | quality improvement | the function yes; the meeting no | QI calculation and statutory export (licensed, D-24) | the team owns its signals (NH3) | quality-signal agent | **largely.** A quality specialist is called on demand |
| **Scheduling administrators** (ASSUMPTION) | roster across wards | staffing | no | rule checks (skill mix from the canton and `clinical`, not invented) | self-rostering (NH1) | roster proposal | **yes** |
| **Intake coordinators** (ASSUMPTION) | admission, waiting list, contract, cost guarantee | access and financing | the contract and financing check yes | financing check | the team accepts the resident (J2 pattern) | transition agent | **largely.** A small contract function stays |
| **Discharge coordinators** (ASSUMPTION) | transfers to hospital and back | transitions | no | transfer summary from the record | the resident's team keeps the place (RET1 pattern) | transition agent | **yes** |

**What does not disappear** (SOURCE or legal):
- needs determination by a registered nurse, and information to the physician (KLV Art. 8a, p. 49);
- the legal conditions for freedom-restricting measures (p. 47 to 48);
- the licensed instrument and its trained use (p. 49 to 53, D-24);
- anonymised data exports, with no names in free text (p. 3);
- one accountable licence holder.

---

## 4. Automation opportunities (deterministic, no AI)

1. **Assessment calendar:** deadlines (180 or 270 days, 90 for a short stay), due dates and overdue items computed per resident. Today they are tracked by coordinators.
2. **Observation-period plan:** the days and the documentation tasks generated from the care plan and the roster, inside the team's own day view. The coordinator's planning task goes.
3. **One record, two uses:** support given during care is captured as structured events (who, when, which ADL episode, support given). The documentation phase becomes a filtered view of what was recorded anyway (NH2). Whether the insurers accept this is D-27.
4. **Traceability check:** for each coded item that needs documentation, show whether supporting entries exist in the period. It shows presence, never whether the coding is correct, so no PAG logic is touched.
5. **Evidence pack for insurer controls:** a generated, time-stamped extract per resident and period.
6. **Events, not counting:** physician and APN visits, order changes and freedom-restricting measures are recorded once, as events, when they happen.
7. **Signatures and physician information:** one digital step each, with the registered-nurse countersignature where KLV 8a requires it.
8. **Billing facts for nursing homes:** tariff level × days, taken from the coded result of the licensed software, with residents' and cantonal shares only once known (D-11, D-12). This is the J5 pattern.

## 5. AI agent opportunities

These follow the Architecture Handbook: AI produces hints and never changes hard rules; a human decides; the approved state cannot be changed afterwards.

| Agent | Takes over | Human decision point | Guardrail |
|---|---|---|---|
| **Observation-period planner** | coordinator planning | primary nurse confirms the plan | never codes |
| **Documentation assistant** (Gate 4) | writing deviation notes from structured events and voice | nurse confirms every entry | no invented observations; source shown |
| **Status-change sentinel** | coordinator and supervisor watching the ADL index | primary nurse decides on reassessment | criteria from `clinical` only (D-26); suggests, never decides |
| **Coding prefill** | blank-form coding | coder codes, registered nurse signs | only with a licence and validation (D-24); every prefilled value shows its evidence |
| **Traceability and audit-readiness** | supervisor and expert controls | team fixes the gaps | presence check only |
| **Quality signals** | QI interpretation in the steering group | team chooses its action | uses licensed indicator outputs (D-24); never ranks individual nurses |
| **Roster and cover** | scheduling administrator | team approves | skill-mix rules from the canton and `clinical` |
| **Transition** | intake and discharge coordinators | receiving team accepts | data minimisation (D-9) |
| **Physician loop** | phoning practices for orders and visits | physician confirms | the valid form is a legal question (D-22) |

## 6. Team autonomy opportunities

**A ward team decides itself:**
- its roster and daily allocation;
- the primary nurse for each resident;
- the acceptance of new residents within capacity;
- the care plan and its evaluation;
- the assessment coding, signed by its registered nurse (KLV 8a);
- cover from neighbouring wards;
- its quality-improvement actions.

**Outside the team:** the licence, verified qualifications, clinical and legal rules, financing contracts, and transparent team economics (J7, D-14).

**The coach** is called by signals (OPS1, AN1, NH3), as in home care. The coach is not a manager.

## 7. Buurtzorg comparison

Buurtzorg is a **home-care** model (sources in `CARE_OPERATING_MODEL.md`). This repository has no verified source for a Buurtzorg nursing-home model (UNKNOWN), so the comparison is of principles.

| Dimension | Current LTCF model (SOURCE or ASSUMPTION) | Buurtzorg principle | NAVORA design (PROPOSAL) |
|---|---|---|---|
| Hierarchy | director, head of care, ward leader, plus a parallel assessment chain (expert, supervisor, coordinator) | no managers; teams of about 10–12; coaches | ward teams; network specialists; coach on signals |
| Assessment | evidence written separately, coded by trained coordinators, controlled twice | nurses assess and document themselves | primary nurse assesses; evidence is a by-product; software checks traceability |
| Coordination | three meetings per observation period | team meetings | one shared record; one team decision |
| Quality | steering group interprets indicators | team reflection | signals to the team, with specialists on demand |
| Scaling | specialist roles per home (1:8, 1:16, 1 per home) | coaches about 1:47 teams | specialists per network, not per home |
| Transitions | coordinators by phone | not addressed | resident's team kept; digital referral both ways |

## 8. How NAVORA can surpass Buurtzorg

1. **Evidence as a by-product.** Buurtzorg removed managers but kept the nurse's paperwork. NAVORA removes the separate evidence-writing, because the care record is structured, time-stamped and cannot be changed afterwards (as F1–F4 already are).
2. **Specialists per network, not per home.** One LTCF expert can serve many homes when signals bring the cases to her. That is impossible in a stand-alone home.
3. **Continuity across settings.** Home care, hospital and nursing home share one care history and one team logic: RET1, REF2 and HAND1 apply unchanged.
4. **Signals instead of meetings.** Status changes and quality issues reach the responsible nurse when they appear, not at the next meeting.
5. **Fair income without perverse incentives.** In nursing homes the classification drives revenue. If team income followed the PAG directly, teams would have a reason to classify upward. **Guardrail (PROPOSAL for D-14):** team income follows direct care, continuity and quality, not the classification level. The traceability check also shows tariff increases that the records do not support.

## 9. Required new capabilities

Drafts. Each waits for D-25 (owner: enter nursing homes) plus the decisions listed.

| ID | Capability | Layer replaced | Manual activity removed | Role less necessary | Continuity | Direct care time | Income potential | Decisions |
|---|---|---|---|---|---|---|---|---|
| **NH1** | The ward team organises itself: roster, allocation, admission acceptance, cover between wards, handover from the record | ward management, scheduling | rostering, allocation, handover meetings | ward leader, scheduling administrator | primary nurse per resident, informed cover | meeting and coordination time back to care | team keeps the value of its organisation (J7) | D-25 |
| **NH2** | Assessment as a by-product of care: assessment calendar, generated observation-period plan, documentation phase as a view of structured care records, traceability check, evidence pack, data exchange with the licensed software | the assessment control chain | planning the period, duplicate evidence entries, control sampling, insurer-control preparation | LTCF coordinator, supervisor and expert as separate roles | the primary nurse assesses her own resident | the largest single administrative block goes | classification stays correct without overhead | D-13, D-24, D-27 |
| **NH3** | Signals go to the team: status-change suggestions and quality indicators for the primary nurse and the team; restraint context visible | quality management, status-change monitoring | ADL-index monitoring, steering-group preparation | quality manager, supervisor | reassessment when the need changes, not when the calendar says so | fewer review meetings | quality as a basis for income (D-14) | D-24, D-26 |

**Reused without change of principle:**
- PLAN2: the care plan drives the work; shift-level planning comes with NH1.
- HAND1: handover from the record.
- COVER1: cover between wards.
- RET1 and REF2: transitions.
- ORD1: the physician loop.
- QG1: quality events.
- J5: billing facts.
- AN1: measurement.
- J6: the primary nurse.

## 10. Required new agents

Covered in section 5. Order of introduction:
1. the observation-period planner;
2. the traceability and audit-readiness agent;
3. the status-change sentinel (needs D-26);
4. the quality-signal agent (needs D-24);
5. the documentation assistant (Gate 4).

The coding-prefill agent comes last, and only with a licence and a clinical validation.

## 11. Transformation roadmap

| Phase | Content | Exit criteria |
|---|---|---|
| **0: decide and measure** | D-25 (enter, partner, ward), D-13 and D-24 (instrument and licence), D-27 (evidence form), D-26 (signals). **Baseline** in the partner home: minutes per observation period, meetings per period, FTE in coordination and assessment roles, direct care share | baseline measured, not estimated |
| **1: one ward organises itself** (NH1) | roster, allocation, handover from the record, cover, quality events, exceptions. The assessment process is unchanged | no ward-leader allocation for 3 months; direct care share up; no safety signal worse |
| **2: assessment as a by-product** (NH2) | calendar, generated observation plan, documentation view, traceability check, exchange with the licensed software | documentation minutes per period down against the baseline; insurer-control findings **not** higher; coding still human, signed by a registered nurse |
| **3: signals and network specialists** (NH3) | status-change suggestions, QI to the team, one LTCF expert serving several homes | reassessment lead time down; specialist roles per resident down |
| **4: integrated network** | home care, hospital and nursing home on one care history; transitions without coordinators | returning residents keep their team; transfer information without re-typing |

**Stop rule:** if any phase worsens a safety signal (QG1, restraints, falls, pressure injuries) or raises insurer findings, it is rolled back. Patient safety is a precondition.

## UNKNOWN and next questions

- Pages 64–80 of the handbook, including the Swiss-QI sheet.
- Tariff amounts per level and the cantonal shares (D-11, D-12).
- Minutes per observation period (Phase 0 baseline).
- What ward leaders and care managers actually do in the pilot home.
- The meaning of the "D/N" variant (p. 59 to 62).
