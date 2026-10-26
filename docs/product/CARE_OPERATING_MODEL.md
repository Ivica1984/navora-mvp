# NAVORA Care Operating Model — beyond Buurtzorg

**Owner:** Product Owner (`po`) · **Stand:** 2026-10-25 22:10 (go-live gate index added; earlier 2026-10-22 18:20) · **Status:** strategic direction. Approved items appear in `docs/agents/NEXT_CAPABILITY.md`. Targets marked *hypothesis* are validated with pilot data (AN1), not assumed.

## North Star

**Direct care share:** the share of paid nursing time spent with the client.

Every capability is judged by whether it raises this share without lowering safety or continuity. It is the measure where NAVORA must beat the benchmark: Buurtzorg notifies nurses who spend less than **60 %** of their annual time on billable services ([Commonwealth Fund 2015](https://www.commonwealthfund.org/publications/case-study/2015/may/home-care-self-governing-nursing-teams-netherlands-buurtzorg-model)). The remaining 40 % is planning, documentation, billing, coordination and travel.

*Hypothesis:* NAVORA can reach **75 %**, because software, not the nurse, does planning, billing preparation and most documentation.

*Measurement (PO, 2026-10-22 14:30):* the denominator is **paid** working time. NAVORA does not record it yet, so the North Star is not measurable today. AN1 shows a within-visit care share instead, labelled as such and never compared with 60 % or 75 %. The proposed way to close the gap without adding a timesheet: derive the working day from field events and let the nurse confirm it once a day (challenge table; working-time recording duties are `legal` question D-23).

*Update (PO, 2026-10-24 21:10, D-23 decided by po):* the denominator will be the **nurse-confirmed** working day: NAVORA proposes the day from her own visit events, only she sees it, she adds breaks and non-visit work and confirms; the confirmed day goes to the employer's record on her action, and the North Star is shown per team only (AN1 suppression), never per person. The employer keeps the legal record; NAVORA is not it. PLANNED; no brief yet. Precondition: visit events readable only within the team.

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
| Dispatcher or coordinator watching an operations screen so that a missed or stuck visit is noticed | A P1 safety signal is delivered to the responsible nurse and her team; one of them takes it with one tap; Operations only when nobody takes it | IMPLEMENTED in the app (SIG1, #279, 0060; awaiting clinical review); outside the app PLANNED (SIG2, D-32) |
| Chasing GP practices for order renewals by phone and fax | Prepared renewal request, sent by the primary nurse, confirmed digitally by the GP | DRAFT (ORD1; D-22, D-9) |
| Nurse ordering her day and route by hand | Proposed order of the day from visit windows and travel time | HYPOTHESIS (Q7 data protection; AN1 travel minutes) |
| Statutory statistics and cantonal reports compiled by hand | Generated from billing, continuity and quality facts | HYPOTHESIS (D-11) |
| Back-office invoice preparation | Invoices generated from J5 facts with a human release | after D-12, D-18 |
| Nurses classify every planned service into a KLV category (A/B/C) by hand | The category comes from an approved service catalogue; the team changes it only with a reason, and the change is visible | HYPOTHESIS (D-15 option C; the catalogue is a clinical and billing rule for the Clinical Owner) |
| A data-protection officer periodically reads access logs to find reads that should not have happened | Reads outside a nurse's own teams or her accepted cover are impossible by design (D-3 option B, bounded cover card); only exceptional reads (a break-glass read, if option C is ever needed) raise a signal to the client's team and the data-protection role; the log is evidence, not a reading task | HYPOTHESIS (D-3; read log is a go-live condition) |
| An administrator or data-protection officer answers each client access request by collecting records by hand, and periodically clears out old referrals and log rows | Retention class per audited column, a one-command client extract and self-expiring referrals: retention and access requests become properties of the data (D-4, D-9 go-live conditions) | HYPOTHESIS (zero staff hours per access request and per retention run, counted from the audit log) |
| An administrator tunes safety-signal thresholds for the whole organisation | The Clinical Owner sets a band, the team chooses inside it (D-28 option C); an organisation override can only make a signal earlier (ADM1-R, CGR-39) and is removed if the pilot shows nobody uses it | HYPOTHESIS (D-28; ADM1-R PLANNED) |
| A nursing-management line layer above the teams (planning, approving, dispatching) that comes with the operating licence | The few duties only the licensed role carries are named functions NAVORA signals and records (serious-event review, qualification confirmation, clinical-rule approval, untaken escalations), carried by one fractional clinical lead at network level; no added dispatch or approval layer is a D-12 partnership condition | HYPOTHESIS (D-12, D-11 licence percentage; fewer than 5 such actions per week per 50 clients, from the audit log) |
| Intake ticking "consent confirmed" and re-typing the medical order from paper for every referral | The legal basis is recorded with a code where it arises (referrer form, needs-assessment visit); the order arrives as a structured record with issue date and the doctor's GLN/ZSR; intake handles exceptions only | HYPOTHESIS (D-9 basis, `lca`; D-22 order record, awaiting `owner`) |
| A steering group or coach reads the pilot figures in a monthly review and decides which change to propose | Each hypothesis carries its written decision rule (threshold, minimum base); NAVORA marks the row when the threshold is crossed, and the PO or the team acts on that signal, not on a calendar | HYPOTHESIS (AN2 accepted 2026-10-24; challenge row "The pilot is steered by a periodic review meeting") |

**Go-live condition (PO, 2026-10-24, SIG1-8, CGR-37):** until safety signals reach people outside the app (D-32), the pilot plan names, for every hour in which visits are planned, the person who has `/field`, `/team` or OPS1 open; no visit is planned outside those hours. Pilot visit hours: UNKNOWN (owner, pilot plan). **Extended 2026-10-24 11:09 (PO, CGR-41 point 3):** the pilot plan also records the organisation's watched hours in `/admin` once SIG2-6 is built, so that a foreseeable look-ahead P1 is raised inside them; until SIG2-6 is built, the named watcher covers every hour in which a look-ahead P1 can arise for the next 24 h of planned visits, or the plan states that such visits are covered (a responsible member assigned) before the last watched hour of the day before. Who watches and in which employment form (working time or Pikett) is the provider's policy (owner, D-12, D-23); whether a P1 must be answered at night is `clinical` (D-28). **Extended 2026-10-24 15:10 (PO, `lca` 15:05 on D-32; CGR-42):** before go-live the provider confirms in writing how the watched hours are staffed (working time or planned Pikett); NAVORA records the hours, the provider decides the form. Operations receives pushes only inside the watched hours (SIG2-12). Until SIG2-11 is built, the pilot checklist records that the signal evaluator job exists and runs in the pilot project (owner executes).

**Go-live condition (PO, 2026-10-24 04:10, D-30, `lca` 03:53):** before the first real client, a client's request to correct a care record can be met when the report's author has left the team: at least a dated addendum or a "bestritten" mark by a registered nurse of the team, shown with the final version, original untouched, audited. Who may write it and which fields: `clinical` (D-30).

**Go-live condition (PO, 2026-10-24 06:10, D-3, `lca` 02:52):** before the first real client, (i) every read of client health data goes through a function that writes a read-log row (person, type, date and time, recipient; kept at least one year, separate, readable only by a data-protection role; content of DSV Art. 4 Abs. 4-5 as read by `lca`); (ii) a data-protection impact assessment (DSG Art. 22) is done; (iii) coordination roles see a client's identity only where their task needs it. **(iv), added 2026-10-24 22:10 (PO, after `lca` 21:55):** every table, view and function that returns client-, case- or visit-linked rows is scoped like 0015 (the row's team, the covering member while her cover runs, coordination roles only where a named task needs it), listed in one read-path inventory with a pgTAP per path; free-text reasons never leave the team and the covering member (brief RLS2). It also keeps any member from rebuilding a colleague's working day (D-23). **Status 2026-10-25 08:10 CET (PO):** RLS2 accepted (no organisation-wide path left); (iv) is met only once F-1 (DOOR1-11), F-2 and F-5 (RLS3) and F-3 (D-4 or DSFA) are done. **Before the first real employee:** no teammate reads `actor_id` of visit events row by row (RLS3-4, D-23 item 9). Whether a pilot strictly requires each stays a question for a legal adviser (`lca` questions 1, 3, 4); until answered these are the safe side.

**Go-live condition (PO, 2026-10-24 06:10, D-31, `lca` 02:52):** before the first real client, care given in a visit that was broken off is documented, in NAVORA (D-31 option 1b) or by a documented procedure of the organisation outside it. The report's content: `clinical` (D-31).

**Go-live condition (PO, 2026-10-24 10:11, D-9, `lca` 07:58):** before the first real client: (g1) a referral holds no free-text need data before the referrer has confirmed that the client was informed and agreed; (g2) a referral that is never converted expires and is anonymised by itself, with no manual clean-up (period with D-4's final rule); (g3) the DSG Art. 19 information given at intake is recorded (text version, when, by whom); (g4) consents per recipient category (other teams for cover, treating doctor, network) and per emergency contact, with a withdrawn state, replace the single consent box before cover is switched on or anything is shared; a no-show outcome "Notfallkontakt informiert" on the basis of a recorded consent then references that record (PO 2026-10-25 22:10, D-19); (g5) a representative can be recorded. The legal basis itself: owner (D-9, option D).

**Go-live condition (PO, 2026-10-24 10:11, D-4, `lca` 08:05):** no audit row is deleted or anonymised before the final retention rule; the retention criteria (care record: the canton's record period after the last treatment; billing evidence: 10 years after the business year; access logs: at least one year; operational rows: until the final rule) can be told to a client; before the first real client, (r1) a client's audit rows can be extracted with one command, staff identities masked by default; (r2) every audited column carries a retention class the validator checks; (r3) admins read the log only through a reader that records the purpose. Final periods: owner after D-11 and D-12.

**Go-live condition (PO, 2026-10-24 10:11, D-15, C-1):** no real client's care plan is created while the team chooses the KLV category freely; the approved service catalogue (option C, `clinical`) comes first.

What does **not** disappear: verified qualifications, clinical responsibility, legal accountability, data protection. These are decisions for their owners, not things to automate away.

## Go-live gates: one list

**PO, 2026-10-25 22:10 CET.** The go-live conditions above, and the real-data gates written in briefs and decision packages, in one place, so nobody has to collect them from twenty files before the first real client. This list is an index: the linked source holds the rule, and a gate is lifted only by the role named there. Status labels: IMPLEMENTED (built and accepted), PLANNED (approved, not yet delivered), OPEN (waits on a decision). Engineering and the other agents add a line by asking the PO; the PO updates the status when the source changes. **No real client, and no real employee data, while any line is not IMPLEMENTED.** Switching on cover (COVER1) has its own list in `docs/agents/briefs/COVER1.md`; it is not needed for go-live because cover stays off.

| Gate | What must hold before the first real client | Source | Lifted by | Status |
|---|---|---|---|---|
| G-1 | A named, qualified Clinical Owner exists (every `clinical` package waits for this) | D-27, `decisions/INDEX.md` | owner | OPEN |
| G-2 | Live database facts known; SR-01 (live) and SR-22 closed; leaked-password protection on | D-1, `docs/engineering/SECURITY_RISKS.md` | owner | OPEN |
| G-3 | Legal entity with licence and OKP admission, pilot canton named | D-12, D-11 | owner | OPEN |
| G-4 | Production hosting settled and the data-protection impact assessment done | D-12 condition, D-2, D-3 (ii) | owner | OPEN |
| G-5 | Intended purpose assessed by a regulatory adviser (medical device question) | D-34 | owner | OPEN |
| G-6 | Qualifications verified before they are active (option B) | D-29 | owner | OPEN |
| G-7 | D-3 (i) read log, (iii) client identity for coordination roles only where a task needs it, (iv) every read path team-scoped: RLS2, RLS3 accepted, F-1 met (DOOR1-11); **F-3 open (AUD1)** | D-3, briefs RLS2, RLS3, DOOR1, AUD1 | po for (iv); owner for the rest | OPEN; (iv) PLANNED (AUD1) |
| G-8 | Intake legal basis and gates g1-g5 (incl. per-contact consent, g4: append-only, scoped, refusal only on `recorded_consent`) | D-9 | owner | OPEN |
| G-9 | Audit log: no deletion before the final rule; r1 client extract, r2 retention class per column, r3 purpose reader (AUD1) | D-4 | po (r1-r3), owner (final periods) | r3 PLANNED (AUD1); r1, r2 OPEN |
| G-10 | No real care plan while the KLV category is chosen freely; approved service catalogue first | D-15 | clinical | OPEN |
| G-11 | No door or key-safe code in any access note, and none left from before the guard (count zero); one "Zugang" line; a clinical category only with an `APPROVED` register row | DOOR1-12, DOOR1-13, DOOR1-14 | po (acceptance) | PLANNED |
| G-12 | A correction request can be met when the report's author has left (addendum or "bestritten" mark); D-30 answered before the first real leaver | D-30 | clinical | OPEN |
| G-13 | **No real client before LEAVE1 is accepted** (access ends with employment, LEAVE1-1 to LEAVE1-14) | LEAVE1-9 | po (acceptance) | PLANNED (`changes-requested` 2026-10-26 02:14 CET: `cra` 01:26 CGR-62 blocking S1 → LEAVE1-14, a leaver's signal take must stop counting; LEAVE1-1 to -13 met, reviewed 00:20) |
| G-14 | Care in a broken-off visit is documented (in NAVORA or by a written procedure) | D-31 | clinical | OPEN |
| G-15 | Watched hours named and their staffing confirmed in writing by the provider; FUP1-C1 and FUP1-C2 merged before SIG1-8 is lifted | SIG1-8 (above), FUP1 | owner (staffing), clinical (lifting SIG1-8), po (FUP1) | OPEN; FUP1-C1/C2 PLANNED |
| G-16 | A no-show or interruption taken by a non-registered nurse still reaches Operations | SIG1-C1 | po | IMPLEMENTED (2026-10-24 21:10) |
| G-17 | A corrected time in the repeated hour can be entered either way (DST1-C4, due before the first real client or 2027-10-31); the test clock can never reach a shared database (DST1-C5, before staging with real users) | DST1 | po (acceptance) | PLANNED |
| G-18 | Before the first real **employee**: no teammate reads who performed each visit event row by row | D-3 (iv) note, RLS3-4, D-23 | po | see RLS3 (accepted 2026-10-25 16:11) |
| G-19 | Before the first real **employee** confirms a working day (WORK1): the licence holder adopts the nurse-confirmed export as its way of keeping the working-time record and states whether ArGV 1 Art. 73b applies under its agreements; the employer adopts the information text after an `lca` look at the final wording; D-4 carries a retention criterion for confirmed working days | D-23 items 3b, 4, 7e; brief WORK1 | owner (D-12, policy), po (D-4 criterion) | OPEN |

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
| AN2 | Pilot reporting by a coach or Operations | Hand tallies of hypothesis counts, monthly count meeting | Coach as reporter | Measures 2 and 8 show whether follow-ups and absences strand clients | Decides which coordination step to remove next | Indirect (evidence before build) |

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
