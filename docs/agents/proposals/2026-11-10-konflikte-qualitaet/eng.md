# Stellungnahme `eng` zu V1-V14

**Stand:** 2026-11-11 00:10 (Europe/Zurich), `eng` (Lead Engineer), Antwort auf Issue #1037 (FE-054, PO 2026-11-10 22:50). Nur diese Datei; README und andere Rollendateien unverändert. **Status aller Punkte: VORGESCHLAGEN**, bindend ist nur `FOUNDER_DECISIONS.md`. Kennzeichnung: IMPLEMENTED (im Repository vorhanden), PLANNED, OPEN, UNKNOWN.

**Reihenfolge-Vorbehalt (FE-054):** Alles, was hier Werkzeug baut (V1, V2, V-eng-1, #1036), ist kein Kriterium von B0. `eng` baut es erst, wenn der PO es einem Block zuordnet oder eine Ausnahme ausspricht (COORD-7: eine offene Engineering-Code-PR). Vorschlag zur Einordnung siehe V-eng-4.

## V1-V14

| Nr | Haltung | Begründung / Änderung |
|---|---|---|
| V1 ADRs je Datei | **Zustimmung, mit Änderung** | Entspricht dem schon erfassten Item MERGE1 (#964, `not-started`, wartet auf Einordnung durch den PO). Änderung: **keine Massenmigration** der bestehenden ADRs. `DECISIONS.md` bleibt wie `JOURNAL.md` unverändertes Archiv bis ADR-178; ab ADR-179 je Datei `docs/engineering/adr/ADR-<n>.md`. Ein Index wird erzeugt, nicht von Hand gepflegt; CI prüft, dass er aktuell ist. Risiko ohne Gegenmittel: zwei parallele PRs nehmen dieselbe Nummer (siehe V-eng-1). |
| V2 Status je Item | **Zustimmung, mit Änderung** | Teil von MERGE1. Je Item eine Datei `docs/agents/status/<ID>.md` mit denselben Feldern wie heute (Origin, State, Next step, PRs, ADRs, Blocked by, Notes); `agents-check` liest die Dateien statt der Tabelle (heute IMPLEMENTED: `scripts/agents-check.mjs` liest die Tabelle *Items*). Die Übersichtstabelle wird erzeugt. Unit-Tests für Generator und Leser zuerst. Dazu V-eng-2 (kurze Statuszeilen), sonst bleibt die B0-Zelle mit rund 16 000 Zeichen auch als Datei unlesbar. Konflikte bleiben möglich, wenn zwei PRs dasselbe Item ändern; das ist mit COORD-7 selten. |
| V3 Generierte Dateien | **Grösstenteils IMPLEMENTED; nur Regel ergänzen** | `ci.yml` (Job `db`) prüft schon, dass `src/lib/supabase/database.types.ts` zu den Migrationen passt (`db-types drift`), und `db-types-sync.yml` erzeugt die Datei neu und committet sie. Kein neues Skript nötig. Fehlend ist nur die Regel für Merges: bei einem Konflikt in dieser Datei die Fassung von `recovery/main` übernehmen, pushen und `db-types-sync` neu erzeugen lassen; der Drift-Check fängt einen Fehler. Vorschlag: eine Zeile in `COORDINATION.md` (PO-Entscheid). |
| V4 Ein Kriterium = ein Testfile | **Zustimmung für neue Tests; bestehende nicht verschieben** | Neue pgTAP- und e2e-Fälle in eigene Dateien je Kriterium (wie schon `123_b0_7_catalogue_privileges.test.sql`, IMPLEMENTED). Bestehende Dateien wie 067, 080, 110 nicht umziehen: Evidenz in ADRs, PRs und Gate-Zeilen zeigt auf diese Dateinamen und Testnummern (z. B. B0-4 auf 080 Tests 6-9); ein Umzug würde Nachweise entwerten und könnte Assertions verlieren. Dateinummern: siehe V-eng-1. |
| V5 Blöcke je Datei | Zustimmung | PO-Sache. Für `eng` hilfreich, wenn jede Kriterienzeile Test-Datei und Lauf-ID trägt; `eng` liefert diese Angaben im PR. |
| V6 Block-Tafel | Zustimmung | `eng` liest sie zu Beginn jedes Laufs. Bitte kurz halten (aktiver Block, offene Kriterien, PR, fehlendes Gate, nächster Merge); Evidenz bleibt im PR und ADR. |
| V7 Ein Kriterium je PR | **Zustimmung, mit Änderung am Richtwert** | Ein Kriterium je PR: ja (B0-1, B0-4, B0-7, B0-8 so geliefert; B0-3 war mit fünf Teilen in einer PR die Ausnahme). Der Richtwert ≤ 400 Zeilen soll **Tests und Testskripte nicht zählen**, sonst entsteht ein Anreiz, weniger zu testen (B0-4, PR #1039: 482 Zeilen, davon 194 Unit-Test und 224 Reproduktionsskripte, 64 Workflow und Doku). Vorschlag: ≤ 400 Zeilen Produktcode und Migrationen, ohne Tests und generierte Dateien; Überschreitung im PR begründen. |
| V8 Sofortiges Nachziehen | **Zustimmung; heute schon Praxis** | Schritt A jedes `eng`-Laufs zieht `recovery/main` per Merge-Commit nach, wenn eine PR `dirty` ist (IMPLEMENTED als Ablauf, z. B. #1032 am 10.11. 22:13). Erweiterung: auch bei `clean` nachziehen, wenn seit dem letzten grünen Lauf eine Migration oder ein Test auf `recovery/main` dazukam. Die sauberste Lösung ist die GitHub-Regel "Require branches to be up to date" im Ruleset (Teil von B0-6, Owner-Klicks, OPEN). Kosten: jeder Nachzug ist ein voller CI-Lauf (rund 15-20 Minuten); mit COORD-7 tragbar. |
| V9 Revert zuerst | **Zustimmung, mit Änderung** | Revert-PR im selben Lauf, wenn der rote Job durch den Merge verursacht ist. **Nicht** bei einem Fehler mit Präfix `infrastructure:` (ADR-174, ADR-178 Entscheid 1: gilt als nicht getestet): dort zuerst ein Re-run des Jobs. Auch der Revert-PR braucht grüne CI auf Kopf und Merge-Commit (FE-054); `eng` merged ihn nicht selbst, der PO merged ihn vor allem anderen. Danach Ursachenanalyse und neue PR. |
| V10 Test zuerst sichtbar | **Zustimmung, mit Änderung** | Für B0-1, B0-4 und B0-7 so geliefert (IMPLEMENTED: Probe #1029; 080 rot ohne #922-Block; Negativprobe B0-7). Für jede PR ein Probe-Branch ist teuer. Vorschlag: **erster Commit einer PR enthält nur die neuen Tests**; der CI-Lauf dieses Commits ist rot und dient als Nachweis (Lauf-ID im PR); danach folgt die Implementierung. Probe-Branch nur, wo ein Test etwas bestehendes absichern soll (Regression, Rechte). Für Doku-PRs entfällt V10. |
| V11 Gate in zwei Läufen | Zustimmung | Betrifft Gate-Rollen. Aus Sicht `eng` der grösste Stau heute (#1039 wartet nur auf das `cra`-Gate). |
| V12 Takt | **IMPLEMENTED durch Owner (22:55)** | `eng` :09, `lca` alle 4 h :20, `cra` alle 4 h :26, PO :39. Keine Einwände. |
| V13 Lokale Tests | **Nicht möglich (Owner, 22:55); Alternative angenommen** | `eng` fragt nicht mehr nach Netzzugang. Alternative #1038 (schnelle Prüfung auf GitHub Actions vor einer PR): Heute läuft `ci` nur bei `pull_request` und bei Push auf `main`/`recovery/main` (IMPLEMENTED, `ci.yml`), ein Push auf einen Feature-Branch ohne PR wird nicht geprüft. PLANNED in #1038: ein Workflow für Branches `quick/**` mit `app`-Job (lint, typecheck, unit, build), ohne `db` und `e2e`; keine PR, kein Merge. |
| V14 Durchgangstest Pflicht | **Zustimmung, sobald BD-2 existiert** | PLANNED mit Block BD. Einbau in den bestehenden `e2e`-Job; `scripts/ci-scope.mjs` (IMPLEMENTED) entscheidet schon heute, ob eine PR `src/` oder `supabase/` berührt. Bedingung: der Durchgang läuft wie in B0-2 10/10 stabil, sonst blockiert ein Flake jede PR. Laufzeitbudget im BD-ADR festlegen. |

## Eigene Vorschläge

| Nr | Vorschlag | Wirkung | Wer baut |
|---|---|---|---|
| V-eng-1 | **Nummernvergabe ohne Kollision:** die Prüfung aus `scripts/migration-order.mjs` (B0-8, IMPLEMENTED für Migrationen) auf ADR-Nummern und pgTAP-Dateinummern ausdehnen: neue Nummer muss über der höchsten der Basis liegen, keine Doppelung. | parallele PRs entdecken die Kollision in der CI statt beim Merge | `eng` |
| V-eng-2 | **Kurze Statuszeilen:** eine Statuszeile (bzw. Datei aus V2) trägt Zustand, nächsten Schritt und Links; die Evidenz steht im PR und im ADR, nicht in der Zeile. | `IMPLEMENTATION_STATUS.md` lesbar, weniger Konfliktfläche | `eng` |
| V-eng-3 | **Reine Doku-PRs mit nur neuen Dateien** (Journal-Datei, Stellungnahme wie diese) brauchen keine Gate-Zeile, nur grüne CI. | Gate-Rollen prüfen nur, was ihre Regeln berührt | PO-Entscheid (Governance) |
| V-eng-4 | **Werkzeug-Reihenfolge nach B0:** zuerst #1036 (agents-check und `freeze.mjs` lesen `journal/*.md`, Voraussetzung für FE-053), dann #1038 (`quick/**`), dann MERGE1 (V1, V2, V-eng-1), je eine PR; als Vorlauf zu BD oder als PO-Ausnahme unter COORD-7. | Konfliktquellen vor BD entfernt | `eng` nach PO-Einordnung |

## Offen / unbekannt

- UNKNOWN: Laufzeit eines Durchgangstests (BD-2) je PR; erst messbar, wenn er existiert.
- OPEN: B0-6 (Ruleset, Owner-Klicks) entscheidet, ob V8 durch GitHub erzwungen werden kann.

Keine personenbezogenen oder Gesundheitsdaten. Live-Projekt nicht berührt.
