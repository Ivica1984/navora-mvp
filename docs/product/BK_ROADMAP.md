# BK-Roadmap: vom Pflegeauftrag bis zur Rechnung

**Besitzer:** Product Owner (`po`) · **Version:** 3, 2026-11-27 15:39 (Europe/Zurich) (~~2, 2026-11-18 16:20~~; ~~1, 2026-11-17 17:15~~) · **Auftrag:** FE-088 (6), FE-090, FE-091, FE-137 (4) · **Founder-Übersicht:** `FOUNDER_STAGING_UEBERSICHT.md` · **Quellen:** Brief `docs/agents/briefs/BK.md`, Blueprint V3.2 §8, `FOUNDER_DECISIONS.md` FE-085, FE-087, FE-088 · **Kennzeichnung:** IMPLEMENTED, PLANNED, OPEN, UNKNOWN. Termine sind Schätzungen des PO, keine Zusagen. Der PO hat keine Tests ausgeführt.

## 00. Stand und Entscheid 2026-11-27 15:39 (FE-137 (4); gilt vor §0 bis §9, die den Verlauf vom 17./18.11. zeigen)

**Fünf Zeilen für den Founder:**
- **JETZT:** Block HEIM-DP, Paket HD-3s-F2-F1 (#1825, Entwurf): die Teamleitung kann keinen Fallbesuch mehr in die Pause eines geteilten Heimdiensts legen; NAVORA lehnt mit Nennung der Übernahme ab (feste Regel, keine KI).
- **BEREIT:** auf Staging seit 20.11. neu bedienbar (synthetisch, Pfade 1–9 automatisch grün, `staging-smoke` 45960192885): Rechnungsentwurf (BK-f), Heim-Woche, -Monat und Plan je Person, Lücke → externer Auftrag → «Gedeckt», Planvorschlag mit festen Regeln, geteilter Dienst, ein Auftrag für beide Blöcke.
- **BLOCKIERT:** keine Frage an den PO offen (Pfad 10 am 27.11. 15:39 entschieden: bekannte Grenze, Folgepunkt STG-P10).
- **ENTSCHEID:** keiner zwingend; optional ein synthetischer Fall in Testteam Basel (Pfad 10) und Bestätigung oder Änderung der BK-d/BK-g-Stelle unten.
- **DANACH:** HD-3a-F1 (Pensum und Wochensoll beim «übernehmen» in der Datenbank geprüft), dann HD-3a-F3 (Monatssoll); beide vertragsbereit.

**Stand BK (IMPLEMENTED, abgenommen für die Simulation, `ABNAHMEAKTE.md` §2):** BK-a (14.11.), BK-b (17.11.), BK-c (18.11.), BK-e (20.11., Berichtsentwurf als Testersatz «regelbasiert, keine KI»), BK-f (20.11. auf `40a2ce1`). **Nicht begonnen (PLANNED):** BK-d (Auftrag aus Text oder Diktat mit KI, Bestätigung durch die Auftraggeberin), BK-g (Szenario-Matrix, ganzer Durchlauf e2e). Die Fenster aus §3 (BK-d «ca. 27.11.», BK-g «1.–2.12.») sind **verpasst**: Seit FE-109 (20.11.) ist HEIM-DP der aktive Block, und die Paketfolge FE-127 enthält BK-d und BK-g nicht.

**Entscheid PO (WANN, Wertordnung und Blockregel; der Founder kann ändern):** BK-d und BK-g sind **förmlich zurückgestellt** und stehen **direkt nach dem Ende der HEIM-DP-Folge** (nach HD-3d) als nächster Block «BK-Abschluss»: zuerst BK-d, dann BK-g. Gründe: (1) Die Paketfolge HEIM-DP ist ein Founder-Entscheid (FE-109, FE-127); der PO schiebt keinen anderen Block dazwischen (README-Regel 12). (2) BK-d braucht ein angeschlossenes Modell: AI1-F1 und AI1 Schritt (b) mit den Render-Werten des Founders (Brief `AI1.md` §2–3). Dieselbe Voraussetzung haben die KI-Pakete in HEIM-DP (INTAKE-E2E-Extraktion, HD-3c); der PO setzt deshalb **AI1-F1 vor das erste Paket, das ein angeschlossenes Modell braucht** (frühestens INTAKE-E2E), damit BK-d danach den geprüften Weg wiederverwendet. (3) BK-g prüft den ganzen BK-Ablauf und braucht BK-d. (4) BK-a bis BK-f sind abgenommen und laufen auf Staging (Pfad 3); der Rückstand ist Abschluss und Nachweis, keine Lücke im bedienbaren Ablauf.

**Vorschlag an den Founder (nicht entschieden):** BK-d direkt nach INTAKE-E2E statt nach HD-3d, weil beide «Freitext → geprüfte Felder → Bestätigung durch einen Menschen» sind; das zöge die erste echte KI-Demo für Auftraggeber um etwa zwei Pakete vor. Das ändert die Founder-Folge FE-127 und braucht ein Wort des Founders.

**Neue Zeitfenster (Schätzung PO, niedrige Sicherheit, keine Zusage):**

| Schritt | Fenster | Annahme |
|---|---|---|
| HD-3s-F2-F1 → HD-3a-F1 → HD-3a-F3 → HD-3b-0 → HD-3b | bis ca. KW 51 (18.12.) | 0,5 bis 2 Arbeitstage je Paket (Tempo KW 48, `eng` Wochenstatus); keine blockierende Klinik- oder Rechtsfrage |
| AI1-F1, AI1 Schritt (b), INTAKE-E2E, HD-3c, HD-3d | KW 51 bis KW 2 (bis ca. 15.1.2027) | grössere Pakete mit Modell; Feiertage; Render-Werte des Founders rechtzeitig |
| **BK-d** (mit Modell, nur synthetische Daten, D-35 A) | **KW 2 bis KW 3 (11.–22.1.2027)** | AI1 Schritt (b) abgenommen |
| **BK-g** (ganzer Durchlauf e2e, Szenario-Matrix) | **KW 3 bis KW 4 (18.–29.1.2027)** | BK-d abgenommen |
| M9 Phase A (Blueprint §10) | 2027-03-12 | **UNKNOWN**, ob gehalten: nach BK-g bleiben rund sechs Wochen für B11 (Gesamttest beider Abläufe); für B2-Kern bis B10 gibt es keine Schätzung |

**Was diese Datei nicht mehr ist:** §1 bis §9 beschreiben den Stand vom 17./18.11. (BK aktiv). Den aktuellen Staging-Stand führt `FOUNDER_STAGING_UEBERSICHT.md`, den Wochenstand `FOUNDER_EXECUTIVE_REPORT.md`, die Reihenfolge *Active now* in `NEXT_CAPABILITY.md` und Blueprint §8.

## 0. Kurzfassung (Verlauf, Stand 18.11.)

- **Freitag 20.11., realistische Reichweite (PLANNED):** «Pflegeauftrag erfassen bis Teamzusage». Die Auftraggeberin erfasst einen Schichtauftrag. Das Team sieht ihn und übernimmt. Die benannte Pflegekraft bestätigt oder sagt «Ich kann nicht». Die Auftraggeberin sieht «Gedeckt» oder «Noch nicht gedeckt». Alles in der echten Staging-Anwendung, mit synthetischen Daten. Das ist **kein** fertiger BK-Durchstich und **kein** Pilot.
- **KI bis Freitag:** keine. Die Abgleichsregeln (PLZ, Qualifikation, Verfügbarkeit) sind feste Regeln. Die Rangfolge (BK-c3) ist frühestens Freitag als **regelbasierte** Rangfolge mit Begründung da.
- **Echtes KI-Modell:** kein Termin möglich. Es fehlt die Wahl des Anbieters durch den Owner (FE-085 (4), Vermerk (d)). Dazu müssen `lca` die Bedingungen lesen und die Schutzregeln AUT-136 stehen.

## 1. Was heute auf Staging läuft (festgestellt 2026-11-17 ca. 17:10)

| Prüfpunkt | Stand | Nachweis |
|---|---|---|
| App-Commit auf Render `navora-staging` | `13c6d68` (= `recovery/main`), Deploy `dep-dbu7in3rjlhs73bhc1m0` live | Render-API, nur lesend |
| Datenbank `navora-staging` | Migrationen bis **0135** `bk_c1_take_cover_state` plus `stg1_bootstrap_deploy_helper`; **0136 nicht eingespielt** | Supabase `list_migrations`, nur lesend |
| Anmeldung und Bedienung im Browser | **UNKNOWN** für den PO (Adresse aus der PO-Sitzung gesperrt). Kein automatischer Test gegen Staging. | – |

**Bedienbar laut Code (IMPLEMENTED; im Browser auf Staging nicht nachgewiesen):**
- `/order`: Schichtauftrag erfassen, Zusammenfassung, einmal absenden (BK-a).
- Team: Einsatzgebiet und Höchstdistanz festlegen (BK-b1s). Feste Abgleichsregeln für Reichweite, Qualifikation und Verfügbarkeit (BK-b).
- Datenbank für Übernahme und Deckungsstand (BK-c1), **noch ohne Bildschirme**.

**Nicht bedienbar:** Übernahme, «Bestätigen» und «Ich kann nicht» auf `/team`, Kundenstatus «Gedeckt» (#1358, nicht gemergt), Rangfolge, KI-Erfassung, Berichtsentwurf, Rechnung.

**Vorschlag an `eng` (Nachweis statt «Render ist bereit»):** Nach jedem Deploy prüft ein CI-Schritt Commit und höchste Migration von Staging und führt einen kurzen Playwright-Klickpfad gegen `navora-staging.onrender.com` aus. Das Ergebnis steht in der PR- oder Merge-Notiz.

## 1a. Staging-Stand 2026-11-18 16:20 (FE-090 (1), FE-091 (1); aktueller Stand, §1 ist Verlauf)

| Prüfpunkt | Stand | Nachweis |
|---|---|---|
| Automatisches Einspielen | **IMPLEMENTED seit heute:** Secret `STAGING_DB_URL` vom Founder gesetzt (FE-089); jeder Push auf `recovery/main` spielt nach grünen Pflichtjobs die Migrationen auf `navora-staging` ein (ADR-190); auf einem PR nur Probelauf | `ci.yml` Job `staging` |
| Datenbank `navora-staging` | **bis 0137 = `recovery/main`.** 0136 und 0137 eingespielt am 18.11. um 15:47 durch den `staging`-Job des Pushes `e6ac4f2`. 0138–0148 kommen erst mit #1421 | Job 134884613655 «Applying migration …0136 … 0137 … Finished» (vom PO gelesen); Migrationsliste lesend (PO 16:00) |
| App-Commit auf Render | `e6ac4f2` live (Deploy 14:38 UTC), danach nur Dokumenten-Commits | Render, lesend (PO 16:00) |
| Klickpfad «Auftrag → Angebot beim Team → Übernahme → Status beim Auftraggeber» auf Staging | **nicht ausgeführt (UNKNOWN)**; im Code IMPLEMENTED und in CI grün (`bk-c2-take-status.spec.ts`); Anleitung in `FOUNDER_STAGING_UEBERSICHT.md` | `eng` prüft auf Staging (#1465) |

## 2. Stand im Code

| Teilschritt | Inhalt | Code | Staging-DB | Abnahme |
|---|---|---|---|---|
| BK-a | Auftrag erfassen (ohne KI) | gemergt (#1238 u. a.) | ja | abgenommen 14.11. (Simulation) |
| BK-b | Reichweite, harte Filter | gemergt (#1268, #1270, #1273) | ja | abgenommen 17.11. (Simulation) |
| BK-c1 | Übernahme, Deckungsstand (DB) | gemergt `781944f` | ja (0135) | abgenommen 18.11. 02:39 (Simulation, BK-c als Ganzes auf `d51d1c1`) |
| BK-c2 | Bildschirme `/team` und Kundenstatus | **gemergt** `25d7cdf` (#1358, Kopf `9a7fc56`; `lca`, `cra`, `uxa` frei) | **0136 fehlt** (`eng` spielt ein, FE-088 (7)) | abgenommen 18.11. 02:39 (Simulation, mit BK-c) |
| BK-c3 | Begründung je eigenem Team (Reihenfolge nach Beginn, keine Rangfolge zwischen Teams; PO 17:39) | **gemergt** `ad21dd2` (#1388, Kopf `8744acd`; `cra`, `uxa`, `aia`, `lca` frei; Stand 17.11. 20:52) | **0137 fehlt** (wie 0136; `STAGING_DB_URL` nicht gesetzt) | abgenommen 18.11. 02:39 (Simulation) auf `d51d1c1`: #1403 (pgTAP 147) gemergt, `ci-repeat` 44215240768 20/20, 0 übersprungen |
| BK-e | `/field`-Verknüpfung, Berichtsentwurf aus Text (kein externer KI-Dienst, Testersatz) | **aktiv seit 18.11. 02:39**; ADR und rote Tests zuerst; Zuschnitt ADR-202 (18.11. 03:39): BK-e1a Ortszeile (#1417 **gemergt** 18.11. 04:39, `3d9f1e6`, Merge-CI grün; nicht abgenommen), BK-e1b Einsatz aus der Übernahme (#1421 aus dem Entwurf, kein `cra`-Gate; gebaut CGR-242, CGR-244, UXR-237, UXR-239, CGR-248/UXR-241, UXR-240, CGR-249 mit Deckungs-Eigenschaft (`ccd0f4b`), CGR-250 (Abwesenheit lässt Übernahme-Einsatz unverändert), CGR-251, Liste aller 21 Einsatz-Schreiber (`82e7323`), CGR-246 Hinweis ans Team (`d9f4a4b`), CGR-251-Kontrolle und CGR-252 Prüfspur bei abgelehntem Versuch (`8d4a1ff`); CGR-253/UXR-245 Ausfall-Hinweis ohne «Ich übernehme» und UXR-246 Linkteil (`2346b34`, `cra` 12:27: CGR-253 erfüllt); offen Playwright, CGR-233, dann `cra`-/`uxa`-Gate auf dem Endstand; CGR-254 Voraussetzung vor realen Klientinnen, nicht Bedingung für BK-e1b; CGR-233 gebaut (`883d21c`, Migration 0147), `cra` 13:29 blockierend CGR-255 (Wettlauf-Test erwartet Doppelbelegung); CGR-256 und UXR-247 Folgepunkte; CGR-255 gebaut `592c7ae` (Migration 0148), `cra` 14:27 erfüllt; Playwright und F1–F4 gebaut `2d67323`, `e2e` dort rot (neuer Kartentest); offen grünes `e2e`, Endstand; danach ADR-204 #1460 vor `ci-repeat`), BK-e2a Entwurf und Liste «nicht übernommen» (mit CGR-245; Abhakliste auf der Karte vorgeschlagen), BK-e2b Unterschrift und Kontrollen | – | – |
| BK-f | Rechnungsentwurf an die Auftraggeberin | nicht begonnen | – | – |
| BK-d | KI-Erfassung des Auftrags (Text oder Diktat) | nicht begonnen; AUT-135 darf auf einem Branch vorbereitet werden | – | – |
| BK-g | Szenario-Matrix, ganzer Durchlauf e2e | nicht begonnen | – | – |

## 3. Die Fragen des Founders (Teilschritt, Abhängigkeit, Agent, Gate, Zeitfenster)

| Frage | Teilschritt | Abhängigkeiten | Verantwortlich | Prüf-Gate | Zeitfenster (Schätzung) |
|---|---|---|---|---|---|
| Übernahme und Zusage auf Staging klickbar | BK-c2 (#1358) | `cra`- und `uxa`-Zeile auf `9a7fc56`; danach 0136 auf Staging mit Nachweis | `cra`, `uxa`, `po` (Merge), `eng` (0136) | FE-087 + `PO_MERGE_PROCESS.md` §4 | Merge Di 17.11. abends bis Mi 18.11. vormittags; 0136 im nächsten `eng`-Lauf danach. Risiko: Das Einspielen brauchte zuletzt eine Bestätigung, die ablief (Journal `eng` 15:42). |
| KI-gestützte Rangfolge und Erklärung | BK-c3 | BK-c2 gemergt; ADR | `eng`; `aia`, `cra`, `uxa`, `lca` | Freigabezeilen; danach Abnahme BK-c (`ci-repeat` 10/10) | **Regelbasiert** mit Begründung: **gemergt Di 17.11. 20:52** (`ad21dd2`, IMPLEMENTED, nicht abgenommen). Mit echtem Modell: **nicht schätzbar**, es fehlt die Anbieterwahl. |
| Auftraggeberin strukturiert Text oder Diktat mit KI und bestätigt selbst | BK-d | BK-c, BK-e, BK-f abgenommen (Reihenfolge, §5); Adapter AUT-135; AUT-136 | `eng`, `aia`, `lca`, `uxa` | `aia` (Kontrollschicht), `lca` (Anbieter und Daten) | Mit Testersatz frühestens Ende KW 48 (ca. 27.11.). Mit echtem Modell: **nicht schätzbar**. |
| Pflegekraft prüft KI-Berichtsentwurf aus Diktat und gibt frei | BK-e | BK-c abgenommen; AUT-135 und AUT-136; Unterschrift (vorhanden seit `signed_visit_reports`) | `eng`, `cra` (Geräteklasse G/H), `aia`, `uxa` | `cra`-Gate pflichtig | Mit Testersatz: PR ab Mo 23.11., Merge ca. 24.–25.11. Mit echtem Modell: **nicht schätzbar**. |
| Geprüfter Rechnungsentwurf | BK-f | BK-e; Preismodell des Teams (AUT-119 (b)); `lca` AUT-119 (c) und ArG-Frage | `eng`, `lca`, `csa` | `lca`-Gate | Synthetischer Entwurf ohne Zuschläge, vom Team geprüft: ca. 25.–27.11. Zuschläge erst nach `lca`-Antwort. |
| Alle Schritte zusammen auf Staging | BK-g | alle Teilschritte abgenommen | `eng`, alle Gates | BK-Abnahme auf benanntem Commit | Mit Testersatz: frühestens 1.–2.12. Mit echtem Modell: **nicht schätzbar**. |

Annahmen: `cra` und `uxa` laufen stündlich (FE-088 (1)). Pro Teilschritt ein bis zwei Tage. Keine blockierende Rückfrage zu Klinik oder Recht. Jede davon verschiebt die Termine.

## 4. Echtes Modell, Testersatz oder feste Regel (Stand Phase A)

| Funktion | Heute | Nächste Stufe | Echtes KI-Modell |
|---|---|---|---|
| Abgleich PLZ-Distanz, Qualifikation, Verfügbarkeit (BK-b) | feste Regeln, IMPLEMENTED | bleibt Regel (Sicherheitsgrundsatz) | **nie**; eine KI darf diese Regeln nicht übersteuern |
| Rangfolge unter den Geeigneten und Begründung (BK-c3) | – | Regeln (Distanz, Kontinuität u. a.) mit Begründungssatz | PLANNED nach Anbieterwahl; nur innerhalb der Geeigneten |
| Auftrag aus Text oder Diktat strukturieren (BK-d) | – | Testersatz (feste Antwort), **keine KI-Funktion** | PLANNED nach Anbieterwahl, AUT-136, `lca` |
| Berichtsentwurf aus Diktat (BK-e) | – | Testersatz, **keine KI-Funktion**; Freigabe durch die Pflegekraft | PLANNED nach Anbieterwahl, AUT-136, `cra` |
| Rechnungsentwurf (BK-f) | – | feste Regeln, ohne Zuschläge | nicht vorgesehen |

Regel nach FE-088 (4): Ein Testersatz wird nie als KI-Funktion oder KI-Abnahme ausgewiesen.

## 5. BK-Reihenfolge aus Produktsicht (Prüfung FE-088 (6))

Heute: c → e → f → d → g. **Der PO behält sie bei.** Gründe nach der Wertordnung: BK-e bringt am meisten direkte Pflegezeit und weniger Schreibarbeit. BK-f schliesst den Geldkreis der Teams (Einkommen, 0 % Provision). BK-d entlastet die Auftraggeberin. BK-e baut den KI-Adapter, den BK-d danach wiederverwendet.

Vorschläge, damit jeder Teilschritt sichtbar näher ans Ziel führt (Founder entscheidet):
1. **Klickpfad pro Teilschritt:** Jeder Brief nennt den Pfad, den der Founder nach dem Merge auf Staging klickt. Der Nachweis kommt aus dem Smoke-Test (§1).
2. **Ehrliche Namen:** BK-c3 heisst bis zur Anbieterwahl «Rangfolge mit Begründung (Regeln)», nicht «KI-Rangfolge».
3. **Anbieterwahl jetzt vorbereiten:** Die Wahl eines Schweizer oder EU-Endpunkts für synthetische Daten ist die einzige Voraussetzung, ohne die keine KI-Stufe einen Termin bekommt. Der PO schlägt einen Entscheid-Antrag (Owner, `lca` liest die Bedingungen) parallel zu BK-c3 vor. Der PO nennt keinen Anbieter.

## 6. Vorschlag `eng-2` (FE-088 (2); Entscheid beim Founder)

| Punkt | Vorschlag |
|---|---|
| Vorbereitender Teilschritt | BK-e: ADR-Entwurf, Adapter AUT-135 mit Testersatz, rote Tests (Unit, pgTAP), Bildschirmgerüst des Berichtsentwurfs |
| Branch | `prep/bk-e-report-draft`, höchstens als Entwurfs-PR für CI; der PO mergt keinen `prep/`-Branch |
| Grenzen | keine Datei, die der offene BK-PR ändert; kein `IMPLEMENTATION_STATUS.md`, kein `NEXT_CAPABILITY.md`; ADR nur als Entwurf in `docs/engineering/probes/`; kein Zugriff auf Staging oder einen KI-Endpunkt |
| Migrationen | SQL nur im Entwurf; die Nummer vergibt `eng` erst, wenn BK-e aktiv ist (nächste freie Nummer nach dem letzten Merge) |
| Gemeinsame Dateien | `recovery/main` wird per Merge-Commit eingezogen, kein Rebase; `DECISIONS.md` erst bei Aktivierung |
| Erwarteter Zeitgewinn (Schätzung) | ca. ein halber Tag pro Teilschritt, zusammen etwa 1–2 Tage bis BK-g. Messgrösse: Zeit von «Teilschritt aktiv» bis «PR bereit» |
| Review-Kapazität | keine Gate-Zeilen auf `prep/`; höchstens ein beratender Vorab-Blick pro Tag von `aia` und `cra`; die Gates prüfen erst, wenn der Teilschritt aktiv ist |
| Risiko | Nacharbeit, wenn BK-c3 Schnittstellen ändert; dann verwirft `eng-2` den Entwurf |
| Versuch | 1 Woche (bis 2026-11-25), danach Auswertung durch den PO |

## 7. Rhythmus der Prüfrollen (FE-091 ersetzt FE-088 (1))

- **Seit 2026-11-18 ca. 15:25 pausiert:** «NAVORA Clinical & Regulatory Architect», «NAVORA UX/UI Design Architect», «NAVORA Legal & Compliance Agent». Aktiv: PO, Engineering, AI & Automation, Wochenstatus Engineering; Chief Strategy Architect wöchentlich (keine Aufgabe, die den aktiven PR verändert).
- **Pflicht-Reviews:** erst wenn `eng` den stabilen Endstand (Commit, Testresultate, Prüffragen) meldet und alle CI-Jobs grün sind, startet der PO die benötigte Rolle einmal (Aufgabe «NAVORA Product Owner agent», Abschnitt «BK BUILD PHASE»). Pausiert heisst nie zustimmend.
- **Messgrösse:** Zeit von «Endstand gemeldet» bis Freigabezeile, je Rolle und PR.
- **Neubewertung:** bis 2026-11-25 oder bei der BK-e-Abnahme, was zuerst eintritt.

## 8. Offen beim Owner/Founder

1. Anbieter und Endpunkt (CH/EU, keine Speicherung) für die erste echte KI-Funktion mit synthetischen Daten, Ablage des Schlüssels nur in der Staging-Umgebung, Ausgabenlimit (FE-085, §9). Die Freigabe synthetischer Daten für KI-Schnittstellen gibt es seit FE-085 (B)(2); die Datenbank-Sperre AUT-115 hebt `eng` im dafür aktiven Teilschritt auf.
2. Entscheid über den `eng-2`-Versuch (§6).
3. Vorschläge §5 (1)–(3).

## 9. Erste echte KI-Funktion (PLANNED; abgestimmte Vorlage mit `aia` bis 2026-11-19 12:00, #1466)

Kennzeichnung heute: **kein KI-Modell ist angeschlossen.** BK-a bis BK-c sind feste Regeln; BK-e2 (Berichtsentwurf) ist als Testersatz geplant.

**Abgestimmte Empfehlung (`po` und `aia`, `aia` Review 69, `AUTOMATION_REVIEW.md` 2026-11-18 15:46):** **B, Auftrag aus Freitext (BK-d), nur Datum, Beginn, Ende und PLZ**, jeder Wert durch eine feste Regel geprüft (AUT-145) und einzeln bestätigt; Qualifikation und Tätigkeiten bleiben von Hand (AUT-146); A folgt als zweite Funktion mit `cra`-Gate. Schwellen, Kosten- und Abschaltregeln: `aia` Review 69 §1. Tausch BK-d vor BK-f erst, wenn Anbieter gewählt, `lca` die Bedingungen gelesen, Schlüsselweg festgelegt und AUT-136 (1) gebaut ist. Vergleich der beiden Kandidaten:

| Punkt | A: Berichtsentwurf aus der Eingabe der Pflegekraft (BK-e2a, Vorschlag PO 16:00) | B: Auftrag aus Freitext (BK-d, Vorschlag PO 15:45) |
|---|---|---|
| Nutzen | grösste Schreibentlastung für Pflegekräfte (Wert 1, 5); im aktiven Block | weniger Erfassungsarbeit bei der Auftraggeberin; für den Founder als Auftraggeber direkt sichtbar |
| Risiko und Prüfungen | Pflegedokumentation: `cra` (Entwurfsgrenzen, Geräteklasse), Unterschrift BK-e2b vor jeder Verbindlichkeit | kein Pflegebericht, keine Zuteilung; jedes Feld von der Auftraggeberin bestätigt; feste Regeln BK-b danach |
| Founder-Lage | FE-085 (B)(3): «echte Voice-to-Report-Anbindung erst, wenn BK-d aktiv ist»; A vor BK-d braucht dazu eine Änderung durch den Founder | passt zu FE-085 (B)(3) |
| Datenweg (beide) | Browser → App-Server (Render) → Modell-Endpunkt des vom Founder gewählten Anbieters (CH/EU, keine Speicherung) → Vorschlag mit Quellstelle je Angabe → Vorschlagsprotokoll (AIG1) → Bestätigung durch einen Menschen. Nur `navora-staging`, nur synthetische Daten, nur Simulationsorganisationen | |
| Kontrolle, Abschaltung, Kosten (beide) | Schlüssel nur in der Staging-Umgebung; Server lehnt ab, wenn er nicht gegen `navora-staging` läuft (AUT-136 (1)); ein Schalter stellt auf Testersatz oder Formular zurück; nichts ohne Bestätigung; nichts ohne Quellstelle; Tageslimit an Aufrufen in der App, Ausgabenlimit im Anbieterkonto | |
| Testkriterien (beide) | CI nur mit Testersatz (kein Schlüssel in CI); Prüfsatz synthetischer Texte mit erwarteten Werten; bestanden ohne erfundenen Wert und mit Quellstelle je Angabe; Schalter-Test; ein protokollierter Live-Lauf auf Staging. Schwellen setzt `aia` | |
| Zeitfenster (Schätzung) | frühestens rund eine Woche nach Merge #1421, wenn Anbieter und Schlüssel vorliegen | frühester Live-Lauf KW 49 (30.11.–4.12.), wenn Anbieter und Schlüssel bis ca. 24.11. vorliegen und BK-d vor BK-f gezogen wird |

Der PO legt dem Founder nach der Antwort von `aia` **eine** Empfehlung vor (FE-090 (5)).
