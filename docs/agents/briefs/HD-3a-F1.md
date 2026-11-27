---
id: HD-3a-F1
title: «übernehmen» prüft Pensum und Wochensoll in der Datenbank (fail closed), Eingaben unter Zeilensperre
author: po
status: approved   # PO 2026-11-27 15:39, FE-137 (2) «vertragsbereit, nicht aktiv»; Inhalt aus Issue #1745 (FE-129) und Brief HD §5b; keine neue Regel des PO
updated: 2026-11-27
---

# HD-3a-F1 — Pensum und Wochensoll beim «übernehmen» in der Datenbank geprüft

Block: **HEIM-DP** (README-Regel 12). Benannter Folgepunkt von HD-3a (FE-129, Issue [#1745](https://github.com/Ivica1984/navora-mvp/issues/1745)); Pflicht vor der HD-3b-Abnahme und vor realen Daten. **Vertragsbereit, nicht aktiv** (FE-137 (2)): `eng` startet den Bau erst, wenn HD-3s-F2-F1 abgenommen ist und *Active now* HD-3a-F1 nennt. Ein Engineering-PR. Simulation, synthetische Daten. Der PO hat keinen Code gelesen und keine Tests ausgeführt; die Code-Aussagen stammen von `eng` (#1745, Kopf `bab9490`) und der Probe [#1794](https://github.com/Ivica1984/navora-mvp/pull/1794) (`363e50dd`, nicht mergen).

## Problem

Heute (IMPLEMENTED, bekannte Grenze FE-129): `public.institution_apply_draft` liest weder `institution_staff.pensum_pct` noch `institutions.weekly_target_hours`, und `private.institution_rule_breaches` überspringt R-h (Dienstminuten je ISO-Woche ≤ Pensum × Wochensoll), wenn einer der Werte leer ist. Wird Pensum oder Wochensoll zwischen «Plan vorschlagen» und «übernehmen» auf «nicht eingetragen» gesetzt, speichert «übernehmen» die Zeilen ohne Wochenstunden-Prüfung. Ruhezeit, Tage in Folge, Schichtmodell, Abwesenheit und Doppelbuchung prüft die Datenbank weiter je Zeile. Zudem prüfen die Formulare der Planungseingaben (R-6-2 (a)) nur mit frischem Lesen vor dem Schreiben; ein kleines Zeitfenster bleibt.

## Users and journey step

Heim- oder Stationsleitung (B2B-Modul 1, GM-2, `/heim`). Planning.

## Outcome

Ein Planvorschlag wird nur mit den Werten übernommen, auf denen er gerechnet wurde; fehlt Pensum oder Wochensoll, lehnt die Datenbank ab und der Bildschirm sagt, was fehlt. Kein Plan entsteht still ohne Stundenprüfung.

## Scope (aus #1745, vier Punkte)

1. **R-6-1:** «übernehmen» lehnt eine Zeile ab, deren Person kein Pensum hat, und den ganzen Aufruf, solange das Wochensoll des Heims leer ist (fail closed, wie der Planer).
2. **R-7-1:** Migration für (1): `institution_apply_draft` als ganze Datei aus der kanonischen Quelle `supabase/schema/functions/public.institution_apply_draft.sql` neu erstellt (STAB1, TESTS 6, kein Textflicken); alle Wächter bleiben (security definer, `search_path ''`, LEAVE1-3, Mitgliedschaft, Personen- und Zellsperren, Audit, Grants).
3. **R-7-2:** Bildschirmtexte auf `/heim` für die neuen Ablehnungscodes (eine Zeile, die die Person bzw. das fehlende Wochensoll nennt und die nächste Handlung: Pensum bzw. Wochensoll eintragen).
4. **R-6-2 (b):** Die Formulare der Planungseingaben prüfen die gezeigten Werte unter einer Zeilensperre in der Datenbank (ersetzt das frische Lesen aus R-6-2 (a)).

## Acceptance criteria

- [ ] pgTAP: Person ohne Pensum im Entwurf → «übernehmen» lehnt genau diese Zeile mit benanntem Code ab; die anderen Zeilen folgen der heutigen Zeilenlogik von `institution_apply_draft` (`eng` nennt im Bereitbericht, ob Zeile oder ganzer Aufruf; beides fail closed).
- [ ] pgTAP: Wochensoll des Heims leer → der ganze Aufruf wird abgelehnt, nichts gespeichert, Audit wie bei bestehenden Ablehnungen.
- [ ] pgTAP: Pensum bzw. Wochensoll zwischen Vorschlag und «übernehmen» auf leer gesetzt → Ablehnung (der Fall der Probe #1794 ist rot vor und grün nach der Änderung).
- [ ] pgTAP: je ein Test pro behaltenem Wächter (security definer, `search_path ''`, Mitgliedschaft, fremdes Heim abgelehnt, Sperren, Grants) und Katalogwächter 157 für jede geänderte Funktion.
- [ ] pgTAP R-6-2 (b): zwei Sitzungen, die gleichzeitig denselben Planungswert ändern, ergeben das Ergebnis einer seriellen Reihenfolge; kein gezeigter Wert wird still überschrieben.
- [ ] Regression: Entwurf mit vollständigen Werten wird unverändert übernommen; Ruhezeit 11 h, Tage in Folge, Schichtmodell, Abwesenheit, Doppelbuchung und geteilter Dienst (HD-3s) unverändert.
- [ ] e2e 390 und 1440 px: (positiv) Vorschlag → «übernehmen» → Woche zeigt den Plan aus `institution_plan`; (negativ, T-2) Pensum einer Person vor «übernehmen» leeren → sichtbarer Grund mit Name und nächster Handlung, nichts gespeichert; T-1 «gesendet = gezeigt».
- [ ] `staging-smoke`: Pfade 1–9 grün (Pfad 7 enthält «übernehmen»), kein Timeout verlängert, kein Test übersprungen.
- [ ] `ci` grün auf dem Kopf; nach dem Merge `staging`-Job-Log, dann `ci-repeat` 10/10 (`db`, `e2e`) im Abnahmefenster.

## Rules and their input class

Pensum, Wochensoll: *Heim-Konfiguration* (synthetisch). Wochenstunden-Grenze R-h: bestehende Regel aus HD-3a (FE-117, FE-123), unverändert. Kein klinischer Wert, keine neue Regel. Kennzeichnung «Arbeitszeitgesetz nicht abschliessend geprüft» bleibt.

## AI leverage

Keine KI: feste, prüfbare Regel. Entfernte Arbeit: Nachkontrolle eines still übernommenen Plans ohne Stundenprüfung.

## Integration (FE-136)

1. Sichten: `/heim` Woche und Monat (Ablehnungstext); `/team`, `/field`, `/order` unverändert. 2. Datensätze: liest `institution_staff`, `institutions`, Entwurf; schreibt `institution_plan` nur wie heute. 3. Nachgelagert: Lücken bleiben sichtbar; externer Auftrag (HD-2, HD-3s-F2) unverändert. 4. Benachrichtigung: keine neue. 5. Schutz: Datenbankprüfung in der Funktion, nicht nur im Bildschirm. 6. Staging-Pfad: Pfad 7 grün; ein negativer Staging-Schritt nur, wenn er ohne neue Zugangsdaten und nur mit Daten des Testheims geht; sonst bekannte Grenze im Bereitbericht mit Folgepunkt (Regel FE-137 (1), wie HD-3s-F2-F1 Pfad 10).

## Gates

`cra` (Unterbesetzung bleibt sichtbar; keine Zeile ohne Prüfung), `uxa` (Ablehnungstexte 390/1440 px). `lca` nicht für die Simulation (FE-109 (A)); vor realen Daten Pflicht (Vertragsstunden). Ein Gate-Fenster nach `Paket prüfbereit:` auf stabilem Kopf mit grüner CI (FE-089 (2), FE-097).

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste.

## Out of scope

Monatssoll (HD-3a-F3); neuer Löser (HD-3b-0); CGR-290 (HD-3s-F2-F2); Lesart des Arbeitsgesetzes (`lca`, vor realen Daten).

## Vision check (FE-070 (7), kurz)

Patientensicherheit: keine stille Planänderung ohne Prüfung (FE-136 (2)). Weniger Nacharbeit der Heimleitung. Keine Disposition, keine neue Hierarchie, kein Geldfluss, keine KI.
