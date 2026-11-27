---
id: HD-3s
title: Geteilter Dienst (zwei Blöcke) im Heimplan, feste Regeln
author: po
status: accepted   # für die Simulation teilabgenommen 2026-11-27 03:39 auf `5e9a0474` (ABNAHMEAKTE.md §2); Vertrag 2026-11-26 11:39
updated: 2026-11-27
---

# HD-3s — Geteilter Dienst (zwei Blöcke) im Heimplan

Block: **HEIM-DP** (README-Regel 12), Paket nach HD-3a, vor HD-3b (FE-127 (1)). Ein Engineering-PR (`feature/hd3s`). Vorarbeit: Probe `probe/hd3s-split-shift-red` (`506a1d40`, nicht gemergt) mit `docs/engineering/probes/HD-3s_RULES_DRAFT.md` und 50 Unit-Tests. Simulation, synthetische Daten. Der PO hat keine Tests ausgeführt und keinen Code gelesen ausser dem Regelentwurf.

## Problem

Viele Heime und Spitäler planen den geteilten Dienst (z. B. 07:00–11:30 und 16:00–20:00). HD-3a kennt nur Dienste mit einem Block. Heute muss die Heimleitung einen geteilten Dienst als zwei Dienste eintragen; dann greift die Ruhezeit von 11 h zwischen den Blöcken, der Tag zählt doppelt bei «Tage in Folge», und der Vorschlag lehnt jeden geteilten Dienst ab oder plant ihn falsch. Quelle: Founder-Parameter FE-127 (3) auf #1712; `eng` R-Entwurf §1–§3.

## Users and journey step

Heimleitung und Planer (`lead`, `planner`) auf `/heim` (Planung → Woche/Monat → Übernehmen → Lücke als Auftrag). Pflegende sehen den geteilten Dienst in ihrem Plan als einen Arbeitstag mit zwei Zeiten. Kein Zugriff anderer Rollen neu.

## Outcome

Die Heimleitung legt eine Dienstart mit zwei Blöcken an; «Plan vorschlagen» plant sie nach denselben Pflichtregeln wie jeden Dienst, mit den Founder-Regeln für den geteilten Dienst; die Datenbank prüft beim Übernehmen dasselbe; der Bildschirm zeigt Grund und Hinweise in Worten.

## Scope (Founder-Parameter FE-127 (3), feste Regeln)

1. **Dienstart mit zwei Blöcken** (Klasse `split`), Eingabe auf `/heim` durch `lead`/`planner` derselben Institution, mit Audit-Zeile. Formprüfungen V1–V5 in dieser Reihenfolge, gleiche Gründe in Bildschirm und Datenbank: `time_format`, `zero_length`, `block_crosses_midnight`, `block_order`, `no_pause`. Keine Mindest- oder Höchstpause (nicht vorgegeben, nicht erfunden).
2. **Pause zählt nicht als Arbeitszeit:** Pensum je ISO-Woche = Minuten beider Blöcke ohne Pause (R-h).
3. **Ruhezeit beginnt nach Block 2** (R-f): vom Ende von Block 2 bis zum nächsten Dienst und vom Ende des vorigen Dienstes bis Beginn Block 1; nie zwischen den Blöcken desselben Dienstes (K1).
4. **Ein Arbeitstag** für «Tage in Folge» (R-g); ≤ 6 Tage am Stück bleibt harte Regel.
5. **Überschneidung** je Block gegen jeden anderen Dienst; ein Dienst in der Pause ist `busy` (K3).
6. **Abwesenheit** gilt für den Arbeitstag des geteilten Dienstes (R-d, HD-3a R3).
7. **Schichtmodelle:** geteilter Dienst nur für «alle Dienste» (`any`) und «keine Nacht» (`no_night`); nie für «nur Früh», «nur Spät», «nur Nacht». Negativtest.
8. **Soll pro Tag nur Hinweis (S5):** Wochensoll des Heims ÷ **Arbeitstage pro Woche** (neues Feld je Heim, Vorgabe 5, Wertebereich durch `eng` begrenzt und in der Datenbank geprüft); Abweichung zeigt einen Hinweis, nie eine Sperre («Zählen, nicht erzwingen»). Kein Wochensoll → kein Hinweis.
9. **Einteilen von Hand:** gleiche Regeln wie HD-3a (FE-123 (7)): Regelverstoss mit Warnung gespeichert und auditiert; Abwesenheit und Überschneidung abgelehnt.
10. **Mindestbesetzung (fail closed):** ein geteilter Dienst zählt nur für die Mindestbesetzung seiner eigenen Dienstart, nicht für Früh oder Spät. Eine Lücke bleibt Lücke, nie «besetzt». Prüffrage an `cra`.
11. **Drei Prüfungen wie HD-3a:** Rechenwerk, unabhängiger Prüfer, Datenbank beim Übernehmen je Zeile. Marke «Optimierung (feste Regeln)»; alle Arbeitszeitwerte mit der Marke «Arbeitszeitgesetz nicht abschliessend geprüft».

## Out of scope (Nicht-Ziele)

- **Werte aus dem Arbeitsgesetz, die der Founder nicht gesetzt hat:** 50 h/Woche (R-i), 14-h-Tagesspanne (R-j), Nachtregel (R-k), Pausenhinweis S6, 9-h-Ruhezeitverkürzung, 7-Tage-Modell, 10-in-12-Nachtvariante. Der PO setzt keinen Arbeitsrechtswert (FE-127 PO-Einordnung). In HD-3s dürfen R-i und R-j höchstens als **Parameter des Heims ohne Vorgabewert** gebaut werden (leer = nicht geprüft, auf dem Bildschirm sichtbar als «nicht geprüft»); R-k und S6 nicht. Ob und mit welchem Wert sie gelten, liest `lca` im Gate dieses Pakets; den Startwert wählt der Founder. Ohne Antwort bleibt «leer, nicht geprüft».
- HiGHS, Wochenenden, Fairness, gespeicherte Planungsläufe (HD-3b); jedes KI-Modell (HD-3c/HD-3d); HD-3a-F1 (eigener Folgepunkt, vor HD-3b-Abnahme).
- Überzeit- oder Saldoberechnung.

## Acceptance criteria

- [ ] Unit (aus der Probe, angepasst): jede Regel und jeder Grund V1–V5, R-b bis R-h in der Reihenfolge des Regelentwurfs §6; 0 Pflichtregelverstösse auch mit geteilten Diensten; Pause nie im Pensum; Ruhezeit nie zwischen den Blöcken; ein Arbeitstag.
- [ ] Negativ: geteilter Dienst an ein Modell «nur Früh/Spät/Nacht» wird nie vorgeschlagen und in der Datenbank abgelehnt; ein Dienst in der Pause ist `busy`; eine ungültige Blockform wird von Bildschirm und Datenbank mit demselben Grund abgelehnt.
- [ ] pgTAP: Dienstart mit zwei Blöcken schreiben nur `lead`/`planner` derselben Institution, mit Audit; Fremd-Institution und andere Rollen abgelehnt; Check-Constraints V1–V5; Übernehmen prüft jede Zeile mit beiden Blöcken (Ruhezeit nach Block 2, ein Tag, Pensum ohne Pause); Feld «Arbeitstage pro Woche» nur im zulässigen Bereich.
- [ ] Mindestbesetzung: ein geteilter Dienst füllt keine Früh- oder Spätlücke (pgTAP oder Unit; Woche = Monat zeigt die Lücke).
- [ ] T-1 «übernommen = gezeigt» mit einem geteilten Dienst; e2e 390 und 1440 px für die Eingabe der Dienstart und den Hinweis S5.
- [ ] `staging-smoke`: Pfad 7 bleibt grün; neuer oder erweiterter Pfad: geteilte Dienstart anlegen → Plan vorschlagen → übernehmen → Woche zeigt einen Arbeitstag mit zwei Zeiten. Kein Timeout verlängert, kein Test übersprungen.
- [ ] Migration als ganze Datei, Funktionen aus den kanonischen Quelldateien (STAB1); `ci` grün auf dem Kopf; nach dem Merge `staging`-Job, dann `ci-repeat` 10/10 (`db`, `e2e`) auf einem integrierten Commit.

## Rules and their input class

Alle Regeln sind *visit/schedule facts* (Zeiten, Pensum, Tage). Keine *clinical content*, keine Regel, die nach Personen- oder Pflegekontext rangiert. Arbeitszeitwerte sind Founder-Parameter für die Simulation (FE-127 (3)), keine geprüfte Lesart des Arbeitsgesetzes.

## AI leverage

1. **Remove:** zwei Ersatzdienste und das manuelle Nachrechnen von Pause und Ruhezeit entfallen.
2. **Rules:** alles oben, deterministisch.
3. **Monitor:** die Datenbank prüft beim Übernehmen jede Zeile.
4. **AI prepares:** keine KI in diesem Paket (Grund: harte Arbeitszeitregeln gehören ins Rechenwerk; KI erst HD-3c/HD-3d).
5.–7. Heimleitung prüft den Vorschlag, entscheidet mit «übernehmen»; keine Unterschrift betroffen.
Gate: Simulation, synthetische Daten; D-35 Regel A unverändert. Die KI darf hier nichts.

## Gates (ein Fenster nach `Paket prüfbereit:` auf einem stabilen Kopf mit grüner CI, FE-089 (2))

- `cra`: Mindestbesetzung mit geteiltem Dienst (Punkt 10), Lücke nie «besetzt», Abwesenheit am Arbeitstag.
- `uxa`: Eingabe der zwei Blöcke, Gründe und Hinweise in Worten, 390/1440 px.
- `lca`: Lesart der Founder-Parameter (Pause keine Arbeitszeit, Ruhezeit nach Block 2) und der Frage R-i/R-j (FE-127: «spätestens im Gate von HD-3s»). Ein `lca`-Befund zur Lesart sperrt reale Daten, nicht die Simulation, ausser er nennt einen Fehler im vereinbarten Ablauf.

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste. Befunde gehen in benannte Folgepunkte `HD-3s-F…`, ausser ein dokumentierter, wesentlicher Sicherheits-, Datenschutz- oder Funktionsfehler im vereinbarten Ablauf.

## Constraints and references

FE-117, FE-119, FE-120, FE-123, FE-127, FE-129; `HD.md` §5b/§5c; Regelentwurf `HD-3s_RULES_DRAFT.md` (Probe); Handbuch V2.2 und Blueprint V3.2 Kap. 8 (HEIM-DP).

## Open questions for engineering

- Schätzung 1–2 Läufe (Founder-Tabelle); bitte im Bereitbericht die tatsächliche Zahl.
- Wie viele Zeilen der Probe unverändert übernommen werden und welche Tests sich änderten (Bereitbericht).
- Ob R-i/R-j als leere Parameter klein genug bleiben; sonst ganz weglassen und als HD-3s-F1 melden.

## PO amendment 2026-11-26 21:39 (geplanter PO-Lauf, Signale (b) und (e); keine neue Merge-Bedingung)

- **Gate-Stand auf `27cb1fc6`:** `lca` clear (7195331421), `cra` clear (7202806794; Lauf nach der Frist 18:39, Kopf unverändert, die Zeile gilt für dieses Fenster), `uxa` **fehlt**. Das Fenster bleibt auf diesem Kopf offen, bis die `uxa`-Zeile steht; ein neuer Push schliesst es.
- **Founder-Klarstellung FE-133 (#1790 7201934395):** (1) Externer Auftrag mit beiden Blöcken als ein Auftrag: nach `eng` (7201953843) kein kleinster sicherer Zusatz, daher **nicht in HD-3s**, sondern **HD-3s-F2** als unmittelbar nächstes Paket nach dem Merge; Inhalt: ein Auftrag mit zwei Zeitblöcken, Angebot und Übernahme je Block geprüft, Pause für die Pflegende frei, keine automatische Aufteilung in zwei Aufträge, Qualifikations- und Auftragsschutz unverändert, dazu `cra` CGR-288 (Arbeit in der Pause zählt für Wochenminuten, Ruhezeit ab Block 2 und R-j; pgTAP-Fall). Staging-Grenze bis dahin: «Geteilter Dienst: noch kein externer Auftrag möglich» und `split_shift_not_orderable` (fail closed). (2) Monatssoll: nicht in HD-3s; Folgepunkt **HD-3a-F3 «Monatssoll»** mit Founder-Wahl. (3) HD-3a-F1 wie gebilligt, vor realen Daten. (4) Kein weiterer Arbeitsrecht- oder Optimierungsumfang in HD-3s; Knappheitsreihenfolge bleibt (`cra` Antwort 4).
- **`cra`-Befunde als Folgepunkte (FE-089 (3)):** CGR-287 (S1 vor realen Personaldaten) → **HD-3s-F4** erweitert: Markierung «enthält Nachtarbeit ja/nein» je geteiltem Diensttyp mit Audit; ohne Markierung oder mit «ja» passt `no_night` nicht; Test mit Block 00:00–04:00; Nachtfenster erst nach Founder und `lca`. CGR-288 → HD-3s-F2 (oben).
- **`aia`-Vorschläge zur Form (AUT-225, AUT-226):** werden in den Briefen von F1, F3, F4, F5 entschieden, nicht hier.
- **Merge:** erst wenn `uxa-gate: #1790 27cb1fc6 clear` steht und §4 erfüllt ist.


## PO amendment 2026-11-26 22:39 (geplanter PO-Lauf, Signale (b) `uxa-gate: #1790 27cb1fc6 clear` und (e) Founder FE-135; keine neue Merge-Bedingung)

- **Gemergt:** #1790 auf Kopf `27cb1fc6` → `7e48a7a4` (Merge-Protokoll [7203964368](https://github.com/Ivica1984/navora-mvp/pull/1790#issuecomment-7203964368)). Gate-Zeilen auf diesem Kopf: `lca` 7195331421, `cra` 7202806794, `uxa` 7203139137, alle `clear` (Simulation).
- **Nach dem Merge (Rohlogs vom PO gelesen):** `ci` 45899843762 auf `7e48a7a4` grün (`db` «Files=179, Tests=7197», «Result: PASS»; `e2e` «228 passed», 2 skipped; `app`, `ui-screenshots`, `staging`). Migration 0182 auf `navora-staging` angewandt durch den `staging`-Job 140186862373 des `ci`-Laufs 45899881358 auf `14f07d03` (enthält `7e48a7a4`; «Applying migration 20261021000182_hd3s_split_shift.sql», «Finished supabase db push»); der Job auf `7e48a7a4` lief eine Minute später und las «Remote database is up to date». `staging-version` 45899881300: navora-staging dient Commit `14f07d03`, Datenbank 20261021000182, «app and database match».
- **`staging-smoke` (Rohlogs vom PO gelesen):** 45899843787 auf `7e48a7a4` **rot** in Pfad 3 (`founder-click-paths.spec.ts:81`: nach «Übernehmen mit Pflegekraft» blieb die Karte 20 s auf «Neues Angebot»; Pfade 4–8 nicht gelaufen; Meldung [7204222381](https://github.com/Ivica1984/navora-mvp/pull/1790#issuecomment-7204222381)). 45901445047 auf `5e9a0474` (enthält `7e48a7a4`, nur Doku dazu) **grün, «9 passed»**, inkl. Pfad 3 und neuem Pfad 8 (geteilter Dienst). Ursache des roten Laufs UNKNOWN, nicht «flaky» genannt; Pfad 3 berührt HD-3s nicht direkt; möglicher, nicht belegter Grund: Render-Umstellung während des Laufs. `eng` nennt die Ursache aus dem Bildschirmfoto und der Render-Deploy-Zeit, ein echter Fehler bekommt einen eigenen `fix/`-PR.
- **Noch nicht abgenommen:** Ursache Pfad-3-Rot benannt, dann `ci-repeat` 10/10 (`db`, `e2e`) auf einem integrierten Commit, dann `ABNAHMEAKTE.md` und Founder-Staging-Bericht.
- **Korrektur PO-Nachtrag 21:39:** der Satz «Pause für die Pflegende frei» für HD-3s-F2 ist ersetzt: in HD-3s-F2 ist die Pause **besetzt** (`eng` 7203486480 (1); kein Founder-Auftrag für eine freie Pause; fail closed, erfüllt CGR-288 (a)/(b)). Vertrag: [`HD-3s-F2.md`](HD-3s-F2.md).
- **`uxa`-Befunde als Folgepunkte (FE-089 (3)):** UXR-294 (mittel, vor realen Daten: Split-Formular macht still einen ungenutzten Ein-Block-Typ mit gleichem Kürzel zum geteilten Dienst) → **HD-3s-F6** (ablehnen mit Grund oder Änderung in der Erfolgsmeldung nennen; vor realen Daten). UXR-293 entfällt mit HD-3s-F2. UXR-295 bis UXR-298 (niedrig) → **HD-3s-F6** zusammen, Reihenfolge `po` nach HD-3a-F1.

## PO acceptance 2026-11-27 03:39 (geplanter PO-Lauf, Signal FE-105 (1) (d): `ci-repeat` im Fenster, `eng` #1790 7207404185; Gate «Simulation, synthetische Daten»)

Benannter Commit **`5e9a0474`** (enthält `7e48a7a4`; darüber nur Dokumentation). Der PO hat keine Tests lokal ausgeführt; Belege aus Job-Protokollen, Gate-Zeilen und dem Bereitbericht (#1790 7193712249).

| Kriterium | Ergebnis | Beleg |
|---|---|---|
| Unit: Regeln V1–V5, R-b bis R-h, 0 Pflichtverstösse, Pause nie im Pensum, Ruhezeit nie zwischen den Blöcken, ein Arbeitstag | erfüllt | Bereitbericht 7193712249 (Tests je Regel); `app`-Job `ci` 45899843762 `success` |
| Negativ: `split` an «nur Früh/Spät/Nacht» nie vorgeschlagen und in der DB abgelehnt; Dienst in der Pause `busy`; ungültige Blockform mit gleichem Grund | erfüllt | Bereitbericht; `cra-gate` 7202806794 clear; pgTAP im `db`-Job |
| pgTAP: Schreibrecht nur `lead`/`planner` derselben Institution, Audit, Check-Constraints V1–V5, Übernehmen prüft beide Blöcke, «Arbeitstage pro Woche» im Bereich | erfüllt | `db` «Files=179, Tests=7197», «Result: PASS» in `ci` 45899843762 und 10/10 in `ci-repeat` 45922060591 (Rohprotokolle vom PO gelesen) |
| Mindestbesetzung: geteilter Dienst füllt keine Früh- oder Spätlücke | erfüllt | `cra-gate` 7202806794 (Punkt 10); pgTAP im `db`-Job |
| T-1 «übernommen = gezeigt» mit geteiltem Dienst; e2e 390 und 1440 px | erfüllt | `e2e` 10/10 «230 passed», 0 skipped, 0 failed, 0 flaky (`ci-repeat` 45922060591); `uxa-gate` 7203139137 clear |
| `staging-smoke`: Pfad 7 grün, neuer Pfad 8 (geteilte Dienstart → vorschlagen → übernehmen → ein Tag mit zwei Zeiten); kein Timeout verlängert, kein Test übersprungen | erfüllt | `staging-smoke` 45901445047 «9 passed» auf `5e9a0474` (Render lieferte `5e9a0474`, `eng` 7204514910); roter Lauf 45899843787 Pfad 3: Render-Wechsel wahrscheinlich, nicht bewiesen (STG-SMOKE-3) |
| Migration als ganze Datei, STAB1; `ci` grün auf dem Kopf; `staging`-Job; `ci-repeat` 10/10 | erfüllt | Merge-Protokoll 7203964368; `staging`-Job 140186862373 «Applying migration 20261021000182_hd3s_split_shift.sql»; `ci-repeat` 45922060591 22/22, Fensterurteil Job 140258626480 «Inside the e2e acceptance window» |

**PO-Status: `accepted`** (Simulation, synthetische Daten). Keine Freigabe für reale Personen und Daten. Offen vor realen Daten: HD-3s-F1, F3, F4, F5, F6 (UXR-294), ArG-Lesart `lca`, HD-3a-F1. Nächstes Paket: HD-3s-F2 (#1808).

