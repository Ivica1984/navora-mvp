# Automation Review

**Owner:** AI & Automation Architect (`aia`, owner 2026-10-27). **Process:** [`../README.md`](../README.md), *Automation review*. **Mandate:** [`ROLE_PROPOSALS_AIA_CSA.md`](ROLE_PROPOSALS_AIA_CSA.md) (approved by the owner 2026-10-27).

**How to read this file:**
- The newest dated section comes first. Never edit an earlier section; correct it in a new one.
- Each finding is a row `AUT-<n>` with:
  - workflow step and role;
  - today's effort and its evidence (events, code, report, source);
  - proposal (eliminate, rule, monitor, agent);
  - device level (L, G, H);
  - gate;
  - measure;
  - severity (`high`, `medium`, `low`);
  - issue.

**Success measures (owner 2026-10-27), in this order:**
1. more direct care time;
2. less administrative burden;
3. stronger self-organised teams.

---

## 2026-10-27 13:30 CET · baseline (seeded by `po`, not an `aia` review)

**Owner instruction for the first runs:** find the largest bottlenecks in home care, and say how NAVORA can eliminate, simplify or automate them.

**Already in the repository** (read these first; do not re-derive):
- [`../../product/AI_OPERATING_MODEL_REVIEW.md`](../../product/AI_OPERATING_MODEL_REVIEW.md): the care graph, roles, meetings, validations, documentation activities, agent catalogue A1-A12, *Agents not to build*, AI governance controls. From now on maintained by `aia`.
- [`../../product/TRANSFORMATION_ALIGNMENT_REPORT.md`](../../product/TRANSFORMATION_ALIGNMENT_REPORT.md): duplicated work, approvals and meetings that could disappear, first-principles redesigns.
- [`../../product/CARE_OPERATING_MODEL.md`](../../product/CARE_OPERATING_MODEL.md): North Star (direct care share, Buurtzorg 60 % benchmark, 75 % hypothesis), *What disappears*, challenge table.
- [`../../product/STRATEGIC_ALIGNMENT_REVIEW.md`](../../product/STRATEGIC_ALIGNMENT_REVIEW.md) §1, §3, §4: the verdict per dimension; the staged AI path approved by the owner; the proposed briefs AIG1, ASM1, PLAN3, BILL2.

**Candidate bottlenecks to test, as PO hypotheses (not findings).** Each needs evidence before it becomes an `AUT-<n>`:
- **Documentation time per visit:** report writing on a phone; countersignature (D-10).
- **Day planning and travel order;** balancing continuity by hand (PLAN2 plans visits; nobody orders the day).
- **Coordination by phone:**
  - GP order renewals (ORD1);
  - referrals from hospitals (REF2);
  - relatives.
- **Needs assessment and reassessment:** re-typing between the assessment tool and the care plan (D-13, D-37).
- **Billing preparation:**
  - checking billable minutes;
  - insurer queries (J5, A4).
- **Onboarding, offboarding and working-time administration** (ADM2, LEAVE1, WORK1).

**Measures available today:**
- AN1 (direct care share per team; synthetic data);
- AN2 (pilot hypotheses from events);
- WORK1 (confirmed working day).

Real pilot values: UNKNOWN until the pilot. Measure gains at team level only, never per person.

**Limits in force:**
- D-35 rule A: no client or staff data to any AI service; AI stage 0 only.
- D-34 statement v2: nothing computed from clinical content outside the future clinical module.
- D-36 option A: interRAI only by name.
- D-27: no clinical rule without the Clinical Owner.
