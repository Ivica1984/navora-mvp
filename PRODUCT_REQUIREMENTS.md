# NAVORA — Product Requirements

**Status:** fachliche Zielanforderungen; bei jeder Funktion zwischen **IMPLEMENTED**, **PLANNED**, **DECIDED**, **OPEN**, **DEPRECATED** und **UNKNOWN** unterscheiden. Aktuelle Implementierung: **VERIFY AGAINST REPOSITORY**.

## Vision und Outcomes

**DECIDED:** Mehr direkte Pflegezeit, weniger Verwaltung, bessere Versorgungsqualität und faire Entlöhnung durch selbstorganisierte Teams. NAVORA organisiert nicht als Linienvorgesetzter. Institutionen/Privatpersonen sind Partner/Anfragende; das rechtliche Leistungs-/Arbeitgebermodell ist **OPEN**. Erfolg durch reale Pilot-KPIs, nicht durch Behauptung einer Überlegenheit gegenüber Buurtzorg.

## Nutzer-Journeys

### Pflegekraft / Field Tool [DECIDED, PLANNED]

Eigene Einsätze sehen → notwendigen Fallkontext und Pflegeziele lesen → Anfahrt/Pflege/Pause mit nachvollziehbarer Zeit → Beobachtungen/Leistungen mobil dokumentieren → Übergabe → KI-Berichtsentwurf korrigieren → menschlich freigeben. Offline-Mutationen idempotent synchronisieren; Daten auf Gerät begrenzen. Vorhandene `/visits`-Seite ist nicht Nachweis dieses Gesamtflusses.

**Akzeptanz:** Eine berechtigte Pflegekraft sieht nur zugewiesene Einsätze; erneutes Senden erzeugt kein Doppelevent; Statusübergänge sind erlaubt; Zeitkorrekturen nachvollziehbar; Bericht ohne Freigabe bleibt Entwurf.

### Selbstorganisiertes Team [DECIDED, PLANNED]

Mehrere Fälle betreuen; Matching-Anfragen gemeinsam prüfen; Annahme/Ablehnung; Verfügbarkeiten und Vertretungen; Einsatzplanung ohne Teamvorgesetzten; Kapazität/Arbeitsbelastung pro Zeitfenster. NAVORA-Coach unterstützt Konflikte, nicht Disposition. Teamentscheid wird auditiert.

### Operations [PARTIAL IMPLEMENTED]

Maximal sechs prioritätsorientierte KPI-Karten, Attention Center, Teamkapazität, SLA, Qualitätsereignisse, offene Entscheidungen und Risikofälle. Kein Matching-Start, keine vollständige Datenverwaltung im Dashboard. Die alte UI und Query sind zu verifizieren.

### Partner / Auftraggeber [PLANNED]

Spital: Überleitung/Nachversorgung; Heim: vertraglich definierte Zusatz-/Übergangsversorgung; Privatperson: Anfrage und zulässige Leistungen. Anfrage → Fall mit Nachvollziehbarkeit; Leistungen/Payer/Verträge trennen. Keine Annahme, dass jede Leistung KVG-fähig ist.

### Fachverantwortliche [PLANNED]

LTCF-CH-/PAG-/MQI-Spezifikationen und Rechte prüfen; Assessments/Quellen validieren; Regelversionen freigeben; Impact Analysis und Testabdeckung überwachen; Qualitätsereignisse reviewen.

### Billing/Payroll [PLANNED]

Freigegebene Einsatz- und Leistungsfakten erzeugen, Tarifversion/Payer bestimmen, Quality Holds prüfen; separat geprüfte Arbeitszeit, Zulagen und Teamökonomie vorbereiten. Keine Rechnungs- oder Lohnautomation ohne rechtliche/fachliche Abnahme.

## Assessment/Clinical Intelligence [PLANNED]

Einmal erfassen, mit Provenienz wiederverwenden; kontinuierliche Veränderungen aus Pflegebeobachtung; strukturierte Assessment-Entwürfe; verifizierte Risikosignale statt ungeprüfter Prognosen; KI erklärt Quellen, Zeitraum, Unsicherheit und fehlende Daten. Kein autonomes Diagnostizieren oder Ändern von Pflegeplänen. Stationäres LTCF-Produkt unterstützt autorisierte interRAI-LTCF-CH-/PAG-/MQI-Prozesse; Anwendbarkeit aufs ambulante Angebot **OPEN**.

## Architect Tool [PLANNED]

Handbuch-Matrix (Kapitel, Frage, Code, Antwort, Regel, Voraussetzung, Ausnahme, Ergebnis, Nachweis, Querverweis); AS-IS/TO-BE; Schwäche→Verbesserung; Rule Repository; deterministische Engine; Smart Input; Explainability; „Warum?“-Ansicht; Human-in-the-loop; Impact Analysis; Versionierung; Tests aus Regeldefinitionen; Dashboard zu Vollständigkeit, Widersprüchen und Freigabefähigkeit. Produktive Regelübernahme erst nach qualitätsgesicherter OCR, fachlicher Prüfung und Rechteklärung.

## KI und Automation [DECIDED/PLANNED]

AI darf Sprache strukturieren, Entwürfe, Lücken und priorisierte Hinweise vorschlagen. Ergebnisse müssen Quelle und Unsicherheit angeben. AI darf harte Regeln nicht überschreiben, keine Zeit erfinden, Berichte final signieren, Diagnosen stellen oder autonom abrechnen.

## Nichtfunktional

Sicherheit und Datenschutz ab Beginn; Datenminimierung; barrierearmes Mobile UI; Offline-Idempotenz; Revisionsfähigkeit; Nachvollziehbarkeit; kontrollierte Multi-Tenancy; testbare Skalierung; Versionen/Migrationen; Mehrsprachigkeit **PLANNED/OPEN**. Ziel „bis zu 5'000 Teams“ im Handbuch ist ein Designziel, keine getestete Kapazität.

## Abnahmegates

1. Vor echtem Patienteneinsatz: Care-Verantwortlichkeiten, Auth/RLS, Datenschutz-Folgenabschätzung, Zugriffs-/Aufbewahrungsregeln, Incident und Restore geprüft.
2. Field MVP: berechtigter Einsatz, Zeit, Beobachtung, Übergabe, Audit und Fehlerpfade E2E geprüft.
3. KI: Quellenbindung, Validierung, menschliches Review und Sicherheitsevaluation.
4. Matching: fachliche Hard Filters, Geodaten-/Qualitätsnachweis, Teamentscheid, Fairness-/Sicherheitsprüfung.
5. LTCF/PAG/MQI: Lizenz/Spezifikation, Referenzfälle, Definitionen, autorisierter Export und fachliche Freigabe.
6. Billing/Payroll: getrennte Faktentypen, Tarife/Verträge/Zulagen/Qualitätsholds fachlich freigegeben.
