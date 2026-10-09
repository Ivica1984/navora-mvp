# NAVORA — Roadmap and Engineering Takeover

**Roadmap = PLANNED**, priorisiert nach Sicherheit und realem Pflege-Nutzen. Termine, Budget und Personen **OPEN**. Keine Phase als erledigt aus dem Vorliegen eines Dokumenten-ZIPs ableiten.

## Gate 0: Wahrheit, Governance und Rechte

- Aktuelles Repo/Supabase-Inventar, Git-Status, Migration-History; alle früheren SQL-Editor-Änderungen gegen versionierte Migrationen abgleichen. **VERIFY AGAINST REPOSITORY**.
- Lizenz-/Urheberrechte für LTCF CH/PAG/MQI; Geltung nach ambulant/stationär, Kanton, Rechtsträger und Vertrag; Fachowner benennen.
- Datenschutz-Folgenabschätzung, Datenscope, Auftragsbearbeiter/AI-/Geocoding-Verträge, verantwortliche klinische Rollen.
- Definition of Done: reproduzierbarer Build/Test + dokumentierte Live-Schema-/Policy-Diff + Freigabe für Staging. Keine echten Patientendaten vor Safety Gates.

## Gate 1: Auth und Datenzugriff (höchste technische Priorität)

- SSR-Client/Cookies und geschützte Routen; Auth serverseitig prüfen.
- Organisationen, Mitgliedschaften, Team-/Fallbezug, Rollenmatrix; Backfill vorhandener Daten.
- RLS-Pilotpolicies und negative Tests; frühere `{public}`-Policies kontrolliert ersetzen.
- Audit/Backup/Restore/Incident-Basis.
- Fertig, wenn anonyme/fremde Konten keine sensiblen Daten lesen/schreiben und berechtigte Personen den korrekten Scope sehen.

## Gate 2: Field Operations MVP

- `/field`: eigene Einsätze, minimaler Kontext, mobile Ausführung.
- Statusmaschine und idempotente Commands; Start/Anfahrt/Pause/Fortsetzung/Abschluss; Zeitsegmente mit Korrekturevents.
- Beobachtungen, Team-Sichtbarkeit, Übergabe, Offline-Sync-Konzept.
- Fertig, wenn der vollständige Einsatzworkflow E2E, RLS-negativ und fachlich positiv getestet ist.

## Gate 3: Dokumentation und Clinical Safety

- Serverbasierter KI-Adapter (Provider/Verträge separat freigeben), Beobachtungs-/Zeitprovenienz, strukturierte Drafts, Warnungen.
- Menschliche Prüfung/Freigabe, unveränderliche Version und Qualitätsereignis-Eskalation.
- Fertig, wenn kein ungeprüfter Entwurf als final/abrechenbar erscheint und Halluzinations-/Safety-Tests bestanden sind.

## Gate 4: Teamautonomie und Matching

- Verfügbarkeit, Teamkalender, Teamentscheid, Vertretung; kein versteckter Linienmanager.
- Mehrfach-Teamstandorte/Geocoding, Kompetenz-/Qualifikationsdaten, Kapazität je Zeitfenster.
- Matching Engine zunächst Dry Run, fachliche Evaluation und Versionierung; keine früheren Seed-Scores übernehmen.
- Kandidaten-Upsert nach Dublettencheck/Unique-Constraint; atomarer Teamentscheid.

## Gate 5: Assessment/Rule-Platform/LTCF

- Vollständige hochauflösende OCR der vier bildbasierten PDF-Teile und fachliche Prüfung jeder Regel/Tabellenstelle; Rechteklärung.
- Handbuchmatrix, versionierte Rule Engine, Smart Input, Explainability, Architect Mode und Impact Analysis.
- Lizenzierter LTCF-CH-Adapter, PAG-Läufe, MQI-Definitionen/Datenqualität/Snapshots/Export mit autorisierten Referenzfällen.
- Fertig erst mit Quellen-Traceability und klinisch freigegebener Testabdeckung für jede erforderliche Regel.

## Gate 6: Partner, Finance Intelligence und Abrechnung

- Spital/Heim/Privat-Zuführung mit Zweckbindung; Payer-/Tarif-/Vertragsmodell und Kanton.
- Billing-Fakten nur aus validierter Pflege, Zeit, freigegebener Doku und ohne Quality Hold; Payroll separat.
- Budget-/Forecast-Szenarien mit Annahmen und Unsicherheiten; Teamökonomie transparent, rechtlich geprüft.
- Stripe nur bei geklärtem Anwendungsfall; Render nur nach Hostingentscheidung.

## Gate 7: Pilot und Skalierung

- Staging-Durchstich, Security Review, Restore, Accessibility und mobile Offline-Tests.
- Pilot mit wenigen selbstorganisierten Teams, Partnern nach geklärter Zulassung und Versorgungspflicht.
- KPIs: administrative Minuten/Einsatz, Pflegezeit, Berichtfreigabe, Qualität/SLA, Teamzufriedenheit/Absenzen, Kosten und Entlöhnung pro Arbeitsstunde. Ausweitung nur nach evidenzbasierter Prüfung.

## Erste Aufgaben des neuen Coding Agent

1. **VERIFY AGAINST REPOSITORY** — aktuellen Code exportieren/inventarisieren; niemals alte ZIP-Module ungeprüft überschreiben.
2. Read-only Audit: Live-Supabase RLS, Tabellen, FKs, Grants, PostGIS, Jobs, Migration-History und Matching-Daten; Ergebnisse ohne Patientendaten dokumentieren.
3. Sicheren Auth/RLS-Vertikalschnitt auf einem Branch umsetzen und negative Tests hinzufügen.
4. Nach Fachreview Field-Tool-Vertikalschnitt implementieren.
5. Architekturpakete nur als Entwurfsvorlagen nutzen; produktive DB-/klinische Regeln separat genehmigen.
