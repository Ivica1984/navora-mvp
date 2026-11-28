---
id: HD-3s-F2-F1-F1
title: Tagesplan-Vorschlag sieht die Pause einer geteilten Übernahme als belegt, feste Regel
author: po
status: approved   # PO 2026-11-28 08:39, FE-137 (2) «vertragsbereit, nicht aktiv»; Bau erst nach der HD-PEN-HAND-Abnahme und wenn *Active now* es nennt
updated: 2026-11-28
---

# HD-3s-F2-F1-F1 — Tagesplan-Vorschlag und geteilte Übernahme

Block: **HEIM-DP**. Folgepunkt aus `cra` CGR-291 (S3, advisory; `CLINICAL_GOVERNANCE.md` Gate #1825), `aia` AUT-235, `uxa` UXR-302. Reihenfolge HD-PEN-HAND → **HD-3s-F2-F1-F1** → HD-3b-0. **Vertragsbereit, nicht aktiv.** Ein Engineering-PR. Simulation, synthetische Daten. Der PO hat keinen Code gelesen; Codefakten aus CGR-291 und dem `eng`-Journal 2026-11-27 14:12 (f).

## Problem

Seit HD-3s-F2-F1 lehnt der Handweg einen Einsatz in der Zeit einer laufenden geteilten Übernahme ab, Pause eingeschlossen. Der **Tagesplan-Vorschlag** (`private.plan3_lines`) baut die belegte Zeit einer Person aber weiter nur aus Einsätzen und kann sie für einen Einsatz in ihrer Pause vorschlagen (IMPLEMENTED laut CGR-291). Die Bestätigung schlägt fail closed fehl (`overlap` bzw. `member_take_window`), nichts Falsches wird gespeichert, aber der Einsatz bleibt ohne Person, bis die Teamleitung neu plant: Mehrarbeit und ein Vorschlag, der der Regel widerspricht.

## Users and journey step

Teamleitung und Team (`/team` Tagesplan), Schritt «Planning»; Pflegekraft mit geteilter Übernahme aus einem Heim-Auftrag.

## Outcome

Der Vorschlag nennt nie eine Person für eine Zeit, in der ihre geteilte Übernahme läuft (Pause eingeschlossen); was vorgeschlagen wird, lässt sich bestätigen.

## Acceptance criteria

- [ ] `private.plan3_lines` (ganz aus der kanonischen Datei) zählt jedes laufende Übernahmefenster der Person (Pause eingeschlossen) als belegt, über `private.member_take_window` (eine Quelle mit dem Handweg).
- [ ] pgTAP: laufende geteilte Übernahme 07:00–11:30 / 16:00–20:00 und ein offener Einsatz 12:00 → der Vorschlag nennt sie **nicht**; Einsatz 20:30 → darf sie nennen (Negativ- und Positivfall); andere Person ohne Übernahme unverändert.
- [ ] pgTAP: Bestätigung eines Vorschlags, der sie nicht nennt, gelingt; die fail-closed-Prüfung `plan3_confirm_overlaps` bleibt unverändert (Regression).
- [ ] UXR-302: der Hinweis vor dem Speichern verspricht keine Wahl, die die Regel nicht mehr lässt (Wortlaut `uxa`, `cra`).
- [ ] Unit/e2e 390 und 1440 px: Tagesplan-Vorschlag mit einer geteilten Übernahme zeigt die Person nicht in der Pause.
- [ ] ADR-230 «Known limits» nachgeführt.
- [ ] `staging-smoke`: bestehende Pfade grün; kein neuer Pfad (bekannte Grenze: Fall braucht eine laufende geteilte Übernahme im Seed; Folgepunkt STG-P10 deckt den Auftragsweg).
- [ ] `ci` grün auf dem Kopf; nach dem Merge `staging`-Job, dann `ci-repeat` 10/10 (`db`, `e2e`).

## Rules and their input class

Belegte Zeit aus einer bestehenden Übernahme: *visit/schedule fact*. Keine neue Regel; dieselbe Regel wie der Handweg.

## AI leverage

Keine KI (Grund: deterministische Belegungsprüfung). Entfernte Arbeit: erneutes Planen nach einer fehlgeschlagenen Bestätigung. Messgrösse: fehlgeschlagene Bestätigungen mit `member_take_window` → 0.

## Integration (FE-136)

1. Sichten: `/team` Tagesplan-Vorschlag; `/heim`, `/field` unverändert. 2. Datensätze: liest Übernahmen und Einsätze; schreibt nichts Neues. 3. Nachgelagert: unverändert. 4. Benachrichtigung: keine. 5. Schutz: `member_take_window`, `plan3_confirm_overlaps`. 6. Staging-Pfad: bekannte Grenze (siehe Kriterium).

## Gates

`cra` (CGR-291 geschlossen), `uxa` (UXR-302). Ein Gate-Fenster nach `Paket prüfbereit:`.

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste.

## Out of scope

CGR-290 (HD-3s-F2-F2, Block 2 allein); Ruhezeit auf dem Auftragsweg (`lca`, Clinical Owner); Nachtfenster CGR-287.

## Vision check (FE-070 (7), kurz)

Vorschläge, denen das Team vertrauen kann; weniger Nacharbeit der Teamleitung; keine Disposition, kein Geldfluss, keine KI.
