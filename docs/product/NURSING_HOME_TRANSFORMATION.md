# NAVORA Nursing Home Transformation Report

**Owner:** Product Owner (`po`) · **Date:** 2026-10-22 · **Status:** strategic analysis (PLANNED). It is not an approved build: every capability below is a proposal gated by D-13, D-24 and D-25.
**Horizon:** 3 in [`CARE_OPERATING_MODEL.md`](CARE_OPERATING_MODEL.md) (nursing homes), after home care and transitions of care.

## How to read this report

**Primary source.** *interRAI LTCF CH — Umsetzungsempfehlung Schweiz für die relevanten PAG- und MQI-Items*, BESA QSys, edition 30.08.2024. The owner uploaded pages 1–63 of the 80-page document. Citations use its page numbers: "QSys p. 50".

**Reading the source as an organisation chart.** Following the owner's instruction, the handbook is read as a description of how Swiss nursing homes organise themselves today, not as an assessment specification. Its roles, ratios, meetings and control loops are the evidence.

**Status labels (`CLAUDE.md`):**
- **IMPLEMENTED:** exists in NAVORA today.
- **PLANNED:** proposed here.
- **OPEN:** needs a decision.
- **UNKNOWN:** not in the source, so it must be verified before anything depends on it.

**What this report does not do:**
- It does not reproduce or reinterpret PAG, MQI or LTCF calculation logic. Building any of it needs the licensed specification (D-24).
- It invents no clinical, legal or tariff rule. Where the source states a legal duty, it is quoted with its page.

**Roles the source does not describe:** ward leaders, care managers, quality managers as a job, scheduling administrators, and intake and discharge coordinators. For these the report gives the PO's operating-model reasoning, marked **UNKNOWN (not in source)**. Pilot interviews must confirm how they work today.

---

## Executive summary

**The finding.** A large part of a Swiss nursing home's hierarchy exists to **classify residents for payment and to defend that classification**. Caring for residents is a smaller part of it.

The source recommends a dedicated three-level structure just for the assessment system:
- one LTCF coordinator per 8 residents;
- one LTCF supervisor per 16 residents;
- at least one LTCF expert per institution;
- the home director, who carries overall responsibility.

For a 96-bed home that means 12 coordinators, 6 supervisors and at least one expert (QSys pp. 49–52). The structure:
- plans 7-day observation periods;
- decides who documents what on which day;
- codes, then checks the coding;
- samples the coding for audit;
- defends the result in insurer controlling.

**The challenge.** This apparatus exists because of three things:
- assessment is periodic;
- evidence is collected as a project;
- correctness is checked after the fact by a layer of people.

If care documentation is continuous, carries its source, and is structured at the moment of care, then the observation period becomes a confirmation rather than a project. The checking also becomes software.

**What is left.** The legally required core. A registered nurse (*dipl. Pflegefachperson*) determines the need and signs it, and the physician is informed (KLV Art. 8a, quoted at QSys p. 49). That core stays with the resident's primary nurse in a self-organised ward team. Everything around it can largely disappear.

**The proposal:**
- Ward leadership is replaced by self-organised ward teams.
- The assessment hierarchy is replaced by an evidence layer, AI drafting and a small shared pool of network clinical experts.
- Rostering is replaced by team self-planning of shifts.
- Handover meetings are replaced by the record (HAND1).

**The money.** The time freed from coordination and control goes to residents and to nurse pay. AN1 measures this, and pay follows the D-14 model.

---

## 1. Current operating model

### 1.1 Structure described by the source

```
Krankenversicherer ── Administrativverträge (CURAVIVA, senesuisse) ── control of providers (p. 3)
        │
Heimleitung (home director): overall responsibility for the interRAI LTCF system;
        │                    ensures enough coordinators are trained; provides resources (pp. 49–51)
Leitung Betreuung und Pflege (head of care): supports the LTCF expert (p. 52)
        │
Qualitätssteuerungsgruppe (quality steering group): interprets LTCF-QI and MQI; the expert is a member (pp. 52–53)
        │
LTCF-Expertin (≥1 per institution, by size): institution-wide responsibility for correct use;
        │      sample audits of PAG-relevant codings; reviews RUG lists of all departments;
        │      represents the PAG in insurer controlling; trains (pp. 51–53)
LTCF-Supervisorin (1 : 16 residents, registered nurse): correct PAG; care planning with the team from CAPs and scales;
        │      evaluates care plans; checks quality and quantity of documentation entries;
        │      monitors that significant status changes are started (pp. 50–51)
LTCF-Koordinatorin (1 : 8 residents): chooses the form and sets the assessment date (180 or 270 days, 90 for short stay);
        │      plans the 7-day (3-day) observation period; plans who documents which items on which day;
        │      leads case discussions; codes in RAIsoft; watches the ADL index for status changes (pp. 49–50)
Pflegeteam / Bezugspflegeperson, Nachtwache, therapists: observe and document (pp. 4, 50)
Arzt / Ärztin, Pflegeexpertin APN-CH: visits, orders; physician receives and signs the needs report (pp. 46–47, 49)
```

### 1.2 The assessment cycle (QSys pp. 3–5, 49–50)

1. **Trigger.** A due date (every 180 or 270 days; 90 days for short stays), or a **significant status change** that would change the care-dependency group (PAG) and the tariff level.
   - A change **upward** needs a full regular observation period.
   - A change **downward** may be entered directly with traceable documentation (p. 3).
2. **Assessment phase (days 1–4):**
   - a focus conversation with the resident;
   - a focus meeting of the team, either as a case discussion or within the *Rapport*;
   - a planning meeting between supervisor and coordinator, ideally on day 4.
3. **Documentation phase (days 5–7):** every PAG-relevant item is documented at least once, **even when stable**, because "it must be confirmed by a documentation entry" (p. 4). PAG-relevant items may only be coded after this phase.
4. **Coding, check and signature.**
   - The coordinator codes and checks.
   - Every person involved signs.
   - If the coordinator is not a registered nurse, the delegating registered nurse co-signs.
   - The physician signs the needs report (*Bedarfsmeldeformular*), not the assessment form (p. 49).
5. **Result.** A PAG with a CH-Index and a tariff level from 1 (a) to 12 (l) (Merkblatt pp. 55–62). Billing data follow the administrative contract with the insurers (p. 3).

### 1.3 Responsibilities by domain

| Domain | Who holds it today | Source |
|---|---|---|
| Organisational structure | Home director; head of care; departments (*Abteilungen*) | pp. 49–52 |
| Hierarchy | Director → head of care → LTCF expert → supervisors → coordinators → team | pp. 49–53 |
| Planning (care) | Supervisor with the team, from CAPs and scales; evaluation at least every 3 months for special measures | pp. 44, 51 |
| Planning (assessment work) | Coordinator: dates, observation period, who documents what | p. 50 |
| Planning (staff rosters) | **UNKNOWN (not in source)** | – |
| Quality management | Quality steering group; expert interprets QI and MQI; supervisor checks documentation | pp. 51–53 |
| Assessment | Coordinator codes; supervisor checks the PAG; expert samples; registered nurse signs (KLV Art. 8a) | pp. 49–52 |
| Documentation | Whole team. The care report is an **exception report**: care delivered as planned needs no entry, except PAG items during the documentation phase | pp. 3–4 |
| Coordination | Coordinator involves night staff, therapists and physicians; case discussions and *Rapport* | pp. 4, 50 |
| Billing | Tariff level from the PAG; administrative contracts; insurer controlling, defended by the expert | pp. 3, 52, 55 |

**What the source gets right (keep it).**
- The care report is an exception report: "not proof of delivery" (p. 3).
- The source recommends that the primary nurse does the assessment where primary nursing exists (p. 4).
- It recommends a relationship-first focus conversation instead of a checklist (p. 4).

NAVORA builds on these three principles. It does not replace them.

---

## 2. Administrative burden analysis

**Derived from source ratios only; minutes are UNKNOWN and must be measured.**

| Driver | What the source requires | Volume for 96 residents (derived) | Nature |
|---|---|---|---|
| Periodic reassessment | every 180 or 270 days, each with a 7-day observation period | about 130–195 observation periods a year; about 2.5–3.7 running at any time | classification work |
| Documenting stable items | PAG items documented once in the 3-day phase even if unchanged | each item once per period | evidence for payment, not for care |
| Planning the observation | who documents which item on which day; involving night staff, therapists, physicians | per period | coordination |
| Meetings | focus meeting, planning meeting, closing meeting | 3 per period | coordination |
| Coding and checking | coordinator codes; supervisor checks PAG and documentation; expert samples; RUG lists per department | per period, plus periodic reviews | control |
| Status change | upward: a full new period; downward: direct edit | event-driven | tariff control |
| Insurer controlling | expert defends the PAG | per control | defence |
| Training and certification | 2-day coordinator course; supervisor course; expert exam with yearly updates | 12 + 6 + ≥1 people | system upkeep |

**The asymmetry is telling.** A higher tariff needs a full observation period. A lower tariff needs only a documented edit (p. 3). The process is built to **control payment risk**. Clinical change runs in both directions, so this design is not about care.

**Benchmark need (OPEN).** Public studies on Swiss nursing homes report rising rationing of care activities ([SHURP](https://shurp.unibas.ch/wp-content/uploads/2022/07/Webpage-SHURP_SBK-Kongress-Mai-2022_Steigende-Rationierung-von-Pflegetätigkeiten_ARenner.pdf)). This report does not use a percentage of time spent on assessment documentation, because none is in hand. The pilot measures it with AN1, by direct care share per shift.

---

## 3. Hierarchy analysis

Each role gets seven answers: why it exists, what problem it solves, whether it is still necessary, whether software can automate it, whether a team can take it, whether an AI agent can draft it, and whether the role can disappear.

| Role | Why it exists | Problem it solves | Still necessary? | Automate? | Delegate to team? | AI agent? | Can it disappear? |
|---|---|---|---|---|---|---|---|
| **Home director** (*Heimleitung*) | Legal and economic accountability; overall responsibility for the LTCF system (p. 51) | Someone answers to canton, insurers and residents | **Yes as an accountable licence holder** (cantonal requirements UNKNOWN, D-25); no as an operational manager | Reporting, budgets, compliance evidence | Daily operations, staffing, care organisation | Prepares accountability reports and flags risks | **Shrinks** to licence holder, host (building, hotel services) and steward of the operating model |
| **Ward leader** (*Stations-/Abteilungsleitung*) | UNKNOWN (not in source). Typically rosters, handover, deployment, first escalation, staff conduct | Coordination of a shift-based unit | **No**, as a layer | Rosters (PLAN2 for shifts), handover (HAND1) | Yes: the ward team plans, decides and admits members (D-20 pattern) | Proposes the roster, flags gaps, offers cover (COVER1) | **Yes.** A self-organised ward team with rotating roles; a coach on call, not in line |
| **Care manager / head of care** (*Leitung Betreuung und Pflege*) | Professional standards; supports the expert (p. 52) | Clinical governance across wards | **The function yes, the line role no.** A cantonal licence may require a named nursing lead (UNKNOWN, D-25) | Standard checks, evidence of compliance | Team practice decisions | Monitors quality signals across wards | **Becomes a network clinical lead** shared across homes; not a line manager of teams |
| **LTCF coordinator** (1 : 8) | Someone must run the observation project and code it (pp. 49–50) | Periodic, project-style evidence collection | **The task yes** (legal need assessment); **the separate role no**. The source itself prefers the primary nurse (p. 4) | Due dates, period planning, "who documents what", reminders | Primary nurse does the assessment as part of her residents' care | Drafts the period plan and the coding from documentation, with its source; a nurse confirms | **Yes as a role.** The work becomes about 1 hour of confirmation by the primary nurse instead of a project (to be measured) |
| **LTCF supervisor** (1 : 16, registered nurse) | Correct PAG; documentation quality; care plans from CAPs; status-change watch (pp. 50–51) | Errors and unsupported codes that insurers reject | **Partly.** The clinical care-planning part stays with the team; the **checking** part is a control layer | Evidence completeness ("every PAG item has a documentation entry in the window"), plausibility, status-change signals | Care planning and its evaluation with the team | Pre-review of every coding before signature | **Yes as a layer**; a few registered nurses keep clinical lead duties in their teams |
| **LTCF expert** (≥1 per institution) | Institution-wide correctness, audits, insurer controlling, training (pp. 51–53) | Payment defence and system knowledge | **Yes, but not per institution** | Sample audits become full automated audits; controlling evidence packs | – | Assembles the evidence pack for a controlling case | **Becomes network-level**: one expert pool across many homes |
| **Quality manager** (job), **quality steering group** | Interpret QI and MQI; steer improvement (pp. 52–53) | Turning indicators into action | **The function yes, the separate layer no** | QI and MQI from routine data, continuously (with licensed definitions) | Teams review their own indicators monthly (as in AN1) | Explains changes and proposes where to look | **Largely.** Teams own their quality; a network quality council handles rare cross-home issues |
| **Scheduling administrator** | UNKNOWN (not in source). Rosters for 24 h coverage | Coverage, qualification mix, labour rules | **No** | Roster generation within the rules | The team approves and swaps | Proposes rosters and swaps; finds cover in the network | **Yes** |
| **Intake coordinator** | UNKNOWN (not in source). Waiting list, admission paperwork, financing questions | First contact for families and hospitals | **Partly**: contracts and financing questions need a human | Structured referral (REF2), document checklist | The receiving ward team decides on admission fit (J2 pattern) | Pre-fills the admission from referral documents; a human confirms | **Mostly.** A small admissions service may remain for contracts and financing |
| **Discharge coordinator** | UNKNOWN (not in source). Transfers to hospital, return home after short stays | Information loss at transitions | **No as a role; yes as a duty** | Transfer packet from the record (HAND1); return path (RET1) | The primary nurse owns the transition | Drafts the transfer summary; a nurse confirms | **Yes** |

**Hierarchy count, 96-bed home.** The visible hierarchy runs from the team through coordinators, supervisors, expert, head of care and director: up to five levels above the nurse at the bedside. Ward leadership is UNKNOWN in the source and would add one more.

**NAVORA target: two levels.**
1. **The ward team.**
2. **An accountable licence holder** supported by network-level experts. The experts are not line managers.

---

## 4. Automation opportunities

The rule throughout: **software does the bookkeeping, a registered nurse decides and signs.**

| Today | Automated | Status |
|---|---|---|
| Coordinator sets dates (180, 270 or 90 days) | Due dates calculated and shown to the primary nurse and team | PLANNED (NH3) |
| Coordinator plans "who documents which item on which day" | Not needed when documentation is structured at the moment of care. The system shows which PAG items still lack an entry in the window | PLANNED (NH2, NH3). Item list from the licensed spec only |
| Supervisor checks documentation quality and quantity | Automatic completeness check before signature: each coded item links to its entries | PLANNED (NH4) |
| ADL-index watch for status change | Signal when the documented support pattern changes, so the nurse decides whether to start a status change | PLANNED (NH5). Calculation from the licensed spec only |
| Expert's RUG list reviews and sample audits | Full, continuous audit report per ward | PLANNED (NH6) |
| Insurer controlling defence | Evidence pack per resident: codes, linked entries, signatures, dates | PLANNED (NH6) |
| QI and MQI preparation for the quality steering group | Indicators computed from routine data per ward and month | PLANNED (NH7). Licensed definitions only |
| Rosters | Shift plan generated from the residents' care plans and the qualification mix | PLANNED (NH1, extends PLAN2) |
| *Rapport* (shift handover meeting) | "Since your last shift" on each resident card | PLANNED (reuses HAND1) |

---

## 5. AI agent opportunities

AI drafts; a named, qualified person confirms. No agent signs, codes into a billing system or changes a care plan by itself. AI never decides a clinical rule. Agents run inside NAVORA's team-scoped access and audit (F0).

| Agent | Replaces the work of | Does | Human in the loop | Guardrails |
|---|---|---|---|---|
| **Observation agent** | coordinator (period planning) | Watches due dates and missing evidence; tells the primary nurse what is still unconfirmed | primary nurse | reads only the ward's residents |
| **Coding draft agent** | coordinator (coding) | Proposes item codes **with the source entries for each**; marks what it cannot support | registered nurse confirms and signs (KLV Art. 8a) | licensed item definitions only; never codes without an entry |
| **Coherence agent** | supervisor (checking) | Finds codes without evidence, contradictions and stale items before signature | the signing nurse | flags only; cannot change codes |
| **Status-change sentinel** | coordinator and supervisor (ADL watch) | Signals a sustained change in documented support | primary nurse decides whether to start a status change | **raises upward and downward changes alike** (removes the payment asymmetry from the care view) |
| **Controlling agent** | expert (defence) | Assembles the evidence pack for an insurer question | expert or licence holder sends it | read-only; audited |
| **Quality insight agent** | quality manager | Explains indicator changes per ward | ward team | aggregates only; no ranking of individual nurses (J6 rule) |
| **Roster agent** | scheduling administrator, ward leader | Proposes the shift plan, swaps and cover | ward team approves | labour-law limits as configuration from `legal` |
| **Transition agent** | intake and discharge coordinators | Pre-fills admission from the referral; drafts transfer summaries | receiving nurse confirms | D-9 data basis |

---

## 6. Team autonomy opportunities

- **Ward team.** About 10–15 people (to be confirmed in the pilot). The team owns a group of residents around the clock: rosters, admissions fit, care plans, assessments, quality review and hiring of colleagues (the D-20 pattern).
- **Primary nurse per resident.** She does the assessment and signs it. This is already the source's own recommendation (p. 4), and it makes the 1 : 8 coordinator role unnecessary.
- **Rotating team roles.** Roster, quality and training roles rotate. They are roles, not ranks, and are time-boxed.
- **Coach on call.** The coach is called by signals (OPS1, AN1), not by a reporting line. Buurtzorg runs about 1 coach per 47 teams in home care (`CARE_OPERATING_MODEL.md`).
- **Network experts.** Clinical leads, LTCF experts and specialists (wound care, palliative, dementia) are shared across homes and booked by teams.
- **Cross-home cover.** Staff shortages are covered from the network of qualified nurses (COVER1), not by agencies or a central dispatcher.

---

## 7. Buurtzorg comparison

| Dimension | Swiss nursing home today (source) | Buurtzorg (home care, Netherlands) | NAVORA target for nursing homes |
|---|---|---|---|
| Unit of organisation | Institution → departments → roles | Teams of about 10–12 nurses, about 50–60 clients each | Ward team owning a resident group 24/7 |
| Hierarchy | Director, head of care, expert, supervisors, coordinators | Teams, coaches, small back office | Team, plus an accountable licence holder and network experts |
| Assessment | Periodic project with a 7-day observation period | Assessment and documentation by the nurse (Omaha System) | Continuous evidence; periodic confirmation by the primary nurse |
| Control | People check people (supervisor, expert) | Trust plus outcome data | Software checks evidence; people decide |
| Coordination | Meetings: focus, planning, closing, *Rapport* | Team meetings, intranet | The record carries the knowledge (HAND1); meetings for decisions |
| Rosters | UNKNOWN (not in source) | The team plans | The team approves generated rosters |
| Scale limit | Staffing ratios grow with beds | Teams are islands; the coach carries absences and finances | Network-level experts, cover and data |
| Evidence | QI and MQI prepared for a steering group | Little systematic outcome data used for learning (`CARE_OPERATING_MODEL.md`) | Indicators per ward each month, owned by the team |

Sources for Buurtzorg: [Commonwealth Fund 2015](https://www.commonwealthfund.org/publications/case-study/2015/may/home-care-self-governing-nursing-teams-netherlands-buurtzorg-model), via `CARE_OPERATING_MODEL.md`. **UNKNOWN:** how Buurtzorg-style self-management performs in residential care. NAVORA holds no source on that, so the pilot is the evidence.

---

## 8. How NAVORA can surpass Buurtzorg

1. **Residential care is open ground.** Buurtzorg's proof is in home care. Applying self-managed teams to 24-hour wards, with software carrying the coordination, is where NAVORA can lead rather than follow.
2. **Assessment becomes a by-product of care.** Buurtzorg nurses still do their own administration. NAVORA turns everyday documentation into assessment evidence, so a registered nurse confirms instead of collecting.
3. **Control becomes software.** Buurtzorg relies on trust. NAVORA adds automatic, transparent evidence checks, which is what insurers and cantons need in order to trust teams without supervisors.
4. **The network instead of the island.** Experts, cover and quality learning are shared across homes and home-care teams. This is the integrated network of Horizon 4.
5. **The transition is the product.** One record from home care to hospital to nursing home and back (HAND1, RET1, REF2). Buurtzorg has no referral source of its own.
6. **The pay link.** Time freed from control layers is measured (AN1) and paid out under the D-14 model: more pay for more direct care, not for more hours.

---

## 9. Required new capabilities

All are PLANNED proposals. **None is approved.** Each needs D-13 and D-24. Any item marked *licence* also needs the licensed interRAI LTCF CH specification and reference cases (`DOMAIN_RULES.md`).

| ID | Capability | Replaces | Reuses | Gate |
|---|---|---|---|---|
| NH0 | **Ward-team operating model pilot.** Organisational change first: one ward, team-owned rosters, admission fit, *Rapport* replaced | ward leadership | – | D-24, D-25 |
| NH1 | Shift self-planning: 24 h roster from care plans and qualification mix; the team approves | scheduling administrator, ward leader | PLAN2, COVER1 | D-24; labour-law rules from `legal` |
| NH2 | Continuous evidence: structured observations at the point of care, each with its source, mapped to assessment items | coordinator's observation project | F1–F4 observations, HAND1 | licence |
| NH3 | Assessment cycle autopilot: due dates (180 / 270 / 90 days, p. 50), missing evidence, status-change trigger | coordinator | NH2 | licence |
| NH4 | Coding draft and signature: AI draft with source entries, coherence check, registered-nurse signature, physician needs report | coordinator, supervisor checks | F6 signature pattern | licence; `clinical` sign-off |
| NH5 | Status-change sentinel, symmetric (upward and downward) | supervisor watch | NH2 | licence |
| NH6 | Audit and controlling evidence pack | expert audits and defence | J5 provenance | licence; insurer contract (D-24) |
| NH7 | Ward quality indicators (QI and MQI) for the team each month | quality steering group preparation | AN1, QG1 | licence (MQI definitions) |
| NH8 | Network expert pool: book a clinical expert across homes | head of care, expert per home | COVER1 offer pattern | D-24 |
| NH9 | Restraint register (freedom-restricting measures): frequency, effect, context and legal conditions as recorded by the source (pp. 47–48); review dates | manual tracking | QG1 | **`legal` and `clinical`**: the legal conditions are not interpreted by NAVORA |

---

## 10. Required new agents

Implement in this order. Each one starts as a **draft-only** agent, and its acceptance error rate is measured before any wider use.

1. **Roster agent** (NH1): needs no licence; the fastest relief for teams.
2. **Transition agent** (REF2, RET1, HAND1): shared with home care.
3. **Observation agent** (NH3).
4. **Coding draft agent** and **coherence agent** (NH4).
5. **Status-change sentinel** (NH5).
6. **Controlling agent** (NH6).
7. **Quality insight agent** (NH7).

Every agent is measured with these fields:
- correction rate by the human;
- time saved per task;
- errors found later in controlling.

These become new rows in AN1 when the work is approved.

---

## 11. Transformation roadmap

| Phase | What changes | Software | Decision gates | Evidence of success |
|---|---|---|---|---|
| **0. Decide** | Choose the nursing-home horizon and a design partner home | none | D-13, D-24, D-25 | signed partnership; licence path known |
| **1. Organise** | One ward becomes a self-organised team: own rosters, primary nurse per resident, *Rapport* replaced by the record. The ward-leader role is suspended for the pilot | HAND1, PLAN2 by shift (NH1), COVER1 | D-25 (licence conformity) | AN1 direct care share per shift up; staff satisfaction; no rise in QG1 events |
| **2. Evidence** | Documentation at the point of care becomes assessment evidence | NH2 | licence | share of assessment items with an entry before the period starts |
| **3. Assessment without a hierarchy** | The primary nurse confirms the AI draft; supervisor checks become software | NH3, NH4, NH5 | licence, `clinical` | hours per assessment; insurer controlling findings unchanged or better |
| **4. Network roles** | Experts and quality are shared across homes; the head of care becomes a network clinical lead | NH6, NH7, NH8 | D-24 | coordinators and supervisors per 100 residents down; income per nurse up (D-14) |
| **5. Integrated network** | One record across home care, hospital transitions and nursing homes | REF2, RET1, ORD1 | D-9, D-22 | readmissions and avoidable transfers (definition by `clinical`) |

---

## Decisions this report opens

- **D-24 (`owner`).** Should NAVORA enter nursing homes (Horizon 3), and with which design-partner home? Can NAVORA obtain the interRAI LTCF CH licence and RAIsoft or export integration rights?
  - Recommendation: start Phase 1 on one ward without any LTCF integration. The organisational change needs no licence.
- **D-25 (`legal`).** What do cantonal licensing rules require of nursing-home leadership (a named home director, a nursing-care lead and their qualifications)? Does a ward team without a ward leader, with a network clinical lead, satisfy them?
  - Recommendation: answer for the pilot canton (D-11) before Phase 1.
- **D-13 (`owner`, open)** stays the instrument decision. This report adds the reason to keep LTCF only for the nursing-home offer.

## Open questions for the pilot (UNKNOWN today)

- Minutes per assessment cycle per resident, by role. These are measured, not estimated.
- How ward leadership, rostering, intake and discharge work in the partner home today. Interviews, then recorded in this report.
- Cantonal staffing and qualification-mix rules. These belong to `legal`, under D-25.
