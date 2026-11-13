# NAVORA — Product Requirements

> **ARCHIVIERT (FE-077, 2026-11-13):** Historisches Übergabedokument (Stand Oktober 2026). Massgeblich sind allein [Blueprint V3.2](docs/product/ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V3.md) (fachlich) und [Architecture Handbook V2.2](docs/architecture/ARCHITECTURE_HANDBOOK_V2.md) (technisch). Kein Agent leitet aus diesem Dokument Vorgaben ab.

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

## KI und Automation [DECIDED: Kernsäule, Owner 2026-11-03; Umsetzung PLANNED, Governance IMPLEMENTED]

NAVORA ist eine AI-first-Plattform. KI ist eine Kernfähigkeit jeder Journey und keine spätere Zusatzfunktion. Jede Anforderung und jeder Brief beantwortet, wie die Arbeit gestaltet wäre, wenn KI von Anfang an existiert hätte (Abschnitt *AI leverage*; Methode und Prinzipien AI-1 bis AI-12 in `docs/product/AI_FIRST_ARCHITECTURE_UPDATE.md`).

**KI soll:**
- Administration abbauen;
- Kontinuität und Qualität verbessern;
- Nachvollziehbarkeit erhöhen;
- Risiken früher sichtbar machen;
- repetitive Arbeit automatisieren.

**Verbindliche Reihenfolge (Owner, 2026-11-03):** Unnötige Arbeit entfernen → Regeln anwenden → kontinuierlich überwachen → KI bereitet vor → Mensch prüft → Mensch entscheidet → Mensch unterschreibt.

KI darf vorbereiten, zusammenfassen, priorisieren, entwerfen, überwachen und vorschlagen. Sie trifft keine verantwortlichen Entscheide, ersetzt keine Unterschriften oder Freigaben und übt kein klinisches Urteil aus.

Sensoren (D-39) sowie Angehörigen-Kanal und Check-in (D-40) sind eingefroren: nur Spezifikation.

**Formen:**
- Vorschläge (Planung, Vertretung, Zuweisung);
- Entwürfe (Bericht, Übergabe, Verordnungserneuerung, Antworten);
- Extraktion (Zuweisung, Diktat);
- kontinuierliches Monitoring (Lieferung, Vollständigkeit, Kontrollen, Agenten).

**Jede Ausgabe:**
- nennt Quellen, Zeitraum, Unsicherheit und was nicht gefunden wurde;
- steht im unveränderlichen Vorschlagsprotokoll;
- wird erst durch eine benannte Person zu Datensatzinhalt.

**KI darf nie:**
- klinische Regeln überschreiben;
- Verantwortung oder vorgeschriebene Unterschriften ersetzen;
- unkontrollierte klinische Entscheide treffen;
- Zeit erfinden;
- Berichte final signieren;
- Diagnosen stellen;
- autonom abrechnen oder codieren;
- P1-Sicherheitssignale priorisieren;
- Personen bewerten (keine Leistungsprofile);
- Klientinnen, Klienten oder Angehörigen klinischen Rat geben.

**Zehn operative KI-Domänen (PLANNED):** Dokumentation, Übergabe, Angehörige, Check-in, Personalkoordination, Operations-Monitoring, Qualitäts-Monitoring, Evidenz für Assessments, Zuweisungsvorbereitung, Assistenz für Pflegende. Reihenfolge und Gates: `docs/product/AI_CAPABILITY_ROADMAP.md`.

**Gates unverändert:**
- D-35 Regel A: im Pilot keine Daten an KI-Dienste bis zum Owner-Paket Stufe 1;
- D-34 A plus C: klinische KI nur im separat qualifizierten Modul;
- D-1;
- G-1.

## Nichtfunktional

Sicherheit und Datenschutz ab Beginn; Datenminimierung; barrierearmes Mobile UI; Offline-Idempotenz; Revisionsfähigkeit; Nachvollziehbarkeit; kontrollierte Multi-Tenancy; testbare Skalierung; Versionen/Migrationen; Mehrsprachigkeit **PLANNED/OPEN**. Ziel „bis zu 5'000 Teams“ im Handbuch ist ein Designziel, keine getestete Kapazität.

## Abnahmegates

1. Vor echtem Patienteneinsatz: Care-Verantwortlichkeiten, Auth/RLS, Datenschutz-Folgenabschätzung, Zugriffs-/Aufbewahrungsregeln, Incident und Restore geprüft.
2. Field MVP: berechtigter Einsatz, Zeit, Beobachtung, Übergabe, Audit und Fehlerpfade E2E geprüft.
3. KI: Quellenbindung, Validierung, menschliches Review und Sicherheitsevaluation; Agentenvertrag, Evaluation auf synthetischen Fällen, Korrekturquote und Stoppregel je Agent (AIG1, AIO1); Anbieter, Region und Vertrag per Owner-Entscheid (D-35 Stufe 1); Niveau G/H nur nach Antwort der regulatorischen Beratung und im klinischen Modul (D-34).
4. Matching: fachliche Hard Filters, Geodaten-/Qualitätsnachweis, Teamentscheid, Fairness-/Sicherheitsprüfung.
5. LTCF/PAG/MQI: Lizenz/Spezifikation, Referenzfälle, Definitionen, autorisierter Export und fachliche Freigabe.
6. Billing/Payroll: getrennte Faktentypen, Tarife/Verträge/Zulagen/Qualitätsholds fachlich freigegeben.
