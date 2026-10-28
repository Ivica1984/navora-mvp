# NAVORA design system

**Owner:** UX/UI Design Architect (`uxa`, owner 2026-10-27) · **Version:** 10 (seeded by `po` 2026-10-27 10:40 CET as version 0; maintained by `uxa` from 2026-10-27 10:42 CET) · **Status of each part:** IMPLEMENTED (in code today), PLANNED (in an approved brief), OPEN (no brief yet).

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

- **One primary action per card or screen section** (filled button). IMPLEMENTED on `/field` visit cards (UX1-7, #554); other screens PLANNED (UX2).
- **Secondary actions** are outline buttons. **Destructive or billing- and planning-changing actions** (cancel a visit, set a billing hold, end access) sit behind "Mehr" and a confirming step that names the consequence in one sentence. IMPLEMENTED on `/field` (UX1-8, #554). The sentence states what happens to the care, not to the data model, from facts `cra` or `eng` give (e.g. removing a planned visit: the care planned for that time does not take place unless someone plans it again; `cra` C-2 (b), wording OPEN).
- **Proposals and confirmation** (assistants, rule-based or AI; PLANNED in AIG1-3, AIG1-4, AIG1-5, AIG1-10, PLAN3-9): a proposed value is marked with the word "Vorschlag" and "vorgeschlagen von <Agent>", never by colour alone; a confirmed value shows "bestätigt von <Name> am <Datum>"; a missing value reads "nicht gefunden", never empty, "keine" or a default; there is no "Alle übernehmen": a bulk confirm is an explicit ticked list and only where AIG1-5 allows it. OPEN proposals by `uxa` for the AIG1 and PLAN3 screens: a changed line shows old → new on one line; the confirm button names its count ("3 Einsätze bestätigen"); a line the server refuses stays in the list with its reason. Whether a ticked list starts ticked or unticked affects automation bias (H-20): UNKNOWN, `cra` and the PO decide.
- **Safety and quality reporting stays one tap** ("Ereignis melden"; PO decision UX1-9). Recording an absence stays at most two taps from the top of `/field` (ABS1, accepted).
- Never two filled buttons of different colours side by side.

## 3. Colour and severity

- **Severity colours are reserved.** The P1 signal colour (red family) is used for P1 safety signals and nothing else; amber for "needs action today, not a safety signal"; neutral for everything else. A brand or action colour is never red or amber. PLANNED: UX2-3.
- Colour is never the only carrier of meaning: every severity has a word or icon too.
- IMPLEMENTED today: two systems. Nurse screens use Tailwind with emerald-800/900 headers and amber, blue and sky accents (`src/app/(protected)/field/*`); first-MVP screens use inline hex colours (`#f4f7f4`, `#153328`). `src/app/globals.css` switches the page background to dark under `prefers-color-scheme: dark` while pages hard-code light colours: effect on a phone in dark mode UNKNOWN; first `uxa` check.
- Dark mode (checked by `uxa` 2026-10-27, UXR-8): every protected page root and `/login` set their own background and text colour, so the dark `body` does not show through; no defect found in code. Residual: native form controls follow the system scheme (no `color-scheme: light`). Until a dark theme is designed NAVORA is light only: `color-scheme: light` on `:root`, no dark override (IMPLEMENTED: UX1-19 (ii), #558).
- **Safety-signal card** (PLANNED: UX2-9; benchmark 2026-10-27; `cra` confirmed with change on 2026-10-27 13:37, merged with #532 as `f3a1e83`): the first line names the situation and its primary action; a visually hidden prefix "Sicherheitssignal:" gives screen readers the level that colour gives sighted users; **one primary action first, and no action a card has today is removed or moved off the card** (e.g. the decision form of an interrupted visit stays); one situation is never shown in two stacked cards; text after a card has its own heading.
- **A situation shown as a signal card and in a list** (IMPLEMENTED on `/team`: UX1-22, #602 merged as `f6277ab`, `alertRepeatsSignal` in `src/features/team/rules.ts`; `cra` C-1, merged #532): the list shows a pointer line ("Steht oben als Sicherheitssignal") only when its entry adds nothing the card lacks; an entry with its own action, flags or handling state keeps them visible. An explanation of when a signal clears may sit behind "Wann erledigt sich das?", but a sentence saying the rules are provisional stays visible.
- **Not a safety signal, so not red** (IMPLEMENTED: UX1-23 one urgency map `URGENCY_BADGE_CLASS` for `/intake` and `/team`, UX1-24 team reachability line, #602 merged as `f6277ab`; `cra` C-2 (a), C-3, merged #532): a referral's urgency at intake (a criteria-free label) is shown as a word in `attention` (amber); a team in which not every member receives P1 signals outside the app is shown open, in `attention`, without expanding, with a link to the setting.
- **Error lines are one component, per screen, not per file** (OPEN: UXR-26): a refused command's `role="alert"` line looks the same in every section of a screen (`error-inline`: amber-800 border, amber-50, stone-900 text, as UX1-23 set in `field-client.tsx`); a billing or quality hold is a state, not a P1 signal, so not red. Guarding tests scan every file a route renders, not one file.
- **Actions with a consequence are not red either** (IMPLEMENTED on `/field` "Mehr", #554; guarding test IMPLEMENTED for `field-client.tsx` only, UX1-23, #602; UXR-16; `/team` "Beenden" and "Entfernen" PLANNED: UX2-13): an action inside a "Mehr" menu (e.g. "Abrechnungssperre setzen", "Einsatz absagen") is `action-outline` in neutral colours; its consequence sentence in the confirming step carries the weight, not the colour.

## 4. Language

- Plain German (Swiss spelling, "ss" not "ß"), the words the team uses. No internal codes (D-…, SIG…, F1–F4, PLAN2, WORK1, CGR-…) in user-facing text; references for reviewers go into a marked reviewer element (`data-ref`, not read aloud). IMPLEMENTED for `src/app` and `src/components`: UX1-11, #598 merged as `8d0e812`; messages from `src/features/**` PLANNED: UX1-C2.
- One product name: **NAVORA**. No "Control Tower", "Board", "Drilldown", "Swiss Care OS", "MVP". IMPLEMENTED: UX1-13, #598 merged as `8d0e812`; UX2-6 PLANNED for the rebuilt shell.
- **One label per page** (IMPLEMENTED: UX1-13, #598 merged as `8d0e812`, `PAGE_LABEL` in `src/lib/auth/nav.ts`; UXR-12): the menu item, the page's own name and every link to it from another page use one constant. The page name is the page's `h1`; the product name in the shell is not a heading (PLANNED: UX2-12, UXR-24). No eyebrow line above a page heading that repeats or paraphrases it (IMPLEMENTED: UX1-32, eyebrow check in `tests/unit/ux1-strings.test.ts`; UXR-22).
- Labels are correct German compounds or phrases ("Details zum Pflegeteam", not "Pflegeteam Detail"; IMPLEMENTED: UX1-32, `TEAM_PANEL_HEADING`; UXR-23).
- A text that `cra` or `lca` fixed keeps its substance word for word; a wording change goes to them first (README, *UX review*).
- **Long fixed information texts** (e.g. the `/work` working-time notice): words unchanged and nothing collapsed; one lead line saying what to do and what comes after; a short heading per paragraph that is accurate for the whole paragraph and names every recipient it mentions; lead line and headings are fixed text next to the paragraphs (same versioning) and `lca` confirms them. Never "bestätigen" next to a privacy text (reads as consent). IMPLEMENTED on `/work` (UX1-21, #554; UXR-3; `lca` D-23 11:41).
- Say what happens, not which rule applies: "Wird nicht abgerechnet, bis die Sperre aufgehoben ist", not "QG1-Hold aktiv".

## 5. Layout, density, mobile first

- **Phone first:** every protected screen and the sign-in page (`/login`, UXR-1: IMPLEMENTED, UX1-15, #558) work at **390 × 844** with no horizontal scroll (PLANNED: UX1-1, UX2-2). Desktop at 1440 px is the second layout, not the first.
- The next visit on `/field` is inside the first viewport when there is no P1 signal (IMPLEMENTED: UX1-6, #554; the "Zu erledigen" row above it in the first viewport IMPLEMENTED: UX1-27, #574 merged as `93f7423`, `cra` CGR-80).
- **Density:** at most one line of explanation under a heading; details behind "Details". A card shows at most four facts before its action.
- One shell for every role: phone tab bar (Heute, Team, Arbeitstag, Mehr), desktop sidebar (PLANNED: UX2-1).
- **Every setting a safety signal depends on is reachable from every screen of that role** without typing an address; for a nurse that is "Meine Einstellungen" (push opt-in, SIG2) from `/field`, `/team` and `/work`. IMPLEMENTED: UX1-20, an interim "Menü" in the header of `/field`, `/team`, `/work` (#554; UXR-10), to be replaced by the UX2-1 tab bar (PLANNED).
- Phone frame of the first-MVP pages (`AppFrame`: one column below 768 px, menu in a top bar, side column from 768 px; menu items filtered by each page's own check): IMPLEMENTED (UX1-1, UX1-3; #535 merged as `e68ba84`). Sign-out belongs inside the menu, not as the most prominent control of the bar (UXR-11; IMPLEMENTED: UX1-20, #554).
- **Jump links to sections** ("Zu erledigen" row and similar; IMPLEMENTED for "Entscheid offen": UX1-27, #574 merged as `93f7423`; IMPLEMENTED for "Zurückgegeben" and "Zur Gegenzeichnung": UX1-30, #588 merged as `566dc8b`, UXR-20, with `cra`'s conditions (1)-(3)): a link that jumps to a section has the section heading's name (one constant), stays short (a screen reader reads the row link by link) and states the open work in words plus count; the instruction lives in the section, not the link, rendered right after the heading and never collapsed. A returned report stays on the nurse's `/field` until she signs it again, whatever its visit date, whatever form the rebuilt screen takes (PLANNED: UX2-11, `cra` 05:30, F6R-5). Pattern compared with the NHS task-list component (benchmark 2026-10-28).
- **Header menus and pop-overs** (IMPLEMENTED for the header "Menü": UX1-26, #554; UXR-14): a menu opened from a header closes on Escape, on a tap outside it and after choosing an item; it never stays open over the content it covers.

## 6. Accessibility floor

- WCAG 2.2 AA contrast; tap targets at least 44 × 44 px; keyboard reachable navigation with `aria-current`; visible focus; no information only in colour (PLANNED: UX2-8, axe in CI: serious and critical fail).
- Text resizes to 200 % without loss of function (OPEN).
- **A safety-related state shown open cannot be folded away by accident** (OPEN: UXR-27; how it is shown is `cra`'s): when a `details` is opened because something needs attention (UX1-24 reach gap), the line that says so sits in its `summary` or outside the `details`, and every `summary` is a 44 px target.
- **Secondary text** (meta lines, reasons, times) uses the `text-secondary` token with at least 4.5:1 on every surface; no text under 18 px with a colour opacity below 80 % (IMPLEMENTED as a class scan: UX1-17, #558, and as axe `color-contrast` on every captured page: UX1-18, #574 merged as `93f7423`; UXR-2). The rule covers inline `style` colours too, not only Tailwind classes (UXR-15: `#6b8075` on `#f4f7f4` is about 3.9:1); until UX1-18's axe run exists, a class scan alone does not prove it. Axe `color-contrast` on every captured page (serious and critical fail) and the inline greys replaced by one constant `SECONDARY_TEXT` (`src/lib/ui/colors.ts`) are IMPLEMENTED (#574, CI green on `e759825` and on `recovery/main` `3578bfb`); no screenshot or axe JSON seen by `uxa` yet. Axe also judges states a nurse sees while working (open dialog, open menu) and its undecided (`incomplete`) results are recorded for review (PLANNED: UX2-10, UXR-21).
- **Dialogs** (IMPLEMENTED for the absence dialog: UX1-25, #554; UXR-13): an element with `role="dialog"` and `aria-modal="true"` moves focus into itself on open (first field or its heading), keeps Tab inside, closes on Escape and returns focus to the control that opened it; the native `<dialog>` with `showModal()` does all four.
- **A dialog that sends cannot be dismissed while sending** (IMPLEMENTED: UX1-28 and UX1-31, #588 merged as `566dc8b`; UXR-18, `cra` CGR-85): while its command is pending, "Abbrechen" is disabled and Escape does nothing, so the result (done, refused, or a notice the team must act on) always appears in the open dialog; a result is never set on a closed dialog. A save that throws (lost connection) ends the pending state and shows the generic refusal in the open dialog.
- **When a dialog's content is replaced** (form → notice) or its focused control becomes disabled, focus moves to the new content's heading or its one action ("Schliessen"), never to the page body (IMPLEMENTED for the absence dialog: UX1-33, #602 merged as `f6277ab`; after a refusal focus returns to "Speichern"; UXR-25).
- **A dialog has a visible heading** (IMPLEMENTED: UX1-29, #588 merged as `566dc8b`; UXR-19) that repeats the label of the control that opened it and is its accessible name (`aria-labelledby`).

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

- CI produces screenshots of every protected route on the synthetic seed at 390 px and 1440 px, per role, as a CI artifact (IMPLEMENTED: UX1-14, #535, artifacts on every push to `recovery/main` since `e68ba84`; extended in UX2-2 PLANNED; axe on page content: UX1-18 IMPLEMENTED, #574 merged as `93f7423`). `uxa` reviews them against this file and records findings in `docs/agents/reports/UX_REVIEW.md`.
- Screenshots never contain real personal or health data and are never committed to `recovery/main`.

**Review procedure** (`uxa`, every run; IMPLEMENTED as a process from 2026-10-27):
1. **Find the change:** PRs merged or open since the last section that touch `src/app`, `src/components`, styles or e2e; new or changed briefs; open `ux` issues.
2. **Get the images:** the newest `ui-screenshots` artifact for `recovery/main` and for each open screen-changing PR, each unpacked into its own empty directory outside the repository. If the artifact cannot be downloaded (no artifact yet, or the session's network refuses the storage host), review from images already on a temporary branch, from a static reproduction of the layout, or from the code, and say which in the section. Never against the live project.
3. **Check every captured route and role** at 390 × 844 first, then 1440 × 900: (a) the three questions in order (§1); (b) one primary action per card (§2); (c) severity colours only where they belong (§3); (d) no internal codes, one name NAVORA, plain Swiss German (§4); (e) no horizontal scroll, next step in the first viewport, at most four facts per card (§5); (f) contrast, 44 px targets, focus, meaning not only in colour (§6); (g) tokens and components, no inline layout (§7); (h) regressions against the previous section.
4. **Rate and route:** severe and high → one issue each for the PO (`agents`, `agent:po`, `ux`, plus `ux:severe`); lower → the report. Anything about how a safety signal or safety-related state is shown → a request to `cra`; anything shown to a client, a referrer or outside the app, or any text `lca` fixed → a request to `lca`. Requests are listed in the report with one question each and stay OPEN until answered.
5. **Close with evidence:** a finding is closed only with a screenshot or test on `recovery/main` that shows the remedy.

## Change log

- 2026-10-28 15:48 CET (`uxa`): version 10. Status moved with the merges of #598 (`8d0e812`) and #602 (`f6277ab`): §3 list pointer line, urgency not red and team reach line IMPLEMENTED; guarding colour test IMPLEMENTED for `field-client.tsx` only; new OPEN rule: error lines are one component per screen (UXR-26). §4 no internal codes (scope `src/app`, `src/components`), one product name, one label per page, no eyebrow, correct compounds IMPLEMENTED; product name not a heading PLANNED (UX2-12). §6 focus after a dialog's content changes IMPLEMENTED; new OPEN rule: an attention state shown open keeps its line in the `summary` (UXR-27).
- 2026-10-28 11:49 CET (`uxa`): version 9. Status moved with the merge of #588 (`566dc8b`): §5 jump links for all three sections IMPLEMENTED; §6 dialog-pending rule (with the CGR-85 thrown-save clause) and visible dialog heading IMPLEMENTED. §4 internal codes and one product name noted in open PR #598; new rule "one label per page" (PLANNED, #598) with OPEN parts (product name not a heading, UXR-24; no eyebrow, UXR-22); correct compounds (UXR-23). §6 new OPEN rule: focus after a dialog's content changes (UXR-25).
- 2026-10-28 07:50 CET (`uxa`): version 8 (the header still read 6 after the 03:50 change; corrected). Status moved with the merge of #574 (`93f7423`) and the PO placements of 04:10 and 06:10: §5 "Zu erledigen" row in the first viewport and jump link for "Entscheid offen" IMPLEMENTED; other jump links PLANNED (UX1-30); new PLANNED rule: a returned report stays on her day until signed again (UX2-11, `cra`). §6 axe `color-contrast` and `SECONDARY_TEXT` IMPLEMENTED; axe on working states and `incomplete` from OPEN to PLANNED (UX2-10). §8 axe IMPLEMENTED.
- 2026-10-28 03:50 CET (`uxa`): version 7. §5 new rule: jump links carry the section heading's name (UX1-27 in #574; UXR-20 OPEN; NHS task-list benchmark). §6 axe and `SECONDARY_TEXT` noted as IMPLEMENTED in open PR #574 (PLANNED until merged); new OPEN clause: axe covers working states and records `incomplete` (UXR-21); dialog rules from OPEN to PLANNED (UX1-28, UX1-29).
- 2026-10-27 23:49 CET (`uxa`): version 6. Status moved with the merges of #554 and #558 (code, CI green; no screenshot seen): §2 one primary action and "Mehr" IMPLEMENTED on `/field`; §3 consequence actions not red and light-only `color-scheme` IMPLEMENTED; §4 long fixed texts IMPLEMENTED; §5 `/login` phone layout, next visit first, settings route, sign-out in the menu and header menus closing IMPLEMENTED; §6 class scan and dialog focus IMPLEMENTED. New OPEN rules in §6: a dialog that sends cannot be dismissed while sending (UXR-18) and has a visible heading (UXR-19).
- 2026-10-27 19:51 CET (`uxa`): version 5. Status moved with the merges of #535 and #532 and the placements of 16:25 and 18:10: §3 signal card PLANNED (UX2-9), list pointer and not-red rules PLANNED (UX1-22 to UX1-24); §4 long fixed texts PLANNED (UX1-21); §5 phone frame IMPLEMENTED, settings route PLANNED (UX1-20); §8 screenshot job IMPLEMENTED. New OPEN rules: §3 consequence actions not red (UXR-16), §5 header menus close (UXR-14), §6 dialogs manage focus (UXR-13) and contrast covers inline colours (UXR-15).
- 2026-10-27 15:50 CET (`uxa`): version 4. §3 safety-signal card updated with `cra`'s C-4 change ("one primary action first; no action removed"), two new rules from C-1, C-2 (a), C-3 (all OPEN; `cra` 13:37, PR #532 not merged); §2 consequence sentence (C-2 (b)) and a proposal-and-confirmation pattern (AIG1, PLAN3: PLANNED parts and OPEN `uxa` proposals); §5 reachability of safety-related settings (UXR-10) and the #535 phone frame (PLANNED until merged).
- 2026-10-27 11:49 CET (`uxa`): version 3. §4 pattern for long fixed information texts (from `lca`'s answer to L-1); §5 `/login` and §6 secondary text from OPEN to PLANNED (UX1-15, UX1-17/-18, PO 11:10).
- 2026-10-27 11:19 CET (`uxa`): version 2. §8 review procedure (owner 2026-10-27: continue the design system and the screenshot review); requests C-1 to C-4 to `cra` and L-1 to `lca` recorded in the UX review.
- 2026-10-27 10:42 CET (`uxa`): version 1. §3 dark-mode check answered from code (UXR-8) and the safety-signal card pattern (OPEN, from the benchmark; `cra` to confirm); §5 `/login` in the phone-first scope (UXR-1); §6 secondary-text contrast rule (UXR-2); §7 token and component proposal before UX2.
- 2026-10-27 10:40 CET (`po`): version 0 from the UX review of 2026-10-27 (#506-#510) and the owner's instruction (three questions, pilot adoption first-class).
