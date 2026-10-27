# NAVORA design system

**Owner:** UX/UI Design Architect (`uxa`, owner 2026-10-27) · **Version:** 3 (seeded by `po` 2026-10-27 10:40 CET as version 0; maintained by `uxa` from 2026-10-27 10:42 CET) · **Status of each part:** IMPLEMENTED (in code today), PLANNED (in an approved brief), OPEN (no brief yet).

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
- Dark mode (checked by `uxa` 2026-10-27, UXR-8): every protected page root and `/login` set their own background and text colour, so the dark `body` does not show through; no defect found in code. Residual: native form controls follow the system scheme (no `color-scheme: light`). Until a dark theme is designed NAVORA is light only: `color-scheme: light` on `:root` (OPEN, report only).
- **Safety-signal card** (OPEN; benchmark 2026-10-27, `cra` must confirm before any brief uses it): the first line names the situation and its one action; a visually hidden prefix ("Sicherheitssignal:") gives screen readers the level that colour gives sighted users; a P1 card has exactly one action; one situation is never shown in two stacked cards; text after a card has its own heading.

## 4. Language

- Plain German (Swiss spelling, "ss" not "ß"), the words the team uses. No internal codes (D-…, SIG…, F1–F4, PLAN2, WORK1, CGR-…) in user-facing text; references for reviewers go into a marked reviewer element. PLANNED: UX1-11.
- One product name: **NAVORA**. No "Control Tower", "Board", "Drilldown", "Swiss Care OS", "MVP". PLANNED: UX1-13, UX2-6.
- A text that `cra` or `lca` fixed keeps its substance word for word; a wording change goes to them first (README, *UX review*).
- **Long fixed information texts** (e.g. the `/work` working-time notice): words unchanged and nothing collapsed; one lead line saying what to do and what comes after; a short heading per paragraph that is accurate for the whole paragraph and names every recipient it mentions; lead line and headings are fixed text next to the paragraphs (same versioning) and `lca` confirms them. Never "bestätigen" next to a privacy text (reads as consent). OPEN (UXR-3; `lca` D-23 11:41, PR #520).
- Say what happens, not which rule applies: "Wird nicht abgerechnet, bis die Sperre aufgehoben ist", not "QG1-Hold aktiv".

## 5. Layout, density, mobile first

- **Phone first:** every protected screen and the sign-in page (`/login`, UXR-1: PLANNED, UX1-15) work at **390 × 844** with no horizontal scroll (PLANNED: UX1-1, UX2-2). Desktop at 1440 px is the second layout, not the first.
- The next visit on `/field` is inside the first viewport when there is no P1 signal (PLANNED: UX1-6).
- **Density:** at most one line of explanation under a heading; details behind "Details". A card shows at most four facts before its action.
- One shell for every role: phone tab bar (Heute, Team, Arbeitstag, Mehr), desktop sidebar (PLANNED: UX2-1).

## 6. Accessibility floor

- WCAG 2.2 AA contrast; tap targets at least 44 × 44 px; keyboard reachable navigation with `aria-current`; visible focus; no information only in colour (PLANNED: UX2-8, axe in CI: serious and critical fail).
- Text resizes to 200 % without loss of function (OPEN).
- **Secondary text** (meta lines, reasons, times) uses the `text-secondary` token with at least 4.5:1 on every surface; no text under 18 px with a colour opacity below 80 % (PLANNED: UX1-17, UX1-18; today 57 uses below that, UXR-2).

## 7. Tokens and components

PLANNED in UX2-3: one token set and a small component set. **Proposal by `uxa` (2026-10-27 10:42 CET), for Engineering's UX2 ADR; OPEN until UX2 builds it.** Values build on what the nurse screens already use (Tailwind, emerald, stone), so `/field`, `/team` and `/work` change little and the first-MVP inline hex colours are retired. Tailwind v4 `@theme` variables in `src/app/globals.css` are the one place; components use the token names, never raw palette classes or hex values. Every contrast pair below must be confirmed by axe in CI (calculated values are approximations: UNKNOWN until measured).

**Colour (semantic):**

| Token | Proposed value | Use | Never |
|---|---|---|---|
| `surface-page` | stone-100 | page background | cards |
| `surface-card` | white | cards, sheets, inputs | |
| `border` | stone-300 | card and input borders | text |
| `text-primary` | emerald-950 | body text, headings | |
| `text-secondary` | stone-700 (or emerald-900 at ≥ 80 %) | meta lines, reasons, times; ≥ 4.5:1 on `surface-page` and `surface-card` | opacity below 80 % |
| `brand` | emerald-950 | header band, product name | buttons |
| `action-primary` | emerald-800, white text | the one filled button per card | any second filled button |
| `action-outline` | white, `border`, `text-primary` | secondary actions, destructive actions before their confirming step | |
| `signal-p1` | rose-700 border, rose-50 background, rose-900 text, rose-800 button | P1 safety signals only (SIG1); how a signal looks is `cra`'s | anything else: destructive actions, urgency badges, banners, errors |
| `attention` | amber-800 text on amber-50 | needs action today, not a safety signal | safety signals |
| `info` | stone-700 on stone-50 | neutral status, empty states | |
| `success` | emerald-800 on emerald-50 | confirmed, done | |
| `error-inline` | text in `text-primary` with an icon and the word "Fehler"; border amber-800 | a refused command | the P1 colour |
| `focus` | 2 px ring emerald-700, 2 px offset | every interactive element | removal without replacement |

**Spacing:** 4 px base; steps 4, 8, 12, 16, 24, 32 (Tailwind 1, 2, 3, 4, 6, 8). Page gutter 16 px on a phone, 32 px on a desktop; gap between cards 12 px.
**Type scale:** 12 (meta only, never the only carrier of a fact a nurse acts on), 14 (secondary), 16 (body, inputs: prevents zoom on iOS), 18 (card title), 20 (section heading), 24 (page heading). Line height 1.5 for body, 1.25 for headings. One font family.
**Radius:** 8 px for buttons and inputs, 16 px for cards. **Elevation:** one card shadow or none; no coloured shadows.
**Touch:** every interactive element at least 44 × 44 px (`min-h-11`), 8 px between adjacent targets.

**Components (one each):** button (`primary`, `outline`, `destructive-confirm`: outline first, then a confirming step naming the consequence in one sentence); card (title, at most four facts, one primary action, "Mehr"); section header with count and collapse; badge (word plus colour, never colour alone); list row; input and select (`w-full min-w-0`, label above); "Mehr" menu with confirmation; empty state (one sentence plus one next step); signal card (`signal-p1`, `cra`-owned content, pattern in §3).

## 8. Screenshots and review

- CI produces screenshots of every protected route on the synthetic seed at 390 px and 1440 px, per role, as a CI artifact (PLANNED: UX1-14, extended in UX2-2; axe on page content: UX1-18). `uxa` reviews them against this file and records findings in `docs/agents/reports/UX_REVIEW.md`.
- Screenshots never contain real personal or health data and are never committed to `recovery/main`.

**Review procedure** (`uxa`, every run; IMPLEMENTED as a process from 2026-10-27):
1. **Find the change:** PRs merged or open since the last section that touch `src/app`, `src/components`, styles or e2e; new or changed briefs; open `ux` issues.
2. **Get the images:** the newest `ui-screenshots` artifact for `recovery/main` and for each open screen-changing PR, each unpacked into its own empty directory outside the repository. If the artifact cannot be downloaded (no artifact yet, or the session's network refuses the storage host), review from images already on a temporary branch, from a static reproduction of the layout, or from the code, and say which in the section. Never against the live project.
3. **Check every captured route and role** at 390 × 844 first, then 1440 × 900: (a) the three questions in order (§1); (b) one primary action per card (§2); (c) severity colours only where they belong (§3); (d) no internal codes, one name NAVORA, plain Swiss German (§4); (e) no horizontal scroll, next step in the first viewport, at most four facts per card (§5); (f) contrast, 44 px targets, focus, meaning not only in colour (§6); (g) tokens and components, no inline layout (§7); (h) regressions against the previous section.
4. **Rate and route:** severe and high → one issue each for the PO (`agents`, `agent:po`, `ux`, plus `ux:severe`); lower → the report. Anything about how a safety signal or safety-related state is shown → a request to `cra`; anything shown to a client, a referrer or outside the app, or any text `lca` fixed → a request to `lca`. Requests are listed in the report with one question each and stay OPEN until answered.
5. **Close with evidence:** a finding is closed only with a screenshot or test on `recovery/main` that shows the remedy.

## Change log

- 2026-10-27 11:49 CET (`uxa`): version 3. §4 pattern for long fixed information texts (from `lca`'s answer to L-1); §5 `/login` and §6 secondary text from OPEN to PLANNED (UX1-15, UX1-17/-18, PO 11:10).
- 2026-10-27 11:19 CET (`uxa`): version 2. §8 review procedure (owner 2026-10-27: continue the design system and the screenshot review); requests C-1 to C-4 to `cra` and L-1 to `lca` recorded in the UX review.
- 2026-10-27 10:42 CET (`uxa`): version 1. §3 dark-mode check answered from code (UXR-8) and the safety-signal card pattern (OPEN, from the benchmark; `cra` to confirm); §5 `/login` in the phone-first scope (UXR-1); §6 secondary-text contrast rule (UXR-2); §7 token and component proposal before UX2.
- 2026-10-27 10:40 CET (`po`): version 0 from the UX review of 2026-10-27 (#506-#510) and the owner's instruction (three questions, pilot adoption first-class).
