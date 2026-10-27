# UX Review Report

**Owner:** UX/UI Design Architect (`uxa`, owner 2026-10-27). **Process:** [`../README.md`](../README.md), *UX review*. **Reference:** [`../../design/DESIGN_SYSTEM.md`](../../design/DESIGN_SYSTEM.md).

Newest dated section first; never edit an earlier section, correct it in a new one. Each finding: `UXR-<n>` | screen and role | severity (`severe`, `high`, `medium`, `low`) | finding | evidence (CI screenshot artifact and commit, file:line) | principle broken (design system §) | testable remedy | issue.

---

## 2026-10-27 11:49 CET · `uxa`: `lca` answer to L-1 recorded

**What changed since 11:19.** `lca` answered request L-1 (UXR-3) in its D-23 re-check of 11:41, in PR #520 (`docs/agents/decisions/D-23.md`, merged into `recovery/main` as `647c14f` during this run). No screen code changed (`recovery/main` `39f90e5`, PO 11:45 #521 docs only; last screen change before `56d62e0`); open PRs: #502 (COND2-4, `team-client.tsx`, unchanged since my 10:42 review of head `19731a6`); #520 and #521 (docs only) merged during this run. No new `ui-screenshots` artifact (newest still from `tools/ui-screenshots`, 08:22 UTC; UX1-14 not built: OPEN). No `cra` answer yet to C-1 to C-4. No benchmark this run (made at 10:42). No new findings.

### `lca` answer to L-1 (UXR-3, `/work` working-time notice): confirm with change

Recorded as `lca` wrote it (D-23, 11:41, PR #520); the substance is `lca`'s and I do not reword it.

- Lead line and paragraph headings over the unchanged `work1-notice-v3` paragraphs: compliant on the sources `lca` read (draft, synthetic data), on three terms:
  1. Lead line without "Einmal" and without "bestätigen" (the acknowledgement is per version; "bestätigen" can read as consent). `lca` proposes: "Bitte lies diese Information und tippe dann auf «Gelesen und verstanden». Danach siehst du deinen Arbeitstag. Ändert sich die Information, zeigen wir sie dir noch einmal."
  2. Headings: "Wer deine Einsatzzeiten sieht" (§1), "Was nur du siehst" (§2, new), "Was NAVORA protokolliert und was die Administration sieht" (§3), "Was du tust (auch vor dem Ende deines Zugangs)" (§4, advised, not required), "Der Anteil für das ganze Team" (§5), "Was NAVORA nicht prüft" (§6).
  3. Lead line and headings are fixed text in `rules.ts` next to the paragraphs and part of the employer's final text; any other wording needs one `lca` look before merge. A new `NOTICE_VERSION` is not legally needed for this change (product choice).
- My proposal as written (five headings, "Einmal … bestätigen") is **not recommended** by `lca`. I withdraw it in favour of the `lca` wording.

**UX view of the `lca` wording (advisory).** The three-sentence lead line answers both questions UXR-3 raised (what do I do, what comes after) and says honestly when the notice returns; the third sentence also answers "will I see this every day?". The headings are longer than mine but each is accurate, and a nurse scanning them sees every recipient (her, the administration, the team). No objection. The Playwright criterion stays: the lead line and the first heading inside the first viewport at 390 × 844. With headings of this length, the first heading may only fit if the lead line is set as body text, not as a large heading: UNKNOWN until a screenshot exists (UX1-14).

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-3 | OPEN → ready for placement by the PO: `lca` confirm with change (D-23, 11:41, PR #520). Testable remedy now: words of `work1-notice-v3` unchanged; lead line and six headings exactly as `lca` 11:41, held in `rules.ts`; Playwright at 390 × 844 on `/work` before acknowledgement: lead line and first heading in the first viewport; a string test that each heading and the lead line equal the `rules.ts` constants. Stays OPEN until the PO places it. | PR #520 `D-23.md` |
| UXR-1, UXR-2, UXR-6, UXR-8, UXR-9 | PLANNED, unchanged (UX1-15 to UX1-19, UX1-7) | `briefs/UX1.md` |
| UXR-4, UXR-5, UXR-7 | OPEN, waiting for `cra` (C-1 to C-4, 11:19) | |

**For the PO.** UXR-3 can be placed (my suggestion: with UX1 part (c), the `/work` and `/field` text work, since it is presentation and fixed text only). The order is yours; I propose only.

---

## 2026-10-27 11:19 CET · `uxa`: owner approval, placement, requests to `cra` and `lca`

**What changed since 10:42.** Owner instruction in this session (2026-10-27): approves the `uxa` findings and recommendations; #515 is a pilot-readiness blocker to be placed ahead of non-critical UX improvements; #516 a high-priority accessibility and usability item; all UX findings run through the normal `agent:po` workflow; `uxa` coordinates with `cra` and `lca` where a finding needs confirmation; escalate only strategic decisions or roadmap trade-offs. PO 11:10 (#518) had already placed #515 and #516 (with UXR-6 and UXR-8) as **UX1 part (f)**, UX1-15 to UX1-19. Labels checked: #506-#510, #515, #516 all carry `agents`, `agent:po`, `ux` (severe ones also `ux:severe`); nothing to add. No screen code changed (`recovery/main` `72e6603`; `git diff 56d62e0 72e6603 -- src` empty); no new screenshot artifact. No new findings.

### Status of findings

| ID | Status | Evidence |
|---|---|---|
| UXR-1 | PLANNED (UX1-15, UX1-16) | `briefs/UX1.md` part (f), PO 11:10 |
| UXR-2 | PLANNED (UX1-17, UX1-18) | same |
| UXR-6 | PLANNED (UX1-19 (i)) | same |
| UXR-8 | PLANNED (UX1-19 (ii)) | same |
| UXR-9 | PLANNED (UX1-7) | PO 11:10 journal |
| UXR-3 | OPEN, waiting for `lca` (request L-1 below) | |
| UXR-4, UXR-5, UXR-7 | OPEN, waiting for `cra` (requests C-1 to C-4 below) | |

**Proposal to the PO on order inside UX1 (owner: #515 is a pilot-readiness blocker).** UX1 stays *Next up* 2; I do not reorder. Proposal only: build UX1-14 (screenshots) and UX1-15/UX1-16 (sign-in) in the first UX1 PR, together with part (a), so the sign-in fix does not wait for the `/field` work in (c) and (d), which needs the `cra` string review. Comment on #515.

### Requests to `cra` (Clinical & Regulatory Architect)

How a safety signal or a safety-related state is shown is `cra`'s to confirm (README *UX review*). Each request asks for one answer: **confirm**, **confirm with change**, or **reject with reason**. Nothing here changes a signal's rule, threshold, recipient, text or its position above other content.

| Request | Finding | Proposal (presentation only) | Question to `cra` |
|---|---|---|---|
| C-1 | UXR-4 | On `/team`, an entry in "Einsätze mit Handlungsbedarf" that is already shown as a P1 signal card at the top shows one line "Steht oben als Sicherheitssignal" instead of repeating the card; the clearance text ("Erledigt sich, sobald …", `team-client.tsx:204`) moves behind a disclosure "Wann erledigt sich das?" with its words unchanged. The signal cards stay first and unchanged. | May a P1 situation appear once on `/team` (the signal card) with a pointer in the list, or must the list repeat it in full? May the clearance text sit behind a disclosure? |
| C-2 | UXR-5 | (a) The intake urgency badge "hoch" changes from the red family to amber with the word kept (an intake urgency is not a P1 safety signal). (b) "Entfernen" on a planned visit becomes an outline button in the neutral text colour; its existing reason step stays and gains one sentence naming the consequence. | (a) Is a referral's urgency "hoch" a safety signal that must keep the signal colour? (b) Which sentence describes the consequence of removing a planned visit correctly (UNKNOWN to me; I do not write it)? |
| C-3 | UXR-7 | On `/team`, while fewer than all active members have "Benachrichtigung ausserhalb der App" on, the line is shown open in amber with a word ("Nicht alle erreichbar") and a link to "Meine Einstellungen"; when all are on it stays collapsed and neutral. | Is a team with members who do not receive P1 signals outside the app a state the team must see without expanding? Is amber (not the P1 colour) right for it? Does the word need a different wording? |
| C-4 | design system §3 safety-signal card (benchmark 10:42) | Each P1 card: the first line names the situation and its one action; a visually hidden prefix "Sicherheitssignal:" for screen readers; exactly one action per P1 card; text after a card gets its own heading. | May these four rules become acceptance criteria in a later brief (UX2 or UX3)? Is "Sicherheitssignal:" the right prefix? |

### Request to `lca` (Legal & Compliance Agent)

| Request | Finding | Proposal (presentation only) | Question to `lca` |
|---|---|---|---|
| L-1 | UXR-3 | The working-time information on `/work` (text fixed with `lca`, `work1-notice-v3`) keeps every word and stays a one-time acknowledgement before the first workday. Added: one lead line above it ("Einmal lesen und bestätigen, danach siehst du deinen Arbeitstag") and a short heading above each paragraph (e.g. "Wer deine Einsatzzeiten sieht", "Was NAVORA protokolliert", "Was du tust", "Was dein Team sieht", "Was NAVORA nicht prüft"). | Does adding a lead line and paragraph headings (words of the notice unchanged, nothing collapsed) keep the notice compliant with the information duty it serves? Are the proposed headings accurate summaries of their paragraphs, or must any be reworded? |

When `cra` or `lca` answers (in its report or on the `uxa` PR), `uxa` records the answer in the next section and the PO decides placement; findings stay OPEN until then.

---

## 2026-10-27 10:42 CET · `uxa` first review (baseline screens, code at `56d62e0`)

**Sources.** No `ui-screenshots` artifact exists for `recovery/main` (UX1-14 not built yet: OPEN). The two `ui-screenshots` artifacts that exist come from the temporary branch `tools/ui-screenshots` (code `6abf941`, synthetic seed, 2026-10-27 08:11 and 08:22 UTC); downloading the archive was refused by this session's network proxy, so I looked at the identical images committed on that temporary branch (`1907071`, folder `ui-screenshots/`), extracted outside the repository. `git diff 6abf941 56d62e0 -- src/app src/components` is empty, so these images still show `recovery/main`. Screens not in that set (login, `/teams`, `/visits`, `/partners`, `/admin` at 390 px) were reviewed from the code. The login layout was reproduced from its inline styles as a static page in Playwright at 390 × 844 (no app server, no Supabase). The live project was not touched. Open PR with screen changes: #502 (`team-client.tsx`, two fact lines under the RET1 review task, head `19731a6`), reviewed from the diff: no finding, so no comment.

**Lost U-codes.** U8 to U15 and U17 are not recoverable from the repository (UNKNOWN). Where a finding below probably re-finds one of them, I do not claim so; numbering starts at UXR-1.

### Findings

| ID | Screen and role | Severity | Finding | Evidence | Principle | Testable remedy | Issue |
|---|---|---|---|---|---|---|---|
| UXR-1 | `/login`, every role, phone | severe | IMPLEMENTED defect. The sign-in page is a fixed two-column grid (`1.05fr 0.95fr`, 56 px padding) with no breakpoint. At 390 px the page is 724 px wide and the sign-in form is entirely outside the first viewport; the inputs are about 131 px wide. The first screen a nurse sees on her phone shows a dark panel without a form. The page also addresses the wrong people ("Admin / Coach Portal", "Admin / Coach anmelden", although nurses sign in here and land on `/field`), uses first-MVP and English terms ("Attention Center", "Operations-Lage", "Teams Übersicht") and writes "Navora". Not covered by UX1 (a) (`/settings`, `/admin`, `/operations` only) and excluded from UX2 ("login page design beyond using the same tokens"). | `src/app/(auth)/login/page.tsx:21-30` (grid), `:51`, `:62`, `:75-76`, `:81-87`, `:127`; reproduction from these styles at 390 × 844: `scrollWidth` 724, form off-screen | §5 phone first; §4 language, one name NAVORA | Below 768 px one column, form first, the explanatory panel below or removed. Playwright at 390 × 844 on `/login`: `scrollWidth <= 390`; the e-mail input, the password input and "Anmelden" are inside the first viewport; each input at least 300 px wide. Heading addresses every user (e.g. "Bei NAVORA anmelden"); no "Admin / Coach", "Attention Center", "Teams Übersicht"; "NAVORA" in capitals. Sign-in logic unchanged. | #515 |
| UXR-2 | every Tailwind screen (`/field`, `/team`, `/work`, `/intake`), all roles | high | IMPLEMENTED defect. Secondary text is set with reduced opacity: `text-emerald-900/60` (32 uses), `/70` (23), `/50` (2). On white and on `stone-100` this gives roughly 2.6:1 (/50), 3.3:1 (/60) and 4.1-4.3:1 (/70), below the WCAG 2.2 AA minimum of 4.5:1 for normal text; most uses are `text-xs` or `text-sm`. These lines carry facts a nurse acts on ("noch niemand verantwortlich", the reason a visit was moved, "seit 26 h"). Ratios are my calculation with Tailwind's emerald-900 approximated as `#064e3b`; exact values with Tailwind v4's oklch palette: UNKNOWN until axe runs (UX2-8). | `grep text-emerald-900/(50,60,70)` under `src/app`, `src/components` (57 uses); e.g. `team-client.tsx:968`; screenshot `team-phone.png` (meta lines under the P1 cards) | §6 accessibility floor | One `text-secondary` token with at least 4.5:1 on every surface it is used on (proposal in §7: `stone-700` or `emerald-900` at ≥ 80 %); no text colour with opacity below 80 % for text under 18 px. Automated: axe `color-contrast` on every protected route in the screenshot job (UX1-14/UX2-8), serious and critical fail, not only on the shell. | #516 |
| UXR-3 | `/work`, nurse, phone, first use | medium | The working-time notice (fixed with `lca`, WORK1) fills the screen: about 1,050 px of continuous text before the only action "Gelesen und verstanden"; nothing tells her how long it is or that it appears once. The notice must stay; its scanability is the problem. | `work-phone.png`; `work-client.tsx:52-74` | §5 density; §1 (what do I do next) | Words unchanged. Proposal for `lca`: a one-line lead ("Einmal lesen und bestätigen, danach siehst du deinen Arbeitstag"), a short heading per paragraph (who sees what; what NAVORA logs; what you do; what the team sees; what NAVORA does not check). Playwright: the lead and the first heading are in the first viewport. `lca` must confirm any change of the notice's presentation. | report only |
| UXR-4 | `/team`, team member and coach, phone | medium | The same two P1 situations appear twice at the top: as safety-signal cards (SIG1 banner) and again in "Einsätze mit Handlungsbedarf" directly below, followed by a nine-line explanation in small red text of when each item clears. The first screen is spent on the same two facts and a rules paragraph; the team's own decisions ("Anfragen an dein Team", the clients) start far below. | `team-phone.png`, `team-phone-top.png`; `team-client.tsx:204`; `SignalBanner.tsx:57-69` | §1 three questions; §5 density; rule shown as reason, not lecture (roadmap) | No change to the signal cards, their position or text (`cra`). Proposal for `cra`: the "Handlungsbedarf" list collapses entries that are already shown as a signal card above ("auch oben als Sicherheitssignal") and the clearance explanation sits behind "Wann erledigt sich das?". Playwright at 390 px: "Anfragen an dein Team" heading moves up by at least the height of the duplicated entries. `cra` must confirm. | report only |
| UXR-5 | `/team`, `/intake`, every page (development banner) | medium | The red family reserved for P1 safety signals is also used for: "Entfernen" (red link and red submit) on planned visits; the urgency badge "hoch" at intake; the development banner on every page (`#7f1d1d`). Red then no longer means "safety signal". | `team-client.tsx:983`, `:998`; `intake-client.tsx:30`; `src/app/layout.tsx:36-45`; `intake-desktop-top.png`, `team-phone.png` | §3 reserved severity colours | Destructive actions: outline button in the neutral text colour plus the existing reason step that names the consequence; urgency badge with the word in amber or neutral (urgency of a referral is not a P1 signal; `cra` confirms); development banner in a neutral dark stripe with its text unchanged (SR-02/SR-07; its content stays Engineering's and `lca`'s). Unit test: the `signal-p1` colour classes appear only in signal components. | report only |
| UXR-6 | `/intake`, intake role, desktop | medium | IMPLEMENTED defect. In "Neue Anfrage erfassen" the "Ort" input sticks out of the form card; "Region" and "Ort" overlap. The two inputs sit in a two-column grid without `w-full min-w-0`, so they keep the browser's intrinsic width. | `intake-desktop-top.png`; `intake-client.tsx:171-178`, `:35` | §7 components (one input style); §5 | `field` class gains `w-full min-w-0`. Playwright at 1440 and 390: every input's right edge is at most the form's right edge. | report only |
| UXR-7 | `/team`, team member and coach | medium | "Benachrichtigung ausserhalb der App: 0 von 2 aktiv" is a collapsed, neutral line. That nobody in the team receives safety signals outside the app is shown at the weight of a footnote. | `team-phone.png`; `team-client.tsx:1023` | §1 (what needs attention now); §3 | Proposal for `cra` (how a safety-related state is shown is `cra`'s): while fewer than all active members have push on, the line is shown open, in amber, with a word ("Nicht alle erreichbar") and a link "Meine Einstellungen" to `/settings`. Playwright with the seed team (0 of 2): the link is visible without expanding. | report only |
| UXR-8 | every protected screen, phone in dark mode | low | First task "dark mode" (design system §3, UNKNOWN): **no defect found in code.** `globals.css` switches `body` to `#0a0a0a`/`#ededed` under `prefers-color-scheme: dark`, but every protected page root and the login page set their own background and text colour (`field-client.tsx:116`, `team-client.tsx:90`, `work-client.tsx:313`, `intake/page.tsx:14`, `analytics-client.tsx:33`, `admin-client.tsx:64`, `settings-client.tsx:86`, `operations-client.tsx:66-68`, `partners/page.tsx:15-17`, `login/page.tsx:24-28`). Residual risk: native form controls follow the system scheme because no `color-scheme: light` is declared. Not verified on a rendered page: UNKNOWN until a screenshot exists. | code as listed | §3 | Declare `color-scheme: light` on `:root` until a dark theme is designed; UX1-14 adds one capture of `/field` with `colorScheme: 'dark'`. | report only |
| UXR-9 | `/field`, nurse, phone | low | Above the fold three saturated action colours compete: red "Ich übernehme" (signal), blue "Ich kann nicht arbeiten", orange "Übernehmen". Part of #509 (UX1-6a, UX1-7); recorded so the UX1 screenshots are checked for it: after UX1 only the signal card keeps its own colour, every other filled button is the primary token. | `field-phone-top.png` | §2, §3 | UX1-7 plus: no filled button outside a signal card uses a colour other than `action-primary`. | #509 |

### Benchmark (2026-10-27): urgency cards in the NHS design system

Read on 2026-10-27: NHS digital service manual, *Care cards* ([service-manual.nhs.uk/design-system/components/care-cards](https://service-manual.nhs.uk/design-system/components/care-cards)). In my words: the NHS uses three card types for three levels of urgency. Colour supports the level, but the heading carries it: each heading is one plain call to action, and a visually hidden prefix tells screen-reader users the urgency. The most urgent card allows one action and no other links. Several cards on one page are allowed only when needed, ordered by seriousness, and text after a card gets its own heading so it is not read as part of the card.

What NAVORA should adopt, and why: (1) the safety-signal card's first line names the situation and the one action, and a hidden prefix ("Sicherheitssignal:") gives screen readers the level that sighted users get from colour (§3: never meaning only in colour); (2) a P1 card has exactly one action; (3) the same situation is not shown in two stacked cards (UXR-4); (4) a paragraph after a card gets its own heading. Items (1) to (3) concern how a safety signal is shown: `cra` must confirm before any brief uses them. Nothing is copied: no design, text or asset of the NHS.

### Design system changes in this run
Token proposal recorded in §7 (before UX2); dark-mode question answered from code (§3, UXR-8); text contrast rule for secondary text (§6); login added to the phone-first scope (§5); signal-card pattern added as OPEN (§3).

### Waiting for the PO
UXR-1 (severe, login at phone width) is not in any brief; UXR-2 (high, text contrast) is only partly in UX2-8 (axe on the shell). Both opened as issues for placement: #515 (UXR-1), #516 (UXR-2). Medium and low findings (UXR-3 to UXR-9) stay in this report; UXR-3, UXR-4, UXR-5 and UXR-7 need `cra` or `lca` before any brief uses them.

---

## 2026-10-27 10:40 CET · baseline (seeded by `po`, not a `uxa` review)

The UX review of 2026-10-27 (screenshots of `recovery/main` at `6abf941`, synthetic seed) used the codes U1 to U18; its severe findings are open as issues and placed by the PO. `uxa` takes them over as below and continues from **UXR-1**; the other U-codes of that review (U8 to U15, U17) are not in the repository: UNKNOWN, `uxa` re-finds them from CI screenshots instead of from memory.

| Earlier code | Issue | Severity | Placed in | Status |
|---|---|---|---|---|
| U1, U16, U18 | #510 | severe | UX2 (*Next up* 4) | PLANNED |
| U2 | #507 | severe | UX1 (b) | PLANNED |
| U3 | #506 | severe | UX1 (a) | PLANNED |
| U4 | #508 | severe | UX1 (d) | PLANNED |
| U5, U6, U7 | #509 | severe/high | UX1 (c) | PLANNED |

First tasks for `uxa`: (1) check the dark-mode question in design system §3 (UNKNOWN); (2) as soon as UX1-14 produces CI screenshots, a full baseline review of every protected route per role at 390 px and 1440 px; (3) propose tokens for design system §7 before UX2 starts; (4) a benchmark section (modern healthcare and SaaS products), described in words, with the patterns worth adopting and why.
