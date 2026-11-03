# WEB1 implementation plan: public website (M5)

**Owner:** Engineering (`eng`, decides HOW) · **Date:** 2026-11-03 (Europe/Zurich) · **Version:** 1

**Baseline (requested by the owner):** the `uxa` design set on PR #834, head `d811658`:
- `docs/design/NAVORA_INFORMATION_ARCHITECTURE.md` (**IA**);
- `NAVORA_SCREEN_CATALOG.md` (**SC**), screens W-01 to W-11;
- `NAVORA_DESIGN_SYSTEM_V1.md` (**DS1**), §2 tokens and §6 marketing extension.

**Also built on:** `docs/product/DELIVERY_PROGRAM.md` (M5, §2), `docs/engineering/IMPLEMENTATION_SEQUENCE.md` (#833).

**Not decided here:** the WEB1 *brief* (content outline and acceptance criteria) is the PO's, due 2026-11-20. Page text, claims and legal content are not written by Engineering; where they are missing this plan says UNKNOWN and names the owner.

**Labels:** IMPLEMENTED · PLANNED · OPEN (decision needed) · UNKNOWN.

---

## 1. Architecture decision proposed (D-IA-4, answered by `eng` in M1; owner decides domain and host in M3)

| Question | Proposal | Why |
|---|---|---|
| Separate site or public routes in the app? | **Separate site, separate origin**, in this repository under `site/` with its own `package.json`, build and CI job | M5 requires no shared session, cookie, local-storage key or analytics id with the app (IA §3.3). A separate origin enforces that by construction; a route group in the app would share the origin and its cookies. |
| Framework | Next.js (same major as the app) with **static generation** for every page. **One** server endpoint: the demo form POST. | Same language, lint rules and token CSS as the app. Static pages meet Lighthouse performance ≥ 90 on a phone without a runtime. |
| Styling | DS1 §2.6 tokens copied into `site/app/globals.css` from the same source file as the app (one script checks they are identical), plus the DS1 §6.1 marketing tokens | One design language; the website cannot drift from the app's colours and focus ring. |
| Content | German and English as MDX or typed content files in `site/content/{de,en}/`, one file per page; no CMS | No CMS is in any brief; content changes go through PRs, which gives `lca` claim review a diff. |
| Demo form backend | `POST /api/demo` behind a **destination adapter** (e-mail or CRM, chosen by the owner in M3) | The destination is UNKNOWN (SC-6). The adapter lets the form, validation, honeypot and rate limit be built and tested before it is known. |
| Data rule | Nothing from the demo form reaches the care database; the site has no Supabase client or key | M5 criterion; a CI check fails if `site/` imports `@supabase/*` or reads a `SUPABASE_*` variable. |
| Analytics, cookies | none | IA §3.2: no tracking cookie unless the owner decides (OPEN, `lca`). |
| Images | synthetic-seed screenshots from the existing `ui-screenshots` CI job (390 and 1440 px); no client photo | DS1 §6.2, Delivery Program §2. |

Recorded as **ADR-142** (PROPOSED) with this plan. The owner decides host and domain in M3 (D-2-like decision; DELIVERY_PROGRAM M5 dependencies).

---

## 2. Shared website building blocks (built once, used by every page)

| Block | DS1 component | Frontend work | Backend | API | Test |
|---|---|---|---|---|---|
| Site frame | `SiteHeader`, `SiteFooter`, `LanguageSwitch` | layout, sticky header 64/56 px, menu panel below 1024 px (Escape, outside tap, close on choice) | none | none | Playwright keyboard path; axe |
| Marketing tokens | DS1 §6.1 | `text-display`, `text-lead`, `section-space`, `surface-tint`, `surface-brand` | none | none | token parity script (app and site) |
| Content blocks | `Hero`, `FeatureBlock`, `StatusTag`, `ClaimNote`, `CtaBand`, `ScreenshotFrame`, `FaqList`, `Prose` | one file each in `site/components/`, unit test per variant | none | none | vitest/RTL per variant |
| Screenshot pipeline | `ScreenshotFrame` | copies selected images from the `ui-screenshots` artifact into `site/public/screens/` at build | none | none | CI: image exists for every referenced screen |
| SEO and a11y | – | metadata per page, `lang` per locale, sitemap, robots, one `h1` per page | none | none | Lighthouse CI (a11y ≥ 95, perf ≥ 90 phone) |
| Security headers | – | CSP without third-party scripts, HSTS, frame-ancestors none | none | none | e2e header check (pattern of `security-headers.spec.ts`) |

---

## 3. Per screen

Every page uses the site frame and the blocks above. "Content" means the PO's WEB1 outline and `lca` clearance; it is never written by Engineering.

| Screen | Frontend components | Backend dependencies | API dependencies | Content dependencies | Sequence |
|---|---|---|---|---|---|
| **W-01 Startseite** `/` | `Hero` (with C-01 phone screenshot), 3 × `FeatureBlock`, AI strip (mandatory sequence), `ClaimNote` "Pilot in Basel", `CtaBand` | none | none | WEB1 h1 and lines (UNKNOWN), `lca` pilot wording | S-3 |
| **W-02 Produkt** `/produkt` | h1, 5 × `FeatureBlock` with `StatusTag`, `CtaBand` | none | none | IMPLEMENTATION_STATUS on publication date (`po` confirms each status) | S-3 |
| **W-02a–e Produktseiten** `/produkt/{team,planung,einsatz,qualitaet,kennzahlen}` | breadcrumb, h1, lead, 3–5 `FeatureBlock` with `ScreenshotFrame`, "In Vorbereitung" `StatusTag` list, `CtaBand` | none | none | screenshots of C-01, C-03, C-04, C-11, C-12, O-05 from the synthetic seed; PLAN3 only as "in Vorbereitung" until delivered | S-4 |
| **W-03 Spitex** `/spitex` | h1, 3 sections with screenshot, `ClaimNote` for every benchmark line, `CtaBand` | none | none | WEB1; `lca` hypothesis wording | S-4 |
| **W-04 Pflegeheime** `/pflegeheime` | h1, `StatusTag` "In Vorbereitung; Designpartner gesucht", `CtaBand` → W-07 with topic `pflegeheim` | none | none | WEB1; D-24 boundaries (no LTCF, CH-Index, care levels) | S-4 |
| **W-05 KI bei NAVORA** `/ki` | h1, numbered sequence list, governance section, "Was die KI nie tut" list, `CtaBand` | none | none | `lca` + `cra` wording; data location stays unsaid until D-35 | S-4 |
| **W-06 Angehörige** `/angehoerige` | h1, `StatusTag` "In Vorbereitung", 2–3 lines, link to W-07 | none | none | WEB1, `lca`; **no form, no sign-up** (D-40 frozen) | S-4 |
| **W-07 Demo anfragen** `/demo` | `DemoForm`: `FormField` × 6, topic hidden field, consent `CheckboxRow`, honeypot (hidden from assistive tech), submit with pending state, `ErrorLine` on send failure with values kept | demo endpoint: validation (shared zod schema), honeypot check, **rate limit per IP and per e-mail** (store depends on the host: UNKNOWN), destination adapter, confirmation e-mail | `POST /api/demo` → adapter `deliver(request)` → owner's destination; responses `ok`, `invalid`, `rate_limited`, `failed` | `lca` consent text, privacy line, retention; owner: destination and response period (SC-6) | S-2 (form and endpoint with a test adapter), S-6 (real adapter after M3) |
| **W-08 Danke** `/demo/danke` | h1, one line, link home; no echo of name or e-mail | none | reached only after `ok` (no data in URL) | WEB1 | S-2 |
| **W-09 Datenschutz** `/datenschutz` | `Prose` template (h1, table of contents on desktop, h2 sections, last-change date) | none | none | **content UNKNOWN** (`lca`, owner) | S-1 template, S-6 content |
| **W-10 Impressum** `/impressum` | `Prose` template | none | none | **content UNKNOWN** (legal entity, D-12) | S-1 template, S-6 content |
| **W-11 Seite nicht gefunden** (404) | h1, one line, two links | none | none | none | S-1 |

---

## 4. Implementation sequence

| Step | What | Depends on | Earliest start | Done (estimate) | Label |
|---|---|---|---|---|---|
| S-0 | ADR-142 accepted by `po` (separate site, `site/` folder, static plus one endpoint) | this plan | 2026-11-04 | 2026-11-13 (M1) | PLANNED |
| S-1 | Scaffold `site/`:<br>• Next.js, static export of pages;<br>• token parity script;<br>• site frame (header, footer, language switch);<br>• `Prose` template, W-11;<br>• Lighthouse and axe in CI;<br>• CI check: no Supabase import or key in `site/` | S-0; DS1 §2.6 and §6 (#834) | 2026-11-16 | 2026-11-20 | PLANNED |
| S-2 | W-07 `DemoForm` and `/api/demo` with a **test adapter** (writes nothing), validation, honeypot, rate-limit interface; W-08 | S-1 | 2026-11-23 | 2026-11-27 | PLANNED |
| S-3 | Marketing components with unit tests; W-01, W-02 with placeholder text clearly marked `[WEB1]` (never published) | S-1, WEB1 brief (2026-11-20) | 2026-11-23 | 2026-12-04 | PLANNED |
| S-4 | W-02a–e, W-03 to W-06 to the `uxa` page designs | `uxa` designs (2026-12-04 and 2026-12-11), WEB1 content | 2026-12-07 | 2026-12-18 | PLANNED |
| S-5 | English locale (same page set); sitemap, metadata | S-4, English text (`po`) | 2026-12-14 | 2026-12-18 | PLANNED |
| S-6 | Real destination adapter, confirmation e-mail, rate-limit store on the chosen host; W-09/W-10 content | **owner M3** (domain, host, destination, 2026-12-11), `lca` texts | 2026-12-14 | 2026-12-23 | OPEN |
| S-7 | Claims review fixes (`lca`, `cra` on care and AI wording) | `lca` review (due 2027-01-08) | 2027-01-04 | 2027-01-12 | PLANNED |
| S-8 | Go live on the public domain; acceptance evidence: Lighthouse, axe, header check, no shared cookie | S-6, S-7, DNS | 2027-01-13 | **2027-01-15 (M5)** | PLANNED |

---

## 5. Critical path, blockers, estimate

**Critical path:**

```text
owner M3: domain + host + demo destination (2026-12-11)
  → S-6 adapter and legal pages → lca review (2027-01-08) → S-7 → S-8 live (2027-01-15)
```

The build steps S-1 to S-5 have about four weeks of slack before S-6. They are not on the critical path.

| Blocker | Owner | Blocks | Needed by |
|---|---|---|---|
| WEB1 brief (content outline, acceptance) | `po` | S-3, S-4 | 2026-11-20 |
| `uxa` page designs | `uxa` | S-4 | 2026-12-04 / 12-11 |
| Domain, host, demo destination, response period | owner (M3) | S-6, S-8 | 2026-12-11 |
| Privacy notice, consent text, retention, Impressum (legal entity, D-12) | `lca`, owner | S-6, S-8 | 2026-12-18 |
| Claims clearance | `lca` (+ `cra`) | S-8 | 2027-01-08 |
| Stock imagery decision (DS1-6) | `lca` | imagery beyond screenshots | 2026-12-04 (otherwise screenshots and illustrations only) |

**Effort:**

| Steps | Size |
|---|---|
| S-1 to S-8 | 4-6 PRs |
| Agent runs | 8-12 |
| Human equivalent | 8-12 person-days |
| Review | 2-4 days, including `lca` |

Confidence is **Low** until WEB1 and the host exist, and **Medium** after. The main risk is host-dependent rate limiting and e-mail sending; the adapter interface keeps that from blocking the rest.

**Estimated completion:** 2027-01-15 (M5 target), **if** the owner decides by 2026-12-11 and `lca` clears claims by 2027-01-08. Each week of delay on either moves go-live by the same week.

## Change log
- 2026-11-03 eng: version 1 (from #834 design set, #832 program, #833 sequence).
