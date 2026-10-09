# NAVORA — Domain Rules

**Hinweis:** Nur ausdrücklich im Verlauf bestätigte Fachprinzipien sind **DECIDED**; Zahlen und Statuswerte aus älterem Code sind **IMPLEMENTED (legacy)**, keine freigegebenen klinischen oder tariflichen Regeln. Alle aktuellen Implementierungen: **VERIFY AGAINST REPOSITORY**.

## Teamautonomie [DECIDED]

- Selbstorganisiertes Team plant Einsätze, Vertretungen und Fallannahme selbst. Kein Linienvorgesetzter durch UI-/Rollenmodell erzeugen.
- Team kann viele Fälle, Matching-Anfragen und Pflegeeinsätze übernehmen. Kapazität ist pro Zeitfenster, Kompetenz, Aufwand und Weg zu prüfen; ein Fall ist keine globale Teamsperre.
- NAVORA coacht bei Konflikten; fachliche Arbeitgeber-, Sicherheits- und Qualitätsverantwortung muss separat geklärt sein (**OPEN**).
- Transparente Teamökonomie darf keine verdeckte Individualüberwachung oder rein mengenbasierte Vergütung erzwingen.

## Fall/Matching [DECIDED/PLANNED]

- Partneranfrage kann nach Prüfung in Klientenfall überführt werden; Status- und Zustimmungsgates **OPEN**.
- Matching ist eigener Prozess; Operations löst ihn nicht aus. Matching-Anfrage → Hard Filters (aktives Team, zulässige Kompetenz, verifizierte Qualifikation, tatsächliche Kapazität, Servicegebiet, offene Safety Holds) → Ranking (fachliche Passung, Distanz, Zeitfenster, Kontinuität, Qualität, Überlastung) → Kandidaten → Teamentscheid.
- Keine hohen Passungswerte ohne Evidenz für wesentliche Kompetenzen. Qualität, Kapazität und Risiko sind getrennte Dimensionen.
- Distanz nur aus verifizierten PostGIS-Standorten berechnen, bei fehlenden Daten `NULL`. Keine DEMO-Kilometer für produktive Entscheidungen.
- Gewichte/Schwellenwerte und Versionen sind **OPEN**; frühere einfache `+30/+35`-Beispielwerte oder Scores 85/45 sind **DEPRECATED** als Qualitätsmatching.
- Kandidaten pro Anfrage/Team sollen dedupliziert werden; Unique-Constraint ist **OPEN/VERIFY AGAINST DATABASE**; vor Migration bestehende Daten prüfen.

## Operations Attention [IMPLEMENTED legacy, fachlich zu validieren]

Im älteren `src/features/operations/queries.ts`: Team-Auslastung ≥90 % → P1; ≥80 % oder `open_slots <=1` → P2. Fall ohne Team mit hoher Dringlichkeit oder seit ≥24 h → P1, sonst P2; Teamentscheid ab ≥24 h → P1; dringliche/alte Partneranfrage → P1; abgeschlossener Einsatz ohne freigegebenen Bericht → P2; offenes Qualitätsereignis `critical/high` → P1, sonst P2. Diese konkreten Grenzwerte sind **IMPLEMENTED (legacy)**, nicht als medizinisch oder betrieblich validiert **DECIDED**. Prüfen, ob doppelte Attention-Items und Statusinterpretationen entstehen.

## Einsatz und Zeit [DECIDED/PLANNED]

Geplante Transitionen: `planned → assigned → accepted → on_the_way → started ↔ paused → completed`, zusätzlich sauber definierte `cancelled`/`no_show`-Pfade. Dies ist ein Entwurf und kann vom bestehenden `care_visits.status` abweichen. Jeder Übergang prüft Rolle/Zuständigkeit/erwarteten Status und schreibt ein Event mit actor, Zeit, Idempotency-Key. Keine negativen Zeiten, ungeklärten Überlappungen oder stillen Zeitkorrekturen. Anfahrt, Pflege und Pause getrennt; Lohnrelevanz ≠ Tarifabrechenbarkeit.

## Dokumentation und KI [DECIDED]

Beobachtung/Leistung hat Autor, Quelle und Zeitpunkt; KI-Ergebnis bleibt versionierter Entwurf mit referenzierten Quellen, Modell-/Promptversion, Warnungen, fehlenden Angaben. Mensch prüft und gibt final frei; nachträgliche Änderung als neue Version. Keine autonome Diagnose, Medikationsentscheidung, klinische Freigabe oder erfundene Handlung.

## Assessment, PAG und MQI [DECIDED als Integrationsziel; konkrete Regeln OPEN]

Einmalige Beobachtung mit nachvollziehbarer Provenienz statt Doppelerfassung; lizenzierter/versionierter interRAI-LTCF-CH-Adapter im einschlägigen LTCF-Angebot; PAG-Berechnung mit Spezifikationsversion, Stichtag, Eingabe-Hash, Review; MQI je Definitionsversion, Population, Zähler/Nenner, Datenqualität/Risikoadjustierung, Review und autorisierte Meldung. Exakte Item-Codes, Formeln, Risikoregeln und Rechte sind **UNKNOWN/OPEN**; nicht aus unvalidierten Scans ableiten. MQI nicht als Gesamtqualitäts- oder Personalranking missbrauchen.

## Rule Engine und Erklärbarkeit [DECIDED/PLANNED]

Harte Handbuchregeln als überprüfte Versionen mit Quelle, Gültigkeit, Voraussetzungen, Eingaben, Abhängigkeiten, Ausnahmen, Resultat und Tests. Evaluation deterministisch; KI erklärt und priorisiert, überschreibt keine Regeln. Kritisches Ergebnis erklärt Eingaben, Regeln, Quellstelle, Version und Unsicherheit. Override kritischer Empfehlung erfordert menschlichen Prozess mit optional/je nach Policy erforderlicher Begründung. Regeländerung erfordert Impact Analysis und Regressionstests.

## Qualität, Abrechnung, Lohn [DECIDED/PLANNED]

Qualitätsereignisse fachlich prüfen; offenen Safety Hold nicht im Matching/Billing ignorieren. Abrechenbarer Fakt erst aus abgeschlossenem Einsatz, validierter Zeit und Leistung, freigegebener Dokumentation, erforderlicher Verordnung/Zulassung, aufgelöster Tarif-/Payerregel und ohne Quality Hold. Diese Gates sind Zielarchitektur, nicht als bestehende DB-Funktion nachgewiesen. Payroll basiert auf geprüfter Arbeitszeit und vertraglichen Zuschlägen, nicht auf Rechnungsbetrag. Teamüberschuss nur nach transparenter, rechtlich geprüfter Regel verteilen.

## Datenschutz und Berechtigung [DECIDED]

Zugriff nicht allein durch `authenticated`: Organisation, Team, Versorgungskontext, Rolle/Zweck prüfen. Break-glass begründen, begrenzen, auditieren und reviewen. Sensible Daten nicht an Browser-Analytics, Logs oder externe AI/Geocoding-Anbieter ohne geprüfte Rechts- und Sicherheitsbasis weitergeben. Keine echten Gesundheitsdaten, solange frühere `{public}`-Policies nicht sicher ersetzt sind.
