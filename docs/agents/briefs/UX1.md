---
id: UX1
title: The nurse's phone shows her next visit first, one clear action per card, a menu that fits her role and words she can read
author: po
status: approved
updated: 2026-10-27
---

# UX1 — Next visit first, one clear action, a menu for her role, plain words

## Problem
A UX review of `recovery/main` at `6abf941` (screenshots on the synthetic seed, 390 px and desktop; issues #506 to #509, 2026-10-27) found four severe presentation defects. The PO checked the code references on `6e1143f` (IMPLEMENTED = present in code today):

- **U3 (#506), IMPLEMENTED defect:** `/settings` (`settings-client.tsx:86`), `/admin` (`admin-client.tsx:64`) and `/operations` (`operations-client.tsx:66`) use a fixed `280px 1fr` / `240px 1fr` grid with no breakpoint. At 390 px the page scrolls sideways and the content column is about 110 px wide. `/settings` is where a nurse switches on push for SIG1 safety signals (SIG2). A safety signal that reaches nobody outside the app because opt-in fails on a phone is a patient-safety gap, not a cosmetic one.
- **U2 (#507), IMPLEMENTED defect:** `src/components/layout/Sidebar.tsx` shows every item to every signed-in role. "Administration" refuses a nurse; "Qualitätsmanagement" (`Sidebar.tsx:142`) is a label with no link; "Teams Übersicht" (`/teams`) and "Einsätze" (`/visits`) are first-MVP pages.
- **U5-U7 (#509), IMPLEMENTED defect:** on `/field` every action is a filled, saturated button; "Abrechnungssperre setzen" (`quality-section.tsx:83`) and "Einsatz absagen" (`visit-lifecycle.tsx:112`) sit at the weight of "Losfahren"; the next visit starts about 1,100 px down, after signals, the workday link, three counters, the absence button and "Offen im Team".
- **U4 (#508), IMPLEMENTED defect:** user-facing text carries internal codes (D-11, D-18, D-28, D-33, SIG1-8, F1–F4, PLAN2, WORK1). The operations heading reads "Navora Operations Control Tower" (`operations-client.tsx:145`) and the sidebar "Swiss Care OS" (`Sidebar.tsx:101`).

`/field` is the nurse's tool at the client's door. Every second spent finding the next visit or recovering from a wrong tap is taken from direct care time, the North Star (`docs/product/CARE_OPERATING_MODEL.md`).

## Users and journey step
Nurses and care assistants (Visit, Documentation: `/field`, `/settings`), team members and coaches (`/team`), Operations (`/operations`), administrators (`/admin`). No step of the data flow changes; this is the presentation of Planning → Visit → Documentation and of the safety-signal opt-in.

## Outcome
On a phone a nurse sees her next visit without scrolling, knows which one button to press, can switch on safety-signal push, meets only menu items she can use, and reads plain German instead of internal codes.

## Acceptance criteria

**(a) Phone width (U3, #506)**
- [ ] **UX1-1** `/settings`, `/admin` and `/operations` have no horizontal scroll at 390 px: Playwright asserts `document.documentElement.scrollWidth <= 390` for each, signed in with the role that may open it. Below 768 px the side column collapses (drawer or stacked), the pattern of `/intake` (`md:grid-cols-[280px_1fr]`).
- [ ] **UX1-2** e2e at 390 px: a nurse completes push opt-in on `/settings` (the existing SIG2 flow, stubbed provider as in the SIG2 e2e) and sees the confirmed state.

**(b) Menu by role (U2, #507)**
- [ ] **UX1-3** The menu shows an item only to the roles whose server-side page check admits them (the page's existing check is the source; one shared function or table maps route → roles, unit-tested against each page's check so they cannot drift). e2e per role (nurse, coach, operations, admin): every visible item opens its page without a refusal message.
- [ ] **UX1-4** No menu item without a target: "Qualitätsmanagement" either links to the existing quality view the role may open or is removed. The first-MVP pages `/teams` and `/visits` are not in the menu (the routes stay until UX2 decides them).
- [ ] **UX1-5** Negative: server-side access checks and RLS are unchanged (diff shows no migration and no change to any page's access check); a nurse who types `/admin` still gets the existing refusal.

**(c) `/field` action hierarchy (U5-U7, #509)**
- [ ] **UX1-6** Order on `/field`: (1) any SIG1 safety signal that concerns her, unchanged in content, rule and position (above everything, as today); (2) her next visit; (3) her other visits today; (4) "Offen im Team", collapsed, its count in the header; (5) workday link and counters below. e2e at 390 px with the seed nurse who has no P1 signal: the next visit's heading is inside the first viewport (`boundingBox().y + height <= 844`).
- [ ] **UX1-6a** **PO decision, accepted criteria kept:** "Ich kann nicht arbeiten" stays inside the first viewport, at most two taps from the top (ABS1, accepted 2026-10-23: "reachable from the top of `/field` in at most two taps", e2e "the button is in the viewport"), as a compact outline control (e.g. in the header row), not below the visit list. Taking an open visit stays one tap (ABS1/COVER1 "one tap, first wins"): while "Offen im Team" is collapsed and lists a visit today that she may take, its header shows the earliest such visit with its "Übernehmen" button. The ABS1 and COVER1 e2e pass unchanged except for selectors.
- [ ] **UX1-7** At most one filled (primary) button per card; other actions are outline buttons. Component or e2e test counts filled buttons per card on `/field`.
- [ ] **UX1-8** "Einsatz absagen" and "Abrechnungssperre setzen" sit in a "Mehr" menu of the visit card and need two taps; the second step states the consequence in one sentence (cancellation: the visit is released to the team; hold: the visit is not billed until the hold is lifted, wording reviewed by `cra`) before the existing command runs. The commands, their audit records and their refusals are unchanged.
- [ ] **UX1-9** **PO decision on the review's proposal:** "Ereignis melden" stays one tap, as an outline button on the card, **not** in "Mehr". Reporting a safety or quality event must stay as easy as today (QG1); only actions with billing or planning consequences move behind a confirmation.
- [ ] **UX1-10** Negative: no signal rule, threshold, priority, recipient or text fixed by `cra` changes; the `/field` e2e suites of SIG1, ABS1, COVER1, F1-F4, F7, DOOR1 and QG1 pass unchanged except for selectors (any assertion change is listed in the PR with its reason).

**(d) Plain words (U4, #508)**
- [ ] **UX1-11** A unit test renders the pages' user-facing strings (or scans the TSX string literals under `src/app/(protected)` and `src/components`) and fails on `/\b(D-\d+|SIG\d+(-\d+)?|F\d(–F\d|-F\d)?|PLAN\d|WORK\d|CGR-\d+|COND\d|IPA\d)\b/` outside an element or attribute marked for reviewers (e.g. `data-ref`, shown in a tooltip or info sheet). Code comments are not user-facing and are exempt.
- [ ] **UX1-12** Every replaced text keeps its meaning. Texts fixed by `cra` or `lca` (hold meaning, IPA1 wordings, WORK1 notice, SIG1-8 condition, billing-estimate limits) keep their substance word for word; only the code is removed or moved to the reviewer reference. The PR lists each changed string old → new; `cra` confirms the list before merge (clinical gate).
- [ ] **UX1-13** One product name "NAVORA" in user-facing headings; "Swiss Care OS", "Navora MVP" and "Control Tower" are gone. `/operations` is headed "Ausnahmen" (it is the OPS1 exception center; the care model has no dispatcher, so the page is not named as one). English UI labels on the touched pages ("Drilldown", "KPI / Analytics") become German.

**(e) Screenshots in CI (owner 2026-10-27: the UX/UI Design Architect reviews CI screenshots; added by po 10:40)**
- [ ] **UX1-14** A CI job renders every protected route on the synthetic seed at 390 × 844 and 1440 × 900, signed in with each role that may open it (nurse, coach, operations, admin), and uploads the images as a GitHub Actions artifact named `ui-screenshots` on every push to `recovery/main` and on every PR that changes `src/app` or `src/components`. Images are never committed to `recovery/main`; the job fails only on a render error, not on a visual difference (visual diffs are `uxa`'s review). The artifact is listed in the PR and kept at least 14 days.

## Rules and their input class
None. UX1 adds and changes no signal, threshold, gate, priority or read scope; it orders, styles and words what exists. The order in UX1-6 keeps every SIG1 safety signal above everything else, as today. Moving two actions behind a confirmation (UX1-8) does not change who may run them or what they do.

## Out of scope
- One app shell, tab bar, design tokens, porting the first-MVP inline-styled pages, retiring `/teams`, `/visits`, `/partners`: **UX2** (#510).
- Any change to a database function, RLS, a migration or a server-side access check.
- New features on any screen.

## Constraints and references
`uxa` (UX/UI Design Architect, owner 2026-10-27) reviews the UX1 screens from the UX1-14 screenshots against `docs/design/DESIGN_SYSTEM.md`; before acceptance the PO decides each `severe` finding on UX1 (README, *UX review*). Issues #506, #507, #508, #509 (UX review 2026-10-27). SIG1, SIG2 (push opt-in), QG1 ("Abrechnungssperre", CGR-13), IPA1 (wordings), WORK1, DOOR1, OPS1. `cra` clinical gate (README): `cra` reviews the `/field` order (UX1-6) and the string list (UX1-12) before merge. Patient safety: a safety signal must not move below anything (UX1-6). Synthetic seed only; no personal data in screenshots or tests.

## Open questions for engineering
- One PR or two? (a)+(b)+(e) and (c)+(d) may ride separate PRs under one hand-off; build (e) first so `uxa` can review the rest from its screenshots. UX1 is `delivered` when all five parts are merged.
- If a page's server-side check cannot be expressed as a role list (e.g. it depends on team membership), state how the menu decides and keep the server check as the boundary.
- Name the seed nurse and the viewport used by UX1-6 in the e2e, so the "first viewport" claim is reproducible.
