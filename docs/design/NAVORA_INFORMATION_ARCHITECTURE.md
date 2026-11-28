# NAVORA information architecture, version 1

**Owner:** UX/UI Design Architect (`uxa`) · **Date:** 2026-11-03 15:00 CET · **Requested by:** owner, after the approval of the Delivery Program (#832, `docs/product/DELIVERY_PROGRAM.md`), for M2 to M8 · **Baseline:** `recovery/main` `2981ad5`, open PRs #799 (UX2-1 shell) and #800, #803, #804, #806, #809, #813, #814, #815 read from code · **Status labels:** IMPLEMENTED (on `recovery/main`), BUILT ON PR (on an open PR head, not merged), PLANNED (in an approved brief), OPEN (needs a PO or owner decision), FROZEN (owner freeze, specification only), UNKNOWN (a fact nobody has given yet; the owner of the answer is named).

**The three files of this set:**

| File | Answers | Delivers for issue #831 |
|---|---|---|
| `NAVORA_INFORMATION_ARCHITECTURE.md` (this file) | which surfaces exist, who uses which, how they are reached, how one moves between them | *Navigation map* (`NAVIGATION_MAP.md`) and the website sitemap |
| [`NAVORA_SCREEN_CATALOG.md`](NAVORA_SCREEN_CATALOG.md) | every screen: purpose, user, navigation entry, required data, dependencies, layout zones, states | *Screen inventory* (`SCREEN_INVENTORY.md`) |
| [`NAVORA_DESIGN_SYSTEM_V1.md`](NAVORA_DESIGN_SYSTEM_V1.md) | tokens, mobile-first and desktop systems, every component with variants and states, marketing extension | *Component inventory* (`COMPONENT_INVENTORY.md`) and the token part of `DESIGN_SYSTEM.md` |

The behaviour rules (three questions, action hierarchy, severity colours, language, accessibility floor) stay in [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) and are referenced as **DS §n**. Where this set and the code differ, the code wins and the difference is listed in §9.

---

## 1. Surfaces

NAVORA has four surfaces. Two code bases: the public website and the one NAVORA app. The caregiver app and the operations app are **role views of the one app**, not separate products (Delivery Program §3, PO recommendation; `eng` decides the delivery form in M1).

| ID | Surface | Who | Origin (host) | Code base | Auth | Status | Milestone |
|---|---|---|---|---|---|---|---|
| S-W | **Website** (public) | prospects: home-care organisations, nursing homes, nurses, partners; the press | public domain, UNKNOWN (owner, M3) | separate from the app, or public routes outside `(protected)`: `eng` decides in M1 (§5 point 6) | none; shares no cookie or session with the app (M5 criterion) | PLANNED (WEB1 brief due 2026-11-20) | M5 |
| S-C | **Caregiver app** | team members: nurses, care assistants, team members with the RN qualification | app domain (today the Render staging host; production UNKNOWN, D-2) | NAVORA app, installable web app on `/field` (PLANNED, MOB1) | Supabase session, `/login` | IMPLEMENTED as web screens; installable app PLANNED | M2, M6 |
| S-O | **Operations app** | coordinator roles: `operations`, `coach`; `admin` | same app domain | NAVORA app | same session | IMPLEMENTED as web screens; phone use and new functions PLANNED (OPS2) | M2, M8 |
| S-F | **Family app** | a client or a consented named relative | UNKNOWN | UNKNOWN | UNKNOWN (D-9 consent, D-3 read scope) | **FROZEN** (D-40): specification only | M7 (specification) |

**Rules for every surface:**
1. One product name, **NAVORA**. No sub-brand per app ("NAVORA Pflege", "NAVORA Ops" are not used). The surface is told by its content, not its name.
2. German (Swiss spelling, "du") first; English second on the website only. The app stays German until a PO decision says otherwise (OPEN).
3. The website never shows care data and never embeds an app screen with data. Screenshots on the website come from the synthetic seed only and show no realistic client names (S-W rules, §6).
4. The family app (S-F) has no route, table or component until the owner decides D-40 (M7 criterion: `eng` confirms none exists).

---

## 2. Roles and what they open

### 2.1 Role model as built (IMPLEMENTED)

Two facts decide what a person sees (`src/lib/auth/nav.ts`, `NavAccess`):
- **Organisation role** (`organization_memberships.role`, migration check): `admin`, `coach`, `operations`, `nurse`. Role names are placeholders until D-3 (`paths.ts`).
- **Team membership** (`team_memberships`; with `qualification`, ADM1/ADM2). A team member's qualification decides RN-only acts (countersign, category B, needs assessment) on the server; the navigation does not change by qualification.

The menu mirrors each page's server check; **it is not an access boundary** (UX1-3, ADR-103). Every page keeps its own check.

| Page (route) | Label (UX1-13 `PAGE_LABEL`) | Server check | admin | coach | operations | nurse | any team member |
|---|---|---|---|---|---|---|---|
| `/operations` | Ausnahmen | `is_coordinator` | ✓ | ✓ | ✓ | – | – |
| `/intake` | Aufnahme | `is_intake_role` | ✓ | – | ✓ | – | – |
| `/partners` | Partneranfragen | intake roles, demo flag only | ✓* | – | ✓* | – | – |
| `/field` | Mein Tag → **Heute** (UX2-32) | own team membership | – | – | – | – | ✓ |
| `/team` | Dein Team → **Team** (UX2-32) | own team membership | – | – | – | – | ✓ |
| `/work` | Mein Arbeitstag → **Arbeitstag** (UX2-32) | any member (own rows) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/analytics` | Kennzahlen | `is_coordinator` or team member | ✓ | ✓ | ✓ | – | ✓ |
| `/settings` | Meine Einstellungen | any member (own rows); also shown when the read fails (`cra` UX1-20) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/admin` | Administration | `is_org_admin` | ✓ | – | – | – | – |

\* only with the demo flag (ADR-006). `/team/vorschlaege`, `/visits/[visitId]`, `/operations/assistenten` and its look-back list are sub-pages, not menu items (§4.4).

**Landing page after sign-in** (`homePathForRoles`, IMPLEMENTED): `/field` when every role of the person is `nurse`; `/operations` for everybody else, also when no membership can be read. **Gap:** a `coach` or `admin` who is also a team member lands on `/operations`, not on her day (OPEN, §9 D-IA-3).

### 2.2 Personas used in the catalog

| Persona | Built role facts | Surface | Home |
|---|---|---|---|
| **Pflegefachperson / Pflegeassistenz** (team member) | `nurse` + team membership | S-C | `/field` |
| **Team member with RN qualification** | as above, `qualification` registered nurse | S-C | `/field` (countersign queue appears there) |
| **Coach** | `coach` (+ team membership possible) | S-O (and S-C if in a team) | `/operations` |
| **Operations** (Koordination, last line) | `operations` | S-O | `/operations` |
| **Administration** | `admin` | S-O | `/operations` |
| **Aufnahme** (intake) | `admin` or `operations` | S-O | `/operations`, works on `/intake` |
| **Website visitor** | none | S-W | `/` |
| **Client or named relative** | none built (FROZEN) | S-F | – |

---

## 3. Website information architecture (S-W, PLANNED, M5)

### 3.1 Sitemap

German is the default language at the root; English under `/en` (second, same structure). URL words are German, lower case, no umlauts (`ae`, `oe`, `ue`), as the app's own routes (`vorschlaege`, `rueckblick`). Content per page: Delivery Program §2; truthful status from `IMPLEMENTATION_STATUS.md` at publication; every claim cleared by `lca` (M5).

| ID | Page | URL (de) | URL (en) | Level | In header | In footer | Primary action |
|---|---|---|---|---|---|---|---|
| W-01 | Startseite | `/` | `/en` | 0 | logo | – | "Demo anfragen" |
| W-02 | Produkt (overview) | `/produkt` | `/en/product` | 1 | "Produkt" | ✓ | "Demo anfragen" |
| W-02a | Team | `/produkt/team` | `/en/product/team` | 2 | via W-02 | ✓ | "Demo anfragen" |
| W-02b | Planung | `/produkt/planung` | `/en/product/planning` | 2 | via W-02 | ✓ | "Demo anfragen" |
| W-02c | Einsatz (field) | `/produkt/einsatz` | `/en/product/field` | 2 | via W-02 | ✓ | "Demo anfragen" |
| W-02d | Qualität | `/produkt/qualitaet` | `/en/product/quality` | 2 | via W-02 | ✓ | "Demo anfragen" |
| W-02e | Kennzahlen | `/produkt/kennzahlen` | `/en/product/analytics` | 2 | via W-02 | ✓ | "Demo anfragen" |
| W-03 | Spitex (home care) | `/spitex` | `/en/home-care` | 1 | "Spitex" | ✓ | "Demo anfragen" |
| W-04 | Pflegeheime | `/pflegeheime` | `/en/nursing-homes` | 1 | "Pflegeheime" | ✓ | "Als Designpartner melden" (goes to W-07 with the topic preset) |
| W-05 | KI bei NAVORA | `/ki` | `/en/ai` | 1 | "KI" | ✓ | "Demo anfragen" |
| W-06 | Angehörige | `/angehoerige` | `/en/families` | 1 | – | ✓ | none (no sign-up, D-40 frozen) |
| W-07 | Demo anfragen (form) | `/demo` | `/en/demo` | 1 | button "Demo anfragen" | ✓ | "Anfrage senden" |
| W-08 | Danke (confirmation) | `/demo/danke` | `/en/demo/thanks` | 2 | – | – | "Zur Startseite" |
| W-09 | Datenschutz | `/datenschutz` | `/en/privacy` | 1 | – | ✓ | – |
| W-10 | Impressum | `/impressum` | `/en/imprint` | 1 | – | ✓ | – |
| W-11 | Seite nicht gefunden | any unknown URL (404) | same | – | – | – | "Zur Startseite" |

**Page text and claims:** the content outline is the PO's (WEB1, due 2026-11-20); W-09 and W-10 content (controller, retention of demo data, legal identity) is UNKNOWN until `lca` and the owner give it. Headings and section order are defined in the catalog; body text is not invented here.

### 3.2 Website navigation

- **Header** (every page, sticky on scroll, 64 px desktop, 56 px phone): logo "NAVORA" (link to W-01) · Produkt · Spitex · Pflegeheime · KI · language switch "DE / EN" · text link "Anmelden" (§3.3) · filled button "Demo anfragen". Below 1024 px: logo, "Demo anfragen", and a "Menü" button that opens a full-width panel with the same items in the same order (closes on Escape, outside tap and after a choice, DS §5 header menus).
- **Footer** (every page): Produkt (W-02 and its five pages) · Spitex · Pflegeheime · KI · Angehörige · Demo anfragen · Datenschutz · Impressum · "Anmelden" · language switch. Status line "NAVORA ist in der Pilotphase in Basel." only if the PO's WEB1 content keeps it (claims, `lca`).
- **Breadcrumbs** only on level 2 (W-02a to W-02e): "Produkt › Team".
- **No** chat widget, no cookie banner for tracking cookies (the website sets none unless the owner decides analytics; OPEN, `lca`), no newsletter sign-up (not in scope).

### 3.3 Website-to-app entry

| Entry | From | To | Rule |
|---|---|---|---|
| "Anmelden" | website header and footer | app origin `/login` (full URL; new top-level navigation, same tab) | the website never hosts a login form; no session, cookie, local storage key or analytics identifier is shared with the app (M5 criterion) |
| Installed caregiver app | phone home screen | app origin `/field` (manifest `start_url`, PLANNED, MOB1) | the website is never the start of the installed app |
| Demo request | W-07 | owner-chosen destination (UNKNOWN, owner M3) | never the care database (M5 criterion) |
| App to website | app `/login` footer link "Was ist NAVORA?" | W-01 | OPEN (PO): the only link from app to website; none inside the signed-in app |

---

## 4. App information architecture (S-C, S-O)

### 4.1 One shell (UX2-1, BUILT ON PR #799)

One shell wraps every protected route (`src/app/(protected)/layout.tsx` → `AppShell`):
- **Phone (< 768 px):** fixed bottom tab bar, 56 px (`min-h-14`) plus the safe area, up to three tabs and "Mehr". "Mehr" opens a list of every other page the person may open, then "Meine Einstellungen" (always present) and "Abmelden" last.
- **Desktop (≥ 768 px):** sticky left sidebar (dark `brand` band), product name as text (not a heading), the same items in menu order, "Abmelden" last.
- One `nav` "Hauptmenü" at a time; the current item has `aria-current="page"`, a 4 px bar and bold text (not colour only).
- Items come only from the UX1-3 map (`menuItemsFor` → `shellItemsFor`), so phone and desktop can never differ.

### 4.2 Tab sets per role (target for M2; UX2-31, UX2-32 PLANNED; proposal for M8 OPEN)

Labels after UX2-32 (one label per destination, `uxa` answer to ADR-131 deviation 1): **Heute** (`/field`), **Team** (`/team`), **Arbeitstag** (`/work`), **Ausnahmen** (`/operations`), **Aufnahme** (`/intake`), **Kennzahlen** (`/analytics`), **Administration** (`/admin`), **Meine Einstellungen** (`/settings`).

| Person (built facts) | Phone tabs, in order (M2: UX2-31) | "Mehr" (M2) | Desktop sidebar order | M8 proposal (OPEN, PO with OPS2) |
|---|---|---|---|---|
| Team member (`nurse` + team) | Heute · Team · Arbeitstag · Mehr | Kennzahlen · Meine Einstellungen · Abmelden | Heute · Team · Arbeitstag · Kennzahlen · Meine Einstellungen · Abmelden | unchanged |
| Operations (`operations`, no team) | Ausnahmen · Arbeitstag · Mehr | Aufnahme · Kennzahlen · Meine Einstellungen · Abmelden | Ausnahmen · Aufnahme · Arbeitstag · Kennzahlen · Meine Einstellungen · Abmelden | Ausnahmen · **Kapazität** · Aufnahme · Mehr (Arbeitstag, Kennzahlen, Einstellungen) |
| Coach (`coach`, no team) | Ausnahmen · Arbeitstag · Mehr | Kennzahlen · Meine Einstellungen · Abmelden | Ausnahmen · Arbeitstag · Kennzahlen · Meine Einstellungen · Abmelden | Ausnahmen · **Kapazität** · Kennzahlen · Mehr |
| Coach in a team (`coach` + team) | Ausnahmen · Heute · Team · Mehr | Arbeitstag · Kennzahlen · Meine Einstellungen · Abmelden | Ausnahmen · Heute · Team · Arbeitstag · Kennzahlen · Meine Einstellungen · Abmelden | Ausnahmen · Heute · Team · Mehr |
| Administration (`admin`, no team) | Ausnahmen · Arbeitstag · Mehr | Aufnahme · Kennzahlen · Administration · Meine Einstellungen · Abmelden | Ausnahmen · Aufnahme · Arbeitstag · Kennzahlen · Administration · Meine Einstellungen · Abmelden | Ausnahmen · Aufnahme · **Administration** · Mehr |

Why the M8 proposal: UX2-31 fills the bar with up to two of `field`, `team`, `work`, which leaves a coordinator without a team one real destination plus "Arbeitstag" (DS §5: a bar with one real destination plus "Mehr" means the set is wrong). In the operations app the core destinations are the exception list, team capacity (Delivery Program §3.3 "Staffing") and intake. **Kapazität** is a new destination (screen O-07, PLANNED with OPS2/M8, route `/operations/kapazitaet`). The tab set is the PO's decision (UX2-31 was decided by the PO); `uxa` proposes.

### 4.3 Route map (app)

```text
/                         → redirect to the role's home (IMPLEMENTED)
/login                    sign-in (public)                                         A-01
/field                    Heute: today's visits, signals, open work                 C-01
/field?datum=YYYY-MM-DD   another day                                              C-02
/field?von=push           entry from a P1 push (opens today, signal first)          C-01
/field/assistent          AI nurse assistant (rule intents)              PLANNED M6  C-15
/team                     Team: signals, team visits, requests, cases, plans        C-11
/team/vorschlaege         Vorschläge: confirm assistant proposals                   C-12
/team/tagesplan?datum=…   PLAN3 day proposal                             PLANNED M4  C-17
/visits/[visitId]         one visit's record (look-back, proposal provenance)       C-13
/work                     Arbeitstag: own working-day record                        C-14
/work?datum=YYYY-MM-DD    another day                                              C-14
/settings                 Meine Einstellungen: push opt-in, outside delivery        A-04
/operations               Ausnahmen: exceptions teams did not resolve               O-01
/operations/kapazitaet    Kapazität: capacity per team and week           PLANNED M8  O-07
/operations/assistenten   Assistenten: agent health list                            O-02
/operations/assistenten/rueckblick/[stopId]   look-back list after a stop          O-03
/intake                   Aufnahme: referrals, intake cases                         O-04
/analytics?monat=YYYY-MM  Kennzahlen: pilot figures per team and month              O-05
/admin                    Administration                                            O-06
/teams, /visits, /partners   first-MVP pages: UX2-5 decides port or retire          L-01..L-03
```

Route naming for new screens: German, lower case, no umlauts, nouns (`tagesplan`, `kapazitaet`, `assistent`). Query parameters: `datum` (ISO date), `monat` (`YYYY-MM`), `von` (origin for the back link), `stopp` (stop id). No care data in a URL (no client name, no free text); identifiers only (UUID).

**Decision for `eng` and the PO in MOB1 (OPEN, D-IA-1):** C-15 and C-17 are drawn as routes so they have a back path and a deep link. If MOB1 prefers a bottom sheet on `/field` for C-15, the route stays and renders the sheet open (same URL, back closes it).

### 4.4 Deep links and back paths

Every screen below the first level has exactly one visible back link at the top (`action-outline` text link with "‹", 44 px), never only the browser back. Its target is decided by the `von` parameter (pattern `recordBackLink`, IMPLEMENTED for the record page) and falls back to the role's home.

| Screen | Entered from | Deep link | Back link label → target |
|---|---|---|---|
| C-01 Heute | tab; push tap; app start | `/field`, `/field?von=push` | none (first level) |
| C-02 other day | day navigation on C-01 | `/field?datum=…` | "Heute" link in the day navigation → `/field` |
| C-12 Vorschläge | link "Vorschläge (<n>)" on C-11 header (PLAN3-12) | `/team/vorschlaege` | "Zurück zum Team" → `/team` |
| C-13 Einsatz record | C-12 line "Einsatz öffnen"; O-03 line | `/visits/<id>?von=vorschlaege`, `?von=rueckblick&stopp=<id>` | "Zurück zu den Vorschlägen" / "Zurück zur Liste" / role home (IMPLEMENTED) |
| C-15 Assistent | button "Assistent" in C-01 header | `/field/assistent` | "Zurück zu Heute" → `/field` |
| C-17 Tagesvorschlag | button "Tag vorschlagen" on C-11 | `/team/tagesplan?datum=…` | "Zurück zum Team" → `/team` |
| C-14 another day | day navigation | `/work?datum=…` | "Heute" in the day navigation → `/work` |
| O-02 Assistenten | link "Assistenten" in O-01 header | `/operations/assistenten` | "Zurück zu den Ausnahmen" → `/operations` |
| O-03 Rückblick | O-02 row; OPS1 card | `/operations/assistenten/rueckblick/<stopId>` | "Zurück zu den Assistenten" → `/operations/assistenten` |
| O-07 Kapazität | tab (M8) | `/operations/kapazitaet?woche=YYYY-Www` | none (first level) |

**Header links** that only repeat a shell item are dropped (UX2-32 (2)); page-specific links stay ("Vorschläge (<n>)", "Assistenten", day navigation).

**Push and other outside entries:** a push opens `/field?von=push` (IMPLEMENTED, `PUSH_URL`); the push text is fixed (`lca`, SIG2) and carries no client data. Any new outside entry (e-mail, family notification) is privacy-relevant: `lca` reads it before it is built.

### 4.5 Content hierarchy on every app screen (DS §1)

Every screen is built from the same vertical order. The catalog fills these zones per screen.

| Order | Zone | Contents | Component (V1) |
|---|---|---|---|
| 0 | Page header | `h1` = page label; at most one context line (date, team); page-specific links | `PageHeader` |
| 1 | **Jetzt** | P1 safety signals (SIG1) for her, then a blocking condition with its one action | `SignalCard`, `Notice(attention)` |
| 2 | **Zu erledigen** | jump row to open work with counts ("Entscheid offen (1) · Zurückgegeben (2)") | `JumpRow` |
| 3 | **Als Nächstes** | the next item with the one filled action | `VisitCard` / `Card` |
| 4 | **Später** | the rest, as sections with count, collapsible where safe | `Section`, `ListRow` |
| 5 | Reference | history, settings links, help | `Section` (collapsed), `details` |

A safety signal is never moved below other content (UX2-7, DS §3). Where a section holds safety-related state shown open, its line stays outside the fold (DS §6, UX2-15).

---

## 5. Family app information architecture (S-F, FROZEN, specification for M7)

No route, table, component or text exists or is built (D-40 frozen; M7 criterion). The structure below is the **specification frame** the PO's M7 specification fills (Delivery Program §3.2, AI-First domain 3 and 4). Each item names its gate.

| ID | Screen (spec) | Function (§3.2) | Who | Entry | Gate |
|---|---|---|---|---|---|
| F-01 | Einwilligung und Zugang | consent of the client to a named relative; sign-in | client, named relative | invitation from the team (channel UNKNOWN) | D-9, D-3, D-40, `lca` |
| F-02 | Nächste Einsätze | visit window, who comes, changes (logistics only) | as F-01 | first screen after sign-in | D-40, D-3 |
| F-03 | Mitteilungen | notifications of changes | as F-01 | push or message (text `lca`) | D-40, D-9, D-33 |
| F-04 | Nachricht an das Team | message routed to the team as a task; every non-logistics answer sent by a team member | as F-01 | tab | D-40; D-35 for drafting |
| F-05 | Befinden (check-in) | client-reported answers to a Clinical-Owner-approved question set; a deviation becomes a team task | client | scheduled prompt | D-40, G-1, D-34, D-39 if sensors |
| F-06 | Team erreichen | team contact (phone, hours) | as F-01 | always visible | D-40 |

Team-side counterparts (where a family message or a check-in deviation appears for the team, on C-11) are part of the same specification and not drawn here.

---

## 6. Content rules that cross surfaces

| Rule | Website | App | Family (spec) |
|---|---|---|---|
| Status of features | IMPLEMENTED shown as available; PLANNED or FROZEN said "in Vorbereitung" | not shown | – |
| AI wording | "KI bereitet vor – Menschen entscheiden" (`lca`, `cra`) | "vorgeschlagen von <Assistent>" / "bestätigt von <Name>" (DS §2) | no AI answers on health (D-40) |
| Medical-device claim | none (`lca`, D-34) | none | none |
| Personal data | no real client photo or name; synthetic screenshots only | synthetic seed until D-1, D-35 A | – |
| Internal codes | none | none (DS §4) | none |
| Person in figures | – | never per person in figures (AN1, AN3) | – |

---

## 7. Search, filters and lists

- **No global search** in M2 to M8 (not in any brief; a search across care data needs a read-scope decision, D-3). OPEN for the PO after M8.
- Lists are **ordered by rule, not by user sort** where order carries safety meaning (signals first, then due, then planned time). User sort or filter is offered only on desktop operations lists (O-01, O-04, O-07) and never by person (AIG1, AN3, PLAN3-4: load visible, not judged).
- Every count shown is the count of what the list holds; "0" is shown where the absence is a fact the reader needs (e.g. "0 offen · 2 nicht mehr offen", DS §2), and nothing is shown as "keine" when the read failed (RLS4-C3).

---

## 8. Milestone map

| Milestone | IA work | Screens (catalog IDs) | Status |
|---|---|---|---|
| M2 (2026-11-27) | one shell, tab sets UX2-31, one label per destination UX2-32, first-MVP pages decided UX2-5 | A-01 to A-05, C-01 to C-14, O-01 to O-06, L-01 to L-03 | BUILT ON PR / PLANNED |
| M4 (2026-12-18) | PLAN3 entry and count, AN3 block | C-11, C-12, C-17, O-05 | PLANNED |
| M5 (2027-01-15) | website sitemap, header, footer, app entry | W-01 to W-11 | PLANNED (WEB1) |
| M6 (2027-01-29) | installable app on `/field`, two-tap reach, assistant route, offline states | A-06, A-07, C-01 to C-16 | PLANNED (MOB1) |
| M7 (2027-02-05) | family specification frame | F-01 to F-06 | FROZEN |
| M8 (2027-02-19) | operations tab set, capacity, control health, grouped exceptions, HAND2 order | O-01, O-02, O-07, O-08, C-05 | PLANNED (OPS2, HAND2, AIO1 briefs due 2026-12-04) |

---

## 9. Open decisions and deviations

| ID | Question | Why it matters | Owner | Default until answered |
|---|---|---|---|---|
| D-IA-1 | Assistant (C-15) and day proposal (C-17) as routes or as sheets on their parent page | back path, deep link, two-tap reach (M6) | `po` (MOB1, PLAN3), `eng` | routes as drawn; a sheet may render on the same URL |
| D-IA-2 | M8 operations tab set with "Kapazität" (§4.2) | one real destination per bar today for coordinators | `po` (OPS2) | UX2-31 as decided |
| D-IA-3 | Landing page for a `coach` or `admin` who is also a team member | lands on `/operations`, not on her day | `po` | as built |
| D-IA-4 | Website hosting: separate site or public routes in the app | session separation, CSP, deployment (M5) | `eng` (M1), owner (domain, M3) | separate origin assumed in this set |
| D-IA-5 | App language: German only, or English too | M10 scale; not in any brief | `po` | German only |
| D-IA-6 | First-MVP pages `/teams`, `/visits`, `/partners` | UX2-5: port or retire | `eng` in the UX2 ADR, `po` accepts | in the catalog as L-01 to L-03 |
| D-IA-7 | Link from the app's `/login` to the website | the only app-to-website path | `po`, `lca` | none |
| Deviation | Page labels in code are still "Mein Tag", "Dein Team", "Mein Arbeitstag" and `TAB_LABEL` differs on #799 | two names per destination | UX2-32 (PLANNED) | this set uses the UX2-32 labels |

## Change log
- 2026-11-03 15:00 CET (`uxa`): version 1, from the Delivery Program (#832) and issue #831.
