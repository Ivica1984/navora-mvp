# Abgestimmte Übersicht für den Founder: Staging, BK-e1b, KI

**Besitzer:** Product Owner (`po`) · **Stand:** 2026-11-18 16:00 (Europe/Zurich) · **Anlass:** Founder-Nachricht vom 18.11. (FE-090) · **Status der Abstimmung:** PO-Teil fertig; der Engineering-Teil (`eng`) und der KI-Teil (`aia`) sind mit Issue angefragt und noch **nicht bestätigt**. Keine Zugangsdaten in diesem Dokument.

Kennzeichnung: IMPLEMENTED · PLANNED · OPEN · UNKNOWN.

| Frage | Antwort |
|---|---|
| **Was kann ich heute in der echten Staging-App durchklicken?** | **Gebaut und in CI getestet, auf Staging von keinem Agenten durchgeklickt (UNKNOWN):** Auftrag erfassen → passendes Team sieht das Angebot → Team übernimmt → Auftraggeber liest «Gedeckt». Der PO hat Staging nicht bedient (keine Zugangsdaten, Seitenabruf in diesem Lauf nicht möglich). Ob der synthetische Seed auf Staging die Teams und Personen der Tests enthält (z. B. «Testteam Basel», «Kollegin B.»), ist **UNKNOWN**. Darum gilt der Ablauf erst als «auf Staging verfügbar», wenn `eng` ihn dort mit App, Datenbank, Login und Bedienung zusammen geprüft hat (angefragt). Klickpfad unten. |
| **Welcher App- und Datenbankstand läuft dort?** | **App (Render `navora-staging`, gelesen 15:55):** live ist `e6ac4f2` (Deploy 14:38 UTC); `4923575` (nur Dokumente) wird gebaut. Letzte Code-Änderung darin: BK-c3 (Begründung je Team) und BK-e1a (Ortszeile). **Datenbank (`navora-staging`, Migrationsliste gelesen 15:50):** Migrationen bis **0137** (`bk_c3_offer_reasons`); **0136 und 0137, die früher fehlten, sind jetzt eingespielt** (`staging`-Job auf `e6ac4f2`, 14:47 UTC, `success`). Stand gleich `recovery/main` (135 Dateien). 0138–0148 kommen erst mit dem Merge von #1421. |
| **Was fehlt noch an #1421?** | Feste Restliste (keine neue Bedingung): (1) **der neue Handy-Test der Übernahmekarte ist rot** (`e2e` 134872594477 auf `2d67323`): `eng` korrigiert Bildschirm oder Test, die vereinbarte Erwartung bleibt; (2) `eng` nennt den Endstand; (3) Freigabezeile `cra` (klinisch) und `uxa` (Bildschirm) auf genau diesem Stand; (4) alle Prüfläufe grün. **Bereits erfüllt und getestet:** der Fehler «gedeckt, obwohl die Pflegekraft zeitgleich anders eingeplant ist» (CGR-233/CGR-255, Migration 0148, Wettlauf-Test mit seriellem Vergleich grün, von `cra` bestätigt); Nachtschicht 22:00–07:00 mit Summen über Mitternacht (pgTAP 148 §14, Unit-Test grün). Gate-Owner: `cra`, `uxa`; Merge: `po`. Pausierte Rollen werden für die Freigabe gezielt angefragt; pausiert heisst nicht genehmigt. |
| **Was kann ich nach #1421 zusätzlich bedienen?** | **Teilergebnis (PLANNED, nach Merge und Staging-Lauf):** Als Pflegekraft erscheint eine übernommene Schicht in «Mein Tag» (`/field`) als Karte «Übernommene Schicht», mit Ortszeile (in der Simulation ohne Strasse) und dem Zeitablauf (Losfahren, Ankunft, Ende) wie bei jedem Einsatz; eine Nachtschicht steht auf dem Starttag. Kein KI-Bericht, keine Rechnung: die kommen in BK-e2 und BK-f. |
| **Welche Funktion nutzt bereits echte KI?** | **Keine.** Im Code ist kein KI-Modell angeschlossen; die Datenbank lehnt einen KI-Akteur sogar in Simulationsorganisationen ab (AUT-115, D-35 Regel A). Empfehlungen und Gründe beim Teamangebot sind **feste Regeln**, keine KI. |
| **Wann kommt die erste echte KI-Demo?** | **Empfehlung PO (PLANNED, `aia` angefragt):** zuerst der **Berichtsentwurf aus der Eingabe der Pflegekraft** (BK-e2a), weil er im aktiven Block liegt, die grösste Schreibentlastung bringt und die menschliche Unterschrift (BK-e2b) schon geplant ist; das Modell entscheidet nie über Qualifikation, Zuteilung oder Abrechnung. Schritte: (1) BK-e2a mit Testersatz und fester Schnittstelle; (2) Anschluss eines echten Modells **nur in Simulationsorganisationen auf Staging**, mit synthetischen Daten, abschaltbar, jeder Entwurf als «KI-Entwurf, nicht unterschrieben» markiert; (3) `lca` prüft Anbieterbedingungen, `cra` die Entwurfsgrenzen, `aia` die Prüfungen. **Zeitfenster: UNKNOWN**; realistisch frühestens rund eine Woche nach dem Merge von #1421, und nur wenn Ihre beiden Entscheide unten vorliegen. Zweiter Kandidat: Auftragserfassung aus Freitext (BK-d). |
| **Was muss ich selbst entscheiden oder einstellen?** | (1) **Entscheid:** Dürfen synthetische Daten auf Staging an einen externen KI-Dienst gehen? (Heute schliesst die Datenbank das aus; echte Personendaten bleiben ausgeschlossen, D-41.) (2) **Entscheid und Einstellung:** Anbieter mit Rechenzentrum Schweiz/EU und ohne Datenspeicherung wählen (FE-085), einen API-Schlüssel nur für Staging erstellen und als Secret hinterlegen (`eng` gibt die Schritte; nie in GitHub-Kommentare). (3) Nur zur Kenntnis: das Docker-Hub-Token läuft nach 90 Tagen ab. Für den heutigen Klickpfad ist **nichts** von Ihnen nötig ausser den Demo-Zugangsdaten, die Sie haben. |

## Klickpfad (in CI getestet; auf Staging noch nicht von einem Agenten geprüft)

Quelle: Test `tests/e2e/bk-c2-take-status.spec.ts` (grün in CI auf `recovery/main`). Zugangsdaten: die Demo-Konten aus FE-086b, die Sie vertraulich erhalten haben.

1. **Auftraggeber** (`kundebs`): Seite **`/order`** öffnen. Datum mindestens einige Tage in der Zukunft, Beginn **07:00**, Ende **15:30**, Einsatzort **4051**, Stufe **HF**, Tätigkeit **Grundpflege**; «Weiter zur Zusammenfassung», dann «Bestätigen & Absenden». **Erwartet:** «Auftrag bestätigt»; in der Liste «Noch nicht gedeckt · Beginn …, 07:00» und «Angebot an alle passenden Teams gleichzeitig.»
2. Abmelden. **Pflegekraft mit HF** (`pflegebs`): Seite **`/team`** öffnen. **Erwartet:** Karte mit «Neues Angebot», «Alle passenden Teams sehen dieses Angebot.», «Empfohlen für euch: jemand von euch ist frei» (feste Regel, keine KI), «Ich (Pflegekraft)» vorgewählt. «Übernehmen mit Pflegekraft» tippen. **Erwartet:** «Übernommen», «Ihr habt diese Schicht übernommen. Es geht: Pflegekraft B.», kein Knopf mehr.
3. **Gegenprobe im selben Team** (`assistbs`): `/team` zeigt dieselbe Karte «Übernommen», ohne Knopf. Optional **anderes Team** (`pflege`): die Karte erscheint dort nicht.
4. **Auftraggeber** (`kundebs`): `/order`. **Erwartet:** «Gedeckt · Person benannt, geprüft für HF» und «Team Testteam Basel · übernommen um …».

Wenn ein Schritt anders aussieht: bitte nicht als Fehler Ihrerseits werten; es ist dann genau der Teil, den `eng` auf Staging noch prüfen muss.

## Zielbild und Stand der Plattform (Kurzfassung)

| Teil | Stand |
|---|---|
| Auftraggeberansicht: Auftrag erfassen, Deckungsstand | IMPLEMENTED (BK-a, BK-c; Simulation) |
| Teamabgleich nach Region, Stufe, Tätigkeit | IMPLEMENTED als feste Regeln (BK-b; Simulation) |
| Team-Dashboard: Angebot, Übernahme, Begründung | IMPLEMENTED (BK-c; Simulation) |
| Mobile Pflegeansicht: übernommene Schicht, Zeitablauf | PLANNED mit #1421 (BK-e1b) |
| KI-Dokumentationsentwurf mit Unterschrift | PLANNED (BK-e2a, BK-e2b); echte KI: OPEN (Ihre Entscheide) |
| Geprüfter Rechnungsentwurf | PLANNED (BK-f; `lca` offen) |
| KI-gestützte Planung | Zielbild; heute feste Regeln (PLAN3) |
| Betreiber-, Einrichtungs-, Angehörigenansicht | Zielbild |
