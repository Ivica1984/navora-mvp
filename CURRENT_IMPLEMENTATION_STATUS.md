# NAVORA — Current Implementation Status

**Wichtig:** „Current“ bedeutet zuletzt im Gespräch nachweisbarer Stand, **nicht Live-Audit am 9. Oktober 2026**. Code-Stand **VERIFY AGAINST REPOSITORY**, DB-Stand **VERIFY AGAINST DATABASE**. `src.zip` ist älter als Codespace-Patches.

| Bereich | Status | Beleg / Einschränkung |
|---|---|---|
| Next.js/React/TS App | **IMPLEMENTED damals** | `src.zip`, erfolgreiche Builds. Ursprünglich Next 16.3.0; später Next 16.3.4. |
| Abhängigkeitssicherheit | **IMPLEMENTED damals** | `npm audit --omit=dev` ergab 0 nach Updates; heute erneut auditieren. |
| Lint und Build | **IMPLEMENTED damals** | Screenshots zeigten erfolgreiche Läufe nach mehreren Type-/Lintfixes. |
| Login | **PARTIAL IMPLEMENTED** | Browser-Client `signInWithPassword` im alten Code. SSR-Auth **nicht bestätigt**. |
| `@supabase/ssr` | **IMPLEMENTED damals** | Installation und Build-Screenshot; Verwendung **UNKNOWN**. |
| Geschützte Routen | **UNKNOWN/OPEN** | Keine Middleware im älteren ZIP; spätere Implementierung nicht belegt. |
| Operations | **PARTIAL IMPLEMENTED** | UI/7 Supabase-Abfragen, KPIs/Attention; heutiger Stand prüfen. |
| Matching Read UI | **PARTIAL IMPLEMENTED damals** | Mock-Seite später durch Supabase-Requests/Teams ersetzt, Build grün. |
| Matching Engine | **NOT IMPLEMENTED (belegt)** | Keine qualitätsvalidierte serverseitige Engine nachgewiesen; alte 12 Kandidaten schwach begründet. |
| Manuelle Matching-Action | **DEPRECATED** | Fälschlich angelegt, danach entfernt. |
| Partners | **PARTIAL IMPLEMENTED** | Route existiert; alter Code hatte fest codierte Werte. |
| Teams/Visits | **PARTIAL IMPLEMENTED** | Pages und direkte Client-Updates im alten ZIP; kein vollständiges Field Tool. |
| Live-Zeit/Offline/Observations | **PLANNED** | Entwurfspakete vorhanden, aktive Integration unbestätigt. |
| `cases`, `teams`, `care_visits` usw. | **IMPLEMENTED damals** | SQL-Editor zeigte neun Tabellen, FKs. `orders`-Zweck **UNKNOWN**. |
| RLS | **IMPLEMENTED aber unsicher damals** | RLS `true`, jedoch `{public}`-Policies mit `true` auf Fällen/Einsätzen/Teams. |
| Matching-Datensätze | **IMPLEMENTED damals** | 4 offene Anfragen und 12 `suggested` Kandidaten; Browser zeigte früher leer. |
| PostGIS | **IMPLEMENTED damals** | v3.3.7, Fall-/Teampflege-Standortfelder. |
| Distanzfunktion | **IMPLEMENTED damals** | `private.calculate_case_team_distance_km`, anon/authenticated=false, service_role=true. |
| Geocoding-Queue | **IMPLEMENTED damals** | `private.geocoding_jobs` und Indizes. Worker **UNKNOWN**. |
| Mehrfach-Teamstandorte | **UNKNOWN** | SQL vorgeschlagen, Ausführung nicht durch Screenshot belegt. |
| KI-Dokumentation | **PLANNED** | Kein Provider/produktiv integrierter Freigabeflow belegt. |
| Assessment/PAG/MQI | **PLANNED** | Architektur-/Schemaentwürfe, nicht produktiv validiert. |
| Rule Engine/Architect Mode | **PLANNED** | Externe Beispielmodule/SQL-Entwürfe; Repo-Integration unbestätigt. |
| OCR der vier LTCF-PDFs | **OPEN** | Scans bildbasiert; keine vollständige qualitätsgeprüfte Item-/Regelmatrix. |
| Billing/Payroll | **PLANNED** | Keine nachgewiesene NAVORA-Abrechnungslogik. |
| Stripe | **UNKNOWN** | Kein bestätigtes NAVORA-Setup; `orders` kein Beweis. |
| Render | **UNKNOWN** | Kein bestätigtes Deployment. |
| GitHub Codespace | **IMPLEMENTED damals** | Terminal/Browser-Screenshots. CI/Branches heute **VERIFY AGAINST REPOSITORY**. |
| Docker/Actions | **PLANNED/UNKNOWN** | In erzeugten Paketen Vorlagen, nicht nachgewiesen integriert. |

## Unmittelbare Risiken

1. Sensible Tabellen mit breiten früheren `{public}`-Policies: Zugriffssicherheit vor Patientendaten prüfen.
2. Browser/SQL-Matching-Differenz: Auth/RLS/Umgebung/Zeitstand untersuchen.
3. DB-Änderungen im SQL-Editor sind möglicherweise nicht versioniert.
4. ZIP-Code ist nicht aktueller Codespace; nicht blind überschreiben.
5. Vorige Handbuch-/Code-Pakete sind externe Entwürfe, keine Produktiv-Implementierung.

## Reproduktionscheck

`git status`, `git log`, `package.json`, Lockfile, `src`, `supabase/migrations`, vorhandene Tests, `.github/workflows` (keine Secrets), Builds und Datenbankschema/Policies abgleichen. **VERIFY AGAINST REPOSITORY**. Erst anschliessend konkrete Migrationen oder neue Commands implementieren.
