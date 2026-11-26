---
id: HD
title: HEIM-DP — Heim-Dienstplanung als vollständiges Register (Woche, Monat, Plan je Mitarbeiterin, Abwesenheit, Lücke, externer Auftrag, gemeinsamer Status, KI-gestützte Planung)
author: po
status: approved   # Fassung 3 (FE-110): HD-1 residual list §4a. Fassung 2: HD-1 approved and ACTIVE (#1623); HD-2 approved; HD-3 PROPOSED until `aia` and `eng` confirm §5
updated: 2026-11-20
---

# HEIM-DP: PO-Produktvertrag, Fassung 3 (2026-11-20 20:05, FE-110: §3a, §4a, §5a neu; sonst unverändert)

**Ursprung:** FE-108 und FE-109 (Founder-Nachrichten vom 2026-11-20: ca. 17:45 an `eng`, ca. 18:00 und ca. 18:20 an `po`). **Gate:** «Simulation, synthetische Daten». Für reale Personen gilt nichts hiervon als freigegeben. Der PO hat keine Tests ausgeführt. Alle Aussagen sind gekennzeichnet als IMPLEMENTED (im Code oder in CI belegt), PLANNED, OPEN oder UNKNOWN.

**Bestätigt (Founder):** Die Vision. Eine Plattform mit Ansichten je Rolle. Interne Heimplanung (B2B-Modul 1) ist getrennt vom externen Auftrag an selbstorganisierte Teams und mit ihm im Ablauf verbunden. Es wird ein Register nach dem anderen gebaut, das Pflegeheim zuerst, und der Founder prüft jedes auf Staging selbst. **Dieser Vertrag (Details):** Er ist vom PO entschieden, soweit unten «PO entscheidet» steht. Der Founder prüft ihn auf Staging; jede Rückmeldung wird eine Korrektur oder ein Folgepaket.

## 1. Nutzerergebnis des ganzen Registers

Die Heimleitung eines synthetischen Heims (Demo `kundebs`, «Testheim Rhein») plant ihr eigenes Personal in Woche und Monat und sieht den Dienst- und Einsatzplan jeder namentlich dargestellten Mitarbeiterin. Sie erfasst eine Abwesenheit und sieht sofort die entstehende Lücke. NAVORA bereitet ihr einen zulässigen Plan und prüfbare Umplanungsoptionen vor. Eine Lücke, die intern bleibt, wird mit einem Tipp zu einem geprüften externen Auftrag. Danach sieht das Heim den ehrlichen Status: in der Woche, im Monat, im Mitarbeiterplan und unter «Externe Aufträge», derselbe Sachverhalt wie bei Team und Pflegekraft. Das gilt auch, wenn die bestätigte Person später ausfällt.

«Plan je Mitarbeiterin» ist der **Dienst- und Einsatzplan** dieser Person (FE-109 (C)). Die Pflegeplanung von Bewohnenden ist ein anderes Modul und nicht Teil von HEIM-DP.

## 2. Ansichten und Konsistenz (PO entscheidet)

| Ansicht | Inhalt | Stand |
|---|---|---|
| Woche | je Tag, Station und Dienst: eingeteilte Personen mit Stufe, Mindestbesetzung des Heims, Status in Worten («2 von 3 · Lücke: 1 fehlt», «1 HF fehlt», «besetzt») | IMPLEMENTED auf #1623, nicht gemergt |
| Monat | Personen × Tage mit Dienstkürzel, «A» für abwesend, geplante Stunden, Lücken je Tag | IMPLEMENTED auf #1623, nicht gemergt |
| Plan je Mitarbeiterin | Monat einer Person; Abwesenheit erfassen und entfernen (nie ein Grund) | IMPLEMENTED auf #1623, nicht gemergt |
| Einstellungen (nur Leitung) | Stationen, Dienstarten, Mindestbesetzung je Station und Dienst als **Daten des Heims** | IMPLEMENTED auf #1623, nicht gemergt |

**Konsistenzregel:** Alle Ansichten lesen eine einzige Lesefunktion (`institution_plan`) aus einer Einteilungs- und einer Abwesenheitstabelle. Es gibt keine Kopie je Ansicht und keine zweite Statuslogik im Frontend. Eine Änderung in einer Ansicht ist nach dem Neuladen in allen anderen sichtbar; ein e2e-Test beweist das je Richtung (Woche → Monat → Person und Person → Woche).

**Feste Regeln, die NAVORA nicht erfindet:** Die Mindestbesetzung setzt das Heim (Beispielwerte im Simulationskonto, gekennzeichnet). Die Qualifikationsstufen stammen aus `QUALIFICATION_MATRIX.md` und sind nur eine vorgeschlagene Grundlage für die Simulation. Arbeitszeit- und Ruhezeitregeln (ArG) sind **OPEN bei `lca`** und werden nicht geprüft; der Bildschirm sagt das (IMPLEMENTED auf #1623).

## 3. Ein gemeinsamer, ehrlicher Status (PO entscheidet)

Eine Datenbankfunktion liefert den Zustand eines externen Auftrags. Heim-Woche, Monat, Mitarbeiterplan, «Externe Aufträge», Team (`/team`) und Pflegekraft (`/field`) lesen dieselbe Quelle. Die Wörter für den Auftraggeber stehen heute in `src/features/orders/offer-rules.ts` (IMPLEMENTED für `/order`); HD-2 bringt sie in die Heim-Ansichten.

| # | Zustand | Bedeutung | Heim sieht in Woche und Monat | Nächste Handlung des Heims |
|---|---|---|---|---|
| L | Lücke | Mindestbesetzung nicht erreicht, kein Auftrag | «Lücke: 1 HF fehlt» | intern besetzen (Optionen) oder «Externen Auftrag vorbereiten» |
| E | Auftrag vorbereitet | aus der Lücke vorbefüllt, noch nicht gesendet | «Auftrag vorbereitet, nicht gesendet» | prüfen und senden oder verwerfen |
| A | Angebot versandt | an alle passenden Teams zugleich | «Angebot versandt · noch nicht gedeckt» | warten; zurückziehen möglich |
| K | Nicht gedeckt | kein passendes Team frei oder Frist erreicht | «Nicht gedeckt» | intern besetzen oder zurückziehen |
| T | Team hat übernommen | ein Team hat zugesagt, die eingeteilte Person hat noch nicht bestätigt | «Team hat übernommen · Person bestätigt noch» | warten; zählt **nicht** als besetzt |
| G | Gedeckt | die Person hat bestätigt **und** NAVORA hat sie dabei geprüft (Stufe, frei, Zugang offen); der Zustand hält nur, solange diese Prüfungen weiter gelten | «Gedeckt · Person bestätigt, geprüft für HF» | nichts |
| N | Nicht mehr gedeckt | die bestätigte Person fällt aus (Abwesenheit, Zugangsende) | «Nicht mehr gedeckt · Angebot läuft wieder» (rot) | sichtbar: «Intern besetzen» (zulässige eigene Personen) oder «Auftrag zurückziehen»; das Angebot geht automatisch wieder an alle passenden Teams |

«Person hat bestätigt» ist das Ereignis, «Gedeckt» ist der Zustand. Im Code geschehen Bestätigung und Prüfung in derselben Transaktion (IMPLEMENTED, BK-c/BK-e). Einen sichtbaren Zwischenzustand «bestätigt, aber nicht geprüft» gibt es darum nicht. Fällt eine Prüfung später weg, wechselt der Zustand auf N (IMPLEMENTED: `recheck_member_takes`, `no_longer_covered`). Kein Bildschirm zeigt nach N noch «gedeckt»: Das ist ein Negativtest in CI und auf Staging. Fällt die Übernahme weg, bevor «Gedeckt» je gezeigt wurde, kehrt der Zustand zu A zurück, mit dem Hinweis «Die eingeteilte Person kann nicht» (IMPLEMENTED).

## 3a. Drei Wörter an einer synthetischen Schicht (FE-110 (1), PO entscheidet)

Beispiel: «Testheim Rhein», Station A, Mo Früh 07:00–15:30, Mindestbesetzung 1 HF (Beispielwert des Simulationskontos).

| Wort | Wann | Paket | Tatsächliche nächste Handlung des Heims |
|---|---|---|---|
| **Lücke** | Mindestbesetzung intern nicht erreicht, kein externer Auftrag (z. B. HF «Mara Test» als abwesend erfasst) | HD-1 (IMPLEMENTED auf #1623) | eine zulässige eigene Person in der Zelle einteilen; ab HD-2 zusätzlich «Externen Auftrag vorbereiten» |
| **Nicht gedeckt** | ein Auftrag existiert, aber kein passendes Team ist frei, alle haben abgelehnt, die Deckungsfrist ist erreicht oder die Schicht hat begonnen | HD-2 | intern einteilen oder Auftrag zurückziehen; kein Text behauptet, dass noch ein Angebot läuft |
| **Nicht mehr gedeckt** | die Schicht war «Gedeckt», dann fällt die bestätigte Person aus | HD-2 | intern einteilen oder Auftrag zurückziehen; der Zusatz «Angebot läuft wieder» nur unter der Bedingung unten |

**Bedingung «Angebot läuft wieder» (HD-2-Abnahmekriterium, Negativtest Pflicht):** Der Zusatz erscheint nur, wenn die Übernahme freigegeben ist (`released_at` gesetzt), ein neuer Rundruf mit mindestens einem offenen Angebot in der aktuellen Runde besteht und die Deckungsfrist nicht erreicht ist. Sonst: «Nicht mehr gedeckt · kein Angebot offen» mit denselben Handlungen. Befund (Code 0136, vom PO gelesen): Der Zweig «Sicherheitsnetz» von `private.order_cover` erfüllt das heute nicht (siehe FE-110 Vermerk (b)); `eng` prüft und belegt mit pgTAP. Für `/order` gilt dieselbe Regel (gleiche Quelle), umgesetzt in HD-2.

## 4. Technische PR-Folge (PO entscheidet die Reihenfolge; `eng` das WIE)

Es ist immer genau ein Paket aktiv (Blockregel unverändert).

| Paket | Inhalt | Abhängig | Gates (ein Fenster nach `Paket prüfbereit:`) | Stand |
|---|---|---|---|---|
| **HD-1** (#1623) | Heim-Mandant `institutions` (unabhängig von Netzwerk-Organisationen, ARCH1 A1), Stammdaten, Woche, Monat, Plan je Mitarbeiterin, Abwesenheit, Lücke (feste Regeln); 16 Funktionen als Dateien nach STAB1; Beispieldaten; `staging-smoke` Pfad 4 | STAB1 (abgenommen) | `cra` (Qualifikationsstatus; Unterbesetzung nie als «besetzt»), `uxa` (neue Bildschirme 390/1440 px). Kein `lca`-Gate für die Simulation (FE-109 (A)); vor realen Daten Pflicht | **für die Simulation teilabgenommen** auf `9debf74` (2026-11-21 03:39, §PO-Teilabnahme) |
| **HD-2** | Lücke → vorbefüllter Auftrag über `preview_client_order`/`confirm_client_order` (kein zweiter Bestellweg); gemeinsamer Status §3 in allen Heim-Ansichten; N mit nächster Handlung; Doppelbestellung je Lücke gesperrt; `staging-smoke` Pfad 5 | HD-1 | `cra`, `uxa` | **für die Simulation teilabgenommen** auf `0b8f537` (2026-11-21 14:39, §PO-Teilabnahme HD-2); Registerabnahme §6 (2) OPEN |
| **AI1** | Modellanschluss über das bestehende Gateway: Kostendeckel (CHF 50/Monat, 300 Aufrufe/Tag), Protokoll, Auswertung, Not-Aus; erste Modellfunktion Berichtsentwurf (`briefs/AI1.md`) | HD-2 | `cra`, `lca` (Anbieterbedingungen, FE-099 (7)), `aia` | approved, verschoben nach FE-109 (b) |
| **HD-3** | KI-gestützte Planung §5: (a) Optimierung: zulässiger Wochen- und Monatsentwurf, Umplanungsoptionen nach Abwesenheit; (b) Modell: Sprache → Abwesenheit und Planungswünsche, Rangfolge und Abwägung zwischen zulässigen Optionen | AI1 (für b) | `cra`, `uxa`, `aia` | PROPOSED bis `aia`/`eng` §5 bestätigen |

**Reihenfolge, Herkunft (FE-110 (2)):** HD-1 → HD-2 ist Founder-Entscheid (FE-109 (C)). Die Stelle von AI1 zwischen HD-2 und HD-3 und die Teilung HD-3a/HD-3b sind **PO-Empfehlung**, bis der Founder sie bestätigt.

### 4a. HD-1 feste Restliste (PO, 2026-11-20 20:05; keine weitere Bedingung)

1. **R1 (Patientensicherheit):** eine inaktive Person zählt nicht als anwesend; Zelle zeigt «nicht mehr aktiv» und die Lücke; die Person bleibt im Monat sichtbar, solange sie im Zeitraum eingeteilt ist. Roter pgTAP zuerst, dann e2e Woche = Monat.
2. **R2 (PO entscheidet):** Zeitänderung einer Dienstart, die ab heute eingeteilt ist, wird abgelehnt (`shift_type_in_use`, Hinweis «neue Dienstart anlegen»); vergangene Pläne bleiben unverändert. pgTAP.
3. **R3 (PO entscheidet):** Abwesenheit gilt für den ganzen Kalendertag. Ein Dienst, dessen Zeitspanne einen Abwesenheitstag berührt (auch die Nacht D-1 bis D), zählt als abwesend (Lücke) und kann nicht neu eingeteilt werden. pgTAP.
4. Ready-Report nach FE-105 mit: Midnight-Test «Monat zeigt die Nacht an genau einem Tag» (neu); LEAVE1 ehrlich: Heimpersonal hat kein Konto, Äquivalent ist «nicht aktiv»; Zugangsende gilt für die planende Person; Gleichzeitigkeit zweier Planender: Test, falls mit `scripts/db-concurrency` machbar, sonst als OPEN benannt (keine Bedingung).
5. `staging-smoke` Pfad 4 und grüne Smoke auf `recovery/main` vor dem Merge (unverändert).

Gates danach in einem Fenster: `cra`, `uxa` (unverändert).

Danach folgen das Heim-Dashboard (es fasst nur die verlässlichen Daten dieser Register zusammen) und später die Register für Spital und Privatperson (Grundriss §9).

## 5. Die KI-Rolle je Schritt (PROPOSED; `aia` und `eng` bestätigen oder ersetzen)

Die Planungsarbeit nimmt vor allem ein **Optimierer** ab. Er ist ein festes, prüfbares Rechenverfahren und kein Sprachmodell. Er wird auf dem Bildschirm als «Optimierung (feste Regeln)» gekennzeichnet. Das **angeschlossene Modell** übernimmt, was Regeln nicht können: Sprache verstehen und Abwägungen begründen. Es kann nur aus Optionen wählen, die die Regeln erlaubt haben.

| Schritt | Feste Regel / Optimierung | Angeschlossenes Modell (HD-3b, nach AI1) | Heimleitung bestätigt |
|---|---|---|---|
| 1 Plan vorbereiten (Woche, Monat) | erzeugt aus Dienstvorlage, Mindestbesetzung, Stufen, Abwesenheiten und Überschneidungsverbot einen **zulässigen Entwurf**; meldet, was unlösbar bleibt (Lücken) | übersetzt Wünsche in eigenen Worten («Maria keine Nächte», «Wochenenden fair verteilen») in weiche Kriterien als **Vorschlag**; vergleicht zwei bis drei Entwürfe in Worten | Sie bestätigt die Kriterien, bevor sie gelten, und übernimmt den Entwurf ganz oder teilweise; nichts gilt ohne Übernahme |
| 2 Abwesenheit verarbeiten | prüft Zeitraum und Überschneidung und markiert die betroffenen Dienste | macht aus einer freien Meldung («Anna fällt Do–Sa aus») einen Vorschlag mit Person und Zeitraum; **kein Grund** wird erfragt, gespeichert oder weitergegeben | Sie bestätigt die Abwesenheit |
| 3 Umplanungsoptionen | berechnet nur zulässige Optionen: intern umbesetzen, tauschen, extern bestellen | ordnet sie nach den bestätigten Kriterien und begründet das nur aus den Plandaten; das Gateway verwirft jede Option, die die Regel nicht geliefert hat (Test) | Sie wählt eine Option |
| 4 Lücke → externer Auftrag | füllt Zeit, Station, Stufe und Tätigkeiten aus der Lücke vor; `preview_client_order` prüft die harten Regeln | kein Modell: Die Lücke ist schon strukturiert, ein Modell brächte hier keinen Nutzen (ehrlich) | Sie prüft und sendet |
| 5 Status zurück | eine Funktion, §3 | kein Modell | — |

**Woran der Founder es auf Staging erkennt:** Jeder Vorschlag trägt eine von drei Marken: «Optimierung (feste Regeln)», «KI-Vorschlag (Modell), bitte prüfen» oder «regelbasiert, keine KI». Jeder Modellvorschlag erscheint im Vorschlagsprotokoll mit Zeit, Modell und Entscheid (IMPLEMENTED als Ledger AIG1 für den Berichtsentwurf). Mit Not-Aus erscheinen nur Regeltexte. **KI-Status heute:** HD-1 nutzt nur feste Regeln. Kein Modell ist in irgendeinem Pfad angeschlossen. Das Modell übernimmt Planungsarbeit erst ab HD-3b; vorher kann es auf Staging nicht vorkommen. Für reale Personen gilt D-35 Regel A unverändert.

### 5a. Nutzen von HD-3 messen (FE-110, Abnahmebedingung von HD-3; PLANNED)

HD-3 wird nicht an einem Erklärungstext abgenommen, sondern an abgenommener Arbeit, gemessen auf dem synthetischen Heim gegen denselben Fall manuell:

| Messgrösse | Manuell (HD-1/HD-2) | Mit HD-3 | Quelle |
|---|---|---|---|
| Schritte und Zeit bis zum zulässigen Monatsplan (Station, 20 Personen) | gezählte Einteilungen und Zeit im e2e-Lauf | Entwurf + Übernahme + Korrekturen | e2e-Zeitstempel, Ereignisprotokoll |
| Schritte und Zeit von der Ausfallmeldung bis «besetzt» oder Auftrag gesendet | Abwesenheit, Suche, Einteilung | Meldung in eigenen Worten → Option wählen | dito |
| Anteil übernommener Vorschläge, Korrekturrate je Feld | — | Vorschlagsprotokoll (AIG1-Ledger) | Ledger |
| verbliebene Lücken und Regelverstösse | Plan | Entwurf (Verstösse müssen 0 sein, Test) | `institution_plan` |

Prüfweg der Heimleitung: Jeder Vorschlag zeigt die Änderungen gegenüber dem aktuellen Plan (wer, wann, welche Zelle), seine Marke und eine Begründung nur aus Plandaten; sie übernimmt ganz, teilweise oder gar nicht; nichts gilt ohne Übernahme. Werte und Messverfahren definiert `aia` mit `eng` (Issue #1627); es wird kein Zielwert erfunden.

**Offene Fragen an `aia`/`eng` (Issue, vor HD-3):** Verfahren und Laufzeit des Optimierers für 8 bis 60 Personen und einen Monat; ob die Übersetzung «Sprache → weiche Kriterien» messbar zuverlässig ist (Auswertungsset); Kosten je Vorschlag gegen den Deckel; was mit synthetischen Namen an das Modell geht (Datenminimierung).

### 5b. Founder-Spezifikation HD-3a (#1712, FE-117; PO-Ergänzung 2026-11-24 14:39)

Der Founder hat HD-3a in Issue #1712 beschrieben. Das ist der Inhalt von **HD-3a «Optimierung (feste Regeln)»**, ohne Modell (Schritt 1 und 2 der Tabelle §5, linke Spalte). Stand: **approved als Inhalt, nicht aktiv**; Start nach AI1 (FE-111), ausser der Founder ordnet ausdrücklich anderes an (Frage auf #1712).

| Teil | Inhalt nach #1712 | PO-Einordnung |
|---|---|---|
| Stammdaten | Pensum 10–100 %, Schichtmodell `any`, `day_only`, `late_only`, `night_only`, `no_night` | synthetisch; WIE (Spalten, Funktion) entscheidet `eng` |
| Absenzen | Zeitraum und Typ (`Ferien`, `Weiterbildung`, `Kompensation`, `Krankheit`) | bestehender Weg `institution_absences` (HD-1), kein zweiter; **Typ «Krankheit» OPEN** (Gesundheitsdatum bei realen Personen; §5 Schritt 2 «kein Grund gespeichert»); PO-Vorschlag bis Entscheid Founder/`lca`: ohne «Krankheit», neutral «Abwesend» |
| Planungslauf | ein Button in Woche und Monat, deterministischer Solver (ADR-224), Ziel < 2 s | Laufzeit wird gemessen und berichtet; Entwurf gilt erst nach Übernahme durch die Heimleitung (§5 rechte Spalte, FE-114) |
| Harte Kriterien | Mindestbesetzung je Station (z. B. 2 Personen, davon 1 HF), Pensum, Absenzen, Schichtmodell, Ruhezeit ≥ 11 h, ≤ 6 Arbeitstage in Folge | Ruhezeit und Tage in Folge: Founder-Vorgabe für die Simulation, als Parameter, Marke «Regel nach Founder-Vorgabe, rechtlich nicht geprüft»; ArG-Lesart `lca` vor realen Daten; Mindestbesetzung ist Heim-Konfiguration, keine klinische Regel (D-27) |
| Rest-Lücken | rote Lücke mit Begründung («1 HF fehlt – alle verfügbaren HF im Dienst oder abwesend»), «Externen Auftrag vorbereiten» (HD-2) | Begründung nur aus Plandaten; keine Unterbesetzung als «besetzt» (HD-1 R1) |
| Nicht-Ziele | kein Lohnlauf, keine automatische Buchung externen Personals, keine automatische Ferienbewilligung | übernommen |

**Abnahmekriterien HD-3a (zusätzlich zu §5a und §6 (3) ohne Modellteil):** pgTAP für jede neue Prüfung; Unit-Tests: kein Dienstpaar mit < 11 h Ruhe, niemand über seinem Pensum, `no_night` nie in der Nacht, eine Absenz nie überplant; Negativtest: ein unlösbarer Monat liefert Lücken mit Begründung, nie einen Regelverstoss (Verstösse = 0); T-1 «übernommen = gezeigt»; `staging-smoke` Pfad «automatisch generieren → übernehmen → Lücke als Auftrag»; `ci-repeat` 10/10 (`db`, `e2e`). Gates in einem Fenster: `cra` (Stufen, Mindestbesetzung, Lücke nie «besetzt»), `uxa` (390/1440 px), `aia` (Marken, Messung §5a). `lca` vor realen Daten.

**PO-Ergänzung 2026-11-24 15:39 (FE-119, Founder-Kommentar [#1712 7134186497](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7134186497)):** Stand **approved und aktiv** (Bau ab sofort auf eigenem Zweig, z. B. `feature/hd3a`, parallel zum Abschluss von AI1; Merge höchstens ein Engineering-PR je Lauf, zuerst der zuerst prüfbereite, bei Gleichstand AI1; HD-3a nimmt danach `recovery/main` per Merge-Commit auf). Absenztypen: `Ferien`, `Weiterbildung`, `Abwesend`; kein Typ «Krankheit», kein Feld für einen Grund. «Kompensation» OPEN beim Founder, bis dahin nicht gebaut. Ruhezeit ≥ 11 h und ≤ 6 Tage in Folge als Parameter mit der Marke «Arbeitszeitgesetz nicht abschliessend geprüft». Abnahmekriterien und Gates oben unverändert (`cra`, `uxa`, `aia` in einem Fenster nach `Paket prüfbereit:`; `lca` vor realen Daten). Zusätzlicher Negativtest: ein Absenztyp ausserhalb der drei wird von der Datenbank abgelehnt. Marke auf dem Bildschirm: «Optimierung (feste Regeln)», keine KI.

**PO-Ergänzung 2026-11-24 16:39 (FE-120, Founder-Kommentar [#1712 7136010742](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7136010742)):** Absenztypen in HD-3a: `Ferien`, `Weiterbildung`, `Kompensation`, `Abwesend`. Weiterhin kein Typ «Krankheit», kein Feld für einen Grund. Der Negativtest lehnt jeden Typ ausserhalb dieser vier ab. Keine Saldo- oder Überzeitberechnung in HD-3a («Kompensation» ist nur ein Absenztyp; eine Überzeitrechnung wäre ein eigenes Paket, OPEN). CGR-284 (`cra`, advisory) gehört in den Vertrag vor `Paket prüfbereit:`.

**PO-Ergänzung 2026-11-24 19:39 (FE-123, FE-125; Founder-Antworten in der `eng`-Live-Sitzung, von `eng` wiedergegeben auf #1712 [7140391042](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7140391042) und [7140850219](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7140850219); vom PO nicht selbst gehört).** Der HD-3a-Vertrag wird auf Founder-Auftrag geändert; diese Änderung ist keine PO-Zusatzbedingung (BK BUILD PHASE (3)), sondern Founder-Scope. Stand: **approved und aktiv**, Zweig `feature/hd3a` (#1729).

| Teil | Vertrag HD-3a ab 19:39 | Status |
|---|---|---|
| Pensum | 100 % = Sollstunden pro Woche **je Heim** (Feld am Heim); Testheim 42 h, Marke «Beispielwert des Heims»; Kapazität = Pensum × Sollstunden je ISO-Woche in Dienstminuten | PLANNED |
| Schichtart | je Dienstart wählt das Heim `early`, `late` oder `night`; Dienstart ohne Art nur an Personen mit `any`; kein Tagdienst, keine Klasse `day` | PLANNED |
| Schichtmodelle | `any`, `early_only` (Vorwärts-Migration aus `day_only`, Testwerte umgesetzt), `late_only`, `night_only`, `no_night` | PLANNED |
| Zeiten | Testheim: Früh 07:00–15:30, Spät 14:30–23:00, Nacht 22:30–07:15, Marke «Beispielwert des Heims»; NAVORA gibt keine Zeiten vor | PLANNED |
| Geteilter Dienst | **nicht in HD-3a**; Folgepaket **HD-3s** (zwei Blöcke, Ruhezeit, Überschneidung, Pensum über beide) | PLANNED, nach HD-3a |
| Einteilen von Hand | Regelverstoss: Warnung nennt die Regel, Speichern möglich, Warnung bleibt auf der Zelle (Woche und Monat), Audit-Ereignis mit bestätigender Person; Abwesenheit und Doppelbelegung **gesperrt** | PLANNED; vor realen Daten `lca` und Clinical Owner neu |
| Wünsche je Person | eigene Tabelle: bevorzugte Wochentage mit Dienstart, Tage ohne Arbeit; Lesen nach RLS wie andere Personendaten; Schreiben nur über Security-Definer-Befehl für `lead` und `planner`, mit Audit und LEAVE1; **kein Freitext-Grund** (kein Gesundheitsdatum) | PLANNED |
| Solver | Wünsche nur als Reihenfolge, brechen nie eine Pflichtregel; Ergebnis listet jeden nicht erfüllten Wunsch mit Grund; Pflicht: Abwesenheit, Doppelbelegung, Qualifikation und Mindestbesetzung (Lücke nie «besetzt»), Pensum, Ruhezeit ≥ 11 h, ≤ 6 Tage in Folge, Schichtmodell | PLANNED; fixe Regel, keine KI |
| Messung (FE-125 (4), ergänzt §5a) | (M1) Anteil der automatisch erstellten Dienste im Monatsplan, die die Heimleitung unverändert übernimmt; (M2) Zeit für einen Monatsplan am synthetischen Testheim; `eng` berichtet beide nach jedem Paket | PLANNED |

**Zusätzliche Abnahmekriterien HD-3a:** Unit-Tests: ein erfüllbarer Wunsch wird erfüllt; ein unerfüllbarer Wunsch erscheint mit Grund in der Liste; 0 Verstösse gegen Pflichtregeln auch mit Wünschen; `early_only` nie im Spät- oder Nachtdienst; Dienstart ohne Art nie an ein eingeschränktes Modell. pgTAP: Wunsch schreiben nur `lead`/`planner` derselben Institution, mit Audit-Zeile; Fremd-Institution und andere Rollen abgelehnt; Wert `day_only` nach der Migration nicht mehr vorhanden; Einteilen von Hand auf Abwesenheit oder Doppelbelegung abgelehnt, Regelverstoss mit Warnung gespeichert und auditiert. Gates unverändert in einem Fenster (`cra`, `uxa`, `aia`; `lca` vor realen Daten). Schätzung `eng`: +1 bis 2 Läufe; der PO nimmt das in Kauf (Founder-Scope).

**PO-Ergänzung 2026-11-25 10:39 (FE-128, Founder-Entscheid «Die Eingabe gehört noch ins HD-3a.», von `eng` wiedergegeben auf [#1729 7158121240](https://github.com/Ivica1984/navora-mvp/pull/1729#issuecomment-7158121240); vom PO nicht selbst gehört).** Founder-Scope, keine PO-Zusatzbedingung (BK BUILD PHASE (3)). Anlass: Befund R-5-1 von `eng` ([7158015717](https://github.com/Ivica1984/navora-mvp/pull/1729#issuecomment-7158015717)): ohne Eingabebildschirm endet der Vorschlag auf Staging bei «Kein Vorschlag».

| Teil | Vertrag HD-3a ab 10:39 | Status |
|---|---|---|
| Heim-Grenzen | Wochensoll, Ruhezeit, Tage in Folge; nur `lead`; bestehender Befehl `institution_set_planning_limits`; Marke «Beispielwert des Heims / Arbeitszeitgesetz nicht abschliessend geprüft» je Feld | PLANNED |
| Schichtklasse | je Dienstart Früh, Spät, Nacht oder «keine Klasse»; nur `lead`; `institution_set_shift_class`; zeigt die Zahl der Einteilungen, die nicht mehr passen | PLANNED |
| Personenplanung | Pensum 10–100 % oder «nicht eingetragen», Schichtmodell; `lead` und `planner`; `institution_set_staff_planning` | PLANNED |
| «Kein Vorschlag» | verweist auf genau diese Felder, nicht auf «Einstellungen» | PLANNED |
| Daten auf Staging | **keine Rückfüll-Migration, keine erfundenen Werte**; `staging-smoke` Pfad 7 trägt fehlende Werte über die Formulare ein | PLANNED |

**Zusätzliche Abnahmekriterien (FE-128):** e2e 390 px je Formular; Negativtests: `planner` sieht kein Formular für Heim-Grenzen und Schichtklasse, `viewer` und Team-Pflegende sehen keines; T-1 «gesendet = gezeigt»; T-2 ein falscher Wert wird mit sichtbarem Text abgelehnt. Keine Migration nötig (Befehle haben LEAVE1-3, Audit, pgTAP 171/172; Feststellung `eng`, vom PO nicht geprüft).

**CGR-284 im Vertrag (PO, 2026-11-25 10:39; angekündigt in der Ergänzung 16:39, keine neue Bedingung):** (a) der Zustand nach «Vorschlag übernehmen» wird nur aus `institution_plan` gelesen, nie aus der Solver-Ausgabe; (b) ein Test auf dem 60-Personen-Monat: nach der Übernahme stimmt für jede Zelle der vom Solver vorhergesagte Zustand (besetzt oder Lücke) mit `institution_plan` überein, eine Abweichung lässt den Test scheitern; (c) ein Lückengrund zählt Personen nach demselben exakten Stufencode wie CR-244 (keine Ersatzregel; eine solche setzt nur der Clinical Owner). Wortlaut und Quelle: `CLINICAL_GOVERNANCE.md` CGR-284.

**Hinweise ohne Bedingung:** AUT-212 (`aia` Review 91, Lückenzahl und Solver-Millisekunden im Laufprotokoll speichern) ist ein Rat an `eng` für das bestehende Messkriterium M1/M2 (§5a, FE-125 (4)), keine neue Bedingung. Die drei Pfad-7-Hinweise (a)–(c) von `eng` in R-5-1 liegen beim Schreiber.

**Nicht in HD-3a (Folgepakete, Reihenfolge nach FE-125 (3)):** **HD-3s** geteilter Dienst; **HD-3c** Wochenenden pro Monat, Ausgleichstage, Fairness, HiGHS (ADR-224 Punkt 3b); **HD-AI** Regeleingabe in eigenen Worten durch ein Sprachmodell (nach AI1 Schritt (b), nur synthetische Daten, D-35 A, Heimleitung bestätigt). **Widerspruch Reihenfolge (gemeldet):** FE-122 (16:46) nennt INTAKE-E2E als nächstes Paket nach HD-3a; FE-125 (ca. 19:20, neuer) nennt HD-3c «direkt nach HD-3a». Nach README-Regel 10 gilt bis zur Founder-Antwort der neuere Entscheid: **HD-3c direkt nach HD-3a**. Die Reihenfolge danach (INTAKE-E2E, HD-3s) ist OPEN und geht als Auswahlfrage (FE-124) an den Founder: (A) HD-3c → HD-3s → INTAKE-E2E (Dienstplanung zuerst ganz fertig; Zuweiser-Flow später); (B) INTAKE-E2E → HD-3c → HD-3s (FE-122 wörtlich; 80-%-Ziel später messbar); (C, **Empfehlung PO**) HD-3c → INTAKE-E2E → HD-3s (80-%-Ziel zuerst messbar, dann der Kernweg Zuweisung → Team; der geteilte Dienst ist klein und betrifft nur Heime, die ihn nutzen). Beide Folgepakete erhalten vor Start einen Brief nach `_TEMPLATE.md`; kein Paket startet vor der HD-3a-Abnahme (README-Regel 12).

**PO-Ergänzung 2026-11-25 14:39 (FE-129, Founder-Kommentare [#1712 7163623239](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7163623239) und [#1729 7163865258](https://github.com/Ivica1984/navora-mvp/pull/1729#issuecomment-7163865258); vom PO selbst gelesen).** Founder-Scope: Lieferung des bedienbaren Ablaufs auf Staging zuerst.

| Punkt | Vertrag HD-3a ab 14:39 | Status |
|---|---|---|
| Kernablauf | Monatsvorschlag aus eingetragenem Pensum, Abwesenheiten, Ruhezeit 11 h (dazu die bisherigen Regeln), Übernahme, Anzeige aus `institution_plan` | PLANNED (Bereitbericht) |
| R-6-3 Komma-Eingabe, R-6-2 (a) | im Vertrag; laut `eng` in `a2df8ee` gebaut | IMPLEMENTED (laut `eng`, vom PO nicht geprüft) |
| R-6-1 / R-7-1 (Migration 0178), R-7-2 | **nicht in HD-3a**, keine neue Migration; Folgepunkt **HD-3a-F1** | PLANNED (Folge) |
| R-6-2 (b) Prüfung unter Zeilensperre | **nicht in HD-3a**; Folgepunkt HD-3a-F1 | PLANNED (Folge) |
| CGR-284 (a)–(c) | bleibt (keine Founder-Verschiebung); zu (b) Auswahlfrage an den Founder | PLANNED |
| §5a | ohne Schemaänderung: M2 aus Server- oder CI-Messung, als solche benannt (R-9-2 Alternative); M1 «Messweg IMPLEMENTED, Wert UNKNOWN bis Founder-Durchgang» (R-9-3); keine erfundenen Werte | PLANNED |

**Bekannte Grenze im Bereitbericht (Pflicht, Wortlaut nach `eng` 7163937907):** «Pensum oder Wochensoll wird zwischen ‹Plan vorschlagen› und ‹übernehmen› auf ‹nicht eingetragen› gesetzt → die Zeilen werden ohne die Wochenstunden-Prüfung gespeichert.» Ruhezeit, Tage in Folge, Schichtmodell, Abwesenheit und Doppelbuchung prüft die Datenbank weiter je Zeile. **HD-3a-F1** (R-6-1, R-7-1, R-7-2, R-6-2 (b)) ist vor der HD-3b-Abnahme und zwingend vor realen Daten fertig.

**Auswahlfrage an den Founder (FE-124), CGR-284 (b) Gleichheitstest auf dem 60-Personen-Monat (R-9-1):** (A, **Empfehlung PO**) in HD-3a behalten: ein Testlauf in bestehenden `app`/`db`-Jobs, keine Migration; beweist, dass der Bildschirm nach der Übernahme genau den Zustand der Datenbank zeigt (Lücken sichtbar); kostet vermutlich ein Teilstück. (B) nach HD-3a-F1 verschieben: schneller prüfbereit; bis dahin ist die Gleichheit nur am 9-Personen-Beispielheim und in Unit-Tests gezeigt, als bekannte Grenze im Bereitbericht. Ohne Antwort gilt (A).

### 5c. Zielarchitektur der automatisierten Dienstplanung (FE-126; PO-Einordnung 2026-11-24 20:39)

Quelle: Founder-Freigabe in der `eng`-Live-Sitzung ca. 19:40, Wiedergabe durch `eng` auf [#1712 7141895771](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7141895771) (vom PO nicht selbst gehört). Leitsatz: **Das Rechenwerk plant, die Heimleitung entscheidet, die KI hilft.** Diese Einordnung ändert den HD-3a-Vertrag (§5b) **nicht** und fügt ihm keine Merge-Bedingung hinzu (FE-089 (3)).

**Paketfolge (ersetzt die Paketnamen aus FE-125 (3); Reihenfolge nach FE-127 (PO-Nachführung 2026-11-24 23:39): HD-3a → HD-3s → HD-3b → INTAKE-E2E → HD-3c → HD-3d; Schätzungen in stündlichen `eng`-Läufen, vom Founder):**

| Paket | Inhalt | Schätzung | Status |
|---|---|---|---|
| HD-3a (#1729) | Greedy, Pflichtregeln, Wunschtage und Nicht-Tage, Übernehmen, Bildschirm, Staging-Smoke (Vertrag §5b) | noch 4–6 | aktiv; Greedy IMPLEMENTED auf dem Branch (Teil 2), Übernehmen PLANNED (Teil 3) |
| HD-3s | geteilter Dienst (zwei Blöcke): Pause keine Arbeitszeit, Ruhezeit nach Block 2, ein Arbeitstag, Pensum ohne Pause, Soll pro Tag nur Hinweis (Sollstunden ÷ Arbeitstage pro Woche, Feld je Heim, Vorgabe 5), zulässig für Schichtmodelle «alle Dienste» und «keine Nacht» (FE-127 (3)) | 1–2 | PLANNED, **direkt nach HD-3a** (FE-127 (1)); Regeln und Tests vorbereitet auf `probe/hd3s-split-shift-red` (nicht gemergt); ArG-Lesart `lca` vor echten Daten |
| HD-3b | HiGHS (MIT, WebAssembly im Server, kein neuer Dienst; Zeitgrenze 10 s als Vorschlag; Greedy als Rückfall, offen gemeldet), Wochenenden pro Monat, Ausgleichstage, Fairness, Stabilität, Kennzahlen (Abdeckung, Wunscherfüllung, Fairness), gespeicherte Planungsläufe | 5–8 | PLANNED nach HD-3s; erster Schritt: Laufzeit HiGHS (UNKNOWN) und Messung der drei Gewichtsprofile, danach wählt der Founder die Startwerte (FE-127 (2)) |
| INTAKE-E2E | durchgehender Zuweiser-Flow Spitalaustritt → Extraktion → Quartier-Match → 1-Klick-Übernahme auf `/field` (FE-122, #1726, geschnitten IE-1/IE-2) | — | PLANNED nach HD-3b (FE-127 (1)); KLV-Katalog (D-15 C) bis dahin mit `cra` und Clinical Owner vorbereitbar |
| HD-3c | KI: Text in eigenen Worten → strukturierte Regeln (Heimleitung bestätigt); Erklärungen nur aus Daten des Rechenwerks; nach AI1 Schritt (b) | 3–5 | PLANNED; angeschlossenes Modell nur mit synthetischen Daten (D-35 A), `lca` vor echten Daten |
| HD-3d | Ausfall-Umplanung: Rechenwerk rechnet 2–3 Optionen, KI ordnet und erklärt | 3–5 | PLANNED |

**Umbenennung (kein Inhaltswechsel):** «HD-3c» aus FE-125 (Wochenenden, Ausgleich, Fairness, HiGHS) heisst jetzt **HD-3b**; «HD-AI» aus FE-125 heisst jetzt **HD-3c**. Ältere Journal- und Brieftexte bleiben unverändert; massgeblich ist diese Tabelle.

**Feste Grundsätze (in Kraft, Simulation):** Pflichtregeln sind harte Nebenbedingungen, Regelverstösse immer 0; eine Lücke ist nie ein Regelbruch und nie «besetzt» (Schlupfvariable «fehlender Platz»); Wünsche, Fairness und Stabilität nur als Strafpunkte; drei Prüfungen (Rechenwerk, unabhängiger Prüfer `verifyDraft`, Datenbank beim Übernehmen unter Personensperre); die KI plant nie selbst. Kennzeichnung je Funktion: Greedy und HiGHS = **feste Regel**; HD-3c/HD-3d-Texte = **angeschlossenes Modell** (erst nach AI1 (b)), bis dahin Testersatz.

**Messung:** Automatisierungsgrad = vorgeschlagene Dienste, die unverändert übernommen werden ÷ alle besetzten Dienste des Monats, Ziel ≥ 80 % (entspricht M1 aus §5b); dazu Abdeckung, Wunscherfüllung, Fairness, Rechenzeit (< 2 s Greedy, < 10 s Optimierung), Planungszeit der Heimleitung (Minuten von Menschen UNKNOWN bis gemessen). In CI ein festes 60-Personen-Testheim als Qualitäts-Regressionstest; alle Werte «Simulation, synthetische Daten».

**OPEN:** Startgewichte der Strafpunkte: Founder wählt nach der Messung der drei Profile in HD-3b (FE-127 (2)); Laufzeit HiGHS (UNKNOWN); Lesart des Arbeitsgesetzes vor echten Daten (`lca`), für HD-3s insbesondere: 14-h-Tagesspanne mit geteiltem Dienst, Pause als Nicht-Arbeitszeit, Ruhezeit nach Block 2, 50 h/Woche gegenüber dem BGAP-Entwurf, Nachtvariante (Fragen von `eng`, 7146360770). **Gelöst (FE-127 (1)):** Stelle von INTAKE-E2E nach HD-3b; geteilter Dienst vor HD-3b.

**Nicht HD-3a-Bedingung (benannte Folgepunkte):** gespeicherter Planungslauf je Übernahme (AUT-201) und M1b/Stichtag (AUT-202) gehören nach der Founder-Tabelle zu HD-3b; `eng` darf eine Lauf-Kennung (`apply_id`) schon in HD-3a schreiben, wie in §5b für M1 nötig (WIE bei `eng`).

### 5d. Richtung künftiges Rechenwerk (FE-134; PO-Einordnung 2026-11-26 21:39)

Quelle: Founder-Kommentar [#1712 7202183900](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7202183900) (vom PO selbst gelesen). **Richtung, kein Baustart.**

- **Pflichtregeln immer hart:** Qualifikation und Skill-Mix, Verfügbarkeit, Absenzen, Schichtmodell, bestätigte Einteilungen, Ruhezeit, vertragliche Kapazität, alle Schutzregeln. Verstösse immer 0 (wie §5c).
- **Rangfolge nur unter vollständig gültigen Plänen:** (1) weniger HF-kritische Lücken; (2) höhere Gesamtabdeckung; (3) Nähe zum vertraglichen Monatssoll / Pensum je Person (HD-3a-F3, FE-133 (2)); (4) faire Verteilung unbeliebter Dienste (Nacht, Wochenende, geteilt); (5) weniger externe Aufträge, nie zulasten von 1–4. Die Strafpunkt-Profile aus FE-127 (2) ordnen sich dieser Rangfolge unter.
- **Neuer Löser nur nach Benchmark:** ein Kandidat (z. B. HiGHS) ersetzt den Greedy aus HD-3a nicht, weil er fortgeschrittener ist. **HD-3b-0 «Löser-Benchmark (synthetisch)»** (PLANNED, eigener Vertrag durch `po` nach HD-3a-F1) muss zeigen: 0 Pflichtregelverstösse; messbare Verbesserung in der Rangfolge oben; begrenzte Serverlaufzeit; deterministische und erklärbare Ergebnisse; der Löser schreibt nie direkt in die Datenbank (Übernahme nur über die bestehenden Prüfungen). Ohne Abnahme von HD-3b-0 bleibt der Greedy.
- **Präzisierung von §5c:** die Zeile HD-3b («HiGHS … ab HD-3b») gilt nur noch unter dieser Bedingung (FE-134 vor FE-126/FE-127, README-Regel 10).
- **Paketfolge (Stand 21:39):** HD-3s → HD-3s-F2 → HD-3a-F1 → HD-3a-F3 (nach Founder-Wahl) → HD-3b-0 → HD-3b → INTAKE-E2E → HD-3c → HD-3d.

## 6. Gemeinsames End-to-End-Abnahmekriterium auf Staging

Es gibt drei ausdrücklich benannte Abnahmen, jede auf einem benannten Commit mit `ci` grün, `ci-repeat` 10/10 (`db`, `e2e`) und `staging-smoke` grün auf dem Merge-Commit. Danach schickt der PO eine Meldung mit App-Commit, Migrationsstand und Lauf-ID. Der Founder bedient den Weg selbst, bevor «geliefert» gilt.

1. **Teilabnahme HD-1 «Planen im Heim»** (ausdrücklich eine Teilabnahme, nicht das Register): Als Heimleitung Station öffnen → synthetische Mitarbeitende einteilen → Woche, Monat und individuellen Plan prüfen (gleicher Stand in allen drei) → Abwesenheit erfassen → Lücke in Woche, Monat und Plan sehen. Negativ in CI: fremdes Heim, Netzwerk-Admin und Koordinator lesen nichts; Viewer kann nicht einteilen; Doppelbelegung und Überschneidung, auch eines Nachtdienstes über Mitternacht mit dem Frühdienst des Folgetags, werden abgelehnt; Zugangsende sperrt Schreiben (LEAVE1).
2. **Registerabnahme HEIM-DP «funktionsfähig, feste Regeln»** (nach HD-2): Weg 1 → «Externen Auftrag vorbereiten» → prüfen, senden → Basler Pflegekraft übernimmt in `/team` → Heim-Woche zeigt T → Person bestätigt → G in Woche, Monat, Plan und «Externe Aufträge» → Abwesenheit der bestätigten Person → überall N mit der nächsten Handlung, nirgends «gedeckt». `/team` und `/field` zeigen denselben Sachverhalt.
3. **Registerabnahme HEIM-DP «KI-gestützt»** (nach HD-3): Abwesenheit in eigenen Worten → Vorschlag bestätigen → Umplanungsoptionen mit Marke «KI-Vorschlag» → Option wählen → verbleibende Lücke als Auftrag; mit Not-Aus derselbe Weg nur mit Regelmarken.

## 7. NAVORA-Betreiber und Coach (begrenzter Weg, PO entscheidet die Reihenfolge)

**Ist (IMPLEMENTED, `eng`-Prüfung `docs/engineering/probes/ARCH1_ENG_REVIEW.md` §3):** Die Rolle `coach` ist heute ein Koordinator: `is_coordinator` gilt für `admin`, `coach` und `operations`, mit organisationsweitem Zeilenzugriff auf 26 Tabellen (u. a. `cases`, `care_visits`, `visit_reports`, `quality_events`). Ob die Gesundheitsspalten aller 26 Tabellen gesperrt sind, ist UNKNOWN. Das gilt nur für synthetische Daten. **Vor realen Daten muss es behoben sein** (Phase-B-Voraussetzung).

| Schritt | Inhalt | Wann |
|---|---|---|
| C0 | Heimdaten sind für Netzwerk-Admin, Koordinator und Coach unsichtbar (pgTAP auf #1623: «the admin of the network … reads nothing», «a coordinator of the network has no institution») | in HD-1 |
| C1 | Betreiberfinanzen: eigener NAVORA-Bereich, liest nur Abo- und B2B-Erträge; keine Pflegeumsätze, keine Fallbeträge | nach HEIM-DP |
| C2 | Support: Konto, Funktion, Fehlerart und Zeit; keine Fallinhalte | nach C1 |
| C3 | Neutraler Coach: eigene Rolle ausserhalb der Organisationsmitgliedschaft; liest nur Teamzahlen über Funktionen und nur auf Anfrage eines Teams; die heutige Rolle `coach` wird zu `coordinator` umbenannt (ein Paket) | vor Phase B; `cra`/`lca` prüfen |

## 8. Nicht in HEIM-DP

Pflegeplanung von Bewohnenden, Arbeitszeitgesetzprüfung (OPEN `lca`), Lohn und Abrechnung des Heimpersonals, Dokumentation (Modul 2), Angehörige (Modul 3), Push-Mitteilungen, Modulbuchung, Spital, Privatperson, reale Daten. Bis zur Registerabnahme 2 ist der Menüpunkt nur für Simulationskonten sichtbar.

## 9. Vision-Check (FE-070 (7), kurz)

Mehr direkte Pflegezeit: keine Telefonkette und kein Abtippen bei Lücken. Kontinuität: Der Status bleibt ehrlich, ein Ausfall ist sofort sichtbar. Einkommen: Das Heim zahlt den Teampreis direkt, ohne Agenturaufschlag und ohne Provision. Autonomie: Das Team entscheidet über die Übernahme; das Heim teilt keine externe Person ein. Weniger Verwaltung: Der Optimierer bereitet zulässige Pläne vor. Geschäftsmodell: Die Dienstplanung ist getrennter B2B-Umsatz (Modul 1), Pflegeumsatz bleibt beim Team, und es fliesst kein Geld über NAVORA.

## PO-Teilabnahme HD-1 (geplanter PO-Lauf 2026-11-21 03:39, Signal FE-105 (1) (d))

Benannter Commit `9debf74` (Code gleich `494dd0e`). Gate «Simulation, synthetische Daten». Der PO hat keine Tests lokal ausgeführt; alle Nachweise aus GitHub-Jobdaten und Roh-Protokollen.

| Kriterium | Ergebnis | Nachweis |
|---|---|---|
| R1 inaktive Person nie anwesend | erfüllt | pgTAP `159_hd1_residual_r1_r3` ok ×10; e2e «HD-1 R1 …» ×10 |
| R2 keine Zeitänderung einer eingesetzten Dienstart | erfüllt | pgTAP 159 (`shift_type_in_use`) ok ×10 |
| R3 Abwesenheit ganzer Kalendertag, auch Nacht hinein | erfüllt | pgTAP 159 ok ×10 |
| Ready-Report (Midnight-Test, LEAVE1 ehrlich, Gleichzeitigkeit) | erfüllt; Gleichzeitigkeit als OPEN benannt | `Paket prüfbereit:` 7050177132 |
| Gates | `cra`, `uxa` clear auf `1eb228a` | 7051236096, 7051219005 |
| §6 (1) Weg Woche, Monat, Plan je Person, Abwesenheit, Lücke | erfüllt | e2e `hd1-home-plan.spec.ts` 390/1440 px ×10 |
| Negativ: Teampflegekraft sieht keine Heimdaten | erfüllt | e2e «HD-1 permission …» ×10; Netzwerk-Admin/Koordinator per pgTAP (Gate-Nachweis #1623) |
| `ci` grün auf Merge-Commits | erfüllt | 44822518383 (`2378c2a`), 44851559796 (`494dd0e`) |
| `staging-smoke` Pfad 4 grün auf Merge-Commit | erfüllt | 44851559771 auf `494dd0e`, 5/5; Render `9debf74` |
| `ci-repeat` 10/10 `db`, `e2e` | erfüllt, 20/20, 0 skipped | 44852899930; `db` «Files=159, Tests=6135», PASS; `e2e` «198 passed»; im Fenster 02:54–03:07 |

PO-Status: **accepted** (Teilabnahme). Folgeposten unverändert: CGR-267 bis CGR-269, UXR-265 bis UXR-268. Nächstes Paket: HD-2 (§4).

## PO-Teilabnahme HD-2 (geplanter PO-Lauf 2026-11-21 14:39, Signal FE-105 (1) (d))

Benannter Commit `0b8f537` (`recovery/main` nach #1641 `ca334ce` und den reinen Dokumentations-Merges #1657 `13e8606`, #1658 `0b8f537`; Code gleich `ca334ce`). Gate «Simulation, synthetische Daten». Der PO hat keine Tests lokal ausgeführt; alle Nachweise aus GitHub-Jobdaten und Roh-Protokollen.

| Kriterium | Ergebnis | Nachweis |
|---|---|---|
| Lücke → vorbefüllter Auftrag über `preview_client_order`/`confirm_client_order`, kein zweiter Bestellweg | erfüllt | Gates #1641; e2e `hd2-gap-order.spec.ts` ×10 |
| Gemeinsamer Status §3/§3a in Woche, Monat, «Externe Aufträge»; FE-110 (b) `order_cover`-Text | erfüllt | `cra-gate: #1641 567e36b clear` 7060791013; `uxa-gate: #1641 567e36b clear` 7061441903 |
| Doppelbestellung je Lücke gesperrt; Rückzug als letztes Teilstück (Grenze: ein aktiver Auftrag je Zelle, HD-2-F1) | erfüllt | pgTAP (Files=162, Tests=6370) PASS ×10 |
| `ci` grün auf Merge-Commits | erfüllt | `ca334ce`, `13e8606`, `0b8f537` (Journal 13:39) |
| Migrationen auf `navora-staging` | erfüllt | `staging`-Job 136836350592: 0161–0163 |
| `staging-smoke` Pfade 5 und 6 grün auf dem Merge-Stand | erfüllt | 44900296031 auf `0b8f537`, 7/7; Render `0b8f537` |
| `ci-repeat` 10/10 `db`, `e2e` | erfüllt, 20/20, 0 skipped | 44905215040 auf `0b8f537` (Zweig `repeat/hd2-accept-0b8f537`); jeder `db`-Versuch «Files=162, Tests=6370», «Result: PASS», keine Zeile `not ok`, kein `# SKIP`; jeder `e2e`-Versuch «203 passed», kein übersprungener, instabiler oder fehlgeschlagener Test; Urteil 136852996371: im Fenster (Start 13:42, Ende 13:57 Zürich) |

PO-Status: **accepted** (Teilabnahme Paket HD-2, Simulation). **Nicht die Registerabnahme §6 (2):** der Weg T → G → N mit Abwesenheit der bestätigten Person und die gleiche Sicht in `/team` und `/field` sind auf Staging nicht als eigener Pfad nachgewiesen, und `/field` fällt auf Staging derzeit ganz aus, wenn `team_visit_alerts` die 8-s-Grenze überschreitet (`staging-smoke` Pfad 3 rot 44902700301, 44906414779; Ursache `docs/engineering/STAGING_DB_SLOWDOWN_2026-11-21.md` §4). Registerabnahme nach PERF1 mit diesem Pfad. Folgeposten unverändert: UXR-269 (#1661, vor dem Founder-Rundgang), UXR-270 bis UXR-273, CGR-270, CGR-271, HD-2-F1, HD-2-F2, AUT-180 bis AUT-182. KI: feste Regeln, kein Modell.

## PO-Teilabnahme HD-3a 2026-11-26 11:39 (geplanter Lauf, Signal (d))

**HD-3a «Optimierung (feste Regeln)» für die Simulation teilabgenommen** (Gate «Simulation, synthetische Daten») auf dem benannten Commit `217a9a58`, zusammen mit ORDER-F1 (inkl. F2, F3, F5), das den Abnahmepfad blockierte (FE-131). Nachweise und Grenzen: `docs/product/ABNAHMEAKTE.md` §2. Kriterien §5b: Gates `cra`, `uxa`, `aia` clear auf `203507b`; `staging-smoke` Pfad 7 grün auf `217a9a58`; `ci-repeat` 45781858795 22/22; bekannte Grenze FE-129 bleibt bis HD-3a-F1 (#1745). **Nächstes Paket nach FE-127 (1): HD-3s**, Vertrag `briefs/HD-3s.md` (approved in diesem Lauf). HD-3a-F1 vor der HD-3b-Abnahme und vor realen Daten. Keine Registerabnahme HEIM-DP «KI-gestützt». Der PO hat keine Tests lokal ausgeführt.
