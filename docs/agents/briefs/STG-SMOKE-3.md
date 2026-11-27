---
id: STG-SMOKE-3
title: Staging-Klickpfade — ein Wiederholungslauf nur bei Deploy-Wechsel (Testwächter)
author: po
status: approved   # PO 2026-11-27 06:39 nach der HD-3s-F2-Abnahme; aus dem technischen Vertrag von `eng` (#1790 7210446002), Option (b)
updated: 2026-11-27
---

# STG-SMOKE-3 — Ein Wiederholungslauf nur bei Deploy-Wechsel

Block: **HEIM-DP** (README-Regel 12), reines Test- und CI-Paket wie AUT-220; keine App-, Daten- oder Datenbankänderung. Ein Engineering-PR (`fix/stg-smoke-3`). Grundlage: PO-Entscheid D 2026-11-27 05:39 (#1818), `eng`-Zählung 7208819340 und Vertrag 7210446002 (PROPOSED → hier übernommen). Der PO hat keinen Code gelesen und keine Tests ausgeführt.

## Problem

Jede Abnahme dieser Woche wartete auf einen roten `staging-smoke`-Lauf. Seit dem 26.11. waren alle 3 roten Läufe derselben Klasse: Render schaltete während des Laufs auf einen neueren Commit um (meist ein reiner Dokumentations-Merge). Ein Mensch musste neu starten und erklären. Das kostet Abnahmezeit und gewöhnt alle an «rot ist normal» — das gefährdet, dass ein echter Fehler übersehen wird.

## Users and journey step

PO (Abnahme), `eng` (Bereit- und Staging-Bericht), Founder (Staging-Bericht). Querschnitt: Nachweis «auf Staging ausgeführt» für jeden Schritt der Kette.

## Outcome

Ein roter Klickpfadlauf, in dem Render nachweislich den Commit gewechselt hat, wird einmal automatisch nur für die fehlgeschlagenen Tests wiederholt und so im Protokoll ausgewiesen. Ein roter Lauf ohne Wechsel bleibt rot.

## Acceptance criteria

- [ ] Workflow: Schritt «Click paths on navora-staging» mit `id` und `continue-on-error: true`; sein Ergebnis bleibt sichtbar. `SERVED_BEFORE` und `SERVED_AFTER` werden geschrieben.
- [ ] Genau ein Wiederholungsschritt (`--last-failed`), der nur läuft, wenn die Pfade rot sind **und** beide Werte nicht leer **und** verschieden sind.
- [ ] `scripts/staging-smoke-verdict.mjs` lässt den Job nur grün, wenn (i) der erste Lauf grün ist oder (ii) ein Wechsel belegt ist und die Wiederholung grün ist; bei (ii) eine `::warning`- und Zusammenfassungszeile «green after one rerun of N failed paths; deploy `<before>` → `<after>`; rerun against `<after>`».
- [ ] Unit `tests/unit/stg-smoke-3-verdict.test.ts`, volle Entscheidungsmatrix: grün; rot ohne Wechsel → rot; rot mit Wechsel und grüner Wiederholung → grün mit Warnung; rot mit Wechsel und roter Wiederholung → rot; leerer Vorher- oder Nachher-Wert → rot; Wiederholung ohne Wechsel versucht → rot.
- [ ] Katalogprüfung (Muster `stg-smoke-1.test.ts`): `retries: 0` bleibt in der Konfiguration; der Wiederholungsschritt ist an die Wechselbedingung gebunden; genau ein Wiederholungsschritt.
- [ ] Negativ: kein Klickpfad, kein Wächter, kein Timeout geändert (TESTS 5); keine zweite Wiederholung; der Job «report a red staging smoke» feuert weiter bei jedem roten Urteil.
- [ ] Nachweis auf CI: ein `workflow_dispatch`-Lauf auf dem Zweig (grüner Pfad); `ci` grün auf dem Kopf. Der Wiederholungspfad ist nur durch die Unit-Matrix belegt — so im Bereitbericht benennen.

## Evidence rule (gilt ab dem Merge)

Ein Lauf, der erst nach der Wiederholung grün ist, zählt in `ABNAHMEAKTE.md` und im Founder-Bericht als «auf Staging ausgeführt» für `<after>` und wird **immer mit seiner Wiederholungszeile** zitiert, nie als einfaches Grün.

## Rules and their input class

Keine Pflege- oder Fachregel. Eine CI-Regel über Deploy-Fakten (servierter Commit vorher/nachher). Keine Eingabeklasse nach D-34 berührt.

## AI leverage

Keine KI: eine feste Entscheidungstabelle ist hier sicherer und prüfbar. Entfernte Arbeit: manuelles Neustarten und Erklären roter Läufe (Basis: 3 von 3 roten Läufen seit 26.11. Deploy-Wechsel, `eng` 7208819340).

## Integration (FE-136)

1. Sichten: unverändert. 2. Datensätze: keine. 3. Nachgelagert: Abnahme- und Staging-Berichte lesen die neue Warnzeile. 4. Benachrichtigung: bestehender Rot-Bericht-Job unverändert. 5. Schutz: Entscheidungsskript plus Katalogprüfung. 6. Staging-Pfad: alle bestehenden Pfade 1–9 laufen unverändert.

## Gates

Kein Gate einer pausierten Rolle nötig (kein klinischer, rechtlicher oder UX-Inhalt). PO prüft gegen diese Liste.

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste.

## Out of scope

`retries` in der Playwright-Konfiguration; Wiederholung bei stabilem Deploy; zweite Wiederholung; Render-Einstellungen (Founder-Option (a), Build-Filter `docs/**`, `*.md`, bleibt empfohlen und unabhängig).

## Known risks (von `eng` genannt)

Ein halb gelaufener Pfad kann Daten hinterlassen, die die Wiederholung rot machen — das bleibt ein ehrliches Rot. Ein Wechsel während der Wiederholung wird nicht nochmals wiederholt.

## Vision check (FE-070 (7), kurz)

Mehr Pflegezeit nur indirekt: kürzere Abnahmewartezeit für jedes folgende Paket; keine Hierarchie, kein Geldfluss, keine Daten. Schätzung `eng`: 2 Läufe (Schätzung, nicht gemessen).
