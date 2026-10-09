# NAVORA — Master Context

**Stand der Übergabe:** 9. Oktober 2026. **Adressat:** neuer Lead Software Engineer / AI Coding Agent. **Quelle:** bisheriger Projektverlauf, eingesehener älterer `src.zip`-Snapshot, Operations-Client-Archiv, NAVORA-Handbücher, Screenshots von Codespace und Supabase sowie vier bildbasierte LTCF-CH-PDF-Teile. **Kein Zugriff auf das aktuelle GitHub-Repository oder die aktuelle Live-Datenbank.**

## Statuslegende

- **IMPLEMENTED:** zum Zeitpunkt eines eingesehenen Codes, Screenshots oder Tests belegt; heutiger Stand nicht garantiert.
- **PLANNED:** konzipiert, aber nicht als integrierte Laufzeitfunktion belegt.
- **DECIDED:** im Produktverlauf verbindlich festgelegtes Architektur-/Produktprinzip.
- **OPEN:** bedarf einer Entscheidung, Validierung oder Lizenz-/Rechtsklärung.
- **DEPRECATED:** ausdrücklich verworfener Ansatz.
- **UNKNOWN:** keine zuverlässige Information.

**VERIFY AGAINST REPOSITORY** ist die Anweisung für alle tatsächlichen heutigen Code-, Dependency-, CI- und Migrationsstände. Datenbankstände zusätzlich gegen Live-Schema und Policies prüfen. Frühere separat erstellte ZIP-Pakete sind Entwürfe, keine nachgewiesenen Repo-Commits.

## Mission und Betriebsmodell

**DECIDED:** NAVORA will die ambulante Pflege in der Schweiz neu organisieren: selbstorganisierte Pflegeteams ohne klassische Linienvorgesetzte, weniger Administration, bessere Qualität und höherer Spielraum für faire Entlöhnung. Teams planen und verteilen ihre Einsätze, entscheiden über Annahme und organisieren Vertretungen selbst; NAVORA ist Plattform und im Konfliktfall neutraler Coach. Rechtliche Arbeitgeber-, Leistungserbringer- und Qualitätspflichten müssen dennoch klar zugewiesen sein. Eine Plattformgesellschaft plus Care-Organisation/Genossenschaft wurde als mögliche Struktur diskutiert, aber nicht gegründet oder abschliessend beschlossen (**OPEN**).

**DECIDED:** Das mobile Field-Operations-Tool ist das Produktzentrum, nicht nur der Operations Control Tower. Ziel: Einsatzkontext → Anfahrt/Start/Pause/Ende → automatische überprüfbare Zeit → strukturierte oder gesprochene Beobachtung → KI-Berichtsentwurf → menschliche Freigabe → Qualität → später Billing- und Payroll-Fakten. KI unterstützt, ersetzt keine klinische Fachverantwortung.

## Anwender

Pflegekraft; selbstorganisiertes Team; NAVORA Operations; neutraler Coach; Qualitätsfachperson; fachliche Architect-/Assessment-Verantwortliche; Partner (Spital, Heim, Privatpersonen/Angehörige); Abrechnung/Payroll; technischer Admin. Genaue Berechtigungen sind **PLANNED/OPEN**, keine bestätigte produktive Zugriffsmatrix.

## Produktgrenzen

- **DECIDED:** Operations = 15-Minuten-Interventions-/Ausnahmebild, keine Matching-Start- oder umfassende CRUD-Oberfläche.
- **DECIDED:** Matching = serverseitige fachlich/qualitativ fundierte Vorschläge; Teams entscheiden selbst. Ein Team kann viele Fälle betreuen.
- **DECIDED:** Keine fiktiven Distanzen, Zeiten, Diagnosen oder Qualitätswerte als produktive Tatsachen.
- **DECIDED:** Assessments aus realen Beobachtungen stützen; interRAI-LTCF-CH/PAG/MQI für das relevante Schweizer Langzeitpflegeprodukt lizenz- und spezifikationskonform integrieren, nicht geschützte Items frei kopieren.
- **DECIDED:** Fachregeln versioniert, erklärbar und testbar; KI überschreibt keine deterministischen Regeln.
- **DECIDED:** Pflegeabrechnung, Plattformumsatz, Lohnfakten und Teamüberschuss strikt unterscheiden.

## Beobachteter Technikstand

**IMPLEMENTED (älterer Code-Snapshot):** Next.js App Router, React, TypeScript, Tailwind, Supabase JS; Routen `/`, `/login`, `/matching`, `/operations`, `/partners`, `/teams`, `/visits`. Operations Query liest `partner_requests`, `cases`, `teams`, `matching_requests`, `care_visits`, `care_notes`, `quality_events` und erzeugt Attention Items/KPIs. Supabase `signInWithPassword` im Login, Browser-Client in `src/lib/supabase.ts`. Teams und Visits hatten direkte Client-Updates. Matching/Partners waren im alten ZIP teilweise Mock-/Hardcode-Seiten.

**IMPLEMENTED (durch spätere Terminalausgaben bestätigt):** TypeScript-Queryfehler in `src/features/cases/queries.ts` korrigiert; Lint/Build anschliessend bestanden; Matching-Seite per Terminal-Patch auf Supabase-Lesequeries umgestellt; `@supabase/ssr` installiert; Next.js 16.3.4; `npm audit --omit=dev` meldete damals null Vulnerabilities. Danach wurde eine irrtümlich angelegte manuelle `createMatchingRequestAction` wieder entfernt; Build/Lint waren erfolgreich. Tatsächliche Dateien und Versionen heute: **VERIFY AGAINST REPOSITORY**.

**IMPLEMENTED (damalige SQL-Screenshots):** neun öffentliche Tabellen `cases`, `teams`, `partner_requests`, `matching_requests`, `match_candidates`, `care_visits`, `care_notes`, `quality_events`, `orders`; fachliche Foreign Keys; RLS aktiv, ABER breite `{public}`-Policies für cases/teams/care_visits; vier offene Matching Requests, zwölf `suggested` Kandidaten; PostGIS 3.3.7 und geografische Fall-/Teamfelder; private Distanzfunktion für service_role; private `geocoding_jobs` mit Indizes. Daten heute erneut prüfen. `orders` darf nicht ohne Beleg als NAVORA-Abrechnung gedeutet werden.

**Widerspruch OPEN:** Ein Browser-Screenshot zeigte keine Matching-Anfragen, während später im SQL-Editor vier offene Anfragen sichtbar waren. Mögliche Ursachen nicht belegt; Zugriffskontext/RLS, Umgebung, Zeitpunkt und Abfragen prüfen.

## Sicherheit – Blocker

Im damaligen Stand waren sensible Tabellen trotz aktivierter RLS durch breite `{public}`-Policies potenziell öffentlich zugänglich. `@supabase/ssr` war nur installiert, durchgängige serverseitige Session-, Team-/Organisations- und RLS-Prüfung nicht belegt. **Keine echten Gesundheitsdaten verwenden, bevor Auth, RLS, Datenschutz-Folgenabschätzung, Audit, Verträge, Aufbewahrung und Restore geprüft sind.** Keine Policies blind löschen, bevor Ersatzregeln getestet sind.

## BAG/LTCF/PAG/MQI und Rule-Plattform

**DECIDED als Produktanforderung, PLANNED als Implementierung:** Schweizer Gesundheits-/Pflegepflichten werden als fachliche/technische Controls behandelt; Geltung nach Rechtsträger, Kanton und Angebot prüfen. Für stationäre Langzeitpflege: lizenzierter interRAI-LTCF-CH-Adapter, versionierte PAG- und MQI-Datensätze, Provenienz, Datenqualität, menschliches Review, autorisierte Meldung. Next-Generation Architect Tool: Handbuchmatrix → Quellen-/Rule-Repository → deterministische Rule Engine → Smart Input → Workflow → Explainability → Impact Analysis → fachliche Tests und Audit. Die vier LTCF-PDFs sind bildbasiert; keine vollständige seitengetreue OCR und klinische Validierung nachgewiesen.

## Sofortauftrag an Übernehmer

1. **VERIFY AGAINST REPOSITORY**: Git-Status, tatsächliche Dateien, Dependencies, Tests, Migrations-/CI-/Deploymentkonfiguration.
2. Live-Supabase-Schema/Policies/Grants/PostGIS/Extensions/Migration-History mit Repo abgleichen; keine Secrets oder Patientendaten in Protokollen.
3. Reproduzierbare Baseline: `npm ci`, Lint, Typecheck, Tests (falls vorhanden), Build; negative Zugriffstests.
4. SSR-Auth + Organisations-/Teamscope + RLS kontrolliert einführen.
5. Ersten Field-Tool-Vertikalschnitt sicher und testbar implementieren.
6. Danach Teamplanung, KI-Dokumentation, Matching-Qualität, Assessment-/Rule-Plattform und erst nach fachlicher Abnahme Billing/Payroll ausbauen.

**Weiterführend:** `ARCHITECTURE.md`, `PRODUCT_REQUIREMENTS.md`, `DOMAIN_RULES.md`, `DATABASE_AND_DATA_MODEL.md`, `INTEGRATIONS.md`, `TECHNICAL_DECISIONS.md`, `TESTING_AND_QUALITY.md`, `CURRENT_IMPLEMENTATION_STATUS.md`, `ROADMAP.md`.
