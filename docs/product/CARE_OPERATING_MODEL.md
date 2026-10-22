# NAVORA Care Operating Model — beyond Buurtzorg

**Owner:** Product Owner (`po`) · **Stand:** 2026-10-22 · **Status:** strategic direction. Approved items appear in `docs/agents/NEXT_CAPABILITY.md`. Targets marked *hypothesis* are validated with pilot data (AN1), not assumed.

## North Star

**Direct care share:** the share of paid nursing time spent with the client.

Every capability is judged by whether it raises this share without lowering safety or continuity. It is the measure where NAVORA must beat the benchmark: Buurtzorg notifies nurses who spend less than **60 %** of their annual time on billable services ([Commonwealth Fund 2015](https://www.commonwealthfund.org/publications/case-study/2015/may/home-care-self-governing-nursing-teams-netherlands-buurtzorg-model)). The remaining 40 % is planning, documentation, billing, coordination and travel.

*Hypothesis:* NAVORA can reach **75 %**, because software, not the nurse, does planning, billing preparation and most documentation.

## The benchmark: what Buurtzorg proved, and where it stops

| Buurtzorg proved | Source |
|---|---|
| Self-governing teams of about 10–12 nurses, each serving about 50–60 clients, without managers | [Commonwealth Fund](https://www.commonwealthfund.org/publications/case-study/2015/may/home-care-self-governing-nursing-teams-netherlands-buurtzorg-model) |
| About 15 coaches for about 700 teams; back office under 50 people | same |
| Overhead 8 % of costs versus 25 % for other providers (Ernst & Young 2009) | same |
| Fewer care hours per client year (108 vs. 168) at higher hourly cost (€54.47 vs. €48.74) | same (KPMG) |

| Where it stops | NAVORA design answer | Capability |
|---|---|---|
| **Nurses still do the administration.** Teams assess, plan, schedule, document and bill themselves; the team is self-managed, but the paperwork is not gone | Software plans from the care plan, derives billing facts and drafts the report. The nurse confirms, not composes | PLAN2, J5, F7; AI drafts in Gate 4 |
| **Coaches carry absences, under-performance, disputes and team finances** (1 coach for about 47 teams). Coaching is the hidden scaling limit | Absences and cover are solved by the network; finances are transparent to the team. The coach is called by signals, not by routine | COVER1, J7, OPS1 |
| **Teams are islands.** Cover between teams depends on phone calls and goodwill | Uncovered visits are offered automatically to qualified nurses in neighbouring teams before anyone is called | COVER1 |
| **The wider organisation blocks the teams:** sign-off for equipment, imposed standards, middle managers re-entering ([UK experience](https://corporate-rebels.com/lessons-buurtzorg-uk); [Drennan et al., BMJ Open 2018](https://bmjopen.bmj.com/content/8/6/e021931)) | NAVORA *is* the organisation: no host hierarchy to fight. Rules live in software as transparent configuration, not in managers | D-20, ADM1 |
| **Flat structures leave career and pay progression unclear** ([BMJ Open 2018](https://bmjopen.bmj.com/content/8/6/e021931)) | Transparent team economics, with income tied to the value the team creates; progression by verified qualification | J7, D-14 |
| **No built-in referral source**; intake by phone ([Commonwealth Fund](https://www.commonwealthfund.org/publications/case-study/2015/may/home-care-self-governing-nursing-teams-netherlands-buurtzorg-model)) | Hospitals refer once, digitally, to all eligible teams at the same time, with an answer guaranteed within hours | REF2, J2 |
| **Documentation data (Omaha System) is not used to learn** ([Commonwealth Fund](https://www.commonwealthfund.org/publications/case-study/2015/may/home-care-self-governing-nursing-teams-netherlands-buurtzorg-model)) | Structured observations, quality events and outcomes feed team-level learning signals | QG1, AN1, Gate 4 |
| **An RN-heavy generalist model** drives the higher hourly cost | Skill mix: registered nurses where the law requires them (category B, needs assessment), care assistants elsewhere, and risk-based rather than blanket countersignature | J3, D-10 |

## What disappears

| Role or task in a traditional organisation | Replaced by | Status |
|---|---|---|
| Station or unit leadership, line managers | Self-organised teams; rules as transparent configuration | IMPLEMENTED (no line roles in the model, DOMAIN_RULES) |
| Dispatcher who assigns cases to teams | Team pull with response deadlines and escalation | IMPLEMENTED (J2) |
| Scheduling administrator | Visits generated from the care plan with the primary nurse | PLANNED (PLAN2) |
| Phone chain to find a substitute | Automatic cross-team cover offer | PLANNED (COVER1) |
| Intake coordinator re-typing referrals | Direct digital referral by the hospital; NAVORA only checks | DRAFT (REF2; legal basis D-9) |
| Documenting after the shift | Report confirmed at visit completion | PLANNED (F7) |
| Billing preparation at month end | Billable facts derived continuously from signed visits | IMPLEMENTED (J5) |
| Manual quality report | Quality events and holds from the visit; KPIs from data | IMPLEMENTED (QG1); PLANNED (AN1) |
| Central member administration | Teams admit colleagues; NAVORA verifies qualifications only | PROPOSED (D-20, owner) |
| Blanket countersignature of care-assistant visits | Risk-based review | PROPOSED (D-10, clinical) |

What does **not** disappear: verified qualifications, clinical responsibility, legal accountability, data protection. These are decisions for their owners, not things to automate away.

## Horizons

1. **Home care (now).** Swiss ambulatory care with self-organised teams; pilot in one canton (D-11).
2. **Transitions of care (next).** The hospital discharge is NAVORA's wedge. Discharge planners spend their time phoning providers. One digital referral with a guaranteed answer is a reason for hospitals to choose NAVORA (REF2).
3. **Nursing homes (later).** The same team model on wards replaces station leadership: teams plan, a residents' care plan drives the work, quality events and holds apply. Needs the LTCF/assessment track decision (D-13).
4. **Integrated care networks.** Home care, nursing homes and hospitals as one journey, with continuity carried by the client's care plan, not by the institution.

## Proposed changes to the Architecture Handbook

- **Operations should shrink by design.** Target ratio of teams per Operations person; every recurring exception type gets an automation proposal. Today intake (J1) is an Operations task. With REF2 it becomes an exception.
- **The coach is signal-driven.** The coach is called by OPS1 and AN1 signals (team health, continuity, quality), not by a calendar.
- **Team membership is a team decision** (D-20), with central verification of qualifications.
