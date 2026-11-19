# Antwort an den Founder: Arbeitsmodus «Paket statt Stundentakt» (FE-095)

**Besitzer:** Product Owner (`po`) · **Stand:** 2026-11-19 16:40 (Europe/Zurich), PO-Live-Sitzung · Antwort auf die Founder-Nachricht an `po` und `eng` vom 2026-11-19 (FE-095).
**Gemeinsam mit `eng`:** Die mit «`eng` bestätigt» markierten Teile sind Engineering zur Bestätigung vorgelegt (Issue #1544). Bis zur Bestätigung gelten sie als Vorschlag des PO.
Kennzeichnung: IMPLEMENTED · PLANNED · OPEN · UNKNOWN. Keine Zugangsdaten in diesem Dokument.

## 0. Bestätigung des Arbeitsmodus

Verstanden. Ab dem laufenden Teilblock gilt praktisch:

1. **Paketvertrag vor dem Bau.** Vor jedem Teilblock schreibt der PO einen kurzen Paketvertrag (sechs Fragen: Ablauf, Umfang und Nicht-Umfang, betroffene Ansichten/Backend/Datenbank, positive und negative Testfälle, nötige Fach-Gates, was der Founder danach auf Staging bedienen kann). `eng` bestätigt Machbarkeit und Schnitt. Danach ist der Umfang **fest**.
2. **Keine stündlichen Umfangsänderungen mehr.** Die stündlichen PO-Läufe ändern den Umfang eines laufenden Pakets nicht und schreiben keine neuen Amendments in den Brief. Sie tun nur noch: CI des letzten Merge-Commits prüfen, reine Rollen-Dokumente mergen, und **still bleiben**, solange kein prüfbereites Paket vorliegt. Neue Ideen aller Rollen gehen in eine Liste «Für spätere Pakete» und werden beim nächsten Paketvertrag entschieden.
3. **Prüfbereit-Meldung löst den PO-Zyklus aus.** `eng` meldet auf dem PR einen Kommentar, der mit `Paket prüfbereit:` beginnt und die sieben Angaben enthält (PR und Head-SHA; neue Funktion; tatsächlich ausgeführte Tests je CI-Job; Migrationen und Staging-Wirkung; bekannte Grenzen; nötige Gates; Demo-Klickpfad). Erst dann prüft der PO, startet die im Paketvertrag benannten Gates gezielt (pausierte Rollen per `fire_trigger`, FE-091) und merged, wenn die Bedingungen erfüllt sind.
4. **Merge ≠ Abnahme.** Nach dem Merge: CI auf dem Merge-Commit, `staging`-Job (Migration eingespielt), App-Commit auf Render von `eng` gemeldet, Klickpfad auf Staging. Dann schreibt der PO: «für die Simulation abgenommen» oder «Nacharbeit», mit Belegen.
5. **Nur belegte wesentliche Sicherheits-, Datenschutz- oder Funktionsfehler im vereinbarten Ablauf** stoppen ein prüfbereites Paket. Alles andere wird ein benanntes Folge-Item.
6. **Nach jeder Abnahme** kommt die gemeinsame Meldung «Ivica, auf der echten NAVORA-Staging-Plattform kannst du jetzt zusätzlich Folgendes tun: …» mit Rolle, Klickpfad, erwartetem Ergebnis, App-Commit, Datenbankstand, «auf Staging selbst geprüft: ja/nein» und dem, was noch fehlt.

**Weniger, grössere Pakete.** BK-e wurde in sieben PRs zerlegt (2a, 2b-1 in drei PRs, Messung, Wächter, …), jeder mit eigenem Gate und Merge-Up. Das hat Wartezeit erzeugt, ohne dass Sie mehr bedienen konnten. Ab jetzt schneidet der PO Pakete so, dass **jedes Paket einen neuen bedienbaren Ablauf auf Staging bringt**.

## 1. Aktiver Teilblock und fester Umfang

**Aktiv:** Block BK («Durchgehender Kern»), Teilstück **BK-e** (übernommene Schicht → mobile Ausführung → Bericht → Unterschrift).

| Teil | Inhalt | Stand |
|---|---|---|
| BK-e1 | Übernommene Schicht erscheint auf `/field`, Zeiten F1–F4, Nachtschicht über Mitternacht | **für die Simulation abgenommen** (2026-11-18, `3ea17ee`) |
| BK-e2a Teil 1 | Anbieterneutraler Adapter inkl. Anthropic-Anbindung, Abschalter, kein Aufrufer | IMPLEMENTED (gemergt #1494) |
| BK-e2a Teil 2a | «Entwurf aus Notizen»: Zeile für Zeile entscheiden, kein «alles übernehmen», Unterschrift wartet | IMPLEMENTED (#1497), **Testersatz mit festen Regeln** |
| BK-e2a 2b-1 | Notizen und Verwerfen ehrlich gezählt (#1529), erfasste Fakten nur zur Ansicht (#1531), Handgriff-Messung (#1503) | IMPLEMENTED (gemergt) |
| BK-e2a 2b-1 (a) | Ledger-Wächter im Resolver, Abschalter schliesst bei jedem Fehler, exakter Staging-Host, keine Leistungen an ein Modell (#1527) | IMPLEMENTED auf dem PR, **nicht gemergt** (wartet auf Nachziehen von `recovery/main`) |
| **BK-e2 Abschlusspaket** | siehe §2 | PLANNED |

**Fester Umfang des Abschlusspakets (Paketvertrag, gilt ab jetzt):**
- **Ablauf:** Die Pflegekraft beendet die übernommene Schicht, tippt oder diktiert (Handy-Tastatur) ihre Notizen, erhält einen Entwurf **von Claude** (synthetische Daten, nur Staging), entscheidet jede Zeile, übernimmt in die Zusammenfassung und unterschreibt. Ohne Freischaltung oder bei Abschaltung: derselbe Ablauf mit dem regelbasierten Testersatz, sichtbar so beschriftet.
- **Im Umfang:** Herkunftsprotokoll (Ledger) mit Migration; Umschalten von `MODEL_LEDGER_READY` nur über das Ledger; Stopp-Regel (AUT-152: ohne Schwellenwert-Zeile bleibt das Modell zu); Wert-Prüfung (AUT-149: jede Zahl, Zeit, Einheit einer Zeile steht in ihrer Quelle); Evaluationsset S2 auf synthetischen Notizen; Unterschrift und Abschluss BK-e2b; Anzeige «KI-Entwurf (Claude), synthetische Daten» vs. «regelbasiert, keine KI».
- **Nicht im Umfang:** kein NAVORA-Sprachdienst, kein Audio; keine Rechnung (BK-f); keine KI-Auftragserfassung (BK-d); keine realen Personen; keine neuen Komfortwünsche.
- **PO-Entscheid für Phase A (WAS, heute):** Das Ledger speichert **keinen Text**, nur `{line_index, sources, digest, length}`, Digest als HMAC mit Schlüssel ausserhalb des Ledgers (Empfehlung `lca` 2026-11-19 03:43 (a); für synthetische Daten nach `lca` kein Hindernis). Aufbewahrung Phase A: kein Hindernis (keine Personendaten); ein Lösch- oder Anonymisierungsweg für Phase B wird **dokumentiert, nicht gebaut** (`lca` (b)). Damit ist die PO-Voraussetzung von 2b-2 erfüllt. Für Phase B bleibt die Frage beim Founder und einer Rechtsberatung (OPEN).

## 2. Nächste Engineering-Lieferung, die den PO-Review auslöst

1. **#1527** (klein, nur Wächter): `eng` zieht `recovery/main` nach, nennt den Kopf; `aia`-Zeile; Merge im nächsten PO-Lauf. Kein neuer Ablauf für Sie.
2. **«BK-e2 Abschlusspaket»** (ein PR oder ein kurzer Stapel, von `eng` als **ein** Paket gemeldet): löst den eigentlichen Review aus.

**Tests (tatsächlich erforderlich):** Unit-Tests für Ledger-Form, Stopp-Regel, AUT-149 und Abschalter (rot zuerst); pgTAP für die Ledger-Migration (nur Team-eigene Zeilen, append-only, kein Text); e2e F7 bei 390 px mit beiden Anbietern (Testersatz in CI; das echte Modell läuft in CI **nie**); negative Fälle: Abschalter an, fehlende Schwellenwert-Zeile, Nicht-Simulationsorganisation, fremdes Team, Wert nicht in Quelle → kein Modellentwurf; `ci-repeat` 10/10 vor der BK-e2-Abnahme.

**Gezielte Gates (nur diese):** `aia` (KI-Steuerung, Ledger, Stopp-Regel); `cra` (Stufe G des Entwurfs, Schwellenwert der Stopp-Regel, CGR-213 (b)); `lca` (Ledger ohne Text, Anbieterbedingungen, `inference_geo`); `uxa` (Beschriftung KI vs. Regel, 390 px). Alle auf **demselben** gemeldeten Kopf, in einem Startdurchgang.

**Zeitfenster (Schätzung; `eng` bestätigt):** Paket prüfbereit ca. 21.–24.11., Gates und Merge innerhalb von 24 h danach.

## 3. Nächster Ablauf, den Sie auf Staging selbst bedienen können

**Heute schon gebaut und in CI getestet, auf Staging von keinem Agenten durchgeklickt (UNKNOWN):** Auftrag erfassen → Team übernimmt → «Gedeckt» → Schicht erscheint auf `/field` → Zeiten erfassen → Notizen tippen → «Entwurf aus Notizen» (Regel-Testersatz) → Zeilen entscheiden → unterschreiben. **Staging-Stand (von `eng` um 16:30 geprüft, Journal `2026-11-19-1637-eng.md`):** Render `navora-staging` läuft auf App-Commit `d1a70d7`; der `staging`-Job auf `d1a70d7` hat die Migrationen bis `20261021000150` eingespielt. App und Datenbank passen zusammen (IMPLEMENTED). Der Klickpfad-Job auf Staging (`staging-smoke.yml`, ADR-205) ist **noch nie grün gelaufen**, weil drei Secrets fehlen (§7 Punkt 1); deshalb ist kein Ablauf «auf Staging selbst geprüft».

**Nach dem BK-e2 Abschlusspaket:** derselbe Ablauf mit einem **echten Claude-Entwurf** auf synthetischen Notizen, sobald Sie den Staging-Schlüssel hinterlegt haben (§8).

## 4. Weg zur ersten echten KI-Funktion

| Schritt | Wer | Stand |
|---|---|---|
| Anbieter: Anthropic-API direkt, nur Staging, nur synthetisch (FE-094) | Founder | entschieden |
| Adapter + Abschalter + exakter Host | `eng` | IMPLEMENTED (#1494), Härtung in #1527 |
| Ledger-Form und Aufbewahrung Phase A | `po` | **heute entschieden** (§1) |
| Ledger-Migration, Stopp-Regel, AUT-149, Evaluationsset S2, Freischaltung über das Ledger | `eng` | PLANNED (Abschlusspaket) |
| Gates `aia`, `cra`, `lca`, `uxa` auf dem Kopf | `po` startet | PLANNED |
| Schlüssel, Ausgabenlimit, Abschalter in Render `navora-staging` | **Founder** | OPEN |
| Erster Live-Lauf auf Staging | `eng` + Founder | **Ziel KW 48/49 (ca. 26.11.–2.12.)**, Schätzung |

Ehrlich: Heute ist **keine** Funktion an ein KI-Modell angeschlossen. Teamempfehlung, Begründung, Berichtsentwurf und Handgriff-Messung sind **feste Regeln** bzw. ein **Testersatz**.

## 5. Plattformansichten: Status

«Bedienbar» heisst hier: gebaut, in CI getestet, für die Simulation abgenommen. Auf Staging selbst durchgeklickt ist bisher **keine** Ansicht (UNKNOWN).

| Ansicht | Route(n) | Status | Was fehlt |
|---|---|---|---|
| Auftraggeber Pflegeheim | `/order` | **bedienbar** (BK-a bis BK-c abgenommen) | «Wie letztes Mal» (AUT-154), KI-Erfassung aus Freitext (BK-d) |
| Auftraggeber Spital, Privatperson | `/order` (gleiches Formular) | **teilweise** | eigene Wortwahl, Sektor-Konfiguration und Einstieg je Typ (UNKNOWN, wie weit das allgemeine Formular passt) |
| Team-Portal | `/team`, `/team/tagesplan`, `/team/vorschlaege`, `/team/einsatzgebiet` | **teilweise** (Angebote, Übernahme, Einsatzgebiet, Tagesvorschlag als Regel) | wirtschaftliche Übersicht, Qualifikationspflege durch das Team (B2 Teil 2), Ausfallkoordination im BK-Pfad |
| Pflegekraft mobil | `/field` | **teilweise** (Schicht, Zeiten, Entwurf mit Regel-Testersatz, Unterschrift) | echter KI-Entwurf (Abschlusspaket), Offline, NAVORA-Diktat |
| B2B-Einrichtung (Module 1–3) | – (`/operations` ist Altbestand, nicht als B2B abgenommen) | **geplant** | eigene Ansicht, Modulbuchung, interne Schichtplanung (B9 nur Brief NH-A1) |
| Angehörige | – | **geplant**, nicht gebaut | Modul 3, Rechte, Rechtsprüfung |
| Betreiber und Finanzen | `/admin`, `/analytics` | **teilweise** (Altbestand; Kennzahlen AN1–AN3 implementiert, nicht ausreichend getestet) | Abo- und B2B-Umsätze getrennt, Modulverwaltung, Betriebsübersicht |
| Coach/Mediator | `/operations` (Ausnahmen) | **teilweise** (Rolle `coach` existiert laut Code und sieht Ausnahmen; korrigiert nach `eng`, Code hat Vorrang) | eigene Konflikt-/Mediationsansicht, getrennt von Admin und Finanzen, ohne Gesundheitsakte |
| Abrechnung (Teil des Team-Portals) | – | **geplant** (BK-f) | Rechnungsentwurf ohne NAVORA-Provision, kein Geldfluss über NAVORA (FE-078) |

**Übergaben zwischen Ansichten heute:** Auftrag (Auftraggeber → Team), Übernahme und «Gedeckt» (Team → Auftraggeber), Schicht (Team → Pflegekraft), Abwesenheit gibt Übernahme frei (Pflegekraft → Auftraggeber). **Fehlt:** Bericht → Auftraggeber (Lesebeleg), Bericht → Rechnung, alles → Betreiber.

**Reihenfolge (PO, hinterfragt):** BK-e2 → **BK-f** (Rechnungsentwurf: schliesst den Kreis bis zum Geld des Teams, Wert 3) → **BK-d** (KI-Auftragserfassung, zweite echte KI) → BK-g (Szenarien). Danach als **eigener Block** die Plattform-Hülle: Betreiber-Mindestansicht mit getrennten Umsätzen und Modulverwaltung, dann B2B-Modul 1 für ein simuliertes Heim. Angehörige und Coach erst nach einer Rechtsprüfung; sie bleiben im Plan, nicht als gebaut.

## 6. Vorschläge über die bisherigen Anforderungen hinaus

1. **Version sichtbar in der App** (`eng`-Vorschlag erwünscht): Fusszeile auf Staging mit App-Commit und Migrationsstand, und ein CI-Check, der rot wird, wenn Render-Commit und Datenbankstand nicht zusammenpassen. Löst «gemergt, aber im Browser kaputt» dauerhaft.
2. **Prüfbereit-Paket automatisch:** CI schreibt die sieben Angaben (Jobs, Tests, Migrationen, Staging) als Kommentar; `eng` ergänzt nur Grenzen und Klickpfad. Weniger Koordination, mehr Bau.
3. **«Wie letztes Mal»** (AUT-154): Folgeauftrag aus dem eigenen letzten Auftrag, vorbelegt, ein Bestätigen. Auftraggeber von 8 auf ca. 2–4 Handgriffe, ohne KI. Die neue Handgriff-Messung (#1503) zeigt den Gewinn sofort.
4. **Angebot direkt auf «Mein Tag»** (AUT-155): Team von 2 auf 1 Handgriff.
5. **Bericht als Beleg für den Auftraggeber:** der unterschriebene Bericht erscheint (ohne Gesundheitsdetails, nur «erbracht, unterschrieben, Zeiten») beim Auftraggeber und speist später direkt den Rechnungsentwurf. Ersetzt Telefon und Stundenzettel.
6. **Messung als Produkt:** «Handgriffe pro Auftrag» und «Zeit bis Gedeckt» im Team- und Betreiber-Dashboard, als Beleg für Pflegeheime, dass NAVORA Disposition ersetzt.

Alle sind Vorschläge für spätere Pakete, keine Bedingung des laufenden.

## 7. Was nur Sie als Founder tun müssen

0. **Drei GitHub-Repository-Secrets** `STAGING_SMOKE_PW_KUNDEBS`, `STAGING_SMOKE_PW_PFLEGEBS`, `STAGING_SMOKE_PW_PFLEGE` (die Staging-Demo-Passwörter; nie im Chat) anlegen. Ohne sie kann kein Ablauf als «auf Staging selbst geprüft» gemeldet werden. **Das ist die dringendste Einstellung.**
1. **Staging-Schlüssel für Claude** in Render `navora-staging` als Umgebungswert hinterlegen (nie in Chat oder GitHub), mit **Ausgabenlimit** im Anbieterkonto; `AI_KILL_SWITCH` bleibt `on`, bis `eng` das Abschlusspaket gemergt meldet. Zeitpunkt: nach dem Merge des Abschlusspakets.
2. **Kenntnisnahme `lca` (c):** Die direkte Anthropic-API bietet laut Doku keine CH/EU-Region (`inference_geo` nur `global` oder `us`). Für synthetische Daten ist das nach FE-094 in Ordnung; `eng` setzt `us` ausdrücklich, damit die Angabe stimmt. Für Phase B braucht es einen anderen Weg (OPEN, später).
3. **Demo-Zugang:** ob Sie die Demo-Konten (FE-086b) für Staging bereits haben und selbst durchklicken wollen, oder `eng` den Klickpfad auf Staging ausführt und belegt. Bitte ein Wort.
4. **Rhythmus der PO-Läufe:** Ich behalte den stündlichen Lauf als stille Wache (er handelt nur auf eine Prüfbereit-Meldung oder einen roten Merge-Commit). Eine Umstellung der geplanten Aufgabe auf seltener darf nur ein Founder-Auftrag; meine Empfehlung dazu kommt bis 25.11. (FE-091 (c)).

**Abgleich mit `eng` (16:52, PO-Live-Sitzung):** Die Antwort von `eng` (`docs/agents/journal/2026-11-19-1637-eng.md`, gemergt `6b1b553`) stimmt mit diesem Dokument in Arbeitsmodus, Paketschnitt (2b-2 + BK-e2b als **ein** Paket) und Gates überein. Übernommen: Staging-Stand (§3), Ansichten Spital/Privat und Coach (§5), Secrets (§7 Punkt 0). Zeitfenster: `eng` schätzt den ersten echten Claude-Entwurf auf Staging für die Woche ab 23.11., wenn die offenen Eingaben bis Mo 23.11. stehen; die PO-Entscheidung zur Ledger-Form ist seit 16:40 gefallen; offen bleiben der Schwellenwert der Stopp-Regel (`cra` am Gate), AUT-149 und S2 (`aia`) sowie die `lca`-Lesung der Anbieterbedingungen. Realistisch: **KW 48 (23.–29.11.)**, spätestens KW 49.

Sonst nichts. Rechtsform, Phase-B-Pilot und KI-Weg für reale Daten bleiben gesondert offen und blockieren Phase A nicht.
