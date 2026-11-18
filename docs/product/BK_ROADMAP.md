# BK-Roadmap: vom Pflegeauftrag bis zur Rechnung

**Besitzer:** Product Owner (`po`) · **Version:** 1, 2026-11-17 17:15 (Europe/Zurich) · **Auftrag:** FE-088 (6) · **Quellen:** Brief `docs/agents/briefs/BK.md`, Blueprint V3.2 §8, `FOUNDER_DECISIONS.md` FE-085, FE-087, FE-088 · **Kennzeichnung:** IMPLEMENTED, PLANNED, OPEN, UNKNOWN. Termine sind Schätzungen des PO, keine Zusagen. Der PO hat keine Tests ausgeführt.

## 0. Kurzfassung

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

## 2. Stand im Code

| Teilschritt | Inhalt | Code | Staging-DB | Abnahme |
|---|---|---|---|---|
| BK-a | Auftrag erfassen (ohne KI) | gemergt (#1238 u. a.) | ja | abgenommen 14.11. (Simulation) |
| BK-b | Reichweite, harte Filter | gemergt (#1268, #1270, #1273) | ja | abgenommen 17.11. (Simulation) |
| BK-c1 | Übernahme, Deckungsstand (DB) | gemergt `781944f` | ja (0135) | abgenommen 18.11. 02:39 (Simulation, BK-c als Ganzes auf `d51d1c1`) |
| BK-c2 | Bildschirme `/team` und Kundenstatus | **gemergt** `25d7cdf` (#1358, Kopf `9a7fc56`; `lca`, `cra`, `uxa` frei) | **0136 fehlt** (`eng` spielt ein, FE-088 (7)) | abgenommen 18.11. 02:39 (Simulation, mit BK-c) |
| BK-c3 | Begründung je eigenem Team (Reihenfolge nach Beginn, keine Rangfolge zwischen Teams; PO 17:39) | **gemergt** `ad21dd2` (#1388, Kopf `8744acd`; `cra`, `uxa`, `aia`, `lca` frei; Stand 17.11. 20:52) | **0137 fehlt** (wie 0136; `STAGING_DB_URL` nicht gesetzt) | abgenommen 18.11. 02:39 (Simulation) auf `d51d1c1`: #1403 (pgTAP 147) gemergt, `ci-repeat` 44215240768 20/20, 0 übersprungen |
| BK-e | `/field`-Verknüpfung, Berichtsentwurf aus Text (kein externer KI-Dienst, Testersatz) | **aktiv seit 18.11. 02:39**; ADR und rote Tests zuerst; Zuschnitt ADR-202 (18.11. 03:39): BK-e1a Ortszeile (#1417 **gemergt** 18.11. 04:39, `3d9f1e6`, Merge-CI grün; nicht abgenommen), BK-e1b Einsatz aus der Übernahme (#1421 aus dem Entwurf, kein `cra`-Gate; gebaut CGR-242, CGR-244, UXR-237, UXR-239, CGR-248/UXR-241, UXR-240, CGR-249 mit Deckungs-Eigenschaft (`ccd0f4b`), CGR-250 (Abwesenheit lässt Übernahme-Einsatz unverändert), CGR-251, Liste aller 21 Einsatz-Schreiber (`82e7323`), CGR-246 Hinweis ans Team (`d9f4a4b`), CGR-251-Kontrolle und CGR-252 Prüfspur bei abgelehntem Versuch (`8d4a1ff`); offen CGR-253/UXR-245 (Ausfall-Hinweis ohne «Ich übernehme», PO 11:39), UXR-246 Linkteil, Playwright, CGR-233, dann `cra`-/`uxa`-Gate auf dem Endstand), BK-e2a Entwurf und Liste «nicht übernommen» (mit CGR-245; Abhakliste auf der Karte vorgeschlagen), BK-e2b Unterschrift und Kontrollen | – | – |
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

## 7. Rhythmus `cra` und `uxa` (FE-088 (1))

- **Umgesetzt 2026-11-17 ca. 17:10:** `cra` `26 * * * *`, `uxa` `47 * * * *` (vorher alle 4 Stunden). Befristet auf das aktive BK-Teilstück.
- **Messgrösse:** Zeit von «Kopf stabil und bereit» bis zur Freigabezeile, je Rolle und PR. Ausgangswert #1358 `9a7fc56`: stabil 16:06; `lca` 16:24 (18 Min.); `cra` und `uxa` offen.
- **Empfehlung zum weiteren Rhythmus:** spätestens 2026-11-21.

## 8. Offen beim Owner/Founder

1. Anbieter für einen KI-Endpunkt mit synthetischen Daten (FE-085 (4)); ohne ihn kein Termin für echte KI.
2. Entscheid über den `eng-2`-Versuch (§6).
3. Vorschläge §5 (1)–(3).
