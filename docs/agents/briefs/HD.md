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
| **HD-1** (#1623) | Heim-Mandant `institutions` (unabhängig von Netzwerk-Organisationen, ARCH1 A1), Stammdaten, Woche, Monat, Plan je Mitarbeiterin, Abwesenheit, Lücke (feste Regeln); 16 Funktionen als Dateien nach STAB1; Beispieldaten; `staging-smoke` Pfad 4 | STAB1 (abgenommen) | `cra` (Qualifikationsstatus; Unterbesetzung nie als «besetzt»), `uxa` (neue Bildschirme 390/1440 px). Kein `lca`-Gate für die Simulation (FE-109 (A)); vor realen Daten Pflicht | **aktiv**, Draft, CI läuft |
| **HD-2** | Lücke → vorbefüllter Auftrag über `preview_client_order`/`confirm_client_order` (kein zweiter Bestellweg); gemeinsamer Status §3 in allen Heim-Ansichten; N mit nächster Handlung; Doppelbestellung je Lücke gesperrt; `staging-smoke` Pfad 5 | HD-1 | `cra`, `uxa` | PLANNED |
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
