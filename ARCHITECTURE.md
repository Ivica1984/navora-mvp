# NAVORA — Architecture

> **ARCHIVIERT: Dieses Dokument ist historisch. Die alleinige und verbindliche Quelle ist [`docs/architecture/ARCHITECTURE_HANDBOOK_V2.md`](docs/architecture/ARCHITECTURE_HANDBOOK_V2.md) (Version 2.2).** Fachliche Quelle: [Blueprint V3.2](docs/product/ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V3.md). Founder-Direktive FE-077 vom 2026-11-13. Kein Agent leitet aus diesem Dokument Vorgaben ab.

**Status:** Zielarchitektur **DECIDED/PLANNED**, nicht mit dem aktuellen Produktionsstand gleichsetzen. **VERIFY AGAINST REPOSITORY**. Siehe `MASTER_CONTEXT.md` für Statuskonvention.

**Aktualisierung 2026-11-03 (Owner-Direktive „AI-first“, po):** KI ist eine Kernsäule der Architektur. Details: [`docs/product/AI_FIRST_ARCHITECTURE_UPDATE.md`](docs/product/AI_FIRST_ARCHITECTURE_UPDATE.md), [`AI_OPPORTUNITY_MAP.md`](docs/product/AI_OPPORTUNITY_MAP.md), [`AI_CAPABILITY_ROADMAP.md`](docs/product/AI_CAPABILITY_ROADMAP.md). Hinweis: Mehrere Kontexte unten sind inzwischen weiter umgesetzt, als hier steht (Stand je Item: `docs/agents/IMPLEMENTATION_STATUS.md`); eine vollständige Statusrevision dieses Handbuchs ist **OPEN**.

## Architekturprinzipien

Supabase/PostgreSQL als gemeinsame Datenwahrheit; Domainlogik unabhängig von React; serverseitige Autorisierung und sensible Regeln; Rollen plus tatsächlicher Versorgungskontext; Human-in-the-loop; idempotente Commands; nachprüfbare Ereignisse/Freigaben; geringe Erfassungslast; Teamautonomie ohne Verletzung gesetzlicher Verantwortung.

### KI-Säule (DECIDED, Owner 2026-11-03)

NAVORA ist eine AI-first-Plattform. KI ist keine spätere Erweiterung, sondern wird mit jeder Fähigkeit entworfen. Ziel ist nicht, KI-Funktionen hinzuzufügen, sondern Koordination, Administration und Versorgungsabläufe um KI-gestützte Fähigkeiten herum neu zu gestalten.

**Verbindliche Reihenfolge (Owner, 2026-11-03):** Unnötige Arbeit entfernen → Regeln anwenden → kontinuierlich überwachen → KI bereitet vor → Mensch prüft → Mensch entscheidet → Mensch unterschreibt.

**KI darf:** vorbereiten, zusammenfassen, priorisieren, entwerfen, überwachen, vorschlagen.

**KI darf nicht:**
- verantwortliche Entscheide treffen;
- Unterschriften ersetzen;
- vorgeschriebene Freigaben ersetzen;
- klinisches Urteil ausüben.

Vorschläge, die dagegen verstossen, werden abgelehnt.

**Verboten:**
- automatische Abrechnungsentscheide;
- automatische klinische Empfehlungen an Klientinnen, Klienten oder Angehörige;
- automatische klinische Priorisierung von Sicherheitssignalen;
- uneingeschränkte Allzweck-Copiloten auf Produktivdaten;
- KI anstelle verantwortlicher menschlicher Entscheide.

**Eingefroren:** D-39 (Sensoren) und D-40 (Angehörige, Check-in) nur als Spezifikation.

**Prinzipien AI-1 bis AI-12** (Wortlaut: `AI_FIRST_ARCHITECTURE_UPDATE.md` §4):
- (1) jede Fähigkeit wird auf KI-Hebel geprüft, jeder Brief hat den Abschnitt *AI leverage*;
- (2) zuerst der Datensatz, dann KI; keine Schattenkopien;
- (3) Human-in-the-loop für klinische und verantwortliche Entscheide: KI überschreibt nie klinische Regeln, ersetzt nie Verantwortung oder vorgeschriebene Unterschriften, trifft keine unkontrollierten klinischen Entscheide;
- (4) jeder KI-Einfluss steht im unveränderlichen Vorschlagsprotokoll (AIG1, IMPLEMENTED);
- (5) ein Agent liest nur, was seine bestätigende Person lesen darf;
- (6) Umfang wird mit gemessener Evidenz verdient (Korrekturquote, Stoppregel, Parallelbetrieb P-1);
- (7) das Risikoniveau L/G/H bestimmt den Weg, H nur im separat qualifizierten klinischen Modul (D-34 C);
- (8) Datenminimierung, Anbieter und Region per Owner-Entscheid (D-35), Verarbeitung CH/EU;
- (9) nie pro Person (keine Leistungsbewertung);
- (10) P1-Sicherheitssignale bleiben deterministisch;
- (11) erklärbar und umkehrbar;
- (12) jede KI-Fähigkeit nennt den entfernten Verwaltungsschritt und seine Basismessung (AN3).

**Unverändert in Kraft:**
- D-35 Regel A: im Pilot keine Klienten- oder Personaldaten an KI-Dienste;
- D-34 A plus C;
- Owner-Regel 2026-10-29: keine echten Daten vor D-1;
- G-1;
- P-1.

```text
Mobile Pflegekraft / Selbstorganisiertes Team / Operations / Partner / Architect
                 ↓ UI (Next.js + React)
         Server Actions / API / SSR Auth
                 ↓ Application Commands, Queries, Policies
    Workflow Orchestrator + Domain Services + Rule Engine
                 ↓                 ↓
 PostgreSQL / RLS / PostGIS    Async: Matching, KI, Geocoding, MQI-Export
                 ↓                 ↓
      Audit / Provenienz / Versionierung / Observability
```

## Bounded Contexts

- **Identity & Governance [PLANNED]:** Organisation, Mitgliedschaft, Rolle, Einsatzbezug, Zweck, Audit, Notfallfreigabe.
- **Partner Intake [PARTIAL IMPLEMENTED]:** Anfragen und Umwandlung; alte Partner-UI hardcodiert.
- **Cases [PARTIAL IMPLEMENTED]:** Klientenfall und Beziehungen; Pflegeplan/Verordnungen **PLANNED**.
- **Matching [PARTIAL IMPLEMENTED]:** Anfragen/Kandidaten gespeichert, Supabase-Read-Seite später gepatcht; produktive Engine **PLANNED**.
- **Team Self-Organization [PARTIAL IMPLEMENTED]:** Teamstammdaten vorhanden; Verfügbarkeit, gemeinsames Planen und Entscheidungen **PLANNED**.
- **Field Operations [PARTIAL IMPLEMENTED]:** `care_visits` und Visits-UI existieren; revisionsfähige Live-Zeit/Events/Field-UI **PLANNED**.
- **Documentation & AI [PARTIAL IMPLEMENTED]:** `care_notes` existiert; Observation/Draft/Approval-Pipeline **PLANNED**.
- **Assessment/LTCF/PAG/MQI [PLANNED]:** lizenzierte Instrumentenadapter, Berechnungen, MQI-Reporting und Datenqualität.
- **Architect/Rule Engine [PLANNED]:** Source Matrix, versionierte Regeln, Tests, „Warum?“, Impact Analysis.
- **Quality/Clinical Intelligence [PARTIAL IMPLEMENTED]:** `quality_events` existiert; validated risk signals/Reviews **PLANNED**.
- **Finance/Payroll [PLANNED]:** Leistungen, Tarife, Rechnungen, Lohn-/Teamökonomiefakten separat.
- **Operations [PARTIAL IMPLEMENTED]:** exception-based Control Tower; Matching nie von hier starten.
- **AI Layer [PARTIAL IMPLEMENTED] (2026-11-03):** Agentenregister, unveränderliches Vorschlagsprotokoll, Bestätigung pro Wert, Stopp und Rückblick (AIG1, Migrationen 0097, 0103, 0104; IMPLEMENTED auf synthetischen Daten). **PLANNED:**
  - KI-Orchestrator (Scope-Prüfung → Minimierung → Modell oder Regel → Schema-Validierung → Quellenprüfung → Protokoll → Vorschlag);
  - Agentenvertrag und Evaluations-Harness (AIO1);
  - zehn operative KI-Domänen (Dokumentation, Übergabe, Angehörige, Check-in, Personalkoordination, Operations-, Qualitäts-Monitoring, Evidenz für Assessments, Zuweisungsvorbereitung, Assistenz für Pflegende).

  **OPEN:** Anbieter, Region und Vertrag (D-35 Stufe 1); Konformitätsweg des klinischen Moduls (D-34).

## Frontend

**IMPLEMENTED früher:** App Router `/login`, `/operations`, `/matching`, `/partners`, `/teams`, `/visits`. Operations-Client rendert KPIs/Attention/Team Health/SLA. React-Komponenten dürfen keine geheime Scoring-, RLS-, Tarif- oder klinische Regel enthalten. **PLANNED:** `/field` mit eigenen Einsätzen, Einsatzdetail, Zeit, Beobachtung, Übergabe und Bericht; Teamkalender; Architect Mode; Assessment- und Quality-UI. Mobile-first, barrierearm, minimale gesicherte Offline-Speicherung. Routenbezeichnungen Zielentwurf, **VERIFY AGAINST REPOSITORY**.

## Backend und Workflows

Commands validieren Identität, Mitgliedschaft, tatsächliche Zuständigkeit, Eingaben, erlaubten Ausgangszustand, Idempotency-Key und Berechtigung; dann atomare Mutation + Audit. Queries liefern nur erlaubte Daten. Ein Teamentscheid führt nicht über mehrere ungesicherte Browser-Updates. Workflow Orchestrator modelliert Partneranfrage → Fall → Matching → Teamentscheid → Teamplanung → Einsatz → Dokumentationsfreigabe → Qualität → Billing-Fakten. **OPEN:** Server Action versus Route Handler/Edge Function/RPC pro Command; Transaktions- und Workerstrategie.

## Datenflüsse

```text
Partner/privat/spital/heim → partner_requests → cases → matching_requests
→ serverseitige Kandidaten → Teamentscheid → care_visits
→ visit_events / visit_time_segments / visit_observations
→ KI-Draft → menschlich freigegebener Bericht → Quality Gate
→ billable_facts → Tarif-/Kostenträgerabgleich
```

Parallel: geprüfte Arbeitszeit → Payroll-Fakten; Erlöse/Kosten/Plattformgebühr → Teamökonomie. Abrechnungs- und Lohnfakten niemals verwechseln. Quer zu allen Schritten (2026-11-03): Die KI-Schicht liest aus dem Graphen nur im Lesebereich der bestätigenden Person und schreibt ausschliesslich Vorschläge zurück; jeder Schritt der Kette wird von Monitoren beobachtet (verspätet, unvollständig, nicht zugestellt).

## Rule Engine und Architect Mode

Quellversion/Seite/Abschnitt → fachliche Regel → versionierte maschinenlesbare Definition → deterministischer Lauf → Erklärung mit Inputs/Quellen/Unsicherheit → Test/Audit. UI zeigt nur relevante Fragen und offene Entscheidungen. Architect Mode verwaltet fachlich freigegebene Versionen und analysiert Auswirkungen auf Feld, Folgeentscheidung, Ergebnis und Test. KI erzeugt Hinweise, verändert aber keine harten Regeln. Frühere Entwürfe in ZIP-Paketen sind **nicht IMPLEMENTED**.

## Geodaten und KI

**IMPLEMENTED in damaliger Datenbank:** PostGIS, `cases.location`, `teams.base_location`, private Distanzfunktion und Geocoding-Queue. **PLANNED:** verifizierte mehrere Teamstandorte, Worker und fachlich validierter Routing-/Radius-Fit; Distanz unbekannt lassen, wenn Lage fehlt. KI-Orchestrator läuft serverseitig: Datenminimierung → Provider → strukturiertes Schema → Validierung → menschliches Review → unveränderlicher freigegebener Stand. Anbieter und Betriebsort **OPEN**. **Präzisiert 2026-11-03:**
- Alle KI-Aufrufe laufen über einen Orchestrator. Er schreibt jeden Vorschlag ins AIG1-Protokoll; keine Modellaufrufe aus Seiten oder Clients.
- Jeder Agent hat einen Vertrag: Zweck und entfernte Arbeit, Auslöser, Lesebereich, typisierte Ausgabe mit Feldklasse, Quelle je Aussage, bestätigende Rolle, Niveau L/G/H, Messgrössen, Stoppregel.
- Ein Agent wird erst eingeschaltet, wenn seine Version auf synthetischen Fällen evaluiert ist.

## Security und Production

**Blocker:** frühere `{public}`-Policies auf sensiblen Tabellen. **PLANNED:** SSR-Cookie-Sessions, RLS je Organisation/Team/Fall, MFA-Konzept, private Geheimnisse, Audit, zeitlich begrenzter Break-glass, Datenlöschung, Restore-Tests, Incident Response, klinische und Datenschutz-Freigaben. Hostinganbieter **UNKNOWN**; Render nicht als bestehend darstellen. CI/Docker existieren in Entwurfspaketen, Integration **VERIFY AGAINST REPOSITORY**. Skalierungsziel vieler Teams ist kein nachgewiesener Lasttest.

## Zielstruktur (PLANNED)

```text
src/app/{(auth),(protected)}/{field,operations,matching,teams,partners,quality,assessments,architect,finance}
src/domain/{visits,teams,matching,documentation,assessment,rules,quality,billing,security,ai}
src/application/{commands,queries,policies,workflows}
src/infrastructure/{supabase,ai,geocoding,integrations,audit}
src/ai/{orchestrator,agents,contracts,evaluation}   # 2026-11-03, PLANNED (AIO1); heute: src/features/ai
src/components/{field,operations,ui}
supabase/{migrations,functions,seed}
tests/{unit,integration,security,e2e}
```

Regel: Domain importiert weder React noch Supabase; Infrastructure implementiert Ports; UI ruft Application auf. Einführung schrittweise anhand des realen Repos.
