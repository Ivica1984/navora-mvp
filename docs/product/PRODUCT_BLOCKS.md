# NAVORA Produktblöcke: Bestandsaufnahme, Abhängigkeiten und Abnahmestatus

**Besitzer:** Product Owner (`po`) · **Grundlage:** Founder-Entscheid **FE-052** (2026-11-07) · **Fassung 1:** 2026-11-07 19:40 (Europe/Zurich) · **Belege:** [`inventory/INVENTORY_2026-11-07.md`](inventory/INVENTORY_2026-11-07.md) (je PR und je Issue) · **Arbeitsbuch:** Blueprint §0 (v2.28) verweist hierher.

Die Datei ist die führende Übersicht für Blöcke und Abnahmen. Die Briefs (`docs/agents/briefs/`) bleiben die Quelle für die Kriterien einzelner Items. Engineering-Status steht weiter in `IMPLEMENTATION_STATUS.md`. Der PO hat für diese Fassung **keine Tests ausgeführt**. Alle Testaussagen stammen aus der GitHub Actions API, gelesen am 2026-11-07.

---

## 0. Ausgangslage und Begriffe (FE-052)

**Ausgangslage:** NAVORA hat **noch keinen nachweislich tragfähigen Pilot**. Es gibt entwickelte und teilweise integrierte Bausteine. Für jeden Produktblock ist zu prüfen, ob er als zusammenhängendes Produkt sicher und zuverlässig funktioniert. Danach ist das in einem vollständigen Simulationsablauf nachzuweisen.

**Begriffe (nie austauschbar):**

| Begriff | Bedeutung | Beleg |
|---|---|---|
| **gemergt** | Änderung ist in `recovery/main` aufgenommen | Merge-Commit |
| **Tests ausgeführt** | die genannten Tests liefen auf einem **benannten Commit** mit dem genannten Ergebnis | CI-Lauf-ID oder Protokoll einer lokalen Ausführung |
| **geprüft** (fachlich, rechtlich, UX) | `cra`, `lca` oder `uxa` haben den **gemergten Stand** gelesen und kein blockierendes Finding | Gate-Zeile mit Commit |
| **freigegeben** | die **befugte Person** hat entschieden: Clinical Owner für klinische Regeln (D-27; noch nicht ernannt, G-1), Founder für Owner-Entscheide | Entscheid mit Datum |
| **abgenommen** (Block) | alle Abnahmekriterien des Blocks sind auf einem benannten Commit nachgewiesen, die Gates liegen vor, die Entscheidung ist schriftlich | Abnahmeprotokoll in §3 |

`cra`- und `lca`-Analysen sind **Vorbereitung, keine Freigabe**. Solange kein Clinical Owner ernannt ist, ist **keine klinische Regel freigegeben**. Frühere PO-Vermerke „accepted“ in `NEXT_CAPABILITY.md`, in den Briefs und im Blueprint bedeuten nur: Prüfung gegen die Brief-Kriterien mit CI auf dem PR. **Sie sind keine Blockabnahme.**

**Blockzustände:** `nicht begonnen` · `in Arbeit` · `implementiert, nicht ausreichend getestet` · `Testfehler offen` · `Fach-/Legal-Gate offen` · `abnahmebereit` · `abgenommen`. Hat ein Block mehrere offene Punkte, gilt der früheste Zustand dieser Reihe. Den Zustand `nicht begonnen` ergänzt der PO für Blöcke ohne Umsetzung.

---

## 1. Wichtigste Befunde der Bestandsaufnahme

1. **Kein Block ist abgenommen.** Das betrifft auch alle 48 Items, die bisher als „accepted“ geführt wurden. Das ist eine Umbenennung, kein Rückbau.
2. **Umfang:** 701 PRs wurden seit 2026-10-21 in `recovery/main` gemergt. 167 davon ändern Produktcode, Datenbank, Tests oder CI, 534 nur Dokumentation oder Governance. Allein am 05., 06. und 07.11. waren es 138 Merges.
3. **Integrierter Stand je Merge:** Von den 167 Produkt-, Test- und CI-PRs haben **36 auf ihrem eigenen Merge-Commit keinen grünen Nachweis**: 21 Läufe wurden durch den nächsten Merge abgebrochen, 8 Merge-Commits liefen nie, 7 waren rot.
   - Ursache der Abbrüche: `ci.yml` setzt `concurrency: cancel-in-progress: true` auch für `recovery/main`.
   - Spätere grüne Commits enthalten diese Änderungen. Sie belegen den jeweiligen Gesamtstand, nicht den einzelnen Merge.
4. **Nicht deterministische Tests auf `recovery/main`:** Auf **13 Commits** von `recovery/main` brachte derselbe Commit einmal grün und einmal rot (Zeitraum 30.10. bis 07.11.; 344 `ci`-Läufe: 294 grün, 32 abgebrochen, 18 rot). Betroffen sind:
   - **Sicherheitssignale** (pgTAP 062, 078, 080): siehe Punkt 5;
   - **Arbeitstag** (pgTAP 079, #603 offen; zuletzt rot am 30.10.);
   - **Doppelbesuch** (pgTAP 098, 30.10.);
   - **e2e**: VIS1 Feldaktionen (30.10.), F1 Gegenzeichnung (30.10.), **UX2-23 Vertragsende** (30.10. und **07.11. 12:57 auf `be2af00`**, Lauf 42374741556; bis heute ohne Issue, jetzt **#979**);
   - **Infrastruktur** („Start local Supabase“, 3-mal).
5. **#919 / pgTAP 080 (Ausfall- und Eskalationspfad der Sicherheitssignale):**
   - Der Fix **#922** (`4af6f8d`, CGR-110) setzt eine **Hypothese** um, einen Lock-Wettlauf mit dem Minuten-Cron. Die Ursache wurde **nie reproduziert**.
   - Seit dem Fix waren alle 77 `db`-Jobs auf `recovery/main` grün (Lauf 1 abgebrochen, Zeitraum 06.11. 21:54 bis 07.11. 18:11).
   - #919 wurde am 07.11. 09:38 mit dieser Begründung geschlossen.
   - **Status nach FE-052:** Symptom seit dem Fix nicht mehr beobachtet, **Ursache nicht nachgewiesen**. Für einen Test, der klinische Gate-Bedingungen belegt (LEAVE1-C2, SIG2, DOOR1-12 bis -14; `cra` 06.11. 21:10), reicht das nicht als „bestanden“. Der Nachweis ist B0-4. **#919 ist deshalb am 07.11. 19:35 wieder geöffnet.**
6. **AN3 (#841):**
   - gemergt am 06.11. 19:40 als `49ab0e0`; CI auf dem Merge-Commit abgebrochen, auf dem Folge-Commit `f5f5e09` einmal grün und einmal rot (pgTAP 080, #919);
   - nach FE-038 sollte AN3 „bei stabil grünem Lauf“ als abgenommen gelten; **eingetragen wurde das nie**. Die Status-Dateien widersprechen sich: `NEXT_CAPABILITY.md` führt „approved“, `IMPLEMENTATION_STATUS.md` „in-review“, der Brief „not yet accepted“;
   - das `cra`-Gate liegt auf `09cdc85`; zum gemergten Head `802987f` weicht nur die generierte Datei `database.types.ts` um eine Zeile ab;
   - offen sind AN3-C1 bis AN3-C3 und die `lca`-Prüfung gegen D-23 vor echten Daten;
   - **Status:** implementiert, nicht ausreichend getestet (Block B10).
7. **Fachliche Gates auf dem gemergten Stand:**
   - 149 PRs ändern Code oder Datenbank. Nur bei **6** liegt eine `cra`-Gate-Zeile auf genau dem gemergten Head, bei 9 weiteren auf einem früheren Head mit blob-gleichen eigenen Code-Dateien.
   - Bei **8** wichen eigene Code-Dateien zwischen Gate und Merge ab, meist durch Konfliktauflösung: #806, #809, #813, #814, #841, #876, #880, #885. #880 und #885 sind durch das Gate der Sammel-PR #934 abgedeckt; bei #841 (AN3) betrifft die Abweichung nur eine generierte Zeile in `database.types.ts`.
   - Bei 126 steht kein Gate im PR. Die Gate-Zeile gibt es erst seit 2026-11-06 13:00. Frühere `cra`-Prüfungen stehen in `CLINICAL_GOVERNANCE.md`, sind dort aber keinem gemergten Commit zugeordnet. **Status je Block:** nicht nachgewiesen, bis die Blockprüfung sie zuordnet.
8. **Repository-Schutz ist nicht aktiv** (API-Abfrage 07.11. 19:10):
   - das Repository ist **öffentlich**;
   - es gibt kein Ruleset und keinen Branch-Schutz auf `recovery/main`;
   - Secret Scanning und Push Protection sind aus.

   D-7 ist entschieden (FE-045, vier Stufen), Stufe 1 ist **noch nicht umgesetzt** (Owner-Klicks).
9. **Lokale Testfähigkeit fehlt.** In den Agenten-Sitzungen löst `registry.npmjs.org` nicht auf (erneut geprüft am 07.11.), und es gibt keinen Docker-Daemon. Lint, Typecheck, Unit-, pgTAP- und e2e-Tests laufen **nur in CI**. FE-047 erlaubt die npm-Registry, die Einstellung ist aber noch nicht gesetzt.
10. **Kein Staging und kein Wiederherstellungstest.** D-2 ist teilweise beantwortet (FE-048: Supabase Zürich, Schweizer App-Host, Staging jetzt), aber der Host ist nicht gewählt und nichts ist eingerichtet. Ein Wiederherstellungstest mit neu erzeugten synthetischen Daten hat nie stattgefunden.
11. **Issues:** 256 Issues sind erfasst. 48 sind offen (30 davon Entscheidungspakete, 1 blockiert). Bei den 208 geschlossenen nennt der Schlusskommentar bei **78 PR und Test**, bei 20 nur einen PR und bei **95 keinen Beleg**. 15 sind begründet überholt. Geschlossene Issues ohne Beleg gelten als **nicht nachgewiesen** und werden in der Blockprüfung erneut belegt. Sie werden **nicht wieder geöffnet, solange die Blockprüfung keinen Fehler zeigt**, damit die Liste nicht zur Beschäftigung wird.
12. **Korrektur einer eigenen Aussage:** Der PO-Lauf von 17:39 führte ASM1-C6 (#815) als „accepted, IMPLEMENTED“. Richtig ist: *gemergt (`5d15391`), CI grün auf dem Merge-Commit (Lauf 42392510972), `cra` ohne blockierendes Finding auf `b386c14`, keine klinische Freigabe, nicht als Block abgenommen*. ASM1-C7 ist offen.

---

## 2. Blöcke und Abhängigkeiten

**Verbesserungen gegenüber dem Founder-Vorschlag** (begründet):

- **B1 „Anfrage, Fall und Teamentscheid“ ist neu.** Der Phase-A-Ablauf beginnt mit der Anfrage und dem Teamentscheid (J1, J2, C1). Diese Teile gehören zu keinem der vorgeschlagenen Blöcke.
- **B5 „Sicherheitssignale und Eskalation“ ist ein eigener Block.** Er ist patientensicherheitskritisch, betrifft ambulant und Heim, und dort liegt der widersprüchliche Test 080. In einem Sammelblock ginge er unter.
- **B10 „Kennzahlen“ ist ein eigener Block.** AN1 bis AN3 messen, ob NAVORA Pflegezeit freisetzt (Wert 1). Sie sind kein Teil der Abrechnung.
- „Simulierter Pflegeheim-Betrieb und ambulante Abläufe“ ist geteilt. **B9** ist die Pflegeheim-Sektorschicht (NH-A1 bis NH-A5). Die ambulanten Abläufe liegen in B1 bis B8 und werden in **B11** als Gesamtablauf nachgewiesen.

**Rollen:** *liefert* = baut und testet technisch; *prüft* = fachliche, rechtliche oder UX-Prüfung (beratend); *gibt frei* = entscheidet. Die Produktabnahme jedes Blocks macht der **PO mit Belegen**. Klinische Regeln gibt nur der **Clinical Owner** frei (nicht ernannt). Owner-Einstellungen und -Verträge macht der **Founder**.

| Block | Zweck und Umfang (Items) | liefert | prüft | gibt frei | hängt ab von | überprüfbares Ergebnis | Zustand | wichtigste offene Punkte |
|---|---|---|---|---|---|---|---|---|
| **B0** Technische Basis und DB-Sicherheit | Repository-Schutz (D-7), CI deterministisch und je Merge (CI2, MERGE1), lokale Testfähigkeit, RLS/Rechte (F0, RLS2-4, AUD1, LEAVE1, COND1/2), Migrationsreihenfolge, Sicherheitstests (SEC1-Basis) | `eng` | `po` (Belege), `cra` (Signaltests), `lca` (Repo-Sichtbarkeit, Secrets) | `po`; Founder für Einstellungen | – | B0-1 bis B0-8 (§4) auf einem benannten Commit | **Testfehler offen** | 13 Commits mit wechselndem Ergebnis; #919-Ursache; UX2-23 ohne Issue; #603; kein Schutz, öffentlich; keine lokalen Tests |
| **B1** Anfrage, Fall, Teamentscheid | J1 Anfrage → Fall → Matching, J2 Teamentscheid, C1 Lebenszyklus, RET1, REF2, J6 Bezugspflege | `eng` | `cra` (Sicherheitshinweise vor Erstkontakt, D-17), `uxa` | `po` | B0 | Ablauf Anfrage bis „Team übernimmt“ inkl. Ablehnung und Rückfrage, e2e auf benanntem Commit | implementiert, nicht ausreichend getestet | keine Blocktestdefinition; Gates im PR nicht nachgewiesen |
| **B2** Qualifikation, Tätigkeitsregeln, Nachweise, Delegation | QUAL1 (Matrix QAM v0.2, Nachweise, Delegation, Prüfung auf jedem Zuteilungsweg), ADM1, ADM2, OBS1 | `eng` | `cra` (QAM), `lca` (Berufsrecht, Delegation), `uxa` | `po`; **Clinical Owner** für die Matrixwerte | B0 | Zuteilung und Start werden bei fehlendem, abgelaufenem oder widersprüchlichem Nachweis, fehlender Delegation und „?“-Zelle verweigert (pgTAP, e2e) | in Arbeit | QUAL1 Teil 2 offen (QUAL1-15, -20, CGR-153 bis -155, UXR-134); alle 115 Matrixzellen PROPOSED |
| **B3** Team- und KI-Einsatzplanung, Ausfallkoordination | J3, PLAN2, PLAN3 (Tagesvorschlag), ABS1, COVER1, VIS2, OPS1, AIG1 (Ledger, Bestätigung je Wert) | `eng` | `cra`, `aia`, `uxa` | `po` | B0, B2 | Vorschlag → Teamentscheid; Ausfall → Vertretung oder sichtbar „nicht besetzbar“ | implementiert, nicht ausreichend getestet | QUAL1-Anbindung an PLAN3 offen; 10 PRs ohne integrierten Nachweis |
| **B4** Mobile Besuchsausführung, Zeit und Leistung | F1-F4, VIS1, DOOR1, CSR1, WORK1, UX1, UX2 (eine App) | `eng` | `uxa`, `cra` | `po` | B0, B2, B3 | Besuch planen → losfahren → starten → erfassen → beenden auf 390 px; Zeitkorrektur; Arbeitstag | in Arbeit | UX2-Rest (M2); e2e-Flakes VIS1, F1 |
| **B5** Sicherheitssignale und Eskalation | SIG1, SIG2, SIGC, DST1, FUP1, Signalteile von LEAVE1/COND1/DOOR1 | `eng` | `cra` | `po`; Clinical Owner für Prioritäten und Fristen | B0 | P1 erreicht eine zuständige Person, eskaliert nachweislich; deterministisch | **Testfehler offen** | #919-Ursache nicht reproduziert (B0-4); 062/078/080-Familie |
| **B6** Diktat, KI-Dokumentation, menschliche Freigabe | F6, F6R, F7 (Bericht, Rückgabe, Unterschrift), HAND1, AIR1; Diktat und KI-Entwurf (DOC-AI, AUT-54) | `eng`, `aia` | `cra`, `lca` (D-35/D-41), `uxa` | `po`; Founder (KI-Pfad, E-3) | B0, B4 | Eingabe → Entwurf → Prüfung → Freigabe durch Teammitglied; nichts ohne Mensch | in Arbeit | Diktat und KI-Entwurf nicht gebaut; Phase-A-Pfad offen (E-3) |
| **B7** Assessment, Pflegeplanung, ärztliche Anordnung | ASM1 inkl. C6/C7, Pflegeplan-Bezug, ORD0, ORD1, QG1; Heim-Assessment (NH-A2) | `eng` | `cra`, `lca` (D-22, D-37) | `po`; Clinical Owner | B0, B2 | Abklärung → Pflegeplan → Besuche; Korrektur und Storno ohne Datenverlust | Fach-/Legal-Gate offen | ASM1-C7; ORD1 Entwurf (D-22); interRAI (D-37); NH-A2 nicht gebaut |
| **B8** Abrechnung, Validierung, Fehlerfälle | J5 (abrechenbare Fakten), BILL1 (Rechnungsentwurf, Validierung, Doppelabrechnung, Zeitkonflikte), J7 | `eng` | `lca` (D-18, D-22, Tarif), `cra` | `po`; Founder (Tarif- und Vertragsfragen) | B0, B4, B7 | geprüfter Rechnungsentwurf oder sichtbar eskalierter Fehler | in Arbeit | BILL1 nicht gebaut; D-18/D-22 offen |
| **B9** Simulierter Pflegeheim-Betrieb | NH-A1 Schichten, NH-A2 Aufnahme, NH-A3 Übergabe, NH-A4 Ausfall, NH-A5 Abrechnung je Bewohnertag | `eng` | `cra`, `lca`, `uxa` | `po`; Clinical Owner vor Phase B | B0, B2, B3, B5 | 24-h-Tag einer Abteilung ohne Dienstplanerin, Lücken sichtbar | in Arbeit (nur Brief NH-A1) | NH-A1 Gate (c) `lca`; NH-A2 bis A5 ohne Brief |
| **B10** Kennzahlen und Wirkungsmessung | AN1, AN2, AN3 | `eng` | `lca` (D-23), `cra` | `po` | B0, B4 | Messwerte je Team und Monat aus Ereignissen, nie je Person | implementiert, nicht ausreichend getestet | AN3-Status widersprüchlich; AN3-C1 bis -C3 |
| **B11** Integration, Staging, Wiederherstellung, Phase-A-Gesamttest | Staging (D-2), Seed nur synthetisch, Backup und Wiederherstellung, zwei durchgängige Simulationsabläufe mit Stoppfällen (§5) | `eng` | alle Rollen je Schritt | `po`; Founder bewertet Phase A | B0 bis B10 | Protokoll beider Abläufe auf einem benannten Commit, Wiederherstellung belegt | nicht begonnen | Host-Wahl D-2; Restore nie getestet |
| **B12** Voraussetzungen Phase B | Clinical Owner (G-1, D-43), Rechtsberatung (FE-050), Pilotvertrag (D-42, D-44), D-1/D-29, externer Sicherheitstest (FE-049), Repo privat (D-7 Stufe 4), KI-Pfad (D-41), Produktion | `po` koordiniert; Founder | `lca`, `cra` | **Founder** | B11 bestanden | jede Voraussetzung mit Entscheid oder Vertrag belegt | nicht begonnen | alles offen; Q1 2027 Rechtsberatung |

**Regeln:**

- Jeder PR und jedes Issue nennt ab sofort in der ersten Zeile `Block: B<n>`.
- Ein PR, der mehrere Blöcke berührt, nennt den führenden Block und die weiteren.
- Die Zuordnung der bisherigen PRs und Issues steht in der Inventur. Sie wurde automatisch aus den Brief-Kürzeln erzeugt und wird in der Blockprüfung bestätigt.

---

## 3. Was vor jeder Blockabnahme vorliegen muss

Jede Blockabnahme ist ein Abschnitt dieser Datei mit genau diesen Teilen. Fehlt ein Teil, ist der Block nicht abgenommen.

1. **Zweck und Umfang**, inklusive der Items und dessen, was ausdrücklich nicht dazugehört.
2. **Akzeptanzkriterien**, nummeriert (B<n>-1 …), jedes prüfbar.
3. **Testfälle**, positiv **und** negativ, je Kriterium, einschliesslich der Fälle, in denen NAVORA nicht weitermachen darf.
4. **Testarten:**
   - Unit (vitest);
   - Datenbank (pgTAP, inklusive RLS und Rechte);
   - Integration (Ablauf über mehrere Funktionen oder Tabellen);
   - Ende-zu-Ende (Playwright auf 390 px und Desktop).

   Entfällt eine Testart, steht die Begründung daneben.
5. **Ergebnisse auf einem benannten Commit des integrierten Stands** (`recovery/main` oder ein Kandidaten-Commit, der darauf aufsetzt), mit Lauf-IDs.
   - **Stabilitätsregel:** Ein Test, der klinische Gate-Bedingungen belegt, zählt erst als bestanden, wenn er auf diesem Commit **10 von 10 Wiederholungen** besteht oder die Ursache eines früheren Ausfalls reproduziert und behoben ist.
6. **Gates:** `cra`, `lca` und `uxa`, soweit der Block sie braucht, **für genau diesen Commit**. Eine fehlende Freigabe des Clinical Owners steht als „klinische Freigabe: nicht erteilt“ da.
7. **Bekannte Einschränkungen und offene Fehler**, mit Issue-Nummern.
8. **Entscheidung:** `abgenommen` oder `nicht abgenommen`, mit Begründung, Datum und Name der entscheidenden Rolle.

**Testfähigkeit:** Ist ein nötiger Test mangels Infrastruktur nicht ausführbar, ist der Block **nicht abgenommen**. Die fehlende Testfähigkeit wird als Blocker in B0 oder B11 geführt.

---

## 4. Erster Block: B0 Technische Basis und Datenbank-Sicherheit

**Warum zuerst:** Jede andere Abnahme stützt sich auf CI-Ergebnisse. Heute kann derselbe Commit grün und rot sein, Merge-Commits bleiben ungetestet, Agenten können nicht lokal testen, und das Repository ist ungeschützt. Solange das gilt, wäre jede fachliche Abnahme auf Sand gebaut.

**Zweck:** Ein Testergebnis auf einem benannten Commit ist wiederholbar und vertrauenswürdig, und der Integrationsstand ist gegen unbeabsichtigte Änderungen geschützt.

**Umfang:** CI, Testdeterminismus, lokale Testfähigkeit, Repository-Schutz Stufe 1, Datenbank-Rechte und -Sicherheit, Migrationsreihenfolge. **Nicht dazu gehören:** Staging, Wiederherstellung und externer Test (B11, B12) sowie neue Features.

| Kriterium | Inhalt | Testfälle (positiv / negativ) | Testart | liefert | prüft | Stand |
|---|---|---|---|---|---|---|
| **B0-1** Jeder Merge-Commit wird vollständig getestet | `recovery/main`-Läufe brechen nicht ab (`cancel-in-progress` nur für PR-Branches); jeder Merge-Commit hat einen vollständigen Lauf | + 3 schnelle Merges hintereinander, jeder Merge-Commit grün / − ein absichtlich roter Test auf einem Branch wird auf dem Merge-Commit rot gemeldet | CI-Konfiguration, Nachweis über die API | `eng` | `po` | offen |
| **B0-2** Wiederholbarkeit | Eine Wiederholungsprüfung (`workflow_dispatch`, N Läufe auf einem Commit) für `db` und `e2e`; auf dem B0-Kandidaten 10 von 10 grün | + 10/10 grün / − jeder Ausfall wird mit Datei und Test benannt und ist ein offener Fehler | pgTAP, Playwright | `eng` | `po` | offen |
| **B0-3** Bekannte Flakes behoben, mit Ursache | UX2-23 Vertragsende (e2e, #979), pgTAP 079 (#603), 098, VIS1 und F1 e2e: Ursache benannt, behoben, B0-2 bestanden | + Ursache reproduziert, dann behoben / − ohne Reproduktion bleibt der Test als „Testfehler offen“ geführt | je nach Test | `eng` | `cra` (F1-Gegenzeichnung, Vertragsende = Zugangsende) | offen |
| **B0-4** #919 / 080 belegt | Der Lock-Wettlauf wird **reproduziert** (zweite Session hält den SIG1-Lock während `eval()`): auf dem Stand vor #922 rot, auf dem heutigen grün; 062, 078, 080 zusätzlich unter erzwungenem Cron-Lauf | + reproduziert und grün / − nicht reproduzierbar: Ursache bleibt UNKNOWN, `cra`-Leseregel gilt weiter, B5 bleibt „Testfehler offen“ | pgTAP, Nebenläufigkeitsskript (`scripts/db-concurrency/`) | `eng` | `cra` (Assertions unverändert) | offen |
| **B0-5** Lokale Testfähigkeit | Engineering führt `npm ci`, Lint, Typecheck, vitest, Build, pgTAP und e2e in der eigenen Sitzung aus und protokolliert sie mit Commit. Alternativ ist eine gleichwertige, dokumentierte Umgebung eingerichtet | + Protokoll mit Commit und Ergebnissen / − ohne Netz oder Docker: bleibt Blocker | alle | `eng`; Founder (Einstellung, E-1) | `po` | **blockiert** (Registry, Docker) |
| **B0-6** Repository-Schutz Stufe 1 | Ruleset auf `recovery/main`: die vier Checks sind Pflicht, kein Force-Push, kein Löschen; Secret Scanning und Push Protection an (FE-045) | + API zeigt Ruleset und Scanning / − ein Push ohne PR wird abgewiesen (Testbranch-Nachweis) | API-Abfrage | Founder (Klicks), `eng` (Klickpfad) | `lca` (Secrets, Sichtbarkeit) | offen |
| **B0-7** Datenbank-Rechte | Keine Tabelle ohne RLS; kein `anon`-Grant; jede SECURITY-DEFINER-Funktion mit `search_path = ''` und von `public` entzogen. Ein pgTAP-Katalogtest prüft das über **alle** Migrationen | + Katalogtest grün / − eine absichtlich falsche Testmigration auf einem Branch macht ihn rot | pgTAP | `eng` | `po`; `lca` (Datenschutz) | teilweise vorhanden: pgTAP 067:370-372 prüft, dass jede für `authenticated` lesbare Tabelle RLS hat; `anon`-Grants und `search_path` der SECURITY-DEFINER-Funktionen sind nicht als Katalogtest gefunden (PO-Suche in `supabase/tests`, 07.11.) |
| **B0-8** Migrationsreihenfolge | Ein Prüfskript stellt fest, dass Migrationen auf leerer und auf bestehender Datenbank in derselben Reihenfolge laufen (z. B. 0106 nach 0122 gemergt) | + Skript grün / − eine nachträglich eingefügte niedrige Nummer wird gemeldet | Skript in CI | `eng` | `po` | offen |

**Gates:** `cra` nur für B0-3 und B0-4 (klinische Assertions unverändert), `lca` für B0-6 und B0-7. UX entfällt, weil B0 keine Nutzeroberfläche ändert.

**Bekannte Einschränkungen:**

- Repository-Stufen 2 bis 4 (privat, getrennte Agentenidentitäten) sind nicht Teil von B0, sondern B12 vor echten Daten.
- MERGE1 (Journal je Datei) gehört nicht zu B0, senkt aber Konflikte und Merge-Rennen. Es läuft mit B0, ist aber kein Kriterium.

**Entscheidung heute:** **nicht abgenommen**, Zustand *Testfehler offen*.

**Ziel:** abnahmebereit bis **2026-11-20**, wenn E-1 bis 2026-11-11 umgesetzt ist. Ohne E-1 bleibt B0-5 offen, und B0 kann nicht abgenommen werden.

---

## 5. Phase A: zwei durchgängige Abläufe statt einer PR-Sammlung

**Phase A ist bestanden**, wenn beide Abläufe mit ausschliesslich neu erzeugten synthetischen Daten auf einem benannten Commit im Staging (B11) vollständig laufen und protokolliert sind. Die Stoppfälle müssen dabei nachweislich stoppen. Alle beteiligten Blöcke müssen abgenommen sein. **Phase A ist keine Freigabe für echte Personen oder Daten.**

| Schritt | ambulant (Spitex-Team) | Pflegeheim-Abteilung (simuliert) | Block |
|---|---|---|---|
| 1 Anfrage | Zuweisung → Fall → Matching (J1) | Aufnahme einer Bewohnerin (NH-A2) | B1, B9 |
| 2 Tätigkeiten, Qualifikation, Delegation | QUAL1-Prüfung je Tätigkeit | dieselbe Prüfung je Schicht (NH-A2) | B2 |
| 3 KI-Planung oder Ausfallkoordination | PLAN3-Tagesvorschlag; ABS1/COVER1 | Kontinuitäts-Default, Lückenliste (NH-A1), Ausfall (NH-A4) | B3, B9 |
| 4 Entscheid des Teams | Team bestätigt je Wert (AIG1) | Mitglied setzt *zuständig* | B3, B9 |
| 5 Einsatz und Zeiterfassung | Losfahren, Start, Ende (F1-F4, VIS1), Arbeitstag (WORK1) | Schicht, Pflegekontakte | B4, B9 |
| 6 Diktat oder strukturierte Eingabe | Beobachtung, Diktat | dasselbe je Schicht | B6 |
| 7 KI-Dokumentationsentwurf | Entwurf (Pfad nach E-3) | dasselbe | B6 |
| 8 Prüfung und Freigabe durch ein Teammitglied | Bericht, Rückgabe, Unterschrift (F6, F6R, F7) | dasselbe | B6 |
| 9 Rechnungsentwurf oder Fehler | geprüfter Entwurf nach KVG/KLV-Zeiten (BILL1) oder eskalierter Fehler | Bewohnertag (NH-A5) | B8, B9 |

**Stoppfälle (NAVORA darf nicht weitermachen).** Die Spalte „heute“ ist aus dem Code gelesen und nicht als Block getestet:

| Fall | erwartetes Verhalten | Block | heute |
|---|---|---|---|
| keine geeignete Vertretung | Besuch bleibt sichtbar „nicht besetzbar“, eine Person im Team ist benachrichtigt, nichts wird stillschweigend verschoben | B3 | IMPLEMENTED in Teilen (#902 CGR-75 (5), COVER1); Benachrichtigung UNKNOWN |
| fehlender oder abgelaufener Nachweis | Zuteilung und Start verweigert mit Grund | B2 | IMPLEMENTED in der Simulation (`qual_check`: `evidence_missing`, `evidence_expired`, `evidence_contradictory`; Migration 0120/0121) |
| fehlende Delegation | verweigert (`delegation_missing`, `delegation_expired`) | B2 | IMPLEMENTED in der Simulation (0120: `qual_delegations`) |
| ungeklärte klinische Regel (Zelle „?“) | verweigert als `unresolved`, sichtbar „ungeklärt“; nie als erlaubt gewertet | B2 | IMPLEMENTED (`unresolved` in 0120); Anzeige zu prüfen |
| widersprüchliche Zeiten | Überschneidung als Fakt vor dem Speichern (VIS2), Zeitkorrektur begründet (F3); in der Abrechnung: Fehler statt Rechnung | B4, B8 | IMPLEMENTED für Besuche; Abrechnungsteil PLANNED (BILL1) |
| mögliche Doppelabrechnung | Rechnungsentwurf gestoppt, Fehler sichtbar eskaliert | B8 | **PLANNED** (BILL1 nicht gebaut) |
| Sicherheitssignal ohne Reaktion | Eskalation an die nächste zuständige Person | B5 | IMPLEMENTED; Test 080 siehe B0-4 |
| KI-Vorschlag ohne menschliche Bestätigung | nichts wird wirksam | B3, B6 | IMPLEMENTED für AIG1-Vorschläge; Doku-Entwurf PLANNED |

---

## 6. Realistischer Weg zu Phase A und Phase B

Die Daten sind Ziele mit den genannten Annahmen, keine Zusagen. Ein Block gilt erst, wenn er abgenommen ist.

| Schritt | Inhalt | abhängig von | Ziel |
|---|---|---|---|
| 1 | **B0** abnahmebereit, dann abgenommen | E-1, Owner-Klicks D-7 Stufe 1 | 2026-11-20 |
| 2 | **B11 Teil 1:** Staging mit neu erzeugten synthetischen Daten, Backup, **Wiederherstellungstest** | D-2 Host-Wahl (Angebote `eng`), Founder | 2026-12-04 |
| 3 | **Re-Verifikation der implementierten Blöcke** B1, B3, B4, B5, B10 in dieser Reihenfolge: Blocktests schreiben, Lücken schliessen, abnehmen. Höchstens ein Block gleichzeitig in Abnahme | B0, Schritt 2 für e2e im Staging | bis 2026-12-18 |
| 4 | **B2** QUAL1 fertig, **B7** ASM1-C7 und Assessment-Teil, **B6** Eingabe, Entwurf und Freigabe (Pfad E-3) | B0; `cra`, `lca` | bis 2027-01-22 |
| 5 | **B8** BILL1 mit Validierung, Doppelabrechnung und Zeitkonflikten (synthetisch, Option A) | B4, B7; D-18/D-22 für die Regeln | bis 2027-02-05 |
| 6 | **B9** NH-A1 bis NH-A5 | B2, B3, B5; Briefs NH-A2 bis A5 | bis 2027-02-19 |
| 7 | **B11 Teil 2:** zwei Simulationsabläufe mit allen Stoppfällen, Protokoll | alle Blöcke abgenommen | bis 2027-03-05 |
| 8 | **Phase A bewertet** durch den Founder | Schritt 7 | M9, 2027-03-12 |
| 9 | **B12:** Clinical Owner ernannt, Regeln freigegeben; Rechtsberatung beantwortet (FE-050); Pilotvertrag; Repo privat; externer Sicherheitstest; Produktion | Phase A, Founder | frühestens Q2 2027 |

**Ehrliche Einschätzung:** M9 am 2027-03-12 ist **erreichbar, wenn B0 bis 20.11. und Staging bis Anfang Dezember stehen**. Das Risiko ist hoch, denn B8 und B9 sind noch nicht gebaut, und NH-A2 bis A5 haben keine Briefs. Die erste ehrliche Neubewertung kommt nach der B0-Abnahme. Verschiebt sich B0 um eine Woche, verschiebt sich M9 voraussichtlich mit. Phase B beginnt nicht vor bestandener Phase A und nicht vor dem Clinical Owner.

---

## 7. Entscheidungen, die der Founder treffen muss

| ID | Frage | Optionen | Auswirkungen | Empfehlung |
|---|---|---|---|---|
| **E-1** | Wie wird lokale Testfähigkeit hergestellt? | (A) In den Netzwerk-Einstellungen der Agenten-Umgebung `registry.npmjs.org` zulassen (FE-047 erlaubt das bereits) und einen Docker-fähigen Lauf ermöglichen. (B) Eine eigene Testumgebung ausserhalb der Agenten-Sitzungen (z. B. GitHub Codespace oder ein eigener Runner), deren Protokolle `eng` liest. (C) Nur CI, ergänzt um die Wiederholungsprüfung B0-2 | A: schnellste Fehlersuche, Engineering kann reproduzieren (B0-4); Netz bleibt auf die Registry beschränkt. B: mehr Aufwand, Protokolle indirekt. C: B0-5 bleibt unerfüllt, B0 ist nach Ihrer Regel nicht abnehmbar | **A**, ergänzt um B0-2. Wenn Docker in der Agenten-Umgebung nicht möglich ist: A für npm plus B für Datenbank und e2e |
| **E-2** | Wie laufen die geplanten Agenten-Aufgaben während der Neuordnung? | (A) Weiterlaufen. FE-052 ist durch Regel 10 bindend und stoppt Feature-Merges; Sie passen die Prompts in einer Woche mit dem Text des PO an. (B) Engineering- und PO-Aufgaben pausieren, bis B0 abgenommen ist. (C) Sofort Prompts anpassen | A: Konzept-, Fach- und B0-Arbeit läuft weiter; Restrisiko, dass ein Lauf ältere Prompt-Schritte ausführt (Merge je Lauf). B: keine Arbeit an B0 ohne Sie. C: sauber, braucht Ihre Zeit jetzt | **A und C zusammen:** weiterlaufen lassen und die vier Prompt-Änderungen aus §8 diese Woche übernehmen |
| **E-3** | Wie wird der Schritt „KI-Dokumentationsentwurf“ in Phase A nachgewiesen? | (A) Regelbasierter Entwurf aus strukturierter Eingabe ohne Sprachmodell (FE-051 Muster 3). (B) Sprachmodell **nur auf synthetischen Daten** in der Simulationsorganisation, Anbieter in CH/EU, vorher `lca`-Prüfung. (C) Eigenes Modell (FE-051 Muster 4) bereits in Phase A | A: kein Datenschutzrisiko, beweist aber keinen KI-Mehrwert. B: zeigt den Ablauf realistisch, Regel A bleibt für echte Daten unberührt; braucht Anbieter und Vertragsprüfung. C: hoher Aufwand vor dem Nachweis | **B, mit A als Rückfallebene**, falls `lca` den Anbieter bis 2027-01-08 nicht klärt. Konfidenz mittel |
| **E-4** | Gilt M9 (2027-03-12) weiter als Zieltermin für die Phase-A-Bewertung? | (A) Ja, mit Neubewertung nach der B0-Abnahme. (B) Jetzt auf Ende April verschieben | A: der Termin bleibt Steuerungsgrösse, wird aber an Belege geknüpft. B: weniger Druck, aber ohne Datengrundlage | **A** |

Andere offene Pakete (D-22, D-18, D-43, D-2, D-41 …) laufen weiter über `DECISION_PACKAGES.md` und sind in dieser Liste bewusst nicht wiederholt.

---

## 8. Ab sofort für alle Rollen

1. **Merge-Freeze (FE-052):**
   - keine Engineering-Feature-PRs nach `recovery/main`, bis B0 abgenommen ist;
   - eine einzelne Sicherheitskorrektur nur nach dokumentierter Risikoprüfung (PR-Kommentar: Risiko, Test, warum nicht warten) und PO-Entscheid;
   - Doku-, Rollen- und PO-PRs gehen weiter unter `PO_MERGE_PROCESS.md` §4;
   - B0-Arbeit von `eng` wird einzeln gemergt, sobald ihre Belege vorliegen.
2. **Jeder PR und jedes Issue nennt den Block** (`Block: B<n>`).
3. **Issues werden nur mit Nachweis geschlossen:** Anforderung, PR oder Commit, Test und Lauf-ID auf dem integrierten Stand. Ein gemergter PR allein schliesst kein Issue.
4. **Berichte zeigen Blockzustände**, nicht die Zahl der Merges. Der PO führt §2 und schreibt jede Abnahme als Abschnitt nach §3.
5. **Rollen-Schwerpunkte bis zur B0-Abnahme:**
   - `eng`: B0-1 bis B0-8, in dieser Reihenfolge, je Kriterium ein PR;
   - `cra`: B0-3 und B0-4 lesen, dann Blocktestfälle für B5 und B2 vorbereiten;
   - `lca`: B0-6 und B0-7; NH-A1 Gate (c); E-3 Anbieterfrage;
   - `uxa`: Blocktestfälle der Nutzerabläufe für B1 und B4;
   - `aia` und `csa`: Konzeptarbeit parallel, kein Merge von Code.
6. **Prompt-Änderungen für die geplanten Aufgaben** (macht der Founder; der PO ändert keine Aufgaben):
   - (a) **PO:** Schritt A wird: „Merge nur nach FE-052: Feature-PRs erst nach B0-Abnahme; Doku- und Rollen-PRs wie bisher“. Schritt C prüft nur Blockabnahmen nach `PRODUCT_BLOCKS.md` §3, nicht „accepted“ je PR.
   - (b) **eng:** Arbeitsreihenfolge B0-1 bis B0-8; jeder PR und jedes Issue mit `Block:`; lokale Testprotokolle mit Commit.
   - (c) **cra, lca, uxa:** Gate-Zeile immer mit dem gemergten Commit; Prüfungen je Block statt je PR, wo der PO es verlangt.
   - (d) **alle:** die „PLAN3 stack #891 to #910“-Zeile im PO-Prompt ist verbraucht (FE-041).

---

## 9. Änderungsprotokoll

- **2026-11-07 19:40, Fassung 1** (`po`, live mit dem Founder): erstellt nach FE-052, mit Bestandsaufnahme (Inventur-Datei), Blockmatrix, B0-Kriterien, Phase-A-Abläufen, Weg zu Phase A/B und E-1 bis E-4.
