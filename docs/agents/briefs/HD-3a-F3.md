---
id: HD-3a-F3
title: Monatssoll je Person und Planungsperiode (Founder-Option A), feste Regeln
author: po
status: accepted   # PO 2026-11-28 08:39 für die Simulation auf `8fa8f90a` (ABNAHMEAKTE §2); vorher approved: PO 2026-11-27 15:39, FE-137 (2) «vertragsbereit, nicht aktiv»; Founder-Wahl Option A (FE-135); offene Punkte mit sicherem Standard, Founder kann ändern; Bau erst nach der HD-3a-F1-Abnahme; **aktiv seit 2026-11-28 04:39** (HD-3a-F1 abgenommen)
updated: 2026-11-28
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

## PO acceptance (2026-11-28 08:39, geplanter PO-Lauf, Signal FE-105 (1) (d))

**Status: accepted** für die Simulation auf `8fa8f90a` (enthält den Merge `bf64e753`; Gate «Simulation, synthetische Daten»; `ABNAHMEAKTE.md` §2). Der PO hat die Tests nicht lokal ausgeführt; alle Werte aus Rohdaten der Jobs über die GitHub-API und aus den `eng`-Berichten 7234765791, 7235781058, 7236003138.

| Kriterium | Ergebnis | Nachweis |
|---|---|---|
| Leitung trägt Monatssoll ein, ändert, löscht; Audit; Prüfung unter Zeilensperre | erfüllt | pgTAP 187 (Schreiben/Ändern/Löschen mit Audit, veralteter gezeigter Wert → nichts geschrieben; Planung, Viewer, Nichtmitglied, anderes Heim, anon abgewiesen); Nebenläufigkeit K im `db`-Job; `staging-smoke` Pfad 11 |
| `/heim` zeigt Soll · geplant · Rest aus der Datenbank (T-1) | erfüllt | e2e `hd3a-f3-month-target.spec.ts` (Werte gleich der Datenbank); `staging-smoke` Job 140895353097 Pfad 11 «11 passed» auf Render `8fa8f90a` |
| Warnung bei Abweichung; kein still geänderter Wert; negativ ohne Abweichung keine Warnung | erfüllt | pgTAP 187 (`month_targets` mit Vergleich und Abweichung inkl. Negativfall; Schwelle); e2e positiv «Warnung sichtbar» |
| Planer und «übernehmen» halten das Monatssoll ein; harte Regeln unverändert | erfüllt | pgTAP 187 (R-m auf der Minutengrenze; Ruhezeit, Tage in Folge, Schichtmodell, Abwesenheit, Doppelbelegung mit Soll wirksam); Unit 18 Tests; Regression pgTAP 171–186 in `db` ×10 «Files=184, Tests=7637», «Result: PASS» |
| Ohne Monatssoll R-h unverändert; weder Monatssoll noch Pensum → Ablehnung | erfüllt | pgTAP 187 («R-h ohne Soll unverändert»; «weder Monatssoll noch Pensum» → `pensum_missing`) |
| e2e 390/1440 px positiv; negativ T-2 «-5» mit sichtbarem Text abgelehnt | erfüllt | `hd3a-f3-month-target.spec.ts`; `e2e` ×10 «240 passed», keine skipped/failed/flaky-Zeile |
| `staging-smoke` Pfade 1–9 grün; neuer Schritt nach FE-137 (1) | erfüllt | Job 140895353097 «11 passed» (1–9 und 11), erster Lauf; Pfad 10 = STG-P10 bekannte Grenze |
| Migration ganz, Funktionen aus kanonischen Dateien; `ci` grün; `staging`; `ci-repeat` 10/10 | erfüllt | `ci` 46117761443 auf `bf64e753` und 46117809922 auf `8fa8f90a` 5/5 `success`; `staging`-Job 140897689807 «Applying migration 20261021000189…»; `staging-version` 140895477224 «up to 20261021000189», «app and database match»; `ci-repeat` 46120023950 22/22, Fenster 08:11–08:25 |
| Gates `cra`, `lca`, `uxa` | clear | 7234839832, 7234853155, 7234867278 auf `5740d09b` |

Bekannte Grenzen (keine Bedingung): W1 kein Wochenmaximum (HD-3a-F3-F1 = F-2 vor realen Personaldaten); Ablehnungsfälle kein Staging-Pfad; Render-Deploy-ID UNKNOWN. Folgepunkte: HD-3a-F3-F2, UXR-309 bis UXR-314, AUT-246, AUT-247 (UXR-309, UXR-310, AUT-247 fahren mit HD-PEN-HAND).
