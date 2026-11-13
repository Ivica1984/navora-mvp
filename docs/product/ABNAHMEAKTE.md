# NAVORA Test- und Abnahmeakte je Block

**Besitzer:** Product Owner (`po`) · **Grundlage:** FE-070 (6), FE-071 · **Angelegt:** 2026-11-12 15:45 (Europe/Zurich) · **Regel:** Eine Abnahme gilt nur auf einem benannten integrierten Commit, auf dem die Tests des Blocks tatsächlich gelaufen und reproduzierbar grün sind. Dazu gehören die erforderlichen Reviews und ein dokumentierter Entscheid. Jede Abnahme nennt ihr Gate: «Simulation, synthetische Daten» oder «Freigabe für reale Personen und Daten». Eine Gesamtzahl bestandener Tests ersetzt diese Akte nie. Der PO führt keine Tests selbst aus; Testumgebung ist GitHub Actions (FE-056). Die Angaben unten stammen aus den Job-Protokollen, nicht nur aus der Statusanzeige.

## 1. Lauf auf dem benannten Commit `4a543c0` (abgeschlossen)

`4a543c0` ist der Stand von `recovery/main` nach #1127 (BD-7) und vier reinen Dokument-Merges.

| Lauf | Jobs | Ergebnis | Inhalt je Versuch |
|---|---|---|---|
| `ci` 43229659680 auf `00b4700` (Merge-Commit #1127; `00b4700..4a543c0` ändert nur Dokumente) | `app`, `db`, `e2e`, `ui-screenshots` | 4/4 `success` | `app`: 110 Testdateien, 1203 Unit-Tests bestanden; `db`: 128 pgTAP-Dateien, 4646 Tests; `e2e`: 163 Tests bestanden |
| `ci-repeat` 43231715012 auf `4a543c0` (gestartet 14:53, beendet 15:04) | 10 × `db`, 10 × `e2e` | **20/20 `success`** | je `db`-Versuch 128 Dateien / 4646 Tests «All tests successful»; je `e2e`-Versuch 163 bestanden |

Was die Protokolle zeigen:

- **Übersprungen:** 0. Es gibt keine `# SKIP`- oder `# TODO`-Zeilen in pgTAP, und Playwright meldet weder «skipped» noch «did not run».
- **Instabil:** 0. Playwright läuft mit `retries: 0` und einem Worker (`playwright.config`). Ein instabiler Test kann sich also nicht hinter einer Wiederholung verstecken.
- **Abgebrochen:** 0 Jobs. Abgebrochen wurden nur die parallelen `pull_request`-Läufe für PR #3 nach `main`. Sie gehören nicht zu diesem Nachweis.
- **Warnungen:** einzig die GitHub-Hinweise zu Node.js 20. Die Browser-Installation wurde in keinem Versuch wiederholt.
- **Erwartet rot, mit Absicht:** Zwei Reproduktionsproben laufen den alten, fehlerhaften Stand nach und prüfen, dass er rot ist. Sie bestehen, wenn das Rot erscheint:
  - B0-4: «vor #922: 080 rot, 17 von 58 fehlgeschlagen»;
  - B0-3: «READ COMMITTED: Katalog geändert, wie 079 Test 44».
- **Erwartet rot, aber nicht in der Testsuite:** Die Testfälle B2-T7 und B2-T8 sind beschrieben, aber noch nicht geschrieben (Tabelle §3).

**Zuvor auffällige Sicherheitsprüfungen, 10 von 10 Versuchen:**

| Prüfung | Was sie zeigt | Ergebnis |
|---|---|---|
| B0-4 / SIG1-Sperre (`b0-4-sig1-lock-race`) | 080 wartet auf die Sperre einer zweiten Sitzung und besteht dann | 10/10 «080 waited for the lock, then passed 59/59» |
| erzwungener Scheduler-Lauf während 062, 078, 080 | Sicherheitssignale gehen nicht verloren und werden nicht doppelt zugestellt | 10/10: 062 55/55, 078 51/51, 080 59/59, je ≥ 1 Scheduler-Lauf in der Datei, 0 Fehler |
| B0-3 / 079-Schnappschuss | Arbeitstag-Katalog stabil unter REPEATABLE READ | 10/10 «identical catalogue (640 role:object rows)» |
| BD-Durchgang (`durchgang-ambulant.spec.ts:185`, ein serieller Test) | Anfrage bis Abrechnungsfakt | 10/10 bestanden |
| BD-Stoppfälle pgTAP 124-128 | Simulationskennzeichen, Abrechnungsleser, Stoppfälle | 10/10 ok |

**Grenze:** Ein grüner Lauf beweist nur, was die Tests prüfen. Δ11 zeigt das: Der Fehler liegt in integriertem, getestetem Code und ist von keinem Test erfasst.

## 2. Blockakten

### B0 Technische Basis und Datenbanksicherheit

- **Status:** **für die Simulation abgenommen, ohne B0-6.** Entscheid 2026-11-11 03:39 auf dem benannten Commit `9bb38d1`, `ci-repeat` 42944657786 20/20.
- **Abgenommen:**
  - B0-1 jeder Merge-Commit vollständig getestet;
  - B0-2 Wiederholbarkeit 10/10;
  - B0-3 Flakes mit Ursache behoben;
  - B0-4 #919/080 reproduziert und behoben;
  - B0-7 Datenbankrechte;
  - B0-8 Migrationsreihenfolge;
  - B0-5 über die Alternative FE-056 (GitHub Actions statt lokaler Tests).
- **Ausdrücklich ausgeschlossen: B0-6 Repository-Schutz Stufe 1** (Pflicht-Checks, kein Force-Push, Secret Scanning; Owner-Handlung, D-7/FE-045). Er hat ein **eigenes Gate: vor B12 und vor jeden realen Daten**. Bis dahin gilt die Ersatzkontrolle: Der PO mergt nur mit Head-SHA und den sieben Bedingungen.
- Der Status wird nicht zurückgenommen, aber ab jetzt mit diesem Ausschluss benannt, nie mehr als «B0 abgenommen» ohne Zusatz.
- **Bestätigt auf `4a543c0`:** B0-2, B0-3 und B0-4 erneut 10/10 (§1).

### BD Durchgang ambulant

- **Status:** **Teilabnahme für die Simulation: ambulante Schritte 1, 1b, 2, 3, 4, 5, 8 und 9** (Schrittliste `PRODUCT_BLOCKS.md` §5). Entscheid 2026-11-12 14:39, wirksam mit `ci-repeat` 43231715012 20/20 auf `4a543c0`.
- **Abgenommene Schritte:**
  - 1 Anfrage → Fall → Teamsuche, Team übernimmt (J1, J2);
  - 1b Abklärungsbesuch → Pflegeplan (ASM1);
  - 2 Qualifikationsprüfung (QUAL1-**Mechanismus** mit VORGESCHLAGENEN Zellen v0.2, nicht die Zellen);
  - 3 PLAN3-Tagesvorschlag;
  - 4 Team bestätigt je Wert (AIG1);
  - 5 Einsatz auf 390 px mit Zeitkorrektur «Testlauf»;
  - 8 Bericht unterschrieben;
  - 9 abrechenbarer Fakt aus A- und C-Minuten, Referenztarif «nicht validiert». Kein Rechnungsentwurf (BILL1 nicht gebaut).
- **Negativfälle abgenommen:** fremdes Team, fremde Organisation und `anon` lesen und handeln nicht.
- **Nicht nachgewiesen, nicht Teil der Abnahme:**
  - Schritt 6 Diktat und Schritt 7 KI-Dokumentationsentwurf (B6, nicht gebaut);
  - Stoppfälle (a) Start an der Tür verweigert, was folgt, (b) Nachweis läuft beim Fortsetzen ab, (e) Pflegeheim-Bewohnerin ohne Zuständige: UNKNOWN bis zur Regel des Clinical Owners;
  - die Pflegeheim-Spalte BD-H (Abnahmebedingung von B9);
  - bekannte Lücke CGR-187.
- **Keine klinische Freigabe, kein Tarifnachweis, keine Freigabe für reale Daten.**

### SAFE-D11 Sicherheitsausnahme Δ11 (wiedereröffneter Fall ohne Team)

- **Status:** **für die Simulation abgenommen** (Gate «Simulation, synthetische Daten»). Entscheid 2026-11-13 02:39 auf dem benannten Commit `29e54ec` (`recovery/main` nach #1159; gegenüber dem Merge-Commit `873e212` von #1151 nur Dokumente).
- **Nachweis (aus den Job-Protokollen):**
  - `ci` 43341179263, Versuch 2 (gestartet 02:29 Zürich): 4/4 `success`; `e2e` 164 bestanden, 0 übersprungen; `db` 131 Dateien, 4711 Tests.
  - `ci-repeat` 43345332342: **20/20 `success`**; jeder `db`-Versuch 131 Dateien / 4711 Tests «All tests successful»; jeder `e2e`-Versuch 164 bestanden, 0 übersprungen, 0 instabil.
  - Die tageszeitabhängigen Tests BD-2, F3 und F7/F6R liefen in allen elf e2e-Protokollen und bestanden. Der Nachtlauf auf `873e212` (3 übersprungen) zählt nicht.
  - SAFE-D11-Tests: pgTAP 129 (Reproduktion), 130, 131 «ok»; e2e `safe-d11.spec.ts` bestanden.
- **Abgenommen:** Ein wiedereröffneter Fall ohne Team erhält eine neue zulässige Teamsuche oder eine sichtbare, Operations zugewiesene Ausnahme, nie keines von beiden (FE-072 (2)).
- **Nicht Teil der Abnahme:** Übergabe eines Falls eines inaktiven Teams an ein neues Team (CGR-195, CGR-196, B1.3); Freigabe für reale Personen und Daten.
- **Korrektur:** Die Bedingung «Anzahl übersprungen = Tageswert 1» vom 13.11. 00:39 beruhte auf einem Abendlauf (23:21, UX2-Verschiebetest übersprungen ab 23:15). Der volle Tageswert ist 0. Ab jetzt gilt: jeder tageszeitabhängige Test bestanden.

## 3. Offene Testfälle und was vor einer Abnahme zu beheben ist

| Block | Offen | Vor der Abnahme zu tun |
|---|---|---|
| B1 | kein e2e für B1-UX-2 (390 px, Doppeltipp), B1-UX-3 (Ablehnung), B1-UX-6 (Sicherheitshinweise, Negativfall CGR-162); ~~Δ11 ohne Test~~ (SAFE-D11 abgenommen 13.11. 02:39, §2) | B1.1 aktiv (`briefs/B1.1.md`); die drei e2e-Tests in B1.2 und B1.3 |
| B2 | B2-T7 (CGR-154) und B2-T8 (CGR-155) beschrieben, nicht geschrieben, nach heutigem Code erwartet rot; B2-T4 und B2-T9 neu; alle 115 Matrixzellen PROPOSED | QUAL1 Teil 2 und die Tests; Matrix bleibt Simulationsregel (FE-069) |
| B3 | B3-UX-3, B3-UX-4 (braucht UXR-146), B3-UX-5, B3-UX-8; QUAL1-Anbindung an PLAN3 | Tests schreiben; Prüfung auf jedem Zuteilungsweg (FE-070 (3)) |
| B4 | kein e2e für B4-UX-1 (390 px) und B4-UX-2 (verweigerter Start); frühere e2e-Instabilität VIS1, F1 | Tests; die F1-Ursache. Auf `4a543c0` lief e2e 10/10 ohne Wiederholung, die Ursache ist trotzdem nicht belegt |
| B5 | **B5-T7** verlangt 10/10 um 03:00 und 20:00 Zürich (tageszeitabhängig, PS-99), nicht nachgewiesen; B5-T11 neu | zwei `ci-repeat`-Läufe zu diesen Zeiten auf dem Kandidaten-Commit; **B5-T9 ist auf `4a543c0` 10/10 belegt** (§1) |
| B6 | Diktat, KI-Entwurf nicht gebaut | Bau, D-35 Stufe |
| B7 | B7-T1 bis B7-T3 (pgTAP) nicht geschrieben; Fach-/Legal-Gate | Tests; Gates |
| B8 | BILL1 und J5-v4 nicht gebaut; D-18 Phase B, D-22 offen | Bau als Simulationsregel (FE-069) |
| B9 | NH-A1 bis NH-A5 nicht gebaut; BD-H | Bau; BD-H grün |
| B10 | **AN3 widersprüchlich:** Code integriert (Migration 0108, pgTAP 109, Analyseansicht), die `eng`-Zeile steht auf `in-review`, die PO-Warteschlange führt AN3 noch als genehmigt und nicht begonnen (*Next up* Rang 2). AN3-C1 bis AN3-C3 nicht gebaut. | Der PO prüft AN3 gegen den Brief auf dem dann aktuellen Commit und bereinigt die Zeile; C1-C3 mit Tests. Bis dahin ist AN3 nicht abgenommen, gleichgültig was eine Zeile sagt |
| B11/B12 | Staging-Migration (#1087) wartet auf das Owner-Secret; B0-6 | Owner-Handlungen |

## Änderungsprotokoll

- 2026-11-12 15:45 (`po`): angelegt nach FE-071 (Founder-Rückmeldung auf Lieferung 1).
- 2026-11-13 02:39 (`po`): Blockakte SAFE-D11 (für die Simulation abgenommen auf `29e54ec`); B1-Zeile in §3 nachgeführt.
