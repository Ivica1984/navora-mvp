# Abgestimmte Übersicht für den Founder: Staging, BK-e, KI

**Besitzer:** Product Owner (`po`) · **Stand:** 2026-11-18 22:00 (Europe/Zurich; erneute Founder-Nachricht FE-090 um ca. 21:45, abgeglichen mit `eng` #1465 Kommentar 21:45 und `aia` #1466) · Keine Zugangsdaten in diesem Dokument. Fassung 16:20: Git-Verlauf.

Kennzeichnung: IMPLEMENTED · PLANNED · OPEN · UNKNOWN.

**Hinweis zum Stand:** #1421 (BK-e1b) ist seit 17:39 gemergt, #1476 (BK-e1c, Nachtschicht nach Mitternacht) seit 20:39. **BK-e1 (übernommene Schicht in der mobilen Ansicht) ist seit ca. 22:10 für die Simulation abgenommen** (zehnfacher Prüflauf 20/20 auf `3ea17ee`, genau dem Stand, den Staging ausliefert). Nächster Schritt: CGR-256, dann der Berichtsentwurf (BK-e2).

| Frage | Antwort |
|---|---|
| **Was kann ich heute in der echten Staging-App durchklicken?** | **Gebaut und in CI getestet; auf Staging von keinem Agenten durchgeklickt (UNKNOWN).** `eng` hat um 21:45 nur gelesen: 0 Aufträge, 0 Angebote, 0 Übernahmen auf Staging. Die Startseite `https://navora-staging.onrender.com/login` lädt (Formular «Bei NAVORA anmelden», Hinweis «nur synthetische Testdaten»; vom PO 21:55 abgerufen). Login und Bedienung: UNKNOWN, bis `eng` oder Sie den Klickpfad unten ausführen. Darum heisst noch keine Funktion «auf Staging verfügbar». |
| **Welcher App- und Datenbankstand läuft dort?** | **App:** Render `navora-staging` live auf **`3ea17ee`** (Deploy fertig 21:43; vom PO über Render gelesen, von `eng` bestätigt). Enthält BK-e1b (#1421), BK-e1c (#1476) und ADR-204 (#1460). **Datenbank:** höchste Migration **0149** (`bk_e1c_night_visit_on_next_day`); `eng` 21:45 gelesen, `staging`-Job 135085487245 (PO 20:39). **Die früher fehlenden Migrationen (0136, 0137 und 0138–0148) sind eingespielt.** App und Datenbank entsprechen `recovery/main`. |
| **Was fehlt noch an #1421?** | **Nichts mehr am PR:** #1421 gemergt (17:39, `7c04240`) mit fester Restliste R1–R5 erfüllt, Gate-Zeilen `cra` und `uxa` «clear», nur Simulation. Der Fehler «gedeckt, obwohl die Pflegekraft zeitgleich eingeplant ist» ist im Übernahmeweg behoben und getestet (CGR-246, CGR-251, CGR-255: Prüfung unter Personensperre, pgTAP 148, Zwei-Sitzungs-Test). Mobiler Ablauf (Handy-Test 390 px) grün; Schicht über Mitternacht als eine Karte, und seit #1476 erscheint die laufende Nachtschicht nach Mitternacht unter «Heute». **Offen, ausdrücklich:** CGR-256 (Überschneidung zweier von Hand geplanter Einsätze über Mitternacht) ist noch nicht gebaut; `cra`: in Phase A von keiner realen Person erreichbar, Voraussetzung, bevor die Nachtschicht die Simulation verlässt. PO: **nächster Engineering-Schritt** (Gate-Owner `cra`, gezielter Start auf dem Endstand). **Teilabnahme BK-e1:** `ci-repeat` 44393766620 auf `3ea17ee` 20/20 grün (je 10 × Datenbank, 10 × Oberfläche, 0 übersprungen); Gate-Owner PO; Gate «Simulation, synthetische Daten». |
| **Was kann ich nach #1421 zusätzlich bedienen?** | **Teilergebnis (gebaut, CI-getestet; auf Staging UNKNOWN):** Als Pflegekraft erscheint eine übernommene Schicht in `/field` als Karte «Übernommene Schicht» mit Ortszeile (Simulation ohne Strasse) und dem Zeitablauf wie bei jedem Einsatz; eine Nachtschicht 22:00–07:00 ist eine Karte und steht nach Mitternacht unter «Heute» mit Sicherheitshinweisen, «Abschliessen» und «Ereignis melden». Eine Abwesenheit vor Beginn gibt die Übernahme frei; die Auftraggeberin liest dann nicht mehr «Gedeckt». **Noch nicht fertig:** kein KI-Bericht, keine Rechnung. |
| **Welche Funktion nutzt bereits echte KI?** | **Keine.** Teamempfehlung und Begründung sind **feste Regeln**; geplante Berichtsentwürfe zuerst als **Testersatz**. Kein Modell angeschlossen; die Datenbank lehnt heute einen KI-Akteur ab (AUT-115). |
| **Wann kommt die erste echte KI-Demo?** | **Abgestimmte Empfehlung `po` + `aia` (#1466, `aia` Kommentar 6989006175):** zuerst **Auftrag aus Freitext** (BK-d): die Auftraggeberin schreibt z. B. «Nachtwache am 3.12. von 22 bis 7 Uhr in 4051»; das Modell schlägt nur **Datum, Beginn, Ende, PLZ** vor, jede Angabe mit Quellstelle, von einer festen Regel geprüft und einzeln bestätigt. **Qualifikation und Tätigkeiten bleiben von Hand; die harten Regeln (BK-b) prüfen danach wie heute, kein Modell übersteuert sie.** Begründung: sichtbarster Nutzen für Sie als Auftraggeber, kleinstes Risiko (kein Pflegebericht, keine Zuteilung), der ganze KI-Weg (Schlüssel, Umgebungssperre, Protokoll, Abschalter, Kosten) wird dort erprobt. Danach der Berichtsentwurf der Pflegekraft (BK-e2a, mit `cra`-Gate und Unterschrift). **Voraussetzungen:** Ihr Anbieterentscheid und Staging-Schlüssel; `lca` liest die Anbieterbedingungen (gezielter Start); AUT-136 (1) Umgebungssperre gebaut. **Zeitfenster (Schätzung):** erster Live-Lauf auf Staging KW 49 (30.11.–4.12.), wenn Anbieter und Schlüssel bis ca. 24.11. vorliegen. |
| **Was muss ich selbst entscheiden oder einstellen?** | (1) **Klickpfad auf Staging:** entweder `eng` in einer Live-Sitzung die Demo-Konten (FE-086b) vertraulich zum Durchklicken freigeben, oder den Pfad unten selbst gehen und das Ergebnis melden. Nie Zugangsdaten in GitHub. (2) **Seed `kolleginbs`** auf Staging: Ihr Go (ADR-190); für den Grundpfad nicht nötig. (3) **KI:** Anbieter mit Rechenzentrum CH/EU ohne Datenspeicherung wählen, Staging-Schlüssel als Render-Secret hinterlegen, Ausgabenlimit im Anbieterkonto. Sonst nichts. |

## Klickpfad 1: Auftrag → Angebot → Übernahme → «Gedeckt» (in CI getestet; auf Staging UNKNOWN)

Quelle: `tests/e2e/bk-c2-take-status.spec.ts`. Konten: die Demo-Konten aus FE-086b (vertraulich).

1. **Auftraggeber** (`kundebs`): `/order`. Datum einige Tage in der Zukunft, Beginn **07:00**, Ende **15:30**, Einsatzort **4051**, Stufe **HF**, Tätigkeit **Grundpflege**; «Weiter zur Zusammenfassung», «Bestätigen & Absenden». **Erwartet:** «Auftrag bestätigt»; in der Liste «Noch nicht gedeckt».
2. Abmelden. **Pflegekraft HF** (`pflegebs`): `/team`. **Erwartet:** Karte «Neues Angebot», «Empfohlen für euch: jemand von euch ist frei» (feste Regel), «Ich (Pflegekraft)» vorgewählt. «Übernehmen mit Pflegekraft». **Erwartet:** «Übernommen».
3. **Gegenprobe im selben Team** (`assistbs`): `/team` zeigt «Übernommen», ohne Knopf.
4. **Auftraggeber** (`kundebs`): `/order`. **Erwartet:** «Gedeckt · Person benannt, geprüft für HF».

## Klickpfad 2: die übernommene Schicht in der mobilen Ansicht (BK-e1b/e1c; in CI getestet bei 390 px; auf Staging UNKNOWN)

Quelle: `tests/e2e/bk-e1b-take-card.spec.ts`, `bk-e1c-night-visit-next-day.spec.ts`. Am besten am Handy.

1. **Auftraggeber** (`kundebs`): `/order`, wie oben, aber Beginn **22:00**, Ende **07:00** (eine Nachtschicht).
2. **Pflegekraft** (`pflegebs`): `/team`, die Nachtschicht mit «Übernehmen mit Pflegekraft» übernehmen.
3. Dieselbe Pflegekraft: `/field?datum=<Datum der Schicht, JJJJ-MM-TT>`. **Erwartet:** genau eine Karte «Übernommene Schicht», 22:00 – 07:00, Ortszeile «4051 Basel · …» (Strasse in der Simulation nicht übermittelt), Zeile «Kannst du nicht?», kein «Einsatz absagen».
4. Optional: unter «Abwesenheit» die Nacht als abwesend erfassen. **Erwartet:** die Karte bleibt mit «Nicht mehr deine Schicht» und Begründung; als `kundebs` steht unter `/order` nicht mehr «Gedeckt».

Wenn ein Schritt anders aussieht, ist das genau der Teil, den `eng` auf Staging noch prüfen muss; bitte melden.

## Zielbild und Stand der Plattform

| Teil | Stand |
|---|---|
| Auftraggeberansicht: Auftrag erfassen, Deckungsstand | IMPLEMENTED (BK-a, BK-c; Simulation); Staging-Bedienung UNKNOWN |
| Teamabgleich nach Region, Stufe, Tätigkeit | IMPLEMENTED als feste Regeln (BK-b) |
| Team-Dashboard: Angebot, Übernahme, Begründung | IMPLEMENTED (BK-c) |
| Mobile Pflegeansicht: übernommene Schicht, Zeitablauf, Nacht über Mitternacht | IMPLEMENTED, BK-e1 für die Simulation abgenommen (20/20 auf `3ea17ee`); Staging-Bedienung UNKNOWN |
| Überschneidung über Mitternacht bei Handplanung (CGR-256) | PLANNED, erster Folgepunkt |
| Erste echte KI: Auftrag aus Freitext (BK-d) | PLANNED; wartet auf Ihren Anbieterentscheid |
| KI-Dokumentationsentwurf mit Unterschrift | PLANNED (BK-e2a, BK-e2b), zuerst Testersatz |
| Geprüfter Rechnungsentwurf | PLANNED (BK-f; `lca` offen) |
| KI-gestützte Planung | Zielbild; heute feste Regeln |
| Betreiber-, Einrichtungs-, Angehörigen-, Coach-Ansicht | Zielbild |
