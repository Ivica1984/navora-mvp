---
id: HD-3s-F2
title: Externer Auftrag mit zwei Blöcken (geteilter Dienst), feste Regeln
author: po
status: approved   # PO-Paketvertrag 2026-11-26 22:39 nach dem HD-3s-Merge (FE-133 (1): «one explicitly linked immediate follow-up»); Nachtrag Integration (FE-136) 23:39
updated: 2026-11-26
---

# HD-3s-F2 — Externer Auftrag mit zwei Blöcken (geteilter Dienst)

Block: **HEIM-DP** (README-Regel 12), unmittelbares Folgepaket von HD-3s (#1790, gemergt `7e48a7a4`), vor HD-3a-F1 (FE-133). Ein Engineering-PR (`feature/hd3s-f2`). Simulation, synthetische Daten. Grundlage: Founder FE-133 (1) ([#1790 7201934395](https://github.com/Ivica1984/navora-mvp/pull/1790#issuecomment-7201934395)), `cra` CGR-288 (`reports/CLINICAL_GOVERNANCE.md` 2026-11-26 21:30), `eng`-Entwurf [7203486480](https://github.com/Ivica1984/navora-mvp/pull/1790#issuecomment-7203486480) (ADR-Entwurf, PROPOSED). Der PO hat keine Tests ausgeführt und keinen Code gelesen ausser den Kommentaren und der Migration 0182 (Überblick).

## Problem

Seit HD-3s plant das Heim einen geteilten Dienst (z. B. 07:00–11:30 und 16:00–20:00). Bleibt er offen, kann die Heimleitung ihn nicht extern vergeben: die Datenbank weist `split_shift_not_orderable` ab, `/heim` zeigt «Geteilter Dienst: noch kein externer Auftrag möglich» (IMPLEMENTED, fail closed). Ein Auftrag kennt heute nur ein Zeitfenster `starts_at`/`ends_at`. Ergebnis heute: Lücke ohne Deckungsweg; im realen Heim würde eine Temporärfirma zwei Bruchstücke füllen, genau der Zwischenhandel, den NAVORA entfernt.

## Users and journey step

Heimleitung und Planer (`lead`, `planner`) auf `/heim` (Lücke → Auftrag); Team-Mitglieder in der Angebotsliste (`team_order_offers`) und bei der Übernahme; die Pflegende auf `/field` (Einsatz, Ein- und Auschecken). Matching → Team-Entscheid → Planung → Einsatz → Dokumentation → Abrechnungsentwurf. Keine neue Rolle, kein neuer Zugriff.

## Outcome

Eine offene Lücke eines geteilten Dienstes wird als **ein** Auftrag mit beiden Blöcken angeboten und von **einer** Pflegenden übernommen; sie sieht und erfasst beide Blöcke getrennt, ihre Pause bleibt für andere Aufträge gesperrt; alle bestehenden Auftragsschutzregeln gelten unverändert.

## PO-Entscheide zu den offenen Fragen von `eng` (7203486480)

- **(a) Pause besetzt, nicht frei:** angenommen. Die Pflegende ist für die ganze Spanne Block-1-Beginn bis Block-2-Ende belegt. Begründung: Der Founder verlangt keine freie Pause (FE-133 (1) nennt nur «beide Blöcke als ein Auftrag»); «Pause frei» war ein `eng`-Vorschlag und steht so im PO-Nachtrag 21:39 von `HD-3s.md` — **dieser Satz ist hiermit ersetzt**. Die besetzte Pause ist fail closed (gleiche Regel wie K3 in HD-3s), sie erfüllt CGR-288 (a) und (b) durch die Bauweise. Eine freie Pause ist ein späterer eigener Punkt, erst nach der `lca`-Lesart R-i/R-j (HD-3s-F1, HD-3s-F3).
- **(b) Zwei Einsätze je Übernahme:** angenommen als WAS: auf `/field` erscheinen zwei Einsätze (je Block), jeder mit eigenem Ein- und Auschecken; geplante Minuten nie über die Pause. Das WIE (Index, Spalte `block_no` o. ä.) entscheidet `eng`.
- **(c) `lca` vor dem Brief:** nein. Die besetzte Pause ist die vorsichtigere Lesart und ändert keine Arbeitszeitregel; `lca` liest im Gate-Fenster dieses Pakets (Abrechnungsentwurf je Einsatz, Ruhezeit ab Block 2).

## Scope (feste Regeln)

1. **Auftrag mit zwei Blöcken:** ein Auftrag trägt optional eine Pause (beide Grenzen leer = ein Block); Formprüfungen wie V1–V5 in HD-3s, gleiche Gründe in Bildschirm und Datenbank. Keine zweite Auftragszeile, keine automatische Aufteilung (FE-133 (1)).
2. **Auftrag aus der Lücke:** die Lücke eines geteilten Dienstes ist bestellbar; `split_shift_not_orderable` entfällt nur für diesen Weg; die Qualifikationsstufe der Lücke wird unverändert übernommen.
3. **Anzeige überall mit beiden Blöcken:** «07:00–11:30 und 16:00–20:00» auf `/heim`, in der Angebotsliste des Teams und auf der `/field`-Karte; nie nur ein Block.
4. **Übernahme:** eine Pflegende übernimmt den ganzen Auftrag; geprüft werden unverändert Stufe, Tätigkeiten, Überschneidung, Abwesenheit, Zugriffsende (LEAVE1), Personensperre (CGR-229/233). Die ganze Spanne gilt als belegt (Entscheid (a)).
5. **CGR-288:** (a) ein zweiter Auftrag in der Pause wird für sie abgelehnt; (b) die Ruhezeit zählt ab Ende Block 2; (c) Angebot mit beiden Blöcken und unverändertem Qualifikationsschutz; (d) pgTAP-Fall für (a) und (b).
6. **Einsätze:** zwei Einsätze je Übernahme (Entscheid (b)); Abrechnungsentwurf, Zeitprüfung und Rechnungsentwurf (BK-f) bleiben je Einsatz unverändert; geplante Minuten = Summe beider Blöcke ohne Pause.
7. **Unverändert:** Ein-Block-Aufträge (Regression), RLS, Spaltenrechte, Audit, Grants.

## Acceptance criteria

- [ ] pgTAP: ein Auftrag aus einer geteilten Lücke trägt beide Blöcke; Formfehler mit denselben Gründen abgelehnt; nur `lead`/`planner` derselben Institution, mit Audit; Fremd-Institution und andere Rollen abgelehnt.
- [ ] pgTAP: die Übernahme schreibt zwei Einsätze; ein zweiter Auftrag in der Pause wird für dieselbe Person abgelehnt (CGR-288 (a)); Ruhezeit ab Block 2 (CGR-288 (b)); Qualifikation und Tätigkeiten unverändert geprüft (Negativfall: zu tiefe Stufe abgelehnt).
- [ ] pgTAP Regression: Ein-Block-Aufträge unverändert (Angebot, Übernahme, ein Einsatz, Abrechnungsentwurf); Katalogwächter (157) für jede geänderte Funktion.
- [ ] Unit: Anzeige beider Blöcke (Formatierung), geplante Minuten ohne Pause.
- [ ] e2e 390 und 1440 px: Heimleitung bestellt eine geteilte Lücke → Team sieht beide Blöcke → Pflegende übernimmt → `/field` zeigt zwei Einsätze; Negativ: eine andere Rolle kann nicht bestellen.
- [ ] `staging-smoke`: derselbe Weg als neuer oder erweiterter Pfad; bestehende Pfade grün; kein Timeout verlängert, kein Test übersprungen.
- [ ] Migration als ganze Datei, Funktionen aus den kanonischen Quelldateien (STAB1); `ci` grün auf dem Kopf; nach dem Merge `staging`-Job, dann `ci-repeat` 10/10 (`db`, `e2e`) auf einem integrierten Commit.

## Rules and their input class

Alle Regeln sind *visit/schedule facts* (Zeiten, Überschneidung, Ruhezeit, Minuten). Keine *clinical content*; keine Regel, die nach Personen- oder Pflegekontext rangiert. Arbeitszeitwerte bleiben mit «Arbeitszeitgesetz nicht abschliessend geprüft» markiert.

## AI leverage

1. **Remove:** zwei getrennte Bestellungen und das Abstimmen von zwei Personen für einen Arbeitstag entfallen; eine Temporärfirma für Bruchstücke wird unnötig.
2. **Rules:** alles oben, deterministisch.
3. **Monitor:** die Datenbank prüft Übernahme und Pause bei jedem Auftrag.
4. **AI prepares:** keine KI (Grund: Arbeitszeit- und Auftragsschutz gehören ins feste Rechenwerk).
5.–7. Heimleitung bestellt, Team-Mitglied entscheidet mit «übernehmen»; Unterschriften und Bericht unverändert.
Gate: Simulation, synthetische Daten; D-35 Regel A unverändert. Die KI darf hier nichts.

## Integration (FE-136; PO-Nachtrag 2026-11-26 23:39)

Nachgetragen vor dem Baustart (kein Branch `feature/hd3s-f2` um 23:39), auf Founder-Bestätigung [#1712 7204197616](https://github.com/Ivica1984/navora-mvp/issues/1712#issuecomment-7204197616). Der Abschnitt beschreibt, was Scope und Kriterien oben schon festlegen; **er fügt keine Merge-Bedingung hinzu** (FE-089 (3)). Wo der PO den heutigen Stand nicht kennt, steht UNKNOWN.

1. **Geänderte Sichten:** `/heim` Woche (Lücke eines geteilten Dienstes → «Externen Auftrag vorbereiten» statt Sperrhinweis) und Sicht «Externe Aufträge» (Auftrag mit beiden Blöcken); Angebotsliste des Teams (`/team`); `/field` (zwei Einsätze). Monat und individueller Plan: zeigen die gedeckte Lücke aus demselben Stand wie heute (keine eigene Änderung). Tag-, Personal- und Leitungssicht: unverändert (noch nicht gebaut bzw. nicht betroffen).
2. **Gemeinsame Datensätze:** liest Diensttyp mit beiden Blöcken (HD-3s), Lücke/Vorgabe, Qualifikation, Abwesenheit, Zugriffsende; schreibt einen Auftrag (beide Blöcke in einer Zeile), Angebot, Übernahme, zwei Einsätze, Abrechnungsentwurf je Einsatz, Audit. Keine zweite Auftragszeile, keine Kopie der Planungsdaten.
3. **Folgeabläufe:** Auftrag → Angebot an Teams → Übernahme durch eine Person → zwei Einsätze auf `/field` (Ein- und Auschecken je Block) → Zeitprüfung → Abrechnungs- und Rechnungsentwurf je Einsatz (BK-f, unverändert). Die Heim-Woche zeigt den Stand der Lücke wie bei Ein-Block-Aufträgen (HD-2).
4. **Benachrichtigungen und Audit:** Audit für jeden Befehl (Scope 7). Benachrichtigungen: F2 fügt keine neue hinzu; welche der bestehende Auftragsablauf heute sendet, ist dem PO **UNKNOWN** — `eng` nennt es im Bereitbericht (Rückfrage, keine Bedingung). Fehlt eine, ist das ein Folgepunkt nach FE-136 (11), nicht Teil von F2.
5. **Pflichtregeln und Nachprüfung:** Scope 4 und 5 (Stufe, Tätigkeiten, Überschneidung über die ganze Spanne, Abwesenheit, LEAVE1, Personensperre, Ruhezeit ab Block 2, CGR-288), Prüfung in der Datenbank bei jeder Übernahme; Ein-Block-Regression.
6. **End-to-End-Pfad auf Staging:** Kriterium `staging-smoke` oben: Heimleitung bestellt die geteilte Lücke → Team sieht beide Blöcke → Pflegende übernimmt → `/field` zeigt zwei Einsätze; die Heim-Woche zeigt den Stand der Lücke wie bei Ein-Block-Aufträgen (HD-2, Punkt 3). Bis zur Lieferung bleibt die Marke «Geteilter Dienst: noch kein externer Auftrag möglich» sichtbar (FE-136 (10)).

## Out of scope (Nicht-Ziele)

- Freie Pause für die Pflegende (später, nach `lca` R-i/R-j); Aufteilen in zwei Aufträge durch die Heimleitung (FE-133 (1) «later»).
- R-i, R-j, R-k, Nachtmarke (HD-3s-F1, F3, F4); Monatssoll (HD-3a-F3); neuer Löser (HD-3b-0).
- Änderung der Tarif- oder Rechnungslogik über «je Einsatz» hinaus.

## Gates (ein Fenster nach `Paket prüfbereit:` auf einem stabilen Kopf mit grüner CI, FE-089 (2), FE-097)

- `cra`: CGR-288 (a)–(d); eine Person für beide Blöcke; Lücke nie «besetzt», solange niemand übernommen hat.
- `uxa`: Anzeige beider Blöcke in `/heim`, Angebotsliste und `/field`, zwei Einsätze verständlich, 390/1440 px.
- `lca`: Abrechnungsentwurf je Einsatz, Ruhezeit ab Block 2, besetzte Pause (Simulation); ein `lca`-Befund zur Lesart sperrt reale Daten, nicht die Simulation, ausser er nennt einen Fehler im vereinbarten Ablauf.

## Fixed residual list (FE-089 (3))

Die Kriterien oben sind die vollständige Merge-Liste. Befunde gehen in benannte Folgepunkte `HD-3s-F2-F…`, ausser ein dokumentierter, wesentlicher Sicherheits-, Datenschutz- oder Funktionsfehler im vereinbarten Ablauf.

## Vision check (FE-070 (7), kurz)

Mehr direkte Pflegezeit und Kontinuität (eine Person für den ganzen Arbeitstag statt zwei Fragmente); Teamautonomie (das Team entscheidet die Übernahme); kein Zwischenhandel, kein Geldfluss über NAVORA (FE-078); keine neue Disposition.

## Constraints and references

FE-078, FE-089, FE-097, FE-127, FE-133; `HD-3s.md`; `HD.md` §5b–§5d; `reports/CLINICAL_GOVERNANCE.md` CGR-288; `lca` 7195331421; Handbuch V2.2 und Blueprint V3.2 Kap. 8 (HEIM-DP).

## Open questions for engineering

- Schätzung laut `eng` 4–6 Läufe; bitte im Bereitbericht die tatsächliche Zahl.
- Grösstes Risiko laut `eng`: zwei Einsätze im Einsatz- und Abrechnungsweg; bitte im Bereitbericht nennen, welche bestehenden Tests sich änderten.
- AUT-222: wie viele geteilte Lücken der Seed heute hat (Messung im Bereitbericht).
