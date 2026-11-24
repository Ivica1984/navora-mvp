# Regelkatalog Dienstplanung (HEIM-DP), Fassung 1

**Autor:** `eng`, Live-Sitzung mit dem Founder, 2026-11-24 ca. 23:30 CET (`session_011vs873H6veyU2FiP9iHg9w`).
**Auftrag (Founder, Auswahl «Regelkatalog jetzt, Bau dort»):** alle definierten Regeln mit Ausführungsreihenfolge, Prioritäten, Grenzwerten und ungültigen Eingaben beschreiben. Widersprüche benennen oder deterministisch lösen. Den Code baut die schreibende Session auf `feature/hd3a` (#1729, FE-099 2a).
**Abgleich mit dem Code:** `feature/hd3a` auf Kopf `e509c95` (`src/features/home-plan/draft.ts`, `supabase/schema/functions/*`). Dieser Katalog ändert keinen Code und keinen PO-Vertrag. Abweichungen zwischen Vertrag (`docs/agents/briefs/HD.md`) und Code sind gemeldet, nicht still angepasst.

Marken: **IMPLEMENTED** (auf dem Branch, nicht gemergt, ausser vermerkt) · **PLANNED** (Paket genannt) · **OPEN** (Entscheid fehlt, Eigentümer genannt) · **UNKNOWN**.
Alle Werte gelten für die Simulation mit synthetischen Daten. Ruhezeit und Tage am Stück tragen die Marke «Arbeitszeitgesetz nicht abschliessend geprüft». `lca` prüft vor echten Daten. Kein Wert hier ist eine klinische Regel (D-27). Die Qualifikationsmatrix bleibt PROPOSED.

---

## 1. Ausführungsreihenfolge des Planungslaufs

| Schritt | Was geschieht | Bei Fehler | Status |
|---|---|---|---|
| 0 Eingabeprüfung | Sollstunden pro Woche des Heims vorhanden und > 0 (`fullTimeMinutes`) | ganzer Lauf verweigert: `pensum_reference_missing` (fail closed), es entsteht kein Teilplan | IMPLEMENTED |
| 1 Kontext | Zuteilungen über ganze ISO-Wochen und ± max(Tage am Stück, 2) Tage um den Zeitraum lesen (`draftContextRange`) | — | IMPLEMENTED |
| 2 Bestand | Jede bestehende Zuteilung zählt für alle Regeln, auch ausserhalb des Zeitraums. Sie wird nie verschoben oder gelöscht. | — | IMPLEMENTED |
| 3 Bedarf je Zelle | Bedarf = Mindestbesetzung − anwesend − extern gedeckt (HD-2). Eine Zelle mit aktivem externem Auftrag bleibt beim Auftrag. | Zelle ohne Regel (`required_total` NULL) wird übersprungen | IMPLEMENTED |
| 4 Reihenfolge der Zellen | knappste Zelle zuerst (wenigste zulässige Personen beim Start), dann Datum, Beginn, Station, Dienstart-ID | — | IMPLEMENTED |
| 5 Person wählen | zuerst die fehlende Stufe, dann beliebige Stufe; Pflichtregeln in fester Reihenfolge (§3); unter den zulässigen Personen geringste geplante Minuten pro Pensum-Punkt, dann kleinste ID | keine zulässige Person: Lücke | IMPLEMENTED |
| 5a Wünsche | nur als Reihenfolge unter zulässigen Personen, vor der Last-Regel (§4) | nicht erfüllter Wunsch erscheint mit Grund | **PLANNED HD-3a** |
| 6 Lücken | jede Restlücke mit Grund aus Plandaten («1 × HF fehlt – 3 aktiv: 2 abwesend, 1 Ruhezeit») | Lücke ist nie «besetzt» | IMPLEMENTED |
| 7 Unabhängige Prüfung | `verifyDraft` prüft jede vorgeschlagene Zeile gegen jede Pflichtregel, getrennt geschrieben; Soll = 0 Verstösse | Verstoss > 0: Entwurf nicht übernehmbar | IMPLEMENTED (Sperre beim Übernehmen PLANNED) |
| 8 Übernehmen | `institution_apply_draft`: Datenbank prüft jede Zeile neu unter Personensperre; Lauf-Kennung | Zeile, die inzwischen bricht, wird nicht gespeichert und gemeldet | **PLANNED HD-3a** |

Deterministisch: gleiche Eingabe in beliebiger Reihenfolge ergibt den gleichen Plan. Es gibt keine Uhr und keinen Zufall (IMPLEMENTED, Unit-Test).

## 2. Prioritätsstufen

| Stufe | Bedeutung | Im Planungslauf | Bei Zuteilung von Hand |
|---|---|---|---|
| **P0 gesperrt** | nie erlaubt | nie | abgelehnt, auch mit Bestätigung (IMPLEMENTED) |
| **P1 Pflichtregel** | Regel des Heims | nie verletzt (Verstösse = 0) | Warnung, Speichern nur mit Bestätigung, Audit-Ereignis, Warnung bleibt sichtbar (FE-123 Q3, IMPLEMENTED) |
| **P2 Wunsch** | möglichst erfüllt | nur Reihenfolge, bricht nie P0/P1 | kein Hinweis nötig (PLANNED) |
| **P3 Ausgleich** | Fairness, Stabilität, Wochenenden | Strafpunkte mit Gewichten je Heim | — (PLANNED HD-3b) |
| **P4 Hinweis** | Information | beeinflusst nichts | Hinweis, keine Sperre |

**Konfliktregel (deterministisch):** Eine höhere Stufe gewinnt immer gegen eine tiefere. Kein Wunsch und kein Gewicht kann eine Pflichtregel aufheben. Kann eine Pflichtregel nur mit einer Lücke eingehalten werden, entsteht die Lücke (Schlupf «fehlender Platz»), nie ein Regelbruch und nie «besetzt».

## 3. Regeln, Grenzwerte, ungültige Eingaben

Prüfreihenfolge im Rechenwerk (`BLOCK_ORDER`): **R-b → R-c → R-d → R-e → R-f → R-g → R-h**. Der erste zutreffende Grund wird gezählt. R-a und die Stufe wirken als Filter davor.

| ID | Regel | Stufe | Grenzwert / Parameter | Ungültige Eingabe | Quelle | Status |
|---|---|---|---|---|---|---|
| R-a | nur aktive Personen | P0 | — | — | HD-1 R1 | IMPLEMENTED |
| R-q | Mindestbesetzung je Station und Dienst, davon n × Stufe | P1 (Lücke, nie besetzt) | 0–50 Personen, Stufe ≤ Gesamt | DB-Check lehnt ab | Heim-Konfiguration (D-27: keine klinische Regel) | IMPLEMENTED; Stufe zählt **genau** (siehe K6) |
| R-b | Pensum erfasst | P1 | 10–100 % | NULL = nie eingeplant (Grund «ohne Pensum»); ausserhalb DB-Check | FE-119 | IMPLEMENTED |
| R-c | Schichtmodell passt zur Schichtart | P1 | `any`, `early_only`, `late_only`, `night_only`, `no_night`; Klassen `early`/`late`/`night`/keine | Dienstart ohne Klasse nur an `any` | FE-123 Q2 | IMPLEMENTED |
| R-d | keine Abwesenheit berührt | **P0** | Tage nach `institution_shift_days`; Nachtdienst berührt zwei Kalendertage | Art ausserhalb der vier Arten abgelehnt; kein Grund-Feld | HD-1 R3, FE-120 | IMPLEMENTED |
| R-e | keine Doppelbelegung oder Überschneidung | **P0** | Zeitspanne DST-genau | — | HD-1 | IMPLEMENTED |
| R-f | Ruhezeit zwischen zwei Diensten | P1 | Standard 11 h; Eingabe 1–24 h | ausserhalb DB-Check | FE-119, Marke ArG | IMPLEMENTED; Eingabegrenze siehe K3 |
| R-g | höchstens n Arbeitstage am Stück (nach Arbeitsdatum) | P1 | Standard 6; Eingabe 1–14 | ausserhalb DB-Check | FE-119, Marke ArG | IMPLEMENTED; siehe K3, K4 |
| R-h | Dienstminuten je ISO-Woche ≤ floor(Pensum × Sollminuten / 100) | P1 | Sollstunden je Heim 1–80 h | Sollstunden fehlen: Lauf verweigert (Schritt 0) | FE-123 Q1 | IMPLEMENTED; **siehe K1, K2** |
| W-1 | bevorzugte Wochentage mit Dienstart | P2 | je Person, ohne Freitext | nur `lead`/`planner` derselben Institution, Audit, LEAVE1 | FE-125 | PLANNED HD-3a |
| W-2 | Tage ohne Arbeit (Wunsch) | P2 | je Person | wie W-1 | FE-125 | PLANNED HD-3a |
| S-1 | geteilter Dienst: Pause zählt nicht als Arbeitszeit | P1 | Minuten = Summe der zwei Blöcke | Blöcke überschneiden sich: abgelehnt (Vorschlag `eng`) | Founder 2026-11-24 (#1712 7145634673) | PLANNED HD-3s |
| S-2 | geteilter Dienst: Ruhezeit ab Ende des zweiten Blocks | P1 | wie R-f | — | Founder, wie S-1 | PLANNED HD-3s |
| S-3 | geteilter Dienst = ein Arbeitstag; Summe ≠ Soll pro Tag ergibt einen Hinweis | P4 | Soll pro Tag = Sollstunden ÷ Arbeitstage pro Woche (Vorschlag: Feld je Heim, Standard 5) | — | Founder «zählen, nicht erzwingen» | PLANNED HD-3s; Feld OPEN (Founder) |
| F-1 | Wochenenden pro Monat, Ausgleichstage, Fairness, Stabilität | P3 | Gewichte je Heim; Startwerte nach Messung von drei Profilen | — | FE-126, Founder 7145462972 | PLANNED HD-3b |

## 4. Wünsche (PLANNED HD-3a): Einordnung ohne Pflichtbruch

Vorschlag `eng` für Schritt 5a, deterministisch:
1. Filter P0 und P1 wie heute. Ein Wunsch macht nie eine unzulässige Person zulässig.
2. Unter den zulässigen Personen: zuerst wer diesen Tag mit dieser Dienstart wünscht (W-1). Wer den Tag frei wünscht (W-2), kommt zuletzt.
3. Danach wie heute: geringste Last pro Pensum-Punkt, dann kleinste ID.
4. Widersprechen sich W-1 und W-2 derselben Person am gleichen Tag, gilt W-2 (frei wünschen geht vor), und der Konflikt wird als Hinweis gezeigt. Das ist ein Vorschlag, Entscheid Founder/PO.
5. Jeder nicht erfüllte Wunsch erscheint in der Ergebnisliste mit dem Grund. Gründe sind entweder eine Pflichtregel (R-b … R-h) oder «für Mindestbesetzung gebraucht».

## 5. Widersprüche und Konflikte

| Nr | Konflikt | Wirkung heute | Lösung | Status |
|---|---|---|---|---|
| **K1** | R-h zählt die **ganze Dienstspanne inklusive Pause** als Pensum-Minuten. | Testheim: Früh 07:00–15:30 = 510 Min., 42 h = 2520 Min. Eine Person mit 100 % bekommt höchstens **4** Dienste pro Woche (5 × 510 = 2550 > 2520). **Gemessen** mit dem Rechenwerk auf `e509c95` (lokale Probe, nicht eingecheckt: 7 Früh-Bedarfe, 1 Person 100 %: 4 eingeteilt, 3 Lücken mit Grund `pensum_full`). Planung wirkt zu knapp. | Vorschlag: Pause je Dienstart als Eingabe des Heims (Minuten); Pensum-Minuten = Spanne − Pause. Pause ≥ gesetzliche Mindestpause ist ein Hinweis (`lca`), keine Sperre. Bis zum Entscheid gilt die heutige, strengere Rechnung. | **OPEN, Founder** |
| **K2** | R-h ist eine **harte Kappe je ISO-Woche**. | Eine Woche mit 6 Diensten bei 100 % ist nie möglich, auch wenn die Folgewoche kürzer ist. Der Founder sagt, dass 6 Tage pro Woche vorkommen. Das Arbeitsgesetz erlaubt Durchschnitte (Art. 21 Abs. 2 ArG: Halbtage bis 4 Wochen zusammenlegen). | Optionen: (a) Wochenkappe bleiben lassen (heute, streng); (b) Pensum über einen Ausgleichszeitraum (z. B. Monat) mit Wochen-Obergrenze; (c) Pensum als P3-Ziel, nur Obergrenze hart. Gehört zu HD-3b (Ausgleich). | **OPEN, Founder/PO** |
| **K3** | Eingabegrenzen sind weiter als die recherchierten Gesetzeswerte. | Ruhezeit 1–24 h (ArG: 11 h, Ausnahme 9 h mit Schnitt 12 h, Spital 8 h); Tage am Stück 1–14 (ArGV 1 Art. 21: 6, Ausnahme 7 nach Art. 7 Abs. 2 ArGV 2); Sollstunden 1–80 h (Höchstarbeitszeit 50 h). Ein Heim könnte heute 4 h Ruhe oder 10 Tage am Stück eintragen. | Vorschlag: Werte unter oder über der Gesetzesgrenze nur mit Warnung und Audit speichern (wie Q3), nicht sperren, bis `lca` die Grenzen festlegt. NAVORA erfindet keine Grenze. | **OPEN, `lca`** |
| K4 | Nachtdienst und «Tage am Stück» | Gezählt wird nach Arbeitsdatum: Nacht Mo 22:30–Di 07:15 = Montag. | Lesart `lca` vor echten Daten. | OPEN, `lca` |
| K5 | Wunsch gegen Pflichtregel | — | Pflichtregel gewinnt immer (§2). | gelöst (Regel) |
| K6 | Stufen-Bedarf zählt nur die genaue Stufe (HF deckt keinen FaGe-Platz und umgekehrt). | Lücke «1 × FaGe fehlt», obwohl eine HF frei ist. | Ob eine höhere Stufe eine tiefere ersetzen darf, ist eine fachliche Regel: Entscheid `cra`/Clinical Owner (D-27), nicht `eng`. Bis dahin genaue Stufe (streng). | OPEN, `cra` |
| K7 | Zuteilung von Hand gegen Pflichtregel | gespeichert mit Bestätigung, Audit, sichtbar | wie FE-123 Q3; Rechenwerk lässt sie stehen und zählt sie mit | gelöst (IMPLEMENTED) |
| K8 | Spätere Änderung (Pensum, Modell, Klasse, Grenzen) macht einen gespeicherten Dienst regelwidrig | Anzeige `rules` gegenüber `override_rules`, kein neues Audit-Ereignis | im Ready-Report ausdrücklich nennen (Review 7144617700 Frage 2) | gemeldet |
| K9 | Mindestbesetzung unerfüllbar | Lücke mit Grund | Schlupf «fehlender Platz»; nie Regelbruch | gelöst (IMPLEMENTED) |
| K10 | Zelle mit externem Auftrag | Rechenwerk füllt sie nicht | Auftrag hat Vorrang (HD-2) | gelöst (IMPLEMENTED) |

## 6. Recherchierte Gesetzesregeln, noch nicht im Rechenwerk

Quelle: SECO-Wegleitungen und die Merkblätter für Heime (Basel-Stadt, 2022) und für Krankenanstalten (SECO, 2023), gelesen am 2026-11-24. Noch nicht gegen die Gesetzestexte auf Fedlex abgeglichen. **Keine davon ist eine Pflichtregel, bevor `lca` sie freigibt.** Bis dahin baut `eng` nichts davon ein.

| Regel | Fundstelle (laut Quelle) | Betrifft | Status |
|---|---|---|---|
| Tagesspanne ≤ 14 h inkl. Pausen (Spital bis 17 h unter Bedingungen) | Art. 10 Abs. 3 ArG; Art. 5 ArGV 2 | geteilter Dienst, lange Dienste | OPEN `lca`; Kandidat HD-3s |
| Höchstarbeitszeit 50 h pro Woche | Art. 9 ArG | R-h, K3 | OPEN `lca` |
| Pausen: > 5,5 h 15 Min., > 7 h 30 Min., > 9 h 60 Min. | Art. 15 ArG, Art. 18 ArGV 1 | K1 | OPEN `lca` |
| freier Halbtag pro Woche bei mehr als 5 Arbeitstagen, zusammenlegbar bis 4 Wochen | Art. 21 ArG | K2 | OPEN `lca`; Kandidat HD-3b |
| 7 Tage am Stück nur mit ≤ 9 h/Tag, Schnitt 50 h über 2 Wochen, danach 83 h frei | Art. 7 Abs. 2 ArGV 2 | R-g | OPEN `lca` |
| Ruhezeit 9 h, wenn Schnitt 12 h über 2 Wochen | Art. 9 ArGV 2 | R-f | OPEN `lca` (heute strenger: immer 11 h) |
| Nachtarbeit 9 h in 10 h; 10 h in 12 h mit Präsenzzeit und 12 h Ruhe | Art. 17a ArG; Art. 10 Abs. 2 ArGV 2 | Nachtdienst | OPEN `lca` |
| mindestens 12 freie Sonntage pro Jahr | Art. 12 Abs. 2 ArGV 2 | Fairness | OPEN `lca`; Kandidat HD-3b |

Wo NAVORA heute strenger ist als die Quelle (Ruhezeit immer 11 h, nie 7 Tage), ist das sicher für die Simulation. Wo NAVORA weiter ist (Eingabegrenzen K3, keine 14-h-Spanne, keine 50-h-Grenze), ist das gemeldet.

## 7. Zuordnung zu Paketen

- **HD-3a (#1729, schreibende Session):** W-1, W-2 mit §4; Übernehmen (Schritt 8); Bildschirm; `staging-smoke`. K1 und K3 als Hinweise im Ready-Report, solange nicht entschieden.
- **HD-3s:** S-1 … S-3; Tagesspanne, falls `lca` freigibt.
- **HD-3b:** F-1, K2, freie Sonntage und Halbtage, falls `lca` freigibt; drei Gewichtsprofile messen.
- **`lca`:** K3, K4 und §6. **`cra`:** K6. **Founder:** K1, K2, Feld «Arbeitstage pro Woche».

AI-Kennzeichnung: alle Regeln hier sind **feste, prüfbare Regeln**. Kein Modell ist angeschlossen.
