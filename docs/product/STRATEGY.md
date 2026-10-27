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

| Track | Next step | Depends on |
|---|---|---|
| Team-owned provider (C) | nursing lead and deputy identified in the pilot team; Zurich licence file drafted from month 0; licence and OKP admission are two procedures of about 8 weeks each | D-11, partner letter of intent, Zurich legal adviser |
| Clinical module (D-34 C) | intended purpose and boundary of the module; conformity route with a regulatory adviser | adviser questions in D-34; stage-0 evidence |
| interRAI foundation (D-37) | licence terms to `lca` (D-36); `eng`, `cra`, `lca` inputs; integration route through the provider's licensed tool | owner provides the licence terms |
| AI stages (D-35) | AIG1 governance layer; stage-1 package naming provider, region and contract | 3 stable pilot months; DPIA; partner approval |
| Clinical Owner (G-1) | owner names the person | – |

## 5 Business model hypotheses (OPEN)

- Platform fee per active team member per month (D-14, F3 recommended; awaiting owner).
- Team surplus and nurse income: value 3 in the owner's value order. Evidence comes from AN1, WORK1 and J5 in the pilot (UNKNOWN until then).

## 6 Open strategic questions for `csa`

1. How fast can the pilot move from the partner (B) to a team-owned provider (C) without a gap in licence or admission?
2. Which hospital or region gives the strongest wedge for horizon 2?
3. What does the clinical module's conformity route cost, and when must it start so that stage 3 is not late?
4. How does NAVORA scale to many team-owned providers without rebuilding a central hierarchy (network services: cover, quality, the Clinical Owner)?
