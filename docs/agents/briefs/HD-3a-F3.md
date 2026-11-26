---
id: HD-3a-F3
title: Monatssoll je Person und Planungsperiode (Founder-Option A), feste Regeln
author: po
status: draft   # Founder-Wahl Option A eingetragen 2026-11-26 22:39 (FE-135); Vertrag wird nach HD-3a-F1 freigegeben (Folge FE-133)
updated: 2026-11-26
---

# HD-3a-F3 — Monatssoll je Person und Planungsperiode

Block: **HEIM-DP**. Folgepunkt aus FE-133 (2); Reihenfolge HD-3s-F2 → HD-3a-F1 → **HD-3a-F3** → HD-3b-0. Dieser Entwurf hält die Founder-Wahl fest; die vollständigen Kriterien schreibt der PO bei der Freigabe. Simulation, synthetische Daten.

## Founder-Entscheid (FE-135, [#1790 7203368699](https://github.com/Ivica1984/navora-mvp/pull/1790#issuecomment-7203368699), Option A)

NAVORA nutzt ein **ausdrückliches, einstellbares Monatssoll** (Stundenbudget), das das Heim **je Person und Planungsperiode** einträgt. Es wird nicht aus dem Wochensoll umgerechnet. Gründe des Founders: vertragliche Monatssolls können von einer Umrechnung abweichen; die Planung soll über den ganzen Monat fair verteilen, nicht ein gleiches Wochenmuster erzwingen; sechs Tage in Folge können gültig sein, wenn alle harten Regeln erfüllt sind und die Person im Monatssoll, in Verfügbarkeit, Schichtmodell, Abwesenheit und Ruhezeit bleibt.

## Founder-Anforderungen (bindend für den Vertrag)

1. Monatssoll, geplante Stunden und Reststunden sichtbar.
2. Sichtbare Warnung, wenn das eingetragene Monatssoll deutlich vom Pensum oder Wochensoll abweicht; nie still überschreiben.
3. Das Monatssoll ist eine Planungsbedingung; es übersteuert nie Qualifikation, Abwesenheit, Ruhezeit, Doppelbuchung oder eine andere harte Sicherheitsregel.

## Offen bis zur Freigabe (PO, mit `eng`; kein Wert erfunden)

- Was «deutlich abweicht» heisst (Schwelle): Founder-Parameter oder Heim-Parameter, Vorschlag durch `eng`, Wahl durch den Founder (FE-124-Auswahlfrage).
- Verhältnis zum heutigen Stundenbudget je ISO-Woche (FE-123 (1)): ersetzt oder zusätzlich; Planungsperiode = Kalendermonat oder Periode des Heims.
- Was gilt, wenn kein Monatssoll eingetragen ist (fail closed wie HD-3a-F1: Zeile oder ganzer Entwurf abgelehnt).
- Gates: `cra`, `uxa`, `lca` (Vertragsstunden, Arbeitszeit); Kennzeichnung «Arbeitszeitgesetz nicht abschliessend geprüft» bleibt.

## Not released

Dieser Brief ist `draft`. Er gibt HD-3b-0 nicht frei (Founder: «This does not release HD-3b-0 yet.»).
