# HEIM1 · Der Arbeitsplatz der Heimleitung: Vorlage für Founder und PO (Version 3)

**Autor:** `eng`, 2026-11-20 ca. 15:45. Version 3 ersetzt die Versionen 1 und 2. Sie beantwortet den dritten Founder-Brief:
- Dienstplanung mit benannten Mitarbeitenden;
- B2B und Teamplattform getrennt;
- Diktat über das Gerät;
- die Reihenfolge neu geprüft.

**Status:** Vorschlag. **Nichts davon ist gebaut, nichts geht in einen laufenden PR.** Der PO entscheidet den Produktumfang; seine Sicht fehlt noch (markiert **PO:**).
**Founder-Entscheid in diesem Brief:** Die Planung des eigenen Heimpersonals (Woche, Besetzung, Lücken, später KI-Umplanung) ist das eigenständige **B2B-Planungsmodul**. Die Beauftragung externer Teams ist ein getrenntes Produkt, und beide sind einzeln nutzbar. Der PO trägt das in `FOUNDER_DECISIONS.md` ein.
**Kennzeichnung:**
- **Staging**: auf Staging nachgewiesen;
- **Code**: gebaut und in der CI getestet, auf Staging nicht durchgeklickt;
- **geplant**: nicht gebaut;
- ESTIMATE: Schätzung, keine Zusage;
- OPEN: Entscheid fehlt.

---

## 1. Zwei Produkte, eine Brücke

```
 B2B-PLANUNGSMODUL (Lizenz des Heims)        TEAMPLATTFORM (Gebühr der Teams, 0 % Provision)
 ─────────────────────────────────────        ───────────────────────────────────────────────
 Heim, Stationen, eigene Mitarbeitende        selbstorganisierte Teams, ihre Mitglieder,
 (benannt), deren vom Heim bestätigte         verifizierte Qualifikationen, Abwesenheiten,
 Qualifikationen, Dienste, Abwesenheiten,     Angebote, Übernahmen, Einsätze, Berichte,
 Lücken                                       Rechnungen der Teams
            │                                              ▲
            │  BRÜCKE (nur zwei Wege, sonst nichts)         │
            ├── 1. «Lücke als externen Auftrag anbieten» ──►│  Auftrag mit Verweis auf die Lücke
            │      (Heim bestätigt; ohne Namen des Heimpersonals)
            ◄── 2. Status zurück in den Plan ───────────────┤  angefragt · übernommen · Person
                   (nur Zustand und Team, nie Teamdaten)       bestätigt · durchgeführt
```

**Architektur (Empfehlung `eng`):**
- **Getrennte Daten:**
  - Die B2B-Tabellen gehören zum Heim (Mandant = Kundenkonto des Heims), mit eigenen Rollen und Rechten (RLS).
  - Die Tabellen der Teamplattform bleiben unverändert.
  - Keine Tabelle enthält Personen beider Seiten.
- **Brücke 1:**
  - Ein Befehl erzeugt aus einer Lücke einen **Auftragsentwurf**. Er übernimmt Zeit, Station, Einsatzort, Tätigkeiten und Stufe. Namen des Heimpersonals und den Abwesenheitsgrund übernimmt er nicht.
  - Gesendet wird erst nach Bestätigung, über den vorhandenen Weg «Prüfen → Bestätigen & Absenden». Alle festen Prüfungen der Teamplattform laufen unverändert.
- **Brücke 2:** Eine Lesefunktion gibt dem Plan nur den Zustand des eigenen Auftrags zurück, den es heute schon gibt («Gedeckt · Person benannt, geprüft für HF», Team). Keine Mitgliederliste, keine Preise anderer Teams.
- **Lizenz und Gebühr getrennt:**
  - **B2B-Modul:** Freischaltung je Heim. Seine Abrechnung ist NAVORA-B2B-Umsatz (Blueprint Ledger B, PLANNED).
  - **Monatsgebühr der Teams:** eigene Abrechnung.
  - **Pflegerechnungen der Teams:** gehören den Teams.
  - Es gibt keine gemeinsame Zahl und kein Provisionsfeld.
  - Ein Heim ohne B2B-Modul sieht keine Dienstplanung, kann aber Aufträge erfassen. Ein Heim nur mit B2B-Modul kann planen, ohne Teams zu beauftragen.
- **Jede neue Datenbankfunktion** entsteht von Anfang an als eigene, lesbare Datei (FE-100) und braucht darum kein STAB1.

## 2. Heim-Navigation

Zielbild nach deinem Vorschlag, mit drei Änderungen. Sichtbar ist ein Register nur, wenn es auf Staging eine echte Aufgabe löst.

```
 NAVORA · Testheim Rhein                                    [Station: alle ▾]  [Woche 48 ◂ ▸]
 ┌──────────────┐
 │ Übersicht    │  Heute · Morgen · Diese Woche — «Jetzt zu entscheiden» (inkl. Mitteilungen)
 │ Woche        │  Dienstplan je Station: eigene Mitarbeitende + Lücken + externe Aufträge   [B2B]
 │ Personal     │  Mitarbeitende, vom Heim bestätigte Qualifikationen, Abwesenheiten          [B2B]
 │ Aufträge     │  externe Anfragen: offen · Angebot gesendet · übernommen · gefährdet · erledigt
 │ Kosten       │  bestellt · vereinbart · erbracht · in Rechnung gestellt · Klärung
 │ Einstellungen│  Standorte, Stationen, Dienstvorlagen, Berechtigungen, gebuchte Module
 └──────────────┘
```

**Die drei Änderungen:**
1. **«Mitteilungen & Ausnahmen» zuerst in der Übersicht.** Ein eigenes Register lohnt erst bei vielen Meldungen; zwei Orte für dieselbe Meldung verwirren.
2. **«Personal» als eigenes Register neben «Woche»,** statt in den Einstellungen. Mitarbeitende, Qualifikationen und Abwesenheiten pflegt die Planerin täglich, nicht einmalig.
3. **Dokumentation und Angehörige** bleiben unsichtbar, bis das Modul gebucht und gebaut ist.

**«Woche» zeigt beide Produkte in einem Raster, aber unterscheidbar:**
- eigene Mitarbeitende mit Namen;
- externe Besetzung mit Team und Zustand;
- Lücken.

So pflegt das Heim keine zweite Liste.

## 3. Wochenablauf mit benannten synthetischen Mitarbeitenden

**Synthetische Ausgangslage:**
- «Testheim Rhein (synthetisch)», Stationen **Rhein 1** und **Rhein 2**, Dienste Früh 07–15, Spät 15–23, Nacht 23–07.
- **Dienstvorlage Rhein 2, Früh:** 3 Personen, davon mindestens 1 HF. Das Heim legt diese Anforderung selbst fest; NAVORA schreibt keine Besetzungsregel vor (§6).
- **Personal Rhein 2:** Anna Muster (HF), Ben Beispiel (FaGe), Carla Test (FaGe), David Probe (AGS). Alle Namen synthetisch.
- **Plan Mittwoch früh:** Anna, Ben, Carla.
- **Montag 10:00:** Carla meldet sich für Mittwoch ab.

| # | Schritt | Was die Heimleitung sieht | Backend | Wer entscheidet | Stand |
|---|---|---|---|---|---|
| 1 | Plan erstellen | Woche Rhein 2: je Dienst die eingeplanten Namen mit Stufe | Dienste, Zuteilungen, Personal (B2B) | Heim (Planerin) | geplant |
| 2 | Abwesenheit erfassen | Bei Carla am Mittwoch «abwesend», ohne Grund | Abwesenheit ohne Grundangabe | Heim | geplant |
| 3 | Lücke entsteht von selbst | Mi früh Rhein 2: **«2 von 3 besetzt · HF vorhanden · 1 FaGe/AGS fehlt»** | feste Regel: Dienstvorlage minus Zuteilungen minus Abwesenheiten | – | geplant |
| 4 | Intern vertreten? | «Kann vertreten (laut Plan frei, Stufe passt): David Probe (AGS)», dazu der Hinweis «Arbeitszeitregeln nicht geprüft» | feste Regel: nicht eingeplant, nicht abwesend, Stufe erfüllt die Vorlage | **Heim** wählt oder lehnt ab | geplant |
| 5 | Extern anfragen | «Als externen Auftrag anbieten»: Entwurf mit Datum, Zeit, Station, Einsatzort, Stufe FaGe, Tätigkeiten aus der Vorlage | Brücke 1: Entwurf mit Lückenverweis, nicht gesendet | – | geplant |
| 6 | Ergänzung in eigenen Worten | Feld «Was ist sonst wichtig?», getippt oder per Gerätediktat. KI schlägt zusätzliche Tätigkeiten vor, jede markiert «KI-Vorschlag aus Ihrem Text», einzeln annehmbar | angeschlossenes Modell (AI1-Anschluss), danach feste Prüfung | – | geplant |
| 7 | Prüfen und absenden | Zusammenfassung. «Geprüft: Region, Stufe, Tätigkeitsnachweis, eingetragene freie Zeit» oder ehrlicher Nullfall. «Preis legt das übernehmende Team fest» | `preview_client_order` → `confirm_client_order` | **Heim** bestätigt | **Staging** (ohne Lückenbezug) |
| 8 | Status im Plan | Mi früh: «2 eigene · 1 extern angefragt (Angebot an 3 Teams)» | Brücke 2 | – | geplant |
| 9 | Team übernimmt | erst «übernommen, Person bestätigt noch», dann «besetzt extern · Testteam Basel» | `take_order`, Bestätigung der Person | **Team** | **Staging** / **Code** |
| 10 | Ausfall der externen Person | Übersicht, «Jetzt zu entscheiden»: «Mi früh Rhein 2: externe Besetzung weggefallen · Angebot läuft wieder · *zuständig: NAVORA-Angebot*». Dazu zwei Knöpfe: intern vertreten / abwarten | vorhandenes Signal (0144), neu auch an das Heim | Team besetzt neu; **Heim** entscheidet, ob es intern handelt | Signal nur ans Team (**Code**) |
| 11 | Durchgeführt und Rechnung | Dienstzelle: «durchgeführt · Bericht 15:02», Rechnung beim Dienst; Kosten in der Monatsübersicht | Bericht, Rechnung (BK-f) | Pflegekraft, Team | **Staging** (ohne Plan) |

**Antworten auf deine Fragen:**
- **Lücke ohne zweite Liste:**
  - Die Anforderung steht **einmal** in der Dienstvorlage je Station und Dienst.
  - Die Lücke ist immer berechnet: Vorlage minus Zuteilung minus Abwesenheit.
  - Niemand trägt eine Lücke ein. Eine Abwesenheit öffnet sie, eine Zuteilung schliesst sie.
- **Keine doppelte Eingabe:**
  - Der Auftrag entsteht aus der Lücke und trägt deren Angaben. Die Brücke ist die einzige Stelle, die Daten herüberreicht.
  - Verschwindet die Lücke, weil die Abwesenheit zurückgezogen oder intern besetzt wurde, markiert NAVORA den Entwurf oder Auftrag als «Lücke besteht nicht mehr». Danach fragt NAVORA nach dem Zurückziehen; das braucht den Ablauf «Ändern und Stornieren».
- **Wer handelt bei einem Ausfall:** Jede Lücke hat genau einen Zustand mit Zuständigkeit:
  - offen;
  - **intern in Klärung** (mit Namen der Heimnutzerin, die sich darum kümmert);
  - **extern angefragt**;
  - übernommen;
  - besetzt.

  Wird eine Lücke intern besetzt, während extern angefragt ist, verlangt NAVORA eine Entscheidung. Es gibt also keine doppelte Besetzung ohne Hinweis.
- **Was jeden Tag Zeit spart: die «Morgenlage».** Ein Blick um 07:00 zeigt:
  - neue Abwesenheiten seit gestern;
  - Lücken heute und morgen, je mit «kann vertreten» aus dem eigenen Personal;
  - den Stand der externen Anfragen.

  Das ist eine feste Regel, keine KI, und spart das Zusammensuchen aus Telefon, Excel und Mails.

## 4. Diktat und KI-Entwurf

Wie von dir entschieden:
- **Eingabe:** ein Textfeld. Das Gerätediktat (Mikrofon-Taste der Handytastatur, Diktieren in Windows/macOS) füllt es; NAVORA nimmt kein Audio auf. Die Bedienbarkeit wird auf iPhone/Safari, Android/Chrome und Windows/Edge geprüft und dokumentiert.
- **Die Eingabe ist austauschbar:** Die KI-Funktion erhält nur Text. Eine spätere eigene Audioaufnahme ist ein neuer Eingabeweg vor demselben Text, und an der KI ändert sich dann nichts.
- **Das Modell schlägt nur vor:**
  - Datum, Zeit, Ort, Anzahl Personen, beschriebene Tätigkeiten, jede mit der Textstelle als Quelle;
  - die Stufe nur, wenn sie wörtlich genannt ist;
  - Fehlendes bleibt leer mit «bitte angeben».

  Feste Regeln prüfen danach Region, Stufe zu Tätigkeit und Zeit.
- **Sichtbar unterscheidbar:**
  - «KI-Vorschlag aus Ihrem Text» (angeschlossenes Modell, nur Staging, synthetisch);
  - «aus Ihrer Dienstvorlage» (Übernahme aus dem Plan);
  - «geprüft nach Regel» (feste Prüfung).
  - In der CI läuft ein Testersatz mit festem Antworttext, der nie «KI» heisst.

## 5. Baufolge, neu geprüft

**Deine Frage:** Wann nutzt eine Heimleitung NAVORA erstmals als Arbeitsplatz für ihre Woche?

**Erkenntnis aus der Prüfung:**
- Das B2B-Planungsmodul besteht aus **neuen** Tabellen und **neuen** Funktionen. Es ändert keine der Funktionen, die STAB1 aufräumt. Es kann also **vor** STAB1 starten.
- STAB1 ist schon begrenzt: auf die Funktionen, die Auftrag, Übernahme und Abwesenheit der Teams als Nächstes ändern, ohne die vier Funktionen der Tranche 2. ESTIMATE 2–3 Läufe, Ergebnis: CI prüft, dass die Dateien gleich der Datenbank sind.
- STAB1 wird erst vor **W2** nötig, weil W2 den Auftragsweg ändert.

| # | Paket | Neu auf Staging bedienbar | Braucht | ESTIMATE |
|---|---|---|---|---|
| **W1** | **Woche und Personal (B2B, Kern)**: Stationen, benannte Mitarbeitende mit vom Heim bestätigter Stufe, Dienstvorlagen, Zuteilung, Abwesenheit, berechnete Lücke, «kann vertreten» | **Heimleitung:** ihre Woche mit Namen planen, eine Abwesenheit erfassen, die Lücke sehen, intern vertreten | nichts (neue Tabellen); `lca` zu Personaldaten | 4–6 Läufe |
| STAB1 | eine Quelle je Auftrags- und Übernahmefunktion (schon beschlossen) | nichts Sichtbares | – | 2–3 Läufe |
| **W2** | **Lücke → externer Auftrag → Status im Plan**, ehrlicher Nullfall, Zustand mit Zuständigkeit | **Heimleitung:** aus der Lücke mit zwei Tipps einen Auftrag senden und im Plan sehen, wann er übernommen ist. **Erster zusammenhängender Arbeitsplatz** | W1, STAB1 | 3–5 Läufe |
| AI1 | KI-Berichtsentwurf (schon beschlossen), Anschluss live | **Pflegekraft:** Entwurf von Claude | Founder: Schlüssel und Kostengrenze auf Render | 3–5 Läufe |
| **K-1** | **KI-Ergänzung im Auftragsentwurf** (Text oder Gerätediktat) | **Heimleitung:** Zusatzbedarf in eigenen Worten → markierte Vorschläge → bestätigen | AI1-Anschluss, W2 | 3–4 Läufe |
| Ü1 | Übersicht mit «Morgenlage» und «Jetzt zu entscheiden», Mitteilung an das Heim bei Übernahme und Ausfall | **Heimleitung:** Morgenlage, Mitteilungen | W2; `lca` zum Inhalt | 3–4 Läufe |
| Ä1 | Ändern und Stornieren in vier Zeitpunkten | **Heimleitung:** ändern ohne zwei Wahrheiten | Ü1; `lca`/`owner` | 4–6 Läufe |
| K1 | Kosten in fünf Spalten, Monat, CSV | **Heimleitung:** Monatsabgleich | – | 2–3 Läufe |
| P2 | Monatsansicht, KI-Umplanungsvorschlag bei Ausfall (B2B) | **Planerin:** Vorschlag für eigenes Personal | W1, AI1-Anschluss | eigener Vertrag |

**Der erste zusammenhängende Heim-Arbeitsplatz** steht nach **W1 + STAB1 + W2**: grob 9–14 Engineering-Läufe plus Gate-Fenster (ESTIMATE). **Zum ersten Mal sichtbar für das Heim ist schon W1:** eigene Woche mit Namen und Lücken, grob 4–6 Läufe.

**KI vor oder nach der Wochenansicht? Empfehlung: danach, aber direkt** (K-1 sofort nach AI1). Begründung:
1. **Die Lücke liefert den grössten Teil der Angaben deterministisch:** Zeit, Station, Stufe, Tätigkeiten. Die KI muss dann nur die frei formulierte Ergänzung strukturieren. Das ist weniger Fehlerfläche, besser messbar und ehrlicher.
2. **Ohne Wochenansicht** würde die KI wieder nur ein Einzelformular füllen. Genau das hast du als schwaches Heimprodukt bezeichnet.
3. **AI1 vor K-1 bleibt richtig:** Der Anschluss mit Not-Aus, Kostengrenze und Protokoll von Vorschlag und Entscheid ist dort fast fertig, und K-1 baut darauf.

**Erste echte KI auf Staging:**
- als Berichtsentwurf (AI1, Pflegekraft) nach W1 + STAB1 + W2 + AI1: grob 12–19 Läufe;
- im Heimablauf (K-1) etwa 3–4 Läufe danach.

**Alternative für dich (Entscheid 1):** AI1 vor W2 ziehen. Die erste echte KI käme dann etwa 3–5 Läufe früher, der zusammenhängende Arbeitsplatz entsprechend später.

## 6. Grenzen und offene Regeln

**Besetzungsanforderungen:** «mindestens 1 HF pro Frühdienst» legt **das Heim** in seiner Dienstvorlage fest. NAVORA schreibt keine Personalschlüssel vor und prüft sie nicht gegen kantonale Vorgaben: OPEN, `cra`/`lca`. Die Ansicht sagt: «Anforderung des Heims».

**Qualifikationen des Heimpersonals:**
- Sie heissen «vom Heim bestätigt». Das Heim ist Arbeitgeber und verantwortlich.
- Sie werden nie mit den verifizierten Nachweisen der Teamplattform vermischt und nie an Teams übermittelt.

**Abwesenheiten:**
- Gespeichert wird nur «abwesend von–bis» ohne Grund. Krankheit ist eine Gesundheitsangabe.
- Ob und wie ein Grund erfasst wird: `lca`.

**«Kann vertreten»:**
- prüft nur Plan, Abwesenheit und Stufe;
- **nicht** Arbeitszeit, Ruhezeiten oder Überstunden. Das wären Arbeitsgesetz-Regeln, OPEN, `lca`; sie werden nicht erfunden.
- Die Ansicht sagt das sichtbar.

**Rechte im B2B-Modul:**
- Heimleitung und Planerin sehen Namen und Pläne.
- Mitarbeitende sehen später nur ihren eigenen Plan.
- Teams sehen nichts davon.
- Die Rollen benennt der PO, die Rechte setzt `eng` mit RLS und pgTAP-Tests um.

**Weitere OPEN-Punkte:**
- Schwelle «gefährdet»: `cra`.
- Folgen kurzfristiger Stornierung: `lca`/`owner`.
- Inhalt der Mitteilungen an das Heim: `lca`.

## 7. Innovationsvorschläge, priorisiert

1. **Morgenlage mit «kann vertreten»** (§3)
   - Spart täglich das Zusammensuchen.
   - Aufwand klein auf W1, feste Regel.
   - Neue Fehlerquelle: Arbeitszeit wird nicht geprüft, was sichtbar vermerkt ist.
   - Kleinster Test: Synthetisch ist Carla abwesend und David frei. Erwartet wird genau David als Vorschlag, Ben nicht, weil er schon eingeplant ist.
2. **Lücke mit Zuständigkeit** (§3)
   - Verhindert, dass zwei Leute dieselbe Lücke parallel lösen oder dass niemand sie löst.
   - Aufwand klein.
   - Kleinster Test: Intern besetzen, während extern angefragt ist. Erwartet wird ein Entscheid-Hinweis, keine stille Doppelbesetzung.
3. **Dienstvorlagen statt Wochen-Neuerfassung**
   - Die Woche wird aus der Vorlage erzeugt; danach werden nur Abweichungen gepflegt.
   - Aufwand klein.
   - Kleinster Test: Eine neue Woche übernimmt alle Vorlagen, und eine Abweichung bleibt nur in ihrer Woche.
4. **Leistungsbestätigung aus dem Bericht in der Dienstzelle**
   - Zeit und Tätigkeitscodes, kein Pflegetext (`lca`).
   - Spart den Abgleich von Rechnung und Plan.
5. **Freiwillig gemeldete Teamkapazität**
   - Später, nach W2.
   - Wettbewerbsfrage: `lca`.

## 8. Founder-Entscheide, die wirklich bei dir liegen

1. **Reihenfolge:** Folgst du dem Vorschlag W1 → STAB1 → W2 → AI1 → K-1? Er weicht von FE-099 (7) ab, wo STAB1 → AI1 → BK-d steht. Oder soll AI1 vor W2 kommen? (§5)
2. **Ein Heim, das nur das B2B-Modul hat:** Darf es in der Simulation auf Staging ohne Lizenzprüfung freigeschaltet sein, bis Preis und Modulabrechnung (GM-2) entschieden sind?

Alles andere entscheiden PO und Fachrollen in ihrem Mandat (§6).

**PO:** Bitte ergänze deine Sicht zu:
- §2: welche Register in W1 sichtbar sind;
- §5: deine Baufolge und den Paketvertrag W1;
- §8: ob du die Entscheide gleich siehst.

---

## Anhang: Belege

- **Staging-Nachweis heute:** `staging-smoke` 44744533079 (4/4) auf App-Commit `8051283`, Datenbank bis 0157. Pfade 1–3 in `tests/staging-smoke/founder-click-paths.spec.ts`.
- **Im Code vorhanden und wiederverwendbar:**
  - Auftragsprüfung `preview_client_order` / `confirm_client_order`;
  - Eignung je Person `private.order_member_step` (0132);
  - Angebot an Teams `private.screen_order_reach`;
  - Statustexte `clientCoverLines`;
  - Ausfall-Signal 0144;
  - Rechnungen 0155/0156;
  - KI-Anschluss mit Testersatz (`src/lib/ai/report-draft/`, Brief `AI1.md`).
- **Fehlt im Code:**
  - Station oder Standort;
  - Heimpersonal und Dienstplan;
  - Stornieren oder Ändern durch das Heim;
  - Mitteilungen an Kundenkonten;
  - Lizenz- und Modulfreischaltung.
- **STAB1-Umfang:** `docs/agents/briefs/STAB1.md` (Tranche 1, ohne die vier Funktionen der Tranche 2; ESTIMATE 2–3 Läufe).
