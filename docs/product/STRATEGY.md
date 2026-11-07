# NAVORA Strategy

**Owner:** Chief Strategy Architect (`csa`, owner 2026-10-27). **Process:** [`../agents/README.md`](../agents/README.md), *Strategy review*. Seeded by `po` on 2026-10-27 13:30 CET from the owner's decisions of the same day; `csa` maintains it from its first run.

Every claim below is labelled:
- IMPLEMENTED: true in the repository today, synthetic data;
- PLANNED: approved or proposed, not built;
- OPEN: undecided;
- UNKNOWN: not established.

---

## 1 Vision (owner, 2026-10-27)

NAVORA software is not a management tool. **It is a core component of the operating model itself.** NAVORA creates a new care-delivery model in which self-organised nursing teams provide care with minimal hierarchy and much less administration; the platform is what makes this possible.

**Long-term objectives:**
- self-organised care teams;
- maximum team autonomy;
- minimal hierarchy;
- maximum direct care time;
- AI-assisted operations, planning, documentation, billing preparation and coordination.

**AI's purpose:** remove administrative burden and enable teams to organise themselves.

**Clinical foundation:** interRAI is a core clinical foundation for care planning, continuity, reassessment and governance, within licensing and regulatory limits.

**How the vision is applied:** pilot safety requires a staged approach, but every strategic decision reflects the long-term vision.

**How opportunities are judged (owner, 2026-10-28, for `csa` and `aia`):** do not start from "how can we improve the current way of working?". First ask: **"If we were designing home care from scratch today, how would we organise it?"** Then compare that future-state model with current practice, and say what NAVORA should **eliminate, redesign, automate or replace entirely**. The goal is a superior care-operating model, not incremental optimisation. The model `csa` uses is in §8.

## 2 Owner decisions of 2026-10-27

| Topic | Decision | Status |
|---|---|---|
| Strategic direction | Approved as recorded in [`STRATEGIC_ALIGNMENT_REVIEW.md`](STRATEGIC_ALIGNMENT_REVIEW.md) §0 | decided |
| D-12 licence holder | B as an operating-model partnership: the pilot team runs on NAVORA as its operating system; 12-month sunset; the team-owned provider (C) prepared from month 0, with `lca`'s five conditions (NAVORA holds no control over it). **The partner is a pilot vehicle, not the destination.** | decided |
| D-34 medical-device status | A plus C: the core stays outside medical-device scope (statement v2); the clinical intelligence (AI documentation drafting, interRAI-based planning support) goes into a separately qualified clinical module, the long-term target | decided (adviser questions still open for the module's route) |
| D-35 AI services | Staged path approved: stage 0 now (governance layer and rules, synthetic data); stage 1 administrative AI after 3 stable pilot months, through a new owner package; stage 2 dictation; stage 3 clinical module | decided (stage 0 in force) |
| D-37 interRAI | Strategic decision track approved; expert review and licence clarification (D-36) before the final decision | OPEN |
| Roles | AI & Automation Architect (`aia`) and Chief Strategy Architect (`csa`) created | IMPLEMENTED (schedules) |

**Owner decisions of 2026-10-28** (in the `csa` session):

| Topic | Decision | Status |
|---|---|---|
| `csa` strategic review of 2026-10-27 | Approved, with the overall direction and the priority on G-1 and on removing blockers to the long-term model | decided |
| STR-14 (freeze packages that wait for a person) | Approved; `csa` to propose an implementation approach (STRATEGIC_ALIGNMENT_REVIEW, STR-17) | decided; implementation PLANNED |
| STR-15 (C-transfer terms before the partner's letter of intent) | Approved as high priority: the transition must be defined before entering a pilot partnership. The package (D-38) must cover transition criteria, client consent and transfer, staff transfer, tariff-contract transition, financing, fee portability, partner incentives, governance after transition, and the conditions under which a team becomes independent | decided; D-38 already exists (PO, from STR-15); `csa` proposes the missing terms T15-T18 and a T10 proposal (STR-18) |
| How opportunities are judged | "Designed from scratch" first, then compare (§1, §8) | decided |

## 3 Horizons

From [`CARE_OPERATING_MODEL.md`](CARE_OPERATING_MODEL.md):
1. **Home care, now.** Pilot in Zurich (D-11 recommended, OPEN).
2. **Transitions of care with hospitals, next** (REF2).
3. **Nursing homes, later** (D-24, OPEN).
4. **Integrated care networks.**

## 4 Regulatory and organisational roadmap (PLANNED unless marked)

Updated by `csa` 2026-10-27 13:55 CET. Month 0 = the partner's letter of intent (D-12; the 8-week trigger makes C the route if none by about week 8). Durations come from `lca` 12:42 on [Z1]; everything else is a `csa` planning estimate, labelled.

| Track | Next step | When it must happen | Depends on | Cost of each month of delay |
|---|---|---|---|---|
| **Clinical Owner (G-1)** | owner names the person, route B (independent mandate) | **now**: before the pilot bundle (STR-13) | owner | 9 clinical packages and D-37's intervals stay blocked; the pilot cannot start; AI stage 1 moves by the same month |
| **Live-project hygiene** (D-1, SR-26, D-7, D-8) | one owner session | **now** | owner | every real-data gate stays closed |
| **Pilot foundation** (D-11, D-2, D-26, D-29, D-14; partner; Zurich legal adviser) | one owner decision meeting (STR-1 to STR-4) | before month 0 | G-1 for the go-live gates | the pilot start moves; with it the 12-month sunset and stage 1 AI |
| **Team-owned provider (C)** | transfer-terms package before the letter of intent (STR-15); nursing lead and deputy qualified under [Z1] identified in the team; Zurich licence file drafted from month 0 | licence and OKP admission are **two procedures of about 8 weeks each** (`lca`), so about 4 months after a complete file. To be admitted inside the 12-month sunset, the file must be complete by **month 7 at the latest** (`csa` estimate: 12 − 4 − about 1 month of margin for questions from the authority) | D-11, partner letter of intent, Zurich legal adviser, STR-15 terms | after month 7 the sunset either slips or the team leaves the partner without an admitted provider (no billing, `lca` condition 5) |
| **Clinical module (D-34 C)** | intended purpose and boundary of the module; conformity route with a regulatory adviser | route chosen before stage 2 starts, because stage 3 needs it and a conformity route takes UNKNOWN time (no source read) | adviser questions in D-34; stage-0 evidence (AIG1) | stage 3 (AI documentation drafting, interRAI-based planning support) cannot start; documentation stays dimension 4 *weak* |
| **interRAI foundation (D-37)** | owner provides the licence terms to `lca` (D-36, `awaiting-approval: owner` since PO 13:35), saying who holds the licence (STR-16); `eng`, `cra`, `lca` inputs; one licence conversation covering HC now and LTCF later (STR-11) | terms before ASM1 is built beyond D-13 B | owner (terms), G-1 (intervals, triggers) | ASM1 stays instrument-neutral; dimension 6 stays *weak* |
| **AI stages (D-35)** | stage 0 now: AIG1 approved (*Next up* 3, PO 13:35; PLANNED); stage 1 package naming provider, region, contract | stage 1 package written during pilot months 1-3 so it is ready at month 3 of stable operation | 3 stable pilot months; DPIA; partner's sub-processor approval | each month before the pilot starts moves stage 1 by a month |

**Update `csa` 2026-11-03 13:33 CET (owner directions #816, #817, #818; STR-20 to STR-25).** The rows above are kept as written; where they conflict, this update wins.

| Track | Change | When it must happen | Cost of each month of delay |
|---|---|---|---|
| **Pilot canton (D-11)** | Owner direction: Basel-Stadt and Basel-Landschaft (#816), replacing the Zurich recommendation. The 8-week licence and admission durations above were read on Zurich sources and are **UNKNOWN for BS and BL**; the month-7 C-file deadline has no source until `lca` re-reads them. `csa` proposes starting in one of the two cantons (STR-20). | `lca` re-read before the partner's LOI | each month without a dated duration leaves the 12-month sunset unprotected |
| **Partner, legal adviser** | Now a Basel partner and a BS/BL adviser (owner agenda bundle 2). Only the owner may contact them. | before month 0 | the pilot start and every C-file date move by the same month |
| **Nursing homes (D-24, D-25)** | Owner direction: one platform for both settings (#818). `csa`: user stories with sources now, build only with one self-organised design-partner ward after G-1 and D-36 (STR-21). | stories: any time; build: after G-1, D-36, a partner ward | building earlier fixes the product shape on licence hierarchy, not on a team |
| **IoT and AI prediction (#817)** | Draft spec; gated by D-34, D-35, a proposed D-39 (sensors in a private home), D-3/D-4, G-1. `csa`: spec without migration until D-34 has a conformity route (STR-22). Billing stays "prepared by AI, signed by a person" (STR-23). | after D-35 stage 1 and D-34 route | none for patients today; earlier build costs rework |
| **interRAI (D-36)** | Owner's licence conversation should name three uses: automated computation of scales and CAPs, AI-drafted proposals confirmed by a nurse, contractor software use (STR-24). Whether they are licensable: UNKNOWN. | before ASM1 goes beyond D-13 B | dimension 6 stays *weak*; all-in-one LTCF stays blocked too |

## 5 Business model hypotheses (OPEN)

Each hypothesis names the evidence it needs. `csa` sets no price and no amount.

| # | Hypothesis | Status | Evidence needed | Source of evidence |
|---|---|---|---|---|
| BM-1 | NAVORA's fee is volume-neutral: per active team member per month (D-14 F3) | OPEN, awaiting owner | that teams do not shrink or shift to fewer full-time members because of it (`cra` H-10) | AN2 hours per active member per team, month on month (pilot) |
| BM-2 | The fee is agreed **per team and is portable** to the team-owned provider; no organisation-wide licence or exclusivity with the partner (STR-2) | proposed by `csa` | the partner's acceptance in the letter of intent | owner, partnership |
| BM-3 | A team-size band variant of F3 is fairer to part-time nurses at equal compliance (STR-2) | proposed by `csa` | `lca` compliance check; whether pilot teams mix part-time members | `lca`; pilot team composition (UNKNOWN) |
| BM-4 | A self-organised team generates a surplus after pay and costs that it can reinvest (S1 now) or later share (S4 with an equal split, after a legal adviser) | OPEN | real invoicing (D-18) and recorded working time (D-23, WORK1) | J5, WORK1, AN1 in the pilot; UNKNOWN until then |
| BM-5 | Nurse income rises in a team-owned provider compared with employment by a traditional provider (value 3) | OPEN, UNKNOWN | a comparison of pay under B and under C, legal form of C, residual financing (STR-1) | the C file; Zurich adviser |
| BM-6 | Low overhead is NAVORA's margin: a team-owned provider on NAVORA runs below the overhead of a Buurtzorg-like back office (benchmark §7: 6.7 % of total costs) | hypothesis | the C provider's cost structure after its first year | C provider accounts (UNKNOWN) |
| BM-7 | Revenue (value 9) grows with the number of teams, not with billed hours | follows from BM-1 | as BM-1 | – |
| BM-8 | (2026-11-03) The F3 fee unit (per active team member) also fits a nursing-home ward team, so all-in-one (#818) needs no second pricing model | hypothesis, `csa` | that a ward team is a stable unit with members, and that nothing in a BS/BL nursing-home licence ties the unit to a hierarchy | `lca` sources (#818); a design-partner ward (UNKNOWN) |
| BM-9 | (2026-11-03) Sensor and AI functions (#817) are not a revenue line before D-34 and D-35 stage 1; pricing them earlier prices a medical-device risk nobody has assessed | hypothesis, `csa`; no price set | D-34 conformity route; D-35 provider and contract | `cra`, `lca`, regulatory adviser |

## 6 Open strategic questions for `csa`

1. **How fast can the pilot move from the partner (B) to a team-owned provider (C) without a gap in licence or admission?** *Partial answer, 2026-10-27:* not by a licence transfer, which `lca` reads as impossible (D-12 note 3); only by a new licence and a new OKP admission, two procedures of about 8 weeks each, plus each client's consent to move. Earliest admission about month 4-5 if the file is complete at month 0; latest safe file date about month 7 for the 12-month sunset (§4). What is still unknown is written as STR-15.
2. Which hospital or region gives the strongest wedge for horizon 2? OPEN: depends on D-11's municipalities and D-9 (REF2).
3. What does the clinical module's conformity route cost, and when must it start so that stage 3 is not late? OPEN: no source read; the route must be chosen before stage 2 (§4).
4. How does NAVORA scale to many team-owned providers without rebuilding a central hierarchy (network services: cover, quality, the Clinical Owner)? *Partial answer:* each provider needs its own Leitung Pflege and deputy (`lca` on [Z1]: no job-sharing of the Leitung Pflege), so the clinical lead cannot be centralised into a network role; what a network can share is the rule set (one version co-signed per provider, STR-13), cover between teams (COVER1), the software and the back office. Whether providers may share a quality function: UNKNOWN (`lca`).
5. **New:** what does the partner gain from incubating a team that leaves after 12 months (fee share, a model contract for its own other teams, staff retention, reputation)? OPEN; owner (partnership); part of STR-15.
6. **New:** may a team member's employment contract with the partner restrict her from joining the team-owned provider, and with it her clients? UNKNOWN; `lca`, then the Zurich adviser (STR-15).
7. **New:** does the client information at intake allow the planned change of provider to be named in advance, so the transfer consent is light? UNKNOWN; `lca` (STR-7).

8. **New 2026-11-03:** with two Basel cantons, should the first team and the C provider start in one canton only? *Partial answer:* `csa` recommends one (STR-20); the cantonal difference in licence, residual financing and tariff contract is UNKNOWN until `lca` reads BS and BL sources.
9. **New 2026-11-03:** does a nursing-home licence in BS or BL leave room for a self-organised ward team (who must be named, which staffing rules)? UNKNOWN; `lca` sources (#818). The answer decides whether all-in-one serves dimension 7 or works against it.
10. **New 2026-11-03:** can any OKP billable service be prepared from sensor data or an AI output, and what must the nurse still document and sign? UNKNOWN; `lca` (#817 gate 5). `csa` assumes the signed visit report stays the only billing basis (J5).
11. **New 2026-11-03:** what do Swiss incumbents that adopted Buurtzorg principles still keep centrally, and can NAVORA's software replace it? *Partial answer:* see the Spitex Zürich Limmat benchmark (§7): planning, recruitment and holidays moved to teams; IT, HR, quality, specialist services and insurer and city relations stayed central, and data-entry deadlines were set by payroll and billing.

## 7 Benchmarks (one per `csa` run, newest first)

### 2026-11-03 · Spitex Zürich Limmat, Buurtzorg-inspired pilot (2018)

**Source:** M. Radtke, interview with Christina Brunnschweiler, CEO Spitex Zürich Limmat, "We stumbled across Buurtzorg", 6 August 2018, PDF on buurtzorg.com (https://www.buurtzorg.com/wp-content/uploads/2018/08/Spitex-We-stumbled-across-Buurtzorg.pdf), read 2026-11-03 through a summarising fetch; statements as reported, not verified. What became of the pilot after 2018: UNKNOWN (not found in this run's search).

**In my words:** a large Swiss Spitex organisation (about 1,000 staff, 6,724 clients in 2017) ran a pilot in Zürich-Schwamendingen with self-organised teams. Interest was so high that seven teams formed instead of two. Teams took over holiday and duty planning, recruited with HR support, and in two teams planned their own visits. Two management levels (centre and team management) were removed. Central services kept IT, HR, quality, specialist care (for example palliative) and the relations with insurers, the city and suppliers. Teams had to use the company's IT system and enter data by a binding deadline set by payroll and billing. Early signals were fewer sick days and lower recruitment costs; the CEO stressed that the aim was satisfied clients and staff, not cost cutting.

**Where NAVORA must exceed it:**
- **Visit planning in every team, not two.** NAVORA's team-owned day plan (PLAN3, PLANNED) must make visit planning the default for every team, with continuity weighted in.
- **No data-entry deadline set by the back office.** Documentation should be captured once at the point of care and turned into payroll and billing preparation automatically (WORK1, J5; AI stages per D-35), so the deadline disappears instead of being enforced.
- **Central functions as software and network services, not a centre.** Quality, cover and insurer communication should be rules and shared services a team uses (STR-13, COVER1, QG1), so removing management levels does not leave a central office in their place.
- **Ownership.** The Zürich pilot stayed inside one employer. NAVORA's destination is the team-owned provider (D-12 C), which is why D-38's terms matter before any partner LOI, Basel included.
- **Basel lesson:** an incumbent can adopt self-organisation inside its hierarchy. A Basel partner that does so is a good design partner (B), but only D-38's sunset terms keep it from becoming the destination.

### 2026-10-27 · Buurtzorg Nederland, *Kwaliteitsbeeld 2025*

**Source:** Buurtzorg Nederland, *Kwaliteitsbeeld Buurtzorg Nederland 2025* (PDF, https://www.buurtzorgnederland.com/assets/Bestanden/d1741ff61f/2025-Kwaliteitsbeeld-Buurtzorg-Nederland-1.pdf), read 2026-10-27 through a summarising fetch; figures as reported by Buurtzorg, not verified.

**In my words:** Buurtzorg runs district nursing through small, fixed, self-steering teams that plan and coordinate their own work. Teams are mixed by qualification level. Regional coaches support a team when it asks. The report gives **overhead of 6.7 % of total costs**, against **16.9 %** at comparable organisations in its benchmark. It reports more than **72,000 clients in 2025**, about 2,000 more than in 2024 at about the same capacity, because care input per client fell. Client satisfaction averages **9.2**. Client NPS is **83.8 %** (sector 54.8 %) and employee NPS **66 %** (sector 4 %). Care planning uses the **Omaha System**, a classification, together with *Positieve Gezondheid*. Buurtzorg names its own open problems: continuity of care (less external hiring, more permanent contracts), agreements with family carers, multidisciplinary work in the neighbourhood, and learning from incident reports. A neighbourhood "ecosystem" project started in 20 municipalities in 2025.

**Where NAVORA must exceed it:**
- **No coach layer.** Buurtzorg keeps regional coaches and a central back office. NAVORA's model replaces both with the care graph, deterministic rules (OPS1, SIG1, COVER1, ABS1) and team consent (ADM2). NAVORA must show it reaches **at or below 6.7 % overhead without a coach layer**. That needs a measure of overhead at provider level, which the pilot does not have yet (UNKNOWN; BM-6).
- **Continuity measured, not only promised.** Buurtzorg names continuity as a problem. NAVORA has a primary nurse (J6, IMPLEMENTED) and proposes a continuity-weighted day plan (PLAN3, PLANNED). It must report continuity per team from events (AN2), never per person.
- **Direct care share from events.** The report gives overhead and satisfaction. NAVORA's North Star is direct care share, computed from events (AN1, IMPLEMENTED on synthetic data), with the 60 % Buurtzorg reference already in `CARE_OPERATING_MODEL.md` and a 75 % hypothesis.
- **Assessment instrument.** Buurtzorg plans with Omaha. NAVORA's direction is interRAI HC (D-37, OPEN), integrated through the provider's licensed tool (D-37 option B), for reassessment, continuity and governance. NAVORA must turn the assessment into reassessment prompts and continuity (ASM1, PLANNED) without computing scales before the clinical module and the licence allow it.
- **Ownership.** Buurtzorg's teams are employees of one foundation. NAVORA's destination is **team-owned providers** (D-12 C). That is a step beyond Buurtzorg and is only credible once STR-15's transfer terms exist.

## 8 Home care designed from scratch (future-state model, `csa` 2026-10-28)

Owner instruction 2026-10-28 (§1). This is the reference `csa` judges packages, briefs and roadmap changes against. It is a strategic model, not a rule: no clinical, legal or tariff rule follows from it, and every regulated role it names stays (Clinical Owner, Leitung Pflege, licence holder). Status of every element: PLANNED or hypothesis unless marked.

### 8.1 If we designed home care today

1. **The unit is a neighbourhood team that owns its provider.** About 8-12 nurses of mixed qualification serve a few contiguous municipalities. The team is the licensed, admitted provider, legally and economically. It holds the licence-bound roles (Leitung Pflege and deputy) inside itself. Nobody above it plans, admits or disposes.
2. **Coordination is a property of the shared record, not a job.** Intake, planning, cover, handover, absence, quality signals and billing facts are states and events in one care graph. A role that exists only to move information between people (dispatcher, scheduler, intake coordinator, billing clerk) does not exist.
3. **One clinical language.** A standardised assessment (interRAI HC is the owner's direction, D-37) is the source of the care plan, the reassessment cycle, continuity and the billing basis. Nothing is typed twice.
4. **Machines propose, people decide.** Rules do rule-shaped work. AI drafts from unstructured input. A named person confirms every entry. Safety signals stay deterministic (D-35 path; never-list unchanged).
5. **Shared services without a headquarters.** What a small provider cannot carry alone is bought as a contracted service shared by many team-owned providers: a regulated back office (tariff contracts, invoicing submission, quality reporting), night and weekend on-call, training places, and the Clinical Owner's rule catalogue. Each provider adopts rules and buys services; none takes instructions (`aia` AUT-12, hypothesis P-24; `lca`: licence-bound roles stay per provider).
6. **Starting a provider is a product.** A team founds its provider from a ready kit: legal-form templates, a licence file, insurance, a tariff-contract route, its training-place arrangement and its NAVORA set-up. An incumbent's licence is not needed as a bridge.
7. **Income follows care.** The team keeps the provider margin. NAVORA's fee is volume-neutral (D-14). Surplus rules reward care delivered with quality held, never hours or categories.

### 8.2 Compared with current practice and with NAVORA today

| Element | Current practice (typical Spitex organisation; general description, not a sourced survey) | NAVORA today | Verdict |
|---|---|---|---|
| Who plans and assigns | Einsatzplanung or dispatcher above the teams | team plans from the care plan (PLAN2), proposal + team confirmation (PLAN3, PLANNED) | **eliminate** the scheduling role (in progress) |
| Who admits colleagues | management or HR | team consent (ADM2, PLANNED); account creation still manual (D-26 default) | **redesign**, then automate the account step (D-26) |
| Handover | team meeting, phone | record shows "since you were last here" (HAND1, IMPLEMENTED) | **eliminate** the meeting (done) |
| Working time | timesheet | proposed from visits, confirmed (WORK1, IMPLEMENTED) | **automate** (done) |
| Assessment | separate tool; re-typed into the plan | instrument-neutral record (ASM1, PLANNED) | **redesign**: one clinical language (D-37) |
| Documentation | free text after the visit | structured lifecycle; report text by hand | **automate** in stages (stage 2 dictation, stage 3 module) |
| Billing preparation | back office checks minutes and orders | billable facts derived from signed visits (J5, IMPLEMENTED) | **automate**; invoice draft later (BILL2) |
| Who holds the licence | the organisation; teams are employees | partner holds it during the pilot (D-12 B) | **replace**: team-owned providers (D-12 C, D-38) |
| How a provider starts | founding project, years | not defined beyond D-38 | **replace** with a provider kit (STR-19) |
| Shared functions | headquarters | none; hypothesis P-24 | **redesign** as contracted shared services |

### 8.3 What follows for current decisions

- **The partner route should be needed once, not per team.** From scratch, nobody would incubate each new team inside an incumbent. D-12 B is a bridge for the first team because no provider kit and no shared regulated service exist yet. Every term in D-38 that the first team works out (licence file, Leistungsauftrag, tariff route, training places, financing) should be written so that the **second team can found its provider directly**. This is STR-19.
- **Judge each package by the end state it leaves behind.** A term that is safe but only works inside the partner (for example a per-person authorisation kept by the partner, STR-3) is a cost the second team pays again.
- **Shared services are the scale path, not a central management.** P-24 needs the adviser's answer (one Leitung Pflege for several providers: UNKNOWN; `lca`). Until then each provider carries its own licence-bound roles.

## 9 Execution tracking (owner, 2026-11-06)

**Owner instruction, 2026-11-06 (in a `csa` session):** a strategic recommendation is complete only when it has an owner, acceptance criteria, an entry in the roadmap or architecture, and measurable progress. `csa` tracks every recommendation until then and re-escalates what has not moved.

**How `csa` applies it (owner choice, same session: "track and escalate", not "write to the roadmap"):** `csa` stays advisory. The PO keeps the only queue and roadmap authority, so priorities are still set in one place. `csa`:
1. ends every review cycle with six parts: strategic findings, strategic risks, required actions, assigned owners, success criteria, review date;
2. for every strategic risk, market shift, business-model threat, competitor threat or transformational opportunity, asks whether `po`, `eng`, `cra`, `lca` or the founder must act, and gives each action an owner, priority, rationale, expected outcome and target date;
3. lists only actions that create measurable progress, grouped as actions for the Product Owner, Engineering, Clinical, Legal and Founder;
4. keeps one execution tracker in `STRATEGIC_ALIGNMENT_REVIEW.md` (newest section) and checks, every cycle, from the repository: was action taken, was the recommendation adopted, did the roadmap change, was the architecture updated, was the risk mitigated;
5. re-escalates an item that has not moved by its target date: once to `po` on the item's issue; a second time as a proposed owner-agenda line through `po` (never to the owner directly);
6. never assigns work to `eng`, `cra` or `lca` directly: actions for them are proposals that `po` accepts into a brief, a package input request or the queue.

Healthcare hierarchy, administration, coordination, planning, documentation, quality management and assessment workflows stay under the challenge duty; each challenge ends in an execution path, not only a finding.

## 10 Brand (owner, 2026-11-03 to 2026-11-06)

**Decision in force: KEEP NAVORA FOR NOW.** NAVORA remains the project name, the repository name and the working product name. No rebranding activity is approved. No Engineering, Product, UX/UI, Clinical or Legal work may be delayed by branding discussions. (Owner, 2026-11-06.)

**Phase 2 brand validation (approved by the owner 2026-11-06):** decides whether a customer-facing rebrand is needed before the pilot launch. Four checks, all of which must pass for NAVORA to stay customer-facing: (1) trademark clearance in CH, the EU and HR, classes 9, 42, 44; (2) no conflicting filing by Navora AI LLC, or a coexistence agreement; (3) navora.ch and one usable .com variant obtainable; (4) a 13-person confusion test with at most 2 confusions. The working document is the owner's Claude Doc *NAVORA Brand Assessment* (tabs: assessment, shortlist, Phase 2 validation); it holds the sources.

**Facts found 2026-11-03 (desk research, not clearance):** navora.com, navora.ai, navora-ai.com in use by others; navora.hr (a Croatian consultancy named Navora) and navora.at (a clothing shop branded NAVORA) in use; navora.de, navora.care, navora.health registered (content unknown); navora.eu and navora.app offered for sale; navora.ch UNKNOWN. Eleven uses of "Navora" on record; the strongest confusion risk is Navora AI LLC (US; AI for regulated sectors including healthcare; Swiss partner in Geneva). Trademark registers were not reachable; trademark status UNKNOWN.

**Timing (`csa` STR-26):** the public website (M5, 2027-01-15) is the first public use of the name and needs a domain decision by the owner in M3 (2026-12-11). Phase 2 should therefore conclude by M3, not only by the pilot launch.

