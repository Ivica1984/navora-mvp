# NAVORA — Architecture

**Status:** Zielarchitektur **DECIDED/PLANNED**, nicht mit dem aktuellen Produktionsstand gleichsetzen. **VERIFY AGAINST REPOSITORY**. Siehe `MASTER_CONTEXT.md` für Statuskonvention.

## Architekturprinzipien

Supabase/PostgreSQL als gemeinsame Datenwahrheit; Domainlogik unabhängig von React; serverseitige Autorisierung und sensible Regeln; Rollen plus tatsächlicher Versorgungskontext; Human-in-the-loop; idempotente Commands; nachprüfbare Ereignisse/Freigaben; geringe Erfassungslast; Teamautonomie ohne Verletzung gesetzlicher Verantwortung.

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

Parallel: geprüfte Arbeitszeit → Payroll-Fakten; Erlöse/Kosten/Plattformgebühr → Teamökonomie. Abrechnungs- und Lohnfakten niemals verwechseln.

## Rule Engine und Architect Mode

Quellversion/Seite/Abschnitt → fachliche Regel → versionierte maschinenlesbare Definition → deterministischer Lauf → Erklärung mit Inputs/Quellen/Unsicherheit → Test/Audit. UI zeigt nur relevante Fragen und offene Entscheidungen. Architect Mode verwaltet fachlich freigegebene Versionen und analysiert Auswirkungen auf Feld, Folgeentscheidung, Ergebnis und Test. KI erzeugt Hinweise, verändert aber keine harten Regeln. Frühere Entwürfe in ZIP-Paketen sind **nicht IMPLEMENTED**.

## Geodaten und KI

**IMPLEMENTED in damaliger Datenbank:** PostGIS, `cases.location`, `teams.base_location`, private Distanzfunktion und Geocoding-Queue. **PLANNED:** verifizierte mehrere Teamstandorte, Worker und fachlich validierter Routing-/Radius-Fit; Distanz unbekannt lassen, wenn Lage fehlt. KI-Orchestrator läuft serverseitig: Datenminimierung → Provider → strukturiertes Schema → Validierung → menschliches Review → unveränderlicher freigegebener Stand. Anbieter und Betriebsort **OPEN**.

## Security und Production

**Blocker:** frühere `{public}`-Policies auf sensiblen Tabellen. **PLANNED:** SSR-Cookie-Sessions, RLS je Organisation/Team/Fall, MFA-Konzept, private Geheimnisse, Audit, zeitlich begrenzter Break-glass, Datenlöschung, Restore-Tests, Incident Response, klinische und Datenschutz-Freigaben. Hostinganbieter **UNKNOWN**; Render nicht als bestehend darstellen. CI/Docker existieren in Entwurfspaketen, Integration **VERIFY AGAINST REPOSITORY**. Skalierungsziel vieler Teams ist kein nachgewiesener Lasttest.

## Zielstruktur (PLANNED)

```text
src/app/{(auth),(protected)}/{field,operations,matching,teams,partners,quality,assessments,architect,finance}
src/domain/{visits,teams,matching,documentation,assessment,rules,quality,billing,security}
src/application/{commands,queries,policies,workflows}
src/infrastructure/{supabase,ai,geocoding,integrations,audit}
src/components/{field,operations,ui}
supabase/{migrations,functions,seed}
tests/{unit,integration,security,e2e}
```

Regel: Domain importiert weder React noch Supabase; Infrastructure implementiert Ports; UI ruft Application auf. Einführung schrittweise anhand des realen Repos.
