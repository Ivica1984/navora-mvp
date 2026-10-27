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
