---
id: HD-PEN-HAND-F1
title: «Stunden nicht prüfbar» sagt Bereich, Ursache und Folge (Zählzeile, Link, Warnbox), keine neue Regel
author: po
status: approved   # PO 2026-11-28 12:39, FE-137 (2) «vertragsbereit, nicht aktiv»; Bau erst nach der HD-3s-F2-F1-F1-Abnahme und wenn *Active now* es nennt
updated: 2026-11-28
---

# HD-PEN-HAND-F1 — Bereich, Ursache und Folge von «Stunden nicht prüfbar»

Block: **HEIM-DP**. Bündelt die benannten Folgepunkte der HD-PEN-HAND-Abnahme (`ABNAHMEAKTE.md` §2, 2026-11-28 12:39): HD-PEN-HAND-F1 = UXR-315, -F2 = UXR-316, -F3 = UXR-317, -F4 = UXR-318 (`uxa` Gate 7237600865, `docs/agents/reports/UX_REVIEW.md` 2026-11-28 10:58). Reihenfolge: HD-3s-F2-F1-F1 (aktiv) → **HD-PEN-HAND-F1** (vertragsbereit) → HD-3b-0 (Founder-Freigabe offen, FE-135). Ein Engineering-PR. Simulation, synthetische Daten. Der PO hat keinen Code gelesen; Codefakten aus UXR-315 bis UXR-318 und dem `eng`-Bereitbericht 7237198017.

## Problem

HD-PEN-HAND (abgenommen) speichert keinen Dienst mehr still ohne Stundenprüfung. Vier Stellen sagen aber nicht genug (IMPLEMENTED laut `uxa`):
1. Die Zählzeile «n Dienste ohne Stundenprüfung» zählt nur die gezeigte Woche oder den gezeigten Monat, liest sich aber wie ein Heimtotal (UXR-315, medium).
2. Der Link führt immer zum Pensum-Feld der ersten Person, auch wenn das fehlende Wochensoll des Heims die Ursache ist (UXR-316).
3. Regelzeile und Grund sagen dieselbe Lücke zweimal; die Marke hat einen Doppelpunkt zu viel (UXR-317).
4. Die Warnbox sagt nicht, dass der Dienst noch nicht eingeteilt ist; ein Link lässt die offene Einteilung fallen (UXR-318).

Folge: die Leitung kann einen Bestand übersehen, am falschen Ort nachtragen oder glauben, ein Dienst sei eingeteilt.

## Users and journey step

Heimleitung, Planung, Betrachter auf `/heim` (Woche, Monat, Warnbox), Schritt «Planning».

## Outcome

Die Zählzeile nennt ihren Bereich; jeder Link führt zur Ursache, die die Rolle beheben kann; die Warnbox sagt «Noch nicht eingeteilt.»; die Lücke steht einmal.

## Acceptance criteria

- [ ] **UXR-315:** die Zählzeile nennt den Bereich («… in dieser Woche» bzw. «… im <Monat Jahr>»); Unit auf dem Text für Woche und Monat; ohne betroffene Dienste keine Zeile (Unit, und e2e `toHaveCount(0)` nur wenn die gemeinsame e2e-Datenbank es zulässt, sonst Unit wie bisher).
- [ ] **UXR-316:** das Linkziel kommt aus derselben Ursache wie die Warnung (`hoursUnknownNext`): fehlt das Wochensoll, erhält die Leitung «Wochensoll eintragen» → Einstellungen, die Planung den Satz, wer es einträgt; fehlt Pensum/Monatssoll, der Link zur Person mit dem Hinweis, dass sie die erste von n ist. Unit je Fall; e2e ein Fall bei 390 px.
- [ ] **UXR-317:** die Lücke steht einmal (Regel als Etikett, Grund mit dem Fall); keine Marke mit zwei Doppelpunkten. Wortlaut von `cra` bestätigt; Unit auf Regeltext und Marke.
- [ ] **UXR-318:** erste Zeile der Warnbox «Noch nicht eingeteilt.»; ein Link verliert die offene Einteilung nicht still (entweder Rückweg mit Person und Dienst oder ausdrücklicher Satz, dass danach neu eingeteilt wird; Entscheid `eng` mit `uxa`); der Satz zu Ruhezeit und Arbeitstagen erscheint nur, wenn diese Regel betroffen ist. e2e 390 und 1440 px.
- [ ] **Unverändert (Regression):** Regelquelle `private.institution_rule_breaches`, Handweg (Warnung, nichts gespeichert, Bestätigung mit Audit), «übernehmen»; pgTAP 157, 188 grün; keine Migration erwartet. Falls doch eine nötig ist: im Bereitbericht begründen, Funktion ganz aus der kanonischen Datei.
- [ ] `staging-smoke` Pfade 1–9 und 11 grün; Pfad 12 bleibt bekannte Grenze STG-PH-1 (kein Staging-Pfad für diesen Text, gleicher Grund wie HD-PEN-HAND).
- [ ] `ci` grün auf dem Kopf; nach dem Merge `staging`-Job, dann `ci-repeat` 10/10 (`db`, `e2e`).

## Rules and their input class

Keine neue Regel. Nur Darstellung und Navigation der bestehenden Vollständigkeitsprüfung (*schedule fact*, synthetisch). Kein klinischer Wert, keine Schwelle. Kennzeichnung «Arbeitszeitgesetz nicht abschliessend geprüft» bleibt.

## AI leverage

1. Entfernen: die Suche nach der Ursache und die doppelte Einteilung nach einem Link. 2. Regel: unverändert fest. 3. Überwachen: die Zählzeile sagt, was sie zählt. 4. KI: **keine** (reiner Text und Link). 5.–7. Die Leitung entscheidet und trägt nach. Messgrösse: Schritte von der Warnung bis zum eingetragenen fehlenden Wert ≤ 2 (e2e-Klickzahl), «Trotzdem einteilen» je Heim und Monat sinkt (Hypothese HEIM-ONB, nicht Bedingung).

## Integration (FE-136)

1. Sichten: `/heim` Woche, Monat, Warnbox, Einstellungen-Anker; `/team`, `/field` unverändert. 2. Datensätze: keine neuen; liest dieselben Felder. 3. Nachgelagert: unverändert. 4. Benachrichtigung: keine (ehrliche Grenze). 5. Schutz: unverändert (`assert_access_open`, Sperren wie HD-PEN-HAND). 6. Staging-Pfad: STG-PH-1 (bekannte Grenze, vorab genannt nach FE-137 (a)).

## Gates

`uxa` (alle vier Punkte, 390/1440 px), `cra` (Wortlaut UXR-315, UXR-317). `lca` nicht für die Simulation. Ein Gate-Fenster nach `Paket prüfbereit:` (FE-089 (2), FE-097).

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste.

## Out of scope

Heimweite Zählung über alle Wochen (neuer Lesepfad, eigener Folgepunkt); Vollständigkeits-Arbeitsliste HEIM-ONB (Hypothese der Läufe 11:39/12:39); Sammelbestätigung (AUT-243); Sperre statt Warnung (vor realen Daten `lca`/Owner); UXR-290; HD-3a-F3-F1.

## Constraints and references

HD-PEN-HAND (`briefs/HD-PEN-HAND.md`, `ABNAHMEAKTE.md` §2); UXR-315 bis UXR-318; `cra` Gate 7237426357 (Nit Doppelpunkt); `eng`-Zweitlesung 7237079370 (Negativfall e2e); FE-089 (3), FE-136, FE-137 (2).

## Open questions for engineering

1. UXR-318: Rückweg mit offener Einteilung (Parameter im Link) oder ausdrücklicher Satz? Vorschlag im Bereitbericht mit `uxa`-Frage.
2. Reicht der bestehende Lesepfad, um die Ursache der ersten betroffenen Zeile zu bestimmen, ohne neue Abfrage?

## Vision check (FE-070 (7), kurz)

Weniger Suchen, keine falsche Entwarnung, keine stille Annahme «eingeteilt». Die Leitung behebt die Ursache selbst; keine Disposition, keine Hierarchie, kein Geldfluss, keine KI.
