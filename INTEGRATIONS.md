# NAVORA — Integrations

**Statusgrenzen:** `@supabase/supabase-js` und Supabase-Reads **IMPLEMENTED** im alten Stand; viele übrige Systeme **PLANNED/OPEN/UNKNOWN**. Tatsächlichen heutigen Code **VERIFY AGAINST REPOSITORY**.

## Supabase [PARTIAL IMPLEMENTED]

Altcode importiert `supabase` aus `src/lib/supabase.ts`, basierend auf `NEXT_PUBLIC_SUPABASE_URL` und `NEXT_PUBLIC_SUPABASE_ANON_KEY`. Login ruft `signInWithPassword`. Queries lesen Operations, Teams, Cases, Visits; Team-/Visit-Client schreibt zum Teil direkt. `@supabase/ssr` später installiert, Cookie-Auth und sichere Server-Clients **nicht nachgewiesen**. Datenbank in Supabase mit RLS und PostGIS; frühere breite Policies sind ein Sicherheitsblocker.

## Partner: Spital, Pflegeheim, Privatperson [PLANNED]

Einlieferung von Anfragen/Austritts-/Übergabeinformationen, Auftragsbestätigung, Status und geprüfte Berichte/Abrechnungsdaten mit je Vertrag festgelegtem Datenscope. Spital/Heim nicht automatisch Arbeitgeber oder Payer eines jeden Einsatzes. Fehlen noch belegte Endpoints, Verträge, Schemas und Partnerauth. **OPEN:** konkrete Partnerpiloten, Formate, Einwilligung/Berufsgeheimnis, SLA und Leistungsabgrenzung.

## EPD/E-GD und FHIR [PLANNED]

Kontrollierte Schnittstellen zu autorisiertem Schweizer Gesundheitsdatenaustausch. Interne Datenverträge können FHIR-orientiert gestaltet werden; kein Nachweis einer bestehenden EPD-Anbindung oder Freigabe. Berechtigungen, Dokumentversionen, Herkunft und Zweck prüfen. Technische Standards, Pflichtanbindung und rechtliche Geltung **OPEN**.

## interRAI LTCF CH / PAG / MQI [PLANNED]

Lizenz- und versionsgebundener Instrumenten-Adapter; klinisch validierte Item-/Scoringdaten nur aus autorisierten Spezifikationen. Import/Assessment → versionierte PAG-Berechnung → MQI-Snapshot mit Datenqualitäts- und fachlichem Review → autorisierte Meldung. Die vier PDF-Teile sind bildbasiert, vollständige OCR-/Tabellen-/Item-Matrix wurde **nicht** bestätigt. **OPEN:** Rechte, Anbieter, aktuelle Schweizer Version, technische Schnittstelle, kantonaler Anwendungsbereich und Testreferenzen.

## KI, Sprache und Dokumentenverarbeitung [PLANNED]

Serverseitiger AI-/Speech-Provider-Adapter, Quelle und Modell-/Promptversion, minimaler Kontext, strukturierte Ausgabe, Review. Keine bestätigte Providerwahl, Datenresidenz, Auftragsbearbeitungsverträge oder aktive API-Integration (**UNKNOWN**). PDF OCR: Segmentierung/Layout-/Tabellenerkennung, Confidence, manuelle fachliche Prüfung und Rechteprüfung; niemals ungeprüfte OCR-Texte zu produktiven Regeln machen.

## Geocoding [PARTIAL IMPLEMENTED]

PostGIS-Felder und private Job-Queue bestätigt; Anbieter, tatsächlicher Worker, verifizierte Koordinaten und Absicherung sensibler Adressen **OPEN**. Kein Browser-Request mit Patientenadresse/API-Key zu ungeprüften Anbietern. `private.calculate_case_team_distance_km` im damaligen Stand nur service-role-executable. Mehrfachstandorte **VERIFY AGAINST DATABASE**.

## Kostenträger/Tarife/Payroll [PLANNED]

KVG-/privat-/institutionelle Leistungsarten, Tarifversionen, Patientenbeteiligung/Restfinanzierung falls anwendbar und Payroll getrennt modellieren. Keine bestätigten Payer-APIs, Rechnungsexporte, Tarifverträge, Lohnanbieter oder Abrechnungsbefugnisse. **OPEN:** Rechtsträger, Kanton, Finanzierungstyp, Leistungsanspruch und Exporte.

## Stripe [UNKNOWN]

Keine bestätigte Entscheidung/Integration für Stripe. `orders` in derselben Supabase-Instanz beweist keinen NAVORA-Zahlungsfluss. Vor Integration Use Case, Rechtsträger, Zahler, Datenscope, Webhook-Idempotenz, Refund, PII-Minimierung und Trennung KVG-/Privatrechnung klären. Keine API-Schlüssel in Client/Repo.

## Render [UNKNOWN]

Kein bestätigter Render-Service oder Deploy. Hosting/Region/Datenstandort/Secret-Handling/Backups/Healthchecks/CI/CD fachlich klären, bevor Render als bestehend dokumentiert wird.

## GitHub [PARTIAL IMPLEMENTED]

Entwicklung im GitHub Codespace belegt. GitHub-Repo-URL, Branches, Pull Requests, Actions, Umgebungs-/Secretschutz, Deployment nicht belegt: **VERIFY AGAINST REPOSITORY**. Früher erzeugte Docker-/Actions-Vorlagen sind nicht automatisch übernommen.

## Integrationskontrakt für neue Adapter

Jeder Adapter dokumentiert: Owner, Zweck, Rechtsgrundlage/Vertrag, Datenkategorien, Feldmapping mit Provenienz, Schnittstellenversion, Auth/Secrets, Idempotenz, Retry und Fehlerpfad, Löschung/Aufbewahrung, Testfixtures, Audit und Monitoring ohne Gesundheitsdaten in Logs.
