# NAVORA Plattform-Grundriss (ARCH1)

**Status:** PROPOSED. Entwurf `po`, Live-Sitzung 2026-11-20 ca. 15:25, aus dem Code von `recovery/main` `37083b2` gelesen (Seiten, Navigation `src/lib/auth/nav.ts`, Rollen `organization_memberships.role`, `client_accounts.client_kind`, Specs). **`eng` bestätigt oder ersetzt jede technische Angabe** (Spalten Backend, Daten, KI, Prüfung) in einem eigenen Docs-PR, bevor H1 startet. Der PO verantwortet Umfang und Reihenfolge. Visuelle Fassung für den Founder: Artifact «NAVORA Plattform-Grundriss» (https://claude.ai/artifact/9HgXU4yQbNmf34Sx7NWzqN). Founder-Auftrag: FE-108.

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
