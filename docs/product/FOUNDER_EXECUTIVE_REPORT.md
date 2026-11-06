# NAVORA Founder Executive Report

**Für:** den Owner (Founder) · **Verfasst von:** Product Owner (`po`) · **Ausgabe:** KW 45, Stand Freitag, 6. November 2026, 14:45 (Europe/Zurich), nachgeführt nach Ihren Freigaben vom 6. November (Prompts, Merge-Test, SR-26, Arbeitsbuch, M9) · **Nächste Ausgabe:** Freitag, 13. November 2026 · **Rhythmus:** jeden Freitag bis 17:00 neu geschrieben (die Vorwoche bleibt in der Git-Historie).

**Dieses Dokument ist das primäre Entscheidungsdokument des Owners.** Es zeigt nur, was fertig ist, was gebaut wird und was Sie entscheiden müssen. Detailquellen: [Blueprint V2](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md) (Meilensteine, Gates, Kennzahlen), [Owner-Agenda](../agents/decisions/OWNER_AGENDA.md) (jede Frage mit Paket). Der PO hat für diesen Bericht keine Tests ausgeführt; CI-Ergebnisse sind über die GitHub-API gelesen.

---

## Auf einen Blick (1 Minute)

| | |
|---|---|
| **Gesamtstatus** | 🟡 At Risk |
| **Lieferung** | 🟡 At Risk: Merge-Testlauf bestanden (#800 gemergt, CI grün); ab jetzt mergt der PO stündlich ein Engineering-PR. Rund 11 fertige PRs warten noch |
| **Pilot M9 (12.03.2027) auf Kurs?** | **NEIN, aber deutlich näher:** M9 ist neu gefasst (Phase A bestanden + Bereitschaftsakte Phase B) und bestätigt; der Merge-Pfad läuft. Grösstes Risiko bleibt die neue Pflegeheim-Abteilung |
| **Wichtigste Antwort diese Woche** | Weg für die Löschung der `orders`-Tabelle wählen (FD-27): das alte Live-Projekt ist pausiert |
| **Wie viele Entscheide warten auf Sie?** | 11 (0 kritisch, 6 hoch, 4 mittel, 1 niedrig) |

**In einem Satz:** Das fachliche Fundament steht, Engineering baut schneller als geplant, und Ihre Richtung vom 6.11. nimmt Partner, Rechtsberater und D-1 vom kritischen Pfad. Neu ist die grösste Bauaufgabe: das simulierte Pflegeheim für Phase A.

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
| **Tagesvorschlag für Teams (PLAN3):** das Team bestätigt Zeile für Zeile, wer welchen Einsatz übernimmt, mit Kontinuität vor freier Kapazität | Engineering | gebaut in 11 PRs (#876 bis #895), grün, klinisch frei; nicht gemergt | Merge bis 27.11., Rest bis 04.12. (Merge läuft seit FE-033) |
| **Eine App auf Telefon und Desktop (UX2)** | Engineering | 4 Teile gebaut und grün, 2 gemergt (#799, #800) | 27.11.2026 (Merge läuft; D-7/D-8 offen) |
| KI-Sicherungen AIG1-C4/-C5 (abgelaufene Vorschläge, Stopp-Nachverfolgung) | Engineering | gebaut, grün | 20.11.2026 |
| Auswertung „Wohin geht die Nicht-Pflegezeit?“ (AN3) | Engineering | gebaut, grün | 11.12.2026 |
| Aufwandsschätzung und Lieferpläne Website/App (#835, #837) | Engineering | gebaut | 13.11.2026 |
| Konfliktfreie Zusammenarbeit (ein Journal-Eintrag pro Datei, Merge-Gate-Skript) | Engineering | geplant | 13.11.2026 |
| Briefs Website (WEB1) und KI-Orchestrator (AIO1) | Product Owner | geplant | 20.11.2026 |
| Brief Pflege-App (MOB1) | Product Owner | geplant | 27.11.2026 |
| Briefs Operations v2 (OPS2) und Übergabe (HAND2) | Product Owner | geplant | 04.12.2026 |
| Angehörigenansicht (FAM1) | Product Owner, dann Engineering | Brief-Entwurf; Legal- und Clinical-Inputs liegen vor | Brief-Freigabe nach Merge der Inputs (Nov.) |
| Texte für Tagesvorschlag und Website-Seitendesign | UX/UI Design Architect | laufend | 04.12.2026 |
| Basel-Prüfung der kantonalen Rechtsfragen (D-18, D-25, D-9, D-4, D-29) | Legal & Compliance | angefragt am 6.11. (D-11 entschieden) | ca. 20.11.2026 |
| Optionen für einen geprüften KI-Pfad mit realen Daten (D-41) | PO mit Legal, Clinical, Engineering | Inputs angefragt; D-35 Regel A bleibt | Paket bis 04.12.2026 |
| Vergleich der Abrechnungsmodelle | Product Owner | erstellt (`PRICING_MODEL_COMPARISON.md`) | Preisentscheid nach Phase A |

---

## 3. Owner Decision Board

Nur Entscheide, die **Sie** treffen müssen. Entschieden am 6.11. und nicht mehr gefragt: D-1 (keine echten Personendaten), D-11 (Basel-Stadt und Basel-Landschaft), D-24 (Pflegeheim im Umfang), Pilotphasen A/B, Umfang Phase A (ambulant + Pflegeheim) ([Entscheidungsliste](FOUNDER_DECISIONS.md)). Nicht jetzt gefragt: Partner, Rechtsberater, Preis (D-14), D-29, D-38. Herleitung jeder Frage: [Bestätigung vom 6.11.](FOUNDER_DIRECTION_CONFIRMATION_2026-11-06.md) §4.

### Critical

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|

### High

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FD-27 | **Weg für die Löschung der Tabelle `orders` (SR-26)** | Sie haben die Löschung angeordnet; das alte Live-Projekt ist pausiert, SQL ist nicht möglich | 13.11.2026 | Ihre SR-26-Anweisung | (b) das ganze alte Projekt löschen: NAVORA nutzt es nicht, Tabelle **und** Backups verschwinden sicher; oder (a) Projekt für eine datierte Sitzung wiederherstellen, ich lösche die Tabelle, danach wieder pausieren (Kopien in Backups bis Ablauf der Aufbewahrung) | E-Mail-Adressen bleiben im pausierten Projekt liegen |
| FD-22 | KI-Anbieter nur für synthetische Daten in Phase A | Ohne Anbieter lassen sich KI-Dokumentation und KI-Prüfungen nicht echt testen (D-35 Regel A bleibt) | 27.11.2026 | DOC-AI, Abrechnungsprüfung | einen CH/EU-Anbieter mit Vertrag nur für synthetische Daten | Phase A testet nur Regel-Ersatz |
| FD-02 | Clinical Owner (Phase B) und klinische Fachprüfung des simulierten Pflegeheims (Phase A) | Nur sie gibt klinische Regeln frei; ein Pflegeheim ohne Fachblick wird falsch modelliert | 15.01.2027 | Phase B; Plausibilität von M9.0 | jetzt eine Fachperson für die Simulation, Clinical Owner bis Phase B | Phase B startet ohne freigegebene Regeln |
| FD-07 | D-7 Repository-Schutz | Schutz vor Fehl-Pushes; Sichtbarkeit ist nach D-1 Ihre freie Wahl | 20.11.2026 | D-8, M2 | Ruleset und Secret Scanning genehmigen | M2 nicht abnahmefähig |
| FD-08 | D-8 Hauptlinie nach `main` | `main` ist veraltet | nach FD-07 | M2 | Option B | Projekt sieht alten Stand |
| FD-09 | D-2 Hosting | Staging, Restore-Test, Simulationsumgebung | 11.12.2026 | M9 Technik | genehmigen | M9 verschiebt sich |

### Medium

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FD-24 | Was „Privatpersonen“ heisst | Mehrere Bedeutungen möglich | 11.12.2026 | Sektorschicht Privatpersonen | Selbstzahlende Klient:innen und Angehörige als Anfragende zuerst | keine (nicht in Phase A) |
| FD-25 | Teameigener Anbieter auch im Pflegeheim? | D-12-Ziel war ein Spitex-Modell | vor Phase B | D-38, Partnervertrag | Pflegeheim behält Bewilligung, Abteilungen selbstorganisiert; teameigener Anbieter bleibt Ziel in der ambulanten Pflege | Vertragsentwurf ohne Zielbild |
| FD-14 | Website: Domain, Hosting, Demo-Empfänger | M5 | 11.12.2026 | M5 | mit D-2 | M5 rutscht |
| FD-16 | interRAI-Lizenzbedingungen an Legal geben (Fakt) | Legal kann sonst nicht prüfen, was aus interRAI verwendet werden darf | 11.12.2026 | Assessment-Inhalte, D-37 | Bedingungen liefern | kein interRAI-Inhalt |

### Low

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FD-15 | D-26 kein Service-Key auf dem App-Server | Sicherheit in Produktion | vor Phase B | Einladungen in Produktion | genehmigen | gering |

**Sicherheitshandlungen (kein Entscheid, nur Sie können sie ausführen):** Schlüssel im Live-Projekt rotieren; Leaked-Password-Schutz einschalten (bis 20.11.2026).

---

## 4. Kritischer Pfad

| Rang | Entscheid oder Handlung | Wirkung auf M9 (Phase A bestanden) | Wirkung auf M10 / Phase B | Spätestens |
|---|---|---|---|---|
| 1 | **Clinical Owner und Fachprüfung (FD-02)** | Plausibilität der simulierten Pflegeheim-Abteilung | ohne sie kein realer Pilot | Fachprüfung 15.01.2027 |
| 2 | **Merge-Pfad läuft (erledigt, FE-033)** | hält M2, M4 und M6 auf Kurs, wenn Engineering die Konflikte zügig löst | Puffer bleibt | – |
| 3 | **Pflegeheim-Abteilung bauen (NH-A1 bis NH-A5)** | grösste neue Bauaufgabe für Phase A | Grundlage für Phase B | Briefs 27.11.2026 |
| 4 | **Hosting D-2 (FD-09)** | Simulationsumgebung, Restore-Test | Produktion, Monitoring, Sicherheitstest | 11.12.2026 |
| 5 | **KI-Anbieter für synthetische Daten (FD-22)** | echter Test der KI-Dokumentation und Abrechnungsprüfung | Grundlage für D-41 (reale Daten) | 27.11.2026 |

---

## 5. Die nächsten 14 Tage (6.–20. November 2026)

Der Merge-Schritt ist aktiv (FE-033): der PO mergt in jedem stündlichen Lauf höchstens ein Engineering-PR.

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
| **Umsetzung (neu)** | Pflegeheim-Briefs NH-A1 bis NH-A5 (Phase A ambulant + Pflegeheim) und KI-Arbeitsablauf-Briefs DOC-AI, PLAN4, QUAL1, BILL1 als Entwürfe | 20.–27.11.2026 |
| **Ihre Fristen in diesem Zeitraum** | FD-27 bis 13.11.; FD-07 (D-7) bis 20.11. | – |

---

## 6. Risiken

| Art | Risiko | Owner | Gegenmassnahme | Aktueller Status |
|---|---|---|---|---|
| Lieferung | Fertige Arbeit bleibt ungemergt; jeder Merge erzeugt Konflikte in allen anderen PRs | PO (stündlich), Engineering | Merge-Schritt aktiv (FE-033); ein Journal-Eintrag pro Datei | 🟡 Test bestanden, rund 11 PRs warten |
| Lieferung | Der 11-teilige Tagesvorschlag-Stapel wird beim Mergen inkonsistent | PO, Engineering | in Reihenfolge mergen; klinisches Gate je Kopf | 🟡 alle Köpfe grün und frei |
| Lieferung | Briefs für Website, Pflege-App und Operations kommen zu spät | PO | feste Termine 20.11., 27.11., 4.12. | 🟢 im Plan |
| Governance | Kein Clinical Owner; simuliertes Pflegeheim ohne Fachprüfung | Owner | FD-02 | 🟡 nicht mehr Vorbedingung für Phase A, aber Qualitätsrisiko |
| Governance | M3-Entscheide nach dem 11.12. verschieben M9 und M10 Tag für Tag | Owner | ein Entscheid-Termin für die Agenda-Gruppe 2 | 🟡 30 % entschieden; Partner und Rechtsberater nicht mehr nötig für Phase A |
| Governance | Strategie-Rolle seit 3.11. ohne Eintrag | Owner (prüft die geplante Aufgabe) | Aufgabe prüfen | 🟡 unbekannt |
| Regulatorisch | Zielbild „kein Medizinprodukt“ vs. Assessment und KI-Dokumentation | `lca`, PO | Zweckbestimmung für Pflegeheime und DOC-AI prüfen; klinisches Modul getrennt | 🟡 neu |
| Regulatorisch | Medizinprodukt-Einstufung offen, sobald KI Inhalte vorbereitet | Owner, Legal | Regulierungsberater; KI bleibt regelbasiert | 🟡 kein Risiko im Pilot, solange KI regelbasiert bleibt |
| Regulatorisch | Zwei Kantone (BS, BL) verdoppeln Rechts- und Tarifarbeit | Legal | Basel-Prüfung je Paket | 🟡 entschieden, Prüfung läuft |
| Betrieb | Kein Staging, kein Restore-Test | Owner (D-2), Engineering | FD-09; Restore-Test vor M9 | 🔴 blockiert |
| Betrieb | Pflegeheim-Abrechnung (pro Tag und Pflegestufe) ist anders als Spitex; Regeln UNKNOWN | Legal, Clinical, PO | Regeln als versionierte Daten, erst synthetisch, dann Shadow Mode | 🟡 neu |

---

## 7. Founder Actions

**Diese Woche (bis 13.11.2026):**

1. **Weg für die Löschung von `orders` wählen (FD-27):** altes Projekt ganz löschen (empfohlen) oder für eine Sitzung wiederherstellen.
2. **Repository-Schutz D-7 genehmigen (FD-07).**
3. **Konnektoren prüfen:** Den Agenten-Aufgaben sind Supabase und Render noch angehängt. Ich kann das nicht ändern; Sie können sie in den Aufgaben-Einstellungen entfernen.

**Diesen Monat (bis 30.11.2026):**

1. **KI-Anbieter für synthetische Daten entscheiden (FD-22).**
2. **D-8 genehmigen** (nach D-7) und **Hosting D-2 (FD-09)**.
3. **Fachperson für das simulierte Pflegeheim benennen (FD-02)**.

---

## Pflege dieses Berichts

- Der PO schreibt diesen Bericht jeden Freitag bis 17:00 neu, aus den Kennzahlen in Blueprint V2 §10. Die Vorwoche bleibt in der Git-Historie.
- Ein beantworteter Entscheid verschwindet aus §3 und erscheint in §1 der nächsten Ausgabe.
- Unbekannte Werte stehen als UNKNOWN da und werden nie geschätzt, ohne dass es dasteht.
- Keine Personen- oder Gesundheitsdaten in diesem Dokument.
