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
