# NAVORA Delivery Program M1-M10

**Owner of this plan:** Product Owner (`po`) · **Date:** 2026-11-03 (Europe/Zurich) · **Requested by:** the owner, *Executive Delivery Directive* (2026-11-03): "The AI-First Architecture update is accepted. The architecture phase is complete. The next step is execution planning." · **Status:** execution plan, version 1.

**How to read the dates:**
- Every date is a **PO target**, not an engineering commitment.
- Engineering's sequence and effort estimate (M1, due 2026-11-13) re-baselines them in version 2 of this plan.
- Dates after M3 hold only if the owner's decisions in M3 arrive by 2026-12-11. Every week of delay there moves M9 and M10 by the same week.

**Version 2 (2026-11-06):** the measurable execution system is [`ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md`](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md) (completion %, sub-milestones, critical path, quality gates, weekly dashboard). This file keeps the detailed objectives and v1 criteria; where the two differ, the blueprint holds (its §3.4).

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

## 0. Status 2026-11-03 15:30: UX/UI baseline adopted (PR #834)

**Decision (owner request, PO review):** PR #834 is reviewed and merged (`b1cffe9`; CI green on head `d811658`; docs only).

The baseline (status IMPLEMENTED as documents) for the **Website, Web App, Caregiver App and Operations App** is:
- [`NAVORA_INFORMATION_ARCHITECTURE.md`](../design/NAVORA_INFORMATION_ARCHITECTURE.md): surfaces, roles, website sitemap, tab sets, route map, deep links;
- [`NAVORA_SCREEN_CATALOG.md`](../design/NAVORA_SCREEN_CATALOG.md): 57 screens W-, A-, C-, O-, L-, F-;
- [`NAVORA_DESIGN_SYSTEM_V1.md`](../design/NAVORA_DESIGN_SYSTEM_V1.md): tokens, the `globals.css` block for UX2-3, 39 components, the marketing extension, the build order.

Every brief, ADR and PR for these surfaces builds on them. A deviation is stated in the PR and needs `uxa`'s design answer and the PO's acceptance. The family app (F-01 to F-06) is in the set as a **specification frame only**: D-40 stays frozen, and nothing in the set authorises a route, table or text for it.

**Review result: no blocking architectural, clinical, legal or product concern.** What I checked:
- the AI assistant (C-15) uses existing queries only, in the team's scope, writes to the AIG1 ledger, has no free clinical question and shows "Keine medizinische Beratung" (wording `cra`);
- PLAN3 (C-17) and capacity (O-07) show load per member only as PLAN3-4 allows, never judged or ranked;
- AN3 (O-05) has no person figure, no target and no colour scale;
- every unbuilt or frozen website feature is "in Vorbereitung", with no medical-device claim and no tracking cookie unless the owner decides;
- the website shares no session with the app;
- demo requests never enter the care database;
- clinical, legal and claim content that is missing is marked UNKNOWN with its owner, not invented.

**Non-blocking items, routed (no item changes a decided rule):**
- **`cra`:** DS1-2 (the `proposal` colour must not read as a severity); SC-2 (offline wording); SC-5 (assistant intent labels and the advice line).
- **`lca`:**
  - SC-2 (pending entries stored on the device);
  - SC-6 (demo response period and destination; privacy notice and imprint content);
  - DS1-6 (stock imagery);
  - **SC-8:** an address link on C-03 to an external maps service would send a client's address to a third party. It is OPEN in the catalog and **not built today** (checked in `src/`). PO decision: it is not built until `lca` answers.
- **`eng`:** DS1-1 (input border contrast), DS1-3 (body font) with UX2-3; D-IA-4 (website hosting) in the M1 estimate; SC-7 / D-IA-6 under UX2-5.
- **`po` decisions now (product authority):**
  - **D-IA-1** routes as drawn (`/field/assistent`, `/team/tagesplan`); a sheet may render on the same URL;
  - **D-IA-3** landing as built;
  - **D-IA-5** the app stays German only until M10;
  - **D-IA-7** no link from the app to the website until WEB1 decides it;
  - **SC-1** becomes **UX2-33** (error, not-found and no-access pages inside the shell; Playwright: an unknown route renders inside the shell);
  - **D-IA-2**, **SC-3** (O-07 capacity) and **SC-4** go into the OPS2 brief (due 2026-12-04);
  - **SC-5** into MOB1;
  - **DS1-4** (app icon and word mark) and **DS1-5** (dark mode after M8) stay open, not on any critical path.

**M1, UX/UI part: met** (issue #831, delivered under the owner's file names; the screen catalog replaces `SCREEN_INVENTORY.md`, the IA replaces `NAVIGATION_MAP.md`, the DS V1 component inventory replaces `COMPONENT_INVENTORY.md`). The M1 Engineering part (estimate, due 2026-11-13) is still open.

### Dependencies after the baseline: what M2-M8 are now unblocked for

| Milestone | Design dependency | Now unblocked | Still blocked by (owner, date) |
|---|---|---|---|
| **M2** web app | **met** | UX2-3 (tokens from DS V1 §2.6), UX2-4 (components, build order step 1), UX2-31/-32 (tab sets and labels, IA §4.2), UX2-33 (A-05) | `eng`: merge of the cleared UX2 PRs #799, #800, #803, #804, #806; CGR-110 (#399) |
| **M3** owner decisions | not applicable | – | owner, 2026-12-11 |
| **M4** PLAN3, AN3 | **met** (C-17, O-05, build order step 3) | PLAN3 and AN3 build, as soon as M2's shell is in | `eng`: AIG1-C4/-C5 first; M2 |
| **M5** website | **met for structure and design** (W-01 to W-11, IA §3, DS V1 §6) | page build on the marketing tokens and components | `po`: WEB1 content (2026-11-20); owner: domain, hosting, demo destination (M3); `lca`: privacy notice, imprint, claims (2027-01-08); `eng`: D-IA-4 (M1) |
| **M6** caregiver app | **met** (C-01 to C-16, A-06, A-07, DS V1 §3.4-3.5, build order step 5) | screens and components of the installable app | `po`: MOB1 (2026-11-27, incl. SC-5); `eng`: delivery form (M1); `cra`/`lca`: SC-2 offline storage and wording |
| **M7** family specification | **met as frame** (F-01 to F-06) | the PO's family specification can start now (no build) | `lca`/`cra`: D-40 inputs; owner: D-40 (build stays frozen) |
| **M8** operations app, AIO1, OPS2, HAND2 | **met** (O-01 to O-08, C-05, build order step 6) | operations screens on the shell | `po`: OPS2, HAND2, AIO1 briefs (2026-12-04, incl. D-IA-2, SC-3, SC-4); `lca`: O-07 capacity read |

**Effect on dates:** none moved. The design baseline arrived 17 days before its due date (2026-11-20), so `uxa`'s later dates (§6) now cover page-level content placement and visual review rather than first designs. The critical path is unchanged: the M3 owner decisions, then the Engineering estimate (M1).

---

## 0b. Status 2026-11-03 22:00: AUT-40 decided; `cra` findings placed

**PO decision on AUT-40 (`aia`, issue #843; `cra` 21:30: no clinical objection): no separate assistant screen at stage 0.** Status: PLANNED (nothing is built).
- **Why:** every one of the four C-15 intents reads only a reader that a screen the nurse already uses shows (C-01 "Heute", the HAND1 line on the visit card, COVER1 and the absence flow, the report section). Through C-15 each answer takes 3 taps instead of 0-1, and a second route to the same safety facts is one more place where they can be shown differently or stale (`cra`). The screen removes no step. Value order: (1) direct care time, (5) less administration; no loss in safety.
- **Decided:**
  1. **No C-15 `/field/assistent` and no intent list in M6.** D-IA-1 keeps `/team/tagesplan`; the `/field/assistent` route is withdrawn until (5).
  2. The answers stay where the question arises: C-01, the visit card, the absence flow.
  3. **"Was fehlt vor dem Unterschreiben?"** is not a new rule. If MOB1 builds a line next to "Unterschreiben", it lists only the conditions `sign_report` already refuses, each taken from that command's refusal codes (one shared constant), never adds one, and with nothing refused reads "Für die Unterschrift fehlt nichts." (never "vollständig", "komplett", "alles erfasst") (**CGR-120**). Any further item is a Clinical Rule Register row, owner `clinical`, PROVISIONAL, before build. Signing stays one confirmation (F7).
  4. **The AIG1 ledger records proposals only, never reads.** Whether assistant reads of client data would need an access log is `lca`'s question; it does not arise while no assistant reads exist.
  5. An assistant entry point comes back only with the first intent no existing screen can answer (dictation A7 or drafting A9; D-35 stage 2, D-34 module). Its brief states the removed step and the human-act count before and after (AUT-38).
- **For `uxa`:** mark C-15 in the screen catalog as deferred (stage 0) and place the CGR-120 line on the report section (C-01/C-03 placement). **For `eng`:** APP1 plan item M6-4 is dropped; its days go to M6-2 and M6-3.

**`cra` findings placed (CGR-113 to CGR-121; PR #842 and #845, read on their branches; advisory):**
- **CGR-117 (S1 by effect), M9:** wording changed below: no clinical gate is waived by the PO or by the owner alone.
- **CGR-118, CGR-121 (S2), M6-2 offline queue:** conditions of MOB1 and of any M6-2 build: the banner states that urgent matters go by phone now and that new safety signals arrive only once the connection is back; each pending entry that reaches another person shows "Noch nicht beim Team" until sent; sign-out with pending entries is a confirming step naming how many and which kinds are unsent, default "Zurück und senden", sign-out only by a second explicit act; the foreground-resend fact is stated; ADR-143 states what happens to pending entries on session expiry and access end, and no entry that reaches another person is discarded unseen. e2e offline (`context.setOffline`) for each. Whether care text may sit on the device at all stays `lca`'s (SC-2).
- **CGR-120 (S3), MOB1:** as decision 3 above.
- **CGR-119 (S2, regulatory):** a brief for an AI domain at level H (AI-First §5.2 domains 1, 2, 4, 7, 8, 9; D-39 C/D; D-40 D) carries the line "D-34 classification: <adviser's answer, date>" and is not approved while it reads UNKNOWN. Added to `briefs/_TEMPLATE.md`.
- **CGR-116 (S2), DOC2:** DOC2 stays not allowed. When it is written, the brief takes `cra`'s five conditions (signed statement per visit with an explicit, never preselected answer on the client's condition; events prove delivery only; visit types set by the Clinical Owner; observations and safety-alert changes as balancing measure; level G, not L).
- **CGR-113, CGR-114, CGR-115 (S3):** conditions for the reviews of ASM1-C6 (#815), AN3 (#841) and AIR1 (#828), recorded in `NEXT_CAPABILITY.md`. For CGR-115 the PO prefers the allow-list (a register field is accepted only for a column listed with a `cra` row); `eng` decides how.
- **AN3-5 wording aligned** to what `cra` confirmed is built: "share of visits with a time correction" (corrections have no open state).


## 0c. Status 2026-11-04 06:10: what may wait offline (CGR-122, CGR-123, AUT-41, UXR-92)

**PO decisions for ADR-143 (#837, proposed by `eng`, not merged) and any M6-2 build.** Status: PLANNED (nothing is built). Sources: `cra` 01:30 (PR #848) and 05:30 (PR #852), `aia` 02:20 (AUT-41, merged #849), `uxa` 03:50 (PR #850); open PRs read on their branches.
1. **CGR-122 (1) is in force: visit-timeline commands and `correct_visit_time` are never queued.** Offline the buttons stay visible and say why they do not work (point 5); a time typed on the device is shown only as a separately labelled claim ("Auf dem Gerät eingegeben") and never becomes a measured or billed minute. **Why:** a queued entry is recorded at the server time of sending, so a queued start or end would misstate the visit's time and the J5 measured and billed minutes. Patient safety and billing accuracy are preconditions, not traded for speed.
2. **CGR-123 is in force: nothing that raises a safety signal or releases a visit waits in a queue.** Also never queued: `record_no_show`, `record_no_show_outcome`, `end_visit_not_completed`, `record_absence`, `change_absence`. Criteria for M6-2: one shared list of non-queueable commands in code; a vitest fails when a command that raises a SIG1 signal or releases a visit is missing from it; one e2e per command with `context.setOffline` showing the refusal and the phone route (point 4). **Why:** a P1 signal or an uncovered visit that waits for the nurse's next online session is the exact delay SIG1 exists to remove.
3. **AUT-41 (`aia`) is the target design, not built yet.** With (1) a visit given entirely without a connection costs the nurse up to three time corrections typed from memory afterwards: administration that takes care time (value order 1 and 5). Target: offline visit times enter afterwards through the existing audited correction path with a preset reason (`uxa` wording proposed: "Ohne Verbindung erfasst (Gerätezeit)"), so she confirms instead of retyping. **Gate (`cra` 05:30):** the Clinical Owner, with `lca`, decides which time is the documented time of an offline visit, and correction rows are told apart by reason kind. Until then (1) holds. Whether the gate is worth pursuing is a pilot question (challenge-review row in `NEXT_CAPABILITY.md`).
4. **"Telefonisch melden" must name a number that works offline.** MOB1 states which number the banner and the refused commands of (2) show, held on the device so it shows without a connection (`cra` 01:30). Which number is the right one for urgent matters (the team's phone or a round-the-clock line) is the Clinical Owner's (UNKNOWN until G-1). MOB1 is not accepted for real clients while it reads UNKNOWN.
5. **UXR-92 (`uxa`, medium) placed in MOB1:** "visible but disabled" is `aria-disabled` with a described reason, never the `disabled` attribute (a screen reader must reach the button and hear why).
- **For `eng`:** ADR-143 takes (1), (2) and (5) before acceptance; CGR-122 and CGR-123 block the M6-2 merge until their tests are green. **For `uxa`:** the wording proposals of 03:50 stand; `cra` confirms them. **For `lca`:** the CGR-122 documentation question is asked together with the Clinical Owner's documented-time question (no package; a clinical rule).


## 0d. Status 2026-11-04 12:45: owner decisions D-39 and D-40

- **D-39 (owner): A.** No sensors, device data intake, IoT integrations, predictive monitoring or AI risk predictions in the pilot; specification-only. No milestone changes.
- **D-40 (owner): option A rejected; a minimal, read-only relative view is in the pilot.** Consented relatives see visit status, planned time and the assigned caregiver. Excluded: AI, messaging, direct communication with care teams, clinical information, assessments, documentation, recommendations. **M7 changes** (below): its decision part is done; its deliverable is now brief **FAM1** (draft 2026-11-04), approved once `lca` (consent; representation; staff display name) and `cra` (visibility, information boundaries, safety) have answered, then built on synthetic data. Real relatives only after the legal adviser's answer (with D-9) and D-1. Screens in scope: F-01 and F-02 of the design set; F-03 to F-06 stay frozen. New M7 date follows Engineering's FAM1 estimate (plan version 2, 2026-11-17).

## 0e. Status 2026-11-05 12:00: PO merges in force; first merges

- **Owner decision (2026-11-05):** the PO alone merges, autonomously, under the seven conditions of `docs/agents/PO_MERGE_PROCESS.md` §4, with post-merge duties in §9. Option C (Engineering merges) rejected.
- **Merged** (merge commits, CI green on each head, PO did not run the tests): **#799** UX2-1 + UX2-31, one shell for every protected route (`c8d2db7`); **#833** `IMPLEMENTATION_SEQUENCE.md` M2-M8 (`0e79e5f`); **#838** D-2 hosting decision support (`847bd4a`).
- **M2 (web app consolidated, 2026-11-27):** first of the four cleared UX2 parts is in; #800, #803, #804 now conflict with `recovery/main` and wait for Engineering to merge it in. Date holds; at risk only if the conflict round-trip stays one PR a day.
- **M1 (delivery baseline, 2026-11-13):** the implementation sequence is on `recovery/main`; #835 (`DELIVERY_ESTIMATE.md` v1) and #837 (WEB1/APP1 plans) conflict and wait for `eng`. Dates are not changed by the sequence until the PO adopts them.
- **New blocker / risk:** every Engineering PR edits `IMPLEMENTATION_STATUS.md`, `docs/engineering/DECISIONS.md` and `JOURNAL.md`, so each merge makes the rest conflict (AUT-49 adopted as direction). Role docs PRs (`cra` chain, `uxa` #850, `aia` #869, `lca` #860) conflict on `JOURNAL.md` too; FAM1 approval waits for the `lca` and `cra` inputs to reach `recovery/main`.
- **Deviation:** none from architecture or strategic direction.

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
- **Deliverables:** login, visits, documentation and handover as one installable app. **No separate AI assistant screen at stage 0** (AUT-40, §0b): its four answers stay on the start screen, the visit card, the absence flow and the report section.
- **Acceptance criteria:**
  - installable on iOS and Android, opening on `/field`;
  - at 390 px each listed function is reachable within two taps from the start screen (e2e);
  - a lost connection never loses an entered value: retry is idempotent, and every command has a key (existing pattern);
  - push opt-in works where the browser allows it (D-33);
  - each of the four former assistant answers (what is next, what changed, who can cover, what blocks signing) is reached from the start screen in ≤ 2 taps without an assistant route (e2e at 390 px);
  - no `ai_suggestions` row exists without a target field and a proposed value: reads never enter the ledger (pgTAP);
  - if a "before signing" line is built: every listed item maps to a `sign_report` refusal code, and the line contains no "vollständig", "komplett" or "alles erfasst" (vitest, CGR-120);
  - offline: CGR-118, CGR-121, CGR-122 and CGR-123 conditions met (e2e with `context.setOffline`, §0b and §0c); UXR-92 for every disabled control.

### M7 Family app specification and decision (Fri 2027-02-05)
- **Objective:** a complete, decision-ready specification of the family app. **No build:** D-40 is frozen. **Changed 2026-11-04 (owner D-40, §0d):** the decision is made; the objective is brief FAM1 approved and built on synthetic data (read-only relative view, F-01 and F-02 only); date to be re-set with the FAM1 estimate.
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
  - every gate that applies "before the first real client or employee" is **closed with evidence**, or waived in writing with the reason and the compensating control by the person who carries its accountability. **A clinical gate** (an S1 item in the Hazard Log, the Safety Risk Register or the Clinical Governance Report, a blocking CGR finding, a Clinical Rule Register row in use) **is waived only by the named Clinical Owner (and, for the partner's clients, the partner's Leitung Pflege, D-12) together with the owner**, never by the PO or the owner alone (`cra` CGR-117, D-27);
  - the readiness file lists every open S1 and S2 `CGR`, `H` and `PS` item with its status;
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
| 5 | **AI assistant** | **not built at stage 0** (AUT-40, §0b, 2026-11-03 22:00) | none in M6: the answers stay on C-01, the visit card, the absence flow and the report section; an entry point returns with the first intent no screen can answer (dictation A7 or drafting A9; D-35 stage 2, D-34 module) | not dated |

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
- DOC2 (not allowed yet; when written, its brief takes the five `cra` CGR-116 conditions, §0b).

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

**Delivered 2026-11-03 (PR #834), baseline from 15:30** under the file names `NAVORA_INFORMATION_ARCHITECTURE.md`, `NAVORA_SCREEN_CATALOG.md` and `NAVORA_DESIGN_SYSTEM_V1.md` (see §0). The original request, kept for reference, was due Fri 2026-11-20 (one week after M1, so it could use `eng`'s delivery form), implementation-ready, not wireframes only:
1. **Screen inventory** (`docs/design/SCREEN_INVENTORY.md`): every screen of the web app, caregiver app, operations app, family-app specification and website. Per screen: route, roles, the three questions (`DESIGN_SYSTEM.md` §1), data read, primary action, components, states, status (IMPLEMENTED or PLANNED).
2. **Navigation map** (`docs/design/NAVIGATION_MAP.md`): per role, tabs and sidebar (UX2-31, UX2-32), deep links, back paths, the website-to-app entry, and the family app as specification.
3. **Component inventory** (`docs/design/COMPONENT_INVENTORY.md`): every component with variants, states (default, hover, focus, active, disabled, loading, empty, error), accessibility notes and the screens that use it.
4. **Design system** (`docs/design/DESIGN_SYSTEM.md`, updated): tokens (colour incl. severity, type, spacing, radius, elevation, motion) as values the build consumes; dark mode if in scope; marketing extension for the website. Every token used by a component is named in the inventory.

**Then (dates unchanged; scope now content placement and visual review on the baseline):** website pages with WEB1 content (Fri 2026-12-04 and 2026-12-11), caregiver app screens with MOB1 (Fri 2026-12-11), operations app screens with OPS2 (Fri 2027-01-08), family-app screen specification within the frame F-01 to F-06 (Fri 2027-01-22).

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
- 2026-11-05 12:00 po: §0e added. PO merges in force (owner); #799, #833, #838 merged; M1/M2 progress and the conflict risk recorded.
- 2026-11-03 po: version 1, from the owner's Executive Delivery Directive.
- 2026-11-03 15:30 po: §0 added. The UX/UI baseline (PR #834) is adopted for website, web app, caregiver app and operations app; the M1 UX/UI part is met; the dependencies of M2-M8 are updated; no date moved.
- 2026-11-03 22:00 po: §0b added. AUT-40 decided (no C-15 assistant screen at stage 0; M6 deliverable, criteria and §3.1 row 5 changed); M9 waiver wording per CGR-117; CGR-113 to CGR-121 placed. No date moved.
- 2026-11-04 06:10 po: §0c added. CGR-122 (1) and CGR-123 in force for ADR-143 and M6-2; AUT-41 the target design behind a Clinical Owner gate; offline phone number and UXR-92 placed in MOB1; M6 offline criterion extended. No date moved.
- 2026-11-04 12:45 po: §0d added. Owner decisions D-39 (A) and D-40 (minimal read-only relative view in the pilot); M7 objective changed to FAM1; date follows the estimate.
