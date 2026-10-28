---
id: UX2
title: One NAVORA app on phone and desktop: one shell, one navigation, one design language
author: po
status: approved
updated: 2026-10-28
---

# UX2 — One app shell for every role

## Problem
UX review 2026-10-27, finding U1 with U16 and U18 (issue #510; screenshots of `recovery/main` at `6abf941`, synthetic seed). The PO checked the code on `6e1143f`:

- IMPLEMENTED: `/field`, `/team` and `/work` use a dark-green header, a narrow centred column and Tailwind, with no shared navigation. `/operations`, `/intake`, `/analytics`, `/admin`, `/settings` and the first-MVP pages `/teams`, `/visits`, `/partners` use the first MVP's `Sidebar.tsx` shell, partly with inline `style={{…}}` layout (`admin-client.tsx:64`, `settings-client.tsx:86`, `operations-client.tsx:66`, `teams-client.tsx:142`, `visits-client.tsx:104`, `partners/page.tsx:14`).
- On the phone a nurse cannot reach `/settings` (push opt-in for safety signals) from `/field`; `/work` is reachable only through a button in the content.

A nurse moving between her own screens changes layout, colour, navigation and vocabulary. The product reads as two products, which costs trust with pilot teams and buyers and makes every new screen pick one of two patterns.

UX1 fixes the severe symptoms (phone width, menu per role, `/field` order, codes in text). UX2 removes the cause.

## Users and journey step
Every signed-in role: nurses and care assistants (Visit, Documentation), team members and coaches (Team Decision, Planning), Operations, administrators, intake. No data-flow step changes.

## Outcome
Every protected screen is part of one NAVORA app: on a phone a tab bar (Heute, Team, Arbeitstag, Mehr), on a desktop a sidebar, the same tokens and components everywhere, and every screen a role may use is reachable from the navigation.

## Acceptance criteria
- [ ] **UX2-1** One shell in `src/app/(protected)/layout.tsx` (or a shared component it renders) wraps every protected route. Phone (< 768 px): bottom tab bar Heute (`/field`), Team (`/team`), Arbeitstag (`/work`), Mehr (the rest the role may open, `/settings` among them). Desktop: a sidebar with the same items. Items per role from the UX1-3 route → roles map (one source).
- [ ] **UX2-2** The UX1-14 screenshot job additionally asserts, for every protected route and role, that the shell is present and there is no horizontal scroll (`scrollWidth <= viewport`); images stay a CI artifact (not committed to `recovery/main`).
- [ ] **UX2-3** Design tokens (colour, spacing, type scale, radius) in one place, used through a small component set (button primary/outline/destructive, card, section header, badge, list row). Status and severity colours keep their meaning; the P1 signal colour is used for nothing else.
- [ ] **UX2-4** No inline `style={{…}}` layout under `src/app/(protected)`: a lint rule (ESLint `react/forbid-dom-props` for `style`, or an equivalent check in CI) fails on it; documented exceptions only for computed values (e.g. a bar width), each with a comment.
- [ ] **UX2-5** First-MVP pages decided one by one in the PR and the ADR: `/teams`, `/visits`, `/partners`. For each, either (i) ported into the shell because it holds a function no newer screen has (name the function), or (ii) retired (route removed or redirected to its successor), with the successor named. No function a role uses today is lost; the PR lists each removed function and where it now lives.
- [ ] **UX2-6** One product name "NAVORA"; German labels on every protected screen (no "Board", "Drilldown", "Control Tower", "Dashboard" as UI labels). Texts fixed by `cra` or `lca` keep their substance word for word (as UX1-12).
- [ ] **UX2-7** Negative: no migration, no RLS, no server-side access check, no signal rule or text fixed by `cra` changes. SIG1 safety signals stay above all content on `/field` and `/team` inside the new shell. The full e2e suite passes; changed assertions are selectors only, listed in the PR.
- [ ] **UX2-8** Accessibility floor on the shell: tab bar and sidebar are reachable by keyboard, have `aria-current` on the active item, tap targets at least 44 × 44 px, and text contrast at least WCAG AA (automated check with axe on the shell in the screenshot job; violations of level serious or critical fail). **PO 2026-10-27 11:10:** page content is checked from UX1 on (UX1-18); UX2-8 keeps that check on every ported page and adds the shell.
- [ ] **UX2-9** **Safety-signal card rules (`cra` C-4, "confirm with change"; added by po 2026-10-27 18:10).** Each P1 card: the first line names the situation; one primary action first, and no action a card has today is removed or moved off the card (e.g. the `visit_interrupted` decision form stays); a visually hidden prefix "Sicherheitssignal:" for screen readers; text after a card gets its own heading. Component test per signal kind: one primary button, every action present before UX2 still present, the prefix in the accessible name.
- [ ] **UX2-10** **Axe on working states and undecided results (`uxa` UXR-21, low; added by po 2026-10-28 04:10).** (a) The screenshot job writes axe `incomplete` nodes for `color-contrast` into `axe_<role>_<viewport>.json` under an `incomplete` key (recorded for `uxa` review, no fail); (b) at 390 × 844 for the nurse, the job also captures and axe-checks the open "Ich kann nicht arbeiten" dialog on `/field` and the open "Mehr" item of the new tab bar (UX2-1), with the same fail rule as UX2-8 (serious or critical fails). Test: the JSON has an `incomplete` key; the screenshots `nurse_field_dialog_390x844.png` and `nurse_field_more_390x844.png` exist in the CI artifact. Negative: no page, text or rule changes; synthetic seed only.
- [ ] **UX2-12** **One `h1` per page, and it is the page's name (`uxa` UXR-24, medium; added by po 2026-10-28 12:15).** The shell renders the product name "NAVORA" as a non-heading element (link or text), never as a heading; each protected page's `PAGE_LABEL` is its single `h1` (today `/admin`, `/analytics` and `/settings` head their page with an `h2`). Playwright per role and per protected route the role may open, at 390 × 844 and 1440 × 900: `getByRole("heading", { level: 1 })` has count 1 and its text equals the page's label in `nav.ts`. Negative: no label, route, rule or read scope changes (WCAG 1.3.1, 2.4.6).

## Rules and their input class
None. UX2 adds and changes no signal, threshold, gate, priority or read scope. The navigation is not a security boundary: every page keeps its server-side check.

## Out of scope
- New functions on any screen; analytics content; any database change.
- A native app or offline mode.
- Marketing site and login page design beyond using the same tokens.

## Constraints and references
Tokens and components follow `uxa`'s proposal in `docs/design/DESIGN_SYSTEM.md` §7 (recorded before UX2 starts; if none is recorded when Engineering claims UX2, Engineering proposes them in the ADR and `uxa` reviews). Before acceptance the PO decides each `severe` `uxa` finding on UX2. Issue #510 (U1, U16, U18). Depends on **UX1** (route → roles map, UX1-3; plain words, UX1-11). `cra` clinical gate: `cra` looks at the `/field` and `/team` screens in the new shell (signal position, hold wording) before merge. Synthetic seed only; no personal data in screenshots. `docs/product/CARE_OPERATING_MODEL.md`: no dispatcher, so no screen is named or styled as a control room.

- [ ] **UX2-11** **A returned report never leaves her day while unsigned (`cra` 05:30 on the PO 04:10 challenge, F6R-5; added by po 2026-10-28 06:10).** Whatever form the ported `/field` takes (a separate returned-reports section or the correction as the visit card's next action), a report a registered nurse returned stays visible on the performer's `/field` until she signs it again, whatever its visit date. Test (e2e or component with the synthetic seed): a returned report whose visit is dated before today appears on today's `/field` with the reason; after she signs again it is gone. If an existing test already asserts this, the PR names it and shows it still passes inside the new shell. Negative: no change to `field_returned_reports`, the return flow (F6R) or any text fixed by `cra`.
## Open questions for engineering
- Route groups: does one `(protected)/layout.tsx` fit, or do the nurse screens need their own group for the phone shell? State it in the ADR.
- Size: port page by page in several PRs under one hand-off; UX2 is `delivered` when UX2-1 to UX2-12 hold on `recovery/main`.
