# NAVORA Care Operating Model — beyond Buurtzorg

**Owner:** Product Owner (`po`) · **Stand:** 2026-10-22 18:20 · **Status:** strategic direction. Approved items appear in `docs/agents/NEXT_CAPABILITY.md`. Targets marked *hypothesis* are validated with pilot data (AN1), not assumed.

## North Star

**Direct care share:** the share of paid nursing time spent with the client.

Every capability is judged by whether it raises this share without lowering safety or continuity. It is the measure where NAVORA must beat the benchmark: Buurtzorg notifies nurses who spend less than **60 %** of their annual time on billable services ([Commonwealth Fund 2015](https://www.commonwealthfund.org/publications/case-study/2015/may/home-care-self-governing-nursing-teams-netherlands-buurtzorg-model)). The remaining 40 % is planning, documentation, billing, coordination and travel.

*Hypothesis:* NAVORA can reach **75 %**, because software, not the nurse, does planning, billing preparation and most documentation.

*Measurement (PO, 2026-10-22 14:30):* the denominator is **paid** working time. NAVORA does not record it yet, so the North Star is not measurable today. AN1 shows a within-visit care share instead, labelled as such and never compared with 60 % or 75 %. The proposed way to close the gap without adding a timesheet: derive the working day from field events and let the nurse confirm it once a day (challenge table; working-time recording duties are `legal` question D-23).

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
| Scheduling administrator | Visits generated from the care plan with the primary nurse | IMPLEMENTED (PLAN2, accepted 2026-10-22) |
| Phone chain to find a substitute | Automatic cross-team cover offer | IMPLEMENTED, switched off until D-3 (COVER1) |
| Intake coordinator re-typing referrals | Direct digital referral by the hospital; NAVORA only checks | DRAFT (REF2; legal basis D-9) |
| Documenting after the shift | Report confirmed at visit completion | IMPLEMENTED (F7) |
| Billing preparation at month end | Billable facts derived continuously from signed visits | IMPLEMENTED (J5) |
| Manual quality report | Quality events and holds from the visit; KPIs from data | IMPLEMENTED (QG1, AN1) |
| Central member administration | Teams admit colleagues; NAVORA verifies qualifications only | PROPOSED (D-20, owner) |
| Blanket countersignature of care-assistant visits | Risk-based review | PROPOSED (D-10, clinical) |
| Daily team handover meeting; shift lead as knowledge carrier | "Since you were last here" on every visit card, from the record | IMPLEMENTED (HAND1, accepted 2026-10-22) |
| Re-intake and re-matching of a client after a hospital stay | Paused case resumes; returning client offered to the known team first | IMPLEMENTED (RET1, accepted 2026-10-22) |
| Shift lead or dispatcher re-assigning an absent nurse's visits by phone | The absent nurse says so once; her visits go to her team, the colleague who knows the client first | PLANNED (ABS1) |
| Dispatcher or coordinator watching an operations screen so that a missed or stuck visit is noticed | A P1 safety signal is delivered to the responsible nurse and her team; one of them takes it with one tap; Operations only when nobody takes it | PLANNED (SIG1, CGR-37; outside the app after D-32) |
| Chasing GP practices for order renewals by phone and fax | Prepared renewal request, sent by the primary nurse, confirmed digitally by the GP | DRAFT (ORD1; D-22, D-9) |
| Nurse ordering her day and route by hand | Proposed order of the day from visit windows and travel time | HYPOTHESIS (Q7 data protection; AN1 travel minutes) |
| Statutory statistics and cantonal reports compiled by hand | Generated from billing, continuity and quality facts | HYPOTHESIS (D-11) |
| Back-office invoice preparation | Invoices generated from J5 facts with a human release | after D-12, D-18 |
| Nurses classify every planned service into a KLV category (A/B/C) by hand | The category comes from an approved service catalogue; the team changes it only with a reason, and the change is visible | HYPOTHESIS (D-15 option C; the catalogue is a clinical and billing rule for the Clinical Owner) |
| Intake ticking "consent confirmed" and re-typing the medical order from paper for every referral | The legal basis is recorded with a code where it arises (referrer form, needs-assessment visit); the order arrives as a structured record with issue date and the doctor's GLN/ZSR; intake handles exceptions only | HYPOTHESIS (D-9 basis, `lca`; D-22 order record, awaiting `owner`) |

**Go-live condition (PO, 2026-10-24, SIG1-8, CGR-37):** until safety signals reach people outside the app (D-32), the pilot plan names, for every hour in which visits are planned, the person who has `/field`, `/team` or OPS1 open; no visit is planned outside those hours. Pilot visit hours: UNKNOWN (owner, pilot plan).

**Go-live condition (PO, 2026-10-24 04:10, D-30, `lca` 03:53):** before the first real client, a client's request to correct a care record can be met when the report's author has left the team: at least a dated addendum or a "bestritten" mark by a registered nurse of the team, shown with the final version, original untouched, audited. Who may write it and which fields: `clinical` (D-30).

What does **not** disappear: verified qualifications, clinical responsibility, legal accountability, data protection. These are decisions for their owners, not things to automate away.

## Where NAVORA exceeds Buurtzorg

| Lever | Buurtzorg | NAVORA | Capability |
|---|---|---|---|
| Intelligent matching | Referrals by phone to one team | All eligible teams at once with a deadline; continuity first for returning clients | J2, RET1, REF2 |
| Intelligent scheduling | Team plans by hand | Visits generated from the care plan with the primary nurse; day order proposed (hypothesis) | PLAN2 |
| Intelligent documentation | Omaha documentation written by the nurse | Report built from visit facts and signed at completion; handover read from the record; AI drafts with human review later | F6, F7, HAND1, Gate 4 |
| Intelligent quality monitoring | Team reflection and coach | Quality events, holds and continuity measures from data, with signals to the team | QG1, J6, AN1 |
| Intelligent workforce coordination | Teams are islands | Network cover offered automatically; knowledge carried by the record | COVER1, HAND1 |
| Organisational simplification | Coaches and a small back office | No dispatch, intake or scheduling roles; Operations handles exceptions only; teams admit colleagues | J2, OPS1, D-20 |

## Impact ledger of proposed capabilities

Every proposed capability answers the same questions. The detail is in each brief.

| ID | Administration layer replaced | Manual activity removed | Role less necessary | Continuity | Direct care time | Income potential |
|---|---|---|---|---|---|---|
| PLAN2 | Scheduling and dispatch | Planning every recurring visit by hand | Scheduling administrator | Primary nurse is the default | Planning time back to care | More billable minutes per paid hour |
| F7 | Documentation back office | Documenting and signing after the shift | – | – | Evening documentation disappears | Same |
| COVER1 | Dispatch for absences | Phone chain for substitutes | Dispatcher; coach as absence handler | Visits happen, case stays with its team | Less coordination time | Cover is extra billable work (pay supplement D-14) |
| HAND1 | Coordination layer | Handover meetings, colleague phone calls | Shift lead as knowledge carrier | Every nurse arrives informed | Meeting time back to care | More billable minutes per paid hour |
| RET1 | Intake and matching for known clients | Re-intake and re-matching | Intake coordinator, dispatcher | Same team across a hospital stay | No re-learning of a known client | Team keeps its client base |
| ABS1 | Dispatch and shift lead for absences | Morning phone chain, re-assigning visits one by one | Dispatcher, shift lead, coach as absence handler | Deputy or primary nurse takes the visit first | Phone time back to care | Team keeps its billable volume |
| REF2 | Intake on both sides | Re-typing referrals; phoning providers | Intake coordinator | Faster start after discharge | Less intake work | Faster start of billable care |
| ORD1 | Order administration | Chasing GP orders | Administrative staff for orders | No gap in category B care | Phone time back to care | B visits stay billable |
| SIG1 | Dispatch and control-room watching | Watching OPS1 for missed visits; phoning around to find who is on it | Dispatcher, coordinator on watch | The responsible nurse hears first | Watching time back to care | – |
| ORD0 | Order administration | Untracked GP information; open-ended orders noticed by chance | – | The doctor link is on the record | – | B care stays billable (renewal prompted) |
| AN1 | Management reporting | Manual KPI reports | Controlling and reporting roles | Continuity becomes visible to the team | Proves the North Star | Evidence for D-14 |

## Horizons

1. **Home care (now).** Swiss ambulatory care with self-organised teams; pilot in one canton (D-11).
2. **Transitions of care (next).** The hospital discharge is NAVORA's wedge. Discharge planners spend their time phoning providers. One digital referral with a guaranteed answer is a reason for hospitals to choose NAVORA (REF2).
3. **Nursing homes (later).** The same team model on wards replaces station leadership: teams plan, a residents' care plan drives the work, quality events and holds apply. Needs the LTCF/assessment track decision (D-13). Analysis and proposals: [`NURSING_HOME_TRANSFORMATION.md`](NURSING_HOME_TRANSFORMATION.md) (D-24, D-25).
4. **Integrated care networks.** Home care, nursing homes and hospitals as one journey, with continuity carried by the client's care plan, not by the institution.

## Proposed changes to the Architecture Handbook

- **Operations should shrink by design.** Target ratio of teams per Operations person; every recurring exception type gets an automation proposal. Today intake (J1) is an Operations task. With REF2 it becomes an exception.
- **The coach is signal-driven.** The coach is called by OPS1 and AN1 signals (team health, continuity, quality), not by a calendar.
- **Team membership is a team decision** (D-20), with central verification of qualifications.
- **Close the loop in the data flow (PO 2026-10-22 13:30).** The Handbook data flow is linear and ends with billing facts. Measured minutes (J5 "above plan"), observations and quality events should flow back as a **care-plan change proposal** to the team, which decides. Then the care plan follows reality instead of a review calendar.
- **Name the missing actors.** The Handbook lists nurse, team, Operations, partner and architect. The **client and relatives**, the **GP** and the **hospital discharge planner** do much of today's coordination by phone. They should be first-class actors with minimal, consented access (ORD1, REF2, visit-window hypothesis).
- **Add a "Workforce network" context.** Cross-team cover (COVER1), returning clients (RET1), nurse-chosen capacity (J4) and verified qualifications are network concerns. Today they are spread over Team Self-Organization and Operations, which invites a central dispatcher to come back.
- **"Teamplanung" is not a manual step.** In the orchestrator chain, team planning should read "plan generated from the care plan; the team handles exceptions" (PLAN2). The team decides; it does not type.
