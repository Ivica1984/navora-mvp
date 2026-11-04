# Automation Review

**Owner:** AI & Automation Architect (`aia`, owner 2026-10-27). **Process:** [`../README.md`](../README.md), *Automation review*. **Mandate:** [`ROLE_PROPOSALS_AIA_CSA.md`](ROLE_PROPOSALS_AIA_CSA.md) (approved by the owner 2026-10-27).

**How to read this file:**
- The newest dated section comes first. Never edit an earlier section; correct it in a new one.
- Each finding is a row `AUT-<n>` with:
  - workflow step and role;
  - today's effort and its evidence (events, code, report, source);
  - verdict (eliminate, simplify, automate, AI-support, replace with a different operating model);
  - estimated direct-care time gain, at team level, labelled as an estimate;
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

**Owner priority (2026-10-27, 13:50):** the largest care-delivery bottlenecks first, each with an estimate of the direct-care time it could return. For every major bottleneck, one verdict:
- **eliminate**;
- **simplify**;
- **automate**;
- **support it through AI**;
- **replace it entirely with a different operating model**.

---

## 2026-11-04 20:20 CET · aia review 25: `cra` #859 (16:45) and #862 (17:30), `lca` #860 (16:55, D-40 / FAM1 re-check) and `uxa` #850 (15:50, 19:50) read; AUT-44 supported by all three gates with conditions (one act stands; the act must carry every consent field); AUT-45 no objection, `uxa` prefers (b); the two `lca` pilot variants supported as simplifications; AUT-46 (low: under "client consents herself only" the first consent question has one possible answer); AUT-47 (low: a later capacity re-check, if the Clinical Owner sets one, follows named events, never a periodic re-confirmation of every consent)

**Read:** `recovery/main` at `39a4883` (unchanged since my review 24, #858; no code, brief or decision merged since). Open, read on their branches:
- `cra` **#859** (16:45: CGR-128 current-slot "Verschoben", CGR-129 resend and one-act invitation never re-open access; AUT-44 supported with conditions, AUT-45 no clinical objection);
- `lca` **#860** (16:55, `decisions/D-40.md`: consent requirements (express, specific, informed, free, documented, revocable), representation UNKNOWN, staff name; AUT-44 legally neutral with one data-security condition; two pilot variants proposed to the PO);
- `cra` **#862** (17:30: CGR-130, capacity fact a required RN act, never a default or derived; revocation reason "Kann diese Einwilligung nicht mehr selbst geben"; both `lca` variants supported clinically);
- `uxa` **#850** (15:50: F-02 wording, UXR-95, UXR-96, AUT-44/-45 inputs; 19:50: CGR-128/-129/-130 wording, client information before consent, UXR-97).
- Open issues labelled `automation`: #793 (AUT-30) only. No new or changed brief (FAM1 unchanged since #856).

**Nothing below is a measurement.** I ran no tests and read no database. How often relatives phone a team about the schedule is still **UNKNOWN** (NAVORA records no calls; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10. Map item "phone coordination with relatives": first remedy PLANNED (FAM1 draft, not approvable until CGR-125 is in FAM1-6).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-46 | Relative consent step (FAM1-2, PROPOSED form `uxa` 19:50 for CGR-130 (1)): registered nurse | PROPOSED: two required radio questions without preselection, (1) "Gibt <Name> diese Einwilligung selbst?" and (2) "Hältst du <Name> für fähig, über diese Einwilligung selbst zu entscheiden?"; under the `lca` pilot variant "client consents herself only" a "Nein" on either refuses the save. Under that variant question (1) has exactly one answer that lets the act continue: it is a statement of the form's scope, asked as a question, on every consent. Question (2) is the capacity fact `cra` and `lca` require (a patient-protection and evidence control, **not challenged**). Effort: one extra answer per consent (small; estimate); the cost is the principle (no question with one possible outcome, the same reason as AUT-42) and a record field that carries no information | **simplify (rule):** if the owner takes the variant, the form states "Die Klientin / der Klient willigt selbst ein" as fixed text above the information block, the command stores `consent_given_by = client` as a constant (no input), and only question (2) is asked, required, with no preselection (CGR-130 (1) unchanged). If the owner does **not** take the variant, question (1) stays as `uxa` worded it, because it then has two outcomes. Equal safety: the stored record is identical; the capacity act stays explicit. Testable: under the variant the consent command has no input for who consented and rejects any value but `client` (pgTAP); the form renders one required question (vitest) | L (consent logistics; the capacity judgement itself is the RN's and the Clinical Owner's, not NAVORA's) | stage 0; gate: PO (FAM1-2), owner (variant), `cra` and `lca` confirm the stored fact is unchanged, `uxa` (form) | per team: acts and answers per consent record (target: one act, one answer); never per person | low | – |
| AUT-47 | Re-check of a relative consent after a change in the client's capacity (CGR-130 clinical question, UNKNOWN; FAM1-3): team | OPEN: `cra` 17:30 leaves to the Clinical Owner (after G-1) whether and when a team must re-check capacity for an existing consent and sets no trigger until a rule is approved (D-27); `lca` 16:55 (2)(d) marks the survival of a consent after a loss of capacity UNKNOWN. A common form for such a rule in consent processes is a periodic re-confirmation of every record (for example every n months), which would add one act per consent per period for every team, also for clients whose situation did not change. No rule exists yet; this finding names no trigger and no interval | **monitor, not re-confirm (form only):** if the Clinical Owner sets a re-check, the brief expresses it as a line on the team's existing exception list when an event the Clinical Owner names is **recorded anyway** in NAVORA (examples of where such events already live: a case pause and its resumption, ASM1 reassessment; which events count is clinical and UNKNOWN), showing the consent and the CGR-130 (3) revocation reason in one place; the line clears by either keeping the consent (one tap) or recording the revocation. No calendar re-confirmation of unaffected consents unless the Clinical Owner's rule requires it explicitly. NAVORA never ends or flags a consent from a score or diagnosis (CGR-130 (2), unchanged) | G if the trigger events are clinical (the Clinical Owner's rule decides); the line itself carries no clinical content | stage 0 (deterministic, on recorded events); gate: Clinical Owner after G-1 (rule), `cra`, PO | per team and month: re-check lines raised and cleared, median days open; acts per consent per year; never per person | low | – |

### 2 Briefs, plans and packages reviewed

- **`lca` 16:55 consent requirements (FAM1-2):** express, specific, informed, free, documented, revocable through any team member. Each is a legal duty, not administration to remove; their **form** fits one act: the information is four fixed sentences on the RN's screen (`uxa` 19:50), the evidence is the record itself, no signature on the sources read (cantonal form UNKNOWN, D-12). No challenge. The negative test "no view, list or count orders or flags clients by consent status" is also a guard against the AUT-45 measure growing into a consent-rate figure: supported; the measure stays on page views (FAM1-14) and the retrospective answer.
- **`lca` pilot variants ("client consents herself only"; "Ihr Pflegeteam" as default):** **supported as simplifications.** The first removes a representation form and a document check from the admission step; the second removes a per-person staff switch from every nurse's settings (`uxa` 19:50) and the wrong-name hazard (CGR-127 (3)). Cost for the measured gain, stated for the PO: `cra` 17:30 notes that relatives of clients with dementia most often want the schedule; under the first variant their calls stay with the team, so the pilot will under-show FAM1's gain. Reported, not a finding (legal reason; the owner decides through the PO).
- **Adviser questions 1, 2, 6-8 with D-9 in one round (`lca`):** supported; one round instead of two lowers PO and owner coordination.
- **CGR-128 (current-slot "Verschoben"):** a derivation rule on data already recorded; adds no act. Supported.
- **CGR-129 and `uxa` 19:50 resend:** self-service resend on the expired-link page, one answer sentence, no address field. It keeps "my link does not work" calls away from the team while closing the re-open path. Supported; identity verification with `lca` (UNKNOWN).
- **CGR-130 (1)-(3):** capacity a required explicit act, never derived; revocation reason by any RN. Patient-protection controls; their form is one required answer and one preset. Not challenged; AUT-46 on the neighbouring question only, AUT-47 on a later re-check.
- **UXR-97 (one client per sign-in or a label):** relative-side effort only; with AUT-44 each consent record is one act whichever option is taken. No finding.
- **UXR-95 (a)-(d):** two steps for a returning relative and a team-level count of failed sign-ins: supported (adoption decides whether calls fall).

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 24. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open. **CGR-130 (2)** (no AIG1 path writes the consent record; no function reads assessment, diagnosis or AI output to set, pre-fill, check or revoke the capacity fact) follows the AIR1 refusal pattern: supported and added to the AI operating model controls.

### 4 Findings: state changes and closed
- **AUT-44:** supported by `cra` (16:45, conditions CGR-129 (3)-(4): the one command refuses unless every FAM1-2 field and any capacity confirmation are present; nomination at admission optional, no preselected answer), by `lca` (16:55, legally neutral; the sign-in contact is taken in the consent conversation and bound to one relative; the invitation names no client before sign-in) and by `uxa` (15:50, one confirming step showing the scope sentence). I accept every condition: none adds an act. Waiting for the PO. Stays open.
- **AUT-45:** no clinical objection (`cra` 16:45); `uxa` 15:50 prefers (b) (no control on any nurse screen; if (a), paper). Waiting for the PO. Stays open.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-42, AUT-43, AUT-41, AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).
- Closed in this section: none.

### 5 Stage tracking (D-35 stages; changes only)
- No change. Stage 0 only in force; stage 1 not opened (provider terms written, D-34); real data blocked (D-1); adviser not named. D-39 A and D-40 (no AI on the relative path) as in review 24.

### 6 Waiting for the PO
- **AUT-44 (medium)** with the `cra` and `lca` conditions; **AUT-45 (medium)**, `uxa` prefers (b).
- **AUT-46 (low)** only if the owner takes the "client consents herself only" variant; **AUT-47 (low)** only when the Clinical Owner sets a re-check rule.
- AUT-42 (ADR-143 point 9 choice), AUT-43, AUT-41 (Clinical Owner gate after G-1), AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments
- No issue opened (no `high` finding). No PR comment: the findings concern a draft brief (FAM1) with no open PO PR; they reach the PO through this report.

---

## 2026-11-04 14:20 CET · aia review 24: owner decisions D-39 (A) and D-40 (minimal read-only relative view) and brief FAM1 draft (#856) read; FAM1 supported in substance (it removes relatives' schedule calls by rules alone); AUT-44 (medium: relative consent and invitation as one act, nominated in the intake consent conversation); AUT-45 (medium: the pilot measure asks teams to count relatives' calls); AUT-39 closed (owner decision); AUT-42 supported by `cra` and written into ADR-143 as an option

**Read:** `recovery/main` at `d31669a`:
- merged since review 23 (#854): PO **#856** (12:45: D-39 decided A; D-40 decided as a minimal option B; brief **FAM1** draft; `DELIVERY_PROGRAM.md` §0d, M7 objective now FAM1);
- open, read on their branches: `cra` **#857** (13:30: FAM1 reviewed, CGR-125 blocking for FAM1 approval, CGR-126, CGR-127), `cra` **#855** (09:30: AUT-42 supported, CGR-124), `eng` **#837** (`92d0aba`: AUT-42 (a)-(d) written into ADR-143 point 9 as an option, second-refusal stop, Playwright test), `uxa` **#850** (11:50: UXR-94; AUT-42 information line);
- open issues labelled `automation`: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. How often relatives phone a team about the schedule is **UNKNOWN** (NAVORA records no calls; FAM1 says the same; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10. Map item "phone coordination with relatives" (team self-organisation / Visit): its first remedy is now PLANNED (FAM1 draft).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-44 | Relative gets access (FAM1-2, open question 2; PLANNED, draft): registered nurse of the client's team, relative | PLANNED: a consent record per relative and client is recorded by a registered nurse (FAM1-2); how the relative is then invited and signs in is open (engineering question 2), so a second act (send a link or code) and a second contact with the relative may follow. The client's intake consent is already captured once at conversion (`intake_consent_confirmed_at`, migration 0010:130-146; D-9 option D treats sharing beyond the team as a consent item). Without a rule, the nomination is a separate conversation after intake. Effort: two acts per relative plus possibly one more visit-time conversation (estimate). The RN restriction itself is **not** challenged: `cra` 13:30 (CGR-126) ties it to the per-decision capacity judgement, a patient-protection control | **simplify, rule:** (1) recording the consent record **is** the invitation: the same command stores the record and issues the relative's sign-in (one act, one audit entry; nothing to send separately); (2) the brief names the intake/admission conversation (ADM2 team admission) as the place where relatives may be nominated, so the RN asks once while she is already confirming the client's consent; later nominations stay possible; (3) revocation stays open to every team member at once (FAM1-3, unchanged; it is the safety direction, CGR-126). Testable: pgTAP: one consent command creates the record and the invitation, refused for a non-RN; no second command exists for inviting; e2e: from the admission screen an RN nominates a relative in one step | L (logistics access; no clinical content) | stage 0 (no AI; FAM1-12); gate: PO (FAM1), `lca` (identity verification of the invitation, FAM1 question 2), `uxa` (admission step), `eng` (ADR on the principal model) | per team and month: acts per consented relative (target 1) and median days from admission to first relative sign-in; never per person | medium | – |
| AUT-45 | FAM1 pilot measure (*AI leverage*, PLANNED): team | PLANNED: "in the team retrospective, whether schedule calls from relatives fell (**counted by the team**, never per person)". A running count of incoming calls is a new administrative act for every nurse who takes one, during or between visits, for the whole pilot, to measure a gain in exactly that time. The benefit claimed is the evidence; the form (continuous counting) is challenged, not the measure | **simplify the measure:** (a) two fixed one-week tallies per pilot team, one before FAM1 is switched on and one about six weeks after, on a paper or tap tally with no names; or (b) only the retrospective question with a three-step answer (fewer / same / more), plus the page views FAM1 already records (FAM1-14, no act). Either is equal in safety (no clinical effect) and costs at most two weeks of counting instead of every week. The choice between (a) and (b) is the PO's | L | stage 0; gate: PO (FAM1 measure), `uxa` if a tally is built | per team: calls per week in the two tally weeks or the retrospective answer; relative page views per month; never per person | medium | – |

### 2 Briefs, plans and packages reviewed

- **D-39 (owner: A):** nothing added for teams. Stage-3 sensor row decided (§5).
- **D-40 (owner: minimal B) and brief FAM1 (draft):** **supported in substance.** It removes a bottleneck of map v2 (relatives phone the team to ask when the nurse comes) using facts the team already records, with no new documentation, no AI and no new task stream: eliminate through the care graph, in the design order. FAM1-4 (access ends on pause or close without anyone acting) and FAM1-7 (only recorded changes are shown) are rules instead of acts: supported. FAM1-14 audit of reads is a control without a team act: supported. Challenges on form: AUT-44, AUT-45. No act, role or field is added without a safety or legal reason beyond those two.
- **`cra` #857 on FAM1:** CGR-125 (exhaustive status mapping with one neutral word) is a patient-safety control and adds no act: supported. CGR-126 (protective revocation preset; capacity confirmed by the recording RN) is a safeguarding control; its form adds one preset choice on revocation only: supported, no challenge. CGR-127 (one access-end sentence; no cancellation reason; "Stand" time; no cached schedule) removes content rather than adding it: supported.
- **ADR-143 `92d0aba` point 9:** AUT-42 written in as an option with the second-refusal stop; `cra` 09:30 and 13:30: both forms acceptable clinically; `uxa` 11:50 line confirmed as a hint. State change in §4.
- **CGR-124 (`cra` #855, no reception offline; scheduled evaluation as a D-2 / MOB1 condition):** an evaluation by Engineering, not a team act. No finding.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 23. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open. FAM1-12 (catalogue guard: no agent, `ai_suggestions` row or AIG1 path may reference the relative principal) follows the AIR1 pattern: supported.

### 4 Findings: state changes and closed
- **AUT-39 closed** (evidence: owner decision D-40 2026-11-04, recorded in #856: messaging, direct communication with care teams and check-ins excluded from the pilot; FAM1 *Out of scope* excludes F-03 to F-06). The two team task streams AUT-39 asked to be sized are not built; if a later decision brings them back, a new finding.
- **AUT-42:** supported by `cra` (09:30, 13:30) and written into ADR-143 point 9 as an option with its test (#837 `92d0aba`); waiting for the PO's choice. Stays open.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-41, AUT-43, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 3 | Sensor inputs (D-39) | **decided A by the owner** (none in the pilot; specification only) |
| 3 | Relative channel with AI (D-40) | **AI excluded by the owner**; the relative view is rule-based (FAM1, stage 0) |
| 1, 2 | unchanged | provider terms written (D-34), stage 1 not opened; real data blocked (D-1); adviser not named |

### 6 Waiting for the PO
- **AUT-44 (medium):** FAM1: one command for consent and invitation; nomination at admission (with `lca` on identity verification).
- **AUT-45 (medium):** FAM1 measure: two tally weeks or the retrospective answer instead of a running count.
- **AUT-42 (medium):** ADR-143 point 9 choice (both forms clinically acceptable).
- AUT-43 (low), AUT-41 (Clinical Owner gate after G-1), AUT-36, AUT-37, AUT-38, AUT-33 (unchanged).

### 7 Issues and comments
- No issue opened (no `high` finding). No PR comment: FAM1 is a merged draft brief with no open PR; both findings are for the PO through this report.

---

## 2026-11-04 08:18 CET · aia review 23: AUT-41 placed by the PO as the target behind a Clinical Owner gate (open, state changed); ADR-143 CGR-123 amendment (#837 `8142bba`), `cra` #852, `uxa` #850 07:50, `lca` D-34 assessment and D-39/D-40 escalation read; AUT-42 (medium: a clock-refused observation waits for a tap before it reaches the team); AUT-43 (low: a no-show reported by phone offline is recorded again later; measure before designing)

**Read:** `recovery/main` at `d85f715`:
- merged since review 22 (#849): `lca` **#851** (D-34 detailed AI assessment; D-39, D-40 legal inputs), PO **#853** (06:10: D-39, D-40 escalated, both "approve A"; `DELIVERY_PROGRAM.md` §0c: CGR-122 (1) and CGR-123 in force, AUT-41 the target behind a gate, challenge row with a pilot hypothesis in `NEXT_CAPABILITY.md`);
- open, read on their branches: `eng` **#837** (`8142bba`: ADR-143 1c never-queued commands, 1d `FIELD_COMMAND_EFFECTS` mapping rule, 5, 6, **9 "Ohne Gerätezeit senden"**), `cra` **#852** (`e787be2`, CGR-123; AUT-41 assessed with conditions (a), (b)), `uxa` **#850** (07:50: call lines, clock-refusal card, UXR-93); code PR heads unchanged since review 22;
- open issues labelled `automation`: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. How often a nurse works without a connection, and how often a phone clock runs ahead of the server, is **UNKNOWN** (no NAVORA event records either today; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-42 | Pending observation refused on resend because its device time is later than the server time (ADR-143 9, PLANNED, #837 `8142bba`; `cra` 05:30 condition, `uxa` 07:50 card): nurse, phone | PLANNED: the refused entry is kept on her card; it reaches the team only after she sees the card and taps **"Ohne Gerätezeit senden"** (one act). Until then the observation, which may carry clinical content, is in nobody's view but hers (H-26 is the hazard `cra` named). The act decides nothing: there is only one possible outcome (send without the claim; the server time is the record's time either way, CGR-122 (2), and billed minutes are untouched, ADR-143 9). The claimed benefit (she knows the device time was discarded) is real but needs no act. Effort: one act per refusal; frequency UNKNOWN, probably rare (estimate). What is challenged is the form (a mandatory tap with one outcome), not the refusal of a late device claim | **rule instead of an act:** on a device-clock refusal, the client resends the same entry **once, automatically, without the claim**, under its original key (as ADR-143 9 already specifies for the manual act; no loop: a second refusal of any kind stops and shows the card as today). The record keeps the marker "Gerätezeit verworfen" (9) and her card shows the same line as information, with no button. The refusal itself stays: a device claim later than the server time is never stored (CGR-122, 8). Whether an automatic resend is acceptable for an entry of clinical content: `cra` (it removes the delay `cra` named; nothing changes in what is recorded). Testable: Playwright with a device clock set ahead: a pending observation is sent after reconnect with no tap, the record has only the server time and the marker, the card shows "Gerätezeit verworfen" without a button; pgTAP 9 unchanged (the refusal rolled back, no idempotency row before the resend) | L (transport of an entry; the content is the nurse's) | stage 0 (no AI); gate: `eng` (ADR-143 9 and point 2 "never retried automatically": one claim-less resend is not a retry loop), `cra` (confirms for clinical content), `uxa` (line without button), PO (MOB1) | per team and month: count of clock refusals and median time from refusal to the entry reaching the server (target: same as a normal resend); never per person | medium | – (comment on #837) |
| AUT-43 | No-show or broken-off visit offline (CGR-123, PO §0c (2), ADR-143 1c; PLANNED): nurse at the door, the teammate who takes her call | PLANNED and right in substance: these commands are never queued, so the escalation is a phone call now. After reconnecting she still records "Nicht angetroffen" or "Nicht abgeschlossen" (the visit status needs it), which creates the P1 `no_show` / `visit_interrupted` at that later server time (SIG1-C2), for a situation the team has already handled by phone. Effort (estimate, not a measurement): the fact is reported twice (call, then the entry), and a teammate may take a P1 that is already being dealt with (one more act, possibly a call back to check). Frequency UNKNOWN | **monitor first, design nothing yet.** The P1 must stay (no suppression, no AI triage of P1; hard rule). Measure from timestamps NAVORA already stores: span from `depart_visit` to `record_no_show`, and from start to `end_visit_not_completed`, per team and month (AN3 pattern, AN1 suppression, no new tap). Only if long spans are frequent in the pilot: a brief with `cra` on how a call-reported no-show is recorded once (for example the teammate who took the call records it on the visit, if the Clinical Owner allows; UNKNOWN, not proposed as a rule by `aia`) | L | stage 0; gate: PO (whether AN3 gains the two spans), `cra` (any later recording design) | the two spans above per team and month; share of `no_show` P1 signals taken within minutes of creation (already handled), per team; never per person | low | – |

### 2 Briefs, plans and packages reviewed

- **PO §0c (06:10):** CGR-122 (1) in force; AUT-41 recorded as the target with the Clinical Owner and `lca` documented-time gate and `cra` condition (b) (offline corrections distinguishable by reason kind), and a challenge row whose measure is the offline share per team and month. This is the measure-before-automating order (AUT-32) applied: **supported.** AUT-41 stays open with a new state (§4).
- **CGR-123 (`cra` #852; ADR-143 1c, 1d):** no-show, not-completed, outcome and absence never queued. A P1 waiting for the next foreground session is exactly the delay SIG1 removes; this is a safety control, not administration. **Supported.** The 1d mapping rule (a vitest derived from the migrations instead of a reviewed list) removes a recurring review act and cannot drift: **supported** as the leaner form. Follow-on cost: AUT-43 (low).
- **ADR-143 9 (clock refusal):** the in-app path `cra` asked for is right (otherwise only the phone); its form as a mandatory tap: AUT-42.
- **UXR-93 (`uxa`):** one line block per card, safety sentence first; no act added. Supported.
- **D-34 (`lca` 05:20, taken in by the PO):** the eleven provider terms and the stage-1 contents list become the D-35 stage-1 checklist; domain 10 "no open clinical Q&A" as a tested technical limit. No team act; consistent with AUT-37 (contract before switch-on). Recorded in stage tracking (§5).
- **D-39, D-40 (escalated, "approve A"):** A adds nothing for teams in the pilot. For the record of the bottleneck map: **D-40 B** (relatives see the visit time and who comes, rule-based, no AI) is the option that removes phone coordination with relatives, a team-level administration item of map v2; `aia` supports the PO's "B as the expected next step" and sets no rule. No finding.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 22. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open.

### 4 Findings: state changes and closed
- **AUT-41:** **adopted by the PO as the target design** (`DELIVERY_PROGRAM.md` §0c (3); ADR-143 1b), gated on the Clinical Owner with `lca` (documented time, UNKNOWN until G-1) and `cra` (b); CGR-122 (1) in force until then. Stays open; closes when 1b is decided either way with its measure in AN3.
- Closed this run: none.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-39, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 1 | Provider terms and stage-1 contents list | written by `lca` (D-34 assessment, 11 terms); recorded by the PO as the stage-1 checklist; stage 1 itself not opened (owner) |
| 1 | Real data to any AI path | blocked (D-1, G-25), unchanged |
| 2 | Regulatory adviser (D-34) | not named; `lca` adds adviser questions 8 (d), 8 (e), 10-12 |
| 3 | Sensor inputs (D-39), relative channel (D-40) | escalated, recommendation A (none in the pilot) |

### 6 Waiting for the PO
- **AUT-42 (medium):** one automatic claim-less resend instead of the "Ohne Gerätezeit senden" act, before ADR-143 acceptance or in MOB1 (with `cra`, `eng`).
- **AUT-43 (low):** whether AN3 gains the two no-show / interruption spans.
- AUT-41: the Clinical Owner gate (after G-1). AUT-36, AUT-37 (medium): Delivery Program version 2. AUT-38 (medium), AUT-33 (medium; #841), AUT-39 (low, D-40).

### 7 Issues and comments
- No issue opened (no `high` finding). One comment on **#837** (AUT-42; AUT-43 noted).

---

## 2026-11-04 02:20 CET · aia review 22: AUT-40 decided by the PO (closed); ADR-143 offline queue (#837) and `cra` CGR-122 (#848) read; AUT-41 (medium: CGR-122 option (1) makes every visit done without a connection cost up to three typed time corrections from memory; the PO's correction-path option gives the same billing control with no extra act)

**Read:** `recovery/main` at `7cbbf7b`:
- merged since review 21 (#844): PO **#846** (22:00: AUT-40 decided, `DELIVERY_PROGRAM.md` §0b, M6 criteria changed, CGR-113 to CGR-121 placed, `briefs/_TEMPLATE.md` CGR-119 line), `uxa` #847;
- open, read on their branches: `eng` **#837** (`7458904`, ADR-143 rewritten with CGR-121 (a)-(d), C-15 withdrawn; `APP1_IMPLEMENTATION_PLAN.md` A-07, C-03 rows), `cra` **#848** (CGR-122, inputs on ADR-143 point 1); heads of #841, #828, #814 and the UX2 PRs unchanged since review 21;
- open issues labelled `automation`: #793 (AUT-30) only; #843 closed by the PO.

**Nothing below is a measurement.** I ran no tests and read no database. Code read: `supabase/migrations/20261021000008_visit_time_corrections.sql` and `…000040…` (signature of `correct_visit_time(event, time, reason, key)`: one call per timeline event) by search only. How often a nurse works without a connection is **UNKNOWN** (no NAVORA event records it today; no study read this run). Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-41 | Visit timeline without a connection (ADR-143, M6-2, PLANNED; `cra` CGR-122 (1) and the PO option, #848): every nurse at a door without signal | IMPLEMENTED today: every command runs online; the timeline events take server `now()`. PLANNED under **CGR-122 (1)**: offline, "Losfahren", "Einsatz starten", "Pause", "Weiter", "Einsatz beenden" and the time correction are disabled; the time is recorded "only with a connection and can afterwards be corrected with a reason". So a visit given entirely without a connection costs, after reconnecting, the timeline taps at the wrong time **plus one `correct_visit_time` per event (up to three: depart, start, complete), each with a time typed from memory and a reason** (0008: one event per call). Estimate, not a measurement: about 3 extra acts and 3 typed times per offline visit, done later in the car or at home, i.e. administration moved out of the visit and a time from memory instead of a device time. The patient-care and billing benefit of CGR-122 is real (no invoice minutes from an unaudited client time; J5); **what is challenged is the form, not the control.** `cra` itself offers the leaner form as an option for the PO | **rule, not manual re-entry: take the PO option of CGR-122, with no act added for the nurse.** (a) Offline, the timeline buttons stay active; each tap is queued as a **reasoned F3 correction** carrying the device time as the claimed time and a **preset reason** set by the command kind (P-37 pattern; e.g. "Ohne Verbindung erfasst", words `uxa`), so it enters billing only through the audited correction path, exactly as CGR-122 (3) requires; (b) the server time stays the server time (CGR-122 (2)); a device time later than the server receipt time is refused (as `cra` wrote) and the entry stays on her card with its refusal, never dropped (ADR-143 2); (c) the card and the record show both times when they differ (CGR-122 (2)); (d) no new review list: an offline-claimed time is reviewed where every F3 correction already is (countersign or quality, as built; nothing added by `aia`); (e) whether the device time is the documented time stays with the Clinical Owner and `lca` (D-10, D-11, UNKNOWN); `aia` sets no rule and no tolerance. Testable: e2e with `context.setOffline`: "Einsatz starten" and "Einsatz beenden" offline, reconnect, the visit carries two F3 corrections with the preset reason and the device times, and **the nurse performed no act after reconnecting other than keeping the app open** (act count 2, same as online); pgTAP: CGR-122 (2), (3) unchanged | L (billing fact; `cra` S1 by effect) | stage 0 (no AI); gate: PO (choice between CGR-122 (1) and the option, MOB1/M6-2), `cra` (confirms the option meets CGR-122), `lca` (D-10/D-11 documentation duty, SC-2), `uxa` (preset reason words) | per team and month: share of visits with an offline-claimed time (separate from other F3 corrections in AN3-5, so the offline rate becomes visible for the first time); human acts per offline visit after reconnecting (target 0 with the option; about 3 under (1), estimate); never per person | medium | – |

### 2 Briefs, plans and packages reviewed

- **AUT-40 decision (PO 22:00, `DELIVERY_PROGRAM.md` §0b):** takes (a)-(e) of the proposal in full; M6 criteria now test ≤ 2 taps from the start screen and "reads never enter the ledger" (pgTAP). **Closed** (below).
- **ADR-143 (#837, PROPOSED):** sign-out step with "Zurück und senden" as default, entries kept on session expiry, `access_ended` entry shown with content: each prevents a lost entry that someone would otherwise have to re-collect by phone. Supported. Point 1 ("reaches another person" constant): **`cra`'s recommendation on #848 (no list, one line "Noch nicht beim Team." on every pending care entry) is the leaner form**: one line instead of a constant, its vitest and two wordings, and no drift. Supported. `take_signal`, `take_open_visit`, `accept_cover`, `withdraw_cover` online only (`cra`): a claim's value is the server's answer; supported, no finding.
- **CGR-122 (#848):** AUT-41.
- **CGR-119 (`briefs/_TEMPLATE.md`, level-H line "D-34 classification"):** one line per level-H brief, no act for any nurse or team. Supported.
- **CGR-117 (M9 waiver wording):** governance, no team act. No finding.
- **CGR-120 ("before signing" line lists only `sign_report` refusals, never "vollständig"):** consistent with AUT-40 (b); no new rule. Supported.

### 3 AI readiness of delivered items (§8)
- Nothing proposing, drafting or ranking was delivered since review 21. #814 (AIG1-C4/-C5) and #828 (AIR1) unchanged and open. The M6 pgTAP "no `ai_suggestions` row without a target field and a proposed value" is now a program criterion (AUT-40 (d)).

### 4 Findings closed
- **AUT-40 (#843):** closed with evidence: PO decision 2026-11-03 22:00 (`DELIVERY_PROGRAM.md` §0b items 1-5; M6 deliverable and criteria; §3.1 row 5), ADR-143 point 7 on #837 (C-15 withdrawn), APP1 M6-4 dropped. Issue closed by the PO.
- AUT-30 (#793), AUT-34: met on #814 and #841 heads; close on merge (unchanged).
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-39, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | "A read is not a proposal" | in the M6 criteria (pgTAP), PLANNED |
| 0 | Guards for the five prohibitions | AIR1 on #828 (open), unchanged |
| 2 | Regulatory adviser (D-34) | the brief template now refuses a level-H brief while "D-34 classification" reads UNKNOWN (CGR-119); adviser still not named |
| 1 | Real data to any AI path | blocked (D-1, G-25), unchanged |

### 6 Waiting for the PO
- **AUT-41 (medium):** choose between CGR-122 (1) and the correction-path option before the MOB1 brief (2026-11-27); `aia` proposes the option with a preset reason and no act after reconnecting.
- AUT-36, AUT-37 (medium): Delivery Program version 2 (after M1, 2026-11-13). AUT-38 (medium), AUT-33 (medium; #841), AUT-39 (low, D-40).

### 7 Issues and comments
- No issue opened (no `high` finding). One comment on **#837** (ADR-143: AUT-41, and support for `cra`'s "no list" on point 1).

---

## 2026-11-03 20:30 CET · aia review 21: Delivery Program M1-M10 (#832), UX/UI baseline (#834, #836) and open plans read; AUT-40 (high: the M6 caregiver "Assistent" is a second screen that answers only questions the start screen already answers, so it adds taps and ledger rows without a care benefit); AUT-34 met on #841 (AN3); AUT-33, AUT-36, AUT-37 not taken into the program; AIR1 (#828) supported

**Read:** `recovery/main` at `c46010a`:
- merged since review 20 (#829): PO **#832** (`DELIVERY_PROGRAM.md` M1-M10, owner *Executive Delivery Directive* 2026-11-03), `uxa` **#834** (`NAVORA_INFORMATION_ARCHITECTURE.md`, `NAVORA_SCREEN_CATALOG.md`, `NAVORA_DESIGN_SYSTEM_V1.md`), PO **#836** (baseline adopted, UX2-33), `uxa` #839;
- open, read through PR text and file list: `eng` **#841** (AN3, migration 0108, head check runs app, db, ui-screenshots `success`, e2e not finished per GitHub), **#837** (`APP1_IMPLEMENTATION_PLAN.md`, `WEB1_IMPLEMENTATION_PLAN.md`; read `APP1` lines on C-15 on its branch), #835 (`DELIVERY_ESTIMATE.md`), #833 (`IMPLEMENTATION_SEQUENCE.md`), **#828** (AIR1, migration 0107), #840, #838; #814 still open (mergeable `clean`), #815, #813, #810, #809, #806, #804, #803, #800, #799; `cra` #842, #819, #812;
- open issues labelled `automation`: #793 (AUT-30) only.

**Nothing below is a measurement.** I ran no tests and read no database. Docs read: `DELIVERY_PROGRAM.md` header, M4, M6-M8, §3, §4, §7 in full; screen catalog C-01, C-11, C-15 to C-17, O-01 to O-03 (lines); `src/app/(protected)/field/report-section.tsx` and `src/features/field/todo.ts` by search only. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-40 | M6 caregiver app item 5 "AI assistant" (`DELIVERY_PROGRAM.md` §3.1, M6 criteria; AI-first update §5 domain 10; screen catalog **C-15** `/field/assistent`; `APP1_IMPLEMENTATION_PLAN.md` M6-4 on #837): every nurse on her phone | PLANNED. C-15 is a separate screen with four intents, and per the catalog and the APP1 plan each one reads **only an existing reader**: "Was steht als Nächstes an?" → `field_visits` + `my_signals` (the content of C-01 "Heute", the app's start screen); "Was hat sich geändert?" → `field_since_last` (HAND1, already on each visit card, C-16 tap 2); "Wer kann übernehmen?" → `team_open_visits` (COVER1, already behind "Ich kann nicht arbeiten" and on the team screen); "Was fehlt vor dem Unterschreiben?" → `field_reports` completeness (the report section signs at completion in one confirmation, F7; in my search I found no "what is missing" line on it, so whether one is needed is UNKNOWN). Path via the assistant: tap "Assistent", tap intent, read, tap the link to act = **3 taps** for an answer the start screen shows at 0-1 taps. The M6 criterion also writes **every answer and its intent to the AIG1 ledger**: a read is not a proposal, has no confirmer and no correction, so these rows enter the ledger whose correction rate per agent and field is the stop rule (§8). **Patient-care benefit claimed: none shown** (domain 10 names the intents, not a removed step); engineering cost dated 2027-01-22 (M6-4) | **eliminate the extra screen at stage 0; place each answer where the question arises:** (a) no C-15 and no `IntentList` in M6; (b) "Was fehlt vor dem Unterschreiben?" as a deterministic line on the report section next to "Unterschreiben", only if `cra` and the PO name a completeness rule (UNKNOWN; not `aia`'s to invent); (c) the other three stay on C-01, the visit card (HAND1) and the absence flow (COVER1) as built; (d) the AIG1 ledger records proposals only, never reads; (e) an assistant entry point returns with the first intent no screen can answer (dictation or drafting, D-35 stage 2 and the D-34 module), and then its brief states the step it removes and the act count before and after (AUT-38). Testable: the M6 e2e reaches each of the four answers from the start screen in ≤ 2 taps at 390 px without a separate route; pgTAP: no `ai_suggestions` row exists without a proposed value and a target field | L | stage 0; PO (M6 scope, MOB1 brief), `uxa` (C-01 placement), `cra` (the completeness rule and the "keine medizinische Beratung" line, if anything remains), `eng` (APP1 plan) | taps from start screen to each answer (e2e, before and after); AIG1 ledger rows that are reads (target 0); engineering days not spent on M6-4 (DELIVERY_ESTIMATE) | **high** | #843 |

### 2 Briefs, plans and packages reviewed

- **Delivery Program M1-M10 (#832, merged):** dates are PO targets; the binding rules repeat the mandatory sequence, D-35 A and the D-39/D-40 freeze. Supported in structure. Automation points:
  - **M4 (PLAN3, AN3, AIG1-C4/-C5):** matches AUT-32/AUT-30. Supported.
  - **M8 AIO1 deliverable "orchestrator, agent contract, evaluation harness, no provider configured":** **AUT-37 not taken in** (the orchestrator and an adapter without a provider are still in M8). Stays open for the PO.
  - **§4 AI roadmap:** no day-order rule (map rank 1, travel and day order). **AUT-36 not taken in.** Stays open.
  - **M6 item 5:** AUT-40.
  - **§3.2 family app, Communication "messages routed to the team as tasks" and Wellbeing "deviations become team tasks":** two new task streams for the team, frozen (D-40). Covered by **AUT-39** (team tasks per 100 clients and week stated in the D-40 package; default no check-in). No new finding.
  - **§3.3 Operations "Staffing: team capacity view per week, never per person":** supported (team level, no ranking).
- **UX/UI baseline (#834, #836):** C-11 "Vorschläge" with `ProposalLine` and a `BulkConfirmBar` "when ≥ 1 tick": consistent with AIG1-5 (ticked list only for `schedule` fields; no accept-all on listed fields). C-17 PLAN3 shows load "never judged"; O-02 has no person column. Supported. The landing text lists all seven steps of the sequence: AUT-38 (one act for steps 5-6) applies to the screens, not only the method text.
- **AN3 on #841 (open):** **AUT-34 met** ((b) is the AN2 `countersign_latency_hours` beside `report_returned_share`, ADR-144 deviation 1). **AUT-33 not met:** spans only, no act counts per 100 visits; the PO approved AN3 without it. One comment on #841.
- **AIR1 on #828 (open):** a register trigger refuses billing and safety-signal-priority targets, catalogue checks that no function writes the ledger's targets, no `ai` agent registered. Removes no step and adds none for any nurse; it makes prohibitions 1 and 3 of the owner directive testable. Supported; no finding. I ran none of its tests.
- **#833, #835, #838, #840:** sequence, estimate, hosting and status documents; read by title and file list only; no automation finding claimed.

### 3 AI readiness of delivered items (§8)
- **#814 (AIG1-C4 + C5):** unchanged since review 20, still open; AUT-30 closes on merge.
- **#828 (AIR1):** guards only; no agent proposes. §8 rows "no accept-all", "named confirmer" unaffected.
- **C-15 (PLANNED):** fails §8 "correction rate per agent and field" as specified, because reads would enter the ledger without a decision (AUT-40 (d)).

### 4 Findings closed
- **AUT-34:** met on #841 head; closes on merge.
- AUT-30 (#793): met on #814 head; closes on merge.
- Open, unchanged: AUT-33, AUT-35, AUT-36, AUT-37, AUT-38, AUT-39, AUT-21, AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13).

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | Guards for the five prohibitions (#824) | AIR1 on #828 (open, PLANNED until merged) |
| 0 | Baseline for ranks 1-3 | AN3 built on #841 (open); act counts (AUT-33) OPEN |
| 0 | Delivery dates | PLAN3 and AN3 M4 2026-12-18; AIO1, OPS2, HAND2 M8 2027-02-19 (PO targets, not commitments) |
| 1 | Real data to any AI path | blocked (D-1, G-25), unchanged; M3 owner decisions 2026-12-11 are the critical path (program §7) |
| 2, 3 | Regulatory adviser (D-34), Clinical Owner (G-1) | not named, unchanged |

### 6 Waiting for the PO
- **AUT-40 (high):** answer before the MOB1 brief (2026-11-27): drop C-15 at stage 0 or name the patient-care benefit it adds.
- AUT-36, AUT-37 (medium): not taken into the Delivery Program; version 2 (after M1, 2026-11-13) is the next place.
- AUT-38 (medium), AUT-33 (medium; #841), AUT-39 (low, D-40 package).

### 7 Issues and comments
- **#843** opened for AUT-40 (labels `agents`, `agent:po`, `automation`); no duplicate found among open issues.
- One comment on **#837** (APP1 plan M6-4, AUT-40) and one on **#841** (AUT-33 open, AUT-34 met).

---

## 2026-11-03 14:40 CET · aia review 20: AI-first architecture update (#822) and owner directive 14:00 reviewed; opportunity-map ranking challenged (AUT-36, medium: the largest bottleneck, travel and day order, is missing from the ranking); AIO1 narrowed (AUT-37, medium); the seven-step sequence must not add acts (AUT-38, medium); D-40 Check-In adds team tasks (AUT-39, low); AUT-32 closed (AN3 approved); AUT-30 met on #814 head

**Read:** `recovery/main` at `41ec907`:
- merged since review 19 (#811): PO **#822** (13:45 *AI-first* and 14:00 *post-PR #822 alignment*: `AI_FIRST_ARCHITECTURE_UPDATE.md`, `AI_OPPORTUNITY_MAP.md`, `AI_CAPABILITY_ROADMAP.md`, brief template *AI leverage*, `NEXT_CAPABILITY.md` rule *AI-first review*, **AN3 approved**, D-39 and D-40 opened and frozen, allowed list PLAN3, AN3, AIO1, OPS2, HAND2 on synthetic data), `csa` #821 (STR-20 to STR-25), `lca` #823 (Basel-Stadt checks for D-2, D-4, D-9, D-29), `uxa` #798;
- open: `eng` **#814** (AIG1-C4 + AIG1-C5, migration 0105, head `dc1b2b4`; check runs app, e2e, db, ui-screenshots all `success` per GitHub, I ran none), #815 (ASM1-C6), #813, #810, #809, #806, #804, #803, #800, #799; `cra` #819, #812; read through their PR text;
- open issues: #793 (AUT-30), **#824** (`eng`: enforce the five prohibitions), **#826** (D-39), **#827** (D-40), #817 (owner spec).
- The PO asked `aia` (JOURNAL 13:45) to challenge the opportunity-map ranking at this review. Done in AUT-36.

**Nothing below is a measurement.** I ran no tests and read no database. Docs read: the three new product documents in full except the update's §6 and §7, `briefs/AN3.md` (14:00), `briefs/_TEMPLATE.md`, `decisions/D-39.md`, `decisions/D-40.md` (summaries), `NEXT_CAPABILITY.md` lines 1-45. Bottleneck map v2 (review 18) stands; next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-36 | Opportunity-map ranking (`AI_OPPORTUNITY_MAP.md` §3, PO 2026-11-03): the PO choosing what is built next; every nurse (rank 1 of the bottleneck map) | The ranking orders by the owner's value list and "can run before D-35 stage 1", not by direct-care time recoverable. Compared with map v2 (review 18): **map rank 1, travel and day order, does not appear in the ranking at all** (A3 is named only under §2.3 *Assist* and §2.11, with Q7 and D-11 as gate); map rank 2 (documentation) is ranking 7 (DOC2, not in the owner's allowed list); map rank 3 (orders, referrals) is ranking 6 and 9. Ranking places 1-5 are PLAN3 (map rank 4), AIO1 (no step removed by itself), AN3 (measure), OPS2 (exceptions handled by Operations, not by nurses at the bedside) and HAND2 (handover ordering: the digest exists, HAND1). So the five items allowed now touch none of the three largest estimated bottlenecks. Each of those waits for an owner, legal or clinical decision (Q7 still OPEN; D-11 answered by the owner to `lca` as Basel-Stadt, JOURNAL 13:55, the PO records it; D-10 with G-1; D-22, D-9, D-3). IMPLEMENTED: AN1 travel minutes within visits; nothing that orders a day | **re-rank by recoverable time, keep safety as precondition**: (a) add a column "bottleneck-map rank (estimate)" to §3 so the value order and the time order are both visible; (b) add **day order of one nurse's own confirmed visits** (AUT-5) to §3 as a stage-0 deterministic rule on **synthetic geography only** (seed coordinates, no real address or location, no travel tracking), proposal confirmed by the nurse in one act, never per-person comparison; its real-data release waits for Q7 (`lca`) and the Basel geography (D-11); (c) the PO asks the owner, in a package, whether this rule joins the synthetic-data list, since it is not in it today. Testable: on the seed, the rule returns an order for a nurse's day within the visits' windows, never moves a visit outside its window, writes each proposal to the AIG1 ledger with field class `schedule`, and reads no location of a person | L (order of a person's own logistics; no clinical content) | stage 0, synthetic; gates: owner (allowed list), `lca` (Q7 before real data), labour-law rules; `uxa` (one-act confirmation) | AN1 travel share per team and month before and after (AN3 baseline); share of proposals confirmed unchanged (AIG1) | medium | – (report; PO answers in its next cycle) |
| AUT-37 | AIO1 (proposed brief, roadmap §3.1 item 2; ranking 2): Engineering; later every agent | Proposed scope: a server-side orchestrator pipeline (scope check, minimisation, model or rule, schema validation, source-per-claim check, ledger write), an agent contract table, an evaluation harness in CI, a provider adapter with **no provider configured** (D-35 A). Every agent allowed now is a **rule** (PLAN3, OPS2, HAND2); minimisation and source-per-claim checks are for language output, which D-35 A forbids on real data until the owner's stage-1 package. IMPLEMENTED already: agent register and stop table (AIG1-1), field classes and one-by-one list (AIG1-5), ledger with input reference, version and confirmer (0097), look-back (0103, 0104), expiry (0105 on #814, open). Patient-care benefit claimed: safety of later agents ("7, safety"). No direct-care step is removed by AIO1 itself | **simplify**: split AIO1. Build now (supports §8 readiness): (i) the agent contract as columns or a versioned document per row of the existing AIG1 register (purpose and removed step, trigger, input scope, output schema, level, confirmer, stop rule, never-list), refusing to switch on an agent without one; (ii) the **evaluation harness in CI** for PLAN3 on synthetic cases (correction rate per field, unchanged-confirmation share, expired share), run per agent version. Defer to the D-35 stage-1 package: the model call step, minimisation, source-per-claim validation and the provider adapter, designed when the first language agent, its provider and region are known (an adapter built against no provider fixes an interface before its constraints exist). Testable: an agent without a contract cannot be switched on (pgTAP); the harness fails CI when an agent version's correction rate on its synthetic set rises above its written threshold | L | stage 0; PO (brief scope), `eng` (ADR), `lca` (contract fields that touch D-35 terms) | no added engineering surface without a running consumer; harness run per PLAN3 version | medium | – (report) |
| AUT-38 | Mandatory sequence "AI prepares → Human reviews → Human decides → Human signs" (update §0, §3; template *AI leverage* steps 5-7): every confirmer, every brief | The owner directive makes review, decision and signature explicit. Read literally as three acts, it would add administration to proposals that today take one: PLAN3 confirms a `schedule` line in one act (AIG1-5 allows a ticked list for `schedule` fields); WORK1 confirms a proposed day once; AN3's own *AI leverage* answers "nothing is signed". §3 step 7 says "which signature or required approval does the law or the Clinical Owner demand?", which allows "none", but neither §3 nor the template says so, and the template asks "which signature or required approval **stays**", which presumes one. No patient-care benefit is shown for a separate review act or a new signature on a logistics proposal; the safety control is that a named person who can reject confirms with the sources in view (AIG1-3), which one act already gives | **keep the control, not the act count**: one sentence in update §3 and the template (PO): "Steps 5 and 6 are one act by the named confirmer, with sources and 'nicht gefunden' in view, unless a law or the Clinical Owner requires a second person; step 7 names an existing or legally required signature and may be 'none'; the AI-first method never adds a signature, an approval or a review step that did not exist before the AI." The never-list (no accept-all on listed fields, AIG1-5) stays. Testable: every brief's *AI leverage* states the number of human acts per proposal before and after; the PO marks `changes-requested` a brief whose count rises without a named safety or legal reason | L (method text) | stage 0; PO (method text), `cra` (whether any clinical field needs two persons; UNKNOWN until the Clinical Owner, D-17 part 3), `uxa` | human acts per 100 proposals per team (AUT-33 act counts) | medium | – (report) |
| AUT-39 | D-40 Check-In Services (domain 4; frozen, specification only): primary nurse, team | Spec (update §5.2 domain 4): the RN chooses each client's questions from a Clinical Owner set; an answer outside the approved band becomes a **team task**. That is a new per-client selection act and a new task stream for the team, with no estimate of volume and no stated care benefit beyond "between visits nobody knows how the client is" (map §1 row 17). Bands and question sets are clinical (UNKNOWN; Clinical Owner, G-1). Frozen: nothing is built | **challenge the form, not the existence** for the specification: (a) the D-40 package states the expected team tasks per 100 clients per week on synthetic data and who closes them; (b) default is no check-in; a check-in is set only where the care plan names a reason; (c) the first scope is logistics only (visit confirmation, who comes), which needs no band; (d) never a P1 signal unless the Clinical Owner makes it one (as written). No proposal for clinical items, bands or thresholds (not `aia`'s to invent) | L (logistics part) · H (interpreting answers) | frozen (owner); D-40, D-9, D-34 module, Clinical Owner, `lca` | team tasks created and closed per 100 clients and week; calls from relatives before and after (UNKNOWN today: calls are not recorded) | low | – (report; noted for #827) |

### 2 Briefs and items reviewed

- **Owner directive 14:00 (human-in-the-loop, five prohibitions, D-39/D-40 freeze):** consistent with every rule in `aia`'s mandate (no P1 triage, no per-person scoring, no automatic coding or billing, no general copilot, no unconfirmed entry). Supported. AUT-38 concerns only how many acts the sequence costs.
- **AI-first update §1 point 3 ("an agent that re-types, chases or summarises fragmented information is worse than a record where it is never fragmented"):** this keeps the care graph before the agent and matches the earlier order. Supported. **§3 step 4** widening AI to "any decision inside the graph" is acceptable because steps 5-7 and AI-3 keep the named confirmer; `aia` watches that each agent still names the step it removes (AI-12).
- **AN3 approved (PO 14:00):** answers AUT-32 (closed below). **AUT-33 and AUT-34 not taken in** (no "per 100", no reuse of `countersign_latency_hours` in the brief). Roadmap §5 measures "administration removed per step" by AN3 **spans**; an elimination removes acts, so the roadmap's own measure needs AUT-33. Both stay open for the PO.
- **OPS2, HAND2 (proposed briefs, not written):** both are rules over existing data; no step added for nurses. When written, `aia` checks: OPS2 groups exceptions so Operations sees fewer lines, never re-orders P1 signals (AI-10); HAND2's "unread before start" stays a fact on the card, never a blocking gate before a visit (a gate would add a step at the door).
- **D-39 (sensors):** frozen; no automation finding. Any sensor-derived billing stays out (prohibition 1).
- **#814 (AIG1-C4 + C5, open):** see §3.

### 3 AI readiness of delivered items (§8)
- **#814 head `dc1b2b4` (not merged):** answers AUT-30 in code: OPS1 `agent_stopped` per stop with at least one open line whatever the agent's state, closes at "0 offen"; expired proposals filtered on read and refused by `confirm_suggestion` as `not_open`, so an expiry can never be counted as a rejection (correction rate per agent and field stays honest); expired counted apart in `agent_health`. No person column added. Ledger stays append-only. **§8 check: met on the PR head**; AUT-30 closes on merge. CI success on all four check runs per GitHub; I ran no test.

### 4 Findings closed
- **AUT-32 closed:** AN3 approved (PO 2026-11-03 14:00, *Next up* 3), per-step baseline on synthetic data before G-19; real data waits for `lca`'s D-23 term (b) read.
- **AUT-30:** met on #814 head; closes on merge (#793 then closable by the PO).
- AUT-33, AUT-34, AUT-35, AUT-21 (#809 open), AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38), AUT-31 (PLAN3-13): unchanged.

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1-C4/-C5 before the first agent other than the synthetic test agent | built on #814 (open, CI green per GitHub) |
| 0 | Baseline for ranks 1-3 | AN3 **approved** (PLANNED, *Next up* 3); act counts (AUT-33) OPEN |
| 0 | Agent contract and evaluation harness (AIO1) | PLANNED; brief not written; scope challenged (AUT-37) |
| 0 | Synthetic-data allowed list | PLAN3, AN3, AIO1, OPS2, HAND2 (owner 14:00); day order not in it (AUT-36) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1, G-25), unchanged |
| 1 | Owner releases stage 1 (provider, region CH/EU, contract, DPIA) | not decided; roadmap §4 item 1 asks the owner to open the package |
| 2 | Regulatory adviser on level G (D-34) | not named; `lca` D-34 AI assessment requested (14:00) |
| 3 | Clinical Owner (G-1) | not named |

### 6 Waiting for the PO
- **AUT-36 (medium):** whether the ranking gets a recoverable-time column and whether a day-order rule on synthetic geography goes to the owner for the allowed list.
- **AUT-37 (medium):** AIO1 scope: contract on the AIG1 register plus evaluation harness now; orchestrator pipeline and provider adapter with the stage-1 package.
- **AUT-38 (medium):** one sentence in the method and the template: steps 5-6 are one act; step 7 may be "none"; the method never adds an act.
- **AUT-33, AUT-34:** AN3 approved without them; take in at the ADR or a brief amendment.
- AUT-39 (low) for the D-40 package (#827); AUT-30 (#793) closable when #814 merges.

### 7 Issues and comments
- No `high` finding: no issue opened. One comment on decision issue **#827** (D-40, AUT-39). No open PR carries an `aia` finding.

---

## 2026-11-03 08:20 CET · aia review 19: AN3 draft (P-19, answer to AUT-32) supported with AUT-33 (medium: spans measure waiting, not work; add act counts per 100 visits) and AUT-34 (low: AN3-1 (b) and AN3-5 already IMPLEMENTED as `countersign_latency_hours` beside `report_returned_share`, reuse); AUT-35 (low: a typed reason on the first qualification at admission, #809); RLS4-C3, UX2-31/-32, #803/#804/#806 without finding

**Read:** `recovery/main` at `6d6dbba`:
- merged since review 18 (#802): PO **#808** (06:30: RLS4-C1/-C2 met, RLS4-C3; CGR-108/-109 into UX2-27/-29 and G-25 (c); UX2-31, UX2-32; **AN3 drafted** from P-19 after AUT-32), `lca` #805 (D-1 re-check on CGR-109);
- open: `eng` #803 (UX2-15/-16/-25), #804 (UX2-18 to -21), #806 (UX2-30), **#809 (UX2-26, from AUT-21)**, #799, #800; `cra` #807, #801; `uxa` #798; read through their PR text;
- open issues labelled `automation`: #793 (AUT-30; adopted as AIG1-C5, open until built).

**Nothing below is a measurement.** I ran no tests and read no database. Code read: `supabase/migrations/20261021000027_pilot_impact.sql`, `…0032_an1_changes.sql` (`pilot_kpis(p_month)`), `…0065_f6r_return_report.sql` (F6R-9 measures), `…0018_reasons_and_qualification.sql` (`set_member_qualification`), `briefs/AN3.md` (06:30), `briefs/RLS4.md` (06:30), `briefs/UX2.md` (06:30). The bottleneck map is v2 (review 18); next refresh 2026-11-10.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-33 | AN3 (P-19, draft): the team and the PO, measuring ranks 1-4 of the map | AN3-1 measures five **spans** (elapsed calendar time between two timestamps). A span shows waiting, not work: a report signed 4 h after the visit may cost 3 minutes; a countersign done in 10 minutes still costs a registered nurse one act per report. When a step is **eliminated** (rank 2: countersign scope under D-10; rank 3: structured orders under D-22; rank 4: PLAN3 proposals instead of setting the responsible nurse visit by visit) the span disappears or changes meaning, so it cannot show the gain. What an elimination removes is **acts**, and NAVORA already records each act: `countersign_report` per report (0016, 0065), ORD0 tasks per order (0061), `take_open_visit` (0046) and the `care_visits` audit trigger (0012) for responsible-member changes, the AIG1 ledger per proposal (0097, 0103, 0104), time corrections (`time_correction_share`, AN1). IMPLEMENTED: the acts and their timestamps. OPEN: whether the audit rows distinguish a manual responsible-member change from a confirmed AIG1 proposal (UNKNOWN until Engineering names the column) | **automate the measure** (deterministic, read-only): add to AN3-1, per team and month with AN1 suppression, the **count of administrative acts per 100 completed visits** for each step AN3 already lists: (i) countersignatures, (ii) returned reports (exists as share, F6R-9), (iii) ORD0 tasks opened, (iv) responsible-member changes made by hand vs through a confirmed proposal, (v) AIG1 proposals changed or rejected (the §8 correction rate per agent and field, team level). No new column, table, field or tap; same "never per person" (AN3-3) and "no target" (AN3-5) rules; where a source cannot separate (iv), Engineering says so in the ADR and leaves it out | L (team counts of recorded acts; no clinical content) | stage 0; gate `lca` (D-23 term (b), as AN3 already names), PO | for each later elimination: acts per 100 visits for that step before and after, beside the WORK1-6 care share (estimate of time freed = acts removed × minutes per act, minutes per act stays UNKNOWN until observed in the pilot) | medium | – (report) |
| AUT-34 | AN3-1 (b) and AN3-5 (countersign span, shown beside returned reports) | **IMPLEMENTED** since F6R (0065, F6R-9): `pilot_kpis` returns `countersign_latency_hours` (median, first signature to countersignature, returns included) and `report_returned_share`, per team and organisation, with AN1 suppression and the note "Evidenz für D-10 …" (no target word). AN3-1 (a) says "reuse, do not duplicate" for the report span; (b) does not. A second definition of the same span would let two figures for one step disagree (e.g. returns counted in one, not in the other) | **eliminate the duplicate**: AN3-1 (b) and AN3-5 reuse `countersign_latency_hours` and `report_returned_share` as built (F6R-9), adding only what AN3-5 adds (open time corrections beside them); the AN3-5 string test runs over the existing note | L | stage 0; PO (brief text), `cra` (AN3-5 wording, already given 05:30) | one definition per span: the AN3 ADR maps each AN3-1 figure to one `pilot_kpis` measure name | low | – |
| AUT-35 | Admission: administrator sets the qualification in the same sitting as the contract (UX2-26, #809, from AUT-21) | #809 (open) puts the qualification on the "Vertrag erfasst" card, as AUT-21 proposed (one sitting instead of two). The existing command `set_member_qualification(…, p_reason, …)` (0018, IMPLEMENTED) needs a typed reason of 3–300 characters, so every admission carries one free-text field whose content at a **first** setting is predictable. The qualification is a safety control (it decides the countersign duty, 0016): its existence, actor, time and audit row are not in question; its **form** is | **simplify**: for the first setting in the admission sitting, a preset reason (as P-37 does for correction acts), e.g. "Bei Vertragserfassung festgelegt", the administrator may overwrite it; every **later change** keeps a typed reason. Wording `uxa`; whether a preset reason meets the audit purpose `lca`/`cra` | L | stage 0; gate `uxa`, `lca`, `cra` (qualification gates countersign) | free-text fields per admission (team level, from the audit rows of the admission sitting) | low | – (does not block #809) |

**Briefs and items reviewed without a new finding:**
- **AN3 as a whole (draft):** answers AUT-32 as proposed: read-only, no new tap or field, never per person, AN1 suppression, `lca` before approval, built before G-19 so the first pilot month is the baseline. AN3-2 (travel beside the care share, labelled as within-visit travel only) is the honest limit for rank 1. Supported with AUT-33 and AUT-34.
- **RLS4-C3:** "Erneut laden" on a failed read and an honest result line; access end stays possible without the list. That is the leaner choice at equal safety (no hold on a leaver's access for a read). No step added. Supported.
- **UX2-31, UX2-32:** the role's home as first tab and one name per destination remove navigation and a translation step. Supported.
- **UX2-27/-29 amendments (CGR-108, CGR-109), G-25 (c):** display text; "nicht erfasst" claims no absence. No step added. The PO's challenge (06:30: a closed visit's record should answer "who cared" from the report, not "who was planned") is the care-graph answer: the fact exists in the signed report, so nobody has to fill the planning field afterwards. Supported.
- **#803, #804, #806 (UX2 parts 4 to 6, open):** presentation only. #806 prefills the instrument on the replace form only when exactly one catalogue entry is valid: less typing, no guess. No step added.

### 2 AI readiness of delivered items (§8)
- Nothing merged since review 18 proposes, drafts or ranks. No §8 check due. AUT-33 (v) would give the §8 correction rate per agent and field a team-level home on `/analytics` once PLAN3 runs.

### 3 Findings closed
- None. **AUT-32:** answered by the AN3 draft; closes when AN3 is approved (after `lca`). **AUT-21:** built on #809 (open); closes on merge. AUT-30 (AIG1-C5) and AUT-31 (PLAN3-13) close when built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-25, AUT-28 (P-38): unchanged.

### 4 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | Baseline for ranks 1-3 (AUT-32) | **PLANNED as draft** (AN3, PO 06:30); waits for `lca` (D-23 term (b)), then *Next up* after PLAN3, before G-19 |
| 0, 1 | all other rows | unchanged from review 18 |

### 5 Waiting for the PO
- **AUT-33 (medium):** whether AN3-1 adds act counts per 100 visits (i)-(v) before `lca` reads the draft, so `lca` reads one version.
- **AUT-34 (low):** AN3-1 (b) and AN3-5 reuse the F6R-9 measures.
- **AUT-35 (low):** preset reason on the first qualification at admission (with `uxa`, `lca`, `cra`); not a reason to hold #809.
- AUT-30 / AIG1-C5 and AIG1-C4 to build; P-36 undo alternative (review 15), AUT-19, AUT-20 as before.

### 6 Issues and comments
- No `high` finding: no issue opened. AUT-35 is low and does not block #809, so no PR comment; AN3 has no open PR or decision issue.

---

## 2026-11-03 02:40 CET · aia review 18: bottleneck map v2 (weekly refresh); AUT-27 closed (RLS4-C1 built, #792); AUT-30 adopted as AIG1-C5, AUT-31 into PLAN3-13; UX2-1 shell (#799) and UX2-27/-29 (#800) without finding; AUT-32 (medium: the three largest bottlenecks have no build path and no per-step baseline)

**Read:** `recovery/main` at `a321e6c`:
- merged since review 17 (#794): PO **#791** (02:25 and addendum 02:55: AIG1-C4, **AIG1-C5 from AUT-30**, PLAN3-11 keyed on open lines, PLAN3-13 with AUT-31), **#792** (RLS4-C1 runbook §5c, RLS4-C2 `/admin`; pgTAP 105), #795, `lca` #797;
- open: `eng` **#799** (UX2-1 shell, ADR-131) and **#800** (UX2-27, UX2-29, ADR-132), `cra` **#801** (01:30: CGR-101, CGR-105 closed; #799 gate clear; CGR-108, CGR-109 on #800), `uxa` #798 (UXR-72 to -74), #796, and the earlier `cra` chain; all read on their branches through their PR text and file lists;
- open issues labelled `automation`: #793 (AUT-30; adopted, open until built).
- No repository activity from 2026-10-31 03:51 to 2026-11-03 01:10.

**Nothing below is a measurement.** I ran no tests and read no database. CI states are as the PRs and `cra` #801 report them; not re-read by me. Code and docs read: `docs/engineering/OWNER_RUNBOOK.md` §5c, `briefs/AIG1.md` (02:55), `briefs/PLAN3.md` (PLAN3-7, -11, -13), `briefs/WORK1.md` (WORK1-5, -6), `briefs/AN1.md`, `NEXT_CAPABILITY.md` (challenge rows P-19, P-20, P-28, P-32, P-38), `OPEN_DECISIONS.md` (D-3, D-9, D-10, D-11, D-17, D-22, D-28, D-37, Q7).

### 1 Bottleneck map v2 (weekly refresh; v1 review 1, 2026-10-27; from-scratch reading review 5)

**Published evidence:** [E1] and [E2] as in review 1 (not re-read). **[E3]** read 2026-11-03: *Kennzahlen der Hilfe und Pflege zu Hause SPITEX 2017/2018* (Gesundheits- und Fürsorgedirektion des Kantons Bern, on the BFS Spitex statistics; <https://www.gsi.be.ch/content/dam/gsi/dokumente-bilder/de/themen/statistiken/sozialmedizinische-institutionen/DA_Kennzahlen_SPITEX_2018_bis_2017_d.pdf>). It gives billed hours and full-time positions per year but, by its own scope, the two cannot be combined into a billable or direct-care share (billed hours cover some services only; positions include administration). **A Swiss direct-care or documentation share for home care therefore stays UNKNOWN** to `aia`; no Swiss figure is used below.

**Rank** = estimated direct-care time recoverable at team level, 1 = largest (estimate, ordinal, unchanged from v1 unless stated). **Moved this week** = what changed in the product since 2026-10-27.

| Rank | Step (role) | Moved this week (status) | What still costs a person time | Verdict (from scratch) | What unblocks it | Finding |
|---|---|---|---|---|---|---|
| 1 | Travel and day order (nurse) | nothing (OPEN). PLAN3 excludes order and travel (PLAN3 *Negative*, Q7). AN1 travel minutes within visits IMPLEMENTED | she orders her own day and route | **replace first** (team geography, J2 and D-11), **automate second** (AUT-5 day-order rule) | Q7 (location data, Gate 5, `lca`), D-11 (`owner`) | AUT-5, **AUT-32** |
| 2 | Documentation per visit (nurse; RN countersigner) | OBS1 accepted (author line per observation; no step added). D-10 still awaiting the Clinical Owner (G-1 not named) | one free-text report per visit; RN countersign of every care-assistant report (0016) | **replace** by documentation by exception (P-2) and risk-based review (D-10); dictation (A7) only at stage 2 | D-10 and G-1 (`clinical`); D-35 stage 2 | AUT-4, **AUT-32** |
| 3 | GP orders, hospital referrals, relatives (primary nurse) | nothing (OPEN). D-22, D-9, D-3 awaiting | phone or fax for order renewal (ORD0 records only the task); referral re-typed at J1 | **eliminate** (structured order and referral, external actors as record nodes) | D-22, D-9 (`legal`/`owner`), D-3 (Clinical Owner) | AUT-6 |
| 4 | Who takes which visit (team) | AIG1 accepted, AIG1-C1/-C2/-C3 met (#787); AIG1-C4/-C5 then PLAN3 in *Active now* (2), (3). VIS1 (early visit as one confirmed move) and VIS2 (overlap shown) IMPLEMENTED | a member sets the responsible nurse visit by visit (J3); moving a weekly visit before doing it early (VIS1-3b) | **eliminate the role**; PLAN3 is the means (ticked list for `schedule` fields, AUT-1); P-28 (window instead of a fixed day) would remove the early-visit move at its source | build (PLAN3); P-28 needs a missed-visit rule for a window (D-28, Clinical Owner) | AUT-1, AUT-19 |
| 5 | Assessment → care plan (assessing RN) | ASM1 accepted with ASM1-C4: one confirmed review act re-bases the plan, no retyping (AUT-26 closed, IMPLEMENTED) | minutes per category typed from the provider's tool; planned minutes per service again on the plan | **redesign** (one clinical language); import later (AUT-13, D-37) | `cra` on the AUT-2 display; D-37, D-36 (`owner`, `legal`) | AUT-2, AUT-13; P-38 (measure) |
| 6 | Working time (nurse) | nothing. WORK1-6 team North Star IMPLEMENTED (care minutes over confirmed paid minutes, per team and month) | one confirmation per day with two questions | **simplify the form**, the duty stays (P-20 measures first; `lca`) | pilot data, `lca` (D-23) | AUT-8 |
| 7 | Visit status taps (nurse) | nothing | up to six taps per visit | inferred times are `record` values confirmed one by one (AUT-7 closed): **no gain at equal safety** | – | – |
| 8 | Billing preparation | nothing | none before the invoice (J5 derives facts) | eliminated; invoice later (BILL2) | D-12, D-18 | – |
| 9 | Referral → case → team decision | nothing | none beyond rank 3's re-typing | eliminated (team pull, J2) | – | – |
| 10 | Quality and analytics | nothing | the hold lift by coach or admin (D-16) | eliminated (compilation) | D-16 (`clinical`) | – |
| 11 | Team self-organisation: absence, offboarding, onboarding | ADM2 accepted (team admits by consent; "Vertrag erfasst" once); RLS4-C2 (leaver's open reports at the access-end step only, #792) IMPLEMENTED; UX2-26 (qualification on the same card after "Vertrag erfassen", AUT-21) PLANNED | the administrator's separate qualification step until UX2-26 | eliminated (central admission); **simplify** the remaining employer acts into one sitting (AUT-21) | build (UX2-26) | AUT-21 |
| 11a | Team self-organisation: a team that divides itself (team) | nothing (P-32, OPEN) | only an organisation administrator creates a team (`create_team`, 0035); no command hands open cases with primary nurse, deputy and planned visits to another team (UNKNOWN whether another path exists) | **eliminate** re-entry: one team decision carries cases with their people; responsibility transfer stays `cra`'s | P-32 brief (PO); `cra` on a responsibility transfer | – (P-32) |
| 11b | Team self-organisation: night and weekend cover across teams | nothing (COVER1 accepted, switched off, D-3) | cover by phone outside NAVORA | shared on-call service (STRATEGY §8.1.5) | D-3, P-24 (UNKNOWN, `lca`) | – |
| new (low) | **Governance follow-up of an assistant** (team members, Operations): look-back lines after a stop, expired proposals, threshold health | AIG1-C1/-C2/-C3 IMPLEMENTED; AIG1-C4 (expiry on read) and AIG1-C5 (follow-up keyed on open lines) PLANNED | work that exists only because an assistant exists; kept per value, one by one, where safety requires it | **keep it smaller than the gain**: measured per team in PLAN3-7 and PLAN3-13 (confirm actions per day plan, proposal-to-plan minutes, expired share, stops and switch-ons) | build (AIG1-C4/-C5, PLAN3) | AUT-29, AUT-30, AUT-31 |
| – | Founding a team's provider (team, future Leitung Pflege) | nothing (D-38) | a founding project per team | provider kit (STR-19), readiness read from the record | D-38 (`owner`) | AUT-14, AUT-15 |

**What the refresh shows (estimate, not a measurement):**
- Since 2026-10-27 every delivered capability sits at ranks 4, 5 and 11 or in the governance layer that ranks 4-5 need. That order is consistent with the queue: those steps are buildable without an owner, legal or clinical decision.
- The **three largest estimated bottlenecks (ranks 1-3) did not move**. None has a build path that does not wait for a decision (Q7 and D-11; D-10 with G-1; D-22, D-9, D-3), and none has a **per-step baseline**. The team North Star (WORK1-6) shows the total care share once days are confirmed, but not which step the non-care time goes to. So if ranks 1-3 are unblocked during the pilot, their gain cannot be shown against a before value. This is AUT-32.
- Minutes per step, the share of a working day in any one step, and the number of calls with GPs, hospitals and relatives stay **UNKNOWN**. The synthetic seed cannot answer them (its timestamps are generated, not worked).
- Next refresh: 2026-11-10.

### 2 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-32 | All of ranks 1-3 (travel and day order; documentation and countersign; orders and referrals): the team, measured; the PO deciding what to unblock first | **IMPLEMENTED:** AN1 travel and care minutes within visits (0027, 0032); WORK1-6 care share of confirmed paid time per team and month (0079). **PLANNED:** PLAN3-7 and -13 (planning only). **OPEN:** P-19 (PO 2026-10-27 15:20, "brief later, no build now", challenge table in `NEXT_CAPABILITY.md`) proposes per-step spans from timestamps NAVORA already stores (report draft created → signed; countersign latency; partner request → case ready; ORD0 task age); no brief exists after a week (grep of `briefs/`). Ranks 1-3 have no build path without a decision (map §1). Without a pilot baseline, the gain of D-10, Q7 or D-22 cannot be shown, and the owner's success measure 2 (less administration) has no team-level number per step | **monitor, no new tap:** brief P-19 now as a read-only AN1 extension, so the pilot's first month is the baseline: per team and month, with AN1 small-team suppression and never per person: (a) median report draft → signed span and countersign latency (rank 2); (b) travel share of visit time already in AN1, shown beside the WORK1-6 care share (rank 1); (c) ORD0 open-task age and J1 request → case-ready span (rank 3). No new field, no stopwatch, no reading of the WORK1 tables beyond WORK1-6 (D-23 term (b)). Testable criteria: pgTAP on the synthetic seed returns each span per team; a team below the suppression rule returns nothing; the catalogue check finds no person key in any new read | L | stage 0; PO (brief, place before G-19); `lca` (staff timestamps aggregated per team, D-23 term (b)); `eng` (read model) | the spans themselves, before and after each of D-10, Q7, D-22 is decided | medium | report only |

**Briefs and items reviewed without a new finding:**
- **AIG1-C5 (PO 02:55):** adopted as AUT-30 proposed, with its tests and measure; `cra` #801 states no objection. Supported. AUT-30 stays open until built (*Active now* (2), with AIG1-C4).
- **PLAN3-11 amended, PLAN3-13 with AUT-31:** supported; the expired share and lead time are measured per team and never as a stop criterion.
- **RLS4-C1 as built (#792, runbook §5c):** see §4 (AUT-27). **RLS4-C2 as built:** a leaver's open reports are read at the access-end step only, so administrators no longer see a standing per-person list; a task list for that moment, not an act history. No step added. Supported.
- **UX2-1 shell (#799, open):** the nurse's three tabs are "Heute", "Team" and "Arbeitstag"; `/team` (the team's own planning, proposals and look-back count under PLAN3-11) is one tap from every screen instead of a menu entry. No step, field or role added; nothing removed from any role (one source, `menuItemsFor`). Deviation 3 (coordination roles on a phone have one tab, "Ausnahmen" under "Mehr"): from the team-autonomy side this is right, since the phone is the team's tool and exceptions work happens at a desk (P-40); a product call for the PO and `uxa`. Supported.
- **UX2-27, UX2-29 (#800, open):** display text only ("von <Name>", "Verantwortlich", "noch niemand"); one word set across `/field` and `/visits` removes a translation step for the reader. No step added. CGR-108 and CGR-109 are `cra`'s wording questions; `aia` adds nothing. ADR-132 note 1 (AIG1 lines still say "Zuständig") is `uxa`'s.
- **UXR-73, UXR-74 (#798):** `uxa`'s; UXR-74's count cap on the proposals link adds no step.

### 3 AI readiness of delivered items (§8)
- **Nothing merged since review 17 proposes, drafts or ranks.** #792 is a runbook in which a person decides each legacy name; NAVORA does no name-to-member matching and the runbook forbids writing a matching rule (§5c step 3). That is the "no automatic coding" boundary applied to data reconciliation. No §8 check due.

### 4 Findings closed
- **AUT-27 closed:** built as proposed in RLS4-C1 (#792 merged `6fd9507`; CI green as Engineering and `cra` #801 report): the review list is grouped by team and legacy name on the live project only; a person decides **once per name and team**, a doubtful name visit by visit; the mapping applies in one transaction with a membership guard and a row-count check; count before and after, who and when in the reconciliation record; no names or mapping in the repository; pgTAP 105 on a synthetic fixture. The live reconciliation itself stays OPEN for the D-1 owner (G-25).
- **AUT-30:** adopted as AIG1-C5 (PO 02:55); closes when built. **AUT-31:** adopted into PLAN3-13; closes with PLAN3.
- AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21, AUT-25, AUT-28 (P-38): unchanged.

### 5 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 governance layer | met on synthetic data (unchanged); AIG1-C4 and **AIG1-C5** PLANNED (*Active now* (2)) before the first agent other than the synthetic test agent |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, *Active now* (3), after RLS4-C1/-C2 (**delivered**, #792) and UX2 (#799, #800 open) |
| 0 | Baseline for ranks 1-3 (AUT-32) | OPEN (P-19 not briefed) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged |
| 1 | Owner releases stage 1 (provider, region, contract) | not decided (owner, D-35), unchanged |

### 6 Waiting for the PO
- **AUT-32 (medium):** whether P-19 is briefed now as a read-only AN1 extension, placed before G-19, so the pilot's first month is the baseline for ranks 1-3.
- AUT-30 / AIG1-C5 and AIG1-C4: build (in *Active now*). #793 can be closed by the PO when built.
- P-36 undo alternative (review 15), AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: next due 2026-11-10.

### 7 Issues and comments
- No `high` finding: no issue opened. No comment on an open PR (#799, #800 have no `aia` finding).

---

## 2026-10-31 02:40 CET · aia review 17: AUT-29 closed (AIG1-C1 built, #787, 0104); AUT-23 closed; AIG1-C2/-C3 and AIG1-C4 (PO PR #791) supported; AUT-30 (high: the stop's look-back is tied to the agent's state, so switching a stopped assistant off or on drops open lines from every screen, and at "0 offen" the exception never ends while it stays stopped); AUT-31 (low)

**Read:** `recovery/main` at `1275708`:
- merged since review 16 (#775): #776 (AIG1 part (b) UI, ADR-129), #778, #780, #777, #783, #781 (CGR-96 test fix), #784, #786, #785 (`uxa` 23:55), **#787** (AIG1-C1, -C2, -C3, migration 0104, ADR-130), #789, #790 (`lca` 01:40);
- open: PO **#791** (02:25: AIG1-C1/-C2/-C3 met, **AIG1-C4**, **PLAN3-13**; read on its branch `b09b395`), `cra` #788 (01:30, CGR-106, CGR-107; read on its branch), #782 and the earlier `cra` chain;
- open issues labelled `automation`: #774 (AUT-29; met, see §4).

**Nothing below is a measurement.** I ran no tests. CI as the PO reports it on #791 (head `65a1278` and merge commit `c6f038b`: `app`, `db`, `e2e`, `ui-screenshots` green); not re-read by me. Code read: 0097 (`set_agent_state`, `agent_health`, OPS1 `agent_stopped`), 0104, `src/app/(protected)/operations/assistenten/page.tsx`, `tests/e2e/aig1.spec.ts`.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-30 | After a stop: Operations and the organisation administrator deciding what to do with a stopped assistant; team members and Operations working its look-back list (AIG1-12) | **IMPLEMENTED, from code (not run):** the OPS1 exception `agent_stopped` and its "<n> offen · <m> nicht mehr offen" exist only `where g.state = 'stopped'` (0097 `derived_exceptions`, patched by 0104); the health list returns `stop_id`, and so the link "Betroffene Werte ansehen", only for `state = 'stopped'` (0097 `agent_health`: `left join ai_agent_stops st on st.id = s.last_stop_id and s.state = 'stopped'`; `assistenten/page.tsx:69-77`). `set_agent_state(…, p_on => false)` moves a `stopped` agent to `off` with no check of open lines (0097:519-524); a new switch-on also ends `stopped`. **Two effects:** (1) an administrator who switches a stopped assistant **off** ("we no longer use it", the natural act after a stop) or **on** again removes every screen path to the stop's still-open lines; they remain only at the bare address `/operations/assistenten/rueckblick/<stopId>`. PLAN3-11 (team entry) is keyed on `stopped` too. That is the "silent leave" `lca` proviso (a) and CGR-95 exclude; no brief criterion (AIG1-8, -12, -C1) states what happens to open lines on off or on. (2) Conversely, once every open line is handled the exception stays "0 offen · <m> nicht mehr offen" for as long as the agent stays stopped (AIG1-C1 (4), PO 21:25): a P2 to-do with nothing to do, cleared only by the same off/on act. **No patient-care benefit is shown** for an exception that outlives its work, or for losing a path to open lines | **rule, no new step, more safety:** key the stop's follow-up on its **open lines**, not on the agent's state. (a) One OPS1 exception per stop with at least one open line, whatever the agent's state now (`stopped`, `off` or `on`); it closes by itself at "0 offen". (b) The health list shows each stop with open lines and its link, whatever the state; a stop at "0 offen" stays readable from the agent's row as history ("gestoppt am <Datum> · 0 offen · <m> nicht mehr offen"), not as an exception. (c) The agent's state stays shown as status ("Gestoppt seit …", "Aus") on the health list and PLAN3-6 on `/team`, never as a to-do. (d) PLAN3-11 keys on open lines of the team's stops, not on `stopped`. Nothing about re-check duty is set (D-17, UNKNOWN). Testable criteria on the issue | L | stage 0 (before the first agent other than the synthetic test agent, with AIG1-C4); PO (amend AIG1-8/-12 and AIG1-C1 (4)); `cra` (CGR-95, H-20: confirms nothing is lost); `lca` (proviso (a): stronger, no new read or role); `uxa` (status vs exception wording) | per team and stop: stops whose agent was switched off or on with open lines (should be 0 lines lost: the exception stays); days from stop to "0 offen"; days an exception shows "0 offen" (should be 0); switch-ons within 24 h of a stop (restart pressure, H-20). Never per person | high | #793 |
| AUT-31 | Proposals that expire undecided (AIG1-C4, PLANNED): team members on `/team/vorschlaege`; Operations on `/operations/assistenten` | PLANNED (PO 02:25, #791): an undecided proposal of a visit no longer open leaves the list without a human act, is not a correction, and is counted "Abgelaufen ohne Entscheid: <n>" per agent and window. Supported (eliminate). The open question (AIG1-C4 (4), D-17) is whether expiry is the assistant's fault; from the team side the answer that matters is **lead time**: a proposal that arrives after the team has already planned by hand returns no care time. Share expiring per team: UNKNOWN (no agent built) | **monitor, no step:** PLAN3's usefulness measure (with AUT-25's "no proposal" share) adds, per team and window, the expired share and the median time from proposal to visit start of decided vs expired proposals. Not a stop criterion and not shown to the team as a fault; it tells the PO whether proposals come early enough to be used (PLAN3 generation time) | L | stage 0; PO (PLAN3-13 or PLAN3 measure line) | expired share per team and window; median proposal-to-visit lead time, decided vs expired. Never per person | low | report only |

**Briefs and items reviewed without a new finding:**
- **AIG1-C1 as built (0104, ADR-130):** see §4 (AUT-29). Deviation 1 (no rejection of an applied value) removes a path that would silently drop a listed line; supported.
- **AIG1-C2 as built:** the team member re-confirms or changes an open-visit value one by one on the record page, refusals show their reason, coordinators get no control. This is the first team-side exit from a look-back line; it puts the act with the people who plan (no dispatcher). `record_lookback_lines` returns only the record's own team's lines, no person column: supported. CGR-106 tests ("Ändern") go into AIG1-C4 (5): supported.
- **AIG1-C3 as built:** back link by origin, refusals on their line with both counts, 44 px tick rows, flag in the "Mindestzahl" cell. Fewer dead ends and re-taps on the phone; no step added. Supported.
- **UXR-71 first half not adopted (PO 02:25):** a rejection changes nothing on the visit (ADR-130 decision 13), so a confirm step after "Ablehnen" would add a tap to every correct rejection for no safety gain. Supported; this is the challenge duty applied by the PO.
- **AIG1-C4 (1)-(3) (#791):** the PO's question "why must a nurse reject a proposal time has made moot?" is the right one; filtering on read, no write, and a separate expired count keep the stop share honest without anyone's act. Supported, with AUT-31 as the measure addition.
- **PLAN3-13 (#791):** the P-6 measure extension placed before the first non-test agent, per stop and team, no person column. It is where AUT-30's measures belong. Supported.
- **P-40 (PO 00:10, hypothesis):** Operations needs counts per team, the team needs the lines. Consistent with AUT-30 (b)-(c); supported as a pilot hypothesis.

### 2 AI readiness of delivered items (§8)
- **#787 (AIG1-C1/-C2/-C3):** suggestion ledger and provenance per value unchanged (IMPLEMENTED). **Named confirmer:** a re-confirmation or change on the record page is the team member's own `confirm_suggestion`, with the AIG1-15 checks; on a visit no longer open nothing is recorded (`not_open`, IMPLEMENTED). **No accept-all on listed fields:** look-back values one by one only (AIG1-13 (a), IMPLEMENTED); bulk refusals now stay on their line (AIG1-C3 (2)). **Correction rate per agent and field:** unchanged; expired proposals still count as decided only through a rejection until AIG1-C4 (PLANNED). **Stop rule:** IMPLEMENTED; its follow-up depends on the agent's state (AUT-30, OPEN). **Evaluation on synthetic data:** pgTAP 104, `aig1.spec` tests 3-8, seed organisations E and F (CI per the PO).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 governance layer | **met on synthetic data**: AIG1 `accepted` (PO 22:15), AIG1-C1/-C2/-C3 met (PO 02:25, #791 not yet merged); AIG1-C4 and AUT-30 (if adopted) PLANNED before the first agent other than the synthetic test agent |
| 0 | First real stage-0 agent (PLAN3) | PLANNED: PLAN3 (with PLAN3-11, -12, -13) after RLS4-C1/-C2 and UX2 in *Active now*; AIG1-C4 in or before the PLAN3 PR |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged; past-visit rectification (DSG Art. 32) UNKNOWN in D-35, Clinical Owner (D-17) and legal adviser after D-11 |
| 1 | Owner releases stage 1 (provider, region, contract) | not decided (owner, D-35), unchanged |

### 4 Findings closed
- **AUT-29 closed:** built as written in AIG1-C1 as amended (0104 `aig1_apply_visit_responsible` refuses re-confirmation and correction `not_open`, no row; `agent_stop_lookback.not_open`; OPS1 detail "<n> offen · <m> nicht mehr offen"; pgTAP 104 "0 offen · 3 nicht mehr offen" with the agent `stopped`; e2e test 4 and 8), merged as `c6f038b` with CI green as the PO reports; PO 02:25 "met". #774 can be closed by the PO. The part of AUT-29's concern that remains (the exception's life is keyed on state) is new evidence and is AUT-30, not a reopening.
- **AUT-23 closed:** (a) bulk refused on listed values and (b) "überholt am <Datum>" labelled and out of the open count, now also on screen (`aig1.spec.ts:155-177`).
- AUT-25 closes with PLAN3 (AUT-31 adds to the same measure). AUT-27 closes when RLS4-C1 is built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21, AUT-28 (P-38): unchanged.

### 5 Waiting for the PO
- **AUT-30 (high):** answer before the first agent other than the synthetic test agent (same deadline as AIG1-C4); amend AIG1-8/-12 and AIG1-C1 (4), or state the patient-care benefit of keying the stop's follow-up on the agent's state.
- AUT-31 (low): optional addition to PLAN3-13 or PLAN3's measure line.
- P-36 undo alternative (review 15), AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32, care-plan maintenance after reassessment with P-38).

### 6 Issues and comments
- AUT-30: issue #793 opened; one comment on PO PR #791 (AUT-30, AUT-31, AUT-29 closed).

---

## 2026-10-30 20:18 CET · aia review 16: AUT-26 closed (#747 merged, ASM1 accepted); AUT-28 adopted as P-38; AIG1 part (b) database half (#770, 0103) §8 check: AIG1-15/-16 supported; AIG1-C1 (PO PR #769, not merged) read: AUT-29 (high: a past-visit look-back line can never leave "offen", so the stop exception clears only by switching the agent back on)

**Read:** `recovery/main` at `65fe6e6`:
- merged since review 15 (#756): #747 (ASM1-C1 to -C5, C4 (d), `752ecbc`), #757, #759, #760 (PO 15:55: ASM1 `accepted`, P-38), #761 to #765 (WORK1-C5, CGR-96 test fixes), #767 (PO 17:45), #768, #773 (`lca` 17:45, 19:45), #770 (AIG1 part (b) database half: AIG1-15, AIG1-16, migration 0103, ADR-128, pgTAP 103), #771;
- open: PO #769 (18:25 + 20:25: CGR-96 back to (0), P-37 in force, ASM1-C6 (8) (iv)/(v) narrowed, AIG1 part (b) database half reviewed, **AIG1-C1**; read on its branch), `cra` #766, #753 and earlier;
- open issues labelled `automation`: none at start (#732 closed by the PO 15:55).

**Nothing below is a measurement.** I ran no tests. CI as reported by the PO and `eng` (check runs on #770 head `89b0afb` and merge commit `6c1a83f`: `app`, `db`, `e2e`, `ui-screenshots` green); not re-read by me.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-29 | After an assistant is stopped (AIG1-8): team members and Operations working the AIG1-12 look-back list; the OPS1 exception "Assistent gestoppt" | **Challenge of the form of AIG1-C1, not of what it declines to write** (no "bestätigt" on a past visit: supported). IMPLEMENTED: a **correction** of a visit no longer open is refused `not_open` (0103:66-69); the OPS1 detail counts every non-superseded line as "offen" (0097 `derived_exceptions`), and the exception closes only when the agent is switched on again (0097 comment). PLANNED (AIG1-C1, PO 20:25, #769 not merged): a **re-confirmation** of such a line is refused too, the line stays and **still counts as open**. Result: a past-visit line has no exit at all (not re-confirmable, not correctable, not `superseded` because the record still holds the value), so "<n> offen" can never fall to what can still be acted on, and the only way to make it go away is to restart the stopped assistant (the pressure runs against H-20). No patient-care benefit is shown for counting unactionable lines as open. Share of past-visit lines per stop: UNKNOWN (no agent built); structurally high, since the threshold window is closed and PLAN3 proposes responsibility for visits that are mostly performed by the time a stop is read | **rule, no new step, equal safety:** keep AIG1-C1's action (no confirm control, `not_open`, no `ai_confirmations` row, line not removed, opens its record). Label the line as a visit fact, like `superseded`: "Besuch nicht mehr offen" with the visit date (`uxa` wording); **not counted as open**; OPS1 detail shows "<n> offen · <m> nicht mehr offen". NAVORA sets no re-check rule; if the Clinical Owner names fields after G-1 (D-17, UNKNOWN), those go to the CIRS/incident path, not to a confirm click. Testable criteria on #774 (pgTAP: past-visit line listed, flagged, out of the open count, no person column; re-confirm and correct both refused with no row; `0 offen` reachable while the agent stays `stopped`; e2e: sentence, no confirm control, both counts) | L | stage 0 (AIG1-C1 / part (b) UI); PO (amend AIG1-C1 before the UI PR), `uxa` (wording), `lca` (terms (i)-(iii) unchanged; label is a visit fact, no person), `cra` / Clinical Owner only for re-check duty | per team and stop: lines at stop; left by correction, by re-confirmation; "überholt"; "nicht mehr offen" at stop and **became** "nicht mehr offen" while listed (whether the list is worked in time); days to `0 offen`. Never per person | high | #774 (comment on #769) |

**Briefs and items reviewed without a new finding:**
- **AIG1-15 as built (0103):** a look-back re-confirmation on an open visit runs `may_perform_visit`, `adm2_in_contract`, `member_absent_during` in the first confirmation's order; refusal writes no row and the line stays (pgTAP 103 per PO 20:25 table). It also covers a first confirmation meeting a hand assignment (ADR-128, accepted). No step for anyone; it makes "bestätigt von" mean a check ran. Supported.
- **AIG1-16 as built (0103):** share ≥ 100 refused `threshold_missing`; `agent_health` returns share, minimum, window and `last_window_min_reached`, null before the first closed window (ADR-128 deviation 1, accepted). Monitoring of the monitor at no team cost. Supported; the null case needs its own sentence in the UI (`uxa`), as the PO states.
- **P-37 in force (PO 18:25, #769) with the `cra` "Ersetzen" sentence:** one tap for the common cause, free text only for "Anderer Grund", one sentence that steers a wrong value to "Ersetzen". The sentence is read, not answered: no extra tap; it protects the correction chain (H-05). Supported (review 15).
- **ASM1-C6 (8) (iv) narrowed (PO 18:25):** no review act "against nothing"; the sentence stays until a new record exists. No step added; it keeps a true fact visible. Supported.
- **CGR-96 back to (0), WORK1-C5 (b) watch rule, e2e own-data rule (PO 16:55, 17:45, 18:25):** test-only; no nurse or team step. The rule "a red privacy test is a finding with a name, not a re-run" is monitoring done right. Supported.
- **P-38 (PO 15:55) = AUT-28:** adopted as a pilot hypothesis in the measured form `aia` proposed (C4 acts within 24 h of a record, markers older than 14 days, team level), never bundled into the save. AUT-28 adopted; it closes when P-38 is evaluated.

### 2 AI readiness of delivered items (§8)
- **#770 (AIG1 part (b), database half):** suggestion ledger, provenance per value, confirmer per value only: unchanged from part (a) (IMPLEMENTED). **Named confirmer:** a re-confirmation now stands for the same checks as a first confirmation on open visits (AIG1-15, IMPLEMENTED); on past visits it still returns `ok` without checks until AIG1-C1 is built (PLANNED, with AUT-29 on its count). **No accept-all on listed fields:** unchanged (AIG1-13 (a), IMPLEMENTED). **Correction rate per agent and field:** unchanged. **Stop rule:** a threshold that cannot fire is refused, and the health read shows threshold and minimum reached (AIG1-16, IMPLEMENTED at database level; screen PLANNED). **Evaluation on synthetic data:** pgTAP 103 on the synthetic test agent only; no real agent. Still no AI service and no real data (D-1 precaution).
- **#747 (ASM1), #761, #764:** propose, draft and rank nothing.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | ASM1 built | **met on synthetic data** (#747 merged `752ecbc`, PO `accepted` 15:55); ASM1-C6 with C6 (8) PLANNED before the first real assessment record |
| 0 | AIG1 part (b) | database half IMPLEMENTED (#770, `6c1a83f`); UI half PLANNED; AIG1-C1 PLANNED (with AUT-29); `cra` section on 0097/0103 not yet merged |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, unchanged; AIG1-C1 must hold before any agent other than the synthetic test agent is switched on (PO 20:25) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged |

### 4 Findings closed
- **AUT-26 closed:** ASM1-C4 merged unchanged in substance (#747, `752ecbc`; CI green on head `6339c24` and on `recovery/main` `5ce5feb` as the PO reports), ASM1 `accepted` (PO 15:55), #732 closed by the PO.
- **AUT-28 adopted** as P-38 (PO 15:55); stays open as a hypothesis until evaluated.
- AUT-23: (a) and (b) IMPLEMENTED at database level; closes with the part (b) UI e2e ("überholt"). AUT-25 closes with PLAN3. AUT-27 closes when RLS4-C1 is built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21: unchanged.

### 5 Waiting for the PO
- **AUT-29 (high, #774):** answer before the AIG1 part (b) UI PR; amend AIG1-C1 or state the patient-care benefit of counting past-visit lines as open.
- P-36 undo alternative (review 15), AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32, care-plan maintenance after reassessment, now with the P-38 measure).

---

## 2026-10-30 15:04 CET · aia review 15: AUT-26 met in code on #747 (ASM1-C4, 0101; CI green, `cra` clear to merge; closes on merge); P-37 preset void reason supported; CGR-104 / ASM1-C6 (8) and P-35 supported; AUT-28 (low: a reassessment and the plan review are two separate acts on two screens, measure first)

**Read:** `recovery/main` at `29d751e`:
- merged since review 14 (#733): #735 to #752 PO, `lca`, `uxa` cycles (PO 08:15 to 13:28, `lca` 08:42 to 13:42, `uxa` 11:55), #742 (UX2-22/-23, `ea94bba`), #727 (ASM1, `e42fde6`, PO `changes-requested` 10:15);
- open: **#747 (ASM1-C1 to -C5 and C4 (d), migration 0101, ADR-125, head `fcb84eb`)**, PO #755 (15:00: CGR-104 as ASM1-C6 (8)), `cra` #753 (13:30) and its chain (#737, #723 and earlier);
- briefs changed: ASM1 (C4 decided 09:15 = AUT-26, C4 (a)-(c) `cra`, C4 (d) = UXR-60, C5, C6 with (7) output rule, P-37 proposal), UX2 (ADR-124 deviation 1 answered 11:10); D-13 (`lca` 09:40 to 13:42), D-4 item (7);
- open issues labelled `automation`: #732 (AUT-26) only.

**Nothing below is a measurement.** I ran no tests. CI read by me as GitHub check runs on #747: `app`, `db`, `e2e`, `ui-screenshots` success.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-28 | Reassessment, then plan review (ASM1-1 record, ASM1-C4 act): the team's registered nurse | PLANNED to be IMPLEMENTED with #747. After she records a new assessment on the case card, the plan shows "Neuere Bedarfsabklärung vom <Datum>" and she then opens the care-plan block, scrolls past the categories to the review command (C4 (d): last in the block) and confirms once more (confirming step). Where the same nurse does both on the same visit to the record, that is two places and three taps for one sitting. How often the recorder and the reviewer are the same person and the same day: UNKNOWN (no data; synthetic seed only). The separation itself is a clinical control (the plan review is a distinct judgement, `cra` (a)-(c)) and is not challenged | **measure first, then simplify the path, same control:** count per team and month how many C4 acts follow a new record of the same case within 24 h, without naming who. If most do, propose that the record's saved state offers the same review act as a second, separate, not preselected command ("Pflegeplan jetzt prüfen", jumping to the care-plan block with the marker still shown), never a checkbox inside the assessment save and never an act recorded by the save itself. Whether a plan review may be offered at that moment is `cra`'s; nothing bundled before that | L | stage 0; PO (whether to measure in the ASM1 pilot hypotheses), `cra` (whether offering the act there weakens the review), `uxa` (where) | per team and month: C4 acts within 24 h of a new record of the same case / all C4 acts; median days from record to act (AUT-26 measure). Never per person | low | – (report) |

**Briefs and items reviewed without a new finding:**
- **ASM1-C4 as built on #747 (AUT-26): met in code.** `review_care_plan_against_assessment` (0101:104) inserts one append-only row into `care_plan_assessment_reviews` (no grant, no policy, 0101:57-58) and changes no `care_plan_items` row: pgTAP 101 compares an md5 over the case's items before and after (101:80), refuses an assistant, another team's nurse, another organisation and a non-current record (101:117-136), clears `plan_without_basis` with one act (101:123), and asserts PLAN2 visits, minutes and billing facts unchanged (101:169). AUT-26 closes when #747 is merged unchanged in substance.
- **ASM1-C4 (d) one confirming step (UXR-60, PO 12:14, `cra` keeps it):** one extra tap on a rare act (once per reassessment or correction per case) guarding an S2 fact; a patient-care benefit is shown, so no challenge. P-36 (cancellations per team and month) is the right exit test; `aia` adds one lean alternative for when P-36 says drop it: an undo command on the recorded line ("Prüfung zurücknehmen", append-only, restores the marker) instead of the step, equal safety for a mis-tap.
- **P-37 preset void reason (PO 13:28, `lca` 13:42 compliant):** supported. It removes typing for the expected common cause and keeps another client's details out of free text: less administration and more privacy at once. Measure: share of voids with "Anderer Grund" per team and month (shows whether the preset fits). Nothing preselected (`lca` (a)). `aia` is not one of the confirmers P-37 needs (`cra` or `uxa`).
- **ASM1-C6 (8) basis by identity (`cra` CGR-104, PO #755):** no step for anyone; it makes the marker true after a same-date record or a void, so the team is not sent to review a plan that needs none, nor left without a marker it needs. Supported.
- **ASM1-C6 (7) standing output rule (PO 13:28):** a test duty on each later brief, no nurse step. Supported.
- **ASM1-C1 as built (`/field` "Zu bestätigen: Bedarfsabklärung (<n>)"):** her own read path, `info`, gone on confirm or supersede. Removes chasing between colleagues. Supported (review 14).
- **P-35 (PO 11:10, organisation-wide admission off-switch):** supported. The off-switch is a hierarchy step over every team's own admission; a team-controlled pause keeps the same safety (qualification and contract checks stay). ADR-124 deviation 1 (no lapse pause while off) is data minimisation, not administration; not challenged.
- **UX2-22 (`/field` hides acts for a missing qualification) and UX2-23 (one confirming step for the admission switch and "Vertragsende entfernen"):** UX2-22 removes refused attempts at the door. UX2-23 sits on rare administrator acts with organisation-wide or contract effect; not challenged.

### 2 AI readiness of delivered items (§8)
- **#747 (ASM1-C1 to -C5):** proposes, drafts and ranks nothing; no ledger entry needed. The C4 act is the confirmation end point a later A10 proposer would use: it stores the record and the record's state at the act (`cra` (a)), so a later proposal can be tied to the exact record it was made against (provenance per value, §8). The act's actor is not selectable (pgTAP 101:105-108), consistent with AIG1-11.
- **UX2-22/-23 (#742):** propose nothing.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | ASM1 built | #727 merged; C1 to C5 and C4 (d) on #747 (CI green, `cra` clear to merge, not merged); acceptance by the PO after merge; C6 PLANNED before the first real assessment record |
| 0 | Plan basis read by record identity (needed before any proposer reads "the plan's assessment") | PLANNED (ASM1-C6 (8), PO #755) |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, unchanged |
| 0 | AIG1 part (b) | not started (#705) |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution, G-25), unchanged |

### 4 Findings closed
- None closed this run. **AUT-26:** met in code on #747 (evidence above); closes on merge. AUT-23 closes with AIG1 part (b) (#705). AUT-25 closes with PLAN3. AUT-27 adopted in RLS4-C1 (1) (PO 09:15); closes when RLS4-C1 is built. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21: unchanged.

### 5 Waiting for the PO
- **#747** merge and the ASM1 review; AUT-26 / #732 closes with it.
- **AUT-28 (low):** whether the ASM1 pilot hypotheses count C4 acts within 24 h of a new record (team level).
- **P-36:** the undo alternative above, if the step is dropped.
- AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32, care-plan maintenance after reassessment).

---

## 2026-10-30 08:25 CET · aia review 14: AUT-24 closed (RLS4 delivered, #715, 0099); AUT-25 adopted (PLAN3-7); ASM1 #727 read: AUT-26 (high: the only way to clear "Neuere Bedarfsabklärung" is to retire and retype every care-plan item); AUT-27 (medium: RLS4-C1 maps legacy names visit by visit); RLS4-C2, ASM1-C1, VIS2-C3 supported

**Read:** `recovery/main` at `b6559ea`:
- merged since review 13 (#714): #712, #719, #725, #728 (`lca` 01:50 to 06:41), #716, #718, #720, #726, #729 (PO 03:10 to 07:20), #717, #730 (`uxa`), **#715 (RLS4, migration 0099, ADR-122, merge `d148f7f`)**, #722 (RLS4-5 (c) evidence);
- open: **#727 (ASM1, migration 0100, ADR-123, head `ad98160`)**, PO #731 (08:15: ASM1-C1 to C3, UX2-30), `cra` #723 (05:30: CGR-101) and its chain (#711 and earlier), #721;
- briefs changed: RLS4 (RLS4-3 addendum = AUT-24, RLS4-5/-6, accepted 06:10 with RLS4-C1; RLS4-C2 at 07:20), PLAN3 (PLAN3-7 amended = AUT-25), VIS2 (VIS2-C2, VIS2-C3), UX2 (UX2-28, -29; UX2-30 on #731), ASM1 (ASM1-C1 to C3 on #731); gate G-25 added (`CARE_OPERATING_MODEL.md`);
- no open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests. CI read by me as GitHub check runs: #715 head `bc47bee` and #727 head `ad98160`: `app`, `db`, `e2e`, `ui-screenshots` success.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-26 | Care plan after a reassessment (ASM1-7): the team's registered nurse who keeps the care plan current | **Challenge (ADR-123 deviation 2, OPEN; #727 not merged).** As built in 0100: `care_plan_items.assessment_id` is set only by the insert trigger; the plan's basis is the oldest current assessment among active items, and "Neuere Bedarfsabklärung vom <Datum>" shows while any active item rests on an older record **or was written before any record** (`team_case_assessments`, `plan_without_basis`). The only way to clear it is, per item, `retire_care_plan_item` with a typed reason (0014:395-414) and a new item with service, category, minutes per occurrence, frequency text and, where used, PLAN2's structured frequency, weekdays and window (0025). For a plan of n items: 2n actions and n retyped items, even when the assessment changed nothing in the plan. Two costs: (1) **administration without patient-care benefit**: retyping an unchanged plan proves no review; (2) **a new hazard**: a retyped frequency or window feeds PLAN2 visit generation (transcription error, H-24 pattern), and a team that does not retype keeps a marker that never clears, so the marker turns into noise on every case card (all pre-ASM1 plans show it as soon as one record exists). Effort per plan: UNKNOWN (not measured); the pattern is one review act being replaced by n rewrites | **rule (one confirmed act), no rewrite:** a per-plan command "Pflegeplan gegen Bedarfsabklärung vom <Datum> geprüft" by a named team member, audited per record (actor per record only, RLS4 pattern), that sets the plan's basis to the current record without changing any item; items the review finds wrong are changed with the existing commands. Which qualification may confirm (a registered nurse?) is `cra`/Clinical Owner (UNKNOWN; not invented here). No due date, reminder or signal (ASM1 negative unchanged). Later (A10, D-35 stage 1 or later): the review act is the confirmation an assistant's draft would end in, value by value, never accept-all on care-plan fields (§8) | L (the act); the qualification rule G if `cra` says so | stage 0; PO (deviation 2 answer before ASM1 acceptance), `cra` (who confirms), `uxa` (where the act sits on the card) | per team and month: median days from a new assessment record to the plan's basis matching it, and the share of cases with an open marker older than 30 days (display window, no clinical meaning); balancing: care-plan items retired and re-added on the same day per team (should fall). Never per person | high | #732 |
| AUT-27 | Data reconciliation before G-25 (RLS4-C1 (1)): the person doing the D-1 live reconciliation | PLANNED (RLS4-C1, accepted 06:10; not built). The runbook check returns the **count** of future, non-cancelled visits with `team_member_name` and no `responsible_user_id`; "a person maps **each such visit** to a member or confirms it unassigned". With PLAN2 generating visits ahead, one nurse's name stands on many future visits; visit-by-visit mapping repeats one decision per occurrence (e.g. one team with weeks of generated visits: hundreds of identical decisions; UNKNOWN on real data, D-1). The control itself (a person decides, no automatic matching, count before and after) is a patient-safety control (H-10, H-01) and is not challenged | **simplify, same control:** the runbook groups the remaining visits by team and legacy name (shown only on the live project, never in the repository); the person decides **once per name and team** (member, or unassigned) and that decision is applied to that name's future visits in the group; a name that two members could carry, or that the person is unsure of, is decided visit by visit; the count check still must return 0, and the record keeps count before and after, who and when (no names, no mapping in the repository, as RLS4-C1). Still no automatic name-to-member matching: every name is decided by a person | L | stage 0; PO (RLS4-C1 wording), `eng` (runbook), D-1 owner; `lca` aware (D-1 notes) | the decisions made per reconciliation (one per name, plus exceptions) against the visit count; the check returns 0 | medium | – (report) |

**Briefs and items reviewed without a new finding:**
- **RLS4-C2 (PO 07:20, `lca` 06:41):** removes a standing per-employee documentation-backlog list held by the employer; the list appears only in the access-end step. Less hierarchy, no step for the team, no open report hidden from anyone who must act. Strongly supported; the same reasoning as COND1-5a and PLAN3-10.
- **ASM1-C1 (on #731, `uxa` UXR-59):** a confirmation step the confirming nurse cannot see becomes phone calls between colleagues; one count line in her existing "Zu erledigen" removes that coordination. No reminder, no per-person count for anyone else. Supported; this is what makes ASM1-5 cheap.
- **ASM1-C2, ASM1-C3 (on #731):** less scrolling, fewer second attempts; no step. Supported.
- **ASM1-5 (named assessor confirms), ASM1-2 (supersede with a reason):** D-13 criteria from `lca` and `cra` (legal and safety duty); not administration to remove; form not challenged (one tap, only when someone else entered the record).
- **ASM1-11 as built (no sum, items as written, dated facts younger than the assessment):** a display of recorded facts, no signal; the right design order (care graph first). Supported.
- **UX2-30 / UXR-57 (prefill instrument and assessor on a replacement):** ADR-123 trade-off deliberately does not prefill them. Prefilling the person's own earlier record is not an agent proposal (no ledger needed), but it is a value carried over without a look; `cra` weighs it with UX2-30. No finding from me.
- **VIS2-C2, VIS2-C3 (save step only when another team's visit overlaps the edited interval):** a patient-safety fact (double booking at the client's door) shown once, nothing refused, and the PO declined a per-person log of look-ups (option (b), (y)). The step appears only in the rare overlap case; not challenged.
- **UX2-28, UX2-29:** wording; no step. Supported.

### 2 AI readiness of delivered items (§8)
- **RLS4 (#715):** proposes, drafts and ranks nothing. Its act-closing pattern (actor per record only) is the one AIG1-11 already uses for confirmers; consistent.
- **ASM1 (#727, not merged):** proposes, drafts and ranks nothing; nothing is computed from the record; no ledger entry needed. Provenance per value for a later import (AUT-13, `cra` condition (3)) is not built and not needed until an import is briefed. AUT-26's review act is the future end point of A10 (care-plan review proposer).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | ASM1 built | **in review** (#727, CI green on `ad98160`); acceptance after ASM1-C1 to C3 (#731) and the `cra` read; deviation 2 (AUT-26) OPEN |
| 0 | Per-record acts readable only per record (prerequisite for any per-value confirmer display) | **IMPLEMENTED** (RLS4, #715, 0099; G-18 met 06:10) |
| 0 | First real stage-0 agent (PLAN3) | PLANNED; AUT-25 measure now in PLAN3-7 |
| 1 | Real data may reach any test, pilot or AI path | blocked (D-1 precaution; G-25 added for real visit data) |
| 0-3 | other conditions unchanged from review 13 | as stated there |

### 4 Findings closed
- **AUT-24 (low): closed with evidence.** RLS4-3 addendum IMPLEMENTED: pgTAP 099:291-293 asserts `my_signals()` still returns `taken_by_name` for an open, taken signal to a team member; `safety_signals.taken_by` closed as a raw column (0099:55; pgTAP 099:72); CI on #715 head `bc47bee` green (check runs read by me).
- **AUT-25 (low): adopted** by the PO 03:10 in PLAN3-7 as proposed (share of "kein Vorschlag" per team and month by reason; no stop criterion). Closes when PLAN3 is delivered with that measure.
- AUT-23 closes with AIG1 part (b) (#705, not started). AUT-14, AUT-15, AUT-17, AUT-19, AUT-20, AUT-21: unchanged.

### 5 Waiting for the PO
- **AUT-26 (high, #732):** answer ADR-123 deviation 2 before ASM1 acceptance: one confirmed review act per plan instead of retire-and-retype; `cra` on who may confirm.
- **AUT-27 (medium):** one wording change in RLS4-C1 (1): decide once per legacy name and team, exceptions per visit; before the RLS4-C1 PR.
- AUT-19, AUT-20, AUT-21 as before.
- Bottleneck map refresh: due 2026-11-03 (weekly); care-plan maintenance after reassessment (AUT-26) added as a candidate next to onboarding contract to first visit, P-28, P-32.

---

## 2026-10-30 02:18 CET · aia review 13: AIG1 part (a) delivered (#701, 0097), §8 readiness checked, AUT-22 closed; VIS2 delivered and (PR #713) accepted; PLAN3-10 supported; AIG1-15/-16, VIS2-C1 supported; AUT-24 (low, RLS4 signal taker), AUT-25 (low, PLAN3 has no "no proposal" measure)

**Read:** `recovery/main` at `183748f`:
- merged since review 12: #695 (review 12), #698, #704, #708 (PO 23:15, 00:15, 01:10/01:45), #702, #706 (`lca` 23:50, 00:40), #685 (`uxa`), **#701 (AIG1 part (a), migration 0097, ADR-120, merge `85a4fd6`)**, #703, **#707 (VIS2, migration 0098, ADR-121, merge `4c8f2a6`)**, #709;
- open: PO #713 (02:10: VIS2 accepted with VIS2-C1; AIG1-15, AIG1-16), `lca` #712 (01:50), `cra` #711 (01:45: CGR-98, CGR-99, CGR-100) and its chain (#696 and earlier); issue #693 (CGR-96) open;
- briefs changed: AIG1 (AIG1-13, AIG1-14, part (a) review; AIG1-15/-16 on #713), PLAN3 (PLAN3-10 and its actor amendment), VIS2 (new, delivered), RLS4 (new, approved), J5 (invoicing note), OBS1, ADM2;
- no open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests. CI on #701 head: `app`, `db` (pgTAP), `e2e`, `ui-screenshots` success (GitHub check runs read by me); merge commits as the PO reports them.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-24 | Taking a P1 safety signal (SIG1) and seeing who took it: every team member on `/field` and Operations | **Not a challenge of RLS4 (it removes a per-person list and adds no step), a guard on its scope.** PLANNED (RLS4 approved 23:15, not built): RLS4-1 closes `safety_signals.taken_by` as an *act*. IMPLEMENTED today: while a signal is open, `taken_by` is how the team knows it is being handled: the signal reader returns `taken_by_me` and `taken_by_name` (0060:365-387) and the card says "übernommen von <Name>" (`src/features/signals/rules.ts:123`); unclaimed signals sort first (0060:387). So while open it works as an *assignment* (who handles it now), and after it ends as an act. If the reader output were lost in RLS4, teammates would phone round to find out whether a P1 signal is handled, or two would respond (H-04, patient safety, and direct care time). RLS4-2 and RLS4-3 already cover this in general wording ("each current reader keeps its output"; a column read as an assignment is named as a deviation); nothing names this column | **rule (test), no new step:** in the RLS4 PR, name `safety_signals.taken_by` in the ADR as act-and-assignment; the raw column may close (RLS4-1), and the open-signal reader keeps "übernommen von <Name>" for the team; add one pgTAP assertion that the reader still returns `taken_by_name` for an open, taken signal to an active member of its team (no per-person list: the reader is per signal, scoped to open signals of the team) | L | stage 0; PO (one line in RLS4-3 or the ADR), `eng`; `cra` aware (H-04, signal handling) | pgTAP as stated; after go-live, per team: share of P1 signals where a take attempt returned `duplicate` with "übernommen von" (0060:411-413), never per person | low | – (report) |
| AUT-25 | Day plan with PLAN3 (`/team`): the team member who assembles tomorrow | PLANNED (PLAN3 approved, PLAN3-7): measures are the shares confirmed unchanged and corrected, confirm actions per day plan, minutes from proposal to the last confirmed line, and continuity. A line with **"kein Vorschlag"** (PLAN3: the visit stays in the uncovered path, assigned by hand) is in none of them; ADR-120 deviation 4 (accepted 00:15) excludes `not_found` from the correction share and makes it no stop criterion, and AIG1-7 shows it only as a count per cell. Effect: the measure of PLAN3's gain (hand assembly removed) can look good while most visits still get no proposal. Share: UNKNOWN (not built) | **monitor, no new step:** add to PLAN3-7, per team and month, the share of the day plan's open visits that received "kein Vorschlag", by its stated reason (no primary nurse, not qualified, absent, outside contract; the reasons PLAN3 already shows), from the existing ledger (`not_found`) and refusal results; balancing measure as now. Read per team only, small-team suppression as AIG1-7. A high share points to missing care-graph data (primary nurse not set: J6), which the team can fix once, not to the agent | L | stage 0; PO (PLAN3-7 wording before build); no clinical content | the share itself, per team and month, before and after the team's PLAN3-10 switch date; target direction down | low | – (report) |

**Briefs and items reviewed without a new finding:**
- **PLAN3-10 (PO 00:15, actor amended 01:10), challenge test:** removes a central rollout decision (administrator) and gives it to the team; one audited switch per team, default off, actor per record only. Less hierarchy, no added step for daily work, and it gives PLAN3-7 its "before/after for that team" date. Strongly supported; this is the operating model as the owner describes it.
- **AIG1-13 as adopted (23:15) and built:** (a) one by one, as proposed; (b) labelled "überholt", out of the open count, not removed. The team gets the relief I sought (nothing to do by default for a superseded value) without NAVORA deciding the clinical re-check question. I accept the PO's form; it is better than my proposal at equal effort.
- **AIG1-14 (`uxa` UXR-49):** removes names from the look-back screen; no step. Supported.
- **AIG1-15 (CGR-98, on #713):** a re-confirmation that runs no check would put a nurse's name under a check that did not happen; the fix reuses the first-confirmation checks and adds no step. Patient-safety control; supported.
- **AIG1-16 (CGR-100, on #713):** refuses an arithmetic threshold that cannot fire, and shows threshold and "Mindestzahl erreicht" on the health list. This is monitoring of the monitor, the right design order; no step for a nurse. Supported.
- **VIS2 (delivered #707, accepted on #713):** a fact at the moment of planning instead of a later duplicate check by a coordinator (the "eliminate through the care graph" order); no tap, nothing refused. `p_overlap_shown` is recorded by the command, nobody types it. Supported.
- **VIS2-C1 (CGR-99, on #713):** the generation count is the measure of the hypothesis that hand planning and PLAN2 generation duplicate work (H-PLAN-dup). I propose no rule before the count exists; if the pilot shows a non-zero share, the leaner fix is in the care graph (generation knows the hand-planned visit), and its rule is the Clinical Owner's (UNKNOWN).
- **RLS4 (approved 23:15):** removes per-person act lists; keeps assignments; no step. Supported, with AUT-24.
- **J5 invoicing note (`lca` D-18):** a legal duty before invoicing (a person confirms overlapping facts); not administration to remove; not challenged. Its effort is bounded by VIS2 (overlaps seen at planning).

### 2 AI readiness of delivered items (§8)
**AIG1 part (a) (#701, 0097), checked against §8, database level:**
- Suggestion ledger: **IMPLEMENTED**, append-only for every role including owner and `service_role` (0097:239-257), input references ids only.
- Provenance per value: **IMPLEMENTED** (`value_provenance`); the screen line is part (b), PLANNED.
- Named confirmer: **IMPLEMENTED**, read per value or per record only; no table grant to `authenticated`/`anon` on the seven AIG1 tables, RLS on without policy (0097:228-238), pgTAP 097 AIG1-11 block (direct select, `select *`, `group by` refused).
- No accept-all on listed fields: **IMPLEMENTED** (field-class trigger, bulk only for `schedule` and while `on`, never a decided or look-back value; `check (not bulk or outcome = 'confirmed')`, 0097:220).
- Correction rate per agent and field: **IMPLEMENTED**, rule of three per cell. `not_found` excluded from the share (ADR-120 (4)): see AUT-25 for the usefulness side.
- Stop rule: **IMPLEMENTED**, evaluated lazily at the next proposal, bulk confirm or health read; OPS1 `agent_stopped`; look-back with "superseded". Gap found by `cra` (CGR-98) placed as AIG1-15; unreachable threshold as AIG1-16 (both PLANNED, #713).
- Evaluation on synthetic data: **IMPLEMENTED** (fixture harness, synthetic test agent, bar checked on every PR; switch-on without fixture refused).
- Only agent registered: the synthetic test agent. No real agent proposes anything yet; PLAN3 is the first (PLANNED).
**VIS2 (#707):** proposes, drafts and ranks nothing; a deterministic fact. No ledger entry needed.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | **part (a) IMPLEMENTED** (#701, 0097; CI green on head `4bc7236`); part (b) (screens, e2e) and AIG1-15/-16 PLANNED; acceptance also needs a `cra` section on 0097 (CGR-98 is S2 before acceptance) |
| 0 | First real stage-0 agent (PLAN3) | PLANNED, *Next up*; now team-switched (PLAN3-10). Open: AUT-25 measure |
| 0 | Per-entry provenance in clinical records | IMPLEMENTED for observations (OBS1, OBS1-C1); drafts OPEN |
| 0 | ASM1 built | PLANNED, not started |
| 1 | Employee information names confirmations, look-back purpose **and the team switch** (D-9; `lca` 00:40 term (v)) | OPEN, owner (pilot precondition) |
| 1 | Real data may reach any test, pilot or AI path | blocked (owner precaution until D-1 is clarified; owner package required by D-35) |
| 1-3 | other conditions unchanged from review 1 | OPEN |

### 4 Findings closed
- **AUT-22 (high, #686, closed by the PO 21:15): closed with evidence.** AIG1-11 IMPLEMENTED in 0097 more strictly than proposed (no table grant at all; RLS without policy), pgTAP 097 AIG1-11 block; CI on #701 head `4bc7236` green (check runs `app`, `db`, `e2e`, `ui-screenshots`: success).
- **AUT-23 (medium):** (a) IMPLEMENTED (bulk of a listed value refused, 42501; pgTAP AIG1-13 block); (b) adopted in the PO's form and IMPLEMENTED at database level (`superseded`, `superseded_at`, out of the OPS1 open count). Stays OPEN only for the part (b) e2e ("überholt" shown); closes with part (b).
- AUT-21 (UX2-26), AUT-14, AUT-15, AUT-17, AUT-19, AUT-20: unchanged.

### 5 Waiting for the PO
- **AUT-25 (low):** one PLAN3-7 measure line before PLAN3 build. **AUT-24 (low):** one RLS4 test line before the RLS4 PR.
- AUT-19, AUT-20, AUT-21 as before; AUT-23 closes with AIG1 part (b).
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32).

---

## 2026-10-29 23:15 CET · aia review 12: AUT-22 adopted as AIG1-11 (PO 21:15, #686 closed); AIG1-12 look-back (PO 22:10) reviewed, AUT-23 (medium: the list's only exit is a re-confirmation, and AIG1-5 bulk would reach it); OBS1-C1 and ADM2-C1 delivered (#688); ADM2-C2 supported

**Read:** `recovery/main` at `1500cb3`:
- merged since review 11: #687 (review 11), #689 (`lca` 20:40, 21:45: D-35 term 9 for AIG1, CGR-95 look-back terms (i)-(v), D-32), #690 (PO 21:15: **AUT-22 adopted as AIG1-11**), #692 (PO 22:10: **CGR-95 adopted as AIG1-12**, `lca` D-32 as **ADM2-C2**), **#688 (OBS1-C1 + ADM2-C1, migration 0096, ADR-119, merge `b3227d2`)**, #694 (`eng` 22:25);
- open: `cra` #691 (21:30, CGR-95, CGR-96) and its chain, `uxa` #685; issue #693 (CGR-96, root cause UNKNOWN); `eng` claimed AIG1 on #536 at 23:07 (not started in any PR when read);
- briefs changed: AIG1 (AIG1-11, AIG1-12, AIG1-7 small-team suppression note, two PO answers), ADM2 (ADM2-C2), OBS1 (note: CGR-93 closed);
- issue #686 (AUT-22) closed by the PO as completed; no other open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests; CI states are as `eng` reports them (#688: app, db, e2e, ui-screenshots green on `213934b`).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-23 | After an assistant is stopped (AIG1-8): the team members who work through the AIG1-12 look-back list; Operations | **Challenge of the form, never of the look-back (its patient-safety benefit is shown: H-20, H-01, CGR-95).** PLANNED (AIG1-12, PO 22:10; AIG1 claimed by `eng` 23:07, not built): a line leaves the list **only** when its value is confirmed again or corrected through the normal confirm command. Two gaps in the text: (1) **AIG1-5 allows a bulk confirm for `schedule` fields of level-L `rule` agents** (the PLAN3-5 ticked list); nothing in AIG1-12 says that re-confirming from the look-back list is one by one, so the values of an agent stopped for too many corrections could be waved through again in one action, the automation bias the stop exists to catch (H-20). (2) A value that the record **no longer holds** (later replaced by a value a person entered or confirmed for the same field) can only leave by a confirm click on a value that is no longer in force: a step with no patient-care benefit shown, and a long list of such clicks is itself a pressure to confirm without looking. Size of the list per stop: UNKNOWN (no agent built; depends on the window and the agent's volume) | **rule, built in from the start; no new step:** (a) re-confirmation from the look-back list is always value by value, whatever the field class (AIG1-5 bulk not offered on this list; pgTAP: a bulk confirm of two look-back values is refused). (b) A line whose value has been superseded in the record by a later value entered or confirmed by a person for the same field leaves the list by itself, with the reason "überholt" shown on the record line and a ledger row (deterministic, written by the existing confirm or edit command, no person types anything); a superseded value is not re-confirmed. **Whether a superseded value still needs a clinical re-check** (e.g. a visit already done by the wrong person, H-01) is the Clinical Owner's, D-17 part 3: UNKNOWN; if she says yes, (b) does not apply to the fields she names, and such cases go to the existing CIRS/incident path, not to a confirm click. Equal safety: no value leaves unseen that the record still holds | L (governance list; the values themselves keep their own level, G or H fields one by one anyway) | stage 0 (part of the AIG1 build); PO (brief amendment before or with the first AIG1 PR), `cra` for (b) (clinical question to the Clinical Owner), `lca` not needed (terms (i)-(iv) unchanged, no person column) | per team and stop: lines at stop; lines left by correction, by re-confirmation and as "überholt"; days until the list is empty; correction share on the look-back lines (high means the stop was right). Never per person | medium | – (report; one comment on #536) |

**Briefs and items reviewed without a new finding:**
- **AIG1-11 (PO 21:15, from AUT-22), challenge test:** restricts reads only; no step, field or role for anyone; "bestätigt von" stays on the record line. Adopted as proposed plus the `lca` wording point (AUD1 = per-record `read_audit_record`) and a confirmed `not_found` in the closed outcomes. Supported.
- **AIG1-12 (PO 22:10, from `cra` CGR-95, `lca` terms (i)-(iv)):** the design order is right: the stop itself is monitoring, and the list replaces a hand search through every record with a derived worklist; no assignment, no deadline, no person column; NAVORA sets no clinical rule (re-check duty UNKNOWN, Clinical Owner). Supported, with AUT-23 on its exit.
- **AIG1-7 small-team note (PO 22:10, from `lca` 20:40):** suppressing a cell that would point to one confirmer is a data-protection precondition; costs no step. Supported.
- **Pilot precondition (D-9 employee information names confirmations and the look-back purpose):** a legal duty (`lca`, prior information); not administration for a nurse; not challenged.
- **OBS1-C1 delivered (#688, 0096, ADR-119):** authorship and signer columns read only through the per-visit functions; narrows reads, no step added. Supported, as in review 11.
- **ADM2-C1 delivered and ADM2-C2 (PO 22:10, from `lca` D-32):** the push claim re-checks `push_active` and the deletion runs on the existing send cycle, so an ex-member's endpoint no longer waits for an administrator to open a page. This removes a person's task from a data-protection duty (eliminate through a rule). Supported.
- **CGR-96 (#693, two `/field` cards for one moved visit in one e2e attempt):** root cause UNKNOWN; no workflow step to review. If it is a product defect, a duplicate visit would cost the team a phone round and a billing correction; the remedy (pgTAP proof) is Engineering's. Not a finding.

### 2 AI readiness of delivered items
- Nothing merged since review 11 proposes, drafts or ranks. 0096 is a read restriction and a deterministic sweep; no ledger entry is needed.
- **AIG1 (claimed, not built), §8 check against the brief as it now stands:** suggestion ledger (AIG1-1, -2) PLANNED; provenance per value (AIG1-3) PLANNED; named confirmer read per value only (AIG1-11) PLANNED; no accept-all on listed fields (AIG1-5) PLANNED, with the look-back gap of AUT-23 (a); correction rate per agent and field (AIG1-7) PLANNED; stop rule (AIG1-8) PLANNED, **now with a recovery path (AIG1-12)**; evaluation on synthetic data PLANNED (pgTAP per criterion, synthetic seed only). Nothing IMPLEMENTED yet.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED; claimed by `eng` 23:07 on #536 (in progress, no PR read); brief now carries D-35 term 9 at table level (AIG1-11) and a stop look-back (AIG1-12). Open: AUT-23 |
| 0 | Per-entry provenance in clinical records | **IMPLEMENTED for observations including OBS1-C1** (#673, #688); drafts and their origin still OPEN |
| 0 | ASM1 built | PLANNED, not started |
| 1 | Employee information names confirmation records and the look-back purpose (D-9, `lca` 20:40, 21:45) | OPEN, owner (pilot precondition, added) |
| 1 | Real data may reach any test, pilot or AI path | blocked (owner precaution until D-1 is clarified; owner package required by D-35) |
| 1-3 | other conditions unchanged from review 1 | OPEN |

### 4 Findings closed
- None closed with delivery evidence. **AUT-22 (high):** adopted by the PO as **AIG1-11** (21:15), issue #686 closed by the PO; the finding stays OPEN until AIG1 is delivered with the AIG1-11 pgTAP block. AUT-21: adopted as UX2-26, not delivered. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20: unchanged.

### 5 Waiting for the PO
- **AUT-23 (medium):** (a) one-by-one re-confirmation on the look-back list, best placed before the first AIG1 PR (`eng` claimed 23:07); (b) the "überholt" exit, after the `cra` / Clinical Owner answer on superseded values.
- AUT-19, AUT-20 as in review 9; AUT-21 delivery of UX2-26; AUT-22 delivery with AIG1.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32).

---

## 2026-10-29 20:20 CET · aia review 11: OBS1 delivered and accepted (#673, PO 19:40) reviewed; AUT-21 adopted as UX2-26; AUT-22 (high: AIG1 keeps the per-value confirmer selectable by direct query); D-1 precaution added to stage tracking

**Read:** `recovery/main` at `a968727`:
- merged since review 10: #660 (reviews 9 and 10), #670, #672, #678, #681, #683 (PO 14:35 to 19:40), #674, #679, #682 (`lca` 16:05, 17:00, 18:40), #675 (`uxa` 16:10), #677 (PO, owner D-1 precaution), **#673 (OBS1, migration 0095, ADR-118, merge `1fa6f26`)**;
- open: #685 (`uxa` 19:50), `cra` #680 (17:30, CGR-94) and its chain; `eng` on #536: OBS1-C1 with ADM2-C1 first, **AIG1 in the next run(s)**;
- briefs changed: OBS1 (OBS1-4 wording, OBS1-7, acceptance with OBS1-C1, OBS1-C2), UX2 (UX2-23 wording, **UX2-26 from AUT-21**, UX2-27); D-1 (owner precaution: no real client data for tests or pilot until D-1 is clarified; no repository migration on the live project before the review result), D-23 (`lca` re-check behind OBS1-7); AIG1 unchanged since 2026-10-27 18:10.
- No open issue was labelled `automation` before this run.

**Nothing below is a measurement.** I ran no tests; CI states are as the PO reports them.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-22 | Every later assisted step (PLAN3 day plan first): the confirmer of a proposed value, i.e. every nurse who uses an assistant | **AI readiness of an approved item before build, not a challenge of a step.** PLANNED (AIG1 approved 2026-10-27, unchanged since 18:10; next after OBS1-C1): AIG1-2 and AIG1-3 store per value the confirmer and the outcome (`confirmed`, `corrected`, `rejected`) with time; AIG1-7 forbids a per-person **reader**. No criterion says who may **select the rows themselves** through the table API. D-35 `lca` term 9: the per-value confirmer is read per value or through the AUD1 purpose reader only, never aggregated per person (ArGV 3 Art. 26); not in any AIG1 criterion. Today's `lca` 16:05 finding on OBS1 (team-wide table select → per-person filter by direct Data API query; now OBS1-C1, a separate retrofit PR that rewrites pgTAP 016, 026, 049) shows the same shape. Effect on care time: if a nurse's accept/correct pattern can be listed, the safe behaviour is to avoid the assistant or accept unchanged (automation bias, H-20), so the administrative gain of every later agent is at risk. Size: UNKNOWN (no agent built) | **rule, built in from the start:** add one AIG1 criterion (e.g. AIG1-11): confirmer and outcome columns of the ledger and confirmation tables not selectable by `authenticated` (mechanism Engineering's, e.g. column grants as 0070, RLS3-4); "bestätigt von" read per value through the record's own function (AIG1-3 line) and through the AUD1 purpose reader; AIG1-7 stays the only aggregate, without a person key; `READ_PATHS.md` lists the columns under RLS3-4 and the pgTAP 071 list fails on an unlisted reader. No added step for anyone; equal safety (accountability per value is kept) | L | stage 0 (precondition of every later stage); PO (brief amendment before build), `lca` (term 9 reading), `eng` (mechanism); no clinical content | pgTAP: direct select of confirmer/outcome → 42501; the record function still returns "bestätigt von" per value; 071 list extended. After go-live, per team only: AIG1-7 correction share per agent and field (a share drifting only to "confirmed unchanged" is a warning sign, read per team, never per person) | high | #686; one comment on #536 |

**Briefs and items reviewed without a new finding:**
- **OBS1 as built (#673, 0095, ADR-118), challenge test:** the marker is set by an insert trigger; the nurse types nothing; the screen adds one `info` line per affected observation ("Qualifikation war beim Schreiben nicht erfasst", not red); nothing is refused, routed or counted. The handover now answers "who wrote this?" without a phone round. Added administration: none. Supported, as in review 10.
- **OBS1-C1 (= OBS1-7, per-visit read paths):** narrows reads only; no step for a nurse or administrator; supported. It is also the template for AUT-22.
- **OBS1-C2 (`cra` CGR-94):** of the three ways, `eng`'s statement in the deploy record ("no observation between 0091 and 0095") is the leanest and changes no screen; the derived marker or the neutral line "Qualifikation beim Schreiben nicht bekannt" only where that statement cannot be made. Patient-safety and accuracy control (DSG Art. 6 Abs. 5, `lca` 18:40); not administration; not challenged.
- **UX2-26 (PO 15:40, from AUT-21):** taken in as proposed (same card, existing command, not preselected, "Später", the gap visible in the admission list). Supported.
- **UX2-23 wording (`uxa` 16:10):** one confirming step on two rare administrator switches, in place, focus moved; supported (review 10).
- **UX2-27 (one author label):** removes a member code from the handover; supported.
- **D-1 owner precaution and its explicit default (PO 17:00, 19:15):** no real client data for tests or pilot runs; no migration on the live project before the review result. A data-protection precondition, not administration; recorded in stage tracking below.

### 2 AI readiness of delivered items
- Nothing merged since review 10 proposes, drafts or ranks. The OBS1 marker is a deterministic fact fixed at write time (no ledger entry needed).
- **Per-entry provenance in clinical records is now IMPLEMENTED for observations** (author per observation in the handover and in new report snapshots; signed snapshots unchanged; per entry only, residual table read closed by OBS1-C1). The §12 control for later documentation drafts (the confirmer is the author; draft origin a separate per-entry fact) can build on it unchanged.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED; *Next up* 1 after OBS1-C1 (`eng` #536); not started. **Missing in the brief:** D-35 term 9 at table level (AUT-22, #686) |
| 0 | Per-entry provenance in clinical records (§8 "provenance per value") | **IMPLEMENTED for observations** (OBS1, #673); OBS1-C1 PLANNED; drafts and their origin still OPEN |
| 0 | ASM1 built | PLANNED, not started |
| 1 | Real staff or client data may reach any test, pilot or AI path | **blocked additionally** by the owner precaution of 2026-10-29 until D-1 is clarified (documented review, result recorded); besides the new owner package D-35 requires (provider, region, contract) |
| 1-3 | other conditions unchanged from review 1 | OPEN |

### 4 Findings closed
- None. **AUT-21 (medium):** adopted by the PO as **UX2-26** (15:40; may ride with UX2-22/UX2-23); stays OPEN until delivered. AUT-14, AUT-15, AUT-17, AUT-19, AUT-20: unchanged.

### 5 Waiting for the PO
- **AUT-22 (high, #686):** answer before AIG1 build starts (one criterion and one pgTAP block now instead of a later OBS1-C1-style retrofit).
- AUT-19, AUT-20: as in review 9. AUT-21: delivery of UX2-26.
- Bottleneck map refresh: due 2026-11-03 (weekly); candidates unchanged (onboarding contract to first visit, P-28, P-32).

---

## 2026-10-29 14:55 CET · aia review 10: ADM2 merged (#647) and OBS1 approved (PO PR #670) reviewed; AUT-21 (onboarding: the qualification is a second administrator step in another place); OBS1 supported

**Read:** `recovery/main` at `064a6c0`:
- merged since review 9: #647 (ADM2 incl. ADM2-15 (c) and ADM2-16, migrations 0091, 0092, 0094, ADR-115, ADR-117; merge `1cc31d4`, CI green on head `eccf343` as reported by `eng` 14:35), #653, #655, #657 (`uxa` 11:53), #658, #659, #661, #663 and #667 (`lca` 09:45, 13:57), #664, #665 (PO 10:15, 12:15), #668;
- open: #670 (PO 14:35: ADM2 accepted with ADM2-C1; **OBS1** approved, *Next up* 1 ahead of AIG1; G-23 extended, G-24 new; read at its branch head), `cra` #666 (13:40, CGR-93) and its chain, this PR #660 (review 9; merge conflict in `JOURNAL.md` resolved by merging `recovery/main` in, both entries kept);
- code: `set_member_qualification` (0018, patched 0046; organisation `admin` only, free-text reason 3-300), `src/app/(protected)/admin/admission-section.tsx` ("Vertrag erfassen", shows "angegeben: <Qualifikation>" and the sentence "Die Qualifikation setzt die Administration wie bisher beim Mitglied"), `admin-client.tsx` ("Qualifikation fehlt", "Qualifikation ändern" on the member entry), 0094 (`qualification_missing`, one audit row per refusal).
- No open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests; CI states are as read through the API or as other roles report them.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-21 | Onboarding: a colleague the team admitted (ADM2) starts working (organisation administrator; the team waiting for her) | **Challenge of the form, never of the gate.** The qualification gate has a clear patient-safety benefit and stays (ADM2-6, ADM2-16, D-29 verification with the owner). **IMPLEMENTED since #647:** after the team admits, the administrator records "Vertrag erfasst" on one card, which shows the claimed qualification as "angegeben" and tells her to set the qualification elsewhere; she must then open the member's entry in another section ("Qualifikation fehlt"), choose "Qualifikation ändern", pick the value and type a reason. Until she does, ADM2-16 refuses the new colleague every depart, start and complete (`qualification_missing`), planning, take and cover refuse her as responsible (ADM2-6), and the team keeps covering her share. **Added steps:** a second navigation and a second form for one administrator act that belongs to the same sitting; dead time between contract and qualification with no owner and no signal to anyone. Length of that gap and refusals per admission: UNKNOWN (no pilot data) | **simplify (same command, same place) and monitor; no new rule:** (1) after a successful "Vertrag erfassen" the same card offers the **existing** `set_member_qualification` for that member and team: the claimed value is shown beside the choice, **not preselected** (an explicit choice, no accept-all; verifying it stays the administrator's act under D-29), reason as today; skipping it is allowed. (2) The admission list keeps such a member under "Vertrag erfasst, Qualifikation fehlt" until it is set, so the gap has a visible place (the existing "Qualifikation fehlt" fact, no new field). Equal safety: same actor, command, check, audit row and refusals; nothing sets a qualification without the administrator's own choice | L (administrative record; the qualification value itself stays the employer's verified fact, D-29) | stage 0; PO (UX2 or with ADM2-C1), `uxa` (card layout), `lca` only if D-29 changes who verifies | per organisation and month: median days from "Vertrag erfasst" to qualification set (target: same day); `qualification_missing` refusals per admitted member in her first 14 days (target: 0); admissions where the team still covered visits because the newcomer could not perform. Never per person | medium | – (report and one comment on #670) |

**Briefs and items reviewed without a new finding:**
- **OBS1 (PO 14:35, #670, *Next up* 1), challenge test:** the marker is derived at write time from a recorded fact (`private.actor_may_perform_visit`); nobody types it, no observation is refused, routed or ranked by it, and the author line removes the phone round "who wrote this?" in the handover. Added administration for a nurse: none; one read line per observation. Patient-care benefit shown (the reader knows whose observation she relies on and whom to ask; `lca` reads authorship as a ZH GesG § 13 duty). Supported. The OBS1-6 `lca` read is a legal check of our own process, not a nurse step; not challenged. The two AN2 measures are team-level counts; supported.
- **OBS1 and AI readiness (forward, no finding):** OBS1 builds the first per-entry provenance in clinical documentation. Recorded as a control in AI Operating Model Review §12: when a later stage lets an agent draft an observation or report text (A-catalogue documentation drafts, D-35 stage 1 or later), the author shown is always the confirming person, and the draft origin is a separate per-entry fact beside it, in the same line; an agent is never shown as an author, and the origin is never a per-person list or count (RLS3-4). Engineering's OBS1-1 choice (column vs derivation) is theirs; nothing in OBS1 needs to change for this.
- **ADM2-C1 (push subscriptions deleted by the first sweep after an automatic access end):** a deterministic sweep instead of a person's task; supported.
- **UX2-22 (hide refused field controls for a member without a recorded qualification):** removes taps that are always refused; supported, and with AUT-21 the state it hides should rarely last more than a day.
- **UX2-23 (one confirming step before switching team admission and before "Vertragsende entfernen"):** adds one tap to two rare administrator commands; the second keeps a person's access after her contract end (data protection), so the form is proportionate. Supported; not challenged.
- **UX2-24, UX2-25, PO challenge 12:15 ("a screen offers a control the server always refuses"):** supported; the PO's general rule is the screen-side twin of AUT-21 (the place of action shows the state and the next step).
- **ADM2 accepted (ADR-115 deviations, ADR-117 deviation 1):** `record_no_show` by a member without qualification not refused: supported (refusing it would hide a missed visit from the team and OPS1/SIG1).

### 2 AI readiness of delivered items
- Nothing merged since review 9 proposes, drafts or ranks. ADM2's consent count (`least(2, n)`) and contract end are deterministic rules; ADM2-16 is a refusal; no ledger entry is needed.
- ADM2-15 (c) ("Fall öffnen" on each successor item) is the first IMPLEMENTED case of the §12 control "an item that asks for an action links to the place of action".

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED; now *Next up* 2, behind OBS1 (#670, open); not started |
| 0 | ASM1 built | PLANNED, not started |
| 0 | Per-entry provenance in clinical records (§8 "provenance per value") | PLANNED for observations through OBS1 (author and marker per entry); drafts and their origin still OPEN |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- None. **AUT-20 (medium):** adopted into hypothesis P-30 by the PO (09:10); stays OPEN until the split count is part of a brief's measures. **AUT-19 (medium):** OPEN, waits for UX2-17. AUT-14, AUT-15, AUT-17: unchanged.

### 5 Waiting for the PO
- **AUT-21 (medium):** qualification offered on the "Vertrag erfasst" card, and the gap kept visible, before G-23 if possible (it decides whether a team-admitted colleague can work on day one).
- AUT-19, AUT-20: as in review 9.
- Bottleneck map refresh: due 2026-11-03 (weekly); onboarding (contract to first visit, AUT-21) added as a candidate next to P-28 and P-32.

---

## 2026-10-29 08:25 CET · aia review 9: AUT-18 closed (#655 merged); P-30 reviewed (AUT-20, the existing uncovered-visit monitoring reaches Operations, not the team); ADM2 answers and ADM2-15 (c) supported

**Read:** `recovery/main` at `dcd5ffa`:
- merged since review 8: #627 (my review 8), #633 (VIS1 follow-up, `35b5a96`), #637, #640, #641, #642, #643, #645, #648 (`lca` 05:42, D-37), #651 (PO 06:10), #653 (issue #650), #655 (VIS1-10, `eng`, ADR-116, migration 0093);
- open: #659 (PO 08:15: VIS1-10 met, acceptance waits for the `cra` VIS1-7 gate on #655; ADM2-15 (c) from `uxa` UXR-42), #658 (`eng`, #655 merged before the `cra` gate, deviation recorded), #657 (`uxa` 07:50), #647 (ADM2 draft), `cra` #646, #639 and older;
- code: `move_visit_to_today` (0093) and `field-client.tsx` (ADR-116 point 3); `visit_uncovered` (0044 header, CR-049) and its delivery rule (SIG1, 0060 header).
- CI on `dcd5ffa` as read through the API at about 08:22: app, db, ui-screenshots green in both runs; e2e green in one run, in progress in the other. No open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-20 | Coverage: a visit released by an absence or a move waits without a responsible member (team; PO hypothesis P-30, 03:10) | **Comment on P-30 (no build).** P-30's next step, if pilot data show ownerless visits at start, is a PLAN3 criterion that **proposes a named owner** (agent at the edge, AIG1 confirm). **Evidence that monitoring already exists (IMPLEMENTED):** the derived exception `visit_uncovered` exists exactly while a visit is planned, nobody is responsible and it is not covered (0019, 0038, 0044, CR-049; P2, 24 h window, PROVISIONAL until D-28) and closes only with its cause. At P2 it is pull-only and shown on OPS1 (`src/features/operations/`), the Operations role's screen; SIG1 (0060) pushes it to every present member of the owning team only when an organisation raises it to P1. So by default the one signal about the team's own coverage gap reaches the central role, while the team has the "Offen im Team" list it must remember to read (P-30's premise). Effort and frequency: UNKNOWN (no pilot data) | **monitor before agent, design order kept:** (1) P-30's count also splits takes made after the exception appeared on OPS1 (Operations acting for the team) from takes by the team (list, VIS1-11 notice, later PLAN3), so the pilot shows whether coverage is being centrally dispatched; (2) if ownerless-at-start is material, the first remedy asked is the **existing** `visit_uncovered` delivered to the owning team (SIG1 recipients, no new rule, no new threshold): its priority and window are a D-28 question for `cra` and the Clinical Owner, never set by `aia` or the PO; (3) only if that is not enough, a PLAN3 owner proposal, with the controls in AI Operating Model Review §12 (fixed candidate order shown with its reason; a person who does not take the visit leaves no trace about her; correction rate per agent and field at team level only; responsibility only through `take_open_visit` and her own tap) | L (responsibility under an existing rule; priority of the signal is H-adjacent and stays with D-28) | stage 0; PO (P-30 measure wording), `cra` and Clinical Owner (D-28 priority and window), `uxa` if the team view changes | per team and month: released visits; median time from release to `taken`; share ownerless at visit start (target: 0); share of takes made by Operations after the OPS1 exception versus by the team | medium | – (report only; no open PR or issue carries P-30) |

**Briefs and items reviewed without a new finding:**
- **ADM2 PO answers (06:10):** (1) a team with no other active member admits on the proposal: supported; a consent nobody can give would return every founding nurse to an administrator (a hierarchy step) with no safety gain, since qualification (ADM2-6) and the employer's contract record still gate care. (2) decline = withdrawal: one outcome less to model; supported. (3) an admitted proposal without "Vertrag erfasst" lapses after 14 days with its candidate data deleted: a deterministic sweep instead of a person's reminder, and data minimisation; supported. The pilot count by number of consents is team level.
- **ADM2-15 (c) (PO 08:15 in #659, from `uxa` UXR-42, issue #656):** the successor item links to the case card and the card shows its reference. This removes a search and a phone call ("which case is that?") and adds one secondary line, not a field anyone fills; the benefit is shown (the CGR-72 remedy can be acted on). Same pattern as AUT-19. Supported, and the PO's general rule ("an item that asks for an action links to the place of action") is taken into §12 of the AI Operating Model Review as a control for every agent proposal.
- **PO scope rule (04:10):** after `changes-requested`, only patient-safety findings enter the capability; the rest go to UX2 or a later brief. This cuts review-driven engineering and `cra` cycles, which is administration of our own process. Supported; `aia` follows it (AUT-20 names no VIS1 criterion).
- **P-31 (night shift vs calendar day) and P-32 (a team divides itself):** both measure first at team level and keep the record and responsibility rules where they are (DAY-1; `cra` on a responsibility transfer). P-32 is a care-graph elimination candidate (cases move with primary nurse and deputy in one command instead of re-entry); taken into the bottleneck map refresh (due 2026-11-03) under team self-organisation.
- **#655 (VIS1-10):** see §4. ADR-116 "Not done": a midnight tolerance and past-dated field actions stay UNKNOWN for the Clinical Owner (CGR-87 (3)); `aia` proposes none.
- **#658, #657:** process and UX notes; no nurse step added.

### 2 AI readiness of delivered items
- #655 adds no proposal, draft or ranking: the re-derived times are the VIS1-3c deterministic default, and the re-offer shows the database's value for one more confirm. It is the first IMPLEMENTED case of the §12 control "the stored value is the value the confirmer saw" (refusal `day_changed`, one audit row, nothing changed; pgTAP 093 as described in ADR-116, CI as read above).
- Nothing merged since review 8 proposes, drafts or ranks; no ledger entry is needed.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED, *Next up* after ADM2 (ADM2 in build, draft #647); not started |
| 0 | ASM1 built | PLANNED, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- **AUT-18 (low):** closed. Evidence: adopted into VIS1-10 (PO 03:10), built in #655 (merged `dcd5ffa`; ADR-116 point 3: on `day_changed` the confirmation stays open with the UXR-39 sentence, the database's today, times re-derived by VIS1-3c and the typed reason kept; reload only as fallback); the PO's 08:15 review (#659, open) marks VIS1-10 met. The `cra` VIS1-7 gate on #655 is still pending; if it returns VIS1-10, `aia` reopens AUT-18 in a new section.
- **AUT-19 (medium):** stays OPEN. Adopted as VIS1-11 / UX2-17 (label "Übernehmen", UXR-38); not in #655 (ADR-116 deviation 3), so it waits for UX2.

### 5 Waiting for the PO
- AUT-20 (medium): P-30 measure split by who took the visit (team or Operations), and the existing `visit_uncovered` delivered to the team (D-28 priority, `cra`) before any PLAN3 owner proposal.
- AUT-19 (medium): built with UX2-17.
- AUT-17 (low), AUT-14 (medium), AUT-15 (low): unchanged; D-38 frozen, nothing written about it.
- Bottleneck map refresh: due 2026-11-03 (weekly), with P-28 (window instead of a fixed day) and P-32 (team split) as candidates.

---

## 2026-10-29 02:45 CET · aia review 8: AUT-16 closed (#624 merged); VIS1-10 and P-29 reviewed (AUT-18, AUT-19); no item proposes, drafts or ranks

**Read:** `recovery/main` at `6d3eb34`:
- merged since review 7: #624 (VIS1, `5d85b8f`, CI green on `30cbde1` as read by the PO), #625, #630, #632 (PO 22:15, 23:15 `changes-requested`, 00:15: VIS1-3c to VIS1-3g, VIS1-8, VIS1-9; hypotheses P-27, P-28, P-29), #629 (`uxa` 22:00);
- open: #633 (`eng`, VIS1 follow-up, read at head `ae3e98e`: `field-client.tsx` released notice, `rules.ts`), #640 (PO 02:15: issue #638 placed as VIS1-10; read at head `307bca3`), #637 (`eng`, e2e run-day guard, #635), #639 and #628 (`cra`), #634 (`uxa`), this PR #627 (my review 7; `db` red on `e0c5208` in pgTAP 079 test 44, the known intermittent failure #399 / CGR-86; continued here, not a second PR);
- code: `take_open_visit` and `team_open_visits` (0046), `absence-section.tsx` (the only caller of `takeOpenVisit`), `reschedule_visit` release path (0056).
- No open issue is labelled `automation`.

**Nothing below is a measurement.** I ran no tests; CI states are as read through the API.

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-18 | Visit: "Heute machen" on a page opened before midnight (nurse at the door at night, `/field`) | **Challenge (form, not existence) of VIS1-10 (PO PR #640, open).** The benefit is shown and the control stays: the stored date must be the database's today and must not contradict the "Heute, <Datum>" the nurse confirmed (record integrity, value 2). **Added step:** on a refusal she reads a sentence, reloads `/field`, finds the card again, reopens "Heute machen" and re-enters what she had (VIS1-3c times are re-derived; the typed reason, VIS1-3b, is lost). Frequency UNKNOWN (page open across midnight; night visits) | **rule, leaner form at equal safety:** the refusal returns the database's day; the same dialog stays open with the new date shown ("Inzwischen ist der <Datum>"), the times re-derived by the VIS1-3c rule, the typed reason kept, and the confirm button enabled again. One more tap on the visible new value instead of a reload and a re-entry. Equal safety: the database still refuses any date that is not its today, the stored value is always the value shown at the last confirm (no silent replacement), the refusal audit row stays. Wording `uxa`; `cra` VIS1-7 gate as already set for VIS1-10. If not taken into VIS1-10, it fits UX2 | L (schedule fact) | stage 0; PO (VIS1-10 wording "reload" or "re-offer"), `uxa`, `eng` (ADR-113) | per team and month: count of `day_changed` refusals and share followed by a successful move of the same visit within 5 minutes (target: all, without a reload) | low | – (comment on #640) |
| AUT-19 | Visit: a move releases the visit because its responsible member is absent at the new time (nurse who moved it, `/field`; PO P-29) | **Comment on PO P-29 (no build, 00:15):** the PO reads "who becomes responsible" as a care-responsibility rule still to be set. **Evidence that the rule already exists (IMPLEMENTED):** `take_open_visit` (0046) lets a member of the visit's team take a planned, uncovered visit with nobody responsible, one tap, first wins, with the J3 qualification check `may_perform_visit`, an absence check at the visit's time and a `taken` row in `visit_plan_changes`. Today it is reached only from "Offen im Team" (`absence-section.tsx`), so after a released move the nurse at the door must scroll to that list, find the visit she just moved and tap again; #633 (VIS1-3d) shows the released notice (`attention`) with no action | **eliminate the search, no new rule:** the VIS1-3d released notice carries one outline action "Ich übernehme" that calls the **existing** `take_open_visit` for that visit, with its existing checks and refusals (`not_qualified`, `absent`, `already_taken` shown with the existing texts). Separate tap, never automatic: the move does not assign her, and nothing assigns without her own tap. P-29's AN1 count stays the way to see whether more is needed (e.g. a combined command); `aia` proposes none | L (responsibility under an existing rule; no clinical content) | stage 0; PO (now as part of VIS1-3d / VIS1-3f or UX2), `uxa` (position next to the notice), `cra` only if the action text or tone changes the VIS1-3d notice (VIS1-7 gate) | P-29 count (released moves started by the mover within 30 minutes) split by taken from the notice versus from "Offen im Team"; released moves still without a responsible member at visit start (target: 0) | medium | – (comment on #640) |

**Briefs and items reviewed without a new finding:**
- **VIS1-3c (UXR-30), VIS1-3d to VIS1-3g, VIS1-8, VIS1-9:** VIS1-3c removes a false `visit_overdue` alarm per early visit (a teammate's call saved; supported). VIS1-8 is a deterministic read, no tap (supported in review 7). VIS1-9 is the same rule on another write path; no person step. VIS1-3f and VIS1-3g are presentation. No administration added.
- **P-27, P-28 (PO challenges):** both are care-graph eliminations and `aia` supports measuring first. P-28 (a window instead of a fixed day for a weekly service) would remove every early-visit move at its source, which is where AUT-16, AUT-18 and AUT-19 all start; it needs a missed-visit rule for a window (`cra`, Clinical Owner, D-28: UNKNOWN). Taken into the bottleneck map refresh (due 2026-11-03) as a Planning candidate.
- **#637 (e2e run-day guard):** test infrastructure; no nurse step.
- **AUT-17 (low, placeholder on the move reason):** not in #633 (no placeholder in the diff). Stays OPEN; allowed, not required.

### 2 AI readiness of delivered items
- #624 (merged) prefills today's date and the card's times; #633 replaces the times with the VIS1-3c rule (next full 5 minutes, planned duration). These are deterministic defaults, not proposals, drafts or rankings; no ledger entry is needed. Nothing merged since review 7 proposes, drafts or ranks.
- **Forward control (AI Operating Model Review §12, extended):** "now" is the database's day; a stored value is the shown value, re-shown when the day changed (AUT-18); responsibility after a release only through `take_open_visit` and the person's own tap (AUT-19).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED, *Next up* after ADM2; not started |
| 0 | ASM1 built | PLANNED, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- **AUT-16 (medium):** closed. Evidence: VIS1-3b IMPLEMENTED in #624, merged `5d85b8f`; the PO's 23:15 review marks VIS1-3b met (`vis1.spec` 72-106: one confirmation on `/field`, existing `reschedule_visit`, the start its own tap); `cra` 22:00 (PR #628) VIS1-7 gate clear. The reason is typed, not prefilled (`cra` 21:30), accepted in review 7. The measure (moves to today from `/field` versus `/team`) becomes countable from the `moved` rows.

### 5 Waiting for the PO
- AUT-18 (low): VIS1-10 refusal re-offers the new date in the same dialog instead of a reload. Comment on #640.
- AUT-19 (medium): "Ich übernehme" on the released notice through the existing `take_open_visit`. Comment on #640.
- AUT-17 (low), AUT-14 (medium), AUT-15 (low): unchanged; D-38 frozen (rule 9), nothing written about it.
- Bottleneck map refresh: due 2026-11-03 (weekly), with P-28 as a Planning candidate.

---

## 2026-10-28 22:00 CET · aia review 7: AUT-16 adopted as VIS1-3b and built in #624 (open); `cra` keeps the reason typed; CGR-89 supported as a fact line; AUT-17 (low)

**Read:** `recovery/main` at `013b733`:
- merged since review 6: #622 (mine), #620 (PO 20:15: COORD6 accepted; VIS1 *Next up* 1 with VIS1-3a from UXR-29 and VIS1-3b from AUT-16, reason not prefilled until `cra`);
- open: #624 (`eng`, VIS1, ADR-111, migration 0089; read at head `2db589d`: `field-client.tsx` move dialog, `features/field/rules.ts`, ADR-111), #623 (`cra` 21:30: VIS1-3b prefill not confirmed, CGR-89; read at head `f6cafc6`), #614, #604, #589, #582 (contained in #623);
- No open issue is labelled `automation`.

**Nothing below is a measurement.** CI on #624 not read as passed; ADR-111 says vitest, typecheck, lint, build and Playwright were not run locally (CI decides).

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-17 | Visit: the reason for moving an early visit (nurse at the door, `/field`, VIS1-3b) | **IMPLEMENTED in open PR #624:** the dialog shows an empty, required `reason` textarea (3-300 characters, `field-client.tsx` at head `2db589d`) and a hint `MOVE_TO_TODAY_HINT` that explains the move ("… im Verlauf festgehalten …"), not what to write. `cra` 21:30 (#623) named a non-submitted placeholder ("Warum heute? z. B. Wunsch der Klientin") as an acceptable aid that keeps the J3 duty. Effort: one typed sentence per early visit, at the door; thinking about what is expected is the part a placeholder removes. Size UNKNOWN (no AN1 count of early moves yet) | **simplify:** a `placeholder` on the reason field asking *why today*, never submitted, never prefilled (`cra` answer kept). Rides #624 if `eng` touches the dialog again, otherwise UX2. Wording `uxa`; no reason list (that would be a reason catalogue, PO documentation rule with a Clinical Rule Register row first, `cra`) | L | stage 0; gate PO, `uxa` (wording) | AN1: per team and week, number of VIS1-3b moves and median time from opening the dialog to confirm (team level only, never per person) | low | none (low) |

### 2 Reviewed without a new finding
- **AUT-16 → VIS1-3b (PO 20:15) and `cra` 21:30:** adopted with one change: the reason is typed, not prefilled. **Accepted by `aia`, no challenge:** `cra` shows that the prefill ("Heute statt am <Datum> gemacht") only restates the `before`/`after` of the `moved` row (0056) and always passes the 3-character minimum, so the duty would be met by default and the only fact NAVORA does not already know (why) would be lost. A prefill there would have removed a step in form only. The rest of AUT-16 is built in #624 as proposed: one confirmation on `/field`, today fixed, card times prefilled and editable, the existing `reschedule_visit` with its checks, the start its own tap. **AUT-16 stays OPEN** until #624 merges with CI green and the `cra` VIS1-7 gate is clear.
- **CGR-89 (`cra` 21:30, advisory S2; for the PO to place):** the confirmation states, as a fact read from the plan, whether the client still has a visit planned on the date the visit leaves. **Supported from the automation side:** it is a deterministic read (no field, no tap, no rule, no level), and it puts at the door the one fact that otherwise someone would have to look up on `/team` afterwards. It is the eliminate-through-the-care-graph pattern. Whether a gap needs a replacement visit is the Clinical Owner's (UNKNOWN); `aia` proposes no signal or rule for it.
- **#624 otherwise:** no step added for a nurse beyond the brief. The refusal audit row (ADR-111 decision 2) is written by the database, not by a person. ADR-111 decision 4 confirms that a member of the visit's team moves it herself (no coordinator), as AUT-16 assumed.

### 3 AI readiness of delivered items
- #624 prefills today's date and the card's own planned times. These are copies of existing values, not a proposal, draft or ranking; no ledger entry is needed. Nothing merged since review 6 proposes, drafts or ranks.
- **Forward control (AI Operating Model Review §12, extended):** any proposed earlier move from PLAN3 or the day-order agent (AUT-5) shows the CGR-89 fact line too, so a confirmer never moves a visit off a date blind.

### 4 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED, *Next up* behind VIS1 and ADM2; not started |
| 0 | ASM1 built | PLANNED, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 5 Findings closed
- None (AUT-16 closes on the #624 merge).

### 6 Waiting for the PO
- CGR-89 placement (`cra`); `aia` supports it (§2).
- AUT-17 (low): placeholder on the reason field.
- AUT-14 (medium), AUT-15 (low): unchanged; D-38 frozen (rule 9), nothing written about it.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-28 20:19 CET · aia review 6: VIS1 reviewed (AUT-16, the early visit as one confirmed move on `/field`); COORD6 and UX1 accepted; no item proposes, drafts or ranks

**Read:** `recovery/main` at `785278e`:
- merged since review 5: #607 (`eng` UX1 status), #608 (mine), #610 and #615 (`lca` 14:56, 17:41), #611 and #616 (PO 15:15, 16:15, 18:15), #613 and #618 (`uxa` 15:48, 19:48), #612 (COORD6, `eng`, ADR-110);
- open: PO #620 (`po/cycle-2026-10-28-2015`: COORD6 accepted, VIS1 *Next up* 1, VIS1-3a from UXR-29; read at its head), `cra` #614 (CGR-87, CGR-88), #604, #589, #582;
- briefs: VIS1 (new, approved 18:15, with VIS1-3a in #620), UX1 (accepted 15:15, conditions UX1-C1 to UX1-C3), UX2-14 to UX2-16;
- code: `reschedule_visit` (0012:133-134 team membership check; 0052 and 0056 patches), `src/features/team/commands.ts` (`rescheduleSchema`: date, start, end, free-text reason 3 to 300 characters), `src/app/(protected)/team/team-client.tsx` (the only screen that calls the move), `src/features/field/rules.ts` (`todayInZurich`, `fieldActions` without a date).
- No open issue is labelled `automation`.

**Changed since review 5:** VIS1 is a new approved brief (`cra` CGR-87, S1 before a pilot with real clients). COORD6 merged and is accepted in #620. UX1 accepted. D-38 is `awaiting-approval: owner` and frozen since 15:15 (rule 9): nothing below is written about the package itself.

**Nothing below is a measurement.**

### 1 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-16 | Visit: a nurse does a visit earlier than planned (nurse at the door, `/field`) | **Challenge (form, not existence).** VIS1 (approved; *Next up* 1 in #620) refuses depart, start, no-show and "not completed" on a visit dated after today, and asks the nurse to move it first. The patient-care benefit is shown and the guard stays: a future visit worked today masks a missed visit on its real date (CGR-87; H-01, H-05) and moves billable facts to a day without care. **Added step:** the move. Today the move exists only on `/team` (`team-client.tsx` → `rescheduleVisit`), where she enters a date, a start and an end time and a free-text reason of at least 3 characters (`commands.ts` `rescheduleSchema`), then returns to `/field` and starts. VIS1-3 / VIS1-3a give a link to that route; PO 20:15 reads `reschedule_visit` as open to any member of the visit's team (0012:134, Engineering confirms in the ADR), so no coordinator is needed. What remains is a screen change and three typed values per early visit, at the door. How often visits are done early: UNKNOWN (no event records it today; it will be countable once VIS1 lands, as moves to today) | **simplify (deterministic, no agent):** on the future-dated card the outline action is "Heute machen". It opens one confirmation on `/field` with the values prefilled: date today (Europe/Zurich, DAY-1), the planned start and end times as on the card (editable), and a reason text prefilled as "Heute statt am <Datum> gemacht" that she may edit. Confirm calls the **existing** `reschedule_visit` with its existing checks (ABS1-C4, ABS1-C5, CGR-35, audit and `moved` log row) and returns her to today's card, where "Einsatz starten" is now offered. No new command, no new permission, no combined "move and start" (the start stays its own tap, so the VIS1 guard is never bypassed). Equal safety: the same audited move, the same reason field, the same refusal paths. CGR-76 check: the control cited by CGR-87 (move first, with audit) is kept in full; only where it is entered changes. Whether a prefilled, editable reason meets the J3 reason duty: `cra` (UNKNOWN to `aia`). Gain: one screen change and two typed times per early visit; minutes UNKNOWN (estimate) | L (schedule fact; no clinical content) | stage 0; PO (whether VIS1-3a's link becomes this action, now or as a follow-up), `uxa` (form of the confirmation at 390 px), `cra` (prefilled reason text; VIS1-7 gate), `eng` (ADR: same command, no bypass) | number of visits moved to today from `/field` versus from `/team`, per team and month; share of those moves started the same day; overdue or missed signals on the original date of a moved visit (target: 0) | medium | – (comment on #620) |

**Briefs and items reviewed without a new finding:**
- **VIS1 guard itself:** a deterministic rule on a visit/schedule fact; no level, no tolerance coded (any tolerance is a Clinical Owner level, UNKNOWN). Supported: it removes a later correction (administration) and protects the signal chain. VIS1-6 keeps past-dated visits as they are, so a forgotten tap is still recordable; no new administration there.
- **VIS1-3a (UXR-29):** one sentence per future day instead of one per card; less reading, no step added. Supported.
- **COORD6 (merged #612, accepted in #620):** a check replaces a rule every agent had to remember. No step for any person. Consequence for `aia`: every later `aia` PR is checked against frozen packages by `agents-check`; this review writes nothing about D-38 for that reason.
- **UX2-14 to UX2-16:** colour, one error component, frame rule. Less to learn per screen; no workflow step added or removed.
- **UX1-C1 to UX1-C3:** test and string conditions; no nurse step.

**Answers placed on earlier findings (no change of severity):**
- **AUT-14, AUT-15:** `lca` 14:56: AUT-14 compliant with per-provider scoping (C's person sees an item only for clients whose choice and consent are recorded); AUT-15 compliant only if staff entries leave NAVORA on the person's own action (DSG Art. 28, OR Art. 328b, as cited by `lca`). Both conditions are now part of the proposals. Both stay OPEN; the package they relate to is frozen awaiting the owner.

### 2 AI readiness of delivered items
- Nothing merged since review 5 proposes, drafts or ranks (#612 is a repository check; UX1 parts are labels and states). Nothing to check against §8.
- **Forward control for PLAN3 and AUT-5 (added to AI Operating Model Review §12):** after VIS1, a proposal that a visit be done earlier is a proposed `reschedule_visit` (its date is a `record`-class field under AIG1-5, confirmed one by one), never a start; no agent and no shortcut starts a visit dated after today.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED. *Next up* 3 in #620 (after VIS1 and ADM2); COORD6 and UX1 no longer ahead of it |
| 0 | ASM1 built | PLANNED (*Next up* 4), not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Findings closed
- None.

### 5 Waiting for the PO
- AUT-16 (medium): whether the VIS1-3 / VIS1-3a move link becomes a one-confirmation "Heute machen" on `/field` (same command), in VIS1 or as a follow-up; `cra` on the prefilled reason. Comment left on #620.
- AUT-14 (medium), AUT-15 (low): unchanged, with the `lca` conditions above.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-28 14:41 CET · aia review 5: "designed from scratch" applied to the bottleneck map; D-38 T15 (b) readiness derived from the record (AUT-14); provider kit (AUT-15)

**Read:** `recovery/main` at `f6277ab`:
- merged since review 4: #587 (mine), #588, #591, #598, #602 (UX1 parts (d) and (g)), the PO cycles #590, #596, #601, #605, #606, `csa` #595, `uxa` #599, `lca` #600;
- open: `eng` #607 (UX1 delivered), `cra` #582, #589, #604 (not merged; read at head `ad18b4e` through the D-38 text that quotes it);
- README *Automation review* (new owner instruction "designed from scratch first", added by po 11:10), rule 9 (frozen packages bind every role); `STRATEGY.md` §8 (future-state model, `csa` 10:47); `CARE_OPERATING_MODEL.md` *Provider kit* (STR-19, P-25);
- briefs: COORD6 (new, approved), UX1-31 to UX1-33, UX2-12, WORK1-C5 (CGR-86); D-38 T15-T18 as of po 14:20 (unfrozen, `inputs-requested`);
- code: `src/features/team/rules.ts` (UX1-22 pointer), `src/features/push/rules.ts` (UX1-24 `allReachable`), `src/features/intake/rules.ts` (UX1-23), `src/features/field/todo.ts` (UX1-30).
- No open issue is labelled `automation`.

**Changed since review 4:** the owner's instruction (2026-10-28) now binds this review: start from "if we designed home care today", compare with current practice, then say eliminate, redesign, automate or replace. UX1 is fully merged (#598 `8d0e812`, #602 `f6277ab`; the register change is in #607, open). D-38 gained T15-T18. No delivered item proposes, drafts or ranks.

**Frozen packages (rule 9):** nothing written about any `awaiting-approval` package. D-38 is unfrozen (`inputs-requested`, po 11:10), so AUT-14 may address it.

**Nothing below is a measurement.**

### 1 The bottleneck map read from scratch (owner instruction 2026-10-28)

Reference: `STRATEGY.md` §8.1 (team owns its provider; coordination is a property of the record; one clinical language; machines propose, people decide; shared services without a headquarters; starting a provider is a product). The ranks of review 1 stand (estimate, ordinal); what changes is the verdict where the from-scratch model asks for more than an improvement.

| Rank (review 1) | Step | Improvement view (review 1) | From scratch (§8.1) | Changed verdict | Status |
|---|---|---|---|---|---|
| 1 | Travel and day order | day-order rule agent (AUT-5) + team geography | a neighbourhood team serving contiguous municipalities makes travel short by design; a route proposal only optimises the remainder | **replace first** (team geography through J2 matching and D-11), **automate second** (AUT-5). The team-level AN1 travel share is the test of both | PLANNED (AUT-5); geography OPEN (`csa`, D-11) |
| 2 | Documentation per visit | simplify, risk-based countersign, dictation later (AUT-4) | the record is written by doing: the care-plan items performed are the proof of delivery, and prose is needed only for what deviated or what the next nurse must know | **replace** "one free-text report per visit" with documentation by exception (P-2 in AUT-4), then dictation (A7, stage 2) only for the exceptions. Blanket countersign: **replace** with risk-based review (D-10, `clinical`). What a report must contain is the Clinical Owner's (UNKNOWN); this changes the form, not the duty | OPEN (D-10, G-1); A7 PLANNED stage 2 |
| 3 | Orders, referrals, relatives | eliminate by structured order and referral (AUT-6) | external actors are nodes of the record; nothing is phoned to be re-typed | unchanged: **eliminate** (AUT-6); waits on owner decisions D-22, D-9, D-3, not on build | OPEN |
| 4 | Who takes which visit | PLAN3 proposal (AUT-1) | no scheduling role exists | unchanged: **eliminate** the role; PLAN3 is the means | PLANNED (*Next up* 7) |
| 5 | Assessment → care plan | side-by-side view, import later (AUT-2, AUT-13) | one clinical language: the assessment is the source of the plan; nothing is typed twice | unchanged: **redesign** (ASM1, D-37); import (AUT-13) | PLANNED |
| 6-7 | Working time, status taps | simplify (AUT-8, AUT-7) | working time is a by-product of visits, confirmed | unchanged (WORK1 IMPLEMENTED; AUT-8 open with `lca`) | IMPLEMENTED / OPEN |
| 8-11 | Billing prep, referral pull, quality, self-organisation | eliminated or in progress | coordination is a state of the record | unchanged | IMPLEMENTED / PLANNED |
| **new** | **Founding a team's provider and moving to it** (team, its future Leitung Pflege; one-off per team, but months of work) | not in the map (D-38 was a partnership question) | **starting a provider is a product** (§8.1.6): a kit, with the readiness facts read from the record | **replace** a founding project with the provider kit (STR-19, po 11:10); **automate** the parts that are facts NAVORA already holds (AUT-14, AUT-15) | PLANNED (kit as documents); OPEN (AUT-14, AUT-15) |
| **new** | **Night and weekend on-call across teams** | not in the map | a contracted service shared by team-owned providers (§8.1.5) | no proposal: depends on P-24 (one Leitung Pflege or on-call service for several providers: UNKNOWN, `lca`, Zurich adviser) and D-3 (COVER1 off) | UNKNOWN |

**Why the new row matters for direct care time:** every hour a nurse spends assembling a licence file, a readiness list or a transfer checklist is taken from visits or from her own time; under D-38 it would be repeated per team unless the kit makes it a one-time product (P-25: second team at most half the time). Minutes: UNKNOWN until a first transition (estimate only).

### 2 Findings: new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-14 | Provider transition: proving the eight T15 (b) safety kinds before a client moves (team, both Leitungen Pflege, Clinical Owner) | D-38 T15 (b) (po 14:20 from `cra` 13:40) names eight kinds of safety measure; how they are shown to be met is not stated, so by default it becomes a compiled checklist per team and per cut-over date. Five kinds already exist as states NAVORA records: (2) an open safety signal without a named taker (`safety_signals.taken_by`, 0060/0063); (3) P1 reach outside the app (`allReachable`, `src/features/push/rules.ts`, UX1-24, IMPLEMENTED); (5) order validity on a date (`cases.medical_order_valid_until`, order alerts, 0024:426, :495); (6) qualification (`private.required_qualification`, 0017:301; `set_member_qualification`, 0018); the returned-report part of (2) (F6R). Not in the record: (1) a responsible provider per client and date (no provider entity; UNKNOWN for `eng`); (4) export (T2, T18 (e), not built); (7) rule adoption (T13, not built); (8) open `cra` S1 findings (a report fact, not data). Challenge duty: no administration is added yet; this finding keeps it that way. The control itself is a patient-safety precondition and stays | **automate (deterministic, no agent):** when the transition is briefed, the readiness for each kind is a read of the record for the moving clients and the cut-over date: a team-level list of the items that still block, each with the existing link to act on it, and the same list for every later team (kit, STR-19). No level, threshold or pass mark is set by the view: levels are the Clinical Owner's (G-1, UNKNOWN); the view shows counts and items, the Clinical Owner or a Leitung Pflege states that the level is met. Kinds (1), (4), (7), (8) stay manual until their data exist; each is named as manual in the view, never shown as met. Gain: one compiled checklist per team transition (and re-checks per postponed date) becomes a read; minutes UNKNOWN (estimate) | L (shows recorded states; no clinical content of its own) | stage 0; PO (whether to brief), `cra` (that the view shows kinds without a level and that no kind is shown as met without data), `eng` (kind (1): how a provider per client and date is recorded), `lca` (the partner's Leitung Pflege reads C-side items only within the D-12 processor scope) | hours from "Clinical Owner's levels set" to "readiness confirmed" per transition; number of kinds checked by hand per transition (target: four, falling as (1), (4), (7) gain data) | medium | – (comment on #545) |
| AUT-15 | Provider kit: C's licence file and set-up (future Leitung Pflege, team) | STR-19 (po 11:10): every transition document is written as a reusable kit; nothing built; no template states a legal or tariff rule not confirmed by `lca` and the adviser. Several entries a licence file and a processor agreement need are facts NAVORA already holds or will hold: the team roster with qualifications (0018), the named Leitung Pflege and deputy (T18 (b)), the rule-adoption record (T13, T18 (d)), the processor-agreement parties and data categories (T18 (c)). Which entries the Zurich licence file requires: [Z1] as read by `lca` 11:55; the full list is UNKNOWN to `aia` | **automate later (deterministic assembly):** the kit's templates mark each entry as (a) a fact read from the record, (b) a team decision, or (c) text `lca` or the adviser confirmed; only (a) is filled from the record, as a draft the future Leitung Pflege confirms entry by entry. No AI drafting of legal text; an AI draft of any part waits for a D-35 stage that allows it and `lca`. Staff data in a licence file is personal data: `lca` first. Gain: the team does not re-type its own roster and roles into each document; minutes UNKNOWN (estimate) | L | stage 0 (deterministic); PO (only when the kit is built), `lca` (which staff facts may leave NAVORA into a licence file, to whom) | P-25 (consent decision → C's admission, first versus second team) | low | – |

**Briefs and items reviewed without a new finding:**
- **COORD6 (approved, *Next up* 2):** a deterministic check replaces a rule that every agent had to remember. It removes coordination work (value 5) without adding a step for any person; it is the pattern §8.1.2 asks for, applied to the agents. Supported.
- **WORK1-C5 (CGR-86):** a privacy control (WORK1-5 keeps the working day the nurse's own). Not administration; no challenge. It does matter for AUT-9: a team-level correction share for WORK1 must not be read while the test that guards D-23 term (b) is red at random.
- **D-38 T16 (stop and lift):** any member may pause a date without asking anyone, and the current provider keeps visiting: team autonomy at no care cost. The single person who lifts is already named as a gap by the PO (deputy for the Clinical Owner, G-1); `aia` agrees and adds nothing.
- **D-38 T15 (a), (d), (f), T17, T18:** legal and financing terms; no workflow step for a nurse beyond what AUT-14 and AUT-15 cover.
- **UX1-22 (merged):** a list entry that only repeats an open P1 card shrinks to one pointer line, fail-safe to the full entry. Less reading per safety situation, deterministic, no ranking. **UX1-23, UX1-24, UX1-30 to UX1-33, UX2-12:** wording, colour, focus and headings; no workflow step added or removed.

### 3 AI readiness of delivered items
- Nothing merged since review 4 proposes, drafts or ranks (UX1 parts (d), (g) are labels, focus, a fail-safe dedupe and a reach status). Nothing to check against §8.
- WORK1 stays outside the register (AUT-9, low); see WORK1-C5 above.

### 4 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED. UX1 merged in full (#598, #602; register update in #607, open). AIG1 is *Next up* 4, after COORD6 and ADM2 |
| 0 | ASM1 built | PLANNED (*Next up* 5), not started |
| 1-3 | unchanged from review 1 | OPEN |

### 5 Findings closed
- None.

### 6 Waiting for the PO
- AUT-14 (medium): whether D-38 T15 (b) is shown by a read of the record when the transition is briefed; `eng` on kind (1). Comment left on #545.
- AUT-15 (low): for when the provider kit is built; `lca` on staff facts in a licence file.
- Bottleneck map refresh: due 2026-11-03 (weekly); the from-scratch reading above is part of it.

---

## 2026-10-28 08:20 CET · aia review 4: AUT-13 import conditions from `cra`; UX1-30, UX2-10, UX2-11 reviewed; no new finding

**Read:** `recovery/main` at `221d4ae`:
- PO 02:10 (#578), 04:10 (#581), 06:10 (#583): ASM1-1 period storage; UX1-28 (d)-(e); UX1-30; UX2-10; UX2-11; the PO challenges on returned reports (04:10) and on AUT-13 (06:10);
- `eng` #574 merged (`93f7423`, ADR-106: UX1-18 axe `color-contrast`, UX1-27 `FOLLOWUP_HEADING` in `src/features/field/todo.ts`);
- `uxa` 03:50 and 07:50 (#580, #586);
- `cra` 05:30 on the open PR #582 (`gov/review-2026-10-28-0530`, not merged): the AUT-13 import conditions and agreement with AI Operating Model Review §12;
- the JOURNAL from 02:10 to 07:50. No open issue is labelled `automation`.

**Changed since review 3:** no item that proposes, drafts or ranks was delivered (#574 is a contrast check and a label constant). `cra` 05:30 and the PO 06:10 answered AUT-13. Three acceptance criteria were added (UX1-30, UX2-10, UX2-11).

**Not re-done:** the bottleneck map v1 (review 1, 2026-10-27 14:48) stands; its weekly refresh is due 2026-11-03. **Nothing below is a measurement.**

### 1 Findings: changes

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-13 | Needs assessment: transcription into ASM1 (assessing RN) | **Answered, still not actionable.** `cra` 05:30 (#582, open): the import is clinically acceptable as described, with three conditions for the later brief: (1) an imported draft is no assessment record until the assessing RN confirms it value by value (it neither satisfies a reassessment due date nor feeds A10); (2) the period is imported as the tool states it, never mapped or converted (CGR-84); (3) the record keeps per value whether it was imported or typed (H-22). PO 06:10: no hypothesis row until `eng` reports the field mapping; depends on D-36 licence terms and the ASM1 build. ASM1 not started (IMPLEMENTED: nothing) | unchanged: **eliminate later through the care graph (import)**. The three `cra` conditions are now part of the proposal and of AI Operating Model Review §12. Condition (3) is the provenance-per-value control of §8, so a later import needs no new control type. Next trigger: the ASM1 PR (`eng` notes the field mapping) or a D-36 licence answer | L (header values only, D-36 A) | stage 0; `lca` (D-36), `cra` (reviews the brief), PO | as review 3; after an import exists, the share of imported values confirmed unchanged, per team | low | – |

**Briefs and packages reviewed without a new finding:**
- **UX1-30 (PO 04:10, `cra` conditions 06:10):** one label per "Zu erledigen" link and its section. The instruction to correct and sign again keeps its words and its place in the section. The nurse reads one label instead of two; no step, field or approval is added.
- **UX2-11 (PO 06:10 from `cra` 05:30):** a returned report stays on her day until she signs it again. This is a continuity control with a shown patient-care benefit (F6R-5: no unsigned report drops out of sight). It also makes the leaner form possible that the PO named in the 04:10 challenge: the correction as the visit card's next action instead of a second list. `aia` supports that direction for UX2. Gain estimated as one fewer place to look per returned report; minutes UNKNOWN until F6R-9 (return share) has pilot data.
- **UX2-10:** CI coverage only (axe on working states); no effect on care time.
- **ASM1-1 period storage (CGR-84):** already reviewed in review 3; no change.

### 2 AI readiness of delivered items
- #574 does not propose, draft or rank: nothing to check against §8.
- WORK1 stays outside the register (AUT-9, low, unchanged).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED. UX1 is still `in-progress`: part (d) (UX1-11 to UX1-13, UX1-28 to UX1-30) and part (g) are open; UX1-18 and UX1-27 merged (#574). AIG1 is *Next up* after UX1 and ADM2 (#499 open) |
| 0 | ASM1 built | PLANNED; approved, not started |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Waiting for the PO
- Nothing new from `aia`: no `high` finding, no challenge, no issue opened.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-28 02:20 CET · aia review 3: AUT-2, AUT-10, AUT-11, AUT-12 taken in by the PO; ASM1 transcription (AUT-13); A10 input control

**Read:** `recovery/main` at `7eae8d0`:
- ASM1 as amended (po 21:15, 22:15; ASM1-1 period, ASM1-11 rewritten, no sum) and the open PO PR #578 (po 02:10: ASM1-1 period storage from `cra` CGR-84; UX1-28 (d), (e));
- UX1-25 to UX1-29 (po 20:15, 22:15, 00:15) and the open `eng` PR #574 (UX1-18, UX1-27);
- D-38 as frozen by po 01:10 (T12 (i) with (a)-(b), T13 with (a)-(f)), `lca` 20:48, 21:45, 23:41, 00:45;
- `cra` 21:30 and 01:30 (`CLINICAL_GOVERNANCE.md`: CGR-80 to CGR-84);
- `NEXT_CAPABILITY.md` challenge table (P-19, P-20, P-24); the JOURNAL from 20:30 to 01:30.

**Changed since review 2:**
- every review-2 proposal was answered by the PO (21:15): AUT-2 → ASM1-11; AUT-10 (b) → D-38 T12 (i), AUT-10 (a) → adviser bundle; AUT-11 → D-38 T13 form; AUT-12 → hypothesis P-24 and adviser question;
- `cra` CGR-81 rewrote ASM1-11 to "items listed as written, no sum"; CGR-84 fixes how the period is stored;
- UX1 parts (c) and (f) merged (#554, #558); no item that proposes, drafts or ranks was delivered.

**Not re-done:** the bottleneck map v1 (review 1, 2026-10-27 14:48) stands; its weekly refresh is due 2026-11-03. **Nothing below is a measurement.**

### 1 Findings: changes and new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-2 | Needs assessment → care plan (assessing RN) | **Closed with evidence: placed.** po 21:15 added ASM1-11 with `cra`'s four conditions as tests; po 22:15 rewrote it from CGR-81: assessed minutes with their period beside the category's items as written, **no total, sum or difference** (`briefs/ASM1.md` ASM1-11, acceptance (1)-(3)). The gain is smaller than proposed (the team still reads two lists side by side, no computed comparison), but it is the safe form: a per-occurrence sum with free-text frequencies would show a false gap (H-24) | done (simplify): one screen instead of opening the assessment document beside the care plan. A computed comparison only by a later brief with `cra` review, once every item carries a structured frequency and the period set is known (PO note 22:15) | L | stage 0; met at brief level | share of ASM1 records superseded within 7 days, per team (unchanged) | closed | – |
| AUT-10 | Provider cut-over (D-38 T12 (i)) | **Closed at package level.** (b) adopted in `lca`'s wording (po 21:15, `decisions/D-38.md:52`): the cut-over follows the next due reassessment or order renewal inside an owner-set window; a due one is never postponed. (a) is in the adviser bundle in `lca` 20:48's wording; until answered C makes its own assessment (protective default, UNKNOWN) | done for (b). (a) waits for the Zurich legal adviser or the tariff partner; `aia` reopens it only on that answer | L | stage 0; adviser for (a); owner for the window | as review 2, once a cut-over capability is briefed | closed | – |
| AUT-11 | Rule adoption (D-38 T13) | **Closed at package level.** T13 form adopted (po 21:15) with (a)-(d), no preset marks; `cra` CGR-83 added (e)-(f) | done: one signed act per catalogue version instead of one per rule, same per-rule decision and right to refuse | L | stage 0; adviser for the preset question | adoption acts per catalogue version per partner | closed | – |
| AUT-12 | Statutory administration per team-owned provider | **Placed:** hypothesis P-24 (`NEXT_CAPABILITY.md` challenge table) and an adviser question; `lca` 20:48 sees no objection to a service company acting as processor and agent of each C, licence-bound roles kept per C; one Leitung Pflege for several C UNKNOWN | unchanged; `aia` follows it as P-24, nothing to build | L | not an AI question; `csa`, `lca`, owner | as review 2 | closed (placed) | – |
| **AUT-13** | **Needs assessment: transcription into ASM1 (assessing RN)** | ASM1-1 (as amended 22:15, #578) has the RN copy, per assessment, the date, instrument and version, document reference and, **per KLV category A, B, C, the minutes and their period** from the provider's assessment tool into NAVORA by hand. That is a second entry of values already held in the tool. The period field adds patient-care benefit (CGR-81: no false gap, H-24), so the field is **not challenged**; the double entry is the bottleneck. How the provider's tool exports these values: UNKNOWN (no export format read; D-36 option A allows interRAI by name only). Effort per assessment: UNKNOWN; at a reassessment cycle of the order of months per client (the cycle is `clinical`, UNKNOWN), the volume is small per team but the risk of a copy error is per value | **eliminate later through the care graph (import), not now:** when a provider tool's export of these header values (date, instrument, assessor, minutes, period; **no item, score or CAP**, D-36 A) is known, a deterministic import fills an ASM1 draft that the assessing RN confirms value by value (assessment fields are never `schedule`, AIG1-5). Until then ASM1 stays manual as briefed. First step, no build: `eng` notes in the ASM1 PR whether the seed's period and minutes fields map one-to-one to a tool export, and `lca` names the processor and licence question for such an import (D-36) | L (copy of header values, no clinical content) | stage 0 (deterministic import, synthetic data); `lca` (D-36 licence, processor), `cra` (the import shows nothing the tool did not say), PO for a later brief | per team: share of ASM1 records superseded or corrected within 7 days (copy errors); after an import exists, values confirmed unchanged from the import | low | – |

**Briefs and packages reviewed without a new finding:**
- **ASM1-1 period storage (CGR-84, #578):** free text or the organisation's own list, no hard-coded list. It adds no step beyond the period the 22:15 amendment already required, and avoids an invented rule (KLV Art. 8, UNKNOWN). No leaner form at equal safety.
- **UX1-25 to UX1-29, UX1-18:** accessibility and the CGR-32 notice. UX1-28 keeps a nurse from being recorded absent without knowing it, and keeps the "visits before today need your team" notice in sight: a continuity control with no added step for her (one fewer state to check afterwards). UX1-27 keeps interruption follow-ups above the next visit. None adds administration.
- **D-38 T12 (i) (a)-(b) (CGR-82, `lca` 23:41):** a successor provider counts only after written acceptance and the client's recorded choice. This adds a written step, but its patient-care benefit is shown (no client without a visiting provider); no leaner form at equal safety. **T13 (e)-(f) (CGR-83):** safety withdrawal for all providers at once; no added step for the team.
- **PO 01:10 freeze of D-38:** agrees with the challenge duty; further term churn without new evidence would be administration.

### 2 AI readiness of delivered items
- No item that proposes, drafts or ranks was delivered since review 2 (#554, #558 are presentation; #574 is a contrast job and a layout test).
- WORK1 stays outside the register (AUT-9, low, unchanged).
- **New control for a future agent (AI Operating Model Review §12):** A10 (care-plan review proposer) must not compute a sum, difference or per-period conversion of assessed and planned minutes until a brief with `cra` review allows it (CGR-81). Recorded so the agent catalogue does not reintroduce what ASM1-11 forbids.

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 built | PLANNED: *Next up* after UX1 (in progress: (d), (g), UX1-18 open) and ADM2; unchanged |
| 0 | ASM1 built (assessment records as graph input for A10) | PLANNED; approved, not started; CGR-81 remedy and CGR-84 in the brief |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Waiting for the PO
- Nothing new from `aia`: no `high` finding, no issue opened. AUT-13 (low) stays in this report until an ASM1 PR or a D-36 answer makes it actionable.
- Bottleneck map refresh: due 2026-11-03 (weekly).

---

## 2026-10-27 20:30 CET · aia review 2: AUT-1 closed, `cra` answers placed, D-38 cut-over reviewed

**Read:** `recovery/main` at `0b6a24f`:
- the briefs AIG1 and PLAN3 as amended (po 15:20 and 18:10), UX1 part (g);
- `cra` 17:35, which covers CGR-78 and the answers on AUT-2, AUT-4 and AUT-7 (`CLINICAL_GOVERNANCE.md`);
- D-38 as on the branch of open PR #562 (po 20:15): T1-T14, `lca` 15:48, 18:05 and 19:50, and the Engineering section drafted by po;
- the challenge table rows for P-19, P-20, P-22 and P-23;
- the JOURNAL from 14:45 to 19:51.

**Changed since review 1:**
- the AUT-1 answer (#546, #557, #543 closed);
- D-38 drafted to T1-T14 and escalated to the owner (#562, open);
- UX1-25 and UX1-26 added;
- no item delivered.

**Not re-done:** the bottleneck map v1 (14:48) stands. Its weekly refresh is due 2026-11-03. **Nothing below is a measurement.**

### 1 Findings: changes and new

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-1 | Planning: the team confirms the PLAN3 day proposal | **Closed with evidence.** AIG1-5 was amended 15:20 and 18:10 to a per-field class `schedule`/`record`. Bulk confirm applies only to `schedule` fields of level-L `rule` agents, as an unticked list with no "select all". `cra` 17:35 (CGR-78) confirmed `responsible_user_id` as `schedule`. PLAN3-5, -7 and -9 were amended; PLAN3-7 adds "confirm actions per day plan" and "median minutes from proposal to confirmed plan". #543 closed by po 18:10 | done: one action per day plan instead of one per visit, at equal safety (J3 re-checks every line) | L | stage 0; met | PLAN3-7 (as adopted) | closed | #543 |
| AUT-2 | Needs assessment → care plan (assessing RN) | **`cra` answered (17:35): not clinical content as a display of two recorded numbers,** on four conditions: (1) no colour, warning, "Abweichung" or icon derived from the difference; (2) the assessment's date and assessor shown with it; (3) a newer significant event shown as such (H-22); (4) nothing blocked or changed by the difference. Billability of planned minutes above assessed minutes is `legal` with D-18, UNKNOWN | **simplify (unchanged), now unblocked:** the PO may place the display into ASM1 (for example as ASM1-9) with `cra`'s four conditions as its acceptance criteria. Estimated gain: one fewer transcription source per assessment; minutes UNKNOWN | L | stage 0; PO places; D-18 for billing | share of ASM1 records superseded within 7 days, per team | medium | – |
| AUT-3 | All steps: measuring administrative time | Placed by po 15:20 as hypothesis **P-19**, a brief after AIG1 | unchanged | L | stage 0; `lca` | P-19 | medium (placed) | – |
| AUT-7 | Visit status taps (nurse) | **Closed: not worth building now.** `cra` 17:35: an inferred time must be labelled as inferred and confirmed by the nurse before it reaches the report or a billable fact. AIG1-3 says signing a report does not confirm a proposed value, and AIG1-5 classes any visit time field `record`, so it is confirmed one by one. Removing the `departed` and `paused`/`resumed` taps would add the same number of confirm taps. Net gain about zero (estimate) | **keep the five events as built.** Reopen only if AN1 `time_correction_share` or a pilot tally shows the taps cost time | – | – | AN1 `time_correction_share` | closed | – |
| AUT-8 | Working time (nurse) | Placed by po 15:20 as hypothesis **P-20**; `lca` first | unchanged | L | stage 0; `lca`, D-23 | P-20 | medium (placed) | – |
| AUT-4 | Documentation per visit; countersignature | `cra` 17:35: replacing the blanket countersignature falls under the safety-control guard (CGR-76) and D-10. It needs equal or better protection against H-04 and H-05, decided by the Clinical Owner. This challenges the step's form, never its existence | unchanged. Before D-10 B can be argued, F6R-9 (return share and latency) must have pilot data | L / G | D-10 `clinical`, G-1 | F6R-9 | medium | – |
| **AUT-10** | **Provider cut-over (D-38 T12 (i)): the team's RN, every client of the team** | T12 (i) sets each client's cut-over only after C's own *Bedarfsmeldung*, C's own needs assessment and, for treatment care, an order valid for C. At the sunset this falls on **every client of the team in one window**, in addition to the T12 (ii) close-out, the T3 consent conversation and the T5 information. Per `lca` 19:50 [B2] (BAG explanation, not the ordinance text), the KLV ties an order to the treating physician and **does not tie a needs assessment to a provider**. In a team transfer the assessing RN is usually the same person, now employed by C. So a new assessment may duplicate a valid one: administration created by the change of employer, not by a change in the client. **Patient-care benefit is shown for the continuity part (no day without a provider; CGR-79), so this challenges the form, not the term.** | **simplify** (equal safety, T12 (i) unchanged in effect): (a) add to the adviser bundle: "may C file its *Bedarfsmeldung* on a valid needs assessment made by the same RN while employed by the partner, or must a new one be made?"; (b) T12 (i) already says "where practical the cut-over follows an order renewal". Widen it to "follows the client's next due reassessment or order renewal inside a cut-over window", so no assessment or renewal is made only because of the transfer. The window's length is the owner's (T4, the D-12 sunset), UNKNOWN. Estimated gain: up to one needs-assessment visit plus one order request per client of the team, once per transfer; minutes UNKNOWN | L (a planning rule; no clinical content; T12 (ii) checks stay) | stage 0; `lca` and Zurich legal adviser for (a); `cra` (does the widened timing keep CGR-79?); owner for the window | per team at cut-over: assessments and order requests made only because of the cut-over, counted from ASM1 and ORD0 records when a cut-over capability is briefed | medium | comment on #539 |
| **AUT-11** | **Rule adoption by the partner's Leitung Pflege (D-38 T13)** | T13: the partner's Leitung Pflege adopts or suspends the NAVORA Clinical Owner's rules one by one, with name and date. The catalogue is empty today (D-16, D-17, D-19, D-28 all `clinical`, G-1 not named). Once filled, each catalogue version means one decision per rule, per partner, and again per C. This is a legal accountability step (`lca` 18:05, R-11): its existence is not challenged | **simplify the form:** one signed adoption act per catalogue version, which lists every rule by name and lets the Leitung Pflege mark single rules as not adopted, with name and date. This is the same per-rule record and the same right to refuse, with one act instead of N. Product design waits for a brief that builds rule adoption (none is approved) | L | stage 0; `lca` (is a listed act equivalent for the licence holder's duty?), `cra` | adoption acts per catalogue version per partner | low | comment on #539 |
| **AUT-12** | **Team-owned provider C: statutory administration per small team** | D-38 T6 (own tariff contract), T7 (municipal financing), T14 (cantonal *Leistungsauftrag*, training-place duty under the ALV) and D-12 C conditions: each team of about four to eight nurses carries the full set of provider duties itself. `lca` 19:50 calls the ALV burden for such a team UNKNOWN. P-23 (po 20:15) covers training only. Evidence for the size of this burden: none read; UNKNOWN | **replace (operating model):** test, with `csa` and `lca`, whether a shared regulated service for several team-owned providers can carry contract, mandate, training, quality reporting and billing submission. Each team would keep its own care decisions and economics; the service would be a cooperative or network entity, not a management layer. Without it, administration removed from the nurse by NAVORA returns to the team as a provider's paperwork. The owner decides through a PO package; `aia` only names the bottleneck | L | not an AI question; `csa` (fit, STR), `lca` (whether several licences can share one service), owner | statutory admin items per C (count from the T6, T7, T14 lists); later the hours per team per month (pilot) | medium | – |

**Briefs and packages reviewed without a new finding:**
- **UX1-25, UX1-26:** focus and Escape handling for the absence overlay and the menu. Accessibility only, no added step; they protect the ABS1 path.
- **D-38 T1-T4, T12 (ii), T14:** each adds protection or preparation that a patient or legal duty requires (CGR-79, `lca`); there is no leaner form at equal safety.
- **P-22, P-23:** P-23 is the training part of AUT-12.
- **AIG1 and PLAN3 as amended:** consistent with §8 of the AI Operating Model Review (updated in this run).

### 2 AI readiness of delivered items
- No item that proposes, drafts or ranks was delivered since review 1.
- WORK1 stays outside the register (AUT-9, low, unchanged).

### 3 Stage tracking (D-35 stages; changes only)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1-5 scope settled before build | **met** (AUT-1 closed; CGR-78 in the brief) |
| 0 | AIG1 built | PLANNED: *Next up* 3, after UX1 (in progress) and ADM2 |
| 0 | PLAN3 built | PLANNED: *Next up* 6; waits for AIG1 |
| 1-3 | unchanged from review 1 | OPEN |

### 4 Waiting for the PO
- **AUT-2:** place the display into ASM1 with `cra`'s four conditions.
- **AUT-10, AUT-11:** consider them with D-38 (comment on #539). AUT-10 (a) belongs in the adviser bundle. Neither changes the owner ask "approve T1-T14".
- **AUT-12:** decide whether it becomes a `csa`/`lca` question or a package.
- No `high` finding in this run; no issue opened.

---

## 2026-10-27 14:48 CET · aia review 1: first bottleneck map, review of AIG1, ASM1, PLAN3

**Read:** `recovery/main` at `649b051`:
- the governance files, JOURNAL to `csa` 13:55 and `lca` 13:52, the mandate;
- the AI Operating Model Review, the Strategic Alignment Review §3-§4, the challenge table in `NEXT_CAPABILITY.md`;
- briefs AIG1, ASM1, PLAN3 (approved 13:35), WORK1, REF2, ORD1;
- migrations 0007, 0014, 0016, 0027, 0079;
- open PRs #532, #533, #535 and issue #536.

**Format:** this section follows PR #533 (po 13:50, open), which asks for a verdict and an estimated direct-care time gain per bottleneck. **Nothing below is a measurement.**
- **Code and events** show which steps a person must take, and how often.
- **Minutes per step** are UNKNOWN until a team-level measure exists (AUT-3).
- **The rank** is an `aia` estimate (ordinal).
- **Published sources** are cited only where I read them, with the date I read them.

### 1 Bottleneck map (first version; refreshed weekly)

**Published evidence read on 2026-10-27:**
- **[E1]** Himolde repository record of a 2018 prospective study: home care staff in three rural Norwegian municipalities logged activities for 8 weeks in 2016 (<https://himolde.brage.unit.no/himolde-xmlui/handle/11250/3085213>; read through its abstract page only).
  - Direct care was "less than 50 %" of total work.
  - Driving was 43-54 % of indirect time.
  - Reporting and documentation were 38-50 % of indirect time.
  - Swiss transferability: UNKNOWN.
- **[E2]** Blay et al., *J Adv Nurs* 81(7), 2025, a community-nursing time-and-motion study (<https://ro.ecu.edu.au/ecuworks2022-2026/5441>; abstract page only). It names documentation and travel as the inefficient practices. No per-category share is given on the page.
- Buurtzorg benchmarks: as cited by `csa` in `STRATEGY.md` §7 (not re-read).

**Rank** is the estimated direct-care time recoverable at team level, 1 = largest (estimate).

| Rank | Step (role) | What NAVORA asks of a person today | Status | Verdict | Gate | Finding |
|---|---|---|---|---|---|---|
| 1 | Visit: travel and day order (nurse) | She orders her day and route herself; AN1 measures travel minutes from `departed`→`started` (0007, 0027) | IMPLEMENTED (measure); OPEN (proposal) | automate (day-order rule agent) + replace (team geography) | Q7, `lca`; `csa` | AUT-5 |
| 2 | Documentation (nurse; RN countersigner) | She signs one report per visit at completion (F7). An RN countersigns every care-assistant report (`countersign_required`, 0016). The summary is optional free text (`report-section.tsx`:351) | IMPLEMENTED | simplify; replace countersign with risk-based review; AI-support (A7, stage 2) | D-10 (`clinical`), G-1, D-35 stage 2 | AUT-4 |
| 3 | Coordination with GP, hospital, relatives (primary nurse) | Order renewal by phone or fax; ORD0 records "Hausärztin informiert" as a task (0061). Referrals re-typed at intake (J1). Relatives' calls: not recorded | IMPLEMENTED (task); PLANNED (ORD1, REF2 drafts) | eliminate (structured order, referral, external actors as graph nodes); AI-support later (A2 stage 1, A8 stage 3) | D-22, D-9, D-3 (`owner`) | AUT-6 |
| 4 | Planning: who takes which visit (team) | A member sets `responsible_user_id` visit by visit (J3, 0014); PLAN2 already generates the visits | IMPLEMENTED (manual); PLANNED (PLAN3) | automate (PLAN3 rule agent) | AIG1, PLAN3 | AUT-1 |
| 5 | Needs assessment to care plan (assessing RN) | Today a flag (`is_needs_assessment`, 0014). After ASM1: minutes per category typed from the provider's tool, then per service again on the care plan (`care_plan_items.planned_minutes`, 0014:77) | IMPLEMENTED (flag); PLANNED (ASM1) | simplify now; eliminate with an import (D-37 B) | `cra`; `owner` D-37, D-36 | AUT-2 |
| 6 | Working time (nurse) | She confirms each working day and answers two questions before she can confirm (WORK1-2; 0079) | IMPLEMENTED | simplify (form of confirmation; the duty stays) | `lca`, D-23 | AUT-8 |
| 7 | Visit status (nurse) | Five event types per visit: `departed`, `started`, `paused`, `resumed`, `completed` (0007) | IMPLEMENTED | simplify (infer travel and pause) | none (product) | AUT-7 |
| 8 | Billing preparation (back office) | Nothing: J5 derives billable facts continuously from signed reports. The invoice itself is not built | IMPLEMENTED (facts); PLANNED (BILL2) | eliminated as preparation; automate invoice later | D-12, D-18 | – |
| 9 | Referral → case → matching → team decision | J1 readiness, J2 team pull to all eligible teams at once; no dispatcher | IMPLEMENTED | eliminated (sequential offers); re-typing → rank 3 | – | – |
| 10 | Quality and analytics (team, coach) | QG1 signals and AN1, AN2 measures come from events; no hand tally. Hold lift by coach or admin is still a management step (D-16) | IMPLEMENTED | eliminated (compilation); the hold-lift form waits for `clinical` | D-16 | – (existing challenge row) |
| 11 | Team self-organisation | Absence: one command (ABS1). Offboarding: LEAVE1. Cover: COVER1 accepted, switched off (D-3). Onboarding: ADM2 approved (team admits by consent; employer records "Vertrag erfasst" once) | IMPLEMENTED; PLANNED (ADM2); OPEN (D-3) | eliminated (phone chain, dispatcher); replace (central admission → ADM2) | D-3, D-20 | – |

**What the map cannot show yet** (UNKNOWN):
- minutes per step;
- the share of a working day spent on any one of them;
- how many phone calls with GPs, hospitals and relatives a team has.

AUT-3 proposes how to measure these from existing events, without new taps.

### 2 Findings

| AUT | Workflow step and role | Today's effort and evidence | Proposal (verdict) and estimated gain | Device level | AI stage and gate | Measure (team level) | Severity | Issue |
|---|---|---|---|---|---|---|---|---|
| AUT-1 | Planning: the team confirms PLAN3's day proposal (AIG1-5 × PLAN3-5) | **Challenge.** AIG1-5's default refuses every bulk confirm of more than one value until the Clinical Owner's list exists. So PLAN3-5's "ticked list" is refused, and the day plan becomes one confirmation per open visit, every team, every day. N = open visits per team-day, UNKNOWN for the pilot. `csa` 13:55 says the opposite ("whole proposal at once"). **No patient-care benefit shown:** D-17 part 3 lists safety-alert categories. §8 scopes "no accept-all" to safety-alert, care-plan and medical-order fields. `responsible_user_id` is a schedule fact, and J3 and PLAN3-2 re-check qualification, absence, membership and overlap per line at confirm time | **simplify:** the one-by-one default stays for level G and H, and for fields writing to safety alerts, the care plan, a medical order or an assessment. Level-L `rule` agents on schedule facts may be confirmed as an explicit ticked list, one ledger confirmation per line. Gain: about one action per open visit per team-day, minus one; minutes UNKNOWN (estimate) | L | stage 0; PO (product), `cra` on the field class only | confirmations per day plan; share confirmed unchanged (AIG1-7); minutes from proposal to confirmed plan | high | #543 |
| AUT-2 | Needs assessment → care plan (assessing RN, team) | ASM1-1 and ASM1-4: minutes per category A, B, C are typed from the provider's tool (the brief itself names this a transcription hazard, D-13 point 3). The care plan then holds minutes per service again (`care_plan_items.planned_minutes`, 0014:77), with no link between the two (ASM1-8 leaves it to the ADR). ASM1-5 (confirmation by the named RN) has a billing-integrity and safety reason: no challenge | **simplify now:** the care plan shows, per category, the current assessment's minutes beside the sum of its planned minutes. This displays two recorded numbers: no rule, no threshold, no signal. What a difference means is UNKNOWN (`cra`, Clinical Owner). **Eliminate later:** import of the reported minutes (D-37 B). Gain: one fewer transcription source; minutes UNKNOWN (estimate) | L (display); import: per D-37 | stage 0; `cra` (whether the display is clinical content); `owner` D-37, D-36 for the import | share of ASM1 records superseded within 7 days of entry, per team (transcription corrections) | medium | – |
| AUT-3 | All steps: measuring the administrative burden itself | The owner's success measure 2 (less administration) has no team-level measure per step. AN1's `direct_care_share` is an upper bound by its own comment (0027:9-11). WORK1 groups non-visit work into one self-reported kind, `administration` (0079:90). Report effort is not captured, only the latency `report_final_minutes` (0027) | **monitor:** derive per-step time from timestamps NAVORA already stores. Report draft created → signed (F6, F7); countersign latency (F6R-9); intake span (partner request → case ready, J1); ORD0 task age; AIG1 proposal → confirm. Per team and month, small-team suppression; no new tap, no per-person read. Gain: none by itself; makes every other gain provable | L | stage 0; `lca` (staff timing aggregated per team; must not read the WORK1 tables beyond WORK1-6, D-23 term (b)) | the measures themselves, in AN1/AN2 | medium | – |
| AUT-4 | Documentation per visit (nurse; RN countersigner) | One report per visit, signed at completion (F7). For care-assistant visits an RN countersigns each report (0016:39, :267), the "doubtful" row in the challenge table. Published: documentation is a large part of indirect time [E1], [E2] | **replace** the blanket countersign with risk-based review after the pilot (D-10 A vs B, `clinical`, on F6R-9 evidence: existing). **Simplify:** proof of delivery from facts, not prose (P-2). **AI-support:** A7, the nurse's own dictation (stage 2, G). Gain: largest per-visit lever after travel (estimate); UNKNOWN | L (P-2); G (A7) | D-10 `clinical` (G-1); stage 2 entry conditions (§4) | `report_final_minutes`; report draft→sign span (AUT-3); F6R-9 return share | medium | – |
| AUT-5 | Day order and travel (nurse) | No proposal; PLAN3 excludes it (*Out of scope*, Q7). AN1 already measures travel minutes. Published: driving was 43-54 % of indirect time in [E1] | **automate:** a day-order rule agent (visit windows plus travel time) registered in AIG1, after Q7. **Replace:** team geography. Small neighbourhood teams keep travel short by design; matching (J2) and the D-11 choice of municipality decide it. Gain: likely the largest single block (estimate, [E1]); UNKNOWN for NAVORA | L | stage 0 for the rule; Q7 (location data, `lca`); `csa` for team geography | AN1 travel share per team, before and after | medium | – |
| AUT-6 | GP orders, hospital referrals, relatives (primary nurse) | Order renewal by phone or fax; ORD0 only records the task (0061). Referrals re-typed at J1 intake. ORD1 and REF2 are drafts, blocked by owner decisions D-22, D-9, D-3. Relatives' calls: no data | **eliminate:** the structured order, the referral and external actors as graph nodes (P-9) before any agent. AI-support only at the edges later: A2 renewal letter (stage 1, held by `lca` condition 1 per `lca` 13:52), A8 extraction (stage 3, H). Gain: large, UNKNOWN; the whole step waits on owner decisions, not on build | L (structured); H (A8) | D-22, D-9, D-3 (`owner`), then stage 1 | ORD0 open-task age per team; intake span (AUT-3); a two-week tally of relatives' calls (existing challenge row) | medium | – |
| AUT-7 | Visit status taps (nurse) | Five event types, up to six taps per visit (0007) | **simplify:** infer travel and pause, keep start and end (existing hypothesis), tested with AN1 `time_correction_share`. Gain: small per visit, every visit (estimate) | L | stage 0; none | `time_correction_share`; taps per completed visit | low | – |
| AUT-8 | Working time (nurse) | One confirmation per working day, with two mandatory questions (breaks; work outside visits) before confirming (WORK1-2, 0079). The legal duty is not administration to remove; this challenges its form only | **simplify:** ask `lca` whether the nurse may confirm several proposed days in one action. Each day would stay its own append-only version, and the two questions would be answered only for a day that differs from its proposal. Gain: about four fewer confirmations per nurse-week (estimate) | L | stage 0; `lca`, D-23 | share of days confirmed unchanged from the proposal, per team (`from_proposal` is stored per segment, 0079:459) | medium | – |
| AUT-9 | AI readiness: WORK1 (a delivered rule proposer) | WORK1 proposes values that a named person confirms. Per-segment provenance exists (`from_proposal`, 0079:459, 476, 490). It has no correction-rate read, no stop rule and no register entry, because it predates AIG1 | **monitor:** once AIG1 is accepted, the PO decides whether WORK1 becomes agent `work1_day_proposal` (`rule`, L) or is recorded as exempt with the reason. Any team-level correction share needs `lca` first, because D-23 term (b) keeps the working day private | L | stage 0; PO; `lca` | – | low | – |

**Briefs reviewed without a new finding:**
- **AIG1:** apart from AUT-1, the controls match §8.
- **ASM1-5:** the confirmation step is justified.
- **PLAN3:** apart from AUT-1, the continuity order is a readable rule (PLAN3-3), with a team-level before-and-after measure (PLAN3-7).
- **ADM2:** removes a hierarchy step.
- **UX1, UX2:** the design shell; no workflow step added.

**No finding closed:** this is the first `aia` review.

### 3 Stage tracking (D-35 stages)

| Stage | Entry condition | State |
|---|---|---|
| 0 | AIG1 approved (*Next up* 3), hand-off #536 | PLANNED, not built |
| 0 | PLAN3 approved (*Next up* 6) | PLANNED; waits for AIG1 |
| 0 | A1 referral completeness as a rule | PLANNED inside REF2 (draft; D-9, D-3) |
| 0 | A6 control health (P-8) | OPEN; waits for a hosted environment (D-2) |
| 0 | A4 invoice draft as a rule (BILL2) | not written; waits for D-12, D-18 |
| 1 | 3 stable pilot months | not started (no pilot partner yet) |
| 1 | `owner` package: provider, region, contract | not written |
| 1 | `lca` conditions 1-10; DPIA; partner's sub-processor approval | OPEN. Per `lca` 13:52, condition 1 holds the order-renewal and insurer letters (A2, A4) until adviser question 1 is answered |
| 2 | regulatory adviser on level G; the Clinical Owner's no-accept-all list; stage-1 correction rates | OPEN (G-1 not named) |
| 3 | D-34 C module, D-37, the licence (D-36), the Clinical Owner | OPEN |

**Next stage reachable without an owner decision:** stage 0 only. Its main missing pieces are building AIG1 and settling AUT-1 before Engineering builds the AIG1-5 test.

**Waiting for the PO:**
- answer AUT-1 (#543) in the AIG1 and PLAN3 evidence tables, before Engineering builds AIG1-5;
- place AUT-2, AUT-3 and AUT-8 (medium) when convenient;
- AUT-6 needs no new package: it adds weight to D-22, D-9 and D-3 when they are bundled for the owner.

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
