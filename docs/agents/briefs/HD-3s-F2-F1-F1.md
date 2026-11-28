---
id: HD-3s-F2-F1-F1
title: Tagesplan-Vorschlag sieht die Pause einer geteilten Übernahme als belegt, feste Regel
author: po
status: approved   # PO 2026-11-28 08:39, FE-137 (2); aktiv seit 2026-11-28 12:39; **für die Simulation abgenommen 2026-11-28 16:39 auf `9d5d90fa`**
updated: 2026-11-28
---

# HD-3s-F2-F1-F1 — Tagesplan-Vorschlag und geteilte Übernahme

Block: **HEIM-DP**. Folgepunkt aus `cra` CGR-291 (S3, advisory; `CLINICAL_GOVERNANCE.md` Gate #1825), `aia` AUT-235, `uxa` UXR-302. Reihenfolge HD-PEN-HAND → **HD-3s-F2-F1-F1** → HD-3b-0. **Aktiv seit 2026-11-28 12:39** (zuvor vertragsbereit, nicht aktiv). Ein Engineering-PR. Simulation, synthetische Daten. Der PO hat keinen Code gelesen; Codefakten aus CGR-291 und dem `eng`-Journal 2026-11-27 14:12 (f).

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

## PO acceptance (2026-11-28 16:39, geplanter PO-Lauf, Signal FE-105 (1) (d))

Gate «Simulation, synthetische Daten», benannter Commit `9d5d90fa` (Merge-Commit von #1872). Der PO hat keine Tests lokal ausgeführt; alle Zeilen aus Rohdaten der Jobs gelesen.

| Kriterium | Ergebnis | Nachweis |
|---|---|---|
| `private.plan3_lines` zählt jedes laufende Übernahmefenster (Pause eingeschlossen) als belegt, über `private.member_take_window` | erfüllt | Migration 0191 (kanonische Datei, revoke, kein grant); `cra-gate` 7240165987 clear |
| pgTAP Negativ-/Positivfall (12:00 nicht, 20:30 darf), andere Person unverändert | erfüllt | `189_hd3s_f2_f1_f1_plan3_take_window.test.sql … ok` in `db` ×10 |
| Bestätigung gelingt; `plan3_confirm_overlaps` unverändert (Regression) | erfüllt | pgTAP 189 und 157 (Katalogwächter) ok ×10, «Result: PASS» |
| UXR-302 Hinweis verspricht keine Wahl, die die Regel nicht lässt | erfüllt | Migration 0192 `public.member_slot_take_window`; Unit `hd3s-f2-f1-f1-take-window-note.test.ts` im grünen `app`-Job; `uxa-gate` 7240137670 clear |
| Unit/e2e 390 und 1440 px | erfüllt | `e2e` ×10 «244 passed», `hd3s-f2-f1-f1-day-plan-take.spec.ts` beide Breiten grün, keine skipped/failed/flaky-Zeile |
| ADR-230 «Known limits» nachgeführt | erfüllt | `docs/engineering/DECISIONS.md` im Diff von #1872 (vom PO gelesen) |
| `staging-smoke` bestehende Pfade grün, kein neuer Pfad | erfüllt (mit Grenze) | Job 141018131085 «11 passed», «FAILED_PATHS: 0»; neuer Ablauf nicht auf Staging (STG-PH-1) |
| `ci` grün; `staging`; `ci-repeat` 10/10 | erfüllt | `ci` 46155936398 5/5; `staging` 141015694223 «Applying migration …0191…», «…0192…»; `staging-version` 141019608502 «up to 20261021000192», «0 commit(s) behind»; `ci-repeat` 46158746414 22/22 im Fenster 16:13–16:29 |

Bekannte Grenzen (keine Bedingung): STG-PH-1; Render-Deploy-ID UNKNOWN. Folgepunkte: HD-3s-F2-F1-F2 (AUT-248 / Probe #1868 §4, CGR-292, UXR-319, UXR-320).
