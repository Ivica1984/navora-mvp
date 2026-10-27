# NAVORA design system

**Owner:** UX/UI Design Architect (`uxa`, owner 2026-10-27) · **Version:** 0 (seeded by `po` 2026-10-27 10:40 CET; `uxa` maintains it from its first run) · **Status of each part:** IMPLEMENTED (in code today), PLANNED (in an approved brief), OPEN (no brief yet).

This file says how NAVORA screens behave and look. It is a contract for Engineering (what to build), for the PO (what to accept) and for `uxa` (what to review against). Code wins where it differs; the difference is then a finding.

## 1. The three questions (product principle, owner 2026-10-27)

Every screen answers, for the person looking at it, in this order:

1. **What needs my attention now?** Safety signals that concern her, then anything that blocks care today.
2. **What do I do next?** One next step, one primary action.
3. **What can wait?** Everything else, collapsed or below, with its count.

A screen that shows rules, codes or every fact at the same weight fails this test even when each fact is correct. NAVORA's business logic is mature; the screen's job is to turn it into a sequence the user can follow without knowing the rules.

| Zone | German label (default) | Contains | Never contains |
|---|---|---|---|
| Jetzt | "Jetzt" | P1 safety signals for her (SIG1), a visit that is due or overdue, a blocking condition with its one action | counters, explanations, codes |
| Als Nächstes | "Als Nächstes" | her next visit or task with one primary button | more than one primary button |
| Später | "Später" / section name with count | the rest of today, team items, history, settings | anything safety-relevant that is due |

Status: the principle is binding from 2026-10-27. On `/field` it is PLANNED in UX1 (UX1-6); for `/team`, `/operations`, `/work` and `/admin` it is OPEN (roadmap, medium term).

## 2. Action hierarchy

- **One primary action per card or screen section** (filled button). PLANNED: UX1-7.
- **Secondary actions** are outline buttons. **Destructive or billing- and planning-changing actions** (cancel a visit, set a billing hold, end access) sit behind "Mehr" and a confirming step that names the consequence in one sentence. PLANNED: UX1-8.
- **Safety and quality reporting stays one tap** ("Ereignis melden"; PO decision UX1-9). Recording an absence stays at most two taps from the top of `/field` (ABS1, accepted).
- Never two filled buttons of different colours side by side.

## 3. Colour and severity

- **Severity colours are reserved.** The P1 signal colour (red family) is used for P1 safety signals and nothing else; amber for "needs action today, not a safety signal"; neutral for everything else. A brand or action colour is never red or amber. PLANNED: UX2-3.
- Colour is never the only carrier of meaning: every severity has a word or icon too.
- IMPLEMENTED today: two systems. Nurse screens use Tailwind with emerald-800/900 headers and amber, blue and sky accents (`src/app/(protected)/field/*`); first-MVP screens use inline hex colours (`#f4f7f4`, `#153328`). `src/app/globals.css` switches the page background to dark under `prefers-color-scheme: dark` while pages hard-code light colours: effect on a phone in dark mode UNKNOWN; first `uxa` check.

## 4. Language

- Plain German (Swiss spelling, "ss" not "ß"), the words the team uses. No internal codes (D-…, SIG…, F1–F4, PLAN2, WORK1, CGR-…) in user-facing text; references for reviewers go into a marked reviewer element. PLANNED: UX1-11.
- One product name: **NAVORA**. No "Control Tower", "Board", "Drilldown", "Swiss Care OS", "MVP". PLANNED: UX1-13, UX2-6.
- A text that `cra` or `lca` fixed keeps its substance word for word; a wording change goes to them first (README, *UX review*).
- Say what happens, not which rule applies: "Wird nicht abgerechnet, bis die Sperre aufgehoben ist", not "QG1-Hold aktiv".

## 5. Layout, density, mobile first

- **Phone first:** every protected screen works at **390 × 844** with no horizontal scroll (PLANNED: UX1-1, UX2-2). Desktop at 1440 px is the second layout, not the first.
- The next visit on `/field` is inside the first viewport when there is no P1 signal (PLANNED: UX1-6).
- **Density:** at most one line of explanation under a heading; details behind "Details". A card shows at most four facts before its action.
- One shell for every role: phone tab bar (Heute, Team, Arbeitstag, Mehr), desktop sidebar (PLANNED: UX2-1).

## 6. Accessibility floor

- WCAG 2.2 AA contrast; tap targets at least 44 × 44 px; keyboard reachable navigation with `aria-current`; visible focus; no information only in colour (PLANNED: UX2-8, axe in CI: serious and critical fail).
- Text resizes to 200 % without loss of function (OPEN).

## 7. Tokens and components

PLANNED in UX2-3: one token set (colour, spacing, type scale, radius) and a small component set: button (primary, outline, destructive), card, section header with count, badge (severity), list row, "Mehr" menu with confirmation, empty state. Until then: OPEN; `uxa` records the token proposal here before Engineering builds UX2.

## 8. Screenshots and review

- CI produces screenshots of every protected route on the synthetic seed at 390 px and 1440 px, per role, as a CI artifact (PLANNED: UX1-14, extended in UX2-2). `uxa` reviews them against this file and records findings in `docs/agents/reports/UX_REVIEW.md`.
- Screenshots never contain real personal or health data and are never committed to `recovery/main`.

## Change log

- 2026-10-27 10:40 CET (`po`): version 0 from the UX review of 2026-10-27 (#506-#510) and the owner's instruction (three questions, pilot adoption first-class).
