---
id: HD-3s-F2-F1
title: Handweg sieht die Pause einer geteilten Übernahme als belegt (CGR-289)
author: po
status: accepted   # PO 2026-11-27 20:39 auf `bfa275ae` (Simulation, synthetische Daten); approved 06:39; aus `cra` CGR-289 Abhilfe (a)–(c); keine neue Regel des PO
updated: 2026-11-27
---

# HD-3s-F2-F1 — Pause einer geteilten Übernahme auf dem Handweg belegt

Block: **HEIM-DP** (README-Regel 12), benannter Folgepunkt von HD-3s-F2 (FE-089 (3)). Ein Engineering-PR (`fix/hd3s-f2-f1`), nach STG-SMOKE-3. Simulation, synthetische Daten. Grundlage: `cra` CGR-289 (`reports/CLINICAL_GOVERNANCE.md` 2026-11-27 04:45, S1 vor realen Klienten). Der PO hat keinen Code gelesen und keine Tests ausgeführt.

## Problem

Der Auftragsweg behandelt den ganzen geteilten Arbeitstag einer Pflegenden als belegt, der Handweg (Fallbesuch durch die Teamleitung) nicht: `member_visit_overlap` und `member_slot_overlap` vergleichen nur Einsätze, und in der Pause liegt keiner. Plant die Teamleitung für sie um 12:00 einen Fallbesuch, liest sie «keine Überschneidung»; beim Speichern gibt der Trigger vor Beginn **ihre ganze geteilte Übernahme stillschweigend frei** (das Heim liest «Nicht mehr gedeckt», das Angebot geht neu hinaus); nach Beginn entsteht ein falscher P1 für Block 1. Abdeckung wird nie überzeichnet (fail closed), aber ein ganzer gedeckter Tag kann ohne Wort verschwinden.

## Users and journey step

Teamleitung (Handplanung Fallbesuch), Pflegende, Heimleitung (Deckung). Planning → Visit.

## Outcome

Die Teamleitung sieht die Pause einer geteilten Übernahme als belegt, bevor sie speichert; keine Übernahme wird mehr stillschweigend freigegeben.

## PO-Entscheid zu CGR-289 (c)

`cra` bietet zwei Formen an. Der PO wählt: **Der Handweg lehnt das Speichern eines Einsatzes ab, der sich mit dem Fenster einer laufenden Übernahme derselben Person überschneidet, mit einem Grund, der die Übernahme nennt** (Datum, Blöcke, Heim). Begründung: keine stille Freigabe, keine Alarmflut, gleiche Sperrlogik wie auf dem Auftragsweg; die Teamleitung entscheidet weiter selbst (andere Person, andere Zeit). Kein klinischer Wert wird gesetzt.

## Acceptance criteria

- [ ] Die Überschneidungsprüfung des Handwegs zählt das Fenster jeder laufenden Übernahme der Person (`starts_at..ends_at`, Pause eingeschlossen) als belegt; gleiche Personensperre wie heute (CGR-289 (a)).
- [ ] pgTAP: laufende geteilte Übernahme 07:00–11:30 / 16:00–20:00; Handbesuch 12:00–13:00 für sie → `member_overlap` true und `member_slot_overlap` true; 20:00–21:00 → false; 06:00–07:00 → false (CGR-289 (b)).
- [ ] pgTAP: Speichern des Handbesuchs 12:00–13:00 wird mit benanntem Grund abgelehnt; die Übernahme bleibt live, beide Einsätze unverändert, kein `take_member_dropped`, Heim liest weiter «Gedeckt».
- [ ] pgTAP Regression: Ein-Block-Übernahme unverändert; Handbesuch ausserhalb jedes Übernahmefensters unverändert erlaubt; Katalogwächter 157 für jede geänderte Funktion.
- [ ] e2e 390 und 1440 px: Teamleitung versucht den Fallbesuch in der Pause → sichtbarer Grund mit der Übernahme, nichts gespeichert; Negativ: anderer Zeitpunkt wird gespeichert.
- [ ] `staging-smoke`: bestehende Pfade grün; kein Timeout verlängert, kein Test übersprungen.
- [ ] Migration als ganze Datei, Funktionen aus den kanonischen Quelldateien (STAB1); `ci` grün auf dem Kopf; nach dem Merge `staging`-Job, dann `ci-repeat` 10/10 (`db`, `e2e`).

## Rules and their input class

Überschneidung einer Person mit ihrer eigenen Übernahme: *visit/schedule fact*. Keine klinische Regel, kein Wert.

## AI leverage

Keine KI: eine feste Belegungsregel. Entfernte Arbeit: Rückfrage und Neuvergabe nach einer stillen Freigabe.

## Integration (FE-136)

1. Sichten: Fallplanung der Teamleitung (Fehlermeldung); `/heim`, `/team`, `/field` unverändert. 2. Datensätze: liest `care_visits`, Übernahmen; schreibt nichts Neues. 3. Nachgelagert: keine Freigabe mehr aus diesem Fall. 4. Benachrichtigung: keine neue; Audit der Ablehnung wie bestehende Ablehnungen (`eng` nennt die Form). 5. Schutz: Datenbankprüfung im Trigger und in der Überschneidungsfunktion. 6. Staging-Pfad: bestehende Pfade 8/9 grün.

## PO-Entscheid Staging-Pfad 10 (2026-11-27 15:39, FE-137 (1), Frage `eng` [#1825 7217482763](https://github.com/Ivica1984/navora-mvp/pull/1825#issuecomment-7217482763))

**Der Vertrag gilt wie geschrieben; keine neue Bedingung (FE-089 (3)).** Staging-Kriterium bleibt «bestehende Pfade grün» (heute Pfade 1–9), kein Timeout verlängert, kein Test übersprungen. Pfad 10 (Handbesuch in der Pause abgelehnt, auf Staging) ist **keine** Merge- und keine Abnahmebedingung. `eng` nennt ihn im Bereitbericht als bekannte Grenze (STAGING 4): «Ablehnung des Handbesuchs in der Pause auf Staging nicht per Klickpfad nachgewiesen (kein Fall in Testteam Basel); nachgewiesen durch pgTAP und e2e in CI.» **Benannter Folgepunkt STG-P10** (Testwächter, kein Gate): Pfad 10 liest einen synthetischen Fall und schreibt nichts; baubar, sobald ein Fall in Testteam Basel besteht. Empfohlener Weg: Option (a), der Founder legt als synthetisches Operations-Demokonto in der App einen Fall mit klar synthetischem Namen an und weist ihn Testteam Basel zu; kein Secret, nichts in Chat oder Dokument. Option (b) (neues GitHub-Secret) nicht gewählt: ein weiterer Schlüssel für einen Lesepfad. Widerspruch zum `eng`-Prompt STAGING 3a (neuer Pfad je Ablauf): für dieses Paket gilt der Vertrag; Regel ab jetzt (FE-137 (1)): jeder Vertrag nennt vorab entweder den Staging-Pfad oder die bekannte Grenze mit Folgepunkt. `cra`-Frage von `eng` zu (c) (Abwesenheit und Übernahmefenster zugleich: abgelehnt statt freigegeben) geht ins Gate-Fenster, keine PO-Antwort.

## Gates

`cra` (CGR-289 geschlossen?), `uxa` (Grundtext verständlich, 390/1440 px). Start nur nach `Paket prüfbereit:` auf stabilem Kopf mit grüner CI (FE-089 (2)).

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste.

## Out of scope

CGR-290 (Block 2 allein freigeben, HD-3s-F2-F2, Produktform Founder/`po`); Ruhezeitregel auf dem Auftragsweg (`lca`/Clinical Owner); UXR-299 bis UXR-301.

## Vision check (FE-070 (7), kurz)

Kontinuität (eine gedeckte Person verliert ihren Tag nicht durch einen Klick), weniger Nacharbeit für Team und Heim, keine Disposition, kein Geldfluss.

## PO-Abnahme (2026-11-27 20:39, geplanter PO-Lauf, Signal FE-105 (1) (d))

**Ergebnis: accepted** auf `bfa275ae` (enthält `2ca16e9c`), Gate «Simulation, synthetische Daten». Der PO hat die Tests nicht lokal ausgeführt; er hat Check-Runs und Rohprotokolle über die GitHub-API gelesen.

| Kriterium | Ergebnis | Nachweis |
|---|---|---|
| Fenster jeder laufenden Übernahme zählt auf dem Handweg als belegt (CGR-289 (a)) | erfüllt | `cra-gate: #1825 54d0eb4e clear` (7224798961); Migration 0185; `eng` 7224392674 |
| pgTAP 12:00–13:00 true; 20:00–21:00, 06:00–07:00 false (CGR-289 (b)) | erfüllt | pgTAP 184 §8–§10 laut `eng`; `db` ×10 «Files=181, Tests=7462», «Result: PASS» (`ci-repeat` 46054928186) |
| Speichern in der Pause abgelehnt mit Grund, Übernahme live, kein `take_member_dropped` | erfüllt | pgTAP 184; `take-visit.sh` Fall 1/1s (`eng`); `db` grün |
| Regression Ein-Block, ausserhalb erlaubt, Katalogwächter 157 | erfüllt | pgTAP 157, `fn-source` 93/92 laut `eng`; `db` grün |
| e2e 390 und 1440 px, Negativfall | erfüllt | `hd3s-f2-f1-take-window.spec.ts` laut `eng`; `e2e` ×10 «234 passed», kein skipped/failed/flaky |
| `staging-smoke` bestehende Pfade grün, nichts übersprungen | erfüllt | `staging-smoke` 46051349320 Job 140683265332 «10 passed» (Pfade 1–9); Pfad 10 = STG-P10 (PO-Entscheid 15:39) |
| Migration ganze Datei, kanonische Quellen; `ci` grün; `staging`-Job; `ci-repeat` 10/10 | erfüllt | `ci` 46051349188 auf `2ca16e9c` grün; `staging`-Job 140687187525 «Applying migration 20261021000185…»; Render `004b5297` (`staging-version` 140684009936); `ci-repeat` 22/22 im Fenster 20:11–20:28 (Job 140701759860) |

Grenzen und Folgepunkte: `ABNAHMEAKTE.md` §2 HD-3s-F2-F1.
