# NAVORA Plattform-Grundriss (ARCH1)

**Status:** Fassung 2.1, 2026-11-20 ca. 18:40. **Vom Founder bestätigt ist die Vision** (eine Plattform mit Ansichten je Rolle, Heim zuerst, Register für Register; FE-108, FE-109 (B)). **Nicht bestätigt sind die Details dieser Fassung**: Sie sind eine Arbeitsgrundlage. Der verbindliche Heim-Vertrag steht in `docs/agents/briefs/HD.md` Fassung 2; Tabellen und Funktionen hat `eng` geprüft (`docs/engineering/probes/ARCH1_ENG_REVIEW.md`). Fassung 2 (16:20): Arbeitsgrundlage (Vermerk unter FE-108). Fassung 1: PROPOSED. Entwurf `po`, Live-Sitzung 2026-11-20 ca. 15:25, aus dem Code von `recovery/main` `37083b2` gelesen (Seiten, Navigation `src/lib/auth/nav.ts`, Rollen `organization_memberships.role`, `client_accounts.client_kind`, Specs). **`eng` bestätigt oder ersetzt jede technische Angabe** (Spalten Backend, Daten, KI, Prüfung) in einem eigenen Docs-PR, bevor H1 startet. Der PO verantwortet Umfang und Reihenfolge. Visuelle Fassung für den Founder: Artifact «NAVORA Plattform-Grundriss» (https://claude.ai/artifact/9HgXU4yQbNmf34Sx7NWzqN). Founder-Auftrag: FE-108.

Kennzeichnung: **Staging** = mit Klicktest auf `navora-staging` nachgewiesen (staging-smoke 44744533079, App `8051283`, DB `20261021000157`); **Code** = im Code und CI, auf Staging nicht nachgewiesen; **Teilweise**; **Fehlt**.

## 1. Fakten aus dem Code (IMPLEMENTED)

- Ein Next.js-App mit gemeinsamer Hülle (`AppShell`); Seiten prüfen keine Rollen selbst, Zugriff wird in der Datenbank durch RLS durchgesetzt. Rollen: `admin`, `coach`, `operations`, `nurse` (Organisation) plus Mitgliedschaft in einem Auftraggeberkonto (`client_account_members`).
- **Keine Organisationsart.** Der Auftraggeberkontext steht nur in `client_accounts.client_kind` (`home`, `hospital_ward`, `household`).
- **Keine Heim-Dienstplanung** für eigenes Personal: keine Tabellen für Standort, Station, Heimmitarbeitende, Dienstplan. `client_shift_plans` (0129) hält nur synthetische Schichtbezeichnungen. NH-A1 (Station als NAVORA-Team) ist genehmigt, aber nicht gebaut.
- **Keine** Angehörigen-, Coach- oder Betreiberansicht (Cockpit nur als offener PR #1541).
- Einzige Modellanbindung: Berichtsentwurf in /field; Standard `rule` («regelbasiert, keine KI»); Modell nur bei Staging-Host, Simulationsorganisation, Not-Aus aus und bereitem Ledger. Ob auf Staging aktiv: UNKNOWN.
- Auf Staging nachgewiesen: Anmeldung aller Demokonten; Auftrag → nur passendes Team sieht ihn → Übernahme → «Gedeckt»; Nachtschicht als eine Karte in /field; Bericht unterschreiben → Rechnungsentwurf → Team sendet → Auftraggeber sieht die Rechnung.

## 2. Registerkarte (Kurzform)

| Gruppe | Register (Stand) |
|---|---|
| Pflegeheim | Übersicht (Teilweise) · Dienstplanung (Fehlt) · Externe Aufträge (Staging, ohne Lücke) · Kosten & Rechnungen (Teilweise) · Mitteilungen & Ausnahmen (Fehlt) · Dokumentation, Modul 2 (Fehlt) · Angehörige, Modul 3 (Fehlt) · Einstellungen (Fehlt) |
| Spital (später) | Übersicht · Stationsbedarf · Externe Aufträge (Code) · Austritte & Übergänge (/intake, anderer Ablauf) · Rechnungen (Code) |
| Privatperson (später) | Meine Betreuung (Fehlt) · Anfrage (Teilweise, gleiches Formular wie Heim) · Rechnungen & Angehörige (Teilweise) |
| Team | Angebote & Übernahmen (Staging) · Fälle & Planung (Code) · Einsatzgebiet (Code) · Preis & Rechnungen (Staging) · Team-Finanzen (Fehlt) |
| Pflegekraft | Heute /field (Staging) · Arbeitstag /work (Code) · Einstellungen (Code) |
| NAVORA | Plattform-Cockpit (#1541, Teilweise) · Support (/admin einer Organisation, Teilweise) · Coach (Fehlt) |

## 3. Pflegeheim-Register: Frontend → Backend → Daten → KI

| Register | Backend (heute / neu) | Daten und Grenze | KI | Prüfung |
|---|---|---|---|---|
| Übersicht | neu `home_overview` über `client_orders`, `team_order_offers`, später Heimdienste | nur eigenes Konto; keine Namen externer Pflegekräfte | keine; «gefährdet» feste Regel | fremdes Konto sieht nichts; Staging-Klickpfad |
| Dienstplanung | neu: Standort, Station, Heimmitarbeitende, Dienst, Einteilung, Abwesenheit; RLS, Audit, ganze Funktionen (STAB1) | B2B-Bereich des Heims, getrennt von NAVORA-Teamdaten | keine im ersten Paket | pgTAP: fremdes Heim und NAVORA-Team lesen nichts; e2e 390 px |
| Externe Aufträge | `preview_client_order`, `confirm_client_order`; harte Regeln Region, Qualifikation, Zeit; neu Vorbefüllung aus der Lücke | Teamname erst nach Übernahme | feste Regel; später Modell als Entwurf (BK-d) | staging-smoke Pfad 1 |
| Kosten & Rechnungen | `team_prices`, `order_take_prices`, `team_invoice_drafts`; neu Schätzung und vereinbarter Preis sichtbar | Pflegeerlös Team ↔ Auftraggeber; NAVORA-Gebühr nie auf dieser Rechnung | keine | staging-smoke Pfad 3 |
| Mitteilungen & Ausnahmen | `my_signals` gilt nur für Teammitglieder; neu Auftraggeber-Hinweise aus Statuswechseln | keine Gesundheitsangaben; Push-Text lca | keine | Ausfall → Hinweis; fremdes Konto nichts |
| Dokumentation | Bericht-Logik (`field_reports`) wiederverwenden | Heimberichte getrennt von Teamberichten | Modell nur Staging + Simulation + Not-Aus | später, cra und lca |
| Angehörige | neu, eigene Freigabetabelle | nur freigegebene Mitteilungen | keine | später, lca |
| Einstellungen | neu Recht je Register und Modul | ohne Preise in Phase A | keine | ohne Recht kein Zugriff, auch nicht per Datenbank |

## 4. Übergang interne Planung → externer Auftrag

Lücke im Wochenplan (feste Regel) → vorbefüllter Auftragsentwurf → Heim prüft und bestätigt → Angebot an Teams, die die harten Regeln erfüllen → Team übernimmt (erst das ist eine Zusage) → Wochenplan «extern gedeckt», Auftraggeberstatus «Gedeckt», Karte bei der Pflegekraft. Ausfall der bestätigten Pflegekraft: Ersatz im Team (Code, BK-e), Heim erhält einen Hinweis (Fehlt), ohne Ersatz zurück auf «Noch nicht gedeckt».

## 5. Empfohlene Bau- und Prüfreihenfolge (PO)

1. **BK-f abnehmen** (ci-repeat läuft, dann `ABNAHMEAKTE.md`).
2. **STAB1** (FE-100), weil jedes Heim-Paket Datenbankfunktionen hinzufügt.
3. **H1 Heim-Arbeitsbereich und Übersicht** aus vorhandenen Daten.
4. **H2 Dienstplanung Woche** (B2B-Modul 1, Kern; Gates cra, lca, uxa).
5. **H3 Lücke → externer Auftrag**, danach KI-Strukturierung (AI1, BK-d) als Vorschlag.
6. **H4 Mitteilungen & Ausnahmen** für das Heim.
7. **H5 Kosten: Schätzung, vereinbart, gestellt.**
8. Später: Einstellungen mit Rechten und Modulen, Monat, Modul 2, Modul 3, Spital, Privatperson, Coach, Cockpit.

Jedes Paket: Nutzeraufgabe und sichtbares Ergebnis vor dem Bau; Frontend, Backend, Rechte und Migration zusammen; Tests und Gates; PO-Merge; Staging-Abgleich; Meldung «Dieses Register kannst du jetzt als … öffnen» mit App-Commit, Migrationsstand, Staging-Lauf, Grenzen.

## 6. Befunde und Abweichungen

- **PO-ARCH-1 (OPEN, `eng`, `cra`):** Rolle `coach` ist heute ein Koordinator und sieht /operations-Ausnahmen mit Fallbezug. Das widerspricht dem neutralen Coach ohne Aktenzugang. Prüfen, was `coach` tatsächlich liest; Vorschlag erst danach.
- **PO-ARCH-2 (OPEN, `po`):** /operations und /intake bilden den früheren zentralen Aufnahmeablauf ab. Für Spital-Übergänge wiederverwenden oder ablösen ist offen; keine Entscheidung vor dem Spital-Paket.
- **Abweichung NH-A1:** der genehmigte, nicht gebaute Brief sieht die Station als selbstorganisiertes NAVORA-Team. Der Founder beschreibt die Heim-Dienstplanung als B2B-Modul für das eigene Personal. Beides kann nebeneinander bestehen; NH-A1 ist nicht der erste Bauschritt. Nichts geändert.

## 7. Entscheidung, die der Founder braucht

Reihenfolge: bisher (FE-099 (7)) BK-f → STAB1 → AI1 → BK-d. Vorschlag: BK-f → STAB1 → H1 → H2 → H3 (mit AI1 und BK-d als KI-Teil) → H4 → H5. Offen beim Founder.

## 8. Fassung 2 (2026-11-20 ca. 16:20, nach Founder-Prüfung)

**Ist-Stand, korrigiert (aus Job-Protokollen):** Render liefert nach jedem Merge den neuesten Commit aus, auch bei reinen Docs-Merges. Stand 15:45: App `d86e59f` = `recovery/main` (0 Commits zurück), DB `20261021000157`, «app and database match» (`staging-version` 44756037571). Letzter Klicktest `staging-smoke` 44744533079 auf `8051283` (gleicher App-Code): 4/4. **BK-f abgenommen** auf `40a2ce1` (`ci-repeat` 44746720886, 20/20; `ABNAHMEAKTE.md`). Auf Staging nachgewiesen sind nur die vier Smoke-Pfade; alles andere ist höchstens Code+CI.

**Kennzeichnung je Register:** Staging (mit Lauf-ID) · Code+CI · Entwurf (Brief oder offener PR) · Fehlt. «Auszahlung an Mitglieder» ersetzt durch «Verteilung des Teamerlöses: Rechtsform, Lohn- und Organisationslogik OPEN (Founder, `lca`)».

**NAVORA getrennt:** Betreiberfinanzen (nur Abo und B2B), technischer Support (Konto, Funktion, Fehlerart, Zeit; keine Fallinhalte), betriebliche Ausnahmen (Jobs, Synchronisation, Staging-Gleichstand), neutraler Coach (nur auf Anfrage eines Teams; Teamzahlen; verborgen: Namen von Klientinnen und Bewohnern, Berichte, Beobachtungen, Sicherheitshinweise, Pflegepläne, Fallbeträge). PO-ARCH-1 bleibt: `coach` ist heute Koordinator; was die Datenbank ihm zeigt, prüft `eng`.

**Geldströme je Register:** Dienstplanung = Heim zahlt NAVORA B2B-Abo; externe Aufträge und Rechnungen = Heim zahlt Team direkt (Pflegeumsatz); Team-Preis = Team zahlt NAVORA feste Monatsgebühr; Spital und Privatperson: Zahler je Fall OPEN (`lca`).

**Fünf Zustände** (überall gleich): Angebot offen · kein passendes Team · Team hat zugesagt, Person bestätigt noch · Besetzung bestätigt («Gedeckt») · Ausfall nach «Gedeckt» («Nicht mehr gedeckt» + nächster Schritt). Auftraggeber-Texte bestehen in `src/features/orders/offer-rules.ts` (Code+CI); Heim-Wochenplan und Mitteilungen fehlen.

**Produktvertrag:** `docs/agents/briefs/HD.md` (Dienstplanung als ein Ergebnis; HD-1 bis HD-4; gemeinsames Staging-End-to-End-Gate). Ersetzt H1–H5 aus §5 als erste Heimlieferung.

**KI-Empfehlung PO:** erste Modellfunktion = AI1 (Berichtsentwurf; Anbieter, CHF 50/Monat und `lca`-Gate entschieden, FE-099 (7)); erste Heim-KI = Ausfall-Optionen erklären (HD-4). Konflikterklärung: feste Regeltexte genügen. Auftrag aus der Lücke strukturieren: kein Nutzen (Lücke ist strukturiert), später für Freitext (BK-d). Wochenplan-Vorschlag: nach HD.

**Baufolge (Fassung 2; beantwortet durch FE-109: HD-1 → HD-2 → AI1 → HD-3, `briefs/HD.md` §4):** A (Empfehlung) STAB1 → AI1 → HD · B AI1 → STAB1 → HD (Ausnahme von FE-100 (6), nicht empfohlen) · C STAB1 → HD → AI1 (Fassung 1).

## 9. Fassung 2.1 (2026-11-20 ca. 18:40): Ist-Stand und die übrigen Nutzergruppen

**Ist-Stand, verifiziert aus Job-Protokollen (nicht aus diesem Dokument):** `staging-version` 44781911610 meldet: `navora-staging` liefert `f3149d6` aus (0 Commits hinter `recovery/main`), Datenbank `20261021000158`, «app and database match». STAB1 ist abgenommen (`ci-repeat` 44778677226, 20/20). Auf Staging nachgewiesen sind nur die vier Smoke-Pfade (`staging-smoke` 44776130634, 4/4 auf `d3b2233`). Der Lauf 44777149305 auf `f7dfd2d` war in Pfad 3 rot; die Ursache ist wahrscheinlich eine Kollision der Testdaten zweier aufeinanderfolgender Läufe (UNKNOWN, Folgeposten STAB1-F3 bei `eng`); der nächste Lauf 44781911457 auf `f3149d6` war wieder 4/4. Die Heim-Dienstplanung (#1623) ist **nicht** auf Staging: Code+CI, Draft. `eng` bestätigt diesen Stand im nächsten Journal.

**Die übrigen Nutzergruppen (Aufgaben und Datenflüsse; gebaut wird später, ein Register nach dem anderen):** Gemeinsame Bausteine, damit HEIM-DP keine zweite Plattform erzwingt: (1) **Einrichtungs-Mandant `institutions`** mit Art (`home`, `hospital_ward`, später weitere) und Mitgliedsrollen `lead`/`planner`/`viewer`; Heim und Spital nutzen denselben Mandanten. Eine Einrichtung kann je Netzwerk ein Auftraggeberkonto haben. (2) **ein Bestellweg** `preview_client_order`/`confirm_client_order` für alle Auftraggeber; (3) **eine Statusfunktion** (HD.md §3) für alle Ansichten; (4) **getrennte Geldströme** (Pflegeumsatz Team ← Auftraggeber direkt; NAVORA-Abo; B2B-Modul).

| Gruppe | Aufgaben | Datenfluss | Stand |
|---|---|---|---|
| Pflegeheim | Dienstplanung (eigenes Personal), externe Aufträge, Status, Rechnungen der Teams lesen | Einrichtung → Auftrag → Team; Status zurück; Rechnung Team → Heim direkt | HD-1 Code+CI (#1623); Aufträge und Rechnungen Staging (Pfade 1, 3) |
| Spital (Station) | wie Heim, Stationen = Abteilungen; kurzfristige Ausfälle | gleicher Mandant `institutions` (Art `hospital_ward`), gleicher Bestellweg | Fehlt (nach HEIM-DP) |
| Privatperson | einen Bedarf bestellen, Status sehen, Rechnung lesen; Angehörige (Modul 3) nur mit Erlaubnis | Haushalt als Auftraggeberkonto (`household`) **ohne** Einrichtung; Zahler je Fall OPEN (`lca`) | Fehlt |
| Team | Angebote sehen, mit eigener Person übernehmen, Preis, Rechnung senden, Abwesenheit im Team ausgleichen | liest nur eigene Übernahmen; sieht nie Heimpersonal oder Heimplan | Staging (Pfade 1, 3) |
| Pflegekraft | Einsatz in `/field`, bestätigen, Bericht, Abwesenheit melden | eigene Einsätze; Abwesenheit → Status N beim Auftraggeber | Staging (Pfade 2, 3) |
| NAVORA-Betreiber | Betreiberfinanzen (nur Abo und B2B), Support (technisch), betriebliche Ausnahmen, neutraler Coach | kein Zugang zu Fall- und Heimpersonaldaten; Weg C0–C3 in HD.md §7 | C0 Code+CI (#1623); C1–C3 Fehlt |

Regel aus dem Code (IMPLEMENTED, 0129; auf #1623 für `institution_members` übernommen): Niemand ist zugleich Auftraggeber und Teammitglied.
