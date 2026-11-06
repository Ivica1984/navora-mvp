# NAVORA Founder Executive Report

**Für:** den Owner (Founder) · **Verfasst von:** Product Owner (`po`) · **Ausgabe:** KW 45, Stand Freitag, 6. November 2026, 09:05 (Europe/Zurich) · **Nächste Ausgabe:** Freitag, 13. November 2026 · **Rhythmus:** jeden Freitag bis 17:00 neu geschrieben (die Vorwoche bleibt in der Git-Historie).

**Dieses Dokument ist das primäre Entscheidungsdokument des Owners.** Es zeigt nur, was fertig ist, was gebaut wird und was Sie entscheiden müssen. Detailquellen: [Blueprint V2](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md) (Meilensteine, Gates, Kennzahlen), [Owner-Agenda](../agents/decisions/OWNER_AGENDA.md) (jede Frage mit Paket). Der PO hat für diesen Bericht keine Tests ausgeführt; CI-Ergebnisse sind über die GitHub-API gelesen.

---

## Auf einen Blick (1 Minute)

| | |
|---|---|
| **Gesamtstatus** | 🟡 At Risk |
| **Lieferung** | 🔴 Blocked: 12 fertige, grüne, klinisch freigegebene Engineering-PRs warten auf den Merge |
| **Pilot M9 (12.03.2027) auf Kurs?** | **NEIN**: nicht wegen der Technik, sondern wegen offener Owner-Entscheide |
| **Wichtigste Antwort diese Woche** | Merge-Schritt in den Prompt der geplanten PO-Aufgabe (FD-01), D-1 beantworten, Clinical Owner benennen |
| **Wie viele Entscheide warten auf Sie?** | 20 (4 kritisch, 8 hoch, 5 mittel, 3 niedrig) |

**In einem Satz:** Das fachliche Fundament steht und Engineering baut schneller als geplant. Der Pilot hängt jetzt an Ihren Entscheiden, vor allem am Clinical Owner, am Partner und an D-1.

---

## 1. Abgeschlossene Lieferungen

### 1.1 Meilensteinfortschritt

Gezählt wird nur Arbeit auf `recovery/main`. „Gebaut“ meint offene PRs mit grüner CI; sie zählen nicht.

| Meilenstein | Ziel | Abgeschlossen | Gebaut | Status |
|---|---|---|---|---|
| M1 Liefergrundlage | 13.11.2026 | 50 % | 90 % | 🟡 |
| M2 Eine Web-App | 27.11.2026 | 20 % | 75 % | 🟡 |
| M3 Owner-Entscheide | 11.12.2026 | 10 % | – | 🔴 |
| M4 KI-Fundament I (Tagesvorschlag) | 18.12.2026 | 0 % | 70 % | 🟡 |
| M5 Website | 15.01.2027 | 15 % | – | 🟡 |
| M6 Pflege-App | 29.01.2027 | 10 % | – | 🟡 |
| M7 Angehörigenansicht | 05.02.2027 | 35 % | 45 % | 🟢 |
| M8 Operations v2 + KI II | 19.02.2027 | 5 % | 10 % | 🟢 |
| M9 Pilotreife | 12.03.2027 | 8 % (2 von 25 Gates) | – | 🔴 |
| M10 Produktionsreife | 30.06.2027 | 0 % | – | 🔴 |

### 1.2 Lieferungen

| Abgeschlossen | Wirkung | Meilenstein | Abnahmestatus |
|---|---|---|---|
| **47 Fähigkeiten über die ganze Versorgungskette** (bis 31.10.): Zuweisung, Fall, Matching, Teamentscheid, Selbstplanung, Einsatz, Dokumentation und Signatur, Qualität, Abrechnungsfakten, Auswertung; dazu Sicherheitssignale aufs Telefon, Abwesenheit ohne Telefonkette, Teamvertretung ohne Disponent:in, Übergabe ohne Teamsitzung, Zugriffsrechte, Audit, Austritt, KI-Vorschlagsprotokoll | Das Betriebsmodell für selbstorganisierte Teams ist auf synthetischen Daten vollständig nachgebaut. Disponent:in, Übergaberapport und Stundenzettel sind im Modell ersetzt. | Fundament für M9 | **abgenommen** (je mit klinischem Gate) |
| Eine App-Shell für alle Rollen, Startseite je Rolle (#799) | Erster Schritt zu einer App auf Telefon und Desktop | M2 | gemergt; UX2 als Ganzes noch nicht abgenommen |
| Design-Baseline: 57 Screens, Navigation, Designsystem (#834) | Design für Website, Web-App, Pflege-App und Operations-App steht, 17 Tage zu früh | M1 | **abgenommen** |
| Implementierungsreihenfolge M2–M8 (#833) | Bauabfolge und Aufwand je Meilenstein | M1 | gemergt |
| Entscheidungsgrundlage Hosting D-2 (#838) | Sie können D-2 auf belastbarer Basis entscheiden | M3 | gemergt |
| Delivery Program M1–M10 (#832) und Blueprint V2 (#898) | Messbarer Ausführungsplan mit Abnahmekriterien, kritischem Pfad und Wochenkennzahlen | alle | gemergt |
| Ihre Entscheide D-39 (keine Sensoren im Pilot) und D-40 (nur lesende Angehörigenansicht) | Pilotumfang geklärt; FAM1 kann gebaut werden | M7 | umgesetzt in Planung |

### 1.3 Abgeschlossene Prüfungen (diese Woche)

| Prüfung | Ergebnis |
|---|---|
| Klinisches Gate (Clinical & Regulatory) auf dem gesamten Tagesvorschlag-Stapel und den UX2-Teilen | frei, kein blockierender Befund |
| Legal & Compliance zu Einwilligung von Angehörigen (D-40) und Planungssichtbarkeit (D-35) | konform unter jeder plausiblen Auslegung (beratend); eine Frage an den Rechtsberater offen |
| KI-Architektur-Review 32 | KI-Kontrollen der Stufe 0 auf dem Tagesvorschlag erfüllt |
| PO-Entscheide zum Tagesvorschlag (PLAN3-15 bis -17) | entschieden; Engineering setzt um |

---

## 2. Laufende Arbeit

| Fähigkeit | Verantwortlich | Status | Geschätzter Abschluss |
|---|---|---|---|
| **Tagesvorschlag für Teams (PLAN3):** das Team bestätigt Zeile für Zeile, wer welchen Einsatz übernimmt, mit Kontinuität vor freier Kapazität | Engineering | gebaut in 11 PRs (#876 bis #895), grün, klinisch frei; nicht gemergt | Merge bis 27.11., Rest bis 04.12. (mit FD-01) |
| **Eine App auf Telefon und Desktop (UX2)** | Engineering | 4 Teile gebaut und grün, 1 gemergt | 27.11.2026 (mit FD-01 und D-7/D-8) |
| KI-Sicherungen AIG1-C4/-C5 (abgelaufene Vorschläge, Stopp-Nachverfolgung) | Engineering | gebaut, grün | 20.11.2026 |
| Auswertung „Wohin geht die Nicht-Pflegezeit?“ (AN3) | Engineering | gebaut, grün | 11.12.2026 |
| Aufwandsschätzung und Lieferpläne Website/App (#835, #837) | Engineering | gebaut | 13.11.2026 |
| Konfliktfreie Zusammenarbeit (ein Journal-Eintrag pro Datei, Merge-Gate-Skript) | Engineering | geplant | 13.11.2026 |
| Briefs Website (WEB1) und KI-Orchestrator (AIO1) | Product Owner | geplant | 20.11.2026 |
| Brief Pflege-App (MOB1) | Product Owner | geplant | 27.11.2026 |
| Briefs Operations v2 (OPS2) und Übergabe (HAND2) | Product Owner | geplant | 04.12.2026 |
| Angehörigenansicht (FAM1) | Product Owner, dann Engineering | Brief-Entwurf; Legal- und Clinical-Inputs liegen vor | Brief-Freigabe nach Merge der Inputs (Nov.) |
| Texte für Tagesvorschlag und Website-Seitendesign | UX/UI Design Architect | laufend | 04.12.2026 |
| Basel-Prüfung der kantonalen Rechtsfragen | Legal & Compliance | wartet auf Ihre Bestätigung von D-11 | 2 Wochen nach D-11 |

---

## 3. Owner Decision Board

Nur Entscheide, die **Sie** treffen müssen. Jede Zeile beantworten Sie mit einem Satz (z. B. „FD-07: genehmigt“). Bis zur Antwort gilt der sichere Default im Paket. Die Fristen sind die spätesten Daten, an denen M9 noch hält (PO-Schätzung).

### Critical

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FD-01 | **Merge-Schritt in der geplanten PO-Aufgabe** | Fertige Arbeit erreicht die Hauptlinie sonst nur in Sitzungen mit Ihnen | **sofort** | M1, M2, M4 | Absatz aus `PO_MERGE_PROCESS.md` §3 (1) in den Task-Prompt einfügen; Lauf stündlich zu Minute 39 | Rückstand und Konfliktarbeit wachsen täglich; M2 hält den 27.11. nicht |
| FD-02 | **G-1 Clinical Owner** und Stellvertretung | Nur diese Person gibt klinische Regeln frei und entscheidet 9 klinische Pakete; ohne sie kein Pilot | 27.11.2026 | M9, Offline-Notfallnummer, 9 Pakete | Route B; oder PO mit Suchprofil und Mandat beauftragen | M9 verschiebt sich Woche für Woche |
| FD-03 | **D-1 Live-Datenbank** | Mögliche reale Daten im alten System; Meldepflicht ungeklärt | 20.11.2026 | jede reale Datenverarbeitung, D-7, Bereinigung (SR-26) | Fakten liefern, Rechtsberatung und Datenschutzverantwortliche benennen, Review-Datum setzen, Schlüsselrotation genehmigen | rechtliches Restrisiko; kein Pilot |
| FD-04 | **D-11 Pilotkanton** | Ihre Richtung Basel (3.11.) ist nicht erfasst; die Agenda fragt noch Zürich | 27.11.2026 | Tarif-, Aufbewahrungs- und Qualifikationsfragen, Partnersuche | Basel bestätigen, **mit einem Kanton zuerst** (BS oder BL), 2–5 Gemeinden nennen | doppelte Rechtsarbeit; M3 offen |

### High

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FD-05 | Rechtsberater im Pilotkanton | Mehrere Rechtsfragen bleiben ohne Berater ungelöst | 27.11.2026 | Abrechnung, Aufnahme, Aufbewahrung, Angehörige, Partner-LOI | einen Berater benennen | Datenschutz-Folgenabschätzung nicht möglich |
| FD-06 | D-12 lizenzierter Partner | Lizenz und OKP-Zulassung für Abrechnung | 11.12.2026 | Abrechnung, Folgenabschätzung, D-38 | Partner im gewählten Kanton nennen | keine Abrechnung, kein Pilot |
| FD-07 | D-7 Repository-Schutz | Technischer Schutz vor Fehl-Pushes; Bedingung für D-8 | 20.11.2026 | M2 | Option B: Ruleset, Secret Scanning, privat auf bezahltem Plan | M2 nicht abnahmefähig |
| FD-08 | D-8 Hauptlinie nach `main` | `main` ist veraltet | nach FD-07 | M2 | Option B | Projekt sieht alten Stand |
| FD-09 | D-2 Hosting (Staging, Produktion, EU/CH) | Ohne Staging kein Restore-Test, keine Pilotumgebung | 11.12.2026 | M9 Technik | genehmigen (Grundlage #838) | M9 verschiebt sich |
| FD-10 | D-29 Qualifikationsprüfung | Keine reale Pflegeperson ohne geprüfte Qualifikation | 11.12.2026 | reale Einsätze | Option B als Gate | kein Einsatz realer Personen |
| FD-11 | Regulierungsberater (Medizinprodukt, D-34) | Zweckbestimmung muss geprüft sein | 11.12.2026 | Go-live-Gate G-5, KI auf hoher Stufe | Berater benennen | Gate G-5 bleibt offen |
| FD-12 | D-38 Bedingungen der Partner-Absichtserklärung | Sichert den Übergang zum teameigenen Anbieter | vor jeder LOI | Partnervertrag | T1–T18 genehmigen | Teamautonomie nicht vertraglich gesichert |

### Medium

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FD-13 | D-14 Gebührenmodell | Faire Teamökonomie, höheres Pflegeeinkommen sichtbar | 11.12.2026 | J7 Teamökonomie | F3 (pro aktivem Teammitglied und Monat) | J7 bleibt Entwurf |
| FD-14 | Website: Domain, Hosting, Empfänger der Demo-Anfragen | Website kann nicht live | 11.12.2026 | M5 | mit D-2 entscheiden | M5 rutscht |
| FD-15 | D-26 kein Service-Key auf dem App-Server | Sicherheit in Produktion | vor M9 | Einladungen in Produktion | genehmigen | Einladungen nicht produktionsfähig |
| FD-16 | D-36 interRAI-Lizenzbedingungen an Legal geben | Fakt, kein Entscheid | 11.12.2026 | D-37 | Bedingungen liefern | D-37 wartet |
| FD-18 | Blueprint und diesen Bericht in die Prompts aller geplanten Agenten-Aufgaben aufnehmen | Agenten dürfen ihre eigenen Aufgaben nicht ändern | 13.11.2026 | einheitliche Arbeitsgrundlage | Link auf Blueprint V2 ergänzen | Agenten lesen ihn nur indirekt |

### Low

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FD-17 | SR-26 fremde Tabelle in der Live-Datenbank | Datenbank-Hygiene | nach FD-03 | – | Option A | gering |
| FD-19 | D-22, D-18, D-9, D-4 an den Berater geben | Rechtsfragen beantworten | nach FD-05 | Abrechnung, Aufnahme | gemäss Paketen | Defaults bleiben |
| FD-20 | D-24, D-25, D-37 (Pflegeheime, interRAI) | Horizont 3 | keine im Pilot | – | D-24 A (jetzt kein Bau) | keine |

---

## 4. Kritischer Pfad

Die fünf Entscheide oder Handlungen mit der grössten Wirkung auf M9 und M10, nach Wirkung geordnet:

| Rang | Entscheid oder Handlung | Wirkung auf M9 (Pilot) | Wirkung auf M10 (Produktion) | Spätestens |
|---|---|---|---|---|
| 1 | **Clinical Owner benennen (FD-02)** | Ohne sie kein Go-live: keine klinische Regel freigegeben, kein klinisches Gate geschlossen | Pilotauswertung und Freigabe weiterer Teams ohne klinische Verantwortung unmöglich | 27.11.2026 |
| 2 | **Pilotkanton und Partner (FD-04, FD-06), mit Rechtsberater (FD-05)** | Lizenz, OKP-Zulassung, Folgenabschätzung durch den Lizenzinhaber | Ohne Partner keine drei stabilen Pilotmonate | Kanton 27.11.2026, Partner 11.12.2026 |
| 3 | **D-1 Live-Datenbank klären (FD-03)** | Keine realen Daten erlaubt, solange offen (Ihre Regel vom 29.10.) | Rechtliches Restrisiko bleibt bis zur Produktion | 20.11.2026 |
| 4 | **Hosting D-2 (FD-09)** | Staging, Restore-Test und Runbooks dauern zusammen etwa 4 Wochen nach Ihrer Antwort | Monitoring, Backups und externer Sicherheitstest bauen darauf auf | 11.12.2026 |
| 5 | **Merge-Schritt (FD-01)** | Hält M2, M4 und M6 auf Kurs; Engineering hat sonst etwa 6 Wochen Puffer | Jede Woche Rückstand frisst Puffer für die drei Pilotmonate | sofort |

---

## 5. Die nächsten 14 Tage (6.–20. November 2026)

Alles unter der Annahme, dass FD-01 diese Woche umgesetzt ist. Ohne FD-01 wird nur in Sitzungen mit Ihnen gemergt.

| Art | Erwartet | Datum |
|---|---|---|
| **Meilenstein** | M1 Liefergrundlage abgeschlossen (Schätzung und Lieferpläne gemergt) | 13.11.2026 |
| **Meilenstein** | Delivery-Daten neu berechnet aus der Engineering-Schätzung | 17.11.2026 |
| **Meilenstein (Teil)** | M2: UX2-Teile, RLS4-C3 und Testsicherheit CGR-110 gemergt | 13.–20.11.2026 |
| **Meilenstein (Teil)** | M4: KI-Sicherungen AIG1-C4/-C5 und Tagesvorschlag Teil (a) gemergt | 20.11.2026 |
| **Prüfung** | PO-Abnahme der gemergten UX2-Teile und des Tagesvorschlag-Stapels (mit klinischem Gate) | laufend ab Merge |
| **Prüfung** | Clinical Gate auf den neuesten Tagesvorschlag-PRs; Liste aller offenen S1/S2-Befunde für die Pilotakte | 13.11.2026 |
| **Prüfung** | Freigabe Brief FAM1, sobald Legal- und Clinical-Inputs gemergt sind | bis 20.11.2026 |
| **Umsetzung** | Konfliktfreie Zusammenarbeit (ein Journal-Eintrag pro Datei, Merge-Gate-Skript) | 13.11.2026 |
| **Umsetzung** | Tagesvorschlag: neue Anfrage schliesst alte Zeilen (PLAN3-15) | 20.11.2026 |
| **Umsetzung** | Briefs WEB1 und AIO1 | 20.11.2026 |
| **Ihre Fristen in diesem Zeitraum** | FD-01 sofort; FD-03 (D-1) und FD-07 (D-7) bis 20.11. | – |

---

## 6. Risiken

| Art | Risiko | Owner | Gegenmassnahme | Aktueller Status |
|---|---|---|---|---|
| Lieferung | Fertige Arbeit bleibt ungemergt; jeder Merge erzeugt Konflikte in allen anderen PRs | Owner (FD-01), dann Engineering | Merge-Schritt; ein Journal-Eintrag pro Datei | 🔴 12 PRs warten |
| Lieferung | Der 11-teilige Tagesvorschlag-Stapel wird beim Mergen inkonsistent | PO, Engineering | in Reihenfolge mergen; klinisches Gate je Kopf | 🟡 alle Köpfe grün und frei |
| Lieferung | Briefs für Website, Pflege-App und Operations kommen zu spät | PO | feste Termine 20.11., 27.11., 4.12. | 🟢 im Plan |
| Governance | Kein Clinical Owner | Owner | FD-02 | 🔴 offen seit 27.10. |
| Governance | M3-Entscheide nach dem 11.12. verschieben M9 und M10 Tag für Tag | Owner | ein Entscheid-Termin für die Agenda-Gruppe 2 | 🔴 ca. 10 % entschieden |
| Governance | Strategie-Rolle seit 3.11. ohne Eintrag | Owner (prüft die geplante Aufgabe) | Aufgabe prüfen | 🟡 unbekannt |
| Regulatorisch | D-1: möglicherweise reale Daten im alten System | Owner | FD-03 | 🔴 offen seit 29.10. |
| Regulatorisch | Medizinprodukt-Einstufung offen, sobald KI Inhalte vorbereitet | Owner, Legal | Regulierungsberater; KI bleibt regelbasiert | 🟡 kein Risiko im Pilot, solange KI regelbasiert bleibt |
| Regulatorisch | Zwei Kantone verdoppeln Rechts- und Tarifarbeit | Owner, Legal | ein Kanton zuerst | 🟡 Richtung Basel nicht erfasst |
| Betrieb | Kein Staging, kein Restore-Test | Owner (D-2), Engineering | FD-09; Restore-Test vor M9 | 🔴 blockiert |
| Betrieb | Kein lizenzierter Partner, keine Abrechnung | Owner | FD-06; teameigener Anbieter (Route C) vorbereitet | 🔴 offen |

---

## 7. Founder Actions

Nur Handlungen, die Ihre Beteiligung brauchen.

**Diese Woche (bis 13.11.2026):**

1. **Merge-Schritt aktivieren (FD-01):** den Absatz aus `docs/agents/PO_MERGE_PROCESS.md` §3 (1) in den Prompt der geplanten PO-Aufgabe einfügen. Am gleichen Ort den Link auf Blueprint V2 und diesen Bericht in die Prompts der übrigen Agenten aufnehmen (FD-18).
2. **D-1 beantworten (FD-03):** Herkunft der Daten (ja / nein / unsicher), Rechtsberatung und Datenschutzverantwortliche nennen, Review-Datum setzen, Leaked-Password-Schutz einschalten.
3. **Pilotkanton bestätigen (FD-04):** „D-11: Basel, Start in BS (oder BL), Gemeinden …“.

**Diesen Monat (bis 30.11.2026):**

1. **Clinical Owner und Stellvertretung benennen (FD-02)**, oder den PO beauftragen, Suchprofil und Mandat zu entwerfen.
2. **Rechtsberater im Pilotkanton benennen (FD-05)** und **Repository-Schutz D-7 genehmigen (FD-07)**, danach D-8.
3. **Einen Entscheid-Termin für Agenda-Gruppe 2 festlegen** (Partner, D-2, D-29, Regulierungsberater, D-14, D-38), damit M3 bis 11.12. abgeschlossen ist.

---

## Pflege dieses Berichts

- Der PO schreibt diesen Bericht jeden Freitag bis 17:00 neu, aus den Kennzahlen in Blueprint V2 §10. Die Vorwoche bleibt in der Git-Historie.
- Ein beantworteter Entscheid verschwindet aus §3 und erscheint in §1 der nächsten Ausgabe.
- Unbekannte Werte stehen als UNKNOWN da und werden nie geschätzt, ohne dass es dasteht.
- Keine Personen- oder Gesundheitsdaten in diesem Dokument.
