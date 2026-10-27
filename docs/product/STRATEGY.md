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

## 2 Owner decisions of 2026-10-27

| Topic | Decision | Status |
|---|---|---|
| Strategic direction | Approved as recorded in [`STRATEGIC_ALIGNMENT_REVIEW.md`](STRATEGIC_ALIGNMENT_REVIEW.md) §0 | decided |
| D-12 licence holder | B as an operating-model partnership: the pilot team runs on NAVORA as its operating system; 12-month sunset; the team-owned provider (C) prepared from month 0, with `lca`'s five conditions (NAVORA holds no control over it). **The partner is a pilot vehicle, not the destination.** | decided |
| D-34 medical-device status | A plus C: the core stays outside medical-device scope (statement v2); the clinical intelligence (AI documentation drafting, interRAI-based planning support) goes into a separately qualified clinical module, the long-term target | decided (adviser questions still open for the module's route) |
| D-35 AI services | Staged path approved: stage 0 now (governance layer and rules, synthetic data); stage 1 administrative AI after 3 stable pilot months, through a new owner package; stage 2 dictation; stage 3 clinical module | decided (stage 0 in force) |
| D-37 interRAI | Strategic decision track approved; expert review and licence clarification (D-36) before the final decision | OPEN |
| Roles | AI & Automation Architect (`aia`) and Chief Strategy Architect (`csa`) created | IMPLEMENTED (schedules) |

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

## 6 Open strategic questions for `csa`

1. **How fast can the pilot move from the partner (B) to a team-owned provider (C) without a gap in licence or admission?** *Partial answer, 2026-10-27:* not by a licence transfer, which `lca` reads as impossible (D-12 note 3); only by a new licence and a new OKP admission, two procedures of about 8 weeks each, plus each client's consent to move. Earliest admission about month 4-5 if the file is complete at month 0; latest safe file date about month 7 for the 12-month sunset (§4). What is still unknown is written as STR-15.
2. Which hospital or region gives the strongest wedge for horizon 2? OPEN: depends on D-11's municipalities and D-9 (REF2).
3. What does the clinical module's conformity route cost, and when must it start so that stage 3 is not late? OPEN: no source read; the route must be chosen before stage 2 (§4).
4. How does NAVORA scale to many team-owned providers without rebuilding a central hierarchy (network services: cover, quality, the Clinical Owner)? *Partial answer:* each provider needs its own Leitung Pflege and deputy (`lca` on [Z1]: no job-sharing of the Leitung Pflege), so the clinical lead cannot be centralised into a network role; what a network can share is the rule set (one version co-signed per provider, STR-13), cover between teams (COVER1), the software and the back office. Whether providers may share a quality function: UNKNOWN (`lca`).
5. **New:** what does the partner gain from incubating a team that leaves after 12 months (fee share, a model contract for its own other teams, staff retention, reputation)? OPEN; owner (partnership); part of STR-15.
6. **New:** may a team member's employment contract with the partner restrict her from joining the team-owned provider, and with it her clients? UNKNOWN; `lca`, then the Zurich adviser (STR-15).
7. **New:** does the client information at intake allow the planned change of provider to be named in advance, so the transfer consent is light? UNKNOWN; `lca` (STR-7).

## 7 Benchmarks (one per `csa` run, newest first)

### 2026-10-27 · Buurtzorg Nederland, *Kwaliteitsbeeld 2025*

**Source:** Buurtzorg Nederland, *Kwaliteitsbeeld Buurtzorg Nederland 2025* (PDF, https://www.buurtzorgnederland.com/assets/Bestanden/d1741ff61f/2025-Kwaliteitsbeeld-Buurtzorg-Nederland-1.pdf), read 2026-10-27 through a summarising fetch; figures as reported by Buurtzorg, not verified.

**In my words:** Buurtzorg runs district nursing through small, fixed, self-steering teams that plan and coordinate their own work. Teams are mixed by qualification level. Regional coaches support a team when it asks. The report gives **overhead of 6.7 % of total costs**, against **16.9 %** at comparable organisations in its benchmark. It reports more than **72,000 clients in 2025**, about 2,000 more than in 2024 at about the same capacity, because care input per client fell. Client satisfaction averages **9.2**. Client NPS is **83.8 %** (sector 54.8 %) and employee NPS **66 %** (sector 4 %). Care planning uses the **Omaha System**, a classification, together with *Positieve Gezondheid*. Buurtzorg names its own open problems: continuity of care (less external hiring, more permanent contracts), agreements with family carers, multidisciplinary work in the neighbourhood, and learning from incident reports. A neighbourhood "ecosystem" project started in 20 municipalities in 2025.

**Where NAVORA must exceed it:**
- **No coach layer.** Buurtzorg keeps regional coaches and a central back office. NAVORA's model replaces both with the care graph, deterministic rules (OPS1, SIG1, COVER1, ABS1) and team consent (ADM2). NAVORA must show it reaches **at or below 6.7 % overhead without a coach layer**. That needs a measure of overhead at provider level, which the pilot does not have yet (UNKNOWN; BM-6).
- **Continuity measured, not only promised.** Buurtzorg names continuity as a problem. NAVORA has a primary nurse (J6, IMPLEMENTED) and proposes a continuity-weighted day plan (PLAN3, PLANNED). It must report continuity per team from events (AN2), never per person.
- **Direct care share from events.** The report gives overhead and satisfaction. NAVORA's North Star is direct care share, computed from events (AN1, IMPLEMENTED on synthetic data), with the 60 % Buurtzorg reference already in `CARE_OPERATING_MODEL.md` and a 75 % hypothesis.
- **Assessment instrument.** Buurtzorg plans with Omaha. NAVORA's direction is interRAI HC (D-37, OPEN), integrated through the provider's licensed tool (D-37 option B), for reassessment, continuity and governance. NAVORA must turn the assessment into reassessment prompts and continuity (ASM1, PLANNED) without computing scales before the clinical module and the licence allow it.
- **Ownership.** Buurtzorg's teams are employees of one foundation. NAVORA's destination is **team-owned providers** (D-12 C). That is a step beyond Buurtzorg and is only credible once STR-15's transfer terms exist.
