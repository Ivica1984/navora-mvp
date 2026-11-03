# NAVORA Delivery Program M1-M10

**Owner of this plan:** Product Owner (`po`) · **Date:** 2026-11-03 (Europe/Zurich) · **Requested by:** the owner, *Executive Delivery Directive* (2026-11-03): "The AI-First Architecture update is accepted. The architecture phase is complete. The next step is execution planning." · **Status:** execution plan, version 1.

**How to read the dates:**
- Every date is a **PO target**, not an engineering commitment.
- Engineering's sequence and effort estimate (M1, due 2026-11-13) re-baselines them in version 2 of this plan.
- Dates after M3 hold only if the owner's decisions in M3 arrive by 2026-12-11. Every week of delay there moves M9 and M10 by the same week.

**Status labels:** IMPLEMENTED (on `recovery/main`, synthetic data) · PLANNED · OPEN (needs a decision) · FROZEN (owner freeze, specification only).

**Binding rules for every milestone:**
- Mandatory sequence: Remove → Rules → Monitor → AI prepares → Human reviews → Human decides → Human signs.
- Synthetic data only until D-1 is clarified; no client or staff data to any AI service (D-35 A).
- D-39 and D-40 frozen.
- Clinical review gate (`cra`) on every item that touches care.
- The PO accepts each milestone against its acceptance criteria. Accepting means reading the evidence: merged PRs, green CI, reports. The PO does not run tests.

**Roles:**
- `po`: Product Owner (what, why, when; acceptance).
- `eng`: Engineering (how; build; tests).
- `uxa`: UX/UI Design Architect (screens, navigation, components, design system).
- `cra`: Clinical & Regulatory Architect (safety, clinical governance; advisory).
- `lca`: Legal & Compliance Agent (advisory; no legal determination).
- `aia`: AI & Automation Architect (automation review).
- **owner:** decisions only the owner can take.

---

## 1. Milestones

| # | Milestone | Target date | Owner (delivers) | Accepts |
|---|---|---|---|---|
| M1 | Delivery baseline | Fri 2026-11-13 | `eng` + `uxa` | `po` |
| M2 | Web application consolidated | Fri 2026-11-27 | `eng` | `po` |
| M3 | Pilot foundation decisions | Fri 2026-12-11 | **owner** | – (owner decides) |
| M4 | AI Foundation I | Fri 2026-12-18 | `eng` | `po` (with `cra`) |
| M5 | Website and public landing pages live | Fri 2027-01-15 | `eng` (build), `uxa` (design) | `po` (with `lca`) |
| M6 | Caregiver app v1 | Fri 2027-01-29 | `eng` | `po` (with `cra`) |
| M7 | Family app specification and decision | Fri 2027-02-05 | `po` | owner (D-40) |
| M8 | Operations Center v2 and AI Foundation II | Fri 2027-02-19 | `eng` | `po` (with `cra`) |
| M9 | Pilot readiness | Fri 2027-03-12 | `po` (readiness), `eng` (technical) | owner (go / no-go) |
| M10 | Production readiness | Wed 2027-06-30 | `eng` (technical), `po` (product) | owner |

### M1 Delivery baseline (Fri 2026-11-13)
- **Objective:** turn this plan into an estimated, sequenced build plan and an implementation-ready design inventory.
- **Owner:** `eng` and `uxa`; `po` accepts.
- **Supporting:** `aia` (AI sequence check), `cra` (clinical scope per item).
- **Dependencies:** this plan; issues for `eng` (estimates) and `uxa` (design deliverables).
- **Deliverables:**
  - `docs/engineering/DELIVERY_ESTIMATE.md` (`eng`, §5);
  - `docs/design/SCREEN_INVENTORY.md`, `NAVIGATION_MAP.md`, `COMPONENT_INVENTORY.md` and an implementation-ready update of `DESIGN_SYSTEM.md` (`uxa`, §6);
  - this plan version 2 with re-baselined dates (`po`, by Tue 2026-11-17).
- **Acceptance criteria:**
  - every item of M2-M10 has an effort estimate in person-days with a confidence label, its predecessor and the risk that moves it;
  - pilot and production readiness estimates are stated as dates with their assumptions;
  - every screen in §2 and §3 appears in the screen inventory with route, role, data read and component list;
  - every component has its states (default, loading, empty, error, disabled, focus) and its token references;
  - no item in the estimate requires real data or a frozen package.

### M2 Web application consolidated (Fri 2026-11-27)
- **Objective:** one NAVORA app on phone and desktop, the base for the caregiver and operations apps.
- **Owner:** `eng`; `po` accepts.
- **Supporting:** `uxa` (review), `cra` (UX2 gate on `/field`, `/team`).
- **Dependencies:**
  - UX2 PRs #799, #800, #803, #804, #806 merged;
  - UX2-27/-29 amendments (CGR-108, CGR-109);
  - UX2-31, UX2-32;
  - CGR-110 (#399) fixed.
- **Deliverables:** UX2 `delivered` (UX2-1 to UX2-32); RLS4-C3 (`/admin` "Erneut laden", no false "keine").
- **Acceptance criteria:**
  - UX2-1 to UX2-32 met on `recovery/main` with green CI (`app`, `db`, `e2e`, `ui-screenshots`);
  - no `severe` UX finding open on a UX2 screen;
  - `cra` UX2 gate clear;
  - pgTAP 062 passes at any hour (CGR-110), shown by two runs at different pinned times.

### M3 Pilot foundation decisions (Fri 2026-12-11)
- **Objective:** the owner takes the decisions without which no pilot date can hold.
- **Owner:** owner; `po` prepares (packages exist).
- **Supporting:** `lca`, `cra` (inputs already in the packages).
- **Dependencies:** decision packages D-1, G-1 (D-27), D-11 (#816), D-12 partner, D-2, D-29, D-7/D-8, D-34 adviser, D-14.
- **Deliverables:** answered packages recorded in `OPEN_DECISIONS.md`.
- **Acceptance criteria:**
  - **D-1** answered: the live database facts are known, the key is rotated, and the documented review is recorded;
  - **G-1:** a Clinical Owner is named;
  - **D-11:** pilot canton (one of BS/BL first, `csa` STR-20) and the municipalities are named;
  - **D-12:** a licensed partner has signed a letter of intent, or route C is chosen;
  - **D-2:** staging and production hosting are approved;
  - **D-29:** qualification verification is approved;
  - **D-7/D-8:** branch protection is in place and `recovery/main` is merged to `main`;
  - **D-34:** the regulatory adviser is named;
  - **D-14:** the fee basis is approved.
- **If missed:** M9 and M10 move by the delay, day for day. M4-M8 continue on synthetic data.

### M4 AI Foundation I (Fri 2026-12-18)
- **Objective:** the first AI-first coordination capability and the measurement baseline.
- **Owner:** `eng`; `po` accepts with `cra`.
- **Supporting:** `aia` (measures), `lca` (AN3 under D-23 term (b)).
- **Dependencies:** M2; AIG1-C4 and AIG1-C5 in or before the PLAN3 PR.
- **Deliverables:**
  - **AIG1-C4/-C5** built;
  - **PLAN3** (PLAN3-1 to PLAN3-13) delivered;
  - **AN3** delivered.
- **Acceptance criteria:**
  - every acceptance criterion of `briefs/PLAN3.md` and `briefs/AN3.md` met with green CI;
  - every PLAN3 proposal is in the AIG1 ledger and becomes a visit assignment only through a named team member's confirmation (AIG1-3, AIG1-5);
  - AN3 returns no person key and suppresses small teams (pgTAP);
  - `cra` gate clear on PLAN3; synthetic data only.

### M5 Website and public landing pages live (Fri 2027-01-15)
- **Objective:** a public website that presents NAVORA truthfully and takes demo requests (track in §2).
- **Owner:** `eng` (build), `uxa` (design); `po` accepts.
- **Supporting:** `lca` (claims, privacy notice, demo-form data), `cra` (wording that touches care or AI).
- **Dependencies:**
  - website brief **WEB1** (`po`, Fri 2026-11-20);
  - `uxa` page designs (Fri 2026-12-04);
  - a hosting and domain decision for the public site (owner, in M3);
  - a destination for demo requests (owner, in M3).
- **Deliverables:** the seven pages and the demo request flow of §2, in German first and English second.
- **Acceptance criteria:**
  - every page is live on the public domain;
  - Lighthouse accessibility ≥ 95 and performance ≥ 90 on phone;
  - every claim on the AI, nursing-home and family pages is cleared by `lca`: no medical-device claim; "AI prepares – humans decide"; frozen or unbuilt features said to be "in Vorbereitung";
  - the demo form stores no data in the care database; it has a privacy notice, a consent tick for contact and a spam guard;
  - the website shares no session or cookie with the app.

### M6 Caregiver app v1 (Fri 2027-01-29)
- **Objective:** the nurse's daily tool as an installable app on her phone (track in §3.1).
- **Owner:** `eng`; `po` accepts with `cra`.
- **Supporting:** `uxa` (screens and components), `cra` (field gate).
- **Dependencies:**
  - M2;
  - brief **MOB1** (`po`, Fri 2026-11-27);
  - `eng` choice of delivery form in M1 (PO recommendation: installable web app on the existing `/field`, so that one code base serves phone and desktop; a native app only if M1 shows a requirement the web app cannot meet).
- **Deliverables:** login, visits, documentation and handover as one installable app; the AI assistant as rule-based intents on synthetic data (domain 10).
- **Acceptance criteria:**
  - installable on iOS and Android, opening on `/field`;
  - at 390 px each listed function is reachable within two taps from the start screen (e2e);
  - a lost connection never loses an entered value: retry is idempotent, and every command has a key (existing pattern);
  - push opt-in works where the browser allows it (D-33);
  - the AI assistant offers only listed intents, each mapped to an existing query or command, writes to the ledger and answers no free clinical question (test).

### M7 Family app specification and decision (Fri 2027-02-05)
- **Objective:** a complete, decision-ready specification of the family app. **No build:** D-40 is frozen.
- **Owner:** `po`; owner decides D-40.
- **Supporting:** `uxa` (screen specification), `lca` and `cra` (D-40 inputs), `eng` (specification impact only).
- **Dependencies:** D-40 package inputs; D-9; D-3.
- **Deliverables:**
  - a family-app specification (screens, data shown, consent model, notification rules, what AI may and may not do);
  - the D-40 package at `awaiting-approval: owner` with a recommendation.
- **Acceptance criteria:**
  - every function in §3.2 is specified with data source, consent rule and the named team role that answers;
  - `lca` and `cra` sections are in;
  - no code, table or migration exists for it (`eng` confirms).
- **Build (only if the owner approves D-40):** earliest eight weeks after approval, estimated in M1.

### M8 Operations Center v2 and AI Foundation II (Fri 2027-02-19)
- **Objective:**
  - Operations becomes a shrinking exception service on phone and desktop;
  - the AI orchestrator and the rule-based monitors exist (tracks §3.3 and §4).
- **Owner:** `eng`; `po` accepts with `cra`.
- **Supporting:** `aia`, `uxa`.
- **Dependencies:** M4; briefs **AIO1**, **OPS2**, **HAND2** (`po`, by Fri 2026-12-04).
- **Deliverables:**
  - **AIO1:** orchestrator, agent contract, evaluation harness, no provider configured;
  - **OPS2:** control health and exception grouping by rule;
  - **HAND2:** handover ordered by rule;
  - the operations app functions alerts, escalations and staffing.
- **Acceptance criteria:**
  - every AIO1, OPS2 and HAND2 criterion met with green CI;
  - an `ai` agent still cannot switch on (D-35 A, pgTAP);
  - no AI path changes a signal priority or a billable fact (tests, issue #824);
  - Operations sees only what teams did not resolve (OPS1 rule unchanged);
  - every operations function works at 390 px.

### M9 Pilot readiness (Fri 2027-03-12)
- **Objective:** NAVORA may serve its first real client and employee in the pilot organisation.
- **Owner:** `po` (readiness file), `eng` (technical readiness); the owner decides go or no-go.
- **Supporting:** `cra` (clinical gate, Clinical Owner briefing), `lca` (DPIA, information texts), `uxa` (training material screens).
- **Dependencies:** M2, M3, M4, M6, M8; every go-live gate G-1 to G-25 (`CARE_OPERATING_MODEL.md`).
- **Deliverables:**
  - pilot readiness file: each gate with its status and evidence;
  - staging and production environments (T12);
  - runbooks (incident, restore, D-1 reconciliation §5c);
  - restore test record;
  - training for the pilot team;
  - watched-hours plan (G-15).
- **Acceptance criteria:**
  - every gate that applies "before the first real client or employee" is **closed with evidence**, or explicitly waived by its owner in writing;
  - restore test done within the last 30 days;
  - DPIA signed by the licence holder;
  - Clinical Owner approved the clinical rules in use;
  - AI agents run as rules only (D-35 A unless the owner approved a stage-1 package);
  - the pilot team has done one full synthetic pilot day end to end.

### M10 Production readiness (Wed 2027-06-30)
- **Objective:** NAVORA can be operated beyond the pilot team: more teams, a second organisation, measured results.
- **Owner:** `eng` (technical), `po` (product evidence); the owner decides.
- **Supporting:** `cra`, `lca`, `aia`.
- **Dependencies:** M9 plus at least three stable pilot months; AN2/AN3 evidence; parallel runs (P-1) for any retired control; D-35 stage-1 package if language-model agents are wanted.
- **Deliverables:**
  - production operations: monitoring, alerting, on-call, backups, external security test, SLA;
  - the pilot evaluation (North Star, continuity, administration per step, safety measures);
  - the D-35 stage-1 decision;
  - the scale plan for the next teams.
- **Acceptance criteria:**
  - an external security test with no open high finding;
  - restore within the agreed time, shown;
  - a P1 signal path monitored with alerting;
  - three months of pilot figures with base counts;
  - every retired control has its parallel-run evidence;
  - the owner signs the production go-live.

---

## 2. Website track (public)

**Owner:** `po` (content, priorities), `uxa` (design), `eng` (build), `lca` (claims and privacy), `cra` (care and AI wording). German first (Basel), English second.

**Website rules:**
- No claim the product does not fulfil today.
- Hypotheses are named as hypotheses (e.g. a direct-care target).
- No medical-device claim.
- AI is described as "KI bereitet vor – Menschen entscheiden".
- Frozen or unbuilt features say "in Vorbereitung".
- No photo of a real client.

| Page | Purpose | Content (truthful status) | Design | Build | Claims review | Live |
|---|---|---|---|---|---|---|
| **Homepage** | what NAVORA is, for whom; two calls to action (demo, for nurses) | care operating system for self-organised teams; North Star direct care time; pilot in Basel | `uxa` Fri 2026-12-04 | `eng` Fri 2026-12-18 | `lca` Fri 2027-01-08 | Fri 2027-01-15 |
| **Product pages** (Team, Planning, Field, Quality, Analytics) | what each capability does today | only IMPLEMENTED features as available; PLANNED marked | `uxa` Fri 2026-12-04 | `eng` Fri 2026-12-18 | `lca` Fri 2027-01-08 | Fri 2027-01-15 |
| **Home Care page** | the home-care model | self-organised teams, continuity, less administration; benchmark only as hypothesis | `uxa` Fri 2026-12-04 | `eng` Fri 2026-12-18 | `lca` Fri 2027-01-08 | Fri 2027-01-15 |
| **Nursing Home page** | interest of design-partner homes | "in Vorbereitung; Designpartner gesucht" (D-24 #818; build after G-1, D-36, a partner ward) | `uxa` Fri 2026-12-11 | `eng` Fri 2026-12-18 | `lca` Fri 2027-01-08 | Fri 2027-01-15 |
| **AI page** | how NAVORA uses AI | the mandatory sequence; governance (ledger, confirmation, stop); what AI never does; data in CH/EU (once D-35 decides) | `uxa` Fri 2026-12-11 | `eng` Fri 2026-12-18 | `lca` + `cra` Fri 2027-01-08 | Fri 2027-01-15 |
| **Family Portal page** | announce the family layer | "in Vorbereitung" only; no sign-up and no feature promise (D-40 frozen) | `uxa` Fri 2026-12-11 | `eng` Fri 2026-12-18 | `lca` Fri 2027-01-08 | Fri 2027-01-15 |
| **Demo request flow** | qualified demo requests | form: name, organisation, role, e-mail, optional phone, message; contact consent; privacy notice; spam guard; confirmation e-mail; the data goes to the owner-chosen destination, never into the care database | `uxa` Fri 2026-12-04 | `eng` Fri 2026-12-18 | `lca` Fri 2027-01-08 (privacy notice, retention) | Fri 2027-01-15 |

**Website deliverables by role:**
- `po`: brief **WEB1** with page content outline and acceptance criteria, Fri 2026-11-20.
- `uxa`: page designs on the design system, Fri 2026-12-04 / 2026-12-11.
- `eng`: build and deployment, Fri 2026-12-18.
- `lca`: claims and privacy review, Fri 2027-01-08.
- owner: domain, hosting and demo destination, in M3.

---

## 3. Mobile app track

**Delivery form (PO recommendation, `eng` decides how in M1):** installable web apps on the one NAVORA app (UX2 shell), one code base for phone and desktop. A native app follows only when M1 names a requirement the web app cannot meet (e.g. background push on iOS).

### 3.1 Caregiver app (M6, Fri 2027-01-29)
| Order | Function | Today | Work | Done by |
|---|---|---|---|---|
| 1 | **Login** | IMPLEMENTED (web login; phone sign-in UX1-15, UX1-16) | install prompt, session on the installed app, sign-in at 390 px | Fri 2026-12-18 |
| 2 | **Visits** | IMPLEMENTED (`/field`: own visits, state machine, signals first) | app start on today's visits, two-tap reach, connection-loss handling | Fri 2027-01-08 |
| 3 | **Documentation** | IMPLEMENTED (F6/F7 report draft from facts, observations OBS1, signing) | value kept on connection loss, idempotent retry, signing at 390 px | Fri 2027-01-15 |
| 4 | **Handover** | IMPLEMENTED (HAND1 "Seit deinem letzten Einsatz") | HAND2 ordering (M8) prepared; reading at 390 px | Fri 2027-01-22 |
| 5 | **AI assistant** | PLANNED (domain 10) | fixed intents over existing queries and commands (what is next, what changed, who can cover, what is missing before I sign); rules only, synthetic data; dictation and drafting wait for D-35 stage 2 and the D-34 module | Fri 2027-01-29 (rule intents); language features not dated |

### 3.2 Family app (M7 specification, Fri 2027-02-05; build FROZEN until D-40)
| Order | Function | Content | Gate |
|---|---|---|---|
| 1 | **Notifications** | visit window, who comes, changes, to a consented named relative | D-40, D-9, D-3 |
| 2 | **Updates** | logistics facts (next visits, changes, team contact); no clinical content | D-40 |
| 3 | **Communication** | messages routed to the team as tasks; every non-logistics answer sent by a team member; AI may draft for the nurse, never answer clinically | D-40, D-35 (drafting) |
| 4 | **Wellbeing** | client-reported check-ins with question sets the Clinical Owner approved; deviations become team tasks; no AI interpretation in the core | D-40, D-39 (if sensors), G-1, D-34 |

Build dates follow the owner's D-40 decision: earliest eight weeks after approval, estimated in M1.

### 3.3 Operations app (M8, Fri 2027-02-19)
| Order | Function | Today | Work | Done by |
|---|---|---|---|---|
| 1 | **Alerts** | IMPLEMENTED (SIG1/SIG2 signals, push where allowed, OPS1 list) | role home as first tab (UX2-31), alert list at 390 px, OPS2 control health | Fri 2027-02-05 |
| 2 | **Escalations** | IMPLEMENTED (OPS1 exception centre; Operations last) | exception grouping by rule, next-step text (OPS2), at 390 px | Fri 2027-02-12 |
| 3 | **Staffing** | IMPLEMENTED in parts (COVER1, ABS1, PLAN3 after M4) | team capacity view per week, uncovered visits, cover status; never per person | Fri 2027-02-19 |

**Overall implementation order:** Caregiver (M6) → Operations (M8) → Family (after D-40).

---

## 4. AI roadmap (PLAN3, AN3, AIO1, HAND2, OPS2)

Synthetic data only; D-1, D-34, D-35 apply. The phases are specification, development, testing and pilot. "Pilot" means use in the pilot organisation after M9, with real data only once the gates allow it. These five are rules or orchestration, not language-model agents.

| Item | Specification | Development | Testing (CI + `cra` gate) | Pilot | Milestone |
|---|---|---|---|---|---|
| **PLAN3** day-plan and continuity proposal | done (approved brief) | Mon 2026-11-30 → Fri 2026-12-11 (with AIG1-C4/-C5) | → Fri 2026-12-18 | from M9 (2027-03-12) | M4 |
| **AN3** per-step spans per team | done (approved 2026-11-03; `lca` D-23 (b) read before real data) | Mon 2026-12-07 → Fri 2026-12-11 | → Fri 2026-12-18 | baseline from pilot month 1 | M4 |
| **AIO1** orchestrator, agent contract, evaluation harness | brief Fri 2026-11-20 (`po`) | Mon 2027-01-04 → Fri 2027-02-05 | → Fri 2027-02-19 | from M9, rule agents only (D-35 A) | M8 |
| **HAND2** handover ordered by rule | brief Fri 2026-12-04 (`po`) | Mon 2027-01-11 → Fri 2027-01-29 | → Fri 2027-02-12 | from M9 | M8 |
| **OPS2** control health and exception grouping | brief Fri 2026-12-04 (`po`) | Mon 2027-01-18 → Fri 2027-02-12 | → Fri 2027-02-19 | from M9 | M8 |

**Not in this roadmap:**
- language-model agents (D-35 stage 1, owner);
- dictation (stage 2);
- clinical drafting and extraction (D-34 module);
- D-39 and D-40 (frozen);
- DOC2 (not allowed yet).

---

## 5. Engineering responsibilities (`eng`)

**Due Fri 2026-11-13 (M1), in `docs/engineering/DELIVERY_ESTIMATE.md`** (issue opened 2026-11-03):
1. **Implementation sequence** for M2-M10: predecessors, what can run in parallel, and the critical path.
2. **Effort estimate** per item in person-days (agent build time and review time stated separately), with a confidence label (High, Medium, Low) and the main risk.
3. **Pilot readiness estimate:** the earliest date M9 can be met technically (T12 staging, production stack, restore test, runbooks, gates owned by `eng`), with its assumptions about M3 decisions.
4. **Production readiness estimate:** the earliest date for M10 technical criteria (monitoring, on-call, backups, external security test, SLA), with assumptions.
5. **Delivery form** of the caregiver, operations and family apps: installable web app or native, with the reason.
6. **Website build approach:** separate public site or public routes, hosting needs, and separation from the app's session and data.

**Standing during M2-M10:**
- build in the PO order;
- enforce the AI restrictions (#824);
- report each delivery in `IMPLEMENTATION_STATUS.md` with PRs and CI;
- flag any date at risk in the journal as soon as it is known.

---

## 6. UX/UI responsibilities (`uxa`)

**Due Fri 2026-11-20** (one week after M1, so it can use `eng`'s delivery form), implementation-ready, not wireframes only:
1. **Screen inventory** (`docs/design/SCREEN_INVENTORY.md`): every screen of the web app, caregiver app, operations app, family-app specification and website. Per screen: route, roles, the three questions (`DESIGN_SYSTEM.md` §1), data read, primary action, components, states, status (IMPLEMENTED or PLANNED).
2. **Navigation map** (`docs/design/NAVIGATION_MAP.md`): per role, tabs and sidebar (UX2-31, UX2-32), deep links, back paths, the website-to-app entry, and the family app as specification.
3. **Component inventory** (`docs/design/COMPONENT_INVENTORY.md`): every component with variants, states (default, hover, focus, active, disabled, loading, empty, error), accessibility notes and the screens that use it.
4. **Design system** (`docs/design/DESIGN_SYSTEM.md`, updated): tokens (colour incl. severity, type, spacing, radius, elevation, motion) as values the build consumes; dark mode if in scope; marketing extension for the website. Every token used by a component is named in the inventory.

**Then:** website page designs (Fri 2026-12-04 and 2026-12-11), caregiver app screens (Fri 2026-12-11), operations app screens (Fri 2027-01-08), family-app screen specification (Fri 2027-01-22).

---

## 7. Pilot-ready path

```text
M1 baseline (11-13) → M2 web app (11-27) → M3 owner decisions (12-11) ─┐
M4 AI Foundation I (12-18) → M6 caregiver app (01-29) → M8 operations + AI II (02-19) ─┤
M5 website (01-15, parallel)   M7 family spec (02-05, parallel, no build)                ─┤
                                                                         → M9 pilot readiness (2027-03-12)
                                                                         → 3 stable pilot months
                                                                         → M10 production readiness (2027-06-30)
```

**Critical path:** the M3 owner decisions (D-1, G-1, D-11, D-12, D-2), then T12 staging and production, then the go-live gates, then M9. Engineering work on synthetic data is not the critical path. The owner's decisions and the partner's licence are.

## 8. Reporting
- The PO updates this plan's status column weekly (Fridays) and after each milestone, with the journal entry and `ROADMAP.md`.
- Version 2 follows Engineering's estimate (Tue 2026-11-17).
- A milestone at risk is reported to the owner as soon as it is known, with the cause and the new date.

## Change log
- 2026-11-03 po: version 1, from the owner's Executive Delivery Directive.
