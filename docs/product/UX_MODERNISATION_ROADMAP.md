# NAVORA UX/UI modernisation roadmap

**Owner:** `po` (what and when) with the UX/UI Design Architect (`uxa`, how it should look and behave). **Approved direction:** owner 2026-10-27 ("approve the UX review findings, the roadmap adjustments and the prioritisation of UX1 and UX2"). **Created:** 2026-10-27 10:40 CET. Status per item: IMPLEMENTED, PLANNED (approved brief), OPEN (no brief yet).

## Why

NAVORA's business capabilities (signals, planning, documentation, quality, billing preparation, team autonomy) are much more mature than its user experience. The UX review of 2026-10-27 (#506-#510) showed two app shells, a menu that offers every role everything, internal codes in user text, broken phone layouts and a nurse screen where the next visit starts about 1,100 px down. A pilot team judges the product by its screens, not by its migrations. If nurses do not adopt `/field`, none of the care-model gains (direct care time, continuity, no dispatcher) reach a client.

**Target:** from a rules-focused interface to a workflow-guided one. Every screen answers *what needs attention now, what to do next, what can wait* ([design system](../design/DESIGN_SYSTEM.md) §1).

## Success criteria: pilot adoption and usability (first-class, owner 2026-10-27)

Measured at team level, never per person, on pilot data once real use starts; on synthetic data the measures are only built. Targets are PO hypotheses for the pilot to confirm or reject, not facts.

| Measure | How | Hypothesis (PO) | Status |
|---|---|---|---|
| Adoption: share of a team's visits started and completed in `/field` (not recorded afterwards) | F-events vs. planned visits (AN2) | ≥ 90 % by pilot week 4 | OPEN (AN2 measure to add) |
| Time from "arrived" to "visit started" | F-events, median per team (P-18) | falls after UX1 | OPEN (P-18) |
| Wrong taps: cancellations and billing holds undone within one hour | events; readability today UNKNOWN (P-18) | falls after UX1 | OPEN |
| Push opt-in for safety signals among active members | SIG2 subscriptions per team | ≥ 95 % of active members | OPEN (count exists per subscription; team measure to add) |
| Perceived usability: System Usability Scale, short anonymous survey per team | survey outside NAVORA's care data; `lca` checks the survey's privacy notice first | SUS ≥ 75 by pilot week 6 | OPEN |
| Support questions about "where is…" / "what does this mean" | pilot support log, counted per week | falls week over week | OPEN |

## Quick wins (0-2 weeks)

| Item | What changes for the user | Brief | Status |
|---|---|---|---|
| Screenshots of every screen per role in CI | `uxa` can review every change; regressions are visible before merge | UX1-14 | PLANNED |
| Phone width for Settings, Admin, Operations | push opt-in for safety signals works on a phone | UX1 (a) | PLANNED |
| Menu per role, no dead items | a nurse sees only what she can use | UX1 (b) | PLANNED |
| `/field`: next visit first, one primary button, confirmation for cancel and hold | less orientation at the door, fewer wrong taps | UX1 (c) | PLANNED |
| Plain words instead of internal codes; NAVORA; "Ausnahmen" instead of "Control Tower" | text a nurse and a buyer can read | UX1 (d) | PLANNED |
| Dark-mode check (page background vs. hard-coded light colours) | no unreadable screens on phones in dark mode | `uxa` first task; brief only if a defect is found | OPEN |

## Medium term (2-8 weeks)

| Item | What changes for the user | Brief | Status |
|---|---|---|---|
| One app shell: phone tab bar (Heute, Team, Arbeitstag, Mehr), desktop sidebar | one product, every screen reachable | UX2 | PLANNED |
| Design tokens and a small component set; no inline layout styles | consistent look; new screens built once | UX2, design system §7 | PLANNED |
| First-MVP pages ported or retired (`/teams`, `/visits`, `/partners`) | no second, older product inside the app | UX2-5 | PLANNED |
| The three zones (Jetzt / Als Nächstes / Später) on `/team`, `/operations`, `/work` | the team sees its open decisions first; Operations sees only what nobody took | UX3 (to be briefed by `po` from `uxa`'s criteria after the first screenshot review) | OPEN |
| Empty, loading and error states with one next step | no blank or technical screens | with UX3 | OPEN |
| Notification experience: push text, grouping, what opens on tap | a signal leads straight to the one action | with UX3; push text is privacy-relevant (`lca`), signal content stays `cra`'s | OPEN |
| First moderated usability test with pilot nurses (5 people, synthetic seed) | real users decide, not assumptions | `uxa` plans, `po` approves; no health data | OPEN |

## Longer term (2-6 months)

| Item | What changes for the user | Depends on | Status |
|---|---|---|---|
| A role-based "Heute" inbox across every role: one list of what needs this person now, built from the signals, tasks and decisions NAVORA already holds | the user does not have to know which screen holds her work | UX2, UX3 | OPEN |
| Progressive disclosure of rules: the rule appears only as the reason for a refused action, with the one way forward | rules guide instead of lecture | UX3 | OPEN |
| Tolerant of poor connectivity at the door (installable web app, clear offline state, no lost input) | care is not blocked by a dead spot in a stairwell | ADR by Engineering; data at rest on a phone is privacy-relevant (`lca`) | OPEN |
| Referrer and hospital-facing screens for transitions of care | a discharge planner refers without phone calls | REF2 (draft; D-9, D-3) | OPEN |
| AI drafting assistance in documentation (draft, the nurse confirms) | less typing, same accountability | D-35 (po-decided), D-34 intended purpose (owner), `cra` | OPEN |
| French and Italian for the Swiss rollout | teams outside German-speaking cantons | D-11 (pilot canton) | OPEN |
| Nursing-home variant of the shell (ward, shift, resident) | the same model inside a nursing home | Horizon "nursing homes" (`CARE_OPERATING_MODEL.md`) | OPEN |
| Accessibility conformance statement (WCAG 2.2 AA) | procurement by public and private providers | UX2-8 in place | OPEN |

## Ownership and flow

`uxa` reviews CI screenshots and changed screens, keeps the design system, writes findings to `docs/agents/reports/UX_REVIEW.md` and opens `ux` issues; the PO turns them into briefs and orders them by the value order (value 1 direct care time first; patient safety a precondition); Engineering builds; `cra` confirms any change to a wording it fixed or to how a safety signal is shown; `lca` reviews anything a screen shows to a client, a referrer or outside the app. Only a strategic product decision goes to the owner.
