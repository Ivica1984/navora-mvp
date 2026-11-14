# NAVORA Founder Executive Report

**Für:** den Owner (Founder) · **Verfasst von:** Product Owner (`po`) · **Ausgabe:** KW 46, Stand Freitag, 13. November 2026, 12:40 (Europe/Zurich), geplanter PO-Lauf 12:39 · **Vorausgabe:** KW 45 (6.11.2026, in der Git-Historie) · **Nächste Ausgabe:** Freitag, 20. November 2026 · **Rhythmus:** jeden Freitag bis 17:00 neu geschrieben.

**Dieses Dokument ist das primäre Entscheidungsdokument des Owners.** Es zeigt, was nachweislich fertig ist, was gebaut wird und was Sie entscheiden oder tun müssen. Quellen: [Blueprint V2](ARCHITECTURE_REVIEW_AND_IMPLEMENTATION_BLUEPRINT_V2.md) §10.3 Woche 46 (Kennzahlen), [`PRODUCT_BLOCKS.md`](PRODUCT_BLOCKS.md) (Blockstände; sie führen seit FE-052 vor den Meilenstein-Prozenten), [`ABNAHMEAKTE.md`](ABNAHMEAKTE.md), [Owner-Agenda](../agents/decisions/OWNER_AGENDA.md), [`FOUNDER_DECISIONS.md`](FOUNDER_DECISIONS.md). Der PO hat für diesen Bericht **keine Tests ausgeführt**; CI-Ergebnisse sind aus den GitHub-Check-Runs gelesen. Werte, die der PO nicht aus Repository oder GitHub lesen kann, stehen als UNKNOWN da.

---

## Nachtrag Freitag 13.11., 22:39 (geplanter PO-Lauf)

- **BK-a (#1238):** nachgebessert; das Protokoll erfasst Herkunft der Dringlichkeit und gewünschten Beginn wieder, die Zeitumstellungstests sind ergänzt. Alle vier Prüfungen grün. **Noch nicht gemergt:** es fehlt die klinische Freigabezeile für den neuen Stand (nächster `cra`-Lauf).
- Kein neuer Entscheid, keine Frage an Sie.

## Nachtrag Freitag 13.11., 21:39 (geplanter PO-Lauf)

- **Erster Bau-PR für BK liegt vor** (#1238: Auftraggeber erfasst einen Auftrag und bestätigt ihn). **Noch nicht gemergt:** Die klinische Prüfung hat einen blockierenden Fehler gefunden: Die Änderung hätte im Protokoll still verloren, wer die Dringlichkeit einer Anfrage gesetzt hat. Engineering hat nachgebessert; Tests und erneute Prüfung laufen. Gemergt wird erst, wenn alles grün ist und kein Prüfschutz gelockert wurde.
- **Zwei Sicherheitsbedingungen eingeplant:** Ein bestätigter Auftrag darf später nie unbemerkt liegen bleiben (wird im Angebotsteil BK-c getestet); und wenn gewählte Stufe und Tätigkeit nicht zusammenpassen, sieht der Auftraggeber das vor dem Absenden (BK-b). Zeitumstellungsnächte (10 bzw. 8 Stunden) werden schon jetzt getestet.
- **Bericht vor der Signatur:** Signieren bleibt gesperrt, bis jeder nicht übernommene Textteil eingefügt oder bewusst weggelassen ist. Das gilt für die Simulation; vor realen Daten muss die/der Clinical Owner das bestätigen. **Ihre Aktion:** keine neue; die Benennung der Clinical Owner bleibt offen.

## Nachtrag Freitag 13.11., 20:40 (geplanter PO-Lauf)

- **Drei Prüfberichte gemergt** (UX, Automatisierung, Recht; nur Dokumentation). Kein Engineering-PR offen; als Nächstes baut Engineering BK-a (Auftrag erfassen und bestätigen).
- **FE-078 ist im Repository nicht eingetragen.** `lca` meldet eine Founder-Nachricht von etwa 16:30 (keine Pflegegelder über NAVORA; Angebot gleichzeitig an alle passenden Teams statt nacheinander). Der PO kann sie nicht prüfen und trägt sie darum nicht ein. **Falls Sie das so entschieden haben:** bitte als FE-078 in `FOUNDER_DECISIONS.md` erfassen lassen; das beantwortet auch die Ein-Satz-Frage von 19:40 zu den Zahlungen. Bis dahin gilt im Bau das Angebot nacheinander (Kaskade); die Alternative ist rechtlich vorbereitet (bedingt, D-44).
- **Drei PO-Entscheide für BK** (operativ, keine Pflege-, Rechts- oder Tarifregel): Das **Team** legt sein Einsatzgebiet selbst fest, ohne Freigabe durch eine Verwaltung. Der **Preis** gehört dem Team: Der Auftraggeber setzt keinen Stundenpreis, er kann höchstens eine Obergrenze angeben; gebaut wird das erst im Rechnungsteil. Beim **Bericht** gibt es keine 30-Sekunden-Grenze und in BK keine Tonaufnahme; nichts, was die Pflegekraft eingibt, fällt still weg.
- **Sicherheitshinweis aus der UX-Prüfung:** Die Einsatzkarte zeigt eine fehlende Strasse nicht an, wenn eine PLZ vorhanden ist. Kein Risiko für Personen jetzt (nur synthetische Daten); wird im BK-Teilstück für die Einsatzkarte zuerst behoben und ist Bedingung für jede Freigabe mit realen Daten.

## Nachtrag Freitag 13.11., 19:40 (geplanter PO-Lauf)

- **BK-Vorarbeit gemergt** (#1228, nur Dokumentation): drei technische Entwürfe für den Bau. Der Auftrag eines Heims wird erst bei «Bestätigen & Absenden» gespeichert und enthält keinen Freitext; der Auftraggeber hat ein eigenes Konto ohne jeden Einblick in Teamdaten; die Distanz zählt nur ab dem Einsatzgebiet des Teams, nie ab einer Privatadresse oder per GPS. Als Nächstes baut Engineering BK-a.
- **Blueprint V3.2.4:** die Korrekturen der Rechtsprüfung (`lca`) sind eingetragen. Wichtig für Sie: Die Beispielrechnung (Heim spart 115 CHF, +33 % Lohn) ist **ein Modell mit Beispielwerten, kein Tarif und kein Einkommensversprechen**. Bitte diese Zahlen nach aussen (Website, Gespräch mit einem Heim, Rekrutierung) nur mit dieser Beschriftung direkt daneben verwenden (Lauterkeitsrecht, UWG).
- **Neue Frage an Sie (ein Satz, Ja oder Nein):** «Über NAVORA laufen keine Zahlungen zwischen Auftraggeber und Team.» FE-055 deckt «keine Provision» ab, diesen Satz aber nicht ausdrücklich. Ihr Ja macht die Gebührenseite der AVG-Abgrenzung verbindlich (die rechtliche Bestätigung bleibt beim Gutachten).
- **Für später (vor realen Daten, kein Handlungsbedarf jetzt):** eine schriftliche Bestätigung von swisstopo für das offizielle PLZ-Verzeichnis, von Ihrer Adresse aus; die sieben Punkte dafür hat `lca` formuliert (Journal 13.11. 16:40 §3). Für die Simulation genügt die synthetische Tabelle.

## Nachtrag Freitag 13.11., 18:40 (geplanter PO-Lauf)

- **B1.1 «Sichere Anfrage» ist für die Simulation abgenommen** (synthetische Daten). Nachweis auf `33523a5`: alle Prüfungen grün, Wiederholungstest 20/20, nichts übersprungen. Damit sind seit Montag drei Abnahmen erreicht (B0, BD-Teilabnahme, SAFE-D11) plus B1.1. **Keine Freigabe für reale Personen oder Daten.**
- **Ab jetzt ist BK aktiv**, der durchgehende Kern vom Auftrag bis zum Rechnungsentwurf. Erstes Teilstück: Auftrag erfassen und bestätigen (BK-a). Das ist der Hebel für M9.
- **Zwei PO-Entscheide ohne Ihre Zustimmung nötig** (operativ, keine Pflege- oder Rechtsregel): Wie weit ein Team fährt, bestimmt das Team; der Auftraggeber kann nur verengen. Schichtnamen kommen aus dem Schichtplan des Auftraggebers und steuern weder Prüfung noch Preis.
- **Von Ihnen weiter erwartet:** FE-078 (Rundruf an mehrere Teams) ist in der Rechtsprüfung zitiert (#1223), aber nicht in `FOUNDER_DECISIONS.md` eingetragen. Bitte bestätigen oder verwerfen; bis dahin bleibt #1223 offen.
- Die Tabelle «Auf einen Blick» unten ist der Stand von 12:40 und wird nächsten Freitag neu geschrieben.

## Auf einen Blick (1 Minute)

| | |
|---|---|
| **Gesamtstatus** | 🟡 At Risk |
| **Lieferung** | 🟢 läuft: der Merge-Pfad funktioniert in den geplanten Läufen (178 PO-Merges seit Montag, Engineering und Doku), Block für Block nach FE-054/FE-071 |
| **Nachweislich fertig (abgenommen)** | B0 Technische Basis «für die Simulation abgenommen, ohne B0-6» (11.11.); BD Durchgang ambulant «Teilabnahme für die Simulation, Schritte 1, 1b, 2-5, 8, 9» (12.11.). **Keine Freigabe für reale Personen oder Daten.** |
| **Aktiver Block** | B1.1 (Regionen, Altdaten) im Zuschnitt FE-073; heute #1181 gemergt; Abnahme auf dem Merge-Commit von B1.1-1c. Danach **BK «Schichtauftrag Heim»** (der durchgehende Kern) |
| **Pilot M9 (12.03.2027) auf Kurs?** | **Nein, weiterhin gefährdet:** der Kern (Auftrag → Team → Besuch → Bericht → Rechnungsentwurf) läuft noch nicht durchgehend; BK ist der Hebel. M1 (Ziel heute) ist nicht erreicht (75 %) |
| **Wichtigste Antwort diese Woche** | **Blueprint V3.0 und Architecture Handbook V2.0 freigeben oder korrigieren** (FE-075; PDFs liegen Ihnen vor) |
| **Was wartet auf Sie?** | 4 Handlungen jetzt (§7), 7 offene Entscheide (§3) |

**In einem Satz:** Diese Woche wurde aus «viel gebaut» zum ersten Mal «nachweislich abgenommen» (B0, BD teilweise); Ihre Entscheide FE-073 bis FE-075 lenken die Arbeit jetzt vom Detail (Altdaten) auf den durchgehenden Kern BK und auf zwei neue Meisterdokumente.

---

## 1. Abgeschlossene Lieferungen

### 1.1 Produktblöcke (führend seit FE-052)

| Block | Stand 13.11.2026 | Gate |
|---|---|---|
| B0 Technische Basis, DB-Sicherheit | **für die Simulation abgenommen 11.11., ohne B0-6** (Repository-Schutz liegt bei Ihnen) | Simulation, synthetische Daten |
| BD Durchgang ambulant | **Teilabnahme 12.11.: Schritte 1, 1b, 2-5, 8, 9;** 6-7 nicht nachgewiesen; Beleg `ci-repeat` 20/20 auf `4a543c0` | Simulation, synthetische Daten |
| SAFE-D11 Sicherheitsfix | gemergt 12.11. (#1143): ein wiedereröffneter Fall ohne Team geht nie verloren | Simulation |
| B1.1 Regionen (aktiv) | B1.1-1 (#1164) und B1.1-1b (#1181, heute) gemergt; offen: #1184 (Wettlauf-Test), B1.1-1c (#1196, Seed nur BS/BL mit PLZ) | Abnahme auf B1.1-1c |
| BK Kern generisch | Brief neu geschrieben (FE-074), Teile BK-a bis BK-g; noch nicht aktiv | – |
| B2 bis B12 | unverändert: in Arbeit, implementiert-nicht-ausreichend-getestet oder nicht begonnen | – |

### 1.2 Meilensteine (Blueprint §4; nachrangig zu den Blöcken)

| Meilenstein | Ziel | Abgeschlossen | Status |
|---|---|---|---|
| M1 Liefergrundlage | 13.11.2026 | 75 % | 🔴 Ziel heute verfehlt |
| M2 Eine Web-App | 27.11.2026 | 21 % | 🟡 |
| M3 Owner-Entscheide | 11.12.2026 | 30 % | 🟡 |
| M4 KI-Fundament I | 18.12.2026 | 87 % | 🟢 |
| M5 Website | 15.01.2027 | 15 % | 🟡 |
| M6 Pflege-App | 29.01.2027 | 10 % | 🟡 |
| M7 Angehörigenansicht | 05.02.2027 | 35 % | 🟢 |
| M8 Operations v2 + KI II | 19.02.2027 | 5 % | 🟡 |
| M9 Pilotreife | 12.03.2027 | 8 % (2 von 25 Gates; diese Woche nicht neu gezählt) | 🔴 |
| M10 Produktionsreife | 30.06.2027 | 0 % | 🔴 |

Die Prozentwerte sind seit FE-052 nicht mehr nachgeführt worden, wo ein Block statt eines Meilensteins abgenommen wurde. Der Blueprint V3-Entwurf ersetzt sie durch Blockfortschritt.

### 1.3 Ihre Entscheide diese Woche (FE-053 bis FE-075, 23 Einträge)

| Thema | Entscheide | Wirkung |
|---|---|---|
| Arbeitsweise | FE-053 (Journal je Datei), FE-054 (Block für Block), FE-056 (Tests in GitHub Actions), FE-061 (verlorener CI-Lauf), FE-070 bis FE-072 (Produktführung, Abnahmeakte, Statusnamen) | Merge-Konflikte durch das Journal beendet; «abgenommen» heisst jetzt Nachweis, nicht Merge |
| Produktion und Hosting | FE-057 (STG1-Ausnahme), FE-059, FE-062 bis FE-067 (Produktion jetzt, Supabase Zürich Free, Infomaniak Jelastic, Standard-Subdomain, Basler Testwelt, Konten von Hand) | D-2 beantwortet; Produktion wird gebaut, als liefen echte Daten |
| Geschäftsmodell | FE-055 (Leitplanken GM-1/GM-2, Gebühr nach Pensum), FE-060 (Abrechnung Phase B offen) | keine Provision bleibt eisern; Tarifwege bleiben OPEN |
| Kern und Reihenfolge | FE-068 (Spezifikation je Block), FE-069 (D-43, D-18 werden mitgebaut), FE-073 (Kern zuerst, Altdaten beendet), FE-074 (BK generisch), FE-075 (neue Meisterdokumente) | weniger Detailarbeit, schneller zum durchgehenden Ablauf |

### 1.4 Prüfungen diese Woche

| Prüfung | Ergebnis |
|---|---|
| Clinical & Regulatory (`cra`) auf B0, BD, SAFE-D11, B1.1-1, B1.1-1b | frei; CGR-203 (Wettlauf auf dem echten Umwandlungspfad) beratend offen, wird mit #1184 erledigt |
| Legal & Compliance (`lca`) auf B1.1-1b und BK-Rechtsnotizen | frei (beratend, keine Rechtsberatung) |
| UX (`uxa`) auf B1.1-1b; Designsystem v77 | frei; Streuzeilen-e2e ist Abnahmebedingung von B1.1-1c |

---

## 2. Laufende Arbeit

| Fähigkeit | Verantwortlich | Status | Erwarteter Abschluss |
|---|---|---|---|
| **B1.1 Rest:** #1184 (Wettlauf «Zuordnen» gegen «Fall eröffnen», nur Test), #1196 (B1.1-1c Seed nur Basel-Stadt/Basel-Landschaft mit PLZ) | Engineering, `cra` | gebaut, Gates offen | Abnahme B1.1 bis ca. 17.11. (PLANNED) |
| **BK «Schichtauftrag Heim», generisch:** Auftraggeber erfasst per Sprache/Text, KI extrahiert, Auftraggeber bestätigt → harte Filter (PLZ-Distanz, Qualifikation, Verfügbarkeit) → KI-Rangfolge → Angebot an das beste Team mit exklusivem Fenster → `/field` → Diktatentwurf → Unterschrift → Rechnungsentwurf ohne Provision | Engineering (BK-a ADR und rote Tests auf Branch), `cra`, `lca`, `uxa`, `aia` | Brief fertig, Block nach B1.1 | BK-a ab B1.1-Abnahme (PLANNED) |
| **Blueprint V3.0 und Architecture Handbook V2.0** | PO, `csa` (V3 Kap. 1-3), `eng` (Handbook per ADR) | Entwürfe an Sie (PDF) | nach Ihrer Freigabe |
| **STG1 Staging-Migrationen** (#1087) | Engineering, Sie (Secret) | wartet auf das Secret `STAGING_DB_URL`; nicht im aktiven Block | nach Secret und Blockfenster |
| Basel-Rechtsfragen, KI-Pfad D-41, Clinical-Mandat D-43 | `lca`, `cra`, PO | Pakete vorbereitet | vor Phase B |

---

## 3. Owner Decision Board

Nur Entscheide, die **Sie** treffen. Beantwortet seit der letzten Ausgabe und nicht mehr gefragt: FD-07 (D-7, FE-045), FD-08 (D-8, FE-047), FD-27 (SR-26-Weg, FE-046), FD-09 (D-2, FE-048/FE-064), D-26 vorläufig (FE-067).

### Critical

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| FE-075 | **Blueprint V3.0 und Architecture Handbook V2.0 freigeben** (oder Korrekturen nennen) | Neue «Single Source of Truth»; bis zur Freigabe bleiben V2 und `ARCHITECTURE.md` führend. Die Entwürfe weichen an 7 Stellen bewusst von Ihrem Wortlaut ab (z. B. B1.1 vor BK, «Tiers payant» OPEN, `ci-repeat` ist kein Lasttest, 52 vs. 75 CHF/h ist Hypothese) | 20.11.2026 | einheitliche Steuerung von BK; ADR-Arbeit von `eng` (T-1 bis T-9) | freigeben mit den 7 Abweichungen; Korrekturen als FE-Eintrag | zwei Meisterdokumente parallel; Doppelarbeit |

### High

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| PROD | **PROD1-PROD3 unter FE-054 einordnen** (gefragt 12.11.) | Sie wollen Produktion jetzt (FE-062), haben aber nicht gesagt, ob das eine Ausnahme zum Ein-Block-Prinzip ist | 20.11.2026 | Produktionsaufbau | (B) als eigener Block nach BK; Ausnahme nur wie STG1 | Produktion wartet ohne Datum |
| FD-22 | KI-Anbieter nur für synthetische Daten | BK nutzt KI-Extraktion beim Auftraggeber; ohne Anbieter läuft sie nur mit eigenem Modell (Muster 4) oder regelbasiert | 27.11.2026 | KI-Teile von BK und A7 | ein CH/EU-Anbieter mit Vertrag nur für synthetische Daten; D-35 Regel A bleibt | BK-Extraktion nur als Platzhalter |
| D-44 (1) | L-10-Gebührendesign verbindlich für GM-1/GM-2 | Schreibt «Abo statt Provision» vertraglich fest | vor Phase B | KON-1, KON-3, KON-4 | genehmigen | Geschäftsmodell nur als Prinzip, nicht als Vertrag |
| D-43 | Mandat für klinische Regelfreigabe (Option B + D) | Ohne benannte Stelle bleibt jede klinische Regel provisorisch | 15.01.2027 | Phase B; Qualifikationsmatrix QAM | genehmigen, Mitglieder benennen | Phase B startet ohne freigegebene Regeln |

### Medium

| ID | Entscheid | Warum es zählt | Frist | Was es blockiert | Empfehlung | Risiko bei Verzug |
|---|---|---|---|---|---|---|
| COORD-7 | Punkte 4a (mechanischer Diff statt `cra`-Neugate nach reinem Merge-in) und 5 (wöchentlicher 30-Minuten-Slot) | Gate-Wartezeit ist diese Woche der Engpass | 20.11.2026 | Durchlaufzeit | beide genehmigen mit den Bedingungen im Paket | Stunden Wartezeit je PR |
| FD-24 | Was «Privatpersonen» heisst | BK hat die Privatperson als Auftraggeber | 11.12.2026 | Sektorschicht Privatpersonen | Selbstzahlende und Angehörige als Anfragende zuerst | BK-Privatperson nur synthetisch |
| FD-29 | B2B-Modulpreise | erst nach Kostenbasis | vor dem ersten B2B-Angebot | GM-2 | nicht jetzt | keines |

---

## 4. Kritischer Pfad

| Rang | Punkt | Wirkung auf M9 (Phase A) | Wirkung auf Phase B | Spätestens |
|---|---|---|---|---|
| 1 | **B1.1 abnehmen, BK bauen** (der durchgehende Kern) | ohne BK kein Phase-A-Gesamttest (B11) | Grundlage jedes Pilots | BK-Start ca. 17.11. |
| 2 | **Gate-Latenz** (`cra`, `lca`, `uxa` je PR mehrere Stunden) | jeder Block dauert Tage länger | – | COORD-7 bis 20.11. |
| 3 | **Repository-Schutz B0-6 (D-7 Stufe 1)** | B0 bleibt ohne B0-6 | Gate vor B12 | 20.11.2026 |
| 4 | **Clinical-Mandat D-43** | simuliertes Pflegeheim ohne Fachblick | ohne Mandat kein realer Pilot | 15.01.2027 |
| 5 | **Staging-Secret für STG1** | Restore- und Staging-Test (B11) | Produktion | vor B11 |

---

## 5. Die nächsten 7 Tage (14.–20. November 2026)

| Art | Erwartet | Datum |
|---|---|---|
| Merge | #1184 nach `cra`-Gate; danach #1196 (B1.1-1c) | ab 13.11. |
| Abnahme | B1.1 auf dem Merge-Commit von B1.1-1c (`ci` grün, `ci-repeat` 10/10), Gate «Simulation, synthetische Daten» | ca. 17.11. (PLANNED) |
| Blockwechsel | BK wird aktiv; BK-a (ADR, rote Tests) zuerst | nach B1.1-Abnahme |
| Prüfung | `csa` prüft V3 Kap. 1-3; `eng` bestätigt das Handbook per ADR | 20.11. (PLANNED) |
| Ihre Fristen | FE-075-Freigabe, PROD-Einordnung, COORD-7, D-7 Stufe 1 | 20.11. |

---

## 6. Risiken

| Art | Risiko | Owner | Gegenmassnahme | Status |
|---|---|---|---|---|
| Lieferung | Gate-Latenz statt Engineering ist der Engpass (#1181: grün seit 9:49, letztes Gate 12:22) | `cra`, `lca`, `uxa`, Owner (COORD-7) | Gates gebündelt anfragen; COORD-7 4a | 🟡 |
| Lieferung | BK ist gross (7 Teile) und berührt KI, Abrechnung und Pflegeheim zugleich | PO, Engineering | strikt in BK-a bis BK-g schneiden; klinische Fragen verkleinern statt erfinden | 🟡 |
| Steuerung | Zwei Meisterdokumente (V2 und V3-Entwurf) parallel | Owner, PO | FE-075 freigeben | 🟡 |
| Sicherheit | Repository ohne Ruleset und Secret Scanning (B0-6) | Owner | D-7 Stufe 1 klicken | 🔴 offen seit 7.11. |
| Sicherheit | Altes Live-Projekt: Löschung (FD-27 (b)) von Ihnen auszuführen; Stand UNKNOWN | Owner | «erledigt» melden | 🟡 UNKNOWN |
| Klinisch | Kein Clinical Owner; QAM v0.1/v0.2 nur PROPOSED für die Simulation | Owner | D-43 | 🟡 kein Risiko in Phase A, solange nur synthetisch |
| Regulatorisch | KI-Extraktion beim Auftraggeber (BK) nähert sich der Medizinprodukt-Frage | `lca`, `cra` | Zweckbestimmung D-34; deterministische Filter zuerst, KI nur Rangfolge und Erklärung | 🟡 |
| Betrieb | Staging-Migrationen warten auf ein Secret | Owner | `STAGING_DB_URL` setzen | 🟡 |

---

## 7. Founder Actions

**Jetzt (bis 20.11.2026):**

1. **Blueprint V3.0 und Handbook V2.0 lesen und freigeben** oder Korrekturen in einem Satz nennen (FE-075).
2. **D-7 Stufe 1 klicken:** Ruleset auf `recovery/main` mit den vier Pflicht-Checks, Secret Scanning, Push Protection (schliesst B0-6).
3. **PROD1-PROD3 einordnen:** «PROD: B» (eigener Block nach BK) oder «PROD: A» (Ausnahme).
4. **COORD-7:** «4a und 5 genehmigt» oder einzeln.

**Wenn Sie Zeit haben:** das Secret `STAGING_DB_URL` für STG1 setzen; «erledigt» zur Löschung des alten Projekts (FD-27) melden.

---

## Pflege dieses Berichts

- Der PO schreibt diesen Bericht jeden Freitag bis 17:00 neu, aus Blueprint V2 §10.3 (Woche 46 ist die Quelle dieser Ausgabe). Die Vorwoche bleibt in der Git-Historie.
- Ein beantworteter Entscheid verschwindet aus §3 und erscheint in §1 der nächsten Ausgabe.
- Unbekannte Werte stehen als UNKNOWN da und werden nie stillschweigend geschätzt.
- Keine Personen- oder Gesundheitsdaten in diesem Dokument.
