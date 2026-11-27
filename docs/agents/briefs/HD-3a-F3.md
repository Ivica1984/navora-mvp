---
id: HD-3a-F3
title: Monatssoll je Person und Planungsperiode (Founder-Option A), feste Regeln
author: po
status: approved   # PO 2026-11-27 15:39, FE-137 (2) «vertragsbereit, nicht aktiv»; Founder-Wahl Option A (FE-135); offene Punkte mit sicherem Standard, Founder kann ändern; Bau erst nach der HD-3a-F1-Abnahme
updated: 2026-11-27
---

# HD-3a-F3 — Monatssoll je Person und Planungsperiode

Block: **HEIM-DP**. Folgepunkt aus FE-133 (2); Reihenfolge HD-3s-F2-F1 → HD-3a-F1 → **HD-3a-F3** → HD-3b-0. **Vertragsbereit, nicht aktiv** (FE-137 (2)): `eng` baut erst, wenn HD-3a-F1 abgenommen ist und *Active now* HD-3a-F3 nennt. Ein Engineering-PR. Simulation, synthetische Daten. Der PO hat keinen Code gelesen und keine Tests ausgeführt.

## Founder-Entscheid (FE-135, [#1790 7203368699](https://github.com/Ivica1984/navora-mvp/pull/1790#issuecomment-7203368699), Option A)

NAVORA nutzt ein **ausdrückliches, einstellbares Monatssoll** (Stundenbudget), das das Heim **je Person und Planungsperiode** einträgt. Es wird nicht aus dem Wochensoll umgerechnet. Gründe des Founders: vertragliche Monatssolls können von einer Umrechnung abweichen; die Planung soll über den ganzen Monat fair verteilen, nicht ein gleiches Wochenmuster erzwingen; sechs Tage in Folge können gültig sein, wenn alle harten Regeln erfüllt sind und die Person im Monatssoll, in Verfügbarkeit, Schichtmodell, Abwesenheit und Ruhezeit bleibt. «This does not release HD-3b-0 yet.»

## Founder-Anforderungen (bindend)

1. Monatssoll, geplante Stunden und Reststunden sichtbar.
2. Sichtbare Warnung, wenn das eingetragene Monatssoll deutlich vom Pensum oder Wochensoll abweicht; nie still überschreiben.
3. Das Monatssoll ist eine Planungsbedingung; es übersteuert nie Qualifikation, Abwesenheit, Ruhezeit, Doppelbuchung oder eine andere harte Sicherheitsregel.

## Bisher offene Punkte: sicherer Standard des PO (FE-137 (1); Founder kann jeden ändern, ohne Antwort gilt der Standard)

| Punkt | Standard für die Simulation | Grund |
|---|---|---|
| Schwelle «deutlich abweicht» | **Keine Zahl vom PO.** Ein Heim-Parameter «Abweichungsschwelle (Stunden)», leer voreingestellt; solange leer, erscheint die Warnung bei **jeder** Abweichung vom Vergleichswert. Der Founder setzt einen Startwert, wenn er will. | kein erfundener Wert; sichtbar statt still (Anforderung 2) |
| Vergleichswert | Wochenstundenbudget heute (Pensum × Wochensoll, FE-123 (1)) × Kalendertage der Periode ÷ 7; nur für die Warnung, nie zum Überschreiben | reine Arithmetik, keine Regel; Founder: nicht umrechnen, nur vergleichen |
| Verhältnis zum Wochenbudget | Ist ein Monatssoll für Person und Periode eingetragen, **ersetzt es** für sie in dieser Periode die Wochenstunden-Grenze R-h als Planungsbedingung (Verteilung über den Monat). Ohne Monatssoll gilt R-h unverändert. Eine konfigurierte Wochen-Höchstarbeitszeit des Heims (Founder-Parameter, ArG-Marke) bleibt hart. | Founder-Grund «fair über den Monat»; harte Grenzen unverändert (Anforderung 3) |
| Planungsperiode | Kalendermonat. Eigene Perioden des Heims: Folgepunkt, nicht in diesem Paket. | einfachster eindeutiger Stand |
| Weder Monatssoll noch Pensum | fail closed wie HD-3a-F1 (Zeile bzw. Aufruf abgelehnt, sichtbarer Grund) | gleiche Logik, kein stiller Plan |

## Acceptance criteria

- [ ] Heimleitung trägt je Person und Kalendermonat ein Monatssoll ein, ändert und löscht es (Audit wie bestehende Planungseingaben, Prüfung unter Zeilensperre wie HD-3a-F1 R-6-2 (b)).
- [ ] `/heim` Monat und Plan je Person zeigen Monatssoll, geplante Stunden (nur gearbeitete Minuten, geteilter Dienst ohne Pause, FE-127 (3)) und Reststunden; Werte aus der Datenbank (T-1).
- [ ] Warnung sichtbar bei Abweichung vom Vergleichswert gemäss Standardtabelle; nie ein still geänderter Wert; Negativ: ohne Abweichung keine Warnung.
- [ ] Planer und «übernehmen» halten das Monatssoll als Bedingung ein; pgTAP: Überschreitung → Lücke mit Grund bzw. Ablehnung; Ruhezeit 11 h, ≤ 6 Tage in Folge, Schichtmodell, Abwesenheit, Doppelbuchung, Qualifikation unverändert hart (Regressionstests).
- [ ] pgTAP: ohne Monatssoll gilt R-h unverändert; weder Monatssoll noch Pensum → Ablehnung (fail closed).
- [ ] e2e 390 und 1440 px: positiv Monatssoll eintragen → Monatsvorschlag → Reststunden stimmen; negativ (T-2) ein falscher Wert (z. B. negative Stunden) wird mit sichtbarem Text abgelehnt.
- [ ] `staging-smoke`: Pfade 1–9 grün; neuer Staging-Schritt nur nach der Regel FE-137 (1) (sonst bekannte Grenze mit Folgepunkt).
- [ ] Migration als ganze Datei, Funktionen aus den kanonischen Quelldateien (STAB1); `ci` grün auf dem Kopf; nach dem Merge `staging`-Job, dann `ci-repeat` 10/10 (`db`, `e2e`).

## Rules and their input class

Monatssoll, Pensum, Wochensoll, Abweichungsschwelle: *Heim-Konfiguration* (synthetisch). Kennzeichnung «Arbeitszeitgesetz nicht abschliessend geprüft» bleibt. Kein klinischer Wert.

## AI leverage

Keine KI: feste Regel und Arithmetik. Entfernte Arbeit: Monatsstunden von Hand nachrechnen.

## Integration (FE-136)

1. Sichten: `/heim` Monat, Plan je Person, Stammdaten; `/team`, `/field` unverändert. 2. Datensätze: neues Monatssoll je Person und Periode (Form: `eng`); liest Plan und Stammdaten. 3. Nachgelagert: Lücken und externer Auftrag unverändert. 4. Benachrichtigung: keine. 5. Schutz: Datenbankprüfung, Zeilensperre, Audit. 6. Staging-Pfad: siehe Kriterium.

## Gates

`cra` (Bedingung übersteuert keine harte Regel), `uxa` (Anzeige und Warnung 390/1440 px), `lca` (Vertragsstunden, Arbeitszeit; Marke bleibt). Ein Gate-Fenster nach `Paket prüfbereit:` (FE-089 (2), FE-097).

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste.

## Out of scope

Eigene Planungsperioden des Heims; HD-3b-0 (nicht freigegeben); Lohn- und Zeitabrechnung.

## Vision check (FE-070 (7), kurz)

Faire Verteilung über den Monat, weniger Rechenarbeit der Heimleitung, keine stille Änderung, keine Disposition, kein Geldfluss, keine KI.
