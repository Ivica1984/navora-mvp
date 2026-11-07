---
id: NH-A1
title: Ward and 24-hour shift model on the shared team records (simulated nursing-home ward)
author: po
status: approved
updated: 2026-11-07
---

# NH-A1 — Ward and 24-hour shift model on the shared team records

**Approved 2026-11-07 13:39 CET (scheduled PO run), for synthetic data in a simulation organisation only (Phase A, FE-021, FE-031).** Blueprint M9.0a, first of five nursing-home briefs (NH-A1 to NH-A5, due 2026-11-27). Screen input: `uxa` proposal `docs/design/proposals/NH-A_WARD_SHIFT_SCREENS.md` (FE-043, #962), N-01, N-02 and §3. Clinical input: `cra` 13:25 (`CLINICAL_GOVERNANCE.md`, branch `gov/review-2026-11-07-1325`).

**Build gate:** Engineering starts only when (a) this brief has a `cra` gate line, (b) a `uxa` line on N-01/N-02 (the screen-catalog entries), and (c) an `lca` line on NH-A1-11 (shared devices) and NH-A1-12 (working time). The COORD-7 order holds: NH-A1 comes after the UX2 remainder. Every rule in this brief is PROVISIONAL. A passed Phase A simulation is no clinical release (CGR-142 (5), O-6).

## Problem
In a nursing home, the ward's day is planned by hierarchy:
- a head of unit or shift planner draws up the roster, often weeks ahead in a separate tool or on paper;
- the shift lead allocates residents to the nurses at the start of each shift;
- gaps (sickness, swaps) are closed by phone, by the same person.

This is the "station leadership" layer the care model wants to remove (`CARE_OPERATING_MODEL.md`; `ARCHITECTURE.md` "Nursing homes (later)": the same team model on wards replaces station leadership). NAVORA today knows teams, members, cases, visits, absences and cover (home care, IMPLEMENTED). It has no ward, no shift and no answer to "who is responsible for this resident in this shift". So the simulated ward that M9.0 needs (Blueprint §4 M9.0) cannot be run. Evidence: no `shift` or `ward` concept in `supabase/migrations` (grep, 2026-11-07). The `uxa` proposal (#962) marks the planning unit as the open choice.

## Users and journey step
- **Ward team members** (registered nurses, care assistants and other roles as the organisation records them): see their own shift and the residents they are responsible for. Phone or ward tablet.
- **The member who coordinates the ward team today** (self-organised; not a role NAVORA creates, FE-040 (4) role model UNKNOWN): sees uncovered residents and the roster.
- Journey step: **Planning** (Blueprint §1.3, nursing-home column). Referral and admission of a resident are NH-A2. Handover is NH-A3, absence and cover across shifts NH-A4, billing per resident-day NH-A5.

## Outcome
A ward team works a 24-hour day without a shift planner and without a morning allocation round. Each member enters her own shifts. Every resident has a named responsible member in every shift, set by a continuity default and changed by any member of the team. Anyone on the team sees within one screen which resident has nobody in the current or the next shift.

## PO decisions in this brief (product authority)
1. **N-01 inside `/field`** (one "Heute" place for visits and shifts), as `uxa` proposed (question 1). No separate ward tab.
2. **Planning unit: the resident, per shift (PROVISIONAL, `uxa` question 2).** Each resident has one named member *zuständig in dieser Schicht* for each shift of the day. The resident's care-plan items are shown on the resident's card (NH-A2), not planned as separate timed tasks. Why:
   - In residential care the shift, not the episode, is the time unit.
   - Per-episode start and stop, as on a home-care visit, would add a timing act to every care contact with no billing need: NH-A5 bills per resident-day, not per minute.
   - Continuity (one person per resident per shift, ideally the same over days) is value 2.

   `cra` 13:25: either unit works only if every resident has a named responsible member per shift, and the uncovered list counts residents (NH-A1-5). This brief meets that condition. Confirming the unit is a clinical as well as a product choice. It is **confirmed by the Clinical Owner before Phase B** (D-43, G-1); until then it holds for synthetic data only.
3. **"Zuständig in dieser Schicht" is team organisation, not professional authority or formal responsibility** (FE-039, Blueprint §1.4: the three are kept apart). It names the person the shift turns to for this resident. It does not say who may perform which activity: QUAL1 decides that per activity (NH-A2). It does not say who carries formal responsibility in the home: KON-2, `lca`/owner. The label and its help text say so (wording `uxa`, `cra` confirms).
4. **The roster is assembled from each member's own entries** (PO challenge 12:39): no planner role, no roster approval step.
5. The `uxa` acceptance criteria for N-01 and N-02 (proposal §2, §3) are taken into this brief (`uxa` question 3), as NH-A1-8 to NH-A1-10. `uxa` may add N-01 and N-02 to `NAVORA_SCREEN_CATALOG.md` as PROPOSED.

## Acceptance criteria
- [ ] **NH-A1-1 Ward.** A team can be marked as a ward (setting `ward`, organisation data), with a recorded ward name. A home-care team is unchanged: every existing pgTAP and e2e test passes unchanged. The ward setting is available only in an organisation marked as a simulation (QUAL1 pattern); a pgTAP shows that the command refuses for a non-simulation organisation.
- [ ] **NH-A1-2 Shift definitions are data.** A ward has its own list of shift definitions: name, start and end time; a shift may cross midnight. No shift name, time or count is written in code (grep in `src` and `supabase` for "Frühdienst", "Spätdienst", "Nachtdienst" outside seed and test files: none). The synthetic seed defines three shifts, chosen by `po` and marked synthetic. Changing a definition is a command (reason, audited, idempotent, ADR-003) and never changes past shifts: a pgTAP edits a definition and shows yesterday's shift unchanged.
- [ ] **NH-A1-3 Own shifts, self-entered.** A member enters, changes and withdraws her own planned shifts on the ward. Another member's shifts cannot be entered for her: refused, pgTAP. **Exception, recorded:** a member may enter a shift *for* a colleague only through the cover flow (NH-A4). The team's roster is the union of these entries. There is no approval step and no planner role (pgTAP: no command takes a roster as input).
- [ ] **NH-A1-4 Resident responsibility per shift.** For every resident (a case in the ward's setting, NH-A2) and every shift of the day, at most one member is *zuständig in dieser Schicht*. Any member of the ward team may set or change it, with an optional reason. Every change is audited with author and time. Negative cases (pgTAP):
  - a member of another team cannot set it (RLS);
  - a member who has no planned shift in that shift cannot be set;
  - a member whose access has ended cannot be set (LEAVE1).
- [ ] **NH-A1-5 Uncovered residents are derived, never entered.** A resident with nobody *zuständig* in the current or the next shift appears in "In dieser Schicht noch ohne Zuständige (n)" on N-02 and as a line on N-01. Rules:
  - The list counts **residents** (`cra` 13:25 condition).
  - It is derived from the schedule facts (NH-A1-3, NH-A1-4) like OPS1 `visit_uncovered`, with a new exception kind `resident_uncovered`.
  - Its **priority and any escalation step are UNKNOWN** (`cra`, Clinical Owner). Until `cra` sets them it is shown to the ward team and Operations with no P1/P2 level and starts no SIG1 delivery. pgTAP: `signal_kind_of` maps no signal kind to `resident_uncovered`.
  - The exception ends by itself when a member is set (pgTAP).
- [ ] **NH-A1-6 Continuity default (rule, no AI).** When a shift's responsibilities are first needed (at the latest when the shift becomes the *next* shift), each resident gets as default the member who was *zuständig* for that resident in the most recent shift of the same definition, if she has a planned shift in this one. Otherwise the field stays empty and NH-A1-5 shows the resident. The default:
  - is a proposal only. It is shown as "Vorschlag (wie letzte <Schichtname>)", and the team confirms it in one act per shift for all residents, or changes single residents;
  - never overwrites a value a person set;
  - is logged with the reason "Kontinuität".

  pgTAP covers four cases: the same member on shift (proposed), a different member on shift (empty), a person's value kept, and the confirm act. Measure for M9.0: share of resident-shifts confirmed without a change, per ward and month, never per person.
- [ ] **NH-A1-7 "Nicht überwacht" list (CGR-142 (1)).** Every reused control in the table below whose answer is "no" or "UNKNOWN" is listed under "Nicht überwacht auf dem Wohnbereich (n)" on N-01 and N-02. Its text comes from one constant that the table's test also reads. It is never styled as success, and never hidden because the count is high. Vitest: the constant has one entry per "no"/"UNKNOWN" row. Playwright: the count is shown and `data-tone` ≠ `ok`.
- [ ] **NH-A1-8 N-01 Meine Schicht (`/field`).** At 390 × 844 on the synthetic ward seed:
  - the shift line ("<Schichtname> · <von>–<bis> · <Wohnbereich>") is the first text after the h1 "Heute";
  - the banner "Simulation · synthetische Daten" is shown;
  - *Jetzt* holds her P1 signals, then the "Nicht überwacht" line;
  - *Als Nächstes* holds the residents she is *zuständig* for in this shift, one card each, ordered by room as recorded;
  - "Andere Schichten heute" is closed by default.

  A member who works visits and shifts on the same day sees both in one list ordered by time (Playwright with a member in a home-care team and a ward team).
- [ ] **NH-A1-9 N-02 Schichtplan Wohnbereich (`/team/schichten`).** "In dieser Schicht noch ohne Zuständige (n)" comes first in DOM order, each row with one action "Zuständige wählen". Then one row per shift of the day, with the planned members by display name and a **count only**:
  - no target, minimum, "unterbesetzt", "zu wenig", "Skill-Mix" or red tone anywhere (Playwright text and `data-tone` check);
  - a shift with nobody planned reads "Noch niemand geplant";
  - at ≥ 1024 px, a shifts × days grid (seven days) with `th scope` row and column headers, reachable by keyboard; an uncovered cell carries the text "ohne Zuständige", never colour only.
- [ ] **NH-A1-10 Picker.** "Zuständige wählen" lists only members with a planned shift in that shift, by display name. Any refusal text comes from the shared label functions (QUAL1-21 pattern; Vitest).
- [ ] **NH-A1-11 Shared devices (`lca`, `eng`, before M9.0b; `uxa` question 4).** Until `lca` answers, a personal sign-in per person, and no resident name on any idle, lock or sign-in screen (Playwright on the sign-in page and after session expiry). `lca` and `eng` answer whether shared ward devices are allowed in Phase A, and the sign-out timeout.
- [ ] **NH-A1-12 Working time across shifts (`lca`).** NAVORA checks no rest period or maximum working time across shifts, and shows no refusal or warning for one, until `lca` names the rule and its source. The N-02 help text says that rest periods are not checked. Shift entries feed `working_time` only as planned time, never as worked time (worked time stays the recorded facts, WORK1, D-23).
- [ ] **NH-A1-13 Synthetic only.** Every ward, shift and resident row in the seed is marked synthetic. The ward commands refuse outside a simulation organisation (NH-A1-1). No ward data reaches an AI service (D-35 rule A; pgTAP: no `ai` agent read on the new tables).
- [ ] **NH-A1-14 Security and audit.** RLS, column grants and the audit trigger on every new table; every write is an idempotent command with a reason where this brief says so, audited in the same transaction (ADR-003). Migrations only add. pgTAP per table: a member of another organisation reads nothing.

## Reused controls on the ward (CGR-142 (1))
| Reused control (home care, IMPLEMENTED) | Does its trigger exist on the ward in NH-A1? | Shown as |
|---|---|---|
| `visit_uncovered` (OPS1): a planned visit with nobody responsible | **no**: replaced by `resident_uncovered` (NH-A1-5); priority UNKNOWN | the uncovered list, no level |
| `visit_overdue`, `visit_stuck` (CSR1, 0038): a visit not started or not moving | **no**: ward care has no per-episode start (decision 2) | *Nicht überwacht* |
| `no_show` (C1, DOOR1): client does not open | **no**: does not apply to a resident | not listed (not a ward situation) |
| `visit_interrupted` (OPS1): a broken-off visit | **no** | *Nicht überwacht* |
| SIG1 delivery of P1 signals to the team | **yes**: signals reach the ward team as on `/field` | *Jetzt* |
| ABS1 absence releases planned work | **UNKNOWN** until NH-A4 (shift release) | *Nicht überwacht* until NH-A4 |
| HAND1 "Seit deinem letzten Einsatz" | **UNKNOWN** until NH-A3 (per shift) | *Nicht überwacht* until NH-A3 |
| QUAL1 check per activity at assignment and start | **UNKNOWN** until NH-A2 (activities on the resident's care plan); NH-A1 assigns no activity | *Nicht überwacht* until NH-A2 |
| J1 readiness before the first visit; D-17 safety alerts before first contact | **UNKNOWN** until NH-A2 (admission) | *Nicht überwacht* until NH-A2 |
| Medical-order validity for B care (J3, CR-046; CGR-156, CGR-157) | **UNKNOWN** (care in a home is not billed by KLV minute; NH-A5) | *Nicht überwacht* |

Each "no" or "UNKNOWN" is an open question for the Clinical Owner: does the ward need its own trigger, and which? None is filled by an invented ward rule.

## Not invented (CGR-142 (2))
| Topic | Status | Owner |
|---|---|---|
| Shift names, times and count | data; synthetic seed by `po` | organisation |
| Staffing per shift, minimum staffing, skill mix | UNKNOWN; shown as counts only | `cra`, Clinical Owner (D-43); `lca` for any legal minimum (canton) |
| Priority and escalation of an uncovered resident | UNKNOWN | `cra`, Clinical Owner |
| Who may be *zuständig* by profession (e.g. a care assistant in a night shift) | UNKNOWN; NH-A1 sets no profession rule | `cra` (QAM, FE-039), Clinical Owner |
| Rest periods and working time across shifts | UNKNOWN | `lca` |
| Care-need level, instrument | out of scope (NH-A5; D-36) | `cra`, `lca` |
| Formal responsibility in the home (KON-2) | out of scope | `lca`, owner (FE-040 (4)) |
| Shared ward devices | UNKNOWN | `lca`, `eng` |

## Rules and their input class
| Rule | Input class | Note |
|---|---|---|
| `resident_uncovered` (NH-A1-5) | visit/schedule fact | displays only; priority and escalation UNKNOWN, so it does not rank, route or escalate |
| Continuity default (NH-A1-6) | visit/schedule fact | proposes only; a person confirms |
| Only members with a planned shift can be *zuständig* (NH-A1-4, NH-A1-10) | visit/schedule fact | team organisation, no professional rule |

No rule of the class *clinical content*. No rule that ranks, routes or escalates on a *care-context fact recorded by a person*.

## AI leverage
1. **Remove:** the roster drawn up by a planner, the allocation round at shift start and the phone round for gaps. Each member enters her own shifts. Responsibility is defaulted by continuity. Gaps are visible to the whole team.
2. **Rules:** the continuity default and the uncovered derivation (deterministic, above).
3. **Monitor:** uncovered residents are derived continuously, for the current and the next shift, not checked at shift start.
4. **AI prepares:** **none in NH-A1.** A deterministic rule covers the proposal. D-35 rule A forbids sending ward data to an AI service, and O-4 (AI provider for synthetic data) is open. A later AI step (for example a proposal for a gap) needs its own brief under the PLAN4 pattern.
5. **Human reviews:** the team sees the proposal ("Vorschlag (wie letzte …)").
6. **Human decides:** any ward member confirms or changes it.
7. **Human signs:** none needed (no attesting act in NH-A1).

Administrative step removed: shift allocation and roster upkeep. The baseline is UNKNOWN for a real home; in Phase A the measures are the AN3 spans per ward and month, plus NH-A1-6's confirmed-without-change share. Gate: D-35 stage 0, synthetic only. The AI must never set a responsibility, compute a staffing level or judge a shift.

## Out of scope
- Resident record, admission and care plan (NH-A2).
- Shift handover (NH-A3); absence and cover of a shift (NH-A4); billing per resident-day (NH-A5).
- Any staffing target, skill-mix rule or rest-period check (see *Not invented*).
- Real organisations and real data (Phase B; D-1, D-42).
- A separate ward app or tab.

## Constraints and references
- Blueprint §1.3, §1.4, §4 M9.0a (CGR-142 conditions (1)-(5)), M9.0b (build due 2027-01-29).
- FE-021, FE-031, FE-036 (Phase A simulated ward), FE-039 (§1.4 terms), FE-040 (4) (role model), FE-043 (`uxa` proposal).
- `ARCHITECTURE.md` (shared team records; RLS, audit); ADR-003 (commands).
- Briefs reused: OPS1, CSR1, SIG1, ABS1, COVER1, HAND1, QUAL1, LEAVE1, WORK1.
- D-35 rule A; D-36 (no interRAI content); D-43 (Clinical Owner mandate); D-25 (nursing-home leadership licensing, `lca`).

## Open questions for engineering
1. Ward as a team setting, or a ward entity under a team? The PO's requirement is only that a home-care team is untouched and a member can belong to both (NH-A1-8). Record the choice in an ADR.
2. Shifts that cross midnight: which date does a night shift belong to on N-01 and N-02? Propose one rule in the ADR. It is a display and data rule, not a clinical one.
3. Estimate in person-days for NH-A1, and whether NH-A1 and NH-A4 share a migration (this belongs in the M1.3 condition: estimate v2 with the NH-A effort before 2026-11-17).
