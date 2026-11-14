# NAVORA screen catalog, version 1

**Owner:** UX/UI Design Architect (`uxa`) · **Date:** 2026-11-03 15:00 CET · **Scope:** every screen needed for M2 to M8 of the Delivery Program (#832): website (M5), shared app screens, caregiver app (M2, M4, M6), operations app (M2, M4, M8), family app specification (M7, FROZEN) · **Baseline:** `recovery/main` `2981ad5`; open PRs read from code (#799, #800, #803, #804, #806, #809, #813, #814, #815) · **Companions:** [`NAVORA_INFORMATION_ARCHITECTURE.md`](NAVORA_INFORMATION_ARCHITECTURE.md) (surfaces, roles, routes, navigation), [`NAVORA_DESIGN_SYSTEM_V1.md`](NAVORA_DESIGN_SYSTEM_V1.md) (tokens, components), [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) (behaviour rules, **DS §n**).

**Status labels:** IMPLEMENTED (on `recovery/main`, synthetic seed) · BUILT ON PR (open PR head) · PLANNED (approved brief) · OPEN (needs a decision; owner named) · FROZEN (D-40, specification only) · UNKNOWN (fact not given; owner of the answer named).

**How to read an entry.** Each screen has: ID, route, status, milestone; **purpose**; **user** (persona, IA §2.2); **navigation entry**; **required data** (the read functions and database objects, as built, from `src/features/*/queries.ts`; new reads marked PLANNED); **dependencies** (briefs, decisions, other screens); **primary action**; **layout** by zone (IA §4.5: Jetzt, Zu erledigen, Als Nächstes, Später, Reference) at 390 × 844 first, then desktop; **components** (V1 names); **states** (loading, empty, error, other); **open** items. Every list ordered by rule; never a figure per person.

**Common states for every app screen** (not repeated per entry):
- *Loading:* server-rendered; the page arrives complete. A client-side read inside a section shows `LoadingLine` in place ("… werden geladen …") and never moves a focused field (DS §6).
- *Read failed:* the section shows `ErrorLine` with what is missing and `RetryBlock` "Erneut laden" (RLS4-C3 pattern, UXR-82); never "keine" or "0" for a failed read.
- *Command refused:* `ErrorLine` in the card that sent it, with the server's reason (DS §3, UX2-14).
- *No access:* the page's server check returns nothing; the screen shows `EmptyState` "Diese Seite ist für deine Rolle nicht freigegeben." with a link to the role's home (A-05, PLANNED).
- *Offline (M6):* `ConnectionBanner` at the top; entered values kept; commands carry an idempotency key and are retried (A-07, PLANNED).

---

## Index

| ID | Screen | Route | User | Status | Milestone |
|---|---|---|---|---|---|
| W-01 | Startseite | `/` (website) | visitor | PLANNED | M5 |
| W-02 | Produkt | `/produkt` | visitor | PLANNED | M5 |
| W-02a–e | Produktseiten Team, Planung, Einsatz, Qualität, Kennzahlen | `/produkt/…` | visitor | PLANNED | M5 |
| W-03 | Spitex | `/spitex` | visitor | PLANNED | M5 |
| W-04 | Pflegeheime | `/pflegeheime` | visitor | PLANNED | M5 |
| W-05 | KI bei NAVORA | `/ki` | visitor | PLANNED | M5 |
| W-06 | Angehörige | `/angehoerige` | visitor | PLANNED | M5 |
| W-07 | Demo anfragen | `/demo` | visitor | PLANNED | M5 |
| W-08 | Danke | `/demo/danke` | visitor | PLANNED | M5 |
| W-09 | Datenschutz | `/datenschutz` | visitor | PLANNED (content UNKNOWN) | M5 |
| W-10 | Impressum | `/impressum` | visitor | PLANNED (content UNKNOWN) | M5 |
| W-11 | Seite nicht gefunden | 404 | visitor | PLANNED | M5 |
| A-01 | Anmelden | `/login` | everyone | IMPLEMENTED | M2, M6 |
| A-02 | Start redirect | `/` (app) | signed in | IMPLEMENTED | – |
| A-03 | App shell (tab bar, sidebar, Mehr) | every protected route | signed in | BUILT ON PR #799 | M2 |
| A-04 | Meine Einstellungen | `/settings` | every member | IMPLEMENTED | M2 |
| A-05 | Error, not found, no access | `error.tsx`, `not-found.tsx` | everyone | PLANNED (missing today) | M2 |
| A-06 | App installieren | prompt on `/field` | team member | PLANNED | M6 |
| A-07 | Verbindung unterbrochen | banner, every screen | everyone | PLANNED | M6 |
| C-01 | Heute | `/field` | team member | IMPLEMENTED | M2, M6 |
| C-02 | Anderer Tag | `/field?datum=…` | team member | IMPLEMENTED | M2 |
| C-03 | Einsatzkarte (visit card and lifecycle) | in C-01 | team member | IMPLEMENTED | M2, M6 |
| C-04 | Dokumentation (Bericht, Beobachtungen) | in C-03 | team member | IMPLEMENTED | M6 |
| C-05 | Übergabe "Seit deinem letzten Einsatz" | in C-03 | team member | IMPLEMENTED; HAND2 PLANNED | M6, M8 |
| C-06 | Ich kann nicht arbeiten (absence dialog) | dialog on C-01 | team member | IMPLEMENTED | M2 |
| C-07 | Offen im Team und Unterstützung (cover) | sections of C-01 | team member | IMPLEMENTED (cover switched off) | M2 |
| C-08 | Zu erledigen: Entscheid offen, Zurückgegeben, Zur Gegenzeichnung | sections of C-01 | team member (RN for countersign) | IMPLEMENTED | M2, M6 |
| C-09 | Ereignis melden (quality) | in C-03 | team member | IMPLEMENTED | M2 |
| C-10 | Sicherheitshinweis an der Tür (door safety alert) | in C-03 | team member | IMPLEMENTED | M2 |
| C-11 | Team | `/team` | team member | IMPLEMENTED | M2, M4 |
| C-12 | Vorschläge | `/team/vorschlaege` | team member | IMPLEMENTED | M2, M4 |
| C-13 | Einsatz (record) | `/visits/[visitId]` | team member; coordinator (read) | IMPLEMENTED | M2 |
| C-14 | Arbeitstag | `/work` | every member | IMPLEMENTED | M2 |
| C-15 | Assistent | `/field/assistent` | team member | PLANNED (domain 10) | M6 |
| C-16 | Einsatz-Schnellzugriff (two-tap reach) | from C-01 | team member | PLANNED | M6 |
| C-17 | Tagesvorschlag (PLAN3) | `/team/tagesplan` | team member | PLANNED | M4 |
| O-01 | Ausnahmen | `/operations` | operations, coach, admin | IMPLEMENTED; OPS2 PLANNED | M2, M8 |
| O-02 | Assistenten | `/operations/assistenten` | coordinator | IMPLEMENTED; AIO1 PLANNED | M2, M8 |
| O-03 | Rückblick nach Stopp | `/operations/assistenten/rueckblick/[stopId]` | coordinator | IMPLEMENTED | M2 |
| O-04 | Aufnahme | `/intake` | admin, operations | IMPLEMENTED | M2 |
| O-05 | Kennzahlen | `/analytics` | coordinator, team member | IMPLEMENTED; AN3 PLANNED | M2, M4 |
| O-06 | Administration | `/admin` | admin | IMPLEMENTED | M2 |
| O-07 | Kapazität | `/operations/kapazitaet` | operations, coach | PLANNED (route OPEN) | M8 |
| O-08 | Kontrollen (control health) | section of O-01 / O-02 | coordinator | PLANNED (OPS2) | M8 |
| L-01 | Teams (first MVP) | `/teams` | coordinator | IMPLEMENTED, UX2-5 decides | M2 |
| L-02 | Online-Einsatzübersicht (first MVP) | `/visits` | coordinator | IMPLEMENTED, UX2-5 decides | M2 |
| L-03 | Partneranfragen (demo) | `/partners` | intake roles, demo flag | IMPLEMENTED (static), UX2-5 decides | M2 |
| F-01–F-06 | Family app | none | client, named relative | FROZEN | M7 (spec) |

---

## W. Website (S-W, M5)

**Common to every website page** (PLANNED, WEB1 due 2026-11-20 decides the content outline; `lca` clears every claim by 2027-01-08; `cra` reads wording on care and AI):
- **User:** website visitor (no account). **Required data:** none from the care database; static content in German and English. **Navigation:** header and footer (IA §3.2).
- **Dependencies:** WEB1 (`po`); domain, hosting and demo destination (owner, M3); D-IA-4 (`eng`, M1); claims rules (Delivery Program §2: no unfulfilled claim, hypotheses named, no medical-device claim, "KI bereitet vor – Menschen entscheiden", "in Vorbereitung" for frozen or unbuilt features, no photo of a real client).
- **Components:** `SiteHeader`, `SiteFooter`, `Hero`, `FeatureBlock`, `StatusTag`, `ClaimNote`, `CtaBand`, `ScreenshotFrame` (synthetic seed screenshots only), `FaqList` (V1 §8).
- **States:** static; `ScreenshotFrame` has a text alternative that describes what the screen does, not the synthetic data shown.
- **Acceptance per page (M5):** Lighthouse accessibility ≥ 95 and performance ≥ 90 on a phone; one `h1`; every image with alt text; no third-party script without an `lca` decision.

### W-01 Startseite · `/` · PLANNED · M5
- **Purpose:** say in one screen what NAVORA is and for whom, and lead to a demo request or to the nurses' view.
- **Navigation entry:** direct, search, links; logo on every page.
- **Primary action:** "Demo anfragen" (→ W-07). Secondary: "Für Pflegefachpersonen" (→ W-02c).
- **Layout (390 px, top to bottom):** `Hero` (h1 one sentence on what NAVORA is; one supporting line; two CTAs; synthetic screenshot of C-01 at phone size) → three `FeatureBlock`s (self-organised teams; less administration; continuity), each linking to its product page → "So arbeitet die KI" strip with the mandatory sequence in one line and a link to W-05 → "Pilot in Basel" `ClaimNote` (truthful status, `lca`) → `CtaBand` "Demo anfragen". **Desktop:** hero in two columns (text left, screenshot right), feature blocks in three columns.
- **Text:** h1 and lines from WEB1 (UNKNOWN until the PO writes them). The North Star "direkte Pflegezeit" appears only as the PO and `lca` word it (hypothesis wording).

### W-02 Produkt · `/produkt` · PLANNED · M5
- **Purpose:** overview of the five capabilities with their truthful status.
- **Navigation entry:** header "Produkt"; footer.
- **Primary action:** open a capability page; "Demo anfragen".
- **Layout:** h1 → five `FeatureBlock`s (Team, Planung, Einsatz, Qualität, Kennzahlen), each with one sentence, one `StatusTag` where a part is PLANNED, and a link → `CtaBand`. Desktop: two-column grid.

### W-02a–W-02e Produktseiten · `/produkt/team`, `/planung`, `/einsatz`, `/qualitaet`, `/kennzahlen` · PLANNED · M5
- **Purpose:** what each capability does **today**, for a buyer and for a nurse.
- **Navigation entry:** W-02; footer; breadcrumbs "Produkt › …".
- **Primary action:** "Demo anfragen".
- **Layout (each):** breadcrumb → h1 → lead line → 3 to 5 `FeatureBlock`s, each one IMPLEMENTED function with a synthetic screenshot (e.g. Einsatz: C-01, C-03, C-04; Team: C-11, C-12; Planung: C-17 only as "in Vorbereitung" until PLAN3 is delivered; Qualität: C-09, AN1 indicators; Kennzahlen: O-05 without person figures) → PLANNED parts in one `StatusTag` list "In Vorbereitung" → `CtaBand`.
- **Required source:** `IMPLEMENTATION_STATUS.md` on the publication date (`po` confirms each function's status).

### W-03 Spitex · `/spitex` · PLANNED · M5
- **Purpose:** explain the home-care model NAVORA serves: self-organised teams, continuity, less administration.
- **Layout:** h1 → three sections ("Teams entscheiden selbst", "Kontinuität", "Weniger Administration") each with one screenshot → benchmark lines only as hypotheses with their source (`ClaimNote`) → `CtaBand`.
- **Dependencies:** WEB1; `lca` (hypothesis wording).

### W-04 Pflegeheime · `/pflegeheime` · PLANNED · M5
- **Purpose:** find design-partner homes; no product promise.
- **Primary action:** "Als Designpartner melden" (→ W-07 with topic "Pflegeheim" preselected).
- **Layout:** h1 → `StatusTag` "In Vorbereitung; Designpartner gesucht" directly under the h1 → what a design partnership is (WEB1) → `CtaBand`.
- **Dependencies:** D-24 (owner; default A, no build), #818; nothing about interRAI LTCF, CH-Index or care levels (D-24 boundaries).

### W-05 KI bei NAVORA · `/ki` · PLANNED · M5
- **Purpose:** how NAVORA uses AI and what it never does.
- **Layout:** h1 "KI bereitet vor – Menschen entscheiden" (wording `lca`, `cra`) → the mandatory sequence as a numbered list (Entfernen → Regeln → Überwachen → KI bereitet vor → Mensch prüft → Mensch entscheidet → Mensch unterschreibt) → governance: proposals are recorded, a named person confirms, an assistant can be stopped and its values looked back at (AIG1, IMPLEMENTED) → "Was die KI nie tut" list (AI-First §5.2 "Not built in any domain") → data location only once D-35 decides (UNKNOWN until then; say nothing) → `CtaBand`.
- **Dependencies:** `lca` + `cra` review; D-35.

### W-06 Angehörige · `/angehoerige` · PLANNED · M5
- **Purpose:** announce the family layer without a promise.
- **Primary action:** none (no sign-up, no form; D-40 frozen).
- **Layout:** h1 → `StatusTag` "In Vorbereitung" → two to three lines on what is being specified (WEB1, `lca`) → link "Demo anfragen" for organisations only.

### W-07 Demo anfragen · `/demo` · PLANNED · M5
- **Purpose:** take a qualified demo request.
- **Navigation entry:** header button on every page; every `CtaBand`; W-04 with topic preset.
- **Required data (written, not read):** Name (required), Organisation (required), Rolle (required, select: Geschäftsleitung, Pflegeleitung, Pflegefachperson, Pflegeheim, Andere), E-Mail (required, `type=email`), Telefon (optional, `type=tel`), Nachricht (optional, 1000 characters), topic (hidden, from the entry), contact consent (required checkbox, text `lca`), spam guard (honeypot field plus server-side rate limit; no third-party captcha unless `lca` and the owner decide). Destination: owner-chosen (UNKNOWN, M3); **never the care database**.
- **Primary action:** "Anfrage senden".
- **Layout (one column at every width, max 560 px):** h1 → one line what happens next ("Wir melden uns innerhalb von … Arbeitstagen": period UNKNOWN, owner) → `FormField`s → consent `CheckboxRow` with link to W-09 → privacy note (one line, `lca`) → submit.
- **States:** field error inline under the field ("Bitte gib eine gültige E-Mail-Adresse ein."); sending (button disabled, "Wird gesendet …"); send failed (`ErrorLine` "Die Anfrage konnte nicht gesendet werden. Bitte versuche es erneut." with values kept); success → W-08.
- **Dependencies:** `lca` (privacy notice, retention, consent text), owner (destination), `eng` (confirmation e-mail, rate limit).

### W-08 Danke · `/demo/danke` · PLANNED · M5
- **Purpose:** confirm the request and say what follows. **Layout:** h1 "Danke für deine Anfrage" → one line on the confirmation e-mail → "Zur Startseite". No data echoed (no name, no e-mail in the page or URL).

### W-09 Datenschutz, W-10 Impressum · PLANNED · M5
- **Purpose:** legal information. **Content:** UNKNOWN (`lca`, owner). **Layout:** `Prose` template: h1, table of contents on desktop, sections with h2, last-change date.

### W-11 Seite nicht gefunden · 404 · PLANNED · M5
- **Layout:** h1 "Seite nicht gefunden" → one line → "Zur Startseite" and "Demo anfragen".

---

## A. Shared app screens

### A-01 Anmelden · `/login` · IMPLEMENTED (UX1-15, UX1-16) · M2, M6
- **Purpose:** sign in to NAVORA.
- **User:** every member. **Navigation entry:** website "Anmelden"; any protected URL without a session (redirect); app start without a session.
- **Required data:** `getOptionalUser` (session); after sign-in `getHomePath` → `organization_memberships.role` (own rows).
- **Dependencies:** Supabase Auth; `homePathForRoles`; D-IA-7 (website link).
- **Primary action:** "Anmelden".
- **Layout (390 px):** product name "NAVORA" (text) → h1 "Anmelden" → E-Mail, Passwort (`FormField`, `autocomplete` set) → primary button full width → staging line (synthetic data only) as built. Desktop: one centred card, max 440 px.
- **States:** wrong credentials (`ErrorLine`, no hint which field); sending (button disabled "Wird angemeldet …").
- **M6 work:** session on the installed app; no change to the form. "Passwort vergessen" flow: UNKNOWN whether in scope (`po`, MOB1).

### A-02 Start redirect · `/` (app) · IMPLEMENTED
- **Purpose:** send a signed-in person to her home (`/field` or `/operations`, IA §2.1). No screen.

### A-03 App shell · every protected route · BUILT ON PR #799 (UX2-1) · M2
- **Purpose:** one navigation for every role on phone and desktop.
- **User:** every signed-in person. **Navigation entry:** always present.
- **Required data:** `NavAccess` (own `organization_memberships.role`, own `team_memberships` exist) via `useNavAccess`; demo flag.
- **Dependencies:** UX2-1, UX2-8, UX2-12, UX2-31, UX2-32; IA §4.1–4.2.
- **Layout:** phone: `TabBar` (fixed bottom) + `MoreMenu`; desktop: `Sidebar`. Content area reserves the bar's height (`pb-[calc(3.5rem+env(safe-area-inset-bottom))]`).
- **States:** membership read failed → only "Meine Einstellungen" and "Abmelden" (fail closed except settings, `cra` UX1-20).

### A-04 Meine Einstellungen · `/settings` · IMPLEMENTED (SIG2) · M2
- **Purpose:** switch on safety signals outside the app (push) on this device; see delivery outside the watched hours.
- **User:** every member (the nurse is the one who needs it).
- **Navigation entry:** "Mehr" / sidebar "Meine Einstellungen"; link from C-11 reach line (UX1-24).
- **Required data:** `getMyPushState` → `my_push_state` (own rows).
- **Dependencies:** SIG2, D-33 (in-app only on Safari and Firefox), service worker `/sw.js`.
- **Primary action:** "Sicherheitssignale auf diesem Gerät erhalten" (push opt-in; label as built is authoritative).
- **Layout (390 px):** h1 → **Jetzt:** if this device does not receive P1 signals outside the app, one `Notice(attention)` with the opt-in button → device state → outside-watched-hours section (`OUTSIDE_LABEL`).
- **States:** browser without push (`Notice(info)` with the D-33 sentence); permission denied (how to allow it, text as built).
- **Open:** UX2-12 makes the page label its `h1` (today `h2`).

### A-05 Error, not found, no access · PLANNED (gap) · M2
- **Purpose:** a page that fails or does not exist still answers "what now". Today there is no `error.tsx`, `not-found.tsx` or `loading.tsx` under `src/app` (checked on `2981ad5`), so Next.js default pages appear outside the shell.
- **Layout:** inside the shell; h1 "Etwas ist schiefgelaufen" / "Seite nicht gefunden" / "Diese Seite ist für deine Rolle nicht freigegeben." → one line → primary link to the role's home → for errors "Erneut versuchen" (Next `reset`). No stack trace, no internal code (DS §4).
- **Dependencies:** UX2 (shell); `eng` places the files. Proposed as a UX2 addition (OPEN, `po`).

### A-06 App installieren · PLANNED (MOB1) · M6
- **Purpose:** install the caregiver app on the phone's home screen.
- **User:** team member on a phone browser. **Navigation entry:** one dismissible `Notice(info)` at the bottom of C-01 (never above signals or the next visit), shown once per device until dismissed; "Mehr" → "App installieren" stays.
- **Required data:** browser install capability (`beforeinstallprompt` where available; on iOS an instruction text); none from the database.
- **Dependencies:** MOB1; `eng` delivery form (M1); web app manifest (`start_url: /field`, V1 §6.6).
- **Primary action:** "Installieren" (Android/Chromium) or "So geht's" (iOS: instruction sheet with the share-menu steps).

### A-07 Verbindung unterbrochen · PLANNED (MOB1) · M6
- **Purpose:** a lost connection never loses an entered value and is never silent.
- **Layout:** `ConnectionBanner` (`attention`) under the page header: "Keine Verbindung. Eingaben bleiben erhalten und werden gesendet, sobald die Verbindung zurück ist." (wording PROPOSED, `cra` confirms because it touches documentation); each pending command shows "Wird gesendet …" on its card; after reconnect one `role="status"` line "Gesendet." or the server's refusal on the card.
- **Dependencies:** M6 criterion (idempotent retry, every command has a key); `eng` decides storage of pending values (local only, cleared on sign-out; `lca` reads it because entered care text would sit on the device).

---

## C. Caregiver app (S-C)

### C-01 Heute · `/field` · IMPLEMENTED (F1–F4, SIG1, UX1, VIS1) · M2 (UX2), M6 (app)
- **Purpose:** the nurse's day: what is unsafe now, which visit is next, what is open for her.
- **User:** team member (nurse, care assistant; RN sees the countersign queue).
- **Navigation entry:** tab "Heute"; landing page for nurses; push tap `/field?von=push`; installed app start.
- **Required data (as built, `field/page.tsx`):** `getMySignals` → `my_signals`; `getFieldVisits` → `field_visits`; `getFieldNotes` → `field_notes`; `getFieldReports` → `field_reports`; `getReturnedReports` → `field_returned_reports`; `getCountersignQueue` → `field_countersign_queue`; `getSinceLast` → `field_since_last`; `getDoorNotes` → `field_door_notes`; `getSafetyAlerts`, `getSafetyAlertHistory` → `field_safety_alerts`, `field_safety_alert_history`; `getVisitStatusNotes` → `field_visit_status_notes`; `getFieldQuality`, `getQualityEventTypes` → `field_quality`, `quality_event_types`; `getAbsenceView` → `team_absences`, `team_open_visits`, `team_memberships`, `member_profiles`; `getCover` → `cover_offers`, `my_covers`, `sync_cover_offers`; `getTeamOpenReports` → `team_open_reports`; `getTeamVisitAlerts` → `team_visit_alerts`; `getMyAssessmentsToConfirm`; `getOwnQualificationGaps` → `team_memberships`.
- **Dependencies:** SIG1/SIG2, VIS1, VIS2, OBS1, F6/F6R/F7, HAND1, ABS1, COVER1 (switched off, D-3), DOOR1, QG1, UX2-15 to UX2-22, UX2-28; A-06, A-07, C-15, C-16 for M6.
- **Primary action:** the next visit's lifecycle step on its card (e.g. "Losfahren"); with a P1 signal, the signal's own action first.
- **Layout (390 × 844):**
  1. `PageHeader`: h1 "Heute" (other day: the date), `DateNav` (‹ gestern · Heute · morgen ›), button "Assistent" (M6, C-15), button "Ich kann nicht arbeiten" (C-06; ≤ 2 taps, ABS1).
  2. **Jetzt:** `SignalCard`s for her P1 signals (`cra`-owned content, UX2-9); a blocking fact about her (`Notice(info)` "qualification missing", UX2-22).
  3. **Zu erledigen:** `JumpRow` "Entscheid offen (n) · Zurückgegeben (n) · Zur Gegenzeichnung (n)" (UX1-27, UX1-30), only kinds with n ≥ 1.
  4. **Als Nächstes:** the next visit's `VisitCard` (C-03), inside the first viewport when there is no P1 signal (UX1-6).
  5. **Später:** the rest of today's visits (`VisitCard` collapsed to header + time + one action); "Offen im Team (n)" and "Ein Nachbarteam braucht Unterstützung (n)" (C-07); sections of C-08; "Offene Berichte im Team".
  6. Reference: install prompt (A-06, M6).
  - **Desktop (≥ 1024 px):** same order in one 720 px column; no second column (the day is read top to bottom).
- **Components:** `PageHeader`, `DateNav`, `SignalCard`, `Notice`, `JumpRow`, `VisitCard`, `Section`, `Dialog`, `EmptyState`.
- **States:** no visit today → `EmptyState` "Heute sind dir keine Einsätze zugeteilt." + link "Offen im Team" when n ≥ 1; day changed while open → VIS1-10 sentence (UX2-20 wording); signals read failed → `ErrorLine` at the very top "Sicherheitssignale konnten nicht geladen werden." with "Erneut laden" (never hidden; wording `cra`).
- **M6:** two-tap reach of visits, documentation, handover and assistant from this screen (C-16); offline (A-07).

### C-02 Anderer Tag · `/field?datum=YYYY-MM-DD` · IMPLEMENTED (VIS1-3a) · M2
- **Purpose:** look at yesterday, tomorrow or another day; move a visit to today.
- **Navigation entry:** `DateNav` on C-01; links "Einsätze von heute".
- **Required data:** as C-01 for that date.
- **Dependencies:** VIS1 (move to today, `reschedule_visit`), UX2-18 to UX2-21.
- **Primary action:** per card "Heute machen" (`action-outline`, VIS1-3b) where allowed; otherwise none.
- **Layout:** h1 = date; one `Notice(info)` at the top saying the usual actions do not apply on this day and the way back ("Einsätze von heute"), DS §2; cards show only their own way forward.

### C-03 Einsatzkarte (visit card and lifecycle) · in C-01 · IMPLEMENTED (F1, lifecycle) · M2, M6
- **Purpose:** everything for one visit: where, when, what, what to watch, the next step.
- **User:** the responsible team member; others in the team read.
- **Navigation entry:** card on C-01/C-02; anchor `#einsatz-<visitId>` (PLANNED, C-16).
- **Required data:** row of `field_visits` (client display name, address, time window, status, planned minutes per category, responsible member, overlap facts VIS2), `field_door_notes`, `field_safety_alerts`, `field_visit_status_notes`, `field_since_last` (C-05), `field_notes` and `field_reports` (C-04).
- **Dependencies:** lifecycle states (planned, on the way, started, paused, completed, not met, cancelled); "Warst du an der Tür? (nötig)" (DOOR1); VIS2 overlap line; UX2-28 ordinal; "Mehr" actions (Einsatz absagen, Abrechnungssperre setzen, Nichtantreffen melden) with consequence sentences (`CANCEL_CONSEQUENCE`, `HOLD_CONSEQUENCE`).
- **Primary action (one, by state):** planned → "Losfahren"; on the way → start; started → "Pause" or end; paused → "Fortsetzen"; completed with draft → "Bericht prüfen und unterschreiben" (C-04). Labels are the built ones (`visit-lifecycle.tsx`).
- **Layout (card, at most four facts before the action, DS §5):** header: time window · client display name (h2) · status `Badge`; facts: address (link to maps: OPEN, `lca`, external service), categories and minutes, responsible member ("Verantwortlich: …"), safety alert lines (`Notice(attention)` or `SignalCard` per `cra`); primary button; secondary row: "Mehr" (`MoreMenu`), "Zeiten ansehen und korrigieren" (`details`); sections inside: "Seit deinem letzten Einsatz" (C-05), Beobachtungen and Bericht (C-04), Qualität (C-09).
- **States:** command pending (button disabled, label "… wird gespeichert"); refused (`ErrorLine` on the card); locked after signing (times read-only, "Zeiten ansehen").

### C-04 Dokumentation (Bericht, Beobachtungen) · in C-03 · IMPLEMENTED (F6, F6R, F7, OBS1) · M6
- **Purpose:** record observations during the visit and sign the report built from the visit's facts.
- **User:** performing team member; countersigner per D-10 (C-08).
- **Navigation entry:** section "Beobachtungen" and "Bericht" on the visit card; "Zurückgegeben" jump (C-08).
- **Required data:** `field_notes` (observations with author, OBS1), `field_reports` (draft built on the server from facts, versions, return reason).
- **Dependencies:** F6/F7 (server-built draft), F6R (return), OBS1 (author line, qualification marker), UX2-27; AI domain 1 drafting is **not** in M6 (D-34 module, D-35 stage 2).
- **Primary action:** "Bericht prüfen und unterschreiben" (after the facts, DS §2 "an attesting act follows what it attests").
- **Layout:** "Beobachtungen" (h3): list (author "von <Name>"/"von dir", time) → `Textarea` + "Speichern" → "Bericht" (h3): facts list (read-only) → signature step (`ConfirmStep` naming what is signed) → after signing "Unterschrieben am … von …".
- **States:** M6: a typed observation survives a lost connection (A-07); returned version visible under "Zurückgegebene Fassung ansehen" (`details`).

### C-05 Übergabe "Seit deinem letzten Einsatz" · in C-03 · IMPLEMENTED (HAND1); HAND2 PLANNED · M6, M8
- **Purpose:** what changed for this client since she was last there.
- **Required data:** `field_since_last` (entries with kind, author, detail).
- **Dependencies:** HAND1; **HAND2** (brief due 2026-12-04): order by rule (open signals, plan changes, new observations); UX2-27 amendment (unnamed author "Teammitglied <n> (ohne Namen)").
- **Primary action:** none (read; nothing is applied).
- **Layout:** `details` summary "Seit deinem letzten Einsatz (n)" (open by default when n ≥ 1 and the visit is next; OPEN for HAND2) → `ListRow` per entry: kind word, time, author, one line. M8: grouped under the HAND2 rule headings (wording `cra`).

### C-06 Ich kann nicht arbeiten · dialog on C-01 · IMPLEMENTED (ABS1, UX1-25, -28, -31, -33) · M2
- **Purpose:** record an absence so the team sees which visits are open.
- **Required data:** `getAbsenceView` (own absence, team open visits); writes the ABS1 command.
- **Primary action:** "Abwesenheit erfassen" / "Abwesenheit ändern".
- **Layout:** native `<dialog>` with visible heading (= opening label), period fields, result: released visits as a count and "Der Einsatz ist jetzt offen im Team"; cannot be dismissed while sending (DS §6).

### C-07 Offen im Team und Unterstützung · sections of C-01 · IMPLEMENTED (ABS1 open visits; COVER1 switched off) · M2
- **Purpose:** take a visit that is open in the team; help a neighbour team (when cover is on).
- **Required data:** `team_open_visits`; `cover_offers`, `my_covers`.
- **Dependencies:** UX2-17 ("Übernehmen", one command one label); COVER1 read decision D-3 (cover stays off).
- **Primary action:** "Übernehmen" per visit (`action-outline` in the list; filled only when the section is the screen's next step).
- **Layout:** `Section` "Offen im Team (n)" → `ListRow`s (time, client display name, minutes, "Übernehmen"); "Von dir übernommen".

### C-08 Zu erledigen · sections of C-01 · IMPLEMENTED (UX1-27, UX1-30, F6R, FUP1) · M2, M6
- **Purpose:** open work that blocks a record: a not-completed visit awaiting a decision, a returned report, reports to countersign.
- **User:** team member; "Zur Gegenzeichnung" only for the RN qualification.
- **Required data:** follow-ups (`FOLLOWUP_HEADING` "Nicht abgeschlossen: Entscheid offen"), `field_returned_reports` ("Zurückgegeben"), `field_countersign_queue` ("Zur Gegenzeichnung").
- **Primary action:** per item: "Ergebnis speichern" / sign again / "Bericht prüfen und unterschreiben"; "Bericht zurückgeben" secondary with reason.
- **Layout:** three `Section`s, each with the instruction right after its heading (never collapsed), reached by the `JumpRow`; a returned report stays until signed again, whatever its date.

### C-09 Ereignis melden · in C-03 · IMPLEMENTED (QG1; one tap, UX1-9) · M2
- **Purpose:** report a quality or safety event from the visit.
- **Required data:** `quality_event_types`, `field_quality`.
- **Primary action:** "Ereignis speichern"; closing "Ereignis abschliessen".
- **Layout:** "Qualität" (h3) → one button "Ereignis melden" → form: type (select), description, "Ereignis speichern"; open events with state.

### C-10 Sicherheitshinweis an der Tür · in C-03 · IMPLEMENTED (DOOR1) · M2
- **Purpose:** record and read safety alerts about the place of care (door, key, animal…; categories as built).
- **Required data:** `active_safety_alert_categories`, `field_safety_alerts`, `field_safety_alert_history`.
- **Layout:** `SafetyAlertForm` (fieldset per category) + "Verlauf (n)" (`details`). How an alert is shown is `cra`'s (DS §3).

### C-11 Team · `/team` · IMPLEMENTED (ORD0, J3, J6, PLAN2, ASM1, ADM2, LEAVE1, AIG1 link) · M2, M4
- **Purpose:** the team's shared decisions: signals, visits needing action, requests to the team, clients and their plans, admissions and leavers.
- **User:** team member (all team roles).
- **Navigation entry:** tab "Team".
- **Required data (as built, `team/page.tsx`):** `getMySignals` → `my_signals`; `getTeamVisitAlerts` → `team_visit_alerts`; `getTeamPushStatus` → `team_push_status`; `getVisitsOutsideWatchedHours` → `visits_outside_watched_hours`; `getTeamOffers` → `team_offers`; `getTeamCases` → `team_cases`; `getCaseLifecycle` → `team_case_lifecycle`; `getContinuity` → `continuity_by_case`; `getPlanStatus` → `team_plan_status` (`refresh_team_plans`); `getTeamCaseAssessments` → `team_case_assessments`; `getAssessmentInstruments` → `assessment_instruments`; `getBillingPreview` → `billing_preview`; `getGpNotices` → `case_gp_notices`; `getMyTeamAdmissions` → `team_admissions`; `getContractEndHandover` → `contract_end_handover`; `getLeaverOpenReports` → `member_open_reports`; `getSuccessorItems` → `team_successor_items`. PLANNED: open proposal count (PLAN3-12).
- **Dependencies:** UX2-13, -15, -16, -24, -25, -30; PLAN3-9 to -12 (M4); ASM1-C6 (#815).
- **Primary action:** depends on the top open item; with nothing open: none (the page is a reference).
- **Layout (390 px):**
  1. `PageHeader`: h1 "Team", context line (team name; with several teams one section per team), link "Vorschläge (n)" (PLAN3-12), button "Tag vorschlagen" (M4, C-17).
  2. **Jetzt:** `SignalCard`s; "Einsätze mit Handlungsbedarf" (frame by UX2-16); reach line "Nicht alle erhalten Sicherheitssignale ausserhalb der App" (`attention`, outside any fold, UX2-15).
  3. **Als Nächstes:** "Anfragen an dein Team" (`team_offers`: accept or refuse with reason), "Aufnahme ins Team" (ADM2), "Austritte in den nächsten 14 Tagen" and "Offene Verantwortung nach Austritt" (LEAVE1; position `cra`, UX2-24).
  4. **Später:** "Unsere Klientinnen und Klienten" (case cards: lifecycle, continuity, Bedarfsabklärung, care plan with review, auto-plan PLAN2, GP notices, billing hold lines) → "Abgeschlossene Fälle" → "Von deinem Team abgelehnt" → billing preview.
  - **Desktop (≥ 1024 px):** two columns: left (Jetzt, Als Nächstes) 560 px, right (clients list) flexible; signals span both columns at the top.
- **States:** no case → `EmptyState` "Dein Team betreut noch keine Klientinnen und Klienten."; PLAN3 stopped → "Vorschlag zurzeit nicht verfügbar" + look-back count (PLAN3-6, -11).

### C-12 Vorschläge · `/team/vorschlaege` · IMPLEMENTED (AIG1 part (b), C1–C3) · M2, M4
- **Purpose:** confirm, change or reject values an assistant proposed, one by one or as a ticked list.
- **User:** team member of the record's team.
- **Navigation entry:** "Vorschläge (n)" on C-11.
- **Required data:** `getTeamSuggestions` → `open_suggestions`, `team_cases`, `member_profiles`, `organization_memberships`.
- **Dependencies:** AIG1-3/-4/-5, AIG1-C3, AIG1-C4/-C5 (#814: expired proposals not listed), PLAN3 lines (M4), UXR-66, -69, -74.
- **Primary action:** per line "Bestätigen"; bulk "<n> angekreuzte Werte bestätigen" (only bulk-eligible values, all unticked, no "alle").
- **Layout:** back link "Zurück zum Team" → h1 "Vorschläge" → per team `Section` → `ProposalLine`s (field label, proposed value, "vorgeschlagen von <Assistent>", "Einsatz öffnen" link to C-13, actions "Bestätigen" / "Ändern" / "Ablehnen") → sticky `BulkConfirmBar` when ≥ 1 tick.
- **States:** none open → `EmptyState` "Keine offenen Vorschläge."; partial refusal → "2 Werte bestätigt, 1 nicht übernommen." and the reason on the refused line.

### C-13 Einsatz (record) · `/visits/[visitId]` · IMPLEMENTED (AIG1, RLS4) · M2
- **Purpose:** one visit's record with where each value came from; re-confirm or change a value on a stopped assistant's look-back list.
- **User:** team member of the record's team (actions); coordinator (read only).
- **Navigation entry:** C-12 "Einsatz öffnen"; O-03 line.
- **Required data:** `getVisitRecord` → `care_visits`, `teams`, `member_profiles`, `value_provenance`; `getRecordLookback` → `record_lookback_lines`; `getHomeLink` → `organization_memberships`.
- **Dependencies:** AIG1-C1/-C2, UX2-29 amendment ("Verantwortlich: noch niemand / nicht erfasst"), shell (UX2-1 closes UXR-72).
- **Primary action:** "Erneut bestätigen" (team member, open visit, listed value); else none.
- **Layout:** back link (by `von`) → h1 "Einsatz <Datum>" → facts `dl` (status, Verantwortlich, team) → provenance line → actions under it.

### C-14 Arbeitstag · `/work` · IMPLEMENTED (WORK1, COND2) · M2
- **Purpose:** confirm her own working day (times, segments) and export a month.
- **User:** every member (own rows only; nobody else reads them, D-23).
- **Navigation entry:** tab "Arbeitstag".
- **Required data:** `getWorkingTimeNotice` → `my_working_time_notice`; `getMyWorkingDay` → `my_working_day`; `getMyWorkingDayVersions` → `my_working_day_versions`; `getMyUnexportedDays` → `my_unexported_working_days`; `getMyContractEnd` → `my_contract_end`.
- **Dependencies:** WORK1, `lca` fixed notice texts (D-23, DS §4), UX1-21.
- **Primary action:** "Bestätigen" of the day's proposal (label as built); after a confirmed version "Korrigieren" with reason.
- **Layout:** h1 = date + `DateNav` → notice "Information zu deinem Arbeitstag" (first visit; text `lca`) → the day's proposal (segments) → confirm → "Frühere Fassungen" (`details`) → "Monat exportieren" (with unexported-days count).

### C-15 Assistent · `/field/assistent` · PLANNED (AI domain 10, rule intents) · M6
- **Purpose:** answer the nurse's operational questions from existing data in one tap, without free text.
- **User:** team member.
- **Navigation entry:** button "Assistent" in the C-01 header (≤ 1 tap); back "Zurück zu Heute".
- **Required data:** only existing queries, one per intent (Delivery Program §3.1): "Was steht als Nächstes an?" → `field_visits` (+ `my_signals`); "Was hat sich geändert?" → `field_since_last`; "Wer kann übernehmen?" → `team_open_visits`, `member_profiles` (team scope only; no person ranking); "Was fehlt vor dem Unterschreiben?" → `field_reports` completeness. Every answer and its intent written to the AIG1 ledger (M6 criterion). No free clinical question (test).
- **Dependencies:** MOB1, AIG1 (ledger), D-35 A (rules only), D-IA-1; dictation and drafting NOT in scope (D-35 stage 2, D-34).
- **Primary action:** tap an intent; each answer ends with one link to where she acts (the visit card, the report).
- **Layout:** h1 "Assistent" → one line "Antworten aus deinen Einsätzen. Keine medizinische Beratung." (wording `cra`) → `IntentList` (four 56 px rows) → answer area (`role="status"`, answer as list with sources "aus: Einsatz 08:30, Bericht") → "vorbereitet vom Assistenten" provenance line.
- **States:** intent read failed (`ErrorLine` + retry); assistant stopped (AIG1) → "Assistent zurzeit nicht verfügbar." and the links to C-01 sections.

### C-16 Einsatz-Schnellzugriff (two-tap reach) · PLANNED (MOB1) · M6
- **Purpose:** each listed function (visits, documentation, handover, assistant) within two taps from the app start at 390 px (M6 e2e criterion).
- **Design:** no new screen. Tap 1 on C-01: the visit card (expands in place and scrolls to its top) or "Assistent"; tap 2: "Beobachtungen", "Bericht", "Seit deinem letzten Einsatz" (each a 44 px row on the card that expands its section). Anchors `#einsatz-<id>`, `#bericht-<id>`, `#uebergabe-<id>` make each reachable by deep link.
- **Dependencies:** MOB1; e2e at 390 px counts taps.

### C-17 Tagesvorschlag (PLAN3) · `/team/tagesplan?datum=…` · PLANNED (PLAN3-1 to -13) · M4
- **Purpose:** propose a responsible member for the day's unassigned visits; the team confirms line by line.
- **User:** team member (the team has switched "Tagesvorschlag" on, PLAN3-10).
- **Navigation entry:** "Tag vorschlagen" on C-11; back "Zurück zum Team".
- **Required data:** PLAN3 proposal function (new, PLANNED; reads the asking member's team only, PLAN3-8); member planned minutes before/after (PLAN3-4); AIG1 ledger.
- **Dependencies:** PLAN3 brief; AIG1-C4/-C5; `cra` gate.
- **Primary action:** "<n> Zuteilungen bestätigen" (ticked list) or per line "Bestätigen".
- **Layout:** h1 "Tagesvorschlag <Datum>" → date picker (today to +14 days) and "auch zugewiesene neu vorschlagen" (checkbox row) → "Vorschlag erstellen" → per member a `Section` "<Name> · <geplante Minuten vorher → nachher>" (load shown, never judged) → `ProposalLine` per visit (time, minute category, proposed member, reason in words, "kein Vorschlag: <Grund>") → `BulkConfirmBar`.
- **States:** stopped → "Vorschlag zurzeit nicht verfügbar" (PLAN3-6); switched off for the team → `EmptyState` with who switches it on (PLAN3-10).

---

## O. Operations app (S-O)

### O-01 Ausnahmen · `/operations` · IMPLEMENTED (OPS1, QG1 holds, continuity); OPS2 PLANNED · M2, M8
- **Purpose:** what the teams did not resolve, Operations last; billing holds; team load.
- **User:** operations, coach, admin.
- **Navigation entry:** first tab for coordinators (UX2-31); landing page.
- **Required data:** `getOperationsDashboard` → `operations_exceptions`, `sync_exceptions`, `cases`, `teams`; `getOpenHolds` → `quality_holds`; `getContinuity` → `continuity_by_case`; `getOpsCaseLifecycle` → `ops_case_lifecycle`; `getBillingPreview` → `billing_preview`; `getMySignals` → `my_signals`; `getSignalEvaluatorHealth` → `signal_evaluator_health`. M8: OPS2 grouping and control health (new reads, PLANNED).
- **Dependencies:** OPS1 rule unchanged (M8 criterion); OPS2, AIO1 briefs (2026-12-04); UX2-4 (no inline style; today inline styles), UX2-12.
- **Primary action:** on each exception its one next step (as built per kind; M8: OPS2 next-step text).
- **Layout (390 px):** h1 "Ausnahmen" + link "Assistenten" → **Jetzt:** evaluator health problem (`Notice(attention)`), exceptions with P1 → `ExceptionList` grouped by rule (M8) with count per group, each `ExceptionRow` (team, kind in words, age, next step) → **Später:** "Abrechnungssperren" → "Kontinuität diesen Monat" → "Pflegeteams" / "Auslastung je Pflegeteam" → billing preview.
  - **Desktop (≥ 1024 px):** list-detail: exception list left (400 px), the selected exception's detail right (case lifecycle panel, history); URL keeps the selection (`?ausnahme=<id>`, PLANNED).
- **States:** no exception → `EmptyState` "Keine offenen Ausnahmen. Die Teams haben alles selbst gelöst." (wording OPEN, `po`).

### O-02 Assistenten · `/operations/assistenten` · IMPLEMENTED (AIG1 health list); AIO1 PLANNED · M2, M8
- **Purpose:** see whether each assistant works within its threshold; find stopped ones.
- **Required data:** `getAgentHealth` → `agent_health`.
- **Dependencies:** AIG1-7, -8, -16; AIG1-C4 (expired count, #814); AIO1 evaluation harness (M8).
- **Primary action:** per stopped agent "Rückblick öffnen" (→ O-03).
- **Layout:** back "Zurück zu den Ausnahmen" → h1 "Assistenten" → `DataTable` (desktop) / `ListRow`s (phone): name, kind, state word, correction share with base, threshold, minimum reached, "<n> entschieden · <n> ohne Entscheid abgelaufen" → never a person column.

### O-03 Rückblick nach Stopp · `/operations/assistenten/rueckblick/[stopId]` · IMPLEMENTED (AIG1-12 to -14, C1) · M2
- **Purpose:** find records whose values a stopped assistant proposed and someone confirmed unchanged in the stop window.
- **Required data:** `getStopLookback` → `agent_stop_lookback`.
- **Primary action:** the line itself opens its record (C-13).
- **Layout:** back → h1 "Unverändert bestätigte Werte" → counts "Werte: n offen · m nicht mehr offen" → `ListRow`s (case reference, visit date, field, team, "überholt am …" / "Einsatz nicht mehr offen"); no person, no tick.

### O-04 Aufnahme · `/intake` · IMPLEMENTED (J1, IPA, REF) · M2
- **Purpose:** take referrals, prepare intake cases and hand them to a team.
- **User:** admin, operations.
- **Navigation entry:** tab (M8 proposal) or sidebar / "Mehr" "Aufnahme".
- **Required data:** `getIntakeData` → `intake_cases`, `linkable_cases`, `partner_requests`, `organization_memberships`; `getActiveAlertCategories` → `active_safety_alert_categories`.
- **Dependencies:** J1, REF2 (draft), DOOR1 categories, UX1-23 urgency word (`attention`, never red).
- **Primary action:** "Neue Anfrage erfassen" (form) or per request its next step.
- **Layout:** h1 "Aufnahme" → "Offene Anfragen (n)" (urgency `Badge` word) → "Fälle in Aufnahme (n)" → "Neue Anfrage erfassen" form (fieldsets "Rückkehrende Klient:in?", "Angaben für Versorgung und Finanzierung"). Desktop: lists left, form right.

### O-05 Kennzahlen · `/analytics?monat=YYYY-MM` · IMPLEMENTED (AN1, AN2); AN3 PLANNED · M2, M4
- **Purpose:** pilot figures per team and month, with base counts; never per person.
- **User:** coordinator; team member (own team).
- **Required data:** `getPilotKpis` → `pilot_kpis`; `getPilotHypotheses` → `pilot_hypotheses`. M4: AN3 spans (new read, AN3-1).
- **Dependencies:** AN1 suppression (< 3 persons hidden, < 5 events "zu wenig Daten"); AN3-1 to -7; AN3-5 (countersign latency never a target: no colour scale, no ranking).
- **Primary action:** none (read); month switch.
- **Layout:** h1 "Kennzahlen <Monat>" + `MonthNav` → per scope (organisation, team) `FigureGroup` of `Figure` (value, period, base "aus n Einsätzen", or "zu wenig Daten") → "Pilot-Hypothesen" with decision rule. Desktop: figures in a 3-column grid.

### O-06 Administration · `/admin` · IMPLEMENTED (ADM1, ADM2, LEAVE1, SIG2, COND, RLS4) · M2
- **Purpose:** members, invitations, teams, exception thresholds, response deadlines, team admission, contracts and leavers, push and watched hours.
- **User:** admin.
- **Navigation entry:** sidebar / "Mehr" "Administration" (M8 proposal: tab).
- **Required data:** `getAdminData` → `admin_members`, `member_invitations`, `member_access_events`, `admin_exception_rules`, `admin_response_deadlines`, `teams`, `organization_memberships`; `getAdminAdmissions` → `admin_team_admissions`; `getAdminContracts` → `member_contract_events`; `getContractEndHandover` → `contract_end_handover`; `getLeaverOpenReports` → `member_open_reports`; `getAdminPush` → `organization_push_settings`, `organization_watched_hours`, `push_vendors`; `getSignalEvaluatorHealth`; `getVisitsOutsideWatchedHours`.
- **Dependencies:** UX2-22, -23, -26 (#809), RLS4-C3 (#813), ADM2, LEAVE1, AIG1-1 (agent switch).
- **Primary action:** per section; at the top the open admission or access step if any.
- **Layout (390 px):** h1 "Administration" → **Jetzt:** "Aufnahme durch das Team" open cards, "Austritte in den nächsten 14 Tagen" → **Später:** `Section`s "Mitglieder", "Einladungen", "Teams", "Ausnahmen: Schwellen und Prioritäten", "Antwortfristen der Teams", "Ausserhalb der überwachten Zeiten und besetzte Zeiten", push settings — each collapsed with its count. Desktop: in-page section nav (sticky left list of the section names) + content column 880 px.
- **States:** confirm steps for organisation-wide switches (DS §2); open-report read failed → "Erneut laden" (RLS4-C3).

### O-07 Kapazität · `/operations/kapazitaet?woche=YYYY-Www` · PLANNED (Delivery Program §3.3 "Staffing"; brief OPS2 or its own, OPEN) · M8
- **Purpose:** per team and week: planned minutes against available members, uncovered visits, cover status. Never per person (Delivery Program §3.3).
- **User:** operations, coach.
- **Navigation entry:** tab "Kapazität" (IA §4.2, D-IA-2).
- **Required data:** new read (PLANNED, `eng`): per team and day: planned visit minutes, visits without a responsible member, open in team, covered by a neighbour team (COVER1, once on), absences as a count (ABS1); sources exist (`care_visits`, `team_absences`, `cover_offers`); small-team suppression as AN1 (`lca` reads it: absence counts are personal data in small teams).
- **Dependencies:** COVER1, ABS1, PLAN3 (after M4), OPS2; D-3; `lca`.
- **Primary action:** per team with uncovered visits "Team ansehen" (read-only team summary; Operations does not assign, teams decide: Teamautonomie).
- **Layout (390 px):** h1 "Kapazität" + `WeekNav` → **Jetzt:** teams with uncovered visits today (`Notice(attention)` per team: "<n> Einsätze ohne Verantwortliche") → week `CapacityGrid` per team: 7 day cells, each "geplant <min> · offen <n>" (words + number, no colour only) → **Später:** teams without gaps. Desktop: one table, teams as rows, days as columns, sticky first column.
- **Open:** whether Operations may contact a team from here (and how) is a PO decision; no assignment control is drawn.

### O-08 Kontrollen (control health) · PLANNED (OPS2, A6) · M8
- **Purpose:** show whether NAVORA's controls run: signal evaluator, push delivery, scheduled jobs, assistants, expired orders.
- **User:** coordinator; admin.
- **Navigation entry:** section at the top of O-01 when a control is unhealthy ("Jetzt"); full list under "Kontrollen" on O-02 (rename O-02 to "Assistenten und Kontrollen": OPEN, `po`).
- **Required data:** `signal_evaluator_health` (exists); OPS2 reads (PLANNED).
- **Layout:** `ControlRow` per control: name in words, state word ("läuft", "verzögert seit …", "gestoppt"), last run, what it means for care (sentence `cra`), next step.

### L-01 Teams · `/teams` · L-02 Online-Einsatzübersicht · `/visits` · L-03 Partneranfragen · `/partners` · IMPLEMENTED (first MVP) · M2
- **Purpose today:** L-01 team overview by region (`teams`); L-02 list of all visits (`care_visits`, `member_profiles`; "Verantwortlich" UX2-29); L-03 static demo page.
- **Decision:** UX2-5 (port or retire, each with its successor named). `uxa` recommendation (not a decision): L-01 retire, successor O-01 "Pflegeteams" and O-07; L-02 port as the desktop visit list for coordinators only if it holds a function no other screen has (`eng` names it), else retire with successor C-11 / O-01; L-03 retire (static demo, no data).

---

## N. Nursing-home ward (simulated, Phase A) · PROPOSED (NH-A1) · M9.0a

Text from `uxa` 15:50 (`UX_REVIEW.md`, #974), copied by `po` 2026-11-07 17:39. Synthetic data only.

### N-01 Meine Schicht · `/field` (shift view, no new tab) · PROPOSED (NH-A1)
- **User:** ward member; phone and ward tablet.
- **Reads:** own planned shifts, residents she is *zuständig* for, P1 signals, uncovered count per shift, the "Nicht überwacht" constant.
- **Commands:** none new on the screen (own shift entry lives on N-02 or its own form, `eng`).
- **Criteria:** NH-A1-8, NH-A1-18, NH-A1-19 (UXR-140, UXR-141).

### N-02 Schichtplan Wohnbereich · `/team/schichten?datum=…` · PROPOSED (NH-A1)
- **User:** ward member, coordinating member; phone list, grid from 1024 px.
- **Reads:** shift definitions, planned shifts, responsibility per resident and shift.
- **Commands:** set or change *zuständig* (NH-A1-4); own shift entry and pattern (NH-A1-3, NH-A1-15).
- **Criteria:** NH-A1-5, NH-A1-9, NH-A1-10, NH-A1-12, NH-A1-16, NH-A1-17 (UXR-139).

## F. Family app (S-F) · FROZEN (D-40) · M7 specification only

No screen is designed beyond this frame and nothing is built (M7: `eng` confirms no code, table or migration). The M7 specification (`po`, with `lca`, `cra`) fills for each screen: data source, consent rule, the team role that answers, notification text (`lca`), what AI may and may not do.

| ID | Screen | Purpose | User | Navigation entry | Required data (spec) | Dependencies |
|---|---|---|---|---|---|---|
| F-01 | Einwilligung und Zugang | the client's consent to a named relative; sign-in | client, named relative | invitation from the team (channel UNKNOWN) | consent record (new), identity of the relative (new) | D-9, D-3, D-40, `lca` |
| F-02 | Nächste Einsätze | visit window, who comes (display name), changes | as F-01 | start screen | logistics facts of `care_visits` for that client (no clinical content) | D-40, D-3 |
| F-03 | Mitteilungen | notifications of changes | as F-01 | push / message | change events (logistics) | D-40, D-9, D-33, `lca` text |
| F-04 | Nachricht an das Team | message as a team task; a team member answers anything non-logistic | as F-01 | tab | team task (new) | D-40; D-35 for drafting |
| F-05 | Befinden | client-reported answers to an approved question set; a deviation becomes a team task | client | scheduled prompt | question set (Clinical Owner), answers (new) | D-40, G-1, D-34, D-39 |
| F-06 | Team erreichen | team phone and hours | as F-01 | always visible | team contact (new) | D-40 |

---

## Coverage check against Delivery Program §2 and §3

| Program item | Screens |
|---|---|
| Website: homepage, product pages, Home Care, Nursing Home, AI, Family Portal, demo flow | W-01, W-02/a–e, W-03, W-04, W-05, W-06, W-07/W-08 (+ W-09 to W-11) |
| Caregiver 1 Login | A-01, A-06 |
| Caregiver 2 Visits | C-01, C-02, C-03, C-07, C-16 |
| Caregiver 3 Documentation | C-04, C-08, A-07 |
| Caregiver 4 Handover | C-05 |
| Caregiver 5 AI assistant | C-15 |
| Operations 1 Alerts | O-01 (Jetzt), O-08, A-04 |
| Operations 2 Escalations | O-01, O-02, O-03 |
| Operations 3 Staffing | O-07 (and C-11, C-17 on the team side) |
| Family 1–4 | F-02/F-03, F-02, F-04, F-05 (FROZEN) |

## Open items raised by this catalog

| ID | Item | Owner |
|---|---|---|
| SC-1 | A-05 error, not-found and no-access pages are missing (Next.js defaults show outside the shell) | `po` (UX2 addition), `eng` |
| SC-2 | A-07 offline wording and local storage of pending entries | `cra` (wording), `lca` (device storage), `eng` |
| SC-3 | O-07 Kapazität: brief, read and suppression | `po`, `lca`, `eng` |
| SC-4 | O-08 placement and the O-02 name | `po` |
| SC-5 | C-15 intent labels and the "keine medizinische Beratung" line | `po` (MOB1), `cra` |
| SC-6 | W-07 response period, destination; W-09/W-10 content | owner, `lca` |
| SC-7 | L-01 to L-03 per UX2-5 | `eng`, `po` |
| SC-8 | Address link to an external maps service on C-03 (sends the client address to a third party) | `lca`, `po` |

## Change log
- 2026-11-03 15:00 CET (`uxa`): version 1, from the Delivery Program (#832) and issue #831.
- 2026-11-07 17:39 CET (`po`): section N (N-01, N-02) added as PROPOSED from the `uxa` 15:50 text (#974), NH-A1 brief.
