---
id: HD-PEN-HAND
title: Handeinteilung ohne Pensum, Monatssoll oder Wochensoll zeigt «Stunden nicht prüfbar» (bestätigen oder abbrechen), feste Regel
author: po
status: accepted   # PO 2026-11-28 12:39, für die Simulation auf `ed7759e8` (ABNAHMEAKTE §2); zuvor approved 08:39, aktiv 08:39–12:39
updated: 2026-11-28
---

# HD-PEN-HAND — «Stunden nicht prüfbar» auf dem Handweg

Block: **HEIM-DP**. Entscheid ENG-PH1 (`OPEN_DECISIONS.md`, PO 2026-11-28 01:39: ja; `cra` empfiehlt ja, Gate-Zeile 7230360397; CGR-286 Handteil). Reihenfolge: HD-3a-F3 (abgenommen 08:39) → **HD-PEN-HAND** → HD-3s-F2-F1-F1 → HD-3b-0. Ein Engineering-PR. Simulation, synthetische Daten. Grundlage: `eng` ADR-232 (Entwurf, `docs/engineering/DECISIONS.md`, gemergt mit #1859) und rote Probe #1858 (`probe/hd-pen-hand-red`, pgTAP 188). Der PO hat keinen Code gelesen und keine Tests ausgeführt; Codefakten aus ADR-232.

## Problem

Teilt die Heimleitung oder Planung eine Person **von Hand** ein, die weder Pensum noch (für den Monat des Diensts) ein Monatssoll hat, oder ist im Heim kein Wochensoll eingetragen, speichert `institution_assign_staff` heute **still**, ohne Stundenprüfung und ohne Hinweis (IMPLEMENTED, Probe #1858 rot). «Plan vorschlagen» und «übernehmen» lehnen dieselbe Lage seit HD-3a-F1/HD-3a-F3 fail closed ab. Der Handweg ist damit der letzte Weg, auf dem eine Person ohne jede Stundengrenze verplant werden kann (`cra` S2 vor realen Personaldaten).

## Users and journey step

Heimleitung und Planung im Heim (`/heim` Woche, Monat, Plan je Person), Schritt «Planning» der Kette. Pflegende sehen nur das Ergebnis.

## Outcome

Wer eine solche Person von Hand einteilt, sieht vor dem Speichern «Stunden nicht prüfbar» mit dem Grund und der nächsten Handlung und wählt «trotzdem einteilen» oder «abbrechen». Bestätigte Dienste tragen sichtbar «von Hand bestätigt» und stehen im Audit. Nichts wird mehr still ohne Stundenprüfung gespeichert.

## PO-Entscheide zu den Fragen «for `po`» in ADR-232 (FE-137 (1))

| Frage | Entscheid PO | Grund |
|---|---|---|
| Warnung mit Bestätigung oder Sperre? | **Warnung mit Bestätigung** (bestehende Warn-/Bestätigungsschleife), keine Sperre | ENG-PH1 lautet «bestätigen oder abbrechen»; eine Sperre wäre eine neue Regel (`cra`/Founder). Eine Lücke in den Stammdaten darf eine dringende Besetzung nicht blockieren, muss aber sichtbar und auditiert sein |
| Altbestand (vor der Migration still gespeicherte Dienste) | Die Marke erscheint je gespeichertem Dienst **unbestätigt** (eine Regelquelle, ADR-232 Punkt 3) **und** zusätzlich **eine Zählzeile** oben in `/heim` Woche/Monat: «n Dienste ohne Stundenprüfung» mit Link zur ersten betroffenen Person (AUT-247) | sichtbar statt still; die Zählzeile macht den Altbestand mit einem Blick behebbar; Wortlaut `cra`, Darstellung `uxa` |
| Staging-Pfad (FE-137 (1)) | **Pfad 12 nur, wenn die Seed-Daten von Testheim Rhein bereits eine synthetische Person ohne Pensum und ohne Monatssoll enthalten:** Handeinteilung → Text sichtbar → «abbrechen» → nichts gespeichert (kein Schreibvorgang, kein Zurücksetzen nötig). Sonst **bekannte Grenze** mit Folgepunkt **STG-PH-1** (Seed-Person anlegen). Kein neues Secret | kein Schreiben auf Staging ohne Rückweg; `eng` nennt im Bereitbericht, welcher Fall gilt |
| UXR-309, UXR-310 | **fahren mit** (gleicher Bildschirm, gleiche Stundenwörter) | ein Durchgang am Formular statt zwei; beide `medium` |
| AUT-243 (einmalige Bestätigung je Heim) | **nicht in diesem Paket**, Folgepunkt | eine Bestätigung je Dienst ist die sichere Grundform; Sammelbestätigung später auf Messung |

## Acceptance criteria

- [ ] **Regel, eine Quelle:** `private.institution_rule_breaches` (ganz aus der kanonischen Datei, Stand nach HD-3a-F3) liefert im letzten Platz: Monatssoll im Monat des Arbeitstags → R-m (unverändert); sonst Pensum und Wochensoll eingetragen → R-h (unverändert); sonst **`hours_unknown`**. Nie zwei davon. Signatur, `stable`, leerer `search_path`, revoke unverändert; keine neue Tabelle, Spalte, Sperre oder Berechtigung.
- [ ] **Handweg:** erster Aufruf von `institution_assign_staff` für eine solche Person → `warning` mit `hours_unknown`, **nichts gespeichert**; bestätigter Aufruf speichert mit `override_rules` ⊇ `hours_unknown`, Audit trägt den Code. Negativ: «abbrechen» → nichts gespeichert. Kontrolle: Person mit Pensum und Wochensoll unverändert.
- [ ] **Probe #1858** rot vorher, grün nachher (pgTAP 188 alle Fälle): Person ohne Pensum; Heim ohne Wochensoll; mit Monatssoll im Monat des Diensts kein `hours_unknown` und R-m bindet; Monatssoll nur im anderen Monat einer ISO-Woche → `hours_unknown` nur für den Dienst im Monat ohne Soll.
- [ ] **Nebenläufigkeit:** Pensum zwischen Warnung und Bestätigung eingetragen → zweiter Aufruf rechnet neu (`hours_unknown` weg; bricht nun R-h, kommt `pensum_full` als neue, unbestätigte Warnung); Pensum dazwischen entfernt → `hours_unknown` unbestätigt → Warnung. Nie unbestätigt gespeichert (Zwei-Sitzungs-Skript im `db`-Job, wie J/K).
- [ ] **«übernehmen» unverändert:** Ablehnungscodes `pensum_missing` und `weekly_target_missing` bleiben (pgTAP); keine Zeile wird zu `hours_unknown`.
- [ ] **Plan-Ansicht:** gespeicherte Dienste einer solchen Person zeigen die Marke («von Hand bestätigt» nur wenn bestätigt); Zählzeile «n Dienste ohne Stundenprüfung» mit Link; ohne betroffene Dienste keine Zählzeile (negativ). Ein unbekannter Regelcode wird nie als «undefined» gezeigt (Filter durch `isPlanningRule` in `queries.ts`).
- [ ] **Nächste Handlung:** für die Leitung Link «Pensum eintragen» / «Monatssoll eintragen» / «Wochensoll eintragen» bei der Warnung; für die Planung der Name der Rolle, die es eintragen kann (UXR-305-Muster). Wortlaut `cra`, Darstellung `uxa`.
- [ ] **UXR-309:** bei leerem Monatssoll ist «kein Monatssoll» vorgewählt, und eine getippte Zahl wählt «Wert»; die erste Eingabe kostet keinen abgelehnten Speichervorgang (e2e). **UXR-310:** Ablehnungstext nach «übernehmen» und die Personalliste nennen «weder Pensum noch Monatssoll» bzw. «· ohne Pensum» nur, wenn auch kein Monatssoll im gezeigten Monat besteht (Unit auf `pensumMissingText`).
- [ ] **Unit:** Regelliste, `parseRules`, `ruleText`, `ruleWarning` mit `hours_unknown`; Plan-Filter unbekannter Codes; `verifyDraft`/Paritätstest kennt den Code.
- [ ] **e2e 390 und 1440 px:** Leitung teilt eine Person ohne Pensum von Hand ein → Text sichtbar → «trotzdem einteilen» → Dienst mit «(von Hand bestätigt)»; «abbrechen» → nichts gespeichert.
- [ ] **Katalogwächter 157** verlangt `hours_unknown`; behaltene Wächter (175–177, 185–187) grün.
- [ ] `staging-smoke`: Pfade 1–9 und 11 grün; Pfad 12 oder bekannte Grenze STG-PH-1 gemäss Entscheidtabelle.
- [ ] `ci` grün auf dem Kopf; nach dem Merge `staging`-Job, dann `ci-repeat` 10/10 (`db`, `e2e`).

## Rules and their input class

`hours_unknown` ist eine Antwort der bestehenden Regelquelle auf eine **fehlende Heim-Konfiguration** (Pensum, Monatssoll, Wochensoll: *visit/schedule fact*, synthetisch). Kein klinischer Wert, keine neue Schwelle. Sie leitet nicht um und eskaliert nicht; sie verlangt eine Bestätigung. Kennzeichnung «Arbeitszeitgesetz nicht abschliessend geprüft» bleibt.

## AI leverage

1. Entfernen: die stille Fehlerquelle «Person ohne Stundengrenze verplant» und das spätere Suchen danach. 2. Regel: feste, prüfbare Regel in der Datenbank. 3. Überwachen: die Zählzeile zeigt den Bestand laufend. 4. KI bereitet vor: **keine KI** (Grund: reine Vollständigkeitsprüfung, deterministisch). 5.–7. Die Leitung oder Planung prüft, entscheidet («trotzdem einteilen») und verantwortet; Audit hält es fest. Entfernter Verwaltungsschritt: nachträgliches Nachrechnen von Stunden ohne Grundlage; Messgrösse: Zahl «Dienste ohne Stundenprüfung» je Heim → 0 nach der ersten Planungswoche. Daten: synthetisch. Die KI darf hier nichts.

## Integration (FE-136)

1. Sichten: `/heim` Woche, Monat, Plan je Person (Marke, Zählzeile, Warnformular), Personalformular (UXR-309), Ablehnungstext «übernehmen» (UXR-310); `/team`, `/field`, Auftragssicht unverändert. 2. Datensätze: liest Plan, Pensum, Monatssoll, Wochensoll; schreibt nur den bestehenden Dienst mit `override_rules` und Audit; keine doppelten Planungsdaten. 3. Nachgelagert: Lücken und externer Auftrag unverändert. 4. Benachrichtigung: keine (ehrliche Grenze); Audit-Eintrag je bestätigtem Dienst. 5. Schutz: Regel in `private.institution_rule_breaches`, gelesen nach Personensperre `for update` und Heim `for share`; LEAVE1-3 und `assert_access_open` zuerst. 6. Staging-Pfad: siehe Entscheidtabelle.

## Gates

`cra` (Wortlaut «Stunden nicht prüfbar», Bestätigung statt Sperre, Altbestand), `uxa` (Warnung, Zählzeile, UXR-309/310, 390/1440 px). `lca` nicht für die Simulation (keine neue Vertrags- oder Arbeitszeitregel). Ein Gate-Fenster nach `Paket prüfbereit:` (FE-089 (2), FE-097).

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste.

## Out of scope

Harte Wochen-Höchstarbeitszeit (HD-3a-F3-F1 = F-2); Sperre statt Warnung; Sammelbestätigung je Heim (AUT-243); Abfrage von Pensum und Wochensoll beim Anlegen (Onboarding-Hypothese, Folgepunkt HEIM-ONB); AUT-246 (Monatssoll aus Vormonat übernehmen); UXR-311 bis UXR-314; HD-3b-0.

## Constraints and references

ENG-PH1; CGR-286 (Handteil); ADR-232; Probe #1858; HD-3a-F1, HD-3a-F3 (`ABNAHMEAKTE.md` §2); FE-089 (3), FE-136, FE-137 (1); AUT-247; UXR-305, UXR-309, UXR-310.

## Open questions for engineering

1. Enthält der Staging-Seed von Testheim Rhein schon eine synthetische Person ohne Pensum und ohne Monatssoll? (entscheidet Pfad 12 oder STG-PH-1)
2. Bereitstellungsfenster (ADR-232): alte App zeigt für diese Personen kein Bestätigungsformular (fail closed, nichts gespeichert) und auf deren Diensten kurz «Regel: undefined». Im Bereitbericht als bekannte Grenze nennen.

## Vision check (FE-070 (7), kurz)

Patientensicherheit und Personalschutz: keine Einteilung ohne sichtbare Stundengrenze. Weniger Nacharbeit; die Leitung entscheidet selbst, keine Disposition, keine neue Hierarchie, kein Geldfluss, keine KI.

## PO acceptance (2026-11-28 12:39, geplanter PO-Lauf, Signal FE-105 (1) (d))

**Status: accepted** für die Simulation auf `ed7759e8` (Merge-Commit von #1863; Gate «Simulation, synthetische Daten»; `ABNAHMEAKTE.md` §2). Der PO hat die Tests nicht lokal ausgeführt; alle Werte aus Rohdaten der Jobs über die GitHub-API und aus den `eng`-Berichten 7237198017 und 7238623085.

| Kriterium | Ergebnis | Nachweis |
|---|---|---|
| Regel, eine Quelle (R-m → R-h → `hours_unknown`, nie zwei; Signatur, STABLE, search_path, revoke unverändert) | erfüllt | Migration 0190; pgTAP 188 (Ausschluss R-m/`hours_unknown`) und 157 (MANIFEST); `eng`-Zweitlesung 7237079370; `cra`-Gate |
| Handweg: Warnung, nichts gespeichert; Bestätigung mit `override_rules` und Audit; «abbrechen» nichts; Kontrollperson unverändert | erfüllt | pgTAP 188 in `db` ×10 «Result: PASS»; e2e `hd-pen-hand.spec.ts` |
| Probe #1858 rot vorher, grün nachher (alle Fälle inkl. ISO-Woche über Monatsende) | erfüllt | `eng` lokal: 188 auf 0189 15/30 not ok, auf 0190 30/30; CI 188 ok ×10 |
| Nebenläufigkeit (Pensum dazwischen eingetragen/entfernt; nie unbestätigt gespeichert) | erfüllt | pgTAP 188 Neuberechnungsfälle; Zwei-Sitzungs-Skript «ok - L …» im `db`-Job (vom PO gelesen) |
| «übernehmen» unverändert | erfüllt | pgTAP 188 (`pensum_missing`, `weekly_target_missing`) |
| Plan-Ansicht: Marke, Zählzeile mit Link, ohne Dienste keine Zählzeile, kein «undefined» | erfüllt | e2e (Marke, Zählzeile); Unit `hd-pen-hand.test.ts` (Negativfall Zählzeile, `withKnownRules`); Negativfall nur Unit (keine Bedingung) |
| Nächste Handlung je Rolle | erfüllt | Unit (nächste Handlung je Rolle); `cra` (a), `uxa` (a) clear |
| UXR-309, UXR-310 | erfüllt | e2e (UXR-309), Unit/e2e Texte; `uxa` (c), (d): «closes on merge» |
| Unit: Regelliste, Parsing, Text, Warnung, Filter, Parität | erfüllt | `tests/unit/hd-pen-hand.test.ts` im grünen `app`-Job |
| e2e 390 und 1440 px | erfüllt | `e2e` ×10 «242 passed», beide Breiten grün, keine skipped/failed/flaky-Zeile |
| Katalogwächter 157, Wächter 175–177, 185–187 | erfüllt | `db` ×10 «Files=185, Tests=7668», «Result: PASS», 0 «# SKIP» |
| `staging-smoke` Pfade 1–9, 11; Pfad 12 oder STG-PH-1 | erfüllt (mit Grenze) | Job 140952514335 «11 passed», «FAILED_PATHS: 0»; STG-PH-1 nach Entscheidtabelle |
| `ci` grün; `staging`; `ci-repeat` 10/10 | erfüllt | `ci` 46136355774 5/5; `staging` 140954944189 «Applying migration …0190…»; `staging-version` 140952729379 «up to 20261021000190», «app and database match»; `ci-repeat` 46138674419 22/22 im Fenster |
| Gates `cra`, `uxa` | clear | 7237426357, 7237600865 auf `a50ff9e7` |

Bekannte Grenzen (keine Bedingung): STG-PH-1; Bereitstellungsfenster ADR-232; Zählzeile nur im gezeigten Bereich; Render-Deploy-ID UNKNOWN. Folgepunkte: HD-PEN-HAND-F1 bis -F4 (UXR-315 bis UXR-318), UXR-290, AUT-243, HEIM-ONB.
