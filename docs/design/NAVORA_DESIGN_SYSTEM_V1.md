# NAVORA design system V1 (build specification)

**Owner:** UX/UI Design Architect (`uxa`) · **Date:** 2026-11-03 15:00 CET · **Version:** 1 · **For:** M2 to M8 of the Delivery Program (#832); issue #831 (component inventory, implementation-ready tokens) · **Status labels:** IMPLEMENTED · BUILT ON PR · PLANNED · OPEN · UNKNOWN.

**Relation to the other design files.** [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) holds the behaviour rules (three questions, action hierarchy, severity, language, accessibility floor), cited as **DS §n**; it stays the review contract. **This file is what Engineering builds:** the token values, the CSS, the component set with props, variants and states, and the phone and desktop systems. [`NAVORA_SCREEN_CATALOG.md`](NAVORA_SCREEN_CATALOG.md) says which component each screen uses; [`NAVORA_INFORMATION_ARCHITECTURE.md`](NAVORA_INFORMATION_ARCHITECTURE.md) the navigation. Where this file and DS differ, DS wins and the difference is a finding.

**What exists today (code on `2981ad5`):** no token set. `globals.css` defines only `text-secondary` (stone-700) and `color-scheme: light`; `body` sets `font-family: Arial` although Geist Sans is loaded in `layout.tsx`; nurse screens use raw Tailwind palette classes (emerald, stone, amber, rose, sky), first-MVP screens inline hex (`#f4f7f4`, `#153328`). There is no `src/components/ui`. UX2-3 (PLANNED) is the build item for §2 and §5; UX2-4 removes inline styles.

---

## 1. Principles that decide every value below

1. **Severity colour is reserved.** Rose only for P1 safety signals; amber only for "needs action today, not a safety signal". No brand, action, error or destructive element uses either (DS §3, UX2-13).
2. **Calm by default.** Most of a care screen is neutral; colour marks the few things that need her.
3. **One way per thing.** One button set, one card, one error line, one notice. A new screen composes existing components; a new component needs a line in this file first.
4. **Phone first, one hand, gloves and glare.** 16 px body, 44 px targets (56 px for the main lifecycle step), high contrast, no hover-only meaning.
5. **Words carry meaning.** Every colour has a word or icon; every icon has a text label.

---

## 2. Tokens

### 2.1 Colour (semantic). Values are Tailwind palette hex; contrast computed against the named background (WCAG 2.x formula; axe in CI confirms, UX2-8)

| Token | Value | Use | Contrast (pair) | Never |
|---|---|---|---|---|
| `surface-page` | `#f5f5f4` (stone-100) | page background (app) | – | cards |
| `surface-card` | `#ffffff` | cards, sheets, dialogs, inputs | – | page background |
| `surface-sunken` | `#fafaf9` (stone-50) | `info` notices, table header, read-only fields | – | – |
| `border-subtle` | `#d6d3d1` (stone-300) | card outline, dividers (decorative) | 1.49:1 on white (decorative only) | input or control borders |
| `border-control` | `#78716c` (stone-500) | input, select, checkbox, outline-button borders | 4.80:1 on white (≥ 3:1, WCAG 1.4.11) | text |
| `text-primary` | `#022c22` (emerald-950) | body text, headings | 15.15:1 white; 13.89:1 stone-100 | – |
| `text-secondary` | `#44403c` (stone-700) | meta lines, reasons, times | 10.27:1 white; 9.42:1 stone-100; ≥ 9.3:1 on every tint below | opacity < 80 % |
| `text-on-brand` | `#ffffff` | text on `brand` | 15.15:1 | – |
| `brand` | `#022c22` (emerald-950) | sidebar, website header band, product name | – | buttons |
| `action-primary` | `#065f46` (emerald-800), text white | the one filled button | 7.68:1 | a second filled button in the same card |
| `action-primary-hover` | `#064e3b` (emerald-900) | hover / pressed of `action-primary` | 9.72:1 | – |
| `action-outline` | bg `#ffffff`, border `border-control`, text `text-primary` | secondary and pre-confirm destructive actions | 15.15:1 | – |
| `action-outline-hover` | bg `#f5f5f4` | hover / pressed | – | – |
| `link` | `#065f46` (emerald-800), underline 1 px offset 4 px | text links | 7.68:1 on white | colour as the only link cue |
| `focus-ring` | `#047857` (emerald-700), 2 px, offset 2 px; on `brand`: `#ffffff` | every interactive element | 5.48:1 on white; 5.03:1 on stone-100 | removal without replacement |
| `signal-p1-bg` / `-border` / `-text` / `-action` | `#fff1f2` / `#be123c` / `#881337` / `#9f1239` (rose-50/700/900/800) | P1 safety-signal card only (`cra` owns its look) | text 8.71:1 on bg; white on action 8.02:1 | anything else |
| `attention-bg` / `-border` / `-text` | `#fffbeb` / `#92400e` / `#92400e` (amber-50/800/800) | needs action today; `ErrorLine`; billing or quality hold state | 6.84:1 | safety signals |
| `info-bg` / `-border` / `-text` | `#fafaf9` / `#d6d3d1` / `#44403c` | neutral status, empty state, "not available yet" | 9.84:1 | warnings |
| `success-bg` / `-text` | `#ecfdf5` / `#065f46` (emerald-50/800) | confirmed, done, sent | 7.29:1 | – |
| `proposal-bg` / `-border` / `-text` | `#f0f9ff` / `#075985` / `#0c4a6e` (sky-50/800/900) | a value proposed by an assistant, until confirmed (DS §2; with the words "vorgeschlagen von …") | 8.87:1 | anything confirmed |
| `overlay` | `rgba(28,25,23,0.5)` | behind dialogs and sheets | – | – |

Dark mode: **not in scope** for M2 to M8 (DS §3: light only, `color-scheme: light`). A dark theme needs its own contrast pass and `cra` for the signal colours (OPEN after M8).

### 2.2 Typography

- **Family:** Geist Sans (already loaded, `--font-geist-sans`), fallback `system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif`. **Fix:** `body` must use `var(--font-sans)` instead of Arial (deviation today). Numbers in tables and times: `font-variant-numeric: tabular-nums`.
- **Scale (app):**

| Token | Size / line height | Weight | Use |
|---|---|---|---|
| `text-meta` | 12 / 16 px | 400 | timestamps beside a fact; never the only carrier of a fact she acts on |
| `text-small` | 14 / 20 px | 400, 600 | secondary lines, badges, table cells |
| `text-body` | 16 / 24 px | 400 | body, inputs (16 px prevents iOS zoom) |
| `text-card-title` | 18 / 26 px | 600 | card title (client display name) |
| `text-section` | 20 / 28 px | 700 | section heading (`h2`) |
| `text-page` | 24 / 32 px | 700 | page heading (`h1`) |

- Weights: 400, 600, 700 only. No all-caps headings (today `uppercase tracking-wide` on `/team` sub-headings: replace with `text-small` 600).
- Line length: body max 72 characters (`max-w-prose`).

### 2.3 Spacing, radius, elevation, sizing

| Group | Tokens |
|---|---|
| Spacing (4 px base) | `1`=4, `2`=8, `3`=12, `4`=16, `5`=20, `6`=24, `8`=32, `10`=40, `12`=48, `16`=64 px (Tailwind default scale; no other values) |
| Gutters | page gutter 16 px (< 768), 24 px (768–1279), 32 px (≥ 1280); gap between cards 12 px; between sections 24 px; inside a card 16 px |
| Radius | `radius-control` 8 px (buttons, inputs, badges 6 px); `radius-card` 16 px; `radius-sheet` 16 px top corners; `radius-pill` 9999 px (count chip only) |
| Elevation | `shadow-card`: `0 1px 2px rgba(28,25,23,0.06)`; `shadow-raised` (tab bar, sticky bars, menus): `0 -1px 0 #d6d3d1` on top edge for the tab bar, `0 4px 16px rgba(28,25,23,0.12)` for menus and sheets; `shadow-dialog`: `0 12px 32px rgba(28,25,23,0.24)`. No coloured shadows |
| Targets | `target-min` 44 px (`min-h-11`, `min-w-11`); `target-main` 56 px for the visit card's primary lifecycle step and the tab bar items; 8 px between adjacent targets |
| Z-index | `z-sticky` 20 (sticky headers, bulk bar), `z-tabbar` 40, `z-menu` 50 ("Mehr", header menus), `z-sheet` 60, `z-dialog` 70 (native `<dialog>` top layer), `z-banner` 80 (connection banner) |

### 2.4 Motion

| Token | Value | Use |
|---|---|---|
| `duration-fast` | 120 ms | hover, pressed, focus ring |
| `duration-base` | 200 ms | expand/collapse of a section, menu open |
| `duration-sheet` | 240 ms | bottom sheet in/out |
| `ease-standard` | `cubic-bezier(0.2, 0, 0, 1)` | all of the above |

`prefers-reduced-motion: reduce` sets every duration to 0 ms. Nothing animates a safety signal (no pulse, no shake, no auto-scroll to it); focus is moved instead where a rule asks (DS §6).

### 2.5 Breakpoints

| Name | Min width | What changes |
|---|---|---|
| base | 0 | one column; tab bar; full-width buttons in forms |
| `sm` | 640 px | form field pairs side by side (DS §5) |
| `md` | 768 px | **shell switch**: sidebar instead of tab bar (UX2-1) |
| `lg` | 1024 px | two-column layouts (C-11, O-01 list-detail, O-04) |
| `xl` | 1280 px | page gutter 32 px; max content widths apply |

Reference viewports: 390 × 844 (phone, first) and 1440 × 900 (desktop), as the screenshot job (UX1-14).

### 2.6 The CSS the build consumes (proposal for UX2-3, `src/app/globals.css`)

```css
@import "tailwindcss";

:root { color-scheme: light; }

@theme inline {
  --font-sans: var(--font-geist-sans), system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
  --font-mono: var(--font-geist-mono), ui-monospace, monospace;
}

@theme {
  /* surfaces and text */
  --color-surface-page: #f5f5f4;
  --color-surface-card: #ffffff;
  --color-surface-sunken: #fafaf9;
  --color-border-subtle: #d6d3d1;
  --color-border-control: #78716c;
  --color-text-primary: #022c22;
  --color-text-secondary: #44403c;
  --color-brand: #022c22;
  /* actions */
  --color-action-primary: #065f46;
  --color-action-primary-hover: #064e3b;
  --color-link: #065f46;
  --color-focus: #047857;
  /* states */
  --color-signal-p1-bg: #fff1f2;
  --color-signal-p1-border: #be123c;
  --color-signal-p1-text: #881337;
  --color-signal-p1-action: #9f1239;
  --color-attention-bg: #fffbeb;
  --color-attention: #92400e;
  --color-info-bg: #fafaf9;
  --color-info: #44403c;
  --color-success-bg: #ecfdf5;
  --color-success: #065f46;
  --color-proposal-bg: #f0f9ff;
  --color-proposal-border: #075985;
  --color-proposal: #0c4a6e;
  /* type */
  --text-meta: 0.75rem;   --text-meta--line-height: 1rem;
  --text-small: 0.875rem; --text-small--line-height: 1.25rem;
  --text-body: 1rem;      --text-body--line-height: 1.5rem;
  --text-card-title: 1.125rem; --text-card-title--line-height: 1.625rem;
  --text-section: 1.25rem;     --text-section--line-height: 1.75rem;
  --text-page: 1.5rem;         --text-page--line-height: 2rem;
  /* shape */
  --radius-control: 0.5rem;
  --radius-card: 1rem;
  --shadow-card: 0 1px 2px rgb(28 25 23 / 0.06);
  --shadow-raised: 0 4px 16px rgb(28 25 23 / 0.12);
  --shadow-dialog: 0 12px 32px rgb(28 25 23 / 0.24);
  /* motion */
  --ease-standard: cubic-bezier(0.2, 0, 0, 1);
}

body {
  background: var(--color-surface-page);
  color: var(--color-text-primary);
  font-family: var(--font-sans);
}

@utility text-secondary { color: var(--color-text-secondary); }

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { transition-duration: 0ms !important; animation-duration: 0ms !important; }
}
```

**Guarding tests (PLANNED with UX2-3, extend UX1-17 / UX2-13 scans):** (1) no raw palette class (`emerald-`, `stone-`, `amber-`, `rose-`, `sky-`, hex) under `src/app/(protected)` and `src/components` outside `src/components/ui` and `src/components/signals`; (2) no `rose` token outside `SignalCard`; (3) no inline `style` except documented computed values (UX2-4).

---

## 3. Mobile-first system (390 px)

### 3.1 Page frame

```text
┌──────────────────────────── 390 ────────────────────────────┐
│ [ConnectionBanner, only when offline]                  z 80 │
│ PageHeader  h1 · context line · page links          16 px gutter
│ ─ Jetzt ─      SignalCard / Notice(attention)               │
│ ─ Zu erledigen ─ JumpRow                                     │
│ ─ Als Nächstes ─ Card with one filled action                 │
│ ─ Später ─     Section (count) …                             │
│                                                             │
│ (content padding-bottom = 56 px + safe-area)                │
├─────────────────────────────────────────────────────────────┤
│ TabBar 56 px + env(safe-area-inset-bottom)          z 40     │
└─────────────────────────────────────────────────────────────┘
```

- One column; cards full width minus 16 px gutters; 12 px between cards.
- **Scroll padding:** `html { scroll-padding-top: <sticky header height>; scroll-padding-bottom: calc(3.5rem + env(safe-area-inset-bottom) + 8px); }` below 768 px, so a focused control is never under a bar (UX2-31 (2), WCAG 2.4.11).
- **Thumb zone:** the primary action of a card is its last row, full width; destructive and rare actions sit behind "Mehr" (DS §2).
- **Page header** is not sticky on phone (it would eat height); only `BulkConfirmBar` and the tab bar are fixed.

### 3.2 Inputs on the phone

| Field | `type` / `inputmode` | `autocomplete` | Notes |
|---|---|---|---|
| E-Mail | `email` | `email` / `username` | – |
| Passwort | `password` | `current-password` | show-password toggle, 44 px |
| Uhrzeit | `time` | off | 5-minute step where the rule prefills (VIS1-3c) |
| Datum | `date` | off | min/max from the rule (e.g. PLAN3 today to +14) |
| Minuten | `text` + `inputmode="numeric"` + `pattern="[0-9]*"` | off | unit in the label ("Minuten") |
| Freitext (Beobachtung, Grund) | `textarea`, min 3 rows, auto-grow | off | `maxlength` with a visible counter from 80 % |
| Telefon (website) | `tel` | `tel` | – |

Labels above the field, never placeholder-only; hint under the label, before the field; error under the field (DS §4). Every field `w-full min-w-0`.

### 3.3 Overlays on the phone

- **Dialog** (native `<dialog>`, `showModal()`): for a step that must finish or be cancelled (absence, confirm steps that are not in place). Full width minus 16 px, max height 90 dvh, scrolls inside, heading visible.
- **Bottom sheet:** for choosing from a list (person picker on "Ändern", "Mehr" on a card). Opens from the bottom, 16 px top radius, drag handle is decoration only (a "Schliessen" button exists), focus moves into it, Escape and outside tap close it, focus returns to the opener.
- **Never** a toast for an outcome she must know (a result is a `role="status"` line where she acted, DS §2 "one command, one result display").

### 3.4 Installable app (PLANNED, MOB1; `eng` decides the delivery form in M1)

| Manifest key | Value |
|---|---|
| `name` / `short_name` | "NAVORA" / "NAVORA" |
| `start_url` | `/field` (team members); a coordinator who installs it starts on `/` and is redirected to her home |
| `scope` | `/` |
| `display` | `standalone` |
| `background_color` | `#f5f5f4` |
| `theme_color` | `#022c22` |
| `lang` | `de-CH` |
| `icons` | 192 and 512 px PNG plus a maskable 512 px; the word mark "N" on `brand` (asset OPEN, `uxa` provides with UX2) |

Status bar: `theme-color` meta `#022c22`. iOS: `apple-mobile-web-app-capable`, `apple-touch-icon` 180 px. Push on the installed app follows D-33.

### 3.5 Offline and slow connection (PLANNED, M6)

- `ConnectionBanner` when `navigator.onLine` is false or a command fails with a network error.
- Each command keeps its idempotency key (existing pattern) and its entered values; the card shows "Wird gesendet …"; after success one `role="status"` "Gesendet."; after a refusal the server's reason on the card.
- Nothing is shown as done before the server confirms it. Reads that failed show `ErrorLine` + `RetryBlock`, never stale data as current (a stale read must show its time: "Stand 08:12").

---

## 4. Responsive desktop system

| Area | Rule |
|---|---|
| Shell | sidebar 256 px fixed width, `brand` background, items 44 px; content area `surface-page` |
| Content widths | **reading** pages (C-01, C-02, C-12, C-13, C-14, A-04, O-03, O-05 text): one column max 720 px, left-aligned to the sidebar with 32 px gutter; **work** pages (C-11, O-01, O-04, O-06, O-07): max 1120 px |
| Two columns (≥ 1024) | C-11: left 560 px (Jetzt, Als Nächstes), right flexible (clients); O-01: list 400 px + detail flexible (list-detail, selection in the URL); O-04: lists left, form right 400 px; O-06: sticky in-page section nav 220 px + content |
| Signals | span the full content width above both columns; never inside a column that can scroll away |
| Tables | `DataTable` only on desktop for comparable rows (O-02 health, O-07 capacity, O-05 figures); below 1024 px the same data as `ListRow`s; sticky header row; numbers right-aligned, `tabular-nums`; no sort by person (there is no person column) |
| Hover | adds feedback only (`action-outline-hover`, row hover `surface-sunken`); no meaning or action appears on hover only |
| Keyboard | every action reachable in DOM order; `Escape` closes menus, sheets, dialogs; no single-key shortcuts (WCAG 2.1.4) |
| Density | same type scale as phone (no smaller desktop type); spacing may use 24 px between sections |

---

## 5. Component system

**Location (PLANNED, UX2-3):** `src/components/ui/<Component>.tsx`, one file each, pure presentational (no Supabase, no queries), with a vitest/RTL test per variant and state. Existing pieces are re-used, not duplicated: `AppShell`, `PageFrame` (#799), `SignalBanner`, `CommandError`, `OverlapNote`, `confirm-step.tsx`, `error-text.tsx`.

**State columns:** D default · H hover · F focus · A active/pressed · Di disabled · L loading · E empty · Er error. "–" = not applicable.

### 5.1 Inventory

| # | Component | Variants | States (D H F A Di L E Er) | Tokens | Accessibility | Used on | Status |
|---|---|---|---|---|---|---|---|
| 1 | `AppShell` | phone, desktop | D F; Er (membership read failed → settings only) | brand, surface-page, focus-ring | one `nav` "Hauptmenü"; `aria-current` | all app | BUILT ON PR #799 |
| 2 | `TabBar` | 1–4 columns | D H F A | surface-card, border-subtle, text-primary, target-main | 4 px bar + bold on current; labels always visible | all app < 768 | BUILT ON PR #799 |
| 3 | `Sidebar` | – | D H F A | brand, text-on-brand | product name not a heading | all app ≥ 768 | BUILT ON PR #799 |
| 4 | `MoreMenu` | tab "Mehr", card "Mehr" (sheet) | D F A; L (action pending) | surface-card, shadow-raised | Escape, outside tap, close on choice; focus return | shell, C-03 | IMPLEMENTED (card "Mehr"); shell on #799 |
| 5 | `PageHeader` | with/without back link, with page links, with `DateNav`/`MonthNav`/`WeekNav` | D | text-page, text-secondary | one `h1` = page label (UX2-12) | all app | PLANNED |
| 6 | `BackLink` | – | D H F A | link | "‹ Zurück zu …" text, 44 px | C-12, C-13, C-15, C-17, O-02, O-03 | IMPLEMENTED (C-13) |
| 7 | `DateNav` / `MonthNav` / `WeekNav` | day, month, ISO week | D H F A Di (no further) | action-outline | `nav` "Tag wählen"; current as text, not a link | C-01, C-02, C-14, O-05, O-07 | IMPLEMENTED (day, month); week PLANNED |
| 8 | `Button` | `primary`, `outline`, `link`, `signal` (only inside `SignalCard`) | D H F A Di L | action-primary(-hover), action-outline(-hover), focus-ring, radius-control, target-min / target-main | L: label "… wird gespeichert", `aria-busy`; disabled keeps 4.5:1 text | all | PLANNED (component); pattern IMPLEMENTED |
| 9 | `ConfirmStep` | in place (default), in dialog | D F; L (Abbrechen disabled while sending); Er | surface-card, text-body | focus to its sentence; action first, "Abbrechen" second, not at the opener's position | C-03 "Mehr", O-06 switches, C-04 signing | IMPLEMENTED (`confirm-step.tsx`) |
| 10 | `Dialog` | form, notice | D F L Er | surface-card, shadow-dialog, overlay | native `<dialog>`; visible heading = opener label; not dismissible while sending | C-06 | IMPLEMENTED |
| 11 | `BottomSheet` | list picker, actions | D F L E | surface-card, radius-sheet, shadow-raised | as Dialog; "Schliessen" button | person picker ("Ändern"), C-03 "Mehr" on phone | PLANNED |
| 12 | `Card` | plain, with header badge | D F (when the whole card is a link) E | surface-card, border-subtle, radius-card, shadow-card | title `h2`/`h3` per page outline; ≤ 4 facts before the action | all | PLANNED (component) |
| 13 | `VisitCard` | collapsed, expanded, locked (signed), other day | D F L Er; state badge per lifecycle | Card + Badge + Button(target-main) | unique accessible name incl. ordinal when names collide (VIS2-3) | C-01, C-02 | IMPLEMENTED (inline in `field-client.tsx`); extract PLANNED |
| 14 | `SignalCard` | P1 (only) | D F; Er (read failed: never hidden) | signal-p1-* | hidden prefix "Sicherheitssignal:"; first line names the situation; one primary first; content `cra` | C-01, C-11, O-01 | IMPLEMENTED (`SignalBanner`); UX2-9 PLANNED |
| 15 | `Notice` | `info`, `attention`, `success`, `proposal` | D; dismissible only for `info` (A-06) | *-bg, *-border, *-text | icon + word; `role="status"` only for results, not for static notices | all | PLANNED (component) |
| 16 | `ErrorLine` | inline (in card), section (read failed) | Er | attention-* | `role="alert"`; word "Fehler" + reason; one per screen look (UX2-14) | all | IMPLEMENTED (`error-text.tsx` on #806, `CommandError`) |
| 17 | `RetryBlock` | – | D F L Er | action-outline | button stays rendered and disabled "Wird geladen …"; result in one `role="status"` container (UXR-82) | O-06, every failed read | BUILT ON PR #813 (focus rule OPEN) |
| 18 | `LoadingLine` | inline text, skeleton rows (lists ≥ 3 rows) | L | text-secondary, surface-sunken | `aria-busy` on the region; skeleton has no animation under reduced motion | client reads | PLANNED |
| 19 | `EmptyState` | section, page | E | info-* | one sentence + one next step | all lists | PLANNED (component) |
| 20 | `Section` | static, collapsible (`details`), with count | D H F A E | text-section, border-subtle | `summary` 44 px; a safety line stays outside the fold (DS §6) | all | IMPLEMENTED (pattern) |
| 21 | `JumpRow` | – | D F E (hidden at 0) | link, text-small | section names as constants; words + count | C-01 | IMPLEMENTED |
| 22 | `ListRow` | read, with one action, as link | D H F A Di | surface-card, border-subtle | whole row a link only when it has no other control | C-07, C-12, O-02, O-03 | PLANNED (component) |
| 23 | `Badge` | status word, urgency word, count | D | info/attention/success tints, radius 6 px, text-small 600 | word always; never colour alone | all | IMPLEMENTED (`URGENCY_BADGE_CLASS`); component PLANNED |
| 24 | `CountChip` | in links and tabs | D | radius-pill, text-small | visible "(n)" up to 99, "99+" above; `aria-label` with exact number | C-11 "Vorschläge (n)" | PLANNED (PLAN3-12) |
| 25 | `FormField` | text, email, password, time, date, number, textarea, select | D H F Di Er; L (form sending) | surface-card, border-control, radius-control, text-body | label above; hint before; error under with `aria-describedby`; 16 px text | all forms | PLANNED (component) |
| 26 | `CheckboxRow` / `RadioRow` | single, in `fieldset` | D H F A Di Er | border-control, focus-ring | whole 44 px row is the label; no "select all" in proposal lists | C-12, C-17, W-07, presets | IMPLEMENTED on #787; component PLANNED |
| 27 | `PresetReason` | preset + "Anderer Grund" | D F Di Er | RadioRow + FormField | neither preselected; free text only after "Anderer Grund" | ASM1-C6 void (#815) | BUILT ON PR #815 |
| 28 | `ProposalLine` | single value, PLAN3 assignment | D F L Er; states proposed / confirmed / changed / rejected / expired / not open | proposal-*, Button | "vorgeschlagen von <Assistent>"; refused reason on the line | C-12, C-17 | IMPLEMENTED (AIG1) |
| 29 | `BulkConfirmBar` | – | D Di (0 ticked) L Er | surface-card, shadow-raised, Button primary | sticky bottom above the tab bar; label names the count | C-12, C-17 | IMPLEMENTED (inline) |
| 30 | `ProvenanceLine` | proposed, confirmed, changed | D | text-secondary | "bestätigt von <Name> am <Datum>" | C-13 | IMPLEMENTED |
| 31 | `IntentList` | – | D H F A L Er | Button outline, target-main | each intent a button; answer region `role="status"` | C-15 | PLANNED (M6) |
| 32 | `Figure` / `FigureGroup` | value, suppressed ("zu wenig Daten"), hidden (small team) | D E | text-page (value), text-secondary (base) | value + period + base always; no colour scale, no rank (AN3-5) | O-05 | IMPLEMENTED (pattern); AN3 PLANNED |
| 33 | `DataTable` | read-only | D H E L Er | surface-card, surface-sunken (header), border-subtle | `caption`, `th scope`; phone fallback `ListRow` | O-02, O-05, O-07 | PLANNED |
| 34 | `CapacityGrid` | week × team | D E L Er | DataTable + attention-* for gaps with words | gap is "offen <n>", not colour | O-07 | PLANNED (M8) |
| 35 | `ExceptionRow` | single, grouped (OPS2) | D H F A | Card/ListRow, attention for due | kind in words, age, next step | O-01 | IMPLEMENTED (exception centre); grouping PLANNED |
| 36 | `ConnectionBanner` | offline, sending | D L | attention-* | `role="status"` on change only | all app (M6) | PLANNED |
| 37 | `InstallPrompt` | Chromium, iOS instructions | D F; dismissed | Notice(info) | dismissible; never above signals | C-01 (M6) | PLANNED |
| 38 | `SafetyAlertForm` | – | D F L Er | as built; signal look `cra` | fieldset per category | C-10 | IMPLEMENTED |
| 39 | `BillingPreview` | per team | D E | Card, DataTable | – | C-11, O-01 | IMPLEMENTED |

### 5.2 Component specs (the ones every screen uses)

**Button**
```ts
type ButtonProps = {
  variant: "primary" | "outline" | "link";
  size?: "default" | "main";        // main = 56 px, the visit card's lifecycle step only
  pending?: boolean;                 // sets aria-busy, disables, shows pendingLabel
  pendingLabel?: string;             // e.g. "Wird gespeichert …"
  fullWidth?: boolean;               // default true below sm inside forms and cards
} & React.ButtonHTMLAttributes<HTMLButtonElement>;
```
Classes (primary): `inline-flex min-h-11 items-center justify-center rounded-control bg-action-primary px-4 text-body font-semibold text-white hover:bg-action-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus disabled:opacity-60`. Outline: `bg-surface-card border border-border-control text-text-primary hover:bg-surface-page`. Link: `text-link underline underline-offset-4 min-h-11`. **Rules:** one `primary` per card or section; no red or amber button outside `SignalCard`; a destructive action is `outline` and opens `ConfirmStep`.

**Card / VisitCard**
```ts
type VisitCardProps = {
  visit: FieldVisit;                 // existing row type
  expanded: boolean;
  ordinal?: { i: number; n: number };// VIS2-3, only when names collide
  primary: { label: string; command: string } | null;
  more: Array<{ label: string; consequence: string }>;
};
```
Anatomy: header row (time window `text-small` 600 · client display name `text-card-title` · state `Badge`) → facts (≤ 4, `dl`) → safety lines (from `cra`-owned components) → primary `Button size="main"` full width → row "Mehr" + "Zeiten ansehen" → sections (Seit deinem letzten Einsatz, Beobachtungen, Bericht, Qualität) as `Section` collapsible with 44 px summaries and anchors (`#uebergabe-<id>`, `#bericht-<id>`).

**Notice**
```ts
type NoticeProps = { tone: "info" | "attention" | "success" | "proposal"; title?: string; action?: React.ReactNode; live?: boolean };
```
Anatomy: 4 px left border in the tone's border colour, icon (decorative, `aria-hidden`) + word (e.g. "Hinweis", "Zu erledigen", "Erledigt", "Vorschlag"), text, at most one action. `live` adds `role="status"` (only for results that arrive after an action).

**ErrorLine** — `role="alert"`, `attention` tone, starts with the word "Fehler:", then the server's reason; placed in the card or section that failed; for a failed read followed by `RetryBlock`.

**Section**
```ts
type SectionProps = { id: string; title: string; count?: number; collapsible?: boolean; defaultOpen?: boolean; pinned?: React.ReactNode /* safety line kept outside the fold */ };
```
`count` shown as "(n)" in the heading; `collapsible` renders `details/summary` with `summary` ≥ 44 px; `pinned` renders above the `details`.

**FormField**
```ts
type FormFieldProps = { label: string; hint?: string; error?: string; required?: boolean; counter?: { max: number } } & ({ as: "input"; type: string } | { as: "textarea" } | { as: "select"; options: Array<{ value: string; label: string }> });
```
Label `text-small` 600 above; hint `text-small text-secondary`; control `min-h-11 w-full min-w-0 rounded-control border-border-control bg-surface-card px-3 text-body`; error `text-small text-attention` with icon, linked by `aria-describedby`; required marked "(nötig)" in the label (as built on `/field`), not with an asterisk only.

**EmptyState** — `info` tone, one sentence on what is empty and why if known, one next step (link or button). Never "keine" for a failed read.

**RetryBlock** — after an `ErrorLine` for a read: `Button outline` "Erneut laden"; while reading the button stays rendered, disabled, "Wird geladen …"; loading and result in one `role="status"` container; focus stays on the button (UXR-82).

---

## 6. Marketing extension (website, M5)

The website uses the same colour tokens, family and focus ring; it adds a display scale, wider layout and marketing components. **No app component with data is embedded**; screenshots are images of the synthetic seed.

### 6.1 Additional tokens

| Token | Value | Use |
|---|---|---|
| `text-display` | 40 / 48 px (phone 32 / 40) 700 | hero `h1` |
| `text-lead` | 20 / 30 px (phone 18 / 28) 400 | hero and page lead |
| `text-h2-marketing` | 28 / 36 px (phone 24 / 32) 700 | section headings |
| `section-space` | 96 px desktop / 56 px phone | vertical space between page sections |
| `content-max` | 1200 px; text blocks max 680 px | page container |
| `surface-tint` | `#ecfdf5` (emerald-50) | alternating section background |
| `surface-brand` | `#022c22` | CTA band, footer (text white 15.15:1) |

Severity colours do not appear on the website (no rose, no amber), except inside a screenshot.

### 6.2 Marketing components

| Component | Variants | States | Notes |
|---|---|---|---|
| `SiteHeader` | desktop, phone (menu panel) | D H F A; menu open | sticky, 64/56 px, "Demo anfragen" primary, "Anmelden" link (IA §3.3) |
| `SiteFooter` | – | D H F | `surface-brand`, link groups, language switch |
| `Hero` | with screenshot, text only | D | one `h1`, lead, two CTAs (primary + outline) |
| `FeatureBlock` | image left/right, stacked (phone) | D | title `h2`/`h3`, two lines, link; optional `StatusTag` |
| `StatusTag` | "In Vorbereitung", "Pilot", "Designpartner gesucht" | D | `info` style, word always; text `lca` |
| `ClaimNote` | hypothesis, source | D | "Hypothese:" prefix + source line; `lca` |
| `ScreenshotFrame` | phone 390, desktop 1440 | D | image of the synthetic seed; caption; alt text describes the function |
| `CtaBand` | – | D | `surface-brand`, one sentence, "Demo anfragen" (on brand: white button with `brand` text, 15.15:1) |
| `DemoForm` | – | D F L Er; success → W-08 | `FormField`s, `CheckboxRow` consent, honeypot hidden from assistive tech (`aria-hidden`, `tabindex=-1`) |
| `FaqList` | – | D H F A | `details/summary`, 44 px |
| `LanguageSwitch` | DE / EN | D H F A | `lang` attribute per link; keeps the equivalent page |

Images: no photo of a real client; people photos only as licensed stock clearly not depicting clients (OPEN, `lca` on stock use in a care context); illustrations preferred.

---

## 7. Content patterns (summary; full rules DS §4)

| Pattern | Text |
|---|---|
| Responsible member | "Verantwortlich: <Name>" · "noch niemand" (open visit) · "nicht erfasst" (visit no longer open) |
| Author | "von <Name>" · "von dir" · "Teammitglied <n> (ohne Namen)" |
| Proposal | "vorgeschlagen von <Assistent>" · "bestätigt von <Name> am <Datum>" · "nicht gefunden" |
| Count with base | "<Wert> · aus <n> Einsätzen" · "zu wenig Daten" |
| Failed read | "<Was> konnte nicht geladen werden." + "Erneut laden" |
| Pending | "Wird gespeichert …" · "Wird gesendet …" · "Wird geladen …" |
| Website status | "In Vorbereitung" · "KI bereitet vor – Menschen entscheiden" |

---

## 8. Build order and acceptance (proposal for `eng` and the PO)

| Step | Milestone | What | Test |
|---|---|---|---|
| 1 | M2 (UX2-3, UX2-4) | tokens §2.6 in `globals.css`; `body` font fix; components 5, 8, 12, 15, 16, 19, 20, 23, 25 in `src/components/ui`; port C-01, C-11, O-01, O-06 to them | guarding scans §2.6; axe serious/critical = 0 on every captured page; unit test per component state |
| 2 | M2 | A-05 error/not-found pages; `RetryBlock` focus rule | Playwright: unknown route renders inside the shell |
| 3 | M4 | `ProposalLine`, `BulkConfirmBar`, `CountChip`, `Figure` for PLAN3 and AN3 | PLAN3-9, PLAN3-12, AN3-7 e2e |
| 4 | M5 | marketing tokens and components §6 on the website code base | Lighthouse a11y ≥ 95, perf ≥ 90 (phone) |
| 5 | M6 | `BottomSheet`, `IntentList`, `ConnectionBanner`, `InstallPrompt`, manifest §3.4 | two-tap e2e at 390 px; offline e2e (value kept, one send) |
| 6 | M8 | `DataTable`, `CapacityGrid`, grouped `ExceptionRow`, `ControlRow` | O-07, O-01 at 390 px and 1440 px; no person column (catalogue test) |

## 9. Open items

| ID | Item | Owner |
|---|---|---|
| DS1-1 | `border-control` stone-500 instead of stone-300 for inputs (non-text contrast 4.80:1 vs 1.49:1): today inputs use stone-300 (e.g. `suggestions-client.tsx` select) | `eng` with UX2-3 |
| DS1-2 | `proposal` tone (sky) for assistant proposals: sky is used ad hoc today; confirm it is not read as a severity | `cra` |
| DS1-3 | Body font Arial vs loaded Geist | `eng` with UX2-3 |
| DS1-4 | App icon and word mark | `uxa` (asset), `po` |
| DS1-5 | Dark mode after M8 | `po` |
| DS1-6 | Stock imagery on the website | `lca` |

## Change log
- 2026-11-03 15:00 CET (`uxa`): version 1, from the Delivery Program (#832) and issue #831; supersedes the token proposal in DS §7 (2026-10-27) with exact values, contrast and CSS.
